extends RefCounted
class_name QualifyingEngine

## Eliminatorias al Mundial — Fase 1 de selecciones nacionales (ver plan en
## .claude/plans: "Selecciones nacionales: Mundial, eliminatorias y copas
## continentales"). Reusa la maquinaria de ContinentalEngine (tabla suiza /
## grupos) en vez de escribir un sistema paralelo: una selección es
## simplemente un STRING (nombre de país, ver Confederations.gd), igual que
## un club_id — ContinentalEngine.swiss_table()/build_groups()/
## group_standings() nunca tocan ClubData, solo ids + un Dictionary de
## fuerza (String -> float), así que funcionan sin cambios.
##
## Formato por confederación — reconocible por confederación como pidió
## Wilber, aproximando el REAL con el mismo criterio "techo alcanzable" que
## ya usa ContinentalEngine._FIELD_TARGET (no un molde único para las 5):
##   - CONMEBOL: TABLA ÚNICA, todos contra todos ida y vuelta (10 países en
##     este juego — el mismo número que la CONMEBOL real).
##   - UEFA / AFC / CAF: GRUPOS de 4 — el ganador de cada grupo clasifica
##     directo, los mejores segundos (por toda la confederación) entran a
##     un repechaje chico.
##   - CONCACAF: los más fuertes entran DIRECTO a una tabla final chica
##     (como el "octagonal" real, que ya arranca con las potencias
##     adentro); el resto se recorta por fuerza a quiénes llenan los cupos
##     que faltan de esa tabla — SIMPLIFICACIÓN CONSCIENTE de Fase 1: en
##     vez de simular un cuadro eliminatorio previo completo (mucha
##     complejidad para un dato que hoy nadie ve todavía, sin UI), se
##     recorta por fuerza. Cuando haya pantalla para esto (Fase 5) vale la
##     pena reemplazarlo por un cuadro real vía
##     SeasonCalendar.build_continental_bracket + SeasonEngine.resolve_cup.
##
## Anclaje temporal: un ciclo de eliminatorias dura ~2 años de calendario
## real (varias ventanas FIFA) — vive en el guardado de nivel superior
## "international" (WorldTickEngine), NUNCA en `season` (que se reconstruye
## entera cada 365 días). Fase 1 no toca todavía ese guardado ni el tick de
## WorldTickEngine — esto es solo el MOTOR, consultado bajo demanda (mismo
## criterio que ContinentalEngine con las copas de club: nada se computa
## hasta que alguien lo pide).

const CYCLE_QUALIFYING_DAYS := 700 # ~1.9 años, varias ventanas FIFA

## Cupos de la tabla única (CONMEBOL y la fase final de CONCACAF) — igual
## espíritu que ContinentalEngine.CAP_SLOTS_PER_COUNTRY: valores de trabajo
## inspirados en la eliminatoria real 2026 (CONMEBOL: 6 directo + 1
## repechaje de 10), no una licencia ni un dato oficial.
const DIRECT_SLOTS := {Confederations.CONMEBOL: 6, Confederations.CONCACAF: 3}
const PLAYOFF_SLOTS := {Confederations.CONMEBOL: 1, Confederations.CONCACAF: 2}

## Repechaje de grupos (UEFA/AFC/CAF): cuántos de los MEJORES segundos de
## toda la confederación (no solo de su grupo) entran al repechaje chico.
const GROUP_RUNNERUP_PLAYOFF_SLOTS := 4
const MAX_GROUPS := 14

## CONCACAF: cuántos de los más fuertes entran directo a la tabla final
## chica, y el tamaño total de esa tabla (el resto de cupos los llena el
## recorte por fuerza del resto del pool — ver nota de la cabecera).
## Formato v2 (auditoría de competiciones, nov-2026): grupos + ganadores del
## repechaje == cupos de la confederación (WorldCupEngine.SLOTS). Antes UEFA
## daba 13+2=15 plazas para 16 cupos y CONCACAF 5 para 6 (Mundial de 46 →
## resolve() vacío), y AFC/CAF 15 "clasificados directos" para 9/10 cupos.
## El formato viejo (`legacy`) solo se usa para un ciclo que ya estaba en
## juego al actualizar, para no rebarajar grupos con partidos jugados.
const GROUP_FORMAT := {
	Confederations.UEFA: {"groups": 12, "playoff_winners": 4},
	Confederations.AFC: {"groups": 8, "playoff_winners": 1},
	Confederations.CAF: {"groups": 9, "playoff_winners": 1},
}
const CONCACAF_DIRECT_V2 := 4

