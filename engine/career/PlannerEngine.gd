extends RefCounted
class_name PlannerEngine

## Planificador semanal — UNA actividad por semana ISO en los días sin
## partido. Efecto chico y variado; estado no-schema en
## season["planner"] = {"week": int, "id": String} (mismo patrón que
## season["wellness"] de LifestyleEngine). Avanza 1 día al confirmar
## (vía WorldTickEngine.advance_day, como el entreno de Training.gd).

const ACTIVITIES := [
	{
		"id": "train", "name": "Entrenamiento extra",
		"desc": "Sesión individual con un preparador. Chance de mejorar un atributo.",
		"icon": "res://addons/at-icons/node/dumbbell.svg", "color": "GREEN",
	},
	{
		"id": "media", "name": "Día de medios",
		"desc": "Entrevistas, foto y contenido para redes. Sube tu reputación.",
		"icon": "res://addons/at-icons/node/brain.svg", "color": "PURPLE",
	},
	{
		"id": "rest", "name": "Descanso total",
		"desc": "Desconectás. Recuperás energía física y mental de golpe.",
		"icon": "res://addons/at-icons/node/circle.svg", "color": "BLUE",
	},
	{
		"id": "family", "name": "Tiempo en familia",
		"desc": "Un respiro con los tuyos. Baja fuerte la tensión mental.",
		"icon": "res://addons/at-icons/node/star.svg", "color": "GOLD",
	},
	{
		"id": "community", "name": "Acción comunitaria",
		"desc": "Visita a un hospital o a la escuelita del club. El cariño de la gente pesa.",
		"icon": "res://addons/at-icons/node/list_unordered.svg", "color": "RED",
	},
]

## --- Planificador POR DÍA (nuevo, pedido de Wilber): asignás una
## actividad a CADA día hasta el próximo partido y confirmás una vez. La
## escena avanza los días aplicando `apply_day` en cada uno. Efectos
## chicos — es constancia, no un atajo. ---
const DAY_ACTIVITIES := [
	{"id": "train",     "name": "Entrenar",   "short": "ENT", "color": "GREEN"},
	{"id": "gym",       "name": "Gimnasio",   "short": "GYM", "color": "GREEN"},
	{"id": "rest",      "name": "Descanso",   "short": "DES", "color": "BLUE"},
	{"id": "media",     "name": "Medios",     "short": "MED", "color": "PURPLE"},
	{"id": "family",    "name": "Familia",    "short": "FAM", "color": "GOLD"},
	{"id": "community", "name": "Comunidad",  "short": "COM", "color": "RED"},
]

static func day_activity(id: String) -> Dictionary:
	for a in DAY_ACTIVITIES:
		if a["id"] == id:
			return a
	return DAY_ACTIVITIES[0]

