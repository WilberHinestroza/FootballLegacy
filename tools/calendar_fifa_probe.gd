extends Node

## Prueba dirigida de Calendar.gd: arma un slot_3 mínimo, instancia la escena
## horizontal y confirma que la cuadrícula mensual se dibuja completa. Los
## fixtures FIFA puntuales se cubren en NationalCalendarIntegrationProbe.
##   godot --headless res://tools/CalendarFifaProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var first_league: LeagueData = world.get("leagues", [])[0]
	var clubs: Array = world.get("clubs_by_league", {}).get(first_league.league_id, [])
	var club_id: String = clubs[0].club_id

	var p := PlayerData.new()
	p.player_name = "Probe Calendario"
	p.club_id = club_id
	p.country = "Argentina"
	p.position = "ST"
	p.detailed_position = "DC"
	p.overall = 75
	p.potential = 80
	SaveManager.save_world_seed(world_seed)
	SaveManager.save_player(p)

	var season: Dictionary = SeasonCalendar.build_season(world, first_league.league_id, 0, 2026, club_id, world_seed)
	SaveManager.save_season(season)

	var packed: PackedScene = load("res://scenes/Calendar/Calendar.tscn")
	var inst = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame

	var rendered_days: int = inst.days_grid.get_child_count()
	print("calendario renderizado: días=%d · horizontal=%s · viewport=%s" % [rendered_days, inst._land, get_viewport().get_visible_rect().size])
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png("res://build/m3d_review_calendar.png")
	var ok: bool = rendered_days >= 28 and inst.month_label.text != ""
	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
