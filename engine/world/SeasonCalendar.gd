extends RefCounted
class_name SeasonCalendar

## Generación DETERMINISTA del calendario de una temporada: fixtures de
## liga (método del círculo, respetando el formato de la liga) y cuadro
## de copa eliminatoria.
##
## No simula resultados ni progresa el cuadro de copa — eso es Fase 5.
## Aquí solo se produce la estructura del calendario, que se persiste en
## el save (SaveManager, clave `season`, schema v3).
##
## Fechas en epoch_day ABSOLUTO (mismo contador que WorldTickEngine).
## `season_start_epoch_day` es el día en que arranca la temporada (0 para
## una carrera nueva); las temporadas siguientes lo rebasan.

## Temporada de 365 días exactos, julio -> junio — pedido explícito de
## Wilber: arranca en julio con la ventana de fichajes, termina en junio
## con las finales de copas continentales (ver ContinentalEngine
## .CONTINENTAL_FINAL_TARGET_DAY). WorldTickEngine usa esto para el
## rollover: la temporada SIEMPRE dura exactamente este tanto, nunca "lo
## que tarde en jugarse" — así todo (liga, copas, continentales, las DOS
## ventanas) tiene un cupo de días fijo y predecible.
const SEASON_TOTAL_DAYS := 365

## Parte 91n: cuando el Mundial vivía al FINAL de la temporada
## (WorldCupEngine.GROUP_START_OFFSET=349), casi no quedaba margen para
## que el torneo tuviera ritmo real, así que la temporada se estiraba
## WC_YEAR_EXTRA_DAYS. Parte 91p movió el Mundial al FRENTE de la
## temporada (ver SeasonCalendar.world_cup_blackout_for_season()) — con
## eso vuelve a caber cómodo en los 365 días de siempre, así que esto
## quedó en 0. Se deja la función (en vez de volver a escribir
## "+SEASON_TOTAL_DAYS" a mano en 4 lugares de WorldTickEngine.gd) por si
## algún ajuste futuro de ritmo vuelve a necesitar estirar la temporada
## de Mundial — sigue siendo el ÚNICO lugar que lo sabría.
const WC_YEAR_EXTRA_DAYS := 0

## Cuántos días dura la temporada que arranca en `start_year` — hoy
## siempre SEASON_TOTAL_DAYS (ver WC_YEAR_EXTRA_DAYS de arriba). Nunca se
## llama con el año de una copa CONTINENTAL de selecciones (esas siguen
## con el ritmo de siempre, sin tocar por ahora — ver Parte 91n/91p en
## memoria).
static func season_length_days(start_year: int) -> int:
	if WorldCupEngine.is_wc_year(start_year):
		return SEASON_TOTAL_DAYS + WC_YEAR_EXTRA_DAYS
	return SEASON_TOTAL_DAYS

const LEAGUE_START_OFFSET := 35        # días desde el inicio de temporada hasta la J1
const SEASON_SPAN_DAYS := 280          # ventana ago -> may aprox., liga + copa doméstica
const MIN_DAYS_BETWEEN_MATCHDAYS := 3
const CUP_FIRST_ROUND_OFFSET := 14     # la ronda inicial de copa cae poco después de la J1

## Días de la semana de cada tipo de partido (0=Lun .. 6=Dom) — pedido
## explícito de Wilber: liga SOLO sábado y domingo, copas (doméstica Y
## continental) de martes a jueves. Antes la liga incluía también el
## viernes, que nunca pidió — corregido. El día "crudo" que reparte el
## calendario se ajusta al día permitido más cercano (ver
## _snap_to_weekdays).
const LEAGUE_WEEKDAYS := [5, 6]        # sábado, domingo
const CUP_WEEKDAYS := [1, 2, 3]        # martes, miércoles, jueves

## Pretemporada: ventana de fichajes + amistosos, los dos ANTES de
## LEAGUE_START_OFFSET(35) para no pisarse con la liga. TRANSFER_WINDOW_DAYS
## es la duración que puede consultar la UI
## (WorldTickEngine.is_transfer_window_open()); la decisión de
## renovar/fichar del USUARIO ya existe aparte, en el rollover de
## temporada (WorldTickEngine._begin_season_rollover()).
##
## MID_SEASON_TRANSFER_WINDOW_OFFSET: la segunda ventana ("a mitad de
## temporada", pedido explícito) — día 184 desde el arranque en julio cae
## en enero (31+31+30+31+30+31 = 184: jul+ago+sep+oct+nov+dic), el mismo
## mes en que abre el mercado de invierno real.
const TRANSFER_WINDOW_DAYS := 21
const MID_SEASON_TRANSFER_WINDOW_OFFSET := 184
const FRIENDLY_COUNT := 3              # "entre 2 o 3" — fijo en 3, simple y determinista
const FRIENDLY_FIRST_DAY_OFFSET := 7
const FRIENDLY_SPACING_DAYS := 7

## Ventanas FIFA de la temporada (selecciones nacionales — Fase 1, ver
## QualifyingEngine.gd): durante estos días el CLUB no juega liga ni copa
## doméstica ("el calendario de club se pausa", confirmado con Wilber en
## el scoping). Offsets desde season_start_epoch_day autorados al ritmo
## real (septiembre/octubre/noviembre/marzo/junio) — nunca una licencia de
## calendario oficial, mismo criterio que el resto de fechas del juego.
## La ventana de junio (día 340) cae ANTES de
## ContinentalEngine.CONTINENTAL_FINAL_TARGET_DAY(350) a propósito, para
## no pisar la final continental de clubes.
const INTERNATIONAL_WINDOW_DAYS := 10
const INTERNATIONAL_WINDOW_OFFSETS := [67, 97, 128, 246, 340]

