extends Node
## Captura las pestañas internas del Perfil y de otras pantallas.
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/PlayerProfile/PlayerProfile.tscn")
	await get_tree().create_timer(1.2).timeout
	var pp: Node = get_tree().current_scene
	for k in ["attrs", "traits", "showcase", "relations", "rpg"]:
		pp._on_tab_pressed(k)
		await get_tree().create_timer(0.6).timeout
		await _shot("Perfil_" + k)
	get_tree().change_scene_to_file("res://scenes/Shop/Shop.tscn")
	await get_tree().create_timer(1.2).timeout
	var shop: Node = get_tree().current_scene
	shop._section = "consumibles"
	shop._render()
	await get_tree().create_timer(0.6).timeout
	await _shot("Tienda_consumibles")
	get_tree().change_scene_to_file("res://scenes/Social/Social.tscn")
	await get_tree().create_timer(1.2).timeout
	for k in ["post", "messages", "profile"]:
		get_tree().current_scene._on_tab_pressed(k)
		await get_tree().create_timer(0.6).timeout
		await _shot("Social_" + k)
	get_tree().quit()

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/%s.png" % n))
	print("CAPTURA ", n)
