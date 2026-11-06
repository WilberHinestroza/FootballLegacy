class_name Goal
extends Node2D
## Portería dibujada en perspectiva (cámara cenital alta mirando "hacia
## arriba" de la pantalla, la misma que usan el balón y los jugadores:
## la altura z sube en pantalla a 0,8 px por px).
##  - Arco de ARRIBA: lo vemos de frente; la red queda detrás (arriba) y
##    se dibuja DEBAJO de los jugadores.
##  - Arco de ABAJO (el tuyo): lo vemos desde atrás; los palos quedan más
##    lejos y la red más cerca de la cámara, así que va ENCIMA de los
##    jugadores (el arquero queda "adentro" del arco).
## La red se infla cuando entra un gol y los palos tiemblan al pegarles.

const POST := Color(0.98, 0.98, 0.96)
const POST_SHADE := Color(0.72, 0.74, 0.78)
const POST_EDGE := Color(0.12, 0.13, 0.16, 0.9)
const NET_FILL := Color(1, 1, 1, 0.10)
const NET_LINE := Color(0.95, 0.97, 1.0, 0.42)
const SHADOW := Color(0, 0, 0, 0.22)
const PROJ := Cfg.Z_PROJ

var top := true
var _ripple_t := 0.0
var _ripple_x := 0.0
var _shake_t := 0.0
var _time := 0.0

func setup(is_top: bool) -> void:
	top = is_top
	z_index = -5 if top else 6

## Gol: la red se infla en la zona donde entró el balón.
func ripple(at_x: float) -> void:
	_ripple_t = 1.4
	_ripple_x = at_x

## Balón al palo / travesaño.
func shake() -> void:
	_shake_t = 0.45

## Pelota contra la red del costado o el techo: se mueve un poco la red.
func shake_net(at_x: float) -> void:
	if _ripple_t < 0.6:
		_ripple_t = 0.7
		_ripple_x = at_x

func _process(dt: float) -> void:
	_time += dt
	if _ripple_t > 0.0 or _shake_t > 0.0:
		_ripple_t = maxf(_ripple_t - dt, 0.0)
		_shake_t = maxf(_shake_t - dt, 0.0)
		queue_redraw()

# ---------------------------------------------------------------- geometría

func _gy() -> float:
	return 0.0 if top else Cfg.FIELD_H

## Hacia dónde va la red (afuera de la cancha).
func _out() -> float:
	return -1.0 if top else 1.0

## Proyección de un punto 3D (x, profundidad detrás de la línea, altura).
func _p(x: float, depth: float, z: float) -> Vector2:
	var wob: float = 0.0
	if _shake_t > 0.0:
		wob = sin(_time * 70.0) * 1.6 * (_shake_t / 0.45) * clampf(z / Cfg.GOAL_H_Z, 0.0, 1.0)
	return Vector2(x + wob, _gy() + _out() * depth - z * PROJ)

## Inflado de la red: empuja hacia afuera cerca de donde entró el balón.
func _bulge(x: float, k: float) -> float:
	if _ripple_t <= 0.0:
		return 0.0
	var f: float = exp(-pow((x - _ripple_x) / (Cfg.GOAL_W * 0.35), 2.0))
	var w: float = sin((1.4 - _ripple_t) * 14.0) * exp(-(1.4 - _ripple_t) * 2.2)
	return f * w * 0.9 * Cfg.M * k

func _draw() -> void:
	var L: float = Cfg.FIELD_W * 0.5 - Cfg.GOAL_W * 0.5
	var R: float = Cfg.FIELD_W * 0.5 + Cfg.GOAL_W * 0.5
	var D: float = Cfg.GOAL_DEPTH
	var H: float = Cfg.GOAL_H_Z
	var Hb: float = H * 0.55          # la red baja hacia atrás
	_draw_shadow(L, R, D, H)
	if top:
		_draw_nets(L, R, D, H, Hb)
		_draw_frame(L, R, H)
	else:
		_draw_frame(L, R, H)
		_draw_nets(L, R, D, H, Hb)

