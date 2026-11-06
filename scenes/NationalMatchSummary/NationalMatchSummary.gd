extends Control

## Resumen de un partido de SELECCIÓN — pedido de Wilber: "las pantallas
## de después de un partido de selección deben ser iguales a las de
## clubes, falta la pantalla de después y la opción de entrevista". Antes
## era un resumen MÍNIMO (marcador + tu nota + caps, sin estadísticas del
## partido ni zona mixta) mientras que MatchSummary.gd (clubes) tenía
## pestañas de Estadísticas/Valoraciones, figura del partido y entrevista.
## Ahora tiene la MISMA estructura, reusando los mismos componentes
## compartidos (MatchStatsView, InterviewEngine, PostMatchInterview,
## MatchRatingCalculator) — solo cambia lo que de verdad es distinto:
## banderas en vez de escudos, país en vez de club, y las consecuencias de
## carrera (caps/goles internacionales/fatiga cruzada con el club) en vez
## de las de club (confianza del DT, sueldo, sanciones, prensa de club).
## Sigue sin objetivos de temporada, sueldo ni sanciones — eso es todo
## estado de CLUB que un partido de selección no tiene.
##
## MatchState.fixture para este camino usa "home_country"/"away_country"
## (no "home_club_id"/"away_club_id" como los partidos de club) — ver
## NationalTeamMatchLauncher.prepare(). Match.gd decide venir acá en vez
## de a MatchSummary.tscn mirando `fixture["competition"]`.

@onready var score_card: PanelContainer = $Root/VBox/ScoreCard
@onready var result_banner_label: Label = $Root/VBox/ScoreCard/ScoreMargin/ScoreVBox/ResultBannerLabel
@onready var score_label: Label = $Root/VBox/ScoreCard/ScoreMargin/ScoreVBox/ScoreLabel
@onready var narrative_label: Label = $Root/VBox/ScoreCard/ScoreMargin/ScoreVBox/NarrativeLabel
@onready var stats_tab_button: Button = $Root/VBox/TabsRow/StatsTabButton
@onready var ratings_tab_button: Button = $Root/VBox/TabsRow/RatingsTabButton
@onready var detail_box: VBoxContainer = $Root/VBox/Scroll/DetailBox
@onready var interview_button: Button = $Root/VBox/InterviewButton
@onready var continue_button: Button = $Root/VBox/ContinueButton

var _fixture: Dictionary = {}
var _result: Dictionary = {}
var _player: PlayerData = null
var _context: Dictionary = {}
var _standout: bool = false
var _user_is_home: bool = false
var _tab: String = "stats"
var _ratings_team: String = "home"

