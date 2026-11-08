extends Control

## Premios anuales — seguimiento EN VIVO de la temporada del mundo
## (mismo principio que la Vitrina / el Balón de Oro de fin de año, pero
## consultable en cualquier momento). Seis pestañas, todas MUNDIALES:
##   Balón de Oro  → WorldTickEngine.ballon_dor_ranking() (BallonDorEngine).
##   Bota de Oro   → goles × coeficiente de liga (YearAwardsEngine).
##   Asistencias   → el que más asistencias da (YearAwardsEngine).
##   Guante de Oro → el mejor portero (YearAwardsEngine).
##   Once ideal    → 1-4-3-3 del año, dibujado en un campo (YearAwardsEngine).
##   Rendimiento   → nota estimada de la temporada; para TI tu media real.
## Diseño (8-nov, Wilber: "el menú de premios se ve horrible"): arriba solo
## las pestañas; en horizontal, dos columnas fijas — trofeo + podio a la
## izquierda, ranking paginado a la derecha — sin nada cortado. Nada se
## simula ni se guarda acá: es lectura del mundo vivo.

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var season_label: Label = $Margin/VBox/SeasonLabel
@onready var tabs_row: HBoxContainer = $Margin/VBox/TabsRow
@onready var content_box: VBoxContainer = $Margin/VBox/Scroll/ContentBox
@onready var scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var back_button: Button = $Margin/VBox/BackButton

## Nombre corto en el botón (seis caben en vertical) y el completo en la cabecera.
const TABS := ["Balón", "Bota", "Asist.", "Guante", "Once", "Notas"]
const TAB_TITLES := ["Balón de Oro", "Bota de Oro", "Rey de las asistencias", "Guante de Oro", "Once ideal del año", "Rendimiento"]
## Trofeo que ilustra cada pestaña (pedido de Wilber: "muestra el premio
## en cada viñeta de los premios individuales").
const TAB_HONORS := ["ballon_dor", "bota_oro", "mvp_liga", "guante_oro", "once_ideal", "mvp_temporada"]
const TAB_HOW := ["El mejor jugador del mundo: goles, asistencias y títulos.",
	"El máximo goleador: los goles valen el doble en las ligas de élite.",
	"El que más asistencias da en la temporada.",
	"El mejor portero: porterías a cero, nivel y títulos.",
	"Los once mejores del mundo, puesto por puesto.",
	"La mejor nota promedio de la temporada."]
## Rankings mundiales recortados al Top 10 (pedido de Wilber: consulta liviana;
## el cómputo pesado ya está cacheado por día en WorldTickEngine).
const TOP_N := 10
const COLS := [34, 180, 150, 70]
var _tab: int = 0
var _tab_buttons: Array[Button] = []
var _bd: Array = []
var _ya: Dictionary = {} # premios del año (YearAwardsEngine): shoe, assists, keepers, xi
var _pager: Pager = null
var _season_text := ""

## true si se entra desde la ceremonia de fin de temporada (resumen → premios
## → carga de la nueva temporada): el botón dice "Continuar".
var _flow_mode: bool = false

