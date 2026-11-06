extends RefCounted
const Sim = preload("res://prototypes/match_v2/ProtoSim.gd")
## Prototipo match_v2 — el ESTADIO del juego (17-oct, Wilber: "recuerda la
## cámara, cancha y todo eso que teníamos"). Misma idea y mismo arte que
## PitchView (césped con corte por estadio, tribunas con público, vallas,
## bancos, camarógrafos, fotógrafos, alcanzapelotas, torres de luz,
## marcador, arcos con red que se hunde), pero en METROS reales (68 × 105)
## y con la proyección de ProtoMatch (cámara que sigue la jugada, cancha
## apenas inclinada). Solo dibuja: no sabe nada del partido salvo lo que
## le pasa la escena (marcador, gol para la red, euforia de la tribuna).
##
## `v` = la escena (ProtoMatch): w2s(), s (px por metro), TILT, px (escala
## de los sprites) y los draw_* (se llama dentro de su _draw).

const GRASS_PATTERNS := ["stripes", "vertical", "checker", "diagonal", "circles", "wide"]
const GRASS_TONES := [
	[Color(0.16, 0.42, 0.20), Color(0.18, 0.46, 0.22)],
	[Color(0.13, 0.40, 0.17), Color(0.17, 0.47, 0.21)],
	[Color(0.20, 0.42, 0.18), Color(0.23, 0.46, 0.20)],
	[Color(0.12, 0.36, 0.22), Color(0.15, 0.40, 0.25)],
]
const LINE := Color(1, 1, 1, 0.78)
const STAND := Color(0.10, 0.11, 0.14)
## Bordes (metros): pasto hasta acá, después las tribunas.
const GX0 := -6.0
const GX1 := 74.0
const GY0 := -7.0
const GY1 := 112.0
const BANNER_TEXTS := ["VAMOS EQUIPO", "SIEMPRE CONTIGO", "LA 12", "AGUANTE", "LOCALES", "ESTA ES TU CASA", "HASTA EL FINAL", "CORAZÓN Y GARRA", "LA BANDA", "FIELES"]

var v
var pattern: String = "stripes"
var grass_a: Color
var grass_b: Color
var stand_kind: int = 0
var night: bool = false
var cols: Array = []
var banner_seed: int = 1
var hype: float = 0.0
var score_text: String = ""
var net_t: float = -9.0
var net_x: float = 34.0
var net_end: int = 0
var live_t: float = 0.0
var _crowd: Array = []
var away_col: Color
## Suplentes y DT (sprites del juego, teñidos): [equipo] → [cfg...]
var _bench_cfg: Array = [[], []]
var _coach_cfg: Array = []
## Gesto de cada DT: [animación, desde cuándo] ("" = camina por su área).
var coach_act: Array = [["", -9.0], ["", -9.0]]
var _coach_next: float = 6.0
var _specks: Array = []
var _wear: Array = []
static var _tex: Dictionary = {}
static var _anim: Dictionary = {}
static var _glow_tex: GradientTexture2D = null
static var _logos: Array = []

func _init(view, seed_i: int, home: Color, away: Color) -> void:
	v = view
	var h: int = absi(hash("grass:proto:%d" % seed_i))
	pattern = GRASS_PATTERNS[h % GRASS_PATTERNS.size()]
	var tone: Array = GRASS_TONES[(h / 7) % GRASS_TONES.size()]
	grass_a = tone[0]
	grass_b = tone[1]
	stand_kind = (h / 13) % 3
	banner_seed = maxi(1, h % 100000)
	night = (h / 31) % 10 < 3
	cols = [home, Color(0.92, 0.92, 0.95)]
	away_col = away
	var skins := ["#f4d6c0", "#d9a577", "#8a5a3b", "#eec1a3", "#5f3a26"]
	for team in range(2):
		var kit: Color = home if team == 0 else away
		for k in range(5):
			var look: Dictionary = Avatar.random_config(seed_i + team * 101 + k * 17)
			_bench_cfg[team].append({"tint_clothing": kit.lightened(0.1).to_html(false), "tint_shorts": "#1f2026",
				"tint_base": skins[(k + team) % skins.size()], "tint_hair": String(look.get("tint_hair", "#2b2320")),
				"tint_boots": "#2b2b30"})
		_coach_cfg.append({"tint_clothing": "#23252c", "tint_shorts": "#23252c", "tint_base": skins[(team * 2 + 1) % skins.size()],
			"tint_hair": "#9a9aa0", "tint_boots": "#111111"})
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	for i in range(160):
		_crowd.append((cols[rng.randi() % 2] as Color).lerp(Color(0.6, 0.5, 0.45), rng.randf_range(0.0, 0.5)))
	for i in range(700):
		_specks.append(Vector2(rng.randf_range(-4.0, 72.0), rng.randf_range(-5.0, 110.0)))
	for i in range(90):
		var top: bool = i % 2 == 0
		var q := Vector2(34.0 + rng.randf_range(-11.0, 11.0), rng.randf_range(0.0, 12.0))
		_wear.append([q if top else Vector2(q.x, 105.0 - q.y), rng.randf_range(0.5, 1.2)])

func tick(dt: float) -> void:
	live_t += dt
	# Cada tanto un DT grita indicaciones.
	if live_t >= _coach_next:
		var tm: int = int(live_t * 7.0) % 2
		if String(coach_act[tm][0]) == "" or live_t - float(coach_act[tm][1]) > 3.0:
			coach_act[tm] = ["coach_grita", live_t]
		_coach_next = live_t + 5.0 + fmod(live_t * 3.7, 5.0)
	hype = maxf(0.0, hype - dt)

## Gol: festeja el DT del que lo hizo, se agarra la cabeza el otro.
func coach_react(scoring_team: int) -> void:
	coach_act[scoring_team] = ["coach_festeja", live_t]
	coach_act[1 - scoring_team] = ["coach_lamenta", live_t]

func goal_net(x: float, top_end: bool) -> void:
	net_t = live_t
	net_x = x
	net_end = 0 if top_end else 1
	hype = 4.0

# ------------------------------------------------------------------ texturas
static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var p: String = "res://assets/stadium/%s.png" % name
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]

static func frames(name: String) -> Array:
	if not _anim.has(name):
		var fr: Array = []
		var i: int = 0
		while ResourceLoader.exists("res://assets/stadium/%s_a%d.png" % [name, i]):
			fr.append(load("res://assets/stadium/%s_a%d.png" % [name, i]))
			i += 1
		_anim[name] = fr
	return _anim[name]

func _now(name: String, fps: float, salt: float) -> Texture2D:
	var fr: Array = frames(name)
	if fr.is_empty() or fps <= 0.0:
		return tex(name)
	return fr[int(live_t * fps + salt) % fr.size()]

static func _glow() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.96, 0.80, 0.22))
		g.set_color(1, Color(1.0, 0.97, 0.86, 0.0))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 128
		_glow_tex.height = 128
	return _glow_tex

