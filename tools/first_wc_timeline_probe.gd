extends Node

## Chequeo puntual (no permanente, respuesta a pregunta de Wilber): en una
## carrera NUEVA (season_start_epoch_day=0, temporada "2026" = año de
## Mundial real), ¿en qué día el campo del Mundial queda completo/con
## campeón? No toca slot_1/slot_2 (usa slot_3, desechable).
##   godot --headless res://tools/FirstWcTimelineProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var strength_by_club: Dictionary = {}
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in meta_by_id:
		strength_by_club[club_id] = int(meta_by_id[club_id].get("base_overall", 55))

	WorldTickEngine.world = world
	WorldTickEngine.world_seed = world_seed
	WorldTickEngine._strength_by_club = strength_by_club
	WorldTickEngine.season = {"start_year": 2026, "season_start_epoch_day": 0}

	var days: Array = [0, 100, 200, 300, WorldCupEngine.GROUP_START_OFFSET,
		WorldCupEngine.KNOCKOUT_OFFSET, WorldCupEngine.KNOCKOUT_OFFSET + WorldCupEngine.SPAN_TO_FINAL]
	for day in days:
		WorldTickEngine.current_epoch_day = int(day)
		var wc: Dictionary = WorldTickEngine.world_cup_this_cycle()
		var groups_n: int = (wc.get("groups", []) as Array).size()
		var champ: String = String(wc.get("champion_country", ""))
		print("día %d: mundial vacío=%s grupos=%d campeón=%s" % [day, wc.is_empty(), groups_n, champ])
	get_tree().quit()
