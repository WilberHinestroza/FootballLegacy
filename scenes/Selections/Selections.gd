extends Control
const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")

## Selecciones nacionales — pantalla nueva del menú hamburguesa (Fase 5 de
## selecciones: pedido explícito de Wilber, "un botón que se llame
## Selecciones y que desde ahí se vea todo"). Hace VISIBLE lo que las
## Fases 1-4 ya calculan en el motor (mundo vivo, nunca precomputado):
## tu convocatoria, tu eliminatoria al Mundial, el Mundial y la copa
## continental de tu confederación si están en curso — y te deja JUGAR tu
## partido de hoy si te tocó uno.
##
## + "Explorar selecciones" (pedido de Wilber: "que se pueda ver todo, no
## solo mi selección... dividilo por continentes, el Mundial, copa
## américa y todo... poder ver cómo avanza el mundo"): un selector de
## confederación para ver la eliminatoria/copa continental de CUALQUIERA
## de las 5, completa (no solo tu entorno), + el Mundial completo —
## mismo dato "mundo vivo" que ya corre para vos, ahora navegable como
## WorldExplorer con las copas de club.
##
## Solo lectura salvo el botón "Jugar" (ver _on_play_pressed) — nunca muta
## nada de esto por su cuenta, todo sale de WorldTickEngine.

const _TABLE_COLS := ["#", "País", "PJ", "G", "E", "P", "DG", "Pts"]
const _TABLE_WIDTHS := [24, 118, 26, 24, 24, 24, 32, 32]
const _CONTEXT_ROWS := 3 # cuántas filas arriba/abajo de tu país se muestran en tablas largas (tarjeta PERSONAL)

@onready var back_button: Button = $Root/VBox/BackButton
@onready var scroll: ScrollContainer = $Root/VBox/Scroll
@onready var content_box: VBoxContainer = $Root/VBox/Scroll/ContentBox

var _player: PlayerData = null
var _confederation: String = ""
var _explore_confederation: String = "" # confederación elegida en "Explorar selecciones" — persiste entre renders

## Detalle de un torneo completo (pedido de Wilber: "botones para ir a
## cada competición a ver cómo avanza y el campeón, goleador y
## asistidor" + "un botón del Mundial para ver enfrentamientos y
## resultados"). "" = pantalla principal; "worldcup"/"national_cup" abren
## una vista propia con pestañas Cuadro/Goleadores/Asistencias.
var _detail_kind: String = ""
var _detail_confederation: String = "" # solo si _detail_kind == "national_cup"
var _detail_tab: String = "bracket" # "bracket" | "scorers" | "assists"
var _detail_group_view: String = "table" # "table" | "fixtures" — fase de grupos del torneo abierto
const _PERF_WIDTHS := [26, 150, 110, 60]

func _ready() -> void:
	WorldTickEngine.load_runtime() # idempotente; por si se entra directo a esta escena
	_player = SaveManager.load_player()
	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn"))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_render()

func _render() -> void:
	Styles.land_columns_later(content_box, 1)  # horizontal: 2 columnas
	for c in content_box.get_children():
		c.queue_free()
	if _player == null or _player.country == "":
		content_box.add_child(_info_label("Sin jugador activo."))
		return

	_confederation = Confederations.confederation_of(_player.country)

	if _detail_kind != "":
		_render_detail()
		UiScroll.pad_bottom(content_box)
		return

	content_box.add_child(_world_banner())
	content_box.add_child(_header_card())
	if _confederation == "":
		content_box.add_child(_info_label("%s no tiene confederación asignada todavía." % _player.country))
		UiScroll.pad_bottom(content_box)
		return

	var fx: Dictionary = WorldTickEngine.pending_user_national_fixture()
	if not fx.is_empty():
		content_box.add_child(_today_card(fx))

	content_box.add_child(Styles.section_label("Eliminatoria al Mundial"))
	content_box.add_child(_qualifying_card())
	content_box.add_child(_open_detail_button("Ver eliminatoria: fixture, goleadores y asistencias", "qualifying", _confederation))

	var wc: Dictionary = WorldTickEngine.world_cup_this_cycle()
	if not wc.is_empty():
		content_box.add_child(Styles.section_label("Mundial"))
		content_box.add_child(_tournament_card(wc, wc.get("champion_country", "")))
		content_box.add_child(_open_detail_button("Ver Mundial: cuadro, goleadores y asistencias", "worldcup", ""))

	var ncup: Dictionary = WorldTickEngine.national_cup_for(_confederation)
	var ncup_name: String = CompetitionNames.national_continental(_confederation)
	content_box.add_child(Styles.section_label(ncup_name))
	if not ncup.is_empty():
		content_box.add_child(_tournament_card(ncup, ncup.get("champion_country", "")))
		content_box.add_child(_open_detail_button("Ver %s: cuadro, goleadores y asistencias" % ncup_name, "national_cup", _confederation))
	else:
		content_box.add_child(_national_cup_placeholder(_confederation))

	# --- Explorar selecciones: cualquier confederación, completa ---
	if _explore_confederation == "":
		_explore_confederation = _confederation if _confederation != "" else Confederations.ALL[0]
	content_box.add_child(Styles.section_label("Explorar selecciones"))
	content_box.add_child(_confederation_picker_row())

	content_box.add_child(Styles.section_label("Eliminatoria de %s" % String(Confederations.REGION.get(_explore_confederation, _explore_confederation))))
	content_box.add_child(_qualifying_explorer_card(_explore_confederation))
	content_box.add_child(_open_detail_button("Ver eliminatoria de %s" % String(Confederations.REGION.get(_explore_confederation, _explore_confederation)), "qualifying", _explore_confederation))

	var explore_ncup: Dictionary = WorldTickEngine.national_cup_for(_explore_confederation)
	if not explore_ncup.is_empty():
		content_box.add_child(_open_detail_button("Ver %s" % CompetitionNames.national_continental(_explore_confederation), "national_cup", _explore_confederation))
	elif _explore_confederation != _confederation:
		content_box.add_child(_national_cup_placeholder(_explore_confederation))

	UiScroll.pad_bottom(content_box)

