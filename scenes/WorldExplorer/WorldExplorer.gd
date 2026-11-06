extends Control

## Explorar el mundo: liga/copa de CUALQUIERA de las ligas del mundo, o el
## torneo de una confederación (clubes cruzando varias ligas de la misma
## confederación — ver Confederations.gd/ContinentalEngine.gd). Mismo
## principio de "mundo vivo" en los dos casos: nada se simula ni se
## guarda aquí, es una vista de solo lectura.
##
## Nacional: país -> liga elegida -> dos SECCIONES propias, Liga (tabla,
## goleadores, asistentes, playoff si aplica) y Copa (cuadro, goleadores,
## asistentes) — cada competición con su propia información, nunca
## mezcladas en una sola lista de pestañas.
## Continental: continente -> torneos de ESE continente (antes era una
## lista plana con las 11 competiciones mezcladas).

@onready var picker_panel: VBoxContainer = $Root/Margin/VBox/PickerPanel
@onready var leagues_mode_button: Button = $Root/Margin/VBox/PickerPanel/ModeRow/LeaguesModeButton
@onready var continental_mode_button: Button = $Root/Margin/VBox/PickerPanel/ModeRow/ContinentalModeButton
@onready var ranking_mode_button: Button = $Root/Margin/VBox/PickerPanel/ModeRow/RankingModeButton
@onready var picker_label: Label = $Root/Margin/VBox/PickerPanel/PickerLabel
@onready var tier_back_button: Button = $Root/Margin/VBox/PickerPanel/TierBackButton
@onready var picker_scroll: ScrollContainer = $Root/Margin/VBox/PickerPanel/Scroll
@onready var league_list_box: VBoxContainer = $Root/Margin/VBox/PickerPanel/Scroll/LeagueListBox
@onready var detail_panel: VBoxContainer = $Root/Margin/VBox/DetailPanel
@onready var league_name_label: Label = $Root/Margin/VBox/DetailPanel/LeagueNameLabel
@onready var section_row: HBoxContainer = $Root/Margin/VBox/DetailPanel/SectionRow
@onready var league_section_button: Button = $Root/Margin/VBox/DetailPanel/SectionRow/LeagueSectionButton
@onready var cup_section_button: Button = $Root/Margin/VBox/DetailPanel/SectionRow/CupSectionButton
@onready var league_tabs_row: HBoxContainer = $Root/Margin/VBox/DetailPanel/LeagueTabsRow
@onready var table_tab_button: Button = $Root/Margin/VBox/DetailPanel/LeagueTabsRow/TableTabButton
@onready var scorers_tab_button: Button = $Root/Margin/VBox/DetailPanel/LeagueTabsRow/ScorersTabButton
@onready var assists_tab_button: Button = $Root/Margin/VBox/DetailPanel/LeagueTabsRow/AssistsTabButton
@onready var playoff_tab_button: Button = $Root/Margin/VBox/DetailPanel/LeagueTabsRow/PlayoffTabButton
@onready var discipline_tab_button: Button = $Root/Margin/VBox/DetailPanel/LeagueTabsRow/DisciplineTabButton
@onready var cup_tabs_row: HBoxContainer = $Root/Margin/VBox/DetailPanel/CupTabsRow
@onready var cup_bracket_tab_button: Button = $Root/Margin/VBox/DetailPanel/CupTabsRow/CupBracketTabButton
@onready var cup_scorers_tab_button: Button = $Root/Margin/VBox/DetailPanel/CupTabsRow/CupScorersTabButton
@onready var cup_assists_tab_button: Button = $Root/Margin/VBox/DetailPanel/CupTabsRow/CupAssistsTabButton
@onready var detail_scroll: ScrollContainer = $Root/Margin/VBox/DetailPanel/Scroll
@onready var detail_box: VBoxContainer = $Root/Margin/VBox/DetailPanel/Scroll/DetailBox
@onready var change_league_button: Button = $Root/Margin/VBox/DetailPanel/ChangeLeagueButton
@onready var back_button: Button = $Root/Margin/VBox/BackButton

@onready var roster_overlay: ColorRect = $RosterOverlay
@onready var roster_title_label: Label = $RosterOverlay/Margin/VBox/RosterTitleLabel
@onready var roster_list_box: VBoxContainer = $RosterOverlay/Margin/VBox/Scroll/RosterListBox
@onready var roster_back_button: Button = $RosterOverlay/Margin/VBox/RosterBackButton
@onready var player_card_overlay: ColorRect = $PlayerCardOverlay
@onready var player_card_box: VBoxContainer = $PlayerCardOverlay/Margin/VBox/Scroll/PlayerCardBox
@onready var player_card_back_button: Button = $PlayerCardOverlay/Margin/VBox/PlayerCardBackButton

var _picker_mode: String = "leagues" # "leagues" | "continental" | "ranking"
var _national_stage: String = "country" # "country" | "division"
var _continental_stage: String = "confederation" # "confederation" | "tier"
var _selected_country: String = ""
var _selected_league: LeagueData = null
var _table_size: int = 0
var _picker_entry: String = "single" # "single" | "division" | "country_cup" — cómo se llegó a _selected_league
var _selected_confederation: String = ""
var _selected_tier: int = 1
var _section: String = "league" # "league" | "cup" — solo aplica a _selected_league
var _league_tab: String = "table" # "table" | "scorers" | "assists" | "playoffs"
var _league_home_view: String = "table" # dentro de "table": "table" | "fixtures"
var _fixtures_page: int = -1 # jornada visible en el calendario; -1 = auto (próxima)
var _fixtures_league_id: int = -999 # liga cuyo _fixtures_page está cacheado
var _cup_tab: String = "bracket" # "bracket" | "scorers" | "assists"
var _group_page: int = 0 # qué grupo se muestra en un torneo continental de grupos
var _cont_view: String = "table" # torneo continental: "table" | "fixtures"
var _cont_fx_page: int = -1 # jornada visible en el calendario continental; -1 = auto
var _comp_header_row: HBoxContainer = null # logo + nombre de la competición (se arma en runtime)

