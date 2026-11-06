extends Control
class_name PitchView

## (10-oct: ahora es la CANCHA COMPLETA — ver "CANCHA COMPLETA" más abajo.)
## Media cancha vista desde arriba (Paquete 1 del ROADMAP, 9-oct) — pedido
## de Wilber con una captura de referencia: fichas redondas con dorsal +
## nombre, balón, el arco ARRIBA. Solo dibuja y anima; QUÉ jugada mostrar
## lo arma PitchPlays.gd y CUÁNDO lo decide Match.gd. No sabe nada del
## motor ni del balance (regla: el MatchEngine no sabe de UI, y la UI no
## decide resultados — esos vienen de DecisionResolver vía DECISION_RESULT).
##
## Coordenadas NORMALIZADAS de media cancha: x 0..1 (banda a banda),
## y 0 = línea de gol de ARRIBA, y 1 = mitad de cancha. Fuera de ese rango
## también vale (la pelota entra al arco con y < 0).

## Media cancha real: 68 m de ancho × 52,5 m de fondo.
const FIELD_ASPECT := 52.5 / 68.0
## Arco AGRANDADO a propósito (9-oct, Wilber: "el arco no está muy
## pequeño?"): a escala real (7,32 m) quedaba de juguete al lado de los
## jugadores de cuerpo entero (cada sprite "mide" ~6 m de cancha). Como en
## los juegos cenitales, el arco va ~1,8× — todo lo que apunta/ataja usa
## esta constante, así que el balance (distancias RELATIVAS al ancho del
## arco, ver Match._on_pitch_shot_released) no cambia.
const GOAL_W := 0.30   # 11-oct, Wilber: "un poco más pequeños los dos arcos" (era 0.36). Todo lo del arco (atajadas, puntería) se mide contra esta constante.
## Áreas ENSANCHADAS con el arco (10-oct, Wilber: "¿y las líneas?"): a
## escala real el área chica (0,27) quedaba MÁS ANGOSTA que el arco
## agrandado (0,36) y el arco se salía por los costados. Se ensanchan
## manteniendo el orden arco < área chica < área grande. Solo dibujo: el
## balance usa GOAL_W y las profundidades, que no cambian.
const BOX_W := 0.78
const BOX_D := 16.5 / 52.5
const SMALL_W := 0.52
const SMALL_D := 5.5 / 52.5
const SPOT_D := 11.0 / 52.5
const CIRCLE_R := 9.15 / 68.0

const GRASS_A := Color(0.16, 0.42, 0.20)
const GRASS_B := Color(0.18, 0.46, 0.22)
const LINE := Color(1, 1, 1, 0.75)

## TIPOS DE CÉSPED (10-oct, Wilber: "diferentes tipos de césped"): dibujo
## del corte + tono, determinista por estadio (Match → grass_for()).
const GRASS_PATTERNS := ["stripes", "vertical", "checker", "diagonal", "circles", "wide"]
const GRASS_TONES := [
	[Color(0.16, 0.42, 0.20), Color(0.18, 0.46, 0.22)],   # clásico
	[Color(0.13, 0.40, 0.17), Color(0.17, 0.47, 0.21)],   # intenso
	[Color(0.20, 0.42, 0.18), Color(0.23, 0.46, 0.20)],   # cálido/seco
	[Color(0.12, 0.36, 0.22), Color(0.15, 0.40, 0.25)],   # azulado (norte)
]
var grass_pattern: String = "stripes"
var grass_a: Color = GRASS_A
var grass_b: Color = GRASS_B

## Césped de un estadio (mismo estadio = mismo corte, cada partido en casa).
func grass_for(stadium_key: String) -> void:
	var h: int = absi(hash("grass:" + stadium_key))
	grass_pattern = GRASS_PATTERNS[h % GRASS_PATTERNS.size()]
	var tone: Array = GRASS_TONES[(h / 7) % GRASS_TONES.size()]
	grass_a = tone[0]
	grass_b = tone[1]
	# CADA ESTADIO, SU TRIBUNA (11-oct, Wilber: "el mismo estadio pero con
	# cositas diferentes entre uno y otro para que parezca que hay más
	# estadios... y pancartas"): techo con reflectores, dos bandejas con
	# palcos, o la popular de siempre; y pancartas propias.
	stand_kind = (h / 13) % 3
	_banner_seed = maxi(1, h % 100000)
	queue_redraw()

func _draw_grass() -> void:
	# Cancha COMPLETA: y de -0.3 (detrás del arco de arriba) a 2.3.
	match grass_pattern:
		"vertical":
			var vb: int = 9
			for i in range(-3, vb + 3):
				for seg in range(4):
					var ya: float = -0.3 + seg * 0.65
					_poly_n([Vector2(float(i) / vb, ya), Vector2(float(i + 1) / vb, ya), Vector2(float(i + 1) / vb, ya + 0.65), Vector2(float(i) / vb, ya + 0.65)], grass_a if posmod(i, 2) == 0 else grass_b)
		"checker":
			var cx: int = 7
			var cy: int = 8
			for j in range(-2, cy * 2 + 2):
				for i in range(-2, cx + 2):
					var x0: float = float(i) / cx
					var y0: float = float(j) / cy
					_poly_n([Vector2(x0, y0), Vector2(x0 + 1.0 / cx, y0), Vector2(x0 + 1.0 / cx, y0 + 1.0 / cy), Vector2(x0, y0 + 1.0 / cy)], grass_a if posmod(i + j, 2) == 0 else grass_b)
		"diagonal":
			var w: float = 0.16
			for i in range(-12, 22):
				var c: float = i * w
				for seg in range(4):
					var ya2: float = -0.3 + seg * 0.65
					var sh: float = (ya2 + 0.3) / 1.6
					_poly_n([Vector2(c - sh, ya2), Vector2(c + w - sh, ya2), Vector2(c + w - sh - 0.40625, ya2 + 0.65), Vector2(c - sh - 0.40625, ya2 + 0.65)], grass_a if posmod(i, 2) == 0 else grass_b)
		"circles":
			for seg in range(4):
				var ya3: float = -0.3 + seg * 0.65
				_poly_n([Vector2(-0.6, ya3), Vector2(1.6, ya3), Vector2(1.6, ya3 + 0.65), Vector2(-0.6, ya3 + 0.65)], grass_a)
			var rings: int = 14
			for k in range(rings, 0, -1):
				var r: float = float(k) * 0.085
				var pts: Array = []
				for a in range(48):
					var ang: float = TAU * a / 48.0
					pts.append(Vector2(0.5 + cos(ang) * r, 1.0 + sin(ang) * r / FIELD_ASPECT))
				_poly_n(pts, grass_a if k % 2 == 0 else grass_b)
		"wide":
			var bands: int = 4
			for i in range(-1, bands * 2 + 1):
				_poly_n([Vector2(-0.6, float(i) / bands), Vector2(1.6, float(i) / bands), Vector2(1.6, float(i + 1) / bands), Vector2(-0.6, float(i + 1) / bands)], grass_a if posmod(i, 2) == 0 else grass_b)
		_:
			# Franjas horizontales + corte a cuadros tenue (el de siempre).
			var bands2: int = 8
			for i in range(-2, bands2 * 2 + 2):
				_poly_n([Vector2(-0.6, float(i) / bands2), Vector2(1.6, float(i) / bands2), Vector2(1.6, float(i + 1) / bands2), Vector2(-0.6, float(i + 1) / bands2)], grass_a if posmod(i, 2) == 0 else grass_b)
			var vb2: int = 7
			for i in range(vb2):
				if i % 2 == 1:
					for seg in range(4):
						var ya4: float = -0.12 + seg * 0.5675
						_poly_n([Vector2(float(i) / vb2, ya4), Vector2(float(i + 1) / vb2, ya4), Vector2(float(i + 1) / vb2, ya4 + 0.5675), Vector2(float(i) / vb2, ya4 + 0.5675)], Color(1, 1, 1, 0.035))

signal finished
## Paquete 2: tocar la cancha para elegir la acción. `target` = id del
## actor tocado ("m1", "a1"...), "goal" (el arco de arriba) o "space".
signal tapped(target: String)

## Objetivos tocables resaltados con un anillo que late (ids o "goal").
var _targets: Array = []
var _interactive: bool = false
var _pulse: float = 0.0

## Clima (MatchIcons.weather_for, el mismo de la previa): "sun" | "cloud" |
## "rain" | "snow". Solo visual — el efecto en el juego ya existe en
## Match._context_mods (barra más rápida con lluvia/nieve).
var _weather: String = "sun"
var _wx_t: float = 0.0
var _wx_drops: Array = []

## Paquete 3: línea de fuera de juego del VAR (y normalizada; < -1 = oculta).
var _line_y: float = -9.0

## Minijuego de REMATE en la cancha (punto 5 del pedido del 9-oct): el
## arquero se mueve de palo a palo y vos arrastrás desde la pelota hacia el
## arco; al soltar se emite `shot_released`. La precisión NO se calcula
## acá (DecisionResolver.pitch_shot_precision) — esto solo mide.
signal shot_released(aim_x: float, power: float, gk_x: float)
var _aim_mode: bool = false
var _slowmo: bool = false
## Partido de NOCHE (P3, 9-oct): cancha un poco más oscura con charcos de
## luz de los reflectores y las torres arriba en las esquinas.
var night: bool = false
## Clima del partido (P6, 10-oct): "rain" = charcos, "snow" = nieve en el
## pasto. Lo fija Match con MatchIcons.weather_for.
var weather: String = ""

## DETALLES de la cancha (10-oct, "más detalles a la cancha y los
## partidos"): tribuna con hinchas detrás del arco (se mueven un poco),
## banco de suplentes al costado, fotógrafos junto al arco, alcanzapelotas
## y desgaste del pasto en el área. Todo procedural y determinista.
var _crowd_cols: Array = []
func _draw_pitch_details(f: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	# Desgaste del pasto: el área chica y el punto penal más pisados.
	for i in range(52):
		_end = i % 2
		var q := Vector2(0.5 + rng.randf_range(-0.16, 0.16), rng.randf_range(0.0, SPOT_D + 0.03))
		var c := _pw(_e(q))
		_end = 0
		draw_set_transform(_cam_offset() + c * cam_zoom, 0.0, Vector2(cam_zoom, cam_zoom * 0.5))
		draw_circle(Vector2.ZERO, rng.randf_range(2.0, 5.0), Color(0.35, 0.32, 0.18, 0.18))
	draw_set_transform(_cam_offset(), 0.0, Vector2(cam_zoom, cam_zoom))
	# Pasto con textura: motitas claras y oscuras.
	for i in range(380):
		var q2 := Vector2(rng.randf_range(-0.05, 1.05), rng.randf_range(-0.05, 2.05))
		draw_rect(Rect2(_pw(q2), Vector2(2, 1)), Color(1, 1, 1, 0.05) if i % 2 == 0 else Color(0, 0, 0, 0.06))
	if not tilt:
		return
	# Laterales y fondo de abajo (cancha completa): gradas oscuras con
	# escalones, para que al alejar o mover la cámara no se vea pasto infinito.
	var stand_col := Color(0.10, 0.11, 0.14)
	for seg in range(5):
		var sy: float = -0.4 + seg * 0.6
		_poly_n([Vector2(-1.6, sy), Vector2(-0.13, sy), Vector2(-0.13, sy + 0.6), Vector2(-1.6, sy + 0.6)], stand_col)
		_poly_n([Vector2(1.13, sy), Vector2(2.6, sy), Vector2(2.6, sy + 0.6), Vector2(1.13, sy + 0.6)], stand_col)
	_poly_n([Vector2(-1.6, 2.14), Vector2(2.6, 2.14), Vector2(2.6, 2.6), Vector2(-1.6, 2.6)], stand_col)
	for k in range(1, 6):
		var ox: float = 0.13 + k * 0.05
		_line_n(Vector2(-ox, -0.05), Vector2(-ox, 2.10), Color(1, 1, 1, 0.05), 1.5, 16)
		_line_n(Vector2(1.0 + ox, -0.05), Vector2(1.0 + ox, 2.10), Color(1, 1, 1, 0.05), 1.5, 16)
	# Vallas a los costados y abajo, en los colores de los equipos.
	var bcols: Array = board_colors if not board_colors.is_empty() else [Color(0.15, 0.3, 0.6), Color(0.75, 0.75, 0.8)]
	for k in range(14):
		var y0b: float = 0.02 + k * 0.14
		var bc: Color = (bcols[k % bcols.size()] as Color).darkened(0.15)
		_line_n(Vector2(-0.115, y0b), Vector2(-0.115, y0b + 0.125), bc, 5.0, 3)
		_line_n(Vector2(1.115, y0b), Vector2(1.115, y0b + 0.125), bc, 5.0, 3)
	for k in range(8):
		_line_n(Vector2(k / 8.0, 2.125), Vector2(k / 8.0 + 0.115, 2.125), (bcols[k % bcols.size()] as Color).darkened(0.15), 6.0, 2)
	# Tribuna detrás del arco: escalones + hinchas con los colores locales.
	var top_l: Vector2 = _pw(Vector2(-0.25, 0.0))
	var top_r: Vector2 = _pw(Vector2(1.25, 0.0))
	var stand_y1: float = top_l.y - 50.0
	var stand_y0: float = stand_y1 - TILT_TOP_EXTRA - 30.0
	draw_rect(Rect2(Vector2(-3000, stand_y0 - 1200), Vector2(size.x + 6000, stand_y1 - stand_y0 + 1200)), Color(0.10, 0.11, 0.14))
	for row in range(4):
		var ry: float = lerpf(stand_y0, stand_y1, float(row) / 4.0)
		draw_rect(Rect2(Vector2(top_l.x - 40, ry), Vector2(top_r.x - top_l.x + 80, 2)), Color(1, 1, 1, 0.05))
	if _crowd_cols.is_empty():
		var cols: Array = board_colors if not board_colors.is_empty() else [Color(0.15, 0.3, 0.6), Color(0.85, 0.85, 0.9)]
		for i in range(140):
			_crowd_cols.append(cols[rng.randi() % cols.size()].lerp(Color(0.6, 0.5, 0.45), rng.randf_range(0.0, 0.5)))
	var t: float = Time.get_ticks_msec() / 1000.0
	for i in range(_crowd_cols.size()):
		var hx: float = lerpf(top_l.x - 30.0, top_r.x + 30.0, fmod(float(i) * 0.6180339, 1.0))
		var hy: float = lerpf(stand_y0 + 4.0, stand_y1 - 6.0, fmod(float(i) * 0.37, 1.0))
		var bob: float = sin(t * 3.0 + float(i)) * (2.5 if _crowd_hype > 0.0 else 0.6)
		# LA OLA: cada tanto recorre la tribuna de punta a punta.
		bob -= _wave_lift((hx - top_l.x) / maxf(top_r.x - top_l.x, 1.0))
		draw_rect(Rect2(Vector2(hx, hy + bob), Vector2(4, 5)), _crowd_cols[i])
		draw_rect(Rect2(Vector2(hx + 1, hy + bob - 3), Vector2(2, 3)), Color(0.85, 0.7, 0.55))
	_draw_stand_life(Rect2(Vector2(top_l.x - 30.0, stand_y0), Vector2(top_r.x - top_l.x + 60.0, stand_y1 - stand_y0)))
	_draw_stand_tiles(top_l, top_r, stand_y0, stand_y1)

## OBJETOS DE ESTADIO (10-oct, Wilber: "usá más PixelLab... rellenar el
## estadio para que se vea más inmersiva la cancha"): bancos con suplentes,
## camarógrafos, fotógrafos, alcanzapelotas, guardias, torres de luz, la
## barra con el bombo y tribunas llenas. Arte en assets/stadium/ (generado
## con PixelLab, fuentes en art_src/pixellab/stadium/).
static var _prop_tex: Dictionary = {}
static func _prop(name: String) -> Texture2D:
	if not _prop_tex.has(name):
		var pth: String = "res://assets/stadium/%s.png" % name
		_prop_tex[name] = load(pth) if ResourceLoader.exists(pth) else null
	return _prop_tex[name]

## OBJETOS ANIMADOS (11-oct, PixelLab): si existe <nombre>_a0.png, _a1...
## el objeto se mueve (camarógrafo que panea, alcanzapelotas inquieto, la
## barra saltando). Devuelve [] si el objeto es una imagen fija.
static var _prop_anim: Dictionary = {}
static func _prop_frames(name: String) -> Array:
	if not _prop_anim.has(name):
		var fr: Array = []
		var i: int = 0
		while ResourceLoader.exists("res://assets/stadium/%s_a%d.png" % [name, i]):
			fr.append(load("res://assets/stadium/%s_a%d.png" % [name, i]))
			i += 1
		_prop_anim[name] = fr
	return _prop_anim[name]

## Cuadro actual de un objeto (`salt` desfasa a los que se repiten).
func _prop_now(name: String, fps: float, salt: float = 0.0) -> Texture2D:
	var fr: Array = _prop_frames(name)
	if fr.is_empty():
		return _prop(name)
	return fr[int(_live_t * fps + salt) % fr.size()]

## CAMILLA (11-oct, Wilber: "procede a full"): en una lesión los camilleros
## entran desde la banda hasta el jugador y se lo llevan. Paso de guion:
## {"stretcher": Vector2 | id} (coordenadas de la jugada).
var _str_on: bool = false
var _str_pos: Vector2 = Vector2.ZERO
var _str_from: Vector2 = Vector2.ZERO
var _str_to: Vector2 = Vector2.ZERO
var _str_moving: bool = false

## LÍNEAS DE TIRO (11-oct, Wilber: "que en la selección de tipo de tiro
## muestre cómo se ve la línea de tiro"). Cada una: {"curve": comba,
## "color": Color, "width": px}. Van de la pelota a `shot_preview_to`.
var shot_previews: Array = []
var shot_preview_to: Vector2 = Vector2(0.5, -0.03)

func set_shot_previews(list: Array, to: Vector2 = Vector2(0.5, -0.03)) -> void:
	shot_previews = list
	shot_preview_to = to
	queue_redraw()

## CARTEL DE CAMBIO (11-oct): {"id": actor que lo levanta, "out": "7", "in": "14"}.
var _board: Dictionary = {}
## Variante de tribuna del estadio (0 = la de siempre) y sus pancartas.
var stand_kind: int = 0
var _banner_seed: int = 1

## Resultado en vivo para el marcador del estadio (lo pone Match).
var score_text: String = ""

## Dibuja un objeto apoyado en el punto `world` de la cancha.
func _draw_prop(name: String, world: Vector2, flip: bool = false, lift: float = 0.0, mod: Color = Color.WHITE, fps: float = 0.0) -> void:
	var tex: Texture2D = _prop_now(name, fps, world.x * 7.0 + world.y * 3.0) if fps > 0.0 else _prop(name)
	if tex == null:
		return
	var base: Vector2 = _pw(world)
	var sz: Vector2 = tex.get_size()
	var rect := Rect2(base - Vector2(sz.x * 0.5, sz.y - 4.0 + lift), sz)
	if flip:
		rect = Rect2(rect.position, Vector2(-sz.x, sz.y))   # ancho negativo = espejado EN EL LUGAR (sumarle el ancho lo corría un cuerpo a la derecha)
	draw_texture_rect(tex, rect, false, mod)
	if name == "scoreboard" and score_text != "":
		# El resultado, en la pantalla del marcador.
		var font: Font = Styles.font_black()
		var tw: float = font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, Vector2(base.x - tw * 0.5, base.y - sz.y * 0.5 + 4.0 - lift), score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.86, 0.3))

## Los objetos parados alrededor de la cancha, como lista: cada uno se
## dibuja en el MISMO pase que los jugadores, ordenado por profundidad
## (11-oct, Wilber: "los jugadores traspasan todo y los cámaras están
## detrás de las líneas"). Causa: se pintaban como parte del fondo, antes
## que las líneas (que les pasaban por encima) y antes que TODOS los
## jugadores (que los pisaban aunque estuvieran más lejos).
func _prop_items() -> Array:
	var out: Array = []
	var hype: bool = _crowd_hype > 0.0
	for c in [Vector2(-0.19, -0.02), Vector2(1.19, -0.02), Vector2(-0.19, 2.09), Vector2(1.19, 2.09)]:
		out.append({"name": "tower", "w": c})
	out.append({"name": "dugout", "w": Vector2(-0.105, 0.80)})
	out.append({"name": "dugout", "w": Vector2(-0.105, 1.27)})
	for c in [Vector2(1.09, 1.0), Vector2(1.09, 0.34), Vector2(1.09, 1.66), Vector2(0.25, -0.05), Vector2(0.75, 2.105)]:
		out.append({"name": "cameraman", "w": c, "flip": (c as Vector2).x < 0.5, "fps": 5.0})
	# 11-oct: marcador detrás del arco de arriba, túnel entre los bancos y
	# los camilleros esperando del otro lado.
	out.append({"name": "scoreboard", "w": Vector2(0.86, -0.115)})
	out.append({"name": "tunnel", "w": Vector2(-0.125, 1.045)})
	out.append({"name": "medics", "w": Vector2(1.10, 1.32), "flip": true})
	for sx in [0.09, 0.17, 0.83, 0.91]:
		for gy in [-0.03, 2.075]:
			out.append({"name": "photographer", "w": Vector2(sx, gy), "flip": sx < 0.5,
				"flash": _flash_on(sx * 31.0 + gy * 7.0, 0.06 if hype else 0.012)})
	var kid: int = 0
	for c in [Vector2(-0.05, 0.25), Vector2(1.05, 0.55), Vector2(-0.05, 1.45), Vector2(1.05, 1.75), Vector2(-0.04, 0.03), Vector2(1.04, 1.97)]:
		out.append({"name": "ballboy", "w": c, "flip": (c as Vector2).x > 0.5, "lift": absf(sin(_live_t * 8.0 + kid)) * 3.0 if hype else 0.0, "fps": 6.0})
		kid += 1
	for k in range(7):
		var sy: float = 0.10 + k * 0.30
		out.append({"name": "steward", "w": Vector2(-0.128, sy)})
		out.append({"name": "steward", "w": Vector2(1.128, sy), "flip": true})
	return out

## Tribunas llenas: mosaico del arte de público (solo las filas de gente,
## sin la esquina de pasto que trae el dibujo) detrás del arco de arriba, a
## los costados y abajo; y la barra con bombo y bandera saltando.
func _draw_stand_tiles(top_l: Vector2, top_r: Vector2, stand_y0: float, stand_y1: float) -> void:
	var tex: Texture2D = _prop("crowd")
	# Tribuna de fondo según el estadio (arte de PixelLab; se usa solo la
	# franja de la tribuna, sin el cielo ni el pasto del dibujo).
	var big: Texture2D = null
	var bsrc := Rect2()
	if stand_kind == 1:
		big = _prop("stand_roof")
		bsrc = Rect2(0, 8, 128, 72)
	elif stand_kind == 2:
		big = _prop("stand_modern")
		bsrc = Rect2(0, 12, 128, 78)
	if big != null:
		var night_mod: Color = Color(0.62, 0.64, 0.78) if night else Color.WHITE
		var bx0: float = top_l.x - 96.0
		while bx0 < top_r.x + 96.0:
			draw_texture_rect_region(big, Rect2(Vector2(bx0, stand_y1 - bsrc.size.y), bsrc.size), bsrc, night_mod)
			bx0 += 128.0
	if tex != null:
		var src := Rect2(0, 0, 100, 40)
		var x: float = top_l.x - 60.0
		while big == null and x < top_r.x + 60.0:
			draw_texture_rect_region(tex, Rect2(Vector2(x, stand_y1 - 40.0), Vector2(100, 40)), src, Color(0.86, 0.86, 0.9))
			draw_texture_rect_region(tex, Rect2(Vector2(x + 50.0, stand_y1 - 78.0), Vector2(100, 40)), src, Color(0.66, 0.66, 0.72))
			x += 100.0
		for k in range(13):
			var wy: float = -0.12 + k * 0.19
			for wx in [-0.30, 1.30]:
				var c: Vector2 = _pw(Vector2(wx, wy))
				draw_texture_rect_region(tex, Rect2(c - Vector2(50, 20), Vector2(100, 40)), src, Color(0.74, 0.74, 0.8))
		var bl: Vector2 = _pw(Vector2(-0.35, 2.25))
		var br2: Vector2 = _pw(Vector2(1.35, 2.25))
		var bx: float = bl.x
		while bx < br2.x:
			draw_texture_rect_region(tex, Rect2(Vector2(bx, bl.y - 12.0), Vector2(100, 40)), src, Color(0.8, 0.8, 0.86))
			bx += 100.0
	_draw_banners(top_l, top_r, stand_y1)
	var ut: Texture2D = _prop("ultras")
	if ut != null:
		var tint: Color = (board_colors[0] as Color).lerp(Color.WHITE, 0.45) if not board_colors.is_empty() else Color.WHITE
		for k in range(3):
			var ux: float = lerpf(top_l.x, top_r.x, 0.2 + 0.3 * k)
			var hop: float = absf(sin(_live_t * (9.0 if _crowd_hype > 0.0 else 4.0) + k * 1.3)) * (5.0 if _crowd_hype > 0.0 else 2.0)
			var utex: Texture2D = _prop_now("ultras", 11.0 if _crowd_hype > 0.0 else 6.0, k * 3.0)
			draw_texture_rect(utex, Rect2(Vector2(ux - 32.0, stand_y1 - 44.0 - hop), Vector2(64, 48)), false, tint)