## --- Detalle de un torneo completo: Cuadro / Goleadores / Asistencias ---

func _render_detail() -> void:
	var tournament: Dictionary
	var title: String
	if _detail_kind == "worldcup":
		tournament = WorldTickEngine.world_cup_this_cycle()
		title = "Mundial"
	elif _detail_kind == "qualifying":
		tournament = WorldTickEngine.national_qualifying_for(_detail_confederation)
		title = "Eliminatoria de %s" % String(Confederations.REGION.get(_detail_confederation, _detail_confederation))
	else:
		tournament = WorldTickEngine.national_cup_for(_detail_confederation)
		title = CompetitionNames.national_continental(_detail_confederation)

	content_box.add_child(_detail_header_row(title))

	if tournament.is_empty():
		content_box.add_child(_info_label("Todavía sin datos de este torneo."))
		return

	content_box.add_child(_detail_tabs_row())

	match _detail_tab:
		"scorers":
			var perf: Dictionary = _detail_performers()
			content_box.add_child(_performers_card(perf.get("scorers", []) as Array, "Goles"))
		"assists":
			var perf2: Dictionary = _detail_performers()
			content_box.add_child(_performers_card(perf2.get("assists", []) as Array, "Asist."))
		_:
			if _detail_kind == "qualifying":
				content_box.add_child(_qualifying_detail_card(tournament))
			else:
				content_box.add_child(_tournament_explorer_card(tournament))

func _detail_performers() -> Dictionary:
	if _detail_kind == "worldcup":
		return WorldTickEngine.top_performers_for_world_cup()
	if _detail_kind == "qualifying":
		return WorldTickEngine.top_performers_for_qualifying(_detail_confederation)
	return WorldTickEngine.top_performers_for_national_cup(_detail_confederation)

