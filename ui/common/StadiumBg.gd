extends RefCounted
class_name StadiumBg

## Fondo de estadio PROCEDURAL por capas para la pantalla de partido:
## cielo/gradiente, techo, gradas con multitud animada (ola de brillo,
## shader barato), focos, vallas publicitarias y césped. Todo generado —
## no usa la foto `stadium_night.jpg`. Determinista por semilla.
##
## Devuelve un Control full-rect listo para meter DETRÁS del HUD.

const _CROWD := "res://assets/stadium/crowd_tile.png"
const _GLOW := "res://assets/stadium/glow.png"
const _WAVE_SH := "res://ui/shaders/crowd_wave.gdshader"

## Fondos en pixel art (PixelLab, 9-oct): día / noche / lluvia, 224×400.
## Las vallas del arte original traían "marcas" con letras inventadas por la
## IA → se tapan con NUESTRAS vallas (BrandMark + colores de los equipos)
## exactamente en la fila de píxeles donde están. [y0, y1) en px de origen.
const PX_SIZE := Vector2(224, 400)
const PX_BOARDS := {"day": [295, 303], "night": [268, 276], "rain": [269, 277]}

## Qué fondo toca: lluvia/nieve → lluvia; si no, ~40% de los partidos de
## noche (determinista por partido, como el clima).
static func variant_for(weather: String, seed_int: int) -> String:
	if weather in ["rain", "snow"]:
		return "rain"
	return "night" if absi(seed_int) % 5 < 2 else "day"

static func build(home_color: Color, away_color: Color, seed_int: int, variant: String = "") -> Control:
	if variant != "" and ResourceLoader.exists("res://assets/stadium/px_%s.png" % variant):
		return _build_px(home_color, away_color, seed_int, variant)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.clip_contents = true

	# --- Cielo / gradiente vertical ---
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.07, 0.12))
	grad.set_color(1, Color(0.06, 0.12, 0.08))
	grad.add_point(0.55, Color(0.07, 0.10, 0.13))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.width = 8
	gtex.height = 64
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	var sky := TextureRect.new()
	sky.texture = gtex
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sky)

	# --- Gradas (dos bandas, teñidas con el color del local para dar
	# ambiente — pedido de Wilber "la gente con el color del equipo local") ---
	_band(root, 0.10, 0.30, Color(0.13, 0.14, 0.17).lerp(home_color, 0.16).darkened(0.15))
	_band(root, 0.30, 0.46, Color(0.16, 0.17, 0.21).lerp(home_color, 0.20).darkened(0.1))

	# --- Multitud con ola de brillo (teñida al color del local) ---
	var crowd := _crowd_layer(seed_int, home_color)
	crowd.anchor_left = 0.0
	crowd.anchor_right = 1.0
	crowd.anchor_top = 0.10
	crowd.anchor_bottom = 0.46
	crowd.offset_left = 0
	crowd.offset_right = 0
	crowd.offset_top = 0
	crowd.offset_bottom = 0
	root.add_child(crowd)

	# --- Focos (glow en las 4 esquinas de arriba) ---
	for fx in [0.06, 0.32, 0.68, 0.94]:
		_flood(root, fx)

	# --- Techo (banda oscura arriba con línea del color local) ---
	var roof := ColorRect.new()
	roof.color = Color(0.04, 0.05, 0.07)
	roof.anchor_right = 1.0
	roof.anchor_bottom = 0.10
	roof.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(roof)
	var roof_line := ColorRect.new()
	roof_line.color = Color(home_color, 0.85)
	roof_line.anchor_right = 1.0
	roof_line.anchor_top = 0.095
	roof_line.anchor_bottom = 0.11
	roof_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(roof_line)

	# --- Vallas publicitarias ---
	root.add_child(_boards(seed_int, home_color, away_color))

	# --- Banquillos (dos dugouts al borde del campo) ---
	_bench(root, 0.06, 0.24, home_color)
	_bench(root, 0.76, 0.94, away_color)

	# --- Césped ---
	var pitch := ColorRect.new()
	pitch.color = Color(0.09, 0.24, 0.12)
	pitch.anchor_right = 1.0
	pitch.anchor_top = 0.52
	pitch.anchor_bottom = 1.0
	pitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pitch)
	# franjas del césped
	for i in range(6):
		var stripe := ColorRect.new()
		stripe.color = Color(1, 1, 1, 0.03 if i % 2 == 0 else 0.0)
		stripe.anchor_left = i / 6.0
		stripe.anchor_right = (i + 1) / 6.0
		stripe.anchor_top = 0.52
		stripe.anchor_bottom = 1.0
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(stripe)
	# líneas de campo (medio campo + círculo central + áreas + arcos)
	_pitch_lines(root)

	# (Antes había figuritas de jugadores corriendo por el campo: se veían
	# feas a esa escala — pedido de Wilber de quitarlas. El fondo se queda
	# con gradas + público + focos + vallas + banquillos + césped.)

	# --- Velo para legibilidad del HUD (transparente arriba → oscuro abajo) ---
	var vgrad := Gradient.new()
	vgrad.set_color(0, Color(0, 0, 0, 0.15))
	vgrad.set_color(1, Color(0, 0, 0, 0.62))
	var vtex := GradientTexture2D.new()
	vtex.gradient = vgrad
	vtex.fill_from = Vector2(0, 0)
	vtex.fill_to = Vector2(0, 1)
	var veil := TextureRect.new()
	veil.texture = vtex
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)

	return root

