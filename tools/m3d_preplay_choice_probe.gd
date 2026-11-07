extends Node
## Sonda de regresión P1-13 · elegir antes de la jugada.
##   godot --headless --path . res://tools/M3DPrePlayChoiceProbe.tscn
##
## Valida la matemática pura (destino de conducción, puntuación de pases,
## aguante) y la integración con el partido 3D: la barra aparece en la intro
## de un ataque con balón, la elección se aplica al arrancar la jugada y no
## aparece en jugadas defensivas ni queda viva al terminar.

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")
const PrePlayChoice = preload("res://engine/match/m3d/PrePlayChoice.gd")

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


## La matemática pura: destino de conducción, puntuación y aguante.
func _test_pure() -> void:
	_check(PrePlayChoice.is_valid(PrePlayChoice.DRIVE), "conducir no es una elección válida")
	_check(PrePlayChoice.is_valid(PrePlayChoice.QUICK_PASS), "el pase rápido no es una elección válida")
	_check(PrePlayChoice.is_valid(PrePlayChoice.HOLD), "aguantar no es una elección válida")
	_check(not PrePlayChoice.is_valid(""), "una elección vacía se acepta")
	_check(not PrePlayChoice.is_valid("correr"), "una elección inventada se acepta")
	_check(PrePlayChoice.label(PrePlayChoice.DRIVE) == "CONDUCIR", "la etiqueta de conducir no es la esperada")
	_check(PrePlayChoice.label(PrePlayChoice.QUICK_PASS) == "PASE RÁPIDO", "la etiqueta del pase no es la esperada")
	_check(PrePlayChoice.label(PrePlayChoice.HOLD) == "AGUANTAR", "la etiqueta de aguantar no es la esperada")

	var carrier := Vector3(20.0, 0.0, 0.0)
	var goal := Vector3(52.5, 0.0, 0.0)
	var target := PrePlayChoice.drive_target(carrier, goal)
	_check(target.x > carrier.x, "conducir no avanza hacia la portería")
	_check(_near(target.distance_to(carrier), PrePlayChoice.DRIVE_DISTANCE),
		"conducir no avanza la distancia prevista")
	_check(PrePlayChoice.drive_target(carrier, carrier) == carrier,
		"sin portería el destino de conducción se mueve")

	var ahead := Vector3(30.0, 0.0, 0.0)
	var behind := Vector3(10.0, 0.0, 0.0)
	_check(PrePlayChoice.pass_score(ahead, carrier, goal) > PrePlayChoice.pass_score(behind, carrier, goal),
		"el pase adelantado no puntúa más que el retrasado")
	_check(_near(PrePlayChoice.pass_score(Vector3(60.0, 0.0, 0.0), carrier, goal), -1.0),
		"un compañero fuera de rango sigue siendo un pase válido")
	_check(_near(PrePlayChoice.pass_score(Vector3(20.5, 0.0, 0.0), carrier, goal), -1.0),
		"un compañero pegado sigue siendo un pase válido")
	_check(PrePlayChoice.best_pass_index([behind, ahead], carrier, goal) == 1,
		"el mejor pase no elige al compañero adelantado")
	_check(PrePlayChoice.best_pass_index([Vector3(60.0, 0.0, 0.0)], carrier, goal) == -1,
		"sin pases válidos se elige igual un compañero")

	_check(PrePlayChoice.hold_stamina(0.5) > 0.5, "aguantar no recupera stamina")
	_check(_near(PrePlayChoice.hold_stamina(1.0), 1.0), "aguantar pasa del 100% de stamina")
	# Inicio de tu jugada: nadie empieza encima del balón
	var bpos := Vector3(10.0, 0.0, 5.0)
	var pushed := PrePlayChoice.opening_push(bpos, Vector3(11.0, 0.0, 5.0))
	_check(_near(pushed.distance_to(bpos), PrePlayChoice.OPENING_SPACE), "un rival encima no se aparta al empezar la jugada")
	_check(pushed.x > bpos.x, "el rival se aparta hacia el lado contrario al que estaba")
	var far := Vector3(20.0, 0.0, 5.0)
	_check(PrePlayChoice.opening_push(bpos, far) == far, "un rival lejano se mueve sin necesidad")
	_check(_near(PrePlayChoice.opening_push(bpos, bpos).distance_to(bpos), PrePlayChoice.OPENING_SPACE),
		"un rival justo en el balón no se aparta")


func _wait_kick(p: SoccerPlayer) -> void:
	var t := 0.0
	while p.is_kicking() and t < 2.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05


func _mate() -> SoccerPlayer:
	for p: SoccerPlayer in m.teams[0]:
		if p != m.star and not p.is_keeper:
			return p
	return null


func _clear_pitch() -> void:
	for p: SoccerPlayer in m.players:
		if p == m.star:
			continue
		p.global_position = Vector3(-40.0, 0.0, 28.0)
		p.velocity = Vector3.ZERO
		p.stun_timer = 0.0
		p.tackle_cooldown = 0.0
	m.star.global_position = Vector3(20.0, 0.0, 0.0)
	m.star.velocity = Vector3.ZERO
	m.star.stun_timer = 0.0
	m._give_ball_now(m.star)
	m._set_human(m.star)
	m._preplay_choice = ""
	m._preplay_hold = 0.0
	m._move_target = null
	m._reset_move_boost()


## Prepara una intro de ataque con el balón en los pies de tu jugador.
func _prepare_intro(kind: int) -> void:
	m._start_moment(kind)
	_clear_pitch()
	m._hud.show_preplay_choices(m._preplay_available())


