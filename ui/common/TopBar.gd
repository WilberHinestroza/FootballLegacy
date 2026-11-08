extends Node

## Cabecera compartida — el ÚNICO lugar donde vive la barra superior. Se
## instancia embebida en cada pantalla de navegación. Toda la parte visible
## vive en un CanvasLayer propio, así queda SIEMPRE fija arriba y encima del
## contenido, sin importar dónde esté en el árbol de la pantalla.

const DEFAULT_HEADER_COLOR := "#2b2b2b"
const DRAWER_WIDTH := 320.0
const DRAWER_ANIM_SECONDS := 0.2
const BAR_HEIGHT := 100.0

const NAV := [
	["Inicio", "res://scenes/Hub/Hub.tscn", Icons.PXS_HOME],
	["Fichajes", "res://scenes/Transfers/Transfers.tscn", Icons.PXS_TRANSFERS],
	["Calendario", "res://scenes/Calendar/Calendar.tscn", Icons.PXS_CALENDAR],
	["Noticias", "res://scenes/News/News.tscn", Icons.PXS_NEWS],
	["Explorar el mundo", "res://scenes/WorldExplorer/WorldExplorer.tscn", Icons.PXS_EXPLORE],
	["Buscar jugador", "res://scenes/PlayerSearch/PlayerSearch.tscn", Icons.PXS_SEARCH],
	["Selecciones", "res://scenes/Selections/Selections.tscn", Icons.PXS_NATIONAL],
]
const SETTINGS_SCENE := "res://scenes/Settings/Settings.tscn"

@onready var _bar: PanelContainer = $Layer/Bar
@onready var _header_margin: MarginContainer = $Layer/Bar/HeaderMargin
@onready var _menu_btn: Button = $Layer/Bar/HeaderMargin/HeaderHBox/MenuButton
@onready var _badge_panel: PanelContainer = $Layer/Bar/HeaderMargin/HeaderHBox/BadgePanel
@onready var _badge_label: Label = $Layer/Bar/HeaderMargin/HeaderHBox/BadgePanel/BadgeLabel
@onready var _club_label: Label = $Layer/Bar/HeaderMargin/HeaderHBox/NamesVBox/ClubNameLabel
@onready var _player_label: Label = $Layer/Bar/HeaderMargin/HeaderHBox/NamesVBox/PlayerNameLabel
@onready var _money_label: Label = $Layer/Bar/HeaderMargin/HeaderHBox/MoneyVBox/MoneyLabel
@onready var _day_label: Label = $Layer/Bar/HeaderMargin/HeaderHBox/MoneyVBox/DayLabel
@onready var _scrim: ColorRect = $Layer/DrawerScrim
@onready var _drawer: PanelContainer = $Layer/DrawerPanel
@onready var _drawer_vbox: VBoxContainer = $Layer/DrawerPanel/DrawerMargin/DrawerVBox

var _drawer_open: bool = false
## Franja "‹ Volver" (solo existe fuera del Hub) — se guarda la
## referencia para poder ocultarla mientras el cajón está abierto. Se
## crea DESPUÉS de Bar/DrawerScrim/DrawerPanel (que ya vienen en el
## .tscn) y `add_child` la deja última en la lista de hijos de `Layer`,
## así que sin esto quedaba dibujándose ENCIMA del cajón abierto en
## cualquier pantalla que no fuera el Hub (reporte de Wilber: "se
## superpone la barra del botón atrás con el menú hamburguesa").
var _back_bar: PanelContainer = null
var _bar_img: TextureRect = null   # foto de estadio detrás de la barra (si el asset está)
var _bar_tint: ColorRect = null    # lavado de color del club encima de la foto

