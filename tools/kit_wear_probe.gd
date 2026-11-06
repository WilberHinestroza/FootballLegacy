extends Control
## Captura REAL: el jugador VISTE el diseño del club (plantillas de Wilber)
## en busto, cuerpo entero, festejo y sprite de cancha.
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.11, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var base: Dictionary = Avatar.random_config(11)
	for k in ["outfit"] + Avatar.ACC_SLOTS:
		base.erase(k)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(6, 6)
	add_child(grid)
	var combos := [[0, "#c8102e", "#ffffff"], [4, "#0b2a6b", "#f2c200"], [14, "#1b7a3a", "#ffffff"], [3, "#ffffff", "#1b7a3a"], [22, "#6a1b9a", "#ffd54f"]]
	for cmb in combos:
		var c := base.duplicate()
		c["tint_clothing"] = cmb[1]
		c["tint_shorts"] = "#1f2026"
		c["kit_w"] = cmb[0]
		c["tint_kit2"] = cmb[2]
		grid.add_child(_cell(Kit.build(Color(cmb[1]), Color(cmb[2]), {"w": cmb[0]}, 104, 10)))
	for cmb in combos:
		var c := base.duplicate()
		c["tint_clothing"] = cmb[1]; c["tint_shorts"] = "#1f2026"; c["kit_w"] = cmb[0]; c["tint_kit2"] = cmb[2]
		grid.add_child(_cell(Avatar.build(c, 104)))
	for cmb in combos:
		var c := base.duplicate()
		c["tint_clothing"] = cmb[1]; c["tint_shorts"] = "#1f2026"; c["kit_w"] = cmb[0]; c["tint_kit2"] = cmb[2]
		grid.add_child(_cell(Avatar.build_full(c, 104)))
	for cmb in combos:
		var c := base.duplicate()
		c["tint_clothing"] = cmb[1]; c["tint_shorts"] = "#1f2026"; c["kit_w"] = cmb[0]; c["tint_kit2"] = cmb[2]
		grid.add_child(_cell(Avatar.build_anim(c, "celeb_corazon", 104, true)))
	for cmb in combos:
		var c := base.duplicate()
		c["tint_clothing"] = cmb[1]; c["tint_shorts"] = "#1f2026"; c["kit_w"] = cmb[0]; c["tint_kit2"] = cmb[2]
		grid.add_child(_cell(Avatar.build_anim(c, "pitch_run_south", 104, true)))
	for i in range(30):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/kit_wear.png"))
	print("CAPTURA OK")
	get_tree().quit(0)

func _cell(n: Control) -> Control:
	n.custom_minimum_size = Vector2(108, 108)
	return n
