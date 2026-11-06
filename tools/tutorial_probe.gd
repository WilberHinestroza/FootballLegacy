extends Node
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	var pl: PlayerData = SaveManager.load_player()
	MatchLauncher.prepare(WorldTickEngine.world, pl, WorldTickEngine.next_user_fixture(pl.club_id), "res://scenes/Hub/Hub.tscn", false)
	var b := LiveBridge.new()
	add_child(b)
	b.build(Color.RED, Color.BLUE)
	var was: bool = Preferences.live_tutorial_seen
	Preferences.live_tutorial_seen = false
	b._tutorial()
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/Tutorial.png"))
	Preferences.live_tutorial_seen = was
	print("CAPTURA tutorial")
	get_tree().quit()