func _ready() -> void:
	WorldTickEngine.load_runtime() # idempotente; por si se entra directo a esta escena
	_land_detail_layout()
	# Bug visual real (auditoría ronda 3): el scroll de la ficha de jugador
	# (overlay compartido con Squad/PlayerSearch) no tenía el deadzone
	# táctil — los otros 4 scrolls de esta pantalla ya lo tienen vía
	# pad_bottom(), pero ninguno de ellos es ancestro de éste.
	UiScroll.make_touch($PlayerCardOverlay/Margin/VBox/Scroll)
	# El picker es una lista puramente vertical (botones full-width o el
	# ranking paginado): sin scroll horizontal, así nada se corta a la
	# izquierda ("la pantalla de ranking hace todo más grande").
	picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	picker_scroll.add_to_group("vlist")
	# El texto largo del PickerLabel (sobre todo el del ranking) NO envolvía
	# → forzaba el ancho mínimo de toda la columna por encima de la pantalla
	# y, con grow_horizontal=BOTH, el sobrante se centraba y recortaba TODO
	# por la izquierda. Envolver + fijar la dirección de crecimiento a END
	# lo mantiene dentro de la pantalla.
	picker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	picker_label.custom_minimum_size = Vector2.ZERO
	($Root as Control).grow_horizontal = Control.GROW_DIRECTION_END
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	back_button.pressed.connect(_on_back_pressed)
	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	change_league_button.pressed.connect(_on_change_league_pressed)
	table_tab_button.pressed.connect(_on_league_tab_pressed.bind("table"))
	scorers_tab_button.pressed.connect(_on_league_tab_pressed.bind("scorers"))
	assists_tab_button.pressed.connect(_on_league_tab_pressed.bind("assists"))
	playoff_tab_button.pressed.connect(_on_league_tab_pressed.bind("playoffs"))
	discipline_tab_button.pressed.connect(_on_league_tab_pressed.bind("discipline"))
	cup_bracket_tab_button.pressed.connect(_on_cup_tab_pressed.bind("bracket"))
	cup_scorers_tab_button.pressed.connect(_on_cup_tab_pressed.bind("scorers"))
	cup_assists_tab_button.pressed.connect(_on_cup_tab_pressed.bind("assists"))
	league_section_button.pressed.connect(_on_section_pressed.bind("league"))
	cup_section_button.pressed.connect(_on_section_pressed.bind("cup"))
	tier_back_button.pressed.connect(_on_tier_back_pressed)
	leagues_mode_button.pressed.connect(_on_leagues_mode_pressed)
	continental_mode_button.pressed.connect(_on_continental_mode_pressed)
	ranking_mode_button.pressed.connect(_on_ranking_mode_pressed)
	roster_back_button.pressed.connect(_on_roster_back_pressed)
	player_card_back_button.pressed.connect(_on_player_card_back_pressed)
	Styles.styled_button(roster_back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	Styles.styled_button(player_card_back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	_refresh_mode_buttons()
	_render_picker()
	_show_picker()

func _refresh_mode_buttons() -> void:
	var buttons: Array = [leagues_mode_button, continental_mode_button, ranking_mode_button]
	var active: Button
	match _picker_mode:
		"leagues":
			active = leagues_mode_button
		"continental":
			active = continental_mode_button
		_:
			active = ranking_mode_button
	for b in buttons:
		if b == active:
			Styles.tab(b, true)
		else:
			Styles.tab(b, false)
	_refresh_picker_label()

func _refresh_picker_label() -> void:
	if _picker_mode == "leagues":
		if _national_stage == "country":
			picker_label.text = "Elige un país:"
		else:
			picker_label.text = "Elige una división de %s:" % _selected_country
	elif _picker_mode == "continental":
		if _continental_stage == "confederation":
			picker_label.text = "Elige un continente:"
		else:
			picker_label.text = "Elige un torneo de %s:" % Confederations.REGION.get(_selected_confederation, _selected_confederation)
	else:
		picker_label.text = "Ranking de ligas por coeficiente continental. Usá ◀ ▶ para pasar de continente."

func _on_leagues_mode_pressed() -> void:
	_picker_mode = "leagues"
	_national_stage = "country"
	_refresh_mode_buttons()
	_render_picker()

func _on_continental_mode_pressed() -> void:
	_picker_mode = "continental"
	_continental_stage = "confederation"
	_refresh_mode_buttons()
	_render_picker()

func _on_ranking_mode_pressed() -> void:
	_picker_mode = "ranking"
	_refresh_mode_buttons()
	_render_picker()

func _on_tier_back_pressed() -> void:
	if _picker_mode == "leagues":
		_national_stage = "country"
	else:
		_continental_stage = "confederation"
	_refresh_picker_label()
	_render_picker()

func _sorted_leagues() -> Array:
	var leagues: Array = (WorldTickEngine.world.get("leagues", []) as Array).duplicate()
	leagues.sort_custom(func(a, b):
		if a.country == b.country:
			return a.tier < b.tier
		return a.country < b.country
	)
	return leagues

## Pinta una lista del picker (países, divisiones, continentes, tiers) con
## paginación ◀ ▶ en vez de scroll — pedido de Wilber. `specs`: Array de
## {text: String, cb: Callable}. La barra ◀ ▶ solo aparece si hay más de
## una hoja (Pager lo maneja solo).
func _paginate_picker(specs: Array) -> void:
	_picker_pager = Pager.new()
	league_list_box.add_child(_picker_pager)
	# 10/hoja (era 14) + colchón: el último país quedaba cortado a la mitad
	# (Wilber). El scroll compite con ModeRow + label + Volver + BottomNav.
	if get_viewport_rect().size.x > get_viewport_rect().size.y:
		# HORIZONTAL: mosaico de 3 por fila (9 por hoja, entra sin scroll).
		var rows: Array = []
		for i in range(0, specs.size(), 3):
			rows.append(specs.slice(i, i + 3))
		_picker_pager.show_items(rows, 3, _picker_row3)
	else:
		_picker_pager.show_items(specs, 8, _picker_card)
	UiScroll.pad_bottom(league_list_box, 64)

func _picker_row3(chunk: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for spec in chunk:
		var c: Control = _picker_card(spec)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.custom_minimum_size.y = 70
		row.add_child(c)
	for _i in range(chunk.size(), 3):
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
	return row

var _picker_pager: Pager = null

## Fila del selector como TARJETA (9-oct, rediseño de Torneos): bandera
## grande, título en negrita + subtítulo (lo que va después de " — "), el
## TROFEO de esa competición a la derecha y borde dorado si es la tuya.
func _picker_card(spec: Dictionary) -> Control:
	var raw: String = String(spec["text"])
	var mine: bool = raw.contains("★")
	raw = raw.replace("  ★ TU PAÍS", "").replace("  ★ TU LIGA", "").replace("  ★ TU CONFEDERACIÓN", "")
	var parts: PackedStringArray = raw.split(" — ", false, 1)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 64)
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	if mine:
		Styles.styled_button(btn, Styles.pill_outlined(Styles.GOLD), Color.WHITE)
	else:
		Styles.styled_button(btn, Styles.card_flat(Color(0.16, 0.17, 0.21), 12), Color.WHITE)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -10
	row.offset_bottom = -4
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if String(spec.get("flag", "")) != "":
		var fl: Texture2D = CountryFlags.flag(String(spec["flag"]))
		if fl != null:
			var fr := TextureRect.new()
			fr.texture = fl
			fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			fr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			fr.custom_minimum_size = Vector2(38, 28)
			fr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(fr)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := Label.new()
	t.text = parts[0]
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.add_theme_font_override("font", Styles.font_semibold())
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", Styles.GOLD if mine else Color.WHITE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	if parts.size() > 1 or mine:
		var st := Label.new()
		st.text = (parts[1] if parts.size() > 1 else "") + ("  ·  ★ la tuya" if mine else "")
		st.clip_text = true
		st.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		st.add_theme_font_size_override("font_size", 12)
		st.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(st)
	row.add_child(col)
	if String(spec.get("trophy", "")) != "":
		var tid: String = String(spec["trophy"])
		var tro: Control = Trophy.for_title(tid, 44) if (tid.begins_with("league_") or tid.begins_with("dcup_")) else Trophy.for_honor(tid, 44)
		tro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tro)
	var chev := Label.new()
	chev.text = "›"
	chev.add_theme_font_override("font", Styles.font_black())
	chev.add_theme_font_size_override("font_size", 22)
	chev.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chev)
	btn.add_child(row)
	btn.pressed.connect(spec["cb"])
	return btn

func _render_picker() -> void:
	for child in league_list_box.get_children():
		child.queue_free()
	_ranking_pager = null
	_picker_pager = null
	match _picker_mode:
		"leagues":
			if _national_stage == "country":
				tier_back_button.visible = false
				_render_country_list()
			else:
				tier_back_button.visible = true
				tier_back_button.text = "< Países"
				_render_division_list()
		"continental":
			if _continental_stage == "confederation":
				tier_back_button.visible = false
				_render_confederation_list()
			else:
				tier_back_button.visible = true
				tier_back_button.text = "< Continentes"
				_render_tier_list()
		_: # "ranking"
			tier_back_button.visible = false
			# El coeficiente recorre las 55 ligas: se pinta un aviso y se
			# calcula tras el frame para que la pestaña abra al instante
			# (queda cacheado por día).
			var loading := Label.new()
			loading.text = "Calculando ranking del mundo…"
			loading.add_theme_color_override("font_color", Styles.GRAY_TEXT)
			league_list_box.add_child(loading)
			_render_ranking_deferred.call_deferred()

func _render_ranking_deferred() -> void:
	if _picker_mode != "ranking" or not is_instance_valid(league_list_box):
		return
	for child in league_list_box.get_children():
		child.queue_free()
	_ranking_pager = null
	_render_ranking()

## Coeficiente continental por liga, agrupado por confederación — pura
## referencia (ver CoefficientEngine.gd): no elige nada, solo se lee. La
## columna "Próx. cupos" es la proyección: si HOY se cerrara la tabla en
## esa posición, a qué torneo entraría esa liga y con cuántos clubes la
## temporada que viene — "saber de antemano los cupos de cada país",
## pedido explícito.
##
## Se pinta PAGINADO con botones ◀ / ▶ (ver Pager.gd): UNA HOJA POR
## CONTINENTE (los que tienen muchas ligas se parten en varias hojas de
## RANKING_PER_PAGE) y los botones de abajo pasan de un continente a
## otro — así no hay que scrollear las 55 ligas apiladas. Pedido
## explícito de Wilber.
const RANKING_PER_PAGE := 10

func _render_ranking() -> void:
	var ranking: Dictionary = WorldTickEngine.coefficient_ranking()
	var my_league_id: int = int(WorldTickEngine.season.get("league_id", -1)) if not WorldTickEngine.season.is_empty() else -1

	# Cada "item" del Pager es una HOJA ya armada (Array de filas de datos).
	var pages: Array = []
	var page_labels: PackedStringArray = []
	for confederation in Confederations.ALL:
		var rows: Array = ranking.get(confederation, [])
		if rows.is_empty():
			continue
		var region: String = Confederations.REGION.get(confederation, confederation)
		var built: Array = []
		for i in range(rows.size()):
			var league: LeagueData = rows[i]["league"]
			var allocs: Array = rows[i]["projected_allocations"]
			var quota_txt: String = "sin cupo continental"
			if allocs.size() == 1:
				var spots: int = int(allocs[0]["spots"])
				quota_txt = "%d cupo%s · Nivel %d" % [spots, "s" if spots != 1 else "", int(allocs[0]["tier"])]
			elif allocs.size() > 1:
				var parts: Array = []
				for a in allocs:
					parts.append("Nivel %d: %d" % [int(a["tier"]), int(a["spots"])])
				quota_txt = "  ·  ".join(parts)
			built.append({
				"pos": i + 1, "league": league, "score": int(rows[i]["score"]),
				"quota": quota_txt, "mine": league.league_id == my_league_id,
			})
		var chunks: int = maxi(1, ceili(float(built.size()) / float(RANKING_PER_PAGE)))
		for c in range(chunks):
			pages.append({
				"region": region,
				"part": c + 1, "parts": chunks,
				"rows": built.slice(c * RANKING_PER_PAGE, (c + 1) * RANKING_PER_PAGE),
			})
			var lbl: String = region
			if chunks > 1:
				lbl = "%s %d/%d" % [region, c + 1, chunks]
			page_labels.append(lbl)

	if _ranking_pager == null or not is_instance_valid(_ranking_pager):
		_ranking_pager = Pager.new()
		league_list_box.add_child(_ranking_pager)
	_ranking_pager.show_items(pages, 1, _build_ranking_page, true, page_labels)
	UiScroll.pad_bottom(league_list_box, 64)

var _ranking_pager: Pager = null

