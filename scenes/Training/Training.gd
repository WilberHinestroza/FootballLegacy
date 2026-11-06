extends Control

## Elegir el foco de entrenamiento de la semana. El foco solo decide QUÉ
## atributos reciben el cambio del tick semanal
## (WorldTickEngine._tick_fatigue_and_development); el ritmo de progresión
## en sí (edad, hueco hasta el potencial) vive SOLO en PlayerDevelopment —
## nunca lo dupliques aquí.

const FOCI := [
	{"key": "physical", "label": "Físico", "desc": "Velocidad, resistencia, fuerza", "icon": Icons.TRAINING, "px": "res://assets/icons_px/train_physical.png", "color": Styles.GREEN},
	{"key": "technical", "label": "Técnica", "desc": "Control, pase, tiro, regate", "icon": Icons.FOOTBALL, "px": "res://assets/icons_px/train_technical.png", "color": Styles.BLUE},
	{"key": "mental", "label": "Mental", "desc": "Decisión, temple, liderazgo", "icon": Icons.BRAIN, "px": "res://assets/icons_px/train_mental.png", "color": Styles.PURPLE},
	{"key": "balanced", "label": "Equilibrado", "desc": "Un poco de todo, al azar", "icon": Icons.STAR, "px": "res://assets/icons_px/train_balanced.png", "color": Styles.GOLD},
]

@onready var vbox: VBoxContainer = $Margin/VBox
@onready var current_label: Label = $Margin/VBox/CurrentLabel
@onready var options_box: VBoxContainer = $Margin/VBox/OptionsBox
@onready var back_button: Button = $Margin/VBox/BackButton

var _progress_card: PanelContainer = null

func _ready() -> void:
	WorldTickEngine.load_runtime() # idempotente; por si se entra directo a esta escena
	# Todo el contenido dentro de un scroll (10-oct, Wilber: "se dañó la
	# pantalla de entrenamiento"). Causa: la pantalla nunca tuvo
	# desplazamiento; al dejar crecer las tarjetas de foco con su texto, el
	# contenido pasó a medir más que la pantalla y el MarginContainer lo
	# desbordó hacia ARRIBA (tapaba la cabecera) y hacia abajo.
	var margin_node: Control = vbox.get_parent()
	var sc := ScrollContainer.new()
	sc.name = "Scroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin_node.remove_child(vbox)
	margin_node.add_child(sc)
	sc.add_child(vbox)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiScroll.make_touch(sc)
	back_button.pressed.connect(_on_back_pressed)
	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	_build_progress_card()
	_build_hero()
	_render()

## Cabecera héroe (9-oct, rediseño): tu jugador, media/potencial y foco.
var _hero: Control = null
func _build_hero() -> void:
	vbox.get_node("TitleLabel").visible = false
	var p := SaveManager.load_player()
	if p == null:
		return
	if _hero != null:
		_hero.queue_free()
	var face := Styles.portrait_frame(Avatar.for_player(p, SaveManager.load_world_seed(), 72), 72, Styles.GREEN)
	var ring := UiKit.chip("%d" % p.overall, PlayerCard.tier_color(p.overall))
	_hero = UiKit.hero(Styles.GREEN, face, "Entrenamiento", "Media %d · Potencial %d" % [p.overall, p.potential],
		[["Foco: %s" % _label_for(WorldTickEngine.get_training_focus()), Styles.GREEN], ["+%d por crecer" % maxi(0, p.potential - p.overall), Styles.GOLD]])
	vbox.add_child(_hero)
	vbox.move_child(_hero, 0)

## Tarjeta de progresión (solo lectura) — hace visible el "RPG": margen
## hasta el potencial, probabilidad real de mejora esta semana
## (PlayerDevelopment, nunca recalculada acá) y cuándo se aplica.
func _build_progress_card() -> void:
	_progress_card = PanelContainer.new()
	_progress_card.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD))
	vbox.add_child(_progress_card)
	vbox.move_child(_progress_card, current_label.get_index())

