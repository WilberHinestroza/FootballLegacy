extends Control

## Creador / editor de avatar. Estilo galería: preview grande arriba,
## fila de CATEGORÍAS, y una GRILLA de miniaturas (se ve cada opción, no
## botones ◀ ▶). Para las partes que se pueden colorear, tira de colores.
##
## Dos modos (CharacterDraft.edit_mode):
##   crear  → guarda en CharacterDraft.avatar y vuelve a CharacterCreation.
##   editar → guarda en PlayerData.avatar y vuelve a Mi Perfil.

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var preview_holder: CenterContainer = $Margin/VBox/PreviewHolder
@onready var random_button: Button = $Margin/VBox/RandomButton
@onready var body: VBoxContainer = $Margin/VBox/Scroll/Body
@onready var scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var next_button: Button = $Margin/VBox/NextButton

## Categorías del editor (pixel art, ver Avatar.gd): [key, etiqueta,
## tipo, paleta]. "style" = grilla de miniaturas (peinado/barba,
## Avatar.options_for) + tira de color; "color" = solo tira de color.
## `paleta` = clave de Avatar.TINTS (la barba sigue el color del pelo).
const CATS := [
	["hair", "Peinado", "style", "hair"],
	["face", "Barba", "style", "hair"],
	# 9-oct: rasgos de la cara (sin color propio — siguen el tono de piel).
	["nose", "Nariz", "feature", "base"],
	["ears", "Orejas", "feature", "base"],
	["rasgo", "Rasgos", "feature", "base"],
	["base", "Piel", "color", "base"],
	["clothing", "Camiseta", "color", "clothing"],
	["shorts", "Short", "color", "shorts"],
	["background", "Fondo", "color", "background"],
]

var _edit_mode: bool = false
var _cfg: Dictionary = {}
var _active: int = 0
var _preview_frame: PanelContainer