static func _build_px(home_color: Color, away_color: Color, seed_int: int, variant: String) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.clip_contents = true
	var img := TextureRect.new()
	img.texture = load("res://assets/stadium/px_%s.png" % variant)
	img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(img)
	var boards := _boards(seed_int, home_color, away_color)
	boards.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.add_child(boards)
	var rows: Array = PX_BOARDS.get(variant, [0, 0])
	# Mismo cálculo que STRETCH_KEEP_ASPECT_COVERED: escala por el lado que
	# más pide, centrado → la fila de vallas cae donde está en el arte.
	var lay := func():
		var sz: Vector2 = root.size
		var s: float = maxf(sz.x / PX_SIZE.x, sz.y / PX_SIZE.y)
		var oy: float = (sz.y - PX_SIZE.y * s) * 0.5
		boards.position = Vector2(0, oy + float(rows[0]) * s)
		boards.size = Vector2(sz.x, float(rows[1] - rows[0]) * s)
	root.resized.connect(lay)
	lay.call_deferred()
	root.add_child(_veil())
	return root

static func _veil() -> TextureRect:
	var vgrad := Gradient.new()
	vgrad.set_color(0, Color(0, 0, 0, 0.15))
	vgrad.set_color(1, Color(0, 0, 0, 0.62))
	var vtex := GradientTexture2D.new()
	vtex.gradient = vgrad
	vtex.fill_from = Vector2(0, 0)
	vtex.fill_to = Vector2(0, 1)
	var veil := TextureRect.new()
	veil.texture = vtex
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return veil

static func _pitch_lines(root: Control) -> void:
	var LINE := Color(1, 1, 1, 0.11)
	# medio campo
	var midline := ColorRect.new()
	midline.color = LINE
	midline.anchor_left = 0.497
	midline.anchor_right = 0.503
	midline.anchor_top = 0.52
	midline.anchor_bottom = 1.0
	midline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(midline)
	# círculo central
	var circ := Panel.new()
	circ.anchor_left = 0.5
	circ.anchor_right = 0.5
	circ.anchor_top = 0.76
	circ.anchor_bottom = 0.76
	circ.offset_left = -34
	circ.offset_right = 34
	circ.offset_top = -22
	circ.offset_bottom = 22
	circ.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0, 0, 0, 0)
	csb.set_corner_radius_all(40)
	csb.set_border_width_all(2)
	csb.border_color = LINE
	circ.add_theme_stylebox_override("panel", csb)
	root.add_child(circ)
	# áreas (izquierda y derecha)
	for lr in [true, false]:
		var box := Panel.new()
		box.anchor_left = 0.0 if lr else 0.86
		box.anchor_right = 0.14 if lr else 1.0
		box.anchor_top = 0.66
		box.anchor_bottom = 0.9
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(0, 0, 0, 0)
		bsb.set_border_width_all(2)
		bsb.border_color = LINE
		box.add_theme_stylebox_override("panel", bsb)
		root.add_child(box)

