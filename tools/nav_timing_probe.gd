extends Node
## Mide cuánto tarda en abrir cada pantalla (de change_scene al primer
## frame dibujado). Lo que pasa de ~100 ms se siente como un tirón.
const SCENES := ["Hub", "Calendar", "Standings", "PlayerProfile", "Agent", "Awards", "CareerMenu", "ClubInfo",
	"Coleccion", "CupBracket", "Lifestyle", "News", "Planner", "PlayerSearch", "Selections", "Settings", "Shop",
	"Social", "Sponsors", "Squad", "Training", "Transfers", "WorldExplorer", "Hub", "Squad", "Hub"]
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	get_tree().current_scene = null
	for s in SCENES:
		var t0: int = Time.get_ticks_usec()
		get_tree().change_scene_to_file("res://scenes/%s/%s.tscn" % [s, s])
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		print("TIEMPO %-14s %6.0f ms%s" % [s, ms, "  <-- LENTO" if ms > 120.0 else ""])
		await get_tree().create_timer(0.3).timeout
	get_tree().quit()
