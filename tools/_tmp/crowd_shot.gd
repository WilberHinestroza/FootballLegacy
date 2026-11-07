extends Node3D
## Primer plano de la grada (con ventana): normal y celebrando gol.
func _ready() -> void:
	FieldBuilder.time_of_day = 0
	FieldBuilder.stars = 4
	FieldBuilder.home_color = Color("#1f7a4d")
	FieldBuilder.home_color2 = Color.WHITE
	FieldBuilder.away_color = Color("#c0392b")
	FieldBuilder.crowd_fill = 0.95
	FieldBuilder.build(self)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	cam.look_at_from_position(Vector3(4, 3.5, -33), Vector3(1, 4.0, -44), Vector3.UP)
	cam.make_current()
	for i in 30:
		await get_tree().process_frame
	_shot("crowd_a")
	var n := 0
	for mmi in find_children("Crowd*", "MultiMeshInstance3D", true, false):
		n += (mmi as MultiMeshInstance3D).multimesh.instance_count
	print("PUBLICO ", n)
	FieldBuilder.set_crowd_excitement(self, 1.0)
	await get_tree().create_timer(0.5).timeout
	_shot("crowd_b")
	cam.look_at_from_position(Vector3(0, 16, 30), Vector3(0, 2, -20), Vector3.UP)
	cam.fov = 50
	await get_tree().create_timer(0.3).timeout
	_shot("crowd_c")
	get_tree().quit(0)

func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/%s.png" % n))