## Una hoja del ranking = encabezado del continente + sus tarjetas.
func _build_ranking_page(page: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var title: String = String(page["region"])
	if int(page["parts"]) > 1:
		title += "  (%d/%d)" % [int(page["part"]), int(page["parts"])]
	box.add_child(DataTable.section_tag(title))
	for r in page["rows"]:
		box.add_child(_ranking_card(int(r["pos"]), r["league"], int(r["score"]), String(r["quota"]), bool(r["mine"])))
	return box

## Fila de ranking como TARJETA vertical (no una tabla ancha que se corta
## en el celu): puesto + "País — Liga" arriba, puntos + cupos abajo.
func _ranking_card(pos: int, league: LeagueData, score: int, quota_txt: String, is_mine: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var bg: Color = Color(0.3, 0.24, 0.05) if is_mine else (Styles.CARD_DARK_2 if pos % 2 == 0 else Styles.CARD_DARK)
	panel.add_theme_stylebox_override("panel", Styles.card(bg, 6))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 12)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 8)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var pos_lbl := Label.new()
	pos_lbl.text = "%d" % pos
	pos_lbl.custom_minimum_size = Vector2(26, 0)
	pos_lbl.add_theme_font_override("font", Styles.font_semibold())
	pos_lbl.add_theme_color_override("font_color", Styles.GOLD if pos <= 4 else Styles.GRAY_TEXT)
	var name_lbl := Label.new()
	name_lbl.text = "%s — %s" % [league.country, league.league_name]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_mine:
		name_lbl.add_theme_color_override("font_color", Styles.GOLD)
	var score_lbl := Label.new()
	score_lbl.text = "%d pts" % score
	score_lbl.add_theme_font_override("font", Styles.font_semibold())
	top.add_child(pos_lbl)
	var fr: TextureRect = CountryFlags.flag_rect(league.country, 14)
	if fr != null:
		top.add_child(fr)
	top.add_child(name_lbl)
	top.add_child(score_lbl)
	v.add_child(top)

	var quota_lbl := Label.new()
	quota_lbl.text = quota_txt
	quota_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	quota_lbl.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	quota_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # cupos multi-nivel no deben ensanchar la tarjeta
	quota_lbl.custom_minimum_size = Vector2.ZERO
	v.add_child(quota_lbl)

	m.add_child(v)
	panel.add_child(m)
	return panel

## Países con MÁS de una división (España, Inglaterra, Alemania...) salen
## como un solo renglón que lleva a la lista de sus divisiones — nunca una
## fila plana por división, eso mezclaba tiers de un mismo país como si
## fueran ligas sueltas. Un país con una sola división va directo a su
## detalle, sin paso intermedio.
func _render_country_list() -> void:
	var by_country: Dictionary = {} # country -> Array[LeagueData]
	for league in _sorted_leagues():
		if not by_country.has(league.country):
			by_country[league.country] = []
		(by_country[league.country] as Array).append(league)
	var countries: Array = by_country.keys()
	countries.sort()

	var my_league_id: int = int(WorldTickEngine.season.get("league_id", -1)) if not WorldTickEngine.season.is_empty() else -1
	var specs: Array = []
	for country in countries:
		var leagues: Array = by_country[country]
		var mine: bool = false
		for l in leagues:
			if l.league_id == my_league_id:
				mine = true
				break
		var mine_txt: String = "  ★ TU PAÍS" if mine else ""
		if leagues.size() == 1:
			var only: LeagueData = leagues[0]
			specs.append({"text": "%s — %s%s" % [country, only.league_name, mine_txt], "cb": _on_league_chosen.bind(only), "flag": country, "trophy": "league_%d" % only.league_id})
		else:
			var top: LeagueData = leagues[0]
			for l in leagues:
				if l.tier < top.tier:
					top = l
			specs.append({"text": "%s — %s y %d división%s más%s" % [country, top.league_name, leagues.size() - 1, "" if leagues.size() == 2 else "es", mine_txt], "cb": _on_country_chosen.bind(country), "flag": country, "trophy": "league_%d" % top.league_id})
	_paginate_picker(specs)

func _on_country_chosen(country: String) -> void:
	_selected_country = country
	_national_stage = "division"
	_refresh_picker_label()
	_render_picker()

## La copa doméstica es del PAÍS (todas sus divisiones la juegan — ver
## SeasonCalendar.country_club_ids), así que aquí sale como UN renglón
## aparte, no repetida dentro de cada división: repetirla sería mostrar
## la misma competición varias veces con distinto disfraz.
func _render_division_list() -> void:
	var my_league_id: int = int(WorldTickEngine.season.get("league_id", -1)) if not WorldTickEngine.season.is_empty() else -1
	var country_leagues: Array = []
	var specs: Array = []
	for league in _sorted_leagues():
		if league.country != _selected_country:
			continue
		country_leagues.append(league)
		var mine: String = "  ★ TU LIGA" if league.league_id == my_league_id else ""
		specs.append({"text": "%s — División %d%s" % [league.league_name, league.tier, mine], "cb": _on_league_chosen.bind(league), "flag": league.country, "trophy": "league_%d" % league.league_id})

	var has_cup: bool = country_leagues.any(func(l): return l.has_domestic_cup)
	if has_cup:
		specs.append({"text": "Copa de %s — todas las divisiones" % _selected_country, "cb": _on_country_cup_chosen, "flag": _selected_country, "trophy": "dcup_%s" % _selected_country})
		# Supercopa nacional acá, con los torneos del país (pedido de Wilber).
		specs.append({"text": "Supercopa de %s — campeón de liga vs. campeón de copa" % _selected_country, "cb": _on_domestic_supercup_chosen, "flag": _selected_country, "trophy": "supercopa"})
	_paginate_picker(specs)

func _on_domestic_supercup_chosen() -> void:
	var top_league: LeagueData = null
	for l in _sorted_leagues():
		if l.country == _selected_country and (top_league == null or l.tier < top_league.tier):
			top_league = l
	if top_league == null:
		return
	_selected_league = top_league
	_selected_confederation = ""
	_picker_entry = "domestic_supercup"
	_show_detail()

func _my_confederation() -> String:
	var my_league_id: int = int(WorldTickEngine.season.get("league_id", -1)) if not WorldTickEngine.season.is_empty() else -1
	if my_league_id == -1:
		return ""
	for l in WorldTickEngine.world.get("leagues", []):
		if l.league_id == my_league_id:
			return Confederations.confederation_of(l.country)
	return ""

func _render_confederation_list() -> void:
	var my_confederation: String = _my_confederation()
	var specs: Array = []
	for confederation in Confederations.ALL:
		var mine: String = "  ★ TU CONFEDERACIÓN" if confederation == my_confederation else ""
		specs.append({"text": "%s — %s%s" % [Confederations.REGION.get(confederation, confederation), confederation, mine], "cb": _on_confederation_row_chosen.bind(confederation), "trophy": "cont_%s_1" % confederation})
	_paginate_picker(specs)

func _on_confederation_row_chosen(confederation: String) -> void:
	_selected_confederation = confederation
	_continental_stage = "tier"
	_refresh_picker_label()
	_render_picker()

func _render_tier_list() -> void:
	var specs: Array = []
	for tier in range(1, Confederations.tier_count(_selected_confederation) + 1):
		specs.append({"text": Confederations.tier_name(_selected_confederation, tier), "cb": _on_confederation_chosen.bind(_selected_confederation, tier)})
	# Supercopa continental de ESTA confederación + Mundial de Clubes (una
	# opción más acá, no todo junto en otra pantalla — pedido de Wilber).
	specs.append({"text": "🏅 Supercopa de %s" % Confederations.REGION.get(_selected_confederation, _selected_confederation), "cb": _on_confederation_chosen.bind(_selected_confederation, 0)})
	specs.append({"text": "🌍 Mundial de Clubes", "cb": _on_confederation_chosen.bind(_selected_confederation, -1)})
	_paginate_picker(specs)

## Supercopa continental de _selected_confederation (derivada — SuperCupEngine).
func _render_continental_supercup() -> void:
	var year: int = WorldTickEngine.get_season_start_year()
	detail_box.add_child(DataTable.section_tag("SUPERCOPA CONTINENTAL %d/%d" % [year, year + 1]))
	var sc: Dictionary = WorldTickEngine.continental_supercup_for(_selected_confederation)
	if sc.is_empty():
		var e := Label.new()
		e.text = "El cuadro se arma cuando se conozcan los campeones continentales."
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		detail_box.add_child(e)
		return
	detail_box.add_child(_supercup_card(sc))

## Supercopa nacional del país de _selected_league (derivada).
func _render_domestic_supercup() -> void:
	var year: int = WorldTickEngine.get_season_start_year()
	detail_box.add_child(DataTable.section_tag("SUPERCOPA NACIONAL %d/%d" % [year, year + 1]))
	var sc: Dictionary = WorldTickEngine.domestic_supercup_for(_selected_league.country)
	if sc.is_empty():
		var e := Label.new()
		e.text = "Se juega entre el campeón de liga y el de copa. El cuadro se arma cuando se conozcan."
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		detail_box.add_child(e)
		return
	detail_box.add_child(_supercup_card(sc))

## Mundial de Clubes (cada 4 años). Cuadro completo si es año de edición.
func _render_cwc() -> void:
	var year: int = WorldTickEngine.get_season_start_year()
	var cwc: Dictionary = WorldTickEngine.cwc_this_season()
	if SuperCupEngine.is_cwc_year(year):
		detail_box.add_child(DataTable.section_tag("MUNDIAL DE CLUBES %d" % year))
		var hint := Label.new()
		hint.text = "Cada 4 años (2025, 2029, 2033…). 32 clubes: 8 grupos de 4, los 2 primeros a octavos."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		hint.add_theme_font_size_override("font_size", 12)
		detail_box.add_child(hint)
		if cwc.is_empty():
			var e2 := Label.new()
			e2.text = "El sorteo se arma cuando llegue la fecha del torneo."
			e2.add_theme_color_override("font_color", Styles.GRAY_TEXT)
			detail_box.add_child(e2)
		else:
			for g in cwc.get("groups", []):
				detail_box.add_child(DataTable.section_tag(String(g["name"]).to_upper()))
				DataTable.add_row(detail_box, ["#", "Club", "PJ", "DG", "Pts"], [28, 150, 34, 40, 40], true, false, Callable(), Color.TRANSPARENT, _hspace(_CREST_PX + 20))
				var st: Array = g["standings"]
				for i in range(st.size()):
					var r: Dictionary = st[i]
					var mine: bool = String(r["club_id"]) == WorldTickEngine.user_club_id
					DataTable.add_row(detail_box, [
						str(i + 1), _club_name(String(r["club_id"])),
						str(r["pj"]), "%+d" % (int(r["gf"]) - int(r["gc"])), str(r["pts"]),
					], [28, 150, 34, 40, 40], false, mine, _open_roster.bind(String(r["club_id"])), Color.TRANSPARENT, _flag_crest_lead(String(r["club_id"])))
			if not (cwc.get("rounds", []) as Array).is_empty():
				detail_box.add_child(DataTable.section_tag("ELIMINATORIA"))
				_render_bracket(cwc, "", true)
	else:
		var nxt: int = year + (4 - (year - SuperCupEngine.CWC_BASE_YEAR) % 4) % 4
		if nxt <= year:
			nxt += 4
		detail_box.add_child(DataTable.section_tag("MUNDIAL DE CLUBES"))
		var w := Label.new()
		w.text = "Próxima edición: %d (se juega cada 4 años)." % nxt
		w.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		detail_box.add_child(w)