const CONCACAF_DIRECT_TO_FINAL := 6
const CONCACAF_FINAL_TABLE_SIZE := 8

## Todos los países de `confederation`, ordenados por fuerza (más fuerte
## primero) — la siembra determinista de toda la eliminatoria sale de acá.
static func _pool_for(confederation: String, strength_by_country: Dictionary) -> Array:
	var pool: Array = []
	for country in Confederations.COUNTRY_TO_CONFEDERATION:
		if Confederations.confederation_of(country) == confederation:
			pool.append(country)
	pool.sort_custom(func(a, b): return float(strength_by_country.get(a, 50)) > float(strength_by_country.get(b, 50)))
	return pool

## Resuelve la eliminatoria de `confederation` al día de hoy. Devuelve
## {"confederation", "format", "direct": Array[String], "playoff_pool":
## Array[String], "eliminated": Array[String], + los datos crudos según el
## formato: "table" (Array de filas) o "groups" (Array de {name,
## standings})}. `direct`/`playoff_pool` reflejan la tabla/grupos TAL COMO
## ESTÁN HOY — mundo vivo: antes de que se jueguen los partidos, todos
## están en 0 y el reparto es solo de siembra, exactamente igual que
## ContinentalEngine con las tablas de liga a mitad de temporada.
static func resolve(confederation: String, strength_by_country: Dictionary, world_seed: int, current_epoch_day: int, cycle_start_epoch_day: int, user_overrides: Dictionary = {}, windows: Array = [], legacy: bool = false) -> Dictionary:
	var pool: Array = _pool_for(confederation, strength_by_country)
	if pool.size() < 2:
		return {}
	match confederation:
		Confederations.CONMEBOL:
			return _resolve_table(pool, confederation, strength_by_country, world_seed, current_epoch_day, cycle_start_epoch_day, user_overrides, CYCLE_QUALIFYING_DAYS, "", windows)
		Confederations.CONCACAF:
			return _resolve_narrowing(pool, confederation, strength_by_country, world_seed, current_epoch_day, cycle_start_epoch_day, user_overrides, windows, legacy)
		_:
			return _resolve_groups(pool, confederation, strength_by_country, world_seed, current_epoch_day, cycle_start_epoch_day, user_overrides, windows, legacy)

## Ventanas de `windows` (lista completa del ciclo) cuyo inicio cae dentro
## de [anchor, anchor+span_days] — cada sub-tramo (CONCACAF tiene dos:
## ronda previa y tabla final) usa solo SUS ventanas, no las de todo el
## ciclo entero.
static func _windows_in_span(windows: Array, anchor: int, span_days: int) -> Array:
	var out: Array = []
	for w in windows:
		if int(w[0]) >= anchor and int(w[0]) <= anchor + span_days:
			out.append(w)
	return out

## --- CONMEBOL: tabla única, todos contra todos ida y vuelta ---
static func _resolve_table(pool: Array, confederation: String, strength_by_country: Dictionary, world_seed: int, current_epoch_day: int, anchor: int, user_overrides: Dictionary, span_days: int = CYCLE_QUALIFYING_DAYS, key_suffix: String = "", windows: Array = [], direct_override: int = -1) -> Dictionary:
	var key_prefix: String = "Q:%s%s" % [confederation, key_suffix]
	var matches_per_team: int = maxi(pool.size() - 1, 1) * 2 # ida y vuelta
	# Fixtures con fecha LIBRE (swiss_fixtures reparte parejo por todo
	# span_days, pensado para calendarios de club) — se remapean a las
	# ventanas FIFA reales antes de puntuar (BUG real, Parte 81: sin esto,
	# el 85% de los partidos de selección caían fuera de una ventana real).
	var fixtures: Array = ContinentalEngine.swiss_fixtures(pool, matches_per_team, key_prefix, anchor, span_days)
	var relevant_windows: Array = _windows_in_span(windows, anchor, span_days)
	if not relevant_windows.is_empty():
		fixtures = SeasonCalendar.remap_to_windows(fixtures, relevant_windows)
	var table: Array = ContinentalEngine.score_fixtures_to_table(pool, fixtures, world_seed, strength_by_country, current_epoch_day, user_overrides)

	var direct_n: int = direct_override if direct_override >= 0 else int(DIRECT_SLOTS.get(confederation, 4))
	var playoff_n: int = int(PLAYOFF_SLOTS.get(confederation, 1))
	var direct: Array = []
	var playoff_pool: Array = []
	var eliminated: Array = []
	for row in table:
		var pos: int = int(row["pos"])
		var country: String = String(row["club_id"])
		if pos <= direct_n:
			direct.append(country)
		elif pos <= direct_n + playoff_n:
			playoff_pool.append(country)
		else:
			eliminated.append(country)
	return {
		"confederation": confederation, "format": "table", "table": table,
		"direct": direct, "playoff_pool": playoff_pool, "eliminated": eliminated,
		"reserve": eliminated.duplicate(), "fixtures": fixtures,
	}

