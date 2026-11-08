extends RefCounted
class_name HonorsEngine

## Detecta los TÍTULOS y HONORES que ganó el jugador en la temporada que
## termina, para el gabinete de trofeos (PlayerData.career_titles, schema
## v20). Se llama una vez en WorldTickEngine._finish_season_rollover(),
## ANTES de resetear los contadores de temporada.
##
## Cada entrada devuelta: {id, name, kind, season, metal}
##   kind ∈ team | continental | world | individual  (decide la silueta)
##   metal 1/2/3 = oro/plata/bronce
##
## Los "mundiales" (clubes / selecciones) y supercopas no tienen soporte
## de mundo todavía (Fase 10 aplazada) — el arte del trofeo existe
## (Trophy.HONOR_IDS) pero acá no se detectan hasta que el modelo de mundo
## los incluya.

## `wte` = instancia de WorldTickEngine (autoload). Se pasa explícito para
## poder testear con un doble.
static func collect_season(wte, player: PlayerData, season_year: int) -> Array:
	var out: Array = []
	if player == null or wte == null:
		return out
	var user_club_id: String = String(wte.user_club_id)
	if user_club_id == "":
		return out

	var league_id: int = int(wte.season.get("league_id", -1))
	var league: LeagueData = null
	for lg in wte.world.get("leagues", []):
		if lg.league_id == league_id:
			league = lg
			break
	var league_name: String = league.league_name if league != null else "Liga"
	var country: String = league.country if league != null else ""

	# --- Liga ---
	var table: Array = wte.table_for_league(league_id)
	var my_row: Dictionary = LeagueTable.row_for(table, user_club_id)
	if not my_row.is_empty() and int(my_row.get("pos", 99)) == 1:
		out.append(_entry("league_%d" % league_id, "%s" % league_name, "team", season_year, 1))

	# --- Copa doméstica ---
	var cup: Dictionary = wte.cup_for_league(league_id)
	if SeasonReportEngine.cup_champion_club_id(cup) == user_club_id:
		out.append(_entry("dcup_%s" % country, CompetitionNames.domestic_cup(country), "team", season_year, 1))

	# --- Copa continental de clubes ---
	# Bug real de la auditoría (ronda 3, pago doble): si el usuario ya ganó
	# esta copa JUGÁNDOLA, WorldTickEngine._award_continental_title() ya
	# la anotó y pagó al instante (id "continental_playable", vivo en
	# _record_continental_result). _finish_season_rollover() pasa la lista
	# COMPLETA que devuelve esta función a PrizeMoneyEngine.for_honors()
	# sin mirar qué ya se había agregado antes — así que volver a devolver
	# el mismo título acá (con OTRO id, "cont_%s_%d") pagaba la prima DOS
	# veces y dejaba un trofeo duplicado en la vitrina. Si ya hay un honor
	# "continental" para esta misma temporada, no se vuelve a generar.
	# Ojo: filtrar por id específico "continental_playable" (el que escribe
	# _award_continental_title()), NO por kind=="continental" genérico —
	# _award_national_cup_title() (copa continental de SELECCIONES,
	# id "natcup_%s") también usa kind:"continental", y un título de
	# selección en la misma temporada bloqueaba por error la detección de
	# la copa de CLUBES (falso positivo encontrado en auto-auditoría).
	var conf: String = Confederations.confederation_of(country)
	if conf != "":
		var already_won_live: bool = false
		for t in player.career_titles:
			if String(t.get("id", "")) == "continental_playable" and int(t.get("season", -1)) == season_year:
				already_won_live = true
				break
		if not already_won_live:
			for tier in range(1, Confederations.tier_count(conf) + 1):
				var cc: Dictionary = wte.continental_cup_for(conf, tier)
				if cc.is_empty():
					continue
				if SeasonReportEngine.cup_champion_club_id(cc) == user_club_id:
					out.append(_entry(
						"cont_%s_%d" % [conf, tier],
						CompetitionNames.continental(conf, tier),
						"continental", season_year, 1))

	# --- Bota de Oro / máximo goleador de la liga ---
	var perf: Dictionary = wte.top_performers_for_league(league_id)
	var scorers: Array = perf.get("scorers", [])
	if not scorers.is_empty() and String(scorers[0].get("name", "")) == player.player_name:
		out.append(_entry("goleador_liga_%d" % league_id, "Máximo goleador · %s" % league_name, "individual", season_year, 1))
	var assisters: Array = perf.get("assists", [])
	if not assisters.is_empty() and String(assisters[0].get("name", "")) == player.player_name:
		out.append(_entry("asist_liga_%d" % league_id, "Máximo asistidor · %s" % league_name, "individual", season_year, 1))

	# --- Premios mundiales del año (YearAwardsEngine) ---
	var ya: Dictionary = wte.year_awards()
	if YearAwardsEngine.user_rank(ya.get("shoe", [])) == 1:
		out.append(_entry("bota_oro_mundial", "Bota de Oro", "individual", season_year, 1))
	if YearAwardsEngine.user_rank(ya.get("assists", [])) == 1:
		out.append(_entry("asistidor_mundial", "Rey de las asistencias", "individual", season_year, 1))
	var gk_rank: int = YearAwardsEngine.user_rank(ya.get("keepers", []))
	if gk_rank == 1:
		out.append(_entry("guante_oro", "Guante de Oro", "individual", season_year, 1))
	elif gk_rank in [2, 3]:
		out.append(_entry("guante_oro_podio", "Podio del Guante de Oro", "individual", season_year, gk_rank))
	if YearAwardsEngine.user_rank(ya.get("xi", [])) > 0:
		out.append(_entry("once_mundial", "Once ideal del año", "individual", season_year, 1))

	# --- Balón de Oro / MVP / 11 ideal (ranking mundial de jugadores) ---
	var bd: Array = wte.ballon_dor_ranking()
	var my_club_name: String = ""
	var my_club := WorldFactory.find_club(wte.world, user_club_id)
	if my_club != null:
		my_club_name = my_club.club_name
	var world_rank: int = -1
	var league_rank: int = -1
	var seen_in_league: int = 0
	for i in range(bd.size()):
		var r: Dictionary = bd[i]
		var same_league: bool = league != null and String(r.get("league_name", "")) == league_name
		if same_league:
			seen_in_league += 1
		if String(r.get("name", "")) == player.player_name and String(r.get("club_name", "")) == my_club_name:
			world_rank = i
			league_rank = seen_in_league
			break
	if world_rank == 0:
		out.append(_entry("ballon_dor", "Balón de Oro", "individual", season_year, 1))
	elif world_rank in [1, 2]:
		out.append(_entry("ballon_dor_podio", "Podio del Balón de Oro", "individual", season_year, 2 if world_rank == 1 else 3))
	if league_rank == 1:
		out.append(_entry("mvp_liga_%d" % league_id, "MVP de %s" % league_name, "individual", season_year, 1))
	# Equipo de la temporada (SeasonAwardsEngine): por goles+asistencias del
	# ranking O por nota media según tu puesto — así entran porteros y defensas.
	var r_games: int = int(wte.season.get("user_rating_games", 0))
	var r_avg: float = float(wte.season.get("user_rating_sum", 0.0)) / float(maxi(r_games, 1))
	var tots: bool = SeasonAwardsEngine.in_tots(player.position, r_avg, r_games, int(my_row.get("pj", 0)))
	if (league_rank != -1 and league_rank <= 11) or tots:
		out.append(_entry("once_ideal_%d" % league_id, "Equipo de la temporada · %s" % league_name, "individual", season_year, 2))

	# --- Jugador del mes (los meses ganados esta temporada) ---
	var potm: Array = wte.season.get("potm_wins", [])
	if not potm.is_empty():
		var pname: String = ("Jugador del mes (%s)" % String(potm[0])) if potm.size() == 1 else ("Jugador del mes ×%d" % potm.size())
		out.append(_entry("potm_%d" % league_id, "%s · %s" % [pname, league_name], "individual", season_year, 1))

	# --- Golden Boy: mejor sub-21 del mundo (la edad ya subió en el rollover) ---
	if player.age - 1 <= SeasonAwardsEngine.GB_MAX_AGE:
		var gb_rng := RandomNumberGenerator.new()
		gb_rng.seed = hash("golden_boy:%d" % season_year) ^ int(wte.world_seed)
		var rivals: Array = SeasonAwardsEngine.gb_rivals(wte.world, user_club_id, gb_rng)
		var lrep: int = league.reputation if league != null else 60
		var gb_bonus: float = SeasonAwardsEngine.gb_user_bonus(r_avg if r_games > 0 else 6.0, player.season_goals, player.season_key_passes, lrep)
		var mine: float = SeasonAwardsEngine.gb_score(player.overall, player.potential, gb_bonus)
		var gb_pos: int = SeasonAwardsEngine.gb_rank(mine, rivals)
		if gb_pos == 1:
			out.append(_entry("golden_boy", "Golden Boy", "individual", season_year, 1))
		elif gb_pos <= 3:
			out.append(_entry("golden_boy_podio", "Podio del Golden Boy", "individual", season_year, gb_pos))

	return out

