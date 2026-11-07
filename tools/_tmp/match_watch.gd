extends Node
## Revisión visual del partido 3D (con ventana, 1024x576): juego ambiente (toda la IA)
## y una jugada tuya sin tocar nada; guarda fotos en build/watch_XX.png.
##   godot --path . --resolution 1024x576 res://tools/_tmp/MatchWatch.tscn
func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	var args := OS.get_cmdline_user_args()
	var force_play := ""
	var force_arrive := args.has("arrive")
	for a in args:
		if a.begins_with("pos="):
			pl.detailed_position = a.substr(4)
			pl.position = Positions.broad_of(pl.detailed_position)
		elif a.begins_with("foot="):
			pl.dominant_foot = a.substr(5)
		elif a.begins_with("play="):
			force_play = a.substr(5)
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
	if args.has("rain"):
		Engine.set_meta("force_weather", 1)
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	var m: SoccerMatch = scr._match
	await get_tree().create_timer(1.0).timeout
	_shot(0)
	m._end_walkout()
	if m.state == m.State.CUTSCENE:
		m._end_cutscene()
	if args.has("subout"):
		m._moments.clear()
		await get_tree().create_timer(1.5).timeout
		m.minute = 70.0
		m._sub_off_star(70)
		for k in 12:
			await get_tree().create_timer(0.6).timeout
			print("SUB t=%d state=%s walk=%s z=%.1f nombre=%s" % [k, m.State.keys()[m.state], m._sub_walk,
				m.star.global_position.z, m._names[0][m.star.index]])
			if DisplayServer.get_name() != "headless":
				get_viewport().get_texture().get_image().save_png("res://build/sub_%02d.png" % k)
		get_tree().quit(0)
		return
	if args.has("half"):
		m._moments.clear()
		await get_tree().create_timer(1.0).timeout
		m._start_halftime_walk()
		for k in 14:
			await get_tree().create_timer(0.7).timeout
			print("HALF t=%.1f state=%s visibles=%d" % [m._outro_t, m.State.keys()[m.state],
				m.players.filter(func(q: SoccerPlayer) -> bool: return q.visible).size()])
			if DisplayServer.get_name() != "headless":
				get_viewport().get_texture().get_image().save_png("res://build/half_%02d.png" % k)
		m._locker_wait = 0.0
		await get_tree().create_timer(1.5).timeout
		print("HALF despues: state=%s visibles=%d ball=%s" % [m.State.keys()[m.state],
			m.players.filter(func(q: SoccerPlayer) -> bool: return q.visible).size(), m.ball.visible])
		get_tree().quit(0)
		return
	if OS.get_cmdline_user_args().has("outro"):
		m._moments.clear()
		await get_tree().create_timer(1.0).timeout
		m.score = [0, 1]
		m.minute = 90.0
		m._finish_match()
		if args.has("shake"):
			print("PAIRS %d state=%s" % [m._outro_shake.size() / 2, m.State.keys()[m.state]])
			for q: SoccerPlayer in m.players:
				if q.team == 1 and q.visible:
					print("  rival d=%.1f" % SoccerMatch.flat_dist(q.global_position, m.star.global_position))
			for k in 16:
				await get_tree().create_timer(0.5).timeout
				var ph := {}
				for q in m._outro_shake:
					var key: String = String(m._outro_shake[q].phase)
					ph[key] = int(ph.get(key, 0)) + 1
				var sd: Dictionary = m._outro_shake.get(m.star, {})
				var dd := -1.0
				if not sd.is_empty():
					dd = SoccerMatch.flat_dist(m.star.global_position, (sd.partner as SoccerPlayer).global_position)
				print("SHAKE t=%.1f %s star=%s d=%.2f" % [m._outro_t, ph, sd.get("phase", "-"), dd])
				if String(sd.get("phase", "")) == "shake" and DisplayServer.get_name() != "headless":
					var cam := Camera3D.new()
					m.add_child(cam)
					var pp: SoccerPlayer = sd.partner
					var mid := (m.star.global_position + pp.global_position) * 0.5
					var side := SoccerMatch.flat(pp.global_position - m.star.global_position).normalized().cross(Vector3.UP)
					cam.global_position = mid + side * 3.2 + Vector3.UP * 1.3
					cam.look_at(mid + Vector3.UP * 1.1)
					cam.make_current()
					m._hud.visible = false
					await RenderingServer.frame_post_draw
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png("res://build/shake_%d.png" % k)
					m._camera.make_current()
					m._hud.visible = true
					cam.queue_free()
	elif OS.get_cmdline_user_args().has("goal"):
		m._moments.clear()
		await get_tree().create_timer(1.5).timeout
		m._start_ambient_goal(1, int(m.minute), "")
	elif force_play != "":
		var fp := PlayGenerator.make(force_play)
		PlayGenerator._fit_to_position(fp, PlayGenerator.POSITION_STYLE.get(m.user_detailed, {}))
		if force_arrive:
			fp.arrive = true
		print("JUGADA %s lado %s llega %s puesto %s slot_z %.1f" % [fp.family, fp.side, fp.get("arrive", false), m.user_detailed, m.star.global_position.z])
		m._moments = [{"minute": m.minute + 3.0, "kind": fp.base, "play": fp}]
	else:
		m._moments = [{"minute": m.minute + 6.0, "kind": m.Moment.ATTACK}]
	if args.has("trace"):
		m.moment_ended.connect(func(txt, ok): print("FIN JUGADA ok=%s %s" % [ok, txt]))
		var last := [""]
		get_tree().physics_frame.connect(func() -> void:
			if m.state != m.State.MOMENT:
				return
			var o: String = m.ball.owner_player.name if m.ball.owner_player != null else "-"
			if args.has("ballpath") and Engine.get_physics_frames() % 6 == 0:
				var bt: Node3D = m.ball.last_touch
				print("    bola (%.1f,%.1f,%.1f) toque %s" % [m.ball.global_position.x, m.ball.global_position.y, m.ball.global_position.z, bt.name if bt != null else "-"])
			if o != last[0]:
				last[0] = o
				var sp: Vector3 = m.star.global_position
				print("  t%.2f dueño %s  star %s (%.1f,%.1f) bola (%.1f,%.1f)" % [m._moment_timer, o, m.star.name, sp.x, sp.z, m.ball.global_position.x, m.ball.global_position.z]))
	var k := 1
	var t0 := Time.get_ticks_msec()
	var started := false
	m.moment_started.connect(func(_t): started = true)
	while k < 26 and (Time.get_ticks_msec() - t0) < 60000:
		await get_tree().create_timer(0.6 if m.state != m.State.CELEBRATION else 0.4).timeout
		if m.state == m.State.CELEBRATION and m._celeb_dance < 6.0:
			m._celeb_dance = 6.0
		_shot(k)
		print("shot %02d estado %s min %.1f balón %s" % [k, m.State.keys()[m.state], m.minute,
			m.ball.owner_player.name if m.ball.owner_player != null else "-"])
		k += 1
	get_tree().quit(0)

func _shot(k: int) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/watch_%02d.png" % k))
