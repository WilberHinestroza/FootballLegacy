extends Control

## Comparte estado con PreMatch a través del Autoload MatchState
## (ver nota en MatchState.gd sobre por qué NO usamos parámetros de
## escena ni un patrón tipo hiltViewModel() por pantalla).

@onready var score_card: PanelContainer = $VBoxContainer/ScoreCard
@onready var score_label: Label = $VBoxContainer/ScoreCard/ScoreMargin/ScoreVBox/CrestRow/ScoreLabel
@onready var minute_label: Label = $VBoxContainer/ScoreCard/ScoreMargin/ScoreVBox/MinuteLabel
var _aggregate_score_label: Label = null
@onready var home_badge_holder: Control = $VBoxContainer/ScoreCard/ScoreMargin/ScoreVBox/CrestRow/HomeBadgeHolder
@onready var away_badge_holder: Control = $VBoxContainer/ScoreCard/ScoreMargin/ScoreVBox/CrestRow/AwayBadgeHolder
@onready var poss_home_bar: ColorRect = $VBoxContainer/ScoreCard/ScoreMargin/ScoreVBox/PossRow/PossHomeBar
@onready var poss_away_bar: ColorRect = $VBoxContainer/ScoreCard/ScoreMargin/ScoreVBox/PossRow/PossAwayBar
@onready var poss_label: Label = $VBoxContainer/ScoreCard/ScoreMargin/ScoreVBox/PossLabel
@onready var rating_big: Label = $BottomBar/BottomMargin/BottomRow/RatingBox/RatingBig
@onready var goals_label: Label = $BottomBar/BottomMargin/BottomRow/GoalsLabel
@onready var energy_button: Button = $BottomBar/BottomMargin/BottomRow/EnergyButton
@onready var bottom_bar: PanelContainer = $BottomBar
@onready var event_log: RichTextLabel = $VBoxContainer/EventLog
@onready var decision_panel: PanelContainer = $DecisionPanel
@onready var decision_title: Label = $DecisionPanel/Margin/VBox/DecisionTitle
@onready var choice_box: VBoxContainer = $DecisionPanel/Margin/VBox/ChoiceBox
@onready var meter_area: VBoxContainer = $DecisionPanel/Margin/VBox/MeterArea
@onready var power_meter_bg: Control = $DecisionPanel/Margin/VBox/MeterArea/PowerMeterBg
@onready var power_meter_fill: ColorRect = $DecisionPanel/Margin/VBox/MeterArea/PowerMeterBg/PowerMeterFill
@onready var target_zone: ColorRect = $DecisionPanel/Margin/VBox/MeterArea/PowerMeterBg/TargetZone
@onready var tap_button: Button = $DecisionPanel/Margin/VBox/MeterArea/TapButton
@onready var halftime_panel: Control = $HalftimePanel
@onready var halftime_score_label: Label = $HalftimePanel/VBox/HalftimeScoreLabel
@onready var continue_second_half_button: Button = $HalftimePanel/VBox/ContinueSecondHalfButton

## Chip de estado del usuario (en cancha / en el banco) + botón para pedir
## entrar o pedir el cambio — armado en código, se inserta bajo el marcador.
var _status_chip: PanelContainer = null
var _status_label: Label = null
var _status_button: Button = null


## Acción elegida en el menú de decisión (kind del engine). "" hasta que
## el usuario toca una de las opciones.
var _chosen_kind: String = ""

## Cancha 2D (Paquete 1 del ROADMAP, ver ui/match/PitchView.gd +
## PitchPlays.gd): muestra la jugada armada en cada momento clave, después
## CÓMO TERMINA tu acción, y los goles del rival con su jugada. Mientras se
## ve la repetición, los eventos del motor que llegan (GOAL /
## DECISION_RESULT) se RETIENEN y se procesan al terminar, así la
## celebración o el popup de resultado salen DESPUÉS de ver la jugada (el
## motor ya está en pausa esperando el ack de esos eventos).
var _pitch: PitchView = null
var _stadium_variant: String = "day"
var _stadium_bg: Control = null
var _pitch_ctx: Dictionary = {}
var _pitch_kind: String = ""
var _replay_pending: bool = false   # decisión resuelta, esperando su DECISION_RESULT
var _replaying: bool = false
var _held_events: Array = []
## Escenas "de paso" (pitazos, cobro de penal): NO pausan el partido.
## Cada una se apaga sola salvo que la cancha ya la esté usando otra cosa.
var _pitch_owner: String = ""        # "decision" | "replay" | "flash"
var _pitch_flash_token: int = 0
var _last_penalty_minute: int = -1   # para mostrar un gol de penal de la IA como penal

const MOVE_SPEED := 1.4 # ciclos completos por segundo, ajustable por dificultad

## Narración ambiental (kind del engine -> frases). Adaptado del prototipo
## de Football Legacy: el motor solo decide SI algo pasa, el texto vive
## aquí, igual que con cualquier otro MatchEvent. Parte 91i (pedido de
## Wilber: "narración enriquecida e inmersiva"): cada kind pasó de UNA
## frase fija a 2-3 variantes (elegidas por hash del minuto — determinista,
## nunca la misma dos minutos seguidos por casualidad) + 6 kinds nuevos.
const AMBIENT_TEMPLATES := {
	"possession_home": ["Tu equipo domina la posesión en este tramo.", "Buena circulación de pelota, manejás el ritmo del partido."],
	"possession_away": ["El rival empieza a manejar más el balón.", "El equipo contrario toma las riendas de la posesión."],
	"midfield_battle": ["Partido trabado en el mediocampo.", "Se pelea cada pelota dividida en la mitad de la cancha."],
	"foul": ["Falta cometida. Se reanuda el juego.", "El árbitro corta el juego por una infracción."],
	"referee_advantage": ["El árbitro deja seguir una jugada dudosa.", "Ley de la ventaja: el juez no corta el juego."],
	"tempo_change": ["Cambio de ritmo: ambos equipos buscan el área rival.", "El partido se abre, ida y vuelta constante."],
	"buildup_home": ["Tu equipo intenta salir jugando desde el fondo.", "Se arma la jugada desde atrás, con paciencia."],
	"buildup_away": ["El rival busca sorprender con un balón largo.", "El equipo contrario intenta un pelotazo directo."],
	"crowd_support": ["El público anima en este pasaje del juego.", "La hinchada se hace sentir desde las tribunas."],
	"corner_no_danger": ["Saque de esquina sin consecuencias.", "El córner se despeja sin sobresaltos."],
	"coach_instructions": ["El entrenador da indicaciones desde la banda.", "El DT grita instrucciones desde el borde del campo."],
	"short_passing_home": ["Tu equipo encadena varios pases cortos.", "Toque y toque: se mueve bien la pelota en corto."],
	"transition_away": ["El rival recupera y sale rápido en transición.", "Contragolpe rival tras una pérdida rápida."],
	"through_ball_intercepted": ["Pase filtrado que la defensa corta a tiempo.", "Buena lectura defensiva: cortan el pase entre líneas."],
	"wing_play": ["Triangulación por la banda sin opciones claras.", "Juego por afuera que no encuentra el desborde."],
	"goalkeeper_calm": ["El portero maneja el balón con calma.", "El arquero controla los tiempos con la pelota en los pies."],
	"switch_play": ["Cambio de juego con un pase largo a la otra banda.", "Diagonal larga que estira la cancha de lado a lado."],
	"good_control": ["Buen control y pase en el círculo central.", "Recibe de espaldas y la da bien, sin complicarse."],
	"pass_intercepted": ["Pase entre líneas que la defensa intercepta.", "La defensa lee bien y corta el pase."],
	"patient_possession": ["Posesión paciente buscando un hueco.", "El equipo no se apura, espera el espacio."],
	"teammate_substitution": ["Tu equipo mueve el banco con un cambio.", "Cambio en tu equipo: entra sangre fresca."],
	"rival_substitution": ["Cambio en el equipo rival.", "El DT rival mueve piezas desde el banco."],
	"keeper_distribution": ["El arquero rival saca rápido, buscando la salida en corto.", "El portero contrario juega en corto con sus defensores."],
	"physical_battle": ["Partido de mucho roce, los cuerpo a cuerpo se sienten.", "Se juega fuerte: cada disputa termina con algún golpe."],
	"tactical_foul": ["Falta táctica para cortar un contragolpe naciente.", "Interrupción a propósito: cortan antes de que crezca el peligro."],
	"long_range_effort": ["Un jugador prueba desde lejos, sin puntería.", "Remate de media distancia que se pierde por el costado."],
	"keeper_save_routine": ["Atajada de rutina, sin sobresaltos.", "El arquero controla un remate sin complicaciones."],
	"bench_reaction": ["El banco de suplentes reacciona a una jugada.", "Se paran del banco para protestar una decisión del árbitro."],
}

## Variante determinista de una frase ambiental — mismo minuto+kind da
## SIEMPRE la misma variante (nunca un randf() suelto sin seed, mismo
## criterio de todo el proyecto), pero minutos distintos varían.
func _ambient_line(kind: String, minute: int) -> String:
	var options: Array = AMBIENT_TEMPLATES.get(kind, ["El juego sigue su curso."])
	if options.is_empty():
		return "El juego sigue su curso."
	var idx: int = absi(hash("%s:%d" % [kind, minute])) % options.size()
	return String(options[idx])

## Titular del popup de acierto/fallo de CADA acción (Parte 91i, pedido de
## Wilber: "narración enriquecida e inmersiva") — antes era un genérico
## "ACERTASTE"/"FALLASTE" para las ~24 acciones del partido, ahora cada
## una describe lo que pasó de verdad. Para las acciones de GOL directo
## (shot_on_goal, one_on_one, etc.) el "ok" nunca se llega a mostrar —
## el gol lo cuenta la celebración (ver el `if goal and ok: pass` de
## _on_event_emitted) — pero se completa igual por si ese camino cambia.
const _OUTCOME_FLAVOR := {
	"shot_on_goal": {"ok": "¡Adentro!", "fail": "Ataja el arquero"},
	"one_on_one": {"ok": "¡Se la picás!", "fail": "Te la achica"},
	"long_shot": {"ok": "¡Golazo de lejos!", "fail": "Se va desviado"},
	"free_kick": {"ok": "¡Barrera vencida!", "fail": "La tapa la barrera"},
	"penalty": {"ok": "¡Gol de penal!", "fail": "Ataja el penal"},
	"penalty_shootout": {"ok": "¡Gol en la tanda!", "fail": "Atajado"},
	"penalty_save": {"ok": "¡Atajaste el penal!", "fail": "Te la clavaron"},
	"penalty_save_shootout": {"ok": "¡Atajaste en la tanda!", "fail": "Gol del rival"},
	"volley": {"ok": "¡Volea perfecta!", "fail": "Le pegás mal"},
	"chip_shot": {"ok": "¡Globito perfecto!", "fail": "Llega el arquero"},
	"key_pass": {"ok": "Pase preciso", "fail": "Lo cortan"},
	"through_ball": {"ok": "¡Rompe la línea!", "fail": "Lo cortan a tiempo"},
	"dribble": {"ok": "Lo superás", "fail": "Te quitan la pelota"},
	"aerial_duel": {"ok": "Ganás el salto", "fail": "Se queda con ella"},
	"pressing": {"ok": "¡Se la robás!", "fail": "No llegás a tiempo"},
	"cutback": {"ok": "Pase atrás preciso", "fail": "La defensa corta"},
	"cross": {"ok": "Centro medido", "fail": "Se pasea sin destino"},
	"one_two": {"ok": "¡Pared perfecta!", "fail": "Se pierde el pase"},
	"counter_run": {"ok": "¡Ganás el espacio!", "fail": "Te alcanzan"},
	"switch_play": {"ok": "Cambio preciso", "fail": "Se va afuera"},
	"distribution": {"ok": "Salida limpia", "fail": "Te presionan y la pierden"},
	"tackle": {"ok": "¡Se la robás!", "fail": "Te gambetea"},
	"interception": {"ok": "¡Anticipás!", "fail": "No llegás"},
	"clearance": {"ok": "Despeje limpio", "fail": "Sale mal el despeje"},
	"last_ditch_tackle": {"ok": "¡Entrada salvadora!", "fail": "Llegás tarde"},
	"recovery_tackle": {"ok": "¡Recuperás al toque!", "fail": "Se escapa en contra"},
	"block_shot": {"ok": "¡Tapás el remate!", "fail": "No llegás"},
	"one_on_one_save": {"ok": "¡Achicás y salvás!", "fail": "Te gana el duelo"},
	"sweep_keeper": {"ok": "¡Salís a tiempo!", "fail": "Te gana la carrera"},
}

## Título del flash de resultado para `kind` — cae a "ACERTASTE"/"FALLASTE"
## si un kind no está en el diccionario (nunca debería pasar con el
## repertorio actual, pero sin esto un kind nuevo futuro rompería la UI).
func _outcome_title(kind: String, ok: bool) -> String:
	var flavor: Dictionary = _OUTCOME_FLAVOR.get(kind, {})
	return String(flavor.get("ok" if ok else "fail", "ACERTASTE" if ok else "FALLASTE"))

var _meter_value: float = 0.0 # 0.0 a 1.0
var _meter_direction: int = 1
var _meter_running: bool = false

## Minijuego activo para la decisión en curso: "meter" (barra clásica),
## "aim" (colocás + timing → definición/penal/tiro libre), "rhythm"
## (3 taps al ritmo → regate), "hold" (mantené y soltá → presión/despeje),
## "reaction" (reflejo puro, sin barra — Parte 91i), "sequence" (tocar el
## botón que se ilumina, 3 rondas — Parte 91i).
var _minigame: String = "meter"
var _aim_zone: int = -1          # 0/1/2 = izq/centro/der elegida
const PANENKA_ZONE := 9          # "zona" especial: definición picada al medio
var _aim_tap_ms: int = 0         # cuánto tardaste en elegir (telegrafiar)
var _aim_kind: String = ""       # kind del minijuego de apuntar en curso (el penal no pasa por _chosen_kind)
const _PENALTY_KINDS := ["penalty", "penalty_shootout"]
const _PITCH_SHOT_KINDS := ["shot_on_goal", "one_on_one", "long_shot", "volley", "chip_shot", "free_kick"]
var _pitch_shot_band: float = 0.15
## Minijuegos interactivos en la cancha por tipo de jugada (PitchMinigame).
## Tiro libre, cabezazo y penal mantienen los suyos.
const _PITCH_MG_KINDS := {
	"pass": ["key_pass", "through_ball", "cutback", "cross", "one_two", "switch_play", "distribution"],
	"dribble": ["dribble", "counter_run"],
	"defend": ["pressing", "tackle", "interception", "clearance", "last_ditch_tackle", "recovery_tackle", "block_shot"],
	"keeper": ["one_on_one_save"],
	"sweep": ["sweep_keeper"],
}
var _aim_shown_at: int = 0
var _rhythm_hits: float = 0.0
var _rhythm_round: int = 0
const _RHYTHM_ROUNDS := 3
var _hold_active: bool = false
var _hold_value: float = 0.0
var _hold_target: float = 0.7
var _hold_secs: float = 1.1          # segundos para cargar de 0 a 1
var _live_stamina: float = 100.0     # estamina en vivo (MINUTE_TICK), para la presión del gesto

## --- Reflejo (Parte 91i): esperás una señal impredecible y tocás lo más
## rápido posible — tocar ANTES de la señal es un adelanto (falla directo).
## Nada de barra: la precisión sale del tiempo de reacción real, no de
## acertar una zona. `_reaction_token` invalida cualquier timer de espera
## que quede pendiente si la decisión ya se resolvió por otro lado.
var _reaction_state: String = "waiting"   # "waiting" (tocar ahora = falla) | "go" (armado)
var _reaction_go_at_ms: int = 0
var _reaction_token: int = 0

## --- Secuencia (Parte 91i): 3 botones, se ilumina UNO a la vez en orden
## al azar con una ventana chica — tocás el que está iluminado antes de
## que se apague. 3 rondas, el promedio de aciertos (0 si te la perdés o
## tocás el equivocado) es la precisión final.
var _sequence_round: int = 0
const _SEQUENCE_ROUNDS := 3
var _sequence_hits: float = 0.0
var _sequence_active_idx: int = -1
var _sequence_lit_at_ms: int = 0
const _SEQUENCE_WINDOW_MS := 850
var _sequence_token: int = 0
var _target_center: float = 0.5
var _target_width: float = 0.18
var _user_goals: int = 0

## Dificultad 0..1 del minijuego de la decisión en curso (la manda el engine
## en cada opción: DecisionResolver.difficulty, según skill del jugador +
## rasgos equipados + rival). Dimensiona ancho de zona y velocidad de la
## barra. La UI ya NO decide acierto/fallo: clavar la zona = conseguido.
var _chosen_difficulty: float = 0.45
var _opts_by_kind: Dictionary = {}

## Velocidad del marcador que barre la barra — se fija al arrancar el
## partido según la diferencia de nivel entre tu equipo y el rival: si sos
## mucho más flojo, barre más rápido (más difícil clavar la zona); si sos
## más fuerte, va más lento. Rango ~0.9x a ~1.8x de MOVE_SPEED.
var _meter_speed: float = MOVE_SPEED

## Popup central de evento (gol / cambio / tarjeta / lesión) — pedido
## explícito: 2-3 s en el medio de la pantalla, del color del equipo al
## que le pasa. Se arma en código para no tocar el .tscn.
var _popup_panel: PanelContainer = null
var _popup_label: Label = null
var _popup_sub_label: Label = null
var _popup_icon: CenterContainer = null

## Balón elegido en la previa (índice en BallDesign) — cae al determinista
## del partido si no se eligió.
func _match_ball_idx() -> int:
	if MatchState.ball_design >= 0:
		return MatchState.ball_design
	return BallDesign.default_for("%s|%s" % [
		String(MatchState.fixture.get("home_club_id", "")), String(MatchState.fixture.get("away_club_id", "")),
	])
var _popup_time_left: float = 0.0   # cuenta atrás en _process; > 0 = visible
# Bug real reportado por Wilber: "el popup de si acerté o no también debería
# parar el tiempo para evitar que se superpongan situaciones" — antes
# el motor NUNCA esperaba a que este popup se fuera (a diferencia de
# tarjeta/lesión/gol, que ya pausaban de verdad), así que podía
# arrancar un momento clave/evento NUEVO mientras el de ACERTASTE/
# FALLASTE seguía en pantalla. Se marca acá SOLO cuando _flash_result()
# lo muestra (no en el resto de usos de _flash_popup, como "Energizante",
# que no tienen nada esperando del lado del motor) y se avisa al motor
# (MatchState.engine.notify_event_ack) cuando el propio timer de
# siempre (POPUP_SECONDS) lo cierra — sigue sin hacer falta tocarlo,
# solo ahora el motor de verdad espera esos ~2.6s en vez de seguir de largo.
var _popup_awaits_engine_ack: bool = false

## Tarjeta de cambio (pedido de Wilber): en vez del popup central, un
## panel compacto que baja desde arriba con ▼ rojo (sale) y ▲ verde
## (entra) + nombres. No tapa el juego.
## Cartel de evento (cambio / amarilla / roja / lesión): panel que baja
## Popup CENTRAL de evento (tarjeta / lesión / cambio / gol rival): aparece
## en el medio, oscurece el fondo y el motor SE PAUSA hasta que se cierra
## (toque o cuenta atrás) — Match._ack_event -> engine.notify_event_ack.
## Pedido de Wilber: "que salgan en el centro y se pause el tiempo para
## que no se arme un caos de tantas cosas juntas".
var _ev_card: PanelContainer = null
var _ev_holder: CenterContainer = null
var _ev_scrim: ColorRect = null
var _ev_icon: CenterContainer = null
var _ev_lines: VBoxContainer = null
var _ev_min: Label = null
var _ev_time_left: float = 0.0
var _ev_awaiting_ack: bool = false
const EV_CARD_SECONDS := 3.4
var _home_color: Color = Color(0.2, 0.45, 0.75)
var _away_color: Color = Color(0.55, 0.16, 0.42)
const POPUP_SECONDS := 2.6

## Entretiempo enriquecido (pedido explícito): stats del partido, cómo van
## los otros partidos de la jornada y el consumible "Bebida energizante".
## Se arma en código sobre $HalftimePanel/VBox para no tocar el .tscn.
var _ht_body: VBoxContainer = null
var _ht_energy_used: bool = false
var _rng := RandomNumberGenerator.new()

## Barra de estamina en vivo (pedido de Wilber): saber si aguanto el
## partido. El valor llega en el payload de MINUTE_TICK (MatchEngine.stamina_pct)
## y es el mismo desgaste que ya baja la precisión de cada decisión.
var _stamina_wrap: Control = null
var _stamina_fill: ColorRect = null
var _stamina_label: Label = null
var _stamina_low_warned: bool = false

func _ready() -> void:
	if MatchState.engine == null:
		push_error("Match.gd: no hay MatchEngine activo en MatchState.")
		return

	_rng.randomize()
	_compute_meter_speed()
	_resolve_team_colors()
	_install_stadium_bg()
	_build_competition_header()

	# Cruce a doble partido: acarreo de la ida para que la prórroga/penales
	# se disparen por AGREGADO, y aviso del resultado de la ida.
	MatchState.apply_tie_aggregate()
	_show_first_leg_banner()
	Audio.music_stop()   # el partido tiene su propio ambiente
	Audio.crowd_start()
	Audio.match_sfx("kickoff")
	Haptics.hit("whistle")
	_apply_static_styles()
	_build_crests()
	_build_popup()
	_build_status_chip()
	_build_stamina_bar()
	_build_halftime_body()
	_build_pitch()
	_landscape_match()

	MatchState.engine.event_emitted.connect(_on_event_emitted)
	MatchState.engine.decision_requested.connect(_on_decision_requested)
	tap_button.pressed.connect(_on_tap_pressed)
	tap_button.button_down.connect(_on_tap_down)
	tap_button.button_up.connect(_on_tap_up)
	continue_second_half_button.pressed.connect(_on_continue_second_half_pressed)
	energy_button.pressed.connect(_on_energy_button_pressed)
	decision_panel.visible = false
	halftime_panel.visible = false
	_refresh_live_stats()
	_refresh_status_chip()
	_refresh_possession()
	_refresh_energy_button()
	UiScroll.make_touch(self)

	await _pre_kickoff_show()
	var result: Dictionary = await MatchState.engine.run_match()
	MatchState.match_result = result
	MatchState.last_user_rating = float(result.get("user_rating", MatchRatingCalculator.BASE_RATING))
	_on_match_finished(result)

## Fondo de estadio PROCEDURAL (StadiumBg): gradas + multitud animada +
## focos + vallas publicitarias + césped, todo generado y teñido con los
## colores de los dos equipos. Va encima del ColorRect `Bg` (respaldo
## sólido) y por debajo del HUD.
func _install_stadium_bg() -> void:
	var seed_int: int = hash("%s|%s" % [
		String(MatchState.fixture.get("home_club_id", "")), String(MatchState.fixture.get("away_club_id", "")),
	]) ^ SaveManager.load_world_seed()
	var wx: String = MatchIcons.weather_for(MatchState.fixture, SaveManager.load_world_seed())
	_stadium_variant = StadiumBg.variant_for(wx, seed_int)
	var bg := StadiumBg.build(_home_color, _away_color, seed_int, _stadium_variant)
	_stadium_bg = bg
	add_child(bg)
	move_child(bg, 1)

## "Mosca" de la televisora arriba del marcador (P1b, 9-oct: logos de las
## televisoras): logo + nombre del canal ficticio + EN VIVO. El canal sale
## determinista por partido (mismo partido = mismo canal).
func _add_tv_bug() -> void:
	var vb := score_card.get_node_or_null("ScoreMargin/ScoreVBox")
	if vb == null or vb.has_node("TvBug"):
		return
	var outlets: Array = MediaOutlets.OUTLETS.filter(func(o): return String(o["id"]) in MediaOutlets.TV_CHANNELS)
	var key: String = "%s|%s" % [String(MatchState.fixture.get("home_club_id", "")), String(MatchState.fixture.get("away_club_id", ""))]
	var o: Dictionary = outlets[absi(hash(key)) % outlets.size()]
	var row := HBoxContainer.new()
	row.name = "TvBug"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lg := MediaOutlets.logo(String(o["name"]), 20)
	lg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lg)
	var l := Label.new()
	l.text = String(o["name"])
	l.add_theme_font_override("font", Styles.font_black())
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(String(o["color"])).lightened(0.25))
	row.add_child(l)
	var live := Label.new()
	live.text = "● EN VIVO"
	live.add_theme_font_size_override("font_size", 10)
	live.add_theme_color_override("font_color", Styles.RED)
	row.add_child(live)
	vb.add_child(row)
	vb.move_child(row, 0)
	_apply_broadcast_style(String(o["id"]))
	# El punto rojo late como en la tele.
	var tw := live.create_tween().set_loops()
	tw.tween_property(live, "modulate:a", 0.35, 0.6)
	tw.tween_property(live, "modulate:a", 1.0, 0.6)