static func _bench(root: Control, x0: float, x1: float, team_color: Color) -> void:
	var dug := Panel.new()
	dug.anchor_left = x0
	dug.anchor_right = x1
	dug.anchor_top = 0.525
	dug.anchor_bottom = 0.565
	dug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.92)
	sb.set_corner_radius_all(3)
	sb.border_width_top = 2
	sb.border_color = Color(team_color, 0.7)
	dug.add_theme_stylebox_override("panel", sb)
	root.add_child(dug)
	var seats := HBoxContainer.new()
	seats.anchor_left = x0
	seats.anchor_right = x1
	seats.anchor_top = 0.532
	seats.anchor_bottom = 0.56
	seats.add_theme_constant_override("separation", 3)
	seats.alignment = BoxContainer.ALIGNMENT_CENTER
	seats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(5):
		var s := ColorRect.new()
		s.color = Color(0.75, 0.75, 0.8, 0.55)
		s.custom_minimum_size = Vector2(4, 4)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seats.add_child(s)
	root.add_child(seats)

static func _band(root: Control, top: float, bottom: float, col: Color) -> void:
	var r := ColorRect.new()
	r.color = col
	r.anchor_right = 1.0
	r.anchor_top = top
	r.anchor_bottom = bottom
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)

static func _crowd_layer(seed_int: int, home_color: Color = Color.WHITE) -> Control:
	var tr := TextureRect.new()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(_CROWD):
		tr.texture = load(_CROWD)
		tr.stretch_mode = TextureRect.STRETCH_TILE
		tr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(_WAVE_SH) and not Preferences.reduce_motion:
		var mat := ShaderMaterial.new()
		mat.shader = load(_WAVE_SH)
		mat.set_shader_parameter("speed", 0.5 + float(absi(seed_int) % 5) * 0.08)
		tr.material = mat
	# Tinte hacia el color del local (sin pasarse: la textura ya trae sus
	# propios colores de gente, esto le da "el clima" del equipo de casa).
	var tint: Color = Color(1, 1, 1).lerp(home_color, 0.34)
	tr.modulate = Color(tint.r, tint.g, tint.b, 0.9)
	return tr

static func _flood(root: Control, x_anchor: float) -> void:
	if not ResourceLoader.exists(_GLOW):
		return
	var g := TextureRect.new()
	g.texture = load(_GLOW)
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	g.custom_minimum_size = Vector2(120, 120)
	g.anchor_left = x_anchor
	g.anchor_right = x_anchor
	g.anchor_top = 0.0
	g.anchor_bottom = 0.0
	g.offset_left = -60
	g.offset_right = 60
	g.offset_top = -30
	g.offset_bottom = 90
	g.modulate = Color(1, 1, 1, 0.28)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(g)

static func _boards(seed_int: int, home_color: Color, away_color: Color) -> Control:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 0)
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.anchor_top = 0.46
	strip.anchor_bottom = 0.52
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_int) ^ 0x9E3779B9
	var pal: Array = BrandMark.PALETTES
	for i in range(8):
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col: Color
		if i % 4 == 0:
			col = home_color
		elif i % 4 == 2:
			col = away_color
		else:
			col = Color(pal[rng.randi() % pal.size()][0])
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.darkened(0.1)
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(1, 1, 1, 0.18)
		cell.add_theme_stylebox_override("panel", sb)
		var glyph := TextureRect.new()
		glyph.texture = _brand_glyph()
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.modulate = Color(1, 1, 1, 0.75)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_top", 3)
		m.add_theme_constant_override("margin_bottom", 3)
		m.add_child(glyph)
		cell.add_child(m)
		strip.add_child(cell)
	return strip

static var _glyph_cache: Texture2D = null
static func _brand_glyph() -> Texture2D:
	if _glyph_cache == null:
		var p := "res://assets/brands/gl_wave.png"
		_glyph_cache = load(p) if ResourceLoader.exists(p) else null
	return _glyph_cache
