extends Node
## Captura las ventanas emergentes / subpantallas en horizontal.
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	get_tree().current_scene = null
	var me: PlayerData = SaveManager.load_player()
	await _go("Squad")
	get_tree().current_scene._open_full_card(me)
	await _shot("P_ficha")
	CharacterDraft.identity = {}
	CharacterDraft.avatar_done = false
	await _go("CharacterCreation")
	get_tree().current_scene._open_country_picker()
	await _shot("P_pais")
	await _go("PlayerSearch")
	get_tree().current_scene._open_league_picker()
	await _shot("P_liga")
	await _go("WorldExplorer")
	var lg: LeagueData = WorldTickEngine.world["leagues"][0]
	get_tree().current_scene._on_league_chosen(lg)
	await _shot("P_liga_detalle")
	await _go("WorldExplorer")
	var we: Node = get_tree().current_scene
	we._on_continental_mode_pressed()
	await get_tree().create_timer(0.4).timeout
	we._on_confederation_row_chosen("UEFA")
	await _shot("P_continental")
	await _go("Social")
	var th: Array = SocialEngine.generate_threads(me, WorldTickEngine.world, SaveManager.load_world_seed(), WorldTickEngine.current_epoch_day, WorldTickEngine.season)
	if not th.is_empty():
		get_tree().current_scene._open_thread(th[0])
		await _shot("P_chat")
	await _go("Calendar")
	get_tree().current_scene._open_sim_overlay()
	await _shot("P_sim")
	var rep := {"start_year": 2026, "wrapped": {"goals": 12, "assists": 9, "matches": 34, "best_rating": 8.7, "minutes": 2710}}
	await _go("Hub")
	SeasonWrapped.open(get_tree().current_scene, rep)
	await _shot("P_wrapped")
	get_tree().quit()

func _go(sc: String) -> void:
	get_tree().change_scene_to_file("res://scenes/%s/%s.tscn" % [sc, sc])
	await get_tree().create_timer(1.2).timeout

func _shot(n: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/%s.png" % n))
	print("CAPTURA ", n)
