extends RefCounted
class_name WorldNewsEngine

## Titulares del MUNDO (no del jugador): líderes de liga, goleadores,
## fichajes, torneos continentales, la liga del usuario. Se DERIVAN del
## estado ya calculado del mundo vivo (WorldTickEngine) — nada se
## persiste, mismo criterio que los resultados de IA. Se mezclan con
## `player.press_feed` en la pantalla de Noticias.
##
## Cada entrada tiene la misma forma que press_feed:
##   {headline, body, source, sentiment, day, world: true}

const _SOURCES := ["DEPORTE TOTAL", "GOLAZO TV", "LA JUGADA", "TRIBUNA", "ESTADIO 24", "CANCHA+", "FÚTBOL HOY", "PITCH RADIO"]

## Titulares de la semana actual (estables durante los 7 días).
static func weekly(wte, player: PlayerData, day: int) -> Array:
	if wte == null or player == null or wte.world.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	var week: int = CalendarUtils.week_index(day)
	rng.seed = hash("worldnews|%d" % week) ^ int(wte.world_seed)
	var out: Array = []
	var leagues: Array = wte.world.get("leagues", [])
	if leagues.is_empty():
		return []

	# --- Líder de 2-3 ligas al azar ---
	var picks: Array = _sample(leagues, mini(3, leagues.size()), rng)
	for lg in picks:
		var table: Array = wte.table_for_league(lg.league_id)
		if table.size() < 2:
			continue
		var leader: String = _club_name(wte, String(table[0].get("club_id", "")))
		var second: String = _club_name(wte, String(table[1].get("club_id", "")))
		var pj: int = int(table[0].get("pj", 0))
		if pj == 0:
			out.append(_mk(rng, "Arranca %s" % lg.league_name,
				"Comienza una nueva temporada de %s (%s). %s y %s parten entre los candidatos." % [lg.league_name, lg.country, leader, second],
				"NEUTRAL", day))
		else:
			out.append(_mk(rng, "%s manda en %s" % [leader, lg.league_name],
				"Tras %d fechas, %s lidera %s con %d puntos; %s aprieta desde atrás." % [pj, leader, lg.league_name, int(table[0].get("pts", 0)), second],
				"NEUTRAL", day))

	# --- Goleador de una liga ---
	var glg = leagues[rng.randi() % leagues.size()]
	var perf: Dictionary = wte.top_performers_for_league(glg.league_id)
	var scorers: Array = perf.get("scorers", [])
	if not scorers.is_empty():
		var s0: Dictionary = scorers[0]
		var g: int = int(s0.get("goals", 0))
		if g >= 3:
			out.append(_mk(rng, "%s no para de convertir" % String(s0.get("name", "?")),
				"%s (%s) es el máximo goleador de %s con %d tantos esta temporada." % [
					String(s0.get("name", "?")), String(s0.get("club_name", "")), glg.league_name, g],
				"POSITIVE", day))

	# --- Fichaje destacado del mercado ---
	# Solo de los YA revueltos a esta altura ("day" — ver TransferMarketEngine
	# .generate_season_transfers) — sin esto la prensa podía espoilear un
	# fichaje que la pantalla de Mercado todavía no reveló.
	var season_start: int = int(wte.season.get("season_start_epoch_day", 0))
	var all_transfers: Array = TransferMarketEngine.season_transfers_cached(wte.world, wte.world_seed, season_start)
	var transfers: Array = all_transfers.filter(func(tr): return int(tr.get("day", 0)) <= day)
	if not transfers.is_empty():
		var t: Dictionary = transfers[rng.randi() % transfers.size()]
		out.append(_mk(rng, "%s cambia de aire" % String(t.get("player_name", "Un jugador")),
			"%s deja %s para firmar con %s por %s." % [
				String(t.get("player_name", "")), _club_name(wte, String(t.get("origin_club_id", ""))),
				_club_name(wte, String(t.get("destination_club_id", ""))), CurrencyFormat.format(int(t.get("fee", 0)))],
			"NEUTRAL", day))

	# --- La liga del usuario: dónde está su club ---
	if player.club_id != "":
		var ut: Array = wte.user_league_table()
		var myrow: Dictionary = LeagueTable.row_for(ut, player.club_id)
		if not myrow.is_empty() and int(myrow.get("pj", 0)) > 0:
			var pos: int = int(myrow.get("pos", 0))
			var sent := "POSITIVE" if pos <= 4 else ("CRITICAL" if pos >= ut.size() - 3 else "NEUTRAL")
			var club_name: String = _club_name(wte, player.club_id)
			var phrase := "pelea arriba" if pos <= 4 else ("está complicado en el fondo" if sent == "CRITICAL" else "se mantiene en zona media")
			out.append(_mk(rng, "%s, %dº en la tabla" % [club_name, pos],
				"%s %s tras %d fechas. La afición sigue de cerca cada partido." % [club_name, phrase, int(myrow.get("pj", 0))],
				sent, day))

	# --- DT destituido en alguna liga (el club del fondo que no levanta) ---
	for lg2 in _sample(leagues, mini(2, leagues.size()), rng):
		var t2: Array = wte.table_for_league(lg2.league_id)
		if t2.size() < 6:
			continue
		if int(t2[0].get("pj", 0)) < 8:
			continue  # muy pronto en la temporada para destituir a nadie
		var loser_id: String = String(t2[t2.size() - 1].get("club_id", ""))
		if loser_id == "" or loser_id == player.club_id:
			continue  # al DT del club del usuario lo maneja CoachChangeEngine
		var sack_rng := RandomNumberGenerator.new()
		sack_rng.seed = hash("worldsack|%d|%s" % [week, loser_id]) ^ int(wte.world_seed)
		if sack_rng.randf() > 0.28:
			continue
		var loser_name: String = _club_name(wte, loser_id)
		var old_coach: CoachData = WorldFactory.find_coach(wte.world, loser_id)
		var old_nm: String = old_coach.coach_name if old_coach != null else "su entrenador"
		var new_nm: String = WorldFactory.synthetic_person_name(hash("worldsack_new|%d|%s" % [week, loser_id]) ^ int(wte.world_seed))
		out.append(_mk(rng, "%s destituye a %s" % [loser_name, old_nm],
			"Último en %s, %s busca una reacción: %s se hace cargo del banquillo esta semana." % [lg2.league_name, loser_name, new_nm],
			"CRITICAL", day - rng.randi_range(0, 4)))

	# --- Nota de color continental ---
	var conf: String = Confederations.confederation_of(_user_country(wte, player))
	if conf != "":
		out.append(_mk(rng, "Se acerca la fase decisiva en %s" % CompetitionNames.continental(conf, 1),
			"Los cruces de %s empiezan a definir a los candidatos al título continental." % CompetitionNames.continental(conf, 1),
			"NEUTRAL", day - rng.randi_range(0, 3)))

	return out

static func _mk(rng: RandomNumberGenerator, headline: String, body: String, sentiment: String, day: int) -> Dictionary:
	return {
		"headline": headline, "body": body, "sentiment": sentiment,
		"source": _SOURCES[rng.randi() % _SOURCES.size()], "day": day, "world": true,
	}

static func _club_name(wte, club_id: String) -> String:
	var c: ClubData = WorldFactory.find_club(wte.world, club_id)
	return c.club_name if c != null else club_id

static func _user_country(wte, player: PlayerData) -> String:
	if player.club_id == "":
		return ""
	var c: ClubData = WorldFactory.find_club(wte.world, player.club_id)
	if c == null:
		return ""
	for lg in wte.world.get("leagues", []):
		if lg.league_id == c.league_id:
			return lg.country
	return ""

static func _sample(arr: Array, n: int, rng: RandomNumberGenerator) -> Array:
	var copy: Array = arr.duplicate()
	var out: Array = []
	for i in range(mini(n, copy.size())):
		out.append(copy.pop_at(rng.randi() % copy.size()))
	return out
