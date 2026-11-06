extends RefCounted
class_name DisciplineEngine

## Tarjetas, suspensiones y lesiones en los partidos de TODA la liga (no
## solo los del usuario) — pedido explícito de Wilber: "las amarillas,
## rojas, lesiones... deben pasar en los demás partidos también".
##
## Reglas:
##  - 5 amarillas acumuladas en la temporada de ESA competición = 1
##    partido de suspensión (el contador sigue sumando de ahí en más,
##    como en la vida real: la 10ª también suspende, etc.)
##  - Roja directa = 1 o 2 partidos de suspensión (al azar, determinista).
##  - Lesión = ausencia de X días — reusa PlayerDevelopment.roll_injury_days
##    en vez de inventar una segunda fórmula de lesiones (la regla de
##    "nunca duplicar una fórmula de balance" de CLAUDE.md).
##
## Un jugador suspendido/lesionado no juega su próximo partido: el resto
## del plantel lo reemplaza (MatchTeam.from_club arma el mejor XI posible
## con los disponibles) y el club pierde algo de fuerza PARA ESE PARTIDO,
## proporcional a cuánto por encima del promedio de su XI ideal estaba el
## jugador ausente — perder a la figura pesa, perder a un suplente casi
## no cambia nada.
##
## Mundo vivo: nada se persiste. Se recorre la temporada desde el día 0
## cada vez que se pide (igual que TopPerformersEngine ya hace con los
## goles) — determinista, misma semilla = misma historia de tarjetas
## siempre. El resultado de `simulate_league()` está pensado para
## enchufarse en el mismo hueco de "overrides" que ya consumen
## LeagueTable.compute / SeasonEngine.league_result / TopPerformersEngine
## .compute_league, así que ninguno de esos tres necesita saber que este
## motor existe.
##
## Alcance de esta primera versión: SOLO ligas domésticas (fixtures en
## orden cronológico ya conocido de antemano). Copas y copas continentales
## arman sus cruces ronda a ronda según quién gana la ronda anterior —
## integrarlas de la misma forma es un cambio más profundo en
## SeasonEngine.resolve_cup, no una extensión de este archivo.

const YELLOW_CHANCE := 0.16        # probabilidad de amarilla por titular y partido
const RED_CHANCE := 0.007          # probabilidad de roja directa por titular y partido
const INJURY_CHANCE := 0.018       # probabilidad de lesión por titular y partido
const YELLOWS_FOR_SUSPENSION := 5

## Tus amarillas de club se acumulan en la temporada (season["user_yellow_count"], se
## reinicia con cada temporada nueva): cada YELLOWS_FOR_SUSPENSION, 1 partido de sanción.
## Devuelve si este partido te deja sancionado. No toca nada si `yellows` es 0.
static func add_user_yellows(season: Dictionary, yellows: int) -> bool:
	if yellows <= 0:
		return false
	var before: int = int(season.get("user_yellow_count", 0))
	var now: int = before + yellows
	season["user_yellow_count"] = now
	if now / YELLOWS_FOR_SUSPENSION > before / YELLOWS_FOR_SUSPENSION:
		season["suspended_matches"] = maxi(int(season.get("suspended_matches", 0)), 1)
		return true
	return false
const IMPACT_FACTOR := 0.6         # cuánto pesa en fuerza cada punto de overall del ausente sobre el promedio de su XI ideal

static func _new_state() -> Dictionary:
	return {"yellows": {}, "suspended_matches": {}, "injured_until_day": {}}

static func _player_key(club_id: String, p: PlayerData) -> String:
	return "%s:%s" % [club_id, p.player_name]

static func _is_available(state: Dictionary, key: String, epoch_day: int) -> bool:
	if int(state["suspended_matches"].get(key, 0)) > 0:
		return false
	if int(state["injured_until_day"].get(key, -1)) > epoch_day:
		return false
	return true

## Array[PlayerData] SIEMPRE tipado: MatchTeam.from_club() exige un
## Array[PlayerData] real — pasarle un Array genérico (aunque tenga
## PlayerData adentro) revienta en un error de tipo silencioso en tiempo
## de ejecución (bug real encontrado: disciplina no generaba NINGÚN
## evento en toda la liga porque esto fallaba en cada partido).
static func _squad_for(club_id: String, world: Dictionary, world_seed: int, season_start_epoch_day: int, squad_cache: Dictionary) -> Array[PlayerData]:
	if squad_cache.has(club_id):
		return squad_cache[club_id]
	var squad: Array[PlayerData] = WorldFactory.make_squad_with_transfers(world, club_id, world_seed, season_start_epoch_day)
	squad_cache[club_id] = squad
	return squad

