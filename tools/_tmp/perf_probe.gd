extends Node
## Tirones del partido 3D (con ventana): partido ambiente + una jugada, frame a
## frame. Imprime los frames > 33 ms con el estado del partido y el perfil por
## secciones de match.gd (usec acumulados / peor frame).
##   godot --path . --resolution 1024x576 res://tools/_tmp/PerfProbe.tscn [-- mobile]
var _m: SoccerMatch
var _spikes: Array = []
var _frames := 0
var _sum := 0.0
var _last := 0
var _on := false

func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	Engine.set_meta("m3d_profile", true)
	if OS.get_cmdline_user_args().has("rain"):
		Engine.set_meta("force_weather", 1)
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	_m = scr._match
	await get_tree().create_timer(1.0).timeout
	_m._end_walkout()
	if _m.state == _m.State.CUTSCENE:
		_m._end_cutscene()
	_m._moments = [{"minute": _m.minute + 4.0, "kind": _m.Moment.ATTACK}]
	SoccerMatch.prof.clear()
	_last = Time.get_ticks_usec()
	_on = true
	await get_tree().create_timer(40.0).timeout
	_on = false
	print("PERF frames=%d media=%.1f ms  picos>33ms=%d" % [_frames, _sum / maxi(_frames, 1), _spikes.size()])
	for s in _spikes.slice(0, 40):
		print("  pico %.0f ms  t=%.1fs  estado=%s" % s)
	var keys := SoccerMatch.prof.keys()
	keys.sort_custom(func(a, b): return int(SoccerMatch.prof[a][0]) > int(SoccerMatch.prof[b][0]))
	for k in keys:
		var e: Array = SoccerMatch.prof[k]
		print("  %-11s total %6.0f ms  por frame %.2f ms  peor %.1f ms" % [k, int(e[0]) / 1000.0, int(e[0]) / 1000.0 / maxi(_frames, 1), int(e[1]) / 1000.0])
	print("  draw calls=%d  objetos=%d  primitivas=%d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit(0)

var _t0 := 0.0
func _process(_d: float) -> void:
	if not _on:
		return
	var now := Time.get_ticks_usec()
	var ms := (now - _last) / 1000.0
	_last = now
	_t0 += ms / 1000.0
	_frames += 1
	_sum += ms
	if ms > 33.0:
		_spikes.append([ms, _t0, _m.State.keys()[_m.state]])
