extends Control
class_name MomentMap

## "Tus jugadas en la cancha" para el resumen del partido (Paquete 2 del
## ROADMAP): cancha ENTERA vertical — arco rival arriba, el tuyo abajo —
## con cada momento clave que tuviste (MatchState.moment_map, lo llena
## Match.gd): resplandor de "calor" donde más participaste, punto verde si
## salió bien / rojo si no, estrella dorada si terminó en gol, y flecha
## para los pases. Solo dibujo; los datos ya vienen resueltos.

const FIELD_ASPECT := 105.0 / 68.0
const GRASS_A := Color(0.16, 0.42, 0.20)
const GRASS_B := Color(0.18, 0.46, 0.22)
const LINE := Color(1, 1, 1, 0.6)
const OK_COL := Color("#3ecf6e")
const FAIL_COL := Color("#e0524a")
const GOAL_COL := Color("#ffd24a")
const HEAT := Color(1.0, 0.62, 0.15)

var moments: Array = []
var _field: Rect2 = Rect2()

func _ready() -> void:
	custom_minimum_size = Vector2(0, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_moments(list: Array) -> void:
	moments = list
	queue_redraw()

func _p(n: Vector2) -> Vector2:
	return _field.position + Vector2(n.x * _field.size.x, n.y * _field.size.y)

func _draw() -> void:
	var avail := Rect2(Vector2(4, 12), size - Vector2(8, 24))
	var h: float = avail.size.y
	var w: float = h / FIELD_ASPECT
	if w > avail.size.x:
		w = avail.size.x
		h = w * FIELD_ASPECT
	_field = Rect2(avail.position + Vector2((avail.size.x - w) * 0.5, (avail.size.y - h) * 0.5), Vector2(w, h))
	var f := _field
	var bands: int = 10
	for i in range(bands):
		draw_rect(Rect2(f.position + Vector2(0, f.size.y * i / bands), Vector2(f.size.x, f.size.y / bands)), GRASS_A if i % 2 == 0 else GRASS_B)
	var lw: float = 1.5
	draw_rect(f, LINE, false, lw)
	draw_line(_p(Vector2(0, 0.5)), _p(Vector2(1, 0.5)), LINE, lw)
	draw_arc(_p(Vector2(0.5, 0.5)), 9.15 / 68.0 * f.size.x, 0, TAU, 32, LINE, lw)
	var box_w: float = 40.32 / 68.0
	var box_d: float = 16.5 / 105.0
	var goal_w: float = 7.32 / 68.0
	for top in [true, false]:
		var y0: float = 0.0 if top else 1.0 - box_d
		draw_rect(Rect2(_p(Vector2(0.5 - box_w * 0.5, y0)), Vector2(box_w * f.size.x, box_d * f.size.y)), LINE, false, lw)
		var gy: float = (f.position.y - 6.0) if top else f.end.y
		draw_rect(Rect2(Vector2(_p(Vector2(0.5 - goal_w * 0.5, 0)).x, gy), Vector2(goal_w * f.size.x, 6.0)), Color(1, 1, 1, 0.5))

	# Calor: varios círculos suaves superpuestos (más jugadas en una zona =
	# más intenso).
	var rad: float = f.size.x * 0.16
	for m in moments:
		var c := _p(m.get("pos", Vector2(0.5, 0.5)))
		for k in range(4):
			draw_circle(c, rad * (1.0 - k * 0.22), Color(HEAT, 0.07))

	# Pases (flecha), después los puntos/estrellas encima.
	for m in moments:
		var to = m.get("to", null)
		if to is Vector2:
			var a := _p(m["pos"])
			var b := _p(to)
			var col: Color = OK_COL if m.get("ok", false) else FAIL_COL
			draw_line(a, b, Color(col, 0.9), 2.0)
			var dir: Vector2 = (b - a).normalized()
			var side := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([b, b - dir * 9.0 + side * 4.5, b - dir * 9.0 - side * 4.5]), col)
	for m in moments:
		var c := _p(m.get("pos", Vector2(0.5, 0.5)))
		if m.get("goal", false) and m.get("ok", false):
			_star(c, 9.0, GOAL_COL)
		else:
			draw_circle(c, 6.0, OK_COL if m.get("ok", false) else FAIL_COL)
			draw_arc(c, 6.0, 0, TAU, 16, Color(0, 0, 0, 0.5), 1.2)

func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var ang: float = -PI * 0.5 + i * PI / 5.0
		var rr: float = r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color(0, 0, 0, 0.55), 1.2)