## Mundial/copa continental de SELECCIONES: en años de torneo, la liga y
## copa doméstica del PAÍS de esa selección se ACORTAN a esto (en vez de
## SEASON_SPAN_DAYS) para que la última jornada caiga bien antes de que
## arranque el bloque del torneo (día 250, ver WorldCupEngine/
## NationalCupEngine.GROUP_START_OFFSET) — de lo contrario la última tanda
## de jornadas (normalmente ~día 308-315 con SEASON_SPAN_DAYS=280) caía
## DENTRO del Mundial (hallazgo de la Parte 82/Item 1: ahí se intentó
## bloquear el calendario de club en vez de acortarlo, y se revirtió por
## el mismo motivo — bloquear le hacía perder días a jornadas ya en curso;
## acortar el span ANTES de generar fixtures no tiene ese problema).
## 205 dejar el último partido ~día 240 (35+205), con margen antes del 250.
## Offsets/años DUPLICADOS a propósito de WorldCupEngine/NationalCupEngine
## (mismo criterio que el resto de este archivo, ver
## ContinentalEngine.CONTINENTAL_FINAL_TARGET_DAY más arriba).
const TOURNAMENT_YEAR_SEASON_SPAN_DAYS := 205
const WORLD_CUP_BASE_YEAR := 2026
const NATIONAL_CUP_BASE_YEAR := {
	"UEFA": 2024, "CONMEBOL": 2025, "CONCACAF": 2027, "AFC": 2024, "CAF": 2025,
}

static func _is_world_cup_year(year: int) -> bool:
	return year >= WORLD_CUP_BASE_YEAR and (year - WORLD_CUP_BASE_YEAR) % 4 == 0

static func _is_national_cup_year(confederation: String, year: int) -> bool:
	var base: int = int(NATIONAL_CUP_BASE_YEAR.get(confederation, -9999))
	return base >= 0 and year >= base and (year - base) % 4 == 0

## `true` si `start_year` es año de Mundial (global) o de copa continental
## de selecciones PARA la confederación del país de esta liga — decide si
## el calendario de club de esa liga usa TOURNAMENT_YEAR_SEASON_SPAN_DAYS
## en vez de SEASON_SPAN_DAYS.
static func is_national_tournament_year(confederation: String, start_year: int) -> bool:
	return _is_world_cup_year(start_year) or _is_national_cup_year(confederation, start_year)

## Bloqueo de calendario de CLUB durante el Mundial de esta temporada —
## Parte 91p, pedido de Wilber: "que el mundial inicie en el año y
## momento que le toca". Antes el Mundial vivía al FINAL de la temporada
## (día 349, ~11 meses después de arrancar) — un Mundial que su propio
## nombre decía "<año de esta temporada>" pero se jugaba, en fechas
## reales, en JUNIO DEL AÑO SIGUIENTE. Movido al frente (ver
## WorldCupEngine.GROUP_START_OFFSET): arranca a los pocos días de julio
## real, el mismo mes/año en que arranca la temporada. La liga y la copa
## doméstica simplemente ESPERAN su turno con el mismo mecanismo de
## blackout que ya usan el receso de fichajes y las ventanas FIFA — nada
## nuevo, solo un bloqueo más grande al principio en vez de mitad de
## temporada. Referencia directa a WorldCupEngine (no duplicado como
## _is_world_cup_year/WORLD_CUP_BASE_YEAR de arriba, que son de antes de
## confirmar que esto compila y corre bien sin ciclo real): esos offsets
## viven en un solo lugar (WorldCupEngine.gd), nunca dos copias que
## puedan desincronizarse. {} si `start_year` no es año de Mundial.
static func world_cup_blackout_for_season(season_start_epoch_day: int, start_year: int) -> Array:
	if not WorldCupEngine.is_wc_year(start_year):
		return []
	var group_start: int = season_start_epoch_day + WorldCupEngine.GROUP_START_OFFSET
	var knockout_start: int = season_start_epoch_day + WorldCupEngine.KNOCKOUT_OFFSET
	var final_day: int = knockout_start + WorldCupEngine.SPAN_TO_FINAL
	return [[group_start, final_day + 5]] # +5 días de aire tras la final antes de que arranque cualquier cosa de club

## Rangos [start, end] (epoch_day absoluto) de las ventanas FIFA de la
## temporada que arranca en `season_start_epoch_day`. Fase 1: solo abre el
## hueco en el calendario de CLUB (build_season, abajo); el propio partido
## de selección del usuario y el tick que lo dispara son Fase 2
## (WorldTickEngine._tick_international_window, todavía no existe).
static func international_windows_for_season(season_start_epoch_day: int) -> Array:
	var out: Array = []
	for offset in INTERNATIONAL_WINDOW_OFFSETS:
		var start: int = season_start_epoch_day + offset
		out.append([start, start + INTERNATIONAL_WINDOW_DAYS - 1])
	return out

## Todas las ventanas FIFA (de CUALQUIER temporada, no solo la actual) que
## caen dentro de [range_start, range_end] — para selecciones (Fase 1/6):
## una eliminatoria dura ~2 años, cruza varias temporadas de club.
## `known_season_start`: un season_start_epoch_day REAL (el de la
## temporada actual, siempre disponible) usado como ancla; se proyecta
## hacia atrás/adelante asumiendo temporadas de SEASON_TOTAL_DAYS exactos
## — una decisión de contrato pendiente puede correr un rollover real 1-2
## días, pero no lo bastante como para que esto importe (BUG real
## encontrado en la Parte 81: antes de esto, QualifyingEngine repartía sus
## fechas parejo por todo el ciclo de 700 días sin mirar estas ventanas —
## 85% de los partidos de selección de una sim de 20 temporadas cayeron
## FUERA de una ventana FIFA real).
static func international_windows_in_range(range_start: int, range_end: int, known_season_start: int) -> Array:
	var out: Array = []
	# El salto inicial hacia atrás usa el ritmo FIJO de siempre (nunca de
	# más: un año de Mundial solo AGREGA días, así que este salto llega
	# como mucho un poco antes de la cuenta real — inofensivo, el while
	# de abajo lo compensa caminando temporada por temporada real).
	var k: int = int(floor(float(range_start - known_season_start) / float(SEASON_TOTAL_DAYS))) - 1
	var season_start: int = known_season_start + k * SEASON_TOTAL_DAYS
	while season_start <= range_end:
		for w in international_windows_for_season(season_start):
			if int(w[1]) >= range_start and int(w[0]) <= range_end:
				out.append(w)
		# Paso real de ESTA temporada (365, o 365+WC_YEAR_EXTRA_DAYS si es
		# año de Mundial) — sin esto, un Mundial de por medio corre TODAS
		# las ventanas FIFA proyectadas de ahí en adelante.
		season_start += season_length_days(CalendarUtils.season_start_year(season_start))
	return out

