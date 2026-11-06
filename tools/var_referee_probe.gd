extends Node
## VAR real + árbitro con personalidad (10-oct): 160 partidos instantáneos.
##   godot --headless --path . res://tools/VarRefereeProbe.tscn
var _dis: int = 0
var _goals_ev: int = 0
var _cards: int = 0
var _fails: int = 0

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		_fails += 1

func _on_ev(ev: MatchEvent) -> void:
	match ev.type:
		MatchEvent.Type.GOAL_DISALLOWED: _dis += 1
		MatchEvent.Type.GOAL: _goals_ev += 1
		MatchEvent.Type.CARD_YELLOW, MatchEvent.Type.CARD_RED: _cards += 1

func _run_batch(n: int, card_mult: float, var_mult: float) -> Dictionary:
	_dis = 0; _goals_ev = 0; _cards = 0
	var world := WorldFactory.build(4242)
	var lg: LeagueData = world["leagues"][0]
	var clubs: Array = world["clubs_by_league"][lg.league_id]
	var score_goals: int = 0
	for i in range(n):
		var hc: ClubData = clubs[i % clubs.size()]
		var ac: ClubData = clubs[(i * 7 + 3) % clubs.size()]
		if hc == ac:
			continue
		var p := PlayerData.new()
		p.player_name = "Prueba VAR"
		p.position = "ST"
		p.detailed_position = "DC"
		p.overall = 74
		p.potential = 80
		for s in ["speed", "stamina", "strength", "control", "passing", "shooting", "dribbling", "decision_making", "composure"]:
			p.set(s, 74)
		p.club_id = hc.club_id
		var hsq := WorldFactory.make_squad(world["club_meta_by_id"][hc.club_id])
		var asq := WorldFactory.make_squad(world["club_meta_by_id"][ac.club_id])
		var ht := MatchTeam.from_club(hc, hsq, p, 1.0, "")
		var at := MatchTeam.from_club(ac, asq, null, 0.0, "")
		MatchState.start_new_match(ht, at, p, false, true)
		MatchState.fixture = {}
		MatchState.engine.referee_card_mult = card_mult
		MatchState.engine.referee_var_mult = var_mult
		MatchState.engine.event_emitted.connect(_on_ev)
		var res: Dictionary = await MatchState.engine.run_match()
		var sc: Dictionary = res.get("score", {})
		score_goals += int(sc.get("home", 0)) + int(sc.get("away", 0))
	return {"score_goals": score_goals, "goal_events": _goals_ev, "disallowed": _dis, "cards": _cards, "n": n}

func _ready() -> void:
	await get_tree().process_frame
	seed(99)
	var base: Dictionary = await _run_batch(160, 1.0, 1.0)
	print("neutro: ", base)
	_check(int(base["score_goals"]) == int(base["goal_events"]), "el marcador = eventos GOL (un anulado nunca cuenta)")
	var rate: float = float(base["disallowed"]) / maxf(1.0, float(base["disallowed"] + base["goal_events"]))
	_check(rate > 0.01 and rate < 0.08, "goles anulados: %.1f%% (esperado ~3,6%%)" % (rate * 100.0))
	var gpm: float = float(base["score_goals"]) / float(base["n"])
	_check(gpm > 1.8 and gpm < 4.3, "goles por partido en el rango de siempre para esta prueba (~3,8): %.2f" % gpm)
	var strict: Dictionary = await _run_batch(160, 1.6, 1.0)
	var soft: Dictionary = await _run_batch(160, 0.65, 1.0)
	print("tarjetero: ", strict["cards"], " tarjetas · permisivo: ", soft["cards"], " · neutro: ", base["cards"])
	_check(int(strict["cards"]) > int(base["cards"]) and int(base["cards"]) > int(soft["cards"]), "tarjetero > neutro > permisivo en tarjetas")
	var names: Dictionary = {}
	for i in range(200):
		names[String(DecisionResolver.referee_profile("Árbitro %d" % i)["id"])] = true
	_check(names.size() == 5, "hay 5 personalidades de árbitro (%s)" % str(names.keys()))
	_check(DecisionResolver.referee_profile("Juan Pérez") == DecisionResolver.referee_profile("Juan Pérez"), "el mismo árbitro pita siempre igual")
	print("PROBE ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
