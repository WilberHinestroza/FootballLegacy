extends Control

## Pantalla de fin de partido: marcador, estadísticas, "el entrenador te
## dice" y, en partidos destacados, la opción de zona mixta (entrevista).
##
## Dueña de las consecuencias del partido sobre la carrera (antes vivían
## en Hub._ready() — mudadas aquí porque este es el sitio natural: "qué
## pasa justo después de jugar", no "qué muestra el hub"). Hub vuelve a
## ser una pantalla de solo lectura del estado ya resuelto.
##
## No limpia MatchState hasta irse de verdad (Continuar o tras la
## entrevista) — PostMatchInterview todavía necesita fixture/match_result
## para generar su pregunta.

@onready var score_card: PanelContainer = $Root/ScoreCard
@onready var result_banner_label: Label = $Root/ScoreCard/ScoreMargin/ScoreVBox/ResultBannerLabel
@onready var score_label: Label = $Root/ScoreCard/ScoreMargin/ScoreVBox/ScoreLabel
@onready var narrative_label: Label = $Root/ScoreCard/ScoreMargin/ScoreVBox/NarrativeLabel
@onready var stats_tab_button: Button = $Root/TabsRow/StatsTabButton
@onready var others_tab_button: Button = $Root/TabsRow/OthersTabButton
@onready var ratings_tab_button: Button = $Root/TabsRow/RatingsTabButton
@onready var detail_box: VBoxContainer = $Root/Scroll/DetailBox
@onready var interview_button: Button = $Root/InterviewButton
@onready var continue_button: Button = $Root/ContinueButton

var _fixture: Dictionary = {}
var _result: Dictionary = {}
var _player: PlayerData = null
var _context: Dictionary = {}
var _standout: bool = false
var _coach: CoachData = null
var _trust_delta: int = 0
var _attr_xp_result: Dictionary = {}
## v33: nivel/XP de carrera antes de este partido + resultado de sumar.
var _lv_before: int = 1
var _xp_before: int = 0
var _lv_result: Dictionary = {}
var _derby_bonus: int = 0
var _yellow_ban: bool = false   # llegaste a 5 amarillas: te perdés el próximo
var _mastery_ups: Array = []
var _gesture_xp: int = 0
var _challenge: Dictionary = {}
var _challenge_met: bool = false
var _new_achievements: Array = []
var _new_injury: bool = false
var _user_is_home: bool = false
## 11-oct (Wilber: "separar en 2 la pestaña estadísticas, una que sea
## vestuario con todo lo de vestuario"): "locker" = vestuario (charla del
## DT, progreso, logros), "stats" = solo números del partido.
var _tab: String = "locker"
var locker_tab_button: Button = null
var _ratings_team: String = "home"

