extends Control
## Lesion con camilla (11-oct). Captura REAL en 3 momentos.
##   godot --path . --resolution 864x936 res://tools/InjuryProbe.tscn
func _ready() -> void:
	var ctx := {"seed": 3, "us": Color(0.2, 0.4, 0.9), "them": Color(0.85, 0.2, 0.2),
		"user": {"num": "9", "name": "WILBER"}, "mates": [{"num": "10", "name": "PEREZ"}, {"num": "7", "name": "GOMEZ"}],
		"rivals": [{"num": "4", "name": "LOPEZ"}, {"num": "5", "name": "DIAZ"}, {"num": "2", "name": "RUIZ"}],
		"our_gk": {"num": "1", "name": "ARQUERO"}, "their_gk": {"num": "1", "name": "RIVAL"}}
	var v := PitchView.new()
	v.board_colors = [Color(0.2, 0.4, 0.9), Color(0.85, 0.2, 0.2)]
	v.size = Vector2(432, 460)
	v.clip_contents = true
	add_child(v)
	var play: Dictionary = PitchPlays.injury_scene(ctx, "Luis Gomez", false, true)
	v.setup(play["scene"])
	await get_tree().process_frame
	await get_tree().process_frame
	v.play(play["steps"])
	var shots := [1.9, 3.0, 4.2]
	var imgs: Array = []
	var seen_on: bool = false
	var t0: int = Time.get_ticks_msec()
	var k: int = 0
	while k < shots.size():
		await get_tree().process_frame
		seen_on = seen_on or v._str_on
		if (Time.get_ticks_msec() - t0) / 1000.0 >= float(shots[k]):
			imgs.append(get_viewport().get_texture().get_image().get_region(Rect2i(0, 0, 395, 421)))
			k += 1
	var out := Image.create(395 * 3, 421, false, imgs[0].get_format())
	for i in range(3):
		out.blit_rect(imgs[i], Rect2i(0, 0, 395, 421), Vector2i(395 * i, 0))
	out.save_png(ProjectSettings.globalize_path("res://_pixellab_preview/injury.png"))
	var ok: bool = seen_on and PitchView._prop_frames("medics").size() >= 8
	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
