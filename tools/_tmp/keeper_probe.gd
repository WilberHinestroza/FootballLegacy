extends Node
## Porteros: tiros desde varias distancias y ángulos a distintos puntos de la portería.
## Cuenta gol / parada / fuera y los balones que ATRAVIESAN al portero (pasan por su
## cuerpo o sus manos sin que lo toque y acaban dentro).
##   godot --headless --path . res://tools/_tmp/KeeperProbe.tscn
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
	var tally := {"goal": 0, "save": 0, "out": 0, "through": 0, "dive": 0}
	var by_dist := {}
	var n := 30
	for i in n:
		var fp := PlayGenerator.make("desborde")
		m._start_moment(fp.base, fp)
		await get_tree().create_timer(0.3).timeout
		m.state = m.State.MOMENT
		var goal := m.opponent_goal_center(0)
		var dir := m.attack_dir(0)
		var dist: float = [11.0, 16.0, 22.0][i % 3]
		var ang: float = [-0.5, -0.2, 0.0, 0.25, 0.5][(i / 3) % 5]
		var from := goal - Vector3(dir * dist * cos(ang), 0.0, dist * sin(ang))
		var keeper: SoccerPlayer = m.teams[1][0]
		for o: SoccerPlayer in m.teams[1]:
			if not o.is_keeper:
				o.reset_to(o.global_position + Vector3(-dir * 25.0, 0, 0), Vector3.RIGHT)
		for o: SoccerPlayer in m.teams[0]:
			if o != m.star:
				o.reset_to(Vector3(-dir * 10.0, 0, o.global_position.z), Vector3.RIGHT)
		m.star.reset_to(from, Vector3(dir, 0, 0))
		m._give_ball_now(m.star)
		# el portero se coloca unos instantes
		for k in 40:
			await get_tree().physics_frame
			m.star.move_input = Vector3.ZERO
			if m.ball.owner_player != m.star:
				break
		if m.ball.owner_player != m.star:
			m._give_ball_now(m.star)
		var tz: float = [-3.4, -2.2, -1.0, 0.0, 1.0, 2.2, 3.4][randi() % 7]
		var ty: float = [0.3, 0.9, 1.8, 2.4][randi() % 4]
		var target := goal + Vector3(0, ty, tz)
		var spd: float = [18.0, 23.0, 28.0][randi() % 3]
		var flat_d := SoccerMatch.flat_dist(m.star.global_position, target)
		var flight := SoccerBall.flight_time(flat_d, spd)
		var vel := SoccerMatch.flat(target - m.star.global_position).normalized() * spd
		vel.y = SoccerBall.lift_for(target.y - 0.11, flight)
		var score0: int = m.score[0]
		m.star.shoot_vector(vel, 0.0)
		var outcome := ""
		var touched := false
		var dived := false
		var near_body := INF
		var crossed := false
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 4000:
			await get_tree().physics_frame
			if keeper.is_diving():
				dived = true
			if m.ball.last_touch == keeper or m.ball.owner_player == keeper:
				touched = true
			var b := m.ball.global_position
			if not crossed and (b.x - keeper.global_position.x) * dir > 0.0 and m.ball.last_touch == m.star:
				crossed = true
				var a := keeper.global_position + Vector3.UP * 0.35
				var h := keeper.hands_position()
				var cp := Geometry3D.get_closest_point_to_segment(b, a, h)
				near_body = b.distance_to(cp)
			if m.score[0] > score0:
				outcome = "goal"
				break
			if touched and m.ball.owner_player == keeper:
				outcome = "save"
				break
			if (b.x - goal.x) * dir > 0.3:
				outcome = "goal" if m.score[0] > score0 else ("save" if touched else "out")
				if outcome == "out" and absf(b.z - goal.z) < SoccerMatch.GOAL_WIDTH * 0.5 and b.y < SoccerMatch.GOAL_HEIGHT:
					await get_tree().create_timer(0.3).timeout
					outcome = "goal" if m.score[0] > score0 else "out"
				break
		if outcome == "":
			outcome = "save" if touched else "out"
		if outcome == "goal" and touched:
			outcome = "goal"
		tally[outcome] += 1
		if dived:
			tally.dive += 1
		if outcome == "goal" and not touched and near_body < 0.35:
			tally.through += 1
			print("  ATRAVIESA d=%.0f tz=%.1f ty=%.1f v=%.0f cuerpo=%.2f estirada=%s" % [dist, tz, ty, spd, near_body, dived])
		print("TIRO %d d=%.0f tz=%.1f ty=%.1f v=%.0f -> %s toco=%s estirada=%s" % [i, dist, tz, ty, spd, outcome, touched, dived])
		var key := "%dm" % int(dist)
		if not by_dist.has(key):
			by_dist[key] = {"goal": 0, "save": 0, "out": 0}
		by_dist[key][outcome] += 1
		m.state = m.State.SIMULATING
		Engine.time_scale = 1.0
		m.score = [score0, m.score[1]]
		await get_tree().create_timer(0.2).timeout
	print("KEEPER %s" % tally)
	print("KEEPER por distancia %s" % by_dist)
	var on: int = int(tally.goal) + int(tally.save)
	print("KEEPER goles/tiros a puerta = %.0f%%" % (100.0 * tally.goal / maxf(on, 1)))
	get_tree().quit(0)
