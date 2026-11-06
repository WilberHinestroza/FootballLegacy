extends RefCounted
class_name StandingsColor

## Franja de color de una posición de tabla de liga — pedido explícito de
## Wilber (auditoría de balance, ronda 6): en PRIMERA división, el
## campeón en DORADO, cada clasificado a copa continental con el color de
## SU torneo (para diferenciarlos entre sí), y ROJO el que desciende (si
## esta liga tiene descenso modelado, ver PromotionRelegationEngine); en
## las DEMÁS divisiones, VERDE el que asciende / ROJO el que desciende.
## Un solo lugar para toda la UI que pinta tablas (Standings.gd, el
## mini-tabla del Hub) — nunca duplicar esta lógica (balance/reglas de
## competición centralizadas, mismo criterio que el resto del proyecto).

static func accent_for(league: LeagueData, table_size: int, pos: int) -> Color:
	return zone_for(league, table_size, pos)["color"]

## Leyenda de la tabla (9-oct, Torneos): [[color, texto], ...] en orden de
## aparición, sin repetir. Misma lógica que accent_for (zone_for).
static func legend_for(league: LeagueData, table_size: int) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for pos in range(1, table_size + 1):
		var z: Dictionary = zone_for(league, table_size, pos)
		var lbl: String = String(z["label"])
		if lbl != "" and not seen.has(lbl):
			seen[lbl] = true
			out.append([z["color"], lbl])
	return out

## Zona de una posición: {color, label}. Fuente única de las franjas.
static func zone_for(league: LeagueData, table_size: int, pos: int) -> Dictionary:
	if league == null or table_size <= 0:
		return {"color": Color.TRANSPARENT, "label": ""}
	var pr: Dictionary = PromotionRelegationEngine.zones_for_league(WorldTickEngine.world, league.league_id)
	if league.tier == 1:
		if pos == 1:
			return {"color": Styles.GOLD, "label": "Campeón"}
		var confederation: String = Confederations.confederation_of(league.country)
		if confederation != "":
			var ranking: Array = (WorldTickEngine.coefficient_ranking().get(confederation, []) as Array)
			var my_rank: int = 0
			for r in ranking:
				if int((r["league"] as LeagueData).league_id) == league.league_id:
					my_rank = int(r["rank"])
					break
			if my_rank > 0:
				var zones: Array = ContinentalEngine.table_zones_for_rank(confederation, my_rank, ranking.size())
				for z in zones:
					if pos >= int(z["from_pos"]) and pos <= int(z["to_pos"]):
						var t: int = int(z["tier"])
						var pair: Array = Competition.CONF_COLORS.get(confederation, Competition.PALETTE[0])
						return {"color": Color(pair[0]).lightened(0.12 * float(t - 1)), "label": CompetitionNames.continental(confederation, t)}
		var relegate_n: int = int(pr.get("relegate_bottom_n", 0))
		if relegate_n > 0 and pos > table_size - relegate_n:
			return {"color": Styles.RED, "label": "Descenso"}
		return {"color": Color.TRANSPARENT, "label": ""}

	var promote_n: int = int(pr.get("promote_top_n", 0))
	if promote_n > 0 and pos <= promote_n:
		return {"color": Styles.GREEN, "label": "Ascenso"}
	var relegate_n2: int = int(pr.get("relegate_bottom_n", 0))
	if relegate_n2 > 0 and pos > table_size - relegate_n2:
		return {"color": Styles.RED, "label": "Descenso"}
	return {"color": Color.TRANSPARENT, "label": ""}
