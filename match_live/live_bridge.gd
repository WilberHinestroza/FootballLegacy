class_name LiveBridge
extends CanvasLayer
## Puente entre la pantalla de partido de FootballLegacy (scenes/Match) y la
## jugada EN VIVO (match_live/). Cuando el MatchEngine pide un momento clave:
##   var r = await bridge.play(situation)   ->   engine.resolve_decision(r)
## La cancha corre dentro de un SubViewport a pantalla completa, así no se
## mezcla con la interfaz del partido (relato, entretiempo, cambios...).
##
## Los 22 son los de verdad: la XI de cada MatchTeam en el puesto donde los
## puso el DT (deployed_code), con su cara (Avatar de FootballLegacy) y sus
## stats de PlayerData, que deciden velocidad, precisión, quites y atajadas.

var container: SubViewportContainer
var svp: SubViewport
var m: Match
var user_home := true
## Pruebas automáticas: las pausas se reanudan solas.
static var test_auto := false

static func enabled() -> bool:
	return true

func build(home_col: Color, away_col: Color) -> void:
	layer = 50
	# Fluidez: la física de la cancha al ritmo de la pantalla (hasta 120).
	# A 60 pasos en un celular de 120 Hz cada posición se veía dos cuadros
	# seguidos y el movimiento temblaba.
	_prev_ticks = Engine.physics_ticks_per_second
	var hz: float = DisplayServer.screen_get_refresh_rate()
	if hz > 0.0:
		Engine.physics_ticks_per_second = clampi(int(round(hz)), 60, 120)
	container = SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	svp = SubViewport.new()
	svp.size_2d_override = Vector2i(640, 360)
	svp.size_2d_override_stretch = true
	# Proporción REAL de la pantalla (los celulares son más alargados que
	# 16:9): alto fijo de 360 y el ancho que corresponda, nada se estira.
	container.resized.connect(_fit_aspect)
	svp.handle_input_locally = true
	container.add_child(svp)

	_home_col = home_col
	_away_col = away_col
	_make_match()
	container.visible = false
	svp.process_mode = Node.PROCESS_MODE_DISABLED

var _prev_ticks: int = 60

func _exit_tree() -> void:
	Engine.physics_ticks_per_second = _prev_ticks

var _home_col: Color
var _away_col: Color
var _sig: String = ""

## Firma de quiénes están en cancha: si cambia (un cambio, entrás vos desde
## el banco, una expulsión), la cancha en vivo se vuelve a armar.
func _xi_sig() -> String:
	var ids: Array = []
	for t in [MatchState.home_team, MatchState.away_team]:
		for p in (t as MatchTeam).starting_xi:
			ids.append(str(p.get_instance_id()))
	return ",".join(ids)

func _make_match() -> void:
	if m != null and is_instance_valid(m):
		svp.remove_child(m)
		m.queue_free()
	_sig = _xi_sig()
	var home: MatchTeam = MatchState.home_team
	var away: MatchTeam = MatchState.away_team
	var u: PlayerData = MatchState.user_player
	user_home = home.starting_xi.has(u) or home.bench.has(u)
	var ut: MatchTeam = home if user_home else away
	var ot: MatchTeam = away if user_home else home
	var ucol: Color = _home_col if user_home else _away_col
	var ocol: Color = _away_col if user_home else _home_col
	var seed_w: int = WorldTickEngine.world_seed
	var ur: Array = _roster(ut, ucol, Color("#27924f"), seed_w, u)
	var orr: Array = _roster(ot, ocol, Color("#e0b422"), seed_w, null)
	# Vos en cancha: te controla a vos. En el BANCO (o expulsado) no hay
	# jugador tuyo: antes quedaba el arquero (índice 0) con TU nombre.
	var uidx: int = -1
	for i in ur.size():
		if ur[i].get("data") == u:
			uidx = i
	var on_pitch: bool = uidx >= 0
	if not on_pitch:
		uidx = mini(9, ur.size() - 1)
	m = Match.new()
	svp.add_child(m)
	m.setup({
		"home_roster": ur, "away_roster": orr, "user_slot": uidx,
		"user_name": _short(u.player_name) if (on_pitch and u != null) else String(ur[uidx].get("name", "")),
		"home_kit": {"clothing": "#" + ucol.to_html(false)}, "away_kit": {"clothing": "#" + ocol.to_html(false)},
		"home_name": ut.team_name, "away_name": ot.team_name,
		"home_form": ut.formation, "away_form": ot.formation,
	})
	m.hud.home_abbr = _abbr(ut.team_name)
	m.hud.away_abbr = _abbr(ot.team_name)
	m.hud.home_col = ucol
	m.hud.away_col = ocol
	m.hud.channel = ScoreStyles.style_for_fixture(MatchState.fixture)
	if slot != null and _embedded:
		m.show_idle()
		m.hud.visible = false
		m.cam.zoom = Vector2.ONE * EMBED_ZOOM