func _ready() -> void:
	_fixture = MatchState.fixture
	_result = MatchState.match_result
	_player = SaveManager.load_player()

	if _result.is_empty() or _player == null:
		_leave()
		return

	var home: String = String(_fixture.get("home_country", ""))
	var away: String = String(_fixture.get("away_country", ""))
	_user_is_home = home == _player.country
	_ratings_team = "home" if _user_is_home else "away"

	_apply_national_consequences()

	# Mismo criterio que MatchSummary._context/_standout — InterviewEngine.
	# extract_context() lee "home_club_id" del fixture para saber si sos
	# local; los fixtures de selección traen "home_country"/"away_country"
	# en su lugar, así que se arma una copia con esa clave aliasada en vez
	# de tocar InterviewEngine (compartido con los partidos de club).
	var fx_for_ctx: Dictionary = _fixture.duplicate()
	fx_for_ctx["home_club_id"] = home
	fx_for_ctx["away_club_id"] = away
	_context = InterviewEngine.extract_context(fx_for_ctx, _result, _player.country, _player, WorldTickEngine.season)
	_standout = InterviewEngine.is_standout(
		int(_context["goals"]), float(_context["rating"]), bool(_context["won"]), int(_context["goal_diff"]),
	)

	_apply_static_styles()
	_render_score_card()

	stats_tab_button.pressed.connect(_on_tab.bind("stats"))
	ratings_tab_button.pressed.connect(_on_tab.bind("ratings"))
	interview_button.visible = _standout
	interview_button.pressed.connect(_on_interview_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	_render()
	UiScroll.make_touch(self)

## Consecuencias REALES de un partido de selección sobre la carrera: caps,
## goles/asistencias internacionales (nunca se resetean), fatiga/lesión
## cruzada con el club, y grabar el resultado como override para que la
## tabla/cuadro no lo re-simule distinto la próxima consulta. Nada de
## sueldo, sanciones, confianza del DT ni objetivos — eso es estado de
## CLUB que un partido de selección no toca.
func _apply_national_consequences() -> void:
	var sc: Dictionary = _result.get("score", {})
	var gh: int = int(sc.get("home", 0))
	var ga: int = int(sc.get("away", 0))

	var goals: int = int(_result.get("user_goals", 0))
	var assists: int = int(_result.get("user_assists", 0))
	# Bug real encontrado en la auditoría: los caps se sumaban SIEMPRE, aunque
	# te quedaras los 90' en el banco sin entrar — mismo bug que ya se había
	# corregido para season_matches_played de club (gateado por user_played,
	# ver MatchEngine.run_match()), nunca replicado acá.
	if bool(_result.get("user_played", false)):
		_player.caps += 1
		_player.international_goals += goals
		_player.international_assists += assists

	# Fatiga/lesión cruzada con el club (Parte 91, pedido de Wilber): antes
	# un partido de selección no restaba nada de fatigue_physical NI
	# aplicaba de verdad la lesión (solo se mostraba el aviso en pantalla,
	# player.injury_days_remaining nunca se tocaba) — jugar un Mundial no
	# tenía ningún costo real de cara al club. Misma fórmula que
	# MatchSummary.gd (PlayerDevelopment, centralizada, sin duplicar).
	# Bug real de la auditoría (ronda 6): faltaba el mismo chequeo
	# "user_played" que ya usan los caps unas líneas arriba — un
	# convocado que se quedó en el banco recibía el mismo golpe de fatiga
	# que si hubiera jugado.
	if not MatchState.user_suspended and bool(_result.get("user_played", false)):
		_player.fatigue_physical = PlayerDevelopment.physical_fatigue_after_match(_player, true)
	var injury_rng := RandomNumberGenerator.new()
	injury_rng.seed = hash("injury:%d" % WorldTickEngine.current_epoch_day) ^ SaveManager.load_world_seed()
	PlayerDevelopment.apply_match_injury(_player, bool(_result.get("user_injured", false)), injury_rng)

	# Nivel de carrera + forma (schema v33): un partido de selección es
	# oficial — cuenta igual que uno de club.
	var played: bool = bool(_result.get("user_played", false))
	var rating: float = float(_result.get("user_rating", MatchRatingCalculator.BASE_RATING))
	var won: bool = (gh > ga) if _user_is_home else (ga > gh)
	ProgressionEngine.add_xp(_player, ProgressionEngine.match_xp(rating, goals, assists, won, played, false))
	if played:
		ProgressionEngine.push_rating(_player, rating)

	SaveManager.save_player(_player)

	# Graba el resultado real como override — si no, la próxima consulta a
	# la tabla/cuadro re-simula este partido con el simulador rápido y da
	# un resultado DISTINTO al que se acaba de jugar (ver nota en
	# WorldTickEngine.record_user_national_result).
	var comp: String = String(_fixture.get("competition", "qualifying"))
	var result_key: String = String(_fixture.get("result_key", ""))
	if result_key != "":
		var winner: String = String(_result.get("shootout_winner", ""))
		if winner == "":
			winner = "home" if gh >= ga else "away"
		WorldTickEngine.record_user_national_result(comp, result_key, gh, ga, winner)

func _apply_static_styles() -> void:
	result_banner_label.add_theme_font_override("font", Styles.font_black())
	Styles.apply_display_font(score_label)
	score_label.add_theme_font_size_override("font_size", Styles.SIZE_DISPLAY + 10)
	Styles.styled_button(interview_button, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
	Styles.styled_button(continue_button, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	interview_button.icon = Icons.load_icon(Icons.MICROPHONE)
	interview_button.add_theme_constant_override("icon_max_width", 26)
	continue_button.icon = Icons.load_icon(Icons.HOME)
	continue_button.add_theme_constant_override("icon_max_width", 28)

func _on_tab(t: String) -> void:
	_tab = t
	_render()
	UiScroll.make_touch(self)

func _refresh_tabs() -> void:
	for pair in [[stats_tab_button, "stats"], [ratings_tab_button, "ratings"]]:
		var b: Button = pair[0]
		if pair[1] == _tab:
			Styles.tab(b, true)
		else:
			Styles.tab(b, false)

func _render() -> void:
	_refresh_tabs()
	for c in detail_box.get_children():
		c.queue_free()
	if _tab == "ratings":
		_render_ratings_tab()
	else:
		_render_stats_tab()

## Tarjeta de marcador: banner de resultado, banderas, marcador, narrativa.
func _render_score_card() -> void:
	var sc: Dictionary = _result.get("score", {})
	var gh: int = int(sc.get("home", 0))
	var ga: int = int(sc.get("away", 0))
	score_label.text = "%d - %d" % [gh, ga]

	var won: bool = bool(_context.get("won", false))
	var result_color: Color
	if gh == ga and String(_result.get("shootout_winner", "")) == "":
		result_banner_label.text = "EMPATE"
		result_color = Styles.AMBER
	elif won:
		result_banner_label.text = "¡VICTORIA!"
		result_color = Styles.GREEN
	else:
		result_banner_label.text = "DERROTA"
		result_color = Styles.RED
	result_banner_label.add_theme_color_override("font_color", result_color)
	var rc_style := Styles.card_accent(result_color, Styles.CARD_DARK, 16)
	rc_style.border_width_top = 4
	rc_style.border_color = result_color
	score_card.add_theme_stylebox_override("panel", rc_style)
	_render_score_header(gh, ga)

	var narrative: String = _build_narrative(gh, ga)
	if bool(_result.get("user_red_carded", false)):
		narrative += " Terminaste expulsado."
	if bool(_result.get("user_injured", false)):
		narrative += " Terminaste lesionado."
	narrative_label.text = narrative

## Cabecera del marcador con las dos banderas — mismo criterio que
## MatchSummary._render_score_header(), con bandera+país en vez de
## escudo+club.
func _render_score_header(gh: int, ga: int) -> void:
	var vbox: VBoxContainer = $Root/VBox/ScoreCard/ScoreMargin/ScoreVBox
	if vbox.has_node("TeamsHeader"):
		vbox.get_node("TeamsHeader").queue_free()
	var home: String = String(_fixture.get("home_country", ""))
	var away: String = String(_fixture.get("away_country", ""))
	if home == "" or away == "":
		return
	var row := HBoxContainer.new()
	row.name = "TeamsHeader"
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_team_chip(home, gh > ga))
	var vs := Label.new()
	vs.text = "vs"
	vs.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	vs.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	row.add_child(vs)
	row.add_child(_team_chip(away, ga > gh))
	vbox.add_child(row)
	vbox.move_child(row, 1) # bajo el banner, encima del score

func _team_chip(country: String, winner: bool) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	var flag: TextureRect = CountryFlags.flag_rect(country, 22)
	var fc := CenterContainer.new()
	fc.add_child(flag)
	col.add_child(fc)
	var lbl := Label.new()
	lbl.text = country
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	if winner:
		lbl.add_theme_font_override("font", Styles.font_semibold())
	else:
		lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	col.add_child(lbl)
	return col

# --- Viñeta: Estadísticas ---

func _render_stats_tab() -> void:
	_render_mvp_card()

	detail_box.add_child(Styles.section_label("TU PARTIDO"))
	var mine := PanelContainer.new()
	mine.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD))
	var mm := MarginContainer.new()
	mm.add_theme_constant_override("margin_left", 14)
	mm.add_theme_constant_override("margin_top", 12)
	mm.add_theme_constant_override("margin_right", 14)
	mm.add_theme_constant_override("margin_bottom", 12)
	var mrow := HBoxContainer.new()
	mrow.add_child(_stat_column(str(int(_result.get("user_goals", 0))), "Goles"))
	mrow.add_child(_stat_column(str(int(_result.get("user_assists", 0))), "Asist."))
	mrow.add_child(_stat_column("%.1f" % float(_result.get("user_rating", MatchRatingCalculator.BASE_RATING)), "Tu nota"))
	mrow.add_child(_stat_column(str(_player.caps), "Caps"))
	mm.add_child(mrow)
	mine.add_child(mm)
	detail_box.add_child(mine)

	# Mapa de jugadas también en selección (P3, 9-oct): mismo componente que
	# el resumen de club (MatchState.moment_map lo llena Match.gd).
	if not MatchState.moment_map.is_empty():
		detail_box.add_child(Styles.section_label("TUS JUGADAS EN LA CANCHA"))
		var map := MomentMap.new()
		map.set_moments(MatchState.moment_map)
		detail_box.add_child(map)
		var legend := RichTextLabel.new()
		legend.bbcode_enabled = true
		legend.fit_content = true
		legend.scroll_active = false
		legend.add_theme_font_size_override("normal_font_size", Styles.SIZE_CAPTION)
		legend.text = "[center][color=#3ecf6e]●[/color] salió bien   [color=#e0524a]●[/color] salió mal   [color=#ffd24a]★[/color] gol   → pase   ·   arriba, el arco rival[/center]"
		detail_box.add_child(legend)

	# Estadísticas del partido — misma versión EXTENDIDA compartida que
	# usan los partidos de club (MatchStatsView), con los colores de
	# camiseta de cada selección en vez de los del club.
	var ms: Dictionary = _result.get("match_stats", {})
	if not ms.is_empty():
		detail_box.add_child(Styles.section_label("ESTADÍSTICAS DEL PARTIDO"))
		var home: String = String(_fixture.get("home_country", ""))
		var away: String = String(_fixture.get("away_country", ""))
		var hc: Color = CountryFlags.team_color(home)
		var ac: Color = CountryFlags.team_color(away)
		var gh_s: int = int(_result.get("score", {}).get("home", 0))
		var ga_s: int = int(_result.get("score", {}).get("away", 0))
		var key: String = "%s|%d" % [home, SaveManager.load_world_seed()]
		MatchStatsView.render(detail_box, ms, gh_s, ga_s, key, hc, ac, false)

	if _standout:
		var s := Label.new()
		s.text = "★  Actuación destacada"
		s.add_theme_color_override("font_color", Styles.GOLD)
		s.add_theme_font_override("font", Styles.font_semibold())
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_box.add_child(s)

