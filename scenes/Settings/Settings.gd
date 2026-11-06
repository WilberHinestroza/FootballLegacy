extends Control

## Ajustes — organizado por PESTAÑAS (pedido de Wilber): Audio · Juego ·
## Interfaz. Todo se guarda en autoloads (Audio / Preferences), nunca en
## el save de una carrera.

@onready var back_button: Button = $Root/VBox/BackButton

var _tab: String = "audio"
var _tabs_row: BoxContainer
var _content: VBoxContainer

func _ready() -> void:
	var bg := Styles.screen_bg()
	add_child(bg)
	move_child(bg, 0)

	var vbox := $Root/VBox as VBoxContainer
	# Ocultar las filas viejas del .tscn — todo se rearma en pestañas.
	for n in ["CurrencyLabel", "CurrencyRow", "SoundLabel", "SoundRow"]:
		var node := vbox.get_node_or_null(n)
		if node is CanvasItem:
			(node as CanvasItem).visible = false

	back_button.pressed.connect(_on_back_pressed)
	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)

	var land: bool = get_viewport_rect().size.x > get_viewport_rect().size.y
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if land:
		# HORIZONTAL: menú lateral (como los ajustes de una consola) y las
		# opciones en un panel a la derecha. "Volver" va arriba del menú.
		var body := HBoxContainer.new()
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 18)
		vbox.add_child(body)
		vbox.move_child(body, back_button.get_index())
		var side := VBoxContainer.new()
		side.custom_minimum_size.x = 240
		side.add_theme_constant_override("separation", 10)
		body.add_child(side)
		back_button.reparent(side)
		back_button.custom_minimum_size = Vector2(0, 44)
		_tabs_row = VBoxContainer.new()
		_tabs_row.add_theme_constant_override("separation", 8)
		side.add_child(_tabs_row)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var psb := Styles.card_flat(Color(0.09, 0.1, 0.12, 0.92), 16)
		psb.content_margin_left = 22
		psb.content_margin_right = 22
		psb.content_margin_top = 16
		psb.content_margin_bottom = 12
		panel.add_theme_stylebox_override("panel", psb)
		body.add_child(panel)
		panel.add_child(sc)
		var root := $Root as MarginContainer
		for side_name in ["top", "bottom"]:
			root.add_theme_constant_override("margin_" + side_name, 18)
	else:
		_tabs_row = HBoxContainer.new()
		_tabs_row.add_theme_constant_override("separation", 6)
		vbox.add_child(_tabs_row)
		vbox.move_child(_tabs_row, back_button.get_index())
		vbox.add_child(sc)
		vbox.move_child(sc, back_button.get_index())
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_content)
	UiScroll.make_touch(self)

	_render()

func _render() -> void:
	for c in _tabs_row.get_children():
		c.queue_free()
	for pair in [["audio", "Audio", "audioOn"], ["game", "Juego", "gamepad"], ["ui", "Interfaz", "gear"]]:
		var b := Button.new()
		b.text = String(pair[1])
		b.icon = Icons.game(String(pair[2]))
		b.add_theme_constant_override("icon_max_width", 18)
		b.expand_icon = false
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		if _tabs_row is VBoxContainer:
			b.custom_minimum_size = Vector2(0, 54)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 17)
			b.add_theme_constant_override("icon_max_width", 24)
		b.focus_mode = Control.FOCUS_NONE
		var on: bool = _tab == String(pair[0])
		Styles.styled_button(b, Styles.pill_filled(Styles.GREEN) if on else Styles.pill_outlined(Styles.GRAY_TEXT), Color.BLACK if on else Styles.GRAY_TEXT)
		b.pressed.connect(func(k = String(pair[0])):
			_tab = k
			_render())
		_tabs_row.add_child(b)

	for c in _content.get_children():
		c.queue_free()
	match _tab:
		"game":
			_tab_game()
		"ui":
			_tab_ui()
		_:
			_tab_audio()
	UiScroll.pad_bottom(_content, 24)

# ---------------------------------------------------------------------------
# AUDIO
# ---------------------------------------------------------------------------

func _tab_audio() -> void:
	# Vibración: independiente del audio, va primero para que se vea aunque
	# el audio esté apagado.
	_content.add_child(_toggle_row("Vibración", Haptics.enabled,
		func(v): Haptics.set_enabled(v)))
	_content.add_child(_thin_divider())

	_content.add_child(_toggle_row("Todo el audio", Audio.enabled, func(v):
		Audio.set_enabled(v)
		_render()))
	if not Audio.enabled:
		var off := Label.new()
		off.text = "El audio está apagado. Activalo para ajustar cada canal."
		off.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		off.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		_content.add_child(off)
		return

	_content.add_child(_thin_divider())
	_content.add_child(_channel("Música del juego", Audio.music_enabled, Audio.music_volume,
		func(v): Audio.set_music_enabled(v),
		func(v): Audio.set_music_volume(v)))

	_content.add_child(_channel("Sonido ambiente (hinchada, partido)", Audio.ambience_enabled, Audio.ambience_volume,
		func(v): Audio.set_ambience_enabled(v),
		func(v):
			Audio.set_ambience_volume(v)
			Audio.match_sfx("tick")))

	_content.add_child(_channel("Sonidos de botones", Audio.ui_enabled, Audio.ui_volume,
		func(v): Audio.set_ui_enabled(v),
		func(v):
			Audio.set_ui_volume(v)
			Audio.play("click")))

