extends RefCounted
class_name SeasonAwardsEngine

## Premios individuales de tu temporada que no salen del ranking del Balón de
## Oro:
##
## - JUGADOR DEL MES (de tu liga): al cerrar cada mes se compara lo que hiciste
##   ESE mes (goles, asistencias y nota media, con pesos según tu puesto) con
##   el mejor rival del mes, cuyo listón depende del nivel de la liga.
## - EQUIPO DE LA TEMPORADA (TOTS): entras si tu nota media de la temporada
##   supera el listón de tu puesto y jugaste la mayoría de partidos de liga.
##   Así un portero o un defensa también pueden entrar (el 11 ideal por
##   goles+asistencias solo veía a los de arriba).
## - GOLDEN BOY: mejor sub-21 del mundo, contra los juveniles de los grandes
##   clubes (media, margen de crecimiento y temporada).
##
## Estado en `season` (aditivo, sin cambio de esquema; el rollover lo convierte
## en honores del gabinete antes de reconstruir la temporada):
##   season["potm_snap"]  -> {month, goals, assists, rsum, games} al abrir el mes
##   season["potm_wins"]  -> Array de nombres de mes ganados

const MONTHS := ["", "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
	"agosto", "septiembre", "octubre", "noviembre", "diciembre"]
const POTM_MIN_GAMES := 3
## Pesos por puesto: [gol, asistencia, nota (por punto sobre 6,5)].
const POTM_WEIGHTS := {
	"ST": [1.0, 0.7, 2.0], "MF": [0.9, 0.9, 2.6], "DF": [0.8, 0.7, 3.4], "GK": [0.0, 0.5, 4.5],
}
const POTM_BASE := 3.4
const POTM_SPREAD := Vector2(-0.8, 1.2)
const POTM_NOMINEE := 0.78 # a este % del listón sales nominado
const POTM_REP := 2
const POTM_MOOD := 6

## Nota media mínima para el equipo de la temporada, por puesto.
const TOTS_RATING := {"ST": 7.25, "MF": 7.2, "DF": 7.1, "GK": 7.05}
const TOTS_MIN_SHARE := 0.55 # de los partidos de liga de tu club

const GB_MAX_AGE := 21
const GB_RIVAL_CLUBS := 24

static func month_of(day: int) -> int:
	return int(CalendarUtils.epoch_day_to_date(day).get("month", 1))

static func snapshot(player: PlayerData, season: Dictionary, day: int) -> Dictionary:
	return {
		"month": month_of(day),
		"goals": player.season_goals, "assists": player.season_key_passes,
		"rsum": float(season.get("user_rating_sum", 0.0)), "games": int(season.get("user_rating_games", 0)),
	}

## Lo que hiciste desde la foto del inicio de mes.
static func month_line(player: PlayerData, season: Dictionary, snap: Dictionary) -> Dictionary:
	var games: int = int(season.get("user_rating_games", 0)) - int(snap.get("games", 0))
	var rsum: float = float(season.get("user_rating_sum", 0.0)) - float(snap.get("rsum", 0.0))
	return {
		"games": games,
		"goals": maxi(player.season_goals - int(snap.get("goals", 0)), 0),
		"assists": maxi(player.season_key_passes - int(snap.get("assists", 0)), 0),
		"avg": rsum / float(games) if games > 0 else 0.0,
	}

static func month_score(role: String, line: Dictionary) -> float:
	var w: Array = POTM_WEIGHTS.get(role, POTM_WEIGHTS["MF"])
	return float(line.goals) * float(w[0]) + float(line.assists) * float(w[1]) + (float(line.avg) - 6.5) * float(w[2])

## Listón del mes: el mejor rival de tu liga ese mes (más alto en ligas fuertes).
static func rival_bar(league_rep: int, rng: RandomNumberGenerator) -> float:
	return POTM_BASE + float(league_rep - 60) / 40.0 * 0.6 + rng.randf_range(POTM_SPREAD.x, POTM_SPREAD.y)

## Resultado del mes: {winner: bool, nominee: bool, line, score, bar}. {} si no hubo bastantes partidos.
static func judge_month(role: String, line: Dictionary, league_rep: int, rng: RandomNumberGenerator) -> Dictionary:
	if int(line.get("games", 0)) < POTM_MIN_GAMES:
		return {}
	var sc: float = month_score(role, line)
	var bar: float = rival_bar(league_rep, rng)
	return {"winner": sc >= bar, "nominee": sc >= bar * POTM_NOMINEE, "line": line, "score": sc, "bar": bar}

## Premio ganado: reputación y ánimo.
static func apply_potm(player: PlayerData, season: Dictionary, month: int) -> void:
	player.reputation = clampi(player.reputation + POTM_REP, 0, 100)
	player.mood = clampi(player.mood + POTM_MOOD, 0, 100)
	var wins: Array = season.get("potm_wins", [])
	wins.append(MONTHS[clampi(month, 1, 12)])
	season["potm_wins"] = wins

## ¿Entras en el equipo de la temporada de tu liga?
static func in_tots(role: String, avg: float, games: int, club_league_games: int) -> bool:
	if club_league_games <= 0 or float(games) < float(club_league_games) * TOTS_MIN_SHARE:
		return false
	return avg >= float(TOTS_RATING.get(role, 7.2))

## Puntuación Golden Boy de un jugador: nivel, margen de crecimiento y temporada.
static func gb_score(overall: int, potential: int, season_bonus: float) -> float:
	return float(overall) + float(maxi(potential - overall, 0)) * 0.25 + season_bonus

## Plus de tu temporada (nota, goles, asistencias) escalado por el nivel de tu liga.
static func gb_user_bonus(avg: float, goals: int, assists: int, league_rep: int) -> float:
	var perf: float = clampf((avg - 6.6) * 4.0, -3.0, 6.0) + float(goals) * 0.12 + float(assists) * 0.08
	return perf * clampf(float(league_rep) / 80.0, 0.6, 1.2)

## Media máxima creíble de un rival sub-21 según su edad (18 → 76, 21 → 82).
static func gb_age_cap(age: int) -> int:
	return 40 + 2 * age

## Tu puesto en el Golden Boy (1 = ganador) frente a las puntuaciones rivales.
static func gb_rank(user_score: float, rival_scores: Array) -> int:
	var better := 0
	for s in rival_scores:
		if float(s) > user_score:
			better += 1
	return better + 1

## Puntuaciones de los mejores sub-21 de los clubes más fuertes del mundo
## (plantillas deterministas de WorldFactory; temporada simulada con un plus al azar).
static func gb_rivals(world: Dictionary, user_club_id: String, rng: RandomNumberGenerator) -> Array:
	var meta: Dictionary = world.get("club_meta_by_id", {})
	var ids: Array = meta.keys()
	ids.sort_custom(func(a, b): return int(meta[a].get("base_overall", 0)) > int(meta[b].get("base_overall", 0)))
	var out: Array = []
	for cid in ids.slice(0, GB_RIVAL_CLUBS):
		if String(cid) == user_club_id:
			continue
		for p in WorldFactory.make_squad(meta[cid]):
			if p.age <= GB_MAX_AGE:
				# Las plantillas generadas reparten la edad al azar: un "juvenil"
				# de 86 en un grande no es creíble, así que se limita por edad.
				var ov: int = mini(p.overall, gb_age_cap(p.age))
				out.append(gb_score(ov, maxi(p.potential, ov), rng.randf_range(-1.0, 4.0)))
	out.sort()
	out.reverse()
	return out.slice(0, 10)