## Cierra la intro y aplica la elección, como hace `_physics_process`.
func _start_play() -> void:
	m.state = m.State.MOMENT
	m._apply_preplay_choice()


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

	# --- La barra aparece en la intro de un ataque con balón. ---
	_prepare_intro(m.Moment.ATTACK)
	_check(m._hud.preplay_visible(), "no se ofrece elegir antes de la jugada")
	_check(m._preplay_choice == "", "la elección nace ya tomada")
	_check(not m._hud.cross_zone_at(Vector2(640.0, 360.0)),
		"la barra de elección se confunde con la de zonas")

	# --- CONDUCIR: arranca hacia la portería con sprint corto. ---
	m._on_preplay_selected(PrePlayChoice.DRIVE)
	_check(m._preplay_choice == PrePlayChoice.DRIVE, "la elección de conducir no se guarda")
	_check(not m._hud.preplay_visible(), "la barra sigue visible tras elegir")
	_start_play()
	_check(m._move_target != null, "conducir no fija un destino")
	if m._move_target != null:
		var to := SoccerMatch.flat(Vector3(m._move_target) - m.star.global_position)
		var to_goal := SoccerMatch.flat(m.opponent_goal_center(0) - m.star.global_position)
		_check(to.dot(to_goal) > 0.0, "conducir no va hacia la portería")
		_check(_near(to.length(), PrePlayChoice.DRIVE_DISTANCE, 0.2),
			"conducir no avanza la distancia prevista")
	_check(m._move_boost == PrePlayChoice.DRIVE_BOOST, "conducir no arranca con sprint")
	_check(m._preplay_choice == "", "la elección de conducir no se consume")

	# --- PASE RÁPIDO: suelta el balón al compañero mejor colocado. ---
	_prepare_intro(m.Moment.ATTACK)
	var mate := _mate()
	_check(mate != null, "no hay compañero para el pase rápido")
	if mate != null:
		mate.global_position = Vector3(32.0, 0.0, 0.0)
		mate.velocity = Vector3.ZERO
		m._on_preplay_selected(PrePlayChoice.QUICK_PASS)
		_check(m._preplay_choice == PrePlayChoice.QUICK_PASS, "la elección de pase no se guarda")
		_start_play()
		_check(m.star.is_kicking(), "el pase rápido no arranca el golpeo")
		await _wait_kick(m.star)
		_check(m.ball.last_kick_kind == "pass", "el pase rápido no sale como pase")
		_check(m._assist_target == mate, "el pase rápido no abre la asistencia")

	# --- AGUANTAR: frena, protege el balón y frena la entrada rival. ---
	_prepare_intro(m.Moment.ATTACK)
	var rival: SoccerPlayer = null
	for o: SoccerPlayer in m.teams[1]:
		if not o.is_keeper:
			rival = o
			break
	_check(rival != null, "no hay rival para probar el aguante")
	if rival != null:
		rival.global_position = m.star.global_position + Vector3(2.0, 0.0, 0.0)
		rival.tackle_cooldown = 0.0
	m.stamina = 0.5
	m._on_preplay_selected(PrePlayChoice.HOLD)
	_check(m._preplay_choice == PrePlayChoice.HOLD, "la elección de aguantar no se guarda")
	_start_play()
	_check(m._preplay_hold > 0.0, "aguantar no frena al jugador")
	_check(m._move_target == null, "aguantar deja un destino de carrera")
	_check(m.stamina > 0.5, "aguantar no recupera stamina")
	if rival != null:
		_check(rival.tackle_cooldown >= PrePlayChoice.HOLD_TACKLE_DELAY,
			"aguantar no frena la entrada del rival cercano")
	m._update_human(0.016)
	_check(m.star.move_input == Vector3.ZERO, "aguantar no deja al jugador quieto")
	# Tocar el césped recupera el control: el aguante se cancela.
	m._move_target = m.star.global_position + Vector3(0.0, 0.0, 5.0)
	m._update_human(0.016)
	_check(m._preplay_hold == 0.0, "tocar el césped no cancela el aguante")

	# --- Sin elección, la jugada arranca como siempre. ---
	_prepare_intro(m.Moment.ATTACK)
	_start_play()
	_check(m._preplay_choice == "" and m._preplay_hold == 0.0,
		"sin elección queda una acción pendiente")
	_check(m._move_target == null, "sin elección el jugador arranca solo")
	_check(not m._hud.preplay_visible(), "la barra sigue visible al arrancar sin elegir")

	# --- En defensa no se ofrece elegir. ---
	m._start_moment(m.Moment.DEFENSE)
	_check(not m._hud.preplay_visible(), "se ofrece elegir en una jugada defensiva")
	m._on_preplay_selected(PrePlayChoice.DRIVE)
	_check(m._preplay_choice == "", "una jugada defensiva acepta una elección")

	# --- Fin de jugada: no queda ninguna elección viva. ---
	_prepare_intro(m.Moment.ATTACK)
	_check(m._hud.preplay_visible(), "la barra no aparece antes de terminar")
	m._on_preplay_selected(PrePlayChoice.HOLD)
	m._finish_moment("Se acabó la ocasión")
	_check(not m._hud.preplay_visible(), "la barra sigue visible al terminar la jugada")
	_check(m._preplay_choice == "" and m._preplay_hold == 0.0,
		"al terminar la jugada queda una elección viva")

	scr.queue_free()
	await get_tree().process_frame
