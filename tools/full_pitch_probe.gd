extends Control
## CANCHA COMPLETA (10-oct): por cámara, 4 vistas a tamaño de celular —
## ataque (encuadre de siempre), cancha entera, jugada defensiva en tu
## mitad y jugada de armado estirada. Captura REAL. Sin --headless:
##   godot --path . --resolution 864x936 res://tools/FullPitchProbe.tscn
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var ctx := {"seed": 3, "us": Color(0.2, 0.4, 0.9), "them": Color(0.85, 0.2, 0.2),
		"user": {"num": "9", "name": "WILBER", "look": {"tint_base": "#8a5a3b", "tint_hair": "#2b2320"}},
		"mates": [{"num": "10", "name": "PEREZ"}, {"num": "7", "name": "GOMEZ"}],
		"rivals": [{"num": "4", "name": "LOPEZ"}, {"num": "5", "name": "DIAZ"}, {"num": "2", "name": "RUIZ"}],
		"our_gk": {"num": "1", "name": "ARQUERO"}, "their_gk": {"num": "1", "name": "RIVAL"}}
	var fails: int = 0
	for mode in ["arco", "tv", "iso"]:
		var views: Array = []
		var kinds := ["shot_on_goal", "shot_on_goal", "tackle", "counter_run"]
		for i in range(4):
			var v := PitchView.new()
			v.cam_mode = mode
			v.board_colors = [Color(0.2, 0.4, 0.9), Color(0.85, 0.2, 0.2)]
			v.night = i == 3
			v.score_text = "2 - 1"
			v.position = Vector2((i % 2) * 432, (i / 2) * 468)
			v.size = Vector2(432, 460)
			v.clip_contents = true
			add_child(v)
			v.setup(PitchPlays.scene_for(kinds[i], ctx))
			views.append(v)
		await get_tree().process_frame
		await get_tree().process_frame
		(views[1] as PitchView).show_whole_pitch(false)
		# Ida y vuelta de coordenadas con cada encuadre (toques = dibujo).
		for v2 in views:
			var pv: PitchView = v2
			for q in [Vector2(0.3, 0.2), Vector2(0.7, 0.6), Vector2(0.5, 0.95)]:
				var back: Vector2 = pv.from_px(pv.to_px(q))
				if back.distance_to(q) > 0.002:
					fails += 1
					print("FAIL ida y vuelta %s flip=%s: %s -> %s" % [mode, pv.scene_flip, q, back])
			# El usuario queda dentro de la pantalla en el encuadre de la jugada.
			if pv != views[1]:
				var sp: Vector2 = pv.to_px(pv.npos("user")) * pv.cam_zoom + pv._cam_offset()
				if not Rect2(Vector2.ZERO, pv.size).grow(-8.0).has_point(sp):
					fails += 1
					print("FAIL usuario fuera de cuadro %s flip=%s: %s" % [mode, pv.scene_flip, sp])
		await get_tree().create_timer(0.3).timeout
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://_pixellab_preview/full_pitch_%s.png" % mode))
		for v3 in views:
			(v3 as Node).queue_free()
		await get_tree().process_frame
	print("PROBE ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
