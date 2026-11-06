extends Node
## Capturas de las ceremonias del partido 3D (con ventana):
##   godot --path . res://tools/M3DCeremonyShot.tscn -- <etiqueta> trophy|mvp
## Deja build/m3d_cer_<etiqueta>_NN.png. Solo toca slot_3 (carrera de prueba).
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var tag: String = args[0] if args.size() > 0 else "x"
	var kind: String = args[1] if args.size() > 1 else "trophy"
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	FieldBuilder.time_of_day = 0
	Engine.set_meta("keep_time_of_day", true)
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	var m: SoccerMatch = scr._match
	await get_tree().create_timer(0.8).timeout
	m._end_walkout()
	await get_tree().create_timer(1.0).timeout
	var shots := 0
	if kind == "trophy":
		SoccerMatch.config["final_trophy"] = "Copa de Campeones"
		m.score = [2, 1]
		m._finish_match()
		var t := 0.0
		while t < TrophyCeremony.DURATION + 1.5:
			await get_tree().create_timer(0.5).timeout
			t += 0.5
			get_viewport().get_texture().get_image().save_png("res://build/m3d_cer_%s_%02d.png" % [tag, shots])
			shots += 1
	else:
		m.state = SoccerMatch.State.MVP_CEREMONY
		for p: SoccerPlayer in m.players:
			p.visible = false
		var c: Node3D = load("res://match3d/scripts/mvp_ceremony.gd").new()
		m.add_child(c)
		var done := [false]
		c.connect("finished", func() -> void: done[0] = true)
		c.call("start", m, m.star, "Tu Jugador", FieldBuilder.home_color)
		var t2 := 0.0
		while not done[0] and t2 < 14.0:
			await get_tree().create_timer(0.4).timeout
			t2 += 0.4
			get_viewport().get_texture().get_image().save_png("res://build/m3d_cer_%s_%02d.png" % [tag, shots])
			shots += 1
	print("CEREMONY ", kind, " cuadros=", shots)
	get_tree().quit(0)
