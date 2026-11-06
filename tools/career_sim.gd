extends Node
## Simulación headless de una carrera LARGA para auditoría, con jugador
## NORMAL (no DEV) y mundo IMPORTADO (FL26-27). Escribe un JSON gordo con
## todo lo que pasa cada temporada.
##
##   godot --headless res://tools/CareerSim.tscn
##
## El wrapper de bash respalda/restaura slot_3.json y user://imported_world.json.

const SLOT := "slot_3"
const SEASONS := 10
const SAFETY := 12000
const WORLD_SEED := -1  # WorldFactory.IMPORTED_SEED

var _report := {"meta": {}, "seasons": [], "matches": []}
var _prev := {}
var _matches_season := 0
var _press_seen := 0

func _ready() -> void:
	await get_tree().process_frame
	_run()

func _run() -> void:
	seed(777)
	SaveManager.active_slot_id = SLOT
	SaveManager.save_slot(SLOT, {})
	SaveManager.save_world_seed(WORLD_SEED)

	WorldFactory.clear_imported_world_cache()
	var world := WorldFactory.build(WORLD_SEED)
	if world.get("leagues", []).is_empty():
		push_error("mundo importado vacío"); get_tree().quit(); return

	# --- Jugador NORMAL: promesa de 17 años, media 58, potencial 78-85 ---
	var rng := RandomNumberGenerator.new(); rng.seed = 777
	var p := PlayerData.new()
	p.player_name = "Tomás Herrera"
	p.country = "Argentina"
	p.position = "MF"
	p.detailed_position = "MC"
	p.dominant_foot = "Derecho"
	p.origin = "Cantera"
	p.age = 17
	p.birth_epoch_day = -17 * 365
	p.overall = 58
	p.potential = clampi(58 + rng.randi_range(20, 27), 78, 88)
	for s in ["speed", "stamina", "strength", "control", "passing", "shooting", "dribbling", "decision_making", "composure"]:
		p.set(s, clampi(56 + rng.randi_range(-6, 8), 40, 74))
	p.leadership = rng.randi_range(38, 55)
	p.reputation = rng.randi_range(20, 30)
	p.personality_traits = {"ambition": 62, "loyalty": 58, "professionalism": 60, "determination": 64, "sportsmanship": 55}
	p.ensure_potential_floor()

	# Club: uno de prestigio MEDIO-BAJO en una liga tier-1 sudamericana o
	# europea menor (arranque realista de un juvenil).
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	var cands: Array = []
	for lg in world.get("leagues", []):
		for c in world.get("clubs_by_league", {}).get(lg.league_id, []):
			var bo: int = int(meta_by_id.get(c.club_id, {}).get("base_overall", 55))
			if bo >= 62 and bo <= 72 and lg.tier <= 2:
				cands.append({"club": c, "lg": lg, "bo": bo})
	cands.sort_custom(func(a, b): return a["bo"] < b["bo"])
	var pick: Dictionary = cands[cands.size() / 3] if not cands.is_empty() else {}
	if pick.is_empty():
		push_error("sin club candidato"); get_tree().quit(); return
	var club: ClubData = pick["club"]
	var lg0: LeagueData = pick["lg"]
	p.club_id = club.club_id
	p.wage = ContractEngine.starting_wage(int(pick["bo"]), lg0.reputation)
	p.contract_years_remaining = ContractEngine.STARTING_CONTRACT_YEARS
	p.balance = 60
	p.market_value = TransferMarketEngine.market_value(p.overall, p.potential, p.age)
	SaveManager.save_player(p)

	var season := SeasonCalendar.build_season(world, int(lg0.league_id), 0, CalendarUtils.season_start_year(0), p.club_id, WORLD_SEED)
	var orng := RandomNumberGenerator.new(); orng.seed = 777
	season["player_objective"] = ObjectivesEngine.generate_player_objective(p, orng)
	SaveManager.save_season(season)
	WorldTickEngine.load_runtime()

	_report["meta"] = {
		"world": "FL26-27 (importado)", "seasons_target": SEASONS,
		"player": p.player_name, "start_pos": p.position, "start_club": club.club_name,
		"start_league": lg0.league_name, "start_country": lg0.country,
		"start_overall": p.overall, "start_potential": p.potential, "start_age": p.age,
		"start_value_k": p.market_value, "start_wage_k": p.wage,
	}
	_prev = _totals()

	var done := 0
	var guard := 0
	while done < SEASONS and guard < SAFETY:
		guard += 1
		var stop := WorldTickEngine.advance_until(WorldTickEngine.current_epoch_day + 800)
		# Un jugador real aceptaría los patrocinios que le llegan — el
		# headless nunca abre esa pantalla, así que se aceptan acá para que
		# el informe muestre el ingreso.
		_auto_accept_sponsor()
		match stop:
			"match_pending":
				_matches_season += 1
				await _sim_match()
			"contract_decision":
				if not _contract():
					done += 1; _snapshot(done, "RETIRO"); _flush(); done = SEASONS
			"season_ended":
				done += 1
				_snapshot(done, "")
				var sp: PlayerData = SaveManager.load_player()
				var ss: Dictionary = _report["seasons"][_report["seasons"].size() - 1]
				print("[T%02d] %da media %d/%d · rep %d · €%.1fM · %s · %d PJ %dG %dA · %s" % [
					done, sp.age, sp.overall, sp.potential, sp.reputation,
					sp.market_value / 1000.0, ss.get("club", "?"), int(ss["season_matches"]),
					int(ss["season_goals"]), int(ss["season_assists"]), str(ss["honors"])])
				_matches_season = 0
				WorldTickEngine.last_season_report = {}
				_flush()
				if sp != null and sp.club_id == "":
					break
			"reached_target":
				pass

	_report["meta"]["days"] = WorldTickEngine.current_epoch_day
	_report["meta"]["seasons_done"] = done
	_flush()
	print("SIM OK — %d temporadas · %d días · %d partidos" % [done, WorldTickEngine.current_epoch_day, _report["matches"].size()])
	get_tree().quit()

