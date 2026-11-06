extends RefCounted
class_name ContinentalEngine

## Copa continental de clubes (Fase 10+ dejó afuera selecciones/Mundial a
## propósito, pero copas de CLUBES cruzando ligas de una misma
## confederación son el mismo alcance que la copa doméstica — mundo
## vivo, nada pre-simulado ni guardado).
##
## Las 3 fases de eliminación directa (_resolve_knockout/_resolve_groups/
## _resolve_swiss) llaman SeasonEngine.resolve_cup() con
## two_legged_until_final=true (auditoría ronda 2): octavos/cuartos/semis
## reales son ida y vuelta, solo la Final es partido único — antes
## resolve_cup() siempre resolvía a partido único, así que un empate en el
## agregado de un cruce que el usuario no jugaba él mismo nunca disparaba
## penales.
##
## Cada confederación usa el formato REAL que usa hoy (2024+), no un
## molde único para las cinco — investigado, no inventado:
##   - UEFA (las 3) y AFC (las 3): FASE DE LIGA tipo "suizo" — todo el
##     campo en una sola tabla, cada club juega contra varios rivales
##     distintos (no todos), los 8 primeros pasan directo a octavos, los
##     puestos 9-24 juegan un playoff previo por el resto de plazas. Esto
##     reemplazó a los grupos de 4 en la reforma de 2024 de ambas
##     confederaciones — es el cambio de formato más comentado del fútbol
##     de clubes reciente, y el motivo de esta reescritura.
##   - CONMEBOL: grupos de 4 (ida y vuelta) clásicos, 2 primeros a octavos
##     — formato que CONMEBOL nunca abandonó.
##   - CAF: 2 grupos (ida y vuelta) de los clasificados, 2 primeros de
##     cada uno van DIRECTO a semifinal (campo más chico, sin octavos).
##   - CONCACAF: sin fase de grupos — cuadro eliminatorio puro desde el
##     primer día, como su "Champions Cup" real.
##
## Pura y testeable: nunca llama a WorldTickEngine directo — quien la use
## le pasa la tabla de cada liga por Callable, mismo patrón que "inyectar"
## world/strength_by_club en el resto de engine/world/*.

enum Format { SWISS, GROUPS, KNOCKOUT }

const FORMAT_BY_CONFEDERATION := {
	Confederations.UEFA: Format.SWISS,
	Confederations.AFC: Format.SWISS,
	Confederations.CONMEBOL: Format.GROUPS,
	Confederations.CAF: Format.GROUPS,
	Confederations.CONCACAF: Format.KNOCKOUT,
}

## Cupos por PAÍS (liga tier 1 == país en este mundo, ver WorldFactory:
## nunca hay dos ligas tier 1 del mismo país) según su POSICIÓN dentro del
## ranking de su propia confederación — no por una brecha de reputación
## absoluta: eso dejaba SOLO a las 5 ligas con reputación >= 80 mandando
## clubes a la Champions (3 cada una = 15 clubes, el bug real reportado:
## "por qué apenas se ven 15 equipos"), y las demás 19 ligas de la UEFA
## nunca competían en el torneo top pese a estar en la misma confederación.
##
## El ranking que define la posición de cada país es el de
## CoefficientEngine, calculado con el resultado YA CERRADO de la
## temporada anterior (nunca el de la temporada en curso — sería
## circular, ver la nota de CoefficientEngine) — quien llama
## (WorldTickEngine) lo arma desde season["confederation_rankings"] y lo
## pasa como `rank_by_league_id`. La primera temporada de una carrera no
## tiene "temporada anterior": se arranca con el ranking de reputación
## (ver CoefficientEngine.bootstrap_rankings) — "los mejores rankeados de
## cada país para empezar el mundo", pedido explícito de Wilber.
## Techo de clubes que un solo país manda a UN torneo — pedido explícito
## de Wilber (tabla real de cantidades por confederación): distinto por
## confederación porque el "campo BUSCADO" (_FIELD_TARGET) de algunas solo
## es alcanzable con un techo más alto, dado lo pocas ligas que tiene esa
## confederación en ESTE mundo (ver comentario de _FIELD_TARGET).
const CAP_SLOTS_PER_COUNTRY := {
	Confederations.UEFA: 5,
	Confederations.CONMEBOL: 5,
	Confederations.AFC: 5,
	Confederations.CONCACAF: 7, # solo 4 ligas en este mundo — techo más alto para llegar al campo real (27) de su torneo top
	Confederations.CAF: 8, # solo 2 ligas con plantel real hoy (dato, ver WorldImporter) — techo más alto para que el campo real (16/16) no dependa de tener las 5 ligas declaradas
}
const _DEFAULT_CAP_SLOTS_PER_COUNTRY := 4

static func _cap_for(confederation: String) -> int:
	return int(CAP_SLOTS_PER_COUNTRY.get(confederation, _DEFAULT_CAP_SLOTS_PER_COUNTRY))