func _ready() -> void:
	_fixture = MatchState.fixture
	_result = MatchState.match_result
	_player = SaveManager.load_player()

	if _result.is_empty() or _player == null:
		# Camino de pruebas sin resultado real que mostrar: no hay nada que
		# resumir, seguir directo a donde tocara ir.
		var dest: String = MatchState.return_scene
		MatchState.clear()
		get_tree().change_scene_to_file(dest)
		return

	if not _fixture.is_empty():
		_coach = _apply_match_consequences()
		_trust_delta = CoachRelations.trust_delta_for_rating(float(_result.get("user_rating", MatchRatingCalculator.BASE_RATING)), _coach, _match_result_sign())
		_context = InterviewEngine.extract_context(_fixture, _result, _player.club_id)
		# En la vuelta, el resultado deportivo es el global; el marcador grande
		# sigue mostrando el partido de hoy y debajo se ve el agregado.
		var tie_winner: String = String(_result.get("tie_winner", ""))
		if tie_winner != "":
			var user_home: bool = String(_fixture.get("home_club_id", "")) == _player.club_id
			_context["won"] = (tie_winner == "home") == user_home
			var aggregate: Dictionary = _result.get("aggregate_score", {})
			var mine: int = int(aggregate.get("home" if user_home else "away", 0))
			var theirs: int = int(aggregate.get("away" if user_home else "home", 0))
			_context["goal_diff"] = mine - theirs
		_standout = InterviewEngine.is_standout(
			int(_context["goals"]), float(_context["rating"]), bool(_context["won"]), int(_context["goal_diff"]),
		)

	_user_is_home = _fixture.get("home_club_id", "") == _player.club_id
	_ratings_team = "home" if _user_is_home else "away"

	_apply_static_styles()
	_render_score_card()

	# La pestaña nueva va primera; con 4 pestañas los rótulos se acortan.
	locker_tab_button = Button.new()
	locker_tab_button.name = "LockerTabButton"
	locker_tab_button.text = "Vestuario"
	locker_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	locker_tab_button.custom_minimum_size = stats_tab_button.custom_minimum_size
	stats_tab_button.get_parent().add_child(locker_tab_button)
	stats_tab_button.get_parent().move_child(locker_tab_button, 0)
	others_tab_button.text = "Otros"
	ratings_tab_button.text = "Notas"
	for tb in [locker_tab_button, stats_tab_button, others_tab_button, ratings_tab_button]:
		(tb as Button).clip_text = true
	locker_tab_button.pressed.connect(_on_tab.bind("locker"))
	stats_tab_button.pressed.connect(_on_tab.bind("stats"))
	others_tab_button.pressed.connect(_on_tab.bind("others"))
	ratings_tab_button.pressed.connect(_on_tab.bind("ratings"))
	interview_button.visible = _standout
	interview_button.pressed.connect(_on_interview_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	_render()
	_landscape_split.call_deferred()
	UiScroll.make_touch(self)

	# Ganaste una final de copa (o la Supercopa) → ceremonia de alzar el
	# trofeo antes de mostrar el resumen (pedido de Wilber).
	var comp: String = String(_fixture.get("competition", ""))
	var is_final_win: bool = String(_fixture.get("round_name", "")) == "Final" or String(_fixture.get("round_name", "")).ends_with("Final")
	var is_title_win: bool = bool(_context.get("won", false)) and (
		(comp == "cup" and String(_fixture.get("round_name", "")) == "Final")
		or comp == "supercup"
		or (comp == "cwc" and is_final_win)
		or (comp == "continental" and String(_fixture.get("round_name", "")) == "Final"))
	var league_clinched: bool = comp in ["", "league"] and not _fixture.is_empty() and _check_league_clinched()
	if not _fixture.is_empty() and is_title_win:
		_play_trophy_lift()
	elif league_clinched:
		_play_trophy_lift("league", "¡CAMPEÓN DE LIGA!")
	elif bool(_context.get("won", false)) and comp != "friendly" and not _fixture.is_empty():
		_celebrate_win()
	# Te lesionaste en este partido → parte médico con la decisión (P5).
	if _new_injury:
		InjuryDecision.open(self, _player)

## Confeti breve al ganar un partido oficial (sin trofeo).
func _celebrate_win() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	var cf := Confetti.new()
	cf.position = Vector2(288, -10)
	layer.add_child(cf)
	cf.burst(1.8)
	await get_tree().create_timer(3.0).timeout
	layer.queue_free()

## ¿El club del usuario acaba de dejar la liga MATEMÁTICAMENTE ganada (antes
## de la última fecha)? Se muestra una sola vez por temporada.
func _check_league_clinched() -> bool:
	if _player == null or WorldTickEngine.season.get("league_title_shown", false):
		return false
	var table: Array = WorldTickEngine.user_league_table()
	if table.size() < 2:
		return false
	var lg: LeagueData = WorldTickEngine._find_league(int(WorldTickEngine.season.get("league_id", -1)))
	if lg == null:
		return false
	var total_md: int = lg.matchdays()
	var me: Dictionary = LeagueTable.row_for(table, _player.club_id)
	if me.is_empty() or int(me.get("pos", 99)) != 1:
		return false
	var my_pts: int = int(me.get("pts", 0))
	# El rival más peligroso: el 2º, con lo máximo que aún puede sumar.
	var second: Dictionary = table[1]
	var second_pts: int = int(second.get("pts", 0))
	var second_left: int = maxi(0, total_md - int(second.get("pj", 0)))
	if my_pts > second_pts + second_left * 3:
		WorldTickEngine.season["league_title_shown"] = true
		SaveManager.save_season(WorldTickEngine.season)
		return true
	return false

## Overlay de celebración del título. Rediseñado 9-oct (Wilber: "organizá
## la ventanita de campeón para que se vea mejor"): tarjeta centrada con
## borde dorado → competición + escudo y club arriba, el TROFEO REAL con
## brillo y tu jugador festejando lado a lado, "¡CAMPEÓN!" y un botón
## pulsante. Antes eran piezas sueltas apiladas y tu jugador levantaba una
## copa genérica además del trofeo real (dos copas en pantalla).
func _play_trophy_lift(kind: String = "", champ_text: String = "¡CAMPEÓN!") -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.modulate.a = 0.0
	layer.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(470, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := Styles.card_flat(Color(0.07, 0.08, 0.11, 0.98), 22)
	sb.set_border_width_all(3)
	sb.border_color = Styles.GOLD
	sb.shadow_color = Color(1.0, 0.8, 0.2, 0.25)
	sb.shadow_size = 24
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)

	# --- Competición + club ---
	var _comp: String = kind if kind != "" else String(_fixture.get("competition", ""))
	var lg: LeagueData = WorldTickEngine._find_league(int(WorldTickEngine.season.get("league_id", -1)))
	var comp_name: String = "CAMPEONATO"
	match _comp:
		"league":
			comp_name = lg.league_name if lg != null else "LIGA"
		"cup":
			comp_name = String(WorldTickEngine.cup.get("cup_name", "COPA"))
		"cwc":
			comp_name = "MUNDIAL DE CLUBES"
		"continental":
			comp_name = "COPA CONTINENTAL"
		"supercup":
			comp_name = "SUPERCOPA"
	var comp_lbl := Label.new()
	comp_lbl.text = comp_name.to_upper()
	comp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comp_lbl.add_theme_font_override("font", Styles.font_black())
	comp_lbl.add_theme_font_size_override("font_size", 14)
	comp_lbl.add_theme_color_override("font_color", Styles.GOLD)
	col.add_child(comp_lbl)
	if _player != null and _player.club_id != "":
		var club_row := HBoxContainer.new()
		club_row.alignment = BoxContainer.ALIGNMENT_CENTER
		club_row.add_theme_constant_override("separation", 10)
		var crest := Styles.club_crest(_player.club_id, 44)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		club_row.add_child(crest)
		var club: ClubData = null
		if not WorldTickEngine.world.is_empty():
			club = WorldFactory.find_club(WorldTickEngine.world, _player.club_id)
		var cn := Label.new()
		cn.text = club.club_name if club != null else ""
		cn.add_theme_font_override("font", Styles.font_semibold())
		cn.add_theme_font_size_override("font_size", 18)
		cn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		club_row.add_child(cn)
		col.add_child(club_row)

	# --- Trofeo real (con brillo) + tu jugador festejando ---
	var tro: Control
	if _comp == "cwc":
		tro = Trophy.for_honor("mundial_clubes", 150)
	elif _comp == "continental":
		var cconf: String = String(_fixture.get("cont_conf", ""))
		var ctier: int = int(_fixture.get("cont_tier", 1))
		tro = Trophy.for_honor("cont_%s_%d" % [cconf, ctier] if cconf != "" else "continental_cup", 150)
	elif _comp == "supercup":
		var skind: String = String(_fixture.get("supercup_kind", "domestic"))
		tro = Trophy.for_honor("supercopa_cont" if skind == "continental" else "supercopa", 150)
	elif _comp == "league" or _comp == "cup":
		if lg != null:
			var tid: String = ("league_%d" % lg.league_id) if _comp == "league" else ("dcup_%s" % lg.country)
			tro = Trophy.for_title(tid, 150, 1)
		else:
			tro = Trophy.for_competition(_comp, 1, 150)
	else:
		tro = Trophy.for_competition("cup", 1, 150)
	# El mismo trofeo en 3D, girando (se parece a su dibujo: TrophySpecs)
	var tro_id: String = String(tro.get_meta("trophy_id", ""))
	if tro_id != "":
		tro.free()
		tro = TrophyViewer.make(tro_id, 150)
		(tro as TrophyViewer).zoomable = true # tocarla la abre en grande
	var stage := HBoxContainer.new()
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_theme_constant_override("separation", -10)
	var tro_holder := Control.new()
	tro_holder.custom_minimum_size = Vector2(170, 180)
	tro_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := Panel.new()
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color(1.0, 0.82, 0.25, 0.16)
	gs.set_corner_radius_all(90)
	gs.shadow_color = Color(1.0, 0.8, 0.2, 0.35)
	gs.shadow_size = 30
	glow.add_theme_stylebox_override("panel", gs)
	glow.position = Vector2(15, 20)
	glow.size = Vector2(140, 140)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tro_holder.add_child(glow)
	tro.position = Vector2(10, 200)   # arranca abajo, sube con rebote
	tro_holder.add_child(tro)
	stage.add_child(tro_holder)
	if _player != null:
		var celeb: String = "celeb_salto" if Avatar.has_anim("celeb_salto") else "trofeo_oro"
		var lift: Control = Avatar.build_anim(Avatar.celebration_config_for_player(_player, SaveManager.load_world_seed()), celeb, 204, true, 9.0)
		lift.custom_minimum_size = Vector2(204, 204)
		lift.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stage.add_child(lift)
	col.add_child(stage)

	var champ := Label.new()
	champ.text = champ_text
	champ.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	champ.add_theme_font_override("font", Styles.font_black())
	champ.add_theme_font_size_override("font_size", 36)
	champ.add_theme_color_override("font_color", Styles.GOLD)
	champ.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	champ.add_theme_constant_override("outline_size", 8)
	col.add_child(champ)
	var season_lbl := Label.new()
	var sy: int = WorldTickEngine.get_season_start_year()
	season_lbl.text = "Temporada %d/%d" % [sy, sy + 1]
	season_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	season_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	col.add_child(season_lbl)

	var cont := PanelContainer.new()
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cs := Styles.card_flat(Styles.GOLD, 20)
	cs.content_margin_left = 22
	cs.content_margin_right = 22
	cs.content_margin_top = 8
	cs.content_margin_bottom = 8
	cont.add_theme_stylebox_override("panel", cs)
	var sub := Label.new()
	sub.text = "Tocá para continuar"
	sub.add_theme_font_override("font", Styles.font_semibold())
	sub.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	cont.add_child(sub)
	col.add_child(cont)

	var tw := create_tween()
	tw.tween_property(dim, "color:a", 0.9, 0.3)
	tw.parallel().tween_property(center, "modulate:a", 1.0, 0.3)
	tw.tween_property(tro, "position:y", -6.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tro, "position:y", 12.0, 0.18)
	tw.tween_callback(func():
		var cf := Confetti.new()
		cf.position = Vector2(288, -10)
		layer.add_child(cf)
		cf.burst(3.5)
		Audio.match_sfx("trophy"))
	var bob := create_tween()
	bob.set_loops()
	bob.tween_property(tro, "position:y", 4.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(1.0)
	bob.tween_property(tro, "position:y", 12.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(cont, "modulate:a", 0.55, 0.7).set_delay(1.0)
	pulse.tween_property(cont, "modulate:a", 1.0, 0.7)

	# Bug de Wilber (9-oct): "sale toca para continuar y no continúa". El
	# CenterContainer de pantalla completa iba ENCIMA del `dim` y se quedaba
	# con el toque — y como es su HERMANO (no su hijo), el toque nunca le
	# llegaba al `dim`. Ahora un atrapa-toques transparente va ÚLTIMO
	# (arriba de todo) y es el que cierra. (OJO también: CanvasLayer no
	# tiene modulate — se funden `dim`/`center` y se libera el layer.)
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(catcher)
	var _dismissed: bool = false
	catcher.gui_input.connect(func(ev: InputEvent):
		if _dismissed or not ((ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.pressed):
			return
		_dismissed = true
		bob.kill()
		pulse.kill()
		var out := create_tween()
		out.tween_property(dim, "color:a", 0.0, 0.22)
		out.parallel().tween_property(center, "modulate:a", 0.0, 0.22)
		out.tween_callback(layer.queue_free))

func _on_tab(t: String) -> void:
	_tab = t
	_render()
	UiScroll.make_touch(self)

func _refresh_tabs() -> void:
	for pair in [[locker_tab_button, "locker"], [stats_tab_button, "stats"], [others_tab_button, "others"], [ratings_tab_button, "ratings"]]:
		var b: Button = pair[0]
		if pair[1] == _tab:
			Styles.tab(b, true)
		else:
			Styles.tab(b, false)

func _render() -> void:
	_refresh_tabs()
	for c in detail_box.get_children():
		c.queue_free()
	match _tab:
		"others":
			_render_others_tab()
		"ratings":
			_render_ratings_tab()
		"stats":
			_render_stats_tab()
		_:
			_render_locker_tab()

func _apply_static_styles() -> void:
	Styles.apply_display_font(score_label)
	score_label.add_theme_font_size_override("font_size", Styles.SIZE_DISPLAY + 10)
	result_banner_label.add_theme_font_override("font", Styles.font_black())
	result_banner_label.add_theme_font_size_override("font_size", 18)
	Styles.styled_button(interview_button, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
	Styles.styled_button(continue_button, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	interview_button.icon = Icons.load_icon(Icons.MICROPHONE)
	interview_button.add_theme_constant_override("icon_max_width", 26)
	continue_button.icon = Icons.load_icon(Icons.HOME)
	continue_button.add_theme_constant_override("icon_max_width", 28)

## Traspasado de Hub._ready(): registra el resultado real, actualiza la
## confianza del entrenador, tira una lesión si tocó, y suma a las
## estadísticas de temporada. Devuelve el entrenador (para la frase).
## +1 ganaste, 0 empate, -1 perdiste (penales cuentan). Para el efecto del
## RESULTADO sobre la confianza del DT.
func _match_result_sign() -> int:
	var sc: Dictionary = _result.get("score", {})
	var gh: int = int(sc.get("home", 0))
	var ga: int = int(sc.get("away", 0))
	var uh: bool = String(_fixture.get("home_club_id", "")) == _player.club_id
	var mine: int = gh if uh else ga
	var theirs: int = ga if uh else gh
	var tie_winner: String = String(_result.get("tie_winner", ""))
	if tie_winner != "":
		return 1 if ((tie_winner == "home") == uh) else -1
	if mine > theirs:
		return 1
	if mine < theirs:
		return -1
	var sw: String = String(_result.get("shootout_winner", ""))
	if sw != "":
		return 1 if ((sw == "home") == uh) else -1
	return 0

func _apply_match_consequences() -> CoachData:
	var sc: Dictionary = _result.get("score", {})
	var gh: int = int(sc.get("home", 0))
	var ga: int = int(sc.get("away", 0))
	var winner: String = String(_result.get("tie_winner", ""))
	if winner == "":
		winner = String(_result.get("shootout_winner", ""))
	if winner == "":
		winner = "home" if gh >= ga else "away"
	WorldTickEngine.record_user_result(_fixture, gh, ga, winner)
	var is_friendly: bool = _fixture.get("competition", "") == "friendly"

	# --- SANCIÓN ---
	# Si cumpliste sanción este partido, se descuenta un partido y no suma
	# nada a tus estadísticas (el equipo jugó sin vos).
	if MatchState.user_suspended:
		var left: int = maxi(0, int(WorldTickEngine.season.get("suspended_matches", 1)) - 1)
		WorldTickEngine.season["suspended_matches"] = left
		SaveManager.save_season(WorldTickEngine.season)
		var w0: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
		return WorldFactory.find_coach(w0, _player.club_id) if _player.club_id != "" else null
	# Roja o DOBLE AMARILLA → te perdés el próximo (2 partidos si fue roja
	# directa violenta, 1 si fue doble amarilla).
	if _result.get("user_red_carded", false) and not is_friendly:
		var games: int = 1 if _result.get("user_double_yellow", false) else 2
		WorldTickEngine.season["suspended_matches"] = maxi(int(WorldTickEngine.season.get("suspended_matches", 0)), games)
		SaveManager.save_season(WorldTickEngine.season)
	elif int(_result.get("user_yellows", 0)) > 0 and not is_friendly:
		# Amarillas sueltas: se acumulan (DisciplineEngine.add_user_yellows)
		_yellow_ban = DisciplineEngine.add_user_yellows(WorldTickEngine.season, int(_result.get("user_yellows", 0)))
		SaveManager.save_season(WorldTickEngine.season)

	# Estadísticas de temporada (Fase 9). Los amistosos de pretemporada no
	# cuentan para estas estadísticas, solo para forma/minutos (moral y
	# confianza del entrenador siguen su curso normal más abajo).
	# BUG REAL #1 (reporte de Wilber, "no me está contando las
	# titularidades"): `_player` es una instancia RECIÉN releída de disco
	# (SaveManager.load_player() en _ready(), arriba) — nunca era el
	# MISMO objeto que MatchLauncher.prepare() metió en starting_xi antes
	# del partido. Se arregló usando `MatchState.user_player` (la MISMA
	# referencia).
	# BUG REAL #2 (reporte de Wilber, "me está sumando titularidades
	# cuando solo he sido suplente"): ESE arreglo alcanzaba a titulares de
	# verdad, pero starting_xi.has(...) sigue siendo la señal EQUIVOCADA —
	# MatchEngine._maybe_substitute_user() REEMPLAZA tu lugar en
	# starting_xi cuando entrás de cambio (así la simulación te trata
	# como "en cancha"), así que después del partido ese arreglo ya NO
	# significa "quiénes arrancaron". Ahora se usa "user_started" del
	# resultado del motor (MatchEngine._user_is_starter, fijado UNA vez al
	# kickoff, antes de cualquier sustitución — ver run_match()).
	var started: bool = bool(_result.get("user_started", false))
	var goals_this_match: int = 0
	if started and not is_friendly:
		_player.season_appearances += 1
	# BUG REAL (Wilber: "solo cuenta los partidos como titular y no los
	# partidos jugados en la temporada, aparecí con 12 partidos en vez de
	# 30+ que jugué") — season_appearances (arriba) en realidad son
	# TITULARIDADES a propósito (así lo lee el objetivo "titularidades" y
	# el chip "Titular." del Hub), pero varias pantallas lo mostraban bajo
	# la etiqueta genérica "Partidos". season_matches_played (v28) cuenta
	# cualquier partido donde jugaste algún minuto, titular o suplente —
	# "user_played" ya viene calculado por el motor (MatchEngine.run_match()).
	if bool(_result.get("user_played", started)) and not is_friendly:
		_player.season_matches_played += 1
	for ev in _result.get("rating_events", []):
		match ev.get("type", ""):
			"goal":
				goals_this_match += 1
				if not is_friendly:
					_player.season_goals += 1
			"key_pass_success":
				if not is_friendly:
					_player.season_key_passes += 1

	# Prima por gol negociada en el contrato (ContractNegotiation): se paga
	# de verdad al balance del jugador por cada gol oficial.
	if goals_this_match > 0 and not is_friendly:
		var bonus: int = int(WorldTickEngine.season.get("contract_extras", {}).get("goal_bonus", 0))
		if bonus > 0:
			_player.balance += bonus * goals_this_match

	var rating: float = float(_result.get("user_rating", MatchRatingCalculator.BASE_RATING))

	# Rendimiento de la temporada: Σ notas / partidos (para "Premios
	# anuales" → pestaña Rendimiento). Estado no-schema → dict `season`.
	# BUG REAL (mismo de fondo que "solo cuenta los partidos como
	# titular", Wilber: "me dieron un 10 cuando mi rendimiento fue de
	# 7.6"): esto solo sumaba partidos de TITULAR — un suplente que entró
	# y tuvo minutos (con su propia nota real, calculada de verdad por
	# MatchRatingCalculator) no contaba para este promedio, achicando el
	# denominador de partidos y desalineando este número del que usa
	# SeasonReportEngine para la nota de fin de temporada. Se reinicia en
	# el rollover junto con season_matches_played.
	if bool(_result.get("user_played", started)) and not is_friendly:
		WorldTickEngine.season["user_rating_sum"] = float(WorldTickEngine.season.get("user_rating_sum", 0.0)) + rating
		WorldTickEngine.season["user_rating_games"] = int(WorldTickEngine.season.get("user_rating_games", 0)) + 1
		SaveManager.save_season(WorldTickEngine.season)

	# --- XP de atributos por el partido ---
	# Pedido de Wilber: cada partido suma XP a los atributos, MÁS cuanto
	# mejor la nota. Los amistosos suman la mitad. No suma si estuviste
	# sancionado (ya se devolvió arriba).
	var assists_this_match: int = int(_result.get("user_assists", 0))
	var xp_gains: Dictionary = PlayerDevelopment.match_xp_gains(_player, rating, goals_this_match, assists_this_match)
	if is_friendly:
		for k in xp_gains:
			xp_gains[k] = float(xp_gains[k]) * 0.5
	_attr_xp_result = PlayerDevelopment.grant_attribute_xp(_player, xp_gains)

	# --- Nivel de carrera + forma (schema v33, ProgressionEngine) ---
	var played_now: bool = bool(_result.get("user_played", started))
	_lv_before = _player.level
	_xp_before = _player.career_xp
	var derby: bool = bool(_fixture.get("derby", false))
	# + XP por la calidad de tus gestos (paquete de minijuegos, 10-oct).
	_gesture_xp = 0 if is_friendly else ProgressionEngine.gesture_xp(MatchState.gesture_stats)
	_lv_result = ProgressionEngine.add_xp(_player, ProgressionEngine.match_xp(rating, goals_this_match, assists_this_match, _match_result_sign() > 0, played_now, is_friendly, derby) + _gesture_xp)
	# CLÁSICO (P5): prima por ganarlo y el ánimo se mueve fuerte.
	if derby and not is_friendly:
		SocialLifeEngine.derby_mood(_player, _match_result_sign() > 0, _match_result_sign() < 0)
		if _match_result_sign() > 0:
			_derby_bonus = PrizeMoneyEngine.derby_win_bonus(_player.wage)
			_player.balance += _derby_bonus
	if played_now and not is_friendly:
		ProgressionEngine.push_rating(_player, rating)
		# Objetivos semanales (P5).
		var wd: int = WorldTickEngine.current_epoch_day
		var ws: int = SaveManager.load_world_seed()
		WeeklyGoalsEngine.bump(WorldTickEngine.season, wd, ws, "play2")
		if rating >= 7.0:
			WeeklyGoalsEngine.bump(WorldTickEngine.season, wd, ws, "rating7")
		if goals_this_match + assists_this_match > 0:
			WeeklyGoalsEngine.bump(WorldTickEngine.season, wd, ws, "contrib")
		if _match_result_sign() > 0:
			WeeklyGoalsEngine.bump(WorldTickEngine.season, wd, ws, "win1")
		# Química (P5): jugar con ellos los acerca.
		SocialLifeEngine.add_chemistry(_player, WorldTickEngine.season, SocialLifeEngine.CHEM_MATCH)
		SaveManager.save_season(WorldTickEngine.season)

	# --- Desgaste físico del partido ---
	# La energía SOLO baja jugando (pedido de Wilber). Un partido oficial
	# completo pega fuerte; el amistoso, menos. Tu resistencia (atributo
	# stamina) amortigua. Se recupera descansando días (WorldTickEngine).
	# Fórmula centralizada en PlayerDevelopment (Parte 91): la usa también
	# NationalMatchSummary.gd, para que un partido de selección canse
	# igual que uno de club de cara al SIGUIENTE partido, sea cual sea.
	# Bug real de la auditoría (ronda 6): faltaba el mismo chequeo
	# "user_played" que ya usan season_matches_played/user_rating_sum un
	# poco más arriba — un convocado que se quedó los 90' en el banco (no
	# sancionado, simplemente no elegido) recibía el mismo golpe de
	# fatiga que si hubiera jugado el partido completo, contradiciendo
	# directamente el comentario de arriba ("La energía SOLO baja
	# jugando").
	if not MatchState.user_suspended and bool(_result.get("user_played", started)):
		_player.fatigue_physical = PlayerDevelopment.physical_fatigue_after_match(_player, not is_friendly)

	var coach: CoachData = null
	if _player.club_id != "":
		var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
		coach = WorldFactory.find_coach(world, _player.club_id)
		CoachRelations.apply_match_result(_player, coach, rating, _match_result_sign())

	var injury_rng := RandomNumberGenerator.new()
	injury_rng.seed = hash("injury:%d" % WorldTickEngine.current_epoch_day) ^ SaveManager.load_world_seed()
	# El fisio del staff personal (StaffEngine) recorta los días de baja
	# (PlayerDevelopment.apply_match_injury, centralizado en Parte 91).
	var inj_before: int = _player.injury_days_remaining
	PlayerDevelopment.apply_match_injury(_player, bool(_result.get("user_injured", false)), injury_rng)
	_new_injury = _player.injury_days_remaining > inj_before and inj_before == 0

	# Desgaste mental (fatigue_mental): una derrota o un mal partido suben la
	# tensión; un partidazo la baja. Se recupera unos puntos por día en
	# WorldTickEngine y, si sube, penaliza tus decisiones del próximo partido
	# (MatchEngine._carried_fatigue_penalty = física + mental). No cuenta en
	# amistosos de pretemporada.
	if not is_friendly:
		var user_home: bool = _fixture.get("home_club_id", "") == _player.club_id
		var user_won: bool = (winner == "home") == user_home
		var mental_delta: float = 0.0
		if rating < 5.5:
			mental_delta += 8.0
		if not user_won and gh != ga:
			mental_delta += 5.0
		if rating >= 7.5:
			mental_delta -= 6.0
		# El rasgo "Motor incansable" también amortigua la tensión que se
		# acumula (nunca la recuperación, que sigue plena).
		if mental_delta > 0.0:
			mental_delta *= Traits.fatigue_factor(_player)
		if mental_delta != 0.0:
			_player.fatigue_mental = clampf(_player.fatigue_mental + mental_delta, 0.0, 100.0)

	# Consumir los efectos "de un solo partido" de la Tienda (suplemento
	# pre-partido, vendaje preventivo) — el partido ya se jugó, sea de liga,
	# copa o amistoso (MatchEngine los aplica en cualquiera).
	_consume_one_match_effect("match_boost_matches")
	_consume_one_match_effect("injury_shield_matches")
	if bool(_result.get("user_played", false)):
		_consume_one_match_effect("reinjury_risk_matches")

	# Prensa (backlog: estado persistente, ver PressGenerator.gd). No cada
	# partido da titular — solo cuando hay algo que contar. Un amistoso de
	# pretemporada no genera prensa (no cuenta para tu carrera real).
	if not is_friendly:
		var press_rng := RandomNumberGenerator.new()
		var wseed: int = SaveManager.load_world_seed()
		press_rng.seed = hash("press:%d" % WorldTickEngine.current_epoch_day) ^ wseed
		var narrative: String = String(WorldTickEngine.season.get("press_narrative", ""))
		var nick: String = Nickname.for_player(_player, wseed)
		# Contexto para titulares con historia (clásico, final, debut, hito).
		var pworld: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(wseed)
		var uh_p: bool = String(_fixture.get("home_club_id", "")) == _player.club_id
		var opp_id: String = String(_fixture.get("away_club_id" if uh_p else "home_club_id", ""))
		var opp_club: ClubData = WorldFactory.find_club(pworld, opp_id)
		var rn: String = String(_fixture.get("round_name", "")).to_lower()
		var press_ctx: Dictionary = {
			"won": bool(_context.get("won", false)),
			"opp": (opp_club.short_name if opp_club != null else "el rival"),
			"is_rival": opp_id != "" and RivalryEngine.club_rival_for(pworld, _player.club_id, wseed) == opp_id,
			"is_final": rn.contains("final") and String(_fixture.get("competition", "")) in ["cup", "continental", "supercup"],
			"career_goals": _player.career_goals + _player.season_goals,
			"debut": (_player.career_matches + _player.season_matches_played) <= 1,
			"flair": _goal_flair(),
		}
		var news: Dictionary = PressGenerator.headline_for_match(_player.player_name, goals_this_match, rating, press_rng, narrative, nick, press_ctx)
		PressGenerator.append_to_feed(_player, news, WorldTickEngine.current_epoch_day)
		# Envión de seguidores por lo que hiciste en la cancha (no solo por publicar).
		press_ctx["goals"] = goals_this_match
		press_ctx["rating"] = rating
		var fbump: int = SocialEngine.match_follower_bump(_player, press_ctx)
		if fbump > 0 and not WorldTickEngine.season.is_empty():
			var soc: Dictionary = (WorldTickEngine.season.get("social", {}) as Dictionary).duplicate()
			soc["bonus_followers"] = int(soc.get("bonus_followers", 0)) + fbump
			WorldTickEngine.season["social"] = soc
			SaveManager.save_season(WorldTickEngine.season)
		# Polémica en redes (ControversyEngine): una roja, comerte tus palabras
		# o festejar ante el rival pueden volverse tendencia.
		if not WorldTickEngine.season.is_empty() and bool(_result.get("user_played", false)):
			var cctx := {"red_card": bool(_result.get("user_red_carded", false)), "rating": rating,
				"won": bool(press_ctx.get("won", false)), "goals": goals_this_match,
				"is_rival": bool(press_ctx.get("is_rival", false))}
			if not ControversyEngine.check_match(_player, WorldTickEngine.season, cctx,
					WorldTickEngine.current_epoch_day, press_rng).is_empty():
				SaveManager.save_season(WorldTickEngine.season)
		# Reacción del DT rival (guerra psicológica), a veces.
		if press_rng.randf() < 0.55:
			var mg := RivalMindGamesEngine.post_match(WorldTickEngine, _fixture, _result, _player)
			if not mg.is_empty():
				PressGenerator.append_to_feed(_player, mg.get("headline", {}), WorldTickEngine.current_epoch_day)
		# Humor de la afición: lo mueve el resultado + tu nota (la zona mixta
		# ya lo tocó por su lado). Decae solo hacia el neutro en advance_day.
		if not WorldTickEngine.season.is_empty():
			var user_home2: bool = _fixture.get("home_club_id", "") == _player.club_id
			var user_won2: bool = (winner == "home") == user_home2
			var fan_delta: int = 0
			if user_won2: fan_delta += 3 + (2 if gh != ga and absi(gh - ga) >= 3 else 0)
			elif gh == ga: fan_delta += 0
			else: fan_delta -= 4 + (2 if absi(gh - ga) >= 3 else 0)
			if rating >= 7.5: fan_delta += 3
			elif rating < 5.5: fan_delta -= 2
			if goals_this_match > 0: fan_delta += 2 * goals_this_match
			var fs: int = int(WorldTickEngine.season.get("fan_sentiment", InterviewEngine.FAN_DEFAULT))
			WorldTickEngine.season["fan_sentiment"] = clampi(fs + fan_delta, 0, 100)
			# RIVAL PERSONAL (10-oct): historial de la temporada contra su club.
			if opp_id != "" and opp_id == ImmersionEngine.nemesis_club_id(pworld, _player.club_id, wseed):
				ImmersionEngine.log_nemesis_match(_player, WorldTickEngine.current_epoch_day,
					_match_result_sign(), goals_this_match, rating, WorldTickEngine.get_season_start_year(), opp_id)
			SaveManager.save_season(WorldTickEngine.season)

	# RETO DEL DT (10-oct): mismo reto que mostró la previa (determinista).
	_challenge = CoachChallengeEngine.for_fixture(_player, _fixture)
	_challenge_met = CoachChallengeEngine.is_met(_challenge, _result, _match_result_sign(), MatchState.gesture_stats)
	if _challenge_met:
		_player.coach_trust = clampi(_player.coach_trust + CoachChallengeEngine.REWARD_TRUST, 0, 100)
		ProgressionEngine.add_xp(_player, CoachChallengeEngine.REWARD_XP)
	# MAESTRÍAS (RPG, 10-oct): lo que hiciste en el partido suma a su rama.
	if not is_friendly:
		_mastery_ups = CareerRpgEngine.add_match_actions(_player, _result.get("rating_events", []))
	# LOGROS que se cumplieron con este partido (dan XP de carrera).
	_new_achievements = CareerRpgEngine.sync_achievements(_player)
	SaveManager.save_player(_player)
	return coach

func _consume_one_match_effect(key: String) -> void:
	var left: int = int(_player.active_effects.get(key, 0)) - 1
	if left <= 0:
		_player.active_effects.erase(key)
	elif _player.active_effects.has(key):
		_player.active_effects[key] = left

## Tarjeta de marcador (siempre visible arriba de las viñetas): banner de
## resultado, escudos, marcador, narrativa.
func _render_score_card() -> void:
	var sc: Dictionary = _result.get("score", {})
	var gh: int = int(sc.get("home", 0))
	var ga: int = int(sc.get("away", 0))
	score_label.text = "%d - %d" % [gh, ga]
	if bool(_result.get("has_tie_carry", false)):
		var aggregate: Dictionary = _result.get("aggregate_score", {})
		score_label.text += "\nGLOBAL  %d - %d" % [int(aggregate.get("home", gh)), int(aggregate.get("away", ga))]

	var won: bool = bool(_context.get("won", false))
	var result_color: Color = Styles.CARD_DARK_2
	if not _fixture.is_empty():
		var return_leg: bool = _fixture.has("tie_agg") or int(_fixture.get("leg", 0)) == 2
		if return_leg and String(_result.get("tie_winner", "")) != "":
			result_banner_label.text = "¡CLASIFICADO!" if won else "ELIMINADO"
			result_color = Styles.GREEN if won else Styles.RED
		elif gh == ga and _result.get("shootout_winner", "") == "":
			result_banner_label.text = "EMPATE"
			result_color = Styles.AMBER
		elif won:
			result_banner_label.text = "¡VICTORIA!"
			result_color = Styles.GREEN
		else:
			result_banner_label.text = "DERROTA"
			result_color = Styles.RED
	else:
		result_banner_label.text = "FIN DEL PARTIDO"
	result_banner_label.add_theme_color_override("font_color", result_color)
	var rc_style := Styles.card_accent(result_color, Styles.CARD_DARK, 16)
	rc_style.border_width_top = 4
	rc_style.border_color = result_color
	score_card.add_theme_stylebox_override("panel", rc_style)
	_render_score_header(gh, ga, _user_is_home)

	var narrative: String = _build_narrative(gh, ga, _user_is_home)
	if bool(_result.get("extra_time_played", false)):
		narrative = "Se resolvió en prórroga. " + narrative
	if String(_result.get("shootout_winner", "")) != "":
		var shootout_score: Array = _result.get("shootout_score", [])
		if shootout_score.size() == 2:
			narrative = "Tanda de penales %d-%d. %s" % [int(shootout_score[0]), int(shootout_score[1]), narrative]
	if _result.get("user_red_carded", false):
		narrative += " Terminaste expulsado."
	elif int(_result.get("user_yellows", 0)) > 0 and _fixture.get("competition", "") != "friendly":
		var acc: int = int(WorldTickEngine.season.get("user_yellow_count", 0))
		narrative += " Viste la amarilla (%d acumuladas)." % acc
		if _yellow_ban:
			narrative += " Llegaste a %d: te perdés el próximo partido." % acc
	if _result.get("user_injured", false):
		narrative += " Terminaste lesionado."
	narrative_label.text = narrative

# --- Viñeta: Estadísticas ---

## VESTUARIO: lo que pasa puertas adentro después del partido — la charla
## del DT y los compañeros, lo que ganaste (nivel, atributos, maestrías,
## logros) y los premios.
func _render_locker_tab() -> void:
	_render_locker_room()
	if _standout:
		var s := Label.new()
		s.text = "★  Actuación destacada"
		s.add_theme_color_override("font_color", Styles.GOLD)
		s.add_theme_font_override("font", Styles.font_semibold())
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_box.add_child(s)
	if _derby_bonus > 0:
		var dl := Label.new()
		dl.text = "🔥 ¡Ganaste el clásico!  Prima %s · XP ×1.5" % CurrencyFormat.format(_derby_bonus)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.add_theme_font_override("font", Styles.font_black())
		dl.add_theme_color_override("font_color", Styles.GOLD)
		detail_box.add_child(dl)
	# Progreso del partido (v33): nivel + atributos, animado (ProgressPanel).
	if not _lv_result.is_empty():
		var pp := ProgressPanel.new().setup(_player, _lv_before, _xp_before, _lv_result, _attr_xp_result)
		pp.open_skills.connect(func():
			SkillsPanel.open(self))
		detail_box.add_child(pp)
	_render_rpg_gains()

## ESTADÍSTICAS: solo los números — figura del partido, tu aporte, tus
## jugadas en la cancha y las estadísticas de los dos equipos.
func _render_stats_tab() -> void:
	_render_mvp_card()

	# Tu aporte
	detail_box.add_child(Styles.section_label("TU PARTIDO"))
	var mine := PanelContainer.new()
	mine.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD))
	var mm := MarginContainer.new()
	mm.add_theme_constant_override("margin_left", 14)
	mm.add_theme_constant_override("margin_top", 12)
	mm.add_theme_constant_override("margin_right", 14)
	mm.add_theme_constant_override("margin_bottom", 12)
	var mrow := HBoxContainer.new()
	mrow.add_child(_stat_column(str(int(_result.get("user_goals", _context.get("goals", 0)))), "Goles"))
	mrow.add_child(_stat_column(str(int(_result.get("user_assists", 0))), "Asist."))
	mrow.add_child(_stat_column("%.1f" % float(_result.get("user_rating", MatchRatingCalculator.BASE_RATING)), "Tu nota"))
	var mcol := VBoxContainer.new()
	mcol.add_theme_constant_override("separation", 6)
	mcol.add_child(mrow)
	var g: int = int(_result.get("user_goals", _context.get("goals", 0)))
	var bonus: int = int(WorldTickEngine.season.get("contract_extras", {}).get("goal_bonus", 0))
	if g > 0 and bonus > 0 and _fixture.get("competition", "") != "friendly":
		var bl := Label.new()
		bl.text = "Prima por gol: +%s  (%d × %s)" % [CurrencyFormat.format(bonus * g), g, CurrencyFormat.format(bonus)]
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.add_theme_color_override("font_color", Styles.GREEN)
		bl.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		mcol.add_child(bl)
	mm.add_child(mcol)
	mine.add_child(mm)
	detail_box.add_child(mine)

	# Tus jugadas en la cancha (Paquete 2 del ROADMAP): dónde tuviste cada
	# momento clave y cómo salió (MatchState.moment_map, lo llena Match.gd
	# con la cancha 2D). Vacío en partidos simulados → no se muestra.
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

	# Estadísticas del partido — versión EXTENDIDA compartida (MatchStatsView).
	var ms: Dictionary = _result.get("match_stats", {})
	if not ms.is_empty():
		detail_box.add_child(Styles.section_label("ESTADÍSTICAS DEL PARTIDO"))
		var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
		var home := WorldFactory.find_club(world, _fixture.get("home_club_id", ""))
		var away := WorldFactory.find_club(world, _fixture.get("away_club_id", ""))
		var hc: Color = Color(home.primary_color_hex) if (home != null and not home.primary_color_hex.is_empty()) else Styles.BLUE
		var ac: Color = Color(away.primary_color_hex) if (away != null and not away.primary_color_hex.is_empty()) else Styles.RED
		var gh_s: int = int(_result.get("score", {}).get("home", 0))
		var ga_s: int = int(_result.get("score", {}).get("away", 0))
		var key: String = "%s|%d" % [String(_fixture.get("home_club_id", "")), SaveManager.load_world_seed()]
		MatchStatsView.render(detail_box, ms, gh_s, ga_s, key, hc, ac, false)


## Lo que ganaste en el RPG con este partido: maestrías que subieron y
## logros cobrados. No se dibuja si no hubo nada.
func _render_rpg_gains() -> void:
	var gs: Dictionary = MatchState.gesture_stats
	var gestures: int = int(gs.get("perfecto", 0)) + int(gs.get("bueno", 0)) + int(gs.get("regular", 0)) + int(gs.get("flojo", 0))
	if _mastery_ups.is_empty() and _new_achievements.is_empty() and gestures == 0 and _challenge.is_empty():
		return
	detail_box.add_child(Styles.section_label("PROGRESO DE CARRERA"))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD))
	var m := MarginContainer.new()
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 14)
	for s in ["top", "bottom"]: m.add_theme_constant_override("margin_" + s, 10)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	if not _challenge.is_empty():
		var cl := Label.new()
		cl.text = ("🎯 Reto del DT CUMPLIDO: +%d confianza · +%d XP" % [CoachChallengeEngine.REWARD_TRUST, CoachChallengeEngine.REWARD_XP]) if _challenge_met else "🎯 Reto del DT sin cumplir: " + String(_challenge.get("text", ""))
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.add_theme_color_override("font_color", Styles.GOLD if _challenge_met else Styles.GRAY_TEXT)
		if _challenge_met:
			cl.add_theme_font_override("font", Styles.font_semibold())
		v.add_child(cl)
	if gestures > 0:
		var gl := Label.new()
		gl.text = "Tus toques: %d perfectos · %d buenos · %d regulares · %d flojos" % [int(gs.get("perfecto", 0)), int(gs.get("bueno", 0)), int(gs.get("regular", 0)), int(gs.get("flojo", 0))]
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(gl)
		var gl2 := Label.new()
		gl2.text = "Mejor racha: %d seguidos%s" % [int(gs.get("best_streak", 0)), ("  ·  +%d XP de carrera" % _gesture_xp) if _gesture_xp > 0 else ""]
		gl2.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		gl2.add_theme_color_override("font_color", Styles.GREEN if _gesture_xp > 0 else Styles.GRAY_TEXT)
		v.add_child(gl2)
	for up in _mastery_ups:
		var info: Dictionary = CareerRpgEngine.MASTERY[String(up["branch"])]
		var l := Label.new()
		l.text = "▲ Maestría de %s: nivel %d" % [String(info["name"]), int(up["level"])]
		l.add_theme_color_override("font_color", Color(String(info["color"])))
		l.add_theme_font_override("font", Styles.font_semibold())
		v.add_child(l)
	for a in _new_achievements:
		var l2 := Label.new()
		l2.text = "★ Logro: %s  (+%d XP)" % [String(a["name"]), int(a["xp"])]
		l2.add_theme_color_override("font_color", Styles.GOLD)
		l2.add_theme_font_override("font", Styles.font_semibold())
		v.add_child(l2)
	m.add_child(v)
	panel.add_child(m)
	detail_box.add_child(panel)

## VESTUARIO (10-oct, Wilber): un compañero te comenta el partido y el DT
## reacciona según tu nota. Fondo del vestuario de PixelLab.
func _render_locker_room() -> void:
	if _fixture.is_empty() or MatchState.user_suspended:
		return
	var seed_i: int = SaveManager.load_world_seed()
	var user_team: MatchTeam = MatchState.home_team if _user_is_home else MatchState.away_team
	var mate_name: String = ""
	if user_team != null:
		var mates: Array = user_team.starting_xi.filter(func(p): return p != null and p.player_name != _player.player_name)
		if not mates.is_empty():
			mate_name = String(mates[absi(hash("mate|%d" % int(_fixture.get("epoch_day", 0)))) % mates.size()].player_name)
	if mate_name == "":
		return
	var you: String = _player.player_name.split(" ", false)[0]
	var lr: Dictionary = ImmersionEngine.locker_room({
		"rating": float(_result.get("user_rating", MatchRatingCalculator.BASE_RATING)),
		"goals": int(_result.get("user_goals", _context.get("goals", 0))),
		"assists": int(_result.get("user_assists", 0)),
		"won": _match_result_sign() > 0, "draw": _match_result_sign() == 0,
		"derby": bool(_fixture.get("derby", false)),
		"mate_name": mate_name, "coach_name": _coach.coach_name if _coach != null else "El DT",
		"key": "%s|%d" % [_player.player_name, int(_fixture.get("epoch_day", 0))], "you": you,
	})
	detail_box.add_child(Styles.section_label("EN EL VESTUARIO"))
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.1)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	panel.clip_contents = true
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, 222)
	panel.add_child(stack)
	if ResourceLoader.exists("res://assets/scenes/locker.png"):
		var bg := TextureRect.new()
		bg.texture = load("res://assets/scenes/locker.png")
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.modulate = Color(0.55, 0.55, 0.6)
		stack.add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12
	col.offset_right = -12
	col.offset_top = 12
	col.offset_bottom = -12
	col.add_theme_constant_override("separation", 10)
	stack.add_child(col)
	var mate_cfg: Dictionary = Avatar.config_for_npc(mate_name, "player", seed_i)
	col.add_child(_locker_bubble(Avatar.build(mate_cfg, 52), mate_name, String(lr["mate_line"]), Styles.GREEN, false))
	if _coach != null:
		var ccfg: Dictionary = Avatar.config_for_npc(_coach.coach_name, "coach", seed_i)
		if String(lr["coach_expr"]) != "":
			ccfg = Avatar.with_expression(ccfg, String(lr["coach_expr"]))
		var mood_col: Color = {"great": Styles.GOLD, "good": Styles.GREEN, "ok": Styles.GRAY_TEXT, "bad": Styles.RED}.get(String(lr["mood"]), Styles.PURPLE)
		var trust_txt: String = ("  · confianza %+d" % _trust_delta) if _trust_delta != 0 else ""
		col.add_child(_locker_bubble(Avatar.build(ccfg, 52), "%s (DT)%s" % [_coach.coach_name, trust_txt], String(lr["coach_line"]), mood_col, true))
	detail_box.add_child(panel)