## Marcador con la GRÁFICA DEL CANAL (10-oct): fondo y borde de acento
## propios, curvatura distinta, y el resultado sobre una placa del canal
## (blanca en GOLAZO, azul en DEPORTE TOTAL, verde oscuro en ESTADIO 24,
## vidrio claro en CANCHA+). La franja del torneo va aparte
## (_build_competition_header) — así canal y torneo se combinan.
func _apply_broadcast_style(channel_id: String) -> void:
	var st: Dictionary = MediaOutlets.BROADCAST.get(channel_id, {})
	if st.is_empty():
		return
	var acc := Color(String(st["accent"]))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Color(String(st["bg"])), 0.94)
	sb.set_corner_radius_all(int(st["radius"]))
	match String(st["edge"]):
		"top": sb.border_width_top = 4
		"bottom": sb.border_width_bottom = 4
		"left": sb.border_width_left = 6
	sb.border_color = acc
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	score_card.add_theme_stylebox_override("panel", sb)
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(String(st["plate"]))
	plate.set_corner_radius_all(maxi(2, int(st["radius"]) / 2))
	plate.content_margin_left = 12
	plate.content_margin_right = 12
	plate.content_margin_top = 0
	plate.content_margin_bottom = 2
	# Misma forma de placa que el marcador 3D (match_hud.gd) de cada canal.
	match channel_id:
		"golazo_tv":
			plate.skew = Vector2(0.3, 0.0)
			plate.content_margin_left = 18
			plate.content_margin_right = 18
		"deporte_total":
			plate.set_corner_radius_all(20)
			plate.shadow_color = Color(acc, 0.55)
			plate.shadow_size = 6
		"estadio_24":
			plate.set_corner_radius_all(0)
			plate.border_color = acc
			plate.set_border_width_all(2)
		"cancha_mas":
			plate.border_color = Color(1, 1, 1, 0.9)
			plate.border_width_bottom = 3
	score_label.add_theme_stylebox_override("normal", plate)
	score_label.add_theme_color_override("font_color", Color(String(st["ink"])))
	minute_label.add_theme_color_override("font_color", acc.lightened(0.35))

func _apply_static_styles() -> void:
	score_card.add_theme_stylebox_override("panel", Styles.card(Styles.CARD_DARK, 16))
	_add_tv_bug()
	Styles.apply_display_font(score_label)
	minute_label.add_theme_color_override("font_color", Styles.GOLD)
	minute_label.add_theme_font_override("font", Styles.font_semibold())
	poss_label.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	rating_big.add_theme_font_override("font", Styles.font_black())
	goals_label.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	var bstyle := Styles.card_flat(Color(0.10, 0.11, 0.13), 14)
	bstyle.border_width_top = 2
	bstyle.border_color = Styles.GOLD
	bstyle.shadow_color = Color(0, 0, 0, 0.4)
	bstyle.shadow_size = 8
	bottom_bar.add_theme_stylebox_override("panel", bstyle)
	Styles.styled_button(energy_button, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
	# Panel de narración semi-transparente: se ve algo del estadio de fondo
	# (pedido de Wilber) pero con suficiente cuerpo para que el texto no se
	# mezcle con la multitud/jugadores del StadiumBg (antes 0.42 → se
	# "superponían" los colores del fondo con el log).
	event_log.add_theme_stylebox_override("normal", Styles.card(Color(0.05, 0.06, 0.09, 0.66), 12))
	decision_panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD, Color(0.11, 0.12, 0.15), 18))
	Styles.styled_button(tap_button, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	Styles.styled_button(continue_second_half_button, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	power_meter_bg.add_theme_stylebox_override("panel", Styles.card(Color(0.05, 0.05, 0.06), 8))
	poss_home_bar.color = _home_color
	poss_away_bar.color = _away_color

## Insignias de los dos clubes en el marcador (estilo prototipo). Se arman
## con Styles.build_club_badge, mismo helper que el resto del juego.
func _build_crests() -> void:
	var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	var home := WorldFactory.find_club(world, MatchState.fixture.get("home_club_id", ""))
	var away := WorldFactory.find_club(world, MatchState.fixture.get("away_club_id", ""))
	_place_badge(home_badge_holder, home, _home_color, MatchState.kit_home_away, true)
	_place_badge(away_badge_holder, away, _away_color, MatchState.kit_away_away, false)

## Marcador: ESCUDO GRANDE en el borde exterior, camiseta pegada al número
## (pedido de Wilber). Home: [escudo ··· camiseta] | Away: [camiseta ··· escudo].
func _place_badge(holder: Control, club, fallback: Color, away_kit: bool, is_home: bool) -> void:
	for c in holder.get_children():
		c.queue_free()
	var col: Color = fallback
	if club != null and not club.primary_color_hex.is_empty():
		col = Color(club.primary_color_hex)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)

	# Escudo + iniciales del club DEBAJO (pedido de Wilber).
	var crest_col := VBoxContainer.new()
	crest_col.add_theme_constant_override("separation", 1)
	crest_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var crest: Control = Styles.club_crest(club.club_id, 58) if club != null else _side_crest(is_home, 58)
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	crest_col.add_child(crest)
	var abbr := Label.new()
	abbr.text = _club_initials(club) if club != null else _side_name(is_home).to_upper().substr(0, 3)
	abbr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abbr.add_theme_font_override("font", Styles.font_semibold())
	abbr.add_theme_font_size_override("font_size", 13)
	abbr.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	abbr.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	abbr.add_theme_constant_override("shadow_offset_y", 1)
	crest_col.add_child(abbr)
	var kit: Control = null
	if club != null:
		kit = Kit.build_for_club_kit(club, WorldTickEngine.get_season_start_year(), away_kit, 38)
		kit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var spring := Control.new()
	spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spring.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if is_home:
		row.add_child(crest_col)
		row.add_child(spring)
		if kit != null:
			row.add_child(kit)
	else:
		if kit != null:
			row.add_child(kit)
		row.add_child(spring)
		row.add_child(crest_col)
	holder.add_child(row)

## Iniciales del club para el marcador: usa short_name si lo hay, si no las
## iniciales de las primeras palabras del nombre.
func _club_initials(club) -> String:
	if club == null:
		return ""
	var sn: String = String(club.short_name) if "short_name" in club else ""
	if sn.strip_edges() != "":
		return sn.strip_edges().to_upper().substr(0, 4)
	var parts: PackedStringArray = String(club.club_name).split(" ", false)
	var out := ""
	for p in parts:
		if p.length() > 0:
			out += p.substr(0, 1)
		if out.length() >= 3:
			break
	return out.to_upper()

## Barra de estamina: se arma en código sobre el ScoreVBox del marcador,
## justo debajo de la etiqueta de posesión, para no tocar el .tscn.
func _build_stamina_bar() -> void:
	var vbox := poss_label.get_parent()
	if vbox == null:
		return
	var wrap := VBoxContainer.new()
	wrap.name = "StaminaWrap"
	wrap.add_theme_constant_override("separation", 2)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var head := HBoxContainer.new()
	var cap := Label.new()
	cap.text = "ESTAMINA"
	cap.add_theme_font_size_override("font_size", 10)
	cap.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := Label.new()
	val.name = "Val"
	val.text = "100%"
	val.add_theme_font_size_override("font_size", 10)
	val.add_theme_color_override("font_color", Styles.GREEN)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(cap)
	head.add_child(val)
	wrap.add_child(head)

	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.08)
	track.custom_minimum_size = Vector2(0, 7)
	track.clip_contents = true
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = Styles.GREEN
	fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fill.anchor_bottom = 1.0
	fill.anchor_right = 1.0
	track.add_child(fill)
	wrap.add_child(track)

	vbox.add_child(wrap)
	_stamina_wrap = wrap
	_stamina_fill = fill
	_stamina_label = val

func _refresh_stamina(pct: float) -> void:
	_live_stamina = pct
	if _stamina_fill == null:
		return
	var f: float = clampf(pct / 100.0, 0.0, 1.0)
	var col: Color = Styles.GREEN
	if pct < 32.0:
		col = Color(0.90, 0.25, 0.22)
	elif pct < 55.0:
		col = Styles.GOLD
	_stamina_fill.anchor_right = f
	_stamina_fill.color = col
	if _stamina_label != null:
		_stamina_label.text = "%d%%" % int(round(pct))
		_stamina_label.add_theme_color_override("font_color", col)
	# Aviso único cuando cae en zona roja: sugiere el energizante si lo hay.
	if pct < 32.0 and not _stamina_low_warned:
		_stamina_low_warned = true
		var player: PlayerData = MatchState.user_player
		var has_drink: bool = player != null and int(player.consumables.get("energy_drink", 0)) > 0 and not _ht_energy_used
		if has_drink:
			event_log.append_text("[color=orange]Te estás quedando sin fuelle — te queda un energizante en el banco.[/color]\n")
			_pulse_energy_button()
		else:
			event_log.append_text("[color=orange]Te estás quedando sin fuelle: tus toques van a salir peor.[/color]\n")
	elif pct >= 45.0:
		_stamina_low_warned = false

func _pulse_energy_button() -> void:
	if not energy_button.visible:
		return
	var tw := create_tween().set_loops(3)
	tw.tween_property(energy_button, "modulate", Color(1.4, 1.2, 0.4), 0.3)
	tw.tween_property(energy_button, "modulate", Color.WHITE, 0.3)

func _refresh_possession() -> void:
	if MatchState.engine == null:
		return
	var st: Dictionary = MatchState.engine.get_match_stats()
	var ph: int = int(st.get("possession_home", 50))
	poss_home_bar.size_flags_stretch_ratio = maxf(float(ph), 1.0)
	poss_away_bar.size_flags_stretch_ratio = maxf(float(100 - ph), 1.0)
	poss_label.text = "Posesión %d%% - %d%%" % [ph, 100 - ph]
	if _pitch != null:
		_pitch.ambient_possession = (float(ph) if _user_side_is(true) else float(100 - ph)) / 100.0

func _refresh_energy_button() -> void:
	var player: PlayerData = MatchState.user_player
	var has_it: bool = player != null and int(player.consumables.get("energy_drink", 0)) > 0
	energy_button.visible = has_it and not _ht_energy_used
	if energy_button.visible:
		energy_button.text = "Energizante x%d" % int(player.consumables.get("energy_drink", 0))

func _on_energy_button_pressed() -> void:
	var player: PlayerData = MatchState.user_player
	if player == null:
		return
	var res: Dictionary = ShopEngine.use_halftime(player)
	if not res.get("ok", false):
		return
	_ht_energy_used = true
	if MatchState.engine != null:
		MatchState.engine.set_fatigue_relief(float(res.get("relief", 0.0)))
	SaveManager.save_player(player)
	event_log.append_text("[color=gold]Bebés el energizante: menos desgaste el resto del partido.[/color]\n")
	_flash_popup("Energizante", "menos fatiga", null)
	_refresh_energy_button()

## Diferencia de nivel tu-equipo vs rival -> velocidad del marcador.
func _compute_meter_speed() -> void:
	var home_t: MatchTeam = MatchState.home_team
	var away_t: MatchTeam = MatchState.away_team
	if home_t == null or away_t == null:
		_meter_speed = MOVE_SPEED
		return
	var user_home: bool = MatchState.user_player != null and (
		home_t.starting_xi.has(MatchState.user_player) or home_t.bench.has(MatchState.user_player))
	var mine: float = MatchEngine._team_strength(home_t if user_home else away_t)
	var rival: float = MatchEngine._team_strength(away_t if user_home else home_t)
	# +20 de diff a favor -> 0.9x ; -20 en contra -> 1.8x
	var t: float = clampf((rival - mine) / 20.0, -1.0, 1.0)
	_meter_speed = MOVE_SPEED * lerp(0.9, 1.8, (t + 1.0) * 0.5)

func _process(delta: float) -> void:
	if _popup_time_left > 0.0:
		_popup_time_left -= delta
		if _popup_time_left <= 0.0 and _popup_panel != null:
			_popup_panel.visible = false
			if _popup_awaits_engine_ack:
				_popup_awaits_engine_ack = false
				if MatchState.engine != null and MatchState.engine.has_method("notify_event_ack"):
					MatchState.engine.notify_event_ack()
	if _ev_time_left > 0.0:
		_ev_time_left -= delta
		if _ev_time_left <= 0.0:
			_ack_event()
	if _hold_active:
		_hold_value = clampf(_hold_value + delta / maxf(_hold_secs, 0.2), 0.0, 1.0)
		_update_hold_visual()
		return
	if not _meter_running:
		return
	_meter_value += _meter_direction * _meter_speed * delta
	if _meter_value >= 1.0:
		_meter_value = 1.0
		_meter_direction = -1
	elif _meter_value <= 0.0:
		_meter_value = 0.0
		_meter_direction = 1
	_position_target_zone() # el ancho real del panel llega tras el layout
	_update_power_meter_visual()

## Vibración por evento — independiente del sonido (se apaga aparte en
## Ajustes). Un solo lugar para no ensuciar el handler.
func _haptic_for_event(event: MatchEvent) -> void:
	match event.type:
		MatchEvent.Type.GOAL:
			if event.payload.get("scored_by_user", false) or event.payload.get("assist_by_user", false):
				Haptics.hit("goal")
			else:
				Haptics.hit("goal_against")
		MatchEvent.Type.CARD_YELLOW:
			Haptics.hit("card_yellow")
		MatchEvent.Type.CARD_RED:
			Haptics.hit("card_red")
		MatchEvent.Type.INJURY:
			Haptics.hit("injury")
		MatchEvent.Type.SUBSTITUTION:
			Haptics.hit("sub")
		MatchEvent.Type.DECISION_RESULT:
			Haptics.hit("success" if event.payload.get("success", false) else "fail")
		MatchEvent.Type.HALFTIME, MatchEvent.Type.FULLTIME:
			Haptics.hit("whistle")
		MatchEvent.Type.PENALTY_AWARDED:
			Haptics.hit("big")

func _on_event_emitted(event: MatchEvent) -> void:
	if _replaying:
		_held_events.append(event)
		return
	if _replay_pending:
		match event.type:
			MatchEvent.Type.DECISION_RESULT:
				_held_events.append(event)
				_replay_pending = false
				_play_decision_replay(event)
				return
			MatchEvent.Type.MINUTE_TICK, MatchEvent.Type.HALFTIME, MatchEvent.Type.FULLTIME:
				# El motor siguió sin mandar resultado (no debería pasar) —
				# soltar lo retenido para no trabar nada.
				_replay_pending = false
				_flush_held_events()
			_:
				# Bug real del Paquete 1 (9-oct): antes CUALQUIER evento que
				# no fuera GOAL cancelaba la repetición — y una decisión puede
				# emitir una tarjeta (quite fallado = amarilla para vos) ANTES
				# de su DECISION_RESULT. Ahora se retiene todo lo que nazca de
				# la misma jugada y se suelta después de verla.
				_held_events.append(event)
				return
	# Mientras estás jugando una jugada, nada le saca la cancha (10-oct).
	if event.type == MatchEvent.Type.GOAL and _ambient_goal_side(event) != "" and _pitch_owner != "decision":
		_held_events.append(event)
		_play_ambient_goal_replay(event, _ambient_goal_side(event) == "team")
		return
	if (event.type == MatchEvent.Type.CARD_YELLOW or event.type == MatchEvent.Type.CARD_RED) and _pitch != null and _pitch_owner != "decision":
		_held_events.append(event)
		_play_card_replay(event)
		return
	if event.type == MatchEvent.Type.AMBIENT and String(event.payload.get("kind", "")) == "clear_chance" and _pitch != null and _pitch_owner != "decision":
		_held_events.append(event)
		_play_chance_replay(event)
		return
	if event.type == MatchEvent.Type.INJURY and _pitch != null and _pitch_owner != "decision":
		# La camilla entra a la cancha (11-oct); después sale el aviso de
		# siempre (igual que las tarjetas: el motor espera ese aviso).
		_held_events.append(event)
		_play_injury_replay(event)
		return
	if event.type == MatchEvent.Type.SUBSTITUTION and _pitch != null and _pitch_owner == "":
		_held_events.append(event)
		_play_sub_replay(event)
		return
	if event.type == MatchEvent.Type.PENALTY_SHOOTOUT and _pitch != null and event.payload.has("team") and not bool(event.payload.get("is_user", false)):
		_held_events.append(event)
		_play_shootout_kick(event)
		return
	if event.type == MatchEvent.Type.PENALTY_AWARDED and _pitch != null:
		_last_penalty_minute = event.minute
		_play_pitch_flash(PitchPlays.penalty_award_scene(_pitch_ctx, _user_side_is(event.payload.get("home", null))), 1.6)
	_dispatch_event(event)

func _dispatch_event(event: MatchEvent) -> void:
	_haptic_for_event(event)
	match event.type:
		MatchEvent.Type.MINUTE_TICK:
			minute_label.text = "%d'" % event.minute
			_refresh_live_stats() # nota en vivo, se actualiza al ritmo del partido
			_refresh_status_chip()
			_refresh_possession()
			_refresh_stamina(float(event.payload.get("stamina", 100.0)))
		MatchEvent.Type.DECISION_RESULT:
			var ok: bool = bool(event.payload.get("success", false))
			var d: float = float(event.payload.get("rating_delta", 0.0))
			var sub: String = "%s%.2f a tu nota" % ["+" if d >= 0.0 else "", d]
			if event.payload.get("goal", false) and ok:
				# El gol lo cuenta la CELEBRACIÓN (evento GOAL) — acá no
				# mostramos el popup viejo ni repetimos el sonido (pedido
				# de Wilber: "el popup viejo sale cuando meto gol y esa no
				# era la idea").
				pass
			else:
				# Sin popup de ACERTASTE/FALLASTE (9-oct, Wilber: "quitá los
				# popups de acierto o desacierto"): la jugada ya se ve en la
				# cancha 2D. Queda la línea en el registro + la nota que late
				# en verde/rojo, y el motor sigue al instante.
				var ttl: String = _outcome_title(String(event.payload.get("kind", "")), ok)
				event_log.append_text("[color=%s]%s (%s)[/color]\n" % ["#5fd068" if ok else "#ff6b6b", ttl, sub])
				_pulse_rating(ok)
				Audio.match_sfx("decision_ok" if ok else "decision_fail")
				_release_engine()
			_refresh_live_stats()
		MatchEvent.Type.GOAL:
			var scorer: String = String(event.payload.get("scorer_name", ""))
			var is_home_goal = event.payload.get("home", null)
			var mine_assist: bool = bool(event.payload.get("assist_by_user", false))
			if event.payload.get("scored_by_user", false):
				event_log.append_text("[color=gold]¡GOL TUYO! minuto %d[/color]\n" % event.minute)
				_user_goals += 1
				Audio.match_sfx("goal")
				_celebrate_user_goal(event.minute, is_home_goal, false)
			elif mine_assist:
				event_log.append_text("[color=gold]Gol de %s  ·  ¡ASISTENCIA TUYA!, minuto %d[/color]\n" % [scorer, event.minute])
				Audio.match_sfx("goal" if _user_side_is(is_home_goal) else "goal_against")
				_celebrate_user_goal(event.minute, is_home_goal, true, scorer)
			else:
				var line: String = "Gol de %s" % scorer if scorer != "" else "Gol"
				event_log.append_text("[color=gold]%s, minuto %d[/color]\n" % [line, event.minute])
				var against: bool = not _user_side_is(is_home_goal)
				# El DT en la banda reacciona (PixelLab, 9-oct): festeja el
				# gol de tu equipo, se agarra la cabeza con el del rival.
				_flash_event_card(_coach_anim("enojado" if against else "festeja"), [
					{"text": "GOL EN CONTRA" if against else "GOL", "color": Styles.RED if against else Styles.GOLD, "big": true},
					{"text": ("Gol de %s" % scorer) if scorer != "" else "Gol", "color": Color.WHITE},
				], event.minute, _card_side_tag(is_home_goal))
				Audio.match_sfx("goal" if not against else "goal_against")
			_refresh_score()
			_refresh_live_stats()
		MatchEvent.Type.GOAL_DISALLOWED:
			var dn: String = String(event.payload.get("scorer_name", ""))
			var d_home = event.payload.get("home", null)
			var ours_d: bool = _user_side_is(d_home)
			var reason: String = String(event.payload.get("reason", "revisión"))
			event_log.append_text("[color=#59e6ff]VAR: gol ANULADO%s por %s, minuto %d[/color]\n" % [(" a " + dn) if dn != "" else "", reason, event.minute])
			Haptics.hit("whistle")
			_flash_event_card(_coach_anim("enojado" if ours_d else "festeja"), [
				{"text": "GOL ANULADO", "color": Styles.RED if ours_d else Styles.GREEN, "big": true},
				{"text": "VAR · %s" % reason, "color": Color(0.35, 0.9, 1.0)},
				{"text": dn, "color": Color.WHITE},
			], event.minute, _card_side_tag(d_home))
			_refresh_live_stats()
		MatchEvent.Type.CARD_YELLOW:
			var yc_name: String = _ev_player_name(event, "Un jugador")
			event_log.append_text("🟨 Amarilla para %s, minuto %d\n" % [yc_name, event.minute])
			# Sin el popup del árbitro viejo (9-oct): la tarjeta la muestra
			# el árbitro pixel art en la repetición de la cancha.
			Audio.match_sfx("card_yellow")
			_release_engine()
		MatchEvent.Type.CARD_RED:
			var rc_name: String = _ev_player_name(event, "Un jugador")
			var dbl: bool = bool(event.payload.get("double_yellow", false))
			var rc_tag: String
			if event.payload.get("is_user", false):
				rc_tag = ("¡Segunda amarilla y a la calle, %s!" % rc_name) if dbl else ("¡Roja directa a %s! Te expulsan" % rc_name)
			else:
				rc_tag = "🟨🟨 %s ve la 2ª amarilla" % rc_name if dbl else "🟥 Roja para %s" % rc_name
			event_log.append_text("[color=red]%s, minuto %d[/color]\n" % [rc_tag, event.minute])
			Audio.match_sfx("card_red")
			_release_engine()
			_refresh_status_chip()
		MatchEvent.Type.INJURY:
			var inj_name: String = _ev_player_name(event, "Un jugador")
			var who_inj: String = "¡Te lesionás vos!" if event.payload.get("is_user", false) else "Lesión de %s" % inj_name
			event_log.append_text("[color=orange]%s, minuto %d[/color]\n" % [who_inj, event.minute])
			var cross := Label.new()
			cross.text = "✚"
			cross.add_theme_font_size_override("font_size", 30)
			cross.add_theme_color_override("font_color", Color(0.95, 0.45, 0.2))
			cross.custom_minimum_size = Vector2(40, 40)
			cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			# Lesión TUYA: tu jugador animado cayendo (PixelLab, 9-oct).
			# De otro: entra la camilla.
			var inj_icon: Control = _user_anim_icon("lesion", 68, false) if event.payload.get("is_user", false) else _stretcher_icon(cross)
			_flash_event_card(inj_icon, [
				{"text": "LESIÓN", "color": Color(0.95, 0.55, 0.3), "big": true},
				{"text": inj_name, "color": Color.WHITE},
			], event.minute, _card_side_tag(event.payload.get("home", null)))
			Audio.match_sfx("injury")
			_refresh_status_chip()
		MatchEvent.Type.SUBSTITUTION:
			if event.payload.get("is_user", false):
				if event.payload.get("entering", true):
					var came_out = event.payload.get("player_out", null)
					var out_nm: String = came_out.player_name if came_out != null else "un compañero"
					# Pedido de Wilber: "cuando entre que me diga en qué
					# posición voy a jugar" — MatchEngine ya manda el puesto
					# táctico real que heredás (no siempre tu posición de
					# oficio), se lo agregamos a la tarjeta y al registro.
					var in_pos: String = String(event.payload.get("position", ""))
					var pos_tag: String = " (%s)" % in_pos if in_pos != "" else ""
					event_log.append_text("[color=cyan]Entrás de cambio por %s%s, minuto %d[/color]\n" % [out_nm, pos_tag, event.minute])
					_flash_sub_card(out_nm, "%s (vos)%s" % [MatchState.user_player.player_name, pos_tag], event.minute, "Tu equipo")
				else:
					var rep = event.payload.get("player_in", null)
					var in_nm: String = rep.player_name if rep != null else "un compañero"
					# coach_pull=true: el DT te saca por rendimiento, no porque
					# lo pediste (pedido de Wilber: "si estoy jugando muy mal,
					# el técnico me puede cambiar del partido") — mensaje
					# distinto para no confundirlo con el cambio pedido.
					var by_coach: bool = bool(event.payload.get("coach_pull", false))
					var msg: String = "El DT te saca por rendimiento (%d'). Entra %s." % [event.minute, in_nm] if by_coach \
						else "Pediste el cambio y salís (%d'). Entra %s." % [event.minute, in_nm]
					event_log.append_text("[color=cyan]%s[/color]\n" % msg)
					# Si te saca el DT por rendimiento, el que aparece es él, enojado.
					_flash_sub_card("%s (vos)" % MatchState.user_player.player_name, in_nm, event.minute, "Tu equipo", _coach_anim("enojado") if by_coach else _user_anim_icon("cambio", 68, true))
				_refresh_status_chip()
			else:
				# Cambio de la IA: SOLO al registro, sin carta ni pausa (venían
				# de a 3-4 seguidos y "se acumulaban" tapando el log — Wilber).
				var out_p = event.payload.get("player_out", null)
				var in_p = event.payload.get("player_in", null)
				var out_nm2: String = out_p.player_name if out_p != null else ""
				var in_nm2: String = in_p.player_name if in_p != null else ""
				var side_tag: String = "Tu equipo" if _user_side_is(event.payload.get("home", null)) else "Rival"
				if out_nm2 != "" or in_nm2 != "":
					event_log.append_text("[color=cyan]Cambio (%s): sale %s, entra %s (%d')[/color]\n" % [side_tag, out_nm2, in_nm2, event.minute])
				else:
					event_log.append_text("[color=cyan]Cambio, minuto %d[/color]\n" % event.minute)
		MatchEvent.Type.PENALTY_AWARDED:
			if bool(event.payload.get("fouled_user", false)):
				event_log.append_text("[color=yellow]¡PENAL! Te bajaron dentro del área, minuto %d. Lo pateás vos.[/color]\n" % event.minute)
			else:
				event_log.append_text("[color=yellow]¡PENAL! minuto %d[/color]\n" % event.minute)
		MatchEvent.Type.EXTRA_TIME_START:
			var global_home: int = int(event.payload.get("home_total", 0))
			var global_away: int = int(event.payload.get("away_total", 0))
			event_log.append_text("[b]Global %d-%d · comienza la prórroga (2 × 15')[/b]\n" % [global_home, global_away])
		MatchEvent.Type.PENALTY_SHOOTOUT:
			_handle_shootout_event(event)
		MatchEvent.Type.KICKOFF:
			_match_live = true
			_play_pitch_flash(PitchPlays.whistle_scene("kickoff", _ctx_now()), 1.6)
			# (El tifo del clásico y la tribuna/familia ya se mostraron ANTES
			# del saque — ver _pre_kickoff_show.)
		MatchEvent.Type.HALFTIME:
			_match_live = false
			_halftime_with_whistle(event.payload)
		MatchEvent.Type.AMBIENT:
			if String(event.payload.get("kind", "")) == "clear_chance":
				var ch_ours: bool = _user_side_is(event.payload.get("home", null))
				event_log.append_text("[color=%s]%d' — %s[/color]\n" % ["#7fd6ff" if ch_ours else "#ffb38a", event.minute,
					"¡Ocasión clara de tu equipo! No entra." if ch_ours else "¡Ocasión clara del rival! Se salva tu equipo."])
				_release_engine()
			else:
				var akind: String = String(event.payload.get("kind", ""))
				var text: String = _ambient_line(akind, event.minute)
				event_log.append_text("[color=gray]%d' — %s[/color]\n" % [event.minute, text])
				# La cancha en vivo acompaña lo narrado (posesión, córner...).
				if _live_bridge != null:
					var aside: int = -1
					if akind.ends_with("_home"):
						aside = 0 if _user_side_is(true) else 1
					elif akind.ends_with("_away"):
						aside = 0 if _user_side_is(false) else 1
					_live_bridge.cue(akind, aside)
		MatchEvent.Type.FULLTIME:
			event_log.append_text("[b]Final del partido (%d')[/b]\n" % event.minute)
			_play_pitch_flash(PitchPlays.whistle_scene("full", _ctx_now()), 1.6)
		_:
			pass