## Figura del partido: cara (Kenney) + trofeo MVP al lado + nota — mismo
## criterio que MatchSummary._render_mvp_card(), con bandera en vez de
## escudo de club.
func _render_mvp_card() -> void:
	var ratings: Array = _result.get("player_ratings", [])
	if ratings.is_empty():
		return
	var mvp: Dictionary = ratings[0]
	var seed_int: int = SaveManager.load_world_seed()
	var is_user: bool = bool(mvp.get("is_user", false))
	var country: String = String(_fixture.get("%s_country" % String(mvp.get("team", "home")), ""))

	detail_box.add_child(Styles.section_label("FIGURA DEL PARTIDO"))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD if is_user else Styles.BLUE))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 14)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var face: Control
	if is_user and _player != null:
		face = Avatar.for_player(_player, seed_int, 64)
	else:
		face = Avatar.for_npc(String(mvp.get("name", "?")), "player", seed_int, 64)
	row.add_child(Styles.portrait_frame(face, 64, Styles.GOLD if is_user else Styles.BLUE))

	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	var nm := Label.new()
	nm.text = ("TÚ · " if is_user else "") + String(mvp.get("name", "?"))
	nm.add_theme_font_override("font", Styles.font_black())
	nm.add_theme_font_size_override("font_size", 18)
	col.add_child(nm)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 6)
	if country != "":
		var fr: TextureRect = CountryFlags.flag_rect(country, 16)
		fr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sub.add_child(fr)
	var pos_lbl := Label.new()
	pos_lbl.text = Positions.broad_label(String(mvp.get("position", "")))
	pos_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	sub.add_child(pos_lbl)
	col.add_child(sub)
	var rt := Label.new()
	rt.text = "Nota %.1f" % float(mvp.get("rating", 0.0))
	rt.add_theme_color_override("font_color", Styles.GREEN)
	rt.add_theme_font_override("font", Styles.font_semibold())
	col.add_child(rt)
	row.add_child(col)

	var trophy := Trophy.for_honor("mvp_match", 60)
	trophy.custom_minimum_size = Vector2(60, 64)
	trophy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(trophy)

	m.add_child(row)
	panel.add_child(m)
	detail_box.add_child(panel)

