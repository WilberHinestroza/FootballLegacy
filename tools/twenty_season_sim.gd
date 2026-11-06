extends Node
## Simulación headless de 20 temporadas con reporte COMPLETO: evolución
## del jugador, club por temporada, resultado de TODAS las competiciones
## de CLUB (liga, copa doméstica, copa(s) continentales, supercopa,
## mundial de clubes) Y de SELECCIÓN (eliminatoria al Mundial, Mundial,
## copa continental de selecciones — Fases 1-5), ganador de cada premio
## individual de club (Balón de Oro, Bota de Oro, Asistidor) — no solo lo
## que ganó el usuario. Pedido explícito de Wilber: "una simulación de 20
## temporadas súper completa... todas las estadísticas posibles".
##
## Clon de ten_season_sim.gd (mismo esqueleto probado: avance día a día
## para capturar el snapshot ANTES del rollover, manejo de contrato,
## captura de competiciones) + el agregado de selecciones nacionales
## completo, incluido el registro del resultado REAL del usuario como
## override (WorldTickEngine.record_user_national_result) — sin eso, la
## tabla de eliminatoria mostraría un resultado distinto al que jugó el
## usuario para sus propios partidos (mismo bug de fondo ya resuelto para
## copas de club en la Parte 71, ahora extendido a selecciones).
##
## Ejecutar:  godot --headless res://tools/TwentySeasonSim.tscn
## Escribe user://twenty_season_report.json. USA slot_3 (desechable).

const SLOT := "slot_3"
const WORLD_SEED := 20260906
## true = usa el mundo IMPORTADO (user://imported_world.json) en vez del
## procedural determinista de siempre. false = procedural (WORLD_SEED).
const USE_IMPORTED_WORLD := true
const SEASONS := 20
const SAFETY_DAYS := 9000

var _report := {"seasons": [], "matches": [], "national_matches": [], "meta": {}}
var _prev := {}

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

		# Selecciones nacionales (Fases 1-5): independiente del calendario de
		# club (las ventanas FIFA ya bloquean liga/copa esos días, ver
		# SeasonCalendar.international_windows_for_season) — se chequea
		# aparte, nunca el mismo día que un fixture de club por construcción.
		var nat_fx: Dictionary = WorldTickEngine.pending_user_national_fixture()
		if not nat_fx.is_empty():
			await _sim_user_national_match(nat_fx)

	if guard >= SAFETY_DAYS:
		print("  !! tope de seguridad alcanzado (posible loop sin fixture)")

	_report["meta"]["days_simulated"] = WorldTickEngine.current_epoch_day
	_report["meta"]["guard_hit"] = guard >= SAFETY_DAYS
	_flush_report()
	print("SIM OK — %d temporadas, %d días, %d partidos de club, %d de selección" % [
		seasons_done, WorldTickEngine.current_epoch_day, _report["matches"].size(), _report["national_matches"].size()])
	get_tree().quit()