## Selección nacional (Fases 2/5): el fixture usa home_country/away_country
## en vez de home_club_id/away_club_id (ver NationalTeamMatchLauncher.gd) —
## esta pantalla EN VIVO nunca se adaptó a ese caso (a diferencia del
## resumen post-partido, que ya tiene su propia escena, NationalMatchSummary).
## Bug real reportado por Wilber: "las pantallas de selección no son como
## las normales" / "las selecciones no necesitan escudos, con la bandera
## basta" — con home_club_id vacío, WorldFactory.find_club() siempre daba
## null, así que escudo/camiseta/nombre caían a un genérico en blanco en
## TODOS los puntos de esta pantalla que asumían club.
func _is_national_fixture() -> bool:
	return MatchState.fixture.has("home_country")

## Cabecera compacta arriba del marcador: competición + jornada/ronda ·
## estadio. Pedido de Wilber ("en los partidos, arriba del marcador que
## aparezca el nombre de la competición... y el estadio") — PreMatch ya
## tenía esto (_competition_header/_venue_row); Match (la pantalla EN
## VIVO) nunca lo mostraba, quedaba solo el marcador pelado.
func _build_competition_header() -> void:
	var comp_text: String = _competition_label_text()
	var stadium_text: String = ""
	if not _is_national_fixture():
		var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
		var home := WorldFactory.find_club(world, MatchState.fixture.get("home_club_id", ""))
		if home != null:
			stadium_text = Venue.stadium_name(home)
	if comp_text == "" and stadium_text == "":
		return
	# FRANJA DEL TORNEO (10-oct, Wilber: "cada torneo con un detalle de su
	# torneo para diferenciar marcadores"): trofeo del torneo + nombre sobre
	# una cinta de SU color; el estadio queda debajo, chico.
	var tcol: Color = _tourney_color()
	var ribbon := PanelContainer.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(tcol.darkened(0.55), 0.92)
	rsb.border_width_left = 3
	rsb.border_width_right = 3
	rsb.border_color = tcol
	rsb.set_corner_radius_all(6)
	rsb.content_margin_left = 8
	rsb.content_margin_right = 10
	rsb.content_margin_top = 1
	rsb.content_margin_bottom = 1
	ribbon.add_theme_stylebox_override("panel", rsb)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 6)
	var tro: Control = _tourney_trophy(22)
	if tro != null:
		tro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rrow.add_child(tro)
	var lbl := Label.new()
	lbl.text = comp_text.to_upper()
	lbl.add_theme_font_override("font", Styles.font_black())
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", tcol.lightened(0.45))
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rrow.add_child(lbl)
	ribbon.add_child(rrow)
	var parent: Node = minute_label.get_parent()
	parent.add_child(ribbon)
	parent.move_child(ribbon, 0)
	if stadium_text != "":
		var sl := Label.new()
		sl.text = "🏟 %s" % stadium_text
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		sl.add_theme_font_size_override("font_size", 10)
		parent.add_child(sl)
		parent.move_child(sl, 1)

## Color propio de cada torneo para la franja del marcador.
func _tourney_color() -> Color:
	var comp: String = String(MatchState.fixture.get("competition", "league"))
	if _is_national_fixture():
		match comp:
			"world_cup": return Color("#d4af37")
			"national_cup": return Color("#3fa7ff")
		return Color("#5bbf72")
	match comp:
		"cup": return Color("#e05252")
		"continental":
			match String(MatchState.fixture.get("cont_conf", "")):
				"UEFA": return Color("#4a6cff")
				"CONMEBOL": return Color("#e0b03a")
				"CONCACAF": return Color("#2bb3c0")
				"AFC": return Color("#e0603a")
				"CAF": return Color("#3fbf6a")
			return Color("#4a6cff")
		"supercup": return Color("#c0c6d0")
		"cwc": return Color("#d4af37")
		"friendly": return Color("#8a8f98")
	return Color("#e8c547")   # liga

## Trofeo chico del torneo (mismo criterio que MatchSummary).
func _tourney_trophy(px: int) -> Control:
	var comp: String = String(MatchState.fixture.get("competition", "league"))
	if _is_national_fixture():
		match comp:
			"world_cup": return Trophy.for_honor("mundial_seleccion", px)
			"national_cup":
				var cf: String = String(MatchState.fixture.get("confederation", ""))
				return Trophy.for_honor("natcup_%s" % cf if cf != "" else "copa_continental_seleccion", px)
		return Trophy.for_honor("mundial_seleccion", px)
	match comp:
		"friendly": return null
		"cwc": return Trophy.for_honor("mundial_clubes", px)
		"supercup":
			return Trophy.for_honor("supercopa_cont" if String(MatchState.fixture.get("supercup_kind", "domestic")) == "continental" else "supercopa", px)
		"continental":
			var conf: String = String(MatchState.fixture.get("cont_conf", ""))
			return Trophy.for_honor("cont_%s_%d" % [conf, int(MatchState.fixture.get("cont_tier", 1))] if conf != "" else "continental_cup", px)
	var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	var uc := WorldFactory.find_club(world, WorldTickEngine.user_club_id)
	if uc == null:
		return null
	if comp == "cup":
		var lg = world.get("league_by_id", {}).get(uc.league_id, null)
		return Trophy.for_title("dcup_%s" % String(lg.country), px) if lg != null else null
	return Trophy.for_title("league_%d" % uc.league_id, px)

func _competition_label_text() -> String:
	var comp: String = String(MatchState.fixture.get("competition", "league"))
	if _is_national_fixture():
		match comp:
			"world_cup": return "Mundial"
			"national_cup": return "Copa continental"
			_: return "Eliminatoria"
	var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	var user_club := WorldFactory.find_club(world, WorldTickEngine.user_club_id)
	var league: LeagueData = null
	if user_club != null:
		for lg in world.get("leagues", []):
			if lg.league_id == user_club.league_id:
				league = lg
				break
	match comp:
		"cup":
			var country: String = league.country if league != null else ""
			if country != "":
				return "%s — %s" % [CompetitionNames.domestic_cup(country), MatchState.fixture.get("round_name", "")]
			return String(MatchState.fixture.get("round_name", "Copa"))
		"friendly":
			return "Amistoso de pretemporada"
		"continental":
			var conf: String = String(MatchState.fixture.get("cont_conf", ""))
			var tier: int = int(MatchState.fixture.get("cont_tier", 1))
			return CompetitionNames.continental(conf, tier) if conf != "" else "Copa continental"
		"supercup":
			return String(MatchState.fixture.get("name", "Supercopa"))
		"cwc":
			return "Mundial de Clubes"
		_:
			if league != null:
				return "%s · J%d" % [league.league_name, int(MatchState.fixture.get("matchday", 0))]
			return "Liga"

## Nombre a mostrar de un lado: club o país según corresponda.
func _side_name(is_home: bool) -> String:
	if _is_national_fixture():
		return String(MatchState.fixture.get("home_country" if is_home else "away_country", "?"))
	var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	var club := WorldFactory.find_club(world, MatchState.fixture.get("home_club_id" if is_home else "away_club_id", ""))
	return club.club_name if club != null else "?"

## Insignia de un lado: la BANDERA si es un partido de selección (pedido
## de Wilber: no hace falta un escudo para un país), el escudo de club si no.
func _side_crest(is_home: bool, px: int) -> Control:
	if _is_national_fixture():
		var country: String = String(MatchState.fixture.get("home_country" if is_home else "away_country", ""))
		var flag: Control = CountryFlags.flag_rect(country, px)
		return flag if flag != null else Styles.build_club_badge(_home_color if is_home else _away_color, "", px)
	return Styles.club_crest(String(MatchState.fixture.get("home_club_id" if is_home else "away_club_id", "")), px)

func _resolve_team_colors() -> void:
	if _is_national_fixture():
		# Sin ClubData no hay primary_color_hex — CountryFlags.team_color()
		# deriva un color determinista del país (mismo criterio que el
		# resto del juego: nunca al azar de verdad) en vez de dejar el
		# celeste/violeta genérico fijo de _home_color/_away_color.
		_home_color = CountryFlags.team_color(String(MatchState.fixture.get("home_country", "")))
		_away_color = CountryFlags.team_color(String(MatchState.fixture.get("away_country", "")))
		return
	var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	var home := WorldFactory.find_club(world, MatchState.fixture.get("home_club_id", ""))
	var away := WorldFactory.find_club(world, MatchState.fixture.get("away_club_id", ""))
	if home != null and not home.primary_color_hex.is_empty():
		_home_color = Color(home.primary_color_hex)
	if away != null and not away.primary_color_hex.is_empty():
		_away_color = Color(away.primary_color_hex)

## Chip "en cancha / en el banco" + botón contextual para pedir entrar o
## pedir el cambio. Se inserta bajo el marcador (no toca el .tscn).
func _build_status_chip() -> void:
	_status_chip = PanelContainer.new()
	_status_chip.add_theme_stylebox_override("panel", Styles.card(Styles.CARD_DARK, 10))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	# Etiqueta arriba, botón DEBAJO a lo ancho — así ni el texto largo del
	# pendiente ensancha la pantalla ("se ancha") ni el botón queda
	# aplastado a cero ("muy pequeño"). Los dos bugs venían de meterlos en
	# un HBox y pelearse por el ancho.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	_status_button = Button.new()
	_status_button.custom_minimum_size = Vector2(0, 46)
	_status_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_button.focus_mode = Control.FOCUS_NONE
	_status_button.visible = false
	_status_button.pressed.connect(_on_status_button_pressed)
	col.add_child(_status_label)
	col.add_child(_status_button)
	m.add_child(col)
	_status_chip.add_child(m)
	var box: VBoxContainer = $VBoxContainer
	box.add_child(_status_chip)
	box.move_child(_status_chip, score_card.get_index() + 1)

func _refresh_status_chip() -> void:
	if _status_chip == null or MatchState.engine == null:
		return
	var st: String = MatchState.engine.user_status()
	var pending: String = MatchState.engine.user_request_pending()
	var text := ""
	match st:
		"en_cancha": text = "● En cancha"
		"banco": text = "● Ya fuiste sustituido" if MatchState.engine.user_done_for_match() else "● En el banco"
		"lesionado": text = "● Lesionado, fuera del partido"
		"expulsado": text = "● Expulsado"
		"no_convocado": text = "● No convocado · lo ves desde la tribuna"
	if pending == "pediste_entrar":
		text += "  ·  el DT tomó nota"
	elif pending == "pediste_salir":
		text += "  ·  pediste el cambio"
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", Styles.GREEN if st == "en_cancha" else Styles.GRAY_TEXT)

	if pending == "" and MatchState.engine.user_can_request_on():
		_status_button.text = "Pedir entrar"
		Styles.styled_button(_status_button, Styles.pill_outlined(Styles.GREEN), Styles.GREEN)
		_status_button.visible = true
	elif pending == "" and MatchState.engine.user_can_request_off():
		_status_button.text = "Pedir el cambio"
		Styles.styled_button(_status_button, Styles.pill_outlined(Styles.AMBER), Styles.AMBER)
		_status_button.visible = true
	else:
		_status_button.visible = false

func _on_status_button_pressed() -> void:
	if MatchState.engine == null:
		return
	if MatchState.engine.user_can_request_on():
		MatchState.engine.request_come_on()
	elif MatchState.engine.user_can_request_off():
		MatchState.engine.request_sub_off()
	_refresh_status_chip()

## Celebración de gol del usuario: confeti desde arriba + popup con una
## acción de festejo al azar + un "latido" de escala en el título.
## Cada celebración: [emoji grande, texto]. El emoji se muestra a lo
## grande en el popup del gol para que "se vean" distintas.
const _CELEBRATIONS := [
	["🙌", "Se lo dedica a la grada"], ["🚩", "Corre hacia la bandera de córner"],
	["😘", "Beso al escudo"], ["🧗", "Salta la publicidad para festejar"],
	["🫂", "Lo abraza todo el banquillo"], ["☝️", "Señala al cielo"],
	["🤫", "Manda callar al rival de visitante"], ["🧎", "Rodilla al suelo y brazos abiertos"],
	["🕺", "Baile coreografiado con dos compañeros"], ["🤰", "Se lleva la pelota bajo la camiseta"],
	["✊", "Salto y puño al aire"], ["✈️", "Corre con los brazos en cruz, estilo avión"],
	["🧘", "Se sienta a lo sastre y mira a la tribuna"], ["👕", "Muestra la camiseta con su nombre"],
	["🤚", "Gesto de 'calma' con las manos"], ["🗣️", "Le pega un grito a la cámara"],
	["🛝", "Deslizada de rodillas hasta el córner"], ["🫡", "Saluda militarmente"],
	["💋", "Se besa la muñeca y apunta al palco"], ["🧑‍🔧", "Abraza al utilero en el borde del campo"],
	["🍼", "Hace el gesto de mecer un bebé"], ["📣", "Corre a buscar a la afición detrás del arco"],
	["🎽", "Se arranca la camiseta (amarilla asegurada)"], ["🗿", "Pose de estatua, brazos cruzados"],
]
func _celebrate_user_goal(minute: int, is_home, is_assist: bool = false, assist_target: String = "") -> void:
	var cel: Array = _CELEBRATIONS[_rng.randi() % _CELEBRATIONS.size()]
	if not is_assist:
		_crowd_chant()
		_goal_flares()
	# Gol propio: SOLO la celebración (pedido de Wilber: "cuando marque gol,
	# quita el popup"). El "GOOOL" gigante + la figura + el césped ya lo
	# cuentan todo; el popup central quedaba de más.

	# Velo oscuro que PAUSA visualmente el partido hasta que se ve la
	# celebración (toque para saltarla). El motor ya está esperando
	# (MatchEngine._celeb_pending) a que llamemos notify_celebration_done().
	var veil := ColorRect.new()
	veil.name = "CelebVeil"
	veil.color = Color(0.02, 0.03, 0.05, 0.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.z_index = 35
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	var _skip := {"v": false}
	veil.gui_input.connect(func(e):
		if e is InputEventScreenTouch and e.pressed:
			_skip["v"] = true)
	create_tween().tween_property(veil, "color:a", 0.55, 0.25)

	# --- Césped bajo el jugador (pedido de Wilber; armado compartido en
	# GoalCelebration.build_grass, 9-oct) ---
	var pitch: Control = GoalCelebration.build_grass(self, size, size.y * 0.62 + GoalCelebration.FEET_Y)
	pitch.z_index = 40
	pitch.modulate.a = 0.0
	create_tween().tween_property(pitch, "modulate:a", 1.0, 0.22)

	# --- "GOOOOL" gigante detrás de la figura ---
	var gool := Label.new()
	gool.name = "CelebGool"
	gool.text = "A S I S T E N C I A" if is_assist else "G O O O O L"
	gool.z_index = 45
	gool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gool.anchor_left = 0.0
	gool.anchor_right = 1.0
	gool.offset_top = size.y * 0.26
	gool.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Styles.apply_display_font(gool)
	gool.add_theme_font_size_override("font_size", int(size.x * 0.11))
	gool.add_theme_color_override("font_color", Color(0.98, 0.83, 0.30))
	gool.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.10))
	gool.add_theme_constant_override("outline_size", 10)
	gool.pivot_offset = Vector2(size.x * 0.5, size.y * 0.05)
	add_child(gool)
	gool.scale = Vector2(0.2, 0.2)
	gool.modulate.a = 0.0
	var gt := create_tween()
	gt.tween_property(gool, "modulate:a", 1.0, 0.1)
	gt.parallel().tween_property(gool, "scale", Vector2(1.12, 1.12), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gt.tween_property(gool, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_SINE)
	var gw := create_tween().set_loops(4)
	gw.tween_property(gool, "rotation", deg_to_rad(1.6), 0.5).set_trans(Tween.TRANS_SINE)
	gw.tween_property(gool, "rotation", deg_to_rad(-1.6), 0.5).set_trans(Tween.TRANS_SINE)

	# La CARA del usuario festejando (Avatar, con boca de festejo — ver
	# Avatar.celebration_config_for_player), grande, con entrada animada
	# (GoalCelebration — reemplazó primero a la figura articulada, que
	# Wilber reportó que se veía rígida/antinatural, y luego a un emoji
	# genérico, cambiado por algo más inmersivo: "sos VOS festejando").
	var kit: Color = _home_color if _user_side_is(is_home) else _away_color
	var celeb := GoalCelebration.new()
	# Por ENCIMA del popup (z 50): antes quedaba tapado por el banner
	# "¡GOL TUYO!" (pedido de Wilber). El confeti sigue arriba de todo (60).
	celeb.z_index = 55
	# Bien abajo para no pisarse con el banner "¡GOL TUYO!" (arriba,
	# CENTER_TOP) ni con "GOOOOL" (26% de la pantalla).
	celeb.position = Vector2(size.x * 0.5, size.y * 0.62)
	add_child(celeb)
	var avatar_cfg: Dictionary = Avatar.celebration_config_for_player(MatchState.user_player, SaveManager.load_world_seed())
	# Dos compañeros se suman al festejo (10-oct), con tu mismo kit.
	var mate_key: String = String(MatchState.user_player.club_id) + "|" + String(cel[1])
	celeb.signature = CareerRpgEngine.signature_celebration(MatchState.user_player)
	celeb.mates = [Avatar.teammate_config(avatar_cfg, mate_key + "|a", SaveManager.load_world_seed()),
		Avatar.teammate_config(avatar_cfg, mate_key + "|b", SaveManager.load_world_seed())]
	celeb.play(avatar_cfg, String(cel[1]), kit, _match_ball_idx())

	var confetti := Confetti.new()
	confetti.position = Vector2(size.x * 0.5, -10)
	add_child(confetti)
	confetti.z_index = 60
	confetti.burst(3.2)

	# Mantener la pausa ~2.6 s (o hasta que toquen para saltar).
	var held := 0.0
	while held < 2.6 and not _skip["v"]:
		await get_tree().process_frame
		held += get_process_delta_time()

	if is_instance_valid(veil):
		var vt := create_tween()
		vt.tween_property(veil, "color:a", 0.0, 0.22)
		vt.tween_callback(veil.queue_free)
	if is_instance_valid(celeb):
		var ct := create_tween()
		ct.tween_property(celeb, "modulate:a", 0.0, 0.22)
		ct.tween_callback(celeb.queue_free)
	for n in [pitch, gool]:
		if is_instance_valid(n):
			var nt := create_tween()
			nt.tween_property(n, "modulate:a", 0.0, 0.25)
			nt.tween_callback(n.queue_free)
	if is_instance_valid(confetti):
		await get_tree().create_timer(1.2).timeout
		if is_instance_valid(confetti):
			confetti.queue_free()

	# Reanudar el motor.
	if MatchState.engine != null:
		MatchState.engine.notify_celebration_done()

## Nombre del jugador de un MatchEvent (tarjeta / lesión). El engine manda
## `payload.player` como PlayerData; "TÚ" si sos vos.
func _user_side_is(is_home_goal) -> bool:
	if not (is_home_goal is bool):
		return false
	# Bug real (Parte 91): en un partido de selección, user_player.club_id
	# sigue siendo el CLUB del jugador (nunca cambia por estar convocado) —
	# comparado contra home_club_id (siempre vacío acá) esto daba SIEMPRE
	# false, sin importar de qué lado jugaba de verdad el usuario.
	if _is_national_fixture():
		var country: String = MatchState.user_player.country if MatchState.user_player != null else ""
		return (MatchState.fixture.get("home_country", "") == country) == is_home_goal
	var uid: String = MatchState.user_player.club_id if MatchState.user_player != null else ""
	return (MatchState.fixture.get("home_club_id", "") == uid) == is_home_goal

func _ev_player_name(event, fallback: String) -> String:
	if event.payload.get("is_user", false):
		return "TÚ"
	var p = event.payload.get("player", null)
	if p != null and "player_name" in p and String(p.player_name) != "":
		return String(p.player_name)
	return fallback

func _build_popup() -> void:
	_popup_panel = PanelContainer.new()
	_popup_panel.set_anchors_preset(Control.PRESET_CENTER)
	_popup_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_popup_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_popup_panel.custom_minimum_size = Vector2(300, 0)
	_popup_panel.visible = false
	_popup_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_panel.z_index = 50
	add_child(_popup_panel)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 30)
	m.add_theme_constant_override("margin_right", 30)
	m.add_theme_constant_override("margin_top", 22)
	m.add_theme_constant_override("margin_bottom", 22)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	_popup_icon = CenterContainer.new()
	_popup_icon.custom_minimum_size = Vector2(0, 44)
	_popup_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_popup_icon.visible = false
	vb.add_child(_popup_icon)
	_popup_label = Label.new()
	_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Parte 91i: los títulos de resultado ahora son frases cortas por
	# acción, no siempre tan cortas como "ACERTASTE" — autowrap de
	# seguridad para que un título un poco más largo NUNCA se salga del
	# panel (antes no hacía falta, todo lo que pasaba por acá era corto).
	_popup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_label.add_theme_font_override("font", Styles.font_black())
	_popup_label.add_theme_font_size_override("font_size", 34)
	_popup_sub_label = Label.new()
	_popup_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_sub_label.add_theme_font_size_override("font_size", Styles.SIZE_HEADING)
	vb.add_child(_popup_label)
	vb.add_child(_popup_sub_label)
	m.add_child(vb)
	_popup_panel.add_child(m)
	_build_event_card()

## Popup CENTRAL de evento (cambio / amarilla / roja / lesión / gol rival).
## Scrim que oscurece + panel al medio. El motor está pausado mientras se
## ve; toque en cualquier lado (o la cuenta atrás) lo cierra y reanuda.
func _build_event_card() -> void:
	# Scrim a media altura (z 40): oscurece y come el toque para cerrar,
	# pero SIEMPRE por debajo del panel de decisión (z 60) para no tapar
	# nunca el minijuego de un momento clave.
	_ev_scrim = ColorRect.new()
	_ev_scrim.name = "EvScrim"
	_ev_scrim.color = Color(0.02, 0.03, 0.05, 0.0)
	_ev_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ev_scrim.visible = false
	_ev_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_ev_scrim.z_index = 40
	_ev_scrim.gui_input.connect(func(e):
		if e is InputEventScreenTouch and e.pressed:
			_ack_event())
	add_child(_ev_scrim)

	# Contenedor a pantalla completa que CENTRA la carta (más fiable que
	# jugar con anchors/offsets a mano — antes salía corrida).
	var holder := CenterContainer.new()
	holder.name = "EvCardHolder"
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	holder.z_index = 41
	add_child(holder)
	_ev_holder = holder

	_ev_card = PanelContainer.new()
	_ev_card.custom_minimum_size = Vector2(320, 0)
	_ev_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := Styles.card_flat(Color(0.06, 0.07, 0.10, 0.98), 14)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.18)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 14
	_ev_card.add_theme_stylebox_override("panel", style)
	holder.add_child(_ev_card)

	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 18)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 14)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	_ev_icon = CenterContainer.new()
	_ev_icon.custom_minimum_size = Vector2(44, 44)
	_ev_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_ev_icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	_ev_lines = VBoxContainer.new()
	_ev_lines.add_theme_constant_override("separation", 2)
	col.add_child(_ev_lines)
	_ev_min = Label.new()
	_ev_min.add_theme_font_size_override("font_size", 11)
	_ev_min.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	col.add_child(_ev_min)
	row.add_child(col)

	m.add_child(row)
	_ev_card.add_child(m)

