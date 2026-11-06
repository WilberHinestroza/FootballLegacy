extends RefCounted
## Prototipo match_v2 — simulación 2D de los 22 jugadores (estilo World
## Soccer Champs) donde el usuario controla SOLO a su futbolista.
##
## Igual que MatchEngine: no sabe NADA de UI. La escena lee `agents`,
## `ball_pos`, `ball_height()` y dibuja; le manda las órdenes del usuario
## con los métodos user_*; y decide el ritmo con `desired_time_scale()`
## (cámara lenta cuando tenés el balón, acelerado cuando estás lejos).
## Toda la matemática de éxito/fallo vive en ProtoRules.
##
## Coordenadas: metros. x en [0, 68] (ancho), y en [0, 105] (largo).
## Equipo 0 = el del usuario, ataca hacia y = 0 (arriba en pantalla).
## Equipo 1 = rival, ataca hacia y = 105.
## "Normalizado" (_n) = vista de un equipo como si fuera el 0: siempre
## ataca hacia y = 0 y defiende y = 105. Es una involución (_n(_n(p)) = p).

const Rules = preload("res://prototypes/match_v2/ProtoRules.gd")

signal sim_event(kind: String, data: Dictionary)

const PITCH_W := 68.0
const PITCH_L := 105.0
## Arco AGRANDADO (17-oct, Wilber: "haz los arcos más anchos"): con los
## jugadores grandes el arco real (7,32 m) se veía de juguete — como en el
## juego (PitchView.GOAL_W). Lo usan la puntería, las atajadas y el dibujo.
const GOAL_HALF := 7.0 # 17-oct (tarde): "los arcos un poco más grandes" (era 6,3; antes 5,5)
## FÍSICA DEL ARCO (17-oct, Wilber: "goles en los ángulos, que peguen en el
## palo y entren o salgan"): el remate llega a la línea a una ALTURA; el
## travesaño está a GOAL_H y los palos y la pelota tienen grosor.
const GOAL_H := 2.8 # 17-oct (tarde): más alto (era 2,6)
const POST_R := 0.17 # 17-oct: palos más gruesos (antes 0,12)
const BALL_HIT_R := 0.2
const GRAVITY := 9.8
const HALF_SIM_SECONDS := 150.0 # 2 tiempos de 2:30 "reales" a ritmo normal

## Ritmo (lo aplica la escena, suavizado).
const SCALE_BULLET := 0.07  # tenés el balón y estás pensando
const SCALE_DRIBBLE := 1.0  # tenés el balón y estás conduciendo
const SCALE_RECEIVE := 0.35 # el pase viene hacia vos
const SCALE_FAST := 2.6     # la jugada está lejos de vos
const FAST_DISTANCE := 32.0

## FORMACIONES: las mismas del juego real (Formations.SLOTS, mismo orden de
## puestos) para que al integrar el DT de la carrera mande en la cancha.
## Posición base de cada puesto, normalizada (ataca hacia y = 0, su arco en
## y = 105). El índice 0 es siempre el arquero (ver _goalkeeper).
const GK_BASE := Vector2(34, 102)
const FORMATION_BASES := {
	"4-4-2": [Vector2(8, 85), Vector2(25, 89), Vector2(43, 89), Vector2(60, 85),
		Vector2(9, 70), Vector2(26, 73), Vector2(42, 73), Vector2(59, 70),
		Vector2(28, 58), Vector2(40, 58)],
	"4-3-3": [Vector2(8, 85), Vector2(25, 89), Vector2(43, 89), Vector2(60, 85),
		Vector2(34, 79), Vector2(23, 71), Vector2(45, 71),
		Vector2(10, 60), Vector2(34, 57), Vector2(58, 60)],
	"4-2-3-1": [Vector2(8, 85), Vector2(25, 89), Vector2(43, 89), Vector2(60, 85),
		Vector2(27, 78), Vector2(41, 78),
		Vector2(10, 65), Vector2(34, 66), Vector2(58, 65), Vector2(34, 57)],
	"3-5-2": [Vector2(20, 88), Vector2(34, 90), Vector2(48, 88),
		Vector2(60, 71), Vector2(34, 79), Vector2(24, 72), Vector2(44, 72), Vector2(8, 71),
		Vector2(28, 58), Vector2(40, 58)],
	"5-3-2": [Vector2(6, 82), Vector2(21, 89), Vector2(34, 90), Vector2(47, 89), Vector2(62, 82),
		Vector2(34, 78), Vector2(23, 72), Vector2(45, 72),
		Vector2(28, 58), Vector2(40, 58)],
	"4-5-1": [Vector2(8, 85), Vector2(25, 89), Vector2(43, 89), Vector2(60, 85),
		Vector2(9, 68), Vector2(24, 73), Vector2(34, 78), Vector2(44, 73), Vector2(59, 68),
		Vector2(34, 59)],
}
## Puesto detallado → línea del prototipo (la misma cuenta que Formations:
## extremos y volantes son MF; solo DC/SD son ST).
const SLOT_ROLE := {
	"LI": "DF", "LD": "DF", "DFC": "DF", "CAI": "DF", "CAD": "DF",
	"MCD": "MF", "MC": "MF", "MI": "MF", "MD": "MF", "EI": "MF", "ED": "MF", "MCO": "MF",
	"DC": "ST", "SD": "ST",
}
var formations := ["4-4-2", "4-4-2"]
const ROLE_SHIFT := {"DF": 0.42, "MF": 0.55, "ST": 0.50}
const ROLE_PUSH := {"DF": 7.0, "MF": 11.0, "ST": 17.0}
const ROLE_YMIN := {"DF": 40.0, "MF": 22.0, "ST": 9.0}
const ROLE_YMAX := {"DF": 99.0, "MF": 92.0, "ST": 78.0}

class Agent:
	var idx: int
	var team: int
	var role: String
	var number: int
	var base: Vector2 # normalizado
	var pos: Vector2
	var vel: Vector2
	var target: Vector2
	var urgent: bool = false
	var pace: int = 65
	var passing: int = 65
	var shooting: int = 60
	var dribbling: int = 62
	var defending: int = 60
	var keeping: int = 30
	var is_user: bool = false
	var stun: float = 0.0
	var tackle_cd: float = 0.0
	var decide_cd: float = 0.0
	var carry_target: Vector2
	var dive_x: float = -1.0
	var dive_delay: float = 0.0
	## Último gesto (semántico, no de UI): "pase", "remate", "barrida",
	## "atajada", "estirada". La escena decide cómo animarlo.
	var action: String = ""
	var action_t: float = -9.0
	var action_dir := Vector2.ZERO
	var burst_t: float = 0.0    # arranque tras una gambeta
	var slide_t: float = 0.0    # deslizándose en un planchazo
	var slide_dir := Vector2.ZERO
	var slide_done: bool = false
	var yellows: int = 0
	var lofted_recv_t: float = -9.0 # cuándo bajó un balón aéreo (para la volea)
	var tackle_at: float = -1.0 # entrada lanzada: cuándo llega el pie (TACKLE_WINDUP)
	var tackle_vs: int = -1
	var run_cd: float = -1.0
	var run_until: float = -1.0 # desmarque al espacio (en ataque) hasta este momento
	var mark_idx: int = -1      # a quién marca (en defensa, cerca del área)

var rng := RandomNumberGenerator.new()
var agents: Array[Agent] = []
var user_idx: int = -1
var user_auto: bool = false # probe headless: el usuario juega como IA

var ball_pos := Vector2(34, 52.5)
var owner: int = -1
var owner_since: float = 0.0
var last_touch_team: int = 0
var loose_vel := Vector2.ZERO
var flight: Dictionary = {}
var last_kicker: int = -1
var last_kick_t: float = -9.0
var gk_hold: float = 0.0
## Altura de la pelota SUELTA (rebotes de palo, despejes del arquero,
## bloqueos): sube, cae por gravedad y pica. En vuelo la da `flight`.
var ball_z: float = 0.0
var ball_vz: float = 0.0
## Patada en preparación: el gesto (pase/remate) arranca YA y la pelota sale
## recién cuando el pie llega (KICK_WINDUP). Antes salía en el cuadro 0 y el
## pie "pateaba el aire" medio segundo después.
var windup: Dictionary = {}
var _keep_act: bool = false
## Remate/pase DE PRIMERA del usuario: deslizaste mientras venía el balón.
var user_first: Dictionary = {}

var t: float = 0.0          # tiempo de simulación total
var clock_t: float = 0.0    # dentro del tiempo actual
var half: int = 1
var score := [0, 0]
var finished: bool = false
var restart_timer: float = 0.0
var pending_kickoff_team: int = -1

## Fases: "play" (balón en juego), "set_piece" (saque de banda / córner /
## saque de arco / tiro libre: el ejecutor va hasta la pelota y saca),
## "goal" (festejo). Ver _start_set_piece / _step_set_piece.
var phase: String = "play"
var carry_phase: float = 0.0 # ritmo de los toques al conducir (solo para la posición del balón)

## Árbitro y jueces de línea: no juegan, pero están en la cancha (siguen la
## jugada, pitan, sacan tarjetas, levantan el banderín en los laterales).
## Solo POSICIÓN y GESTO semántico — la escena decide cómo se ven.
var ref_pos := Vector2(30, 60)
var ref_vel := Vector2.ZERO
var ref_action: String = ""   # "pitazo", "amarilla", "roja"
var ref_action_t: float = -9.0
var lines_y := [26.0, 79.0]   # juez izquierdo (mitad de arriba) / derecho (abajo)
var lines_flag_t := [-9.0, -9.0]
var set_piece: Dictionary = {}
var last_scorer: int = -1

## MODO JUGADAS (ProtoDirector): el partido son momentos sueltos. La escena
## llama setup_play(kind, minute); la sim avisa cuándo terminó (play_over +
## play_result) y la escena arma la siguiente. Sin entretiempo ni saque del
## medio: el reloj lo maneja el director.
var plays_mode: bool = false
var play_kind: String = ""
var play_t0: float = 0.0
var play_over: bool = false
var play_result: String = ""
var play_minute: int = 0
var _play_lost_t: float = 0.0
var _play_won_t: float = 0.0

# Órdenes del usuario
var user_dribble: bool = false
var user_dribble_target := Vector2.ZERO
var user_move_target := Vector2.ZERO
var user_move_t: float = 0.0
var user_press_t: float = 0.0
var user_call_until: float = -1.0
var user_dribble_until: float = -1.0 # la gambeta conduce sola un instante
var user_sent_off: bool = false

var stats := {
	"shots": [0, 0], "on_target": [0, 0], "possession": [0.0, 0.0],
	"passes": [0, 0], "passes_ok": [0, 0],
	"user_receptions": 0, "user_passes": 0, "user_passes_ok": 0,
	"user_shots": 0, "user_goals": 0, "user_assists": 0,
	"user_dribbles_lost": 0, "user_tackles_won": 0, "user_ball_time": 0.0,
	"user_skills": 0, "user_skills_ok": 0, "user_slides": 0, "user_slides_won": 0,
	"user_fouls": 0, "user_yellows": 0,
}
var _last_passer: int = -1
var gk_dive_z: float = 0.5 # altura a la que va el remate que el arquero intenta atajar

func _init(user_role: String = "ST", seed_value: int = 0, home_ovr: int = 70, away_ovr: int = 70,
		home_formation: String = "4-4-2", away_formation: String = "4-4-2") -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	formations = [home_formation if FORMATION_BASES.has(home_formation) else "4-4-2",
		away_formation if FORMATION_BASES.has(away_formation) else "4-4-2"]
	for team in range(2):
		var ovr: int = home_ovr if team == 0 else away_ovr
		var slots: Array = Formations.slots_for(formations[team])
		var bases: Array = FORMATION_BASES[formations[team]]
		for i in range(11):
			var a := Agent.new()
			a.idx = agents.size()
			a.team = team
			a.role = "GK" if i == 0 else String(SLOT_ROLE.get(slots[i - 1], "MF"))
			a.base = GK_BASE if i == 0 else bases[i - 1]
			a.number = i + 1
			_roll_attributes(a, ovr)
			agents.append(a)
	# El usuario: el último del equipo 0 con ese rol (el ST derecho, el MF...)
	for a in agents:
		if a.team == 0 and a.role == user_role:
			user_idx = a.idx
	var u: Agent = agents[user_idx]
	u.is_user = true
	_reset_positions()
	_kickoff(0)

func _roll_attributes(a: Agent, ovr: int) -> void:
	var v := func(bias: int) -> int: return clampi(ovr + bias + rng.randi_range(-6, 6), 30, 95)
	match a.role:
		"GK":
			a.keeping = v.call(2); a.pace = v.call(-15); a.passing = v.call(-12)
			a.shooting = 20; a.dribbling = 25; a.defending = 30
		"DF":
			a.defending = v.call(4); a.pace = v.call(-2); a.passing = v.call(-6)
			a.shooting = v.call(-22); a.dribbling = v.call(-12)
		"MF":
			a.passing = v.call(4); a.dribbling = v.call(0); a.defending = v.call(-8)
			a.shooting = v.call(-8); a.pace = v.call(-2)
		"ST":
			a.shooting = v.call(4); a.dribbling = v.call(0); a.pace = v.call(2)
			a.passing = v.call(-8); a.defending = v.call(-30)

# ---------------------------------------------------------------- utilidades
static func _n(p: Vector2, team: int) -> Vector2:
	if team == 0:
		return p
	return Vector2(PITCH_W - p.x, PITCH_L - p.y)

static func _goal_y(attacking_team: int) -> float:
	return 0.0 if attacking_team == 0 else PITCH_L

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2: float = ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var u: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * u)

static func _bezier(s: Vector2, c: Vector2, e: Vector2, u: float) -> Vector2:
	var a := s.lerp(c, u)
	var b := c.lerp(e, u)
	return a.lerp(b, u)

func user() -> Agent:
	return agents[user_idx]

func user_has_ball() -> bool:
	return owner == user_idx

func carrier() -> Agent:
	return agents[owner] if owner >= 0 else null

func _poss_team() -> int:
	if owner >= 0:
		return (agents[owner] as Agent).team
	if not flight.is_empty():
		return int(flight["team"])
	return last_touch_team

func _goalkeeper(team: int) -> Agent:
	return agents[team * 11]

func _nearest(team: int, p: Vector2, include_gk: bool = false, exclude: int = -1) -> Agent:
	var best: Agent = null
	var bd: float = INF
	for a in agents:
		if a.team != team or a.idx == exclude:
			continue
		if a.role == "GK" and not include_gk:
			continue
		var d: float = a.pos.distance_to(p)
		if d < bd:
			bd = d
			best = a
	return best

func _pressure(a: Agent) -> float:
	var opp := _nearest(1 - a.team, a.pos, true)
	var d: float = opp.pos.distance_to(a.pos)
	return clampf(1.0 - (d - 1.0) / 4.0, 0.0, 1.0)

func minute() -> int:
	if plays_mode:
		return play_minute
	var m: int = int(clock_t / HALF_SIM_SECONDS * 45.0)
	return mini(m, 45) + (45 if half == 2 else 0)

## Altura visual del balón (metros) — solo para dibujar la sombra/arco.
func ball_height() -> float:
	if flight.is_empty():
		return ball_z
	var u: float = clampf(float(flight["done"]) / float(flight["len"]), 0.0, 1.0)
	if flight["kind"] == "shot":
		return lerpf(float(flight.get("z0", 0.0)), float(flight["z"]), u) + sin(u * PI) * float(flight["h"])
	return sin(u * PI) * float(flight["h"])

