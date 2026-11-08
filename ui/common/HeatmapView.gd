class_name HeatmapView
extends Control
## Mapa de calor de tu partido (MatchData): un campo visto desde arriba, tu
## portería a la izquierda y la rival a la derecha, con cada zona más caliente
## cuanto más tiempo estuviste ahí (azul → amarillo → rojo).

var heat: Array = []
var cols := 12
var rows := 8


func setup(values: Array, c: int, r: int) -> void:
	heat = values
	cols = c
	rows = r
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.36, 0.2))
	var mx := 0
	for v in heat:
		mx = maxi(mx, int(v))
	if mx > 0 and heat.size() == cols * rows:
		var cw := w / cols
		var ch := h / rows
		for r in rows:
			for c in cols:
				var t := float(heat[r * cols + c]) / float(mx)
				if t <= 0.02:
					continue
				var col: Color
				if t < 0.5:
					col = Color(0.2, 0.55, 1.0).lerp(Color(1.0, 0.9, 0.2), t * 2.0)
				else:
					col = Color(1.0, 0.9, 0.2).lerp(Color(1.0, 0.2, 0.15), (t - 0.5) * 2.0)
				col.a = lerpf(0.25, 0.85, t)
				draw_rect(Rect2(c * cw, r * ch, cw + 0.5, ch + 0.5), col)
	# Líneas del campo
	var line := Color(1, 1, 1, 0.55)
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), line, false, 2.0)
	draw_line(Vector2(w * 0.5, 0), Vector2(w * 0.5, h), line, 2.0)
	draw_arc(Vector2(w * 0.5, h * 0.5), h * 0.14, 0.0, TAU, 32, line, 2.0)
	var bw := w * 16.5 / 105.0
	var bh := h * 40.3 / 68.0
	draw_rect(Rect2(0, (h - bh) * 0.5, bw, bh), line, false, 2.0)
	draw_rect(Rect2(w - bw, (h - bh) * 0.5, bw, bh), line, false, 2.0)
