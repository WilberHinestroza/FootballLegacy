extends RefCounted
class_name TopPerformersEngine

## Tabla de goleadores y asistentes de una liga (o copa continental) —
## mundo vivo, igual filosofía que SeasonEngine/LeagueTable: el marcador
## de un partido de IA ya es una función pura de (world_seed, fixture);
## esto añade UNA CAPA MÁS de la misma idea, repartiendo esos goles entre
## el once titular del club de forma determinista (misma semilla = mismo
## reparto siempre), sin persistir nada ni simular partido a partido.
##
## El once titular se pide vía MatchTeam.from_club() — la MISMA lógica
## que arma el equipo real de partido (GK real + 10 de campo) — nunca
## una selección de scorers propia y distinta.

const SCORER_WEIGHT := {"GK": 0, "DF": 1, "MF": 2, "ST": 5}
const ASSIST_WEIGHT := {"GK": 0, "DF": 1, "MF": 5, "ST": 2}
## Top 10, no 15 (pedido de Wilber: "que el query muestre solo los
## primeros 10 para aligerar la consulta y hacerla más rápida").
const MAX_ROWS := 10

## fixtures: fixtures de la liga. world/clubs_by_id: para armar el once
## de cada club (YA con los fichajes de la temporada, ver
## WorldFactory.make_squad_with_transfers) y mostrar su nombre.
## overrides/strength_by_club: mismos parámetros que SeasonEngine.league_result.
static func compute_league(
	fixtures: Array, world: Dictionary, clubs_by_id: Dictionary,
	current_epoch_day: int, world_seed: int, season_start_epoch_day: int, overrides: Dictionary, strength_by_club: Dictionary,
) -> Dictionary:
	var club_meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	var goals: Dictionary = {}
	var assists: Dictionary = {}
	var xi_cache: Dictionary = {}

	for fx in fixtures:
		if int(fx["epoch_day"]) >= current_epoch_day:
			continue
		var home_id: String = fx["home_club_id"]
		var away_id: String = fx["away_club_id"]
		if not club_meta_by_id.has(home_id) or not club_meta_by_id.has(away_id):
			continue
		var score: Array = SeasonEngine.league_result(fx, world_seed, overrides, strength_by_club)
		var fixture_key: String = SeasonEngine.league_result_key(int(fx["matchday"]), home_id, away_id, int(fx["epoch_day"]))
		_attribute_goals(int(score[0]), home_id, "%s:home" % fixture_key, world, clubs_by_id, world_seed, season_start_epoch_day, xi_cache, goals, assists)
		_attribute_goals(int(score[1]), away_id, "%s:away" % fixture_key, world, clubs_by_id, world_seed, season_start_epoch_day, xi_cache, goals, assists)

	return {"scorers": _sorted_rows(goals), "assists": _sorted_rows(assists)}

## Igual que compute_league pero para un cuadro de copa ya resuelto
## (SeasonEngine.resolve_cup) — solo cuenta las rondas ya decididas.
## No hay inject_user aquí a propósito: PlayerData.season_goals es un
## total de TODAS las competiciones (liga + copa, ver MatchSummary.gd),
## así que no hay forma de aislar "solo goles de copa" sin un contador
## nuevo — mejor dejar la atribución sintética también para el usuario
## en esta pestaña que mostrar un número que en realidad es el total.
static func compute_cup(resolved_cup: Dictionary, world: Dictionary, clubs_by_id: Dictionary, world_seed: int, season_start_epoch_day: int) -> Dictionary:
	var club_meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	var goals: Dictionary = {}
	var assists: Dictionary = {}
	var xi_cache: Dictionary = {}

	for rnd in resolved_cup.get("rounds", []):
		for m in rnd.get("matches", []):
			var result: Variant = m.get("result", null)
			if result == null:
				continue
			var home_id: String = m.get("home_club_id", "")
			var away_id: String = m.get("away_club_id", "")
			if not club_meta_by_id.has(home_id) or not club_meta_by_id.has(away_id):
				continue
			var fixture_key: String = SeasonEngine.cup_result_key(int(rnd["round"]), home_id, away_id)
			_attribute_goals(int(result[0]), home_id, "%s:home" % fixture_key, world, clubs_by_id, world_seed, season_start_epoch_day, xi_cache, goals, assists)
			_attribute_goals(int(result[1]), away_id, "%s:away" % fixture_key, world, clubs_by_id, world_seed, season_start_epoch_day, xi_cache, goals, assists)

	return {"scorers": _sorted_rows(goals), "assists": _sorted_rows(assists)}

