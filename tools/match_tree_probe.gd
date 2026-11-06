extends Node
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	var player: PlayerData = SaveManager.load_player()
	MatchLauncher.prepare(WorldTickEngine.world, player, WorldTickEngine.next_user_fixture(player.club_id), "res://scenes/Hub/Hub.tscn", false)
	LiveBridge.test_auto = true
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/Match/Match.tscn")
	await get_tree().create_timer(12.0).timeout
	_dump(get_tree().current_scene, 0)
	get_tree().quit()
func _dump(n: Node, d: int) -> void:
	if d > 4:
		return
	var extra := ""
	if n is Control:
		var c := n as Control
		extra = " vis=%s pos=%s size=%s" % [c.visible, c.position.round(), c.size.round()]
	elif n is CanvasLayer:
		extra = " layer=%d" % (n as CanvasLayer).layer
	print("TREE ", "  ".repeat(d), n.name, " <", n.get_class(), ">", extra)
	for k in n.get_children():
		if k is Control or k is CanvasLayer or d < 1:
			_dump(k, d + 1)
