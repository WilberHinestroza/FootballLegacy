extends Node
## Sonda de regresión P1-12 · jugadas encadenadas.
##   godot --headless --path . res://tools/M3DPlayChainProbe.tscn
##
## Valida que un regate exitoso abre un remate con más potencia y puntería, que
## el pase abre una ventana de asistencia y que el receptor que define dentro
## de esa ventana cuenta el pase clave. Monta el partido 3D real.

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")
const PlayChain = preload("res://engine/match/m3d/PlayChain.gd")

var fails := 0
var m: SoccerMatch

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		fails += 1
		print("FALLA: ", msg)

func _near(a: float, b: float, eps := 0.001) -> bool:
	return absf(a - b) <= eps

func _ready() -> void:
	_test_pure()
	await _test_match()
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


## La matemática pura: bonus por eslabón, decaimiento y ventana de asistencia.
func _test_pure() -> void:
	_check(_near(PlayChain.shot_bonus(0, 2.0), 0.0), "sin regate ya hay bonus de remate")
	_check(PlayChain.shot_bonus(1, 2.0) > 0.0, "un regate no abre el remate")
	_check(PlayChain.shot_bonus(2, 2.0) > PlayChain.shot_bonus(1, 2.0),
		"el segundo quiebro no suma potencia")
	_check(PlayChain.shot_bonus(3, 2.0) > PlayChain.shot_bonus(2, 2.0),
		"el tercer quiebro no suma potencia")
	_check(_near(PlayChain.shot_bonus(3, 0.0), 0.0), "la ventana vencida sigue dando bonus")
	_check(PlayChain.shot_bonus(3, 1.0) < PlayChain.shot_bonus(3, 2.0),
		"el bonus no decae con el tiempo")
	_check(PlayChain.shot_bonus(3, 2.0) <= PlayChain.MAX_SHOT_BONUS + 0.0001,
		"el bonus de potencia se pasa del máximo")
	_check(PlayChain.shot_accuracy(2, 2.0) > PlayChain.shot_accuracy(1, 2.0),
		"el combo no mejora la puntería")
	_check(_near(PlayChain.shot_accuracy(0, 2.0), 0.0), "sin regate ya hay bonus de puntería")
	_check(PlayChain.assist_window(1.0) > PlayChain.assist_window(0.0),
		"el buen pasador no tiene más ventana de asistencia")
	_check(PlayChain.assist_active(0.5), "una asistencia viva no se reconoce")
	_check(not PlayChain.assist_active(0.0), "una asistencia vencida sigue viva")
	_check(_near(PlayChain.assist_shot_bonus(0.0, 3.0), 0.0),
		"una asistencia vencida da potencia")
	_check(PlayChain.assist_shot_bonus(3.0, 3.0) > 0.0, "una asistencia viva no da potencia")
	_check(PlayChain.assist_shot_bonus(1.5, 3.0) < PlayChain.assist_shot_bonus(3.0, 3.0),
		"el bonus de asistencia no decae")
	_check(PlayChain.is_shot_open(1, 1.0), "un regate no deja el remate abierto")
	_check(not PlayChain.is_shot_open(1, 0.0), "un regate vencido deja el remate abierto")


func _wait_kick(p: SoccerPlayer) -> void:
	var t := 0.0
	while p.is_kicking() and t < 2.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05


func _swipe_to_goal() -> PackedVector2Array:
	var from := m.star.global_position
	var a := m._camera.unproject_position(from)
	var b := m._camera.unproject_position(from + Vector3(14.0, 0.0, 0.0))
	return PackedVector2Array([a, b])


