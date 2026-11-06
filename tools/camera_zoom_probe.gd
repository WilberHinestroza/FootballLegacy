extends Control
## Zoom de cámara: al elegir la acción y al sacar tarjeta el árbitro.
##   godot --path . --resolution 576x1024 res://tools/CameraZoomProbe.tscn
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var ctx := {"seed": 3, "us": Color(0.2, 0.4, 0.9), "them": Color(0.85, 0.2, 0.2),
		"user": {"num": "9", "name": "WILBER", "look": {"tint_base": "#8a5a3b", "tint_hair": "#2b2320"}},
		"mates": [{"num": "10", "name": "PEREZ"}, {"num": "7", "name": "GOMEZ"}],
		"rivals": [{"num": "4", "name": "LOPEZ"}, {"num": "5", "name": "DIAZ"}, {"num": "2", "name": "RUIZ"}],
		"our_gk": {"num": "1", "name": "ARQUERO"}, "their_gk": {"num": "1", "name": "RIVAL"}}
	var a := PitchView.new()
	a.position = Vector2(16, 8)
	a.size = Vector2(544, 480)
	add_child(a)
	var b := PitchView.new()
	b.position = Vector2(16, 520)
	b.size = Vector2(544, 480)
	add_child(b)
	await get_tree().process_frame
	a.setup(PitchPlays.scene_for("shot_on_goal", ctx))
	a.set_interactive(true, ["goal", "m1", "d1"])
	a.focus_on(["user", "m1", "d1"], [Vector2(0.5, 0.04)], 2.3)
	var card: Dictionary = PitchPlays.card_scene(ctx, "Juan Lopez", false, false, false)
	b.setup(card["scene"])
	b.play(card["steps"])
	await get_tree().create_timer(1.6).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/camera_zoom.png"))
	# Gol en cámara lenta.
	a.setup(PitchPlays.scene_for("shot_on_goal", ctx))
	var steps: Array = PitchPlays.outcome_for("shot_on_goal", true, true, ctx)
	for i in range(steps.size() - 1, -1, -1):
		if (steps[i] as Dictionary).has("ball"):
			steps[i] = (steps[i] as Dictionary).duplicate()
			steps[i]["slow"] = 2.6
			break
	a.play(steps)
	await get_tree().create_timer(0.9).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/camera_slowmo.png"))
	# Penal atajado por el usuario arquero.
	ctx["aim_zone"] = 3
	ctx["user"] = {"num": "1", "name": "WILBER"}
	b.setup(PitchPlays.scene_for("penalty_save", ctx))
	b.reset_camera(false)
	b.play(PitchPlays.outcome_for("penalty_save", true, false, ctx))
	await get_tree().create_timer(1.3).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/camera_save.png"))
	var sv := 0
	var kp := PlayerData.new()
	kp.composure = 70
	kp.decision_making = 70
	for i in range(1000):
		if DecisionResolver.resolve_penalty_save(kp, 70, DecisionResolver.penalty_save_multiplier(4, 0.95)):
			sv += 1
	print("atajadas con buen reflejo al medio: %d/1000" % sv)
	print("CAPTURA OK")
	get_tree().quit(0)
