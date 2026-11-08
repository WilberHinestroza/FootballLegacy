extends Control

## Pantalla central del loop corto/medio: desde aquí se avanza el día y
## se entra a los partidos del calendario.
## Sigue el patrón de FL: el Hub es un wrapper delgado que DELEGA en
## WorldTickEngine.advance_day(), nunca duplica lógica de tick.
##
## Cabecera con el color real del club (ClubData.primary_color_hex,
## activado en WorldFactory) y calendario semanal — pulido visual sobre
## el prototipo de Football Legacy que compartió Wilber (capturas de
## Android Studio): insignia circular, tarjeta de estado compacta en vez
## de un bloque de texto, botones tipo píldora, tarjetas de prensa reales.
## Sin arte (escudos) todavía: placeholder de texto consciente, ver nota
## de ClubCrestCache en el README.
##
## Contrato/patrocinio/agente/objetivos, que antes vivían aquí como texto,
## se movieron a la pestaña "Carrera" — el Inicio del prototipo es magro
## a propósito (overall, confianza, semana, próximo partido, prensa).

const WEEKDAY_ABBR := ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]
const MAX_PRESS_ITEMS := 3
const _COLOR_FIFA := Color("#e2822f")   # mismo naranja de selecciones que ya usa Calendar.gd

## Caché de torneos de selección para pintar la tira semanal (mismo patrón
## que Calendar.gd::_build_days_grid) — BUG REAL: el calendario semanal del
## Hub solo miraba fixtures de CLUB, así que un día de partido de
## selección quedaba en blanco acá aunque Calendar.gd ya lo mostrara bien
## desde antes (reportado de nuevo por Wilber: "tampoco salen en el
## calendario semanal los partidos de selección cuando tocan").
var _nat_country: String = ""
var _nat_qualifying: Dictionary = {}
var _nat_wc: Dictionary = {}
var _nat_ncup: Dictionary = {}


@onready var status_card: PanelContainer = $Root/Scroll/BodyMargin/BodyVBox/StatusCard
@onready var overall_circle: PanelContainer = $Root/Scroll/BodyMargin/BodyVBox/StatusCard/StatusMargin/StatusVBox/TopRow/OverallCircle
@onready var overall_label: Label = $Root/Scroll/BodyMargin/BodyVBox/StatusCard/StatusMargin/StatusVBox/TopRow/OverallCircle/OverallLabel
@onready var position_label: Label = $Root/Scroll/BodyMargin/BodyVBox/StatusCard/StatusMargin/StatusVBox/TopRow/PositionVBox/PositionLabel
@onready var season_label: Label = $Root/Scroll/BodyMargin/BodyVBox/StatusCard/StatusMargin/StatusVBox/TopRow/PositionVBox/SeasonLabel
## HFlowContainer, no HBoxContainer (bug real, Parte 87: con HBoxContainer
## los chips nunca hacían salto de línea — al abrirse la ventana de
## fichajes se sumaba el chip más largo de todos ("Ventana de fichajes
## abierta") y la fila entera se estiraba más ancha que la pantalla,
## ensanchando todo el Hub). FlowContainer envuelve a una nueva línea
## cuando no entran, sin tocar nada más de _refresh_status_card().
@onready var chips_row: HFlowContainer = $Root/Scroll/BodyMargin/BodyVBox/StatusCard/StatusMargin/StatusVBox/ChipsRow

@onready var week_strip: HBoxContainer = $Root/Scroll/BodyMargin/BodyVBox/WeekStrip
@onready var next_match_card: PanelContainer = $Root/Scroll/BodyMargin/BodyVBox/NextMatchCard
@onready var next_match_label: Label = $Root/Scroll/BodyMargin/BodyVBox/NextMatchCard/NextMatchMargin/NextMatchVBox/NextMatchLabel
@onready var cup_label: Label = $Root/Scroll/BodyMargin/BodyVBox/NextMatchCard/NextMatchMargin/NextMatchVBox/CupLabel

@onready var advance_day_button: Button = $Root/Scroll/BodyMargin/BodyVBox/AdvanceRow/AdvanceDayButton
@onready var next_match_button: Button = $Root/Scroll/BodyMargin/BodyVBox/AdvanceRow/NextMatchButton
@onready var match_actions_row: HBoxContainer = $Root/Scroll/BodyMargin/BodyVBox/MatchActionsRow

@onready var play_match_button: Button = $Root/Scroll/BodyMargin/BodyVBox/MatchActionsRow/PlayMatchButton
@onready var sim_match_button: Button = $Root/Scroll/BodyMargin/BodyVBox/MatchActionsRow/SimMatchButton
@onready var sponsor_button: Button = $Root/Scroll/BodyMargin/BodyVBox/SponsorButton
@onready var wage_offer_button: Button = $Root/Scroll/BodyMargin/BodyVBox/WageOfferButton
@onready var season_event_button: Button = $Root/Scroll/BodyMargin/BodyVBox/SeasonEventButton
@onready var press_box: VBoxContainer = $Root/Scroll/BodyMargin/BodyVBox/PressBox
@onready var standings_label: Label = $Root/Scroll/BodyMargin/BodyVBox/StandingsLabel



var _player: PlayerData = null
var _club: ClubData = null
var _world: Dictionary = {}
var _pending_fixture: Dictionary = {}   # partido de hoy detectado por el tick
var _bulk_advancing: bool = false       # true mientras Semana/Mes/Siguiente avanzan varios días de golpe

## INICIO EN BLOQUES (P2, 9-oct): tu tarjeta → avisos (patrocinios,
## renovación, eventos) → PRÓXIMO PARTIDO con sus botones → tu semana →
## prensa → tabla. Antes la semana iba antes del partido y los avisos
## quedaban perdidos entre los botones.
func _arrange_blocks() -> void:
	var box := $Root/Scroll/BodyMargin/BodyVBox as VBoxContainer
	var order: Array = ["StatusCard", "SponsorButton", "WageOfferButton", "SeasonEventButton",
		"NextMatchTitle", "NextMatchCard", "AdvanceRow", "MatchActionsRow", "WeekTitleLabel", "WeekStrip"]
	if not box.has_node("NextMatchTitle"):
		var t := Styles.section_label("PRÓXIMO PARTIDO")
		t.name = "NextMatchTitle"
		box.add_child(t)
	var idx := 0
	for n in order:
		var node := box.get_node_or_null(n)
		if node != null:
			box.move_child(node, idx)
			idx += 1
	# Títulos del .tscn con el mismo estilo de sección (barra dorada).
	for pair in [["WeekTitleLabel", "TU SEMANA"], ["PressTitleLabel", "PRENSA"]]:
		var old := box.get_node_or_null(String(pair[0])) as Label
		if old != null and old.visible:
			var t2 := Styles.section_label(String(pair[1]))
			box.add_child(t2)
			box.move_child(t2, old.get_index())
			old.visible = false

func _ready() -> void:
	WorldTickEngine.load_runtime() # idempotente; garantiza día + mundo + calendario sincronizados
	# Bug visual real encontrado en el barrido de .tscn (auditoría ronda 3):
	# la pantalla más visitada del juego nunca tenía el scroll táctil
	# arreglado (UiScroll.make_touch) — arrastrar el dedo sobre la tarjeta
	# de prensa o la tabla podía no scrollear.
	UiScroll.make_touch($Root/Scroll)
	_arrange_blocks()
	_landscape_layout()
	_landscape_fit.call_deferred()

	# ¿Se agotó el contrato? Antes de mostrar nada del Hub, resolver la
	# renovación / fichaje (Fase 8b) en su propia pantalla.
	if WorldTickEngine.season.get("awaiting_contract_decision", false):
		get_tree().change_scene_to_file("res://scenes/ContractDecision/ContractDecision.tscn")
		return
	# ¿Recién terminó una temporada? Ceremonia (resumen + Balón de Oro)
	# antes que nada más — pedido explícito.
	if not WorldTickEngine.last_season_report.is_empty():
		get_tree().change_scene_to_file("res://scenes/SeasonCeremony/SeasonCeremony.tscn")
		return

	_player = SaveManager.load_player()
	# APODO (P5): la primera vez que te lo ganás, la prensa lo anuncia.
	if _player != null and Nickname.earned(_player) and not _player.active_effects.has("nick_announced"):
		var nick: String = Nickname.for_player(_player, SaveManager.load_world_seed())
		_player.active_effects["nick_announced"] = 1
		PressGenerator.append_to_feed(_player, {
			"headline": "La afición ya lo bautizó: «%s»" % nick,
			"body": "En las tribunas ya no le dicen por su nombre. Y los cantos lo acompañan cada fin de semana.",
			"source": "TRIBUNA", "sentiment": "POSITIVE",
		}, WorldTickEngine.current_epoch_day)
		SaveManager.save_player(_player)
		Nav.toast("¡Te ganaste un apodo: «%s»!" % nick)
	# LOGROS (RPG, 10-oct): los que ya estén cumplidos se cobran acá — cubre
	# las carreras empezadas antes de que existieran y lo que se cumple fuera
	# de un partido (edad, fichajes, dinero).
	if _player != null:
		var new_ach: Array = CareerRpgEngine.sync_achievements(_player)
		if not new_ach.is_empty():
			SaveManager.save_player(_player)
			var xp_sum: int = 0
			for a in new_ach:
				xp_sum += int(a["xp"])
			Nav.toast("★ %s (+%d XP de carrera)" % [String(new_ach[0]["name"]) if new_ach.size() == 1 else "%d logros nuevos" % new_ach.size(), xp_sum])
	# Ediciones doradas ganadas con títulos (P3): se agregan solas y avisa.
	if _player != null:
		var new_gold: Array = GoldEditions.sync(_player)
		if not new_gold.is_empty():
			SaveManager.save_player(_player)
			Nav.toast("¡Edición dorada desbloqueada: %s! Mirala en la Tienda." % Avatar.label_of(String(new_gold[0])))
	_world = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	if _player != null and _player.club_id != "":
		_club = WorldFactory.find_club(_world, _player.club_id)

	# Las consecuencias de haber jugado un partido (resultado, confianza,
	# lesión, estadísticas de temporada) ya se resolvieron en MatchSummary
	# antes de volver aquí — el Hub solo lee el estado ya persistido.

	advance_day_button.pressed.connect(_on_advance_day_pressed)
	next_match_button.pressed.connect(_on_next_match_pressed)
	play_match_button.pressed.connect(_on_play_match_pressed)
	sim_match_button.pressed.connect(_on_sim_match_pressed)
	sponsor_button.pressed.connect(_on_sponsor_pressed)
	wage_offer_button.pressed.connect(_on_wage_offer_pressed)
	season_event_button.pressed.connect(_on_season_event_pressed)
	_build_dm_button()
	_build_planner_button()
	_build_academy_button()
	_build_offers_button()
	_build_fifa_button()
	_build_callup_button()
	WorldTickEngine.day_advanced.connect(_on_day_advanced)
	WorldTickEngine.user_match_today.connect(_on_user_match_today)

	_apply_button_icon(advance_day_button, Icons.PLAY)
	_apply_button_icon(next_match_button, Icons.FAST_FORWARD, 22)
	_apply_button_icon(play_match_button, Icons.FOOTBALL)
	_apply_button_icon(sim_match_button, Icons.FAST_FORWARD)
	_apply_button_icon(sponsor_button, Icons.SPONSOR)
	_apply_button_icon(wage_offer_button, Icons.WAGE_UP)
	_apply_button_icon(season_event_button, Icons.DICE)

	_apply_static_styles()

	var has_season: bool = WorldTickEngine.has_active_season()
	next_match_button.disabled = not has_season
	advance_day_button.disabled = not has_season

	# ¿Hoy es día de partido y aún no lo he jugado?
	_pending_fixture = _today_unplayed_fixture()
	_refresh_topbar()
	_refresh_status()

	# ¿Veníamos de un "Semana"/"Mes" que se cortó para simular un partido?
	# Retomar el avance hasta el objetivo guardado.
	var bulk_target: int = int(WorldTickEngine.season.get("bulk_advance_target", 0))
	if bulk_target > WorldTickEngine.current_epoch_day and _pending_fixture.is_empty():
		call_deferred("_advance_to_day", bulk_target, true)
	elif bulk_target > 0 and bulk_target <= WorldTickEngine.current_epoch_day:
		_clear_bulk_target()

