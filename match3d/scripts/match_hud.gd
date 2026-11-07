class_name MatchHUD
extends CanvasLayer
## Marcador con minuto, panel de simulación con comentarios, avisos grandes,
## instrucciones del momento, barra de tiempo y estela de los gestos.

const CrossZone = preload("res://engine/match/m3d/CrossZone.gd")
const PrePlayChoice = preload("res://engine/match/m3d/PrePlayChoice.gd")

signal replay_pressed
signal pause_pressed
signal entry_requested
signal leave_requested
signal exit_requested
signal choice_made(index: int)
signal cross_zone_selected(zone_id: String)
signal preplay_selected(choice_id: String)

var gesture: GestureInput
var _cross_bar: HBoxContainer
var _preplay_bar: HBoxContainer
var _replay_btn: Button
var _pause_btn: Button
var _request_btn: Button
var _leave_btn: Button
var _exit_btn: Button
var _stamina_label: Label
var _stamina_bg: ColorRect
var _stamina_fill: ColorRect
var _power_bg: ColorRect
var _power_fill: ColorRect
var _power_cap: ColorRect
var _power_label: Label
var _power_linger := 0.0
var _power_hiding := false
var _aim_arc: Line2D
var _sub_panel: PanelContainer
var _sub_time := 0.0

var _score: Label
var _home_lbl: Label
var _away_lbl: Label
var _minute_lbl: Label
var _board: PanelContainer
var _style: Dictionary = {}
var _message: Label      # primera línea del aviso, grande
var _message_sub: Label  # el resto, más pequeño
var _msg_box: VBoxContainer
var _msg_band: Panel
var _hint: Label
var _timer_bar: ProgressBar
var _sim_panel: PanelContainer
var _feed: Label
var _feed_old: Label   # las dos líneas anteriores, más tenues
var _feed_lines: Array[String] = []
var _msg_time := 0.0
var _rating_panel: PanelContainer
var _rating_lbl: Label
var _rating_delta: Label
var _rating_flash := 0.0


