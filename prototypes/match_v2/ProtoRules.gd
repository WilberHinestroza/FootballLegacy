extends RefCounted
## Prototipo match_v2 — TODA la matemática de éxito/fallo del prototipo en
## un solo lugar (mismo criterio que DecisionResolver en el juego real).
## Cuando el prototipo se integre, esto se muda a DecisionResolver; nunca
## duplicar una de estas fórmulas en ProtoSim ni en la escena.
##
## Atributos en escala 1-99. Distancias en metros, velocidades en m/s.

# --- Velocidades -----------------------------------------------------------
static func run_speed(pace: int) -> float:
	return 5.0 + float(pace) * 0.035          # pace 70 -> 7.45 m/s

static func pass_speed(distance: float) -> float:
	return clampf(11.0 + distance * 0.45, 12.0, 24.0)

## El pase rasante se frena (m/s²) hasta un mínimo (m/s) — lo aplica
## ProtoSim._update_flight y lo usa el cálculo del pase adelantado.
const PASS_DECEL := 2.2
const PASS_MIN_SPEED := 6.0

## Cuánto tarda (s) un pase en recorrer `distance` metros, con el frenado.
static func pass_travel_time(distance: float) -> float:
	var v0: float = pass_speed(distance)
	var d_brake: float = (v0 * v0 - PASS_MIN_SPEED * PASS_MIN_SPEED) / (2.0 * PASS_DECEL)
	if distance <= d_brake:
		return (v0 - sqrt(maxf(v0 * v0 - 2.0 * PASS_DECEL * distance, 0.0))) / PASS_DECEL
	return (v0 - PASS_MIN_SPEED) / PASS_DECEL + (distance - d_brake) / PASS_MIN_SPEED

## PASE ADELANTADO: cuánto se confía en que el receptor siga a la misma
## velocidad (1 = del todo). Los que acomodan su posición frenan, así que
## a ellos se les adelanta un poco menos; al que pica al espacio, todo.
const PASS_LEAD_TRUST := 0.85
const PASS_LEAD_TRUST_RUNNER := 1.0
const PASS_LEAD_MAX_SECS := 3.0

static func shot_speed(power: float, shooting: int) -> float:
	return 17.0 + power * 13.0 + float(shooting) * 0.03

# --- Pase ------------------------------------------------------------------
## Desvío angular (radianes, sigma) de un pase. `pressure` 0..1 = qué tan
## encima tenía al rival más cercano.
static func pass_angle_sigma(passing: int, pressure: float) -> float:
	return (100.0 - float(passing)) * 0.0022 + pressure * 0.05

## Chance de que un rival que toca la trayectoria del balón lo corte.
static func intercept_chance(defending: int, ball_speed: float, lofted: bool) -> float:
	if lofted:
		return 0.0
	var c: float = 0.30 + float(defending) * 0.006 - (ball_speed - 12.0) * 0.025
	return clampf(c, 0.12, 0.85)

## Del total de pases cortados, cuántos quedan en rebote (no controlados).
const INTERCEPT_DEFLECT := 0.45

## Bloqueo de un remate por un jugador de campo que está en la línea.
static func block_chance(defending: int) -> float:
	return clampf(0.15 + float(defending) * 0.004, 0.15, 0.50)

# --- Duelo -----------------------------------------------------------------
## Entrada: del gesto al contacto (s); de las ganadas, cuántas se queda el
## que entra (el resto, pelota suelta).
const TACKLE_WINDUP := 0.16
const TACKLE_KEEP := 0.45
## Falta en una entrada de la IA (mucho más si es de atrás).
static func tackle_foul(defending: int, from_behind: bool) -> float:
	var base: float = 0.08 if from_behind else 0.025
	return clampf(base - float(defending - 60) * 0.002, 0.02, 0.35)
## Arquero que se tira a los pies del atacante.
static func gk_smother(keeping: int, dribbling: int) -> float:
	return clampf(0.5 + float(keeping - dribbling) * 0.01, 0.2, 0.8)
## De los centros que el arquero alcanza, cuántos despeja de puños.
const GK_PUNCH_CROSS := 0.35
## Penal: chance de que el arquero se quede en el medio / de que lo lea.
const PEN_GK_STAY := 0.2
static func pen_gk_reads(keeping: int) -> float:
	return clampf(0.1 + float(keeping - 60) * 0.006, 0.05, 0.3)
