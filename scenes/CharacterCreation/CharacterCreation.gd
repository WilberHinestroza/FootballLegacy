extends Control

## Creación de personaje: identidad ampliada (nombre+apellido, posición
## principal + secundaria opcional, nacionalidad, pie dominante, origen,
## año de nacimiento) + test de personalidad (5 preguntas al azar de 20,
## aprendizaje de Football Legacy). Al terminar arma un PlayerData, lo
## persiste en el slot activo y salta al partido de prueba.
##
## El slot activo (SaveManager.active_slot_id) ya viene fijado por la
## pantalla inicial antes de entrar aquí — estado compartido vía autoload.
## Los campos nuevos son schema v16 (ver SaveManager).

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var identity_scroll: ScrollContainer = $Margin/VBox/IdentityScroll
@onready var identity_box: VBoxContainer = $Margin/VBox/IdentityScroll/IdentityBox
@onready var quiz_panel: VBoxContainer = $Margin/VBox/QuizPanel
@onready var progress_label: Label = $Margin/VBox/QuizPanel/ProgressLabel
@onready var question_label: Label = $Margin/VBox/QuizPanel/QuestionLabel
@onready var options_box: VBoxContainer = $Margin/VBox/QuizPanel/OptionsBox
@onready var to_quiz_button: Button = $Margin/VBox/ToQuizButton

const FEET := ["Derecho", "Izquierdo", "Ambidiestro"]
const ORIGINS := [
	"Barrio humilde", "Cantera de club grande", "Familia futbolera",
	"Descubierto tarde", "Academia extranjera",
	"DEV — jugador 80-85 (pruebas)",
]
const DEV_ORIGIN := "DEV — jugador 80-85 (pruebas)"
const AGE_MIN := 15
const AGE_MAX := 20
## Dificultad de PROGRESIÓN (schema v25) — pedido explícito: "3
## dificultades, fácil = progresión rápida, difícil = más lenta". Escala
## la velocidad de subida de atributos/overall en PlayerDevelopment.gd;
## no toca el balance de partido (eso lo sigue decidiendo DecisionResolver
## solo). {code, label, desc}.
const DIFFICULTIES := [
	["easy", "Fácil", "Subís de nivel más rápido: menos XP para cada +1 de atributo."],
	["normal", "Normal", "El ritmo de progresión de siempre — el que ya tenía el juego."],
	["hard", "Difícil", "Cuesta más cada +1: hace falta currarla partido a partido y entreno a entreno."],
]
const DIFFICULTY_DEFAULT_IDX := 1

var _name_edit: LineEdit
var _surname_edit: LineEdit
var _pos_option: OptionButton
var _pos2_option: OptionButton
var _country_name: String = Countries.DEFAULT
var _country_btn: Button
var _country_overlay: Control
var _foot_option: OptionButton
var _origin_option: OptionButton
var _difficulty_option: OptionButton
var _start_option: OptionButton
var _start_hint: Label
var _difficulty_hint: Label
var _year_slider: HSlider
var _year_value_label: Label
var _year_age_label: Label

var _questions: Array = []
var _answers: Array = []
var _current: int = 0

var _identity: Dictionary = {}

var _avatar_cfg: Dictionary = {}

