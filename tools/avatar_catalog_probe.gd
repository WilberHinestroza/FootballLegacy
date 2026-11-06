extends Control
## Captura REAL del catálogo del avatar: peinados (busto y cuerpo entero),
## caras y guayos, y cómo salen en las animaciones (festejo) y en la cancha.
##   godot --path . --resolution 576x1024 res://tools/AvatarCatalogProbe.tscn
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.11, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var base: Dictionary = Avatar.random_config(7)
	base["tint_hair"] = "#2b2320"
	base["tint_base"] = "#d9a577"
	base["face"] = ""
	for k in Avatar.ACC_SLOTS:
		base.erase(k)
	base.erase("outfit")
	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(8, 8)
	add_child(grid)
	for h in Avatar.HAIR_STYLES:
		var c := base.duplicate()
		c["hair"] = h["id"]
		grid.add_child(_cell(Avatar.build(c, 96), h["id"]))
	for h in ["melena", "rastas", "trenzas", "mono", "largo", "cresta", "rulos"]:
		for an in ["celeb_salto", "celeb_rodillas"]:
			var c := base.duplicate()
			c["hair"] = h
			c["face"] = "barba" if h == "rastas" else ""
			c["acc_eyes"] = "lentes_sol" if h == "cresta" else ""
			grid.add_child(_cell(Avatar.build_anim(c, an, 96, true), "%s %s" % [an.substr(6, 5), h]))
	for f in []:
		var c := base.duplicate()
		c["face"] = f["id"]
		grid.add_child(_cell(Avatar.build(c, 96), "cara " + f["id"]))
	for gid in ["guayos_rosa", "guayos_verde", "guayos_oro"]:
		for an in ["celeb_baile", "pitch_run_east", "pitch_idle_south"]:
			var c := base.duplicate()
			c["acc_feet"] = gid
			c["hair"] = "rastas"
			grid.add_child(_cell(Avatar.build_anim(c, an, 96, true), "%s %s" % [an.substr(0, 10), gid.substr(7)]))
	for a in []:
		if a["slot"] == "acc_feet":
			var c := base.duplicate()
			c["acc_feet"] = a["id"]
			grid.add_child(_cell(Avatar.build_full(c, 96), a["id"]))
	for i in range(30):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/avatar_catalog.png"))
	print("CAPTURA OK")
	get_tree().quit(0)

func _cell(n: Control, label: String) -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(110, 0)
	n.custom_minimum_size = Vector2(96, 96)
	v.add_child(n)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 10)
	v.add_child(l)
	return v
