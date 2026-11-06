extends Control

## Feed de prensa completo (PlayerData.press_feed) — más reciente primero.
## Lectura pura, no muta nada.

## Paginado con ◀ ▶ (Pager) en vez de scroll táctil — pedido de Wilber.
const PER_PAGE := 4

@onready var entries_box: VBoxContainer = $Margin/VBox/Scroll/EntriesBox
@onready var scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var back_button: Button = $Margin/VBox/BackButton

## Titular a resaltar al entrar (lo pasa el Hub al tocar su tarjeta).
var _focus_key: String = ""

static func _key_of(entry: Dictionary) -> String:
	return "%d|%s" % [int(entry.get("day", 0)), String(entry.get("headline", ""))]

func _ready() -> void:
	_focus_key = WorldTickEngine.focus_news_key
	WorldTickEngine.focus_news_key = ""  # de un solo uso
	back_button.pressed.connect(_on_back_pressed)
	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_render()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")

func _render() -> void:
	for child in entries_box.get_children():
		child.queue_free()

	var player := SaveManager.load_player()
	var feed: Array = (player.press_feed if player != null else []).duplicate(true)

	# Mezcla los titulares del MUNDO (WorldNewsEngine, derivados/vivos) con
	# los tuyos (press_feed, persistidos). Ordenado por día, más reciente
	# primero. Así Noticias nunca se ve "en pausa".
	if player != null:
		feed.append_array(WorldNewsEngine.weekly(WorldTickEngine, player, WorldTickEngine.current_epoch_day))
	feed.sort_custom(func(a, b): return int(a.get("day", 0)) > int(b.get("day", 0)))

	if feed.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Todavía no hay titulares."
		entries_box.add_child(empty_label)
		UiKit.empty_icon(empty_label, Icons.PX_NEWS)
		return

	if get_viewport_rect().size.x > get_viewport_rect().size.y:
		_render_front_page(feed)
		return
	var pager := Pager.new()
	entries_box.add_child(pager)
	pager.show_items(feed, PER_PAGE, _make_card)
	# Si venimos del Hub tocando una noticia, abrir su hoja.
	if _focus_key != "":
		for i in range(feed.size()):
			if _key_of(feed[i]) == _focus_key:
				pager.goto_page(i / PER_PAGE)
				break
	UiScroll.pad_bottom(entries_box)

func _make_card(entry: Dictionary) -> PanelContainer:
	var accent: Color = Styles.sentiment_color(entry.get("sentiment", ""))
	var is_focus: bool = _focus_key != "" and _key_of(entry) == _focus_key
	var panel := PanelContainer.new()
	if is_focus:
		var fs := Styles.card_accent(Styles.GOLD)
		fs.set_border_width_all(2)
		fs.border_color = Styles.GOLD
		panel.add_theme_stylebox_override("panel", fs)
	else:
		panel.add_theme_stylebox_override("panel", Styles.card_accent(accent))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)

	var source: String = MediaOutlets.display(String(entry.get("source", "")))
	var source_row := HBoxContainer.new()
	source_row.add_theme_constant_override("separation", 7)
	if source != "":
		var lg := MediaOutlets.logo(source, 26)
		lg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		source_row.add_child(lg)
	var source_lbl := Label.new()
	var tag: String = "  ·  MUNDO" if entry.get("world", false) else "  ·  SOBRE TI"
	source_lbl.text = "%s  ·  día %d%s" % [source, int(entry.get("day", 0)), tag]
	source_lbl.add_theme_color_override("font_color", accent)
	source_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	source_row.add_child(source_lbl)

	var headline_lbl := Label.new()
	headline_lbl.text = entry.get("headline", "")
	headline_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline_lbl.add_theme_font_size_override("font_size", Styles.SIZE_HEADING)

	var body_lbl := Label.new()
	body_lbl.text = entry.get("body", "")
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	vb.add_child(source_row)
	vb.add_child(headline_lbl)
	vb.add_child(body_lbl)
	margin.add_child(vb)
	panel.add_child(margin)
	return panel