static func _board_logos() -> Array:
	if _logos.is_empty():
		var paths: Array = []
		for n in SponsorEngine.SPONSOR_NAMES:
			paths.append("res://assets/sponsors/%s.png" % BrandMark.slug(String(n)))
		for b in BootBrands.BRANDS:
			paths.append("res://assets/brands/%s.png" % String(b.get("logo", "")))
		for pth in paths:
			if ResourceLoader.exists(pth):
				_logos.append(load(pth))
	return _logos

# ------------------------------------------------------------------ helpers
func _quad(x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	var a: Vector2 = v.w2s(Vector2(x0, y0))
	var b: Vector2 = v.w2s(Vector2(x1, y1))
	var r := Rect2(a, b - a).abs()
	if r.intersects(Rect2(Vector2(-50, -50), v.get_viewport_rect().size + Vector2(100, 100))):
		v.draw_rect(r, col)

func _poly(pts_w: Array, col: Color) -> void:
	var pts := PackedVector2Array()
	for q in pts_w:
		pts.append(v.w2s(q))
	v.draw_colored_polygon(pts, col)

func _line(a: Vector2, b: Vector2, w: float, col: Color = LINE) -> void:
	v.draw_line(v.w2s(a), v.w2s(b), col, w)

func _ring(c: Vector2, r: float, a0: float, a1: float, w: float, min_dy: float = -999.0, sgn: float = 1.0) -> void:
	var pts := PackedVector2Array()
	for i in range(41):
		var a: float = lerpf(a0, a1, float(i) / 40.0)
		var q := c + Vector2(cos(a), sin(a)) * r
		if (q.y - c.y) * sgn >= min_dy:
			pts.append(v.w2s(q))
	if pts.size() >= 2:
		v.draw_polyline(pts, LINE, w)

func _visible(q: Vector2, margin: float = 120.0) -> bool:
	var vs: Vector2 = v.get_viewport_rect().size
	return q.x > -margin and q.x < vs.x + margin and q.y > -margin and q.y < vs.y + margin * 2.0

# ------------------------------------------------------------------- suelo
## Todo lo que va pegado al piso: tribunas de fondo, césped, desgaste,
## líneas, sombras de nubes, vallas laterales.
func draw_ground() -> void:
	var vs: Vector2 = v.get_viewport_rect().size
	v.draw_rect(Rect2(Vector2.ZERO, vs), STAND)
	_draw_side_stands()
	_draw_grass()
	for w in _wear:
		var c: Vector2 = v.w2s(w[0])
		if _visible(c, 30.0):
			v.draw_set_transform(c, 0.0, Vector2(1.0, v.TILT * 0.6))
			v.draw_circle(Vector2.ZERO, float(w[1]) * v.s, Color(0.35, 0.32, 0.18, 0.16))
			v.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in range(_specks.size()):
		var p: Vector2 = v.w2s(_specks[i])
		if _visible(p, 4.0):
			v.draw_rect(Rect2(p, Vector2(2, 1)), Color(1, 1, 1, 0.05) if i % 2 == 0 else Color(0, 0, 0, 0.06))
	_draw_lines()
	_draw_clouds()
	_draw_side_boards()
	_draw_end_stand(true)
	_draw_end_stand(false)
	# La valla del fondo de arriba va DETRÁS del arco (antes se dibujaba
	# encima y cortaba la red por la mitad); la de abajo sigue en el orden
	# por profundidad.
	_draw_end_board(0)

func _draw_grass() -> void:
	match pattern:
		"vertical":
			var w: float = 68.0 / 9.0
			for i in range(-1, 11):
				_quad(i * w, GY0, (i + 1) * w, GY1, grass_a if posmod(i, 2) == 0 else grass_b)
		"checker":
			var cw: float = 68.0 / 7.0
			var ch: float = 105.0 / 16.0
			for j in range(-2, 19):
				for i in range(-1, 9):
					_quad(i * cw, j * ch, (i + 1) * cw, (j + 1) * ch, grass_a if posmod(i + j, 2) == 0 else grass_b)
		"diagonal":
			_quad(GX0, GY0, GX1, GY1, grass_a)
			var bw: float = 10.0
			for i in range(-14, 14):
				if posmod(i, 2) == 1:
					var x0: float = i * bw
					_poly([Vector2(x0, GY0), Vector2(x0 + bw, GY0), Vector2(x0 + bw + (GY1 - GY0) * 0.6, GY1), Vector2(x0 + (GY1 - GY0) * 0.6, GY1)], grass_b)
		"circles":
			_quad(GX0, GY0, GX1, GY1, grass_a)
			for k in range(16, 0, -1):
				if k % 2 == 1:
					var pts: Array = []
					var r: float = k * 5.5
					for a in range(56):
						var ang: float = TAU * a / 56.0
						pts.append(Vector2(34.0 + cos(ang) * r, 52.5 + sin(ang) * r))
					_poly(pts, grass_b)
					var inner: Array = []
					var r2: float = (k - 1) * 5.5
					if r2 > 0.0:
						for a in range(56):
							var ang2: float = TAU * a / 56.0
							inner.append(Vector2(34.0 + cos(ang2) * r2, 52.5 + sin(ang2) * r2))
						_poly(inner, grass_a)
		"wide":
			var bh: float = 105.0 / 8.0
			for i in range(-1, 10):
				_quad(GX0, i * bh, GX1, (i + 1) * bh, grass_a if posmod(i, 2) == 0 else grass_b)
		_:
			var sh: float = 105.0 / 16.0
			for i in range(-2, 19):
				_quad(GX0, i * sh, GX1, (i + 1) * sh, grass_a if posmod(i, 2) == 0 else grass_b)
			var vw: float = 68.0 / 7.0
			for i in range(7):
				if i % 2 == 1:
					_quad(i * vw, -2.0, (i + 1) * vw, 107.0, Color(1, 1, 1, 0.035))

func _draw_lines() -> void:
	var lw: float = clampf(0.12 * v.s, 1.6, 3.2)
	_line(Vector2(0, 0), Vector2(68, 0), lw)
	_line(Vector2(68, 0), Vector2(68, 105), lw)
	_line(Vector2(68, 105), Vector2(0, 105), lw)
	_line(Vector2(0, 105), Vector2(0, 0), lw)
	_line(Vector2(0, 52.5), Vector2(68, 52.5), lw)
	_ring(Vector2(34, 52.5), 9.15, 0.0, TAU, lw)
	v.draw_circle(v.w2s(Vector2(34, 52.5)), lw * 1.3, LINE)
	for top in [true, false]:
		var y0: float = 0.0 if top else 105.0
		var sg: float = 1.0 if top else -1.0
		for box in [[20.16, 16.5], [9.16, 5.5]]:
			var hw: float = float(box[0])
			var dp: float = float(box[1]) * sg
			_line(Vector2(34 - hw, y0), Vector2(34 - hw, y0 + dp), lw)
			_line(Vector2(34 - hw, y0 + dp), Vector2(34 + hw, y0 + dp), lw)
			_line(Vector2(34 + hw, y0 + dp), Vector2(34 + hw, y0), lw)
		v.draw_circle(v.w2s(Vector2(34, y0 + 11.0 * sg)), lw * 1.3, LINE)
		# Medialuna: solo la parte fuera del área.
		_ring(Vector2(34, y0 + 11.0 * sg), 9.15, 0.0, TAU, lw, 5.5, sg)
	# Arcos de córner.
	for c in [[0.0, 0.0, 0.0], [68.0, 0.0, PI * 0.5], [68.0, 105.0, PI], [0.0, 105.0, PI * 1.5]]:
		_ring(Vector2(c[0], c[1]), 1.0, float(c[2]), float(c[2]) + PI * 0.5, lw)

func _draw_clouds() -> void:
	if night:
		return
	for k in range(3):
		var u: float = fmod(live_t * (0.010 + 0.004 * k) + k * 0.37, 1.4) - 0.2
		var c: Vector2 = v.w2s(Vector2(u * 68.0, 18.0 + k * 34.0))
		var rad: float = (14.0 + 3.0 * k) * v.s
		v.draw_set_transform(c, 0.0, Vector2(1.0, 0.42))
		v.draw_circle(Vector2.ZERO, rad, Color(0, 0, 0, 0.05))
		v.draw_circle(Vector2(rad * 0.5, rad * 0.2), rad * 0.7, Color(0, 0, 0, 0.04))
		v.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Tribunas a los costados y la de atrás de TU arco, VISTAS DESDE ARRIBA
## (17-oct, Wilber: "algunos sprites del estadio no tienen sentido"): antes
## se repetía el dibujo de una tribuna en diagonal (con un pedazo de pasto),
## que desde esta cámara se veía torcido. Ahora: escalones de cemento y filas
## de hinchas (cabeza + hombros con los colores del local) que se mueven.
func _draw_side_stands() -> void:
	var vs: Vector2 = v.get_viewport_rect().size
	var step_m: float = 1.35                 # fondo de cada escalón (m)
	var seat_m: float = 0.95                 # un hincha cada tanto (m)
	var head: float = maxf(2.0, 0.22 * v.s)
	for side in [-1.0, 1.0]:
		var x_in: float = GX0 if side < 0.0 else GX1
		# ¿Se ve esta tribuna?
		var edge: Vector2 = v.w2s(Vector2(x_in, 0.0))
		if (side < 0.0 and edge.x < -10.0) or (side > 0.0 and edge.x > vs.x + 10.0):
			continue
		for k in range(9):
			var x: float = x_in + side * (0.7 + k * step_m)
			var px_x: float = v.w2s(Vector2(x, 0)).x
			if px_x < -20.0 or px_x > vs.x + 20.0:
				continue
			_line(Vector2(x - side * step_m * 0.5, GY0 - 12.0), Vector2(x - side * step_m * 0.5, GY1 + 12.0), maxf(1.0, 0.08 * v.s), Color(1, 1, 1, 0.05))
			var y0: float = clampf(v.cam.y - vs.y / (v.s * v.TILT), GY0 - 12.0, GY1 + 12.0)
			var y1: float = clampf(v.cam.y + vs.y / (v.s * v.TILT), GY0 - 12.0, GY1 + 12.0)
			var j: int = int(floorf(y0 / seat_m))
			while j * seat_m < y1:
				_fan(Vector2(x + side * 0.05 * float(posmod(j, 3)), j * seat_m), k * 31 + j * 7 + (0 if side < 0.0 else 500), head)
				j += 1
	# Atrás de TU arco (abajo): mismas filas, a lo ancho.
	var bot: Vector2 = v.w2s(Vector2(0.0, GY1))
	if bot.y < vs.y + 10.0:
		for k in range(8):
			var y: float = GY1 + 0.7 + k * step_m
			if v.w2s(Vector2(0, y)).y > vs.y + 20.0:
				break
			_line(Vector2(GX0 - 12.0, y - step_m * 0.5), Vector2(GX1 + 12.0, y - step_m * 0.5), maxf(1.0, 0.08 * v.s), Color(1, 1, 1, 0.05))
			var i: int = int(floorf((GX0 - 12.0) / seat_m))
			while i * seat_m < GX1 + 12.0:
				_fan(Vector2(i * seat_m, y + 0.05 * float(posmod(i, 3))), k * 53 + i * 11 + 1000, head)
				i += 1

## Un hincha visto desde arriba: hombros (camiseta) + cabeza; salta con el gol.
func _fan(w: Vector2, salt: int, head: float) -> void:
	var c: Vector2 = v.w2s(w)
	if c.x < -10.0 or c.y < -10.0 or c.x > v.get_viewport_rect().size.x + 10.0 or c.y > v.get_viewport_rect().size.y + 10.0:
		return
	var h: int = absi(salt * 2654435761) % 997
	if h % 9 == 0:
		return # asiento vacío
	var col: Color = _crowd[h % _crowd.size()]
	var bob: float = (absf(sin(live_t * 9.0 + float(h))) * head * 1.2) if hype > 0.0 else sin(live_t * 2.0 + float(h)) * 0.6
	v.draw_rect(Rect2(c + Vector2(-head * 1.1, -bob), Vector2(head * 2.2, head * 1.3)), col.darkened(0.1))
	var skins := [Color(0.95, 0.82, 0.70), Color(0.85, 0.65, 0.48), Color(0.62, 0.42, 0.28), Color(0.40, 0.27, 0.18)]
	v.draw_circle(c + Vector2(0, -head * 0.5 - bob), head * 0.75, skins[h % skins.size()])
	if h % 4 == 0:
		v.draw_circle(c + Vector2(0, -head * 0.75 - bob), head * 0.6, Color(0.18, 0.13, 0.1)) # pelo

## Vallas de publicidad a los costados (en los colores del local).
func _draw_side_boards() -> void:
	for k in range(15):
		var y0: float = 1.0 + k * 7.0
		var bc: Color = (cols[k % 2] as Color).darkened(0.15)
		for x in [-3.2, 71.2]:
			if x < 0.0 and y0 > 33.0 and y0 < 72.0:
				continue # delante de los bancos y del túnel no hay vallas
			var a: Vector2 = v.w2s(Vector2(x, y0))
			var b: Vector2 = v.w2s(Vector2(x, y0 + 6.4))
			v.draw_line(a, b, bc, maxf(4.0, 0.5 * v.s))

## Tribuna de cabecera (detrás de cada arco): fondo, público, pancartas,
## la barra saltando, banderas y flashes.
func _draw_end_stand(top: bool) -> void:
	var y_edge: float = GY0 if top else GY1
	var front: Vector2 = v.w2s(Vector2(0, y_edge))
	var vs: Vector2 = v.get_viewport_rect().size
	if top and front.y < -40.0:
		return
	if not top and front.y > vs.y + 40.0:
		return
	var left: float = v.w2s(Vector2(GX0 - 6.0, 0)).x
	var right: float = v.w2s(Vector2(GX1 + 6.0, 0)).x
	var ps: float = v.px
	var nm: Color = Color(0.62, 0.64, 0.78) if night else Color.WHITE
	if top:
		# Escalones.
		for row in range(5):
			v.draw_rect(Rect2(Vector2(left, front.y - 14.0 - row * 26.0 * ps * 0.6), Vector2(right - left, 2)), Color(1, 1, 1, 0.05))
	var big: Texture2D = null
	var bsrc := Rect2()
	if stand_kind == 1:
		big = tex("stand_roof")
		bsrc = Rect2(0, 8, 128, 72)
	elif stand_kind == 2:
		big = tex("stand_modern")
		bsrc = Rect2(0, 12, 128, 78)
	var crowd: Texture2D = tex("crowd")
	if top:
		if big != null:
			var bx: float = left
			while bx < right:
				v.draw_texture_rect_region(big, Rect2(Vector2(bx, front.y - bsrc.size.y * ps), bsrc.size * ps), bsrc, nm)
				bx += 128.0 * ps
		elif crowd != null:
			var x: float = left
			while x < right:
				v.draw_texture_rect_region(crowd, Rect2(Vector2(x, front.y - 40.0 * ps), Vector2(100, 40) * ps), Rect2(0, 0, 100, 40), Color(0.86, 0.86, 0.9))
				v.draw_texture_rect_region(crowd, Rect2(Vector2(x + 50.0 * ps, front.y - 78.0 * ps), Vector2(100, 40) * ps), Rect2(0, 0, 100, 40), Color(0.66, 0.66, 0.72))
				x += 100.0 * ps
		# Hinchas sueltos que se mueven (y LA OLA).
		var y0: float = front.y - 120.0 * ps
		for i in range(_crowd.size()):
			var hx: float = lerpf(left, right, fmod(float(i) * 0.6180339, 1.0))
			var hy: float = lerpf(y0 - 40.0, y0 + 30.0, fmod(float(i) * 0.37, 1.0))
			var bob: float = sin(live_t * 3.0 + float(i)) * (2.5 if hype > 0.0 else 0.6) - _wave((hx - left) / maxf(right - left, 1.0))
			v.draw_rect(Rect2(Vector2(hx, hy + bob), Vector2(4, 5) * ps * 0.8), _crowd[i])
			v.draw_rect(Rect2(Vector2(hx + 1, hy + bob - 3 * ps * 0.8), Vector2(2, 3) * ps * 0.8), Color(0.85, 0.7, 0.55))
		_draw_flags(Rect2(Vector2(left, y0 - 40.0), Vector2(right - left, 70.0)))
		_draw_banners(front.y, left, right)
		var ut: Texture2D = tex("ultras")
		if ut != null:
			var tint: Color = (cols[0] as Color).lerp(Color.WHITE, 0.45)
			for k in range(3):
				var ux: float = lerpf(v.w2s(Vector2(0, 0)).x, v.w2s(Vector2(68, 0)).x, 0.2 + 0.3 * k)
				var hop: float = absf(sin(live_t * (9.0 if hype > 0.0 else 4.0) + k * 1.3)) * (5.0 if hype > 0.0 else 2.0) * ps
				var utex: Texture2D = _now("ultras", 11.0 if hype > 0.0 else 6.0, k * 3.0)
				v.draw_texture_rect(utex, Rect2(Vector2(ux - 32.0 * ps, front.y - 44.0 * ps - hop), Vector2(64, 48) * ps), false, tint)
	elif false:
		if crowd != null:
			var x2: float = left
			while x2 < right:
				v.draw_texture_rect_region(crowd, Rect2(Vector2(x2, front.y - 8.0), Vector2(100, 40) * ps), Rect2(0, 0, 100, 40), Color(0.8, 0.8, 0.86))
				v.draw_texture_rect_region(crowd, Rect2(Vector2(x2 + 50.0 * ps, front.y + 30.0 * ps), Vector2(100, 40) * ps), Rect2(0, 0, 100, 40), Color(0.68, 0.68, 0.74))
				x2 += 100.0 * ps

func _wave(u: float) -> float:
	var cyc: float = fmod(live_t, 17.0)
	if cyc > 3.2:
		return 0.0
	var front: float = cyc / 3.2 * 1.3 - 0.15
	return maxf(0.0, 1.0 - absf(u - front) / 0.09) * 5.0

func _draw_flags(r: Rect2) -> void:
	for k in range(5):
		var fx: float = r.position.x + r.size.x * (0.08 + 0.21 * k)
		var fy: float = r.position.y + r.size.y * (0.75 - 0.12 * (k % 3))
		var sway: float = sin(live_t * (1.6 + 0.2 * k) + k) * (7.0 if hype > 0.0 else 3.5)
		var top := Vector2(fx + sway, fy - 30.0)
		v.draw_line(Vector2(fx, fy), top, Color(0.75, 0.75, 0.78), 1.5)
		var col: Color = cols[k % cols.size()]
		var pts := PackedVector2Array([top])
		for sgi in range(1, 4):
			pts.append(top + Vector2(7.0 * sgi, sin(live_t * 5.0 + k + sgi * 0.9) * 2.5))
		for sgi in range(3, 0, -1):
			pts.append(top + Vector2(7.0 * sgi, 12.0 + sin(live_t * 5.0 + k + sgi * 0.9) * 2.5))
		pts.append(top + Vector2(0, 12))
		v.draw_colored_polygon(pts, col)
	var n: int = 26 if hype > 0.0 else (10 if night else 4)
	for k in range(n):
		if _flash(float(k) * 3.7, 0.16):
			var slot: float = floorf(live_t * 9.0) + float(k) * 17.0
			var px := Vector2(r.position.x + fmod(absf(sin(slot * 3.11) * 9973.0), 1.0) * r.size.x, r.position.y + fmod(absf(sin(slot * 7.77) * 7919.0), 1.0) * r.size.y)
			v.draw_circle(px, 2.2, Color(1, 1, 1, 0.95))
			v.draw_circle(px, 5.0, Color(1, 1, 1, 0.25))

func _flash(salt: float, chance: float) -> bool:
	var slot: float = floorf(live_t * 9.0)
	return fmod(absf(sin(slot * 12.9898 + salt * 78.233) * 43758.5453), 1.0) < chance

func _draw_banners(front_y: float, left: float, right: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = banner_seed
	var font: Font = v.font
	var count: int = 3 + rng.randi() % 3
	var span: float = right - left
	for k in range(count):
		var txt: String = BANNER_TEXTS[rng.randi() % BANNER_TEXTS.size()]
		var base_c: Color = cols[0] if rng.randf() < 0.7 else Color(0.93, 0.93, 0.9)
		var ink: Color = Color(0.97, 0.97, 0.95) if base_c.get_luminance() < 0.55 else (cols[0] as Color).darkened(0.2)
		var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 14.0
		var cx: float = left + span * (float(k) + 0.5 + rng.randf_range(-0.25, 0.25)) / float(count)
		var y: float = front_y - 16.0 - float(rng.randi() % 3) * 15.0
		var sway: float = sin(live_t * 1.4 + float(k) * 1.7) * 1.2
		var pts := PackedVector2Array([Vector2(cx - w * 0.5, y), Vector2(cx + w * 0.5, y), Vector2(cx + w * 0.5 + sway, y + 14.0), Vector2(cx - w * 0.5 + sway, y + 14.0)])
		v.draw_colored_polygon(pts, base_c.darkened(0.08))
		v.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0, 0.5), 1.0)
		v.draw_string(font, Vector2(cx - w * 0.5 + 7.0 + sway * 0.5, y + 11.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)

## Noche: todo más oscuro y azulado, con charcos de luz de los reflectores.
func draw_night() -> void:
	if not night:
		return
	var vs: Vector2 = v.get_viewport_rect().size
	v.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.0, 0.02, 0.09, 0.32))
	var g := _glow()
	var big: float = 60.0 * v.s
	for c in [Vector2(0, 0), Vector2(68, 0), Vector2(0, 105), Vector2(68, 105), Vector2(34, 52.5)]:
		var cc: Vector2 = v.w2s((c as Vector2).lerp(Vector2(34, 52.5), 0.18))
		v.draw_texture_rect(g, Rect2(cc - Vector2(big, big * v.TILT) * 0.5, Vector2(big, big * v.TILT)), false)

