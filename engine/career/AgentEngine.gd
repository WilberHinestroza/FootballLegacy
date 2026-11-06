extends RefCounted
class_name AgentEngine

## Representante del jugador — generado UNA vez en la creación de
## personaje (cambiar de agente es una pieza futura, no esta). Su calidad
## (1-5 estrellas) da un pequeño empujón al sueldo negociado; esa
## matemática vive aquí, igual que ContractEngine.
##
## PLACEHOLDER: nombres inventados, sin licencias reales.

const AGENT_NAMES := [
	"Andrés Henao", "Marta Solórzano", "Iván Duarte", "Carla Prieto",
	"Tomás Reyes", "Elena Vidal", "Ricardo Fon", "Nadia Kessler",
	"Bruno Salas", "Paula Nieto", "Diego Lares", "Sofía Marín",
]

## Usa el RNG global (como el resto de la creación de personaje: overall,
## potential...) — es una tirada única, no necesita ser reproducible.
static func generate_agent() -> Dictionary:
	var name: String = AGENT_NAMES[randi() % AGENT_NAMES.size()]
	var stars: int = clampi(3 + randi_range(-2, 2), 1, 5) # sesgado al centro: la mayoría, 2-4
	return {"name": name, "stars": stars}

## Multiplicador sobre un sueldo ya calculado (ContractEngine): 1 estrella
## -> 0.85, 3 (normal) -> 1.0, 5 -> 1.15. Un agente mejor negocia más.
static func wage_multiplier(stars: int) -> float:
	var s: int = clampi(stars, 1, 5)
	return 0.85 + float(s - 1) * 0.075

# --- Perfil ampliado para la pantalla "Mi agente" (cosmético, determinista) ---

const _TIERS := ["Agente novato", "Agente regional", "Agente consolidado", "Agente top", "Agente élite mundial"]
const _CLIENT_NAMES := [
	"Luca Kilian", "Mateo Farré", "Noah Brandt", "Iker Salcedo", "Dani Roth",
	"Aleix Pons", "Tomás Vega", "Elias Krause", "Bruno Achar", "Leo Sander",
]

## Perfil DERIVADO (no se persiste): tier, experiencia, nº de clientes,
## 4 atributos 0-100 y un "otro cliente". Determinista a partir del
## nombre del agente + world_seed — mismo criterio que el estilo del DT.
static func profile(agent_name: String, stars: int, world: Dictionary, world_seed: int) -> Dictionary:
	var s: int = clampi(stars, 1, 5)
	var base: int = absi(hash("agent:%s" % agent_name) ^ world_seed)

	var attrs := {
		"Deportivo": clampi(45 + s * 8 + (base % 17), 30, 99),
		"Económico": clampi(45 + s * 8 + ((base / 17) % 17), 30, 99),
		"Comercial": clampi(40 + s * 8 + ((base / 289) % 19), 25, 99),
		"Influencia": clampi(38 + s * 8 + ((base / 4913) % 21), 22, 99),
	}
	var years_exp: int = 4 + s * 3 + (base % 9)
	var n_clients: int = 1 + (base % 4)

	var other := {}
	var clubs_by_league: Dictionary = world.get("clubs_by_league", {})
	if not clubs_by_league.is_empty():
		var league_ids: Array = clubs_by_league.keys()
		var lg = league_ids[base % league_ids.size()]
		var clubs: Array = clubs_by_league[lg]
		if not clubs.is_empty():
			var club = clubs[(base / 7) % clubs.size()]
			other = {
				"name": _CLIENT_NAMES[(base / 11) % _CLIENT_NAMES.size()],
				"club_name": club.club_name,
				"overall": clampi(55 + s * 3 + ((base / 13) % 20), 48, 88),
			}

	return {
		"tier": _TIERS[s - 1],
		"years_exp": years_exp,
		"clients": n_clients,
		"attributes": attrs,
		"other_client": other,
	}

# --- "Pedir aumento de sueldo" (pedido de Wilber: botón con cooldown que
# convive con la mejora que "llega sola" de WageOfferEngine) ---

const RAISE_COOLDOWN_DAYS := 45
const RAISE_MIN_TRUST := 58
const RAISE_MIN_APPEARANCES := 4

