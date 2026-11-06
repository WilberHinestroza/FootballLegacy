extends Node
## Sonda de regresión · P0-13 / P0-15 / P0-16.
##   godot --headless --path . res://tools/M3DRulesProbe.tscn
##
## P0-13 · Goles fantasma: el pase clave ya no mueve el marcador por decreto;
##         el compañero remata y el gol solo cuenta cuando el balón entra.
## P0-15 · Balón dividido: un pase a 6-8 m/s a media altura se controla con el
##         cuerpo; uno a 12 m/s sigue pasando de largo.
## P0-16 · Sustituciones limpias: entrar/salir reutiliza el mismo avatar, sin
##         nodos duplicados, sin perder colisión y sin control fantasma.

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")

var fails := 0
var m: SoccerMatch
var scr: Node

func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FALLA: ", msg)

func _ready() -> void:
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
		print("PROBE FAIL (%d fallos)" % fails)
		get_tree().quit(1)
		return
	scr = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	await get_tree().process_frame
	m = scr._match
	_check(m != null, "el partido 3D se montó correctamente")
	if m == null:
		print("PROBE FAIL (%d fallos)" % fails)
		get_tree().quit(1)
		return
	if m.state == m.State.WALKOUT:
		m._end_walkout()
	await _test_key_pass_goal()
	await _test_body_control()
	await _test_deflection()
	_test_substitutions()
	scr.queue_free()
	await get_tree().process_frame
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


## P0-13 · Fuerza un pase clave y comprueba que el marcador no se mueve hasta
## que el balón cruza la línea. Repite hasta ver un gol real (o falla si el
## camino nunca lo consigue).
func _test_key_pass_goal() -> void:
	var receiver: SoccerPlayer = null
	for p: SoccerPlayer in m.teams[0]:
		if p != m.star and not p.is_keeper:
			receiver = p
			break
	_check(receiver != null, "no hay compañero para el pase clave")
	if receiver == null:
		return
	var scored := 0
	for attempt in 6:
		m.state = m.State.MOMENT
		m.moment_type = SoccerMatch.Moment.BUILDUP
		m._moment_goal = -1
		m._scripted_goal_receiver = null
		m._shot_pending = false
		m._saved = false
		m._rebound_done = false
		m._moment_timer = 12.0
		m.score = [0, 0]
		var shots_before: int = int(m.match_stats.shots[0])
		var sot_before: int = int(m.match_stats.sot[0])
		# El pase clave puede fallar la tirada: se reintenta hasta que el
		# compañero reciba en zona de definición.
		var forced := false
		for i in 300:
			# Colocación realista de armado: el receptor encara la portería
			# desde el borde del área, no desde su campo.
			receiver.reset_to(Vector3(30.0, 0.0, 0.0), Vector3.RIGHT)
			m.ball.reset_to(receiver.global_position + Vector3(0.3, SoccerBall.RADIUS, 0.0))
			await get_tree().physics_frame
			# La jugada se rearma DESPUÉS del frame: el partido pudo cerrar la
			# anterior y dejar el estado en MOMENT_RESULT.
			m.state = m.State.MOMENT
			m.moment_type = SoccerMatch.Moment.BUILDUP
			m._moment_goal = -1
			m._scripted_goal_receiver = null
			m._shot_pending = false
			m._saved = false
			m._rebound_done = false
			m._moment_timer = 12.0
			m.score = [0, 0]
			m._give_ball(receiver)
			m._key_pass(receiver)
			if m._scripted_goal_receiver != null:
				forced = true
				break
			# Falló la tirada: _finish_moment cerró la jugada; se rearma.
		if not forced:
			_check(false, "no se pudo forzar un pase clave en 300 intentos")
			return
		_check(m.score == [0, 0], "el pase clave movió el marcador antes de que el balón entrara")
		_check(m._shot_pending, "el pase clave no generó un remate real")
		_check(m.ball.owner_player == null, "el balón sigue pegado al pie tras el remate del pase clave")
		# Deja correr la física hasta que entre o se agote el tiempo.
		var guard := 0
		while guard < 240 and m.score[0] == 0:
			guard += 1
			await get_tree().physics_frame
		if m.score[0] > 0:
			scored += 1
			_check(m._moment_goal == 0, "el gol del pase clave no quedó marcado para el equipo 0")
			_check(int(m.match_stats.shots[0]) > shots_before, "el remate del pase clave no contó como tiro")
			_check(int(m.match_stats.sot[0]) > sot_before, "el gol del pase clave no contó como tiro a puerta")
			_check(m.match_stats.me.assists > 0, "el gol del pase clave no contó como asistencia")
			return
	_check(scored > 0, "el pase clave no metió ningún gol real en 6 intentos")
	m._scripted_goal_receiver = null
	_check(false, "el pase clave no metió gol: el camino queda sin validar")


