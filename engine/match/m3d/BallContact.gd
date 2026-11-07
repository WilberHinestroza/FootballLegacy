class_name BallContact
extends RefCounted
## Contacto con el balón y entre cuerpos en el partido 3D.
##
## Funciones puras (atributos normalizados 0..1), sin nodos ni UI: se prueban en
## headless (tools/M3DBallContactProbe.tscn) y las usa el partido. Tres ideas:
##   1. Conducción a toques: cada toque adelanta el balón; esprintar lo alarga y el
##      buen regateador lo lleva más pegado. Mientras está lejos del pie está
##      "expuesto": el defensor que espera ese momento entra con ventaja.
##   2. Choque hombro con hombro: el más fuerte desequilibra al otro un instante
##      (tambaleo), lo que frena y quita precisión al pase o al tiro. No es falta.
##   3. Golpeo según dónde queda el balón respecto al pie: limpio a la distancia
##      justa; mordido si está pegado al cuerpo; estirado si se fue largo; forzado si
##      hay que girarse mucho para golpear.

## Metros extra que se adelanta el balón en cada toque corriendo (toque medio).
const TOUCH_BASE := 0.85
## Toque más largo posible (regate malo y esprintando): para normalizar la exposición.
const TOUCH_MAX := TOUCH_BASE * 1.15 * 1.35
## Multiplicador de velocidad mientras se tambalea.
const STUMBLE_SPEED := 0.55


## Multiplicador del largo del toque. `sprint_k` (0..1): cuánto va esprintando.
static func touch_length(dribbling: float, control: float, sprint_k: float) -> float:
	var skill := clampf(dribbling * 0.6 + control * 0.4, 0.0, 1.0)
	return lerpf(1.15, 0.7, skill) * lerpf(1.0, 1.35, clampf(sprint_k, 0.0, 1.0))


## Cuán suelto está el balón (0 pegado al pie .. 1 toque largo recién dado),
## a partir de los metros que va por delante de lo normal.
static func exposure(extra_ahead: float) -> float:
	return clampf(extra_ahead / TOUCH_MAX, 0.0, 1.0)


## Distancia a la que el defensor contiene (perfilado, sin entrar). Con el balón
## suelto se acerca para robar; con el balón pegado espera un poco más lejos.
static func contain_distance(exposure_now: float) -> float:
	return lerpf(1.5, 0.75, clampf(exposure_now, 0.0, 1.0))


## Alcance de la entrada: con el balón suelto se llega desde algo más lejos.
static func tackle_reach(exposure_now: float) -> float:
	return lerpf(1.7, 2.2, clampf(exposure_now, 0.0, 1.0))


## Multiplica las ganas de entrar de la IA. El que lee bien el juego espera el mal
## toque (casi no entra con el balón pegado y entra mucho con el balón suelto); el
## que lee mal entra en cualquier momento.
static func tackle_urge(decision_making: float, exposure_now: float) -> float:
	var d := clampf(decision_making, 0.0, 1.0)
	return lerpf(lerpf(1.0, 0.3, d), lerpf(1.6, 2.4, d), clampf(exposure_now, 0.0, 1.0))


## Lo que suma (o resta) a la probabilidad de ganar la entrada lo suelto del balón.
static func tackle_bonus(exposure_now: float) -> float:
	return (clampf(exposure_now, 0.0, 1.0) - 0.3) * 0.4


## Probabilidad de que el defensor desequilibre al que lleva el balón en un choque
## de hombros (si no, el que se tambalea es el defensor).
static func shoulder_win_chance(def_strength: float, att_strength: float, att_balance: float) -> float:
	var att := att_strength * 0.7 + att_balance * 0.3
	return clampf(0.5 + (def_strength - att) * 0.8, 0.15, 0.85)


## Cuánto dura el tambaleo según por cuánto se perdió el choque (0..1).
static func stumble_time(margin: float) -> float:
	return lerpf(0.35, 0.7, clampf(margin, 0.0, 1.0))


## Error extra del pase/tiro mientras dura el tambaleo (`left` segundos que quedan).
static func stumble_error(left: float) -> float:
	return 1.0 + clampf(left / 0.7, 0.0, 1.0) * 0.9


## Si al que pierde el choque se le va el balón (solo si ya iba suelto y lo perdió claro).
static func shoulder_loses_ball(exposure_now: float, margin: float) -> bool:
	return exposure_now > 0.55 and margin > 0.35


## Calidad del golpeo. `off` = metros que el balón está por delante (+) o por
## detrás (-) del punto ideal frente al pie; `turn_deg` = cuánto hay que girarse
## para golpear hacia donde se apunta. Devuelve {kind, power, error}:
## power multiplica la velocidad y error la desviación aleatoria.
static func strike(off: float, turn_deg: float) -> Dictionary:
	var power := 1.0
	var error := 0.85 # golpe limpio: algo más preciso que la media
	var kind := "clean"
	if off < -0.18:
		var k := clampf((-off - 0.18) / 0.3, 0.0, 1.0)
		kind = "jammed"
		power = lerpf(0.9, 0.75, k)
		error = lerpf(1.25, 1.7, k)
	elif off > 0.35:
		var k2 := clampf((off - 0.35) / 0.6, 0.0, 1.0)
		kind = "stretched"
		power = lerpf(0.95, 0.85, k2)
		error = lerpf(1.2, 1.55, k2)
	if turn_deg > 70.0:
		var k3 := clampf((turn_deg - 70.0) / 110.0, 0.0, 1.0)
		if kind == "clean":
			kind = "twisted"
			error = 1.0
		power *= lerpf(0.95, 0.82, k3)
		error *= lerpf(1.1, 1.8, k3)
	return {"kind": kind, "power": power, "error": error}
