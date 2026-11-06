extends Node
## Simulación headless de 5 temporadas para auditar el juego.
## Ejecutar:  godot --headless res://tools/FiveSeasonSim.tscn
## Escribe un informe JSON en user://five_season_report.json.
## USA slot_3 como borrador — el wrapper de bash lo respalda y lo restaura.

const SLOT := "slot_3"
const WORLD_SEED := 20260906
const SEASONS := 5
const SAFETY_DAYS := 5000

var _report := {"seasons": [], "matches": [], "meta": {}}
var _prev := {}
var _match_log_this_season := []

func _ready() -> void:
	await get_tree().process_frame
	_run()

func _run() -> void:
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = WORLD_SEED
	seed(WORLD_SEED)

	SaveManager.active_slot_id = SLOT
	# Slot limpio
	SaveManager.save_slot(SLOT, {})
	SaveManager.save_world_seed(WORLD_SEED)

	var world := WorldFactory.build(WORLD_SEED)

	# --- Jugador tipo DEV: ST joven, media 80 ---
	var p := PlayerData.new()
	p.player_name = "Sim Tester"
	p.country = "Argentina"
	p.position = "ST"
	p.detailed_position = Positions.default_detailed_for_broad("ST")
	p.dominant_foot = "Derecho"
	p.origin = "Cantera de club grande"
	p.age = 19
	p.birth_epoch_day = -19 * 365
	p.overall = 80
	p.potential = 92
	for stat in ["speed", "stamina", "strength", "control", "passing", "shooting", "dribbling", "decision_making", "composure"]:
		p.set(stat, clampi(80 + seed_rng.randi_range(-4, 8), 60, 96))
	p.leadership = 68
	p.reputation = 60
	p.market_value = TransferMarketEngine.market_value(p.overall, p.potential, p.age)
	p.ensure_potential_floor()

	# --- Club: uno de reputación media de la liga argentina ---
	var arg := WorldFactory.find_league_for_country(world, "Argentina")
	var clubs: Array = world.get("clubs_by_league", {}).get(arg.league_id, [])
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	clubs = clubs.duplicate()
	clubs.sort_custom(func(a, b): return int(meta_by_id.get(a.club_id, {}).get("base_overall", 55)) > int(meta_by_id.get(b.club_id, {}).get("base_overall", 55)))
	var club: ClubData = clubs[clampi(int(clubs.size() * 0.45), 0, clubs.size() - 1)]
	p.club_id = club.club_id
	p.wage = ContractEngine.starting_wage(int(meta_by_id.get(club.club_id, {}).get("base_overall", 60)), arg.reputation)
	p.contract_years_remaining = ContractEngine.STARTING_CONTRACT_YEARS
	p.balance = 200
	SaveManager.save_player(p)

	var season := SeasonCalendar.build_season(world, int(arg.league_id), 0, CalendarUtils.season_start_year(0), p.club_id, WORLD_SEED)
	var orng := RandomNumberGenerator.new(); orng.seed = WORLD_SEED
	season["player_objective"] = ObjectivesEngine.generate_player_objective(p, orng)
	SaveManager.save_season(season)
	WorldTickEngine.load_runtime()

	_report["meta"] = {
		"world_seed": WORLD_SEED,
		"start_club": club.club_name,
		"start_league": arg.league_name,
		"start_overall": p.overall,
		"start_age": p.age,
	}
	_prev = _career_totals()

	var seasons_done := 0
	var guard := 0
	var matches_this_season := 0
	while seasons_done < SEASONS and guard < SAFETY_DAYS:
		guard += 1
		var target := WorldTickEngine.current_epoch_day + 800
		var stop := WorldTickEngine.advance_until(target)
		match stop:
			"match_pending":
				matches_this_season += 1
				await _sim_user_match()
			"contract_decision":
				if not _handle_contract():
					_snapshot(seasons_done + 1, "RETIRO")
					seasons_done = SEASONS
			"season_ended":
				seasons_done += 1
				_snapshot(seasons_done, "")
				var _sp: PlayerData = SaveManager.load_player()
				var _s: Dictionary = _report["seasons"][_report["seasons"].size() - 1]
				print("  [T%d] día %d · %d PJ · media %d · %da · rep %d · valor %dk · %dG %dA temp · %s" % [
					seasons_done, WorldTickEngine.current_epoch_day, matches_this_season,
					int(_sp.overall), int(_sp.age), int(_sp.reputation), int(_sp.market_value),
					int(_s["season_goals"]), int(_s["season_assists"]), str(_s["honors"])])
				matches_this_season = 0
				WorldTickEngine.last_season_report = {}
				_flush_report()  # informe parcial tras cada temporada
				var pp := SaveManager.load_player()
				if pp != null and pp.club_id == "":
					break
			"reached_target":
				print("  ...avanzado a día %d sin evento" % WorldTickEngine.current_epoch_day)

	_report["meta"]["days_simulated"] = WorldTickEngine.current_epoch_day
	_report["meta"]["guard_hit"] = guard >= SAFETY_DAYS
	_flush_report()
	print("SIM OK — %d temporadas, %d días, %d partidos jugados" % [
		seasons_done, WorldTickEngine.current_epoch_day, _report["matches"].size()])
	get_tree().quit()

