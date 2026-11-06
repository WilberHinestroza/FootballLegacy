extends Node
## Captura REAL de Vida personal con un jugador sembrado en slot_3
## (desechable). Sin --headless.
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var p := PlayerData.new()
	p.player_name = "Probe Vida"
	p.balance = 5000
	p.home_type = "apartment"
	p.car_type = "luxury_car"
	SaveManager.save_player(p)
	var inst: Node = (load("res://scenes/Lifestyle/Lifestyle.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(inst)
	for i in range(20):
		await get_tree().process_frame
	var sc := inst.find_child("*Scroll*", true, false) as ScrollContainer
	var k: int = 0
	for y in [0, 900, 1500]:
		if sc != null:
			sc.scroll_vertical = y
		for i in range(4):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/lifestyle_%d.png" % k))
		k += 1
	print("CAPTURA OK")
	get_tree().quit(0)
