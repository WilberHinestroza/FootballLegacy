extends Control
## TRIBUNAS POR ESTADIO + PANCARTAS + CARTEL DE CAMBIO (11-oct). Captura REAL.
##   godot --path . --resolution 864x936 res://tools/StadiumKindsProbe.tscn
func _ready() -> void:
	var ctx := {"seed": 3, "us": Color(0.2, 0.4, 0.9), "them": Color(0.85, 0.2, 0.2),
		"user": {"num": "9", "name": "WILBER"}, "mates": [{"num": "10", "name": "PEREZ"}, {"num": "7", "name": "GOMEZ"}],
		"rivals": [{"num": "4", "name": "LOPEZ"}, {"num": "5", "name": "DIAZ"}, {"num": "2", "name": "RUIZ"}],
		"our_gk": {"num": "1", "name": "ARQUERO"}, "their_gk": {"num": "1", "name": "RIVAL"}}
	var views: Array = []
	for i in range(4):
		var v := PitchView.new()
		v.board_colors = [[Color(0.2, 0.4, 0.9), Color(0.85, 0.2, 0.2)], [Color(0.1, 0.55, 0.3), Color(0.95, 0.95, 0.9)], [Color(0.75, 0.15, 0.2), Color(0.1, 0.1, 0.12)], [Color(0.2, 0.4, 0.9), Color(0.85, 0.2, 0.2)]][i]
		v.position = Vector2((i % 2) * 432, (i / 2) * 468)
		v.size = Vector2(432, 460)
		v.clip_contents = true
		add_child(v)
		v.grass_for("estadio%d" % i)
		if i < 3:
			v.stand_kind = i
			v.setup(PitchPlays.scene_for("shot_on_goal", ctx))
		views.append(v)
	var sub: Dictionary = PitchPlays.sub_scene(ctx, "Luis Gomez", "Juan Perez", true, false, false)
	(views[3] as PitchView).setup(sub["scene"])
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(3):
		(views[i] as PitchView)._cam_to(1.0, Vector2(0.5, 0.0), false)
	(views[3] as PitchView).play(sub["steps"])
	await get_tree().create_timer(1.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/stadium_kinds.png"))
	var v3: PitchView = views[3]
	var ok: bool = not v3._board.is_empty() and String(v3._board.get("out", "")) == "7" and PitchView._prop("stand_roof") != null and PitchView._prop("stand_modern") != null
	print("cartel: ", v3._board)
	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