func _ready() -> void:
	WorldTickEngine.load_runtime()
	_flow_mode = WorldTickEngine.post_season_flow
	back_button.pressed.connect(_on_back_pressed)
	if _flow_mode:
		back_button.text = "Continuar"
		back_button.icon = Icons.load_icon(Icons.PLAY)
		Styles.styled_button(back_button, Styles.pill_filled(Styles.GOLD), Color.BLACK)
		back_button.custom_minimum_size = Vector2(0, 44)
	# Fuera del flujo de fin de temporada ya está la flecha de la barra de arriba
	back_button.visible = _flow_mode
	# Cabecera compacta: la pantalla es para los rankings, no para el título
	title_label.visible = false
	season_label.visible = false
	var margin := $Margin as MarginContainer
	margin.add_theme_constant_override("margin_top", 78)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	($Margin/VBox as VBoxContainer).add_theme_constant_override("separation", 10)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	content_box.add_theme_constant_override("separation", 10)

	var start_year: int = CalendarUtils.season_start_year(WorldTickEngine.current_epoch_day)
	_season_text = "Temporada %d/%d" % [start_year, start_year + 1]

	tabs_row.add_theme_constant_override("separation", 6)
	for i in range(TABS.size()):
		var b := Button.new()
		b.text = TABS[i]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 14)
		b.clip_text = true
		b.pressed.connect(_on_tab_pressed.bind(i))
		tabs_row.add_child(b)
		_tab_buttons.append(b)

	_refresh_tabs()
	# El ranking recorre las ligas de élite: puede tardar. Pintamos la pantalla
	# con un aviso y lo calculamos al frame siguiente (transición sin congelar).
	_empty("Calculando premios de la temporada…")
	await get_tree().process_frame
	await get_tree().process_frame
	_bd = WorldTickEngine.ballon_dor_ranking()
	_ya = WorldTickEngine.year_awards()
	# Fin de temporada: los ganadores de la temporada que TERMINÓ.
	if _flow_mode and not WorldTickEngine.final_awards.is_empty():
		_bd = WorldTickEngine.final_awards
		if not WorldTickEngine.final_year_awards.is_empty():
			_ya = WorldTickEngine.final_year_awards
		var y: int = WorldTickEngine.final_awards_year
		if y > 0:
			_season_text = "Temporada %d/%d" % [y, y + 1]
	if is_inside_tree():
		_render()

func _on_back_pressed() -> void:
	if _flow_mode:
		get_tree().change_scene_to_file("res://scenes/SeasonLoading/SeasonLoading.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")

func _on_tab_pressed(i: int) -> void:
	_tab = i
	_refresh_tabs()
	_render()

func _refresh_tabs() -> void:
	for i in range(_tab_buttons.size()):
		Styles.tab(_tab_buttons[i], i == _tab)

func _wide() -> bool:
	return get_viewport_rect().size.x > get_viewport_rect().size.y

func _render() -> void:
	for c in content_box.get_children():
		c.queue_free()
	_pager = null
	if _bd.is_empty():
		content_box.add_child(_trophy_header())
		_render_showcase()
		return
	var player := SaveManager.load_player()
	var my_name: String = player.player_name if player != null else ""
	if _tab == 4:
		_render_team_of_year()
		if not _wide():
			UiScroll.pad_bottom(content_box)
		return
	# Dos columnas en horizontal (trofeo + destacado | ranking); una en vertical
	var wide := _wide()
	var body: BoxContainer = HBoxContainer.new() if wide else VBoxContainer.new()
	body.add_theme_constant_override("separation", 20 if wide else 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.85
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.15
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	left.add_child(_trophy_header())
	match _tab:
		5:
			_render_performance(left, right, my_name)
		3:
			_render_ranked(left, right, _ya.get("keepers", []), "PaC", my_name,
				func(r): return str(int(r.get("cs", 0))),
				func(r): return "%d a cero" % int(r.get("cs", 0)),
				"Todavía no hay porteros destacados esta temporada.")
		2:
			_render_ranked(left, right, _ya.get("assists", []), "Asist.", my_name,
				func(r): return str(int(r.get("assists", 0))),
				func(r): return "%d asist." % int(r.get("assists", 0)),
				"Todavía no hay asistencias registradas esta temporada.")
		1:
			_render_ranked(left, right, _ya.get("shoe", []), "Goles", my_name,
				func(r): return "%d (%s)" % [int(r.get("goals", 0)), _pts(float(r.get("points", 0.0)))],
				func(r): return "%d goles" % int(r.get("goals", 0)),
				"Todavía no hay goles registrados esta temporada.")
		_:
			_render_ranked(left, right, _bd, "Pts", my_name,
				func(r): return str(int(round(float(r.get("score", 0.0))))),
				func(r): return "%d G · %d A" % [int(r.get("goals", 0)), int(r.get("assists", 0))],
				"Todavía no hay datos esta temporada.")
	if not wide:
		UiScroll.pad_bottom(content_box)

## Cabecera: el trofeo de la pestaña, su nombre, la temporada y cómo se gana.
func _trophy_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var tro := Trophy.for_honor(TAB_HONORS[_tab], 52)
	if tro != null:
		tro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tro)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_lbl := Label.new()
	name_lbl.text = TAB_TITLES[_tab]
	name_lbl.add_theme_font_override("font", Styles.font_black())
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Styles.GOLD)
	v.add_child(name_lbl)
	var sub := Label.new()
	sub.text = "%s · %s" % [_season_text, TAB_HOW[_tab]]
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(sub)
	row.add_child(v)
	return row

