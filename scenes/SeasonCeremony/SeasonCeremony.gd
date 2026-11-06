extends Control

## Ceremonia de fin de temporada — pedido explícito: resumen del jugador
## y del club, nota de la temporada (0-10) y el Balón de Oro del mundo.
## Lee WorldTickEngine.last_season_report (armado una sola vez en
## WorldTickEngine._finish_season_rollover, ver SeasonReportEngine.gd) y
## lo limpia al salir — nunca se persiste, es un resumen de un solo uso.

@onready var season_label: Label = $Scroll/Margin/VBox/SeasonLabel
@onready var rating_label: Label = $Scroll/Margin/VBox/RatingCard/RatingMargin/RatingVBox/RatingLabel
@onready var player_summary_label: Label = $Scroll/Margin/VBox/RatingCard/RatingMargin/RatingVBox/PlayerSummaryLabel
@onready var club_name_label: Label = $Scroll/Margin/VBox/ClubCard/ClubMargin/ClubVBox/ClubNameLabel
@onready var club_summary_label: Label = $Scroll/Margin/VBox/ClubCard/ClubMargin/ClubVBox/ClubSummaryLabel
@onready var ballon_dor_box: VBoxContainer = $Scroll/Margin/VBox/BallonDorBox
@onready var continue_button: Button = $Scroll/Margin/VBox/ContinueButton
@onready var rating_card: PanelContainer = $Scroll/Margin/VBox/RatingCard
@onready var club_card: PanelContainer = $Scroll/Margin/VBox/ClubCard

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")

@onready var next_hint_label: Label = $Scroll/Margin/VBox/NextHintLabel

func _ready() -> void:
	var sc := $Scroll as ScrollContainer
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# Bug visual real (auditoría ronda 3): faltaba el deadzone táctil —
	# la tabla del Balón de Oro (DataTable) podía tragarse el arrastre.
	UiScroll.make_touch(sc)

	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.add_theme_constant_override("icon_max_width", 26)
	Styles.apply_display_font(rating_label)

	var report: Dictionary = WorldTickEngine.last_season_report
	var start_year: int = int(report.get("start_year", CalendarUtils.season_start_year(WorldTickEngine.current_epoch_day)))
	season_label.text = "Temporada %d/%d" % [start_year, start_year + 1]

	# Logo de la liga del jugador junto al título de la temporada.
	var uclub := WorldFactory.find_club(WorldTickEngine.world, WorldTickEngine.user_club_id)
	if uclub != null:
		var parent := season_label.get_parent()
		var idx := season_label.get_index()
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		parent.remove_child(season_label)
		var logo := Competition.league_node(uclub.league_id, 26)
		logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(logo)
		row.add_child(season_label)
		parent.add_child(row)
		parent.move_child(row, idx)

	# El botón "seguir": si el contrato venció, primero hay que decidir el
	# futuro; si no, se va directo a la temporada nueva (que ya está armada).
	var pending_decision: bool = WorldTickEngine.season.get("awaiting_contract_decision", false)
	if pending_decision:
		continue_button.text = "  Decidir mi futuro"
		continue_button.icon = Icons.load_icon(Icons.CAREER)
		Styles.styled_button(continue_button, Styles.pill_filled(Styles.BLUE), Color.WHITE)
		next_hint_label.text = "Tu contrato venció — te toca elegir club y condiciones."
	else:
		continue_button.text = "  Ir a la temporada %d/%d" % [start_year + 1, start_year + 2]
		continue_button.icon = Icons.load_icon(Icons.PLAY)
		Styles.styled_button(continue_button, Styles.pill_filled(Styles.GOLD), Color.BLACK)
		next_hint_label.text = "La temporada %d/%d ya está lista: nuevo calendario, mercado y objetivos." % [start_year + 1, start_year + 2]
	next_hint_label.add_theme_color_override("font_color", Styles.GRAY_TEXT)

	var rating: float = float(report.get("player_rating", 0.0))
	rating_label.text = "%.1f" % rating
	var med_name: String = Medals.GOLD if rating >= 8.0 else (Medals.SILVER if rating >= 6.5 else Medals.BRONZE)
	var med := Medals.rect(Medals.by_name(med_name), 42)
	if med != null:
		var rv := $Scroll/Margin/VBox/RatingCard/RatingMargin/RatingVBox
		var mc := CenterContainer.new()
		rv.add_child(mc)
		rv.move_child(mc, 0)
		mc.add_child(med)
	var rating_color: Color = _rating_color(rating)
	rating_label.add_theme_color_override("font_color", rating_color)
	rating_card.add_theme_stylebox_override("panel", Styles.card_accent(rating_color))
	player_summary_label.text = String(report.get("player_summary", ""))

	club_name_label.text = String(report.get("club_name", "Tu club")).to_upper()
	club_summary_label.text = String(report.get("club_summary", ""))
	club_card.add_theme_stylebox_override("panel", Styles.card_accent(Styles.BLUE))

	_render_new_traits(report.get("new_traits", []))
	if bool(report.get("captaincy", false)):
		_render_captaincy_banner()
	var prize: Dictionary = report.get("prize_money", {})
	if int(prize.get("total", 0)) > 0:
		var pl := Label.new()
		pl.text = "💰 Primas por títulos: %s" % CurrencyFormat.format(int(prize["total"]))
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.add_theme_font_override("font", Styles.font_semibold())
		pl.add_theme_color_override("font_color", Styles.GREEN)
		var vbox := ballon_dor_box.get_parent() as VBoxContainer
		vbox.add_child(pl)
		vbox.move_child(pl, ballon_dor_box.get_index())
	_render_ballon_dor(report.get("ballon_dor", []))

	_landscape_ceremony(rating)

	# "TU TEMPORADA" tipo Wrapped antes del resumen (P5, 10-oct).
	if report.has("wrapped"):
		SeasonWrapped.open(self, report)

	# Confeti si la temporada fue buena (Kenney Particle Pack).
	if rating >= 6.5:
		var confetti := Confetti.new()
		confetti.position = Vector2(288, -10)
		add_child(confetti)
		confetti.burst(3.5)

