extends Node
## Sonda de regresión · P0-05: tanda de penales sin rebote ni segunda jugada.
##   godot --headless --path . res://tools/M3DShootoutProbe.tscn
##
## Juega 20 tandas completas alternando todos los caminos del penalti del
## usuario (gol, atajada, rechace, fuera, palo y balón que vuelve a sus pies)
## y valida que cada tiro cierra la jugada una sola vez. También comprueba que
## el gol de la tanda no ensucia el marcador ni las estadísticas del partido,
## que la IA resuelve sus tiros sin abrir un momento y que la muerte súbita
## añade dos tiros más.

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")
const OUTCOMES := ["goal", "save", "parry", "miss", "post", "recollect"]
const SHOOTOUTS := 20

var fails := 0
var m: SoccerMatch
var scr: Node
var _replay_resumed := false

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
	_check(m.star != null, "no hay jugador estrella para la tanda")
	if m.star == null:
		scr.queue_free()
		print("PROBE FAIL (%d fallos)" % fails)
		get_tree().quit(1)
		return
	m.star.visible = true
	_test_sudden_death()
	var goals := 0
	var saves := 0
	var misses := 0
	var posts := 0
	var recollects := 0
	var user_total := 0
	for i in SHOOTOUTS:
		var res := _run_shootout(i)
		goals += int(res.get("goals", 0))
		saves += int(res.get("saves", 0))
		misses += int(res.get("misses", 0))
		posts += int(res.get("posts", 0))
		recollects += int(res.get("recollects", 0))
		user_total += int(res.get("user_kicks", 0))
	_check(user_total >= SHOOTOUTS, "el usuario no tiró suficientes penaltis para la prueba (%d)" % user_total)
	print("tandas %d · tiros del usuario %d · goles %d · atajadas/rechaces %d · fuera %d · palos %d · balón devuelto %d" % [
		SHOOTOUTS, user_total, goals, saves, misses, posts, recollects])
	_test_shootout_replay()
	scr.queue_free()
	await get_tree().process_frame
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


## Una tanda completa. Devuelve cuántos desenlaces de cada tipo se probaron.
func _run_shootout(iteration: int) -> Dictionary:
	m.score = [0, 0]
	m._start_penalty_shootout()
	_check(m._shootout_sequence.size() == 10, "la tanda no tiene 5 tiros por equipo (%d)" % m._shootout_sequence.size())
	_check(m._shootout_cursor == 0 and m._shootout_scores == [0, 0], "la tanda no arranca limpia")
	var score_before: Array = m.score.duplicate()
	var sot_before: int = int(m.match_stats.sot[0])
	var stats_before: int = int(m.match_stats.me.goals)
	var user_kicks := 0
	var goals := 0
	var saves := 0
	var misses := 0
	var posts := 0
	var recollects := 0
	var guard := 0
	while m._shootout_phase != "winner" and guard < 200:
		guard += 1
		if m.state == m.State.PENALTY_SHOOTOUT:
			var ai_cursor := m._shootout_cursor
			m._update_shootout(10.0)
			_check(not m._rebound_done, "la IA abrió un rebote en la tanda")
			_check(m._shootout_cursor >= ai_cursor, "la tanda retrocedió de tiro")
			continue
		if m.state == m.State.MOMENT_INTRO or m.state == m.State.MOMENT:
			user_kicks += 1
			var cursor_before := m._shootout_cursor
			var outcome: String = OUTCOMES[(iteration + user_kicks) % OUTCOMES.size()]
			m.state = m.State.MOMENT
			_simulate_user_kick(outcome)
			_check(m._shootout_cursor == cursor_before + 1,
				"el penalti '%s' no cerró exactamente un tiro (%d → %d)" % [outcome, cursor_before, m._shootout_cursor])
			_check(not m._rebound_done, "el penalti '%s' abrió una segunda jugada" % outcome)
			match outcome:
				"goal":
					goals += 1
					_check(m.score == score_before, "el gol de la tanda movió el marcador del partido")
					_check(int(m.match_stats.sot[0]) == sot_before, "el gol de la tanda contó tiro a puerta")
					_check(int(m.match_stats.me.goals) == stats_before, "el gol de la tanda contó como gol del jugador")
				"save", "parry":
					saves += 1
				"miss":
					misses += 1
				"post":
					posts += 1
				"recollect":
					recollects += 1
			continue
		_check(false, "estado inesperado en la tanda: %s" % m.State.keys()[m.state])
		break
	_check(guard < 200, "la tanda no terminó en %d pasos" % guard)
	_check(m._shootout_phase == "winner", "la tanda no llegó a un ganador")
	_check(m._shootout_scores[0] != m._shootout_scores[1], "la tanda terminó empatada")
	_check(user_kicks >= 1, "el usuario no tiró ningún penalti")
	return {"goals": goals, "saves": saves, "misses": misses, "posts": posts, "recollects": recollects, "user_kicks": user_kicks}


