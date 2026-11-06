extends Node
## Sonda de regresión P1-14 · cambio de ritmo.
##   godot --headless --path . res://tools/M3DMomentumProbe.tscn
##
## Valida la matemática pura (acelerar rápido, frenar con inercia, distancia de
## frenada y costo de estamina) y la integración real: esprintar gasta la
## estamina del partido, el multi-toque gasta más, sin fondo físico se corta el
## sprint y el jugador conserva velocidad al soltar el mando (no frena en seco).

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")
const Momentum = preload("res://engine/match/m3d/Momentum.gd")

var fails := 0
var m: SoccerMatch

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		fails += 1
		print("FALLA: ", msg)

func _near(a: float, b: float, eps := 0.0001) -> bool:
	return absf(a - b) <= eps

func _ready() -> void:
	_test_pure()
	await _test_match()
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


## La matemática pura: ritmos de aceleración/frenada y gasto de estamina.
func _test_pure() -> void:
	_check(Momentum.BRAKE < Momentum.ACCEL, "frenar no cuesta menos que acelerar")
	_check(Momentum.BRAKE_SPRINT < Momentum.BRAKE, "el sprint no cuesta más frenar que el trote")
	_check(Momentum.BRAKE_SPRINT < Momentum.BRAKE_BALL and Momentum.BRAKE_BALL < Momentum.BRAKE,
		"la frenada con balón no queda entre la del sprint y la normal")

	_check(_near(Momentum.rate(0.0, 6.2), Momentum.ACCEL), "arrancar no usa la aceleración viva")
	_check(_near(Momentum.rate(6.2, 6.2), Momentum.ACCEL), "mantener la velocidad no acelera")
	_check(_near(Momentum.rate(6.2, 0.0), Momentum.BRAKE), "frenar no usa la inercia normal")
	_check(_near(Momentum.rate(6.2, 0.0, true), Momentum.BRAKE_SPRINT),
		"frenar desde el sprint no usa la inercia del sprint")
	_check(_near(Momentum.rate(6.2, 0.0, false, true), Momentum.BRAKE_BALL),
		"frenar con balón no protege el control")

	var normal := Momentum.stopping_distance(6.2, Momentum.BRAKE)
	var sprint := Momentum.stopping_distance(8.6, Momentum.BRAKE_SPRINT)
	_check(normal > 0.0, "la frenada normal no recorre distancia")
	_check(sprint > normal, "el sprint no necesita más metros para parar")
	_check(_near(Momentum.stopping_distance(0.0), 0.0), "parado se sigue recorriendo distancia")
	_check(Momentum.stopping_distance(10.0, 0.0) > 0.0, "una frenada nula no recorre distancia")

	_check(_near(Momentum.stamina_cost(1.0, false, 0), 0.0), "sin sprint se gasta estamina")
	_check(_near(Momentum.stamina_cost(1.0, true, 0), Momentum.SPRINT_DRAIN),
		"el sprint no gasta la estamina configurada")
	_check(Momentum.stamina_cost(1.0, true, 2) > Momentum.stamina_cost(1.0, true, 0),
		"el multi-toque no gasta más estamina que el sprint")
	_check(_near(Momentum.stamina_cost(1.0, true, 2),
		Momentum.SPRINT_DRAIN + Momentum.BOOST_DRAIN * 2.0),
		"el gasto del multi-toque no es el configurado")
	_check(_near(Momentum.stamina_cost(0.5, true, 0), Momentum.SPRINT_DRAIN * 0.5),
		"el gasto de estamina no escala con el tiempo")
	_check(_near(Momentum.stamina_cost(0.0, true, 2), 0.0), "sin tiempo se gasta estamina")
	_check(_near(Momentum.stamina_cost(-1.0, true, 2), 0.0), "un delta negativo gasta estamina")


