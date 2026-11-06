extends Node
## Captura REAL de una pantalla con un jugador sembrado en slot_3
## (desechable — borrar el slot_3.json real después). Sin --headless:
##   godot --path . --resolution 576x1024 res://tools/SeededShotProbe.tscn -- res://scenes/X/X.tscn salida.png [drawer]
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var p := PlayerData.new()
	p.player_name = "Probe Captura"
	p.balance = 250000
	SaveManager.save_player(p)
	var args := OS.get_cmdline_user_args()
	var inst: Node = (load(args[0]) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(inst)
	for i in range(20):
		await get_tree().process_frame
	if args.size() > 2 and args[2] == "drawer":
		var tb: Node = get_tree().get_first_node_in_group("nav_back_handlers")
		if tb != null:
			tb._set_drawer_open(true)
		for i in range(30):
			await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/" + args[1]))
	print("CAPTURA OK")
	get_tree().quit(0)
