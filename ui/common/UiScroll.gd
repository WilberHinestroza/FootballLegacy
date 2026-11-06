extends RefCounted
class_name UiScroll

## Deja TODO ScrollContainer de un subárbol con scroll TÁCTIL (arrastre del
## contenido con el dedo, gana por sobre botones/tarjetas de adentro) y sin
## la barrita. Pedido explícito de Wilber.

## deadzone ~12: suficiente para que un arrastre "gane" por sobre un botón
## de adentro, sin exigir un tirón enorme (30 se sentía errático/lento).
## No se toca horizontal_scroll_mode: hay filas de pestañas que scrollean
## en horizontal y necesitan verse.
static func make_touch(node: Node) -> void:
	if node is ScrollContainer:
		var sc := node as ScrollContainer
		# deadzone alto: un arrastre gana claramente sobre los botones de
		# adentro (Wilber: "el scroll táctil va muy mal"). follow_focus off
		# para que no salte solo al enfocar un control.
		sc.scroll_deadzone = 26
		sc.follow_focus = false
		# Vertical: se scrollea con el dedo pero sin barrita.
		if sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO:
			sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		# Horizontal: se DESACTIVA solo en los ScrollContainer marcados en el
		# grupo "vlist" (listas puramente verticales). Así su contenido se
		# clampa al ancho de pantalla y el `clip_text` de los labels funciona
		# — era la causa del texto cortado a la izquierda ("todo más grande").
		# Las tablas anchas de verdad (clasificación, fase de grupos) NO
		# llevan el grupo y conservan su scroll horizontal.
		# Filas puramente horizontales (suplentes, pestañas): se arrastran
		# con el dedo, sin la barrita blanca debajo.
		if sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO:
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		if sc.is_in_group("vlist") and sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO:
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	for child in node.get_children():
		make_touch(child)

## Botones/controles DENTRO de una lista: MOUSE_FILTER_PASS en vez de
## STOP. Causa raíz del "el táctil a veces funciona y a veces no" (9-oct,
## medido con tools/TouchProbe): un arrastre que EMPEZABA sobre un botón no
## llegaba nunca al ScrollContainer (STOP corta la propagación) → la lista
## no se movía; si empezaba sobre un texto, sí. En pantallas llenas de
## botones (Tienda, Fichajes, menús) eso era la mitad de los intentos.
## Con PASS el toque sigue apretando el botón, y el arrastre llega a la
## lista, que lo toma al pasar la zona muerta.
static func touch_friendly(node: Node) -> void:
	for c in node.get_children():
		_pass_if_blocking(c)
		touch_friendly(c)

static func _pass_if_blocking(c: Node) -> void:
	if not (c is Control) or c is ScrollContainer or c is Range:
		return   # sliders/barras necesitan quedarse con su arrastre
	var ctl := c as Control
	if ctl.mouse_filter == Control.MOUSE_FILTER_STOP and (c is BaseButton or c is LineEdit or c is TextEdit or c is Container or c is Panel):
		ctl.mouse_filter = Control.MOUSE_FILTER_PASS

## Enganche GLOBAL (lo instala Nav en _ready): todo control que entra al
## árbol DENTRO de una lista queda "pasante". Hace falta así porque las
## pantallas rearman sus listas a cada rato (_render) con botones nuevos.
static func on_node_added(n: Node) -> void:
	if not (n is Control):
		return
	if n is Label:
		_min_font.call_deferred(n)
	if n is HSlider:
		_style_slider(n as HSlider)
	var p: Node = n.get_parent()
	var depth: int = 0
	while p != null and depth < 24:
		if p is ScrollContainer:
			_pass_if_blocking(n)
			return
		p = p.get_parent()
		depth += 1

## Piso de tamaño de letra (9-oct, Wilber: "todo muy apretado"): había
## descripciones a 9-11 px (Entrenar, Agente, tarjeta de Carrera) que en el
## celular quedaban ilegibles. Base 576 px de ancho → 12 es el mínimo.
const MIN_FONT := 12

