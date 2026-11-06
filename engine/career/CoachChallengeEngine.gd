extends RefCounted
class_name CoachChallengeEngine

## RETO DEL DT (10-oct, paquete de minijuegos #14): antes de cada partido
## oficial el entrenador te pide algo concreto. Cumplirlo sube su confianza
## y da XP de carrera; no cumplirlo no castiga. DETERMINISTA por partido
## (jugador + día): la previa y el resumen calculan el mismo reto sin
## guardar nada.

const REWARD_TRUST := 3
const REWARD_XP := 25

const POOL := [
	{"id": "goal", "text": "Quiero un gol tuyo hoy.", "pos": ["ST", "MF"]},
	{"id": "rating7", "text": "Terminá el partido con nota 7 o más.", "pos": ["ST", "MF", "DF", "GK"]},
	{"id": "key2", "text": "Dame dos jugadas de ataque bien hechas (pases clave o regates).", "pos": ["ST", "MF"]},
	{"id": "tackle2", "text": "Ganá dos duelos defensivos.", "pos": ["DF", "MF"]},
	{"id": "clean", "text": "Cabeza fría: ni una tarjeta.", "pos": ["DF", "MF", "ST", "GK"]},
	{"id": "win65", "text": "Ganemos, y vos con nota 6,5 o más.", "pos": ["ST", "MF", "DF", "GK"]},
	{"id": "noflop", "text": "No quiero toques flojos: como mucho uno en todo el partido.", "pos": ["ST", "MF", "DF", "GK"]},
]

## Reto de este partido, o {} si no corresponde (amistoso / sin jugador).
static func for_fixture(player: PlayerData, fixture: Dictionary) -> Dictionary:
	if player == null or fixture.is_empty() or String(fixture.get("competition", "")) == "friendly":
		return {}
	var options: Array = POOL.filter(func(c): return player.position in (c["pos"] as Array))
	if options.is_empty():
		return {}
	var key: String = "%s|%d|%s" % [player.player_name, int(fixture.get("epoch_day", 0)), String(fixture.get("home_club_id", fixture.get("home_country", "")))]
	return options[absi(hash("coachchallenge:" + key)) % options.size()]

## ¿Cumplido? `result` = MatchState.match_result, `sign` = 1 ganó / 0 / -1,
## `gestures` = MatchState.gesture_stats.
static func is_met(challenge: Dictionary, result: Dictionary, sign: int, gestures: Dictionary) -> bool:
	if challenge.is_empty() or not bool(result.get("user_played", true)):
		return false
	var rating: float = float(result.get("user_rating", 6.0))
	var key_ok: int = 0
	var tackles: int = 0
	for ev in result.get("rating_events", []):
		match String(ev.get("type", "")):
			"key_pass_success": key_ok += 1
			"tackle_success": tackles += 1
	var total: int = int(gestures.get("perfecto", 0)) + int(gestures.get("bueno", 0)) + int(gestures.get("regular", 0)) + int(gestures.get("flojo", 0))
	match String(challenge.get("id", "")):
		"goal": return int(result.get("user_goals", 0)) >= 1
		"rating7": return rating >= 7.0
		"key2": return key_ok >= 2
		"tackle2": return tackles >= 2
		"clean": return not bool(result.get("user_red_carded", false)) and int(result.get("user_yellows", 0)) == 0
		"win65": return sign > 0 and rating >= 6.5
		"noflop": return total > 0 and int(gestures.get("flojo", 0)) <= 1
	return false
