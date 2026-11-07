extends Node
## Lanzadores designados y capitán: quién cobra penaltis, faltas y córners (con un
## compañero y contigo de lanzador) y una foto del brazalete (con ventana).
func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	var mine: MatchTeam = MatchState.home_team if String(fx.get("home_club_id", "")) == pl.club_id else MatchState.away_team
	var u: PlayerData = MatchState.user_player
	if not mine.starting_xi.has(u):
		mine.bench.erase(u)
		for i in mine.starting_xi.size():
			if (mine.starting_xi[i] as PlayerData).position == u.position:
				mine.starting_xi[i] = u
				break
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	var m: SoccerMatch = scr._match
	await get_tree().create_timer(1.0).timeout
	m._end_walkout()
	if m.state == m.State.CUTSCENE:
		m._end_cutscene()
	m._moments.clear()
	print("CONFIG home=%s" % m.config.get("home_set_pieces", {}))
	print("CONFIG away=%s" % m.config.get("away_set_pieces", {}))
	for t in 2:
		var d := {}
		for k in m._takers[t]:
			d[k] = m._name_of(m._takers[t][k])
		print("TAKERS %d %s" % [t, d])
	var ended := [""]
	m.moment_ended.connect(func(txt, ok): ended[0] = "%s %s" % ["OK" if ok else "FALLO", txt])
	var cases := [["PENALTY", false], ["FREE_KICK", false], ["CORNER", false], ["CORNER", true], ["PENALTY", true]]
	for c in cases:
		var kind: int = m.Moment[c[0]]
		var real: Dictionary = m._takers[0].duplicate()
		if c[1]:
			for k in ["penalty", "free_kick", "corner"]:
				m._takers[0][k] = m.star
		else:
			for k in ["penalty", "free_kick", "corner"]:
				if m._takers[0].get(k) == m.star:
					m._takers[0][k] = m.teams[0][9]
		ended[0] = ""
		var fp := {} if c[0] == "PENALTY" else PlayGenerator.make("tiro_libre" if c[0] == "FREE_KICK" else "corner")
		var goals0: int = int(m.match_stats.me.goals)
		var ok0: int = int(m.match_stats.me.moments_ok)
		var fail0: int = int(m.match_stats.me.moments_fail)
		m._start_moment(kind, fp)
		var t0 := Time.get_ticks_msec()
		while m.state != m.State.MOMENT and Time.get_ticks_msec() - t0 < 5000:
			await get_tree().process_frame
		var bo: SoccerPlayer = m.ball.owner_player
		if DisplayServer.get_name() != "headless":
			await get_tree().create_timer(0.4).timeout
			get_viewport().get_texture().get_image().save_png("res://build/sp_%s_%s.png" % [c[0], c[1]])
		print("   balón en (%.1f, %.1f)  tu=(%.1f,%.1f)" % [m.ball.global_position.x, m.ball.global_position.z, m.star.global_position.x, m.star.global_position.z])
		print("%s usuario=%s «%s» balón=%s (es tu jugador=%s) cross_pending=%s" % [c[0], c[1], m.play.get("title", ""),
			m._name_of(bo) if bo else "-", bo == m.star, m._cross_pending])
		if c[0] == "CORNER" and c[1]:
			var cam: Camera3D = m._camera
			var a := cam.unproject_position(m.ball.global_position)
			var b := cam.unproject_position(m.opponent_goal_center(0) + Vector3(-7.0, 0, 1.5))
			m._on_swiped(PackedVector2Array([a, a.lerp(b, 0.5), b]), 0.35)
			print("   gesto de córner: cross_pending=%s balón vuela=%s" % [m._cross_pending, m.ball.owner_player == null])
		if c[0] == "PENALTY" and c[1]:
			m.star.shoot_at(m.opponent_goal_center(0) + Vector3(0, 0, 2.5), 0.8)
		t0 = Time.get_ticks_msec()
		while ended[0] == "" and Time.get_ticks_msec() - t0 < 12000:
			await get_tree().create_timer(0.3).timeout
		print("   -> %s  goles_tuyos+%d asist=%d ok+%d fallo+%d" % [ended[0] if ended[0] != "" else "sin terminar",
			int(m.match_stats.me.goals) - goals0, int(m.match_stats.me.assists),
			int(m.match_stats.me.moments_ok) - ok0, int(m.match_stats.me.moments_fail) - fail0])
		m._takers[0] = real
		m.state = m.State.SIMULATING
		Engine.time_scale = 1.0
		await get_tree().create_timer(0.5).timeout
	if DisplayServer.get_name() != "headless":
		var cap: SoccerPlayer = m._takers[0].get("captain")
		if cap != null:
			m.state = m.State.SIMULATING
			var cam := Camera3D.new()
			m.add_child(cam)
			cam.global_position = cap.global_position + cap.facing * 0.6 + cap.facing.cross(Vector3.UP) * -2.3 + Vector3.UP * 1.5
			cam.look_at(cap.global_position + Vector3.UP * 1.2)
			cam.make_current()
			m._hud.visible = false
			for i in 3:
				await RenderingServer.frame_post_draw
			cam.global_position = cap.global_position + cap.facing * 0.6 + cap.facing.cross(Vector3.UP) * -2.3 + Vector3.UP * 1.5
			cam.look_at(cap.global_position + Vector3.UP * 1.2)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/captain_band.png")
			print("FOTO capitán %s" % m._name_of(cap))
			var av: PlayerAvatar = cap._avatar
			print("BAND items=%s" % [av._items.has("captain")])
			if av._items.has("captain"):
				var att: Node3D = av._items["captain"][0]
				var mi: Node3D = att.get_child(0).get_child(0)
				var b := ItemCatalog.find_bone(av.skeleton, "LeftArm")
				var cam2 := Camera3D.new()
				m.add_child(cam2)
				var side := (mi.global_position - cap.global_position)
				side.y = 0.0
				cam2.global_position = mi.global_position + side.normalized() * 1.6 + cap.facing * 0.8 + Vector3.UP * 0.3
				cam2.look_at(mi.global_position)
				cam2.make_current()
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://build/captain_band2.png")
				print("BAND en %s  hombro %s  visible=%s" % [mi.global_position, av.skeleton.global_transform * av.skeleton.get_bone_global_pose(b).origin, mi.is_visible_in_tree()])
	get_tree().quit(0)
