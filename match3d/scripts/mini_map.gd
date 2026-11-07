class_name MiniMap
extends Control
## Mapita de la cancha en la esquina (abajo a la izquierda) para las jugadas: con
## la cámara a tu espalda no se ve lo que viene por detrás. Orientado como la
## cámara de jugada: tu equipo ataca HACIA ARRIBA y tu banda derecha (+Z) queda a
## la derecha. Solo lee posiciones del partido; no decide nada.

const W := 100.0  # ancho del mapa (px) = ancho de la cancha (68 m)
const H := 154.0  # alto (px) = largo (105 m)
const REDRAW := 1.0 / 20.0

var match_ref: Node = null
var colors := [Color(0.2, 0.8, 0.4), Color(0.9, 0.3, 0.3)]
var _acc := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)


func _process(delta: float) -> void:
	_acc += delta / maxf(Engine.time_scale, 0.01)
	if _acc >= REDRAW:
		_acc = 0.0
		queue_redraw()


func _to_map(p: Vector3) -> Vector2:
	var L: float = SoccerMatch.FIELD_LENGTH
	var Wm: float = SoccerMatch.FIELD_WIDTH
	return Vector2((p.z + Wm * 0.5) / Wm * W, (L * 0.5 - p.x) / L * H)


func _draw() -> void:
	var line := Color(1, 1, 1, 0.35)
	draw_rect(Rect2(Vector2(-3, -3), Vector2(W + 6, H + 6)), Color(0.02, 0.06, 0.03, 0.62))
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.12, 0.42, 0.2, 0.55))
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), line, false, 1.0)
	draw_line(Vector2(0, H * 0.5), Vector2(W, H * 0.5), line, 1.0)
	draw_arc(Vector2(W * 0.5, H * 0.5), W * 0.13, 0.0, TAU, 20, line, 1.0)
	# Áreas (40,3 x 16,5 m) arriba y abajo
	var bw := 40.3 / SoccerMatch.FIELD_WIDTH * W
	var bh := 16.5 / SoccerMatch.FIELD_LENGTH * H
	draw_rect(Rect2(Vector2((W - bw) * 0.5, 0.0), Vector2(bw, bh)), line, false, 1.0)
	draw_rect(Rect2(Vector2((W - bw) * 0.5, H - bh), Vector2(bw, bh)), line, false, 1.0)
	if match_ref == null:
		return
	var star: SoccerPlayer = match_ref.star
	for t in 2:
		for p: SoccerPlayer in match_ref.teams[t]:
			if not p.visible or p == star:
				continue
			var c: Color = colors[t]
			var mp := _to_map(p.global_position)
			draw_circle(mp, 3.4, Color(0, 0, 0, 0.7))
			draw_circle(mp, 2.6, c)
	if star != null and star.visible:
		# Tú: más grande, con aro amarillo y una cuña hacia donde miras
		var sp := _to_map(star.global_position)
		var f := star.facing
		var fd := Vector2(f.z, -f.x).normalized()
		if fd != Vector2.ZERO:
			var side := Vector2(-fd.y, fd.x)
			draw_colored_polygon(PackedVector2Array([sp + fd * 11.0, sp + side * 4.0, sp - side * 4.0]),
					Color(1.0, 0.85, 0.2, 0.45))
		draw_circle(sp, 4.6, Color(1.0, 0.85, 0.2))
		draw_circle(sp, 3.0, colors[0])
	var ball: Node3D = match_ref.ball
	if ball != null and ball.visible:
		var bp := _to_map(ball.global_position)
		draw_circle(bp, 2.6, Color(0, 0, 0, 0.8))
		draw_circle(bp, 1.9, Color.WHITE)
