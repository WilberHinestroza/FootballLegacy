extends Control
class_name UltimateCard
const _M3D = preload("res://engine/match/m3d/Match3DBridge.gd")  # retrato 3D

## CARTA DE JUGADOR estilo "Ultimate" (10-oct, Wilber: "mejora la carta de
## jugador tanto la del hub principal y la de mi perfil"). Un solo
## componente para las dos pantallas: silueta de carta con hombros y punta,
## degradé del NIVEL (bronce/plata/oro/especial — corte de
## PlayerCard.tier_color, no se duplica), franja diagonal del color del
## club, columna izquierda con MEDIA + puesto + bandera + escudo, cuerpo
## entero del avatar, nombre en banda y las 6 stats de la carta
## (PlayerDevelopment.card_stat — la misma fuente que la media).
## Todo se posiciona en proporción al ancho: sirve chica (Hub) y grande
## (Perfil). Alto = ancho × RATIO.

const RATIO := 1.42

var _player: PlayerData
var _club: ClubData
var _w: float = 200.0
var _tier_top: Color
var _tier_bot: Color
var _ink: Color
var _club_col: Color
var _compact: bool = false   # < 150 px (Hub): sin stats, avatar más grande
var _shine_t: float = -1.0
## Carta ESPECIAL (10-oct, ImmersionEngine.special_card): premio
## individual, racha o leyenda. {} = la normal por media.
var _special: Dictionary = {}

static func build(player: PlayerData, club: ClubData, width: int) -> UltimateCard:
	var c := UltimateCard.new()
	c._player = player
	c._club = club
	c._w = float(width)
	c.custom_minimum_size = Vector2(width, round(width * RATIO))
	c.size = c.custom_minimum_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Degradé por nivel (mismos cortes que PlayerCard.tier_color).
static func tier_colors(overall: int) -> Array:
	if overall > 85:
		return [Color("#9b5de5"), Color("#2a1150"), Color("#f5ecff")]
	if overall >= 80:
		return [Color("#f7dc6f"), Color("#9a6f12"), Color("#2b1d02")]
	if overall >= 61:
		return [Color("#eef2f6"), Color("#7c8896"), Color("#1d232b")]
	return [Color("#e3a76b"), Color("#7a4520"), Color("#2a1608")]