func _detail_header_row(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var back_btn := Button.new()
	back_btn.icon = Icons.load_icon(Icons.BACK)
	back_btn.add_theme_constant_override("icon_max_width", 20)
	back_btn.custom_minimum_size = Vector2(44, 44)
	Styles.styled_button(back_btn, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	back_btn.pressed.connect(_on_detail_back_pressed)
	row.add_child(back_btn)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_override("font", Styles.font_black())
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	return row

func _on_detail_back_pressed() -> void:
	_detail_kind = ""
	_detail_confederation = ""
	_detail_tab = "bracket"
	_detail_group_view = "table"
	_render()

func _detail_tabs_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var main_tab_label: String = "Tabla" if _detail_kind == "qualifying" else "Cuadro"
	for tab in [["bracket", main_tab_label], ["scorers", "Goleadores"], ["assists", "Asistencias"]]:
		var btn := Button.new()
		btn.text = String(tab[1])
		btn.clip_text = true
		btn.custom_minimum_size = Vector2(0, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if String(tab[0]) == _detail_tab:
			Styles.tab(btn, true)
		else:
			Styles.tab(btn, false)
		btn.pressed.connect(_on_detail_tab_pressed.bind(String(tab[0])))
		row.add_child(btn)
	return row

func _on_detail_tab_pressed(tab: String) -> void:
	_detail_tab = tab
	_render()

func _open_detail_button(label: String, kind: String, confed: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.clip_text = true
	btn.custom_minimum_size = Vector2(0, 44)
	Styles.styled_button(btn, Styles.pill_outlined(Styles.PURPLE), Styles.PURPLE)
	btn.pressed.connect(_on_open_detail.bind(kind, confed))
	return btn

## Cuando la copa continental de `confederation` no está en curso este
## año (la inmensa mayoría de las temporadas — cada 4 años, ver
## NationalCupEngine.BASE_YEAR/is_cup_year), antes esta pantalla no
## mostraba NADA de esa competencia — ni el nombre, ni cuándo es la
## próxima. Pedido de Wilber: "yo quiero que también se pueda ver la
## información de las copas continentales de selecciones", incluso
## fuera de su año. Muestra al menos cuándo es la próxima edición.
func _national_cup_placeholder(confederation: String) -> Label:
	var lbl := Label.new()
	var next_year: int = _next_national_cup_year(confederation)
	lbl.text = "Esta temporada no hay — próxima edición: temporada %d." % next_year
	lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _next_national_cup_year(confederation: String) -> int:
	var base: int = int(NationalCupEngine.BASE_YEAR.get(confederation, 0))
	var from_year: int = WorldTickEngine.get_season_start_year()
	if base <= 0:
		return from_year
	var year: int = base
	while year < from_year:
		year += 4
	return year

func _on_open_detail(kind: String, confed: String) -> void:
	_detail_kind = kind
	_detail_confederation = confed
	_detail_tab = "bracket"
	_detail_group_view = "table"
	_render()

## Tabla de goleadores/asistentes de un torneo (WorldTickEngine.
## top_performers_for_world_cup/top_performers_for_national_cup) — mismo
## patrón que WorldExplorer._render_performers, adaptado a país en vez de
## club (bandera en vez de escudo).
func _performers_card(rows: Array, count_label: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.PURPLE))
	var margin := _margin()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	if rows.is_empty():
		vbox.add_child(_info_label("Sin datos todavía."))
	else:
		var pager := Pager.new()
		vbox.add_child(pager)
		pager.set_header(DataTable.make_row(["#", "Jugador", "País", count_label], _PERF_WIDTHS, true))
		var items: Array = []
		for i in range(rows.size()):
			items.append({"idx": i, "row": rows[i]})
		pager.show_items(items, 12, _build_performer_row)
	margin.add_child(vbox)
	panel.add_child(margin)
	return panel

func _build_performer_row(item: Dictionary) -> Control:
	var row: Dictionary = item["row"]
	var country: String = String(row.get("club_name", ""))
	var flag: Control = CountryFlags.flag_rect(country, 16) if country != "" else null
	return DataTable.make_row([
		str(int(item["idx"]) + 1), String(row.get("name", "")), country, str(int(row.get("count", 0))),
	], _PERF_WIDTHS, false, false, Callable(), Color.TRANSPARENT, int(item["idx"]), flag)

## --- Encabezado: bandera, país, confederación, convocatoria, stats ---

## Mapamundi pixel arriba (P6, 10-oct) con tu bandera encima.
func _world_banner() -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 80 if stage_is_land() else 150)
	stage.clip_contents = true
	if ResourceLoader.exists("res://assets/scenes/world_map.png"):
		var bg := TextureRect.new()
		bg.texture = load("res://assets/scenes/world_map.png")
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.add_child(bg)
	var lbl := Label.new()
	lbl.text = "SELECCIONES DEL MUNDO"
	lbl.add_theme_font_override("font", Styles.font_black())
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.position.y = -40
	stage.add_child(lbl)
	return stage

func _header_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD))
	var margin := _margin()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var flag: TextureRect = CountryFlags.flag_rect(_player.country, 28)
	if flag != null:
		top.add_child(flag)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 1)
	var country_lbl := Label.new()
	country_lbl.text = _player.country
	country_lbl.add_theme_font_override("font", Styles.font_black())
	country_lbl.add_theme_font_size_override("font_size", 18)
	names.add_child(country_lbl)
	if _confederation != "":
		var region_lbl := Label.new()
		region_lbl.text = String(Confederations.REGION.get(_confederation, _confederation))
		region_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		region_lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		names.add_child(region_lbl)
	top.add_child(names)
	top.add_child(_status_chip())
	vbox.add_child(top)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 18)
	stats.add_child(_stat_block("Partidos", str(_player.caps)))
	stats.add_child(_stat_block("Goles", str(_player.international_goals)))
	stats.add_child(_stat_block("Asistencias", str(_player.international_assists)))
	vbox.add_child(stats)

	margin.add_child(vbox)
	panel.add_child(margin)
	return panel

func _status_chip() -> PanelContainer:
	var status: String = _player.national_team_status
	var label: String
	var accent: Color
	match status:
		"captain":
			label = "Capitán"; accent = Styles.GOLD
		"regular":
			label = "Convocado"; accent = Styles.GREEN
		"fringe":
			label = "Convocado (suplente)"; accent = Styles.BLUE
		"left_out":
			label = "No convocado"; accent = Styles.GRAY_TEXT
		_:
			label = "Sin convocatoria aún"; accent = Styles.GRAY_TEXT
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.chip())
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 5)
	m.add_theme_constant_override("margin_bottom", 5)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_color_override("font_color", accent)
	lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	m.add_child(lbl)
	panel.add_child(m)
	return panel