func _empty(text: String, into: Node = null) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	(into if into != null else content_box).add_child(l)
	if not text.begins_with("Calculando"):
		UiKit.empty_icon(l, Icons.PX_AWARDS)

## Un premio con ranking: podio a la izquierda, lista paginada a la derecha.
## `cell` = la columna de la tabla, `podium_line` = la línea bajo cada uno del podio.
func _render_ranked(left: Control, right: Control, src: Array, header: String, my_name: String, cell: Callable, podium_line: Callable, empty_text: String) -> void:
	var rows: Array = src.slice(0, TOP_N)
	if rows.is_empty():
		_empty(empty_text, left)
		return
	left.add_child(Podium.build(rows.slice(0, 3), my_name, podium_line))
	var items: Array = []
	for i in range(rows.size()):
		items.append({"idx": i, "row": rows[i], "cell": cell,
			"mine": bool(rows[i].get("you", false)) or String(rows[i].get("name", "")) == my_name})
	_pager = Pager.new()
	right.add_child(_pager)
	_pager.set_header(DataTable.make_row(["#", "Jugador", "Club", header], COLS, true))
	_pager.show_items(items, 6 if _wide() else TOP_N, _build_year_row)

func _build_year_row(item: Dictionary) -> Control:
	var r: Dictionary = item["row"]
	return DataTable.make_row([
		str(int(item["idx"]) + 1), String(r.get("name", "?")), String(r.get("club_name", "?")), String((item["cell"] as Callable).call(r)),
	], COLS, false, bool(item["mine"]), Callable(), Color.TRANSPARENT, int(item["idx"]))

func _pts(v: float) -> String:
	return ("%.1f" % v).replace(".0", "")

# ---------------------------------------------------------------- once ideal

## Once ideal del año dibujado en un campo (1-4-3-3; en horizontal, de
## izquierda a derecha; en vertical, el portero abajo).
func _render_team_of_year() -> void:
	content_box.add_child(_trophy_header())
	var xi: Array = _ya.get("xi", [])
	if xi.is_empty():
		_empty("El once ideal se arma cuando ruede la temporada.")
		return
	var wide := _wide()
	var pitch := PanelContainer.new()
	var sb := Styles.card_flat(Color(0.13, 0.36, 0.2), 16)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1, 1, 1, 0.35)
	pitch.add_theme_stylebox_override("panel", sb)
	pitch.custom_minimum_size = Vector2(0, 340 if wide else 520)
	pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(pitch)
	var field := Control.new()
	field.clip_contents = true
	pitch.add_child(field)
	# Franjas del césped y líneas
	for i in 8:
		if i % 2 == 0:
			continue
		var band := ColorRect.new()
		band.color = Color(1, 1, 1, 0.035)
		if wide:
			_anchor(band, i / 8.0, 0.0, (i + 1) / 8.0, 1.0)
		else:
			_anchor(band, 0.0, i / 8.0, 1.0, (i + 1) / 8.0)
		field.add_child(band)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.3)
	if wide:
		_anchor(line, 0.5, 0.0, 0.5, 1.0)
		line.offset_right = 2
	else:
		_anchor(line, 0.0, 0.5, 1.0, 0.5)
		line.offset_bottom = 2
	field.add_child(line)
	var circle := Panel.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0, 0, 0, 0)
	cs.border_color = Color(1, 1, 1, 0.3)
	cs.set_border_width_all(2)
	cs.set_corner_radius_all(48)
	circle.add_theme_stylebox_override("panel", cs)
	_anchor(circle, 0.5, 0.5, 0.5, 0.5)
	circle.offset_left = -48
	circle.offset_right = 48
	circle.offset_top = -48
	circle.offset_bottom = 48
	field.add_child(circle)
	for s in [0, 1]:
		var box := Panel.new()
		var bs := cs.duplicate() as StyleBoxFlat
		bs.set_corner_radius_all(2)
		box.add_theme_stylebox_override("panel", bs)
		if wide:
			_anchor(box, 0.0 if s == 0 else 0.86, 0.22, 0.14 if s == 0 else 1.0, 0.78)
		else:
			_anchor(box, 0.22, 0.0 if s == 0 else 0.88, 0.78, 0.12 if s == 0 else 1.0)
		field.add_child(box)
	# Los once, por líneas
	var lines := {"GK": [], "DF": [], "MF": [], "ST": []}
	for r: Dictionary in xi:
		(lines[String(r.get("pos", "MF"))] as Array).append(r)
	var depth := {"GK": 0.1, "DF": 0.31, "MF": 0.56, "ST": 0.8}
	for pos: String in lines:
		var arr: Array = lines[pos]
		for i in arr.size():
			var across: float = (i + 1.0) / (arr.size() + 1.0)
			var d: float = float(depth[pos])
			var at := Vector2(d, across) if wide else Vector2(across, 1.0 - d)
			field.add_child(_xi_chip(arr[i], at))

