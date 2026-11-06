extends Control

## Buscador de jugadores del mundo con filtros — pedido explícito de
## Wilber: "agregar una sección para buscar jugadores en específico con
## filtros y todo", accesible desde el menú de Carrera.
##
## Alcance acotado a propósito por rendimiento (mismo pedido de Wilber en
## esta tanda: "optimiza los queries"): se busca DENTRO de una liga
## elegida, no las 55 de golpe. Arma esa liga con
## WorldFactory.make_squad_with_transfers — el MISMO costo que ya paga
## WorldExplorer al abrir un club, cacheado en memoria por liga mientras
## la pantalla esté abierta (elegir otra liga sí recalcula).
##
## Filtros: nombre, posición amplia, rango de edad, rango de media. Tocar
## un resultado abre su carta de atributos completa — PlayerCard.render(),
## el mismo overlay reusado en Squad/WorldExplorer, nunca una vista propia.

const _POSITIONS := [
	["", "Cualquier posición"],
	["GK", "Portero"],
	["DF", "Defensa"],
	["MF", "Mediocampo"],
	["ST", "Delantero"],
]
const _RESULTS_PER_PAGE := 12

@onready var league_button: Button = $Root/VBox/LeagueRow/LeagueButton
@onready var name_edit: LineEdit = $Root/VBox/FilterCard/FilterMargin/FilterVBox/NameEdit
@onready var pos_option: OptionButton = $Root/VBox/FilterCard/FilterMargin/FilterVBox/PosRow/PosOption
@onready var age_min: SpinBox = $Root/VBox/FilterCard/FilterMargin/FilterVBox/RangeRow/AgeMin
@onready var age_max: SpinBox = $Root/VBox/FilterCard/FilterMargin/FilterVBox/RangeRow/AgeMax
@onready var ovr_min: SpinBox = $Root/VBox/FilterCard/FilterMargin/FilterVBox/OvrRow/OvrMin
@onready var ovr_max: SpinBox = $Root/VBox/FilterCard/FilterMargin/FilterVBox/OvrRow/OvrMax
@onready var search_button: Button = $Root/VBox/FilterCard/FilterMargin/FilterVBox/SearchButton
@onready var count_label: Label = $Root/VBox/CountLabel
@onready var results_scroll: ScrollContainer = $Root/VBox/Scroll
@onready var results_box: VBoxContainer = $Root/VBox/Scroll/ResultsBox
@onready var back_button: Button = $Root/VBox/BackButton

@onready var player_card_overlay: ColorRect = $PlayerCardOverlay
@onready var player_card_box: VBoxContainer = $PlayerCardOverlay/Margin/VBox/Scroll/PlayerCardBox
@onready var player_card_back_button: Button = $PlayerCardOverlay/Margin/VBox/PlayerCardBackButton

var _world: Dictionary = {}
var _leagues_sorted: Array = []
var _league_id: int = -1
var _league_picker_overlay: Control = null
var _squad_cache: Dictionary = {}   # league_id (int) -> Array[{player, club}]
var _pager: Pager = null