## Estilos que no dependen de datos de la carrera (colores fijos de la
## paleta) — se aplican una sola vez, separados de _refresh_topbar() /
## _refresh_status() que sí dependen del club/jugador cargado.
func _apply_static_styles() -> void:
	# status_card/next_match_card/overall_circle NO se estilan acá: su color
	# depende de datos de la carrera (tier del overall, tipo de competencia
	# del próximo partido — ver _refresh_status_card()/_refresh_next_match()),
	# así que se recalculan cada vez que esos datos cambian.

	Styles.styled_button(advance_day_button, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
	Styles.styled_button(next_match_button, Styles.pill_filled(Styles.GREEN))
	Styles.styled_button(play_match_button, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	Styles.styled_button(sim_match_button, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
	# Avisos: estilo RELLENO para que salten a la vista (pedido de Wilber:
	# "que el juego te avise" cuando llega un patrocinio o una oferta).
	Styles.styled_button(sponsor_button, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	Styles.styled_button(wage_offer_button, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	Styles.styled_button(season_event_button, Styles.pill_filled(Styles.BLUE), Color.BLACK)

## Los SVG del addon se re-importan a 64x64 (ver addons/at-icons/node/*.import,
## svg/scale=4.0 — a 1.0 quedaban de 16x16, ilegibles en una pantalla de
## teléfono). Con la fuente ya nítida a esa resolución, acá solo topeamos
## el tamaño de despliegue con icon_max_width para que no reviente el alto
## del botón — icono a la izquierda del texto, para botones de una sola
## línea (distinto del ícono arriba-del-texto que usa BottomNav/CareerMenu
## para sus tarjetas de navegación, que sí tienen alto de sobra).
func _apply_button_icon(button: Button, icon_path: String, max_width: int = 28) -> void:
	button.icon = Icons.load_icon(icon_path)
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", max_width)

func _user_club_id() -> String:
	return _player.club_id if _player != null else ""

func _today_unplayed_fixture() -> Dictionary:
	# pending_user_fixture ya cubre el de hoy + un continental vencido sin
	# jugar (la fase de grupos internacional hay que jugarla siempre).
	var fx: Dictionary = WorldTickEngine.pending_user_fixture()
	if not fx.is_empty():
		return fx
	# Partido de SELECCIÓN (Parte 91: "deben ser como los demás, nada
	# distinto") — mismo tratamiento que cualquier otro fixture de hoy.
	return WorldTickEngine.pending_user_national_fixture()

# --- Cabecera: escudo (texto), club, jugador, dinero, día ---

func _on_advance_day_pressed() -> void:
	# Bug real de la auditoría: a diferencia de "Avanzar hasta tu próximo
	# partido" (_on_next_match_pressed, abajo), este botón nunca chequeaba
	# si HOY ya hay partido pendiente del usuario — se podía saltear el
	# partido propio sin avisar, resuelto solo por la IA de fondo, sin
	# acreditar caps/goles/asistencias/desarrollo reales. Mismo criterio
	# que el resto de los botones de avance masivo.
	if not _pending_fixture.is_empty():
		_warn_match_today()
		return
	_maybe_confirm("Avanzar 1 día", func():
		_clear_bulk_target()
		WorldTickEngine.advance_day())

## "Avanzar": corre los días hasta tu próximo partido y PARA ahí (no lo
## simula). Si HOY ya es día de partido y no lo jugaste, no avanza: avisa
## que tenés partido y ofrece simularlo.
func _on_next_match_pressed() -> void:
	if not _pending_fixture.is_empty():
		_warn_match_today()
		return
	_maybe_confirm("Avanzar hasta tu próximo partido", func():
		_clear_bulk_target()
		var target: Dictionary = WorldTickEngine.next_user_fixture(_user_club_id())
		if target.is_empty():
			return
		var day: int = int(target["epoch_day"])
		if day > WorldTickEngine.current_epoch_day:
			_advance_to_day(day, false))

## Diálogo cuando intentás avanzar teniendo partido hoy sin jugar.
func _warn_match_today() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "Tenés partido HOY: %s.\nJugalo o simulalo para poder seguir." % _fixture_line(_pending_fixture)
	dlg.ok_button_text = "Simular ahora"
	dlg.cancel_button_text = "Volver"
	dlg.confirmed.connect(func(): _on_sim_match_pressed())
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()

## Si Ajustes → "Confirmar antes de avanzar" está activo, pide confirmación
## antes de correr `action`. Si no, la ejecuta directo.
func _maybe_confirm(action_desc: String, action: Callable) -> void:
	if not Preferences.confirm_advance:
		action.call()
		return
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "%s?" % action_desc
	dlg.ok_button_text = "Avanzar"
	dlg.cancel_button_text = "Cancelar"
	dlg.confirmed.connect(func(): action.call())
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()

func _clear_bulk_target() -> void:
	if WorldTickEngine.season.has("bulk_advance_target"):
		WorldTickEngine.season.erase("bulk_advance_target")
		SaveManager.save_season(WorldTickEngine.season)

## Avanza hasta `n` días de golpe — delega en WorldTickEngine.advance_until
## (fuente única de avance de tiempo, ver CLAUDE.md: esta pantalla nunca
## repite el bucle de advance_day(), solo reacciona a por qué se detuvo).
## `auto_sim`: si en el camino aparece un partido tuyo, se SIMULA solo (va
## a MatchSummary) y al volver el Hub retoma el avance hasta el objetivo —
## así "Semana"/"Mes" resuelven de verdad tus partidos, no te dejan tirado.
func _advance_multiple(n: int, auto_sim: bool) -> void:
	var target: int = WorldTickEngine.current_epoch_day + n
	if auto_sim:
		WorldTickEngine.season["bulk_advance_target"] = target
		SaveManager.save_season(WorldTickEngine.season)
	_advance_to_day(target, auto_sim)

func _advance_to_day(target_epoch_day: int, auto_sim: bool = false) -> void:
	_bulk_advancing = true
	var stop_reason: String = WorldTickEngine.advance_until(target_epoch_day)
	_bulk_advancing = false
	_pending_fixture = _today_unplayed_fixture()

	if stop_reason == "contract_decision":
		_clear_bulk_target()
		get_tree().change_scene_to_file("res://scenes/ContractDecision/ContractDecision.tscn")
		return
	if stop_reason == "season_ended":
		_clear_bulk_target()
		get_tree().change_scene_to_file("res://scenes/SeasonCeremony/SeasonCeremony.tscn")
		return

	if stop_reason == "match_pending" and auto_sim and not _pending_fixture.is_empty():
		# Simular el partido del usuario y seguir: al volver de MatchSummary,
		# _ready() retoma el avance hasta bulk_advance_target.
		_launch_fixture(_pending_fixture, true)
		return

	_clear_bulk_target()
	_player = SaveManager.load_player()
	_refresh_topbar()
	_refresh_status()

func _on_day_advanced(_new_epoch_day: int) -> void:
	if _bulk_advancing:
		return # _advance_multiple hace su propio refresco al terminar
	if not WorldTickEngine.last_season_report.is_empty():
		get_tree().change_scene_to_file("res://scenes/SeasonCeremony/SeasonCeremony.tscn")
		return
	if WorldTickEngine.season.get("awaiting_contract_decision", false):
		get_tree().change_scene_to_file("res://scenes/ContractDecision/ContractDecision.tscn")
		return
	_player = SaveManager.load_player() # el tick puede haberlo cambiado (lesión, desarrollo)
	_refresh_topbar()
	_refresh_status()

func _on_user_match_today(fixture: Dictionary) -> void:
	_pending_fixture = fixture
	_refresh_status()

# --- Jugar ---

func _on_play_match_pressed() -> void:
	_try_launch(false)

## "Simular" — pedido explícito ("un botón de simular partido"): resuelve
## el partido del usuario al instante con el MISMO MatchEngine/
## DecisionResolver que el partido jugado a mano (nunca una segunda
## fórmula de balance, ver CLAUDE.md), solo que las decisiones del
## usuario se autorresuelven y no hay pausas de ritmo en tiempo real —
## ver MatchEngine.instant_mode. Va derecho a MatchSummary, sin pasar por
## PreMatch/Match (no hay nada que animar).
func _on_sim_match_pressed() -> void:
	_try_launch(true)

func _try_launch(instant: bool) -> void:
	if _player != null and _player.injury_days_remaining > 0:
		return # lesionado: los botones ya están deshabilitados, esto es un cinturón extra
	# Bug real de la auditoría: ni "Jugar" ni "Simular" se deshabilitaban al
	# tocarlos, y "Simular" cede frames reales (instant_mode igual espera
	# medio de partido, decisiones, etc.) — un doble-toque rápido podía
	# lanzar DOS partidos concurrentes pisando MatchState.engine/fixture a
	# mitad de la primera corrutina. Deshabilitar acá, ANTES de armar nada.
	play_match_button.disabled = true
	sim_match_button.disabled = true

	var fixture: Dictionary = _pending_fixture
	if fixture.is_empty():
		# comodidad: si no hay partido hoy, deja jugar/simular el siguiente (liga o copa)
		fixture = WorldTickEngine.next_user_fixture(_user_club_id())

	if fixture.is_empty() or _player == null:
		# No debería pasar en el flujo real (Start.gd siempre entra al Hub
		# con carrera activa) — antes esto caía a DebugDataFactory (un
		# partido de relleno para probar el Hub sin carrera desde el
		# editor), quitado por no ser código real de juego (candidato a
		# borrar de CLAUDE.md, cerca del release).
		play_match_button.disabled = false
		sim_match_button.disabled = false
		return

	await _launch_fixture(fixture, instant)
	# Si _launch_fixture volvió sin cambiar de escena (prep falló), hay que
	# reactivar los botones — si cambió de escena, esta instancia ya no
	# importa (Hub.tscn se está liberando).
	if is_inside_tree():
		play_match_button.disabled = false
		sim_match_button.disabled = false

func _launch_fixture(fixture: Dictionary, instant: bool = false) -> void:
	# Selección (Parte 91, "nada distinto"): mismo botón Jugar/Simular que
	# un fixture de club, pero el armado de los dos MatchTeam es otro
	# launcher (NationalTeamMatchLauncher, el mismo que ya usaba
	# Selections.gd — no se duplica esa lógica acá).
	if fixture.has("opponent"):
		var season_start: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
		var prep_nat: Dictionary = NationalTeamMatchLauncher.prepare(
			_world, WorldTickEngine.world_seed, season_start, _player,
			_player.country, String(fixture.get("opponent", "")), bool(fixture.get("is_home", true)),
			float(fixture.get("user_start_chance", 0.0)), "res://scenes/Hub/Hub.tscn", instant,
			String(fixture.get("competition", "qualifying")), bool(fixture.get("is_knockout", false)), String(fixture.get("key", "")))
		if not bool(prep_nat.get("ok", false)):
			return
		if instant:
			MatchState.apply_tie_aggregate()
			var result_nat: Dictionary = await MatchState.engine.run_match()
			MatchState.match_result = result_nat
			(Engine.get_main_loop() as SceneTree).change_scene_to_file("res://scenes/NationalMatchSummary/NationalMatchSummary.tscn")
			return
		(Engine.get_main_loop() as SceneTree).change_scene_to_file("res://scenes/PreMatch/PreMatch.tscn")
		return

	# El armado de los dos MatchTeam vive en MatchLauncher (lo comparte el
	# Calendario, que también resuelve tus partidos al simular hasta una
	# fecha) — no duplicar acá.
	var prep: Dictionary = MatchLauncher.prepare(_world, _player, fixture, "res://scenes/Hub/Hub.tscn", instant)
	if not prep.get("ok", false):
		return

	if instant:
		MatchState.apply_tie_aggregate()
		var result: Dictionary = await MatchState.engine.run_match()
		MatchState.match_result = result
		# Si saliste del Inicio mientras se simulaba, igual ir al resumen.
		(Engine.get_main_loop() as SceneTree).change_scene_to_file("res://scenes/MatchSummary/MatchSummary.tscn")
		return

	(Engine.get_main_loop() as SceneTree).change_scene_to_file("res://scenes/PreMatch/PreMatch.tscn")

## Aviso de "tenés mensajes nuevos" — armado en código (no tocar el .tscn),
## se cuelga arriba de la tira semanal. Solo aparece si hay una invitación
## de DM sin ver esta semana (SocialEngine).
var _dm_button: Button = null

func _build_dm_button() -> void:
	_dm_button = Button.new()
	_dm_button.custom_minimum_size = Vector2(0, 52)
	_dm_button.visible = false
	_dm_button.text = "Tenés mensajes nuevos"
	_dm_button.icon = Icons.load_icon(Icons.SOCIAL)
	_dm_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(_dm_button, Styles.pill_outlined(Styles.PURPLE), Styles.PURPLE)
	_dm_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Social/Social.tscn"))
	season_event_button.add_sibling(_dm_button)

func _refresh_dm_button() -> void:
	if _dm_button == null or _player == null:
		return
	var pending: bool = not SocialEngine.dm_seen_this_week(WorldTickEngine.season, WorldTickEngine.current_epoch_day) \
		and SocialEngine.has_pending_invite(_player, WorldTickEngine.world, WorldTickEngine.world_seed, WorldTickEngine.current_epoch_day, WorldTickEngine.season)
	# Polémica en redes sin responder (ControversyEngine): manda sobre los mensajes.
	var hot: bool = not ControversyEngine.active(WorldTickEngine.season).is_empty()
	_dm_button.text = "Eres tendencia: responde en redes" if hot else "Tenés mensajes nuevos"
	_dm_button.visible = pending or hot

## Aviso "tenés ofertas de otros clubes" (TransferOfferEngine.inbox) — antes
## solo se veían entrando a Fichajes → Mis ofertas, sin que el juego avisara.
var _offers_button: Button = null

func _build_offers_button() -> void:
	_offers_button = Button.new()
	_offers_button.custom_minimum_size = Vector2(0, 52)
	_offers_button.visible = false
	_offers_button.icon = Icons.load_icon(Icons.TRANSFER)
	_offers_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(_offers_button, Styles.pill_filled(Styles.BLUE), Color.BLACK)
	# Transfers.tscn ya abre en la pestaña "Mis ofertas" por defecto.
	_offers_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/Transfers/Transfers.tscn"))
	season_event_button.add_sibling(_offers_button)

func _refresh_offers_button() -> void:
	if _offers_button == null or _player == null:
		return
	var inbox: Array = TransferOfferEngine.inbox(WorldTickEngine.season)
	var pre: bool = not PreContractEngine.offer(WorldTickEngine.season).is_empty()
	_offers_button.visible = not inbox.is_empty() or pre
	if pre and inbox.is_empty():
		_offers_button.text = "🔔  Te ofrecen un precontrato"
	elif _offers_button.visible:
		var n: int = inbox.size()
		_offers_button.text = "🔔  %d oferta%s de otros clubes" % [n, "" if n == 1 else "s"]

## CANTERA (AcademyEngine): botón con tu juvenil (abre AcademyPanel) mientras
## sigas en la cantera.
var _academy_button: Button = null

func _build_academy_button() -> void:
	_academy_button = Button.new()
	_academy_button.custom_minimum_size = Vector2(0, 52)
	_academy_button.visible = false
	_academy_button.icon = Icons.load_icon(Icons.CLUB)
	_academy_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(_academy_button, Styles.pill_outlined(Styles.GREEN), Styles.GREEN)
	_academy_button.pressed.connect(func(): AcademyPanel.open(self, _player))
	season_event_button.add_sibling(_academy_button)

func _refresh_academy_button() -> void:
	if _academy_button == null or _player == null:
		return
	_academy_button.visible = AcademyEngine.in_academy(_player)
	if _academy_button.visible:
		var d: Dictionary = AcademyEngine.data(_player)
		_academy_button.text = "Cantera · nota %.1f" % AcademyEngine.avg_rating(_player) if int(d.get("matches", 0)) > 0 else "Tu cantera"

## ¿Hoy juega el primer equipo sin ti porque estás en la cantera y no te convocaron?
func _academy_out_today() -> bool:
	return _player != null and not _pending_fixture.is_empty() \
		and AcademyEngine.sits_out(_player, _pending_fixture, WorldTickEngine.world_seed)

## Botón "Planificar la semana" (PlannerEngine) — solo aparece si hoy NO
## hay partido del usuario y todavía no planificó esta semana.
var _planner_button: Button = null

func _build_planner_button() -> void:
	_planner_button = Button.new()
	_planner_button.custom_minimum_size = Vector2(0, 52)
	_planner_button.visible = false
	_planner_button.text = "Planificar la semana"
	_planner_button.icon = Icons.load_icon(Icons.CALENDAR)
	_planner_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(_planner_button, Styles.pill_outlined(Styles.GREEN), Styles.GREEN)
	_planner_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Planner/Planner.tscn"))
	season_event_button.add_sibling(_planner_button)

func _refresh_planner_button() -> void:
	if _planner_button == null or _player == null:
		return
	var day: int = WorldTickEngine.current_epoch_day
	var has_match_today: bool = not WorldTickEngine.user_fixture_on(day, _user_club_id()).is_empty()
	# Aparece si hay AL MENOS 2 días libres hasta el próximo partido.
	var nxt: Dictionary = WorldTickEngine.next_user_fixture(_user_club_id())
	var free_days: int = (int(nxt.get("epoch_day", day)) - day) if not nxt.is_empty() else 0
	_planner_button.visible = not has_match_today and free_days >= 2
	_land_adv_cols()

## Aviso "se viene una fecha FIFA" — antes solo se veía el día que llegaba
## (Calendar.gd resaltándola, Parte 82); acá avisa CON anticipación (≤6
## días) para que no agarre de sorpresa en medio de una racha de partidos
## de club. Puramente informativo (no hay nada que decidir, a diferencia
## de sponsor/wage/season_event) — tocarlo lleva al Calendario, donde ya
## se ve resaltada.
var _fifa_button: Button = null

func _build_fifa_button() -> void:
	_fifa_button = Button.new()
	_fifa_button.custom_minimum_size = Vector2(0, 52)
	_fifa_button.visible = false
	_fifa_button.icon = Icons.load_icon(Icons.CALENDAR)
	_fifa_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(_fifa_button, Styles.pill_outlined(Color("#4c6fb1")), Color("#4c6fb1"))
	_fifa_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Calendar/Calendar.tscn"))
	season_event_button.add_sibling(_fifa_button)

## Horizontal: la fila de Planificar / FIFA / Pasar el día / Avanzar usa
## tantas columnas como botones visibles (una columna vacía robaba ancho).
func _land_adv_cols() -> void:
	if not _is_land() or next_match_button == null:
		return
	var adv := next_match_button.get_parent() as GridContainer
	if adv == null:
		return
	var n: int = 0
	for b in adv.get_children():
		if b is Control and (b as Control).visible:
			n += 1
	adv.columns = maxi(n, 1)

func _refresh_fifa_button() -> void:
	if _fifa_button == null or _player == null:
		return
	var days: int = WorldTickEngine.days_until_next_international_window()
	_fifa_button.visible = days >= 0
	if _fifa_button.visible:
		_fifa_button.text = "FIFA mañana" if days == 1 else "FIFA en %d días" % days
		if not _is_land():
			_fifa_button.text = "Fecha " + _fifa_button.text
	_land_adv_cols()

## Aviso de convocatoria a la selección (pedido de Wilber: "que salga un
## popup con la invitación") — botón que aparece SOLO mientras
## user_callup_status.seen sea false (WorldTickEngine._tick_international_window
## lo deja así al resolver la convocatoria de cada fecha FIFA) y lleva a
## NationalCallUp.tscn, que lo marca visto al cerrarse. Mismo patrón que
## sponsor/wage_offer: estado persistente, no un popup efímero.
var _callup_button: Button = null

func _build_callup_button() -> void:
	_callup_button = Button.new()
	_callup_button.custom_minimum_size = Vector2(0, 52)
	_callup_button.visible = false
	_callup_button.icon = Icons.load_icon(Icons.NATIONAL_TEAM)
	_callup_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(_callup_button, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	_callup_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/NationalCallUp/NationalCallUp.tscn"))
	season_event_button.add_sibling(_callup_button)

func _refresh_callup_button() -> void:
	if _callup_button == null or _player == null:
		return
	var callup: Dictionary = SaveManager.load_international().get("user_callup_status", {})
	_callup_button.visible = not callup.is_empty() and not bool(callup.get("seen", true))
	if _callup_button.visible:
		_callup_button.text = "🔔  ¡Te convocaron a la selección!" if bool(callup.get("called_up", false)) else "🔔  Noticias de la selección"

## Parte 91b: la primera versión de este pedido agregaba acá un botón
## SEPARADO ("🔔 Partido de selección") que lanzaba el partido con su
## propio camino, distinto del de club. Wilber lo rechazó explícitamente:
## "los partidos de selección deben ser como los demás, salir en el
## calendario y jugarse como se juegan los demás, nada distinto". Se
## sacó ese botón — ahora un partido de selección hoy usa EXACTAMENTE el
## mismo `_pending_fixture`/`match_actions_row` (Jugar/Simular) que un
## partido de club (ver _tick_fixtures() en WorldTickEngine y
## _today_unplayed_fixture()/_launch_fixture() más abajo, que distinguen
## el tipo de fixture solo para elegir el launcher correcto).

# --- Estado / calendario semanal ---


func _refresh_topbar() -> void:
	if has_node("TopBar"):
		$TopBar.refresh()

func _refresh_status() -> void:
	_maybe_present_signing()
	_refresh_boot_offer_button()
	_refresh_status_card()
	sponsor_button.visible = _player != null and not _player.pending_sponsor_offer.is_empty()
	if sponsor_button.visible:
		var so: Dictionary = _player.pending_sponsor_offer
		var wk: int = int(so.get("weekly_income", 0))
		sponsor_button.text = "🔔  Patrocinio: %s/semana" % CurrencyFormat.format(wk) if wk > 0 else "🔔  Oferta de patrocinio"
	wage_offer_button.visible = _player != null and not _player.pending_wage_offer.is_empty()
	if wage_offer_button.visible:
		var wo: Dictionary = _player.pending_wage_offer
		var nw: int = int(wo.get("new_wage", 0))
		wage_offer_button.text = "🔔  Tu club te ofrece renovar: %s" % CurrencyFormat.format(nw) if nw > 0 else "🔔  Tu club quiere renovarte"
	season_event_button.visible = _player != null and not _player.pending_season_event.is_empty()
	_refresh_dm_button()
	_refresh_offers_button()
	_refresh_planner_button()
	_refresh_academy_button()
	_refresh_fifa_button()
	_refresh_callup_button()
	_refresh_week_strip()
	_refresh_weekly_goals()
	_refresh_next_match()
	_refresh_cup_label()
	_refresh_press()
	_refresh_standings()
	_refresh_mosaic()

## Tarjeta compacta (overall + posición/temporada + chips) que reemplaza
## el bloque de texto largo que tenía el Hub antes — contrato, patrocinio,
## agente y objetivos se movieron a la pestaña Carrera.
## Nivel de carrera + barra de XP + forma + puntos de habilidad (v33).
func _build_level_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "LevelRow"
	row.add_theme_constant_override("separation", 8)
	var lv := Label.new()
	lv.text = "NV %d" % _player.level
	lv.add_theme_font_override("font", Styles.font_black())
	lv.add_theme_font_size_override("font_size", 13)
	lv.add_theme_color_override("font_color", Styles.BLUE.lightened(0.3))
	lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lv)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = float(ProgressionEngine.xp_to_next(_player.level))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Styles.BLUE
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	row.add_child(bar)
	bar.value = 0.0
	bar.create_tween().tween_property(bar, "value", float(_player.career_xp), 0.7).set_trans(Tween.TRANS_QUAD)
	var f: int = ProgressionEngine.form(_player)
	var fl := Label.new()
	fl.text = "%s %s" % [ProgressionEngine.FORM_ARROWS[f], ProgressionEngine.FORM_NAMES[f]]
	fl.add_theme_font_size_override("font_size", 12)
	fl.add_theme_color_override("font_color", ProgressionEngine.form_color(f))
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(fl)
	if _player.skill_points > 0:
		var sp := Button.new()
		sp.text = "+%d" % _player.skill_points
		sp.tooltip_text = "Puntos de habilidad"
		sp.focus_mode = Control.FOCUS_NONE
		sp.custom_minimum_size = Vector2(46, 30)
		Styles.styled_button(sp, Styles.pill_filled(Styles.GOLD), Color.BLACK)
		sp.pressed.connect(func():
			SkillsPanel.open(self).closed.connect(_refresh_status))
		row.add_child(sp)
		sp.ready.connect(func(): Juice.pulse(sp, 1.08))
	return row

func _refresh_status_card() -> void:
	overall_label.text = str(_player.overall) if _player != null else "?"
	if _player == null:
		return
	var year := WorldTickEngine.get_season_start_year()
	position_label.text = Positions.label_of(_player.detailed_position)
	season_label.text = "Temporada %d/%d" % [year, year + 1]

	var tier: Color = PlayerCard.tier_color(_player.overall)
	status_card.add_theme_stylebox_override("panel", Styles.card_accent(tier))

	var sm := status_card.get_node("StatusMargin/StatusVBox") as VBoxContainer
	# El TopRow del .tscn (círculo + pos/temporada) se reemplaza por un
	# encabezado "RPG": retrato del avatar + nombre + badge de media +
	# barra de energía (pedido de Wilber).
	var top_row := sm.get_node_or_null("TopRow")
	if top_row: (top_row as Control).visible = false
	var old_h := sm.get_node_or_null("RpgHeader")
	if old_h: old_h.free()
	var old_e := sm.get_node_or_null("EnergyRow")
	if old_e: old_e.free()
	var old_l := sm.get_node_or_null("LevelRow")
	if old_l: old_l.free()

	var header := HBoxContainer.new()
	header.name = "RpgHeader"
	header.add_theme_constant_override("separation", 12)
	# Carta "Ultimate" (10-oct, pedido de Wilber: mejorar la carta del Hub)
	# en vez del retrato chico + disco de media: la media, el puesto, la
	# bandera, el escudo y las 6 stats ya viven en la carta.
	var ucard := UltimateCard.build(_player, _club, 118)
	ucard.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(ucard)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_theme_constant_override("separation", 1)
	var nm := Label.new()
	nm.text = _player.player_name
	nm.add_theme_font_override("font", Styles.font_black())
	nm.add_theme_font_size_override("font_size", 16)
	mid.add_child(nm)
	var pos_txt: String = Positions.label_of(_player.detailed_position)
	if _player.secondary_detailed_position != "":
		pos_txt += "  /  " + Positions.label_of(_player.secondary_detailed_position)
	var pl := Label.new()
	pl.text = "%s · %d años" % [pos_txt, _player.age]
	pl.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	pl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.88))
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(pl)
	var sl := Label.new()
	sl.text = "Temporada %d/%d" % [year, year + 1]
	sl.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	sl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	mid.add_child(sl)
	# Línea de stats de la temporada: goles + asistencias (pedido de Wilber).
	var statline := Label.new()
	statline.text = "⚽ %d goles   ·   🅰 %d asistencias" % [_player.season_goals, _player.season_key_passes]
	statline.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	statline.add_theme_color_override("font_color", Color(0.9, 0.85, 0.55))
	mid.add_child(statline)
	header.add_child(mid)

	if _player.potential > _player.overall:
		var potl := Label.new()
		potl.text = "Potencial %d" % _player.potential
		potl.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		potl.add_theme_color_override("font_color", Styles.GOLD)
		mid.add_child(potl)
	sm.add_child(header)
	sm.move_child(header, 0)

	sm.add_child(_build_energy_row())
	sm.move_child(sm.get_node("EnergyRow"), 1)
	sm.add_child(_build_level_row())
	sm.move_child(sm.get_node("LevelRow"), 2)

	for child in chips_row.get_children():
		child.queue_free()
	if _player.club_id != "":
		var coach := WorldFactory.find_coach(_world, _player.club_id)
		if coach != null:
			chips_row.add_child(_make_chip("Confianza DT: %d%%" % _player.coach_trust))
	chips_row.add_child(_make_chip("Titular: %d" % _player.season_appearances))
	# Amarillas acumuladas en la temporada (con DisciplineEngine.YELLOWS_FOR_SUSPENSION, sanción)
	var ycount: int = int(WorldTickEngine.season.get("user_yellow_count", 0)) % DisciplineEngine.YELLOWS_FOR_SUSPENSION
	if ycount > 0:
		chips_row.add_child(_make_chip("Amarillas: %d/%d" % [ycount, DisciplineEngine.YELLOWS_FOR_SUSPENSION]))
	var fs = WorldTickEngine.season.get("fan_sentiment", null)
	if fs != null:
		chips_row.add_child(_make_chip("Afición: %s" % _fan_mood_text(int(fs))))
	if WorldTickEngine.is_transfer_window_open():
		chips_row.add_child(_make_chip("Ventana de fichajes abierta"))

## Barra de energía / estamina en la tarjeta del Hub + ritmo de
## recuperación por día, para decidir entrenar vs descansar (pedido de
## Wilber). La energía SOLO baja jugando partidos.
func _build_energy_row() -> VBoxContainer:
	var erow := VBoxContainer.new()
	erow.name = "EnergyRow"
	erow.add_theme_constant_override("separation", 2)
	var energy: float = clampf(100.0 - _player.fatigue_physical, 0.0, 100.0)
	var ecol: Color = Styles.GREEN if energy >= 66.0 else (Styles.GOLD if energy >= 40.0 else Styles.RED)

	var etop := HBoxContainer.new()
	var ecap := Label.new()
	ecap.text = "⚡ ENERGÍA"
	ecap.add_theme_font_size_override("font_size", 10)
	ecap.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	ecap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var eval := Label.new()
	eval.text = "%d%%" % int(round(energy))
	eval.add_theme_font_size_override("font_size", 10)
	eval.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	eval.add_theme_color_override("font_color", ecol)
	etop.add_child(ecap)
	etop.add_child(eval)
	erow.add_child(etop)

	var etrack := ColorRect.new()
	etrack.color = Color(1, 1, 1, 0.08)
	etrack.custom_minimum_size = Vector2(0, 8)
	etrack.clip_contents = true
	var efill := ColorRect.new()
	efill.color = ecol
	efill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	efill.anchor_bottom = 1.0
	efill.anchor_right = clampf(energy / 100.0, 0.0, 1.0)
	etrack.add_child(efill)
	erow.add_child(etrack)

	var rate: int = int(round(WorldTickEngine.daily_energy_recovery(_player)))
	var hint := Label.new()
	var nf: Dictionary = WorldTickEngine.next_user_fixture(_user_club_id())
	var dleft: int = (int(nf["epoch_day"]) - WorldTickEngine.current_epoch_day) if (not nf.is_empty() and nf.has("epoch_day")) else -1
	if _player.fatigue_physical <= 0.5:
		hint.text = "Energía al máximo — solo baja jugando."
	elif dleft > 0:
		var proj: int = int(round(clampf(energy + float(rate * dleft), 0.0, 100.0)))
		hint.text = "+%d/día descansando · en %dd llegarías ~%d%%" % [rate, dleft, proj]
	else:
		hint.text = "+%d/día descansando · entrenar no la mueve" % rate
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	erow.add_child(hint)
	return erow

func _fan_mood_text(fs: int) -> String:
	if fs >= 80: return "▲ en éxtasis"
	if fs >= 65: return "▲ contenta"
	if fs >= 45: return "— tranquila"
	if fs >= 30: return "▼ inquieta"
	return "▼ crispada"

func _make_chip(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.chip())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	margin.add_child(lbl)
	panel.add_child(margin)
	return panel

## OBJETIVOS DE LA SEMANA (P5, 10-oct): 3 metas chicas con premio.
var _goals_box: VBoxContainer = null
func _refresh_weekly_goals() -> void:
	if _player == null or WorldTickEngine.season.is_empty():
		return
	var box := week_strip.get_parent() as VBoxContainer
	if _goals_box == null:
		_goals_box = VBoxContainer.new()
		_goals_box.add_theme_constant_override("separation", 6)
		box.add_child(_goals_box)
		box.move_child(_goals_box, week_strip.get_index() + 1)
	for c in _goals_box.get_children():
		c.queue_free()
	var day: int = WorldTickEngine.current_epoch_day
	var ws: int = SaveManager.load_world_seed()
	var goals: Array = WeeklyGoalsEngine.current(WorldTickEngine.season, day, ws)
	_goals_box.add_child(Styles.section_label("OBJETIVOS DE LA SEMANA"))
	for g in goals:
		var card := PanelContainer.new()
		var done: bool = WeeklyGoalsEngine.is_done(g)
		var claimed: bool = bool(g.get("claimed", false))
		card.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GREEN if done else Styles.GRAY_TEXT))
		var m := MarginContainer.new()
		for side in ["left", "right"]:
			m.add_theme_constant_override("margin_" + side, 12)
		for side in ["top", "bottom"]:
			m.add_theme_constant_override("margin_" + side, 8)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var d := Label.new()
		d.text = ("✔ " if claimed else "") + String(g["desc"])
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 13)
		col.add_child(d)
		var p := Label.new()
		p.text = "%d / %d  ·  Premio: %s" % [int(g["progress"]), int(g["target"]), WeeklyGoalsEngine.reward_text(g["reward"])]
		p.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		p.add_theme_color_override("font_color", Styles.GOLD if done else Styles.GRAY_TEXT)
		col.add_child(p)
		row.add_child(col)
		if done and not claimed:
			var b := Button.new()
			b.text = "Cobrar"
			b.custom_minimum_size = Vector2(86, 38)
			b.focus_mode = Control.FOCUS_NONE
			Styles.styled_button(b, Styles.pill_filled(Styles.GOLD), Color.BLACK)
			var gid: String = String(g["id"])
			b.pressed.connect(func():
				if WeeklyGoalsEngine.claim(WorldTickEngine.season, _player, day, ws, gid):
					SaveManager.save_player(_player)
					SaveManager.save_season(WorldTickEngine.season)
					Audio.play("celebrate")
					Juice.float_text(self, "¡Premio!", b.global_position - global_position, Styles.GOLD, 22)
					for tb in get_tree().get_nodes_in_group("topbar"):
						if tb.has_method("refresh"):
							tb.call("refresh")
					_refresh_status())
			row.add_child(b)
			b.ready.connect(func(): Juice.pulse(b, 1.06))
		m.add_child(row)
		card.add_child(m)
		_goals_box.add_child(card)