## `lines`: Array de {text, color, big}. `icon_node`: Control o null.
## `spin`: anima el icono entrando girado (para tarjetas).
func _flash_event_card(icon_node, lines: Array, minute: int, tag: String, spin: bool = false) -> void:
	if _ev_card == null:
		return
	for c in _ev_icon.get_children():
		c.queue_free()
	_ev_icon.visible = icon_node != null
	if icon_node != null:
		_ev_icon.add_child(icon_node)
	for c in _ev_lines.get_children():
		c.queue_free()
	for ln in lines:
		var l := Label.new()
		l.text = String(ln.get("text", ""))
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = true
		if bool(ln.get("big", false)):
			l.add_theme_font_override("font", Styles.font_black())
			l.add_theme_font_size_override("font_size", 18)
		else:
			l.add_theme_font_override("font", Styles.font_semibold())
			l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", ln.get("color", Color.WHITE))
		_ev_lines.add_child(l)
	_ev_min.text = ("%s · %d'" % [tag, minute]) if tag != "" else "%d'" % minute

	# Aparece al MEDIO (el CenterContainer lo centra) con un fundido + un
	# rebote de escala. El motor ya está pausado (MatchEngine._drain_ack)
	# esperando _ack_event().
	_ev_awaiting_ack = true
	if _ev_scrim != null:
		_ev_scrim.visible = true
		_ev_scrim.color.a = 0.0
		create_tween().tween_property(_ev_scrim, "color:a", 0.5, 0.18)
	if _ev_holder != null:
		_ev_holder.visible = true
	_ev_card.visible = true
	# Centro real de la carta, no un alto fijo — antes asumía ~84 de alto
	# (icono chico de 44 + 2-3 líneas cortas), que dejaba de valer con el
	# ícono del árbitro (130 de alto) y el rebote de entrada quedaba
	# pivotando de un punto que ya no era el centro.
	_ev_card.pivot_offset = _ev_card.get_minimum_size() * 0.5
	_ev_card.scale = Vector2(0.7, 0.7)
	_ev_card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_ev_card, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(_ev_card, "scale", Vector2(1.05, 1.05), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_ev_card, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	_ev_time_left = EV_CARD_SECONDS
	Audio.match_sfx("tick")

	if spin and icon_node != null and icon_node is Control:
		var ic := icon_node as Control
		ic.pivot_offset = ic.custom_minimum_size * 0.5
		ic.rotation = deg_to_rad(-65.0)
		ic.scale = Vector2(0.4, 0.4)
		var ctw := create_tween().set_parallel(true)
		ctw.tween_property(ic, "rotation", 0.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)
		ctw.tween_property(ic, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)

## El motor espera confirmación tras ciertos eventos (MatchEngine._drain_ack).
## Sin popup que cerrar, se la damos UN cuadro después: _drain_ack borra los
## avisos que llegan ANTES de empezar a esperar.
func _release_engine() -> void:
	get_tree().process_frame.connect(func():
		if MatchState.engine != null and MatchState.engine.has_method("notify_event_ack"):
			MatchState.engine.notify_event_ack(), CONNECT_ONE_SHOT)

## La nota en vivo "late" verde (acertaste) o roja (fallaste).
func _pulse_rating(ok: bool) -> void:
	if rating_big == null:
		return
	rating_big.pivot_offset = rating_big.size * 0.5
	var tw := create_tween()
	tw.tween_property(rating_big, "modulate", Color(0.6, 1.6, 0.7) if ok else Color(1.7, 0.6, 0.6), 0.12)
	tw.parallel().tween_property(rating_big, "scale", Vector2(1.25, 1.25), 0.12)
	tw.tween_property(rating_big, "modulate", Color.WHITE, 0.45)
	tw.parallel().tween_property(rating_big, "scale", Vector2.ONE, 0.45)

## Cierra el popup central de evento y REANUDA el motor. Lo dispara el
## toque en el scrim o la cuenta atrás de _process. Idempotente.
func _ack_event() -> void:
	if not _ev_awaiting_ack:
		return
	_ev_awaiting_ack = false
	_ev_time_left = 0.0
	if _ev_card != null:
		var tw := create_tween()
		tw.tween_property(_ev_card, "modulate:a", 0.0, 0.16)
		tw.parallel().tween_property(_ev_card, "scale", Vector2(0.85, 0.85), 0.16).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): _ev_card.visible = false)
	if _ev_scrim != null:
		var st := create_tween()
		st.tween_property(_ev_scrim, "color:a", 0.0, 0.16)
		st.tween_callback(func():
			_ev_scrim.visible = false
			if _ev_holder != null:
				_ev_holder.visible = false)
	if MatchState.engine != null and MatchState.engine.has_method("notify_event_ack"):
		MatchState.engine.notify_event_ack()

## Global bajo el marcador en una vuelta ida/vuelta.
func _show_first_leg_banner() -> void:
	var carry_value: Variant = MatchState.fixture.get("tie_agg", null)
	var first_leg: bool = MatchState.fixture.has("tie_key") and int(MatchState.fixture.get("leg", 0)) == 1
	if not (carry_value is Dictionary) and not first_leg:
		return
	var lbl := Label.new()
	_aggregate_score_label = lbl
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", Styles.font_semibold())
	lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	lbl.add_theme_color_override("font_color", Styles.GOLD)
	var vb := score_label.get_parent().get_parent() as VBoxContainer  # ScoreVBox
	if vb != null:
		vb.add_child(lbl)
		vb.move_child(lbl, minute_label.get_index() + 1)
		_refresh_aggregate_score()

## Árbitro sacando la tarjeta (pedido de Wilber, arte propio pasado por
## él) — reemplaza el rectángulo de color de MatchIcons.card() en el
## popup de evento de amarilla/roja (incluida la roja por doble
## amarilla, que reusa la MISMA pose de roja: el árbitro la muestra
## igual, sea directa o por acumulación — no hay una 4ª pose distinta).
const _REFEREE_YELLOW := preload("res://assets/characters/referee/referee_yellow_card.png")
const _REFEREE_RED := preload("res://assets/characters/referee/referee_red_card.png")
## OJO: hasta el fix de `expand_mode` (abajo) esta constante NUNCA controló
## el tamaño real -- la imagen (667x1979 crudo) se renderizaba casi a su
## resolución nativa sin importar el valor, así que el historial
## 130->92->64 no es un dato confiable de "tamaño que se veía bien". Ahora
## que sí se respeta: la imagen es MUY angosta (relación ~1:3, pose de
## cuerpo completo), así que un alto chico da un ancho ilegible.
const _REFEREE_ICON_HEIGHT := 300.0

func _card_icon(is_red: bool) -> Control:
	var tex: Texture2D = _REFEREE_RED if is_red else _REFEREE_YELLOW
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var aspect: float = float(tex.get_width()) / float(tex.get_height())
	rect.custom_minimum_size = Vector2(_REFEREE_ICON_HEIGHT * aspect, _REFEREE_ICON_HEIGHT)
	# `custom_minimum_size` es un PISO, no un techo -- si el contenedor
	# padre (_ev_icon) tiene espacio de sobra, un Control por defecto lo
	# ocupa igual y la imagen (con KEEP_ASPECT_CENTERED) crece con él. Con
	# el árbitro nuevo (imagen mucho más alta que el rectángulo de color
	# de antes) eso lo hacía "tapar toda la pantalla" -- reportado por
	# Wilber. SHRINK_CENTER lo fija al tamaño real, sin importar cuánto
	# espacio le sobre al contenedor.
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect

func _card_side_tag(home) -> String:
	if not (home is bool):
		return ""
	return "Tu equipo" if _user_side_is(home) else "Rival"

## Compat: el cambio arma sus dos líneas ▼/▲ y llama al cartel genérico.
func _flash_sub_card(out_name: String, in_name: String, minute: int, tag: String = "", icon: Control = null) -> void:
	var swap := Label.new()
	swap.text = "⇄"
	swap.add_theme_font_size_override("font_size", 26)
	swap.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	swap.custom_minimum_size = Vector2(40, 40)
	swap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	swap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_flash_event_card(icon if icon != null else swap, [
		{"text": "CAMBIO", "color": Styles.GRAY_TEXT},
		{"text": "▼  %s" % (out_name if out_name != "" else "—"), "color": Styles.RED},
		{"text": "▲  %s" % (in_name if in_name != "" else "—"), "color": Styles.GREEN},
	], minute, tag)

## `is_home == null` -> popup neutro (dorado). Si no, se colorea con el
## color del equipo al que le pasa la situación. Se oculta solo por la
## cuenta atrás de _process (`_popup_time_left`), no por un timer frágil.
func _flash_popup(title: String, subtitle: String, is_home, icon: String = "") -> void:
	var col: Color = Styles.GOLD
	if is_home is bool:
		col = _home_color if is_home else _away_color
	if _popup_icon != null:
		for ch in _popup_icon.get_children():
			ch.queue_free()
		if icon == "ball":
			_popup_icon.add_child(BallDesign.build(_match_ball_idx(), 40))
			_popup_icon.visible = true
		elif icon == "injury":
			_popup_icon.visible = false
			# Pulso rojo del panel para comunicar el golpe.
			var itw := create_tween()
			itw.tween_property(_popup_panel, "modulate", Color(1.5, 0.7, 0.7), 0.12)
			itw.tween_property(_popup_panel, "modulate", Color.WHITE, 0.5)
		elif icon.begins_with("card"):
			var card_rect := MatchIcons.card(icon == "card_red", 36)
			_popup_icon.add_child(card_rect)
			_popup_icon.visible = true
			# Animación: entra girada y se endereza con un rebote.
			card_rect.pivot_offset = Vector2(18, 18)
			card_rect.rotation = deg_to_rad(-70.0)
			card_rect.scale = Vector2(0.4, 0.4)
			var ctw := create_tween().set_parallel(true)
			ctw.tween_property(card_rect, "rotation", 0.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ctw.tween_property(card_rect, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_popup_icon.visible = false
	var style := Styles.card_flat(col, 18)
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 3)
	style.border_color = Color(1, 1, 1, 0.4)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	_popup_panel.add_theme_stylebox_override("panel", style)
	var text_col := Styles.contrasting_text_color(col)
	_popup_label.text = title.to_upper()
	_popup_label.add_theme_color_override("font_color", text_col)
	_popup_sub_label.text = subtitle
	_popup_sub_label.add_theme_color_override("font_color", Color(text_col, 0.85))
	_popup_sub_label.visible = not subtitle.is_empty()
	_popup_panel.visible = true
	_popup_time_left = POPUP_SECONDS

## Popup de resultado de decisión: verde si acertaste (sumaste nota),
## rojo si fallaste (restaste) — pedido explícito para saber al toque si
## sumás o restás puntos de valoración.
func _flash_result(title: String, subtitle: String, ok: bool) -> void:
	_flash_popup(title, subtitle, null)
	_popup_awaits_engine_ack = true
	var col: Color = Styles.GREEN if ok else Styles.RED
	var style := Styles.card_flat(col, 18)
	for side in ["left", "right", "top", "bottom"]:
		style.set("border_width_" + side, 3)
	style.border_color = Color(1, 1, 1, 0.4)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	_popup_panel.add_theme_stylebox_override("panel", style)
	var tc := Styles.contrasting_text_color(col)
	_popup_label.add_theme_color_override("font_color", tc)
	_popup_sub_label.add_theme_color_override("font_color", Color(tc, 0.9))

func _handle_shootout_event(event: MatchEvent) -> void:
	var phase: String = event.payload.get("phase", "")
	if phase == "start":
		event_log.append_text("[b]Tanda de penales[/b]\n")
	elif phase == "end":
		var winner: String = event.payload.get("winner", "")
		var score: Array = event.payload.get("score", [0, 0])
		event_log.append_text("Tanda decidida %d-%d. Gana: %s\n" % [score[0], score[1], winner])
	elif event.payload.has("team"):
		var ok: bool = event.payload.get("success", false)
		var team_label: String = event.payload.get("team", "")
		event_log.append_text("Penal (%s): %s\n" % [team_label, "gol" if ok else "falla"])

## Decisión que llegó mientras todavía se veía la repetición de la anterior
## (jugada ENCADENADA, 10-oct): se muestra cuando la repetición termina.
var _deferred_decision: Dictionary = {}

var _last_user_world = null   # Vector2 (mundo) donde terminaste tu última acción
func _on_decision_requested(situation: Dictionary) -> void:
	if _replaying or _replay_pending:
		_deferred_decision = situation
		return
	# PARTIDO EN VIVO (FootballLegacy H): la jugada se juega en la cancha.
	if LiveBridge.enabled():
		_live_moment(situation)
		return
	# Jugada encadenada: arrancás donde quedaste. Jugada nueva: de cero.
	if bool(situation.get("chained", false)) and _last_user_world != null and not bool(situation.get("foul", false)):
		_pitch_ctx["user_at_world"] = _last_user_world
	else:
		_pitch_ctx.erase("user_at_world")
	# Sistema "por decisiones": primero ELEGÍS la acción (menú de opciones),
	# después va el minijuego de precisión para esa acción. El engine está
	# en pausa (await) hasta que se resuelve.
	# Cinturón y tirantes: el panel de decisión SIEMPRE por encima del
	# scrim de los popups de evento (z 40) — que nunca tape el minijuego.
	decision_panel.z_index = 60
	_chosen_kind = ""
	_meter_running = false
	for c in choice_box.get_children():
		c.queue_free()

	var options: Array = situation.get("options", [])
	_opts_by_kind = {}
	for o in options:
		_opts_by_kind[String(o.get("kind", ""))] = o
	if not options.is_empty() and Preferences.live_play and _pitch != null:
		# OPORTUNIDAD EN VIVO (10-oct): sin menú. La jugada aparece en la
		# cancha y la jugás con el gesto; lo que no tiene versión "en vivo"
		# (pelota parada, centros que te llegan, arquero) arranca directo
		# su minijuego con la acción principal.
		var k0: String = String(options[0].get("kind", ""))
		choice_box.visible = false
		meter_area.visible = true
		decision_title.text = ("¡LA JUGADA SIGUE! · %d'" if bool(situation.get("chained", false)) else "¡TU JUGADA! · %d'") % int(situation.get("minute", 0))
		if bool(situation.get("chained", false)):
			var vp_l: Vector2 = get_viewport().get_visible_rect().size
			var ftxt: String = "¡FALTA! TIRO LIBRE" if bool(situation.get("foul", false)) else ("¡REBOTE!" if bool(situation.get("rebound", false)) else "¡LA JUGADA SIGUE!")
			Juice.float_text(self, ftxt, Vector2(vp_l.x * 0.5 - float(ftxt.length()) * 7.5, vp_l.y * 0.36), Color(1.0, 0.85, 0.3) if bool(situation.get("foul", false)) else Color(0.4, 0.9, 1.0), 26)
		decision_panel.visible = true
		if _live_ok(k0):
			_minigame = "live"
			_show_pitch_for(k0, int(situation.get("minute", 0)))
			_pitch.set_interactive(false)
			_start_live(options, bool(situation.get("from_pass", false)))
		else:
			_show_pitch_for(k0, int(situation.get("minute", 0)))
			_on_choice_pressed(k0)
		return
	if options.is_empty():
		# Penal u otra decisión sin menú: directo al minijuego.
		choice_box.visible = false
		decision_title.text = _label_for_kind(situation.get("kind", ""))
		meter_area.visible = true
		_chosen_difficulty = float(situation.get("difficulty", 0.32))
		_start_minigame(String(situation.get("kind", "")))
	else:
		choice_box.visible = true
		meter_area.visible = false
		decision_title.text = ("¡LA JUGADA SIGUE! · %d'" if bool(situation.get("chained", false)) else "Momento clave · %d'") % int(situation.get("minute", 0))
		if bool(situation.get("chained", false)):
			var vp_c: Vector2 = get_viewport().get_visible_rect().size
			Juice.float_text(self, "¡REBOTE!" if bool(situation.get("rebound", false)) else "¡JUGADA ENCADENADA!", Vector2(vp_c.x * 0.5 - (70.0 if bool(situation.get("rebound", false)) else 150.0), vp_c.y * 0.36), Color(0.4, 0.9, 1.0), 26)
		var narration: String = String(situation.get("narration", ""))
		if not narration.is_empty():
			var nar := Label.new()
			nar.text = narration
			nar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nar.add_theme_color_override("font_color", Styles.GRAY_TEXT)
			nar.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
			choice_box.add_child(nar)
		choice_box.add_child(_decision_factors_row())
		for opt in options:
			choice_box.add_child(_make_choice_button(opt))
	decision_panel.visible = true
	if options.is_empty():
		# El penal en juego ahora emite DECISION_RESULT (MatchEngine,
		# 9-oct) → se puede repetir; la tanda todavía no.
		if String(situation.get("kind", "")) in ["penalty", "penalty_save", "penalty_save_shootout"]:
			_show_pitch_for(String(situation.get("kind", "")), int(situation.get("minute", 0)))
		else:
			_hide_pitch()
	else:
		_show_pitch_for(String(options[0].get("kind", "")), int(situation.get("minute", 0)))

## Qué hace más fácil o más difícil este momento (P4, 9-oct — "dificultad
## visible: rival + cansancio"): chips chicos con la fuerza del rival, tu
## cansancio, la forma, el ánimo y el clima. Solo informativo: la cuenta
## real sigue en DecisionResolver.
func _decision_factors_row() -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 4)
	var p: PlayerData = MatchState.user_player
	var rival: MatchTeam = null
	if MatchState.home_team != null and MatchState.away_team != null and p != null:
		rival = MatchState.away_team if (MatchState.home_team.starting_xi.has(p) or MatchState.home_team.bench.has(p)) else MatchState.home_team
	if rival != null and not rival.starting_xi.is_empty():
		var sum := 0
		for x in rival.starting_xi:
			sum += x.overall
		var avg: int = int(round(float(sum) / rival.starting_xi.size()))
		var col: Color = Styles.RED if avg >= (p.overall if p != null else 60) + 4 else (Styles.GREEN if avg <= (p.overall if p != null else 60) - 4 else Styles.GRAY_TEXT)
		flow.add_child(UiKit.chip("Rival %d" % avg, col))
	if p != null:
		var fat: int = int(round((p.fatigue_physical + p.fatigue_mental) / 2.0))
		if fat >= 15:
			flow.add_child(UiKit.chip("Cansancio %d%%" % fat, Styles.AMBER if fat < 45 else Styles.RED))
		var f: int = ProgressionEngine.form(p)
		if f != 3:
			flow.add_child(UiKit.chip("Forma %s" % ProgressionEngine.FORM_ARROWS[f], ProgressionEngine.form_color(f)))
		if p.mood >= 80 or p.mood <= 25:
			flow.add_child(UiKit.chip("Ánimo %s" % SocialLifeEngine.mood_label(p.mood), Styles.GREEN if p.mood >= 80 else Styles.RED))
	var wx: String = MatchIcons.weather_for(MatchState.fixture, SaveManager.load_world_seed())
	if wx == "rain" or wx == "snow":
		flow.add_child(UiKit.chip("Lluvia" if wx == "rain" else "Nieve", Styles.BLUE))
	return flow

func _make_choice_button(opt: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 60)
	btn.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(btn, Styles.card_accent(Styles.GOLD, Styles.CARD_DARK, 12))
	btn.pressed.connect(_on_choice_pressed.bind(String(opt.get("kind", ""))))

	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.text = String(opt.get("label", ""))
	lbl.add_theme_font_override("font", Styles.font_semibold())
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(lbl)
	var hint := Label.new()
	hint.text = String(opt.get("hint", ""))
	hint.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	hint.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hint)
	if bool(opt.get("combo", false)):
		# COMBO (P4): ganaste el regate → el arquero quedó descolocado.
		var cb := Label.new()
		cb.text = "⚡ COMBO · el arquero quedó descolocado"
		cb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cb.add_theme_font_override("font", Styles.font_black())
		cb.add_theme_font_size_override("font_size", 12)
		cb.add_theme_color_override("font_color", Styles.GOLD)
		col.add_child(cb)
		btn.ready.connect(func(): Juice.pulse(btn, 1.03, 0.9))
	row.add_child(col)

	# Ya no hay porcentaje oculto: si clavás el minijuego, entra. Lo que
	# cambia es lo DIFÍCIL de clavarlo — la zona es más fina y la barra más
	# rápida cuanto peor el matchup. Mostramos esa dificultad.
	var d: float = float(opt.get("difficulty", 0.45))
	var dcol := VBoxContainer.new()
	dcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dcol.alignment = BoxContainer.ALIGNMENT_CENTER
	var d_lbl := Label.new()
	d_lbl.text = _difficulty_word(d)
	d_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d_lbl.add_theme_font_override("font", Styles.font_semibold())
	d_lbl.add_theme_font_size_override("font_size", 13)
	d_lbl.add_theme_color_override("font_color", _difficulty_tint(d))
	d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dcol.add_child(d_lbl)
	var pips := Label.new()
	pips.text = _difficulty_pips(d)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.add_theme_font_size_override("font_size", 13)
	pips.add_theme_color_override("font_color", _difficulty_tint(d))
	pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dcol.add_child(pips)
	row.add_child(dcol)

	m.add_child(row)
	btn.add_child(m)
	return btn

func _difficulty_word(d: float) -> String:
	if d < 0.28: return "Fácil"
	if d < 0.48: return "Media"
	if d < 0.68: return "Difícil"
	return "Brutal"

func _difficulty_pips(d: float) -> String:
	var n: int = clampi(int(round(d * 5.0)) + 1, 1, 5)
	return "●".repeat(n) + "○".repeat(5 - n)

func _difficulty_tint(d: float) -> Color:
	if d < 0.28: return Styles.GREEN
	if d < 0.55: return Styles.AMBER
	return Styles.RED

## ¿Esta jugada tiene versión "en vivo"? Hace falta que la pelota esté en
## tus pies (ataque) o en los del rival que te encara (defensa).
func _live_ok(kind: String) -> bool:
	var base: Dictionary = PitchPlays.SETUPS.get(kind, {})
	var ball = base.get("ball", "user")
	if PitchPlays.is_attack(kind):
		return ball is String and ball == "user" and not (kind in ["free_kick", "penalty", "penalty_shootout"])
	return kind in PitchPlays.DEFEND and ball is String and ball == "a1"

var _live_opts: Array = []
var _live_slide: bool = false
func _start_live(options: Array, with_run: bool = false) -> void:
	_live_opts = []
	for o in options:
		_live_opts.append(String(o.get("kind", "")))
	_live_slide = false
	_chosen_kind = ""
	_chosen_difficulty = float(options[0].get("difficulty", 0.45))
	_meter_running = false
	tap_button.visible = false
	for n in meter_area.get_children():
		if String(n.name).begins_with("MG_"):
			n.queue_free()
	var mods := _context_mods()
	if not _pitch.minigame_done.is_connected(_on_pitch_mg_done):
		_pitch.minigame_done.connect(_on_pitch_mg_done)
	_pitch.live_options = _live_opts
	# Vengo de un pase mío: antes de recibir, me DESMARCO arrastrando el dedo.
	_pitch.live_run = with_run and PitchPlays.is_attack(String(_live_opts[0]))
	_pitch.live_run_speed = DecisionResolver.run_speed(MatchState.user_player.speed if MatchState.user_player != null else 60)
	var mg: PitchMinigame = _pitch.start_minigame("live", String(_live_opts[0]), clampf(_chosen_difficulty, 0.0, 1.0), float(mods[1]))
	if _pitch.live_run:
		_pitch.reset_camera(true)   # la cámara sigue a tu jugador mientras se desmarca
	elif PitchPlays.is_attack(String(_live_opts[0])):
		var pts: Array = [Vector2(0.5, 0.0)] if PitchPlays._first_in(_live_opts, PitchPlays.SHOT) != "" and _pitch.npos("user").y < 0.45 else []
		_pitch.focus_on(["user", "m1", "m2"], pts, 1.7)
	else:
		_pitch.focus_on(["user", "a1", "a2"], [], 1.9)
	_tap_hint(mg.window_hint(), "tap")
	_set_meter_ui()

