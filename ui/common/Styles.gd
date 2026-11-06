extends RefCounted
class_name Styles

## Fábrica de StyleBoxFlat para toda la interfaz — un solo lugar con la
## paleta y las formas (píldoras, tarjetas) para no repetir "corner_radius
## = 999" a mano en cada pantalla. Paleta calibrada contra el prototipo de
## Football Legacy (capturas de Android Studio que compartió Wilber):
## fondo casi negro, tarjetas gris oscuro, verde para la acción principal
## del día, ámbar para la secundaria, dorado para resaltar "esto es tuyo".

const BG_DARK := Color(0.043, 0.043, 0.043)
const CARD_DARK := Color(0.11, 0.11, 0.11)
const CARD_DARK_2 := Color(0.145, 0.145, 0.145)
const GREEN := Color(0.243, 0.663, 0.325)      # acción principal ("Pasar el día")
const AMBER := Color(0.831, 0.616, 0.235)      # acción secundaria ("Semana")
const GOLD := Color(1.0, 0.85, 0.3)            # resaltado "esto es tuyo"
const BLUE := Color(0.204, 0.451, 0.749)       # tarjetas "mundo del juego" (Carrera)
const RED := Color(0.82, 0.26, 0.26)           # resultado/efecto negativo (derrota, evento malo)
const BRONZE := Color(0.72, 0.45, 0.20)        # nivel de jugador <=60 (PlayerCard.tier_color)
const SILVER := Color(0.75, 0.75, 0.78)        # nivel de jugador 61-79
const PURPLE := Color(0.58, 0.35, 0.85)        # nivel de jugador >85 ("celestial")
const GRAY_TEXT := Color(0.65, 0.65, 0.65)

## Escala tipográfica — pedido explícito ("que se vea como EA FC / Soccer
## Champs"): antes cada pantalla inventaba su propio tamaño de letra suelto
## (11 a 22, sin criterio), lo que hacía que ninguna jerarquía se sintiera
## igual de una pantalla a otra. Un solo lugar con 5 escalones, de mayor a
## menor peso visual — cualquier Label nuevo elige uno de estos, nunca un
## número a mano.
const SIZE_DISPLAY := 32   # números grandes: overall, marcador de partido
const SIZE_TITLE := 22     # título de pantalla, nombre del jugador
const SIZE_HEADING := 16   # subtítulos, nombre de club en una fila
const SIZE_BODY := 14      # texto de cuerpo estándar
const SIZE_CAPTION := 12   # texto secundario en gris
const SIZE_LABEL := 11     # encabezado de sección en mayúsculas ("PRENSA")

## Tipografía — Poppins (SIL OFL, embebida en ui/fonts/), pedido explícito
## ("que se vea como EA FC 26 / Soccer Champs"): el peso Regular ya es el
## default de TODO el proyecto (ver project.godot: gui/theme/custom_font),
## así que cualquier Label/Button que no pida nada distinto YA usa Poppins
## sin tocar una sola pantalla. Estos dos pesos más pesados son para lo
## poco que de verdad necesita más peso visual — números grandes (overall,
## marcador) y botones/acciones — nunca para texto de cuerpo corrido.
static var _font_cache: Dictionary = {}

static func _load_font(path: String) -> Font:
	if not _font_cache.has(path):
		_font_cache[path] = load(path)
	return _font_cache[path]

static func font_semibold() -> Font:
	return _load_font("res://ui/fonts/Poppins-SemiBold.ttf")

static func font_black() -> Font:
	return _load_font("res://ui/fonts/Poppins-Black.ttf")

## Número protagonista (overall, marcador de partido) — SIEMPRE peso Black,
## nunca el Regular por defecto: es el elemento que más se parece a la
## "carta" de EA FC/Soccer Champs, tiene que pesar más que cualquier texto
## alrededor.
static func apply_display_font(label: Label) -> void:
	label.add_theme_font_override("font", font_black())

