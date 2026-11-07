extends Node
## Capturas de las ceremonias del partido 3D (con ventana):
##   godot --path . res://tools/M3DCeremonyShot.tscn -- <etiqueta> trophy|mvp
## Deja build/m3d_cer_<etiqueta>_NN.png. Solo toca slot_3 (carrera de prueba).
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var tag: String = args[0] if args.size() > 0 else "x"
	var kind: String = args[1] if args.size() > 1 else "trophy"
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	FieldBuilder.time_of_day = 0
	Engine.set_meta("keep_time_of_day", true)
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	var m: SoccerMatch = scr._match
	await get_tree().create_timer(0.8).timeout
	m._end_walkout()
	await get_tree().create_timer(1.0).timeout
	var shots := 0
	if args.has("pintada"):
		# Comparar con la ropa pintada (sin prendas por piezas)
		for av: PlayerAvatar in find_children("*", "PlayerAvatar", true, false):
			av.set_garments([])
	if kind == "draws":
		# Coste de render: llamadas de dibujo y objetos en un cuadro del partido
		for i in 3:
			await get_tree().create_timer(1.0).timeout
			print("DRAWS calls=%d objs=%d prims=%d avatars=%d" % [
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				find_children("*", "PlayerAvatar", true, false).size()])
	elif kind == "bench":
		# Banquillo local de frente y de lado: suplentes sentados (que no se hundan)
		var cam := Camera3D.new()
		cam.fov = 40.0
		m.add_child(cam)
		cam.make_current()
		var bench: Array = m.staff._bench_people[0]
		var mid: Node3D = bench[bench.size() / 2]
		for view: Vector3 in [Vector3(0.0, 1.3, 4.5), Vector3(3.0, 1.0, 2.2), Vector3(-2.0, 0.7, 1.8)]:
			cam.global_position = mid.global_position + view
			cam.look_at(mid.global_position + Vector3(0.0, 0.7, 0.0))
			for k in 6:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/m3d_cer_%s_%02d.png" % [tag, shots])
			shots += 1
	elif kind == "var":
		# Fuera de juego pitado (bandera) y luego revisión del VAR de un gol
		m.state = SoccerMatch.State.SIMULATING
		var runner: SoccerPlayer = m.teams[0][9]
		var passer: SoccerPlayer = m.teams[0][5]
		passer.reset_to(Vector3(18.0, 0.0, 2.0), Vector3.RIGHT)
		runner.reset_to(Vector3(m.offside_line_world(0) + 2.5, 0.0, 6.0), Vector3.RIGHT)
		m._on_ball_kicked(passer, "pass")
		m._give_ball(runner)
		for k in 2:
			await get_tree().create_timer(0.5).timeout
			get_viewport().get_texture().get_image().save_png("res://build/m3d_cer_%s_%02d.png" % [tag, shots])
			shots += 1
		runner.reset_to(Vector3(m.offside_line_world(0) + 0.3, 0.0, 6.0), Vector3.RIGHT)
		m._var_pending = {"team": 0, "offside": true, "player": runner,
			"line_w": m.offside_line_world(0), "px_w": runner.global_position.x, "z": 6.0}
		m._on_goal_area_entered(m.ball, 0)
		for k in 5:
			await get_tree().create_timer(0.9).timeout
			get_viewport().get_texture().get_image().save_png("res://build/m3d_cer_%s_%02d.png" % [tag, shots])
			shots += 1
	elif kind == "locker":
		m._start_locker()
		for k in 4:
			await get_tree().create_timer(1.5).timeout
			get_viewport().get_texture().get_image().save_png("res://build/m3d_cer_%s_%02d.png" % [tag, shots])
			shots += 1
	elif kind == "staff":
		# Primeros planos del personal de banda (camarógrafos, fotógrafos, recogepelotas)
		var cam := Camera3D.new()
		cam.fov = 40.0
		m.add_child(cam)
		cam.make_current()
		m.set_process(false)
		var picks: Array = m.staff._followers.slice(0, 20)
		for f: Node3D in picks:
			var fwd := f.global_transform.basis.z.normalized()
			var side := f.global_transform.basis.x.normalized()
			cam.global_position = f.global_position + fwd * 2.6 + side * 1.4 + Vector3.UP * 1.5
			cam.look_at(f.global_position + Vector3.UP * 1.0)
			for k in 4:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/m3d_cer_%s_%02d.png" % [tag, shots])
			shots += 1
	elif kind == "breakdown":
		# Qué grupo pesa más: se apaga cada uno y se mide la diferencia
		var info := func(label: String) -> void:
			for k in 3:
				await RenderingServer.frame_post_draw
			print("BREAK %-12s calls=%d prims=%d" % [label,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		get_tree().paused = true
		await info.call("todo")
		var sun := m.find_children("*", "DirectionalLight3D", true, false)
		for l: DirectionalLight3D in sun:
			l.shadow_enabled = false
		await info.call("sin_sombra")
		for l: DirectionalLight3D in sun:
			l.shadow_enabled = true
		var mms := m.find_children("*", "MultiMeshInstance3D", true, false)
		for mm: MultiMeshInstance3D in mms:
			print("  MM %s inst=%d tris~%d" % [mm.name, mm.multimesh.instance_count,
				mm.multimesh.instance_count * (mm.multimesh.mesh.get_faces().size() / 3 if mm.multimesh.mesh else 0)])
			mm.visible = false
		await info.call("sin_multimesh")
		for mm: MultiMeshInstance3D in mms:
			mm.visible = true
		var avs := find_children("*", "PlayerAvatar", true, false)
		for av: Node3D in avs:
			av.visible = false
		await info.call("sin_avatares")
		get_tree().quit(0)
		return
	elif kind == "match":
		# Partido entero tal cual (sin tocar nada): una captura por segundo real con el estado
		var secs := int(args[2]) if args.size() > 2 else 150
		for i in secs:
			await get_tree().create_timer(1.0, true, false, true).timeout
			get_viewport().get_texture().get_image().save_png("res://build/m3d_cer_%s_%03d.png" % [tag, shots])
			print("FRAME %03d min=%d state=%s score=%s" % [shots, int(m.minute), SoccerMatch.State.keys()[m.state], str(m.score)])
			shots += 1
			if m.state == SoccerMatch.State.ENDED:
				break
	elif kind == "ambient" or kind == "miss":
		# Gol (o fallo) de la simulación: ¿el portero se estira bien y nadie queda quieto?
		for rep in 3:
			if kind == "ambient":
				m._start_ambient_goal(rep % 2, 30 + rep, "")
			else:
				m._start_ambient_miss(rep % 2, 30 + rep, "")
			for i in 8:
				await get_tree().create_timer(0.22).timeout
				get_viewport().get_texture().get_image().save_png("res://build/m3d_cer_%s_%02d.png" % [tag, shots])
				shots += 1
			while m.state != SoccerMatch.State.SIMULATING:
				await get_tree().create_timer(0.3).timeout
			await get_tree().create_timer(0.5).timeout
	elif kind == "final":
		m.score = [3, 2]
		m._log_goal(0, 12, m.profile.player_name, false, true)
		m._log_goal(1, 34, "Marco Ruiz", false)
		m._log_goal(0, 58, "Diego Salas", true)
		m._log_goal(1, 71, "Marco Ruiz", false)
		m._log_goal(0, 89, m.profile.player_name, false, true)
		m._start_outro()
		for i in 6:
			await get_tree().create_timer(0.6).timeout
			get_viewport().get_texture().get_image().save_png("res://build/m3d_cer_%s_%02d.png" % [tag, shots])
			shots += 1
	elif kind == "trophy":
		SoccerMatch.config["final_trophy"] = "Copa de Campeones"
		m.score = [2, 1]
		m._finish_match()
		var t := 0.0
		while t < TrophyCeremony.DURATION + 1.5:
			await get_tree().create_timer(0.5).timeout
			t += 0.5
			get_viewport().get_texture().get_image().save_png("res://build/m3d_cer_%s_%02d.png" % [tag, shots])
			shots += 1
	else:
		m.state = SoccerMatch.State.MVP_CEREMONY
		for p: SoccerPlayer in m.players:
			p.visible = false
		var c: Node3D = load("res://match3d/scripts/mvp_ceremony.gd").new()
		m.add_child(c)
		var done := [false]
		c.connect("finished", func() -> void: done[0] = true)
		c.call("start", m, m.star, "Tu Jugador", FieldBuilder.home_color)
		var t2 := 0.0
		while not done[0] and t2 < 14.0:
			await get_tree().create_timer(0.4).timeout
			t2 += 0.4
			get_viewport().get_texture().get_image().save_png("res://build/m3d_cer_%s_%02d.png" % [tag, shots])
			shots += 1
	print("CEREMONY ", kind, " cuadros=", shots)
	get_tree().quit(0)