## El gesto que hiciste → acción del motor + precisión (fórmulas en
## DecisionResolver). La acción siempre es una de las que ofreció el motor.
func _on_live_done(r: Dictionary) -> void:
	if _minigame != "live":
		return
	var action: String = String(r.get("action", "timeout"))
	var kind: String = String(_live_opts[0])
	match action:
		"pass": kind = PitchPlays.kind_for_tap(String(r.get("receiver", "m1")), _live_opts)
		"shot": kind = PitchPlays.kind_for_tap("goal", _live_opts)
		"dribble": kind = PitchPlays.kind_for_tap("space", _live_opts)
		"slide":
			for sk in ["last_ditch_tackle", "recovery_tackle", "tackle"]:
				if sk in _live_opts:
					kind = sk
					break
	if kind == "":
		kind = String(_live_opts[0])
	var d: float = clampf(float(_opts_by_kind.get(kind, {}).get("difficulty", _chosen_difficulty)), 0.0, 1.0)
	# Recibiste libre o marcado (solo si hubo desmarque): cambia lo difícil.
	if _pitch.live_run and r.has("open"):
		d = clampf(d + DecisionResolver.receive_difficulty_mod(float(r["open"])), 0.0, 1.0)
	var wf: float = float(_context_mods()[0])
	var precision: float = 0.1
	match action:
		"pass":
			_pitch_ctx["pass_to"] = String(r.get("receiver", "m1"))
			if bool(r.get("offside", false)):
				precision = DecisionResolver.OFFSIDE_PRECISION
				_pitch_ctx["force_offside"] = true
			else:
				precision = DecisionResolver.pitch_pass_precision(d, float(r.get("clearance", 0.0)), wf)
		"shot":
			var half: float = PitchView.GOAL_W * 0.5
			var ax: float = float(r.get("aim_x", 0.5))
			var wide: bool = absf(ax - 0.5) > half
			var sep: float = clampf(absf(ax - float(r.get("gk_x", 0.5))) / (PitchView.GOAL_W * 0.9), 0.0, 1.0)
			var pw: float = float(r.get("power", 0.0))
			precision = DecisionResolver.pitch_shot_precision(d, sep, pw, wide, wf)
			_pitch_ctx["aim_x"] = clampf(ax, 0.5 - half * 1.5, 0.5 + half * 1.5)
			_pitch_ctx["shot_high"] = precision < DecisionResolver.GRADE_GOOD and pw > DecisionResolver.SHOT_POWER_IDEAL
		"dribble":
			precision = DecisionResolver.live_dribble_precision(d, float(r.get("clearance", 0.0)), wf)
		"tackle":
			precision = DecisionResolver.pitch_timing_precision(d, float(r.get("err", 9.0)), true, 0.34, 0.14, wf)
		"slide":
			_live_slide = true
			precision = DecisionResolver.live_slide_precision(d, float(r.get("err", 9.0)), wf)
	_chosen_kind = kind
	_chosen_difficulty = d
	# El final se anima desde donde quedó cada uno (sin rearmar la escena).
	_pitch_ctx["live_pos"] = _pitch.actor_positions()
	_pitch_kind = kind
	_finish_decision(precision)

func _on_choice_pressed(kind: String) -> void:
	_chosen_kind = kind
	if _pitch != null and _pitch.visible:
		# La jugada se rearma para la acción ELEGIDA (si elegiste pasar en
		# vez de rematar, tiene que haber a quién pasarle).
		_pitch_kind = kind
		_pitch.set_interactive(false)
		_pitch.setup(PitchPlays.scene_for(kind, _pitch_ctx))
	_chosen_difficulty = float(_opts_by_kind.get(kind, {}).get("difficulty", 0.45))
	for c in choice_box.get_children():
		c.queue_free()
	choice_box.visible = false
	decision_title.text = _label_for_kind(kind)
	meter_area.visible = true
	_start_minigame(kind)

# ============================================================
#  MINIJUEGOS DE DECISIÓN
#  Todos terminan llamando `_finish_decision(precision 0..1)`.
#  La matemática de éxito/fallo sigue enteramente en DecisionResolver
#  (vía engine.resolve_decision) — acá solo se produce la `precision`.
# ============================================================

## Parte 91h: los 12 momentos nuevos se reparten en los minijuegos de
## siempre según a cuál se parecen más. Parte 91i (pedido de Wilber:
## "inventemos algunos minijuegos más"): sumados "reaction" (reflejo puro,
## para las acciones instintivas de último segundo) y "sequence" (leer y
## tocar la opción correcta, para las jugadas de "elegís entre varias
## opciones") — 4 de los 12 momentos nuevos se movieron a estos dos en vez
## de quedarse en hold/meter, donde encajaban peor.
const _AIM_KINDS := ["shot_on_goal", "one_on_one", "penalty", "penalty_shootout", "free_kick", "long_shot", "aerial_duel", "volley", "chip_shot", "penalty_save", "penalty_save_shootout"]
const _RHYTHM_KINDS := ["dribble", "counter_run"]
const _HOLD_KINDS := ["pressing", "clearance", "last_ditch_tackle"]
const _REACTION_KINDS := ["recovery_tackle", "block_shot", "one_on_one_save", "sweep_keeper"]
const _SEQUENCE_KINDS := ["cross", "switch_play", "distribution"]

func _minigame_for(kind: String) -> String:
	if kind in _AIM_KINDS:
		return "aim"
	if kind in _RHYTHM_KINDS:
		return "rhythm"
	if kind in _HOLD_KINDS:
		return "hold"
	if kind in _REACTION_KINDS:
		return "reaction"
	if kind in _SEQUENCE_KINDS:
		return "sequence"
	return "meter"

func _start_minigame(kind: String) -> void:
	_minigame = _minigame_for(kind)
	_aim_zone = -1
	_rhythm_hits = 0.0
	_rhythm_round = 0
	_hold_active = false
	_hold_value = 0.0
	# Invalida cualquier timer de espera de reflejo/secuencia que hubiera
	# quedado pendiente de una decisión anterior (nunca debería pasar, pero
	# cuesta cero blindarlo y evita un doble-avance fantasma).
	_reaction_token += 1
	_sequence_token += 1
	# Limpia adornos de un minijuego previo.
	for n in meter_area.get_children():
		if String(n.name).begins_with("MG_"):
			n.queue_free()
	# Remates: el minijuego se juega EN la cancha 2D (punto 5 del pedido del
	# 9-oct, "intervenir en la acción") — arrastrar hacia el arco lejos del
	# arquero que se mueve. Tiro libre y penal mantienen los suyos.
	if kind in _PITCH_SHOT_KINDS and _pitch != null and _pitch.visible:
		_minigame = "pitch_shot"
	elif _pitch_mg_mode(kind) != "" and _pitch != null and _pitch.visible:
		_minigame = "pitch_mg"
	match _minigame:
		"pitch_shot": _start_pitch_shot(kind)
		"pitch_mg": _start_pitch_mg(kind)
		"aim": _start_aim(kind)
		"rhythm": _start_rhythm(kind)
		"hold": _start_hold(kind)
		"reaction": _start_reaction(kind)
		"sequence": _start_sequence(kind)
		_: _start_power_meter(kind)
	_set_meter_ui()

## El panel del minijuego muestra SOLO lo que este minijuego usa (10-oct,
## captura real: la barra y el cartel "tocá cuando el marcador esté en la
## zona verde" quedaban a la vista mientras apuntabas el remate o
## gambeteabas en la cancha — confundía). Además el botón dice qué hacer.
func _set_meter_ui() -> void:
	var meter_hint: Label = meter_area.get_node_or_null("MeterHint")
	var bar_on: bool = true
	var hint: String = "Tocá el botón cuando la barrita esté en la zona verde"
	var btn: String = "¡TOCAR!"
	match _minigame:
		"pitch_shot":
			bar_on = false
			hint = "PASO 1 de 3  ·  APUNTÁ en la cancha"
		"pitch_mg", "live":
			bar_on = false
			hint = "Se juega EN LA CANCHA"
		"pitch_shot_style":
			bar_on = false
			hint = ""
		"pitch_shot_hold":
			hint = "PASO 3 de 3  ·  POTENCIA"
			btn = "MANTENÉ APRETADO Y SOLTÁ"
		"hold":
			hint = "Mantené apretado y soltá en la zona verde"
			btn = "MANTENÉ APRETADO Y SOLTÁ"
		"pitch_pass_bar":
			hint = "PASO 2 de 2  ·  PRECISIÓN del pase"
		"reaction", "sequence", "aim":
			bar_on = false
			hint = ""
	power_meter_bg.visible = bar_on
	if meter_hint != null:
		meter_hint.text = hint
		meter_hint.visible = hint != ""
		meter_hint.add_theme_color_override("font_color", Styles.GOLD)
		meter_hint.add_theme_font_override("font", Styles.font_semibold())
	tap_button.text = btn

## Modificadores de contexto sobre la ventana/velocidad (clima, fatiga,
## de visitante). Devuelve [width_factor, speed_factor].
func _context_mods() -> Array:
	var wf := 1.0
	var sf := 1.0
	var wx: String = MatchIcons.weather_for(MatchState.fixture, SaveManager.load_world_seed())
	if wx == "rain":
		sf *= 1.22
	elif wx == "snow":
		sf *= 1.30
	var p: PlayerData = MatchState.user_player
	if p != null:
		var fat: float = float(p.fatigue_physical) + float(p.fatigue_mental)
		wf *= clampf(1.0 - fat / 320.0, 0.72, 1.0)
	var is_away: bool
	if _is_national_fixture():
		is_away = MatchState.fixture.get("away_country", "") == (p.country if p != null else "")
	else:
		is_away = MatchState.fixture.get("away_club_id", "") == (p.club_id if p != null else "")
	if is_away:
		wf *= 0.92   # de visitante, algo más difícil
	# Clásico: presión (P5, fórmula en DecisionResolver).
	if bool(MatchState.fixture.get("derby", false)) and p != null:
		wf *= 1.0 + DecisionResolver.derby_pressure(p.composure)
	# Presión del momento (10-oct): piernas cansadas y partido grande.
	wf *= DecisionResolver.stamina_width_factor(_live_stamina)
	var rn: String = String(MatchState.fixture.get("round_name", ""))
	var is_final: bool = rn == "Final" or rn.ends_with(" Final") or String(MatchState.fixture.get("competition", "")) == "supercup"
	wf *= DecisionResolver.big_match_width_factor(is_final, bool(MatchState.fixture.get("is_knockout", false)), p.composure if p != null else 60)
	# Habilidades del árbol + forma (schema v33, fórmula en DecisionResolver).
	var chem: int = SocialLifeEngine.chemistry(p, WorldTickEngine.season) if not _is_national_fixture() else 30
	var rpg: Array = DecisionResolver.rpg_meter_mods(p, _chosen_kind, chem)
	wf *= float(rpg[0])
	sf *= float(rpg[1])
	return [wf, sf]

# --- 1) Barra clásica ---
func _start_power_meter(_kind: String) -> void:
	_tap_hint("Tocá cuando la barrita entre en la zona verde. Si la clavás, la jugada sale.", "tap")
	_meter_value = 0.0
	_meter_direction = 1
	_meter_running = true
	# El acierto/fallo ya NO es un dado oculto: clavar la zona = conseguido.
	# La dificultad (skill del jugador + rasgos + rival) fija cuán fina y
	# rápida es la zona. `_chosen_difficulty` 0 = regalado, 1 = brutal.
	var d: float = clampf(_chosen_difficulty, 0.0, 1.0)
	var mods := _context_mods()
	# Zona: incluso "fácil" pide algo de puntería (0.34), "brutal" es un hilo.
	_target_width = lerpf(0.34, 0.10, d) * float(mods[0])
	_meter_speed = MOVE_SPEED * lerpf(0.80, 2.0, d) * float(mods[1])
	_target_center = randf_range(0.3, 0.7)
	_position_target_zone()

