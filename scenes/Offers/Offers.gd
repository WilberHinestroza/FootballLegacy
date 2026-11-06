extends Control

## Tras el partido de prueba: 5 ofertas de club generadas por CareerSetup
## según la nota de la prueba. El jugador elige una y ahí empieza su
## carrera (se fija player.club_id y se persiste).
##
## Estado de entrada vía Autoload (no parámetros de escena):
##  - MatchState.user_player      -> el jugador recién creado
##  - MatchState.match_result     -> {"user_rating": float, ...}
##  - SaveManager.load_world_seed -> para reconstruir el mismo mundo

@onready var subtitle_label: Label = $Scroll/Margin/VBox/SubtitleLabel
@onready var offers_box: VBoxContainer = $Scroll/Margin/VBox/OffersBox

var _player: PlayerData = null
var _offers: Array = []
var _world: Dictionary = {}

func _ready() -> void:
	_player = MatchState.user_player
	if _player == null:
		_player = SaveManager.load_player() # respaldo si se recargó la escena
	if _player == null:
		push_error("Offers.gd: no hay jugador ni en MatchState ni en el slot.")
		return

	# MatchState.match_result ya está vacío acá: MatchSummary llama
	# MatchState.clear() antes de navegar a esta pantalla — bug real
	# corregido, ver el comentario de MatchState.last_user_rating.
	var rating: float = MatchState.last_user_rating
	_world = WorldFactory.build(SaveManager.load_world_seed())
	_offers = CareerSetup.generate_offers(_player, rating, _world)

	subtitle_label.text = "Tu prueba: %.1f / 10 — elige tu primer club" % rating
	_render_offers()

## País de una liga por id (para mostrar de dónde es cada oferta).
func _league_country(league_id: int) -> String:
	for lg in _world.get("leagues", []):
		if lg.league_id == league_id:
			return String(lg.country)
	return ""

func _render_offers() -> void:
	for child in offers_box.get_children():
		child.queue_free()

	if get_viewport_rect().size.x > get_viewport_rect().size.y:
		_render_draft()
		return
	for i in range(_offers.size()):
		offers_box.add_child(_make_offer_card(_offers[i], i))

## HORIZONTAL: las ofertas como CARTAS verticales lado a lado (estilo
## draft): escudo grande, liga y país, rol, fuerza de la plantilla, sueldo
## destacado y "Elegir". Si no entran todas, se deslizan de costado.
func _render_draft() -> void:
	var tl := get_node_or_null("Scroll/Margin/VBox/TitleLabel") as Label
	if tl != null:
		tl.text = "ELEGÍ TU PRIMER CLUB"
		tl.add_theme_font_override("font", Styles.font_black())
		tl.add_theme_font_size_override("font_size", 28)
		tl.add_theme_color_override("font_color", Styles.GOLD)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.y = 360
	UiScroll.make_touch(sc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(row)
	offers_box.add_child(sc)
	for i in range(_offers.size()):
		row.add_child(_offer_tile(_offers[i], i))

func _offer_tile(o: Dictionary, index: int) -> Control:
	var club := WorldFactory.find_club(_world, o["club_id"])
	var col: Color = Color(club.primary_color_hex) if club != null else Styles.CARD_DARK_2
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 340)
	var sb := Styles.card_flat(Color(0.09, 0.1, 0.12, 0.96), 16)
	sb.border_width_top = 6
	sb.border_color = col if col.get_luminance() > 0.12 else Styles.GOLD
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 14
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var cc := CenterContainer.new()
	var badge := Styles.club_crest(String(o["club_id"]), 84) if club != null else Styles.build_club_badge(col, "", 84)
	cc.add_child(badge)
	v.add_child(cc)
	var nm := Label.new()
	nm.text = String(o["club_name"])
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.add_theme_font_override("font", Styles.font_black())
	nm.add_theme_font_size_override("font_size", 17)
	v.add_child(nm)
	var lg := HBoxContainer.new()
	lg.alignment = BoxContainer.ALIGNMENT_CENTER
	lg.add_theme_constant_override("separation", 6)
	var country: String = _league_country(int(o.get("league_id", -1)))
	if country != "":
		lg.add_child(CountryFlags.flag_rect(country, 14))
	var ll := Label.new()
	ll.text = String(o["league_name"])
	ll.add_theme_font_size_override("font_size", 12)
	ll.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	lg.add_child(ll)
	v.add_child(lg)
	var home := Label.new()
	home.text = "Tu país" if o["is_home_country"] else "Extranjero"
	home.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home.add_theme_font_size_override("font_size", 11)
	home.add_theme_color_override("font_color", Styles.GREEN if o["is_home_country"] else Color("#7cc4ff"))
	v.add_child(home)
	# Rol (chip) + fuerza de la plantilla (barra).
	var role := Label.new()
	role.text = "Rol: %s" % String(o["role"]).capitalize()
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.add_theme_font_override("font", Styles.font_semibold())
	role.add_theme_font_size_override("font_size", 13)
	v.add_child(role)
	var str_l := Label.new()
	str_l.text = "Plantilla  %d" % int(o["club_strength"])
	str_l.add_theme_font_size_override("font_size", 11)
	str_l.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(str_l)
	var bar := ProgressBar.new()
	bar.min_value = 40
	bar.max_value = 90
	bar.value = int(o["club_strength"])
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	var f := StyleBoxFlat.new()
	f.bg_color = Styles.GOLD
	f.set_corner_radius_all(3)
	var b := StyleBoxFlat.new()
	b.bg_color = Color(1, 1, 1, 0.08)
	b.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", f)
	bar.add_theme_stylebox_override("background", b)
	v.add_child(bar)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var wage := Label.new()
	wage.text = "%s / temporada" % CurrencyFormat.format(int(o["wage"]))
	wage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wage.add_theme_font_override("font", Styles.font_black())
	wage.add_theme_font_size_override("font_size", 16)
	wage.add_theme_color_override("font_color", Styles.GOLD)
	v.add_child(wage)
	var pick := Button.new()
	pick.text = "Elegir"
	pick.focus_mode = Control.FOCUS_NONE
	pick.custom_minimum_size = Vector2(0, 42)
	Styles.styled_button(pick, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	pick.pressed.connect(_on_offer_chosen.bind(index))
	v.add_child(pick)
	card.add_child(v)
	return card

func _make_offer_card(o: Dictionary, index: int) -> Button:
	var club := WorldFactory.find_club(_world, o["club_id"])
	var badge_color: Color = Color(club.primary_color_hex) if club != null else Styles.CARD_DARK_2
	var short_name: String = club.short_name if club != null else "?"

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 108)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Styles.styled_button(btn, Styles.card_accent(badge_color))
	btn.pressed.connect(_on_offer_chosen.bind(index))

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

	var badge_col := VBoxContainer.new()
	badge_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge_col.add_theme_constant_override("separation", 3)
	var badge := Styles.club_crest(String(o["club_id"]), 52) if club != null else Styles.build_club_badge(badge_color, "", 52)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_col.add_child(badge)
	var country: String = _league_country(int(o.get("league_id", -1)))
	if country != "":
		var fr: TextureRect = CountryFlags.flag_rect(country, 20)
		if fr != null:
			fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			badge_col.add_child(fr)
	row.add_child(badge_col)

	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 3)

	var origin: String = "tu país" if o["is_home_country"] else "extranjero"
	var title_lbl := Label.new()
	var country_txt: String = ("  ·  %s" % country) if country != "" else ""
	title_lbl.text = "%s — %s%s (%s)" % [o["club_name"], o["league_name"], country_txt, origin]
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	subtitle_lbl.text = "Fuerza plantilla %d  ·  rol: %s  ·  sueldo %s/temporada" % [
		o["club_strength"], o["role"], CurrencyFormat.format(int(o["wage"])),
	]
	subtitle_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	subtitle_lbl.add_theme_font_size_override("font_size", 12)
	subtitle_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(subtitle_lbl)

	row.add_child(texts)
	margin.add_child(row)
	btn.add_child(margin)
	return btn

