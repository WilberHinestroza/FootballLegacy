extends Node
## Sonda de regresión P1-33 / P1-34 · IA por atributos.
##   godot --headless --path . res://tools/AiTuningProbe.tscn
##
## Valida que las probabilidades, distancias y riesgos que usa AiBrain salgan
## de los atributos del jugador, con monotonía y límites razonables. No monta
## partido: AiTuning es puro a propósito (sin nodos ni UI).

const AiTuning = preload("res://engine/match/m3d/AiTuning.gd")

var fails := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		fails += 1
		print("FALLA: ", msg)

func _in_range(v: float, lo: float, hi: float) -> bool:
	return v >= lo - 0.0001 and v <= hi + 0.0001

func _ready() -> void:
	_test_delay()
	_test_attacking_choices()
	_test_support_and_runs()
	_test_defending()
	_test_vision_and_loose_ball()
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)

func _test_delay() -> void:
	var slow: float = AiTuning.decision_delay_scale(0.0)
	var fast: float = AiTuning.decision_delay_scale(1.0)
	_check(slow > fast, "leer peor no hace decidir más lento")
	_check(_in_range(slow, 1.3, 1.3) and _in_range(fast, 0.7, 0.7), "el retraso de decisión no respeta sus límites")

func _test_attacking_choices() -> void:
	_check(AiTuning.star_pass_chance(0.2, 0.2) < AiTuning.star_pass_chance(0.9, 0.9),
		"mejor passing/lectura no aumenta el pase a tu jugador")
	_check(_in_range(AiTuning.star_pass_chance(0.0, 0.0), 0.48, 0.74), "el pase al compañero se sale de rango")
	_check(AiTuning.star_cross_chance(0.2, 0.2) < AiTuning.star_cross_chance(0.9, 0.9),
		"mejor passing no aumenta el centro en tu jugada")
	_check(_in_range(AiTuning.star_cross_chance(0.0, 0.0), 0.42, 0.70), "el centro al área se sale de rango")
	_check(AiTuning.star_solo_shot_chance(0.2, 0.2) < AiTuning.star_solo_shot_chance(0.9, 0.9),
		"mejor tiro no aumenta la resolución individual")
	_check(_in_range(AiTuning.star_solo_shot_chance(0.0, 0.0), 0.28, 0.52),
		"el tiro individual se sale de rango")
	_check(AiTuning.shot_chance(0.8, 0.8, 10.0) > AiTuning.shot_chance(0.2, 0.2, 10.0),
		"mejor tiro no aumenta la decisión de chutar")
	_check(AiTuning.shot_chance(0.5, 0.5, 8.0) > AiTuning.shot_chance(0.5, 0.5, 28.0),
		"la distancia no reduce la decisión de chutar")
	_check(_in_range(AiTuning.shot_chance(0.0, 0.0, 40.0), 0.30, 0.85),
		"la decisión de chutar se sale de rango")
	_check(AiTuning.wing_cross_chance(0.2, 0.2) < AiTuning.wing_cross_chance(0.9, 0.9),
		"mejor passing no aumenta el centro desde la banda")
	_check(_in_range(AiTuning.wing_cross_chance(0.0, 0.0), 0.22, 0.40),
		"el centro desde la banda se sale de rango")
	_check(AiTuning.pressure_pass_chance(0.2, 0.2) < AiTuning.pressure_pass_chance(0.9, 0.9),
		"mejor passing/lectura no aumenta el pase bajo presión")
	_check(_in_range(AiTuning.pressure_pass_chance(0.0, 0.0), 0.08, 0.20),
		"el pase bajo presión se sale de rango")

func _test_support_and_runs() -> void:
	_check(AiTuning.support_distance(0.2, 0.2) < AiTuning.support_distance(0.9, 0.9),
		"mejor passing no ofrece el pase más lejos")
	_check(_in_range(AiTuning.support_distance(0.0, 0.0), 5.5, 7.5),
		"la distancia de apoyo se sale de rango")
	_check(AiTuning.run_depth(0.2, 0.2) < AiTuning.run_depth(0.9, 0.9),
		"más velocidad no hace picar más al hueco")
	_check(_in_range(AiTuning.run_depth(0.0, 0.0), 0.5, 1.8),
		"la profundidad del desmarque se sale de rango")

func _test_defending() -> void:
	_check(AiTuning.mark_tightness(0.9, 0.9, 10.0) < AiTuning.mark_tightness(0.2, 0.2, 10.0),
		"mejor defensor no marca más cerca")
	_check(AiTuning.mark_tightness(0.5, 0.5, 10.0) < AiTuning.mark_tightness(0.5, 0.5, 24.0),
		"el marcaje no se pega más cerca del área")
	_check(_in_range(AiTuning.mark_tightness(0.0, 0.0, 30.0), 0.55, 1.8),
		"la distancia de marcaje se sale de rango")
	_check(AiTuning.press_bias(0.2, 0.2) < AiTuning.press_bias(0.9, 0.9),
		"mejor lectura/fuerza no aumenta la presión")
	_check(_in_range(AiTuning.press_bias(0.0, 0.0), 0.6, 1.4),
		"el sesgo de presión se sale de rango")
	_check(AiTuning.slide_bias(0.9, 0.9) < AiTuning.slide_bias(0.2, 0.2),
		"más disciplina no reduce las planchas")
	_check(_in_range(AiTuning.slide_bias(0.0, 0.0), 0.18, 0.55),
		"el riesgo de plancha se sale de rango")

func _test_vision_and_loose_ball() -> void:
	_check(AiTuning.vision_weight(0.2) < AiTuning.vision_weight(0.9),
		"mejor passing no valora más al hombre libre")
	_check(_in_range(AiTuning.vision_weight(0.0), 0.55, 1.0),
		"el peso de visión se sale de rango")
	_check(AiTuning.loose_ball_anticipation(0.9) < AiTuning.loose_ball_anticipation(0.2),
		"mejor lectura no anticipa antes el balón suelto")
	_check(_in_range(AiTuning.loose_ball_anticipation(0.0), 0.75, 1.25),
		"la anticipación del balón suelto se sale de rango")
