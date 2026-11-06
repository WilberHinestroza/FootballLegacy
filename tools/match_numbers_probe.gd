extends Node
## NÚMEROS POR PARTIDO (10-oct, Wilber: "quiero que por partido sean
## números realistas"). Simula muchos partidos con un humano "promedio",
## "bueno" y "muy bueno" (qué tan seguido clava la zona verde) y mide goles,
## remates, tarjetas y lo que hace el usuario. Solo lectura.
##   godot --headless --path . res://tools/MatchNumbersProbe.tscn
const N := 150

func _mk_player(pos: String, ovr: int) -> PlayerData:
	var p := PlayerData.new()
	p.player_name = "Prueba Números"
	p.position = pos
	p.detailed_position = {"GK": "POR", "DF": "DFC", "MF": "MC", "ST": "DC"}[pos]
	p.overall = ovr
	p.potential = maxi(ovr, 80)
	for s in ["speed", "stamina", "strength", "control", "passing", "shooting", "dribbling", "decision_making", "composure"]:
		p.set(s, ovr)
	return p

func _run(pos: String, ovr: int, clean_rate: float) -> Dictionary:
	var world := WorldFactory.build(4242)
	var clubs: Array = world["clubs_by_league"][world["leagues"][0].league_id]
	var tot := {"goals": 0, "ug": 0, "ua": 0, "rating": 0.0, "shots": 0, "on_target": 0, "cards": 0, "reds": 0, "moments": 0, "n": 0}
	var counters := {"cards": 0, "reds": 0, "moments": 0}
	for i in range(N):
		var hc: ClubData = clubs[i % clubs.size()]
		var ac: ClubData = clubs[(i * 7 + 3) % clubs.size()]
		if hc == ac:
			continue
		var p := _mk_player(pos, ovr)
		var user_home: bool = i % 2 == 0
		p.club_id = hc.club_id if user_home else ac.club_id
		var hsq := WorldFactory.make_squad(world["club_meta_by_id"][hc.club_id])
		var asq := WorldFactory.make_squad(world["club_meta_by_id"][ac.club_id])
		var ht := MatchTeam.from_club(hc, hsq, p if user_home else null, 1.0 if user_home else 0.0, "")
		var at := MatchTeam.from_club(ac, asq, null if user_home else p, 0.0 if user_home else 1.0, "")
		MatchState.start_new_match(ht, at, p, false, true)
		MatchState.fixture = {}
		MatchState.engine.sim_clean_rate = clean_rate
		MatchState.engine.event_emitted.connect(func(ev: MatchEvent):
			if ev.type == MatchEvent.Type.CARD_YELLOW:
				counters["cards"] += 1
			elif ev.type == MatchEvent.Type.CARD_RED:
				counters["reds"] += 1
			elif ev.type == MatchEvent.Type.DECISION_REQUEST:
				counters["moments"] += 1
		)
		var res: Dictionary = await MatchState.engine.run_match()
		tot["n"] += 1
		tot["goals"] += int(res["score"]["home"]) + int(res["score"]["away"])
		tot["ug"] += int(res.get("user_goals", 0))
		tot["ua"] += int(res.get("user_assists", 0))
		tot["rating"] += float(res.get("user_rating", 6.0))
		var st: Dictionary = res.get("stats", MatchState.engine.get_match_stats())
		for side in ["home", "away"]:
			tot["shots"] += int(st.get(side, {}).get("shots", 0))
			tot["on_target"] += int(st.get(side, {}).get("on_target", 0))
	tot["cards"] = counters["cards"]
	tot["reds"] = counters["reds"]
	tot["moments"] = counters["moments"]
	return tot

func _ready() -> void:
	await get_tree().process_frame
	seed(2026)
	print("REFERENCIA REAL: ~2,7 goles/partido · ~25 remates (9 al arco) · ~4 amarillas · ~0,2 rojas")
	print("  delantero top 0,7-0,9 goles/partido · bueno 0,4-0,5 · medio 0,25-0,35 · volante 0,1-0,25 G y 0,15-0,3 A · nota media 6,5-7,0")
	print("%-28s %6s %6s %6s %6s %6s %6s %6s %6s %6s" % ["caso", "goles", "tuyos", "asist", "nota", "remat", "arco", "amar", "rojas", "moment"])
	for c in [["ST", 68, 0.4], ["ST", 68, 0.65], ["ST", 78, 0.65], ["ST", 88, 0.65], ["ST", 88, 0.85],
			["MF", 78, 0.65], ["DF", 78, 0.65], ["GK", 78, 0.65]]:
		var t: Dictionary = await _run(String(c[0]), int(c[1]), float(c[2]))
		var n: float = float(t["n"])
		print("%-28s %6.2f %6.2f %6.2f %6.2f %6.1f %6.1f %6.2f %6.2f %6.1f" % [
			"%s %d · acierta %d%%" % [String(c[0]), int(c[1]), int(float(c[2]) * 100.0)],
			float(t["goals"]) / n, float(t["ug"]) / n, float(t["ua"]) / n, float(t["rating"]) / n,
			float(t["shots"]) / n, float(t["on_target"]) / n, float(t["cards"]) / n, float(t["reds"]) / n, float(t["moments"]) / n])
	get_tree().quit(0)
