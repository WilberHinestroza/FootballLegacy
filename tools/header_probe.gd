extends Control
## Minijuego de cabezazo (HeaderTiming): captura antes y después del toque
## + precisión por timing.
##   godot --path . --resolution 576x1024 res://tools/HeaderProbe.tscn
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var ht := HeaderTiming.new()
	ht.duration = 1.2
	ht.player_cfg = Avatar.celebration_config_for_player(null, 7)
	ht.position = Vector2(20, 40)
	ht.size = Vector2(536, 260)
	add_child(ht)
	var got := [0.0]
	ht.tapped.connect(func(e): got[0] = e)
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/header_a.png"))
	await get_tree().create_timer(0.4).timeout
	ht._finish((ht._t - ht.duration) * 1000.0)
	await get_tree().create_timer(0.35).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/header_b.png"))
	print("err %.0f ms → precisión %.2f" % [got[0], DecisionResolver.header_timing_precision(got[0], 0.5)])
	print("perfecto %.2f · tarde 300ms %.2f · sin toque %.2f" % [DecisionResolver.header_timing_precision(0, 0.5), DecisionResolver.header_timing_precision(300, 0.5), DecisionResolver.header_timing_precision(9999, 0.5)])
	get_tree().quit(0)
