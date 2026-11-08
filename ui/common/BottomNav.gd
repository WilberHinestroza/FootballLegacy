extends PanelContainer

## Barra de navegación inferior reutilizable — inspirada en el prototipo
## de Football Legacy (Plantilla / Torneos / Inicio / Carrera / Club),
## con la píldora verde detrás de la pestaña activa que se ve en sus
## capturas. Se auto-detecta la pestaña activa por la escena actual, así
## que cada pantalla solo instancia este componente sin pasarle nada
## (mismo principio de "estado vía Autoload, no parámetros de escena" que
## ya usa MatchState — aquí no hay estado, pero tampoco wiring manual).

const TABS := [
	{"label": "Plantilla", "icon": Icons.PXS_SQUAD, "scene": "res://scenes/Squad/Squad.tscn"},
	{"label": "Torneos", "icon": Icons.PXS_TROPHY, "scene": "res://scenes/WorldExplorer/WorldExplorer.tscn"},
	{"label": "Inicio", "icon": Icons.PXS_HOME, "scene": "res://scenes/Hub/Hub.tscn"},
	{"label": "Carrera", "icon": Icons.PXS_CAREER, "scene": "res://scenes/CareerMenu/CareerMenu.tscn"},
	{"label": "Club", "icon": Icons.PXS_CLUB, "scene": "res://scenes/ClubInfo/ClubInfo.tscn"},
]

@onready var row: HBoxContainer = $Row

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08)
	style.border_width_top = 2
	style.border_color = Color(0.2, 0.2, 0.2)
	# Zona segura del móvil (barra de gestos, esquinas redondeadas): sin esto la
	# parte baja de los botones quedaba tapada. Más un colchón fijo de 4 px.
	var inset := _safe_insets()
	# En el móvil, mínimo 16 px aunque Android no informe de nada: en horizontal
	# la barra de gestos y las esquinas redondeadas no cuentan como zona insegura
	# y los botones quedaban pegados al borde (Wilber, 8-nov: "les falta subir un
	# poco mas").
	var min_bottom: float = 16.0 if OS.has_feature("mobile") else 0.0
	style.content_margin_bottom = 4.0 + maxf(inset.y, min_bottom)
	style.content_margin_left = inset.x
	style.content_margin_right = inset.x
	add_theme_stylebox_override("panel", style)

	# La pantalla que CONTIENE la barra (dueño en el árbol), no
	# current_scene — mismo criterio que TopBar._screen().
	var current_path: String = ""
	var n: Node = owner
	while n != null and n.scene_file_path == "":
		n = n.owner
	if n != null:
		current_path = n.scene_file_path
	elif get_tree() != null and get_tree().current_scene != null:
		current_path = get_tree().current_scene.scene_file_path

	for tab in TABS:
		row.add_child(_build_tab(tab, tab["scene"] == current_path))

## Lo que tapa el sistema abajo (y) y a los lados (x), en píxeles del viewport.
func _safe_insets() -> Vector2:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector2.ZERO
	var vp := get_viewport().get_visible_rect().size
	var k: float = vp.y / float(win.y)
	var bottom: float = maxf(0.0, float(win.y - (safe.position.y + safe.size.y))) * k
	var side: float = maxf(float(safe.position.x), float(win.x - (safe.position.x + safe.size.x))) * k
	return Vector2(clampf(side, 0.0, 60.0), clampf(bottom, 0.0, 40.0))


## Cada pestaña es un botón envuelto en un margen — el margen es lo que
## deja que la píldora de fondo (corner_radius=999 sobre un botón corto)
## se vea como cápsula suelta en vez de un rectángulo pegado a las
## vecinas, igual que en el prototipo.
func _build_tab(tab: Dictionary, is_active: bool) -> Control:
	var wrap := MarginContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("margin_left", 4)
	wrap.add_theme_constant_override("margin_right", 4)
	wrap.add_theme_constant_override("margin_top", 8)
	wrap.add_theme_constant_override("margin_bottom", 8)

	var btn := Button.new()
	btn.text = tab["label"]
	btn.icon = load(tab["icon"]) as Texture2D
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.expand_icon = false
	# Fuente real 64x64 (ver addons/at-icons/node/*.import) topeada a 22px de
	# despliegue: nítida, pero deja sitio a la etiqueta debajo.
	btn.add_theme_constant_override("icon_max_width", 22)
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 58)
	# HORIZONTAL: barra baja, icono al lado del texto.
	var vp_w: Vector2 = get_viewport().get_visible_rect().size
	if vp_w.x > vp_w.y:
		btn.custom_minimum_size = Vector2(0, 50)
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_constant_override("icon_max_width", 30)
		btn.add_theme_font_size_override("font_size", 16)
	else:
		btn.add_theme_font_size_override("font_size", 12)

	if is_active:
		Styles.styled_button(btn, Styles.pill_filled(Styles.GREEN), Color.BLACK)
		# Activa SIN `disabled` (el estilo de deshabilitado la apagaba);
		# simplemente no tiene acción conectada.
	else:
		Styles.styled_button(btn, Styles.pill_filled(Color(0, 0, 0, 0)), Styles.GRAY_TEXT)
		btn.pressed.connect(_on_tab_pressed.bind(tab["scene"]))
	# Íconos pixel art (después de styled_button, que pisa los colores de
	# ícono): a color, los inactivos un poco apagados.
	if Icons.is_pixel(String(tab["icon"])):
		Icons.pixel_button_icon(btn, String(tab["icon"]), 32, 1.0 if is_active else 0.72)

	wrap.add_child(btn)
	return wrap

func _on_tab_pressed(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