func _stat_block(label: String, value: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_override("font", Styles.font_semibold())
	val_lbl.add_theme_font_size_override("font_size", 16)
	v.add_child(val_lbl)
	var cap_lbl := Label.new()
	cap_lbl.text = label
	cap_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	cap_lbl.add_theme_font_size_override("font_size", 10)
	v.add_child(cap_lbl)
	return v

## --- "Tenés partido hoy" ---

func _today_card(fx: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GREEN))
	var margin := _margin()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Tenés partido de selección hoy"
	title.add_theme_font_override("font", Styles.font_semibold())
	vbox.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var home: String = _player.country if bool(fx.get("is_home", true)) else String(fx.get("opponent", ""))
	var away: String = String(fx.get("opponent", "")) if bool(fx.get("is_home", true)) else _player.country
	var vs_lbl := Label.new()
	vs_lbl.text = "%s vs %s" % [home, away]
	vs_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(vs_lbl)
	vbox.add_child(row)

	var play_btn := Button.new()
	play_btn.text = "Jugar"
	play_btn.custom_minimum_size = Vector2(0, 48)
	Styles.styled_button(play_btn, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	play_btn.pressed.connect(_on_play_pressed.bind(fx))
	vbox.add_child(play_btn)

	margin.add_child(vbox)
	panel.add_child(margin)
	return panel

func _on_play_pressed(fx: Dictionary) -> void:
	var season_start: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
	var user_start_chance: float = float(fx.get("user_start_chance", 0.0))
	var prep: Dictionary = NationalTeamMatchLauncher.prepare(
		WorldTickEngine.world, WorldTickEngine.world_seed, season_start, _player,
		_player.country, String(fx.get("opponent", "")), bool(fx.get("is_home", true)),
		user_start_chance, "res://scenes/Selections/Selections.tscn", false,
		String(fx.get("competition", "qualifying")), bool(fx.get("is_knockout", false)), String(fx.get("key", "")))
	if not bool(prep.get("ok", false)):
		return
	# 6-nov: la selección también se juega en 3D (antes iba siempre al clásico).
	if Match3DBridge.supported():
		get_tree().change_scene_to_file("res://scenes/Match3D/Match3D.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/Match/Match.tscn")

## --- Eliminatoria al Mundial ---

func _qualifying_card() -> PanelContainer:
	var resolved: Dictionary = WorldTickEngine.national_qualifying_for(_confederation)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.BLUE))
	var margin := _margin()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	if resolved.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Todavía sin datos de eliminatoria."
		vbox.add_child(empty_lbl)
		margin.add_child(vbox)
		panel.add_child(margin)
		return panel

	vbox.add_child(_qualifying_status_label(resolved))

	var format: String = String(resolved.get("format", ""))
	if format == "table":
		vbox.add_child(_context_table(resolved.get("table", []) as Array))
	else:
		var my_group: Dictionary = {}
		for g in resolved.get("groups", []) as Array:
			for row in g.get("standings", []) as Array:
				if String(row.get("club_id", "")) == _player.country:
					my_group = g
					break
			if not my_group.is_empty():
				break
		if my_group.is_empty():
			var no_group_lbl := Label.new()
			no_group_lbl.text = "%s no entró al campo de esta eliminatoria." % _player.country
			no_group_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
			vbox.add_child(no_group_lbl)
		else:
			var group_lbl := Label.new()
			group_lbl.text = String(my_group.get("name", "Grupo"))
			group_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
			group_lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
			vbox.add_child(group_lbl)
			vbox.add_child(_full_table(my_group.get("standings", []) as Array))

	margin.add_child(vbox)
	panel.add_child(margin)
	return panel

func _qualifying_status_label(resolved: Dictionary) -> Label:
	var lbl := Label.new()
	var direct: Array = resolved.get("direct", [])
	var playoff: Array = resolved.get("playoff_pool", [])
	if direct.has(_player.country):
		lbl.text = "Clasificado directo al Mundial"
		lbl.add_theme_color_override("font_color", Styles.GREEN)
	elif playoff.has(_player.country):
		lbl.text = "En zona de repechaje"
		lbl.add_theme_color_override("font_color", Styles.GOLD)
	else:
		lbl.text = "Fuera de zona de clasificación"
		lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	lbl.add_theme_font_override("font", Styles.font_semibold())
	return lbl

