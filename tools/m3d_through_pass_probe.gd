extends Node
## Sonda de regresión P1-07 · pase al hueco dibujado.
##   godot --headless --path . res://tools/M3DThroughPassProbe.tscn
##
## Valida que el pase del armado caiga en el punto elegido con el dedo, que el
## compañero más cercano a ese punto sea el que corre a recibirla y que el pase
## ya no se cuente como remate. Monta el partido 3D real.

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")

var fails := 0
var m: SoccerMatch

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		fails += 1
		print("FALLA: ", msg)

func _ready() -> void:
	await _test_match()
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


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
	m.moment_type = m.Moment.BUILDUP
	m.human = m.star
	m.star.global_position = Vector3(0.0, 0.0, 0.0)
	m.star.stats["passing"] = 100
	for o: SoccerPlayer in m.teams[1]:
		o.global_position = Vector3(-30.0, 0.0, 25.0)
	m._give_ball_now(m.star)

	# El compañero más cercano al punto elegido es el que corre a recibirla.
	var mates: Array[SoccerPlayer] = []
	for mate: SoccerPlayer in m.teams[0]:
		if mate != m.star and not mate.is_keeper:
			mates.append(mate)
	_check(mates.size() >= 2, "no hay compañeros para probar el pase al hueco")
	if mates.size() < 2:
		scr.queue_free()
		return
	var a: SoccerPlayer = mates[0]
	var b: SoccerPlayer = mates[1]
	a.global_position = Vector3(10.0, 0.0, 0.0)
	b.global_position = Vector3(40.0, 0.0, 20.0)
	var point := Vector3(38.0, 0.0, 19.0)
	_check(m._nearest_teammate_to(point) == b,
		"el pase no elige al compañero más cercano al punto dibujado")

	# El pase sale medido y no se cuenta como remate.
	var shots_before: int = m.match_stats.shots[0]
	m._through_pass_to(point, 1.0)
	_check(m.star.is_kicking(), "el pase al hueco no arranca el golpeo")
	_check(m.match_stats.shots[0] == shots_before,
		"el pase al hueco se cuenta como remate")

	# Tras soltar el balón, viaja hacia el punto elegido.
	await get_tree().create_timer(0.5).timeout
	var v := m.ball.linear_velocity
	var to_point := Vector3(point.x - m.ball.global_position.x, 0.0, point.z - m.ball.global_position.z)
	_check(m.ball.owner_player == null or m.ball.speed() > 1.0,
		"el pase al hueco no suelta el balón")
	if m.ball.speed() > 1.0 and to_point.length() > 1.0:
		var dot := Vector2(v.x, v.z).normalized().dot(Vector2(to_point.x, to_point.z).normalized())
		_check(dot > 0.6, "el balón no viaja hacia el punto dibujado")

	# El gesto completo del armado usa el pase al hueco (no un remate).
	m.state = m.State.MOMENT
	m.moment_type = m.Moment.BUILDUP
	m.human = m.star
	m._skill_cooldown = 0.0
	m.star.global_position = Vector3(0.0, 0.0, 0.0)
	m._give_ball_now(m.star)
	shots_before = m.match_stats.shots[0]
	m._on_swiped(PackedVector2Array([Vector2(420.0, 420.0), Vector2(760.0, 300.0)]), 0.2)
	_check(m.star.is_kicking(), "el deslizamiento del armado no dispara el pase al hueco")
	_check(m.match_stats.shots[0] == shots_before,
		"el deslizamiento del armado sigue contando un remate")

	scr.queue_free()
	await get_tree().process_frame
