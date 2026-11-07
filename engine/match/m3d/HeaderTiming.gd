extends RefCounted
## Cabezazo con timing (P1-11): ventana de contacto y calidad del testazo.
##
## El balón solo se puede cabecear cuando baja por la franja de la cabeza. El
## jugador más cercano sigue teniendo prioridad, pero el contacto ya no es
## automático: si llega tarde (el balón ya pasó por debajo de la ventana) o
## queda lejos, el testazo sale flojo, desviado o no sale. La altura ideal y la
## tolerancia dependen de la fuerza y la sangre fría del jugador.
##
## No toca nodos ni UI: se prueba en headless y lo usa el partido 3D.

## Franja de altura (m) en la que la cabeza puede golpear el balón.
const MIN_HEIGHT := 1.55
const MAX_HEIGHT := 1.98
## Altura (m) de contacto ideal con un jugador de fuerza media.
const IDEAL_HEIGHT := 1.82
## Distancia horizontal (m) a la que el contacto es cómodo.
const COMFORT_DISTANCE := 0.45
## Distancia máxima (m) a la que se puede intentar el cabezazo con temple alto.
const MAX_DISTANCE := 1.05
## Por debajo de esta calidad el jugador llega tarde y no golpea.
const MISS_QUALITY := 0.12
## Calidad a partir de la cual el cabezazo se considera limpio.
const CLEAN_QUALITY := 0.55


## ¿El balón está en la franja de cabeza y bajando? `vy` es su velocidad vertical.
static func in_window(ball_y: float, vy: float) -> bool:
	return vy < 1.0 and ball_y >= MIN_HEIGHT and ball_y <= MAX_HEIGHT


## Altura ideal de contacto: un jugador fuerte cabecea algo más arriba.
static func ideal_height(strength := 0.5) -> float:
	return lerpf(1.72, 1.92, clampf(strength, 0.0, 1.0))


## Tolerancia vertical (m) alrededor de la altura ideal.
static func height_tolerance(strength := 0.5) -> float:
	return lerpf(0.36, 0.52, clampf(strength, 0.0, 1.0))


## Calidad 0..1 según la altura del balón en el momento del contacto.
static func height_quality(ball_y: float, strength := 0.5) -> float:
	var ideal := ideal_height(strength)
	var half := height_tolerance(strength)
	return clampf(1.0 - absf(ball_y - ideal) / half, 0.0, 1.0)


## Distancia máxima de contacto: la sangre fría permite estirarse algo más.
static func reach(composure := 0.5) -> float:
	return lerpf(0.78, MAX_DISTANCE, clampf(composure, 0.0, 1.0))


## Calidad 0..1 según la distancia horizontal al balón.
static func distance_quality(dist: float, composure := 0.5) -> float:
	var r := reach(composure)
	if dist <= COMFORT_DISTANCE:
		return 1.0
	if dist >= r:
		return 0.0
	return clampf(1.0 - (dist - COMFORT_DISTANCE) / (r - COMFORT_DISTANCE), 0.0, 1.0)


## Calidad total del cabezazo (0 = no llega, 1 = contacto limpio).
static func quality(ball_y: float, dist: float, strength := 0.5, composure := 0.5) -> float:
	return height_quality(ball_y, strength) * distance_quality(dist, composure)


## ¿El contacto llega a producirse? Si no, el balón sigue de largo.
static func can_contact(q: float) -> bool:
	return q > MISS_QUALITY


## ¿El testazo sale limpio (a puerta y con fuerza)?
static func is_clean(q: float) -> bool:
	return q >= CLEAN_QUALITY


## La fuerza del cabezazo baja cuando el contacto es malo.
static func power_scale(q: float) -> float:
	return lerpf(0.62, 1.0, clampf(q, 0.0, 1.0))


## La puntería empeora cuando el contacto es malo.
static func accuracy_scale(q: float) -> float:
	return lerpf(0.4, 1.0, clampf(q, 0.0, 1.0))


# ---------- Cabezazo de TU jugador (8-nov) ----------
# "Siguen siendo difíciles y raros": la ventana de arriba (1,55-1,98 m, bajando y a
# <0,9 m) exige estar clavado bajo el balón. Al jugador que controlas se le da algo
# de margen — como en cualquier juego de fútbol, el que manejas "llega" — y si un
# rival está más cerca, se decide un duelo por fuerza en vez de ganarlo siempre él.

## Alcance extra (m) del jugador que controlas.
const ASSIST_REACH := 0.35
## Franja de altura ampliada para tu jugador (m).
const ASSIST_MIN_HEIGHT := 1.4
const ASSIST_MAX_HEIGHT := 2.1
## Tolerancia de altura ampliada (multiplica height_tolerance).
const ASSIST_TOLERANCE := 1.35


## ¿Tu jugador puede cabecear ya? (también con el balón casi en lo alto de su curva)
static func in_window_assisted(ball_y: float, vy: float) -> bool:
	return vy < 2.5 and ball_y >= ASSIST_MIN_HEIGHT and ball_y <= ASSIST_MAX_HEIGHT


## Calidad del cabezazo de tu jugador, con su margen de altura y alcance.
static func quality_assisted(ball_y: float, dist: float, strength := 0.5, composure := 0.5) -> float:
	var ideal := ideal_height(strength)
	var half := height_tolerance(strength) * ASSIST_TOLERANCE
	var hq := clampf(1.0 - absf(ball_y - ideal) / half, 0.0, 1.0)
	return hq * distance_quality(maxf(dist - ASSIST_REACH, 0.0), composure)


## Duelo aéreo con un rival más cerca del balón: probabilidad de que lo ganes tú.
static func duel_win_chance(my_strength: float, rival_strength: float) -> float:
	return clampf(0.62 + (my_strength - rival_strength) * 0.6, 0.35, 0.88)