func _ready() -> void:
	var tc: Array = tier_colors(_player.overall)
	_tier_top = tc[0]
	_tier_bot = tc[1]
	_ink = tc[2]
	_special = ImmersionEngine.special_card(_player, WorldTickEngine.get_season_start_year())
	if not _special.is_empty():
		_tier_top = _special["top"]
		_tier_bot = _special["bot"]
		_ink = _special["ink"]
	_club_col = Color(_club.primary_color_hex) if _club != null and _club.primary_color_hex != "" else Styles.BLUE
	var h: float = _w * RATIO
	var seed_i: int = SaveManager.load_world_seed()
	_compact = _w < 150.0

	# Cuerpo entero (atrás de los textos, a la derecha).
	# Cuerpo entero con el modelo 3D del partido (pixel art si el 3D está apagado)
	var bh: int = int(h * (0.62 if _compact else 0.50))
	var body: Control = _M3D.portrait(_player, _club, bh, true)
	body.position = Vector2(_w * (0.26 if _compact else 0.30) - bh * 0.18, h * (0.10 if _compact else 0.065))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)

	# Columna izquierda: media, puesto, bandera, escudo.
	var ov := _lbl(str(_player.overall), _w * 0.19, _ink, true)
	ov.position = Vector2(_w * 0.075, h * 0.07)
	ov.size = Vector2(_w * 0.26, _w * 0.22)
	ov.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(ov)
	var pos := _lbl(_player.detailed_position if _player.detailed_position != "" else Positions.broad_label(_player.position), _w * 0.075, _ink, true)
	pos.position = Vector2(_w * 0.075, h * 0.07 + _w * 0.21)
	pos.size = Vector2(_w * 0.26, _w * 0.09)
	pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(pos)
	var yy: float = h * 0.07 + _w * (0.36 if _compact else 0.32)
	var flag_tex: Texture2D = CountryFlags.flag_or_proc(_player.country) if _player.country != "" else null
	if flag_tex != null:
		var fl := TextureRect.new()
		fl.texture = flag_tex
		fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fl.position = Vector2(_w * 0.105, yy)
		fl.size = Vector2(_w * 0.20, _w * 0.13)
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fl)
		yy += _w * 0.16
	if _club != null:
		var cr := Styles.club_crest(_club.club_id, int(_w * 0.17))
		cr.position = Vector2(_w * 0.12, yy)
		add_child(cr)

	# Nombre en la banda.
	var nm := _lbl(_short_name(_player.player_name).to_upper(), _w * 0.085, _ink, true)
	nm.position = Vector2(0, h * (0.735 if _compact else 0.585))
	nm.size = Vector2(_w, _w * 0.11)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.clip_text = true
	add_child(nm)
	# Cinta de la versión especial arriba, entre los hombros.
	if not _special.is_empty():
		var rib := _lbl(String(_special["label"]), _w * (0.06 if _compact else 0.05), _special["edge"], true)
		rib.position = Vector2(_w * 0.30, h * 0.035)
		rib.size = Vector2(_w * 0.66, _w * 0.08)
		rib.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rib.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		rib.add_theme_constant_override("outline_size", maxi(2, int(_w * 0.015)))
		add_child(rib)

	if _compact:
		set_process(true)
		return
	# 6 stats en 2 columnas: "62 RIT".
	var keys: Array = PlayerDevelopment.CARD_STAT_KEYS
	for i in range(keys.size()):
		var col: int = i / 3
		var row: int = i % 3
		var v: int = PlayerDevelopment.card_stat(_player, String(keys[i]))
		var x0: float = _w * (0.17 if col == 0 else 0.56)
		var y0: float = h * 0.690 + row * _w * 0.092
		var num := _lbl(str(v), _w * 0.078, _ink, true)
		num.position = Vector2(x0, y0)
		num.size = Vector2(_w * 0.13, _w * 0.1)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(num)
		var k := _lbl(String(keys[i]), _w * 0.07, Color(_ink, 0.78), false)
		k.position = Vector2(x0 + _w * 0.15, y0 + _w * 0.006)
		k.size = Vector2(_w * 0.16, _w * 0.1)
		add_child(k)

	# Nivel RPG abajo, en la punta (+ escalón de la carta).
	var tier_txt: String = String(_special.get("label", ImmersionEngine.card_tier_name(_player.overall)))
	var lv := _lbl("NV %d · %s" % [_player.level, tier_txt], _w * 0.045, Color(_ink, 0.85), true)
	lv.position = Vector2(0, h * 0.912)
	lv.size = Vector2(_w, _w * 0.08)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lv)
	set_process(true)

## Brillo que cruza la carta cada ~4 s, recortado a la silueta (el
## Juice.shine genérico se salía por las esquinas biseladas).
func _process(delta: float) -> void:
	_shine_t += delta
	if _shine_t > (2.0 if not _special.is_empty() else 4.0):
		_shine_t = -1.0
	if _shine_t >= 0.0 and _shine_t <= 1.0 + delta:
		queue_redraw()

## "Tomás Herrera" -> "T. Herrera" si no entra.
static func _short_name(full: String) -> String:
	var parts: PackedStringArray = full.strip_edges().split(" ", false)
	if full.length() <= 14 or parts.size() < 2:
		return full
	return "%s. %s" % [parts[0].substr(0, 1), parts[parts.size() - 1]]