## Burbuja de chat del vestuario: cara + nombre + frase.
func _locker_bubble(face: Control, who: String, text: String, accent: Color, right: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var frame: Control = Styles.portrait_frame(face, 52, accent)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var bub := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.14, 0.92)
	sb.set_corner_radius_all(12)
	sb.border_color = accent
	sb.border_width_left = 0 if right else 3
	sb.border_width_right = 3 if right else 0
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 7
	sb.content_margin_bottom = 8
	bub.add_theme_stylebox_override("panel", sb)
	bub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bc := VBoxContainer.new()
	bc.add_theme_constant_override("separation", 2)
	var n := Label.new()
	n.text = who
	n.add_theme_font_override("font", Styles.font_semibold())
	n.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	n.add_theme_color_override("font_color", accent)
	bc.add_child(n)
	var t := Label.new()
	t.text = "«%s»" % text
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bc.add_child(t)
	bub.add_child(bc)
	if right:
		row.add_child(bub)
		row.add_child(frame)
	else:
		row.add_child(frame)
		row.add_child(bub)
	return row

# --- Viñeta: Otros partidos ---

func _render_others_tab() -> void:
	var others: Array = WorldTickEngine.other_matchday_scores(_fixture, 1.0) if WorldTickEngine.has_method("other_matchday_scores") else []
	if others.is_empty():
		var e := Label.new()
		e.text = "No hay otros partidos de esta jornada para mostrar (copa o torneo continental)."
		UiKit.empty_icon(e, Icons.PX_CALENDAR)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		detail_box.add_child(e)
		return
	detail_box.add_child(Styles.section_label("OTROS PARTIDOS DE LA JORNADA"))
	for m in others:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", Styles.card(Styles.CARD_DARK, 8))
		var mm := MarginContainer.new()
		mm.add_theme_constant_override("margin_left", 12)
		mm.add_theme_constant_override("margin_top", 8)
		mm.add_theme_constant_override("margin_right", 12)
		mm.add_theme_constant_override("margin_bottom", 8)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var lh := Label.new()
		lh.text = String(m["home_name"])
		lh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lh.clip_text = true
		var mid := Label.new()
		mid.text = "  %d - %d  " % [int(m["gh"]), int(m["ga"])]
		mid.add_theme_font_override("font", Styles.font_semibold())
		var la := Label.new()
		la.text = String(m["away_name"])
		la.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		la.clip_text = true
		la.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if m.has("home_id"):
			hb.add_child(_others_crest(String(m["home_id"])))
		hb.add_child(lh)
		hb.add_child(mid)
		hb.add_child(la)
		if m.has("away_id"):
			hb.add_child(_others_crest(String(m["away_id"])))
		mm.add_child(hb)
		row.add_child(mm)
		detail_box.add_child(row)

