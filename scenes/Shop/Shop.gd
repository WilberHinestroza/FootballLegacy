extends Control

## Tienda de consumibles (ver ShopEngine.gd) — pedido explícito, porte de
## Football Legacy: "cuida tu cuerpo entre partidos". Comprar y usar/armar;
## se guarda al momento (sin carrito, mismo criterio que Lifestyle).
##
## Arriba, la sección ESTILO (9-oct, schema v31): ropa y accesorios en
## pixel art (Avatar.OUTFITS / ACCESSORIES, precios en ShopEngine.
## COSMETIC_PRICE). Cada prenda se previsualiza puesta en TU jugador.

const _COLORS := {
	"RED": Styles.RED, "GOLD": Styles.GOLD, "BLUE": Styles.BLUE,
	"PURPLE": Styles.PURPLE, "GREEN": Styles.GREEN,
}

@onready var balance_label: Label = $Root/Scroll/Margin/VBox/BalanceLabel
@onready var message_label: Label = $Root/Scroll/Margin/VBox/MessageLabel
@onready var catalog_box: VBoxContainer = $Root/Scroll/Margin/VBox/CatalogBox
@onready var inventory_box: VBoxContainer = $Root/Scroll/Margin/VBox/InventoryBox
@onready var back_button: Button = $Root/Scroll/Margin/VBox/BackButton

var _player: PlayerData = null

var _style_box: VBoxContainer
var _wardrobe_pager: Pager
var _wardrobe_tab: String = "camisa"   # camisa | chaqueta | bottom | shoes | acc | feet
## Pestañas principales (9-oct, pedido de Wilber): "estilo" (ropa,
## accesorios, guayos) | "consumibles" (botiquines y suplementos). Antes
## todo iba en un solo scroll larguísimo.
var _section: String = "estilo"
## Prenda que te estás probando en el probador (horizontal). "" = tu ropa.
var _try_on: String = ""
var _main_tabs: HBoxContainer
const _WARDROBE_ROWS_PER_PAGE := 3

func _ready() -> void:
	WorldTickEngine.load_runtime()
	_player = SaveManager.load_player()
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn"))
	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	message_label.visible = false
	_style_box = VBoxContainer.new()
	_style_box.add_theme_constant_override("separation", 10)
	var vbox := catalog_box.get_parent()
	vbox.add_child(_style_box)
	vbox.move_child(_style_box, catalog_box.get_index())
	_wardrobe_pager = Pager.new()
	_main_tabs = HBoxContainer.new()
	_main_tabs.add_theme_constant_override("separation", 8)
	vbox.add_child(_main_tabs)
	vbox.move_child(_main_tabs, _style_box.get_index())
	var sc := $Root/Scroll as ScrollContainer
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_render()

## Cabecera HÉROE (P2, 9-oct — misma pasada que Plantilla/Entrenar).
var _hero: Control = null
func _render_hero() -> void:
	if _hero != null and is_instance_valid(_hero):
		_hero.queue_free()
	var vb := balance_label.get_parent()
	var title := vb.get_node_or_null("TitleLabel")
	if title != null:
		(title as Control).visible = false
	balance_label.visible = false
	var icon := Icons.make_rect(Icons.PX_SHOP, 60)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var owned_items: int = 0
	for k in _player.consumables:
		owned_items += int(_player.consumables[k])
	var chips: Array = [["%d prendas" % _player.cosmetics_owned.size(), Styles.PURPLE], ["%d consumibles" % owned_items, Styles.GREEN]]
	_hero = UiKit.hero(Styles.PURPLE, icon, "Tienda", "Saldo  %s" % CurrencyFormat.format(_player.balance), chips)
	vb.add_child(_hero)
	vb.move_child(_hero, balance_label.get_index())