# --- Viñeta: Valoraciones (sub-viñetas por selección) ---

func _render_ratings_tab() -> void:
	var ratings: Array = _result.get("player_ratings", [])
	var home_name: String = String(_fixture.get("home_country", "Local"))
	var away_name: String = String(_fixture.get("away_country", "Visitante"))

	var subrow := HBoxContainer.new()
	subrow.add_theme_constant_override("separation", 8)
	var bh := Button.new()
	bh.text = home_name
	bh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.custom_minimum_size = Vector2(0, 40)
	bh.clip_text = true
	bh.pressed.connect(func(): _ratings_team = "home"; _render())
	var ba := Button.new()
	ba.text = away_name
	ba.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ba.custom_minimum_size = Vector2(0, 40)
	ba.clip_text = true
	ba.pressed.connect(func(): _ratings_team = "away"; _render())
	if _ratings_team == "home":
		Styles.tab(bh, true, true)
		Styles.tab(ba, false, true)
	else:
		Styles.tab(bh, false, true)
		Styles.tab(ba, true, true)
	subrow.add_child(bh)
	subrow.add_child(ba)
	detail_box.add_child(subrow)

	var is_user_side: bool = (_ratings_team == "home") == _user_is_home
	var any := false
	for r in ratings:
		if String(r.get("team", "")) == _ratings_team:
			detail_box.add_child(_rating_row(r, is_user_side))
			any = true
	if not any:
		var e := Label.new()
		e.text = "Sin valoraciones."
		e.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		detail_box.add_child(e)

