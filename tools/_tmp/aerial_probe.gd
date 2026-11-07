extends Node
## Balones aéreos: lanza centros/balones largos a distintas alturas hacia un jugador
## y cuenta qué hizo (cabezazo, pecho, muslo, empeine, volea).
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
	var tally := {}
	for i in 24:
		var fp := PlayGenerator.make(["balon_largo", "elaborado", "desborde"][i % 3])
		fp.lane = 0.0
		fp.arrive = i % 3 != 0
		m._start_moment(fp.base, fp)
		await get_tree().create_timer(1.8).timeout
		# lanza a mano un balón aéreo desde 14-22 m hacia el receptor
		var recv: SoccerPlayer = m.star
		if OS.get_cmdline_user_args().has("box"):
			recv.reset_to(Vector3(40.0, 0.0, randf_range(-5.0, 5.0)), Vector3.RIGHT)
			for o: SoccerPlayer in m.teams[1]:
				if not o.is_keeper and SoccerMatch.flat_dist(o.global_position, recv.global_position) < 3.0:
					o.reset_to(o.global_position + Vector3(0, 0, 5), Vector3.LEFT)
		var mate: SoccerPlayer = m._nearest_of_team(0, recv.global_position, [recv], 40.0)
		if mate == null:
			continue
		var from: Vector3 = recv.global_position - Vector3(randf_range(14.0, 22.0), 0.0, randf_range(-4.0, 4.0))
		if OS.get_cmdline_user_args().has("bike"):
			from = recv.global_position + Vector3(randf_range(6.0, 9.0), 0.0, 14.0 * (1.0 if i % 2 == 0 else -1.0))
		mate.reset_to(from, Vector3.RIGHT)
		m._give_ball_now(mate)
		mate.cross_to_point(recv.global_position, ([1.7, 1.9, 2.0, 1.8] if OS.get_cmdline_user_args().has("bike") else [0.6, 1.0, 1.4, 1.8])[i % 4])
		var seen := ""
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 3500:
			await get_tree().physics_frame
			var ac: String = m._aerial_choice.get(recv, "")
			if ac != "":
				seen = ac
			if m.ball.owner_player == recv or m.ball.last_touch == recv:
				if m.ball.last_touch == recv and m.ball.owner_player == null:
					await get_tree().create_timer(0.1).timeout
				break
		var anim := String(recv._anim.current_animation) if recv._anim != null else ""
		if anim == "bicycle" and OS.get_cmdline_user_args().has("shot"):
			for k in 3:
				await get_tree().create_timer([0.0, 0.25, 0.5][k]).timeout
				get_viewport().get_texture().get_image().save_png("res://build/bike_%d_%d.png" % [i, k])
		var key := "%s/%s" % [seen if seen != "" else "-", anim]
		tally[key] = int(tally.get(key, 0)) + 1
		m.state = m.State.SIMULATING
	for k in tally:
		print("AEREO %s x%d" % [k, tally[k]])
	get_tree().quit(0)
