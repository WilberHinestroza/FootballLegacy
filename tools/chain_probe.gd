extends Node
## Jugada encadenada (10-oct): no cambia los goles por partido, y aparece.
##   godot --headless --path . res://tools/ChainProbe.tscn
var _chains: int = 0
var _fails: int = 0
func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		_fails += 1

func _batch(n: int) -> Dictionary:
	var world := WorldFactory.build(4242)
	var clubs: Array = world["clubs_by_league"][world["leagues"][0].league_id]
	var goals: int = 0
	var user_goals: int = 0
	_chains = 0
	for i in range(n):
		var hc: ClubData = clubs[i % clubs.size()]
		var ac: ClubData = clubs[(i * 7 + 3) % clubs.size()]
		if hc == ac:
			continue
		var p := PlayerData.new()
		p.player_name = "Prueba Cadena"
		p.position = "ST"
		p.detailed_position = "DC"
		p.overall = 74
		p.potential = 80
		for s in ["speed", "stamina", "strength", "control", "passing", "shooting", "dribbling", "decision_making", "composure"]:
			p.set(s, 74)
		p.club_id = hc.club_id
		var ht := MatchTeam.from_club(hc, WorldFactory.make_squad(world["club_meta_by_id"][hc.club_id]), p, 1.0, "")
		var at := MatchTeam.from_club(ac, WorldFactory.make_squad(world["club_meta_by_id"][ac.club_id]), null, 0.0, "")
		MatchState.start_new_match(ht, at, p, false, true)
		MatchState.fixture = {}
		MatchState.engine.decision_requested.connect(func(s):
			if bool(s.get("chained", false)):
				_chains += 1)
		var res: Dictionary = await MatchState.engine.run_match()
		goals += int(res["score"]["home"]) + int(res["score"]["away"])
		user_goals += int(res.get("user_goals", 0))
	return {"gpm": float(goals) / float(n), "user_gpm": float(user_goals) / float(n), "chains": _chains}

func _ready() -> void:
	await get_tree().process_frame
	seed(31)
	var r: Dictionary = await _batch(240)
	print(r)
	_check(int(r["chains"]) > 10, "aparecen jugadas encadenadas (%d en 240 partidos)" % int(r["chains"]))
	_check(float(r["gpm"]) > 2.0 and float(r["gpm"]) < 3.4, "goles por partido en rango (%.2f)" % float(r["gpm"]))
	print("PROBE ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