func _anchor(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = l
	c.anchor_top = t
	c.anchor_right = r
	c.anchor_bottom = b
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Ficha de un jugador del once: puesto en un círculo, apellido y club.
func _xi_chip(r: Dictionary, at: Vector2) -> Control:
	var you: bool = bool(r.get("you", false))
	var holder := Control.new()
	_anchor(holder, at.x, at.y, at.x, at.y)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.custom_minimum_size = Vector2(160, 0)
	v.position = Vector2(-80, -27)
	holder.add_child(v)
	var dot := PanelContainer.new()
	var ds := StyleBoxFlat.new()
	ds.bg_color = Styles.GOLD if you else Color(0.96, 0.96, 0.96)
	ds.set_corner_radius_all(12)
	ds.border_color = Color(0, 0, 0, 0.5)
	ds.set_border_width_all(2)
	dot.add_theme_stylebox_override("panel", ds)
	dot.custom_minimum_size = Vector2(24, 24)
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pl := Label.new()
	pl.text = String(r.get("pos", ""))
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.add_theme_font_override("font", Styles.font_black())
	pl.add_theme_font_size_override("font_size", 9)
	pl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
	dot.add_child(pl)
	v.add_child(dot)
	var nm: String = String(r.get("name", "?"))
	var n := Label.new()
	n.text = ("★ " if you else "") + nm.get_slice(" ", nm.get_slice_count(" ") - 1)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.add_theme_font_override("font", Styles.font_black())
	n.add_theme_font_size_override("font_size", 13)
	n.add_theme_color_override("font_color", Styles.GOLD if you else Color.WHITE)
	n.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	n.add_theme_constant_override("outline_size", 4)
	v.add_child(n)
	var c := Label.new()
	var ga := "%d/%d" % [int(r.get("goals", 0)), int(r.get("assists", 0))]
	if String(r.get("pos", "")) == "GK":
		ga = "%d PaC" % YearAwardsEngine.clean_sheets(int(r.get("pj", 0)), int(r.get("gc", 0)))
	c.text = "%s · %s" % [String(r.get("club_name", "")), ga]
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.clip_text = true
	c.add_theme_font_size_override("font_size", 9)
	c.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85))
	c.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	c.add_theme_constant_override("outline_size", 3)
	v.add_child(c)
	return holder

# ---------------------------------------------------------------- rendimiento

