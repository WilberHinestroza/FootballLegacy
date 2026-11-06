extends Node3D
## Tira de cuadros de una animación del jugador (con ventana):
##   godot --path . res://tools/AnimStrip.tscn -- <anim> [cuadros] [lado|frente]
## Deja build/anim_<anim>.png con los cuadros en fila.
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var an: String = args[0] if args.size() > 0 else "walk"
	var n: int = int(args[1]) if args.size() > 1 else 8
	var view: String = args[2] if args.size() > 2 else "lado"
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
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.position = Vector3(5.5, 1.0, 0.0) if view == "lado" else Vector3(1.6, 1.0, 5.2)
	cam.look_at(Vector3(0, 0.85, 0))
	cam.make_current()
	get_viewport().size = Vector2i(360, 480) if false else get_viewport().size
	av.anim.play(an)
	av.anim.speed_scale = 0.0
	var length := av.anim.current_animation_length
	var strip: Image = null
	for i in n:
		av.anim.seek(length * float(i) / float(n), true)
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
	strip.resize(strip.get_width() / 2, strip.get_height() / 2)
	strip.save_png("res://build/anim_%s_%s.png" % [an, view])
	print("STRIP ", an, " len=", length)
	get_tree().quit(0)
