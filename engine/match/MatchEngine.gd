extends RefCounted
class_name MatchEngine

## Corazón del gameplay: simula la mayoría del partido y se detiene
## SOLO en los momentos donde el jugador del usuario está involucrado.
##
## Contrato motor <-> UI: en Football Legacy (Kotlin) esto se resolvía
## con CompletableDeferred. En Godot el equivalente natural es `await`
## sobre una señal: el engine emite `decision_requested` y hace
## `await` de vuelta hasta que la UI llama a `resolve_decision()`.
##
## Reglas de balance heredadas de FL (no romper sin razón fuerte):
const MAX_CLEAR_CHANCES := 10
const CONVERSION_CAP := 0.65
const MAX_PENALTIES := 2 # penales EN JUEGO (no de tanda), por partido
const EVENT_DELAY_SECONDS := 0.25 # ritmo mínimo entre eventos, no bloquea la UI
const ACK_TIMEOUT_MS := 12000 # máximo que el motor espera a que la pantalla cierre un evento (ver _drain_ack)

# Probabilidades ambientales por minuto (no dependen del usuario).
const ENV_CARD_CHANCE_PER_MINUTE := 0.050   # 10-oct: 0.03 daba 2,5 amarillas por partido (real ~4)
const ENV_CARD_RED_RATIO := 0.012   # 10-oct: 0.055 daba 0,29 rojas por partido contando dobles amarillas (real ~0,2). Antes: # del total de tarjetas, cuántas son rojas (~1 roja cada 4-5 partidos)
## Bajado de 0.006 (Wilber: "revisa las lesiones ya que suceden
## demasiado") — con 0.006/min, la chance de AL MENOS una lesión (de
## cualquier jugador, no solo del usuario, ver _pick_random_pitch_player)
## en un partido de 90' era 1-(1-0.006)^90 ≈ 42%, y cada una pausa el
## partido con un popup — casi 1 de cada 2 partidos se interrumpía por
## esto. Con 0.003 baja a ≈ 23%, más cerca de lo real.
const ENV_INJURY_CHANCE_PER_MINUTE := 0.003
const ENV_PENALTY_CHANCE_PER_MINUTE := 0.0015 # ~0.15%/min, como en FL

# Probabilidad base por minuto de que el usuario reciba un momento clave,
# según posición. Subidas respecto a la v1 original: un GK con 0.010
# esperaba <1 momento en todo el partido — "parece que ni toco el balón".
const BASE_CHANCE_PER_MINUTE := {
	"ST": 0.040,
	"MF": 0.032,
	"DF": 0.024,
	"GK": 0.018,
}

# Narración ambiental (adaptada de MatchEngine.kt/ambientDescription del
# prototipo de Football Legacy): solo el ENGINE decide SI algo pasa este
# minuto y con qué etiqueta genérica — el texto en español vive en
# Match.gd, igual que el resto de eventos. Solo se tira en minutos donde
# no pasó nada más (ni gol, ni tarjeta, ni lesión, ni penal, ni momento
# clave), para no saturar por encima de eso.
const AMBIENT_CHANCE_PER_MINUTE := 0.55
const AMBIENT_KINDS := [
	"possession_home", "possession_away", "midfield_battle", "foul",
	"referee_advantage", "tempo_change", "buildup_home", "buildup_away",
	"crowd_support", "corner_no_danger", "coach_instructions",
	"short_passing_home", "transition_away", "through_ball_intercepted",
	"wing_play", "goalkeeper_calm", "switch_play", "good_control",
	"pass_intercepted", "patient_possession",
	"teammate_substitution", "rival_substitution",
	# --- Parte 91i (pedido de Wilber: "narración enriquecida e
	# inmersiva") — 6 tipos de ambiente nuevos, mismo criterio: el motor
	# solo decide QUE algo de esto pasó, el texto vive en Match.gd. ---
	"keeper_distribution", "physical_battle", "tactical_foul",
	"long_range_effort", "keeper_save_routine", "bench_reaction",
]

signal event_emitted(event: MatchEvent)
signal decision_requested(situation: Dictionary)

var home_team: MatchTeam
var away_team: MatchTeam
var user_player: PlayerData
var is_knockout: bool = false # si true: empate en el 90' -> prórroga -> penales

## Acarreo del resultado de la IDA (en la orientación de ESTE partido) para
## un cruce a doble partido. La prórroga/penales se disparan si el AGREGADO
## queda igualado al final de la vuelta, no solo el marcador de la vuelta.
var _tie_carry: Dictionary = {"home": 0, "away": 0}
var _has_tie_carry: bool = false
var _two_leg_first_leg: bool = false
func set_tie_aggregate(home_carry: int, away_carry: int) -> void:
	_tie_carry = {"home": home_carry, "away": away_carry}
	_has_tie_carry = true

func set_two_leg_first_leg(value: bool) -> void:
	_two_leg_first_leg = value

func _tie_level() -> bool:
	return (int(_score["home"]) + int(_tie_carry["home"])) == (int(_score["away"]) + int(_tie_carry["away"]))

## "Simular partido" (pedido explícito) — el MISMO motor/DecisionResolver
## que el partido jugado a mano, solo que: (1) las pausas de ritmo real
## (_wait_for_pace/_await_halftime) se saltan, y (2) cada decisión del
## usuario se autorresuelve con una "precisión" al azar en vez de esperar
## el minijuego táctil de la UI (ver _auto_precision) — nunca una segunda
## fórmula de balance, sigue pasando por DecisionResolver igual que
## siempre. El motor sigue sin saber nada de Sprites/Tweens/sonido, esto
## es una política de RITMO de la simulación, no una rama de UI.
var instant_mode: bool = false

var _score: Dictionary = {"home": 0, "away": 0}
var _shootout_score: Array = [0, 0]
var _clear_chances_used: int = 0
## Cuántos momentos clave "debería" tener el usuario en TODO el partido si
## juega los 90 — se fija al arrancar. Garantiza un piso (Wilber: "mínimo
## 3, máximo 10, 10 poco probable"). El reparto se estira según los
## minutos que realmente juegue.
var _key_moment_target: int = 5
var _user_on_minute: int = 0     # minuto en que el usuario entró (0 = titular)
var _last_key_minute: int = -99
var _penalties_used: int = 0
var _pending_decision_result = null

## Pausa por celebración: cuando marcás o asistís, el motor ESPERA a que la
## pantalla termine la celebración (Match.notify_celebration_done). En
## instant_mode no aplica. Tope de seguridad ~7 s por si la UI no responde.
var _celeb_pending: bool = false
var _celeb_done: bool = false

func notify_celebration_done() -> void:
	_celeb_done = true
	_ui_ack = true   # la celebración cuenta como "popup cerrado" para _drain_ack

## Pausa por EVENTO (tarjeta / lesión / cambio / gol rival): el motor se
## queda quieto tras emitir uno de esos hasta que la pantalla cierra el
## popup central (Match._ack_event -> notify_event_ack) o pasa el tope de
## seguridad. Pedido de Wilber: "que salgan en el centro y el tiempo se
## pause para que no se arme un caos de tantas cosas juntas". El gol
## PROPIO no entra acá: ya tiene su pausa de celebración.
var _pending_ack: bool = false
var _ui_ack: bool = false

func notify_event_ack() -> void:
	_ui_ack = true

func _drain_ack() -> void:
	if not _pending_ack or instant_mode:
		_pending_ack = false
		return
	_pending_ack = false
	_ui_ack = false
	# Tope por TIEMPO real (ACK_TIMEOUT_MS), no por frames: antes eran 540
	# frames = 9 s a 60 Hz pero solo 4,5 s en un celular a 120 Hz (el S24
	# de Wilber) — el partido podía seguir corriendo con la celebración
	# todavía en pantalla. Cubre celebración entera (hold + confeti) y la
	# repetición de la cancha 2D (Paquete 1), sin dejar el partido colgado
	# si la pantalla nunca responde.
	var deadline: int = Time.get_ticks_msec() + ACK_TIMEOUT_MS
	while not _ui_ack and Time.get_ticks_msec() < deadline:
		await Engine.get_main_loop().process_frame
	_ui_ack = false
var _user_is_starter: bool = false
var _user_is_on_pitch: bool = false
var _user_injured: bool = false
var _user_red_carded: bool = false
var _user_yellows: int = 0        # 2 en el mismo partido = roja (doble amarilla)
var _user_double_yellow: bool = false
## Mismo conteo que _user_yellows pero para CUALQUIER OTRO jugador del
## partido (PlayerData -> cantidad de amarillas). Sin esto, la doble
## amarilla solo se aplicaba al usuario -- cualquier otro jugador podía
## acumular amarillas sin límite en el mismo partido y nunca quedaba
## expulsado por acumulación, solo por roja directa. Reportado por Wilber
## jugando de verdad ("le sacaron 2 amarillas a un mismo jugador y no vio
## la roja").
var _yellow_counts: Dictionary = {}
## Se prende cuando el equipo DEL USUARIO sufre una baja forzada (lesión o
## roja de un compañero). Habilita al DT a meter al usuario ANTES de la
## recta final si lo pidió — sin esto, no te mete tan temprano.
var _forced_change_user_side: bool = false

## Peticiones del usuario desde la pantalla de partido: "pedir entrar" (si
## está en el banco) / "pedir el cambio para descansar" (si está en cancha).
## El DT las atiende en el próximo par de minutos, no al instante.
var _user_wants_on: bool = false
var _user_wants_off: bool = false
## Una vez que te sacaron (pediste el cambio y saliste), NO podés volver a
## entrar en el mismo partido — como en el fútbol real. Antes el botón
## "Pedir entrar" reaparecía tras salir (bug de Wilber).
var _user_subbed_off: bool = false
var _rating_calc := MatchRatingCalculator.new()
var _halftime_continue: bool = false

## Goles esperados (xG) de CADA equipo para todo el partido — la pieza que
## faltaba: hallazgo real de un test de temporada completa (52 empates de
## 58 partidos). Antes SOLO el usuario podía hacer que un equipo anotara
## (su propio tiro/pase clave, o un penal ambiental rarísimo, 0.15%/min) —
## un partido donde no le tocaba protagonismo (banca, puesto con pocas
## chances) terminaba casi siempre 0-0 sin importar la fuerza real de los
## equipos. `_maybe_ambient_goal()` reparte esta xG minuto a minuto para
## que compañeros y rivales anoten SIN pasar por el usuario — MISMA fórmula
## de fuerza->xG que ya usa MatchSimulator para el resto del mundo (nunca
## una segunda matemática de balance, ver CLAUDE.md), calculada una sola
## vez acá porque MatchEngine sí conoce el plantel real de cada lado (con
## fichajes aplicados) y MatchSimulator solo trabaja con el número de
## fuerza ya resumido.
var _home_xg: float = 0.0
var _away_xg: float = 0.0
## Multiplicador dinámico de la xG por equipo — lo mueve una expulsión
## (equipo con 10 produce mucho menos, el rival un poco más). Nunca es una
## segunda fórmula: solo escala la xG que ya calculó _expected_goals.
var _xg_mult: Dictionary = {"home": 1.0, "away": 1.0}

## Tope duro: máximo UNA roja por equipo y partido. Si ya hay una para ese
## lado, la sanción se degrada a amarilla — así nunca se ve "un montón de
## rojas" (pedido de Wilber).
var _reds_by_side: Dictionary = {"home": 0, "away": 0}

## Jugadores YA EXPULSADOS (roja): no pueden recibir otra tarjeta ni
## lesionarse — bug de Wilber: "un mismo jugador recibió roja y al rato
## amarilla".
var _sent_off: Array = []

func _red_allowed(on_home: bool) -> bool:
	return int(_reds_by_side["home" if on_home else "away"]) == 0

func _register_red(on_home: bool) -> void:
	_reds_by_side["home" if on_home else "away"] = int(_reds_by_side["home" if on_home else "away"]) + 1

## Aplica el efecto de una roja: el equipo sancionado baja su xG el resto
## del partido, el rival sube un poco. Se llama desde CADA sitio que
## expulsa a alguien (ambiental o por una decisión del usuario).
func _apply_red_card_effect(on_home: bool) -> void:
	var side: String = "home" if on_home else "away"
	var other: String = "away" if on_home else "home"
	_xg_mult[side] = float(_xg_mult[side]) * 0.62
	_xg_mult[other] = float(_xg_mult[other]) * 1.16

func _live_xg(is_home: bool, minute: int = 45) -> float:
	return (_home_xg if is_home else _away_xg) \
		* float(_xg_mult["home" if is_home else "away"]) \
		* _game_state_xg_factor(is_home, minute)

## El MARCADOR y el RELOJ mueven el ataque de cada equipo — realismo:
## el que pierde se vuelca (más cuanto más tarde y peor va), el que gana
## administra el resultado. Nunca es una 2ª fórmula de balance: solo
## escala la xG que ya calculó _expected_goals.
func _game_state_xg_factor(is_home: bool, minute: int) -> float:
	var mine: int = int(_score["home"]) if is_home else int(_score["away"])
	var theirs: int = int(_score["away"]) if is_home else int(_score["home"])
	var d: int = mine - theirs
	if d == 0:
		return 1.0
	# 0 en el min 40, 1 en el 90 — el resultado pesa más al final.
	var late: float = clampf((float(minute) - 40.0) / 50.0, 0.0, 1.0)
	if d < 0:
		return 1.0 + float(mini(-d, 2)) * lerpf(0.05, 0.22, late)   # voy perdiendo → me vuelco
	return 1.0 - lerpf(0.03, 0.16, late)                            # voy ganando → administro

## Bonus plano a los atributos del usuario EN SUS acciones este partido —
## lo alimenta el "Suplemento pre-partido" de la Tienda (ShopEngine). Acá
## solo se LEE la flag (el motor no toca persistencia, ver cabecera);
## MatchSummary la descuenta y guarda al terminar el partido.
var _match_attr_bonus: int = 0
## Árbitro del partido (DecisionResolver.referee_profile): lo setea quien
## lanza el partido. 1.0 = neutro.
var referee_card_mult: float = 1.0
var referee_var_mult: float = 1.0
## Multiplicador de faltas pitadas (0.8 permisivo ... 1.35 estricto).
var referee_foul_mult: float = 1.0
## VAR del último gol: "" sin revisión | "valid" revisado y válido |
## "annulled" anulado. Y cuántos goles se anularon (para saber si una
## jugada tuya terminó en gol anulado).
var _last_goal_var: String = ""
var _disallowed_count: int = 0

## Nota de CADA jugador del partido (PlayerData -> float, base 6.0) — pedido
## explícito: "la valoración de cada jugador del partido", no solo la del
## usuario. Se ajusta por goles, tarjetas y el resultado; se devuelve en
## run_match() como lista ordenada.
var _ratings: Dictionary = {}
var _user_goals: int = 0
var _user_assists: int = 0
## Sesgo de momentos clave por el estilo del DT del usuario (Formations.
## moment_bias) — {kind: multiplicador} sobre _KIND_WEIGHTS.
var _moment_bias: Dictionary = {}
var _ai_subs_home: int = 0
var _ai_subs_away: int = 0
## Pertenencia de equipo FIJA (XI + banca al arranque) — no se puede usar
## starting_xi para esto porque los cambios de la IA lo mutan a mitad de
## partido (un titular sustituido dejaría de "pertenecer" a su equipo).
var _home_roster: Array = []
var _away_roster: Array = []

## Estadísticas de EQUIPO del partido (tiros, tiros a puerta, córners,
## faltas) — no existían: el motor solo llevaba lo del usuario. Se acumulan
## minuto a minuto con tasas derivadas de la MISMA xG que ya calcula
## _expected_goals (nunca una segunda matemática de balance): más xG ->
## más tiros. Solo presentación (entretiempo / resumen), no tocan marcador.
var _stats: Dictionary = {
	"home": {"shots": 0, "on_target": 0, "corners": 0, "fouls": 0},
	"away": {"shots": 0, "on_target": 0, "corners": 0, "fouls": 0},
}
var _possession_home: int = 50

## Fatiga del partido: penaliza (poco) la precisión de las decisiones del
## usuario según avanza el partido. La "Bebida energizante" de la Tienda
## (consumible de entretiempo, ver ShopEngine.use_halftime) recorta esta
## penalización vía set_fatigue_relief(). Es un modificador de estado, el
## éxito/fallo real lo sigue decidiendo DecisionResolver.
##
## Parte 91 (reporte de Wilber jugando de titular: "la estamina no me
## baja hasta el segundo tiempo, debería bajar desde el primer minuto"):
## antes el desgaste de un TITULAR arrancaba recién en el min 46 (0 fijo
## todo el 1er tiempo) — quedaba como si el titular llegara al entretiempo
## "recién entrado". Ahora corre desde que pisa la cancha (min 0 para un
## titular, su minuto real de entrada para un suplente — eso NO cambia).
## En el entretiempo se recupera una fracción de lo acumulado en el 1er
## tiempo (pedido explícito: "en el medio tiempo aumenta un poco"), y si
## sigue jugando el 2do tiempo sigue bajando desde ahí.
const FIRST_HALF_FATIGUE_MAX := 0.10
const HALFTIME_RECOVERY_FRAC := 0.4
const SECOND_HALF_FATIGUE_MAX := 0.16
const EXTRA_TIME_FATIGUE_MAX := 0.08
## Techo de los 90 minutos reglamentarios, usado para normalizar la barra
## del HUD. La fatiga adicional de la prórroga puede llevarla más abajo.
const MAX_FATIGUE_PRECISION_PENALTY := FIRST_HALF_FATIGUE_MAX * (1.0 - HALFTIME_RECOVERY_FRAC) + SECOND_HALF_FATIGUE_MAX
var _fatigue_relief: float = 0.0

