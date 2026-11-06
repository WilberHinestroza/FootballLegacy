extends Node
## Sonda de regresión P0-12 · autoguardado a prueba de cierres.
##   godot --headless --path . res://tools/SaveAutosaveProbe.tscn
##
## Valida la escritura atómica (temporal + rotación a .bak), la recuperación
## de un .json truncado desde el respaldo, la recuperación desde un .tmp que
## quedó completo antes del rename, que delete_slot borre las tres copias y
## que autosave() vuelque WorldTickEngine.season. Usa un slot de prueba y lo
## limpia al terminar.

const SLOT := "slot_probe_autosave"

var fails := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		fails += 1
		print("FALLA: ", msg)

func _paths() -> Dictionary:
	return {
		"main": SaveManager.get_slot_path(SLOT),
		"bak": SaveManager.get_slot_path(SLOT) + ".bak",
		"tmp": SaveManager.get_slot_path(SLOT) + ".tmp",
	}

func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _read_raw(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	var t := f.get_as_text()
	f.close()
	return t

func _json_dict(path: String) -> Dictionary:
	var raw = JSON.parse_string(_read_raw(path))
	return raw if raw is Dictionary else {}

func _player_name(data: Dictionary) -> String:
	var player: Dictionary = data.get("player", {})
	return String(player.get("player_name", ""))

func _cleanup() -> void:
	SaveManager.delete_slot(SLOT)

func _ready() -> void:
	_cleanup()
	SaveManager.active_slot_id = SLOT
	_test_atomic_roundtrip()
	_test_corrupt_recovery()
	_test_tmp_recovery()
	_test_delete_removes_all()
	_test_autosave_flushes_season()
	_cleanup()
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)

func _test_atomic_roundtrip() -> void:
	SaveManager.save_slot(SLOT, {"player": {"player_name": "Uno"}})
	var p := _paths()
	_check(FileAccess.file_exists(p["main"]), "el guardado crea el .json principal")
	_check(not FileAccess.file_exists(p["tmp"]), "no queda temporal tras guardar")
	_check(not FileAccess.file_exists(p["bak"]), "el primer guardado no inventa un respaldo")
	_check(_player_name(SaveManager.load_slot(SLOT)) == "Uno", "roundtrip del primer guardado")

	SaveManager.save_slot(SLOT, {"player": {"player_name": "Dos"}})
	_check(FileAccess.file_exists(p["bak"]), "el segundo guardado rota el anterior a .bak")
	_check(_player_name(SaveManager.load_slot(SLOT)) == "Dos", "el principal manda sobre el respaldo")
	_check(_player_name(_json_dict(p["bak"])) == "Uno", "el .bak conserva la versión anterior")

func _test_corrupt_recovery() -> void:
	var p := _paths()
	# Principal truncado, como un cierre a mitad de escritura.
	_write_raw(p["main"], "{\"player\": {\"player_name\": \"Dos\"")
	var recovered := SaveManager.load_slot(SLOT)
	_check(_player_name(recovered) == "Uno", "un .json corrupto se recupera desde el .bak")
	_check(int(_json_dict(p["main"]).get("schema_version", 0)) == SaveManager.CURRENT_SCHEMA_VERSION,
		"la recuperación reescribe un principal legible")

func _test_tmp_recovery() -> void:
	var p := _paths()
	# Cierre justo entre el temporal completo y el rename: no hay principal
	# ni respaldo, pero sí un .tmp íntegro.
	if FileAccess.file_exists(p["main"]):
		DirAccess.remove_absolute(p["main"])
	if FileAccess.file_exists(p["bak"]):
		DirAccess.remove_absolute(p["bak"])
	_write_raw(p["tmp"], JSON.stringify(
		{"schema_version": SaveManager.CURRENT_SCHEMA_VERSION, "player": {"player_name": "Temporal"}}, "\t"))
	var recovered := SaveManager.load_slot(SLOT)
	_check(_player_name(recovered) == "Temporal", "un .tmp íntegro se usa si falta el principal")
	_check(FileAccess.file_exists(p["main"]), "el .tmp recuperado pasa a ser el principal")

func _test_delete_removes_all() -> void:
	var p := _paths()
	_write_raw(p["main"], JSON.stringify({"schema_version": SaveManager.CURRENT_SCHEMA_VERSION}))
	_write_raw(p["bak"], JSON.stringify({"schema_version": SaveManager.CURRENT_SCHEMA_VERSION}))
	_write_raw(p["tmp"], JSON.stringify({"schema_version": SaveManager.CURRENT_SCHEMA_VERSION}))
	SaveManager.delete_slot(SLOT)
	_check(not FileAccess.file_exists(p["main"]), "delete_slot borra el principal")
	_check(not FileAccess.file_exists(p["bak"]), "delete_slot borra el respaldo")
	_check(not FileAccess.file_exists(p["tmp"]), "delete_slot borra el temporal")
	_check(SaveManager.load_slot(SLOT).is_empty(), "un slot borrado no revive desde el respaldo")

func _test_autosave_flushes_season() -> void:
	SaveManager.save_slot(SLOT, {"player": {"player_name": "Auto"}})
	var wte := get_node_or_null("/root/WorldTickEngine")
	var original = wte.season
	wte.season = {"current_epoch_day": 12345, "season_start_epoch_day": 12300}
	SaveManager.autosave("cierre")
	var loaded := SaveManager.load_slot(SLOT)
	var season: Dictionary = loaded.get("season", {})
	_check(int(season.get("current_epoch_day", 0)) == 12345, "autosave vuelca WorldTickEngine.season")
	wte.season = original
