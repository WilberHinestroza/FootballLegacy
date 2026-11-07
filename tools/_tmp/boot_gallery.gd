extends Node3D
## Galería de guayos en 3D (de lado y en 3/4) para revisar diseños y logos.
##   godot --path . res://tools/_tmp/BootGallery.tscn   -> build/boots_side.png, build/boots_34.png

const PER_ROW := 5
const GAP := 0.42


func _ready() -> void:
	var ids: Array = ItemCatalog.GUAYOS.keys()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.17, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var avs: Array = []
	for i in ids.size():
		var av := PlayerAvatar.new()
		add_child(av)
		var row := i / PER_ROW
		av.position = Vector3((i % PER_ROW) * GAP, 0.0, -row * 3.0)
		av.rotation.y = PI * 0.5 # de lado: la punta hacia +X
		var c := {"skin_color": Color(0.8, 0.6, 0.45), "shirt_color": Color(0.9, 0.9, 0.9),
			"shorts_color": Color(0.1, 0.1, 0.12), "socks_color": Color(0.95, 0.95, 0.95)}
		c.merge(ItemCatalog.guayos_params(String(ids[i])))
		av.set_colors(c)
		avs.append(av)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.42
	add_child(cam)
	get_viewport().size = Vector2i(2000, 420)
	await _settle()
	var rows := int(ceil(ids.size() / float(PER_ROW)))
	var sheet := Image.create(2000, 420 * rows, false, Image.FORMAT_RGBA8)
	for r in rows:
		cam.position = Vector3((PER_ROW - 1) * GAP * 0.5, 0.11, -r * 3.0 + 1.2)
		cam.far = 2.0
		cam.look_at(cam.position + Vector3(0, 0, -1))
		await _settle()
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, 2000, 420), Vector2i(0, r * 420))
	sheet.save_png(ProjectSettings.globalize_path("res://build/boots_side.png"))
	# 3/4 desde delante y arriba: empeine, cordones y punta
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 30.0
	var sheet2 := Image.create(2000, 420 * rows, false, Image.FORMAT_RGBA8)
	for r in rows:
		var mid := Vector3((PER_ROW - 1) * GAP * 0.5, 0.05, -r * 3.0)
		cam.position = mid + Vector3(0.9, 0.55, 1.5)
		cam.far = 2.6
		cam.look_at(mid + Vector3(0.1, 0.0, 0.0))
		await _settle()
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet2.blit_rect(img, Rect2i(0, 0, 2000, 420), Vector2i(0, r * 420))
	sheet2.save_png(ProjectSettings.globalize_path("res://build/boots_34.png"))
	print("GALERIA guayos: ", ids.size())
	get_tree().quit()


func _settle() -> void:
	for f in 8:
		await get_tree().process_frame
