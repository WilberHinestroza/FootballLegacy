extends Control
## Captura REAL de la ropa/zapatos/accesorios nuevos (10-oct) puestos en el
## avatar de cuerpo entero.
##   godot --path . --resolution 576x1024 res://tools/WardrobeProbe.tscn
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.11, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(8, 8)
	add_child(grid)
	var p := PlayerData.new()
	p.player_name = "Probe Ropa"
	var base: Dictionary = Avatar.config_for_player(p, 7)
	var looks: Array = [
		{"outfit": "camisa_chinos", "acc_feet": "mocasines"},
		{"outfit": "gabardina", "acc_feet": "botas_chelsea", "acc_neck": "bufanda"},
		{"outfit": "parka_roja", "acc_feet": "zapatillas_blancas", "acc_head": "boina"},
		{"outfit": "blazer_terciopelo", "acc_eyes": "lentes_redondos"},
		{"outfit": "cortavientos", "acc_feet": "zapatillas_blancas"},
		{"acc_feet": "guayos_plata"},
		{"acc_feet": "guayos_lava", "acc_neck": "bufanda"},
		{"outfit": "jeans", "acc_head": "boina", "acc_eyes": "lentes_redondos"},
	]
	var ok := true
	for l in looks:
		var cfg: Dictionary = base.duplicate(true)
		for k in l:
			cfg[k] = l[k]
		var v := VBoxContainer.new()
		var a := Avatar.build_full(cfg, 136)
		v.add_child(a)
		var lb := Label.new()
		lb.text = ", ".join(l.values())
		lb.add_theme_font_size_override("font_size", 9)
		lb.custom_minimum_size = Vector2(136, 0)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(lb)
		grid.add_child(v)
	for id in ["camisa_chinos", "gabardina", "parka_roja", "blazer_terciopelo", "cortavientos", "zapatillas_blancas", "mocasines", "botas_chelsea", "guayos_plata", "guayos_lava", "bufanda", "boina", "lentes_redondos"]:
		if Avatar.slot_of(id) == "" or ShopEngine.cosmetic_price(p, id) <= 0:
			print("FALLA catálogo ", id)
			ok = false
	for i in range(20):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/wardrobe.png"))
	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
