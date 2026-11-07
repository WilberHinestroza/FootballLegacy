extends SceneTree
## Zona mixta 3D: la pregunta habla de tu jugada (chilena, diagonal, pared…).
func _init() -> void:
	var rng := RandomNumberGenerator.new()
	var p := PlayerData.new()
	p.position = "MF"
	p.detailed_position = "EI"
	p.dominant_foot = "Derecho"
	p.potential = 80
	var fx := {"home_club_id": "a", "away_club_id": "b"}
	var cases := [
		["chilena", {"play": "centro", "flair": "bicycle", "goal": true, "assist": false}, "EI", "chilena"],
		["volea", {"play": "rechace", "flair": "volley", "goal": true, "assist": false}, "DC", "volea"],
		["diagonal", {"play": "diagonal", "flair": "", "goal": true, "assist": false}, "EI", "izquierda"],
		["pared", {"play": "pared", "flair": "", "goal": true, "assist": false}, "MC", "pared"],
		["central", {"play": "corner", "flair": "", "goal": true, "assist": false}, "DFC", "central"],
		["lateral", {"play": "desborde", "flair": "", "goal": false, "assist": true}, "LD", "lateral"],
	]
	var fails := 0
	for c in cases:
		var gp: Dictionary = c[1]
		var res := {"score": {"home": 1, "away": 0}, "user_rating": 7.5, "rating_events": [{"type": "goal" if gp.goal else "key_pass_success"}],
			"user_detailed": c[2], "user_goal_plays": [gp]}
		var ctx := InterviewEngine.extract_context(fx, res, "a", p, {})
		var q := InterviewEngine.generate_question(ctx, rng)
		var ok: bool = String(q.question).to_lower().contains(c[3])
		if not ok:
			fails += 1
		print("%s -> %s %s" % [c[0], q.question, "" if ok else "  <-- FALLA"])
	var h := PressGenerator.headline_for_match("Tomás Herrera", 1, 8.0, rng, "", "", {"flair": "bicycle"})
	print("titular: ", h.get("headline", ""))
	print("PRESS PROBE %s" % ("OK" if fails == 0 else "FAIL"))
	quit(0)
