extends Node
## Captura del Inicio con un partido pendiente HOY (botón "Ir al partido").
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")
	await get_tree().create_timer(1.5).timeout
	var hub: Node = get_tree().current_scene
	var pl: PlayerData = SaveManager.load_player()
	hub._pending_fixture = WorldTickEngine.next_user_fixture(pl.club_id)
	hub._land_refresh_match_day()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/Hub_matchday.png"))
	print("OK ", hub._land_match_btn.text)
	get_tree().quit()