func _render() -> void:
	for child in catalog_box.get_children():
		child.queue_free()
	for child in inventory_box.get_children():
		child.queue_free()
	if _player == null:
		balance_label.text = "Sin jugador."
		return

	balance_label.text = "Saldo:  %s" % CurrencyFormat.format(_player.balance)
	_render_hero()
	_render_main_tabs()
	var style_on: bool = _section == "estilo"
	_style_box.visible = style_on
	catalog_box.visible = not style_on
	inventory_box.visible = not style_on
	if style_on:
		_render_style()
		UiScroll.pad_bottom(_style_box)
		return

	if get_viewport_rect().size.x > get_viewport_rect().size.y:
		_render_consumables_land()
		return
	catalog_box.add_child(Styles.section_label("CATÁLOGO"))
	var cat_pager := Pager.new()
	catalog_box.add_child(cat_pager)
	cat_pager.show_items(ShopEngine.CATALOG, 4, _catalog_card)

	inventory_box.add_child(Styles.section_label("TU INVENTARIO"))
	if _player.consumables.is_empty():
		var empty := Label.new()
		empty.text = "Todavía no compraste nada."
		UiKit.empty_icon(empty, Icons.PX_SHOP)
		empty.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		inventory_box.add_child(empty)
	else:
		var inv: Array = []
		for id in _player.consumables:
			inv.append({"id": String(id), "count": int(_player.consumables[id])})
		var inv_pager := Pager.new()
		inventory_box.add_child(inv_pager)
		inv_pager.show_items(inv, 4, func(item): return _inventory_card(item["id"], item["count"]))
	UiScroll.pad_bottom(inventory_box)

func _render_main_tabs() -> void:
	for c in _main_tabs.get_children():
		c.queue_free()
	for t in [["estilo", "Estilo"], ["consumibles", "Consumibles"]]:
		var b := Button.new()
		b.text = String(t[1])
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", Styles.font_semibold())
		if _section == t[0]:
			Styles.tab(b, true)
		else:
			Styles.tab(b, false)
		var sid: String = String(t[0])
		b.pressed.connect(func():
			_section = sid
			_render())
		_main_tabs.add_child(b)

# --- Estilo (guardarropa) ---