# --- 2) Aim + power (definición / penal / tiro libre) ---
func _start_aim(kind: String) -> void:
	_meter_running = false
	tap_button.visible = false
	var box := VBoxContainer.new()
	box.name = "MG_Aim"
	box.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.text = "¿A dónde la mandás? (elegí rápido para no cantarla)"
	if kind == "aerial_duel":
		lbl.text = "Vas por arriba: elegí el remate (rápido para ganarle al marcador)"
	lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(lbl)
	_aim_kind = kind
	if kind in ["penalty_save", "penalty_save_shootout"]:
		# Atajar (P4): elegís a dónde tirarte; después la barra = reflejo.
		lbl.text = "Elegí hacia dónde te tirás. Si adivinás el lado, la atajás más fácil."
		var sgrid := GoalAimGrid.new()
		sgrid.zone_picked.connect(func(z: int): _on_aim_zone_picked(z, kind))
		box.add_child(sgrid)
	elif kind in _PENALTY_KINDS:
		# Penal: el arco de frente en 9 zonas con el arquero (pedido de
		# Wilber). Qué pasa en cada zona: DecisionResolver.
		# aim_penalty_grid_multiplier.
		lbl.text = "Elegí dónde patear. Los ángulos de arriba no los ataja nadie… pero son más fáciles de errar."
		var grid := GoalAimGrid.new()
		grid.zone_picked.connect(func(z: int): _on_aim_zone_picked(z, kind))
		box.add_child(grid)
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var zones := ["◤ Izquierda", "▲ Centro", "Derecha ◥"]
		if kind == "free_kick":
			zones = ["Al primer palo", "Por encima de la barrera", "Al segundo palo"]
		elif kind == "aerial_duel":
			zones = ["Picar abajo ⬇", "Cruzado ⬈", "Peinar 2º palo ⤴"]
		for i in range(3):
			var b := Button.new()
			b.text = zones[i]
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 46)
			b.focus_mode = Control.FOCUS_NONE
			Styles.styled_button(b, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
			var z := i
			b.pressed.connect(func(): _on_aim_zone_picked(z, kind))
			row.add_child(b)
		box.add_child(row)
	# Opción picada de alto riesgo: Panenka en el penal, vaselina en el mano a
	# mano (picarla por encima del arquero que sale a achicar).
	if kind == "penalty" or kind == "one_on_one":
		var pk := Button.new()
		pk.text = "🥄  Picarla (Panenka) — arriesgado" if kind == "penalty" else "🥄  Vaselina por encima del arquero"
		pk.custom_minimum_size = Vector2(0, 42)
		pk.focus_mode = Control.FOCUS_NONE
		Styles.styled_button(pk, Styles.pill_outlined(Styles.RED), Styles.RED)
		pk.pressed.connect(func(): _on_aim_zone_picked(PANENKA_ZONE, kind))
		box.add_child(pk)
	meter_area.add_child(box)
	meter_area.move_child(box, 0)
	_aim_shown_at = Time.get_ticks_msec()

func _on_aim_zone_picked(zone: int, kind: String) -> void:
	_aim_zone = zone
	_aim_tap_ms = Time.get_ticks_msec() - _aim_shown_at
	var aim_box: Node = meter_area.get_node_or_null("MG_Aim")
	if aim_box != null:
		aim_box.queue_free()
	if kind == "aerial_duel":
		_start_header_timing()
		return
	tap_button.visible = true
	# Ahora el timing.
	_start_power_meter(kind)
	if zone == PANENKA_ZONE:
		_tap_hint("Timing PERFECTO o es papelón: soltá justo en la zona.", "tap")
	elif kind == "aerial_duel":
		_tap_hint("Cronometrá el salto: tocá cuando la barra entre en la zona.", "tap")
	else:
		_tap_hint("Ahora clavá el timing del disparo.", "tap")

## Cabezazo (P4): sombra que crece + salto con la animación de cabezazo.
func _start_header_timing() -> void:
	tap_button.visible = false
	_minigame = "header"
	var ht := HeaderTiming.new()
	ht.name = "MG_Header"
	ht.duration = DecisionResolver.header_duration(_chosen_difficulty) * float(_context_mods()[1])
	if MatchState.user_player != null:
		ht.player_cfg = Avatar.celebration_config_for_player(MatchState.user_player, SaveManager.load_world_seed())
	meter_area.add_child(ht)
	meter_area.move_child(ht, 0)
	ht.tapped.connect(func(err_ms: float):
		var precision: float = DecisionResolver.header_timing_precision(err_ms, _chosen_difficulty)
		var clean: bool = precision >= DecisionResolver.CLEAN_HIT
		precision = DecisionResolver.aim_aerial_duel_multiplier(_chosen_difficulty, float(_aim_tap_ms), _aim_zone, precision)
		if clean:
			precision = maxf(precision, DecisionResolver.CLEAN_HIT)
		await get_tree().create_timer(0.7).timeout
		if is_instance_valid(ht):
			ht.queue_free()
		_finish_decision(precision))

# --- 3) Rhythm 3-tap (regate) ---
func _start_rhythm(_kind: String) -> void:
	_tap_hint("Encará: 3 toques al ritmo. Clavá los 3 y pasás limpio.", "tap")
	_rhythm_round = 0
	_rhythm_hits = 0.0
	_next_rhythm_round()

func _next_rhythm_round() -> void:
	if _rhythm_round >= _RHYTHM_ROUNDS:
		_finish_decision(clampf(_rhythm_hits / float(_RHYTHM_ROUNDS), 0.0, 1.0))
		return
	_rhythm_round += 1
	decision_title.text = "Regate  ·  toque %d/%d" % [_rhythm_round, _RHYTHM_ROUNDS]
	_meter_value = 0.0
	_meter_direction = 1
	var d: float = clampf(_chosen_difficulty, 0.0, 1.0)
	_target_width = lerpf(0.34, 0.13, d) * float(_context_mods()[0])
	_meter_speed = MOVE_SPEED * lerpf(1.0, 1.7, d) * (1.0 + 0.12 * _rhythm_round)
	_target_center = randf_range(0.3, 0.7)
	_meter_running = true
	_position_target_zone()

# --- 4) Hold & release (presión / despeje / último hombre) ---
func _start_hold(_kind: String) -> void:
	_tap_hint("MANTENÉ para cargar y SOLTÁ en la zona verde. En la zona = hecho.", "tap_hold")
	_hold_secs = 1.1
	var d: float = clampf(_chosen_difficulty, 0.0, 1.0)
	_hold_target = randf_range(0.52, 0.86) * lerp(1.0, 0.9, 1.0 - float(_context_mods()[0]))
	_hold_value = 0.0
	_hold_active = false
	_target_width = lerpf(0.24, 0.09, d)
	_target_center = _hold_target
	_position_target_zone()
	_update_hold_visual()

func _update_hold_visual() -> void:
	var bg_width: float = power_meter_bg.size.x
	if bg_width <= 0.0:
		bg_width = 600.0
	power_meter_fill.size.x = maxf(_hold_value * bg_width, MARKER_WIDTH)
	power_meter_fill.size.y = power_meter_bg.size.y
	power_meter_fill.position = Vector2(0, 0)

# --- 5) Reflejo (Parte 91i) ---
## Sin barra: esperás una señal que tarda un tiempo IMPREDECIBLE en salir
## (para que no se pueda "cantar" el timing) y tocás lo más rápido posible
## en cuanto sale. Tocar ANTES de la señal es un adelanto — falla directo,
## igual que en la vida real. `_reaction_token` evita que un timer de
## espera viejo (de una decisión ya resuelta) dispare la señal tarde.
func _start_reaction(kind: String) -> void:
	tap_button.visible = true
	_reaction_state = "waiting"
	_reaction_token += 1
	var my_token: int = _reaction_token
	_tap_hint("Esperá la señal — tocar antes de tiempo es un adelanto.", "tap")
	_show_reaction_prompt("Esperá…", Styles.GRAY_TEXT)
	var delay: float = randf_range(0.6, 1.7) * lerpf(1.15, 0.85, clampf(_chosen_difficulty, 0.0, 1.0))
	await get_tree().create_timer(delay).timeout
	if my_token != _reaction_token:
		return  # la decisión ya se resolvió (adelanto o se canceló) mientras esperábamos
	_reaction_state = "go"
	_reaction_go_at_ms = Time.get_ticks_msec()
	_show_reaction_prompt("¡YA!", Styles.GREEN)
	Audio.match_sfx("tick")

func _show_reaction_prompt(text: String, color: Color) -> void:
	var h: Node = meter_area.get_node_or_null("MG_Reaction")
	if h != null:
		meter_area.remove_child(h)
		h.free()
	var lbl := Label.new()
	lbl.name = "MG_Reaction"
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", Styles.font_black())
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", color)
	meter_area.add_child(lbl)
	meter_area.move_child(lbl, 0)

# --- 6) Secuencia (Parte 91i) ---
## 3 botones; se ilumina UNO a la vez en orden al azar con una ventana
## chica de tiempo — tocás el que está iluminado antes de que se apague.
## 3 rondas, el promedio de aciertos es la precisión final (0 en la ronda
## si te la perdés o tocás el equivocado). Pensado para jugadas de "leer
## la opción correcta entre varias", a diferencia del ritmo (puro timing).
func _start_sequence(kind: String) -> void:
	tap_button.visible = false
	_sequence_round = 0
	_sequence_hits = 0.0
	_sequence_active_idx = -1
	_build_sequence_buttons()
	_next_sequence_round()

func _build_sequence_buttons() -> void:
	var box := VBoxContainer.new()
	box.name = "MG_Sequence"
	box.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = "Tocá el botón que se ilumina, antes de que se apague."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	box.add_child(lbl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for i in range(3):
		var b := Button.new()
		b.name = "SeqBtn%d" % i
		b.text = str(i + 1)
		b.custom_minimum_size = Vector2(64, 64)
		b.focus_mode = Control.FOCUS_NONE
		Styles.styled_button(b, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
		var idx := i
		b.pressed.connect(func(): _on_sequence_button_pressed(idx))
		row.add_child(b)
	box.add_child(row)
	meter_area.add_child(box)
	meter_area.move_child(box, 0)

func _next_sequence_round() -> void:
	if _sequence_round >= _SEQUENCE_ROUNDS:
		_finish_decision(clampf(_sequence_hits / float(_SEQUENCE_ROUNDS), 0.0, 1.0))
		return
	_sequence_round += 1
	_sequence_active_idx = randi() % 3
	_sequence_lit_at_ms = Time.get_ticks_msec()
	_set_sequence_button_lit(_sequence_active_idx, true)
	_sequence_token += 1
	var my_token: int = _sequence_token
	var window: float = (_SEQUENCE_WINDOW_MS / 1000.0) * lerpf(1.2, 0.8, clampf(_chosen_difficulty, 0.0, 1.0))
	await get_tree().create_timer(window).timeout
	if my_token != _sequence_token:
		return  # ya se tocó (acierto o error) o se canceló la decisión
	_set_sequence_button_lit(_sequence_active_idx, false)
	_sequence_active_idx = -1
	_next_sequence_round()  # se pasó de largo: 0 en esta ronda

func _on_sequence_button_pressed(idx: int) -> void:
	if _minigame != "sequence" or _sequence_active_idx < 0:
		return
	if idx == _sequence_active_idx:
		var rt: int = Time.get_ticks_msec() - _sequence_lit_at_ms
		_sequence_hits += clampf(1.0 - float(rt) / float(_SEQUENCE_WINDOW_MS), 0.15, 1.0)
		Audio.match_sfx("tick")
	_sequence_token += 1  # invalida el timer de "se pasó de largo" de esta ronda
	_set_sequence_button_lit(_sequence_active_idx, false)
	_sequence_active_idx = -1
	_next_sequence_round()

func _set_sequence_button_lit(idx: int, lit: bool) -> void:
	var box: Node = meter_area.get_node_or_null("MG_Sequence")
	if box == null:
		return
	var row: Node = box.get_child(1) if box.get_child_count() > 1 else null
	if row == null:
		return
	var b: Node = row.get_node_or_null("SeqBtn%d" % idx)
	if b == null:
		return
	Styles.styled_button(b, Styles.pill_filled(Styles.GOLD) if lit else Styles.pill_outlined(Styles.GRAY_TEXT), Color.BLACK if lit else Styles.GRAY_TEXT)

func _tap_hint(text: String, gesture: String = "") -> void:
	# BUG REAL (reporte de Wilber, "se sigue replicando la explicación"):
	# algunos flujos (ej. _on_aim_zone_picked, que llama _start_power_meter
	# y ENSEGUIDA otro _tap_hint más específico, sin frame de por medio)
	# invocan esta función DOS veces seguidas. Con queue_free() (borrado
	# DIFERIDO), el segundo llamado encontraba el nodo "MG_Hint" del primero
	# TODAVÍA vivo (recién puesto en cola, no borrado aún) y Godot, al
	# chocar el nombre en add_child(), lo auto-renombraba a "MG_Hint2" en
	# vez de reemplazarlo — la búsqueda por nombre exacto de la PRÓXIMA
	# llamada nunca encontraba ese "MG_Hint2" huérfano, y quedaban los dos
	# textos apilados hasta el final de la decisión. Borrado INMEDIATO
	# (remove_child + free) en vez de queue_free(): para cuando se agrega
	# el nuevo, el viejo ya no ocupa el nombre.
	var h: Node = meter_area.get_node_or_null("MG_Hint")
	if h != null:
		meter_area.remove_child(h)
		h.free()
	var row := HBoxContainer.new()
	row.name = "MG_Hint"
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if gesture != "" and InputPrompts.has(gesture):
		var ic := InputPrompts.rect(gesture, 26, Styles.GRAY_TEXT)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	var l := Label.new()
	l.text = text
	# Más grande y más claro (10-oct): en el celular casi no se leía.
	l.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	l.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	meter_area.add_child(row)
	meter_area.move_child(row, 0)

func _finish_decision(precision: float) -> void:
	_meter_running = false
	_hold_active = false
	_grade_gesture(clampf(precision, 0.0, 1.0))
	decision_panel.visible = false
	tap_button.visible = true
	for n in meter_area.get_children():
		if String(n.name).begins_with("MG_"):
			n.queue_free()
	if _pitch != null:
		_pitch.stop_shot_aim()
		_pitch.stop_minigame()
	if _pitch != null and _pitch.visible and _pitch_kind != "":
		# La zona que elegiste (si fue un minijuego de apuntar) define a dónde
		# va la pelota en la repetición.
		_pitch_ctx["aim_zone"] = _aim_zone if _minigame == "aim" else -1
		_replay_pending = true
	if MatchState.engine != null:
		var was_slide: bool = _live_slide
		_live_slide = false
		MatchState.engine.resolve_decision({"kind": _chosen_kind, "precision": clampf(precision, 0.0, 1.0), "slide": was_slide})

## CALIFICACIÓN DEL GESTO (10-oct): Perfecto / Bien / Regular / Flojo, con
## racha de aciertos seguidos. Se anota en MatchState.gesture_stats (da XP
## extra en el resumen, ProgressionEngine.gesture_xp).
const _GRADE_LOOK := {
	"perfecto": ["¡PERFECTO!", Color(1.0, 0.84, 0.25)],
	"bueno": ["¡BIEN!", Color(0.4, 0.9, 0.5)],
	"regular": ["REGULAR", Color(0.8, 0.8, 0.85)],
	"flojo": ["FLOJO", Color(0.95, 0.4, 0.35)],
}
func _grade_gesture(precision: float) -> void:
	var grade: String = DecisionResolver.gesture_grade(precision)
	var gs: Dictionary = MatchState.gesture_stats   # mismo diccionario (por referencia)
	gs[grade] = int(gs.get(grade, 0)) + 1
	if DecisionResolver.gesture_keeps_streak(grade):
		gs["streak"] = int(gs.get("streak", 0)) + 1
		gs["best_streak"] = maxi(int(gs.get("best_streak", 0)), int(gs["streak"]))
	else:
		gs["streak"] = 0
	var look: Array = _GRADE_LOOK[grade]
	var text: String = String(look[0])
	if int(gs["streak"]) >= 2:
		text += "  RACHA ×%d" % int(gs["streak"])
	var vp: Vector2 = get_viewport().get_visible_rect().size
	Juice.float_text(self, text, Vector2(vp.x * 0.5 - 110.0, vp.y * 0.42), look[1], 30 if grade == "perfecto" else 24)
	if grade == "perfecto":
		Haptics.hit("success")

func _label_for_kind(kind: String) -> String:
	# Tras elegir la acción (o en un penal), el título es corto: el "cómo"
	# lo explica el hint del medidor ("Toca cuando la barra esté en la zona").
	match kind:
		"shot_on_goal": return "Remate a puerta"
		"key_pass": return "Pase al área"
		"tackle": return "Duelo defensivo"
		"dribble": return "Encarás el 1v1"
		"long_shot": return "Bombazo de lejos"
		"aerial_duel": return "Duelo aéreo"
		"interception": return "Cortás el pase"
		"one_on_one": return "Mano a mano con el arquero"
		"free_kick": return "Tiro libre directo"
		"through_ball": return "Pase filtrado"
		"last_ditch_tackle": return "Entrada de último hombre"
		"clearance": return "Despeje del área"
		"pressing": return "Presión alta"
		"penalty": return "¡Penal para tu equipo!"
		"penalty_save", "penalty_save_shootout": return "¡Penal en contra! Vos en el arco"
		"penalty_shootout": return "Tanda de penales"
		"volley": return "Volea"
		"chip_shot": return "Globito al arquero"
		"cutback": return "Pase atrás desde el fondo"
		"cross": return "Centro al área"
		"one_two": return "Pared con un compañero"
		"counter_run": return "Contragolpe"
		"switch_play": return "Cambio de frente"
		"recovery_tackle": return "Recuperación en transición"
		"distribution": return "Salida en largo"
		"block_shot": return "Bloqueo con el cuerpo"
		"one_on_one_save": return "Mano a mano con el rival"
		"sweep_keeper": return "Salida del arquero"
		_: return "Momento clave"

func _position_target_zone() -> void:
	var bg_width := power_meter_bg.size.x
	if bg_width <= 0.0:
		bg_width = 600.0 # fallback antes del primer layout pass
	target_zone.position.x = (_target_center - _target_width * 0.5) * bg_width
	target_zone.size.x = _target_width * bg_width
	target_zone.size.y = power_meter_bg.size.y

const MARKER_WIDTH := 8.0

func _update_power_meter_visual() -> void:
	var bg_width := power_meter_bg.size.x
	if bg_width <= 0.0:
		bg_width = 600.0
	# El marcador es una BARRITA fina que barre (no un relleno que tape la
	# zona verde) — pedido explícito. Se dibuja encima de TargetZone.
	power_meter_fill.size.x = MARKER_WIDTH
	power_meter_fill.size.y = power_meter_bg.size.y
	power_meter_fill.position.x = clampf(_meter_value * bg_width - MARKER_WIDTH * 0.5, 0.0, bg_width - MARKER_WIDTH)
	power_meter_fill.position.y = 0.0

## Precisión del toque. DENTRO de la zona verde SIEMPRE devuelve ≥ CLEAN_HIT
## (0.82 al borde, 1.0 al centro) → la acción se consigue sí o sí. Fuera de
## la zona, cae rápido en un margen chico (media chance) y luego a 0.
func _meter_precision() -> float:
	var half: float = maxf(_target_width * 0.5, 0.001)
	var distance: float = abs(_meter_value - _target_center)
	if distance <= half:
		return lerpf(1.0, 0.82, distance / half)
	var over: float = distance - half
	return clampf(0.70 - over / (half + 0.06) * 0.70, 0.0, 0.70)

func _on_tap_pressed() -> void:
	# En "hold" el disparo lo maneja button_up. "sequence" tiene sus PROPIOS
	# botones (no pasa por tap_button en absoluto).
	if _minigame == "hold" or _minigame == "pitch_shot_hold" or _minigame == "sequence":
		return
	if _minigame == "reaction":
		# Sin barra que "esté corriendo" — el toque puede llegar en
		# cualquier momento (esperando o ya armado), a diferencia de los
		# demás minijuegos que ignoran el toque si no hay nada corriendo.
		_reaction_token += 1  # invalida el timer de espera pendiente
		if _reaction_state != "go":
			Audio.match_sfx("decision_fail")
			_finish_decision(0.0)  # te adelantaste a la señal
		else:
			Audio.match_sfx("tick")
			var rt: int = Time.get_ticks_msec() - _reaction_go_at_ms
			_finish_decision(clampf(1.0 - float(rt - 120) / 480.0, 0.0, 1.0))
		return
	if not _meter_running:
		return
	_meter_running = false
	Audio.match_sfx("tick")

	if _minigame == "rhythm":
		var pr: float = _meter_precision()
		_rhythm_hits += pr
		if pr >= 0.5:
			Audio.match_sfx("decision_ok")
		await get_tree().create_timer(0.28).timeout
		_next_rhythm_round()
		return

	var precision: float = _meter_precision()
	if _minigame == "pitch_shot_bar" or _minigame == "pitch_pass_bar":
		var bar: float = precision
		precision = DecisionResolver.pitch_aim_bar_precision(bar, _pitch_aim_score)
		if _minigame == "pitch_shot_bar":
			# Barra pasada de largo + toque flojo = por encima del travesaño.
			_pitch_ctx["shot_high"] = bar < DecisionResolver.CLEAN_HIT and _meter_value > _target_center
		_finish_decision(precision)
		return
	# Regla de Wilber: si CLAVÁS la zona verde, la acción entra sí o sí. Los
	# ajustes de puntería/duelo de abajo pueden MEJORAR o acercar un toque
	# flojo, pero NUNCA convertir un toque limpio en fallo. Antes el "arquero
	# adivinó tu palo" (o perder el duelo aéreo) tiraba la precisión por
	# debajo de CLEAN_HIT aun con timing perfecto → "le atino al verde y
	# marca fallo".
	var clean_hit: bool = precision >= DecisionResolver.CLEAN_HIT
	if _minigame == "aim" and _aim_zone == PANENKA_ZONE:
		# Panenka: elección de riesgo — con mal timing ES papelón (esto SÍ
		# puede fallar, es el trato de picarla).
		if precision >= DecisionResolver.CLEAN_HIT:
			precision = clampf(precision * 1.2, 0.0, 1.0)
			Audio.match_sfx("decision_ok")
		else:
			precision *= 0.22
			clean_hit = false
	elif _minigame == "aim" and _chosen_kind == "aerial_duel":
		# Cabezazo: ganarle el salto al marcador (fórmula centralizada en
		# DecisionResolver, ver nota de la auditoría ahí).
		precision = DecisionResolver.aim_aerial_duel_multiplier(_chosen_difficulty, float(_aim_tap_ms), _aim_zone, precision)
	elif _minigame == "aim" and _aim_kind in ["penalty_save", "penalty_save_shootout"]:
		# Atajada: adivinar el lado + reflejo (DecisionResolver).
		precision = DecisionResolver.penalty_save_multiplier(_aim_zone, precision)
		_pitch_ctx["aim_zone"] = _aim_zone
	elif _minigame == "aim" and _aim_zone >= 0 and _aim_kind in _PENALTY_KINDS:
		# Penal en 9 zonas (fórmula centralizada en DecisionResolver).
		precision = DecisionResolver.aim_penalty_grid_multiplier(_chosen_difficulty, float(_aim_tap_ms), _aim_zone, precision)
	elif _minigame == "aim" and _aim_zone >= 0:
		# El arquero adivina un palo (fórmula centralizada en DecisionResolver).
		precision = DecisionResolver.aim_shot_gk_multiplier(_chosen_difficulty, float(_aim_tap_ms), _aim_zone, precision)
	# Piso: un toque limpio sigue siendo limpio pase lo que pase arriba.
	if clean_hit:
		precision = maxf(precision, DecisionResolver.CLEAN_HIT)
	_finish_decision(precision)

func _on_tap_down() -> void:
	if _minigame != "hold" and _minigame != "pitch_shot_hold":
		return
	_hold_active = true
	_hold_value = 0.0

func _on_tap_up() -> void:
	if _minigame == "pitch_shot_hold" and _hold_active:
		_hold_active = false
		Audio.match_sfx("tick")
		var bar: float = DecisionResolver.shot_power_precision(_hold_value, _hold_target, _target_width)
		# Pasado de fuerza y fuera de la zona = por encima del travesaño.
		_pitch_ctx["shot_high"] = bar < DecisionResolver.GRADE_GOOD and _hold_value > _hold_target
		# La ALTURA la elegís con la fuerza: primera mitad de la zona verde =
		# rasante (esquina de abajo), segunda mitad = arriba (al ángulo).
		_pitch_ctx["shot_level"] = "high" if _hold_value >= _hold_target else "low"
		_finish_decision(DecisionResolver.strike_precision(DecisionResolver.pitch_aim_bar_precision(bar, _pitch_aim_score), _strike))
		return
	if _minigame != "hold" or not _hold_active:
		return
	_hold_active = false
	Audio.match_sfx("tick")
	# Mismo criterio que _meter_precision: soltar dentro de la banda = hecho.
	var half: float = maxf(_target_width * 0.5, 0.001)
	var distance: float = abs(_hold_value - _hold_target)
	var precision: float
	if distance <= half:
		precision = lerpf(1.0, 0.82, distance / half)
	else:
		precision = clampf(0.70 - (distance - half) / (half + 0.06) * 0.70, 0.0, 0.70)
	_finish_decision(precision)

var _ht_tabs: HBoxContainer = null
var _ht_stats: Dictionary = {}
var _ht_tab: String = "stats"
var _ht_gh: int = 0
var _ht_ga: int = 0

func _show_halftime(payload: Dictionary) -> void:
	_refresh_talk_button()
	# Descanso REAL: el motor se queda esperando (await) hasta que se pulsa
	# "Empezar 2do tiempo" — no es solo un cartel, para el reloj de verdad.
	var gh: int = int(payload.get("home", 0))
	var ga: int = int(payload.get("away", 0))
	var extra_time_break: bool = bool(payload.get("extra_time", false))
	var break_title := "DESCANSO DE LA PRÓRROGA" if extra_time_break else "DESCANSO"
	var break_minute := 105 if extra_time_break else 45
	event_log.append_text("[b]— %s %d-%d (%d') —[/b]\n" % [break_title, gh, ga, break_minute])
	var carry: Dictionary = MatchState.engine._tie_carry if MatchState.engine != null else {}
	var show_global := MatchState.engine != null and MatchState.engine._has_tie_carry
	var global_home: int = gh + int(carry.get("home", 0))
	var global_away: int = ga + int(carry.get("away", 0))
	continue_second_half_button.text = "Empezar 2º tiempo extra" if extra_time_break else "Empezar 2º tiempo"
	halftime_score_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	halftime_panel.anchors_preset = Control.PRESET_FULL_RECT
	halftime_panel.offset_left = 12
	halftime_panel.offset_top = 12
	halftime_panel.offset_right = -12
	halftime_panel.offset_bottom = -12
	var hp := Styles.card_accent(Styles.GOLD, Color(0.09, 0.10, 0.13), 18)
	hp.border_width_top = 3
	hp.border_color = Styles.GOLD
	halftime_panel.add_theme_stylebox_override("panel", hp)

	# Cabecera con escudos + marcador.
	for c in halftime_score_label.get_children():
		c.queue_free()
	halftime_score_label.text = ""
	halftime_score_label.custom_minimum_size = Vector2(0, 52)
	var hdr := HBoxContainer.new()
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr.add_theme_constant_override("separation", 16)
	hdr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var hb := _side_crest(true, 40)
	var sc := Label.new()
	sc.text = "%s   %d - %d%s" % [break_title, gh, ga,
		(" · GLOBAL %d - %d" % [global_home, global_away]) if show_global else ""]
	sc.add_theme_font_override("font", Styles.font_black())
	sc.add_theme_font_size_override("font_size", 24)
	var ab := _side_crest(false, 40)
	hdr.add_child(hb)
	hdr.add_child(sc)
	hdr.add_child(ab)
	halftime_score_label.add_child(hdr)

	_ht_stats = payload.get("stats", {})
	_ht_gh = gh
	_ht_ga = ga
	_ht_tab = "stats"
	_render_halftime()
	halftime_panel.visible = true

func _crest_short(is_home: bool) -> String:
	var world: Dictionary = WorldTickEngine.world
	var id: String = MatchState.fixture.get("home_club_id" if is_home else "away_club_id", "")
	var c := WorldFactory.find_club(world, id)
	return c.short_name if c != null else "?"

## Botón de ARENGA de capitán (P4): se arma al mostrar el entretiempo
## (recién ahí se sabe si estás en cancha).
func _refresh_talk_button() -> void:
	var vbox: VBoxContainer = $HalftimePanel/VBox
	var old := vbox.get_node_or_null("TalkButton")
	if old != null:
		old.queue_free()
	if MatchState.engine != null and MatchState.engine.has_method("can_captain_talk") and MatchState.engine.can_captain_talk():
		var talk := Button.new()
		talk.name = "TalkButton"
		talk.text = "📣  Arengar al equipo (sos el capitán)"
		talk.custom_minimum_size = Vector2(0, 48)
		talk.focus_mode = Control.FOCUS_NONE
		var cap_icon := "res://assets/ui/captain.png"
		if ResourceLoader.exists(cap_icon):
			talk.icon = load(cap_icon)
			talk.add_theme_constant_override("icon_max_width", 30)
			talk.text = "  Arengar al equipo (sos el capitán)"
		Styles.styled_button(talk, Styles.pill_filled(Styles.GOLD), Color.BLACK)
		talk.pressed.connect(func():
			if MatchState.engine.captain_team_talk():
				talk.queue_free()
				_show_team_talk())
		vbox.add_child(talk)
		vbox.move_child(talk, continue_second_half_button.get_index())
		talk.ready.connect(func(): Juice.pulse(talk, 1.03))

func _build_halftime_body() -> void:
	var vbox: VBoxContainer = $HalftimePanel/VBox
	vbox.add_theme_constant_override("separation", 10)

	_ht_tabs = HBoxContainer.new()
	_ht_tabs.add_theme_constant_override("separation", 6)
	for pair in [["Estadísticas", "stats"], ["Otros partidos", "others"], ["Consumibles", "items"]]:
		var b := Button.new()
		b.text = pair[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(t = pair[1]): _ht_tab = t; _render_halftime())
		_ht_tabs.add_child(b)
	vbox.add_child(_ht_tabs)
	vbox.move_child(_ht_tabs, continue_second_half_button.get_index())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ht_body = VBoxContainer.new()
	_ht_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ht_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_ht_body)
	vbox.add_child(scroll)
	vbox.move_child(scroll, continue_second_half_button.get_index())

## Tu gol: BENGALAS en las esquinas + la tribuna salta (P6, 10-oct).
func _goal_flares() -> void:
	if Preferences.reduce_motion:
		return
	var layer := CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	var tex: Texture2D = load("res://assets/ui/flare.png") if ResourceLoader.exists("res://assets/ui/flare.png") else null
	if tex != null:
		var xs: Array = [0.04, 0.16, 0.84, 0.96]
		for i in range(xs.size()):
			var fl := TextureRect.new()
			fl.texture = tex
			fl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			fl.size = Vector2(48, 96)
			fl.position = Vector2(size.x * float(xs[i]) - 24.0, size.y - 120.0 + (i % 2) * 14.0)
			fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(fl)
			var tw := fl.create_tween().set_loops(8)
			tw.tween_property(fl, "modulate", Color(1.3, 1.1, 1.0, 1.0), randf_range(0.08, 0.16))
			tw.tween_property(fl, "modulate", Color(0.85, 0.7, 0.7, 0.9), randf_range(0.08, 0.16))
	# La tribuna salta.
	if _stadium_bg != null and is_instance_valid(_stadium_bg):
		var y0: float = _stadium_bg.position.y
		var jt := _stadium_bg.create_tween().set_loops(5)
		jt.tween_property(_stadium_bg, "position:y", y0 - 6.0, 0.12)
		jt.tween_property(_stadium_bg, "position:y", y0, 0.12)
	var end := layer.create_tween()
	end.tween_interval(2.8)
	end.tween_callback(layer.queue_free)

## CANTO de la hinchada con tu apodo (P5, 9-oct): cartel arriba con la
## bufanda/megáfono; si todavía no tenés apodo, cantan tu apellido.
const _CHANTS := ["¡Olé, olé, olé, %s, %s!", "¡Y dale, dale, dale %s!", "¡%s, %s, el más grande!", "¡Que de la mano de %s todos la vuelta vamos a dar!"]
func _crowd_chant() -> void:
	var p: PlayerData = MatchState.user_player
	if p == null:
		return
	var nm: String = Nickname.press_name(p, SaveManager.load_world_seed())
	var line: String = _CHANTS[_rng.randi() % _CHANTS.size()]
	line = line % ([nm, nm] if line.count("%s") == 2 else [nm])
	var layer := CanvasLayer.new()
	layer.layer = 96
	add_child(layer)
	var panel := PanelContainer.new()
	var sb := Styles.card_flat(Color(0.5, 0.05, 0.08, 0.92), 16)
	sb.set_border_width_all(2)
	sb.border_color = Styles.GOLD
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.position.y = 20
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var ic := Icons.make_rect("res://assets/ui/chant.png", 40)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(ic)
	var l := Label.new()
	l.text = "🎵 " + line
	l.add_theme_font_override("font", Styles.font_black())
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	panel.add_child(row)
	layer.add_child(panel)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.6)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(layer.queue_free)

## TRIBUNA (10-oct, Wilber: "hinchas con memoria" + "familia en la
## tribuna"): al arrancar, si toca, un corte a la tribuna con las pancartas
## con tu nombre/apodo (o los silbidos) y, en partidos clave, tus padres.
## ANTES DEL SAQUE (10-oct, bug reportado por Wilber: "cuando va la familia
## al estadio tapa toda la pantalla y no deja hacer bien las jugadas").
## Causa: el corte a la tribuna salía 1,7 s DESPUÉS del saque, en una capa
## por encima de todo, y si justo llegaba tu jugada la tapaba. Ahora el
## tifo del clásico y la tribuna/familia se muestran y TERMINAN antes de
## que arranque el motor del partido.
func _pre_kickoff_show() -> void:
	if MatchState.engine == null or MatchState.engine.instant_mode:
		return
	if bool(MatchState.fixture.get("derby", false)) and ResourceLoader.exists("res://assets/scenes/tifo.png"):
		_show_tifo()
		await get_tree().create_timer(2.3).timeout
	if _queue_stands_moment(0.05):
		await get_tree().create_timer(3.5).timeout

func _queue_stands_moment(delay: float) -> bool:
	var p: PlayerData = MatchState.user_player
	if p == null:
		return false
	var seed_i: int = SaveManager.load_world_seed()
	var home: bool = _user_side_is(true)
	var derby: bool = bool(MatchState.fixture.get("derby", false))
	var fs: int = int(WorldTickEngine.season.get("fan_sentiment", InterviewEngine.FAN_DEFAULT))
	var num: int = Kit.suggested_number(p.position, "%s|%d" % [p.player_name, seed_i])
	# Ex club (v34): de visitante en una cancha donde jugaste.
	var ex_rec: String = ""
	if not _is_national_fixture() and not home:
		var w_ex: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(seed_i)
		ex_rec = ImmersionEngine.ex_club_reception(p, w_ex, String(MatchState.fixture.get("home_club_id", "")), seed_i)
	var crowd: Dictionary = {} if _is_national_fixture() else ImmersionEngine.crowd_banners(p, seed_i, fs, home, derby, num, ex_rec)
	var kind: String = ImmersionEngine.key_match_kind(MatchState.fixture, p)
	var has_crowd: bool = not crowd.is_empty() and String(crowd.get("kind", "")) != ""
	if not has_crowd and kind == "":
		return false
	if has_crowd:
		event_log.append_text("[color=%s]%s[/color]\n" % ["#ff8080" if String(crowd["kind"]) == "boo" else "#9fe39f", String(crowd["line"])])
	if kind != "":
		event_log.append_text("[color=#ff8fb1]Tu familia está en la tribuna.[/color]\n")
	var t := get_tree().create_timer(delay)
	t.timeout.connect(_show_stands_moment.bind(crowd if has_crowd else {}, kind))
	return true

func _show_stands_moment(crowd: Dictionary, family_kind: String) -> void:
	var p: PlayerData = MatchState.user_player
	if p == null or not is_inside_tree():
		return
	var seed_i: int = SaveManager.load_world_seed()
	var layer := CanvasLayer.new()
	layer.layer = 93
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	# Franja de tribuna: fondo oscuro con "público" (cabezas + torsos con
	# los colores del club; rojos si silban).
	var band_h: float = 250.0
	var band := Control.new()
	band.position = Vector2(0, vp.y * 0.30)
	band.size = Vector2(vp.x, band_h)
	band.clip_contents = true
	root.add_child(band)
	var kit_a: Color = Color(Avatar.user_kit_hex) if Avatar.user_kit_hex != "" else Styles.BLUE
	var kit_b: Color = Color(Avatar.user_kit2_hex) if Avatar.user_kit2_hex != "" else Color.WHITE
	var boo: bool = String(crowd.get("kind", "")) == "boo"
	band.draw.connect(func():
		band.draw_rect(Rect2(Vector2.ZERO, band.size), Color(0.05, 0.05, 0.07, 0.94))
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for row in range(9):
			var y: float = 12.0 + row * 26.0
			band.draw_rect(Rect2(0, y + 16, band.size.x, 3), Color(1, 1, 1, 0.05))
			var x: float = rng.randf_range(0, 10)
			while x < band.size.x:
				var c: Color = Color(0.85, 0.2, 0.2) if (boo and rng.randf() < 0.5) else (kit_a if rng.randf() < 0.55 else kit_b)
				c = c.darkened(rng.randf_range(0.25, 0.6))
				band.draw_circle(Vector2(x, y + 6), 5.0, Color(0.85, 0.7, 0.55).darkened(rng.randf_range(0.2, 0.6)))
				band.draw_rect(Rect2(x - 6, y + 11, 12, 9), c)
				x += rng.randf_range(13, 19)
		band.draw_rect(Rect2(0, 0, band.size.x, 3), kit_a)
		band.draw_rect(Rect2(0, band.size.y - 3, band.size.x, 3), kit_a))
	# Pancartas.
	var banners: Array = crowd.get("banners", [])
	for i in range(banners.size()):
		var bp := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.92, 0.9, 0.85) if boo else (kit_a if i % 2 == 0 else kit_b)
		sb.border_color = Color(0.1, 0.1, 0.1) if boo else (kit_b if i % 2 == 0 else kit_a)
		sb.set_border_width_all(4)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		bp.add_theme_stylebox_override("panel", sb)
		var bl := Label.new()
		bl.text = String(banners[i])
		bl.add_theme_font_override("font", Styles.font_black())
		bl.add_theme_font_size_override("font_size", 22)
		var ink: Color = Color(0.75, 0.05, 0.05) if boo else (Color.BLACK if sb.bg_color.get_luminance() > 0.55 else Color.WHITE)
		bl.add_theme_color_override("font_color", ink)
		bp.add_child(bl)
		band.add_child(bp)
		bp.position = Vector2(18 + i * vp.x * 0.30, 14 + i * 58)
		bp.rotation = deg_to_rad(-3.0 if i % 2 == 0 else 2.5)
		var r0: float = bp.rotation
		var wob := bp.create_tween().set_loops(4)
		wob.tween_property(bp, "rotation", r0 + deg_to_rad(1.5), 0.35)
		wob.tween_property(bp, "rotation", r0, 0.35)
	# Familia.
	if family_kind != "":
		var fam := HBoxContainer.new()
		fam.add_theme_constant_override("separation", 6)
		var pcfg: Dictionary = Avatar.config_for_player(p, seed_i)
		for role in ["mother", "father"]:
			var fcfg: Dictionary = Avatar.with_expression(ImmersionEngine.parent_config(pcfg, role, p.player_name, seed_i), "feliz")
			fam.add_child(Styles.portrait_frame(Avatar.build(fcfg, 64), 64, Color("#ff8fb1")))
		var partner: String = String(p.partner.get("name", "")) if p.partner is Dictionary else ""
		if partner != "":
			fam.add_child(Styles.portrait_frame(Avatar.build(Avatar.config_for_npc(partner, "partner", seed_i), 64), 64, Color("#ff8fb1")))
		band.add_child(fam)
		var n_faces: int = fam.get_child_count()
		var fam_w: float = n_faces * 70.0 + (n_faces - 1) * 6.0
		fam.position = Vector2(vp.x - fam_w - 14.0, band_h - 100.0) if not banners.is_empty() else Vector2((vp.x - fam_w) * 0.5, band_h * 0.5 - 30.0)
		# Cartel ARRIBA de las caras (al costado se cortaba contra el borde).
		var fl := Label.new()
		fl.text = "TU FAMILIA EN LA TRIBUNA"
		fl.add_theme_font_override("font", Styles.font_black())
		fl.add_theme_font_size_override("font_size", 13)
		fl.add_theme_color_override("font_color", Color("#ff8fb1"))
		fl.add_theme_color_override("font_outline_color", Color.BLACK)
		fl.add_theme_constant_override("outline_size", 6)
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fl.size = Vector2(260, 18)
		fl.position = Vector2(fam.position.x + fam_w - 260.0, fam.position.y - 20.0)
		band.add_child(fl)
	var tag := Label.new()
	tag.text = "SILBIDOS" if boo else "LA TRIBUNA"
	tag.add_theme_font_override("font", Styles.font_black())
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", Styles.RED if boo else Styles.GOLD)
	tag.position = Vector2(12, band_h - 22)
	band.add_child(tag)
	root.modulate.a = 0.0
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.6)
	tw.tween_property(root, "modulate:a", 0.0, 0.4)
	tw.tween_callback(layer.queue_free)

