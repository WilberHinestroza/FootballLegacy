extends SceneTree
## Partido 3D de SELECCIÓN — carrera real en slot_3: arma un partido de eliminatorias
## con NationalTeamMatchLauncher (el mismo del Hub), te pone de titular, monta Match3D,
## captura la salida y el juego, y comprueba que el 3D lo soporta (bandera de escudo,
## sin patrocinio). Solo toca slot_3 (respáldalo antes).
##   godot --path . -s res://tools/m3d_national_probe.gd


func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var Match3DBridge: Script = load("res://engine/match/m3d/Match3DBridge.gd")
	var NTML: Script = load("res://engine/career/NationalTeamMatchLauncher.gd")
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var wte: Node = root.get_node("WorldTickEngine")
	var ms: Node = root.get_node("MatchState")
	var pl: PlayerData = root.get_node("SaveManager").load_player()
	var rival := "Brasil" if pl.country != "Brasil" else "Argentina"
	var season_start: int = int(wte.season.get("season_start_epoch_day", 0))
	var prep: Dictionary = NTML.prepare(wte.world, wte.world_seed, season_start, pl,
		pl.country, rival, true, 1.0, "res://scenes/Hub/Hub.tscn", false, "qualifying", false, "")
	print("preparado: ", prep.get("ok", false), " · ", pl.country, " vs ", rival)
	var u: PlayerData = ms.user_player
	var mine: MatchTeam = ms.home_team
	if not mine.starting_xi.has(u):
		mine.bench.erase(u)
		for i in mine.starting_xi.size():
			if (mine.starting_xi[i] as PlayerData).position == u.position:
				mine.starting_xi[i] = u
				break
	print("soportado 3D: ", Match3DBridge.supported())
	if not Match3DBridge.supported():
		quit(1)
		return
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	root.add_child(scr)
	var cfg: Dictionary = scr._cfg
	print("%s vs %s · sponsor '%s' / '%s' · estadio %s · %s" % [cfg.home_name, cfg.away_name,
		cfg.get("home_sponsor", "?"), cfg.get("away_sponsor", "?"), cfg.stadium, cfg.competition])
	var m: Node = scr._match
	for k in 3:
		await create_timer(2.0).timeout
		root.get_texture().get_image().save_png("res://build/nat_walk_%d.png" % k)
	m._end_walkout()
	await create_timer(3.0).timeout
	root.get_texture().get_image().save_png("res://build/nat_play.png")
	quit(0)
