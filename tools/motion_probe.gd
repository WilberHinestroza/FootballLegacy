extends Control
## MOVIMIENTO (11-oct, Wilber: "en vez de correr se teletransportan"): mide,
## cuadro a cuadro, cuanto se mueve cada jugador en pantalla durante un
## cambio y varias jugadas. Velocidad en "cuerpos por segundo" (1 cuerpo =
## 40 px, la altura del jugador). Un velocista real: ~4,5 cuerpos/s.
##   godot --path . --resolution 864x936 res://tools/MotionProbe.tscn
func _ctx(sd: int) -> Dictionary:
	return {"seed": sd, "us": Color(0.2, 0.4, 0.9), "them": Color(0.85, 0.2, 0.2),
		"user": {"num": "9", "name": "WILBER"}, "mates": [{"num": "10", "name": "PEREZ"}, {"num": "7", "name": "GOMEZ"}],
		"rivals": [{"num": "4", "name": "LOPEZ"}, {"num": "5", "name": "DIAZ"}, {"num": "2", "name": "RUIZ"}],
		"our_gk": {"num": "1", "name": "ARQUERO"}, "their_gk": {"num": "1", "name": "RIVAL"}}

func _measure(v: PitchView, label: String, steps: Array) -> float:
	v.play(steps)
	var done := [false]
	v.finished.connect(func(): done[0] = true, CONNECT_ONE_SHOT)
	var last := {}
	var win := {}
	var worst: float = 0.0
	var worst_id: String = ""
	var no_run: int = 0
	var t_prev: int = Time.get_ticks_usec()
	while not done[0]:
		await get_tree().process_frame
		var dt: float = maxf(get_process_delta_time(), 0.001)   # el reloj del motor, el mismo que mueve la jugada
		for id in v._actors:
			if bool(v._actors[id].get("extra", false)):
				continue
			var px: Vector2 = v._p(v._actors[id]["pos"])
			if last.has(id):
				# Promedio de 4 cuadros: un cuadro suelto con el reloj corrido no cuenta.
				var hist: Array = win.get(id, [])
				hist.append([px.distance_to(last[id]), dt])
				if hist.size() > 4:
					hist.pop_front()
				win[id] = hist
				var dsum: float = 0.0
				var tsum: float = 0.0
				for h in hist:
					dsum += float(h[0])
					tsum += float(h[1])
				var sp: float = dsum / maxf(tsum, 0.001) / 40.0
				if hist.size() == 4 and sp > worst:
					worst = sp
					worst_id = id
				var an: String = String(v._actors[id]["anim"])
				if sp > 1.5 and an == "idle":
					no_run += 1
			last[id] = px
	print("%-16s pico %.1f cuerpos/s (%s) · cuadros deslizando sin correr: %d" % [label, worst, worst_id, no_run])
	return worst

func _ready() -> void:
	var v := PitchView.new()
	v.board_colors = [Color(0.2, 0.4, 0.9), Color(0.85, 0.2, 0.2)]
	v.size = Vector2(432, 460)
	v.clip_contents = true
	add_child(v)
	var worst: float = 0.0
	var sub: Dictionary = PitchPlays.sub_scene(_ctx(3), "Juan Perez", "Luis Gomez", true, false, false)
	v.setup(sub["scene"])
	await get_tree().process_frame
	await get_tree().process_frame
	worst = maxf(worst, await _measure(v, "cambio", sub["steps"]))
	for kind in ["counter_run", "through_ball", "cross", "dribble", "tackle", "shot_on_goal", "key_pass", "pressing", "one_on_one", "long_shot", "chip_shot", "block_shot", "last_ditch_tackle"]:
		for ok in [true, false]:
			var c := _ctx(5)
			v.setup(PitchPlays.scene_for(kind, c))
			await get_tree().process_frame
			worst = maxf(worst, await _measure(v, kind + (" ok" if ok else " falla"), PitchPlays.outcome_for(kind, ok, false, c)))
	var good: bool = worst <= 14.5   # 11-oct: carrera 7,5; gestos 12; arquero 13,5   # carrera: 6; regates, barridas y estiradas pueden ir algo mas rapido
	print("PROBE ", "OK" if good else "FAIL", " (pico %.1f)" % worst)
	get_tree().quit(0 if good else 1)
