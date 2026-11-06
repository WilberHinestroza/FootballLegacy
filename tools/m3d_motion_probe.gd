extends Node
## Sonda de regresión P0-11 / P1-71 · giros y transiciones de animación.
##   godot --headless --path . res://tools/M3DMotionProbe.tscn
##
## Valida las funciones puras que usa SoccerPlayer para girar y para mezclar
## locomoción: el giro de 180° no es instantáneo, cuesta velocidad, converge sin
## pasarse y los tiempos de mezcla quedan dentro de un rango razonable.

var fails := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		fails += 1
		print("FALLA: ", msg)

func _near(a: float, b: float, eps := 0.0001) -> bool:
	return absf(a - b) <= eps

func _ready() -> void:
	_test_turn_speed_factor()
	_test_turn_toward()
	_test_locomotion_blend()
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)

## El castigo por giro es monótono: de frente 1,0 y a 180° el mínimo.
func _test_turn_speed_factor() -> void:
	var p := SoccerPlayer.new()
	_check(_near(p.turn_speed_factor(1.0), 1.0), "ir de frente no cuesta velocidad")
	_check(_near(p.turn_speed_factor(-1.0), 0.30), "el giro de 180° no aplica el castigo mínimo")
	var prev: float = p.turn_speed_factor(-1.0)
	var monotonic := true
	for i in range(1, 41):
		var align := -1.0 + i * 0.05
		var f: float = p.turn_speed_factor(align)
		if f < prev - 0.0001:
			monotonic = false
		prev = f
	_check(monotonic, "el castigo por giro no es monótono")
	_check(p.turn_speed_factor(0.0) > 0.30 and p.turn_speed_factor(0.0) < 1.0,
		"el giro de 90° no queda entre el mínimo y el máximo")
	_check(p.turn_speed_factor(1.0) > p.turn_speed_factor(0.0)
		and p.turn_speed_factor(0.0) > p.turn_speed_factor(-1.0),
		"girar más no cuesta más velocidad")
	p.free()

## Un giro de 180° avanza poco a poco, sin teletransporte ni sobrepaso.
func _test_turn_toward() -> void:
	var p := SoccerPlayer.new()
	p.facing = Vector3(0.0, 0.0, 1.0)
	var start: Vector3 = p.facing
	var step: Vector3 = p._turn_toward(Vector3(0.0, 0.0, -1.0), 1.0 / 60.0, 12.0)
	_check(step.z > 0.95, "el primer frame de un giro de 180° no conserva la orientación")
	_check(not _near(step.z, -1.0), "el giro de 180° se completa de golpe en un frame")
	# Giro de 90°: debe quedar entre las dos direcciones en el primer frame.
	p.facing = start
	var side: Vector3 = p._turn_toward(Vector3(1.0, 0.0, 0.0), 1.0 / 60.0, 12.0)
	_check(side.z > 0.8 and side.x > 0.0, "el giro de 90° no avanza de forma progresiva")
	# Convergencia: en ~0,5 s a 7,2 rad/s debe haber completado el giro.
	p.facing = start
	for i in 30:
		p.facing = p._turn_toward(Vector3(0.0, 0.0, -1.0), 1.0 / 60.0, 7.2)
	_check(p.facing.z < -0.99, "el giro de 180° no termina en medio segundo")
	# Nunca se pasa de la dirección objetivo.
	p.facing = start
	var overshoot := false
	for i in 60:
		p.facing = p._turn_toward(Vector3(0.0, 0.0, -1.0), 1.0 / 60.0, 7.2)
		if p.facing.z < -1.0001:
			overshoot = true
	_check(not overshoot, "el giro se pasa de la dirección objetivo")
	_check(_near(p.facing.length(), 1.0), "el giro no conserva el vector unitario")
	# Un objetivo nulo no rompe la orientación actual.
	p.facing = start
	_check(_near(p._turn_toward(Vector3.ZERO, 1.0 / 60.0, 12.0).z, 1.0),
		"un objetivo nulo no conserva la orientación")
	p.free()

## La mezcla crece con el cambio de velocidad y al volver de una acción.
func _test_locomotion_blend() -> void:
	var p := SoccerPlayer.new()
	var still: float = p.locomotion_blend(0.0, 0.0)
	var fast: float = p.locomotion_blend(0.0, 8.0)
	var mid: float = p.locomotion_blend(2.0, 4.0)
	var recovering: float = p.locomotion_blend(0.0, 0.0, true)
	_check(_near(still, 0.06), "sin cambio de velocidad la mezcla no es la mínima")
	_check(fast > mid and mid > still, "más cambio de velocidad no alarga la mezcla")
	_check(_near(fast, 0.16), "un cambio grande de velocidad no usa la mezcla máxima")
	_check(recovering >= 0.18, "la vuelta desde una acción no alarga la mezcla")
	_check(still >= 0.05 and fast <= 0.2 and recovering <= 0.2,
		"algún tiempo de mezcla se sale del rango seguro")
	p.free()