func _ready() -> void:
	setup_broadcast(BROADCAST.keys()[0], ["LOCAL", "VISITA"], [Color.RED, Color.BLUE])

	_timer_bar = ProgressBar.new()
	add_child(_timer_bar)
	_timer_bar.show_percentage = false
	_timer_bar.max_value = 1.0
	_timer_bar.step = 0.001
	_timer_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_timer_bar.offset_left = -160.0
	_timer_bar.offset_right = 160.0
	_timer_bar.offset_top = 60.0
	_timer_bar.offset_bottom = 72.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.8, 0.15)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	_timer_bar.add_theme_stylebox_override("fill", fill)
	_timer_bar.add_theme_stylebox_override("background", bg)
	_timer_bar.visible = false

	_sim_panel = PanelContainer.new()
	add_child(_sim_panel)
	# 7-nov: teletipo compacto arriba a la izquierda (antes una caja en el centro que
	# crecía hasta tapar media jugada). Última línea brillante, dos anteriores tenues.
	_sim_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_sim_panel.offset_left = 10.0
	_sim_panel.offset_right = 360.0
	_sim_panel.offset_top = 112.0
	_sim_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.42)
	panel_style.set_corner_radius_all(10)
	panel_style.border_width_left = 3
	panel_style.border_color = Color(1.0, 0.8, 0.15, 0.9)
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_top = 6.0
	panel_style.content_margin_bottom = 8.0
	_sim_panel.add_theme_stylebox_override("panel", panel_style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	_sim_panel.add_child(vbox)
	var title := _label(12, vbox)
	title.text = "● EN JUEGO"
	title.label_settings.font_color = Color(1.0, 0.8, 0.15)
	_feed_old = _label(13, vbox)
	_feed_old.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feed_old.label_settings.font_color = Color(1.0, 1.0, 1.0, 0.55)
	_feed_old.visible = false
	_feed = _label(15, vbox)
	_feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Aviso: franja translúcida en el tercio superior (no tapa la jugada); el final, centrado
	_msg_band = Panel.new()
	_msg_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band_sb := StyleBoxFlat.new()
	band_sb.bg_color = Color(0.0, 0.0, 0.0, 0.4)
	band_sb.set_corner_radius_all(14)
	_msg_band.add_theme_stylebox_override("panel", band_sb)
	add_child(_msg_band)
	_msg_box = VBoxContainer.new()
	_msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_msg_box.add_theme_constant_override("separation", 0)
	add_child(_msg_box)
	_message = _label(40, _msg_box)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_sub = _label(22, _msg_box)
	_message_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_sub.label_settings.font_color = Color(1.0, 1.0, 1.0, 0.92)
	_msg_box.visible = false
	_msg_band.visible = false

	_hint = _label(18, self)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -64.0
	_hint.offset_bottom = -10.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.visible = false

	_build_rating()

	# P1-03: aro de puntería sobre el arco (debajo de la estela del gesto).
	_aim_arc = Line2D.new()
	_aim_arc.width = 5.0
	_aim_arc.closed = true
	_aim_arc.joint_mode = Line2D.LINE_JOINT_ROUND
	_aim_arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_aim_arc.end_cap_mode = Line2D.LINE_CAP_ROUND
	_aim_arc.antialiased = true
	_aim_arc.visible = false
	add_child(_aim_arc)

	gesture = GestureInput.new()
	add_child(gesture)

	# Pausa (8-nov): arriba en el centro, como en las consolas
	_pause_btn = Button.new()
	_pause_btn.text = "❚❚"
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.add_theme_font_size_override("font_size", 26)
	_pause_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pause_btn.offset_left = -36.0
	_pause_btn.offset_right = 36.0
	_pause_btn.offset_top = 10.0
	_pause_btn.offset_bottom = 82.0
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color(0.05, 0.06, 0.08, 0.72)
	pb.set_corner_radius_all(36)
	pb.set_border_width_all(2)
	pb.border_color = Color(1, 1, 1, 0.35)
	for st in ["normal", "hover", "pressed"]:
		_pause_btn.add_theme_stylebox_override(st, pb)
	_pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	_pause_btn.visible = false
	add_child(_pause_btn)

	# Botón de repetición: aparece al terminar cada jugada
	_replay_btn = Button.new()
	_replay_btn.text = "⟲  REPETICIÓN"
	_replay_btn.add_theme_font_size_override("font_size", 24)
	_replay_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_replay_btn.offset_left = -250.0
	_replay_btn.offset_top = -150.0
	_replay_btn.offset_right = -20.0
	_replay_btn.offset_bottom = -84.0
	var rb := StyleBoxFlat.new()
	rb.bg_color = Color(0.85, 0.12, 0.15, 0.92)
	rb.set_corner_radius_all(10)
	_replay_btn.add_theme_stylebox_override("normal", rb)
	_replay_btn.add_theme_stylebox_override("hover", rb)
	_replay_btn.add_theme_stylebox_override("pressed", rb)
	_replay_btn.pressed.connect(func() -> void: replay_pressed.emit())
	_replay_btn.visible = false
	add_child(_replay_btn)

	_request_btn = Button.new()
	_request_btn.text = "PEDIR ENTRAR"
	_request_btn.add_theme_font_size_override("font_size", 22)
	_request_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_request_btn.offset_left = 20.0
	_request_btn.offset_top = -150.0
	_request_btn.offset_right = 270.0
	_request_btn.offset_bottom = -84.0
	var qb := StyleBoxFlat.new()
	qb.bg_color = Color(0.2, 0.5, 0.9, 0.92)
	qb.set_corner_radius_all(10)
	_request_btn.add_theme_stylebox_override("normal", qb)
	_request_btn.add_theme_stylebox_override("hover", qb)
	_request_btn.add_theme_stylebox_override("pressed", qb)
	_request_btn.pressed.connect(func() -> void: entry_requested.emit())
	_request_btn.visible = false
	add_child(_request_btn)

	_leave_btn = Button.new()
	_leave_btn.text = "PEDIR SALIR"
	_leave_btn.add_theme_font_size_override("font_size", 22)
	_leave_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_leave_btn.offset_left = 20.0
	_leave_btn.offset_top = -90.0
	_leave_btn.offset_right = 270.0
	_leave_btn.offset_bottom = -24.0
	var lb := StyleBoxFlat.new()
	lb.bg_color = Color(0.6, 0.15, 0.15, 0.92)
	lb.set_corner_radius_all(10)
	_leave_btn.add_theme_stylebox_override("normal", lb)
	_leave_btn.add_theme_stylebox_override("hover", lb)
	_leave_btn.add_theme_stylebox_override("pressed", lb)
	_leave_btn.pressed.connect(func() -> void: leave_requested.emit())
	_leave_btn.visible = false
	add_child(_leave_btn)

	# Barra de estamina: arriba de la repetición, a la derecha
	_stamina_bg = ColorRect.new()
	_stamina_bg.color = Color(0.0, 0.0, 0.0, 0.55)
	_stamina_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_stamina_bg.offset_left = -250.0
	_stamina_bg.offset_top = -190.0
	_stamina_bg.offset_right = -20.0
	_stamina_bg.offset_bottom = -170.0
	_stamina_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bg.visible = false
	add_child(_stamina_bg)
	_stamina_fill = ColorRect.new()
	_stamina_fill.color = Color(0.35, 0.9, 0.4)
	_stamina_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stamina_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bg.add_child(_stamina_fill)
	_stamina_label = Label.new()
	_stamina_label.add_theme_font_size_override("font_size", 15)
	_stamina_label.add_theme_color_override("font_color", Color.WHITE)
	_stamina_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_stamina_label.add_theme_constant_override("outline_size", 5)
	_stamina_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stamina_label.offset_top = -22.0
	_stamina_label.offset_bottom = -20.0
	_stamina_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_stamina_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bg.add_child(_stamina_label)

	# Barra de POTENCIA del remate (P1-01): se llena mientras mantenés el
	# gesto y muestra con una marca blanca el techo que impone la stamina.
	_power_bg = ColorRect.new()
	_power_bg.color = Color(0.0, 0.0, 0.0, 0.55)
	_power_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_power_bg.offset_left = -250.0
	_power_bg.offset_top = -240.0
	_power_bg.offset_right = -20.0
	_power_bg.offset_bottom = -218.0
	_power_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_bg.visible = false
	add_child(_power_bg)
	_power_fill = ColorRect.new()
	_power_fill.color = Color(0.35, 0.9, 0.4)
	_power_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_power_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_bg.add_child(_power_fill)
	_power_cap = ColorRect.new()
	_power_cap.color = Color(1.0, 1.0, 1.0, 0.85)
	_power_cap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_power_cap.offset_left = -1.0
	_power_cap.offset_right = 1.0
	_power_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_bg.add_child(_power_cap)
	_power_label = Label.new()
	_power_label.add_theme_font_size_override("font_size", 14)
	_power_label.add_theme_color_override("font_color", Color.WHITE)
	_power_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_power_label.add_theme_constant_override("outline_size", 4)
	_power_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_power_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_bg.add_child(_power_label)

	# Pedir el cambio (salir) estando en el campo: mismo hueco que "pedir entrar"
	_exit_btn = Button.new()
	_exit_btn.text = "PEDIR SALIR"
	_exit_btn.add_theme_font_size_override("font_size", 22)
	_exit_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_exit_btn.offset_left = 20.0
	_exit_btn.offset_top = -150.0
	_exit_btn.offset_right = 270.0
	_exit_btn.offset_bottom = -84.0
	var xb := StyleBoxFlat.new()
	xb.bg_color = Color(0.75, 0.32, 0.12, 0.92)
	xb.set_corner_radius_all(10)
	_exit_btn.add_theme_stylebox_override("normal", xb)
	_exit_btn.add_theme_stylebox_override("hover", xb)
	_exit_btn.add_theme_stylebox_override("pressed", xb)
	_exit_btn.pressed.connect(func() -> void: exit_requested.emit())
	_exit_btn.visible = false
	add_child(_exit_btn)

	# P1-10 · Centro con zona elegida: tres botones sobre la franja inferior
	# para mandar el centro al primer palo, al segundo o al punto penal.
	_cross_bar = HBoxContainer.new()
	_cross_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_cross_bar.offset_left = -340.0
	_cross_bar.offset_right = 340.0
	_cross_bar.offset_top = -176.0
	_cross_bar.offset_bottom = -112.0
	_cross_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_cross_bar.add_theme_constant_override("separation", 12)
	_cross_bar.visible = false
	add_child(_cross_bar)
	for entry in [[CrossZone.NEAR_POST, "1ER PALO"], [CrossZone.FAR_POST, "2º PALO"],
			[CrossZone.PENALTY_SPOT, "PUNTO PENAL"]]:
		_cross_bar.add_child(_cross_button(String(entry[0]), String(entry[1])))

	# P1-13 · Elección antes de la jugada: conducir, pasar rápido o aguantar.
	# Se muestra durante la intro de las jugadas de ataque en las que llevas el balón.
	_preplay_bar = HBoxContainer.new()
	_preplay_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_preplay_bar.offset_left = -340.0
	_preplay_bar.offset_right = 340.0
	_preplay_bar.offset_top = -176.0
	_preplay_bar.offset_bottom = -112.0
	_preplay_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_preplay_bar.add_theme_constant_override("separation", 12)
	_preplay_bar.visible = false
	add_child(_preplay_bar)
	for entry in [[PrePlayChoice.DRIVE, PrePlayChoice.label(PrePlayChoice.DRIVE)],
			[PrePlayChoice.QUICK_PASS, PrePlayChoice.label(PrePlayChoice.QUICK_PASS)],
			[PrePlayChoice.HOLD, PrePlayChoice.label(PrePlayChoice.HOLD)]]:
		_preplay_bar.add_child(_preplay_button(String(entry[0]), String(entry[1])))


func _preplay_button(choice_id: String, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(196.0, 58.0)
	var sb := StyleBoxFlat.new()
	match choice_id:
		PrePlayChoice.DRIVE:
			sb.bg_color = Color(0.12, 0.42, 0.78, 0.94)
		PrePlayChoice.QUICK_PASS:
			sb.bg_color = Color(0.1, 0.52, 0.32, 0.94)
		_:
			sb.bg_color = Color(0.72, 0.42, 0.12, 0.94)
	sb.set_corner_radius_all(10)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func() -> void: preplay_selected.emit(choice_id))
	return b


## Muestra u oculta la barra de elección previa a la jugada.
func show_preplay_choices(value := true) -> void:
	if _preplay_bar != null:
		_preplay_bar.visible = value


func hide_preplay_choices() -> void:
	show_preplay_choices(false)


func preplay_visible() -> bool:
	return _preplay_bar != null and _preplay_bar.visible


func _cross_button(zone_id: String, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(196.0, 58.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.52, 0.32, 0.94)
	sb.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(func() -> void: cross_zone_selected.emit(zone_id))
	return b


## Muestra u oculta la barra de zonas del centro.
func show_cross_zones(value := true) -> void:
	if _cross_bar != null:
		_cross_bar.visible = value


func hide_cross_zones() -> void:
	show_cross_zones(false)


## ¿El toque cae sobre uno de los botones de zona? Entonces no es una orden de
## movimiento para el jugador (GestureInput y el botón reciben el mismo evento).
func cross_zone_at(pos: Vector2) -> bool:
	if _cross_bar == null or not _cross_bar.visible:
		return false
	for b in _cross_bar.get_children():
		if b is Button and (b as Button).get_global_rect().has_point(pos):
			return true
	return false


## Botón de pedir entrar (desde el banquillo). Solo se muestra cuando tiene sentido.
func show_request_button(value: bool) -> void:
	_request_btn.visible = value

func show_leave_button(value: bool) -> void:
	_leave_btn.visible = value


## Botón de pedir salir (estando en el campo, mientras se simula).
func show_exit_button(value: bool) -> void:
	_exit_btn.visible = value


## Energía del jugador, 0..1: verde, amarilla o roja según cuánto le queda.
func set_stamina(fraction: float, shown: bool) -> void:
	_stamina_bg.visible = shown
	var f := clampf(fraction, 0.0, 1.0)
	_stamina_fill.anchor_right = f
	_stamina_fill.color = Color(0.35, 0.9, 0.4) if f > 0.5 else (Color(0.95, 0.8, 0.2) if f > 0.25 else Color(0.95, 0.3, 0.25))
	_stamina_label.text = "ENERGÍA  %d%%" % int(round(f * 100.0))


## Barra de potencia mientras se carga el remate. `cap` es el máximo que
## permite la stamina: la marca blanca muestra ese techo.
func show_power(fraction: float, cap: float) -> void:
	var f := clampf(fraction, 0.0, 1.0)
	var c := clampf(cap, 0.05, 1.0)
	_power_bg.visible = true
	_power_hiding = false
	_power_linger = 0.0
	_power_fill.anchor_right = f
	if f > 0.93:
		_power_fill.color = Color(0.95, 0.3, 0.25)
	elif f > 0.75:
		_power_fill.color = Color(0.95, 0.8, 0.2)
	else:
		_power_fill.color = Color(0.35, 0.9, 0.4)
	_power_cap.anchor_left = c
	_power_cap.anchor_right = c
	_power_label.text = "POTENCIA  %d%%" % int(round(f * 100.0))


## P1-03 · Aro de puntería: círculo de `radius` píxeles alrededor del punto
## de mira proyectado sobre el arco. El color va de verde (margen) a rojo
## (zona mínima).
func show_aim_zone(center: Vector2, radius: float, color: Color) -> void:
	if _aim_arc == null:
		return
	if radius < 2.0:
		_aim_arc.visible = false
		return
	var n := 40
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * float(i) / float(n)
		pts[i] = center + Vector2(cos(a), sin(a)) * radius
	_aim_arc.points = pts
	_aim_arc.default_color = color
	_aim_arc.visible = true


func hide_aim_zone() -> void:
	if _aim_arc != null:
		_aim_arc.visible = false


## Deja la barra visible un instante con el último valor y la apaga.
func hide_power() -> void:
	if _power_bg.visible and not _power_hiding:
		_power_hiding = true
		_power_linger = 0.45


## Rótulo de TV del cambio: entra (verde) y sale (rojo), con el color del equipo.
func show_substitution(team_name: String, color: Color, num_off: int, num_on: int) -> void:
	if _sub_panel:
		_sub_panel.queue_free()
	_sub_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Color(String(_style.get("bg", "#101418"))), 0.92)
	sb.set_corner_radius_all(int(_style.get("radius", 6)))
	sb.border_color = color
	sb.border_width_left = 8
	sb.set_content_margin_all(10.0)
	_sub_panel.add_theme_stylebox_override("panel", sb)
	_sub_panel.position = Vector2(16.0, 76.0)
	_sub_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub_panel)
	var col := VBoxContainer.new()
	_sub_panel.add_child(col)
	var title := _label(18, col)
	title.text = "CAMBIO · %s" % team_name.to_upper()
	title.label_settings.font_color = Color(String(_style.get("accent", "#ffffff"))).lightened(0.3)
	var on := _label(22, col)
	on.text = "▲  Entra el %d" % num_on
	on.label_settings.font_color = Color(0.4, 1.0, 0.45)
	var off := _label(22, col)
	off.text = "▼  Sale el %d" % num_off
	off.label_settings.font_color = Color(1.0, 0.4, 0.35)
	_sub_time = 4.5