## CLÁSICO (P5): la tribuna con el tifo y bengalas al arranque, 2 s.
func _show_tifo() -> void:
	if not ResourceLoader.exists("res://assets/scenes/tifo.png"):
		return
	var layer := CanvasLayer.new()
	layer.layer = 94
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/scenes/tifo.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var lbl := Label.new()
	lbl.text = "¡CLÁSICO!"
	lbl.add_theme_font_override("font", Styles.font_black())
	lbl.add_theme_font_size_override("font_size", 54)
	lbl.add_theme_color_override("font_color", Styles.GOLD)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 12)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(lbl)
	Haptics.hit("big")
	root.modulate.a = 0.0
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func(): Juice.pop(lbl, 1.25, 0.5))
	tw.tween_interval(1.9)
	tw.tween_property(root, "modulate:a", 0.0, 0.4)
	tw.tween_callback(layer.queue_free)

## Escena de la arenga: vestuario + tu jugador arengando (PixelLab).
func _show_team_talk() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var bg := TextureRect.new()
	if ResourceLoader.exists("res://assets/scenes/locker.png"):
		bg.texture = load("res://assets/scenes/locker.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.25)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(veil)
	if MatchState.user_player != null and Avatar.has_anim("arenga"):
		var cfg: Dictionary = Avatar.celebration_config_for_player(MatchState.user_player, SaveManager.load_world_seed())
		# En primer plano, delante de la mesa (pies a 57/68 del lienzo).
		var anim := Avatar.build_anim(cfg, "arenga", 440, true, 9.0)
		anim.custom_minimum_size = Vector2(440, 440)
		anim.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		anim.position = Vector2(-220, -440.0 * 57.0 / 68.0 - 150.0)
		root.add_child(anim)
	var lbl := Label.new()
	lbl.text = "¡VAMOS, MUCHACHOS!
Este partido lo damos vuelta juntos."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", Styles.font_black())
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Styles.GOLD)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl.position.y = 70
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(lbl)
	var fx := Label.new()
	fx.text = "+6% ataque del equipo · +1 a tus acciones en el 2º tiempo"
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx.add_theme_color_override("font_color", Styles.GREEN)
	fx.add_theme_color_override("font_outline_color", Color.BLACK)
	fx.add_theme_constant_override("outline_size", 6)
	fx.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	fx.position.y = -90
	fx.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(fx)
	Audio.play("celebrate")
	Haptics.hit("big")
	Juice.pop(lbl, 1.2)
	await get_tree().create_timer(2.6).timeout
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.35)
	tw.tween_callback(layer.queue_free)

func _render_halftime() -> void:
	# resaltar la viñeta activa
	var keys := ["stats", "others", "items"]
	for i in range(_ht_tabs.get_child_count()):
		var b: Button = _ht_tabs.get_child(i)
		Styles.tab(b, keys[i] == _ht_tab, true)

	for c in _ht_body.get_children():
		c.queue_free()
	match _ht_tab:
		"others":
			_ht_render_others()
		"items":
			_ht_render_items()
		_:
			_ht_render_stats()

func _ht_render_stats() -> void:
	# Misma vista EXTENDIDA que el resumen final (MatchStatsView).
	var key: String = "%s|%d" % [String(MatchState.fixture.get("home_club_id", "")), SaveManager.load_world_seed()]
	MatchStatsView.render(_ht_body, _ht_stats, _ht_gh, _ht_ga, key, _home_color, _away_color, true)

func _ht_render_others() -> void:
	var others: Array = WorldTickEngine.other_matchday_scores(MatchState.fixture, 0.5)
	if others.is_empty():
		var e := Label.new()
		e.text = "Sin otros partidos de la jornada."
		UiKit.empty_icon(e, Icons.PX_CALENDAR)
		e.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		_ht_body.add_child(e)
		return
	for m in others:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", Styles.card(Styles.CARD_DARK, 6))
		var mm := MarginContainer.new()
		for s in ["left", "right"]:
			mm.add_theme_constant_override("margin_" + s, 10)
		for s in ["top", "bottom"]:
			mm.add_theme_constant_override("margin_" + s, 6)
		var hb := HBoxContainer.new()
		var lh := Label.new(); lh.text = String(m["home_name"]); lh.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lh.clip_text = true
		var mid := Label.new(); mid.text = " %d - %d " % [int(m["gh"]), int(m["ga"])]; mid.add_theme_font_override("font", Styles.font_semibold())
		var la := Label.new(); la.text = String(m["away_name"]); la.size_flags_horizontal = Control.SIZE_EXPAND_FILL; la.clip_text = true; la.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hb.add_child(lh); hb.add_child(mid); hb.add_child(la)
		mm.add_child(hb); row.add_child(mm)
		_ht_body.add_child(row)
	var note := Label.new()
	note.text = "Marcadores provisionales, el partido sigue."
	note.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	note.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	_ht_body.add_child(note)

func _ht_render_items() -> void:
	var player: PlayerData = MatchState.user_player
	if _ht_energy_used:
		var l := Label.new()
		l.text = "Bebiste el energizante — menos desgaste en la 2ª parte."
		l.add_theme_color_override("font_color", Styles.GOLD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ht_body.add_child(l)
		return
	var n: int = int(player.consumables.get("energy_drink", 0)) if player != null else 0
	if n <= 0:
		var e := Label.new()
		e.text = "No tenés consumibles de entretiempo. Comprá bebidas energizantes en la Tienda."
		UiKit.empty_icon(e, Icons.PX_SHOP)
		e.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ht_body.add_child(e)
		return
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 14)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var t := Label.new(); t.text = "Bebida energizante  x%d" % n; t.add_theme_font_override("font", Styles.font_semibold())
	var d := Label.new(); d.text = "Recuperás energía: menos fatiga el resto del partido."
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; d.add_theme_color_override("font_color", Styles.GRAY_TEXT); d.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.text = "Usar ahora"
	Styles.styled_button(btn, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	btn.pressed.connect(func(): _on_energy_drink_pressed(); _render_halftime())
	v.add_child(t); v.add_child(d); v.add_child(btn)
	m.add_child(v); card.add_child(m)
	_ht_body.add_child(card)


func _on_energy_drink_pressed() -> void:
	var player: PlayerData = MatchState.user_player
	if player == null:
		return
	var res: Dictionary = ShopEngine.use_halftime(player)
	if not res.get("ok", false):
		return
	_ht_energy_used = true
	if MatchState.engine != null:
		MatchState.engine.set_fatigue_relief(float(res.get("relief", 0.0)))
	SaveManager.save_player(player)
	event_log.append_text("[color=gold]Bebida energizante: menos desgaste en la 2ª parte.[/color]\n")
	if _ht_tabs != null:
		_render_halftime()
	_refresh_energy_button()

func _on_continue_second_half_pressed() -> void:
	halftime_panel.visible = false
	_match_live = true
	_show_ambient()
	if MatchState.engine != null:
		MatchState.engine.continue_second_half()

func _on_match_finished(_result: Dictionary) -> void:
	_match_live = false
	# Dejar ver el pitazo final en la cancha (Paquete 3) antes de ir al resumen.
	if _pitch != null and _pitch.visible:
		await get_tree().create_timer(1.6).timeout
	Audio.crowd_stop()
	# El resumen (marcador, stats, entrenador, zona mixta) vive en su
	# propia pantalla — MatchSummary lee MatchState.match_result, que ya
	# quedó guardado en _ready() antes de llamar aquí.
	decision_panel.visible = false
	# Selecciones nacionales (Fase 5): un partido de selección usa
	# fixture["home_country"]/["away_country"] en vez de
	# ["home_club_id"]/["away_club_id"] — MatchSummary asume lo segundo
	# (objetivos de temporada, standings de club, etc., nada de lo cual
	# tiene sentido para un partido de selección), así que va a su propio
	# resumen chico (NationalMatchSummary). Cualquier partido de CLUB
	# nunca tiene competition en este set, cero cambio de comportamiento.
	var comp: String = String(MatchState.fixture.get("competition", ""))
	if comp in ["qualifying", "world_cup", "national_cup"]:
		get_tree().change_scene_to_file("res://scenes/NationalMatchSummary/NationalMatchSummary.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/MatchSummary/MatchSummary.tscn")

func _refresh_score() -> void:
	if MatchState.engine == null:
		return
	var score: Dictionary = MatchState.engine.get_live_score()
	var txt: String = "%d - %d" % [int(score.get("home", 0)), int(score.get("away", 0))]
	if _pitch != null:
		_pitch.score_text = txt   # el marcador del estadio
	# Cambió el marcador → el número salta (P1b #13).
	if score_label.text != txt and score_label.text != "":
		score_label.text = txt
		Juice.pop(score_label, 1.4, 0.45)
	else:
		score_label.text = txt
	_refresh_aggregate_score()


func _refresh_aggregate_score() -> void:
	if _aggregate_score_label == null:
		return
	var carry: Dictionary = MatchState.fixture.get("tie_agg", {})
	var score: Dictionary = MatchState.engine.get_live_score() if MatchState.engine != null else {}
	_aggregate_score_label.text = "GLOBAL  %d - %d" % [
		int(carry.get("home", 0)) + int(score.get("home", 0)),
		int(carry.get("away", 0)) + int(score.get("away", 0))]

func _refresh_live_stats() -> void:
	if MatchState.engine == null:
		return
	var rating: float = MatchState.engine.get_live_rating()
	var g: int = MatchState.engine.get_user_goals()
	var a: int = MatchState.engine.get_user_assists()
	var col: Color = Styles.GREEN if rating >= 7.0 else (Styles.AMBER if rating >= 6.0 else Styles.RED)
	rating_big.text = "%.1f" % rating
	rating_big.add_theme_color_override("font_color", col)
	goals_label.text = "Goles %d   ·   Asist. %d" % [g, a]

# ============================================================
#  CANCHA 2D (Paquete 1 del ROADMAP)
# ============================================================

func _build_pitch() -> void:
	_pitch = PitchView.new()
	_pitch.night = _stadium_variant == "night"
	# Césped del estadio local (mismo corte cada vez que se juega ahí).
	_pitch.grass_for(String(MatchState.fixture.get("home_club_id", MatchState.fixture.get("home_country", "neutral"))))
	_pitch.weather = MatchIcons.weather_for(MatchState.fixture, SaveManager.load_world_seed())
	_pitch.custom_minimum_size = Vector2(0, 300)
	_pitch.visible = false
	_pitch.cam_mode = "arco"
	var vb := event_log.get_parent()
	vb.add_child(_pitch)
	# UNA SOLA CÁMARA (11-oct, Wilber: "lo sensato sería dejar solo 1 cámara,
	# la original"): se quitó el botón que cambiaba entre las 3 vistas. El
	# código de "tv" e "iso" sigue en PitchView (lo usan las pruebas), pero
	# el partido siempre usa "arco".
	# CANCHA COMPLETA (10-oct): "Ver todo" aleja hasta mostrar la cancha
	# entera; otro toque vuelve a la jugada. (Además: un dedo mueve la
	# cámara, dos dedos acercan/alejan.)
	var all_btn := Button.new()
	all_btn.name = "WholePitchButton"
	all_btn.text = "Ver todo"
	all_btn.focus_mode = Control.FOCUS_NONE
	all_btn.add_theme_font_size_override("font_size", 11)
	all_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	all_btn.offset_left = -96.0
	all_btn.offset_right = -6.0
	all_btn.offset_top = 40.0
	all_btn.offset_bottom = 70.0
	Styles.styled_button(all_btn, Styles.card_flat(Color(0, 0, 0, 0.55), 10), Color.WHITE)
	all_btn.pressed.connect(func():
		if _pitch.cam_is_home():
			_pitch.show_whole_pitch(true)
		else:
			_pitch.reset_camera(true))
	_pitch.add_child(all_btn)
	vb.move_child(_pitch, event_log.get_index())
	_pitch_ctx = _build_pitch_context()
	# Los 22 de la cancha son los titulares de verdad (cara, pelo y ritmo).
	_pitch.team_people = {"us": _pitch_ctx.get("mates", []), "them": _pitch_ctx.get("rivals", []),
		"our_gk": _pitch_ctx.get("our_gk", {}), "their_gk": _pitch_ctx.get("their_gk", {})}
	_pitch.set_weather(MatchIcons.weather_for(MatchState.fixture, SaveManager.load_world_seed()))
	_pitch.ball_texture = BallDesign.texture(_match_ball_idx())
	_pitch.team_kits = _pitch_team_kits()
	_pitch.board_colors = [_home_color, _away_color]
	# Uno de los 3 árbitros (Referee.gd), fijo por partido como el clima.
	_pitch_ctx["ref_anims"] = Referee.anim_set(Referee.for_fixture(MatchState.fixture, SaveManager.load_world_seed()))
	_pitch.tapped.connect(_on_pitch_tapped)

## Diseño de camiseta (plantilla de Wilber) que usa cada equipo en ESTE
## partido, indexado por el color con que la cancha pinta a ese equipo.
func _pitch_team_kits() -> Dictionary:
	var out := {}
	if _is_national_fixture():
		return out
	var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	var yr: int = WorldTickEngine.get_season_start_year()
	for side in [["home_club_id", MatchState.kit_home_away], ["away_club_id", MatchState.kit_away_away]]:
		var club := WorldFactory.find_club(world, String(MatchState.fixture.get(side[0], "")))
		if club == null:
			continue
		var w: int = int(Kit.for_club_kit(club, yr, bool(side[1])).get("w", -1))
		if w < 0:
			continue
		var cc: Array = Kit._club_colors(club)
		for key in [_pitch_ctx.get("us", Color.WHITE), _pitch_ctx.get("them", Color.BLACK)]:
			var kc: Color = key
			if kc.is_equal_approx(Color(club.primary_color_hex)):
				out[kc.to_html(false)] = {"w": w, "sec": (cc[1] as Color).to_html(false)}
	return out

## Nombres, dorsales y colores para las fichas. Dorsal = orden en el XI
## (que ya viene GK → DF → MF → ST, ver MatchTeam._build_lineup), así el
## arquero es el 1 y los delanteros los números altos.
func _build_pitch_context() -> Dictionary:
	var user_home: bool = _user_side_is(true)
	var us_team: MatchTeam = MatchState.home_team if user_home else MatchState.away_team
	var them_team: MatchTeam = MatchState.away_team if user_home else MatchState.home_team
	var us: Color = _home_color if user_home else _away_color
	var them: Color = _away_color if user_home else _home_color
	# Si los dos colores se confunden en la cancha, el rival va de alternativo
	# (Kit.colors_clash — la regla vieja dejaba pasar verde oscuro vs verde).
	if Kit.colors_clash(us, them):
		var rival_club: ClubData = null
		if not _is_national_fixture():
			var w_k: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
			rival_club = WorldFactory.find_club(w_k, String(MatchState.fixture.get("away_club_id" if user_home else "home_club_id", "")))
		them = Kit.alt_color_against(rival_club, us)
	var ctx := {
		"seed": hash("%s|%s" % [String(MatchState.fixture.get("home_club_id", "")), String(MatchState.fixture.get("away_club_id", ""))]),
		"us": us, "them": them,
		"user": {"num": "", "name": PitchPlays.short_name(MatchState.user_player.player_name if MatchState.user_player != null else "")},
		"mates": [], "rivals": [], "our_gk": {}, "their_gk": {},
	}
	var wseed: int = SaveManager.load_world_seed()   # una sola lectura de disco
	for side in [[us_team, "mates", "our_gk"], [them_team, "rivals", "their_gk"]]:
		var team: MatchTeam = side[0]
		if team == null:
			continue
		for i in range(team.starting_xi.size()):
			var pl: PlayerData = team.starting_xi[i]
			var who := {"num": str(i + 1), "name": PitchPlays.short_name(pl.player_name), "look": _pitch_look(pl, wseed), "pos": pl.position, "speed": pl.speed,
				"attrs": {"passing": pl.passing, "dribbling": pl.dribbling, "strength": pl.strength, "speed": pl.speed}}
			if pl == MatchState.user_player:
				ctx["user"] = who
			elif pl.position == "GK":
				ctx[side[2]] = who
			else:
				(ctx[side[1]] as Array).append(who)
	# Más cerca del arco primero: los delanteros/medios son los que más
	# aparecen en las jugadas de ataque.
	(ctx["mates"] as Array).reverse()
	(ctx["rivals"] as Array).reverse()
	return ctx

## Piel y pelo de un jugador para su sprite en la cancha (los mismos de su
## avatar: el tuyo es el que armaste en el editor).
func _pitch_look(pl: PlayerData, wseed: int) -> Dictionary:
	var cfg: Dictionary = Avatar.config_for_player(pl, wseed)
	var out := {}
	for k in ["tint_base", "tint_hair", "hair", "face", "acc_feet", "acc_head", "acc_eyes", "acc_ears"]:
		if String(cfg.get(k, "")) != "":
			out[k] = String(cfg[k])
	return out

func _show_pitch_for(kind: String, minute: int) -> void:
	if _pitch == null or kind == "":
		return
	_pitch_kind = kind
	_pitch_owner = "decision"
	_pitch_ctx["seed"] = hash("%s|%d" % [String(MatchState.fixture.get("home_club_id", "")), minute]) ^ _rng.randi()
	_pitch.setup(PitchPlays.scene_for(kind, _pitch_ctx))
	_pitch.visible = true
	var targets: Array = PitchPlays.tap_targets(_opts_by_kind.keys())
	_pitch.set_interactive(not targets.is_empty(), targets)
	if not targets.is_empty() and choice_box.visible:
		var hint := Label.new()
		hint.text = "👆 También podés elegir tocando en la cancha lo que está marcado."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color", Styles.GOLD)
		hint.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		choice_box.add_child(hint)
		choice_box.move_child(hint, mini(1, choice_box.get_child_count() - 1))
	_fit_pitch()
	_zoom_for_choice.call_deferred(targets)

## Cámara CERCA mientras elegís la acción (9-oct, Wilber: "la cámara más
## cerca cuando decida qué acción hacer, más zoom"): encuadra a tu jugador,
## la pelota y lo que se puede tocar (compañero / rival / arco).
func _zoom_for_choice(targets: Array) -> void:
	if _pitch == null or not _pitch.visible or _chosen_kind != "" or _minigame == "live":
		return
	var ids: Array = ["user"]
	var pts: Array = []
	for t in targets:
		if String(t) == "goal":
			pts.append(Vector2(0.5, 0.04))
		else:
			ids.append(String(t))
	_pitch.focus_on(ids, pts, 2.3)

## Tocaste la cancha mientras elegías: se traduce a una de las opciones
## que YA ofreció el motor (PitchPlays.kind_for_tap) — nunca una nueva.
func _on_pitch_tapped(target: String) -> void:
	if _chosen_kind != "" or not choice_box.visible:
		return
	var kind: String = PitchPlays.kind_for_tap(target, _opts_by_kind.keys())
	if kind != "":
		Haptics.hit("select")
		_on_choice_pressed(kind)

## Alto de la cancha: lo que deja libre el panel de decisión (que crece
## desde abajo), entre 180 y 360 px.
func _fit_pitch() -> void:
	if _live_slot != null:
		# Horizontal con cancha en vivo: la animación vieja no se muestra y
		# el relato queda siempre a la vista.
		event_log.visible = true
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if _pitch == null or not _pitch.visible:
		return
	# NO CONVOCADO = lo ves DESDE LA TRIBUNA (cámara isométrica, con el
	# estadio alrededor). En cualquier otro caso, la cámara de siempre.
	var want_cam: String = "iso" if (MatchState.engine != null and MatchState.engine.user_status() == "no_convocado") else "arco"
	if _pitch.cam_mode != want_cam:
		_pitch.set_cam_mode(want_cam)
	# JUGADA A PANTALLA GRANDE (11-oct): mientras se ve la cancha el relato
	# se guarda, y la cancha ocupa todo el alto libre.
	event_log.visible = false
	await get_tree().process_frame
	if _pitch == null or not _pitch.visible:
		event_log.visible = true
		return
	var bottom: float = (decision_panel.global_position.y if decision_panel.visible else bottom_bar.global_position.y) - 8.0
	_pitch.custom_minimum_size.y = clampf(bottom - _pitch.global_position.y, 180.0, 760.0)

func _hide_pitch() -> void:
	_pitch_owner = ""
	if _pitch != null:
		_pitch.set_interactive(false)
		_pitch.visible = false
	event_log.visible = true
	_pitch_kind = ""
	# Entre jugadas la cancha no se apaga: muestra el partido andando.
	if _match_live and _pitch != null and not halftime_panel.visible:
		_show_ambient()

## Contexto de la cancha con el dato de AHORA: ¿estás en cancha? (lo usan
## las escenas que te dibujan aunque no sea una jugada tuya).
func _ctx_now() -> Dictionary:
	_pitch_ctx["user_on"] = MatchState.engine != null and MatchState.engine.user_status() == "en_cancha"
	return _pitch_ctx

## JUEGO AMBIENTAL (10-oct, Wilber: "los jugadores se deben mover solos si
## estoy en la banca"): la cancha con los 22 moviéndose y la pelota
## circulando, entre tus jugadas o mientras mirás desde el banco.
var _match_live: bool = false
const AMBIENT_PITCH := false
func _show_ambient() -> void:
	# 11-oct (Wilber: "la narración no va acorde a lo que muestra la
	# pantalla... mejor que se muestre solo la narración y cuando sea una
	# jugada importante se pare el tiempo y se muestre a pantalla completa").
	# Los 22 moviéndose solos eran decorado: no sabían lo que decía la
	# narración. Entre jugadas ya NO hay cancha: solo el relato.
	if not AMBIENT_PITCH:
		return
	if _pitch == null or MatchState.engine == null:
		return
	var p: PlayerData = MatchState.user_player
	var actor := {}
	if p != null and MatchState.engine.user_status() == "en_cancha":
		var u: Dictionary = _pitch_ctx.get("user", {})
		actor = {"id": "user", "color": PitchPlays.GK_US if p.position == "GK" else _pitch_ctx.get("us", Color.WHITE),
			"num": u.get("num", ""), "name": u.get("name", ""), "look": u.get("look", {}), "user": true, "gk": p.position == "GK"}
	_pitch.setup_ambient(_pitch_ctx.get("us", Color.WHITE), _pitch_ctx.get("them", Color.BLACK), actor, p.position if p != null else "MF")
	_pitch.visible = true
	_fit_pitch()

func _play_decision_replay(result_event: MatchEvent) -> void:
	# En vivo la cancha vieja está oculta: no se espera su animación.
	if _live_slot != null:
		await _live_skip_replay()
		return
	_replaying = true
	_pitch_owner = "replay"
	var ok: bool = bool(result_event.payload.get("success", false))
	var goal: bool = bool(result_event.payload.get("goal", false))
	# VAR real: si el motor anuló el gol, la repetición muestra la pelota
	# adentro y después la revisión que lo anula.
	var var_state: String = String(result_event.payload.get("var", ""))
	var annulled: bool = var_state == "annulled"
	PitchPlays.var_mode = var_state
	var kind: String = String(result_event.payload.get("kind", _pitch_kind))
	if kind != _pitch_kind:
		_pitch.setup(PitchPlays.scene_for(kind, _pitch_ctx))
	else:
		_pitch.reset_camera(true)   # del zoom del minijuego a la vista completa
	_pitch.visible = true
	_fit_pitch()
	MatchState.moment_map.append({
		"kind": kind, "ok": ok, "goal": goal,
		"pos": PitchPlays.user_full_pos(kind, _pitch_ctx),
		"to": PitchPlays.pass_target_full(kind, _pitch_ctx),
	})
	PitchPlays.rebound_mode = bool(result_event.payload.get("rebound", false))
	var out_steps: Array = PitchPlays.outcome_for(kind, ok or annulled, goal or annulled, _pitch_ctx)
	PitchPlays.var_mode = ""
	PitchPlays.rebound_mode = false
	if ok and goal:
		# Tu gol en CÁMARA LENTA (P4): el último vuelo de la pelota.
		for i in range(out_steps.size() - 1, -1, -1):
			if (out_steps[i] as Dictionary).has("ball"):
				out_steps[i] = (out_steps[i] as Dictionary).duplicate()
				out_steps[i]["slow"] = 2.6
				break
	_pitch.play(out_steps)
	_pitch_ctx.erase("aim_x")
	_pitch_ctx.erase("shot_high")
	_pitch_ctx.erase("shot_level")
	_pitch_ctx.erase("strike")
	_pitch_ctx.erase("pass_to")
	_pitch_ctx.erase("pass_point")
	_pitch_ctx.erase("live_pos")
	_pitch_ctx.erase("force_offside")
	await _pitch.finished
	# Dónde quedaste parado: si la jugada sigue, la próxima acción arranca ahí.
	_last_user_world = _pitch._w(_pitch.npos("user")) if _pitch.has_actor("user") else null
	await get_tree().create_timer(0.35).timeout
	_end_replay()

## Gol que NO salió de una decisión tuya (los de una decisión ya se
## muestran en _play_decision_replay): "rival" (en contra), "team" (de un
## compañero, Paquete 2) o "" (gol/asistencia tuya — eso lo cuenta la
## celebración).
func _ambient_goal_side(event: MatchEvent) -> String:
	if _pitch == null or bool(event.payload.get("scored_by_user", false)) or bool(event.payload.get("assist_by_user", false)):
		return ""
	var hg = event.payload.get("home", null)
	if not (hg is bool):
		return ""
	return "team" if _user_side_is(hg) else "rival"

func _play_ambient_goal_replay(goal_event: MatchEvent, ours: bool) -> void:
	# En vivo: el gol se ve en la cancha en vivo (antes no se mostraba nada).
	if _live_slot != null:
		if _live_bridge != null:
			_replaying = true
			await _live_bridge.stage("goal", ours)
			_end_replay()
			return
		await _live_skip_replay()
		return
	_replaying = true
	_pitch_owner = "replay"
	var user_on: bool = MatchState.engine != null and MatchState.engine.user_status() == "en_cancha"
	var user_gk: bool = MatchState.user_player != null and MatchState.user_player.position == "GK"
	_pitch_ctx["seed"] = hash("goal|%d" % goal_event.minute) ^ _rng.randi()
	var scorer: String = String(goal_event.payload.get("scorer_name", ""))
	var play: Dictionary = PitchPlays.team_goal(_pitch_ctx, scorer, user_on, user_gk) if ours else PitchPlays.rival_goal(_pitch_ctx, scorer, user_on, user_gk)
	if goal_event.minute == _last_penalty_minute:
		# Gol de penal de la IA: se muestra el penal, no una jugada inventada.
		play = PitchPlays.ai_penalty_goal(_pitch_ctx, scorer, ours)
	_pitch.setup(play["scene"])
	_pitch.visible = true
	_fit_pitch()
	_pitch.play(play["steps"])
	await _pitch.finished
	await get_tree().create_timer(0.3).timeout
	_end_replay()

func _end_replay() -> void:
	_replaying = false
	_hide_pitch()
	_flush_held_events()
	if not _deferred_decision.is_empty():
		var sit: Dictionary = _deferred_decision
		_deferred_decision = {}
		_on_decision_requested(sit)

func _flush_held_events() -> void:
	var held: Array = _held_events.duplicate()
	_held_events.clear()
	for e in held:
		_dispatch_event(e)

## Cambio: uno sale hacia la banda y el otro entra corriendo; después sale
## el aviso de siempre.
func _play_sub_replay(ev: MatchEvent) -> void:
	# En vivo la cancha vieja está oculta: no se espera su animación.
	if _live_slot != null:
		await _live_skip_replay()
		return
	_replaying = true
	_pitch_owner = "replay"
	var p_out = ev.payload.get("player_out", null)
	var p_in = ev.payload.get("player_in", null)
	var is_user: bool = bool(ev.payload.get("is_user", false))
	var entering: bool = bool(ev.payload.get("entering", true))
	var ours: bool = is_user or _user_side_is(ev.payload.get("home", null))
	var out_nm: String = p_out.player_name if p_out is PlayerData else ""
	var in_nm: String = p_in.player_name if p_in is PlayerData else ""
	if is_user and entering:
		in_nm = MatchState.user_player.player_name
	elif is_user:
		out_nm = MatchState.user_player.player_name
	var play: Dictionary = PitchPlays.sub_scene(_pitch_ctx, out_nm, in_nm, ours, is_user and not entering, is_user and entering)
	_pitch.setup(play["scene"])
	_pitch.visible = true
	_fit_pitch()
	_pitch.play(play["steps"])
	await _pitch.finished
	await get_tree().create_timer(0.15).timeout
	_end_replay()

## Ocasión clara de cualquiera de los dos equipos (sin gol).
func _play_chance_replay(ev: MatchEvent) -> void:
	# En vivo: la ocasión se ve en la cancha en vivo (tiro y atajada).
	if _live_slot != null:
		if _live_bridge != null:
			_replaying = true
			await _live_bridge.stage("chance", _user_side_is(ev.payload.get("home", null)))
			_end_replay()
			return
		await _live_skip_replay()
		return
	_replaying = true
	_pitch_owner = "replay"
	var ours: bool = _user_side_is(ev.payload.get("home", null))
	var user_on: bool = MatchState.engine != null and MatchState.engine.user_status() == "en_cancha"
	var user_gk: bool = MatchState.user_player != null and MatchState.user_player.position == "GK"
	_pitch_ctx["seed"] = hash("chance|%d" % ev.minute) ^ _rng.randi()
	# El que remata: un compañero / rival de los que están en cancha.
	var pool: Array = _pitch_ctx.get("mates" if ours else "rivals", [])
	var shooter: String = String((pool[_rng.randi() % pool.size()] as Dictionary).get("name", "")) if not pool.is_empty() else ""
	var play: Dictionary = PitchPlays.clear_chance(_pitch_ctx, shooter, ours, user_on, user_gk)
	_pitch.setup(play["scene"])
	_pitch.visible = true
	_fit_pitch()
	_pitch.play(play["steps"])
	await _pitch.finished
	await get_tree().create_timer(0.3).timeout
	_end_replay()

## Lesión: el jugador queda en el piso y los camilleros se lo llevan.
func _play_injury_replay(ev: MatchEvent) -> void:
	# En vivo la cancha vieja está oculta: no se espera su animación.
	if _live_slot != null:
		await _live_skip_replay()
		return
	_replaying = true
	_pitch_owner = "replay"
	var pl = ev.payload.get("player", null)
	_pitch_ctx["seed"] = hash("injury|%d" % ev.minute) ^ _rng.randi()
	var play: Dictionary = PitchPlays.injury_scene(_ctx_now(), pl.player_name if pl is PlayerData else "",
		bool(ev.payload.get("is_user", false)), _user_side_is(ev.payload.get("home", null)))
	_pitch.setup(play["scene"])
	_pitch.visible = true
	_fit_pitch()
	_pitch.play(play["steps"])
	await _pitch.finished
	await get_tree().create_timer(0.15).timeout
	_end_replay()

## Tarjeta: el árbitro llega y la levanta; después sale el aviso de
## siempre (el motor ya está en pausa esperando ese ack).
func _play_card_replay(card_event: MatchEvent) -> void:
	# En vivo: la falta que da la tarjeta se ve en la cancha en vivo.
	if _live_slot != null:
		if _live_bridge != null and not bool(card_event.payload.get("is_user", false)):
			_replaying = true
			await _live_bridge.stage("card", _user_side_is(card_event.payload.get("home", null)))
			_end_replay()
			return
		await _live_skip_replay()
		return
	_replaying = true
	_pitch_owner = "replay"
	var pl = card_event.payload.get("player", null)
	var pname: String = pl.player_name if pl is PlayerData else ""
	var is_user: bool = bool(card_event.payload.get("is_user", false))
	var ours: bool = _user_side_is(card_event.payload.get("home", null))
	# Cada tarjeta es su propia escena (otro lugar, otra víctima).
	_pitch_ctx["seed"] = hash("card|%d" % card_event.minute) ^ _rng.randi()
	var play: Dictionary = PitchPlays.card_scene(_pitch_ctx, pname, is_user, ours, card_event.type == MatchEvent.Type.CARD_RED)
	_pitch.setup(play["scene"])
	_pitch.visible = true
	_fit_pitch()
	_pitch.play(play["steps"])
	await _pitch.finished
	await get_tree().create_timer(0.2).timeout
	_end_replay()

## Penal de la tanda pateado por otro: se ve en la cancha y después se
## suelta el evento (registro + ack al motor).
func _play_shootout_kick(ev: MatchEvent) -> void:
	# En vivo la cancha vieja está oculta: no se espera su animación.
	if _live_slot != null:
		await _live_skip_replay()
		_release_engine()
		return
	_replaying = true
	_pitch_owner = "replay"
	var ours: bool = _user_side_is(ev.payload.get("home", null))
	var play: Dictionary = PitchPlays.shootout_kick(_pitch_ctx, ours, String(ev.payload.get("taker", "")), bool(ev.payload.get("success", false)), int(ev.payload.get("n", 0)))
	_pitch.setup(play["scene"])
	_pitch.visible = true
	_fit_pitch()
	_pitch.focus_on(["s", "gk"], [], 1.8, true)
	_pitch.play(play["steps"])
	await _pitch.finished
	await get_tree().create_timer(0.35).timeout
	_end_replay()
	_release_engine()

## Escena de paso que NO pausa el partido (pitazos, cobro de penal). Si la
## cancha está ocupada (decisión, repetición) no se muestra.
func _play_pitch_flash(play: Dictionary, secs: float) -> void:
	if _pitch == null or _replaying or _replay_pending or decision_panel.visible:
		return
	_pitch_owner = "flash"
	_pitch.setup(play["scene"])
	_pitch.visible = true
	_fit_pitch()
	_pitch.play(play["steps"])
	_pitch_flash_token += 1
	var token: int = _pitch_flash_token
	await get_tree().create_timer(secs).timeout
	if token == _pitch_flash_token and _pitch_owner == "flash" and not _replaying and not decision_panel.visible:
		_hide_pitch()

## Entretiempo: primero el pitazo en la cancha, después el panel.
func _halftime_with_whistle(payload: Dictionary) -> void:
	_play_pitch_flash(PitchPlays.whistle_scene("half", _ctx_now()), 1.5)
	await get_tree().create_timer(1.5).timeout
	_show_halftime(payload)

## Tu jugador animado (PixelLab, 9-oct) para las cartas de evento: con el
## kit puesto (en la cancha no se juega de traje), teñido con tu piel/pelo/
## kit. Sin arte para esa animación → el cuerpo quieto (Avatar.build_anim).
## DT en pixel art (traje, no se tiñe): assets/coach/<anim>/<n>.png.
func _coach_anim(anim: String, px: int = 68) -> Control:
	var frames: Array = []
	var i: int = 0
	while ResourceLoader.exists("res://assets/coach/%s/%d.png" % [anim, i]):
		frames.append(load("res://assets/coach/%s/%d.png" % [anim, i]))
		i += 1
	if frames.is_empty():
		return BallDesign.build(_match_ball_idx(), 40)
	var r := AnimRect.new()
	r.frames = frames
	r.loop = true
	r.fps = 9.0
	r.custom_minimum_size = Vector2(px, px)
	# Placa de césped (la banda): el traje negro se perdía contra la
	# tarjeta de eventos, casi negra (0.06).
	return _grass_plate(r)

func _grass_plate(child: Control) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := Styles.card(Color(0.20, 0.42, 0.24), 10)
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	plate.add_theme_stylebox_override("panel", sb)
	plate.add_child(child)
	return plate

func _stretcher_icon(fallback: Control) -> Control:
	var p := "res://assets/misc/stretcher.png"
	if not ResourceLoader.exists(p):
		return fallback
	var r := TextureRect.new()
	r.texture = load(p)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(96, 64)
	fallback.queue_free()
	return _grass_plate(r)

func _user_anim_icon(anim: String, px: int, loop: bool) -> Control:
	var cfg: Dictionary = Avatar.celebration_config_for_player(MatchState.user_player, SaveManager.load_world_seed())
	var icon: Control = Avatar.build_anim(cfg, anim, px, loop)
	icon.custom_minimum_size = Vector2(px, px)
	return icon

# --- Remate en la cancha (minijuego interactivo) ---

func _start_pitch_shot(_kind: String) -> void:
	_meter_running = false
	tap_button.visible = false
	if _kind == "free_kick":
		_tap_hint("TIRO LIBRE: arrastrá hacia un palo para CURVARLA por afuera de la barrera (al medio pega en la barrera). Después, la barra.", "tap")
	else:
		if _pitch.cam_mode == "arco":
			_tap_hint("Arrastrá el dedo sobre la cancha hacia un costado para apuntar LEJOS del arquero, y soltá.", "tap")
		else:
			_tap_hint("Arrastrá el dedo A LO LARGO del arco (siguiendo las flechas) para apuntar LEJOS del arquero, y soltá.", "tap")
	var d: float = clampf(_chosen_difficulty, 0.0, 1.0)
	var mods := _context_mods()
	_pitch_shot_band = lerpf(0.20, 0.08, d) * float(mods[0])
	if not _pitch.shot_released.is_connected(_on_pitch_shot_released):
		_pitch.shot_released.connect(_on_pitch_shot_released)
	_pitch.start_shot_aim(d, float(mods[1]), _pitch_shot_band)
	# Cámara cerca (Wilber: "acercar la cámara para que sea más cómodo").
	_pitch.focus_on(["user", "gk"], [Vector2(0.5, 0.0)], 2.0)

func _on_pitch_shot_released(aim_x: float, power: float, gk_x: float) -> void:
	if _minigame != "pitch_shot":
		return
	var half: float = PitchView.GOAL_W * 0.5
	var wide: bool = absf(aim_x - 0.5) > half
	# Separación del arquero: 0 = le pegaste encima, 1 = el palo opuesto con
	# el arquero en el otro extremo de su recorrido.
	var sep: float = clampf(absf(aim_x - gk_x) / (PitchView.GOAL_W * 0.9), 0.0, 1.0)
	# Fase 2: la BARRA (9-oct). La puntería queda guardada y se combina con
	# el toque en _on_tap_pressed (DecisionResolver.pitch_aim_bar_precision).
	_pitch_aim_score = DecisionResolver.pitch_shot_aim_score(_chosen_difficulty, sep, wide, MatchState.user_player)
	if _chosen_kind == "free_kick" and not wide:
		# Tiro libre (P4): al medio pega en la barrera; cerca del palo = la
		# curvaste por afuera.
		_pitch_aim_score *= DecisionResolver.free_kick_wall_factor(absf(aim_x - 0.5) / half)
	# Para la repetición: la pelota va a donde apuntaste.
	_pitch_ctx["aim_x"] = clampf(aim_x, 0.5 - half * 1.5, 0.5 + half * 1.5)
	_start_strike_choice()

## PASO 2 de 3: cómo le pegás (DecisionResolver.STRIKES).
var _strike: String = "colocado"
func _start_strike_choice() -> void:
	_minigame = "pitch_shot_style"
	_meter_running = false
	tap_button.visible = false
	power_meter_bg.visible = false
	for n in meter_area.get_children():
		if String(n.name).begins_with("MG_"):
			n.queue_free()
	var box := VBoxContainer.new()
	box.name = "MG_strike"
	box.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "PASO 2 de 3  ·  ¿CÓMO LE PEGÁS?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Styles.GOLD)
	title.add_theme_font_override("font", Styles.font_semibold())
	box.add_child(title)
	# Cada golpe con SU línea de tiro dibujada en la cancha, del mismo color
	# que el borde de su botón.
	var aim_x: float = float(_pitch_ctx.get("aim_x", 0.5))
	var sgn: float = 1.0 if aim_x >= 0.5 else -1.0
	var looks := {
		"colocado": {"curve": 0.0, "color": Color(1, 1, 1, 0.9), "width": 2.0},
		"potente": {"curve": 0.0, "color": Color(1.0, 0.35, 0.3, 0.95), "width": 4.0},
		"comba": {"curve": 0.06 * sgn, "color": Color(0.35, 0.75, 1.0, 0.95), "width": 2.5},
		"comba_fuera": {"curve": -0.07 * sgn, "color": Color(1.0, 0.75, 0.25, 0.95), "width": 2.5},
	}
	var previews: Array = []
	for sk0 in DecisionResolver.STRIKE_ORDER:
		previews.append(looks.get(sk0, looks["colocado"]))
	_pitch.set_shot_previews(previews, Vector2(aim_x, -0.03))
	for sk in DecisionResolver.STRIKE_ORDER:
		var st: Dictionary = DecisionResolver.strike(sk)
		var b := Button.new()
		b.text = "●  %s\n%s" % [String(st["label"]).to_upper(), String(st["desc"])]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 50)
		b.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		Styles.styled_button(b, Styles.card_flat(Color(0.12, 0.14, 0.18), 10), (looks.get(sk, looks["colocado"])["color"] as Color).lightened(0.2))
		b.pressed.connect(_on_strike_chosen.bind(sk))
		box.add_child(b)
	meter_area.add_child(box)
	var meter_hint: Label = meter_area.get_node_or_null("MeterHint")
	if meter_hint != null:
		meter_hint.visible = false
	_tap_hint("", "tap")