# ------------------------------------------------------------------- ritmo
func desired_time_scale() -> float:
	if finished or restart_timer > 0.0 or user_auto:
		return 1.0
	var u := user()
	if not windup.is_empty():
		return 1.0 # el gesto de la patada se ve a velocidad normal
	if owner == user_idx:
		return SCALE_DRIBBLE if user_dribble else SCALE_BULLET
	if not flight.is_empty() and int(flight["receiver"]) == user_idx:
		var rem: float = (flight["e"] as Vector2).distance_to(ball_pos)
		if rem < 10.0:
			return SCALE_RECEIVE
	if u.pos.distance_to(ball_pos) > FAST_DISTANCE and user_move_t <= 0.0 and user_press_t <= 0.0:
		return SCALE_FAST
	return 1.0

# --------------------------------------------------------- órdenes usuario
## `lob` = PASE ALTO (doble toque al compañero, como WSC): por arriba de
## los rivales; si cae en el área es un centro (cabezazo).
func user_pass_to(idx: int, lob: bool = false) -> void:
	if owner != user_idx or idx == user_idx:
		return
	var r: Agent = agents[idx]
	if r.team != 0:
		return
	var u := user()
	if not windup.is_empty():
		return
	var d: float = u.pos.distance_to(r.pos)
	var dest: Vector2 = lead_point(u.pos, r)
	if lob:
		_queue_pass(u, dest, idx, 0.0, -1, {"lofted": true, "h": maxf(2.5, d * 0.16), "cross": dest.y < 20.0})
	else:
		_queue_pass(u, dest, idx)

## Deslizar: si la línea apunta al arco (y estás en campo rival) es remate;
## si no, pase al hueco en esa dirección. `power` 0..1, `curve` -1..1.
func user_kick(dir: Vector2, power: float, curve: float, soft: bool = false) -> String:
	if owner != user_idx or dir.length() < 0.01 or not windup.is_empty():
		return ""
	var u := user()
	dir = dir.normalized()
	var throw_in: bool = phase == "set_piece" and set_piece.get("kind", "") == "throw"
	if throw_in:
		var e0 := u.pos + dir * (7.0 + power * 17.0)
		var r0 := _nearest(0, e0, false, user_idx)
		_kick_pass(u, e0, -1, 0.0, r0.idx if r0 != null else -1)
		return "through"
	var x_at: float = _goal_x_along(u.pos, dir)
	if x_at > -900.0:
		x_at = assisted_shot_x(x_at)
		if soft:
			# VASELINA (trazo lento): suave y por arriba, cae bajo el travesaño.
			_queue_shot(u, x_at, clampf(power, 0.25, 0.6), curve, GOAL_H - 0.5)
			windup["chip"] = true
			return "chip"
		_queue_shot(u, x_at, power, curve, Rules.shot_height_for_power(power))
		return "shot"
	# IMÁN DE PASE: si el trazo va hacia un compañero, el pase va a él.
	var mate: Agent = magnet_target(u.pos, dir)
	if mate != null:
		var dm: float = u.pos.distance_to(mate.pos)
		_queue_pass(u, lead_point(u.pos, mate), mate.idx, curve, -1, {"lofted": true, "h": dm * 0.15} if soft else {})
		return "pass"
	var dist: float = 7.0 + power * 33.0
	var e := u.pos + dir * dist
	var recv := _nearest(0, e, false, user_idx)
	_queue_pass(u, e, -1, curve, recv.idx if recv != null else -1, {"lofted": true, "h": dist * 0.15} if soft else {})
	return "through"

## ASISTENCIA DE REMATE: un trazo que apunta cerca del palo se corrige un
## poco hacia adentro (lo justo para que apuntar no frustre; el error del
## remate sigue dependiendo de tus stats).
func assisted_shot_x(x_at: float) -> float:
	var off: float = x_at - 34.0
	if absf(off) > GOAL_HALF + Rules.SHOT_ASSIST_RANGE:
		return x_at
	var inside: float = clampf(off, -(GOAL_HALF - 0.8), GOAL_HALF - 0.8)
	return lerpf(x_at, 34.0 + inside, Rules.SHOT_ASSIST)

## PASE ADELANTADO por intercepción: dónde se encuentran la pelota y el
## receptor si este sigue corriendo igual. La pelota sale recién después de
## la preparación de la patada y se frena en el camino (Rules.pass_travel_time),
## así que el tiempo de encuentro se itera: t → punto → distancia → t.
## Antes era `pos + vel · (d / velocidad) · 0,8`, que no contaba el frenado
## y se quedaba corto en los pases largos a uno que pica.
func lead_point(from: Vector2, r: Agent, trust: float = Rules.PASS_LEAD_TRUST, windup_secs: float = Rules.KICK_WINDUP) -> Vector2:
	var v: Vector2 = r.vel * trust
	var t_meet: float = windup_secs + Rules.pass_travel_time(from.distance_to(r.pos))
	var p: Vector2 = r.pos
	for _i in range(4):
		t_meet = minf(t_meet, Rules.PASS_LEAD_MAX_SECS)
		p = r.pos + v * t_meet
		t_meet = windup_secs + Rules.pass_travel_time(from.distance_to(p))
	return _clamp_pitch(p)

## El compañero al que apunta un trazo (dentro de PASS_MAGNET_DEG), o null.
func magnet_target(from: Vector2, dir: Vector2) -> Agent:
	var best: Agent = null
	var ba: float = deg_to_rad(Rules.PASS_MAGNET_DEG)
	for m in agents:
		if m.team != 0 or m.is_user or m.role == "GK":
			continue
		var to: Vector2 = m.pos - from
		var d: float = to.length()
		if d < 4.0 or d > 45.0:
			continue
		var ang: float = absf(dir.angle_to(to))
		if ang < ba:
			ba = ang
			best = m
	return best

## El compañero mejor ubicado para recibir (la estrella que muestra la
## escena): adelante, libre y con la línea de pase limpia.
func best_pass_option() -> int:
	if owner != user_idx:
		return -1
	var u := user()
	var best: int = -1
	var bs: float = -9.0
	for m in agents:
		if m.team != 0 or m.is_user or m.role == "GK" or _is_offside(m, u):
			continue
		var d: float = u.pos.distance_to(m.pos)
		if d < 5.0 or d > 38.0:
			continue
		var open: float = 10.0
		var lane: float = 99.0
		for o in agents:
			if o.team == 0:
				continue
			open = minf(open, o.pos.distance_to(m.pos))
			lane = minf(lane, _seg_dist(o.pos, u.pos, m.pos))
		if lane < 0.9:
			continue
		var sc: float = (u.pos.y - m.pos.y) * 0.04 + open * 0.08 - d * 0.01 + minf(lane, 4.0) * 0.1
		if sc > bs:
			bs = sc
			best = m.idx
	return best

## Dónde cruza la línea de gol rival un trazo desde `from` en `dir` (o
## -999 si no va al arco / estás lejos).
func _goal_x_along(from: Vector2, dir: Vector2) -> float:
	if dir.y >= -0.05 or from.y > 42.0:
		return -999.0
	var k: float = -from.y / dir.y
	var x_at: float = from.x + dir.x * k
	if absf(x_at - 34.0) <= GOAL_HALF + 7.0:
		return x_at
	return -999.0

## AVANZAR TOCANDO (17-oct, Wilber: "que sea tocar a donde quieres ir en vez
## de arrastrar, para que no se confunda con el tiro"): corrés con la pelota
## hasta ese punto y ahí el tiempo vuelve a frenarse.
func user_run_to(p: Vector2) -> void:
	if owner != user_idx or phase != "play" or not windup.is_empty():
		return
	user_dribble = true
	user_dribble_until = -1.0
	user_dribble_target = _clamp_pitch(p)
	user().burst_t = maxf(user().burst_t, Rules.USER_RUN_BURST) # arranca de una (video 2: tardaba)

## Remate o pase DE PRIMERA: el trazo se hace mientras viene la pelota y se
## ejecuta al recibirla (de cabeza si viene alta).
func user_first_time(dir: Vector2, power: float, curve: float) -> void:
	if owner == user_idx or dir.length() < 0.01:
		return
	user_first = {"dir": dir.normalized(), "power": power, "curve": curve, "t": t}

func ball_incoming_to_user() -> bool:
	return not flight.is_empty() and flight["kind"] == "pass" and int(flight["receiver"]) == user_idx

func user_dribble_to(p: Vector2) -> void:
	if owner != user_idx or phase != "play":
		return
	user_dribble = true
	user_dribble_target = _clamp_pitch(p)

func user_dribble_end() -> void:
	if t >= user_dribble_until:
		user_dribble = false

## Gambeta: encarar al rival más cercano en la dirección `dir`. Si sale,
## el defensor queda pasado (tirado un instante) y arrancás con ventaja.
func user_skill(dir: Vector2) -> void:
	if owner != user_idx or dir.length() < 0.01 or phase != "play":
		return
	var u := user()
	dir = dir.normalized()
	var opp := _nearest(1, u.pos)
	var d: float = opp.pos.distance_to(u.pos) if opp != null else 99.0
	_act(u, "regate", dir)
	stats["user_skills"] += 1
	if d <= 4.5:
		if rng.randf() < Rules.skill_success(u.dribbling, opp.defending, d):
			stats["user_skills_ok"] += 1
			opp.stun = 1.2
			opp.tackle_cd = 1.5
			_act(opp, "caida", u.pos - opp.pos)
			sim_event.emit("skill_ok", {})
		else:
			u.stun = 0.5
			_give_ball(opp)
			sim_event.emit("skill_fail", {})
			return
	u.burst_t = 0.7
	owner_since = t
	user_dribble = true
	user_dribble_until = t + 0.7
	user_dribble_target = _clamp_pitch(u.pos + dir * 7.0)

## Planchazo: te tirás deslizando en `dir`. Si llegás al rival con balón:
## limpio (la sacás), falta (tiro libre y quizá tarjeta) o lo errás. Después
## quedás un momento en el piso.
func user_slide(dir: Vector2) -> void:
	var u := user()
	if owner == user_idx or u.stun > 0.0 or u.slide_t > 0.0 or dir.length() < 0.01:
		return
	dir = dir.normalized()
	# PUNTERÍA ASISTIDA (como WSC): si el trazo va más o menos hacia el rival
	# con la pelota, te tirás a donde VA a estar la pelota, no a donde está.
	if owner >= 0 and (agents[owner] as Agent).team != u.team:
		var c: Agent = agents[owner]
		var dc: float = u.pos.distance_to(c.pos)
		var lead: float = clampf(dc / Rules.SLIDE_SPEED, 0.0, 0.5)
		var aim: Vector2 = ball_pos + c.vel * lead - u.pos
		if aim.length() > 0.1 and absf(dir.angle_to(aim)) < deg_to_rad(Rules.SLIDE_AIM_DEG):
			dir = aim.normalized()
	if owner >= 0 and (agents[owner] as Agent).team != u.team and u.pos.distance_to((agents[owner] as Agent).pos) > Rules.SLIDE_REACH:
		# Muy lejos para llegar barriendo: corre hacia él y se tira al llegar.
		user_press_t = 3.0
		user_move_t = 0.0
		_slide_pending = true
		return
	_start_slide(u, dir)
	stats["user_slides"] += 1

var _slide_pending: bool = false
func _step_slide_pending() -> void:
	if not _slide_pending:
		return
	var u := user()
	if owner < 0 or (agents[owner] as Agent).team == u.team or user_press_t <= 0.0 or u.stun > 0.0:
		_slide_pending = false
		return
	var c: Agent = agents[owner]
	if u.pos.distance_to(c.pos) <= Rules.SLIDE_REACH:
		_slide_pending = false
		user_slide(c.pos - u.pos)

func _start_slide(a: Agent, dir: Vector2) -> void:
	a.slide_dir = dir.normalized()
	a.slide_t = Rules.SLIDE_SECS
	a.slide_done = false
	a.tackle_cd = 2.0
	_act(a, "barrida", a.slide_dir)

func user_move_to(p: Vector2) -> void:
	user_move_target = _clamp_pitch(p)
	user_move_t = 3.5
	user_press_t = 0.0

func user_press() -> void:
	user_press_t = 4.0
	user_move_t = 0.0

func user_call_for_ball() -> void:
	user_call_until = t + 3.5
	if owner >= 0 and owner != user_idx and (agents[owner] as Agent).team == user().team:
		var c: Agent = agents[owner]
		c.decide_cd = minf(c.decide_cd, 0.15) # te mira enseguida
	sim_event.emit("user_call", {})

# -------------------------------------------------------------------- step
func step(dt: float) -> void:
	if finished:
		return
	if restart_timer > 0.0:
		t += dt # el reloj de los gestos sigue (festejos animados)
		restart_timer -= dt
		if phase == "goal":
			_move_agents(dt)
			_step_ball_in_net(dt)
		if restart_timer <= 0.0 and pending_kickoff_team >= 0:
			if plays_mode:
				pending_kickoff_team = -1
				play_over = true
				return
			phase = "play"
			_reset_positions()
			_kickoff(pending_kickoff_team)
		return
	if plays_mode and play_over:
		return
	t += dt
	clock_t += dt
	_move_officials(dt)
	if plays_mode:
		_check_play_end(dt)
		if play_over:
			return
	if phase == "dead":
		_step_dead(dt)
		return
	if phase == "set_piece":
		for a in agents:
			a.stun = maxf(a.stun - dt, 0.0)
		_step_set_piece(dt)
		_step_windup()
		return
	if not plays_mode and clock_t >= HALF_SIM_SECONDS and flight.is_empty():
		_end_half()
		return
	if user_dribble_until > 0.0 and t >= user_dribble_until:
		user_dribble_until = -1.0
		user_dribble = false
	# Llegaste a donde tocaste: el tiempo vuelve a frenarse para decidir.
	if owner == user_idx and user_dribble and user_dribble_until < 0.0 and user().pos.distance_to(user_dribble_target) < 1.2:
		user_dribble = false
	user_move_t = maxf(user_move_t - dt, 0.0)
	user_press_t = maxf(user_press_t - dt, 0.0)
	var pt := _poss_team()
	if owner >= 0:
		stats["possession"][pt] += dt
		if owner == user_idx:
			stats["user_ball_time"] += dt
	for a in agents:
		a.stun = maxf(a.stun - dt, 0.0)
		a.tackle_cd = maxf(a.tackle_cd - dt, 0.0)
	_update_targets()
	_carrier_logic(dt)
	_move_agents(dt)
	_update_ball(dt)
	_step_windup()
	_tackles()
	_step_slide_pending()
	_slide_contact()

# ----------------------------------------------------------------- objetivos
func _offside_line_n(team: int) -> float:
	var ys: Array = []
	for o in agents:
		if o.team != team:
			ys.append(_n(o.pos, team).y)
	ys.sort()
	var second: float = ys[1] if ys.size() > 1 else 0.0
	return minf(second, _n(ball_pos, team).y)

