extends Control

## Ficha propia del jugador con pestañas — pedido explícito ("quiero que
## entremos en la parte de las stats de los jugadores", con capturas de
## referencia de Football Legacy mostrando Stats/Atributos/Vitrina/
## Relaciones/Historia). Se entra desde CareerMenu ("Mi perfil").
##
## Alcance de ESTA versión (Historia/GOAT quedan para después, ver
## CLAUDE.md sobre no abrir más superficie de la necesaria): 4 pestañas
## con datos 100% reales, nada inventado —
##   Stats: valor de mercado (TransferMarketEngine, el jugador del
##          usuario nunca tuvo este campo poblado, se calcula en vivo
##          igual que para cualquier jugador de IA) + contadores de
##          temporada + contadores de CARRERA (PlayerData.career_goals/
##          career_assists/trophies_won, schema v12).
##   Atributos: reusa PlayerCard.render() tal cual (mismo criterio que
##          Squad/WorldExplorer — un solo lugar para pintar una carta).
##   Vitrina: trofeos de carrera + posición EN VIVO en el Balón de Oro
##          de esta temporada (WorldTickEngine.ballon_dor_ranking()).
##   Relaciones: mismas fuentes que la tarjeta de ClubInfo
##          (RivalryEngine) — clásico de club + rival de posición.
## Solo lectura, "mundo vivo": nada se persiste ni se simula acá.

@onready var name_label: Label = $Margin/VBox/NameLabel
@onready var sub_label: Label = $Margin/VBox/SubLabel
@onready var stats_tab_button: Button = $Margin/VBox/TabsRow/StatsTabButton
@onready var attrs_tab_button: Button = $Margin/VBox/TabsRow/AttrsTabButton
@onready var showcase_tab_button: Button = $Margin/VBox/TabsRow/ShowcaseTabButton
@onready var relations_tab_button: Button = $Margin/VBox/TabsRow/RelationsTabButton
@onready var detail_box: VBoxContainer = $Margin/VBox/Scroll/DetailBox
@onready var back_button: Button = $Margin/VBox/BackButton

var _player: PlayerData = null
var _world: Dictionary = {}
var _club: ClubData = null
var _tab: String = "stats"
var _show_locked_traits: bool = false
var _trait_cat: String = "todos"     # filtro del menú de rasgos
var _rpg_tab_button: Button = null   # pestaña "RPG" (se agrega por código)
var _traits_tab_button: Button = null

func _extra_tab(text: String, key: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_on_tab_pressed.bind(key))
	return b

func _ready() -> void:
	WorldTickEngine.load_runtime()
	_player = SaveManager.load_player()
	_world = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	if _player != null and _player.club_id != "":
		_club = WorldFactory.find_club(_world, _player.club_id)

	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	back_button.pressed.connect(_on_back_pressed)

	stats_tab_button.pressed.connect(_on_tab_pressed.bind("stats"))
	attrs_tab_button.pressed.connect(_on_tab_pressed.bind("attrs"))
	showcase_tab_button.pressed.connect(_on_tab_pressed.bind("showcase"))
	relations_tab_button.pressed.connect(_on_tab_pressed.bind("relations"))
	# Quinta pestaña: RPG (10-oct, Wilber: "agrega una sección en mi perfil
	# para mirar esas cosas"). Con 5 pestañas los nombres largos no entran.
	# + RASGOS aparte de Atributos (Wilber, 10-oct). Con 6 pestañas van en
	# DOS filas de 3, con los nombres completos.
	_traits_tab_button = _extra_tab("Rasgos", "traits")
	_rpg_tab_button = _extra_tab("RPG", "rpg")
	var old_row: Control = stats_tab_button.get_parent()
	var grid := GridContainer.new()
	grid.name = "TabsGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	old_row.get_parent().add_child(grid)
	old_row.get_parent().move_child(grid, old_row.get_index())
	for b in [stats_tab_button, attrs_tab_button, _traits_tab_button, showcase_tab_button, relations_tab_button, _rpg_tab_button]:
		if b.get_parent() != null:
			b.get_parent().remove_child(b)
		grid.add_child(b)
	old_row.visible = false
	var sc := $Margin/VBox/Scroll as ScrollContainer
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER

	if _player == null:
		name_label.text = "Sin jugador"
		sub_label.text = ""
		return

	name_label.text = _player.player_name
	var nick: String = Nickname.for_player(_player, SaveManager.load_world_seed())
	if nick != "":
		name_label.text = "%s  ·  «%s»" % [_player.player_name, nick]
	var club_txt: String = " — %s" % _club.club_name if _club != null else ""
	sub_label.text = "%s (%s) — %d años%s" % [
		Positions.label_of(_player.detailed_position), Positions.broad_label(_player.position), _player.age, club_txt,
	]

	_build_portrait()
	_render()
	_landscape_split()