## La XI de un MatchTeam como plantilla del partido en vivo (arquero primero).
func _roster(t: MatchTeam, col: Color, gk_col: Color, seed_w: int, user: PlayerData) -> Array:
	var xi: Array = t.starting_xi.duplicate()
	xi.sort_custom(func(a, b): return (t.deployed_code(a) == "POR" or a.position == "GK") and not (t.deployed_code(b) == "POR" or b.position == "GK"))
	var out: Array = []
	var shorts: String = "#f0f0f0" if col.get_luminance() < 0.5 else "#1e1e24"
	for i in xi.size():
		var p: PlayerData = xi[i]
		var gk: bool = i == 0
		var cfg: Dictionary = (Avatar.config_for_player(p, seed_w) if p == user else Avatar.config_for_npc(p.player_name, "player", seed_w)).duplicate(true)
		for k in ["outfit", "top", "bottom", "full", "region"]:
			cfg.erase(k)
		var c: Color = gk_col if gk else col
		cfg["tint_clothing"] = "#" + c.to_html(false)
		cfg["tint_socks"] = "#" + c.to_html(false)
		cfg["tint_shorts"] = "#2b2b2b" if gk else shorts
		out.append({
			"data": p, "code": "POR" if gk else t.deployed_code(p), "cfg": cfg,
			"name": _short(p.player_name), "number": 1 if gk else i + 1,
			"stats": {"speed": p.speed, "stamina": p.stamina, "strength": p.strength, "control": p.control,
				"passing": p.passing, "shooting": p.shooting, "dribbling": p.dribbling,
				"decision_making": p.decision_making, "composure": p.composure, "overall": p.overall},
		})
	return out

## Juega un momento clave y devuelve el resultado para resolve_decision().
func play(situation: Dictionary) -> Dictionary:
	if not test_auto and not Preferences.live_tutorial_seen:
		await _tutorial()
	if _xi_sig() != _sig:
		_make_match()
	_show()
	var opts: Array = situation.get("options", [])
	var k: String = String(opts[0].get("kind", "")) if not opts.is_empty() else String(situation.get("kind", "dribble"))
	var sit: Dictionary = situation.duplicate()
	if k in ["penalty_save", "penalty_save_shootout", "penalty_shootout"]:
		sit["kind"] = "penalty"
	else:
		sit["kind"] = k
	var minute: int = int(situation.get("minute", 0))
	for t in m.teams:
		for p in t.players:
			var sta: float = p.st("stamina")
			p.energy = clampf(1.0 - float(minute) / 90.0 * (0.55 - sta / 250.0), 0.35, 1.0)
	if MatchState.engine != null:
		var sc: Dictionary = MatchState.engine.get_live_score()
		var uh: int = int(sc.get("home", 0))
		var ua: int = int(sc.get("away", 0))
		m.hud.score_h = uh if user_home else ua
		m.hud.score_a = ua if user_home else uh
	m.hud.clock_text = "%d'" % minute
	if test_auto:
		m.auto_resume = 0.3
	m.start_moment(sit)
	var r: Dictionary = await m.moment_finished
	_hide()
	var kinds: Array = []
	for o in opts:
		kinds.append(String(o.get("kind", "")))
	var chosen: String = String(r.get("kind", k))
	if kinds.is_empty():
		chosen = String(situation.get("kind", k))
	elif not kinds.has(chosen):
		chosen = kinds[0]
	return {"kind": chosen, "precision": float(r.get("precision", 0.5)), "outcome": String(r.get("outcome", "")), "live": true}

