extends RefCounted
## Fuera de juego del partido 3D: solo geometría, sin UI ni azar (el azar del juez
## de línea y del VAR vive en DecisionResolver).
## Todo en coordenadas del EQUIPO QUE ATACA: x crece hacia la portería rival y la
## línea del medio campo está en x = 0.
##
## Regla: en el instante del pase, un atacante está en fuera de juego si está en
## campo rival, por delante del balón y por delante del penúltimo rival (el portero
## cuenta). Solo se pita si luego interviene (toca el balón).

## Margen que se da por "en línea" (la misma altura es legal).
const TOLERANCE := 0.05


## Línea de fuera de juego: lo más adelantado entre el penúltimo defensor, el balón
## y el medio campo. `defender_xs` = x de todos los rivales (portero incluido).
static func line_x(defender_xs: Array, ball_x: float) -> float:
	var xs := defender_xs.duplicate()
	xs.sort()
	xs.reverse() # el más cercano a su portería primero (x más alta)
	var second := -INF
	if xs.size() >= 2:
		second = float(xs[1])
	elif xs.size() == 1:
		second = float(xs[0])
	return maxf(maxf(second, ball_x), 0.0)


## Cuánto está por delante de la línea (m). > TOLERANCE = fuera de juego.
static func margin(player_x: float, line: float) -> float:
	return player_x - line


static func is_offside(player_x: float, line: float) -> bool:
	return margin(player_x, line) > TOLERANCE


## Hasta dónde sube un atacante que espera el pase: la línea más su error de
## lectura `slack` en metros (AiTuning.offside_slack; negativo = se queda antes).
static func hold_x(line: float, slack: float) -> float:
	return line + slack


## Un defensor deja "colgado" a un atacante adelantado (no lo persigue) si está
## más de `gap` m por delante de la línea y el balón todavía está lejos.
static func leave_offside_runner(attacker_x: float, line: float, ball_dist: float, gap := 1.0) -> bool:
	return attacker_x > line + gap and ball_dist > 18.0
