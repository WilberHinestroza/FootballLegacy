extends Control

## Pantalla inicial ÚNICA (antes eran dos: Start = menú, MainMenu = slots,
## borrado por huérfano). Todo vive acá — fondo de estadio, los 3 slots
## seleccionables, un botón Jugar grande, y los accesos secundarios
## (Ajustes / Colección / Acerca de / Importar mundo). Pedido explícito de
## Wilber con prototipo.

@onready var vbox: VBoxContainer = $Margin/VBox
@onready var delete_confirm: ConfirmationDialog = $DeleteConfirmDialog

var _selected: int = 0
var _pending_delete_slot: String = ""
var _world_cache: Dictionary = {}   # world_seed -> world (evita rebuild por slot)

func _ready() -> void:
	# Prueba de rendimiento (un solo uso): ver tools/perf_test.gd.
	if FileAccess.file_exists("user://perftest"):
		DirAccess.remove_absolute("user://perftest")
		get_tree().change_scene_to_file.call_deferred("res://tools/PerfTest.tscn")
		return
	SaveManager.migrate_legacy_slots_if_needed()
	# Fondo de estadio (mismo helper que el partido / la barra superior).
	# Estadio en pixel art de noche (9-oct, rediseño) — la misma identidad
	# visual del resto del juego, en vez de la foto.
	var bg := StadiumBg.build(Color(0.2, 0.5, 0.3), Color(0.9, 0.8, 0.3), 3, "night")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)
	delete_confirm.confirmed.connect(_on_delete_confirmed)

	_selected = _most_recent_slot()
	_render()

## El slot con la partida más avanzada (mayor día). Si no hay ninguna, 0.
func _most_recent_slot() -> int:
	var best: int = 0
	var best_day: int = -1
	for i in range(SaveManager.SLOT_IDS.size()):
		var s := SaveManager.slot_summary(SaveManager.SLOT_IDS[i])
		if not s.is_empty() and int(s.get("current_epoch_day", 0)) > best_day:
			best_day = int(s["current_epoch_day"])
			best = i
	return best