func show_pause_button(value: bool) -> void:
	if _pause_btn != null and _pause_btn.visible != value:
		_pause_btn.visible = value


func show_replay_button(value: bool) -> void:
	_replay_btn.visible = value


func _process(delta: float) -> void:
	# Tiempo real: los mensajes duran lo mismo aunque el juego vaya a cámara lenta
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	if _power_hiding:
		_power_linger -= real_delta
		if _power_linger <= 0.0:
			_power_bg.visible = false
			_power_hiding = false
	if _sub_time > 0.0:
		_sub_time -= real_delta
		_sub_panel.modulate.a = clampf(_sub_time / 0.4, 0.0, 1.0)
		if _sub_time <= 0.0:
			_sub_panel.visible = false
	if _rating_flash > 0.0:
		_rating_flash -= real_delta
		var k := 1.0 - _rating_flash / 1.6
		_rating_delta.position = _rating_panel.position + Vector2(_rating_panel.size.x + 8.0, 4.0 - k * 18.0)
		_rating_delta.modulate.a = clampf(_rating_flash / 0.5, 0.0, 1.0)
		if _rating_flash <= 0.0:
			_rating_delta.visible = false
	if _msg_time > 0.0:
		_msg_time -= real_delta
		var a := clampf(_msg_time / 0.3, 0.0, 1.0)
		_msg_box.modulate.a = a
		_msg_band.modulate.a = a
		if _msg_time <= 0.0:
			_msg_box.visible = false
			_msg_band.visible = false


## Chapa "TU NOTA" bajo el marcador: color según la nota y un +0.3 / -0.2 que sube y se va.
func _build_rating() -> void:
	_rating_panel = PanelContainer.new()
	add_child(_rating_panel)
	_rating_panel.position = Vector2(16, 84)  # debajo de la franja de competición del marcador
	_rating_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	_rating_panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rating_panel.add_child(row)
	var t := _label(16, row)
	t.text = "TU NOTA"
	t.label_settings.font_color = Color(1, 1, 1, 0.75)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rating_lbl = _label(26, row)
	_rating_lbl.text = "6.0"
	_rating_delta = _label(20, self)
	_rating_delta.visible = false
	_rating_panel.visible = false