# ------------------------------------------------------------ objetos parados
## Lo que está parado alrededor de la cancha: se ordena por profundidad con
## los jugadores (el que está más abajo tapa al de atrás). Cada uno:
## {"y": metros (orden), "kind": "prop"/"board"/"goal", ...}.
func items() -> Array:
	var out: Array = []
	# Torres de luz solo en las esquinas del FONDO (las de abajo quedaban de
	# espaldas, encima del público).
	for c in [Vector2(-9.0, -8.0), Vector2(77.0, -8.0)]:
		out.append({"y": c.y, "kind": "prop", "name": "tower", "w": c})
	# Banquillos y túnel DIBUJADOS DESDE ARRIBA (17-oct, Wilber: "se ve
	# horrible el túnel y los banquillos"): el arte de PixelLab era en
	# diagonal (isométrico) y no encajaba con la cámara cenital.
	out.append({"y": 36.0, "kind": "dugout", "c": 40.0, "team": 0})
	out.append({"y": 61.0, "kind": "dugout", "c": 65.0, "team": 1})
	out.append({"y": 51.0, "kind": "tunnel"})
	for c in [Vector2(72.8, 20.0), Vector2(72.8, 52.5), Vector2(72.8, 86.0), Vector2(16.0, -3.4), Vector2(52.0, 107.6)]:
		out.append({"y": c.y, "kind": "prop", "name": "cameraman", "w": c, "flip": c.x < 34.0, "fps": 5.0})
	# Marcador en la esquina de la tribuna (no en medio del público) y el
	# carrito médico estacionado junto al túnel.
	out.append({"y": -8.0, "kind": "prop", "name": "scoreboard", "w": Vector2(-3.5, -8.0)})
	out.append({"y": 74.0, "kind": "prop", "name": "medcart", "w": Vector2(-4.8, 74.0)})
	for sx in [6.0, 11.5, 56.5, 62.0]:
		for gy in [-2.2, 107.2]:
			out.append({"y": gy, "kind": "prop", "name": "photographer", "w": Vector2(sx, gy), "flip": sx < 34.0,
				"flash": _flash(sx * 31.0 + gy * 7.0, 0.06 if hype > 0.0 else 0.012)})
	var kid: int = 0
	for c in [Vector2(-2.0, 17.0), Vector2(70.0, 37.0), Vector2(-2.0, 76.0), Vector2(70.0, 92.0), Vector2(-1.8, 1.8), Vector2(69.8, 103.2)]:
		out.append({"y": c.y, "kind": "prop", "name": "ballboy", "w": c, "flip": c.x > 34.0, "fps": 6.0,
			"lift": absf(sin(live_t * 8.0 + kid)) * 3.0 if hype > 0.0 else 0.0})
		kid += 1
	for k in range(7):
		var sy: float = 7.0 + k * 15.0
		if sy < 33.0 or sy > 72.0: # en la zona de bancos y túnel no hay guardias
			out.append({"y": sy, "kind": "prop", "name": "steward", "w": Vector2(-5.6, sy)})
		out.append({"y": sy, "kind": "prop", "name": "steward", "w": Vector2(73.6, sy), "flip": true})
	out.append({"y": 109.2, "kind": "board", "end": 1})
	out.append({"y": 105.01, "kind": "goal", "end": 1})
	for c in [Vector2(0, 0), Vector2(68, 0), Vector2(0, 105), Vector2(68, 105)]:
		out.append({"y": c.y + 0.02, "kind": "flag", "w": c})
	return out

