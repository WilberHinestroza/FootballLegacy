extends VBoxContainer
class_name Pager

## Lista PAGINADA con botones ◀ / ▶ — reemplaza el scroll táctil en las
## pantallas con listas largas (pedido explícito: el táctil se sentía
## errático). No scrollea nada: muestra N filas por hoja y se cambia de
## hoja con botones.

var _items: Array = []
var _per: int = 12
var _build: Callable = Callable()
var _page: int = 0
var _pages: int = 1
var _page_labels: PackedStringArray = []  # opcional: rótulo por hoja (ej. nombre de continente)

var _rows: VBoxContainer
var _bar: HBoxContainer
var _header: VBoxContainer   # ranura fija entre la barra y las filas (ej. encabezado de columnas)
var _prev: Button
var _next: Button
var _lbl: Label

func _ready() -> void:
	add_theme_constant_override("separation", 10)

	# La barra ◀ ▶ va SIEMPRE ARRIBA de las filas (pedido de Wilber): así
	# no se mueve cuando una hoja tiene menos filas que otra.
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 10)
	# Barra compacta (9-oct): antes ocupaba una fila enorme de 48 px.
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_prev = Button.new()
	_prev.custom_minimum_size = Vector2(46, 32)
	_prev.focus_mode = Control.FOCUS_NONE
	var _arr_w := "res://assets/ui/kenney/PNG/Grey/Default/arrow_basic_w.png"
	var _arr_e := "res://assets/ui/kenney/PNG/Grey/Default/arrow_basic_e.png"
	if ResourceLoader.exists(_arr_w):
		_prev.icon = load(_arr_w)
		_prev.add_theme_constant_override("icon_max_width", 16)
		_prev.expand_icon = false
	else:
		_prev.text = "◀"
	_prev.pressed.connect(func(): _go(_page - 1))
	_lbl = Label.new()
	# P2 (9-oct): ◀ 1/3 ▶ agrupado al centro y más chico (sigue ARRIBA de la
	# lista, pedido explícito de Wilber, para que no salte entre hojas).
	_lbl.custom_minimum_size = Vector2(110, 32)
	_lbl.add_theme_font_override("font", Styles.font_semibold())
	_lbl.clip_text = true
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	_next = Button.new()
	_next.custom_minimum_size = Vector2(46, 32)
	_next.focus_mode = Control.FOCUS_NONE
	if ResourceLoader.exists(_arr_e):
		_next.icon = load(_arr_e)
		_next.add_theme_constant_override("icon_max_width", 16)
		_next.expand_icon = false
	else:
		_next.text = "▶"
	_next.pressed.connect(func(): _go(_page + 1))
	_bar.add_child(_prev)
	_bar.add_child(_lbl)
	_bar.add_child(_next)
	add_child(_bar)

	_header = VBoxContainer.new()
	add_child(_header)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_rows)

	_style_nav()

func _style_nav() -> void:
	Styles.styled_button(_prev, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	Styles.styled_button(_next, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)

## items: Array de datos. build: Callable(item) -> Control (la fila).
## page_labels (opcional): un texto por HOJA para el centro de la barra
## (ej. el nombre del continente). Si está vacío se muestra "N / M".
func show_items(items: Array, per: int, build: Callable, keep_page: bool = false, page_labels: PackedStringArray = PackedStringArray()) -> void:
	_items = items
	_per = maxi(per, 1)
	_build = build
	_page_labels = page_labels
	_pages = maxi(1, ceili(float(_items.size()) / float(_per)))
	if not keep_page:
		_page = 0
	_page = clampi(_page, 0, _pages - 1)
	if _rows == null:
		await ready
	_render()

func _go(p: int) -> void:
	_page = clampi(p, 0, _pages - 1)
	_render()

## Salta a una hoja concreta (para abrir una lista ya posicionada).
func goto_page(p: int) -> void:
	_go(p)

## Nodo fijo entre la barra ◀ ▶ y las filas (ej. la fila de encabezado de
## una tabla). Se puede llamar antes o después de show_items.
func set_header(node: Control) -> void:
	if _header == null:
		await ready
	for c in _header.get_children():
		c.queue_free()
	if node != null:
		_header.add_child(node)

func _render() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var start: int = _page * _per
	for i in range(start, mini(start + _per, _items.size())):
		var row: Variant = _build.call(_items[i])
		if row is Control:
			_rows.add_child(row)
	if _page < _page_labels.size() and _page_labels[_page] != "":
		_lbl.text = "%s  ·  %d/%d" % [_page_labels[_page], _page + 1, _pages]
	else:
		_lbl.text = "%d / %d" % [_page + 1, _pages]
	_prev.disabled = _page <= 0
	_next.disabled = _page >= _pages - 1
	_bar.visible = _pages > 1
	_style_nav()
