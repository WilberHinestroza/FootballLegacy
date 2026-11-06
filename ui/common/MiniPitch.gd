extends Control
class_name MiniPitch

## Cancha entera vista desde arriba (ataque hacia ARRIBA) para la vista de
## formación de Plantilla: césped a franjas + líneas reales (áreas, área
## chica, círculo central, puntos de penal). Solo dibujo, sin input — las
## fichas van encima como hijos del panel.

const GRASS_A := Color(0.13, 0.36, 0.17)
const GRASS_B := Color(0.15, 0.40, 0.19)
const LINE := Color(1, 1, 1, 0.42)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, GRASS_A)
	var bands: int = 10
	for i in range(bands):
		if i % 2 == 1:
			draw_rect(Rect2(0, r.size.y * i / bands, r.size.x, r.size.y / bands), GRASS_B)
	var m: float = 8.0
	var f := Rect2(m, m, r.size.x - m * 2.0, r.size.y - m * 2.0)
	var lw: float = 2.0
	draw_rect(f, LINE, false, lw)
	var mid_y: float = f.position.y + f.size.y * 0.5
	draw_line(Vector2(f.position.x, mid_y), Vector2(f.end.x, mid_y), LINE, lw)
	var cr: float = f.size.x * 0.14
	draw_arc(Vector2(f.get_center().x, mid_y), cr, 0, TAU, 40, LINE, lw)
	draw_circle(Vector2(f.get_center().x, mid_y), 3.0, LINE)
	# Áreas (grande + chica + punto + medialuna) arriba y abajo.
	for top in [true, false]:
		var bw: float = f.size.x * 0.58
		var bd: float = f.size.y * 0.15
		var sw: float = f.size.x * 0.27
		var sd: float = f.size.y * 0.055
		var x0: float = f.get_center().x - bw * 0.5
		var y0: float = f.position.y if top else f.end.y - bd
		draw_rect(Rect2(x0, y0, bw, bd), LINE, false, lw)
		var sy: float = f.position.y if top else f.end.y - sd
		draw_rect(Rect2(f.get_center().x - sw * 0.5, sy, sw, sd), LINE, false, lw)
		var spot_y: float = f.position.y + bd * 0.7 if top else f.end.y - bd * 0.7
		draw_circle(Vector2(f.get_center().x, spot_y), 2.5, LINE)
		var arc_y: float = y0 + bd if top else y0
		var a0: float = 0.0 if top else PI
		draw_arc(Vector2(f.get_center().x, arc_y), cr * 0.55, a0 + 0.35, a0 + PI - 0.35, 20, LINE, lw)
