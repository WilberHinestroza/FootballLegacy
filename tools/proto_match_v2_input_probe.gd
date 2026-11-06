extends Node
## Prototipo match_v2 — prueba los GESTOS reales (eventos de mouse como los
## que genera el dedo en Android) contra la escena: mantener = conducir,
## trazo corto desde tu jugador = gambeta.
##   godot --path . --resolution 576x1024 res://tools/ProtoMatchV2InputProbe.tscn
var scene

func _ready() -> void:
	scene = (load("res://prototypes/match_v2/ProtoMatch.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(scene)
	await _frames(10)
	await _wait_user_ball()
	# 1) TOCAR la cancha 120 px arriba de tu jugador = avanzar hasta ahí.
	var u = scene.sim.user()
	var p0: Vector2 = scene.w2s(u.pos) + Vector2(0, -120)
	var start_pos: Vector2 = u.pos
	_press(p0, true)
	await get_tree().process_frame
	_press(p0, false)
	for i in range(90):
		await get_tree().process_frame
	print("TAP: user_dribble=", scene.sim.user_dribble, " has_ball=", scene.sim.user_has_ball(), " movido=", u.pos.distance_to(start_pos))
	await _frames(5)
	# 2) Toque "sucio" (30 px de trazo) = sigue siendo avanzar, NO remate.
	await _wait_user_ball()
	u = scene.sim.user()
	var shots0: int = int(scene.sim.stats["user_shots"])
	var q: Vector2 = scene.w2s(u.pos) + Vector2(40, -100)
	_press(q, true)
	for i in range(3):
		q += Vector2(0, -10)
		_motion(q)
		await get_tree().process_frame
	_press(q, false)
	await _frames(3)
	print("  sucio pases=", scene.sim.stats["user_passes"], " has=", scene.sim.user_has_ball())
	print("TOQUE SUCIO: remates ", shots0, " -> ", scene.sim.stats["user_shots"], "  conduce=", scene.sim.user_dribble)
	await _frames(5)
	# 3) Gambeta: trazo corto y rápido desde tu jugador.
	await _wait_user_ball()
	u = scene.sim.user()
	var before: int = int(scene.sim.stats["user_skills"])
	var r0: Vector2 = scene.w2s(u.pos)
	print("PRE-SKILL: replay=", scene.replaying, " interlude=", scene.interlude_t, " phase=", scene.sim.phase, " has=", scene.sim.user_has_ball(), " on_user=", scene._hit(u, r0, 1.2), " windup=", scene.sim.windup)
	_press(r0, true)
	for i in range(4):
		_motion(r0 + Vector2(15 * (i + 1), -10 * (i + 1)))
		await get_tree().process_frame
	_press(r0 + Vector2(60, -40), false)
	await _frames(3)
	print("SKILL: gambetas ", before, " -> ", scene.sim.stats["user_skills"])
	get_tree().quit(0)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _wait_user_ball() -> void:
	var tries: int = 0
	while (not scene.sim.user_has_ball() or scene.interlude_t > 0.0 or scene.sim.phase != "play") and tries < 4000:
		await get_tree().process_frame
		tries += 1
	await _frames(20)

func _press(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	e.global_position = p
	Input.warp_mouse(p)
	get_viewport().push_input(e)

func _motion(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.warp_mouse(p)
	get_viewport().push_input(e)
