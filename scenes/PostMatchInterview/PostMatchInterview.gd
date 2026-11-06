extends Control

## Zona mixta PROCEDURAL: la pregunta sale de la rama que mejor encaja con
## el partido (roja, hito, contrato por vencer, hat-trick, derbi perdido…) y,
## según el TONO de tu respuesta, puede haber una REPREGUNTA encadenada.
## Cada respuesta mueve reputación, confianza del DT, rasgos, humor de la
## afición y clima de vestuario (ver InterviewEngine). Al cerrar se limpia
## MatchState y se vuelve a MatchState.return_scene.

@onready var source_label: Label = $Margin/VBox/SourceLabel
@onready var question_label: Label = $Margin/VBox/QuestionLabel
@onready var options_box: VBoxContainer = $Margin/VBox/Scroll/OptionsBox

var _rng := RandomNumberGenerator.new()
var _context: Dictionary = {}
var _source: String = "Prensa"
var _q_index: int = 0

func _ready() -> void:
	# Bug visual real (auditoría ronda 3): faltaba el deadzone táctil.
	UiScroll.make_touch($Margin/VBox/Scroll)
	# Fondo: sala de conferencias pixel (P6, 10-oct), oscurecida para leer.
	if ResourceLoader.exists("res://assets/scenes/press_room.png"):
		var bg := TextureRect.new()
		bg.texture = load("res://assets/scenes/press_room.png")
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.modulate = Color(0.24, 0.24, 0.28)   # más oscuro: el texto se lee mejor
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		move_child(bg, 0)
		# Velo oscuro DETRÁS de pregunta y respuestas: el fondo es tan cargado
		# que el texto perdía contraste.
		var veil := Panel.new()
		var vs := StyleBoxFlat.new()
		vs.bg_color = Color(0.03, 0.035, 0.05, 0.78)
		vs.set_corner_radius_all(16)
		veil.add_theme_stylebox_override("panel", vs)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Margin.add_child(veil)
		$Margin.move_child(veil, 0)
	var fixture: Dictionary = MatchState.fixture
	var result: Dictionary = MatchState.match_result
	var player := SaveManager.load_player()

	if result.is_empty() or player == null:
		_leave()
		return

	_rng.seed = randi()
	# Partido de SELECCIÓN (fixture trae "home_country"/"away_country" en
	# vez de "home_club_id"/"away_club_id", ver NationalTeamMatchLauncher.
	# prepare()) — mismo criterio de alias que NationalMatchSummary.gd, si
	# no extract_context() nunca encuentra "home_club_id" y calcula
	# "¿jugaste de local?" mal (bug real: la entrevista de un partido de
	# selección daría por VISITANTE siempre, aunque hayas jugado de local).
	var ctx_fixture: Dictionary = fixture
	var ctx_club_id: String = player.club_id
	if fixture.has("home_country"):
		ctx_fixture = fixture.duplicate()
		ctx_fixture["home_club_id"] = fixture.get("home_country", "")
		ctx_fixture["away_club_id"] = fixture.get("away_country", "")
		ctx_club_id = player.country
	_context = InterviewEngine.extract_context(
		ctx_fixture, result, ctx_club_id, player, WorldTickEngine.season)
	var q: Dictionary = InterviewEngine.generate_question(_context, _rng)
	_source = MediaOutlets.display(String(q.get("source", "Prensa")))
	_show_question(q)

func _show_question(q: Dictionary) -> void:
	source_label.text = "%s  ·  Zona mixta" % _source
	question_label.text = "\"%s\"" % q.get("question", "")
	_place_reporter(_source)
	for child in options_box.get_children():
		child.queue_free()
	# HORIZONTAL: respuestas en grilla de 2 (entran todas sin bajar).
	var target: Container = options_box
	if get_viewport_rect().size.x > get_viewport_rect().size.y:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		options_box.add_child(grid)
		target = grid
	for option in q.get("options", []):
		var o: Control = _make_option(option)
		o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		target.add_child(o)

