extends SceneTree
## Captura del ARCO del prototipo match_v2 (con ventana):
##   godot --path . --resolution 576x1024 -s res://tools/proto_goal_probe.gd
## Salida: _pixellab_preview/proto_v2_goal.png (arco quieto) y
## proto_v2_goal_dive.png (arquero tirado después de una estirada).
var inst

func _initialize() -> void:
	inst = (load("res://prototypes/match_v2/ProtoMatch.tscn") as PackedScene).instantiate()
	root.add_child(inst)
	_run()

func _run() -> void:
	await _frames(60)
	inst.interlude_t = 0.0
	inst.card_panel.visible = false
	inst.cam_lock = Vector2(34, 10)
	await _frames(20)
	_save("proto_v2_goal.png")
	await _frames(2)
	var gk = inst.sim._goalkeeper(1)
	gk.pos = Vector2(34, 1.5)
	inst.sim._act(gk, "estirada", Vector2(1, 0))
	gk.action_t = inst.sim.t - 1.0
	await _frames(3)
	_save("proto_v2_goal_dive.png")
	await _frames(2)
	# Arquero con la pelota en las manos: sale caminando (el nuestro, abajo).
	gk = inst.sim._goalkeeper(0)
	inst.sim.plays_mode = false # que no se corte la jugada al tenerla el arquero
	inst.sim.play_over = false
	inst.interlude_t = 0.0
	inst.card_panel.visible = false
	inst.sim.phase = "play"
	gk.pos = Vector2(34, 101)
	inst.cam_lock = Vector2(34, 96)
	gk.stun = 0.0
	gk.action = ""
	inst.sim.flight = {}
	inst.sim.ball_pos = gk.pos
	inst.sim._give_ball(gk)
	inst.sim._act(gk, "hold")
	await _frames(30)
	print("GK carry y=", gk.pos.y, " vel=", gk.vel, " owner_gk=", inst.sim.owner == gk.idx)
	inst.lbl_toast.modulate.a = 0.0
	_save("proto_v2_goal_carry.png")
	await _frames(2)
	# REMATE cuadro a cuadro: tu jugador al borde del área, tiro al ángulo.
	var u = inst.sim.user()
	inst.sim.phase = "play"
	u.pos = Vector2(30, 19)
	inst.sim.ball_pos = u.pos
	inst.sim._give_ball(u)
	inst.cam_lock = Vector2(34, 9)
	await _frames(5)
	inst.sim.user_kick(Vector2(0.28, -1.0), 0.75, 0.0)
	for i in range(10):
		await _frames(5)
		inst.lbl_toast.modulate.a = 0.0
		_save("proto_v2_shot_%d.png" % i)
	await _frames(2)
	quit()

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _save(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://_pixellab_preview/" + n))
	print("CAPTURA OK ", n)
