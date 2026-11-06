extends Node
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	var pl: PlayerData = SaveManager.load_player()
	MatchLauncher.prepare(WorldTickEngine.world, pl, WorldTickEngine.next_user_fixture(pl.club_id), "res://scenes/Hub/Hub.tscn", false)
	LiveBridge.test_auto = true
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/Match/Match.tscn")
	await get_tree().create_timer(6.0).timeout
	var cs: Node = get_tree().current_scene
	var b: LiveBridge = cs._live_bridge
	if b == null:
		print("EMBED sin bridge")
	else:
		var c: Control = b.container
		print("EMBED parent=", c.get_parent().name, " vis=", c.is_visible_in_tree(), " rect=", c.get_global_rect(), " slot=", cs._live_slot.get_global_rect(), " svp_proc=", b.svp.process_mode, " state=", b.m.state)
	for i in 120:
		await get_tree().create_timer(0.5).timeout
		if b != null and b.m.state != "moment" and b.container.get_parent() == cs._live_slot:
			await get_tree().create_timer(2.0).timeout
			break
	if b != null:
		var c2: Control = b.container
		print("EMBED2 parent=", c2.get_parent().name, " vis=", c2.is_visible_in_tree(), " rect=", c2.get_global_rect(), " mod=", c2.modulate, " state=", b.m.state, " svp=", b.svp.process_mode)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/Embed_check.png"))
	get_tree().quit()
