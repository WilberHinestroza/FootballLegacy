extends Node

## Prueba de humo del GoalCelebration (el jugador en pixel art de cuerpo
## entero con el kit puesto, ver Avatar.celebration_config_for_player, +
## entrada animada) —
## instancia una por cada estilo de entrada (pop/spin/drop/slide/wobble,
## ver GoalCelebration.ENTRIES) y confirma que no crashea ni deja errores
## en unos segundos de simulación de tweens. NO puede verificar que se vea
## bien (esto es 100% visual) — solo que corre sin romperse. La
## verificación visual real la hace Wilber en el celular.
##   godot --headless res://tools/GoalCelebrationProbe.tscn

func _ready() -> void:
	var p := PlayerData.new()
	p.player_name = "Probe Celebración"
	p.country = "Argentina"
	var world_seed: int = 20260906
	p.cosmetics_owned = ["traje_negro", "cadena_fina"]
	p.cosmetics_equipped = {"outfit": "traje_negro", "acc_neck": "cadena_fina"}
	var cfg: Dictionary = Avatar.celebration_config_for_player(p, world_seed)
	print("config de festejo: full=%s (esperado true) outfit=%s (esperado vacío) cadena=%s" % [cfg.get("full"), cfg.get("outfit", ""), cfg.get("acc_neck", "")])
	if not bool(cfg.get("full", false)) or cfg.has("outfit") or String(cfg.get("acc_neck", "")) != "cadena_fina":
		print("PROBE FAIL (el festejo debe ser cuerpo entero, con kit y con los accesorios)")
		get_tree().quit(1)
		return

	var texts: Array = [
		"Se lo dedica a la grada",
		"Corre hacia la bandera de córner",
		"Baile coreografiado con dos compañeros",
		"Deslizada de rodillas hasta el córner",
		"Manda callar al rival de visitante",
	]
	for text in texts:
		var celeb := GoalCelebration.new()
		add_child(celeb)
		celeb.play(cfg, String(text), Color(0.2, 0.4, 0.9))

	# Dejar correr varios frames (las entradas + flash + confeti duran
	# ~2s) para que los tweens de verdad ejecuten sus callbacks.
	for i in range(30):
		await get_tree().process_frame

	print("PROBE OK (5 estilos de entrada corridos sin crash)")
	get_tree().quit(0)
