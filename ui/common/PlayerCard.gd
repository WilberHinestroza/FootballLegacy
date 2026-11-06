extends RefCounted
class_name PlayerCard

## Contenido de la "carta" de un jugador — overall grande, posición, edad,
## potencial, nacionalidad y los 9 atributos. Un solo lugar para no
## duplicar este render en cada pantalla que necesite mostrar un jugador
## a fondo (WorldExplorer al ver la nómina de cualquier club, Squad al
## ver la propia plantilla, y las que hagan falta después) — balance y
## presentación centralizados, mismo criterio que Styles/Icons.

## Nivel de la "carta" por overall — pedido explícito: <=60 bronce/cobre,
## 61-79 plata, 80-85 oro, >85 morado ("celestial", al estilo cartas
## especiales de un FIFA/FC). Único lugar con esta regla — cualquier
## pantalla que necesite el color de nivel de un jugador llama acá,
## nunca duplica los cortes.
static func tier_color(overall: int) -> Color:
	if overall > 85:
		return Styles.PURPLE
	if overall >= 80:
		return Styles.GOLD
	if overall >= 61:
		return Styles.SILVER
	return Styles.BRONZE

## Vacía `container` y arma la carta adentro. El llamador solo necesita
## un VBoxContainer visible (típicamente dentro de un overlay/popup propio)
## y mostrarlo/ocultarlo — este método no toca visibilidad de nada.
static func render(container: VBoxContainer, p: PlayerData) -> void:
	for child in container.get_children():
		child.queue_free()

	var header := VBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 4)

	# Retrato (Avatar Mixer) + burbuja de overall, lado a lado.
	var portrait_row := HBoxContainer.new()
	portrait_row.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_row.add_theme_constant_override("separation", 12)

	var tcol: Color = tier_color(p.overall)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(96, 96)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fstyle := Styles.card_flat(Color(1, 1, 1, 0.06), 16)
	fstyle.set_border_width_all(3)
	fstyle.border_color = tcol
	frame.add_theme_stylebox_override("panel", fstyle)
	var av := Avatar.for_player(p, SaveManager.load_world_seed(), 88)
	var av_center := CenterContainer.new()
	av_center.add_child(av)
	frame.add_child(av_center)
	portrait_row.add_child(frame)

	var circle := PanelContainer.new()
	circle.custom_minimum_size = Vector2(72, 72)
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	circle.add_theme_stylebox_override("panel", Styles.circle(tcol, 72))
	var center := CenterContainer.new()
	var ov_lbl := Label.new()
	ov_lbl.text = str(p.overall)
	ov_lbl.add_theme_font_size_override("font_size", 28)
	ov_lbl.add_theme_color_override("font_color", Color.BLACK)
	Styles.apply_display_font(ov_lbl)
	center.add_child(ov_lbl)
	circle.add_child(center)
	portrait_row.add_child(circle)
	header.add_child(portrait_row)

	var name_lbl := Label.new()
	name_lbl.text = p.player_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	header.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "%s (%s) — %d años — Potencial %d" % [Positions.label_of(p.detailed_position), Positions.broad_label(p.position), p.age, p.potential]
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	header.add_child(sub_lbl)

	if String(p.origin) == "Cantera del club":
		var canter := Label.new()
		canter.text = "🎓  Canterano"
		canter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		canter.add_theme_color_override("font_color", Styles.GREEN)
		canter.add_theme_font_size_override("font_size", 12)
		header.add_child(canter)

	if p.country != "":
		var nat_row := HBoxContainer.new()
		nat_row.alignment = BoxContainer.ALIGNMENT_CENTER
		nat_row.add_theme_constant_override("separation", 6)
		var fr: TextureRect = CountryFlags.flag_rect(p.country, 14)
		if fr != null:
			nat_row.add_child(fr)
		var nat_lbl := Label.new()
		nat_lbl.text = p.country
		nat_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		nat_row.add_child(nat_lbl)
		header.add_child(nat_row)

	container.add_child(header)

	# Seguir en redes (cuenta del jugador).
	if not p.player_name.is_empty():
		var fkey := "player:" + p.player_name
		var fbtn := Button.new()
		fbtn.custom_minimum_size = Vector2(0, 38)
		fbtn.focus_mode = Control.FOCUS_NONE
		fbtn.add_theme_font_size_override("font_size", 12)
		_style_follow(fbtn, SocialEngine.is_following(WorldTickEngine.season, fkey))
		fbtn.pressed.connect(func():
			var now := SocialEngine.toggle_follow(WorldTickEngine.season, fkey)
			SaveManager.save_season(WorldTickEngine.season)
			_style_follow(fbtn, now))
		var fwrap := CenterContainer.new()
		fwrap.add_child(fbtn)
		container.add_child(fwrap)

	# --- Rasgos (schema v21-22, ver Traits.gd) — los EQUIPADOS primero
	# (los que aplican en partido), el resto abajo y atenuados. ---
	if p.traits is Array and not p.traits.is_empty():
		container.add_child(HSeparator.new())
		var active_ids: Array = Traits.active(p)
		var eq_head := Label.new()
		eq_head.text = "PERKS EQUIPADOS  ·  %d/%d" % [active_ids.size(), Traits.slots_for(p.overall)]
		eq_head.add_theme_color_override("font_color", Styles.GOLD)
		eq_head.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		container.add_child(eq_head)
		if active_ids.is_empty():
			var none_lbl := Label.new()
			none_lbl.text = "Ninguno equipado."
			none_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
			none_lbl.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
			container.add_child(none_lbl)
		for tid in active_ids:
			container.add_child(_trait_row(String(tid), true))
		var rest: Array = []
		for tid in p.traits:
			if not (String(tid) in active_ids):
				rest.append(String(tid))
		if not rest.is_empty():
			var rest_head := Label.new()
			rest_head.text = "OTROS RASGOS (sin equipar)"
			rest_head.add_theme_color_override("font_color", Styles.GRAY_TEXT)
			rest_head.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
			container.add_child(rest_head)
			for tid in rest:
				container.add_child(_trait_row(String(tid), false))

	container.add_child(HSeparator.new())

	# --- Atributos estilo EA FC: 6 categorías con número + barra de color
	# (mismo lenguaje que la pantalla "Mi Perfil"). ---
	var cats := [
		["RIT", "Ritmo", PlayerDevelopment.card_stat(p, "RIT")],
		["TIR", "Tiros", PlayerDevelopment.card_stat(p, "TIR")],
		["PAS", "Pases", PlayerDevelopment.card_stat(p, "PAS")],
		["REG", "Regates", PlayerDevelopment.card_stat(p, "REG")],
		["DEF", "Defensa", PlayerDevelopment.card_stat(p, "DEF")],
		["FÍS", "Físico", PlayerDevelopment.card_stat(p, "FÍS")],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	for c in cats:
		grid.add_child(_cat_cell(String(c[0]), String(c[1]), int(c[2])))
	container.add_child(grid)

	# --- Detalle de los 9 atributos, compacto ---
	container.add_child(HSeparator.new())
	var attrs := [
		["Velocidad", p.speed], ["Resistencia", p.stamina], ["Fuerza", p.strength],
		["Control", p.control], ["Pase", p.passing], ["Tiro", p.shooting],
		["Regate", p.dribbling], ["Decisión", p.decision_making], ["Compostura", p.composure],
	]
	for a in attrs:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = a[0]
		lbl.custom_minimum_size = Vector2(150, 0)
		row.add_child(lbl)
		row.add_child(_attr_bar(int(a[1]), 90.0))
		var val := Label.new()
		val.text = str(a[1])
		val.custom_minimum_size = Vector2(28, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.add_theme_color_override("font_color", _attr_color(int(a[1])))
		row.add_child(val)
		container.add_child(row)

	# --- Stats de temporada: solo si el jugador tiene registro real
	# (los datos de la IA no se persisten — "mundo vivo"). ---
	if p.season_matches_played > 0 or p.season_goals > 0:
		container.add_child(HSeparator.new())
		var stats_row := HBoxContainer.new()
		stats_row.add_theme_constant_override("separation", 8)
		stats_row.add_child(_stat_col(str(p.season_matches_played), "Partidos"))
		stats_row.add_child(_stat_col(str(p.season_goals), "Goles"))
		stats_row.add_child(_stat_col(str(p.season_key_passes), "Asistencias"))
		container.add_child(stats_row)
	_land_layout(container, grid)

static func _trait_row(tid: String, equipped: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD if equipped else Styles.PURPLE))
	if not equipped:
		panel.modulate = Color(1, 1, 1, 0.62)   # atenuado: no aplica en partido
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 10)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 7)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var badge := TraitBadge.build(String(tid), 28)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	var n := Label.new()
	n.text = ("● " + Traits.name_of(tid)) if equipped else Traits.name_of(tid)
	n.add_theme_font_override("font", Styles.font_semibold())
	if equipped:
		n.add_theme_color_override("font_color", Styles.GOLD)
	col.add_child(n)
	var d := Label.new()
	d.text = Traits.desc_of(tid)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	d.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	col.add_child(d)
	row.add_child(col)
	m.add_child(row)
	panel.add_child(m)
	return panel

