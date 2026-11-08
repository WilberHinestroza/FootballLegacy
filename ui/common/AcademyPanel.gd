extends Control
class_name AcademyPanel
## Tu cantera (AcademyEngine): números del juvenil, últimos partidos, qué te
## falta para subir al primer equipo y cuántas veces te convocaron.

var _player: PlayerData

func setup(player: PlayerData) -> void:
	_player = player

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GREEN))
	center.add_child(panel)
	var m := MarginContainer.new()
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 18)
	for s in ["top", "bottom"]: m.add_theme_constant_override("margin_" + s, 14)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(680, 0)
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	var d: Dictionary = AcademyEngine.data(_player)

	var title := Label.new()
	title.text = "Cantera · %s" % String(d.get("club_name", ""))
	title.add_theme_font_override("font", Styles.font_black())
	title.add_theme_font_size_override("font_size", 22)
	v.add_child(title)

	var nums := Label.new()
	nums.text = "%d partidos juveniles · %d goles · %d asistencias · nota media %.1f · %d convocatorias con el primer equipo" % [
		int(d.get("matches", 0)), int(d.get("goals", 0)), int(d.get("assists", 0)),
		AcademyEngine.avg_rating(_player), int(d.get("callups", 0))]
	nums.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nums.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(nums)

	v.add_child(Styles.section_label("PARA SUBIR AL PRIMER EQUIPO"))
	for c in AcademyEngine.promotion_checklist(_player):
		var l := Label.new()
		l.text = "%s  %s" % ["✔" if bool(c[1]) else "•", String(c[0])]
		l.add_theme_color_override("font_color", Styles.GREEN if bool(c[1]) else Color.WHITE)
		v.add_child(l)
	var age_l := Label.new()
	if _player.age < AcademyEngine.RELEASE_AGE:
		age_l.text = "Tienes %d años: si a los %d no das el nivel, el club te deja libre." % [_player.age, AcademyEngine.RELEASE_AGE]
	else:
		age_l.text = "Este es tu año: al terminar la temporada, o subes o te dejan libre."
	age_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	age_l.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	age_l.add_theme_color_override("font_color", Styles.AMBER)
	v.add_child(age_l)

	v.add_child(Styles.section_label("ÚLTIMOS PARTIDOS DEL JUVENIL"))
	var recent: Array = d.get("recent", [])
	if recent.is_empty():
		var e := Label.new()
		e.text = "Todavía no jugaste: el juvenil juega una vez por semana."
		e.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		v.add_child(e)
	for i in range(recent.size() - 1, -1, -1):
		var r: Dictionary = recent[i]
		var dt: Dictionary = CalendarUtils.epoch_day_to_date(int(r.get("day", 0)))
		var extra: String = ""
		if int(r.get("goals", 0)) > 0:
			extra += "  · %d gol%s" % [int(r.goals), "" if int(r.goals) == 1 else "es"]
		if int(r.get("assists", 0)) > 0:
			extra += "  · %d asist." % int(r.assists)
		var row := Label.new()
		row.text = "%02d/%02d  ·  %s  ·  nota %.1f%s" % [int(dt.get("day", 1)), int(dt.get("month", 1)), String(r.get("score", "")), float(r.get("rating", 0)), extra]
		var rt: float = float(r.get("rating", 0))
		row.add_theme_color_override("font_color", Styles.GREEN if rt >= 7.5 else (Styles.AMBER if rt >= 6.0 else Styles.RED))
		v.add_child(row)

	var close := Button.new()
	close.text = "Cerrar"
	close.custom_minimum_size = Vector2(0, 42)
	close.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(close, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	close.pressed.connect(_close)
	v.add_child(close)

func _close() -> void:
	if get_parent() is CanvasLayer:
		get_parent().queue_free()
	else:
		queue_free()

static func open(host: Node, player: PlayerData) -> AcademyPanel:
	var layer := CanvasLayer.new()
	layer.layer = 60
	var p := AcademyPanel.new()
	p.setup(player)
	layer.add_child(p)
	host.add_child(layer)
	return p
