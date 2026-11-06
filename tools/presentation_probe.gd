extends Node
## Captura REAL de la presentación oficial al fichar (con carrera sembrada).
func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	await get_tree().process_frame
	var p := SaveManager.load_player()
	var pp := PlayerPresentation.new()
	pp.setup({"club_id": p.club_id, "player": p, "years": 3, "number": 0, "loan": false})
	get_tree().root.add_child(pp)
	for i in range(80):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/presentation.png"))
	print("CAPTURA OK")
	get_tree().quit(0)