## Confederaciones donde CADA país participa en TODOS los niveles de su
## confederación a la vez (sus mejores clubes al torneo top, los
## siguientes al segundo, etc.) — así funciona CONMEBOL/CONCACAF/CAF/AFC de
## verdad: Brasil o Argentina mandan clubes a la Libertadores Y a la
## Sudamericana en la MISMA temporada, nunca "todo o nada" en un solo
## torneo. CONCACAF en la realidad reparte por sub-región (Norte/
## Centroamérica/Caribe) en vez de por nivel, algo que este mundo no
## modela (solo tiene 4 países, mezclados); "compartido" es la
## aproximación más simple que sigue dando a cada país acceso a sus
## varios torneos, en vez de dejarlo encerrado en uno solo para siempre.
##
## UEFA se agregó acá en la ronda 6 (pedido explícito de Wilber, jugando):
## antes quedaba afuera con un sistema de "bloques exclusivos" (cada país
## entero a UN SOLO torneo según su ranking general de la confederación,
## nunca repartido) — pero eso no es como funciona la Champions real: un
## país fuerte manda su 1°-4° a Champions, 5°-6° a Europa y 7° a
## Conference, TODO DENTRO DE LA MISMA LIGA, exactamente el mismo patrón
## que ya usan las otras 4 confederaciones acá. Con el cap ya configurado
## (CAP_SLOTS_PER_COUNTRY[UEFA]=5) y sus ~25 ligas, el reparto compartido
## funciona con el mismo _distribute_slots() ya probado para las demás.
const _SHARED_TIER_CONFEDERATIONS := [Confederations.CONMEBOL, Confederations.CAF, Confederations.CONCACAF, Confederations.AFC, Confederations.UEFA]

## Tamaño de campo BUSCADO para cada torneo (tier 1..N) de cada
## confederación — pedido explícito, con la tabla REAL 2024+ como
## referencia (36/36/36 UEFA; 32/32 CONMEBOL en grupos de 4; 27/20/10
## CONCACAF; 16/16 CAF en grupos de 4; 24/32/20 AFC). Este mundo tiene MUY
## pocas ligas por confederación fuera de la UEFA (7 CONMEBOL, 4 CONCACAF,
## 7 AFC, 2 CAF con plantel real) — cuando el número real no es alcanzable
## ni subiendo el CAP (_cap_for) sin que un solo país inunde el torneo, se
## usa el techo alcanzable en su lugar (documentado por confederación
## abajo), nunca un número inventado más allá de eso.
##
## CONMEBOL y CAF juegan grupos de 4 (ver build_groups): el objetivo de
## esas dos DEBE ser múltiplo de 4, si no _resolve_groups arma
## `group_count = pool.size() / 4` grupos y recorta el pool a
## `group_count * 4`, descartando en silencio los cupos que sobran del
## reparto (bug real reportado dos veces: primero "copas internacionales
## sin estar los equipos completos" con el reparto viejo por bloques,
## después "la Libertadores/Sudamericana tienen 3 grupos" con el primer
## intento de arreglo — objetivos [12,12] técnicamente exactos pero muy
## chicos para lo que se espera de esos torneos). UEFA/AFC juegan fase de
## liga y CONCACAF cuadro directo — ninguno de los dos tiene ese problema
## (cualquier tamaño de campo sirve, con bye si hace falta).
const _FIELD_TARGET := {
	Confederations.UEFA: [36, 36, 36], # real exacto — 24 ligas / 3 bloques de 8 x CAP 5 = 40 ≥ 36
	Confederations.CONMEBOL: [32, 32], # real exacto — 7 ligas x CAP 5 = 35 ≥ 32, ambos múltiplo de 4
	Confederations.CONCACAF: [27, 20, 10], # real exacto — 4 ligas x CAP 7 = 28 ≥ 27, resto ya alcanzaba
	Confederations.AFC: [24, 32, 20], # real exacto — 7 ligas x CAP 5 = 35 ≥ 32 (el más grande de los 3)
	Confederations.CAF: [16, 16], # real exacto — 2 ligas con plantel real x CAP 8 = 16
}

## Fase de liga (suizo): partidos por club y tope de campo que entra al
## cuadro final tras la fase de liga — 8 directos a octavos + 16 en
## playoff previo = 24, igual que la reforma real de UEFA/AFC.
const SWISS_MATCHES_MAIN := 8    # tier 1 y 2
const SWISS_MATCHES_MINOR := 6   # tier 3 (solo UEFA)
const SWISS_KNOCKOUT_FIELD := 24
const SWISS_FIELD_CAP := 36      # techo de clubes en la fase de liga

