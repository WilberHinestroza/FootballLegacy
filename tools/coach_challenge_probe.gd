extends Node
## Reto del DT (10-oct).   godot --headless --path . res://tools/CoachChallengeProbe.tscn
var _fails: int = 0
func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		_fails += 1

func _ready() -> void:
	var p := PlayerData.new()
	p.player_name = "Prueba"
	p.position = "ST"
	var fx := {"competition": "league", "epoch_day": 120, "home_club_id": "c_1_1"}
	var a := CoachChallengeEngine.for_fixture(p, fx)
	_check(not a.is_empty() and a == CoachChallengeEngine.for_fixture(p, fx), "mismo reto en la previa y en el resumen")
	_check(CoachChallengeEngine.for_fixture(p, {"competition": "friendly", "epoch_day": 1}).is_empty(), "sin reto en amistosos")
	var seen := {}
	for d in range(200):
		fx["epoch_day"] = d
		var c := CoachChallengeEngine.for_fixture(p, fx)
		seen[String(c["id"])] = true
		if not ("ST" in (c["pos"] as Array)):
			_check(false, "reto que no es de su puesto: " + String(c["id"]))
	_check(seen.size() >= 5 and not seen.has("tackle2"), "variedad de retos para un delantero (%s)" % str(seen.keys()))
	var goal := {"id": "goal"}
	_check(CoachChallengeEngine.is_met(goal, {"user_goals": 1}, 1, {}) and not CoachChallengeEngine.is_met(goal, {"user_goals": 0}, 1, {}), "reto de gol")
	_check(not CoachChallengeEngine.is_met(goal, {"user_goals": 1, "user_played": false}, 1, {}), "sin jugar no se cumple")
	_check(CoachChallengeEngine.is_met({"id": "win65"}, {"user_rating": 6.8}, 1, {}) and not CoachChallengeEngine.is_met({"id": "win65"}, {"user_rating": 6.8}, 0, {}), "reto de ganar con nota")
	_check(CoachChallengeEngine.is_met({"id": "key2"}, {"rating_events": [{"type": "key_pass_success"}, {"type": "key_pass_success"}]}, 0, {}), "reto de dos jugadas de ataque")
	_check(CoachChallengeEngine.is_met({"id": "noflop"}, {}, 0, {"perfecto": 2, "flojo": 1}) and not CoachChallengeEngine.is_met({"id": "noflop"}, {}, 0, {"flojo": 2}), "reto de toques")
	_check(CoachChallengeEngine.is_met({"id": "clean"}, {"user_yellows": 0}, 0, {}) and not CoachChallengeEngine.is_met({"id": "clean"}, {"user_yellows": 1}, 0, {}), "reto sin tarjetas")
	print("PROBE ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
