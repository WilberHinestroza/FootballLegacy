extends Node
## Cabezazos: centros desde la banda a tu jugador en el área (con un defensa cerca),
## sin tocar nada. Cuenta quién cabecea: tú, el rival o nadie.
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
	var tally := {"tú": 0, "rival": 0, "nadie": 0, "otro": 0}
	var hits := 0
	for i in 24:
		var fp := PlayGenerator.make("elaborado")
		m._start_moment(fp.base, fp)
		await get_tree().create_timer(0.3).timeout
		m.state = m.State.MOMENT
		var recv: SoccerPlayer = m.star
		recv.reset_to(Vector3(randf_range(41.0, 45.0), 0.0, randf_range(-4.0, 4.0)), Vector3.RIGHT)
		for o: SoccerPlayer in m.teams[1]:
			if not o.is_keeper:
				o.reset_to(o.global_position + Vector3(-30.0, 0, 0), Vector3.LEFT)
		var marker: SoccerPlayer = m.teams[1][3]
		marker.reset_to(recv.global_position + Vector3(randf_range(0.8, 2.0), 0, randf_range(-1.5, 1.5)), Vector3.LEFT)
		var mate: SoccerPlayer = m.teams[0][7]
		var side := 1.0 if i % 2 == 0 else -1.0
		mate.reset_to(Vector3(randf_range(36.0, 44.0), 0.0, side * 26.0), Vector3(0, 0, -side))
		m._give_ball_now(mate)
		m._move_target = null
		var aim := recv.global_position + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
		mate.cross_to_point(aim, [1.7, 1.85, 2.0][i % 3])
		var who := "nadie"
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 3500:
			await get_tree().physics_frame
			var lt: SoccerPlayer = m.ball.last_touch
			if lt != null and lt != mate:
				who = "tú" if lt == recv else ("rival" if lt.team == 1 else "otro")
				break
		tally[who] += 1
		var a := String(recv._anim.current_animation) if recv._anim != null else ""
		if who == "tú" and a == "header":
			hits += 1
		m.state = m.State.SIMULATING
		Engine.time_scale = 1.0
		await get_tree().create_timer(0.3).timeout
	print("CABEZAZOS %s (de cabeza tuyos: %d)" % [tally, hits])
	get_tree().quit(0)
