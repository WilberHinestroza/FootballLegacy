extends Control
## VOLADA AL ANGULO (11-oct): remate alto al palo que el arquero ataja.
##   godot --path . --resolution 864x936 res://tools/HighSaveProbe.tscn
func _ready() -> void:
	var v := PitchView.new()
	v.board_colors = [Color(0.2, 0.4, 0.9), Color(0.85, 0.2, 0.2)]
	v.size = Vector2(432, 460)
	v.clip_contents = true
	add_child(v)
	var steps: Array = []
	var ctx := {}
	for sd in range(80):
		ctx = {"seed": sd, "us": Color(0.2, 0.4, 0.9), "them": Color(0.85, 0.2, 0.2),
			"user": {"num": "9", "name": "WILBER"}, "mates": [{"num": "10", "name": "PEREZ"}, {"num": "7", "name": "GOMEZ"}],
			"rivals": [{"num": "4", "name": "LOPEZ"}, {"num": "5", "name": "DIAZ"}, {"num": "2", "name": "RUIZ"}],
			"our_gk": {"num": "1", "name": "ARQUERO"}, "their_gk": {"num": "1", "name": "RIVAL"},
			"aim_x": 0.5 + PitchView.GOAL_W * 0.34, "shot_level": "high", "strike": "comba"}
		steps = PitchPlays.outcome_for("shot_on_goal", false, false, ctx)
		var saved: bool = false
		for s in steps:
			if String((s as Dictionary).get("flash", "")).contains("ATAJADA"):
				saved = true
		if saved:
			break
	v.setup(PitchPlays.scene_for("shot_on_goal", ctx))
	await get_tree().process_frame
	await get_tree().process_frame
	v.play(steps)
	var imgs: Array = []
	var seen: bool = false
	var t_seen: int = 0
	var marks := [120, 280, 430]
	var k: int = 0
	var guard: int = 0
	while k < marks.size() and guard < 1500:
		await get_tree().process_frame
		guard += 1
		if not seen and v.has_actor("gk") and String(v._actors["gk"]["anim"]) == "volada":
			seen = true
			t_seen = Time.get_ticks_msec()
		if seen and Time.get_ticks_msec() - t_seen >= int(marks[k]):
			imgs.append(get_viewport().get_texture().get_image().get_region(Rect2i(40, 0, 320, 200)))
			k += 1
	if imgs.size() == 3:
		var out := Image.create(320 * 3, 200, false, imgs[0].get_format())
		for i in range(3):
			out.blit_rect(imgs[i], Rect2i(0, 0, 320, 200), Vector2i(320 * i, 0))
		out.resize(320 * 3 * 2, 400, Image.INTERPOLATE_NEAREST)
		out.save_png(ProjectSettings.globalize_path("res://_pixellab_preview/high_save.png"))
	print("el arquero volo al angulo: ", seen)
	print("PROBE ", "OK" if seen and imgs.size() == 3 else "FAIL")
	get_tree().quit(0 if seen else 1)
