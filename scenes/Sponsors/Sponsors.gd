extends Control

## PATROCINIOS (10-oct, Wilber: "crea una pantalla para el sponsor normal y
## el de guayos, que esté en Carrera"). Solo LECTURA de lo que ya existe en
## PlayerData (sponsor / boot_deal / pending_*): contrato principal, contrato
## de guayos, ofertas pendientes (con acceso a su pantalla de decisión) y el
## catálogo de marcas. Toda la matemática sigue en SponsorEngine y
## BootDealEngine — acá no se calcula nada de balance.

const BACK_SCENE := "res://scenes/CareerMenu/CareerMenu.tscn"

@onready var box: VBoxContainer = $Margin/Scroll/Box

var _player: PlayerData = null

func _ready() -> void:
	WorldTickEngine.load_runtime()
	UiScroll.make_touch($Margin/Scroll)
	_render()

func _render() -> void:
	Styles.land_columns_later(box, 1)  # horizontal: 2 columnas
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	_player = SaveManager.load_player()
	if _player == null:
		return
	var seed_i: int = SaveManager.load_world_seed()
	var weekly: int = int(_player.sponsor.get("weekly_income", 0)) + int(_player.boot_deal.get("weekly_income", 0))

	# Cabecera: tu jugador firmando (animación) + ingreso semanal total.
	var left: Control
	if Avatar.has_anim("firma"):
		left = Avatar.build_anim(Avatar.celebration_config_for_player(_player, seed_i), "firma", 96, true, 7.0)
	else:
		left = Avatar.for_player(_player, seed_i, 72)
	var chips: Array = [["%s / semana" % CurrencyFormat.format(weekly), Styles.GREEN]]
	if not _player.sponsor.is_empty():
		chips.append(["Principal ✓", Styles.GOLD])
	if not _player.boot_deal.is_empty():
		chips.append(["Guayos ✓", Color(0.45, 0.75, 1.0)])
	box.add_child(UiKit.hero(Styles.GOLD, left, "Patrocinios", "Tus contratos con marcas", chips))

	# --- Patrocinador principal ---
	box.add_child(Styles.section_label("PATROCINADOR PRINCIPAL"))
	if not _player.sponsor.is_empty():
		var sname: String = String(_player.sponsor.get("name", ""))
		var gifts: Array = []
		for g in _player.sponsor.get("granted", []):
			gifts.append(Avatar.label_of(String(g)))
		box.add_child(_deal_card(BrandMark.build(sname, 64), sname, Styles.GOLD,
			int(_player.sponsor.get("weekly_income", 0)), int(_player.sponsor.get("weeks_remaining", 0)), 30,
			("Te regala: %s (mientras dure el contrato)" % ", ".join(gifts)) if not gifts.is_empty() else ""))
	elif not _player.pending_sponsor_offer.is_empty():
		var o: Dictionary = _player.pending_sponsor_offer
		box.add_child(_offer_card(BrandMark.build(String(o.get("name", "")), 56), String(o.get("name", "")), Styles.GOLD,
			int(o.get("weekly_income", 0)), int(o.get("weeks_remaining", 0)),
			func(): get_tree().change_scene_to_file("res://scenes/SponsorOffer/SponsorOffer.tscn")))
	else:
		var strength: int = int(WorldTickEngine._strength_by_club.get(_player.club_id, 55)) if "_strength_by_club" in WorldTickEngine else 55
		var chance: float = SponsorEngine.offer_chance(strength, _player.overall)
		box.add_child(_empty_card("Sin patrocinador por ahora.",
			"Chance de oferta cada semana: %d%%. Sube con tu media y con la fuerza de tu club." % int(round(chance * 100.0)), Styles.GOLD))

	# --- Guayos ---
	box.add_child(Styles.section_label("PATROCINIO DE GUAYOS"))
	if not _player.boot_deal.is_empty():
		var brand: Dictionary = BootBrands.by_id(String(_player.boot_deal.get("brand", "")))
		var bcol: Color = Color(String(brand.get("color", "#ffd54f")))
		var models: Array = []
		for m in brand.get("models", []):
			models.append(Avatar.label_of(String(m)))
		var card := _deal_card(BootBrands.logo_rect(brand, 64), String(brand.get("name", "")), bcol,
			int(_player.boot_deal.get("weekly_income", 0)), int(_player.boot_deal.get("weeks_remaining", 0)), 52,
			"Modelos gratis: %s" % ", ".join(models))
		box.add_child(card)
		box.add_child(_models_row(brand))
	elif not _player.pending_boot_offer.is_empty():
		var bo: Dictionary = _player.pending_boot_offer
		var b2: Dictionary = BootBrands.by_id(String(bo.get("brand", "")))
		box.add_child(_offer_card(BootBrands.logo_rect(b2, 56), String(b2.get("name", "")), Color(String(b2.get("color", "#ffd54f"))),
			int(bo.get("weekly_income", 0)), int(bo.get("weeks_remaining", 0)),
			func():
				var panel := BootOfferPanel.new()
				panel.closed.connect(_render)
				add_child(panel)))
	else:
		var bchance: float = BootDealEngine.offer_chance(_player.overall, _player.reputation)
		var why: String = "Necesitás media 60 o más para que una marca te mire." if _player.overall < 60 \
			else "Chance de oferta cada semana: %d%%. Sube con tu media y tu reputación." % int(round(bchance * 100.0))
		box.add_child(_empty_card("Sin contrato de guayos.", why, Color(0.45, 0.75, 1.0)))

	# --- Catálogo de marcas de guayos ---
	box.add_child(Styles.section_label("MARCAS DE GUAYOS"))
	var grid := GridContainer.new()
	grid.columns = 4 if get_viewport_rect().size.x > get_viewport_rect().size.y else 2  # horizontal: 4 por fila
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for b in BootBrands.BRANDS:
		grid.add_child(_brand_tile(b, String(_player.boot_deal.get("brand", "")) == String(b["id"])))
	box.add_child(grid)

	var back := Button.new()
	back.text = "Volver"
	back.custom_minimum_size = Vector2(0, 52)
	back.focus_mode = Control.FOCUS_NONE
	back.icon = Icons.load_icon(Icons.BACK)
	back.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	back.pressed.connect(func(): get_tree().change_scene_to_file(BACK_SCENE))
	# En horizontal sobra: ya está la flecha de la barra de arriba.
	back.visible = get_viewport_rect().size.x <= get_viewport_rect().size.y
	box.add_child(back)
	UiScroll.pad_bottom(box)