func _on_offer_chosen(index: int) -> void:
	var o: Dictionary = _offers[index]
	var stars: int = clampi(int(round((int(o["club_strength"]) - 42) / 9.6)), 1, 5)
	var sc := SigningCeremony.new()
	sc.setup({
		"club_id": o["club_id"], "club_name": o["club_name"], "league_name": o["league_name"],
		"stars": stars, "wage": int(o.get("wage", 0)), "years": ContractEngine.STARTING_CONTRACT_YEARS,
		"role": String(o.get("role", "Rotación")), "number": 0, "is_renewal": false, "player": _player,
	})
	sc.confirmed.connect(_finalize_choice.bind(o))
	add_child(sc)

func _finalize_choice(o: Dictionary) -> void:
	_player.club_id = o["club_id"]
	var base_wage: int = int(o.get("wage", ContractEngine.starting_wage(o["club_strength"], o["reputation"])))
	# Mismo criterio de techo que el resto de los sueldos (auditoría, ronda 2).
	_player.wage = mini(int(round(base_wage * AgentEngine.wage_multiplier(_player.agent_stars))), ContractEngine.wage_ceiling(_player.overall))
	_player.contract_years_remaining = ContractEngine.STARTING_CONTRACT_YEARS
	# Bug real de la auditoría (ronda 6): el rol que la ceremonia de firma
	# le PROMETE al jugador ("titular"/"rotación"/"promesa") no tenía
	# ningún efecto acá, a diferencia de un fichaje de mitad de carrera
	# (TransferOfferEngine.execute_pending), que sí fija coach_trust
	# inicial según el rol Y, si es "titular", un empujón real y temporal
	# a la chance de arrancar (role_titular_matches). Mismo criterio acá
	# para el primer club de la carrera.
	var role: String = String(o.get("role", "rotación"))
	match role:
		"titular": _player.coach_trust = 78
		"rotación": _player.coach_trust = 55
		_: _player.coach_trust = 42
	if role == "titular":
		_player.active_effects["role_titular_matches"] = TransferOfferEngine.TITULAR_PROMISE_MATCHES
	SaveManager.save_player(_player)

	# Generar y persistir el calendario de la liga de ese club. Carrera
	# nueva -> la temporada arranca en el día 0.
	var world_seed := SaveManager.load_world_seed()
	var world := WorldFactory.build(world_seed)
	var start_year := CalendarUtils.season_start_year(0)
	var season := SeasonCalendar.build_season(world, int(o["league_id"]), 0, start_year, _player.club_id, world_seed)

	# Objetivo de temporada del jugador (Fase 9, backlog "renovable cada
	# año"): el del club se deriva en vivo, este se sortea una vez.
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	season["player_objective"] = ObjectivesEngine.generate_player_objective(_player, rng)

	SaveManager.save_season(season)
	WorldTickEngine.load_runtime()

	MatchState.clear()
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")