func _ready() -> void:
	identity_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	identity_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# Bug visual real (auditoría ronda 3): faltaba el deadzone táctil.
	UiScroll.make_touch(identity_scroll)
	to_quiz_button.pressed.connect(_on_to_quiz_pressed)
	Styles.styled_button(to_quiz_button, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	to_quiz_button.text = "Siguiente: apariencia"
	_questions = PersonalityQuiz.pick_random()

	# Sólo se salta al test cuando la apariencia se cerró con "Siguiente"
	# (avatar_done). Si el jugador volvió del avatar con "Volver", se
	# reabre la identidad con los datos ya cargados (antes se usaba
	# has_avatar() y por eso "volver" parecía reiniciar la creación).
	if CharacterDraft.has_identity() and CharacterDraft.avatar_done:
		_identity = CharacterDraft.identity.duplicate(true)
		_avatar_cfg = CharacterDraft.avatar.duplicate(true)
		identity_scroll.visible = false
		to_quiz_button.visible = false
		quiz_panel.visible = true
		title_label.text = "Test de personalidad"
		_landscape_header(2)
		_render_question()
		return

	_build_identity_form()
	if CharacterDraft.has_identity():
		_restore_identity_form(CharacterDraft.identity)
	_landscape_header(0)
	_landscape_identity()

# --- Paso 1: identidad ---

func _build_identity_form() -> void:
	# Nombre + apellido
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nombre"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surname_edit = LineEdit.new()
	_surname_edit.placeholder_text = "Apellido"
	_surname_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)
	name_row.add_child(_surname_edit)
	identity_box.add_child(_field("Nombre del jugador", name_row))

	# Posición principal
	_pos_option = OptionButton.new()
	for entry in Positions.DETAILED:
		_pos_option.add_item("%s (%s)" % [entry["label"], entry["code"]])
	_pos_option.select(Positions.DETAILED.size() - 1) # DC por defecto
	_pos_option.item_selected.connect(func(_i): _sync_pos2_disabled())
	identity_box.add_child(_field("Posición principal", _pos_option))

	# Posición secundaria (opcional) — la que elijas como principal queda
	# BLOQUEADA acá (no tiene sentido principal == secundaria).
	_pos2_option = OptionButton.new()
	_pos2_option.add_item("Ninguna")
	for entry in Positions.DETAILED:
		_pos2_option.add_item("%s (%s)" % [entry["label"], entry["code"]])
	_pos2_option.select(0)
	identity_box.add_child(_field("Posición secundaria (opcional)", _pos2_option))
	_sync_pos2_disabled()

	# Nacionalidad — botón que abre un buscador (195 países en un
	# OptionButton eran imposibles de navegar, pedido de Wilber).
	_country_btn = Button.new()
	_country_btn.custom_minimum_size = Vector2(0, 46)
	_country_btn.focus_mode = Control.FOCUS_NONE
	_country_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_country_btn.clip_text = true
	Styles.styled_button(_country_btn, Styles.card_flat(Styles.CARD_DARK_2, 8), Color.WHITE)
	_country_btn.pressed.connect(_open_country_picker)
	_refresh_country_btn()
	identity_box.add_child(_field("Nacionalidad", _country_btn))

	# Pie dominante
	_foot_option = OptionButton.new()
	for f in FEET:
		_foot_option.add_item(f)
	_foot_option.select(0)
	identity_box.add_child(_field("Pie dominante", _foot_option))

	# Origen
	_origin_option = OptionButton.new()
	for o in ORIGINS:
		_origin_option.add_item(o)
	_origin_option.select(0)
	identity_box.add_child(_field("Origen", _origin_option))

	# Dificultad de progresión
	var diff_wrap := VBoxContainer.new()
	diff_wrap.add_theme_constant_override("separation", 4)
	_difficulty_option = OptionButton.new()
	_difficulty_option.custom_minimum_size = Vector2(0, 46)
	for d in DIFFICULTIES:
		_difficulty_option.add_item(String(d[1]))
	_difficulty_option.select(DIFFICULTY_DEFAULT_IDX)
	_difficulty_option.item_selected.connect(func(_i): _refresh_difficulty_hint())
	diff_wrap.add_child(_difficulty_option)
	_difficulty_hint = Label.new()
	_difficulty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_difficulty_hint.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	_difficulty_hint.add_theme_font_size_override("font_size", 12)
	diff_wrap.add_child(_difficulty_hint)
	identity_box.add_child(_field("Dificultad de progresión", diff_wrap))
	_refresh_difficulty_hint()

	# Año de nacimiento (slider) — se traduce a edad al inicio.
	var yr_wrap := VBoxContainer.new()
	yr_wrap.add_theme_constant_override("separation", 4)
	var yr_top := HBoxContainer.new()
	_year_value_label = Label.new()
	_year_value_label.add_theme_font_override("font", Styles.font_black())
	_year_value_label.add_theme_font_size_override("font_size", 20)
	_year_value_label.add_theme_color_override("font_color", Styles.GREEN)
	_year_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_year_age_label = Label.new()
	_year_age_label.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	_year_age_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	yr_top.add_child(_year_value_label)
	yr_top.add_child(_year_age_label)
	yr_wrap.add_child(yr_top)
	_year_slider = HSlider.new()
	var base_year: int = int(CalendarUtils.EPOCH_START_DATE["year"])
	_year_slider.min_value = base_year - AGE_MAX
	_year_slider.max_value = base_year - AGE_MIN
	_year_slider.step = 1
	_year_slider.value = base_year - 16
	_year_slider.custom_minimum_size = Vector2(0, 28)
	Styles.style_slider(_year_slider)
	_year_slider.value_changed.connect(func(_v): _refresh_year_label())
	yr_wrap.add_child(_year_slider)
	identity_box.add_child(_field("Año de nacimiento", yr_wrap))
	_refresh_year_label()

	# Inicio de carrera (AcademyEngine): directo al primer equipo o en la cantera.
	var st_wrap := VBoxContainer.new()
	st_wrap.add_theme_constant_override("separation", 4)
	_start_option = OptionButton.new()
	_start_option.custom_minimum_size = Vector2(0, 46)
	_start_option.add_item("Primer equipo")
	_start_option.add_item("Cantera (hasta %d años)" % AcademyEngine.MAX_START_AGE)
	_start_option.item_selected.connect(func(_i): _refresh_start_hint())
	st_wrap.add_child(_start_option)
	_start_hint = Label.new()
	_start_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_start_hint.add_theme_font_size_override("font_size", 12)
	st_wrap.add_child(_start_hint)
	identity_box.add_child(_field("Inicio de carrera", st_wrap))
	_refresh_start_hint()

