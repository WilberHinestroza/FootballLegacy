extends RefCounted
## Jugadas encadenadas (P1-12): un regate exitoso abre un remate con ventaja y
## un buen pase deja viva la asistencia unos segundos.
##
## Funciones puras: el bonus del remate nace del número de quiebros encadenados
## (P1-05) y se apaga con el tiempo; la ventana de asistencia crece con el
## atributo de pase. El partido usa estos valores para dar potencia y puntería
## al remate que nace de un regate y para contar el pase clave cuando el
## receptor define dentro de la ventana.
##
## No toca nodos ni UI: se prueba en headless y lo usa el partido 3D.

## Tiempo (s) que un regate exitoso deja abierto el remate con ventaja.
const DRIBBLE_SHOT_WINDOW := 2.2
## Ventana (s) de asistencia según el pase: de un pasador flojo a uno de élite.
const ASSIST_WINDOW_MIN := 2.6
const ASSIST_WINDOW_MAX := 4.2
## Bonus base de potencia por haber superado a un rival con el regate.
const BASE_SHOT_BONUS := 0.04
## Bonus extra por cada quiebro adicional del combo.
const SHOT_BONUS_PER_LINK := 0.05
const MAX_SHOT_BONUS := 0.14
## Lo mismo para la puntería (menos desviación del gesto).
const BASE_SHOT_ACCURACY := 0.03
const SHOT_ACCURACY_PER_LINK := 0.03
const MAX_SHOT_ACCURACY := 0.09
## Potencia extra del remate del receptor dentro de la ventana de asistencia.
const ASSIST_SHOT_BONUS := 0.06


## Multiplicador extra de potencia (0..MAX_SHOT_BONUS) del remate que nace de
## un regate. `window_left` es el tiempo que queda de la ventana.
static func shot_bonus(chain: int, window_left: float) -> float:
	if chain <= 0 or window_left <= 0.0:
		return 0.0
	var links := mini(chain, 3)
	var raw := BASE_SHOT_BONUS + maxi(links - 1, 0) * SHOT_BONUS_PER_LINK
	var decay := clampf(window_left / DRIBBLE_SHOT_WINDOW, 0.0, 1.0)
	return minf(raw * decay, MAX_SHOT_BONUS)


## Puntería extra (0..MAX_SHOT_ACCURACY) del remate encadenado.
static func shot_accuracy(chain: int, window_left: float) -> float:
	if chain <= 0 or window_left <= 0.0:
		return 0.0
	var links := mini(chain, 3)
	var raw := BASE_SHOT_ACCURACY + maxi(links - 1, 0) * SHOT_ACCURACY_PER_LINK
	var decay := clampf(window_left / DRIBBLE_SHOT_WINDOW, 0.0, 1.0)
	return minf(raw * decay, MAX_SHOT_ACCURACY)


## Segundos que la asistencia sigue viva tras el pase.
static func assist_window(passing: float) -> float:
	return lerpf(ASSIST_WINDOW_MIN, ASSIST_WINDOW_MAX, clampf(passing, 0.0, 1.0))


## ¿La asistencia sigue viva?
static func assist_active(window_left: float) -> bool:
	return window_left > 0.0


## Potencia extra del remate del receptor mientras la asistencia está viva.
static func assist_shot_bonus(window_left: float, total: float) -> float:
	if not assist_active(window_left):
		return 0.0
	var decay := clampf(window_left / maxf(total, 0.01), 0.0, 1.0)
	return ASSIST_SHOT_BONUS * decay


## ¿El regate deja el remate abierto? Se usa para el aviso del HUD.
static func is_shot_open(chain: int, window_left: float) -> bool:
	return shot_bonus(chain, window_left) > 0.0
