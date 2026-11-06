extends Node
## Captura REAL de una pantalla del juego (con render — correr SIN
## --headless, con --resolution 576x1024) usando slot_3 (copia desechable).
##   godot --path . --resolution 576x1024 res://tools/ScreenshotProbe.tscn -- res://scenes/X/X.tscn salida.png
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://scenes/Standings/Standings.tscn"
	var out: String = args[1] if args.size() > 1 else "shot.png"
	# 3er argumento "prep": arma el próximo partido (como el Hub) antes de
	# abrir la pantalla — para Previa / Partido / Resumen.
	if args.size() > 2 and args[2] == "prep":
		var pl: PlayerData = SaveManager.load_player()
		var wd: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
		MatchLauncher.prepare(wd, pl, WorldTickEngine.next_user_fixture(pl.club_id), "res://scenes/Hub/Hub.tscn", false)
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(inst)
	for i in range(20):
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://_pixellab_preview/" + out))
	print("CAPTURA OK ", out, " ", img.get_size())
	get_tree().quit(0)