## Cara del periodista a la izquierda de la fuente (envuelve el Label una vez).
func _place_reporter(source: String) -> void:
	var parent := source_label.get_parent()
	if parent.has_node("ReporterRow"):
		return
	var idx := source_label.get_index()
	var row := HBoxContainer.new()
	row.name = "ReporterRow"
	row.add_theme_constant_override("separation", 10)
	var seed_int: int = SaveManager.load_world_seed()
	row.add_child(Styles.portrait_frame(
		Avatar.for_npc("reportero:" + source, "journalist", seed_int, 40), 40, Styles.GRAY_TEXT))
	# Logo del medio al lado del periodista (P1b, 9-oct).
	if not MediaOutlets.by_name(source).is_empty():
		row.add_child(MediaOutlets.logo(source, 40))
	parent.remove_child(source_label)
	source_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(source_label)
	parent.add_child(row)
	parent.move_child(row, idx)

## Chip con el "tono" de la respuesta (Humilde/Arrogante/Líder/...) coloreado
## según si sube o baja tu reputación — solo presentación, la matemática de
## verdad vive entera en InterviewEngine.apply_response().
func _make_option(option: Dictionary) -> Button:
	var reputation: int = int(option.get("reputation", 0))
	var trait_color: Color = Styles.GREEN if reputation > 0 else (Styles.RED if reputation < 0 else Styles.GRAY_TEXT)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 92)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Styles.styled_button(btn, Styles.card_accent(trait_color))
	btn.pressed.connect(_on_option_chosen.bind(option))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 6)

	var trait_chip := PanelContainer.new()
	trait_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	trait_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trait_chip.add_theme_stylebox_override("panel", Styles.chip())
	var chip_margin := MarginContainer.new()
	chip_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_margin.add_theme_constant_override("margin_left", 8)
	chip_margin.add_theme_constant_override("margin_right", 8)
	chip_margin.add_theme_constant_override("margin_top", 3)
	chip_margin.add_theme_constant_override("margin_bottom", 3)
	var trait_lbl := Label.new()
	trait_lbl.text = String(option.get("label", "")).to_upper()
	trait_lbl.add_theme_color_override("font_color", trait_color)
	trait_lbl.add_theme_font_size_override("font_size", 11)
	trait_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_margin.add_child(trait_lbl)
	trait_chip.add_child(chip_margin)
	content.add_child(trait_chip)

	var text_lbl := Label.new()
	text_lbl.text = "\"%s\"" % option.get("text", "")
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(text_lbl)

	margin.add_child(content)
	btn.add_child(margin)
	return btn

func _on_option_chosen(option: Dictionary) -> void:
	var player := SaveManager.load_player()
	if player != null:
		InterviewEngine.apply_response(player, option, WorldTickEngine.season)
		# Titular de prensa si la respuesta dio para ello (tono fuerte).
		var pname: String = Nickname.press_name(player, SaveManager.load_world_seed())
		var hl: Dictionary = InterviewEngine.headline_from_answer(pname, option)
		if not hl.is_empty():
			PressGenerator.append_to_feed(player, hl, WorldTickEngine.current_epoch_day)
		SaveManager.save_player(player)
		if not WorldTickEngine.season.is_empty():
			SaveManager.save_season(WorldTickEngine.season)

	# Una sola repregunta encadenada según el tono elegido.
	if _q_index == 0:
		_q_index = 1
		var fq: Dictionary = InterviewEngine.followup(_context, option, _rng)
		if not fq.is_empty():
			_show_question(fq)
			return
	_leave()

func _leave() -> void:
	var dest: String = MatchState.return_scene
	MatchState.clear()
	# La entrevista REEMPLAZA al botón "Continuar" del resumen: al salir hay
	# que avanzar el día igual que hace MatchSummary._on_continue_pressed
	# (si no, hacer la entrevista se "comía" el avance automático de día).
	if dest == "res://scenes/Hub/Hub.tscn":
		WorldTickEngine.advance_day()
		if WorldTickEngine.season.get("awaiting_contract_decision", false):
			dest = "res://scenes/ContractDecision/ContractDecision.tscn"
		elif not WorldTickEngine.last_season_report.is_empty():
			dest = "res://scenes/SeasonCeremony/SeasonCeremony.tscn"
	get_tree().change_scene_to_file(dest)
