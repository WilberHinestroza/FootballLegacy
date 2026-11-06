extends RefCounted
class_name MatchSimulator

## Simulación ESTADÍSTICA e instantánea de un partido de IA (sin narración,
## sin eventos). NO usar MatchEngine para esto: MatchEngine es interactivo
## y lento (timers de ritmo por minuto). Aquí solo importa un marcador
## plausible según la fuerza de cada equipo.
##
## Determinista: se le pasa un RandomNumberGenerator ya sembrado por
## fixture, para que el resultado no cambie al recargar la partida.

const BASE_XG := 1.35          # goles esperados de un equipo medio en un partido medio
const HOME_ADVANTAGE := 6.0    # en "puntos de fuerza"
const STRENGTH_TO_XG := 0.042  # cuánto xG mueve cada punto de diferencia de fuerza — subido de 0.028: con la fuerza ya calculada bien (top-18 del plantel, no el promedio de todos), esto es lo que hacía falta para que un Real Madrid le gane a un Rayo Vallecano la mayoría de las veces sin volver los partidos un resultado cantado (siguen pasando sorpresas, solo que ya no son la mitad de las veces)
const MIN_XG := 0.12
const MAX_XG := 4.5

## Devuelve [goles_local, goles_visitante].
static func simulate(home_strength: float, away_strength: float, rng: RandomNumberGenerator) -> Array:
	var diff: float = (home_strength - away_strength) + HOME_ADVANTAGE
	var home_xg: float = clampf(BASE_XG + diff * STRENGTH_TO_XG, MIN_XG, MAX_XG)
	var away_xg: float = clampf(BASE_XG - diff * STRENGTH_TO_XG, MIN_XG, MAX_XG)
	return [_poisson(home_xg, rng), _poisson(away_xg, rng)]

static func _poisson(lambda: float, rng: RandomNumberGenerator) -> int:
	# Algoritmo de Knuth. lambda acotada arriba, así que el bucle es corto.
	var threshold: float = exp(-lambda)
	var k: int = 0
	var p: float = 1.0
	while p > threshold:
		k += 1
		p *= rng.randf()
	return k - 1
