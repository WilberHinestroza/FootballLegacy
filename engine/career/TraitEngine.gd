extends RefCounted
class_name TraitEngine

## Desbloqueo de rasgos (Traits.gd) por hitos de CARRERA. Se llama en el
## rollover de temporada (WorldTickEngine._finish_season_rollover): mira
## los contadores acumulados del jugador y devuelve los rasgos nuevos que
## se ganó esta temporada. El llamador los añade a player.traits, guarda y
## publica un titular de prensa.
##
## Reglas (todas sobre contadores que YA existen en PlayerData):
##   killer_instinct → 50 goles de carrera
##   penalty_king    → 30 goles de carrera
##   dead_ball       → 45 asistencias de carrera
##   engine          → 120 partidos de carrera
##   rock            → 90 partidos de carrera y ser defensa/portero
##   talisman        → 3 títulos ganados como titular (trophies_won)

## `pos` (opcional): lista de posiciones broad ("GK"/"DF"/"MF"/"ST") que
## habilitan el rasgo. Sin `pos` → cualquier posición.
const RULES := [
	# Generales
	{"id": "penalty_king", "check": "goals", "min": 30},
	{"id": "killer_instinct", "check": "goals", "min": 50},
	{"id": "dead_ball", "check": "assists", "min": 45},
	{"id": "engine", "check": "matches", "min": 120},
	{"id": "talisman", "check": "trophies", "min": 3},
	# Por posición
	{"id": "poacher", "check": "goals", "min": 20, "pos": ["ST"]},
	{"id": "aerial_threat", "check": "goals", "min": 45, "pos": ["ST"]},
	{"id": "goal_machine", "check": "goals", "min": 90, "pos": ["ST"]},
	{"id": "playmaker", "check": "assists", "min": 25, "pos": ["MF"]},
	{"id": "speedster", "check": "matches", "min": 45, "pos": ["ST", "MF"]},
	{"id": "pressing_monster", "check": "matches", "min": 70, "pos": ["MF", "ST"]},
	{"id": "ball_winner", "check": "matches", "min": 60, "pos": ["MF", "DF"]},
	{"id": "rock", "check": "matches", "min": 80, "pos": ["DF", "GK"]},
	{"id": "last_man", "check": "matches", "min": 95, "pos": ["DF"]},
	{"id": "sweeper", "check": "matches", "min": 130, "pos": ["DF"]},
	{"id": "keeper_wall", "check": "matches", "min": 80, "pos": ["GK"]},
	{"id": "cat_reflexes", "check": "matches", "min": 160, "pos": ["GK"]},
	# Segunda tanda generales
	{"id": "free_kick_master", "check": "assists", "min": 60},
	{"id": "iron_man", "check": "matches", "min": 200},
	{"id": "big_game_player", "check": "trophies", "min": 4},
	{"id": "mentor", "check": "trophies", "min": 7},
	{"id": "fan_idol", "check": "reputation", "min": 80},
	# Tercera tanda (10-oct): historia de carrera y atributos.
	{"id": "captain", "check": "leadership", "min": 80},
	{"id": "one_club", "check": "seniority", "min": 6},
	{"id": "globetrotter", "check": "former_clubs", "min": 3},
	{"id": "national_hero", "check": "caps", "min": 30},
	{"id": "world_champion", "check": "world_cup", "min": 1},
	{"id": "nemesis_slayer", "check": "nemesis_wins", "min": 5},
	{"id": "golden_boy", "check": "level", "min": 15, "max_age": 21},
	{"id": "veteran", "check": "age", "min": 32},
	{"id": "assist_king", "check": "assists", "min": 80},
	{"id": "award_winner", "check": "individual", "min": 3},
	{"id": "centurion", "check": "goals", "min": 150},
	{"id": "marathon", "check": "matches", "min": 300},
	{"id": "clutch", "check": "attr:composure", "min": 82},
	{"id": "sprinter", "check": "attr:speed", "min": 86},
	{"id": "strongman", "check": "attr:strength", "min": 85},
	{"id": "penalty_stopper", "check": "matches", "min": 120, "pos": ["GK"]},
]

static func check_unlocks(player: PlayerData) -> Array:
	if player == null:
		return []
	var out: Array = []
	for rule in RULES:
		var id: String = String(rule["id"])
		if id in player.traits:
			continue
		var pos_ok: bool = not rule.has("pos") or player.position in (rule["pos"] as Array)
		# "max_age": hay que lograrlo ANTES de esa edad (Niño de oro).
		if rule.has("max_age") and player.age > int(rule["max_age"]):
			pos_ok = false
		if pos_ok and _meets(player, String(rule["check"]), int(rule["min"])):
			out.append(id)
	return out

static func _meets(player: PlayerData, check: String, minv: int) -> bool:
	match check:
		"goals":
			return player.career_goals >= minv
		"assists":
			return player.career_assists >= minv
		"matches":
			return player.career_matches >= minv
		"trophies":
			return player.trophies_won >= minv
		"reputation":
			return player.reputation >= minv
		_:
			# Contadores de historia / atributos: una sola fuente, la misma
			# que usan los logros.
			return CareerRpgEngine.value_of(player, check) >= minv

## Progreso actual hacia una regla (para la barra del menú de rasgos).
static func progress(player: PlayerData, check: String) -> int:
	match check:
		"goals": return player.career_goals
		"assists": return player.career_assists
		"matches": return player.career_matches
		"trophies": return player.trophies_won
		"reputation": return player.reputation
	return CareerRpgEngine.value_of(player, check)

static func check_label(check: String) -> String:
	match check:
		"goals": return "Goles de carrera"
		"assists": return "Asistencias de carrera"
		"matches": return "Partidos de carrera"
		"trophies": return "Títulos como titular"
		"reputation": return "Reputación"
		"leadership": return "Liderazgo"
		"seniority": return "Temporadas en tu club"
		"former_clubs": return "Clubes anteriores"
		"caps": return "Partidos con la selección"
		"world_cup": return "Mundiales ganados"
		"nemesis_wins": return "Victorias sobre tu rival"
		"level": return "Nivel de carrera"
		"age": return "Edad"
		"individual": return "Premios individuales"
		"attr:composure": return "Temple"
		"attr:speed": return "Velocidad"
		"attr:strength": return "Fuerza"
	return "Progreso"

## Regla de desbloqueo de un rasgo ({} si no tiene).
static func rule_for(id: String) -> Dictionary:
	for r in RULES:
		if String(r["id"]) == id:
			return r
	return {}

## Titular de prensa para un rasgo recién ganado.
static func headline_for(id: String) -> Dictionary:
	return {
		"headline": "Nuevo rasgo desbloqueado: %s" % Traits.name_of(id),
		"body": Traits.desc_of(id),
		"source": "CUERPO TÉCNICO", "sentiment": "POSITIVE",
	}