static func _style_follow(btn: Button, following: bool) -> void:
	btn.text = "✓ Siguiendo" if following else "＋ Seguir en redes"
	Styles.styled_button(btn,
		Styles.pill_filled(Styles.GREEN) if following else Styles.pill_outlined(Styles.GRAY_TEXT),
		Color.BLACK if following else Color.WHITE)

static func _attr_color(v: int) -> Color:
	if v >= 80:
		return Styles.GREEN
	if v >= 65:
		return Styles.AMBER
	return Styles.RED

static func _attr_bar(v: int, width_hint: float = 120.0) -> Control:
	var track := PanelContainer.new()
	track.custom_minimum_size = Vector2(width_hint, 8)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.add_theme_stylebox_override("panel", Styles.card_flat(Color(1, 1, 1, 0.10), 4))
	var fill := ColorRect.new()
	fill.color = _attr_color(v)
	fill.size_flags_horizontal = Control.SIZE_FILL
	fill.custom_minimum_size = Vector2(width_hint * clampf(v / 99.0, 0.04, 1.0), 8)
	track.add_child(fill)
	return track

static func _cat_cell(key: String, cat_name: String, v: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(_attr_color(v)))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 10)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 6)
	var v_box := VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 2)
	var top := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.add_theme_font_override("font", Styles.font_semibold())
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(k)
	var num := Label.new()
	num.text = str(v)
	num.add_theme_font_size_override("font_size", 20)
	num.add_theme_color_override("font_color", _attr_color(v))
	top.add_child(num)
	v_box.add_child(top)
	var nm := Label.new()
	nm.text = cat_name
	nm.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	nm.add_theme_font_size_override("font_size", 11)
	v_box.add_child(nm)
	v_box.add_child(_attr_bar(v, 130.0))
	m.add_child(v_box)
	panel.add_child(m)
	return panel