## Rendimiento = ranking mundial por nota estimada de temporada. Para el
## usuario se usa su media REAL de todos los partidos jugados.
func _render_performance(left: Control, right: Control, my_name: String) -> void:
	var games: int = int(WorldTickEngine.season.get("user_rating_games", 0))
	var my_avg: float = float(WorldTickEngine.season.get("user_rating_sum", 0.0)) / float(maxi(games, 1))

	# Tarjeta con TU media real.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Styles.card_accent(_rating_color(my_avg) if games > 0 else Styles.GRAY_TEXT))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 16)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var h := Label.new()
	h.text = "TU MEDIA REAL DE LA TEMPORADA"
	h.add_theme_font_size_override("font_size", 11)
	h.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(h)
	var big := Label.new()
	big.text = ("%.2f  ·  %d partido%s" % [my_avg, games, "" if games == 1 else "s"]) if games > 0 else "Sin partidos oficiales todavía"
	big.add_theme_font_size_override("font_size", 22 if games > 0 else 15)
	if games > 0:
		big.add_theme_color_override("font_color", _rating_color(my_avg))
	v.add_child(big)
	m.add_child(v)
	card.add_child(m)
	left.add_child(card)

	# Ranking mundial por nota estimada.
	var rows: Array = []
	for r in _bd:
		var est: float = _estimated_rating(r)
		if String(r.get("name", "")) == my_name and games > 0:
			est = my_avg
		rows.append({"name": String(r.get("name", "?")), "club_name": String(r.get("club_name", "?")), "est": est})
	rows.sort_custom(func(a, b): return float(a["est"]) > float(b["est"]))
	rows = rows.slice(0, TOP_N)
	var items: Array = []
	for i in range(rows.size()):
		items.append({"idx": i, "row": rows[i], "mine": rows[i]["name"] == my_name,
			"cell": func(r): return "%.2f" % float(r["est"])})
	_pager = Pager.new()
	right.add_child(_pager)
	_pager.set_header(DataTable.make_row(["#", "Jugador", "Club", "Nota"], COLS, true))
	_pager.show_items(items, 6 if _wide() else TOP_N, _build_year_row)

## Nota estimada de temporada a partir de goles/asistencias/títulos —
## aproximación para poder comparar a todo el mundo (los jugadores IA no
## tienen nota partido a partido). El usuario usa su media real.
func _estimated_rating(r: Dictionary) -> float:
	var trophies: int = (r.get("trophies", []) as Array).size()
	return clampf(6.30 + int(r.get("goals", 0)) * 0.055 + int(r.get("assists", 0)) * 0.040 + trophies * 0.15, 4.5, 9.7)

func _rating_color(avg: float) -> Color:
	if avg >= 7.5:
		return Styles.GOLD
	if avg >= 6.8:
		return Styles.GREEN
	if avg >= 6.0:
		return Styles.AMBER
	return Styles.RED

# ---------------------------------------------------------------- vitrina

## Sin jornadas jugadas todavía: la VITRINA de los seis premios (el de la
## pestaña elegida resaltado) y cómo se ganan.
func _render_showcase() -> void:
	var grid := GridContainer.new()
	grid.columns = 3 if _wide() else 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for i in TAB_HONORS.size():
		var on: bool = i == _tab
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(190, 150)
		var sb := Styles.card_flat(Color(0.16, 0.13, 0.05) if on else Color(0.1, 0.11, 0.13), 16)
		sb.border_width_bottom = 4
		sb.border_color = Styles.GOLD if on else Color(1, 1, 1, 0.08)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 4)
		var cc := CenterContainer.new()
		var tro: Control = Trophy.for_honor(String(TAB_HONORS[i]), 52)
		if tro != null:
			cc.add_child(tro)
		v.add_child(cc)
		var t := Label.new()
		t.text = String(TAB_TITLES[i])
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_font_override("font", Styles.font_black())
		t.add_theme_font_size_override("font_size", 14)
		t.add_theme_color_override("font_color", Styles.GOLD if on else Color.WHITE)
		v.add_child(t)
		var d := Label.new()
		d.text = TAB_HOW[i]
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 11)
		d.add_theme_color_override("font_color", Color(0.78, 0.8, 0.85))
		v.add_child(d)
		card.add_child(v)
		grid.add_child(card)
	content_box.add_child(grid)
	var note := Label.new()
	note.text = "La carrera arranca con la primera jornada. Jugá tus partidos para entrar en el ranking."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	content_box.add_child(note)
