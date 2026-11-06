extends RefCounted
class_name TrophyCabinet

## Render de una vitrina de club a partir de ClubHonorsEngine.for_club().
## Se usa en ClubInfo (tu club) y en el overlay de nómina de WorldExplorer
## (cualquier club). Devuelve un Control listo para meter en un VBox.

const _TIER_COLOR := {
	"gold": Color(0.90, 0.74, 0.28),
	"silver": Color(0.78, 0.80, 0.86),
	"bronze": Color(0.80, 0.53, 0.34),
}

static func build(entries: Array, club_name: String = "") -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)

	if entries.is_empty():
		var e := Label.new()
		e.text = "Sin títulos mayores en las vitrinas todavía."
		UiKit.empty_icon(e, Icons.PX_AWARDS)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		root.add_child(e)
		return root

	var total: int = ClubHonorsEngine.total_count(entries)
	var head := Label.new()
	head.text = "%d título%s mayor%s" % [total, "" if total == 1 else "s", "" if total == 1 else "es"]
	head.add_theme_font_override("font", Styles.font_black())
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Styles.GOLD)
	root.add_child(head)

	for entry in entries:
		root.add_child(_row(entry))
	return root

static func _row(entry: Dictionary) -> PanelContainer:
	var accent: Color = _TIER_COLOR.get(String(entry.get("tier", "bronze")), Styles.GRAY_TEXT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(accent))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 12)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var tro: Control = Trophy.for_title(String(entry["title_id"]), 44) if entry.has("title_id") else Trophy.for_honor(String(entry.get("icon", "mvp_liga")), 44)
	if tro != null:
		tro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tro)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 1)
	var n := Label.new()
	n.text = String(entry.get("name", "?"))
	n.add_theme_font_override("font", Styles.font_semibold())
	texts.add_child(n)
	var sub := Label.new()
	sub.text = "Último: %d" % int(entry.get("last_year", 0))
	sub.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	sub.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	texts.add_child(sub)
	row.add_child(texts)

	var count := Label.new()
	count.text = "×%d" % int(entry.get("count", 0))
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count.add_theme_font_override("font", Styles.font_black())
	count.add_theme_font_size_override("font_size", 22)
	count.add_theme_color_override("font_color", accent)
	row.add_child(count)

	m.add_child(row)
	panel.add_child(m)
	return panel
