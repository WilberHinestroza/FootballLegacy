class_name GestureInput
extends Control
## Convierte toques (o clics del ratón) en gestos:
##   toque corto  -> tapped(pos)
##   deslizar     -> swiped(puntos, duración)
## Dibuja la estela del dedo para que se vea el gesto.

signal tapped(pos: Vector2)
signal swiped(points: PackedVector2Array, duration: float)

const TAP_MAX_DIST := 24.0

var _finger := -1
var _points := PackedVector2Array()
var _start_ms := 0
var _trail := PackedVector2Array()
var _trail_alpha := 0.0
var _last_tap_hold := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## ¿El dedo sigue apoyado? El remate con potencia (P1-01) usa esto para
## mostrar la barra mientras se carga el gesto.
func is_holding() -> bool:
	return _finger != -1


## Tiempo real (segundos) que lleva el dedo apoyado; 0 si no hay gesto.
func held_seconds() -> float:
	if _finger == -1:
		return 0.0
	return (Time.get_ticks_msec() - _start_ms) / 1000.0


## Tiempo real (segundos) que llevó el último toque. El pase bombeado (P1-09)
## lo usa para distinguir un toque normal de uno mantenido.
func last_tap_hold_seconds() -> float:
	return _last_tap_hold


## Puntos del gesto en curso (para previsualizar potencia/efecto).
func current_points() -> PackedVector2Array:
	return _points


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _finger == -1:
				_finger = st.index
				_points = PackedVector2Array([st.position])
				_start_ms = Time.get_ticks_msec()
		elif st.index == _finger:
			_points.append(st.position)
			_finger = -1
			var duration := (Time.get_ticks_msec() - _start_ms) / 1000.0
			if _points[_points.size() - 1].distance_to(_points[0]) < TAP_MAX_DIST:
				_last_tap_hold = duration
				tapped.emit(_points[0])
			else:
				_trail = _points
				_trail_alpha = 1.0
				swiped.emit(_points, duration)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _finger:
			_points.append(sd.position)


func _process(delta: float) -> void:
	if _finger != -1 or _trail_alpha > 0.0:
		var real_delta := delta / maxf(Engine.time_scale, 0.01)
		_trail_alpha = maxf(_trail_alpha - real_delta * 2.5, 0.0)
		queue_redraw()


func _draw() -> void:
	var pts := _points if _finger != -1 else _trail
	var a := 0.9 if _finger != -1 else _trail_alpha
	if pts.size() >= 2 and a > 0.0:
		draw_polyline(pts, Color(1.0, 1.0, 1.0, a), 7.0, true)
