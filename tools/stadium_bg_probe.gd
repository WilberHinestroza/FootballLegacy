extends Control
## Captura REAL de los 3 fondos de estadio en pixel art (con las vallas
## propias tapando las del arte). Sin --headless:
##   godot --path . --resolution 576x1024 res://tools/StadiumBgProbe.tscn
func _ready() -> void:
	for v in ["day", "night", "rain"]:
		var bg := StadiumBg.build(Color("#c8102e"), Color("#0b2a6b"), 7, v)
		add_child(bg)
		for i in range(6):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/stadium_%s.png" % v))
		bg.queue_free()
		await get_tree().process_frame
	print("CAPTURA OK")
	get_tree().quit(0)
