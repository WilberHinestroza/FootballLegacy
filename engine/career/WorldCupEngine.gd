extends RefCounted
class_name WorldCupEngine

## Mundial de SELECCIONES (Fase 3, ampliado a 48 a pedido de Wilber) —
## formato REAL 2026+: 48 selecciones, 12 grupos de 4 a partido único (3
## fechas), los 2 primeros de cada grupo MÁS los 8 mejores terceros (de
## los 12) pasan a dieciseisavos, y de ahí eliminatoria directa hasta la
## final (32 → 16 → 8 → 4 → 2 → 1, cinco rondas). Mismo espíritu que
## ClubWorldCupEngine.gd (grupos + bracket, "mundo vivo") pero con PAÍSES
## en vez de clubes y una cadencia propia de 4 años (WC_BASE_YEAR, no la
## de SuperCupEngine — el Mundial de selecciones y el de clubes no tienen
## por qué coincidir de año).
##
## SIMPLIFICACIÓN consciente que SÍ se mantiene (técho alcanzable): el
## EMPAREJAMIENTO de dieciseisavos no replica la tabla real de la FIFA
## (qué grupo-tercero enfrenta a qué grupo-ganador depende de CUÁLES 8 de
## los 12 terceros clasificaron, una tabla de combinaciones bastante
## intrincada) — acá los 32 clasificados (24 de grupos + 8 mejores
## terceros) entran directo al sembrado por fuerza de
## SeasonCalendar.build_continental_bracket(), igual que cualquier otro
## cuadro de este juego. La FORMA del torneo (48→32→dieciseisavos→...→
## final) es real; el detalle fino de qué cruce exacto de octavos es
## aproximado.
##
## Mundo vivo: NADA se persiste salvo los resultados REALES que el usuario
## haya jugado — igual patrón que ClubWorldCupEngine (claves "G:md:home:away"
## para grupo y SeasonEngine.cup_result_key para el cuadro). Todo lo demás
## es función pura de (world_seed, año). El arte del trofeo
## (Trophy.V3_ART["mundial_seleccion"]) ya existía de antes (Fase 1).
##
## Alimentado por QualifyingEngine (Fase 1/2): `field()` recibe, por
## confederación, la lista de países YA CLASIFICADOS (directos primero,
## luego el pool de repechaje como relleno) — no vuelve a decidir quién
## clasifica, solo arma el cuadro de 48 con lo que la eliminatoria ya dio.

const GROUPS := 12
const PER_GROUP := 4
## Parte 91p (pedido de Wilber, tras varias vueltas de la Parte 91n:
## "que el mundial inicie en el año y momento que le toca" — un Mundial
## que se llama "2026" pero se jugaba en JUNIO DE 2027 no cumplía eso,
## por más que la temporada tuviera margen). El Mundial ahora arranca AL
## PRINCIPIO de la temporada (a los pocos días de julio real, el mismo
## mes/año en que arranca — CalendarUtils.EPOCH_START_DATE), no al
## final. La liga/copa doméstica esperan su turno con el mismo mecanismo
## de blackout que ya usa el receso de fichajes/ventanas FIFA (ver
## SeasonCalendar.world_cup_blackout_for_season() — build_league_fixtures
## empuja la J1 sola hasta después de la final, no hace falta tocar
## LEAGUE_START_OFFSET a mano). Con esto el Mundial cabe cómodo dentro
## de los 365 días de siempre (termina el día 50, con la liga recién
## arrancando semanas después) — ya NO hace falta estirar la temporada
## (SeasonCalendar.WC_YEAR_EXTRA_DAYS volvió a 0).
const GROUP_START_OFFSET := 10 # días desde el arranque de temporada = ~11 de julio real
const MATCHDAY_SPACING := 4 # 3 jornadas de grupo entran en 8 días (real: ~2 semanas)
const KNOCKOUT_OFFSET := 25 # 6 días de colchón tras la última jornada de grupos
const SPAN_TO_FINAL := 25 # 32 clasificados -> 5 rondas, termina el día 50 (~20 de agosto real) — ~5 días/ronda
const BEST_THIRDS_COUNT := 8