## Offside: tolerancia (m) — la "línea" del juez.
const OFFSIDE_MARGIN := 0.4
## Barrera: separación entre jugadores (m).
const WALL_SPACING := 1.4
## De los pases a un compañero en offside, cuántos se dan igual (el pasador
## no lo vio) — sin esto el fuera de juego no existía.
const OFFSIDE_MISREAD := 0.25
## Duración máxima de una jugada del modo por jugadas (s de simulación).
const PLAY_MAX_SECS := 24.0 # video 2 de Wilber: jugadas de casi un minuto en el medio
## Partido por jugadas: chance, entre una jugada y la siguiente, de un gol
## "fuera de cámara" del rival / de tu equipo (jugadas en las que no estás).
const BG_GOAL_RIVAL := 0.05 # 17-oct: Wilber perdía partidos por goles que no vio
const BG_GOAL_OWN := 0.06
## IA: cuánto prefiere el pase en profundidad a un compañero que pica.
const THROUGH_BALL_BONUS := 0.35
static func tackle_success(defending: int, dribbling: int) -> float:
	return clampf(0.38 + float(defending - dribbling) * 0.012, 0.12, 0.75)

## Gambeta contra el rival más cercano (`dist` metros: encarar de muy cerca
## es más difícil; con un poco de espacio, más fácil).
static func skill_success(dribbling: int, defending: int, dist: float) -> float:
	return clampf(0.45 + float(dribbling - defending) * 0.012 + (dist - 1.5) * 0.05, 0.15, 0.85)

## Planchazo: chance de sacarla limpia; de hacer falta (mucho más si es
## por detrás); y de que esa falta sea tarjeta.
static func slide_clean(defending: int, dribbling: int) -> float:
	return clampf(0.45 + float(defending - dribbling) * 0.010, 0.15, 0.72)

static func slide_foul(from_behind: bool) -> float:
	return 0.45 if from_behind else 0.20

# --- Planchazo estilo WSC (17-oct, Wilber: "traer los planchazos") -----------
const SLIDE_SECS := 0.55            # cuánto dura el deslizamiento (antes 0,45)
const SLIDE_SPEED := 11.0           # m/s al tirarse (≈ 4,5 m de barrida)
const SLIDE_AIM_DEG := 40.0         # trazo dentro de esto del rival = barrida a la pelota
const SLIDE_BALL_FIRST_BONUS := 0.22 # tocó la pelota antes que al rival
const SLIDE_VS_USER_MALUS := 0.12   # la IA te la saca un poco menos
const AI_SLIDE_CHANCE := 0.008      # por paso (60/s) persiguiendo a uno que se va

# --- Desmarque al espacio (Score! Hero) ------------------------------------
const RUNNER_DELAY := 0.25          # (s de juego) con la pelota antes de que pique
const RUNNER_SECS := 2.6            # dura la corrida

# --- Arquero ---------------------------------------------------------------
const GK_DOWN_SECS := 0.8          # tendido después de tirarse
const GK_HOLD_SECS := 1.6         # mínimo con la pelota en las manos antes de sacarla
const GK_WALK_OUT_Y := 96.5       # (y normalizada; su arco en 105) hasta dónde camina
const GK_WALK_MULT := 0.5         # camina, no corre
const GK_LET_GO_WIDE := 1.5         # (m afuera del palo) desde acá deja ir el remate

static func yellow_chance(from_behind: bool) -> float:
	return 0.60 if from_behind else 0.30

static func red_direct_chance(from_behind: bool) -> float:
	return 0.10 if from_behind else 0.02

# --- Remate ----------------------------------------------------------------
## Error lateral (metros, sigma) en la línea de gol.
static func shot_error_sigma(shooting: int, distance: float, pressure: float, power: float, curve: float) -> float:
	var s: float = 0.35 + (100.0 - float(shooting)) * 0.022
	s *= 0.55 + distance / 22.0
	s += pressure * 0.6 + maxf(power - 0.75, 0.0) * 2.5 + absf(curve) * 0.4
	return s