static func rating_color(r: float) -> Color:
	if r >= 8.0:
		return Color(0.25, 0.9, 1.0)
	if r >= 7.0:
		return Color(0.35, 1.0, 0.45)
	if r >= 6.0:
		return Color(1.0, 0.85, 0.25)
	return Color(1.0, 0.35, 0.3)


func set_rating(r: float, change: float) -> void:
	_rating_panel.visible = true
	_rating_lbl.text = "%.1f" % r
	_rating_lbl.label_settings.font_color = rating_color(r)
	if absf(change) >= 0.05:
		_rating_delta.text = ("+%.1f" % change) if change > 0.0 else ("%.1f" % change)
		_rating_delta.label_settings.font_color = Color(0.4, 1.0, 0.5) if change > 0.0 else Color(1.0, 0.4, 0.35)
		_rating_delta.visible = true
		_rating_flash = 1.6


func update_score(score: Array, minute: float) -> void:
	_score.text = "%d - %d" % [score[0], score[1]]
	if (score[0] != _last_score[0] or score[1] != _last_score[1]) and _plate != null:
		_last_score = [score[0], score[1]]
		# pulso de la placa al cambiar el resultado
		_plate.pivot_offset = _plate.size * 0.5
		var tw := create_tween()
		tw.tween_property(_plate, "scale", Vector2(1.25, 1.25), 0.15)
		tw.tween_property(_plate, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	_minute_lbl.text = "%d'" % int(minute)
	if minute > SoccerMatch.MATCH_MINUTES:
		var et_minute := int(minute - SoccerMatch.MATCH_MINUTES)
		_minute_lbl.text = "ET %d'" % et_minute
	_update_aggregate(score)


func set_shootout_clock() -> void:
	if _minute_lbl != null:
		_minute_lbl.text = "PEN"


func set_aggregate(carry_user: int, carry_rival: int) -> void:
	_aggregate_enabled = true
	_aggregate_carry = [carry_user, carry_rival]
	_update_aggregate(_last_score)


func _update_aggregate(score: Array) -> void:
	if _aggregate_label == null or not _aggregate_enabled:
		return
	_aggregate_label.visible = true
	_aggregate_label.text = "GLOBAL · %d - %d" % [
		int(_aggregate_carry[0]) + int(score[0]), int(_aggregate_carry[1]) + int(score[1])]


## Gráfica de transmisión de cada cadena (MediaOutlets.BROADCAST de FootballCareer).
## Cada canal tiene su propio marcador: "slant" (segmentos inclinados), "pill"
## (cápsula), "block" (bloque digital) o "split" (mitades con el color de cada
## equipo). Segmentos: logo · escudo+siglas · resultado · siglas+escudo · minuto,
## con una franja de la competición debajo.
const BROADCAST := {
	"golazo_tv":     {"name": "GOLAZO TV", "bg": "#1c0c10", "accent": "#e23b3b", "radius": 3, "plate": "#ffffff", "ink": "#1c0c10", "shape": "slant"},
	"deporte_total": {"name": "DEPORTE TOTAL", "bg": "#0a1530", "accent": "#2f7fe6", "radius": 22, "plate": "#2f7fe6", "ink": "#ffffff", "shape": "pill"},
	"estadio_24":    {"name": "ESTADIO 24", "bg": "#07170e", "accent": "#18b85c", "radius": 0, "plate": "#0d2a18", "ink": "#8dffbd", "shape": "block"},
	"cancha_mas":    {"name": "CANCHA+", "bg": "#05191e", "accent": "#16c4d8", "radius": 10, "plate": "#e8fbff", "ink": "#06303a", "shape": "split"},
}

var _plate: PanelContainer
var _last_score := [0, 0]
var _aggregate_label: Label
var _aggregate_carry := [0, 0]
var _aggregate_enabled := false


## extra (opcional): {"crests": [maker, maker], "colors2": [c, c], "competition": "..."}
func setup_broadcast(channel: String, names: Array, colors: Array, extra: Dictionary = {}) -> void:
	if not BROADCAST.has(channel):
		channel = BROADCAST.keys()[0]
	_style = BROADCAST[channel]
	if _board:
		_board.queue_free()
	_aggregate_label = null
	var bg := Color(String(_style.bg))
	var accent := Color(String(_style.accent))
	var radius := int(_style.radius)
	var shape := String(_style.get("shape", "slant"))
	var skew := 0.32 if shape == "slant" else 0.0
	var crests: Array = extra.get("crests", [null, null])
	var colors2: Array = extra.get("colors2", [Color.WHITE, Color.WHITE])

	_board = PanelContainer.new()
	add_child(_board)
	_board.position = Vector2(16, 12)
	_board.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3 if shape == "slant" else 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(row)

	var n := 5
	var segs: Array[PanelContainer] = []
	for i in n:
		var seg := PanelContainer.new()
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.skew = Vector2(skew, 0.0)
		sb.content_margin_left = 10.0 + skew * 14.0
		sb.content_margin_right = 10.0 + skew * 14.0
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		sb.anti_aliasing = true
		if shape == "pill":
			# cápsula: solo los extremos redondeados
			sb.corner_radius_top_left = radius if i == 0 else 0
			sb.corner_radius_bottom_left = radius if i == 0 else 0
			sb.corner_radius_top_right = radius if i == n - 1 else 0
			sb.corner_radius_bottom_right = radius if i == n - 1 else 0
		else:
			sb.set_corner_radius_all(radius)
		match i:
			0:
				sb.bg_color = Color(bg, 0.95)
			1, 3:
				var tc: Color = colors[0 if i == 1 else 1]
				if shape == "split":
					sb.bg_color = tc.darkened(0.15)
					sb.border_color = colors2[0 if i == 1 else 1]
					sb.border_width_bottom = 3
				elif shape == "block":
					sb.bg_color = Color(bg.lightened(0.05), 0.95)
					sb.border_color = tc
					sb.border_width_top = 3
				else:
					sb.bg_color = Color(bg.lightened(0.08), 0.95)
					sb.border_color = tc
					sb.border_width_bottom = 4
			2:
				sb.bg_color = Color(String(_style.plate))
				sb.content_margin_left = 14.0 + skew * 14.0
				sb.content_margin_right = 14.0 + skew * 14.0
				if shape == "block":
					sb.border_color = accent
					sb.set_border_width_all(2)
				elif shape == "pill":
					sb.shadow_color = Color(accent, 0.6)
					sb.shadow_size = 6
			4:
				if shape == "block":
					sb.bg_color = Color(bg, 0.95)
					sb.border_color = accent
					sb.border_width_bottom = 3
				else:
					sb.bg_color = accent
		seg.add_theme_stylebox_override("panel", sb)
		row.add_child(seg)
		segs.append(seg)
	_plate = segs[2]

	var logo_path := "res://match3d/media/%s.png" % channel
	if ResourceLoader.exists(logo_path):
		var logo := TextureRect.new()
		logo.texture = load(logo_path)
		logo.custom_minimum_size = Vector2(34, 34)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segs[0].add_child(logo)
	else:
		var l0 := _label(16, segs[0])
		l0.text = String(_style.name).left(3)

	_home_lbl = _team_seg(segs[1], names[0], colors[0], colors2[0], crests[0], false)
	_score = _label(26, segs[2])
	_score.label_settings.outline_size = 0
	_score.label_settings.font_color = Color(String(_style.ink))
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score.custom_minimum_size.x = 64
	_score.text = "0 - 0"
	_last_score = [0, 0]
	_away_lbl = _team_seg(segs[3], names[1], colors[1], colors2[1], crests[1], true)
	_minute_lbl = _label(22, segs[4])
	_minute_lbl.custom_minimum_size.x = 46
	_minute_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minute_lbl.label_settings.font_color = accent.lightened(0.4) if shape == "block" else Color.WHITE
	_minute_lbl.text = "0'"

	# Franja inferior: competición (o el nombre del canal).
	var strip := PanelContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(bg.darkened(0.3), 0.85)
	ssb.skew = Vector2(skew, 0.0)
	ssb.content_margin_left = 12.0 + skew * 10.0
	ssb.content_margin_right = 12.0 + skew * 10.0
	ssb.corner_radius_bottom_left = mini(radius, 8)
	ssb.corner_radius_bottom_right = mini(radius, 8)
	ssb.border_color = accent
	ssb.border_width_left = 3
	strip.add_theme_stylebox_override("panel", ssb)
	var sl := _label(13, strip)
	sl.label_settings.outline_size = 0
	sl.label_settings.font_color = Color(1, 1, 1, 0.8)
	var comp := String(extra.get("competition", ""))
	sl.text = (comp if comp != "" else String(_style.name)).to_upper()
	stack.add_child(strip)
	_aggregate_label = _label(12, stack)
	_aggregate_label.label_settings.outline_size = 0
	_aggregate_label.label_settings.font_color = Color(String(_style.accent)).lightened(0.2)
	_aggregate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aggregate_label.visible = false

	# Mosca del canal arriba a la derecha
	var prev := get_node_or_null("Bug")
	if prev:
		remove_child(prev)
		prev.queue_free()
	var bug := _label(18, self)
	bug.name = "Bug"
	bug.text = "● EN VIVO  ·  %s" % String(_style.name)
	bug.label_settings.font_color = Color(1.0, 1.0, 1.0, 0.85)
	bug.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bug.offset_left = -300.0
	bug.offset_right = -16.0
	bug.offset_top = 14.0
	bug.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## Segmento de un equipo: escudo chico + siglas (el visitante, espejado).
func _team_seg(seg: PanelContainer, team_name: String, c: Color, c2: Color, maker: Variant, mirror: bool) -> Label:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seg.add_child(box)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(30, 30)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cr := _crest(team_name, c, c2, maker)
	cr.scale = Vector2.ONE * (30.0 / 76.0)
	holder.add_child(cr)
	var l := _label(22, box)
	l.text = team_name.substr(0, 3).to_upper()
	l.custom_minimum_size.x = 50
	# Cancha+ pinta el segmento con el color del equipo: siglas oscuras si es claro.
	if String(_style.get("shape", "")) == "split" and c.get_luminance() > 0.6:
		l.label_settings.font_color = Color(0.08, 0.1, 0.12)
		l.label_settings.outline_size = 0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(holder)
	if not mirror:
		box.move_child(holder, 0)
	return l


## Mapita de la cancha (abajo a la izquierda) durante las jugadas.
var minimap: MiniMap


func setup_minimap(m: Node, home: Color, away: Color) -> void:
	minimap = MiniMap.new()
	minimap.match_ref = m
	minimap.colors = [home, away]
	minimap.anchor_top = 1.0
	minimap.anchor_bottom = 1.0
	minimap.offset_left = 16.0
	minimap.offset_right = 16.0 + MiniMap.W
	minimap.offset_top = -MiniMap.H - 16.0
	minimap.offset_bottom = -16.0
	minimap.visible = false
	add_child(minimap)


func show_minimap(value: bool) -> void:
	if minimap != null and minimap.visible != value:
		minimap.visible = value


func set_timer(fraction: float, show: bool) -> void:
	_timer_bar.visible = show
	_timer_bar.value = clampf(fraction, 0.0, 1.0)


func set_sim_visible(value: bool) -> void:
	_sim_panel.visible = value


func add_feed(text: String) -> void:
	_feed_lines.append(text)
	while _feed_lines.size() > 3:
		_feed_lines.pop_front()
	_feed.text = _feed_lines[-1]
	var old: Array[String] = _feed_lines.slice(0, _feed_lines.size() - 1)
	_feed_old.text = "\n".join(PackedStringArray(old))
	_feed_old.visible = not old.is_empty()


func clear_feed() -> void:
	_feed_lines.clear()
	_feed.text = ""
	_feed_old.text = ""
	_feed_old.visible = false


func set_hint(text: String) -> void:
	_hint.text = text
	_hint.visible = text != ""


## top_frac: altura del mensaje (fracción de pantalla); el vestuario lo baja para no tapar su cartel.
func show_message(text: String, duration: float, top_frac := 0.16) -> void:
	var lines := text.split("
", false, 1)
	_message.text = lines[0] if lines.size() > 0 else ""
	_message_sub.text = lines[1] if lines.size() > 1 else ""
	_message_sub.visible = _message_sub.text != ""
	var vp := get_viewport().get_visible_rect().size
	var final_screen := duration > 60.0 # el resultado final se queda en el centro
	# Entre la ficha del jugador (izquierda) y el borde derecho, sin taparlas
	var margin := 0.0 if final_screen else minf(268.0, vp.x * 0.2)
	var w := vp.x - margin * 2.0
	# Ancho real antes de medir: si no, el texto con ajuste de línea se mide a ancho 0
	# (una letra por línea) y la franja oscura ocupaba media pantalla
	_message.custom_minimum_size.x = w
	_message_sub.custom_minimum_size.x = w
	_msg_box.position = Vector2(margin, 0.0)
	_msg_box.size = Vector2(w, 0.0)
	_msg_box.reset_size()
	_msg_box.size.x = w
	var h := _text_h(_message, w) + (_text_h(_message_sub, w) if _message_sub.visible else 0.0)
	var top := (vp.y - h) * 0.5 if final_screen else vp.y * top_frac
	_msg_box.position = Vector2(margin, top)
	_msg_box.size = Vector2(w, h)
	_msg_box.set_deferred("size", Vector2(w, h)) # cuando las etiquetas ya midan su ancho nuevo
	_msg_band.position = Vector2(margin, top - 6.0)
	_msg_band.size = Vector2(w, h + 12.0)
	_msg_band.self_modulate = Color(1, 1, 1, 1.4 if final_screen else 1.0)
	_msg_box.visible = true
	_msg_band.visible = true
	_msg_box.modulate.a = 1.0
	_msg_band.modulate.a = 1.0
	# Entra con un pequeño golpe de escala
	_msg_box.pivot_offset = _msg_box.size * 0.5
	_msg_box.scale = Vector2(1.18, 1.18)
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_msg_box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_msg_time = duration


## Alto del texto de una etiqueta con ajuste de línea a `w` píxeles (medido con su fuente).
func _text_h(l: Label, w: float) -> float:
	var f := l.get_theme_font("font")
	var fs := l.label_settings.font_size
	var sz := f.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, -1,
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
	return sz.y + l.label_settings.outline_size


func hide_message() -> void:
	_msg_box.visible = false
	_msg_band.visible = false
	_msg_time = 0.0


## ---------- charla con opciones (vestuario) ----------

var _choice_panel: PanelContainer


## Panel abajo con quién habla, lo que dice y botones grandes (para el dedo).
func show_choices(speaker: String, text: String, options: Array[String]) -> void:
	hide_choices()
	_choice_panel = PanelContainer.new()
	add_child(_choice_panel)
	_choice_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_choice_panel.offset_left = 40.0
	_choice_panel.offset_right = -40.0
	_choice_panel.offset_top = -230.0
	_choice_panel.offset_bottom = -16.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.86)
	sb.set_corner_radius_all(16)
	sb.border_color = Color(String(_style.get("accent", "#e23b3b")))
	sb.border_width_top = 3
	sb.set_content_margin_all(14.0)
	_choice_panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_choice_panel.add_child(col)
	var who := _label(20, col)
	who.text = speaker.to_upper()
	who.label_settings.font_color = Color(String(_style.get("accent", "#e23b3b"))).lightened(0.3)
	var said := _label(19, col)
	said.text = text
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.custom_minimum_size = Vector2(220, 56)
		b.add_theme_font_size_override("font_size", 22)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.85, 0.12, 0.15, 0.95) if i == 0 else (Color(0.16, 0.5, 0.28, 0.95) if i == 1 else Color(0.15, 0.3, 0.62, 0.95))
		bs.set_corner_radius_all(12)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, bs)
		b.pressed.connect(func() -> void:
			hide_choices()
			choice_made.emit(i))
		row.add_child(b)
	# Entra desde abajo
	_choice_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_choice_panel, "modulate:a", 1.0, 0.25)