var _support: Array = []
## El compañero que está picando al espacio (para que la escena dibuje su
## flecha), o -1.
var runner_idx: int = -1
func _update_targets() -> void:
	var poss := _poss_team()
	_support.clear()
	if owner == user_idx:
		var u0 := user()
		var c1: Agent = null
		var c2: Agent = null
		for m in agents:
			if m.team != 0 or m.is_user or m.role == "GK":
				continue
			var dm: float = m.pos.distance_to(u0.pos)
			if c1 == null or dm < c1.pos.distance_to(u0.pos):
				c2 = c1
				c1 = m
			elif c2 == null or dm < c2.pos.distance_to(u0.pos):
				c2 = m
		if c1 != null and c2 != null:
			# el de la izquierda va a la izquierda
			_support = [c1.idx, c2.idx] if c1.pos.x <= c2.pos.x else [c2.idx, c1.idx]
		# PICA AL ESPACIO (como Score! Hero): con la pelota en tus pies, el
		# delantero habilitado más adelantado arranca a la espalda de la
		# defensa — el pase filtrado siempre tiene a quién ir.
		if runner_idx < 0 or t >= (agents[runner_idx] as Agent).run_until:
			runner_idx = -1
			if t - owner_since > Rules.RUNNER_DELAY:
				var bestr: Agent = null
				for m in agents:
					if m.team != 0 or m.is_user or m.role in ["GK", "DF"] or _support.has(m.idx) or _is_offside(m, u0):
						continue
					if m.pos.y > u0.pos.y + 2.0 or t < m.run_cd:
						continue
					if bestr == null or m.pos.y < bestr.pos.y:
						bestr = m
				if bestr != null:
					bestr.run_until = t + Rules.RUNNER_SECS
					bestr.run_cd = t + Rules.RUNNER_SECS + 3.0
					runner_idx = bestr.idx
	else:
		runner_idx = -1
	var off_line := [_offside_line_n(0), _offside_line_n(1)]
	for a in agents:
		a.urgent = false
		var bn := _n(ball_pos, a.team)
		var tn := Vector2.ZERO
		if a.role == "GK":
			tn = _gk_spot(a, bn, poss == a.team)
		elif poss == a.team or poss < 0:
			tn = _attack_spot(a, bn, float(off_line[a.team]))
		else:
			tn = _defend_spot(a, bn)
		a.target = _n(tn, a.team)
	if phase == "play" and poss >= 0:
		_assign_marks(1 - poss)

	# Balón suelto o en vuelo: el más cercano de cada equipo va a buscarlo.
	# (En pelota parada nadie va a buscarla ni presiona: ver _step_set_piece.)
	if phase != "play":
		pass
	elif owner < 0:
		var dest := ball_pos + loose_vel * 0.4
		var recv: int = -1
		if not flight.is_empty():
			dest = flight["e"]
			recv = int(flight["receiver"])
		if recv >= 0:
			var r: Agent = agents[recv]
			r.target = dest
			r.urgent = true
		if not flight.is_empty() and bool(flight.get("cross", false)):
			var gkc := _goalkeeper(1 - int(flight["team"]))
			if _n(dest, gkc.team).y > 97.0 and absf(dest.x - 34.0) < 10.0:
				gkc.target = dest
				gkc.urgent = true
		for team in range(2):
			if recv >= 0 and (agents[recv] as Agent).team == team:
				continue
			var exclude: int = last_kicker if (t - last_kick_t) < 0.4 else -1
			var ch := _nearest(team, dest, false, exclude)
			if ch != null:
				ch.target = dest if flight.is_empty() else ball_pos.lerp(dest, 0.5)
				ch.urgent = true
		# El arquero sale si el balón suelto está en su área chica.
		for team in range(2):
			var gk := _goalkeeper(team)
			var bn := _n(dest, team)
			if flight.is_empty() and bn.y > 93.0 and absf(bn.x - 34.0) < 12.0:
				gk.target = dest
				gk.urgent = true
	else:
		# Presión: el más cercano encima del portador, el segundo cubre.
		var c: Agent = agents[owner]
		var dteam := 1 - c.team
		var own_goal := Vector2(34.0, _goal_y(c.team))
		var p1 := _nearest(dteam, c.pos)
		if p1 != null:
			p1.target = c.pos + (own_goal - c.pos).normalized() * 0.8
			p1.urgent = true
			var p2 := _nearest(dteam, c.pos, false, p1.idx)
			if p2 != null and p2.pos.distance_to(c.pos) < 18.0:
				p2.target = c.pos + (own_goal - c.pos).normalized() * 7.0
				p2.urgent = true
		# ACHIQUE: atacante solo en el área, encarando → el arquero le sale.
		var gk := _goalkeeper(dteam)
		var cn := _n(c.pos, dteam)
		if c.role != "GK" and cn.y > 87.0 and absf(cn.x - 34.0) < 20.0 and gk.pos.distance_to(c.pos) < 13.0 and gk.stun <= 0.0:
			gk.target = c.pos + (own_goal - c.pos).normalized() * 0.9
			gk.urgent = true

	# Arquero estirándose a un remate.
	if not flight.is_empty() and flight["kind"] == "shot":
		var gk := _goalkeeper(1 - int(flight["team"]))
		if gk.dive_x >= 0.0:
			gk.urgent = true

	# Órdenes del usuario sobre su propio jugador (sin balón).
	if not user_auto and owner != user_idx:
		var u := user()
		if user_press_t > 0.0 and owner >= 0 and (agents[owner] as Agent).team == 1:
			u.target = (agents[owner] as Agent).pos
			u.urgent = true
		elif user_move_t > 0.0:
			u.target = user_move_target
			u.urgent = true

## ARQUERO (17-oct, "mejora a los arqueros"): sobre la línea pelota-centro
## del arco, más afuera cuanto más lejos está la pelota (achica el ángulo);
## con la pelota de su equipo lejos, sale de líbero.
func _gk_spot(a: Agent, bn: Vector2, own_poss: bool) -> Vector2:
	var goal_c := Vector2(34.0, PITCH_L)
	var to_b: Vector2 = bn - goal_c
	var dist: float = maxf(to_b.length(), 0.1)
	var out: float = clampf(dist * 0.08, 0.8, 3.6)
	if own_poss and bn.y < 60.0:
		out = 9.0
	var tn: Vector2 = goal_c + to_b / dist * out
	tn.x = clampf(tn.x, 34.0 - GOAL_HALF + 0.6, 34.0 + GOAL_HALF - 0.6)
	tn.y = minf(tn.y, PITCH_L - 0.6)
	return tn

## EN ATAQUE: la forma de siempre empujada hacia arriba, extremos abiertos,
## sin pasarse del offside; y DESMARQUES al espacio (delanteros y extremos).
func _attack_spot(a: Agent, bn: Vector2, off_n: float) -> Vector2:
	var tn := Vector2.ZERO
	var k: float = ROLE_SHIFT[a.role]
	tn.x = a.base.x + (bn.x - 34.0) * 0.32
	tn.y = a.base.y + (bn.y - 52.5) * k - float(ROLE_PUSH[a.role])
	if a.base.x < 15.0:
		tn.x -= 4.0
	elif a.base.x > 53.0:
		tn.x += 4.0
	if a.role == "MF" and (a.base.x < 15.0 or a.base.x > 53.0):
		tn.y -= 9.0
	tn.y = clampf(tn.y, float(ROLE_YMIN[a.role]), float(ROLE_YMAX[a.role]))
	if a.role != "DF":
		tn.y = maxf(tn.y, off_n + 0.5)
	# Desmarque: arranca habilitado y pica a la espalda de la defensa.
	if a.is_user and not user_auto:
		pass
	elif t < a.run_until:
		tn = Vector2(clampf(_n(a.pos, a.team).x + (34.0 - _n(a.pos, a.team).x) * 0.15, 6.0, 62.0), maxf(off_n - 9.0, 6.0))
		a.urgent = true
	elif owner >= 0 and agents[owner].team == a.team and owner != a.idx and (a.role == "ST" or (a.role == "MF" and absf(a.base.x - 34.0) > 18.0)):
		var an: Vector2 = _n(a.pos, a.team)
		if an.y < off_n + 4.0 and an.y > off_n - 0.5 and off_n > 14.0 and rng.randf() < 0.012:
			a.run_until = t + 2.4
	# APOYOS: con la pelota en TUS pies, los dos compañeros más cerca se
	# abren a los costados y adelante: siempre tenés dos opciones de pase.
	if owner == user_idx and _support.has(a.idx):
		var un: Vector2 = _n(user().pos, a.team)
		var side_s: float = -1.0 if _support[0] == a.idx else 1.0
		tn = Vector2(clampf(un.x + side_s * 11.0, 4.0, 64.0), maxf(un.y - 8.0, off_n + 1.0))
		a.urgent = true
		return tn
	# Apoyo: el más cercano al portador le ofrece un pase corto (no se esconde).
	if owner >= 0 and owner != a.idx and agents[owner].team == a.team and a.role != "DF":
		var cn: Vector2 = _n(agents[owner].pos, a.team)
		var an2: Vector2 = _n(a.pos, a.team)
		if an2.distance_to(cn) < 16.0 and an2.distance_to(cn) > 3.0 and t >= a.run_until:
			var side: float = 1.0 if an2.x >= cn.x else -1.0
			tn = tn.lerp(cn + Vector2(side * 9.0, -6.0), 0.45)
	tn.x = clampf(tn.x, 2.0, PITCH_W - 2.0)
	return tn

## EN DEFENSA: bloque compacto. La línea de 4 sube y baja con la pelota (y
## nunca se mete en el arco), los volantes delante; todos cierran hacia el
## lado de la pelota.
func _defend_spot(a: Agent, bn: Vector2) -> Vector2:
	var line: float = clampf(bn.y + 20.0, 64.0, 97.0)
	var tn := Vector2.ZERO
	tn.x = 34.0 + (a.base.x - 34.0) * 0.78 + (bn.x - 34.0) * 0.42
	match a.role:
		"DF":
			tn.y = line + (2.0 if absf(a.base.x - 34.0) > 20.0 else 0.0)
		"MF":
			tn.y = line - 13.0
		_:
			tn.y = clampf(bn.y - 8.0, 45.0, 75.0) # los delanteros esperan la contra
	if a.mark_idx >= 0:
		# Marca: entre su atacante y el arco, a un paso.
		var m: Agent = agents[a.mark_idx]
		var mn: Vector2 = _n(m.pos, a.team)
		tn = mn + (Vector2(34.0, PITCH_L) - mn).normalized() * 1.6
		a.urgent = true
	tn.x = clampf(tn.x, 2.0, PITCH_W - 2.0)
	return tn

## Cerca del área, cada defensor/volante toma al atacante libre más cercano.
func _assign_marks(dteam: int) -> void:
	for a in agents:
		a.mark_idx = -1
	var bn: Vector2 = _n(ball_pos, dteam)
	if bn.y < 62.0:
		return
	var taken: Dictionary = {}
	for a in agents:
		if a.team != dteam or a.role == "GK" or a.role == "ST":
			continue
		var best: Agent = null
		var bd: float = 14.0
		for o in agents:
			if o.team == dteam or o.role == "GK" or o.idx == owner or taken.has(o.idx):
				continue
			var on: Vector2 = _n(o.pos, dteam)
			if on.y < 66.0:
				continue
			var d: float = o.pos.distance_to(a.pos)
			if d < bd:
				bd = d
				best = o
		if best != null:
			taken[best.idx] = true
			a.mark_idx = best.idx

# --------------------------------------------------------------- portador
func _carrier_logic(dt: float) -> void:
	if owner < 0:
		return
	var c: Agent = agents[owner]
	c.urgent = true
	if not windup.is_empty() and int(windup["idx"]) == owner:
		c.target = c.pos # firme mientras patea
		return
	if owner == user_idx and not user_auto:
		c.target = user_dribble_target if user_dribble else c.pos
		return
	if c.role == "GK":
		c.target = c.pos
		if c.action == "atajada" and t - c.action_t > 0.6:
			_act(c, "hold")
		# CON LA PELOTA EN LAS MANOS (como WSC): sale caminando hasta el borde
		# de su área chica larga y recién ahí la saca.
		if c.action == "hold" and phase == "play":
			var cn: Vector2 = _n(c.pos, c.team)
			c.target = _n(Vector2(lerpf(cn.x, 34.0, 0.4), Rules.GK_WALK_OUT_Y), c.team)
			if cn.y > Rules.GK_WALK_OUT_Y + 1.0:
				gk_hold = maxf(gk_hold, 0.35) # no la saca hasta llegar
		gk_hold -= dt
		if gk_hold <= 0.0:
			_ai_gk_distribute(c)
		return
	c.target = c.carry_target
	c.decide_cd -= dt
	if c.decide_cd <= 0.0:
		_ai_decide(c)

func _ai_decide(a: Agent) -> void:
	var an := _n(a.pos, a.team)
	var pressure := _pressure(a)
	var goal_d: float = an.distance_to(Vector2(34, 0))
	var best_kind := "dribble"
	var best_score: float = -9.0
	var best_target: Agent = null

	# LA PEDISTE (17-oct, Wilber en su video: "¡Pídela!" y nadie se la daba):
	# el compañero te la da. Al pie si la línea está limpia; si hay un rival
	# en el medio, por arriba.
	if a.team == user().team and t < user_call_until and not user_auto and phase == "play":
		var u := user()
		var du: float = a.pos.distance_to(u.pos)
		if du >= 3.0 and du <= 45.0 and not _is_offside(u, a):
			var lane_u: float = 99.0
			for o in agents:
				if o.team != a.team:
					lane_u = minf(lane_u, _seg_dist(o.pos, a.pos, u.pos))
			user_call_until = -1.0
			var lob: bool = lane_u < Rules.CALL_LOB_LANE and du > 9.0
			_queue_pass(a, lead_point(a.pos, u), user_idx, 0.0, -1, {"lofted": true, "h": maxf(2.5, du * 0.15)} if lob else {})
			return

	if goal_d < 26.0:
		var ang: float = absf(an.x - 34.0) / maxf(an.y, 1.0)
		var s: float = 1.42 - goal_d * 0.05 + float(a.shooting) * 0.004 - ang * 0.30 + rng.randf() * 0.2
		if s > best_score:
			best_score = s
			best_kind = "shoot"

	for m in agents:
		if m.team != a.team or m.idx == a.idx or m.role == "GK":
			continue
		var d: float = a.pos.distance_to(m.pos)
		if d < 5.0 or d > 40.0:
			continue
		var mn := _n(m.pos, a.team)
		if _is_offside(m, a) and rng.randf() > Rules.OFFSIDE_MISREAD:
			continue
		var progress: float = an.y - mn.y
		var open: float = 10.0
		var lane: float = 99.0
		for o in agents:
			if o.team == a.team:
				continue
			open = minf(open, o.pos.distance_to(m.pos))
			lane = minf(lane, _seg_dist(o.pos, a.pos, m.pos))
		var risk: float = (2.2 - lane) * 0.55 if lane < 2.2 and d <= 26.0 else 0.0
		var s: float = progress * 0.035 + open * 0.07 - risk - d * 0.008 + rng.randf() * 0.25
		# Abrir la cancha: el extremo libre en campo rival es una salida buena.
		if absf(mn.x - 34.0) > 18.0 and mn.y < 45.0 and open > 4.0:
			s += 0.10
		if m.is_user:
			s += Rules.USER_PASS_BIAS
			if t < user_call_until:
				s += Rules.USER_CALL_BONUS
		# PASE EN PROFUNDIDAD al que pica (al espacio delante de él).
		if t < m.run_until and m.vel.length() > 2.0 and d < 34.0:
			s += Rules.THROUGH_BALL_BONUS
		if s > best_score:
			best_score = s
			best_kind = "pass"
			best_target = m

	# Extremo en el último tercio: centro al área (cabezazos, y los que se
	# pasan terminan en córner o saque de arco).
	if a.role != "GK" and an.y < 34.0 and absf(an.x - 34.0) > 15.0 and rng.randf() < 0.4:
		var box: Array = []
		for m in agents:
			if m.team == a.team and m.idx != a.idx and m.role != "GK":
				var mn := _n(m.pos, a.team)
				if mn.y < 26.0 and absf(mn.x - 34.0) < 18.0:
					box.append(m)
		var spot_n := Vector2(34.0 + rng.randf_range(-6.0, 6.0), rng.randf_range(6.0, 12.0))
		var r: Agent = box[rng.randi() % box.size()] if not box.is_empty() else _nearest(a.team, _n(spot_n, a.team), false, a.idx)
		var tgt: Vector2 = _n(spot_n, a.team).lerp(r.pos, 0.5)
		_queue_pass(a, tgt, r.idx, 0.0, -1, {"cross": true, "lofted": true, "h": 3.0})
		sim_event.emit("cross", {"team": a.team})
		return

	# Defensor apretado en su área: la revienta (despeje largo y cruzado).
	if a.role == "DF" and an.y > 74.0 and pressure > 0.3 and rng.randf() < 0.6:
		var tn := an + Vector2(rng.randf_range(-22.0, 22.0), -rng.randf_range(30.0, 42.0))
		var chaser := _nearest(a.team, _n(tn, a.team), false, a.idx)
		_queue_pass(a, _n(tn, a.team), -1, 0.0, chaser.idx if chaser != null else -1)
		sim_event.emit("clearance", {"team": a.team})
		return

	var space: float = _space_ahead(a)
	var ds: float = 0.25 + (minf(space, 12.0) - 4.0) * 0.05 + float(a.dribbling) * 0.002 - pressure * 0.3 + rng.randf() * 0.2
	if ds > best_score:
		best_kind = "dribble"

	match best_kind:
		"shoot":
			var gk := _goalkeeper(1 - a.team)
			var side: float = 1.0 if gk.pos.x < 34.0 else -1.0
			if rng.randf() < 0.3:
				side = -side
			# Abajo, a media altura o al ángulo.
			var z_pick: float = [0.25, 0.25, 1.1, 2.1][rng.randi() % 4]
			_queue_shot(a, 34.0 + side * (GOAL_HALF - 0.9), rng.randf_range(0.55, 0.85), 0.0, z_pick)
		"pass":
			var trust: float = Rules.PASS_LEAD_TRUST_RUNNER if t < best_target.run_until else Rules.PASS_LEAD_TRUST
			_queue_pass(a, lead_point(a.pos, best_target, trust), best_target.idx)
		_:
			var tn := an + Vector2((34.0 - an.x) * 0.15 + rng.randf_range(-5.0, 5.0), -9.0)
			a.carry_target = _clamp_pitch(_n(tn, a.team))
			a.decide_cd = rng.randf_range(0.45, 0.95)

