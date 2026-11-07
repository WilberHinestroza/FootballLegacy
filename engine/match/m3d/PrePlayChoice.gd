extends RefCounted
## Elección antes de la jugada (P1-13).
##
## Funciones puras: cuando arranca una jugada de ataque y tu jugador tiene el
## balón, puedes elegir qué hace en el primer segundo:
##   - CONDUCIR: arranca hacia la portería con sprint corto.
##   - PASE RÁPIDO: suelta la pelota al compañero mejor colocado antes de que
##     la defensa se cierre.
##   - AGUANTAR: protege el balón, frena y deja que la jugada se abra; los
##     rivales cercanos tardan un poco en entrar.
##
## No toca nodos ni UI: se prueba en headless y lo usa el partido 3D.

const DRIVE := "drive"
const QUICK_PASS := "pass"
const HOLD := "hold"
const ALL := [DRIVE, QUICK_PASS, HOLD]

## Metros que avanza el jugador al elegir CONDUCIR.
const DRIVE_DISTANCE := 14.0
## Nivel de sprint que se aplica al conducir (1 = sprint normal).
const DRIVE_BOOST := 1
## Distancia mínima y máxima (m) para que un compañero sea un pase válido.
const MIN_PASS_DISTANCE := 2.0
const PASS_RANGE := 34.0
## Cuánto pesa la distancia frente al avance hacia la portería al puntuar un pase.
const PASS_DISTANCE_PENALTY := 0.25
## Segundos que el jugador se queda aguantando el balón.
const HOLD_SECONDS := 1.2
## Radio (m) en el que los rivales pierden el primer intento de entrada.
const HOLD_SHIELD_RADIUS := 4.0
## Enfriamiento de entrada que se impone a los rivales cercanos al aguantar.
const HOLD_TACKLE_DELAY := 0.9
## Recuperación de stamina (0..1) por aguantar un momento.
const HOLD_STAMINA_GAIN := 0.03
## Al arrancar tu jugada con el balón: ningún rival empieza más cerca que esto (m)…
const OPENING_SPACE := 6.5 # Wilber: "los rivales no deben estar tan encima para que la jugada tenga inicio"
## En defensa: a cuánto empiezas como mínimo del rival que lleva el balón (m).
const DEFENSE_SPACE := 5.5
## …y los de alrededor tardan esto (s de juego) en poder entrar. Sin esto, quieto
## leyendo la pantalla te lo robaban en menos de un segundo ("injugables").
const OPENING_TACKLE_DELAY := 1.8
const OPENING_RADIUS := 9.0


## Dónde poner a un rival que arranca encima del balón: misma dirección, a
## OPENING_SPACE como mínimo. Si ya está lejos, se queda donde está.
static func opening_push(ball_pos: Vector3, rival_pos: Vector3) -> Vector3:
	var off := Vector3(rival_pos.x - ball_pos.x, 0.0, rival_pos.z - ball_pos.z)
	var d := off.length()
	if d >= OPENING_SPACE:
		return rival_pos
	var dir := off / d if d > 0.01 else Vector3(1.0, 0.0, 0.0)
	var p := ball_pos + dir * OPENING_SPACE
	p.y = rival_pos.y
	return p


## ¿La elección existe?
static func is_valid(choice: String) -> bool:
	return choice in ALL


## Texto del botón para cada elección.
static func label(choice: String) -> String:
	match choice:
		DRIVE:
			return "CONDUCIR"
		QUICK_PASS:
			return "PASE RÁPIDO"
		HOLD:
			return "AGUANTAR"
	return ""


## Punto al que conduce el jugador: `distance` metros hacia la portería rival.
static func drive_target(carrier: Vector3, goal: Vector3, distance := DRIVE_DISTANCE) -> Vector3:
	var to := Vector3(goal.x - carrier.x, 0.0, goal.z - carrier.z)
	if to.length() < 0.01:
		return carrier
	return carrier + to.normalized() * maxf(distance, 0.0)


## Puntuación de un posible pase: premia avanzar hacia la portería y castiga
## la distancia. Devuelve -1.0 si el compañero está fuera de rango.
static func pass_score(candidate: Vector3, carrier: Vector3, goal: Vector3,
		max_range := PASS_RANGE) -> float:
	var to := Vector3(candidate.x - carrier.x, 0.0, candidate.z - carrier.z)
	var d := to.length()
	if d < MIN_PASS_DISTANCE or d > max_range:
		return -1.0
	var to_goal := Vector3(goal.x - carrier.x, 0.0, goal.z - carrier.z)
	if to_goal.length() < 0.01:
		return -d
	return to.dot(to_goal.normalized()) - d * PASS_DISTANCE_PENALTY


## Índice del mejor pase dentro de una lista de posiciones, o -1 si ninguno
## avanza lo suficiente. `candidates` contiene Vector3 en orden de jugadores.
static func best_pass_index(candidates: Array, carrier: Vector3, goal: Vector3,
		max_range := PASS_RANGE) -> int:
	var best := -1
	var best_score := 0.0
	for i in candidates.size():
		var score := pass_score(candidates[i], carrier, goal, max_range)
		if score > best_score:
			best_score = score
			best = i
	return best


## Stamina tras aguantar el balón: respira y recupera un poco, sin pasar del 100%.
static func hold_stamina(stamina: float, gain := HOLD_STAMINA_GAIN) -> float:
	return clampf(stamina + maxf(gain, 0.0), 0.0, 1.0)
