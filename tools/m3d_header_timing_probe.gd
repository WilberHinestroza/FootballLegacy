extends Node
## Sonda de regresión P1-11 · cabezazo con timing.
##   godot --headless --path . res://tools/M3DHeaderTimingProbe.tscn
##
## Valida la ventana de contacto, la calidad según altura/distancia/atributos y
## que el partido 3D cebece solo cuando el balón baja por la franja de la cabeza.
## Un balón alto o un jugador lejos ya no cabecean: llegan tarde.

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")
const HeaderTiming = preload("res://engine/match/m3d/HeaderTiming.gd")

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


func _test_pure() -> void:
	_check(HeaderTiming.in_window(1.8, -2.0), "un balón a la altura de la cabeza y bajando no entra en la ventana")
	_check(not HeaderTiming.in_window(1.8, 2.0), "un balón que sube entra en la ventana")
	_check(not HeaderTiming.in_window(HeaderTiming.MIN_HEIGHT - 0.1, -2.0),
		"un balón por debajo de la franja entra en la ventana")
	_check(not HeaderTiming.in_window(HeaderTiming.MAX_HEIGHT + 0.1, -2.0),
		"un balón por encima de la franja entra en la ventana")
	_check(HeaderTiming.ideal_height(1.0) > HeaderTiming.ideal_height(0.0),
		"un jugador fuerte no cabecea más arriba")
	_check(HeaderTiming.height_tolerance(1.0) > HeaderTiming.height_tolerance(0.0),
		"un jugador fuerte no tiene más margen")
	var ideal := HeaderTiming.ideal_height(0.5)
	var q_ideal := HeaderTiming.quality(ideal, 0.0, 0.5, 0.5)
	var q_low := HeaderTiming.quality(HeaderTiming.MIN_HEIGHT, 0.0, 0.5, 0.5)
	var q_high := HeaderTiming.quality(HeaderTiming.MAX_HEIGHT, 0.0, 0.5, 0.5)
	_check(_near(q_ideal, 1.0, 0.02), "el contacto en la altura ideal no es limpio")
	_check(q_low < q_ideal, "el balón bajo no empeora el contacto")
	_check(q_high < q_ideal, "el balón alto no empeora el contacto")
	_check(HeaderTiming.reach(1.0) > HeaderTiming.reach(0.0),
		"la sangre fría no estira el alcance")
	var close := HeaderTiming.distance_quality(0.0, 0.5)
	var far := HeaderTiming.distance_quality(HeaderTiming.MAX_DISTANCE + 0.5, 0.5)
	_check(_near(close, 1.0), "un balón pegado no da calidad máxima")
	_check(_near(far, 0.0), "un balón lejano sigue dando calidad")
	_check(HeaderTiming.quality(ideal, HeaderTiming.MAX_DISTANCE + 1.0, 0.5, 0.5) == 0.0,
		"un jugador lejos puede cabecear")
	_check(not HeaderTiming.can_contact(0.0), "un contacto nulo se acepta")
	_check(HeaderTiming.can_contact(0.5), "un contacto válido se rechaza")
	_check(HeaderTiming.is_clean(HeaderTiming.CLEAN_QUALITY), "el umbral limpio no se reconoce")
	_check(not HeaderTiming.is_clean(HeaderTiming.CLEAN_QUALITY - 0.1), "un contacto flojo se da por limpio")
	_check(HeaderTiming.power_scale(1.0) > HeaderTiming.power_scale(0.2),
		"un mal contacto no resta fuerza")
	_check(HeaderTiming.accuracy_scale(1.0) > HeaderTiming.accuracy_scale(0.2),
		"un mal contacto no resta puntería")


func _reset_ball(pos: Vector3, vel: Vector3) -> void:
	m.ball.owner_player = null
	m.ball.global_position = pos
	m.ball.linear_velocity = vel
	m.ball._pending_velocity = null
	m.ball._blocked_time = 0.0
	m.ball.last_kick_kind = ""
	m.ball.last_touch = null
	m._last_header_ms = -10000


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
	m.moment_type = m.Moment.CROSS
	m.human = m.star
	m._shot_pending = false
	m._penalty_kicked = false
	m.star.global_position = Vector3(45.0, 0.0, 0.0)
	m.star.velocity = Vector3.ZERO
	for p: SoccerPlayer in m.players:
		if p != m.star:
			p.global_position = Vector3(-40.0, 0.0, 28.0)
			p.velocity = Vector3.ZERO

	# --- Balón en la franja y bajando: cabezazo real. ---
	_reset_ball(m.star.global_position + Vector3(0.0, 1.8, 0.0), Vector3(0.0, -2.0, 0.0))
	var shots_before := int(m.match_stats.me.shots)
	m._update_possession(0.016)
	_check(m.ball.last_kick_kind == "shot", "un balón cabeceable no se cabecea")
	_check(m.ball.last_touch == m.star, "el cabezazo no lo firma el jugador")
	_check(int(m.match_stats.me.shots) == shots_before + 1, "el cabezazo no cuenta como remate")
	_check(m.ball.velocity_now().x > 0.0, "el cabezazo no va hacia la portería rival")
	_check(m.ball.velocity_now().length() > 8.0, "el cabezazo sale sin fuerza")

	# --- Balón por debajo de la franja: llega tarde y no cabecea. ---
	_reset_ball(m.star.global_position + Vector3(0.0, HeaderTiming.MIN_HEIGHT - 0.2, 0.0),
		Vector3(0.0, -2.0, 0.0))
	m._update_possession(0.016)
	_check(m.ball.last_kick_kind != "shot", "un balón bajo se cabecea igual")

	# --- Balón por encima de la franja: aún no es el momento. ---
	_reset_ball(m.star.global_position + Vector3(0.0, HeaderTiming.MAX_HEIGHT + 0.2, 0.0),
		Vector3(0.0, -2.0, 0.0))
	m._update_possession(0.016)
	_check(m.ball.last_kick_kind != "shot", "un balón alto se cabecea antes de tiempo")

	# --- Jugador lejos del balón: no llega. ---
	_reset_ball(m.star.global_position + Vector3(HeaderTiming.MAX_DISTANCE + 0.6, 1.8, 0.0),
		Vector3(0.0, -2.0, 0.0))
	m._update_possession(0.016)
	_check(m.ball.last_kick_kind != "shot", "un jugador lejos cabecea igual")

	# --- Contacto flojo: sale más lento que uno limpio. ---
	m.star.global_position = Vector3(45.0, 0.0, 0.0)
	m.ball.owner_player = null
	m.ball.last_kick_kind = ""
	m._header(m.star, 0.2)
	var weak := m.ball.velocity_now().length()
	m.ball.owner_player = null
	m.ball.last_kick_kind = ""
	m._header(m.star, 1.0)
	var clean := m.ball.velocity_now().length()
	_check(clean > weak, "un cabezazo flojo sale igual de fuerte que uno limpio")

	scr.queue_free()
	await get_tree().process_frame
