extends Control

## Calendario mensual del club del usuario — pedido explícito ("como en
## el modo DT de EAFC26"): cuadrícula Lun-Dom con los partidos de liga,
## copa doméstica y amistosos de ESE mes, más los días de ventana de
## fichajes y las fechas FIFA (selecciones nacionales, ver más abajo).
##
## "que desde el calendario yo pueda escoger hasta qué fecha quiero que
## se simule el mundo", pedido explícito: tocar CUALQUIER día (tenga
## evento o no) lo selecciona, y "Simular hasta esta fecha" delega en
## WorldTickEngine.advance_until_live() — fuente única de avance de tiempo
## (CLAUDE.md), esta pantalla nunca repite el bucle de advance_day() ni
## reinventa cuándo detenerse (partido propio pendiente, decisión de
## contrato, cierre de temporada), solo reacciona a por qué se detuvo.
##
## Mientras simula muestra un panel con la fecha avanzando, una barra de
## progreso y el marcador de cada jornada de tu liga a medida que se
## resuelve (pedido de Wilber: "que te vaya mostrando cómo avanza y el
## resultado de cada partido"). Si en el camino hay un partido tuyo, se
## para y ofrece simularlo (va a MatchSummary, con todas sus consecuencias,
## y al volver el Calendario retoma solo hasta la fecha objetivo).

