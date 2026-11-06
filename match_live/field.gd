class_name Field
extends Node2D
## Dibuja la cancha (césped a franjas y líneas) y coloca las porterías.

const GRASS_A := Color(0.20, 0.50, 0.22)
const GRASS_B := Color(0.18, 0.46, 0.20)
const OUTSIDE := Color(0.14, 0.36, 0.16)
const LINE := Color(0.95, 0.97, 0.93, 0.9)
const LW := 2.0

var _drawn_goals := false

func _ready() -> void:
	z_index = -10

func _draw() -> void:
	var W: float = Cfg.FIELD_W
	var H: float = Cfg.FIELD_H
	var pad: float = 16.0 * Cfg.M
	draw_rect(Rect2(-pad, -pad, W + pad * 2.0, H + pad * 2.0), OUTSIDE)
	# Franjas horizontales.
	var stripes: int = 14
	var sh: float = H / float(stripes)
	for i in stripes:
		draw_rect(Rect2(-Cfg.MARGIN, i * sh, W + Cfg.MARGIN * 2.0, sh), GRASS_A if i % 2 == 0 else GRASS_B)
	draw_rect(Rect2(-Cfg.MARGIN, -Cfg.MARGIN, W + Cfg.MARGIN * 2.0, Cfg.MARGIN), GRASS_B)
	draw_rect(Rect2(-Cfg.MARGIN, H, W + Cfg.MARGIN * 2.0, Cfg.MARGIN), GRASS_B)
	# Líneas.
	draw_rect(Rect2(0, 0, W, H), LINE, false, LW)
	draw_line(Vector2(0, H * 0.5), Vector2(W, H * 0.5), LINE, LW)
	draw_arc(Vector2(W * 0.5, H * 0.5), Cfg.CENTER_R, 0.0, TAU, 64, LINE, LW)
	draw_circle(Vector2(W * 0.5, H * 0.5), 2.5, LINE)
	for top in [true, false]:
		var gy: float = 0.0 if top else H
		var s: float = 1.0 if top else -1.0
		draw_rect(_box(gy, s, Cfg.BOX_W, Cfg.BOX_H), LINE, false, LW)
		draw_rect(_box(gy, s, Cfg.SMALL_W, Cfg.SMALL_H), LINE, false, LW)
		var spot := Vector2(W * 0.5, gy + s * Cfg.PENALTY_SPOT)
		draw_circle(spot, 2.0, LINE)
		# Medialuna del área (solo la parte fuera del área).
		var a0: float = acos((Cfg.BOX_H - Cfg.PENALTY_SPOT) / Cfg.CENTER_R)
		if top:
			draw_arc(spot, Cfg.CENTER_R, PI * 0.5 - a0, PI * 0.5 + a0, 24, LINE, LW)
		else:
			draw_arc(spot, Cfg.CENTER_R, -PI * 0.5 - a0, -PI * 0.5 + a0, 24, LINE, LW)
	# Arcos de córner.
	var r: float = 1.0 * Cfg.M
	draw_arc(Vector2(0, 0), r, 0.0, PI * 0.5, 8, LINE, LW)
	draw_arc(Vector2(W, 0), r, PI * 0.5, PI, 8, LINE, LW)
	draw_arc(Vector2(0, H), r, -PI * 0.5, 0.0, 8, LINE, LW)
	draw_arc(Vector2(W, H), r, PI, PI * 1.5, 8, LINE, LW)
	if _drawn_goals:
		for gy in [-Cfg.GOAL_DEPTH, H]:
			var rect := Rect2(W * 0.5 - Cfg.GOAL_W * 0.5, gy, Cfg.GOAL_W, Cfg.GOAL_DEPTH)
			draw_rect(rect, Color(1, 1, 1, 0.25))
			draw_rect(rect, Color.WHITE, false, 3.0)

func _box(gy: float, s: float, w: float, h: float) -> Rect2:
	var x: float = (Cfg.FIELD_W - w) * 0.5
	if s > 0.0:
		return Rect2(x, gy, w, h)
	return Rect2(x, gy - h, w, h)

## Portería con el sprite de PixelLab (o dibujada si no existe).
func _add_goal(top: bool) -> void:
	var cx: float = Cfg.FIELD_W * 0.5
	var gy: float = 0.0 if top else Cfg.FIELD_H
	var path := "res://assets/goal.png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		var r: Rect2i = Sprites.opaque_rect(tex)
		var s := Sprite2D.new()
		s.texture = tex
		s.region_enabled = true
		s.region_rect = Rect2(r)
		var k: float = (Cfg.GOAL_W + 0.4 * Cfg.M) / float(r.size.x)
		s.scale = Vector2(k, k)
		var h: float = float(r.size.y) * k
		# Arriba: los postes (borde inferior del dibujo) sobre la línea de gol.
		# Abajo: espejado en vertical, la red queda hacia afuera.
		s.flip_v = not top
		s.position = Vector2(cx, gy - h * 0.5 if top else gy + h * 0.5)
		s.z_index = 2 if not top else 0
		add_child(s)
	else:
		_drawn_goals = true