func _refresh_week_strip() -> void:
	for child in week_strip.get_children():
		child.queue_free()
	if _player == null:
		return

	_nat_country = _player.country if _player != null else ""
	_nat_qualifying = {}
	_nat_wc = {}
	_nat_ncup = {}
	if _nat_country != "":
		var nat_confederation: String = Confederations.confederation_of(_nat_country)
		if nat_confederation != "":
			_nat_qualifying = WorldTickEngine.national_qualifying_for(nat_confederation)
			_nat_wc = WorldTickEngine.world_cup_this_cycle()
			_nat_ncup = WorldTickEngine.national_cup_for(nat_confederation)

	# Semana fija de domingo a sábado (7-nov, Wilber: "que solo cambie de semana al
	# pasar a domingo"). Antes era hoy + 6 días y la tira se corría cada día.
	var today: int = WorldTickEngine.current_epoch_day
	var wd: int = int(CalendarUtils.epoch_day_to_date(today).get("weekday", 0)) % 7
	var sunday: int = today - wd
	for offset in range(7):
		var day: int = sunday + offset
		var cell := _make_day_cell(day, day == today)
		if day < today:
			cell.modulate = Color(1, 1, 1, 0.45) # ya pasó
		week_strip.add_child(cell)

## Partido de selección de `day` (Mundial -> copa continental ->
## eliminatoria, mismo orden de prioridad que WorldTickEngine.
## pending_user_national_fixture()/Calendar.gd) — {} si no hay o si el país
## del jugador no tiene selección. Para HOY usa pending_user_national_
## fixture() (respeta si te convocaron o no); para el resto de la semana
## muestra el partido PROGRAMADO igual, sin depender de la convocatoria
## (mundo vivo — recién se sabe si te llaman el día que abre la ventana).
func _national_fixture_on(day: int) -> Dictionary:
	if _nat_country == "":
		return {}
	if day == WorldTickEngine.current_epoch_day:
		return WorldTickEngine.pending_user_national_fixture()
	var intl: Dictionary = SaveManager.load_international()
	if not _nat_wc.is_empty():
		var wc_fx: Dictionary = WorldCupEngine.next_user_fixture(_nat_wc, _nat_country, day, intl.get("wc_results", {}))
		if not wc_fx.is_empty():
			return wc_fx
	if not _nat_ncup.is_empty():
		var ncup_fx: Dictionary = NationalCupEngine.next_user_fixture(_nat_ncup, _nat_country, day, intl.get("natcup_results", {}))
		if not ncup_fx.is_empty():
			return ncup_fx
	if WorldTickEngine.is_day_in_international_window(day) and not _nat_qualifying.is_empty():
		var q_fx: Dictionary = QualifyingEngine.user_fixture_today(_nat_qualifying, _nat_country, day)
		if not q_fx.is_empty():
			return q_fx
	return {}

