extends Control
## JUEGO AMBIENTAL + objetos de estadio + arcos iguales (10-oct). Captura REAL.
##   godot --path . --resolution 864x936 res://tools/AmbientProbe.tscn
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var fails: int = 0
	var views: Array = []
	for i in range(4):
		var v := PitchView.new()
		v.cam_mode = "tv" if i == 3 else "arco"
		v.board_colors = [Color(0.2, 0.4, 0.9), Color(0.85, 0.2, 0.2)]
		v.night = i == 2
		v.position = Vector2((i % 2) * 432, (i / 2) * 468)
		v.size = Vector2(432, 460)
		v.clip_contents = true
		add_child(v)
		var actor := {"id": "user", "color": Color(0.2, 0.4, 0.9), "num": "9", "name": "WILBER", "user": true}
		# 0: en el banco (sin vos) · 1: cancha entera · 2: con vos, de noche · 3: TV
		v.setup_ambient(Color(0.2, 0.4, 0.9), Color(0.85, 0.2, 0.2), {} if i == 0 else actor, "MF")
		views.append(v)
	await get_tree().process_frame
	await get_tree().process_frame
	var v1: PitchView = views[1]
	v1.show_whole_pitch(false)
	var b0: Vector2 = (views[0] as PitchView).nball()
	var moved: float = 0.0
	var t0: int = Time.get_ticks_msec()
	var shot: int = 0
	var crowd_frames: int = 0
	var frames_n: int = 0
	while Time.get_ticks_msec() - t0 < 7000:
		await get_tree().process_frame
		moved = maxf(moved, (views[0] as PitchView).nball().distance_to(b0))
		# Orden: pasado el arranque, nadie queda parado encima de otro.
		if Time.get_ticks_msec() - t0 > 2500:
			frames_n += 1
			var pv0: PitchView = views[0]
			var ids: Array = []
			for aid in pv0._actors:
				if pv0._actors[aid].has("slot"):
					ids.append(aid)
			var stacked: bool = false
			for i1 in range(ids.size()):
				for i2 in range(i1 + 1, ids.size()):
					if (pv0._actors[ids[i1]]["pos"] as Vector2).distance_to(pv0._actors[ids[i2]]["pos"]) < 0.035:
						stacked = true
			if stacked:
				crowd_frames += 1
		if shot == 0 and Time.get_ticks_msec() - t0 > 3500:
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ambient.png"))
			shot = 1
	print("cuadros con jugadores encimados: %d de %d" % [crowd_frames, frames_n])
	if frames_n > 0 and float(crowd_frames) / float(frames_n) > 0.10:
		fails += 1
		print("FAIL jugadores encimados demasiado seguido")
	if moved < 0.15:
		fails += 1
		print("FAIL la pelota no circula sola: ", moved)
	if (views[0] as PitchView).has_actor("user") or not (views[2] as PitchView).has_actor("user"):
		fails += 1
		print("FAIL en el banco no aparecés; en cancha sí")
	# Arcos del mismo tamaño en la cámara detrás del arco.
	var top_w: float = v1._pw(Vector2(0.5 + PitchView.GOAL_W * 0.5, 0.0)).x - v1._pw(Vector2(0.5 - PitchView.GOAL_W * 0.5, 0.0)).x
	var bot_w: float = v1._pw(Vector2(0.5 + PitchView.GOAL_W * 0.5, 2.0)).x - v1._pw(Vector2(0.5 - PitchView.GOAL_W * 0.5, 2.0)).x
	if absf(top_w - bot_w) > 0.5:
		fails += 1
		print("FAIL los arcos no miden lo mismo: ", top_w, " vs ", bot_w)
	# Ida y vuelta de coordenadas en las dos mitades.
	for q in [Vector2(0.3, 0.2), Vector2(0.7, 1.0), Vector2(0.4, 1.7)]:
		if v1._from_px_w(v1._pw(q)).distance_to(q) > 0.002:
			fails += 1
			print("FAIL ida y vuelta ", q, v1._from_px_w(v1._pw(q)))
	# Zoom acotado: ni más lejos que la cancha entera ni demasiado cerca.
	var fit: float = float(v1._whole_fit()[0])
	v1._cam_to(0.01, Vector2(0.5, 1.0), false)
	var zmin: float = v1.cam_zoom
	v1._cam_to(9.0, Vector2(0.5, 1.0), false)
	if absf(zmin - fit) > 0.01 or v1.cam_zoom > PitchView.ZOOM_MAX + 0.001:
		fails += 1
		print("FAIL zoom sin tope: ", zmin, " ", fit, " ", v1.cam_zoom)
	print("PROBE ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
