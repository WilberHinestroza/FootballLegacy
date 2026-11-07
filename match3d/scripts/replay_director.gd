class_name ReplayDirector
extends Node
## Repetición de la última jugada con cámara libre.
## Graba cada fotograma de física de la jugada (posición, giro y animación de los 22 y el
## balón) y luego la reproduce. La cámara se mueve por toda la cancha:
##   un dedo / clic izquierdo = girar · dos dedos / clic derecho = desplazar
##   pellizcar / rueda = acercar · "Seguir balón" la vuelve a pegar al balón.

const MAX_FRAMES := 1500 # unos 25 s de juego
const REC_HZ := 30.0    # graba 30 muestras por segundo (la mitad de coste y memoria)
const SPEEDS := [0.25, 0.5, 1.0]

var _frames: Array = []
var _rec_acc := 0.0
var _match: SoccerMatch
var _playing := false
var _paused := false
var _t := 0.0           # fotograma actual (con decimales)
var _speed := 1.0
var _follow := true
# Cámara en órbita: alrededor de _target, a _dist metros, con giro _yaw e inclinación _pitch
var _cam: Camera3D
var _target := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.45
var _dist := 16.0
var _touches: Dictionary = {}
var _ui: CanvasLayer
var _slider: HSlider
var _play_btn: Button
var _follow_btn: Button
var _speed_btns: Array[Button] = []
var _rec_label: Label
var _blink := 0.0
var _seeking := false
var _on_stop := Callable()

# Momento del partido (7-nov): la mejor jugada tuya se guarda (copia de sus
# fotogramas) y se ve sola al final. Cada jugada propone una puntuación al acabar;
# se confirma al empezar la siguiente grabación, así incluye la celebración.
var _best_frames: Array = []
var _best_score := -1.0
var best_info := {}
var _pending_score := -1.0
var _pending_info := {}
var _saved_frames: Array = []
var _restore := {}
var _auto_close := false
var _auto_left := 0.0


func begin() -> void:
	_commit()
	_frames = [] # array nuevo: la copia del mejor momento no se borra
	_rec_acc = 0.0


func has_frames() -> bool:
	return _frames.size() > 10


## La jugada que acaba de terminar puede ser el momento del partido.
func propose(score: float, info: Dictionary) -> void:
	_pending_score = score
	_pending_info = info


func _commit() -> void:
	if _pending_score > _best_score and has_frames():
		_best_frames = _frames
		_best_score = _pending_score
		best_info = _pending_info
	_pending_score = -1.0


func has_best() -> bool:
	_commit()
	return _best_frames.size() > 10


## Reproduce el momento del partido solo (sin tocar nada) y al acabar deja todo como
## estaba ahora; luego llama a `on_stop`.
func play_best(m: SoccerMatch, title: String, on_stop: Callable) -> void:
	_commit()
	_restore = _capture(m)
	_saved_frames = _frames
	_frames = _best_frames
	play(m, on_stop)
	_auto_close = true
	_auto_left = 1.4
	_rec_label.text = title
	_rec_label.label_settings.font_color = Color(1.0, 0.85, 0.3)


## Desde la pausa (8-nov): vuelve a ver tu última jugada con la cámara libre y,
## al cerrar, deja todo como estaba ahora (como play_best, pero sin cierre solo).
func play_last(m: SoccerMatch, on_stop: Callable) -> void:
	_commit()
	_restore = _capture(m)
	_saved_frames = _frames
	play(m, on_stop)
	_rec_label.text = "⟲ ÚLTIMA JUGADA"
	_rec_label.label_settings.font_color = Color(1.0, 0.85, 0.3)


## Guarda el fotograma actual (lo llama el partido en cada paso de física de la jugada).
func record(m: SoccerMatch) -> void:
	if _playing or _frames.size() >= MAX_FRAMES:
		return
	_rec_acc += get_physics_process_delta_time()
	if _rec_acc < 1.0 / REC_HZ:
		return
	_rec_acc = 0.0
	_frames.append(_capture(m))


