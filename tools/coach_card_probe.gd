extends Control
## Captura REAL: DT y camilla sobre el fondo de la tarjeta de eventos.
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var m: Node = load("res://scenes/Match/Match.gd").new()
	var row := HBoxContainer.new()
	row.position = Vector2(30, 60)
	row.add_theme_constant_override("separation", 30)
	add_child(row)
	row.add_child(m._coach_anim("festeja"))
	row.add_child(m._coach_anim("enojado"))
	row.add_child(m._stretcher_icon(Label.new()))
	for i in range(12):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().get_region(Rect2i(0, 0, 400, 200)).save_png(ProjectSettings.globalize_path("res://_pixellab_preview/coach_card.png"))
	print("CAPTURA OK")
	get_tree().quit(0)