## Cabecera héroe (9-oct, rediseño): cuerpo entero con el kit del club,
## nombre/apodo, puesto·edad·club, chips de media/potencial/valor y la
## camiseta con tu dorsal. "Editar apariencia" va debajo, a lo ancho.
func _build_portrait() -> void:
	name_label.visible = false
	sub_label.visible = false
	var accent: Color = Color(_club.primary_color_hex) if _club != null and _club.primary_color_hex != "" else Styles.BLUE
	if accent.get_luminance() > 0.8:
		accent = Styles.BLUE
	var body := Avatar.build_full(Avatar.config_for_player(_player, SaveManager.load_world_seed()), 112)
	body.custom_minimum_size = Vector2(96, 112)
	var nick: String = Nickname.for_player(_player, SaveManager.load_world_seed())
	var subtitle: String = "%s · %d años%s" % [Positions.label_of(_player.detailed_position), _player.age,
		(" · " + _club.club_name) if _club != null else ""]
	var chips: Array = [["Media %d" % _player.overall, PlayerCard.tier_color(_player.overall)],
		["Potencial %d" % _player.potential, Styles.GOLD]]
	if nick != "":
		chips.append(["«%s»" % nick, Color(0.6, 0.75, 1.0)])
	var right: Control = null
	if _club != null:
		var num: int = Kit.suggested_number(_player.position, "%s|%d" % [_player.player_name, SaveManager.load_world_seed()])
		right = Kit.build_for_club_kit(_club, WorldTickEngine.get_season_start_year(), false, 72, num)
	# Carta "Ultimate" grande (10-oct, Wilber: "mejora la carta de jugador
	# ... la de mi perfil"): la carta a la izquierda y, al lado, nombre,
	# apodo, puesto, chips y la camiseta con tu dorsal.
	body.queue_free()
	var hero := PanelContainer.new()
	var hsb := Styles.card_flat(Color(accent.darkened(0.55), 0.92), 18)
	hsb.set_border_width_all(2)
	hsb.border_color = Color(accent, 0.6)
	hsb.content_margin_left = 12
	hsb.content_margin_right = 12
	hsb.content_margin_top = 12
	hsb.content_margin_bottom = 12
	hero.add_theme_stylebox_override("panel", hsb)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 14)
	hero.add_child(hrow)
	var card := UltimateCard.build(_player, _club, 190)
	hrow.add_child(card)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	hrow.add_child(col)
	var tl := Label.new()
	tl.text = _player.player_name
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.add_theme_font_override("font", Styles.font_black())
	tl.add_theme_font_size_override("font_size", 22)
	col.add_child(tl)
	var stl := Label.new()
	stl.text = subtitle
	stl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stl.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	stl.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
	col.add_child(stl)
	var cf := HFlowContainer.new()
	cf.add_theme_constant_override("h_separation", 6)
	cf.add_theme_constant_override("v_separation", 6)
	for ch in chips:
		cf.add_child(UiKit.chip(String(ch[0]), ch[1]))
	cf.add_child(UiKit.chip("Nivel %d" % _player.level, Color(0.45, 0.8, 1.0)))
	col.add_child(cf)
	if right != null:
		right.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(right)
	var edit_btn := Button.new()
	edit_btn.text = "Editar apariencia"
	edit_btn.custom_minimum_size = Vector2(0, 44)
	edit_btn.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(edit_btn, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
	edit_btn.pressed.connect(func():
		CharacterDraft.edit_mode = true
		get_tree().change_scene_to_file("res://scenes/AvatarCreator/AvatarCreator.tscn"))
	var vbox := $Margin/VBox as VBoxContainer
	vbox.add_child(hero)
	vbox.move_child(hero, sub_label.get_index() + 1)
	vbox.add_child(edit_btn)
	vbox.move_child(edit_btn, hero.get_index() + 1)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/CareerMenu/CareerMenu.tscn")

func _on_tab_pressed(tab: String) -> void:
	_tab = tab
	_render()

func _refresh_tabs() -> void:
	var buttons: Dictionary = {
		"stats": stats_tab_button, "attrs": attrs_tab_button,
		"showcase": showcase_tab_button, "relations": relations_tab_button,
		"rpg": _rpg_tab_button, "traits": _traits_tab_button,
	}
	for key in buttons:
		var b: Button = buttons[key]
		if key == _tab:
			Styles.tab(b, true)
		else:
			Styles.tab(b, false)

func _render() -> void:
	_refresh_tabs()
	for child in detail_box.get_children():
		child.queue_free()
	if _player == null:
		return
	if _is_land() and _tab in ["attrs", "rpg", "traits"]:
		match _tab:
			"attrs": _land_attrs()
			"rpg": _land_rpg()
			"traits": _land_traits()
		UiScroll.pad_bottom(detail_box)
		return
	match _tab:
		"attrs":
			_render_attrs()
		"showcase":
			_render_showcase()
		"relations":
			_render_relations()
		"rpg":
			_render_rpg()
		"traits":
			_paginate(_render_traits_section(), 3)
		_:
			_render_stats()
	UiScroll.pad_bottom(detail_box)

func _render_stats() -> void:
	# El jugador del usuario nunca tuvo market_value poblado (ese campo
	# solo lo llena WorldFactory al generar planteles de IA) — se calcula
	# en vivo con la MISMA fórmula, nunca una segunda inventada acá.
	var value: int = _player.market_value
	if value <= 0:
		value = TransferMarketEngine.market_value(_player.overall, _player.potential, _player.age)

	detail_box.add_child(Styles.section_label("VALOR DE MERCADO"))
	var value_panel := _card(Styles.GREEN)
	var value_content: VBoxContainer = value_panel.get_child(0).get_child(0)
	value_content.add_child(_row_label("Valor estimado", CurrencyFormat.format(value)))
	detail_box.add_child(value_panel)

	detail_box.add_child(Styles.section_label("ESTA TEMPORADA"))
	var season_panel := _card(Styles.BLUE)
	var season_content: VBoxContainer = season_panel.get_child(0).get_child(0)
	var season_row := HBoxContainer.new()
	season_row.add_child(_stat_column(str(_player.season_matches_played), "Partidos"))
	season_row.add_child(_stat_column(str(_player.season_goals), "Goles"))
	season_row.add_child(_stat_column(str(_player.season_key_passes), "Asistencias"))
	season_content.add_child(season_row)
	detail_box.add_child(season_panel)

	detail_box.add_child(Styles.section_label("CARRERA"))
	var career_panel := _card(Styles.GOLD)
	var career_content: VBoxContainer = career_panel.get_child(0).get_child(0)
	var career_row := HBoxContainer.new()
	career_row.add_child(_stat_column(str(_player.career_matches), "Partidos"))
	career_row.add_child(_stat_column(str(_player.career_goals), "Goles"))
	career_row.add_child(_stat_column(str(_player.career_assists), "Asistencias"))
	career_content.add_child(career_row)
	detail_box.add_child(career_panel)

## Rasgos (schema v21): TODOS los del catálogo, con estado
## desbloqueado / bloqueado + progreso hacia el hito que lo abre.
func _render_traits_section() -> Array:
	var owned: int = 0
	for tid0 in Traits.CATALOG:
		if tid0 in _player.traits:
			owned += 1
	detail_box.add_child(Styles.section_label("RASGOS  ·  %d / %d" % [owned, Traits.CATALOG.size()]))

	# --- Slots de partido: qué rasgos llevás EQUIPADOS ---
	var slots: int = Traits.slots_for(_player.overall)
	var equipped_now: Array = Traits.active(_player)
	var is_auto: bool = _player.equipped_traits.is_empty()
	var slot_line := Label.new()
	var nxt: int = Traits.next_slot_overall(_player.overall)
	var tail: String = ("  ·  4º slot a media %d" % nxt) if nxt > 0 else "  ·  4 slots abiertos"
	if nxt > 0 and slots < 4:
		tail = "  ·  próximo slot a media %d" % nxt
	slot_line.text = "Equipados en partido: %d / %d%s%s" % [
		equipped_now.size(), slots, tail, ("   (auto)" if is_auto else "")]
	slot_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_line.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	slot_line.add_theme_color_override("font_color", Styles.GOLD)
	detail_box.add_child(slot_line)
	if owned > slots:
		var hint := Label.new()
		hint.text = "Tenés más rasgos que slots — elegí cuáles entran con “Equipar”."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		hint.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		detail_box.add_child(hint)

	# --- MENÚ NUEVO (10-oct): los slots a la vista, lo que suman y filtro ---
	detail_box.add_child(_trait_slots_row(equipped_now, slots))
	var summary: Array = Traits.active_summary(_player)
	if not summary.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		for row in summary:
			flow.add_child(UiKit.chip("%s +%.1f%%" % [String(row[0]), float(row[1]) * 100.0], Styles.GREEN))
		detail_box.add_child(flow)
	var cats := HFlowContainer.new()
	cats.add_theme_constant_override("h_separation", 6)
	cats.add_theme_constant_override("v_separation", 6)
	var cat_list: Array = [["todos", "Todos"]]
	cat_list.append_array(Traits.CATEGORIES)
	for c in cat_list:
		var n_cat: int = 0
		var n_own: int = 0
		for tid1 in Traits.CATALOG:
			if String(c[0]) == "todos" or Traits.category_of(String(tid1)) == String(c[0]):
				n_cat += 1
				if tid1 in _player.traits:
					n_own += 1
		var cb := Button.new()
		cb.text = "%s %d/%d" % [String(c[1]), n_own, n_cat]
		cb.focus_mode = Control.FOCUS_NONE
		cb.custom_minimum_size = Vector2(0, 34)
		cb.add_theme_font_size_override("font_size", 12)
		Styles.tab(cb, _trait_cat == String(c[0]), true)
		var cid: String = String(c[0])
		cb.pressed.connect(func():
			_trait_cat = cid
			_render())
		cats.add_child(cb)
	detail_box.add_child(cats)

	# Los que ya tenés primero.
	var ids: Array = Traits.CATALOG.keys()
	ids.sort_custom(func(a, b):
		var ga: bool = a in _player.traits
		var gb: bool = b in _player.traits
		if ga != gb:
			return ga
		return false)
	var locked_total: int = Traits.CATALOG.size() - owned

	if locked_total > 0:
		var toggle := Button.new()
		toggle.text = "Ocultar bloqueados" if _show_locked_traits else "Ver %d rasgos bloqueados" % locked_total
		toggle.custom_minimum_size = Vector2(0, 40)
		toggle.focus_mode = Control.FOCUS_NONE
		Styles.styled_button(toggle, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
		toggle.pressed.connect(func():
			_show_locked_traits = not _show_locked_traits
			_render())
		detail_box.add_child(toggle)

	# Devuelve los builders de tarjeta de rasgo — se paginan JUNTO a los de
	# atributos en un solo ◀▶ (pedido de Wilber: "lo mismo que en las tablas").
	var builders: Array = []
	for tid in ids:
		if _trait_cat != "todos" and Traits.category_of(String(tid)) != _trait_cat:
			continue
		if (tid in _player.traits) or _show_locked_traits:
			builders.append(func(t = tid) -> Control: return _trait_card(String(t)))
	return builders

## Fila de SLOTS de partido: los rasgos equipados con su medalla, los
## vacíos y los que todavía no abriste (con la media que piden).
func _trait_slots_row(equipped_now: Array, slots: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i in range(Traits.MAX_MATCH_SLOTS):
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var open: bool = i < slots
		var filled: bool = i < equipped_now.size()
		var sb := Styles.card_flat(Color(1, 0.85, 0.3, 0.14) if filled else Color(1, 1, 1, 0.05), 12)
		sb.set_border_width_all(2)
		sb.border_color = Styles.GOLD if filled else (Color(1, 1, 1, 0.18) if open else Color(1, 1, 1, 0.06))
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		cell.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		var cc := CenterContainer.new()
		var cap := Label.new()
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_font_size_override("font_size", 10)
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap.custom_minimum_size = Vector2(70, 0)
		if filled:
			cc.add_child(TraitBadge.build(String(equipped_now[i]), 40))
			cap.text = Traits.name_of(String(equipped_now[i]))
		elif open:
			var plus := Label.new()
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", 26)
			plus.add_theme_color_override("font_color", Styles.GRAY_TEXT)
			plus.custom_minimum_size = Vector2(40, 40)
			plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cc.add_child(plus)
			cap.text = "Libre"
			cap.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		else:
			var lock := Label.new()
			lock.text = "🔒"
			lock.custom_minimum_size = Vector2(40, 40)
			lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cc.add_child(lock)
			cap.text = "Media %d" % int(Traits.SLOT_UNLOCK_OVERALL[i])
			cap.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		v.add_child(cc)
		v.add_child(cap)
		cell.add_child(v)
		row.add_child(cell)
	return row

## Tarjeta de un rasgo (equipado / desbloqueado / bloqueado + progreso).
func _trait_card(tid: String) -> Control:
	var got: bool = tid in _player.traits
	var slots: int = Traits.slots_for(_player.overall)
	var equipped_now: Array = Traits.active(_player)
	var rules_by_id: Dictionary = {}
	for r in TraitEngine.RULES:
		rules_by_id[String(r["id"])] = r
	var cat_label: String = ""
	for c in Traits.CATEGORIES:
		if String(c[0]) == Traits.category_of(tid):
			cat_label = String(c[1])

	var panel := _card(Styles.PURPLE if got else Styles.CARD_DARK)
	var v: VBoxContainer = panel.get_child(0).get_child(0)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var badge := TraitBadge.build(tid, 38, not got)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(badge)
	var n := Label.new()
	n.text = Traits.name_of(tid)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.add_theme_font_override("font", Styles.font_semibold())
	if not got:
		n.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	top.add_child(n)
	if got:
		var equipped: bool = tid in equipped_now
		var eb := Button.new()
		eb.focus_mode = Control.FOCUS_NONE
		eb.custom_minimum_size = Vector2(0, 30)
		if equipped:
			eb.text = "Equipado ✓"
			Styles.styled_button(eb, Styles.pill_filled(Styles.GOLD), Color.BLACK)
		elif equipped_now.size() >= slots:
			eb.text = "Sin slot"
			eb.disabled = true
			Styles.styled_button(eb, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
		else:
			eb.text = "Equipar"
			Styles.styled_button(eb, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
		eb.pressed.connect(func(): _toggle_equip(tid))
		top.add_child(eb)
	else:
		var lock_lbl := Label.new()
		lock_lbl.text = "🔒"
		lock_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		top.add_child(lock_lbl)
	v.add_child(top)

	var d := Label.new()
	d.text = ("[%s]  " % cat_label if cat_label != "" else "") + Traits.desc_of(tid)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	d.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	v.add_child(d)

	if not got and rules_by_id.has(tid):
		var rule: Dictionary = rules_by_id[tid]
		var cur: int = TraitEngine.progress(_player, String(rule["check"]))
		var need: int = int(rule["min"])
		var pos_txt: String = ""
		if rule.has("pos"):
			pos_txt = "  ·  Posición: %s" % "/".join(rule["pos"] as Array)
		if rule.has("max_age"):
			pos_txt += "  ·  antes de los %d años" % (int(rule["max_age"]) + 1)
		var prog := Label.new()
		prog.text = "%s  ·  %d / %d%s" % [TraitEngine.check_label(String(rule["check"])), mini(cur, need), need, pos_txt]
		prog.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		prog.add_theme_color_override("font_color", Styles.AMBER)
		v.add_child(prog)
		var track := ColorRect.new()
		track.color = Color(1, 1, 1, 0.08)
		track.custom_minimum_size = Vector2(0, 6)
		var fill := ColorRect.new()
		fill.color = Styles.AMBER
		fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
		fill.anchor_right = clampf(float(cur) / float(maxi(need, 1)), 0.0, 1.0)
		fill.anchor_bottom = 1.0
		track.add_child(fill)
		v.add_child(track)
	return panel

## Equipa / desequipa un rasgo para el partido. Al tocar por primera vez se
## "materializa" el auto (los primeros N) para que el cambio sea explícito.
func _toggle_equip(tid: String) -> void:
	var slots: int = Traits.slots_for(_player.overall)
	var eq: Array = _player.equipped_traits.duplicate()
	if eq.is_empty():
		eq = Traits.active(_player).duplicate()
	if tid in eq:
		eq.erase(tid)
	elif eq.size() < slots:
		eq.append(tid)
	# Nunca dejar ids no desbloqueados o de más.
	eq = eq.filter(func(x): return x in _player.traits)
	_player.equipped_traits = eq
	SaveManager.save_player(_player)
	_render()

func _trait_progress(check: String) -> int:
	match check:
		"goals": return _player.career_goals
		"assists": return _player.career_assists
		"matches", "matches_def": return _player.career_matches
		"trophies": return _player.trophies_won
		"reputation": return _player.reputation
		_: return 0

func _trait_cond_label(check: String) -> String:
	match check:
		"goals": return "Goles de carrera"
		"assists": return "Asistencias de carrera"
		"matches", "matches_def": return "Partidos de carrera"
		"trophies": return "Títulos como titular"
		"reputation": return "Reputación"
		_: return "Progreso"

## Atributos estilo EA FC (pedido explícito con captura de referencia):
## 6 categorías (RIT/TIR/PAS/REG/DEF/FÍS) con número grande + barra de
## color arriba, y una tarjeta por categoría con los atributos REALES del
## juego que la alimentan (el juego tiene 9 atributos, no los ~30 de FIFA).
const _ATTR_CATS := [
	{"key": "RIT", "name": "Ritmo", "subs": [["Velocidad", "speed"], ["Resistencia", "stamina"]]},
	{"key": "TIR", "name": "Tiros", "subs": [["Finalización", "shooting"], ["Compostura", "composure"]]},
	{"key": "PAS", "name": "Pases", "subs": [["Precisión de pase", "passing"], ["Visión", "decision_making"]]},
	{"key": "REG", "name": "Regates", "subs": [["Regate", "dribbling"], ["Control del balón", "control"]]},
	{"key": "DEF", "name": "Defensa", "subs": [["Lectura de juego", "decision_making"], ["Fuerza en el duelo", "strength"]]},
	{"key": "FÍS", "name": "Físico", "subs": [["Fuerza", "strength"], ["Resistencia", "stamina"], ["Liderazgo", "leadership"]]},
]

## Delega en PlayerDevelopment.card_stat — ÚNICA fuente (antes duplicada
## acá y en PlayerCard.gd, ver cabecera de esa función).
func _cat_value(key: String) -> int:
	if key in PlayerDevelopment.CARD_STAT_KEYS:
		return PlayerDevelopment.card_stat(_player, key)
	return 50

func _attr_color(v: int) -> Color:
	if v >= 75:
		return Styles.GREEN
	if v >= 55:
		return Styles.AMBER
	return Styles.RED

func _attr_bar(v: int, width_hint: float = 220.0) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width_hint, 6)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.10)
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(track)
	var fill := ColorRect.new()
	fill.color = _attr_color(v)
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.anchor_left = 0.0
	fill.anchor_right = clampf(v / 100.0, 0.03, 1.0)
	holder.add_child(fill)
	return holder

func _render_attrs() -> void:
	if _player == null:
		return
	# RASGOS: header/slots fijos + tarjetas (builders); ATRIBUTOS: resumen +
	# tarjeta por categoría. Todo en UN SOLO ◀▶ (pedido de Wilber).
	# Los RASGOS tienen su propia pestaña desde el 10-oct.
	var builders: Array = []
	detail_box.add_child(Styles.section_label("ATRIBUTOS"))
	builders.append(Callable(self, "_attr_summary_block"))
	for cat in _ATTR_CATS:
		builders.append(func(c = cat) -> Control: return _attr_cat_card(c))
	_paginate(builders, 3)

## Nota + fila-resumen de las 6 categorías (RIT/TIR/…). Bloque 1 del pager.
func _attr_summary_block() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var note := Label.new()
	note.text = "Cada atributo junta XP hacia su siguiente +1. Sube entrenando el foco que lo alimenta (Físico / Técnico / Mental) y jugando partidos — cuanto mejor tu nota, más XP recibís."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	note.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	box.add_child(note)
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", Styles.card(Styles.CARD_DARK, 12))
	var tm := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		tm.add_theme_constant_override("margin_" + s, 12)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 6)
	for cat in _ATTR_CATS:
		var v: int = _cat_value(cat["key"])
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		var num := Label.new()
		num.text = str(v)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.add_theme_font_override("font", Styles.font_black())
		num.add_theme_font_size_override("font_size", 20)
		num.add_theme_color_override("font_color", _attr_color(v))
		var cap := Label.new()
		cap.text = cat["key"]
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		cap.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		col.add_child(num)
		col.add_child(cap)
		col.add_child(_attr_bar(v, 40.0))
		trow.add_child(col)
	tm.add_child(trow)
	top.add_child(tm)
	box.add_child(top)
	return box

## Tarjeta de una categoría (Ritmo/Tiros/…) con sus sub-atributos + barra XP.
func _attr_cat_card(cat: Dictionary) -> Control:
	var v: int = _cat_value(cat["key"])
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Styles.card_accent(_attr_color(v)))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 14)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	var hn := Label.new()
	hn.text = String(cat["name"]).to_upper()
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hn.add_theme_font_override("font", Styles.font_semibold())
	hn.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	hn.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	var hv := Label.new()
	hv.text = str(v)
	hv.add_theme_font_override("font", Styles.font_black())
	hv.add_theme_color_override("font_color", _attr_color(v))
	head.add_child(hn)
	head.add_child(hv)
	cv.add_child(head)
	var seen_attr := {}
	for sub in cat["subs"]:
		var attr_key: String = String(sub[1])
		var sv: int = int(_player.get(attr_key))
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 8)
		var sl := Label.new()
		sl.text = String(sub[0])
		sl.custom_minimum_size = Vector2(105 if _is_land() else 150, 0)
		sl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		var sb := _attr_bar(sv, 90.0 if _is_land() else 220.0)
		var snum := Label.new()
		snum.text = str(sv)
		snum.custom_minimum_size = Vector2(28, 0)
		snum.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		snum.add_theme_font_override("font", Styles.font_semibold())
		snum.add_theme_color_override("font_color", _attr_color(sv))
		srow.add_child(sl)
		srow.add_child(sb)
		srow.add_child(snum)
		cv.add_child(srow)
		if not seen_attr.has(attr_key):
			seen_attr[attr_key] = true
			cv.add_child(_attr_xp_line(attr_key, sv))
	m.add_child(cv)
	card.add_child(m)
	return card

