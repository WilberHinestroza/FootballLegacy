extends Node3D
## Temporal: gorras de frente, de lado y 3/4 -> build/hats.png
const IDS := ["lentes_sol", "aviador", "lentes_redondos", "auriculares", "cadena_fina", "cadena_gruesa", "bufanda", "pendientes", "reloj"]
var only := []
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
	var sheet: Image
	var ids: Array = IDS
	for a in OS.get_cmdline_user_args():
		ids = ["gorra", "gorro_lana", "cinta", "boina"] if a == "hats" else IDS
	sheet = Image.create(400 * 3, 400 * ids.size(), false, Image.FORMAT_RGBA8)
	for r in ids.size():
		var av := PlayerAvatar.new()
		add_child(av)
		var cfg := Avatar.random_config(7)
		var id: String = ids[r]
		cfg[Avatar.slot_of(id)] = id
		Avatar3D.apply(av, cfg)
		for k in 8:
			await get_tree().process_frame
		var wrist: bool = id == "reloj"
		var head := av.skeleton.global_transform * av.skeleton.get_bone_global_pose(ItemCatalog.find_bone(av.skeleton, "LeftHand" if wrist else "Head")).origin + Vector3(0, 0.12 if ids.size() == 4 else -0.08, 0)
		var angs := [0.0, 0.9, 1.57]
		for c in 3:
			var a: float = angs[c]
			cam.global_position = head + Vector3(sin(a), 0.25, cos(a)) * (0.8 if wrist else (1.5 if ids.size() == 4 else 1.9))
			cam.look_at(head)
			for k in 4:
				await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(0, 0, 400, 400), Vector2i(c * 400, r * 400))
		av.queue_free()
	sheet.save_png(ProjectSettings.globalize_path("res://build/hats.png"))
	get_tree().quit()
