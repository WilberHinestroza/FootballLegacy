extends RefCounted
class_name CoefficientEngine

## Coeficiente de cada liga: puntos según hasta dónde llegaron SUS clubes
## en los torneos continentales de su confederación (todos los niveles),
## al día de hoy — mismo espíritu que el coeficiente UEFA real (más
## rondas superadas = más puntos), adaptado a que acá no hay temporadas
## PASADAS de verdad que consultar por separado (ver nota abajo).
##
## Nota de diseño: el coeficiente se calcula sobre el estado actual de
## los torneos, no se persiste ni se acumula temporada a temporada — sería
## circular usarlo para decidir los cupos DE ESE MISMO cálculo (¿con qué
## cupo entraron los clubes cuyo resultado define el cupo?). Por ahora es
## una tabla de referencia/diagnóstico (qué ligas están rindiendo de
## verdad en continentales) para ajustar reputación/cupos a mano cuando
## haga falta — no reemplaza automáticamente a ContinentalEngine._spots_for.
##
## Puntos ACUMULATIVOS por etapa (un campeón suma también octavos +
## cuartos + semifinal + final, no solo el último tramo — "llegó" a
## todas esas rondas de verdad).
const POINTS_ROUND_OF_16 := 1
const POINTS_QUARTERFINAL := 2
const POINTS_SEMIFINAL := 3
const POINTS_FINAL := 5
const POINTS_CHAMPION := 8

const _STAGE_ORDER := ["Octavos de final", "Cuartos de final", "Semifinal", "Final", "Campeón"]
const _STAGE_POINTS := {
	"Octavos de final": POINTS_ROUND_OF_16,
	"Cuartos de final": POINTS_QUARTERFINAL,
	"Semifinal": POINTS_SEMIFINAL,
	"Final": POINTS_FINAL,
	"Campeón": POINTS_CHAMPION,
}

## club_id -> etapa más lejana que alcanzó en `bracket` (una de
## _STAGE_ORDER), o ausente si quedó eliminado antes de octavos (o el
## cuadro es tan chico que ni siquiera hay ronda de octavos).
static func stage_reached_by_club(bracket: Dictionary) -> Dictionary:
	var reached: Dictionary = {}
	var rounds: Array = bracket.get("rounds", [])
	for rnd in rounds:
		var round_name: String = String(rnd.get("round_name", ""))
		if not _STAGE_POINTS.has(round_name):
			continue # rondas más chicas que octavos (dieciseisavos, previa...) no puntúan
		for m in rnd.get("matches", []):
			for cid in [String(m.get("home_club_id", "")), String(m.get("away_club_id", ""))]:
				if cid != "":
					reached[cid] = round_name # se pisa con la ronda más avanzada, vienen en orden
		for cid in (rnd.get("byes", []) as Array):
			reached[String(cid)] = round_name
		if round_name == "Final" and rnd.get("decided", false):
			for m in rnd.get("matches", []):
				var winner: String = String(m.get("winner_club_id", ""))
				if winner != "":
					reached[winner] = "Campeón"
	return reached

static func _cumulative_points(stage: String) -> int:
	var idx: int = _STAGE_ORDER.find(stage)
	if idx < 0:
		return 0
	var total: int = 0
	for i in range(idx + 1):
		total += _STAGE_POINTS[_STAGE_ORDER[i]]
	return total