# ---------------------------------------------------------------- horizontal
## PORTADA (horizontal): la nota elegida en grande a la izquierda, como la
## tapa de un diario deportivo; a la derecha todos los titulares en lista.
## Tocar un titular lo pasa a la portada.
func _render_front_page(feed: Array) -> void:
	var main: Dictionary = feed[0]
	for e in feed:
		if _focus_key != "" and _key_of(e) == _focus_key:
			main = e
			break
	var sc := entries_box.get_parent() as ScrollContainer
	if sc != null:
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	entries_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	entries_box.add_child(cols)
	cols.custom_minimum_size.y = maxf(sc.size.y if sc != null else 360.0, 360.0)
	# Portada.
	var accent: Color = Styles.sentiment_color(main.get("sentiment", ""))
	var front := PanelContainer.new()
	front.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	front.size_flags_stretch_ratio = 1.25
	var fsb := Styles.card_flat(Color(0.08, 0.09, 0.11, 0.95), 16)
	fsb.border_width_top = 5
	fsb.border_color = accent
	fsb.content_margin_left = 24
	fsb.content_margin_right = 24
	fsb.content_margin_top = 20
	fsb.content_margin_bottom = 20
	front.add_theme_stylebox_override("panel", fsb)
	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 12)
	var src: String = MediaOutlets.display(String(main.get("source", "")))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	if src != "":
		head.add_child(MediaOutlets.logo(src, 40))
	var hv := VBoxContainer.new()
	var sl := Label.new()
	sl.text = src.to_upper()
	sl.add_theme_font_override("font", Styles.font_black())
	sl.add_theme_font_size_override("font_size", 15)
	sl.add_theme_color_override("font_color", accent)
	hv.add_child(sl)
	var dl := Label.new()
	dl.text = "Día %d  ·  %s" % [int(main.get("day", 0)), "Mundo" if main.get("world", false) else "Sobre vos"]
	dl.add_theme_font_size_override("font_size", 12)
	dl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	hv.add_child(dl)
	head.add_child(hv)
	fv.add_child(head)
	var hl := Label.new()
	hl.text = String(main.get("headline", ""))
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.add_theme_font_override("font", Styles.font_black())
	hl.add_theme_font_size_override("font_size", 28)
	fv.add_child(hl)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(80, 3)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	line.color = accent
	fv.add_child(line)
	var bl := Label.new()
	bl.text = String(main.get("body", ""))
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.add_theme_font_size_override("font_size", 17)
	bl.add_theme_color_override("font_color", Color(0.86, 0.88, 0.92))
	fv.add_child(bl)
	# Logo grande del medio abajo a la derecha: llena la portada cuando la
	# nota es corta (antes quedaba un hueco negro).
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fv.add_child(sp)
	if src != "":
		var big := MediaOutlets.logo(src, 110)
		big.size_flags_horizontal = Control.SIZE_SHRINK_END
		big.modulate = Color(1, 1, 1, 0.35)
		fv.add_child(big)
	front.add_child(fv)
	cols.add_child(front)
	# Titulares.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	right.add_child(Styles.section_label("Últimos titulares"))
	var lsc := ScrollContainer.new()
	lsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiScroll.make_touch(lsc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	lsc.add_child(list)
	right.add_child(lsc)
	cols.add_child(right)
	for e in feed:
		list.add_child(_headline_row(e, e == main))

func _headline_row(e: Dictionary, current: bool) -> Control:
	var p := PanelContainer.new()
	var sb := Styles.card_flat(Color(0.2, 0.17, 0.05) if current else Styles.CARD_DARK_2, 10)
	sb.border_width_left = 3
	sb.border_color = Styles.GOLD if current else Styles.sentiment_color(e.get("sentiment", ""))
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var src: String = MediaOutlets.display(String(e.get("source", "")))
	if src != "":
		var lg := MediaOutlets.logo(src, 22)
		lg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(lg)
	var t := Label.new()
	t.text = String(e.get("headline", ""))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("font_size", 14)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	var d := Label.new()
	d.text = "d%d" % int(e.get("day", 0))
	d.add_theme_font_size_override("font_size", 11)
	d.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(d)
	p.add_child(h)
	UiScroll.on_tap(p, func():
		_focus_key = _key_of(e)
		_render())
	return p