func choices_visible() -> bool:
	return _choice_panel != null and is_instance_valid(_choice_panel)


func hide_choices() -> void:
	if choices_visible():
		_choice_panel.queue_free()
	_choice_panel = null


func _label(size: int, parent: Node) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.outline_size = maxi(4, int(size / 6.0))
	ls.outline_color = Color(0.0, 0.0, 0.0, 0.85)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


# ---------- presentación de la salida (estilo tele) ----------
## Mientras salen los equipos: primero el cartel del partido (escudos, competición,
## estadio) y luego las dos alineaciones dibujadas sobre medio campo cada una.
## data = {names [2], colors [2], colors2 [2], competition, stadium, formations [2],
##         coaches [2], lineups [2] = [[{x, y (0-1, propia portería abajo), num, name, you}]]}
var _intro: Control


## Alineaciones de la salida, a la espera de show_walkout_lineups().
var _intro_lu: Control = null

## `auto_lineups` = false: las alineaciones esperan a show_walkout_lineups() (la
## salida las muestra con la fila ya formada, no tapando a los que salen del túnel).
func show_walkout_intro(data: Dictionary, delay := 0.4, auto_lineups := true) -> void:
	hide_walkout_intro()
	_intro = Control.new()
	_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_intro)
	var card := _intro_matchup(data)
	var lineups := _intro_lineups(data)
	lineups.modulate.a = 0.0
	# Cartel: entra desde abajo, se queda y se va; luego las alineaciones
	card.modulate.a = 0.0
	var tw := _intro.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(card, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(card, "position:y", card.position.y, 0.45).from(card.position.y + 60.0) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.4)
	tw.tween_property(card, "modulate:a", 0.0, 0.3)
	_intro_lu = lineups
	if auto_lineups:
		tw.tween_callback(show_walkout_lineups)