## Igual que compute_cup pero para un torneo de SELECCIONES ya resuelto
## (Mundial o copa continental — mismo dict shape rounds/groups con
## home_club_id/away_club_id/club_id usados como ids de PAÍS, ver
## WorldCupEngine/NationalCupEngine). No hay ClubData para un país, así
## que el plantel de cada uno sale de
## NationalTeamFactory.squads_for_countries() (un solo recorrido de todos
## los clubes del mundo para TODOS los países del torneo, nunca uno por
## país) y el once titular de MatchTeam.from_national_team() — la MISMA
## lógica de armado que usa el partido real, pero con user_player=null
## (igual que _starting_xi_for con los clubes: esto es una lectura
## agregada de TODOS los países, no el partido del usuario, así que no se
## fuerza su promoción a titular en ningún equipo). Sin inject_user por la
## misma razón que compute_cup: player.international_goals/assists son un
## TOTAL de carrera de selección, no algo aislable a "solo este torneo".
## `resolved` también acepta el shape de QualifyingEngine.resolve()
## (Parte 91w, pedido de Wilber: "agrega el botón de ver... goleador y
## asistencias... de cada eliminatoria"): formato "grupos" ya cubierto
## arriba (mismo shape que Mundial/copas); formato "tabla única"
## (CONMEBOL/CONCACAF) trae sus partidos en un `fixtures` plano con
## home/away/result directos (ver QualifyingEngine._resolve_table) — el
## bucle de abajo lo suma sin tocar los otros dos, que siguen sin usarlo.
static func compute_national_tournament(resolved: Dictionary, world: Dictionary, world_seed: int, season_start_epoch_day: int) -> Dictionary:
	var countries: Dictionary = {}
	for rnd in resolved.get("rounds", []) as Array:
		for m in rnd.get("matches", []) as Array:
			countries[String(m.get("home_club_id", ""))] = true
			countries[String(m.get("away_club_id", ""))] = true
	for g in resolved.get("groups", []) as Array:
		for row in g.get("standings", []) as Array:
			countries[String(row.get("club_id", ""))] = true
	for fx in resolved.get("fixtures", []) as Array:
		countries[String(fx.get("home", ""))] = true
		countries[String(fx.get("away", ""))] = true
	countries.erase("")

	var squads: Dictionary = NationalTeamFactory.squads_for_countries(world, world_seed, season_start_epoch_day, countries.keys())
	var xi_cache: Dictionary = {}
	var goals: Dictionary = {}
	var assists: Dictionary = {}

	for rnd in resolved.get("rounds", []) as Array:
		for m in rnd.get("matches", []) as Array:
			var result: Variant = m.get("result", null)
			if result == null:
				continue
			var home_id: String = String(m.get("home_club_id", ""))
			var away_id: String = String(m.get("away_club_id", ""))
			var fixture_key: String = SeasonEngine.cup_result_key(int(rnd.get("round", 0)), home_id, away_id)
			_attribute_national_goals(int(result[0]), home_id, "%s:home" % fixture_key, squads, xi_cache, goals, assists)
			_attribute_national_goals(int(result[1]), away_id, "%s:away" % fixture_key, squads, xi_cache, goals, assists)

	for fx in resolved.get("fixtures", []) as Array:
		var fx_result: Variant = fx.get("result", null)
		if fx_result == null:
			continue
		var fx_home: String = String(fx.get("home", ""))
		var fx_away: String = String(fx.get("away", ""))
		var fx_key: String = String(fx.get("key", ""))
		_attribute_national_goals(int(fx_result[0]), fx_home, "%s:home" % fx_key, squads, xi_cache, goals, assists)
		_attribute_national_goals(int(fx_result[1]), fx_away, "%s:away" % fx_key, squads, xi_cache, goals, assists)

	# BUG REAL encontrado de paso (no estaba, no lo pidió Wilber, pero sin
	# esto la fase de GRUPOS nunca aportaba un solo gol — antes del
	# repechaje de eliminatoria/Mundial/copa continental, "rounds" está
	# vacío, así que UEFA/AFC/CAF (puro grupos, sin ronda de eliminación)
	# quedaban SIEMPRE con 0 goleadores): cada grupo trae sus propios
	# fixtures con resultado ya escrito (ver ContinentalEngine.
	# group_standings()) — faltaba sumarlos acá.
	for g in resolved.get("groups", []) as Array:
		var group_index: int = int(g.get("group_index", -1))
		for fx in g.get("fixtures", []) as Array:
			var g_result: Variant = fx.get("result", null)
			if g_result == null:
				continue
			var g_home: String = String(fx.get("home_club_id", fx.get("home", "")))
			var g_away: String = String(fx.get("away_club_id", fx.get("away", "")))
			var g_key: String = ContinentalEngine.group_fixture_key(group_index, int(fx.get("matchday", 0)), g_home, g_away)
			_attribute_national_goals(int(g_result[0]), g_home, "%s:home" % g_key, squads, xi_cache, goals, assists)
			_attribute_national_goals(int(g_result[1]), g_away, "%s:away" % g_key, squads, xi_cache, goals, assists)

	return {"scorers": _sorted_rows(goals), "assists": _sorted_rows(assists)}