## Reasigna los "epoch_day"/"round"/"matchday" de `fixtures` (ya armados
## por swiss_fixtures()/build_league_fixtures(), con fecha LIBRE pensada
## para calendarios largos de club) a días dentro de `windows` — agrupa
## por ronda (campo "round" o "matchday", lo que tenga) y reparte las
## rondas entre las ventanas disponibles EN BLOQUES CONSECUTIVOS (jornada
## 1+2 a la ventana 0, jornada 3+4 a la ventana 1, etc.), nunca por
## módulo. `windows`: Array de [start, end] (ver
## international_windows_for_season/international_windows_in_range).
##
## BUG REAL arreglado acá (Parte 91x, pedido de Wilber: "los dos días de
## partido de fecha FIFA no deberían ser días seguidos" + "salen con el
## nombre del mismo partido"): la versión anterior repartía por MÓDULO
## (ronda i -> ventana i % N), así que cuando había más rondas que
## ventanas (típico en CONMEBOL: 18 jornadas de ida/vuelta contra solo 9
## ventanas del ciclo) la ronda que volvía a caer en la MISMA ventana era
## la i+N-ésima — y por cómo arma los cruces `swiss_fixtures()` (método
## del círculo), esa ronda es EXACTAMENTE la vuelta del mismo cruce que
## la ida ya jugada en esa ventana (mismo rival, comprobado con
## `FifaWindowSpacingProbe`: Argentina aparecía "vs Venezuela" dos días
## seguidos). Ahora cada ventana recibe un BLOQUE de rondas consecutivas
## del calendario (jornada N, N+1, ...) — rondas consecutivas SIEMPRE son
## rivales distintos (nadie juega dos veces seguidas contra el mismo
## equipo en un round-robin), que es justo cómo funciona una fecha FIFA
## real de dos partidos. Además el offset dentro de la ventana ya no
## arranca en el día 0 (pegado al último partido de club antes del
## blackout) — se reparte lejos de los dos bordes.
static func remap_to_windows(fixtures: Array, windows: Array) -> Array:
	if windows.is_empty() or fixtures.is_empty():
		return fixtures
	var by_round: Dictionary = {}
	for fx in fixtures:
		var r = fx.get("round", fx.get("matchday", 0))
		if not by_round.has(r):
			by_round[r] = []
		by_round[r].append(fx)
	var round_keys: Array = by_round.keys()
	round_keys.sort()
	var w_count: int = windows.size()
	var rounds_per_window: int = maxi(1, int(ceil(float(round_keys.size()) / float(w_count))))
	var out: Array = []
	for i in range(round_keys.size()):
		var window_idx: int = mini(i / rounds_per_window, w_count - 1)
		var slot_in_window: int = i % rounds_per_window
		var w: Array = windows[window_idx]
		var w_start: int = int(w[0])
		var w_len: int = maxi(int(w[1]) - w_start, 0)
		var offset: int = int(round(float(slot_in_window + 1) * float(w_len) / float(rounds_per_window + 1)))
		offset = clampi(offset, 0, w_len)
		var day: int = w_start + offset
		for fx in by_round[round_keys[i]]:
			var fx2: Dictionary = (fx as Dictionary).duplicate()
			fx2["epoch_day"] = day
			out.append(fx2)
	return out

