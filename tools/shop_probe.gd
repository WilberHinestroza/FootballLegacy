extends Node
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/Shop/Shop.tscn")
	await get_tree().create_timer(1.2).timeout
	var shop: Node = get_tree().current_scene
	shop._try_on = "top_" + String(Avatar.TOPS[2]["src"])
	shop._render()
	await get_tree().create_timer(0.8).timeout
	await _shot("Shop_probador")
	shop._try_on = ""
	shop._section = "consumibles"
	shop._render()
	await get_tree().create_timer(0.8).timeout
	await _shot("Shop_consumibles")
	get_tree().quit()
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/%s.png" % n))
	print("CAPTURA ", n)