## Cansancio que traés DESDE fuera del partido: energía física
## (fatigue_physical, la suben los eventos de la sección Mensajes) +
## tensión mental (fatigue_mental, la sube una derrota o un mal partido).
## Penaliza plano TODAS tus decisiones, no solo la 2ª parte. Tope -0.15;
## las dos al máximo -> penalización completa, una sola -> la mitad.
const CARRIED_FATIGUE_MAX := 0.15
var _carried_fatigue_penalty: float = 0.0

const RATING_BASE := 6.0
const MAX_AI_SUBS := 3
const AI_SUB_WINDOW_START := 55

func _init(p_home: MatchTeam, p_away: MatchTeam, p_user_player: PlayerData, p_is_knockout: bool = false, p_instant: bool = false) -> void:
	home_team = p_home
	away_team = p_away
	user_player = p_user_player
	is_knockout = p_is_knockout
	instant_mode = p_instant
	_user_is_starter = home_team.starting_xi.has(user_player) or away_team.starting_xi.has(user_player)
	_user_is_on_pitch = _user_is_starter
	_user_on_minute = 0
	# Objetivo de momentos clave del partido: normalmente 4-6, rara vez hasta 10.
	_key_moment_target = randi_range(4, 6) if randf() > 0.08 else randi_range(7, 10)

	_home_roster = home_team.starting_xi + home_team.bench
	_away_roster = away_team.starting_xi + away_team.bench
	for p in home_team.starting_xi:
		_ratings[p] = RATING_BASE
	for p in away_team.starting_xi:
		_ratings[p] = RATING_BASE

	var home_strength: float = _team_strength(home_team)
	var away_strength: float = _team_strength(away_team)
	_home_xg = _expected_goals(home_strength, away_strength, true)
	_away_xg = _expected_goals(away_strength, home_strength, false)
	# El usuario titular se "queda" con parte de la xG de su equipo (sus
	# propios goles y asistencias salen de sus momentos clave).
	if user_player != null and _user_is_starter:
		var share: float = float(DecisionResolver.USER_XG_SHARE.get(user_player.position, 1.0))
		if home_team.starting_xi.has(user_player):
			_home_xg *= share
		else:
			_away_xg *= share
	_possession_home = int(clampf(50.0 + (home_strength - away_strength) * 0.6, 33.0, 67.0))

	# Formación del DT de cada equipo: escala la xG (ofensiva/defensiva +
	# delanteros) — mismo criterio que el resto, solo modula la xG que ya
	# calculó _expected_goals, nunca una segunda fórmula (ver Formations.gd).
	if home_team.formation != "":
		var home_phil: String = Formations.philosophy_for(null, home_team.formation)
		_home_xg *= Formations.xg_factor(home_team.formation, home_phil)
		# Bug real de la auditoría: faltaba el lado defensivo del trade-off
		# (ver comentario de defense_factor) — una formación defensiva
		# ahora también le resta xG al RIVAL, no solo se resta a sí misma.
		_away_xg *= Formations.defense_factor(home_team.formation, home_phil)
	if away_team.formation != "":
		var away_phil: String = Formations.philosophy_for(null, away_team.formation)
		_away_xg *= Formations.xg_factor(away_team.formation, away_phil)
		_home_xg *= Formations.defense_factor(away_team.formation, away_phil)
	# Estilo del DT del usuario: sesga el reparto de sus momentos clave y,
	# si juega a la posesión, empuja un poco la tenencia a su favor.
	var user_is_home_team: bool = home_team.starting_xi.has(user_player) or home_team.bench.has(user_player)
	var user_team: MatchTeam = home_team if user_is_home_team else away_team
	_moment_bias = Formations.moment_bias(user_team.play_style)
	if user_team.play_style == "Posesión":
		_possession_home = clampi(_possession_home + (4 if user_is_home_team else -4), 30, 70)
	elif user_team.play_style == "Contraataque":
		_possession_home = clampi(_possession_home + (-4 if user_is_home_team else 4), 30, 70)

	# El equipo del usuario reparte parte de su xG en los momentos clave que
	# ÉL resuelve (su propio tiro/pase), no todo en goles ambientales — si
	# no, ese equipo sumaría xG_ambiental + los goles propios del usuario
	# encima y ganaría de más. El descuento va según cuánto suele generar el
	# usuario desde su puesto (un ST resuelve más chances propias que un DF).
	# Si el usuario arranca en la banca no se descuenta nada: los goles
	# ambientales cubren al equipo entero hasta que (si) entra.
	if _user_is_starter:
		var shares: Dictionary = {"ST": 0.25, "MF": 0.12, "DF": 0.03, "GK": 0.02}
		var user_share: float = float(shares.get(user_player.position, 0.1))
		if home_team.starting_xi.has(user_player):
			_home_xg *= (1.0 - user_share)
		elif away_team.starting_xi.has(user_player):
			_away_xg *= (1.0 - user_share)

	# Suplemento pre-partido de la Tienda: bonus a las acciones del usuario
	# este partido (MatchSummary descuenta la flag al terminar).
	if user_player != null and int(user_player.active_effects.get("match_boost_matches", 0)) > 0:
		_match_attr_bonus = ShopEngine.PREMATCH_ATTR_BONUS

	# Capitanía (CaptaincyEngine): +bonus a tus acciones y un empuje al xG
	# de tu equipo. season["is_captain"] lo fija el rollover.
	if user_player != null and WorldTickEngine.season.get("is_captain", false):
		_match_attr_bonus += CaptaincyEngine.MATCH_ATTR_BONUS
		var cap_side: String = "home" if user_is_home_team else "away"
		_xg_mult[cap_side] = float(_xg_mult[cap_side]) * CaptaincyEngine.TEAM_XG_FACTOR

	# Humor de la afición (season["fan_sentiment"], lo mueven resultados y
	# zona mixta): jugando de LOCAL, una hinchada enchufada empuja tu xG un
	# poco; una crispada mete nervios. Sutil (±~4%).
	if user_player != null and user_is_home_team and WorldTickEngine.season.has("fan_sentiment"):
		var fs: int = int(WorldTickEngine.season.get("fan_sentiment", 55))
		var fan_factor: float = clampf(1.0 + (float(fs) - 55.0) / 100.0 * 0.11, 0.94, 1.06)
		if not is_equal_approx(fan_factor, 1.0):
			_xg_mult["home"] = float(_xg_mult["home"]) * fan_factor

	# Clima de vestuario (season["dressing_room"], lo mueven entrevistas y
	# el Planner) — BUG real encontrado en la auditoría del 12-sep: el
	# stat existía y se movía, pero no afectaba NADA del juego. A
	# diferencia de fan_sentiment (solo de local), esto es interno al
	# plantel: te acompaña juegues donde juegues. Bonus chico a TUS
	# acciones (mismo mecanismo que el suplemento pre-partido/capitanía),
	# ±3 en los extremos, 0 en el clima neutro (60).
	if user_player != null and WorldTickEngine.season.has("dressing_room"):
		var dr: int = int(WorldTickEngine.season.get("dressing_room", InterviewEngine.DRESSING_DEFAULT))
		var dr_bonus: int = clampi(int(round(float(dr - InterviewEngine.DRESSING_DEFAULT) / 13.0)), -3, 3)
		_match_attr_bonus += dr_bonus

	# Rasgo "Muro bajo los palos" (portero): el rival genera menos peligro.
	if user_player != null and user_player.position == "GK":
		var cf: float = Traits.concede_factor(user_player)
		if cf < 1.0:
			var opp_side: String = "away" if user_is_home_team else "home"
			_xg_mult[opp_side] = float(_xg_mult[opp_side]) * cf

	if user_player != null:
		var carried: float = (user_player.fatigue_physical + user_player.fatigue_mental) / 200.0
		_carried_fatigue_penalty = clampf(carried * CARRIED_FATIGUE_MAX, 0.0, CARRIED_FATIGUE_MAX)

## Promedio de overall del XI titular — mismo criterio que la fuerza de
## club que ya usa el resto del "mundo vivo" (top jugadores reales, no
## toda la plantilla), solo que acá ya tenemos el XI exacto de ESTE
## partido (con favor del entrenador ya aplicado), no hace falta
## recalcularlo desde cero.
static func _team_strength(team: MatchTeam) -> float:
	if team.starting_xi.is_empty():
		return 55.0
	var total: int = 0
	for p in team.starting_xi:
		total += p.overall
	return float(total) / float(team.starting_xi.size())

## AMBIENT_XG_FACTOR: recorte sobre la xG cruda de MatchSimulator. Los
## goles ambientales NO son lo único que anota en MatchEngine (encima van
## los momentos clave del usuario, penales en juego, conversiones de pase
## clave), así que se recorta un poco para que la media termine cerca de
## ~2.7 goles/partido (fútbol de verdad) en vez de irse por encima de 3.
const AMBIENT_XG_FACTOR := 0.9

static func _expected_goals(strength: float, opponent_strength: float, is_home: bool) -> float:
	var advantage: float = MatchSimulator.HOME_ADVANTAGE if is_home else -MatchSimulator.HOME_ADVANTAGE
	var diff: float = (strength - opponent_strength) + advantage
	var raw: float = clampf(MatchSimulator.BASE_XG + diff * MatchSimulator.STRENGTH_TO_XG, MatchSimulator.MIN_XG, MatchSimulator.MAX_XG)
	return raw * AMBIENT_XG_FACTOR

func run_match() -> Dictionary:
	_emit(MatchEvent.Type.KICKOFF, 0)

	for minute in range(1, 46):
		await _tick_minute(minute)
		if _match_should_stop_early():
			break

	# Descanso real de los 90 minutos.
	if not _match_should_stop_early():
		_emit(MatchEvent.Type.HALFTIME, 45, {"home": _score["home"], "away": _score["away"], "stats": get_match_stats()})
		await _await_halftime()

	for minute in range(46, 91):
		await _tick_minute(minute)
		if _match_should_stop_early():
			break

	var shootout_winner: String = ""
	var extra_time_played := false
	var final_minute := 90
	if is_knockout and not _two_leg_first_leg and _tie_level() and not _match_should_stop_early():
		extra_time_played = true
		_emit(MatchEvent.Type.EXTRA_TIME_START, 90, {"home_total": int(_score["home"]) + int(_tie_carry["home"]),
			"away_total": int(_score["away"]) + int(_tie_carry["away"])})
		for minute in range(91, 106):
			await _tick_minute(minute)
			if _match_should_stop_early():
				break
		if not _match_should_stop_early():
			# Segundo descanso breve: el segundo tiempo extra también son 15'.
			_emit(MatchEvent.Type.HALFTIME, 105, {"home": _score["home"], "away": _score["away"],
				"stats": get_match_stats(), "extra_time": true})
			await _await_halftime()
		for minute in range(106, 121):
			if _match_should_stop_early():
				break
			await _tick_minute(minute)
		final_minute = 120
		if _tie_level():
			shootout_winner = await _run_penalty_shootout()
	_emit(MatchEvent.Type.FULLTIME, final_minute)
	var tie_winner := ""
	if is_knockout and not _two_leg_first_leg:
		var total_home := int(_score["home"]) + int(_tie_carry["home"])
		var total_away := int(_score["away"]) + int(_tie_carry["away"])
		if total_home > total_away:
			tie_winner = "home"
		elif total_away > total_home:
			tie_winner = "away"
		else:
			tie_winner = shootout_winner

	_apply_result_to_ratings(shootout_winner, tie_winner)

	return {
		"score": _score,
		"shootout_score": _shootout_score.duplicate(),
		"aggregate_score": {"home": int(_score["home"]) + int(_tie_carry["home"]),
			"away": int(_score["away"]) + int(_tie_carry["away"])},
		"has_tie_carry": _has_tie_carry,
		"user_player": user_player,
		"user_rating": _rating_calc.get_rating(),
		"rating_events": _rating_calc.get_events_log(),
		"user_injured": _user_injured,
		"user_red_carded": _user_red_carded,
		"user_double_yellow": _user_double_yellow,
		"shootout_winner": shootout_winner,
		"tie_winner": tie_winner,
		"extra_time_played": extra_time_played,
		"player_ratings": _player_ratings_list(),
		"match_stats": get_match_stats(),
		"user_goals": _user_goals,
		"user_assists": _user_assists,
		# BUG REAL (Wilber: "me está sumando titularidades cuando solo he
		# sido suplente"): `_user_is_starter` se fija UNA vez al arranque
		# (línea ~306), antes de que _maybe_substitute_user() reemplace tu
		# lugar en starting_xi cuando entrás de cambio — a partir de ahí
		# starting_xi ya NO significa "quiénes arrancaron", significa
		# "quiénes están en cancha ahora". MatchSummary.gd usaba
		# starting_xi.has(user_player) DESPUÉS del partido para decidir
		# titularidad, así que un suplente que entraba quedaba marcado
		# como titular. Exponer la señal real de acá, nunca mutada.
		"user_started": _user_is_starter,
		# BUG REAL (Wilber: "solo cuenta los partidos como titular y no
		# los partidos jugados en la temporada"): "¿jugó de verdad, aunque
		# sea unos minutos?" — titular, O entró de cambio y se quedó hasta
		# el final, O entró de cambio y lo sacaron después. Si se quedó
		# TODO el partido en el banco sin entrar, esto da false (no jugó
		# ningún minuto, no debería contar como partido jugado).
		"user_played": _user_is_starter or _user_is_on_pitch or _user_subbed_off,
		"user_yellows": _user_yellows,
	}

## Ajuste final por el resultado: los del equipo ganador suben un poco,
## los del que perdió bajan un poco (nunca por debajo de 3 ni arriba de 10).
func _apply_result_to_ratings(shootout_winner: String, tie_winner: String) -> void:
	var gh: int = _score["home"]
	var ga: int = _score["away"]
	var home_won: bool = tie_winner == "home" or (tie_winner == "" and gh > ga) or shootout_winner == "home"
	var away_won: bool = tie_winner == "away" or (tie_winner == "" and ga > gh) or shootout_winner == "away"
	for p in _ratings:
		var on_home: bool = p in _home_roster
		var delta: float = 0.0
		if home_won:
			delta = 0.4 if on_home else -0.4
		elif away_won:
			delta = -0.4 if on_home else 0.4
		_ratings[p] = clampf(_ratings[p] + delta, 3.0, 10.0)
	# Bug real de la auditoría: el usuario tiene su PROPIA nota en paralelo
	# (_rating_calc, basada en eventos reales) — la nota final que se
	# muestra/usa SIEMPRE sale de ahí (get_rating()), nunca de
	# _ratings[user_player]. El ajuste de arriba nunca llegaba al usuario;
	# un compañero con las mismas estadísticas terminaba con mejor/peor
	# nota que él solo por jugar del lado ganador/perdedor.
	if user_player != null and (_user_is_starter or _user_is_on_pitch or _user_subbed_off):
		var user_on_home: bool = user_player in _home_roster
		var user_delta: float = 0.0
		if home_won:
			user_delta = 0.4 if user_on_home else -0.4
		elif away_won:
			user_delta = -0.4 if user_on_home else 0.4
		_rating_calc.register_result(user_delta)

## Lista ordenada de mejor a peor para la UI:
## [{name, position, team: "home"|"away", is_user, rating}].
func _player_ratings_list() -> Array:
	var rows: Array = []
	# La nota del USUARIO SIEMPRE es la del MatchRatingCalculator (la misma
	# que "Tu nota" en el resumen). Antes esta lista usaba _ratings[user],
	# un acumulador aparte, así que "figura del partido" mostraba una nota
	# distinta a "tu nota" para el mismo partido (bug de Wilber).
	var user_rt: float = _rating_calc.get_rating()
	for p in _ratings:
		var is_u: bool = p == user_player
		rows.append({
			"name": p.player_name,
			"position": p.position,
			"team": "home" if p in _home_roster else "away",
			"is_user": is_u,
			"rating": user_rt if is_u else clampf(_ratings[p], 3.0, 10.0),
		})
	rows.sort_custom(func(a, b): return a["rating"] > b["rating"])
	return rows

## Lectura en vivo para la UI (marcador y nota corriendo durante el
## partido) — nunca mutan estado, solo exponen lo que ya se calcula.
func get_live_score() -> Dictionary:
	return _score.duplicate()

func get_live_rating() -> float:
	return _rating_calc.get_rating()

func get_user_goals() -> int:
	return _user_goals

func get_user_assists() -> int:
	return _user_assists

## Amortigua la probabilidad de generar OTRA asistencia en el mismo partido:
## 1ª asistencia sin penalización, la 2ª al 42%, la 3ª al 18%… — un MF top
## llegaba a 41 asistencias en 32 partidos en la sim.
func _assist_dampen() -> float:
	return DecisionResolver.ASSIST_SCALE * pow(0.42, float(maxi(0, _user_assists - 1)))