## Entrada/salida con fundido corto (0,25 s): la cancha no aparece de golpe
## encima del relato.
var _fade: Tween = null

func _fit_aspect() -> void:
	var sz: Vector2 = container.size
	if sz.x < 8.0 or sz.y < 8.0:
		return
	svp.size_2d_override = Vector2i(int(round(360.0 * sz.x / sz.y)), 360)

# ---------------------------------------------------------------- incrustada
## HORIZONTAL: entre jugada y jugada la cancha EN VIVO (la misma de las
## jugadas, con el partido corriendo de fondo) se ve dentro de `slot`, en la
## pantalla del partido. Cuando llega tu jugada se agranda a pantalla
## completa y al terminar vuelve a su lugar.
## Cámara de la ventanita: más cerca que la vista general, sigue la pelota.
const EMBED_ZOOM := 1.0
var slot: Control = null
var _embedded := false

func embed(s: Control) -> void:
	slot = s
	container.modulate.a = 1.0
	svp.process_mode = Node.PROCESS_MODE_INHERIT
	m.idle_zoom = EMBED_ZOOM
	m.show_idle()
	m.hud.visible = false
	m.cam.zoom = Vector2.ONE * EMBED_ZOOM
	_dock()

## Dentro de la pantalla del partido (como un Control más): así las ventanas
## del partido (entretiempo, cambios, avisos) quedan POR ENCIMA.
func _dock() -> void:
	_embedded = true
	if container.get_parent() != slot:
		container.reparent(slot, false)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE   # incrustada no toma toques
	container.visible = true

## A la capa de arriba (pantalla completa) para tu jugada.
func _undock() -> void:
	var r := Rect2(container.global_position, container.size)
	if container.get_parent() != self:
		container.reparent(self, false)
	container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	container.position = r.position
	container.size = r.size
	container.mouse_filter = Control.MOUSE_FILTER_STOP