## Intenta que el agente negocie una mejora YA. Devuelve
## {ok: bool, reason: String}. Si ok, deja player.pending_wage_offer
## puesto (la pantalla WageOffer lo resuelve, igual que la automática) y
## marca el cooldown en season["agent_raise_cd_day"].
static func request_raise(player: PlayerData, season: Dictionary, today: int, league_position_ratio: float) -> Dictionary:
	if not player.pending_wage_offer.is_empty():
		return {"ok": false, "reason": "Ya tenés una mejora de sueldo esperando tu respuesta."}
	if player.contract_years_remaining <= 0:
		return {"ok": false, "reason": "Sin contrato vigente: la renovación se negocia al vencer."}
	var cd_day: int = int(season.get("agent_raise_cd_day", -9999))
	if today < cd_day:
		return {"ok": false, "reason": "Tu agente ya lo intentó hace poco. Volvé en %d días." % (cd_day - today)}
	if player.coach_trust < RAISE_MIN_TRUST or player.season_appearances < RAISE_MIN_APPEARANCES:
		return {"ok": false, "reason": "Necesitás más rendimiento o más tiempo en el club."}

	var offer: Dictionary = WageOfferEngine.generate_offer(player, league_position_ratio)
	season["agent_raise_cd_day"] = today + RAISE_COOLDOWN_DAYS
	if offer.is_empty():
		return {"ok": false, "reason": "El club dice que tu sueldo ya está acorde a tu nivel. Probá más adelante."}
	player.pending_wage_offer = offer
	return {"ok": true, "reason": ""}

## Para pintar el botón "Pedir aumento" gris con el motivo sin ejecutarlo.
static func raise_blocker(player: PlayerData, season: Dictionary, today: int) -> String:
	if not player.pending_wage_offer.is_empty():
		return "Ya tenés una mejora esperando respuesta."
	if player.contract_years_remaining <= 0:
		return "Se negocia al vencer el contrato."
	var cd_day: int = int(season.get("agent_raise_cd_day", -9999))
	if today < cd_day:
		return "Tu agente lo intentó hace poco (faltan %d días)." % (cd_day - today)
	if player.coach_trust < RAISE_MIN_TRUST or player.season_appearances < RAISE_MIN_APPEARANCES:
		return "Necesitás más rendimiento o más tiempo en el club."
	return ""

# --- "Pedir ser titular" (pedido de Wilber: "agrega un botón en agente
# para pedir ser titular o algo así") — el agente presiona al DT de cara
# al PRÓXIMO partido. NO garantiza nada (seguiría rompiendo la regla dura
# de MatchTeam "nunca elegir solo por favor" si lo hiciera): sube, por un
# solo partido, la probabilidad de CoachRelations.start_chance vía
# player.active_effects["agent_lobby_matches"] — mismo patrón de "efecto
# de un solo uso" que ya usa ShopEngine (match_boost_matches/
# injury_shield_matches), consumido en MatchLauncher.prepare() (ahí es
# donde de verdad se decide titular/banco, antes de PreMatch). ---

const LOBBY_COOLDOWN_DAYS := 20
const LOBBY_MIN_TRUST := 35
const LOBBY_BOOST := 0.35   # se suma a la chance base de CoachRelations.start_chance
const LOBBY_CAP := 0.85     # tope: sigue sin ser un titular "asegurado"

## Arma el favor para el próximo partido. Devuelve {ok: bool, reason: String}.
static func request_starting(player: PlayerData, season: Dictionary, today: int) -> Dictionary:
	if int(player.active_effects.get("agent_lobby_matches", 0)) > 0:
		return {"ok": false, "reason": "Tu agente ya habló con el DT para tu próximo partido."}
	var cd_day: int = int(season.get("agent_lobby_cd_day", -9999))
	if today < cd_day:
		return {"ok": false, "reason": "Tu agente ya lo intentó hace poco. Volvé en %d días." % (cd_day - today)}
	if player.coach_trust < LOBBY_MIN_TRUST:
		return {"ok": false, "reason": "El DT todavía no confía lo suficiente en vos para escuchar a tu agente."}
	player.active_effects["agent_lobby_matches"] = 1
	season["agent_lobby_cd_day"] = today + LOBBY_COOLDOWN_DAYS
	return {"ok": true, "reason": ""}

## Para pintar el botón "Pedir ser titular" gris con el motivo sin ejecutarlo.
static func lobby_blocker(player: PlayerData, season: Dictionary, today: int) -> String:
	if int(player.active_effects.get("agent_lobby_matches", 0)) > 0:
		return "Tu agente ya habló con el DT para tu próximo partido."
	var cd_day: int = int(season.get("agent_lobby_cd_day", -9999))
	if today < cd_day:
		return "Tu agente lo intentó hace poco (faltan %d días)." % (cd_day - today)
	if player.coach_trust < LOBBY_MIN_TRUST:
		return "El DT todavía no confía lo suficiente en vos."
	return ""

## Aplica (y consume) el favor del agente sobre la chance base de
## CoachRelations.start_chance para el próximo partido. Vive acá (no en
## MatchLauncher) por la regla de balance centralizado — una sola fórmula.
static func apply_lobby_boost(player: PlayerData, base_chance: float) -> float:
	if player == null or int(player.active_effects.get("agent_lobby_matches", 0)) <= 0:
		return base_chance
	player.active_effects.erase("agent_lobby_matches")
	return clampf(base_chance + LOBBY_BOOST, 0.0, LOBBY_CAP)