## Punto de entrada: arma el dict `season` completo. `user_club_id` +
## `world_seed` son solo para los amistosos (rivales y fecha deterministas
## de esta temporada) — la liga y la copa no los necesitan.
static func build_season(world: Dictionary, league_id: int, season_start_epoch_day: int, start_year: int, user_club_id: String, world_seed: int, previous_rankings: Dictionary = {}) -> Dictionary:
	var league: LeagueData = null
	for lg in world.get("leagues", []):
		if lg.league_id == league_id:
			league = lg
			break
	if league == null:
		push_error("SeasonCalendar: liga %d inexistente" % league_id)
		return {}

	var clubs: Array = world.get("clubs_by_league", {}).get(league_id, [])
	var club_ids: Array = clubs.map(func(c): return c.club_id)

	# Receso real del mercado de invierno: ni liga ni copa doméstica
	# programan partidos esos 21 días (pedido de Wilber: "en época de
	# fichajes no se juega fútbol, son vacaciones"). Acá SÍ es seguro
	# calcularlo desde season_start_epoch_day — este es el único punto
	# donde ese valor es de verdad el arranque real de temporada.
	# Recesos de CLUB esta temporada: el mercado de invierno + las ventanas
	# FIFA (selecciones nacionales, Fase 1) — ninguno de los dos programa
	# liga ni copa doméstica esos días (pedido de Wilber para el mercado;
	# mismo criterio real para las fechas FIFA, confirmado en el scoping de
	# selecciones: "el calendario de club se pausa durante una fecha FIFA").
	var winter_blackout: Array = _mid_season_blackout(season_start_epoch_day)
	var blackouts: Array = [winter_blackout]
	blackouts.append_array(international_windows_for_season(season_start_epoch_day))
	blackouts.append_array(world_cup_blackout_for_season(season_start_epoch_day, start_year))
	# Año de Mundial/copa continental de selecciones para el país de esta
	# liga: calendario de club MÁS CORTO (ver TOURNAMENT_YEAR_SEASON_SPAN_DAYS)
	# para que la última jornada no se pise con el torneo — Y con menos
	# aire entre jornadas (Parte 91, a pedido de Wilber): las ligas reales
	# SÍ se comprimen así antes de un Mundial (más partidos entre semana
	# seguidos que en una temporada normal, no solo ocasionales). Sigue
	# sin haber NUNCA 2 jornadas el mismo fin de semana — eso lo sigue
	# garantizando build_league_fixtures igual, con cualquier mínimo.
	var confederation: String = Confederations.confederation_of(league.country)
	var is_tournament_year: bool = is_national_tournament_year(confederation, start_year)
	var span: int = TOURNAMENT_YEAR_SEASON_SPAN_DAYS if is_tournament_year else SEASON_SPAN_DAYS
	var min_gap: int = TOURNAMENT_YEAR_MIN_LEAGUE_MATCHDAY_GAP if is_tournament_year else MIN_LEAGUE_MATCHDAY_GAP
	var fixtures := build_league_fixtures(club_ids, league, season_start_epoch_day, span, LEAGUE_WEEKDAYS, blackouts, min_gap)
	var cup: Dictionary = {}
	if league.has_domestic_cup:
		# La copa doméstica es del PAÍS, no de una sola división — la Copa
		# del Rey/FA Cup/etc. reales cruzan todas las categorías, nunca son
		# solo de la máxima. Ver country_club_ids().
		cup = build_cup_bracket(country_club_ids(world, league.country), league, season_start_epoch_day, blackouts, span)
	var friendlies := build_friendlies(world, user_club_id, season_start_epoch_day, world_seed)

	# Ranking de países por confederación que decide los cupos continentales
	# de ESTA temporada (ver ContinentalEngine/CoefficientEngine) — el de la
	# temporada anterior si el que llama lo pasa (rollover normal), o el de
	# arranque por reputación si no (carrera nueva, o mundo importado que
	# todavía no tiene uno propio).
	var rankings: Dictionary = previous_rankings if not previous_rankings.is_empty() else CoefficientEngine.bootstrap_rankings(world)

	return {
		"start_year": start_year,
		"season_start_epoch_day": season_start_epoch_day,
		"current_epoch_day": season_start_epoch_day,
		"league_id": league_id,
		"league_fixtures": fixtures,
		"cup": cup,
		"friendlies": friendlies,
		"confederation_rankings": rankings,
		"results": {},   # reservado para Fase 5 (resultados + clasificación)
	}

## 2-3 amistosos de pretemporada del club del usuario, contra rivales al
## azar (determinista) de cualquier liga del mundo — solo el usuario los
## juega, nunca se persiste ni afecta tabla/objetivos (ver SeasonEngine,
## namespace de clave "F:").
static func build_friendlies(world: Dictionary, user_club_id: String, season_start_epoch_day: int, world_seed: int) -> Array:
	if user_club_id == "":
		return []
	var candidates: Array = []
	for arr in world.get("clubs_by_league", {}).values():
		for c in arr:
			if c.club_id != user_club_id:
				candidates.append(c.club_id)
	if candidates.is_empty():
		return []

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("friendlies:%d:%s" % [season_start_epoch_day, user_club_id]) ^ world_seed
	var friendlies: Array = []
	for i in range(FRIENDLY_COUNT):
		var opponent: String = candidates[rng.randi() % candidates.size()]
		var day: int = season_start_epoch_day + FRIENDLY_FIRST_DAY_OFFSET + i * FRIENDLY_SPACING_DAYS
		var is_home: bool = i % 2 == 0
		friendlies.append({
			"competition": "friendly",
			"index": i,
			"epoch_day": day,
			"home_club_id": user_club_id if is_home else opponent,
			"away_club_id": opponent if is_home else user_club_id,
		})
	return friendlies

# --- Liga: round-robin por el método del círculo ---

