
extends CanvasLayer
## PAUSA del partido 3D (8-nov, Wilber: "botón de pausa a la mitad y que tenga
## ajustes y otras opciones como repeticiones y así, como en Ser una Leyenda").
## Congela el partido (get_tree().paused) y ofrece: Reanudar, Repeticiones
## (última jugada / mejor jugada del partido), Estadísticas y Ajustes que se
## aplican en vivo (ritmo, ayuda de puntería, afición, menos animaciones).
## Solo UI: lo que hace el partido lo decide SoccerMatch (pause_replay).

const GOLD := Color(1.0, 0.85, 0.3)
const DIM := Color(0.72, 0.74, 0.8)

var _m: SoccerMatch
var _content: VBoxContainer
var _menu_btns: Dictionary = {}
var _section := "resume"


func _init(m: SoccerMatch) -> void:
	_m = m
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		root.add_theme_constant_override("margin_" + side, 70)
	for side in ["top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 40)
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	root.add_child(col)
	# Cabecera: PAUSA + marcador
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	col.add_child(head)
	head.add_child(_label("PAUSA", 40, Color.WHITE, true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var score := _label("", 30, GOLD, true)
	score.name = "Score"
	head.add_child(score)
	# Cuerpo: menú a la izquierda, contenido a la derecha
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 26)
	col.add_child(body)
	var menu := VBoxContainer.new()
	menu.custom_minimum_size.x = 330
	menu.add_theme_constant_override("separation", 10)
	body.add_child(menu)
	for d in [["resume", "▶  Reanudar"], ["replays", "⟲  Repeticiones"], ["stats", "▤  Estadísticas"], ["settings", "⚙  Ajustes"]]:
		var b := _menu_button(String(d[1]))
		b.pressed.connect(_on_menu.bind(String(d[0])))
		menu.add_child(b)
		_menu_btns[String(d[0])] = b
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.07, 0.08, 0.1, 0.92)
	psb.set_corner_radius_all(16)
	psb.border_width_left = 3
	psb.border_color = Color(GOLD, 0.6)
	psb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", psb)
	body.add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	sc.add_child(_content)


func open() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	var names: Array = SoccerMatch.TEAM_NAMES
	(find_child("Score", true, false) as Label).text = "%s  %d - %d  %s   ·   %d'" % [
		_short(String(names[0])), int(_m.score[0]), int(_m.score[1]), _short(String(names[1])), int(_m.minute)]
	_show("replays" if _m.can_pause_replay("last") else "stats")


func close() -> void:
	visible = false
	get_tree().paused = false


func _on_menu(key: String) -> void:
	if key == "resume":
		close()
		return
	_show(key)


func _show(key: String) -> void:
	_section = key
	for k in _menu_btns:
		_style_menu(_menu_btns[k], k == key)
	for c in _content.get_children():
		c.queue_free()
	match key:
		"replays": _build_replays()
		"stats": _build_stats()
		"settings": _build_settings()


# ---------------------------------------------------------------- repeticiones
func _build_replays() -> void:
	_content.add_child(_label("REPETICIONES", 20, GOLD, true))
	var any := false
	if _m.can_pause_replay("last"):
		any = true
		_content.add_child(_action("Última jugada", "Vuelve a ver tu última jugada con cámara libre", func() -> void:
			close()
			_m.pause_replay("last")))
	if _m.can_pause_replay("best"):
		any = true
		_content.add_child(_action("Mejor jugada del partido", "Tu mejor acción hasta ahora", func() -> void:
			close()
			_m.pause_replay("best")))
	if not any:
		_content.add_child(_label("Todavía no hay jugadas tuyas para repetir.", 18, DIM, false))


# ---------------------------------------------------------------- estadísticas
func _build_stats() -> void:
	var st: Dictionary = _m.match_stats
	if st.is_empty():
		_content.add_child(_label("Sin estadísticas todavía.", 18, DIM, false))
		return
	var names: Array = SoccerMatch.TEAM_NAMES
	_content.add_child(_label("ESTADÍSTICAS", 20, GOLD, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	_cell(grid, _short(String(names[0])), 18, Color.WHITE, true, HORIZONTAL_ALIGNMENT_RIGHT)
	_cell(grid, "", 18, DIM, false, HORIZONTAL_ALIGNMENT_CENTER)
	_cell(grid, _short(String(names[1])), 18, Color.WHITE, true, HORIZONTAL_ALIGNMENT_LEFT)
	for d in [["shots", "Tiros"], ["sot", "A puerta"], ["corners", "Córners"], ["fouls", "Faltas"], ["yellows", "Amarillas"]]:
		var v: Array = st.get(String(d[0]), [0, 0])
		_cell(grid, str(v[0]), 20, Color.WHITE, true, HORIZONTAL_ALIGNMENT_RIGHT)
		_cell(grid, String(d[1]), 16, DIM, false, HORIZONTAL_ALIGNMENT_CENTER)
		_cell(grid, str(v[1]), 20, Color.WHITE, true, HORIZONTAL_ALIGNMENT_LEFT)
	_content.add_child(_label("TÚ  ·  nota %.1f" % _m.live_rating(), 20, GOLD, true))
	var me: Dictionary = st.get("me", {})
	var mine := GridContainer.new()
	mine.columns = 4
	mine.add_theme_constant_override("h_separation", 26)
	mine.add_theme_constant_override("v_separation", 6)
	_content.add_child(mine)
	var rows: Array = [["Goles", "goals"], ["Asistencias", "assists"], ["Tiros", "shots"], ["Pases clave", "key_passes"],
		["Recuperaciones", "recov"], ["Jugadas logradas", "moments_ok"]]
	if _m.star != null and _m.star.role == "GK":
		rows = [["Paradas", "saves"], ["Goles recibidos", "conceded"], ["Jugadas logradas", "moments_ok"]]
	for r in rows:
		_cell(mine, String(r[0]), 16, DIM, false, HORIZONTAL_ALIGNMENT_LEFT)
		_cell(mine, str(int(me.get(String(r[1]), 0))), 18, Color.WHITE, true, HORIZONTAL_ALIGNMENT_LEFT)


# ---------------------------------------------------------------- ajustes
func _build_settings() -> void:
	_content.add_child(_label("AJUSTES", 20, GOLD, true))
	_content.add_child(_choice("Ritmo del partido", ["lento", "normal", "rapido"], ["Lento", "Normal", "Rápido"],
		Preferences.match_speed, func(v: String) -> void: Preferences.set_match_speed(v)))
	_content.add_child(_choice("Cámara de jugada", Preferences.MATCH_CAMERAS, ["Cerca", "Lejos"],
		Preferences.match_camera, func(v: String) -> void: Preferences.set_match_camera(v)))
	_content.add_child(_choice("Ayuda de puntería", Preferences.AIM_ASSIST_LEVELS, ["Alta", "Media", "Manual"],
		Preferences.aim_assist, func(v: String) -> void: Preferences.set_aim_assist(v)))
	_content.add_child(_choice("Sonido de la afición", ["si", "no"], ["Sí", "No"],
		"si" if Preferences.crowd_sound else "no", func(v: String) -> void:
			Preferences.set_crowd_sound(v == "si")
			if v == "si":
				Audio.crowd_start()
			else:
				Audio.crowd_stop()))
	_content.add_child(_choice("Menos animaciones", ["no", "si"], ["No", "Sí"],
		"si" if Preferences.reduce_motion else "no", func(v: String) -> void: Preferences.set_reduce_motion(v == "si")))


func _choice(title: String, values: Array, labels: Array, current: String, cb: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := _label(title, 18, Color.WHITE, false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var btns: Array[Button] = []
	for i in values.size():
		var b := Button.new()
		b.text = String(labels[i])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(118, 50)
		b.add_theme_font_size_override("font_size", 17)
		btns.append(b)
		row.add_child(b)
	var paint := func(sel: String) -> void:
		for i in btns.size():
			_style_pill(btns[i], String(values[i]) == sel)
	paint.call(current)
	for i in btns.size():
		var v := String(values[i])
		btns[i].pressed.connect(func() -> void:
			cb.call(v)
			paint.call(v))
	return row


# ---------------------------------------------------------------- piezas
func _menu_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 22)
	_style_menu(b, false)
	return b


func _style_menu(b: Button, on: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GOLD, 0.95) if on else Color(0.12, 0.13, 0.17, 0.95)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 22
	for s in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(s, sb)
	for s in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(s, Color.BLACK if on else Color.WHITE)


func _style_pill(b: Button, on: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GOLD, 0.95) if on else Color(1, 1, 1, 0.06)
	sb.set_corner_radius_all(25)
	sb.set_border_width_all(0 if on else 2)
	sb.border_color = Color(1, 1, 1, 0.18)
	for s in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(s, sb)
	for s in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(s, Color.BLACK if on else Color.WHITE)


func _action(title: String, desc: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "%s\n%s" % [title, desc]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 84)
	b.add_theme_font_size_override("font_size", 19)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.14, 0.18)
	sb.set_corner_radius_all(12)
	sb.border_width_left = 4
	sb.border_color = GOLD
	sb.content_margin_left = 20
	for s in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(s, sb)
	b.pressed.connect(cb)
	return b


func _cell(grid: GridContainer, text: String, size: int, color: Color, bold: bool, align: HorizontalAlignment) -> void:
	var l := _label(text, size, color, bold)
	l.horizontal_alignment = align
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(l)


func _label(text: String, size: int, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", Styles.font_black())
	return l


func _short(team: String) -> String:
	return team.substr(0, 3).to_upper() if team.length() > 14 else team
