extends Node
## Línea defensiva coordinada: muestrea la dispersión en x de los defensas que
## guardan posición y cuánto se mueve la línea (sube/recula) en juego ambiente.
func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	var m: SoccerMatch = scr._match
	await get_tree().create_timer(1.0).timeout
	m._end_walkout()
	if m.state == m.State.CUTSCENE:
		m._end_cutscene()
	m._moments.clear()
	var ups := 0
	var downs := 0
	var spread_sum := 0.0
	var n := 0
	var ahead := 0
	for k in 120:
		await get_tree().create_timer(0.25).timeout
		for t in 2:
			var ls: float = m._line_shift[t]
			if ls > 1.5: ups += 1
			if ls < -1.5: downs += 1
			var h: SoccerPlayer = m.ball.owner_player
			if h == null or h.team == t:
				continue
			var xs: Array = []
			for d: SoccerPlayer in m.teams[t]:
				if d.role == "DF":
					xs.append(d.global_position.x * m.attack_dir(t))
					if d.global_position.x * m.attack_dir(t) > m.ball.global_position.x * m.attack_dir(t) + 1.0 \
							and SoccerMatch.flat_dist(d.global_position, m.ball.global_position) > 8.0:
						ahead += 1
			xs.sort()
			spread_sum += float(xs[-2]) - float(xs[1]) if xs.size() >= 4 else 0.0
			n += 1
	print("LINE sube=%d recula=%d dispersion_media=%.1f m defensas_por_delante_del_balon=%d muestras=%d" % [ups, downs, spread_sum / maxi(n, 1), ahead, n])
	print("LINE PROBE %s" % ("OK" if ups > 0 and downs > 0 else "FAIL"))
	get_tree().quit(0)