func draw_item(it: Dictionary) -> void:
	match String(it["kind"]):
		"prop":
			_draw_prop(it)
		"board":
			_draw_end_board(int(it["end"]))
		"goal":
			draw_goal(int(it["end"]))
		"dugout":
			_draw_dugout(float(it["c"]), int(it["team"]))
		"tunnel":
			_draw_tunnel()
		"flag":
			var base: Vector2 = v.w2s(it["w"])
			if not _visible(base):
				return
			var hgt: float = 18.0 * v.px
			v.draw_line(base, base - Vector2(0, hgt), Color(0.95, 0.95, 0.95), 2.0)
			var dir: float = 1.0 if float((it["w"] as Vector2).x) == 0.0 else -1.0
			v.draw_colored_polygon(PackedVector2Array([base - Vector2(0, hgt), base - Vector2(-9.0 * dir * v.px * 0.8, hgt * 0.82 + sin(live_t * 6.0 + base.x) * 2.0), base - Vector2(0, hgt * 0.62)]), Color(1.0, 0.82, 0.2))

## Banquillo visto desde arriba: piso, suplentes sentados (cabeza y hombros
## con su camiseta), el techo de acrílico transparente con su marco (más
## arriba en pantalla porque está alto) y el DT parado en el área técnica.
func _draw_dugout(c: float, team: int) -> void:
	var p0: Vector2 = v.w2s(Vector2(-5.6, c - 5.0))
	var p1: Vector2 = v.w2s(Vector2(-2.6, c + 5.0))
	if not _visible(p0, 200.0) and not _visible(p1, 200.0):
		return
	var floor_r := Rect2(p0, p1 - p0)
	v.draw_rect(floor_r.grow(3.0), Color(0, 0, 0, 0.25))
	v.draw_rect(floor_r, Color(0.22, 0.23, 0.27))
	v.draw_rect(Rect2(floor_r.position, Vector2(floor_r.size.x * 0.3, floor_r.size.y)), Color(0.15, 0.16, 0.19)) # pared del fondo
	# Suplentes SENTADOS: el sprite de costado (mirando a la cancha) solo de
	# la cintura para arriba, apoyado en el banco.
	var ps: float = v.px
	for k in range(4):
		var cfgk: Dictionary = _bench_cfg[team][k]
		var fr: Array = Avatar.anim_frames(cfgk, "pitch_idle_east")
		if fr.is_empty():
			continue
		var tx: Texture2D = fr[0]
		var y: float = c - 3.3 + k * 2.4
		var seat: Vector2 = v.w2s(Vector2(-4.3, y))
		var bob: float = (absf(sin(live_t * 8.0 + k)) * 4.0 * ps) if hype > 0.0 else 0.0
		var cut: float = 36.0 # filas del sprite que se ven (cabeza y torso)
		var w: float = 68.0 * ps
		v.draw_texture_rect_region(tx, Rect2(seat - Vector2(w * 0.5, cut * ps + bob), Vector2(w, cut * ps)), Rect2(0, 0, 68, cut))
	# Frente del banco (tapa las piernas) y techo de acrílico con su marco.
	var front := Rect2(Vector2(v.w2s(Vector2(-3.4, 0)).x, floor_r.position.y), Vector2(v.w2s(Vector2(-2.6, 0)).x - v.w2s(Vector2(-3.4, 0)).x, floor_r.size.y))
	v.draw_rect(front, Color(0.32, 0.34, 0.40))
	v.draw_rect(Rect2(front.position, Vector2(front.size.x, 3.0)), Color(0.5, 0.52, 0.58))
	var lift: float = 2.2 * v.hpx() * 0.45
	var roof := Rect2(floor_r.position - Vector2(3.0, lift + 3.0), floor_r.size + Vector2(6.0, 6.0))
	v.draw_rect(roof, Color(0.78, 0.88, 0.98, 0.18))
	v.draw_rect(roof, Color(0.88, 0.9, 0.94, 0.9), false, maxf(2.0, 0.14 * v.s))
	for k in range(1, 5):
		var yy: float = roof.position.y + roof.size.y * k / 5.0
		v.draw_line(Vector2(roof.position.x, yy), Vector2(roof.end.x, yy), Color(0.88, 0.9, 0.94, 0.35), 1.0)
	# Área técnica (líneas blancas en el pasto) y el DT caminando adentro.
	var a0: Vector2 = v.w2s(Vector2(-2.4, c - 6.0))
	var a1: Vector2 = v.w2s(Vector2(-0.6, c + 6.0))
	var lw: float = maxf(1.0, 0.07 * v.s)
	for i in range(12):
		if i % 2 == 0:
			v.draw_line(Vector2(a1.x, lerpf(a0.y, a1.y, float(i) / 12.0)), Vector2(a1.x, lerpf(a0.y, a1.y, float(i + 1) / 12.0)), Color(1, 1, 1, 0.55), lw)
	v.draw_line(Vector2(a0.x, a0.y), Vector2(a1.x, a0.y), Color(1, 1, 1, 0.55), lw)
	v.draw_line(Vector2(a0.x, a1.y), Vector2(a1.x, a1.y), Color(1, 1, 1, 0.55), lw)
	# El DT va y viene por su área: camina (correr lento) o se para a mirar.
	var ph: float = fmod(live_t * 0.25 + team * 0.5, 2.0)
	var moving: bool = ph < 0.6 or (ph > 1.0 and ph < 1.6)
	var cy: float = c + (lerpf(-3.0, 3.0, ph / 0.6) if ph < 0.6 else (3.0 if ph <= 1.0 else (lerpf(3.0, -3.0, (ph - 1.0) / 0.6) if ph < 1.6 else -3.0)))
	var anim: String = ("pitch_run_south" if ph < 0.6 else "pitch_run_north") if moving else "pitch_idle_east"
	var gest: String = String(coach_act[team][0])
	var gt: float = live_t - float(coach_act[team][1])
	var gest_on: bool = gest != "" and gt < 2.6 and Avatar.has_anim(gest)
	if gest_on:
		anim = gest
		moving = false
	var cfr: Array = Avatar.anim_frames(_coach_cfg[team], anim)
	if not cfr.is_empty():
		var ct: Texture2D = cfr[int(live_t * 5.0) % cfr.size()] if moving else cfr[0]
		if gest_on:
			ct = cfr[mini(int(gt * 9.0), cfr.size() - 1)] if gest != "coach_festeja" else cfr[int(gt * 9.0) % cfr.size()]
		var feet: Vector2 = v.w2s(Vector2(-1.5, cy))
		v.draw_set_transform(feet + Vector2(1, 1), 0.0, Vector2(1.0, 0.35))
		v.draw_circle(Vector2.ZERO, 0.7 * v.s, Color(0, 0, 0, 0.28))
		v.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var sz := Vector2(68, 68) * ps
		v.draw_texture_rect(ct, Rect2(feet - Vector2(sz.x * 0.5, sz.y * (56.5 / 68.0)), sz), false)