func _fill_progress_card() -> void:
	for c in _progress_card.get_children():
		c.queue_free()
	var player := SaveManager.load_player()
	if player == null:
		return
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	var gap: int = player.potential - player.overall
	var days_left: int = 7 - int(WorldTickEngine.current_epoch_day) % 7
	col.add_child(_prow("Nivel de carrera", "%d  ·  %d / %d XP" % [player.level, player.career_xp, ProgressionEngine.xp_to_next(player.level)]))
	var f: int = ProgressionEngine.form(player)
	col.add_child(_prow("Forma", "%s %s" % [ProgressionEngine.FORM_ARROWS[f], ProgressionEngine.FORM_NAMES[f]]))
	col.add_child(_prow("Media / Potencial", "%d / %d" % [player.overall, player.potential]))
	col.add_child(_prow("Margen de mejora", "%d puntos" % gap))
	if gap > 0:
		col.add_child(_prow("Cómo subís", "Jugando y entrenando (ver abajo)"))
	elif player.age >= PlayerDevelopment.DECLINE_START_AGE:
		var dec: float = PlayerDevelopment.weekly_decline_chance(player.age)
		col.add_child(_prow("Riesgo de bajar (edad)", "%d%%" % int(round(dec * 100.0))))
	else:
		col.add_child(_prow("Estado", "en tu techo, estable"))
	col.add_child(_prow("Próximo ajuste", "en %d días" % days_left))

	# Atributo del foco actual más cerca de subir por XP (schema v23).
	var focus_now: String = WorldTickEngine.get_training_focus()
	var group: Array = PlayerDevelopment.FOCUS_GROUPS.get(focus_now, [])
	var best_name: String = ""
	var best_missing: int = 1 << 30
	for attr_name in group:
		var av: int = int(player.get(attr_name))
		if av >= PlayerDevelopment.attr_cap(player):
			continue
		var need: int = PlayerDevelopment.xp_needed(av, player.growth_difficulty)
		var have: int = int(round(float(player.attribute_xp.get(attr_name, 0.0))))
		if need - have < best_missing:
			best_missing = need - have
			best_name = attr_name
	if best_name != "":
		col.add_child(_prow("Más cerca de subir", "%s  ·  faltan %d XP" % [
			PlayerDevelopment.attr_es(best_name), maxi(0, best_missing)]))
	margin.add_child(col)
	_progress_card.add_child(margin)

