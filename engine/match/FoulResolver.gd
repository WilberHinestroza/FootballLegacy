extends RefCounted
class_name FoulResolver
## Reglas puras de faltas y balón parado (P0-03).
##
## Sin nodos, sin UI y sin estado: solo matemática de cancha. Lo usan el
## partido 3D (match.gd), la IA (ai_brain.gd) y las sondas de regresión.
## El árbitro aporta multiplicadores deterministas desde DecisionResolver.

## Medidas reglamentarias del campo y del área grande (mismas que SoccerMatch).
const FIELD_LENGTH := 105.0
const BOX_DEPTH := 16.5
const BOX_WIDTH := 40.3

## ¿La posición cae dentro del área que defiende el rival?
## `attacking_dir` = +1 si el equipo ataca hacia +X, -1 si ataca hacia -X.
static func in_penalty_area(pos: Vector3, attacking_dir: float,
		field_length := FIELD_LENGTH, box_depth := BOX_DEPTH, box_width := BOX_WIDTH) -> bool:
	if attacking_dir == 0.0:
		return false
	var dir := signf(attacking_dir)
	var goal_line := dir * field_length * 0.5
	var depth := (goal_line - pos.x) * dir
	return depth >= 0.0 and depth <= box_depth and absf(pos.z) <= box_width * 0.5

## Qué cobra el equipo que ataca hacia `attacking_dir` tras una falta:
## "penalty" dentro del área, "free_kick" en campo rival y "none" en el propio.
static func set_piece_kind(pos: Vector3, attacking_dir: float,
		field_length := FIELD_LENGTH, box_depth := BOX_DEPTH, box_width := BOX_WIDTH) -> String:
	if attacking_dir == 0.0:
		return "none"
	if in_penalty_area(pos, attacking_dir, field_length, box_depth, box_width):
		return "penalty"
	if pos.x * signf(attacking_dir) > 0.0:
		return "free_kick"
	return "none"

## Lectura defensiva 0..1: decisión + sangre fría. Más lectura = menos riesgo.
static func discipline(decision_making: float, composure: float) -> float:
	return clampf(decision_making * 0.6 + composure * 0.4, 0.0, 1.0)

## Probabilidad de que una entrada sea falta.
##   won     el defensor llegó al balón
##   slide   barrida (más arriesgada)
##   dodge   el atacante lo regateó antes de la entrada
##   referee_foul_mult  0.8 permisivo ... 1.35 estricto
static func foul_chance(won: bool, slide: bool, dodge: bool,
		decision_making: float, composure: float, referee_foul_mult := 1.0) -> float:
	var base: float
	if dodge:
		base = 0.42 if slide else 0.18
	elif slide:
		base = 0.14 if won else 0.58
	else:
		base = 0.03 if won else 0.14
	var risk := lerpf(1.35, 0.55, discipline(decision_making, composure))
	return clampf(base * risk * maxf(referee_foul_mult, 0.0), 0.0, 0.95)

## Probabilidad de amarilla para una falta (la roja directa no existe en el 3D;
## la doble amarilla la maneja match.gd).
static func card_chance(slide: bool, decision_making: float, composure: float,
		referee_card_mult := 1.0) -> float:
	var base := 0.55 if slide else 0.18
	var risk := lerpf(1.25, 0.70, discipline(decision_making, composure))
	return clampf(base * risk * maxf(referee_card_mult, 0.0), 0.0, 0.95)
