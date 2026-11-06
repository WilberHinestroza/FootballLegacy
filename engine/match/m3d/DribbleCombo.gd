extends RefCounted
## Combos de regate (P1-05).
##
## Funciones puras: encadenar dos o tres quiebros en direcciones distintas
## dentro de una ventana corta supera más fácil al defensor, y el defensor
## resiste según su atributo defensivo (`SoccerPlayer.duel_skill(true)`:
## fuerza, lectura y velocidad). El primer quiebro es normal; el segundo y el
## tercero suman probabilidad y dejan al rival mareado más tiempo.
##
## No toca nodos ni UI: se prueba en headless y lo usa el partido 3D.

## Tiempo máximo (s) entre quiebros para que cuenten como combo.
const WINDOW := 0.9
## Máximo de quiebros encadenados que suman bonus.
const MAX_CHAIN := 3
## Ángulo mínimo (grados) entre quiebros para que el combo valga: repetir el
## mismo lado no engaña a nadie.
const MIN_ANGLE_DEG := 35.0
## Probabilidad base de superar a un defensor.
const BASE_CHANCE := 0.55
## Bonus de probabilidad por cada quiebro extra del combo.
const COMBO_BONUS := 0.12
## Castigo por intentarlo contra el portero.
const KEEPER_PENALTY := 0.2
## Tiempo de mareo base y lo que suma cada quiebro extra.
const STUN_BASE := 0.9
const STUN_PER_CHAIN := 0.25


## ¿El nuevo quiebro cambia lo suficiente de dirección respecto al anterior?
static func is_chain(prev_dir: Vector3, dir: Vector3, min_angle_deg := MIN_ANGLE_DEG) -> bool:
	var a := Vector3(prev_dir.x, 0.0, prev_dir.z)
	var b := Vector3(dir.x, 0.0, dir.z)
	if a.length() < 0.001 or b.length() < 0.001:
		return false
	var angle := rad_to_deg(a.normalized().angle_to(b.normalized()))
	return angle >= min_angle_deg


## Nuevo eslabón del combo. Si la ventana ya venció o el gesto repite lado,
## empieza de cero en 1; si no, sube hasta MAX_CHAIN.
static func next_chain(prev_chain: int, prev_dir: Vector3, dir: Vector3, window_left: float) -> int:
	if prev_chain <= 0 or window_left <= 0.0 or not is_chain(prev_dir, dir):
		return 1
	return mini(prev_chain + 1, MAX_CHAIN)


## Probabilidad de dejar atrás a un defensor. `defender_duel` es 0..1.
static func beat_chance(dribbling: float, defender_duel: float, chain: int, is_keeper := false) -> float:
	var extra := maxi(chain - 1, 0)
	var chance := BASE_CHANCE + clampf(dribbling, 0.0, 1.0) * 0.4 \
		- clampf(defender_duel, 0.0, 1.0) * 0.35 \
		+ extra * COMBO_BONUS
	if is_keeper:
		chance -= KEEPER_PENALTY
	return clampf(chance, 0.15, 0.95)


## Mareo que deja el quiebro: crece con el combo (el rival queda fuera de la jugada).
static func stun_time(chain: int) -> float:
	return STUN_BASE + maxi(chain - 1, 0) * STUN_PER_CHAIN
