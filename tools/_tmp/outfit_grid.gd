extends Control
## Cuerpo entero de varias prendas (con ventana). Args: ids separados por coma.
func _ready() -> void:
	var ids: PackedStringArray = (OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "floral").split(",")
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.22, 0.26)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var g := GridContainer.new()
	g.columns = 6
	add_child(g)
	for id in ids:
		var cfg := Avatar.random_config(77)
		cfg["outfit"] = id
		cfg["top"] = ""
		cfg["bottom"] = ""
		cfg["acc_shoes"] = "zapatillas_retro" if id == ids[0] else ""
		cfg["full"] = true
		var c := Avatar3D.build(cfg, 220)
		if c != null:
			g.add_child(c)
	for i in 90:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/outfits.png"))
	get_tree().quit(0)