## Ancla temporal de TODO torneo continental: SIEMPRE relativa a la
## temporada actual (season_start_epoch_day), nunca a un día absoluto fijo.
## Bug real que esto reemplaza: antes se usaba un "0"/"90" fijos — a partir
## de la 2ª temporada, current_epoch_day ya había pasado esos días hace
## rato y el cuadro entero salía "ya jugado" (campeón decidido) desde el
## primer vistazo, sin ninguna ronda "pendiente" jamás.
##
## Calendario real (pedido explícito): la temporada arranca en julio y
## termina en junio CON las finales de copas continentales — así que la
## fase de grupos/suiza arranca poco después que la propia liga doméstica
## (día 65 ≈ septiembre, las continentales de verdad también corren en
## paralelo a las ligas, no "a mitad de año" como se hacía antes) y los
## octavos/cuartos/semis/final ocupan el resto de la temporada hasta
## CONTINENTAL_FINAL_TARGET_DAY (≈350, fines de mayo) — antes de que
## SeasonCalendar.SEASON_TOTAL_DAYS(365) cierre la temporada y arranque el
## rollover.
##
## Calendario (epoch day 0 = 1 de julio, ver CalendarUtils.EPOCH_START_DATE;
## 1 de enero ≈ día 184): la fase de grupos/suizo arranca el día 48
## (~18 de agosto) y termina el día 168 (~16 de diciembre) — pedido de
## Wilber: "terminarlas antes de enero".
const CONTINENTAL_START_OFFSET := 48
const KNOCKOUT_AFTER_PHASE_OFFSET := 120 # separación entre el arranque de grupos/suizo y el cuadro final
const CONTINENTAL_FINAL_TARGET_DAY := 350

## Cuántos días quedan hasta CONTINENTAL_FINAL_TARGET_DAY desde que arranca
## el CUADRO FINAL (`bracket_start_day`) — SeasonCalendar reparte las
## rondas del cuadro en esa ventana así, tenga las rondas que tenga (24
## equipos o 6), la final siempre cae cerca de la misma fecha. Nunca
## negativo ni irrisoriamente corto aunque algo se corra de más.
static func _span_to_final(bracket_start_day: int) -> int:
	return maxi(CONTINENTAL_FINAL_TARGET_DAY - bracket_start_day, 30)

## Ligas tier-1 de `confederation`, ordenadas por posición (mejor primero):
## la de `rank_by_league_id` si el país aparece ahí, si no por reputación
## (bootstrap de la 1ª temporada, o país nuevo que el ranking aún no vio —
## desempate estable, nunca los deja fuera).
static func _leagues_by_rank(world: Dictionary, confederation: String, rank_by_league_id: Dictionary) -> Array:
	var leagues: Array = []
	for league in world.get("leagues", []):
		# team_count > 0: un mundo importado puede declarar una liga sin
		# haber cargado clubes para ella (cobertura parcial del JSON del
		# usuario, ver WorldImporter) — un país sin un solo club no puede
		# mandar a nadie a ningún lado, nunca cuenta para el reparto.
		if league.tier == 1 and league.team_count > 0 and Confederations.confederation_of(league.country) == confederation:
			leagues.append(league)
	leagues.sort_custom(func(a, b):
		var ra: int = int(rank_by_league_id.get(a.league_id, 999999))
		var rb: int = int(rank_by_league_id.get(b.league_id, 999999))
		if ra != rb:
			return ra < rb
		return a.reputation > b.reputation
	)
	return leagues

## Reparte el ranking de `total` países en `tiers` bloques iguales (el
## último puede ser más chico) — bloque 1 = las posiciones más altas =
## torneo de más nivel. Devuelve Array[Array[int]]: índices 0-based del
## ranking que caen en cada bloque.
static func _tier_blocks(total: int, tiers: int) -> Array:
	var block_size: int = maxi(1, int(ceil(float(total) / float(tiers))))
	var blocks: Array = []
	var start: int = 0
	for t in range(tiers):
		var end: int = mini(start + block_size, total)
		var idxs: Array = []
		for i in range(start, end):
			idxs.append(i)
		blocks.append(idxs)
		start = end
	return blocks

## Reparte `target` cupos entre `block_size` países en orden de posición
## (el primero del bloque recibe antes que el último — nunca al revés),
## de a un cupo por vuelta, hasta CAP_SLOTS_PER_COUNTRY cada uno. Con
## target == block_size * CAP todos llegan al techo (parejo); con menos,
## los primeros del bloque terminan con más que los últimos — mismo
## espíritu que una lista de acceso real (los países más fuertes SÍ mandan
## más clubes que el último de su propio bloque).
static func _distribute_slots(block_size: int, target: int, cap: int) -> Array:
	var slots: Array = []
	for i in range(block_size):
		slots.append(0)
	var remaining: int = mini(target, block_size * cap)
	while remaining > 0:
		var progressed: bool = false
		for i in range(block_size):
			if remaining <= 0:
				break
			if slots[i] < cap:
				slots[i] += 1
				remaining -= 1
				progressed = true
		if not progressed:
			break
	return slots