## Puntaje de arranque de un mundo NUEVO (sin ninguna temporada jugada
## todavía) — pedido explícito de Wilber: "debería ya venir con los
## puntos que establecen el inicio de temporada", en vez de 0 parejo
## para las ~55 ligas hasta que se juegue la primera copa continental.
## Aproximación deliberada (no hay historial real que consultar, mismo
## motivo que bootstrap_rankings() de abajo): mapea la reputación de cada
## liga (0-100) a un puntaje del mismo ORDEN DE MAGNITUD que gana una
## liga fuerte en una temporada real jugando bien la copa (un campeón +
## un par de clubes llegando lejos ronda ~25-30 puntos, ver POINTS_*
## arriba) — reputación 95+ ≈ 24-27 pts, ~65 ≈ 6-8 pts, ~40 ≈ 1-2 pts.
## Nunca se recalcula una vez que hay historial real guardado (ver
## SaveManager.coefficient_history, v30): esto es SOLO el día 1.
## confederation -> (String league_id -> puntaje).
static func seed_scores_from_reputation(world: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for confederation in Confederations.ALL:
		var by_id: Dictionary = {}
		for league in world.get("leagues", []):
			if league.tier != 1 or league.team_count <= 0:
				continue
			if Confederations.confederation_of(league.country) != confederation:
				continue
			var rep_ratio: float = clampf(float(league.reputation) / 100.0, 0.0, 1.0)
			by_id[str(league.league_id)] = int(round(pow(rep_ratio, 3.0) * 30.0))
		result[confederation] = by_id
	return result

## Ranking de arranque de una carrera nueva (o de una confederación que el
## ranking guardado todavía no vio): por reputación, mejor primero —
## "los mejores rankeados de cada país para empezar el mundo", pedido
## explícito de Wilber ya que la 1ª temporada no tiene una anterior de la
## que sacar posición real. confederation -> Array[league_id].
static func bootstrap_rankings(world: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for confederation in Confederations.ALL:
		var leagues: Array = []
		for league in world.get("leagues", []):
			if league.tier == 1 and league.team_count > 0 and Confederations.confederation_of(league.country) == confederation:
				leagues.append(league)
		leagues.sort_custom(func(a, b): return a.reputation > b.reputation)
		result[confederation] = leagues.map(func(l): return int(l.league_id))
	return result

## Puntos totales de cada liga (league_id -> int) sumando TODOS los
## niveles del torneo continental de `confederation`, al día de hoy.
## `rank_by_league_id`: posición (1-based) de cada liga en el ranking
## VIGENTE de esta temporada (el que decidió sus cupos) — ver
## ContinentalEngine.qualified_clubs para por qué esto no es circular.
## `frozen_pool_for` (confederation, tier) -> Array: el sorteo REAL ya
## congelado del torneo que se está jugando de verdad esta temporada (ver
## WorldTickEngine._frozen_cont_pool). Bug real encontrado en la auditoría:
## sin esto, cada llamada recalculaba `qualified_clubs()` con la tabla
## doméstica EN VIVO (casi siempre distinta a la tabla congelada al
## arrancar la temporada, que es la que de verdad decidió quién entró al
## torneo) — el puntaje de coeficiente terminaba premiando/castigando a un
## club por cómo le fue en un cuadro FANTASMA que nunca se jugó, y ese
## puntaje decide cupos continentales reales de la temporada siguiente.
static func compute_scores(world: Dictionary, confederation: String, table_for_league: Callable, world_seed: int, strength_by_club: Dictionary, current_epoch_day: int, season_start_epoch_day: int = 0, rank_by_league_id: Dictionary = {}, frozen_pool_for: Callable = Callable()) -> Dictionary:
	var scores: Dictionary = {}
	for tier in range(1, Confederations.tier_count(confederation) + 1):
		var frozen: Array = frozen_pool_for.call(confederation, tier) if frozen_pool_for.is_valid() else []
		var cup := ContinentalEngine.build_and_resolve(world, confederation, tier, table_for_league, world_seed, strength_by_club, current_epoch_day, season_start_epoch_day, rank_by_league_id, {}, frozen)
		if cup.is_empty():
			continue
		var reached := stage_reached_by_club(cup)
		for club_id in reached:
			var club := WorldFactory.find_club(world, club_id)
			if club == null:
				continue
			var pts: int = _cumulative_points(reached[club_id])
			scores[club.league_id] = int(scores.get(club.league_id, 0)) + pts
	return scores

## Ranking global: confederation -> Array[{league, score, rank,
## projected_allocations}], ordenado por puntaje descendente (empate: más
## reputación primero). Solo ligas de PRIMERA división (las únicas que
## mandan clubes a torneos continentales — ver
## ContinentalEngine.qualified_clubs()); una segunda división nunca puede
## aparecer acá aunque tenga buena reputación. Todas las de primera salen,
## aunque tengan 0 puntos — así se ve de un vistazo quién no está
## rindiendo, no solo quién sí.
##
## `projected_allocations` (Array[{tier, spots}], ver
## ContinentalEngine.allocation_for_rank): si HOY se cerrara la temporada y
## se repartieran los cupos de la próxima con ESTA posición, a qué
## torneo(s) y con cuántos clubes entraría esa liga — "saber de antemano
## cuántos cupos tiene cada país para las próximas copas", pedido
## explícito. Puede traer MÁS de una fila (confederaciones "compartidas"
## como CONMEBOL/CAF: el mismo país entra a sus dos torneos a la vez).
##
## `rank_by_league_id_per_confederation`: confederation -> (league_id ->
## rank 1-based) VIGENTE esta temporada (la que usó ContinentalEngine para
## armar los campos que se están puntuando acá) — normalmente
## WorldTickEngine._rank_by_league_id() por confederación.
## `prev_scores_by_confederation` (pedido explícito de Wilber, ronda 6):
## confederation -> (String league_id -> puntaje crudo de la temporada
## ANTERIOR, ver SaveManager.load_coefficient_history()) — se SUMA al
## puntaje fresco de esta temporada, dando una ventana de 2 temporadas en
## vez de resetear el ranking entero cada año. {} = sin historial todavía
## (primera temporada del sistema, o save viejo) → se comporta exactamente
## como antes (solo esta temporada).
static func global_ranking(world: Dictionary, table_for_league: Callable, world_seed: int, strength_by_club: Dictionary, current_epoch_day: int, season_start_epoch_day: int = 0, rank_by_league_id_per_confederation: Dictionary = {}, frozen_pool_for: Callable = Callable(), prev_scores_by_confederation: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	for confederation in Confederations.ALL:
		var rank_map: Dictionary = rank_by_league_id_per_confederation.get(confederation, {})
		var scores := compute_scores(world, confederation, table_for_league, world_seed, strength_by_club, current_epoch_day, season_start_epoch_day, rank_map, frozen_pool_for)
		var prev_scores: Dictionary = prev_scores_by_confederation.get(confederation, {})
		var rows: Array = []
		for league in world.get("leagues", []):
			if league.tier != 1 or league.team_count <= 0:
				continue
			if Confederations.confederation_of(league.country) != confederation:
				continue
			# Bug real de la auditoría (ronda 6, encontrado probando el
			# coloreado de tablas): String(int) es un cast ESTRICTO que
			# esta versión de Godot no acepta para convertir un int a
			# String (a diferencia de str(int), que sí — y es lo que usa
			# el resto del codebase para esto). Crasheaba coefficient_
			# ranking() apenas había más de una liga en la confederación.
			var combined_score: int = int(scores.get(league.league_id, 0)) + int(prev_scores.get(str(league.league_id), 0))
			rows.append({"league": league, "score": combined_score})
		rows.sort_custom(func(a, b):
			if a["score"] != b["score"]:
				return a["score"] > b["score"]
			return a["league"].reputation > b["league"].reputation
		)
		for i in range(rows.size()):
			rows[i]["rank"] = i + 1
			rows[i]["projected_allocations"] = ContinentalEngine.allocation_for_rank(confederation, i + 1, rows.size())
		result[confederation] = rows
	return result

## Puntaje CRUDO (solo la temporada que recién terminó, sin sumar
## historial) por confederación, listo para persistir como el nuevo
## "coefficient_history" en el rollover (ver SaveManager.save_
## coefficient_history) — mismos argumentos que global_ranking() pero SIN
## prev_scores_by_confederation (nunca acumula sobre lo ya guardado; el
## llamador REEMPLAZA el historial entero con esto, así la ventana de 2
## temporadas nunca crece a 3+). Devuelve confederation -> (String
## league_id -> puntaje).
static func raw_scores_by_confederation(world: Dictionary, table_for_league: Callable, world_seed: int, strength_by_club: Dictionary, current_epoch_day: int, season_start_epoch_day: int = 0, rank_by_league_id_per_confederation: Dictionary = {}, frozen_pool_for: Callable = Callable()) -> Dictionary:
	var result: Dictionary = {}
	for confederation in Confederations.ALL:
		var rank_map: Dictionary = rank_by_league_id_per_confederation.get(confederation, {})
		var scores := compute_scores(world, confederation, table_for_league, world_seed, strength_by_club, current_epoch_day, season_start_epoch_day, rank_map, frozen_pool_for)
		var by_id: Dictionary = {}
		for league_id in scores:
			by_id[str(league_id)] = int(scores[league_id])
		result[confederation] = by_id
	return result
