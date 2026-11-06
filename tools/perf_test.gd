extends Node
## PRUEBA DE RENDIMIENTO en el celular (no toca ninguna partida guardada):
## juega jugadas en vivo con equipos de prueba ~40 s y escribe en el log
## (adb logcat) los cuadros por segundo. Se activa creando el archivo
## user://perftest (un solo uso) y abriendo el juego.
var m: Match
var samples: Array = []

func _ready() -> void:
	var hz: float = DisplayServer.screen_get_refresh_rate()
	if hz > 0.0:
		Engine.physics_ticks_per_second = clampi(int(round(hz)), 60, 120)
	print("PERF pantalla=%.0f Hz fisica=%d" % [hz, Engine.physics_ticks_per_second])
	m = Match.new()
	add_child(m)
	m.setup({"home_form": "4-3-3", "away_form": "4-4-2", "user_slot": 9})
	m.hud.channel = "deporte_total"
	m.auto_resume = 0.4
	await get_tree().create_timer(1.0).timeout
	var kinds := ["counter_run", "shot_on_goal", "cross", "tackle", "dribble", "one_on_one_save"]
	var t0: int = Time.get_ticks_msec()
	var i: int = 0
	while Time.get_ticks_msec() - t0 < 40000:
		if m.state != "moment":
			m.start_moment({"kind": kinds[i % kinds.size()], "minute": 30 + i, "narration": "Prueba de rendimiento"})
			i += 1
		await get_tree().create_timer(1.0).timeout
		var fps: float = Engine.get_frames_per_second()
		samples.append(fps)
		print("PERF fps=%d proceso=%.1fms fisica=%.1fms objetos=%d dibujos=%d" % [fps,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	samples.sort()
	var avg: float = 0.0
	for s in samples:
		avg += s
	avg /= maxf(samples.size(), 1)
	print("PERF RESUMEN promedio=%.1f minimo=%d mediana=%d jugadas=%d" % [avg, samples[0], samples[samples.size() / 2], i])
	get_tree().quit()