## A qué torneo(s) (tier 1-based) y con cuántos cupos entra el país en la
## posición `rank` (1-based) de un total de `total_countries` en
## `confederation` — la MISMA cuenta que usa qualified_clubs() para armar
## el campo, expuesta para que CoefficientEngine pueda mostrar "si hoy
## terminara la tabla de coeficientes, a esta liga le tocarían estos
## cupos en tal torneo" (pedido explícito: saber los cupos de cada país
## para las próximas copas ANTES de que arranquen).
##
## Array[{tier, spots}], nunca más de una fila por tier, en orden de tier
## (1 primero). Todas las confederaciones son "compartidas" desde la
## ronda 6 (ver _SHARED_TIER_CONFEDERATIONS): pueden devolver una fila
## POR CADA tier — el mismo país entra a Champions Y Europa (o Libertadores
## Y Sudamericana) el mismo año, cada una con su propio reparto
## independiente, según en qué franja de SU PROPIA tabla quedó cada club.
## Para la UI (pintar la tabla de liga, pedido explícito de Wilber, ronda
## 6): rangos de POSICIÓN DE TABLA (1-based, inclusive) que alimentan cada
## tier continental para una liga en `rank` de su confederación — mismo
## criterio de "offset acumulado" que qualified_clubs(), pero para UNA
## sola liga, sin tocar tablas de otras. Array[{tier, from_pos, to_pos}].
static func table_zones_for_rank(confederation: String, rank: int, total_countries: int) -> Array:
	var allocs: Array = allocation_for_rank(confederation, rank, total_countries)
	var zones: Array = []
	var offset: int = 0
	for a in allocs:
		var spots: int = int(a["spots"])
		if spots <= 0:
			continue
		zones.append({"tier": int(a["tier"]), "from_pos": offset + 1, "to_pos": offset + spots})
		offset += spots
	return zones

## Lista de acceso REALISTA (bug reportado: "ligas top 5 que no mandan a nadie a la
## Champions"). El reparto parejo de a un cupo por vuelta dejaba a la Premier, LaLiga
## o la Serie A con 2 cupos de Champions —igual que Austria— y con dos sorpresas en
## la tabla sus grandes se quedaban afuera. Ahora, como la UEFA real: los 4 primeros
## del ranking mandan 4 a la Champions, el 5° 3, el 6° 2 y el resto 1; las ligas de
## abajo del todo van a la Europa League / Conference. Cupos base por posición
## (1-based) y por nivel; luego se ajusta al tamaño de campo buscado (_FIELD_TARGET).
const _ACCESS_PROFILE := {
	Confederations.UEFA: [
		[4, 4, 4, 4, 3, 2],                       # Champions: el resto, 1
		[2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2],        # Europa League: el resto, 1
		[1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2], # Conference: el resto, 1
	],
}

## Cupos por posición según _ACCESS_PROFILE, ajustados para sumar `target`: si
## sobran se quitan desde la última liga hacia arriba (las de abajo pueden quedarse
## sin ese torneo); si faltan se suman desde arriba, sin pasar `cap`.
static func _profile_slots(confederation: String, tier_idx: int, total: int, target: int, cap: int) -> Array:
	var prof: Array = (_ACCESS_PROFILE[confederation] as Array)[mini(tier_idx, (_ACCESS_PROFILE[confederation] as Array).size() - 1)]
	var slots: Array = []
	var sum := 0
	for i in range(total):
		var v: int = int(prof[i]) if i < prof.size() else 1
		v = mini(v, cap)
		slots.append(v)
		sum += v
	var i := total - 1
	while sum > target and i >= 0:
		if slots[i] > 0:
			slots[i] -= 1
			sum -= 1
		else:
			i -= 1
		if i >= 0 and slots[i] == 0:
			i -= 1
	var guard := 0
	while sum < target and guard < 20:
		var progressed := false
		for k in range(total):
			if sum >= target:
				break
			if slots[k] < cap:
				slots[k] += 1
				sum += 1
				progressed = true
		if not progressed:
			break
		guard += 1
	return slots

static func allocation_for_rank(confederation: String, rank: int, total_countries: int) -> Array:
	var tiers: int = Confederations.tier_count(confederation)
	var targets: Array = _FIELD_TARGET.get(confederation, [])

	var cap: int = _cap_for(confederation)

	if confederation in _SHARED_TIER_CONFEDERATIONS:
		var result: Array = []
		for t in range(tiers):
			var target: int = int(targets[t]) if t < targets.size() else 0
			if target <= 0:
				continue
			var slots: Array = _profile_slots(confederation, t, total_countries, target, cap) if _ACCESS_PROFILE.has(confederation) else _distribute_slots(total_countries, target, cap)
			var spots: int = int(slots[rank - 1]) if rank - 1 < slots.size() else 0
			if spots > 0:
				result.append({"tier": t + 1, "spots": spots})
		return result

	var blocks := _tier_blocks(total_countries, tiers)
	for t in range(blocks.size()):
		var idxs: Array = blocks[t]
		if idxs.is_empty():
			continue
		var idx: int = rank - 1
		if idx < idxs[0] or idx > idxs[idxs.size() - 1]:
			continue
		var target: int = int(targets[t]) if t < targets.size() else cap
		var slots := _distribute_slots(idxs.size(), target, cap)
		var spots: int = int(slots[idx - idxs[0]])
		return [{"tier": t + 1, "spots": spots}] if spots > 0 else []
	return []