func _prepare_shot() -> void:
	m.state = m.State.MOMENT
	m.moment_type = m.Moment.ATTACK
	m.human = m.star
	m._shot_pending = false
	m._penalty_kicked = false
	m.star.global_position = Vector3(34.0, 0.0, 0.0)
	m.star.velocity = Vector3.ZERO
	m.star.stun_timer = 0.0
	# Cámara fija detrás del jugador para que el gesto de pantalla apunte a +X.
	m._camera.global_position = m.star.global_position + Vector3(-14.0, 10.0, 0.0)
	m._camera.look_at(m.star.global_position, Vector3.UP)
	m._give_ball_now(m.star)


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
	for p: SoccerPlayer in m.players:
		if p != m.star:
			p.global_position = Vector3(-40.0, 0.0, 28.0)
			p.velocity = Vector3.ZERO
			p.stun_timer = 0.0

	# --- Remate sin regate previo. ---
	_prepare_shot()
	m._chain_links = 0
	m._chain_shot_window = 0.0
	var swipe := _swipe_to_goal()
	m._on_swiped(swipe, 0.2)
	await _wait_kick(m.star)
	var plain := SoccerMatch.flat(m.ball.velocity_now()).length()
	_check(plain > 5.0, "el remate de prueba no sale")

	# --- Remate después de un combo de regate: más potencia. ---
	_prepare_shot()
	m._open_shot_chain(3)
	_check(m._chain_links == 3, "el regate no abre la cadena de remate")
	_check(_near(m._chain_shot_window, PlayChain.DRIBBLE_SHOT_WINDOW),
		"la ventana del remate encadenado no dura lo previsto")
	m._on_swiped(swipe, 0.2)
	await _wait_kick(m.star)
	var chained := SoccerMatch.flat(m.ball.velocity_now()).length()
	_check(chained > plain * 1.04, "el remate tras regate no sale más fuerte")
	_check(m._chain_links == 0 and m._chain_shot_window == 0.0,
		"el remate no consume la cadena del regate")

	# --- La ventana del remate se apaga sola. ---
	m._open_shot_chain(2)
	m._update_play_chain(1.0)
	_check(m._chain_shot_window < PlayChain.DRIBBLE_SHOT_WINDOW,
		"la ventana del remate no avanza")
	m._update_play_chain(PlayChain.DRIBBLE_SHOT_WINDOW + 1.0)
	_check(m._chain_links == 0 and m._chain_shot_window == 0.0,
		"la ventana del remate no se cierra sola")

	# --- El pase abre la asistencia y corta el combo de regate. ---
	_prepare_shot()
	var mate: SoccerPlayer = null
	for p: SoccerPlayer in m.teams[0]:
		if p != m.star and not p.is_keeper:
			mate = p
			break
	_check(mate != null, "no hay compañero para probar la asistencia")
	if mate == null:
		scr.queue_free()
		return
	m._open_shot_chain(2)
	var kp_before := int(m.match_stats.me.key_passes)
	m.on_pass(m.star, mate)
	_check(m._chain_links == 0, "el pase no corta el combo de regate")
	_check(m._assist_target == mate, "el pase no abre la asistencia")
	_check(m._assist_window > 0.0, "la ventana de asistencia no dura nada")
	_check(not m._assist_shot_counted, "la asistencia nace ya consumida")

	# --- El receptor define dentro de la ventana: pase clave y remate más fuerte. ---
	m.ball.owner_player = null
	m.ball.linear_velocity = Vector3(20.0, 0.0, 0.0)
	m.ball._pending_velocity = Vector3(20.0, 0.0, 0.0)
	m.on_shot(mate)
	_check(int(m.match_stats.me.key_passes) == kp_before + 1,
		"el remate del receptor no cuenta como pase clave")
	_check(m._assist_target == null, "la asistencia no se consume con el remate")
	var boosted := (m.ball._pending_velocity as Vector3).length()
	_check(boosted > 20.0, "el remate del receptor no sale más fuerte")
	_check(boosted <= 20.0 * (1.0 + PlayChain.ASSIST_SHOT_BONUS) + 0.01,
		"el bonus de asistencia se pasa del máximo")

	# --- Fuera de la ventana, el remate no cuenta como pase clave. ---
	m._open_assist(mate)
	m._update_play_chain(PlayChain.ASSIST_WINDOW_MAX + 1.0)
	_check(m._assist_target == null, "la asistencia no se cierra sola")
	var kp_late := int(m.match_stats.me.key_passes)
	m.on_shot(mate)
	_check(int(m.match_stats.me.key_passes) == kp_late,
		"un remate tarde sigue contando como pase clave")

	# --- Fin de jugada: no queda ninguna cadena viva. ---
	m._open_shot_chain(2)
	m._open_assist(mate)
	m._finish_moment("Fin de prueba")
	_check(m._chain_links == 0 and m._assist_target == null,
		"al terminar la jugada queda una cadena viva")

	scr.queue_free()
	await get_tree().process_frame
