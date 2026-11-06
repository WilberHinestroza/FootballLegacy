extends Node
## Sonda de regresión P1-03 · zona de tiro visible.
##   godot --headless --path . res://tools/M3DShotZoneProbe.tscn
##
## Valida que el aro de puntería se achique con la distancia a la portería, con
## la fatiga y con la presión del rival, y que el HUD lo dibuje y lo apague.
## Monta el partido 3D real para probar el camino completo.

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")
const ShotZone = preload("res://engine/match/m3d/ShotZone.gd")

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
	_test_assist_pure()
	await _test_match()
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


## La matemática pura: distancia, stamina y presión achican la zona.
func _test_pure() -> void:
	var close: float = ShotZone.radius(8.0, 1.0, 99.0)
	var far: float = ShotZone.radius(40.0, 1.0, 99.0)
	_check(close > far, "la zona no se achica con la distancia")
	_check(_near(close, ShotZone.MAX_RADIUS), "a quemarropa y fresco la zona no llega al máximo")
	_check(_near(far, ShotZone.MIN_RADIUS), "lejos y sin presión la zona no baja al mínimo")
	var fresh: float = ShotZone.radius(20.0, 1.0, 99.0)
	var tired: float = ShotZone.radius(20.0, 0.0, 99.0)
	_check(fresh > tired, "la fatiga no achica la zona")
	var free: float = ShotZone.radius(20.0, 1.0, 99.0)
	var pressed: float = ShotZone.radius(20.0, 1.0, 0.5)
	_check(free > pressed, "la presión del rival no achica la zona")
	_check(_near(ShotZone.radius(20.0, 1.0, ShotZone.PRESSURE_RADIUS * 2.0), free),
		"un rival lejano sigue presionando")
	_check(ShotZone.radius(80.0, 0.0, 0.0) >= ShotZone.MIN_RADIUS,
		"la zona puede quedar por debajo del mínimo")
	_check(ShotZone.radius(0.0, 2.0, 999.0) <= ShotZone.MAX_RADIUS,
		"la zona puede pasarse del máximo")
	_check(ShotZone.color_for(close).g > ShotZone.color_for(far).g,
		"el color no pasa de verde a rojo al achicarse la zona")


## P1-04: la asistencia de puntería mezcla el gesto con la dirección al arco.
func _test_assist_pure() -> void:
	_check(ShotZone.assist_blend("alta") > ShotZone.assist_blend("media"),
		"la asistencia alta no endereza más que la media")
	_check(ShotZone.assist_blend("media") > ShotZone.assist_blend("manual"),
		"la asistencia media no endereza más que la manual")
	_check(_near(ShotZone.assist_blend("manual"), 0.0), "la asistencia manual no es neutra")
	var to_goal := Vector3.RIGHT
	var dir := Vector3(1.0, 0.0, 0.6).normalized()
	var manual: Vector3 = ShotZone.assist_dir(dir, to_goal, "manual")
	var media: Vector3 = ShotZone.assist_dir(dir, to_goal, "media")
	var alta: Vector3 = ShotZone.assist_dir(dir, to_goal, "alta")
	_check(manual.distance_to(dir) < 0.0001, "la asistencia manual no respeta el gesto")
	_check(alta.z < media.z and media.z < dir.z,
		"la asistencia no acerca el gesto al arco")
	_check(alta.x > media.x, "la asistencia alta no apunta más de frente")


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

	# Todos los rivales lejos: sin presión.
	for o: SoccerPlayer in m.teams[1]:
		o.global_position = Vector3(0.0, 0.0, 30.0)
	m.state = m.State.MOMENT
	m.moment_type = m.Moment.ATTACK
	m._shot_pending = false
	m._penalty_kicked = false
	m.human = m.star
	m._give_ball_now(m.star)
	m.stamina = 1.0
	m.star.global_position = Vector3(40.0, 0.0, 0.0)
	m._update_aim_zone()
	var close_radius: float = m._aim_zone_radius
	_check(close_radius > 0.0, "cerca del arco no se calculó la zona de tiro")

	# Más lejos: la zona tiene que achicarse.
	m.star.global_position = Vector3(10.0, 0.0, 0.0)
	m._update_aim_zone()
	var far_radius: float = m._aim_zone_radius
	_check(far_radius < close_radius, "la zona no se achica al alejarse del arco")

	# A media distancia (donde aún hay margen) la fatiga y la presión se notan.
	m.star.global_position = Vector3(25.0, 0.0, 0.0)
	m._update_aim_zone()
	var mid_radius: float = m._aim_zone_radius
	_check(mid_radius > 0.0 and mid_radius < close_radius, "la zona a media distancia no es intermedia")

	# Cansado: la zona se achica todavía más.
	m.stamina = 0.0
	m._update_aim_zone()
	_check(m._aim_zone_radius < mid_radius, "la fatiga no achica la zona en el partido")

	# Con un rival encima: se achica aún más.
	m.stamina = 1.0
	var rival: SoccerPlayer = m.teams[1][0]
	rival.global_position = m.star.global_position + Vector3(0.8, 0.0, 0.0)
	m._update_aim_zone()
	_check(m._aim_zone_radius < mid_radius, "la presión no achica la zona en el partido")

	# Sin remate posible, el aro desaparece.
	m.state = m.State.MOMENT_RESULT
	m._update_aim_zone()
	_check(_near(m._aim_zone_radius, 0.0) and not m._hud._aim_arc.visible,
		"fuera de la jugada el aro no se apaga")

	# El HUD dibuja y apaga el aro.
	m._hud.show_aim_zone(Vector2(100.0, 100.0), 40.0, Color(0.2, 1.0, 0.4))
	_check(m._hud._aim_arc.visible, "show_aim_zone no muestra el aro")
	_check(m._hud._aim_arc.points.size() == 40, "el aro no se dibuja como círculo cerrado")
	m._hud.show_aim_zone(Vector2(100.0, 100.0), 0.5, Color.WHITE)
	_check(not m._hud._aim_arc.visible, "un aro demasiado pequeño no se oculta")
	m._hud.show_aim_zone(Vector2(100.0, 100.0), 40.0, Color.WHITE)
	m._hud.hide_aim_zone()
	_check(not m._hud._aim_arc.visible, "hide_aim_zone no apaga el aro")

	# P1-04: el partido usa la preferencia global y la aplica al gesto de remate.
	var prev: String = Preferences.aim_assist
	var dir := Vector3(1.0, 0.0, 0.55).normalized()
	var to_goal := Vector3.RIGHT
	Preferences.set_aim_assist("manual")
	_check(Preferences.aim_assist == "manual", "set_aim_assist no guarda el nivel manual")
	var manual: Vector3 = m._shot_dir_assist(dir, to_goal)
	_check(manual.distance_to(dir) < 0.0001, "en manual el partido no respeta el gesto")
	Preferences.set_aim_assist("alta")
	_check(Preferences.aim_assist == "alta", "set_aim_assist no guarda el nivel alto")
	var alta: Vector3 = m._shot_dir_assist(dir, to_goal)
	_check(alta.z < manual.z, "en alta el partido no endereza hacia el arco")
	_check(alta.distance_to(to_goal) < manual.distance_to(to_goal),
		"en alta el remate no queda más cerca de la portería")
	Preferences.set_aim_assist("imposible")
	_check(Preferences.aim_assist == "alta", "set_aim_assist acepta un nivel inválido")
	Preferences.set_aim_assist(prev)

	scr.queue_free()
	await get_tree().process_frame
