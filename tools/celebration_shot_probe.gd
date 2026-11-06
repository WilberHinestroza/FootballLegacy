extends Control
## Captura REAL del festejo de gol (mismo armado que Match: césped
## compartido + GoalCelebration) en 3 animaciones distintas.
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	size = Vector2(576, 1024)
	var p := PlayerData.new()
	p.player_name = "Probe Gol"
	var cfg: Dictionary = Avatar.celebration_config_for_player(p, 7)
	cfg["tint_clothing"] = "#1b7a3a"
	cfg["kit_w"] = 3
	cfg["tint_kit2"] = "#ffffff"
	GoalCelebration.build_grass(self, size, size.y * 0.62 + GoalCelebration.FEET_Y)
	var celeb := GoalCelebration.new()
	celeb.position = Vector2(size.x * 0.5, size.y * 0.62)
	add_child(celeb)
	# 10-oct: con compañeros que se suman al festejo.
	celeb.mates = [Avatar.teammate_config(cfg, "mate|a", 7), Avatar.teammate_config(cfg, "mate|b", 7)]
	celeb.play(cfg, "Corre hacia la bandera de córner", Color("#1b7a3a"), 5)
	for i in range(70):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/celebration.png"))
	print("CAPTURA OK")
	get_tree().quit(0)
