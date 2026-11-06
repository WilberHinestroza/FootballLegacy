extends Node3D
## Tira de cuadros de una animación del jugador (con ventana):
##   godot --path . res://tools/AnimStrip.tscn -- <anim> [cuadros] [lado|frente]
## Deja build/anim_<anim>.png con los cuadros en fila.
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var an: String = args[0] if args.size() > 0 else "walk"
	var n: int = int(args[1]) if args.size() > 1 else 8
	var view: String = args[2] if args.size() > 2 else "lado"
	var pose: String = args[3] if args.size() > 3 else ""
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.68)
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.25, 0.5, 0.28)
	floor.material_override = fm
	add_child(floor)
	var av := PlayerAvatar.new()
	add_child(av)
	if OS.get_cmdline_user_args().has("suit"):
		av.queue_free()
		av = CeremonyKit.suit_person(self, Color(0.7, 0.1, 0.1), "dt")
	# street=<arriba>,<abajo>: ropa de calle del vestuario (Avatar3D.STREET), p. ej. street=polo,jeans
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("street="):
			var parts := a.substr(7).split(",")
			Avatar3D.apply(av, {"top": parts[0], "bottom": parts[1] if parts.size() > 1 else parts[0],
				"tint_base": "#8d5a3c", "hair": "corto"})
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.position = Vector3(5.5, 1.0, 0.0) if view == "lado" else Vector3(1.6, 1.0, 5.2)
	cam.look_at(Vector3(0, 0.85, 0))
	# cerca: primer plano de las piernas (revisar la ropa)
	# cerca=<altura>: lo mismo apuntando a otra altura (1.0 puños, 1.35 cuello)
	for a: String in OS.get_cmdline_user_args():
		var hy := 0.45 if a == "cerca" else (float(a.substr(6)) if a.begins_with("cerca=") else -1.0)
		if hy > 0.0:
			cam.position = cam.position * 0.4 + Vector3(0, hy - 0.9, 0)
			cam.look_at(Vector3(0, hy, 0))
	cam.make_current()
	get_viewport().size = Vector2i(360, 480) if false else get_viewport().size
	av.anim.play(an)
	av.anim.speed_scale = 0.0
	var cup: Node3D = null
	if pose != "":
		av.pose_arms(pose, 0.01)
		cup = TrophyBuilder.build("mvp", Color(1.0, 0.82, 0.28))
		cup.scale = Vector3.ONE * 1.55
		add_child(cup)
		av.skeleton.skeleton_updated.connect(func() -> void:
			cup.global_position = av.hands_position() - Vector3.UP * 0.18
			cup.global_rotation.y = av.global_rotation.y - PI)
		for i in 40:
			await get_tree().process_frame
	var length := av.anim.current_animation_length
	var strip: Image = null
	for i in n:
		av.anim.seek(length * float(i) / float(n), true)
		if cup != null:
			await get_tree().create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var w := img.get_width()
		var h := img.get_height()
		var cw := int(h * 0.5)
		var crop := img.get_region(Rect2i((w - cw) / 2, 0, cw, h))
		if strip == null:
			strip = Image.create(cw * n, h, false, crop.get_format())
		strip.blit_rect(crop, Rect2i(0, 0, cw, h), Vector2i(cw * i, 0))
	if not OS.get_cmdline_user_args().has("full"):
		strip.resize(strip.get_width() / 2, strip.get_height() / 2)
	strip.save_png("res://build/anim_%s_%s%s.png" % [an, view, pose])
	print("STRIP ", an, " len=", length)
	get_tree().quit(0)
