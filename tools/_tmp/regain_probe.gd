extends Node
## Robo arriba: en una jugada de defensa, un compañero roba en campo rival y la
## jugada debe seguir como contraataque (no cerrarse como "balón recuperado").
## En campo propio sí se cierra.
func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	var m: SoccerMatch = scr._match
	await get_tree().create_timer(1.0).timeout
	m._end_walkout()
	if m.state == m.State.CUTSCENE:
		m._end_cutscene()
	m._moments.clear()
	var fails := 0
	for case_x: float in [-20.0, 20.0, 30.0]:
		var fp := PlayGenerator.make("presion_alta")
		m._start_moment(fp.base, fp)
		await get_tree().create_timer(2.2).timeout
		print("  antes: moment=%s state=%s dir=%.0f" % [m.Moment.keys()[m.moment_type], m.State.keys()[m.state], m.attack_dir(0)])
		var mate: SoccerPlayer = m._nearest_of_team(0, Vector3(case_x, 0.0, 0.0), [m.star], 60.0)
		mate.reset_to(Vector3(case_x, 0.0, 3.0), Vector3.RIGHT)
		m._give_ball_now(mate)
		await get_tree().create_timer(0.3).timeout
		var kind: String = m.Moment.keys()[m.moment_type]
		var st: String = m.State.keys()[m.state]
		print("REGAIN x=%.0f -> moment=%s state=%s high=%s" % [case_x, kind, st, m._high_regain])
		if case_x > 0.0 and (kind != "COUNTER" or st != "MOMENT"):
			fails += 1
		if case_x < 0.0 and st == "MOMENT":
			fails += 1
		# deja que termine (y que cuente bien)
		var t0 := Time.get_ticks_msec()
		while m.state == m.State.MOMENT and Time.get_ticks_msec() - t0 < 14000:
			await get_tree().physics_frame
		var last: Dictionary = m.match_stats.moment_log[-1] if not m.match_stats.moment_log.is_empty() else {}
		print("  fin: %s ok=%s grade=%s" % [last.get("text", "?"), last.get("ok", "?"), last.get("grade", "?")])
		if not bool(last.get("ok", false)):
			fails += 1
		m._foul_for_us = false
		m._pending_free_kick = false
		m._pending_penalty = false
		m.state = m.State.SIMULATING
		await get_tree().create_timer(0.5).timeout
	print("REGAIN PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0)
