extends RefCounted
class_name ObjectivesEngine

## Objetivos de temporada — backlog heredado de Football Legacy.
##
## El del CLUB se deriva EN VIVO de sus ambiciones (ClubData.league_ambition
## / cup_ambition) — nunca se persiste, es una función pura del club.
## El del JUGADOR se sortea una vez por temporada (creación de personaje /
## cada rollover) y se persiste en season["player_objective"] — mismo
## patrón que season["training_focus"].

static func club_league_objective(club: ClubData) -> String:
	if club.league_ambition >= 80:
		return "Pelear el título de liga"
	if club.league_ambition >= 60:
		return "Clasificar a competición continental"
	if club.league_ambition >= 40:
		return "Terminar en la mitad alta de la tabla"
	return "Asegurar la permanencia"

static func club_cup_objective(club: ClubData) -> String:
	if club.cup_ambition >= 80:
		return "Ganar la copa"
	if club.cup_ambition >= 55:
		return "Llegar a semifinales de copa"
	return "Competir con dignidad en la copa"

## Etiqueta de prestigio derivada de la reputación de LIGA (LeagueData.reputation,
## no de ClubData — el club no trae la suya propia). Solo texto de
## presentación para la ficha de club, no afecta balance.
static func reputation_tier_label(league_reputation: int) -> String:
	if league_reputation >= 85:
		return "GIGANTE"
	if league_reputation >= 70:
		return "GRANDE"
	if league_reputation >= 50:
		return "MEDIO"
	return "MODESTO"

## kind -> {text (con %d para el target), target, positions (vacío = todas)}
const PLAYER_OBJECTIVE_POOL := {
	"trust": {"text": "Termina la temporada con la confianza del entrenador por encima de %d", "target": 65, "positions": []},
	"appearances": {"text": "Consigue al menos %d titularidades esta temporada", "target": 10, "positions": []},
	"goals": {"text": "Marca al menos %d goles esta temporada", "target": 3, "positions": ["MF", "ST"]},
	"key_passes": {"text": "Consigue al menos %d pases clave esta temporada", "target": 5, "positions": ["DF", "MF"]},
}

## Sortea UN objetivo elegible para la posición del jugador, con el
## target ESCALADO a su nivel/edad/puesto — un titular consolidado tiene
## metas altas; un juvenil de banco, modestas (antes eran fijas: "marca
## 3 goles" igual para un crack que para un pibe). Pedido de Wilber.
static func generate_player_objective(player: PlayerData, rng: RandomNumberGenerator) -> Dictionary:
	var candidates: Array = []
	for kind in PLAYER_OBJECTIVE_POOL:
		var spec: Dictionary = PLAYER_OBJECTIVE_POOL[kind]
		var positions: Array = spec.get("positions", [])
		if positions.is_empty() or positions.has(player.position):
			candidates.append(kind)
	var kind: String = candidates[rng.randi() % candidates.size()]
	var target: int = _scaled_target(kind, player, rng)
	return {"kind": kind, "target": target, "text": (PLAYER_OBJECTIVE_POOL[kind]["text"] as String) % target}

## `role` 0 (pibe de banco) .. 1 (titular top). Juveniles con recorrido
## tienen metas algo más laxas (siguen en formación).
static func _scaled_target(kind: String, p: PlayerData, rng: RandomNumberGenerator) -> int:
	var role: float = clampf((float(p.overall) - 55.0) / 25.0, 0.0, 1.0)
	if p.age <= 20 and p.potential - p.overall >= 8:
		role *= 0.72
	var jitter: float = rng.randf_range(0.85, 1.15)
	match kind:
		"appearances":
			return clampi(int(round(lerpf(5.0, 26.0, role) * jitter)), 3, 32)
		"goals":
			var m: float = 1.0 if p.position == "ST" else 0.42
			return clampi(int(round(lerpf(2.0, 20.0, role) * m * jitter)), 1, 26)
		"key_passes":
			var m2: float = 0.6 if p.position == "DF" else 1.0
			return clampi(int(round(lerpf(3.0, 18.0, role) * m2 * jitter)), 2, 22)
		"trust":
			return clampi(int(round(lerpf(52.0, 74.0, clampf(float(p.coach_trust) / 100.0, 0.0, 1.0)) * jitter)), 45, 85)
		_:
			return int(PLAYER_OBJECTIVE_POOL[kind]["target"])

## Progreso actual del objetivo del jugador, según sus contadores de temporada.
static func player_objective_progress(player: PlayerData, objective: Dictionary) -> Dictionary:
	var current: int
	match objective.get("kind", ""):
		"trust":
			current = player.coach_trust
		"appearances":
			current = player.season_appearances
		"goals":
			current = player.season_goals
		"key_passes":
			current = player.season_key_passes
		_:
			current = 0
	var target: int = int(objective.get("target", 0))
	return {"current": current, "target": target, "met": current >= target}