func _flush() -> void:
	var f := FileAccess.open("user://career_sim_report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "\t")); f.close()

func _auto_accept_sponsor() -> void:
	var p := SaveManager.load_player()
	if p != null and not p.pending_sponsor_offer.is_empty():
		WorldTickEngine.resolve_sponsor_offer(true)

func _totals() -> Dictionary:
	var p := SaveManager.load_player()
	if p == null: return {"g": 0, "a": 0, "m": 0, "t": 0}
	return {"g": p.career_goals, "a": p.career_assists, "m": p.career_matches, "t": p.trophies_won}

func _contract() -> bool:
	var ro: Dictionary = WorldTickEngine.season.get("renewal_offer", {})
	var offers: Array = WorldTickEngine.season.get("transfer_offers", [])
	# Un juvenil ambicioso: si hay una oferta claramente mejor (más sueldo), se va.
	if not offers.is_empty():
		var best: Dictionary = offers[0]
		for o in offers:
			if int(o.get("wage", 0)) > int(best.get("wage", 0)): best = o
		var stay_wage: int = int(ro.get("wage", 0))
		if int(best.get("wage", 0)) > stay_wage * 1.15 or ro.is_empty():
			WorldTickEngine.resolve_contract_decision(String(best.get("club_id", "")), int(best.get("wage", 200)))
			return true
	if ro.has("club_id") and String(ro["club_id"]) != "":
		WorldTickEngine.resolve_contract_decision(String(ro["club_id"]), int(ro.get("wage", 200)))
		return true
	return false

func _sim_match() -> void:
	var wte := WorldTickEngine
	var club_id: String = wte.user_club_id
	var fx: Dictionary = wte.user_fixture_on(wte.current_epoch_day, club_id)
	if fx.is_empty(): fx = wte.next_user_fixture(club_id)
	if fx.is_empty(): return
	var world: Dictionary = wte.world
	var p := SaveManager.load_player()
	var hid: String = String(fx.get("home_club_id", ""))
	var aid: String = String(fx.get("away_club_id", ""))
	var hc := WorldFactory.find_club(world, hid)
	var ac := WorldFactory.find_club(world, aid)
	if hc == null or ac == null: return
	var ss: int = int(wte.season.get("season_start_epoch_day", 0))
	var hsq := WorldFactory.make_squad_with_transfers(world, hid, wte.world_seed, ss)
	var asq := WorldFactory.make_squad_with_transfers(world, aid, wte.world_seed, ss)
	var uh: bool = hid == p.club_id
	var sch: float = CoachRelations.start_chance(p.coach_trust)
	var hco := WorldFactory.find_coach(world, hid)
	var aco := WorldFactory.find_coach(world, aid)
	var ht := MatchTeam.from_club(hc, hsq, p if uh else null, sch if uh else 0.0, hco.formation if hco else "")
	var at := MatchTeam.from_club(ac, asq, null if uh else p, 0.0 if uh else sch, aco.formation if aco else "")
	var ko: bool = bool(fx.get("is_knockout", false))
	MatchState.start_new_match(ht, at, p, ko, true)
	MatchState.fixture = fx
	if fx.has("tie_agg") and fx["tie_agg"] is Dictionary:
		MatchState.engine.set_tie_aggregate(int(fx["tie_agg"].get("home", 0)), int(fx["tie_agg"].get("away", 0)))
	var res: Dictionary = await MatchState.engine.run_match()

	var sc: Dictionary = res.get("score", {})
	var gh: int = int(sc.get("home", 0)); var ga: int = int(sc.get("away", 0))
	var winner: String = String(res.get("shootout_winner", ""))
	if winner == "": winner = "home" if gh >= ga else "away"
	var comp: String = String(fx.get("competition", "league"))
	var friendly: bool = comp == "friendly"
	var started: bool = ht.starting_xi.has(p) or at.starting_xi.has(p)
	var g := 0; var a := 0
	for ev in res.get("rating_events", []):
		match String(ev.get("type", "")):
			"goal": g += 1
			"key_pass_success": a += 1
	var rating: float = float(res.get("user_rating", 6.0))
	if started and not friendly:
		p.season_appearances += 1; p.season_goals += g; p.season_key_passes += a
		wte.season["user_rating_sum"] = float(wte.season.get("user_rating_sum", 0.0)) + rating
		wte.season["user_rating_games"] = int(wte.season.get("user_rating_games", 0)) + 1
		SaveManager.save_season(wte.season)
	if res.get("user_injured", false) and p.injury_days_remaining <= 0:
		var ir := RandomNumberGenerator.new(); ir.seed = hash("inj:%d" % wte.current_epoch_day) ^ wte.world_seed
		p.injury_days_remaining = maxi(1, int(round(PlayerDevelopment.roll_injury_days(ir) * StaffEngine.injury_factor(p))))
	var coach := WorldFactory.find_coach(wte.world, p.club_id)
	CoachRelations.apply_match_result(p, coach, rating)
	SaveManager.save_player(p)
	wte.record_user_result(fx, gh, ga, winner)

	_report["matches"].append({
		"t": _report["seasons"].size() + 1, "day": wte.current_epoch_day, "comp": comp, "ko": ko,
		"home": hc.short_name, "away": ac.short_name, "score": "%d-%d" % [gh, ga],
		"uhome": uh, "started": started, "g": g, "a": a, "rating": snappedf(rating, 0.1),
		"injured": bool(res.get("user_injured", false)), "red": bool(res.get("user_red_carded", false)),
		"diff": _diff_probe(p, ht if uh else at, at if uh else ht),
	})

func _diff_probe(p: PlayerData, _own, opp) -> float:
	if p == null: return -1.0
	var rov := 68
	if opp != null and opp.starting_xi.size() > 0:
		var s := 0
		for pl in opp.starting_xi: s += pl.overall
		rov = int(s / float(opp.starting_xi.size()))
	var ks := ["shot_on_goal", "one_on_one", "key_pass", "dribble", "aerial_duel"]
	var tot := 0.0
	for k in ks: tot += DecisionResolver.difficulty(k, p, rov, 0)
	return snappedf(tot / ks.size(), 0.01)

func _snapshot(idx: int, note: String) -> void:
	var p := SaveManager.load_player()
	if p == null: return
	var wte := WorldTickEngine
	var cur := _totals()
	var lsr: Dictionary = wte.last_season_report
	var club := WorldFactory.find_club(wte.world, p.club_id)
	var lgid := int(wte.season.get("league_id", -1))

	# Tabla de liga del usuario
	var lg_row := {}
	var lg_champ := ""
	var table: Array = wte.user_league_table()
	if not table.is_empty():
		var r: Dictionary = LeagueTable.row_for(table, p.club_id)
		if not r.is_empty():
			lg_row = {"pos": int(r.get("pos", 0)), "pj": int(r.get("pj", 0)), "pts": int(r.get("pts", 0)),
				"gf": int(r.get("gf", 0)), "ga": int(r.get("ga", 0)), "of": table.size()}
		lg_champ = String(WorldFactory.find_club(wte.world, String(table[0].get("club_id", ""))).club_name) if table[0].has("club_id") else ""

	# Ballon d'Or
	var bd: Array = wte.ballon_dor_ranking()
	var bd_top: Array = []
	var bd_rank := -1
	for i in range(bd.size()):
		var e: Dictionary = bd[i]
		if i < 10:
			bd_top.append("%s (%s)" % [String(e.get("name", "?")), String(e.get("club_name", ""))])
		if String(e.get("name", "")) == p.player_name:
			bd_rank = i + 1

	# Prensa de la temporada (todas las nuevas desde el último snapshot)
	var press: Array = []
	var feed: Array = p.press_feed
	for e in feed:
		if e is Dictionary and int(e.get("day", 0)) >= int(_prev.get("day", 0)):
			press.append({"d": int(e.get("day", 0)), "h": String(e.get("headline", "")), "s": String(e.get("sentiment", ""))})
	press.reverse()

	# Perks
	var trait_names: Array = []
	for tid in p.traits: trait_names.append(Traits.name_of(tid))
	var eq_names: Array = []
	for tid in Traits.active(p): eq_names.append(Traits.name_of(tid))

	var honors: Array = []
	for h in lsr.get("honors", []):
		honors.append(String(h.get("name", h)) if h is Dictionary else String(h))
	var titles: Array = []
	for tt in p.career_titles:
		titles.append({"n": String(tt.get("name", "")), "y": int(tt.get("season", 0)), "k": String(tt.get("kind", ""))})

	_report["seasons"].append({
		"n": idx, "note": note, "year": int(wte.get_season_start_year()),
		"age": p.age, "overall": p.overall, "potential": p.potential,
		"reputation": p.reputation, "value_k": p.market_value, "wage_k": p.wage,
		"balance_k": p.balance, "contract_years": p.contract_years_remaining,
		"club": club.club_name if club else p.club_id, "club_id": p.club_id,
		"league_id": lgid,
		"coach": _coach_name(wte, p.club_id), "coach_trust": p.coach_trust,
		"coach_replaced": wte.season.has("coach_replacement"),
		"fatigue_phys": snappedf(p.fatigue_physical, 0.1), "fatigue_ment": snappedf(p.fatigue_mental, 0.1),
		"injury_days": p.injury_days_remaining,
		"fan_sentiment": int(wte.season.get("fan_sentiment", 55)),
		"dressing_room": int(wte.season.get("dressing_room", 60)),
		"press_narrative": String(wte.season.get("press_narrative", "")),
		"is_captain": bool(wte.season.get("is_captain", false)),
		"sponsor": String(p.sponsor.get("name", "")), "sponsor_weekly_k": int(p.sponsor.get("weekly_income", 0)),
		"season_matches": cur["m"] - int(_prev.get("m", 0)),
		"season_goals": cur["g"] - int(_prev.get("g", 0)),
		"season_assists": cur["a"] - int(_prev.get("a", 0)),
		"season_trophies": cur["t"] - int(_prev.get("t", 0)),
		"career_goals": cur["g"], "career_assists": cur["a"], "career_matches": cur["m"], "career_trophies": cur["t"],
		"league_row": lg_row, "league_champion": lg_champ,
		"honors": honors, "prize_k": int(lsr.get("prize_money", {}).get("total", 0)),
		"new_traits": lsr.get("new_traits", []), "traits": trait_names, "equipped": eq_names,
		"slots": Traits.slots_for(p.overall),
		"ballon_dor_rank": bd_rank, "ballon_dor_top10": bd_top,
		"player_rating": lsr.get("player_rating", null),
		"all_titles": titles,
		"press": press,
		"personality": p.personality_traits.duplicate(),
	})
	var t := _totals(); t["day"] = wte.current_epoch_day
	_prev = t

func _coach_name(wte, club_id: String) -> String:
	var c := WorldFactory.find_coach(wte.world, club_id)
	return c.coach_name if c != null else "?"
