extends Control
## Objetos del estadio (11-oct): marcador, tunel, camilleros. Captura REAL.
##   godot --path . --resolution 864x936 res://tools/StadiumPropsProbe.tscn
func _ready() -> void:
	var ctx := {"seed": 3, "us": Color(0.2, 0.4, 0.9), "them": Color(0.85, 0.2, 0.2),
		"user": {"num": "9", "name": "WILBER"}, "mates": [{"num": "10", "name": "PEREZ"}, {"num": "7", "name": "GOMEZ"}],
		"rivals": [{"num": "4", "name": "LOPEZ"}, {"num": "5", "name": "DIAZ"}, {"num": "2", "name": "RUIZ"}],
		"our_gk": {"num": "1", "name": "ARQUERO"}, "their_gk": {"num": "1", "name": "RIVAL"}}
	var foci := [Vector2(0.80, 0.25), Vector2(0.10, 1.05), Vector2(0.90, 1.30), Vector2(0.5, 0.3)]
	var views: Array = []
	for i in range(4):
		var v := PitchView.new()
		v.board_colors = [Color(0.2, 0.4, 0.9), Color(0.85, 0.2, 0.2)]
		v.score_text = "2 - 1"
		v.position = Vector2((i % 2) * 432, (i / 2) * 468)
		v.size = Vector2(432, 460)
		v.clip_contents = true
		add_child(v)
		v.setup(PitchPlays.scene_for("shot_on_goal", ctx))
		views.append(v)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(4):
		(views[i] as PitchView)._cam_to(1.0, foci[i], false)
	(views[3] as PitchView).crowd_hype(5.0)
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/stadium_props.png"))
	var ok: bool = PitchView._prop_frames("cameraman").size() == 9 and PitchView._prop_frames("ultras").size() == 9 and PitchView._prop("scoreboard") != null
	print("medics tex: ", PitchView._prop("medics"), " px: ", (views[2] as PitchView)._pw(Vector2(1.10, 1.32)) * 1.0 + (views[2] as PitchView)._cam_offset(), " focus ", (views[2] as PitchView).cam_focus)
	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