## Sin tipo en el parámetro: si el Label se liberó en el mismo frame, la
## llamada diferida trae un objeto muerto y el tipado `Label` fallaba al
## convertir ANTES de llegar al is_instance_valid ("Cannot convert argument").
static func _min_font(obj) -> void:
	if not is_instance_valid(obj) or not (obj is Label):
		return
	var l: Label = obj
	if not l.has_theme_font_size_override("font_size"):
		return
	# Solo 10-11: lo de 9 o menos es a propósito (iniciales dentro de
	# escudos/insignias chiquitas) y subirlo lo desbordaría.
	var fs: int = l.get_theme_font_size("font_size")
	if fs >= 10 and fs < MIN_FONT:
		l.add_theme_font_size_override("font_size", MIN_FONT)

## TOQUE real para tarjetas/filas clickeables (9-oct). Antes cada una
## reaccionaba al APOYAR el dedo y con MOUSE_FILTER_STOP: intentar
## arrastrar una lista empezando sobre un jugador/noticia/día ABRÍA eso en
## vez de scrollear — otra cara del "el táctil a veces funciona y a veces
## no". Ahora: se dispara al SOLTAR, y solo si el dedo casi no se movió
## (si se movió, era un arrastre de la lista). PASS deja que la lista
## reciba el arrastre.
const TAP_SLOP := 18.0

static func on_tap(c: Control, cb: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(ev: InputEvent):
		if not (ev is InputEventMouseButton) or ev.button_index != MOUSE_BUTTON_LEFT:
			return
		if ev.pressed:
			c.set_meta("_tap_from", ev.global_position)
		elif c.has_meta("_tap_from"):
			var from: Vector2 = c.get_meta("_tap_from")
			c.remove_meta("_tap_from")
			if from.distance_to(ev.global_position) <= TAP_SLOP:
				cb.call()
	)

## Deslizadores (9-oct): sin estilo propio solo se veía la "manija" blanca
## suelta, sin barra (Ajustes, año de nacimiento) — no se entendía qué era.
## Barra oscura + parte llena dorada + manija redonda.
static func _style_slider(sl: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.21, 0.25)
	track.set_corner_radius_all(6)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.85, 0.3)
	fill.set_corner_radius_all(6)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := Image.create(26, 26, false, Image.FORMAT_RGBA8)
	for y in range(26):
		for x in range(26):
			var d: float = Vector2(x - 12.5, y - 12.5).length()
			if d <= 12.0:
				knob.set_pixel(x, y, Color(1, 1, 1) if d < 10.0 else Color(0.85, 0.7, 0.2))
	var kt := ImageTexture.create_from_image(knob)
	sl.add_theme_icon_override("grabber", kt)
	sl.add_theme_icon_override("grabber_highlight", kt)
	if sl.custom_minimum_size.y < 28:
		sl.custom_minimum_size.y = 28

const _PAD_NAME := "_ListBottomPad"

## Añade (una sola vez) un colchón al final de un contenedor de lista para
## que el ÚLTIMO ítem no quede pegado ni tapado por el botón "Volver" que
## va abajo de la pantalla (pedido de Wilber). Idempotente: si el populate
## de la pantalla borra y rearma la lista, se vuelve a llamar y listo.
static func pad_bottom(container: Node, px: int = 30) -> void:
	if container == null or not is_instance_valid(container):
		return
	# Quita cualquier colchón previo (rerender) sin depender del diferido.
	for c in container.get_children():
		if String(c.name).begins_with(_PAD_NAME):
			container.remove_child(c)
			c.queue_free()
	var sp := Control.new()
	sp.name = _PAD_NAME
	sp.custom_minimum_size = Vector2(0, px)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(sp)
	# De paso, deja el ScrollContainer que lo contiene con arrastre táctil
	# "duro" (deadzone alto, sin barrita) — Wilber: "el scroll táctil va
	# muy mal". Así se aplica en TODA pantalla que llame a pad_bottom, sin
	# tocar cada _ready.
	var p: Node = container.get_parent()
	while p != null and not (p is ScrollContainer):
		p = p.get_parent()
	if p is ScrollContainer:
		var sc := p as ScrollContainer
		sc.scroll_deadzone = 26
		sc.follow_focus = false
		if sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO:
			sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