## P0-15 · Control con el cuerpo a media altura.
func _test_body_control() -> void:
	m.state = m.State.ENDED
	m._scripted_goal_receiver = null
	var p: SoccerPlayer = null
	for q: SoccerPlayer in m.teams[0]:
		if not q.is_keeper and q != m.star:
			p = q
			break
	_check(p != null, "no hay jugador de campo para el control con el cuerpo")
	if p == null:
		return
	p.reset_to(Vector3(10.0, 0.0, 10.0), Vector3.RIGHT)
	m.ball.reset_to(p.global_position + Vector3(-0.7, 1.30, 0.0))
	await get_tree().physics_frame
	m.ball.linear_velocity = Vector3(7.0, 0.0, 0.0)
	m._update_possession(0.016)
	_check(m.ball.owner_player == p, "un pase a 7 m/s a media altura no se controla con el cuerpo")
	m.ball.owner_player = null
	m.ball.reset_to(p.global_position + Vector3(-0.7, 1.30, 0.0))
	await get_tree().physics_frame
	m.ball.linear_velocity = Vector3(12.0, 0.0, 0.0)
	m._update_possession(0.016)
	_check(m.ball.owner_player == null, "un balón a 12 m/s a media altura no debe quedar controlado")
	m.ball.owner_player = null


## P0-09 · Un remate fuerte que llega a un defensor de campo rebota en su
## cuerpo (se desvía) en vez de quedar controlado a sus pies.
func _test_deflection() -> void:
	m.state = m.State.ENDED
	var o: SoccerPlayer = null
	for q: SoccerPlayer in m.teams[1]:
		if not q.is_keeper:
			o = q
			break
	var shooter: SoccerPlayer = null
	for q: SoccerPlayer in m.teams[0]:
		if not q.is_keeper:
			shooter = q
			break
	_check(o != null and shooter != null, "faltan jugadores para probar el desvío")
	if o == null or shooter == null:
		return
	m._scripted_goal_receiver = null
	o.reset_to(Vector3(20.0, 0.0, 10.0), Vector3.LEFT)
	m.ball.reset_to(Vector3(19.3, 0.15, 10.0))
	await get_tree().physics_frame
	m.ball.owner_player = null
	m.ball.last_touch = shooter
	m.ball.last_kick_kind = "shot"
	m.ball.linear_velocity = Vector3(20.0, 0.0, 0.0)
	m._update_possession(0.016)
	_check(m.ball.owner_player == null, "un remate fuerte quedó controlado por el defensor en vez de desviarse")
	_check(m.ball.last_touch == o, "el desvío no se atribuyó al defensor")
	m.ball.owner_player = null


## P0-16 · Sustituciones: mismo avatar, sin duplicados ni colisión perdida.
func _test_substitutions() -> void:
	m.state = m.State.ENDED
	var star: SoccerPlayer = m.star
	var before := m.players.size()
	var ids_before := {}
	for p: SoccerPlayer in m.players:
		ids_before[p.get_instance_id()] = true
	_check(star != null, "no hay jugador estrella para el cambio")
	if star == null:
		return
	m._sub_off_star(60)
	_check(m.players.size() == before, "salir al banquillo duplicó avatares (%d → %d)" % [before, m.players.size()])
	_check(m.players.count(star) == 1, "el avatar del jugador quedó duplicado o fuera de la lista")
	_check(m.subbed_off and not m._on_pitch_now(), "el cambio no sacó al jugador del control")
	_check(star.visible, "el suplente no quedó visible en el campo")
	_check(star.collision_layer != 0 and star.collision_mask != 0, "el jugador quedó sin colisiones tras el cambio")
	var ids_after := {}
	for p: SoccerPlayer in m.players:
		ids_after[p.get_instance_id()] = true
	_check(ids_after.size() == before, "hay nodos de jugador duplicados tras el cambio")
	m._enter_from_bench(70)
	_check(m.players.size() == before, "volver a entrar duplicó avatares")
	_check(m.players.count(star) == 1, "el jugador que vuelve no es el mismo nodo")
	_check(star.collision_layer != 0 and star.collision_mask != 0, "el jugador que vuelve quedó sin colisiones")
	_check(String(m._names[0][star.index]) == m.profile.player_name,
			"al volver no se restauró tu nombre en el avatar")
