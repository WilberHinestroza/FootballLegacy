extends Node3D
## Temporal: gorras de frente, de lado y 3/4 -> build/hats.png
const IDS := ["gorra", "gorro_lana", "cinta", "boina"]
func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.45, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 22.0
	add_child(cam)
	get_viewport().size = Vector2i(400, 400)
	var sheet := Image.create(400 * 3, 400 * IDS.size(), false, Image.FORMAT_RGBA8)
	for r in IDS.size():
		var av := PlayerAvatar.new()
		add_child(av)
		var cfg := Avatar.random_config(7)
		cfg["acc_head"] = IDS[r]
		Avatar3D.apply(av, cfg)
		for k in 8:
			await get_tree().process_frame
		var head := av.skeleton.global_transform * av.skeleton.get_bone_global_pose(ItemCatalog.find_bone(av.skeleton, "Head")).origin + Vector3(0, 0.12, 0)
		var angs := [0.0, 0.9, 1.57]
		for c in 3:
			var a: float = angs[c]
			cam.global_position = head + Vector3(sin(a), 0.25, cos(a)) * 1.5
			cam.look_at(head)
			for k in 4:
				await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(0, 0, 400, 400), Vector2i(c * 400, r * 400))
		av.queue_free()
	sheet.save_png(ProjectSettings.globalize_path("res://build/hats.png"))
	get_tree().quit()