func _ready() -> void:
	add_to_group("topbar")
	_landscape_compact()
	# Fondo con degradado oscuro para TODA pantalla de navegación (un solo
	# lugar) — el look del mockup de referencia.
	$BgLayer.add_child(Styles.screen_bg())

	# Foto de estadio detrás del contenido de la barra (donde va el menú
	# hamburguesa) — pedido explícito. Se recorta al rect de la barra y
	# queda por DEBAJO de HeaderMargin (que se dibuja último).
	var stadium: Texture2D = Styles.stadium_texture()
	if stadium != null:
		_bar.clip_contents = true
		_bar_img = TextureRect.new()
		_bar_img.texture = stadium
		# SCALE + IGNORE_SIZE: la textura llena el rect de la barra y NO
		# impone tamaño mínimo (si no, el PanelContainer tomaría los
		# 1408×3056 nativos y reventaría la escala de los botones). A 84px
		# de alto la foto queda como una textura ambiental difusa, sirve.
		_bar_img.stretch_mode = TextureRect.STRETCH_SCALE
		_bar_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bar_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar_img.modulate = Color(0.62, 0.62, 0.62, 1.0)
		_bar.add_child(_bar_img)
		_bar.move_child(_bar_img, 0)
		_bar_tint = ColorRect.new()
		_bar_tint.custom_minimum_size = Vector2.ZERO
		_bar_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.add_child(_bar_tint)
		_bar.move_child(_bar_tint, 1)

	# 9-oct (Wilber): hamburguesa a la DERECHA y "atrás" en su lugar, a la
	# izquierda (patrón estándar de Android) — reemplaza la franja "‹ Volver"
	# de ancho completo, que le robaba 46 px de alto a cada pantalla.
	add_to_group("nav_back_handlers")
	var hbox: HBoxContainer = _menu_btn.get_parent()
	hbox.move_child(_menu_btn, hbox.get_child_count() - 1)
	_drawer.anchor_left = 1.0
	_drawer.anchor_right = 1.0
	_menu_btn.icon = Icons.load_icon(Icons.MENU)
	_menu_btn.add_theme_constant_override("icon_max_width", 24)
	_menu_btn.pressed.connect(func(): _set_drawer_open(not _drawer_open))
	_scrim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_set_drawer_open(false))
	_drawer.offset_left = 0.0
	_drawer.offset_right = DRAWER_WIDTH
	# Cajón menos plano: panel oscuro con borde de acento a la derecha y
	# una sombra que lo separa del contenido (pedido de Wilber).
	var drawer_sb := Styles.card_flat(Color(0.12, 0.13, 0.16), 0)
	drawer_sb.border_width_left = 3
	drawer_sb.border_color = Styles.GOLD
	drawer_sb.shadow_color = Color(0, 0, 0, 0.5)
	drawer_sb.shadow_size = 14
	_drawer.add_theme_stylebox_override("panel", drawer_sb)

	# El cajón se desplaza: en horizontal no caben todas las entradas y
	# "Guardar y salir" quedaba fuera de la pantalla (Wilber, 8-nov).
	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dscroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	dscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dmargin: Control = _drawer_vbox.get_parent()
	dmargin.add_child(dscroll)
	_drawer_vbox.reparent(dscroll)
	_drawer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiScroll.make_touch(dscroll)
	for pair in NAV:
		_drawer_vbox.add_child(_drawer_button(String(pair[0]), String(pair[1]), Color.WHITE, pair[2]))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_drawer_vbox.add_child(spacer)
	_drawer_vbox.add_child(_drawer_divider())
	_drawer_vbox.add_child(_drawer_button("Ajustes", SETTINGS_SCENE, Color.WHITE, Icons.PXS_SETTINGS))
	_drawer_vbox.add_child(_drawer_button("Guardar y salir", "res://scenes/Start/Start.tscn", Styles.RED, Icons.PXS_EXIT))

	_build_back_button()
	_refresh()
	Audio.music_start()   # música ambiental del juego (idempotente)
	call_deferred("_fix_scrolls")
	call_deferred("_hide_screen_back_button")

## La pantalla que CONTIENE esta barra (su dueño en el árbol), no
## current_scene: así da bien también cuando la pantalla se instancia
## dentro de otra (herramientas de captura, transiciones).
func _screen() -> Node:
	var n: Node = owner
	while n != null and n.scene_file_path == "":
		n = n.owner
	return n if n != null else get_tree().current_scene

## Atrás del sistema / del botón: si el cajón está abierto, lo cierra.
func nav_back() -> bool:
	if _drawer_open:
		_set_drawer_open(false)
		return true
	return false

## Botón "‹" arriba a la IZQUIERDA (donde antes estaba la hamburguesa).
## Vuelve a la pantalla anterior real (Nav.back()). No existe en el Hub.
func _build_back_button() -> void:
	var cs: Node = _screen()
	var here: String = cs.scene_file_path if cs != null else ""
	if here == Nav.HOME:
		return
	var back := Button.new()
	back.name = "TopBackButton"
	back.custom_minimum_size = _menu_btn.custom_minimum_size if _menu_btn.custom_minimum_size.x > 0 else Vector2(48, 48)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.focus_mode = Control.FOCUS_NONE
	back.icon = Icons.load_icon(Icons.BACK)
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.add_theme_constant_override("icon_max_width", 24)
	Styles.styled_button(back, Styles.pill_filled(Color(0, 0, 0, 0.35)), Color.WHITE)
	back.pressed.connect(func(): Nav.back())
	var hbox: HBoxContainer = _menu_btn.get_parent()
	hbox.add_child(back)
	hbox.move_child(back, 0)