## Cupos por confederación, sumando 48 — aproximación al reparto real
## 2026+ (UEFA 16, CAF 9, AFC 8, CONCACAF 6+sedes, CONMEBOL 6+repechaje),
## valores de trabajo (no una licencia de la FIFA; este juego tampoco
## modela sedes anfitrionas ni el repechaje intercontinental aparte).
const SLOTS := {"UEFA": 16, "CONMEBOL": 7, "CONCACAF": 6, "AFC": 9, "CAF": 10}

const WC_BASE_YEAR := 2026

## Los 48 países que jugaron el Mundial 2026 REAL (Canadá/México/EE.UU.),
## ya definido y jugado a esta altura (setiembre 2026) — pedido de
## Wilber: "por qué no haces el mundial inicial con las selecciones de
## este reciente mundial? ya para las próximas ya habrá clasificatoria".
## Nueva Zelanda (OFC, único cupo de esa confederación) entra dentro de
## "AFC" porque el juego no modela una confederación de Oceanía aparte
## (decisión de diseño de siempre, ver Confederations.gd). Los cupos de
## CADA confederación acá NO calzan con WorldCupEngine.SLOTS (esos son
## una aproximación de trabajo hecha antes de que la clasificación real
## terminara; CONMEBOL real fueron 6, no 7 — Bolivia perdió el repechaje
## intercontinental contra Irak) — no importa: WorldTickEngine.
## world_cup_this_cycle() pasa esta lista COMPLETA como `override_field`
## de resolve(), sin pasar por field()/pool_by_conf/SLOTS para nada.
## Curazao (CONCACAF, debutante real) se agregó a Countries.ALL/
## Confederations/NationalNames para esto — no existía en el juego.
const REAL_WC_2026_FIELD := [
	# UEFA (16)
	"Inglaterra", "Francia", "Croacia", "Noruega", "Portugal", "Alemania",
	"Países Bajos", "Suiza", "Escocia", "España", "Austria", "Bélgica",
	"Bosnia y Herzegovina", "Suecia", "Turquía", "República Checa",
	# CAF (10)
	"Argelia", "Cabo Verde", "Egipto", "Ghana", "Costa de Marfil",
	"Marruecos", "Senegal", "Sudáfrica", "Túnez", "República Democrática del Congo",
	# CONCACAF (6, 3 sedes + 3 directos)
	"Estados Unidos", "México", "Canadá", "Panamá", "Haití", "Curazao",
	# CONMEBOL (6)
	"Argentina", "Ecuador", "Colombia", "Uruguay", "Brasil", "Paraguay",
	# AFC + Nueva Zelanda/OFC plegada acá (10)
	"Japón", "Irán", "Uzbekistán", "Jordania", "Corea del Sur", "Australia",
	"Catar", "Arabia Saudita", "Irak", "Nueva Zelanda",
]

static func is_wc_year(year: int) -> bool:
	return year >= WC_BASE_YEAR and (year - WC_BASE_YEAR) % 4 == 0

## 32 países. `pool_by_conf[conf]`: Array de países YA CLASIFICADOS de esa
## confederación (ver QualifyingEngine.resolve — direct + playoff_pool
## concatenados, directos primero), ordenados por prioridad. Si un pool no
## llega a su cupo, se completa con lo que sobre de UEFA/CONMEBOL (las
## confederaciones con más profundidad en este mundo) — mismo respaldo que
## ClubWorldCupEngine.field().
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

static func country_qualifies(country: String, pool_by_conf: Dictionary) -> bool:
	return field(pool_by_conf).has(country)

