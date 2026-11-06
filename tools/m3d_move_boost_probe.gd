extends Node
## Sonda de regresión · multi-toque para correr a un punto.
##   godot --headless --path . res://tools/M3DMoveBoostProbe.tscn
##
## Valida que toques seguidos en la misma zona suban el boost, que el boost
## acelere al jugador, que gaste más estamina y que se corte al llegar o al
## quedarse sin energía.

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
	_test_multitap_levels()
	_test_boost_speed()
	await _test_match_boost()
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)

## Dos o tres toques seguidos en la misma zona suben de nivel; cambiar de zona
## o esperar demasiado vuelve a un toque normal. El nivel se corta en el máximo.
func _test_multitap_levels() -> void:
	var pos := Vector2(120.0, 240.0)
	_check(SoccerMatch.multitap_level(1000, pos, -10000, pos, 0) == 1, "un primer toque no empieza en nivel 1")
	_check(SoccerMatch.multitap_level(1100, pos, 1000, pos, 1) == 2, "el segundo toque seguido no sube a nivel 2")
	_check(SoccerMatch.multitap_level(1200, pos, 1100, pos, 2) == 3, "el tercer toque seguido no sube a nivel 3")
	_check(SoccerMatch.multitap_level(1300, pos, 1200, pos, 3) == 3, "el multi-toque no se corta en el máximo")
	_check(SoccerMatch.multitap_level(2000, pos, 1200, pos, 3) == 1, "esperar demasiado no reinicia el multi-toque")
	_check(SoccerMatch.multitap_level(1300, pos, 1200, pos + Vector2(200.0, 0.0), 2) == 1,
		"tocar otra zona no reinicia el multi-toque")

## El multiplicador de velocidad es 1,0 sin boost y crece hasta el máximo.
func _test_boost_speed() -> void:
	var p := SoccerPlayer.new()
	p.move_boost = 0.0
	_check(_near(p.move_boost_speed(), 1.0), "sin boost la velocidad no es la normal")
	p.move_boost = 0.5
	var mid: float = p.move_boost_speed()
	_check(mid > 1.0 and mid < SoccerPlayer.MOVE_BOOST_SPEED_MAX, "el boost intermedio no acelera de forma parcial")
	p.move_boost = 1.0
	_check(_near(p.move_boost_speed(), SoccerPlayer.MOVE_BOOST_SPEED_MAX), "el boost lleno no llega a la velocidad máxima")
	p.move_boost = 2.0
	_check(_near(p.move_boost_speed(), SoccerPlayer.MOVE_BOOST_SPEED_MAX), "el boost no se limita a la velocidad máxima")
	p.free()

## En el partido real: el boost se aplica al jugador y consume estamina.
func _test_match_boost() -> void:
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
	if m.human == null:
		m.human = m.star
	_check(m.human != null, "no hay jugador humano para probar el movimiento")
	if m.human == null:
		scr.queue_free()
		await get_tree().process_frame
		return
	m.state = m.State.MOMENT
	m.moment_type = m.Moment.ATTACK
	m.human.sprinting = false
	m.human.move_boost = 0.0
	m._move_target = m.human.global_position + Vector3(20.0, 0.0, 0.0)

	# Boost lleno: sprint, velocidad extra y estamina extra.
	m.stamina = 1.0
	m._move_boost = m.MOVE_BOOST_MAX
	m._update_human(0.5)
	_check(m.human.move_boost > 0.99, "el multi-toque no acelera al jugador")
	_check(m.human.sprinting, "el multi-toque no activa el sprint")
	_check(m.stamina < 1.0, "el multi-toque no consume estamina")
	_check(_near(m.stamina, 1.0 - Momentum.stamina_cost(0.5, true, m.MOVE_BOOST_MAX)),
		"el consumo de estamina del multi-toque no es el configurado")

	# Sin multi-toque: sprint normal, con el gasto base de P1-14.
	m.stamina = 1.0
	m._move_boost = 0
	m._update_human(0.5)
	_check(_near(m.human.move_boost, 0.0), "sin multi-toque el jugador recibe boost")
	_check(m.stamina < 1.0, "el sprint normal no consume estamina")
	_check(_near(m.stamina, 1.0 - Momentum.stamina_cost(0.5, true, 0)),
		"el consumo de estamina del sprint no es el configurado")

	# Sin estamina suficiente no hay boost (y no se sigue gastando).
	m.stamina = m.MOVE_BOOST_MIN_STAMINA * 0.5
	m._move_boost = m.MOVE_BOOST_MAX
	m._update_human(0.5)
	_check(_near(m.human.move_boost, 0.0), "sin estamina el jugador sigue recibiendo boost")
	_check(_near(m.stamina, m.MOVE_BOOST_MIN_STAMINA * 0.5), "sin estamina se sigue gastando estamina")

	# Al llegar al punto se limpia la orden y el boost.
	m.stamina = 1.0
	m._move_target = m.human.global_position
	m._move_boost = m.MOVE_BOOST_MAX
	m._update_human(0.1)
	_check(m._move_target == null, "al llegar al punto no se limpia la orden")
	_check(m._move_boost == 0, "al llegar al punto no se limpia el boost")
	_check(m.human.move_input == Vector3.ZERO, "al llegar al punto el jugador sigue empujando")

	scr.queue_free()
	await get_tree().process_frame
