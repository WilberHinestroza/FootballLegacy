extends Node
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")
	await get_tree().create_timer(2.0).timeout
	var cols: Node = get_tree().current_scene.get_node("Root/Scroll/BodyMargin/BodyVBox/Cols")
	for side in cols.get_children():
		print("== col")
		for k in side.get_children():
			var c := k as Control
			print("  ", k.name, " ", k.get_class(), " vis=", c.visible, " h=", c.size.y, " txt=", _t(k).substr(0, 30))
			if k.name == "PressBox" or k.get_class() == "VBoxContainer":
				for kk in k.get_children():
					print("      ", kk.name, " ", kk.get_class(), " h=", (kk as Control).size.y if kk is Control else 0.0)
	get_tree().quit()
func _t(n: Node) -> String:
	if n is Label: return n.text
	if n is Button: return n.text
	for c in n.get_children():
		var t := _t(c)
		if t != "": return t
	return ""