## Muestra las alineaciones de la salida (una sola vez) y las retira solas.
func show_walkout_lineups(hold := 6.0) -> void:
	if not is_instance_valid(_intro_lu) or _intro_lu.has_meta("shown"):
		return
	_intro_lu.set_meta("shown", true)
	var tw := _intro_lu.create_tween()
	tw.tween_property(_intro_lu, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(_intro_lu, "scale", Vector2.ONE, 0.4).from(Vector2(0.92, 0.92)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(_intro_lu, "modulate:a", 0.0, 0.4)


func hide_walkout_intro() -> void:
	if is_instance_valid(_intro):
		_intro.queue_free()
	_intro = null


# ---------- marcador final (estilo tele) ----------

var _final_card: Control


## Marcador final en el centro: competición arriba, los dos escudos con el resultado
## grande en medio (el que pierde, apagado) y debajo los goleadores de cada lado con
## sus minutos. Entra con un golpe de escala y los goles aparecen uno a uno.
## data = {names, colors, colors2, crests, score: [a, b], winner: -1|0|1,
##         goals: [{team, minute, name, star}], footer: "PENALES 4 - 3", competition}
func show_final_card(data: Dictionary, hold := 6.0) -> void:
	hide_final_card()
	hide_message()
	var vp := get_viewport().get_visible_rect().size
	var w := minf(860.0, vp.x - 32.0)
	var goals: Array = data.get("goals", [])
	# Una línea por goleador y equipo: "PÉREZ  12'  67'"
	var lines: Array = [[], []]
	var order: Array = [{}, {}]
	for g: Dictionary in goals:
		var t := clampi(int(g.get("team", 0)), 0, 1)
		var who := String(g.get("name", "")).to_upper()
		if who == "":
			who = "GOL"
		if not (order[t] as Dictionary).has(who):
			order[t][who] = (lines[t] as Array).size()
			lines[t].append({"name": who, "mins": [], "star": bool(g.get("star", false))})
		lines[t][order[t][who]].mins.append("%d'" % int(g.get("minute", 0)))
	var rows := maxi((lines[0] as Array).size(), (lines[1] as Array).size())
	var bar_h := 128.0
	var list_h := 0.0 if rows == 0 else 22.0 + rows * 30.0
	var footer := String(data.get("footer", ""))
	var h := 34.0 + bar_h + list_h + (36.0 if footer != "" else 0.0) + 10.0

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(w, h)
	root.position = Vector2((vp.x - w) * 0.5, maxf(12.0, (vp.y - h) * 0.42))
	root.pivot_offset = root.size * 0.5
	add_child(root)
	_final_card = root
	var accent := Color(String(_style.get("accent", "#f2c230")))
	var gold := Color(1.0, 0.86, 0.4)

	# Cinta: FINAL · competición
	var top := String(data.get("title", "FINAL DEL PARTIDO")) # "DESCANSO" en el entretiempo
	if String(data.get("competition", "")) != "":
		top += "  ·  " + String(data.competition).to_upper()
	var tl := _label(22, root)
	tl.text = top
	tl.size = Vector2(w, 30.0)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.label_settings.font_color = gold

	var bar := Panel.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(0.0, 34.0)
	bar.size = Vector2(w, bar_h + list_h)
	bar.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.94)
	sb.set_corner_radius_all(16)
	sb.border_width_bottom = 5
	sb.border_color = accent
	bar.add_theme_stylebox_override("panel", sb)
	root.add_child(bar)
	var winner := int(data.get("winner", -1))
	var score: Array = data.get("score", [0, 0])
	var mid := 190.0 # ancho del bloque del resultado
	for t in 2:
		var c: Color = data.colors[t]
		var c2: Color = data.colors2[t]
		var lost := winner >= 0 and winner != t
		var half := ColorRect.new()
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hc := c.darkened(0.3 if lost else 0.08)
		half.color = Color(hc, 0.9)
		var ink := Color(0.06, 0.07, 0.1) if hc.get_luminance() > 0.62 else Color.WHITE
		half.size = Vector2((w - mid) * 0.5, bar_h)
		half.position = Vector2(0.0 if t == 0 else (w + mid) * 0.5, 0.0)
		bar.add_child(half)
		var crest := _crest(String(data.names[t]), c, c2, (data.get("crests", [null, null]) as Array)[t])
		crest.position = Vector2(18.0 if t == 0 else w - 18.0 - 76.0, (bar_h - 76.0) * 0.5)
		crest.modulate = Color(1, 1, 1, 0.55) if lost else Color.WHITE
		bar.add_child(crest)
		var tname := String(data.names[t]).to_upper()
		var nw := (w - mid) * 0.5 - 116.0
		var nl := _label(32, bar)
		nl.text = tname
		nl.clip_text = true
		var nls: LabelSettings = nl.label_settings
		var nf: Font = nls.font if nls.font else nl.get_theme_font("font")
		while nls.font_size > 15 and nf.get_string_size(tname, HORIZONTAL_ALIGNMENT_LEFT, -1, nls.font_size).x > nw:
			nls.font_size -= 1
		nls.font_color = ink
		if ink != Color.WHITE:
			nls.outline_size = 0
		nl.size = Vector2(nw, bar_h)
		nl.position = Vector2(104.0 if t == 0 else (w + mid) * 0.5 + 12.0, 0.0)
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if t == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		if lost:
			nl.label_settings.font_color = Color(ink, 0.7)
		if winner == t:
			var tag := _label(16, bar)
			tag.text = "GANADOR"
			tag.label_settings.font_color = gold
			tag.size = nl.size
			tag.position = nl.position + Vector2(0.0, 34.0)
			tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			tag.horizontal_alignment = nl.horizontal_alignment
	var sc := _label(64, bar)
	sc.text = "%d - %d" % [int(score[0]), int(score[1])]
	sc.size = Vector2(mid, bar_h)
	sc.position = Vector2((w - mid) * 0.5, 0.0)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sc.label_settings.font_color = Color.WHITE if winner < 0 else gold

	# Goleadores: una columna por equipo, pegadas al centro
	var items: Array[Control] = []
	if rows > 0:
		var cap := _label(13, bar)
		cap.text = "GOLES"
		cap.label_settings.font_color = Color(1, 1, 1, 0.5)
		cap.size = Vector2(w, 18.0)
		cap.position = Vector2(0.0, bar_h + 4.0)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for t in 2:
			for i in (lines[t] as Array).size():
				var ln: Dictionary = lines[t][i]
				var gl := _label(20, bar)
				var mins := "  ".join(PackedStringArray(ln.mins))
				gl.text = (String(ln.name) + "   " + mins) if t == 0 else (mins + "   " + String(ln.name))
				gl.clip_text = true
				gl.size = Vector2(w * 0.5 - 40.0, 28.0)
				gl.position = Vector2(16.0 if t == 0 else w * 0.5 + 24.0, bar_h + 22.0 + i * 30.0)
				gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if t == 0 else HORIZONTAL_ALIGNMENT_LEFT
				if bool(ln.star):
					gl.label_settings.font_color = gold
				gl.modulate.a = 0.0
				items.append(gl)
		var line := ColorRect.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.color = Color(1, 1, 1, 0.18)
		line.size = Vector2(2.0, rows * 30.0 - 4.0)
		line.position = Vector2(w * 0.5 - 1.0, bar_h + 24.0)
		bar.add_child(line)
	if footer != "":
		var fl := _label(22, root)
		fl.text = footer
		fl.size = Vector2(w, 30.0)
		fl.position = Vector2(0.0, 34.0 + bar_h + list_h + 8.0)
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fl.label_settings.font_color = gold

	root.modulate.a = 0.0
	var tw := root.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(root, "scale", Vector2.ONE, 0.45).from(Vector2(1.15, 1.15)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for it in items:
		tw.tween_property(it, "modulate:a", 1.0, 0.2)
		tw.parallel().tween_property(it, "position:y", it.position.y, 0.2).from(it.position.y + 10.0)
	tw.tween_interval(hold)
	tw.tween_property(root, "modulate:a", 0.0, 0.5)
	tw.tween_callback(root.queue_free)


func hide_final_card() -> void:
	if is_instance_valid(_final_card):
		_final_card.queue_free()
	_final_card = null


## Franja del partido abajo en el centro: [escudo] LOCAL  VS  VISITA [escudo].
func _intro_matchup(data: Dictionary) -> Control:
	var vp := get_viewport().get_visible_rect().size
	var w := minf(900.0, vp.x - 40.0)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(w, 150.0)
	root.position = Vector2((vp.x - w) * 0.5, vp.y - 150.0 - 70.0)
	root.pivot_offset = root.size * 0.5
	_intro.add_child(root)
	# Cinta superior: competición · estadio
	var top := String(data.get("competition", ""))
	if String(data.get("stadium", "")) != "":
		top += ("  ·  " if top != "" else "") + String(data.stadium)
	if top != "":
		var tl := _label(20, root)
		tl.text = top.to_upper()
		tl.size = Vector2(w, 26.0)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.label_settings.font_color = Color(1.0, 0.86, 0.4)
	var bar := Panel.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(0.0, 32.0)
	bar.size = Vector2(w, 96.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.92)
	sb.set_corner_radius_all(14)
	sb.border_width_bottom = 4
	sb.border_color = Color(String(_style.get("accent", "#f2c230")))
	bar.add_theme_stylebox_override("panel", sb)
	root.add_child(bar)
	for t in 2:
		var c: Color = data.colors[t]
		var c2: Color = data.colors2[t]
		# Medio panel con el color del club
		var half := ColorRect.new()
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		half.color = Color(c, 0.85)
		half.size = Vector2(w * 0.5 - 70.0, 96.0)
		half.position = Vector2(0.0 if t == 0 else w * 0.5 + 70.0, 0.0)
		bar.add_child(half)
		var crest := _crest(String(data.names[t]), c, c2, (data.get("crests", [null, null]) as Array)[t])
		crest.position = Vector2(14.0 if t == 0 else w - 14.0 - 76.0, 10.0)
		bar.add_child(crest)
		var tname := String(data.names[t]).to_upper()
		var nl := _label(int(clampf(36.0 * 13.0 / maxf(tname.length(), 1.0), 22.0, 36.0)), bar)
		nl.text = tname
		nl.clip_text = true
		nl.size = Vector2(w * 0.5 - 70.0 - 110.0, 50.0)
		nl.position = Vector2(100.0 if t == 0 else w * 0.5 + 80.0, 12.0)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if t == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var fl := _label(18, bar)
		fl.text = String(data.formations[t])
		fl.label_settings.font_color = Color(1, 1, 1, 0.8)
		fl.size = nl.size
		fl.position = nl.position + Vector2(0.0, 48.0)
		fl.horizontal_alignment = nl.horizontal_alignment
	var vs := _label(42, bar)
	vs.text = "VS"
	vs.size = Vector2(140.0, 96.0)
	vs.position = Vector2(w * 0.5 - 70.0, 0.0)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs.label_settings.font_color = Color(1.0, 0.86, 0.4)
	return root


## Escudo sencillo: forma de escudo con los dos colores y las iniciales.
## Escudo del equipo: el real del RPG (maker: Callable -> Control) escalado a 76 px;
## si no hay, uno dibujado con los colores y las siglas.
func _crest(team_name: String, c: Color, c2: Color, maker: Variant = null) -> Control:
	if maker is Callable and (maker as Callable).is_valid():
		var real: Variant = (maker as Callable).call()
		if real is Control:
			var box := Control.new()
			box.custom_minimum_size = Vector2(76, 76)
			box.size = Vector2(76, 76)
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var rc := real as Control
			var base := maxf(maxf(rc.custom_minimum_size.x, rc.size.x), 1.0)
			rc.scale = Vector2.ONE * (76.0 / base)
			box.add_child(rc)
			return box
	var cr := _Crest.new()
	cr.c1 = c
	cr.c2 = c2
	var ini := ""
	for w: String in team_name.split(" ", false):
		if ini.length() < 2 and (w.length() > 3 or ini == ""):
			ini += w.left(1) # sin "de", "del", "FC"...
	cr.initials = ini.to_upper()
	cr.custom_minimum_size = Vector2(76, 76)
	cr.size = Vector2(76, 76)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cr


## Las dos alineaciones lado a lado, cada una sobre medio campo vertical.
func _intro_lineups(data: Dictionary) -> Control:
	var vp := get_viewport().get_visible_rect().size
	var card_w := minf(330.0, (vp.x - 60.0) * 0.5)
	var pitch_h := minf(400.0, vp.y - 250.0)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(card_w * 2.0 + 24.0, pitch_h + 100.0)
	root.position = Vector2((vp.x - root.size.x) * 0.5, maxf(70.0, (vp.y - root.size.y) * 0.5 - 10.0))
	root.pivot_offset = root.size * 0.5
	_intro.add_child(root)
	for t in 2:
		var c: Color = data.colors[t]
		var x0 := t * (card_w + 24.0)
		var bg := Panel.new()
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.position = Vector2(x0, 0.0)
		bg.size = Vector2(card_w, root.size.y)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.06, 0.09, 0.9)
		sb.set_corner_radius_all(14)
		sb.border_width_top = 6
		sb.border_color = c
		bg.add_theme_stylebox_override("panel", sb)
		root.add_child(bg)
		var title := _label(20 if String(data.names[t]).length() <= 15 else 17, bg)
		title.text = String(data.names[t]).to_upper()
		title.clip_text = true
		title.size = Vector2(card_w - 20.0, 24.0)
		# El nombre del equipo y la formación van en líneas separadas para que
		# nunca se corte el dibujo del sistema táctico en móvil.
		var ls: LabelSettings = title.label_settings
		var fnt: Font = ls.font if ls.font else title.get_theme_font("font")
		while ls.font_size > 12 and fnt.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ls.font_size).x > card_w - 24.0:
			ls.font_size -= 1
		title.position = Vector2(10.0, 8.0)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var formation := _label(14, bg)
		formation.text = String(data.formations[t])
		formation.label_settings.font_color = Color(1.0, 0.84, 0.38)
		formation.size = Vector2(card_w - 20.0, 18.0)
		formation.position = Vector2(10.0, 30.0)
		formation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var pitch := _Pitch.new()
		pitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pitch.position = Vector2(12.0, 52.0)
		pitch.size = Vector2(card_w - 24.0, pitch_h)
		bg.add_child(pitch)
		for pl: Dictionary in data.lineups[t]:
			var dot := _player_dot(int(pl.num), String(pl.name), c, Color(data.colors2[t]), bool(pl.get("you", false)))
			dot.position = Vector2(float(pl.x) * pitch.size.x, float(pl.y) * pitch.size.y) - Vector2(40.0, 15.0)
			pitch.add_child(dot)
		var coach := String(data.coaches[t])
		if coach != "":
			var cl := _label(17, bg)
			cl.text = "DT: " + coach
			cl.label_settings.font_color = Color(1, 1, 1, 0.75)
			cl.size = Vector2(card_w - 20.0, 26.0)
			cl.position = Vector2(10.0, 58.0 + pitch_h)
			cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return root


