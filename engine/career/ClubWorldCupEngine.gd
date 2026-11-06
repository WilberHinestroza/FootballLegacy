extends RefCounted
class_name ClubWorldCupEngine

## Mundial de Clubes JUGABLE — formato real 2025: 32 clubes, 8 grupos de 4
## a partido único (3 fechas), 2 primeros de cada grupo a octavos, y de
## ahí eliminatoria directa hasta la final. Cada 4 años
## (SuperCupEngine.is_cwc_year: 2025, 2029, 2033…).
##
## Mundo vivo: NADA se persiste salvo los resultados REALES del usuario
## (season["cwc_results"], claves "G:md:home:away" para grupo y
## SeasonEngine.cup_result_key para el cuadro). Todo lo demás es función
## pura de (world_seed, año). Reusa SeasonEngine.resolve_cup para la
## eliminatoria (con los mismos overrides que la copa nacional).

const GROUPS := 8
const PER_GROUP := 4
const GROUP_START_OFFSET := 250     # días desde el arranque de temporada (~abril)
const MATCHDAY_SPACING := 6
const KNOCKOUT_OFFSET := 272
const SPAN_TO_FINAL := 78

const SLOTS := {"UEFA": 12, "CONMEBOL": 6, "CONCACAF": 4, "AFC": 4, "CAF": 4, "OFC": 2}

static func is_cwc_season(year: int) -> bool:
	return SuperCupEngine.is_cwc_year(year)

## 32 ids. Cupos reales por confederación; si un pool no llega, se completa
## con los más fuertes de UEFA + CONMEBOL.
static func field(pool_by_conf: Dictionary) -> Array:
	var out: Array = []
	for conf in SLOTS:
		var pool: Array = pool_by_conf.get(conf, [])
		for i in range(mini(int(SLOTS[conf]), pool.size())):
			out.append(String(pool[i]))
	var extra: Array = (pool_by_conf.get("UEFA", []) as Array) + (pool_by_conf.get("CONMEBOL", []) as Array)
	var k: int = 0
	while out.size() < GROUPS * PER_GROUP and k < extra.size():
		var c: String = String(extra[k])
		k += 1
		if not out.has(c):
			out.append(c)
	return out.slice(0, GROUPS * PER_GROUP)

static func club_qualifies(club_id: String, pool_by_conf: Dictionary) -> bool:
	return field(pool_by_conf).has(club_id)

