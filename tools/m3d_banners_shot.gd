extends Node
## Capturas de las pancartas 3D (6-nov) durante la salida de los equipos.
## Clásico + afición alta = pancartas con tu nombre. Solo toca slot_3.
##   godot --path . res://tools/M3DBannersShot.tscn   (con ventana)
const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")

func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	fx["derby"] = true
	WorldTickEngine.season["fan_sentiment"] = 85
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
	print("BANNERS crowd=", FieldBuilder.crowd, " stars=", FieldBuilder.stars)
	var n: Node = (scr._match as Node).get_node_or_null("Banners")
	print("BANNERS telas=", n.get_child_count() if n else -1)
	await get_tree().create_timer(1.0).timeout
	var W: float = SoccerMatch.FIELD_WIDTH
	var cam := Camera3D.new()
	scr._match.add_child(cam)
	var views := [[Vector3(0.0, 5.0, 2.0), Vector3(0.0, 1.0, -W * 0.5 - 6.0)],
		[Vector3(8.0, 3.0, -W * 0.5 + 1.0), Vector3(0.0, 1.0, -W * 0.5 - 6.0)],
		[Vector3(0.0, 5.0, -2.0), Vector3(0.0, 1.0, W * 0.5 + 6.0)]]
	for k in views.size():
		cam.position = views[k][0]
		cam.look_at(views[k][1])
		cam.make_current()
		for on in [true, false]:
			if n:
				(n as Node3D).visible = on
			await get_tree().create_timer(0.4).timeout
			get_viewport().get_texture().get_image().save_png("res://build/m3d_banners_v%d_%s.png" % [k, "on" if on else "off"])
	print("BANNERS listo")
	get_tree().quit(0)
