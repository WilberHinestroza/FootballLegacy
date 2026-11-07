extends Node
## Capturas del campo de entrenamiento 3D: cada foco en 3 momentos.
const TrainingStage = preload("res://ui/common/TrainingStage.gd")

func _ready() -> void:
	var cv := CanvasLayer.new()
	add_child(cv)
	var box := VBoxContainer.new()
	box.position = Vector2(20, 20)
	box.size = Vector2(700, 260)
	cv.add_child(box)
	var cfg := Avatar.random_config(7)
	for key in ["physical", "technical", "mental", "keeper"]:
		var st = TrainingStage.make(cfg, key, key == "keeper", 240)
		box.add_child(st)
		st.custom_minimum_size = Vector2(700, 240)
		for k in 3:
			await get_tree().create_timer(1.6 + k * 1.1).timeout
			get_viewport().get_texture().get_image().save_png("res://build/training_%s_%d.png" % [key, k])
		var done := [false]
		st.play_session(func() -> void: done[0] = true)
		var t0 := Time.get_ticks_msec()
		var min_d := 99.0
		var cones: Array = TrainingStage.SLALOM_CONES + TrainingStage.LANE_CONES + [TrainingStage.PASS_CONE]
		while not done[0] and Time.get_ticks_msec() - t0 < 8000:
			await get_tree().process_frame
			var ap: Vector3 = st._portrait.avatar.position / st._k
			for c: Vector2 in cones:
				min_d = minf(min_d, Vector2(ap.x, ap.z).distance_to(c))
		print("CONOS %s distancia_minima=%.2f m" % [key, min_d])
		print("SESION %s fin=%s ms=%d" % [key, done[0], Time.get_ticks_msec() - t0])
		st.queue_free()
		await get_tree().process_frame
	print("PROBE OK")
	get_tree().quit()
