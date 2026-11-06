extends Node
## Prueba: previa del partido -> "Simular" -> resumen (FootballLegacy H).
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	var player: PlayerData = SaveManager.load_player()
	var world: Dictionary = WorldTickEngine.world
	var fixture: Dictionary = WorldTickEngine.next_user_fixture(player.club_id)
	var prep: Dictionary = MatchLauncher.prepare(world, player, fixture, "res://scenes/Hub/Hub.tscn", false)
	print("SIM prep ok=", prep.get("ok", false))
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/PreMatch/PreMatch.tscn")
	await get_tree().create_timer(1.5).timeout
	var pm: Node = get_tree().current_scene
	var b := Button.new()
	pm.add_child(b)
	pm._on_simulate_pressed(b)
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 60000:
		await get_tree().create_timer(0.3).timeout
		var cs: Node = get_tree().current_scene
		if cs != null and cs.scene_file_path.contains("Summary"):
			print("SIM OK -> ", cs.scene_file_path.get_file(), " marcador=", MatchState.match_result.get("score", "?"))
			get_tree().quit(0)
			return
	print("SIM FALLA: no llegó al resumen")
	get_tree().quit(1)
