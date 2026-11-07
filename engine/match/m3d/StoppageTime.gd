extends RefCounted
## Minutos de descuento, como en el fútbol de verdad: el cuarto árbitro levanta el
## cartel al 45' y al 90' y el reloj sigue (45+1', 90+3'...).
##
## Cuánto se añade sale de lo que paró el juego en esa parte: goles celebrados,
## cambios y revisiones del VAR, más un poco de azar. Funciones puras: no tocan
## nodos ni UI.

## Base de cada parte (la segunda siempre lleva más: cambios, pérdidas de tiempo).
const BASE := [1, 3]
## Minutos que suma cada gol / cada cambio / cada revisión del VAR.
const PER_GOAL := 0.5
const PER_SUB := 0.3
const PER_VAR := 1.5
## Tope de cada parte.
const MAX := [5, 9]
## Probabilidad de una última jugada tuya en el descuento final.
const LAST_PLAY_CHANCE := 0.35


## Minutos (enteros, ≥1) que se añaden al final de la parte `half` (0 = primera,
## 1 = segunda). `roll` es un número en [0, 1) para el azar.
static func minutes(half: int, goals: int, subs: int, var_reviews: int, roll: float) -> int:
	var h := clampi(half, 0, 1)
	var raw := float(BASE[h]) + goals * PER_GOAL + subs * PER_SUB + var_reviews * PER_VAR + roll * 2.0
	return clampi(int(floor(raw)), 1, int(MAX[h]))


## Texto del reloj: "45+2'" (el primer minuto del descuento ya es +1).
static func clock(base_minute: int, elapsed: float) -> String:
	return "%d+%d'" % [base_minute, maxi(1, int(ceil(elapsed)))]
