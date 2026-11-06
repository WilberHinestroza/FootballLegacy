extends Node
## Schema v32 + patrocinio de guayos: migración v31→v32, aceptar regala los
## modelos y pone el primero, el tick paga, al vencer se van los regalados
## (los comprados quedan). Captura del panel de oferta.
##   godot --path . --resolution 576x1024 res://tools/BootDealProbe.tscn
var fails := 0
func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		fails += 1

func _ready() -> void:
	# 1) Migración: un slot v31 sin los campos nuevos.
	var old := {"schema_version": 31, "player": {"player_name": "Viejo", "cosmetics_owned": [], "cosmetics_equipped": {}}}
	var mig: Dictionary = SaveManager._migrate_if_needed(old)
	_check(int(mig["schema_version"]) == SaveManager.CURRENT_SCHEMA_VERSION and mig["player"].has("level") and mig["player"].has("boot_deal") and mig["player"].has("pending_boot_offer"), "migración v31→v32 agrega boot_deal/pending_boot_offer")
	# 2) Flujo del contrato.
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var p := SaveManager.load_player()
	p.overall = 80
	p.reputation = 70
	p.cosmetics_owned = ["guayos_rojo"]   # uno ya comprado
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var offer: Dictionary = BootDealEngine.generate_offer(p, rng)
	offer["brand"] = "voltix"
	p.pending_boot_offer = offer
	SaveManager.save_player(p)
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	await get_tree().process_frame
	get_tree().current_scene = dummy
	var panel := BootOfferPanel.new()
	get_tree().root.add_child(panel)
	for i in range(25):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/boot_offer.png"))
	panel.queue_free()
	WorldTickEngine.resolve_boot_offer(true)
	p = SaveManager.load_player()
	_check(String(p.boot_deal.get("brand", "")) == "voltix" and p.cosmetics_owned.has("guayos_negro") and String(p.cosmetics_equipped.get("acc_feet", "")) == "guayos_rojo", "aceptar: contrato + modelos gratis + el primero puesto")
	var bal: int = p.balance
	p.boot_deal["weeks_remaining"] = 1
	var news: String = BootDealEngine.weekly_tick(p, rng)
	_check(p.balance > bal and p.boot_deal.is_empty() and not p.cosmetics_owned.has("guayos_negro") and p.cosmetics_owned.has("guayos_rojo"), "vence: cobra la última semana, se va el regalado, queda el comprado (%s)" % news)
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0)