func _render_captaincy_banner() -> void:
	var vbox := ballon_dor_box.get_parent() as VBoxContainer
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 14)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	var l := Label.new()
	l.text = "🎖  EL VESTUARIO TE ELIGE CAPITÁN"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Styles.font_black())
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Styles.GOLD)
	m.add_child(l)
	card.add_child(m)
	vbox.add_child(card)
	vbox.move_child(card, ballon_dor_box.get_index())

## Rasgos recién desbloqueados esta temporada (schema v21) — tarjeta
## morada arriba del Balón de Oro.
func _render_new_traits(ids: Array) -> void:
	if ids.is_empty():
		return
	var vbox := ballon_dor_box.get_parent() as VBoxContainer
	var card := PanelContainer.new()
	card.name = "NewTraitsCard"
	card.add_theme_stylebox_override("panel", Styles.card_accent(Styles.PURPLE))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 14)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var h := Label.new()
	h.text = "✦ NUEVO%s RASGO%s DE JUGADOR" % ["" if ids.size() == 1 else "S", "" if ids.size() == 1 else "S"]
	h.add_theme_font_override("font", Styles.font_black())
	h.add_theme_font_size_override("font_size", 13)
	h.add_theme_color_override("font_color", Styles.PURPLE)
	v.add_child(h)
	for tid in ids:
		var trow := HBoxContainer.new()
		trow.add_theme_constant_override("separation", 8)
		var badge := TraitBadge.build(String(tid), 34)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		trow.add_child(badge)
		var line := Label.new()
		line.text = "%s — %s" % [Traits.name_of(String(tid)), Traits.desc_of(String(tid))]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		trow.add_child(line)
		v.add_child(trow)
	m.add_child(v)
	card.add_child(m)
	vbox.add_child(card)
	vbox.move_child(card, ballon_dor_box.get_index())

func _rating_color(rating: float) -> Color:
	if rating >= 8.0:
		return Styles.GOLD
	if rating >= 6.0:
		return Styles.GREEN
	if rating >= 4.5:
		return Color.WHITE
	return Styles.RED