func _others_crest(club_id: String) -> Control:
	var c := Styles.club_crest(club_id, 20)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c

## Figura del partido: cara (Kenney) + trofeo MVP al lado + nota.
func _render_mvp_card() -> void:
	var ratings: Array = _result.get("player_ratings", [])
	if ratings.is_empty():
		return
	var mvp: Dictionary = ratings[0]
	var seed_int: int = SaveManager.load_world_seed()
	var is_user: bool = bool(mvp.get("is_user", false))
	var club_id: String = String(_fixture.get("%s_club_id" % String(mvp.get("team", "home")), ""))

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
	if club_id != "":
		var cr := Styles.club_crest(club_id, 18)
		cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sub.add_child(cr)
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

# --- Viñeta: Valoraciones (sub-viñetas por equipo) ---

func _render_ratings_tab() -> void:
	var ratings: Array = _result.get("player_ratings", [])
	var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	var home := WorldFactory.find_club(world, _fixture.get("home_club_id", ""))
	var away := WorldFactory.find_club(world, _fixture.get("away_club_id", ""))
	var home_name: String = home.club_name if home != null else "Local"
	var away_name: String = away.club_name if away != null else "Visitante"

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


## Cabecera del marcador con los dos clubes y su color, para que no se vea
## un "3 - 1" pelado. Se arma en código sobre ScoreVBox, encima del score.
func _render_score_header(gh: int, ga: int, user_is_home: bool) -> void:
	var vbox: VBoxContainer = $Root/ScoreCard/ScoreMargin/ScoreVBox
	if vbox.has_node("TeamsHeader"):
		vbox.get_node("TeamsHeader").queue_free()
	var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	var home := WorldFactory.find_club(world, _fixture.get("home_club_id", ""))
	var away := WorldFactory.find_club(world, _fixture.get("away_club_id", ""))
	if home == null or away == null:
		return
	var row := HBoxContainer.new()
	row.name = "TeamsHeader"
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_team_chip(home.club_name, home.primary_color_hex, gh > ga))
	var vs := Label.new()
	vs.text = "vs"
	vs.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	vs.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	row.add_child(vs)
	row.add_child(_team_chip(away.club_name, away.primary_color_hex, ga > gh))
	vbox.add_child(row)
	vbox.move_child(row, 1) # bajo el banner, encima del score