## TÚNEL de salida (17-oct, Wilber: "mejora el túnel"): la manga inflable
## de los estadios, vista desde arriba. Techo de medio cilindro con franjas
## en los colores del local (luz arriba, sombra a los costados), costillas,
## la pared de adelante (se ve por la inclinación de la cámara), el logo en
## el techo, la alfombra que sale a la cancha y la boca oscura en la tribuna.
func _draw_tunnel() -> void:
	var x0: float = GX0 - 6.0   # entra en la tribuna
	var x1: float = -2.9        # boca, del lado de la cancha
	var yc: float = 52.5
	var hw: float = 1.8
	if not _visible(v.w2s(Vector2(x1, yc)), 300.0):
		return
	# Alto en pantalla: más bajo que el real (con 2,5 m quedaba una caja
	# enorme); se lee como una manga.
	var lift: float = 1.15 * v.hpx()
	var up := Vector2(0, -lift)
	var kit: Color = cols[0]
	# Sombra en el piso (luz de arriba a la izquierda) y alfombra de salida.
	_quad(x0, yc - hw + 0.4, x1 + 0.9, yc + hw + 0.9, Color(0, 0, 0, 0.28))
	_quad(x1, yc - 1.1, x1 + 2.4, yc + 1.1, Color(0.16, 0.17, 0.2))
	_quad(x1 + 0.1, yc - 1.0, x1 + 2.3, yc - 0.85, Color(1, 1, 1, 0.5))
	_quad(x1 + 0.1, yc + 0.85, x1 + 2.3, yc + 1.0, Color(1, 1, 1, 0.5))
	# Pared de adelante (lado de la cámara): del piso al techo.
	var fl: Vector2 = v.w2s(Vector2(x0, yc + hw))
	var fr: Vector2 = v.w2s(Vector2(x1, yc + hw))
	v.draw_colored_polygon(PackedVector2Array([fl, fr, fr + up * 0.62, fl + up * 0.62]), kit.darkened(0.55))
	# Techo: medio cilindro en franjas a lo ancho, con el sombreado de volumen.
	var bands: int = 9
	for i in range(bands):
		var u0: float = float(i) / bands
		var u1: float = float(i + 1) / bands
		# Altura del techo en cada franja (arco): más alto al medio.
		var h0: float = sin(PI * u0) * 0.38 + 0.62
		var h1: float = sin(PI * u1) * 0.38 + 0.62
		var ya: float = yc - hw + 2.0 * hw * u0
		var yb: float = yc - hw + 2.0 * hw * u1
		var light: float = clampf(1.15 - absf((u0 + u1) * 0.5 - 0.38) * 1.6, 0.45, 1.15)
		var seg: int = 0
		var xa: float = x0
		while xa < x1 - 0.01:
			var xb: float = minf(xa + 1.6, x1)
			var base: Color = kit.darkened(0.05) if seg % 2 == 0 else kit.lightened(0.06)
			var col: Color = Color(base.r * light, base.g * light, base.b * light)
			var p_a: Vector2 = v.w2s(Vector2(xa, ya)) + up * h0
			var p_b: Vector2 = v.w2s(Vector2(xb, ya)) + up * h0
			var p_c: Vector2 = v.w2s(Vector2(xb, yb)) + up * h1
			var p_d: Vector2 = v.w2s(Vector2(xa, yb)) + up * h1
			v.draw_colored_polygon(PackedVector2Array([p_a, p_b, p_c, p_d]), col)
			xa = xb
			seg += 1
	# Costillas (los aros de la manga) y el borde de la boca.
	var nrib: int = int((x1 - x0) / 1.6) + 1
	for k in range(nrib + 1):
		var x: float = minf(x0 + k * 1.6, x1)
		var pts := PackedVector2Array()
		for j in range(bands + 1):
			var u: float = float(j) / bands
			pts.append(v.w2s(Vector2(x, yc - hw + 2.0 * hw * u)) + up * (sin(PI * u) * 0.38 + 0.62))
		v.draw_polyline(pts, Color(1, 1, 1, 0.28) if k < nrib else Color(0.95, 0.95, 0.98), maxf(1.0, (0.05 if k < nrib else 0.12) * v.s))
	# Franja blanca a lo largo (la del club) por arriba de la manga.
	var s0: Vector2 = v.w2s(Vector2(x0, yc - hw * 0.25)) + up
	var s1: Vector2 = v.w2s(Vector2(x1, yc - hw * 0.25)) + up
	v.draw_line(s0, s1, Color(1, 1, 1, 0.8), maxf(2.0, 0.22 * v.s))
	# Logo del club / patrocinador en el techo, cerca de la boca.
	var logos: Array = _board_logos()
	if not logos.is_empty():
		var lt: Texture2D = logos[banner_seed % logos.size()]
		var lc: Vector2 = v.w2s(Vector2(x1 - 1.8, yc + 0.4)) + up * 0.95
		var ls: float = 1.4 * v.s
		v.draw_texture_rect(lt, Rect2(lc - Vector2(ls, ls * 0.8) * 0.5, Vector2(ls, ls * 0.8)), false, Color(1, 1, 1, 0.9))
	# Boca oscura donde la manga se mete en la tribuna.
	var b0: Vector2 = v.w2s(Vector2(x0 - 0.8, yc - hw))
	var b1: Vector2 = v.w2s(Vector2(x0, yc + hw))
	v.draw_rect(Rect2(b0 + up * 0.6, b1 - b0 - up * 0.6), Color(0.04, 0.04, 0.06))