func _supercup_card(sc: Dictionary) -> Control:
	var m: Dictionary = sc.get("match", {})
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD))
	var mg := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		mg.add_theme_constant_override("margin_" + s, 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var t := Label.new()
	t.text = String(sc.get("name", "Supercopa"))
	t.add_theme_font_override("font", Styles.font_semibold())
	v.add_child(t)
	var st := Label.new()
	st.text = String(sc.get("subtitle", ""))
	st.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	st.add_theme_font_size_override("font_size", 11)
	v.add_child(st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_mini_flag_crest(String(m.get("home", "")), 24))
	var hn := Label.new()
	hn.text = _club_name(String(m.get("home", "")))
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hn.clip_text = true
	row.add_child(hn)
	var sc_lbl := Label.new()
	var pens: Array = m.get("pens", []) if m.get("pens", []) is Array else []
	if pens.size() == 2:
		sc_lbl.text = "%d - %d\n(%d-%d pen.)" % [int(m.get("gh", 0)), int(m.get("ga", 0)), int(pens[0]), int(pens[1])]
	else:
		sc_lbl.text = "%d - %d" % [int(m.get("gh", 0)), int(m.get("ga", 0))]
	sc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sc_lbl.add_theme_font_override("font", Styles.font_semibold())
	row.add_child(sc_lbl)
	var an := Label.new()
	an.text = _club_name(String(m.get("away", "")))
	an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	an.clip_text = true
	an.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(an)
	row.add_child(_mini_flag_crest(String(m.get("away", "")), 24))
	v.add_child(row)
	var champ := Label.new()
	champ.text = "🏆 Campeón: %s" % _club_name(String(m.get("winner", "")))
	champ.add_theme_color_override("font_color", Styles.GOLD)
	champ.add_theme_font_size_override("font_size", 12)
	v.add_child(champ)
	mg.add_child(v)
	panel.add_child(mg)
	return panel

func _on_league_chosen(league: LeagueData) -> void:
	_selected_league = league
	_selected_confederation = ""
	_picker_entry = "division" if _national_stage == "division" else "single"
	_section = "league"
	_league_tab = "table"
	_league_home_view = "table"
	_fixtures_page = -1
	_cup_tab = "bracket"
	_bracket_round_page = 0
	_show_detail()

## Entrada directa a la copa compartida de un país multi-división (ver
## el renglón "Copa (País)" en _render_division_list) — usa la división
## de mayor categoría como "portadora" del league_id: a WorldTickEngine
## solo le importa el país, cualquier división de ese país sirve.
func _on_country_cup_chosen() -> void:
	var top_league: LeagueData = null
	for l in _sorted_leagues():
		if l.country == _selected_country and (top_league == null or l.tier < top_league.tier):
			top_league = l
	if top_league == null:
		return
	_selected_league = top_league
	_selected_confederation = ""
	_picker_entry = "country_cup"
	_cup_tab = "bracket"
	_bracket_round_page = 0
	_show_detail()

func _on_confederation_chosen(confederation: String, tier: int) -> void:
	_selected_confederation = confederation
	_selected_tier = tier
	_selected_league = null
	_group_page = 0
	_cont_fx_page = -1
	_bracket_round_page = 0
	_show_detail()

const _COMP_HEADER_ICON_PX := 78  # 30 -> 42 -> 60 -> 78 -- pedido de Wilber: "hazlas otro poco mas grandes"

## Pone el logo de la competición a la izquierda del nombre y el TROFEO real
## a la derecha (pedido de Wilber: "que muestre a la derecha el trofeo así
## como a la izquierda está el logo"). La primera vez envuelve el Label de
## la escena en un HBox (no hace falta tocar el .tscn). `trophy` opcional
## porque algunas vistas (fuera de esta pasada) todavía no tienen un id de
## trofeo calculado — mejor sin trofeo que reventar.
func _set_comp_header(logo: Control, text: String, trophy: Control = null) -> void:
	# Cabecera HÉROE (9-oct, P1): logo grande, nombre en grande, país abajo
	# y el trofeo a la derecha — mismo lenguaje que Club/Entrenar/Perfil.
	var title: String = text
	var subtitle: String = ""
	if text.find(" — ") >= 0:
		subtitle = text.get_slice(" — ", 0)
		title = text.get_slice(" — ", 1)
	if _comp_hero != null and is_instance_valid(_comp_hero):
		_comp_hero.queue_free()
	logo.custom_minimum_size = Vector2(64, 64)
	if trophy != null:
		trophy.custom_minimum_size = Vector2(64, 64)
	var chips: Array = []
	if _selected_league != null and _selected_confederation == "" and int(WorldTickEngine.season.get("league_id", -1)) == _selected_league.league_id:
		chips.append(["★ TU LIGA", Styles.GOLD])
	_comp_hero = UiKit.hero(Styles.BLUE, logo, title, subtitle, chips, trophy)
	var parent := league_name_label.get_parent()
	parent.add_child(_comp_hero)
	parent.move_child(_comp_hero, league_name_label.get_index())
	league_name_label.visible = false
	if _comp_header_row != null:
		_comp_header_row.visible = false
	_style_tabs()

var _comp_hero: PanelContainer = null

## Pestañas de liga/copa como píldoras chicas con la activa resaltada
## (antes: texto plano, no se sabía cuál estaba elegida).
func _style_tabs() -> void:
	if _fixture_tab_button == null:
		_fixture_tab_button = Button.new()
		_fixture_tab_button.focus_mode = Control.FOCUS_NONE
		_fixture_tab_button.pressed.connect(_on_league_tab_pressed.bind("fixtures"))
		league_tabs_row.add_child(_fixture_tab_button)
		if table_tab_button.get_parent() == league_tabs_row:
			league_tabs_row.move_child(_fixture_tab_button, table_tab_button.get_index() + 1)
		elif _land_on:
			_fixture_tab_button.reparent(table_tab_button.get_parent())
			table_tab_button.get_parent().move_child(_fixture_tab_button, table_tab_button.get_index() + 1)
			_fixture_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_fixture_tab_button.custom_minimum_size = Vector2(0, 38)
		league_tabs_row.add_theme_constant_override("separation", 4)
		cup_tabs_row.add_theme_constant_override("separation", 4)
	var league_tabs: Array = [[table_tab_button, "table", "Tabla"], [_fixture_tab_button, "fixtures", "Fixture"],
		[scorers_tab_button, "scorers", "Goles"], [assists_tab_button, "assists", "Asist."],
		[playoff_tab_button, "playoffs", "Playoffs"], [discipline_tab_button, "discipline", "Tarjetas"]]
	for t in league_tabs:
		_pill_tab(t[0], String(t[2]), _league_tab == String(t[1]))
	for t in [[cup_bracket_tab_button, "bracket", "Cuadro"], [cup_scorers_tab_button, "scorers", "Goles"], [cup_assists_tab_button, "assists", "Asist."]]:
		_pill_tab(t[0], String(t[2]), _cup_tab == String(t[1]))

var _fixture_tab_button: Button = null

func _pill_tab(b: Button, text: String, on: bool) -> void:
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 38)
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 13)
	Styles.tab(b, on, true)
	b.add_theme_font_size_override("font_size", 13)

func _set_comp_header_legacy(logo: Control, text: String, trophy: Control = null) -> void:
	if _comp_header_row == null:
		var parent := league_name_label.get_parent()
		var idx := league_name_label.get_index()
		_comp_header_row = HBoxContainer.new()
		_comp_header_row.name = "CompHeaderRow"
		_comp_header_row.add_theme_constant_override("separation", 8)
		parent.remove_child(league_name_label)
		_comp_header_row.add_child(league_name_label)
		league_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(_comp_header_row)
		parent.move_child(_comp_header_row, idx)
	for c in _comp_header_row.get_children():
		if c != league_name_label:
			c.queue_free()
	logo.custom_minimum_size = Vector2(_COMP_HEADER_ICON_PX, _COMP_HEADER_ICON_PX)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_comp_header_row.add_child(logo)
	_comp_header_row.move_child(logo, 0)
	league_name_label.text = text
	if trophy != null:
		trophy.custom_minimum_size = Vector2(_COMP_HEADER_ICON_PX, _COMP_HEADER_ICON_PX)
		trophy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_comp_header_row.add_child(trophy)

func _show_picker() -> void:
	picker_panel.visible = true
	$Root/Margin/VBox/TitleLabel.visible = true
	detail_panel.visible = false

