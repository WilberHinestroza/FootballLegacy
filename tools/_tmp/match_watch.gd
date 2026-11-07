extends Node
## Revisión visual del partido 3D (con ventana, 1024x576): juego ambiente (toda la IA)
## y una jugada tuya sin tocar nada; guarda fotos en build/watch_XX.png.
##   godot --path . --resolution 1024x576 res://tools/_tmp/MatchWatch.tscn
func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	var mine: MatchTeam = MatchState.home_team if String(fx.get("home_club_id", "")) == pl.club_id else MatchState.away_team
	var u: PlayerData = MatchState.user_player
	if not mine.starting_xi.has(u):
		mine.bench.erase(u)
		for i in mine.starting_xi.size():
			if (mine.starting_xi[i] as PlayerData).position == u.position:
				mine.starting_xi[i] = u
				break
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	var m: SoccerMatch = scr._match
	await get_tree().create_timer(1.0).timeout
	_shot(0)
	m._end_walkout()
	if m.state == m.State.CUTSCENE:
		m._end_cutscene()
	m._moments = [{"minute": m.minute + 6.0, "kind": m.Moment.ATTACK}]
	var k := 1
	var t0 := Time.get_ticks_msec()
	var started := false
	m.moment_started.connect(func(_t): started = true)
	while k < 40 and (Time.get_ticks_msec() - t0) < 60000:
		await get_tree().create_timer(0.6).timeout
		_shot(k)
		print("shot %02d estado %s min %.1f balón %s" % [k, m.State.keys()[m.state], m.minute,
			m.ball.owner_player.name if m.ball.owner_player != null else "-"])
		k += 1
	get_tree().quit(0)

func _shot(k: int) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/watch_%02d.png" % k))
