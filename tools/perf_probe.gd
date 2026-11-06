extends Control
## RENDIMIENTO de la cancha (11-oct, Wilber: "a veces va como lento, pesado
## o pegado"). Mide el costo por cuadro de PitchView en una jugada con los
## 22 en cancha. En PC; el celular es varias veces mas lento.
##   godot --path . --resolution 864x936 res://tools/PerfProbe.tscn
func _ready() -> void:
	var ctx := {"seed": 3, "us": Color(0.2, 0.4, 0.9), "them": Color(0.85, 0.2, 0.2),
		"user": {"num": "9", "name": "WILBER"}, "mates": [{"num": "10", "name": "PEREZ"}, {"num": "7", "name": "GOMEZ"}],
		"rivals": [{"num": "4", "name": "LOPEZ"}, {"num": "5", "name": "DIAZ"}, {"num": "2", "name": "RUIZ"}],
		"our_gk": {"num": "1", "name": "ARQUERO"}, "their_gk": {"num": "1", "name": "RIVAL"}}
	var v := PitchView.new()
	v.board_colors = [Color(0.2, 0.4, 0.9), Color(0.85, 0.2, 0.2)]
	v.size = Vector2(432, 700)
	v.clip_contents = true
	add_child(v)
	v.setup(PitchPlays.scene_for("through_ball", ctx))
	await get_tree().process_frame
	for i in range(30):
		await get_tree().process_frame
	# Costo de la logica (_process) medido a mano.
	var t0: int = Time.get_ticks_usec()
	for i in range(300):
		v._process(0.016)
	var proc_ms: float = (Time.get_ticks_usec() - t0) / 300.0 / 1000.0
	# Costo total por cuadro segun el motor.
	var acc: float = 0.0
	var n: int = 0
	var draws: float = 0.0
	for i in range(180):
		await get_tree().process_frame
		acc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		n += 1
	print("logica por cuadro: %.3f ms · cuadro completo: %.2f ms · llamadas de dibujo: %.0f · fps: %.0f" % [proc_ms, acc / n, draws / n, Performance.get_monitor(Performance.TIME_FPS)])
	print("PROBE OK")
	get_tree().quit(0)