const _WEEKDAY_LABELS := ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
const _MONTH_NAMES := [
	"", "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
	"Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre",
]
const _MES_ABBR := ["", "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]

const _COLOR_LEAGUE := Styles.BLUE
const _COLOR_CUP := Styles.GOLD
const _COLOR_FRIENDLY := Styles.GREEN
const _COLOR_MARKET := Styles.PURPLE
const _COLOR_INTL := Color("#c0c0c0")   # plateado — torneos internacionales (pedido de Wilber)
const _COLOR_SEASON_END := Styles.RED   # último día de temporada (pedido de Wilber: marcarlo)
const _COLOR_FIFA := Color("#e2822f")   # naranja selecciones — antes un azul casi idéntico al de Liga, pedido de Wilber: "cambia a naranja el color de los partidos de selección" para poder distinguirlos de un vistazo

@onready var prev_button: Button = $Root/VBox/NavRow/PrevButton
@onready var next_button: Button = $Root/VBox/NavRow/NextButton
@onready var month_label: Label = $Root/VBox/NavRow/MonthLabel
@onready var weekday_row: GridContainer = $Root/VBox/WeekdayRow
@onready var days_grid: GridContainer = $Root/VBox/DaysGrid
@onready var legend_row: HFlowContainer = $Root/VBox/LegendRow
@onready var detail_card: PanelContainer = $Root/VBox/DetailCard
@onready var detail_label: Label = $Root/VBox/DetailCard/DetailMargin/DetailLabel
@onready var simulate_button: Button = $Root/VBox/SimulateButton
@onready var back_button: Button = $Root/VBox/BackButton

var _year: int = 2026
var _month: int = 7
var _club_id: String = ""
var _today_epoch_day: int = 0
var _selected_epoch_day: int = -1

## País/eliminatoria del usuario, para marcar SOLO los días con partido
## real de selección dentro de una ventana FIFA (pedido de Wilber: "en
## las fechas FIFA también deberían tener marcadas solo los dos partidos
## de esa fecha FIFA y no toda la semana" — antes CUALQUIER día de los
## 10 de la ventana se pintaba igual, sin importar si ESE día tenía
## partido programado de verdad). `_nat_qualifying` se recalcula UNA vez
## por render del mes (_build_days_grid), no por celda — QualifyingEngine.
## resolve() arma toda la tabla/grupos de la confederación, no es gratis
## como para llamarlo hasta 10 veces por mes visible.
var _nat_country: String = ""
var _nat_qualifying: Dictionary = {}
## Mundial/copa continental del ciclo actual (si corresponde) — BUG REAL
## arreglado (Wilber: "cuando me convocan a la selección, no me sale el
## partido en el calendario semanal"): _event_for_day() solo pre-veía
## partidos de ELIMINATORIA en días que no son "hoy" — un partido de
## Mundial o de copa continental en cualquier otro día del mes NUNCA se
## marcaba, aunque estuviera programado y confirmado. Calculados una vez
## por render del mes, mismo criterio que _nat_qualifying.
var _nat_wc: Dictionary = {}
var _nat_ncup: Dictionary = {}

# --- Simulación en vivo ---
var _sim_running: bool = false
var _sim_target: int = 0
var _sim_from: int = 0
var _sim_matchday_epochs: Dictionary = {}   # epoch_day -> true, jornadas de liga ya registradas en el log
var _sim_md_days: Dictionary = {}           # epoch_day -> true, días que SON jornada de tu liga (calendario fijo)
var _sim_overlay: Control = null
var _sim_date_lbl: Label = null
var _sim_bar: ProgressBar = null
var _sim_log: VBoxContainer = null
var _sim_log_scroll: ScrollContainer = null
var _sim_action_row: VBoxContainer = null
var _sim_match_launching: bool = false

func _ready() -> void:
	WorldTickEngine.load_runtime()
	var player: PlayerData = SaveManager.load_player()
	_club_id = player.club_id if player != null else ""
	_nat_country = player.country if player != null else ""
	_today_epoch_day = WorldTickEngine.current_epoch_day

	var today_date := CalendarUtils.epoch_day_to_date(_today_epoch_day)
	_year = int(today_date["year"])
	_month = int(today_date["month"])

	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	# Flechas de mes grandes y redondeadas (estilo app, 9-oct).
	for nb in [[prev_button, "‹"], [next_button, "›"]]:
		var b: Button = nb[0]
		b.text = String(nb[1])
		b.custom_minimum_size = Vector2(56, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", Styles.font_black())
		b.add_theme_font_size_override("font_size", 26)
		Styles.styled_button(b, Styles.card_flat(Color(0.13, 0.15, 0.22), 12), Color(0.55, 0.62, 1.0))
	month_label.add_theme_font_override("font", Styles.font_semibold())
	month_label.add_theme_font_size_override("font_size", 22)
	Styles.styled_button(prev_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	Styles.styled_button(next_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	back_button.pressed.connect(_on_back_pressed)
	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	simulate_button.pressed.connect(_on_simulate_pressed)
	simulate_button.icon = Icons.load_icon(Icons.FAST_FORWARD)
	simulate_button.add_theme_constant_override("icon_max_width", 24)
	Styles.styled_button(simulate_button, Styles.pill_filled(Styles.AMBER), Color.BLACK)

	_build_weekday_header()
	_build_legend()
	_landscape_split()
	_render()
	if _land:
		_land_upcoming()   # después de _render: ahí se cargan los datos de selección
		# El panel de la derecha arranca mostrando HOY (si no, quedaba vacío).
		var td: Dictionary = CalendarUtils.epoch_day_to_date(_today_epoch_day)
		_select_day(int(td["day"]), _today_epoch_day, _event_for_day(_today_epoch_day))

	# ¿Veníamos de simular hasta una fecha y se cortó para jugar un partido
	# propio? Al volver de MatchSummary retomamos solo hasta el objetivo.
	var resume_target: int = int(WorldTickEngine.season.get("cal_sim_target", 0))
	if resume_target > WorldTickEngine.current_epoch_day:
		# Bug real de la auditoría (ronda 4): si el día en el que se cortó
		# tenía DOS partidos propios el mismo día (club Y selección —
		# puede pasar de verdad: Mundial de Clubes y copa continental de
		# CONMEBOL/CAF caen el mismo día del mismo año), acá se reanudaba
		# la simulación a ciegas apenas volvías de jugar el de club, sin
		# volver a mirar si todavía quedaba el de selección pendiente ESE
		# mismo día — advance_until_live() avanza el día ANTES de
		# chequear, así que ese partido de selección quedaba resuelto
		# por la IA de fondo sin acreditarte nada, sin aviso. Hub.gd ya se
		# cuidaba de esto (nunca reanuda si _today_unplayed_fixture() no
		# está vacío); acá faltaba el mismo chequeo.
		var still_pending: Dictionary = WorldTickEngine.pending_user_fixture()
		if still_pending.is_empty():
			still_pending = WorldTickEngine.pending_user_national_fixture()
		if not still_pending.is_empty():
			call_deferred("_offer_user_match")
		else:
			call_deferred("_start_calendar_sim", resume_target)
	elif resume_target > 0:
		WorldTickEngine.season.erase("cal_sim_target")
		SaveManager.save_season(WorldTickEngine.season)

func _build_weekday_header() -> void:
	for child in weekday_row.get_children():
		child.queue_free()
	for label_text in _WEEKDAY_LABELS:
		var lbl := Label.new()
		lbl.text = label_text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		lbl.add_theme_font_size_override("font_size", 12)
		weekday_row.add_child(lbl)

func _build_legend() -> void:
	for child in legend_row.get_children():
		child.queue_free()
	legend_row.add_child(_legend_box("Local", Styles.CARD_DARK))
	legend_row.add_child(_legend_box("Visitante", _AWAY_BG))
	legend_row.add_child(_legend_chip("Liga", _COLOR_LEAGUE))
	legend_row.add_child(_legend_chip("Copa", _COLOR_CUP))
	legend_row.add_child(_legend_chip("Internacional", _COLOR_INTL))
	legend_row.add_child(_legend_chip("Amistoso", _COLOR_FRIENDLY))
	legend_row.add_child(_legend_chip("Mercado", _COLOR_MARKET))
	legend_row.add_child(_legend_chip("Fecha FIFA", _COLOR_FIFA))
	legend_row.add_child(_legend_chip("Fin de temporada", _COLOR_SEASON_END))

func _legend_box(label_text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var sq := PanelContainer.new()
	sq.custom_minimum_size = Vector2(18, 12)
	var sb := Styles.card_flat(color, 3)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.35)
	sq.add_theme_stylebox_override("panel", sb)
	row.add_child(sq)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	row.add_child(lbl)
	return row

func _legend_chip(label_text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var dot := PanelContainer.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.add_theme_stylebox_override("panel", Styles.circle(color, 10))
	row.add_child(dot)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	row.add_child(lbl)
	return row

func _on_prev_pressed() -> void:
	_month -= 1
	if _month < 1:
		_month = 12
		_year -= 1
	_render()

func _on_next_pressed() -> void:
	_month += 1
	if _month > 12:
		_month = 1
		_year += 1
	_render()

func _on_back_pressed() -> void:
	if _sim_running:
		return
	# Abandonar el calendario cancela un avance a medias (si lo hubiera).
	if WorldTickEngine.season.has("cal_sim_target"):
		WorldTickEngine.season.erase("cal_sim_target")
		SaveManager.save_season(WorldTickEngine.season)
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")

func _render() -> void:
	month_label.text = "%s %d" % [_MONTH_NAMES[_month], _year]
	detail_label.text = ""
	detail_card.visible = false
	_selected_epoch_day = -1
	_update_simulate_button()
	_build_days_grid()

func _build_days_grid() -> void:
	for child in days_grid.get_children():
		child.queue_free()

	_nat_qualifying = {}
	_nat_wc = {}
	_nat_ncup = {}
	if _nat_country != "":
		var nat_confederation: String = Confederations.confederation_of(_nat_country)
		if nat_confederation != "":
			_nat_qualifying = WorldTickEngine.national_qualifying_for(nat_confederation)
			_nat_wc = WorldTickEngine.world_cup_this_cycle()
			_nat_ncup = WorldTickEngine.national_cup_for(nat_confederation)

	var first_weekday: int = CalendarUtils.weekday_of(_year, _month, 1)
	for i in range(first_weekday):
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		days_grid.add_child(spacer)

	var total_days: int = CalendarUtils.days_in_month(_year, _month)
	for day in range(1, total_days + 1):
		var epoch_day: int = CalendarUtils.date_to_epoch_day(_year, _month, day)
		days_grid.add_child(_make_day_cell(day, epoch_day))

## Último día de la temporada actual — el día siguiente dispara el
## rollover (ver WorldTickEngine._tick_sentiment: dispara cuando
## current_epoch_day > season_start + SEASON_TOTAL_DAYS, o sea que ESE
## día de acá es el último "normal"). Pedido de Wilber: "dime el día fijo
## en el que termina, o márcalo en el calendario".
func _season_end_epoch_day() -> int:
	return int(WorldTickEngine.season.get("season_start_epoch_day", 0)) + SeasonCalendar.SEASON_TOTAL_DAYS

## Solo el día de INICIO o el de CIERRE de cualquiera de las 2 ventanas
## de fichajes de la temporada (verano/invierno, ver SeasonCalendar.
## TRANSFER_WINDOW_DAYS/MID_SEASON_TRANSFER_WINDOW_OFFSET) — "" el resto
## de los 21 días de cada una. Antes se pintaba la ventana entera pareja
## (pedido de Wilber: "pinta solo el día de inicio y el día final").
func _market_window_edge_label(epoch_day: int) -> String:
	if WorldTickEngine.season.is_empty():
		return ""
	var start: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
	var w: int = SeasonCalendar.TRANSFER_WINDOW_DAYS
	var mid: int = SeasonCalendar.MID_SEASON_TRANSFER_WINDOW_OFFSET
	if epoch_day == start or epoch_day == start + mid:
		return "Arranca la ventana de fichajes"
	if epoch_day == start + w or epoch_day == start + mid + w:
		return "Cierra la ventana de fichajes"
	return ""

func _event_for_day(epoch_day: int) -> Dictionary:
	if _club_id != "" and epoch_day == _season_end_epoch_day():
		return {"color": _COLOR_SEASON_END, "label": "Fin de temporada", "fixture": {}}
	# Antes se pintaban los 21 días completos de la ventana de fichajes —
	# pedido de Wilber: "pinta solo el día de inicio y el día final". BUG
	# REAL encontrado con la captura de Wilber: el día de CIERRE (offset
	# 21, múltiplo de 7) cae SIEMPRE el mismo día de la semana que el de
	# inicio, y los amistosos de pretemporada se programan semanales — el
	# cierre coincidía sistemáticamente con un amistoso, que lo tapaba por
	# completo (mostraba el inicio pero nunca el cierre). Un amistoso es
	# de relleno; el cierre del mercado es información real y puntual, así
	# que gana sobre un amistoso. Los partidos oficiales de club y selección
	# conservan prioridad sobre el rótulo del mercado.
	var market_edge: String = _market_window_edge_label(epoch_day) if _club_id != "" else ""
	var fixture: Dictionary = WorldTickEngine.user_fixture_on(epoch_day, _club_id) if _club_id != "" else {}
	if not fixture.is_empty():
		var competition: String = String(fixture.get("competition", ""))
		if competition == "friendly" and market_edge != "":
			return {"color": _COLOR_MARKET, "label": market_edge, "fixture": {}}
		if competition == "friendly":
			return {"color": _COLOR_FRIENDLY, "label": "Amistoso", "fixture": fixture}
		if competition == "league":
			return {"color": _COLOR_LEAGUE, "label": "Liga J%d" % int(fixture.get("matchday", 0)), "fixture": fixture}
		if competition == "continental":
			return {"color": _COLOR_INTL, "label": String(fixture.get("round_name", "Continental")), "fixture": fixture}
		return {"color": _COLOR_CUP, "label": String(fixture.get("round_name", "Copa")), "fixture": fixture}
	# user_fixture_on() solo devuelve "el próximo" continental — el resto de
	# la fase de grupos/eliminatoria hay que pedirla aparte para pintarla.
	var cont: Dictionary = WorldTickEngine.user_continental_fixture_on(epoch_day, _club_id) if _club_id != "" else {}
	if not cont.is_empty():
		return {"color": _COLOR_INTL, "label": String(cont.get("round_name", "Continental")), "fixture": cont}
	# Partidos de selección: Mundial / copa continental / eliminatoria.
	# BUG REAL arreglado (Wilber: "cuando me convocan a la selección, no
	# me sale el partido en el calendario semanal"): todo este bloque
	# vivía adentro de un `if WorldTickEngine.is_day_in_international_
	# window(epoch_day):` — pero esa función SOLO conoce las 5 ventanas
	# FIFA "regulares" de la eliminatoria (offsets fijos de la
	# temporada). El Mundial y la copa continental corren en un bloque de
	# calendario TOTALMENTE APARTE (SeasonCalendar.world_cup_blackout_for_
	# season(), Parte 91p — arranca cerca del día 10, no en ninguna de
	# esas 5 ventanas), así que ese gate los excluía de raíz: ni el día
	# del partido de Mundial (ni siquiera "hoy") llegaba a evaluarse.
	# Para HOY, muestra el partido programado aunque no te hayan convocado.
	# Solo el convocado recibe la acción de jugar; al resto lo resuelve la IA.
	if epoch_day == _today_epoch_day:
		var nat_fx: Dictionary = WorldTickEngine.user_national_fixture_on(epoch_day)
		if not nat_fx.is_empty():
			var comp: String = String(nat_fx.get("competition", "qualifying"))
			var comp_label: String
			match comp:
				"world_cup": comp_label = "Mundial"
				"national_cup": comp_label = "Copa continental"
				_: comp_label = "Eliminatoria"
			var called_up: bool = bool(nat_fx.get("called_up", false))
			return {"color": _COLOR_FIFA,
				"label": "%s vs %s" % [comp_label, String(nat_fx.get("opponent", "?"))],
				"fixture": nat_fx, "callup_state": "called" if called_up else "not_called"}
		return {}
	# Cualquier OTRO día: para un día futuro arbitrario no hay forma
	# barata de saber si te van a convocar (eso recién se sabe el día que
	# abre la ventana/arranca el torneo) — se muestra el partido
	# PROGRAMADO igual, sin depender de la convocatoria (mundo vivo,
	# mismo criterio que ya tenía la eliminatoria). Mismo orden de
	# prioridad que pending_user_national_fixture() usa para HOY: Mundial
	# -> copa continental -> eliminatoria.
	var intl: Dictionary = SaveManager.load_international()
	if not _nat_wc.is_empty():
		var wc_fx: Dictionary = WorldCupEngine.next_user_fixture(_nat_wc, _nat_country, epoch_day, intl.get("wc_results", {}))
		if not wc_fx.is_empty():
			var wc_home: String = String(wc_fx.get("home_country", ""))
			var wc_away: String = String(wc_fx.get("away_country", ""))
			var wc_is_home: bool = wc_home == _nat_country
			var wc_opp: String = wc_away if wc_is_home else wc_home
			var wc_scheduled := {"opponent": wc_opp, "is_home": wc_is_home,
				"epoch_day": epoch_day, "competition": "world_cup", "called_up": false}
			return {"color": _COLOR_FIFA, "label": "Mundial vs %s" % wc_opp,
				"fixture": wc_scheduled, "callup_state": "pending"}
	if not _nat_ncup.is_empty():
		var ncup_fx: Dictionary = NationalCupEngine.next_user_fixture(_nat_ncup, _nat_country, epoch_day, intl.get("natcup_results", {}))
		if not ncup_fx.is_empty():
			var ncup_home: String = String(ncup_fx.get("home_country", ""))
			var ncup_away: String = String(ncup_fx.get("away_country", ""))
			var ncup_is_home: bool = ncup_home == _nat_country
			var ncup_opp: String = ncup_away if ncup_is_home else ncup_home
			var ncup_scheduled := {"opponent": ncup_opp, "is_home": ncup_is_home,
				"epoch_day": epoch_day, "competition": "national_cup", "called_up": false}
			return {"color": _COLOR_FIFA, "label": "Copa continental vs %s" % ncup_opp,
				"fixture": ncup_scheduled, "callup_state": "pending"}
	if WorldTickEngine.is_day_in_international_window(epoch_day) and not _nat_qualifying.is_empty():
		var q_fx: Dictionary = QualifyingEngine.user_fixture_today(_nat_qualifying, _nat_country, epoch_day)
		if not q_fx.is_empty():
			q_fx["competition"] = "qualifying"
			q_fx["called_up"] = false
			return {"color": _COLOR_FIFA, "label": "Eliminatoria vs %s" % String(q_fx.get("opponent", "?")),
				"fixture": q_fx, "callup_state": "pending"}
	if market_edge != "":
		return {"color": _COLOR_MARKET, "label": market_edge, "fixture": {}}
	return {}

## Celda del día, estilo app (9-oct, referencia de Wilber): número arriba a
## la izquierda, ícono de la competición arriba a la derecha, ESCUDO del
## rival al medio y la jornada/ronda abajo. LOCAL = celda oscura,
## VISITANTE = celda clara. Hoy = borde azul; el día tocado = dorado. Días
## sin partido pero con evento (mercado, fin de temporada, selección sin
## rival conocido) llevan una franja del color del evento.
const _AWAY_BG := Color(0.93, 0.94, 0.96)
const _DARK_TEXT := Color(0.08, 0.09, 0.12)

func _make_day_cell(day: int, epoch_day: int) -> Control:
	var event: Dictionary = _event_for_day(epoch_day)
	var is_today: bool = epoch_day == _today_epoch_day
	var is_selected: bool = epoch_day == _selected_epoch_day
	var fx: Dictionary = event.get("fixture", {})
	var has_match: bool = not fx.is_empty() and (fx.has("home_club_id") or fx.has("opponent") or fx.has("home_country"))
	var is_away: bool = false
	var rival_id: String = ""
	if has_match and fx.has("home_club_id"):
		is_away = String(fx.get("away_club_id", "")) == _club_id
		rival_id = String(fx.get("home_club_id", "")) if is_away else String(fx.get("away_club_id", ""))
	elif has_match and fx.has("opponent"):
		is_away = not bool(fx.get("is_home", true))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 62 if _land else 86)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg: Color = _AWAY_BG if (has_match and is_away) else Styles.CARD_DARK
	if _land and not (has_match and is_away):
		bg = Color(bg, 0.8)   # deja ver el fondo del club
	var style := Styles.card_flat(bg, 10)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	if is_selected or is_today:
		style.set_border_width_all(3)
		style.border_color = Styles.GOLD if is_selected else Color(0.42, 0.52, 1.0)
	elif not event.is_empty() and not has_match:
		style.border_width_bottom = 4
		style.border_color = event.get("color", Styles.GRAY_TEXT)
	panel.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var day_lbl := Label.new()
	day_lbl.text = str(day)
	day_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_lbl.add_theme_font_override("font", Styles.font_semibold())
	day_lbl.add_theme_font_size_override("font_size", 14)
	day_lbl.add_theme_color_override("font_color", _DARK_TEXT if (has_match and is_away) else Color(0.9, 0.91, 0.95))
	day_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(day_lbl)
	if not event.is_empty():
		top.add_child(_comp_badge(event))
	vb.add_child(top)

	if has_match:
		var mid := CenterContainer.new()
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if rival_id != "":
			var crest := Styles.club_crest(rival_id, 34)
			crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mid.add_child(crest)
		else:
			# Selección: bandera/inicial del rival.
			var opp := Label.new()
			opp.text = String(fx.get("opponent", "?")).substr(0, 3).to_upper()
			opp.add_theme_font_override("font", Styles.font_black())
			opp.add_theme_color_override("font_color", _COLOR_FIFA)
			mid.add_child(opp)
		vb.add_child(mid)
		var tag := Label.new()
		tag.text = _short_tag(event)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.clip_text = true
		tag.add_theme_font_override("font", Styles.font_semibold())
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", _DARK_TEXT if is_away else Color(0.9, 0.91, 0.95))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(tag)
	panel.add_child(vb)

	# CUALQUIER día se puede tocar (tenga evento o no) — "escoger hasta qué
	# fecha simular", pedido explícito, no solo días con partido/mercado.
	UiScroll.on_tap(panel, func(): _select_day(day, epoch_day, event))
	if is_today and not Preferences.reduce_motion:
		# HOY late suave (P1b #13).
		panel.ready.connect(func(): Juice.pulse(panel, 1.06, 1.4))
	return panel

## Ícono chico de la competición (arriba a la derecha de la celda).
func _comp_badge(event: Dictionary) -> Control:
	var col: Color = event.get("color", Styles.GRAY_TEXT)
	var letter: String = "•"
	# (if y no `match`: un match contra constantes que vienen de OTRA clase
	# —Styles.BLUE— no compara bien y caía en la rama equivocada.)
	for pair in [[_COLOR_LEAGUE, "L"], [_COLOR_CUP, "C"], [_COLOR_INTL, "I"], [_COLOR_FRIENDLY, "A"],
			[_COLOR_FIFA, "S"], [_COLOR_MARKET, "M"], [_COLOR_SEASON_END, "F"]]:
		if col.is_equal_approx(pair[0]):
			letter = String(pair[1])
			break
	var b := PanelContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.custom_minimum_size = Vector2(18, 18)
	var sb := Styles.card_flat(col, 5)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	b.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = letter
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Styles.font_black())
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Styles.contrasting_text_color(col))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	return b

## "J12", "Copa", "Amist." — lo que va abajo del escudo.
func _short_tag(event: Dictionary) -> String:
	match String(event.get("callup_state", "")):
		"called": return "Convocado"
		"not_called": return "No conv."
		"pending": return "Conv. pend."
	var lab: String = String(event.get("label", ""))
	if lab.begins_with("Liga J"):
		return lab.substr(5)
	if lab == "Amistoso":
		return "Amist."
	if lab.length() > 9:
		return lab.substr(0, 8) + "."
	return lab

## Tocar un día lo selecciona como objetivo de "Simular hasta esta fecha"
## (si es futuro) y muestra su detalle (evento real, o solo la fecha si
## no tiene nada) — separado de _build_days_grid() para poder refrescar
## SOLO los bordes de selección sin pisar el texto de detalle recién puesto.
func _select_day(day: int, epoch_day: int, event: Dictionary) -> void:
	if _sim_running:
		return
	_selected_epoch_day = epoch_day
	detail_card.visible = not _land
	_land_detail(day, epoch_day, event)
	if event.is_empty():
		detail_label.text = "%d de %s de %d — sin evento" % [day, _MONTH_NAMES[_month], _year]
		detail_card.add_theme_stylebox_override("panel", Styles.card())
	else:
		_show_detail(day, event)
		detail_card.add_theme_stylebox_override("panel", Styles.card_accent(event.get("color", Styles.CARD_DARK)))
	_update_simulate_button()
	_build_days_grid()

## Visible solo para una fecha FUTURA (simular "hasta hoy" o al pasado no
## tiene sentido) — el texto muestra cuántos días de golpe implica, para
## que quede claro antes de tocar (puede incluir un partido propio en el
## medio, ver _on_simulate_pressed).
func _update_simulate_button() -> void:
	if _selected_epoch_day == _today_epoch_day:
		var today_event := _event_for_day(_today_epoch_day)
		var today_fixture: Dictionary = today_event.get("fixture", {})
		if today_fixture.has("opponent") and bool(today_fixture.get("called_up", false)):
			simulate_button.text = "Jugar con la selección"
			simulate_button.icon = Icons.load_icon(Icons.PLAY)
			Styles.styled_button(simulate_button, Styles.pill_filled(Styles.GREEN), Color.WHITE)
			simulate_button.visible = true
			simulate_button.disabled = false
		elif today_fixture.has("opponent"):
			simulate_button.text = "No convocado · partido simulado"
			simulate_button.icon = Icons.load_icon(Icons.FAST_FORWARD)
			Styles.styled_button(simulate_button, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
			simulate_button.visible = true
			simulate_button.disabled = true
		else:
			simulate_button.visible = false
		return
	if _selected_epoch_day < _today_epoch_day:
		simulate_button.visible = false
		return
	var days: int = _selected_epoch_day - _today_epoch_day
	simulate_button.text = "Simular %d día%s hasta esta fecha" % [days, "s" if days != 1 else ""]
	simulate_button.icon = Icons.load_icon(Icons.FAST_FORWARD)
	Styles.styled_button(simulate_button, Styles.pill_filled(Styles.AMBER), Color.BLACK)
	simulate_button.visible = true
	simulate_button.disabled = false

## Arranca la simulación en vivo hasta la fecha seleccionada. TODO el
## avance lo hace WorldTickEngine.advance_until_live (fuente única de
## avance de tiempo) — acá solo se pinta el progreso y se reacciona a por
## qué se detuvo.
func _on_simulate_pressed() -> void:
	if _sim_running:
		return
	if _selected_epoch_day == _today_epoch_day:
		var event := _event_for_day(_today_epoch_day)
		var fx: Dictionary = event.get("fixture", {})
		if fx.has("opponent") and bool(fx.get("called_up", false)):
			_launch_national_fixture(fx)
		return
	if _selected_epoch_day < _today_epoch_day:
		return
	# Si hoy hay un partido tuyo sin jugar, primero se juega desde el Hub —
	# el avance lo saltaría.
	if not WorldTickEngine.pending_user_fixture().is_empty():
		_open_sim_overlay()
		_sim_date_lbl.text = "Tenés un partido pendiente hoy"
		_sim_log_line("Jugá el partido de hoy desde el Inicio antes de simular.", Styles.AMBER)
		_show_sim_close()
		return
	if not WorldTickEngine.pending_user_national_fixture().is_empty():
		_open_sim_overlay()
		_sim_date_lbl.text = "Tenés un partido de selección pendiente hoy"
		_sim_log_line("Juega con tu selección antes de avanzar el calendario.", Styles.AMBER)
		_show_sim_close()
		return
	_start_calendar_sim(_selected_epoch_day)


func _launch_national_fixture(fx: Dictionary) -> void:
	if _sim_match_launching:
		return
	var player: PlayerData = SaveManager.load_player()
	if player == null:
		return
	_sim_match_launching = true
	simulate_button.disabled = true
	var prep: Dictionary = NationalTeamMatchLauncher.prepare(
		WorldTickEngine.world, WorldTickEngine.world_seed,
		int(WorldTickEngine.season.get("season_start_epoch_day", 0)), player, player.country,
		String(fx.get("opponent", "")), bool(fx.get("is_home", true)),
		float(fx.get("user_start_chance", 0.0)), "res://scenes/Calendar/Calendar.tscn", false,
		String(fx.get("competition", "qualifying")), bool(fx.get("is_knockout", false)), String(fx.get("key", "")))
	if not bool(prep.get("ok", false)):
		_sim_match_launching = false
		simulate_button.disabled = false
		return
	(Engine.get_main_loop() as SceneTree).change_scene_to_file("res://scenes/PreMatch/PreMatch.tscn")

func _start_calendar_sim(target: int) -> void:
	if _sim_running:
		return
	_sim_target = target
	_sim_from = WorldTickEngine.current_epoch_day
	_sim_matchday_epochs.clear()
	_sim_md_days.clear()
	var lid0: int = int(WorldTickEngine.season.get("league_id", -1))
	if lid0 >= 0:
		for rnd0 in WorldTickEngine.league_fixture_rounds(lid0):
			_sim_md_days[int(rnd0.get("epoch_day", 0))] = true
	WorldTickEngine.season["cal_sim_target"] = target
	SaveManager.save_season(WorldTickEngine.season)
	_open_sim_overlay()
	_sim_log_clear()
	_sim_date_lbl.text = _long_date(WorldTickEngine.current_epoch_day)
	_sim_bar.value = 0.0
	await _run_calendar_sim()

func _run_calendar_sim() -> void:
	_sim_running = true
	simulate_button.disabled = true
	back_button.disabled = true
	if not WorldTickEngine.sim_tick.is_connected(_on_sim_tick):
		WorldTickEngine.sim_tick.connect(_on_sim_tick)
	var reason: String = await WorldTickEngine.advance_until_live(_sim_target)
	if WorldTickEngine.sim_tick.is_connected(_on_sim_tick):
		WorldTickEngine.sim_tick.disconnect(_on_sim_tick)
	_sim_running = false
	back_button.disabled = false

	match reason:
		"contract_decision":
			get_tree().change_scene_to_file("res://scenes/ContractDecision/ContractDecision.tscn")
			return
		"season_ended":
			get_tree().change_scene_to_file("res://scenes/SeasonCeremony/SeasonCeremony.tscn")
			return
		"match_pending":
			_offer_user_match()
			return
		_:
			WorldTickEngine.season.erase("cal_sim_target")
			SaveManager.save_season(WorldTickEngine.season)
			_log_league_results_up_to(WorldTickEngine.current_epoch_day)  # flush jornadas restantes
			_sim_date_lbl.text = _long_date(WorldTickEngine.current_epoch_day)
			_sim_bar.value = 100.0
			_sim_log_line("Listo — mundo simulado hasta el %s." % _short_date(WorldTickEngine.current_epoch_day), Styles.GREEN)
			_show_sim_close()

## Se paró porque hay un partido tuyo en el camino. Lo mostramos y dejamos
## un botón para simularlo: va a MatchSummary (con TODAS sus consecuencias
## reales — no hay una segunda vía de resolución) y al volver el Calendario
## retoma el avance hasta la fecha objetivo (cal_sim_target sigue guardado).
func _offer_user_match() -> void:
	var fx: Dictionary = WorldTickEngine.pending_user_fixture()
	if fx.is_empty():
		fx = WorldTickEngine.pending_user_national_fixture()
	if fx.is_empty():
		# raro: reintentar el avance
		await _run_calendar_sim()
		return

	var hn: String
	var an: String
	var rn: String
	if fx.has("opponent"):
		# Selección (Parte 91, "nada distinto"): mismo aviso que un
		# partido de club, con el país en vez del club.
		var _cal_player := SaveManager.load_player()
		var player_country: String = _cal_player.country if _cal_player != null else "?"
		var opponent: String = String(fx.get("opponent", "?"))
		var is_home: bool = bool(fx.get("is_home", true))
		hn = player_country if is_home else opponent
		an = opponent if is_home else player_country
		match String(fx.get("competition", "qualifying")):
			"world_cup": rn = "Mundial"
			"national_cup": rn = "Copa continental"
			_: rn = "Eliminatoria"
	else:
		var home := WorldFactory.find_club(WorldTickEngine.world, fx.get("home_club_id", ""))
		var away := WorldFactory.find_club(WorldTickEngine.world, fx.get("away_club_id", ""))
		hn = home.short_name if home != null else "?"
		an = away.short_name if away != null else "?"
		rn = String(fx.get("round_name", ""))
		if rn == "":
			rn = "Liga J%d" % int(fx.get("matchday", 0)) if String(fx.get("competition", "")) == "league" else "Partido"
	_sim_date_lbl.text = _long_date(WorldTickEngine.current_epoch_day)
	_sim_log_line("· %s — TU PARTIDO: %s vs %s" % [rn, hn, an], Styles.AMBER)

	for c in _sim_action_row.get_children():
		c.queue_free()
	var play_btn := Button.new()
	play_btn.custom_minimum_size = Vector2(0, 52)
	play_btn.text = "Simular mi partido"
	play_btn.icon = Icons.load_icon(Icons.FAST_FORWARD)
	play_btn.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(play_btn, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	play_btn.pressed.connect(_on_sim_user_match.bind(fx))
	_sim_action_row.add_child(play_btn)
	_sim_action_row.visible = true

func _on_sim_user_match(fx: Dictionary) -> void:
	# Bug real de la auditoría: esta función es async (corre varios frames
	# reales incluso "instantánea") y el botón nunca se deshabilitaba — un
	# doble-toque podía lanzar DOS partidos concurrentes pisándose
	# MatchState.engine/fixture. simulate_button/back_button ya se
	# deshabilitan en _run_calendar_sim(); acá faltaba el mismo cuidado.
	if _sim_match_launching:
		return
	_sim_match_launching = true
	for c in _sim_action_row.get_children():
		if c is Button:
			c.disabled = true
	var player: PlayerData = SaveManager.load_player()
	if player == null:
		_sim_match_launching = false
		return
	if fx.has("opponent"):
		var season_start: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
		var prep_nat: Dictionary = NationalTeamMatchLauncher.prepare(
			WorldTickEngine.world, WorldTickEngine.world_seed, season_start, player,
			player.country, String(fx.get("opponent", "")), bool(fx.get("is_home", true)),
			float(fx.get("user_start_chance", 0.0)), "res://scenes/Calendar/Calendar.tscn", true,
			String(fx.get("competition", "qualifying")), bool(fx.get("is_knockout", false)), String(fx.get("key", "")))
		if not bool(prep_nat.get("ok", false)):
			_sim_log_line("No se pudo montar el partido — se cancela el avance.", Styles.RED)
			WorldTickEngine.season.erase("cal_sim_target")
			SaveManager.save_season(WorldTickEngine.season)
			_sim_match_launching = false
			_show_sim_close()
			return
		MatchState.apply_tie_aggregate()
		MatchState.match_result = await MatchState.engine.run_match()
		(Engine.get_main_loop() as SceneTree).change_scene_to_file("res://scenes/NationalMatchSummary/NationalMatchSummary.tscn")
		return
	var prep: Dictionary = MatchLauncher.prepare(
		WorldTickEngine.world, player, fx, "res://scenes/Calendar/Calendar.tscn", true)
	if not prep.get("ok", false):
		_sim_log_line("No se pudo montar el partido — se cancela el avance.", Styles.RED)
		WorldTickEngine.season.erase("cal_sim_target")
		SaveManager.save_season(WorldTickEngine.season)
		_sim_match_launching = false
		_show_sim_close()
		return
	MatchState.apply_tie_aggregate()
	MatchState.match_result = await MatchState.engine.run_match()
	(Engine.get_main_loop() as SceneTree).change_scene_to_file("res://scenes/MatchSummary/MatchSummary.tscn")

func _on_sim_tick(current: int, target: int) -> void:
	_sim_date_lbl.text = _long_date(current)
	var span: int = maxi(1, target - _sim_from)
	_sim_bar.value = clampf(float(current - _sim_from) / float(span) * 100.0, 0.0, 100.0)
	# league_fixture_rounds es pesado: solo lo pedimos los días que SON
	# jornada de tu liga (calendario fijo, precomputado en _sim_md_days).
	if _sim_md_days.has(current):
		_log_league_results_up_to(current)

## Vuelca al log los marcadores de las jornadas de TU liga cuyo día ya
## pasó y que todavía no habíamos mostrado. league_fixture_rounds ya da el
## resultado determinista (mundo vivo, nada se persiste); tu propio partido
## aparece con su marcador REAL en cuanto lo simulás (override de temporada).
func _log_league_results_up_to(current: int) -> void:
	var lid: int = int(WorldTickEngine.season.get("league_id", -1))
	if lid < 0:
		return
	for rnd in WorldTickEngine.league_fixture_rounds(lid):
		var ep: int = int(rnd.get("epoch_day", 0))
		if ep <= 0 or ep > current or _sim_matchday_epochs.has(ep):
			continue
		var md: int = int(rnd.get("matchday", 0))
		_sim_log_line("— Jornada %d —" % md, Styles.GRAY_TEXT)
		for m in rnd.get("matches", []):
			if not bool(m.get("played", false)):
				continue
			var h := WorldFactory.find_club(WorldTickEngine.world, m.get("home_id", ""))
			var a := WorldFactory.find_club(WorldTickEngine.world, m.get("away_id", ""))
			var hn: String = h.short_name if h != null else "?"
			var an: String = a.short_name if a != null else "?"
			var mine: bool = String(m.get("home_id", "")) == _club_id or String(m.get("away_id", "")) == _club_id
			var col: Color = Styles.GOLD if mine else Color.WHITE
			_sim_log_line("%s %d–%d %s" % [hn, int(m.get("gh", 0)), int(m.get("ga", 0)), an], col)
		_sim_matchday_epochs[ep] = true

# --- Overlay de simulación (construido en código, no se toca el .tscn) ---

func _open_sim_overlay() -> void:
	if _sim_overlay == null:
		_sim_overlay = ColorRect.new()
		(_sim_overlay as ColorRect).color = Color(0.03, 0.035, 0.05, 0.97)   # opaco: el calendario de atrás se mezclaba
		_sim_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_sim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		_sim_overlay.z_index = 50
		add_child(_sim_overlay)

		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pad.add_theme_constant_override("margin_left", 22)
		pad.add_theme_constant_override("margin_right", 22)
		pad.add_theme_constant_override("margin_top", 90)
		pad.add_theme_constant_override("margin_bottom", 40)
		_sim_overlay.add_child(pad)

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 12)
		pad.add_child(col)

		var title := Label.new()
		title.text = "Simulando el mundo…"
		title.add_theme_font_size_override("font_size", 22)
		title.add_theme_font_override("font", Styles.font_black())
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(title)

		_sim_date_lbl = Label.new()
		_sim_date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sim_date_lbl.add_theme_font_size_override("font_size", 15)
		_sim_date_lbl.add_theme_color_override("font_color", Styles.AMBER)
		col.add_child(_sim_date_lbl)

		_sim_bar = ProgressBar.new()
		_sim_bar.custom_minimum_size = Vector2(0, 14)
		_sim_bar.min_value = 0.0
		_sim_bar.max_value = 100.0
		_sim_bar.show_percentage = false
		col.add_child(_sim_bar)

		_sim_log_scroll = ScrollContainer.new()
		_sim_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_sim_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		UiScroll.make_touch(_sim_log_scroll)
		var logframe := PanelContainer.new()
		logframe.add_theme_stylebox_override("panel", Styles.card())
		logframe.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(logframe)
		var logmargin := MarginContainer.new()
		logmargin.add_theme_constant_override("margin_left", 12)
		logmargin.add_theme_constant_override("margin_right", 12)
		logmargin.add_theme_constant_override("margin_top", 10)
		logmargin.add_theme_constant_override("margin_bottom", 10)
		logframe.add_child(logmargin)
		logmargin.add_child(_sim_log_scroll)
		_sim_log = VBoxContainer.new()
		_sim_log.add_theme_constant_override("separation", 3)
		_sim_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_sim_log_scroll.add_child(_sim_log)

		_sim_action_row = VBoxContainer.new()
		_sim_action_row.add_theme_constant_override("separation", 8)
		_sim_action_row.visible = false
		col.add_child(_sim_action_row)

	_sim_overlay.visible = true
	_sim_action_row.visible = false
	for c in _sim_action_row.get_children():
		c.queue_free()

func _show_sim_close() -> void:
	for c in _sim_action_row.get_children():
		c.queue_free()
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 52)
	btn.text = "Continuar"
	Styles.styled_button(btn, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	btn.pressed.connect(_close_sim_overlay)
	_sim_action_row.add_child(btn)
	_sim_action_row.visible = true

func _close_sim_overlay() -> void:
	if _sim_overlay != null:
		_sim_overlay.visible = false
	_today_epoch_day = WorldTickEngine.current_epoch_day
	var d := CalendarUtils.epoch_day_to_date(_today_epoch_day)
	_year = int(d["year"])
	_month = int(d["month"])
	_render()
	if _land:
		_land_upcoming()
		_select_day(int(d["day"]), _today_epoch_day, _event_for_day(_today_epoch_day))

func _sim_log_clear() -> void:
	if _sim_log == null:
		return
	for c in _sim_log.get_children():
		c.queue_free()

func _sim_log_line(text: String, color: Color = Color.WHITE) -> void:
	if _sim_log == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	_sim_log.add_child(lbl)
	# mantener el scroll abajo
	await get_tree().process_frame
	if _sim_log_scroll != null:
		_sim_log_scroll.scroll_vertical = int(_sim_log_scroll.get_v_scroll_bar().max_value)

func _long_date(epoch_day: int) -> String:
	var d := CalendarUtils.epoch_day_to_date(epoch_day)
	return "%d de %s de %d" % [int(d["day"]), _MONTH_NAMES[int(d["month"])], int(d["year"])]

func _short_date(epoch_day: int) -> String:
	var d := CalendarUtils.epoch_day_to_date(epoch_day)
	return "%d %s" % [int(d["day"]), _MES_ABBR[int(d["month"])]]

var _detail_crest_row: HBoxContainer = null

func _show_detail(day: int, event: Dictionary) -> void:
	var fixture: Dictionary = event.get("fixture", {})
	if fixture.is_empty():
		detail_label.text = "%d de %s: %s" % [day, _MONTH_NAMES[_month], String(event.get("label", ""))]
		if String(event.get("callup_state", "")) == "pending":
			detail_label.text += "\nConvocatoria pendiente; el partido sólo se podrá jugar si recibes el llamado."
		_set_detail_crests(null, null)
		return
	if fixture.has("opponent"):
		# Selección (Parte 91, "nada distinto"): mismo detalle que un
		# partido de club, con la bandera del rival en vez del escudo.
		var player := SaveManager.load_player()
		var player_country: String = player.country if player != null else "?"
		var opponent: String = String(fixture.get("opponent", "?"))
		var is_home: bool = bool(fixture.get("is_home", true))
		var home_name: String = player_country if is_home else opponent
		var away_name: String = opponent if is_home else player_country
		var status_text := ""
		match String(event.get("callup_state", "")):
			"called": status_text = "CONVOCADO · puedes jugar este partido"
			"not_called": status_text = "NO CONVOCADO · el partido se simula automáticamente"
			"pending": status_text = "CONVOCATORIA PENDIENTE · si no te llaman, se simula"
		detail_label.text = "%d de %s — %s: %s vs %s\n%s" % [day, _MONTH_NAMES[_month],
			String(event.get("label", "")), home_name, away_name, status_text]
		_set_detail_crests(CountryFlags.flag_rect(home_name, 40 if _land else 22), CountryFlags.flag_rect(away_name, 40 if _land else 22))
		return
	var home := WorldFactory.find_club(WorldTickEngine.world, fixture.get("home_club_id", ""))
	var away := WorldFactory.find_club(WorldTickEngine.world, fixture.get("away_club_id", ""))
	var home_name: String = home.club_name if home != null else "?"
	var away_name: String = away.club_name if away != null else "?"
	detail_label.text = "%d de %s — %s: %s vs %s" % [day, _MONTH_NAMES[_month], String(event.get("label", "")), home_name, away_name]
	_set_detail_crests(Styles.club_crest(String(fixture.get("home_club_id", "")), 48 if _land else 22), Styles.club_crest(String(fixture.get("away_club_id", "")), 48 if _land else 22))

## Insignias (escudo o bandera, ya armadas por el llamador) flanqueando la
## línea de detalle (envuelve el Label una sola vez). null/null = sin
## partido, se ocultan.
func _set_detail_crests(home_crest, away_crest) -> void:
	if _detail_crest_row == null:
		var parent := detail_label.get_parent()
		var idx := detail_label.get_index()
		_detail_crest_row = HBoxContainer.new()
		_detail_crest_row.add_theme_constant_override("separation", 8)
		_detail_crest_row.alignment = BoxContainer.ALIGNMENT_CENTER
		parent.remove_child(detail_label)
		_detail_crest_row.add_child(detail_label)
		detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(_detail_crest_row)
		parent.move_child(_detail_crest_row, idx)
	for c in _detail_crest_row.get_children():
		if c != detail_label:
			_detail_crest_row.remove_child(c)
			c.queue_free()
	if home_crest == null and away_crest == null:
		return
	if home_crest != null:
		home_crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_detail_crest_row.add_child(home_crest)
		_detail_crest_row.move_child(home_crest, 0)
	if away_crest != null:
		away_crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_detail_crest_row.add_child(away_crest)


## HORIZONTAL: el mes a la izquierda (celdas más bajas: entran las 6
## semanas sin bajar) y a la derecha el panel del día elegido, la leyenda y
## "Simular hasta acá".
var _land := false

func _landscape_split() -> void:
	if get_viewport_rect().size.x <= get_viewport_rect().size.y:
		return
	_land = true
	var vbox := $Root/VBox as VBoxContainer
	var nav: Control = prev_button.get_parent() as Control
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	vbox.add_child(body)
	vbox.move_child(body, nav.get_index())
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 330
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	nav.reparent(left)
	$Root/VBox/WeekdayRow.reparent(left)
	$Root/VBox/DaysGrid.reparent(left)
	var detail: Control = $Root/VBox/DetailCard
	detail.reparent(right)
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var legend: Control = $Root/VBox/LegendRow
	legend.reparent(right)
	simulate_button.reparent(right)
	simulate_button.custom_minimum_size.y = 52
	back_button.visible = false   # "volver" está en la barra de arriba
	# Estilo consola: fondo del club, tarjeta grande del día elegido y la lista
	# de próximos partidos (el DetailCard de texto queda solo para vertical).
	right.custom_minimum_size.x = 360
	detail.visible = false
	_land_match = VBoxContainer.new()
	_land_match.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_land_match)
	right.move_child(_land_match, 0)
	_land_next = VBoxContainer.new()
	_land_next.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_land_next)
	right.move_child(_land_next, 1)
	var club := WorldFactory.find_club(WorldTickEngine.world, _club_id)
	var base: Color = Color(club.primary_color_hex) if club != null and club.primary_color_hex != "" else Styles.GREEN
	var bd := UiKit.club_backdrop(base)
	add_child(bd)
	move_child(bd, 0)

var _land_match: VBoxContainer = null
var _land_next: VBoxContainer = null

## Tarjeta grande del día elegido (horizontal): escudos, nombres, marcador si
## ya lo jugaste, local/visitante y estado de convocatoria.
func _land_detail(day: int, epoch_day: int, event: Dictionary) -> void:
	if _land_match == null:
		return
	for c in _land_match.get_children():
		_land_match.remove_child(c)
		c.queue_free()
	var col: Color = event.get("color", Color(0.42, 0.52, 1.0)) if not event.is_empty() else Color(0.42, 0.52, 1.0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	var wd: String = _WEEKDAY_LABELS[CalendarUtils.weekday_of_epoch_day(epoch_day)]
	var date_txt: String = "%s %d de %s de %d" % [wd, day, _MONTH_NAMES[_month].to_lower(), _year]
	if epoch_day == _today_epoch_day:
		date_txt += "  ·  HOY"
	body.add_child(UiKit.tile_text(date_txt, 13, Styles.GRAY_TEXT))
	var fx: Dictionary = event.get("fixture", {})
	var title: String = String(event.get("label", "")) if not event.is_empty() else "Día libre"
	if fx.has("home_club_id") or fx.has("opponent"):
		var hn: String
		var an: String
		var hc: Control
		var ac: Control
		var is_away: bool
		if fx.has("opponent"):
			is_away = not bool(fx.get("is_home", true))
			var opp: String = String(fx.get("opponent", "?"))
			hn = opp if is_away else _nat_country
			an = _nat_country if is_away else opp
			hc = CountryFlags.flag_rect(hn, 54)
			ac = CountryFlags.flag_rect(an, 54)
		else:
			var h_id: String = String(fx.get("home_club_id", ""))
			var a_id: String = String(fx.get("away_club_id", ""))
			is_away = a_id == _club_id
			var hcl := WorldFactory.find_club(WorldTickEngine.world, h_id)
			var acl := WorldFactory.find_club(WorldTickEngine.world, a_id)
			hn = hcl.club_name if hcl != null else "?"
			an = acl.club_name if acl != null else "?"
			hc = Styles.club_crest(h_id, 64)
			ac = Styles.club_crest(a_id, 64)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_land_side(hc, hn, not is_away))
		var mid := Label.new()
		var score: Array = _fixture_score(fx)
		mid.text = "%d - %d" % [int(score[0]), int(score[1])] if score.size() >= 2 else "VS"
		mid.add_theme_font_override("font", Styles.font_black())
		mid.add_theme_font_size_override("font_size", 30 if score.size() >= 2 else 22)
		mid.add_theme_color_override("font_color", Color.WHITE if score.size() >= 2 else Styles.GRAY_TEXT)
		mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mid)
		row.add_child(_land_side(ac, an, is_away))
		body.add_child(row)
		var chips := HBoxContainer.new()
		chips.alignment = BoxContainer.ALIGNMENT_CENTER
		chips.add_theme_constant_override("separation", 6)
		chips.add_child(UiKit.chip("VISITANTE" if is_away else "LOCAL", col))
		if score.size() >= 2:
			chips.add_child(UiKit.chip("JUGADO", Styles.GREEN))
		match String(event.get("callup_state", "")):
			"called": chips.add_child(UiKit.chip("CONVOCADO", Styles.GREEN))
			"not_called": chips.add_child(UiKit.chip("NO CONVOCADO", Styles.RED))
			"pending": chips.add_child(UiKit.chip("CONVOCATORIA PENDIENTE", _COLOR_FIFA))
		body.add_child(chips)
	else:
		var big := UiKit.tile_text(title if not event.is_empty() else "Sin partido ese día", 20, Color.WHITE, true)
		big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		big.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		body.add_child(big)
		if String(event.get("callup_state", "")) == "pending":
			body.add_child(UiKit.tile_text("Si no te llaman, se simula solo.", 13, Styles.GRAY_TEXT))
		elif epoch_day > _today_epoch_day:
			body.add_child(UiKit.tile_text("Puedes simular hasta este día.", 13, Styles.GRAY_TEXT))
	_land_match.add_child(UiKit.tile(title, col, body, Callable(), 150))