## `span_days`: ventana en la que se reparten las jornadas — la liga
## doméstica usa SEASON_SPAN_DAYS (default); los grupos de una copa
## continental (ver ContinentalEngine.build_groups) pasan una ventana
## bien más corta, la de la fase de grupos nada más.
## `blackout`: LISTA de rangos [start, end] de días en los que NO se puede
## caer una jornada (receso real del mercado de invierno + ventanas FIFA,
## ver _in_blackout) — opcional, SOLO lo pasa el llamador que arma la liga
## DOMÉSTICA real (build_season), donde `season_start_epoch_day` es de
## verdad el arranque de temporada. Los
## llamados internos de ContinentalEngine (fase de grupos) usan este
## mismo parámetro con un ANCLA LOCAL distinta (grp_anchor, compensada
## para que la fase de grupos quepa antes del cuadro final) — calcular el
## receso desde ESE valor daría una ventana desalineada, así que esos
## llamados no lo pasan (quedan sin receso, que es lo correcto: ver el
## comentario de _build_groups sobre por qué grp_anchor no es el inicio
## real de temporada).
## `min_matchday_gap`: mínimo de días entre 2 jornadas de LIGA — default
## MIN_LEAGUE_MATCHDAY_GAP(5), pero build_season() pasa un mínimo más
## chico en año de Mundial/copa continental (Parte 91): las ligas reales
## SÍ comprimen así antes de un torneo grande (más partidos entre semana
## seguidos, no solo ocasionales) — sigue sin haber NUNCA 2 jornadas el
## mismo fin de semana, solo se acepta un poco menos de aire entre medio.
static func build_league_fixtures(club_ids: Array, league: LeagueData, season_start_epoch_day: int, span_days: int = SEASON_SPAN_DAYS, weekdays: Array = LEAGUE_WEEKDAYS, blackout: Array = [], min_matchday_gap: int = MIN_LEAGUE_MATCHDAY_GAP) -> Array:
	var teams: Array = club_ids.duplicate()
	if teams.size() % 2 == 1:
		teams.append("")   # equipo fantasma: quien lo enfrenta, descansa

	var n: int = teams.size()
	var half: int = n / 2
	var single_rounds: Array = []   # cada entrada: Array de [home_id, away_id]

	var rot: Array = teams.duplicate()
	for r in range(n - 1):
		var pairs: Array = []
		for i in range(half):
			var a: String = rot[i]
			var b: String = rot[n - 1 - i]
			if a == "" or b == "":
				continue
			var home := a
			var away := b
			# regla estándar: invertir SOLO el emparejamiento del equipo
			# fijo en rondas impares, para equilibrar localías.
			if i == 0 and r % 2 == 1:
				home = b
				away = a
			pairs.append([home, away])
		single_rounds.append(pairs)
		# rotación del círculo: rot[0] fijo, el resto gira.
		var last: String = rot.pop_back()
		rot.insert(1, last)

	var mult: int = league.rounds_multiplier()
	var all_rounds: Array = []
	for cycle in range(mult):
		for r in range(single_rounds.size()):
			var pairs: Array = single_rounds[r]
			if cycle % 2 == 1:
				var flipped: Array = []
				for p in pairs:
					flipped.append([p[1], p[0]])   # vuelta: se invierte la localía
				all_rounds.append(flipped)
			else:
				all_rounds.append(pairs.duplicate())

	var total_matchdays: int = all_rounds.size()

	# Plan de jornadas CORTAS vs LARGAS, calculado de antemano (Parte 88,
	# segunda vuelta) — reemplaza dos intentos reactivos que no alcanzaban
	# a sostener las dos reglas a la vez ("nunca menos de
	# MIN_LEAGUE_MATCHDAY_GAP días entre 2 jornadas de liga", pedido de
	# Wilber tras encontrar 2 partidos el mismo fin de semana, MÁS "la
	# liga entra en el presupuesto de días de la temporada", Parte 84:
	# terminar antes de que arranque el Mundial en años de torneo).
	# LARGA = próximo fin de semana (WEEKLY_GAP=7, el ritmo de SIEMPRE).
	# CORTA = entre semana, a MIN_LEAGUE_MATCHDAY_GAP días de la anterior.
	# Si TODAS las jornadas fueran largas, harían falta
	# `n_gaps * WEEKLY_GAP` días — si eso no entra en `span_days`, hacen
	# falta `n_short_gaps` jornadas cortas (cada una ahorra
	# WEEKLY_GAP-MIN_LEAGUE_MATCHDAY_GAP días) para que el total SÍ entre.
	# `n_short_gaps` sale de una cuenta, no de prueba y error, así que el
	# resultado es EXACTO: en una temporada normal da 0 (ninguna jornada
	# entre semana, cero cambio de comportamiento); en una comprimida da
	# justo las que hacen falta, ni una de más ni una de menos — y
	# repartidas PAREJO en toda la temporada (mismo patrón de reparto
	# parejo que remap_to_windows en este archivo), no todas juntas al
	# final.
	var n_gaps: int = maxi(total_matchdays - 1, 0)
	# LARGA = una semana real (locks al mismo día que la anterior) — con
	# el mismo colchón que ya tenía la fórmula de siempre
	# (span_days/total_matchdays, ~7.37 para una temporada de 280 días).
	# `maxf` con 7.0: una jornada "larga" nunca puede ser menos de una
	# semana real, para eso están las cortas.
	var weekly_gap: float = maxf(7.0, float(span_days) / float(maxi(total_matchdays, 1)))
	var short_gap_savings: float = weekly_gap - float(min_matchday_gap)
	# CAUSA REAL del límite que quedó abierto en la Parte 89: esta cuenta
	# nunca restaba los días de receso (mercado de invierno, 21 días +
	# hasta 5 ventanas FIFA de 10) del presupuesto disponible — asumía que
	# los `span_days` enteros estaban libres para partidos, cuando en
	# realidad una buena parte están bloqueados. Sin esto, `n_short_gaps`
	# salía sistemáticamente BAJO: la liga entraba en el presupuesto
	# "sobre el papel" pero cualquier jornada que cayera cerca de un
	# receso se empujaba igual, y la temporada terminaba días (o semanas)
	# más tarde de lo planeado.
	# Ventana de recesos generosa (span_days + 90, no span_days a secas):
	# si la temporada llega MUY comprimida, el arrastre de un receso puede
	# empujar el final más allá de `span_days` y toparse con OTRO receso
	# que quedaba justo afuera de la ventana original — contarlo de más acá
	# es gratis (como mucho, alguna jornada entre semana de más de las
	# estrictamente necesarias), contarlo de menos es lo que dejaba el
	# cálculo corto.
	var range_start: int = season_start_epoch_day + LEAGUE_START_OFFSET
	var blackout_days: int = _blackout_days_in_range(blackout, range_start, range_start + span_days + 90)
	var available_span: int = maxi(span_days - blackout_days, n_gaps * min_matchday_gap)
	var excess: float = float(n_gaps) * weekly_gap - float(available_span)
	var n_short_gaps: int = 0
	if excess > 0.0 and n_gaps > 0 and short_gap_savings > 0.0:
		n_short_gaps = mini(n_gaps, ceili(excess / short_gap_savings))

	# Objetivo ABSOLUTO acumulado desde el arranque (suma de los gaps
	# planeados, NUNCA desde "la jornada anterior tal como quedó de
	# verdad") — a propósito: si una jornada se empuja por un receso
	# (mercado de invierno, ventana FIFA), ese empujón NO se arrastra a
	# las jornadas siguientes (que apuntan a su propio objetivo absoluto,
	# independiente), solo se corrige localmente con `earliest`. Encadenar
	# el objetivo a la jornada anterior REAL se probó y hacía que un solo
	# empujón por blackout se sumara para siempre en cada jornada
	# siguiente — la temporada terminaba mucho más tarde de lo esperado.
	var fixtures: Array = []
	var day0: int = _snap_to_weekdays(season_start_epoch_day + LEAGUE_START_OFFSET, weekdays, season_start_epoch_day, blackout)
	for pair0 in all_rounds[0]:
		fixtures.append({
			"competition": "league", "matchday": 1, "epoch_day": day0,
			"home_club_id": pair0[0], "away_club_id": pair0[1],
		})
	var absolute_target: float = float(day0)
	var prev_day: int = day0
	for gap_i in range(1, total_matchdays):
		# Reparto parejo de `n_short_gaps` entre los `n_gaps` saltos
		# totales — el salto gap_i es "corto" si cruza un múltiplo entero
		# al repartir n_short_gaps proporcionalmente entre 1..n_gaps.
		var is_short: bool = n_short_gaps > 0 and (gap_i * n_short_gaps) / n_gaps > ((gap_i - 1) * n_short_gaps) / n_gaps
		absolute_target += float(min_matchday_gap) if is_short else weekly_gap
		var earliest: int = prev_day + min_matchday_gap
		var target: int = maxi(int(round(absolute_target)), earliest)
		var day: int
		if is_short:
			# Entre semana O fin de semana, lo que quede más cerca del
			# objetivo — si por calendario un fin de semana cae justo ahí,
			# se aprovecha (no hace falta forzar entre semana si no hace
			# falta).
			day = _nearest_allowed(target, weekdays + MIDWEEK_DAYS, earliest, blackout)
		else:
			day = _snap_to_weekdays(target, weekdays, prev_day, blackout)
			if day < earliest:  # el objetivo cayó bien pegado al mínimo (arranque de temporada, o un receso justo antes) — no debería pasar casi nunca, pero por las dudas
				day = _nearest_allowed(target, weekdays, earliest, blackout)
		prev_day = day
		for pair in all_rounds[gap_i]:
			fixtures.append({
				"competition": "league",
				"matchday": gap_i + 1,
				"epoch_day": day,
				"home_club_id": pair[0],
				"away_club_id": pair[1],
			})
	return fixtures