## XI ideal (sin bajas) de un club — vara de medir para cuánto pesa cada
## ausencia, no el plantel completo (un plantel con muchos suplentes
## flojos no debería "inflar" el promedio de referencia).
static func _ideal_xi(club: ClubData, squad: Array[PlayerData]) -> Array[PlayerData]:
	if squad.is_empty():
		return []
	return MatchTeam.from_club(club, squad, null, 0.0).starting_xi

## XI disponible para ESTE partido + penalización de fuerza por las bajas
## respecto del XI ideal.
static func _eligible_lineup(club: ClubData, squad: Array[PlayerData], ideal_xi: Array[PlayerData], state: Dictionary, club_id: String, epoch_day: int) -> Dictionary:
	if squad.is_empty():
		return {"xi": [], "penalty": 0.0}
	var available: Array[PlayerData] = []
	for p in squad:
		if _is_available(state, _player_key(club_id, p), epoch_day):
			available.append(p)
	if available.is_empty():
		available = squad.duplicate() # nunca deja a un club sin plantel jugable

	var actual_xi: Array[PlayerData] = MatchTeam.from_club(club, available, null, 0.0).starting_xi

	var avg_overall: float = 0.0
	if not ideal_xi.is_empty():
		for p in ideal_xi:
			avg_overall += p.overall
		avg_overall /= ideal_xi.size()

	var penalty: float = 0.0
	for p in ideal_xi:
		if not actual_xi.has(p):
			penalty += maxf(0.0, float(p.overall) - avg_overall) * IMPACT_FACTOR

	return {"xi": actual_xi, "penalty": penalty}

## Tarjetas y lesión DEL PARTIDO YA JUGADO — nunca afectan su propio
## resultado (ya se simuló), solo el próximo partido de cada jugador.
static func _roll_match_events(
	seed_key: String, xi: Array, club_id: String, state: Dictionary, epoch_day: int, world_seed: int,
	yellow_events: Array, red_events: Array, injury_events: Array,
) -> void:
	for i in range(xi.size()):
		var p: PlayerData = xi[i]
		var key: String = _player_key(club_id, p)

		var card_rng := RandomNumberGenerator.new()
		card_rng.seed = hash("%s:card:%d" % [seed_key, i]) ^ world_seed
		var roll: float = card_rng.randf()
		if roll < RED_CHANCE:
			var ban_rng := RandomNumberGenerator.new()
			ban_rng.seed = hash("%s:banlen:%d" % [seed_key, i]) ^ world_seed
			var ban_matches: int = ban_rng.randi_range(1, 2)
			state["suspended_matches"][key] = int(state["suspended_matches"].get(key, 0)) + ban_matches
			red_events.append({"name": p.player_name, "club_id": club_id, "epoch_day": epoch_day})
		elif roll < RED_CHANCE + YELLOW_CHANCE:
			var yellows: int = int(state["yellows"].get(key, 0)) + 1
			state["yellows"][key] = yellows
			yellow_events.append({"name": p.player_name, "club_id": club_id})
			if yellows % YELLOWS_FOR_SUSPENSION == 0:
				state["suspended_matches"][key] = int(state["suspended_matches"].get(key, 0)) + 1

		var injury_rng := RandomNumberGenerator.new()
		injury_rng.seed = hash("%s:injury:%d" % [seed_key, i]) ^ world_seed
		if injury_rng.randf() < INJURY_CHANCE:
			var days_rng := RandomNumberGenerator.new()
			days_rng.seed = hash("%s:injurydays:%d" % [seed_key, i]) ^ world_seed
			var days: int = PlayerDevelopment.roll_injury_days(days_rng)
			state["injured_until_day"][key] = epoch_day + days
			injury_events.append({"name": p.player_name, "club_id": club_id, "days": days, "epoch_day": epoch_day})

