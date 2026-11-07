extends RefCounted
## Lanzadores designados por el DT y capitán (8-nov). Módulo de reglas del partido 3D:
## toda la matemática de quién cobra penaltis, faltas y córners, y quién lleva el
## brazalete, vive aquí (nada de fórmulas sueltas en match.gd).
##
## El mérito sale de las estadísticas del jugador y de sus insignias de especialista
## (rasgos de Traits.gd: "dead_ball", "penalty_king", "free_kick_master"). Tu jugador
## compite con el resto del once; la confianza del DT (coach_trust) le da un pequeño
## margen a favor o en contra. Se calcula en cada partido: no se guarda nada.
##   const SetPieceTakers = preload("res://engine/match/m3d/SetPieceTakers.gd")

const KINDS := ["penalty", "free_kick", "corner"]
const LABELS := {"penalty": "Penaltis", "free_kick": "Faltas", "corner": "Córners", "captain": "Capitán"}

## Insignias que suman mérito en cada tipo de balón parado (puntos sobre 100).
const BADGE_BONUS := {
	"penalty": {"penalty_king": 12.0, "dead_ball": 7.0},
	"free_kick": {"dead_ball": 12.0, "free_kick_master": 10.0},
	"corner": {"dead_ball": 8.0, "free_kick_master": 8.0},
}

## Cuánto pesa la confianza del DT en TU candidatura: 80 de confianza = +3 puntos,
## 20 = -3. Con mérito parecido, el DT elige a quien más confía.
const TRUST_WEIGHT := 0.1


## Mérito 0..~110 para cobrar `kind`. `stats` en escala 0-100 (PlayerData).
static func merit(kind: String, stats: Dictionary, badges: Array) -> float:
	var sh: float = float(stats.get("shooting", 50))
	var co: float = float(stats.get("composure", 50))
	var ct: float = float(stats.get("control", 50))
	var pa: float = float(stats.get("passing", 50))
	var dm: float = float(stats.get("decision_making", 50))
	var m := 0.0
	match kind:
		"penalty":
			m = sh * 0.5 + co * 0.4 + ct * 0.1
		"free_kick":
			m = sh * 0.45 + pa * 0.25 + co * 0.15 + ct * 0.15
		"corner":
			m = pa * 0.6 + ct * 0.2 + dm * 0.2
	var bonus: Dictionary = BADGE_BONUS.get(kind, {})
	for b in badges:
		m += float(bonus.get(String(b), 0.0))
	return m


## Mérito para el brazalete: liderazgo, veteranía en el club, edad y nivel.
static func captain_merit(leadership: int, age: int, seniority: int, overall: int) -> float:
	return leadership * 0.5 + minf(seniority, 8) * 3.0 + clampf(age - 20, 0, 12) * 1.2 + overall * 0.25


## Elige lanzadores y capitán de un once. Cada entrada:
##   {"name", "stats", "badges", "leadership", "age", "seniority", "overall", "gk", "user", "trust"}
## Devuelve {"penalty": nombre, "free_kick": nombre, "corner": nombre, "captain": nombre}.
static func designate(entries: Array) -> Dictionary:
	var out := {}
	for kind: String in KINDS:
		var best := ""
		var best_m := -INF
		for e: Dictionary in entries:
			if bool(e.get("gk", false)):
				continue
			var m := merit(kind, e.get("stats", {}), e.get("badges", []))
			if bool(e.get("user", false)):
				m += (float(e.get("trust", 50)) - 50.0) * TRUST_WEIGHT
			if m > best_m:
				best_m = m
				best = String(e.get("name", ""))
		out[kind] = best
	var cap := ""
	var cap_m := -INF
	for e: Dictionary in entries:
		var cm := captain_merit(int(e.get("leadership", 30)), int(e.get("age", 24)),
				int(e.get("seniority", 0)), int(e.get("overall", 50)))
		if bool(e.get("user", false)):
			cm += (float(e.get("trust", 50)) - 50.0) * TRUST_WEIGHT
		if cm > cap_m:
			cap_m = cm
			cap = String(e.get("name", ""))
	out["captain"] = cap
	return out


## Entrada de designate() para un PlayerData.
static func entry(pl: PlayerData, is_user: bool) -> Dictionary:
	var badges: Array = []
	for t in pl.traits:
		badges.append(String(t))
	for t in pl.equipped_traits:
		if not badges.has(String(t)):
			badges.append(String(t))
	return {"name": pl.player_name, "badges": badges, "leadership": pl.leadership, "age": pl.age,
		"seniority": pl.club_seniority, "overall": pl.overall, "gk": pl.position == "GK",
		"user": is_user, "trust": pl.coach_trust,
		"stats": {"shooting": pl.shooting, "composure": pl.composure, "control": pl.control,
			"passing": pl.passing, "decision_making": pl.decision_making}}


## Designación para un once de PlayerData (`user` = tu jugador, o null).
static func for_xi(xi: Array, user: PlayerData) -> Dictionary:
	var entries: Array = []
	for x in xi:
		var pl: PlayerData = x
		if pl != null:
			entries.append(entry(pl, pl == user))
	return designate(entries)
