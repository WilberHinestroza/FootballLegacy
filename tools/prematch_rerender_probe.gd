extends Node
## La previa se redibuja 3 veces (como al tocar camisetas/balón): sin
## duplicados ni errores, y las columnas siguen en pie.
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	var pl: PlayerData = SaveManager.load_player()
	MatchLauncher.prepare(WorldTickEngine.world, pl, WorldTickEngine.next_user_fixture(pl.club_id), "res://scenes/Hub/Hub.tscn", false)
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/PreMatch/PreMatch.tscn")
	await get_tree().create_timer(1.0).timeout
	var pm: Node = get_tree().current_scene
	for i in 3:
		pm._render()
		await get_tree().process_frame
	var vb: Node = pm.get_node("Scroll/Margin/VBox")
	var n_cols: int = 0
	for k in vb.get_children():
		if k.name.begins_with("LandCols"):
			n_cols += 1
	var tabs: int = vb.find_children("PM_Tabs*", "", true, false).size()
	print("REDIBUJO cols=", n_cols, " pestañas=", tabs, " alineaciones_en=", pm.teams_row.get_parent().name)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/PreMatch_rerender.png"))
	get_tree().quit()
