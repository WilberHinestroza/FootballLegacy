extends Control
## FUERA DE JUEGO BIEN MEDIDO (11-oct). En cada jugada marcada como fuera
## de juego: el receptor tiene que estar DE VERDAD mas alla del penultimo
## rival (contando a todos los de la cancha) y la linea dibujada tiene que
## pasar por ese rival. Y la linea del VAR tiene que coincidir con el fallo.
##   godot --path . --resolution 864x936 res://tools/OffsideProbe.tscn
func _ctx(sd: int) -> Dictionary:
	return {"seed": sd, "us": Color(0.2, 0.4, 0.9), "them": Color(0.85, 0.2, 0.2),
		"user": {"num": "9", "name": "WILBER"}, "mates": [{"num": "10", "name": "PEREZ"}, {"num": "7", "name": "GOMEZ"}],
		"rivals": [{"num": "4", "name": "LOPEZ"}, {"num": "5", "name": "DIAZ"}, {"num": "2", "name": "RUIZ"}],
		"our_gk": {"num": "1", "name": "ARQUERO"}, "their_gk": {"num": "1", "name": "RIVAL"}}

func _ready() -> void:
	var v := PitchView.new()
	v.board_colors = [Color(0.2, 0.4, 0.9), Color(0.85, 0.2, 0.2)]
	v.size = Vector2(432, 460)
	v.clip_contents = true
	add_child(v)
	var fails: int = 0
	var checked: int = 0
	var shot: bool = false
	var stacked: int = 0
	for kind in ["through_ball", "one_two"]:
		for sd in range(40):
			var c := _ctx(sd)
			c["force_offside"] = true
			var steps: Array = PitchPlays.outcome_for(kind, false, false, c)
			var has_flag: bool = false
			for s in steps:
				if (s as Dictionary).has("flag") and bool(s["flag"]):
					has_flag = true
			if not has_flag:
				continue
			v.setup(PitchPlays.scene_for(kind, c))
			await get_tree().process_frame
			v.play(steps)
			# Hasta que se levanta el banderin.
			var guard: int = 0
			while not v._flag_up and guard < 900:
				await get_tree().process_frame
				guard += 1
			await get_tree().process_frame
			# El receptor = el companero mas adelantado.
			var recv: String = "m1"
			for id in ["m1", "m2", "user"]:
				if v.has_actor(id) and v.npos(id).y < v.npos(recv).y:
					recv = id
			var line: float = v.offside_line_for(recv)
			checked += 1
			if not (v.npos(recv).y < line - 0.005):
				fails += 1
				print("FAIL %s sd=%d: marcado adelantado pero no lo esta (receptor y=%.3f, penultimo rival y=%.3f)" % [kind, sd, v.npos(recv).y, line])
			elif absf(v._line_y - line) > 0.012:
				fails += 1
				print("FAIL %s sd=%d: la linea dibujada (%.3f) no pasa por el penultimo rival (%.3f)" % [kind, sd, v._line_y, line])
			# Orden: nadie de relleno parado encima de los que juegan.
			for eid in v._actors:
				if not bool(v._actors[eid].get("extra", false)):
					continue
				for nid in v._actors:
					if bool(v._actors[nid].get("extra", false)) or bool(v._actors[nid].get("ref", false)):
						continue
					if v._p(v._actors[eid]["pos"]).distance_to(v._p(v._actors[nid]["pos"])) < 22.0:
						stacked += 1
			if not shot:
				shot = true
				get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/offside.png"))
			v._tween.kill()
	# VAR: la linea (si hay) tiene que coincidir con el veredicto.
	var var_checked: int = 0
	for mode in ["annulled", "valid"]:
		PitchPlays.var_mode = mode
		for sd in range(30):
			var c2 := _ctx(sd)
			var scene: Dictionary = PitchPlays.scene_for("shot_on_goal", c2)
			var steps2: Array = PitchPlays.outcome_for("shot_on_goal", true, true, c2)
			var ly: float = -9.0
			var text: String = ""
			for s2 in steps2:
				if (s2 as Dictionary).has("line") and float(s2["line"]) > -1.0:
					ly = float(s2["line"])
				if String((s2 as Dictionary).get("flash", "")).contains("ANULADO"):
					text = String(s2["flash"])
			var uy: float = 0.2
			for a in scene["actors"]:
				if String(a["id"]) == "user":
					uy = (a["pos"] as Vector2).y
			var_checked += 1
			if mode == "annulled" and text.contains("FUERA DE JUEGO") and not (ly > -1.0 and uy < ly):
				fails += 1
				print("FAIL VAR anulado por adelantado pero el goleador no pasa la linea (y=%.3f, linea=%.3f)" % [uy, ly])
			if mode == "valid" and ly > -1.0 and uy < ly - 0.012:
				fails += 1
				print("FAIL VAR gol valido con el goleador mas alla de la linea")
	PitchPlays.var_mode = ""
	print("fueras de juego revisados: %d · revisiones VAR: %d" % [checked, var_checked])
	print("jugadores de relleno encima de los de la jugada: %d (en %d jugadas)" % [stacked, checked])
	if stacked > checked / 4:
		fails += 1
		print("FAIL demasiados jugadores encimados en la jugada")
	if checked == 0:
		fails += 1
		print("FAIL no se pudo armar ningun fuera de juego")
	print("PROBE ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