## Arma `pool_by_conf` (el parámetro que espera field()/resolve()) a partir
## de los resultados YA RESUELTOS de QualifyingEngine para cada
## confederación — {confederation: QualifyingEngine.resolve(...)}.
## Directos primero, después el pool de repechaje como relleno (ver
## nota de field() sobre respaldo). Un helper chico, pero evita que quien
## llama (WorldTickEngine, Fase 4+) tenga que conocer las claves internas
## de QualifyingEngine.
static func pool_from_qualifying(qualifying_by_confederation: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for conf in qualifying_by_confederation:
		var resolved: Dictionary = qualifying_by_confederation[conf]
		if resolved.is_empty():
			continue
		var pool: Array = []
		pool.append_array(resolved.get("direct", []))
		pool.append_array(resolved.get("playoff_pool", []))
		# Reserva al final: si la eliminatoria no llena su cupo (formato viejo),
		# lo completa el mejor no clasificado de la MISMA confederación.
		for c in resolved.get("reserve", []):
			if not pool.has(c):
				pool.append(c)
		out[conf] = pool
	return out

## Reparto en 8 grupos por bombos (los 8 más fuertes al bombo 1, etc.) —
## idéntico algoritmo que ClubWorldCupEngine._groups_of, namespace de
## semilla propio ("wc_draw") para no compartir sorteo con el CWC de clubes.
static func _groups_of(f: Array, world_seed: int, year: int, strength_by_country: Dictionary) -> Array:
	var sorted_f: Array = f.duplicate()
	sorted_f.sort_custom(func(a, b): return int(strength_by_country.get(a, 55)) > int(strength_by_country.get(b, 55)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wc_draw|%d" % year) ^ world_seed
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

## Fixtures de un grupo de 4, partido único, 3 fechas — mismo emparejado
## que ClubWorldCupEngine.group_fixtures (MD1: 0-1,2-3 · MD2: 0-2,3-1 ·
## MD3: 3-0,1-2).
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

static func _grp_score(fx: Dictionary, world_seed: int, year: int, strength_by_country: Dictionary, overrides: Dictionary) -> Array:
	var key: String = _grp_key(int(fx["matchday"]), String(fx["home"]), String(fx["away"]))
	if overrides.has(key):
		var s: Array = overrides[key].get("score", [0, 0])
		return [int(s[0]), int(s[1])]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wcg|%s|%d" % [key, year]) ^ world_seed
	return MatchSimulator.simulate(float(strength_by_country.get(fx["home"], 55)), float(strength_by_country.get(fx["away"], 55)), rng)

## BUG REAL arreglado (Wilber: "en la tabla del mundial no se muestra
## partidos ganados, empatados y perdidos, todo está en 0 aunque se hayan
## jugado los partidos"): las filas se armaban con las claves "pg"/"pe"/
## "pp", pero `Selections.gd._table_row()` (la UI que arma la tabla) lee
## "g"/"e"/"p" — el mismo nombre que ya usa `ContinentalEngine.
## group_standings()` (por eso las copas continentales SÍ mostraban esas
## columnas bien). Como GDScript no avisa por leer una clave de
## Dictionary que no existe (devuelve el default de `.get()`, 0), el
## desajuste quedó invisible hasta que alguien miró la tabla de verdad.
static func _standings(ids: Array, fixtures: Array, world_seed: int, year: int, strength_by_country: Dictionary, current_epoch_day: int, overrides: Dictionary) -> Array:
	var row: Dictionary = {}
	for cid in ids:
		row[String(cid)] = {"club_id": String(cid), "pj": 0, "g": 0, "e": 0, "p": 0, "gf": 0, "gc": 0, "pts": 0}
	for fx in fixtures:
		if int(fx["epoch_day"]) >= current_epoch_day:
			continue
		var sc: Array = _grp_score(fx, world_seed, year, strength_by_country, overrides)
		fx["result"] = sc # el mismo dict vive en groups[g]["fixtures"] — así la UI (Selections.gd) muestra el resultado de grupos sin recalcularlo aparte
		var h: String = String(fx["home"]); var a: String = String(fx["away"])
		row[h]["pj"] += 1; row[a]["pj"] += 1
		row[h]["gf"] += sc[0]; row[h]["gc"] += sc[1]
		row[a]["gf"] += sc[1]; row[a]["gc"] += sc[0]
		if sc[0] > sc[1]:
			row[h]["g"] += 1; row[h]["pts"] += 3; row[a]["p"] += 1
		elif sc[1] > sc[0]:
			row[a]["g"] += 1; row[a]["pts"] += 3; row[h]["p"] += 1
		else:
			row[h]["e"] += 1; row[a]["e"] += 1; row[h]["pts"] += 1; row[a]["pts"] += 1
	var rows: Array = row.values()
	rows.sort_custom(func(x, y):
		if x["pts"] != y["pts"]:
			return x["pts"] > y["pts"]
		var dx: int = x["gf"] - x["gc"]; var dy: int = y["gf"] - y["gc"]
		if dx != dy:
			return dx > dy
		return x["gf"] > y["gf"])
	return rows

## Reordena `entries` (Array de {"id","group"}) para que, emparejados de
## a 2 consecutivos (índices 2i/2i+1 — el mismo criterio que
## SeasonCalendar._build_bracket_rounds), nunca coincidan dos del MISMO
## "group". Greedy: cada entrada busca la primera restante de un grupo
## distinto para completar el par — siempre alcanza salvo que un solo
## grupo aporte más de la mitad del campo (no pasa acá: como mucho 3 de
## 32, ver la nota donde se llama).
static func _avoid_same_group_pairs(entries: Array) -> Array:
	var pool: Array = entries.duplicate()
	var out: Array = []
	while pool.size() >= 2:
		var a: Dictionary = pool.pop_front()
		out.append(a)
		var partner_idx: int = -1
		for i in range(pool.size()):
			if int(pool[i]["group"]) != int(a["group"]):
				partner_idx = i
				break
		if partner_idx < 0:
			partner_idx = 0
		out.append(pool[partner_idx])
		pool.remove_at(partner_idx)
	out.append_array(pool)
	return out

## Torneo completo. {} si no es año de Mundial o el mundo no da para 32.
## `current_epoch_day` gatea grupos → octavos (mundo vivo: nada existe
## antes de que su fecha llegue).
## `override_field` (opcional): campo de 48 países YA armado (congelado
## por WorldTickEngine.world_cup_this_cycle() la primera vez que se
## resuelve, ver ese comentario) — cuando se pasa, se usa TAL CUAL en vez
## de derivarlo de `pool_by_conf` otra vez. `pool_by_conf` igual hace
## falta como parámetro (compat con los 2 llamadores que todavía arman
## el pool en vivo — WorldCupProbe.tscn, el diagnóstico manual).
static func resolve(world_seed: int, year: int, strength_by_country: Dictionary, pool_by_conf: Dictionary, season_start_day: int, current_epoch_day: int, overrides: Dictionary, override_field: Array = []) -> Dictionary:
	if not is_wc_year(year):
		return {}
	var f: Array = override_field if not override_field.is_empty() else field(pool_by_conf)
	if f.size() < GROUPS * PER_GROUP:
		return {}
	var grp_ids: Array = _groups_of(f, world_seed, year, strength_by_country)
	var group_start: int = season_start_day + GROUP_START_OFFSET
	var knockout_start: int = season_start_day + KNOCKOUT_OFFSET

	var groups: Array = []
	for g in range(GROUPS):
		var ids: Array = grp_ids[g]
		var fixtures: Array = group_fixtures(ids, group_start)
		groups.append({
			"name": "Grupo %s" % char(65 + g),
			"standings": _standings(ids, fixtures, world_seed, year, strength_by_country, current_epoch_day, overrides),
			"fixtures": fixtures,
		})

	var out := {
		"cup_id": "wc_%d" % year, "cup_name": "Copa Mundial %d" % year,
		"groups": groups, "rounds": [], "champion_country": "",
		"group_start": group_start, "knockout_start": knockout_start,
	}

	var groups_done: bool = current_epoch_day >= group_start + 2 * MATCHDAY_SPACING + 1
	if not groups_done:
		return out

	# Cada calificado se etiqueta con su grupo de origen ({"id","group"}) —
	# hace falta para _avoid_same_group_pairs() de abajo.
	var qualifiers_tagged: Array = []
	var thirds_tagged: Array = []
	for gi in range(groups.size()):
		var standings: Array = groups[gi]["standings"]
		for r in standings.slice(0, 2):
			qualifiers_tagged.append({"id": String(r["club_id"]), "group": gi})
		if standings.size() > 2:
			var t: Dictionary = standings[2].duplicate()
			t["group"] = gi
			thirds_tagged.append(t)
	# Los 8 MEJORES terceros (de los 12 grupos) completan el cuadro de 32 —
	# mismo criterio de tabla que _sorted_table/_standings: puntos, después
	# diferencia de gol, después goles a favor.
	thirds_tagged.sort_custom(func(x, y):
		if x["pts"] != y["pts"]:
			return x["pts"] > y["pts"]
		var dx: int = x["gf"] - x["gc"]; var dy: int = y["gf"] - y["gc"]
		if dx != dy:
			return dx > dy
		return x["gf"] > y["gf"])
	for r in thirds_tagged.slice(0, BEST_THIRDS_COUNT):
		qualifiers_tagged.append({"id": String(r["club_id"]), "group": int(r["group"])})
	# Reordena para que ningún cruce de dieciseisavos enfrente a dos
	# selecciones del MISMO grupo — BUG REAL arreglado (Wilber: "si dos
	# selecciones están en el mismo grupo y pasan primero y segundo, por
	# qué se enfrentan entre sí en dieciseisavos" — antes qualifiers traía
	# el 1º y el 2º de cada grupo SEGUIDOS, y _build_bracket_rounds()
	# empareja de a 2 consecutivos sin saber nada de grupos, así que
	# terminaban jugando entre sí apenas un partido después del último de
	# la fase de grupos, algo que nunca pasa en un Mundial real).
	var qualifiers: Array = []
	for e in _avoid_same_group_pairs(qualifiers_tagged):
		qualifiers.append(String(e["id"]))
	var bracket: Dictionary = SeasonCalendar.build_continental_bracket(
		qualifiers, out["cup_id"], out["cup_name"], knockout_start, SPAN_TO_FINAL)
	var resolved: Dictionary = SeasonEngine.resolve_cup(bracket, world_seed, strength_by_country, overrides, current_epoch_day)
	out["rounds"] = resolved.get("rounds", [])
	for rnd in out["rounds"]:
		if String(rnd.get("round_name", "")) == "Final" and rnd.get("decided", false):
			for m in rnd.get("matches", []):
				out["champion_country"] = String(m.get("winner_club_id", ""))
	return out

## Próximo partido del usuario en el torneo (grupo o cuadro), o {} — mismo
## contrato que ClubWorldCupEngine.next_user_fixture, con `country` en vez
## de `club_id`.
static func next_user_fixture(tournament: Dictionary, country: String, current_epoch_day: int, results: Dictionary) -> Dictionary:
	if tournament.is_empty() or country == "":
		return {}
	for g in tournament.get("groups", []):
		var in_group: bool = false
		for r in g.get("standings", []):
			if String(r["club_id"]) == country:
				in_group = true
		if not in_group:
			continue
		for fx in g.get("fixtures", []):
			if String(fx["home"]) != country and String(fx["away"]) != country:
				continue
			# BUG REAL corregido (Wilber: "en las fechas FIFA... casi que
			# toda la semana pueda ir pasando los días para jugar dentro
			# de esa semana" — asigná días específicos): faltaba este
			# chequeo (NationalCupEngine.next_user_fixture() SÍ lo tenía,
			# mismo criterio de siempre) — sin él, CUALQUIER día desde que
			# el campo del Mundial existe mostraba el partido como
			# "pendiente hoy", no solo el día real de esa jornada.
			if int(fx.get("epoch_day", -1)) != current_epoch_day:
				continue
			var key: String = _grp_key(int(fx["matchday"]), String(fx["home"]), String(fx["away"]))
			if results.has(key):
				continue
			return {
				"competition": "world_cup", "wc_phase": "group",
				"wc_key": key, "matchday": int(fx["matchday"]),
				"round_name": "Fase de grupos · J%d" % int(fx["matchday"]),
				"epoch_day": int(fx["epoch_day"]),
				"home_country": String(fx["home"]), "away_country": String(fx["away"]),
				"is_knockout": false,
			}
	for rnd in tournament.get("rounds", []):
		if int(rnd.get("epoch_day", -1)) != current_epoch_day:
			continue
		for m in rnd.get("matches", []):
			if String(m.get("home_club_id", "")) != country and String(m.get("away_club_id", "")) != country:
				continue
			var key2: String = SeasonEngine.cup_result_key(int(rnd["round"]), String(m["home_club_id"]), String(m["away_club_id"]))
			if results.has(key2):
				continue
			return {
				"competition": "world_cup", "wc_phase": "knockout",
				"wc_key": key2, "round": int(rnd["round"]),
				"round_name": String(rnd.get("round_name", "Eliminatoria")),
				"epoch_day": int(rnd["epoch_day"]),
				"home_country": String(m["home_club_id"]), "away_country": String(m["away_club_id"]),
				"is_knockout": true,
			}
	return {}
