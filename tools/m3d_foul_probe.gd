extends Node
## Sonda de regresión P0-03 · faltas a favor.
##   godot --headless --path . res://tools/M3DFoulProbe.tscn
##
## Valida la geometría del área (el bug original comparaba x > 44 y z < 11),
## la decisión penalti/tiro libre, que una falta a favor no cuente como jugada
## fallida, que no se dupliquen las faltas y que el balón parado pendiente se
## cobre al volver a la simulación.

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")
const FoulRules = preload("res://engine/match/FoulResolver.gd")

var fails := 0
var m: SoccerMatch

func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FALLA: ", msg)

func _ready() -> void:
	_test_resolver()
	await _test_match()
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)

## Reglas puras: área reglamentaria, espejo y riesgo de falta/tarjeta.
func _test_resolver() -> void:
	# El punto de penalti (41,5) es área, no tiro libre: el bug original lo
	# clasificaba mal porque comparaba x > 44.
	_check(FoulRules.set_piece_kind(Vector3(41.5, 0.0, 0.0), 1.0) == "penalty", "el punto de penalti no es penalti")
	_check(FoulRules.set_piece_kind(Vector3(36.0, 0.0, 0.0), 1.0) == "penalty", "el borde del área no es penalti")
	_check(FoulRules.set_piece_kind(Vector3(35.9, 0.0, 0.0), 1.0) == "free_kick", "un metro fuera del área no es tiro libre")
	_check(FoulRules.set_piece_kind(Vector3(30.0, 0.0, 0.0), 1.0) == "free_kick", "campo rival fuera del área no es tiro libre")
	_check(FoulRules.set_piece_kind(Vector3(-10.0, 0.0, 0.0), 1.0) == "none", "campo propio no debe dar tiro libre")
	_check(FoulRules.set_piece_kind(Vector3(41.5, 0.0, 20.1), 1.0) == "penalty", "el ancho del área no es penalti")
	_check(FoulRules.set_piece_kind(Vector3(41.5, 0.0, 20.2), 1.0) == "free_kick", "fuera del ancho del área no es tiro libre")
	# Espejo: equipo que ataca hacia -X.
	_check(FoulRules.set_piece_kind(Vector3(-41.5, 0.0, 0.0), -1.0) == "penalty", "el área espejo no es penalti")
	_check(FoulRules.set_piece_kind(Vector3(-30.0, 0.0, 0.0), -1.0) == "free_kick", "el campo rival espejo no es tiro libre")
	_check(FoulRules.set_piece_kind(Vector3(10.0, 0.0, 0.0), -1.0) == "none", "el campo propio espejo no debe dar tiro libre")
	# Árbitro estricto pita más que uno permisivo; el defensor con lectura
	# comete menos faltas que el impulsivo; la plancha es más arriesgada.
	var base := FoulRules.foul_chance(false, false, false, 0.5, 0.5, 1.0)
	_check(FoulRules.foul_chance(false, false, false, 0.5, 0.5, 1.3) > base, "el árbitro estricto no aumenta las faltas")
	_check(FoulRules.foul_chance(false, false, false, 0.5, 0.5, 0.8) < base, "el árbitro permisivo no reduce las faltas")
	_check(FoulRules.foul_chance(false, false, false, 0.2, 0.2, 1.0) > FoulRules.foul_chance(false, false, false, 0.9, 0.9, 1.0), "la lectura defensiva no reduce las faltas")
	_check(FoulRules.foul_chance(false, true, false, 0.5, 0.5, 1.0) > FoulRules.foul_chance(false, false, false, 0.5, 0.5, 1.0), "la plancha no es más arriesgada")
	_check(FoulRules.foul_chance(false, true, false, 0.5, 0.5, 1.0) > FoulRules.foul_chance(true, true, false, 0.5, 0.5, 1.0), "perder la entrada no es más arriesgado")
	_check(FoulRules.card_chance(true, 0.5, 0.5, 1.0) > FoulRules.card_chance(false, 0.5, 0.5, 1.0), "la plancha no saca más amarillas")
	_check(FoulRules.card_chance(false, 0.5, 0.5, 1.3) > FoulRules.card_chance(false, 0.5, 0.5, 0.8), "el árbitro tarjetero no saca más amarillas")

