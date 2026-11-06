extends Control
## Captura REAL de lo nuevo del editor/Tienda (9-oct).
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.11, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var base: Dictionary = Avatar.random_config(7)
	for k in ["face", "nose", "ears", "rasgo", "outfit"] + Avatar.ACC_SLOTS:
		base.erase(k)
	base["hair"] = "rapado"
	base["tint_hair"] = "#2b2320"
	base["tint_base"] = "#d9a577"
	var grid := GridContainer.new()
	grid.columns = 6
	grid.position = Vector2(4, 4)
	add_child(grid)
	for h in ["afro", "calvo", "flequillo", "coleta", "puntas", "degradado", "rizos_largos", "raya"]:
		var c := base.duplicate(); c["hair"] = h
		grid.add_child(_cell(Avatar.build(c, 88), h))
	for pair in [["nose", "grande"], ["nose", "aguilena"], ["nose", "chata"], ["ears", "grandes"], ["rasgo", "mandibula"], ["rasgo", "redonda"], ["rasgo", "pecas"], ["rasgo", "cejas"], ["rasgo", "cicatriz"]]:
		var c := base.duplicate(); c[pair[0]] = pair[1]
		grid.add_child(_cell(Avatar.build(c, 88), pair[1]))
	for o in ["franela", "chaleco", "oversize", "traje_gris", "retro", "seda", "hoodie_negro"]:
		var c := base.duplicate(); c["outfit"] = o
		grid.add_child(_cell(Avatar.build_full(c, 88), o))
	for gid in ["guayos_azul", "guayos_morado", "guayos_rojo", "guayos_arcoiris"]:
		var c := base.duplicate(); c["acc_feet"] = gid
		grid.add_child(_cell(Avatar.build_full(c, 88), gid.substr(7)))
	var c2 := base.duplicate(); c2["hair"] = "afro"; c2["rasgo"] = "pecas"
	grid.add_child(_cell(Avatar.build_anim(c2, "celeb_baile", 88, true), "anim afro"))
	for i in range(30):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/avatar_new.png"))
	print("CAPTURA OK")
	get_tree().quit(0)

func _cell(n: Control, label: String) -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(92, 0)
	v.add_theme_constant_override("separation", 0)
	n.custom_minimum_size = Vector2(88, 88)
	v.add_child(n)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 10)
	v.add_child(l)
	return v