## Círculo con el dorsal y el apellido debajo; tú, con aro dorado.
func _player_dot(num: int, pname: String, c: Color, c2: Color, you: bool) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size = Vector2(80.0, 48.0)
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size = Vector2(30.0, 30.0)
	p.position = Vector2(25.0, 0.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(15)
	sb.set_border_width_all(3 if you else 2)
	sb.border_color = Color(1.0, 0.82, 0.25) if you else c2
	p.add_theme_stylebox_override("panel", sb)
	box.add_child(p)
	var n := _label(16, p)
	n.text = str(num)
	n.size = p.size
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var l := _label(13, box)
	l.text = pname
	l.size = Vector2(80.0, 18.0)
	l.position = Vector2(0.0, 30.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	if you:
		l.label_settings.font_color = Color(1.0, 0.86, 0.4)
	return box


## Campo vertical en miniatura (la portería propia abajo).
class _Pitch extends Control:
	func _draw() -> void:
		var s := size
		for i in 8:
			var col := Color(0.16, 0.45, 0.22) if i % 2 == 0 else Color(0.18, 0.5, 0.25)
			draw_rect(Rect2(0.0, s.y * i / 8.0, s.x, s.y / 8.0), col)
		var line := Color(1, 1, 1, 0.55)
		draw_rect(Rect2(Vector2.ZERO, s), line, false, 2.0)
		draw_line(Vector2(0.0, s.y * 0.5), Vector2(s.x, s.y * 0.5), line, 2.0)
		draw_arc(s * 0.5, s.x * 0.16, 0.0, TAU, 40, line, 2.0)
		for y: float in [0.0, 1.0]:
			var bw := s.x * 0.56
			var bh := s.y * 0.16
			draw_rect(Rect2((s.x - bw) * 0.5, y * (s.y - bh), bw, bh), line, false, 2.0)


## Escudo dibujado: dos mitades de color, borde y siglas.
class _Crest extends Control:
	var c1 := Color.RED
	var c2 := Color.WHITE
	var initials := ""

	func _draw() -> void:
		var s := size
		var pts := PackedVector2Array([Vector2(0.08, 0.04), Vector2(0.92, 0.04), Vector2(0.92, 0.5),
				Vector2(0.5, 0.97), Vector2(0.08, 0.5)])
		for i in pts.size():
			pts[i] *= s
		draw_colored_polygon(pts, c1)
		var right := PackedVector2Array([Vector2(0.5, 0.04) * s, pts[1], pts[2], pts[3]])
		draw_colored_polygon(right, c2.lerp(c1, 0.15))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(1, 1, 1, 0.9), 3.0, true)
		var f := ThemeDB.fallback_font
		var fs := 26
		var tw := f.get_string_size(initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2((s.x - tw) * 0.5, s.y * 0.56)
		draw_string_outline(f, at, initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.8))
		draw_string(f, at, initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
