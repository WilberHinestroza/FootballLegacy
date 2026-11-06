extends Node
## Captura WageOffer / SponsorOffer con ofertas de prueba (la partida se
## respalda y se restaura desde afuera).
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	var p: PlayerData = SaveManager.load_player()
	p.pending_wage_offer = {"club_id": p.club_id, "old_wage": 400000, "new_wage": 650000, "reason": ""}
	p.pending_sponsor_offer = {"name": "Voltix", "weekly_income": 12000, "weeks_remaining": 30}
	SaveManager.save_player(p)
	get_tree().current_scene = null
	for sc in ["WageOffer", "SponsorOffer"]:
		get_tree().change_scene_to_file("res://scenes/%s/%s.tscn" % [sc, sc])
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/%s_data.png" % sc))
		print("CAPTURA ", sc)
	get_tree().quit()
