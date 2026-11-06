extends Control
class_name GoalAimGrid

## Minijuego de penal (pedido de Wilber, 9-oct): el arco de frente, dividido
## en 9 zonas (3×3), con el arquero parado en el medio. Tocás la zona y
## Match.gd sigue con el timing del disparo de siempre. Solo UI: lo que
## pasa con cada zona (arquero que adivina, ángulos, riesgo de la fila de
## arriba) vive en DecisionResolver.aim_penalty_grid_multiplier.

signal zone_picked(zone: int)

const POST := Color.WHITE
const NET := Color(1, 1, 1, 0.22)
const CELL_LINE := Color(1, 1, 1, 0.35)
const PICK := Color(1.0, 0.85, 0.3, 0.45)
const KEEPER := Color("#f2c230")

var _goal: Rect2 = Rect2()
var _picked: int = -1
var _pressed_cell: int = -1

func _ready() -> void:
	custom_minimum_size = Vector2(0, 170)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func _layout() -> void:
	# Arco real 7,32 × 2,44 m → ~3:1. Deja margen para los palos y el césped.
	var w: float = minf(size.x - 16.0, (size.y - 26.0) * 3.0)
	var h: float = w / 3.0
	_goal = Rect2(Vector2((size.x - w) * 0.5, 10.0), Vector2(w, h))

func _cell_rect(i: int) -> Rect2:
	var cw: float = _goal.size.x / 3.0
	var ch: float = _goal.size.y / 3.0
	return Rect2(_goal.position + Vector2((i % 3) * cw, floori(i / 3.0) * ch), Vector2(cw, ch))

func _cell_at(p: Vector2) -> int:
	if not _goal.has_point(p):
		return -1
	var col: int = clampi(int((p.x - _goal.position.x) / (_goal.size.x / 3.0)), 0, 2)
	var row: int = clampi(int((p.y - _goal.position.y) / (_goal.size.y / 3.0)), 0, 2)
	return row * 3 + col

func _gui_input(event: InputEvent) -> void:
	if _picked >= 0:
		return
	var pos := Vector2.ZERO
	var down := false
	var up := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventScreenTouch:
		pos = event.position
		down = event.pressed
		up = not event.pressed
	else:
		return
	var c := _cell_at(pos)
	if down:
		_pressed_cell = c
		queue_redraw()
	elif up:
		if c >= 0 and c == _pressed_cell:
			_picked = c
			queue_redraw()
			zone_picked.emit(c)
		_pressed_cell = -1
		queue_redraw()
	accept_event()

func _draw() -> void:
	_layout()
	var g := _goal
	# Césped debajo del arco.
	draw_rect(Rect2(Vector2(0, g.end.y), Vector2(size.x, size.y - g.end.y)), Color(0.16, 0.42, 0.20))
	# Red.
	draw_rect(g, Color(1, 1, 1, 0.05))
	var step: float = 7.0
	var x: float = g.position.x
	while x <= g.end.x:
		draw_line(Vector2(x, g.position.y), Vector2(x, g.end.y), NET, 1.0)
		x += step
	var y: float = g.position.y
	while y <= g.end.y:
		draw_line(Vector2(g.position.x, y), Vector2(g.end.x, y), NET, 1.0)
		y += step
	# Zonas.
	for i in range(9):
		var r := _cell_rect(i)
		if i == _picked or i == _pressed_cell:
			draw_rect(r.grow(-2.0), PICK)
		draw_rect(r, CELL_LINE, false, 1.0)
	# Arquero en el medio (cuerpo + brazos abiertos + cabeza).
	var c := Vector2(g.get_center().x, g.end.y)
	var bh: float = g.size.y * 0.62
	var bw: float = g.size.x * 0.07
	draw_rect(Rect2(c + Vector2(-bw * 0.5, -bh), Vector2(bw, bh * 0.78)), KEEPER)
	draw_line(c + Vector2(-bw * 0.5, -bh * 0.85), c + Vector2(-bw * 1.9, -bh * 1.05), KEEPER, bw * 0.38)
	draw_line(c + Vector2(bw * 0.5, -bh * 0.85), c + Vector2(bw * 1.9, -bh * 1.05), KEEPER, bw * 0.38)
	draw_line(c + Vector2(-bw * 0.25, -bh * 0.22), c + Vector2(-bw * 0.6, 0), Color(0.1, 0.1, 0.12), bw * 0.32)
	draw_line(c + Vector2(bw * 0.25, -bh * 0.22), c + Vector2(bw * 0.6, 0), Color(0.1, 0.1, 0.12), bw * 0.32)
	draw_circle(c + Vector2(0, -bh - bw * 0.45), bw * 0.5, Color(0.93, 0.72, 0.55))
	# Palos y travesaño (encima de todo).
	var pw: float = 4.0
	draw_line(g.position, Vector2(g.position.x, g.end.y), POST, pw)
	draw_line(Vector2(g.end.x, g.position.y), g.end, POST, pw)
	draw_line(g.position, Vector2(g.end.x, g.position.y), POST, pw)
