extends Control
## Captura REAL (con render) de la cancha durante los minijuegos, con la
## cámara cerca. Sin --headless:  godot --path . --resolution 576x1024 res://tools/PitchCamProbe.tscn
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var ctx := {"seed": 3, "us": Color(0.2, 0.4, 0.9), "them": Color(0.85, 0.2, 0.2),
		"user": {"num": "9", "name": "WILBER"}, "mates": [{"num": "10", "name": "PEREZ"}, {"num": "7", "name": "GOMEZ"}],
		"rivals": [{"num": "4", "name": "LOPEZ"}, {"num": "5", "name": "DIAZ"}, {"num": "2", "name": "RUIZ"}],
		"our_gk": {"num": "1", "name": "ARQUERO"}, "their_gk": {"num": "1", "name": "RIVAL"}}
	var shots := [["shot_on_goal", "shot", ["user", "gk"], [Vector2(0.5, 0)], 2.0], ["key_pass", "pass", ["user", "m1", "m2"], [], 1.7], ["dribble", "dribble", ["user", "d1"], [], 2.1]]
	var y: float = 10
	for sdef in shots:
		var v := PitchView.new()
		v.position = Vector2(16, y)
		v.size = Vector2(544, 320)
		add_child(v)
		v.setup(PitchPlays.scene_for(String(sdef[0]), ctx))
		if sdef[1] == "shot":
			v.start_shot_aim(0.5, 1.0, 0.15)
			# Arrastre a mitad de camino hacia el palo derecho, para ver la mira.
			await get_tree().process_frame
			v._aim_drag = true
			v._aim_from = Vector2(250, 250)
			v._aim_to = v._aim_from + Vector2(v.aim_span_x() * 0.8, -v._field.size.y * 0.25)
		else:
			v.start_minigame(String(sdef[1]), String(sdef[0]), 0.5, 1.0)
		v.focus_on(sdef[2], sdef[3], float(sdef[4]))
		y += 335
	for i in range(60):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/cancha_zoom.png"))
	print("CAPTURA OK")
	get_tree().quit(0)