## Día del repechaje de segundos (UEFA/AFC/CAF): cerca del final del ciclo,
## después de que la fase de grupos ya terminó de sobra (build_groups usa
## como mucho CYCLE_QUALIFYING_DAYS de span).
const GROUP_PLAYOFF_OFFSET_FRAC := 0.92

## Resuelve el repechaje de los GROUP_RUNNERUP_PLAYOFF_SLOTS mejores
## segundos a un resultado REAL — antes se quedaban eternamente "en
## repechaje" (WorldCupEngine.pool_from_qualifying() los daba a TODOS por
## clasificados sin jugar nada, ver hallazgo de la Parte 82/Item 3 de
## "hazlo todo"). Reusa SeasonCalendar.build_playoff_bracket +
## SeasonEngine.resolve_cup — misma maquinaria de cuadro y penales que ya
## usan el Mundial/copas continentales, ninguna fórmula nueva. Solo importa
## la ronda de SEMIFINALES: cada cruce da UN cupo (no hay una final entre
## los 2 ganadores — son 2 plazas independientes, no una sola). Devuelve
## {winners, losers, decided, round} — "decided" false mientras el día del
## repechaje todavía no llegó (mundo vivo); "round" (la ronda 0 tal cual la
## devuelve SeasonEngine.resolve_cup, con "matches"/"epoch_day") viaja
## SIEMPRE que haya cuadro, decidido o no — es lo que necesita
## user_fixture_today() para ofrecerle el partido al usuario en el día
## exacto, en vez de dejar que se autosimule si le toca a él (Item 3 de la
## Parte 82 quedó con esta limitación conocida; ahora sí es jugable).
static func _resolve_group_playoff(playoff_pool: Array, confederation: String, world_seed: int, strength_by_country: Dictionary, playoff_day: int, current_epoch_day: int, user_overrides: Dictionary) -> Dictionary:
	if playoff_pool.size() < 2:
		return {"winners": playoff_pool.duplicate(), "losers": [], "decided": true, "round": {}}
	var bracket: Dictionary = SeasonCalendar.build_playoff_bracket(
		playoff_pool, "qual_playoff_%s" % confederation, "Repechaje %s" % CompetitionNames.national_continental(confederation), playoff_day, 4)
	var resolved: Dictionary = SeasonEngine.resolve_cup(bracket, world_seed, strength_by_country, user_overrides, current_epoch_day)
	var rounds: Array = resolved.get("rounds", [])
	if rounds.is_empty():
		return {"winners": [], "losers": [], "decided": false, "round": {}}
	var semis: Dictionary = rounds[0]
	if not bool(semis.get("decided", false)):
		return {"winners": [], "losers": [], "decided": false, "round": semis}
	# `byes` (si playoff_pool no es potencia de 2, ver build_playoff_bracket):
	# avanzan de oficio, no juegan la ronda 0 — se cuentan igual que un
	# ganador para no perder su cupo.
	var winners: Array = []
	winners.append_array(semis.get("byes", []))
	var losers: Array = []
	for m in semis.get("matches", []):
		var w: String = String(m.get("winner_club_id", ""))
		var h: String = String(m.get("home_club_id", ""))
		var a: String = String(m.get("away_club_id", ""))
		winners.append(w)
		losers.append(a if w == h else h)
	return {"winners": winners, "losers": losers, "decided": true, "round": semis}

