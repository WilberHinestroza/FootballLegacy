extends RefCounted
class_name MatchEvent

## Evento emitido por MatchEngine. La UI/animaciones (equivalente a
## AnimationRegistry/AnimationDirector en FL) consumen estos eventos
## sin que el engine sepa nada de Sprites, Tweens, etc.
## Mantener el engine 100% desacoplado de la capa visual es uno de
## los aprendizajes más valiosos de Football Legacy V11.

enum Type {
	KICKOFF,
	MINUTE_TICK,
	GOAL,
	CARD_YELLOW,
	CARD_RED,
	INJURY,
	DECISION_REQUEST, # el engine necesita input del jugador (ver await abajo)
	DECISION_RESULT, # resultado de la decisión resuelta: {success, kind, rating_delta}
	PENALTY_AWARDED,
	HALFTIME,
	FULLTIME,
	EXTRA_TIME_START,
	PENALTY_SHOOTOUT,
	SUBSTITUTION,
	AMBIENT, # "algo pasa" sin consecuencia en el marcador ni decisión del usuario — textura, ver Match.gd
	GOAL_DISALLOWED, # VAR real (10-oct): gol anulado, NO cuenta. {home, scorer_name, scored_by_user, reason}
}

var type: Type
var minute: int = 0
var payload: Dictionary = {} # datos libres según el tipo (ej. {"player": p, "team": t})

func _init(p_type: Type, p_minute: int = 0, p_payload: Dictionary = {}) -> void:
	type = p_type
	minute = p_minute
	payload = p_payload
