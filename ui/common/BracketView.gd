extends RefCounted
class_name BracketView

## Cuadro de eliminatoria "profesional": cada partido en su propia
## tarjeta (local | resultado o "vs" | visitante) en vez de una línea de
## texto suelta ("Local 2 - 1 Visitante"). Un solo lugar para
## CupBracket/WorldExplorer, que antes tenían cada uno su propia versión.
##
## Append-only, igual que DataTable.add_row: el llamador limpia su
## contenedor antes de la primera llamada (así WorldExplorer puede pegar
## fase de grupos + cuadro en el mismo contenedor sin que uno borre al otro).

## `club_name_fn`: Callable(club_id: String) -> String, para no acoplar
## esto a WorldFactory/WorldTickEngine directamente.
## `country_fn` (opcional): Callable(club_id) -> String nombre de país; si
## se pasa, cada escudo lleva su BANDERA al lado (torneos internacionales).
static func render(container: VBoxContainer, bracket: Dictionary, highlight_club_id: String, empty_text: String, club_name_fn: Callable, country_fn: Callable = Callable()) -> void:
	if bracket.is_empty():
		if empty_text != "":
			var empty_lbl := Label.new()
			empty_lbl.text = empty_text
			empty_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
			container.add_child(empty_lbl)
		return

	for rnd in bracket.get("rounds", []):
		render_round(container, rnd, highlight_club_id, club_name_fn, country_fn)
		container.add_child(HSeparator.new())

## HORIZONTAL: el cuadro como en la TV — cada ronda es una COLUMNA, de
## izquierda (primera ronda) a derecha (final), y las rondas cortas quedan
## centradas a la altura de las largas. Va dentro de un ScrollContainer que
## se mueve en los dos sentidos.
static func render_columns(container: Control, bracket: Dictionary, highlight_club_id: String, empty_text: String, club_name_fn: Callable, country_fn: Callable = Callable()) -> void:
	var rounds: Array = bracket.get("rounds", [])
	if rounds.is_empty():
		var vb := VBoxContainer.new()
		container.add_child(vb)
		render(vb, bracket, highlight_club_id, empty_text, club_name_fn, country_fn)
		return
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	container.add_child(cols)
	for i in rounds.size():
		var rnd: Dictionary = rounds[i]
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 360
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 6)
		render_round(col, rnd, highlight_club_id, club_name_fn, country_fn)
		cols.add_child(col)
		if i < rounds.size() - 1:
			var arrow := Label.new()
			arrow.text = "›"
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			arrow.add_theme_font_override("font", Styles.font_black())
			arrow.add_theme_font_size_override("font_size", 26)
			arrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.25))
			cols.add_child(arrow)

## Una SOLA ronda (para el navegador ◀▶ de rondas de las copas grandes).
static func render_round(container: VBoxContainer, rnd: Dictionary, highlight_club_id: String, club_name_fn: Callable, country_fn: Callable = Callable()) -> void:
	container.add_child(_round_header(rnd))
	for m in rnd.get("matches", []):
		container.add_child(_match_row(m, highlight_club_id, club_name_fn, country_fn))
	if not (rnd.get("byes", []) as Array).is_empty():
		container.add_child(_byes_line(rnd["byes"] as Array, club_name_fn))

static func _round_header(rnd: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = rnd.get("round_name", "")
	title.add_theme_font_size_override("font_size", 17)
	row.add_child(title)
	if not rnd.get("decided", false):
		var badge := PanelContainer.new()
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		badge.add_theme_stylebox_override("panel", Styles.chip(Styles.CARD_DARK_2))
		var badge_lbl := Label.new()
		badge_lbl.text = "PENDIENTE"
		badge_lbl.add_theme_font_size_override("font_size", 10)
		badge_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		badge.add_child(badge_lbl)
		row.add_child(badge)
	return row

static func _match_row(m: Dictionary, highlight_club_id: String, club_name_fn: Callable, country_fn: Callable = Callable()) -> PanelContainer:
	var home_id: String = String(m.get("home_club_id", ""))
	var away_id: String = String(m.get("away_club_id", ""))
	var result: Variant = m.get("result", null)
	var winner_id: String = String(m.get("winner_club_id", ""))

	var is_mine: bool = highlight_club_id != "" and (home_id == highlight_club_id or away_id == highlight_club_id)
	var style := Styles.card_accent(Styles.GOLD) if is_mine else Styles.card(Styles.CARD_DARK, 8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var home_lbl := _side_label(String(club_name_fn.call(home_id)), HORIZONTAL_ALIGNMENT_LEFT)
	var away_lbl := _side_label(String(club_name_fn.call(away_id)), HORIZONTAL_ALIGNMENT_RIGHT)

	# El perdedor se apaga en gris — comunica quién avanzó sin necesitar un
	# "(avanza)" de texto aparte. El club del usuario siempre en dorado,
	# incluso si perdió (es SU resultado, no debe apagarse como cualquiera).
	if home_id == highlight_club_id:
		home_lbl.add_theme_color_override("font_color", Styles.GOLD)
	elif result != null and winner_id != "" and home_id != winner_id:
		home_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	if away_id == highlight_club_id:
		away_lbl.add_theme_color_override("font_color", Styles.GOLD)
	elif result != null and winner_id != "" and away_id != winner_id:
		away_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)

	var score_lbl := Label.new()
	score_lbl.custom_minimum_size = Vector2(60, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if result != null:
		var pens: Array = m.get("pens", []) if m.get("pens", []) is Array else []
		if pens.size() == 2:
			score_lbl.text = "%d - %d\n(%d-%d pen.)" % [int(result[0]), int(result[1]), int(pens[0]), int(pens[1])]
			score_lbl.add_theme_font_size_override("font_size", 12)
		else:
			score_lbl.text = "%d - %d" % [int(result[0]), int(result[1])]
			score_lbl.add_theme_font_size_override("font_size", 15)
	else:
		score_lbl.text = "vs"
		score_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)

	if home_id != "":
		row.add_child(_crest(home_id, country_fn))
	row.add_child(home_lbl)
	row.add_child(score_lbl)
	row.add_child(away_lbl)
	if away_id != "":
		row.add_child(_crest(away_id, country_fn))
	panel.add_child(row)
	return panel

static func _crest(club_id: String, country_fn: Callable = Callable()) -> Control:
	var c := Styles.club_crest(club_id, 22)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not country_fn.is_valid():
		return c
	var country: String = String(country_fn.call(club_id))
	var fr: TextureRect = CountryFlags.flag_rect(country, 12) if country != "" else null
	if fr == null:
		return c
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(fr)
	box.add_child(c)
	return box

static func _side_label(text: String, align: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.horizontal_alignment = align
	return lbl

static func _byes_line(byes: Array, club_name_fn: Callable) -> Label:
	var names: Array = []
	for cid in byes:
		names.append(String(club_name_fn.call(cid)))
	var lbl := Label.new()
	lbl.text = "Exentos: %s" % ", ".join(names)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	lbl.add_theme_font_size_override("font_size", 12)
	return lbl