## Cuántos días de `blackout` (recesos: mercado de invierno, ventanas
## FIFA) caen dentro de [range_start, range_end] — recortando cada rango
## a la intersección. Usado por build_league_fixtures para saber cuánto
## presupuesto de días de VERDAD hay disponible, no los `span_days`
## enteros (ver comentario de `available_span` ahí).
static func _blackout_days_in_range(blackout: Array, range_start: int, range_end: int) -> int:
	var total: int = 0
	for range_pair in blackout:
		var r: Array = range_pair
		if r.size() != 2:
			continue
		var s: int = maxi(int(r[0]), range_start)
		var e: int = mini(int(r[1]), range_end)
		if e >= s:
			total += e - s + 1
	return total

## Ventana de mercado de INVIERNO (mitad de temporada) como receso real:
## ni liga ni copa (doméstica o continental) programan partidos esos 21
## días — pedido explícito de Wilber ("en época de fichajes no se juega
## fútbol, son vacaciones"). La ventana de VERANO (días 0-21) ya no
## necesita esto: la liga arranca recién en LEAGUE_START_OFFSET(35), así
## que nunca se solapan.
static func _mid_season_blackout(season_start_epoch_day: int) -> Array:
	var start: int = season_start_epoch_day + MID_SEASON_TRANSFER_WINDOW_OFFSET
	return [start, start + TRANSFER_WINDOW_DAYS - 1]

## `blackout`: LISTA de rangos [start, end] (nunca un solo par suelto desde
## la Fase 1 de selecciones — antes solo existía el receso de fichajes de
## invierno; ahora también las ventanas FIFA, ver
## international_windows_for_season). `true` si `day` cae DENTRO de
## cualquiera de los rangos.
static func _in_blackout(day: int, blackout: Array) -> bool:
	for range_pair in blackout:
		var r: Array = range_pair
		if r.size() == 2 and day >= int(r[0]) and day <= int(r[1]):
			return true
	return false

## Ajusta `raw_day` al día permitido (por día de la semana) más cercano
## dentro de ±3; si eso cae en o antes de `after_day` (para no pisar ni
## invertir respecto al partido anterior) O dentro de `blackout` (receso
## del mercado de invierno y/o ventanas FIFA — ver _in_blackout), empuja al
## siguiente día permitido posterior. `allowed` nunca es vacío, así que
## siempre termina.
static func _snap_to_weekdays(raw_day: int, allowed: Array, after_day: int, blackout: Array = []) -> int:
	var day: int = raw_day
	for delta in [0, 1, -1, 2, -2, 3, -3]:
		if CalendarUtils.weekday_of_epoch_day(raw_day + delta) in allowed:
			day = raw_day + delta
			break
	while day <= after_day or _in_blackout(day, blackout):
		day += 1
		while not (CalendarUtils.weekday_of_epoch_day(day) in allowed):
			day += 1
	return day

## Entre semana (martes/miércoles/jueves) — 0=lunes...6=domingo, igual
## convención que LEAGUE_WEEKDAYS.
const MIDWEEK_DAYS := [1, 2, 3]
## Mínimo de días entre 2 jornadas de LIGA para que cuenten como "fines
## de semana distintos" — por debajo de esto, se considera "pegado". Ver
## el plan de jornadas cortas/largas en build_league_fixtures (BUG real
## reportado por Wilber, Parte 88: "no es normal que hayan 2 partidos de
## liga en un fin de semana uno después del otro").
const MIN_LEAGUE_MATCHDAY_GAP := 5
## Mínimo de días entre jornadas de liga en año de Mundial/copa
## continental (Parte 91) — más ajustado que el normal (5), como las
## ligas reales antes de un torneo grande, pero SIGUE garantizando que
## nunca haya 2 jornadas el mismo fin de semana (3 días alcanza de sobra
## para eso: nunca es sábado+domingo).
const TOURNAMENT_YEAR_MIN_LEAGUE_MATCHDAY_GAP := 3