func _flush_report() -> void:
	var f := FileAccess.open("user://twenty_season_report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "\t"))
	f.close()

func _print_season_line(idx: int, matches: int) -> void:
	var sp: PlayerData = SaveManager.load_player()
	var s: Dictionary = _report["seasons"][_report["seasons"].size() - 1]
	var nat: Dictionary = s.get("national", {})
	var nat_bit: String = ""
	if not nat.is_empty() and String(nat.get("status", "")) != "":
		nat_bit = " · sel:%s (%d caps)" % [String(nat.get("status", "")), int(nat.get("caps", 0))]
	print("  [T%d] día %d · %d PJ · %s · media %d · %da · %dG %dA · liga:%s copa:%s%s" % [
		idx, WorldTickEngine.current_epoch_day, matches, String(s["club"]),
		int(sp.overall), int(sp.age), int(s["season_goals"]), int(s["season_assists"]),
		String(s["league"]["result"]), String(s["domestic_cup"]["result"]), nat_bit])

func _handle_contract() -> bool:
	var ro: Dictionary = WorldTickEngine.season.get("renewal_offer", {})
	var offers: Array = WorldTickEngine.season.get("transfer_offers", [])
	if ro.has("club_id") and String(ro["club_id"]) != "":
		if offers.is_empty() or randf() < 0.55:
			WorldTickEngine.resolve_contract_decision(String(ro["club_id"]), int(ro.get("wage", 200)))
			return true
	if not offers.is_empty():
		# OJO: `offers[0]` es CASI SIEMPRE la oferta del país de origen —
		# CareerSetup.generate_offers() la garantiza en el primer lugar del
		# array (paso 1, antes de rellenar el resto), así que agarrar
		# siempre el índice 0 sesgaba TODAS las simulaciones a quedarse en
		# el mismo país (reporte de Wilber: "por qué siempre pasás toda la
		# temporada en el mismo país" — era este script, no el juego: el
		# juego SÍ garantiza al menos una oferta internacional entre las 5,
		# el jugador real las ve todas en ContractDecision y elige). Ahora
		# se compara el SUELDO de las 3 ofertas que llegan (mismo criterio
		# "mejor postor" que usaría un jugador real), sin favorecer al país
		# de origen por posición en el array.
		var best_idx: int = 0
		var best_wage: int = -1
		for i in range(offers.size()):
			var w: int = int(offers[i].get("wage", 0))
			if w > best_wage:
				best_wage = w
				best_idx = i
		var best: Dictionary = offers[best_idx]
		WorldTickEngine.resolve_contract_decision(String(best.get("club_id", "")), int(best.get("wage", 200)))
		return true
	if ro.has("club_id"):
		WorldTickEngine.resolve_contract_decision(String(ro["club_id"]), int(ro.get("wage", 200)))
		return true
	return false

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

## Partido de SELECCIÓN del usuario (eliminatoria, Mundial o copa
## continental — `fx` ya viene resuelto por WorldTickEngine.
## pending_user_national_fixture, que decide cuál de las 3 toca hoy).
## Mismo criterio que _sim_user_match(): NationalTeamMatchLauncher arma
## los equipos reales (plantel de 23 con relleno sintético si hace
## falta), se corre el motor de partido COMPLETO (no el simulador rápido
## de IA-vs-IA), y se aplican las consecuencias reales — caps, goles,
## asistencias, y el resultado se graba como OVERRIDE (sin esto, la
## próxima consulta a la tabla resimularía este partido con un resultado
## distinto al que se acaba de jugar).
func _sim_user_national_match(fx: Dictionary) -> void:
	var wte := WorldTickEngine
	var p := SaveManager.load_player()
	if p == null:
		return
	var season_start: int = int(wte.season.get("season_start_epoch_day", 0))
	var prep: Dictionary = NationalTeamMatchLauncher.prepare(
		wte.world, wte.world_seed, season_start, p, p.country,
		String(fx.get("opponent", "")), bool(fx.get("is_home", true)),
		float(fx.get("user_start_chance", 0.0)), "", true,
		String(fx.get("competition", "qualifying")), bool(fx.get("is_knockout", false)), String(fx.get("key", "")))
	if not bool(prep.get("ok", false)):
		return
	var result: Dictionary = await MatchState.engine.run_match()

	var sc: Dictionary = result.get("score", {})
	var gh: int = int(sc.get("home", 0))
	var ga: int = int(sc.get("away", 0))
	var goals: int = int(result.get("user_goals", 0))
	var assists: int = int(result.get("user_assists", 0))
	p.caps += 1
	p.international_goals += goals
	p.international_assists += assists
	SaveManager.save_player(p)

	var comp: String = String(fx.get("competition", "qualifying"))
	var result_key: String = String(fx.get("key", ""))
	if result_key != "":
		var winner: String = String(result.get("shootout_winner", ""))
		if winner == "":
			winner = "home" if gh >= ga else "away"
		wte.record_user_national_result(comp, result_key, gh, ga, winner)

	_report["national_matches"].append({
		"day": wte.current_epoch_day, "competition": comp,
		"home": String(MatchState.fixture.get("home_country", "")),
		"away": String(MatchState.fixture.get("away_country", "")),
		"score": "%d-%d" % [gh, ga], "goals": goals, "assists": assists,
		"rating": snappedf(float(result.get("user_rating", 6.0)), 0.1),
	})
	MatchState.clear()

## --- Progreso en un cuadro eliminatorio (copa doméstica o continental) ---
## Devuelve {"result": texto legible, "champion_id": String, "reached_round": String}
func _bracket_progress(bracket: Dictionary, club_id: String) -> Dictionary:
	if bracket.is_empty():
		return {"result": "No aplica", "champion_id": "", "reached_round": ""}
	var last_round: String = ""
	var champion_id: String = ""
	for rnd in bracket.get("rounds", []):
		var rn: String = String(rnd.get("round_name", ""))
		var in_round := false
		for m in rnd.get("matches", []):
			var h: String = String(m.get("home_club_id", ""))
			var a: String = String(m.get("away_club_id", ""))
			if h == club_id or a == club_id:
				in_round = true
			if rn == "Final" and bool(m.get("decided", false)):
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

	# --- Selección nacional (Fases 1-5) ---
	var national_info := _national_snapshot(p)

	return {
		"start_year": int(wte.season.get("start_year", wte.get_season_start_year())),
		"club_id": club_id_now,
		"club_name": club.club_name if club != null else club_id_now,
		"is_captain": bool(wte.season.get("is_captain", false)),
		"league": league_info, "domestic_cup": dcup_prog, "continental": continental_list,
		"supercups": supercups, "club_world_cup": cwc_info, "awards": awards,
		"national": national_info,
	}

## Estado de la selección de `p` al momento de la captura: convocatoria,
## eliminatoria al Mundial (posición/estado de clasificación), Mundial y
## copa continental de selecciones si están en curso ese año, y stats
## acumuladas (caps/goles/asistencias con la selección, NUNCA se
## resetean). {} si el país de `p` no tiene confederación asignada.
func _national_snapshot(p: PlayerData) -> Dictionary:
	var wte := WorldTickEngine
	var out := {
		"country": p.country, "status": p.national_team_status,
		"caps": p.caps, "international_goals": p.international_goals,
		"international_assists": p.international_assists,
	}
	var confederation: String = Confederations.confederation_of(p.country)
	out["confederation"] = confederation
	if confederation == "":
		return out

	var qualifying: Dictionary = wte.national_qualifying_for(confederation)
	if not qualifying.is_empty():
		var direct: Array = qualifying.get("direct", [])
		var playoff: Array = qualifying.get("playoff_pool", [])
		var qstatus: String
		if direct.has(p.country):
			qstatus = "Clasificado directo"
		elif playoff.has(p.country):
			qstatus = "Zona de repechaje"
		else:
			qstatus = "Fuera de zona de clasificación"
		out["qualifying_status"] = qstatus
		out["qualifying_format"] = String(qualifying.get("format", ""))

	var wc: Dictionary = wte.world_cup_this_cycle()
	if not wc.is_empty():
		out["world_cup"] = _national_tournament_progress(wc, p.country)

	var ncup: Dictionary = wte.national_cup_for(confederation)
	if not ncup.is_empty():
		out["continental_cup"] = _national_tournament_progress(ncup, p.country)
		out["continental_cup_name"] = CompetitionNames.national_continental(confederation)

	return out

## Progreso de `country` en un torneo de selecciones (Mundial o copa
## continental — mismo dict shape: groups/rounds/champion_country).
## Espíritu idéntico a _bracket_progress(), pero para este shape propio
## (no reusa esa función porque el shape difiere: acá no hay "league_phase"
## suizo, y el campeón ya viene resuelto en "champion_country").
func _national_tournament_progress(tournament: Dictionary, country: String) -> Dictionary:
	var champion: String = String(tournament.get("champion_country", ""))
	var my_group: Dictionary = {}
	for g in tournament.get("groups", []):
		for row in g.get("standings", []):
			if String(row.get("club_id", "")) == country:
				my_group = g
				break
		if not my_group.is_empty():
			break
	if my_group.is_empty():
		return {"result": "No participó", "champion": champion}

	var rounds: Array = tournament.get("rounds", [])
	if rounds.is_empty():
		var standings: Array = my_group.get("standings", [])
		var pos: int = 0
		for i in range(standings.size()):
			if String(standings[i].get("club_id", "")) == country:
				pos = i + 1
				break
		return {"result": "Fase de grupos (%d° de %d)" % [pos, standings.size()], "champion": champion}

	for i in range(rounds.size() - 1, -1, -1):
		var rnd: Dictionary = rounds[i]
		for m in rnd.get("matches", []):
			var home: String = String(m.get("home_club_id", ""))
			var away: String = String(m.get("away_club_id", ""))
			if home != country and away != country:
				continue
			var round_name: String = String(rnd.get("round_name", "eliminatoria"))
			if not bool(rnd.get("decided", false)):
				return {"result": "Jugando %s" % round_name, "champion": champion}
			var winner: String = String(m.get("winner_club_id", ""))
			if winner == country:
				return {"result": "Campeón" if round_name == "Final" else "Avanzó de %s" % round_name, "champion": champion}
			return {"result": "Eliminado en %s" % round_name, "champion": champion}
	return {"result": "Fase de grupos", "champion": champion}

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
		"national": comp.get("national", {}),
		"honors_this_season": honor_names,
		"new_titles_this_season": new_titles_this_season,
		"traits": p.traits.duplicate(),
		"equipped_traits": p.equipped_traits.duplicate(),
		"is_captain": bool(comp.get("is_captain", false)),
		"player_rating": lsr.get("player_rating", null),
		"injury_days": p.injury_days_remaining,
	})
	_prev = cur