func _prow(label: String, value: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	var v := Label.new()
	v.text = value
	hb.add_child(l)
	hb.add_child(v)
	return hb

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")

var _train_btn: Button = null

func _render() -> void:
	_land_setup()
	_fill_progress_card()
	var current: String = WorldTickEngine.get_training_focus()
	current_label.text = "Foco: %s. Cada sesión suma XP a los atributos del foco y experiencia de carrera (niveles → puntos de habilidad). Jugar partidos suma más." % _label_for(current)
	current_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	for child in options_box.get_children():
		child.queue_free()

	# Botón de sesión manual: avanza 1 día y da un empujoncito al foco.
	if _train_btn == null:
		_train_btn = Button.new()
		_train_btn.custom_minimum_size = Vector2(0, 52)
		_train_btn.focus_mode = Control.FOCUS_NONE
		_train_btn.icon = Icons.load_icon(Icons.TRAINING)
		_train_btn.add_theme_constant_override("icon_max_width", 22)
		_train_btn.pressed.connect(_on_train_session)
		if _land_left != null:
			_land_left.add_child(_train_btn)
		else:
			vbox.add_child(_train_btn)
			vbox.move_child(_train_btn, options_box.get_index())
	_build_intensity_row(vbox)
	var player := SaveManager.load_player()
	var injured: bool = player != null and player.injury_days_remaining > 0
	_train_btn.text = "Lesionado — no podés entrenar" if injured else "Entrenar sesión de hoy (avanza 1 día)"
	_train_btn.disabled = injured
	Styles.styled_button(_train_btn, Styles.pill_filled(Styles.GREEN if not injured else Styles.GRAY_TEXT), Color.BLACK)

	if _focus_grid != null:
		for c in _focus_grid.get_children():
			c.queue_free()
	for f in FOCI:
		var is_current: bool = f["key"] == current
		(_focus_grid if _focus_grid != null else options_box).add_child(_make_option(f, is_current))

## Intensidad de la sesión (v33): Suave / Normal / Intensa + botón a las
## Habilidades. La matemática vive en ProgressionEngine.INTENSITY.
var _intensity_row: VBoxContainer = null
func _build_intensity_row(vbox: Control) -> void:
	if _intensity_row != null:
		_intensity_row.queue_free()
	_intensity_row = VBoxContainer.new()
	_intensity_row.add_theme_constant_override("separation", 6)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var cur: String = WorldTickEngine.get_training_intensity()
	var descs := {"suave": "Menos XP · recuperás energía", "normal": "XP normal", "intensa": "+45% XP · riesgo de golpe leve"}
	for key in ["suave", "normal", "intensa"]:
		var b := Button.new()
		b.text = String(ProgressionEngine.INTENSITY[key]["name"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 42)
		b.focus_mode = Control.FOCUS_NONE
		var col: Color = {"suave": Styles.BLUE, "normal": Styles.GREEN, "intensa": Styles.RED}[key]
		Styles.styled_button(b, Styles.pill_filled(col) if key == cur else Styles.pill_outlined(col), Color.BLACK if key == cur else col)
		b.pressed.connect(func():
			WorldTickEngine.set_training_intensity(key)
			_render())
		h.add_child(b)
	_intensity_row.add_child(Styles.section_label("INTENSIDAD"))
	_intensity_row.add_child(h)
	var d := Label.new()
	d.text = String(descs[cur])
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	d.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	_intensity_row.add_child(d)
	var p := SaveManager.load_player()
	var sk := Button.new()
	sk.custom_minimum_size = Vector2(0, 46)
	sk.focus_mode = Control.FOCUS_NONE
	sk.text = "Habilidades  ·  %d punto%s" % [p.skill_points, "" if p.skill_points == 1 else "s"] if p != null else "Habilidades"
	Styles.styled_button(sk, Styles.pill_filled(Styles.GOLD) if p != null and p.skill_points > 0 else Styles.pill_outlined(Styles.GOLD), Color.BLACK if p != null and p.skill_points > 0 else Styles.GOLD)
	sk.pressed.connect(func():
		SkillsPanel.open(self).closed.connect(_render))
	_intensity_row.add_child(sk)
	if p != null and p.skill_points > 0:
		sk.ready.connect(func(): Juice.pulse(sk, 1.04))
	if _land_right != null:
		_land_right.add_child(_intensity_row)
	else:
		var host: Node = _train_btn.get_parent()
		host.add_child(_intensity_row)
		host.move_child(_intensity_row, _train_btn.get_index())

func _on_train_session() -> void:
	var player := SaveManager.load_player()
	if player == null or player.injury_days_remaining > 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var intensity: String = WorldTickEngine.get_training_intensity()
	var s: Dictionary = PlayerDevelopment.training_session(player, WorldTickEngine.get_training_focus(), rng, ProgressionEngine.intensity_mult(intensity))
	# v33: XP de carrera + efecto de la intensidad (suave recupera, intensa
	# arriesga un golpe leve).
	var extra: Dictionary = ProgressionEngine.after_training(player, intensity, rng)
	WeeklyGoalsEngine.bump(WorldTickEngine.season, WorldTickEngine.current_epoch_day, SaveManager.load_world_seed(), "train3")
	SaveManager.save_season(WorldTickEngine.season)
	var msg: String = "+%d XP de carrera" % int(extra["lv"]["xp"])
	if int(extra["lv"]["levels"]) > 0:
		msg = "¡Nivel %d! +%d punto(s) de habilidad" % [player.level, int(extra["lv"]["points"])]
	if int(extra["knock_days"]) > 0:
		msg += " · golpe leve: %d días afuera" % int(extra["knock_days"])
	Nav.toast(msg)
	# Entrenar ya NO gasta energía física (pedido de Wilber: solo baja
	# jugando). El día de entreno no recupera energía — ese es su costo.
	SaveManager.save_player(player)
	WorldTickEngine.advance_day("train")
	# El Hub sabe encaminar si el avance destapó un partido / cierre de
	# temporada / decisión de contrato (patrón hub-and-spoke de siempre).
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")

func _make_option(f: Dictionary, is_current: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 84)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.disabled = is_current
	var focus_color: Color = f.get("color", Styles.GOLD)
	if is_current:
		Styles.styled_button(btn, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	else:
		Styles.styled_button(btn, Styles.card_accent(focus_color), Color.WHITE)
		btn.pressed.connect(_on_focus_chosen.bind(f["key"]))

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
	# Sin esto, el HBoxContainer padre estira la insignia circular a lo
	# alto de la fila (mismo bug de fondo que en CareerMenu._make_tile,
	# ahí en el eje horizontal — el contenedor padre siempre estira al
	# hijo salvo que se le diga explícitamente que no).
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", Styles.circle(Color(0, 0, 0, 0.25) if is_current else focus_color, 44))
	var badge_center := CenterContainer.new()
	badge_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Logo en pixel art (10-oct, Wilber: "logos de los entrenamientos"); si
	# falta el archivo, el ícono genérico de antes.
	var px_path: String = String(f.get("px", ""))
	if px_path != "" and ResourceLoader.exists(px_path):
		var logo := Icons.make_rect(px_path, 40)
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		badge.custom_minimum_size = Vector2(52, 52)
		badge.add_theme_stylebox_override("panel", Styles.circle(Color(0, 0, 0, 0.28), 52))
		badge_center.add_child(logo)
	else:
		badge_center.add_child(Icons.make_rect(f["icon"], 22))
	badge.add_child(badge_center)
	row.add_child(badge)

	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	var title_lbl := Label.new()
	title_lbl.text = f["label"]
	title_lbl.add_theme_color_override("font_color", Color.BLACK if is_current else Color.WHITE)
	texts.add_child(title_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = f["desc"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0, 0, 0, 0.6) if is_current else Styles.GRAY_TEXT)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	texts.add_child(desc_lbl)

	# Qué SUBE este plan, en números (pedido de Wilber: "que muestre qué
	# aumenta de esa planificación de la semana").
	var gain_lbl := Label.new()
	gain_lbl.text = _plan_gain_text(String(f["key"]))
	if get_viewport_rect().size.x > get_viewport_rect().size.y:
		# Horizontal: solo lo esencial ("+19 XP/sesión a … (+5 al resto)");
		# la estimación de sesiones y el ajuste semanal llenaban la tarjeta.
		var cut: int = gain_lbl.text.find(")")
		if cut > 0:
			gain_lbl.text = gain_lbl.text.substr(0, cut + 1)
		gain_lbl.add_theme_font_size_override("font_size", 12)
	gain_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gain_lbl.add_theme_color_override("font_color", Color(0, 0, 0, 0.72) if is_current else f.get("color", Styles.GOLD))
	gain_lbl.add_theme_font_size_override("font_size", 11)
	texts.add_child(gain_lbl)
	row.add_child(texts)

	if is_current:
		var check_lbl := Label.new()
		check_lbl.text = "✓"
		check_lbl.add_theme_color_override("font_color", Color.BLACK)
		check_lbl.add_theme_font_size_override("font_size", 20)
		row.add_child(check_lbl)

	margin.add_child(row)
	btn.add_child(margin)
	# El botón medía 84 px FIJOS y el texto (3 renglones con ajuste de
	# línea) se salía por abajo y se montaba con la tarjeta siguiente
	# (captura de Wilber, 10-oct). Ahora crece con su contenido.
	var fit := func():
		btn.custom_minimum_size.y = maxf(84.0, margin.get_combined_minimum_size().y)
	margin.minimum_size_changed.connect(fit)
	btn.resized.connect(fit)
	return btn

func _label_for(key: String) -> String:
	for f in FOCI:
		if f["key"] == key:
			return f["label"]
	return key

## Texto de "qué sube este plan", con números reales tomados de
## PlayerDevelopment.training_session() (nunca recalculado a mano acá).
func _plan_gain_text(key: String) -> String:
	var player := SaveManager.load_player()
	if player == null:
		return ""
	var group: Array = PlayerDevelopment.FOCUS_GROUPS.get(key, [])
	var balanced: bool = group.is_empty()
	if balanced:
		group = PlayerDevelopment.ALL_TRAINABLE
	var gains: Dictionary = PlayerDevelopment.session_gains_preview(player, key)
	var per_focus_xp: float = float(gains.get(group[0], 0.0)) if not group.is_empty() else 0.0
	var rest_attr: String = ""
	for a in PlayerDevelopment.ALL_TRAINABLE:
		if not group.has(a):
			rest_attr = a
			break
	var rest_xp: float = float(gains.get(rest_attr, 0.0))

	if balanced:
		return "≈ +%d XP/sesión repartido en TODOS los atributos. El ajuste semanal sube +1 a 2 al azar." % int(round(per_focus_xp))

	# Nombres ES + el que está más cerca de +1 con este plan.
	var names: Array = []
	var soonest_name: String = ""
	var soonest_sessions: int = 1 << 30
	for a in group:
		names.append(PlayerDevelopment.attr_es(a))
		var av: int = int(player.get(a))
		if av >= PlayerDevelopment.attr_cap(player):
			continue
		var need: int = PlayerDevelopment.xp_needed(av, player.growth_difficulty)
		var have: int = int(round(float(player.attribute_xp.get(a, 0.0))))
		var sess: int = int(ceil(maxf(1.0, float(need - have)) / maxf(1.0, per_focus_xp)))
		if sess < soonest_sessions:
			soonest_sessions = sess
			soonest_name = PlayerDevelopment.attr_es(a)
	var tail: String = ""
	if soonest_name != "":
		tail = "  ·  %s en ~%d sesión%s" % [soonest_name, soonest_sessions, "" if soonest_sessions == 1 else "es"]
	return "≈ +%d XP/sesión a %s (+%d al resto)%s.  El ajuste semanal sube +1 a 2 de esos." % [
		int(round(per_focus_xp)), " · ".join(names), int(round(rest_xp)), tail]

func _on_focus_chosen(key: String) -> void:
	WorldTickEngine.set_training_focus(key)
	_render()


# ---------------------------------------------------------------- horizontal
## HORIZONTAL: a la izquierda tu ficha y el progreso; a la derecha los 4
## FOCOS en mosaico 2×2, la intensidad y el botón grande de entrenar.
var _land_left: VBoxContainer = null
var _land_right: VBoxContainer = null
var _focus_grid: GridContainer = null

func _land_setup() -> void:
	if get_viewport_rect().size.x <= get_viewport_rect().size.y:
		return
	if _land_left == null:
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 18)
		cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(cols)
		vbox.move_child(cols, 0)
		_land_left = VBoxContainer.new()
		_land_left.custom_minimum_size.x = 380
		_land_left.add_theme_constant_override("separation", 10)
		cols.add_child(_land_left)
		_land_right = VBoxContainer.new()
		_land_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_land_right.add_theme_constant_override("separation", 10)
		cols.add_child(_land_right)
		_land_right.add_child(Styles.section_label("Foco de entrenamiento"))
		_focus_grid = GridContainer.new()
		_focus_grid.columns = 2
		_focus_grid.add_theme_constant_override("h_separation", 10)
		_focus_grid.add_theme_constant_override("v_separation", 10)
		_land_right.add_child(_focus_grid)
		options_box.visible = false
		_progress_card.reparent(_land_left)
		current_label.reparent(_land_left)
		current_label.add_theme_font_size_override("font_size", 13)
		current_label.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		back_button.visible = false
	if _hero != null and is_instance_valid(_hero) and _hero.get_parent() != _land_left:
		_hero.reparent(_land_left)
		_land_left.move_child(_hero, 0)
