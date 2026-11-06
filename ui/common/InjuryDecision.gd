extends Control
class_name InjuryDecision

## LESIÓN CON DECISIÓN (P5, 9-oct — "apurar la vuelta vs. recuperación
## completa"). Sala médica de fondo; el médico te da el parte y elegís.
## Las reglas (cuántos días, riesgo de recaída) viven en PlayerDevelopment.

signal closed

var _player: PlayerData

static func open(host: Node, player: PlayerData) -> InjuryDecision:
	var layer := CanvasLayer.new()
	layer.layer = 93
	host.add_child(layer)
	var d := InjuryDecision.new()
	d._player = player
	d.closed.connect(layer.queue_free)
	layer.add_child(d)
	return d

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	if ResourceLoader.exists("res://assets/scenes/medical.png"):
		bg.texture = load("res://assets/scenes/medical.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.45)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 16)
	m.add_theme_constant_override("margin_top", 40)
	m.add_theme_constant_override("margin_bottom", 24)
	add_child(m)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_END
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)

	var days: int = _player.injury_days_remaining
	var fast: int = PlayerDevelopment.rushed_injury_days(days)
	var card := PanelContainer.new()
	var sb := Styles.card_flat(Color(0.07, 0.08, 0.11, 0.96), 16)
	sb.set_border_width_all(2)
	sb.border_color = Styles.RED
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sb)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(Styles.portrait_frame(Avatar.for_npc("medico:%s" % _player.club_id, "staff", SaveManager.load_world_seed(), 56), 56, Styles.RED))
	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := Label.new()
	t.text = "PARTE MÉDICO"
	t.add_theme_font_override("font", Styles.font_black())
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Styles.RED)
	tcol.add_child(t)
	var q := Label.new()
	q.text = "\"Son %d días de baja si hacemos todo bien. Si querés, podemos apurarlo… pero el músculo no va a estar al 100%%.\"" % days
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tcol.add_child(q)
	row.add_child(tcol)
	cv.add_child(row)
	cv.add_child(_option("Recuperación completa", "%d días afuera · volvés sin riesgo" % days, Styles.GREEN, false))
	cv.add_child(_option("Apurar la vuelta", "%d días afuera · riesgo ALTO de recaer en los próximos %d partidos" % [fast, PlayerDevelopment.REINJURY_MATCHES], Styles.AMBER, true))
	v.add_child(card)
	card.modulate.a = 0.0
	card.create_tween().tween_property(card, "modulate:a", 1.0, 0.3)

func _option(title: String, sub: String, col: Color, rush: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 70)
	b.focus_mode = Control.FOCUS_NONE
	b.text = title + "\n" + sub
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Styles.styled_button(b, Styles.card_accent(col), Color.WHITE)
	b.pressed.connect(func():
		if rush:
			PlayerDevelopment.rush_injury(_player)
		SaveManager.save_player(_player)
		Nav.toast("Vas a apurar la vuelta. Cuidate." if rush else "Recuperación completa. Paciencia.")
		closed.emit()
		queue_free())
	return b