## Un canal: título + toggle Sí/No + slider de volumen (deshabilitado si off).
func _channel(title: String, on: bool, vol: float, on_toggle: Callable, on_vol: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_toggle_row(title, on, func(v):
		on_toggle.call(v)
		_render()))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = vol
	s.custom_minimum_size = Vector2(0, 30)
	s.editable = on
	Styles.style_slider(s)
	s.value_changed.connect(func(v): on_vol.call(v))
	box.add_child(s)
	return box

# ---------------------------------------------------------------------------
# JUEGO
# ---------------------------------------------------------------------------

func _tab_game() -> void:
	_content.add_child(_section("Ritmo del partido"))
	_content.add_child(_choice_row(
		[["Detallado", "lento"], ["Normal", "normal"], ["Rápido", "rapido"]],
		Preferences.match_speed,
		func(k):
			Preferences.set_match_speed(k)
			get_tree().reload_current_scene()))

	_content.add_child(_toggle_row("Confirmar antes de avanzar días", Preferences.confirm_advance,
		func(v): Preferences.set_confirm_advance(v)))
	_content.add_child(_toggle_row("Menos animaciones (público, confeti…)", Preferences.reduce_motion,
		func(v): Preferences.set_reduce_motion(v)))
	# Partido 3D (31-oct): titular en partidos de club. Apagado = el de siempre.
	_content.add_child(_toggle_row("Partido 3D", Preferences.match_3d,
		func(v): Preferences.set_match_3d(v)))

	_content.add_child(_thin_divider())
	_content.add_child(_section("Asistencia de puntería (partido 3D)"))
	_content.add_child(_choice_row(
		[["Alta", "alta"], ["Media", "media"], ["Manual", "manual"]],
		Preferences.aim_assist,
		func(k):
			Preferences.set_aim_assist(k)
			_render()))

# ---------------------------------------------------------------------------
# INTERFAZ
# ---------------------------------------------------------------------------

func _tab_ui() -> void:
	_content.add_child(_section("Moneda"))
	_content.add_child(_choice_row(
		[["Euro (€)", "EUR"], ["Dólar ($)", "USD"]],
		Preferences.currency,
		func(k):
			Preferences.set_currency(k)
			_render()))

	_content.add_child(_thin_divider())
	_content.add_child(_section("Tamaño del texto"))
	_content.add_child(_choice_row(
		[["Normal", "normal"], ["Grande", "grande"]],
		Preferences.text_scale,
		func(k):
			Preferences.set_text_scale(k)
			get_tree().reload_current_scene()))

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _choice_row(opts: Array, current: String, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for opt in opts:
		var b := Button.new()
		b.text = String(opt[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.focus_mode = Control.FOCUS_NONE
		var key: String = String(opt[1])
		var on: bool = current == key
		Styles.styled_button(b, Styles.pill_filled(Styles.GREEN) if on else Styles.pill_outlined(Styles.GRAY_TEXT), Color.BLACK if on else Color.WHITE)
		b.pressed.connect(func(k = key): on_pick.call(k))
		row.add_child(b)
	return row

func _toggle_row(label_text: String, initial: bool, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 44)
	var l := Label.new()
	l.text = label_text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var b := Button.new()
	b.custom_minimum_size = Vector2(64, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var state := {"on": initial}
	var refresh := func():
		b.text = "Sí" if state["on"] else "No"
		Styles.styled_button(b, Styles.pill_filled(Styles.GREEN) if state["on"] else Styles.pill_outlined(Styles.GRAY_TEXT),
			Color.BLACK if state["on"] else Styles.GRAY_TEXT)
	refresh.call()
	b.pressed.connect(func():
		state["on"] = not state["on"]
		on_change.call(state["on"])
		refresh.call())
	row.add_child(b)
	return row

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Styles.font_semibold())
	l.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	return l

func _thin_divider() -> Control:
	var c := ColorRect.new()
	c.color = Color(1, 1, 1, 0.07)
	c.custom_minimum_size = Vector2(0, 1)
	return c

func _on_back_pressed() -> void:
	if Nav.can_go_back():
		Nav.back()
	else:
		get_tree().change_scene_to_file("res://scenes/Start/Start.tscn")
