extends Node
## Captura REAL (sin --headless, --resolution 576x1024) del prototipo
## match_v2: juego normal, tu jugada (con trazo), saque de banda tuyo,
## córner y festejo de gol. Salida en _pixellab_preview/proto_v2_*.png
##   godot --path . --resolution 576x1024 res://tools/ProtoMatchV2ShotProbe.tscn
var inst

func _ready() -> void:
	inst = (load("res://prototypes/match_v2/ProtoMatch.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(inst)
	await _frames(90)
	_save("proto_v2_play.png")
	var tries: int = 0
	while not inst.sim.user_has_ball() and tries < 3000:
		await get_tree().process_frame
		tries += 1
	await _frames(40)
	var u = inst.sim.user()
	var p0: Vector2 = inst.w2s(u.pos) + Vector2(0, 20)
	inst.touching = true
	inst.g_start = p0
	inst.g_mode = ""
	inst.g_points = PackedVector2Array([p0, p0 + Vector2(-20, -60), p0 + Vector2(-30, -140)])
	await _frames(2)
	_save("proto_v2_userball.png")
	# Remate con la línea de trayectoria (y estrella antes de deslizar).
	inst.touching = false
	inst.g_points = PackedVector2Array()
	u.pos = Vector2(26, 22)
	inst.sim.ball_pos = u.pos
	inst.sim._give_ball(u)
	inst.cam_lock = Vector2(30, 18)
	await _frames(25)
	_save("proto_v2_star.png")
	print("STAR best=", inst.sim.best_pass_option(), " scale=", inst.cur_scale, " owner_user=", inst.sim.user_has_ball(), " touching=", inst.touching)
	var q0: Vector2 = inst.w2s(u.pos) + Vector2(0, 20)
	inst.touching = true
	inst.g_start = q0
	inst.g_start_ms = Time.get_ticks_msec()
	inst.g_on_user = false
	inst.g_points = PackedVector2Array([q0, q0 + Vector2(10, -70), q0 + Vector2(40, -150), q0 + Vector2(90, -220)])
	await _frames(2)
	_save("proto_v2_aim.png")
	inst.touching = false
	inst.g_points = PackedVector2Array()
	inst.cam_lock = Vector2(-999, -999)
	inst.touching = false
	inst.g_points = PackedVector2Array()
	# Saque de banda: el usuario cerca de la banda izquierda.
	u.pos = Vector2(6, 40)
	inst.sim._start_set_piece("throw", 0, Vector2(0.2, 38))
	tries = 0
	while not inst.sim.set_piece.get("ready", false) and tries < 600:
		await get_tree().process_frame
		tries += 1
	await _frames(30)
	_save("proto_v2_throw.png")
	print("throw ready=", inst.sim.set_piece.get("ready", false), " taker_user=", int(inst.sim.set_piece.get("taker", -1)) == inst.sim.user_idx)
	# Córner del rival... no: córner a favor (equipo 0, arriba a la derecha).
	inst.sim._start_set_piece("corner", 0, Vector2(67.5, 0.5))
	await _frames(150)
	_save("proto_v2_corner.png")
	# Tiro libre tuyo cerca del área: barrera + árbitro.
	inst.sim._end_set_piece()
	inst.interlude_t = 0.0
	inst.card_panel.visible = false
	inst.sim.setup_play("tiro_libre", 30)
	inst.cam = inst.sim.ball_pos
	await _frames(90)
	_save("proto_v2_freekick.png")
	# Banquillos y túnel (lado izquierdo, mitad de cancha).
	inst.cam_lock = Vector2(7.0, 52.5)
	await _frames(20)
	_save("proto_v2_bench.png")
	inst.cam_lock = Vector2(-999, -999)
	# Arquero rival con la pelota en las manos.
	inst.sim._end_set_piece()
	inst.sim._give_ball(inst.sim.agents[11])
	inst.sim.gk_hold = 99.0
	await _frames(30)
	_save("proto_v2_gkhold.png")
	# Festejo de gol del usuario.
	inst.sim._end_set_piece()
	inst.sim.score[0] += 1
	inst.user_celeb = "celeb_avion"
	inst.sim._start_celebration(u)
	inst.sim.restart_timer = 3.0
	inst.sim.pending_kickoff_team = 1
	await _frames(70)
	_save("proto_v2_goal.png")
	get_tree().quit(0)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _save(n: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://_pixellab_preview/" + n))
	print("CAPTURA OK ", n)