func _make_day_cell(day: int, is_today: bool) -> PanelContainer:
	var date: Dictionary = CalendarUtils.epoch_day_to_date(day)
	var weekday: int = int(date.get("weekday", 0)) % WEEKDAY_ABBR.size()
	var fx: Dictionary = WorldTickEngine.user_fixture_on(day, _user_club_id())
	# user_fixture_on solo da "el próximo" continental — pedir aparte el
	# resto de la fase de grupos/eliminatoria para pintarlos en la tira.
	if fx.is_empty():
		fx = WorldTickEngine.user_continental_fixture_on(day, _user_club_id())
	# Partido de SELECCIÓN (Mundial/copa continental/eliminatoria) — un club
	# no juega club Y selección el mismo día (el calendario los excluye
	# entre sí), así que esto solo entra cuando `fx` de club quedó vacío.
	var is_national: bool = false
	if fx.is_empty():
		var nat_fx: Dictionary = _national_fixture_on(day)
		if not nat_fx.is_empty():
			fx = nat_fx
			is_national = true

	# Día de mercado abierto (mismo criterio y color que la pantalla de
	# Calendario — _COLOR_MARKET = Styles.PURPLE). "cierre" = último día de
	# la ventana, se resalta más fuerte (pedido de Wilber: "que se muestre
	# el color cuando se está en cierre de fichajes").
	var window_day: bool = fx.is_empty() and WorldTickEngine.is_day_in_transfer_window(day)
	var window_deadline: bool = window_day and not WorldTickEngine.is_day_in_transfer_window(day + 1)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(40, 58)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var comp_ws: String = String(fx.get("competition", ""))
	var bg_color: Color
	if is_today:
		bg_color = Styles.GREEN
	elif not fx.is_empty():
		if is_national:
			bg_color = _COLOR_FIFA
		elif comp_ws == "continental":
			bg_color = Color("#8f9199")   # plateado (torneo internacional)
		elif comp_ws == "cup":
			bg_color = Color(0.55, 0.16, 0.42)
		else:
			bg_color = Color(0.16, 0.32, 0.58)
	elif window_deadline:
		bg_color = Styles.PURPLE
	elif window_day:
		bg_color = Styles.PURPLE.darkened(0.34)
	else:
		bg_color = Styles.CARD_DARK_2
	panel.add_theme_stylebox_override("panel", Styles.card(bg_color, 10))

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	var weekday_lbl := Label.new()
	weekday_lbl.text = WEEKDAY_ABBR[weekday]
	weekday_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var day_lbl := Label.new()
	day_lbl.text = str(int(date.get("day", 0)))
	day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_lbl.add_theme_font_size_override("font_size", 17)
	weekday_lbl.add_theme_font_size_override("font_size", 11)
	vb.add_child(weekday_lbl)
	vb.add_child(day_lbl)
	if not fx.is_empty() and _is_land():
		_land_match_cell(panel, vb, fx, day, is_national, bg_color)
	elif not fx.is_empty():
		var mark := Label.new()
		mark.text = "🏆" if comp_ws in ["cup", "supercup", "continental"] else "⚽"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(mark)
	elif window_day:
		var mark := Label.new()
		mark.text = "⏳" if window_deadline else "💱"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size", 12)
		vb.add_child(mark)
	panel.add_child(vb)
	return panel

