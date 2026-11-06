extends Control

## Se agotó el contrato del usuario (WorldTickEngine._begin_season_rollover).
## Elegir entre renovar con el club actual o fichar por uno de los clubes
## externos interesados (Fase 8b, mercado de fichajes). Sin botón de
## "volver": es una decisión obligatoria, no hay temporada siguiente hasta
## que se resuelve.

@onready var options_box: VBoxContainer = $Margin/VBox/Scroll/OptionsBox

func _ready() -> void:
	WorldTickEngine.load_runtime() # idempotente; por si se entra directo a esta escena
	# Bug visual real (auditoría ronda 3): pantalla obligatoria (sin botón
	# volver) sin el scroll táctil arreglado — con varias ofertas podía
	# quedar una opción inalcanzable.
	UiScroll.make_touch($Margin/VBox/Scroll)
	_render()

func _render() -> void:
	for child in options_box.get_children():
		child.queue_free()

	var world: Dictionary = WorldTickEngine.world
	var renewal: Dictionary = WorldTickEngine.season.get("renewal_offer", {})
	_build_negotiation_table(world, renewal)
	if not renewal.is_empty():
		var current_club := WorldFactory.find_club(world, renewal.get("club_id", ""))
		var name: String = current_club.club_name if current_club != null else "tu club actual"
		_add_option("Renovar con %s" % name, "Sueldo %s/temporada" % CurrencyFormat.format(int(renewal.get("wage", 0))), Icons.CLUB, renewal.get("club_id", ""), int(renewal.get("wage", 0)))

	for o in WorldTickEngine.season.get("transfer_offers", []):
		var origin: String = "tu país" if o.get("is_home_country", false) else "extranjero"
		_add_option(
			"%s — %s" % [o["club_name"], o["league_name"]],
			"%s  ·  Fuerza plantilla %d  ·  sueldo %s/temporada" % [origin, o["club_strength"], CurrencyFormat.format(int(o["wage"]))],
			Icons.TRANSFER, o["club_id"], int(o["wage"]), Styles.BLUE,
		)

	if options_box.get_child_count() == 0:
		var fallback := Label.new()
		if bool(WorldTickEngine.season.get("forced_retirement", false)):
			fallback.text = "Ya no llegan ofertas y la edad pesa. Es momento de colgar los botines con la cabeza en alto."
		else:
			fallback.text = "Ningún club te ofrece contrato. Si no querés seguir buscando, podés retirarte."
		fallback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fallback.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		options_box.add_child(fallback)

	# Colgar los botines: alternativa a aceptar una oferta cuando el
	# contrato venció (pedido de Wilber). Mid-contrato NO se llega acá:
	# rechazar ofertas y seguir ya es el comportamiento por defecto.
	var retire_btn := Button.new()
	retire_btn.custom_minimum_size = Vector2(0, 48)
	retire_btn.focus_mode = Control.FOCUS_NONE
	retire_btn.text = "Colgar los botines (retirarme)"
	Styles.styled_button(retire_btn, Styles.pill_outlined(Styles.RED), Styles.RED)
	retire_btn.pressed.connect(_on_retire_pressed)
	options_box.add_child(retire_btn)

func _on_retire_pressed() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "¿Seguro que querés retirarte? Termina tu carrera de jugador."
	dlg.title = "Retiro"
	dlg.ok_button_text = "Me retiro"
	dlg.confirmed.connect(func():
		var p := SaveManager.load_player()
		if p != null:
			p.club_id = ""
			p.wage = 0
			p.contract_years_remaining = 0
			p.press_feed.push_front({
				"headline": "%s anuncia su retiro" % p.player_name,
				"body": "Tras una carrera con %d títulos, %s cuelga los botines." % [p.trophies_won, p.player_name],
				"source": "DEPORTE TOTAL", "sentiment": "NEUTRAL", "day": WorldTickEngine.current_epoch_day,
			})
			SaveManager.save_player(p)
			# Palmarés final a la Colección (autoloads/SaveManager.gd) —
			# sobrevive aunque este slot se reutilice para una carrera nueva.
			SaveManager.archive_retired_career(p)
		# El Salón de la Fama limpia awaiting_contract_decision al salir.
		get_tree().change_scene_to_file("res://scenes/Retirement/Retirement.tscn"))
	add_child(dlg)
	dlg.popup_centered()

