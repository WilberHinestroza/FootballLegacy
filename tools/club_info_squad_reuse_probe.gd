extends Node

## Prueba dirigida a la auditoría de rendimiento general: ClubInfo.gd
## armaba el plantel del club del usuario DOS veces en un solo render
## (_build_squad_card y _build_rivalry_card, cada una con su propio
## make_squad_with_transfers() para el MISMO club) — ahora se arma una
## sola vez en _ready() y se pasa a ambas. Instancia la escena REAL con
## un jugador/temporada de verdad (mismo patrón que HubFifaHeadsUpProbe)
## para ejercitar de verdad _build_rivalry_card() con el plantel ya armado.
##   godot --headless res://tools/ClubInfoSquadReuseProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var first_league: LeagueData = world.get("leagues", [])[0]
	var clubs: Array = world.get("clubs_by_league", {}).get(first_league.league_id, [])
	var club_id: String = clubs[0].club_id

	var p := PlayerData.new()
	p.player_name = "Probe ClubInfo"
	p.club_id = club_id
	p.position = "MF"
	p.detailed_position = "MC"
	p.overall = 70
	p.potential = 80
	SaveManager.save_world_seed(world_seed)
	SaveManager.save_player(p)
	var season: Dictionary = SeasonCalendar.build_season(world, first_league.league_id, 0, 2026, club_id, world_seed)
	SaveManager.save_season(season)
	WorldTickEngine.load_runtime()

	var packed: PackedScene = load("res://scenes/ClubInfo/ClubInfo.tscn")
	var inst: Node = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame

	var vbox: VBoxContainer = inst.get_node("Root/Scroll/Margin/VBox")
	var ok: bool = vbox.get_child_count() > 3
	print("ClubInfo instanciado sin crash, tarjetas construidas: %d" % vbox.get_child_count())
	if not ok:
		print("FALLA: se esperaban varias tarjetas (banner/plantel/gabinete/DT/...) y hay muy pocas")

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
