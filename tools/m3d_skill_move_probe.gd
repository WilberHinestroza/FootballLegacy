extends Node
## Sonda de regresión P1-06 · jugadas de lujo (rabona, sombrero, elástica,
## bicicleta).
##   godot --headless --path . res://tools/M3DSkillMoveProbe.tscn
##
## Valida que el dibujo del gesto se clasifique bien, que el éxito dependa de
## los atributos y del defensor, y que el partido cobre stamina, abra el
## enfriamiento y ejecute la jugada (quiebro o golpeo) sin romper la posesión.

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")
const SkillMove = preload("res://engine/match/m3d/SkillMove.gd")

var fails := 0
var m: SoccerMatch

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		fails += 1
		print("FALLA: ", msg)

func _ready() -> void:
	_test_pure()
	await _test_match()
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


func _line(from: Vector2, to: Vector2, n := 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(from.lerp(to, float(i) / float(n - 1)))
	return pts


## Clasificación de gestos sintéticos y probabilidades puras.
func _test_pure() -> void:
	var straight := _line(Vector2(0, 0), Vector2(220, 0))
	_check(SkillMove.classify(straight) == "", "una línea recta se clasifica como jugada de lujo")
	_check(SkillMove.classify(_line(Vector2(0, 0), Vector2(60, 0), 4)) == "",
		"un gesto demasiado corto se clasifica como jugada de lujo")

	# V: ida y vuelta -> elástica.
	var v := PackedVector2Array([
		Vector2(0, 0), Vector2(50, 0), Vector2(100, 0), Vector2(150, 0),
		Vector2(100, 0), Vector2(50, 0), Vector2(0, 0)])
	_check(SkillMove.classify(v) == "elastica", "la V no se clasifica como elástica")

	# Círculo -> bicicleta.
	var circle := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		circle.append(Vector2(cos(a), sin(a)) * 45.0)
	circle.append(circle[0])
	_check(SkillMove.classify(circle) == "bicicleta", "el círculo no se clasifica como bicicleta")

	# Arco tendido -> sombrero.
	var arch := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0
		arch.append(Vector2(t * 240.0, 50.0 * (pow(2.0 * t - 1.0, 2.0) - 1.0)))
	_check(SkillMove.classify(arch) == "sombrero", "el arco no se clasifica como sombrero")

	# Un tiro con efecto normal (cuarto de vuelta) NO es jugada de lujo.
	var soft := PackedVector2Array()
	for i in 13:
		var a := (PI * 0.5) * float(i) / 12.0
		soft.append(Vector2(cos(a), sin(a)) * 160.0)
	_check(SkillMove.classify(soft) == "", "un tiro con efecto se clasifica como jugada de lujo")
	# Gancho claro de un solo lado -> rabona.
	var curve := PackedVector2Array()
	for i in 17:
		var a := deg_to_rad(130.0) * float(i) / 16.0
		curve.append(Vector2(cos(a), sin(a)) * 90.0)
	_check(SkillMove.classify(curve) == "rabona", "la curva no se clasifica como rabona")

	# Atributos y defensor.
	var base: float = SkillMove.success_chance("elastica", 0.7, 0.6, 0.6, 0.5)
	_check(SkillMove.success_chance("elastica", 0.95, 0.6, 0.6, 0.5) > base,
		"el regate no mejora la elástica")
	_check(SkillMove.success_chance("elastica", 0.7, 0.6, 0.6, 0.9) < base,
		"el defensor no complica la elástica")
	_check(SkillMove.success_chance("sombrero", 0.6, 0.95, 0.6, 0.5)
		> SkillMove.success_chance("sombrero", 0.6, 0.2, 0.6, 0.5),
		"el control no mejora el sombrero")
	_check(SkillMove.success_chance("rabona", 0.6, 0.6, 0.95, 0.5)
		> SkillMove.success_chance("rabona", 0.6, 0.6, 0.2, 0.5),
		"el pase no mejora la rabona")
	_check(SkillMove.success_chance("sombrero", 1.0, 1.0, 1.0, 0.0) <= 0.92,
		"la jugada de lujo no tiene techo de éxito")
	_check(SkillMove.success_chance("rabona", 0.0, 0.0, 0.0, 1.0) >= 0.2,
		"la jugada de lujo no tiene piso de éxito")
	_check(SkillMove.stamina_cost("sombrero") > SkillMove.stamina_cost("bicicleta"),
		"el sombrero no cuesta más stamina que la bicicleta")
	_check(absf(SkillMove.rabona_curl(curve)) > 0.0, "la rabona no define su efecto")


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
	m.stamina = 1.0
	m._skill_cooldown = 0.0
	m._give_ball_now(m.star)
	m.star.global_position = Vector3(0.0, 0.0, 0.0)
	for o: SoccerPlayer in m.teams[1]:
		o.global_position = Vector3(0.0, 0.0, 30.0)
	var rival: SoccerPlayer = m.teams[1][0]
	rival.global_position = m.star.global_position + Vector3(0.0, 0.0, 1.5)

	# Elástica: quiebro con costo y enfriamiento.
	m._execute_skill_move("elastica", Vector3(0.0, 0.0, 1.0), Vector3.RIGHT, PackedVector2Array())
	_check(m.stamina < 1.0, "la elástica no cobra stamina")
	_check(m._skill_cooldown > 0.0, "la elástica no abre el enfriamiento")
	_check(m.star.dodge_timer > 0.0, "la elástica no protege el balón")
	_check(m._dodge_chain >= 1, "la elástica no cuenta como quiebro")

	# Bicicleta: amague sin perder el balón.
	m._skill_cooldown = 0.0
	m.stamina = 1.0
	m._give_ball_now(m.star)
	m._execute_skill_move("bicicleta", Vector3(0.0, 0.0, 1.0), Vector3.RIGHT, PackedVector2Array())
	_check(m.stamina < 1.0, "la bicicleta no cobra stamina")
	_check(m.star.has_ball(), "la bicicleta te saca el balón de los pies")

	# Sombrero: la pelota sale de los pies.
	m._skill_cooldown = 0.0
	m.stamina = 1.0
	m._give_ball_now(m.star)
	m._execute_skill_move("sombrero", Vector3.RIGHT, Vector3.RIGHT, PackedVector2Array())
	_check(m.stamina < 1.0, "el sombrero no cobra stamina")
	_check(m.star.is_kicking(), "el sombrero no arranca el golpeo")

	# Rabona: pase con efecto (o remate si no hay compañero libre).
	m._skill_cooldown = 0.0
	m.stamina = 1.0
	m._give_ball_now(m.star)
	m._execute_skill_move("rabona", Vector3.RIGHT, Vector3.RIGHT, PackedVector2Array())
	_check(m.stamina < 1.0, "la rabona no cobra stamina")
	_check(m.star.is_kicking(), "la rabona no arranca el golpeo")

	# Un gesto dibujado dispara la jugada a través de _try_skill_move.
	m._skill_cooldown = 0.0
	m.stamina = 1.0
	m._give_ball_now(m.star)
	var v := PackedVector2Array([
		Vector2(0, 0), Vector2(50, 0), Vector2(100, 0), Vector2(150, 0),
		Vector2(100, 0), Vector2(50, 0), Vector2(0, 0)])
	_check(m._try_skill_move(v, Vector3(0.0, 0.0, 1.0), Vector3.RIGHT),
		"un gesto en V no dispara la jugada de lujo")
	_check(m._skill_cooldown > 0.0, "la jugada disparada no abre el enfriamiento")
	_check(not m._try_skill_move(v, Vector3(0.0, 0.0, 1.0), Vector3.RIGHT),
		"el enfriamiento no bloquea otra jugada seguida")

	scr.queue_free()
	await get_tree().process_frame
