class_name Hud
extends CanvasLayer
## Interfaz y gestos (sin joystick ni botones, como World Soccer Champs /
## Mini Soccer Star). Un solo dedo sobre la cancha:
##  - ARRASTRAR (mantener y mover): el jugador corre hacia el dedo.
##  - TOCAR: pase al compañero tocado (o al espacio). Sin balón: barrida
##    cerca del rival / cambiar al compañero tocado.
##  - DESLIZAR rápido: tiro en esa dirección. Trazo curvo = rosca,
##    deslizar más lento = vaselina. Se puede arrastrar y terminar con un
##    "latigazo" para tirar en carrera.
## Con mouse funciona igual (emular toque). Teclado de apoyo para PC:
## WASD/flechas mueven, Shift sprint.

signal tapped(screen_pos: Vector2)
signal swiped(dir: Vector2, power: float, curve: float, chip: bool)
signal scribbled                    # garabato rápido (zigzag) = regate
signal restart_requested

const TAP_MAX_PX := 16.0
const TAP_MAX_MS := 260
const FLICK_WINDOW_MS := 170      # se mira el final del trazo para detectar el tiro
const FLICK_MIN_PX := 34.0
const FLICK_MIN_SPEED := 0.75     # px por ms
const SWIPE_FULL_PX := 160.0
const CHIP_MS := 230              # latigazo más lento que esto = vaselina

var dragging := false             # hay un dedo arrastrando (para correr)
var drag_pos := Vector2.ZERO      # en pantalla
var keys := Vector2.ZERO          # teclado (PC)
var sprint := false

var score_text := ""
var clock_text := ""
var message := ""
var hint := "Arrastra: correr · Toca compañero: pase · Desliza: tiro"
var _msg_t := 0.0
var minimap_dots: Array = []
var paused := false               # jugada congelada esperando tu decisión
var decision_title := ""
var decision_hint := ""
var card_text := ""                 # ficha de tu jugador en la pausa
var card_stats := ""
var rival_text := ""                # ficha del rival que te encara
var rival_stats := ""
var replay := false                 # mostrando la repetición
var bug_art_only := false            # exportar el marco vacio (sin textos)
var _shapes := true
var _art: Dictionary = {}
const ART_RECT := {"bar": Rect2(6, 6, 168, 24), "center": Rect2(6, 4, 182, 42), "banner": Rect2(2, 4, 206, 40)}
# Marcador de TV (arriba a la izquierda) y logo de la televisora (derecha).
var channel := "golazo_tv"
var home_abbr := "TUE"
var away_abbr := "RIV"
var home_col := Color("#2e6fb0")
var away_col := Color("#c0392b")
var score_h := 0
var score_a := 0
var mode := "moment"               # "ticker" (simulando) o "moment" (jugando)
var ticker_lines: Array = []        # últimos eventos del relato
var ticker_title := ""

var _pad: Control
var _touch := -1
var _pts := PackedVector2Array()
var _times := PackedInt64Array()
var _t0 := 0
var _trail_fade := 0.0
var _last_trail := PackedVector2Array()
var _font: Font

func _ready() -> void:
	layer = 10
	_font = ThemeDB.fallback_font
	_pad = Control.new()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.draw.connect(_draw_pad)
	add_child(_pad)

func flash(text: String, secs: float = 1.6) -> void:
	message = text
	_msg_t = secs

