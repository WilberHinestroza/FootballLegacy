extends Node
## Sonda de regresión P1-10 · centro con zona elegida.
##   godot --headless --path . res://tools/M3DCrossZoneProbe.tscn
##
## Valida los tres puntos del área (primer palo, segundo palo y punto penal),
## que el centro espere tu elección, que los botones del HUD no muevan al
## jugador y que el balón salga hacia la zona elegida. Monta el partido 3D real.

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")
const CrossZone = preload("res://engine/match/m3d/CrossZone.gd")

var fails := 0
var m: SoccerMatch

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		fails += 1
		print("FALLA: ", msg)

func _near(a: float, b: float, eps := 0.01) -> bool:
	return absf(a - b) <= eps

func _ready() -> void:
	_test_pure()
	await _test_match()
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


## La geometría pura de las tres zonas.
func _test_pure() -> void:
	var goal := Vector3(52.5, 0.0, 0.0)
	var zones := CrossZone.targets(goal, 1.0, 4.1)
	_check(zones.size() == 3, "el centro no tiene tres zonas")
	_check(CrossZone.zone_by_id(zones, CrossZone.NEAR_POST).point.z > 0.0,
		"el primer palo no está en la banda del centro (+Z)")
	var near: Dictionary = CrossZone.zone_by_id(zones, CrossZone.NEAR_POST)
	var far: Dictionary = CrossZone.zone_by_id(zones, CrossZone.FAR_POST)
	var spot: Dictionary = CrossZone.zone_by_id(zones, CrossZone.PENALTY_SPOT)
	_check(far.point.z < 0.0, "el segundo palo no está en la banda opuesta")
	_check(_near(near.point.z + far.point.z, 0.0, 0.001), "los dos palos no son simétricos")
	_check(_near(spot.point.x, goal.x - CrossZone.SPOT_DISTANCE), "el punto penal no está a 11 m")
	_check(_near(spot.point.z, 0.0, 0.001), "el punto penal no está centrado")
	_check(near.point.x < goal.x and far.point.x < goal.x, "los palos quedan detrás de la línea")
	_check(CrossZone.height_for(CrossZone.PENALTY_SPOT) < CrossZone.height_for(CrossZone.NEAR_POST),
		"el centro al punto penal no baja más que a los palos")
	_check(CrossZone.is_valid(CrossZone.NEAR_POST) and CrossZone.is_valid(CrossZone.FAR_POST)
		and CrossZone.is_valid(CrossZone.PENALTY_SPOT), "alguna zona válida no se reconoce")
	_check(not CrossZone.is_valid("inventada"), "una zona inventada se acepta")
	_check(CrossZone.label_for(CrossZone.FAR_POST) != "", "la zona no tiene etiqueta")
	_check(CrossZone.label_for("inventada") == "", "una zona inventada tiene etiqueta")
	_check(CrossZone.DEFAULT == CrossZone.NEAR_POST, "la zona por defecto no es el primer palo")

	var mirrored := CrossZone.targets(goal, -1.0, 4.1)
	_check(CrossZone.zone_by_id(mirrored, CrossZone.NEAR_POST).point.z < 0.0,
		"el primer palo no cambia al centrar desde la otra banda")
	_check(CrossZone.nearest_id(near.point, zones) == CrossZone.NEAR_POST,
		"la zona más cercana a un palo no coincide")
	_check(_near(CrossZone.point_for(goal, 1.0, CrossZone.FAR_POST).z, far.point.z),
		"point_for no devuelve el punto de la zona")


func _wait_kick(p: SoccerPlayer) -> void:
	var t := 0.0
	while p.is_kicking() and t < 2.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05


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

	# --- El centro espera la elección de zona. ---
	m._start_moment(m.Moment.CROSS)
	_check(m.moment_type == m.Moment.CROSS, "el momento no es un centro")
	_check(m._cross_pending, "el centro no espera la elección de zona")
	_check(m._cross_carrier != null and m._cross_carrier != m.star, "no hay un compañero para centrar")
	if m._cross_carrier == null:
		scr.queue_free()
		return
	_check(m._cross_carrier.has_ball(), "el centro no arranca con el balón")
	_check(m._cross_carrier.ai_timer > m.CROSS_ZONE_AUTO_SECONDS,
		"la IA puede centrar antes de que elijas zona")
	_check(not m._hud._cross_bar.visible, "la barra de zonas aparece durante la intro")

	# --- Al empezar la jugada aparecen los tres botones. ---
	m.state = m.State.MOMENT
	m._hud.show_cross_zones(true)
	await get_tree().process_frame
	_check(m._hud._cross_bar.visible, "la barra de zonas no se muestra al empezar")
	_check(m._hud._cross_bar.get_child_count() == 3, "faltan botones de zona")

	# --- Tocar un botón no es una orden de movimiento. ---
	var btn: Button = m._hud._cross_bar.get_child(0)
	var center := btn.get_global_rect().get_center()
	_check(m._hud.cross_zone_at(center), "el HUD no reconoce el toque en un botón")
	var before: Variant = m._move_target
	m._on_tapped(center)
	_check(m._move_target == before, "tocar un botón de zona mueve al jugador")

	# --- Elegir el segundo palo: el centro sale hacia allí y tú atacas la zona. ---
	var crosser: SoccerPlayer = m._cross_carrier
	var side := signf(crosser.global_position.z)
	var zones := CrossZone.targets(m.opponent_goal_center(0), side, m.GOAL_WIDTH * 0.5)
	var far: Dictionary = CrossZone.zone_by_id(zones, CrossZone.FAR_POST)
	m._on_cross_zone_selected(CrossZone.FAR_POST)
	_check(not m._cross_pending, "la elección no cierra la espera de zona")
	_check(m._cross_zone == CrossZone.FAR_POST, "la zona elegida no se guarda")
	_check(not m._hud._cross_bar.visible, "la barra de zonas no se oculta al elegir")
	_check(m._move_target != null and Vector3(m._move_target).distance_to(far.point) < 0.01,
		"el jugador no ataca el palo elegido")
	await _wait_kick(crosser)
	var v := m.ball.velocity_now()
	_check(v.y > 2.0, "el centro no sale elevado")
	_check(m.ball.last_kick_kind == "pass", "el centro no se registra como pase")
	var to_far := SoccerMatch.flat(far.point - crosser.global_position)
	_check(absf(to_far.z) < 0.1 or signf(v.z) == signf(to_far.z),
		"el centro no va hacia el palo elegido")

	# --- Sin elección, el centro sale solo al primer palo. ---
	m._start_moment(m.Moment.CROSS)
	_check(m._cross_pending and m._cross_carrier != null, "el segundo centro no espera zona")
	m.state = m.State.MOMENT
	m._hud.show_cross_zones(true)
	m._cross_auto = 0.0
	m._update_cross_zone(0.1)
	_check(not m._cross_pending, "el tiempo de elección no lanza el centro")
	_check(m._cross_zone == CrossZone.DEFAULT, "el centro automático no va al primer palo")
	_check(not m._hud._cross_bar.visible, "la barra sigue visible tras el centro automático")

	# --- Fin de jugada: se cancela cualquier espera pendiente. ---
	m._start_moment(m.Moment.CROSS)
	m._finish_moment("Se acabó la ocasión")
	_check(not m._cross_pending and not m._hud._cross_bar.visible,
		"al terminar la jugada queda una zona pendiente")

	scr.queue_free()
	await get_tree().process_frame