func _team_chip(name: String, color_hex: String, winner: bool) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 4)
	var c: Color = Color(color_hex) if not color_hex.is_empty() else Styles.GRAY_TEXT
	bar.add_theme_stylebox_override("panel", Styles.card(c, 2))
	col.add_child(bar)
	var lbl := Label.new()
	lbl.text = name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	if winner:
		lbl.add_theme_font_override("font", Styles.font_semibold())
	else:
		lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	col.add_child(lbl)
	return col

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

## ¿Pasó el usuario el cruce a doble partido? (el agregado ya quedó
## grabado por WorldTickEngine._record_cup_leg / _record_continental_result).
func _cup_tie_advanced() -> bool:
	var tk: String = String(_fixture.get("tie_key", ""))
	var parts: PackedStringArray = tk.split(":", true, 2)
	if parts.size() < 3:
		return bool(_context.get("won", false))
	var r: int = int(String(parts[0]).trim_prefix("R"))
	var h: String = parts[1]
	var a: String = parts[2]
	var store: String = "cont_results" if String(_fixture.get("competition", "")) == "continental" else "results"
	var res: Dictionary = WorldTickEngine.season.get(store, {}).get(SeasonEngine.cup_result_key(r, h, a), {})
	if res.is_empty():
		return bool(_context.get("won", false))
	var winner: String = String(res.get("winner", ""))
	return (winner == "home" and _player.club_id == h) or (winner == "away" and _player.club_id == a)

