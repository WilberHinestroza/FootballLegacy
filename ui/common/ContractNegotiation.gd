extends Control
class_name ContractNegotiation

## Overlay de REGATEO con el presidente del club (ver NegotiationEngine
## para la matemática). El jugador pide ajustes; el presidente responde y
## se le acaba la paciencia. Al aceptar → emite `agreed(final_terms)`
## (el llamador dispara la SigningCeremony con esos términos).

signal agreed(terms: Dictionary)
signal rejected

var _d: Dictionary = {}          # {club_id, club_name, pres_name, base_wage, base_years, agent_stars, allow_reject, player}
var _state: Dictionary = {}
var _body: VBoxContainer
var _pat_fill: ColorRect
var _msg: Label
var _terms: Label

func setup(data: Dictionary) -> ContractNegotiation:
	_d = data
	return self

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 200
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.74)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var neg_player: PlayerData = _d.get("player") as PlayerData
	_state = NegotiationEngine.start(int(_d.get("base_wage", 0)), int(_d.get("base_years", 3)), int(_d.get("agent_stars", 3)), neg_player.overall if neg_player != null else 60)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(320, 0)
	card.add_theme_stylebox_override("panel", Styles.card_accent(Styles.BLUE))
	center.add_child(card)
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 16)
	card.add_child(m)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	m.add_child(_body)

	var title := Label.new()
	title.text = "NEGOCIACIÓN"
	title.add_theme_font_override("font", Styles.font_black())
	title.add_theme_color_override("font_color", Styles.GOLD)
	title.add_theme_font_size_override("font_size", 13)
	_body.add_child(title)

	# Mesa: TÚ  ↔  PRESIDENTE (las dos caras enfrentadas)
	var pres_name: String = String(_d.get("pres_name", "El presidente"))
	var seed_int: int = SaveManager.load_world_seed()
	var mesa := HBoxContainer.new()
	mesa.alignment = BoxContainer.ALIGNMENT_CENTER
	mesa.add_theme_constant_override("separation", 10)

	var p: PlayerData = _d.get("player", null)
	var you_face: Control = Avatar.for_player(p, seed_int, 48) if p != null else Avatar.for_npc("Jugador", "player", seed_int, 48)
	mesa.add_child(_side(Styles.portrait_frame(you_face, 48, Styles.GOLD), p.player_name if p != null else "Tú", "Tú"))

	var vs := Label.new()
	vs.text = "↔"
	vs.add_theme_font_override("font", Styles.font_black())
	vs.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mesa.add_child(vs)

	mesa.add_child(_side(
		Styles.portrait_frame(Avatar.for_npc(pres_name, "president", seed_int, 48), 48, Styles.BLUE),
		pres_name, "Presidente · %s" % String(_d.get("club_name", ""))))
	_body.add_child(mesa)

	var cid: String = String(_d.get("club_id", ""))
	if cid != "":
		var crest_wrap := CenterContainer.new()
		var cr := Styles.club_crest(cid, 30)
		crest_wrap.add_child(cr)
		_body.add_child(crest_wrap)

	# Paciencia
	var plab := Label.new()
	plab.text = "Paciencia del presidente"
	plab.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	plab.add_theme_font_size_override("font_size", 10)
	_body.add_child(plab)
	var track := PanelContainer.new()
	track.custom_minimum_size = Vector2(0, 8)
	track.add_theme_stylebox_override("panel", Styles.card_flat(Color(1, 1, 1, 0.10), 4))
	_pat_fill = ColorRect.new()
	_pat_fill.color = Styles.GREEN
	track.add_child(_pat_fill)
	_body.add_child(track)

	# Perfil / social: valor de mercado + qué opina tu agente.
	var p2: PlayerData = _d.get("player", null)
	if p2 != null:
		var prof := Label.new()
		var mv: int = int(p2.market_value) if p2.market_value > 0 else 0
		var stars: int = int(_d.get("agent_stars", 3))
		var takes := [
			"Tu agente ve poco margen. Aceptá algo razonable.",
			"Tu agente dice que hay para pedir un poco más.",
			"Tu agente está seguro de que podés apretar fuerte.",
		]
		prof.text = "Valor de mercado: %s   ·   %s" % [
			(CurrencyFormat.format(mv) if mv > 0 else "s/d"),
			takes[clampi(stars - 2, 0, 2)],
		]
		prof.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prof.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		prof.add_theme_font_size_override("font_size", 10)
		_body.add_child(prof)

	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.add_theme_font_size_override("font_size", 12)
	_body.add_child(_msg)

	_body.add_child(HSeparator.new())
	_terms = Label.new()
	_terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_terms.add_theme_font_override("font", Styles.font_semibold())
	_terms.add_theme_font_size_override("font_size", 12)
	_body.add_child(_terms)
	_body.add_child(HSeparator.new())

	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 6)
	_body.add_child(actions)

	_refresh()

func _refresh() -> void:
	var pat: int = clampi(int(_state.get("patience", 0)), 0, 100)
	_pat_fill.anchor_right = pat / 100.0
	_pat_fill.color = Styles.GREEN if pat > 45 else (Styles.AMBER if pat > 20 else Styles.RED)
	_msg.text = String(_state.get("last_message", ""))
	_msg.add_theme_color_override("font_color", Styles.RED if _state.get("last_response", "") == "walk" else Styles.GRAY_TEXT)
	_terms.text = NegotiationEngine.summary_line(_state)

	var actions: VBoxContainer = _body.get_node("Actions")
	for c in actions.get_children():
		c.queue_free()

	var locked: bool = bool(_state.get("locked", false))
	if not locked:
		for ask in NegotiationEngine.ASKS:
			var a: String = String(ask)
			var b := Button.new()
			b.text = String(NegotiationEngine.ASKS[a])
			b.custom_minimum_size = Vector2(0, 40)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 12)
			Styles.styled_button(b, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
			b.pressed.connect(func():
				_state = NegotiationEngine.apply_ask(_state, a)
				_refresh())
			actions.add_child(b)

	var accept := Button.new()
	accept.text = "Aceptar y firmar"
	accept.custom_minimum_size = Vector2(0, 48)
	accept.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(accept, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	accept.pressed.connect(func():
		agreed.emit(_final_terms())
		queue_free())
	actions.add_child(accept)

	if bool(_d.get("allow_reject", false)):
		var rej := Button.new()
		rej.text = "Rechazar la oferta"
		rej.custom_minimum_size = Vector2(0, 40)
		rej.focus_mode = Control.FOCUS_NONE
		Styles.styled_button(rej, Styles.pill_outlined(Styles.RED), Styles.RED)
		rej.pressed.connect(func():
			rejected.emit()
			queue_free())
		actions.add_child(rej)

func _side(portrait: Control, name_text: String, sub_text: String) -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	var pw := CenterContainer.new()
	pw.add_child(portrait)
	col.add_child(pw)
	var n := Label.new()
	n.text = name_text
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.add_theme_font_size_override("font_size", 11)
	col.add_child(n)
	var s := Label.new()
	s.text = sub_text
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	s.add_theme_font_size_override("font_size", 9)
	col.add_child(s)
	return col

func _final_terms() -> Dictionary:
	return {
		"wage": int(_state["wage"]),
		"years": int(_state["years"]),
		"goal_bonus": int(_state["goal_bonus"]),
		"release_clause": int(_state["release_clause"]),
	}
