extends Control

## Salón de la Fama — se muestra UNA vez, al colgar los botines
## (ContractDecision._on_retire_pressed → acá en vez de a Start). Resume
## la carrera: temporadas, partidos, goles, asistencias, títulos del
## gabinete (career_titles), rasgos ganados y un cierre. "Continuar"
## limpia todo y vuelve al menú inicial.
##
## Solo lectura de PlayerData ya guardado — no toca nada del mundo.

func _ready() -> void:
	var bg := Styles.screen_bg()
	add_child(bg)
	move_child(bg, 0)

	var player: PlayerData = SaveManager.load_player()

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	# Bug visual real (auditoría ronda 3): una carrera larga y decorada
	# (muchos títulos) podía no scrollear al arrastrar sobre una celda de
	# trofeo — faltaba el deadzone táctil.
	UiScroll.make_touch(scroll)
	var margin := MarginContainer.new()
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 18)
	for s in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 24)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	if player == null:
		var e := Label.new()
		e.text = "Sin carrera que resumir."
		vbox.add_child(e)
		_add_continue(vbox)
		return

	# Cabecera.
	var title := Label.new()
	title.text = "SALÓN DE LA FAMA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Styles.font_black())
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Styles.GOLD)
	vbox.add_child(title)

	var av_center := CenterContainer.new()
	av_center.add_child(Styles.portrait_frame(
		Avatar.for_player(player, SaveManager.load_world_seed(), 96), 96, Styles.GOLD))
	vbox.add_child(av_center)

	var name_lbl := Label.new()
	name_lbl.text = player.player_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(name_lbl)

	var role := Label.new()
	role.text = "%s · se retira a los %d años" % [Positions.label_of(player.detailed_position), player.age]
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	vbox.add_child(role)

	var legacy: int = LegacyEngine.tier(player)
	var lchip := CenterContainer.new()
	lchip.add_child(_chip("Legado: %s" % LegacyEngine.TIER_NAMES[legacy], [Styles.GRAY_TEXT, Styles.BLUE, Styles.GOLD, Styles.PURPLE][legacy]))
	vbox.add_child(lchip)

	# Club donde se retira (para la ceremonia y la camiseta retirada).
	var world: Dictionary = WorldTickEngine.world
	if world.is_empty():
		world = WorldFactory.build(SaveManager.load_world_seed())
	var club: ClubData = WorldFactory.find_club(world, player.club_id) if player.club_id != "" else null
	if LegacyEngine.jersey_retired(player) and club != null:
		vbox.add_child(Styles.section_label("CAMISETA RETIRADA"))
		var jrow := HBoxContainer.new()
		jrow.add_theme_constant_override("separation", 12)
		var num: int = Kit.suggested_number(player.position, "%s|%d" % [player.player_name, SaveManager.load_world_seed()])
		jrow.add_child(Kit.build_for_club_kit(club, WorldTickEngine.get_season_start_year(), false, 72, num))
		var jl := Label.new()
		jl.text = "%s colgó tu N.º %d: nadie más lo va a usar." % [club.club_name, num]
		jl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		jl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		jl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		jl.add_theme_color_override("font_color", Styles.GOLD)
		jrow.add_child(jl)
		vbox.add_child(jrow)

	vbox.add_child(HSeparator.new())

	# Números de carrera.
	vbox.add_child(Styles.section_label("LA CARRERA EN NÚMEROS"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.add_child(_stat_card(str(player.career_matches), "Partidos"))
	grid.add_child(_stat_card(str(player.career_goals), "Goles"))
	grid.add_child(_stat_card(str(player.career_assists), "Asistencias"))
	grid.add_child(_stat_card(str(player.trophies_won), "Títulos como titular"))
	vbox.add_child(grid)

	# Gabinete de trofeos (career_titles).
	var titles: Array = player.career_titles if player.career_titles is Array else []
	vbox.add_child(Styles.section_label("VITRINA PERSONAL · %d" % titles.size()))
	if titles.is_empty():
		var none := Label.new()
		none.text = "Sin títulos mayores. La gloria no lo es todo."
		none.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		vbox.add_child(none)
	else:
		var tgrid := GridContainer.new()
		tgrid.columns = 3
		tgrid.add_theme_constant_override("h_separation", 8)
		tgrid.add_theme_constant_override("v_separation", 12)
		for entry in titles:
			tgrid.add_child(_title_cell(entry))
		vbox.add_child(tgrid)

	# Rasgos ganados.
	var traits: Array = player.traits if player.traits is Array else []
	if not traits.is_empty():
		vbox.add_child(Styles.section_label("RASGOS QUE LO DEFINIERON"))
		var tr_wrap := HFlowContainer.new()
		tr_wrap.add_theme_constant_override("h_separation", 10)
		tr_wrap.add_theme_constant_override("v_separation", 10)
		for tid in traits:
			var tcol := VBoxContainer.new()
			tcol.alignment = BoxContainer.ALIGNMENT_CENTER
			tcol.add_theme_constant_override("separation", 2)
			var b := TraitBadge.build(String(tid), 44)
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			tcol.add_child(b)
			var tl := Label.new()
			tl.text = Traits.name_of(String(tid))
			tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tl.add_theme_font_size_override("font_size", 10)
			tl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
			tl.custom_minimum_size = Vector2(64, 0)
			tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tcol.add_child(tl)
			tr_wrap.add_child(tcol)
		vbox.add_child(tr_wrap)

	vbox.add_child(HSeparator.new())
	var closing := Label.new()
	closing.text = _closing_line(player)
	closing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	closing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	closing.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	vbox.add_child(closing)

	_add_continue(vbox)

	# Ceremonia de despedida ANTES del Salón de la Fama (queda debajo).
	FarewellCeremony.open(self, player, club).closed.connect(func():
		var cf := Confetti.new()
		cf.position = Vector2(288, -10)
		add_child(cf)
		cf.burst(4.0))

func _closing_line(p: PlayerData) -> String:
	if p.career_titles.size() >= 8 or p.trophies_won >= 8:
		return "Una leyenda. Su nombre queda grabado en la historia del fútbol."
	if p.career_goals >= 150:
		return "Un goleador de época. Las redes lo van a extrañar."
	if p.career_matches >= 400:
		return "Kilómetros y kilómetros de fútbol. Profesionalismo puro, temporada tras temporada."
	if p.trophies_won >= 2:
		return "Una carrera para estar orgulloso. Gracias por todo."
	return "No todas las carreras terminan con vitrinas llenas, pero todas dejan huella."

func _stat_card(value: String, caption: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card(Styles.CARD_DARK, 12))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 14)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var n := Label.new()
	n.text = value
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Styles.apply_display_font(n)
	n.add_theme_font_size_override("font_size", 26)
	n.add_theme_color_override("font_color", Styles.GOLD)
	v.add_child(n)
	var c := Label.new()
	c.text = caption
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	c.add_theme_font_size_override("font_size", 11)
	v.add_child(c)
	m.add_child(v)
	panel.add_child(m)
	return panel

## Bug real encontrado en la auditoría (ronda 3): esta era la TERCERA
## copia de "renderizar una celda de career_titles" (las otras dos,
## Coleccion.gd y PlayerProfile.gd, ya usaban HonorsEngine.trophy_key_for()
## — la única que sabe traducir un id sufijado como "botaoro_12" o
## "dcup_Argentina" a la clave de arte correcta). Esta pasaba el id crudo
## directo a Trophy.for_honor(), que nunca matcheaba esos sufijos y caía
## siempre al trofeo genérico procedural — el "if tro == null" de abajo
## era código muerto (for_honor()/build() nunca devuelven null).
func _title_cell(entry: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(88, 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tro: Control = Trophy.for_entry(entry, 44)
	var cc := CenterContainer.new()
	cc.add_child(tro)
	v.add_child(cc)
	var n := Label.new()
	n.text = String(entry.get("name", "?"))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.add_theme_font_size_override("font_size", 10)
	v.add_child(n)
	var yr := Label.new()
	yr.text = str(int(entry.get("season", 0)))
	yr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yr.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	yr.add_theme_font_size_override("font_size", 9)
	v.add_child(yr)
	return v

func _chip(text: String, color: Color) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", Styles.card(Color(color, 0.18), 8))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 8)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 3)
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 11)
	m.add_child(l)
	chip.add_child(m)
	return chip

func _add_continue(vbox: VBoxContainer) -> void:
	var btn := Button.new()
	btn.text = "Continuar"
	btn.custom_minimum_size = Vector2(0, 50)
	btn.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(btn, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	btn.pressed.connect(func():
		WorldTickEngine.season.erase("awaiting_contract_decision")
		WorldTickEngine.season.erase("forced_retirement")
		SaveManager.save_season(WorldTickEngine.season)
		get_tree().change_scene_to_file("res://scenes/Start/Start.tscn"))
	vbox.add_child(btn)