## --- UEFA / AFC / CAF: grupos de 4, ganador directo + repechaje de segundos ---
static func _resolve_groups(pool: Array, confederation: String, strength_by_country: Dictionary, world_seed: int, current_epoch_day: int, anchor: int, user_overrides: Dictionary, windows: Array = [], legacy: bool = false) -> Dictionary:
	var fmt: Dictionary = GROUP_FORMAT.get(confederation, {})
	var group_count: int = mini(pool.size() / 4, MAX_GROUPS)
	if not legacy and not fmt.is_empty():
		group_count = mini(pool.size() / 4, int(fmt["groups"]))
	var slots: int = int(WorldCupEngine.SLOTS.get(confederation, 99))
	if group_count < 2:
		# Confederación/mundo demasiado chico para grupos reales — cae a
		# tabla única, mismo criterio de respaldo que
		# ContinentalEngine._resolve_groups con _resolve_knockout.
		return _resolve_table(pool, confederation, strength_by_country, world_seed, current_epoch_day, anchor, user_overrides, CYCLE_QUALIFYING_DAYS, "", windows)

	var field: Array = pool.slice(0, group_count * 4)
	var relevant_windows: Array = _windows_in_span(windows, anchor, CYCLE_QUALIFYING_DAYS)
	var groups: Array = ContinentalEngine.build_groups(field, group_count, world_seed, strength_by_country, current_epoch_day, anchor, user_overrides, CYCLE_QUALIFYING_DAYS, relevant_windows)

	var direct: Array = []
	var winners: Array = []
	var runnerups: Array = []
	var eliminated: Array = []
	for g in groups:
		var standings: Array = g["standings"]
		if standings.size() > 0:
			winners.append(standings[0])
		if standings.size() > 1:
			runnerups.append(standings[1])
		for row in standings.slice(2):
			eliminated.append(String(row["club_id"]))
	var by_pts := func(a, b):
		if a["pts"] != b["pts"]:
			return a["pts"] > b["pts"]
		return a["dg"] > b["dg"]
	runnerups.sort_custom(by_pts)
	# Más ganadores de grupo que cupos (solo el formato viejo): clasifican los
	# mejores ganadores y el resto queda de reserva; no hay repechaje.
	var overflow: Array = []
	if winners.size() >= slots:
		winners.sort_custom(by_pts)
		for i in range(slots, winners.size()):
			overflow.append(String(winners[i]["club_id"]))
		winners = winners.slice(0, slots)
	for w in winners:
		direct.append(String(w["club_id"]))
	var playoff_n: int = mini(GROUP_RUNNERUP_PLAYOFF_SLOTS, runnerups.size())
	if not legacy and not fmt.is_empty():
		playoff_n = mini(2 * int(fmt["playoff_winners"]), runnerups.size())
	if not overflow.is_empty():
		playoff_n = 0
	var playoff_pool: Array = []
	for i in range(playoff_n):
		playoff_pool.append(String(runnerups[i]["club_id"]))
	for i in range(playoff_n, runnerups.size()):
		eliminated.append(String(runnerups[i]["club_id"]))
	# Los que ni entraron al campo (techo de MAX_GROUPS/múltiplo de 4)
	# quedan eliminados desde la siembra — no tienen chance real este ciclo.
	for country in pool:
		if not field.has(country):
			eliminated.append(country)

	# Repechaje de segundos: resuelto a un resultado REAL (Item 3, "hazlo
	# todo") — mientras no llegue su día, playoff_pool se queda como está
	# (mismo comportamiento visible que antes); apenas se decide, los
	# ganadores pasan a "direct" (clasificados de verdad) y los perdedores a
	# "eliminated", y playoff_pool queda vacío — nadie se queda ahí para
	# siempre.
	var playoff_day: int = anchor + int(CYCLE_QUALIFYING_DAYS * GROUP_PLAYOFF_OFFSET_FRAC)
	var po: Dictionary = _resolve_group_playoff(playoff_pool, confederation, world_seed, strength_by_country, playoff_day, current_epoch_day, user_overrides)
	var losers: Array = []
	if bool(po.get("decided", false)):
		direct.append_array(po.get("winners", []))
		losers = po.get("losers", [])
		eliminated.append_array(losers)
		playoff_pool = []
	eliminated.append_array(overflow)
	# Reserva (por si a un Mundial le faltara alguien): ganadores sobrantes,
	# perdedores del repechaje, demás segundos y el resto por fuerza.
	var reserve: Array = overflow + losers
	for i in range(playoff_n, runnerups.size()):
		reserve.append(String(runnerups[i]["club_id"]))
	for c in pool:
		if not reserve.has(c) and eliminated.has(c):
			reserve.append(c)

	return {
		"confederation": confederation, "format": "groups", "groups": groups,
		"direct": direct, "playoff_pool": playoff_pool, "eliminated": eliminated, "reserve": reserve,
		"playoff_round": po.get("round", {}),
	}