func _ready() -> void:
	var bg := Styles.screen_bg()
	add_child(bg)
	move_child(bg, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# Bug visual real (auditoría ronda 3): faltaba el deadzone táctil.
	UiScroll.make_touch(scroll)

	_edit_mode = CharacterDraft.edit_mode
	if _edit_mode:
		var p := SaveManager.load_player()
		_cfg = Avatar.from_legacy(p.avatar) if (p != null and not p.avatar.is_empty()) else Avatar.random_config(randi())
		title_label.text = "Edita tu jugador"
	elif CharacterDraft.has_avatar():
		_cfg = Avatar.from_legacy(CharacterDraft.avatar)
	else:
		_cfg = Avatar.random_config(randi())
	# Un config puede venir "solo skin" del import — asegurar que tenga
	# todas las capas para poder editarlo.
	if not _cfg.has("hair"):
		_cfg.merge(Avatar.random_config(randi()), false)

	_preview_frame = PanelContainer.new()
	_preview_frame.custom_minimum_size = Vector2(250, 250)   # 9-oct: más grande
	var fstyle := Styles.card_flat(Color(1, 1, 1, 0.06), 18)
	fstyle.set_border_width_all(3)
	fstyle.border_color = Styles.GOLD
	_preview_frame.add_theme_stylebox_override("panel", fstyle)
	var pcn := CenterContainer.new()
	pcn.name = "PC"
	_preview_frame.add_child(pcn)
	preview_holder.add_child(_preview_frame)

	random_button.icon = Icons.load_icon(Icons.DICE)
	random_button.add_theme_constant_override("icon_max_width", 20)
	Styles.styled_button(random_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	random_button.pressed.connect(func():
		_cfg = Avatar.random_config(randi())
		_build())

	next_button.text = "Guardar" if _edit_mode else "Siguiente: test de personalidad"
	Styles.styled_button(next_button, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	next_button.pressed.connect(_on_next)

	# Botón de VOLVER explícito (antes no había y el back del sistema dejaba
	# la creación a medias — bug reportado por Wilber).
	var back_btn := Button.new()
	back_btn.text = "‹  Cancelar" if _edit_mode else "‹  Volver"
	back_btn.custom_minimum_size = Vector2(0, 44)
	back_btn.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(back_btn, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	back_btn.pressed.connect(_on_back)
	var vbox := $Margin/VBox as VBoxContainer
	vbox.add_child(back_btn)
	vbox.move_child(back_btn, title_label.get_index() + 1)
	_landscape_split()

	_build()

## Volver sin guardar. En modo EDICIÓN vuelve a Mi Perfil (y apaga
## edit_mode); en creación, a la pantalla de identidad.
## Nav no maneja el atrás del sistema acá: lo hace _notification (abajo).
func handles_system_back() -> bool:
	return true

func _on_back() -> void:
	if _edit_mode:
		CharacterDraft.edit_mode = false
		get_tree().change_scene_to_file("res://scenes/PlayerProfile/PlayerProfile.tscn")
	else:
		# Volver a la IDENTIDAD (no al test). Guardamos el avatar tal cual
		# para no perder lo que llevaba hecho, pero NO marcamos avatar_done:
		# así CharacterCreation reabre el formulario de identidad (con los
		# datos ya puestos), en vez de saltar al test de personalidad.
		CharacterDraft.avatar = _cfg.duplicate(true)
		CharacterDraft.avatar_done = false
		get_tree().change_scene_to_file("res://scenes/CharacterCreation/CharacterCreation.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()

## Recorte del avatar (lienzo de 48) por categoría.
const _CAT_REGION := {
	"hair": Rect2i(14, 0, 20, 10), "face": Rect2i(15, 8, 18, 10), "nose": Rect2i(17, 6, 14, 9),
	"ears": Rect2i(12, 3, 24, 12), "rasgo": Rect2i(14, 3, 20, 14),
}

func _cat_icon(i: int) -> Texture2D:
	var key: String = String(CATS[i][0])
	if _CAT_REGION.has(key):
		var cfg: Dictionary = _cfg.duplicate()
		cfg["full"] = true
		var at := AtlasTexture.new()
		at.atlas = Avatar.compose(cfg)
		at.region = Rect2(_CAT_REGION[key])
		# ×3 entero para que se lea (pixel art nítido).
		var img: Image = at.get_image()
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		return ImageTexture.create_from_image(img)
	# Categorías de color: círculo del tono actual.
	var hex: String = String(_cfg.get("tint_" + String(CATS[i][3]), "#888888"))
	var col := Color(hex)
	var n := 28
	var img2 := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(n):
		for x in range(n):
			var d: float = Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length()
			if d <= n * 0.5 - 0.5:
				img2.set_pixel(x, y, col if d < n * 0.5 - 2.5 else col.darkened(0.45))
	return ImageTexture.create_from_image(img2)

func _build() -> void:
	for c in body.get_children():
		c.queue_free()

	# --- Categorías (grilla pareja de 4 columnas, 9-oct: antes eran chips
	# chiquitos de anchos distintos que se amontonaban) ---
	var flow := GridContainer.new()
	flow.columns = 4
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for i in range(CATS.size()):
		var b := Button.new()
		b.text = String(CATS[i][1])
		b.custom_minimum_size = Vector2(0, 78)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		# Ícono = la pieza REAL de tu avatar (9-oct, P1): tu pelo, tu barba,
		# tu nariz... y un círculo del color elegido en las de color.
		b.icon = _cat_icon(i)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = false
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if i == _active:
			Styles.styled_button(b, Styles.pill_filled(Styles.GOLD), Color.BLACK)
		else:
			Styles.styled_button(b, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
		var idx := i
		b.pressed.connect(func():
			_active = idx
			_build())
		flow.add_child(b)
	body.add_child(flow)

	var key: String = String(CATS[_active][0])
	var kind: String = String(CATS[_active][2])
	var tint_key: String = String(CATS[_active][3])

	# --- Colores ---
	# La camiseta y el short por defecto toman los colores del club
	# (Avatar.user_kit_hex / user_kit2_hex). Elegir uno a mano los "fija"
	# (clothing_locked); el botón los suelta.
	if key == "clothing" or key == "shorts":
		var locked: bool = bool(_cfg.get("clothing_locked", false))
		var kb := Button.new()
		kb.text = "Colores del club (auto)" if not locked else "Usar los colores de mi club"
		kb.focus_mode = Control.FOCUS_NONE
		if locked:
			Styles.styled_button(kb, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
		else:
			Styles.styled_button(kb, Styles.pill_filled(Styles.GOLD), Color.BLACK)
		kb.pressed.connect(func():
			_cfg.erase("clothing_locked")
			_cfg.erase("tint_clothing")
			_cfg.erase("tint_shorts")
			_build())
		body.add_child(kb)
	var color_title: String = "Color de pelo y barba" if kind == "style" else ("Tono de piel" if kind == "feature" else "Color de " + String(CATS[_active][1]).to_lower())
	body.add_child(Styles.section_label(color_title))
	var pal_row := HFlowContainer.new()
	pal_row.add_theme_constant_override("h_separation", 6)
	pal_row.add_theme_constant_override("v_separation", 6)
	var cur_tint: String = Avatar.tint_of(_cfg, tint_key)
	for hex in Avatar.TINTS[tint_key]["palette"]:
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(38, 38)
		sw.focus_mode = Control.FOCUS_NONE
		var sb := Styles.card_flat(Color(hex), 8)
		sb.set_border_width_all(3)
		sb.border_color = Color.WHITE if cur_tint == String(hex) else Color(0, 0, 0, 0.3)
		sw.add_theme_stylebox_override("normal", sb)
		sw.add_theme_stylebox_override("hover", sb)
		sw.add_theme_stylebox_override("pressed", sb)
		var h := String(hex)
		sw.pressed.connect(func():
			_cfg = Avatar.set_tint(_cfg, tint_key, h)
			if tint_key == "clothing" or tint_key == "shorts":
				# Elegido a mano: no lo pisa el club. Se fijan LOS DOS colores
				# del kit para que el otro no quede "a medias" con el del club.
				var pv: Dictionary = Avatar.preview_config(_cfg)
				_cfg["clothing_locked"] = true
				for k in ["clothing", "shorts"]:
					if not _cfg.has("tint_" + k) and pv.has("tint_" + k):
						_cfg["tint_" + k] = pv["tint_" + k]
			_build())
		pal_row.add_child(sw)
	body.add_child(pal_row)

	# --- Grilla de miniaturas (peinado / barba) ---
	if kind == "style" or kind == "feature":
		body.add_child(Styles.section_label("Elige " + String(CATS[_active][1]).to_lower()))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		var cur_val: String = String(_cfg.get(key, "rapado" if key == "hair" else ""))
		for opt in Avatar.options_for(key):
			grid.add_child(_thumb(key, String(opt), String(opt) == cur_val))
		body.add_child(grid)

	_refresh_preview()

func _thumb(key: String, opt: String, selected: bool) -> Control:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(0, 104)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.focus_mode = Control.FOCUS_NONE
	var sb := Styles.card_flat(Color(1, 1, 1, 0.05) if not selected else Color(1, 0.85, 0.3, 0.22), 8)
	sb.set_border_width_all(2)
	sb.border_color = Styles.GOLD if selected else Color(1, 1, 1, 0.10)
	tile.add_theme_stylebox_override("normal", sb)
	tile.add_theme_stylebox_override("hover", sb)
	tile.add_theme_stylebox_override("pressed", sb)

	var thumb_cfg := Avatar.preview_config(_cfg)
	thumb_cfg[key] = opt
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(Avatar.build(thumb_cfg, 64))
	col.add_child(cc)
	var lbl := Label.new()
	lbl.text = Avatar.option_label(key, opt)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	lbl.add_theme_color_override("font_color", Styles.GOLD if selected else Styles.GRAY_TEXT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(lbl)
	tile.add_child(col)
	tile.pressed.connect(func():
		_cfg[key] = opt
		_build())
	return tile

func _refresh_preview() -> void:
	var pc: Node = _preview_frame.get_node("PC")
	for c in pc.get_children():
		c.queue_free()
	pc.add_child(Avatar.build_full(Avatar.preview_config(_cfg), 240))

func _on_next() -> void:
	if _edit_mode:
		var p := SaveManager.load_player()
		if p != null:
			p.avatar = _cfg.duplicate(true)
			SaveManager.save_player(p)
		CharacterDraft.edit_mode = false
		get_tree().change_scene_to_file("res://scenes/PlayerProfile/PlayerProfile.tscn")
	else:
		CharacterDraft.avatar = _cfg.duplicate(true)
		CharacterDraft.avatar_done = true
		get_tree().change_scene_to_file("res://scenes/CharacterCreation/CharacterCreation.tscn")


## HORIZONTAL (FootballLegacy H): el jugador a la izquierda y las opciones
## a la derecha, así se ve el cambio mientras elegís.
func _landscape_split() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= vp.y:
		return
	var vbox := $Margin/VBox as VBoxContainer
	var m := $Margin as MarginContainer
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 14)
	# Encabezado en UNA fila: [‹ Volver]  Personaliza tu jugador  [pasos].
	var back_btn := vbox.get_child(title_label.get_index() + 1) as Button
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	vbox.add_child(head)
	vbox.move_child(head, title_label.get_index())
	back_btn.reparent(head)
	back_btn.custom_minimum_size = Vector2(130, 40)
	title_label.reparent(head)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var steps := CreationSteps.make(1)
	head.add_child(steps)
	if _edit_mode:
		steps.visible = false
	next_button.custom_minimum_size = Vector2(0, 50)
	var cols := HBoxContainer.new()
	cols.name = "Cols"
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 18)
	vbox.add_child(cols)
	vbox.move_child(cols, scroll.get_index())
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 300
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 12)
	cols.add_child(left)
	preview_holder.reparent(left)
	random_button.reparent(left)
	scroll.reparent(cols)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