func _show_detail() -> void:
	picker_panel.visible = false
	detail_panel.visible = true
	if _land_on:
		$Root/Margin/VBox/TitleLabel.visible = false
		_land_sweep_tabs()
	if _selected_league == null:
		var _title: String = Confederations.tier_name(_selected_confederation, _selected_tier)
		var _trophy: Control = null
		if _selected_tier == 0:
			_title = "🏅 Supercopa de %s" % Confederations.REGION.get(_selected_confederation, _selected_confederation)
			_trophy = Trophy.for_honor("supercopa_cont", _COMP_HEADER_ICON_PX)
		elif _selected_tier == -1:
			_title = "🌍 Mundial de Clubes"
			_trophy = Trophy.for_honor("mundial_clubes", _COMP_HEADER_ICON_PX)
		else:
			_trophy = Trophy.for_honor("cont_%s_%d" % [_selected_confederation, _selected_tier], _COMP_HEADER_ICON_PX)
		var _logo: Control = Competition.continental_node(_selected_confederation, maxi(_selected_tier, 1), _COMP_HEADER_ICON_PX)
		_set_comp_header(_logo, _title, _trophy)
		section_row.visible = false
		league_tabs_row.visible = false
		cup_tabs_row.visible = false
		change_league_button.text = "Cambiar de copa"
		_render_detail()
		return

	playoff_tab_button.disabled = not _selected_league.has_playoffs
	match _picker_entry:
		"domestic_supercup":
			_set_comp_header(
				Competition.domestic_cup_node(_selected_league.country, _COMP_HEADER_ICON_PX),
				"🏅 Supercopa de %s" % _selected_league.country,
				Trophy.for_honor("supercopa", _COMP_HEADER_ICON_PX))
			section_row.visible = false
			league_tabs_row.visible = false
			cup_tabs_row.visible = false
			change_league_button.text = "Cambiar de país"
		"country_cup":
			# La copa ya salió como su propio renglón en la lista de
			# divisiones (todas la juegan) — aquí no hace falta el toggle
			# Liga/Copa, es SOLO la copa.
			_set_comp_header(
				Competition.domestic_cup_node(_selected_league.country, _COMP_HEADER_ICON_PX),
				CompetitionNames.domestic_cup(_selected_league.country),
				Trophy.for_title("dcup_%s" % _selected_league.country, _COMP_HEADER_ICON_PX))
			section_row.visible = false
			league_tabs_row.visible = false
			cup_tabs_row.visible = true
			_section = "cup"
			change_league_button.text = "Cambiar de país"
		"division":
			# La copa de este país ya tiene su propio renglón aparte (ver
			# _render_division_list) — mostrarla otra vez aquí, dentro de
			# CADA división, sería repetir la misma competición.
			_set_comp_header(
				Competition.league_node(_selected_league.league_id, _COMP_HEADER_ICON_PX),
				"%s — %s" % [_selected_league.country, _selected_league.league_name],
				Trophy.for_title("league_%d" % _selected_league.league_id, _COMP_HEADER_ICON_PX))
			section_row.visible = false
			league_tabs_row.visible = true
			cup_tabs_row.visible = false
			_section = "league"
			change_league_button.text = "Cambiar de liga"
		_: # "single" — país de una sola división: Liga y Copa conviven aquí
			_set_comp_header(
				Competition.league_node(_selected_league.league_id, _COMP_HEADER_ICON_PX),
				"%s — %s" % [_selected_league.country, _selected_league.league_name],
				Trophy.for_title("league_%d" % _selected_league.league_id, _COMP_HEADER_ICON_PX))
			var has_cup: bool = _selected_league.has_domestic_cup
			section_row.visible = has_cup
			if not has_cup:
				_section = "league"
			_refresh_section_buttons()
			change_league_button.text = "Cambiar de liga"
	_render_detail()

func _refresh_section_buttons() -> void:
	if _section == "league":
		Styles.tab(league_section_button, true)
		Styles.tab(cup_section_button, false)
		league_tabs_row.visible = true
		cup_tabs_row.visible = false
	else:
		Styles.tab(cup_section_button, true)
		Styles.tab(league_section_button, false)
		league_tabs_row.visible = false
		cup_tabs_row.visible = true

func _on_section_pressed(section: String) -> void:
	_section = section
	_refresh_section_buttons()
	_render_detail()

func _on_change_league_pressed() -> void:
	_show_picker()

## Atrás (franja de arriba o gesto del sistema): cierra primero lo que
## esté abierto — ficha de jugador → plantel → detalle de liga → nivel del
## selector — y recién después sale de la pantalla.
func nav_back() -> bool:
	if player_card_overlay.visible:
		_on_player_card_back_pressed()
		return true
	if roster_overlay.visible:
		_on_roster_back_pressed()
		return true
	if detail_panel.visible:
		_show_picker()
		return true
	if tier_back_button.visible:
		_on_tier_back_pressed()
		return true
	return false

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")

func _on_league_tab_pressed(tab: String) -> void:
	if tab == "playoffs" and playoff_tab_button.disabled:
		return
	_league_tab = tab
	_style_tabs()
	_render_detail()

func _on_cup_tab_pressed(tab: String) -> void:
	_cup_tab = tab
	_style_tabs()
	_render_detail()

func _render_detail() -> void:
	for child in detail_box.get_children():
		child.queue_free()
	_dispatch_detail()
	UiScroll.pad_bottom(detail_box, 76)  # aire bajo lo último (BackButton + BottomNav)

func _dispatch_detail() -> void:
	if _selected_confederation != "":
		if _selected_tier == 0:
			_render_continental_supercup()
		elif _selected_tier == -1:
			_render_cwc()
		else:
			_render_continental_cup()
		return
	if _picker_entry == "domestic_supercup":
		_render_domestic_supercup()
		return
	if _section == "cup":
		match _cup_tab:
			"scorers":
				_render_performers(WorldTickEngine.top_performers_for_cup(_selected_league.league_id).get("scorers", []), "Goles")
			"assists":
				_render_performers(WorldTickEngine.top_performers_for_cup(_selected_league.league_id).get("assists", []), "Asist.")
			_:
				_render_cup()
	else:
		match _league_tab:
			"scorers":
				_render_performers(WorldTickEngine.top_performers_for_league(_selected_league.league_id).get("scorers", []), "Goles")
			"assists":
				_render_performers(WorldTickEngine.top_performers_for_league(_selected_league.league_id).get("assists", []), "Asist.")
			"playoffs":
				_render_playoffs()
			"discipline":
				_render_discipline()
			"fixtures":
				_render_fixtures()
			_:
				_render_table()
				_render_table_legend()