## Lista paginada genérica para las pestañas de Mi Perfil — mismo criterio
## ◀▶ que el resto del juego (el scroll táctil se sentía mal). `builders`:
## Array de Callable() -> Control, uno por sección; se reconstruyen al
## cambiar de hoja.
func _paginate(builders: Array, per: int) -> void:
	var pager := Pager.new()
	detail_box.add_child(pager)
	pager.show_items(builders, per, func(b: Callable) -> Control: return b.call())

## Una línea fina bajo cada atributo: barra de XP + "faltan N · entrená X".
## Es lo que Wilber pidió: saber cuánto falta para subir y qué entrenar.
func _attr_xp_line(attr_key: String, value: int) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 1)
	var need: int = PlayerDevelopment.xp_needed(value, _player.growth_difficulty if _player != null else "normal")
	var have: float = clampf(float(_player.attribute_xp.get(attr_key, 0.0)), 0.0, float(need))
	var cap: int = PlayerDevelopment.attr_cap(_player)

	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.06)
	track.custom_minimum_size = Vector2(0, 4)
	track.clip_contents = true
	var fill := ColorRect.new()
	fill.color = Styles.BLUE
	fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(have / float(maxi(need, 1)), 0.0, 1.0)
	track.add_child(fill)
	wrap.add_child(track)

	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 10)
	if value >= cap:
		lbl.text = "Al tope (%d) — no sube más por ahora" % cap
		lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		fill.anchor_right = 1.0
		fill.color = Styles.GRAY_TEXT
	else:
		var focus: String = PlayerDevelopment.attr_focus(attr_key)
		var flabel: String = PlayerDevelopment.focus_label(focus)
		lbl.text = "%d / %d XP  ·  faltan %d  ·  entrená %s" % [
			int(round(have)), need, maxi(0, need - int(round(have))), flabel]
		lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	wrap.add_child(lbl)
	return wrap