## Deshabilita en el desplegable de posición SECUNDARIA la opción que está
## elegida como principal (item 0 = "Ninguna"; item i+1 = Positions.DETAILED[i]).
## BUG REAL encontrado (Wilber: "cambié la posición principal por la que
## ya tenía de secundaria y se duplicó la pantalla") — esta función tenía
## el resto de _build_identity_form() (nacionalidad, pie, origen,
## dificultad, año) mal anidado DENTRO de su cuerpo por un indentado
## corrido. Como esto se llama cada vez que cambiás la posición principal
## (_pos_option.item_selected), cada cambio reconstruía y volvía a
## agregar TODOS esos campos a identity_box sin sacar los viejos —
## duplicando visualmente media pantalla. Separado en su propia función,
## que ahora solo hace lo que dice su nombre.
func _sync_pos2_disabled() -> void:
	if _pos_option == null or _pos2_option == null:
		return
	var primary_idx: int = _pos_option.selected
	for i in range(Positions.DETAILED.size()):
		_pos2_option.set_item_disabled(i + 1, i == primary_idx)
	if _pos2_option.selected == primary_idx + 1:
		_pos2_option.select(0)

## Vuelve a poner en el formulario los datos de un borrador de identidad
## (cuando el jugador vuelve del creador de avatar con "Volver"). Es el
## inverso del dict que arma _on_to_quiz_pressed().
func _restore_identity_form(d: Dictionary) -> void:
	var full: String = String(d.get("name", "")).strip_edges()
	var sp: int = full.find(" ")
	if sp >= 0:
		_name_edit.text = full.substr(0, sp)
		_surname_edit.text = full.substr(sp + 1)
	else:
		_name_edit.text = full

	_country_name = String(d.get("country", _country_name))
	_refresh_country_btn()

	var pos_code: String = String(d.get("pos", ""))
	for i in range(Positions.DETAILED.size()):
		if Positions.DETAILED[i]["code"] == pos_code:
			_pos_option.select(i)
			break

	var pos2_code: String = String(d.get("pos2", ""))
	if pos2_code == "":
		_pos2_option.select(0)
	else:
		for i in range(Positions.DETAILED.size()):
			if Positions.DETAILED[i]["code"] == pos2_code:
				_pos2_option.select(i + 1)
				break

	var fi: int = FEET.find(String(d.get("foot", "")))
	if fi >= 0:
		_foot_option.select(fi)
	var oi: int = ORIGINS.find(String(d.get("origin", "")))
	if oi >= 0:
		_origin_option.select(oi)

	var diff_code: String = String(d.get("difficulty", "normal"))
	for i in range(DIFFICULTIES.size()):
		if DIFFICULTIES[i][0] == diff_code:
			_difficulty_option.select(i)
			break
	_refresh_difficulty_hint()

	var base_year: int = int(CalendarUtils.EPOCH_START_DATE["year"])
	var age: int = int(d.get("age", 16))
	_year_slider.value = base_year - age
	_refresh_year_label()
	if _start_option != null:
		_start_option.select(1 if bool(d.get("academy", false)) else 0)
		_refresh_start_hint()
	_sync_pos2_disabled()

