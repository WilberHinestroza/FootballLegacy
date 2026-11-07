extends Node
## Capturas: pantalla Entrenamiento (botón Práctica + campo 3D) y pantalla Práctica
## con el resultado de una sesión. Carrera de prueba en slot_3.
func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var tree := get_tree()
	var tr: Node = load("res://scenes/Training/Training.tscn").instantiate()
	add_child(tr)
	await tree.create_timer(3.0).timeout
	tree.root.get_texture().get_image().save_png("res://build/practice_training.png")
	MatchState.practice_result = {"summary": {"mode": "scrim", "facet": "", "goals": 1, "assists": 1, "saves": 0, "ok": 5, "fail": 2, "moments": 7, "us": 3, "them": 1},
		"rewards": {"completed": ["Marca o asiste en titulares contra suplentes"], "xp": 50, "levels": 0, "locked": []}}
	tr.queue_free()
	add_child(load("res://scenes/Practice/Practice.tscn").instantiate())
	await tree.create_timer(2.0).timeout
	tree.root.get_texture().get_image().save_png("res://build/practice_screen.png")
	print("SHOTS OK")
	tree.quit()