func _capture(m: SoccerMatch) -> Dictionary:
	var xf: Array[Transform3D] = []
	var vis: Array[Transform3D] = []
	var anims := PackedStringArray()
	var times := PackedFloat32Array()
	for p: SoccerPlayer in m.players:
		xf.append(p.global_transform)
		vis.append(p._visual.transform if p._visual else Transform3D.IDENTITY)
		var a: AnimationPlayer = p._anim
		if a and a.current_animation != "":
			anims.append(a.current_animation)
			times.append(a.current_animation_position)
		else:
			anims.append("")
			times.append(0.0)
	return {"ball": m.ball.global_transform, "xf": xf, "vis": vis, "an": anims, "at": times}


func play(m: SoccerMatch, on_stop := Callable()) -> void:
	_match = m
	_on_stop = on_stop
	_playing = true
	_paused = false
	_t = 0.0
	_speed = 1.0
	_follow = true
	Engine.time_scale = 1.0
	for p in m.players:
		p.process_mode = Node.PROCESS_MODE_DISABLED
	m.ball.process_mode = Node.PROCESS_MODE_DISABLED
	m.ball.freeze = true
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 55.0
		m.add_child(_cam)
	_cam.make_current()
	var b: Vector3 = (_frames[0].ball as Transform3D).origin
	_target = Vector3(b.x, 0.5, b.z)
	_yaw = 0.0 # de frente, como la cámara de TV
	_pitch = 0.42
	_dist = 16.0
	_build_ui()
	_ui.visible = true
	_apply(0)


func _stop() -> void:
	if not _playing:
		return
	if not _restore.is_empty():
		_apply_frame(_restore) # momento del partido: vuelve a como estaba antes de verlo
		_restore = {}
		_frames = _saved_frames
		_saved_frames = []
		_rec_label.text = "● REPETICIÓN"
		_rec_label.label_settings.font_color = Color(1.0, 0.25, 0.25)
	else:
		_apply(_frames.size() - 1) # todo queda como estaba al final de la jugada
	_auto_close = false
	_playing = false
	_ui.visible = false
	_touches.clear()
	for p in _match.players:
		p.process_mode = Node.PROCESS_MODE_INHERIT
	_match.ball.process_mode = Node.PROCESS_MODE_INHERIT
	_match.ball.freeze = false
	# P0-10: la tanda vuelve a su propio flujo; la jugada normal, al resultado.
	if _on_stop.is_valid():
		var cb := _on_stop
		_on_stop = Callable()
		cb.call()
	else:
		_match.end_replay()


func _process(delta: float) -> void:
	if not _playing:
		return
	if not _paused and not _seeking:
		_t += delta * REC_HZ * _speed
		if _t >= _frames.size() - 1:
			_t = _frames.size() - 1
			_paused = true
			_play_btn.text = "▶"
	if _auto_close and _paused and _t >= _frames.size() - 1:
		_auto_left -= delta
		if _auto_left <= 0.0:
			_stop()
			return
		_apply(int(_t))
		_slider.set_value_no_signal(_t / maxf(_frames.size() - 1, 1.0))
	_blink += delta
	_rec_label.modulate.a = 1.0 if fmod(_blink, 1.0) < 0.6 else 0.35
	if _follow:
		var b := _match.ball.global_position
		_target = _target.lerp(Vector3(b.x, clampf(b.y, 0.4, 3.0), b.z), minf(1.0, delta * 4.0))
	_place_camera()


func _apply(i: int) -> void:
	_apply_frame(_frames[clampi(i, 0, _frames.size() - 1)])


func _apply_frame(f: Dictionary) -> void:
	_match.ball.global_transform = f.ball
	var xf: Array = f.xf
	var vis: Array = f.vis
	var an: PackedStringArray = f.an
	var at: PackedFloat32Array = f.at
	for k in _match.players.size():
		var p: SoccerPlayer = _match.players[k]
		p.global_transform = xf[k]
		if p._visual:
			p._visual.transform = vis[k]
		var a: AnimationPlayer = p._anim
		if a and an[k] != "":
			if a.current_animation != an[k]:
				a.play(an[k])
			a.seek(at[k], true)


func _place_camera() -> void:
	var L := SoccerMatch.FIELD_LENGTH * 0.5 + 8.0
	var W := SoccerMatch.FIELD_WIDTH * 0.5 + 8.0
	_target.x = clampf(_target.x, -L, L)
	_target.z = clampf(_target.z, -W, W)
	var off := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	var pos := _target + off
	pos.y = maxf(pos.y, 0.4)
	_cam.global_position = pos
	_cam.look_at(_target, Vector3.UP)