func _refresh_country_btn() -> void:
	if _country_btn == null:
		return
	for c in _country_btn.get_children():
		c.queue_free()
	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fr: TextureRect = CountryFlags.flag_rect(_country_name, 16)
	if fr != null:
		box.add_child(fr)
	var l := Label.new()
	l.text = _country_name
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	var chev := Label.new()
	chev.text = "▾"
	chev.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(chev)
	m.add_child(box)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_country_btn.add_child(m)

static func _norm(s: String) -> String:
	var out := s.to_lower()
	for pair in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"], ["ñ", "n"]]:
		out = out.replace(pair[0], pair[1])
	return out

func _open_country_picker() -> void:
	if _country_overlay != null and is_instance_valid(_country_overlay):
		_country_overlay.queue_free()
	_country_overlay = Control.new()
	_country_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.6)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_country_overlay.queue_free())
	_country_overlay.add_child(scrim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = 60
	panel.offset_bottom = -60
	panel.add_theme_stylebox_override("panel", Styles.card(Styles.CARD_DARK))
	var pm := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		pm.add_theme_constant_override("margin_" + s, 14)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)

	var search := LineEdit.new()
	search.placeholder_text = "Buscar país…"
	search.custom_minimum_size = Vector2(0, 44)
	v.add_child(search)

	var pager := Pager.new()
	v.add_child(pager)

	var render_list := func(query: String):
		var q := _norm(query.strip_edges())
		var matches: Array = []
		for country in Countries.ALL:
			if q == "" or _norm(country).contains(q):
				matches.append(country)
		pager.show_items(matches, 9, func(country: String) -> Control:
			var b := Button.new()
			b.custom_minimum_size = Vector2(0, 44)
			b.focus_mode = Control.FOCUS_NONE
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.clip_text = true
			Styles.styled_button(b, Styles.card_flat(Styles.CARD_DARK_2, 8), Color.WHITE)
			var hb := HBoxContainer.new()
			hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			hb.add_theme_constant_override("separation", 8)
			hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var mm := MarginContainer.new()
			mm.add_theme_constant_override("margin_left", 10)
			mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var fr: TextureRect = CountryFlags.flag_rect(country, 16)
			if fr != null:
				hb.add_child(fr)
			var l := Label.new()
			l.text = country
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(l)
			mm.add_child(hb)
			mm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			b.add_child(mm)
			b.pressed.connect(func():
				_country_name = country
				_refresh_country_btn()
				_country_overlay.queue_free())
			return b)

	search.text_changed.connect(render_list)
	render_list.call("")

	pm.add_child(v)
	panel.add_child(pm)
	_country_overlay.add_child(panel)
	add_child(_country_overlay)
	search.grab_focus()