## Estado del usuario para la pantalla de partido:
## "en_cancha" | "banco" | "lesionado" | "expulsado".
func user_not_called() -> bool:
	return home_team.user_not_called or away_team.user_not_called

func user_status() -> String:
	if user_not_called():
		return "no_convocado"
	if _user_red_carded:
		return "expulsado"
	if _user_injured:
		return "lesionado"
	if _user_is_on_pitch:
		return "en_cancha"
	return "banco"

func user_can_request_on() -> bool:
	return user_status() == "banco" and not _user_wants_on and not _user_subbed_off

func user_can_request_off() -> bool:
	return user_status() == "en_cancha" and not _user_wants_off

## Ya cumpliste tu parte (te sustituyeron): la pantalla lo muestra y no
## ofrece "Pedir entrar".
func user_done_for_match() -> bool:
	return _user_subbed_off

func user_request_pending() -> String:
	if _user_wants_on:
		return "pediste_entrar"
	if _user_wants_off:
		return "pediste_salir"
	return ""

## Llamadas desde la UI (botón "Pedir entrar" / "Pedir el cambio").
func request_come_on() -> void:
	if user_can_request_on():
		_user_wants_on = true

func request_sub_off() -> void:
	if user_can_request_off():
		_user_wants_off = true

## Foto de las estadísticas de equipo al momento — la usa la pantalla de
## entretiempo y podría usarla el resumen. Copia defensiva: nadie de la UI
## debe poder mutar los contadores internos.
func get_match_stats() -> Dictionary:
	return {
		"possession_home": _possession_home,
		"possession_away": 100 - _possession_home,
		"home": (_stats["home"] as Dictionary).duplicate(),
		"away": (_stats["away"] as Dictionary).duplicate(),
	}

## La pantalla de entretiempo llama acá tras consumir la "Bebida
## energizante" (ShopEngine.use_halftime). `relief` 0..1 = fracción de la
## fatiga de 2ª parte que se anula. Modificador de ritmo, no de balance.
func set_fatigue_relief(relief: float) -> void:
	_fatigue_relief = clampf(relief, 0.0, 1.0)

## Penalización a la precisión de una decisión del usuario por el desgaste
## del partido — ver _fatigue_precision_penalty() para la curva completa.
## Estamina VISIBLE del usuario, 0..100, para la barra del HUD del partido.
## No es un valor nuevo: es el mismo desgaste que _fatigue_precision_penalty
## + _carried_fatigue_penalty ya aplican a la precisión de cada decisión
## (línea de precision en _apply_decision_result). La barra sólo lo hace
## visible para que Wilber sepa si aguanta o si conviene el energizante.
func stamina_pct(minute: int) -> float:
	if user_player == null:
		return 100.0
	var pen: float = _fatigue_precision_penalty(minute) + _carried_fatigue_penalty
	var ref_max: float = MAX_FATIGUE_PRECISION_PENALTY + CARRIED_FATIGUE_MAX
	var norm: float = clampf(pen / maxf(ref_max, 0.001), 0.0, 1.0)
	# Curva un poco cóncava: la barra "se siente" antes de tocar fondo.
	return clampf(100.0 * (1.0 - pow(norm, 0.85) * 0.94), 4.0, 100.0)

## Curva de desgaste a lo largo del partido (ver constantes de arriba).
## Titular (_user_on_minute==0): sube desde el min 0 hasta un tope en el
## entretiempo, se alivia una fracción en el entretiempo mismo, y sigue
## subiendo en el 2do tiempo si sigue en cancha. Suplente que entra en el
## 1er tiempo: mismo criterio, arranca su rampa desde su minuto de
## entrada. Suplente que entra en el 2do tiempo: entra fresco, arranca su
## propia rampa desde su minuto de entrada sin pasar por el entretiempo.
func _fatigue_precision_penalty(minute: int) -> float:
	# El desgaste SOLO corre mientras el usuario está EN CANCHA. Un
	# suplente que todavía no entró no se cansa — antes la barra se le
	# vaciaba desde el banco apenas pedía el cambio (bug de Wilber).
	if not _user_is_on_pitch or minute < _user_on_minute:
		return 0.0
	var stamina_relief: float = (float(user_player.stamina) / 400.0) if user_player != null else 0.0
	var relief_mult: float = (1.0 - _fatigue_relief) * (1.0 - stamina_relief)

	if _user_on_minute >= 46:
		var ramp: float = clampf(float(minute - _user_on_minute) / 44.0, 0.0, 1.0)
		return clampf((SECOND_HALF_FATIGUE_MAX * ramp + _extra_time_fatigue(minute)) * relief_mult, 0.0, 0.5)

	var first_half_span: float = maxf(float(45 - _user_on_minute), 1.0)
	var ramp1: float = clampf(float(mini(minute, 45) - _user_on_minute) / first_half_span, 0.0, 1.0)
	var first_half_pen: float = FIRST_HALF_FATIGUE_MAX * ramp1
	if minute <= 45:
		return clampf(first_half_pen * relief_mult, 0.0, 0.5)

	var after_break: float = first_half_pen * (1.0 - HALFTIME_RECOVERY_FRAC)
	var ramp2: float = clampf(float(minute - 46) / 44.0, 0.0, 1.0)
	var pen: float = after_break + SECOND_HALF_FATIGUE_MAX * ramp2 + _extra_time_fatigue(minute)
	return clampf(pen * relief_mult, 0.0, 0.5)


func _extra_time_fatigue(minute: int) -> float:
	if minute <= 90 or minute <= _user_on_minute or not _user_is_on_pitch:
		return 0.0
	var start: int = maxi(90, _user_on_minute)
	var elapsed: float = clampf(float(minute - start) / float(maxi(120 - start, 1)), 0.0, 1.0)
	return EXTRA_TIME_FATIGUE_MAX * elapsed

func _match_should_stop_early() -> bool:
	# Punto de enganche futuro (ej. abandono forzado); hoy nunca corta.
	return false

## Llamado desde la UI cuando el jugador pulsa "Empezar 2do tiempo".
func continue_second_half() -> void:
	_halftime_continue = true

func _await_halftime() -> void:
	if instant_mode:
		return
	while not _halftime_continue:
		await Engine.get_main_loop().process_frame
	_halftime_continue = false

func _tick_minute(minute: int) -> void:
	_last_minute_seen = minute
	_emit(MatchEvent.Type.MINUTE_TICK, minute, {"stamina": stamina_pct(minute)})

	_tick_match_texture(minute)
	_maybe_substitute_user(minute)

	var something_happened: bool = false

	# Tras CADA sub-paso que puede sacar un popup modal (cambio / gol rival
	# / tarjeta / lesión) se hace _drain_ack(): el motor NO sigue —ni deja
	# que salga un momento clave— hasta que la pantalla cierra ese popup.
	# Antes el _drain_ack() estaba solo al final del minuto, así que un
	# popup podía quedar tapando el minijuego de un momento clave (bug:
	# "narraron que marqué gol y no me salió la opción de la acción").
	if await _maybe_user_sub_off(minute):
		something_happened = true
	elif await _maybe_coach_subs_user_off(minute):
		something_happened = true
	await _drain_ack()

	# Goles de compañeros / del rival, INDEPENDIENTES del usuario — fuera
	# del gate `_user_red_carded` a propósito: si te expulsan el partido
	# sigue sin vos, los demás jugadores siguen anotando.
	if await _maybe_ambient_goal(minute, true):
		something_happened = true
	await _drain_ack()
	if await _maybe_ambient_goal(minute, false):
		something_happened = true
	await _drain_ack()

	# Cambios de la IA (ambos equipos) — también fuera del gate del usuario.
	if await _maybe_ai_substitution(minute, true):
		something_happened = true
	await _drain_ack()
	if await _maybe_ai_substitution(minute, false):
		something_happened = true
	await _drain_ack()

	if not _user_red_carded:
		if await _maybe_environmental_card(minute):
			something_happened = true
		await _drain_ack()
		if await _maybe_environmental_injury(minute):
			something_happened = true
		await _drain_ack()
		if await _maybe_environmental_penalty(minute):
			something_happened = true
		await _drain_ack()

		if _should_trigger_key_moment(minute):
			await _resolve_key_moment(minute)
			something_happened = true

	if _clear_chance_home != null:
		if not something_happened:
			_emit(MatchEvent.Type.AMBIENT, minute, {"kind": "clear_chance", "home": bool(_clear_chance_home)})
			something_happened = true
		_clear_chance_home = null
	if not something_happened:
		_maybe_ambient_narration(minute)

	await _drain_ack()
	await _wait_for_pace()

## Textura estadística del minuto: tiros / córners / faltas que NO terminan
## en gol (los goles suman su propio tiro a puerta en _register_goal_for,
## las tarjetas su falta en _maybe_environmental_card). Tasas proporcionales
## a la xG de cada equipo — misma fuente que el resto del balance.
## Qué parte de los remates al arco sin gol se muestran como ocasión clara
## (≈3 por partido con ~6 atajadas entre los dos equipos).
const CLEAR_CHANCE_SHARE := 0.5
var _clear_chance_home = null   # bool cuando hay una ocasión por contar este minuto

func _tick_match_texture(minute: int) -> void:
	for is_home in [true, false]:
		var side: String = "home" if is_home else "away"
		var xg: float = _live_xg(is_home, minute)
		# ~9 tiros esperados por unidad de xG -> ronda los 11-13 tiros/equipo
		# de un partido real; ~35% terminan a puerta.
		if randf() < (xg * 9.0) / 90.0:
			_stats[side]["shots"] += 1
			if randf() < 0.35:
				_stats[side]["on_target"] += 1
				# OCASIÓN CLARA (11-oct, Wilber: "pasa muy poco en el
				# partido"): parte de los remates al arco que NO son gol se
				# cuentan como jugada importante — la pantalla la muestra.
				if _clear_chance_home == null and randf() < CLEAR_CHANCE_SHARE:
					_clear_chance_home = is_home
		if randf() < 0.055:
			_stats[side]["corners"] += 1
		if randf() < 0.11:
			_stats[side]["fouls"] += 1

## Textura de partido (adaptado del prototipo): en un minuto donde no pasó
## nada más, hay buena probabilidad de que se narre "algo" igualmente —
## sin tocar marcador, tarjetas ni la nota del usuario. Solo presentación.
func _maybe_ambient_narration(minute: int) -> void:
	if randf() >= AMBIENT_CHANCE_PER_MINUTE:
		return
	var kind: String = AMBIENT_KINDS[randi() % AMBIENT_KINDS.size()]
	_emit(MatchEvent.Type.AMBIENT, minute, {"kind": kind})

## Gol de un compañero o del rival, sin involucrar al usuario — ver
## `_home_xg`/`_away_xg` arriba. Se reparte la xG de todo el partido en
## 90 chances independientes (mismo criterio que ENV_CARD_CHANCE_PER_MINUTE
## y el resto de probabilidades "ambientales": una tasa por partido
## discretizada minuto a minuto), así que en promedio el marcador final
## se acerca a lo que produciría MatchSimulator para estos mismos equipos.
func _maybe_ambient_goal(minute: int, is_home: bool) -> bool:
	var xg: float = _live_xg(is_home, minute)
	if randf() >= xg / 90.0:
		return false
	var scorer := _pick_weighted_scorer(home_team if is_home else away_team)
	_register_goal_for(is_home, minute, false, scorer)
	if scorer != null:
		_ratings[scorer] = _ratings.get(scorer, RATING_BASE) + 1.3
	await _wait_for_pace()
	return true

