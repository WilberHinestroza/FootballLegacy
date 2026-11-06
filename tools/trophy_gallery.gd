extends Control
## Captura REAL: trofeos de Wilber asignados (ligas, copas, internacionales, premios).
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.11, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.position = Vector2(4, 4)
	add_child(grid)
	var ids := ["mundial_seleccion", "natcup_UEFA", "natcup_CONMEBOL", "cont_UEFA_1", "cont_UEFA_2", "cont_CONMEBOL_1",
		"cont_CONMEBOL_2", "mundial_clubes", "supercopa", "supercopa_cont", "ballon_dor", "bota_oro",
		"max_goleador", "once_ideal", "mvp_liga", "mvp_temporada"]
	for i in ids:
		grid.add_child(_cell(Trophy.for_honor(i, 84), i))
	for t in ["league_2", "league_3", "league_4", "league_5", "league_6", "league_9", "league_10", "league_16", "dcup_España", "dcup_Inglaterra", "dcup_Chile", "dcup_Japón"]:
		grid.add_child(_cell(Trophy.for_title(t, 84), t))
	grid.add_child(_cell(BallDesign.build(3, 84), "balón 3"))
	grid.add_child(_cell(BallDesign.build(11, 84), "balón 11"))
	for i in range(20):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/trophy_gallery.png"))
	print("CAPTURA OK")
	get_tree().quit(0)

func _cell(n: Control, label: String) -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(92, 0)
	n.custom_minimum_size = Vector2(84, 84)
	v.add_child(n)
	var l := Label.new()
	l.text = label
	l.clip_text = true
	l.add_theme_font_size_override("font_size", 10)
	v.add_child(l)
	return v