func _render_showcase() -> void:
	var titles: Array = _player.career_titles
	var groups := {"team": [], "continental": [], "world": [], "individual": []}
	for t in titles:
		var k: String = String(t.get("kind", "team"))
		if not groups.has(k):
			k = "team"
		groups[k].append(t)

	var group_meta := [
		["team", "TÍTULOS DE EQUIPO", Styles.GOLD],
		["continental", "COPAS CONTINENTALES", Styles.BLUE],
		["world", "MUNDIALES", Styles.PURPLE],
		["individual", "HONORES INDIVIDUALES", Styles.GREEN],
	]
	var builders: Array = []
	for gm in group_meta:
		var arr: Array = (groups[gm[0]] as Array)
		if arr.is_empty():
			continue
		arr = arr.duplicate()
		arr.sort_custom(func(a, b): return int(a.get("season", 0)) > int(b.get("season", 0)))
		builders.append(func(g = gm, a2 = arr) -> Control: return _showcase_group_card(String(g[1]), g[2], a2))

	# Compat: saves previos a v20 solo tienen el contador agregado.
	var legacy: int = maxi(0, _player.trophies_won - titles.size())
	if legacy > 0:
		builders.append(func(n = legacy) -> Control: return _showcase_legacy_card(n))

	# Balón de Oro EN VIVO (posición de esta temporada).
	builders.append(Callable(self, "_showcase_ballon_dor_card"))

	if builders.size() == 1 and legacy == 0 and titles.is_empty():
		detail_box.add_child(Styles.section_label("VITRINA DE TROFEOS"))
		var e_panel := _card(Styles.GOLD)
		(e_panel.get_child(0).get_child(0) as VBoxContainer).add_child(_row_label("Palmarés", "Todavía sin títulos"))
		detail_box.add_child(e_panel)

	detail_box.add_child(_trophy_room(titles))
	_paginate(builders, 1)

## SALA DE TROFEOS 3D (1-nov, pedido de Wilber: "las locaciones que tiene el juego
## como la zona de trofeos"): vitrina de madera con cada título en 3D, parecido a su
## dibujo pixel (TrophyBuilder + TrophySpecs), las más recientes primero (hasta 18).
func _trophy_room(titles: Array) -> Control:
	var arr: Array = titles.duplicate()
	arr.sort_custom(func(a, b): return int(a.get("season", 0)) > int(b.get("season", 0)))
	var entries: Array = []
	for t in arr.slice(0, 18):
		var key: String = HonorsEngine.trophy_key_for(t)
		entries.append({"id": key if key != "" else String(t.get("id", "cup")),
			"label": "%s %d" % [String(t.get("name", "")), int(t.get("season", 0))]})
	return TrophyRoom.make_view(entries, Vector2(0, 300), "Vitrina de " + _player.player_name)