## FUERA DE JUEGO: `m` está adelantado respecto de la pelota y del
## penúltimo rival en el momento del pase de `passer` (en campo rival).
func _is_offside(m: Agent, passer: Agent) -> bool:
	if m.team != passer.team or m.role == "GK":
		return false
	var mn: Vector2 = _n(m.pos, m.team)
	if mn.y >= 52.5:
		return false
	var ys: Array = []
	for o in agents:
		if o.team != m.team:
			ys.append(_n(o.pos, m.team).y)
	ys.sort()
	var second: float = ys[1] if ys.size() > 1 else 0.0
	var ball_n: float = _n(passer.pos, m.team).y
	return mn.y < minf(second, ball_n) - Rules.OFFSIDE_MARGIN

func _space_ahead(a: Agent) -> float:
	var an := _n(a.pos, a.team)
	var best: float = 30.0
	for o in agents:
		if o.team == a.team:
			continue
		var v := _n(o.pos, a.team) - an
		if v.y < 0.0 and absf(v.x) < -v.y * 0.8 + 2.0:
			best = minf(best, v.length())
	return best

func _ai_gk_distribute(gk: Agent) -> void:
	var best: Agent = null
	var bs: float = -99.0
	for m in agents:
		if m.team != gk.team or m.role == "GK":
			continue
		var d: float = gk.pos.distance_to(m.pos)
		if d > 45.0:
			continue
		var open: float = 10.0
		for o in agents:
			if o.team != gk.team:
				open = minf(open, o.pos.distance_to(m.pos))
		var s: float = open * 0.1 + rng.randf() * 0.4
		if s > bs:
			bs = s
			best = m
	if best != null:
		_queue_pass(gk, best.pos, best.idx)

# ------------------------------------------------------------------ patadas
func _queue_pass(a: Agent, target: Vector2, receiver: int, curve: float = 0.0, chaser: int = -1, extra: Dictionary = {}) -> void:
	var gesture: String = "pase"
	var secs: float = Rules.KICK_WINDUP
	if a.role == "GK" and owner == a.idx:
		if a.pos.distance_to(target) > 30.0:
			gesture = "saque_largo"
			secs = Rules.GK_KICK_WINDUP
		else:
			gesture = "lanzar" # con la mano
			secs = Rules.GK_THROW_WINDUP
	windup = {"idx": a.idx, "kind": "pass", "target": target, "receiver": receiver, "curve": curve,
		"chaser": chaser, "extra": extra, "at": t + secs}
	_act(a, gesture, target - a.pos)

func _queue_shot(a: Agent, aim_x: float, power: float, curve: float, aim_z: float) -> void:
	windup = {"idx": a.idx, "kind": "shot", "x": aim_x, "power": power, "curve": curve, "z": aim_z,
		"at": t + Rules.SHOT_WINDUP}
	_act(a, "remate", Vector2(aim_x, _goal_y(a.team)) - a.pos)

func _step_windup() -> void:
	if windup.is_empty():
		return
	var w: Dictionary = windup
	if owner != int(w["idx"]):
		windup = {} # se la sacaron mientras armaba la patada
		return
	if t < float(w["at"]):
		return
	windup = {}
	var a: Agent = agents[int(w["idx"])]
	_keep_act = true
	if w["kind"] == "shot":
		_launch_shot(a, float(w["x"]), float(w["power"]), float(w["curve"]), false, float(w["z"]))
		if bool(w.get("chip", false)):
			flight["chip"] = true
			flight["h"] = 2.2 + float(flight["len"]) * 0.06
	else:
		_kick_pass(a, w["target"], int(w["receiver"]), float(w["curve"]), int(w["chaser"]))
		for k in (w["extra"] as Dictionary):
			flight[k] = w["extra"][k]
	_keep_act = false

func _kick_pass(a: Agent, target: Vector2, receiver: int, curve: float = 0.0, chaser: int = -1) -> void:
	var sp_kind: String = _end_set_piece()
	if sp_kind == "throw" and a.pos.distance_to(target) > 24.0:
		target = a.pos + (target - a.pos).normalized() * 24.0
	target = _clamp_pitch(target)
	var pressure := _pressure(a)
	var dir := target - a.pos
	var d: float = maxf(dir.length(), 1.0)
	var err: float = rng.randfn(0.0, Rules.pass_angle_sigma(a.passing, pressure) * (Rules.LONG_BALL_ERROR_MULT if d > 26.0 else 1.0))
	# Sin recortar a la cancha: un pase desviado puede irse al lateral o
	# al fondo (antes casi nunca había saques de banda ni córners).
	var e := a.pos + dir.rotated(err)
	e = Vector2(clampf(e.x, -3.0, PITCH_W + 3.0), clampf(e.y, -3.0, PITCH_L + 3.0))
	var lofted: bool = d > 26.0 or sp_kind in ["corner", "goal_kick", "throw"]
	var perp := Vector2(-dir.y, dir.x).normalized()
	var c := a.pos.lerp(e, 0.5) + perp * curve * d * Rules.CURVE_BEND
	var h: float = d * 0.12 if lofted else 0.0
	if sp_kind == "throw":
		h = 1.6
	flight = {
		"kind": "pass", "team": a.team, "s": a.pos, "c": c, "e": e,
		"len": d, "done": 0.0, "speed": Rules.pass_speed(d),
		"receiver": receiver if receiver >= 0 else chaser,
		"lofted": lofted, "h": h,
		"tried": {}, "passer": a.idx, "curve": curve, "over": false,
		"cross": sp_kind == "corner" or (lofted and _n(e, a.team).y < 20.0),
	}
	if sp_kind == "throw":
		# El gesto ya venía armado (pelota atrás de la cabeza): sigue desde la
		# mitad, cuando sale la pelota.
		_act(a, "saque", e - a.pos)
		a.action_t = t - 0.3
	elif _keep_act:
		pass # el gesto arrancó en la preparación (_queue_pass)
	elif a.role == "GK" and d > 30.0:
		_act(a, "saque_largo", e - a.pos)
	else:
		_act(a, "pase", e - a.pos)
	_release(a)
	stats["passes"][a.team] += 1
	_last_passer = a.idx
	# Fuera de juego: se mira en el momento del pase (no en saques de banda,
	# de arco ni córners). Si el que recibe estaba adelantado → pitazo al tocarla.
	if sp_kind == "" or sp_kind == "free_kick":
		var rcv: int = int(flight["receiver"])
		var offs: Array = []
		for m in agents:
			if m.team == a.team and m.idx != a.idx and _is_offside(m, a):
				offs.append(m.idx)
		if not offs.is_empty():
			flight["offside"] = offs
		if rcv >= 0 and offs.has(rcv):
			flight["offside_rcv"] = true
	if a.idx == user_idx:
		stats["user_passes"] += 1
		user_dribble = false

var _shot_sp_kind: String = ""
func _launch_shot(a: Agent, aim_x: float, power: float, curve: float, header: bool = false, aim_z: float = -1.0) -> void:
	_shot_sp_kind = _end_set_piece()
	var gy := _goal_y(a.team)
	var pressure := _pressure(a)
	var dist: float = a.pos.distance_to(Vector2(aim_x, gy))
	aim_x += rng.randfn(0.0, Rules.shot_error_sigma(a.shooting, dist, pressure, power, curve) * (Rules.HEADER_ERROR_MULT if header else 1.0))
	if aim_z < 0.0:
		aim_z = Rules.shot_height_for_power(power)
	if header:
		aim_z = clampf(aim_z * 0.7, 0.2, 2.3)
	aim_z = maxf(aim_z + rng.randfn(0.0, Rules.shot_height_sigma(a.shooting, dist, pressure, power) * (Rules.HEADER_ERROR_MULT if header else 1.0)), 0.05)
	var over: bool = aim_z > GOAL_H + BALL_HIT_R
	var e := Vector2(aim_x, gy + (-0.6 if a.team == 0 else 0.6))
	var dir := e - a.pos
	var perp := Vector2(-dir.y, dir.x).normalized()
	var c := a.pos.lerp(e, 0.5) + perp * curve * dist * Rules.CURVE_BEND
	var speed: float = Rules.shot_speed(power, a.shooting) * (Rules.HEADER_SPEED_MULT if header else 1.0)
	flight = {
		"kind": "shot", "team": a.team, "s": a.pos, "c": c, "e": e,
		"len": dist, "done": 0.0, "speed": speed, "receiver": -1,
		"lofted": false, "z": aim_z, "z0": 1.9 if header else (0.5 if t - a.lofted_recv_t < 0.8 else 0.1),
		"h": clampf(dist * 0.02, 0.1, 0.9) * (1.0 - power * 0.5),
		"tried": {}, "passer": a.idx, "curve": curve, "over": over,
	}
	# El arquero lee la dirección INICIAL del balón (tangente hacia el
	# punto de control); con rosca, esa lectura lo engaña. Cuanto mejor
	# arquero, más corrige hacia el destino real.
	var gk := _goalkeeper(1 - a.team)
	var tdir := (c - a.pos)
	var read_x: float = aim_x
	if absf(tdir.y) > 0.01:
		read_x = a.pos.x + tdir.x * ((gy - a.pos.y) / tdir.y)
	var trust: float = clampf(float(gk.keeping) / 100.0 * 0.7, 0.0, 0.85)
	gk.dive_x = lerpf(read_x, aim_x, trust) + rng.randfn(0.0, 0.5)
	gk.dive_delay = Rules.gk_reaction(gk.keeping)
	# Hasta donde llega: un poco más allá del palo, no a la tribuna.
	gk.dive_x = clampf(gk.dive_x, 34.0 - GOAL_HALF - 0.6, 34.0 + GOAL_HALF + 0.6)
	# Lo que se va claramente afuera o muy arriba, un buen arquero lo mira
	# irse (no se tira de gusto).
	var wide: float = absf(aim_x - 34.0) - GOAL_HALF
	if (wide > Rules.GK_LET_GO_WIDE or aim_z > GOAL_H + 1.0) and rng.randf() < float(gk.keeping) / 100.0:
		gk.dive_x = lerpf(gk.pos.x, clampf(aim_x, 34.0 - GOAL_HALF + 0.8, 34.0 + GOAL_HALF - 0.8), 0.3)
	if _shot_sp_kind == "penalty":
		# Penal: el arquero ADIVINA (no llega a leerlo): un palo o se queda.
		var guess: float = rng.randf()
		gk.dive_x = 34.0 if guess < Rules.PEN_GK_STAY else 34.0 + (1.0 if rng.randf() < 0.5 else -1.0) * (GOAL_HALF - 1.2)
		if rng.randf() < Rules.pen_gk_reads(gk.keeping):
			gk.dive_x = aim_x
		gk.dive_delay = 0.05
	gk_dive_z = aim_z
	var gesture: String = "remate"
	if header:
		# De espaldas al arco y muy cerca: a veces, chilena.
		gesture = "chilena" if rng.randf() < Rules.BICYCLE_CHANCE else "cabezazo"
	elif t - a.lofted_recv_t < 0.8:
		gesture = "volea" # le pegó de aire, apenas la bajó
	if not _keep_act or gesture != "remate":
		_act(a, gesture, e - a.pos)
	_release(a)
	stats["shots"][a.team] += 1
	if a.idx == user_idx:
		stats["user_shots"] += 1
		user_dribble = false
	sim_event.emit("shot", {"team": a.team, "user": a.idx == user_idx})

func _act(a: Agent, action: String, dir: Vector2 = Vector2.ZERO) -> void:
	a.action = action
	a.action_t = t
	a.action_dir = dir

func _release(a: Agent) -> void:
	owner = -1
	last_kicker = a.idx
	last_kick_t = t
	last_touch_team = a.team
	loose_vel = Vector2.ZERO

func _give_ball(a: Agent) -> void:
	var prev_team := _poss_team()
	var was_flight: Dictionary = flight
	var recv_h: float = ball_height()
	flight = {}
	ball_z = 0.0
	ball_vz = 0.0
	owner = a.idx
	owner_since = t
	loose_vel = Vector2.ZERO
	last_touch_team = a.team
	a.decide_cd = rng.randf_range(0.25, 0.6)
	a.carry_target = a.pos
	a.dive_x = -1.0
	if a.role == "GK":
		gk_hold = Rules.GK_HOLD_SECS
		# Si recién la atajó, se ve el gesto de la atajada y DESPUÉS la sostiene
		# (ver _carrier_logic); si no, la agarra directo.
		if not (a.action == "atajada" and t - a.action_t < 0.05):
			_act(a, "hold")
	if not was_flight.is_empty() and was_flight["kind"] == "pass" and (was_flight.get("offside", []) as Array).has(a.idx):
		_call_offside(a)
		return
	# PRIMER TOQUE: un pase fuerte a un jugador de la IA a veces se le
	# escapa (más si no es bueno con la pelota). A vos no: tu control es tuyo.
	if not was_flight.is_empty() and was_flight["kind"] == "pass" and a.idx != user_idx and a.role != "GK" \
			and rng.randf() < Rules.heavy_touch(float(was_flight["speed"]), a.dribbling):
		owner = -1
		last_touch_team = a.team
		last_kicker = a.idx
		last_kick_t = t
		var fd: Vector2 = ((was_flight["e"] as Vector2) - (was_flight["s"] as Vector2)).normalized()
		loose_vel = fd.rotated(rng.randf_range(-0.6, 0.6)) * rng.randf_range(3.5, 6.0)
		_act(a, "control")
		sim_event.emit("heavy_touch", {"team": a.team})
		return
	if not was_flight.is_empty() and was_flight["kind"] == "pass" and bool(was_flight.get("lofted", false)) and a.role != "GK":
		_act(a, "control")
		a.lofted_recv_t = t
	elif not was_flight.is_empty() and was_flight["kind"] == "pass" and a.role != "GK" and a.vel.length() < Rules.CONTROL_MAX_SPEED:
		# PRIMER TOQUE al pie (17-oct, animación nueva): para la pelota con la
		# cara interna, mirando hacia de donde vino.
		_act(a, "control", (was_flight["s"] as Vector2) - a.pos)
	if not was_flight.is_empty() and was_flight["kind"] == "pass":
		var passer: Agent = agents[int(was_flight["passer"])]
		if passer.team == a.team:
			stats["passes_ok"][a.team] += 1
			if passer.idx == user_idx:
				stats["user_passes_ok"] += 1
	if a.idx == user_idx:
		stats["user_receptions"] += 1
		user_dribble = false
		sim_event.emit("user_ball", {})
		if not user_first.is_empty() and t - float(user_first["t"]) < 2.5:
			_user_first_exec(a, recv_h)
			return
	elif prev_team != a.team:
		sim_event.emit("turnover", {"team": a.team})

