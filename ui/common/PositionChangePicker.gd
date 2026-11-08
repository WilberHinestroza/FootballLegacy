extends Control
class_name PositionChangePicker
## Hablar con el DT de tu posición (PositionChangeEngine): cada puesto de campo
## con tu encaje (atributos), tu familiaridad y lo que opina el DT; botón para
## pedirlo. Si el DT te propuso un cambio, arriba aparece para aceptar o no.
## Emite `changed` cuando cambias de puesto.

signal changed

var _player: PlayerData
var _wseed := 0
var _blocker := ""
var _info: Label
var _list: VBoxContainer

func setup(player: PlayerData) -> void:
	_player = player
	_wseed = SaveManager.load_world_seed()
	_blocker = PositionChangeEngine.blocker(player, WorldTickEngine.season, WorldTickEngine.current_epoch_day)

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
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.BLUE))
	center.add_child(panel)
	var m := MarginContainer.new()
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 16)
	for s in ["top", "bottom"]: m.add_theme_constant_override("margin_" + s, 12)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	var title := Label.new()
	title.text = "Tu posición · %s" % Positions.label_of(_player.detailed_position)
	title.add_theme_font_override("font", Styles.font_black())
	title.add_theme_font_size_override("font_size", 22)
	v.add_child(title)
	var offer: Dictionary = PositionChangeEngine.pending_offer(WorldTickEngine.season, WorldTickEngine.current_epoch_day)
	if not offer.is_empty():
		v.add_child(_offer_card(String(offer.code)))
	_info = Label.new()
	_info.custom_minimum_size = Vector2(720, 0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	if _blocker != "":
		_info.text = _blocker
		_info.add_theme_color_override("font_color", Styles.AMBER)
	else:
		_info.text = "Encaje: cuánto encajan tus atributos en el puesto. Familiaridad: cuánto lo conoces; sube jugando ahí y, sin adaptar, rindes algo menos. Puedes pedir un cambio por temporada."
		_info.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(_info)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiScroll.make_touch(scroll)
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	for code in PositionChangeEngine.outfield_codes():
		_list.add_child(_row(code))
	var close := Button.new()
	close.text = "Cerrar"
	close.custom_minimum_size = Vector2(0, 42)
	close.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(close, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	close.pressed.connect(_close)
	v.add_child(close)

func _offer_card(code: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	var l := Label.new()
	l.text = "  El DT te propone jugar de %s (encaje %d%% frente a %d%%)" % [
		Positions.label_of(code).to_lower(), PositionChangeEngine.fit(_player, code),
		PositionChangeEngine.fit(_player, _player.detailed_position)]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", Styles.GOLD)
	h.add_child(l)
	for yes in [true, false]:
		var b := Button.new()
		b.text = "Aceptar" if yes else "No"
		b.custom_minimum_size = Vector2(96, 40)
		b.focus_mode = Control.FOCUS_NONE
		Styles.styled_button(b, Styles.pill_filled(Styles.GOLD) if yes else Styles.pill_outlined(Styles.GRAY_TEXT), Color.BLACK if yes else Color.WHITE)
		b.pressed.connect(_answer.bind(yes))
		h.add_child(b)
	return card

func _verdict(code: String) -> Array:
	var c: float = PositionChangeEngine.accept_chance(_player, code)
	if c <= 0.0:
		return ["No te ve ahí", Styles.RED]
	if c >= 0.65:
		return ["Probable", Styles.GREEN]
	if c >= 0.35:
		return ["Posible", Styles.AMBER]
	return ["Difícil", Styles.AMBER]

func _row(code: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var mine: bool = code == _player.detailed_position
	var second: bool = code == _player.secondary_detailed_position
	var nm := Label.new()
	nm.text = "%s  %s" % [Positions.label_of(code), "· tu puesto" if mine else ("· 2ª posición" if second else "")]
	nm.custom_minimum_size = Vector2(300, 0)
	nm.clip_text = true
	nm.add_theme_color_override("font_color", Styles.GOLD if mine else Color.WHITE)
	row.add_child(nm)
	var f: int = PositionChangeEngine.fit(_player, code)
	var fl := Label.new()
	fl.text = "Encaje %d%%" % f
	fl.custom_minimum_size = Vector2(110, 0)
	fl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	row.add_child(fl)
	var fam: int = PositionChangeEngine.familiarity(_player, code)
	var fa := Label.new()
	fa.text = "Familiaridad %d%%" % fam
	fa.custom_minimum_size = Vector2(150, 0)
	fa.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	fa.add_theme_color_override("font_color", Styles.GREEN if fam >= 85 else (Styles.AMBER if fam >= 40 else Styles.GRAY_TEXT))
	row.add_child(fa)
	if mine:
		return row
	var vd: Array = _verdict(code)
	var vl := Label.new()
	vl.text = String(vd[0])
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	vl.add_theme_color_override("font_color", vd[1])
	row.add_child(vl)
	var b := Button.new()
	b.text = "Pedir"
	b.custom_minimum_size = Vector2(80, 34)
	b.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(b, Styles.pill_outlined(Styles.BLUE), Styles.BLUE)
	b.disabled = _blocker != ""
	b.pressed.connect(_ask.bind(code))
	row.add_child(b)
	return row

func _ask(code: String) -> void:
	var season: Dictionary = WorldTickEngine.season
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("pos_ask:%d:%s" % [WorldTickEngine.current_epoch_day, code]) ^ _wseed
	var res: Dictionary = PositionChangeEngine.request(_player, season, code, WorldTickEngine.current_epoch_day, rng, _wseed)
	if bool(res.get("asked", false)):
		SaveManager.save_player(_player)
		SaveManager.save_season(season)
	if bool(res.get("ok", false)):
		_press_change(code)
		Nav.toast(String(res.message))
		changed.emit()
		_close()
		return
	_info.text = String(res.get("message", ""))
	_info.add_theme_color_override("font_color", Styles.AMBER)
	_blocker = PositionChangeEngine.blocker(_player, season, WorldTickEngine.current_epoch_day)
	for c in _list.get_children():
		c.queue_free()
	for c in PositionChangeEngine.outfield_codes():
		_list.add_child(_row(c))

func _answer(yes: bool) -> void:
	var season: Dictionary = WorldTickEngine.season
	var code: String = String(PositionChangeEngine.pending_offer(season, WorldTickEngine.current_epoch_day).get("code", ""))
	var msg: String = PositionChangeEngine.answer_offer(_player, season, yes, _wseed)
	SaveManager.save_player(_player)
	SaveManager.save_season(season)
	if yes and code != "":
		_press_change(code)
	Nav.toast(msg)
	changed.emit()
	_close()

func _press_change(code: String) -> void:
	PressGenerator.append_to_feed(_player, {
		"headline": "%s cambia de puesto: ahora juega de %s" % [Nickname.press_name(_player, _wseed), Positions.label_of(code).to_lower()],
		"body": "Su entrenador lo ve en otro sitio. Le tocará adaptarse unos partidos.",
		"source": "CLUB", "sentiment": "NEUTRAL",
	}, WorldTickEngine.current_epoch_day)
	SaveManager.save_player(_player)

func _close() -> void:
	if get_parent() is CanvasLayer:
		get_parent().queue_free()
	else:
		queue_free()

static func open(host: Node, player: PlayerData) -> PositionChangePicker:
	var layer := CanvasLayer.new()
	layer.layer = 60
	var picker := PositionChangePicker.new()
	picker.setup(player)
	layer.add_child(picker)
	host.add_child(layer)
	return picker
