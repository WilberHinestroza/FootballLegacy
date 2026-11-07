extends Node
## Festejo: el goleador llega al banderín aunque haya rivales en el camino.
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
	for k in 3:
		var scorer: SoccerPlayer = m.teams[0][9]
		scorer.reset_to(Vector3(40.0 * m.attack_dir(0), 0.0, 6.0), Vector3.RIGHT)
		m._start_goal_celebration(scorer, 0, func() -> void: m.state = m.State.SIMULATING)
		# Pared de rivales entre él y el banderín
		var spot: Vector3 = m._celeb_spot
		var mid := scorer.global_position.lerp(spot, 0.5)
		for i in 4:
			var r: SoccerPlayer = m.teams[1][2 + i]
			r.reset_to(mid + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.5, 1.5)), Vector3.LEFT)
		var t0 := Time.get_ticks_msec()
		while not m._celeb_dancing and Time.get_ticks_msec() - t0 < 9000:
			await get_tree().physics_frame
		var d := SoccerMatch.flat_dist(scorer.global_position, spot)
		print("CELEB %d: baila=%s a %.1f m del banderín en %.1f s" % [k, m._celeb_dancing, d, (Time.get_ticks_msec() - t0) / 1000.0])
		if d > 1.2:
			fails += 1
		m._end_goal_celebration()
		m.state = m.State.SIMULATING
		await get_tree().create_timer(0.5).timeout
	print("CELEB PROBE %s" % ("OK" if fails == 0 else "FAIL"))
	get_tree().quit(0)
