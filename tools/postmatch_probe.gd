extends Node
## Simula un partido y captura el post-partido (resumen y entrevista),
## arriba y scrolleado abajo.
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	var pl: PlayerData = SaveManager.load_player()
	MatchLauncher.prepare(WorldTickEngine.world, pl, WorldTickEngine.next_user_fixture(pl.club_id), "res://scenes/Hub/Hub.tscn", true)
	MatchState.apply_tie_aggregate()
	MatchState.match_result = await MatchState.engine.run_match()
	get_tree().current_scene = null
	for sc in ["MatchSummary", "PostMatchInterview"]:
		get_tree().change_scene_to_file("res://scenes/%s/%s.tscn" % [sc, sc])
		await get_tree().create_timer(1.5).timeout
		await _shot(sc + "_a")
		var cs: Node = get_tree().current_scene
		if cs == null:
			print("SIN ESCENA ", sc)
			continue
		var best: ScrollContainer = null
		for s in cs.find_children("*", "ScrollContainer", true, false):
			if (s as ScrollContainer).is_visible_in_tree():
				if best == null or (s.get_child(0) as Control).size.y > (best.get_child(0) as Control).size.y:
					best = s
		if best != null:
			print("SCROLL ", sc, " extra=", int((best.get_child(0) as Control).size.y - best.size.y))
			best.scroll_vertical = 100000
			await get_tree().create_timer(0.3).timeout
			await _shot(sc + "_b")
	get_tree().quit()

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/%s.png" % n))
	print("CAPTURA ", n)