func _draw_prop(it: Dictionary) -> void:
	var name: String = it["name"]
	var t: Texture2D = _now(name, float(it.get("fps", 0.0)), float((it["w"] as Vector2).x) * 0.7)
	if t == null:
		return
	var base: Vector2 = v.w2s(it["w"])
	if not _visible(base, 200.0):
		return
	var ps: float = v.px
	var sz: Vector2 = t.get_size() * ps
	var lift: float = float(it.get("lift", 0.0)) * ps
	var r := Rect2(base - Vector2(sz.x * 0.5, sz.y - 4.0 * ps + lift), sz)
	if bool(it.get("flip", false)):
		r = Rect2(r.position, Vector2(-sz.x, sz.y))
	v.draw_texture_rect(t, r, false, Color(0.62, 0.64, 0.78) if night else Color.WHITE)
	if bool(it.get("flash", false)):
		v.draw_circle(base + Vector2(0, -14.0 * ps), 6.0 * ps, Color(1, 1, 1, 0.9))
	if name == "scoreboard" and score_text != "":
		var fs: int = int(14.0 * ps)
		var tw: float = v.font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		v.draw_string(v.font, Vector2(base.x - tw * 0.5, base.y - sz.y * 0.5 + 6.0 * ps), score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.86, 0.3))