static func _stat_col(value: String, caption: String) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var v := Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_theme_font_size_override("font_size", 22)
	Styles.apply_display_font(v)
	col.add_child(v)
	var c := Label.new()
	c.text = caption
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	c.add_theme_font_size_override("font_size", 11)
	col.add_child(c)
	return col

## Hace clickeable cualquier Control (fila de nómina, ficha de la cancha,
## banca) para abrir la carta de `p` — conecta gui_input, no reemplaza el
## control ni le agrega un Button encima.
static func make_clickable(control: Control, p: PlayerData, on_click: Callable) -> void:
	UiScroll.on_tap(control, func(): on_click.call(p))


## HORIZONTAL (FootballLegacy H): la ficha en DOS columnas. Izquierda: cara,
## media, datos y rasgos. Derecha: las 6 categorías y los 9 atributos.
## Antes era una columna angosta con las estadísticas cortadas abajo.
static func _land_layout(container: VBoxContainer, grid: GridContainer) -> void:
	if not container.is_inside_tree():
		return
	var vp: Vector2 = container.get_viewport().get_visible_rect().size
	if vp.x <= vp.y:
		return
	var kids: Array = []
	for c in container.get_children():
		if not c.is_queued_for_deletion():
			kids.append(c)
	var gi: int = kids.find(grid)
	if gi < 1:
		return
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.3
	right.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	cols.add_child(right)
	container.add_child(cols)
	for i in kids.size():
		var k: Node = kids[i]
		if i == gi - 1 and k is HSeparator:
			k.queue_free()
			continue
		k.reparent(left if i < gi else right)
	grid.columns = 3
	for r in right.get_children():
		if r is HBoxContainer and r.get_child_count() == 3 and r.get_child(0) is Label:
			(r.get_child(0) as Control).custom_minimum_size.x = 120