func _render_ballon_dor(rows: Array) -> void:
	for child in ballon_dor_box.get_children():
		child.queue_free()
	if rows.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Sin datos todavía."
		ballon_dor_box.add_child(empty_lbl)
		return

	var player := SaveManager.load_player()
	# Gala 3D del Balón de Oro (1-nov, pedido de Wilber: "las ceremonias de premios
	# individuales como el balón de oro"): salón, focos, y el ganador con el trofeo.
	var win_name: String = String(rows[0].get("name", "?"))
	var is_you: bool = player != null and win_name == player.player_name
	var report: Dictionary = WorldTickEngine.last_season_report
	var sy: int = int(report.get("start_year", CalendarUtils.season_start_year(WorldTickEngine.current_epoch_day)))
	ballon_dor_box.add_child(AwardGala.make_view({"award": "ballon_dor", "title": "Balón de Oro",
		"subtitle": "Temporada %d/%d" % [sy, sy + 1], "winner_name": win_name, "is_you": is_you,
		"profile": Match3DBridge.profile_for(player, SaveManager.load_world_seed(), Color.BLACK, Color.BLACK, Color.BLACK) if is_you else null},
		Vector2(0, 280)))
	# ¡Ganaste el Balón de Oro! Tu jugador con el premio (animación de
	# PixelLab, 9-oct) arriba de la tabla.
	if player != null and String(rows[0].get("name", "")) == player.player_name and Avatar.has_anim("balon_oro"):
		var cc := CenterContainer.new()
		var anim: Control = Avatar.build_anim(Avatar.celebration_config_for_player(player, SaveManager.load_world_seed()), "balon_oro", 136, false, 8.0)
		anim.custom_minimum_size = Vector2(136, 136)
		cc.add_child(anim)
		ballon_dor_box.add_child(cc)
	else:
		# Podio del Balón de Oro (P1, 9-oct).
		ballon_dor_box.add_child(Podium.build(rows.slice(0, 3), player.player_name if player != null else "",
			func(r): return "%d/%d" % [int(r.get("goals", 0)), int(r.get("assists", 0))]))
	DataTable.add_row(ballon_dor_box, ["#", "Jugador", "Club", "G/A"], [28, 168, 140, 58], true)
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var is_mine: bool = player != null and String(row.get("name", "")) == player.player_name
		DataTable.add_row(ballon_dor_box, [
			str(i + 1), String(row.get("name", "?")), String(row.get("club_name", "?")),
			"%d/%d" % [int(row.get("goals", 0)), int(row.get("assists", 0))],
		], [28, 168, 140, 58], false, is_mine)

func _on_continue_pressed() -> void:
	var rep: Dictionary = WorldTickEngine.last_season_report
	WorldTickEngine.final_awards = (rep.get("ballon_dor", []) as Array).duplicate(true)
	WorldTickEngine.final_awards_year = int(rep.get("start_year", 0))
	WorldTickEngine.last_season_report = {}
	if WorldTickEngine.season.get("awaiting_contract_decision", false):
		get_tree().change_scene_to_file("res://scenes/ContractDecision/ContractDecision.tscn")
	else:
		# Secuencia completa de fin de temporada (pedido de Wilber):
		# resumen (acá) → premios individuales (Awards) → carga de la
		# nueva temporada (SeasonLoading) → recién ahí al Hub.
		get_tree().change_scene_to_file("res://scenes/Awards/Awards.tscn")


## HORIZONTAL: una CEREMONIA. Izquierda: tu jugador festejando (o
## lamentándose si fue mala) con tu nota grande y la medalla. Derecha: la
## temporada, tu club, lo ganado, el Balón de Oro y el botón para seguir.
func _landscape_ceremony(rating: float) -> void:
	if get_viewport_rect().size.x <= get_viewport_rect().size.y:
		return
	var vbox := $Scroll/Margin/VBox as VBoxContainer
	var player: PlayerData = SaveManager.load_player()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 380
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left.add_theme_constant_override("separation", 10)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	cols.add_child(right)
	var kids: Array = vbox.get_children()
	vbox.add_child(cols)
	var good: bool = rating >= 6.5
	if player != null:
		var anim: String = "celeb_aplauso" if good else "lamento"
		if rating >= 8.0 and Avatar.has_anim("balon_oro"):
			anim = "balon_oro"
		var stage := UiKit.anim_stage(player, anim, _rating_color(rating), 160)
		left.add_child(stage)
	rating_card.reparent(left)
	for k in kids:
		if k == rating_card:
			continue
		(k as Node).reparent(right)
	var tl := right.get_node_or_null("TitleLabel") as Label
	if tl != null:
		tl.text = "FIN DE TEMPORADA"
		tl.add_theme_font_override("font", Styles.font_black())
		tl.add_theme_font_size_override("font_size", 28)
		tl.add_theme_color_override("font_color", Styles.GOLD)
	season_label.add_theme_font_size_override("font_size", 18)
	rating_label.add_theme_font_size_override("font_size", 54)
	# Primas antes del encabezado del Balón de Oro (no entre título y tabla).
	var hdr: Node = right.get_node_or_null("BallonDorHeaderLabel")
	if hdr != null:
		for k in right.get_children():
			if k is Label and (k as Label).text.begins_with("💰"):
				right.move_child(k, hdr.get_index())
