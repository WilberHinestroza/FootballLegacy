extends Node
## Momento del partido: tu gol en una jugada se guarda y, al pitazo final, se
## repite solo antes de la despedida (OUTRO). Con ventana guarda build/hl_NN.png.
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
	# Jugada de ataque: tu remate entra
	var fp := PlayGenerator.make("mano_a_mano")
	m._start_moment(fp.base, fp)
	await get_tree().create_timer(2.5).timeout
	m.star.reset_to(Vector3(44.0, 0.0, 1.0), Vector3.RIGHT)
	m._give_ball_now(m.star)
	m.star.shoot_exact(Vector3(52.6, 0.8, 2.6), 1.0)
	var t0 := Time.get_ticks_msec()
	while m.state != m.State.MOMENT_RESULT and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().physics_frame
	print("HL jugada: estado=%s gol=%d goles=%d" % [m.State.keys()[m.state], m._moment_goal, m.match_stats.me.goals])
	await get_tree().create_timer(2.0).timeout
	print("HL has_best=%s info=%s" % [m.replay.has_best(), m.replay.best_info])
	m.minute = 90.0
	m._finish_match()
	var shots := 0
	var saw_outro := false
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		await get_tree().create_timer(0.8).timeout
		if not DisplayServer.get_name() == "headless" and shots < 8:
			get_viewport().get_texture().get_image().save_png("res://build/hl_%02d.png" % shots)
			shots += 1
		if m.state == m.State.OUTRO:
			saw_outro = true
			break
	print("HL fin: estado=%s outro=%s" % [m.State.keys()[m.state], saw_outro])
	print("HL PROBE %s" % ("OK" if saw_outro and m.replay.best_info.has("label") else "FAIL"))
	get_tree().quit(0)
