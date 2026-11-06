extends Node
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	var p: PlayerData = SaveManager.load_player()
	var clubs: Array = (WorldTickEngine.world["club_by_id"] as Dictionary).values()
	WorldTickEngine.season["awaiting_contract_decision"] = true
	WorldTickEngine.season["renewal_offer"] = {"club_id": p.club_id, "wage": 900000, "years": 3}
	WorldTickEngine.season["transfer_offers"] = [
		{"club_id": clubs[3].club_id, "club_name": clubs[3].club_name, "league_name": "Liga de prueba", "club_strength": 74, "is_home_country": false, "wage": 1400000, "years": 4},
		{"club_id": clubs[40].club_id, "club_name": clubs[40].club_name, "league_name": "Liga de prueba", "club_strength": 68, "is_home_country": true, "wage": 1100000, "years": 2}]
	SaveManager.save_season(WorldTickEngine.season)
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/ContractDecision/ContractDecision.tscn")
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/Contract.png"))
	print("CAPTURA contrato")
	get_tree().quit()