## Escudo de club — pedido explícito ("busca e instala assets gratis de
## Godot si los necesitas"): en vez de bajar un asset nuevo, Icons.CLUB
## (shield.svg) YA estaba instalado en el proyecto (addons/at-icons) pero
## solo se usaba como ícono de UI genérico — nunca como el escudo real de
## un club en Hub/Club/Plantilla, que hasta ahora era un círculo liso con
## texto (el placeholder consciente del README, "sin arte todavía"). Un
## escudo con FORMA de escudo, teñido con el color real de CADA club
## (primary_color_hex), no tiene costo de asset ni de licencia nueva y se
## ve mucho más cerca de EA FC/Soccer Champs que un círculo — sirve para
## cualquiera de los ~800 clubes del mundo sin necesitar un asset por club.
## Escudo de club — MODULAR por capas (ver Crest.gd), dividido en color
## principal (relleno) y secundario (patrón + emblema). `secondary`
## opcional: si no viene, se deriva del principal. `seed_key` opcional
## (club_id) para la forma/patrón; si no, el short_name.
## NOTA: ya NO se superpone la sigla del club — el escudo se reconoce por
## color + forma + patrón + emblema, como un escudo de verdad (pedido de
## Wilber: "no necesitan las iniciales encima"). `short_name` solo se usa
## como semilla de respaldo.
static func build_club_badge(primary_color: Color, short_name: String, size: int, secondary_color: Color = Color.TRANSPARENT, seed_key: String = "") -> Control:
	var secondary: Color = secondary_color
	if secondary.a < 0.05 or absf(secondary.get_luminance() - primary_color.get_luminance()) < 0.22:
		var lum: float = primary_color.get_luminance()
		secondary = primary_color.darkened(0.35) if lum > 0.5 else primary_color.lightened(0.45)

	var key: String = seed_key if seed_key != "" else short_name
	var root := Crest.build(primary_color, secondary, Crest.config_for(key), size, true)
	root.custom_minimum_size = Vector2(size, size)
	return root

## Escudito de un club por su id (busca colores en el mundo cargado).
## Para tablas/listas — sin etiqueta. Devuelve un Control de px×px.
static func club_crest(club_id: String, px: int) -> Control:
	var world: Dictionary = WorldTickEngine.world
	if world.is_empty():
		world = WorldFactory.build(SaveManager.load_world_seed())
	var club: ClubData = WorldFactory.find_club(world, club_id)
	var prim: Color = BLUE
	var sec: Color = Color.TRANSPARENT
	if club != null:
		if not club.primary_color_hex.is_empty():
			prim = Color(club.primary_color_hex)
		if not club.secondary_color_hex.is_empty():
			sec = Color(club.secondary_color_hex)
	if sec.a < 0.05 or absf(sec.get_luminance() - prim.get_luminance()) < 0.22:
		sec = prim.darkened(0.35) if prim.get_luminance() > 0.5 else prim.lightened(0.45)
	var c := Crest.build(prim, sec, Crest.config_for(club_id), px, true)
	c.custom_minimum_size = Vector2(px, px)
	return c

## Retrato enmarcado para una cara (avatar de jugador o NPC). `face` es el
## Control de Avatar.build/for_player/for_npc. Marco redondeado + borde.
static func portrait_frame(face: Control, px: int, ring: Color = Color(1, 1, 1, 0.16)) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(px + 10, px + 10)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var st := card_flat(Color(1, 1, 1, 0.06), maxi(6, int(px * 0.28)))
	st.set_border_width_all(2)
	st.border_color = ring
	frame.add_theme_stylebox_override("panel", st)
	var cc := CenterContainer.new()
	face.custom_minimum_size = Vector2(px, px)
	cc.add_child(face)
	frame.add_child(cc)
	return frame

## Color de un titular de prensa según su sentimiento (PressGenerator.gd)
## — un solo lugar, usado tanto en el Hub (últimos 3) como en Noticias
## (feed completo), nunca dos criterios de color distintos para el mismo dato.
static func sentiment_color(sentiment: String) -> Color:
	if sentiment == "CRITICAL":
		return RED
	if sentiment == "NEUTRAL":
		return GRAY_TEXT
	return GREEN

