extends Node
## Práctica: arma cada modo con la carrera de prueba (slot_3, ui_gallery_probe),
## comprueba las jugadas planeadas y juega una sesión de faceta hasta el final
## (sin tocar nada) para ver que vuelve con el resultado y los retos.
const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")
var fails := 0

func _check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FALLA: ", msg)

func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	print("jugador %s %s club %s" % [pl.player_name, pl.position, pl.club_id])
	for mode in [["free", ""], ["facet", "remate"], ["facet", "balon_parado"], ["facet", "defensa"], ["scrim", ""]]:
		var cfg := Match3DBridge.practice_config(mode[0], mode[1], func(_r): pass)
		_check(not cfg.is_empty(), "sin config para " + str(mode))
		var names: Array = []
		for x in cfg.home_players: names.append(x.name)
		for x in cfg.away_players:
			_check(not names.has(x.name), "%s juega en los dos equipos" % x.name)
		_check(cfg.home_players.size() == 10 and cfg.away_players.size() == 11, "planteles %d/%d" % [cfg.home_players.size(), cfg.away_players.size()])
		print("%s/%s: familias %s · peto %s · lanzador penaltis %s" % [mode[0], mode[1], cfg.practice_families, cfg.away_shirt, cfg.home_set_pieces.get("penalty")])
	# Retos de la semana
	var st := PracticeEngine.state(WorldTickEngine.season, WorldTickEngine.current_epoch_day, SaveManager.load_world_seed(), pl.position == "GK")
	for c in st.list: print("  reto: %s (+%d XP)" % [c.desc, c.xp])
	# Tope de 2 cobros por semana: una sesión que lo cumple todo
	var fake := {"mode": "facet", "facet": "remate", "goals": 9, "assists": 9, "saves": 9, "ok": 9, "fail": 0, "moments": 9, "us": 3, "them": 0}
	var season_copy: Dictionary = WorldTickEngine.season.duplicate(true)
	var p2: PlayerData = pl.duplicate()
	var r1 := PracticeEngine.apply_session(season_copy, p2, WorldTickEngine.current_epoch_day, SaveManager.load_world_seed(), fake)
	fake.mode = "scrim"; fake.facet = ""
	var r2 := PracticeEngine.apply_session(season_copy, p2, WorldTickEngine.current_epoch_day, SaveManager.load_world_seed(), fake)
	print("cobros: sesión1 %s · sesión2 %s · bloqueados %s" % [r1.completed, r2.completed, r2.locked])
	_check(r1.completed.size() + r2.completed.size() <= 2, "se cobraron más de 2 retos en la semana")
	# Sesión de faceta jugada hasta el final
	MatchState.practice = {"mode": "facet", "facet": "remate"}
	MatchState.practice_result = {}
	var scr: Node = load("res://scenes/Practice/PracticeMatch.tscn").instantiate()
	add_child(scr)
	var m: SoccerMatch = scr._match
	var fams := {}
	for e in m._moments: fams[e.play.family] = true
	print("jugadas planeadas %d: %s · público %.2f" % [m._moments.size(), fams.keys(), FieldBuilder.crowd_fill])
	_check(m._moments.size() == PracticeEngine.SESSION_MOMENTS, "número de jugadas")
	for f in fams: _check(PracticeEngine.families("remate").has(f), "familia fuera de la faceta: %s" % f)
	Engine.time_scale = 6.0
	var t0 := Time.get_ticks_msec()
	while MatchState.practice_result.is_empty() and Time.get_ticks_msec() - t0 < 150000:
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(m) and m.state == m.State.OUTRO and not scr._done:
			scr._on_outro_finished()
	Engine.time_scale = 1.0
	var res: Dictionary = MatchState.practice_result
	_check(not res.is_empty(), "la sesión no terminó")
	print("resultado: ", res.get("summary"), " · retos ", res.get("rewards"))
	print("PROBE OK" if fails == 0 else "PROBE FAIL %d" % fails)
	(Engine.get_main_loop() as SceneTree).quit()
