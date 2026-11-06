extends Node
## Simulación headless de 10 temporadas con reporte COMPLETO: evolución
## del jugador, club por temporada, resultado de TODAS las competiciones
## (liga, copa doméstica, copa(s) continentales, supercopa, mundial de
## clubes) y ganador de cada premio individual — no solo lo que ganó el
## usuario. Pedido explícito de Wilber: "quiero todos los datos posibles".
##
## Ejecutar:  godot --headless res://tools/TenSeasonSim.tscn
## Escribe user://ten_season_report.json. USA slot_3 (desechable).

const SLOT := "slot_3"
const WORLD_SEED := 20260906
## true = usa el mundo IMPORTADO (user://imported_world.json, el archivo
## real que Wilber pidió simular: "corré con el json FL26-27...") en vez
## del procedural determinista de siempre. false = procedural (WORLD_SEED).
const USE_IMPORTED_WORLD := true
const SEASONS := 10
const SAFETY_DAYS := 9000

var _report := {"seasons": [], "matches": [], "meta": {}}
var _prev := {}
var _prev_league_tiers := {}  # club_id -> league_id, para detectar ascensos/descensos NUEVOS entre snapshots

func _ready() -> void:
	await get_tree().process_frame
	_run()

func _run() -> void:
	var world_seed: int = WorldFactory.IMPORTED_SEED if (USE_IMPORTED_WORLD and WorldFactory.has_imported_world()) else WORLD_SEED
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = WORLD_SEED   # los atributos iniciales del jugador siguen con semilla propia, aparte del mundo
	seed(WORLD_SEED)

	SaveManager.active_slot_id = SLOT
	SaveManager.save_slot(SLOT, {})
	SaveManager.save_world_seed(world_seed)

	WorldFactory.clear_imported_world_cache()
	var world := WorldFactory.build(world_seed)
	print("mundo: ", ("IMPORTADO" if world_seed == WorldFactory.IMPORTED_SEED else "procedural (%d)" % world_seed))

	var p := PlayerData.new()
	p.player_name = "Sim Tester"
	p.country = "Argentina"
	p.position = "ST"
	p.detailed_position = Positions.default_detailed_for_broad("ST")
	p.dominant_foot = "Derecho"
	p.origin = "Cantera de club grande"
	p.age = 18
	p.birth_epoch_day = -18 * 365
	p.overall = 78
	p.potential = 91
	for stat in ["speed", "stamina", "strength", "control", "passing", "shooting", "dribbling", "decision_making", "composure"]:
		p.set(stat, clampi(78 + seed_rng.randi_range(-4, 8), 55, 96))
	p.leadership = 62
	p.reputation = 55
	p.market_value = TransferMarketEngine.market_value(p.overall, p.potential, p.age)
	p.ensure_potential_floor()

	var arg: LeagueData = WorldFactory.find_league_for_country(world, "Argentina")
	if arg == null:
		# El mundo importado podría no tener Argentina en tier 1 (formato
		# real puede variar) — cae a la primera liga de primera que haya.
		for lg in world.get("leagues", []):
			if lg.tier == 1:
				arg = lg
				break
	if arg == null:
		arg = world.get("leagues", [])[0]
		p.country = arg.country
	var clubs: Array = world.get("clubs_by_league", {}).get(arg.league_id, [])
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	clubs = clubs.duplicate()
	clubs.sort_custom(func(a, b): return int(meta_by_id.get(a.club_id, {}).get("base_overall", 55)) > int(meta_by_id.get(b.club_id, {}).get("base_overall", 55)))
	var club: ClubData = clubs[clampi(int(clubs.size() * 0.5), 0, clubs.size() - 1)]
	p.club_id = club.club_id
	p.wage = ContractEngine.starting_wage(int(meta_by_id.get(club.club_id, {}).get("base_overall", 60)), arg.reputation)
	p.contract_years_remaining = ContractEngine.STARTING_CONTRACT_YEARS
	p.balance = 200
	SaveManager.save_player(p)

	var season := SeasonCalendar.build_season(world, int(arg.league_id), 0, CalendarUtils.season_start_year(0), p.club_id, world_seed)
	var orng := RandomNumberGenerator.new(); orng.seed = WORLD_SEED
	season["player_objective"] = ObjectivesEngine.generate_player_objective(p, orng)
	SaveManager.save_season(season)
	WorldTickEngine.load_runtime()

	_report["meta"] = {
		"world_seed": world_seed, "start_club": club.club_name, "start_club_id": club.club_id,
		"start_league": arg.league_name, "start_league_id": arg.league_id,
		"start_overall": p.overall, "start_potential": p.potential, "start_age": p.age,
	}
	_prev = _career_totals()

	var seasons_done := 0
	var guard := 0
	var matches_this_season := 0
	# Capturado el día ANTERIOR a que el rollover reconstruya `season` de
	# cero (tabla de liga, cuadro de copa, continental, premios: todo eso
	# se vuelve ilegible una vez que WorldTickEngine.season ya es la
	# temporada NUEVA). El motor NO expone un hook a mitad de rollover, así
	# que este sim avanza día a día (en vez de con advance_until en saltos
	# grandes, que es lo que hace la pantalla real) para poder mirar
	# exactamente ese último día. Esto es SOLO para la herramienta de
	# reporte, nunca duplica advance_day() en sí (fuente única de avance,
	# ver CLAUDE.md) — cada día real lo sigue resolviendo advance_day().
	var pending_snapshot: Dictionary = {}
	while seasons_done < SEASONS and guard < SAFETY_DAYS:
		guard += 1
		var season_end_day: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0)) + SeasonCalendar.SEASON_TOTAL_DAYS
		if WorldTickEngine.current_epoch_day == season_end_day and not WorldTickEngine.season.get("awaiting_contract_decision", false):
			pending_snapshot = _capture_competition_snapshot()

		WorldTickEngine.advance_day()

		if WorldTickEngine.season.get("awaiting_contract_decision", false):
			if pending_snapshot.is_empty():
				pending_snapshot = _capture_competition_snapshot()
			if not _handle_contract():
				seasons_done += 1
				_snapshot(seasons_done, "RETIRO", pending_snapshot)
				break
			if not WorldTickEngine.last_season_report.is_empty():
				seasons_done += 1
				_snapshot(seasons_done, "", pending_snapshot)
				_print_season_line(seasons_done, matches_this_season)
				matches_this_season = 0
				WorldTickEngine.last_season_report = {}
				_flush_report()
			pending_snapshot = {}
			continue

		if not WorldTickEngine.last_season_report.is_empty():
			seasons_done += 1
			_snapshot(seasons_done, "", pending_snapshot)
			_print_season_line(seasons_done, matches_this_season)
			matches_this_season = 0
			pending_snapshot = {}
			WorldTickEngine.last_season_report = {}
			_flush_report()
			var pp := SaveManager.load_player()
			if pp != null and pp.club_id == "":
				break
			continue

		var fx: Dictionary = WorldTickEngine.pending_user_fixture()
		if not fx.is_empty():
			matches_this_season += 1
			await _sim_user_match()

	if guard >= SAFETY_DAYS:
		print("  !! tope de seguridad alcanzado (posible loop sin fixture)")

	_report["meta"]["days_simulated"] = WorldTickEngine.current_epoch_day
	_report["meta"]["guard_hit"] = guard >= SAFETY_DAYS
	_flush_report()
	print("SIM OK — %d temporadas, %d días, %d partidos jugados" % [
		seasons_done, WorldTickEngine.current_epoch_day, _report["matches"].size()])
	get_tree().quit()

