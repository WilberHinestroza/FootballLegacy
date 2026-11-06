extends Node
## Revisión de pantallas en horizontal: captura ARRIBA y ABAJO (scrolleada
## al final) de una pantalla, con slot_3 (copia de prueba).
##   godot --path . --resolution 1024x576 res://tools/ReviewProbe.tscn -- res://scenes/X/X.tscn nombre [prep]
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	SaveManager.active_slot_id = "slot_3"
	for a in args:
		if a.begins_with("slot_"):
			SaveManager.active_slot_id = a
	WorldTickEngine.load_runtime()
	var path: String = args[0]
	var out: String = args[1]
	if args.size() > 2 and args[2] == "prep":
		var pl: PlayerData = SaveManager.load_player()
		var wd: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
		MatchLauncher.prepare(wd, pl, WorldTickEngine.next_user_fixture(pl.club_id), "res://scenes/Hub/Hub.tscn", false)
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(inst)
	for i in range(24):
		await get_tree().process_frame
	_save(out + "_a.png")
	var best: ScrollContainer = null
	var best_extra: float = 40.0
	for sc in inst.find_children("*", "ScrollContainer", true, false):
		var s := sc as ScrollContainer
		if not s.is_visible_in_tree() or s.get_child_count() == 0:
			continue
		var extra: float = (s.get_child(0) as Control).size.y - s.size.y
		if extra > best_extra:
			best_extra = extra
			best = s
	if best != null:
		best.scroll_vertical = int(best_extra) + 100
		for i in range(6):
			await get_tree().process_frame
		_save(out + "_b.png")
		print("SCROLL ", out, " extra=", int(best_extra))
	get_tree().quit(0)

func _save(f: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/" + f))
