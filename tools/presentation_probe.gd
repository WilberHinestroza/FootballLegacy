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
	# Momentos: entrada, saludo, camiseta, grada (segundos)
	var shots := []
	for i in 12:
		shots.append([1.0 + i * 1.4, "%02d" % i])
	var t0 := Time.get_ticks_msec()
	for sh in shots:
		while (Time.get_ticks_msec() - t0) / 1000.0 < float(sh[0]):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/presentation_%s.png" % sh[1]))
	print("CAPTURA OK")
	get_tree().quit(0)