func _render_style() -> void:
	if _wardrobe_pager.get_parent() != null:
		_wardrobe_pager.get_parent().remove_child(_wardrobe_pager)
	for child in _style_box.get_children():
		child.queue_free()
	var land: bool = get_viewport_rect().size.x > get_viewport_rect().size.y
	var hint := Label.new()
	hint.text = "Lo que te pongas se ve en tu perfil, el Hub y las charlas. En la cancha usás el kit del club, pero tus GUAYOS sí se ven en la cancha y en los festejos."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	hint.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)

	var preview := PanelContainer.new()
	preview.add_theme_stylebox_override("panel", Styles.card_flat(Color(1, 1, 1, 0.05), 16))
	var pc := CenterContainer.new()
	var pcfg: Dictionary = _cfg_with(_try_on) if (land and _try_on != "") else Avatar.config_for_player(_player, WorldTickEngine.world_seed)
	pc.add_child(Avatar.build_full(pcfg, 250 if land else 168))
	preview.add_child(pc)
	# HORIZONTAL = PROBADOR: tu jugador grande a la izquierda, prendas a la
	# derecha. Lo de abajo se agrega a `dest` (la columna derecha).
	var dest: Container = _style_box
	if land:
		if _hero != null and is_instance_valid(_hero):
			_hero.visible = false
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 16)
		_style_box.add_child(cols)
		var left := VBoxContainer.new()
		left.custom_minimum_size.x = 330
		left.add_theme_constant_override("separation", 8)
		cols.add_child(left)
		var psb := Styles.card_flat(Color(0.12, 0.08, 0.18, 0.95), 18)
		psb.border_width_bottom = 6
		psb.border_color = Styles.PURPLE
		preview.add_theme_stylebox_override("panel", psb)
		preview.custom_minimum_size.y = 300
		left.add_child(preview)
		var bal := Label.new()
		bal.text = "Saldo  %s   ·   %d prendas" % [CurrencyFormat.format(_player.balance), _player.cosmetics_owned.size()]
		bal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bal.add_theme_font_override("font", Styles.font_semibold())
		bal.add_theme_color_override("font_color", Styles.GOLD)
		left.add_child(bal)
		if _try_on != "":
			var tl := Label.new()
			tl.text = "Probándote: %s" % Avatar.label_of(_try_on)
			tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tl.add_theme_font_override("font", Styles.font_semibold())
			tl.add_theme_color_override("font_color", Color("#c9a7ff"))
			left.add_child(tl)
			var back := Button.new()
			back.text = "Volver a mi ropa"
			back.focus_mode = Control.FOCUS_NONE
			back.custom_minimum_size = Vector2(0, 34)
			Styles.styled_button(back, Styles.pill_outlined(Styles.PURPLE), Color.WHITE)
			back.pressed.connect(func():
				_try_on = ""
				_render())
			left.add_child(back)
		else:
			left.add_child(hint)
		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_theme_constant_override("separation", 10)
		cols.add_child(right)
		dest = right
	else:
		_style_box.add_child(hint)
		_style_box.add_child(preview)

	# Por tipo de prenda (10-oct, Wilber): dos filas de 3.
	var tabs := GridContainer.new()
	tabs.columns = 3
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	for t in [["camisa", "Camisas"], ["chaqueta", "Chaquetas"], ["bottom", "Pantalones"],
			["shoes", "Zapatos"], ["acc", "Accesorios"], ["feet", "Guayos"]]:
		var b := Button.new()
		b.text = String(t[1])
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		if _wardrobe_tab == t[0]:
			Styles.tab(b, true, true)
		else:
			Styles.tab(b, false, true)
		var tab_id: String = String(t[0])
		b.pressed.connect(func():
			_wardrobe_tab = tab_id
			_wardrobe_pager.goto_page(0)
			_render())
		tabs.add_child(b)
	dest.add_child(tabs)

	# Filas de a 2 prendas (grilla de 2 columnas dentro del Pager).
	var src: Array = []
	match _wardrobe_tab:
		"camisa", "chaqueta":
			for t in Avatar.TOPS:
				if String(t["cat"]) == _wardrobe_tab:
					src.append({"id": "top_" + String(t["src"])})
		"bottom":
			for t in Avatar.BOTTOMS:
				src.append({"id": "bot_" + String(t["src"])})
		"shoes":
			src = Avatar.ACCESSORIES.filter(func(a): return a["slot"] == "acc_shoes")
		"acc":
			src = Avatar.ACCESSORIES.filter(func(a): return a["slot"] != "acc_feet" and a["slot"] != "acc_shoes")
		_:
			src = Avatar.ACCESSORIES.filter(func(a): return a["slot"] == "acc_feet")
	var per_row: int = 3 if land else 2
	var rows: Array = []
	for i in range(0, src.size(), per_row):
		rows.append(src.slice(i, i + per_row))
	dest.add_child(_wardrobe_pager)
	_wardrobe_pager.show_items(rows, _WARDROBE_ROWS_PER_PAGE, _wardrobe_row, true)

