extends Control
## Captura REAL (con render) de jugadores con las piezas del avatar.
##   godot --path . --resolution 576x1024 res://tools/AvatarRenderProbe.tscn
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.11, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var cfgs := [
		{"hair": "mono", "face": "bigote", "tint_base": "#d9a577", "tint_hair": "#2b2320", "acc_feet": "guayos_verde"},
		{"hair": "trenzas", "face": "candado", "tint_base": "#5f3a26", "tint_hair": "#141010", "acc_feet": "guayos_oro"},
		{"hair": "rastas", "face": "", "tint_base": "#8a5a3b", "tint_hair": "#3a2a1a", "acc_feet": "guayos_rosa"},
		{"hair": "engominado", "face": "barba3", "tint_base": "#f4d6c0", "tint_hair": "#5a3b26", "acc_feet": "guayos_negro"},
		{"hair": "rapado", "face": "barba_larga", "tint_base": "#b57e56", "tint_hair": "#2b2320", "acc_feet": "guayos_blanco"},
		{"hair": "mono", "face": "barba_larga", "tint_base": "#eec1a3", "tint_hair": "#d8c07a", "outfit": "traje_negro", "acc_neck": "cadena_fina"},
	]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(20, 20)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	add_child(grid)
	for c in cfgs:
		var cc: Dictionary = c.duplicate()
		cc["tint_clothing"] = "#c0392b"
		cc["tint_shorts"] = "#f0f0f0"
		grid.add_child(Avatar.build_full(cc, 144))
	var row := HBoxContainer.new()
	row.position = Vector2(20, 680)
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	for c in cfgs:
		row.add_child(Avatar.build(c, 72))
	for i in range(10):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/avatar_piezas_nuevas.png"))
	print("CAPTURA OK")
	get_tree().quit(0)
