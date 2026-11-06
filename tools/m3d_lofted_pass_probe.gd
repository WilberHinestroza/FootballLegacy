extends Node
## Sonda de regresión P1-09 · pase bombeado.
##   godot --headless --path . res://tools/M3DLoftedPassProbe.tscn
##
## Valida la matemática del vuelo (ápice, tiempo de caída y velocidad
## horizontal), que mantener el toque del pase lo levante por encima del rival y
## que un toque corto siga siendo un pase raso. Monta el partido 3D real.

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")
const LoftedPass = preload("res://engine/match/m3d/LoftedPass.gd")

var fails := 0
var m: SoccerMatch

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		fails += 1
		print("FALLA: ", msg)

func _near(a: float, b: float, eps := 0.02) -> bool:
	return absf(a - b) <= eps

func _ready() -> void:
	_test_pure()
	await _test_match()
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


## La física pura del balón levantado.
func _test_pure() -> void:
	var k := 0.5
	for apex in [0.6, 1.2, 2.3, 3.0]:
		var vy: float = LoftedPass.vy_for_apex(apex, k)
		_check(_near(LoftedPass.apex_height(vy, k), apex),
			"el ápice calculado no coincide con el pedido (%.2f m)" % apex)
	_check(LoftedPass.vy_for_apex(2.3, k) > LoftedPass.vy_for_apex(1.2, k),
		"más altura no exige más velocidad vertical")
	_check(LoftedPass.vy_for_apex(0.0, k) == 0.0, "un ápice nulo exige velocidad")
	_check(LoftedPass.apex_height(0.0, k) == 0.0, "sin velocidad vertical hay ápice")

	var vy2: float = LoftedPass.vy_for_apex(2.3, k)
	var t2: float = LoftedPass.hang_time(vy2, k)
	_check(t2 > 0.5, "el tiempo de vuelo del bombeo es demasiado corto")
	var vy3: float = LoftedPass.vy_for_apex(3.0, k)
	_check(LoftedPass.hang_time(vy3, k) > t2, "más altura no alarga el vuelo")
	_check(LoftedPass.horizontal_speed(20.0, t2, k) > 0.0,
		"la velocidad horizontal del bombeo es nula")
	_check(LoftedPass.horizontal_speed(30.0, t2, k) > LoftedPass.horizontal_speed(20.0, t2, k),
		"más distancia no exige más velocidad horizontal")
	_check(LoftedPass.clearance_apex() > LoftedPass.DEFENDER_HEIGHT,
		"el ápice no pasa por encima del defensor")


## Espera a que la animación de golpeo suelte el balón.
func _wait_kick() -> void:
	var t := 0.0
	while m.star.is_kicking() and t < 2.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05


func _test_match() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	pl.avatar = Avatar.random_config(1234)
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	fx["competition"] = "cup"
	fx["round_name"] = "Octavos de final"
	fx["is_knockout"] = true
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	var mine: MatchTeam = MatchState.home_team if String(fx.get("home_club_id", "")) == pl.club_id else MatchState.away_team
	var u: PlayerData = MatchState.user_player
	if not mine.starting_xi.has(u):
		mine.bench.erase(u)
		for i in mine.starting_xi.size():
			if (mine.starting_xi[i] as PlayerData).position == u.position:
				mine.starting_xi[i] = u
				break
	if not Match3DBridge.supported():
		_check(false, "el partido 3D no está soportado en esta configuración")
		return
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	await get_tree().process_frame
	m = scr._match
	_check(m != null, "el partido 3D se montó correctamente")
	if m == null:
		return
	if m.state == m.State.WALKOUT:
		m._end_walkout()
	if m.star == null:
		_check(false, "no hay jugador estrella")
		scr.queue_free()
		return

	m.state = m.State.MOMENT
	m.moment_type = m.Moment.ATTACK
	m.human = m.star
	m.star.global_position = Vector3(0.0, 0.0, 0.0)
	m.star.velocity = Vector3.ZERO
	for o: SoccerPlayer in m.teams[1]:
		o.global_position = Vector3(-30.0, 0.0, 25.0)
	var mates: Array[SoccerPlayer] = []
	for mate: SoccerPlayer in m.teams[0]:
		if mate != m.star and not mate.is_keeper:
			mates.append(mate)
	_check(mates.size() >= 1, "no hay compañeros para probar el pase bombeado")
	if mates.is_empty():
		scr.queue_free()
		return
	var mate: SoccerPlayer = mates[0]
	mate.global_position = Vector3(18.0, 0.0, 0.0)
	mate.velocity = Vector3.ZERO
	# Un rival en la línea de pase: el bombeo tiene que pasar por encima.
	var defender: SoccerPlayer = m.teams[1][0]
	defender.global_position = Vector3(9.0, 0.0, 0.0)

	# --- Directo: el pase sale con mucha velocidad vertical. ---
	m._give_ball_now(m.star)
	await get_tree().physics_frame
	m.star.lofted_pass(mate)
	await _wait_kick()
	var k := SoccerBall.air_drag()
	var vy_expected: float = LoftedPass.vy_for_apex(LoftedPass.clearance_apex(), k)
	var v := m.ball.velocity_now()
	_check(v.y > 4.0, "el pase bombeado no sale hacia arriba")
	_check(absf(v.y - vy_expected) < 0.6, "el pase bombeado no usa el ápice calculado")
	_check(m.ball.last_kick_kind == "pass", "el pase bombeado no se registra como pase")
	var apex: float = LoftedPass.apex_height(v.y, k)
	_check(apex > defender.global_position.y + 1.8,
		"el pase bombeado no pasa por encima del defensor")

	# --- Integración: mantener el toque levanta el pase. ---
	await _reset_attack(mate)
	m._hud.gesture._last_tap_hold = 0.6
	var screen: Vector2 = m._camera.unproject_position(mate.global_position + Vector3.UP)
	_check(m._player_at_screen(screen) == mate, "la pantalla del compañero no lo selecciona")
	m._on_tapped(screen)
	await _wait_kick()
	var v2 := m.ball.velocity_now()
	_check(v2.y > 4.0, "mantener el toque del pase no lo levanta")

	# --- Integración: un toque corto sigue siendo un pase raso. ---
	await _reset_attack(mate)
	m._hud.gesture._last_tap_hold = 0.1
	screen = m._camera.unproject_position(mate.global_position + Vector3.UP)
	m._on_tapped(screen)
	await _wait_kick()
	var v3 := m.ball.velocity_now()
	_check(v3.y < 3.0, "un toque corto también levanta el pase")

	scr.queue_free()
	await get_tree().process_frame


## Devuelve la jugada a un ataque limpio con el balón en los pies del jugador.
func _reset_attack(mate: SoccerPlayer) -> void:
	m.state = m.State.MOMENT
	m.moment_type = m.Moment.ATTACK
	m.human = m.star
	m._shot_pending = false
	m._penalty_kicked = false
	m._move_target = null
	m.star.global_position = Vector3.ZERO
	m.star.velocity = Vector3.ZERO
	mate.global_position = Vector3(18.0, 0.0, 0.0)
	mate.velocity = Vector3.ZERO
	m._give_ball_now(m.star)
	await get_tree().physics_frame
