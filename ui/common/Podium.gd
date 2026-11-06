extends RefCounted
class_name Podium

## PODIO (P1, 9-oct): el escenario pixel (assets/ui/podium.png) con el
## top 3 de cuerpo entero — 1° al centro sobre el estrado, 2° y 3° a los
## costados — medalla, nombre y el número de la pestaña.
const HEIGHT := 250

## `top` = filas con "name"; `value_of(row) -> String` = el número a mostrar.
static func build(top: Array, my_name: String, value_of: Callable) -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, HEIGHT)
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/podium.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg)
	var me := SaveManager.load_player()
	var wseed: int = SaveManager.load_world_seed()
	# [anclaje x, alto de los pies (fracción), tamaño, medalla]
	var spots: Array = [[0.5, 0.80, 118, Medals.GOLD], [0.2, 0.90, 96, Medals.SILVER], [0.8, 0.90, 96, Medals.BRONZE]]
	for i in range(mini(top.size(), 3)):
		var r: Dictionary = top[i]
		var nm: String = String(r.get("name", "?"))
		var cfg: Dictionary = Avatar.config_for_player(me, wseed) if (nm == my_name and me != null) else Avatar.config_for_npc(nm, "player", wseed)
		var sp: Array = spots[i]
		var px: int = int(sp[2])
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_END
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var med := Medals.rect(Medals.by_name(String(sp[3])), 26)
		var mc := CenterContainer.new()
		if med != null:
			mc.add_child(med)
		col.add_child(mc)
		var av := Avatar.build_full(cfg, px)
		av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(av)
		var l := Label.new()
		l.text = "%s · %s" % [nm.get_slice(" ", nm.get_slice_count(" ") - 1), String(value_of.call(r))]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", Styles.font_black())
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Styles.GOLD if nm == my_name else Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", 5)
		col.add_child(l)
		col.custom_minimum_size = Vector2(150, 0)
		stage.add_child(col)
		# Posición: centrado en x, pies a la altura pedida (se acomoda al
		# tamaño real cuando el contenedor se dimensiona).
		var fx: float = float(sp[0])
		var fy: float = float(sp[1])
		stage.resized.connect(func():
			var h: float = col.get_combined_minimum_size().y
			col.size = Vector2(150, h)
			col.position = Vector2(stage.size.x * fx - 75.0, stage.size.y * fy - h + 16.0))
	return stage
