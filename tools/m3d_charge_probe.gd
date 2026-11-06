extends Node
## Sonda de regresión P1-01 / P1-02 · remate cargado con potencia y efecto.
##   godot --headless --path . res://tools/M3DChargeProbe.tscn
##
## Valida que la potencia crezca con el tiempo que se mantiene el gesto y con
## el largo del deslizamiento, que la stamina ponga el techo de potencia y de
## efecto (curva), y que la barra del HUD muestre el valor y la marca del techo.
## Monta el partido 3D real para probar los helpers y el HUD de verdad.

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")

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

	_test_power_cap()
	_test_power_scaling()
	_test_curl_cap()
	_test_power_bar()
	_test_gesture_hold()

	scr.queue_free()
	await get_tree().process_frame

## La stamina define el techo: fresco = 100 %, agotado = SHOT_STAMINA_MIN_CAP.
func _test_power_cap() -> void:
	m.stamina = 1.0
	_check(_near(m._shot_power_cap(), 1.0), "stamina llena permite potencia máxima")
	m.stamina = 0.0
	_check(_near(m._shot_power_cap(), m.SHOT_STAMINA_MIN_CAP), "stamina vacía aplica el techo mínimo de potencia")
	m.stamina = 0.5
	var mid: float = m._shot_power_cap()
	_check(mid > m.SHOT_STAMINA_MIN_CAP and mid < 1.0, "la stamina intermedia deja un techo intermedio")
	_check(_near(mid, lerpf(m.SHOT_STAMINA_MIN_CAP, 1.0, 0.5)), "el techo interpola lineal con la stamina")

## Potencia = deslizamiento + tiempo mantenido, siempre bajo el techo.
func _test_power_scaling() -> void:
	m.stamina = 1.0
	var vp_h: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var short_swipe := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, vp_h * 0.1)])
	var full_swipe := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, vp_h * 0.5)])
	var p_short_hold: float = m._shot_power_preview(full_swipe, 0.0)
	var p_long_hold: float = m._shot_power_preview(full_swipe, m.CHARGE_FULL_SECONDS * 0.5)
	var p_short_flick: float = m._shot_power_preview(short_swipe, 0.0)
	var p_long_flick: float = m._shot_power_preview(full_swipe, 0.0)
	var p_both: float = m._shot_power_preview(full_swipe, m.CHARGE_FULL_SECONDS)
	_check(p_long_hold > p_short_hold, "mantener el gesto no aumenta la potencia")
	_check(p_long_flick > p_short_flick, "un deslizamiento más largo no aumenta la potencia")
	_check(p_both > p_long_hold and p_both > p_long_flick, "cargar y deslizar largo no suma más que cada uno solo")
	_check(_near(p_both, 1.0), "carga completa con gesto largo llega al 100 %")
	# El tiempo mantenido debe pesar exactamente CHARGE_HOLD_WEIGHT.
	_check(_near(p_long_hold - p_short_hold, m.CHARGE_HOLD_WEIGHT * 0.5),
		"el tiempo mantenido aporta el peso configurado")
	# Con stamina baja el mismo gesto queda recortado por el techo.
	m.stamina = 0.0
	var tired: float = m._shot_power_preview(full_swipe, m.CHARGE_FULL_SECONDS)
	_check(_near(tired, m.SHOT_STAMINA_MIN_CAP), "cansado, el gesto completo queda en el techo de stamina")
	m.stamina = 0.5
	var half: float = m._shot_power_preview(full_swipe, m.CHARGE_FULL_SECONDS)
	_check(half < 1.0 and half > m.SHOT_STAMINA_MIN_CAP, "a media stamina el gesto completo queda entre los dos techos")
	# Un gesto mínimo nunca baja del piso de potencia.
	m.stamina = 1.0
	var tiny := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 0.0)])
	_check(_near(m._shot_power_preview(tiny, 0.0), 0.2), "un gesto mínimo conserva el piso de potencia")

## El efecto también depende de la stamina (P1-02).
func _test_curl_cap() -> void:
	m.stamina = 1.0
	_check(_near(m._shot_curl_cap(), 1.0), "stamina llena permite el efecto completo")
	m.stamina = 0.0
	_check(_near(m._shot_curl_cap(), m.SHOT_STAMINA_MIN_CURL), "stamina vacía recorta el efecto al mínimo")
	m.stamina = 0.25
	var q1: float = m._shot_curl_cap()
	m.stamina = 0.75
	var q2: float = m._shot_curl_cap()
	_check(q2 > q1, "más stamina no da más efecto")
	_check(_near(q1, lerpf(m.SHOT_STAMINA_MIN_CURL, 1.0, 0.25)), "el efecto interpola lineal con la stamina")
	m.stamina = 1.0

## La barra del HUD muestra potencia, techo y se apaga sola.
func _test_power_bar() -> void:
	var hud: MatchHUD = m._hud
	_check(hud != null and hud.gesture is GestureInput, "el HUD del partido tiene el gesto conectado")
	if hud == null:
		return
	hud.show_power(0.8, 0.55)
	_check(hud._power_bg.visible, "show_power no muestra la barra")
	_check(_near(hud._power_fill.anchor_right, 0.8), "la barra no refleja la potencia")
	_check(_near(hud._power_cap.anchor_left, 0.55) and _near(hud._power_cap.anchor_right, 0.55),
		"la marca blanca no refleja el techo de stamina")
	_check(hud._power_label.text.contains("80"), "la etiqueta no muestra el porcentaje")
	_check(hud._power_fill.color.g > 0.5, "la barra al 80 % no está en color ámbar")
	hud.show_power(0.99, 1.0)
	_check(hud._power_fill.color.g < 0.5, "la barra casi llena no está en rojo")
	hud.hide_power()
	_check(hud._power_hiding, "hide_power no inicia el apagado diferido")
	hud._process(0.5)
	_check(not hud._power_bg.visible, "la barra no se apaga tras el tiempo de gracia")
	# Un show_power nuevo cancela un apagado pendiente.
	hud.show_power(0.4, 1.0)
	hud.hide_power()
	hud.show_power(0.5, 1.0)
	hud._process(0.5)
	_check(hud._power_bg.visible, "un gesto nuevo no cancela el apagado pendiente")
	hud.hide_power()
	hud._process(0.5)

## GestureInput expone el tiempo mantenido y los puntos en curso.
func _test_gesture_hold() -> void:
	var gi := GestureInput.new()
	add_child(gi)
	_check(not gi.is_holding(), "sin tocar, el gesto no está activo")
	_check(_near(gi.held_seconds(), 0.0), "sin tocar, no hay tiempo de carga")
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = Vector2(120.0, 200.0)
	gi._input(down)
	_check(gi.is_holding(), "con el dedo apoyado, el gesto está activo")
	_check(gi.held_seconds() >= 0.0, "el tiempo de carga no es válido")
	_check(gi.current_points().size() == 1, "el gesto no guarda el punto inicial")
	var move := InputEventScreenTouch.new()
	move.index = 0
	move.pressed = false
	move.position = Vector2(120.0, 320.0)
	gi._input(move)
	_check(not gi.is_holding(), "al soltar, el gesto deja de estar activo")
	gi.queue_free()