func _flush_report() -> void:
	var f := FileAccess.open("user://five_season_report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "\t"))
	f.close()

func _handle_contract() -> bool:
	var ro: Dictionary = WorldTickEngine.season.get("renewal_offer", {})
	var offers: Array = WorldTickEngine.season.get("transfer_offers", [])
	if ro.has("club_id") and String(ro["club_id"]) != "":
		# 60% renueva, 40% se va al mejor postor (si hay)
		if offers.is_empty() or randf() < 0.6:
			WorldTickEngine.resolve_contract_decision(String(ro["club_id"]), int(ro.get("wage", 200)))
			return true
	if not offers.is_empty():
		# `offers[0]` es casi siempre la del país de origen (CareerSetup.
		# generate_offers la garantiza primera) — comparar sueldo entre
		# las 3 en vez de agarrar siempre el índice 0, o toda carrera se
		# queda en el mismo país (ver mismo comentario en ten_season_sim.gd).
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
	return false  # sin nada: retiro

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

	var world2: Dictionary = wte.world
	var coach := WorldFactory.find_coach(world2, p.club_id)
	CoachRelations.apply_match_result(p, coach, rating)
	SaveManager.save_player(p)
	wte.record_user_result(fx, gh, ga, winner)

	_report["matches"].append({
		"day": wte.current_epoch_day, "comp": comp, "ko": is_ko,
		"home": home_club.club_name, "away": away_club.club_name,
		"score": "%d-%d" % [gh, ga], "user_home": user_is_home,
		"started": started, "goals": goals_m, "assists": assists_m,
		"rating": snappedf(rating, 0.1), "injured": bool(result.get("user_injured", false)),
		"diff_menu": _difficulty_probe(fx, p),
	})

## Registra la dificultad que verían las opciones del menú para este partido
## (media de las opciones del puesto) — para auditar el rebalanceo.
func _difficulty_probe(fx: Dictionary, p: PlayerData) -> float:
	if p == null:
		return -1.0
	var rival_ov := 68
	var kinds := ["shot_on_goal", "one_on_one", "key_pass", "dribble", "aerial_duel"]
	var tot := 0.0
	for k in kinds:
		tot += DecisionResolver.difficulty(k, p, rival_ov, 0)
	return snappedf(tot / kinds.size(), 0.01)

func _snapshot(idx: int, note: String) -> void:
	var p := SaveManager.load_player()
	if p == null:
		return
	var cur := _career_totals()
	var lsr: Dictionary = WorldTickEngine.last_season_report
	var club := WorldFactory.find_club(WorldTickEngine.world, p.club_id)
	var honors: Array = lsr.get("honors", [])
	var honor_names: Array = []
	for h in honors:
		honor_names.append(String(h.get("name", h)) if h is Dictionary else String(h))
	var titles_names: Array = []
	for t in p.career_titles:
		titles_names.append(String(t.get("name", "")))
	_report["seasons"].append({
		"n": idx, "note": note,
		"age": p.age, "overall": p.overall, "potential": p.potential,
		"reputation": p.reputation, "market_value_k": p.market_value,
		"wage_k": p.wage, "balance_k": p.balance,
		"club": club.club_name if club != null else p.club_id,
		"club_id": p.club_id,
		"season_goals": cur["g"] - int(_prev.get("g", 0)),
		"season_assists": cur["a"] - int(_prev.get("a", 0)),
		"season_matches": cur["m"] - int(_prev.get("m", 0)),
		"season_trophies": cur["t"] - int(_prev.get("t", 0)),
		"career_goals": cur["g"], "career_assists": cur["a"],
		"career_matches": cur["m"], "career_trophies": cur["t"],
		"honors": honor_names,
		"new_traits": lsr.get("new_traits", []),
		"traits": p.traits.duplicate(),
		"equipped_traits": p.equipped_traits.duplicate(),
		"slots": Traits.slots_for(p.overall),
		"is_captain": bool(WorldTickEngine.season.get("is_captain", false)),
		"player_rating": lsr.get("player_rating", null),
		"prize_money_k": lsr.get("prize_money", {}).get("total", 0),
		"ballon_dor_top": (lsr.get("ballon_dor", []) as Array).slice(0, 3).map(func(e): return String(e.get("name", "?")) if e is Dictionary else "?"),
		"all_titles": titles_names,
		"injury_days": p.injury_days_remaining,
		"press_tail": _press_tail(p),
	})
	_prev = cur

func _press_tail(p: PlayerData) -> Array:
	var out: Array = []
	var feed: Array = p.press_feed
	for i in range(maxi(0, feed.size() - 4), feed.size()):
		var e = feed[i]
		if e is Dictionary:
			out.append(String(e.get("headline", "")))
	return out