## Encabezado de sección en mayúsculas ("PLANTEL", "RIVALIDADES"...) — antes
## CADA pantalla definía su propia copia idéntica de este helper (Hub,
## ClubInfo, CareerMenu, PlayerProfile, WorldExplorer...); un solo lugar
## para no repetir el mismo Label seis veces por el proyecto.
## Encabezado de sección (9-oct, Wilber: "mejorá la GUI"): antes un gris
## chiquito de 11 px que se perdía; ahora barrita dorada a la izquierda,
## letra semibold más clara y aire arriba — se ve dónde empieza cada bloque.
static func section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.set_meta("section", true)   # land_columns() corta las columnas acá
	lbl.text = text.to_upper()
	lbl.add_theme_color_override("font_color", Color(0.86, 0.88, 0.93))
	lbl.add_theme_font_override("font", font_semibold())
	lbl.add_theme_font_size_override("font_size", 13)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_left = 3
	sb.border_color = GOLD
	sb.content_margin_left = 9
	sb.content_margin_top = 6
	sb.content_margin_bottom = 2
	lbl.add_theme_stylebox_override("normal", sb)
	return lbl

static func pill_filled(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(999)
	# Un toque de profundidad tipo EA FC: borde superior más claro, sombra
	# suave (sin necesitar textura de degradado).
	s.border_width_top = 2
	s.border_color = color.lightened(0.28)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0, 2)
	return s