## PANCARTAS colgadas del frente de la tribuna: telas en los colores del
## local, con frases genéricas (nada de nombres reales). Cuáles y dónde
## salen del estadio, así cada cancha tiene las suyas.
const _BANNER_TEXTS := ["VAMOS EQUIPO", "SIEMPRE CONTIGO", "LA 12", "AGUANTE", "LOCALES", "ESTA ES TU CASA", "HASTA EL FINAL", "CORAZÓN Y GARRA", "LA BANDA", "FIELES"]
func _draw_banners(top_l: Vector2, top_r: Vector2, stand_y1: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _banner_seed
	var cols: Array = board_colors if not board_colors.is_empty() else [Color(0.15, 0.3, 0.6), Color(0.85, 0.85, 0.9)]
	var font: Font = Styles.font_black()
	var count: int = 3 + rng.randi() % 3
	var span: float = top_r.x - top_l.x
	for k in range(count):
		var txt: String = _BANNER_TEXTS[rng.randi() % _BANNER_TEXTS.size()]
		var base_c: Color = cols[0] if rng.randf() < 0.7 else Color(0.93, 0.93, 0.9)
		var ink: Color = Color(0.97, 0.97, 0.95) if base_c.get_luminance() < 0.55 else (cols[0] as Color).darkened(0.2)
		var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 12.0
		var cx: float = top_l.x + span * (float(k) + 0.5 + rng.randf_range(-0.25, 0.25)) / float(count)
		var y: float = stand_y1 - 15.0 - float(rng.randi() % 3) * 13.0
		# La tela cuelga y se mueve apenas con el viento.
		var sway: float = sin(_live_t * 1.4 + float(k) * 1.7) * 1.2
		var pts := PackedVector2Array([Vector2(cx - w * 0.5, y), Vector2(cx + w * 0.5, y), Vector2(cx + w * 0.5 + sway, y + 12.0), Vector2(cx - w * 0.5 + sway, y + 12.0)])
		draw_colored_polygon(pts, base_c.darkened(0.08))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0, 0.5), 1.0)
		draw_string(font, Vector2(cx - w * 0.5 + 6.0 + sway * 0.5, y + 9.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ink)

## La tribuna se agita (gol, ocasión): lo prende Match.
var _crowd_hype: float = 0.0
func crowd_hype(secs: float = 3.0) -> void:
	_crowd_hype = secs
	_update_processing()

func _draw_weather_ground(f: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	if weather == "rain":
		for i in range(9):
			var c := Vector2(f.position.x + rng.randf_range(0.08, 0.92) * f.size.x, f.position.y + rng.randf_range(0.1, 0.95) * f.size.y)
			var w: float = rng.randf_range(0.05, 0.11) * f.size.x
			draw_set_transform(_cam_offset() + c * cam_zoom, 0.0, Vector2(cam_zoom, cam_zoom * 0.45))
			draw_circle(Vector2.ZERO, w, Color(0.35, 0.55, 0.75, 0.32))
			draw_circle(Vector2(-w * 0.25, -w * 0.15), w * 0.35, Color(0.85, 0.92, 1.0, 0.16))
		draw_set_transform(_cam_offset(), 0.0, Vector2(cam_zoom, cam_zoom))
	else:
		for i in range(12):
			var c2 := Vector2(f.position.x + rng.randf_range(0.0, 1.0) * f.size.x, f.position.y + rng.randf_range(0.0, 1.0) * f.size.y)
			var w2: float = rng.randf_range(0.06, 0.14) * f.size.x
			draw_set_transform(_cam_offset() + c2 * cam_zoom, 0.0, Vector2(cam_zoom, cam_zoom * 0.5))
			draw_circle(Vector2.ZERO, w2, Color(0.95, 0.97, 1.0, 0.30))
		draw_set_transform(_cam_offset(), 0.0, Vector2(cam_zoom, cam_zoom))
		for i in range(140):
			draw_rect(Rect2(Vector2(f.position.x + rng.randf() * f.size.x, f.position.y - 40.0 + rng.randf() * (f.size.y + 40.0)), Vector2(2, 2)), Color(1, 1, 1, 0.5))

static var _glow_tex: GradientTexture2D = null
static func _glow() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.96, 0.80, 0.20))
		g.set_color(1, Color(1.0, 0.97, 0.86, 0.0))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 128
		_glow_tex.height = 128
	return _glow_tex

func _draw_floodlights(f: Rect2) -> void:
	# Noche: todo más oscuro y azulado…
	draw_rect(Rect2(Vector2(-3000, -3000), size + Vector2(6000, 6000)), Color(0.0, 0.02, 0.09, 0.55))
	# …y cuatro charcos de luz de los reflectores, más uno suave al centro.
	var tex := _glow()
	var big: float = f.size.x * 0.95
	for c in [f.position, Vector2(f.end.x, f.position.y), Vector2(f.position.x, f.end.y), f.end]:
		var cc: Vector2 = (c as Vector2).lerp(f.get_center(), 0.18)
		draw_texture_rect(tex, Rect2(cc - Vector2(big, big) * 0.5, Vector2(big, big)), false)
	draw_texture_rect(tex, Rect2(f.get_center() - Vector2(big, big) * 0.4, Vector2(big, big) * 0.8), false, Color(1, 1, 1, 0.45))
	# Torres en las puntas de las vallas.
	# Sobre las esquinas del FONDO y siempre dentro de la pantalla (con la
	# cancha ensanchada, f.position.x queda fuera).
	for x in [_pw(Vector2(0.0, 0.0)).x - 16.0, _pw(Vector2(1.0, 0.0)).x + 16.0]:
		var lp := Vector2(x, f.position.y - 50.0)
		draw_line(lp + Vector2(0, 4), lp + Vector2(0, 46), Color(0.32, 0.34, 0.38), 3.0)
		draw_rect(Rect2(lp - Vector2(10, 5), Vector2(20, 9)), Color(0.18, 0.2, 0.24))
		for k in range(3):
			draw_circle(lp + Vector2(-6 + k * 6, 0), 2.4, Color(1, 1, 0.88))
		draw_texture_rect(tex, Rect2(lp - Vector2(34, 34), Vector2(68, 68)), false)

