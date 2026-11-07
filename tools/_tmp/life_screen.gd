extends Node
## Captura de Vida personal con las vitrinas 3D (carrera de prueba en slot_3).
func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var scr: Node = load("res://scenes/Lifestyle/Lifestyle.tscn").instantiate()
	add_child(scr)
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png("res://build/life_screen.png")
	var sc: ScrollContainer = scr.scroll
	var target: Control = null
	for c in scr.body.find_children("*", "Control", true, false):
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("LifeStage.gd"):
			target = c
			break
	if target != null:
		sc.ensure_control_visible(target)
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png("res://build/life_screen2.png")
	print("SCREEN OK ", target != null)
	get_tree().quit()