## Escudo/bandera grande con el nombre debajo (el tuyo en dorado).
func _land_side(crest: Control, name_txt: String, mine: bool) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size.x = 120
	v.add_theme_constant_override("separation", 4)
	var cc := CenterContainer.new()
	cc.add_child(crest)
	v.add_child(cc)
	var l := Label.new()
	l.text = name_txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.add_theme_font_override("font", Styles.font_semibold())
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Styles.GOLD if mine else Color.WHITE)
	v.add_child(l)
	return v

## Marcador guardado de un partido tuyo de liga o amistoso ([] si no se jugó).
func _fixture_score(fx: Dictionary) -> Array:
	var comp: String = String(fx.get("competition", ""))
	var h: String = String(fx.get("home_club_id", ""))
	var a: String = String(fx.get("away_club_id", ""))
	var key := ""
	if comp == "league":
		key = SeasonEngine.league_result_key(int(fx.get("matchday", 0)), h, a, int(fx.get("epoch_day", 0)))
	elif comp == "friendly":
		key = SeasonEngine.friendly_result_key(int(fx.get("index", 0)), h, a)
	else:
		return []
	var r = WorldTickEngine.season.get("results", {}).get(key, null)
	return r if r is Array and r.size() >= 2 else []

## Tus próximos 4 partidos desde hoy (club y selección); tocar uno salta a ese día.
func _land_upcoming() -> void:
	if _land_next == null:
		return
	for c in _land_next.get_children():
		_land_next.remove_child(c)
		c.queue_free()
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	var card := UiKit.tile("Próximos partidos", Styles.BLUE, rows, Callable(), 120)
	_land_next.add_child(card)
	var found := 0
	var d: int = _today_epoch_day
	while d < _today_epoch_day + 75 and found < 4:
		var ev: Dictionary = _event_for_day(d)
		var fx: Dictionary = ev.get("fixture", {})
		if fx.has("home_club_id") or fx.has("opponent"):
			rows.add_child(_land_next_row(d, ev))
			found += 1
		d += 1
	if found == 0:
		rows.add_child(UiKit.tile_text("No tienes partidos en las próximas semanas.", 13, Styles.GRAY_TEXT))