## `table_for_league` : Callable(league_id: int) -> Array — mismo contrato
## que WorldTickEngine.table_for_league(), para no acoplar este archivo al
## autoload. `rank_by_league_id`: ver nota de arriba del archivo.
static func qualified_clubs(world: Dictionary, confederation: String, tier: int, table_for_league: Callable, strength_by_club: Dictionary, rank_by_league_id: Dictionary) -> Array:
	# Los torneos continentales son SOLO de primera división — una segunda
	# división nunca manda clubes a la Champions/Libertadores de verdad,
	# sin importar cuánta reputación tenga.
	var leagues := _leagues_by_rank(world, confederation, rank_by_league_id)
	if leagues.is_empty():
		return []

	var pool: Array = []
	for i in range(leagues.size()):
		var allocs: Array = allocation_for_rank(confederation, i + 1, leagues.size())
		# Un país "compartido" (ver _SHARED_TIER_CONFEDERATIONS) puede tener
		# fila para varios tiers a la vez — sus mejores puestos de tabla van
		# al tier más alto, los SIGUIENTES puestos (nunca los mismos clubes
		# dos veces) al siguiente tier. `offset` acumula cuántos puestos ya
		# se repartieron a tiers de más nivel antes de llegar al pedido acá.
		var offset: int = 0
		var spots_here: int = 0
		var found: bool = false
		for a in allocs:
			if int(a["tier"]) == tier:
				spots_here = int(a["spots"])
				found = true
				break
			offset += int(a["spots"])
		if not found or spots_here <= 0:
			continue
		var league: LeagueData = leagues[i]
		var table: Array = table_for_league.call(league.league_id)
		for k in range(offset, mini(offset + spots_here, table.size())):
			pool.append(String(table[k]["club_id"]))
	pool.sort_custom(func(a, b): return float(strength_by_club.get(a, 50)) > float(strength_by_club.get(b, 50)))
	return pool

## Arma y resuelve UN torneo (nivel `tier`, 1-based) de la confederación
## al día de hoy, con el formato real de esa confederación. {} si ese
## nivel no tiene ni 2 clubes clasificados. `season_start_epoch_day`: el de
## la temporada ACTUAL (WorldTickEngine.season) — nunca un día absoluto
## fijo, ver CONTINENTAL_START_OFFSET arriba.
static func build_and_resolve(
	world: Dictionary, confederation: String, tier: int, table_for_league: Callable,
	world_seed: int, strength_by_club: Dictionary, current_epoch_day: int, season_start_epoch_day: int = 0,
	rank_by_league_id: Dictionary = {}, user_overrides: Dictionary = {}, frozen_pool: Array = [],
) -> Dictionary:
	# `frozen_pool`: el sorteo del torneo (qué clubes entran y en qué orden
	# de siembra) se CONGELA una vez por temporada — ver
	# WorldTickEngine._frozen_cont_pool. Si no viene congelado (tests,
	# CoefficientEngine que sólo quiere el campeón) se calcula al vuelo con
	# la tabla actual, pero eso NO debe usarse para lo que el usuario ve/
	# juega: la tabla de liga cambia cada jornada y el grupo se rebarajaba
	# (bug reportado por Wilber: "el grupo cambió de equipos").
	var pool: Array = frozen_pool.duplicate() if not frozen_pool.is_empty() \
		else qualified_clubs(world, confederation, tier, table_for_league, strength_by_club, rank_by_league_id)
	if pool.size() < 2:
		return {}
	var cup_id: String = "continental_%s_%d" % [confederation, tier]
	var cup_name: String = Confederations.tier_name(confederation, tier)
	var format: int = FORMAT_BY_CONFEDERATION.get(confederation, Format.GROUPS)
	var anchor: int = season_start_epoch_day + CONTINENTAL_START_OFFSET

	match format:
		Format.SWISS:
			return _resolve_swiss(pool, confederation, tier, cup_id, cup_name, world_seed, strength_by_club, current_epoch_day, anchor, user_overrides)
		Format.GROUPS:
			return _resolve_groups(pool, confederation, cup_id, cup_name, world_seed, strength_by_club, current_epoch_day, anchor, user_overrides)
		_:
			return _resolve_knockout(pool, cup_id, cup_name, world_seed, strength_by_club, current_epoch_day, anchor, user_overrides)

# --- KNOCKOUT puro (CONCACAF): cuadro directo desde el primer día ---

static func _resolve_knockout(pool: Array, cup_id: String, cup_name: String, world_seed: int, strength_by_club: Dictionary, current_epoch_day: int, anchor: int, user_overrides: Dictionary = {}) -> Dictionary:
	var bracket := SeasonCalendar.build_continental_bracket(pool, cup_id, cup_name, anchor, _span_to_final(anchor))
	var resolved: Dictionary = SeasonEngine.resolve_cup(bracket, world_seed, strength_by_club, user_overrides, current_epoch_day, true)
	resolved["groups"] = []
	resolved["league_phase"] = []
	return resolved