func _wardrobe_row(pair: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for it in pair:
		row.add_child(_wardrobe_tile(String(it["id"])))
	var want: int = 3 if get_viewport_rect().size.x > get_viewport_rect().size.y else 2
	for _i in range(pair.size(), want):
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
	return row

func _wardrobe_tile(id: String) -> PanelContainer:
	var owned: bool = ShopEngine.owns_cosmetic(_player, id)
	var equipped: bool = ShopEngine.is_equipped(_player, id)
	var price: int = ShopEngine.cosmetic_price(_player, id)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := Styles.card_flat(Color(1, 0.85, 0.3, 0.14) if equipped else Color(1, 1, 1, 0.05), 12)
	st.set_border_width_all(2)
	st.border_color = Styles.GOLD if equipped else Color(1, 1, 1, 0.08)
	panel.add_theme_stylebox_override("panel", st)
	var m := _margin()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)

	var cfg: Dictionary = Avatar.config_for_player(_player, WorldTickEngine.world_seed)
	var slot: String = Avatar.slot_of(id)
	if slot == "top" or slot == "bottom":
		# Vista previa de la prenda suelta sobre lo que ya llevás puesto (un
		# conjunto entero se muestra desarmado en sus dos mitades).
		var whole: String = String(cfg.get("outfit", ""))
		if whole != "":
			cfg.erase("outfit")
			cfg["top"] = whole
			cfg["bottom"] = Avatar.bottom_src_for(whole)
		cfg[slot] = Avatar.piece_src(id)
	elif slot == "acc_shoes":
		# Los zapatos de calle se ven con ropa de calle.
		if not Avatar.wears_street(cfg):
			cfg["outfit"] = "jeans"
		cfg[slot] = id
	elif slot == "acc_feet":
		Avatar.strip_street(cfg)   # los guayos, con el kit
		cfg[slot] = id
	else:
		cfg[slot] = id
	var cc := CenterContainer.new()
	if slot == "acc_feet" or slot == "acc_shoes":
		# Guayos: zoom a los pies (en el cuerpo entero apenas se veían).
		cc.add_child(Avatar.build_feet(cfg, 132))
	elif slot in ["acc_head", "acc_eyes", "acc_ears", "acc_neck"]:
		# Gorras, lentes, pendientes, cadenas, bufanda: primer plano (de cuerpo
		# entero, a este tamaño, apenas se distinguían)
		cc.add_child(Avatar.build(cfg, 96))
	else:
		cc.add_child(Avatar.build_full(cfg, 96))
	col.add_child(cc)

	# Guayos: logo + nombre de la marca (BootBrands, 9-oct).
	var brand: Dictionary = BootBrands.of_model(id)
	if not brand.is_empty():
		var brow := HBoxContainer.new()
		brow.alignment = BoxContainer.ALIGNMENT_CENTER
		brow.add_theme_constant_override("separation", 4)
		brow.add_child(BootBrands.logo_rect(brand, 22))
		var bl := Label.new()
		bl.text = String(brand["name"]).to_upper()
		bl.add_theme_font_override("font", Styles.font_black())
		bl.add_theme_font_size_override("font_size", 12)
		bl.add_theme_color_override("font_color", Color(String(brand["color"])))
		brow.add_child(bl)
		col.add_child(brow)
	var name_lbl := Label.new()
	name_lbl.text = Avatar.label_of(id)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_override("font", Styles.font_semibold())
	name_lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	col.add_child(name_lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 36)
	btn.focus_mode = Control.FOCUS_NONE
	if ShopEngine.is_gold_cosmetic(id) and not owned:
		# Edición dorada bloqueada: el logro que la desbloquea.
		var lock := HBoxContainer.new()
		lock.alignment = BoxContainer.ALIGNMENT_CENTER
		lock.add_theme_constant_override("separation", 4)
		var gi := Icons.make_rect("res://assets/ui/gold_edition.png", 22)
		gi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		lock.add_child(gi)
		var nl := Label.new()
		nl.text = String(GoldEditions.rule(Avatar.piece_src(id) if Avatar.piece_src(id) != "" else id).get("need", "Logro"))
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(110, 0)
		nl.add_theme_font_size_override("font_size", 11)
		nl.add_theme_color_override("font_color", Styles.GOLD)
		lock.add_child(nl)
		col.add_child(lock)
		cc.modulate = Color(0.45, 0.45, 0.5)
		m.add_child(col)
		panel.add_child(m)
		return panel
	if equipped:
		btn.text = "Quitar"
		Styles.styled_button(btn, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
		btn.pressed.connect(_on_unequip.bind(id))
	elif owned:
		btn.text = "Poner"
		Styles.styled_button(btn, Styles.pill_filled(Styles.GREEN), Color.BLACK)
		btn.pressed.connect(_on_equip.bind(id))
	elif _player.balance >= price:
		btn.text = CurrencyFormat.format(price)
		Styles.styled_button(btn, Styles.pill_filled(Styles.GOLD), Color.BLACK)
		btn.pressed.connect(_on_buy_cosmetic.bind(id))
	else:
		btn.text = CurrencyFormat.format(price)
		Styles.styled_button(btn, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
		btn.disabled = true
	col.add_child(btn)

	m.add_child(col)
	panel.add_child(m)
	_tap_to_try(panel, id)
	return panel

## Compra (P1b #13): "-€X" que sube y se va + el dinero de arriba cuenta.
func _purchase_fx(spent: int) -> void:
	Audio.play("confirm")
	Haptics.hit("success")
	if spent > 0:
		Juice.float_text(self, "-" + CurrencyFormat.format(spent), Vector2(size.x * 0.5 - 50.0, size.y * 0.45), Color(1, 0.5, 0.45), 28)
	for tb in get_tree().get_nodes_in_group("topbar"):
		if tb.has_method("refresh"):
			tb.call("refresh")

func _on_buy_cosmetic(id: String) -> void:
	var bal0: int = _player.balance
	if ShopEngine.buy_cosmetic(_player, id):
		SaveManager.save_player(_player)
		_toast("¡Comprado! Ya lo tenés puesto.")
		_purchase_fx(bal0 - _player.balance)
	else:
		_toast("No se pudo comprar.")
	_render()

func _on_equip(id: String) -> void:
	if ShopEngine.equip_cosmetic(_player, id):
		SaveManager.save_player(_player)
	_render()

func _on_unequip(id: String) -> void:
	ShopEngine.unequip_cosmetic(_player, id)
	SaveManager.save_player(_player)
	_render()

func _catalog_card(it: Dictionary) -> PanelContainer:
	var accent: Color = _COLORS.get(it.get("color_key", "GOLD"), Styles.GOLD)
	var id: String = String(it["id"])
	var price: int = ShopEngine.price_for(_player, id)
	var camp_left: int = ShopEngine.training_camps_left(WorldTickEngine.season)
	var camp_capped: bool = id == "training_camp" and camp_left <= 0
	var affordable: bool = _player.balance >= price and not camp_capped

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(accent))
	var margin := _margin()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	row.add_child(_icon_badge(it.get("icon", ""), accent))

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 3)
	var name_lbl := Label.new()
	name_lbl.text = String(it["name"])
	name_lbl.add_theme_font_override("font", Styles.font_semibold())
	texts.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = String(it["desc"])
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	desc_lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	texts.add_child(desc_lbl)
	var tag_text: String = String(it.get("tag", ""))
	if id == "training_camp":
		tag_text += "  ·  quedan %d/%d esta temporada" % [camp_left, ShopEngine.TRAINING_CAMP_SEASON_LIMIT]
	texts.add_child(_tag_chip(tag_text, accent))
	row.add_child(texts)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(96, 0)
	buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_btn.text = "Agotado" if camp_capped else CurrencyFormat.format(price)
	if affordable:
		Styles.styled_button(buy_btn, Styles.pill_filled(Styles.GOLD), Color.BLACK)
		buy_btn.pressed.connect(_on_buy.bind(id))
	else:
		Styles.styled_button(buy_btn, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
		buy_btn.disabled = true
	row.add_child(buy_btn)

	margin.add_child(row)
	panel.add_child(margin)
	return panel

func _inventory_card(id: String, count: int) -> PanelContainer:
	var it: Dictionary = ShopEngine.item_by_id(id)
	var accent: Color = _COLORS.get(it.get("color_key", "GOLD"), Styles.GOLD)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(accent))
	var margin := _margin()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_icon_badge(it.get("icon", ""), accent))

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 3)
	var name_lbl := Label.new()
	name_lbl.text = "%s   x%d" % [String(it.get("name", id)), count]
	name_lbl.add_theme_font_override("font", Styles.font_semibold())
	texts.add_child(name_lbl)
	var hint_lbl := Label.new()
	hint_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	hint_lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.text = _inventory_hint(id)
	texts.add_child(hint_lbl)
	row.add_child(texts)

	var use_btn := Button.new()
	use_btn.custom_minimum_size = Vector2(96, 0)
	use_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var kind: String = String(it.get("kind", "instant"))
	# Tope de USO del campamento (no solo de compra — ver
	# ShopEngine.training_camp_uses_left): antes el botón "Usar" quedaba
	# siempre habilitado aunque ya no quedara cupo, y el jugador solo se
	# enteraba al tocar y ver el toast de rechazo.
	var camp_uses_capped: bool = id == "training_camp" and ShopEngine.training_camp_uses_left(WorldTickEngine.season) <= 0
	use_btn.text = "Agotado" if camp_uses_capped else ("Usar" if kind == "instant" else ("Activar" if kind == "arm" else "—"))
	if kind == "halftime" or camp_uses_capped:
		Styles.styled_button(use_btn, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
		use_btn.disabled = true
	else:
		Styles.styled_button(use_btn, Styles.pill_filled(accent), Color.BLACK)
		use_btn.pressed.connect(_on_use.bind(id))
	row.add_child(use_btn)

	margin.add_child(row)
	panel.add_child(margin)
	return panel

func _inventory_hint(id: String) -> String:
	match id:
		"medkit":
			return "Recorta días de lesión. %s" % ("Estás lesionado." if _player.injury_days_remaining > 0 else "No estás lesionado ahora mismo.")
		"training_camp":
			var left: int = ShopEngine.training_camp_uses_left(WorldTickEngine.season)
			return "Mejora +1 a 3 atributos + overall al instante. Quedan %d/%d usos esta temporada (aunque tengas más comprados)." % [left, ShopEngine.TRAINING_CAMP_SEASON_LIMIT]
		"energy_drink":
			return "Se usa desde el entretiempo del partido, no acá."
		"bandage":
			return "Se arma para tu próximo partido." + (_armed_txt("injury_shield_matches"))
		"prematch_supp":
			return "Se arma para tu próximo partido." + (_armed_txt("match_boost_matches"))
		"focus_supp":
			return "Se arma para tu próximo entrenamiento." + (" YA ARMADO." if _player.active_effects.get("training_boost", false) else "")
		_:
			return ""

func _armed_txt(key: String) -> String:
	return "  YA ARMADO." if int(_player.active_effects.get(key, 0)) > 0 else ""

func _on_buy(id: String) -> void:
	var bal0: int = _player.balance
	if ShopEngine.buy(_player, id, WorldTickEngine.season):
		SaveManager.save_player(_player)
		SaveManager.save_season(WorldTickEngine.season)
		_toast("Comprado.")
		_purchase_fx(bal0 - _player.balance)
	else:
		_toast("Ya usaste tu cupo de esta temporada." if id == "training_camp" else "No se pudo comprar.")
	_render()

func _on_use(id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	var res: Dictionary = ShopEngine.use(_player, id, rng, WorldTickEngine.season)
	if res.get("ok", false):
		SaveManager.save_player(_player)
		if id == "training_camp":
			SaveManager.save_season(WorldTickEngine.season)
	_toast(String(res.get("message", "")))
	_render()

func _toast(text: String) -> void:
	if text.is_empty():
		return
	message_label.text = text
	message_label.visible = true

# --- helpers de layout ---

func _margin() -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_bottom", 12)
	return m

func _icon_badge(icon_path: String, color: Color) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(40, 40)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", Styles.card(Color(color, 0.22), 10))
	var center := CenterContainer.new()
	if icon_path.ends_with(".png"):
		# Ícono pixel de PixelLab (9-oct): con sus colores, nítido y grande.
		badge.custom_minimum_size = Vector2(56, 56)
		var r := Icons.make_rect(icon_path, 48)
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		center.add_child(r)
	else:
		center.add_child(Icons.make_rect(icon_path, 20, color))
	badge.add_child(center)
	return badge

func _tag_chip(text: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.add_theme_stylebox_override("panel", Styles.card(Color(color, 0.18), 8))
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_left", 8)
	cm.add_theme_constant_override("margin_right", 8)
	cm.add_theme_constant_override("margin_top", 2)
	cm.add_theme_constant_override("margin_bottom", 2)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	cm.add_child(lbl)
	chip.add_child(cm)
	return chip


# ---------------------------------------------------------------- horizontal
## Tu configuración con UNA prenda puesta (misma regla que la vista previa
## de cada tarjeta del guardarropa).
func _cfg_with(id: String) -> Dictionary:
	var cfg: Dictionary = Avatar.config_for_player(_player, WorldTickEngine.world_seed).duplicate(true)
	var slot: String = Avatar.slot_of(id)
	if slot == "top" or slot == "bottom":
		var whole: String = String(cfg.get("outfit", ""))
		if whole != "":
			cfg.erase("outfit")
			cfg["top"] = whole
			cfg["bottom"] = Avatar.bottom_src_for(whole)
		cfg[slot] = Avatar.piece_src(id)
	elif slot == "acc_shoes":
		if not Avatar.wears_street(cfg):
			cfg["outfit"] = "jeans"
		cfg[slot] = id
	elif slot == "acc_feet":
		Avatar.strip_street(cfg)
		cfg[slot] = id
	else:
		cfg[slot] = id
	return cfg

## PROBADOR: tocar la tarjeta (fuera del botón) te pone la prenda en el
## jugador grande de la izquierda, sin comprarla.
func _tap_to_try(panel: Control, id: String) -> void:
	if get_viewport_rect().size.x <= get_viewport_rect().size.y:
		return
	if _try_on == id:
		var sb: StyleBoxFlat = (panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
		sb.border_color = Color("#c9a7ff")
		sb.set_border_width_all(3)
		panel.add_theme_stylebox_override("panel", sb)
	UiScroll.on_tap(panel, func():
		_try_on = "" if _try_on == id else id
		_render())

## CONSUMIBLES (horizontal): catálogo completo a la izquierda en grilla de
## 2 (sin pasar páginas) y TU INVENTARIO a la derecha, siempre a la vista.
func _render_consumables_land() -> void:
	if _hero != null and is_instance_valid(_hero):
		_hero.visible = false
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	catalog_box.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	left.add_theme_constant_override("separation", 8)
	cols.add_child(left)
	var head := HBoxContainer.new()
	var t := Styles.section_label("CATÁLOGO")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var bal := Label.new()
	bal.text = "Saldo  %s" % CurrencyFormat.format(_player.balance)
	bal.add_theme_font_override("font", Styles.font_semibold())
	bal.add_theme_color_override("font_color", Styles.GOLD)
	head.add_child(bal)
	left.add_child(head)
	var g := GridContainer.new()
	g.columns = 1   # 2 columnas desbordaban a lo ancho
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	left.add_child(g)
	for it in ShopEngine.CATALOG:
		var c: Control = _catalog_card(it)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(c)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)
	var n: int = 0
	for k in _player.consumables:
		n += int(_player.consumables[k])
	right.add_child(Styles.section_label("TU INVENTARIO  ·  %d" % n))
	if _player.consumables.is_empty():
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", Styles.card_flat(Color(1, 1, 1, 0.04), 14))
		var ev := VBoxContainer.new()
		ev.alignment = BoxContainer.ALIGNMENT_CENTER
		ev.custom_minimum_size.y = 180
		var ic := Icons.make_rect(Icons.PX_SHOP, 56)
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.modulate = Color(1, 1, 1, 0.5)
		var icc := CenterContainer.new()
		icc.add_child(ic)
		ev.add_child(icc)
		var el := Label.new()
		el.text = "Todavía no compraste nada.\nLo que compres aparece acá para usarlo."
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		el.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		ev.add_child(el)
		box.add_child(ev)
		right.add_child(box)
	else:
		for id in _player.consumables:
			right.add_child(_inventory_card(String(id), int(_player.consumables[id])))
	inventory_box.visible = false