## Una suspensión se cumple con el partido DEL EQUIPO, jugara o no jugara
## el que la tenía — se descuenta a TODO el plantel con saldo pendiente
## cada vez que ese club disputa una fecha.
static func _tick_suspensions(state: Dictionary, club_id: String, squad: Array) -> void:
	for p in squad:
		var key: String = _player_key(club_id, p)
		var left: int = int(state["suspended_matches"].get(key, 0))
		if left > 0:
			state["suspended_matches"][key] = left - 1

## `fixtures`: de SeasonCalendar.build_league_fixtures (ya en orden
## cronológico). Devuelve {results, yellow_leaders, red_cards, injuries}.
## `results` (fixture_key -> [gh,ga]) tiene el MISMO formato que
## SeasonEngine.league_result_key espera como override — quien llame debe
## fusionarlo con season["results"] (los partidos reales del usuario
## siempre pisan por encima de esto).
static func simulate_league(
	fixtures: Array, world: Dictionary, clubs_by_id: Dictionary,
	strength_by_club: Dictionary, world_seed: int, current_epoch_day: int, season_start_epoch_day: int,
) -> Dictionary:
	var club_meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	var state := _new_state()
	var results: Dictionary = {}
	var squad_cache: Dictionary = {}
	var ideal_cache: Dictionary = {}
	var yellow_events: Array = []
	var red_events: Array = []
	var injury_events: Array = []

	for fx in fixtures:
		if int(fx["epoch_day"]) >= current_epoch_day:
			break
		var home_id: String = fx["home_club_id"]
		var away_id: String = fx["away_club_id"]
		if home_id == "" or away_id == "" or not club_meta_by_id.has(home_id) or not club_meta_by_id.has(away_id):
			continue
		var home_club: ClubData = clubs_by_id.get(home_id)
		var away_club: ClubData = clubs_by_id.get(away_id)
		if home_club == null or away_club == null:
			continue

		var epoch_day: int = int(fx["epoch_day"])
		var key: String = SeasonEngine.league_result_key(int(fx["matchday"]), home_id, away_id, epoch_day)

		var home_squad: Array[PlayerData] = _squad_for(home_id, world, world_seed, season_start_epoch_day, squad_cache)
		var away_squad: Array[PlayerData] = _squad_for(away_id, world, world_seed, season_start_epoch_day, squad_cache)
		if not ideal_cache.has(home_id):
			ideal_cache[home_id] = _ideal_xi(home_club, home_squad)
		if not ideal_cache.has(away_id):
			ideal_cache[away_id] = _ideal_xi(away_club, away_squad)

		var home_lineup := _eligible_lineup(home_club, home_squad, ideal_cache[home_id], state, home_id, epoch_day)
		var away_lineup := _eligible_lineup(away_club, away_squad, ideal_cache[away_id], state, away_id, epoch_day)

		var home_s: float = float(strength_by_club.get(home_id, 55)) - float(home_lineup["penalty"])
		var away_s: float = float(strength_by_club.get(away_id, 55)) - float(away_lineup["penalty"])
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key) ^ world_seed
		results[key] = MatchSimulator.simulate(home_s, away_s, rng)

		_tick_suspensions(state, home_id, home_squad)
		_tick_suspensions(state, away_id, away_squad)
		_roll_match_events("%s:home" % key, home_lineup["xi"], home_id, state, epoch_day, world_seed, yellow_events, red_events, injury_events)
		_roll_match_events("%s:away" % key, away_lineup["xi"], away_id, state, epoch_day, world_seed, yellow_events, red_events, injury_events)

	return {
		"results": results,
		"yellow_leaders": _yellow_leaderboard(state, clubs_by_id),
		"red_cards": red_events,
		"injuries": injury_events,
	}

static func _yellow_leaderboard(state: Dictionary, clubs_by_id: Dictionary) -> Array:
	var rows: Array = []
	for key in (state["yellows"] as Dictionary).keys():
		var parts: PackedStringArray = String(key).split(":", true, 1)
		if parts.size() < 2:
			continue
		var club_id: String = parts[0]
		var club: ClubData = clubs_by_id.get(club_id)
		rows.append({
			"name": parts[1],
			"club_name": club.club_name if club != null else "?",
			"count": int(state["yellows"][key]),
		})
	rows.sort_custom(func(a, b):
		if a["count"] != b["count"]:
			return a["count"] > b["count"]
		return String(a["name"]) < String(b["name"])
	)
	return rows
