extends Node
## Sonda de regresión P1-08 · pase de primera.
##   godot --headless --path . res://tools/M3DFirstTouchProbe.tscn
##
## Valida que un balón que viene hacia ti se pueda jugar de un toque (a un
## compañero o al hueco) antes de controlarlo, y que NO se dispare cuando el
## balón está lejos, lo tienes tú, viene lento o se aleja. Monta el partido 3D.

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


## Deja el balón libre en una posición con una velocidad concreta.
func _set_ball(pos: Vector3, vel: Vector3) -> void:
	m.ball.owner_player = null
	m.ball.global_position = pos
	m.ball.linear_velocity = vel
	m.ball._pending_velocity = null


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
	_check(mates.size() >= 1, "no hay compañeros para probar el pase de primera")
	if mates.is_empty():
		scr.queue_free()
		return
	var mate: SoccerPlayer = mates[0]
	mate.global_position = Vector3(12.0, 0.0, 0.0)
	mate.velocity = Vector3.ZERO

	# --- Positivo: balón que llega, toque al compañero. ---
	_set_ball(Vector3(0.0, 0.0, -2.2), Vector3(0.0, 0.0, 6.0))
	var shots_before: int = m.match_stats.shots[0]
	_check(m._try_first_touch(Vector2.ZERO, mate), "el balón que llega no se juega de primera")
	_check(m.ball.last_touch == m.star, "el pase de primera no queda a nombre del jugador")
	_check(m.ball.owner_player == null, "el pase de primera se queda pegada a los pies")
	var v := m.ball.velocity_now()
	_check(v.x > 4.0, "el pase de primera no busca al compañero")
	_check(not m.ball.can_be_picked_by(m.star),
		"el jugador puede recoger su propio pase de primera")
	_check(m.match_stats.shots[0] == shots_before,
		"el pase de primera se cuenta como remate")

	# --- Negativo: balón demasiado lejos. ---
	_set_ball(Vector3(0.0, 0.0, -5.0), Vector3(0.0, 0.0, 6.0))
	_check(not m._try_first_touch(Vector2.ZERO, mate),
		"un balón a más de 3,4 m se juega de primera")

	# --- Negativo: el balón ya lo tienes tú. ---
	m._give_ball_now(m.star)
	_check(not m._try_first_touch(Vector2.ZERO, mate),
		"con el balón controlado se dispara el pase de primera")

	# --- Negativo: balón lento. ---
	_set_ball(Vector3(0.0, 0.0, -2.0), Vector3(0.0, 0.0, 1.0))
	_check(not m._try_first_touch(Vector2.ZERO, mate),
		"un balón lento se juega de primera")

	# --- Negativo: el balón se aleja. ---
	_set_ball(Vector3(0.0, 0.0, -2.0), Vector3(0.0, 0.0, -6.0))
	_check(not m._try_first_touch(Vector2.ZERO, mate),
		"un balón que se aleja se juega de primera")

	# --- Negativo: tocar cerca de uno mismo es moverse, no jugarla. ---
	# La cámara del partido mira casi de frente, así que usamos el punto del
	# suelo al que proyecta un toque y colocamos al jugador justo ahí.
	var far_screen := Vector2(760.0, 300.0)
	var far_ground: Vector3 = m._clamp_to_field(m._ground_point(far_screen))
	m.star.global_position = far_ground
	_set_ball(far_ground + Vector3(0.0, 0.0, -2.0), Vector3(0.0, 0.0, 6.0))
	_check(not m._try_first_touch(far_screen, null),
		"tocar cerca de uno mismo dispara el pase de primera")
	m.star.global_position = Vector3.ZERO

	# --- Positivo: tocar el césped manda la pelota al hueco. ---
	_set_ball(Vector3(0.0, 0.0, -2.0), Vector3(0.0, 0.0, 6.0))
	_check(SoccerMatch.flat_dist(far_ground, m.star.global_position) > SoccerMatch.FIRST_TOUCH_MIN_TARGET,
		"la pantalla lejana no proyecta lejos del jugador")
	_check(m._try_first_touch(far_screen, null),
		"el toque al hueco no se juega de primera")
	var v2 := m.ball.velocity_now()
	var to_ground := SoccerMatch.flat(far_ground - m.ball.global_position)
	if to_ground.length() > 1.0:
		var dot := Vector2(v2.x, v2.z).normalized().dot(Vector2(to_ground.x, to_ground.z).normalized())
		_check(dot > 0.6, "el pase de primera no va hacia el punto dibujado")

	# --- Integración: el toque del partido dispara el pase de primera. ---
	m._move_target = null
	_set_ball(Vector3(0.0, 0.0, -2.0), Vector3(0.0, 0.0, 6.0))
	m._on_tapped(far_screen)
	_check(m.ball.last_touch == m.star and m.ball.owner_player == null,
		"el toque del partido no juega el balón de primera")
	_check(m._move_target == null, "el pase de primera también mueve al jugador")

	# --- Integración: sin balón cerca, el toque sigue moviendo al jugador. ---
	m._move_target = null
	_set_ball(Vector3(30.0, 0.0, 30.0), Vector3.ZERO)
	m._on_tapped(far_screen)
	_check(m._move_target != null, "el toque normal dejó de mover al jugador")

	scr.queue_free()
	await get_tree().process_frame