func _refresh_next_match() -> void:
	_land_refresh_match_day.call_deferred()
	# "Jugar" y "Simular" solo se ven el DÍA del partido (pedido de Wilber:
	# ocultos hasta que estemos en el día de partido).
	match_actions_row.visible = not _pending_fixture.is_empty() and not _is_land()
	# 7-nov: en vertical, el día de partido "Pasar el día"/"Avanzar" solo avisaban
	# de que había partido (4 botones compitiendo). Se ocultan hasta jugarlo, como en
	# horizontal (ahí lo hace _land_refresh_match_day).
	if not _is_land():
		(next_match_button.get_parent() as Control).visible = _pending_fixture.is_empty()

	var susp: int = int(WorldTickEngine.season.get("suspended_matches", 0))
	# La sanción es de CLUB (tarjetas acumuladas con el club) — no aplica a
	# un partido de selección (Parte 91): una tarjeta en liga no te saca
	# de la convocatoria nacional, ni al revés.
	var susp_today: bool = susp > 0 and not _pending_fixture.is_empty() and not _pending_fixture.has("opponent") and String(_pending_fixture.get("competition", "")) != "friendly"
	if _player != null and _player.injury_days_remaining > 0:
		play_match_button.disabled = true
		sim_match_button.disabled = true
		play_match_button.text = "Lesionado (%d días)" % _player.injury_days_remaining
	elif susp_today:
		play_match_button.disabled = true
		play_match_button.text = "Cumplís sanción"
		sim_match_button.disabled = false
		sim_match_button.text = "Ver el partido (jugás desde afuera)"
	elif _academy_out_today():
		play_match_button.disabled = true
		play_match_button.text = "En la cantera: no convocado"
		sim_match_button.disabled = false
		sim_match_button.text = "Ver el partido del primer equipo"
	else:
		play_match_button.disabled = false
		sim_match_button.disabled = false
		sim_match_button.text = "Simular"

	if not _pending_fixture.is_empty():
		if susp_today or _academy_out_today():
			pass
		elif _player == null or _player.injury_days_remaining <= 0:
			play_match_button.text = "Jugar partido de HOY"
			# Día de partido: el botón late (P1b #13). Una sola vez por botón.
			if not play_match_button.has_meta("pulsing") and not Preferences.reduce_motion:
				play_match_button.set_meta("pulsing", true)
				Juice.pulse(play_match_button, 1.04, 1.2)
		var susp_txt: String = "  ·  ⚠ SANCIONADO (%d partido%s)" % [susp, "" if susp == 1 else "s"] if susp_today else ""
		next_match_label.text = "Hoy: %s%s" % [_fixture_line(_pending_fixture), susp_txt]
		next_match_card.add_theme_stylebox_override("panel", Styles.card_accent(_competition_color(_pending_fixture)))
		_set_next_match_logo(_pending_fixture)
		return

	if _player == null or _player.injury_days_remaining <= 0:
		play_match_button.text = "Jugar partido"
	var nxt := WorldTickEngine.next_user_fixture(_user_club_id())
	if nxt.is_empty():
		next_match_label.text = "Sin partidos en el calendario."
		next_match_card.add_theme_stylebox_override("panel", Styles.card())
		return
	var days_to: int = nxt["epoch_day"] - WorldTickEngine.current_epoch_day
	next_match_label.text = "Próximo (en %d días): %s" % [days_to, _fixture_line(nxt)]
	next_match_card.add_theme_stylebox_override("panel", Styles.card_accent(_competition_color(nxt)))
	# SEMANA DE CLÁSICO (10-oct): cuenta regresiva y la tarjeta en rojo.
	var rival_id: String = RivalryEngine.club_rival_for(_world, _user_club_id(), SaveManager.load_world_seed()) if not _world.is_empty() else ""
	var dw: Dictionary = ImmersionEngine.derby_week(nxt, _user_club_id(), rival_id, WorldTickEngine.current_epoch_day)
	if not dw.is_empty():
		var dl: int = int(dw["days_left"])
		next_match_label.text = "🔥 SEMANA DE CLÁSICO — %s
%s" % ["¡mañana!" if dl == 1 else "faltan %d días" % dl, _fixture_line(nxt)]
		next_match_card.add_theme_stylebox_override("panel", Styles.card_accent(Styles.RED))
	_set_next_match_logo(nxt)

var _next_logo_row: HBoxContainer = null

## Logo de la competición junto a la línea del próximo partido (envuelve
## el Label una vez).
func _set_next_match_logo(fixture: Dictionary) -> void:
	if _next_logo_row == null:
		var parent := next_match_label.get_parent()
		var idx := next_match_label.get_index()
		_next_logo_row = HBoxContainer.new()
		_next_logo_row.add_theme_constant_override("separation", 8)
		parent.remove_child(next_match_label)
		_next_logo_row.add_child(next_match_label)
		next_match_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(_next_logo_row)
		parent.move_child(_next_logo_row, idx)
	for c in _next_logo_row.get_children():
		if c != next_match_label:
			_next_logo_row.remove_child(c)
			c.queue_free()
	var comp: String = String(fixture.get("competition", "league"))
	var logo: Control = null
	if fixture.has("opponent"):
		# Selección (Parte 91): sin liga/copa de club que mostrar — la
		# bandera del rival cumple el mismo rol (identificar el partido
		# de un vistazo) que el logo de competición en un fixture de club.
		logo = CountryFlags.flag_rect(String(fixture.get("opponent", "")), 20)
		if logo != null:
			logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_next_logo_row.add_child(logo)
			_next_logo_row.move_child(logo, 0)
		return
	var uclub := WorldFactory.find_club(_world, _user_club_id())
	if comp == "cup" and uclub != null:
		for lg in _world.get("leagues", []):
			if lg.league_id == uclub.league_id:
				logo = Competition.domestic_cup_node(lg.country, 24)
				break
	elif comp == "friendly":
		logo = null
	elif uclub != null:
		logo = Competition.league_node(uclub.league_id, 24)
	if logo != null:
		logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_next_logo_row.add_child(logo)
		_next_logo_row.move_child(logo, 0)

## Mismo código de color por competencia que ya usa Calendar.gd (Liga=azul,
## Copa=dorado, Amistoso=verde) — una sola paleta de "tipo de partido" en
## toda la app, nunca un criterio de color distinto por pantalla.
func _competition_color(fixture: Dictionary) -> Color:
	match String(fixture.get("competition", "league")):
		"friendly":
			return Styles.GREEN
		"league":
			return Styles.BLUE
		"continental":
			return Color("#c0c0c0")   # plateado — internacional
		"qualifying", "world_cup", "national_cup":
			return Color("#4c6fb1")   # mismo azul "selecciones" que ya usa Calendar.gd
		_:
			return Styles.GOLD

## Menú hamburguesa: Entrenamiento/Vida/Clasificación/Copa ya viven en la
## pestaña "Carrera" de la barra inferior — el cajón se queda con lo que
## no tiene tab propia (Noticias, un acceso directo a explorar, y salir).

## Prensa en CARRUSEL (pedido de Wilber): una noticia a la vez, van
## pasando solas cada PRESS_ROTATE_SECS. Puntos abajo; tocar la tarjeta
## abre el cuerpo y pausa el giro hasta cerrarla.
const PRESS_CAROUSEL_MAX := 6
const PRESS_ROTATE_SECS := 4.5
var _press_cards: Array = []
var _press_dots: HBoxContainer = null
var _press_idx: int = 0
var _press_paused: bool = false
var _press_timer: Timer = null

func _refresh_press() -> void:
	for child in press_box.get_children():
		child.queue_free()
	_press_cards.clear()
	_press_dots = null
	_press_idx = 0
	_press_paused = false
	if _mosaic_on:
		if _press_timer != null:
			_press_timer.stop()
		_press_newspaper()
		return
	# La zona de prensa RESERVA su espacio SIEMPRE (haya o no noticia) para
	# que no salten los elementos de abajo del Hub (pedido de Wilber).
	press_box.custom_minimum_size = Vector2(0, 120)
	if _player == null or _player.press_feed.is_empty():
		var empty := Label.new()
		empty.text = "Sin novedades de la prensa por ahora."
		UiKit.empty_icon(empty, Icons.PX_NEWS)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty.custom_minimum_size = Vector2(0, 96)
		empty.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		empty.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		press_box.add_child(empty)
		return

	var n: int = mini(PRESS_CAROUSEL_MAX, _player.press_feed.size())
	if n == 0:
		return
	for i in range(n):
		var card := _make_press_card(_player.press_feed[i])
		card.visible = (i == 0)
		press_box.add_child(card)
		_press_cards.append(card)

	if n > 1:
		# Fila de navegación: ◀  ● ● ○ ●  ▶ — botones para pasar las
		# noticias a mano (pedido de Wilber), además del giro automático.
		var nav := HBoxContainer.new()
		nav.alignment = BoxContainer.ALIGNMENT_CENTER
		nav.add_theme_constant_override("separation", 12)
		var prev_b := Button.new()
		prev_b.text = "◀"
		prev_b.custom_minimum_size = Vector2(44, 32)
		prev_b.focus_mode = Control.FOCUS_NONE
		Styles.styled_button(prev_b, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
		prev_b.pressed.connect(func(): _press_nav(-1))
		nav.add_child(prev_b)
		_press_dots = HBoxContainer.new()
		_press_dots.alignment = BoxContainer.ALIGNMENT_CENTER
		_press_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_press_dots.add_theme_constant_override("separation", 5)
		for i in range(n):
			var d := Panel.new()
			d.custom_minimum_size = Vector2(7, 7)
			d.add_theme_stylebox_override("panel", Styles.circle(Styles.GOLD if i == 0 else Color(1, 1, 1, 0.22), 7))
			_press_dots.add_child(d)
		nav.add_child(_press_dots)
		var next_b := Button.new()
		next_b.text = "▶"
		next_b.custom_minimum_size = Vector2(44, 32)
		next_b.focus_mode = Control.FOCUS_NONE
		Styles.styled_button(next_b, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
		next_b.pressed.connect(func(): _press_nav(1))
		nav.add_child(next_b)
		press_box.add_child(nav)

		if _press_timer == null:
			_press_timer = Timer.new()
			_press_timer.wait_time = PRESS_ROTATE_SECS
			_press_timer.timeout.connect(_advance_press)
			add_child(_press_timer)
		_press_timer.start()
	elif _press_timer != null:
		_press_timer.stop()

func _advance_press() -> void:
	if _press_paused or _press_cards.size() < 2:
		return
	_show_press((_press_idx + 1) % _press_cards.size())

## Navegación manual de la prensa (botones ◀ ▶). Reinicia el temporizador
## para que no salte de golpe justo después de tocar.
func _press_nav(dir: int) -> void:
	if _press_cards.size() < 2:
		return
	var n := _press_cards.size()
	_show_press((_press_idx + dir + n) % n)
	if _press_timer != null:
		_press_timer.start()

func _show_press(i: int) -> void:
	if i < 0 or i >= _press_cards.size():
		return
	_press_cards[_press_idx].visible = false
	_press_idx = i
	var card: Control = _press_cards[i]
	card.visible = true
	card.modulate.a = 0.0
	create_tween().tween_property(card, "modulate:a", 1.0, 0.25)
	if _press_dots != null:
		for j in range(_press_dots.get_child_count()):
			_press_dots.get_child(j).add_theme_stylebox_override(
				"panel", Styles.circle(Styles.GOLD if j == i else Color(1, 1, 1, 0.22), 7))

## Llamado desde _make_press_card cuando se abre/cierra el cuerpo: pausa o
## reanuda el giro del carrusel.
func _set_press_paused(paused: bool) -> void:
	_press_paused = paused

const PRESS_CARD_H := 76

## Tarjeta de prensa de TAMAÑO FIJO — fuente + titular (recortado). Al
## tocar NO se expande en el Hub: lleva a la pantalla de Noticias abierta
## en esa noticia (pedido de Wilber).
func _make_press_card(entry: Dictionary) -> PanelContainer:
	var accent: Color = Styles.sentiment_color(entry.get("sentiment", ""))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(accent))
	panel.custom_minimum_size = Vector2(0, PRESS_CARD_H)
	panel.clip_contents = true
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 3)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 6)
	var src_logo := MediaOutlets.logo(String(entry.get("source", "")), 20)
	src_logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(src_logo)
	var source_lbl := Label.new()
	source_lbl.text = MediaOutlets.display(String(entry.get("source", ""))).to_upper()
	source_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_lbl.add_theme_color_override("font_color", accent)
	source_lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	source_lbl.clip_text = true
	var arrow := Label.new()
	arrow.text = "leer  ›"
	arrow.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	arrow.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	top.add_child(source_lbl)
	top.add_child(arrow)
	vb.add_child(top)

	var headline_lbl := Label.new()
	headline_lbl.text = String(entry.get("headline", ""))
	headline_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	headline_lbl.max_lines_visible = 2
	headline_lbl.add_theme_font_size_override("font_size", 15)
	headline_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(headline_lbl)

	margin.add_child(vb)
	panel.add_child(margin)
	var e_key: String = "%d|%s" % [int(entry.get("day", 0)), String(entry.get("headline", ""))]
	UiScroll.on_tap(panel, func():
		WorldTickEngine.focus_news_key = e_key
		get_tree().change_scene_to_file("res://scenes/News/News.tscn"))
	return panel