## Integración real: monta el partido 3D y fuerza faltas en zonas concretas.
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
	# Asegura que el usuario sea titular, como en M3DGameProbe.
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
	_check(m != null, "no se montó el partido 3D")
	if m == null:
		return
	if m.state == m.State.WALKOUT:
		m._end_walkout()
	_check(m._referee_foul_mult >= 0.5 and m._referee_card_mult >= 0.5, "los multiplicadores del árbitro no llegaron al 3D")
	# Sin amarillas aleatorias: esta sonda mide faltas, no tarjetas.
	m._referee_card_mult = 0.0
	var rival: SoccerPlayer = m.teams[1][5]

	# 1) Falta en el punto de penalti: debe ser penalti (no tiro libre) y no
	#    debe contar como jugada fallida.
	var fouls_before: int = int(m.match_stats.fouls[1])
	var ok_before: int = int(m.match_stats.me.moments_ok)
	_set_moment(Vector3(41.5, 0.0, 0.0))
	m._call_foul(rival, m.star)
	_check(m._pending_penalty, "la falta en el punto de penalti no dio penalti")
	_check(not m._pending_free_kick, "el penalti también quedó como tiro libre")
	_check(int(m.match_stats.fouls[1]) == fouls_before + 1, "la falta no se contó exactamente una vez")
	_check(int(m.match_stats.me.moments_ok) == ok_before + 1, "la falta a favor contó como jugada fallida")
	_check(m._foul_grade == "" and not m._foul_for_us, "la nota de la falta no se limpió")
	var last: Dictionary = m.match_stats.moment_log.back()
	_check(bool(last.get("ok", false)), "el log marca la falta a favor como fallida")
	_check(String(last.get("grade", "")) == "bueno", "la falta a favor no dejó nota positiva")
	_check(m.state == m.State.MOMENT_RESULT, "la falta no cerró la jugada")
	# Repetir la llamada no debe sumar otra falta.
	var after: int = int(m.match_stats.fouls[1])
	m._call_foul(rival, m.star)
	_check(int(m.match_stats.fouls[1]) == after, "la falta se contó dos veces")
	# El penalti pendiente se cobra al volver a la simulación.
	m.state = m.State.SIMULATING
	m._moments.clear()
	m.minute = 50.0
	m._sim_step(0.0)
	_check(m.state == m.State.MOMENT_INTRO and m.moment_type == m.Moment.PENALTY, "el penalti pendiente no se jugó")
	_check(not m._pending_penalty, "el penalti pendiente no se consumió")

	# 2) Falta fuera del área y en campo rival: tiro libre desde el lugar.
	_set_moment(Vector3(30.0, 0.0, 0.0))
	var spot: Vector3 = m.star.global_position
	m._call_foul(rival, m.star)
	_check(m._pending_free_kick and not m._pending_penalty, "la falta fuera del área no dio tiro libre")
	_check(m._pending_fk_spot.distance_to(spot) < 0.01, "el tiro libre no sale del lugar de la falta")
	m.state = m.State.SIMULATING
	m._moments.clear()
	m.minute = 50.0
	m._sim_step(0.0)
	_check(m.state == m.State.MOMENT_INTRO and m.moment_type == m.Moment.FREE_KICK, "el tiro libre pendiente no se jugó")

	# 3) Falta en campo propio: no hay balón parado ofensivo, pero tampoco
	#    debe contar como fallo.
	_set_moment(Vector3(-10.0, 0.0, 0.0))
	var ok_own: int = int(m.match_stats.me.moments_ok)
	m._call_foul(rival, m.star)
	_check(not m._pending_penalty and not m._pending_free_kick, "una falta en campo propio dio balón parado")
	_check(int(m.match_stats.me.moments_ok) == ok_own + 1, "la falta en campo propio contó como fallo")

	# 4) Falta del usuario: sigue siendo una jugada fallida y no da balón
	#    parado a favor.
	_set_moment(Vector3(10.0, 0.0, 0.0))
	rival.global_position = Vector3(10.5, 0.0, 0.0)
	var fouls_own: int = int(m.match_stats.fouls[0])
	m._call_foul(m.star, rival)
	_check(int(m.match_stats.fouls[0]) == fouls_own + 1, "la falta del usuario no se contó")
	_check(not m._pending_penalty and not m._pending_free_kick, "una falta del usuario dio balón parado a favor")
	var last_own: Dictionary = m.match_stats.moment_log.back()
	_check(not bool(last_own.get("ok", true)), "una falta del usuario no contó como jugada fallida")

	scr.queue_free()
	await get_tree().process_frame

## Deja el partido en un momento de ataque y coloca a tu jugador en `pos`.
func _set_moment(pos: Vector3) -> void:
	m._moments.clear()
	m._pending_penalty = false
	m._pending_free_kick = false
	m._pending_fk_spot = Vector3.ZERO
	m._foul_grade = ""
	m._foul_for_us = false
	m.state = m.State.MOMENT
	m.moment_type = m.Moment.ATTACK
	m.minute = 50.0
	m._halftime_pending = false
	m._extra_time_break_pending = false
	m.star.global_position = pos
	m.star.stun_timer = 0.0
	m.ball.owner_player = m.star