## Quién anota un gol ambiental — al azar ponderado por puesto (un ST tiene
## mucha más chance que un DF). Solo presentación/nota: no cambia el balance
## del marcador, que ya lo decidió _maybe_ambient_goal.
## NUNCA devuelve al usuario: el usuario solo marca por SUS momentos clave
## (con scored_by_user=true). Antes un gol ambiental de tu equipo podía
## narrarse "Gol de <vos>" sin que hicieras nada (bug de Wilber), o peor,
## "Gol de <vos> · ¡ASISTENCIA TUYA!".
func _pick_weighted_scorer(team: MatchTeam) -> PlayerData:
	var field: Array = team.starting_xi.filter(func(p): return p.position != "GK" and p != user_player and not (p in _sent_off))
	if field.is_empty():
		return null
	var weights: Array = field.map(func(p): return {"ST": 5.0, "MF": 2.5, "DF": 1.0}.get(p.position, 1.5))
	var total: float = 0.0
	for w in weights:
		total += w
	var roll: float = randf() * total
	for i in range(field.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return field[i]
	return field[field.size() - 1]

# --- Sustituciones ---

func _maybe_substitute_user(minute: int) -> void:
	# user_player es null si estás cumpliendo sanción (MatchLauncher.prepare
	# arma el partido con user_for_match=null) — CRASH real encontrado en
	# la auditoría: sin este guard, el resto de la función igual podía
	# tirar el dado y reventar más abajo (team.deployed_code(null) accede
	# a null.detailed_position). Los otros 9 sitios de este archivo que
	# tocan user_player ya se cuidaban de esto; a este le faltaba.
	if user_player == null:
		return
	# Bug real de la auditoría: faltaba _user_subbed_off acá. Si el usuario
	# arrancó en el banco, entró de cambio y DESPUÉS lo sacaron (pedido
	# propio o el DT), _user_is_starter seguía en false y _user_is_on_pitch
	# volvía a false — sin este chequeo, esta función podía volver a
	# meterlo una segunda vez en el mismo partido, algo que el propio
	# código dice garantizar que nunca pasa.
	if _user_is_starter or _user_is_on_pitch or _user_injured or _user_red_carded or _user_subbed_off:
		return
	if user_not_called():
		return
	# El DT NO te mete un suplente a los 15' porque lo pediste. Solo:
	#  - si hubo una baja forzada en TU equipo (lesión/roja de un compañero)
	#    → entrás casi seguro en el próximo par de minutos, a cualquier hora;
	#  - si no, recién desde ~58' y con chance creciente hacia el final;
	#  - sin pedirlo, muy chica y solo en la recta final.
	var chance: float
	if _user_wants_on and _forced_change_user_side:
		chance = 0.7
	elif _user_wants_on and minute >= 58:
		chance = 0.08 + clamp((minute - 58) / 25.0, 0.0, 1.0) * 0.32
	elif _user_wants_on:
		return  # el DT tomó nota, pero no es momento
	elif minute >= 65:
		chance = clamp((minute - 65) / 25.0, 0.0, 1.0) * 0.03
	else:
		return
	if randf() < chance:
		_user_is_on_pitch = true
		_user_wants_on = false
		_forced_change_user_side = false
		_user_on_minute = minute
		var user_home: bool = user_player in _home_roster
		# Sale un compañero de la XI (no el portero) para hacerte lugar.
		var team: MatchTeam = home_team if user_home else away_team
		# Bug real encontrado en la auditoría: sin el `break`, este loop se
		# quedaba SIEMPRE con el último de starting_xi (por el orden
		# GK->DF->MF->ST que mantiene _sort_by_deployed, casi siempre un
		# delantero) sin importar tu posición — entrabas de 9 aunque fueras
		# defensor. Ahora primero busca a alguien de tu MISMA línea, y solo
		# si no hay (formación rarísima) cae a cualquiera que no sea el arquero.
		var out_p: PlayerData = null
		for p in team.starting_xi:
			if p != user_player and p.position != "GK" and p.position == user_player.position:
				out_p = p
				break
		if out_p == null:
			for p in team.starting_xi:
				if p != user_player and p.position != "GK":
					out_p = p
					break
		var idx: int = team.starting_xi.find(out_p) if out_p != null else -1
		if idx != -1:
			team.starting_xi[idx] = user_player
			# El usuario hereda el PUESTO TÁCTICO del compañero que sale (no
			# necesariamente su posición de oficio) — pedido de Wilber:
			# "cuando entre que me diga en qué posición voy a jugar". Sin
			# esto, deployed_code(user_player) caía al fallback (tu propia
			# posición de oficio), que podía no tener nada que ver con el
			# hueco real que estás cubriendo.
			team.deployed_position[user_player] = team.deployed_code(out_p)
		if not _ratings.has(user_player):
			_ratings[user_player] = RATING_BASE
		_emit(MatchEvent.Type.SUBSTITUTION, minute, {
			"player": user_player, "player_in": user_player, "player_out": out_p,
			"entering": true, "is_user": true, "home": user_home,
			"position": team.deployed_code(user_player),
		})

## Pediste el cambio para descansar: el DT te saca en el próximo par de
## minutos y mete a alguien del banco. Al salir dejás de recibir momentos
## clave y tu nota queda fijada.
func _maybe_user_sub_off(minute: int) -> bool:
	if not _user_wants_off or not _user_is_on_pitch or _user_injured or _user_red_carded:
		return false
	if minute < 25:
		return false # muy temprano, el DT no te saca todavía
	if randf() >= 0.5:
		return false
	_user_is_on_pitch = false
	_user_wants_off = false
	_user_subbed_off = true   # ya no podés volver a entrar este partido
	var user_home: bool = user_player in _home_roster
	var team: MatchTeam = home_team if user_home else away_team
	var replacement: PlayerData = null
	for p in team.bench:
		if p != user_player and not team.starting_xi.has(p):
			replacement = p
			break
	var idx: int = team.starting_xi.find(user_player)
	if idx != -1 and replacement != null:
		team.starting_xi[idx] = replacement
		_ratings[replacement] = RATING_BASE
	_emit(MatchEvent.Type.SUBSTITUTION, minute, {
		"home": user_home, "entering": false, "is_user": true,
		"player_out": user_player, "player_in": replacement,
	})
	await _wait_for_pace()
	return true

## Si vas jugando MUY mal, el DT te puede sacar sin que lo pidas — pedido
## de Wilber: "si estoy jugando muy mal, el técnico me puede cambiar del
## partido". Antes el ÚNICO camino para salir (fuera de lesión/roja) era
## que VOS lo pidieras (_maybe_user_sub_off) — un DT real no espera a que
## se lo pidas si la nota es un desastre. Igual que el resto de las
## decisiones del DT: nunca antes de que hayas tenido margen real para
## mostrar algo (min. 60+, y al menos 20' en cancha si entraste de cambio).
const COACH_PULL_RATING_THRESHOLD := 4.0
const COACH_PULL_MIN_MINUTE := 60
const COACH_PULL_CHANCE_PER_CHECK := 0.05

func _maybe_coach_subs_user_off(minute: int) -> bool:
	if not _user_is_on_pitch or _user_injured or _user_red_carded:
		return false
	if minute < COACH_PULL_MIN_MINUTE:
		return false
	if not _user_is_starter and minute - _user_on_minute < 20:
		return false
	if _rating_calc.get_rating() > COACH_PULL_RATING_THRESHOLD:
		return false
	if randf() >= COACH_PULL_CHANCE_PER_CHECK:
		return false
	_user_is_on_pitch = false
	_user_wants_off = false
	_user_subbed_off = true
	var user_home: bool = user_player in _home_roster
	var team: MatchTeam = home_team if user_home else away_team
	var replacement: PlayerData = null
	for p in team.bench:
		if p != user_player and not team.starting_xi.has(p):
			replacement = p
			break
	var idx: int = team.starting_xi.find(user_player)
	if idx != -1 and replacement != null:
		team.starting_xi[idx] = replacement
		_ratings[replacement] = RATING_BASE
	_emit(MatchEvent.Type.SUBSTITUTION, minute, {
		"home": user_home, "entering": false, "is_user": true, "coach_pull": true,
		"player_out": user_player, "player_in": replacement,
	})
	await _wait_for_pace()
	return true

## Cambio de la IA (cualquiera de los dos equipos, nunca saca al usuario)
## — probabilidad creciente hacia el final, tope MAX_AI_SUBS por equipo.
## Cambio de la IA para CUALQUIERA de los dos equipos, con lógica:
##  - cansancio: sale el titular con MENOS resistencia (proxy de fatiga)
##  - marcador + lo que busca el DT: perdiendo -> saca un defensor y mete
##    delantero/medio; ganando y sobre el final -> saca delantero y mete
##    defensor para aguantar; empatado -> refresco por posición (like-for-
##    like)
##  - nunca toca al portero ni al usuario; tope MAX_AI_SUBS por equipo
func _maybe_ai_substitution(minute: int, is_home: bool) -> bool:
	var done: int = _ai_subs_home if is_home else _ai_subs_away
	if done >= MAX_AI_SUBS:
		return false

	var team: MatchTeam = home_team if is_home else away_team
	var my_goals: int = _score["home"] if is_home else _score["away"]
	var opp_goals: int = _score["away"] if is_home else _score["home"]
	var losing: bool = my_goals < opp_goals
	var winning: bool = my_goals > opp_goals
	var deficit: int = opp_goals - my_goals   # >0 si voy perdiendo

	# Ventana: normalmente desde AI_SUB_WINDOW_START, pero un DT que va
	# perdiendo por 2+ mueve el banco ANTES (desde el 46').
	var window_start: int = 46 if deficit >= 2 else AI_SUB_WINDOW_START
	if minute < window_start:
		return false

	# Chance por minuto: base creciente hacia el final, MÁS ganas cuanto
	# peor va el marcador (un DT 2 abajo cambia con urgencia).
	var chance: float = clampf(float(minute - window_start) / 35.0, 0.0, 1.0) * 0.07
	if deficit >= 1:
		chance *= (1.6 + 0.7 * float(mini(deficit, 3)))   # ~2.3x con 1 abajo, ~3.7x con 3
	elif winning and minute >= 78:
		chance *= 1.5                                      # cierra el partido / mata tiempo
	if randf() >= chance:
		return false

	var out_pool: Array = team.starting_xi.filter(func(p): return p != user_player and p.position != "GK")
	var in_pool: Array = team.bench.filter(func(p): return p != user_player and not team.starting_xi.has(p) and p.position != "GK")
	if out_pool.is_empty() or in_pool.is_empty():
		return false

	# Posición que el DT quiere QUITAR y METER según el contexto.
	var want_out_pos: String = ""
	var want_in_pos: String = ""
	if deficit >= 2:
		# 2+ abajo: entra ataque sí o sí (aunque sea temprano).
		want_out_pos = "DF"
		want_in_pos = "ST"
	elif losing and minute >= 60:
		want_out_pos = "DF"
		want_in_pos = "ST" if randf() < 0.6 else "MF"
	elif winning and minute >= 72:
		want_out_pos = "ST"
		want_in_pos = "DF" if randf() < 0.6 else "MF"

	# Elegir quién SALE: si hay preferencia de posición, de esa línea; si
	# no, del campo. Sale el PEOR combinado = poca resistencia + jugando
	# mal (nota baja) — antes solo miraba la resistencia, así un jugador
	# con un partido horrible seguía en cancha si estaba entero.
	var candidates_out: Array = out_pool
	if want_out_pos != "":
		var line_pool: Array = out_pool.filter(func(p): return p.position == want_out_pos)
		if not line_pool.is_empty():
			candidates_out = line_pool
	candidates_out.sort_custom(func(a, b):
		var sa: float = float(a.stamina) + (_ratings.get(a, RATING_BASE) - RATING_BASE) * 14.0
		var sb: float = float(b.stamina) + (_ratings.get(b, RATING_BASE) - RATING_BASE) * 14.0
		return sa < sb)
	var out_p: PlayerData = candidates_out[randi() % mini(3, candidates_out.size())]

	# Elegir quién ENTRA: misma posición que quiero, si no la del que sale,
	# si no el mejor disponible.
	var target_in_pos: String = want_in_pos if want_in_pos != "" else out_p.position
	var same: Array = in_pool.filter(func(p): return p.position == target_in_pos)
	var in_p: PlayerData
	if not same.is_empty():
		same.sort_custom(func(a, b): return a.overall > b.overall)
		in_p = same[0]
	else:
		in_pool.sort_custom(func(a, b): return a.overall > b.overall)
		in_p = in_pool[0]

	var idx: int = team.starting_xi.find(out_p)
	if idx == -1:
		return false
	team.starting_xi[idx] = in_p
	_ratings[in_p] = RATING_BASE
	if is_home:
		_ai_subs_home += 1
	else:
		_ai_subs_away += 1

	_emit(MatchEvent.Type.SUBSTITUTION, minute, {
		"home": is_home, "entering": false, "is_user": false,
		"player_out": out_p, "player_in": in_p,
	})
	await _wait_for_pace()
	return true

# --- Eventos ambientales (no dependen de un momento clave del usuario) ---

func _maybe_environmental_card(minute: int) -> bool:
	if randf() >= ENV_CARD_CHANCE_PER_MINUTE * referee_card_mult:
		return false
	var candidate := _pick_random_pitch_player()
	if candidate == null or candidate in _sent_off:
		return false
	# Un jugador YA amonestado se cuida (10-oct): 2 de cada 3 veces esa
	# falta no termina en la segunda amarilla. Sin esto, con ~4 amarillas por
	# partido salían 0,4 rojas (real ~0,2), casi todas por doble amarilla.
	var booked: bool = (candidate == user_player and _user_yellows > 0) or int(_yellow_counts.get(candidate, 0)) > 0
	if booked and randf() < 0.66:
		return false
	var on_home_c: bool = candidate in _home_roster
	await _book_player(candidate, minute, randf() < ENV_CARD_RED_RATIO and _red_allowed(on_home_c))
	return true

## Amonesta (o expulsa, `is_red`) a `candidate`: cuenta amarillas, segunda
## amarilla = roja, efectos de la expulsión y el evento. Lo usan la tarjeta
## "ambiental" y la falta por una BARRIDA tuya que llega tarde (10-oct).
func _book_player(candidate: PlayerData, minute: int, is_red: bool) -> void:
	var on_home: bool = candidate in _home_roster
	var is_user := candidate == user_player
	var double_yellow := false
	# SEGUNDA AMARILLA en el mismo partido = ROJA (siempre, sin importar el
	# tope de rojas). Pedido de Wilber -- aplica a CUALQUIER jugador, no
	# solo al usuario (antes solo _user_yellows llevaba la cuenta).
	if not is_red:
		if is_user:
			_user_yellows += 1
			if _user_yellows >= 2:
				is_red = true
				double_yellow = true
				_user_double_yellow = true
		else:
			var n: int = int(_yellow_counts.get(candidate, 0)) + 1
			_yellow_counts[candidate] = n
			if n >= 2:
				is_red = true
				double_yellow = true
	_stats["home" if on_home else "away"]["fouls"] += 1

	if is_red:
		# Bug real encontrado en la auditoría: acá SOLO se registraba la
		# roja directa, nunca la de doble amarilla (aunque el comentario de
		# arriba diga "siempre, sin importar el tope de rojas" — eso vale
		# para DECIDIR la expulsión, no para dejar de CONTAR el jugador
		# menos que ya tiene ese equipo). Sin esto, un equipo con una
		# expulsión por doble amarilla podía igual sacarse OTRA roja directa
		# en otro jugador más tarde — dos expulsados, rompiendo el "tope
		# duro: máximo UNA roja por equipo y partido" que el código dice
		# garantizar.
		_register_red(on_home)
		_sent_off.append(candidate)   # no vuelve a recibir tarjetas ni lesión
	if is_user:
		_rating_calc.register_card(is_red)
		if is_red:
			_user_red_carded = true
			_user_is_on_pitch = false
	elif is_red and on_home == (user_player in _home_roster):
		_forced_change_user_side = true  # roja a un compañero → hueco real
	if is_red:
		_apply_red_card_effect(on_home)
	_ratings[candidate] = _ratings.get(candidate, RATING_BASE) - (1.4 if is_red else 0.4)

	_emit(is_red_to_type(is_red), minute, {"player": candidate, "is_user": is_user, "home": on_home, "double_yellow": double_yellow})
	await _wait_for_pace()

## BARRIDA que no llegó (ui_result "slide"): falta, y puede ser tarjeta.
var _last_decision_ok: bool = true
var _last_decision_goal: bool = false
func _maybe_slide_foul(ui_result: Dictionary, minute: int) -> void:
	if not bool(ui_result.get("slide", false)) or _last_decision_ok or not _user_is_on_pitch or user_player in _sent_off:
		return
	_stats["home" if user_player in _home_roster else "away"]["fouls"] += 1
	if randf() < DecisionResolver.SLIDE_FOUL_CARD_CHANCE * referee_card_mult:
		await _book_player(user_player, minute, randf() < DecisionResolver.SLIDE_RED_CHANCE and _red_allowed(user_player in _home_roster))

func is_red_to_type(is_red: bool) -> MatchEvent.Type:
	return MatchEvent.Type.CARD_RED if is_red else MatchEvent.Type.CARD_YELLOW

func _maybe_environmental_injury(minute: int) -> bool:
	# Recaída: si apuraste la vuelta de una lesión, el riesgo extra es TUYO.
	var forced_user: bool = PlayerDevelopment.reinjury_active(user_player) and _user_is_on_pitch and not _user_injured 		and randf() < ENV_INJURY_CHANCE_PER_MINUTE * (PlayerDevelopment.REINJURY_MULT - 1.0) * 0.5
	if not forced_user and randf() >= ENV_INJURY_CHANCE_PER_MINUTE:
		return false
	var candidate := user_player if forced_user else _pick_random_pitch_player()
	if candidate == null:
		return false
	var is_user := candidate == user_player
	# Vendaje preventivo de la Tienda: baja MUCHO la probabilidad de que la
	# lesión ambiental le toque justo al usuario este partido (la flag la
	# descuenta MatchSummary al terminar).
	if is_user and user_player != null and int(user_player.active_effects.get("injury_shield_matches", 0)) > 0:
		if randf() < (1.0 - ShopEngine.BANDAGE_RISK_FACTOR):
			return false # el vendaje "absorbe" el golpe: no hay lesión
	var inj_home: bool = candidate in _home_roster
	if is_user:
		_user_injured = true
		_user_is_on_pitch = false

	_emit(MatchEvent.Type.INJURY, minute, {"player": candidate, "is_user": is_user, "home": inj_home})
	await _wait_for_pace()

	# TODA lesión obliga a un cambio: el equipo del lesionado mete un
	# suplente en su lugar (si le quedan y hay banco) — pedido de Wilber.
	var replaced: bool = await _sub_in_for_injured(candidate, inj_home, minute)
	if not replaced and not is_user and inj_home == (user_player in _home_roster):
		# No se pudo reemplazar a un compañero (banco agotado): queda el
		# hueco y el usuario puede pedir entrar a cubrirlo.
		_forced_change_user_side = true
	return true

## Mete un suplente por el jugador lesionado. Devuelve true si hubo cambio.
func _sub_in_for_injured(injured: PlayerData, is_home: bool, minute: int) -> bool:
	var team: MatchTeam = home_team if is_home else away_team
	var idx: int = team.starting_xi.find(injured)
	if idx == -1:
		return false
	var need_gk: bool = injured.position == "GK"
	var in_pool: Array = team.bench.filter(func(p):
		return p != user_player and not team.starting_xi.has(p) and (p.position == "GK") == need_gk)
	if in_pool.is_empty() and not need_gk:
		in_pool = team.bench.filter(func(p): return p != user_player and not team.starting_xi.has(p) and p.position != "GK")
	if in_pool.is_empty():
		return false
	# El mejor disponible de la misma posición; si no, el mejor a secas.
	var same: Array = in_pool.filter(func(p): return p.position == injured.position)
	var pool: Array = same if not same.is_empty() else in_pool
	pool.sort_custom(func(a, b): return a.overall > b.overall)
	var in_p: PlayerData = pool[0]
	team.starting_xi[idx] = in_p
	_ratings[in_p] = RATING_BASE
	if is_home:
		_ai_subs_home += 1
	else:
		_ai_subs_away += 1
	_emit(MatchEvent.Type.SUBSTITUTION, minute, {
		"home": is_home, "entering": false, "is_user": false, "forced_injury": true,
		"player_out": injured, "player_in": in_p,
	})
	await _wait_for_pace()
	return true

func _maybe_environmental_penalty(minute: int) -> bool:
	if _penalties_used >= MAX_PENALTIES:
		return false
	if randf() >= ENV_PENALTY_CHANCE_PER_MINUTE:
		return false
	_penalties_used += 1

	var awarded_to_home: bool = randf() < 0.5
	var attacking_team := home_team if awarded_to_home else away_team
	var defending_team := away_team if awarded_to_home else home_team
	_emit(MatchEvent.Type.PENALTY_AWARDED, minute, {"home": awarded_to_home})
	await _wait_for_pace()

	var user_attacks_this_side: bool = _user_team_is(attacking_team)
	var gk := _find_goalkeeper(defending_team)
	var gk_overall: int = gk.overall if gk != null else 60

	# Si sos el pateador designado, te toca patear. Un delantero lo es casi
	# siempre; un mediocampista a veces; un defensor/arquero casi nunca.
	# CRASH real encontrado probando el fix de _maybe_substitute_user
	# (Parte 94): user_player es null si estás cumpliendo sanción, y esta
	# línea accedía a user_player.position SIN chequear null — a
	# diferencia de _maybe_substitute_user (que solo se jugaba el dado
	# desde el minuto 65), esta función corre TODOS los minutos, así que
	# un partido de sanción con algún penal en 90' revienta seguro.
	var taker_chance: float = 0.3
	if user_player != null:
		taker_chance = {"ST": 0.85, "MF": 0.45, "DF": 0.12, "GK": 0.05}.get(user_player.position, 0.3)
	if user_player != null and user_attacks_this_side and _user_is_on_pitch and not _user_injured and not _user_red_carded and randf() < taker_chance:
		# El usuario es el pateador designado esta vez.
		await _user_takes_penalty(minute, awarded_to_home, gk_overall)
	else:
		# Penal resuelto ambientalmente (pateador de IA).
		var taker := _pick_random_field_player(attacking_team)
		var taker_composure: int = taker.composure if taker != null else 55
		var success: bool
		if _user_is_keeper_of(defending_team):
			# Sos el ARQUERO: te toca atajarlo (P4, 9-oct).
			success = not await _user_saves_penalty(taker_composure, minute, "penalty_save")
		else:
			var taker_shooting: int = taker.shooting if taker != null else 55
			success = DecisionResolver.resolve_shootout_kick(taker_composure, gk_overall, taker_shooting)
		if success:
			_register_goal_for(awarded_to_home, minute, false, taker, false, true)
			if taker != null:
				_ratings[taker] = _ratings.get(taker, RATING_BASE) + 1.0

	return true

## El usuario patea un penal (el del partido o el que le hicieron a él).
func _user_takes_penalty(minute: int, awarded_to_home: bool, gk_overall: int) -> void:
	var situation := {"minute": minute, "kind": "penalty", "player": user_player}
	_emit(MatchEvent.Type.DECISION_REQUEST, minute, situation)
	decision_requested.emit(situation)
	var ui_result: Dictionary = await _await_decision_result()
	var precision: float = clamp(ui_result.get("precision", 0.5), 0.0, 1.0)
	var outcome := DecisionResolver.resolve_penalty(user_player, gk_overall, precision, _match_attr_bonus)
	var rating_before: float = _ratings.get(user_player, RATING_BASE)
	if outcome["success"]:
		_bump_user_rating(1.2)
		_register_goal_for(awarded_to_home, minute, true, null, false, true)
	else:
		_rating_calc.register_decision_failed("penalty")
		_bump_user_rating(-0.6)
	# Bug real (9-oct): el penal TUYO nunca emitía DECISION_RESULT (los
	# momentos clave sí, ver _apply_decision_result) — si lo errabas no
	# salía ningún aviso ("Ataja el penal" estaba definido en Match.gd
	# pero el evento nunca llegaba) y la cancha 2D no tenía cómo saber
	# cómo terminó. Mismo payload que un momento clave.
	_emit(MatchEvent.Type.DECISION_RESULT, minute, {
		"kind": "penalty",
		"success": bool(outcome["success"]),
		"rating_delta": _ratings.get(user_player, RATING_BASE) - rating_before,
		"goal": bool(outcome["success"]),
	})

# --- Momentos clave del usuario ---

## `minute` viene del bucle. Garantiza un PISO de momentos clave y respeta
## el techo (MAX_CLEAR_CHANCES = 10). Entre medio, probabilidad normal.
func _should_trigger_key_moment(minute: int = 45) -> bool:
	if not _user_is_on_pitch or _user_injured or _user_red_carded:
		return false
	if _clear_chances_used >= MAX_CLEAR_CHANCES:
		return false
	if minute - _last_key_minute < 5:
		return false  # espaciado mínimo, no dos seguidos

	# Cuántos "debería" llevar a esta altura, escalado a los minutos que
	# realmente juega (si entró tarde, el objetivo baja proporcional).
	var mins_total: float = maxf(90.0 - float(_user_on_minute), 12.0)
	var mins_played: float = clampf(float(minute - _user_on_minute), 0.0, mins_total)
	var scaled_target: float = float(_key_moment_target) * (mins_total / 90.0)
	var due: int = int(round(scaled_target * (mins_played / mins_total)))
	if _clear_chances_used < due:
		_last_key_minute = minute
		return true

	var chance: float = BASE_CHANCE_PER_MINUTE.get(user_player.position, 0.015)
	if randf() < chance:
		_last_key_minute = minute
		return true
	return false

## Repertorio de momentos clave por puesto. Antes cada puesto tenía 1-2
## opciones fijas ("ST siempre remata"); ahora se sortea con peso para que
## el partido por decisiones tenga variedad (pedido explícito: revisar el
## prototipo y sumar decisiones). Cada kind mapea a un resolver propio en
## DecisionResolver — toda la matemática sigue en un solo lugar.
## `key_pass`/`through_ball` del ST bajados de 1.7/1.1 a 0.7/0.5 (Item 5,
## "hazlo todo" — balance pass): la sim de 20 temporadas mostró temporadas
## de UN MISMO ST con 50-62 goles Y 50-62 asistencias a la vez (ej. 2037:
## 62/62) — un delantero real casi nunca asiste casi tanto como convierte.
## Bajar esto reduce el peso de "asistidor" en el marcador de Balón de Oro/
## Asistidor sin tocar el resto de la tabla (MF/DF/GK intactos) ni la
## conversión por acción (DecisionResolver/CLEAN_HIT, ya calibrada aparte
## contra la sim de 5 temporadas) — ajuste deliberadamente conservador,
## solo la FRECUENCIA de que un ST reciba una ocasión de asistir en vez de
## rematar; recomendable re-correr la sim de 20 temporadas para confirmar
## que baja la dominancia antes de dar esto por cerrado.
## Parte 91 (re-medición pedida por Wilber tras la Parte 82): la sim
## seguía dando temporadas de un ST con asistencias a la par o por encima
## de los goles (ej. 48G/54A). Causa real encontrada revisando
## DecisionResolver a fondo: "dribble" (nunca gol propio, SIEMPRE
## asistencia si sale — ver el case "dribble" de _apply_decision_result)
## seguía con el peso ORIGINAL (2.0, el 2° más alto del ST) y su propia
## probabilidad de asistencia (hasta 0.52) es la más generosa de las 3
## rutas de asistencia — Parte 82 solo tocó key_pass/through_ball y dejó
## esta, la más grande, intacta. Bajado 2.0 -> 1.2 (mismo criterio
## conservador: solo FRECUENCIA, no la fórmula de conversión).
## Parte 91h (pedido de Wilber: "crea más situaciones de partido para
## actuar... distribuidas entre todas las posiciones y ataque, transición
## y defensa") — 12 momentos nuevos sumados al repertorio de cada puesto:
## volley/chip_shot/cutback/one_two/counter_run (ST), + cross/switch_play/
## recovery_tackle (MF), + recovery_tackle/block_shot (DF), +
## distribution/one_on_one_save/sweep_keeper (GK, que antes tenía solo 3
## acciones en todo su repertorio). De paso, "pressing" del ST bajado
## 1.4 -> 0.9 (pedido explícito de Wilber tras la Parte 91: era el único
## camino de asistencia del ST que quedó sin tocar en las dos pasadas de
## balance anteriores — ver DecisionResolver.resolve_pressing, su
## assist_odds propio no bajó, solo la frecuencia con la que sale).
const _KIND_WEIGHTS := {
	# 10-oct (números realistas): las OCASIONES DE GOL eran el 59% de los
	# momentos de un delantero (≈3,4 remates claros por partido). Ahora ~28%
	# (≈1,6) y el resto es juego: encarar, asociarse, presionar. Volante:
	# de 24% a ~13%.
	"ST": {"shot_on_goal": 1.9, "dribble": 1.7, "one_on_one": 0.6, "aerial_duel": 0.7, "key_pass": 1.5, "through_ball": 1.0, "pressing": 1.6, "free_kick": 0.35, "volley": 0.3, "chip_shot": 0.25, "cutback": 1.0, "one_two": 1.2, "counter_run": 1.2},
	"MF": {"key_pass": 2.6, "through_ball": 1.6, "shot_on_goal": 0.8, "long_shot": 0.9, "dribble": 1.6, "pressing": 1.5, "interception": 1.6, "tackle": 1.3, "free_kick": 0.5, "volley": 0.2, "cutback": 0.5, "cross": 1.3, "one_two": 1.1, "counter_run": 0.9, "switch_play": 1.0, "recovery_tackle": 1.0},
	"DF": {"tackle": 3.3, "interception": 2.4, "aerial_duel": 1.7, "last_ditch_tackle": 1.4, "clearance": 1.3, "key_pass": 1.1, "pressing": 0.9, "recovery_tackle": 1.0, "block_shot": 1.2},
	"GK": {"tackle": 3.0, "clearance": 2.0, "interception": 1.6, "distribution": 1.3, "one_on_one_save": 1.0, "sweep_keeper": 1.1},
}

## Alternativas COHERENTES con cada acción principal — el menú extra sale
## de acá, no de una "familia" gruesa (antes un remate de frente al arco
## ofrecía "tiro libre directo", que no tiene sentido; reporte de Wilber).
## Se filtran luego a lo que el resolver soporta.
const _COMPATIBLE_EXTRAS := {
	"shot_on_goal": ["one_on_one", "key_pass", "dribble", "volley", "chip_shot"],       # definir distinto / cederla / gambetear
	"one_on_one": ["shot_on_goal", "dribble", "key_pass", "chip_shot", "volley"],       # definir ya / amagar al arquero / pase atrás
	"long_shot": ["shot_on_goal", "through_ball", "dribble", "volley"],    # buscar el área / filtrar / encarar
	"free_kick": ["key_pass"],                                    # jugarla corta al área
	"aerial_duel": ["key_pass", "shot_on_goal"],                 # peinarla a un compañero / rematar de primera
	# 10-oct: una jugada de armado ya no ofrece "rematar" como alternativa —
	# si no, el jugador elegía remate en CADA momento y la cuenta de
	# ocasiones de arriba no servía. El remate llega cuando la jugada lo da
	# (o por la jugada encadenada tras un regate ganado).
	"dribble": ["key_pass", "counter_run", "one_two", "through_ball"],
	"key_pass": ["through_ball", "dribble", "cross", "cutback", "one_two", "switch_play"],
	"through_ball": ["key_pass", "dribble", "cutback", "cross", "one_two"],
	"pressing": ["tackle", "interception", "recovery_tackle"],
	"tackle": ["interception", "last_ditch_tackle", "clearance", "recovery_tackle", "block_shot"],
	"interception": ["tackle", "clearance", "recovery_tackle", "sweep_keeper"],
	"clearance": ["tackle", "last_ditch_tackle", "block_shot", "distribution"],
	"last_ditch_tackle": ["clearance", "tackle", "block_shot"],
	# --- Parte 91h: los 12 momentos nuevos, cada uno con sus propias
	# alternativas coherentes (mismo criterio de arriba: nunca una
	# "familia" gruesa) ---
	"volley": ["shot_on_goal", "chip_shot", "one_on_one"],
	"chip_shot": ["one_on_one", "volley", "shot_on_goal"],
	"cutback": ["key_pass", "cross", "through_ball"],
	"cross": ["key_pass", "cutback", "through_ball"],
	"one_two": ["key_pass", "through_ball", "dribble"],
	"counter_run": ["dribble", "key_pass", "through_ball"],
	"switch_play": ["key_pass", "through_ball", "cross"],
	"recovery_tackle": ["tackle", "interception", "pressing"],
	"distribution": ["key_pass", "clearance"],
	"block_shot": ["tackle", "last_ditch_tackle", "clearance"],
	"one_on_one_save": ["clearance", "tackle"],
	"sweep_keeper": ["clearance", "interception"],
}

## Pesos del puesto con el sesgo del estilo del DT aplicado.
func _biased_weights(position: String) -> Dictionary:
	var base: Dictionary = _KIND_WEIGHTS.get(position, {"key_pass": 1.0})
	if _moment_bias.is_empty():
		return base
	var out: Dictionary = {}
	for k in base:
		out[k] = float(base[k]) * float(_moment_bias.get(k, 1.0))
	return out

func _kind_for_position(position: String) -> String:
	return _weighted_pick(_biased_weights(position))

## Sorteo ponderado sobre {kind: peso}. Un solo lugar para no repetir el
## bucle en _kind_for_position y _decision_options.
func _weighted_pick(weights: Dictionary) -> String:
	if weights.is_empty():
		return "key_pass"
	var total: float = 0.0
	for w in weights.values():
		total += maxf(0.0, float(w))
	if total <= 0.0:
		return String(weights.keys()[0])
	var roll: float = randf() * total
	for k in weights:
		roll -= maxf(0.0, float(weights[k]))
		if roll <= 0.0:
			return String(k)
	return String(weights.keys()[0])

func _shuffle_in_place(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t

## Etiqueta corta (verbo) y pista de cada decisión — las usa la pantalla de
## partido para pintar el menú de acciones (el sistema "por decisiones" del
## prototipo: primero ELEGÍS qué hacer, después el minijuego de precisión).
const DECISION_LABELS := {
	"shot_on_goal": "Rematar", "key_pass": "Pase al área", "tackle": "Entrar a robar",
	"dribble": "Encarar 1v1", "long_shot": "Bombazo de lejos", "aerial_duel": "Ir por arriba",
	"interception": "Cortar el pase", "one_on_one": "Definir mano a mano", "free_kick": "Tiro libre directo",
	"through_ball": "Pase filtrado", "last_ditch_tackle": "Entrada desesperada", "clearance": "Despejar",
	"pressing": "Presionar arriba", "penalty": "Patear el penal",
	# --- Parte 91h: 12 momentos nuevos ---
	"volley": "Rematar de volea", "chip_shot": "Globito al arquero", "cutback": "Pase atrás desde el fondo",
	"cross": "Centrar al área", "one_two": "Jugar la pared", "counter_run": "Arrancar el contragolpe",
	"switch_play": "Cambiar el frente", "recovery_tackle": "Recuperarla en transición",
	"distribution": "Salida en largo", "block_shot": "Tirarte a tapar", "one_on_one_save": "Achicar y salir",
	"sweep_keeper": "Salir a cortar",
}
const DECISION_HINTS := {
	"shot_on_goal": "Riesgo medio · buscás el gol", "long_shot": "Difícil · si entra, golazo",
	"free_kick": "Muy difícil · golazo", "one_on_one": "Buen chance de gol",
	"dribble": "Generás peligro, no gol directo", "key_pass": "Buscás la asistencia",
	"through_ball": "Rompés la línea", "aerial_duel": "Duelo de fuerza",
	"pressing": "Robo en campo rival", "tackle": "Recuperás la pelota",
	"interception": "Anticipás el pase", "clearance": "Lo más seguro",
	"last_ditch_tackle": "Todo o nada, salvás un gol",
	# --- Parte 91h: 12 momentos nuevos ---
	"volley": "Difícil · golazo si entra", "chip_shot": "Delicado · buen chance de gol",
	"cutback": "Asistencia de calidad", "cross": "Buscás la asistencia",
	"one_two": "Combinación rápida", "counter_run": "Ganás el espacio a la carrera",
	"switch_play": "Cambiás el juego de lado", "recovery_tackle": "Robo urgente en transición",
	"distribution": "Lanzás el contragolpe", "block_shot": "Lo más seguro, con el cuerpo",
	"one_on_one_save": "Todo o nada, salvás un gol", "sweep_keeper": "Arriesgado, salís de la línea",
}

## Menú de 2-3 acciones para un momento clave: la de más peso del puesto
## (fija) + 1-2 más al azar del repertorio. Cada opción trae su `chance`
## (probabilidad de acierto CON un toque normal — la barra de precisión la
## ajusta después) para que el usuario elija informado. El kind elegido
## pasa igual por _apply_decision_result / DecisionResolver.
## Familias de acción — las opciones extra del menú se sacan de la MISMA
## familia que la principal, así no aparece "presionar arriba" en una
## jugada narrada como "mano a mano con el arquero".
const _KIND_FAMILY := {
	"shot_on_goal": "atacar", "one_on_one": "atacar", "long_shot": "atacar",
	"free_kick": "atacar", "aerial_duel": "atacar",
	"key_pass": "crear", "through_ball": "crear", "dribble": "crear", "pressing": "crear",
	"tackle": "defender", "interception": "defender", "clearance": "defender",
	"last_ditch_tackle": "defender",
}

func _decision_options(position: String, def_overall: int, gk_overall: int) -> Array:
	var weights: Dictionary = _biased_weights(position)
	# PRIMARIA por sorteo ponderado (antes era SIEMPRE la de más peso → un
	# ST veía "Rematar" en cada momento clave; reporte de Wilber). Así el
	# mismo puesto ve remate, gambeta, presión, pase... según sale la
	# jugada.
	var primary: String = _weighted_pick(weights)
	var picks: Array = [primary]

	# Extras COHERENTES con la primaria (no una familia gruesa). Se
	# priorizan los que además están en el repertorio del puesto, pero se
	# permite alguno de fuera (p.ej. un ST puede "ceder al compañero").
	var compat: Array = (_COMPATIBLE_EXTRAS.get(primary, []) as Array).duplicate()
	var in_pos: Array = []
	var out_pos: Array = []
	for k in compat:
		if k == primary:
			continue
		if not DECISION_LABELS.has(k):
			continue
		if weights.has(k):
			in_pos.append(k)
		else:
			out_pos.append(k)
	_shuffle_in_place(in_pos)
	_shuffle_in_place(out_pos)
	var pool: Array = in_pos + out_pos
	while picks.size() < 3 and not pool.is_empty():
		picks.append(pool.pop_front())
	# Garantía de al menos 2 opciones.
	if picks.size() < 2:
		for k in weights.keys():
			if k != primary:
				picks.append(k)
				break
	return _options_for_kinds(picks, def_overall, gk_overall)

## Arma las opciones (etiqueta, chance, dificultad) para una lista de acciones.
func _options_for_kinds(picks: Array, def_overall: int, gk_overall: int) -> Array:
	return picks.map(func(k): return {
		"kind": k,
		"label": DECISION_LABELS.get(k, k),
		"hint": DECISION_HINTS.get(k, ""),
		"chance_lo": _preview_chance(k, def_overall, gk_overall, 0.2),
		"chance_hi": _preview_chance(k, def_overall, gk_overall, 0.95),
		"difficulty": maxf(0.05, DecisionResolver.difficulty(
			k, user_player, _rival_overall_for(k, def_overall, gk_overall), _match_attr_bonus) - DecisionResolver.combo_ease(k, _combo_active())),
		"combo": _combo_active() and DecisionResolver.combo_ease(k, true) > 0.0,
	})

## Arenga de capitán (P4): la pantalla la pide en el entretiempo.
var _team_talk_used: bool = false
func can_captain_talk() -> bool:
	return not _team_talk_used and user_player != null and _user_is_on_pitch and WorldTickEngine.season.get("is_captain", false)

func captain_team_talk() -> bool:
	if not can_captain_talk():
		return false
	_team_talk_used = true
	var side: String = "home" if _user_team_is(home_team) else "away"
	_xg_mult[side] = float(_xg_mult[side]) * CaptaincyEngine.TALK_XG_FACTOR
	_match_attr_bonus += CaptaincyEngine.TALK_ATTR_BONUS
	return true

var _combo_until_minute: int = -1
## Jugada encadenada (DecisionResolver.CHAIN_*): `_chain_pending` la pide el
## regate ganado; `_in_chain` evita encadenar una cadena.
var _chain_pending: bool = false
var _in_chain: bool = false
## REBOTE del arquero (DecisionResolver.REBOUND_*): usa el mismo mecanismo
## de la jugada encadenada, con otras opciones (definir de primera).
var _chain_rebound: bool = false
var _last_minute_seen: int = 0
func _combo_active() -> bool:
	return _combo_until_minute >= 0 and _current_minute_for_combo() <= _combo_until_minute

func _current_minute_for_combo() -> int:
	return _last_minute_seen

## Rival que pesa en una acción: el arquero en los remates/definiciones,
## el defensor en el resto. Lo usa la dificultad del minijuego.
func _rival_overall_for(kind: String, def_overall: int, gk_overall: int) -> int:
	if kind in ["shot_on_goal", "long_shot", "one_on_one", "free_kick", "penalty", "penalty_shootout", "volley", "chip_shot"]:
		return gk_overall
	return def_overall

## Probabilidad de acierto de una acción para una precisión dada — la vista
## previa del menú muestra el rango entre un toque flojo (0.2) y uno casi
## perfecto (0.95), así el usuario ve cuánto pesa la barra en cada opción.
## Pasa por el MISMO resolver que la resolución real (nunca una segunda
## fórmula, ver DecisionResolver).
func _preview_chance(kind: String, def_overall: int, gk_overall: int, precision: float) -> float:
	var p := user_player
	var b := _match_attr_bonus
	var d: Dictionary
	match kind:
		"shot_on_goal": d = DecisionResolver.resolve_shot(p, gk_overall, precision, b)
		"long_shot": d = DecisionResolver.resolve_long_shot(p, gk_overall, precision, b)
		"one_on_one": d = DecisionResolver.resolve_one_on_one(p, gk_overall, precision, b)
		"free_kick": d = DecisionResolver.resolve_free_kick(p, gk_overall, precision, b)
		"key_pass": d = DecisionResolver.resolve_key_pass(p, def_overall, precision, b)
		"through_ball": d = DecisionResolver.resolve_through_ball(p, def_overall, precision, b)
		"dribble": d = DecisionResolver.resolve_dribble(p, def_overall, precision, b)
		"aerial_duel": d = DecisionResolver.resolve_aerial_duel(p, def_overall, precision, b)
		"pressing": d = DecisionResolver.resolve_pressing(p, def_overall, precision, b)
		"tackle": d = DecisionResolver.resolve_tackle(p, def_overall, precision, b)
		"interception": d = DecisionResolver.resolve_interception(p, def_overall, precision, b)
		"clearance": d = DecisionResolver.resolve_clearance(p, def_overall, precision, b)
		"last_ditch_tackle": d = DecisionResolver.resolve_last_ditch_tackle(p, def_overall, precision, b)
		# --- Parte 91h: 12 momentos nuevos ---
		"volley": d = DecisionResolver.resolve_volley(p, gk_overall, precision, b)
		"chip_shot": d = DecisionResolver.resolve_chip_shot(p, gk_overall, precision, b)
		"cutback": d = DecisionResolver.resolve_cutback(p, def_overall, precision, b)
		"cross": d = DecisionResolver.resolve_cross(p, def_overall, precision, b)
		"one_two": d = DecisionResolver.resolve_one_two(p, def_overall, precision, b)
		"counter_run": d = DecisionResolver.resolve_counter_run(p, def_overall, precision, b)
		"switch_play": d = DecisionResolver.resolve_switch_play(p, def_overall, precision, b)
		"recovery_tackle": d = DecisionResolver.resolve_recovery_tackle(p, def_overall, precision, b)
		"distribution": d = DecisionResolver.resolve_distribution(p, def_overall, precision, b)
		"block_shot": d = DecisionResolver.resolve_block_shot(p, def_overall, precision, b)
		"one_on_one_save": d = DecisionResolver.resolve_keeper_one_on_one(p, def_overall, precision, b)
		"sweep_keeper": d = DecisionResolver.resolve_sweeper_keeper(p, def_overall, precision, b)
		_: return 0.5
	return float(d.get("chance", 0.5))

## Narración corta de la jugada. Ahora SE DERIVA de la acción PRINCIPAL del
## menú (`primary_kind`) para que lo narrado y las opciones coincidan
## (pedido de Wilber: "a veces salen decisiones que no tienen que ver con
## la jugada narrada"). Solo texto; no toca balance.
func _situation_narration(primary_kind: String, minute: int, def_overall: int, gk_overall: int) -> String:
	var user_home := _user_team_is(home_team)
	var gf: int = _score["home"] if user_home else _score["away"]
	var ga: int = _score["away"] if user_home else _score["home"]

	var keeper_kinds := ["shot_on_goal", "one_on_one", "long_shot", "free_kick", "volley", "chip_shot"]
	var pass_kinds := ["key_pass", "through_ball", "dribble", "cutback", "cross", "one_two", "counter_run", "switch_play", "distribution"]

	var zona: String
	match primary_kind:
		"shot_on_goal": zona = "Te queda de frente al arco, dentro del área"
		"one_on_one": zona = "Te escapaste de la última línea: quedás MANO A MANO con el arquero"
		"long_shot": zona = "La pelota te cae al borde del área, con espacio para sacar el zurdazo"
		"free_kick": zona = "Falta a favor a la entrada del área. Tiro libre para vos"
		"aerial_duel": zona = "Sale un centro cerrado y vas a pelearla por arriba"
		"dribble": zona = "Encarás al marcador en velocidad, mano a mano"
		"key_pass": zona = "Levantás la cabeza y hay un compañero pidiéndola en el área"
		"through_ball": zona = "Ves el desmarque entre líneas para meter el pase filtrado"
		"pressing": zona = "El rival la tiene en su campo y salís a presionar arriba"
		"tackle": zona = "El rival avanza con la pelota por tu sector y vas al cruce"
		"interception": zona = "Se viene un pase del rival y estás para anticipar"
		"clearance": zona = "Cae un balón dividido en tu área y hay que despejarlo"
		"last_ditch_tackle": zona = "El delantero rival se escapa solo: entrada desesperada o es gol"
		"volley": zona = "El centro te cae de aire, sin control, a un paso del área"
		"chip_shot": zona = "El arquero salió a achicar y te quedó adelantado"
		"cutback": zona = "Llegás al fondo y hay un compañero pidiéndola atrás, de cara al arco"
		"cross": zona = "Ganás la línea de fondo con espacio para centrar"
		"one_two": zona = "Tenés un compañero cerca para jugar la pared"
		"counter_run": zona = "Se abrió el campo: podés arrancar el contragolpe"
		"switch_play": zona = "El rival se cerró de un lado, hay campo abierto del otro"
		"recovery_tackle": zona = "Perdiste la pelota recién y el rival sale rápido de contra"
		"distribution": zona = "Tenés el balón en las manos y tus compañeros ya arrancaron"
		"block_shot": zona = "El rival remata de cerca, apenas llegás a interponerte"
		"one_on_one_save": zona = "El delantero rival se escapó de la última línea: quedan mano a mano"
		"sweep_keeper": zona = "Un pase filtrado deja mano a mano al rival, tenés que salir a cortarlo"
		_: zona = "Se abre un momento clave en tu zona"

	var rival: String
	if primary_kind in keeper_kinds:
		rival = "El arquero (%d) achica el ángulo." % gk_overall
	elif primary_kind == "aerial_duel":
		rival = "Un rival de %d salta con vos." % def_overall
	else:
		rival = "Tenés un rival de %d encima." % def_overall

	var apoyo: String
	if primary_kind in pass_kinds:
		apoyo = ["Un compañero picó al espacio y te la pide.", "Se abre un pasillo si te animás a jugarla.", "Tenés dos opciones de pase, elegí rápido."][randi() % 3]
	elif primary_kind in keeper_kinds:
		apoyo = ["Nadie te va a ayudar acá: la decisión es tuya.", "El arco es lo único que ves.", "Un compañero llega tarde, resolvé vos."][randi() % 3]
	else:
		apoyo = ["El equipo se cierra atrás para taparte la ayuda.", "Estás solo en la acción, no hay relevo.", "Si no cortás vos, no corta nadie."][randi() % 3]

	var presion: String = ""
	if minute >= 75:
		if gf < ga:
			presion = " Vas %d-%d y el reloj corre." % [gf, ga]
		elif gf > ga:
			presion = " Ganás %d-%d, cuidá la pelota." % [gf, ga]
		else:
			presion = " Está %d-%d, cualquier jugada puede definir." % [gf, ga]
	elif minute <= 15 and gf == ga:
		presion = " Arranca el partido, sin apuro."

	return "%s. %s %s%s" % [zona, rival, apoyo, presion]

func _resolve_key_moment(minute: int) -> void:
	var user_team_is_home := _user_team_is(home_team)
	var opposing_team: MatchTeam = away_team if user_team_is_home else home_team
	var gk := _find_goalkeeper(opposing_team)
	var gk_overall: int = gk.overall if gk != null else 60
	var defender := _pick_random_field_player(opposing_team)
	var def_overall: int = defender.overall if defender != null else 60

	var options: Array = _decision_options(user_player.position, def_overall, gk_overall)
	# La narración se arma DESPUÉS de las opciones y sobre la acción
	# principal, así lo que se cuenta y lo que se puede elegir van juntos.
	var situation := {
		"minute": minute,
		"kind": options[0]["kind"], # compat: acción por defecto si la UI no elige
		"options": options,
		"narration": _situation_narration(String(options[0]["kind"]), minute, def_overall, gk_overall),
		"player": user_player,
	}
	_emit(MatchEvent.Type.DECISION_REQUEST, minute, situation)
	decision_requested.emit(situation)

	var ui_result: Dictionary = await _await_decision_result()
	var chosen: String = String(ui_result.get("kind", ""))
	if chosen == "":
		# Modo simular / la UI no mandó acción: se elige una al azar del menú.
		chosen = String(options[randi() % options.size()]["kind"])
	_chain_pending = false
	_chain_rebound = false
	_apply_decision_result(chosen, minute, ui_result)
	await _maybe_slide_foul(ui_result, minute)
	# LA JUGADA CONTINÚA (Etapa 2): mientras la pelota siga viva en tus pies
	# — regate ganado, rebote del arquero, pase que te devuelven, robo y
	# salida — volvés a intervenir, hasta CHAIN_MAX_LINKS veces seguidas.
	var depth: int = 0
	var last_kind: String = chosen
	while depth < DecisionResolver.CHAIN_MAX_LINKS and _user_is_on_pitch and not (user_player in _sent_off):
		var next_kinds: Array = []
		var narr: String = ""
		var was_rebound: bool = false
		var from_pass: bool = false
		var foul_won: bool = false
		if _chain_pending:
			was_rebound = _chain_rebound
			next_kinds = DecisionResolver.REBOUND_KINDS if was_rebound else DecisionResolver.CHAIN_KINDS
			narr = "¡REBOTE! El arquero la dejó viva en el área y te queda a vos: definí de primera." if was_rebound else "¡Lo pasaste! Quedás de frente al arco: rematá, o buscá a un compañero."
		elif not _last_decision_goal and randf() < DecisionResolver.continue_chance(last_kind, _last_decision_ok, depth):
			next_kinds = DecisionResolver.continue_kinds(last_kind, _last_decision_ok)
			narr = DecisionResolver.continue_narration(last_kind, _last_decision_ok)
			from_pass = _last_decision_ok and not (last_kind in DecisionResolver._WIN_BALL)   # pasaste y te la devuelven: antes te desmarcás
			foul_won = DecisionResolver.is_foul_won(last_kind, _last_decision_ok)
			if foul_won:
				_stats["away" if user_player in _home_roster else "home"]["fouls"] += 1
				# PENAL (11-oct): a veces la falta fue dentro del área. Lo
				# patea quien lo recibió — vos — y ahí termina la jugada.
				if _penalties_used < MAX_PENALTIES and randf() < DecisionResolver.PENALTY_FROM_FOUL_CHANCE:
					_penalties_used += 1
					var pen_home: bool = user_player in _home_roster
					_emit(MatchEvent.Type.PENALTY_AWARDED, minute, {"home": pen_home, "fouled_user": true})
					await _wait_for_pace()
					await _user_takes_penalty(minute, pen_home, gk_overall)
					break
		_chain_pending = false
		_chain_rebound = false
		if next_kinds.is_empty():
			break
		depth += 1
		# En el último eslabón ya no se encadena otra vez.
		_in_chain = depth >= DecisionResolver.CHAIN_MAX_LINKS
		var chain_opts: Array = _options_for_kinds(next_kinds, def_overall, gk_overall)
		var chain_sit := {
			"minute": minute, "kind": chain_opts[0]["kind"], "options": chain_opts, "chained": true, "rebound": was_rebound,
			"narration": narr, "link": depth, "from_pass": from_pass, "foul": foul_won,
			"player": user_player,
		}
		_emit(MatchEvent.Type.DECISION_REQUEST, minute, chain_sit)
		decision_requested.emit(chain_sit)
		var chain_res: Dictionary = await _await_decision_result()
		var chain_kind: String = String(chain_res.get("kind", ""))
		if chain_kind == "":
			chain_kind = String(chain_opts[randi() % chain_opts.size()]["kind"])
		_apply_decision_result(chain_kind, minute, chain_res)
		await _maybe_slide_foul(chain_res, minute)
		last_kind = chain_kind
	_in_chain = false
	_chain_pending = false
	_chain_rebound = false

func resolve_decision(ui_result: Dictionary) -> void:
	# Llamado desde la UI (MatchScreen) con {"precision": 0.0-1.0}
	# calculado por el minijuego táctil. Sirve tanto para momentos
	# clave normales como para penales (mismo contrato).
	_pending_decision_result = ui_result

func _await_decision_result() -> Dictionary:
	if instant_mode:
		return {"precision": _auto_precision()}
	while _pending_decision_result == null:
		await Engine.get_main_loop().process_frame
	var result: Dictionary = _pending_decision_result
	_pending_decision_result = null
	return result

## Precisión de un "toque" que nadie dio de verdad — el jugador rinde
## cerca de su propio nivel (compostura) con algo de variación, ni
## perfecto ni al azar puro; el peso real de la decisión sigue viniendo
## de los atributos del jugador dentro de DecisionResolver, esto solo
## imita "qué tan bien salió el toque" cuando no hay minijuego de verdad.
## GANCHO DE PRUEBA (tools/MatchNumbersProbe): si es >= 0, el "toque" sin
## minijuego imita a un HUMANO que clava la zona esa fracción de las veces
## (y si no, sale un toque flojo/regular). -1 = comportamiento normal.
var sim_clean_rate: float = -1.0

func _auto_precision() -> float:
	if sim_clean_rate >= 0.0:
		return randf_range(0.84, 1.0) if randf() < sim_clean_rate else randf_range(0.15, 0.68)
	# Sin minijuego real (simular / bulk-advance): el "toque" imita a un
	# jugador de su nivel. Calibrado para que un crack (media ~92) clave la
	# zona (≥ CLEAN_HIT) ~38% de las veces y un juvenil (~55) ~18% — si no,
	# un delantero top mete 60 goles por liga (visto en la sim de 5 temporadas).
	var avg: float = (float(user_player.overall) + float(user_player.composure)) * 0.5
	var c: float = clampf(0.003 + avg * 0.00375, 0.05, 0.42)
	return clampf(randf() * 0.6 + c, 0.0, 1.0)

func _apply_decision_result(kind: String, minute: int, ui_result: Dictionary) -> void:
	_clear_chances_used += 1
	var rating_before: float = _ratings.get(user_player, RATING_BASE)
	var goals_before: int = _score["home"] + _score["away"]
	var disallowed_before: int = _disallowed_count
	var precision: float = clamp(ui_result.get("precision", 0.5), 0.0, 1.0)
	# La fatiga baja la precisión, PERO un toque limpio (clavaste la zona)
	# no puede caer por debajo de CLEAN_HIT — la acción entra igual, solo
	# pierde margen (regla de Wilber: "si le pego bien a la barra, entra").
	# Un toque flojo sí sufre toda la penalización.
	var _was_clean: bool = precision >= DecisionResolver.CLEAN_HIT
	precision = clampf(precision * (1.0 - _fatigue_precision_penalty(minute) - _carried_fatigue_penalty), 0.0, 1.0)
	if _was_clean:
		precision = maxf(precision, DecisionResolver.CLEAN_HIT)
	var user_team_is_home := _user_team_is(home_team)
	var opposing_team := away_team if user_team_is_home else home_team
	var gk := _find_goalkeeper(opposing_team)
	var gk_overall: int = gk.overall if gk != null else 60

	# JUGADA EN VIVO (match_live): lo que pasó en la cancha manda.
	if bool(ui_result.get("live", false)) and ui_result.has("outcome"):
		_apply_live_outcome(kind, minute, String(ui_result["outcome"]), user_team_is_home, opposing_team)
	else:
		match kind:
			"shot_on_goal":
				var outcome := DecisionResolver.resolve_shot(user_player, gk_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_goal()
					_bump_user_rating(1.4)
					_register_goal_for(user_team_is_home, minute, true)
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.15)
			"key_pass":
				var defender := _pick_random_field_player(opposing_team)
				var defender_overall: int = defender.overall if defender != null else 60
				var outcome := DecisionResolver.resolve_key_pass(user_player, defender_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_key_pass_success()
					_bump_user_rating(0.6)
					# Pase limpio (clavaste el minijuego) → el compañero la mete
					# más veces que no; pase salvado al borde → chance normal.
					# (0.86 daba ~19 asist/temporada a un MF top — visto en la sim.)
					var _assist_odds: float = 0.44 if precision >= DecisionResolver.CLEAN_HIT else CONVERSION_CAP * 0.35
					if randf() <= _assist_odds * _assist_dampen():
						# Lo define un compañero (tu asistencia) — nunca vos.
						var finisher := _pick_weighted_scorer(home_team if user_team_is_home else away_team)
						_register_goal_for(user_team_is_home, minute, false, finisher, true)
						_user_assists += 1
						if finisher != null:
							_ratings[finisher] = _ratings.get(finisher, RATING_BASE) + 1.0
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.15)
			"tackle":
				var attacker := _pick_random_field_player(opposing_team)
				var attacker_overall: int = attacker.overall if attacker != null else 60
				var outcome := DecisionResolver.resolve_tackle(user_player, attacker_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_tackle_success()
					_bump_user_rating(0.45)
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.2)
					if randf() <= 0.25:
						# Bug real encontrado en la auditoría: acá nunca se pasaba un
						# scorer (a diferencia de _maybe_ambient_goal, que siempre
						# elige uno con peso) — el gol en contra quedaba con
						# scorer_name vacío en el evento, y el rival que en
						# realidad te la metió no se llevaba el +1.3 de nota que
						# le correspondía.
						var conceding_scorer := _pick_weighted_scorer(away_team if user_team_is_home else home_team)
						_register_goal_for(not user_team_is_home, minute, false, conceding_scorer)
						if conceding_scorer != null:
							_ratings[conceding_scorer] = _ratings.get(conceding_scorer, RATING_BASE) + 1.3
			"dribble":
				# Encarar 1v1: si sale, quedás de cara y hay chance de que termine
				# en gol de un compañero (tu jugada) — nunca gol tuyo directo acá.
				var marker := _pick_random_field_player(opposing_team)
				var marker_overall: int = marker.overall if marker != null else 60
				var outcome := DecisionResolver.resolve_dribble(user_player, marker_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_key_pass_success()
					_bump_user_rating(0.7)
					var _drib_odds: float = 0.52 if precision >= DecisionResolver.CLEAN_HIT else CONVERSION_CAP * 0.38
					# JUGADA ENCADENADA: en vez del sorteo, la definís vos ahora.
					if not _in_chain and randf() < DecisionResolver.CHAIN_CHANCE:
						_chain_pending = true
					elif randf() <= _drib_odds * _assist_dampen():
						var finisher := _pick_weighted_scorer(home_team if user_team_is_home else away_team)
						_register_goal_for(user_team_is_home, minute, false, finisher, true)
						_user_assists += 1
						if finisher != null:
							_ratings[finisher] = _ratings.get(finisher, RATING_BASE) + 1.0
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.2)
			"long_shot":
				# Bombazo de lejos: difícil, pero si entra vale más para tu nota.
				var outcome := DecisionResolver.resolve_long_shot(user_player, gk_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_goal()
					_bump_user_rating(1.6)
					_register_goal_for(user_team_is_home, minute, true)
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.1)
			"aerial_duel":
				var rival := _pick_random_field_player(opposing_team)
				var rival_overall: int = rival.overall if rival != null else 60
				var outcome := DecisionResolver.resolve_aerial_duel(user_player, rival_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					if user_player.position == "ST":
						# Cabezazo a gol.
						_rating_calc.register_goal()
						_bump_user_rating(1.3)
						_register_goal_for(user_team_is_home, minute, true)
					else:
						# Despeje ganado en el área propia.
						_rating_calc.register_tackle_success()
						_bump_user_rating(0.4)
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.15)
					if user_player.position != "ST" and randf() <= 0.2:
						# Bug real encontrado en la auditoría: acá nunca se pasaba un
						# scorer (a diferencia de _maybe_ambient_goal, que siempre
						# elige uno con peso) — el gol en contra quedaba con
						# scorer_name vacío en el evento, y el rival que en
						# realidad te la metió no se llevaba el +1.3 de nota que
						# le correspondía.
						var conceding_scorer := _pick_weighted_scorer(away_team if user_team_is_home else home_team)
						_register_goal_for(not user_team_is_home, minute, false, conceding_scorer)
						if conceding_scorer != null:
							_ratings[conceding_scorer] = _ratings.get(conceding_scorer, RATING_BASE) + 1.3
			"interception":
				var passer := _pick_random_field_player(opposing_team)
				var passer_overall: int = passer.overall if passer != null else 60
				var outcome := DecisionResolver.resolve_interception(user_player, passer_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_tackle_success()
					_bump_user_rating(0.5)
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.2)
					if randf() <= 0.18:
						# Bug real encontrado en la auditoría: acá nunca se pasaba un
						# scorer (a diferencia de _maybe_ambient_goal, que siempre
						# elige uno con peso) — el gol en contra quedaba con
						# scorer_name vacío en el evento, y el rival que en
						# realidad te la metió no se llevaba el +1.3 de nota que
						# le correspondía.
						var conceding_scorer := _pick_weighted_scorer(away_team if user_team_is_home else home_team)
						_register_goal_for(not user_team_is_home, minute, false, conceding_scorer)
						if conceding_scorer != null:
							_ratings[conceding_scorer] = _ratings.get(conceding_scorer, RATING_BASE) + 1.3
			"one_on_one":
				var outcome := DecisionResolver.resolve_one_on_one(user_player, gk_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_goal()
					_bump_user_rating(1.5)
					_register_goal_for(user_team_is_home, minute, true)
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.2)
			"free_kick":
				var outcome := DecisionResolver.resolve_free_kick(user_player, gk_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_goal()
					_bump_user_rating(1.7)
					_register_goal_for(user_team_is_home, minute, true)
				else:
					# Errar un tiro libre casi no penaliza — es una jugada "gratis".
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.05)
			"through_ball":
				var line := _pick_random_field_player(opposing_team)
				var line_overall: int = line.overall if line != null else 60
				var outcome := DecisionResolver.resolve_through_ball(user_player, line_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_key_pass_success()
					_bump_user_rating(0.75)
					if randf() <= CONVERSION_CAP * 0.42 * _assist_dampen():
						var finisher := _pick_weighted_scorer(home_team if user_team_is_home else away_team)
						_register_goal_for(user_team_is_home, minute, false, finisher, true)
						_user_assists += 1
						if finisher != null:
							_ratings[finisher] = _ratings.get(finisher, RATING_BASE) + 1.0
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.15)
			"last_ditch_tackle":
				var runner := _pick_random_field_player(opposing_team)
				var runner_overall: int = runner.overall if runner != null else 60
				var outcome := DecisionResolver.resolve_last_ditch_tackle(user_player, runner_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					# Salvaste un gol cantado.
					_rating_calc.register_tackle_success()
					_bump_user_rating(0.9)
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.35)
					if randf() <= 0.3:
						var on_home: bool = user_player in _home_roster
						var is_red: bool = randf() < 0.06 and _red_allowed(on_home)
						var dbl_y := false
						if not is_red:
							_user_yellows += 1
							if _user_yellows >= 2:
								is_red = true
								dbl_y = true
								_user_double_yellow = true
						if is_red:
							_register_red(on_home)  # mismo fix que _maybe_environmental_card: contar SIEMPRE, sea directa o doble amarilla
						_rating_calc.register_card(is_red)
						_bump_user_rating(-1.4 if is_red else -0.4)
						if is_red:
							_user_red_carded = true
							_user_is_on_pitch = false
							_apply_red_card_effect(on_home)
							_sent_off.append(user_player)  # mismo criterio que _maybe_environmental_card: no puede seguir "en cancha" para sorteos/tanda
						_stats["home" if on_home else "away"]["fouls"] += 1
						_emit(is_red_to_type(is_red), minute, {"player": user_player, "is_user": true, "home": on_home, "double_yellow": dbl_y})
					elif randf() <= 0.55:
						# Bug real encontrado en la auditoría: acá nunca se pasaba un
						# scorer (a diferencia de _maybe_ambient_goal, que siempre
						# elige uno con peso) — el gol en contra quedaba con
						# scorer_name vacío en el evento, y el rival que en
						# realidad te la metió no se llevaba el +1.3 de nota que
						# le correspondía.
						var conceding_scorer := _pick_weighted_scorer(away_team if user_team_is_home else home_team)
						_register_goal_for(not user_team_is_home, minute, false, conceding_scorer)
						if conceding_scorer != null:
							_ratings[conceding_scorer] = _ratings.get(conceding_scorer, RATING_BASE) + 1.3
			"clearance":
				var presser := _pick_random_field_player(opposing_team)
				var presser_overall: int = presser.overall if presser != null else 60
				var outcome := DecisionResolver.resolve_clearance(user_player, presser_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_tackle_success()
					_bump_user_rating(0.35)
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.2)
					if randf() <= 0.3:
						# Bug real encontrado en la auditoría: acá nunca se pasaba un
						# scorer (a diferencia de _maybe_ambient_goal, que siempre
						# elige uno con peso) — el gol en contra quedaba con
						# scorer_name vacío en el evento, y el rival que en
						# realidad te la metió no se llevaba el +1.3 de nota que
						# le correspondía.
						var conceding_scorer := _pick_weighted_scorer(away_team if user_team_is_home else home_team)
						_register_goal_for(not user_team_is_home, minute, false, conceding_scorer)
						if conceding_scorer != null:
							_ratings[conceding_scorer] = _ratings.get(conceding_scorer, RATING_BASE) + 1.3
			"pressing":
				var target := _pick_random_field_player(opposing_team)
				var target_overall: int = target.overall if target != null else 60
				var outcome := DecisionResolver.resolve_pressing(user_player, target_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_tackle_success()
					_bump_user_rating(0.5)
					if randf() <= 0.25 * _assist_dampen():
						var finisher := _pick_weighted_scorer(home_team if user_team_is_home else away_team)
						_register_goal_for(user_team_is_home, minute, false, finisher, true)
						_user_assists += 1
						if finisher != null:
							_ratings[finisher] = _ratings.get(finisher, RATING_BASE) + 1.0
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.15)
					if randf() <= 0.12:
						# Bug real encontrado en la auditoría: acá nunca se pasaba un
						# scorer (a diferencia de _maybe_ambient_goal, que siempre
						# elige uno con peso) — el gol en contra quedaba con
						# scorer_name vacío en el evento, y el rival que en
						# realidad te la metió no se llevaba el +1.3 de nota que
						# le correspondía.
						var conceding_scorer := _pick_weighted_scorer(away_team if user_team_is_home else home_team)
						_register_goal_for(not user_team_is_home, minute, false, conceding_scorer)
						if conceding_scorer != null:
							_ratings[conceding_scorer] = _ratings.get(conceding_scorer, RATING_BASE) + 1.3

			# --- Parte 91h: 12 momentos nuevos (5 ataque, 4 transición, 3 defensa) ---
			"volley":
				var outcome := DecisionResolver.resolve_volley(user_player, gk_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_goal()
					_bump_user_rating(1.7)
					_register_goal_for(user_team_is_home, minute, true)
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.2)
			"chip_shot":
				var outcome := DecisionResolver.resolve_chip_shot(user_player, gk_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_goal()
					_bump_user_rating(1.5)
					_register_goal_for(user_team_is_home, minute, true)
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.15)
			"cutback":
				var defender := _pick_random_field_player(opposing_team)
				var defender_overall: int = defender.overall if defender != null else 60
				var outcome := DecisionResolver.resolve_cutback(user_player, defender_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_key_pass_success()
					_bump_user_rating(0.65)
					if randf() <= 0.5 * _assist_dampen():
						var finisher := _pick_weighted_scorer(home_team if user_team_is_home else away_team)
						_register_goal_for(user_team_is_home, minute, false, finisher, true)
						_user_assists += 1
						if finisher != null:
							_ratings[finisher] = _ratings.get(finisher, RATING_BASE) + 1.0
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.15)
			"cross":
				var defender := _pick_random_field_player(opposing_team)
				var defender_overall: int = defender.overall if defender != null else 60
				var outcome := DecisionResolver.resolve_cross(user_player, defender_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_key_pass_success()
					_bump_user_rating(0.6)
					if randf() <= 0.4 * _assist_dampen():
						var finisher := _pick_weighted_scorer(home_team if user_team_is_home else away_team)
						_register_goal_for(user_team_is_home, minute, false, finisher, true)
						_user_assists += 1
						if finisher != null:
							_ratings[finisher] = _ratings.get(finisher, RATING_BASE) + 1.0
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.15)
			"one_two":
				var defender := _pick_random_field_player(opposing_team)
				var defender_overall: int = defender.overall if defender != null else 60
				var outcome := DecisionResolver.resolve_one_two(user_player, defender_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_key_pass_success()
					_bump_user_rating(0.55)
					if randf() <= 0.42 * _assist_dampen():
						var finisher := _pick_weighted_scorer(home_team if user_team_is_home else away_team)
						_register_goal_for(user_team_is_home, minute, false, finisher, true)
						_user_assists += 1
						if finisher != null:
							_ratings[finisher] = _ratings.get(finisher, RATING_BASE) + 1.0
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.15)
			"counter_run":
				var defender := _pick_random_field_player(opposing_team)
				var defender_overall: int = defender.overall if defender != null else 60
				var outcome := DecisionResolver.resolve_counter_run(user_player, defender_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_key_pass_success()
					_bump_user_rating(0.7)
					if randf() <= 0.46 * _assist_dampen():
						var finisher := _pick_weighted_scorer(home_team if user_team_is_home else away_team)
						_register_goal_for(user_team_is_home, minute, false, finisher, true)
						_user_assists += 1
						if finisher != null:
							_ratings[finisher] = _ratings.get(finisher, RATING_BASE) + 1.0
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.2)
			"switch_play":
				var defender := _pick_random_field_player(opposing_team)
				var defender_overall: int = defender.overall if defender != null else 60
				var outcome := DecisionResolver.resolve_switch_play(user_player, defender_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_key_pass_success()
					_bump_user_rating(0.6)
					if randf() <= 0.38 * _assist_dampen():
						var finisher := _pick_weighted_scorer(home_team if user_team_is_home else away_team)
						_register_goal_for(user_team_is_home, minute, false, finisher, true)
						_user_assists += 1
						if finisher != null:
							_ratings[finisher] = _ratings.get(finisher, RATING_BASE) + 1.0
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.15)
			"recovery_tackle":
				var attacker := _pick_random_field_player(opposing_team)
				var attacker_overall: int = attacker.overall if attacker != null else 60
				var outcome := DecisionResolver.resolve_recovery_tackle(user_player, attacker_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_tackle_success()
					_bump_user_rating(0.5)
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.2)
					if randf() <= 0.22:
						# Bug real encontrado en la auditoría: acá nunca se pasaba un
						# scorer (a diferencia de _maybe_ambient_goal, que siempre
						# elige uno con peso) — el gol en contra quedaba con
						# scorer_name vacío en el evento, y el rival que en
						# realidad te la metió no se llevaba el +1.3 de nota que
						# le correspondía.
						var conceding_scorer := _pick_weighted_scorer(away_team if user_team_is_home else home_team)
						_register_goal_for(not user_team_is_home, minute, false, conceding_scorer)
						if conceding_scorer != null:
							_ratings[conceding_scorer] = _ratings.get(conceding_scorer, RATING_BASE) + 1.3
			"distribution":
				var presser := _pick_random_field_player(opposing_team)
				var presser_overall: int = presser.overall if presser != null else 60
				var outcome := DecisionResolver.resolve_distribution(user_player, presser_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_key_pass_success()
					_bump_user_rating(0.55)
					if randf() <= 0.3 * _assist_dampen():
						var finisher := _pick_weighted_scorer(home_team if user_team_is_home else away_team)
						_register_goal_for(user_team_is_home, minute, false, finisher, true)
						_user_assists += 1
						if finisher != null:
							_ratings[finisher] = _ratings.get(finisher, RATING_BASE) + 1.0
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.15)
			"block_shot":
				var attacker := _pick_random_field_player(opposing_team)
				var attacker_overall: int = attacker.overall if attacker != null else 60
				var outcome := DecisionResolver.resolve_block_shot(user_player, attacker_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_tackle_success()
					_bump_user_rating(0.55)
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.3)
					if randf() <= 0.35:
						# Bug real encontrado en la auditoría: acá nunca se pasaba un
						# scorer (a diferencia de _maybe_ambient_goal, que siempre
						# elige uno con peso) — el gol en contra quedaba con
						# scorer_name vacío en el evento, y el rival que en
						# realidad te la metió no se llevaba el +1.3 de nota que
						# le correspondía.
						var conceding_scorer := _pick_weighted_scorer(away_team if user_team_is_home else home_team)
						_register_goal_for(not user_team_is_home, minute, false, conceding_scorer)
						if conceding_scorer != null:
							_ratings[conceding_scorer] = _ratings.get(conceding_scorer, RATING_BASE) + 1.3
			"one_on_one_save":
				var attacker := _pick_random_field_player(opposing_team)
				var attacker_overall: int = attacker.overall if attacker != null else 60
				var outcome := DecisionResolver.resolve_keeper_one_on_one(user_player, attacker_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_tackle_success()
					_bump_user_rating(0.95)
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.4)
					if randf() <= 0.7:
						# Bug real encontrado en la auditoría: acá nunca se pasaba un
						# scorer (a diferencia de _maybe_ambient_goal, que siempre
						# elige uno con peso) — el gol en contra quedaba con
						# scorer_name vacío en el evento, y el rival que en
						# realidad te la metió no se llevaba el +1.3 de nota que
						# le correspondía.
						var conceding_scorer := _pick_weighted_scorer(away_team if user_team_is_home else home_team)
						_register_goal_for(not user_team_is_home, minute, false, conceding_scorer)
						if conceding_scorer != null:
							_ratings[conceding_scorer] = _ratings.get(conceding_scorer, RATING_BASE) + 1.3
			"sweep_keeper":
				var attacker := _pick_random_field_player(opposing_team)
				var attacker_overall: int = attacker.overall if attacker != null else 60
				var outcome := DecisionResolver.resolve_sweeper_keeper(user_player, attacker_overall, precision, _match_attr_bonus)
				if outcome["success"]:
					_rating_calc.register_tackle_success()
					_bump_user_rating(0.6)
				else:
					_rating_calc.register_decision_failed(kind)
					_bump_user_rating(-0.35)
					if randf() <= 0.45:
						# Bug real encontrado en la auditoría: acá nunca se pasaba un
						# scorer (a diferencia de _maybe_ambient_goal, que siempre
						# elige uno con peso) — el gol en contra quedaba con
						# scorer_name vacío en el evento, y el rival que en
						# realidad te la metió no se llevaba el +1.3 de nota que
						# le correspondía.
						var conceding_scorer := _pick_weighted_scorer(away_team if user_team_is_home else home_team)
						_register_goal_for(not user_team_is_home, minute, false, conceding_scorer)
						if conceding_scorer != null:
							_ratings[conceding_scorer] = _ratings.get(conceding_scorer, RATING_BASE) + 1.3

		# Feedback para la UI: acierto/desacierto + cuánto sumó/restó tu nota.
	var rating_delta: float = _ratings.get(user_player, RATING_BASE) - rating_before
	var goal_came: bool = (_score["home"] + _score["away"]) > goals_before
	# COMBO (P4, 9-oct): un regate ganado deja al arquero descolocado — el
	# próximo remate en los siguientes minutos sale más fácil.
	if kind == "dribble" and rating_delta > 0.001:
		_combo_until_minute = minute + DecisionResolver.COMBO_MINUTES
	elif DecisionResolver.skill_bucket(kind) == "finish":
		_combo_until_minute = -1
	# Remate BIEN PEGADO que no fue gol (lo atajaron): no es un fallo tuyo.
	if _was_clean and not goal_came and DecisionResolver.skill_bucket(kind) == "finish" and _disallowed_count == disallowed_before:
		_rating_calc.register_shot_on_target()
	var annulled_now: bool = _disallowed_count > disallowed_before
	# REBOTE: remate bien pegado, atajado, y la pelota queda viva.
	var rebound_now: bool = false
	if _was_clean and not goal_came and not annulled_now and not _in_chain and _user_is_on_pitch \
			and DecisionResolver.skill_bucket(kind) == "finish" and not (kind in ["penalty", "penalty_shootout", "free_kick"]) \
			and randf() < DecisionResolver.REBOUND_CHANCE:
		_chain_pending = true
		_chain_rebound = true
		rebound_now = true
	_last_decision_ok = rating_delta > 0.001
	_last_decision_goal = goal_came or annulled_now
	_emit(MatchEvent.Type.DECISION_RESULT, minute, {
		"rebound": rebound_now,
		"kind": kind,
		"success": rating_delta > 0.001,
		"rating_delta": rating_delta,
		"goal": goal_came,
		# VAR: "annulled" = la jugada fue gol y lo anularon; "valid" = lo
		# revisaron y vale. La UI muestra la revisión; acá ya está resuelto.
		"var": "annulled" if annulled_now else (_last_goal_var if goal_came else ""),
	})
	# La pausa por celebración/gol ya la maneja _drain_ack() en _tick_minute
	# (el evento GOAL prende _pending_ack para CUALQUIER gol) — antes esto
	# solo pausaba los goles nacidos de un momento clave.

func _bump_user_rating(delta: float) -> void:
	_ratings[user_player] = _ratings.get(user_player, RATING_BASE) + delta

func _register_goal_for(is_home: bool, minute: int, scored_by_user: bool, scorer: PlayerData = null, assist_by_user: bool = false, no_var: bool = false) -> void:
	# VAR REAL (10-oct): un gol de jugada puede revisarse y anularse. Se
	# decide ACÁ, antes de contar nada — un gol anulado nunca llega al
	# marcador ni a las estadísticas de goles. Penales: sin VAR.
	_last_goal_var = ""
	if not no_var:
		var v: Dictionary = DecisionResolver.var_review(referee_var_mult)
		if bool(v["reviewed"]):
			_last_goal_var = "annulled" if bool(v["overturned"]) else "valid"
		if bool(v["overturned"]):
			_disallowed_count += 1
			_stats["home" if is_home else "away"]["shots"] += 1
			if scored_by_user:
				# Lo que el llamador ya te había sumado por el "gol".
				_rating_calc.unregister_goal()
				_bump_user_rating(-1.0)
			var dn: String = user_player.player_name if scored_by_user else (scorer.player_name if scorer != null else "")
			_emit(MatchEvent.Type.GOAL_DISALLOWED, minute, {
				"home": is_home, "scored_by_user": scored_by_user, "scorer_name": dn,
				"assist_by_user": assist_by_user, "reason": String(v["reason"]),
			})
			return
	if is_home:
		_score["home"] += 1
	else:
		_score["away"] += 1
	if scored_by_user:
		_user_goals += 1
	var goal_side: String = "home" if is_home else "away"
	_stats[goal_side]["shots"] += 1
	_stats[goal_side]["on_target"] += 1
	var scorer_name: String = ""
	if scored_by_user:
		scorer_name = user_player.player_name
	elif scorer != null:
		scorer_name = scorer.player_name
	if scored_by_user or assist_by_user:
		_celeb_pending = true
	_emit(MatchEvent.Type.GOAL, minute, {
		"scored_by_user": scored_by_user, "home": is_home, "scorer_name": scorer_name,
		"assist_by_user": assist_by_user,
		"assist_name": user_player.player_name if assist_by_user and user_player != null else "",
		"var": _last_goal_var,
	})

# --- Tanda de penales (muerte súbita) ---

func _run_penalty_shootout() -> String:
	_emit(MatchEvent.Type.PENALTY_SHOOTOUT, 120, {"phase": "start"})

	var home_takers := _order_takers(home_team)
	var away_takers := _order_takers(away_team)
	var home_gk := _find_goalkeeper(away_team)
	var away_gk := _find_goalkeeper(home_team)
	var home_gk_overall: int = away_gk.overall if away_gk != null else 60 # el GK que ATAJA es el del equipo contrario
	var away_gk_overall: int = home_gk.overall if home_gk != null else 60

	var home_score := 0
	var away_score := 0
	var round_index := 0

	while true:
		var home_taker: PlayerData = home_takers[round_index % home_takers.size()] if home_takers.size() > 0 else null
		var away_taker: PlayerData = away_takers[round_index % away_takers.size()] if away_takers.size() > 0 else null

		if home_taker != null:
			var home_success := await _take_shootout_kick(home_taker, away_gk_overall, away_team)
			if home_success:
				home_score += 1
			_emit(MatchEvent.Type.PENALTY_SHOOTOUT, 120, {"team": "home", "success": home_success, "score": [home_score, away_score],
				"taker": home_taker.player_name, "is_user": home_taker == user_player or _user_is_keeper_of(away_team), "home": true, "n": round_index * 2})
			await _drain_ack()

		if away_taker != null:
			var away_success := await _take_shootout_kick(away_taker, home_gk_overall, home_team)
			if away_success:
				away_score += 1
			_emit(MatchEvent.Type.PENALTY_SHOOTOUT, 120, {"team": "away", "success": away_success, "score": [home_score, away_score],
				"taker": away_taker.player_name, "is_user": away_taker == user_player or _user_is_keeper_of(home_team), "home": false, "n": round_index * 2 + 1})
			await _drain_ack()

		round_index += 1

		# Ronda inicial de 5: si tras 5 rondas hay diferencia matemáticamente
		# irremontable o llegamos a la 5ta, evaluamos; luego, muerte súbita
		# ronda a ronda (1 vs 1) hasta que alguien falle y el otro anote.
		if round_index >= 5:
			if home_score != away_score:
				break
			if round_index >= 5 and home_taker == null and away_taker == null:
				break # sin más pateadores disponibles, corte de seguridad

	var winner := "home" if home_score > away_score else "away"
	_shootout_score = [home_score, away_score]
	_emit(MatchEvent.Type.PENALTY_SHOOTOUT, 120, {"phase": "end", "winner": winner, "score": [home_score, away_score]})
	return winner

## ¿El usuario es el arquero en cancha de `team`?
func _user_is_keeper_of(team: MatchTeam) -> bool:
	return user_player != null and user_player.position == "GK" and _user_team_is(team) \
		and _user_is_on_pitch and not _user_injured and not _user_red_carded

## Penal en contra con el usuario en el arco: decisión "penalty_save"
## (elegir el lado + reflejo). Devuelve true si lo atajó.
func _user_saves_penalty(taker_composure: int, minute: int, kind: String) -> bool:
	var situation := {"minute": minute, "kind": kind, "player": user_player,
		"difficulty": DecisionResolver.penalty_save_difficulty(taker_composure, user_player)}
	_emit(MatchEvent.Type.DECISION_REQUEST, minute, situation)
	decision_requested.emit(situation)
	var ui_result: Dictionary = await _await_decision_result()
	var precision: float = clamp(ui_result.get("precision", 0.5), 0.0, 1.0)
	var saved: bool = DecisionResolver.resolve_penalty_save(user_player, taker_composure, precision)
	var rating_before: float = _ratings.get(user_player, RATING_BASE)
	_bump_user_rating(1.3 if saved else -0.2)
	_emit(MatchEvent.Type.DECISION_RESULT, minute, {
		"kind": kind, "success": saved,
		"rating_delta": _ratings.get(user_player, RATING_BASE) - rating_before,
		"goal": not saved,
	})
	return saved

func _take_shootout_kick(taker: PlayerData, gk_overall: int, keeper_team: MatchTeam = null) -> bool:
	if keeper_team != null and taker != user_player and _user_is_keeper_of(keeper_team):
		return not await _user_saves_penalty(taker.composure, 120, "penalty_save_shootout")
	if taker == user_player and not _user_injured and not _user_red_carded:
		var situation := {"minute": 120, "kind": "penalty_shootout", "player": user_player}
		_emit(MatchEvent.Type.DECISION_REQUEST, 120, situation)
		decision_requested.emit(situation)
		var ui_result: Dictionary = await _await_decision_result()
		var precision: float = clamp(ui_result.get("precision", 0.5), 0.0, 1.0)
		var outcome := DecisionResolver.resolve_penalty(taker, gk_overall, precision, _match_attr_bonus)
		return outcome["success"]
	else:
		return DecisionResolver.resolve_shootout_kick(taker.composure, gk_overall, taker.shooting)

func _order_takers(team: MatchTeam) -> Array[PlayerData]:
	# Mejores rematadores primero (composure + shooting), como en FL.
	# Un jugador expulsado no puede patear la tanda (bug real de la
	# auditoría: seguía en starting_xi y podía salir sorteado, incluso
	# el usuario si él fue el expulsado).
	var candidates: Array[PlayerData] = team.starting_xi.filter(func(p): return p.position != "GK" and not (p in _sent_off))
	candidates.sort_custom(func(a, b): return (a.shooting + a.composure) > (b.shooting + b.composure))
	return candidates

# --- Helpers ---

func _user_team_is(team: MatchTeam) -> bool:
	return team.starting_xi.has(user_player) or team.bench.has(user_player)

func _find_goalkeeper(team: MatchTeam) -> PlayerData:
	for p in team.starting_xi:
		if p.position == "GK" and not (p in _sent_off):
			return p
	return null

func _pick_random_field_player(team: MatchTeam) -> PlayerData:
	var field_players: Array[PlayerData] = team.starting_xi.filter(func(p): return p.position != "GK" and not (p in _sent_off))
	if field_players.is_empty():
		return null
	return field_players[randi() % field_players.size()]

func _pick_random_pitch_player() -> PlayerData:
	var pool: Array[PlayerData] = []
	for pl in home_team.starting_xi:
		if not (pl in _sent_off) and not (pl == user_player and _user_red_carded):
			pool.append(pl)
	for pl in away_team.starting_xi:
		if not (pl in _sent_off) and not (pl == user_player and _user_red_carded):
			pool.append(pl)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]

## Gancho de pruebas: congela el avance del partido (las pruebas que fuerzan
## una jugada no quieren que justo caiga un gol o el entretiempo encima).
var hold: bool = false
func _wait_for_pace() -> void:
	if instant_mode:
		return
	while hold:
		await Engine.get_main_loop().process_frame
	# Ritmo ajustable en Ajustes (lento / normal / rápido).
	await Engine.get_main_loop().create_timer(EVENT_DELAY_SECONDS * Preferences.match_pace_factor()).timeout

func _emit(type: MatchEvent.Type, minute: int, payload: Dictionary = {}) -> void:
	if not instant_mode:
		match type:
			MatchEvent.Type.CARD_YELLOW, MatchEvent.Type.CARD_RED, \
			MatchEvent.Type.INJURY, MatchEvent.Type.DECISION_RESULT:
				_pending_ack = true
			MatchEvent.Type.AMBIENT:
				# Una ocasión clara detiene el partido mientras se ve.
				if String(payload.get("kind", "")) == "clear_chance":
					_pending_ack = true
			MatchEvent.Type.SUBSTITUTION:
				# Solo los cambios que te involucran a VOS pausan y muestran
				# carta; los cambios de la IA (que pueden venir de a 3-4
				# seguidos) van solo al registro, sin frenar el partido
				# (reporte de Wilber: "se acumula el mensaje / se superponen").
				if bool(payload.get("is_user", false)):
					_pending_ack = true
			MatchEvent.Type.PENALTY_SHOOTOUT:
				# Cada penal de la tanda que NO patea el usuario se ve en la
				# cancha: el motor espera a que termine (el del usuario ya
				# tiene su propia repetición de decisión).
				if payload.has("team") and not bool(payload.get("is_user", false)):
					_pending_ack = true
			MatchEvent.Type.GOAL:
				# CUALQUIER gol pausa el partido: el propio/asistencia con la
				# animación de celebración, el rival/compañero con el popup
				# central. La pantalla avisa cuando terminó
				# (notify_celebration_done / _ack_event -> notify_event_ack).
				_pending_ack = true
	event_emitted.emit(MatchEvent.new(type, minute, payload))


## Jugada EN VIVO (match_live): aplica el resultado real de la cancha con
## los mismos registros que los minijuegos (goles, asistencias, nota).
func _apply_live_outcome(kind: String, minute: int, outcome: String, user_home: bool, opposing_team: MatchTeam) -> void:
	var own_team: MatchTeam = home_team if user_home else away_team
	match outcome:
		"goal":
			_rating_calc.register_goal()
			_bump_user_rating(1.4)
			_register_goal_for(user_home, minute, true)
		"assist_goal":
			var finisher := _pick_weighted_scorer(own_team)
			_rating_calc.register_key_pass_success()
			_bump_user_rating(1.0)
			_register_goal_for(user_home, minute, false, finisher, true)
			_user_assists += 1
		"team_goal":
			_bump_user_rating(0.2)
			_register_goal_for(user_home, minute, false, _pick_weighted_scorer(own_team))
		"conceded":
			var scorer := _pick_weighted_scorer(opposing_team)
			_rating_calc.register_decision_failed(kind)
			_bump_user_rating(-0.35)
			_register_goal_for(not user_home, minute, false, scorer)
			if scorer != null:
				_ratings[scorer] = _ratings.get(scorer, RATING_BASE) + 1.3
		"won", "claimed", "gk_save", "block", "cleared":
			_rating_calc.register_tackle_success()
			_bump_user_rating(0.5)
		"chance", "pass_ok":
			_rating_calc.register_key_pass_success()
			_bump_user_rating(0.4)
		"kept", "held", "opp_saved", "opp_miss", "team_won":
			_bump_user_rating(0.1)
		_:
			_rating_calc.register_decision_failed(kind)
			_bump_user_rating(-0.15)