## La pantalla ya no pinta su propio "Volver al Hub" abajo — lo reemplaza
## la franja de arriba. Se esconde ese botón y se BAJA TODO el contenido
## (contenedor raíz + cada overlay) para que nada quede tapado por la franja.
func _hide_screen_back_button() -> void:
	await get_tree().process_frame
	var scene: Node = _screen()
	if scene == null:
		return
	# Título de pantalla con UNA sola tipografía en todo el juego (cada
	# pantalla traía su tamaño/peso).
	var t: Node = scene.find_child("TitleLabel", true, false)
	if t is Label:
		(t as Label).add_theme_font_override("font", Styles.font_black())
		(t as Label).add_theme_font_size_override("font_size", 24)
	var b: Node = scene.find_child("BackButton", true, false)
	if b is Button:
		(b as Button).visible = false

	# (Antes acá se bajaba todo el contenido +46 px para la franja
	# "‹ Volver"; con el atrás dentro de la barra ya no hace falta.)

## Recorre el árbol y junta los MarginContainer con un margin_top explícito
## de al menos 80 (el que las pantallas ponen para no chocar con el TopBar).
func _clear_bar_margins(node: Node, out: Array = []) -> Array:
	for c in node.get_children():
		if c is MarginContainer:
			var ov: Variant = (c as MarginContainer).get("theme_override_constants/margin_top")
			if ov != null and int(ov) >= 80:
				out.append(c)
		if c.get_child_count() > 0:
			_clear_bar_margins(c, out)
	return out

func _drawer_divider() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", 10)
	return s

func _fix_scrolls() -> void:
	await get_tree().process_frame
	var scene: Node = _screen()
	if scene != null:
		UiScroll.make_touch(scene)

func _drawer_button(label: String, scene_path: String, text_col: Color, icon_path: String = "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 54)
	b.text = "   " + label
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	if icon_path != "":
		b.icon = Icons.load_icon(icon_path)
		b.add_theme_constant_override("icon_max_width", 20)
	b.add_theme_constant_override("content_margin_left", 14)
	# Menos plano: relleno sólido con borde de acento tenue + hover claro.
	var normal := Styles.card_flat(Color(0.16, 0.17, 0.21), 10)
	normal.border_width_left = 3
	normal.border_color = Color(text_col, 0.35) if text_col != Color.WHITE else Color(Styles.GOLD, 0.5)
	var hover := Styles.card_flat(Color(0.22, 0.23, 0.28), 10)
	hover.border_width_left = 3
	hover.border_color = Styles.GOLD if text_col == Color.WHITE else text_col
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_color_override("font_color", text_col)
	b.add_theme_color_override("font_hover_color", text_col)
	b.add_theme_color_override("icon_normal_color", text_col)
	if Icons.is_pixel(icon_path):
		Icons.pixel_button_icon(b, icon_path, 32)
	b.pressed.connect(func():
		_set_drawer_open(false)
		if scene_path != _screen().scene_file_path:
			get_tree().change_scene_to_file(scene_path))
	return b

func _set_drawer_open(open: bool) -> void:
	_drawer_open = open
	# La franja "‹ Volver" (si esta pantalla la tiene) se esconde mientras
	# el cajón está abierto — si no, quedaba dibujada ENCIMA del cajón
	# (se agrega después en el árbol de Layer, ver comentario de _back_bar).
	if _back_bar != null:
		_back_bar.visible = not open
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC)
	if open:
		_drawer.offset_left = 0.0
		_drawer.offset_right = DRAWER_WIDTH
		_scrim.modulate.a = 0.0
		_scrim.visible = true
		_drawer.visible = true
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(_drawer, "offset_left", -DRAWER_WIDTH, DRAWER_ANIM_SECONDS)
		tw.tween_property(_drawer, "offset_right", 0.0, DRAWER_ANIM_SECONDS)
		tw.tween_property(_scrim, "modulate:a", 1.0, DRAWER_ANIM_SECONDS)
	else:
		# Ocultar el scrim YA (que no siga comiendo toques mientras se anima).
		_scrim.visible = false
		tw.set_ease(Tween.EASE_IN)
		tw.tween_property(_drawer, "offset_left", 0.0, DRAWER_ANIM_SECONDS)
		tw.tween_property(_drawer, "offset_right", DRAWER_WIDTH, DRAWER_ANIM_SECONDS)
		await tw.finished
		if not _drawer_open:
			_drawer.visible = false