## Ejecuta el remate/pase de primera que dejaste armado.
func _user_first_exec(u: Agent, h: float) -> void:
	var uf: Dictionary = user_first
	user_first = {}
	var dir: Vector2 = uf["dir"]
	var x_at: float = _goal_x_along(u.pos, dir)
	if x_at > -900.0:
		if h > 1.3:
			_launch_shot(u, x_at, float(uf["power"]), 0.0, true, Rules.shot_height_for_power(float(uf["power"])))
		else:
			if h > 0.4:
				u.lofted_recv_t = t # de volea
			_launch_shot(u, x_at, float(uf["power"]), float(uf["curve"]), false, Rules.shot_height_for_power(float(uf["power"])))
		sim_event.emit("first_time", {"shot": true})
		return
	var e := u.pos + dir * (7.0 + float(uf["power"]) * 30.0)
	var recv := _nearest(0, e, false, user_idx)
	_kick_pass(u, e, -1, float(uf["curve"]), recv.idx if recv != null else -1)
	sim_event.emit("first_time", {"shot": false})

## Pitazo de offside: el juez levanta el banderín y saca el rival (tiro libre
## indirecto desde donde estaba el adelantado).
func _call_offside(a: Agent) -> void:
	owner = -1
	lines_flag_t[0 if a.pos.y < 52.5 else 1] = t
	_ref_do("pitazo")
	sim_event.emit("offside", {"team": a.team, "user": a.idx == user_idx})
	_start_set_piece("free_kick", 1 - a.team, _clamp_pitch(a.pos))

# --------------------------------------------------------------- movimiento
func _move_agents(dt: float) -> void:
	for a in agents:
		var speed: float = Rules.run_speed(a.pace)
		if not a.urgent:
			speed *= 0.72
		if a.idx == owner:
			# Tu carrera con la pelota (tocaste un punto) es casi a fondo.
			speed *= Rules.CARRY_SPEED_USER if (a.idx == user_idx and user_dribble) else Rules.CARRY_SPEED
		if a.stun > 0.0:
			speed *= 0.3
		if a.role == "GK" and a.idx == owner and a.action == "hold":
			speed *= Rules.GK_WALK_MULT # camina con la pelota en las manos
		if a.slide_t > 0.0:
			a.slide_t -= dt
			var sv: float = Rules.SLIDE_SPEED * clampf(a.slide_t / Rules.SLIDE_SECS + 0.3, 0.3, 1.0)
			a.vel = a.slide_dir * sv
			a.pos += a.vel * dt
			if a.slide_t <= 0.0:
				a.stun = maxf(a.stun, 0.8) # levantarse
			continue
		if a.burst_t > 0.0:
			a.burst_t -= dt
			speed *= 1.35
		if a.role == "GK" and a.dive_x >= 0.0 and not flight.is_empty():
			a.dive_delay -= dt
			if a.dive_delay <= 0.0:
				var dx: float = a.dive_x - a.pos.x
				if a.action != "estirada" and absf(dx) > 0.8:
					_act(a, "estirada", Vector2(dx, 0.0))
				var step_x: float = clampf(dx, -Rules.gk_dive_speed(a.keeping) * dt, Rules.gk_dive_speed(a.keeping) * dt)
				a.pos.x += step_x
				a.vel = Vector2(step_x / dt, 0.0)
			continue
		var to := a.target - a.pos
		var d: float = to.length()
		var want := Vector2.ZERO
		if d > 0.4:
			want = to / d * minf(speed, d * 2.5)
		# INERCIA (17-oct, Wilber: "seguir mejorando la fluidez de todas las
		# acciones"): antes la velocidad saltaba a la deseada en un cuadro
		# (arrancar, frenar y dar media vuelta eran instantáneos y el cuerpo
		# "temblaba" entre direcciones). Ahora acelera con un tope.
		var acc: float = Rules.ACCEL_URGENT if a.urgent else Rules.ACCEL
		if a.idx == user_idx and a.idx == owner:
			acc *= Rules.USER_CARRY_ACCEL_MULT # con la pelota respondés al toque
		if want.dot(a.vel) < 0.0:
			acc *= Rules.BRAKE_MULT
		# SEPARACIÓN: los compañeros no se enciman (video 2: uno corría pegado
		# encima tuyo). Empuje suave lejos del compañero a menos de SEP_DIST.
		if a.role != "GK" and a.slide_t <= 0.0:
			for o in agents:
				if o == a or o.team != a.team:
					continue
				var dd: Vector2 = a.pos - o.pos
				var dl: float = dd.length()
				if dl < Rules.SEP_DIST and dl > 0.01:
					want += dd / dl * (Rules.SEP_DIST - dl) * Rules.SEP_PUSH
		a.vel = a.vel.move_toward(want, acc * dt)
		if d <= 0.4 and a.vel.length() < 1.2:
			a.vel = Vector2.ZERO
		else:
			a.pos += a.vel * dt
		a.pos.x = clampf(a.pos.x, -1.0, PITCH_W + 1.0)
		a.pos.y = clampf(a.pos.y, -1.5, PITCH_L + 1.5)

func _clamp_pitch(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 0.6, PITCH_W - 0.6), clampf(p.y, 0.6, PITCH_L - 0.6))

# -------------------------------------------------------------------- balón
func _update_ball(dt: float) -> void:
	if owner >= 0:
		var c: Agent = agents[owner]
		var face := Vector2(0, -1 if c.team == 0 else 1)
		var spd: float = c.vel.length()
		if spd > 0.5:
			face = c.vel / spd
		# CONDUCCIÓN CON TOQUES (17-oct): corriendo, la pelota se le adelanta
		# y la alcanza (como en el juego); quieto, pegada al pie. Va hacia ese
		# punto con un poco de retraso: no salta de lado cuando el jugador gira.
		# TOQUES DE VERDAD (17-oct, "más fluidez con el balón"): cada
		# CARRY_TOUCH_M metros el pie la empuja (sale rápido hacia adelante),
		# rueda más lento que él y la alcanza — antes era un vaivén parejo.
		carry_phase = fmod(carry_phase + spd * dt / Rules.CARRY_TOUCH_M, 1.0)
		var f: float = smoothstep(0.0, 0.15, carry_phase) if carry_phase < 0.15 else 1.0 - (carry_phase - 0.15) / 0.85
		var reach: float = (0.5 + Rules.CARRY_TOUCH_AHEAD * f) if spd > 2.0 else Rules.BALL_IDLE_AHEAD
		# Al pie DERECHO (17-oct, Wilber: "parece que estoy sobre el balón"):
		# quieto de espaldas la pelota quedaba bajo el cuerpo; ahora va un poco
		# adelante y al costado, se ve siempre.
		var side_v: Vector2 = Vector2(-face.y, face.x) * (Rules.BALL_SIDE if spd < 4.0 else Rules.BALL_SIDE * 0.4)
		var want_b: Vector2 = c.pos + face * reach + side_v
		# Quieto (y casi siempre en cámara lenta): se acomoda RÁPIDO al pie;
		# antes tardaba segundos reales y parecía que estabas parado encima.
		ball_pos = ball_pos.lerp(want_b, 1.0 - exp(-(16.0 if spd > 0.5 else 70.0) * dt))
		if ball_pos.distance_to(want_b) > 2.0:
			ball_pos = want_b
		return
	if not flight.is_empty():
		_update_flight(dt)
		return
	# Suelto (con altura: rebotes del palo, del arquero, bloqueos)
	ball_pos += loose_vel * dt
	if ball_z > 0.0 or ball_vz > 0.0:
		ball_vz -= GRAVITY * dt
		ball_z += ball_vz * dt
		if ball_z <= 0.0:
			ball_z = 0.0
			if ball_vz < -1.6:
				ball_vz = -ball_vz * 0.45 # pica
				loose_vel *= 0.82
			else:
				ball_vz = 0.0
	loose_vel *= exp(-(1.4 if ball_z < 0.05 else 0.12) * dt)
	if _check_out():
		return
	# Pelota que se va afuera con fuerza, pegada a la línea: nadie llega a
	# tocarla (antes siempre la alcanzaba alguien → casi nunca había laterales).
	var out_x: float = 0.0
	if ball_pos.x < 3.0 and loose_vel.x < -0.6:
		out_x = -1.0
	elif ball_pos.x > PITCH_W - 3.0 and loose_vel.x > 0.6:
		out_x = 1.0
	var out_y: float = 0.0
	if ball_pos.y < 3.0 and loose_vel.y < -0.6:
		out_y = -1.0
	elif ball_pos.y > PITCH_L - 3.0 and loose_vel.y > 0.6:
		out_y = 1.0
	if out_x != 0.0 or out_y != 0.0:
		if out_x != 0.0:
			loose_vel.x = out_x * maxf(absf(loose_vel.x), 2.5)
		if out_y != 0.0:
			loose_vel.y = out_y * maxf(absf(loose_vel.y), 2.5)
		return
	var best: Agent = null
	var bd: float = 0.9
	for a in agents:
		if a.stun > 0.0 or (a.idx == last_kicker and t - last_kick_t < 0.35):
			continue
		# Alta solo la agarra el arquero en su área; si no, hay que esperar que baje.
		var high_ok: float = 2.6 if a.role == "GK" and _n(ball_pos, a.team).y > 88.0 else 1.1
		if ball_z > high_ok:
			continue
		var d: float = a.pos.distance_to(ball_pos)
		if d < bd:
			bd = d
			best = a
	if best != null:
		_give_ball(best)

func _update_flight(dt: float) -> void:
	var f := flight
	f["done"] = float(f["done"]) + float(f["speed"]) * dt
	if f["kind"] == "pass":
		f["speed"] = maxf(float(f["speed"]) - Rules.PASS_DECEL * dt, Rules.PASS_MIN_SPEED)
	else:
		f["speed"] = float(f["speed"]) * exp(-Rules.SHOT_DRAG * dt) # el aire la frena un poco
	var u: float = clampf(float(f["done"]) / float(f["len"]), 0.0, 1.0)
	ball_pos = _bezier(f["s"], f["c"], f["e"], u)
	var team: int = int(f["team"])
	var lofted: bool = f["lofted"]

	if f["kind"] == "pass":
		# El duelo se intenta en cada cuadro de la bajada (antes se probaba UNA
		# vez al 78 % del vuelo, cuando nadie llegaba todavía → nunca había
		# cabezazos).
		if f.get("cross", false) and u > 0.82:
			if _cross_duel(f):
				return
		if (not lofted and u > 0.08) or (u > 0.85 and not f.get("cross", false)):
			var tried: Dictionary = f["tried"]
			for a in agents:
				if a.idx == int(f["passer"]) or a.stun > 0.0:
					continue
				if a.pos.distance_to(ball_pos) > 1.1:
					continue
				if f.get("cross", false) and u > 0.8 and _aerial_duel(a, f):
					return
				if a.team == team:
					_give_ball(a)
					return
				if tried.has(a.idx):
					continue
				tried[a.idx] = true
				var ic: float = Rules.intercept_chance(a.defending, float(f["speed"]), lofted and u <= 0.85)
				if int(f["passer"]) == user_idx:
					ic *= Rules.USER_PASS_INTERCEPT_MULT # tu pase: cortarlo cuesta más (video 2: 1 de 4)
				if rng.randf() < ic:
					sim_event.emit("intercept", {"team": a.team, "user_passer": int(f["passer"]) == user_idx})
					if rng.randf() < Rules.INTERCEPT_DEFLECT:
						# La toca pero no la controla: rebote (de acá salen muchos
						# laterales y córners).
						var fdir := ((f["e"] as Vector2) - (f["s"] as Vector2)).normalized()
						flight = {}
						last_touch_team = a.team
						last_kicker = a.idx
						last_kick_t = t
						loose_vel = fdir.rotated(rng.randf_range(-1.4, 1.4)) * float(f["speed"]) * rng.randf_range(0.4, 0.7)
						_act(a, "entrada", fdir * -1.0)
					else:
						_give_ball(a)
					return
		if u >= 1.0:
			var dir := (f["e"] as Vector2) - (f["c"] as Vector2)
			loose_vel = dir.normalized() * minf(float(f["speed"]) * 0.35, 4.0)
			ball_z = 0.0
			ball_vz = 2.2 if lofted else 0.0 # el pelotazo pica
			flight = {}
		return

	# Remate: bloqueos de jugadores de campo en la línea.
	if u > 0.1 and u < 0.85 and not f["over"]:
		var tried2: Dictionary = f["tried"]
		for a in agents:
			if a.team == team or a.role == "GK" or tried2.has(a.idx):
				continue
			if a.pos.distance_to(ball_pos) < 0.9:
				tried2[a.idx] = true
				if rng.randf() < Rules.block_chance(a.defending):
					flight = {}
					last_touch_team = a.team
					loose_vel = Vector2(rng.randf_range(-12, 12), 9.0 if team == 0 else -9.0)
					ball_z = 0.4
					ball_vz = rng.randf_range(1.5, 5.0)
					_act(a, "entrada", loose_vel)
					sim_event.emit("block", {"team": a.team})
					return
	if u >= 1.0:
		_resolve_shot(f)

## Duelo aéreo cuando baja el centro: atacantes y defensores a menos de
## 2,5 m del balón lo disputan (Rules.aerial_attacker_wins).
func _cross_duel(f: Dictionary) -> bool:
	var team: int = int(f["team"])
	var att: Agent = null
	var dfn: Agent = null
	for a in agents:
		if a.role == "GK" or a.stun > 0.0 or a.idx == int(f["passer"]):
			continue
		var d: float = a.pos.distance_to(ball_pos)
		if d > 2.5:
			continue
		if a.team == team and (att == null or d < att.pos.distance_to(ball_pos)):
			att = a
		elif a.team != team and (dfn == null or d < dfn.pos.distance_to(ball_pos)):
			dfn = a
	if att == null and dfn == null:
		return false
	var winner: Agent = att
	if att == null:
		winner = dfn
	elif dfn != null and rng.randf() >= Rules.aerial_attacker_wins(att.pace, dfn.defending):
		winner = dfn
	winner.pos = winner.pos.lerp(ball_pos, 0.6) # salta a buscarla
	return _aerial_duel(winner, f)

