extends Node
## Instancia una escena real (con autoloads) y reporta errores de nodos
## @onready que no resuelven (path roto en el .tscn) — CompileCheck NO
## los detecta porque solo hace load(), nunca instantiate().
##   godot --headless res://tools/ScenePathProbe.tscn -- res://scenes/X/X.tscn
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://scenes/PlayerSearch/PlayerSearch.tscn"
	print("instanciando ", path)
	var packed: PackedScene = load(path)
	if packed == null:
		print("PROBE FAIL: no cargó ", path)
		get_tree().quit(1)
		return
	var inst: Node = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	print("PROBE OK (instanciado sin crash)")
	get_tree().quit(0)