func _process(dt: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= dt
		if _msg_t <= 0.0 and not message.begins_with("FIN"):
			message = ""
	keys = Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	if keys.length() > 0.0:
		keys = keys.normalized()
	sprint = Input.is_key_pressed(KEY_SHIFT)
	# Arrastre: cuenta como "correr" cuando el dedo se mantiene o se mueve lento.
	# Estilo WSC: no se conduce arrastrando (avanzar = tocar adonde ir).
	dragging = false
	_trail_fade = maxf(_trail_fade - dt * 3.0, 0.0)
	_pad.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if message.begins_with("FIN"):
				restart_requested.emit()
				return
			if _touch == -1:
				_touch = event.index
				_t0 = Time.get_ticks_msec()
				_pts = PackedVector2Array([event.position])
				_times = PackedInt64Array([_t0])
		elif event.index == _touch:
			_add_point(event.position)
			_touch = -1
			_resolve()
	elif event is InputEventScreenDrag and event.index == _touch:
		_add_point(event.position)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER and message.begins_with("FIN"):
		restart_requested.emit()

func _add_point(p: Vector2) -> void:
	if _pts.is_empty() or _pts[_pts.size() - 1].distance_to(p) > 1.5:
		_pts.append(p)
		_times.append(Time.get_ticks_msec())

func _resolve() -> void:
	var n: int = _pts.size()
	var now: int = Time.get_ticks_msec()
	var total_ms: int = now - _t0
	var a: Vector2 = _pts[0]
	var b: Vector2 = _pts[n - 1]
	_last_trail = _pts
	_trail_fade = 1.0
	# Toque: el dedo casi no se movió. Antes, si quedaba apoyado más de
	# 0,26 s el toque se descartaba y tu jugador "no respondía".
	if a.distance_to(b) < TAP_MAX_PX or (total_ms < TAP_MAX_MS and a.distance_to(b) < TAP_MAX_PX * 1.6):
		tapped.emit(b)
		return
	if _is_scribble(total_ms):
		scribbled.emit()
		return
	# Latigazo: el tramo final del trazo, rápido y largo.
	var i0: int = n - 1
	while i0 > 0 and now - _times[i0 - 1] <= FLICK_WINDOW_MS + 120:
		i0 -= 1
	# Si todo el gesto fue corto en tiempo, se usa entero.
	if total_ms < 450:
		i0 = 0
	var seg := PackedVector2Array()
	for i in range(i0, n):
		seg.append(_pts[i])
	if seg.size() < 2:
		return
	var chord: Vector2 = seg[seg.size() - 1] - seg[0]
	var l: float = chord.length()
	var ms: float = maxf(float(now - _times[i0]), 1.0)
	if l < FLICK_MIN_PX or l / ms < FLICK_MIN_SPEED * (0.6 if total_ms < 450 else 1.0):
		# Trazo lento: antes se ignoraba. Ahora es un pase/tiro suave en la
		# dirección de todo el gesto (si fue largo); si no, cuenta como toque.
		# Arrastre lento: NO es un pase (disparaba pases/tiros sin querer).
		# Cuenta como tocar donde terminó el dedo (ir hasta ahí).
		tapped.emit(b)
		return
	var dir: Vector2 = chord / l
	var dev: float = 0.0
	for q in seg:
		var v: float = dir.cross(q - seg[0])
		if absf(v) > absf(dev):
			dev = v
	var curve: float = clampf(dev / l * 3.0, -1.0, 1.0)
	var power: float = clampf(l / SWIPE_FULL_PX * 0.7 + (l / ms) * 0.18, 0.3, 1.0)
	swiped.emit(dir, power, curve, ms > CHIP_MS)

# ---------------------------------------------------------------- dibujo

func _size() -> Vector2:
	return _pad.get_viewport_rect().size

func _draw_pad() -> void:
	var s: Vector2 = _size()
	var c := _pad
	_draw_bug(s)
	# Dedo: punto hacia donde corre + trazo.
	if dragging:
		c.draw_arc(drag_pos, 14.0, 0, TAU, 24, Color(1, 1, 1, 0.5), 2.0)
		c.draw_circle(drag_pos, 4.0, Color(1, 1, 1, 0.6))
	if _touch != -1 and _pts.size() > 1:
		# Línea punteada amarilla mientras apuntas (como WSC).
		for i in range(0, _pts.size() - 1):
			if i % 2 == 0:
				c.draw_line(_pts[i], _pts[i + 1], Color(1, 0.9, 0.2, 0.9), 3.0)
		c.draw_circle(_pts[_pts.size() - 1], 4.0, Color(1, 0.9, 0.2, 0.9))
	elif _trail_fade > 0.0 and _last_trail.size() > 1:
		c.draw_polyline(_last_trail, Color(1, 0.95, 0.4, 0.6 * _trail_fade), 3.0)
	# Minimapa.
	var mm := Rect2(s.x - 58, 46, 50, 76)
	c.draw_rect(mm, Color(0.1, 0.3, 0.12, 0.75))
	c.draw_rect(mm, Color(1, 1, 1, 0.5), false, 1.0)
	c.draw_line(mm.position + Vector2(0, mm.size.y * 0.5), mm.position + Vector2(mm.size.x, mm.size.y * 0.5), Color(1, 1, 1, 0.3))
	for d in minimap_dots:
		var p: Vector2 = d[0]
		var mp: Vector2 = mm.position + Vector2(p.x / Cfg.FIELD_W * mm.size.x, p.y / Cfg.FIELD_H * mm.size.y)
		c.draw_circle(mp, d[2], d[1])
	if paused and mode == "moment":
		_draw_decision(s)
	if mode == "ticker":
		_draw_ticker(s)
	elif hint != "" and not paused:
		c.draw_rect(Rect2(0, s.y - 24, s.x, 24), Color(0, 0, 0, 0.35))
		_text(Vector2(s.x * 0.5, s.y - 8), hint, 9, Color(1, 1, 1, 0.9))
	if message != "":
		var lines: PackedStringArray = _wrap_message(message, s)
		var h: float = 34.0 + 22.0 * float(lines.size() - 1)
		var wide: bool = s.x > s.y
		var my: float = s.y * (0.38 if (mode == "ticker" or message.begins_with("FIN")) else 0.13)
		# En horizontal, el título de la jugada va a la IZQUIERDA bajo el
		# marcador: arriba al centro tapaba el arco.
		var left_pill: bool = wide and mode == "moment" and not message.begins_with("FIN")
		if left_pill:
			my = 72.0
		# Cápsula centrada (no una franja de lado a lado) que se desvanece al
		# final: tapa menos cancha y no corta de golpe.
		var fin: bool = message.begins_with("FIN")
		var a: float = 1.0 if fin else clampf(_msg_t / 0.35, 0.0, 1.0)
		var maxw: float = 0.0
		for i in lines.size():
			var fs: int = (16 if wide else 22) if i == 0 else (11 if wide else 13)
			maxw = maxf(maxw, _font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var bw: float = minf(s.x - 16.0, maxw + 48.0)
		var cx: float = (8.0 + bw * 0.5) if left_pill else s.x * 0.5
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.05, 0.08, 0.72 * a)
		sb.set_corner_radius_all(10)
		sb.border_width_bottom = 2
		sb.border_color = Color(1, 0.85, 0.3, 0.8 * a)
		c.draw_style_box(sb, Rect2(cx - bw * 0.5, my - 26, bw, h))
		for i in lines.size():
			var col: Color = Color(1, 0.95, 0.4) if i == 0 else Color.WHITE
			col.a = a
			_text(Vector2(cx, my + i * 22.0), lines[i], (16 if wide else 22) if i == 0 else (11 if wide else 13), col)

func _text(center: Vector2, t: String, size: int, col: Color) -> void:
	var w: float = _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_pad.draw_string(_font, center - Vector2(w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.6 * col.a))
	_pad.draw_string(_font, center - Vector2(w * 0.5 + 1, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## Relato del partido mientras se simula (entre momentos).
func _draw_ticker(s: Vector2) -> void:
	var c := _pad
	var bw: float = minf(s.x - 24, 400.0)
	var bh2: float = 104.0 if s.x > s.y else 120.0
	var box := Rect2((s.x - bw) * 0.5, s.y - bh2 - 8.0, bw, bh2)
	c.draw_rect(box, Color(0.02, 0.06, 0.03, 0.82))
	c.draw_rect(box, Color(1, 1, 1, 0.25), false, 1.0)
	_text(Vector2(s.x * 0.5, box.position.y + 20), ticker_title, 13, Color(1, 0.95, 0.4))
	var y: float = box.position.y + 44
	var n: int = ticker_lines.size()
	for i in range(maxi(0, n - 4), n):
		var line: String = String(ticker_lines[i])
		var col := Color(1, 1, 1, 0.55 + 0.45 * float(i - maxi(0, n - 4)) / 4.0)
		c.draw_string(_font, Vector2(box.position.x + 10, y), line, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 20, 11, col)
		y += 17

## Aviso de "jugada pausada": bordes oscuros, título que late y los gestos.
func _draw_decision(s: Vector2) -> void:
	var c := _pad
	var pulse: float = 0.6 + 0.4 * sin(float(Time.get_ticks_msec()) / 170.0)
	var edge := Color(0, 0, 0, 0.35)
	c.draw_rect(Rect2(0, 0, 10, s.y), edge)
	c.draw_rect(Rect2(s.x - 10, 0, 10, s.y), edge)
	var wide: bool = s.x > s.y
	var bh: float = 50.0 if wide else 70.0
	c.draw_rect(Rect2(0, s.y - bh, s.x, bh), Color(0, 0, 0, 0.5))
	var px: float = s.x * 0.5
	var py: float = s.y - (32.0 if wide else 50.0)
	var w: float = _font.get_string_size(decision_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var bx: float = px - w * 0.5 - 18
	c.draw_rect(Rect2(bx, py - 14, 4, 15), Color(1, 0.92, 0.2, pulse))
	c.draw_rect(Rect2(bx + 7, py - 14, 4, 15), Color(1, 0.92, 0.2, pulse))
	_text(Vector2(px, py), decision_title, 18, Color(1, 0.95, 0.4, 0.75 + 0.25 * pulse))
	# Ficha de tu jugador (abajo a la izquierda, como WSC).
	if card_text != "":
		var cy: float = s.y - bh - 40.0
		_card(Vector2(8, cy), card_text, card_stats, Color(1, 0.92, 0.2))
	if rival_text != "":
		_card(Vector2(s.x - 186, s.y - bh - 40.0), rival_text, rival_stats, Color(1, 0.35, 0.3))
	_text(Vector2(px, s.y - (10.0 if wide else 24.0)), decision_hint, 9, Color(1, 1, 1, 0.95))

## Garabato: trazo rápido que cambia de sentido al menos 2 veces (zigzag).
func _is_scribble(total_ms: int) -> bool:
	if total_ms > 900 or _pts.size() < 4:
		return false
	var dirs: Array = []
	var last: Vector2 = _pts[0]
	var length: float = 0.0
	for i in range(1, _pts.size()):
		var seg: Vector2 = _pts[i] - last
		if seg.length() >= 8.0:
			dirs.append(seg.normalized())
			length += seg.length()
			last = _pts[i]
	var turns: int = 0
	for i in range(1, dirs.size()):
		if (dirs[i] as Vector2).dot(dirs[i - 1]) < -0.2:
			turns += 1
	return turns >= 2 and length > 60.0

# ---------------------------------------------------------------- TV

const CHANNELS := ScoreStyles.CHANNELS
var _logo_cache: Dictionary = {}

func _sb(col: Color, r: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(mini(r, 10))
	return sb

## Marcador estilo TV, arriba a la izquierda, con la gráfica del canal o
## del torneo (ver ScoreStyles).
func _draw_bug(s: Vector2) -> void:
	var st: Dictionary = ScoreStyles.get_style(channel)
	var lay: String = String(st.get("layout", "bar"))
	var art: Texture2D = _bug_art(channel)
	if art != null and not bug_art_only:
		_pad.draw_texture_rect(art, ART_RECT[lay], false)
		_shapes = false
	match lay:
		"center":
			_bug_center(st)
		"banner":
			_bug_banner(st)
		_:
			_bug_bar(st)
	_shapes = true
	if bug_art_only:
		return
	# Logo de la televisora, arriba a la derecha (como en la tele real).
	var ch: String = String(st.get("channel", channel))
	var cst: Dictionary = ScoreStyles.get_style(ch)
	var logo: Texture2D = _logo(ch)
	var lx: float = s.x - 64.0 - _w(String(cst["name"]), 8)
	if logo != null:
		_pad.draw_texture_rect(logo, Rect2(lx, 6, 22, 22), false, Color(1, 1, 1, 0.9))
	_tx(Vector2(lx + 25, 15), String(cst["name"]), 8, Color(1, 1, 1, 0.9))
	_pad.draw_circle(Vector2(lx + 28, 23), 2.0, Color(1, 0.2, 0.2, 0.6 + 0.4 * sin(float(Time.get_ticks_msec()) / 300.0)))
	_tx(Vector2(lx + 32, 26), "EN VIVO", 7, Color(1, 1, 1, 0.8))
	if replay:
		_tx(Vector2(10, 62), "R", 26, Color(1, 1, 1, 0.9))
		_text(Vector2(s.x * 0.5, s.y - 10), "Repetición · toca para saltar", 9, Color(1, 1, 1, 0.9))

func _ct() -> String:
	return clock_text if clock_text != "" else "0'"

## Barra compacta (GOLAZO TV, ESTADIO 24, TRIBUNA).
func _bug_bar(st: Dictionary) -> void:
	var bg := Color(String(st["bg"]))
	var ac := Color(String(st["accent"]))
	var pl := Color(String(st["plate"]))
	var ink := Color(String(st["ink"]))
	var r: int = int(st["radius"])
	var c := _pad
	var x0: float = 8.0
	var y0: float = 8.0
	var h: float = 20.0
	var total: float = 40.0 * 2.0 + 40.0 + 34.0 + 6.0
	if _shapes: c.draw_style_box(_sb(bg, r), Rect2(x0, y0, total, h))
	match String(st["edge"]):
		"top":
			if _shapes: c.draw_rect(Rect2(x0 + 4, y0, total - 8, 2), ac)
		"bottom":
			if _shapes: c.draw_rect(Rect2(x0 + 4, y0 + h - 2, total - 8, 2), ac)
		"left":
			if _shapes: c.draw_rect(Rect2(x0, y0, 3, h), ac)
	var x: float = x0 + 4.0
	if _shapes: c.draw_rect(Rect2(x, y0 + 4, 3, h - 8), home_col)
	_tx(Vector2(x + 6, y0 + 14), home_abbr, 11, Color.WHITE)
	x += 40.0
	if _shapes: c.draw_style_box(_sb(pl, maxi(r - 2, 0)), Rect2(x, y0 + 2, 40, h - 4))
	var sc: String = "%d-%d" % [score_h, score_a]
	_tx(Vector2(x + (40 - _w(sc, 12)) * 0.5, y0 + 14), sc, 12, ink)
	x += 44.0
	_tx(Vector2(x + 2, y0 + 14), away_abbr, 11, Color.WHITE)
	if _shapes: c.draw_rect(Rect2(x + 32, y0 + 4, 3, h - 8), away_col)
	x += 40.0
	if _shapes: c.draw_style_box(_sb(ac, maxi(r - 2, 0)), Rect2(x, y0 + 2, 32, h - 4))
	_tx(Vector2(x + (32 - _w(_ct(), 11)) * 0.5, y0 + 14), _ct(), 11, Color.WHITE)

## Emblema entre los goles y reloj debajo (estilo Premier; torneos).
func _bug_center(st: Dictionary) -> void:
	var bg := Color(String(st["bg"]))
	var ac := Color(String(st["accent"]))
	var pl := Color(String(st["plate"]))
	var ink := Color(String(st["ink"]))
	var txt := Color(String(st.get("text", "#ffffff")))
	var r: int = int(st["radius"])
	var c := _pad
	var x0: float = 8.0
	var y0: float = 6.0
	var h: float = 24.0
	var tw: float = 50.0
	var sw: float = 24.0
	var ew: float = 30.0
	var total: float = tw * 2.0 + sw * 2.0 + ew
	if _shapes: c.draw_style_box(_sb(bg, r), Rect2(x0, y0, total, h))
	if _shapes: c.draw_rect(Rect2(x0, y0 + 3, 4, h - 6), home_col)
	if _shapes: c.draw_rect(Rect2(x0 + total - 4, y0 + 3, 4, h - 6), away_col)
	_tx(Vector2(x0 + (tw - _w(home_abbr, 13)) * 0.5 + 2, y0 + 17), home_abbr, 13, txt)
	_tx(Vector2(x0 + tw + sw * 2.0 + ew + (tw - _w(away_abbr, 13)) * 0.5 - 2, y0 + 17), away_abbr, 13, txt)
	var sx: float = x0 + tw
	if _shapes: c.draw_rect(Rect2(sx, y0, sw, h), pl)
	if _shapes: c.draw_rect(Rect2(sx + sw + ew, y0, sw, h), pl)
	_tx(Vector2(sx + (sw - _w(str(score_h), 16)) * 0.5, y0 + 19), str(score_h), 16, ink)
	_tx(Vector2(sx + sw + ew + (sw - _w(str(score_a), 16)) * 0.5, y0 + 19), str(score_a), 16, ink)
	var ec := Vector2(sx + sw + ew * 0.5, y0 + h * 0.5)
	if _shapes: c.draw_circle(ec, 16.0, bg)
	if _shapes: c.draw_arc(ec, 16.0, 0.0, TAU, 32, ac, 2.0)
	_emblem(String(st.get("emblem", "ball")), ec, 11.0, ac, bg)
	var cw: float = 48.0
	if _shapes: c.draw_style_box(_sb(bg, 6), Rect2(ec.x - cw * 0.5, y0 + h + 1, cw, 15))
	_tx(Vector2(ec.x - _w(_ct(), 11) * 0.5, y0 + h + 13), _ct(), 11, ac)
	if st.has("channel"):
		_tx(Vector2(x0 + 2, y0 + h + 26), String(st["name"]), 7, Color(1, 1, 1, 0.8))

## Franja con bloques en flecha y reloj arriba (estilo LaLiga).
func _bug_banner(st: Dictionary) -> void:
	var bg := Color(String(st["bg"]))
	var ac := Color(String(st["accent"]))
	var c := _pad
	var x0: float = 14.0
	var y0: float = 20.0
	var h: float = 22.0
	var bw: float = 58.0
	var mid: float = 70.0
	var total: float = bw * 2.0 + mid
	if _shapes: c.draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + total, y0), Vector2(x0 + total + 6, y0 + h * 0.5), Vector2(x0 + total, y0 + h), Vector2(x0, y0 + h), Vector2(x0 - 6, y0 + h * 0.5)]), bg)
	if _shapes: c.draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + bw, y0), Vector2(x0 + bw + 8, y0 + h * 0.5), Vector2(x0 + bw, y0 + h), Vector2(x0, y0 + h)]), ac)
	if _shapes: c.draw_colored_polygon(PackedVector2Array([Vector2(x0 + total, y0), Vector2(x0 + total - bw, y0), Vector2(x0 + total - bw - 8, y0 + h * 0.5), Vector2(x0 + total - bw, y0 + h), Vector2(x0 + total, y0 + h)]), ac)
	if _shapes: c.draw_rect(Rect2(x0, y0 + h - 3, bw, 3), home_col)
	if _shapes: c.draw_rect(Rect2(x0 + total - bw, y0 + h - 3, bw, 3), away_col)
	_tx(Vector2(x0 + (bw - _w(home_abbr, 12)) * 0.5, y0 + 15), home_abbr, 12, Color.WHITE)
	_tx(Vector2(x0 + total - bw + (bw - _w(away_abbr, 12)) * 0.5, y0 + 15), away_abbr, 12, Color.WHITE)
	var cx: float = x0 + bw + mid * 0.5
	_tx(Vector2(cx - 24 - _w(str(score_h), 15) * 0.5, y0 + 17), str(score_h), 15, Color.WHITE)
	_tx(Vector2(cx + 24 - _w(str(score_a), 15) * 0.5, y0 + 17), str(score_a), 15, Color.WHITE)
	if _shapes: c.draw_circle(Vector2(cx, y0 + h * 0.5), 10.0, Color(1, 1, 1, 0.12))
	_emblem(String(st.get("emblem", "ball")), Vector2(cx, y0 + h * 0.5), 8.0, Color.WHITE, bg)
	var cw: float = 48.0
	if _shapes: c.draw_rect(Rect2(cx - cw * 0.5, y0 - 14, cw, 14), Color.WHITE)
	else:
		# Con el arte de PixelLab la pestaña del reloj trae un adorno dibujado:
		# se tapa para que el minuto se lea limpio.
		c.draw_rect(Rect2(cx - 19, y0 - 13, 38, 11), Color(0.9, 0.91, 0.94))
	_tx(Vector2(cx - _w(_ct(), 11) * 0.5, y0 - 3), _ct(), 11, Color(String(st["ink"])))

