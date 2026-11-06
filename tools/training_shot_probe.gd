extends "res://tools/ui_gallery_probe.gd"
## Captura de Entrenamiento a tamaño de celular, con tiempo para asentarse.
func _ready() -> void:
	_seed_career()
	await get_tree().process_frame
	var inst: Node = (load("res://scenes/Training/Training.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	for k in range(3):
		for i in range(40):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Training_%d.png" % k))
	for b in inst.find_children("*", "Button", true, false):
		if b.custom_minimum_size.y >= 84:
			print("BTN ", b.size, " min ", b.custom_minimum_size)
	var sc := inst.find_children("*", "ScrollContainer", true, false)
	for s in sc:
		print("SCROLL v=", s.scroll_vertical, " size=", s.size)
	get_tree().quit(0)