func _field(label: String, control: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.add_child(Styles.section_label(label))
	if control is OptionButton or control is LineEdit:
		control.custom_minimum_size = Vector2(0, 46)
	v.add_child(control)
	return v

func _refresh_year_label() -> void:
	var year: int = int(_year_slider.value)
	var age: int = int(CalendarUtils.EPOCH_START_DATE["year"]) - year
	_year_value_label.text = str(year)
	_year_age_label.text = "%d años al inicio" % age

func _refresh_start_hint() -> void:
	if _start_hint == null or _start_option == null:
		return
	_start_hint.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	if _start_option.selected == 1:
		_start_hint.text = "Empiezas en el juvenil de un club más grande, con beca. Juegas partidos juveniles cada semana; si destacas, te suben al primer equipo. A los 18, o subes o te dejan libre."
	else:
		_start_hint.text = "Firmas directamente con un primer equipo tras la prueba."

func _refresh_difficulty_hint() -> void:
	if _difficulty_hint == null or _difficulty_option == null:
		return
	var idx: int = clampi(_difficulty_option.selected, 0, DIFFICULTIES.size() - 1)
	_difficulty_hint.text = String(DIFFICULTIES[idx][2])

func _on_to_quiz_pressed() -> void:
	var first := _name_edit.text.strip_edges()
	var last := _surname_edit.text.strip_edges()
	if first.is_empty():
		_name_edit.placeholder_text = "Escribe un nombre"
		_name_edit.grab_focus()
		return

	var pos_code: String = Positions.DETAILED[_pos_option.selected]["code"]
	var pos2_code: String = ""
	if _pos2_option.selected > 0:
		pos2_code = Positions.DETAILED[_pos2_option.selected - 1]["code"]
		if pos2_code == pos_code:
			pos2_code = "" # secundaria == principal no tiene sentido

	var academy: bool = _start_option != null and _start_option.selected == 1
	var start_age: int = int(CalendarUtils.EPOCH_START_DATE["year"]) - int(_year_slider.value)
	if academy and start_age > AcademyEngine.MAX_START_AGE:
		_start_hint.text = "La cantera es hasta los %d años: cambia el año de nacimiento." % AcademyEngine.MAX_START_AGE
		_start_hint.add_theme_color_override("font_color", Styles.AMBER)
		return
	CharacterDraft.identity = {
		"name": (first + " " + last).strip_edges(),
		"country": _country_name,
		"pos": pos_code,
		"pos2": pos2_code,
		"foot": FEET[_foot_option.selected],
		"origin": ORIGINS[_origin_option.selected],
		"difficulty": String(DIFFICULTIES[_difficulty_option.selected][0]),
		"age": start_age,
		"academy": academy,
	}
	# El avatar se hace en su propia pantalla; al volver, _ready() retoma
	# directo en el test de personalidad.
	get_tree().change_scene_to_file("res://scenes/AvatarCreator/AvatarCreator.tscn")

# --- Paso 2: test de personalidad ---

func _render_question() -> void:
	var q: Dictionary = _questions[_current]
	progress_label.text = "Pregunta %d / %d" % [_current + 1, _questions.size()]
	question_label.text = q.get("text", "")

	for child in options_box.get_children():
		child.queue_free()

	# HORIZONTAL: las respuestas en una grilla de 2 columnas (entran todas).
	var target: Container = options_box
	if _is_land():
		var grid := GridContainer.new()
		grid.columns = 3 if (q.get("options", []) as Array).size() == 3 else 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		options_box.add_child(grid)
		target = grid
	for option in q.get("options", []):
		var btn := Button.new()
		btn.text = option.get("text", "")
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 62)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		Styles.styled_button(btn, Styles.card(), Color.WHITE)
		btn.pressed.connect(_on_option_chosen.bind(option))
		if _is_land():
			btn.custom_minimum_size = Vector2(0, 92)
			btn.add_theme_font_size_override("font_size", 16)
		target.add_child(btn)

func _on_option_chosen(option: Dictionary) -> void:
	_answers.append(option)
	_current += 1
	if _current < _questions.size():
		_render_question()
	else:
		_finish()

