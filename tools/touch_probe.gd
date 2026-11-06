extends Control
## Diagnóstico del táctil en listas (con emulación táctil desde el mouse).
##   godot --path . --resolution 576x1024 res://tools/TouchProbe.tscn
var presses: Array = []
var _last: Vector2 = Vector2.ZERO
var _sc: ScrollContainer = null

func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.global_position = pos
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_last = pos
	Input.parse_input_event(e)

func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = pos - _last
	e.velocity = (pos - _last) * 60.0
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	_last = pos
	Input.parse_input_event(e)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _build(fix: bool) -> void:
	if _sc != null:
		_sc.queue_free()
		await _frames(2)
	_sc = ScrollContainer.new()
	_sc.size = Vector2(576, 1024)
	add_child(_sc)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(560, 0)
	_sc.add_child(vb)
	for i in range(40):
		var c: Control
		if i % 3 == 2:
			var pc := PanelContainer.new()
			var pl := Label.new()
			pl.text = "Tarjeta %d" % i
			pc.add_child(pl)
			UiScroll.on_tap(pc, func(): presses.append(i))
			c = pc
		elif i % 3 == 0:
			var b := Button.new()
			b.text = "Botón %d" % i
			b.pressed.connect(func(): presses.append(i))
			c = b
		else:
			var l := Label.new()
			l.text = "Texto %d" % i
			c = l
		c.custom_minimum_size = Vector2(0, 80)
		vb.add_child(c)
	UiScroll.make_touch(_sc)
	if fix:
		UiScroll.touch_friendly(_sc)
	await _frames(3)

func _drag_test(label: String, start: Vector2) -> void:
	_touch(start, true)
	await _frames(1)
	for i in range(1, 9):
		_move(start.lerp(start - Vector2(0, 300), i / 8.0))
		await _frames(1)
	_touch(start - Vector2(0, 300), false)
	await _frames(60)
	print("  arrastre desde %s: scroll=%d, botones apretados=%s" % [label, _sc.scroll_vertical, str(presses)])
	presses.clear()

func _tap_test(label: String, pos: Vector2, jitter: Vector2) -> void:
	_touch(pos, true)
	await _frames(1)
	if jitter != Vector2.ZERO:
		_move(pos + jitter)
		await _frames(1)
	_touch(pos + jitter, false)
	await _frames(3)
	print("  %s: botones apretados=%s scroll=%d" % [label, str(presses), _sc.scroll_vertical])
	presses.clear()

func _ready() -> void:
	Input.emulate_touch_from_mouse = true
	for fix in [false, true]:
		print("== ", "CON arreglo" if fix else "SIN arreglo")
		for rep in range(1):
			# filas de 80 (+4 sep): i=6 botón, i=7 texto, i=8 tarjeta
			for t in [["botón", 6], ["texto", 7], ["tarjeta", 8]]:
				await _build(fix)
				await _drag_test(t[0], Vector2(200, int(t[1]) * 84 + 40))
		await _build(fix)
		await _tap_test("toque corto en botón", Vector2(200, 40), Vector2.ZERO)
		await _tap_test("toque con temblor 10px", Vector2(200, 3 * 84 + 40), Vector2(4, 10))
		await _tap_test("toque con temblor 20px", Vector2(200, 6 * 84 + 40), Vector2(6, 20))
		await _tap_test("toque en TARJETA", Vector2(200, 2 * 84 + 40), Vector2(3, 6))
	get_tree().quit(0)