# --- GRUPOS ida y vuelta (CONMEBOL: hasta 8 de 4; CAF: hasta 4 de 4) ---

## Menos de 2 grupos completos (8 clubes) no alcanza para una fase de
## grupos real — un solo grupo de 4 forzaría a recortar el resto de
## clasificados legítimos solo para completar el múltiplo de 4. Con un
## mundo chico (pocas ligas por confederación fuera de la UEFA) esto pasa
## seguido: mejor un cuadro directo con TODOS los que clasificaron que un
## grupo único a medias descartando clubes.
##
## `max_groups` es solo un TECHO de sanidad, generoso a propósito — el
## tamaño real del pool ya lo decide _FIELD_TARGET/_cap_for (arriba del
## archivo); un techo más bajo acá (como el "2" que tenía CAF antes de
## subirle el CAP a 8 para llegar a su campo real de 16) recortaría en
## silencio un pool ya bien calculado, el mismo bug de fondo que esto
## archivo entero viene arreglando.
static func _resolve_groups(pool: Array, confederation: String, cup_id: String, cup_name: String, world_seed: int, strength_by_club: Dictionary, current_epoch_day: int, anchor: int, user_overrides: Dictionary = {}) -> Dictionary:
	var max_groups: int = 8
	var group_count: int = mini(pool.size() / 4, max_groups)

	if group_count < 2:
		return _resolve_knockout(pool, cup_id, cup_name, world_seed, strength_by_club, current_epoch_day, anchor, user_overrides)

	var field: Array = pool.slice(0, group_count * 4)
	var groups := build_groups(field, group_count, world_seed, strength_by_club, current_epoch_day, anchor, user_overrides)
	var knockout_start: int = anchor + KNOCKOUT_AFTER_PHASE_OFFSET

	# MUNDO VIVO: los octavos NO existen hasta que TERMINÓ la fase de grupos.
	# Antes el cuadro se armaba con clasificados provisorios (pts=0 → orden
	# de siembra) y ya mostraba equipos en octavos con los grupos sin jugar
	# (bug reportado por Wilber).
	if current_epoch_day < knockout_start:
		return {"groups": groups, "league_phase": [], "rounds": [], "cup_id": cup_id, "cup_name": cup_name}

	var advancers: Array = []
	for g in groups:
		for row in (g["standings"] as Array).slice(0, 2):
			advancers.append(String(row["club_id"]))
	var bracket := SeasonCalendar.build_continental_bracket(advancers, cup_id, cup_name, knockout_start, _span_to_final(knockout_start))
	var resolved: Dictionary = SeasonEngine.resolve_cup(bracket, world_seed, strength_by_club, user_overrides, current_epoch_day, true)
	resolved["groups"] = groups
	resolved["league_phase"] = []
	return resolved

## Sembrado por bombos: el bombo 1 son los `group_count` más fuertes, el
## bombo 2 los siguientes, etc. — cada grupo recibe uno de cada bombo, así
## los más fuertes nunca se cruzan entre sí en la fase de grupos (mismo
## criterio que el sorteo real de bombos).
## `windows` (opcional, selecciones — ver SeasonCalendar.remap_to_windows):
## si no está vacío, las fechas de cada jornada se remapean a esas
## ventanas FIFA en vez de la fecha libre que arma build_league_fixtures
## (pensada para calendarios LARGOS de club). Los llamadores de club nunca
## pasan esto, cero cambio de comportamiento para copas de club.
static func build_groups(field: Array, group_count: int, world_seed: int, strength_by_club: Dictionary, current_epoch_day: int, anchor: int, user_overrides: Dictionary = {}, phase_span_days: int = KNOCKOUT_AFTER_PHASE_OFFSET - 12, windows: Array = []) -> Array:
	var group_clubs: Array = []
	for g in range(group_count):
		group_clubs.append([])
	for pot in range(4):
		for g in range(group_count):
			var idx: int = pot * group_count + g
			group_clubs[g].append(field[idx])

	var fake_league := LeagueData.new()
	fake_league.format = LeagueData.FORMAT_DOUBLE_RR   # ida y vuelta, como los grupos reales

	# build_league_fixtures añade su propio LEAGUE_START_OFFSET(35) a la J1;
	# lo compensamos para que la fase de grupos arranque de verdad en
	# `anchor` (día 48) y las 6 jornadas quepan ANTES de knockout_start
	# (anchor+120). Sin esto la J5/J6 caían dentro del cuadro final y no se
	# podían jugar (bug: "no me salen los partidos de fase de grupos").
	var grp_anchor: int = anchor - SeasonCalendar.LEAGUE_START_OFFSET
	var groups: Array = []
	for g in range(group_count):
		var ids: Array = group_clubs[g]
		var fixtures := SeasonCalendar.build_league_fixtures(ids, fake_league, grp_anchor, phase_span_days, SeasonCalendar.CUP_WEEKDAYS)
		if not windows.is_empty():
			fixtures = SeasonCalendar.remap_to_windows(fixtures, windows)
		var standings := group_standings(ids, fixtures, world_seed, strength_by_club, current_epoch_day, g, user_overrides)
		# `fixtures` y `group_index` expuestos para poder JUGAR los partidos
		# del usuario (WorldTickEngine._next_user_continental_fixture).
		groups.append({"name": "Grupo %s" % char(65 + g), "standings": standings,
			"group_index": g, "fixtures": fixtures})
	return groups

