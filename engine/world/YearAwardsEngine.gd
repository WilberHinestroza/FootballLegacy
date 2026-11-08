class_name YearAwardsEngine
extends RefCounted
## Premios mundiales del año (además del Balón de Oro, ver BallonDorEngine):
##   Bota de Oro    → goles × coeficiente de la liga (×2 en las ligas de élite,
##                    ×1,5 en las fuertes, ×1 en el resto), como la de verdad.
##   Asistidor      → más asistencias del mundo (desempata el Balón de Oro).
##   Guante de Oro  → mejor portero: porterías a cero, nivel y títulos.
##   Once ideal     → 1 GK, 4 DF, 3 MF, 3 ST por nota de puesto (los defensas y
##                    porteros por fin cuentan: no viven de goles).
## Puro: WorldTickEngine junta las filas (onces de los clubes que pelean arriba
## en las ligas de élite + tú) y aquí solo se puntúa y ordena. Mundo vivo,
## nada se guarda.

const XI_SHAPE := {"GK": 1, "DF": 4, "MF": 3, "ST": 3}
const POS_ORDER := ["GK", "DF", "MF", "ST"]

## Coeficiente de la Bota de Oro según la reputación de la liga.
static func shoe_coef(league_rep: int) -> float:
	if league_rep >= 85:
		return 2.0
	if league_rep >= 75:
		return 1.5
	return 1.0


## Porterías a cero estimadas de un equipo (Poisson: P(0 goles) = e^-media).
static func clean_sheets(pj: int, gc: int) -> int:
	if pj <= 0:
		return 0
	return int(round(pj * exp(-float(gc) / float(pj))))


## `rows` = las del Balón de Oro (name, club_name, league_reputation, goals...).
static func golden_shoe(rows: Array) -> Array:
	var out: Array = []
	for r: Dictionary in rows:
		if int(r.get("goals", 0)) <= 0:
			continue
		var q := r.duplicate()
		q["points"] = float(r.get("goals", 0)) * shoe_coef(int(r.get("league_reputation", 60)))
		out.append(q)
	out.sort_custom(func(a, b):
		if float(a.points) != float(b.points):
			return float(a.points) > float(b.points)
		return int(a.goals) > int(b.goals))
	return out


static func assist_kings(rows: Array) -> Array:
	var out: Array = rows.filter(func(r): return int(r.get("assists", 0)) > 0)
	out.sort_custom(func(a, b):
		if int(a.assists) != int(b.assists):
			return int(a.assists) > int(b.assists)
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	return out


## Nota de puesto de un jugador para el once / el Guante de Oro. `row`:
## {pos, overall, league_reputation, pj, gc, pts, goals, assists, trophies}
## (pj/gc/pts = los de su club en liga; trophies = los títulos de su club).
static func player_score(row: Dictionary) -> float:
	var pj: int = maxi(int(row.get("pj", 0)), 1)
	var ppg: float = float(row.get("pts", 0)) / float(pj)
	var conceded: float = float(row.get("gc", 0)) / float(pj)
	var g: float = float(row.get("goals", 0))
	var a: float = float(row.get("assists", 0))
	var s: float = (float(row.get("overall", 70)) - 70.0) * 0.8 + ppg * 4.0
	match String(row.get("pos", "MF")):
		"GK": s += float(clean_sheets(int(row.get("pj", 0)), int(row.get("gc", 0)))) * 1.8
		"DF": s += (1.6 - conceded) * 8.0 + g * 1.5 + a * 1.0
		"MF": s += g * 1.6 + a * 1.8
		_: s += g * 2.0 + a * 1.0
	for t in (row.get("trophies", []) as Array):
		s += float(BallonDorEngine.TROPHY_BASE.get(t, 0.0)) * 0.5
	return s * BallonDorEngine.rep_factor(int(row.get("league_reputation", 60)))


## Ordena las filas con su nota ("score") y "cs" para los porteros.
static func score_all(rows: Array) -> Array:
	var out: Array = []
	for r: Dictionary in rows:
		var q := r.duplicate()
		q["score"] = player_score(r)
		if String(r.get("pos", "")) == "GK":
			q["cs"] = clean_sheets(int(r.get("pj", 0)), int(r.get("gc", 0)))
		out.append(q)
	out.sort_custom(func(a, b): return float(a.score) > float(b.score))
	return out


static func keepers(scored: Array) -> Array:
	return scored.filter(func(r): return String(r.get("pos", "")) == "GK")


## Once ideal del año, ya en orden GK → DF → MF → ST.
static func team_of_year(scored: Array) -> Array:
	var xi: Array = []
	for pos: String in POS_ORDER:
		var n: int = int(XI_SHAPE[pos])
		for r: Dictionary in scored:
			if n <= 0:
				break
			if String(r.get("pos", "")) == pos:
				xi.append(r)
				n -= 1
	return xi


## ¿Está el usuario (fila marcada "you") en esta lista? Devuelve su puesto (1..) o 0.
static func user_rank(rows: Array) -> int:
	for i in rows.size():
		if bool((rows[i] as Dictionary).get("you", false)):
			return i + 1
	return 0