## Centro al área: el primero que llega por arriba cabecea. Atacante →
## cabezazo al arco (o la baja si es el usuario: decidís vos); defensor →
## despeje; arquero en el área chica → la agarra.
func _aerial_duel(a: Agent, f: Dictionary) -> bool:
	var team: int = int(f["team"])
	var an := _n(a.pos, team) # vista del equipo que centró
	if an.y > 18.0 or absf(an.x - 34.0) > 21.0:
		return false
	var gk := _goalkeeper(1 - team)
	if gk.pos.distance_to(ball_pos) < 2.2 and an.y < 6.5:
		sim_event.emit("save", {"team": gk.team, "user": false})
		if rng.randf() < Rules.GK_PUNCH_CROSS:
			# De puños: la saca lejos del área.
			flight = {}
			_act(gk, "punos", Vector2.ZERO)
			last_touch_team = gk.team
			last_kicker = gk.idx
			last_kick_t = t
			loose_vel = Vector2(rng.randf_range(-8, 8), (-12.0 if gk.team == 0 else 12.0))
			ball_z = 2.2
			ball_vz = 3.0
			return true
		_act(gk, "atajada", Vector2.ZERO)
		_give_ball(gk)
		return true
	if a.team == team:
		if a.idx == user_idx and not user_auto:
			if not user_first.is_empty() and t - float(user_first["t"]) < 2.5:
				flight = {}
				owner = a.idx
				_user_first_exec(a, 2.0)
				return true
			return false # te la bajás y decidís
		if rng.randf() < Rules.HEADER_ON_CROSS:
			flight = {}
			var aim: float = 34.0 + rng.randf_range(-GOAL_HALF + 0.6, GOAL_HALF - 0.6)
			_launch_shot(a, aim, 0.45, 0.0, true)
			return true
		return false
	# Defensor: despeja de cabeza.
	flight = {}
	_act(a, "cabezazo", Vector2(0, -1 if a.team == 0 else 1))
	last_touch_team = a.team
	last_kicker = a.idx
	last_kick_t = t
	loose_vel = Vector2(rng.randf_range(-7, 7), (-11.0 if a.team == 0 else 11.0))
	sim_event.emit("clearance", {"team": a.team})
	return true

func _resolve_shot(f: Dictionary) -> void:
	var team: int = int(f["team"])
	var e: Vector2 = f["e"]
	var z: float = float(f["z"])
	var gk := _goalkeeper(1 - team)
	var shooter: Agent = agents[int(f["passer"])]
	# Cómo llega la pelota a la línea (dirección de la curva al final y
	# velocidad): con esto sigue de largo — a la red, a la valla o al córner.
	var end_dir: Vector2 = ((f["e"] as Vector2) - (f["c"] as Vector2)).normalized()
	var end_spd: float = float(f["speed"])
	_net_vel = end_dir * minf(end_spd, 30.0) * 0.55
	flight = {}
	gk.dive_x = -1.0
	# Se tiró: queda tendido un momento antes de levantarse (como WSC).
	if gk.action == "estirada":
		gk.stun = maxf(gk.stun, Rules.GK_DOWN_SECS)
	var by_user: bool = shooter.idx == user_idx
	var dx: float = absf(e.x - 34.0)
	var side: float = signf(e.x - 34.0) if e.x != 34.0 else 1.0
	var into: float = 1.0 if team == 0 else -1.0 # hacia la cancha desde ese arco
	var rr: float = POST_R + BALL_HIT_R
	# --- PALO: según qué parte del palo toca, entra o sale.
	if z < GOAL_H + rr and absf(dx - GOAL_HALF) < rr:
		var inside: float = (GOAL_HALF - dx) / rr
		if rng.randf() < Rules.post_in_chance(inside):
			_score_goal(team, shooter, e.x - side * 0.6, minf(z, GOAL_H - 0.3), "palo_adentro")
			return
		sim_event.emit("miss", {"team": team, "user": by_user, "post": true, "over": false})
		ball_pos = Vector2(34.0 + side * GOAL_HALF, e.y + into * 0.4)
		loose_vel = Vector2(side * rng.randf_range(2.0, 7.0) * (1.0 if inside < 0.0 else -0.4), into * rng.randf_range(5.0, 11.0))
		ball_z = clampf(z, 0.2, GOAL_H)
		ball_vz = rng.randf_range(0.5, 2.5)
		last_touch_team = team
		_act(gk, "volada" if z > 1.8 else "estirada", Vector2(e.x - gk.pos.x, 0.0))
		return
	# --- TRAVESAÑO: pega abajo del larguero → pica adentro o afuera.
	if dx < GOAL_HALF and absf(z - GOAL_H) < rr:
		var below: float = (GOAL_H - z) / rr
		sim_event.emit("miss", {"team": team, "user": by_user, "post": true, "over": false, "bar": true})
		if below > 0.0 and rng.randf() < Rules.post_in_chance(below) * 0.85:
			_score_goal(team, shooter, e.x, 0.3, "travesano_adentro")
			return
		ball_pos = Vector2(e.x, e.y + into * 0.5)
		loose_vel = Vector2(rng.randf_range(-3.0, 3.0), into * rng.randf_range(4.0, 9.0))
		ball_z = GOAL_H
		ball_vz = -2.0 if below > 0.0 else 3.0
		last_touch_team = team
		_act(gk, "volada", Vector2(e.x - gk.pos.x, 0.0))
		return
	if f["over"] or dx > GOAL_HALF or z > GOAL_H:
		if z > GOAL_H and dx < GOAL_HALF + 1.0:
			_act(gk, "volada", Vector2(e.x - gk.pos.x, 0.0))
		sim_event.emit("miss", {"team": team, "user": by_user, "post": false, "over": z > GOAL_H})
		ball_z = z
		_dead_ball("goal_kick", 1 - team, _goal_kick_spot(1 - team, e.x), end_dir * end_spd * 0.8, 2.0 if z > GOAL_H else 0.5)
		return
	stats["on_target"][team] += 1
	if plays_mode and team == 0:
		play_result = "atajada"
	# --- ARQUERO: alcance de costado (ya se estiró hacia dive_x) y hacia
	# arriba. Al ángulo (alto y contra el palo) es lo más difícil.
	var reach: float = Rules.gk_reach(gk.keeping)
	var reach_up: float = Rules.gk_reach_high(gk.keeping)
	var d: float = absf(gk.pos.x - e.x)
	var ex: float = d / reach
	var ez: float = maxf(0.0, z - 1.7) / maxf(reach_up - 1.7, 0.1)
	var edge: float = sqrt(ex * ex + ez * ez)
	if bool(f.get("chip", false)) and absf(gk.pos.y - _goal_y(team)) > 3.5:
		edge = 2.0 # vaselina por encima del arquero adelantado
	if edge <= 1.0 and rng.randf() < Rules.save_chance(gk.keeping, float(f["speed"]), edge, float(f["curve"])):
		sim_event.emit("save", {"team": 1 - team, "user": by_user})
		if rng.randf() < Rules.catch_chance(gk.keeping, float(f["speed"]), edge, z):
			# La RETIENE: si la tiene cerca del cuerpo, atajada (con la pelota
			# dibujada en las manos); si se estiró, termina la estirada y la agarra.
			ball_pos = gk.pos
			if d < 0.9 and z < 1.9:
				_act(gk, "atajada", Vector2.ZERO)
			elif gk.action != "estirada":
				_act(gk, "volada" if z > 1.7 else "estirada", Vector2(e.x - gk.pos.x, 0.0))
			_give_ball(gk)
			return
		# La RECHAZA: arriba y al medio, de puños; si no, estirada/volada.
		if z > 1.6 and d < 1.0:
			_act(gk, "punos", Vector2.ZERO)
		elif gk.action != "estirada" or z > 1.7:
			_act(gk, "volada" if z > 1.7 else "estirada", Vector2(e.x - gk.pos.x, 0.0))
		# Rechazo: al costado o arriba. Al límite, muchos se van al córner.
		if edge > 0.75 and rng.randf() < 0.45:
			sim_event.emit("parry_corner", {"team": 1 - team})
			var corner := Vector2(0.5 if e.x < 34.0 else PITCH_W - 0.5, 0.5 if team == 0 else PITCH_L - 0.5)
			# La pelota sale por arriba/al costado del arco (no salta al córner).
			ball_z = clampf(z, 0.5, 2.4)
			_dead_ball("corner", team, corner, Vector2(side * rng.randf_range(4.0, 8.0), -into * rng.randf_range(3.0, 6.0)), 2.5)
			return
		ball_pos = Vector2(e.x, e.y + into * 1.2)
		loose_vel = Vector2(side * rng.randf_range(3.0, 9.0), into * rng.randf_range(3.0, 9.0))
		ball_z = clampf(z, 0.3, 2.2)
		ball_vz = rng.randf_range(1.0, 4.0)
		last_touch_team = 1 - team
		last_kicker = gk.idx
		last_kick_t = t
		return
	_score_goal(team, shooter, e.x, z, "remate")

## Gol: la pelota sigue hasta la red (cae adentro), festejo y saque del medio.
var _net_vel := Vector2.ZERO
var _goal_y_net: float = 0.0
## La pelota adentro del arco: rueda/vuela hasta el fondo de la red (que la
## frena), pica y queda ahí.
func _step_ball_in_net(dt: float) -> void:
	ball_pos += loose_vel * dt
	var into_net: float = -1.0 if _goal_y_net < 52.5 else 1.0
	if (ball_pos.y - _goal_y_net) * into_net > Rules.NET_DEPTH:
		ball_pos.y = _goal_y_net + into_net * Rules.NET_DEPTH
		loose_vel = Vector2(loose_vel.x * 0.3, -loose_vel.y * 0.12)
		ball_vz = minf(ball_vz, 0.0)
	var lim: float = GOAL_HALF - 0.25
	if absf(ball_pos.x - 34.0) > lim:
		ball_pos.x = 34.0 + signf(ball_pos.x - 34.0) * lim
		loose_vel.x *= -0.2
	ball_vz -= GRAVITY * dt
	ball_z += ball_vz * dt
	if ball_z <= 0.0:
		ball_z = 0.0
		ball_vz = -ball_vz * 0.4 if ball_vz < -1.5 else 0.0
	loose_vel *= exp(-(2.5 if ball_z < 0.05 else 0.6) * dt)

## PELOTA MUERTA: el remate afuera (o el rechazo al córner) sigue su vuelo
## un momento — pica, pega en la valla — y recién ahí se arma el saque.
var _dead: Dictionary = {}
func _dead_ball(kind: String, team: int, spot: Vector2, vel: Vector2, vz: float) -> void:
	phase = "dead"
	owner = -1
	flight = {}
	windup = {}
	loose_vel = vel
	ball_vz = vz
	_dead = {"kind": kind, "team": team, "spot": spot, "left": Rules.DEAD_BALL_SECS}

func _step_dead(dt: float) -> void:
	ball_pos += loose_vel * dt
	ball_vz -= GRAVITY * dt
	ball_z += ball_vz * dt
	if ball_z <= 0.0:
		ball_z = 0.0
		ball_vz = -ball_vz * 0.45 if ball_vz < -1.6 else 0.0
		loose_vel *= 0.85
	loose_vel *= exp(-(1.2 if ball_z < 0.05 else 0.15) * dt)
	# Vallas: la pelota rebota (no se va a la tribuna).
	if ball_pos.y < -4.8 or ball_pos.y > PITCH_L + 4.8:
		ball_pos.y = clampf(ball_pos.y, -4.8, PITCH_L + 4.8)
		loose_vel.y *= -0.3
	if ball_pos.x < -3.5 or ball_pos.x > PITCH_W + 3.5:
		ball_pos.x = clampf(ball_pos.x, -3.5, PITCH_W + 3.5)
		loose_vel.x *= -0.3
	# Los jugadores frenan y se quedan mirando.
	for a in agents:
		a.stun = maxf(a.stun - dt, 0.0)
		a.slide_t = 0.0
		a.vel = a.vel.move_toward(Vector2.ZERO, 9.0 * dt)
		a.pos += a.vel * dt
	_dead["left"] = float(_dead["left"]) - dt
	if float(_dead["left"]) <= 0.0:
		phase = "play"
		ball_z = 0.0
		ball_vz = 0.0
		loose_vel = Vector2.ZERO
		_start_set_piece(String(_dead["kind"]), int(_dead["team"]), _dead["spot"])

func _score_goal(team: int, shooter: Agent, x: float, z: float, kind: String) -> void:
	score[team] += 1
	var by_user: bool = shooter.idx == user_idx and shooter.team == team
	var assist_user: bool = false
	if by_user:
		stats["user_goals"] += 1
	elif _last_passer == user_idx and team == 0:
		stats["user_assists"] += 1
		assist_user = true
	var gy: float = _goal_y(team)
	# Sigue de largo hacia el fondo de la red (antes saltaba 1 m adentro y
	# se frenaba en seco).
	ball_pos = Vector2(clampf(x, 34.0 - GOAL_HALF + 0.4, 34.0 + GOAL_HALF - 0.4), gy + (-0.7 if team == 0 else 0.7))
	ball_z = clampf(z, 0.0, GOAL_H - 0.3)
	ball_vz = 0.0
	owner = -1
	flight = {}
	loose_vel = _net_vel if _net_vel != Vector2.ZERO else loose_vel * 0.5
	_net_vel = Vector2.ZERO
	_goal_y_net = gy
	windup = {}
	sim_event.emit("goal", {"team": team, "user": by_user, "assist_user": assist_user, "scorer": shooter.number,
		"x": x, "z": z, "kind": kind, "own_goal": shooter.team != team})
	_ref_do("pitazo")
	if plays_mode:
		play_result = "gol" if team == 0 else "gol_rival"
	_start_celebration(shooter if shooter.team == team else _nearest(team, ball_pos))
	restart_timer = 3.4
	pending_kickoff_team = 1 - team

func _check_out() -> bool:
	var p := ball_pos
	if p.x >= 0.0 and p.x <= PITCH_W and p.y >= 0.0 and p.y <= PITCH_L:
		return false
	if p.x < 0.0 or p.x > PITCH_W:
		# Lateral: saca el otro equipo, desde la línea.
		var spot := Vector2(0.2 if p.x < 0.0 else PITCH_W - 0.2, clampf(p.y, 1.0, PITCH_L - 1.0))
		_start_set_piece("throw", 1 - last_touch_team, spot)
		return true
	# Línea de fondo ENTRE LOS PALOS y bajo el travesaño: gol (un rebote, un
	# despeje que se mete en contra…).
	if absf(p.x - 34.0) < GOAL_HALF and ball_z < GOAL_H:
		var scorer_team: int = 0 if p.y < 0.0 else 1
		var who: Agent = agents[last_kicker] if last_kicker >= 0 else _nearest(scorer_team, p)
		_score_goal(scorer_team, who, p.x, ball_z, "rebote")
		return true
	# Línea de fondo: saque de arco o córner.
	var defending: int = 1 if p.y < 0.0 else 0
	if last_touch_team != defending:
		_start_set_piece("goal_kick", defending, _goal_kick_spot(defending, p.x))
	else:
		var corner := Vector2(0.5 if p.x < 34.0 else PITCH_W - 0.5, 0.5 if p.y < 0.0 else PITCH_L - 0.5)
		_start_set_piece("corner", 1 - defending, corner)
	return true

func _goal_kick_spot(team: int, x: float) -> Vector2:
	var y: float = PITCH_L - 5.5 if team == 0 else 5.5
	return Vector2(34.0 + (9.0 if x > 34.0 else -9.0), y)