## Reparte los 32 en 8 grupos por bombos (los 8 más fuertes al bombo 1,
## etc.; un equipo de cada bombo por grupo, barajado por bombo).
static func _groups_of(f: Array, world_seed: int, year: int, sbc: Dictionary) -> Array:
	var sorted_f: Array = f.duplicate()
	sorted_f.sort_custom(func(a, b): return int(sbc.get(a, 55)) > int(sbc.get(b, 55)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cwc_draw|%d" % year) ^ world_seed
	var groups: Array = []
	for g in range(GROUPS):
		groups.append([])
	for pot in range(PER_GROUP):
		var band: Array = sorted_f.slice(pot * GROUPS, (pot + 1) * GROUPS)
		for i in range(band.size() - 1, 0, -1):
			var j: int = rng.randi() % (i + 1)
			var tmp = band[i]; band[i] = band[j]; band[j] = tmp
		for g in range(GROUPS):
			groups[g].append(String(band[g]))
	return groups

## Fixtures de un grupo de 4, partido único, 3 fechas.
## MD1: 0-1, 2-3 · MD2: 0-2, 3-1 · MD3: 3-0, 1-2
static func group_fixtures(ids: Array, group_start_day: int) -> Array:
	if ids.size() < 4:
		return []
	var mds := [
		[[0, 1], [2, 3]],
		[[0, 2], [3, 1]],
		[[3, 0], [1, 2]],
	]
	var out: Array = []
	for md in range(3):
		for pair in mds[md]:
			out.append({
				"matchday": md + 1,
				"epoch_day": group_start_day + md * MATCHDAY_SPACING,
				"home": String(ids[pair[0]]), "away": String(ids[pair[1]]),
			})
	return out

static func _grp_key(md: int, home: String, away: String) -> String:
	return "G:%d:%s:%s" % [md, home, away]

## Marcador de un partido de grupo: override del usuario si existe, si no
## simulación determinista.
static func _grp_score(fx: Dictionary, world_seed: int, year: int, sbc: Dictionary, overrides: Dictionary) -> Array:
	var key: String = _grp_key(int(fx["matchday"]), String(fx["home"]), String(fx["away"]))
	if overrides.has(key):
		var s: Array = overrides[key].get("score", [0, 0])
		return [int(s[0]), int(s[1])]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cwcg|%s|%d" % [key, year]) ^ world_seed
	return MatchSimulator.simulate(float(sbc.get(fx["home"], 55)), float(sbc.get(fx["away"], 55)), rng)

## Tabla de un grupo. `played_only`: si es false, cuenta TODOS los partidos
## (para la vista final); si true, solo los que ya se jugaron por fecha.
static func _standings(ids: Array, fixtures: Array, world_seed: int, year: int, sbc: Dictionary, current_epoch_day: int, overrides: Dictionary) -> Array:
	var row: Dictionary = {}
	for cid in ids:
		row[String(cid)] = {"club_id": String(cid), "pj": 0, "pg": 0, "pe": 0, "pp": 0, "gf": 0, "gc": 0, "pts": 0}
	for fx in fixtures:
		if int(fx["epoch_day"]) >= current_epoch_day:
			continue
		var sc: Array = _grp_score(fx, world_seed, year, sbc, overrides)
		var h: String = String(fx["home"]); var a: String = String(fx["away"])
		row[h]["pj"] += 1; row[a]["pj"] += 1
		row[h]["gf"] += sc[0]; row[h]["gc"] += sc[1]
		row[a]["gf"] += sc[1]; row[a]["gc"] += sc[0]
		if sc[0] > sc[1]:
			row[h]["pg"] += 1; row[h]["pts"] += 3; row[a]["pp"] += 1
		elif sc[1] > sc[0]:
			row[a]["pg"] += 1; row[a]["pts"] += 3; row[h]["pp"] += 1
		else:
			row[h]["pe"] += 1; row[a]["pe"] += 1; row[h]["pts"] += 1; row[a]["pts"] += 1
	var rows: Array = row.values()
	rows.sort_custom(func(x, y):
		if x["pts"] != y["pts"]:
			return x["pts"] > y["pts"]
		var dx: int = x["gf"] - x["gc"]; var dy: int = y["gf"] - y["gc"]
		if dx != dy:
			return dx > dy
		return x["gf"] > y["gf"])
	return rows

## Torneo completo. Devuelve {} si no es año de Mundial o el mundo no da
## para 32. Con `current_epoch_day` gatea grupos → octavos.
static func resolve(world_seed: int, year: int, sbc: Dictionary, pool_by_conf: Dictionary, season_start_day: int, current_epoch_day: int, overrides: Dictionary) -> Dictionary:
	if not is_cwc_season(year):
		return {}
	var f: Array = field(pool_by_conf)
	if f.size() < GROUPS * PER_GROUP:
		return {}
	var grp_ids: Array = _groups_of(f, world_seed, year, sbc)
	var group_start: int = season_start_day + GROUP_START_OFFSET
	var knockout_start: int = season_start_day + KNOCKOUT_OFFSET

	var groups: Array = []
	for g in range(GROUPS):
		var ids: Array = grp_ids[g]
		var fixtures: Array = group_fixtures(ids, group_start)
		groups.append({
			"name": "Grupo %s" % char(65 + g),
			"standings": _standings(ids, fixtures, world_seed, year, sbc, current_epoch_day, overrides),
			"fixtures": fixtures,
		})

	var out := {
		"cup_id": "cwc_%d" % year, "cup_name": "Mundial de Clubes %d" % year,
		"groups": groups, "rounds": [], "champion_club_id": "",
		"group_start": group_start, "knockout_start": knockout_start,
	}

	var groups_done: bool = current_epoch_day >= group_start + 2 * MATCHDAY_SPACING + 1
	if not groups_done:
		return out

	var qualifiers: Array = []
	for g in groups:
		for r in (g["standings"] as Array).slice(0, 2):
			qualifiers.append(String(r["club_id"]))
	var bracket: Dictionary = SeasonCalendar.build_continental_bracket(
		qualifiers, out["cup_id"], out["cup_name"], knockout_start, SPAN_TO_FINAL)
	var resolved: Dictionary = SeasonEngine.resolve_cup(bracket, world_seed, sbc, overrides, current_epoch_day)
	out["rounds"] = resolved.get("rounds", [])
	for rnd in out["rounds"]:
		if String(rnd.get("round_name", "")) == "Final" and rnd.get("decided", false):
			for m in rnd.get("matches", []):
				out["champion_club_id"] = String(m.get("winner_club_id", ""))
	return out

## Próximo partido del usuario en el torneo (grupo O cuadro), o {}.
## `played_key(fx)` es la clave con la que se guarda en season["cwc_results"].
static func next_user_fixture(tournament: Dictionary, club_id: String, current_epoch_day: int, results: Dictionary) -> Dictionary:
	if tournament.is_empty() or club_id == "":
		return {}
	# fase de grupos
	for g in tournament.get("groups", []):
		var in_group: bool = false
		for r in g.get("standings", []):
			if String(r["club_id"]) == club_id:
				in_group = true
		if not in_group:
			continue
		for fx in g.get("fixtures", []):
			if String(fx["home"]) != club_id and String(fx["away"]) != club_id:
				continue
			var key: String = _grp_key(int(fx["matchday"]), String(fx["home"]), String(fx["away"]))
			if results.has(key):
				continue
			return {
				"competition": "cwc", "cwc_phase": "group",
				"cwc_key": key, "matchday": int(fx["matchday"]),
				"round_name": "Fase de grupos · J%d" % int(fx["matchday"]),
				"epoch_day": int(fx["epoch_day"]),
				"home_club_id": String(fx["home"]), "away_club_id": String(fx["away"]),
				"is_knockout": false,
			}
	# eliminatoria
	for rnd in tournament.get("rounds", []):
		if int(rnd.get("epoch_day", 0)) < current_epoch_day and not rnd.get("decided", false):
			pass
		for m in rnd.get("matches", []):
			if String(m.get("home_club_id", "")) != club_id and String(m.get("away_club_id", "")) != club_id:
				continue
			var key2: String = SeasonEngine.cup_result_key(int(rnd["round"]), String(m["home_club_id"]), String(m["away_club_id"]))
			if results.has(key2):
				continue
			return {
				"competition": "cwc", "cwc_phase": "knockout",
				"cwc_key": key2, "round": int(rnd["round"]),
				"round_name": String(rnd.get("round_name", "Eliminatoria")),
				"epoch_day": int(rnd["epoch_day"]),
				"home_club_id": String(m["home_club_id"]), "away_club_id": String(m["away_club_id"]),
				"is_knockout": true,
			}
	return {}