func _finish() -> void:
	var p := PlayerData.new()
	p.player_name = _identity["name"]
	p.country = _identity["country"]
	p.detailed_position = _identity["pos"]
	p.position = Positions.broad_of(_identity["pos"])
	p.secondary_detailed_position = _identity["pos2"]
	p.dominant_foot = _identity["foot"]
	p.origin = _identity["origin"]
	p.growth_difficulty = String(_identity.get("difficulty", "normal"))
	p.age = _identity["age"]
	if bool(_identity.get("academy", false)):
		AcademyEngine.mark_pending(p)   # las ofertas tras la prueba serán de cantera
	p.avatar = _avatar_cfg.duplicate(true)

	# Atributos base provisionales: un perfil plano decente. El generador
	# real por arquetipo/posición y la importación de plantillas llegan en
	# una fase posterior. No inventamos aquí números de balance. `overall`
	# se calcula SIEMPRE al final (PlayerDevelopment.compute_overall) A
	# PARTIR de estos mismos atributos, nunca un número aparte (mismo bug
	# que se corrigió en el crecimiento: "media" desincronizada de lo que
	# el jugador ve en pantalla).
	var is_dev: bool = p.origin == DEV_ORIGIN
	if is_dev:
		# Atajo de pruebas: jugador ya hecho, 80-85 de media y atributos
		# altos (algunos por encima, como un crack real), para no tener
		# que jugar 3 temporadas antes de probar algo.
		var dev_ov: int = randi_range(80, 85)
		p.potential = clampi(dev_ov + randi_range(4, 12), dev_ov, 99)
		for attr in ["speed", "stamina", "strength", "control", "passing", "shooting", "dribbling", "decision_making", "composure"]:
			p.set(attr, clampi(dev_ov + randi_range(-3, 9), 60, 97))
		p.leadership = randi_range(55, 85)
		p.reputation = randi_range(55, 68)   # ya te conocen: mejores ofertas y patrocinios
		p.origin = "Cantera de club grande" # no dejar la etiqueta de dev en la carrera
	else:
		p.potential = randi_range(68, 88)
	p.ensure_potential_floor() # invariante: potential >= overall

	p.personality_traits = PersonalityQuiz.score(_answers)
	if not is_dev:
		_apply_origin(p)

	p.overall = PlayerDevelopment.compute_overall(p)
	p.ensure_potential_floor()
	if is_dev:
		p.market_value = TransferMarketEngine.market_value(p.overall, p.potential, p.age)

	var agent: Dictionary = AgentEngine.generate_agent()
	p.agent_name = agent["name"]
	p.agent_stars = agent["stars"]
	# Nivel de carrera inicial según la media (v33) + esos puntos para el
	# árbol de habilidades desde el día uno.
	p.level = ProgressionEngine.initial_level(p.overall)
	p.skill_points = ProgressionEngine.points_up_to(p.level) + 1

	var world_seed: int = WorldFactory.IMPORTED_SEED if WorldFactory.has_imported_world() else randi()
	SaveManager.save_world_seed(world_seed)
	# Sal del mercado de fichajes: con el mundo importado el world_seed es
	# fijo (-1) para todas las carreras, así que sin esto SIEMPRE salían los
	# mismos fichajes a los mismos clubes (reporte de Wilber). Distinta por
	# carrera, != 0 (0 = save legacy, ver SaveManager v24).
	var market_salt: int = randi()
	while market_salt == 0:
		market_salt = randi()
	SaveManager.save_market_salt(market_salt)
	SaveManager.save_player(p)

	CharacterDraft.clear()

	var trial := CareerSetup.build_trial_teams(p)
	MatchState.user_suspended = false   # una sanción de otra carrera no cuenta aquí
	MatchState.start_new_match(trial["home"], trial["away"], p)
	MatchState.return_scene = "res://scenes/Offers/Offers.tscn"
	get_tree().change_scene_to_file("res://scenes/PreMatch/PreMatch.tscn")