func _panel(accent: Color) -> Array:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(accent))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 14)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	panel.add_child(m)
	return [panel, v]

func _head_row(logo: Control, name_text: String, accent: Color, sub: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(logo)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	var n := Label.new()
	n.text = name_text
	n.add_theme_font_override("font", Styles.font_black())
	n.add_theme_font_size_override("font_size", 20)
	n.add_theme_color_override("font_color", accent)
	col.add_child(n)
	var s := Label.new()
	s.text = sub
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	col.add_child(s)
	row.add_child(col)
	return row

## Contrato ACTIVO: marca, paga, semanas que quedan (barra) y lo que falta cobrar.
func _deal_card(logo: Control, name_text: String, accent: Color, weekly: int, weeks_left: int, weeks_ref: int, extra: String) -> Control:
	var pv: Array = _panel(accent)
	var v: VBoxContainer = pv[1]
	v.add_child(_head_row(logo, name_text, accent, "%s por semana" % CurrencyFormat.format(weekly)))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.max_value = maxi(weeks_ref, weeks_left)
	bar.value = weeks_left
	var fg := StyleBoxFlat.new()
	fg.bg_color = accent
	fg.set_corner_radius_all(5)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fg)
	bar.add_theme_stylebox_override("background", bg)
	v.add_child(bar)
	var info := Label.new()
	info.text = "Quedan %d semanas  ·  te falta cobrar %s" % [weeks_left, CurrencyFormat.format(weekly * weeks_left)]
	info.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	info.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(info)
	if extra != "":
		var e := Label.new()
		e.text = extra
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		e.add_theme_color_override("font_color", Styles.GREEN)
		v.add_child(e)
	return pv[0]

## Oferta PENDIENTE: resumen + botón a la pantalla donde se decide.
func _offer_card(logo: Control, name_text: String, accent: Color, weekly: int, weeks: int, on_open: Callable) -> Control:
	var pv: Array = _panel(accent)
	var v: VBoxContainer = pv[1]
	v.add_child(_head_row(logo, name_text, accent, "Te ofrece %s por semana durante %d semanas" % [CurrencyFormat.format(weekly), weeks]))
	var b := Button.new()
	b.text = "Ver la oferta"
	b.custom_minimum_size = Vector2(0, 46)
	b.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(b, Styles.pill_filled(accent), Color.BLACK)
	b.pressed.connect(on_open)
	v.add_child(b)
	return pv[0]

func _empty_card(title: String, body: String, accent: Color) -> Control:
	var pv: Array = _panel(accent)
	var v: VBoxContainer = pv[1]
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", Styles.font_semibold())
	v.add_child(t)
	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	b.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(b)
	return pv[0]

## Los modelos de la marca que tenés por contrato, con zoom a los pies.
func _models_row(brand: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var base: Dictionary = Avatar.celebration_config_for_player(_player, SaveManager.load_world_seed())
	for m in brand.get("models", []):
		var cfg: Dictionary = base.duplicate(true)
		cfg["acc_feet"] = String(m)
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(Avatar.build_feet(cfg, 104))
		var l := Label.new()
		l.text = Avatar.label_of(String(m)) + ("  ✓" if String(_player.cosmetics_equipped.get("acc_feet", "")) == String(m) else "")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 11)
		cell.add_child(l)
		row.add_child(cell)
	return row

func _brand_tile(b: Dictionary, mine: bool) -> Control:
	var col: Color = Color(String(b.get("color", "#ffd54f")))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := Styles.card_flat(Color(col, 0.16) if mine else Color(1, 1, 1, 0.05), 12)
	sb.set_border_width_all(2)
	sb.border_color = col if mine else Color(1, 1, 1, 0.08)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	var cc := CenterContainer.new()
	cc.add_child(BootBrands.logo_rect(b, 48))
	v.add_child(cc)
	var n := Label.new()
	n.text = String(b["name"]).to_upper() + ("  ✓" if mine else "")
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_override("font", Styles.font_black())
	n.add_theme_color_override("font_color", col)
	v.add_child(n)
	var c := Label.new()
	c.text = "%d modelos" % (b["models"] as Array).size()
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_theme_font_size_override("font_size", 11)
	c.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(c)
	panel.add_child(v)
	return panel