## Emblemas propios (sin logos reales).
func _emblem(kind: String, c: Vector2, r: float, fg: Color, bg: Color) -> void:
	var p := _pad
	match kind:
		"cup":
			if _shapes: p.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.8), c + Vector2(r * 0.7, -r * 0.8), c + Vector2(r * 0.35, r * 0.1), c + Vector2(-r * 0.35, r * 0.1)]), fg)
			if _shapes: p.draw_arc(c + Vector2(-r * 0.7, -r * 0.4), r * 0.3, PI * 0.5, PI * 1.5, 8, fg, 2.0)
			if _shapes: p.draw_arc(c + Vector2(r * 0.7, -r * 0.4), r * 0.3, -PI * 0.5, PI * 0.5, 8, fg, 2.0)
			if _shapes: p.draw_rect(Rect2(c + Vector2(-r * 0.12, r * 0.1), Vector2(r * 0.24, r * 0.45)), fg)
			if _shapes: p.draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.55), Vector2(r, r * 0.3)), fg)
		"stars":
			if _shapes: p.draw_circle(c, r * 0.45, fg)
			for i in 8:
				var a: float = TAU * float(i) / 8.0 - PI * 0.5
				_star(c + Vector2(cos(a), sin(a)) * r * 0.85, r * 0.22, fg)
		"globe":
			if _shapes: p.draw_arc(c, r, 0.0, TAU, 24, fg, 1.5)
			if _shapes: p.draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), fg, 1.0)
			if _shapes: p.draw_line(c + Vector2(0, -r), c + Vector2(0, r), fg, 1.0)
			if _shapes: p.draw_arc(c, r * 0.5, -PI * 0.5, PI * 0.5, 12, fg, 1.0)
			if _shapes: p.draw_arc(c, r * 0.5, PI * 0.5, PI * 1.5, 12, fg, 1.0)
		"shield":
			if _shapes: p.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.8), c + Vector2(r * 0.8, -r * 0.8), c + Vector2(r * 0.8, r * 0.1), c + Vector2(0, r), c + Vector2(-r * 0.8, r * 0.1)]), fg)
			_star(c + Vector2(0, -r * 0.1), r * 0.45, bg)
		"crown":
			if _shapes: p.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, r * 0.5), c + Vector2(-r * 0.8, -r * 0.5), c + Vector2(-r * 0.4, 0), c + Vector2(0, -r * 0.8), c + Vector2(r * 0.4, 0), c + Vector2(r * 0.8, -r * 0.5), c + Vector2(r * 0.8, r * 0.5)]), fg)
		_:
			if _shapes: p.draw_circle(c, r, fg)
			var pts := PackedVector2Array()
			for i in 5:
				var a2: float = TAU * float(i) / 5.0 - PI * 0.5
				pts.append(c + Vector2(cos(a2), sin(a2)) * r * 0.42)
			if _shapes: p.draw_colored_polygon(pts, bg)

