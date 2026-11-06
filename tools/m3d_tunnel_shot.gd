extends Node
## Capturas de la salida del túnel y de la vuelta al túnel (partido 3D).
##   godot --path . res://tools/M3DTunnelShot.tscn -- <etiqueta>   (con ventana)
## Deja build/m3d_tunnel_<etiqueta>_walk_NN.png y _out_NN.png. Solo toca slot_3.
func _ready() -> void:
	var tag: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "x"
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
	FieldBuilder.time_of_day = 0
	Engine.set_meta("keep_time_of_day", true)
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	var m: SoccerMatch = scr._match
	# "-- <tag> staff": cámara fija frente al túnel y los banquillos (desfile del banquillo)
	var fixed: Camera3D = null
	if OS.get_cmdline_user_args().has("staff"):
		fixed = Camera3D.new()
		fixed.fov = 62.0
		m.add_child(fixed)
		fixed.global_position = Vector3(0.5, 6.5, -21.0)
		fixed.look_at(Vector3(0.5, 0.6, -37.0))
	var k := 0
	while m.state == m.State.WALKOUT and k < 40:
		await get_tree().create_timer(0.6).timeout
		if fixed:
			fixed.make_current()
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://build/m3d_tunnel_%s_walk_%02d.png" % [tag, k])
		k += 1
	print("TUNNEL walkout cuadros=", k, " estado=", m.state)
	# Salto al final: todos en el campo, y vuelta al túnel
	m._start_outro()
	k = 0
	while m.state == m.State.OUTRO and k < 50:
		await get_tree().create_timer(0.7).timeout
		if fixed:
			fixed.make_current()
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://build/m3d_tunnel_%s_out_%02d.png" % [tag, k])
		k += 1
	print("TUNNEL outro cuadros=", k)
	get_tree().quit(0)