## Tabla de un grupo — igual espíritu que LeagueTable.compute, pero con
## su propio namespace de semilla ("G:") para no compartir clave con
## resultados de liga real (aunque nunca coincidirían de verdad: los
## rivales de grupo son de ligas distintas). Sin nombre de club aquí a
## propósito: esta función es pura (solo club_id), quien la llame ya
## tiene el mundo cargado para resolver el nombre real.
static func group_fixture_key(group_index: int, matchday: int, home_id: String, away_id: String) -> String:
	return "G:%d:%d:%s:%s" % [group_index, matchday, home_id, away_id]

static func group_standings(club_ids: Array, fixtures: Array, world_seed: int, strength_by_club: Dictionary, current_epoch_day: int, group_index: int, user_overrides: Dictionary = {}) -> Array:
	var rows: Dictionary = {}
	for cid in club_ids:
		rows[cid] = {"club_id": cid, "pj": 0, "g": 0, "e": 0, "p": 0, "gf": 0, "gc": 0, "pts": 0}

	for fx in fixtures:
		# MUNDO VIVO: solo se juega lo que ya pasó en el calendario. Antes se
		# resolvía la fase de grupos entera de una en el día 1 de la
		# temporada (bug reportado por Wilber).
		if int(fx.get("epoch_day", 0)) > current_epoch_day:
			continue
		var home_id: String = fx["home_club_id"]
		var away_id: String = fx["away_club_id"]
		if home_id == "" or away_id == "":
			continue
		var key: String = group_fixture_key(group_index, int(fx["matchday"]), home_id, away_id)
		var score: Array
		if user_overrides.has(key):
			var s: Array = user_overrides[key].get("score", [0, 0])
			score = [int(s[0]), int(s[1])]
		else:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(key) ^ world_seed
			score = MatchSimulator.simulate(float(strength_by_club.get(home_id, 55)), float(strength_by_club.get(away_id, 55)), rng)
		fx["result"] = score # el mismo dict vive en build_groups()["fixtures"] — así la UI muestra el resultado sin recalcularlo aparte
		_apply_result(rows[home_id], int(score[0]), int(score[1]))
		_apply_result(rows[away_id], int(score[1]), int(score[0]))

	return _sorted_table(rows.values())

# --- FASE DE LIGA "suizo" (UEFA + AFC) ---

static func _swiss_matches_per_team(confederation: String, tier: int) -> int:
	if confederation == Confederations.UEFA and tier == 3:
		return SWISS_MATCHES_MINOR
	return SWISS_MATCHES_MAIN

static func _resolve_swiss(pool: Array, confederation: String, tier: int, cup_id: String, cup_name: String, world_seed: int, strength_by_club: Dictionary, current_epoch_day: int, anchor: int, user_overrides: Dictionary = {}) -> Dictionary:
	var field: Array = pool.slice(0, mini(pool.size(), SWISS_FIELD_CAP))
	var matches_per_team: int = mini(_swiss_matches_per_team(confederation, tier), field.size() - 1)
	var key_prefix: String = "S:%s:%d" % [confederation, tier]
	var league_phase := swiss_table(field, matches_per_team, world_seed, strength_by_club, key_prefix, current_epoch_day, anchor, user_overrides)

	# Los primeros SWISS_KNOCKOUT_FIELD pasan al cuadro final. Con campo
	# lleno (36 -> recorte a 24) eso da EXACTAMENTE 8 byes directos y 16 en
	# playoff previo (potencia de 2 más cercana a 24 es 16), igual que la
	# reforma real: 8 directos a octavos, 9º-24º juegan el playoff previo.
	var swiss_fx: Array = swiss_fixtures(field, matches_per_team, key_prefix, anchor)
	var knockout_start: int = anchor + KNOCKOUT_AFTER_PHASE_OFFSET
	# Igual que en fase de grupos: sin fase de liga terminada, NO hay cuadro.
	if current_epoch_day < knockout_start:
		return {"groups": [], "league_phase": league_phase, "swiss_fixtures": swiss_fx, "rounds": [], "cup_id": cup_id, "cup_name": cup_name}

	var knockout_field: Array = []
	for row in league_phase.slice(0, mini(league_phase.size(), SWISS_KNOCKOUT_FIELD)):
		knockout_field.append(String(row["club_id"]))

	var bracket := SeasonCalendar.build_continental_bracket(knockout_field, cup_id, cup_name, knockout_start, _span_to_final(knockout_start))
	var resolved: Dictionary = SeasonEngine.resolve_cup(bracket, world_seed, strength_by_club, user_overrides, current_epoch_day, true)
	resolved["groups"] = []
	resolved["league_phase"] = league_phase
	resolved["swiss_fixtures"] = swiss_fx
	return resolved

