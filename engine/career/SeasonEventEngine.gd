extends RefCounted
class_name SeasonEventEngine

## Eventos inesperados de temporada — pedido explícito: "que ocurran entre
## 0 a 3 veces por temporada" que beneficien o perjudiquen al jugador,
## "también eventos de decisiones" (no solo avisos). Cuatro categorías
## pedidas: económicos, de rendimiento, sociales/mediáticos y de relación
## con el club.
##
## Mismo patrón que SponsorEngine/WageOfferEngine: estado persistente
## (PlayerData.pending_season_event, ver SaveManager schema v14), nunca un
## popup efímero. Los efectos SOLO tocan campos que YA existen y tienen
## semántica establecida en el resto del juego (balance, coach_trust,
## reputation — ver LifestyleEngine/InterviewEngine) — nunca una métrica
## nueva inventada para esto.
##
## Cada entrada del pool trae `options` (Array) — un evento de "aviso"
## simplemente tiene UNA sola opción ("Entendido"); uno "de decisión"
## trae 2+. La pantalla (SeasonEvent.gd) no distingue entre los dos casos
## más que en cuántos botones dibuja: la resolución es siempre "aplica los
## efectos YA sorteados de la opción elegida".

const WEEKLY_CHANCE := 0.03 # ~1.5 eventos esperados en una temporada de 52 semanas
const MAX_PER_SEASON := 3

## `events_used_this_season`: season.get("random_events_used", 0) — se
## resetea solo cada temporada porque `season` entero se reemplaza en el
## rollover (ver WorldTickEngine._finish_season_rollover), no hace falta
## un reset explícito acá.
static func should_offer(events_used_this_season: int, rng: RandomNumberGenerator) -> bool:
	if events_used_this_season >= MAX_PER_SEASON:
		return false
	return rng.randf() < WEEKLY_CHANCE

const _POOL := [
	# --- Económicos ---
	{"id": "sponsor_bonus", "category": "economic",
		"title": "Bono sorpresa",
		"body": "Un patrocinador menor te manda un bono por tu buena imagen.",
		"options": [{"label": "Entendido", "effects": {"balance": [40, 80]}}]},
	{"id": "fine", "category": "economic",
		"title": "Multa administrativa",
		"body": "La liga te sanciona con una multa menor por un trámite fuera de plazo.",
		"options": [{"label": "Entendido", "effects": {"balance": [-50, -20]}}]},
	{"id": "streaming_gig", "category": "economic",
		"title": "Propuesta de streaming",
		"body": "Un canal te ofrece pagarte por aparecer en un evento la semana de un partido importante.",
		"options": [
			{"label": "Aceptar", "effects": {"balance": [60, 100], "coach_trust": [-10, -5]}},
			{"label": "Rechazar", "effects": {}},
		]},
	# --- Rendimiento ---
	{"id": "form_high", "category": "performance",
		"title": "Racha de buena forma",
		"body": "Vienes entrenando a un nivel altísimo y el cuerpo técnico lo nota.",
		"options": [{"label": "Entendido", "effects": {"coach_trust": [5, 10]}}]},
	{"id": "minor_knock", "category": "performance",
		"title": "Molestia física",
		"body": "Una molestia sin importancia te bajó el ritmo unos días, sin llegar a lesión.",
		"options": [{"label": "Entendido", "effects": {"coach_trust": [-7, -3]}}]},
	{"id": "extra_recovery", "category": "performance",
		"title": "Sesión extra de recuperación",
		"body": "El cuerpo técnico te ofrece una sesión de recuperación extra, de tu bolsillo.",
		"options": [
			{"label": "Pagarla", "effects": {"balance": [-50, -30], "coach_trust": [3, 8]}},
			{"label": "Rechazar", "effects": {}},
		]},
	# --- Sociales / mediáticos ---
	{"id": "good_press", "category": "media",
		"title": "Nota elogiosa",
		"body": "Un medio importante publica una nota destacando tu presente.",
		"options": [{"label": "Entendido", "effects": {"reputation": [5, 10]}}]},
	{"id": "scandal", "category": "media",
		"title": "Rumor incómodo",
		"body": "Circula un rumor incómodo sobre ti en redes sociales.",
		"options": [{"label": "Entendido", "effects": {"reputation": [-12, -5]}}]},
	{"id": "risky_interview", "category": "media",
		"title": "Entrevista polémica",
		"body": "Un periodista te invita a una entrevista sobre un tema delicado.",
		"options": [
			{"label": "Dar la entrevista", "effects": {"reputation": [-15, 15]}},
			{"label": "Declinar", "effects": {}},
		]},
	# --- Relación con el club ---
	{"id": "public_praise", "category": "club",
		"title": "Elogio público",
		"body": "Tu entrenador te elogia frente a todo el plantel en la conferencia de prensa.",
		"options": [{"label": "Entendido", "effects": {"coach_trust": [6, 12]}}]},
	{"id": "locker_room_friction", "category": "club",
		"title": "Fricción en el vestuario",
		"body": "Un roce con un compañero por la titularidad tensa el ambiente.",
		"options": [{"label": "Entendido", "effects": {"coach_trust": [-9, -4]}}]},
	{"id": "teammate_favor", "category": "club",
		"title": "Favor de un compañero",
		"body": "Un compañero te pide que hables bien de él con el entrenador.",
		"options": [
			{"label": "Ayudarlo", "effects": {"coach_trust": [-6, -3]}},
			{"label": "Negarte", "effects": {}},
		]},
]

## Elige un evento al azar y sortea YA los montos de cada opción (queda
## fijo desde que se genera — la UI solo muestra lo ya sorteado, nunca
## vuelve a tirar dados al re-renderizar).
static func generate_event(rng: RandomNumberGenerator) -> Dictionary:
	var template: Dictionary = _POOL[rng.randi() % _POOL.size()].duplicate(true)
	var options: Array = template["options"]
	for opt in options:
		opt["resolved_effects"] = _roll_effects(opt.get("effects", {}), rng)
	return template

static func _roll_effects(effects: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var resolved: Dictionary = {}
	for key in effects:
		var range_arr: Array = effects[key]
		if range_arr.size() < 2:
			continue
		resolved[key] = rng.randi_range(int(range_arr[0]), int(range_arr[1]))
	return resolved

## Aplica los efectos YA resueltos de la opción elegida — mismos clamps
## que ya usa el resto del juego para cada campo (coach_trust/reputation
## 0-100 vía LifestyleEngine/InterviewEngine; balance nunca negativo).
static func apply_effects(player: PlayerData, resolved_effects: Dictionary) -> void:
	for key in resolved_effects:
		var delta: int = int(resolved_effects[key])
		match key:
			"balance":
				player.balance = maxi(player.balance + delta, 0)
			"coach_trust":
				player.coach_trust = clampi(player.coach_trust + delta, 0, 100)
			"reputation":
				player.reputation = clampi(player.reputation + delta, 0, 100)
