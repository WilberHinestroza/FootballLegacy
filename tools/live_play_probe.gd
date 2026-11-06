extends "res://tools/ui_gallery_probe.gd"
## OPORTUNIDAD EN VIVO (10-oct): sin menú, el gesto es la jugada. Fuerza
## momentos dentro de un partido real y simula los gestos. slot_3.
##   godot --path . --resolution 432x936 res://tools/LivePlayProbe.tscn
var _fails: int = 0
func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		_fails += 1

func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/live_%s.png" % name))

func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _gesture(pv: PitchView, from: Vector2, to: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = from if pressed else to
		pv._gui_input(e)

func _force(m: Node, kinds: Array) -> void:
	var opts: Array = []
	for k in kinds:
		opts.append({"kind": k, "difficulty": 0.4, "label": k, "risk": "media"})
	m.call("_on_decision_requested", {"minute": 30, "kind": kinds[0], "player": MatchState.user_player, "narration": "Prueba.", "options": opts})
	# Si justo había una repetición (un cambio, una tarjeta), el partido
	# guarda el pedido y lo abre al terminar: esperar a que esté en pantalla.
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 12000 and not ((m.get("decision_panel") as Control).visible and String(m.get("_chosen_kind")) in ["", String(kinds[0])] and (m.get("_pitch") as PitchView).visible and not bool(m.get("_replaying"))):
		await get_tree().process_frame
	await _wait(50)

func _until_free(m: Node) -> void:
	if MatchState.engine != null and MatchState.engine.hold:
		# Con el partido en pausa no llega el resultado del motor: se suelta
		# la jugada a mano para poder forzar la siguiente.
		await _wait(40)
		m.set("_replay_pending", false)
		m.set("_replaying", false)
		(m.get("decision_panel") as Control).visible = false
		m.call("_hide_pitch")
		await _wait(8)
		return
	var t0: int = Time.get_ticks_msec()
	while (bool(m.get("_replaying")) or bool(m.get("_replay_pending")) or (m.get("decision_panel") as Control).visible) and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	await _wait(20)

func _ready() -> void:
	_seed_career()
	await get_tree().process_frame
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	var m: Node = (load("res://scenes/Match/Match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	await _wait(200)
	MatchState.engine.hold = true   # el partido queda quieto: solo pasan las jugadas que fuerza la prueba
	await _wait(120)
	await _until_free(m)
	var pv: PitchView = m.get("_pitch")
	# 11-oct: el modo en vivo quedo ESTACIONADO (apagado por defecto); esta
	# prueba lo prende a mano para que no se rompa mientras tanto.
	_check(not Preferences.live_play, "el modo en vivo viene apagado (partido por decisiones)")
	Preferences.live_play = true

	# 1) Ataque: remate deslizando hacia el arco con la fuerza justa.
	await _force(m, ["shot_on_goal", "key_pass", "dribble"])
	_check(not (m.get("choice_box") as Control).visible and String(m.get("_minigame")) == "live", "ataque: sin menú, se juega en la cancha (%s)" % String(m.get("_minigame")))
	_shot("attack")
	var b: Vector2 = pv.to_screen(pv.nball())
	var g: Vector2 = pv.to_screen(Vector2(0.5 + PitchView.GOAL_W * 0.3, 0.0))
	var len: float = DecisionResolver.SHOT_POWER_IDEAL * pv.aim_span_y() * pv.cam_zoom
	_gesture(pv, b, b + (g - b).normalized() * len)
	await _wait(2)
	_check(String(m.get("_chosen_kind")) == "shot_on_goal", "deslizar hacia el arco = remate (%s)" % String(m.get("_chosen_kind")))
	await _wait(25)
	_shot("attack_after")
	await _until_free(m)

	# 2) Ataque: tocar a un compañero = pase.
	await _force(m, ["key_pass", "dribble"])
	_gesture(pv, pv.to_screen(pv.npos("m2")), pv.to_screen(pv.npos("m2")))
	await _wait(2)
	_check(String(m.get("_chosen_kind")) == "key_pass" and String((m.get("_pitch_ctx") as Dictionary).get("pass_to", "")) == "m2", "tocar a un compañero = pase a ese compañero (%s)" % String(m.get("_chosen_kind")))
	await _until_free(m)

	# 3) Ataque: deslizar al costado = regate.
	await _force(m, ["dribble", "key_pass"])
	var u: Vector2 = pv.to_screen(pv.npos("user"))
	_gesture(pv, u + Vector2(0, 60), u + Vector2(0, 60) + pv.screen_dir_x() * 70.0)
	await _wait(2)
	_check(String(m.get("_chosen_kind")) == "dribble", "deslizar al costado = regate (%s)" % String(m.get("_chosen_kind")))
	await _until_free(m)

	# 3b) DESMARQUE: vengo de un pase → arrastro el dedo y mi jugador corre.
	var opts_r: Array = []
	for k in ["dribble", "through_ball"]:
		opts_r.append({"kind": k, "difficulty": 0.4, "label": k, "risk": "media"})
	m.call("_on_decision_requested", {"minute": 31, "kind": "dribble", "player": MatchState.user_player, "narration": "Prueba.", "options": opts_r, "chained": true, "from_pass": true})
	var tr: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - tr < 12000 and not (pv.visible and pv._mg != null and String(pv._mg.mode) == "live"):
		await get_tree().process_frame
	await _wait(10)
	_check(pv._mg != null and String(pv._mg._phase) == "run", "viniendo de un pase arranca el desmarque")
	var me0: Vector2 = pv.npos("user")
	var hold := InputEventMouseButton.new()
	hold.button_index = MOUSE_BUTTON_LEFT
	hold.pressed = true
	hold.position = pv.to_screen(me0)
	pv._gui_input(hold)
	var mv := InputEventMouseMotion.new()
	mv.position = pv.to_screen(me0 + Vector2(0.15, -0.10))
	pv._gui_input(mv)
	await _wait(45)
	_shot("run")
	_check(pv.npos("user").distance_to(me0) > 0.03, "arrastrando el dedo mi jugador se mueve (%.3f)" % pv.npos("user").distance_to(me0))
	var t_run: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_run < 6000 and pv._mg != null and String(pv._mg._phase) != "act":
		await get_tree().process_frame
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = mv.position
	pv._gui_input(rel)
	await _wait(5)
	_check(pv._mg != null and String(pv._mg._phase) == "act" and pv.nball().distance_to(pv.npos("user")) < 0.06, "al terminar me llega el pase y la jugada se congela")
	var u2: Vector2 = pv.to_screen(pv.npos("user"))
	_gesture(pv, u2 + Vector2(0, 60), u2 + Vector2(0, 60) + pv.screen_dir_x() * 70.0)
	await _wait(2)
	_check(String(m.get("_chosen_kind")) == "dribble", "y sigo jugando (%s)" % String(m.get("_chosen_kind")))
	await _until_free(m)

	# 4) Defensa: deslizar = barrida (y queda marcada como tal para el motor).
	await _force(m, ["tackle", "last_ditch_tackle"])
	_check(String(m.get("_minigame")) == "live", "defensa: también en vivo")
	_shot("defend")
	_gesture(pv, Vector2(200, 500), Vector2(200, 420))
	await _wait(2)
	_check(String(m.get("_chosen_kind")) == "last_ditch_tackle", "deslizar defendiendo = barrida (%s)" % String(m.get("_chosen_kind")))
	await _until_free(m)

	# 5) Defensa: tocar = quite de pie.
	await _force(m, ["tackle", "last_ditch_tackle"])
	_gesture(pv, Vector2(200, 500), Vector2(200, 500))
	await _wait(2)
	_check(String(m.get("_chosen_kind")) == "tackle", "tocar defendiendo = quite (%s)" % String(m.get("_chosen_kind")))
	await _until_free(m)

	# 6) Lo que no tiene versión en vivo (te llega un centro) arranca su minijuego sin menú.
	await _force(m, ["aerial_duel", "key_pass"])
	_check(not (m.get("choice_box") as Control).visible and String(m.get("_chosen_kind")) == "aerial_duel", "cabezazo: sin menú, directo al minijuego")
	_shot("aerial")

	# Fórmulas.
	_check(DecisionResolver.live_slide_precision(0.5, 0.3, 1.0) > DecisionResolver.pitch_timing_precision(0.5, 0.3, true, 0.34, 0.14, 1.0), "la barrida perdona más el momento que el quite de pie")
	_check(DecisionResolver.OFFSIDE_PRECISION < 0.2, "pase a un adelantado casi nunca prospera")
	_check(DecisionResolver.run_speed(90) > DecisionResolver.run_speed(55) and DecisionResolver.receive_difficulty_mod(0.2) < 0.0 and DecisionResolver.receive_difficulty_mod(0.04) > 0.0, "más Velocidad = corre más; recibir libre lo hace más fácil, marcado más difícil")
	_check(DecisionResolver.live_dribble_precision(0.5, 0.2) >= DecisionResolver.CLEAN_HIT and DecisionResolver.live_dribble_precision(0.5, 0.01) < 0.4, "regate: hacia el espacio sale, contra el rival no")
	print("PROBE ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