## Tabla completa (para grupos chicos, tipo un grupo de 4-6 países).
func _full_table(table: Array) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(DataTable.make_row(_TABLE_COLS, _TABLE_WIDTHS, true))
	for row in table:
		box.add_child(_table_row(row))
	return box

## Tabla larga (CONMEBOL/CONCACAF, hasta 25 países): solo el entorno de TU
## posición, para no forzar a pintar/scrollear una tabla entera de 55.
func _context_table(table: Array) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(DataTable.make_row(_TABLE_COLS, _TABLE_WIDTHS, true))
	var my_idx: int = -1
	for i in range(table.size()):
		if String(table[i].get("club_id", "")) == _player.country:
			my_idx = i
			break
	var lo: int = 0
	var hi: int = mini(table.size(), 6) # sin tu país: primeros 6 igual
	if my_idx >= 0:
		lo = maxi(0, my_idx - _CONTEXT_ROWS)
		hi = mini(table.size(), my_idx + _CONTEXT_ROWS + 1)
	for i in range(lo, hi):
		box.add_child(_table_row(table[i]))
	return box

func _table_row(row: Dictionary) -> Control:
	var country: String = String(row.get("club_id", ""))
	var is_mine: bool = country == _player.country
	var dg: int = int(row.get("dg", int(row.get("gf", 0)) - int(row.get("gc", 0))))
	return DataTable.make_row([
		str(row.get("pos", "")), country, str(row.get("pj", 0)), str(row.get("g", 0)),
		str(row.get("e", 0)), str(row.get("p", 0)), "%+d" % dg, str(row.get("pts", 0)),
	], _TABLE_WIDTHS, false, is_mine, Callable(), Color.TRANSPARENT, -1, CountryFlags.flag_rect(country, 16))

## --- Mundial / copa continental: estado + grupo si corresponde ---

func _tournament_card(tournament: Dictionary, champion: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.PURPLE))
	var margin := _margin()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var my_group: Dictionary = {}
	for g in tournament.get("groups", []) as Array:
		for row in g.get("standings", []) as Array:
			if String(row.get("club_id", "")) == _player.country:
				my_group = g
				break
		if not my_group.is_empty():
			break

	if champion != "":
		var champ_lbl := Label.new()
		champ_lbl.text = "Campeón: %s" % champion
		champ_lbl.add_theme_font_override("font", Styles.font_semibold())
		champ_lbl.add_theme_color_override("font_color", Styles.GOLD)
		vbox.add_child(champ_lbl)
	elif my_group.is_empty():
		var out_lbl := Label.new()
		out_lbl.text = "%s no está en este torneo." % _player.country
		out_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		vbox.add_child(out_lbl)
	else:
		var status_lbl := Label.new()
		var rounds: Array = tournament.get("rounds", [])
		if rounds.is_empty():
			status_lbl.text = "En fase de grupos"
		else:
			status_lbl.text = _knockout_status(tournament, rounds)
		status_lbl.add_theme_font_override("font", Styles.font_semibold())
		vbox.add_child(status_lbl)
		var group_lbl := Label.new()
		group_lbl.text = String(my_group.get("name", "Grupo"))
		group_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		group_lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		vbox.add_child(group_lbl)
		vbox.add_child(_full_table(my_group.get("standings", []) as Array))

	margin.add_child(vbox)
	panel.add_child(margin)
	return panel

## Última ronda en la que aparece el país del usuario, decidida o no —
## "Eliminado en <ronda>" si perdió, "Sigue en <ronda>" si sigue vivo.
func _knockout_status(tournament: Dictionary, rounds: Array) -> String:
	for i in range(rounds.size() - 1, -1, -1):
		var rnd: Dictionary = rounds[i]
		for m in rnd.get("matches", []) as Array:
			var home: String = String(m.get("home_club_id", ""))
			var away: String = String(m.get("away_club_id", ""))
			if home != _player.country and away != _player.country:
				continue
			var round_name: String = String(rnd.get("round_name", "eliminatoria"))
			if not bool(rnd.get("decided", false)):
				return "Jugando %s" % round_name
			var winner: String = String(m.get("winner_club_id", ""))
			if winner == _player.country:
				var is_final: bool = round_name == "Final"
				return "Campeón" if is_final else "Avanzó de %s" % round_name
			return "Eliminado en %s" % round_name
	return "En fase de grupos"

## --- Explorar selecciones: cualquier confederación / el Mundial completo ---