func _draw_shadow(L: float, R: float, D: float, H: float) -> void:
	# Sombra del arco proyectada sobre el pasto (sol arriba a la izquierda).
	var off := Vector2(H * 0.35, H * 0.12)
	var pts := PackedVector2Array([
		_p(L, 0, 0), _p(R, 0, 0), _p(R, D, 0) + off * 0.3, _p(L, D, 0) + off * 0.3])
	draw_colored_polygon(pts, Color(0, 0, 0, 0.10))
	for x in [L, R]:
		var b: Vector2 = _p(x, 0, 0)
		draw_line(b, b + off, SHADOW, 3.0)
	draw_line(_p(L, 0, 0) + off, _p(R, 0, 0) + off, Color(0, 0, 0, 0.12), 3.0)

func _draw_nets(L: float, R: float, D: float, H: float, Hb: float) -> void:
	var nu: int = 14
	# Fondo.
	var back := func(u: float, v: float) -> Vector2:
		var x: float = lerpf(L, R, u)
		return _p(x, D + _bulge(x, 1.0), lerpf(0.0, Hb, v))
	_net_face(back, nu, 5)
	# Techo (del travesaño al fondo).
	var roof := func(u: float, v: float) -> Vector2:
		var x: float = lerpf(L, R, u)
		return _p(x, lerpf(0.0, D, v) + _bulge(x, v), lerpf(H, Hb, v))
	_net_face(roof, nu, 4)
	# Laterales.
	for x in [L, R]:
		var sx: float = x
		var side := func(u: float, v: float) -> Vector2:
			return _p(sx, u * D, lerpf(H, Hb, u) * v)
		_net_face(side, 5, 5)
	# Tubos de la base de la red en el pasto.
	draw_line(_p(L, D, 0), _p(R, D, 0), Color(0.85, 0.87, 0.9, 0.8), 2.0)
	draw_line(_p(L, 0, 0), _p(L, D, 0), Color(0.85, 0.87, 0.9, 0.6), 1.5)
	draw_line(_p(R, 0, 0), _p(R, D, 0), Color(0.85, 0.87, 0.9, 0.6), 1.5)

## Dibuja una cara de red como una malla de nu × nv celdas.
func _net_face(f: Callable, nu: int, nv: int) -> void:
	var grid: Array = []
	for j in nv + 1:
		var row := PackedVector2Array()
		for i in nu + 1:
			row.append(f.call(float(i) / nu, float(j) / nv))
		grid.append(row)
	for j in nv:
		for i in nu:
			# Dos triángulos: con la red sacudida un cuadro puede quedar
			# cruzado y draw_colored_polygon fallaba al triangularlo.
			var cols := PackedColorArray([NET_FILL, NET_FILL, NET_FILL])
			draw_primitive(PackedVector2Array([grid[j][i], grid[j][i + 1], grid[j + 1][i + 1]]), cols, PackedVector2Array())
			draw_primitive(PackedVector2Array([grid[j][i], grid[j + 1][i + 1], grid[j + 1][i]]), cols, PackedVector2Array())
	for j in nv + 1:
		draw_polyline(grid[j], NET_LINE, 1.0)
	for i in nu + 1:
		var col := PackedVector2Array()
		for j in nv + 1:
			col.append(grid[j][i])
		draw_polyline(col, NET_LINE, 1.0)

func _draw_frame(L: float, R: float, H: float) -> void:
	var w: float = 4.0
	for x in [L, R]:
		var a: Vector2 = _p(x, 0, 0)
		var b: Vector2 = _p(x, 0, H)
		draw_line(a, b, POST_EDGE, w + 2.0)
		draw_line(a, b, POST, w)
		draw_line(a + Vector2(w * 0.3, 0), b + Vector2(w * 0.3, 0), POST_SHADE, 1.0)
		draw_circle(a, w * 0.6, POST_SHADE)
	var c0: Vector2 = _p(L, 0, H)
	var c1: Vector2 = _p(R, 0, H)
	draw_line(c0, c1, POST_EDGE, w + 2.0)
	draw_line(c0, c1, POST, w)
	draw_line(c0 + Vector2(0, w * 0.3), c1 + Vector2(0, w * 0.3), POST_SHADE, 1.0)
	draw_circle(c0, w * 0.5 + 1.0, POST)
	draw_circle(c1, w * 0.5 + 1.0, POST)
