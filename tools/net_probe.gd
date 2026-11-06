extends Control
## LA RED REACCIONA AL GOL (11-oct). Captura REAL en 3 momentos del gol.
##   godot --path . --resolution 864x936 res://tools/NetProbe.tscn
func _ready() -> void:
	var ctx := {"seed": 11, "us": Color(0.2, 0.4, 0.9), "them": Color(0.85, 0.2, 0.2),
		"user": {"num": "9", "name": "WILBER"}, "mates": [{"num": "10", "name": "PEREZ"}, {"num": "7", "name": "GOMEZ"}],
		"rivals": [{"num": "4", "name": "LOPEZ"}, {"num": "5", "name": "DIAZ"}, {"num": "2", "name": "RUIZ"}],
		"our_gk": {"num": "1", "name": "ARQUERO"}, "their_gk": {"num": "1", "name": "RIVAL"}, "aim_x": 0.5 - PitchView.GOAL_W * 0.3}
	var v := PitchView.new()
	v.board_colors = [Color(0.2, 0.4, 0.9), Color(0.85, 0.2, 0.2)]
	v.size = Vector2(432, 460)
	v.clip_contents = true
	add_child(v)
	v.setup(PitchPlays.scene_for("shot_on_goal", ctx))
	await get_tree().process_frame
	await get_tree().process_frame
	v.play(PitchPlays.outcome_for("shot_on_goal", true, true, ctx))
	var imgs: Array = []
	var marks := [0.03, 0.14, 0.5]
	var k: int = 0
	var guard: int = 0
	var saw_wait: bool = false
	while k < marks.size() and guard < 1500:
		await get_tree().process_frame
		guard += 1
		saw_wait = saw_wait or v._kick_wait > 0.0
		var age: float = v._live_t - v._net_t
		if v._net_t > 0.0 and age >= float(marks[k]):
			imgs.append(get_viewport().get_texture().get_image().get_region(Rect2i(60, 0, 280, 190)))
			k += 1
	var ok: bool = imgs.size() == 3 and saw_wait
	if imgs.size() == 3:
		var out := Image.create(280 * 3, 190, false, imgs[0].get_format())
		for i in range(3):
			out.blit_rect(imgs[i], Rect2i(0, 0, 280, 190), Vector2i(280 * i, 0))
		out.resize(280 * 3 * 2, 380, Image.INTERPOLATE_NEAREST)
		out.save_png(ProjectSettings.globalize_path("res://_pixellab_preview/net.png"))
	print("la red reacciono: ", imgs.size() == 3, " · la pelota espero el golpe: ", saw_wait)
	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
