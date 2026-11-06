extends Control

## Planificador HASTA EL PRÓXIMO PARTIDO (pedido de Wilber): calcula
## cuántos días faltan, te deja elegir qué hacer CADA día, y con un botón
## avanza todos esos días aplicando la actividad de cada uno — el jugador
## evoluciona (atributos, forma, reputación, afición) en el camino.
## Fuente única de avance: WorldTickEngine.advance_day (ver CLAUDE.md).

@onready var body: VBoxContainer = $Root/Scroll/Margin/VBox
@onready var back_button: Button = $Root/Scroll/Margin/VBox/BackButton

var _player: PlayerData = null
var _plan: Array = []          # id de actividad por día
var _days: int = 0
const _MAX_DAYS := 12
const _COLORS := {
	"GREEN": Color(0.30, 0.80, 0.46), "PURPLE": Color(0.72, 0.45, 0.95),
	"BLUE": Color(0.36, 0.66, 0.98), "GOLD": Color(0.95, 0.77, 0.30),
	"RED": Color(0.94, 0.38, 0.38),
}

func _ready() -> void:
	WorldTickEngine.load_runtime()
	_player = SaveManager.load_player()
	var sc := $Root/Scroll as ScrollContainer
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# UiScroll.make_touch() acá en _ready(), no vía pad_bottom() al final de
	# _render() — _render() tiene 2 early-return (sin jugador / sin días
	# libres) que antes dejaban el scroll sin el tratamiento táctil
	# completo (bug real de la auditoría).
	UiScroll.make_touch(sc)
	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	back_button.pressed.connect(func(): Nav.back())

	var nxt: Dictionary = WorldTickEngine.next_user_fixture(_player.club_id if _player != null else "")
	_days = 0
	if not nxt.is_empty():
		_days = clampi(int(nxt.get("epoch_day", 0)) - WorldTickEngine.current_epoch_day, 0, _MAX_DAYS)
	_plan = PlannerEngine.default_plan(_days)
	_render()

func _render() -> void:
	for c in body.get_children():
		if c != back_button:
			c.queue_free()

	var head := Label.new()
	head.text = "PLANIFICAR HASTA EL PRÓXIMO PARTIDO"
	head.add_theme_font_override("font", Styles.font_black())
	head.add_theme_font_size_override("font_size", 17)
	body.add_child(head)
	body.move_child(head, 0)

	if _player == null:
		_add_line("Sin jugador activo.", Styles.GRAY_TEXT)
		body.move_child(back_button, body.get_child_count() - 1)
		return

	if _days <= 0:
		_add_line("No hay días libres antes de tu próximo partido. Volvé después de jugarlo.", Styles.GRAY_TEXT)
		body.move_child(back_button, body.get_child_count() - 1)
		return

	var today: int = WorldTickEngine.current_epoch_day
	_add_line("Faltan %d día%s para el partido. Elegí qué hacer cada uno (tocá para cambiar):" % [
		_days, "" if _days == 1 else "s"], Styles.GRAY_TEXT)

	for i in range(_days):
		body.add_child(_day_row(i, today + i + 1))

	# Resumen rápido del plan.
	var counts: Dictionary = {}
	for id in _plan:
		counts[id] = int(counts.get(id, 0)) + 1
	var parts: Array = []
	for a in PlannerEngine.DAY_ACTIVITIES:
		if counts.has(a["id"]):
			parts.append("%d× %s" % [counts[a["id"]], a["name"]])
	_add_line("Plan: " + " · ".join(parts), Styles.GRAY_TEXT)

	var go := Button.new()
	go.text = "Aceptar el plan y avanzar %d día%s" % [_days, "" if _days == 1 else "s"]
	go.custom_minimum_size = Vector2(0, 52)
	go.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(go, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	go.pressed.connect(_accept_plan)
	body.add_child(go)

	UiScroll.pad_bottom(body)
	body.move_child(back_button, body.get_child_count() - 1)

func _add_line(text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	body.add_child(l)

func _day_row(idx: int, epoch_day: int) -> PanelContainer:
	var act: Dictionary = PlannerEngine.day_activity(String(_plan[idx]))
	var accent: Color = _COLORS.get(String(act.get("color", "GREEN")), Styles.GREEN)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(accent, Styles.CARD_DARK, 10))
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 46)
	btn.pressed.connect(func():
		var n: int = PlannerEngine.DAY_ACTIVITIES.size()
		var cur: int = 0
		for k in range(n):
			if PlannerEngine.DAY_ACTIVITIES[k]["id"] == _plan[idx]:
				cur = k
		_plan[idx] = String(PlannerEngine.DAY_ACTIVITIES[(cur + 1) % n]["id"])
		_render())
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 12)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	var dl := Label.new()
	dl.text = "Día %d" % (idx + 1)
	dl.custom_minimum_size = Vector2(56, 0)
	dl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	dl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dl)
	var an := Label.new()
	an.text = String(act.get("name", "?"))
	an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	an.add_theme_font_override("font", Styles.font_semibold())
	an.add_theme_color_override("font_color", accent)
	an.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(an)
	var chg := Label.new()
	chg.text = "cambiar ›"
	chg.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	chg.add_theme_font_size_override("font_size", 10)
	chg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chg)
	m.add_child(row)
	btn.add_child(m)
	panel.add_child(btn)
	return panel

func _accept_plan() -> void:
	if _player == null or _plan.is_empty():
		return
	var applied: int = 0
	for id in _plan:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("planday:%d:%s" % [WorldTickEngine.current_epoch_day, id]) ^ SaveManager.load_world_seed()
		var fresh := SaveManager.load_player()
		if fresh == null:
			break
		PlannerEngine.apply_day(fresh, WorldTickEngine.season, String(id), rng)
		SaveManager.save_player(fresh)
		SaveManager.save_season(WorldTickEngine.season)
		WorldTickEngine.advance_day()
		applied += 1
		# Cortar si aparece algo que hay que ver (fin de temporada, contrato,
		# o un partido inesperado hoy).
		if not WorldTickEngine.last_season_report.is_empty():
			get_tree().change_scene_to_file("res://scenes/SeasonCeremony/SeasonCeremony.tscn")
			return
		if WorldTickEngine.season.get("awaiting_contract_decision", false):
			get_tree().change_scene_to_file("res://scenes/ContractDecision/ContractDecision.tscn")
			return
		# Bug real encontrado en la auditoría: este loop reimplementaba el
		# avance de días en vez de pasar por WorldTickEngine.advance_until()
		# (la fuente única real, CLAUDE.md) — el comentario de arriba
		# prometía cortar "si aparece... un partido inesperado hoy", pero
		# nunca se implementó. Un partido de club O de selección podía
		# quedar tapado por el plan multi-día y resolverse solo por la IA de
		# fondo, sin acreditar nada (mismo bug que ya se había corregido en
		# advance_until_live()/advance_until(), nunca replicado acá).
		if not WorldTickEngine.pending_user_fixture().is_empty() or not WorldTickEngine.pending_user_national_fixture().is_empty():
			get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")
			return
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")