# ---------- control de la cámara ----------

func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _touches.size() >= 2 and _touches.has(sd.index):
			var ids := _touches.keys()
			var other: Vector2 = _touches[ids[0] if ids[0] != sd.index else ids[1]]
			var before := (_touches[sd.index] as Vector2).distance_to(other)
			var after := sd.position.distance_to(other)
			if after > 1.0:
				_zoom(before / after)
			_pan(sd.relative * 0.5)
		else:
			_orbit(sd.relative)
		_touches[sd.index] = sd.position
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_orbit(mm.relative)
		elif mm.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			_pan(mm.relative)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.1)


func _orbit(rel: Vector2) -> void:
	_yaw -= rel.x * 0.006
	_pitch = clampf(_pitch + rel.y * 0.004, 0.04, 1.45)


func _zoom(factor: float) -> void:
	_dist = clampf(_dist * factor, 2.5, 70.0)


func _pan(rel: Vector2) -> void:
	_set_follow(false)
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var k := _dist * 0.0025
	_target += (-right * rel.x + fwd * rel.y) * k


func _set_follow(value: bool) -> void:
	_follow = value
	if _follow_btn:
		_follow_btn.text = "◎ Siguiendo balón" if value else "◎ Seguir balón"


# ---------- interfaz ----------

func _build_ui() -> void:
	if _ui != null:
		_set_follow(true)
		_play_btn.text = "❚❚"
		_mark_speed()
		return
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	_rec_label = Label.new()
	_rec_label.text = "● REPETICIÓN"
	var ls := LabelSettings.new()
	ls.font_size = 30
	ls.font_color = Color(1.0, 0.25, 0.25)
	ls.outline_size = 6
	ls.outline_color = Color(0.0, 0.0, 0.0, 0.8)
	_rec_label.label_settings = ls
	_rec_label.position = Vector2(20.0, 76.0)
	root.add_child(_rec_label)
	var help := Label.new()
	help.text = "Arrastra: girar · dos dedos: mover y acercar"
	var hs := LabelSettings.new()
	hs.font_size = 16
	hs.outline_size = 4
	hs.outline_color = Color(0.0, 0.0, 0.0, 0.8)
	help.label_settings = hs
	help.position = Vector2(22.0, 116.0)
	root.add_child(help)

	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -86.0
	bar.offset_left = 12.0
	bar.offset_right = -12.0
	bar.offset_bottom = -10.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(8.0)
	bar.add_theme_stylebox_override("panel", sb)
	root.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)

	_play_btn = _button(row, "❚❚", 64.0)
	_play_btn.pressed.connect(func() -> void:
		if _paused and _t >= _frames.size() - 1:
			_t = 0.0
		_paused = not _paused
		_play_btn.text = "▶" if _paused else "❚❚")
	for s: float in SPEEDS:
		var b := _button(row, "%sx" % str(s), 64.0)
		b.pressed.connect(func() -> void:
			_speed = s
			_mark_speed())
		_speed_btns.append(b)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.001
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.custom_minimum_size = Vector2(120.0, 40.0)
	_slider.drag_started.connect(func() -> void: _seeking = true)
	_slider.drag_ended.connect(func(_c: bool) -> void: _seeking = false)
	_slider.value_changed.connect(func(v: float) -> void:
		_t = v * (_frames.size() - 1)
		_apply(int(_t)))
	row.add_child(_slider)
	_follow_btn = _button(row, "", 190.0)
	_follow_btn.pressed.connect(func() -> void: _set_follow(not _follow))
	_set_follow(true)
	var close := _button(row, "✕ Salir", 110.0)
	close.pressed.connect(_stop)
	_mark_speed()


func _mark_speed() -> void:
	for i in _speed_btns.size():
		_speed_btns[i].modulate = Color(1.0, 0.85, 0.2) if is_equal_approx(SPEEDS[i], _speed) else Color.WHITE


func _button(parent: Node, text: String, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 56.0)
	b.add_theme_font_size_override("font_size", 22)
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b
