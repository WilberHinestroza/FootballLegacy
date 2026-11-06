extends Node

## Prueba dirigida: migración de esquema v27 -> v28
## (player.season_matches_played, ver SaveManager.gd historial). Confirma
## que un save v27 sin el campo nuevo se migra con el backfill esperado
## (arranca del valor de season_appearances) y termina en
## CURRENT_SCHEMA_VERSION.
##   godot --headless res://tools/SchemaV28Probe.tscn

func _ready() -> void:
	var ok: bool = true

	var old_data: Dictionary = {
		"schema_version": 27,
		"world_seed": 20260906,
		"player": {
			"player_name": "Probe Migración", "club_id": "c_2_0",
			"season_appearances": 12, "season_goals": 5, "season_key_passes": 3,
			"caps": 2, "international_goals": 0, "international_assists": 0,
			"national_team_status": "",
		},
		"season": {},
	}

	var migrated: Dictionary = SaveManager._migrate_if_needed(old_data)
	print("schema_version final: %d (esperado %d)" % [int(migrated.get("schema_version", -1)), SaveManager.CURRENT_SCHEMA_VERSION])
	if int(migrated.get("schema_version", -1)) != SaveManager.CURRENT_SCHEMA_VERSION:
		print("FALLA: no llegó a la versión actual")
		ok = false

	var mp: Dictionary = migrated.get("player", {})
	print("season_matches_played tras migrar: %s (esperado 12, backfill de season_appearances)" % mp.get("season_matches_played", "FALTA"))
	if int(mp.get("season_matches_played", -1)) != 12:
		print("FALLA: el backfill no copió season_appearances")
		ok = false

	# Un save YA en v28 (con el campo puesto de verdad, distinto del
	# backfill) no debería tocarse.
	var v28_data: Dictionary = old_data.duplicate(true)
	v28_data["schema_version"] = 28
	(v28_data["player"] as Dictionary)["season_matches_played"] = 37
	var migrated2: Dictionary = SaveManager._migrate_if_needed(v28_data)
	var mp2: Dictionary = migrated2.get("player", {})
	print("save ya en v28 (season_matches_played=37 real): tras migrar = %s (no debería tocarse)" % mp2.get("season_matches_played", "FALTA"))
	if int(mp2.get("season_matches_played", -1)) != 37:
		print("FALLA: un save ya en v28 no debería perder su valor real")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
