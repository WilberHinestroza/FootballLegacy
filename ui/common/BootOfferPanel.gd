extends Control
class_name BootOfferPanel

## Oferta de patrocinio de GUAYOS (schema v32): logo grande de la marca,
## tu jugador con su modelo puesto, cuánto paga y cuánto dura, y los modelos
## que te regala. Aceptar / Rechazar → WorldTickEngine.resolve_boot_offer.

signal closed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p := SaveManager.load_player()
	var offer: Dictionary = p.pending_boot_offer if p != null else {}
	var brand: Dictionary = BootBrands.by_id(String(offer.get("brand", "")))
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.78)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col: Color = Color(String(brand.get("color", "#ffd54f")))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(440, 0)
	var sb := Styles.card_flat(Color(0.08, 0.09, 0.12, 0.98), 20)
	sb.set_border_width_all(3)
	sb.border_color = col
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var kind := Label.new()
	kind.text = "OFERTA DE PATROCINIO · GUAYOS"
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind.add_theme_font_override("font", Styles.font_black())
	kind.add_theme_font_size_override("font_size", 13)
	kind.add_theme_color_override("font_color", Styles.GOLD)
	v.add_child(kind)
	if brand.is_empty() or p == null:
		v.add_child(_btn("Cerrar", Styles.GRAY_TEXT, func(): _close()))
		return
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 12)
	head.add_child(BootBrands.logo_rect(brand, 72))
	var bn := Label.new()
	bn.text = String(brand["name"]).to_upper()
	bn.add_theme_font_override("font", Styles.font_black())
	bn.add_theme_font_size_override("font_size", 34)
	bn.add_theme_color_override("font_color", col)
	bn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(bn)
	v.add_child(head)
	# Tu jugador con el primer modelo puesto + los modelos que te regalan.
	var stage := HBoxContainer.new()
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_theme_constant_override("separation", 8)
	for m in brand["models"]:
		var cfg: Dictionary = Avatar.config_for_player(p, SaveManager.load_world_seed()).duplicate()
		cfg["acc_feet"] = String(m)
		var full := Avatar.build_full(cfg, 104)
		full.custom_minimum_size = Vector2(104, 104)
		stage.add_child(full)
	v.add_child(stage)
	var models := Label.new()
	models.text = "Te regalan sus %d modelos mientras dure el contrato" % (brand["models"] as Array).size()
	models.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	models.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	models.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(models)
	v.add_child(UiKit.stat_strip([
		[CurrencyFormat.format(int(offer.get("weekly_income", 0))), "por semana", Styles.GREEN],
		["%d" % int(offer.get("weeks_remaining", 0)), "semanas", Color.WHITE],
	]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var rej := _btn("Rechazar", Styles.GRAY_TEXT, func(): _resolve(false))
	rej.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rej)
	var acc := _btn("Aceptar", Styles.GREEN, func(): _resolve(true), true)
	acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(acc)
	v.add_child(row)

func _btn(text: String, color: Color, cb: Callable, filled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(b, Styles.pill_filled(color) if filled else Styles.pill_outlined(color), Color.BLACK if filled else color)
	b.pressed.connect(cb)
	return b

func _resolve(accepted: bool) -> void:
	WorldTickEngine.resolve_boot_offer(accepted)
	_close()

func _close() -> void:
	closed.emit()
	queue_free()