func _confederation_picker_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for conf in Confederations.ALL:
		var btn := Button.new()
		btn.text = String(Confederations.REGION.get(conf, conf))
		btn.clip_text = true
		btn.custom_minimum_size = Vector2(0, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if conf == _explore_confederation:
			Styles.tab(btn, true, true)
		else:
			Styles.tab(btn, false, true)
		btn.pressed.connect(_on_pick_confederation.bind(conf))
		row.add_child(btn)
	return row

func _on_pick_confederation(conf: String) -> void:
	_explore_confederation = conf
	_render()

## Eliminatoria COMPLETA de `confederation` (no recortada a tu entorno,
## a diferencia de _qualifying_card): tabla entera paginada (formato
## "table") o TODOS los grupos, uno por hoja (formato "groups").
func _qualifying_explorer_card(confederation: String) -> PanelContainer:
	var resolved: Dictionary = WorldTickEngine.national_qualifying_for(confederation)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.BLUE))
	var margin := _margin()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	if resolved.is_empty():
		vbox.add_child(_info_label("Todavía sin datos de eliminatoria."))
		margin.add_child(vbox)
		panel.add_child(margin)
		return panel

	var direct: Array = resolved.get("direct", [])
	var playoff: Array = resolved.get("playoff_pool", [])
	var eliminated: Array = resolved.get("eliminated", [])
	var summary := Label.new()
	summary.text = "Directo: %d  ·  Repechaje: %d  ·  Eliminados: %d" % [direct.size(), playoff.size(), eliminated.size()]
	summary.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	summary.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	vbox.add_child(summary)

	if String(resolved.get("format", "")) == "table":
		var pager := Pager.new()
		vbox.add_child(pager)
		pager.set_header(DataTable.make_row(_TABLE_COLS, _TABLE_WIDTHS, true))
		pager.show_items(resolved.get("table", []) as Array, 10, _table_row)
	else:
		var groups: Array = resolved.get("groups", []) as Array
		var labels := PackedStringArray()
		for g in groups:
			labels.append(String(g.get("name", "Grupo")))
		var pager2 := Pager.new()
		vbox.add_child(pager2)
		pager2.show_items(groups, 1, _explorer_group_card, false, labels)

	margin.add_child(vbox)
	panel.add_child(margin)
	return panel

## Versión RICA de _qualifying_explorer_card, para la vista de detalle
## (pedido de Wilber: "agrega el botón de ver fixture, goleador y
## asistencias... de la eliminatoria de cada confederación") — mismo
## toggle Tabla/Fixtures que ya usa _tournament_explorer_card para el
## Mundial/copas, aplicado acá a la eliminatoria (que nunca tiene
## "rounds" de eliminación directa — solo tabla única o grupos, por eso
## es una función propia en vez de sumar más ramas a
## _tournament_explorer_card).
func _qualifying_detail_card(resolved: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.BLUE))
	var margin := _margin()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	if resolved.is_empty():
		vbox.add_child(_info_label("Todavía sin datos de eliminatoria."))
		margin.add_child(vbox)
		panel.add_child(margin)
		return panel

	var direct: Array = resolved.get("direct", [])
	var playoff: Array = resolved.get("playoff_pool", [])
	var eliminated: Array = resolved.get("eliminated", [])
	var summary := Label.new()
	summary.text = "Directo: %d  ·  Repechaje: %d  ·  Eliminados: %d" % [direct.size(), playoff.size(), eliminated.size()]
	summary.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	summary.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	vbox.add_child(summary)

	vbox.add_child(_group_phase_toggle_row())
	if _detail_group_view == "fixtures":
		vbox.add_child(_qualifying_fixtures_view(resolved))
	elif String(resolved.get("format", "")) == "table":
		var pager := Pager.new()
		vbox.add_child(pager)
		pager.set_header(DataTable.make_row(_TABLE_COLS, _TABLE_WIDTHS, true))
		pager.show_items(resolved.get("table", []) as Array, 10, _table_row)
	else:
		var groups: Array = resolved.get("groups", []) as Array
		var labels := PackedStringArray()
		for g in groups:
			labels.append(String(g.get("name", "Grupo")))
		var pager2 := Pager.new()
		vbox.add_child(pager2)
		pager2.show_items(groups, 1, _explorer_group_card, false, labels)

	margin.add_child(vbox)
	panel.add_child(margin)
	return panel

## Fixtures de la eliminatoria — formato "grupos" reusa
## _explorer_group_fixtures_card tal cual (misma pinta que Mundial/
## copas); formato "tabla única" (CONMEBOL/CONCACAF) pagina por JORNADA
## en vez de por grupo, ya que acá no hay grupos — un ida-y-vuelta entre
## 10 países son 90 partidos, impagable sin agrupar.
func _qualifying_fixtures_view(resolved: Dictionary) -> Control:
	if String(resolved.get("format", "")) != "table":
		var groups: Array = resolved.get("groups", []) as Array
		var labels2 := PackedStringArray()
		for g in groups:
			labels2.append(String(g.get("name", "Grupo")))
		var pager2 := Pager.new()
		pager2.show_items(groups, 1, _explorer_group_fixtures_card, false, labels2)
		return pager2

	var by_round: Dictionary = {}
	for fx in resolved.get("fixtures", []) as Array:
		var r: int = int(fx.get("round", 0))
		if not by_round.has(r):
			by_round[r] = []
		(by_round[r] as Array).append(fx)
	var round_keys: Array = by_round.keys()
	round_keys.sort()
	var rounds_arr: Array = []
	var labels := PackedStringArray()
	for rk in round_keys:
		rounds_arr.append(by_round[rk])
		labels.append("Jornada %d" % (int(rk) + 1))
	var pager := Pager.new()
	pager.show_items(rounds_arr, 1, _qualifying_round_page, false, labels)
	return pager