func _build_narrative(gh: int, ga: int, user_is_home: bool) -> String:
	if _fixture.is_empty():
		return "Partido de prueba, no cuenta para tu carrera."
	var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	var home := WorldFactory.find_club(world, _fixture.get("home_club_id", ""))
	var away := WorldFactory.find_club(world, _fixture.get("away_club_id", ""))
	var home_name: String = home.club_name if home != null else "Local"
	var away_name: String = away.club_name if away != null else "Visitante"
	var verb: String = "empató con" if gh == ga else ("venció a" if gh > ga else "cayó ante")
	var line: String = "%s %s %s %d-%d." % [home_name, verb, away_name, gh, ga]

	var goals: int = int(_context.get("goals", 0))
	if goals == 1:
		line += " Anotaste un gol."
	elif goals >= 2:
		line += " Anotaste %d goles." % goals

	if _fixture.get("competition", "") in ["cup", "continental"]:
		var is_cont: bool = _fixture.get("competition", "") == "continental"
		var comp_lbl: String = String(_fixture.get("cont_name", "la copa continental")) if is_cont else "la copa"
		var user_won: bool = bool(_context.get("won", false))
		if String(_fixture.get("cont_phase", "")) in ["group", "swiss"]:
			if _context.get("won", false):
				line += " Sumás en la fase de grupos de %s." % comp_lbl
			elif gh == ga:
				line += " Repartís puntos en la fase de grupos de %s." % comp_lbl
			else:
				line += " Tropiezo en la fase de grupos de %s." % comp_lbl
		elif _fixture.has("leg"):
			if int(_fixture["leg"]) == 1:
				line += " Falta la vuelta para definir el cruce."
			else:
				var advanced: bool = _cup_tie_advanced()
				line += " Pasás de ronda por el global." if advanced else " Quedás eliminado por el global."
		elif _fixture.get("round_name", "") == "Final":
			if is_cont:
				line += " ¡CAMPEÓN DE %s!" % comp_lbl.to_upper() if user_won else " Subcampeón continental. Cerquísima."
			else:
				line += " ¡Campeón de copa!" if user_won else " Se escapa el título en la final."
		else:
			line += " Avanzás de ronda." if user_won else " Quedás eliminado de %s." % comp_lbl
	elif _fixture.get("competition", "") == "supercup":
		var scn: String = String(_fixture.get("name", "Supercopa"))
		line += " ¡%s para tu vitrina!" % scn if bool(_context.get("won", false)) else " La %s se queda en la otra vitrina." % scn
	elif _fixture.get("competition", "") == "cwc":
		var won2: bool = bool(_context.get("won", false))
		if String(_fixture.get("cwc_phase", "")) == "group":
			line += " Suma en el grupo del Mundial de Clubes." if won2 else " Tropiezo en el grupo del Mundial de Clubes."
		elif String(_fixture.get("round_name", "")) == "Final":
			line += " ¡CAMPEONES DEL MUNDO!" if won2 else " Subcampeones del mundo. Cerca."
		else:
			line += " Avanzás en el Mundial de Clubes." if won2 else " Eliminados del Mundial de Clubes."
	elif _fixture.get("competition", "") == "friendly":
		line += " Amistoso de pretemporada: no cuenta para la tabla ni tus estadísticas."
	return line

