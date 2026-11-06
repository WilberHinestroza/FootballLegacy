extends Node
## Temporal: arranca el partido 3D suelto y guarda capturas de la salida del túnel.
func _ready() -> void:
	var m: Node = load("res://match3d/Main.tscn").instantiate()
	add_child(m)
	var t := 0.0
	for at: float in [0.8, 2.2, 3.4, 4.6, 6.0, 8.0, 11.0, 14.0, 17.5]:
		await get_tree().create_timer(at - t).timeout
		t = at
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("C:/Users/USUARIO/AppData/Local/Temp/claude/C--Users-USUARIO-Desktop-Proyectos-Godot-MiniSoccer3D/2cf8cef3-4f2e-4869-bd4d-afce45cbc8cf/scratchpad/walk_%04.1f.png" % at)
		print("shot ", at, " state=", m.get("state"))
	get_tree().quit()