func _render() -> void:
	for c in vbox.get_children():
		c.queue_free()

	# Logo (9-oct): trofeo + FOOTBALL/LEGACY en dos tonos + balón.
	var logo := HBoxContainer.new()
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	logo.add_theme_constant_override("separation", 10)
	var cup := Trophy.for_honor("mundial_seleccion", 64)
	cup.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.add_child(cup)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -10)
	for w in [["FOOTBALL", Color.WHITE], ["LEGACY", Styles.GOLD]]:
		var t := Label.new()
		t.text = String(w[0])
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_font_override("font", Styles.font_black())
		t.add_theme_font_size_override("font_size", 40)
		t.add_theme_color_override("font_color", w[1])
		t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		t.add_theme_constant_override("outline_size", 10)
		words.add_child(t)
	logo.add_child(words)
	var ball := BallDesign.build(0, 52)
	ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.add_child(ball)
	vbox.add_child(logo)

	var subtitle := Label.new()
	subtitle.text = "Tu carrera, tu historia"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	vbox.add_child(subtitle)

	vbox.add_child(_spacer(10))
	vbox.add_child(Styles.section_label("Elige una partida"))

	for i in range(SaveManager.SLOT_IDS.size()):
		vbox.add_child(_build_slot_row(i))

	vbox.add_child(_spacer(6))

	var play := Button.new()
	play.custom_minimum_size = Vector2(0, 60)
	play.focus_mode = Control.FOCUS_NONE
	play.icon = Icons.load_icon(Icons.PLAY)
	play.add_theme_constant_override("icon_max_width", 24)
	var sel_summary := SaveManager.slot_summary(SaveManager.SLOT_IDS[_selected])
	play.text = "  Continuar" if not sel_summary.is_empty() else "  Nueva carrera"
	Styles.styled_button(play, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	play.pressed.connect(_on_play_pressed)
	vbox.add_child(play)

	vbox.add_child(_spacer(4))

	# Accesos secundarios en 2 columnas.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.add_child(_menu_button("Ajustes", Icons.SETTINGS, Styles.GRAY_TEXT, _on_settings))
	grid.add_child(_menu_button("Colección", Icons.COLLECTION, Styles.GRAY_TEXT, _on_collection))
	grid.add_child(_menu_button("Acerca de", Icons.INFO, Styles.GRAY_TEXT, _on_about))
	grid.add_child(_menu_button("Importar mundo", Icons.IMPORT, Styles.BLUE, _on_import))
	vbox.add_child(grid)

	vbox.add_child(_spacer(4))
	var quit := Button.new()
	quit.custom_minimum_size = Vector2(0, 44)
	quit.text = "Salir"
	quit.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(quit, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
	quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit)
	_landscape_split()

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _menu_button(text: String, icon_path: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "  " + text
	b.custom_minimum_size = Vector2(0, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.icon = Icons.load_icon(icon_path)
	b.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(b, Styles.pill_outlined(col), Color.WHITE if col == Styles.GRAY_TEXT else col)
	b.pressed.connect(cb)
	return b

func _build_slot_row(index: int) -> PanelContainer:
	var slot_id: String = SaveManager.SLOT_IDS[index]
	var summary := SaveManager.slot_summary(slot_id)
	var is_selected: bool = index == _selected

	var panel := PanelContainer.new()
	var bg: Color = Color(0.10, 0.16, 0.11) if is_selected else Color(0.10, 0.11, 0.13)
	var style := Styles.card_accent(Styles.GREEN, bg, 12) if is_selected else Styles.card(bg, 12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Insignia: escudo del club si hay partida, llave si el slot está vacío.
	if summary.is_empty():
		var key_badge := PanelContainer.new()
		key_badge.custom_minimum_size = Vector2(44, 44)
		key_badge.add_theme_stylebox_override("panel", Styles.circle(Color(1, 1, 1, 0.10), 44))
		var kc := CenterContainer.new()
		kc.add_child(Icons.make_rect(Icons.PLAY, 18, Styles.GRAY_TEXT))
		key_badge.add_child(kc)
		hbox.add_child(key_badge)
	else:
		var world := _world_for(int(summary["world_seed"]))
		var club := WorldFactory.find_club(world, String(summary["club_id"]))
		var col: Color = Color(club.primary_color_hex) if (club != null and not club.primary_color_hex.is_empty()) else Styles.BLUE
		var sec: Color = Color(club.secondary_color_hex) if (club != null and not club.secondary_color_hex.is_empty()) else Color.TRANSPARENT
		var short_name: String = club.short_name if club != null else "?"
		hbox.add_child(Styles.build_club_badge(col, short_name, 44, sec, String(summary.get("club_id", ""))))

	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 1)

	var line1 := Label.new()
	line1.clip_text = true
	if summary.is_empty():
		line1.text = "Slot %d — Nueva carrera" % (index + 1)
		line1.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	else:
		line1.text = "Slot %d — %s" % [index + 1, summary["player_name"]]
		line1.add_theme_font_override("font", Styles.font_semibold())
	names.add_child(line1)

	if not summary.is_empty():
		var world2 := _world_for(int(summary["world_seed"]))
		var club2 := WorldFactory.find_club(world2, String(summary["club_id"]))
		var line2 := Label.new()
		var start_year: int = int(summary.get("start_year", 0))
		line2.text = "%s · Temporada %d/%d" % [club2.club_name if club2 != null else "?", start_year, start_year + 1]
		line2.clip_text = true
		line2.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		line2.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		names.add_child(line2)
	hbox.add_child(names)

	# Botón de borrar (solo slots con partida). Va con mouse_filter STOP
	# para que su toque no "caiga" al panel (que selecciona el slot).
	if not summary.is_empty():
		var del := Button.new()
		del.custom_minimum_size = Vector2(46, 44)
		del.focus_mode = Control.FOCUS_NONE
		del.icon = Icons.load_icon(Icons.TRASH)
		del.add_theme_constant_override("icon_max_width", 22)
		del.mouse_filter = Control.MOUSE_FILTER_STOP
		Styles.styled_button(del, Styles.pill_outlined(Styles.RED), Styles.RED)
		del.pressed.connect(_on_delete_pressed.bind(slot_id))
		hbox.add_child(del)

	panel.add_child(hbox)
	UiScroll.on_tap(panel, func():
		_selected = index
		_render())
	return panel

func _world_for(seed_val: int) -> Dictionary:
	if not _world_cache.has(seed_val):
		_world_cache[seed_val] = WorldFactory.build(seed_val)
	return _world_cache[seed_val]

# --- Acciones ---

func _on_play_pressed() -> void:
	var slot_id: String = SaveManager.SLOT_IDS[_selected]
	if SaveManager.slot_summary(slot_id).is_empty():
		SaveManager.active_slot_id = slot_id
		CharacterDraft.clear() # empezar de cero el flujo de creación
		get_tree().change_scene_to_file("res://scenes/CharacterCreation/CharacterCreation.tscn")
	else:
		SaveManager.active_slot_id = slot_id
		WorldTickEngine.load_runtime()
		get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/Settings/Settings.tscn")

func _on_collection() -> void:
	get_tree().change_scene_to_file("res://scenes/Coleccion/Coleccion.tscn")

func _on_about() -> void:
	Placeholder.title = "Acerca de"
	Placeholder.body = "FootballLegacy\nCarrera individual de futbolista, hecho en Godot.\n\nProyecto personal de Wilber."
	get_tree().change_scene_to_file("res://scenes/Placeholder/Placeholder.tscn")

func _on_import() -> void:
	get_tree().change_scene_to_file("res://scenes/ImportWorld/ImportWorld.tscn")

func _on_delete_pressed(slot_id: String) -> void:
	_pending_delete_slot = slot_id
	delete_confirm.dialog_text = "¿Borrar esta carrera? No se puede deshacer."
	delete_confirm.popup_centered()

func _on_delete_confirmed() -> void:
	if _pending_delete_slot == "":
		return
	SaveManager.delete_slot(_pending_delete_slot)
	_pending_delete_slot = ""
	_world_cache.clear()
	_selected = _most_recent_slot()
	_render()


## HORIZONTAL (FootballLegacy H): logo y lema a la izquierda (centrados),
## slots + Continuar + accesos a la derecha.
func _landscape_split() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= vp.y:
		return
	var kids: Array = []
	for c in vbox.get_children():
		if not c.is_queued_for_deletion():
			kids.append(c)
	if kids.size() < 3:
		return
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.3
	# Separación justa para que entre todo, "Salir" incluido.
	right.add_theme_constant_override("separation", mini(vbox.get_theme_constant("separation"), 10))
	cols.add_child(left)
	cols.add_child(right)
	vbox.add_child(cols)
	kids[0].reparent(left)
	kids[1].reparent(left)
	for i in range(2, kids.size()):
		kids[i].reparent(right)
	var m := $Margin as MarginContainer
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
