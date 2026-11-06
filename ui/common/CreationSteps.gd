class_name CreationSteps
extends RefCounted
## Indicador de pasos de "Crear jugador" (FootballLegacy H):
##   ① Datos  —  ② Apariencia  —  ③ Personalidad
## El paso actual va en dorado, los hechos en verde, los que faltan en gris.

const STEPS := ["Datos", "Apariencia", "Personalidad"]

static func make(current: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "CreationSteps"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in STEPS.size():
		if i > 0:
			var line := ColorRect.new()
			line.custom_minimum_size = Vector2(36, 2)
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.color = Styles.GREEN if i <= current else Color(1, 1, 1, 0.18)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(line)
		var col: Color = Styles.GOLD if i == current else (Styles.GREEN if i < current else Color(0.45, 0.47, 0.53))
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2(24, 24)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", Styles.card_flat(col, 12))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n := Label.new()
		n.text = "✓" if i < current else str(i + 1)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.add_theme_font_override("font", Styles.font_black())
		n.add_theme_font_size_override("font_size", 12)
		n.add_theme_color_override("font_color", Color.BLACK)
		dot.add_child(n)
		row.add_child(dot)
		var t := Label.new()
		t.text = STEPS[i]
		t.add_theme_font_override("font", Styles.font_semibold())
		t.add_theme_font_size_override("font_size", 14)
		t.add_theme_color_override("font_color", Color.WHITE if i == current else Color(0.6, 0.62, 0.68))
		row.add_child(t)
	return row