func _ready() -> void:
	WorldTickEngine.load_runtime()
	_world = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())

	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/CareerMenu/CareerMenu.tscn"))

	results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	results_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# Bug visual real (auditoría ronda 3): faltaba el deadzone táctil en
	# los dos scrolls de esta pantalla (resultados + ficha de jugador).
	UiScroll.make_touch(results_scroll)
	UiScroll.make_touch($PlayerCardOverlay/Margin/VBox/Scroll)

	name_edit.placeholder_text = "Nombre del jugador…"
	name_edit.custom_minimum_size = Vector2(0, 44)
	name_edit.text_submitted.connect(func(_t): _run_search())

	for pair in _POSITIONS:
		pos_option.add_item(pair[1])

	for sb in [age_min, age_max, ovr_min, ovr_max]:
		sb.custom_minimum_size = Vector2(0, 40)
	age_min.min_value = 15; age_min.max_value = 45; age_min.value = 15
	age_max.min_value = 15; age_max.max_value = 45; age_max.value = 45
	ovr_min.min_value = 30; ovr_min.max_value = 99; ovr_min.value = 30
	ovr_max.min_value = 30; ovr_max.max_value = 99; ovr_max.value = 99

	Styles.styled_button(search_button, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	search_button.icon = Icons.load_icon(Icons.SEARCH)
	search_button.add_theme_constant_override("icon_max_width", 20)
	search_button.pressed.connect(_run_search)

	player_card_back_button.pressed.connect(func(): player_card_overlay.visible = false)

	league_button.custom_minimum_size = Vector2(0, 44)
	league_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	league_button.clip_text = true
	league_button.icon = Icons.load_icon(Icons.EXPLORE)
	league_button.add_theme_constant_override("icon_max_width", 20)
	Styles.styled_button(league_button, Styles.card_flat(Styles.CARD_DARK_2, 8), Color.WHITE)
	league_button.pressed.connect(_open_league_picker)

	_landscape_split()
	_populate_leagues()
	_run_search()

## Todas las ligas del mundo, agrupadas por reputación (los grandes
## primero) — mismo criterio de "lo importante arriba" que WorldExplorer.
## NO se pinta como OptionButton: con 55 ligas ese desplegable nativo
## scrollea horrible al tacto (reporte de Wilber) — mismo picker con
## buscador + Pager que ya usa CharacterCreation para elegir país.
func _populate_leagues() -> void:
	_leagues_sorted = (_world.get("leagues", []) as Array).duplicate()
	_leagues_sorted.sort_custom(func(a, b): return int(a.reputation) > int(b.reputation))
	var player: PlayerData = SaveManager.load_player()
	_league_id = -1
	if player != null and player.club_id != "":
		var my_club: ClubData = WorldFactory.find_club(_world, player.club_id)
		if my_club != null:
			_league_id = my_club.league_id
	if _league_id == -1 and not _leagues_sorted.is_empty():
		_league_id = int(_leagues_sorted[0].league_id)
	_refresh_league_button()

func _league_by_id(league_id: int) -> LeagueData:
	for lg in _leagues_sorted:
		if int(lg.league_id) == league_id:
			return lg
	return null

func _refresh_league_button() -> void:
	var lg: LeagueData = _league_by_id(_league_id)
	league_button.text = "  %s (%s)" % [lg.league_name, lg.country] if lg != null else "  Elegir liga…"

## Picker a pantalla completa: buscador + lista paginada (Pager), el
## mismo patrón que _open_country_picker en CharacterCreation — tocar
## cualquier fila cierra el picker y dispara la búsqueda.
func _open_league_picker() -> void:
	if _league_picker_overlay != null and is_instance_valid(_league_picker_overlay):
		_league_picker_overlay.queue_free()
	_league_picker_overlay = Control.new()
	_league_picker_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.6)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_league_picker_overlay.queue_free())
	_league_picker_overlay.add_child(scrim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = 60
	panel.offset_bottom = -60
	panel.add_theme_stylebox_override("panel", Styles.card(Styles.CARD_DARK))
	var pm := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		pm.add_theme_constant_override("margin_" + s, 14)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)

	var search := LineEdit.new()
	search.placeholder_text = "Buscar liga o país…"
	search.custom_minimum_size = Vector2(0, 44)
	v.add_child(search)

	var pager := Pager.new()
	v.add_child(pager)

	var render_list := func(query: String):
		var q := _norm(query.strip_edges())
		var matches: Array = []
		for lg in _leagues_sorted:
			if q == "" or _norm(lg.league_name).contains(q) or _norm(lg.country).contains(q):
				matches.append(lg)
		pager.show_items(matches, 9, func(lg: LeagueData) -> Control:
			var b := Button.new()
			b.custom_minimum_size = Vector2(0, 46)
			b.focus_mode = Control.FOCUS_NONE
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.clip_text = true
			Styles.styled_button(b, Styles.card_flat(Styles.CARD_DARK_2, 8), Color.WHITE)
			var hb := HBoxContainer.new()
			hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			hb.add_theme_constant_override("separation", 8)
			hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var mm := MarginContainer.new()
			mm.add_theme_constant_override("margin_left", 10)
			mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var logo: Control = Competition.league_node(lg.league_id, 20)
			if logo != null:
				logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hb.add_child(logo)
			var l := Label.new()
			l.text = "%s (%s)" % [lg.league_name, lg.country]
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(l)
			mm.add_child(hb)
			mm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			b.add_child(mm)
			b.pressed.connect(func():
				_league_id = int(lg.league_id)
				_refresh_league_button()
				_league_picker_overlay.queue_free()
				_run_search())
			return b)

	search.text_changed.connect(render_list)
	render_list.call("")

	pm.add_child(v)
	panel.add_child(pm)
	_league_picker_overlay.add_child(panel)
	add_child(_league_picker_overlay)
	search.grab_focus()

## Plantel completo de una liga (todos sus clubes, con fichajes ya
## aplicados) — cacheado por liga mientras la pantalla esté abierta.
func _pool_for_league(league_id: int) -> Array:
	if _squad_cache.has(league_id):
		return _squad_cache[league_id]
	var season_start: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
	var clubs: Array = _world.get("clubs_by_league", {}).get(league_id, [])
	var pool: Array = []
	for club in clubs:
		var squad: Array = WorldFactory.make_squad_with_transfers(_world, club.club_id, WorldTickEngine.world_seed, season_start)
		for p in squad:
			pool.append({"player": p, "club": club})
	_squad_cache[league_id] = pool
	return pool