## Versión pixel de la sala (antes del 3D): se deja por si hace falta volver.
func _trophy_room_2d(titles: Array) -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 250)
	stage.clip_contents = true
	var bg := TextureRect.new()
	if ResourceLoader.exists("res://assets/scenes/trophy_room.png"):
		bg.texture = load("res://assets/scenes/trophy_room.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(bg)
	var shelf := HBoxContainer.new()
	shelf.alignment = BoxContainer.ALIGNMENT_CENTER
	shelf.add_theme_constant_override("separation", 2)
	shelf.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shelf.offset_top = -96
	shelf.offset_bottom = -26
	stage.add_child(shelf)
	var sorted: Array = titles.duplicate()
	sorted.sort_custom(func(a, b): return int(a.get("season", 0)) > int(b.get("season", 0)))
	for t in sorted.slice(0, 10):
		var tro: Control = Trophy.for_entry(t, 52)
		if tro != null:
			tro.custom_minimum_size = Vector2(52, 64)
			shelf.add_child(tro)
	var cap := Label.new()
	cap.text = "SALA DE TROFEOS · %d" % titles.size() if not titles.is_empty() else "SALA DE TROFEOS · vacía, por ahora"
	cap.add_theme_font_override("font", Styles.font_black())
	cap.add_theme_font_size_override("font_size", 14)
	cap.add_theme_color_override("font_color", Styles.GOLD)
	cap.add_theme_color_override("font_outline_color", Color.BLACK)
	cap.add_theme_constant_override("outline_size", 6)
	cap.position = Vector2(12, 8)
	stage.add_child(cap)
	return stage

func _showcase_group_card(title: String, accent: Color, arr: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(Styles.section_label("%s (%d)" % [title, arr.size()]))
	var panel := _card(accent)
	var content: VBoxContainer = panel.get_child(0).get_child(0)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	for e in arr:
		grid.add_child(_title_cell(e))
	content.add_child(grid)
	box.add_child(panel)
	return box

func _showcase_legacy_card(legacy: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(Styles.section_label("TÍTULOS ANTERIORES (%d)" % legacy))
	var lpanel := _card(Styles.GOLD)
	var lcontent: VBoxContainer = lpanel.get_child(0).get_child(0)
	lcontent.add_child(_row_label("Ganados antes de registrar el detalle", str(legacy)))
	var lgrid := GridContainer.new()
	lgrid.columns = 6
	lgrid.add_theme_constant_override("h_separation", 6)
	lgrid.add_theme_constant_override("v_separation", 6)
	for i in range(mini(legacy, 24)):
		var lt := Trophy.generic("%s#%d" % [_player.player_name, i], 40)
		lt.custom_minimum_size = Vector2(40, 46)
		lgrid.add_child(lt)
	lcontent.add_child(lgrid)
	box.add_child(lpanel)
	return box

func _showcase_ballon_dor_card() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(Styles.section_label("BALÓN DE ORO"))
	var bd_panel := _card(Styles.PURPLE)
	var bd_content: VBoxContainer = bd_panel.get_child(0).get_child(0)
	var loading: HBoxContainer = _row_label("Posición actual", "calculando…")
	bd_content.add_child(loading)
	box.add_child(bd_panel)
	_fill_ballon_dor.call_deferred(bd_content, loading)
	return box

## Celda de un título: trofeo + nombre + temporada.
func _title_cell(entry: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 3)
	var node: Control = Trophy.for_entry(entry, 52)
	node.custom_minimum_size = Vector2(52, 58)
	var wrap := CenterContainer.new()
	wrap.add_child(node)
	col.add_child(wrap)
	var nm := Label.new()
	nm.text = String(entry.get("name", "Título"))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.add_theme_font_size_override("font_size", 11)
	# Ancho mínimo: con 52 px "Eredivisie" se partía letra por letra.
	nm.custom_minimum_size = Vector2(96, 0)
	col.add_child(nm)
	var yr := Label.new()
	yr.text = "%d/%02d" % [int(entry.get("season", 0)), (int(entry.get("season", 0)) + 1) % 100]
	yr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yr.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	yr.add_theme_font_size_override("font_size", 9)
	col.add_child(yr)
	return col

func _fill_ballon_dor(bd_content: Node, loading: Node) -> void:
	if not is_instance_valid(bd_content) or _player == null:
		return
	var ranking: Array = WorldTickEngine.ballon_dor_ranking()
	var my_club_name: String = _club.club_name if _club != null else ""
	var found_idx: int = -1
	for i in range(ranking.size()):
		if String(ranking[i].get("name", "")) == _player.player_name and String(ranking[i].get("club_name", "")) == my_club_name:
			found_idx = i
			break
	if is_instance_valid(loading):
		loading.queue_free()
	if found_idx == -1:
		bd_content.add_child(_row_label("Posición actual", "Sin puntos todavía"))
	else:
		var row: Dictionary = ranking[found_idx]
		bd_content.add_child(_row_label("Posición actual", "%d° de %d" % [found_idx + 1, ranking.size()]))
		bd_content.add_child(_row_label("Puntaje", "%.1f" % float(row.get("score", 0.0))))

func _render_relations() -> void:
	if _club == null:
		detail_box.add_child(Styles.section_label("Sin club"))
		return

	var rival_id: String = RivalryEngine.club_rival_for(_world, _club.club_id, WorldTickEngine.world_seed)
	var rival_club: ClubData = WorldFactory.find_club(_world, rival_id) if rival_id != "" else null

	var meta: Dictionary = _world.get("club_meta_by_id", {})
	var position_rival: Dictionary = {}
	if meta.has(_club.club_id):
		var season_start: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
		var squad: Array[PlayerData] = WorldFactory.make_squad_with_transfers(_world, _club.club_id, WorldTickEngine.world_seed, season_start)
		position_rival = RivalryEngine.position_rival_for(_player, squad)

	var rc_name: String = rival_club.club_name if rival_club != null else ""
	# RIVAL PERSONAL (10-oct, ImmersionEngine): quien más te marca.
	var nemesis: Dictionary = {}
	var nem_club_id: String = ImmersionEngine.nemesis_club_id(_world, _club.club_id, WorldTickEngine.world_seed)
	if nem_club_id != "" and meta.has(nem_club_id):
		var ss: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
		nemesis = ImmersionEngine.pick_nemesis(WorldFactory.make_squad_with_transfers(_world, nem_club_id, WorldTickEngine.world_seed, ss), _player.position)
		if not nemesis.is_empty():
			var nc: ClubData = WorldFactory.find_club(_world, nem_club_id)
			nemesis["club"] = nc.short_name if nc != null else ""
			nemesis["rec"] = ImmersionEngine.nemesis_record(_player.nemesis_log)
	var builders: Array = [func() -> Control:
		# QUÍMICA con el plantel (P5).
		var cbox := VBoxContainer.new()
		cbox.add_theme_constant_override("separation", 6)
		cbox.add_child(Styles.section_label("QUÍMICA CON EL PLANTEL"))
		var cpanel := _card(Styles.GREEN)
		var cc: VBoxContainer = cpanel.get_child(0).get_child(0)
		var chem: int = SocialLifeEngine.chemistry(_player, WorldTickEngine.season)
		var crow := HBoxContainer.new()
		crow.add_theme_constant_override("separation", 10)
		var cic := Icons.make_rect("res://assets/ui/chemistry.png", 44)
		cic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		crow.add_child(cic)
		var ccol := VBoxContainer.new()
		ccol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ct := Label.new()
		ct.text = "%s · %d/100" % [SocialLifeEngine.chemistry_label(chem), chem]
		ct.add_theme_font_override("font", Styles.font_black())
		ccol.add_child(ct)
		var cbar := ProgressBar.new()
		cbar.show_percentage = false
		cbar.custom_minimum_size = Vector2(0, 10)
		cbar.max_value = 100
		var fg := StyleBoxFlat.new()
		fg.bg_color = Styles.GREEN
		fg.set_corner_radius_all(5)
		var bgs := StyleBoxFlat.new()
		bgs.bg_color = Color(1, 1, 1, 0.08)
		bgs.set_corner_radius_all(5)
		cbar.add_theme_stylebox_override("fill", fg)
		cbar.add_theme_stylebox_override("background", bgs)
		ccol.add_child(cbar)
		cbar.create_tween().tween_property(cbar, "value", float(chem), 0.6)
		var ch := Label.new()
		ch.text = "Sube jugando con ellos y con las noches de videojuegos. Con más química, tus pases tienen más zona verde."
		ch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ch.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		ch.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		ccol.add_child(ch)
		crow.add_child(ccol)
		cc.add_child(crow)
		cbox.add_child(cpanel)
		return cbox]
	if rival_club == null and position_rival.is_empty() and nemesis.is_empty():
		_paginate(builders, 2)
		return
	builders.append(func() -> Control:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.add_child(Styles.section_label("RIVALIDADES"))
		var panel := _card(Styles.RED)
		var content: VBoxContainer = panel.get_child(0).get_child(0)
		if rc_name != "":
			content.add_child(_row_label("Clásico de club", rc_name))
		if not position_rival.is_empty():
			content.add_child(_row_label(
				"%s (%d/100)" % [String(position_rival["reason"]), int(position_rival["intensity"])],
				"%s — OVR %d" % [String(position_rival["name"]), int(position_rival["overall"])],
			))
		if not nemesis.is_empty():
			var nrow := HBoxContainer.new()
			nrow.add_theme_constant_override("separation", 10)
			nrow.add_child(Styles.portrait_frame(Avatar.build(Avatar.with_expression(Avatar.config_for_npc(String(nemesis["name"]), "player", WorldTickEngine.world_seed), "enojado"), 44), 44, Styles.RED))
			var ncol := VBoxContainer.new()
			ncol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var nt := Label.new()
			nt.text = "Rival personal: %s" % String(nemesis["name"])
			nt.add_theme_font_override("font", Styles.font_semibold())
			ncol.add_child(nt)
			var rec: Dictionary = nemesis["rec"]
			var ns := Label.new()
			ns.text = "%s · %s · OVR %d · %s" % [String(nemesis["detailed"]), String(nemesis["club"]), int(nemesis["overall"]),
				("todavía sin cruces" if int(rec["played"]) == 0 else "historial %dG %dE %dP" % [int(rec["won"]), int(rec["draw"]), int(rec["lost"])])]
			ns.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ns.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
			ns.add_theme_color_override("font_color", Styles.GRAY_TEXT)
			ncol.add_child(ns)
			nrow.add_child(ncol)
			content.add_child(nrow)
		box.add_child(panel)
		return box)
	_paginate(builders, 2)

# --- Helpers de tarjeta, mismo criterio visual que ClubInfo.gd ---


func _card(accent: Color = Color.TRANSPARENT) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card() if accent.a <= 0 else Styles.card_accent(accent))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	panel.add_child(margin)
	return panel

func _row_label(key: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var key_lbl := Label.new()
	key_lbl.text = key
	key_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_lbl)
	var value_lbl := Label.new()
	value_lbl.text = value
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_lbl)
	return row

func _stat_column(value: String, label: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var value_lbl := Label.new()
	value_lbl.text = value
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.add_theme_font_size_override("font_size", 22)
	col.add_child(value_lbl)
	var caption_lbl := Label.new()
	caption_lbl.text = label
	caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	caption_lbl.add_theme_font_size_override("font_size", 12)
	col.add_child(caption_lbl)
	return col


# =====================================================================
#  Pestaña RPG (10-oct): rango, arquetipo, maestrías, festejo de firma y
#  logros. Solo lectura de CareerRpgEngine — acá no hay matemática.
# =====================================================================

func _render_rpg() -> void:
	var builders: Array = [
		Callable(self, "_rpg_rank_card"),
		Callable(self, "_rpg_mastery_card"),
		Callable(self, "_rpg_celebration_card"),
	]
	# Logros: primero los que están más cerca de cumplirse, al final los cobrados.
	var list: Array = CareerRpgEngine.ACHIEVEMENTS.duplicate()
	list.sort_custom(func(a, b):
		var ca: bool = CareerRpgEngine.is_claimed(_player, String(a["id"]))
		var cb: bool = CareerRpgEngine.is_claimed(_player, String(b["id"]))
		if ca != cb:
			return not ca
		var pa: float = float(CareerRpgEngine.value_of(_player, String(a["check"]))) / float(maxi(int(a["min"]), 1))
		var pb: float = float(CareerRpgEngine.value_of(_player, String(b["check"]))) / float(maxi(int(b["min"]), 1))
		return pa > pb)
	for i in range(0, list.size(), 5):
		var chunk: Array = list.slice(i, i + 5)
		builders.append(func(ch = chunk, first = (i == 0)) -> Control: return _rpg_achievements_block(ch, first))
	_paginate(builders, 1)

func _rpg_bar(frac: float, col: Color, h: float = 8.0) -> Control:
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.08)
	track.custom_minimum_size = Vector2(0, h)
	var fill := ColorRect.new()
	fill.color = col
	fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(frac, 0.0, 1.0)
	track.add_child(fill)
	return track

## `wrap` = false para etiquetas cortas al costado de otra dentro de una
## fila: con ajuste de línea y sin ancho propio se partían LETRA POR LETRA a
## ancho de celular ("Nivel 3 / 10" en vertical — bug que vio Wilber).
func _rpg_text(text: String, size: int, col: Color = Color.WHITE, heavy: bool = false, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if heavy:
		l.add_theme_font_override("font", Styles.font_black())
	return l

## RANGO + nivel + ARQUETIPO.
func _rpg_rank_card() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(Styles.section_label("TU CARRERA"))
	var panel := _card(Styles.GOLD)
	var c: VBoxContainer = panel.get_child(0).get_child(0)
	c.add_child(_rpg_text(CareerRpgEngine.rank_name(_player.level).to_upper(), 24, Styles.GOLD, true))
	var need: int = ProgressionEngine.xp_to_next(_player.level)
	c.add_child(_rpg_text("Nivel %d  ·  %d / %d XP" % [_player.level, _player.career_xp, need], Styles.SIZE_LABEL))
	c.add_child(_rpg_bar(float(_player.career_xp) / float(maxi(need, 1)), Styles.GOLD))
	var nr: Array = CareerRpgEngine.next_rank(_player.level)
	if String(nr[0]) != "":
		c.add_child(_rpg_text("Próximo rango: %s (nivel %d)" % [String(nr[0]), int(nr[1])], Styles.SIZE_CAPTION, Styles.GRAY_TEXT))
	else:
		c.add_child(_rpg_text("Ya sos una leyenda: no hay rango más alto.", Styles.SIZE_CAPTION, Styles.GRAY_TEXT))
	var f: int = ProgressionEngine.form(_player)
	c.add_child(_row_label("Puntos de habilidad sin gastar", str(_player.skill_points)))
	# Entrada SIEMPRE visible al árbol (10-oct, Wilber: "¿cómo llego a esta
	# pantalla de habilidades?"): antes solo aparecía con puntos sin gastar.
	var sk_btn := Button.new()
	sk_btn.text = "Abrir árbol de habilidades  ›"
	sk_btn.custom_minimum_size = Vector2(0, 46)
	sk_btn.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(sk_btn, Styles.pill_filled(Styles.GOLD) if _player.skill_points > 0 else Styles.pill_outlined(Styles.GOLD), Color.BLACK if _player.skill_points > 0 else Styles.GOLD)
	sk_btn.pressed.connect(func():
		SkillsPanel.open(self).closed.connect(func():
			_player = SaveManager.load_player()
			_render()))   # _render limpia la pestaña antes de redibujar (con _render_rpg directo quedaba duplicada)
	c.add_child(sk_btn)
	c.add_child(_row_label("Forma", "%s %s" % [ProgressionEngine.FORM_ARROWS[f], ProgressionEngine.FORM_NAMES[f]]))
	c.add_child(_row_label("Logros", "%d / %d" % [CareerRpgEngine.achievements_done(_player), CareerRpgEngine.ACHIEVEMENTS.size()]))
	c.add_child(_row_label("Rasgos", "%d / %d" % [_player.traits.size(), Traits.CATALOG.size()]))
	box.add_child(panel)

	var arch: Dictionary = CareerRpgEngine.archetype(_player)
	var ap := _card(Styles.PURPLE)
	var ac: VBoxContainer = ap.get_child(0).get_child(0)
	ac.add_child(_rpg_text("ARQUETIPO", 11, Styles.PURPLE, true))
	ac.add_child(_rpg_text("%s  ·  %s %d" % [String(arch["name"]), String(arch["key"]), int(arch["value"])], 18, Color.WHITE, true))
	ac.add_child(_rpg_text(String(arch["desc"]), Styles.SIZE_LABEL, Styles.GRAY_TEXT))
	ac.add_child(_rpg_text("Sale de tu atributo de carta más alto: si entrenás otra cosa, cambia.", Styles.SIZE_CAPTION, Styles.GRAY_TEXT))
	box.add_child(ap)
	return box

## MAESTRÍAS: suben con lo que hacés en los partidos.
func _rpg_mastery_card() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(Styles.section_label("MAESTRÍAS"))
	box.add_child(_rpg_text("Suben solas con lo que hacés en partidos oficiales. Cada nivel da +0,4% permanente a esa rama (máximo +4%).", Styles.SIZE_CAPTION, Styles.GRAY_TEXT))
	for b in CareerRpgEngine.MASTERY:
		var info: Dictionary = CareerRpgEngine.MASTERY[b]
		var col: Color = Color(String(info["color"]))
		var lv: int = CareerRpgEngine.mastery_level(_player, String(b))
		var pr: Array = CareerRpgEngine.mastery_progress(_player, String(b))
		var panel := _card(col)
		var c: VBoxContainer = panel.get_child(0).get_child(0)
		var head := HBoxContainer.new()
		var n := _rpg_text(String(info["name"]), 17, col, true)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(n)
		head.add_child(_rpg_text("Nivel %d / 10" % lv, Styles.SIZE_LABEL, Color.WHITE, false, false))
		c.add_child(head)
		if int(pr[1]) > 0:
			c.add_child(_rpg_bar(float(pr[0]) / float(pr[1]), col))
			c.add_child(_rpg_text("%d / %d %s para el próximo nivel  ·  total %d" % [int(pr[0]), int(pr[1]), String(info["what"]), CareerRpgEngine.mastery_count(_player, String(b))], Styles.SIZE_CAPTION, Styles.GRAY_TEXT))
		else:
			c.add_child(_rpg_bar(1.0, col))
			c.add_child(_rpg_text("Al máximo  ·  total %d %s" % [CareerRpgEngine.mastery_count(_player, String(b)), String(info["what"])], Styles.SIZE_CAPTION, Styles.GRAY_TEXT))
		c.add_child(_rpg_text("Bonus actual: +%.1f%%" % (CareerRpgEngine.mastery_bonus(_player, String(b)) * 100.0), Styles.SIZE_CAPTION, Styles.GREEN))
		box.add_child(panel)
	return box

## FESTEJO DE FIRMA: elegís el tuyo (sale 2 de cada 3 goles).
func _rpg_celebration_card() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(Styles.section_label("FESTEJO DE FIRMA"))
	var cur: String = CareerRpgEngine.signature_celebration(_player)
	var panel := _card(Styles.BLUE)
	var c: VBoxContainer = panel.get_child(0).get_child(0)
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(0, 150)
	var show_anim: String = cur if cur != "" else String(Avatar.CELEBRATION_ANIMS[0])
	cc.add_child(UiKit.player_anim(_player, show_anim, 144, true, 8.0))
	c.add_child(cc)
	c.add_child(_rpg_text("Tu festejo: %s" % (CareerRpgEngine.celebration_label(cur) if cur != "" else "al azar (como siempre)"), 16, Color.WHITE, true))
	c.add_child(_rpg_text("El que elijas sale en 2 de cada 3 goles tuyos.", Styles.SIZE_CAPTION, Styles.GRAY_TEXT))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var options: Array = [""]
	options.append_array(Avatar.CELEBRATION_ANIMS)
	for anim in options:
		var b := Button.new()
		b.text = CareerRpgEngine.celebration_label(String(anim)) if String(anim) != "" else "Al azar"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 11)
		b.clip_text = true
		Styles.tab(b, String(anim) == cur, true)
		var aid: String = String(anim)
		b.pressed.connect(func():
			CareerRpgEngine.set_signature_celebration(_player, aid)
			SaveManager.save_player(_player)
			_render())
		grid.add_child(b)
	c.add_child(grid)
	box.add_child(panel)
	return box

func _rpg_achievements_block(chunk: Array, first: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(Styles.section_label("LOGROS  ·  %d / %d" % [CareerRpgEngine.achievements_done(_player), CareerRpgEngine.ACHIEVEMENTS.size()]))
	if first:
		box.add_child(_rpg_text("Cada logro da XP de carrera una sola vez. Se cobran solos.", Styles.SIZE_CAPTION, Styles.GRAY_TEXT))
	for a in chunk:
		var done: bool = CareerRpgEngine.is_claimed(_player, String(a["id"]))
		var panel := _card(Styles.GOLD if done else Styles.CARD_DARK)
		var c: VBoxContainer = panel.get_child(0).get_child(0)
		c.add_theme_constant_override("separation", 3)
		var head := HBoxContainer.new()
		var n := _rpg_text(("★ " if done else "") + String(a["name"]), 15, Styles.GOLD if done else Color.WHITE, true)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(n)
		head.add_child(_rpg_text("+%d XP" % int(a["xp"]), Styles.SIZE_CAPTION, Styles.GREEN if done else Styles.GRAY_TEXT, false, false))
		c.add_child(head)
		c.add_child(_rpg_text(String(a["desc"]), Styles.SIZE_CAPTION, Styles.GRAY_TEXT))
		if not done:
			var cur: int = CareerRpgEngine.value_of(_player, String(a["check"]))
			var need: int = int(a["min"])
			c.add_child(_rpg_bar(float(cur) / float(maxi(need, 1)), Styles.AMBER, 6.0))
			c.add_child(_rpg_text("%d / %d" % [mini(cur, need), need], 10, Styles.AMBER))
		box.add_child(panel)
	return box


## HORIZONTAL (FootballLegacy H): tu carta, "Editar apariencia" y las
## pestañas a la izquierda; el contenido de la pestaña a la derecha, con su
## propio scroll. Así se ve todo sin bajar.
func _landscape_split() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= vp.y:
		return
	var vbox := $Margin/VBox as VBoxContainer
	var sc := $Margin/VBox/Scroll as ScrollContainer
	var cols := HBoxContainer.new()
	cols.name = "LandCols"
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 400
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.8
	left.add_theme_constant_override("separation", vbox.get_theme_constant("separation"))
	cols.add_child(left)
	var before: Array = []
	for k in vbox.get_children():
		if k == sc:
			break
		before.append(k)
	vbox.add_child(cols)
	vbox.move_child(cols, sc.get_index())
	for k in before:
		(k as Node).reparent(left)
	sc.reparent(cols)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


# ================================================================ horizontal
func _is_land() -> bool:
	return get_viewport_rect().size.x > get_viewport_rect().size.y

func _grid(cols: int, gap: int = 10) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", gap)
	g.add_theme_constant_override("v_separation", gap)
	return g

# ---------------------------------------------------------------- atributos
## Los 6 grupos a la vez (antes 3 hojas con ◀▶).
func _land_attrs() -> void:
	detail_box.add_child(_attr_summary_block())
	var g := _grid(2)
	for cat in _ATTR_CATS:
		var c: Control = _attr_cat_card(cat)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(c)
	detail_box.add_child(g)

# ---------------------------------------------------------------- rasgos
## Mosaico con TODOS los rasgos a la vista (antes había que tocar "Ver 38
## bloqueados") y el detalle del elegido al costado.
var _trait_sel: String = ""

func _land_traits() -> void:
	var owned: int = 0
	for t0 in Traits.CATALOG:
		if t0 in _player.traits:
			owned += 1
	detail_box.add_child(Styles.section_label("RASGOS  ·  %d / %d desbloqueados" % [owned, Traits.CATALOG.size()]))
	var slots: int = Traits.slots_for(_player.overall)
	var equipped_now: Array = Traits.active(_player)
	detail_box.add_child(_trait_slots_row(equipped_now, slots))
	var cats := HFlowContainer.new()
	cats.add_theme_constant_override("h_separation", 6)
	cats.add_theme_constant_override("v_separation", 6)
	var cat_list: Array = [["todos", "Todos"]]
	cat_list.append_array(Traits.CATEGORIES)
	for c in cat_list:
		var n_cat: int = 0
		var n_own: int = 0
		for t1 in Traits.CATALOG:
			if String(c[0]) == "todos" or Traits.category_of(String(t1)) == String(c[0]):
				n_cat += 1
				if t1 in _player.traits:
					n_own += 1
		var cb := Button.new()
		cb.text = "%s %d/%d" % [String(c[1]), n_own, n_cat]
		cb.focus_mode = Control.FOCUS_NONE
		cb.custom_minimum_size = Vector2(0, 32)
		Styles.tab(cb, _trait_cat == String(c[0]), true)
		var cid: String = String(c[0])
		cb.pressed.connect(func():
			_trait_cat = cid
			_render())
		cats.add_child(cb)
	detail_box.add_child(cats)
	var ids: Array = []
	for tid in Traits.CATALOG:
		if _trait_cat == "todos" or Traits.category_of(String(tid)) == _trait_cat:
			ids.append(String(tid))
	ids.sort_custom(func(a, b): return (a in _player.traits) and not (b in _player.traits))
	if _trait_sel == "" or not ids.has(_trait_sel):
		_trait_sel = ids[0] if not ids.is_empty() else ""
	# Detalle del elegido arriba (a lo ancho) y el mosaico completo debajo.
	if _trait_sel != "":
		detail_box.add_child(_trait_card(_trait_sel))
	var g := _grid(3, 8)
	detail_box.add_child(g)
	for tid in ids:
		g.add_child(_trait_tile(tid, tid in equipped_now))

func _trait_tile(tid: String, equipped: bool) -> Control:
	var got: bool = tid in _player.traits
	var sel: bool = tid == _trait_sel
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 50)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3 if sel else 1)
	sb.bg_color = Color(0.2, 0.13, 0.3) if got else Color(0.08, 0.085, 0.1)
	sb.border_color = Color.WHITE if sel else (Styles.GOLD if equipped else (Styles.PURPLE if got else Color(1, 1, 1, 0.08)))
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.offset_right = -6
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := TraitBadge.build(tid, 34, not got)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(badge)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := Label.new()
	n.text = Traits.name_of(tid)
	n.clip_text = true
	n.add_theme_font_override("font", Styles.font_semibold())
	n.add_theme_font_size_override("font_size", 13)
	n.add_theme_color_override("font_color", Color.WHITE if got else Color(0.55, 0.57, 0.62))
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(n)
	var st_l := Label.new()
	st_l.text = "Equipado" if equipped else ("Tuyo" if got else "🔒")
	st_l.add_theme_font_size_override("font_size", 11)
	st_l.add_theme_color_override("font_color", Styles.GOLD if equipped else (Styles.GREEN if got else Color(0.45, 0.47, 0.52)))
	st_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(st_l)
	h.add_child(v)
	b.add_child(h)
	b.pressed.connect(func():
		_trait_sel = tid
		_render())
	return b