func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a: float = TAU * float(i) / 10.0 - PI * 0.5
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	if _shapes: _pad.draw_colored_polygon(pts, col)

func _logo(id: String) -> Texture2D:
	if not _logo_cache.has(id):
		var p: String = "res://assets/media/%s.png" % id
		_logo_cache[id] = load(p) if ResourceLoader.exists(p) else null
	return _logo_cache[id]

func _w(t: String, size: int) -> float:
	return _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func _tx(p: Vector2, t: String, size: int, col: Color) -> void:
	if bug_art_only:
		return
	_pad.draw_string(_font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## Ficha de jugador (como WSC): nombre y número arriba, estadísticas abajo.
func _card(p: Vector2, title: String, stats: String, accent: Color) -> void:
	var c := _pad
	if _shapes: c.draw_rect(Rect2(p, Vector2(178, 34)), Color(0, 0, 0, 0.6))
	if _shapes: c.draw_rect(Rect2(p, Vector2(3, 34)), accent)
	_tx(p + Vector2(8, 13), title, 10, Color.WHITE)
	_tx(p + Vector2(8, 27), stats, 8, Color(0.85, 0.9, 1.0))

## Arte del marcador hecho con PixelLab (assets/scoreboards/<estilo>.png).
func _bug_art(id: String) -> Texture2D:
	var k: String = "art_" + id
	if not _art.has(k):
		var p: String = "res://assets/scoreboards/%s.png" % id
		_art[k] = load(p) if ResourceLoader.exists(p) else null
	return _art[k]

## Corta el texto del cartel en renglones que entren (el relato largo se
## salía de la pantalla). Máximo 4 renglones.
func _wrap_message(msg: String, s: Vector2) -> PackedStringArray:
	var out := PackedStringArray()
	var wide: bool = s.x > s.y
	var maxw: float = (s.x * 0.46) if (wide and mode == "moment" and not msg.begins_with("FIN")) else (s.x - 48.0)
	var raw: PackedStringArray = msg.split("\n")
	for i in raw.size():
		var fs: int = (16 if wide else 22) if out.is_empty() else (11 if wide else 13)
		var line := ""
		for w in raw[i].split(" ", false):
			var t: String = w if line == "" else line + " " + w
			if _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw and line != "":
				out.append(line)
				line = w
			else:
				line = t
		out.append(line)
		if out.size() >= 4:
			break
	return out