func _rating_row(r: Dictionary, is_user_side: bool) -> PanelContainer:
	var row := PanelContainer.new()
	var is_user: bool = bool(r.get("is_user", false))
	var bg: Color = Color(0.3, 0.24, 0.05) if is_user else (Styles.CARD_DARK_2 if is_user_side else Styles.CARD_DARK)
	var style := Styles.card_flat(bg, 6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	row.add_theme_stylebox_override("panel", style)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var pos_lbl := Label.new()
	pos_lbl.text = Positions.broad_label(String(r.get("position", "")))
	pos_lbl.custom_minimum_size = Vector2(34, 0)
	pos_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	pos_lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	hb.add_child(pos_lbl)
	var name_lbl := Label.new()
	name_lbl.text = "%s%s" % [String(r.get("name", "?")), "  (tú)" if is_user else ""]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_user:
		name_lbl.add_theme_color_override("font_color", Styles.GOLD)
	hb.add_child(name_lbl)
	var rating_lbl := Label.new()
	var rv: float = float(r.get("rating", 6.0))
	rating_lbl.text = "%.1f" % rv
	rating_lbl.add_theme_font_override("font", Styles.font_semibold())
	rating_lbl.add_theme_color_override("font_color", _rating_tint(rv))
	hb.add_child(rating_lbl)
	row.add_child(hb)
	return row

func _rating_tint(v: float) -> Color:
	if v >= 7.5:
		return Styles.GREEN
	if v >= 6.0:
		return Color.WHITE
	if v >= 4.5:
		return Styles.AMBER
	return Styles.RED

func _stat_column(value: String, label: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var value_lbl := Label.new()
	value_lbl.text = value
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.add_theme_font_size_override("font_size", 26)
	value_lbl.add_theme_font_override("font", Styles.font_black())
	col.add_child(value_lbl)
	var caption_lbl := Label.new()
	caption_lbl.text = label
	caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	caption_lbl.add_theme_font_size_override("font_size", 12)
	col.add_child(caption_lbl)
	return col

func _build_narrative(gh: int, ga: int) -> String:
	var home: String = String(_fixture.get("home_country", "Local"))
	var away: String = String(_fixture.get("away_country", "Visitante"))
	var verb: String = "empató con" if gh == ga else ("venció a" if gh > ga else "cayó ante")
	var line: String = "%s %s %s %d-%d." % [home, verb, away, gh, ga]

	var goals: int = int(_context.get("goals", 0))
	if goals == 1:
		line += " Anotaste un gol."
	elif goals >= 2:
		line += " Anotaste %d goles." % goals

	var comp_label: String
	match String(_fixture.get("competition", "qualifying")):
		"world_cup": comp_label = "el Mundial"
		"national_cup": comp_label = "la copa continental"
		_: comp_label = "la eliminatoria"
	var user_won: bool = bool(_context.get("won", false))
	if bool(_fixture.get("is_knockout", false)):
		if String(_fixture.get("round_name", "")) == "Final":
			line += " ¡CAMPEONES!" if user_won else " Subcampeones. Cerquísima."
		else:
			line += " Avanzás en %s." % comp_label if user_won else " Quedás eliminados de %s." % comp_label
	else:
		if user_won:
			line += " Sumás en %s." % comp_label
		elif gh == ga:
			line += " Repartís puntos en %s." % comp_label
		else:
			line += " Tropiezo en %s." % comp_label
	return line

func _on_interview_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/PostMatchInterview/PostMatchInterview.tscn")

func _on_continue_pressed() -> void:
	_leave()

func _leave() -> void:
	var dest: String = MatchState.return_scene
	MatchState.clear()
	# Mismo criterio que MatchSummary._on_continue_pressed(): al terminar
	# el partido se avanza un día para que se vean reflejados los
	# resultados de la jornada — sin esto, jugar una selección "se comía"
	# el avance automático que sí tienen los partidos de club.
	if dest == "res://scenes/Hub/Hub.tscn":
		WorldTickEngine.advance_day()
		if WorldTickEngine.season.get("awaiting_contract_decision", false):
			dest = "res://scenes/ContractDecision/ContractDecision.tscn"
		elif not WorldTickEngine.last_season_report.is_empty():
			dest = "res://scenes/SeasonCeremony/SeasonCeremony.tscn"
	get_tree().change_scene_to_file(dest)
