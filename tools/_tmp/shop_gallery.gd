extends Control
## Temporal: dibuja todas las prendas de la tienda como en sus tarjetas (3D) y guarda captura.
func _ready() -> void:
	Preferences.match_3d = true
	var ids: Array = []
	var which := "acc"
	for a in OS.get_cmdline_user_args():
		which = a
	if which == "big":
		_big()
		return
	if which == "acc":
		for a: Dictionary in Avatar.ACCESSORIES:
			ids.append(String(a.id))
	elif which == "bot":
		for t: Dictionary in Avatar.BOTTOMS:
			ids.append("bot_" + String(t.src))
	else:
		for t: Dictionary in Avatar.TOPS:
			ids.append("top_" + String(t.src))
	var g := GridContainer.new()
	g.columns = 8
	add_child(g)
	var base := Avatar.random_config(7)
	base["tint_clothing"] = "#c0392b"
	base["tint_shorts"] = "#f0f0f0"
	for id: String in ids:
		var cfg: Dictionary = base.duplicate(true)
		var slot := Avatar.slot_of(id)
		if slot == "top" or slot == "bottom":
			cfg[slot] = Avatar.piece_src(id)
		elif slot == "acc_shoes":
			cfg["outfit"] = "jeans"
			cfg[slot] = id
		elif slot == "acc_feet":
			Avatar.strip_street(cfg)
			cfg[slot] = id
		else:
			cfg[slot] = id
		var v := VBoxContainer.new()
		if slot == "acc_feet" or slot == "acc_shoes":
			v.add_child(Avatar.build_feet(cfg, 132))
		elif slot in ["acc_head", "acc_eyes", "acc_ears", "acc_neck"]:
			v.add_child(Avatar.build(cfg, 132))
		else:
			v.add_child(Avatar.build_full(cfg, 132))
		var l := Label.new()
		l.text = id
		l.add_theme_font_size_override("font_size", 11)
		v.add_child(l)
		g.add_child(v)
	await get_tree().create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/USUARIO/AppData/Local/Temp/claude/C--Users-USUARIO-Desktop-Proyectos-Godot-MiniSoccer3D/2cf8cef3-4f2e-4869-bd4d-afce45cbc8cf/scratchpad/shop_%s.png" % which)
	get_tree().quit()


func _big() -> void:
	var h := HBoxContainer.new()
	add_child(h)
	var looks := [
		{"shirt_color": Color(0.75, 0.1, 0.15), "shorts_color": Color(0.95, 0.95, 0.95), "socks_color": Color(0.75, 0.1, 0.15)},
		{"shirt_color": Color(0.1, 0.2, 0.5), "shorts_color": Color(0.1, 0.12, 0.25), "socks_color": Color(0.9, 0.9, 0.9)},
		{"shirt_color": Color(0.95, 0.95, 0.95), "long_sleeves": true, "long_pants": true, "shorts_color": Color(0.23, 0.35, 0.53), "socks_color": Color(0.23, 0.35, 0.53), "use_sole": true, "boots_color": Color("#f2f2f4"), "sole_color": Color("#c9ccd2")},
		{"shirt_color": Color(0.98, 0.82, 0.12), "long_sleeves": true, "gloves": true, "glove_color": Color(0.95, 0.95, 0.96), "glove_color2": Color(0.98, 0.82, 0.12).darkened(0.45), "shorts_color": Color(0.1, 0.1, 0.1)},
	]
	for i in looks.size():
		var p := PlayerPortrait.new(300, Color(0.2, 0.3, 0.25), true)
		p.avatar.set_colors(looks[i])
		if i == 3:
			p.avatar.anim.play("keeper_idle")
		h.add_child(p)
	var p2 := PlayerPortrait.new(300, Color(0.2, 0.3, 0.25), false, "feet")
	p2.avatar.set_colors(looks[0])
	h.add_child(p2)
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/USUARIO/AppData/Local/Temp/claude/C--Users-USUARIO-Desktop-Proyectos-Godot-MiniSoccer3D/2cf8cef3-4f2e-4869-bd4d-afce45cbc8cf/scratchpad/shop_big.png")
	get_tree().quit()