## Tabla única de fase de liga: cada club juega `matches_per_team` rivales
## DISTINTOS (nunca se repiten) — se logra tomando las primeras rondas del
## mismo método del círculo que arma el calendario de una liga normal
## (SeasonCalendar.build_league_fixtures), cortado antes de completar la
## vuelta entera.
## Recorre el emparejamiento del suizo (mismo algoritmo que swiss_table)
## y devuelve la lista de partidos [{round, epoch_day, home, away, key}].
static func swiss_fixtures(field: Array, matches_per_team: int, key_prefix: String, anchor: int, phase_span_days: int = KNOCKOUT_AFTER_PHASE_OFFSET) -> Array:
	var teams: Array = field.duplicate()
	if teams.size() % 2 == 1:
		teams.append("")
	var n: int = teams.size()
	var half: int = n / 2
	var rot: Array = teams.duplicate()
	var out: Array = []
	for r in range(matches_per_team):
		var round_day: int = anchor + int(round(float(r + 1) * float(phase_span_days) / float(matches_per_team + 1)))
		for i in range(half):
			var a: String = rot[i]
			var b: String = rot[n - 1 - i]
			if a == "" or b == "":
				continue
			var home: String = a
			var away: String = b
			if i == 0 and r % 2 == 1:
				home = b
				away = a
			out.append({
				"round": r, "epoch_day": round_day, "home": home, "away": away,
				"key": "%s:%d:%s:%s" % [key_prefix, r, home, away],
			})
		var last: String = rot.pop_back()
		rot.insert(1, last)
	return out

static func swiss_table(field: Array, matches_per_team: int, world_seed: int, strength_by_club: Dictionary, key_prefix: String, current_epoch_day: int = 1073741824, anchor: int = 0, user_overrides: Dictionary = {}, phase_span_days: int = KNOCKOUT_AFTER_PHASE_OFFSET) -> Array:
	var fixtures: Array = swiss_fixtures(field, matches_per_team, key_prefix, anchor, phase_span_days)
	return score_fixtures_to_table(field, fixtures, world_seed, strength_by_club, current_epoch_day, user_overrides)

## Puntúa una lista de fixtures YA ARMADA (home/away/key/epoch_day) — se
## separó de swiss_table() (12-sep, selecciones: las fechas de
## QualifyingEngine se remapean a ventanas FIFA reales DESPUÉS de armar
## los fixtures, ver SeasonCalendar.remap_to_windows) para poder puntuar
## esa lista remapeada en vez de la que arma swiss_fixtures() con fechas
## libres. swiss_table() sigue siendo el camino de club, sin cambios.
static func score_fixtures_to_table(field: Array, fixtures: Array, world_seed: int, strength_by_club: Dictionary, current_epoch_day: int, user_overrides: Dictionary = {}) -> Array:
	var rows: Dictionary = {}
	for cid in field:
		rows[cid] = {"club_id": cid, "pj": 0, "g": 0, "e": 0, "p": 0, "gf": 0, "gc": 0, "pts": 0}

	for fx in fixtures:
		if int(fx["epoch_day"]) > current_epoch_day:
			continue
		var home: String = String(fx["home"])
		var away: String = String(fx["away"])
		var key: String = String(fx["key"])
		var score: Array
		if user_overrides.has(key):
			var s: Array = user_overrides[key].get("score", [0, 0])
			score = [int(s[0]), int(s[1])]
		else:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(key) ^ world_seed
			score = MatchSimulator.simulate(float(strength_by_club.get(home, 55)), float(strength_by_club.get(away, 55)), rng)
		fx["result"] = score # mismo dict que vive en resolved["fixtures"] — la UI lee esto en vez de recalcular (mismo criterio que group_standings())
		_apply_result(rows[home], int(score[0]), int(score[1]))
		_apply_result(rows[away], int(score[1]), int(score[0]))

	return _sorted_table(rows.values())

static func _sorted_table(rows: Array) -> Array:
	var table: Array = rows
	table.sort_custom(func(a, b):
		if a["pts"] != b["pts"]:
			return a["pts"] > b["pts"]
		var a_dg: int = a["gf"] - a["gc"]
		var b_dg: int = b["gf"] - b["gc"]
		if a_dg != b_dg:
			return a_dg > b_dg
		return String(a["club_id"]) < String(b["club_id"])
	)
	for i in range(table.size()):
		table[i]["pos"] = i + 1
		table[i]["dg"] = table[i]["gf"] - table[i]["gc"]
	return table

static func _apply_result(row: Dictionary, gf: int, gc: int) -> void:
	row["pj"] += 1
	row["gf"] += gf
	row["gc"] += gc
	if gf > gc:
		row["g"] += 1
		row["pts"] += 3
	elif gf == gc:
		row["e"] += 1
		row["pts"] += 1
	else:
		row["p"] += 1
