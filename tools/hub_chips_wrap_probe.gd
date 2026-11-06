extends Node

## Prueba dirigida del bug de ChipsRow (Parte 87): con la ventana de
## fichajes abierta se suma el chip más largo ("Ventana de fichajes
## abierta") — antes ChipsRow era HBoxContainer (nunca hace salto de
## línea) y la fila se estiraba más ancha que la pantalla. Ahora es
## HFlowContainer. Instancia el Hub en el día de la ventana de fichajes y
## confirma: no crashea, el nodo es HFlowContainer, y el chip largo está
## ahí (no se salteó por error al cambiar el tipo de contenedor).
##   godot --headless res://tools/HubChipsWrapProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var first_league: LeagueData = world.get("leagues", [])[0]
	var clubs: Array = world.get("clubs_by_league", {}).get(first_league.league_id, [])
	var club_id: String = clubs[0].club_id

	var p := PlayerData.new()
	p.player_name = "Probe Chips"
	p.club_id = club_id
	SaveManager.save_world_seed(world_seed)
	SaveManager.save_player(p)
	var season: Dictionary = SeasonCalendar.build_season(world, first_league.league_id, 0, 2029, club_id, world_seed)
	season["current_epoch_day"] = 5  # dentro de la ventana de fichajes de verano [0,20]
	SaveManager.save_season(season)

	WorldTickEngine.load_runtime()
	print("DEBUG current_epoch_day=%d season_start=%d is_open=%s" % [
		WorldTickEngine.current_epoch_day,
		int(WorldTickEngine.season.get("season_start_epoch_day", -1)),
		WorldTickEngine.is_transfer_window_open()])

	var packed: PackedScene = load("res://scenes/Hub/Hub.tscn")
	var inst = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame

	var problems: int = 0
	var chips_row = inst.chips_row
	print("chips_row class: ", chips_row.get_class())
	if not (chips_row is HFlowContainer):
		print("FALLA: chips_row no es HFlowContainer")
		problems += 1

	var chip_texts: Array = []
	for chip in chips_row.get_children():
		for lbl in _all_labels(chip as Node):
			chip_texts.append(String(lbl.text))
	print("chips (%d): %s" % [chips_row.get_child_count(), chip_texts])
	var found_window_chip: bool = false
	for t in chip_texts:
		if String(t).contains("Ventana de fichajes"):
			found_window_chip = true
	if not found_window_chip:
		print("FALLA: no se agregó el chip de ventana de fichajes (¿is_transfer_window_open() no dio true?)")
		problems += 1

	print("PROBE ", "OK" if problems == 0 else "FAIL (%d)" % problems)
	get_tree().quit(1 if problems > 0 else 0)

func _all_labels(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_labels(c))
	return out