func _on_strike_chosen(sk: String) -> void:
	if _minigame != "pitch_shot_style":
		return
	_strike = sk
	_pitch.set_shot_previews([])
	var box: Node = meter_area.get_node_or_null("MG_strike")
	if box != null:
		box.queue_free()
	# El golpe cambia la puntería que hacía falta y cómo se ve la pelota.
	_pitch_aim_score = DecisionResolver.strike_aim_score(_pitch_aim_score, sk)
	_pitch_ctx["strike"] = sk
	_start_shot_power()

## REMATE: segunda fase = POTENCIA (10-oct, paquete de minijuegos). Mantenés
## para cargar y soltás en la zona; pasarte = se va alta, quedarte corto =
## sale floja. Antes era la misma barra de toque que el pase.
func _start_shot_power() -> void:
	_minigame = "pitch_shot_hold"
	tap_button.visible = true
	_meter_running = false
	var p: PlayerData = MatchState.user_player
	var z: Dictionary = DecisionResolver.shot_power_zone(_chosen_difficulty, p.shooting if p != null else 60, float(_context_mods()[0]) * float(DecisionResolver.strike(_strike)["zone"]))
	_hold_target = float(z["center"])
	_target_center = _hold_target
	_target_width = float(z["width"])
	_hold_secs = float(z["secs"])
	_hold_value = 0.0
	_hold_active = false
	_position_target_zone()
	_update_hold_visual()
	_tap_hint("Mantené apretado: la barra se llena. Soltá en la zona VERDE. Al PRINCIPIO de la zona = remate RASANTE (abajo); al FINAL = ARRIBA (al ángulo). Si te pasás de la zona, se va alta.", "tap_hold")
	_set_meter_ui()

var _pitch_aim_score: float = 1.0

## Arranca la barra clásica después de apuntar en la cancha (remate/pase).
func _start_aim_bar(mg: String, hint: String) -> void:
	_minigame = mg
	tap_button.visible = true
	_start_power_meter(_chosen_kind)
	_tap_hint(hint, "tap")
	_set_meter_ui()

# --- Minijuegos interactivos en la cancha (pase/regate/defensa/arquero) ---

func _pitch_mg_mode(kind: String) -> String:
	for mode in _PITCH_MG_KINDS:
		if kind in _PITCH_MG_KINDS[mode]:
			return String(mode)
	return ""

func _start_pitch_mg(kind: String) -> void:
	_meter_running = false
	tap_button.visible = false
	var mods := _context_mods()
	if not _pitch.minigame_done.is_connected(_on_pitch_mg_done):
		_pitch.minigame_done.connect(_on_pitch_mg_done)
	var mode: String = _pitch_mg_mode(kind)
	var mg: PitchMinigame = _pitch.start_minigame(mode, kind, clampf(_chosen_difficulty, 0.0, 1.0), float(mods[1]))
	# Cámara cerca de lo que importa en cada minijuego.
	match mode:
		"pass": _pitch.focus_on(["user", "m1", "m2"], [], 1.7)
		"dribble": _pitch.focus_on(["user", "d1"], [], 2.1)
		"defend": _pitch.focus_on(["user", "a1", "a2"], [], 1.9)
		"keeper": _pitch.focus_on(["user", "a1"], [Vector2(0.5, 0.0)], 2.0)
		"sweep": _pitch.focus_on(["user", "a1", "a2"], [], 1.8)
	_tap_hint(mg.window_hint(), "tap")

## Lo que hiciste en la cancha → precisión (fórmulas en DecisionResolver,
## misma escala que la barra clásica).
func _on_pitch_mg_done(r: Dictionary) -> void:
	if String(r.get("mode", "")) == "live":
		_on_live_done(r)
		return
	if _minigame != "pitch_mg":
		return
	var d: float = clampf(_chosen_difficulty, 0.0, 1.0)
	var wf: float = float(_context_mods()[0])
	var precision: float = 0.2
	match String(r.get("mode", "")):
		"pass":
			if r.has("receiver"):
				_pitch_ctx["pass_to"] = String(r["receiver"])
			if r.has("to"):
				_pitch_ctx["pass_point"] = r["to"]
			# Elegiste a quién/dónde → ahora la barra (9-oct). Un pase al
			# espacio perdido ya no tiene arreglo.
			_pitch_aim_score = -1.0 if bool(r.get("lost", false)) else DecisionResolver.pitch_pass_aim_score(d, float(r.get("clearance", 0.0)), wf, MatchState.user_player)
			_start_aim_bar("pitch_pass_bar", "¡Pase elegido! Frená la barra en la zona verde para meterlo.")
			return
		"dribble":
			precision = DecisionResolver.pitch_timing_precision(d, float(r.get("err", 9.0)), bool(r.get("correct", false)), 0.30, 0.12, wf)
		"defend", "sweep":
			precision = DecisionResolver.pitch_timing_precision(d, float(r.get("err", 9.0)), bool(r.get("correct", false)), 0.34, 0.14, wf)
		"keeper":
			if bool(r.get("guess", false)):
				precision = DecisionResolver.pitch_keeper_guess_precision(bool(r.get("correct", false)), float(r.get("early_by", 1.0)))
			else:
				precision = DecisionResolver.pitch_timing_precision(d, float(r.get("err", 9.0)), bool(r.get("correct", false)), 0.55, 0.25, wf)
	_finish_decision(precision)


# ---------------------------------------------------------------- partido en vivo
var _live_bridge: LiveBridge = null

var _live_slot: Control = null

func _ensure_live_bridge() -> void:
	if _live_bridge == null:
		_live_bridge = LiveBridge.new()
		add_child(_live_bridge)
		_live_bridge.build(_home_color, _away_color)

## Cancha en vivo incrustada en la columna derecha desde el arranque.
func _live_embed() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or _live_slot == null:
		return
	_ensure_live_bridge()
	_live_bridge.embed(_live_slot)

func _live_moment(situation: Dictionary) -> void:
	_ensure_live_bridge()
	var r: Dictionary = await _live_bridge.play(situation)
	if MatchState.engine != null:
		MatchState.engine.resolve_decision(r)


## HORIZONTAL (FootballLegacy H): dos columnas. Izquierda: marcador, banco y
## avisos. Derecha: la cancha a todo el alto durante las jugadas, y el
## relato cuando no hay jugada (_fit_pitch ya alterna uno y otro).
func _landscape_match() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= vp.y:
		return
	var vb := $VBoxContainer as VBoxContainer
	var cols := HBoxContainer.new()
	cols.name = "LandCols"
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 380
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.7
	left.add_theme_constant_override("separation", vb.get_theme_constant("separation"))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	cols.add_child(right)
	var kids: Array = vb.get_children()
	vb.add_child(cols)
	for k in kids:
		if k == _pitch or k == event_log:
			continue
		(k as Node).reparent(left)
	if LiveBridge.enabled():
		# La cancha EN VIVO (la misma de tus jugadas) reemplaza a la animación
		# vieja: arriba la cancha con el partido de fondo, abajo el relato.
		var hidden := Control.new()
		hidden.visible = false
		right.add_child(hidden)
		_pitch.reparent(hidden)
		# Oculta y DORMIDA: antes seguía animando (y dibujando) en segundo
		# plano todo el partido, gastando batería y cuadros por nada.
		_pitch.process_mode = Node.PROCESS_MODE_DISABLED
		_live_slot = Control.new()
		_live_slot.name = "LiveSlot"
		_live_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_live_slot.size_flags_stretch_ratio = 1.7
		_live_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.add_child(_live_slot)
		event_log.reparent(right)
		event_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
		event_log.custom_minimum_size.y = 120
		_live_embed.call_deferred()
	else:
		_pitch.reparent(right)
		event_log.reparent(right)
		event_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_bg := Styles.card_flat(Color(0.04, 0.045, 0.06, 0.9), 12)
	log_bg.content_margin_left = 12
	log_bg.content_margin_right = 12
	log_bg.content_margin_top = 8
	log_bg.content_margin_bottom = 8
	event_log.add_theme_stylebox_override("normal", log_bg)


## Modo en vivo: en vez de la animación (invisible) de la cancha vieja, una
## pausa corta para leer el relato y se sigue.
func _live_skip_replay() -> void:
	_replaying = true
	_last_user_world = null
	await get_tree().create_timer(0.6).timeout
	_end_replay()
