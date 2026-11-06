extends Control
## Pasos laterales del arquero (11-oct): mientras apuntas el remate el
## arquero se mueve de lado a lado y tiene que usar "paso_der"/"paso_izq".
##   godot --path . --resolution 864x936 res://tools/KeeperStepsProbe.tscn
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
	v.setup(PitchPlays.scene_for("shot_on_goal", ctx))
	await get_tree().process_frame
	await get_tree().process_frame
	v.start_shot_aim(0.4, 1.0, 0.15)
	var seen := {}
	var t0: int = Time.get_ticks_msec()
	var shot: bool = false
	while Time.get_ticks_msec() - t0 < 3500:
		await get_tree().process_frame
		var an: String = String(v._actors["gk"]["anim"])
		seen[an] = int(seen.get(an, 0)) + 1
		if not shot and an.begins_with("paso_") and Time.get_ticks_msec() - t0 > 800:
			shot = true
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/keeper_steps.png"))
	print("animaciones del arquero (cuadros): ", seen)
	var ok: bool = seen.has("paso_der") and seen.has("paso_izq")
	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
