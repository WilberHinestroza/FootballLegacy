extends RefCounted
class_name PromotionRelegationEngine

## Ascensos y descensos entre categorias de un mismo pais (ej. Bundesliga
## tier 1 <-> 2. Bundesliga tier 2). Solo funciones puras -- no toca
## `world` ni ningun save; el llamador decide cuando aplicar el resultado
## (ver WorldFactory.apply_league_overrides).
##
## Alcance real de los datos del juego (verificado contra LEAGUE_BLUEPRINTS
## de WorldFactory.gd y el JSON importado real de Wilber, coinciden
## exactamente): solo 5 paises tienen mas de un tier -- Espana, Alemania,
## Francia, Italia (2 tiers cada uno) e Inglaterra (4 tiers). El resto de
## las ~50 ligas del juego no tiene con que emparejar y simplemente no
## participa -- tier_boundaries() lo resuelve solo, sin caso especial.

const DEFAULT_MOVES_PER_BOUNDARY := 3

## Empareja cada liga con la de tier inmediatamente inferior/superior DEL
## MISMO PAIS (mismo criterio de agrupacion que
## WorldFactory._index_leagues_by_country: country.strip_edges().to_lower()).
## Devuelve Array de {country, top: LeagueData, bottom: LeagueData}
## (top.tier < bottom.tier, es decir top es la categoria MAS ALTA del par).
static func tier_boundaries(world: Dictionary) -> Array:
	var by_country: Dictionary = {}
	for lg in world.get("leagues", []):
		var key: String = String(lg.country).strip_edges().to_lower()
		var arr: Array = by_country.get(key, [])
		arr.append(lg)
		by_country[key] = arr

	var out: Array = []
	for key in by_country:
		var leagues: Array = by_country[key]
		if leagues.size() < 2:
			continue
		leagues.sort_custom(func(a, b): return a.tier < b.tier)
		for i in range(leagues.size() - 1):
			out.append({
				"country": String(leagues[i].country),
				"top": leagues[i],
				"bottom": leagues[i + 1],
			})
	return out

## Para la UI (pintar la tabla de liga, pedido explícito de Wilber, ronda
## 6): cuántas posiciones de arriba/abajo de ESTA liga participan del
## ascensor esta temporada — mismo n_eff que plan_moves(), pero solo el
## TAMAÑO (alcanza con team_count, no hace falta la tabla real).
## {"promote_top_n": int, "relegate_bottom_n": int} (0 = esta liga no
## tiene ese lado del ascensor — la mayoría de las ~50 ligas no tienen
## ninguno, solo los 5 países con más de un tier).
static func zones_for_league(world: Dictionary, league_id: int) -> Dictionary:
	var out: Dictionary = {"promote_top_n": 0, "relegate_bottom_n": 0}
	for b in tier_boundaries(world):
		var top: LeagueData = b["top"]
		var bottom: LeagueData = b["bottom"]
		var n_eff: int = clampi(DEFAULT_MOVES_PER_BOUNDARY, 1, mini(top.team_count, bottom.team_count) - 1)
		if n_eff <= 0:
			continue
		if top.league_id == league_id:
			out["relegate_bottom_n"] = n_eff
		if bottom.league_id == league_id:
			out["promote_top_n"] = n_eff
	return out

## `standings_by_league`: Dictionary league_id(int) -> Array de filas
## (mismo formato que WorldTickEngine.table_for_league(), cada fila con
## al menos "club_id", ordenadas de 1ro a ultimo). Devuelve Array de
## {club_id, from_league_id, to_league_id, direction: "up"|"down"}.
static func plan_moves(_world: Dictionary, boundaries: Array, standings_by_league: Dictionary, n: int = DEFAULT_MOVES_PER_BOUNDARY) -> Array:
	var moves: Array = []
	# Defensivo: un club solo puede moverse UNA vez por temporada. Una
	# liga "del medio" (ej. tier 2 de Inglaterra) es "bottom" de un
	# boundary Y "top" del siguiente, así que su tabla se lee dos veces
	# (una por cada boundary) -- si esa lectura no es perfectamente
	# estable entre llamadas (empates en la tabla, orden no determinista)
	# un club podría terminar contado dos veces. Nunca reproducido de
	# forma confiable en pruebas limpias, pero se vio una vez en un
	# reporte real -- este set evita el duplicado sin importar la causa.
	var seen_club_ids: Dictionary = {}
	for b in boundaries:
		var top_id: int = int(b["top"].league_id)
		var bottom_id: int = int(b["bottom"].league_id)
		var top_table: Array = standings_by_league.get(top_id, [])
		var bottom_table: Array = standings_by_league.get(bottom_id, [])
		if top_table.is_empty() or bottom_table.is_empty():
			continue
		var n_eff: int = clampi(n, 1, mini(top_table.size(), bottom_table.size()) - 1)
		if n_eff <= 0:
			continue
		# Descienden: los ULTIMOS n_eff de la liga de arriba.
		for i in range(top_table.size() - n_eff, top_table.size()):
			var down_id: String = String(top_table[i]["club_id"])
			if seen_club_ids.has(down_id):
				continue
			seen_club_ids[down_id] = true
			moves.append({
				"club_id": down_id,
				"from_league_id": top_id, "to_league_id": bottom_id, "direction": "down",
			})
		# Ascienden: los PRIMEROS n_eff de la liga de abajo.
		for i in range(n_eff):
			var up_id: String = String(bottom_table[i]["club_id"])
			if seen_club_ids.has(up_id):
				continue
			seen_club_ids[up_id] = true
			moves.append({
				"club_id": up_id,
				"from_league_id": bottom_id, "to_league_id": top_id, "direction": "up",
			})
	return moves
