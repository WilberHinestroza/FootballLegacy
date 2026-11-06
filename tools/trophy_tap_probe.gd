extends Node
## Ventanita de "¡CAMPEÓN!": captura real + se cierra con UN toque (bug
## 9-oct). Sin --headless (para la captura):
##   godot --path . --resolution 576x1024 res://tools/TrophyTapProbe.tscn
func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	await get_tree().process_frame
	get_tree().current_scene = dummy
	var ms := Control.new()
	ms.set_script(load("res://tools/champ_overlay_host.gd"))
	ms.size = Vector2(576, 1024)
	get_tree().root.add_child(ms)
	await get_tree().process_frame
	ms.call("_play_trophy_lift", "league", "¡CAMPEÓN DE LIGA!")
	for i in range(150):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/champ_overlay.png"))
	var opened: bool = _layers(ms) == 1
	Input.emulate_touch_from_mouse = true
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = Vector2(288, 600)
		e.global_position = e.position
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(e)
		await get_tree().process_frame
	for i in range(40):
		await get_tree().process_frame
	var closed: bool = _layers(ms) == 0
	print("abierta: ", opened, " / cerrada con un toque: ", closed)
	print("PROBE ", "OK" if opened and closed else "FAIL")
	get_tree().quit(0)

func _layers(n: Node) -> int:
	var c: int = 0
	for ch in n.get_children():
		if ch is CanvasLayer and is_instance_valid(ch) and not ch.is_queued_for_deletion():
			c += 1
	return c