static func _norm(s: String) -> String:
	var out := s.to_lower()
	for pair in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"], ["ñ", "n"]]:
		out = out.replace(pair[0], pair[1])
	return out

func _run_search() -> void:
	if _league_id == -1:
		return
	var pool: Array = _pool_for_league(_league_id)

	var name_q: String = _norm(name_edit.text.strip_edges())
	var pos_code: String = _POSITIONS[pos_option.selected][0]
	var amin: int = int(age_min.value)
	var amax: int = int(age_max.value)
	var omin: int = int(ovr_min.value)
	var omax: int = int(ovr_max.value)

	var matches: Array = []
	for entry in pool:
		var p: PlayerData = entry["player"]
		if name_q != "" and not _norm(p.player_name).contains(name_q):
			continue
		if pos_code != "" and p.position != pos_code:
			continue
		if p.age < amin or p.age > amax:
			continue
		if p.overall < omin or p.overall > omax:
			continue
		matches.append(entry)
	matches.sort_custom(func(a, b): return int(a["player"].overall) > int(b["player"].overall))

	count_label.text = "%d resultado%s" % [matches.size(), "" if matches.size() == 1 else "s"]
	for c in results_box.get_children():
		c.queue_free()
	_pager = null
	if matches.is_empty():
		var e := Label.new()
		e.text = "Nadie coincide con esos filtros en esta liga."
		e.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		results_box.add_child(e)
		return
	_pager = Pager.new()
	results_box.add_child(_pager)
	_pager.show_items(matches, _RESULTS_PER_PAGE, _build_row)

func _build_row(entry: Dictionary) -> PanelContainer:
	var p: PlayerData = entry["player"]
	var club: ClubData = entry["club"]

	var panel := PanelContainer.new()
	var style := Styles.card_flat(Styles.CARD_DARK, 6)
	style.border_width_left = 4
	style.border_color = PlayerCard.tier_color(p.overall)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var crest := Styles.club_crest(club.club_id, 26)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(crest)

	var pos_lbl := Label.new()
	pos_lbl.text = Positions.broad_label(p.position)
	pos_lbl.custom_minimum_size = Vector2(76, 0)
	pos_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(pos_lbl)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_col.add_theme_constant_override("separation", 1)
	var name_lbl := Label.new()
	name_lbl.text = p.player_name
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_col.add_child(name_lbl)
	var club_lbl := Label.new()
	club_lbl.text = club.club_name
	club_lbl.clip_text = true
	club_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	club_lbl.add_theme_font_size_override("font_size", 11)
	club_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	club_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_col.add_child(club_lbl)
	hbox.add_child(name_col)

	var age_lbl := Label.new()
	age_lbl.text = "%d años" % p.age
	age_lbl.custom_minimum_size = Vector2(64, 0)
	age_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(age_lbl)

	var ov_lbl := Label.new()
	ov_lbl.text = str(p.overall)
	ov_lbl.custom_minimum_size = Vector2(32, 0)
	ov_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ov_lbl.add_theme_color_override("font_color", PlayerCard.tier_color(p.overall))
	ov_lbl.add_theme_font_override("font", Styles.font_semibold())
	ov_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(ov_lbl)

	panel.add_child(hbox)
	PlayerCard.make_clickable(panel, p, _open_player_card)
	return panel

func _open_player_card(p: PlayerData) -> void:
	PlayerCard.render(player_card_box, p)
	player_card_overlay.visible = true

## Atrás cierra primero la ficha abierta (ver Nav.back).
func nav_back() -> bool:
	if player_card_overlay.visible:
		player_card_overlay.visible = false
		return true
	return false


## HORIZONTAL: panel de filtros fijo a la izquierda (como un buscador de
## ojeador) y los resultados a todo el alto a la derecha.
func _landscape_split() -> void:
	if get_viewport_rect().size.x <= get_viewport_rect().size.y:
		return
	var vbox := $Root/VBox as VBoxContainer
	var league_row: Control = league_button.get_parent() as Control
	var filter_card: Control = name_edit.get_parent().get_parent().get_parent() as Control
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	vbox.add_child(body)
	vbox.move_child(body, league_row.get_index())
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 340
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	var t := Styles.section_label("Filtros del ojeador")
	left.add_child(t)
	league_row.reparent(left)
	filter_card.reparent(left)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sp)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	count_label.reparent(right)
	results_scroll.reparent(right)
	results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	back_button.visible = false   # hay "volver" en la barra de arriba