func _show() -> void:
	if _fade != null:
		_fade.kill()
	container.visible = true
	svp.process_mode = Node.PROCESS_MODE_INHERIT
	m.hud.visible = true
	if _embedded:
		# De la ventanita a pantalla completa, con un crecimiento suave.
		_embedded = false
		_undock()
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_fade = create_tween().set_parallel(true)
		_fade.tween_property(container, "position", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_fade.tween_property(container, "size", vp, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		return
	container.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(container, "modulate:a", 1.0, 0.25)

func _hide() -> void:
	if slot != null and is_instance_valid(slot):
		# Vuelve a la ventanita con el partido corriendo de fondo.
		if _fade != null:
			_fade.kill()
		m.show_idle()
		m.hud.visible = false
		m.cam.zoom = Vector2.ONE * EMBED_ZOOM
		_fade = create_tween().set_parallel(true)
		_fade.tween_property(container, "position", slot.global_position, 0.3).set_trans(Tween.TRANS_CUBIC)
		_fade.tween_property(container, "size", slot.size, 0.3).set_trans(Tween.TRANS_CUBIC)
		_fade.chain().tween_callback(_dock)
		return
	svp.process_mode = Node.PROCESS_MODE_DISABLED
	if _fade != null:
		_fade.kill()
	if not container.visible:
		return
	_fade = create_tween()
	_fade.tween_property(container, "modulate:a", 0.0, 0.25)
	_fade.tween_callback(func(): container.visible = false)

## El partido de fondo muestra lo que se narra: una escena corta (gol,
## ocasión, falta...) y la narración espera a que termine (máx. 6 s).
func stage(kind: String, ours: bool) -> void:
	if test_auto:
		print("LIVE escena %s (tuyo=%s) embebida=%s" % [kind, ours, _embedded])
	if m == null or not _embedded or svp.process_mode == Node.PROCESS_MODE_DISABLED or not container.visible:
		return
	m.idle_zoom = EMBED_ZOOM
	var done := [false]
	m.staged.connect(func() -> void: done[0] = true, CONNECT_ONE_SHOT)
	m.stage(kind, ours)
	var t0: int = Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 6000 and is_inside_tree():
		await get_tree().process_frame

## Señal chica de la narración (posesión, córner, saque del arquero...).
## side: 0 tu equipo, 1 rival, -1 sin lado.
func cue(kind: String, side: int) -> void:
	if m != null and _embedded:
		m.cue(kind, side)

static func _short(full: String) -> String:
	var parts: PackedStringArray = full.strip_edges().split(" ", false)
	if parts.size() <= 1:
		return full
	return "%s. %s" % [parts[0].substr(0, 1), parts[parts.size() - 1]]

static func _abbr(team_name: String) -> String:
	var clean: String = team_name.strip_edges().to_upper()
	var parts: PackedStringArray = clean.split(" ", false)
	if parts.size() >= 2 and parts[0].length() <= 3:
		return parts[1].substr(0, 3)
	return clean.substr(0, 3)


# ---------------------------------------------------------------- tutorial
## La primera vez: cómo se juega (solo gestos, como WSC). Una sola vez.
func _tutorial() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	var sb := Styles.card_flat(Color(0.07, 0.08, 0.1, 0.98), 18)
	sb.border_width_top = 5
	sb.border_color = Styles.GOLD
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(860, 0)
	dim.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := Label.new()
	t.text = "CÓMO SE JUEGA"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", Styles.font_black())
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Styles.GOLD)
	v.add_child(t)
	var sub := Label.new()
	sub.text = "Manejás solo a tu jugador. Todo es con el dedo: sin joystick ni botones."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(sub)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	v.add_child(g)
	var tips := [
		["👆", "Tocá el pasto", "Corrés hasta ahí (con la pelota, conducís). Si un rival te toca, te la puede robar."],
		["🤝", "Tocá a un compañero", "Pase. Si estás por la banda y él en el área, es un centro."],
		["⚽", "Deslizá hacia el arco", "Remate. Más largo y rápido = más fuerte (y más riesgo de que se vaya)."],
		["〰️", "Garabato rápido", "Hacé un zigzag con el dedo para regatear al rival que tenés enfrente."],
		["🛡️", "Defendiendo", "Deslizá hacia el rival: barrida. Tocalo: entrada. Tocá el pasto: cerrás espacio."],
		["⏸️", "Pausa en gris", "Cuando la jugada se congela, tomate tu tiempo: elegí qué hacer y el juego sigue."],
	]
	for tip in tips:
		var c := PanelContainer.new()
		var cs := Styles.card_flat(Color(0.12, 0.13, 0.16), 12)
		cs.content_margin_left = 12
		cs.content_margin_right = 12
		cs.content_margin_top = 10
		cs.content_margin_bottom = 10
		c.add_theme_stylebox_override("panel", cs)
		c.custom_minimum_size = Vector2(262, 112)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4)
		var head := Label.new()
		head.text = "%s  %s" % [tip[0], tip[1]]
		head.add_theme_font_override("font", Styles.font_semibold())
		head.add_theme_font_size_override("font_size", 16)
		cv.add_child(head)
		var d := Label.new()
		d.text = tip[2]
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 12)
		d.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88))
		cv.add_child(d)
		c.add_child(cv)
		g.add_child(c)
	var go := Button.new()
	go.text = "¡A jugar!"
	go.custom_minimum_size = Vector2(0, 52)
	go.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(go, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	v.add_child(go)
	await go.pressed
	Preferences.set_live_tutorial_seen(true)
	dim.queue_free()