# ------------------------------------------------------------ pelota parada
func _start_set_piece(kind: String, team: int, spot: Vector2, taker: Agent = null) -> void:
	phase = "set_piece"
	owner = -1
	flight = {}
	loose_vel = Vector2.ZERO
	ball_pos = spot
	ball_z = 0.0
	ball_vz = 0.0
	windup = {}
	user_first = {}
	last_touch_team = team
	user_dribble = false
	if taker == null:
		taker = _pick_taker(kind, team, spot)
	taker.action = "" # (por si venía de otro gesto en pausa, p. ej. un lateral)
	set_piece = {"kind": kind, "team": team, "spot": spot, "taker": taker.idx,
		"ready": false, "exec_t": 0.0, "t0": t}
	sim_event.emit("set_piece", {"kind": kind, "team": team, "user": taker.idx == user_idx})
	if kind in ["throw", "corner", "goal_kick"]:
		lines_flag_t[0 if spot.y < 52.5 else 1] = t
	if kind == "free_kick":
		_setup_wall(team, spot)

func _pick_taker(kind: String, team: int, spot: Vector2) -> Agent:
	if kind == "goal_kick":
		return _goalkeeper(team)
	var u := user()
	if kind == "throw" and team == u.team and u.pos.distance_to(spot) < 15.0:
		return u
	var best: Agent = null
	var bd: float = INF
	for a in agents:
		if a.team != team or a.role == "GK":
			continue
		if kind == "corner" and (a.role == "ST" or a.is_user):
			continue # los de arriba van al área
		var d: float = a.pos.distance_to(spot)
		if d < bd:
			bd = d
			best = a
	return best

## Devuelve qué pelota parada se estaba sacando ("" si ninguna) y vuelve
## a "play". La llaman todas las patadas: sacar = jugar.
func _end_set_piece() -> String:
	if phase != "set_piece":
		return ""
	wall.clear()
	var k: String = set_piece.get("kind", "")
	phase = "play"
	set_piece = {}
	return k

func _step_set_piece(dt: float) -> void:
	var sp := set_piece
	var taker: Agent = agents[int(sp["taker"])]
	var spot: Vector2 = sp["spot"]
	_update_targets()
	if not sp["ready"]:
		taker.target = spot
		taker.urgent = true
	else:
		taker.target = taker.pos
	if sp["kind"] == "corner":
		_corner_targets(int(sp["team"]))
	if sp["kind"] == "free_kick":
		_clear_around(spot, int(sp["team"]), taker)
		_wall_targets()
	if sp["kind"] == "penalty":
		_penalty_targets(int(sp["team"]), taker)
	_move_agents(dt)
	if not sp["ready"]:
		ball_pos = spot
		# Llegó a la pelota (o tardó demasiado: se acomoda).
		if (taker.pos.distance_to(spot) < 0.6 and _wall_ready()) or t - float(sp["t0"]) > 6.0:
			sp["ready"] = true
			taker.pos = spot
			owner = taker.idx
			owner_since = t
			taker.carry_target = spot
			var manual: bool = taker.idx == user_idx and not user_auto
			sp["exec_t"] = INF if manual else t + 1.0
			if sp["kind"] == "throw":
				_act(taker, "saque", Vector2(1.0 if spot.x < 34.0 else -1.0, 0.0))
				taker.action_t = 1e9 # pelota atrás de la cabeza hasta que saque
			if manual:
				stats["user_receptions"] += 1
				sim_event.emit("user_ball", {"set_piece": sp["kind"]})
		return
	ball_pos = taker.pos
	if t >= float(sp["exec_t"]) and windup.is_empty():
		sp["exec_t"] = INF
		_ai_set_piece_exec(String(sp["kind"]), taker)

func _ai_set_piece_exec(kind: String, a: Agent) -> void:
	match kind:
		"throw", "goal_kick":
			var max_d: float = 22.0 if kind == "throw" else 50.0
			var best: Agent = null
			var bs: float = -99.0
			for m in agents:
				if m.team != a.team or m.idx == a.idx or m.role == "GK":
					continue
				var d: float = a.pos.distance_to(m.pos)
				if d > max_d or d < 4.0:
					continue
				var open: float = 10.0
				for o in agents:
					if o.team != a.team:
						open = minf(open, o.pos.distance_to(m.pos))
				var sc: float = open * 0.12 + rng.randf() * 0.5 + (Rules.USER_PASS_BIAS if m.is_user else 0.0)
				if sc > bs:
					bs = sc
					best = m
			if best == null:
				best = _nearest(a.team, a.pos, false, a.idx)
			if kind == "throw":
				_kick_pass(a, best.pos, best.idx)
			else:
				_queue_pass(a, best.pos, best.idx)
		"corner":
			var cands: Array = []
			for m in agents:
				if m.team == a.team and m.idx != a.idx and m.role != "GK":
					var mn := _n(m.pos, a.team)
					if mn.y < 18.0 and absf(mn.x - 34.0) < 20.0:
						cands.append(m)
			var r: Agent = cands[rng.randi() % cands.size()] if not cands.is_empty() else _nearest(a.team, Vector2(34.0, _goal_y(a.team)), false, a.idx)
			_queue_pass(a, r.pos + Vector2(rng.randf_range(-1.5, 1.5), 0.0), r.idx)
		"penalty":
			var side: float = 1.0 if rng.randf() < 0.5 else -1.0
			var xs: float = 34.0 + side * rng.randf_range(GOAL_HALF * 0.35, GOAL_HALF - 0.7)
			_queue_shot(a, xs, rng.randf_range(0.5, 0.75), 0.0, [0.3, 0.3, 1.2, 2.1][rng.randi() % 4])
		"free_kick":
			var an := _n(a.pos, a.team)
			var gd: float = an.distance_to(Vector2(34, 0))
			if gd < 28.0 and rng.randf() < 0.55:
				var side: float = 1.0 if rng.randf() < 0.5 else -1.0
				_queue_shot(a, 34.0 + side * (GOAL_HALF - 0.7), 0.7, -side * 0.6 * (1.0 if a.team == 0 else -1.0), rng.randf_range(1.2, 2.4))
			else:
				_end_set_piece()
				_ai_decide(a)
		_:
			_end_set_piece()

## Tiro libre cerca del área: 3 del equipo que defiende forman la barrera a
## 9,15 m de la pelota, en la línea pelota-arco.
var wall: Array = [] # índices de los de la barrera (para la escena)
func _setup_wall(att: int, spot: Vector2) -> void:
	wall.clear()
	var goal := Vector2(34.0, _goal_y(att))
	if spot.distance_to(goal) > 32.0:
		return
	var dir := (goal - spot).normalized()
	var center := spot + dir * 9.15
	var perp := dir.orthogonal()
	var used: Array = []
	# 17-oct (Wilber: "la del tiro libre es con barrera"): con los sprites
	# agrandados, 3 jugadores a 0,9 m se veían como uno solo. Cerca del arco
	# van 4, separados lo justo para que se vean hombro con hombro.
	var n: int = 4 if spot.distance_to(goal) < 25.0 else 3
	for i in range(n):
		var p := center + perp * (float(i) - (float(n) - 1.0) * 0.5) * Rules.WALL_SPACING
		var best: Agent = null
		var bd: float = INF
		for a in agents:
			if a.team == att or a.role == "GK" or used.has(a.idx):
				continue
			var d: float = a.pos.distance_to(p)
			if d < bd:
				bd = d
				best = a
		if best != null:
			used.append(best.idx)
			wall.append({"idx": best.idx, "pos": p})

## Tiro libre: los rivales que no están en la barrera, a 9,15 m de la
## pelota; los compañeros le dejan lugar al que patea.
func _clear_around(spot: Vector2, att: int, taker: Agent, snap: bool = false) -> void:
	var in_wall: Dictionary = {}
	for w in wall:
		in_wall[int(w["idx"])] = true
	for a in agents:
		if a.idx == taker.idx or a.role == "GK" or in_wall.has(a.idx):
			continue
		var need: float = 9.5 if a.team != att else 4.5
		var off: Vector2 = a.target - spot
		if off.length() < need:
			var dirv: Vector2 = off.normalized() if off.length() > 0.1 else Vector2(1, 0).rotated(float(a.idx))
			a.target = _clamp_pitch(spot + dirv * need)
			a.urgent = true
		if snap and a.pos.distance_to(spot) < need:
			a.pos = a.target

func _wall_ready() -> bool:
	for w in wall:
		if (agents[int(w["idx"])] as Agent).pos.distance_to(w["pos"]) > 1.0:
			return false
	return true

func _wall_targets() -> void:
	for w in wall:
		var a: Agent = agents[int(w["idx"])]
		a.target = w["pos"]
		a.urgent = true

## Córner: los de arriba del que saca van al área; los defensores los marcan.
const CORNER_SPOTS := [Vector2(29, 7), Vector2(34, 5.5), Vector2(39, 8), Vector2(31, 12), Vector2(37, 12), Vector2(34, 16)]
func _corner_targets(att: int) -> void:
	var taker_idx: int = int(set_piece["taker"])
	var attackers: Array = []
	for role in ["ST", "MF", "DF"]:
		for a in agents:
			if a.team == att and a.role == role and a.idx != taker_idx:
				if role == "MF" and (a.base.x < 15.0 or a.base.x > 53.0):
					continue # los volantes abiertos se quedan afuera
				if role == "DF" and absf(a.base.x - 34.0) > 12.0:
					continue
				attackers.append(a)
	var markers: Array = []
	for a in agents:
		if a.team != att and a.role in ["DF", "MF"] and absf(a.base.x - 34.0) < 20.0:
			markers.append(a)
	for i in range(mini(attackers.size(), CORNER_SPOTS.size())):
		var a: Agent = attackers[i]
		var spn: Vector2 = CORNER_SPOTS[i]
		if not (a.idx == user_idx and (user_move_t > 0.0 or user_press_t > 0.0)):
			a.target = _n(spn, att)
			a.urgent = true
		if i < markers.size():
			var mk: Agent = markers[i]
			mk.target = _n(spn - Vector2(0.0, 1.2), att)
			mk.urgent = true

## Penal: todos afuera del área y de la medialuna; el arquero en la línea.
func _penalty_targets(att: int, taker: Agent) -> void:
	var k: int = 0
	for a in agents:
		if a.idx == taker.idx:
			continue
		if a.role == "GK":
			if a.team != att:
				a.target = _n(Vector2(34.0, 0.4), att)
				a.urgent = true
			continue
		var x: float = 10.0 + float(k % 10) * 5.3
		a.target = _n(Vector2(x, 20.5 + float(k % 3) * 1.5), att)
		a.urgent = true
		k += 1

## Gol: el que la metió festeja, los compañeros cercanos corren a abrazarlo,
## el resto vuelve caminando; el arquero que la recibió se lamenta.
func _start_celebration(scorer: Agent) -> void:
	phase = "goal"
	last_scorer = scorer.idx
	_act(scorer, "festejo")
	for a in agents:
		a.slide_t = 0.0
		a.urgent = false
		if a.idx == scorer.idx:
			a.target = a.pos
		elif a.team == scorer.team and a.role != "GK" and a.pos.distance_to(scorer.pos) < 35.0:
			a.target = scorer.pos + Vector2(rng.randf_range(-1.8, 1.8), rng.randf_range(-1.2, 1.2))
			a.urgent = true
		else:
			var b: Vector2 = a.base
			b.y = maxf(b.y, 56.0)
			a.target = _n(b, a.team)
	_act(_goalkeeper(1 - scorer.team), "lamento")

# ------------------------------------------------------------------- duelos
## ENTRADAS (17-oct, "mejora las entradas"): el defensor se tira (gesto)
## y el pie llega TACKLE_WINDUP después: si el portador ya se fue, la
## erra. Bien hecha, muchas veces la pelota queda suelta (no siempre es
## del que entra). Mal hecha o de atrás: FALTA (tiro libre o penal).
func _tackles() -> void:
	# Resolver las entradas lanzadas.
	for a in agents:
		if a.tackle_at < 0.0 or t < a.tackle_at:
			continue
		var vs: int = a.tackle_vs
		a.tackle_at = -1.0
		a.tackle_vs = -1
		if owner != vs or phase != "play":
			continue
		var c: Agent = agents[owner]
		if a.pos.distance_to(c.pos) > 1.8:
			a.stun = 0.35 # llegó tarde: pasó de largo
			if c.idx == user_idx:
				sim_event.emit("user_beat", {})
			continue
		var behind: bool = (c.pos - a.pos).dot(Vector2(0, -1 if c.team == 0 else 1)) > 0.6 * a.pos.distance_to(c.pos)
		if a.role != "GK" and rng.randf() < Rules.tackle_foul(a.defending, behind):
			_foul(a, c, behind)
			return
		if a.role == "GK":
			if rng.randf() < Rules.gk_smother(a.keeping, c.dribbling):
				if c.idx == user_idx:
					stats["user_dribbles_lost"] += 1
				ball_pos = a.pos
				_give_ball(a)
				_act(a, "atajada", Vector2.ZERO)
				sim_event.emit("save", {"team": a.team, "user": c.idx == user_idx, "smother": true})
			else:
				a.stun = 1.0
				if c.idx == user_idx:
					sim_event.emit("user_beat", {})
			return
		if rng.randf() < Rules.tackle_success(a.defending, c.dribbling):
			if c.idx == user_idx:
				stats["user_dribbles_lost"] += 1
			if a.idx == user_idx:
				stats["user_tackles_won"] += 1
			c.stun = 0.5
			windup = {}
			if rng.randf() < Rules.TACKLE_KEEP:
				_give_ball(a)
			else:
				owner = -1
				last_touch_team = a.team
				last_kicker = c.idx
				last_kick_t = t
				loose_vel = ((c.pos - a.pos).normalized().rotated(rng.randf_range(-1.0, 1.0))) * rng.randf_range(4.0, 8.0)
				if (c.pos.x < 9.0 or c.pos.x > PITCH_W - 9.0) and rng.randf() < 0.6:
					loose_vel.x = (-1.0 if c.pos.x < 34.0 else 1.0) * rng.randf_range(7.0, 10.0)
			if rng.randf() < 0.3:
				_act(c, "caida", c.pos - a.pos)
			sim_event.emit("tackle", {"team": a.team, "user_lost": c.idx == user_idx, "user_won": a.idx == user_idx})
			return
		a.stun = 0.6
		_act(a, "cuerpeo", c.pos - a.pos)
		if c.idx == user_idx:
			sim_event.emit("user_beat", {})
	# Lanzar entradas nuevas.
	var protect: float = Rules.RECEIVE_PROTECT_USER if owner == user_idx else 0.45
	if owner < 0 or t - owner_since < protect or phase != "play":
		return
	var c2: Agent = agents[owner]
	if c2.role == "GK" and c2.action in ["hold", "atajada"]:
		return # en las manos del arquero no se la quita nadie
	for a in agents:
		if a.team == c2.team or a.stun > 0.0 or a.tackle_cd > 0.0 or a.tackle_at >= 0.0:
			continue
		var d: float = a.pos.distance_to(c2.pos)
		if a.role == "GK":
			# Achique: se tira a los pies del atacante en su área.
			if d < 1.9 and _n(c2.pos, a.team).y > 87.0:
				a.tackle_cd = 1.5
				a.tackle_at = t + Rules.TACKLE_WINDUP
				a.tackle_vs = c2.idx
				_act(a, "achique", c2.pos - a.pos)
			continue
		if d > 1.9:
			# PLANCHAZO DE LA IA: el que corre atrás de uno que se le escapa se
			# tira a la pelota (de 2,5 a 4,5 m, nunca dentro de su área).
			if not a.is_user and a.slide_t <= 0.0 and d > 2.5 and d < 4.5 and c2.vel.length() > 4.0 \
					and _n(c2.pos, a.team).y < 84.0 and rng.randf() < Rules.AI_SLIDE_CHANCE:
				var lead2: float = clampf(d / Rules.SLIDE_SPEED, 0.0, 0.45)
				_start_slide(a, ball_pos + c2.vel * lead2 - a.pos)
			continue
		if a.is_user and not user_auto and user_press_t <= 0.0:
			continue # tu jugador entra solo si se lo pediste (tocando al rival)
		a.tackle_cd = 1.1
		a.tackle_at = t + Rules.TACKLE_WINDUP
		a.tackle_vs = c2.idx
		a.target = c2.pos
		_act(a, "entrada", c2.pos - a.pos)

