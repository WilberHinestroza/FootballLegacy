extends Control
class_name ShirtNumberPicker
## Ventana para elegir dorsal (ShirtNumberEngine): números del 1 al 99 con su
## estado — el tuyo (dorado), libres (verde), del referente que te puedes ganar
## (borde dorado), ocupados o bloqueados (apagados). Al elegir guarda, avisa a la
## prensa si es el 10/7/9 y emite `chosen`.

signal chosen(number: int)

var _player: PlayerData
var _club_bo := -1
var _captain := false
var _wseed := 0
var _blocker := ""
var _info: Label

func setup(player: PlayerData, club_base_overall: int, is_captain: bool) -> void:
	_player = player
	_club_bo = club_base_overall
	_captain = is_captain
	_wseed = SaveManager.load_world_seed()
	_blocker = ShirtNumberEngine.blocker(player, WorldTickEngine.season, WorldTickEngine.is_transfer_window_open())

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
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD))
	center.add_child(panel)
	var m := MarginContainer.new()
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 16)
	for s in ["top", "bottom"]: m.add_theme_constant_override("margin_" + s, 12)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	var title := Label.new()
	title.text = "Elige tu dorsal"
	title.add_theme_font_override("font", Styles.font_black())
	title.add_theme_font_size_override("font_size", 22)
	v.add_child(title)
	_info = Label.new()
	_info.custom_minimum_size = Vector2(600, 0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	if _blocker != "":
		_info.text = _blocker
		_info.add_theme_color_override("font_color", Styles.AMBER)
	else:
		_info.text = "Verde: libre. Borde dorado: número de referente que ya te has ganado. Apagados: los llevan tus compañeros o son del referente. Solo puedes cambiarlo una vez por temporada."
		_info.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(_info)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for n in range(1, 100):
		grid.add_child(_number_button(n))
	var close := Button.new()
	close.text = "Cerrar"
	close.custom_minimum_size = Vector2(0, 42)
	close.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(close, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	close.pressed.connect(_close)
	v.add_child(close)

func _number_button(n: int) -> Button:
	var b := Button.new()
	b.text = str(n)
	b.custom_minimum_size = Vector2(54, 42)
	b.focus_mode = Control.FOCUS_NONE
	var st: String = ShirtNumberEngine.status(_player, _wseed, n, _club_bo, _captain)
	match st:
		"mine":
			Styles.styled_button(b, Styles.pill_filled(Styles.GOLD), Color.BLACK)
		"free":
			Styles.styled_button(b, Styles.pill_outlined(Styles.GREEN), Styles.GREEN)
		"iconic_free":
			Styles.styled_button(b, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
		"iconic_locked":
			Styles.styled_button(b, Styles.pill_outlined(Styles.RED), Styles.RED)
			b.modulate = Color(1, 1, 1, 0.45)
		_:
			Styles.styled_button(b, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
			b.modulate = Color(1, 1, 1, 0.3)
	if _blocker != "" or st == "mine":
		b.disabled = st != "mine"
		return b
	b.pressed.connect(_pick.bind(n))
	return b

func _pick(n: int) -> void:
	var season: Dictionary = WorldTickEngine.season
	var res: Dictionary = ShirtNumberEngine.choose(_player, season, _wseed, n, _club_bo, _captain, WorldTickEngine.is_transfer_window_open())
	if not bool(res.get("ok", false)):
		_info.text = String(res.get("message", ""))
		_info.add_theme_color_override("font_color", Styles.AMBER)
		return
	if bool(res.get("iconic", false)):
		PressGenerator.append_to_feed(_player, {
			"headline": "%s se queda con el %d" % [Nickname.press_name(_player, _wseed), n],
			"body": "El vestuario le cede el dorsal de los referentes. Ahora toca estar a la altura.",
			"source": "CLUB", "sentiment": "POSITIVE",
		}, WorldTickEngine.current_epoch_day)
	SaveManager.save_player(_player)
	SaveManager.save_season(season)
	Nav.toast(String(res.get("message", "")))
	chosen.emit(n)
	_close()

## Se abre dentro de su propia CanvasLayer (open()): al cerrar se va con ella.
func _close() -> void:
	if get_parent() is CanvasLayer:
		get_parent().queue_free()
	else:
		queue_free()

## Abre el selector encima de todo, a pantalla completa.
static func open(host: Node, player: PlayerData, club_base_overall: int, is_captain: bool) -> ShirtNumberPicker:
	var layer := CanvasLayer.new()
	layer.layer = 60
	var picker := ShirtNumberPicker.new()
	picker.setup(player, club_base_overall, is_captain)
	layer.add_child(picker)
	host.add_child(layer)
	return picker