## Plan por defecto para `n` días: alterna entrenar/gimnasio y deja
## DESCANSO el día antes del partido.
static func default_plan(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		if i == n - 1 and n >= 2:
			out.append("rest")
		else:
			out.append("train" if i % 2 == 0 else "gym")
	return out

## Aplica UN día del plan sobre `player`/`season`. Efecto CHICO. Devuelve
## un texto corto. NO avanza el día (eso lo hace la escena).
static func apply_day(player: PlayerData, season: Dictionary, id: String, rng: RandomNumberGenerator) -> String:
	var ff: float = Traits.fatigue_factor(player)
	match id:
		"train":
			var s: Dictionary = PlayerDevelopment.training_session(player, "auto", rng)
			ProgressionEngine.add_xp(player, ProgressionEngine.training_xp("normal"))
			player.fatigue_physical = clampf(player.fatigue_physical + 6.0 * ff, 0.0, 100.0)
			if int(s.get("overall_delta", 0)) > 0:
				return "Entreno: ¡subiste de nivel!"
			return "Entreno cumplido."
		"gym":
			player.fatigue_physical = clampf(player.fatigue_physical + 8.0 * ff, 0.0, 100.0)
			if rng.randf() < 0.32:
				var attr: String = ["speed", "stamina", "strength"][rng.randi() % 3]
				player.set(attr, clampi(int(player.get(attr)) + 1, 20, 99))
				PlayerDevelopment.bank_overall_progress(player, 1)
				return "Gimnasio: +1 %s." % attr
			return "Gimnasio: trabajo físico."
		"rest":
			player.fatigue_physical = maxf(0.0, player.fatigue_physical - 14.0)
			player.fatigue_mental = maxf(0.0, player.fatigue_mental - 10.0)
			return "Descanso: recuperás energía."
		"media":
			var r: int = rng.randi_range(1, 2)
			player.reputation = clampi(player.reputation + r, 0, 100)
			player.fatigue_mental = clampf(player.fatigue_mental + 4.0, 0.0, 100.0)
			if season is Dictionary:
				season["fan_sentiment"] = clampi(int(season.get("fan_sentiment", 55)) + 2, 0, 100)
			return "Medios: +%d reputación." % r
		"family":
			player.fatigue_mental = maxf(0.0, player.fatigue_mental - 12.0)
			return "Familia: bajás la tensión."
		"community":
			player.reputation = clampi(player.reputation + 1, 0, 100)
			player.fatigue_physical = clampf(player.fatigue_physical + 2.0 * ff, 0.0, 100.0)
			if season is Dictionary:
				season["fan_sentiment"] = clampi(int(season.get("fan_sentiment", 55)) + 2, 0, 100)
				season["dressing_room"] = clampi(int(season.get("dressing_room", 60)) + 1, 0, 100)
			return "Comunidad: la gente lo valora."
	return ""

static func week_of(day: int) -> int:
	return CalendarUtils.week_index(day)

static func done_this_week(season: Dictionary, day: int) -> bool:
	var pl: Dictionary = season.get("planner", {})
	return int(pl.get("week", -1)) == week_of(day)

static func chosen_id(season: Dictionary, day: int) -> String:
	var pl: Dictionary = season.get("planner", {})
	if int(pl.get("week", -1)) == week_of(day):
		return String(pl.get("id", ""))
	return ""

static func activity(id: String) -> Dictionary:
	for a in ACTIVITIES:
		if a["id"] == id:
			return a
	return {}

## Aplica la actividad. Devuelve {"ok": bool, "message": String}. NO avanza
## el día (eso lo hace la escena, como Training).
static func apply(player: PlayerData, season: Dictionary, day: int, id: String, rng: RandomNumberGenerator) -> Dictionary:
	if done_this_week(season, day):
		return {"ok": false, "message": "Ya planificaste esta semana."}
	if activity(id).is_empty():
		return {"ok": false, "message": "Actividad desconocida."}

	var msg := ""
	var ff: float = Traits.fatigue_factor(player)
	match id:
		"train":
			var summary: Dictionary = PlayerDevelopment.training_session(player, "auto", rng)
			ProgressionEngine.add_xp(player, ProgressionEngine.training_xp("normal"))
			player.fatigue_physical = clampf(player.fatigue_physical + 8.0 * ff, 0.0, 100.0)
			if int(summary.get("overall_delta", 0)) > 0:
				msg = "Gran sesión: subiste de nivel."
			elif not (summary.get("attribute_deltas", {}) as Dictionary).is_empty():
				msg = "Buena sesión: afinaste algún detalle."
			else:
				msg = "Sesión cumplida. El progreso llega con constancia."
		"media":
			var r: int = rng.randi_range(2, 5)
			player.reputation = clampi(player.reputation + r, 0, 100)
			player.fatigue_physical = clampf(player.fatigue_physical + 5.0 * ff, 0.0, 100.0)
			msg = "Día de prensa hecho. +%d de reputación." % r
		"rest":
			player.fatigue_physical = maxf(0.0, player.fatigue_physical - 16.0)
			player.fatigue_mental = maxf(0.0, player.fatigue_mental - 12.0)
			msg = "Descansaste de verdad. Volvés enchufado."
		"family":
			player.fatigue_mental = maxf(0.0, player.fatigue_mental - 16.0)
			player.fatigue_physical = maxf(0.0, player.fatigue_physical - 4.0)
			msg = "Tiempo con los tuyos. La cabeza vuelve a su lugar."
		"community":
			var rc: int = rng.randi_range(1, 3)
			player.reputation = clampi(player.reputation + rc, 0, 100)
			player.fatigue_physical = clampf(player.fatigue_physical + 2.0 * ff, 0.0, 100.0)
			msg = "La gente lo valora. +%d de reputación." % rc

	season["planner"] = {"week": week_of(day), "id": id}
	return {"ok": true, "message": msg}