func _lbl(text: String, size_px: float, col: Color, heavy: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if heavy:
		l.add_theme_font_override("font", Styles.font_black())
	l.add_theme_font_size_override("font_size", maxi(8, int(size_px)))
	l.add_theme_color_override("font_color", col)
	return l

## Silueta de la carta (hombros biselados arriba, punta suave abajo).
func _outline_pts() -> PackedVector2Array:
	var w: float = _w
	var h: float = _w * RATIO
	var s: float = w * 0.10   # bisel de hombros
	return PackedVector2Array([
		Vector2(s, 0), Vector2(w * 0.36, 0), Vector2(w * 0.5, h * 0.03), Vector2(w * 0.64, 0), Vector2(w - s, 0),
		Vector2(w, s), Vector2(w, h * 0.84), Vector2(w * 0.5, h), Vector2(0, h * 0.84), Vector2(0, s),
	])

func _draw() -> void:
	var w: float = _w
	var h: float = _w * RATIO
	var pts := _outline_pts()
	# Degradé vertical: color por vértice según su altura.
	var cols := PackedColorArray()
	for p in pts:
		cols.append(_tier_top.lerp(_tier_bot, clampf(p.y / h, 0.0, 1.0)))
	draw_polygon(pts, cols)
	# Franja diagonal del club (detrás del avatar).
	var band := PackedVector2Array([Vector2(w * 0.55, 0), Vector2(w * 0.80, 0), Vector2(w * 0.30, h * 0.58), Vector2(w * 0.05, h * 0.58)])
	draw_colored_polygon(_clip_to_card(band), Color(_club_col, 0.30))
	# Brillo superior.
	var gloss := PackedVector2Array([Vector2(w * 0.1, 0), Vector2(w * 0.9, 0), Vector2(w, w * 0.1), Vector2(w, h * 0.22), Vector2(0, h * 0.30), Vector2(0, w * 0.1)])
	draw_colored_polygon(gloss, Color(1, 1, 1, 0.10))
	# Banda del nombre + separadores.
	if _compact:
		draw_line(Vector2(w * 0.12, h * 0.735), Vector2(w * 0.88, h * 0.735), Color(_ink, 0.35), maxf(1.0, w * 0.006))
	else:
		draw_line(Vector2(w * 0.12, h * 0.585), Vector2(w * 0.88, h * 0.585), Color(_ink, 0.35), maxf(1.0, w * 0.006))
		draw_line(Vector2(w * 0.12, h * 0.685), Vector2(w * 0.88, h * 0.685), Color(_ink, 0.35), maxf(1.0, w * 0.006))
		draw_line(Vector2(w * 0.5, h * 0.70), Vector2(w * 0.5, h * 0.875), Color(_ink, 0.25), maxf(1.0, w * 0.006))
	# Brillo que cruza (recortado a la silueta).
	if _shine_t >= 0.0 and _shine_t <= 1.0:
		var x: float = lerpf(-w * 0.5, w * 1.3, _shine_t)
		var sb := PackedVector2Array([Vector2(x, 0), Vector2(x + w * 0.12, 0), Vector2(x - w * 0.38, h), Vector2(x - w * 0.50, h)])
		for part in Geometry2D.intersect_polygons(sb, pts):
			draw_colored_polygon(part, Color(1, 1, 1, 0.22))
	# Destellos de la versión especial.
	if not _special.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(_special["id"]))
		var ec: Color = _special["edge"]
		for i in range(9):
			var pnt := Vector2(rng.randf_range(w * 0.08, w * 0.92), rng.randf_range(h * 0.06, h * 0.55))
			var r: float = rng.randf_range(w * 0.008, w * 0.02)
			draw_line(pnt - Vector2(r * 2.2, 0), pnt + Vector2(r * 2.2, 0), Color(ec, 0.55), maxf(1.0, w * 0.005))
			draw_line(pnt - Vector2(0, r * 2.2), pnt + Vector2(0, r * 2.2), Color(ec, 0.55), maxf(1.0, w * 0.005))
	# Marco doble.
	var closed := pts.duplicate()
	closed.append(pts[0])
	var edge: Color = _special["edge"] if not _special.is_empty() else _tier_top.lightened(0.35)
	draw_polyline(closed, edge, maxf(2.0, w * (0.024 if not _special.is_empty() else 0.018)), true)
	var inner := PackedVector2Array()
	var c := Vector2(w * 0.5, h * 0.5)
	for p in closed:
		inner.append(c + (p - c) * 0.94)
	draw_polyline(inner, Color(_ink, 0.30), maxf(1.0, w * 0.006), true)

## Recorte simple de la franja al rectángulo de la carta (la silueta casi
## lo llena; los bordes biselados quedan tapados por el marco).
func _clip_to_card(poly: PackedVector2Array) -> PackedVector2Array:
	var res: Array = Geometry2D.intersect_polygons(poly, _outline_pts())
	return res[0] if not res.is_empty() else PackedVector2Array()
