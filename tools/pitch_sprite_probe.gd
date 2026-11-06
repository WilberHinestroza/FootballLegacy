extends Control
## Captura REAL de los jugadores en pixel art sobre la cancha 2D (quietos,
## en carrera, rematando / arquero estirándose). Sin --headless:
##   godot --path . --resolution 576x1024 res://tools/PitchSpriteProbe.tscn
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
	var views: Array = []
	var y: float = 8
	for i in range(3):
		var v := PitchView.new()
		v.night = i == 2   # la tercera, de noche (reflectores)
		v.weather = ["rain", "snow", ""][i]
		v.grass_pattern = ["checker", "diagonal", "circles"][i]
		v.grass_a = PitchView.GRASS_TONES[i + 1][0]
		v.grass_b = PitchView.GRASS_TONES[i + 1][1]
		v.position = Vector2(16, y)
		v.size = Vector2(544, 330)
		add_child(v)
		views.append(v)
		y += 338
	var t0: int = Time.get_ticks_msec()
	views[0].setup(PitchPlays.scene_for("key_pass", ctx))
	views[1].setup(PitchPlays.scene_for("shot_on_goal", ctx))
	views[2].setup(PitchPlays.scene_for("dribble", ctx))
	await get_tree().process_frame
	print("armado + primer cuadro: %d ms" % (Time.get_ticks_msec() - t0))
	var c2 := ctx.duplicate()
	c2["aim_x"] = 0.46
	var t1: int = Time.get_ticks_msec()
	views[1].play(PitchPlays.outcome_for("shot_on_goal", true, true, c2))
	views[2].play(PitchPlays.outcome_for("dribble", false, false, ctx))
	views[0].play(PitchPlays.outcome_for("key_pass", true, false, ctx))
	await get_tree().process_frame
	print("arranque de jugadas: %d ms" % (Time.get_ticks_msec() - t1))
	var shots := [0.25, 0.55, 0.85]
	var last: float = 0.0
	for k in range(shots.size()):
		await get_tree().create_timer(shots[k] - last).timeout
		last = shots[k]
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://_pixellab_preview/pitch_sprites_%d.png" % k))
	print("CAPTURA OK")
	get_tree().quit(0)