func _on_sponsor_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/SponsorOffer/SponsorOffer.tscn")

func _on_wage_offer_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/WageOffer/WageOffer.tscn")

func _on_season_event_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/SeasonEvent/SeasonEvent.tscn")

func _refresh_cup_label() -> void:
	var s := WorldTickEngine.user_cup_status()
	var status: String = s.get("status", "out")
	match status:
		"champion":
			cup_label.text = "Copa: ¡CAMPEÓN!"
		"eliminated":
			cup_label.text = "Copa: eliminado en %s" % s.get("round_name", "?")
		"advancing":
			cup_label.text = "Copa: clasificado — %s" % s.get("round_name", "?")
		"upcoming":
			var days_to: int = int(s["epoch_day"]) - WorldTickEngine.current_epoch_day
			var when: String = "HOY" if days_to <= 0 else "en %d días" % days_to
			cup_label.text = "Copa (%s): %s" % [when, _fixture_line(s)]
		_:
			cup_label.text = ""

## Mini tabla de posiciones en el Hub — con FORMA de tabla (columnas Pos /
## Club / PJ / Pts, franja verde/roja por zona), no un bloque de texto.
var _standings_box: VBoxContainer = null

func _refresh_standings() -> void:
	standings_label.visible = false
	if _standings_box == null:
		_standings_box = VBoxContainer.new()
		_standings_box.add_theme_constant_override("separation", 3)
		standings_label.get_parent().add_child(_standings_box)
		standings_label.get_parent().move_child(_standings_box, standings_label.get_index() + 1)
	for c in _standings_box.get_children():
		c.queue_free()

	var table := WorldTickEngine.user_league_table()
	if table.is_empty():
		return
	var widths: Array = [26, 300, 34, 34, 34, 40, 40] if _mosaic_on else [22, 96, 26, 28, 28, 32, 32]
	var hspace := Control.new()
	hspace.custom_minimum_size = Vector2(18, 1)
	DataTable.add_row(_standings_box, ["#", "Club", "PJ", "GF", "GC", "+/-", "Pts"], widths, true, false, Callable(), Color.TRANSPARENT, hspace)
	var n: int = table.size()
	var shown := {}
	var to_show: Array = []
	# En el mosaico la tabla va en un panel grande: la liga entera
	var top_n: int = n if _mosaic_on else mini(4, n)
	for i in range(top_n):
		to_show.append(table[i])
	var mine: Dictionary = LeagueTable.row_for(table, _user_club_id())
	if not mine.is_empty() and int(mine["pos"]) > top_n:
		to_show.append(mine)
	var league_id: int = int(WorldTickEngine.season.get("league_id", -1))
	var league: LeagueData = null
	for lg in WorldTickEngine.world.get("leagues", []):
		if lg.league_id == league_id:
			league = lg
			break
	for r in to_show:
		var pos: int = int(r["pos"])
		var accent: Color = StandingsColor.accent_for(league, n, pos)
		var is_mine: bool = String(r["club_id"]) == _user_club_id()
		var dg: int = int(r.get("dg", int(r.get("gf", 0)) - int(r.get("gc", 0))))
		var dg_txt: String = ("+%d" % dg) if dg > 0 else str(dg)
		DataTable.add_row(_standings_box, [
			str(pos), r["name"], str(r["pj"]), str(r.get("gf", 0)), str(r.get("gc", 0)), dg_txt, str(r["pts"])
		], widths, false, is_mine, Callable(), accent, Styles.club_crest(String(r["club_id"]), 18))

## Selección nacional (Parte 91): el fixture trae "opponent"/"is_home" en
## vez de home_club_id/away_club_id (ver
## WorldTickEngine._normalize_national_fixture/QualifyingEngine.
## user_fixture_today) — nunca coincide con un fixture de club, así que
## sirve de discriminador limpio sin tocar el resto de la función.
## "vs Rival" (o "en casa de Rival") para botones estrechos.
func _rival_line(fixture: Dictionary) -> String:
	if fixture.has("opponent"):
		return "vs %s" % String(fixture.get("opponent", "?"))
	var me: String = _user_club_id()
	var home_id: String = String(fixture.get("home_club_id", ""))
	var rival := WorldFactory.find_club(_world, String(fixture.get("away_club_id", "")) if home_id == me else home_id)
	return "vs %s" % (rival.club_name if rival != null else "?")


func _fixture_line(fixture: Dictionary) -> String:
	if fixture.has("opponent"):
		var user_country: String = _player.country if _player != null else "?"
		var opponent: String = String(fixture.get("opponent", "?"))
		var is_home: bool = bool(fixture.get("is_home", true))
		var home_name: String = user_country if is_home else opponent
		var away_name: String = opponent if is_home else user_country
		var comp: String
		match String(fixture.get("competition", "qualifying")):
			"world_cup": comp = "Mundial"
			"national_cup": comp = "Copa continental"
			_: comp = "Eliminatoria"
		return "%s vs %s  (%s)" % [home_name, away_name, comp]
	var home := WorldFactory.find_club(_world, fixture.get("home_club_id", ""))
	var away := WorldFactory.find_club(_world, fixture.get("away_club_id", ""))
	var home_name: String = home.club_name if home != null else "?"
	var away_name: String = away.club_name if away != null else "?"
	var competition: String = fixture.get("competition", "league")
	var comp: String
	if competition == "cup":
		comp = fixture.get("round_name", "")
	elif competition == "friendly":
		comp = "Amistoso"
	else:
		comp = "Liga J%d" % fixture.get("matchday", 0)
	return "%s vs %s  (%s)" % [home_name, away_name, comp]

## Fichaje de mitad de temporada recién cerrado (WorldTickEngine.
## pending_presentation) → presentación oficial en el estadio, una vez.
func _maybe_present_signing() -> void:
	var pend: Dictionary = WorldTickEngine.pending_presentation
	if pend.is_empty() or has_node("PlayerPresentation"):
		return
	WorldTickEngine.pending_presentation = {}
	var p := SaveManager.load_player()
	if p == null:
		return
	var pp := PlayerPresentation.new()
	pp.name = "PlayerPresentation"
	pp.setup({"club_id": String(pend.get("club_id", p.club_id)), "player": p,
		"years": int(pend.get("years", p.contract_years_remaining)), "number": 0, "loan": bool(pend.get("loan", false))})
	add_child(pp)

## Botón de oferta de GUAYOS (schema v32), debajo del de patrocinio.
var _boot_btn: Button = null
func _refresh_boot_offer_button() -> void:
	var p := SaveManager.load_player()
	var show: bool = p != null and not p.pending_boot_offer.is_empty()
	if not show:
		if _boot_btn != null:
			_boot_btn.visible = false
		return
	var brand: Dictionary = BootBrands.by_id(String(p.pending_boot_offer.get("brand", "")))
	if _boot_btn == null:
		_boot_btn = Button.new()
		_boot_btn.custom_minimum_size = Vector2(0, 50)
		_boot_btn.focus_mode = Control.FOCUS_NONE
		_boot_btn.pressed.connect(func():
			var panel := BootOfferPanel.new()
			panel.closed.connect(_refresh_status)
			add_child(panel))
		var parent := sponsor_button.get_parent()
		parent.add_child(_boot_btn)
		parent.move_child(_boot_btn, sponsor_button.get_index() + 1)
	_boot_btn.visible = true
	_boot_btn.text = "  Guayos %s: %s/semana" % [String(brand.get("name", "")), CurrencyFormat.format(int(p.pending_boot_offer.get("weekly_income", 0)))]
	var logo := "res://assets/brands/%s.png" % String(brand.get("logo", ""))
	if ResourceLoader.exists(logo):
		_boot_btn.icon = load(logo)
		_boot_btn.add_theme_constant_override("icon_max_width", 28)
		_boot_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Styles.styled_button(_boot_btn, Styles.pill_filled(Color(String(brand.get("color", "#ffd54f")))), Color.BLACK)


## HORIZONTAL (FootballLegacy H): dos columnas. Izquierda: tu ficha, tu
## semana y objetivos. Derecha: avisos, PRÓXIMO PARTIDO con sus botones,
## prensa y tabla. Mismo orden de bloques que _arrange_blocks dentro de
## cada columna; los nodos se mueven (no se recrean), así las variables
## @onready siguen apuntando bien.
func _landscape_layout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= vp.y:
		return
	var box := $Root/Scroll/BodyMargin/BodyVBox as VBoxContainer
	var sep: int = box.get_theme_constant("separation")
	var cols := HBoxContainer.new()
	cols.name = "Cols"
	cols.add_theme_constant_override("separation", 18)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for v in [left, right]:
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", sep)
		cols.add_child(v)
	var kids: Array = box.get_children()
	box.add_child(cols)
	box.move_child(cols, 0)
	var zone: String = "alerts"
	for k in kids:
		var n: String = String(k.name)
		if n == "StatusCard":
			k.reparent(left)
			continue
		if n == "NextMatchTitle":
			zone = "match"
		elif zone == "after" and (n in ["PressTitleLabel", "PressBox", "StandingsLabel"] or _node_text(k).contains("PRENSA")):
			zone = "press"
		k.reparent(right if zone != "after" else left)
		if n in ["NextMatchTitle", "NextMatchCard", "MatchActionsRow"]:
			(k as CanvasItem).visible = false
		if n == "MatchActionsRow":
			zone = "after"
	# La carta y la semana tienen que verse juntas: los chips (confianza,
	# titular, afición...) pasan arriba de la columna derecha y el título
	# "TU SEMANA" sobra (la tira se explica sola).
	if left.has_node("WeekTitleLabel"):
		left.get_node("WeekTitleLabel").visible = false

func _node_text(n: Node) -> String:
	if n is Label:
		return (n as Label).text
	for c in n.get_children():
		var t: String = _node_text(c)
		if t != "":
			return t
	return ""


func _is_land() -> bool:
	var vp: Vector2 = get_viewport_rect().size
	return vp.x > vp.y

## HORIZONTAL: el día de partido de la tira semanal muestra el escudo del
## rival y si sos LOCAL o VISITANTE (como el Calendario). Tocarlo te lleva al
## partido: si es hoy, a la previa; si es más adelante, avanza hasta ese día
## y abre la previa (ahí elegís Jugar o Simular).
func _land_match_cell(panel: PanelContainer, vb: VBoxContainer, fx: Dictionary, day: int, is_national: bool, bg: Color) -> void:
	panel.custom_minimum_size = Vector2(56, 100)
	var club: String = _user_club_id()
	var away: bool
	var crest: Control
	if is_national or fx.has("opponent"):
		away = not bool(fx.get("is_home", true))
		crest = CountryFlags.flag_rect(String(fx.get("opponent", "")), 22)
	else:
		away = String(fx.get("away_club_id", "")) == club
		crest = Styles.club_crest(String(fx.get("home_club_id", "")) if away else String(fx.get("away_club_id", "")), 36)
	if away:
		# Visitante: celda clara con texto oscuro (mismo código que el Calendario).
		panel.add_theme_stylebox_override("panel", Styles.card(Color(0.86, 0.87, 0.9) if day != WorldTickEngine.current_epoch_day else bg.lightened(0.45), 10))
		for l in vb.get_children():
			(l as Label).add_theme_color_override("font_color", Color(0.1, 0.11, 0.14))
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(crest)
	vb.add_child(cc)
	var tag := Label.new()
	tag.text = "VIS" if away else "LOC"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_override("font", Styles.font_semibold())
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", Color(0.1, 0.11, 0.14) if away else Color(0.92, 0.93, 0.96))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tag)
	for c in vb.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiScroll.on_tap(panel, func(): _go_to_match_day(day))