## "Mesa de negociación": tu cara enfrentada a la del presidente del club
## que negocia (el actual si hay renovación; si no, el mundo). Se arma una
## sola vez, va justo encima del SubtitleLabel.
func _build_negotiation_table(world: Dictionary, renewal: Dictionary) -> void:
	var vbox := $Margin/VBox as VBoxContainer
	if vbox.has_node("NegotiationTable"):
		vbox.get_node("NegotiationTable").queue_free()

	var p := SaveManager.load_player()
	if p == null:
		return
	var seed_int: int = SaveManager.load_world_seed()

	var club_id: String = String(renewal.get("club_id", p.club_id))
	var club := WorldFactory.find_club(world, club_id)
	var club_name: String = club.club_name if club != null else "el club"
	var pres_name: String = WorldFactory.synthetic_person_name(hash("president:" + club_id) ^ seed_int)

	var row := HBoxContainer.new()
	row.name = "NegotiationTable"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)

	row.add_child(_side(Styles.portrait_frame(Avatar.for_player(p, seed_int, 56), 56, Styles.GOLD), p.player_name, "Tú"))
	var vs := Label.new()
	vs.text = "·  ultimando detalles  ·"
	vs.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	vs.add_theme_font_size_override("font_size", 12)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vs)
	row.add_child(_side(Styles.portrait_frame(Avatar.for_npc(pres_name, "president", seed_int, 56), 56, Styles.BLUE), pres_name, "Presidente · %s" % club_name))

	vbox.add_child(row)
	vbox.move_child(row, 2) # tras TitleLabel + SubtitleLabel

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
	n.add_theme_font_size_override("font_size", 12)
	col.add_child(n)
	var s := Label.new()
	s.text = sub_text
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	s.add_theme_font_size_override("font_size", 10)
	col.add_child(s)
	return col

func _player_club_id() -> String:
	var p := SaveManager.load_player()
	return p.club_id if p != null else ""

func _player_wage() -> int:
	var p := SaveManager.load_player()
	return p.wage if p != null else 0

func _add_option(title: String, subtitle: String, icon_path: String, club_id: String, wage: int, accent: Color = Styles.GOLD) -> void:
	if get_viewport_rect().size.x > get_viewport_rect().size.y:
		_add_card(title, subtitle, club_id, wage, accent)
		return
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 96)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Styles.styled_button(btn, Styles.card_accent(accent))
	btn.pressed.connect(_on_option_chosen.bind(club_id, wage))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(44, 44)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", Styles.circle(Styles.CARD_DARK_2, 44))
	var badge_center := CenterContainer.new()
	badge_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_center.add_child(Icons.make_rect(icon_path, 22))
	badge.add_child(badge_center)
	row.add_child(badge)

	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(title_lbl)
	var subtitle_lbl := Label.new()
	subtitle_lbl.text = subtitle
	subtitle_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	subtitle_lbl.add_theme_font_size_override("font_size", 12)
	subtitle_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(subtitle_lbl)
	row.add_child(texts)

	margin.add_child(row)
	btn.add_child(margin)
	options_box.add_child(btn)

