extends Control

## Premios anuales — seguimiento EN VIVO de la temporada del mundo
## (mismo principio que la Vitrina / el Balón de Oro de fin de año, pero
## consultable en cualquier momento). Cuatro pestañas, todas rankings
## MUNDIALES:
##   Balón de Oro  → WorldTickEngine.ballon_dor_ranking() tal cual (ya
##                    viene ponderado y ordenado por BallonDorEngine).
##   Bota de Oro   → el mismo pool ordenado por goles.
##   Asistidor     → el mismo pool ordenado por asistencias.
##   Rendimiento   → nota estimada de la temporada por jugador
##                    (6.3 + goles/asist/títulos), y para TI tu media
##                    real acumulada (season["user_rating_sum"/"_games"]).
## Listas PAGINADAS con ◀ ▶ (Pager) — nada de scroll táctil.
## Nada se simula ni se guarda acá: es lectura del mundo vivo.

@onready var season_label: Label = $Margin/VBox/SeasonLabel
@onready var tabs_row: HBoxContainer = $Margin/VBox/TabsRow
@onready var content_box: VBoxContainer = $Margin/VBox/Scroll/ContentBox
@onready var scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var back_button: Button = $Margin/VBox/BackButton

const TABS := ["Balón de Oro", "Bota de Oro", "Asistidor", "Rendimiento"]
## Trofeo que ilustra cada pestaña (pedido de Wilber: "muestra el premio
## en cada viñeta de los premios individuales").
const TAB_HONORS := ["ballon_dor", "bota_oro", "mvp_liga", "mvp_temporada"]
const PER_PAGE := 12
## Rankings mundiales recortados al Top 10 (pedido de Wilber: "que el
## query muestre solo los primeros 10 para aligerar la consulta y
## hacerla más rápida"). El cómputo pesado (recorrer las 55 ligas) ya
## está cacheado por día en WorldTickEngine.ballon_dor_ranking() — este
## recorte es sobre la lista ya resuelta, para que pintar la UI (la
## parte que sí se repite cada vez que se abre la pantalla) sea liviano.
const TOP_N := 10
var _tab: int = 0
var _tab_buttons: Array[Button] = []
var _bd: Array = []
var _pager: Pager = null

## true si se entra desde la ceremonia de fin de temporada (pedido de
## Wilber: "resumen → premios individuales → carga de la nueva
## temporada"). En ese caso el botón dice "Continuar" y sigue la cadena
## hacia SeasonLoading en vez de "Volver" directo al Hub.
var _flow_mode: bool = false

func _ready() -> void:
	WorldTickEngine.load_runtime()
	_flow_mode = WorldTickEngine.post_season_flow
	back_button.pressed.connect(_on_back_pressed)
	if _flow_mode:
		back_button.text = "Continuar"
		back_button.icon = Icons.load_icon(Icons.PLAY)
		Styles.styled_button(back_button, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	else:
		Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER

	var start_year: int = CalendarUtils.season_start_year(WorldTickEngine.current_epoch_day)
	season_label.text = "Temporada %d/%d" % [start_year, start_year + 1]

	var medal := Medals.rect(Medals.by_name(Medals.GOLD), 34)
	if medal != null:
		var mc := CenterContainer.new()
		mc.add_child(medal)
		$Margin/VBox.add_child(mc)
		$Margin/VBox.move_child(mc, 0)

	for i in range(TABS.size()):
		var b := Button.new()
		b.text = TABS[i]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 13)
		b.clip_text = true
		b.pressed.connect(_on_tab_pressed.bind(i))
		tabs_row.add_child(b)
		_tab_buttons.append(b)

	_refresh_tabs()
	# El ranking recorre las 55 ligas: puede tardar. Pintamos la pantalla
	# con un aviso y lo calculamos al frame siguiente para que la
	# transición no se congele (pedido de Wilber: "va muy lento al entrar").
	_empty("Calculando premios de la temporada…")
	await get_tree().process_frame
	await get_tree().process_frame
	_bd = WorldTickEngine.ballon_dor_ranking()
	# Fin de temporada: los ganadores de la temporada que TERMINÓ.
	if _flow_mode and not WorldTickEngine.final_awards.is_empty():
		_bd = WorldTickEngine.final_awards
		var y: int = WorldTickEngine.final_awards_year
		if y > 0:
			season_label.text = "Temporada %d/%d" % [y, y + 1]
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
		if i == _tab:
			Styles.tab(_tab_buttons[i], true)
		else:
			Styles.tab(_tab_buttons[i], false)

func _render() -> void:
	for c in content_box.get_children():
		c.queue_free()
	_pager = null

	content_box.add_child(_trophy_header())

	if _bd.is_empty():
		_render_showcase()
		return

	var player := SaveManager.load_player()
	var my_name: String = player.player_name if player != null else ""

	match _tab:
		3:
			_render_performance(my_name)
		2:
			_render_leaderboard("assists", "Asist.", my_name)
		1:
			_render_leaderboard("goals", "Goles", my_name)
		_:
			_render_leaderboard("score", "Pts", my_name)
	UiScroll.pad_bottom(content_box)

## Cabecera con el trofeo que representa la pestaña + su nombre.
func _trophy_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var honor: String = TAB_HONORS[_tab] if _tab < TAB_HONORS.size() else "ballon_dor"
	var tro := Trophy.for_honor(honor, 46)
	if tro != null:
		tro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tro)
	var name_lbl := Label.new()
	name_lbl.text = TABS[_tab]
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lbl.add_theme_font_override("font", Styles.font_black())
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Styles.GOLD)
	row.add_child(name_lbl)
	return row

