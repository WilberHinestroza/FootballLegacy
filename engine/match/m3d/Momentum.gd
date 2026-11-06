extends RefCounted
## Cambio de ritmo (P1-14).
##
## El jugador no arranca y frena igual: la aceleración responde rápido al toque,
## pero la frenada conserva inercia, sobre todo si venía esprintando. Además,
## esprintar consume estamina del partido y el multi-toque cuesta más.
##
## Funciones puras: no tocan nodos ni UI. Las usa SoccerPlayer/SoccerMatch y se
## prueban en headless.

## Aceleración al arrancar o al cambiar de ritmo (m/s²).
const ACCEL := 38.0
## Frenada normal sin balón (m/s²). Menor que ACCEL: el cuerpo pesa.
const BRAKE := 20.0
## Frenada viniendo de un sprint (m/s²). Cuesta más parar.
const BRAKE_SPRINT := 12.0
## Frenada con el balón en los pies (m/s²): se protege el control.
const BRAKE_BALL := 16.0
## Estamina del partido (0..1) que cuesta un segundo de sprint.
const SPRINT_DRAIN := 0.006
## Estamina extra por segundo y nivel de multi-toque.
const BOOST_DRAIN := 0.010
## Diferencia mínima (m/s) para considerar que se acelera o se frena.
const EPSILON := 0.01


## Ritmo (m/s²) con el que la velocidad actual se acerca a la deseada.
## Acelerar es rápido; frenar arrastra inercia, y más si venías de sprint.
static func rate(current_speed: float, desired_speed: float, sprinting := false,
		has_ball := false) -> float:
	if desired_speed + EPSILON >= current_speed:
		return ACCEL
	if sprinting:
		return BRAKE_SPRINT
	if has_ball:
		return BRAKE_BALL
	return BRAKE


## Distancia (m) que recorre un jugador antes de detenerse desde `speed` con
## una frenada `brake`. Sirve para comparar la inercia del sprint con la normal.
static func stopping_distance(speed: float, brake := BRAKE) -> float:
	var v := maxf(speed, 0.0)
	var b := maxf(brake, 0.001)
	return v * v / (2.0 * b)


## Estamina que se gasta en `delta` segundos esprintando (`sprinting`) con un
## nivel de multi-toque `boost` (0 = sin boost).
static func stamina_cost(delta: float, sprinting: bool, boost := 0) -> float:
	var d := maxf(delta, 0.0)
	if d <= 0.0:
		return 0.0
	var per_second := SPRINT_DRAIN if sprinting else 0.0
	per_second += BOOST_DRAIN * float(maxi(boost, 0))
	return per_second * d