# ---------------------------------------------------------------- RPG
## TABLERO: rango, arquetipo y contadores arriba; maestrías en grilla;
## logros en mosaico; festejo de firma al final. Sin 9 hojas.
func _land_rpg() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	detail_box.add_child(top)
	var rk := _card(Styles.GOLD)
	rk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rk.size_flags_stretch_ratio = 1.3
	var rc: VBoxContainer = rk.get_child(0).get_child(0)
	rc.add_child(_rpg_text("RANGO", 11, Styles.GRAY_TEXT, true))
	rc.add_child(_rpg_text(CareerRpgEngine.rank_name(_player.level).to_upper(), 26, Styles.GOLD, true))
	var need: int = ProgressionEngine.xp_to_next(_player.level)
	rc.add_child(_rpg_text("Nivel %d  ·  %d / %d XP" % [_player.level, _player.career_xp, need], 13))
	rc.add_child(_rpg_bar(float(_player.career_xp) / float(maxi(need, 1)), Styles.GOLD, 10.0))
	var nr: Array = CareerRpgEngine.next_rank(_player.level)
	rc.add_child(_rpg_text(("Próximo: %s (nivel %d)" % [String(nr[0]), int(nr[1])]) if String(nr[0]) != "" else "Rango máximo", 12, Styles.GRAY_TEXT))
	top.add_child(rk)
	var arch: Dictionary = CareerRpgEngine.archetype(_player)
	var ap := _card(Styles.PURPLE)
	ap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ac: VBoxContainer = ap.get_child(0).get_child(0)
	ac.add_child(_rpg_text("ARQUETIPO", 11, Styles.PURPLE, true))
	ac.add_child(_rpg_text(String(arch["name"]), 22, Color.WHITE, true))
	ac.add_child(_rpg_text("%s %d" % [String(arch["key"]), int(arch["value"])], 14, Styles.PURPLE.lightened(0.3), true))
	ac.add_child(_rpg_text(String(arch["desc"]), 12, Styles.GRAY_TEXT))
	top.add_child(ap)
	var f: int = ProgressionEngine.form(_player)
	var counters := _grid(4, 8)
	detail_box.add_child(counters)
	var cdefs: Array = [
		["PUNTOS SIN GASTAR", str(_player.skill_points), Styles.GOLD],
		["LOGROS", "%d/%d" % [CareerRpgEngine.achievements_done(_player), CareerRpgEngine.ACHIEVEMENTS.size()], Styles.GREEN],
		["RASGOS", "%d/%d" % [_player.traits.size(), Traits.CATALOG.size()], Styles.PURPLE],
		["FORMA", "%s %s" % [ProgressionEngine.FORM_ARROWS[f], ProgressionEngine.FORM_NAMES[f]], Styles.BLUE],
	]
	for c in cdefs:
		var cp := _card(c[2])
		cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv: VBoxContainer = cp.get_child(0).get_child(0)
		cv.add_child(_rpg_text(String(c[0]), 11, Styles.GRAY_TEXT, true, false))
		cv.add_child(_rpg_text(String(c[1]), 22, c[2], true, false))
		counters.add_child(cp)
	var sk_btn := Button.new()
	sk_btn.text = "Abrir árbol de habilidades  ›"
	sk_btn.custom_minimum_size = Vector2(0, 44)
	sk_btn.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(sk_btn, Styles.pill_filled(Styles.GOLD) if _player.skill_points > 0 else Styles.pill_outlined(Styles.GOLD), Color.BLACK if _player.skill_points > 0 else Styles.GOLD)
	sk_btn.pressed.connect(func():
		SkillsPanel.open(self).closed.connect(func():
			_player = SaveManager.load_player()
			_render()))
	detail_box.add_child(sk_btn)
	detail_box.add_child(Styles.section_label("MAESTRÍAS  ·  +0,4% permanente por nivel"))
	var mg := _grid(3, 8)
	detail_box.add_child(mg)
	for b in CareerRpgEngine.MASTERY:
		var info: Dictionary = CareerRpgEngine.MASTERY[b]
		var col: Color = Color(String(info["color"]))
		var lv: int = CareerRpgEngine.mastery_level(_player, String(b))
		var pr: Array = CareerRpgEngine.mastery_progress(_player, String(b))
		var mp := _card(col)
		mp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mc: VBoxContainer = mp.get_child(0).get_child(0)
		var hd := HBoxContainer.new()
		var nm := _rpg_text(String(info["name"]), 15, col, true, false)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hd.add_child(nm)
		hd.add_child(_rpg_text("Nv %d/10" % lv, 13, Color.WHITE, true, false))
		mc.add_child(hd)
		var frac: float = (float(pr[0]) / float(maxi(int(pr[1]), 1))) if int(pr[1]) > 0 else 1.0
		mc.add_child(_rpg_bar(frac, col))
		mc.add_child(_rpg_text("+%.1f%%  ·  %d %s" % [CareerRpgEngine.mastery_bonus(_player, String(b)) * 100.0, CareerRpgEngine.mastery_count(_player, String(b)), String(info["what"])], 12, Styles.GREEN, false, false))
		mg.add_child(mp)
	detail_box.add_child(Styles.section_label("LOGROS  ·  cada uno da XP una sola vez"))
	var list: Array = CareerRpgEngine.ACHIEVEMENTS.duplicate()
	list.sort_custom(func(a, b2):
		var ca: bool = CareerRpgEngine.is_claimed(_player, String(a["id"]))
		var cb: bool = CareerRpgEngine.is_claimed(_player, String(b2["id"]))
		if ca != cb:
			return ca
		var pa: float = float(CareerRpgEngine.value_of(_player, String(a["check"]))) / float(maxi(int(a["min"]), 1))
		var pb: float = float(CareerRpgEngine.value_of(_player, String(b2["check"]))) / float(maxi(int(b2["min"]), 1))
		return pa > pb)
	var lg := _grid(3, 8)
	detail_box.add_child(lg)
	for a in list:
		var done: bool = CareerRpgEngine.is_claimed(_player, String(a["id"]))
		var lp := _card(Styles.GOLD if done else Styles.CARD_DARK)
		lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lc: VBoxContainer = lp.get_child(0).get_child(0)
		lc.add_theme_constant_override("separation", 3)
		var lh := HBoxContainer.new()
		var ln := _rpg_text(("★ " if done else "") + String(a["name"]), 13, Styles.GOLD if done else Color.WHITE, true, false)
		ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ln.clip_text = true
		lh.add_child(ln)
		lh.add_child(_rpg_text("+%d" % int(a["xp"]), 12, Styles.GREEN if done else Styles.GRAY_TEXT, false, false))
		lc.add_child(lh)
		var cur: int = CareerRpgEngine.value_of(_player, String(a["check"]))
		var need2: int = int(a["min"])
		lc.add_child(_rpg_bar(1.0 if done else float(cur) / float(maxi(need2, 1)), Styles.GOLD if done else Styles.AMBER, 5.0))
		var dtxt: String = String(a["desc"]) if done else "%s  ·  %d/%d" % [String(a["desc"]), mini(cur, need2), need2]
		lc.add_child(_rpg_text(dtxt, 11, Styles.GRAY_TEXT))
		lg.add_child(lp)
	detail_box.add_child(_rpg_celebration_card())