## Contacto de los planchazos (tuyo o de la IA). Gana el que llega a la
## PELOTA: si la toca antes que al rival es limpio casi siempre; si llega
## al cuerpo (o por detrás), falta.
func _slide_contact() -> void:
	if owner < 0 or phase != "play":
		return
	var c: Agent = agents[owner]
	for a in agents:
		if a.slide_t <= 0.0 or a.slide_done or a.team == c.team:
			continue
		var db: float = a.pos.distance_to(ball_pos)
		var dc: float = a.pos.distance_to(c.pos)
		if dc > 1.7 and db > 1.3:
			continue
		a.slide_done = true
		var ball_first: bool = db < dc
		# "Por detrás": te deslizás en la misma dirección en la que él ataca.
		var behind: bool = a.slide_dir.dot(Vector2(0, 1 if c.team == 1 else -1)) > 0.5
		var r: float = rng.randf()
		var p_clean: float = Rules.slide_clean(a.defending, c.dribbling) + (Rules.SLIDE_BALL_FIRST_BONUS if ball_first else 0.0)
		var p_foul: float = Rules.slide_foul(behind) * (0.5 if ball_first else 1.0)
		if a.idx != user_idx and c.idx == user_idx:
			p_clean -= Rules.SLIDE_VS_USER_MALUS # justicia: a vos te cuesta un poco más sacártela
		if r < p_clean:
			if a.idx == user_idx:
				stats["user_slides_won"] += 1
			if c.idx == user_idx:
				stats["user_dribbles_lost"] += 1
			owner = -1
			windup = {}
			last_touch_team = a.team
			last_kicker = c.idx
			last_kick_t = t
			loose_vel = a.slide_dir * rng.randf_range(5.0, 8.0)
			if (c.pos.x < 9.0 or c.pos.x > PITCH_W - 9.0) and rng.randf() < 0.5:
				loose_vel.x = (-1.0 if c.pos.x < 34.0 else 1.0) * 8.0
			c.stun = 0.6
			_act(c, "caida", c.pos - a.pos)
			if a.idx == user_idx:
				sim_event.emit("slide_ok", {})
			else:
				sim_event.emit("tackle", {"team": a.team, "user_lost": c.idx == user_idx, "user_won": false, "slide": true})
		elif r < p_clean + p_foul:
			_foul(a, c, behind)
		elif a.idx == user_idx:
			sim_event.emit("slide_miss", {})
		elif c.idx == user_idx:
			sim_event.emit("user_beat", {})
		return

func _foul_by_user(victim: Agent, behind: bool) -> void:
	_foul(user(), victim, behind)

## Falta de `fouler` sobre `victim`: tarjeta (al usuario le cuenta en sus
## números; expulsado = fin de TU partido), protestas, y tiro libre — o
## PENAL si fue dentro del área de `fouler`.
func _foul(fouler: Agent, victim: Agent, behind: bool) -> void:
	var by_user: bool = fouler.idx == user_idx
	if by_user:
		stats["user_fouls"] += 1
	windup = {}
	_act(victim, "caida", victim.pos - fouler.pos)
	var card: String = ""
	var r: float = rng.randf()
	if r < Rules.red_direct_chance(behind) * (1.0 if by_user else 0.3):
		card = "red"
	elif r < Rules.red_direct_chance(behind) + Rules.yellow_chance(behind) * (1.0 if by_user else 0.5):
		fouler.yellows += 1
		if by_user:
			stats["user_yellows"] += 1
		card = "yellow" if fouler.yellows < 2 else "red2"
	if not by_user and card != "yellow":
		card = "" # prototipo: la IA no se queda con uno menos
	var vn: Vector2 = _n(victim.pos, victim.team)
	var penalty: bool = vn.y < 16.5 and absf(vn.x - 34.0) < 20.16
	# LEY DE LA VENTAJA: si el que recibió la falta sigue con la pelota y
	# su equipo ataca, el árbitro deja seguir (la tarjeta igual corre).
	if not penalty and owner == victim.idx and vn.y < 70.0 and rng.randf() < Rules.ADVANTAGE_CHANCE:
		victim.action = ""
		victim.stun = 0.0
		sim_event.emit("advantage", {"team": victim.team, "card": card, "by_user": by_user})
		if card == "yellow":
			_ref_do("amarilla")
		return
	sim_event.emit("foul", {"card": card, "by_user": by_user, "on_user": victim.idx == user_idx, "penalty": penalty})
	_ref_do("roja" if card in ["red", "red2"] else ("amarilla" if card == "yellow" else "pitazo"))
	var n: int = 0
	for m in agents:
		if m.team == victim.team and m.idx != victim.idx and m.role != "GK" and m.pos.distance_to(victim.pos) < 14.0 and n < 2:
			_act(m, "protesta", fouler.pos - m.pos)
			n += 1
	if penalty:
		start_penalty(victim.team)
	else:
		var taker: Agent = victim
		# Tiro libre de tu equipo cerca del área: lo patea VOS.
		if victim.team == 0 and vn.y < 34.0 and not user_sent_off:
			taker = user()
		_start_set_piece("free_kick", victim.team, _clamp_pitch(victim.pos), taker)
	if by_user and (card == "red" or card == "red2"):
		user_sent_off = true
		finished = true
		sim_event.emit("sent_off", {})
		sim_event.emit("full_time", {})

## PENAL para `team`: patea el usuario si es de su equipo (y no está
## expulsado); el resto afuera del área; el arquero en la línea.
func start_penalty(team: int) -> void:
	var spot: Vector2 = _n(Vector2(34.0, 11.0), team)
	var taker: Agent = user() if team == 0 and not user_sent_off else null
	if taker == null:
		var bs: int = -1
		for a in agents:
			if a.team == team and a.role != "GK" and a.shooting > bs:
				bs = a.shooting
				taker = a
	_start_set_piece("penalty", team, spot, taker)

# ------------------------------------------------------------ saques/tiempos
func _reset_positions() -> void:
	for a in agents:
		var b: Vector2 = a.base
		b.y = maxf(b.y, 56.0)
		a.pos = _n(b, a.team)
		a.target = a.pos
		a.vel = Vector2.ZERO
		a.stun = 0.0
		a.dive_x = -1.0

func _kickoff(team: int) -> void:
	pending_kickoff_team = -1
	flight = {}
	# Saca el delantero más central (antes el índice 9 fijo: con 4-5-1 era el extremo).
	var kicker: Agent = null
	for a in agents:
		if a.team == team and a.role == "ST" and (kicker == null or absf(a.base.x - 34.0) < absf(kicker.base.x - 34.0)):
			kicker = a
	if kicker == null:
		kicker = agents[team * 11 + 10]
	kicker.pos = Vector2(34.0, 52.5)
	ball_pos = kicker.pos
	_give_ball(kicker)
	kicker.decide_cd = 0.8
	sim_event.emit("kickoff", {"team": team})

# ------------------------------------------------------------- árbitros
func _ref_do(action: String) -> void:
	ref_action = action
	ref_action_t = t

func _move_officials(dt: float) -> void:
	# El árbitro va en diagonal, unos metros al costado y atrás de la
	# pelota, sin pisarle el lugar a nadie.
	var goal := ball_pos + Vector2(-9.0 if ball_pos.x > 34.0 else 9.0, 7.0)
	goal = Vector2(clampf(goal.x, 6.0, PITCH_W - 6.0), clampf(goal.y, 8.0, PITCH_L - 8.0))
	var to := goal - ref_pos
	var sp: float = 6.5 if to.length() > 4.0 else to.length() * 1.5
	ref_vel = to.normalized() * sp if to.length() > 0.3 else Vector2.ZERO
	ref_pos += ref_vel * dt
	# Jueces de línea: a la altura del penúltimo defensor de su mitad.
	# Izquierdo = mitad de arriba (donde ataca el equipo 0); derecho = abajo.
	var l0: float = clampf(_offside_line_n(0), 2.0, 52.5)
	var l1: float = clampf(PITCH_L - _offside_line_n(1), 52.5, PITCH_L - 2.0)
	lines_y[0] = move_toward(float(lines_y[0]), l0, 7.0 * dt)
	lines_y[1] = move_toward(float(lines_y[1]), l1, 7.0 * dt)

# ------------------------------------------------------------ modo jugadas
## Arma la cancha para la jugada `kind` (vista del equipo 0, que ataca hacia
## y = 0) y la arranca. Ver ProtoDirector.LABELS.
func setup_play(kind: String, minute_i: int) -> void:
	plays_mode = true
	play_kind = kind
	play_minute = minute_i
	play_t0 = t
	play_over = false
	play_result = ""
	_play_lost_t = 0.0
	_play_won_t = 0.0
	phase = "play"
	restart_timer = 0.0
	pending_kickoff_team = -1
	owner = -1
	flight = {}
	windup = {}
	user_first = {}
	user_dribble = false
	user_dribble_until = -1.0
	user_move_t = 0.0
	user_press_t = 0.0
	loose_vel = Vector2.ZERO
	ball_z = 0.0
	ball_vz = 0.0
	wall.clear()
	set_piece = {}
	for a in agents:
		a.stun = 0.0
		a.vel = Vector2.ZERO
		a.slide_t = 0.0
		a.tackle_at = -1.0
		a.run_until = -1.0
		a.action = ""
		a.dive_x = -1.0
	var u := user()
	match kind:
		"corner":
			_place_for(Vector2(60.0, 8.0), 0)
			_start_set_piece("corner", 0, Vector2(PITCH_W - 0.5, 0.5))
			_snap_to_targets()
			return
		"tiro_libre":
			var spot := Vector2(rng.randf_range(22.0, 46.0), rng.randf_range(19.0, 27.0))
			_place_for(spot, 0)
			_snap_to_targets()
			u.pos = spot + Vector2(0, 2.0)
			_start_set_piece("free_kick", 0, spot, u)
			for w in wall:
				var wa: Agent = agents[int(w["idx"])]
				wa.pos = w["pos"]
				wa.vel = Vector2.ZERO
			_clear_around(spot, 0, u, true)
			return
		"penal":
			_place_for(Vector2(34.0, 11.0), 0)
			_snap_to_targets()
			start_penalty(0)
			return
		"defensa":
			var bp := Vector2(rng.randf_range(12.0, 56.0), rng.randf_range(70.0, 80.0))
			_place_for(bp, 1)
			_snap_to_targets()
			var c := _nearest(1, bp)
			c.pos = bp
			ball_pos = bp
			_give_ball(c)
			return
	# Jugadas abiertas: el balón lo tiene un compañero (o vos) en la zona.
	var bp2 := Vector2(rng.randf_range(20.0, 48.0), rng.randf_range(44.0, 56.0))
	if kind == "contra":
		bp2 = Vector2(rng.randf_range(18.0, 50.0), rng.randf_range(56.0, 64.0))
	elif kind == "centro":
		bp2 = Vector2(6.0 if rng.randf() < 0.5 else 62.0, rng.randf_range(24.0, 32.0))
	_place_for(bp2, 0)
	_snap_to_targets()
	if kind == "contra":
		# El rival estaba arriba: su defensa quedó mal parada (2-3 contra 2).
		for a in agents:
			if a.team == 1 and a.role in ["DF", "MF"]:
				a.pos.y = clampf(a.pos.y + rng.randf_range(10.0, 18.0), 0.0, 90.0)
				if a.role == "MF":
					a.pos.y = maxf(a.pos.y, bp2.y + 2.0)
	var carrier: Agent = null
	if kind == "centro":
		carrier = _nearest(0, bp2, false, user_idx)
		u.pos = Vector2(34.0 + rng.randf_range(-6.0, 6.0), rng.randf_range(12.0, 18.0))
	elif rng.randf() < Rules.PLAY_START_USER:
		carrier = u # la jugada arranca en tus pies (como Score! Hero)
	else:
		carrier = _nearest(0, bp2, false, user_idx)
	carrier.pos = bp2
	ball_pos = bp2
	_give_ball(carrier)
	carrier.decide_cd = 0.9
	if carrier != u and kind != "centro":
		# Si la tiene un compañero, te la busca enseguida: la jugada es TUYA.
		user_call_until = t + 3.0

## Objetivos "de partido" como si la pelota estuviera en `bp` y la tuviera `team`.
func _place_for(bp: Vector2, team: int) -> void:
	ball_pos = bp
	last_touch_team = team
	owner = -1
	_update_targets_for(team)

func _update_targets_for(poss: int) -> void:
	var off_line := [_offside_line_n(0), _offside_line_n(1)]
	for a in agents:
		var bn := _n(ball_pos, a.team)
		var tn: Vector2
		if a.role == "GK":
			tn = _gk_spot(a, bn, poss == a.team)
		elif poss == a.team:
			tn = _attack_spot(a, bn, float(off_line[a.team]))
		else:
			tn = _defend_spot(a, bn)
		a.target = _n(tn, a.team)

func _snap_to_targets() -> void:
	for a in agents:
		a.pos = a.target + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
		a.vel = Vector2.ZERO
		a.mark_idx = -1
	ref_pos = ball_pos + Vector2(8.0, 6.0)

## ¿Se definió la jugada? (gol: lo marca _score_goal y termina tras el festejo)
func _check_play_end(dt: float) -> void:
	if restart_timer > 0.0 or play_over:
		return
	var el: float = t - play_t0
	var attack: bool = play_kind != "defensa"
	if phase == "set_piece":
		var k: String = String(set_piece.get("kind", ""))
		# Laterales y saques de arco cortan la jugada; córner, tiro libre y
		# penal la siguen (son parte de la jugada).
		if k in ["throw", "goal_kick"] and float(set_piece.get("t0", 0.0)) > play_t0 + 0.05:
			_end_play("afuera" if k == "throw" else ("atajada" if play_result == "atajada" else "afuera"))
		return
	var pt: int = _poss_team()
	if owner >= 0:
		var c: Agent = agents[owner]
		if c.team == 1:
			_play_lost_t += dt
			_play_won_t = 0.0
		else:
			_play_won_t += dt
			_play_lost_t = 0.0
		if c.role == "GK" and c.team == 1 and attack and t - owner_since > 0.8:
			_end_play("atajada")
			return
	var near_user: bool = owner >= 0 and (agents[owner] as Agent).team == 1 and (agents[owner] as Agent).pos.distance_to(user().pos) < 9.0
	if attack and _play_lost_t > (Rules.PLAY_LOST_SECS_NEAR if near_user else 2.2):
		_end_play("perdida")
	elif not attack and (_play_won_t > 2.0 or (pt == 0 and _n(ball_pos, 1).y < 45.0)):
		_end_play("recuperada")
	elif attack and pt == 1 and ball_pos.y > 70.0:
		_end_play("perdida")
	elif el > Rules.PLAY_MAX_SECS:
		_end_play("tiempo")

func _end_play(result: String) -> void:
	play_over = true
	play_result = result
	windup = {}
	sim_event.emit("play_end", {"result": result, "kind": play_kind})

func _end_half() -> void:
	if half == 1:
		half = 2
		clock_t = 0.0
		owner = -1
		flight = {}
		restart_timer = 2.0
		pending_kickoff_team = 1
		sim_event.emit("half_time", {})
		_ref_do("pitazo")
	else:
		finished = true
		_ref_do("pitazo")
		sim_event.emit("full_time", {})