func _refresh() -> void:
	var player: PlayerData = SaveManager.load_player()
	var world: Dictionary = WorldTickEngine.world
	if world.is_empty():
		world = WorldFactory.build(SaveManager.load_world_seed())
	var club: ClubData = null
	if player != null and player.club_id != "":
		club = WorldFactory.find_club(world, player.club_id)

	var col: Color = Color(club.primary_color_hex) if (club != null and not club.primary_color_hex.is_empty()) else Color(DEFAULT_HEADER_COLOR)
	var text_col: Color = Styles.contrasting_text_color(col)

	if _bar_img != null:
		# Con la foto detrás: base oscura + franja de color del club abajo
		# (identidad) + lavado tenue del club encima de la foto. Texto
		# siempre blanco con sombra para que se lea sobre la imagen.
		var base := Styles.card_flat(Color(0.05, 0.06, 0.08), 0)
		base.border_width_bottom = 3
		base.border_color = col
		_bar.add_theme_stylebox_override("panel", base)
		_bar_tint.color = Color(col, 0.26)
		text_col = Color(0.96, 0.97, 1.0)
	else:
		_bar.add_theme_stylebox_override("panel", Styles.card(col, 0))

	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		_menu_btn.add_theme_color_override(state, text_col)

	# Escudo modular del club (Crest.gd) en vez del círculo con la inicial.
	_badge_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_badge_label.visible = false
	for ch in _badge_panel.get_children():
		if ch != _badge_label:
			_badge_panel.remove_child(ch)
			ch.queue_free()
	if club != null:
		var sec: Color = Color(club.secondary_color_hex) if not club.secondary_color_hex.is_empty() else Color.TRANSPARENT
		var crest := Styles.build_club_badge(col, club.short_name, 48, sec, club.club_id)
		crest.name = "Crest"
		_badge_panel.add_child(crest)
	for lbl in [_badge_label, _club_label, _player_label, _money_label, _day_label]:
		lbl.add_theme_color_override("font_color", text_col)
		if _bar_img != null:
			lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
			lbl.add_theme_constant_override("shadow_offset_x", 0)
			lbl.add_theme_constant_override("shadow_offset_y", 1)
			lbl.add_theme_constant_override("shadow_outline_size", 3)
	_player_label.add_theme_color_override("font_color", Color(text_col, 0.78))
	_day_label.add_theme_color_override("font_color", Color(text_col, 0.78))

	_club_label.text = club.club_name if club != null else "Sin club"
	_player_label.text = player.player_name if player != null else ""
	# El dinero CUENTA al cambiar (P1b #13): verde si subió, rojo si bajó.
	var bal: int = player.balance if player != null else 0
	if _last_balance >= 0 and _last_balance != bal and not Preferences.reduce_motion:
		Juice.count_up(_money_label, _last_balance, bal, 0.9, func(v): return CurrencyFormat.format(v))
		var flash: Color = Color(0.45, 1.0, 0.5) if bal > _last_balance else Color(1.0, 0.45, 0.4)
		_money_label.modulate = flash
		_money_label.create_tween().tween_property(_money_label, "modulate", Color.WHITE, 1.1)
		Juice.pop(_money_label, 1.15)
	else:
		_money_label.text = CurrencyFormat.format(bal)
	_last_balance = bal
	_day_label.text = "Día %d" % WorldTickEngine.day_in_season()

static var _last_balance: int = -1

## Para que la pantalla (p.ej. el Hub tras pasar un día) refresque la barra.
func refresh() -> void:
	if is_node_ready():
		_refresh()



## HORIZONTAL (FootballLegacy H): la barra baja de 100 a 60 px y cada
## pantalla recupera esos 40 px (el margin_top >= 80 que dejaba para no
## quedar tapada, ver _clear_bar_margins).
func _landscape_compact() -> void:
	await get_tree().process_frame
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= vp.y:
		return
	var bar := $Layer/Bar as Control
	bar.offset_bottom = BAR_HEIGHT - 40.0
	var hm := bar.get_node_or_null("HeaderMargin") as MarginContainer
	if hm != null:
		for side in ["top", "bottom"]:
			var v: Variant = hm.get("theme_override_constants/margin_" + side)
			if v != null:
				hm.add_theme_constant_override("margin_" + side, maxi(int(v) - 14, 4))
	var badge := bar.find_child("BadgePanel", true, false) as Control
	if badge != null:
		badge.custom_minimum_size = Vector2(40, 40)
	var scene: Node = _screen()
	if scene == null:
		return
	for m in _clear_bar_margins(scene):
		var cur: int = int(m.get("theme_override_constants/margin_top"))
		m.add_theme_constant_override("margin_top", cur - 40)
