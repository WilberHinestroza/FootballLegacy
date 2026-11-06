extends Control

## Importa un mundo (ligas + clubes + jugadores + DTs) desde un .json que
## el usuario elige — ver WorldImporter.gd para el parseo/validación y
## WorldFactory.gd para cómo ese mundo reemplaza al procedural (semilla
## centinela WorldFactory.IMPORTED_SEED). El archivo se guarda tal cual en
## user://imported_world.json; desde ahí toda carrera NUEVA lo usa (no es
## una elección por partida, es un interruptor global).
##
## Nada de esto toca una carrera ya en curso: su season/cup/resultados ya
## guardados siguen intactos, solo cambia qué mundo arma WorldFactory la
## próxima vez que alguien elija "Nueva carrera".

@onready var status_label: Label = $Root/Margin/VBox/StatusLabel
@onready var pick_button: Button = $Root/Margin/VBox/PickButton
@onready var clear_button: Button = $Root/Margin/VBox/ClearButton
@onready var back_button: Button = $Root/Margin/VBox/BackButton
@onready var file_dialog: FileDialog = $FileDialog
@onready var clear_confirm: ConfirmationDialog = $ClearConfirmDialog

func _ready() -> void:
	pick_button.icon = Icons.load_icon(Icons.IMPORT)
	pick_button.add_theme_constant_override("icon_max_width", 24)
	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)

	Styles.styled_button(pick_button, Styles.pill_filled(Styles.BLUE), Color.BLACK)
	Styles.styled_button(clear_button, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	UiKit.land_back_arrow.call_deferred(back_button)
	_steps_row()

	pick_button.pressed.connect(_on_pick_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	back_button.pressed.connect(_on_back_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	clear_confirm.confirmed.connect(_on_clear_confirmed)

	# En Android el diálogo propio de Godot solo ve el sandbox de la app —
	# los .json que el usuario baja a Descargas/Documentos NO aparecen.
	# `use_native_dialog` = el selector de archivos DEL SISTEMA (SAF), que
	# es lo que Wilber espera. Devuelve una URI content:// que FileAccess
	# abre igual. Filtro amplio: algunos gestores no etiquetan el .json con
	# MIME application/json y quedaría gris.
	file_dialog.use_native_dialog = true
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray([
		"*.json ; Mundo (JSON)", "*.txt ; Texto", "* ; Todos los archivos",
	])

	_refresh_status()

func _refresh_status() -> void:
	if not WorldFactory.has_imported_world():
		status_label.text = "No hay ningún mundo importado. Las carreras nuevas usan el generador de siempre."
		status_label.remove_theme_color_override("font_color")
		clear_button.visible = false
		return

	var file := FileAccess.open(WorldFactory.IMPORTED_WORLD_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if file != null:
		file.close()
	if raw is Dictionary:
		var s: Dictionary = WorldImporter.summarize(raw)
		status_label.text = "Mundo importado activo:\n%d ligas · %d clubes · %d jugadores · %d entrenadores\n\nLas carreras NUEVAS van a usar este mundo." % [
			s["leagues"], s["clubs"], s["players"], s["coaches"],
		]
	else:
		status_label.text = "Hay un mundo importado, pero el archivo guardado no se pudo leer."
	status_label.remove_theme_color_override("font_color")
	clear_button.visible = true

func _on_pick_pressed() -> void:
	# En Android usamos el selector DEL SISTEMA (SAF) directo por
	# DisplayServer — es lo más fiable y ve Descargas/Drive/etc. Devuelve
	# una lista de rutas (content:// en Android); tomamos la primera.
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var filters := PackedStringArray(["*.json,*.txt ; Mundo (JSON)", "* ; Todos los archivos"])
		var ok := DisplayServer.file_dialog_show(
			"Elegir mundo (.json)", "", "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters,
			_on_native_file_result)
		if ok == OK:
			return
	# Fallback (desktop / sin native): el diálogo propio de Godot.
	file_dialog.popup_centered_ratio(0.9)

## Callback del selector nativo: (status: bool, selected_paths: PackedStringArray, ...)
func _on_native_file_result(status: bool, selected_paths: PackedStringArray, _filter_index: int = 0) -> void:
	if not status or selected_paths.is_empty():
		return
	_on_file_selected(selected_paths[0])

func _on_file_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		status_label.text = "No se pudo abrir el archivo."
		status_label.add_theme_color_override("font_color", Color(0.85, 0.35, 0.35))
		return
	var text := file.get_as_text()
	file.close()

	var raw: Variant = JSON.parse_string(text)
	var errors: Array = WorldImporter.validate(raw)
	if not errors.is_empty():
		status_label.text = "No se pudo importar:\n— %s" % "\n— ".join(errors)
		status_label.add_theme_color_override("font_color", Color(0.85, 0.35, 0.35))
		return

	DirAccess.make_dir_recursive_absolute("user://")
	var out := FileAccess.open(WorldFactory.IMPORTED_WORLD_PATH, FileAccess.WRITE)
	out.store_string(JSON.stringify(raw))
	out.close()
	WorldFactory.clear_imported_world_cache()

	var s: Dictionary = WorldImporter.summarize(raw)
	var msg := "¡Importado! %d ligas · %d clubes · %d jugadores · %d entrenadores.\n\nLas carreras NUEVAS van a usar este mundo." % [
		s["leagues"], s["clubs"], s["players"], s["coaches"],
	]
	# Nombres con codificación rota que no se pudo reparar sola (ver
	# WorldFactory.repair_imported_text/looks_corrupted) — avisar acá en vez
	# de dejarlos pasar en silencio (pedido de Wilber tras encontrar
	# "MÂS Monumental" en su propio archivo).
	var suspicious: Array[String] = WorldImporter.scan_suspicious_names(raw)
	if not suspicious.is_empty():
		msg += "\n\n⚠ %d nombre(s) con caracteres raros (revisá el .json):\n— %s" % [
			suspicious.size(), "\n— ".join(suspicious),
		]
	# Clubes con el MISMO nombre en ligas distintas (Nacional de Portugal y
	# de Uruguay, Fortaleza de Brasil y de Colombia...) son normales: cada
	# uno tiene su id, sus colores y su liga. Ya no se avisa como error.
	status_label.text = msg
	status_label.add_theme_color_override("font_color", Styles.GREEN if suspicious.is_empty() else Color(0.85, 0.65, 0.25))
	clear_button.visible = true

func _on_clear_pressed() -> void:
	clear_confirm.dialog_text = "¿Quitar el mundo importado? Las carreras nuevas van a volver a usar el generador de siempre.\n\nOJO: si tenés una carrera EN CURSO con este mundo importado, sus clubes/jugadores van a dejar de coincidir con lo que ya jugaste."
	clear_confirm.popup_centered()

func _on_clear_confirmed() -> void:
	if FileAccess.file_exists(WorldFactory.IMPORTED_WORLD_PATH):
		DirAccess.remove_absolute(WorldFactory.IMPORTED_WORLD_PATH)
	WorldFactory.clear_imported_world_cache()
	_refresh_status()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Start/Start.tscn")


## Los 3 pasos, a la vista (la pantalla era solo un texto y un botón).
func _steps_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var steps := [["1", "Prepará tu archivo", "Un .json con tus ligas, clubes, jugadores y entrenadores."],
		["2", "Elegilo acá", "Tocá \"Elegir archivo .json\" y buscalo en tu celular (Descargas, Documentos…)."],
		["3", "Empezá una carrera NUEVA", "Las carreras nuevas usan tu mundo. Las que ya tenés no cambian."]]
	for st in steps:
		var c := PanelContainer.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := Styles.card_flat(Color(0.1, 0.11, 0.14), 14)
		sb.border_width_top = 4
		sb.border_color = Styles.BLUE
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		c.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		var n := Label.new()
		n.text = String(st[0])
		n.add_theme_font_override("font", Styles.font_black())
		n.add_theme_font_size_override("font_size", 30)
		n.add_theme_color_override("font_color", Styles.BLUE)
		v.add_child(n)
		var t := Label.new()
		t.text = String(st[1])
		t.add_theme_font_override("font", Styles.font_semibold())
		t.add_theme_font_size_override("font_size", 16)
		v.add_child(t)
		var d := Label.new()
		d.text = String(st[2])
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 13)
		d.add_theme_color_override("font_color", Color(0.78, 0.8, 0.85))
		v.add_child(d)
		c.add_child(v)
		row.add_child(c)
	pick_button.get_parent().add_child(row)
	pick_button.get_parent().move_child(row, pick_button.get_index())