## Día permitido más CERCANO a `raw_day` (mismo orden de preferencia que
## _snap_to_weekdays: exacto, +1, -1, +2, -2, +3, -3) que además sea
## `>= earliest` y no caiga en blackout. Si ninguno de esos ±3 sirve
## (earliest los tapa a todos, o blackout), empuja adelante desde
## `earliest` — mismo criterio de respaldo que _snap_to_weekdays.
static func _nearest_allowed(raw_day: int, allowed: Array, earliest: int, blackout: Array) -> int:
	for delta in [0, 1, -1, 2, -2, 3, -3]:
		var day: int = raw_day + delta
		if day >= earliest and CalendarUtils.weekday_of_epoch_day(day) in allowed and not _in_blackout(day, blackout):
			return day
	var day: int = earliest
	while not (CalendarUtils.weekday_of_epoch_day(day) in allowed) or _in_blackout(day, blackout):
		day += 1
	return day

# --- Copa: cuadro eliminatorio ---

## Todos los club_id de un país, de TODAS sus divisiones — para la copa
## doméstica (en la vida real cruza categorías: Copa del Rey, FA Cup...
## nunca son solo de la máxima). Ligas de mayor categoría primero (tier
## ascendente), así los cabezas de serie que reciben bye en el cuadro
## salen de la división más fuerte del país.
static func country_club_ids(world: Dictionary, country: String) -> Array:
	var country_leagues: Array = []
	for lg in world.get("leagues", []):
		if lg.country == country:
			country_leagues.append(lg)
	country_leagues.sort_custom(func(a, b): return a.tier < b.tier)
	var ids: Array = []
	for lg in country_leagues:
		var clubs: Array = world.get("clubs_by_league", {}).get(lg.league_id, [])
		for c in clubs:
			ids.append(c.club_id)
	return ids

static func build_cup_bracket(club_ids: Array, league: LeagueData, season_start_epoch_day: int, blackout: Array = [], span_days: int = SEASON_SPAN_DAYS) -> Dictionary:
	var bracket := _build_bracket_rounds(club_ids, season_start_epoch_day, LEAGUE_START_OFFSET + CUP_FIRST_ROUND_OFFSET, span_days - CUP_FIRST_ROUND_OFFSET, blackout)
	bracket["cup_id"] = "cup_%s" % league.country
	bracket["cup_name"] = CompetitionNames.domestic_cup(league.country)
	return bracket

## Igual que build_cup_bracket pero para un cuadro que NO viene de una
## sola liga (copas continentales: clubes de varias ligas de la misma
## confederación) — mismo sembrado, pero el día de arranque que recibe YA
## es el día exacto en el que debe jugarse la primera ronda (lo calculó
## ContinentalEngine con su propio ancla de calendario), así que acá NO
## se le suma el offset de liga doméstica encima — sería una copa
## empezando 49 días más tarde de lo que en realidad quiere. `span_days`:
## cuántos días hay hasta la final — ContinentalEngine lo calcula para
## que la final caiga cerca de CONTINENTAL_FINAL_TARGET_DAY siempre, sin
## importar cuántas rondas tenga el cuadro.
static func build_continental_bracket(club_ids: Array, cup_id: String, cup_name: String, season_start_epoch_day: int, span_days: int) -> Dictionary:
	var bracket := _build_bracket_rounds(club_ids, season_start_epoch_day, 0, span_days)
	bracket["cup_id"] = cup_id
	bracket["cup_name"] = cup_name
	return bracket

## Liguilla/playoff post-temporada regular (ligas con LeagueData.has_playoffs
## — MLS, Liga MX, Championship inglés, etc.): mismo sembrado por bombos
## que build_cup_bracket, pero con RITMO DE PLAYOFF (rondas cada
## `round_spacing` días desde `start_day`) en vez de repartidas a lo largo
## de toda una temporada — por eso no reusa _build_bracket_rounds, que da
## por sentado ese ritmo largo.
static func build_playoff_bracket(club_ids: Array, cup_id: String, cup_name: String, start_day: int, round_spacing: int = 10) -> Dictionary:
	var field: Array = club_ids.duplicate()
	var target: int = 1
	while target * 2 <= field.size():
		target *= 2
	var prelim_matches: int = field.size() - target
	var teams_playing: int = prelim_matches * 2
	var byes_count: int = field.size() - teams_playing
	var byes: Array = field.slice(0, byes_count)
	var players: Array = field.slice(byes_count, field.size())

	var rounds: Array = []
	var round_index: int = 0
	var teams_in_next: int = target

	if prelim_matches > 0:
		var pm: Array = []
		for i in range(prelim_matches):
			pm.append(_cup_match(players[i * 2], players[i * 2 + 1]))
		rounds.append({"round": 1, "round_name": "Ronda previa", "epoch_day": start_day, "matches": pm, "byes": byes})
		round_index = 1
	else:
		var fm: Array = []
		for i in range(field.size() / 2):
			fm.append(_cup_match(field[i * 2], field[i * 2 + 1]))
		rounds.append({"round": 1, "round_name": _round_name(field.size()), "epoch_day": start_day, "matches": fm, "byes": []})
		round_index = 1
		teams_in_next = field.size() / 2

	while teams_in_next > 1:
		var day: int = start_day + round_index * round_spacing
		var empty: Array = []
		for i in range(teams_in_next / 2):
			empty.append(_cup_match("", ""))
		rounds.append({"round": round_index + 1, "round_name": _round_name(teams_in_next), "epoch_day": day, "matches": empty, "byes": []})
		teams_in_next /= 2
		round_index += 1

	return {"cup_id": cup_id, "cup_name": cup_name, "rounds": rounds}