func _empty(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	content_box.add_child(l)
	if not text.begins_with("Calculando"):
		UiKit.empty_icon(l, Icons.PX_AWARDS)

## Ordena _bd por la clave pedida y lo pagina. `score` ya viene ordenado
## (Balón de Oro); goals/assists se reordenan.
func _render_leaderboard(key: String, count_header: String, my_name: String) -> void:
	var rows: Array = _bd.duplicate()
	if key != "score":
		rows.sort_custom(func(a, b): return int(a.get(key, 0)) > int(b.get(key, 0)))
		rows = rows.filter(func(r): return int(r.get(key, 0)) > 0)
	if rows.is_empty():
		_empty("Todavía no hay %s registradas esta temporada." % count_header.to_lower())
		return
	rows = rows.slice(0, TOP_N)
	var podium: Control = Podium.build(rows.slice(0, 3), my_name,
		func(r): return "%d %s" % [int(r.get(key, 0)), count_header.to_lower()])
	content_box.add_child(podium)

	var items: Array = []
	for i in range(rows.size()):
		items.append({"idx": i, "row": rows[i], "key": key, "mine": String(rows[i].get("name", "")) == my_name})
	_pager = Pager.new()
	content_box.add_child(_pager)
	_pager.set_header(DataTable.make_row(["#", "Jugador", "Club", count_header], [34, 190, 150, 60], true))
	_pager.show_items(items, PER_PAGE, _build_lb_row)
	_land_pair(podium, _pager)

func _build_lb_row(item: Dictionary) -> Control:
	var r: Dictionary = item["row"]
	var v: int = int(r.get(item["key"], 0))
	return DataTable.make_row([
		str(int(item["idx"]) + 1), String(r.get("name", "?")), String(r.get("club_name", "?")), str(v),
	], [34, 190, 150, 60], false, bool(item["mine"]), Callable(), Color.TRANSPARENT, int(item["idx"]))

## Rendimiento = ranking mundial por nota estimada de temporada. Para el
## usuario se usa su media REAL de todos los partidos jugados (titular o
## suplente, ver MatchSummary.gd "user_played" — antes solo contaba
## partidos de titular, bug real reportado por Wilber).
func _render_performance(my_name: String) -> void:
	var games: int = int(WorldTickEngine.season.get("user_rating_games", 0))
	var my_avg: float = float(WorldTickEngine.season.get("user_rating_sum", 0.0)) / float(maxi(games, 1))

	# Tarjeta con TU media real, fija arriba.
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
	content_box.add_child(card)

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
		items.append({"idx": i, "row": rows[i], "mine": rows[i]["name"] == my_name})
	_pager = Pager.new()
	content_box.add_child(_pager)
	_pager.set_header(DataTable.make_row(["#", "Jugador", "Club", "Nota"], [34, 190, 150, 60], true))
	_pager.show_items(items, PER_PAGE, _build_perf_row)
	_land_pair(card, _pager)

func _build_perf_row(item: Dictionary) -> Control:
	var r: Dictionary = item["row"]
	return DataTable.make_row([
		str(int(item["idx"]) + 1), String(r["name"]), String(r["club_name"]), "%.2f" % float(r["est"]),
	], [34, 190, 150, 60], false, bool(item["mine"]), Callable(), Color.TRANSPARENT, int(item["idx"]))

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


## HORIZONTAL: lo destacado (podio / tu media) a la izquierda y el ranking
## completo a la derecha, a la vista los dos.
func _land_pair(left_node: Control, right_node: Control) -> void:
	if get_viewport_rect().size.x <= get_viewport_rect().size.y:
		return
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	content_box.add_child(cols)
	content_box.move_child(cols, left_node.get_index())
	var l := VBoxContainer.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_child(l)
	left_node.reparent(l)
	right_node.reparent(cols)
	right_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Sin jornadas jugadas todavía: en vez de una pantalla vacía, la VITRINA de
## los cuatro premios (el de la pestaña elegida resaltado) y cómo se ganan.
func _render_showcase() -> void:
	for c in content_box.get_children():
		if c != content_box.get_child(0):
			c.queue_free()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var how := ["El mejor jugador del mundo: goles, asistencias y títulos.",
		"El máximo goleador de todas las ligas.",
		"El que más asistencias da en la temporada.",
		"La mejor nota promedio de la temporada."]
	for i in TAB_HONORS.size():
		var on: bool = i == _tab
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(230, 230)
		var sb := Styles.card_flat(Color(0.16, 0.13, 0.05) if on else Color(0.1, 0.11, 0.13), 16)
		sb.border_width_bottom = 4
		sb.border_color = Styles.GOLD if on else Color(1, 1, 1, 0.08)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 14
		sb.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 8)
		var cc := CenterContainer.new()
		var tro: Control = Trophy.for_honor(String(TAB_HONORS[i]), 96 if on else 76)
		if tro != null:
			cc.add_child(tro)
		v.add_child(cc)
		var t := Label.new()
		t.text = String(TABS[i])
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_font_override("font", Styles.font_black())
		t.add_theme_font_size_override("font_size", 17)
		t.add_theme_color_override("font_color", Styles.GOLD if on else Color.WHITE)
		v.add_child(t)
		var d := Label.new()
		d.text = how[i] if i < how.size() else ""
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 12)
		d.add_theme_color_override("font_color", Color(0.78, 0.8, 0.85))
		v.add_child(d)
		card.add_child(v)
		row.add_child(card)
	content_box.add_child(row)
	var note := Label.new()
	note.text = "La carrera arranca con la primera jornada. Jugá tus partidos para entrar en el ranking."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	content_box.add_child(note)