func _land_next_row(epoch_day: int, ev: Dictionary) -> Control:
	var fx: Dictionary = ev.get("fixture", {})
	var dt: Dictionary = CalendarUtils.epoch_day_to_date(epoch_day)
	var p := PanelContainer.new()
	var sb := Styles.card_flat(Color(1, 1, 1, 0.05), 8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	sb.border_width_left = 3
	sb.border_color = ev.get("color", Styles.GRAY_TEXT)
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	var when := UiKit.tile_text("%s %d %s" % [_WEEKDAY_LABELS[CalendarUtils.weekday_of_epoch_day(epoch_day)], int(dt["day"]), _MES_ABBR[int(dt["month"])]], 12, Styles.GRAY_TEXT)
	when.custom_minimum_size.x = 76
	when.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	row.add_child(when)
	var is_away: bool
	var crest: Control
	var rival: String
	if fx.has("opponent"):
		is_away = not bool(fx.get("is_home", true))
		rival = String(fx.get("opponent", "?"))
		crest = CountryFlags.flag_rect(rival, 22)
	else:
		is_away = String(fx.get("away_club_id", "")) == _club_id
		var rid: String = String(fx.get("home_club_id", "")) if is_away else String(fx.get("away_club_id", ""))
		var rc := WorldFactory.find_club(WorldTickEngine.world, rid)
		rival = rc.club_name if rc != null else "?"
		crest = Styles.club_crest(rid, 24)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(crest)
	var nm := UiKit.tile_text(rival, 13, Color.WHITE, true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.custom_minimum_size.x = 60
	row.add_child(nm)
	var tag := UiKit.tile_text(_short_tag(ev) + ("  V" if is_away else "  L"), 12, ev.get("color", Styles.GRAY_TEXT), true)
	tag.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	row.add_child(tag)
	UiKit._ignore_mouse(row)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	UiScroll.on_tap(p, func() -> void:
		if _sim_running:
			return
		_year = int(dt["year"])
		_month = int(dt["month"])
		_render()
		_select_day(int(dt["day"]), epoch_day, ev))
	return p