static func pill_outlined(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = color
	s.set_border_width_all(2)
	s.set_corner_radius_all(999)
	return s

## Tarjeta/panel. Con `USE_PIX_PANELS` devuelve la textura 9-slice de
## Kenney (pixel-ui) teñida a `bg`. Si no, el StyleBoxFlat plano de antes.
## OJO: los call sites que MUTAN el resultado (bordes/shadow) usan
## `card_flat()`, no este.
const USE_PIX_PANELS := true

static func card(bg: Color = CARD_DARK, radius: int = 14) -> StyleBox:
	if USE_PIX_PANELS:
		return _pix_box("grey.png", bg, 16, clampi(radius, 4, 12))
	return card_flat(bg, radius)

## Igual que card() pero SIEMPRE plano y mutable (para los pocos lugares
## que le tocan bordes / shadow / bg_color después).
static func card_flat(bg: Color = CARD_DARK, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	return s

## Tarjeta "glass" — fondo casi transparente con borde tenue, para el look
## del mockup de referencia (EA FC 26). Va bien sobre el degradado de fondo.
static func glass(radius: int = 14, tint: float = 0.05) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, tint)
	s.set_corner_radius_all(radius)
	s.set_border_width_all(1)
	s.border_color = Color(1, 1, 1, 0.09)
	return s

## Degradado vertical cacheado (top -> bottom).
static var _grad_cache: Dictionary = {}
static func gradient_texture(top: Color, bottom: Color) -> GradientTexture2D:
	var key := "%s|%s" % [top.to_html(), bottom.to_html()]
	if _grad_cache.has(key):
		return _grad_cache[key]
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 8
	t.height = 256
	_grad_cache[key] = t
	return t

## Botón "pill" con degradado real (StyleBoxTexture) — profundidad tipo EA
## FC sin depender de assets.
static func pill_gradient(color: Color) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = gradient_texture(color.lightened(0.18), color.darkened(0.16))
	s.set_expand_margin_all(0)
	return s

## Fondo de pantalla: foto de cancha oscura (ui/bg/pitch_dark.jpg) muy
## atenuada + un velo en degradado encima para que el texto siempre
## contraste — look del mockup de referencia (EA FC 26 / Soccer Champs).
## Devuelve un Control a pantalla completa; lo usa TopBar para que TODA
## pantalla de navegación lo herede en un solo lugar. Si la imagen aún no
## está importada, cae de vuelta al degradado plano.
const PITCH_BG_PATH := "res://ui/bg/pitch_dark.jpg"

static func screen_bg() -> Control:
	var pitch_tex: Texture2D = load(PITCH_BG_PATH) if ResourceLoader.exists(PITCH_BG_PATH) else null
	return _layered_bg(
		pitch_tex,
		# Más tapado (9-oct): las líneas de la cancha del fondo caían justo
		# detrás de títulos y tarjetas ("cajita" alrededor de "Entrenamiento",
		# el círculo central cruzando listas) — se veía todo desordenado.
		Color(0.55, 0.58, 0.63, 1.0),
		Color(0.04, 0.06, 0.09, 0.72), Color(0.015, 0.02, 0.03, 0.86),
		Color(0.07, 0.09, 0.13), Color(0.03, 0.035, 0.05),
	)

## Arma el fondo por capas. TODO se estira con STRETCH_SCALE y anclas+
## offsets a rect completo — es EXACTAMENTE el mismo camino que el
## degradado plano que ya funcionaba; solo cambia la textura de la capa
## base. (KEEP_ASPECT_COVERED daba una imagen gigante/mal encuadrada en
## 4.7 con estos contenedores.) La leve deformación de aspecto no se nota
## en fotos borrosas.
static func _layered_bg(tex: Texture2D, tex_dim: Color, veil_top: Color, veil_bottom: Color, fallback_top: Color, fallback_bottom: Color) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var base := TextureRect.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_SCALE
	if tex != null:
		base.texture = tex
		base.modulate = tex_dim
	else:
		base.texture = gradient_texture(fallback_top, fallback_bottom)
	root.add_child(base)

	var veil := TextureRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.texture = gradient_texture(veil_top, veil_bottom)
	root.add_child(veil)

	return root

## Foto de estadio de noche (ui/bg/stadium_night.jpg) — para el fondo del
## PARTIDO y detrás de la barra superior. Devuelve la Texture2D o null si
## todavía no está importada.
const STADIUM_BG_PATH := "res://ui/bg/stadium_night.jpg"

static func stadium_texture() -> Texture2D:
	if ResourceLoader.exists(STADIUM_BG_PATH):
		return load(STADIUM_BG_PATH)
	return null

## Fondo a pantalla completa con la foto del estadio + velo en degradado
## configurable (para poder oscurecerlo más o menos según la pantalla).
## Cae al degradado plano si la imagen no está.
static func stadium_bg(veil_top: Color = Color(0.03, 0.05, 0.08, 0.45), veil_bottom: Color = Color(0.01, 0.015, 0.025, 0.72), dim: float = 0.62) -> Control:
	return _layered_bg(
		stadium_texture(),
		Color(dim, dim, dim, 1.0),
		veil_top, veil_bottom,
		Color(0.07, 0.11, 0.09), Color(0.02, 0.03, 0.025),
	)

## Tarjeta con una franja de color en el borde izquierdo — lenguaje visual
## de apps de carrera deportiva (EA FC Carrera / Soccer Champs, pedido
## explícito) para marcar de un vistazo "esto es tuyo" (tono del jugador)
## o "esto es de esta competencia" (tono de liga/copa/amistoso), sin
## necesitar una insignia redonda aparte cuando la tarjeta ya representa
## un solo estado con color propio.
static func card_accent(accent: Color, bg: Color = CARD_DARK, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_width_left = 4
	s.border_color = accent
	return s

## Círculo relleno — insignia de club, avatar de overall, etc. `size` es el
## lado del cuadrado que lo contiene (el corner_radius = size/2 lo redondea
## por completo).
static func circle(bg: Color, size: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(size / 2.0))
	return s

## Chip pequeño (p. ej. "Confianza DT: 92%") — tarjeta redondeada, más
## compacta que `card()`.
static func chip(bg: Color = CARD_DARK_2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(10)
	return s

## Negro o blanco, el que más contraste dé sobre `bg` — para texto/íconos
## encima de un color DINÁMICO (el color real de un club puede ser blanco
## o casi, y un texto/ícono claro fijo se volvería invisible ahí encima;
## visto de verdad con el primary_color_hex de Real Madrid/River Plate).
static func contrasting_text_color(bg: Color) -> Color:
	var luminance: float = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	return Color.BLACK if luminance > 0.6 else Color.WHITE

# =====================================================================
#  Assets Kenney UI Pack — polish puntual (el pack es de BOTONES y
#  controles, no trae paneles/tarjetas, así que NO se hace un swap
#  general de StyleBox; se usa donde suma: sliders y estrellas).
# =====================================================================

const _K_UI := "res://assets/ui/kenney/PNG/Grey/Default/"

## Fila de estrellas (rating N/total) con el sprite real de Kenney en vez
## de los caracteres ★/☆. `size` = alto en px.
static func star_row(filled: int, total: int = 5, size: int = 16, tint: Color = GOLD) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var full: Texture2D = load(_K_UI + "star.png") if ResourceLoader.exists(_K_UI + "star.png") else null
	var empty: Texture2D = load(_K_UI + "star_outline.png") if ResourceLoader.exists(_K_UI + "star_outline.png") else null
	if full == null:
		var l := Label.new()
		l.text = "★".repeat(clampi(filled, 0, total)) + "☆".repeat(maxi(0, total - filled))
		l.add_theme_color_override("font_color", tint)
		row.add_child(l)
		return row
	for i in range(total):
		var r := TextureRect.new()
		r.texture = full if i < filled else empty
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(size, size)
		r.modulate = tint if i < filled else Color(tint, 0.4)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(r)
	return row

## Aplica el look de Kenney a un HSlider (track + manija). El default de
## Godot se ve pobre; esto le da un riel y un tirador de verdad.
static func style_slider(slider: HSlider) -> void:
	var handle: String = _K_UI + "slide_hangle.png"
	var track: String = _K_UI + "slide_horizontal_grey.png"
	if ResourceLoader.exists(handle):
		var h: Texture2D = load(handle)
		slider.add_theme_icon_override("grabber", h)
		slider.add_theme_icon_override("grabber_highlight", h)
		slider.add_theme_icon_override("grabber_disabled", h)
	if ResourceLoader.exists(track):
		var sb := StyleBoxTexture.new()
		sb.texture = load(track)
		sb.set_texture_margin_all(7)
		sb.set_content_margin_all(0)
		slider.add_theme_stylebox_override("slider", sb)

# --- Botones con textura pixel-art (Kenney pixel-ui 9-slice) ---
# El pack `assets/ui/pixel/9-Slice/Colored/` son paneles 9-slice de 48px
# que se tiñen con `modulate_color`. `styled_button` sigue recibiendo un
# StyleBoxFlat (compat con TODOS los call sites) pero, si USE_PIX_BUTTONS,
# ignora su FORMA y usa la textura, leyendo el color deseado del propio
# StyleBoxFlat (bg_color si es relleno, border_color si es contorno).
const USE_PIX_BUTTONS := true
const _PIX_9S := "res://assets/ui/pixel/9-Slice/Colored/"
static var _pix_cache: Dictionary = {}

static func _pix_box(file: String, tint: Color, tex_m: int, content: int) -> StyleBoxTexture:
	var key := "%s|%s|%d|%d" % [file, tint.to_html(), tex_m, content]
	if _pix_cache.has(key):
		return _pix_cache[key]
	var s := StyleBoxTexture.new()
	var path := _PIX_9S + file
	if ResourceLoader.exists(path):
		s.texture = load(path)
	s.set_texture_margin_all(tex_m)
	s.set_content_margin_all(content)
	s.modulate_color = tint
	_pix_cache[key] = s
	return s

## Panel/tarjeta con textura pixel-art teñida. Para pantallas que se
## migran a mano (NO cambia `card()`, que muchas pantallas mutan).
static func panel_tex(tint: Color = CARD_DARK, content: int = 12) -> StyleBoxTexture:
	return _pix_box("grey.png", tint, 16, content)

## Botones "de juego" (9-oct, Wilber: "mejorá todos los botones"): esquinas
## redondeadas, canto inferior más oscuro (relieve), brillo arriba y al
## apretar el botón se HUNDE (el canto pasa arriba → el texto baja 3 px).
## Los de contorno: fondo oscuro neutro con borde del color de intención.
const USE_GAME_BUTTONS := true

static func _game_box(bg: Color, edge: Color, top_hi: Color, depth: int, sunk: bool, outline: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(12)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6 + (depth if sunk else 0)
	s.content_margin_bottom = 6 + (0 if sunk else depth)
	if outline.a > 0.0:
		s.set_border_width_all(2)
		s.border_color = outline
	s.border_width_bottom = (1 if sunk else depth) + (2 if outline.a > 0.0 else 0)
	s.border_width_top = 1 if not sunk else depth
	if outline.a <= 0.0:
		s.border_color = edge
	# El borde de arriba lleva el "brillo"; StyleBoxFlat tiene un solo color
	# de borde, así que el brillo va como sombra interna clara vía expand.
	s.shadow_color = Color(0, 0, 0, 0.30 if not sunk else 0.12)
	s.shadow_size = 3 if not sunk else 1
	s.shadow_offset = Vector2(0, 2 if not sunk else 0)
	s.anti_aliasing = true
	return s

static func _game_button(button: Button, bg: Color, filled: bool, intent: Color, text_color: Color) -> void:
	var edge: Color = bg.darkened(0.38)
	var outline: Color = Color(0, 0, 0, 0) if filled else intent
	if not filled:
		edge = Color(0.08, 0.09, 0.11)
	var depth: int = 4
	button.add_theme_stylebox_override("normal", _game_box(bg, edge, bg.lightened(0.25), depth, false, outline))
	button.add_theme_stylebox_override("hover", _game_box(bg.lightened(0.07), edge, bg.lightened(0.3), depth, false, outline))
	button.add_theme_stylebox_override("pressed", _game_box(bg.darkened(0.06), edge, bg, depth, true, outline))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var dis := _game_box(bg.lerp(Color(0.2, 0.2, 0.22), 0.55).darkened(0.25), edge.darkened(0.2), bg, 2, false, Color(outline, outline.a * 0.4))
	button.add_theme_stylebox_override("disabled", dis)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(k, text_color)
	button.add_theme_color_override("font_disabled_color", Color(text_color, 0.55))

## PESTAÑA con el mismo look en TODO el juego (P2, 9-oct — antes cada
## pantalla las pintaba de un color: verde, dorado, azul). `sub` = pestañas
## de segundo nivel (más chicas). Activa = dorada; inactiva = gris oscura.
static func tab(button: Button, on: bool, sub: bool = false) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 36.0 if sub else 44.0)
	button.add_theme_font_size_override("font_size", 13 if sub else 14)
	button.add_theme_font_override("font", font_semibold())
	if button.disabled:
		styled_button(button, pill_outlined(Color(1, 1, 1, 0.12)), Color(1, 1, 1, 0.25))
	elif on:
		styled_button(button, pill_filled(GOLD), Color.BLACK)
	elif sub:
		styled_button(button, pill_outlined(Color(1, 1, 1, 0.22)), GRAY_TEXT)
	else:
		styled_button(button, pill_filled(CARD_DARK_2), GRAY_TEXT)

static func styled_button(button: Button, style: StyleBox, text_color: Color = Color.WHITE) -> void:
	button.add_theme_font_override("font", font_semibold())

	# Color de intención del botón, venga de un StyleBoxFlat (pill_*/card_flat)
	# o de un StyleBoxTexture (card() con USE_PIX_PANELS).
	var flat: StyleBoxFlat = style as StyleBoxFlat
	var filled: bool = true
	var want: Color = CARD_DARK_2
	if flat != null:
		filled = flat.bg_color.a > 0.1
		want = flat.bg_color if filled else flat.border_color
	elif style is StyleBoxTexture:
		want = (style as StyleBoxTexture).modulate_color

	if USE_GAME_BUTTONS:
		_game_button(button, want if filled else Color(0.16, 0.17, 0.21), filled, want, text_color)
		if not button.pressed.is_connected(Audio.click):
			button.pressed.connect(Audio.click)
		return

	if USE_PIX_BUTTONS:
		# Relleno → panel teñido con el color. Contorno → panel oscuro
		# NEUTRO y el texto del color acento (se lee igual de bien).
		var base_tint: Color = want if filled else Color(0.17, 0.17, 0.19)
		button.add_theme_stylebox_override("normal", _pix_box("grey.png", base_tint, 16, 6))
		button.add_theme_stylebox_override("hover", _pix_box("grey.png", base_tint.lightened(0.07), 16, 6))
		button.add_theme_stylebox_override("pressed", _pix_box("grey_pressed.png", base_tint.darkened(0.05), 16, 6))
		button.add_theme_stylebox_override("disabled", _pix_box("grey.png", base_tint.darkened(0.4), 16, 6))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
			button.add_theme_color_override(k, text_color)
		if not button.pressed.is_connected(Audio.click):
			button.pressed.connect(Audio.click)
		return

	button.add_theme_stylebox_override("normal", style)
	if flat != null:
		var hover := flat.duplicate()
		hover.bg_color = flat.bg_color.lightened(0.08) if flat.bg_color.a > 0 else flat.bg_color
		button.add_theme_stylebox_override("hover", hover)
		var pressed := flat.duplicate()
		pressed.bg_color = flat.bg_color.darkened(0.08) if flat.bg_color.a > 0 else flat.bg_color
		button.add_theme_stylebox_override("pressed", pressed)
		var disabled := flat.duplicate()
		disabled.bg_color = flat.bg_color.darkened(0.35) if flat.bg_color.a > 0 else flat.bg_color
		button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	# font_disabled_color es una clave de tema APARTE de font_color — sin
	# esto, un botón deshabilitado usa el gris apagado por defecto de
	# Godot, que en un texto ya claro (blanco) se ve bien, pero en un
	# texto oscuro pensado para un fondo de color (p. ej. negro sobre
	# verde) queda invisible sobre el negro de fondo de la app.
	button.add_theme_color_override("font_disabled_color", text_color)

	# Sonido de clic (Kenney Interface Sounds, autoload Audio). Todo botón
	# que pasa por acá suena. Idempotente: styled_button se llama muchas
	# veces por re-render, pero el Callable de Audio.click es el mismo.
	if not button.pressed.is_connected(Audio.click):
		button.pressed.connect(Audio.click)


# ---------------------------------------------------------------- horizontal
## HORIZONTAL (FootballLegacy H): reparte el contenido de `box` en DOS
## columnas parejas, sin cortar ninguna sección (cada una arranca en un
## section_label). Los primeros `keep_top` hijos (la cabecera) quedan a lo
## ancho. Llamar al principio del _render(): corre al final del cuadro, ya
## con todo armado, y si la pantalla se redibuja se rehace sola.
static func land_columns_later(box: VBoxContainer, keep_top: int = 1) -> void:
	(func(): land_columns(box, keep_top)).call_deferred()

static func land_columns(box: VBoxContainer, keep_top: int = 1) -> void:
	if box == null or not is_instance_valid(box) or not box.is_inside_tree():
		return
	var vp: Vector2 = box.get_viewport().get_visible_rect().size
	if vp.x <= vp.y:
		return
	var old: Node = box.get_node_or_null("LandCols")
	if old != null:
		var back: Array = []
		for col in old.get_children():
			for k in col.get_children():
				if not k.is_queued_for_deletion():
					back.append(k)
		back.sort_custom(func(a, b): return int(a.get_meta("land_order", 0)) < int(b.get_meta("land_order", 0)))
		var at: int = old.get_index()
		for k in back:
			k.reparent(box)
			box.move_child(k, at)
			at += 1
		box.remove_child(old)
		old.queue_free()
	var kids: Array = []
	for c in box.get_children():
		if not c.is_queued_for_deletion():
			kids.append(c)
	if kids.size() < keep_top + 2:
		return
	var groups: Array = []
	for i in range(keep_top, kids.size()):
		var c: Node = kids[i]
		c.set_meta("land_order", i)
		if groups.is_empty() or (c is Label and c.has_meta("section")):
			groups.append([c])
		else:
			(groups.back() as Array).append(c)
	if groups.size() < 2:
		groups.clear()
		for i in range(keep_top, kids.size()):
			groups.append([kids[i]])
	# Héroe arriba -> pasa a la barra izquierda (info a la izquierda,
	# contenido a la derecha) en vez de ocupar todo el ancho.
	var side_hero: Control = null
	if keep_top == 1 and kids[0] is PanelContainer and (kids[0] as Node).has_meta("ui_hero"):
		side_hero = kids[0]
		kids[0].set_meta("land_order", 0)
	var cols := HBoxContainer.new()
	cols.name = "LandCols"
	cols.add_theme_constant_override("separation", 18)
	var col_v: Array = []
	var col_h: Array = [0.0, 0.0]
	for i in 2:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", box.get_theme_constant("separation"))
		cols.add_child(v)
		col_v.append(v)
	box.add_child(cols)
	box.move_child(cols, 0 if side_hero != null else keep_top)
	if side_hero != null:
		UiKit.hero_to_column(side_hero)
		side_hero.reparent(col_v[0])
		col_h[0] = side_hero.get_combined_minimum_size().y + 8.0
		(col_v[0] as Control).size_flags_stretch_ratio = 0.8
	# En orden: cada sección va a la columna más baja hasta ese momento.
	for g in groups:
		var h: float = 0.0
		for n in g:
			if n is Control:
				h += (n as Control).get_combined_minimum_size().y + 8.0
		var tgt: int = 0 if col_h[0] <= col_h[1] else 1
		for n in g:
			(n as Node).reparent(col_v[tgt])
		col_h[tgt] += h
	var sc := box.get_parent() as ScrollContainer
	if sc != null:
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