static func _build_bracket_rounds(club_ids: Array, season_start_epoch_day: int, start_offset: int, span_days: int, blackout: Array = []) -> Dictionary:
	# Sembrado: los primeros de la lista son los cabezas de serie que
	# reciben bye (WorldFactory ordena por fuerza; para copas
	# continentales el llamador ya entrega los clasificados en ese orden).
	var field: Array = club_ids.duplicate()

	var target: int = 1
	while target * 2 <= field.size():
		target *= 2   # mayor potencia de 2 <= nº de equipos

	var prelim_matches: int = field.size() - target
	var teams_playing: int = prelim_matches * 2
	var byes_count: int = field.size() - teams_playing
	var byes: Array = field.slice(0, byes_count)
	var players: Array = field.slice(byes_count, field.size())

	var rounds: Array = []
	# Copas (doméstica y continental) entre semana — pedido explícito.
	var first_day: int = _snap_to_weekdays(season_start_epoch_day + start_offset, CUP_WEEKDAYS, 0, blackout)

	# nº total de rondas del cuadro (desde 'target' hasta 1) + preliminar si la hay
	var bracket_rounds: int = 0
	var bs: int = target
	while bs > 1:
		bracket_rounds += 1
		bs /= 2
	var total_rounds: int = bracket_rounds + (1 if prelim_matches > 0 else 0)
	var cup_step: float = float(span_days) / float(maxi(total_rounds, 1))

	var round_index: int = 0
	var teams_in_next: int = target

	if prelim_matches > 0:
		var pm: Array = []
		for i in range(prelim_matches):
			pm.append(_cup_match(players[i * 2], players[i * 2 + 1]))
		rounds.append({
			"round": 1,
			"round_name": "Ronda preliminar",
			"epoch_day": first_day,
			"matches": pm,
			"byes": byes,
		})
		round_index = 1
	else:
		# el campo ya es potencia de 2: la primera ronda tiene emparejamientos reales
		var fm: Array = []
		for i in range(field.size() / 2):
			fm.append(_cup_match(field[i * 2], field[i * 2 + 1]))
		rounds.append({
			"round": 1,
			"round_name": _round_name(field.size()),
			"epoch_day": first_day,
			"matches": fm,
			"byes": [],
		})
		round_index = 1
		teams_in_next = field.size() / 2

	# rondas siguientes: fechas fijadas, emparejamientos por resolver (Fase 5)
	var prev_round_day: int = first_day
	while teams_in_next > 1:
		var day: int = _snap_to_weekdays(first_day + int(round(round_index * cup_step)), CUP_WEEKDAYS, prev_round_day, blackout)
		prev_round_day = day
		var empty: Array = []
		for i in range(teams_in_next / 2):
			empty.append(_cup_match("", ""))
		rounds.append({
			"round": round_index + 1,
			"round_name": _round_name(teams_in_next),
			"epoch_day": day,
			"matches": empty,
			"byes": [],
		})
		teams_in_next /= 2
		round_index += 1

	return {
		"rounds": rounds,
	}

# --- Consultas sobre un `season` ya construido (lógica pura, testeable) ---

## Fixture de LIGA que involucra a `club_id` en `epoch_day`, o {}.
## (La copa se consulta con SeasonEngine.cup_fixture_for_club_on() sobre
## el cuadro ya resuelto — sus emparejamientos de ronda 2+ no existen en
## la plantilla `season["cup"]`.)
static func fixture_for_club_on(season: Dictionary, epoch_day: int, club_id: String) -> Dictionary:
	if club_id == "" or season.is_empty():
		return {}
	for fx in season.get("league_fixtures", []):
		if int(fx["epoch_day"]) == epoch_day and _involves(fx, club_id):
			return fx.duplicate()
	return {}

## Próximo fixture de liga del club a partir de `from_epoch_day` (incluido), o {}.
static func next_league_fixture_for_club(season: Dictionary, from_epoch_day: int, club_id: String) -> Dictionary:
	if club_id == "" or season.is_empty():
		return {}
	var best: Dictionary = {}
	for fx in season.get("league_fixtures", []):
		if int(fx["epoch_day"]) < from_epoch_day or not _involves(fx, club_id):
			continue
		if best.is_empty() or int(fx["epoch_day"]) < int(best["epoch_day"]):
			best = fx.duplicate()
	return best

## Amistoso que involucra a `club_id` en `epoch_day`, o {}.
static func friendly_fixture_for_club_on(season: Dictionary, epoch_day: int, club_id: String) -> Dictionary:
	if club_id == "" or season.is_empty():
		return {}
	for fx in season.get("friendlies", []):
		if int(fx["epoch_day"]) == epoch_day and _involves(fx, club_id):
			return fx.duplicate()
	return {}

## Próximo amistoso del club a partir de `from_epoch_day` (incluido), o {}.
static func next_friendly_for_club(season: Dictionary, from_epoch_day: int, club_id: String) -> Dictionary:
	if club_id == "" or season.is_empty():
		return {}
	var best: Dictionary = {}
	for fx in season.get("friendlies", []):
		if int(fx["epoch_day"]) < from_epoch_day or not _involves(fx, club_id):
			continue
		if best.is_empty() or int(fx["epoch_day"]) < int(best["epoch_day"]):
			best = fx.duplicate()
	return best

## Último día con actividad de la temporada (liga, amistoso o copa) — más
## allá de este día, WorldTickEngine considera la temporada terminada y
## hace el rollover a la siguiente.
static func season_last_day(season: Dictionary) -> int:
	var last: int = int(season.get("season_start_epoch_day", 0))
	for fx in season.get("league_fixtures", []):
		last = maxi(last, int(fx["epoch_day"]))
	for fx in season.get("friendlies", []):
		last = maxi(last, int(fx["epoch_day"]))
	for rnd in season.get("cup", {}).get("rounds", []):
		last = maxi(last, int(rnd["epoch_day"]))
	return last

static func _involves(fx: Dictionary, club_id: String) -> bool:
	return fx.get("home_club_id", "") == club_id or fx.get("away_club_id", "") == club_id

static func _cup_match(home_id: String, away_id: String) -> Dictionary:
	return {"home_club_id": home_id, "away_club_id": away_id, "is_knockout": true}

static func _round_name(teams_in_round: int) -> String:
	match teams_in_round:
		2:
			return "Final"
		4:
			return "Semifinal"
		8:
			return "Cuartos de final"
		16:
			return "Octavos de final"
		32:
			return "Dieciseisavos de final"
		_:
			return "Ronda de %d" % teams_in_round