## El ORIGEN deja de ser solo flavor: cada uno da un pequeño sesgo de
## arranque (media/potencial/atributos/personalidad/confianza). Nada
## grande — un matiz, no una ventaja rota.
func _apply_origin(p: PlayerData) -> void:
	var pt: Dictionary = p.personality_traits
	match _identity["origin"]:
		"Barrio humilde":
			p.strength = clampi(p.strength + 3, 20, 99)
			p.stamina = clampi(p.stamina + 2, 20, 99)
			pt["determination"] = clampi(int(pt.get("determination", 50)) + 10, 0, 100)
			pt["ambition"] = clampi(int(pt.get("ambition", 50)) + 6, 0, 100)
		"Cantera de club grande":
			p.control = clampi(p.control + 2, 20, 99)
			p.passing = clampi(p.passing + 2, 20, 99)
			p.coach_trust = clampi(p.coach_trust + 8, 0, 100)
			p.reputation += 3
		"Familia futbolera":
			p.decision_making = clampi(p.decision_making + 3, 20, 99)
			p.composure = clampi(p.composure + 2, 20, 99)
			p.potential = clampi(p.potential + 5, p.overall, 93)
			pt["loyalty"] = clampi(int(pt.get("loyalty", 50)) + 6, 0, 100)
		"Descubierto tarde":
			p.strength = clampi(p.strength + 3, 20, 99)
			p.stamina = clampi(p.stamina + 2, 20, 99)
			p.potential = clampi(p.potential - 5, p.overall, 93)
		"Academia extranjera":
			p.control = clampi(p.control + 3, 20, 99)
			p.dribbling = clampi(p.dribbling + 3, 20, 99)
			p.potential = clampi(p.potential + 3, p.overall, 93)
			p.coach_trust = clampi(p.coach_trust - 6, 0, 100)
	p.personality_traits = pt


# --- HORIZONTAL (FootballLegacy H) ---

func _is_land() -> bool:
	var vp: Vector2 = get_viewport_rect().size
	return vp.x > vp.y

## Título + indicador de pasos (1 Datos · 2 Apariencia · 3 Personalidad).
func _landscape_header(step: int) -> void:
	if not _is_land():
		return
	var m := $Margin as MarginContainer
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_bottom", 16)
	m.add_theme_constant_override("margin_left", 40)
	m.add_theme_constant_override("margin_right", 40)
	var vbox := $Margin/VBox as VBoxContainer
	var steps := CreationSteps.make(step)
	vbox.add_child(steps)
	vbox.move_child(steps, title_label.get_index() + 1)
	if step == 2:
		question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		question_label.add_theme_font_override("font", Styles.font_semibold())
		question_label.add_theme_font_size_override("font_size", 22)
		progress_label.add_theme_color_override("font_color", Styles.GOLD)
		quiz_panel.add_theme_constant_override("separation", 18)
		quiz_panel.alignment = BoxContainer.ALIGNMENT_CENTER
		quiz_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Tu jugador recién creado acompaña el test (llenaba de vacío).
		if not _avatar_cfg.is_empty():
			var cc := CenterContainer.new()
			cc.add_child(Avatar.build_full(_avatar_cfg, 120))
			quiz_panel.add_child(cc)
			quiz_panel.move_child(cc, 0)

## Datos en DOS columnas: quién sos (nombre, posiciones, país) a la
## izquierda y cómo arrancás (pie, origen, dificultad, edad) a la derecha.
func _landscape_identity() -> void:
	if not _is_land():
		return
	var fields: Array = identity_box.get_children()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var half: int = int(ceil(fields.size() / 2.0))
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for v in [left, right]:
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 12)
		cols.add_child(v)
	for i in fields.size():
		(fields[i] as Node).reparent(left if i < half else right)
	identity_box.add_child(cols)
	identity_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_name_edit.custom_minimum_size = Vector2(0, 46)
	_surname_edit.custom_minimum_size = Vector2(0, 46)
	to_quiz_button.custom_minimum_size = Vector2(0, 50)