## ALTURA del remate en la línea de gol (metros; el travesaño está a
## ProtoSim.GOAL_H = 2,6). Más fuerte = más arriba: suave va rasante, fuerte
## busca el ángulo, y a fondo se va por arriba.
static func shot_height_for_power(power: float) -> float:
	return 0.15 + pow(clampf((power - 0.2) / 0.8, 0.0, 1.0), 1.4) * 3.0

## Error de altura (metros, sigma).
static func shot_height_sigma(shooting: int, distance: float, pressure: float, power: float) -> float:
	return 0.15 + (100.0 - float(shooting)) * 0.005 + distance * 0.01 + pressure * 0.25 + maxf(power - 0.8, 0.0) * 1.0

## Pelota que toca el palo/travesaño: `inside` -1..1 = qué tan adentro del
## palo pegó (1 = la cara de adentro → casi seguro gol; -1 = la de afuera).
static func post_in_chance(inside: float) -> float:
	return clampf(0.5 + inside * 0.45, 0.05, 0.95)

## Preparación de las patadas (s): del inicio del gesto al contacto con la
## pelota (coincide con el cuadro en que el pie le pega, ver ProtoMatch).
const KICK_WINDUP := 0.18
const SHOT_WINDUP := 0.2
const GK_KICK_WINDUP := 0.32
const GK_THROW_WINDUP := 0.25

static func gk_dive_speed(keeping: int) -> float:
	# 17-oct: con el arco agrandado (ProtoSim.GOAL_HALF 5,5) el arquero llega
	# proporcionalmente más lejos y más rápido, si no casi todo era gol.
	return 4.0 + float(keeping) * 0.05

static func gk_reach(keeping: int) -> float:
	return 1.25 + float(keeping) * 0.012

## Segundos que tarda el arquero en arrancar hacia el remate: depende de sus
## reflejos (keeping 70 ≈ 0,22 s, el valor fijo de antes). La velocidad del
## balón no entra acá: un remate más rápido llega antes y le deja menos
## tiempo para estirarse (eso ya sale de la física del vuelo).
static func gk_reaction(keeping: int) -> float:
	return clampf(0.30 - float(keeping - 30) * 0.002, 0.15, 0.32)

## Hasta qué altura llega el arquero estirándose (m).
static func gk_reach_high(keeping: int) -> float:
	return 2.25 + float(keeping) * 0.005

## De lo que ataja, cuánto RETIENE (el resto lo rechaza): fácil si le llega
## al cuerpo, a media altura y despacio.
static func catch_chance(keeping: int, ball_speed: float, edge: float, height: float) -> float:
	var c: float = 0.8 - edge * 0.65 - (ball_speed - 18.0) * 0.02 + float(keeping - 60) * 0.008 - maxf(height - 1.8, 0.0) * 0.3
	return clampf(c, 0.05, 0.9)

## Si el balón pasa dentro del alcance del arquero, ¿la ataja?
## `edge` 0..1 = qué tan al límite de su alcance pasó (1 = en la punta de
## los dedos). `curve` resta: la rosca engaña.
static func save_chance(keeping: int, ball_speed: float, edge: float, curve: float) -> float:
	var c: float = 0.55 + float(keeping) * 0.005 - edge * 0.45 - (ball_speed - 20.0) * 0.012 - absf(curve) * 0.12
	return clampf(c, 0.10, 0.95)

# --- Juego aéreo -------------------------------------------------------------
const HEADER_ON_CROSS := 0.75    # el atacante que llega al centro cabecea (si no, la baja)
const HEADER_ERROR_MULT := 1.7   # un cabezazo se desvía bastante más que un remate
const HEADER_SPEED_MULT := 0.65
## Atacante contra defensor en un centro (pace ~ timing del salto).
static func aerial_attacker_wins(att_pace: int, def_defending: int) -> float:
	return clampf(0.45 + float(att_pace - def_defending) * 0.008, 0.25, 0.65)

const BICYCLE_CHANCE := 0.08    # de los remates de cabeza, cuántos salen de chilena

## Aceleración de los jugadores (m/s²): sin "urgencia" (acomodarse) y con
## urgencia (ir a la pelota, presionar). Frenar/dar la vuelta es BRAKE_MULT
## veces más rápido que arrancar.
const ACCEL := 15.0
const ACCEL_URGENT := 26.0
const BRAKE_MULT := 1.6