func _go_to_match_day(day: int) -> void:
	if _player != null and _player.injury_days_remaining > 0:
		return
	if day <= WorldTickEngine.current_epoch_day and _academy_out_today():
		return   # cantera sin convocatoria: el botón ya simula el partido
	if day <= WorldTickEngine.current_epoch_day:
		_try_launch(false)
		return
	if not _pending_fixture.is_empty():
		_warn_match_today()
		return
	_maybe_confirm("Avanzar hasta el partido", func():
		_clear_bulk_target()
		_advance_to_day(day, false)
		if is_inside_tree() and not _pending_fixture.is_empty():
			_try_launch(false))


## HORIZONTAL: la pantalla principal entra ENTERA, sin scroll. Izquierda:
## carta + semana. Derecha: chips, avisos, Pasar/Avanzar y abajo un cuadro
## con pestañas (Prensa · Tabla · Objetivos) que ocupa lo que sobra.
var _land_tab: int = 0
var _land_pages: Array = []
var _land_tab_btns: Array = []

func _landscape_fit() -> void:
	if not _is_land() or not is_inside_tree():
		return
	var root_scroll := $Root/Scroll as ScrollContainer
	# SHOW_NEVER y no DISABLED: con DISABLED el scroll mide lo que su contenido y,
	# si este crecía (p. ej. con "Planificar la semana"), empujaba la barra de
	# navegación fuera de la pantalla (Wilber: "los botones se tapan").
	root_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root_scroll.scroll_vertical = 0
	get_tree().process_frame.connect(func(): root_scroll.scroll_vertical = 0, CONNECT_ONE_SHOT)
	var margin := $Root/Scroll/BodyMargin as MarginContainer
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.add_theme_constant_override("margin_top", margin.get_theme_constant("margin_top") + 4)
	var box := $Root/Scroll/BodyMargin/BodyVBox as VBoxContainer
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cols := box.get_node("Cols") as HBoxContainer
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := cols.get_child(0) as VBoxContainer
	var right := cols.get_child(1) as VBoxContainer
	# Izquierda FIJA y derecha con su propio scroll (Wilber, 8-nov: "las
	# pantallas que tienen 2 columnas y la de la izquierda no deberian
	# moverse"). Antes se desplazaba toda la pantalla y, si la derecha no
	# cabía, "Fecha FIFA" y los botones de avanzar quedaban bajo la barra.
	UiKit.fixed_column(left) # queda en el mismo sitio de `cols`
	var rsc := ScrollContainer.new()
	rsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rsc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	rsc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiScroll.make_touch(rsc)
	cols.add_child(rsc)
	right.reparent(rsc)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Izquierda: carta + semana (que llega hasta abajo). Derecha: chips,
	# Pasar/Avanzar y las pestañas.
	chips_row.reparent(right)
	right.move_child(chips_row, 0)
	week_strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Títulos de sección que sobran (la tira y las pestañas se explican solas).
	for col in [left, right]:
		for k in col.get_children():
			if k is Label and (k as Label).text in ["TU SEMANA", "PRENSA"]:
				(k as Label).visible = false
	# Cuadro con pestañas.
	var tabs_box := VBoxContainer.new()
	tabs_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs_box.add_theme_constant_override("separation", 6)
	right.add_child(tabs_box)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	tabs_box.add_child(bar)
	var titles: Array = ["Prensa", "Tabla", "Objetivos"]
	for i in titles.size():
		var b := Button.new()
		b.text = titles[i]
		b.custom_minimum_size = Vector2(0, 32)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_land_show_tab.bind(i))
		bar.add_child(b)
		_land_tab_btns.append(b)
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		UiScroll.make_touch(sc)
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 4)
		sc.add_child(page)
		tabs_box.add_child(sc)
		_land_pages.append(sc)
	press_box.reparent(_land_pages[0].get_child(0))
	press_box.custom_minimum_size = Vector2.ZERO
	standings_label.reparent(_land_pages[1].get_child(0))
	if _standings_box != null:
		_standings_box.reparent(_land_pages[1].get_child(0))
	if _goals_box != null:
		_goals_box.reparent(_land_pages[2].get_child(0))
	_land_show_tab(_land_tab)
	# DÍA DE PARTIDO: un solo botón grande "Ir al partido" en lugar de
	# Pasar el día / Avanzar (los dos juntos confundían).
	var adv: Control = next_match_button.get_parent() as Control
	# "Planificar la semana" en la misma fila que Pasar el día / Avanzar (sola en
	# su fila ocupaba media pantalla de alto y no cabía todo)
	if _planner_button != null and adv is GridContainer:
		_planner_button.reparent(adv)
		adv.move_child(_planner_button, 0)
		_planner_button.text = "Planificar"
		_planner_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# El aviso de Fecha FIFA también va en esa fila (solo ocupaba media fila
	# y empujaba Pasar el día / Avanzar por debajo de la pantalla). La rejilla
	# salta los botones ocultos: caben hasta 4 en una fila.
	if _fifa_button != null and adv is GridContainer:
		_fifa_button.reparent(adv)
		adv.move_child(_fifa_button, 1 if _planner_button != null and _planner_button.get_parent() == adv else 0)
		_fifa_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_fifa_button.clip_text = true
	if adv is GridContainer:
		for b in adv.get_children():
			if b is Control:
				(b as Control).custom_minimum_size.y = 42.0
		_land_adv_cols()
	_land_match_btn = Button.new()
	_land_match_btn.focus_mode = Control.FOCUS_NONE
	_land_match_btn.custom_minimum_size = Vector2(0, 56)
	_land_match_btn.add_theme_font_size_override("font_size", 18)
	_land_match_btn.clip_text = true
	Styles.styled_button(_land_match_btn, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	_land_match_btn.pressed.connect(func(): _go_to_match_day(WorldTickEngine.current_epoch_day))
	adv.get_parent().add_child(_land_match_btn)
	adv.get_parent().move_child(_land_match_btn, adv.get_index())
	_land_refresh_match_day()
	_build_mosaic(left, right, tabs_box)

func _land_show_tab(i: int) -> void:
	_land_tab = i
	for j in _land_pages.size():
		(_land_pages[j] as Control).visible = j == i
		var b: Button = _land_tab_btns[j]
		if j == i:
			Styles.styled_button(b, Styles.pill_filled(Styles.GOLD), Color.BLACK)
		else:
			Styles.styled_button(b, Styles.pill_filled(Color(0.16, 0.17, 0.21)), Color(0.85, 0.86, 0.9))


var _land_match_btn: Button = null

func _land_refresh_match_day() -> void:
	if _land_match_btn == null or not is_instance_valid(_land_match_btn):
		return
	_land_pack_alerts()
	var adv: Control = next_match_button.get_parent() as Control
	var today: bool = not _pending_fixture.is_empty()
	adv.visible = not today
	_land_match_btn.visible = today
	if not today:
		return
	if _player != null and _player.injury_days_remaining > 0:
		_land_match_btn.text = "Lesionado (%d días): simular el partido" % _player.injury_days_remaining
		_land_match_btn.pressed.connect(_on_sim_match_pressed, CONNECT_ONE_SHOT)
	elif _academy_out_today():
		_land_match_btn.text = "Cantera: ver el partido del primer equipo  ·  %s" % _rival_line(_pending_fixture)
		_land_match_btn.pressed.connect(_on_sim_match_pressed, CONNECT_ONE_SHOT)
	else:
		# 7-nov: con "Local vs Visitante (Competición)" el nombre del rival se cortaba;
		# solo el rival, que es lo que importa ("Ir al partido · vs X").
		var star: String = "⭐  Convocado con el primer equipo  ·  " if AcademyEngine.in_academy(_player) else "⚽  Ir al partido  ·  "
		_land_match_btn.text = star + _rival_line(_pending_fixture)
	if not _land_match_btn.has_meta("pulsing") and not Preferences.reduce_motion:
		_land_match_btn.set_meta("pulsing", true)
		_land_match_btn.ready.connect(func(): Juice.pulse(_land_match_btn, 1.03, 1.2))


## Avisos (patrocinio, guayos, evento, convocatoria, mensajes, planificar):
## en horizontal van en una grilla compacta de 2 columnas. Apilados a lo
## ancho empujaban Prensa/Tabla/Objetivos fuera de la pantalla.
func _land_pack_alerts() -> void:
	var adv: Control = next_match_button.get_parent() as Control
	var right: Node = adv.get_parent()
	if right == null:
		return
	var g: GridContainer = right.get_node_or_null("LandAlerts")
	if g == null:
		g = GridContainer.new()
		g.name = "LandAlerts"
		g.columns = 2
		g.add_theme_constant_override("h_separation", 6)
		g.add_theme_constant_override("v_separation", 6)
		right.add_child(g)
		right.move_child(g, adv.get_index())
	for c in right.get_children():
		if c is Button and c != _land_match_btn:
			c.reparent(g)
	for b in g.get_children():
		var bt := b as Button
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.custom_minimum_size = Vector2(0, 34)
		bt.clip_text = true
		bt.add_theme_font_size_override("font_size", 13)
		bt.add_theme_constant_override("icon_max_width", 18)
	right.move_child(g, adv.get_index())
	if _mosaic_on:
		g.columns = 3


# ---------------------------------------------------------------- mosaico (8-nov)
## INICIO estilo consola pero táctil (Wilber: "un menú mejor como las del PES o
## FIFA pero en táctil"). En horizontal: a la izquierda tu jugador en 3D con la
## camiseta del club (hace un gesto de vez en cuando), su nivel/energía y la
## semana; a la derecha el próximo partido en grande y un mosaico de tarjetas
## (Prensa, Tabla, Objetivos, Entrenamiento, Práctica, Vida). Prensa/Tabla/
## Objetivos abren su panel encima (el mismo de antes). La lógica del Hub
## (avisos, Pasar/Avanzar, día de partido) no cambia: solo la forma.
const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")
const HERO_GESTURES := ["fist_pump", "clap", "point", "victory_idle"]
const MOSAIC_TILES := [
	{"key": "press", "title": "Prensa", "icon": Icons.PX_NEWS},
	{"key": "table", "title": "Tabla", "icon": Icons.PX_STANDINGS},
	{"key": "goals", "title": "Objetivos", "icon": Icons.PX_AWARDS},
	{"key": "training", "title": "Entrenamiento", "icon": Icons.PX_TRAINING},
	{"key": "practice", "title": "Práctica", "icon": Icons.PX_CUP},
	{"key": "life", "title": "Vida personal", "icon": Icons.PX_LIFESTYLE},
]

var _mosaic_on := false
var _mosaic_bodies := {}          # key -> VBoxContainer con el texto de la tarjeta
var _mosaic_match: VBoxContainer = null
var _hero_info: VBoxContainer = null
var _hero_face: Control = null
var _panel_overlay: Control = null
var _accent := Styles.GREEN


func _club_accent() -> Color:
	if _club != null and _club.primary_color_hex != "":
		var c := Color(_club.primary_color_hex)
		# Colores muy oscuros (negro, azul marino) no se leen como borde: aclarar
		var out: Color = c.lightened(0.35) if c.get_luminance() < 0.18 else c
		return out
	return Styles.GREEN


func _build_mosaic(left: VBoxContainer, right: VBoxContainer, tabs_box: Control) -> void:
	_mosaic_on = true
	_accent = _club_accent()
	# Fondo con el color del club, detrás de todo
	var base: Color = Color(_club.primary_color_hex) if _club != null and _club.primary_color_hex != "" else Styles.GREEN
	var bd := UiKit.club_backdrop(base)
	add_child(bd)
	move_child(bd, 0)
	# Izquierda: tu jugador en 3D, su ficha corta y la semana
	status_card.visible = false
	left.custom_minimum_size.x = 360
	left.size_flags_stretch_ratio = 0.62
	var hero := VBoxContainer.new()
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.add_theme_constant_override("separation", 4)
	left.add_child(hero)
	left.move_child(hero, 0)
	if _player != null:
		_hero_face = Match3DBridge.portrait(_player, _club, 260, true, Color(0, 0, 0, 0))
		_hero_face.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_hero_face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_hero_face.custom_minimum_size = Vector2(0, 140) # crece con el sitio libre; la columna es fija
		hero.add_child(_hero_face)
		var t := Timer.new()
		t.wait_time = 7.0
		t.autostart = true
		t.timeout.connect(_hero_gesture)
		add_child(t)
	_hero_info = VBoxContainer.new()
	_hero_info.add_theme_constant_override("separation", 3)
	hero.add_child(_hero_info)
	week_strip.size_flags_vertical = Control.SIZE_SHRINK_END
	# Derecha: el partido en grande, el mosaico y abajo los avisos y Pasar/Avanzar
	var at := chips_row.get_index() + 1
	_mosaic_match = VBoxContainer.new()
	_mosaic_match.add_theme_constant_override("separation", 2)
	var match_tile := UiKit.tile("Próximo partido", _accent, _mosaic_match, _on_match_tile, 120)
	right.add_child(match_tile)
	right.move_child(match_tile, at)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	right.add_child(grid)
	right.move_child(grid, at + 1)
	for d: Dictionary in MOSAIC_TILES:
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 0)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var ic := TextureRect.new()
		ic.texture = Icons.load_icon(String(d.icon))
		ic.custom_minimum_size = Vector2(32, 32)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		row.add_child(body)
		_mosaic_bodies[String(d.key)] = body
		var tl := UiKit.tile(String(d.title), _accent, row, _on_mosaic_tile.bind(String(d.key)), 64)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(tl)
	# Prensa · Tabla · Objetivos: el cuadro con pestañas de antes, ahora encima
	_build_panel_overlay(tabs_box)
	_refresh_press()
	_refresh_standings()
	_refresh_mosaic()


