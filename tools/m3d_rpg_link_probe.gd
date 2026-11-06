extends Node
## Enlace partido 3D <-> carrera: amarillas acumuladas, energía y jugadas como "toques".
##   godot --headless --path . res://tools/M3DRpgLinkProbe.tscn
const M3D = preload("res://engine/match/m3d/Match3DBridge.gd")
var _fails := 0

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		_fails += 1

func _ready() -> void:
	var season := {}
	_check(not DisciplineEngine.add_user_yellows(season, 0), "0 amarillas no cambia nada")
	for i in 4:
		DisciplineEngine.add_user_yellows(season, 1)
	_check(int(season.get("suspended_matches", 0)) == 0, "4 amarillas: sin sanción")
	_check(DisciplineEngine.add_user_yellows(season, 1), "la 5ª amarilla sanciona")
	_check(int(season.suspended_matches) == 1, "1 partido de sanción")
	_check(not DisciplineEngine.add_user_yellows(season, 1), "la 6ª no vuelve a sancionar")
	var st := {"speed": 80, "stamina": 80, "strength": 80, "passing": 80}
	var full: Dictionary = DecisionResolver.m3d_energy_stats(st, 100.0)
	_check(full.stats == st and full.note == "", "con energía llena, stats intactas")
	var low: Dictionary = DecisionResolver.m3d_energy_stats(st, 20.0)
	_check(int(low.stats.speed) < 80 and int(low.stats.passing) < 80 and int(low.stats.speed) < int(low.stats.passing), "fundido: lo físico baja más que lo técnico (%s)" % str(low.stats))
	_check(String(low.note) != "", "aviso de cansancio: " + String(low.note))
	MatchState.gesture_stats = {"perfecto": 0, "bueno": 0, "regular": 0, "flojo": 0, "streak": 0, "best_streak": 0}
	M3D._fill_gesture_stats([{"ok": true, "grade": "perfecto"}, {"ok": true, "grade": "bueno"}, {"ok": false, "grade": "regular"}, {"ok": true}])
	var gs: Dictionary = MatchState.gesture_stats
	_check(int(gs.perfecto) == 1 and int(gs.bueno) == 2 and int(gs.regular) == 1, "jugadas -> toques %s" % str(gs))
	_check(int(gs.best_streak) == 2, "racha de jugadas buenas")
	_check(ProgressionEngine.gesture_xp(gs) > 0, "las jugadas dan XP de carrera (%d)" % ProgressionEngine.gesture_xp(gs))
	print("PROBE %s (%d fallos)" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