## Añade a `player.career_titles` los honores nuevos (dedupe por id+season).
## Devuelve cuántos se agregaron.
static func record(player: PlayerData, entries: Array) -> int:
	if player == null or entries.is_empty():
		return 0
	var existing := {}
	for t in player.career_titles:
		existing["%s|%s" % [String(t.get("id", "")), str(t.get("season", 0))]] = true
	var added := 0
	for e in entries:
		var key := "%s|%s" % [String(e.get("id", "")), str(e.get("season", 0))]
		if existing.has(key):
			continue
		player.career_titles.append(e)
		existing[key] = true
		added += 1
	return added

static func _entry(id: String, name: String, kind: String, season_year: int, metal: int) -> Dictionary:
	return {"id": id, "name": name, "kind": kind, "season": season_year, "metal": metal}

## honor_id de Trophy.HONOR_IDS para una entrada del gabinete — decide la
## silueta del trofeo a dibujar.
static func trophy_key_for(entry: Dictionary) -> String:
	var id: String = String(entry.get("id", ""))
	if id == "ballon_dor" or id == "ballon_dor_podio":
		return "ballon_dor"
	if id.begins_with("botaoro") or id == "bota_oro_mundial":
		return "bota_oro"
	if id.begins_with("goleador_liga"):
		return "max_goleador"
	if id.begins_with("asist"):
		return "mvp_liga"
	if id.begins_with("guante_oro"):
		return "guante_oro"
	if id == "once_mundial":
		return "once_ideal"
	if id.begins_with("mvp_liga"):
		return "mvp_liga"
	if id.begins_with("once_ideal"):
		return "once_ideal"
	if id.begins_with("potm_"):
		return "mvp_match"
	if id.begins_with("golden_boy"):
		return "mvp_temporada"
	if id == "world_cup":
		return "mundial_seleccion"
	if id.begins_with("natcup_"):
		return id
	if id.begins_with("cont_"):
		return id
	if id == "supercopa" or id == "supercopa_cont":
		return id
	match String(entry.get("kind", "")):
		"continental": return "continental_cup"
		"world": return "mundial_clubes"
		_: return ""  # team -> cup genérico por `id`