## Valla de cabecera (parada, con logos de patrocinadores y barrido LED).
func _draw_end_board(end: int) -> void:
	var y: float = -5.5 if end == 0 else 109.2
	var l: Vector2 = v.w2s(Vector2(-2.0, y))
	if l.y < -60.0 or l.y > v.get_viewport_rect().size.y + 60.0:
		return
	var rgt: Vector2 = v.w2s(Vector2(70.0, y))
	var h: float = 14.0 * v.px
	var seg: float = (rgt.x - l.x) / 9.0
	var logos: Array = _board_logos()
	for i in range(9):
		var c: Color = cols[i % 2]
		var r := Rect2(Vector2(l.x + i * seg, l.y - h), Vector2(seg - 2.0, h))
		v.draw_rect(r, c.darkened(0.15))
		if not logos.is_empty():
			var lt: Texture2D = logos[(i + end * 3) % logos.size()]
			var ls: float = h - 4.0
			v.draw_texture_rect(lt, Rect2(r.position + Vector2((r.size.x - ls) * 0.5, 2.0), Vector2(ls, ls)), false)
	v.draw_rect(Rect2(Vector2(l.x, l.y), Vector2(rgt.x - l.x, 2)), Color(0, 0, 0, 0.35))
	var sweep: float = fmod(live_t * 0.22 + end * 0.5, 1.6) - 0.3
	if sweep > 0.0 and sweep < 1.0:
		var sx: float = lerpf(l.x, rgt.x, sweep)
		v.draw_rect(Rect2(Vector2(sx - 12.0, l.y - h), Vector2(24, h)), Color(1, 1, 1, 0.22))