## --- CONCACAF: los más fuertes directo a una tabla final chica, el resto
## se recorta por fuerza (ver nota de simplificación en la cabecera) ---
static func _resolve_narrowing(pool: Array, confederation: String, strength_by_country: Dictionary, world_seed: int, current_epoch_day: int, cycle_start_epoch_day: int, user_overrides: Dictionary, windows: Array = [], legacy: bool = false) -> Dictionary:
	var direct_to_final: Array = pool.slice(0, mini(CONCACAF_DIRECT_TO_FINAL, pool.size()))
	var rest: Array = pool.slice(direct_to_final.size())
	var needed: int = maxi(CONCACAF_FINAL_TABLE_SIZE - direct_to_final.size(), 0)
	var survivors: Array = rest.slice(0, mini(needed, rest.size()))
	var pre_eliminated: Array = rest.slice(survivors.size())

	var final_field: Array = direct_to_final + survivors
	var pre_span: int = int(CYCLE_QUALIFYING_DAYS * 0.4)
	var final_anchor: int = cycle_start_epoch_day + pre_span
	var final_span: int = CYCLE_QUALIFYING_DAYS - pre_span
	var resolved: Dictionary = _resolve_table(final_field, confederation, strength_by_country, world_seed, current_epoch_day, final_anchor, user_overrides, final_span, ":final", windows, -1 if legacy else CONCACAF_DIRECT_V2)
	resolved["eliminated"].append_array(pre_eliminated)
	resolved["reserve"].append_array(pre_eliminated)
	resolved["pre_stage_pool"] = rest
	return resolved

## Busca el partido de `country` en `current_epoch_day` dentro de
## `resolved` (el dict que devuelve resolve(), Fase 2) — soporta ambos
## formatos: "table" (fixtures con claves home/away, ver
## ContinentalEngine.swiss_fixtures) y "groups" (cada grupo trae las
## suyas con home_club_id/away_club_id, ver SeasonCalendar.
## build_league_fixtures). {} si no hay partido ese día — la inmensa
## mayoría de los días, las ventanas FIFA son cortas.
## `key` en el resultado es la clave EXACTA que usan swiss_table()/
## group_standings() para ese partido — quien juegue el partido de verdad
## (NationalTeamMatchLauncher + WorldTickEngine.record_user_national_result)
## la necesita para grabar el resultado REAL como override; si no, la
## tabla lo re-simularía con el simulador rápido en la próxima consulta,
## dando un resultado DISTINTO al que el usuario jugó de verdad (mismo
## bug de fondo que ya se arregló para las copas de club, Parte 71).
static func user_fixture_today(resolved: Dictionary, country: String, current_epoch_day: int) -> Dictionary:
	if resolved.is_empty():
		return {}
	if String(resolved.get("format", "")) == "table":
		for fx in resolved.get("fixtures", []):
			if int(fx.get("epoch_day", -1)) != current_epoch_day:
				continue
			var home: String = String(fx.get("home", ""))
			var away: String = String(fx.get("away", ""))
			if home == country:
				return {"opponent": away, "is_home": true, "epoch_day": current_epoch_day, "key": String(fx.get("key", ""))}
			if away == country:
				return {"opponent": home, "is_home": false, "epoch_day": current_epoch_day, "key": String(fx.get("key", ""))}
		return {}
	for g in resolved.get("groups", []):
		var group_index: int = int(g.get("group_index", -1))
		for fx in g.get("fixtures", []):
			if int(fx.get("epoch_day", -1)) != current_epoch_day:
				continue
			var home_id: String = String(fx.get("home_club_id", ""))
			var away_id: String = String(fx.get("away_club_id", ""))
			var key: String = ContinentalEngine.group_fixture_key(group_index, int(fx.get("matchday", 0)), home_id, away_id)
			if home_id == country:
				return {"opponent": away_id, "is_home": true, "epoch_day": current_epoch_day, "key": key}
			if away_id == country:
				return {"opponent": home_id, "is_home": false, "epoch_day": current_epoch_day, "key": key}
	# Repechaje de segundos (Item 3, Parte 82/84): si al usuario le toca
	# justo ESTE cruce, se juega de verdad en vez de autosimularse — mismo
	# contrato que un cruce de copa (SeasonEngine.cup_result_key), marcado
	# is_knockout para que WorldTickEngine._normalize_national_fixture no
	# lo trate como partido de tabla.
	var playoff_round: Dictionary = resolved.get("playoff_round", {})
	if not playoff_round.is_empty() and int(playoff_round.get("epoch_day", -1)) == current_epoch_day:
		for m in playoff_round.get("matches", []):
			var ph: String = String(m.get("home_club_id", ""))
			var pa: String = String(m.get("away_club_id", ""))
			var pkey: String = SeasonEngine.cup_result_key(int(playoff_round.get("round", 1)), ph, pa)
			if ph == country:
				return {"opponent": pa, "is_home": true, "epoch_day": current_epoch_day, "key": pkey, "is_knockout": true}
			if pa == country:
				return {"opponent": ph, "is_home": false, "epoch_day": current_epoch_day, "key": pkey, "is_knockout": true}
	return {}