static func _national_xi_for(country: String, squads: Dictionary, xi_cache: Dictionary) -> Array:
	if xi_cache.has(country):
		return xi_cache[country]
	var squad_raw: Array = squads.get(country, [])
	if squad_raw.is_empty():
		xi_cache[country] = []
		return []
	var squad: Array[PlayerData] = []
	for p in squad_raw:
		squad.append(p)
	var team := MatchTeam.from_national_team(country, squad, null, 0.0)
	xi_cache[country] = team.starting_xi
	return team.starting_xi

static func _attribute_national_goals(
	goals_scored: int, country: String, seed_prefix: String,
	squads: Dictionary, xi_cache: Dictionary, goals: Dictionary, assists: Dictionary,
) -> void:
	if goals_scored <= 0:
		return
	var xi: Array = _national_xi_for(country, squads, xi_cache)
	if xi.is_empty():
		return
	for i in range(goals_scored):
		var scorer_rng := RandomNumberGenerator.new()
		scorer_rng.seed = hash("%s:goal:%d" % [seed_prefix, i])
		var scorer: PlayerData = _weighted_pick(xi, SCORER_WEIGHT, scorer_rng, null, country, goals)
		if scorer == null:
			continue
		_bump(goals, country, scorer, country)

		var assist_rng := RandomNumberGenerator.new()
		assist_rng.seed = hash("%s:assist:%d" % [seed_prefix, i])
		var assister: PlayerData = _weighted_pick(xi, ASSIST_WEIGHT, assist_rng, scorer, country, assists)
		if assister != null:
			_bump(assists, country, assister, country)

## Reemplaza (o agrega) la fila del usuario con sus cifras REALES —
## PlayerData.season_goals/season_key_passes, ya registrados partido a
## partido — en vez de dejar la atribución sintética que le tocara.
static func inject_user(result: Dictionary, player: PlayerData, club_name: String) -> void:
	_upsert(result["scorers"], player.player_name, club_name, player.season_goals, player.club_id)
	_upsert(result["assists"], player.player_name, club_name, player.season_key_passes, player.club_id)

static func _upsert(rows: Array, name: String, club_name: String, count: int, club_id: String = "") -> void:
	for r in rows:
		var same_club: bool = String(r.get("club_id", "")) == club_id if (club_id != "" and r.has("club_id")) else r["club_name"] == club_name
		if r["name"] == name and same_club:
			r["count"] = count
			rows.sort_custom(_row_sort)
			return
	if count > 0:
		rows.append({"name": name, "club_name": club_name, "club_id": club_id, "count": count})
		rows.sort_custom(_row_sort)
		if rows.size() > MAX_ROWS:
			rows.resize(MAX_ROWS)

static func _attribute_goals(
	goals_scored: int, club_id: String, seed_prefix: String,
	world: Dictionary, clubs_by_id: Dictionary, world_seed: int, season_start_epoch_day: int, xi_cache: Dictionary,
	goals: Dictionary, assists: Dictionary,
) -> void:
	if goals_scored <= 0:
		return
	var xi: Array = _starting_xi_for(club_id, world, clubs_by_id, world_seed, season_start_epoch_day, xi_cache)
	if xi.is_empty():
		return
	var club: ClubData = clubs_by_id.get(club_id)
	var club_name: String = club.club_name if club != null else "?"
	for i in range(goals_scored):
		var scorer_rng := RandomNumberGenerator.new()
		scorer_rng.seed = hash("%s:goal:%d" % [seed_prefix, i])
		var scorer: PlayerData = _weighted_pick(xi, SCORER_WEIGHT, scorer_rng, null, club_id, goals)
		if scorer == null:
			continue
		_bump(goals, club_id, scorer, club_name)

		var assist_rng := RandomNumberGenerator.new()
		assist_rng.seed = hash("%s:assist:%d" % [seed_prefix, i])
		var assister: PlayerData = _weighted_pick(xi, ASSIST_WEIGHT, assist_rng, scorer, club_id, assists)
		if assister != null:
			_bump(assists, club_id, assister, club_name)

