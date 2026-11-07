extends Node
## Medición de FPS EN EL CELULAR (7-nov). Se lanza solo por adb, nunca desde el juego:
##   adb shell "run-as com.wilber.footballlegacy.h touch files/perftest"  (y abrir el juego)
## Usa un slot temporal ("slot_perf", la misma carrera de prueba que en el PC), juega
## 45 s de partido ambiente + una jugada, escribe en el log "PERF ..." y borra el slot.
## La carrera del jugador (slot_1…3) no se toca.
const SLOT := "slot_perf"
const SECONDS := 45.0
var _m: SoccerMatch
var _ms: Array[float] = []
var _states := {}
var _last := 0
var _on := false
var _t := 0.0
var _spikes: Array = []
var _prev_state := ""
var _trail: Array = []
var _buckets: Array = []
var _bucket_t0 := 0.0
var _bucket_ms := 0.0
var _bucket_n := 0 # últimos cambios de estado (para saber qué pasaba en el tirón)


func _ready() -> void:
	SaveManager.active_slot_id = SLOT
	SaveManager.save_slot(SLOT, {})
	SaveManager.save_world_seed(4242)
	var world := WorldFactory.build(4242)
	var p := PlayerData.new()
	p.player_name = "Prueba Rendimiento"
	p.country = "Argentina"
	p.position = "MF"
	p.detailed_position = "MC"
	p.age = 20
	p.overall = 64
	p.potential = 82
	for s in ["speed", "stamina", "strength", "control", "passing", "shooting", "dribbling", "decision_making", "composure"]:
		p.set(s, 62)
	var lg0: LeagueData = world["leagues"][0]
	var club: ClubData = world["clubs_by_league"][lg0.league_id][3]
	p.club_id = club.club_id
	p.contract_years_remaining = 3
	SaveManager.save_player(p)
	SaveManager.save_season(SeasonCalendar.build_season(world, int(lg0.league_id), 0, CalendarUtils.season_start_year(0), p.club_id, 4242))
	WorldTickEngine.load_runtime()
	WorldTickEngine.advance_until(WorldTickEngine.current_epoch_day + 20)
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	Engine.set_meta("m3d_profile", true)
	if OS.get_cmdline_user_args().has("rain") or OS.get_cmdline_args().has("rain"):
		Engine.set_meta("force_weather", 1)
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	_m = scr._match
	await get_tree().create_timer(2.0).timeout
	_m._end_walkout()
	if _m.state == _m.State.CUTSCENE:
		_m._end_cutscene()
	_m._moments = [{"minute": _m.minute + 5.0, "kind": _m.Moment.ATTACK}]
	SoccerMatch.prof.clear()
	_last = Time.get_ticks_usec()
	_on = true
	var secs: float = float(Engine.get_meta("perf_seconds", SECONDS))
	if secs > 60.0:
		_m._moments = [] # prueba larga (calor): partido ambiente seguido
		for k in range(1, int(secs / 25.0)):
			_m._moments.append({"minute": minf(_m.minute + 4.0 * k, 38.0), "kind": _m.Moment.ATTACK})
	await get_tree().create_timer(secs).timeout
	_on = false
	_report()
	SaveManager.delete_slot(SLOT)
	get_tree().quit(0)


## Pase lo que pase, el slot de prueba no se queda en el celular.
func _exit_tree() -> void:
	SaveManager.delete_slot(SLOT)


func _process(_d: float) -> void:
	if not _on:
		return
	# El partido no termina nunca durante la medición (ni descanso ni final: antes la
	# prueba larga acababa el partido, volvía al Hub y no informaba).
	if _m.minute > 40.0:
		_m.minute = 8.0
		_m._moments = [{"minute": 14.0, "kind": _m.Moment.ATTACK}, {"minute": 24.0, "kind": _m.Moment.ATTACK},
			{"minute": 34.0, "kind": _m.Moment.ATTACK}]
	var now := Time.get_ticks_usec()
	var ms := (now - _last) / 1000.0
	_last = now
	_ms.append(ms)
	_t += ms / 1000.0
	var st: String = _m.State.keys()[_m.state]
	if st != _prev_state:
		_trail.append("%.1fs→%s" % [_t, st])
		_prev_state = st
	_bucket_ms += ms
	_bucket_n += 1
	if _t - _bucket_t0 >= 30.0:
		_buckets.append("%.0fs:%.0ffps" % [_t, 1000.0 / maxf(_bucket_ms / maxi(_bucket_n, 1), 0.01)])
		_bucket_t0 = _t
		_bucket_ms = 0.0
		_bucket_n = 0
	if ms > 50.0:
		var worst := ""
		var wv := 0
		for k in SoccerMatch.prof_last:
			if int(SoccerMatch.prof_last[k]) > wv:
				wv = int(SoccerMatch.prof_last[k])
				worst = k
		_spikes.append("%.0f ms a los %.1fs estado=%s  process=%.1f física=%.1f  peor sección=%s %.1f ms  antes: %s" % [ms, _t, st,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			worst, wv / 1000.0, ", ".join(_trail.slice(-2))])
	var e: Array = _states.get(st, [0, 0.0])
	_states[st] = [int(e[0]) + 1, float(e[1]) + ms]


func _report() -> void:
	var sorted := _ms.duplicate()
	sorted.sort()
	var n := sorted.size()
	var avg := 0.0
	for v in sorted:
		avg += v
	avg /= maxi(n, 1)
	var p95: float = sorted[int(n * 0.95)] if n > 0 else 0.0
	var spikes := sorted.filter(func(v: float) -> bool: return v > 50.0).size()
	print("PERF frames=%d fps_medio=%.1f ms_medio=%.1f p95=%.1f peor=%.1f tirones>50ms=%d escala3d=%.2f" % [
		n, 1000.0 / maxf(avg, 0.01), avg, p95, sorted[n - 1] if n > 0 else 0.0, spikes, get_viewport().scaling_3d_scale])
	print("PERF por tramo ", " ".join(_buckets))
	for sp in _spikes:
		print("PERF tirón ", sp)
	for st in _states:
		print("PERF estado %s frames=%d ms_medio=%.1f" % [st, _states[st][0], float(_states[st][1]) / maxi(int(_states[st][0]), 1)])
	for k in SoccerMatch.prof:
		var e: Array = SoccerMatch.prof[k]
		print("PERF script %s por_frame=%.2f ms peor=%.1f ms" % [k, int(e[0]) / 1000.0 / maxi(n, 1), int(e[1]) / 1000.0])
	print("PERF render draw_calls=%d objetos=%d primitivas=%d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
