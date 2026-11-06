extends RefCounted
## Pase bombeado (P1-09): matemática pura del balón levantado por encima del
## defensor.
##
## Con el frenado del aire `k` (el `linear_damp` del balón más el del proyecto)
## y la gravedad, calcula la velocidad vertical que hace que el balón alcance un
## ápice concreto, el tiempo que tarda en volver a la altura de salida y la
## velocidad horizontal para recorrer una distancia en ese tiempo. Así el pase
## cae en los pies del compañero y pasa por encima de la cabeza del rival.
##
## No toca nodos ni UI: se prueba en headless y lo usa el partido 3D.

const GRAVITY := 9.8
## Altura (m) por encima de la cabeza del defensor a la que debe pasar el balón.
const CLEARANCE := 0.45
## Altura de referencia (m) de un defensor de campo.
const DEFENDER_HEIGHT := 1.85


## Altura máxima (m) que alcanza el balón con velocidad vertical `vy` y
## frenado `k`. Devuelve 0 si no llega a subir.
static func apex_height(vy: float, k: float) -> float:
	if vy <= 0.0:
		return 0.0
	var drag := maxf(k, 0.001)
	var t_apex := log((drag * vy + GRAVITY) / GRAVITY) / drag
	return maxf((vy - GRAVITY * t_apex) / drag, 0.0)


## Velocidad vertical (m/s) necesaria para que el ápice sea `apex` metros.
## Búsqueda binaria: la altura crece de forma monótona con `vy`.
static func vy_for_apex(apex: float, k: float) -> float:
	if apex <= 0.0:
		return 0.0
	var drag := maxf(k, 0.001)
	var low := 0.0
	var high := 60.0
	for _i in 48:
		var mid := (low + high) * 0.5
		if apex_height(mid, drag) < apex:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5


## Tiempo (s) que tarda el balón en volver a la altura de salida.
static func hang_time(vy: float, k: float) -> float:
	if vy <= 0.0:
		return 0.0
	var drag := maxf(k, 0.001)
	var high := 1.0
	while _height_at(vy, high, drag) > 0.0 and high < 20.0:
		high *= 2.0
	var low := 0.001
	for _i in 48:
		var mid := (low + high) * 0.5
		if _height_at(vy, mid, drag) > 0.0:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5


## Velocidad horizontal (m/s) para recorrer `dist` metros en `t` segundos.
static func horizontal_speed(dist: float, t: float, k: float) -> float:
	var drag := maxf(k, 0.001)
	var f := (1.0 - exp(-drag * maxf(t, 0.01))) / drag
	return maxf(dist, 0.0) / maxf(f, 0.001)


## Ápice recomendado para superar a un defensor: su altura más un margen.
static func clearance_apex(defender_height := DEFENDER_HEIGHT) -> float:
	return maxf(defender_height, 0.0) + CLEARANCE


# ---------- física vertical ----------

## Altura del balón en el instante `t` (saliendo desde y = 0).
static func _height_at(vy: float, t: float, k: float) -> float:
	var a := vy + GRAVITY / k
	return a * (1.0 - exp(-k * t)) / k - GRAVITY * t / k
