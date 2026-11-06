extends RefCounted
class_name DataTable

## Fila de tabla "profesional": encabezado con separador propio, filas en
## tarjeta con cebra (zebra striping) para escanear fácil, dorado para
## "esto es tuyo" — un solo lugar para Standings/CupBracket/WorldExplorer,
## que antes tenían cada uno su propia versión casi idéntica de esto.

## Agrega UNA fila a `container` (append-only — el llamador limpia el
## contenedor antes de la primera llamada, igual que siempre).
## `on_click` (opcional, Callable de 0 argumentos): si es válido, la fila
## se puede tocar — usar Callable().bind(...) para pasarle argumentos.
static func add_row(container: VBoxContainer, cells: Array, widths: Array, is_header: bool, is_mine: bool = false, on_click: Callable = Callable(), accent: Color = Color.TRANSPARENT, lead: Control = null) -> void:
	# Cebra sobre el conteo de hijos ya puestos: no hace falta un índice
	# aparte, y cuando se pegan varias tablas seguidas (grupos de copa
	# continental) el patrón simplemente sigue, no se resetea a lo tonto.
	var node := make_row(cells, widths, is_header, is_mine, on_click, accent, container.get_child_count(), lead)
	container.add_child(node)

## Igual que add_row pero DEVUELVE el nodo en vez de agregarlo — para
## listas paginadas (ver Pager.gd), donde cada fila la coloca el Pager.
## `row_index` alimenta la cebra (par/impar); -1 = sin cebra (fila sola).
static func make_row(cells: Array, widths: Array, is_header: bool, is_mine: bool = false, on_click: Callable = Callable(), accent: Color = Color.TRANSPARENT, row_index: int = -1, lead: Control = null) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if lead != null:
		lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lead)
	for i in range(cells.size()):
		var lbl := Label.new()
		lbl.text = str(cells[i])
		lbl.custom_minimum_size = Vector2(widths[i], 0)
		if widths[i] >= 90: # columna de texto (nombre/club)
			# clip_text hace que el ancho mínimo ignore el texto: un nombre
			# largo nunca empuja la tabla (pedido de Wilber). Y EXPAND_FILL
			# hace que esta columna se coma el espacio sobrante -> los
			# números quedan pegados a la derecha, sin hueco muerto.
			lbl.clip_text = true
			lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if is_header:
			lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
			lbl.add_theme_font_size_override("font_size", 12)
		elif is_mine:
			lbl.add_theme_color_override("font_color", Styles.GOLD)
		row.add_child(lbl)

	if is_header:
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 12)
		pad.add_theme_constant_override("margin_right", 12)
		pad.add_theme_constant_override("margin_bottom", 4)
		pad.add_child(row)
		var box := VBoxContainer.new()
		box.add_child(pad)
		box.add_child(HSeparator.new())
		return box

	var idx: int = row_index if row_index >= 0 else 0
	var bg: Color = Color(0.3, 0.24, 0.05) if is_mine else (Styles.CARD_DARK_2 if idx % 2 == 0 else Styles.CARD_DARK)
	var style: StyleBoxFlat = Styles.card_accent(accent, bg, 6) if accent.a > 0.0 else Styles.card_flat(bg, 6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(row)

	if on_click.is_valid():
		UiScroll.on_tap(panel, on_click)

	return panel

## Etiqueta de sección chica ("FASE DE GRUPOS", "ELIMINATORIAS"...) en vez
## de un Label gris suelto — un rótulo con más peso visual que separa
## bloques dentro de una misma pantalla larga.
static func section_tag(text: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", Styles.chip(Styles.CARD_DARK_2))
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	panel.add_child(lbl)
	return panel