## Dibuja los nombres sin que se pisen. Cada label = [texto, punto base
## (centro, línea de base) bajo los pies, es_usuario, y de la cabeza]. El
## usuario va primero; si un nombre choca con uno ya puesto prueba una línea
## más abajo y después arriba de la cabeza; si no entra, no se dibuja.
func _draw_labels(labels: Array, font: Font) -> void:
	# Con la cámara alejada la letra se agranda para que en pantalla mida lo
	# mismo; muy lejos, solo queda tu nombre.
	var FS: int = int(clampf(roundf(11.0 / maxf(cam_zoom, 0.1)), 11.0, 26.0))
	if cam_zoom < 0.5:
		labels = labels.filter(func(l): return bool(l[2]))
	labels.sort_custom(func(a, b): return bool(a[2]) and not bool(b[2]))
	var placed: Array = []
	for l in labels:
		var w: float = font.get_string_size(String(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
		var base: Vector2 = l[1]
		var tries: Array = [base, base + Vector2(0, FS + 2), Vector2(base.x, float(l[3]))]
		var chosen = null
		for t in tries:
			var rect := Rect2(Vector2(t.x - w * 0.5 - 2.0, t.y - FS), Vector2(w + 4.0, FS + 3.0))
			var hit := false
			for q in placed:
				if (q as Rect2).intersects(rect):
					hit = true
					break
			if not hit:
				chosen = t
				placed.append(rect)
				break
		if chosen == null:
			continue
		var pos: Vector2 = (chosen as Vector2) + Vector2(-w * 0.5, 0)
		var col: Color = Color(1.0, 0.88, 0.35) if bool(l[2]) else Color.WHITE
		draw_string_outline(font, pos, String(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, FS, 4, Color(0, 0, 0, 0.75))
		draw_string(font, pos, String(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, FS, col)
## Indicador de fuerza junto a la pelota (apagado: la fuerza es la barra).
var aim_power_gauge: bool = false
var _aim_t: float = 0.0
var _aim_speed: float = 2.0
var _aim_drag: bool = false
var _aim_from: Vector2 = Vector2.ZERO     # px, donde empezó el arrastre
var _aim_to: Vector2 = Vector2.ZERO       # px, dedo ahora
var _aim_band: float = 0.15               # medio ancho de la banda de fuerza (para dibujarla)
const AIM_POWER_SPAN := 0.42              # arrastre de este largo (en altos de cancha) = fuerza 1.0

## CÁMARA (9-oct, Wilber: "acercar más la cámara para que los minijuegos
## sean más cómodos"): zoom suave sobre la zona de la acción. Todo el
## dibujo de la cancha pasa por draw_set_transform; los toques se pasan por
## _unzoom() para que "tocar una ficha" siga funcionando con zoom.
var cam_zoom: float = 1.0
var cam_focus: Vector2 = Vector2(0.5, 0.5)   # punto de la cancha (MUNDO) en el centro de la pantalla
var _cam_tween: Tween = null

## Minijuegos interactivos (pase/regate/defensa/arquero) — PitchMinigame.
signal minigame_done(result: Dictionary)
var _mg: PitchMinigame = null

## Paquete 5: actores con SPRITE animado (árbitro). Un actor con "anims"
## ({nombre: [Texture2D...]}) se dibuja como personaje en vez de ficha.
var _has_sprites: bool = false
const SPRITE_FPS := 10.0
## Jugadores y arqueros en pixel art (9-oct, tools/pitch_sprites.py): cada
## ficha de jugador se dibuja con el sprite de PixelLab teñido con el color
## del equipo (camiseta) + piel/pelo propios. Los cuadros se arman a pedido
## (Avatar.anim_frames, cacheado) — no se tiñen 80 cuadros por jugador al
## armar la escena, solo los que de verdad se ven.
const DIRS8 := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
const _SKINS := ["#f4d6c0", "#eec1a3", "#d9a577", "#b57e56", "#8a5a3b", "#5f3a26"]
const _HAIRS := ["#2b2320", "#5a3b26", "#8a5a3b", "#c98f4b", "#d8c07a", "#2b2320"]
const _BOOTS := ["#2b2b30", "#e8b923", "#3ee03a", "#ff4fa3", "#2e7bff", "#ff6a1a", "#d81e2a"]
var use_player_sprites: bool = true
## Diseño de camiseta por equipo (color.to_html → {"w": int, "sec": hex}):
## los jugadores visten las rayas/cuadros del kit (plantillas de Wilber).
var team_kits: Dictionary = {}
## Textura del balón del partido (BallDesign.texture); null = círculo.
var ball_texture: Texture2D = null

## id -> {pos: Vector2, color: Color, text: Color, num: String, name: String,
##        user: bool}
var _actors: Dictionary = {}
var _ball: Vector2 = Vector2(0.5, 0.5)
var _ball_h: float = 0.0          # altura del balón (vuelo), en radios de ficha
var _ball_spin: float = 0.0       # giro acumulado (radianes)
var _ball_prev_px: Vector2 = Vector2.ZERO
var _ball_visible: bool = true
var _field: Rect2 = Rect2()
var _tween: Tween = null
var _flash: Label = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
	_flash = Label.new()
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.add_theme_font_override("font", Styles.font_semibold())
	_flash.add_theme_font_size_override("font_size", 40)
	_flash.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_flash.add_theme_constant_override("outline_size", 10)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.visible = false
	add_child(_flash)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)

func set_weather(kind: String) -> void:
	_weather = kind
	_wx_drops.clear()
	if kind == "rain" or kind == "snow":
		var r := RandomNumberGenerator.new()
		r.seed = 7
		for i in range(70 if kind == "rain" else 55):
			_wx_drops.append(Vector3(r.randf(), r.randf(), r.randf_range(0.6, 1.4)))
	_update_processing()
	queue_redraw()

## Activa/desactiva elegir tocando. `targets`: qué se resalta.
func set_interactive(on: bool, targets: Array = []) -> void:
	_interactive = on
	_targets = targets if on else []
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_update_processing()
	queue_redraw()

func _update_processing() -> void:
	set_process(_interactive or not _wx_drops.is_empty() or _has_sprites or _aim_mode or _mg != null or _crowd_hype > 0.0 or ambient)

# --- Cámara ------------------------------------------------------------

## Desplazamiento de pantalla de la cámara actual (px).
func _cam_offset() -> Vector2:
	return size * 0.5 - _pw(cam_focus) * cam_zoom

## Punto de pantalla → punto de la cancha SIN zoom (lo que esperan _p y
## target_at).
func _unzoom(px: Vector2) -> Vector2:
	return (px - _cam_offset()) / cam_zoom

## CÁMARA LIBRE (10-oct, cancha completa): `cam_focus` va en coordenadas de
## MUNDO y el zoom puede ALEJARSE (< 1) hasta ver la cancha entera. Mientras
## `_cam_home` está prendido la cámara es el encuadre "de la jugada"
## (_home_cam), recalculado en cada dibujo — así no depende de que el
## control ya tenga tamaño cuando se arma la escena.
const ZOOM_MIN := 0.22
## Lo más cerca que se puede acercar (10-oct, Wilber: "limitá el zoom para
## que no se salga de todo ni que esté tan cerca"). Lo más lejos = la cancha
## entera en pantalla (_whole_fit), ni un paso más.
const ZOOM_MAX := 1.5
var _cam_home: bool = true

## Encuadre de la jugada: [zoom, foco en MUNDO].
func _home_cam() -> Array:
	# La cámara SIGUE la jugada (pelota + vos), sin zoom: píxeles nítidos.
	return [1.0, _clamp_focus(1.0, _follow)]

## Punto (MUNDO) que la cámara persigue: la pelota, tirando un poco hacia
## vos y — si la jugada es cerca del arco — hacia el arco.
var _follow: Vector2 = Vector2(0.5, 0.5)
func _follow_target() -> Vector2:
	if ambient:
		return _w(_ball)
	if not _ball_visible:
		# Sin pelota en la jugada (un cambio, una tarjeta): al medio de los
		# que participan.
		var sum := Vector2.ZERO
		var cnt: int = 0
		for id in _actors:
			if not bool(_actors[id].get("extra", false)):
				sum += _actors[id]["pos"]
				cnt += 1
		if cnt > 0:
			return _w(sum / float(cnt))
	var tgt: Vector2 = _ball
	if _actors.has("user"):
		tgt = _ball.lerp(_actors["user"]["pos"], 0.35)
	if tgt.y < 0.36:
		tgt = tgt.lerp(Vector2(0.5, 0.0), 0.35)   # el arco entra en cuadro
	return _w(tgt)

func _cam_sync() -> void:
	if _cam_home and not (_cam_tween != null and _cam_tween.is_valid() and _cam_tween.is_running()):
		var h: Array = _home_cam()
		cam_zoom = float(h[0])
		cam_focus = h[1]

func _clamp_focus(zoom: float, f: Vector2) -> Vector2:
	if cam_mode == "arco" and _field.size.x > 1.0:
		# La vista no se sale de la cancha: cuanto más lejos, menos se puede
		# correr el foco; con la cancha entera en pantalla queda centrada.
		var hx: float = 0.5 * size.x / maxf(zoom * _field.size.x * 0.9, 1.0)
		var hy: float = 0.5 * size.y / maxf(zoom * _field.size.y, 1.0)
		var fx: float = 0.5 if hx >= 0.67 else clampf(f.x, hx - 0.17, 1.17 - hx)
		var fy: float = 1.0 if hy >= 1.10 else clampf(f.y, hy - 0.34, 2.23 - hy)
		return Vector2(fx, fy)
	return Vector2(clampf(f.x, 0.0, 1.0), clampf(f.y, 0.0, 2.0))

## Mueve la cámara. `focus_w` en coordenadas de MUNDO.
func _cam_to(zoom: float, focus_w: Vector2, animated: bool) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_home = false
	zoom = clampf(zoom, minf(float(_whole_fit()[0]), 1.0), ZOOM_MAX)
	var f: Vector2 = _clamp_focus(zoom, focus_w)
	if not animated:
		cam_zoom = zoom
		cam_focus = f
		queue_redraw()
		return
	_cam_tween = create_tween().set_parallel(true)
	_cam_tween.tween_property(self, "cam_zoom", zoom, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(self, "cam_focus", f, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_method(func(_v): queue_redraw(), 0.0, 1.0, 0.45)

## `focus` en coordenadas de ESCENA (las de la jugada).
func set_camera(zoom: float, focus: Vector2, animated: bool = true) -> void:
	_cam_to(zoom, _w(focus), animated)

## Vuelve al encuadre de la jugada.
func reset_camera(animated: bool = true) -> void:
	if not animated or size.x < 2.0:
		if _cam_tween != null and _cam_tween.is_valid():
			_cam_tween.kill()
		_cam_home = true
		queue_redraw()
		return
	_layout_field()
	var h: Array = _home_cam()
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel(true)
	_cam_tween.tween_property(self, "cam_zoom", float(h[0]), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(self, "cam_focus", h[1], 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_method(func(_v): queue_redraw(), 0.0, 1.0, 0.45)
	_cam_home = true

## Toda la cancha en pantalla (botón "ver todo").
func show_whole_pitch(animated: bool = true) -> void:
	_layout_field()
	var fit: Array = _whole_fit()
	_cam_to(float(fit[0]), fit[1], animated)

## [zoom, foco] con el que entra TODA la cancha en pantalla.
func _whole_fit() -> Array:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for q in [Vector2(0, -0.06), Vector2(1, -0.06), Vector2(0, 2.06), Vector2(1, 2.06), Vector2(0, 1), Vector2(1, 1)]:
		var px: Vector2 = _pw(q)
		mn = Vector2(minf(mn.x, px.x), minf(mn.y, px.y))
		mx = Vector2(maxf(mx.x, px.x), maxf(mx.y, px.y))
	mn -= Vector2(10, 40)
	mx += Vector2(10, 10)
	var z: float = minf(size.x / maxf(mx.x - mn.x, 1.0), size.y / maxf(mx.y - mn.y, 1.0))
	return [maxf(z, ZOOM_MIN), _from_px_w((mn + mx) * 0.5)]

## ¿La cámara está en el encuadre de la jugada?
func cam_is_home() -> bool:
	return _cam_home

## Zoom que encuadra a estos actores (+ la pelota), con margen.
func focus_on(ids: Array, extra_points: Array = [], zoom_max: float = 2.0, with_ball: bool = true) -> void:
	var pts: Array = extra_points.duplicate()
	if with_ball:
		pts.append(_ball)
	for id in ids:
		if _actors.has(id):
			pts.append(_actors[id]["pos"])
	if pts.is_empty():
		return
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in pts:
		var q: Vector2 = _w(p)
		mn = Vector2(minf(mn.x, q.x), minf(mn.y, q.y))
		mx = Vector2(maxf(mx.x, q.x), maxf(mx.y, q.y))
	var span: Vector2 = (mx - mn) + Vector2(0.18, 0.18)
	var z: float = clampf(minf(1.0 / span.x, 1.0 / span.y), 1.5, zoom_max)
	var c: Vector2 = (mn + mx) * 0.5
	# Los zooms que piden las jugadas son de la cancha "de pantalla"; con la
	# cancha grande equivalen a ~1 (sin escalar el pixel art).
	_cam_to(clampf(z / WORLD_SCALE, 1.0, 1.3), c, true)

# --- API para PitchMinigame (coordenadas de ESCENA) ---
func has_actor(id: String) -> bool:
	return _actors.has(id)

func npos(id: String) -> Vector2:
	return _actors[id]["pos"] if _actors.has(id) else Vector2(0.5, 0.5)

func set_npos(id: String, v: Vector2) -> void:
	if _actors.has(id):
		_actors[id]["pos"] = v

func nball() -> Vector2:
	return _ball

func set_nball(v: Vector2) -> void:
	_ball = v

func to_px(n: Vector2) -> Vector2:
	return _p(n)

## Punto de la jugada → píxel de PANTALLA (con la cámara aplicada): donde
## hay que tocar para darle a ese punto.
func to_screen(n: Vector2) -> Vector2:
	return _p(n) * cam_zoom + _cam_offset()

## Los titulares de verdad (los pone Match): {"us": [...], "them": [...],
## "our_gk": {}, "their_gk": {}} con num / name / look / pos / speed. Los
## jugadores de relleno toman su cara, su número y su ritmo.
var team_people: Dictionary = {}

## Opciones del motor para la oportunidad en vivo (las lee PitchMinigame).
var live_options: Array = []
## Desmarque antes de recibir (la jugada viene de un pase tuyo) y velocidad
## de tu jugador en unidades de cancha por segundo (los pone Match).
var live_run: bool = false
var live_run_speed: float = 0.14

## Dónde está cada uno AHORA (para que el final de la jugada arranque desde
## ahí y no desde la formación de libreto).
func actor_positions() -> Dictionary:
	var out := {}
	for id in _actors:
		if not bool(_actors[id].get("extra", false)):
			out[id] = (_actors[id]["pos"] as Vector2) - (_actors[id].get("ai_off", Vector2.ZERO) as Vector2)
	return out

## Pone a un jugador a correr hacia el arco de la jugada (o lo frena). Lo
## usan los minijuegos que mueven gente (paredes).
func set_running(id: String, on: bool) -> void:
	if not _actors.has(id) or not _actors[id].has("sprite"):
		return
	_actors[id]["face"] = "north"
	_set_anim(id, ("run_" + _screen_face("north")) if on else "idle", true)

## Arranca un minijuego interactivo sobre la jugada que ya está armada.
func start_minigame(mode: String, kind: String, difficulty: float, speed_mod: float) -> PitchMinigame:
	stop_minigame()
	_mg = PitchMinigame.new()
	_mg.done.connect(func(r: Dictionary):
		_mg = null
		mouse_filter = Control.MOUSE_FILTER_STOP if _interactive else Control.MOUSE_FILTER_IGNORE
		_update_processing()
		queue_redraw()
		minigame_done.emit(r))
	_mg.start(self, mode, kind, difficulty, speed_mod)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_processing()
	return _mg

func stop_minigame() -> void:
	if _mg != null:
		_mg.finished = true
		_mg = null
		_update_processing()

## Arranca el minijuego de remate. `speed_mod` = el mismo factor de clima
## que acelera la barra clásica; `band` solo para dibujar la zona de fuerza.
func start_shot_aim(difficulty: float, speed_mod: float, band: float) -> void:
	if not _actors.has("gk"):
		return
	_aim_mode = true
	_aim_drag = false
	_aim_t = randf() * TAU
	_aim_speed = lerpf(1.4, 3.2, clampf(difficulty, 0.0, 1.0)) * speed_mod
	_aim_band = band
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_processing()

func stop_shot_aim() -> void:
	_aim_mode = false
	_aim_drag = false
	mouse_filter = Control.MOUSE_FILTER_STOP if _interactive else Control.MOUSE_FILTER_IGNORE
	_update_processing()
	queue_redraw()

## Punto del arco (x normalizada sobre la línea de gol) al que apuntás.
## 9-oct (Wilber: "no apunto a donde disparar, siempre apunta al medio"):
## antes salía del ÁNGULO del arrastre, y como el arco es angosto frente a
## la distancia a la pelota, casi cualquier arrastre caía al medio. Ahora el
## arrastre HORIZONTAL mueve la mira de palo a palo (y un poco más allá =
## afuera) y el VERTICAL es la fuerza — control directo con el dedo.
const AIM_X_SPAN := 0.22          # arrastre lateral (en anchos de cancha) para llegar al palo
func _aim_goal_x() -> float:
	if cam_mode == "arco" and not _plain():
		# Jugada espejada o en tu mitad (11-oct): el arrastre es el MISMO de
		# siempre — a la izquierda de la pantalla apunta al palo que se ve a
		# la izquierda — solo cambia a qué lado de la jugada corresponde.
		# (Antes este caso caía en la fórmula de las otras cámaras, que
		# pedía un arrastre 30% más largo.)
		var sgn: float = 1.0 if _p(Vector2(1.0, 0.0)).x >= _p(Vector2(0.0, 0.0)).x else -1.0
		var dxm: float = (_aim_to.x - _aim_from.x) / maxf(1.0, aim_span_x()) * sgn
		return 0.5 + clampf(dxm, -1.2, 1.2) * (GOAL_W * 0.5)
	if not _plain():
		# Se apunta arrastrando A LO LARGO de la línea de gol, vaya como vaya en pantalla.
		var g0: Vector2 = _p(Vector2(0.0, 0.0))
		var g1: Vector2 = _p(Vector2(1.0, 0.0))
		var gd: Vector2 = g1 - g0
		var along: float = (_aim_to - _aim_from).dot(gd.normalized()) / maxf(1.0, gd.length() / WORLD_SCALE * AIM_X_SPAN * 1.3)
		return 0.5 + clampf(along, -1.2, 1.2) * (GOAL_W * 0.5)
	var dx: float = (_aim_to.x - _aim_from.x) / maxf(1.0, aim_span_x())
	return 0.5 + clampf(dx, -1.2, 1.2) * (GOAL_W * 0.5)

func _aim_power() -> float:
	return maxf(0.0, _aim_from.y - _aim_to.y) / maxf(1.0, aim_span_y())

## Largo (px sin zoom) del arrastre que lleva la mira al palo / da fuerza 1.
func aim_span_x() -> float:
	return _field.size.x / WORLD_SCALE * AIM_X_SPAN

func aim_span_y() -> float:
	return _field.size.y / WORLD_SCALE * AIM_POWER_SPAN

## Píxel (sin zoom) → coordenada normalizada de la cancha (inversa de _p).
func from_px(px: Vector2) -> Vector2:
	return _wi(_from_px_w(px))

func _from_px_w(px: Vector2) -> Vector2:
	if cam_mode == "tv":
		var tr: Rect2 = _tv_rect()
		var tt: float = (px.y - tr.position.y) / maxf(tr.size.y, 1.0)
		var a2: float = 1.0 - TV_FAR
		var v: float = (-TV_FAR + sqrt(maxf(TV_FAR * TV_FAR + 4.0 * a2 * tt, 0.0))) / (2.0 * a2)
		var s: float = lerpf(TV_FAR, 1.0, clampf(v, -0.3, 1.3))
		var u: float = 0.5 + (px.x - tr.position.x - tr.size.x * 0.5) / maxf(tr.size.x * TV_WIDTH * s, 1.0)
		return Vector2(v, 1.0 - u)
	if cam_mode == "iso":
		var k: float = _iso_k()
		var o: Vector2 = _iso_origin()
		var aa: float = (px.x - o.x) / maxf(k, 0.001)
		var bb: float = (px.y - o.y) / maxf(k * 0.5, 0.001)
		return Vector2((aa + bb) / 136.0, (bb - aa) / 105.0)
	var t: float = (px.y - _field.position.y) / maxf(_field.size.y, 1.0)
	var y: float = t
	var a: float = 1.0 - TILT_FAR
	var b: float = TILT_FAR
	if tilt and a > 0.001:
		if t <= 1.0:
			y = (-b + sqrt(maxf(b * b + 4.0 * a * t, 0.0))) / (2.0 * a)
		else:
			y = 2.0 - (-b + sqrt(maxf(b * b + 4.0 * a * (2.0 - t), 0.0))) / (2.0 * a)
	var cx: float = _field.position.x + _field.size.x * 0.5
	var x: float = 0.5 + (px.x - cx) / maxf(_field.size.x * _depth(y), 1.0)
	return Vector2(x, y)

## Jugadores de RELLENO (9-oct, Wilber: "la cancha se ve un poco vacía"):
## compañeros y rivales quietos en el resto de la media cancha, lejos de la
## jugada. Solo decorado: no se tocan, no tienen la pelota, no se mueven.
const EXTRAS_PER_TEAM := 7   # 10-oct: cancha completa (antes 4 en media cancha)
var extras_enabled: bool = true

func _add_extras(scene: Dictionary) -> void:
	if not extras_enabled or not use_player_sprites:
		return
	_amb_us = scene.get("us", null)
	var us_col = null
	var them_col = null
	var us_n: int = 0
	var them_n: int = 0
	var has_gk_us: bool = false
	var has_gk_them: bool = false
	for a in scene.get("actors", []):
		if bool(a.get("ref", false)):
			continue
		var c: Color = a.get("color", Color.WHITE)
		if String(a["id"]) == "gk" or bool(a.get("gk", false)):
			if c == PitchPlays.GK_US:
				has_gk_us = true
			else:
				has_gk_them = true
			continue
		if bool(a.get("user", false)) or String(a["id"]).begins_with("m"):
			us_col = c if us_col == null else us_col
			us_n += 1
		else:
			them_col = c if them_col == null else them_col
			them_n += 1
	# Juego ambiental: los colores vienen dados (puede no haber nadie tuyo).
	if us_col == null and scene.get("us", null) != null:
		us_col = scene["us"]
	if them_col == null and scene.get("them", null) != null:
		them_col = scene["them"]
	if us_col == null and them_col == null:
		return
	# Jugadas con un solo equipo a la vista (un cambio, una tarjeta): no se
	# inventa al otro.
	var ball_w: Vector2 = _w(_resolve_target(scene.get("ball", Vector2(0.5, 0.5)))) if scene.get("ball", null) != null else Vector2(0.5, 1.0)
	# El bloque de cada equipo acompaña a la pelota (sube o baja con ella).
	var shift: float = (clampf(ball_w.y, 0.1, 1.9) - 1.0) * 0.50
	var n: int = 0
	for team in [[us_col, "us", us_n], [them_col, "them", them_n]]:
		if team[0] == null:
			continue
		# 4-4-2 en coordenadas de MUNDO. Los tuyos defienden el arco de
		# abajo (y=2); los rivales, el de arriba.
		var slots: Array = []
		var ours: bool = team[1] == "us"
		# JUEGO ORGANIZADO (11-oct, Wilber: "organizar el juego con respecto
		# al gameplay de partido"). Causa del desorden: los dos equipos usaban
		# EL MISMO dibujo espejado, así que tus volantes caían exactamente
		# sobre sus delanteros (y tus delanteros sobre sus volantes): se veían
		# parejas de jugadores encimados. Ahora cada equipo tiene sus alturas
		# y anchos, intercalados con los del otro.
		var shape: Array = [[1.66, [0.14, 0.38, 0.62, 0.86]], [1.27, [0.12, 0.37, 0.63, 0.88]], [0.88, [0.38, 0.62]]]
		if not ours:
			shape = [[1.70, [0.17, 0.41, 0.59, 0.83]], [1.36, [0.08, 0.31, 0.69, 0.92]], [1.00, [0.27, 0.73]]]
		for line in shape:
			for sx in line[1]:
				var wy: float = float(line[0]) if ours else 2.0 - float(line[0])
				slots.append(Vector2(float(sx), clampf(wy + shift, 0.12, 1.88)))
		# Los que YA están en la jugada ocupan el puesto más cercano.
		var taken: Array = []
		for id in _actors:
			var ad: Dictionary = _actors[id]
			if bool(ad.get("ref", false)) or bool(ad.get("extra", false)) or bool(ad.get("keeper", false)) or id == "gk":
				continue
			var belongs: bool = (bool(ad["user"]) or String(id).begins_with("m")) == ours
			if id == "out" or id == "in" or id == "p" or id == "s" or id == "v":
				belongs = (ad["color"] as Color) == (team[0] as Color)
			if not belongs:
				continue
			var pw2: Vector2 = _w(ad["pos"])
			var bi: int = -1
			var bd: float = 9.0
			for si in range(slots.size()):
				if si in taken:
					continue
				var dd: float = (slots[si] as Vector2).distance_to(pw2)
				if dd < bd:
					bd = dd
					bi = si
			if bi >= 0:
				taken.append(bi)
		# Quiénes del plantel ya están en la jugada (por nombre) y quiénes
		# quedan para ocupar el resto de los puestos.
		var used: Dictionary = {}
		for idn in _actors:
			used[String(_actors[idn]["name"])] = true
		var pool: Array = []
		for person in (team_people.get("us" if ours else "them", []) as Array):
			if not used.has(String((person as Dictionary).get("name", ""))):
				pool.append(person)
		for si in range(slots.size()):
			if si in taken:
				continue
			var wpos: Vector2 = slots[si]
			# Tiran la línea con los de la jugada (ver offside_line_for).
			if not ambient:
				var hold0: float = _line_hold(team[0], not ours)
				if not is_nan(hold0):
					wpos.y = maxf(wpos.y, hold0) if not ours else minf(wpos.y, hold0)
			# El puesto pide un defensor / volante / delantero: se busca uno.
			var want: String = "DF" if si < 4 else ("MF" if si < 8 else "ST")
			var who: Dictionary = {}
			for pi in range(pool.size()):
				if String((pool[pi] as Dictionary).get("pos", "")) == want:
					who = pool[pi]
					pool.remove_at(pi)
					break
			if who.is_empty() and not pool.is_empty():
				who = pool.pop_front()
			var pos: Vector2 = _wi(wpos)
			# Nadie encima de la jugada: si cae cerca de un actor, se corre.
			for id2 in _actors:
				var other: Vector2 = _actors[id2]["pos"]
				if other.distance_to(pos) < 0.12:
					pos = other + (pos - other + Vector2(0.01, 0.01)).normalized() * 0.13
			if not ambient:
				var hold1: float = _line_hold(team[0], not ours)
				if not is_nan(hold1):
					var pw3: Vector2 = _w(pos)
					pw3.y = minf(pw3.y, hold1 - 0.02) if ours else maxf(pw3.y, hold1 + 0.02)
					pos = _wi(pw3)
			var eid: String = "extra%d" % n
			n += 1
			var a2 := {"id": eid, "pos": pos, "color": team[0], "look": who.get("look", {}), "name": String(who.get("name", eid))}
			_actors[eid] = {
				"pos": pos, "color": team[0], "text": Color.WHITE, "num": "", "name": "",
				"user": false, "ref": false, "card": null, "anims": {}, "anim": "idle",
				"anim_t0": 0, "anim_loop": true, "extra": true,
			}
			_actors[eid].merge(_sprite_setup(a2, team[0]))
			# IA de posición: su puesto (mundo, sin el corrimiento por la
			# pelota) y su ritmo propio.
			_actors[eid]["slot"] = Vector2(wpos.x, wpos.y - shift)
			# Su ritmo sale de su Velocidad real (si se conoce).
			if who.has("speed"):
				_actors[eid]["spd"] = lerpf(0.07, 0.135, clampf((float(who["speed"]) - 40.0) / 55.0, 0.0, 1.0))
			else:
				_actors[eid]["spd"] = 0.075 + fmod(float(n) * 0.37, 1.0) * 0.045
			_actors[eid]["num"] = String(who.get("num", ""))
			_actors[eid]["attrs"] = who.get("attrs", {})
			# Cada uno mira hacia el arco que ataca (en el mundo: los tuyos, arriba).
			_actors[eid]["face"] = ("north" if ours else "south") if not scene_flip else ("south" if ours else "north")
	# Los arqueros que no participan de la jugada.
	for gk in [[PitchPlays.GK_THEM, Vector2(0.5, 0.03), has_gk_them, them_col], [PitchPlays.GK_US, Vector2(0.5, 1.97), has_gk_us, us_col]]:
		if bool(gk[2]) or gk[3] == null or (us_col == null or them_col == null):
			continue
		var fpos: Vector2 = _wi(gk[1])
		var skip: bool = false
		for id3 in _actors:
			if (_actors[id3]["pos"] as Vector2).distance_to(fpos) < 0.08:
				skip = true   # ya hay un arquero ahí (el tuyo, cuando sos arquero)
		if skip:
			continue
		var gid: String = "extra_gk%d" % n
		n += 1
		var gk_who: Dictionary = team_people.get("their_gk" if gk[0] == PitchPlays.GK_THEM else "our_gk", {})
		var fa := {"id": gid, "pos": fpos, "color": gk[0], "gk": true, "look": gk_who.get("look", {}), "name": String(gk_who.get("name", gid))}
		_actors[gid] = {
			"pos": fpos, "color": gk[0], "text": Color.WHITE, "num": "", "name": "",
			"user": false, "ref": false, "card": null, "anims": {}, "anim": "idle",
			"anim_t0": 0, "anim_loop": true, "extra": true,
		}
		_actors[gid].merge(_sprite_setup(fa, gk[0]))
		_actors[gid]["goal_y"] = (gk[1] as Vector2).y
		_actors[gid]["spd"] = 0.09
		_actors[gid]["face"] = "north"

## Colores de las vallas publicitarias (los pone Match: local / visitante).
var board_colors: Array = []

## Datos de sprite de un jugador: tinte (camiseta = color del equipo,
## short oscuro/claro según contraste, piel/pelo del `look` o por nombre),
## prefijo de animaciones (arquero o de campo) y hacia dónde mira quieto.
func _sprite_setup(a: Dictionary, col: Color) -> Dictionary:
	var keeper: bool = String(a["id"]) == "gk" or bool(a.get("gk", false))
	var h: int = absi(hash("%s|%s" % [a.get("name", ""), a["id"]]))
	var look: Dictionary = a.get("look", {})
	var cfg := {
		"tint_clothing": col.to_html(false),
		"tint_shorts": "#1f2026" if col.get_luminance() > 0.42 else "#e9e9ec",
		"tint_base": String(look.get("tint_base", _SKINS[h % _SKINS.size()])),
		"tint_hair": String(look.get("tint_hair", _HAIRS[(h / 7) % _HAIRS.size()])),
	}
	# Peinado/barba/accesorios y guayos del jugador (los de cabeza solo se
	# ven en la pose de frente; los guayos tiñen los botines en todas).
	for k in ["hair", "face", "acc_feet", "acc_head", "acc_eyes", "acc_ears"]:
		if String(look.get(k, "")) != "":
			cfg[k] = String(look[k])
	if not cfg.has("acc_feet") and (h / 13) % 5 < 3:
		# Variedad: los demás también usan botines de colores.
		cfg["tint_boots"] = _BOOTS[(h / 31) % _BOOTS.size()]
	var tk: Dictionary = team_kits.get(col.to_html(false), {})
	if not keeper and int(tk.get("w", -1)) >= 0:
		cfg["kit_w"] = int(tk["w"])
		cfg["tint_kit2"] = String(tk["sec"])
	var p: Vector2 = a.get("pos", Vector2(0.5, 0.5))
	return {
		"sprite": cfg,
		"prefix": "gk_" if keeper else "pitch_",
		# Arquero mira a la cancha; el resto, hacia el arco de arriba si
		# está en campo de ataque (los de abajo suben).
		"face": "south" if keeper else "north",
		"keeper": keeper,
		"fcache": {},
		"_y0": p.y,
	}

## Cuadros de la animación lógica `anim` de un actor ("idle", "run_<dir>",
## "remate", "atajada"...). Árbitro: su set fijo. Jugador: se resuelve al
## arte que existe (8 direcciones; el arquero sin carrera propia usa la del
## jugador de campo con su buzo).
static var _no_anim: Dictionary = {}
func _frames(a: Dictionary, anim: String) -> Array:
	var fixed: Dictionary = a["anims"]
	if fixed.has(anim):
		return fixed[anim]
	if not a.has("sprite"):
		return []
	var pre: String = a["prefix"]
	var names: Array = []
	if anim == "idle":
		var sf: String = _screen_face(String(a["face"]))
		if a.has("vdir") and not a["keeper"]:
			sf = String(DIRS8[int(a["vdir"])])
		names = [pre + "idle_" + sf, "pitch_idle_" + sf]
		if a["keeper"]:
			names.insert(1, "gk_idle_south")
	elif anim.begins_with("run_"):
		names = [pre + anim, "pitch_" + anim]
	else:
		names = [pre + anim, "pitch_" + anim]
		if String(a.get("act_dir", "")) != "" and anim in ["remate", "pase", "barrida"]:
			# Primero la dirección exacta; si ese arte no existe (la barrida no
			# tiene diagonales), la más parecida de las cuatro.
			var ad: String = String(a["act_dir"])
			var coarse: String = {"ne": "e", "nw": "w", "se": "s", "sw": "s"}.get(ad, ad)
			if coarse != ad:
				names.insert(0, "pitch_" + anim + "_" + coarse)
			names.insert(0, "pitch_" + anim + "_" + ad)
		# Arquero visto de ESPALDAS (tu arco, abajo en la cámara detrás del
		# arco): sus atajadas tienen arte propio "_n" (PixelLab, 11-oct).
		if a["keeper"] and _screen_face(String(a["face"])) == "north":
			names.insert(0, "gk_" + anim + "_n")
	var cache: Dictionary = a["fcache"]
	for n in names:
		if cache.has(n):
			return cache[n]
		# Lo que no existe se anota una vez (antes se le preguntaba al disco
		# en CADA cuadro por cada jugador: costaba y trababa en el celular).
		if _no_anim.has(n):
			continue
		if not Avatar.has_anim(n):
			_no_anim[n] = true
			continue
		if true:
			var f: Array = Avatar.anim_frames(a["sprite"], n)
			cache[n] = f
			return f
	return []

func _set_anim(id: String, anim: String, loop: bool) -> void:
	var a: Dictionary = _actors[id]
	if a["anim"] == anim:
		return
	if _frames(a, anim).is_empty():
		return
	a["anim"] = anim
	a["anim_t0"] = Time.get_ticks_msec()
	a["anim_loop"] = loop

func _process(delta: float) -> void:
	if _mg != null:
		_mg.process(delta)
	if _aim_mode and _actors.has("gk"):
		_aim_t += delta * _aim_speed
		# Va hacia su vaivén de a poco: al empezar a apuntar saltaba de donde
		# estaba parado al centro del arco en un solo cuadro.
		var gk_goal := Vector2(0.5 + sin(_aim_t) * GOAL_W * 0.42, 0.025)
		_actors["gk"]["pos"] = (_actors["gk"]["pos"] as Vector2).lerp(gk_goal, minf(1.0, delta * 9.0))
	_pulse = fmod(_pulse + delta * 2.2, TAU)
	_wx_t += delta
	_follow = _follow.lerp(_follow_target(), minf(1.0, delta * 3.5))
	if ambient:
		_ambient_tick(delta)
	_extras_ai(delta)
	_scene_ai()
	_live_t += delta
	_keeper_steps(delta)
	for sid in _actors:
		var sa: Dictionary = _actors[sid]
		var spx: Vector2 = _p(sa["pos"])
		var sd: float = spx.distance_to(sa.get("spx", spx))
		sa["spx"] = spx
		if sd < 60.0:
			sa["stride"] = float(sa.get("stride", 0.0)) + sd
		# GIROS (11-oct, "naturalidad"): el jugador no cambia de dirección de
		# golpe — pasa por las direcciones intermedias (45° cada TURN_STEP),
		# por el lado más corto. Los gestos y el arquero no giran así.
		if not sa.has("sprite") or bool(sa.get("keeper", false)):
			continue
		var an: String = String(sa["anim"])
		var want_dir: String = ""
		if an.begins_with("run_"):
			want_dir = an.substr(4)
		elif an == "idle":
			want_dir = _screen_face(String(sa["face"]))
		else:
			sa.erase("vdir")
			continue
		var wi: int = DIRS8.find(want_dir)
		if wi < 0:
			continue
		if not sa.has("vdir"):
			sa["vdir"] = wi
			continue
		var ci: int = int(sa["vdir"])
		if ci == wi:
			sa["vturn"] = 0.0
			continue
		sa["vturn"] = float(sa.get("vturn", 0.0)) + delta
		while float(sa["vturn"]) >= TURN_STEP and ci != wi:
			sa["vturn"] = float(sa["vturn"]) - TURN_STEP
			var diff: int = posmod(wi - ci, 8)
			ci = posmod(ci + (1 if diff <= 4 else -1), 8)
		sa["vdir"] = ci
	# Los jueces de línea siguen la jugada por su banda.
	var bw: Vector2 = _w(_ball)
	_lm_y[0] = lerpf(_lm_y[0], clampf(bw.y, 0.03, 1.0), minf(1.0, delta * 2.2))
	_lm_y[1] = lerpf(_lm_y[1], clampf(bw.y, 1.0, 1.97), minf(1.0, delta * 2.2))
	if _crowd_hype > 0.0:
		_crowd_hype = maxf(0.0, _crowd_hype - delta)
	queue_redraw()

## PASOS LATERALES DEL ARQUERO (11-oct, Wilber: "animaciones de moverse a
## los lados al arquero antes de tirarse"). Cuando el arquero se acomoda de
## costado (sigue la pelota, se perfila, el vaivén mientras apuntás) ya no
## se desliza quieto: da pasitos laterales hacia ese lado. No pisa sus
## otros gestos (estirada, atajada, salto).
func _keeper_steps(delta: float) -> void:
	for id in _actors:
		var a: Dictionary = _actors[id]
		if not bool(a.get("keeper", false)) or not a.has("sprite"):
			continue
		var px: float = _p(a["pos"]).x
		var vx: float = (px - float(a.get("kx", px))) / maxf(delta, 0.001)
		a["kx"] = px
		# Suavizado: un cuadro suelto no cambia de animación.
		var sm: float = lerpf(float(a.get("kvx", 0.0)), vx, 0.25)
		a["kvx"] = sm
		var cur: String = String(a["anim"])
		if cur != "idle" and not cur.begins_with("paso_"):
			continue
		var want: String = "idle"
		if absf(sm) > 14.0:
			want = "paso_der" if sm > 0.0 else "paso_izq"
		elif cur.begins_with("paso_") and absf(sm) > 6.0:
			want = cur
		if want != cur and (want == "idle" or has_anim_for(a, want)):
			_set_anim(id, want, true)

## ZOOM CON DOS DEDOS (10-oct, Wilber: "que se pueda acercar o alejar la
## cámara con los dedos"). Con un dedo todo sigue igual (apuntar, tocar,
## deslizar); con dos, se acerca/aleja y se mueve la cámara. Soltar los dos
## dedos cancela el gesto de un dedo que hubiera quedado a medias.
const PINCH_ZOOM_MAX := 2.8
var _touches: Dictionary = {}        # índice del dedo → posición
var _pinch_dist0: float = 0.0
var _pinch_zoom0: float = 1.0
var _pinch_active: bool = false

func _pinch_input(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() == 2:
			var pts: Array = _touches.values()
			_pinch_dist0 = maxf((pts[0] as Vector2).distance_to(pts[1]), 1.0)
			_pinch_zoom0 = cam_zoom
			_pinch_active = true
			_aim_drag = false          # un remate a medio apuntar se cancela
			if _cam_tween != null and _cam_tween.is_valid():
				_cam_tween.kill()
			return true
		if _pinch_active:
			# Mientras quede algún dedo del pellizco apoyado, no es un toque.
			if _touches.is_empty():
				_pinch_active = false
			return true
		return false
	if event is InputEventScreenDrag and _pinch_active and _touches.size() == 2:
		var before: Vector2 = ((_touches.values()[0] as Vector2) + (_touches.values()[1] as Vector2)) * 0.5
		_touches[event.index] = event.position
		var pts2: Array = _touches.values()
		var mid: Vector2 = ((pts2[0] as Vector2) + (pts2[1] as Vector2)) * 0.5
		var z: float = clampf(_pinch_zoom0 * (pts2[0] as Vector2).distance_to(pts2[1]) / _pinch_dist0, ZOOM_MIN, ZOOM_MAX)
		# Arrastrar con los dos dedos mueve el foco.
		_cam_to(z, _from_px_w(_pw(cam_focus) + (before - mid) / maxf(cam_zoom, 0.1)), false)
		return true
	return _pinch_active

## El pellizco se detecta en _input (global), no en _gui_input: así funciona
## también cuando la cancha no es interactiva (mirando una repetición), que
## es cuando tiene mouse_filter IGNORE y no recibe _gui_input.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_touches.clear()
		_pinch_active = false
		return
	if event is InputEventScreenTouch and event.pressed and not get_global_rect().has_point(event.position):
		return   # dedo apoyado fuera de la cancha: no cuenta para el pellizco
	if _pinch_input(event):
		get_viewport().set_input_as_handled()
	elif _pan_input(event):
		get_viewport().set_input_as_handled()

## MOVER LA CÁMARA CON UN DEDO (10-oct, Wilber: "yo puedo mover la cámara y
## hacer zoom para tomar las decisiones"). Solo cuando no hay un minijuego
## ni se está apuntando (ahí el dedo JUEGA). Un toque corto sigue siendo un
## toque: recién a los 14 px de arrastre pasa a mover la cámara.
const PAN_START_PX := 14.0
var _pan_id: int = -9
var _pan_from: Vector2 = Vector2.ZERO
var _pan_last: Vector2 = Vector2.ZERO
var _panning: bool = false

func _can_pan() -> bool:
	return _mg == null and not _aim_mode and not _slowmo and not _pinch_active

func _pan_input(event: InputEvent) -> bool:
	if not _can_pan():
		_pan_id = -9
		_panning = false
		return false
	var id: int = -9
	var pos := Vector2.ZERO
	var down := false
	var up := false
	var move := false
	if event is InputEventScreenTouch:
		id = event.index
		pos = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventScreenDrag:
		id = event.index
		pos = event.position
		move = true
	elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return false   # ratón emulado desde el toque: ya llegó como toque
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if not get_global_rect().has_point(event.position):
				return false
			_layout_field()
			_cam_to(cam_zoom * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), cam_focus, false)
			return true
		if event.button_index != MOUSE_BUTTON_LEFT:
			return false
		id = -1
		pos = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventMouseMotion:
		id = -1
		pos = event.position
		move = true
	else:
		return false
	if down:
		if id >= 0 and _touches.size() != 1:
			return false
		_pan_id = id
		_pan_from = pos
		_pan_last = pos
		_panning = false
		return false
	if id != _pan_id:
		return false
	if up:
		_pan_id = -9
		if _panning:
			_panning = false
			return true   # era un arrastre de cámara, no un toque
		return false
	if move:
		if not _panning and pos.distance_to(_pan_from) > PAN_START_PX:
			_panning = true
			_pan_last = pos
		if _panning:
			_layout_field()
			_cam_to(cam_zoom, _from_px_w(_pw(cam_focus) - (pos - _pan_last) / maxf(cam_zoom, 0.1)), false)
			_pan_last = pos
			return true
	return false

func _gui_input(event: InputEvent) -> void:
	if _pinch_active:
		accept_event()
		return
	if _mg != null:
		accept_event()
		_mg.input(event)
		return
	if _aim_mode:
		_aim_input(event)
		return
	if not _interactive:
		return
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and not event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		pos = event.position
	else:
		return
	accept_event()
	tapped.emit(target_at(_unzoom(pos)))

func _aim_input(event: InputEvent) -> void:
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	else:
		return
	accept_event()
	pos = _unzoom(pos)
	if pressed and not _aim_drag:
		_aim_drag = true
		_aim_from = pos
		_aim_to = pos
	elif _aim_drag and not released:
		_aim_to = pos
	elif _aim_drag and released:
		_aim_to = pos
		var ax: float = _aim_goal_x()
		var pw: float = _aim_power()
		var gx: float = float(_actors["gk"]["pos"].x)
		stop_shot_aim()
		shot_released.emit(ax, pw, gx)
	queue_redraw()

## Qué hay bajo un punto (en píxeles del control): actor más cercano dentro
## de un radio generoso (dedo), el arco, o espacio libre.
func target_at(px: Vector2) -> String:
	_layout_field()
	var r: float = clampf(_field.size.x * 0.034, 9.0, 16.0)
	var best: String = ""
	var best_d: float = r * 2.6
	for id in _actors:
		if id == "user" or id == "gk" or bool(_actors[id].get("extra", false)):
			continue
		var d: float = _p(_actors[id]["pos"]).distance_to(px)
		if d < best_d:
			best_d = d
			best = id
	if best != "":
		return best
	if not _plain():
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(px, _p(Vector2(0.5 - GOAL_W * 0.7, 0.0)), _p(Vector2(0.5 + GOAL_W * 0.7, 0.0)))
		return "goal" if q.distance_to(px) < 40.0 else "space"
	var mouth := Rect2(_p(Vector2(0.5 - GOAL_W, 0.0)) - Vector2(0, 16), Vector2(GOAL_W * 2.0 * _field.size.x, 16 + SMALL_D * _field.size.y))
	if mouth.has_point(px):
		return "goal"
	return "space"

## Arma la escena. `scene` = {"actors": [{id, pos, color, num, name,
## user}], "ball": Vector2 | id del actor que la tiene}.
func setup(scene: Dictionary) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_actors.clear()
	_has_sprites = false
	ambient = false
	_amb_holder = ""
	_amb_pass = {}
	scene_flip = bool(scene.get("flip", false))
	scene_mirror = bool(scene.get("mirror", false))
	scene_stretch = float(scene.get("stretch", 1.0))
	_pan_id = -9
	_panning = false
	for a in scene.get("actors", []):
		var col: Color = a.get("color", Color.WHITE)
		_actors[String(a["id"])] = {
			"pos": a.get("pos", Vector2(0.5, 0.5)),
			"color": col,
			"text": Styles.contrasting_text_color(col),
			"num": String(a.get("num", "")),
			"name": String(a.get("name", "")),
			"user": bool(a.get("user", false)),
			"ref": bool(a.get("ref", false)),
			"card": a.get("card", null),
			"anims": a.get("anims", {}),
			"anim": "idle",
			"anim_t0": 0,
			"anim_loop": true,
			"attrs": a.get("attrs", {}),
		}
		if not (a.get("anims", {}) as Dictionary).is_empty():
			_has_sprites = true
		elif use_player_sprites and not bool(a.get("ref", false)):
			_actors[String(a["id"])].merge(_sprite_setup(a, col))
			_has_sprites = true
	_add_extras(scene)
	_ball = _resolve_target(scene.get("ball", Vector2(0.5, 0.5)))
	_ball_h = 0.0
	_ball_visible = scene.get("ball", null) != null
	_line_y = -9.0
	_flag_up = false
	_str_on = false
	_str_moving = false
	_net_t = -9.0
	_board = {}
	shot_previews = []
	_ball_visible = scene.get("ball", null) != null
	_follow = _follow_target()
	_flash.visible = false
	reset_camera(false)
	_update_processing()
	queue_redraw()

## Reproduce una lista de pasos en orden y emite `finished` al terminar.
## Paso: {"t": seg, "moves": {id: Vector2}, "ball": Vector2|id,
##        "arc": float (altura máx del vuelo), "flash": String,
##        "flash_color": Color, "hide_ball": bool}
## Tope de velocidad de carrera en pantalla, en cuerpos (40 px) por segundo,
## y cuánto más rápido que el promedio va el tramo medio del paso (lo da la
## curva de `_step_progress`).
const RUN_MAX_BODIES := 7.5
## Pixeles de avance por cuadro de la carrera (8 cuadros = 2 pasos).
const STRIDE_PX := 13.0
## Segundos por cada 45° de giro (media vuelta = 0,2 s).
const TURN_STEP := 0.05
## Respiración (parado): cada cuánto y qué parte del cuerpo baja 1 píxel.
const BREATH_SECS := 2.4
const BREATH_SPLIT := 0.56
## 11-oct (Wilber: "a veces va como lento, pesado o pegado"): cada paso
## arrancaba de cero y frenaba a cero, así que una jugada de varios pasos se
## veía a tirones. Ahora el movimiento es casi parejo (RUN_EASE_MIX = cuánto
## queda de la curva de arranque/frenada) y el tope de carrera sube un poco.
const RUN_EASE := -1.25
const RUN_EASE_MIX := 0.3
const RUN_EASE_PEAK := 1.08

func _set_dur(d: float) -> void:
	_cur_dur = d

func play(steps: Array) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	# NADIE SE TELETRANSPORTA (11-oct, bug reportado por Wilber: "en vez de
	# correr se teletransportan"). Causa: la duración de cada paso se pensó
	# para la cancha chica; desde que la cancha mide 1,7 veces más (y las
	# jugadas de armado arrancan más atrás) el mismo paso recorre mucha más
	# pantalla en el mismo tiempo — medido: picos de 25 a 47 cuerpos por
	# segundo (un velocista hace ~4,5). Ahora cada paso dura lo que haga
	# falta para que el que más corre no pase de RUN_MAX_BODIES.
	_layout_field()
	var sim: Dictionary = {}
	for sid in _actors:
		sim[sid] = _actors[sid]["pos"]
	for st in steps:
		var step: Dictionary = st
		var dur: float = maxf(0.05, float(step.get("t", 0.5)))
		var mv: Dictionary = step.get("moves", {})
		var gest: Dictionary = step.get("anim", {})
		for mid in mv:
			if not sim.has(mid):
				continue
			# (un regate o una barrida si pueden ir mas rapido que una carrera,
			# pero tampoco de un salto).
			# 11-oct (Wilber: "el arquero también parece que se teletransporta
			# al salir o atajar"): el arquero había quedado SIN tope. Una
			# estirada es más rápida que una carrera, pero se tiene que ver.
			var is_gk: bool = bool(_actors[mid].get("keeper", false))
			var px_d: float = _p(mv[mid]).distance_to(_p(sim[mid]))
			dur = maxf(dur, px_d * RUN_EASE_PEAK / (RUN_MAX_BODIES * (1.8 if is_gk else (1.6 if gest.has(mid) else 1.0)) * 40.0))
			sim[mid] = mv[mid]
		_tween.tween_callback(_set_dur.bind(dur * float(step.get("slow", 1.0))))
		_tween.tween_callback(_begin_step.bind(step))
		_tween.tween_method(_step_progress, 0.0, 1.0, dur * float(step.get("slow", 1.0)))
		_tween.tween_callback(_end_step.bind(step))
	_tween.tween_callback(func(): finished.emit())

var _from: Dictionary = {}
var _to: Dictionary = {}
var _ball_from: Vector2
var _ball_to: Vector2
var _ball_follow: String = ""
var _arc: float = 0.0
var _curve: float = 0.0        # comba lateral (coordenadas de jugada)
var _kick_wait: float = 0.0    # fracción del paso que la pelota espera el golpe
var _cur_dur: float = 0.5      # duración real del paso en curso
const KICK_CONTACT := 0.20     # segundos del gesto hasta que el pie toca la pelota
const KICK_FPS := 20.0         # cuadros/s de los golpes (cuadro 4 de 8 = contacto a los 0,20 s)
const KICK_ANIMS := ["remate", "pase", "volea", "cabezazo", "chilena"]
var _trail: Array = []         # últimas posiciones en pantalla (estela de un remate)
## RED (11-oct, Wilber: "la reacción de la red a los goles"): cuándo y por
## dónde entró la última pelota, para que la red se hunda y vibre.
var _net_t: float = -9.0
var _net_x: float = 0.5
var _net_end: int = 0
var _moving_ball: bool = false

func _begin_step(step: Dictionary) -> void:
	_from.clear()
	_to.clear()
	var moves: Dictionary = step.get("moves", {})
	for id in moves:
		if _actors.has(id):
			_from[id] = _actors[id]["pos"]
			_to[id] = moves[id]
	_moving_ball = step.has("ball")
	_ball_follow = ""
	if _moving_ball:
		_ball_from = _ball
		var tgt = step["ball"]
		# Si el destino es un actor que TAMBIÉN se mueve en este paso, la
		# pelota va a donde él termina (recibe en carrera).
		if tgt is String and _to.has(tgt):
			_ball_to = _to[tgt] + _feet_offset()
		else:
			_ball_to = _resolve_target(tgt)
	elif step.get("dribble", "") != "":
		_ball_follow = String(step["dribble"])
	_arc = float(step.get("arc", 0.0))
	_curve = 0.0
	_kick_wait = 0.0
	_trail.clear()
	if step.get("hide_ball", false):
		_ball_visible = false
	# Cámara dentro de un guion (9-oct, Wilber: "zoom al árbitro cuando saque
	# las tarjetas"): {"cam": {"ids": [...], "zoom": z}} o {"cam": "reset"}.
	if step.has("cam"):
		var cam = step["cam"]
		if cam is Dictionary:
			focus_on((cam as Dictionary).get("ids", []), [], float((cam as Dictionary).get("zoom", 2.2)), false)
		else:
			reset_camera(true)
	var cards: Dictionary = step.get("set_card", {})
	for id in cards:
		if _actors.has(id):
			_actors[id]["card"] = cards[id]
	_str_moving = false
	if step.has("board"):
		_board = step["board"] if step["board"] is Dictionary else {}
	for hid in (step.get("hide", []) as Array):
		if _actors.has(hid):
			_actors[hid]["hidden"] = true
	if step.has("stretcher"):
		var st = step["stretcher"]
		var st_to: Vector2 = (_to.get(st, _actors[st]["pos"]) as Vector2) if (st is String and _actors.has(st)) else (st as Vector2)
		if not _str_on:
			# Entran desde la banda derecha de la jugada, a su misma altura.
			_str_pos = Vector2(1.10, st_to.y)
			_str_on = true
		_str_from = _str_pos
		_str_to = st_to
		_str_moving = true
	if step.has("line"):
		# "auto:<id>" = la linea se MIDE en este momento: el penultimo rival
		# de quien ataca, con todos donde estan parados ahora.
		if step["line"] is String:
			_line_y = offside_line_for(String(step["line"]).trim_prefix("auto:"))
		else:
			_line_y = float(step["line"])
	if step.has("flag"):
		_flag_up = bool(step["flag"])
	var anims: Dictionary = (step.get("anim", {}) as Dictionary).duplicate()
	if _moving_ball:
		_infer_actions(step, anims)
		var kicker: String = ""
		for kid in anims:
			if String(anims[kid]) in ["remate", "pase", "volea", "cabezazo", "chilena"]:
				kicker = kid
		if kicker != "":
			_kick_wait = clampf(KICK_CONTACT / maxf(_cur_dur, 0.05), 0.0, 0.4)
		# Comba: explícita en el paso, o suave en centros (pelota alta y
		# cruzada) y remates. Siempre hacia el lado "natural" de la jugada.
		if step.has("curve"):
			_curve = float(step["curve"])
		else:
			var dvec: Vector2 = _ball_to - _ball_from
			var bend_dir: float = 1.0 if dvec.x >= 0.0 else -1.0
			if _arc >= 1.5 and absf(dvec.x) > 0.2:
				_curve = 0.035 * bend_dir
			elif _ball_to.y < 0.04 and dvec.length() > 0.12:
				_curve = 0.014 * bend_dir
	for id in anims:
		if _actors.has(id):
			# GESTOS CON DIRECCIÓN (11-oct, PixelLab): el pase, el remate y la
			# barrida ya no miran siempre al arco de arriba — se dibujan hacia
			# donde va la pelota (o hacia donde se tira el que barre).
			if String(anims[id]) in ["remate", "pase", "barrida"]:
				var from_px: Vector2 = _p(_actors[id]["pos"])
				var to_px2: Vector2 = _p(_to[id]) if (String(anims[id]) == "barrida" and _to.has(id)) else _p(_ball_to)
				_actors[id]["act_dir"] = _act_dir(to_px2 - from_px)
			_set_anim(id, String(anims[id]), false)
	# Quien se mueve y tiene sprite, corre hacia donde va.
	for id in _to:
		var ac: Dictionary = _actors[id]
		if ((ac["anims"] as Dictionary).is_empty() and not ac.has("sprite")) or anims.has(id):
			continue
		var d: Vector2 = (_to[id] as Vector2) - (_from[id] as Vector2)
		if d.length() < 0.004:
			continue
		var dir: String = ("east" if d.x > 0 else "west") if absf(d.x) > absf(d.y) else ("south" if d.y > 0 else "north")
		if ac.has("sprite"):
			# 8 direcciones (el arte de PixelLab las tiene); la cancha es
			# más alta que ancha en pantalla → el ángulo va en píxeles.
			var dp: Vector2 = d * _field.size
			dir = DIRS8[posmod(int(round(dp.angle() / (PI / 4.0))), 8)]
			if not _plain():
				# `face` queda en orientación de CANCHA; el sprite corre hacia
				# donde eso se ve en pantalla con esta cámara.
				var fd: Vector2 = d * Vector2(68.0, 52.5)
				ac["face"] = DIRS8[posmod(int(round(fd.angle() / (PI / 4.0))), 8)]
				dir = _screen_face(String(ac["face"]))
			else:
				ac["face"] = dir
		_set_anim(id, "run_" + dir, true)
	# CÁMARA LENTA (P4, 9-oct): el paso dura `slow` veces más, franjas de
	# cine y zoom a la jugada.
	if float(step.get("slow", 1.0)) > 1.01:
		_slowmo = true
		focus_on(["user", "gk"], [], 2.0, true)
	var f: String = String(step.get("flash", ""))
	if f != "":
		_show_flash(f, step.get("flash_color", Styles.GOLD))

## Hacia dónde se hace un gesto, EN PANTALLA: "" = arriba (el arte base),
## "ne", "e", "se", "s", "sw", "w", "nw".
const _ACT_SFX := ["e", "se", "s", "sw", "w", "nw", "", "ne"]
func _act_dir(dv: Vector2) -> String:
	if dv.length() < 4.0:
		return ""
	return _ACT_SFX[posmod(int(round(dv.angle() / (PI / 4.0))), 8)]

func _step_progress(t: float) -> void:
	if _str_moving:
		_str_pos = _str_from.lerp(_str_to, t)
	# LA PELOTA SALE CUANDO EL PIE LE PEGA (11-oct, Wilber: "que las patadas
	# al arco, los centros, pases y todo eso se vean mejor"). Antes la pelota
	# arrancaba en el mismo instante que el gesto: ya iba volando mientras el
	# jugador todavía llevaba la pierna atrás. Ahora espera el contacto.
	var bt: float = t
	if _kick_wait > 0.0:
		bt = clampf((t - _kick_wait) / (1.0 - _kick_wait), 0.0, 1.0)
	var e: float = lerpf(t, ease(t, RUN_EASE), RUN_EASE_MIX)
	for id in _to:
		_actors[id]["pos"] = (_from[id] as Vector2).lerp(_to[id], e)
	if _moving_ball:
		# FÍSICA (10-oct, Wilber: "mejorar las físicas"): por el piso sale
		# fuerte y se va frenando por el roce; por el aire cae y da un pique.
		if _arc <= 0.05:
			_ball = _ball_from.lerp(_ball_to, 1.0 - pow(1.0 - bt, 1.7))
			_ball_h = 0.0
		else:
			_ball = _ball_from.lerp(_ball_to, bt)
			if bt < 0.80:
				_ball_h = _arc * sin(PI * bt / 0.80)
			else:
				_ball_h = _arc * 0.22 * sin(PI * (bt - 0.80) / 0.20)
		# COMBA: los centros y los remates no van en línea recta.
		if _curve != 0.0:
			var along: Vector2 = _ball_to - _ball_from
			var side: Vector2 = Vector2(-along.y, along.x).normalized()
			_ball += side * _curve * sin(PI * bt)
	elif _ball_follow != "" and _actors.has(_ball_follow):
		_ball = _actors[_ball_follow]["pos"] + _carry_offset(_ball_follow, _to.has(_ball_follow))
	queue_redraw()

func _end_step(_step: Dictionary) -> void:
	if _moving_ball and _ball_to.y < 0.0 and absf(_ball_to.x - 0.5) <= GOAL_W * 0.5:
		var nw: Vector2 = _w(_ball_to)
		_net_t = _live_t
		_net_x = nw.x
		_net_end = 0 if nw.y < 1.0 else 1
	_trail.clear()
	if _slowmo:
		_slowmo = false
		reset_camera(true)
	_ball_h = 0.0
	for id in _to:
		if String(_actors[id]["anim"]).begins_with("run_"):
			_set_anim(id, "idle", true)
	queue_redraw()

## Gestos que salen solos de la jugada (sin que PitchPlays los pida):
## quien tiene la pelota y la suelta → remate (si va al arco) o pase; el
## arquero al que le llega → estirada al costado o atajada de frente; quien
## se la roba a un rival corriendo → barrida.
func _infer_actions(step: Dictionary, anims: Dictionary) -> void:
	var holder: String = _holder()
	var tgt = step["ball"]
	var to_goal: bool = _ball_to.y < 0.04
	if holder != "" and not anims.has(holder) and _actors[holder].has("sprite") and not bool(_actors[holder].get("keeper", false)) and not (tgt is String and tgt == holder):
		anims[holder] = "remate" if to_goal else "pase"
	for id in _actors:
		var a: Dictionary = _actors[id]
		if anims.has(id) or not a.has("sprite"):
			continue
		if bool(a.get("keeper", false)) and to_goal:
			var gk_to: Vector2 = _to.get(id, a["pos"])
			var dx: float = gk_to.x - (a["pos"] as Vector2).x
			if absf(dx) > 0.02 and cam_mode != "arco":
				# Las estiradas están dibujadas de frente: en las otras cámaras
				# el arquero salta o ataja de frente.
				anims[id] = "salto" if has_anim_for(a, "salto") else "atajada"
			elif absf(dx) > 0.02:
				# BUG (10-oct, Wilber: "los vi tirándose a la izquierda pero
				# hacia la derecha"): el lado se decidía en coordenadas de la
				# JUGADA; en tu arco (jugada espejada) la pantalla va al revés
				# y el arquero se estiraba para un lado mientras se movía al otro.
				var sdx: float = _p(gk_to).x - _p(a["pos"]).x
				anims[id] = "estirada_der" if sdx > 0.0 else "estirada_izq"
				# PELOTA ALTA (al ángulo, tiro libre, 11-oct): vuela hacia
				# arriba y al palo, no se tira al piso.
				if _arc >= 1.5 and has_anim_for(a, "volada"):
					anims[id] = "volada"
					a["vol_dir"] = 1.0 if sdx > 0.0 else -1.0
			elif _ball_to.distance_to(a["pos"]) < 0.06:
				# Pelota alta (vaselina, cabezazo, remate con comba) → salta
				# hacia arriba; rasa o a media altura → atajada de frente.
				anims[id] = "salto" if _arc >= 1.2 and has_anim_for(a, "salto") else "atajada"
		elif tgt is String and tgt == id and _to.has(id) and holder != "" and holder != id and _actors[holder]["color"] != a["color"]:
			anims[id] = "barrida"

## ¿Existe el arte de esa animación para el actor? (el salto del arquero
## es nuevo: si falta el PNG, cae a la atajada de siempre).
func has_anim_for(a: Dictionary, anim: String) -> bool:
	var prefix: String = "gk_" if bool(a.get("keeper", false)) else "pitch_"
	return ResourceLoader.exists("res://assets/pixelplayer/anim/%s%s/0.png" % [prefix, anim])

## Actor que tiene la pelota en los pies ahora (o "").
func _holder() -> String:
	var best: String = ""
	var best_d: float = 0.045
	for id in _actors:
		if bool(_actors[id].get("ref", false)) or bool(_actors[id].get("extra", false)):
			continue
		var d: float = (_actors[id]["pos"] + _feet_offset()).distance_to(_ball)
		if d < best_d:
			best_d = d
			best = id
	return best

func _show_flash(text: String, col: Color) -> void:
	_flash.text = text
	_flash.add_theme_color_override("font_color", col)
	_flash.visible = true
	_flash.pivot_offset = size * 0.5
	_flash.scale = Vector2(0.4, 0.4)
	_flash.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_flash, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _resolve_target(tgt) -> Vector2:
	if tgt is Vector2:
		return tgt
	if tgt is String and _actors.has(tgt):
		return _actors[tgt]["pos"] + _feet_offset()
	return _ball

## Balón (con sombra que se separa cuando va por el aire). Se dibuja en su
## lugar dentro del orden de profundidad: los jugadores que están más cerca
## de la cámara lo tapan (antes iba siempre encima de todos).
var _ball_drawn: bool = false
func _draw_ball(r: float) -> void:
	_ball_drawn = true
	if _ball_visible:
		# 11-oct (Wilber: "¿jugadores más grandes o el balón más pequeño?"): el
		# balón. Los jugadores van a escala ENTERA de píxel (agrandarlos = el
		# doble) y la pelota medía casi media altura de jugador.
		var br: float = r * 0.32
		var bp := _p(_ball)
		# LA PELOTA SE ELEVA (11-oct, Wilber: "que en los centros se vea el
		# balón elevarse, cuando vaya al ángulo también"): sube más en
		# pantalla, se agranda al acercarse a la cámara y su sombra se queda
		# en el piso, más chica y más clara cuanto más alta va.
		var hk: float = clampf(_ball_h / 2.6, 0.0, 1.0)
		draw_circle(bp + Vector2(1.5 + _ball_h * 1.5, 2.0 + _ball_h * 0.8), br * lerpf(1.0, 0.6, hk), Color(0, 0, 0, lerpf(0.35, 0.16, hk)))
		var lift: Vector2 = Vector2(0, -_ball_h * r * 1.35)
		var bs: float = br * (1.0 + _ball_h * 0.2)
		# EL BALÓN GIRA (10-oct, Wilber: "que los balones giren"): rueda según
		# lo que se desplazó en pantalla, hacia donde va.
		# Estela corta cuando la pelota va rápido (un remate, un pelotazo).
		if _moving_ball:
			_trail.append(bp + lift)
			if _trail.size() > 4:
				_trail.pop_front()
			if _trail.size() >= 2 and (_trail.back() as Vector2).distance_to(_trail[0]) > 26.0:
				for ti in range(_trail.size() - 1):
					draw_circle(_trail[ti], bs * (0.45 + 0.15 * ti), Color(1, 1, 1, 0.07 + 0.05 * ti))
		var moved: Vector2 = bp - _ball_prev_px
		if moved.length() < 60.0:
			_ball_spin += moved.length() / maxf(br, 1.0) * (1.0 if moved.x >= 0.0 else -1.0) * 0.55
		_ball_prev_px = bp
		if ball_texture != null:
			# El balón del partido (9-oct: "los balones no los vi"): el mismo
			# que elegiste en la previa, no un círculo blanco.
			var side: float = bs * 2.6
			draw_set_transform(_cam_offset() + (bp + lift) * cam_zoom, _ball_spin, Vector2(cam_zoom, cam_zoom))
			draw_texture_rect(ball_texture, Rect2(-Vector2(side, side) * 0.5, Vector2(side, side)), false)
			draw_set_transform(_cam_offset(), 0.0, Vector2(cam_zoom, cam_zoom))
		else:
			draw_circle(bp + lift, bs, Color.WHITE)
			draw_arc(bp + lift, bs, 0, TAU, 16, Color(0, 0, 0, 0.6), 1.2)

## CONDUCCIÓN (10-oct, Wilber: "animar al jugador con balón, como que lleva
## un balón"): la pelota va ADELANTE de quien la lleva, hacia donde mira, y
## mientras corre la va empujando con toques cortos (se le adelanta y la
## alcanza). Quieto, queda pegada al pie.
const _FIELD_DIR := {
	"east": Vector2(1, 0), "south-east": Vector2(0.7, 0.7), "south": Vector2(0, 1), "south-west": Vector2(-0.7, 0.7),
	"west": Vector2(-1, 0), "north-west": Vector2(-0.7, -0.7), "north": Vector2(0, -1), "north-east": Vector2(0.7, -0.7),
}
func _carry_offset(id: String, moving: bool) -> Vector2:
	var a: Dictionary = _actors[id]
	var dir: Vector2 = _FIELD_DIR.get(String(a.get("face", "north")), Vector2(0, -1))
	if bool(a.get("keeper", false)):
		dir = Vector2(0, 1)
	var reach: float = 0.034
	if moving:
		reach = 0.030 + 0.022 * absf(sin(_live_t * 9.0))
	return Vector2(dir.x * reach * 0.8, dir.y * reach)

## La pelota "en los pies": un poco adelante (hacia el arco de arriba).
func _feet_offset() -> Vector2:
	return Vector2(0.0, -0.035)

# --- Dibujo ------------------------------------------------------------

## CANCHA GRANDE (10-oct, Wilber: "hacer la cancha más grande para que
## quepan los 22 jugadores y no queden amontonados... no se ve toda la
## cancha pero con pases y andando se puede recorrer"). La cancha mide
## WORLD_SCALE veces lo que entra en pantalla y los jugadores quedan del
## mismo tamaño: se ve UNA PARTE y la cámara sigue la jugada.
const WORLD_SCALE := 1.7

func _layout_field() -> void:
	if cam_mode != "arco":
		var base := Rect2(Vector2(6, 6), size - Vector2(12, 12))
		_field = Rect2(base.position, base.size * WORLD_SCALE)
		return
	var margin_top: float = 46.0 + (TILT_TOP_EXTRA if tilt else 0.0)  # red + vallas (+ tribuna)
	var avail := Rect2(Vector2(14, margin_top), size - Vector2(28, margin_top + 4))
	# El frente SIEMPRE se pasa un poco de la pantalla (no solo cuando el
	# alto limita): así la cancha se ve igual de inclinada en el partido
	# real que en las capturas de prueba.
	var w: float = avail.size.x * (OVERSCAN if tilt else 1.0)
	var hk: float = TILT_H if tilt else 1.0
	var h: float = w * FIELD_ASPECT * hk
	if h > avail.size.y:
		h = avail.size.y
		# Limitada por el alto: se ensancha un poco (10-oct, Wilber: "un
		# poco más ancha") en vez de dejar franjas vacías a los costados.
		w = minf(avail.size.x * OVERSCAN, h / (FIELD_ASPECT * hk) * WIDEN)
	w *= WORLD_SCALE * FLAT_W
	h *= WORLD_SCALE
	_field = Rect2(avail.position + Vector2((avail.size.x - w) * 0.5, 0.0), Vector2(w, h))

## CANCHA INCLINADA (10-oct, Wilber: "desde arriba pero un poco inclinada
## para que se vea mejor"): el borde del arco (y=0) es más angosto que la
## mitad de cancha (y=1) y la profundidad se comprime hacia el fondo. TODO
## el dibujo y los toques pasan por _p / from_px, así que el resto del
## código (minijuegos, repeticiones) no se entera. `_field.size.x` = ancho
## del borde CERCANO.
const WIDEN := 1.60   # cuánto puede ensancharse la cancha (tope real = ancho disponible × OVERSCAN)
## El borde CERCANO se pasa un poco de la pantalla (10-oct, Wilber: "ancharla
## más abajo para que parezca más inclinada"): las esquinas de abajo quedan
## apenas fuera y los costados se abren en diagonal.
const OVERSCAN := 1.10
## 11-oct (Wilber: "se ve raro... la línea del lado de mi arco se ve muy
## distorsionada"). Causa: para que los dos arcos midieran lo mismo la
## cancha se angostaba hacia ARRIBA y también hacia ABAJO (un óvalo), así
## que en tu mitad las líneas se cerraban al revés de lo que el ojo espera
## y las bandas salían curvas. Con 1.0 no hay deformación: bandas rectas,
## áreas rectangulares y los dos arcos idénticos. La inclinación queda solo
## en el alto (TILT_H) y en los objetos parados.
const TILT_FAR := 1.0
## Sin el angostamiento el fondo se vería 1,28 veces más ancho que antes:
## se compensa para que arcos y áreas queden del tamaño ya aprobado.
const FLAT_W := 0.89
const TILT_H := 0.84
const TILT_TOP_EXTRA := 26.0
var tilt: bool = true

## ------------------------------------------------------------------
## CÁMARAS (10-oct, Wilber: "3 tipos de cámara: isométrico, vista de TV y
## detrás del arco"). La de siempre es "arco" y NO cambia: todo su código
## queda como estaba. "tv" (lateral, arco a la derecha, como una
## transmisión) e "iso" (cancha en diagonal) usan otra proyección en _p /
## from_px y un dibujo genérico de arco y entorno. Lo que el resto del
## juego ve (coordenadas de cancha 0..1, repeticiones, minijuegos) es
## idéntico en las tres.
const CAM_MODES := ["arco", "tv", "iso"]
const CAM_LABELS := {"arco": "Detrás del arco", "tv": "TV lateral", "iso": "Isométrica"}
var cam_mode: String = "arco"
const TV_FAR := 0.80          # la banda de enfrente se ve más chica
const TV_WIDTH := 0.94

func set_cam_mode(m: String) -> void:
	if not (m in CAM_MODES) or m == cam_mode:
		return
	cam_mode = m
	for id in _actors:
		(_actors[id] as Dictionary)["fcache"] = {}
	reset_camera(false)
	queue_redraw()

func _tv_rect() -> Rect2:
	var w: float = _field.size.x
	var h: float = minf(_field.size.y * 0.74, w * 0.70)
	return Rect2(Vector2(_field.position.x, _field.position.y + (_field.size.y - h) * 0.62), Vector2(w, h))

func _iso_k() -> float:
	return minf(_field.size.x * 0.96 / 120.5, _field.size.y * 0.90 / 60.25)

func _iso_origin() -> Vector2:
	var k: float = _iso_k()
	return Vector2(_field.position.x + (_field.size.x - 120.5 * k) * 0.5 + 52.5 * k,
		_field.position.y + (_field.size.y - 60.25 * k) * 0.55)

## Dirección EN PANTALLA de "hacia la derecha de la cancha" (x creciente).
## Los minijuegos de deslizar la usan para que el gesto siga a la cancha
## en cualquier cámara. En "arco" es simplemente la derecha.
func screen_dir_x() -> Vector2:
	if _plain():
		return Vector2.RIGHT
	return (_p(Vector2(0.6, 0.5)) - _p(Vector2(0.4, 0.5))).normalized()

const _FACE_VEC := {
	"east": Vector2(1, 0), "south-east": Vector2(1, 1), "south": Vector2(0, 1), "south-west": Vector2(-1, 1),
	"west": Vector2(-1, 0), "north-west": Vector2(-1, -1), "north": Vector2(0, -1), "north-east": Vector2(1, -1),
}
## Hacia dónde mira un sprite EN PANTALLA para una orientación de cancha
## ("north" = hacia el arco). En "arco" coincide.
func _screen_face(face: String) -> String:
	if _plain():
		return face
	var v: Vector2 = _FACE_VEC.get(face, Vector2(0, 1))
	var c := Vector2(0.5, 0.5)
	var d: Vector2 = _p(c + v * 0.1) - _p(c)
	return DIRS8[posmod(int(round(d.angle() / (PI / 4.0))), 8)]

## PERSPECTIVA SIMÉTRICA (10-oct, Wilber: "los arcos no son del mismo
## tamaño... está muy grande la de mi equipo"). Antes la cancha se seguía
## ensanchando hacia abajo (tu arco quedaba 1,56 veces más ancho que el
## rival). Ahora es un espejo alrededor de la mitad de cancha: lo más ancho
## es el medio y los dos arcos miden EXACTAMENTE lo mismo.
func _depth(y: float) -> float:
	if not tilt:
		return 1.0
	var k: float = clampf(y, -0.4, 2.4) - 1.0
	return 1.0 - (1.0 - TILT_FAR) * k * k

func _g1(y: float) -> float:
	return y * TILT_FAR + (1.0 - TILT_FAR) * y * y

func _gy(y: float) -> float:
	if not tilt:
		return y
	return _g1(y) if y <= 1.0 else 2.0 - _g1(2.0 - y)

## CANCHA COMPLETA (10-oct, Wilber: "hagamos la cancha completa en todas
## las cámaras... y seccionar los minijuegos para que no todo pase en el
## mismo pedazo de cancha"). Dos sistemas de coordenadas:
##   MUNDO  : x 0..1, y 0 = arco de ARRIBA (el rival), 1 = mitad de cancha,
##            2 = TU arco. Lo usa todo el dibujo de la cancha (_pw).
##   ESCENA : lo de siempre (y 0 = "el arco de la jugada", 1 = media
##            cancha). Lo usan las jugadas y los minijuegos (_p / from_px).
## Una escena se ubica en el mundo con `scene_flip` (jugadas defensivas: en
## TU mitad, contra tu arco) y `scene_stretch` (jugadas de armado: arrancan
## más atrás). Así PitchPlays y PitchMinigame no cambian.
var scene_flip: bool = false
## MÁS SITUACIONES (11-oct): la misma jugada puede darse por la otra banda.
## Se espeja ACÁ (en la conversión jugada → cancha), así las posiciones, los
## pasos, los minijuegos y los toques quedan espejados todos juntos.
var scene_mirror: bool = false
var scene_stretch: float = 1.0
var _end: int = 0   # extremo que se está dibujando (0 arriba, 1 abajo)

func _w(n: Vector2) -> Vector2:
	if scene_mirror:
		n = Vector2(1.0 - n.x, n.y)
	if scene_flip:
		return Vector2(1.0 - n.x, 2.0 - n.y * scene_stretch)
	return Vector2(n.x, n.y * scene_stretch)

func _wi(w: Vector2) -> Vector2:
	var n: Vector2 = Vector2(1.0 - w.x, (2.0 - w.y) / scene_stretch) if scene_flip else Vector2(w.x, w.y / scene_stretch)
	if scene_mirror:
		n.x = 1.0 - n.x
	return n

func _e(q: Vector2) -> Vector2:
	return Vector2(1.0 - q.x, 2.0 - q.y) if _end == 1 else q

## Vista "de siempre": cámara detrás del arco y jugada sin espejar. Es el
## camino de código original (y el más probado).
func _plain() -> bool:
	return cam_mode == "arco" and not scene_flip and not scene_mirror

func _p(n: Vector2) -> Vector2:
	return _pw(_w(n))

func _pw(n: Vector2) -> Vector2:
	if cam_mode == "tv":
		var tr: Rect2 = _tv_rect()
		# Acotado: fuera de la cancha la curva de perspectiva se pliega (los
		# rombos del césped que se extienden lejos quedaban cruzados).
		var v: float = clampf(n.x, -0.45, 1.45)   # 0 = banda de enfrente (arriba), 1 = la cercana
		var u: float = 1.0 - n.y            # arco a la derecha
		var s: float = lerpf(TV_FAR, 1.0, clampf(v, -0.3, 1.3))
		return Vector2(tr.position.x + tr.size.x * 0.5 + (u - 0.5) * tr.size.x * TV_WIDTH * s,
			tr.position.y + (v * TV_FAR + (1.0 - TV_FAR) * v * v) * tr.size.y)
	if cam_mode == "iso":
		var k: float = _iso_k()
		var o: Vector2 = _iso_origin()
		return Vector2(o.x + (n.x * 68.0 - n.y * 52.5) * k, o.y + (n.x * 68.0 + n.y * 52.5) * k * 0.5)
	var cx: float = _field.position.x + _field.size.x * 0.5
	return Vector2(cx + (n.x - 0.5) * _field.size.x * _depth(n.y), _field.position.y + _gy(n.y) * _field.size.y)

## Polilínea en coordenadas de cancha (muestreada: con perspectiva las
## verticales se curvan apenas).
func _line_n(a: Vector2, b: Vector2, col: Color, w: float, steps: int = 10) -> void:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		pts.append(_pw(_e(a.lerp(b, float(i) / steps))))
	draw_polyline(pts, col, w)

func _rect_n(x0: float, y0: float, x1: float, y1: float, col: Color, w: float) -> void:
	_line_n(Vector2(x0, y0), Vector2(x1, y0), col, w)
	_line_n(Vector2(x1, y0), Vector2(x1, y1), col, w)
	_line_n(Vector2(x1, y1), Vector2(x0, y1), col, w)
	_line_n(Vector2(x0, y1), Vector2(x0, y0), col, w)

func _poly_n(pts_n: Array, col: Color) -> void:
	var pts := PackedVector2Array()
	for q in pts_n:
		pts.append(_pw(q))
	if cam_mode != "arco":
		# Con las otras proyecciones una franja lejana puede quedar de canto
		# (área ~0) y eso no se puede triangular: se saltea.
		var area: float = 0.0
		for k in range(pts.size()):
			var k2: int = (k + 1) % pts.size()
			area += pts[k].x * pts[k2].y - pts[k2].x * pts[k].y
		if absf(area) < 8.0:
			return
	draw_colored_polygon(pts, col)

## Arco de circunferencia (radio en unidades de ANCHO de cancha).
func _arc_n(c: Vector2, r: float, a0: float, a1: float, col: Color, w: float, steps: int = 32, min_y: float = -9.0) -> void:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var a: float = lerpf(a0, a1, float(i) / steps)
		var q := c + Vector2(cos(a) * r, sin(a) * r / FIELD_ASPECT)
		if q.y >= min_y:
			pts.append(_pw(_e(q)))
	if pts.size() >= 2:
		draw_polyline(pts, col, w)

func _draw() -> void:
	_layout_field()
	var f := _field
	# Césped con el corte del estadio (grass_for).
	var full := Rect2(Vector2.ZERO, size)
	draw_rect(full, grass_a if cam_mode == "arco" else grass_a.darkened(0.30))
	_cam_sync()
	draw_set_transform(_cam_offset(), 0.0, Vector2(cam_zoom, cam_zoom))
	_draw_grass()
	# Rectángulo (sin cámara) de la cancha ENTERA, para clima y reflectores.
	var ff := Rect2(f.position, Vector2(f.size.x, maxf(f.size.y, _pw(Vector2(0.5, 2.0)).y - f.position.y)))
	if cam_mode == "arco":
		_draw_pitch_details(f)
		if weather == "rain" or weather == "snow":
			_draw_weather_ground(ff)
	else:
		_draw_surround_generic()
	var lw: float = clampf(f.size.x * 0.004 / WORLD_SCALE * 1.2, 1.5, 3.0)
	# Contorno, línea del medio y círculo central.
	_end = 0
	_line_n(Vector2(0.0, 0.0), Vector2(1.0, 0.0), LINE, lw)
	_line_n(Vector2(1.0, 0.0), Vector2(1.0, 2.0), LINE, lw, 24)
	_line_n(Vector2(1.0, 2.0), Vector2(0.0, 2.0), LINE, lw)
	_line_n(Vector2(0.0, 2.0), Vector2(0.0, 0.0), LINE, lw, 24)
	_line_n(Vector2(0.0, 1.0), Vector2(1.0, 1.0), LINE, lw)
	_arc_n(Vector2(0.5, 1.0), CIRCLE_R, 0.0, TAU, LINE, lw, 48)
	draw_circle(_pw(Vector2(0.5, 1.0)), lw * 1.4, LINE)
	# En cada extremo: área grande, área chica, punto penal y medialuna.
	for e in [0, 1]:
		_end = e
		_rect_n(0.5 - BOX_W * 0.5, 0.0, 0.5 + BOX_W * 0.5, BOX_D, LINE, lw)
		_rect_n(0.5 - SMALL_W * 0.5, 0.0, 0.5 + SMALL_W * 0.5, SMALL_D, LINE, lw)
		draw_circle(_pw(_e(Vector2(0.5, SPOT_D))), lw * 1.4, LINE)
		_arc_n(Vector2(0.5, SPOT_D), CIRCLE_R, 0.0, PI, LINE, lw, 32, BOX_D)
	_end = 0
	_draw_cloud_shadows()
	if cam_mode == "arco":
		_draw_boards(f)
		_draw_corner_flags(f, lw)
		_draw_goal(f, lw, 0)
		# (Tu arco se dibuja más abajo, en el pase ordenado: queda entre la
		# cámara y los jugadores, así que los tapa.)
		if night:
			_draw_floodlights(ff)
	else:
		_draw_goal_generic(lw, 0)
		_draw_goal_generic(lw, 1)
		if night:
			draw_rect(Rect2(Vector2(-3000, -3000), size + Vector2(6000, 6000)), Color(0.0, 0.02, 0.09, 0.42))

	# Fichas: primero las sombras, después los cuerpos (el usuario arriba).
	var r: float = clampf(f.size.x * 0.034, 9.0, 16.0)
	var order: Array = _actors.keys()
	# Profundidad: el que está más abajo en la cancha (más "cerca") tapa al
	# de atrás — con personajes de cuerpo entero se nota mucho.
	if _plain():
		order.sort_custom(func(a, b): return (_actors[a]["pos"] as Vector2).y < (_actors[b]["pos"] as Vector2).y)
	else:
		# En las otras cámaras "más cerca" es más abajo EN PANTALLA.
		order.sort_custom(func(a, b): return _p(_actors[a]["pos"]).y < _p(_actors[b]["pos"]).y)
	for id in order:
		var sa: Dictionary = _actors[id]
		if bool(sa.get("hidden", false)):
			continue
		if sa.has("sprite") or not (sa["anims"] as Dictionary).is_empty():
			# Personaje: sombra chata bajo los pies (no un disco en el pecho).
			var sh := PackedVector2Array()
			var fc: Vector2 = _p(sa["pos"]) + Vector2(1.0, r * 0.3)
			for k in range(16):
				var ang: float = TAU * k / 16.0
				sh.append(fc + Vector2(cos(ang) * r * 0.85, sin(ang) * r * 0.32))
			draw_colored_polygon(sh, Color(0, 0, 0, 0.28))
		else:
			draw_circle(_p(sa["pos"]) + Vector2(1.5, 2.5), r, Color(0, 0, 0, 0.30))
	var font: Font = Styles.font_semibold()
	# Nombres: se juntan acá y se dibujan DESPUÉS de todos los cuerpos, sin
	# pisarse (P0, 9-oct: "nombres que se pisan cuando dos están juntos").
	var labels: Array = []
	_ball_drawn = false
	var ball_y: float = _p(_ball).y
	# UN SOLO PASE ordenado por profundidad (más abajo en pantalla = más
	# cerca = tapa): jugadores, objetos del estadio, jueces de línea y tu arco.
	var items: Array = []
	for id0 in order:
		items.append([_p(_actors[id0]["pos"]).y, "actor", id0])
	for pr in _prop_items():
		items.append([_pw(pr["w"]).y, "prop", pr])
	for li in range(2):
		items.append([_pw(_linesman_w(li)).y, "line", li])
	if cam_mode == "arco":
		items.append([_pw(Vector2(0.5, 2.0)).y - 1.0, "goal", 1])
	if _str_on:
		items.append([_p(_str_pos).y + 2.0, "stretcher", 0])
	items.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	for it in items:
		if it[1] == "prop":
			var pd: Dictionary = it[2]
			_draw_prop(String(pd["name"]), pd["w"], bool(pd.get("flip", false)), float(pd.get("lift", 0.0)), Color(0.62, 0.64, 0.78) if night else Color.WHITE, float(pd.get("fps", 0.0)))
			if bool(pd.get("flash", false)):
				draw_circle(_pw(pd["w"]) + Vector2(0, -14), 6.0, Color(1, 1, 1, 0.9))
			continue
		if it[1] == "line":
			_draw_linesmen(int(it[2]))
			continue
		if it[1] == "goal":
			_draw_goal(f, lw, 1)
			continue
		if it[1] == "stretcher":
			# CARRITO MÉDICO (11-oct, Wilber: "cambiemos la lesión por una
			# ambulancia o un carrito... se ve rara con el jugador arrastrado
			# por el piso"). Si falta el arte, los camilleros de antes.
			var stx: Texture2D = _prop("medcart")
			if stx == null:
				stx = _prop_now("medics", 9.0) if _str_moving else _prop("medics")
			if stx != null:
				var sp: Vector2 = _p(_str_pos)
				var ssz: Vector2 = stx.get_size()
				# Mira hacia donde va (el arte mira a la izquierda) y traquetea.
				var going_right: bool = _p(_str_to).x > _p(_str_from).x
				var bump: float = roundf(sin(_live_t * 22.0)) if _str_moving else 0.0
				draw_colored_polygon(PackedVector2Array([sp + Vector2(-22, 2), sp + Vector2(22, 2), sp + Vector2(18, 7), sp + Vector2(-18, 7)]), Color(0, 0, 0, 0.25))
				draw_texture_rect(stx, Rect2(sp - Vector2(ssz.x * 0.5, ssz.y - 8.0 + bump), Vector2(-ssz.x if going_right else ssz.x, ssz.y)), false)
			continue
		var id = it[2]
		var a: Dictionary = _actors[id]
		if bool(a.get("hidden", false)):
			continue
		var c := _p(a["pos"])
		# La pelota por el piso va DETRÁS de quien está más cerca de la cámara.
		if not _ball_drawn and _ball_h < 0.6 and c.y > ball_y + 2.0:
			_draw_ball(r)
		var frames: Array = []
		# CONDUCCION (11-oct, PixelLab): quien corre CON la pelota usa su propia
		# animacion (pasos cortos, mirando el balon) en vez de la carrera libre.
		# Dirección que se VE (va girando de a 45°, ver _process).
		var shown_anim: String = String(a["anim"])
		if shown_anim.begins_with("run_") and a.has("vdir"):
			shown_anim = "run_" + String(DIRS8[int(a["vdir"])])
		if shown_anim.begins_with("run_") and (id == _ball_follow or (ambient and id == _amb_holder)):
			frames = _frames(a, "drib_" + shown_anim.substr(4))
		if frames.is_empty():
			frames = _frames(a, shown_anim)
		if not frames.is_empty():
			if a["user"]:
				# Aro bajo los pies: dónde estás vos entre 20 jugadores iguales.
				var ring := PackedVector2Array()
				for k in range(29):
					var ang: float = TAU * k / 28.0
					ring.append(c + Vector2(0, r * 0.3) + Vector2(cos(ang) * r * 1.1, sin(ang) * r * 0.5))
				draw_polyline(ring, Color(1.0, 0.86, 0.25, 0.95), 2.5)
			# 11-oct (Wilber: "la animación de pateo va más lenta que el tiro y
			# la salida del balón"). Causa: el gesto iba a 10 cuadros/s (el pie
			# llegaba a la pelota a los ~0,45 s) y la pelota salía a los 0,20 s.
			# Los golpes van a KICK_FPS: el contacto cae justo cuando sale.
			var afps: float = KICK_FPS if String(a["anim"]) in KICK_ANIMS else SPRITE_FPS
			var idx: int = int((Time.get_ticks_msec() - int(a["anim_t0"])) / 1000.0 * afps * (0.4 if _slowmo else 1.0))
			if String(a["anim"]).begins_with("run_"):
				# PASOS AL RITMO DE LO QUE AVANZA (11-oct, Wilber: "naturalidad,
				# movimientos bien hechos"): antes las piernas iban siempre a
				# 10 cuadros por segundo, corriera rapido o apenas se moviera
				# (los pies "patinaban"). Ahora el cuadro sale de la distancia
				# recorrida en pantalla.
				idx = int(float(a.get("stride", 0.0)) / STRIDE_PX)
			idx = idx % frames.size() if a["anim_loop"] else mini(idx, frames.size() - 1)
			var tex: Texture2D = frames[idx]
			# Escala por PÍXEL de origen (no por lienzo): los cuadros de
			# animación vienen en un lienzo más grande (68) que la pose (48)
			# pero centrados en el mismo punto, así no "salta" de tamaño.
			# Escala ENTERA (×1, ×2...): en pixel art una escala fraccionaria
			# (×1,47 en el celular) deja píxeles desparejos.
			var px_scale: float = maxf(1.0, roundf((r * 4.4) / 48.0))
			var sz: Vector2 = tex.get_size() * px_scale
			var top_left: Vector2 = c - Vector2(sz.x * 0.5, sz.y * 0.5 + r * 1.1)
			# RESPIRA (11-oct, "naturalidad"): parado no es una estatua — el torso
			# y la cabeza bajan 1 píxel al soltar el aire, cada uno a su tiempo. Es
			# por código (mismo dibujo), no arte nuevo.
			var breath_ph: float = fmod(Time.get_ticks_msec() / 1000.0 + float(hash(id) % 97) * 0.07, BREATH_SECS) / BREATH_SECS
			if String(a["anim"]) == "volada":
				# Volada a un ángulo: el salto es recto en el arte; acá se
				# inclina hacia el palo y se eleva mientras dura.
				var vp: float = float(idx) / maxf(float(frames.size() - 1), 1.0)
				var vang: float = float(a.get("vol_dir", 1.0)) * 0.80 * sin(PI * vp)
				var vlift: float = 22.0 * sin(PI * vp)
				draw_set_transform(_cam_offset() + (top_left + sz * 0.5 - Vector2(0, vlift)) * cam_zoom, vang, Vector2(cam_zoom, cam_zoom))
				draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false)
				draw_set_transform(_cam_offset(), 0.0, Vector2(cam_zoom, cam_zoom))
			elif String(a["anim"]) == "idle" and breath_ph > 0.55 and not _slowmo:
				var th: Vector2 = tex.get_size()
				var cut: float = floorf(th.y * BREATH_SPLIT)
				draw_texture_rect_region(tex, Rect2(top_left + Vector2(0, cut * px_scale), Vector2(sz.x, (th.y - cut) * px_scale)), Rect2(0, cut, th.x, th.y - cut))
				draw_texture_rect_region(tex, Rect2(top_left + Vector2(0, px_scale), Vector2(sz.x, cut * px_scale)), Rect2(0, 0, th.x, cut))
			else:
				draw_texture_rect(tex, Rect2(top_left, sz), false)
			if a["card"] is Color and a.has("sprite"):
				var cr2 := Rect2(c + Vector2(r * 0.5, -r * 3.4), Vector2(r * 0.7, r * 0.95))
				draw_rect(cr2, a["card"])
				draw_rect(cr2, Color(0, 0, 0, 0.6), false, 1.2)
			if a["user"]:
				# Flecha que rebota sobre tu cabeza (10-oct): el aro solo no
				# alcanzaba para encontrarte entre 20 jugadores.
				# ESTRELLA (10-oct, Wilber: "a mi jugador colocale una estrella
				# encima para diferenciarlo"): reemplaza a la flecha.
				var top: Vector2 = c + Vector2(0, -sz.y * 0.5 - r * 1.1 - 13.0 + sin(_pulse * 2.0) * 3.0)
				var star := PackedVector2Array()
				for sk in range(10):
					var sa2: float = -PI * 0.5 + TAU * sk / 10.0
					star.append(top + Vector2(cos(sa2), sin(sa2)) * (9.0 if sk % 2 == 0 else 4.0))
				draw_colored_polygon(star, Color(1.0, 0.86, 0.25))
				star.append(star[0])
				draw_polyline(star, Color(0, 0, 0, 0.8), 1.5)
				draw_circle(top + Vector2(-1.5, -1.5), 1.6, Color(1, 1, 0.85, 0.9))
			# El árbitro no lleva cartel: se reconoce por la ropa y su nombre
			# se pisaba con los de los jugadores.
			if String(a["name"]) != "" and not bool(a.get("ref", false)):
				labels.append([String(a["name"]), c + Vector2(0, r * 1.1 + 12.0), bool(a["user"]), c.y - sz.y - r * 1.1 + 6.0])
			continue
		if a["user"]:
			draw_arc(c, r + 5.0, 0, TAU, 32, Color(1, 1, 1, 0.9), 2.0)
		draw_circle(c, r, a["color"])
		draw_arc(c, r, 0, TAU, 32, Color(1.0, 0.85, 0.2, 0.9) if a["ref"] else Color(0, 0, 0, 0.45), 2.0 if a["ref"] else 1.5)
		if a["card"] is Color:
			# Tarjeta levantada sobre la cabeza.
			var cr := Rect2(c + Vector2(r * 0.35, -r * 2.5), Vector2(r * 0.75, r * 1.05))
			draw_rect(cr, a["card"])
			draw_rect(cr, Color(0, 0, 0, 0.6), false, 1.2)
		var num: String = a["num"]
		if num != "":
			var fs: int = int(r * 1.05)
			var tw: float = font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, c + Vector2(-tw * 0.5, fs * 0.36), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, a["text"])
		if String(a["name"]) != "":
			labels.append([String(a["name"]), c + Vector2(0, r + 13.0), bool(a["user"]), c.y - r * 2.6])
	_draw_labels(labels, font)

	if _slowmo:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var bar_h: float = size.y * 0.09
		draw_rect(Rect2(0, 0, size.x, bar_h), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(0, size.y - bar_h, size.x, bar_h), Color(0, 0, 0, 0.85))
		var fnt: Font = Styles.font_black()
		var txt := "REPETICIÓN · CÁMARA LENTA"
		var tw: float = fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(fnt, Vector2(size.x * 0.5 - tw * 0.5, bar_h * 0.7), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.3))
		draw_set_transform(_cam_offset(), 0.0, Vector2(cam_zoom, cam_zoom))
	# Minijuego de remate: línea de tiro + punto en el arco + fuerza.
	if _aim_mode:
		var bpos: Vector2 = _p(_ball)
		if _aim_drag:
			var ax: float = _aim_goal_x()
			var gp: Vector2 = _p(Vector2(ax, 0.0))
			var inside: bool = absf(ax - 0.5) <= GOAL_W * 0.5
			var col: Color = Color(1, 1, 1, 0.9) if inside else Color(1, 0.4, 0.35, 0.9)
			var segs: int = 18
			for i in range(segs):
				if i % 2 == 0:
					draw_line(bpos.lerp(gp, float(i) / segs), bpos.lerp(gp, float(i + 1) / segs), col, 2.0)
			# Mira sobre la línea de gol (se desliza con el arrastre lateral).
			draw_arc(gp, 6.0, 0, TAU, 16, col, 2.0)
			draw_line(gp + Vector2(-9, 0), gp + Vector2(-3, 0), col, 2.0)
			draw_line(gp + Vector2(3, 0), gp + Vector2(9, 0), col, 2.0)
			draw_line(gp + Vector2(0, -9), gp + Vector2(0, -3), col, 2.0)
			# (La fuerza ya no va en el arrastre: después de apuntar viene la
			# barra clásica — 9-oct. El indicador queda solo si se pide.)
			var pw: float = _aim_power()
			var ok: bool = absf(pw - DecisionResolver.SHOT_POWER_IDEAL) <= _aim_band
			var bar := Rect2(bpos + Vector2(16, -30), Vector2(7, 40 if aim_power_gauge else 0))
			draw_rect(bar, Color(0, 0, 0, 0.5))
			var lo: float = clampf(DecisionResolver.SHOT_POWER_IDEAL - _aim_band, 0.0, 1.0)
			var hi: float = clampf(DecisionResolver.SHOT_POWER_IDEAL + _aim_band, 0.0, 1.0)
			if aim_power_gauge:
				draw_rect(Rect2(bar.position + Vector2(0, bar.size.y * (1.0 - hi)), Vector2(bar.size.x, bar.size.y * (hi - lo))), Color(0.2, 0.9, 0.4, 0.45))
				var fill_h: float = bar.size.y * clampf(pw, 0.0, 1.0)
				draw_rect(Rect2(bar.position + Vector2(1, bar.size.y - fill_h), Vector2(bar.size.x - 2, fill_h)), Color(0.3, 1.0, 0.5) if ok else Color(1.0, 0.8, 0.3))
		else:
			# Pista: flechas ◀ ▶ que laten (se apunta arrastrando a los costados).
			var a: float = 0.5 + 0.5 * sin(_pulse * 2.0)
			var pc := Color(1, 0.85, 0.3, a)
			# Las flechas siguen la dirección en que hay que arrastrar (la de
			# la línea de gol en pantalla; en "arco", a los costados).
			var gdn: Vector2 = screen_dir_x()
			var gpn := Vector2(-gdn.y, gdn.x)
			var lift_v := Vector2(0, -10.0) if cam_mode == "arco" else Vector2.ZERO
			for sgn in [-1.0, 1.0]:
				var tip: Vector2 = bpos + gdn * sgn * 26.0 + lift_v
				draw_line(bpos + gdn * sgn * 10.0 + lift_v, tip, pc, 2.0)
				draw_line(tip, tip - gdn * sgn * 6.0 - gpn * 5.0, pc, 2.0)
				draw_line(tip, tip - gdn * sgn * 6.0 + gpn * 5.0, pc, 2.0)

	if _mg != null:
		_mg.draw(self)
	# Líneas de tiro: la misma curva que va a hacer la pelota.
	if not shot_previews.is_empty():
		var p0: Vector2 = _ball
		var p1: Vector2 = shot_preview_to
		var alongp: Vector2 = p1 - p0
		var sidep: Vector2 = Vector2(-alongp.y, alongp.x).normalized()
		for pv in shot_previews:
			var pts := PackedVector2Array()
			for k in range(21):
				var tt: float = float(k) / 20.0
				pts.append(_p(p0.lerp(p1, tt) + sidep * float(pv.get("curve", 0.0)) * sin(PI * tt)))
			var pcol: Color = pv.get("color", Color.WHITE)
			var pwid: float = float(pv.get("width", 2.5))
			# Punteada: tramos alternados.
			for k in range(0, 20, 2):
				draw_line(pts[k], pts[k + 1], pcol, pwid)
			draw_circle(pts[20], 4.0, pcol)
	# Cartel de cambio sobre el cuarto árbitro.
	if not _board.is_empty() and _actors.has(String(_board.get("id", ""))):
		var bc: Vector2 = _p(_actors[String(_board["id"])]["pos"]) + Vector2(0, -r * 4.6)
		var brect := Rect2(bc - Vector2(26, 13), Vector2(52, 24))
		draw_line(bc + Vector2(0, 11), bc + Vector2(0, r * 2.2), Color(0.2, 0.2, 0.22), 3.0)
		draw_rect(brect, Color(0.04, 0.04, 0.06))
		draw_rect(brect, Color(0.75, 0.75, 0.8), false, 1.5)
		draw_line(bc + Vector2(0, -12), bc + Vector2(0, 10), Color(0.3, 0.3, 0.34), 1.0)
		var bfont: Font = Styles.font_black()
		var o_txt: String = String(_board.get("out", ""))
		var i_txt: String = String(_board.get("in", ""))
		var ow: float = bfont.get_string_size(o_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var iw: float = bfont.get_string_size(i_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(bfont, bc + Vector2(-13 - ow * 0.5, 5), o_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.25, 0.22))
		draw_string(bfont, bc + Vector2(13 - iw * 0.5, 5), i_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.3, 1.0, 0.4))

	# Línea de fuera de juego (VAR).
	if _line_y > -1.0 and not _plain():
		_line_n(_w(Vector2(0.0, _line_y)), _w(Vector2(1.0, _line_y)), Color(0.35, 0.9, 1.0, 0.95), 2.5)
	elif _line_y > -1.0:
		var ly: float = _p(Vector2(0, _line_y)).y
		var xx: float = f.position.x
		while xx < f.end.x:
			draw_line(Vector2(xx, ly), Vector2(minf(xx + 8.0, f.end.x), ly), Color(0.35, 0.9, 1.0, 0.95), 2.0)
			xx += 13.0

	# Objetivos tocables: anillo punteado que late.
	if _interactive:
		var pr: float = r + 7.0 + sin(_pulse) * 2.5
		for t in _targets:
			var center := Vector2.ZERO
			var rad: float = pr
			if t == "goal":
				center = _p(Vector2(0.5, 0.0))
				rad = GOAL_W * f.size.x * 0.75 + sin(_pulse) * 2.5
				if cam_mode != "arco":
					rad = _p(Vector2(0.5 - GOAL_W * 0.5, 0.0)).distance_to(_p(Vector2(0.5 + GOAL_W * 0.5, 0.0))) * 0.75 + sin(_pulse) * 2.5
			elif _actors.has(t):
				center = _p(_actors[t]["pos"])
			else:
				continue
			var segs: int = 14
			for i in range(segs):
				if i % 2 == 0:
					var a0: float = TAU * i / segs + _pulse * 0.3
					draw_arc(center, rad, a0, a0 + TAU / segs, 4, Color(1.0, 0.85, 0.3, 0.95), 2.0)

	if not _ball_drawn:
		_draw_ball(r)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_weather()
	_draw_confetti()
	_draw_minimap()

## Entorno de las cámaras "tv" e "iso": tribuna del otro lado de la
## cancha (TV) con público en los colores de los equipos.
func _draw_surround_generic() -> void:
	if cam_mode == "iso":
		_draw_surround_iso()
		return
	if cam_mode != "tv":
		return
	var tl: Vector2 = _pw(Vector2(0.0, 2.0))      # banda de enfrente, del lado de mitad de cancha
	var tr2: Vector2 = _pw(Vector2(0.0, 0.0))     # banda de enfrente, del lado del arco
	var top_y: float = minf(tl.y, tr2.y) - 10.0
	draw_rect(Rect2(Vector2(-3000, -3000), Vector2(size.x + 6000, top_y + 3000)), Color(0.09, 0.10, 0.13))
	var cols: Array = board_colors if not board_colors.is_empty() else [Color(0.15, 0.3, 0.6), Color(0.85, 0.85, 0.9)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var t: float = Time.get_ticks_msec() / 1000.0
	var rows: int = 9
	for row in range(rows):
		var y: float = top_y - 8.0 - row * 13.0
		draw_rect(Rect2(Vector2(tl.x - 60.0, y + 8.0), Vector2(tr2.x - tl.x + 120.0, 2)), Color(1, 1, 1, 0.05))
		var x: float = tl.x - 50.0 + rng.randf_range(-6.0, 4.0)
		while x < tr2.x + 50.0:
			var c: Color = (cols[rng.randi() % cols.size()] as Color).lerp(Color(0.6, 0.5, 0.45), rng.randf_range(0.0, 0.5))
			var hop: float = (absf(sin(t * 9.0 + x * 0.3)) * 3.0) if _crowd_hype > 0.0 else (roundf(sin(t * 2.2 + x * 0.7 + row)) * 0.6 + 0.6)
			hop += _wave_lift((x - tl.x) / maxf(tr2.x - tl.x, 1.0))
			draw_circle(Vector2(x, y - hop), 2.6, Color(0.85, 0.7, 0.55).darkened(rng.randf_range(0.1, 0.5)))
			draw_rect(Rect2(Vector2(x - 3.0, y + 2.5 - hop), Vector2(6, 5)), c.darkened(0.2))
			x += rng.randf_range(8.0, 11.0)
	_draw_stand_life(Rect2(Vector2(tl.x - 40.0, top_y - 8.0 - rows * 13.0), Vector2(tr2.x - tl.x + 80.0, rows * 13.0)))
	# Vallas a lo largo de la banda de enfrente.
	var n: int = 16
	for i in range(n):
		var a: Vector2 = tl.lerp(tr2, float(i) / n)
		var b: Vector2 = tl.lerp(tr2, float(i + 1) / n)
		var bc: Color = (cols[i % cols.size()] as Color).darkened(0.15)
		draw_colored_polygon(PackedVector2Array([a + Vector2(0, -16), b + Vector2(-2, -16), b + Vector2(-2, -5), a + Vector2(0, -5)]), bc)

## DESDE LA TRIBUNA (11-oct, Wilber: "que las otras cámaras sean cuando no
## esté convocado y poder verlos desde el estadio"). La isométrica no tenía
## estadio alrededor (pasto oscuro hasta el borde). Ahora tiene piso de
## cemento alrededor de la cancha, tribunas con gente en los dos lados del
## fondo y vallas en los colores de los equipos.
func _draw_surround_iso() -> void:
	var concrete := Color(0.13, 0.14, 0.17)
	_poly_n([Vector2(-0.75, -0.75), Vector2(1.75, -0.75), Vector2(1.75, 2.75), Vector2(-0.75, 2.75)], concrete)
	# El pasto de la cancha y su franja de seguridad vuelven encima.
	_poly_n([Vector2(-0.16, -0.12), Vector2(1.16, -0.12), Vector2(1.16, 2.12), Vector2(-0.16, 2.12)], grass_a.darkened(0.12))
	var tex: Texture2D = _prop("crowd")
	var cols: Array = board_colors if not board_colors.is_empty() else [Color(0.15, 0.3, 0.6), Color(0.85, 0.85, 0.9)]
	# Tribunas del fondo: detrás del arco de arriba (y < 0) y de la banda
	# izquierda (x < 0) — las dos que quedan "lejos" en esta vista.
	if tex != null:
		var src := Rect2(0, 0, 100, 40)
		for row in range(3):
			var off: float = 0.26 + row * 0.11
			var shade: float = 0.92 - row * 0.14
			for k in range(15):
				var c1: Vector2 = _pw(Vector2(-0.2 + k * 0.1, -off * 1.3))
				draw_texture_rect_region(tex, Rect2(c1 - Vector2(50, 28 + row * 6), Vector2(100, 40)), src, Color(shade, shade, shade + 0.04))
			for k in range(26):
				var c2: Vector2 = _pw(Vector2(-off, -0.25 + k * 0.1))
				draw_texture_rect_region(tex, Rect2(c2 - Vector2(50, 28 + row * 6), Vector2(100, 40)), src, Color(shade, shade, shade + 0.04))
	# Vallas alrededor.
	for k in range(14):
		var bc: Color = (cols[k % cols.size()] as Color).darkened(0.15)
		_line_n(Vector2(-0.14, 0.02 + k * 0.14), Vector2(-0.14, 0.145 + k * 0.14), bc, 5.0, 2)
		_line_n(Vector2(1.14, 0.02 + k * 0.14), Vector2(1.14, 0.145 + k * 0.14), bc, 5.0, 2)
	for k in range(8):
		var bc2: Color = (cols[k % cols.size()] as Color).darkened(0.15)
		_line_n(Vector2(k / 8.0, -0.10), Vector2(k / 8.0 + 0.115, -0.10), bc2, 5.0, 2)
		_line_n(Vector2(k / 8.0, 2.10), Vector2(k / 8.0 + 0.115, 2.10), bc2, 5.0, 2)

## Arco para "tv" e "iso": mismos elementos que el de siempre (postes que
## suben, travesaño, red en caja, sombra) pero armado con los dos postes en
## pantalla y la dirección "hacia atrás del arco", así sirve en cualquier
## orientación.
func _draw_goal_generic(lw: float, end: int = 0) -> void:
	_end = end
	var pl: Vector2 = _pw(_e(Vector2(0.5 - GOAL_W * 0.5, 0.0)))
	var pr: Vector2 = _pw(_e(Vector2(0.5 + GOAL_W * 0.5, 0.0)))
	var back: Vector2 = _pw(_e(Vector2(0.5, -0.07))) - _pw(_e(Vector2(0.5, 0.0)))
	var r: float = clampf(_field.size.x * 0.034, 9.0, 16.0)
	var body_h: float = 40.0 * maxf(1.0, roundf((r * 4.4) / 48.0))
	var up := Vector2(0, -body_h * 1.35)
	var bl: Vector2 = pl + back
	var br: Vector2 = pr + back
	var net := Color(1, 1, 1, 0.10)
	var mesh := Color(1, 1, 1, 0.28)
	# Sombra.
	var sh := Vector2(absf(up.y) * 0.3, absf(up.y) * 0.1)
	draw_line(pl + sh, pr + sh, Color(0, 0, 0, 0.22), maxf(2.0, lw * 1.6))
	# Red: fondo, laterales, techo.
	for poly in [[bl, bl + up * 0.82, br + up * 0.82, br], [pl, pl + up, bl + up * 0.82, bl], [pr, pr + up, br + up * 0.82, br], [pl + up, pr + up, br + up * 0.82, bl + up * 0.82]]:
		var pts := PackedVector2Array(poly)
		# Una cara de canto (área ~0) no se puede triangular: se saltea.
		var area: float = 0.0
		for q in range(pts.size()):
			var q2: int = (q + 1) % pts.size()
			area += pts[q].x * pts[q2].y - pts[q2].x * pts[q].y
		if absf(area) > 12.0:
			draw_colored_polygon(pts, net)
	var cols: int = 8
	for i in range(cols + 1):
		var t: float = float(i) / cols
		draw_line(bl.lerp(br, t), (bl + up * 0.82).lerp(br + up * 0.82, t), mesh, 1.0)
		draw_line((pl + up).lerp(pr + up, t), (bl + up * 0.82).lerp(br + up * 0.82, t), mesh, 1.0)
	for j in range(1, 5):
		var t2: float = float(j) / 5.0
		draw_line(bl + up * 0.82 * t2, br + up * 0.82 * t2, mesh, 1.0)
		draw_line(pl + up * t2, bl + up * 0.82 * t2, mesh, 1.0)
		draw_line(pr + up * t2, br + up * 0.82 * t2, mesh, 1.0)
	# Postes y travesaño.
	var pw: float = maxf(3.0, lw * 2.0)
	for base in [pl, pr]:
		draw_line(base, base + up, Color.WHITE, pw)
		draw_line(base + Vector2(pw * 0.3, 0), base + up + Vector2(pw * 0.3, 0), Color(0.72, 0.74, 0.78), pw * 0.4)
	draw_line(pl + up, pr + up, Color.WHITE, pw)
	draw_circle(pl + up, pw * 0.5, Color.WHITE)
	draw_circle(pr + up, pw * 0.5, Color.WHITE)
	# Banderines de córner.
	for side in [0.0, 1.0]:
		var cb: Vector2 = _pw(_e(Vector2(side, 0.0)))
		draw_line(cb, cb - Vector2(0, 16), Color(0.95, 0.95, 0.95), 2.0)
		draw_colored_polygon(PackedVector2Array([cb - Vector2(0, 16), cb - Vector2(-8, 13), cb - Vector2(0, 10)]), Color(1.0, 0.82, 0.2))

	_end = 0

## Vallas publicitarias detrás del arco, en los colores de los equipos.
func _draw_boards(f: Rect2) -> void:
	var cols: Array = board_colors if not board_colors.is_empty() else [Color(0.15, 0.3, 0.6), Color(0.75, 0.75, 0.8)]
	var h: float = 14.0
	var y0: float = f.position.y - 46.0
	var left: float = _pw(Vector2(0.0, 0.0)).x
	var far_w: float = _pw(Vector2(1.0, 0.0)).x - left
	var seg: float = far_w / 8.0
	var logos: Array = _board_logos()
	for i in range(8):
		var c: Color = cols[i % cols.size()]
		var r := Rect2(Vector2(left + i * seg, y0), Vector2(seg - 2.0, h))
		draw_rect(r, c.darkened(0.15))
		# Vallas con los logos de los patrocinadores (P1, 9-oct); sin logo,
		# la franja blanca de siempre.
		if not logos.is_empty():
			var tex: Texture2D = logos[i % logos.size()]
			var ls: float = h - 2.0
			draw_texture_rect(tex, Rect2(r.position + Vector2((r.size.x - ls) * 0.5, 1.0), Vector2(ls, ls)), false)
		else:
			draw_rect(Rect2(r.position + Vector2(seg * 0.25, 5), Vector2(seg * 0.5 - 2.0, 3)), Color(1, 1, 1, 0.55))
	draw_rect(Rect2(Vector2(left, y0 + h), Vector2(far_w, 2)), Color(0, 0, 0, 0.35))
	# Valla LED: un barrido de luz la recorre cada pocos segundos.
	var sweep: float = fmod(_live_t * 0.22, 1.6) - 0.3
	if sweep > 0.0 and sweep < 1.0:
		draw_rect(Rect2(Vector2(left + far_w * sweep - 9.0, y0), Vector2(18, h)), Color(1, 1, 1, 0.22))
		draw_rect(Rect2(Vector2(left + far_w * sweep - 3.0, y0), Vector2(6, h)), Color(1, 1, 1, 0.28))

static var _logo_cache: Array = []
## Patrocinadores + marcas de guayos (los que tengan logo pixel).
static func _board_logos() -> Array:
	if _logo_cache.is_empty():
		var paths: Array = []
		for n in SponsorEngine.SPONSOR_NAMES:
			paths.append("res://assets/sponsors/%s.png" % BrandMark.slug(String(n)))
		for b in BootBrands.BRANDS:
			paths.append("res://assets/brands/%s.png" % String(b.get("logo", "")))
		for pth in paths:
			if ResourceLoader.exists(pth):
				_logo_cache.append(load(pth))
	return _logo_cache

## Banderines de córner en las dos esquinas de arriba.
func _draw_corner_flags(_f: Rect2, lw: float) -> void:
	for corner in [[0.0, 0.0, 0.0], [1.0, 0.0, PI * 0.5], [1.0, 2.0, PI], [0.0, 2.0, PI * 1.5]]:
		var base := _pw(Vector2(float(corner[0]), float(corner[1])))
		draw_arc(base, 9.0, float(corner[2]), float(corner[2]) + PI * 0.5, 8, LINE, lw)
		draw_line(base, base - Vector2(0, 16), Color(0.95, 0.95, 0.95), 2.0)
		var dir: float = 1.0 if float(corner[0]) == 0.0 else -1.0
		draw_colored_polygon(PackedVector2Array([base - Vector2(0, 16), base - Vector2(-8 * dir, 13 + sin(_live_t * 6.0 + base.x) * 2.0), base - Vector2(0, 10)]), Color(1.0, 0.82, 0.2))

## Arco con profundidad: red de fondo más chica (perspectiva), laterales,
## postes y travesaño gruesos.
## ARCO EN 3D (10-oct, Wilber: "mejorar las porterías que parecen
## enterradas al suelo"). Antes era un rectángulo de red APOYADO en el
## césped con los postes como puntos: se leía como un pozo. Ahora los
## postes SUBEN (alto = 2,44/7,32 del ancho), el travesaño va arriba, y la
## red es una caja: techo, fondo y laterales que caen hacia atrás, con su
## sombra proyectada en el pasto.
func _draw_goal(f: Rect2, lw: float, end: int = 0) -> void:
	var yg: float = 0.0 if end == 0 else 2.0
	var gl := _pw(Vector2(0.5 - GOAL_W * 0.5, yg))
	var gw: float = _pw(Vector2(0.5 + GOAL_W * 0.5, yg)).x - gl.x
	# Alto: NO sale del ancho (gw*0.30 daba un arco más BAJO que los
	# jugadores — "se ve aplastada", Wilber 10-oct). Causa: el arco estaba
	# a escala de la CANCHA y los jugadores son mucho más grandes que la
	# cancha (un sprite mide ~7 m de cancha). El travesaño (2,44 m) va a
	# ~1,35 alturas de jugador (1,80 m), así que se mide contra el sprite.
	var r: float = clampf(f.size.x * 0.034, 9.0, 16.0)
	var body_h: float = 40.0 * maxf(1.0, roundf((r * 4.4) / 48.0))   # cuerpo visible del sprite (48 px de lienzo)
	var gh: float = maxf(gw * 0.30, body_h * 1.35)
	var gd: float = clampf(gw * 0.20, 12.0, 26.0) * (1.0 if end == 0 else -1.0) # fondo de la red hacia atrás (abajo: hacia la cámara)
	var inset: float = gw * 0.06
	var front_l := gl
	var front_r := gl + Vector2(gw, 0)
	var top_l := front_l - Vector2(0, gh)
	var top_r := front_r - Vector2(0, gh)
	var back_l := gl + Vector2(inset, -gd)                 # base de la red, atrás
	var back_r := gl + Vector2(gw - inset, -gd)
	var btop_l := back_l - Vector2(0, gh * 0.78)           # la red cae un poco hacia atrás
	var btop_r := back_r - Vector2(0, gh * 0.78)
	# Sombra del arco en el césped (luz de arriba-izquierda).
	var sh := Vector2(gh * 0.35, gh * 0.12)
	draw_line(front_l + Vector2(2, 1), front_l + sh + Vector2(0, 2), Color(0, 0, 0, 0.28), maxf(2.0, lw * 1.6))
	draw_line(front_r + Vector2(2, 1), front_r + sh + Vector2(0, 2), Color(0, 0, 0, 0.28), maxf(2.0, lw * 1.6))
	draw_line(front_l + sh + Vector2(0, 2), front_r + sh + Vector2(0, 2), Color(0, 0, 0, 0.22), maxf(2.0, lw * 1.6))
	# Red: fondo, laterales y techo (translúcidos) + malla.
	var net := Color(1, 1, 1, 0.10)
	var mesh := Color(1, 1, 1, 0.28)
	if end == 0:
		draw_colored_polygon(PackedVector2Array([back_l, btop_l, btop_r, back_r]), Color(0.05, 0.08, 0.06, 0.35))
	draw_colored_polygon(PackedVector2Array([back_l, btop_l, btop_r, back_r]), net)
	draw_colored_polygon(PackedVector2Array([front_l, top_l, btop_l, back_l]), net)
	draw_colored_polygon(PackedVector2Array([front_r, top_r, btop_r, back_r]), net)
	draw_colored_polygon(PackedVector2Array([top_l, top_r, btop_r, btop_l]), Color(1, 1, 1, 0.14))
	var cols: int = maxi(4, int(gw / 7.0))
	# LA RED SE HUNDE Y VIBRA donde entró la pelota (se apaga en ~1,5 s).
	var age: float = _live_t - _net_t
	var hit: bool = end == _net_end and age >= 0.0 and age < 1.6
	var amp: float = 15.0 * exp(-3.0 * age) * cos(age * 15.0) + (9.0 * exp(-2.2 * age)) if hit else 0.0
	var hx: float = clampf((_net_x - (0.5 - GOAL_W * 0.5)) / GOAL_W, 0.0, 1.0)
	var away := Vector2(0, -1.0 if end == 0 else 1.0)   # hacia atrás del arco
	var mesh_hit: Color = Color(1, 1, 1, 0.5) if hit else mesh
	for i in range(cols + 1):
		var t: float = float(i) / cols
		if hit:
			var pts := PackedVector2Array()
			for k in range(5):
				var ty: float = float(k) / 4.0
				var w0: float = exp(-pow((t - hx) / 0.22, 2.0)) * sin(PI * clampf(ty * 0.8 + 0.1, 0.0, 1.0))
				pts.append(back_l.lerp(back_r, t).lerp(btop_l.lerp(btop_r, t), ty) + away * amp * w0)
			draw_polyline(pts, mesh_hit, 1.0)
		else:
			draw_line(back_l.lerp(back_r, t), btop_l.lerp(btop_r, t), mesh, 1.0)      # fondo, verticales
		draw_line(top_l.lerp(top_r, t), btop_l.lerp(btop_r, t), mesh, 1.0)        # techo
	for j in range(1, 5):
		var t2: float = float(j) / 5.0
		if hit:
			var pts2 := PackedVector2Array()
			for k in range(cols + 1):
				var tx: float = float(k) / cols
				var w1: float = exp(-pow((tx - hx) / 0.22, 2.0)) * sin(PI * clampf(t2 * 0.8 + 0.1, 0.0, 1.0))
				pts2.append(back_l.lerp(back_r, tx).lerp(btop_l.lerp(btop_r, tx), t2) + away * amp * w1)
			draw_polyline(pts2, mesh_hit, 1.0)
		else:
			draw_line(back_l.lerp(btop_l, t2), back_r.lerp(btop_r, t2), mesh, 1.0)    # fondo, horizontales
		draw_line(front_l.lerp(top_l, t2), back_l.lerp(btop_l, t2), mesh, 1.0)    # lateral izq
		draw_line(front_r.lerp(top_r, t2), back_r.lerp(btop_r, t2), mesh, 1.0)    # lateral der
	draw_line(back_l, back_r, Color(1, 1, 1, 0.45), 1.5)
	draw_line(btop_l, btop_r, Color(1, 1, 1, 0.40), 1.2)
	draw_line(top_l, btop_l, Color(1, 1, 1, 0.40), 1.2)
	draw_line(top_r, btop_r, Color(1, 1, 1, 0.40), 1.2)
	# Postes que SUBEN + travesaño, con sombreado de un lado (volumen).
	var pw: float = maxf(3.0, lw * 2.0)
	for pair in [[front_l, top_l], [front_r, top_r]]:
		draw_line(pair[0], pair[1], Color.WHITE, pw)
		draw_line(pair[0] + Vector2(pw * 0.3, 0), pair[1] + Vector2(pw * 0.3, 0), Color(0.72, 0.74, 0.78), pw * 0.4)
	draw_line(top_l, top_r, Color.WHITE, pw)
	draw_line(top_l + Vector2(0, pw * 0.3), top_r + Vector2(0, pw * 0.3), Color(0.72, 0.74, 0.78), pw * 0.4)
	draw_circle(top_l, pw * 0.5, Color.WHITE)
	draw_circle(top_r, pw * 0.5, Color.WHITE)

## ------------------------------------------------------------------
## ESTADIO VIVO (10-oct, Wilber: "la cancha y el estadio (detalles)
## animados"). Todo procedural y barato: nada de esto sabe del partido,
## solo de `_crowd_hype` (gol / ocasión) y del reloj.
var _live_t: float = 0.0
var _lm_y: Array = [0.5, 1.5]     # jueces de línea: y (mundo) de cada uno
var _flag_up: bool = false        # banderín levantado (fuera de juego)

## Altura extra de un hincha por LA OLA (u = 0..1 a lo largo de la tribuna).
func _wave_lift(u: float) -> float:
	var cyc: float = fmod(_live_t, 17.0)
	if cyc > 3.2:
		return 0.0
	var front: float = cyc / 3.2 * 1.3 - 0.15
	var d: float = absf(u - front)
	return maxf(0.0, 1.0 - d / 0.09) * 5.0

## Destello pseudoaleatorio estable por cuadro corto (flashes de cámaras).
func _flash_on(salt: float, chance: float) -> bool:
	var slot: float = floorf(_live_t * 9.0)
	return fmod(absf(sin(slot * 12.9898 + salt * 78.233) * 43758.5453), 1.0) < chance

## Banderas que flamean, trapos y flashes en una tribuna (rect en píxeles
## de cancha, sin cámara).
func _draw_stand_life(r: Rect2) -> void:
	var cols: Array = board_colors if not board_colors.is_empty() else [Color(0.15, 0.3, 0.6), Color(0.85, 0.85, 0.9)]
	# Banderas grandes: mástil + paño que ondea en 3 tramos.
	for k in range(5):
		var fx: float = r.position.x + r.size.x * (0.08 + 0.21 * k)
		var fy: float = r.position.y + r.size.y * (0.75 - 0.12 * (k % 3))
		var sway: float = sin(_live_t * (1.6 + 0.2 * k) + k) * (7.0 if _crowd_hype > 0.0 else 3.5)
		var top := Vector2(fx + sway, fy - 26.0)
		draw_line(Vector2(fx, fy), top, Color(0.75, 0.75, 0.78), 1.5)
		var col: Color = cols[k % cols.size()]
		var pts := PackedVector2Array([top])
		for sgi in range(1, 4):
			pts.append(top + Vector2(6.0 * sgi, sin(_live_t * 5.0 + k + sgi * 0.9) * 2.5))
		for sgi in range(3, 0, -1):
			pts.append(top + Vector2(6.0 * sgi, 10.0 + sin(_live_t * 5.0 + k + sgi * 0.9) * 2.5))
		pts.append(top + Vector2(0, 10))
		draw_colored_polygon(pts, col)
		draw_line(top + Vector2(0, 5), top + Vector2(18, 5 + sin(_live_t * 5.0 + k + 2.7) * 2.5), cols[(k + 1) % cols.size()], 2.0)
	# Flashes de cámaras: pocos siempre, muchos con el gol o de noche.
	var n: int = 26 if _crowd_hype > 0.0 else (10 if night else 4)
	for k in range(n):
		if _flash_on(float(k) * 3.7, 0.16):
			var slot: float = floorf(_live_t * 9.0) + float(k) * 17.0
			var px := Vector2(r.position.x + fmod(absf(sin(slot * 3.11) * 9973.0), 1.0) * r.size.x, r.position.y + fmod(absf(sin(slot * 7.77) * 7919.0), 1.0) * r.size.y)
			draw_circle(px, 2.2, Color(1, 1, 1, 0.95))
			draw_circle(px, 5.0, Color(1, 1, 1, 0.25))

## Sombras de nubes que cruzan el pasto (de día, sin lluvia).
func _draw_cloud_shadows() -> void:
	if night or weather == "rain" or weather == "snow":
		return
	var zoom := Vector2(cam_zoom, cam_zoom)
	for k in range(3):
		var u: float = fmod(_live_t * (0.012 + 0.004 * k) + k * 0.37, 1.4) - 0.2
		var c: Vector2 = _pw(Vector2(u, 0.25 + k * 0.7))
		var rad: float = _field.size.x * (0.20 + 0.05 * k)
		draw_set_transform(_cam_offset() + c * cam_zoom, 0.0, zoom * Vector2(1.0, 0.42))
		draw_circle(Vector2.ZERO, rad, Color(0, 0, 0, 0.055))
		draw_circle(Vector2(rad * 0.5, rad * 0.2), rad * 0.7, Color(0, 0, 0, 0.045))
	draw_set_transform(_cam_offset(), 0.0, zoom)

## JUECES DE LÍNEA (10-oct, Wilber: "agregar jueces de línea"): uno por
## banda, cada uno en una mitad, siguiendo la jugada. Levantan el banderín
## cuando una jugada pide "flag" (fuera de juego).
func _linesman_w(i: int) -> Vector2:
	return Vector2(1.05 if i == 0 else -0.05, float(_lm_y[i]))

func _draw_linesmen(only: int = -1) -> void:
	var ball_top: bool = _w(_ball).y <= 1.0
	var art: Dictionary = _linesman_art()
	for i in range(2):
		if only >= 0 and i != only:
			continue
		var wpos := Vector2(1.05 if i == 0 else -0.05, float(_lm_y[i]))
		var base: Vector2 = _pw(wpos)
		var up: bool = _flag_up and (ball_top == (i == 0))
		if up and _lm_up_t[i] < 0.0:
			_lm_up_t[i] = _live_t
		elif not up:
			_lm_up_t[i] = -1.0
		if not art.is_empty():
			# Arte de PixelLab (10-oct): dibujado mirando a la derecha; el de
			# la otra banda se espeja para mirar hacia la cancha.
			var inward: Vector2 = _pw(wpos + Vector2(-0.1 if i == 0 else 0.1, 0.0)) - base
			var flip: bool = inward.x < 0.0
			var frames: Array = art["marca"] if up else art["espera"]
			var idx: int
			if up:
				# Levanta el banderín y lo sostiene (los últimos cuadros).
				idx = mini(int((_live_t - float(_lm_up_t[i])) * 12.0), frames.size() - 1)
				if idx == frames.size() - 1:
					idx = frames.size() - 2 + int(_live_t * 4.0) % 2
			else:
				idx = int(_live_t * 5.0 + i * 2) % frames.size()
			var tex: Texture2D = frames[idx]
			var sz: Vector2 = tex.get_size()
			draw_circle(base + Vector2(1, 1), 5.0, Color(0, 0, 0, 0.25))
			var rect := Rect2(base - Vector2(sz.x * 0.5, sz.y * 0.5 + 16.0), sz)
			if flip:
				rect = Rect2(rect.position, Vector2(-sz.x, sz.y))   # ancho negativo = espejado EN EL LUGAR (sumarle el ancho lo corría un cuerpo a la derecha)
			draw_texture_rect(tex, rect, false)
			if up:
				draw_arc(base + Vector2(0, -16), 20.0 + sin(_pulse * 2.0) * 2.0, 0, TAU, 20, Color(1.0, 0.85, 0.3, 0.8), 2.0)
			continue
		var step: float = roundf(sin(_live_t * 9.0 + i)) * 1.0
		# Sin arte: figura dibujada (sombra, piernas, camiseta flúor, cabeza).
		draw_circle(base + Vector2(1, 1), 4.0, Color(0, 0, 0, 0.25))
		draw_rect(Rect2(base + Vector2(-3, -6 + step * 0.5), Vector2(2, 6)), Color(0.08, 0.08, 0.1))
		draw_rect(Rect2(base + Vector2(1, -6 - step * 0.5), Vector2(2, 6)), Color(0.08, 0.08, 0.1))
		draw_rect(Rect2(base + Vector2(-4, -15), Vector2(8, 9)), Color(0.85, 0.95, 0.2))
		draw_rect(Rect2(base + Vector2(-2, -20), Vector2(5, 5)), Color(0.85, 0.7, 0.55))
		var hand: Vector2 = base + Vector2(4, -12)
		var tip: Vector2 = hand + (Vector2(2, -17) if up else Vector2(7, 6))
		draw_line(hand, tip, Color(0.95, 0.95, 0.95), 1.5)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(8, 2), tip + Vector2(8, 8), tip + Vector2(0, 6)]), Color(1.0, 0.25, 0.2))

var _lm_up_t: Array = [-1.0, -1.0]
static var _lm_art: Dictionary = {}
static var _lm_art_tried: bool = false
## Cuadros del juez de línea: {"espera": [...], "marca": [...]} o {} si falta.
static func _linesman_art() -> Dictionary:
	if _lm_art_tried:
		return _lm_art
	_lm_art_tried = true
	var out := {}
	for a in ["espera", "marca"]:
		var fr: Array = []
		var i: int = 0
		while ResourceLoader.exists("res://assets/referee/linesman/%s_%d.png" % [a, i]):
			fr.append(load("res://assets/referee/linesman/%s_%d.png" % [a, i]))
			i += 1
		if fr.is_empty():
			return _lm_art
		out[a] = fr
	_lm_art = out
	return _lm_art

## JUEGO AMBIENTAL (10-oct, Wilber: "los jugadores se deben mover solos si
## estoy en la banca"). Entre tus jugadas — y todo el tiempo si estás en el
## banco — la cancha muestra el partido andando: los 22 en formación, la
## pelota que circula de pie a pie, las líneas que suben y bajan con ella.
## Es DECORADO: quién tiene más la pelota sale de la posesión real
## (`ambient_possession`), pero los goles, tarjetas y tus jugadas llegan del
## motor como siempre y reemplazan esta escena cuando pasan.
var ambient: bool = false
var ambient_possession: float = 0.5     # 0..1: cuánto la tiene TU equipo
var _amb_us = null
var _amb_holder: String = ""
var _amb_t: float = 1.0
var _amb_pass: Dictionary = {}

## `user_actor` = {} si no estás en cancha; `role` = GK / DF / MF / ST.
func setup_ambient(us: Color, them: Color, user_actor: Dictionary, role: String) -> void:
	var actors: Array = []
	var upos := Vector2(0.5, {"GK": 1.97, "DF": 1.62, "MF": 1.22, "ST": 0.80}.get(role, 1.22))
	if not user_actor.is_empty():
		var ua: Dictionary = user_actor.duplicate()
		ua["pos"] = upos
		actors.append(ua)
	setup({"actors": actors, "ball": Vector2(0.5, 1.0), "us": us, "them": them})
	ambient = true
	if _actors.has("user"):
		_actors["user"]["spd"] = 0.10
		if role == "GK":
			_actors["user"]["goal_y"] = 1.97
		else:
			_actors["user"]["slot"] = upos
	_amb_holder = ""
	_amb_pass = {}
	_amb_t = 0.6
	_update_processing()

## Atributo 0..1 de un jugador de la cancha (0,5 si no se conoce).
func _attr01(id: String, attr: String) -> float:
	if not _actors.has(id):
		return 0.5
	var at: Dictionary = _actors[id].get("attrs", {})
	if not at.has(attr):
		return 0.5
	return clampf((float(at[attr]) - 40.0) / 55.0, 0.0, 1.0)

func _amb_is_ours(id: String) -> bool:
	return _amb_us != null and (_actors[id]["color"] as Color).is_equal_approx(_amb_us as Color)

## Elige a quién va la pelota: del equipo `ours`, de campo, ni muy cerca ni
## muy lejos, y mejor si está más adelante.
func _amb_pick(ours: bool, from_w: Vector2) -> String:
	var best: String = ""
	var best_s: float = -9.0
	for id in _actors:
		var a: Dictionary = _actors[id]
		if id == _amb_holder or not a.has("slot") or _amb_is_ours(id) != ours:
			continue
		var w: Vector2 = _w(a["pos"])
		var dist: float = w.distance_to(from_w)
		var fwd: float = (from_w.y - w.y) if ours else (w.y - from_w.y)
		# Buen pasador = se anima al pase largo.
		var reach: float = lerpf(0.24, 0.42, _attr01(_amb_holder, "passing")) if _amb_holder != "" and _actors.has(_amb_holder) else 0.30
		var score: float = randf() * 0.5 + fwd * 0.9 - absf(dist - reach) * 1.2
		# Línea de pase tapada por otro jugador: casi nunca se elige (la
		# pelota "atravesaba" a los que estaban en el medio).
		for oid in _actors:
			if oid == id or oid == _amb_holder:
				continue
			var ow: Vector2 = _w(_actors[oid]["pos"])
			var ab: Vector2 = w - from_w
			var kk: float = clampf((ow - from_w).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if kk > 0.08 and kk < 0.92 and ow.distance_to(from_w + ab * kk) < 0.045:
				score -= 3.0
				break
		if score > best_s:
			best_s = score
			best = id
	return best

func _ambient_tick(delta: float) -> void:
	if _tween != null and _tween.is_valid() and _tween.is_running():
		return
	if _amb_holder == "" or not _actors.has(_amb_holder):
		_amb_holder = _amb_pick(randf() < ambient_possession, Vector2(0.5, 1.0))
		if _amb_holder == "":
			return
	if not _amb_pass.is_empty():
		_amb_pass["t"] = float(_amb_pass["t"]) + delta
		var k: float = clampf(float(_amb_pass["t"]) / float(_amb_pass["dur"]), 0.0, 1.0)
		var to_id: String = _amb_pass["to"]
		if not _actors.has(to_id):
			_amb_pass = {}
			return
		_ball = (_amb_pass["from"] as Vector2).lerp((_actors[to_id]["pos"] as Vector2) + _carry_offset(to_id, false), 1.0 - pow(1.0 - k, 1.6))
		_ball_h = sin(k * PI) * float(_amb_pass["arc"])
		if k >= 1.0:
			_amb_holder = to_id
			_amb_pass = {}
			_ball_h = 0.0
			# IA POR ATRIBUTOS (11-oct): el que regatea bien la aguanta más.
			_amb_t = randf_range(0.8, 1.9) * lerpf(0.75, 1.5, _attr01(to_id, "dribbling"))
		return
	_ball = (_actors[_amb_holder]["pos"] as Vector2) + _carry_offset(_amb_holder, bool(_actors[_amb_holder].get("moving", false)))
	_amb_t -= delta
	if _amb_t > 0.0:
		return
	var mine: bool = _amb_is_ours(_amb_holder)
	var hw: Vector2 = _w(_actors[_amb_holder]["pos"])
	# Cerca de un área la jugada se diluye (los goles los trae el motor).
	var deep: bool = (mine and hw.y < 0.45) or (not mine and hw.y > 1.55)
	# ...y el que pasa bien la pierde menos; un rival fuerte cerca la roba más.
	var keep_p: float = 0.40 + 0.45 * (ambient_possession if mine else 1.0 - ambient_possession) + 0.16 * (_attr01(_amb_holder, "passing") - 0.5)
	var near_d: float = 9.0
	var near_id: String = ""
	for oid in _actors:
		if _actors[oid].has("slot") and _amb_is_ours(oid) != mine:
			var dn: float = (_actors[oid]["pos"] as Vector2).distance_to(_actors[_amb_holder]["pos"])
			if dn < near_d:
				near_d = dn
				near_id = oid
	if near_id != "" and near_d < 0.12:
		keep_p -= 0.18 * _attr01(near_id, "strength")
	var keep: bool = not deep and randf() < keep_p
	var to: String = _amb_pick(mine if keep else not mine, hw)
	if to == "":
		_amb_t = 1.0
		return
	var dist: float = _w(_actors[to]["pos"]).distance_to(hw)
	if _actors[_amb_holder].has("sprite"):
		# 11-oct: el pase se ve (también en carrera) y sale hacia el compañero;
		# el pelotazo largo usa el gesto de remate.
		_actors[_amb_holder]["act_dir"] = _act_dir(_p(_actors[to]["pos"]) - _p(_actors[_amb_holder]["pos"]))
		_set_anim(_amb_holder, "remate" if dist > 0.45 else "pase", false)
	_amb_pass = {"from": _ball, "to": to, "t": 0.0, "dur": clampf(dist * 1.9, 0.35, 0.95), "arc": 1.3 if dist > 0.45 else 0.0}

## FUERA DE JUEGO BIEN MEDIDO (11-oct, Wilber: "los fuera de juego se miden
## mal"). Causa: la línea se sacaba solo de los 3 defensores "de la jugada"
## y los otros defensores de la cancha podían estar parados MÁS ATRÁS — o
## sea, habilitando al que se marcaba adelantado. Dos arreglos:
##  1) la línea es la regla de verdad: el PENÚLTIMO rival (el último suele
##     ser el arquero), contando a TODOS los que están en la cancha;
##  2) los defensores de relleno "tiran la línea": nunca se quedan más
##     atrás que sus compañeros que están en la jugada.
## Coordenadas de la jugada (y = 0 el arco que se ataca). -1 si no se puede.
func offside_line_for(attacker_id: String) -> float:
	if not _actors.has(attacker_id):
		return -1.0
	var col: Color = _actors[attacker_id]["color"]
	var att_keeper: bool = bool(_actors[attacker_id].get("keeper", false))
	var ys: Array = []
	for id in _actors:
		var a: Dictionary = _actors[id]
		if bool(a.get("ref", false)):
			continue
		# Rival = otro color; los arqueros tienen color propio: es rival el
		# que cuida el arco que se ataca (el de y más chico).
		var is_keeper: bool = bool(a.get("keeper", false)) or a.has("goal_y") or id == "gk"
		if is_keeper:
			if (a["pos"] as Vector2).y < 0.5 and not att_keeper:
				ys.append((a["pos"] as Vector2).y)
			continue
		if not (a["color"] as Color).is_equal_approx(col):
			ys.append((a["pos"] as Vector2).y)
	if ys.size() < 2:
		return -1.0
	ys.sort()
	return float(ys[1])

## Hasta dónde puede retroceder un jugador de relleno (MUNDO): la línea de
## sus compañeros de campo que están en la jugada. NAN = sin límite.
func _line_hold(col: Color, own_goal_top: bool) -> float:
	var lim: float = NAN
	for id in _actors:
		var a: Dictionary = _actors[id]
		if bool(a.get("extra", false)) or bool(a.get("ref", false)) or bool(a.get("keeper", false)) or id == "gk":
			continue
		if not (a["color"] as Color).is_equal_approx(col):
			continue
		var wy: float = _w(a["pos"]).y
		if is_nan(lim):
			lim = wy
		else:
			lim = minf(lim, wy) if own_goal_top else maxf(lim, wy)
	return lim

## IA DE POSICIÓN (10-oct, Wilber: "que todos los jugadores tengan IA...
## moverse con sentido en el partido"). Los jugadores que NO participan de
## la jugada dejan de ser estatuas: cada línea acompaña a la pelota (sube,
## baja, bascula hacia el lado de la jugada) y el arquero del otro arco se
## acomoda según por dónde viene la pelota y achica cuando está lejos.
## Es solo VISUAL: los que deciden la jugada (los actores de la escena) los
## siguen moviendo PitchPlays / el minijuego, y el resultado sale del motor.
func _extras_ai(delta: float) -> void:
	if _slowmo:
		return
	var bw: Vector2 = _w(_ball)
	var shift: float = (clampf(bw.y, 0.1, 1.9) - 1.0) * 0.50
	# ¿Quién tiene la pelota? El que ataca se ABRE y adelanta sus líneas; el
	# que defiende se CIERRA hacia el lado de la pelota y retrocede.
	var our_ball: bool = not scene_flip
	if ambient and _amb_holder != "" and _actors.has(_amb_holder):
		our_ball = _amb_is_ours(_amb_holder)
	# UNO solo sale a presionar al que la lleva (el más cercano del equipo
	# que defiende); los demás guardan su lugar.
	var presser: String = ""
	var press_d: float = 0.42
	for pid in _actors:
		var pa: Dictionary = _actors[pid]
		if not pa.has("slot") or _amb_us == null or _amb_is_ours(pid) == our_ball:
			continue
		var pd2: float = _w(pa["pos"]).distance_to(bw)
		if pd2 < press_d:
			press_d = pd2
			presser = pid
	for id in _actors:
		var a: Dictionary = _actors[id]
		if not a.has("spd"):
			continue
		var tgt_w: Vector2
		if a.has("goal_y"):
			var gy: float = float(a["goal_y"])
			var out: float = clampf(absf(bw.y - gy) - 0.8, 0.0, 0.7) * 0.16
			tgt_w = Vector2(clampf(0.5 + (bw.x - 0.5) * 0.4, 0.5 - GOAL_W * 0.4, 0.5 + GOAL_W * 0.4), gy + (out if gy < 1.0 else -out))
		else:
			var sl: Vector2 = a["slot"]
			var mine_t: bool = _amb_us != null and _amb_is_ours(id)
			var has_ball: bool = mine_t == our_ball
			# Los tuyos atacan hacia arriba (y menor); los rivales hacia abajo.
			var fwd: float = -1.0 if mine_t else 1.0
			var push: float = fwd * (0.09 if has_ball else -0.05)
			var wide: float = 1.12 if has_ball else 0.84
			tgt_w = Vector2(clampf(0.5 + (sl.x - 0.5) * wide + (bw.x - 0.5) * (0.16 if has_ball else 0.30) + sin(_live_t * 0.5 + sl.x * 9.0) * 0.014, 0.05, 0.95),
				clampf(sl.y + shift + push + cos(_live_t * 0.4 + sl.y * 7.0) * 0.014, 0.12, 1.88))
			if id == presser:
				# Se para entre la pelota y su arco, encima del que la lleva.
				tgt_w = Vector2(bw.x, clampf(bw.y - fwd * 0.06, 0.12, 1.88))
			if not ambient:
				var hold: float = _line_hold(a["color"], not mine_t)
				if not is_nan(hold):
					tgt_w.y = minf(tgt_w.y, hold) if mine_t else maxf(tgt_w.y, hold)
			if ambient and id == _amb_holder and _amb_pass.is_empty():
				# El que la tiene encara hacia el arco rival.
				tgt_w.y = clampf(_w(a["pos"]).y + (-0.2 if _amb_is_ours(id) else 0.2), 0.12, 1.88)
		var tgt: Vector2 = _wi(tgt_w)
		# No se meten encima de los que están jugando la pelota.
		for oid in _actors:
			if oid == id or bool(_actors[oid].get("extra", false)):
				continue
			var op: Vector2 = _actors[oid]["pos"]
			if op.distance_to(tgt) < 0.10:
				tgt = op + (tgt - op + Vector2(0.01, 0.007)).normalized() * 0.11
		# ...ni unos encima de otros: cada uno guarda su metro.
		for oid2 in _actors:
			if oid2 == id or not bool(_actors[oid2].get("extra", false)) or (id == presser and oid2 == _amb_holder):
				continue
			var op2: Vector2 = _actors[oid2]["pos"]
			if op2.distance_to(tgt) < 0.075:
				tgt = op2 + (tgt - op2 + Vector2(0.008, 0.006) * (1.0 if id > oid2 else -1.0)).normalized() * 0.08
		# La linea defensiva manda sobre todo lo anterior (esquivar, bascular).
		if not ambient and a.has("slot") and _amb_us != null:
			var mine_h: bool = _amb_is_ours(id)
			var hold2: float = _line_hold(a["color"], not mine_h)
			if not is_nan(hold2):
				var tw2: Vector2 = _w(tgt)
				tw2.y = minf(tw2.y, hold2 - 0.02) if mine_h else maxf(tw2.y, hold2 + 0.02)
				tgt = _wi(tw2)
		# Última palabra: nadie termina parado encima de los que juegan la
		# pelota. Se corre DE COSTADO (así no rompe la línea defensiva).
		for oid3 in _actors:
			if oid3 == id or bool(_actors[oid3].get("extra", false)) or bool(_actors[oid3].get("ref", false)):
				continue
			var op3: Vector2 = _actors[oid3]["pos"]
			if op3.distance_to(tgt) < 0.09:
				var side: float = signf(tgt.x - op3.x)
				if side == 0.0:
					side = 1.0 if (hash(id) % 2) == 0 else -1.0
				tgt.x = clampf(op3.x + side * 0.10, 0.03, 0.97)
		var pos: Vector2 = a["pos"]
		var d: Vector2 = tgt - pos
		var dist: float = d.length()
		var moving: bool = bool(a.get("moving", false))
		if (moving and dist > 0.012) or dist > 0.035:
			a["pos"] = pos + d / dist * minf(dist, float(a["spd"]) * delta)
			var fd: Vector2 = d * Vector2(68.0, 52.5)
			var face: String = DIRS8[posmod(int(round(fd.angle() / (PI / 4.0))), 8)]
			if a.has("goal_y"):
				# El arquero se acomoda con pasos laterales (ver _keeper_steps),
				# sin darse vuelta para "correr".
				a["moving"] = true
			elif not moving or String(a["face"]) != face:
				a["face"] = face
				a["moving"] = true
				_set_anim(id, "run_" + _screen_face(face), true)
		elif moving:
			a["moving"] = false
			if a.has("goal_y"):
				continue
			# Quieto: mira hacia la pelota.
			var look: Vector2 = (_ball - pos) * Vector2(68.0, 52.5)
			a["face"] = DIRS8[posmod(int(round(look.angle() / (PI / 4.0))), 8)]
			_set_anim(id, "idle", true)

## IA DENTRO DE LA JUGADA (10-oct, Wilber: "que el arquero tenga IA para
## tapar o salir del arco, que los defensas se muevan por sí solos").
## Mientras decidís o jugás el minijuego, los que participan no son
## estatuas: el arquero se perfila hacia la pelota y achica cuando la
## tenés cerca, los defensas basculan para tapar el camino al arco, tus
## compañeros se muestran, y todos miran la pelota. Es un corrimiento
## CHICO sobre su lugar (se guarda y se descuenta en cada cuadro), así que
## no cambia la geometría que miden los minijuegos ni el resultado.
const SCENE_AI_MAX := 0.022
func _scene_ai() -> void:
	var playing: bool = _tween != null and _tween.is_valid() and _tween.is_running()
	var active: bool = (_interactive or _mg != null) and not _aim_mode and not playing and not _slowmo
	var driven: Array = []
	if _mg != null:
		driven = _mg.driven_ids()
	for id in _actors:
		var a: Dictionary = _actors[id]
		if bool(a.get("extra", false)) or bool(a["user"]) or bool(a.get("ref", false)):
			continue
		var last: Vector2 = a.get("ai_off", Vector2.ZERO)
		var off := Vector2.ZERO
		if active and not (id in driven):
			var home: Vector2 = (a["pos"] as Vector2) - last
			var k: float = float(hash(id) % 97) * 0.13
			if bool(a.get("keeper", false)):
				# Arquero: se corre hacia el lado de la pelota y da un paso
				# adelante cuando está cerca (achica el ángulo).
				off = Vector2(clampf((_ball.x - 0.5) * 0.30, -0.07, 0.07) - (home.x - 0.5) * 0.5,
					clampf(0.045 - _ball.y * 0.09, 0.0, 0.035))
				off.x += sin(_live_t * 5.0) * 0.004
				# ATRIBUTOS EN TU JUGADA (11-oct): un arquero rápido acompaña
				# mejor la pelota y achica más.
				off *= lerpf(0.75, 1.25, _attr01(id, "speed"))
			else:
				var mine: bool = String(id).begins_with("m")
				var defending: bool = mine == scene_flip or (not mine and not scene_flip)
				if defending:
					# Defensa: da un paso hacia la línea pelota-arco, perfilado.
					var goal := Vector2(0.5, 0.0)
					var ab: Vector2 = goal - _ball
					var t2: float = clampf((home - _ball).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
					var onto: Vector2 = (_ball + ab * t2) - home
					# El rápido cierra más y antes; el lento llega a medias.
					off = onto.limit_length(SCENE_AI_MAX) * (0.6 + 0.4 * sin(_live_t * 1.7 + k)) * lerpf(0.65, 1.35, _attr01(id, "speed"))
				else:
					# Compañero que ataca: se muestra, amaga el pique.
					# El compañero hábil se mueve más para ofrecerse; el
					# rápido pica más largo.
					off = Vector2(sin(_live_t * 1.3 + k) * 0.012 * lerpf(0.7, 1.4, _attr01(id, "dribbling")),
						-absf(sin(_live_t * 0.9 + k)) * 0.016 * lerpf(0.65, 1.4, _attr01(id, "speed")))
			# Mira la pelota.
			if a.has("sprite") and not String(a["anim"]).begins_with("run_") and String(a["anim"]) == "idle":
				var look: Vector2 = (_ball - home) * Vector2(68.0, 52.5)
				if look.length() > 0.5 and not bool(a.get("keeper", false)):
					a["face"] = DIRS8[posmod(int(round(look.angle() / (PI / 4.0))), 8)]
		# El corrimiento entra y SALE de a poco: al empezar la repeticion se
		# soltaba de golpe y el jugador (sobre todo el arquero) pegaba un salto.
		off = last.lerp(off, 0.14)
		if off.length() < 0.0006:
			off = Vector2.ZERO
		if off != last:
			a["pos"] = (a["pos"] as Vector2) - last + off
			a["ai_off"] = off

## RADAR (10-oct): con la cancha grande solo se ve una parte, así que en
## la esquina va la cancha entera en chiquito — los 22, la pelota, vos (en
## dorado) y el recuadro de lo que está mirando la cámara.
var minimap: bool = true
func _draw_minimap() -> void:
	if not minimap or _slowmo or size.x < 200.0:
		return
	var mw: float = 46.0
	var mh: float = 70.0
	var o := Vector2(8.0, size.y - mh - 8.0)
	draw_rect(Rect2(o - Vector2(3, 3), Vector2(mw + 6, mh + 6)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(o, Vector2(mw, mh)), Color(0.12, 0.36, 0.17, 0.92))
	var lc := Color(1, 1, 1, 0.45)
	draw_rect(Rect2(o, Vector2(mw, mh)), lc, false, 1.0)
	draw_line(o + Vector2(0, mh * 0.5), o + Vector2(mw, mh * 0.5), lc, 1.0)
	draw_arc(o + Vector2(mw, mh) * 0.5, 6.0, 0, TAU, 16, lc, 1.0)
	draw_rect(Rect2(o + Vector2(mw * 0.25, 0), Vector2(mw * 0.5, mh * 0.11)), lc, false, 1.0)
	draw_rect(Rect2(o + Vector2(mw * 0.25, mh * 0.89), Vector2(mw * 0.5, mh * 0.11)), lc, false, 1.0)
	# Lo que ve la cámara.
	var c0: Vector2 = _from_px_w(_unzoom(Vector2.ZERO))
	var c1: Vector2 = _from_px_w(_unzoom(size))
	var c2: Vector2 = _from_px_w(_unzoom(Vector2(size.x, 0)))
	var c3: Vector2 = _from_px_w(_unzoom(Vector2(0, size.y)))
	var vmn := Vector2(minf(minf(c0.x, c1.x), minf(c2.x, c3.x)), minf(minf(c0.y, c1.y), minf(c2.y, c3.y)))
	var vmx := Vector2(maxf(maxf(c0.x, c1.x), maxf(c2.x, c3.x)), maxf(maxf(c0.y, c1.y), maxf(c2.y, c3.y)))
	vmn = Vector2(clampf(vmn.x, 0.0, 1.0), clampf(vmn.y, 0.0, 2.0))
	vmx = Vector2(clampf(vmx.x, 0.0, 1.0), clampf(vmx.y, 0.0, 2.0))
	draw_rect(Rect2(o + Vector2(vmn.x * mw, vmn.y * 0.5 * mh), Vector2((vmx.x - vmn.x) * mw, (vmx.y - vmn.y) * 0.5 * mh)), Color(1, 1, 1, 0.16))
	draw_rect(Rect2(o + Vector2(vmn.x * mw, vmn.y * 0.5 * mh), Vector2((vmx.x - vmn.x) * mw, (vmx.y - vmn.y) * 0.5 * mh)), Color(1, 1, 1, 0.7), false, 1.0)
	var user_at = null
	for id in _actors:
		var a: Dictionary = _actors[id]
		if bool(a.get("ref", false)):
			continue
		var w: Vector2 = _w(a["pos"])
		var q: Vector2 = o + Vector2(clampf(w.x, 0.0, 1.0) * mw, clampf(w.y, 0.0, 2.0) * 0.5 * mh)
		if bool(a["user"]):
			user_at = q
		else:
			draw_rect(Rect2(q - Vector2(1.5, 1.5), Vector2(3, 3)), a["color"])
	if _ball_visible:
		var bw: Vector2 = _w(_ball)
		draw_circle(o + Vector2(clampf(bw.x, 0.0, 1.0) * mw, clampf(bw.y, 0.0, 2.0) * 0.5 * mh), 1.6, Color.WHITE)
	if user_at != null:
		draw_circle(user_at, 3.2, Color(0, 0, 0, 0.8))
		draw_circle(user_at, 2.4, Color(1.0, 0.86, 0.25))

## Papelitos cayendo mientras la tribuna festeja (en pantalla, sin cámara).
func _draw_confetti() -> void:
	if _crowd_hype <= 0.0:
		return
	var cols: Array = board_colors if not board_colors.is_empty() else [Color(1, 0.85, 0.3), Color.WHITE]
	var a: float = clampf(_crowd_hype / 1.2, 0.0, 1.0)
	for k in range(46):
		var sx: float = fmod(float(k) * 0.6180339, 1.0)
		var sp: float = 0.25 + fmod(float(k) * 0.37, 0.4)
		var y: float = fmod(_live_t * sp + float(k) * 0.113, 1.0)
		var x: float = sx + sin(_live_t * 2.0 + k) * 0.02
		var c: Color = cols[k % cols.size()]
		c.a = a * 0.9
		draw_rect(Rect2(Vector2(x * size.x, y * size.y), Vector2(3, 5) if k % 2 == 0 else Vector2(5, 3)), c)

func _draw_weather() -> void:
	match _weather:
		"cloud":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.12, 0.16))
		"rain":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.16, 0.22))
			for d in _wx_drops:
				var y: float = fmod(d.y + _wx_t * 1.6 * d.z, 1.0)
				var x: float = fmod(d.x + _wx_t * 0.12, 1.0)
				var p := Vector2(x * size.x, y * size.y)
				draw_line(p, p + Vector2(-2.5, 9.0) * d.z, Color(0.8, 0.88, 1.0, 0.45), 1.0)
		"snow":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.9, 1.0, 0.10))
			for d in _wx_drops:
				var y: float = fmod(d.y + _wx_t * 0.18 * d.z, 1.0)
				var x: float = fmod(d.x + sin(_wx_t * 1.3 + d.y * 9.0) * 0.015, 1.0)
				draw_circle(Vector2(x * size.x, y * size.y), 1.6 * d.z, Color(1, 1, 1, 0.8))
