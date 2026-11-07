extends Node
## Jugadas de mano a mano (a favor, en contra y de portero): las arranca todas y
## mira dónde quedan tú, el del balón y el portero, y cómo acaba cada una.
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
	var ended := [""]
	m.moment_ended.connect(func(txt, ok): ended[0] = "%s %s" % ["OK" if ok else "FALLO", txt])
	for fam in ["mano_a_mano", "mano_a_mano", "mano_a_mano", "mano_a_mano", "mano_a_mano", "mano_a_mano",
			"persecucion", "persecucion", "ultimo_hombre", "ultimo_hombre"]:
		var fp := PlayGenerator.make(fam)
		ended[0] = ""
		m._start_moment(fp.base, fp)
		var t0 := Time.get_ticks_msec()
		while m.state != m.State.MOMENT and Time.get_ticks_msec() - t0 < 6000:
			await get_tree().process_frame
			if m.state == m.State.MOMENT_INTRO:
				m._on_tapped(Vector2.ZERO)
		await get_tree().create_timer(0.3).timeout
		var bo: SoccerPlayer = m.ball.owner_player
		var k: SoccerPlayer = m.teams[1][0] if fp.phase == "ataque" else m.teams[0][0]
		var sp := m.star.global_position
		print("%s/%s «%s» estado=%s tu=(%.0f,%.0f) balón=%s (%.0f,%.0f) portero=(%.0f,%.0f)" % [fam, fp.get("variant", "-"), fp.title,
			m.State.keys()[m.state], sp.x, sp.z, bo.name if bo else "-", m.ball.global_position.x, m.ball.global_position.z,
			k.global_position.x, k.global_position.z])
		t0 = Time.get_ticks_msec()
		while ended[0] == "" and Time.get_ticks_msec() - t0 < 12000:
			await get_tree().create_timer(0.5).timeout
			if fp.phase == "ataque" and m.ball.owner_player == m.star:
				# corre hacia la portería y define cerca
				var gl := m.opponent_goal_center(0)
				m._move_target = gl - Vector3(6.0, 0, 0)
				if SoccerMatch.flat_dist(m.star.global_position, gl) < 13.0:
					m.star.shoot_at(gl + Vector3(0, 0.6, randf_range(-3.0, 3.0)), 0.8)
		var kk: SoccerPlayer = m.teams[1][0] if fp.phase == "ataque" else m.teams[0][0]
		var lb: SoccerPlayer = m.ball.last_touch
		print("   tu=(%.0f,%.0f) ultimo toque=%s" % [m.star.global_position.x, m.star.global_position.z, lb.name if lb else "-"])
		print("   -> %s   (portero en x=%.1f)" % [ended[0] if ended[0] != "" else "sin terminar", kk.global_position.x])
		m.state = m.State.SIMULATING
		Engine.time_scale = 1.0
		await get_tree().create_timer(0.5).timeout
	var gk := PlayGenerator.make("mano_a_mano_gk")
	print("GK variantes ejemplo: %s «%s»" % [gk.variant, gk.title])
	get_tree().quit(0)