## Deja al jugador aislado y con el mando manual para medir su física.
func _isolate() -> void:
	m.set_physics_process(false)
	m.star.set_physics_process(false)
	m.star.stun_timer = 0.0
	m.star._receive_timer = 0.0
	m.star._action_timer = 0.0
	m.star.move_boost = 0.0
	m.star.sprinting = false
	m.star.facing = Vector3.RIGHT
	m.ball.owner_player = null
	m.ball.global_position = Vector3(-40.0, 0.0, 30.0)
	m.ball.linear_velocity = Vector3.ZERO


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
	_isolate()

	var dt := 1.0 / 60.0

	# --- Frenada normal: conserva inercia, no se planta de golpe. ---
	m.star.velocity = Vector3(SoccerPlayer.SPEED, 0.0, 0.0)
	m.star.move_input = Vector3.ZERO
	m.star._physics_process(dt)
	var v_normal := m.star.velocity.length()
	_check(v_normal < SoccerPlayer.SPEED - 0.2, "soltar el mando no reduce la velocidad")
	_check(_near(v_normal, SoccerPlayer.SPEED - Momentum.BRAKE * dt, 0.01),
		"la frenada normal no usa la inercia configurada")

	# --- Frenada desde el sprint: cuesta más parar que trotando. ---
	m.star.velocity = Vector3(SoccerPlayer.SPRINT_SPEED, 0.0, 0.0)
	m.star.sprinting = true
	m.star.move_input = Vector3.ZERO
	m.star._physics_process(dt)
	var v_sprint := m.star.velocity.length()
	_check(_near(v_sprint, SoccerPlayer.SPRINT_SPEED - Momentum.BRAKE_SPRINT * dt, 0.01),
		"la frenada del sprint no usa su inercia")
	_check((SoccerPlayer.SPRINT_SPEED - v_sprint) < (SoccerPlayer.SPEED - v_normal),
		"el sprint frena tan rápido como el trote")
	m.star.sprinting = false

	# --- Con el balón se frena algo más despacio (se protege el control). ---
	m._give_ball_now(m.star)
	m.star.velocity = Vector3(SoccerPlayer.SPEED, 0.0, 0.0)
	m.star.sprinting = false
	m.star.move_input = Vector3.ZERO
	m.star._physics_process(dt)
	var v_ball := m.star.velocity.length()
	_check(_near(v_ball, SoccerPlayer.SPEED - Momentum.BRAKE_BALL * dt, 0.01),
		"la frenada con balón no usa su inercia")
	_check(v_ball > v_normal, "con balón se frena más rápido que sin balón")
	m.ball.owner_player = null
	m.ball.global_position = Vector3(-40.0, 0.0, 30.0)

	# --- Arrancar es más vivo que frenar. ---
	m.star.velocity = Vector3.ZERO
	m.star.facing = Vector3.RIGHT
	m.star.move_input = Vector3.RIGHT
	m.star.sprinting = false
	m.star._physics_process(dt)
	var v_accel := m.star.velocity.length()
	_check(_near(v_accel, Momentum.ACCEL * dt, 0.02), "arrancar no usa la aceleración viva")
	_check(v_accel > (SoccerPlayer.SPEED - v_normal), "arrancar no es más vivo que frenar")

	# --- Esprintar gasta la estamina del partido. ---
	m.star.move_input = Vector3.ZERO
	m._move_target = m.star.global_position + Vector3(20.0, 0.0, 0.0)
	m._move_boost = 0
	m.stamina = 1.0
	m._update_human(0.5)
	_check(m.human.sprinting, "la orden de correr no activa el sprint")
	_check(_near(m.stamina, 1.0 - Momentum.stamina_cost(0.5, true, 0)),
		"el sprint no gasta la estamina configurada")

	# --- El multi-toque gasta todavía más. ---
	m.stamina = 1.0
	m._move_boost = m.MOVE_BOOST_MAX
	m._update_human(0.5)
	_check(_near(m.stamina, 1.0 - Momentum.stamina_cost(0.5, true, m.MOVE_BOOST_MAX)),
		"el multi-toque no suma su gasto al del sprint")

	# --- Sin fondo físico se corta el sprint y no se sigue gastando. ---
	m.stamina = m.MOVE_BOOST_MIN_STAMINA * 0.5
	m._move_boost = m.MOVE_BOOST_MAX
	m._update_human(0.5)
	_check(not m.human.sprinting, "sin estamina el jugador sigue esprintando")
	_check(_near(m.human.move_boost, 0.0), "sin estamina el jugador sigue con boost")
	_check(_near(m.stamina, m.MOVE_BOOST_MIN_STAMINA * 0.5),
		"sin estamina se sigue gastando estamina")

	# --- Sin esprint no hay gasto. ---
	m._move_target = null
	m._move_boost = 0
	m.stamina = 1.0
	m._give_ball_now(m.star)
	m._update_human(0.5)
	_check(not m.human.sprinting, "sin orden de sprint el jugador esprinta solo")
	_check(_near(m.stamina, 1.0), "sin sprint se gasta estamina")

	scr.queue_free()
	await get_tree().process_frame