func _hero_gesture() -> void:
	if _hero_face == null or not is_instance_valid(_hero_face) or not (_hero_face is PlayerPortrait):
		return
	var av = (_hero_face as PlayerPortrait).avatar
	if av == null or av.anim == null:
		return
	var anim: String = HERO_GESTURES.pick_random()
	if av.anim.has_animation(anim):
		av.anim.play(anim, 0.25)
		av.anim.queue("idle")


## Panel encima de la pantalla (Prensa/Tabla/Objetivos) con su botón de cerrar.
func _build_panel_overlay(tabs_box: Control) -> void:
	_panel_overlay = Control.new()
	_panel_overlay.name = "PanelOverlay"
	_panel_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_overlay.visible = false
	_panel_overlay.z_index = 20
	add_child(_panel_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_overlay.add_child(dim)
	UiScroll.on_tap(dim, func() -> void: _panel_overlay.visible = false)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Styles.card_accent(_accent))
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 70
	card.offset_right = -70
	card.offset_top = 72    # debajo de la barra de arriba (si no, tapa las pestañas)
	card.offset_bottom = -10
	_panel_overlay.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	tabs_box.reparent(col)
	tabs_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "Cerrar"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(0, 42)
	Styles.styled_button(close, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	close.pressed.connect(func() -> void: _panel_overlay.visible = false)
	col.add_child(close)


func _on_mosaic_tile(key: String) -> void:
	match key:
		"press": _open_panel(0)
		"table": _open_panel(1)
		"goals": _open_panel(2)
		"training": get_tree().change_scene_to_file("res://scenes/Training/Training.tscn")
		"practice": get_tree().change_scene_to_file("res://scenes/Practice/Practice.tscn")
		"life": get_tree().change_scene_to_file("res://scenes/Lifestyle/Lifestyle.tscn")


func _open_panel(i: int) -> void:
	if _panel_overlay == null:
		return
	_land_show_tab(i)
	_panel_overlay.visible = true


## El próximo partido: si es hoy, a jugarlo; si no, avanza hasta ese día.
func _on_match_tile() -> void:
	if not _pending_fixture.is_empty():
		_go_to_match_day(WorldTickEngine.current_epoch_day)
		return
	var fx: Dictionary = WorldTickEngine.next_user_fixture(_user_club_id())
	if not fx.is_empty():
		_go_to_match_day(int(fx.get("epoch_day", WorldTickEngine.current_epoch_day)))


func _refresh_mosaic() -> void:
	if not _mosaic_on or _player == null:
		return
	_refresh_hero_info()
	_refresh_match_tile()
	var b: Dictionary = _mosaic_bodies
	# Prensa: el último titular
	var head := "Sin novedades"
	if not _player.press_feed.is_empty():
		head = String((_player.press_feed[0] as Dictionary).get("headline", head))
	_fill(b.press, head, "Toca para ver todas")
	# Tabla: tu puesto
	var table: Array = WorldTickEngine.user_league_table()
	var mine: Dictionary = {} if table.is_empty() else LeagueTable.row_for(table, _user_club_id())
	if mine.is_empty():
		_fill(b.table, "Sin liga", "")
	else:
		_fill(b.table, "%dº de %d" % [int(mine.get("pos", 0)), table.size()],
				"%d pts · %d PJ" % [int(mine.get("pts", 0)), int(mine.get("pj", 0))])
	# Objetivos de la semana
	var goals: Array = WeeklyGoalsEngine.current(WorldTickEngine.season, WorldTickEngine.current_epoch_day, SaveManager.load_world_seed())
	var done := 0
	var to_claim := 0
	for g: Dictionary in goals:
		if WeeklyGoalsEngine.is_done(g):
			done += 1
			if not bool(g.get("claimed", false)):
				to_claim += 1
	var sub_goals: String = ("¡%d por cobrar!" % to_claim) if to_claim > 0 else "esta semana"
	_fill(b.goals, "%d de %d cumplidos" % [done, goals.size()], sub_goals)
	# Entrenamiento: tu foco
	var sub_tr: String = "Lesionado" if _player.injury_days_remaining > 0 else "Toca para entrenar"
	_fill(b.training, _focus_label(WorldTickEngine.get_training_focus()), sub_tr)
	# Práctica: retos cobrados
	var pst: Dictionary = PracticeEngine.state(WorldTickEngine.season, WorldTickEngine.current_epoch_day,
			SaveManager.load_world_seed(), _player.position == "GK")
	_fill(b.practice, "%d/%d cobrados" % [int(pst.get("claims", 0)), PracticeEngine.MAX_CLAIMS_PER_WEEK], "retos de la semana")
	# Vida personal
	_fill(b.life, LifestyleEngine.home_label(_player.home_type), LifestyleEngine.car_label(_player.car_type))


func _focus_label(key: String) -> String:
	match key:
		"physical": return "Físico"
		"technical": return "Técnica"
		"mental": return "Mental"
	return "Equilibrado"


func _fill(body: VBoxContainer, big: String, small: String) -> void:
	for c in body.get_children():
		c.queue_free()
	var l := UiKit.tile_text(big, 15, Color.WHITE, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(l)
	if small != "":
		var s2 := UiKit.tile_text(small, 12, Color(0.75, 0.77, 0.82))
		s2.autowrap_mode = TextServer.AUTOWRAP_OFF
		s2.clip_text = true
		s2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		body.add_child(s2)


func _refresh_hero_info() -> void:
	for c in _hero_info.get_children():
		c.queue_free()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	_hero_info.add_child(top)
	top.add_child(UiKit.chip("%d" % _player.overall, PlayerCard.tier_color(_player.overall)))
	var name_l := UiKit.tile_text(_player.player_name, 18, Color.WHITE, true)
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_l.clip_text = true
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	var pos: String = _player.detailed_position if _player.detailed_position != "" else _player.position
	top.add_child(UiKit.chip(pos, _accent))
	_hero_info.add_child(_build_energy_row())
	_hero_info.add_child(_build_level_row())


func _refresh_match_tile() -> void:
	for c in _mosaic_match.get_children():
		c.queue_free()
	var today := not _pending_fixture.is_empty()
	var fx: Dictionary = _pending_fixture if today else WorldTickEngine.next_user_fixture(_user_club_id())
	if fx.is_empty():
		_mosaic_match.add_child(UiKit.tile_text("Sin partidos en el calendario", 16, Styles.GRAY_TEXT))
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_mosaic_match.add_child(row)
	var home_c: Control
	var away_c: Control
	var home_n: String
	var away_n: String
	if fx.has("opponent"):
		var is_home: bool = bool(fx.get("is_home", true))
		var opp := String(fx.get("opponent", "?"))
		home_n = _player.country if is_home else opp
		away_n = opp if is_home else _player.country
		home_c = CountryFlags.flag_rect(home_n, 40)
		away_c = CountryFlags.flag_rect(away_n, 40)
	else:
		var hc := WorldFactory.find_club(_world, String(fx.get("home_club_id", "")))
		var ac := WorldFactory.find_club(_world, String(fx.get("away_club_id", "")))
		home_n = hc.club_name if hc != null else "?"
		away_n = ac.club_name if ac != null else "?"
		home_c = Styles.club_crest(String(fx.get("home_club_id", "")), 52)
		away_c = Styles.club_crest(String(fx.get("away_club_id", "")), 52)
	row.add_child(_match_side(home_c, home_n))
	var mid := VBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.custom_minimum_size.x = 120
	var vs := UiKit.tile_text("HOY" if today else "VS", 24, Styles.GOLD if today else Color.WHITE, true)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(vs)
	var line := _fixture_line(fx)
	var comp := ""
	if line.contains("("):
		comp = line.substr(line.rfind("(") + 1).trim_suffix(")")
	var cl := UiKit.tile_text(comp, 12, _competition_color(fx).lightened(0.35))
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(cl)
	if not today:
		var days_to: int = int(fx.get("epoch_day", 0)) - WorldTickEngine.current_epoch_day
		var dl := UiKit.tile_text("en %d día%s" % [days_to, "" if days_to == 1 else "s"], 12, Color(0.8, 0.82, 0.86))
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mid.add_child(dl)
	row.add_child(mid)
	row.add_child(_match_side(away_c, away_n))
	UiKit._ignore_mouse(_mosaic_match)


func _match_side(crest: Control, n: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 170
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	var cc := CenterContainer.new()
	cc.add_child(crest)
	v.add_child(cc)
	var l := UiKit.tile_text(n, 14, Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(l)
	return v


## PRENSA en el mosaico (8-nov, Wilber: "en la de prensa se pueden mostrar
## diferentes las noticias"): como la portada de un periódico. La principal en
## grande con su entradilla; las demás en dos columnas. Tocar abre Noticias.
const PRESS_PAPER_MAX := 9

func _press_newspaper() -> void:
	press_box.custom_minimum_size = Vector2.ZERO
	if _player == null or _player.press_feed.is_empty():
		var empty := UiKit.tile_text("Sin novedades de la prensa por ahora.", 14, Styles.GRAY_TEXT)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		press_box.add_child(empty)
		return
	press_box.add_child(_press_story(_player.press_feed[0], true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for i in range(1, mini(PRESS_PAPER_MAX, _player.press_feed.size())):
		var st := _press_story(_player.press_feed[i], false)
		st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(st)
	press_box.add_child(grid)
	var all := Button.new()
	all.text = "Ver todas en Noticias"
	all.focus_mode = Control.FOCUS_NONE
	all.custom_minimum_size = Vector2(0, 38)
	Styles.styled_button(all, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	all.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/News/News.tscn"))
	press_box.add_child(all)


func _press_story(entry: Dictionary, lead: bool) -> PanelContainer:
	var accent: Color = Styles.sentiment_color(entry.get("sentiment", ""))
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.15) if lead else Color(0.09, 0.1, 0.12)
	sb.set_corner_radius_all(10)
	sb.border_width_left = 4
	sb.border_color = accent
	sb.content_margin_left = 14
	sb.content_margin_right = 12
	sb.content_margin_top = 10 if lead else 8
	sb.content_margin_bottom = 10 if lead else 8
	panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	vb.add_child(top)
	top.add_child(MediaOutlets.logo(String(entry.get("source", "")), 22 if lead else 16))
	var src := UiKit.tile_text(MediaOutlets.display(String(entry.get("source", ""))).to_upper(), 11, accent, true)
	src.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	src.clip_text = true
	top.add_child(src)
	var ago: int = WorldTickEngine.current_epoch_day - int(entry.get("day", WorldTickEngine.current_epoch_day))
	var when := "hoy" if ago <= 0 else ("ayer" if ago == 1 else "hace %d días" % ago)
	var wl := UiKit.tile_text(("PORTADA · " if lead else "") + when, 11, Styles.GOLD if lead else Styles.GRAY_TEXT)
	wl.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING   # si no, su ancho mínimo es ~0 y desaparece
	top.add_child(wl)
	var head := UiKit.tile_text(String(entry.get("headline", "")), 22 if lead else 14, Color.WHITE, lead)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.max_lines_visible = 2
	vb.add_child(head)
	var body := String(entry.get("body", ""))
	if lead and body != "":
		var bl := UiKit.tile_text(body, 13, Color(0.78, 0.8, 0.85))
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.max_lines_visible = 3
		vb.add_child(bl)
	UiKit._ignore_mouse(vb)
	var e_key: String = "%d|%s" % [int(entry.get("day", 0)), String(entry.get("headline", ""))]
	UiScroll.on_tap(panel, func() -> void:
		WorldTickEngine.focus_news_key = e_key
		get_tree().change_scene_to_file("res://scenes/News/News.tscn"))
	return panel