func _on_interview_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/PostMatchInterview/PostMatchInterview.tscn")

func _on_continue_pressed() -> void:
	var dest: String = MatchState.return_scene
	MatchState.clear()
	# Al terminar el partido, pasa solo al día siguiente para que se vean
	# reflejados los resultados de la jornada (pedido explícito). Si el
	# avance destapa una decisión de contrato o el cierre de temporada, va
	# a la pantalla que corresponde en vez de al Hub.
	if not _fixture.is_empty() and dest == "res://scenes/Hub/Hub.tscn":
		WorldTickEngine.advance_day()
		if WorldTickEngine.season.get("awaiting_contract_decision", false):
			dest = "res://scenes/ContractDecision/ContractDecision.tscn"
		elif not WorldTickEngine.last_season_report.is_empty():
			dest = "res://scenes/SeasonCeremony/SeasonCeremony.tscn"
	get_tree().change_scene_to_file(dest)


## HORIZONTAL (FootballLegacy H): izquierda el resultado (y Entrevista /
## Continuar abajo); derecha las pestañas con su contenido a todo el alto.
## Antes el marcador se comía media pantalla y el detalle quedaba en una
## franja finita.
func _landscape_split() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= vp.y:
		return
	var root := $Root as VBoxContainer
	var tabs: Control = stats_tab_button.get_parent() as Control
	var sc: Control = $Root/Scroll as Control
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.75
	left.add_theme_constant_override("separation", 10)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	cols.add_child(left)
	cols.add_child(right)
	var kids: Array = root.get_children()
	root.add_child(cols)
	root.move_child(cols, 0)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for k in kids:
		if k == tabs or k == sc:
			continue
		if k == interview_button or k == continue_button:
			continue
		(k as Node).reparent(left)
	left.add_child(spacer)
	interview_button.reparent(left)
	continue_button.reparent(left)
	tabs.reparent(right)
	sc.reparent(right)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL


## Partido 3D: "bicycle" / "volley" si marcaste así (para el titular).
func _goal_flair() -> String:
	var best := ""
	for gp in _result.get("user_goal_plays", []):
		if bool(gp.get("goal", false)):
			var f: String = String(gp.get("flair", ""))
			if f == "bicycle":
				return f
			if f == "volley":
				best = f
	return best
