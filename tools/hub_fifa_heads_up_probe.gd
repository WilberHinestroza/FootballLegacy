extends Node

## Prueba dirigida del aviso "se viene una fecha FIFA" en el Hub (UX/UI,
## 13-sep): WorldTickEngine.days_until_next_international_window() +
## Hub._fifa_button. Ventanas de prueba (season_start=0): [67,76], [97,106],
## [128,137], [246,255], [340,349].
##   godot --headless res://tools/HubFifaHeadsUpProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var first_league: LeagueData = world.get("leagues", [])[0]
	var clubs: Array = world.get("clubs_by_league", {}).get(first_league.league_id, [])
	var club_id: String = clubs[0].club_id

	var p := PlayerData.new()
	p.player_name = "Probe FIFA Hub"
	p.club_id = club_id
	SaveManager.save_world_seed(world_seed)
	SaveManager.save_player(p)
	var season: Dictionary = SeasonCalendar.build_season(world, first_league.league_id, 0, 2029, club_id, world_seed)
	SaveManager.save_season(season)
	WorldTickEngine.load_runtime()

	var problems: int = 0

	# día 61: faltan 6 para la ventana [67,76] → dentro del lookahead (6).
	WorldTickEngine.current_epoch_day = 61
	var d1: int = WorldTickEngine.days_until_next_international_window()
	print("día 61 -> faltan %d (esperado 6)" % d1)
	if d1 != 6:
		problems += 1

	# día 55: faltan 12 → fuera del lookahead default (6) → -1.
	WorldTickEngine.current_epoch_day = 55
	var d2: int = WorldTickEngine.days_until_next_international_window()
	print("día 55 -> faltan %s (esperado -1, fuera de lookahead)" % d2)
	if d2 != -1:
		problems += 1

	# día 70: YA está en la ventana [67,76] -> -1 (no "viene", ya llegó).
	WorldTickEngine.current_epoch_day = 70
	var d3: int = WorldTickEngine.days_until_next_international_window()
	print("día 70 (dentro de la ventana) -> %s (esperado -1)" % d3)
	if d3 != -1:
		problems += 1

	# día 130: recién salió de [128,137]... espera, 130 SIGUE dentro
	# [128,137] -> -1. Probamos 140 (fuera de toda ventana, próxima 246,
	# lejos) -> -1 por estar fuera de lookahead.
	WorldTickEngine.current_epoch_day = 140
	var d4: int = WorldTickEngine.days_until_next_international_window()
	print("día 140 (lejos de toda ventana) -> %s (esperado -1)" % d4)
	if d4 != -1:
		problems += 1

	# --- Hub: instanciar con este estado y confirmar el botón/texto ---
	# Hub._ready() llama WorldTickEngine.load_runtime(), que RELEE
	# season["current_epoch_day"] de disco — un cambio en memoria del
	# autoload no alcanza, hay que grabarlo en el save (mismo motivo por
	# el que WorldTickEngine.advance_day() siempre persiste season).
	season["current_epoch_day"] = 61
	SaveManager.save_season(season)
	var packed: PackedScene = load("res://scenes/Hub/Hub.tscn")
	var inst = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var btn: Button = inst._fifa_button
	print("Hub._fifa_button: visible=%s texto='%s'" % [btn.visible if btn else "NULL", btn.text if btn else "?"])
	if btn == null or not btn.visible or not btn.text.contains("6"):
		print("FALLA: el botón del Hub no refleja los 6 días")
		problems += 1

	print("PROBE ", "OK" if problems == 0 else "FAIL (%d)" % problems)
	get_tree().quit(1 if problems > 0 else 0)
