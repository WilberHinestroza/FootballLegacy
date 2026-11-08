extends RefCounted
class_name BallonDorEngine

## Balón de Oro del mundo: mezcla goles+asistencias (ponderados por el
## nivel de la liga donde se hicieron, para que meter 20 en una liga de
## reputación 48 no valga lo mismo que meter 20 en una de reputación 96)
## con éxito colectivo (título de liga, copa doméstica, copa continental)
## — mismo espíritu que la votación real: pesan los números Y los
## títulos, no solo la tabla de goleadores de cada uno.
##
## Pura: recibe los candidatos ya reunidos desde afuera (WorldTickEngine
## los junta liga por liga) — no conoce al autoload ni a WorldFactory.

const GOAL_WEIGHT := 2.2
const ASSIST_WEIGHT := 1.6
const REPUTATION_BASELINE := 95.0 # la liga más fuerte del mundo — vara de referencia
const REPUTATION_EXPONENT := 2.2  # cuánto castiga a una liga floja frente a la más fuerte —
                                   # lineal (bug real reportado: "Lucas Pérez es irreal") dejaba
                                   # a una liga de reputación 61 competir casi en igualdad con
                                   # las 5 grandes de Europa; el Balón de Oro real nunca sale de
                                   # ahí salvo una temporada verdaderamente descomunal

## Valor BASE de cada trofeo — se multiplica por el mismo `rep_factor` que
## goles/asistencias (pedido explícito: "obviamente no es lo mismo ganar
## la Champions que ganar la liga de Arabia"). Antes eran puntos fijos: un
## título de la liga saudí (reputación 63) sumaba exactamente lo mismo
## que uno de la Premier (reputación 96) — ahora el mismo título de liga
## vale 14 puntos completos para el que gana la más fuerte del mundo, y
## una fracción chica para el que gana una floja. Las claves son las que
## ya arma WorldTickEngine._tag_club_players.
const TROPHY_BASE := {
	"league_champion": 14.0, "league_runner_up": 5.0,
	"domestic_cup_champion": 8.0,
	"continental_top_champion": 32.0, "continental_top_runner_up": 14.0,
	"continental_other_champion": 16.0, "continental_other_runner_up": 6.0,
}

## `candidates`: Array de Dictionary {name, club_name, league_reputation,
## goals, assists, trophies: Array[String] (claves de TROPHY_BASE)}.
## Devuelve la misma lista con "score" agregado, ordenada de mayor a menor.
## Cuánto vale lo hecho en una liga frente a la más fuerte del mundo (0..1).
static func rep_factor(league_reputation: int) -> float:
	var rep_ratio: float = float(league_reputation) / REPUTATION_BASELINE
	return pow(clampf(rep_ratio, 0.0, 1.0), REPUTATION_EXPONENT)

static func rank(candidates: Array) -> Array:
	var rows: Array = candidates.duplicate(true)
	for row in rows:
		var rf: float = rep_factor(int(row.get("league_reputation", REPUTATION_BASELINE)))
		var score: float = (float(row.get("goals", 0)) * GOAL_WEIGHT + float(row.get("assists", 0)) * ASSIST_WEIGHT) * rf
		for t in (row.get("trophies", []) as Array):
			score += float(TROPHY_BASE.get(t, 0.0)) * rf
		row["score"] = score
	rows.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	return rows