func _flush_report() -> void:
	var f := FileAccess.open("user://ten_season_report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "\t"))
	f.close()

func _print_season_line(idx: int, matches: int) -> void:
	var sp: PlayerData = SaveManager.load_player()
	var s: Dictionary = _report["seasons"][_report["seasons"].size() - 1]
	print("  [T%d] día %d · %d PJ · %s · media %d · %da · %dG %dA · liga:%s copa:%s" % [
		idx, WorldTickEngine.current_epoch_day, matches, String(s["club"]),
		int(sp.overall), int(sp.age), int(s["season_goals"]), int(s["season_assists"]),
		String(s["league"]["result"]), String(s["domestic_cup"]["result"])])

func _handle_contract() -> bool:
	var ro: Dictionary = WorldTickEngine.season.get("renewal_offer", {})
	var offers: Array = WorldTickEngine.season.get("transfer_offers", [])

	if offers.is_empty():
		if ro.has("club_id") and String(ro["club_id"]) != "":
			WorldTickEngine.resolve_contract_decision(String(ro["club_id"]), int(ro.get("wage", 200)))
			return true
		return false

	# Jugador AMBICIOSO: elige por REPUTACIÓN (club/liga más grande), el
	# sueldo solo desempata entre ofertas de reputación pareja -- antes
	# elegía por sueldo más alto y encima renovaba a ciegas el 55% de las
	# veces aun con ofertas mejores sobre la mesa, así que la carrera casi
	# nunca escalaba a un club de verdad grande (Wilber jugando: "nunca
	# llego a un gran club" -- esto era la mitad del problema, la otra
	# mitad ya se corrigió en CareerSetup.generate_offers()).
	var best_idx: int = 0
	var best_rep: int = -1
	var best_wage: int = -1
	for i in range(offers.size()):
		var rep: int = int(offers[i].get("reputation", 0))
		var w: int = int(offers[i].get("wage", 0))
		if rep > best_rep or (rep == best_rep and w > best_wage):
			best_rep = rep
			best_wage = w
			best_idx = i
	var best: Dictionary = offers[best_idx]

	# Renovar solo si la mejor oferta externa NO es una mejora real de
	# categoría (tolerancia de +3 de reputación para no forzar un cambio
	# por una diferencia insignificante) -- si te ofrecen algo claramente
	# más grande, un jugador ambicioso se va.
	var current_rep: int = 0
	if ro.has("club_id") and String(ro["club_id"]) != "":
		var cur_club := WorldFactory.find_club(WorldTickEngine.world, String(ro["club_id"]))
		if cur_club != null:
			var cur_lg := WorldTickEngine._find_league(cur_club.league_id)
			if cur_lg != null:
				current_rep = cur_lg.reputation
		if best_rep <= current_rep + 3:
			WorldTickEngine.resolve_contract_decision(String(ro["club_id"]), int(ro.get("wage", 200)))
			return true

	WorldTickEngine.resolve_contract_decision(String(best.get("club_id", "")), int(best.get("wage", 200)))
	return true

func _career_totals() -> Dictionary:
	var p := SaveManager.load_player()
	if p == null:
		return {"g": 0, "a": 0, "m": 0, "t": 0}
	return {"g": p.career_goals, "a": p.career_assists, "m": p.career_matches, "t": p.trophies_won}

func _sim_user_match() -> void:
	var wte := WorldTickEngine
	var club_id: String = wte.user_club_id
	var fx: Dictionary = wte.user_fixture_on(wte.current_epoch_day, club_id)
	if fx.is_empty():
		fx = wte.next_user_fixture(club_id)
	if fx.is_empty():
		return
	var world: Dictionary = wte.world
	var p := SaveManager.load_player()
	var home_id: String = String(fx.get("home_club_id", ""))
	var away_id: String = String(fx.get("away_club_id", ""))
	var home_club := WorldFactory.find_club(world, home_id)
	var away_club := WorldFactory.find_club(world, away_id)
	if home_club == null or away_club == null:
		return
	var season_start: int = int(wte.season.get("season_start_epoch_day", 0))
	var home_squad := WorldFactory.make_squad_with_transfers(world, home_id, wte.world_seed, season_start)
	var away_squad := WorldFactory.make_squad_with_transfers(world, away_id, wte.world_seed, season_start)
	var user_is_home: bool = home_id == p.club_id
	var start_chance: float = CoachRelations.start_chance(p.coach_trust)
	var hc := WorldFactory.find_coach(world, home_id)
	var ac := WorldFactory.find_coach(world, away_id)
	var home_team := MatchTeam.from_club(home_club, home_squad, p if user_is_home else null, start_chance if user_is_home else 0.0, hc.formation if hc else "")
	var away_team := MatchTeam.from_club(away_club, away_squad, null if user_is_home else p, 0.0 if user_is_home else start_chance, ac.formation if ac else "")
	var is_ko: bool = bool(fx.get("is_knockout", false))
	MatchState.start_new_match(home_team, away_team, p, is_ko, true)
	MatchState.fixture = fx
	if fx.has("tie_agg"):
		var ta = fx["tie_agg"]
		if ta is Dictionary:
			MatchState.engine.set_tie_aggregate(int(ta.get("home", 0)), int(ta.get("away", 0)))
	var result: Dictionary = await MatchState.engine.run_match()

	var sc: Dictionary = result.get("score", {})
	var gh: int = int(sc.get("home", 0))
	var ga: int = int(sc.get("away", 0))
	var winner: String = String(result.get("shootout_winner", ""))
	if winner == "":
		winner = "home" if gh >= ga else "away"
	var comp: String = String(fx.get("competition", "league"))
	var is_friendly: bool = comp == "friendly"
	var started: bool = home_team.starting_xi.has(p) or away_team.starting_xi.has(p)
	var goals_m := 0
	var assists_m := 0
	for ev in result.get("rating_events", []):
		match String(ev.get("type", "")):
			"goal": goals_m += 1
			"key_pass_success": assists_m += 1
	var rating: float = float(result.get("user_rating", 6.0))

	if started and not is_friendly:
		p.season_appearances += 1
		p.season_goals += goals_m
		p.season_key_passes += assists_m
		wte.season["user_rating_sum"] = float(wte.season.get("user_rating_sum", 0.0)) + rating
		wte.season["user_rating_games"] = int(wte.season.get("user_rating_games", 0)) + 1
		SaveManager.save_season(wte.season)
	if result.get("user_injured", false) and p.injury_days_remaining <= 0:
		var irng := RandomNumberGenerator.new()
		irng.seed = hash("injury:%d" % wte.current_epoch_day) ^ wte.world_seed
		p.injury_days_remaining = maxi(1, int(round(PlayerDevelopment.roll_injury_days(irng) * StaffEngine.injury_factor(p))))
	# XP de atributos por el partido (MISMO cálculo que MatchSummary._apply_
	# match_consequences — el sim se saltaba esto y por eso la media no
	# subía nada tras el fix del 12-sep que sacó el tick semanal duplicado).
	if not MatchState.user_suspended:
		var xp_gains: Dictionary = PlayerDevelopment.match_xp_gains(p, rating, goals_m, assists_m)
		if is_friendly:
			for k in xp_gains:
				xp_gains[k] = float(xp_gains[k]) * 0.5
		PlayerDevelopment.grant_attribute_xp(p, xp_gains)

	var coach := WorldFactory.find_coach(wte.world, p.club_id)
	CoachRelations.apply_match_result(p, coach, rating)
	SaveManager.save_player(p)
	wte.record_user_result(fx, gh, ga, winner)

	_report["matches"].append({
		"day": wte.current_epoch_day, "comp": comp, "ko": is_ko,
		"home": home_club.club_name, "away": away_club.club_name,
		"score": "%d-%d" % [gh, ga], "user_home": user_is_home,
		"started": started, "goals": goals_m, "assists": assists_m,
		"rating": snappedf(rating, 0.1),
	})

## --- Progreso en un cuadro eliminatorio (copa doméstica o continental) ---
## Devuelve {"result": texto legible, "champion_id": String, "reached_round": String}
func _bracket_progress(bracket: Dictionary, club_id: String) -> Dictionary:
	if bracket.is_empty():
		return {"result": "No aplica", "champion_id": "", "reached_round": ""}
	var last_round: String = ""
	var champion_id: String = ""
	for rnd in bracket.get("rounds", []):
		var rn: String = String(rnd.get("round_name", ""))
		# "decided" es una bandera de la RONDA (rnd["decided"], puesta por
		# SeasonEngine.resolve_cup()), no de cada partido -- un partido
		# individual no tiene esa clave, así que m.get("decided", false)
		# siempre caía al default (false) y el campeón nunca se detectaba,
		# ni siquiera cuando la propia final ya se había jugado. Mismo
		# chequeo correcto que ya usa SeasonReportEngine._final_winner()
		# en el juego real (por eso el juego real nunca tuvo este bug).
		var round_decided: bool = bool(rnd.get("decided", false))
		var in_round := false
		for m in rnd.get("matches", []):
			var h: String = String(m.get("home_club_id", ""))
			var a: String = String(m.get("away_club_id", ""))
			if h == club_id or a == club_id:
				in_round = true
			if rn == "Final" and round_decided:
				champion_id = String(m.get("winner_club_id", ""))
		if in_round:
			last_round = rn
	if champion_id == club_id:
		return {"result": "Campeón", "champion_id": champion_id, "reached_round": "Final"}
	if last_round != "":
		return {"result": "Eliminado en %s" % last_round, "champion_id": champion_id, "reached_round": last_round}
	# no llegó a la fase de eliminación directa -- ¿grupos o suizo?
	for g in bracket.get("groups", []):
		var standings: Array = g.get("standings", [])
		for i in range(standings.size()):
			if String(standings[i].get("club_id", "")) == club_id:
				var pos: int = i + 1
				return {"result": "Fase de grupos (%d° de %d)" % [pos, standings.size()], "champion_id": champion_id, "reached_round": "Grupos"}
	var league_phase: Array = bracket.get("league_phase", [])
	for i in range(league_phase.size()):
		if String(league_phase[i].get("club_id", "")) == club_id:
			return {"result": "Fase suiza (%d° de %d)" % [i + 1, league_phase.size()], "champion_id": champion_id, "reached_round": "Suiza"}
	return {"result": "No clasificó", "champion_id": champion_id, "reached_round": ""}

func _club_name(id: String) -> String:
	if id == "":
		return ""
	var c := WorldFactory.find_club(WorldTickEngine.world, id)
	return c.club_name if c != null else id

## Todo lo que hay que leer del MUNDO VIVO (tabla, copas, premios) — hay
## que llamarlo el día ANTERIOR al que el rollover reconstruye
## WorldTickEngine.season desde cero, o si no se lee la temporada NUEVA
## (0 partidos jugados) en vez de la que en realidad terminó. Ver el
## comentario grande en _run().
func _capture_competition_snapshot() -> Dictionary:
	var wte := WorldTickEngine
	var p := SaveManager.load_player()
	if p == null:
		return {}
	var club_id_now: String = wte.user_club_id
	var club := WorldFactory.find_club(wte.world, club_id_now)

	# --- Liga ---
	var league_id: int = int(wte.season.get("league_id", -1))
	var league: LeagueData = wte._find_league(league_id)
	var table: Array = wte.table_for_league(league_id)
	var my_row: Dictionary = LeagueTable.row_for(table, club_id_now)
	var champ_row: Dictionary = table[0] if not table.is_empty() else {}
	var league_info := {
		"name": league.league_name if league != null else "?",
		"position": int(my_row.get("pos", 0)) if not my_row.is_empty() else 0,
		"points": int(my_row.get("pts", 0)) if not my_row.is_empty() else 0,
		"teams": table.size(),
		"champion": _club_name(String(champ_row.get("club_id", ""))) if not champ_row.is_empty() else "?",
		"result": ("Campeón" if int(my_row.get("pos", 99)) == 1 else "%d°/%d" % [int(my_row.get("pos", 0)), table.size()]) if not my_row.is_empty() else "N/D",
	}

	# --- Copa doméstica ---
	var dcup: Dictionary = wte.cup_for_league(league_id)
	var dcup_prog := _bracket_progress(dcup, club_id_now)
	dcup_prog["name"] = CompetitionNames.domestic_cup(league.country) if league != null else "Copa"
	dcup_prog["champion"] = _club_name(dcup_prog["champion_id"])

	# --- Copa(s) continentales del país/confederación ---
	var conf: String = Confederations.confederation_of(league.country) if league != null else ""
	var continental_list: Array = []
	if conf != "":
		for tier in range(1, Confederations.tier_count(conf) + 1):
			var cc: Dictionary = wte.continental_cup_for(conf, tier)
			if cc.is_empty():
				continue
			var prog := _bracket_progress(cc, club_id_now)
			# si "no clasificó" Y el club nunca estuvo en el pool sembrado, se
			# omite (no es "su" torneo esta temporada en ese tier)
			if prog["result"] == "No clasificó":
				continue
			prog["name"] = CompetitionNames.continental(conf, tier)
			prog["champion"] = _club_name(prog["champion_id"])
			continental_list.append(prog)

	# --- Supercopa(s) ---
	var supercups: Array = []
	for kind in (wte.season.get("supercup_results", {}) as Dictionary).keys():
		var r: Dictionary = wte.season["supercup_results"][kind]
		supercups.append({"kind": kind, "result": ("Campeón" if bool(r.get("won", false)) else "Subcampeón"), "score": "%d-%d" % [int(r.get("gh", 0)), int(r.get("ga", 0))]})

	# --- Mundial de clubes ---
	var cwc_info := {"result": "No aplica", "champion": ""}
	if ClubWorldCupEngine.is_cwc_season(int(wte.season.get("start_year", wte.get_season_start_year()))):
		var cwc: Dictionary = wte.cwc_this_season()
		if not cwc.is_empty():
			var prog2 := _bracket_progress(cwc, club_id_now)
			cwc_info["result"] = prog2["result"]
			cwc_info["champion"] = _club_name(String(cwc.get("champion_club_id", "")))

	# --- Premios individuales: GANADOR real (no solo el rango del usuario) ---
	var perf: Dictionary = wte.top_performers_for_league(league_id)
	var scorers: Array = perf.get("scorers", [])
	var assisters: Array = perf.get("assists", [])
	var bd: Array = wte.ballon_dor_ranking()
	var awards := {
		"ballon_dor_winner": String(bd[0].get("name", "?")) if not bd.is_empty() else "?",
		"ballon_dor_winner_club": String(bd[0].get("club_name", "?")) if not bd.is_empty() else "?",
		"bota_oro_winner": String(scorers[0].get("name", "?")) if not scorers.is_empty() else "?",
		"bota_oro_goals": int(scorers[0].get("count", 0)) if not scorers.is_empty() else 0,
		"asistidor_winner": String(assisters[0].get("name", "?")) if not assisters.is_empty() else "?",
		"asistidor_count": int(assisters[0].get("count", 0)) if not assisters.is_empty() else 0,
		"me_ballon_dor_rank": -1,
	}
	for i in range(bd.size()):
		if String(bd[i].get("name", "")) == p.player_name:
			awards["me_ballon_dor_rank"] = i + 1
			break

	# --- Campeón de CADA liga del mundo (no solo la del usuario) — pedido
	# explícito de Wilber: "tooooodos los datos posibles de campeones por
	# ligas". Mismo table_for_league() que ya usa el bloque de arriba.
	var all_leagues: Array = []
	for lg2 in wte.world.get("leagues", []):
		var tbl2: Array = wte.table_for_league(int(lg2.league_id))
		if tbl2.is_empty():
			continue
		all_leagues.append({
			"name": lg2.league_name, "country": lg2.country, "tier": lg2.tier,
			"champion": _club_name(String(tbl2[0].get("club_id", ""))),
		})

	# --- Selecciones: Mundial + copas continentales de selecciones, el
	# año que corresponda (mismo criterio de "año de torneo" que usa
	# _tick_national_trophies()).
	var start_year: int = int(wte.season.get("start_year", wte.get_season_start_year()))
	var national_team := {"world_cup": {"is_year": false, "champion_country": ""}, "national_cups": []}
	if WorldCupEngine.is_wc_year(start_year):
		var wc: Dictionary = wte.world_cup_this_cycle()
		national_team["world_cup"] = {"is_year": true, "champion_country": String(wc.get("champion_country", ""))}
	for nc_conf in Confederations.ALL:
		if NationalCupEngine.is_cup_year(nc_conf, start_year):
			var ncup: Dictionary = wte.national_cup_for(nc_conf)
			national_team["national_cups"].append({
				"confederation": nc_conf, "champion_country": String(ncup.get("champion_country", "")),
			})

	return {
		"start_year": int(wte.season.get("start_year", wte.get_season_start_year())),
		"club_id": club_id_now,
		"club_name": club.club_name if club != null else club_id_now,
		"is_captain": bool(wte.season.get("is_captain", false)),
		"league": league_info, "domestic_cup": dcup_prog, "continental": continental_list,
		"supercups": supercups, "club_world_cup": cwc_info, "awards": awards,
		"all_leagues_champions": all_leagues, "national_team": national_team,
	}

func _snapshot(idx: int, note: String, comp: Dictionary) -> void:
	var p := SaveManager.load_player()
	if p == null:
		return
	var wte := WorldTickEngine
	var cur := _career_totals()
	var lsr: Dictionary = wte.last_season_report
	# `comp` viene de _capture_competition_snapshot(), tomado el día ANTES
	# del rollover — es la única fuente confiable para club/año/torneos de
	# la temporada que ACABA de terminar (wte.season ya es la nueva acá).
	var club_id_then: String = String(comp.get("club_id", p.club_id))
	var club_name_then: String = String(comp.get("club_name", club_id_then))
	var start_year_then: int = int(comp.get("start_year", wte.get_season_start_year() - 1))

	var honors: Array = lsr.get("honors", [])
	var honor_names: Array = []
	for h in honors:
		honor_names.append(String(h.get("name", h)) if h is Dictionary else String(h))
	var new_titles_this_season: Array = []
	for t in p.career_titles:
		if int(t.get("season", -1)) == start_year_then:
			new_titles_this_season.append(String(t.get("name", "")))

	# --- Ascensos/descensos NUEVOS esta temporada (diff contra el override
	# persistido de la temporada anterior -- _finish_season_rollover() ya
	# aplicó y guardó todo antes de que last_season_report se llene, así
	# que ACÁ ya está el estado post-rollover). Pedido explícito de Wilber:
	# "prueba el sistema de ascensos".
	var cur_league_tiers: Dictionary = SaveManager.load_league_tiers()
	var pr_moves_report: Array = []
	for cid in cur_league_tiers:
		var new_lid: int = int(cur_league_tiers[cid])
		if int(_prev_league_tiers.get(cid, -1)) == new_lid:
			continue
		var mv_club := WorldFactory.find_club(wte.world, String(cid))
		var mv_lg := wte._find_league(new_lid)
		pr_moves_report.append({
			"club": mv_club.club_name if mv_club != null else String(cid),
			"to_league": mv_lg.league_name if mv_lg != null else "?",
			"to_tier": mv_lg.tier if mv_lg != null else -1,
		})
	_prev_league_tiers = cur_league_tiers.duplicate()

	_report["seasons"].append({
		"n": idx, "note": note,
		"start_year": start_year_then,
		"club": club_name_then,
		"club_id": club_id_then,
		"age": p.age, "overall": p.overall, "potential": p.potential,
		"reputation": p.reputation, "market_value_k": p.market_value,
		"wage_k": p.wage, "balance_k": p.balance,
		"attributes": {
			"speed": p.speed, "stamina": p.stamina, "strength": p.strength, "control": p.control,
			"passing": p.passing, "shooting": p.shooting, "dribbling": p.dribbling,
			"decision_making": p.decision_making, "composure": p.composure, "leadership": p.leadership,
		},
		"season_goals": cur["g"] - int(_prev.get("g", 0)),
		"season_assists": cur["a"] - int(_prev.get("a", 0)),
		"season_matches": cur["m"] - int(_prev.get("m", 0)),
		"season_trophies": cur["t"] - int(_prev.get("t", 0)),
		"career_goals": cur["g"], "career_assists": cur["a"],
		"career_matches": cur["m"], "career_trophies": cur["t"],
		"league": comp.get("league", {}),
		"domestic_cup": comp.get("domestic_cup", {}),
		"continental": comp.get("continental", []),
		"supercups": comp.get("supercups", []),
		"club_world_cup": comp.get("club_world_cup", {}),
		"awards": comp.get("awards", {}),
		"all_leagues_champions": comp.get("all_leagues_champions", []),
		"national_team": comp.get("national_team", {}),
		"promotions_relegations": pr_moves_report,
		"honors_this_season": honor_names,
		"new_titles_this_season": new_titles_this_season,
		"traits": p.traits.duplicate(),
		"equipped_traits": p.equipped_traits.duplicate(),
		"is_captain": bool(comp.get("is_captain", false)),
		"player_rating": lsr.get("player_rating", null),
		"injury_days": p.injury_days_remaining,
	})
	_prev = cur