func _on_option_chosen(club_id: String, wage: int) -> void:
	var p := SaveManager.load_player()
	var is_renewal: bool = p != null and club_id == p.club_id
	var world: Dictionary = WorldTickEngine.world
	var club := WorldFactory.find_club(world, club_id)
	var league_name := ""
	var stars := 3
	for lg in world.get("leagues", []):
		if club != null and lg.league_id == club.league_id:
			league_name = lg.league_name
			stars = clampi(int(round((lg.reputation - 40) / 12.0)), 1, 5)
			break
	var pres_name: String = WorldFactory.synthetic_person_name(hash("president:" + club_id) ^ SaveManager.load_world_seed())
	var club_name: String = club.club_name if club != null else "tu club"

	# 1) Regateo con el presidente.
	var neg := ContractNegotiation.new()
	neg.setup({
		"club_id": club_id, "club_name": club_name, "pres_name": pres_name,
		"base_wage": wage, "base_years": ContractEngine.STARTING_CONTRACT_YEARS,
		"agent_stars": p.agent_stars if p != null else 3,
		"allow_reject": not is_renewal, "player": p,
	})
	neg.agreed.connect(func(terms: Dictionary):
		# 2) Ceremonia de firma con los términos negociados.
		var sc := SigningCeremony.new()
		sc.setup({
			"club_id": club_id, "club_name": club_name, "league_name": league_name,
			"stars": stars, "wage": int(terms["wage"]), "years": int(terms["years"]),
			"role": "Renovación" if is_renewal else "Nuevo desafío",
			"number": 0, "is_renewal": is_renewal, "player": p,
		})
		sc.confirmed.connect(func():
			WorldTickEngine.resolve_contract_decision(club_id, int(terms["wage"]), int(terms["years"]), {
				"goal_bonus": int(terms.get("goal_bonus", 0)),
				"release_clause": int(terms.get("release_clause", 0)),
			})
			# resolve_contract_decision ya armó last_season_report (la
			# temporada recién terminada) — mostrarlo antes del Hub, misma
			# cadena que el cierre normal: resumen → premios → carga.
			if not WorldTickEngine.last_season_report.is_empty():
				get_tree().change_scene_to_file("res://scenes/SeasonCeremony/SeasonCeremony.tscn")
			else:
				get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn"))
		add_child(sc))
	add_child(neg)


## HORIZONTAL: cada opción es una CARTA (como "Elegí tu primer club"):
## escudo grande, si es renovación o traspaso, datos, sueldo destacado y
## "Elegir". Las cartas van lado a lado.
func _add_card(title: String, subtitle: String, club_id: String, wage: int, accent: Color) -> void:
	var row: HBoxContainer = options_box.get_node_or_null("LandCards")
	if row == null:
		var m := $Margin as MarginContainer
		m.add_theme_constant_override("margin_top", 12)
		m.add_theme_constant_override("margin_bottom", 10)
		row = HBoxContainer.new()
		row.name = "LandCards"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		options_box.add_child(row)
		options_box.move_child(row, 0)
	var p: PlayerData = SaveManager.load_player()
	var renew: bool = p != null and club_id == p.club_id
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(230, 0)
	var sb := Styles.card_flat(Color(0.09, 0.1, 0.12, 0.96), 16)
	sb.border_width_top = 6
	sb.border_color = Styles.GOLD if renew else accent
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var tag := Label.new()
	tag.text = "RENOVAR" if renew else "TRASPASO"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_override("font", Styles.font_black())
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", Styles.GOLD if renew else accent.lightened(0.3))
	v.add_child(tag)
	var cc := CenterContainer.new()
	cc.add_child(Styles.club_crest(club_id, 56))
	v.add_child(cc)
	var t := Label.new()
	t.text = title.replace("Renovar con ", "")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_override("font", Styles.font_black())
	t.add_theme_font_size_override("font_size", 16)
	v.add_child(t)
	var sub := Label.new()
	# Sin el sueldo: ya va grande abajo.
	var parts: Array = []
	for part in subtitle.split("  ·  "):
		if not part.to_lower().begins_with("sueldo"):
			parts.append(part)
	sub.text = "  ·  ".join(parts)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(sub)
	var w := Label.new()
	w.text = "%s / temporada" % CurrencyFormat.format(wage)
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w.add_theme_font_override("font", Styles.font_black())
	w.add_theme_font_size_override("font_size", 17)
	w.add_theme_color_override("font_color", Styles.GOLD)
	v.add_child(w)
	var b := Button.new()
	b.text = "Elegir"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 42)
	Styles.styled_button(b, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	b.pressed.connect(_on_option_chosen.bind(club_id, wage))
	v.add_child(b)
	card.add_child(v)
	row.add_child(card)