## Ejecuta el tiro del usuario y fuerza el desenlace pedido por el camino real
## de `_check_moment_outcome` / `_on_goal_area_entered`.
func _simulate_user_kick(outcome: String) -> void:
	var star: SoccerPlayer = m.star
	m.on_shot(star)
	_check(m._penalty_kicked, "el remate de la tanda no marcó el penalti como ejecutado")
	# Después del remate, el jugador no debe poder volver a tocar ni rematar.
	m._on_tapped(Vector2.ZERO)
	m._on_swiped(PackedVector2Array([Vector2(10.0, 10.0), Vector2(100.0, 100.0)]), 0.2)
	match outcome:
		"goal":
			m._on_goal_area_entered(m.ball, 0)
		"save":
			m.ball.owner_player = m.teams[1][0]
			m._check_moment_outcome(0.016)
		"parry":
			# El portero rechaza: balón vivo y jugador congelado. No puede haber
			# segunda jugada; el tiro se cierra cuando el balón se detiene.
			m._saved = true
			m.ball.owner_player = null
			m.ball.linear_velocity = Vector3(-8.0, 0.0, 0.0)
			m._check_moment_outcome(0.016)
			_check(m._shootout_in_user_kick, "el rechace cerró el tiro antes de tiempo")
			m.ball.linear_velocity = Vector3.ZERO
			m._check_moment_outcome(10.0)
		"miss":
			m.ball.owner_player = null
			m.ball.linear_velocity = Vector3(-18.0, 0.0, 0.0)
			m._check_moment_outcome(10.0)
		"post":
			m.ball.owner_player = null
			m.ball.last_hit_post = true
			m.ball.linear_velocity = Vector3(-5.0, 0.0, 0.0)
			m._check_moment_outcome(10.0)
		"recollect":
			# El rechace vuelve a los pies del tirador: se cierra como fallo, no
			# como una nueva ocasión.
			m.ball.owner_player = star
			m._check_moment_outcome(0.016)


## La muerte súbita debe añadir dos tiros (uno por equipo) y empezar por el 0.
func _test_sudden_death() -> void:
	m.score = [0, 0]
	m._start_penalty_shootout()
	var before := m._shootout_sequence.size()
	m._shootout_scores = [2, 2]
	m._shootout_cursor = before
	m._shootout_sudden = 0
	m._start_next_shootout_kick()
	_check(m._shootout_sequence.size() == before + 2, "la muerte súbita no añadió dos tiros")
	_check(m._shootout_team == 0, "la muerte súbita no empieza por el equipo 0")
	# Juega el par de muerte súbita hasta que haya ganador.
	var guard := 0
	while m._shootout_phase != "winner" and guard < 200:
		guard += 1
		if m.state == m.State.PENALTY_SHOOTOUT:
			m._update_shootout(10.0)
		elif m.state == m.State.MOMENT_INTRO or m.state == m.State.MOMENT:
			m.state = m.State.MOMENT
			_simulate_user_kick("goal")
			_check(not m._rebound_done, "la muerte súbita abrió una segunda jugada")
		else:
			print("muerte súbita: estado inesperado ", m.State.keys()[m.state])
			break
	_check(m._shootout_phase == "winner", "la muerte súbita no terminó (%s, %d pasos, %d-%d)" % [
		m._shootout_phase, guard, m._shootout_scores[0], m._shootout_scores[1]])
	_check(m._shootout_scores[0] != m._shootout_scores[1], "la muerte súbita terminó empatada")


## P0-10 · La tanda se graba y se puede rever en la cancha de repetición sin
## romper el flujo: al cerrar la repetición se vuelve al ganador.
func _test_shootout_replay() -> void:
	m.state = m.State.PENALTY_SHOOTOUT
	m._shootout_phase = "winner"
	m._shootout_winner_team = 0
	m._shootout_scores = [3, 2]
	m.replay.begin()
	for i in 12:
		m.replay._rec_acc = 1.0
		m.replay.record(m)
	_check(m.replay.has_frames(), "la tanda no dejó fotogramas para la repetición")
	m._replay_return_state = m.State.PENALTY_SHOOTOUT
	m._replay_return_phase = "winner"
	m.state = m.State.REPLAY
	m.replay.play(m, _on_replay_stop)
	m.replay._stop()
	_check(_replay_resumed, "la repetición de la tanda no volvió a su flujo")
	_check(m.state == m.State.PENALTY_SHOOTOUT and m._shootout_phase == "winner",
		"la repetición de la tanda no devolvió el estado al ganador")
	_check(m._hud._replay_btn.visible, "la repetición de la tanda no dejó el botón para reverla otra vez")


func _on_replay_stop() -> void:
	m._resume_shootout_after_replay()
	_replay_resumed = true
