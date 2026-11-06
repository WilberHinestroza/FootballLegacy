extends RefCounted
class_name MatchRatingCalculator

## Aprendizaje directo de FL: determinePlayerOfTheMatch (y, por
## extensión, cualquier rating de partido) debe usar EVENTOS REALES
## del partido, nunca el overall del jugador ni umbrales fijos.
## Esta clase acumula eventos y calcula un rating 1-10 al final.

## 10-oct (números realistas, tools/MatchNumbersProbe): con base 6,5, +1,0
## por gol y +0,4 por acción bien hecha, un jugador normal promediaba 8-9,5.
## Ahora un partido correcto ronda 6,5-7 y un 8+ hay que ganárselo.
const BASE_RATING := 6.3

var _rating: float = BASE_RATING
var _events_log: Array[Dictionary] = []

func register_goal() -> void:
	_rating += 0.9
	_events_log.append({"type": "goal", "delta": 0.9})

## Remate bien pegado que el arquero atajó: compensa el "fallo" que anotó
## la jugada (queda apenas en positivo).
func register_shot_on_target() -> void:
	_rating += 0.35
	_events_log.append({"type": "shot_on_target", "delta": 0.35})

## VAR: el gol que se había anotado no vale.
func unregister_goal() -> void:
	_rating -= 0.9
	_events_log.append({"type": "goal_disallowed", "delta": -0.9})

func register_key_pass_success() -> void:
	_rating += 0.22
	_events_log.append({"type": "key_pass_success", "delta": 0.22})

func register_decision_failed(kind: String) -> void:
	_rating -= 0.25
	_events_log.append({"type": "decision_failed", "kind": kind, "delta": -0.25})

func register_tackle_success() -> void:
	_rating += 0.2
	_events_log.append({"type": "tackle_success", "delta": 0.2})

func register_card(is_red: bool) -> void:
	_rating -= 1.5 if is_red else 0.4
	_events_log.append({"type": "card", "delta": -1.5 if is_red else -0.4})

## Ajuste por RESULTADO del partido (ganó/perdió tu equipo) — el mismo
## que reciben todos los demás jugadores vía MatchEngine._apply_result_
## to_ratings(). Bug real de la auditoría: esa función solo escribía a
## _ratings[user_player] (un dict que el usuario NUNCA lee para su nota
## final — la nota real siempre sale de get_rating() acá abajo), así que
## el usuario quedaba sistemáticamente en desventaja/ventaja respecto a
## un compañero con las mismas estadísticas.
func register_result(delta: float) -> void:
	_rating += delta
	_events_log.append({"type": "match_result", "delta": delta})

func get_rating() -> float:
	return clamp(_rating, 1.0, 10.0)

func get_events_log() -> Array[Dictionary]:
	return _events_log
