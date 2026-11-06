extends Node
## Prueba (6-nov, partido solo 3D): si no juegas (sancionado), "Jugar" en la
## previa simula al instante y va al resumen, sin pasar por ningún partido 2D.
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	var player: PlayerData = SaveManager.load_player()
	var fixture: Dictionary = WorldTickEngine.next_user_fixture(player.club_id)
	var prep: Dictionary = MatchLauncher.prepare(WorldTickEngine.world, player, fixture, "res://scenes/Hub/Hub.tscn", false)
	print("NOPLAY prep ok=", prep.get("ok", false))
	MatchState.user_suspended = true
	print("NOPLAY 3D supported=", Match3DBridge.supported())
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/PreMatch/PreMatch.tscn")
	await get_tree().create_timer(1.5).timeout
	get_tree().current_scene._on_start_match_pressed()
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 60000:
		await get_tree().create_timer(0.3).timeout
		var cs: Node = get_tree().current_scene
		if cs != null and cs.scene_file_path.contains("Summary"):
			print("NOPLAY OK -> ", cs.scene_file_path.get_file(), " marcador=", MatchState.match_result.get("score", "?"))
			get_tree().quit(0)
			return
	print("NOPLAY FAIL: no llegó al resumen")
	get_tree().quit(1)

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")