func _qualifying_round_page(fixtures: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	if not fixtures.is_empty():
		var round_num: int = int(fixtures[0].get("round", 0))
		var date_txt: String = _short_date(int(fixtures[0].get("epoch_day", 0)))
		var hdr := Label.new()
		hdr.text = "Jornada %d · %s" % [round_num + 1, date_txt] if date_txt != "" else "Jornada %d" % (round_num + 1)
		hdr.add_theme_font_override("font", Styles.font_semibold())
		box.add_child(hdr)
	for fx in fixtures:
		box.add_child(_national_match_row({
			"home_club_id": String(fx.get("home", "")), "away_club_id": String(fx.get("away", "")),
			"result": fx.get("result", null),
		}))
	return box

## Una página de "un grupo" — nombre + tabla completa de sus 4 países.
func _explorer_group_card(group: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = String(group.get("name", "Grupo"))
	lbl.add_theme_font_override("font", Styles.font_semibold())
	box.add_child(lbl)
	box.add_child(_full_table(group.get("standings", []) as Array))
	return box

## Mundial o copa continental, COMPLETO (todos los grupos o todas las
## rondas del cuadro, no solo tu país) — mismo dict shape que
## world_cup_this_cycle()/national_cup_for(): groups/rounds/champion_country.
## Pedido de Wilber: "agregales sus fixtures y sus brackets" — mismo
## patrón que WorldExplorer._render_continental_cup con clubes: un toggle
## Tabla/Fixtures para la fase de grupos, y el CUADRO de eliminación
## SIEMPRE debajo si ya existe (antes uno tapaba al otro: en cuanto
## arrancaba el cuadro final, los grupos ya jugados desaparecían del
## todo).
func _tournament_explorer_card(tournament: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.PURPLE))
	var margin := _margin()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var champion: String = String(tournament.get("champion_country", ""))
	if champion != "":
		var champ_lbl := Label.new()
		champ_lbl.text = "Campeón: %s" % champion
		champ_lbl.add_theme_font_override("font", Styles.font_semibold())
		champ_lbl.add_theme_color_override("font_color", Styles.GOLD)
		vbox.add_child(champ_lbl)

	var groups: Array = tournament.get("groups", []) as Array
	if not groups.is_empty():
		vbox.add_child(_group_phase_toggle_row())
		var labels := PackedStringArray()
		for g in groups:
			labels.append(String(g.get("name", "Grupo")))
		var pager := Pager.new()
		vbox.add_child(pager)
		if _detail_group_view == "fixtures":
			pager.show_items(groups, 1, _explorer_group_fixtures_card, false, labels)
		else:
			pager.show_items(groups, 1, _explorer_group_card, false, labels)

	# Cuadro de eliminación: UNA ronda por página (pedido de Wilber: "en
	# el menú de mundial no hay scroll para ver lo que sigue en el
	# fixture ya en los brackets" — un Mundial de 32 tiene dieciseisavos
	# de 16 partidos + 4 rondas más, 31 filas apiladas sin paginar en un
	# solo cuadro). Mismo patrón Pager que ya usa la fase de grupos acá
	# arriba — navegación con ◀ ▶ en vez de depender del arrastre
	# táctil del ScrollContainer exterior.
	var rounds: Array = tournament.get("rounds", []) as Array
	if not rounds.is_empty():
		if not groups.is_empty():
			vbox.add_child(HSeparator.new())
			vbox.add_child(Styles.section_label("Eliminatoria"))
		var round_labels := PackedStringArray()
		for rnd in rounds:
			round_labels.append(String(rnd.get("round_name", "Ronda")))
		var round_pager := Pager.new()
		vbox.add_child(round_pager)
		round_pager.show_items(rounds, 1, _round_block, false, round_labels)

	margin.add_child(vbox)
	panel.add_child(margin)
	return panel

func _group_phase_toggle_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for pair in [["table", "Tabla"], ["fixtures", "Fixtures"]]:
		var b := Button.new()
		b.text = String(pair[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 36)
		var on: bool = _detail_group_view == String(pair[0])
		Styles.tab(b, on, true)
		b.pressed.connect(_on_group_view_pressed.bind(String(pair[0])))
		row.add_child(b)
	return row

func _on_group_view_pressed(view: String) -> void:
	_detail_group_view = view
	_render()

## Una página de "un grupo" en modo FIXTURES — sus partidos jornada a
## jornada, con resultado si ya se jugó (mismo campo "result" que
## WorldCupEngine._standings()/ContinentalEngine.group_standings() ya
## dejan escrito en cada fixture al calcular la tabla — no se recalcula
## nada aparte, ninguna fórmula nueva). Reusa _national_match_row (la
## misma fila que ya pinta el cuadro de eliminación) normalizando las 2
## formas de nombrar local/visitante que usan WorldCupEngine ("home"/
## "away") y ContinentalEngine ("home_club_id"/"away_club_id").
func _explorer_group_fixtures_card(group: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = String(group.get("name", "Grupo"))
	lbl.add_theme_font_override("font", Styles.font_semibold())
	box.add_child(lbl)

	var fixtures: Array = (group.get("fixtures", []) as Array).duplicate()
	fixtures.sort_custom(func(a, b): return int(a.get("matchday", 0)) < int(b.get("matchday", 0)))
	var last_md: int = -1
	for fx in fixtures:
		var md: int = int(fx.get("matchday", 0))
		if md != last_md:
			var md_lbl := Label.new()
			var date_txt: String = _short_date(int(fx.get("epoch_day", 0)))
			md_lbl.text = "Jornada %d · %s" % [md, date_txt] if date_txt != "" else "Jornada %d" % md
			md_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
			md_lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
			box.add_child(md_lbl)
			last_md = md
		var home: String = String(fx.get("home", fx.get("home_club_id", "")))
		var away: String = String(fx.get("away", fx.get("away_club_id", "")))
		box.add_child(_national_match_row({"home_club_id": home, "away_club_id": away, "result": fx.get("result", null)}))
	return box

func _round_block(rnd: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var header := Label.new()
	var round_name: String = String(rnd.get("round_name", "Ronda"))
	if not bool(rnd.get("decided", false)):
		round_name = "%s (pendiente)" % round_name
	var date_txt: String = _short_date(int(rnd.get("epoch_day", 0)))
	header.text = "%s · %s" % [round_name, date_txt] if date_txt != "" else round_name
	header.add_theme_font_override("font", Styles.font_semibold())
	header.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	box.add_child(header)
	for m in rnd.get("matches", []) as Array:
		box.add_child(_national_match_row(m))
	return box

## "13 sep" — mismo formato corto que WorldExplorer._short_date (calendario
## de copas de club), reusado acá para fechas de partido de selección.
const _MES_ABBR := ["", "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]

func _short_date(epoch_day: int) -> String:
	if epoch_day <= 0:
		return ""
	var d: Dictionary = CalendarUtils.epoch_day_to_date(epoch_day)
	return "%d %s" % [int(d.get("day", 0)), _MES_ABBR[clampi(int(d.get("month", 1)), 1, 12)]]

## Fila compacta de un cruce del cuadro final: bandera · país · marcador
## (o "vs" si no se jugó) · país · bandera.
func _national_match_row(m: Dictionary) -> Control:
	var home: String = String(m.get("home_club_id", ""))
	var away: String = String(m.get("away_club_id", ""))
	var result: Variant = m.get("result", null)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var hf: TextureRect = CountryFlags.flag_rect(home, 14) if home != "" else null
	if hf != null:
		row.add_child(hf)
	var home_lbl := Label.new()
	home_lbl.text = home
	home_lbl.clip_text = true
	home_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(home_lbl)

	var score_lbl := Label.new()
	score_lbl.custom_minimum_size = Vector2(64, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if result != null and (result as Array).size() == 2:
		score_lbl.text = "%d-%d" % [int(result[0]), int(result[1])]
		# Cruce de mata-mata definido por penales (SeasonEngine.resolve_cup
		# deja "pens":[ph,pa] en el partido) — pedido de Wilber: mostrar
		# también el resultado de la tanda, no solo el marcador del 90'.
		var pens: Array = m.get("pens", []) as Array
		if pens.size() == 2:
			score_lbl.text += "\n(%d-%d pen.)" % [int(pens[0]), int(pens[1])]
			score_lbl.add_theme_font_size_override("font_size", 11)
	else:
		score_lbl.text = "vs"
		score_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	row.add_child(score_lbl)

	var away_lbl := Label.new()
	away_lbl.text = away
	away_lbl.clip_text = true
	away_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	away_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(away_lbl)
	var af: TextureRect = CountryFlags.flag_rect(away, 14) if away != "" else null
	if af != null:
		row.add_child(af)
	return row

## --- helpers de layout ---

func _margin() -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_bottom", 12)
	return m

func _info_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


func stage_is_land() -> bool:
	return get_viewport_rect().size.x > get_viewport_rect().size.y