static func _starting_xi_for(club_id: String, world: Dictionary, clubs_by_id: Dictionary, world_seed: int, season_start_epoch_day: int, xi_cache: Dictionary) -> Array:
	if xi_cache.has(club_id):
		return xi_cache[club_id]
	var club: ClubData = clubs_by_id.get(club_id)
	if club == null or not (world.get("club_meta_by_id", {}) as Dictionary).has(club_id):
		xi_cache[club_id] = []
		return []
	var squad: Array[PlayerData] = WorldFactory.make_squad_with_transfers(world, club_id, world_seed, season_start_epoch_day)
	var team := MatchTeam.from_club(club, squad, null, 0.0)
	xi_cache[club_id] = team.starting_xi
	return team.starting_xi

## Peso = aptitud de posición × calidad del jugador × "enfriamiento" —
## antes era SOLO posición, así que un suplente de 60 de overall tenía la
## MISMA chance de anotar que la estrella de 91 del mismo puesto ("los
## resultados no tienen lógica para los jugadores", bug real reportado).
## Exponente 1.3 (no cuadrado): un cuadrado completo concentraba TODAS
## las asistencias de la temporada en un solo mediocampista de overall
## alto. Ni así alcanzaba: sobre 30+ fechas, hasta una ventaja moderada
## de peso se acumula sola — un jugador terminó con 31 asistencias en una
## temporada de MLS, otro bug real reportado. `COOLDOWN_RATE`: cada gol o
## asistencia que un jugador YA lleva esta competición enfría su propio
## peso para el próximo — el mejor del plantel sigue siendo el más
## probable en cada partido individual, pero no se puede devorar la
## temporada entera él solo; el resto del plantel también suma con el
## correr de las fechas, como pasa de verdad.
const COOLDOWN_RATE := 0.28

static func _player_weight(p: PlayerData, weights: Dictionary, club_id: String, running_totals: Dictionary) -> float:
	var base: float = float(weights.get(p.position, 0))
	if base <= 0.0:
		return 0.0
	var quality: float = maxf(float(p.overall), 1.0)
	var key: String = "%s:%s" % [club_id, p.player_name]
	var so_far: int = int((running_totals.get(key, {}) as Dictionary).get("count", 0))
	var cooldown: float = 1.0 / (1.0 + float(so_far) * COOLDOWN_RATE)
	return base * pow(quality, 1.3) * cooldown

static func _weighted_pick(xi: Array, weights: Dictionary, rng: RandomNumberGenerator, exclude, club_id: String, running_totals: Dictionary) -> PlayerData:
	var total: float = 0.0
	for p in xi:
		if p == exclude:
			continue
		total += _player_weight(p, weights, club_id, running_totals)
	if total <= 0.0:
		return null
	var roll: float = rng.randf() * total
	var acc: float = 0.0
	for p in xi:
		if p == exclude:
			continue
		acc += _player_weight(p, weights, club_id, running_totals)
		if roll <= acc:
			return p
	return null

static func _bump(dict: Dictionary, club_id: String, player: PlayerData, club_name: String) -> void:
	var key: String = "%s:%s" % [club_id, player.player_name]
	if not dict.has(key):
		# club_id: hay clubes con el MISMO nombre en ligas distintas (Nacional
		# de Portugal y de Uruguay) — el nombre solo no alcanza para saber cuál.
		dict[key] = {"name": player.player_name, "club_name": club_name, "club_id": club_id, "count": 0}
	dict[key]["count"] += 1

static func _row_sort(a: Dictionary, b: Dictionary) -> bool:
	if a["count"] != b["count"]:
		return a["count"] > b["count"]
	return String(a["name"]) < String(b["name"])

static func _sorted_rows(dict: Dictionary) -> Array:
	var rows: Array = dict.values()
	rows.sort_custom(_row_sort)
	return rows.slice(0, mini(MAX_ROWS, rows.size()))
