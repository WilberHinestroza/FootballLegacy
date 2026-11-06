extends Control
## ESTADIO VIVO + cambios + fuera de juego + paredes (10-oct). Captura REAL.
##   godot --path . --resolution 864x936 res://tools/LiveStadiumProbe.tscn
func _ctx(sd: int) -> Dictionary:
	return {"seed": sd, "us": Color(0.2, 0.4, 0.9), "them": Color(0.85, 0.2, 0.2),
		"user": {"num": "9", "name": "WILBER", "look": {"tint_base": "#8a5a3b", "tint_hair": "#2b2320"}},
		"mates": [{"num": "10", "name": "PEREZ"}, {"num": "7", "name": "GOMEZ"}],
		"rivals": [{"num": "4", "name": "LOPEZ"}, {"num": "5", "name": "DIAZ"}, {"num": "2", "name": "RUIZ"}],
		"our_gk": {"num": "1", "name": "ARQUERO"}, "their_gk": {"num": "1", "name": "RIVAL"}}

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var fails: int = 0
	var views: Array = []
	for i in range(4):
		var v := PitchView.new()
		v.cam_mode = "tv" if i == 2 else "arco"
		v.board_colors = [Color(0.2, 0.4, 0.9), Color(0.85, 0.2, 0.2)]
		v.night = i == 2
		v.position = Vector2((i % 2) * 432, (i / 2) * 468)
		v.size = Vector2(432, 460)
		v.clip_contents = true
		add_child(v)
		views.append(v)
	# 0: cambio
	var sub: Dictionary = PitchPlays.sub_scene(_ctx(3), "Juan Perez", "Luis Gomez", true, false, false)
	(views[0] as PitchView).setup(sub["scene"])
	# 1: pase filtrado que termina en fuera de juego
	var off_steps: Array = []
	var off_ctx: Dictionary = {}
	for sd in range(60):
		var c := _ctx(sd)
		var st: Array = PitchPlays.outcome_for("through_ball", false, false, c)
		for s in st:
			if (s as Dictionary).has("flag"):
				off_steps = st
				off_ctx = c
				break
		if not off_steps.is_empty():
			break
	if off_steps.is_empty():
		fails += 1
		print("FAIL ningún pase filtrado fallado terminó en fuera de juego")
	else:
		(views[1] as PitchView).setup(PitchPlays.scene_for("through_ball", off_ctx))
	# 2: tribuna festejando (TV, noche)
	(views[2] as PitchView).setup(PitchPlays.scene_for("shot_on_goal", _ctx(3)))
	(views[2] as PitchView).crowd_hype(6.0)
	# 3: paredes
	var v3: PitchView = views[3]
	v3.setup(PitchPlays.scene_for("one_two", _ctx(3)))
	await get_tree().process_frame
	await get_tree().process_frame
	(views[0] as PitchView).play(sub["steps"])
	if not off_steps.is_empty():
		(views[1] as PitchView).play(off_steps)
	var mg: PitchMinigame = v3.start_minigame("pass", "one_two", 0.3, 1.0)
	v3.focus_on(["user", "m1", "m2"], [], 1.7)
	var got := {}
	v3.minigame_done.connect(func(r): got.merge(r))
	if mg._combo_total != 2:
		fails += 1
		print("FAIL la pared (one_two) debía tener 2 toques previos: ", mg._combo_total)
	var u0: Vector2 = v3.npos("user")
	var shot_at := [1.5, 2.3]
	var t0: int = Time.get_ticks_msec()
	var k: int = 0
	var walls: int = 0
	while Time.get_ticks_msec() - t0 < 9000 and (k < shot_at.size() or got.is_empty()):
		await get_tree().process_frame
		var el: float = (Time.get_ticks_msec() - t0) / 1000.0
		if k < shot_at.size() and el >= float(shot_at[k]):
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/live_stadium_%d.png" % k))
			k += 1
		# Jugar las paredes: tocar a un compañero LIBRE cuando lo haya.
		if got.is_empty() and mg._wall.is_empty() and mg.t > 0.5 and el > 1.6:
			for id in ["m1", "m2"]:
				if mg.lane_open(id):
					if mg._combo_done < mg._combo_total:
						walls += 1
					var px: Vector2 = v3.to_screen(v3.npos(id))
					for pressed in [true, false]:
						var e := InputEventMouseButton.new()
						e.button_index = MOUSE_BUTTON_LEFT
						e.pressed = pressed
						e.position = px
						v3._gui_input(e)
					break
	if got.is_empty() or int(got.get("combo", -1)) != 2 or not got.has("receiver"):
		fails += 1
		print("FAIL paredes: se esperaban 2 paredes y un pase final: ", got)
	if v3.npos("user").y >= u0.y - 0.1:
		fails += 1
		print("FAIL paredes: el usuario debía avanzar: ", u0, " -> ", v3.npos("user"))
	# Fórmulas: la pared limpia abre el pase; el rebote existe.
	if not (DecisionResolver.combo_pass_clearance(0.05, [0.2, 0.2], 0.5) > 0.05 and DecisionResolver.combo_pass_clearance(0.05, [], 0.5) == 0.05):
		fails += 1
		print("FAIL fórmula de paredes")
	print("paredes jugadas: ", walls, " · resultado: ", got)
	print("PROBE ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
