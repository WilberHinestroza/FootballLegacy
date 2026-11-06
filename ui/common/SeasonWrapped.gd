extends Control
class_name SeasonWrapped
const _M3D = preload("res://engine/match/m3d/Match3DBridge.gd")  # retrato 3D

## "TU TEMPORADA" tipo Wrapped (P5, 10-oct): tarjetas a pantalla completa,
## una tras otra al tocar, con los números contando. Datos de
## WorldTickEngine.last_season_report["wrapped"] (ya calculados).

signal closed

var _data: Dictionary = {}
var _year: int = 0
var _player: PlayerData
var _slides: Array = []
var _i: int = 0
var _holder: Control

static func open(host: Node, report: Dictionary) -> SeasonWrapped:
	var layer := CanvasLayer.new()
	layer.layer = 97
	host.add_child(layer)
	var w := SeasonWrapped.new()
	w._data = report.get("wrapped", {})
	w._year = int(report.get("start_year", 0))
	w.closed.connect(layer.queue_free)
	layer.add_child(w)
	return w

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("nav_back_handlers")
	_player = SaveManager.load_player()
	var d := _data
	_slides = [
		["TU TEMPORADA", "%d/%d" % [_year, _year + 1], "", Color("#5b21b6"), -1, ""],
		["Jugaste", "", "partidos", Color("#1d4ed8"), int(d.get("matches", 0)), ""],
		["Hiciste", "", "goles", Color("#b91c1c"), int(d.get("goals", 0)), ""],
		["Diste", "", "asistencias", Color("#047857"), int(d.get("assists", 0)), ""],
		["Tu nota media", "%.2f" % float(d.get("avg", 0.0)), "", Color("#b45309"), -1, ""],
		["Llegaste a nivel", "", "", Color("#0e7490"), int(d.get("level", 1)), ""],
		["Tu equipo terminó", ("%d°" % int(d.get("position", 0))) if int(d.get("position", 0)) > 0 else "—", "en la liga", Color("#7c2d12"), -1, ""],
		["Química con el plantel", "", "/ 100", Color("#166534"), int(d.get("chemistry", 0)), ""],
	]
	if String(d.get("partner", "")) != "":
		_slides.append(["Y fuera de la cancha…", "♥ %s" % String(d.get("partner", "")), "estuvo a tu lado", Color("#be185d"), -1, ""])
	_slides.append(["¡GRAN TEMPORADA!", "Tocá para seguir", "", Color("#5b21b6"), -1, "end"])
	_holder = Control.new()
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_show(0)

func _gui_input(e: InputEvent) -> void:
	var pressed: bool = (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
	if pressed:
		accept_event()
		_next()

func nav_back() -> bool:
	_close()
	return true

func _next() -> void:
	if _i + 1 >= _slides.size():
		_close()
	else:
		_show(_i + 1)

func _close() -> void:
	closed.emit()
	queue_free()

func _show(i: int) -> void:
	_i = i
	for c in _holder.get_children():
		c.queue_free()
	var s: Array = _slides[i]
	var col: Color = s[3]
	var bg := TextureRect.new()
	bg.texture = Styles.gradient_texture(col.lightened(0.15), col.darkened(0.55))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(bg)
	var solid := ColorRect.new()
	solid.color = Color(col.darkened(0.3), 0.55)
	solid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(solid)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(v)
	# Progreso arriba (barritas).
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 4)
	for k in range(_slides.size()):
		var dr := ColorRect.new()
		dr.custom_minimum_size = Vector2(22, 4)
		dr.color = Color(1, 1, 1, 0.9 if k <= i else 0.3)
		dots.add_child(dr)
	v.add_child(dots)
	if i == 0 and _player != null:
		var av: Control = _M3D.portrait(_player, null, 200, true)
		av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(av)
	var t := _lbl(String(s[0]), 26, Color.WHITE)
	v.add_child(t)
	var big := _lbl(String(s[1]), 84, Styles.GOLD)
	v.add_child(big)
	if int(s[4]) >= 0:
		Juice.count_up(big, 0, int(s[4]), 1.0)
	var sub := _lbl(String(s[2]), 22, Color(1, 1, 1, 0.85))
	v.add_child(sub)
	var hint := _lbl("tocá para seguir  ›" if String(s[5]) != "end" else "", 14, Color(1, 1, 1, 0.6))
	v.add_child(hint)
	v.modulate.a = 0.0
	var tw := v.create_tween()
	tw.tween_property(v, "modulate:a", 1.0, 0.3)
	big.pivot_offset = Vector2(270, 50)
	Juice.pop(big, 1.15, 0.5)
	Audio.play("click")

func _lbl(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", Styles.font_black())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("outline_size", 6)
	return l
