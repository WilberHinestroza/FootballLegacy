extends RefCounted
class_name LeagueTable

## Clasificación de una liga hasta el día actual. Sirve para CUALQUIER liga
## del mundo: los resultados se obtienen de SeasonEngine (override del
## usuario o simulación determinista).
##
## 3 puntos por victoria, 1 por empate. Desempate: puntos -> dif. de goles
## -> goles a favor -> nombre. (Los desempates reales por país llegan con
## el import de datos.)

## fixtures: lista de fixtures de la liga (con matchday, epoch_day, home/away).
## clubs: Array[ClubData] de la liga (nombres + para listar a todos).
## decided_before_day: solo cuentan fixtures con epoch_day < este valor.
static func compute(fixtures: Array, clubs: Array, decided_before_day: int, world_seed: int, overrides: Dictionary, strength_by_club: Dictionary) -> Array:
	var rows: Dictionary = {}
	for club in clubs:
		rows[club.club_id] = {
			"club_id": club.club_id, "name": club.club_name,
			"pj": 0, "g": 0, "e": 0, "p": 0, "gf": 0, "gc": 0, "pts": 0,
		}

	for fx in fixtures:
		if int(fx["epoch_day"]) >= decided_before_day:
			continue
		var home_id: String = fx["home_club_id"]
		var away_id: String = fx["away_club_id"]
		if not rows.has(home_id) or not rows.has(away_id):
			continue
		var score: Array = SeasonEngine.league_result(fx, world_seed, overrides, strength_by_club)
		_apply(rows[home_id], int(score[0]), int(score[1]))
		_apply(rows[away_id], int(score[1]), int(score[0]))

	var table: Array = rows.values()
	table.sort_custom(_sort_rows)
	for i in range(table.size()):
		table[i]["pos"] = i + 1
		table[i]["dg"] = table[i]["gf"] - table[i]["gc"]
	return table

## Fila de un club concreto, o {} si no está.
static func row_for(table: Array, club_id: String) -> Dictionary:
	for r in table:
		if r["club_id"] == club_id:
			return r
	return {}

static func _apply(row: Dictionary, gf: int, gc: int) -> void:
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

static func _sort_rows(a: Dictionary, b: Dictionary) -> bool:
	if a["pts"] != b["pts"]:
		return a["pts"] > b["pts"]
	var a_dg: int = a["gf"] - a["gc"]
	var b_dg: int = b["gf"] - b["gc"]
	if a_dg != b_dg:
		return a_dg > b_dg
	if a["gf"] != b["gf"]:
		return a["gf"] > b["gf"]
	return a["name"] < b["name"]