# --------------------------------------------------------------------- arcos
## Arco en 3D como el del juego: postes que suben, travesaño, red-caja que
## cae hacia atrás y se HUNDE donde entró la pelota. `end` 0 = arriba (y=0,
## donde atacás), 1 = abajo (tu arco, se dibuja delante de los jugadores).
func draw_goal(end: int) -> void:
	var yg: float = 0.0 if end == 0 else 105.0
	var half: float = Sim.GOAL_HALF
	var gl: Vector2 = v.w2s(Vector2(34.0 - half, yg))
	if not _visible(gl, 300.0):
		return
	var gw: float = half * 2.0 * v.s
	var lw: float = clampf(0.12 * v.s, 1.6, 3.2)
	# Alto contra el SPRITE (un jugador "mide" ~1,8 m: travesaño ≈ 1,35 cuerpos).
	var gh: float = Sim.GOAL_H * v.hpx()
	# Red honda como en WSC: el techo de malla se ve bien arriba del travesaño.
	var gd: float = 2.4 * v.s * v.TILT * (1.0 if end == 0 else -1.0)
	var inset: float = gw * 0.03
	var front_l := gl
	var front_r := gl + Vector2(gw, 0)
	var top_l := front_l - Vector2(0, gh)
	var top_r := front_r - Vector2(0, gh)
	var back_l := gl + Vector2(inset, -gd)
	var back_r := gl + Vector2(gw - inset, -gd)
	var btop_l := back_l - Vector2(0, gh * 0.95)
	var btop_r := back_r - Vector2(0, gh * 0.95)
	# SOMBRA del arco en el pasto (luz de arriba a la izquierda, como WSC):
	# la de la red, suave, y la de los palos y el travesaño, marcada.
	var sh := Vector2(gh * 0.55, gh * 0.22)
	var pws: float = maxf(4.0, Sim.POST_R * 2.0 * v.s * 1.6)
	v.draw_colored_polygon(PackedVector2Array([front_l, front_r, front_r + sh, front_l + sh]), Color(0, 0, 0, 0.13))
	v.draw_line(front_l + Vector2(2, 1), front_l + sh, Color(0, 0, 0, 0.26), pws)
	v.draw_line(front_r + Vector2(2, 1), front_r + sh, Color(0, 0, 0, 0.26), pws)
	v.draw_line(front_l + sh, front_r + sh, Color(0, 0, 0, 0.24), pws)
	var net := Color(1, 1, 1, 0.10)
	var mesh := Color(1, 1, 1, 0.28)
	if end == 0:
		v.draw_colored_polygon(PackedVector2Array([back_l, btop_l, btop_r, back_r]), Color(0.05, 0.08, 0.06, 0.35))
	v.draw_colored_polygon(PackedVector2Array([back_l, btop_l, btop_r, back_r]), net)
	v.draw_colored_polygon(PackedVector2Array([front_l, top_l, btop_l, back_l]), net)
	v.draw_colored_polygon(PackedVector2Array([front_r, top_r, btop_r, back_r]), net)
	v.draw_colored_polygon(PackedVector2Array([top_l, top_r, btop_r, btop_l]), Color(1, 1, 1, 0.10))
	# Techo de malla tupida (lo que más se ve del arco desde arriba).
	var roof_mesh := Color(1, 1, 1, 0.5)
	for j in range(1, 6):
		var tr: float = float(j) / 6.0
		v.draw_line(top_l.lerp(btop_l, tr), top_r.lerp(btop_r, tr), roof_mesh, 1.0)
	var ncols: int = maxi(8, int(gw / 6.0))
	var age: float = live_t - net_t
	var hit: bool = end == net_end and age >= 0.0 and age < 1.6
	var amp: float = (15.0 * exp(-3.0 * age) * cos(age * 15.0) + 9.0 * exp(-2.2 * age)) * v.px if hit else 0.0
	var hx: float = clampf((net_x - (34.0 - half)) / (half * 2.0), 0.0, 1.0)
	var away := Vector2(0, -1.0 if end == 0 else 1.0)
	var mesh_hit: Color = Color(1, 1, 1, 0.5) if hit else mesh
	for i in range(ncols + 1):
		var t: float = float(i) / ncols
		if hit:
			var pts := PackedVector2Array()
			for k in range(5):
				var ty: float = float(k) / 4.0
				var w0: float = exp(-pow((t - hx) / 0.22, 2.0)) * sin(PI * clampf(ty * 0.8 + 0.1, 0.0, 1.0))
				pts.append(back_l.lerp(back_r, t).lerp(btop_l.lerp(btop_r, t), ty) + away * amp * w0)
			v.draw_polyline(pts, mesh_hit, 1.0)
		else:
			v.draw_line(back_l.lerp(back_r, t), btop_l.lerp(btop_r, t), mesh, 1.0)
		v.draw_line(top_l.lerp(top_r, t), btop_l.lerp(btop_r, t), Color(1, 1, 1, 0.5), 1.0)
	for j in range(1, 5):
		var t2: float = float(j) / 5.0
		if hit:
			var pts2 := PackedVector2Array()
			for k in range(ncols + 1):
				var tx: float = float(k) / ncols
				var w1: float = exp(-pow((tx - hx) / 0.22, 2.0)) * sin(PI * clampf(t2 * 0.8 + 0.1, 0.0, 1.0))
				pts2.append(back_l.lerp(back_r, tx).lerp(btop_l.lerp(btop_r, tx), t2) + away * amp * w1)
			v.draw_polyline(pts2, mesh_hit, 1.0)
		else:
			v.draw_line(back_l.lerp(btop_l, t2), back_r.lerp(btop_r, t2), mesh, 1.0)
		v.draw_line(front_l.lerp(top_l, t2), back_l.lerp(btop_l, t2), mesh, 1.0)
		v.draw_line(front_r.lerp(top_r, t2), back_r.lerp(btop_r, t2), mesh, 1.0)
	v.draw_line(back_l, back_r, Color(1, 1, 1, 0.45), 1.5)
	v.draw_line(btop_l, btop_r, Color(1, 1, 1, 0.40), 1.2)
	v.draw_line(top_l, btop_l, Color(1, 1, 1, 0.40), 1.2)
	v.draw_line(top_r, btop_r, Color(1, 1, 1, 0.40), 1.2)
	# Palos más gruesos (17-oct, Wilber): el grosor sale del de la física
	# (Sim.POST_R) para que el tiro al palo pegue donde se ve el palo.
	var pw: float = maxf(4.0, Sim.POST_R * 2.0 * v.s * 1.6)
	for pair in [[front_l, top_l], [front_r, top_r]]:
		v.draw_line(pair[0], pair[1], Color.WHITE, pw)
		v.draw_line(pair[0] + Vector2(pw * 0.3, 0), pair[1] + Vector2(pw * 0.3, 0), Color(0.72, 0.74, 0.78), pw * 0.4)
	v.draw_line(top_l, top_r, Color.WHITE, pw)
	v.draw_line(top_l + Vector2(0, pw * 0.3), top_r + Vector2(0, pw * 0.3), Color(0.72, 0.74, 0.78), pw * 0.4)
	v.draw_circle(top_l, pw * 0.5, Color.WHITE)
	v.draw_circle(top_r, pw * 0.5, Color.WHITE)
