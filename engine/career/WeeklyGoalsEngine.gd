extends RefCounted
class_name WeeklyGoalsEngine

## OBJETIVOS SEMANALES chicos (P5, 10-oct — "objetivos semanales con
## recompensas de Tienda"). 3 por semana, deterministas por semana + seed;
## progreso en season["weekly_goals"] (estado de temporada, no esquema).
## Se cobran en el Inicio: dinero, XP de carrera o un consumible.

const POOL := [
	{"id": "rating7", "desc": "Jugá un partido con nota 7 o más", "target": 1, "reward": {"kind": "item", "id": "energy_drink"}},
	{"id": "train3", "desc": "Entrená 3 sesiones", "target": 3, "reward": {"kind": "xp", "amount": 40}},
	{"id": "outing", "desc": "Salí una vez (cine, cena, fiesta…)", "target": 1, "reward": {"kind": "money", "amount": 4}},
	{"id": "contrib", "desc": "Hacé un gol o una asistencia", "target": 1, "reward": {"kind": "item", "id": "prematch_supp"}},
	{"id": "play2", "desc": "Jugá 2 partidos oficiales", "target": 2, "reward": {"kind": "xp", "amount": 60}},
	{"id": "win1", "desc": "Ganá un partido", "target": 1, "reward": {"kind": "money", "amount": 6}},
	{"id": "skill", "desc": "Desbloqueá una habilidad", "target": 1, "reward": {"kind": "item", "id": "bandage"}},
]

static func _week(day: int) -> int:
	return CalendarUtils.week_index(day)

## Los objetivos de esta semana (los crea si cambió la semana).
static func current(season: Dictionary, day: int, world_seed: int) -> Array:
	var wg: Dictionary = season.get("weekly_goals", {})
	if int(wg.get("week", -1)) != _week(day):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("weekly:%d" % _week(day)) ^ world_seed
		var pool: Array = POOL.duplicate(true)
		var picks: Array = []
		while picks.size() < 3 and not pool.is_empty():
			var g: Dictionary = pool.pop_at(rng.randi() % pool.size())
			g["progress"] = 0
			g["claimed"] = false
			picks.append(g)
		wg = {"week": _week(day), "goals": picks}
		season["weekly_goals"] = wg
	return wg["goals"]

## Suma progreso a un objetivo (si está activo esta semana).
static func bump(season: Dictionary, day: int, world_seed: int, goal_id: String, n: int = 1) -> void:
	for g in current(season, day, world_seed):
		if String(g["id"]) == goal_id:
			g["progress"] = mini(int(g["progress"]) + n, int(g["target"]))

static func is_done(g: Dictionary) -> bool:
	return int(g.get("progress", 0)) >= int(g.get("target", 1))

static func reward_text(r: Dictionary) -> String:
	match String(r.get("kind", "")):
		"money": return CurrencyFormat.format(int(r["amount"]))
		"xp": return "+%d XP" % int(r["amount"])
		"item":
			var it: Dictionary = ShopEngine.item_by_id(String(r["id"]))
			return String(it.get("name", r["id"]))
	return ""

## Cobra la recompensa. Devuelve true si se cobró.
static func claim(season: Dictionary, player: PlayerData, day: int, world_seed: int, goal_id: String) -> bool:
	for g in current(season, day, world_seed):
		if String(g["id"]) == goal_id and is_done(g) and not bool(g["claimed"]):
			var r: Dictionary = g["reward"]
			match String(r["kind"]):
				"money": player.balance += int(r["amount"])
				"xp": ProgressionEngine.add_xp(player, int(r["amount"]))
				"item": player.consumables[String(r["id"])] = int(player.consumables.get(String(r["id"]), 0)) + 1
			g["claimed"] = true
			return true
	return false