# --- Ayudas y justicia (17-oct, Wilber: "que toda persona lo pueda jugar sin
# sentirse frustrado"). La dificultad la dan los stats; esto es igual para
# todos. -----------------------------------------------------------------------
const SHOT_ASSIST := 0.55        # cuánto corrige un remate que apunta cerca del palo
const SHOT_ASSIST_RANGE := 2.5   # (m) fuera del palo donde todavía ayuda
const PASS_MAGNET_DEG := 17.0    # trazo a menos de esto de un compañero = pase a él
const RECEIVE_PROTECT_USER := 0.8 # (s) nadie te entra apenas la recibís
const ADVANTAGE_CHANCE := 0.45   # falta al que sigue con la pelota: se juega la ventaja
## ROSCA QUE SIGUE AL DEDO (17-oct, video de WSC: la línea punteada copia
## la curva del trazo y la pelota va por ahí). Desvío del punto de control
## por unidad de rosca (antes 0,25 remate / 0,3 pase: curvaba menos que el trazo).
const CURVE_BEND := 0.45
const DOUBLE_TAP_MS := 260        # dos toques al mismo compañero = pase alto
const SOFT_SWIPE_MS := 380       # trazo más lento que esto = vaselina / pase elevado
const REPLAY_SPEED := 0.55       # repetición del gol (fracción de la velocidad real)
const HINT_SHOWS := 3            # cada ayuda contextual se muestra las primeras N veces
## Pase fuerte que se le escapa a un jugador de la IA (primer toque).
static func heavy_touch(ball_speed: float, dribbling: int) -> float:
	return clampf((ball_speed - 16.0) * 0.012 + float(60 - dribbling) * 0.003, 0.0, 0.12)
## Velocidad con la pelota (fracción de la carrera libre): la IA / vos
## corriendo a un punto tocado. Y desde qué velocidad (m/s) el que lleva la
## pelota usa la animación de correr en vez de la de conducir.
const CARRY_SPEED := 0.82
const CARRY_SPEED_USER := 0.93
const CARRY_RUN_ANIM_SPEED := 4.2

const LONG_BALL_ERROR_MULT := 1.4 # pelotazos (>26 m) mucho menos precisos

# --- IA: cuánto prefiere pasársela al usuario --------------------------------
## El foco del juego es TU carrera: los compañeros te buscan un poco más
## que a un compañero cualquiera, y bastante más si se la pediste.
const USER_PASS_BIAS := 0.22
const USER_CALL_BONUS := 0.55
const CALL_LOB_LANE := 1.6        # al pedirla con un rival en la línea: va por arriba
const PLAY_START_USER := 0.7      # jugadas abiertas que arrancan en tus pies
const PLAY_LOST_SECS_NEAR := 3.0  # perdida cerca tuyo: tiempo para recuperarla
const SLIDE_REACH := 4.2          # más lejos que esto: corre y se tira al llegar
const CONTROL_MAX_SPEED := 3.5      # recibe más lento que esto: se ve el control al pie
const NET_DEPTH := 2.2              # fondo de la red (m detrás de la línea)
const DEAD_BALL_SECS := 0.9         # remate afuera: la pelota sigue antes del saque
const SHOT_DRAG := 0.22             # frenado del remate por el aire (1/s)
const USER_PASS_INTERCEPT_MULT := 0.6 # a tus pases les cuesta más cortarlos
const USER_RUN_BURST := 0.35          # (s) arranque explosivo al tocar un destino con la pelota
const USER_CARRY_ACCEL_MULT := 1.8    # aceleración de tu jugador con la pelota
const SEP_DIST := 1.6                 # compañeros más cerca que esto se separan
const SEP_PUSH := 3.0
const CARRY_TOUCH_M := 2.2        # metros entre toque y toque al conducir corriendo
const CARRY_TOUCH_AHEAD := 0.8    # cuánto se adelanta la pelota en cada toque
const BALL_IDLE_AHEAD := 0.8      # quieto con la pelota: tan adelante del pie (m)
const BALL_SIDE := 0.35           # hacia el pie derecho (m)
