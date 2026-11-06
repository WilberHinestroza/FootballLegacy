extends Node
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/Training/Training.tscn")
	await get_tree().create_timer(1.2).timeout
	SkillsPanel.open(get_tree().current_scene)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/Skills.png"))
	print("CAPTURA habilidades")
	get_tree().quit()