## Pestaña "Tabla" con un toggle arriba: Tabla de posiciones / Calendario
## de la liga (pedido de Wilber: "sección de fixture en cada liga").
func _render_league_home() -> void:
	var toggle := HBoxContainer.new()
	toggle.add_theme_constant_override("separation", 8)
	for pair in [["table", "Tabla"], ["fixtures", "Calendario"]]:
		var b := Button.new()
		b.text = String(pair[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.focus_mode = Control.FOCUS_NONE
		var on: bool = _league_home_view == String(pair[0])
		Styles.tab(b, on, true)
		b.pressed.connect(func(v = String(pair[0])):
			_league_home_view = v
			_render_detail())
		toggle.add_child(b)
	detail_box.add_child(toggle)
	if _league_home_view == "fixtures":
		_render_fixtures()
	else:
		_render_table()

## Calendario completo de la liga, jornada a jornada, con navegador ◀ ▶.
func _render_fixtures() -> void:
	var rounds: Array = WorldTickEngine.league_fixture_rounds(_selected_league.league_id)
	if rounds.is_empty():
		var e := Label.new()
		e.text = "Sin calendario todavía."
		UiKit.empty_icon(e, Icons.PX_CALENDAR)
		e.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		detail_box.add_child(e)
		return
	if _fixtures_league_id != _selected_league.league_id:
		_fixtures_league_id = _selected_league.league_id
		_fixtures_page = -1
	if _fixtures_page < 0:
		# Auto: primera jornada con algún partido sin jugar (la "actual").
		_fixtures_page = rounds.size() - 1
		for i in range(rounds.size()):
			var any_pending := false
			for m in (rounds[i]["matches"] as Array):
				if not bool(m["played"]):
					any_pending = true
					break
			if any_pending:
				_fixtures_page = i
				break
	_fixtures_page = clampi(_fixtures_page, 0, rounds.size() - 1)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 10)
	var pv := Button.new()
	pv.text = "◀"
	pv.disabled = _fixtures_page <= 0
	pv.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(pv, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	pv.pressed.connect(func(): _fixtures_page -= 1; _render_detail())
	nav.add_child(pv)
	var t := Label.new()
	t.text = "Jornada %d  (%d/%d)" % [int(rounds[_fixtures_page]["matchday"]), _fixtures_page + 1, rounds.size()]
	t.add_theme_font_size_override("font_size", 15)
	nav.add_child(t)
	var nx := Button.new()
	nx.text = "▶"
	nx.disabled = _fixtures_page >= rounds.size() - 1
	nx.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(nx, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	nx.pressed.connect(func(): _fixtures_page += 1; _render_detail())
	nav.add_child(nx)
	detail_box.add_child(nav)

	var my_id: String = WorldTickEngine.user_club_id
	var idx := 0
	for m in (rounds[_fixtures_page]["matches"] as Array):
		detail_box.add_child(_fixture_row(m, my_id, idx))
		idx += 1

const _MES_ABBR := ["", "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]

## "12 sep" a partir de un epoch_day — para la fecha de cada partido del
## calendario (pedido de Wilber: "auditoría").
func _short_date(epoch_day: int) -> String:
	if epoch_day <= 0:
		return ""
	var d: Dictionary = CalendarUtils.epoch_day_to_date(epoch_day)
	return "%d %s" % [int(d.get("day", 0)), _MES_ABBR[clampi(int(d.get("month", 1)), 1, 12)]]

func _fixture_row(m: Dictionary, my_id: String, row_idx: int) -> Control:
	var hid: String = String(m["home_id"])
	var aid: String = String(m["away_id"])
	var mine: bool = hid == my_id or aid == my_id
	var bg: Color = Color(0.3, 0.24, 0.05) if mine else (Styles.CARD_DARK_2 if row_idx % 2 == 0 else Styles.CARD_DARK)
	var style: StyleBoxFlat = Styles.card_flat(bg, 6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	UiScroll.on_tap(panel, func(): _open_roster(hid if aid == my_id else aid))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	# Fecha en la que se juega (pedido de Wilber: "para llevar auditoría").
	var date_lbl := Label.new()
	date_lbl.text = _short_date(int(m.get("epoch_day", 0)))
	date_lbl.custom_minimum_size = Vector2(46, 0)
	date_lbl.add_theme_font_size_override("font_size", 10)
	date_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	row.add_child(date_lbl)
	row.add_child(Styles.club_crest(hid, 20))
	var hn := Label.new()
	hn.text = _club_name(hid)
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hn.clip_text = true
	hn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if mine: hn.add_theme_color_override("font_color", Styles.GOLD)
	row.add_child(hn)
	var sc := Label.new()
	sc.custom_minimum_size = Vector2(44, 0)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if bool(m["played"]):
		sc.text = "%d - %d" % [int(m["gh"]), int(m["ga"])]
		sc.add_theme_font_override("font", Styles.font_semibold())
	else:
		sc.text = "vs"
		sc.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	row.add_child(sc)
	var an := Label.new()
	an.text = _club_name(aid)
	an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	an.clip_text = true
	an.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if mine: an.add_theme_color_override("font_color", Styles.GOLD)
	row.add_child(an)
	row.add_child(Styles.club_crest(aid, 20))
	panel.add_child(row)
	return panel

const _TABLE_WIDTHS := [26, 150, 30, 26, 26, 26, 40, 42]
const _CREST_PX := 18

## Qué significa cada color de la franja (Campeón / copas / descenso).
func _render_table_legend() -> void:
	var legend: Array = StandingsColor.legend_for(_selected_league, _table_size)
	if legend.is_empty():
		return
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 4)
	for e in legend:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 5)
		var sw := ColorRect.new()
		sw.color = e[0]
		sw.custom_minimum_size = Vector2(10, 10)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
		var l := Label.new()
		l.text = String(e[1])
		l.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		l.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		h.add_child(l)
		flow.add_child(h)
	detail_box.add_child(flow)

func _render_table() -> void:
	var table := WorldTickEngine.table_for_league(_selected_league.league_id)
	if table.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Sin datos todavía."
		UiKit.empty_icon(empty_lbl, Icons.PX_STANDINGS)
		detail_box.add_child(empty_lbl)
		return
	var my_club_id: String = WorldTickEngine.user_club_id
	_table_size = table.size()
	var pager := Pager.new()
	detail_box.add_child(pager)
	var hspace := Control.new()
	hspace.custom_minimum_size = Vector2(_CREST_PX, 1)
	pager.set_header(DataTable.make_row(["#", "Club", "PJ", "G", "E", "P", "DG", "Pts"], _TABLE_WIDTHS, true, false, Callable(), Color.TRANSPARENT, -1, hspace))
	var items: Array = []
	for i in range(table.size()):
		items.append({"idx": i, "row": table[i], "mine": table[i]["club_id"] == my_club_id})
	pager.show_items(items, 12, _build_table_row)

func _build_table_row(item: Dictionary) -> Control:
	var row: Dictionary = item["row"]
	var cid: String = row["club_id"]
	# Bug real de la auditoría (ronda 6, confirmado por Wilber jugando): la
	# tabla de ESTA pantalla ("Torneos" → Tabla, la que de verdad se usa)
	# nunca tuvo la franja de color — solo se había tocado Standings.gd
	# (Clasificación de tu propia liga desde el Hub) y el mini-tabla, no
	# esta, que es la vista principal de tabla de cualquier liga del mundo.
	var accent: Color = StandingsColor.accent_for(_selected_league, _table_size, int(row["pos"]))
	return DataTable.make_row([
		str(row["pos"]), row["name"], str(row["pj"]), str(row["g"]),
		str(row["e"]), str(row["p"]), "%+d" % row["dg"], str(row["pts"]),
	], _TABLE_WIDTHS, false, bool(item["mine"]), _open_roster.bind(cid), accent, int(item["idx"]), Styles.club_crest(cid, _CREST_PX))

func _hspace(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, 1)
	return c

func _add_table_row(cells: Array, is_header: bool, is_mine: bool = false, custom_widths: Array = [], club_id_for_click: String = "", intl: bool = false) -> void:
	var widths: Array = custom_widths if not custom_widths.is_empty() else [30, 210, 34, 30, 30, 30, 42, 42]
	# Cualquier fila de tabla con club (no el encabezado) se puede tocar
	# para ver su nómina — "debo poder entrar a ver la nómina de cada
	# equipo", pedido explícito.
	var on_click: Callable = _open_roster.bind(club_id_for_click) if club_id_for_click != "" and not is_header else Callable()
	var lead: Control = null
	if is_header:
		lead = _hspace((_CREST_PX + 20) if intl else _CREST_PX)
	elif club_id_for_click != "":
		lead = _flag_crest_lead(club_id_for_click) if intl else Styles.club_crest(club_id_for_click, _CREST_PX)
	DataTable.add_row(detail_box, cells, widths, is_header, is_mine, on_click, Color.TRANSPARENT, lead)

func _render_cup() -> void:
	var league_cup := WorldTickEngine.cup_for_league(_selected_league.league_id)
	_render_bracket(league_cup, "Esta liga no tiene copa, o aún no hay datos.")

func _render_playoffs() -> void:
	var playoff := WorldTickEngine.playoff_for_league(_selected_league.league_id)
	_render_bracket(playoff, "Esta liga no tiene liguilla, o aún no hay datos.")

func _render_continental_cup() -> void:
	var cup := WorldTickEngine.continental_cup_for(_selected_confederation, _selected_tier)
	if cup.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Sin clubes clasificados todavía."
		UiKit.empty_icon(empty_lbl, Icons.PX_STANDINGS)
		detail_box.add_child(empty_lbl)
		return

	# Toggle Tabla / Calendario — solo tiene sentido si hay fase de grupos
	# o de liga (los torneos de cuadro directo ya listan sus rondas).
	var has_phase: bool = not (cup.get("groups", []) as Array).is_empty() \
		or not (cup.get("swiss_fixtures", []) as Array).is_empty()
	if has_phase:
		var toggle := HBoxContainer.new()
		toggle.add_theme_constant_override("separation", 8)
		for pair in [["table", "Tabla"], ["fixtures", "Calendario"]]:
			var b := Button.new()
			b.text = String(pair[1])
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 40)
			b.focus_mode = Control.FOCUS_NONE
			var on: bool = _cont_view == String(pair[0])
			Styles.tab(b, on, true)
			b.pressed.connect(func(v = String(pair[0])):
				_cont_view = v
				_render_detail())
			toggle.add_child(b)
		detail_box.add_child(toggle)

	if has_phase and _cont_view == "fixtures":
		_render_cont_fixtures()
		detail_box.add_child(HSeparator.new())
		detail_box.add_child(DataTable.section_tag("ELIMINATORIAS"))
		_render_bracket(cup, "", true)
		return

	_render_league_phase(cup.get("league_phase", []))
	_render_groups(cup.get("groups", []))
	_render_bracket(cup, "", true)

## Calendario de la fase de grupos / liga del torneo continental, jornada
## a jornada, con navegador ◀ ▶ — mismo formato que el de la liga.
func _render_cont_fixtures() -> void:
	var rounds: Array = WorldTickEngine.continental_fixture_rounds(_selected_confederation, _selected_tier)
	if rounds.is_empty():
		var e := Label.new()
		e.text = "El calendario de la fase de grupos aún no está armado."
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		detail_box.add_child(e)
		return
	if _cont_fx_page < 0:
		_cont_fx_page = rounds.size() - 1
		for i in range(rounds.size()):
			var pending := false
			for m in (rounds[i]["matches"] as Array):
				if not bool(m["played"]):
					pending = true
					break
			if pending:
				_cont_fx_page = i
				break
	_cont_fx_page = clampi(_cont_fx_page, 0, rounds.size() - 1)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 10)
	var pv := Button.new()
	pv.text = "◀"
	pv.disabled = _cont_fx_page <= 0
	pv.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(pv, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	pv.pressed.connect(func(): _cont_fx_page -= 1; _render_detail())
	nav.add_child(pv)
	var t := Label.new()
	t.text = "Jornada %d  (%d/%d)" % [int(rounds[_cont_fx_page]["matchday"]), _cont_fx_page + 1, rounds.size()]
	t.add_theme_font_size_override("font_size", 15)
	nav.add_child(t)
	var nx := Button.new()
	nx.text = "▶"
	nx.disabled = _cont_fx_page >= rounds.size() - 1
	nx.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(nx, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	nx.pressed.connect(func(): _cont_fx_page += 1; _render_detail())
	nav.add_child(nx)
	detail_box.add_child(nav)

	var my_id: String = WorldTickEngine.user_club_id
	var idx := 0
	for m in (rounds[_cont_fx_page]["matches"] as Array):
		detail_box.add_child(_fixture_row(m, my_id, idx))
		idx += 1

const _LP_WIDTHS := [26, 210, 34, 46, 40]

func _render_league_phase(rows: Array) -> void:
	if rows.is_empty():
		return
	detail_box.add_child(DataTable.section_tag("FASE DE LIGA"))
	var hint_lbl := Label.new()
	hint_lbl.text = "Los 8 primeros pasan directo a octavos; 9º-24º juegan el playoff previo."
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	hint_lbl.add_theme_font_size_override("font_size", 12)
	detail_box.add_child(hint_lbl)

	# Tabla larga (formato Champions, hasta 36) → paginada con ◀▶ (pedido
	# de Wilber: "colocala con botones para pasar y hacer la lista más corta").
	var my_club_id: String = WorldTickEngine.user_club_id
	var pager := Pager.new()
	detail_box.add_child(pager)
	var hsp := Control.new()
	hsp.custom_minimum_size = Vector2(_CREST_PX + 20, 1)
	pager.set_header(DataTable.make_row(["#", "Club", "PJ", "Pts", "DG"], _LP_WIDTHS, true, false, Callable(), Color.TRANSPARENT, -1, hsp))
	var items: Array = []
	for i in range(rows.size()):
		items.append({"row": rows[i], "mine": String(rows[i].get("club_id", "")) == my_club_id, "idx": i})
	pager.show_items(items, 12, _build_lp_row)
	detail_box.add_child(HSeparator.new())

func _build_lp_row(item: Dictionary) -> Control:
	var row: Dictionary = item["row"]
	var cid: String = String(row.get("club_id", ""))
	return DataTable.make_row([
		str(row["pos"]), _club_name(cid), str(row["pj"]), str(row["pts"]), "%+d" % row["dg"],
	], _LP_WIDTHS, false, bool(item["mine"]), _open_roster.bind(cid), Color.TRANSPARENT, int(item["idx"]), _flag_crest_lead(cid))

## Un grupo a la vez, con botones ◀ ▶ para pasar de uno a otro — con
## cupos reales (7-9 grupos en algunas confederaciones tras el reparto por
## país, ver ContinentalEngine) listarlos todos apilados hacía la pantalla
## interminable; pedido explícito de Wilber.
func _render_groups(groups: Array) -> void:
	if groups.is_empty():
		return
	_group_page = clampi(_group_page, 0, groups.size() - 1)
	var my_club_id: String = WorldTickEngine.user_club_id
	detail_box.add_child(DataTable.section_tag("FASE DE GRUPOS"))

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 12)

	var prev_btn := Button.new()
	prev_btn.text = "◀"
	prev_btn.disabled = _group_page <= 0
	prev_btn.pressed.connect(_on_group_page_changed.bind(-1))
	Styles.styled_button(prev_btn, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	nav.add_child(prev_btn)

	var group: Dictionary = groups[_group_page]
	var title_lbl := Label.new()
	title_lbl.text = "%s (%d/%d) — clasifican los 2 primeros" % [group["name"], _group_page + 1, groups.size()]
	title_lbl.add_theme_font_size_override("font_size", 16)
	nav.add_child(title_lbl)

	var next_btn := Button.new()
	next_btn.text = "▶"
	next_btn.disabled = _group_page >= groups.size() - 1
	next_btn.pressed.connect(_on_group_page_changed.bind(1))
	Styles.styled_button(next_btn, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	nav.add_child(next_btn)

	detail_box.add_child(nav)
	_add_table_row(["#", "Club", "PJ", "DG", "Pts"], true, false, [24, 232, 40, 50, 42], "", true)
	for row in group["standings"]:
		var club_id: String = row["club_id"]
		_add_table_row([
			str(row["pos"]), _club_name(club_id), str(row["pj"]),
			"%+d" % row["dg"], str(row["pts"]),
		], false, club_id == my_club_id, [24, 232, 40, 50, 42], club_id, true)
	detail_box.add_child(HSeparator.new())
	detail_box.add_child(DataTable.section_tag("ELIMINATORIAS"))

func _on_group_page_changed(delta: int) -> void:
	_group_page += delta
	_render_detail()

var _bracket_round_page: int = 0

## Eliminatoria por RONDAS: un navegador ◀ Octavos (1/4) ▶ y solo esa
## ronda a la vez (Wilber: "distribuido por rondas... en champions").
func _render_bracket(bracket: Dictionary, empty_text: String, intl: bool = false) -> void:
	var cfn: Callable = Callable(self, "_club_country") if intl else Callable()
	var rounds: Array = bracket.get("rounds", [])
	if rounds.is_empty():
		if empty_text != "":
			var e := Label.new()
			e.text = empty_text
			e.add_theme_color_override("font_color", Styles.GRAY_TEXT)
			detail_box.add_child(e)
		return
	if rounds.size() == 1:
		BracketView.render_round(detail_box, rounds[0], WorldTickEngine.user_club_id, _club_name, cfn)
		return
	_bracket_round_page = clampi(_bracket_round_page, 0, rounds.size() - 1)
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 10)
	var pv := Button.new()
	pv.text = "◀"
	pv.disabled = _bracket_round_page <= 0
	pv.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(pv, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	pv.pressed.connect(func(): _bracket_round_page -= 1; _render_detail())
	nav.add_child(pv)
	var t := Label.new()
	t.text = "%s  (%d/%d)" % [String(rounds[_bracket_round_page].get("round_name", "Ronda")), _bracket_round_page + 1, rounds.size()]
	t.add_theme_font_size_override("font_size", 15)
	nav.add_child(t)
	var nx := Button.new()
	nx.text = "▶"
	nx.disabled = _bracket_round_page >= rounds.size() - 1
	nx.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(nx, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	nx.pressed.connect(func(): _bracket_round_page += 1; _render_detail())
	nav.add_child(nx)
	detail_box.add_child(nav)
	BracketView.render_round(detail_box, rounds[_bracket_round_page], WorldTickEngine.user_club_id, _club_name, cfn)

const _PERF_WIDTHS := [30, 168, 152, 66]

func _render_performers(rows: Array, count_label: String) -> void:
	if rows.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Sin datos todavía."
		UiKit.empty_icon(empty_lbl, Icons.PX_STANDINGS)
		detail_box.add_child(empty_lbl)
		return
	var player := SaveManager.load_player()
	var my_name: String = player.player_name if (player != null and player.club_id != "") else ""
	var pager := Pager.new()
	detail_box.add_child(pager)
	pager.set_header(DataTable.make_row(["#", "Jugador", "Club", count_label], _PERF_WIDTHS, true))
	var items: Array = []
	for i in range(rows.size()):
		items.append({"idx": i, "row": rows[i], "cl": count_label, "mine": String(rows[i]["name"]) == my_name})
	pager.show_items(items, 12, _build_performer_row)

func _build_performer_row(item: Dictionary) -> Control:
	var row: Dictionary = item["row"]
	return DataTable.make_row([
		str(int(item["idx"]) + 1), String(row["name"]), String(row["club_name"]),
		"%s %d" % [String(item["cl"]), int(row["count"])],
	], _PERF_WIDTHS, false, bool(item["mine"]), Callable(), Color.TRANSPARENT, int(item["idx"]))

## Tarjetas/lesiones de la liga — pedido explícito ("agregue las
## tarjetas y las lesiones"). El motor (DisciplineEngine) ya existía y se
## probaba solo en tests de texto; esta es su primera pantalla real.
func _render_discipline() -> void:
	var disc: Dictionary = WorldTickEngine.discipline_for_league(_selected_league.league_id)
	var yellow_leaders: Array = disc.get("yellow_leaders", [])
	var reds: Array = disc.get("red_cards", [])
	var injuries: Array = disc.get("injuries", [])

	detail_box.add_child(DataTable.section_tag("MÁS AMONESTADOS"))
	if yellow_leaders.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Sin datos todavía."
		UiKit.empty_icon(empty_lbl, Icons.PX_STANDINGS)
		detail_box.add_child(empty_lbl)
	else:
		_add_table_row(["#", "Jugador", "Club", "Amarillas"], true, false, [30, 260, 220, 90])
		for i in range(mini(15, yellow_leaders.size())):
			var row: Dictionary = yellow_leaders[i]
			_add_table_row([
				str(i + 1), String(row["name"]), String(row["club_name"]), str(int(row["count"])),
			], false, false, [30, 260, 220, 90])

	detail_box.add_child(DataTable.section_tag("EXPULSIONES (%d)" % reds.size()))
	if reds.is_empty():
		var empty_red := Label.new()
		empty_red.text = "Sin expulsiones todavía."
		UiKit.empty_icon(empty_red, Icons.PX_STANDINGS)
		detail_box.add_child(empty_red)
	else:
		for row in reds:
			var lbl := Label.new()
			lbl.text = "%s (%s)" % [String(row["name"]), _club_name(String(row["club_id"]))]
			detail_box.add_child(lbl)

	detail_box.add_child(DataTable.section_tag("LESIONADOS (%d)" % injuries.size()))
	if injuries.is_empty():
		var empty_inj := Label.new()
		empty_inj.text = "Sin lesiones todavía."
		UiKit.empty_icon(empty_inj, Icons.PX_STANDINGS)
		detail_box.add_child(empty_inj)
	else:
		for row in injuries:
			var lbl := Label.new()
			lbl.text = "%s (%s) — %d días" % [String(row["name"]), _club_name(String(row["club_id"])), int(row["days"])]
			detail_box.add_child(lbl)

func _club_name(club_id: String) -> String:
	if club_id == "":
		return "?"
	var club := WorldFactory.find_club(WorldTickEngine.world, club_id)
	return club.club_name if club != null else club_id

## País del club = país de su liga. Para poner la bandera al lado del
## escudo en los torneos internacionales (pedido de Wilber).
func _club_country(club_id: String) -> String:
	if club_id == "":
		return ""
	var club := WorldFactory.find_club(WorldTickEngine.world, club_id)
	if club == null:
		return ""
	for lg in WorldTickEngine.world.get("leagues", []):
		if lg.league_id == club.league_id:
			return lg.country
	return ""

## [bandera][escudo] para torneos internacionales. `px` = tamaño del escudo.
func _mini_flag_crest(club_id: String, px: int) -> Control:
	var crest: Control = Styles.club_crest(club_id, px)
	var country: String = _club_country(club_id)
	var fr: TextureRect = CountryFlags.flag_rect(country, maxi(10, px - 8)) if country != "" else null
	if fr == null:
		return crest
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(fr)
	box.add_child(crest)
	return box

## Igual, tamaño de tabla (`_CREST_PX`) — para el nodo `lead` de DataTable.
func _flag_crest_lead(club_id: String) -> Control:
	return _mini_flag_crest(club_id, _CREST_PX)

# --- Nómina de un club y carta de un jugador (overlays por encima de todo) ---

const _POSITION_ORDER := ["GK", "DF", "MF", "ST"]

var _roster_club_id: String = ""
var _roster_view: String = "squad"  # "squad" | "vitrina"

func _open_roster(club_id: String) -> void:
	var club := WorldFactory.find_club(WorldTickEngine.world, club_id)
	var meta: Dictionary = WorldTickEngine.world.get("club_meta_by_id", {})
	if club == null or not meta.has(club_id):
		return
	_roster_club_id = club_id
	_roster_view = "squad"
	roster_title_label.text = club.club_name
	_place_roster_identity(club)
	_place_roster_tabs()
	_render_roster_body()
	roster_overlay.visible = true

## Dos viñetas encima de la lista: Plantilla | Vitrina (pedido de Wilber).
func _place_roster_tabs() -> void:
	var parent := roster_list_box.get_parent().get_parent()  # VBox del overlay
	var row: HBoxContainer = parent.get_node_or_null("RosterTabsRow")
	if row == null:
		row = HBoxContainer.new()
		row.name = "RosterTabsRow"
		row.add_theme_constant_override("separation", 6)
		var scroll_idx := roster_list_box.get_parent().get_index()
		parent.add_child(row)
		parent.move_child(row, scroll_idx)
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	for pair in [["Plantilla", "squad"], ["Vitrina", "vitrina"]]:
		var b := Button.new()
		b.text = String(pair[0])
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		var key: String = String(pair[1])
		var on: bool = _roster_view == key
		Styles.tab(b, on, true)
		b.pressed.connect(func():
			_roster_view = key
			_place_roster_tabs()
			_render_roster_body())
		row.add_child(b)

func _render_roster_body() -> void:
	for child in roster_list_box.get_children():
		child.queue_free()
	if _roster_view == "vitrina":
		roster_list_box.add_child(TrophyCabinet.build(
			WorldTickEngine.club_trophy_cabinet(_roster_club_id)))
		return

	var squad: Array[PlayerData] = WorldFactory.make_squad_with_transfers(
		WorldTickEngine.world, _roster_club_id, WorldTickEngine.world_seed, int(WorldTickEngine.season.get("season_start_epoch_day", 0)),
	)
	squad.sort_custom(func(a, b):
		var oa: int = _POSITION_ORDER.find(a.position)
		var ob: int = _POSITION_ORDER.find(b.position)
		if oa != ob:
			return oa < ob
		return a.overall > b.overall
	)
	var my_club_id: String = WorldTickEngine.user_club_id
	var player := SaveManager.load_player() if _roster_club_id == my_club_id else null
	if player != null and not squad.has(player):
		squad.append(player)
		squad.sort_custom(func(a, b):
			var oa: int = _POSITION_ORDER.find(a.position)
			var ob: int = _POSITION_ORDER.find(b.position)
			if oa != ob:
				return oa < ob
			return a.overall > b.overall)
	# Lista PAGINADA con encabezado por línea (GK/DF/MF/ST) — navegar 25
	# jugadores de un scroll era incómodo (pedido de Wilber).
	var _LINE_NAME := {"GK": "PORTEROS", "DF": "DEFENSAS", "MF": "MEDIOCAMPO", "ST": "DELANTEROS"}
	var items: Array = []
	var last_line := ""
	for p in squad:
		if p.position != last_line:
			last_line = p.position
			items.append({"kind": "header", "text": String(_LINE_NAME.get(p.position, p.position))})
		items.append({"kind": "row", "player": p, "mine": player != null and p.player_name == player.player_name})
	var pager := Pager.new()
	roster_list_box.add_child(pager)
	pager.show_items(items, 11, func(it):
		if it["kind"] == "header":
			return DataTable.section_tag(String(it["text"]))
		return _make_roster_row(it["player"], bool(it["mine"])))
	UiScroll.pad_bottom(roster_list_box)

## Escudo (grande) + las dos camisetas (titular y visitante) junto al
## título de la nómina. El Label del .tscn se envuelve una sola vez; el
## resto de hijos se PURGAN con remove_child + queue_free (queue_free es
## diferido: sin el remove_child inmediato se acumulaban escudos y
## camisetas a cada apertura — bug que reportó Wilber con captura).
func _place_roster_identity(club: ClubData) -> void:
	# OJO: el título se RE-PARENTA a RosterIdentityRow la primera vez, así
	# que NO se puede usar roster_title_label.get_parent() en llamadas
	# siguientes (devuelve el row, y se creaba un row nuevo dentro → los
	# escudos/camisetas se acumulaban, bug que reportó Wilber otra vez).
	var parent: Node = $RosterOverlay/Margin/VBox
	var row: HBoxContainer = parent.get_node_or_null("RosterIdentityRow")
	if row == null:
		row = HBoxContainer.new()
		row.name = "RosterIdentityRow"
		row.add_theme_constant_override("separation", 10)
		var idx := roster_title_label.get_index()
		roster_title_label.get_parent().remove_child(roster_title_label)
		row.add_child(roster_title_label)
		roster_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		roster_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		roster_title_label.clip_text = true
		roster_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		parent.add_child(row)
		parent.move_child(row, idx)
	for c in row.get_children():
		if c != roster_title_label:
			row.remove_child(c)
			c.queue_free()

	var crest := Styles.club_crest(club.club_id, 46)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(crest)
	row.move_child(crest, 0)
	var yr: int = WorldTickEngine.get_season_start_year()
	for away in [false, true]:
		var kcol := VBoxContainer.new()
		kcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		kcol.add_theme_constant_override("separation", 1)
		var kit := Kit.build_for_club_kit(club, yr, away, 42)
		kit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		kcol.add_child(kit)
		var kl := Label.new()
		kl.text = "Visita" if away else "Titular"
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kl.add_theme_font_size_override("font_size", 9)
		kl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		kcol.add_child(kl)
		row.add_child(kcol)
		row.move_child(kcol, 1 if not away else 2)

func _make_roster_row(p: PlayerData, is_mine: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 48)
	var bg: Color = Color(0.3, 0.24, 0.05) if is_mine else Styles.CARD_DARK
	var style := Styles.card_flat(bg, 6)
	style.border_width_left = 4
	style.border_color = PlayerCard.tier_color(p.overall)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	UiScroll.on_tap(panel, func(): _open_player_card(p))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var fr: TextureRect = CountryFlags.flag_rect(p.country, 16)
	if fr != null:
		fr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(fr)

	var pos_lbl := Label.new()
	pos_lbl.text = p.detailed_position
	pos_lbl.custom_minimum_size = Vector2(38, 0)
	pos_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	pos_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(pos_lbl)

	var name_lbl := Label.new()
	name_lbl.text = p.player_name + ("  (tú)" if is_mine else "")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_mine:
		name_lbl.add_theme_color_override("font_color", Styles.GOLD)
	elif String(p.origin) == "Cantera del club":
		name_lbl.text = "🎓 " + name_lbl.text
	row.add_child(name_lbl)

	var age_lbl := Label.new()
	age_lbl.text = "%dª" % p.age
	age_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	age_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(age_lbl)

	var ovr := Label.new()
	ovr.text = str(p.overall)
	ovr.custom_minimum_size = Vector2(26, 0)
	ovr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ovr.add_theme_font_override("font", Styles.font_semibold())
	ovr.add_theme_color_override("font_color", PlayerCard.tier_color(p.overall))
	row.add_child(ovr)

	panel.add_child(row)
	return panel

func _on_roster_back_pressed() -> void:
	roster_overlay.visible = false

func _open_player_card(p: PlayerData) -> void:
	PlayerCard.render(player_card_box, p)
	player_card_overlay.visible = true

func _on_player_card_back_pressed() -> void:
	player_card_overlay.visible = false


## HORIZONTAL: dentro de una liga / copa, la cabecera, Liga/Copa, las
## pestañas y "Cambiar de liga" van en una columna a la izquierda; la tabla
## (o cuadro, goleadores…) ocupa todo el alto a la derecha. Antes la tabla
## quedaba en un hueco de UNA fila.
var _land_on := false

func _land_detail_layout() -> void:
	if get_viewport_rect().size.x <= get_viewport_rect().size.y:
		return
	_land_on = true
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	detail_panel.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 300
	left.add_theme_constant_override("separation", 8)
	cols.add_child(left)
	for n in [league_name_label, section_row, league_tabs_row, cup_tabs_row]:
		n.reparent(left)
	for row in [league_tabs_row, cup_tabs_row]:
		var g := GridContainer.new()
		g.columns = 2
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_theme_constant_override("h_separation", 6)
		g.add_theme_constant_override("v_separation", 6)
		for b in row.get_children():
			(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			(b as Control).custom_minimum_size.y = 38
			b.reparent(g)
		row.add_child(g)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sp)
	change_league_button.reparent(left)
	detail_scroll.reparent(cols)
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL


## Pestañas que se agregan por código después (ej. "Fixture") entran a la grilla.
func _land_sweep_tabs() -> void:
	for row in [league_tabs_row, cup_tabs_row]:
		var g: GridContainer = null
		for c in row.get_children():
			if c is GridContainer:
				g = c
		if g == null:
			continue
		for c in row.get_children():
			if c is Button:
				(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
				(c as Control).custom_minimum_size = Vector2(0, 38)
				c.reparent(g)
		for b in g.get_children():
			(b as Control).custom_minimum_size = Vector2(0, 38)
