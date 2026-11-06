extends Node2D
## Prototipo match_v2 — escena jugable. Dibuja la cancha vista desde arriba
## con los 22 jugadores (ProtoSim) y traduce los gestos a órdenes SOLO
## para tu jugador:
##   Con el balón (el tiempo casi se congela):
##     · tocar a un compañero          -> pase al pie
##     · deslizar (desde cualquier lado) -> remate si apunta al arco,
##                                         pase al hueco si no. Largo =
##                                         fuerza, curvar el trazo = rosca
##     · mantener el dedo (en cualquier lado) -> conducir hacia el dedo
##     · trazo corto y rápido desde tu jugador -> gambeta en esa dirección
##   Sin el balón:
##     · tocar/arrastrar en la cancha  -> moverte ahí (desmarque)
##     · tocar a tu jugador            -> pedirla
##     · tocar al rival con el balón   -> ir a presionarlo (entrada de pie)
##     · trazo rápido con el rival cerca -> planchazo
## Abrir con F6 en el editor. No toca saves ni autoloads.
##
## Jugadores = los sprites pixel del juego (assets/pixelplayer/anim, vía
## Avatar.anim_frames con tintes por equipo). Cámara que sigue la jugada
## (estilo WSC) + radar arriba a la derecha con la cancha entera.

const Sim = preload("res://prototypes/match_v2/ProtoSim.gd")
const Rules = preload("res://prototypes/match_v2/ProtoRules.gd")
const Stadium = preload("res://prototypes/match_v2/ProtoStadium.gd")
const Director = preload("res://prototypes/match_v2/ProtoDirector.gd")
## PARTIDO POR JUGADAS (17-oct): true = 8 momentos sueltos (ProtoDirector);
## false = el partido corrido de antes (sigue andando, lo usan las pruebas).
const PLAYS_MODE := true
const RESULT_TEXT := {"gol": "¡GOL!", "gol_rival": "Gol del rival", "atajada": "Atajó el arquero",
	"afuera": "Se fue afuera", "perdida": "Perdieron la pelota", "recuperada": "¡Recuperada!", "tiempo": "Se diluyó la jugada"}

const COL_BG := Color(0.07, 0.09, 0.08)
const COL_GRASS_A := Color(0.20, 0.47, 0.24)
const COL_GRASS_B := Color(0.18, 0.43, 0.22)
const COL_LINE := Color(1, 1, 1, 0.8)
const COL_HOME := Color(0.17, 0.42, 0.88)
const COL_AWAY := Color(0.85, 0.27, 0.23)
const COL_GK_HOME := Color(0.25, 0.75, 0.45)
const COL_GK_AWAY := Color(0.93, 0.76, 0.26)
const COL_USER := Color(1.0, 0.84, 0.25)
const COL_SHOT := Color(1.0, 0.35, 0.3)
const COL_PASS := Color(0.45, 0.9, 1.0)

## CÁMARA (17-oct, Wilber: "la cámara, cancha y todo eso que teníamos, los
## sprites y balón más grandecitos"): más cerca que antes (40 m de ancho) y
## con la cancha apenas INCLINADA como en el juego (TILT: el fondo se
## comprime; lo que está parado — jugadores, arcos — no). Se acerca un poco
## más cuando tenés la pelota y se abre cuando el juego va rápido lejos.
const VIEW_W_BALL := 24.0    # metros de ancho en pantalla: con la pelota
const VIEW_W_PLAY := 25.5    #   jugando normal
const VIEW_W_FAST := 28.5    #   juego acelerado lejos tuyo
const TILT := 0.84
const PX_PER_S := 1.0 / 10.5 # escala del pixel art por px/metro (≈1,65 con 33 m; 17-oct: "un poco más grandes")
const BALL_R_M := 0.5        # radio del balón dibujado (metros; agrandado a propósito)
## Alturas (pelota en el aire, travesaño): px por metro de ALTO, medidos
## contra el sprite (un jugador "mide" 1,8 m = 40 px de cuerpo × escala).
const BODY_ART_PX := 40.0
## Gestos que arrancan en un cuadro más adelante: así el pie le pega a la
## pelota justo cuando sale (ProtoRules.KICK_WINDUP / SHOT_WINDUP). El
## remate y el pase llegan al contacto en el cuadro ~6; la entrada en el 5.
const ACTION_START := {"pase": 3, "remate": 3, "entrada": 2, "atajada": 2, "saque_largo": 1, "lanzar": 2}
const TURN_SECS := 0.06      # cada giro de 45° del cuerpo tarda esto (no "salta" de dirección)
const FEET_Y := 56.5 / 68.0  # dónde están los pies en el cuadro de 68 px
const KICK_FPS := 16.0       # cuadros/s (de simulación) de los gestos
const STRIDE_M := 0.55       # metros por cuadro de carrera (la de 6 cuadros)
const STRIDE_RUN8 := 0.42    # carrera de 8 cuadros
const STRIDE_JOG := 0.3      # trote de 8 cuadros
const JOG_MAX := 3.4         # (m/s) más lento que esto: trota
const LEVANTA_SECS := 0.55   # dura el gesto de levantarse
const GK_ALERT_M := 32.0     # pelota a menos de esto de su arco: arquero en alerta
const ACTION_SECS := {"pase": 0.45, "remate": 0.5, "barrida": 0.7, "entrada": 0.5, "regate": 0.6, "caida": 1.0,
	"atajada": 0.9, "estirada": 1.5, "cabezazo": 0.55, "saque": 0.75, "festejo": 3.4, "lamento": 3.4, "protesta": 1.6,
	"control": 0.5, "volea": 0.5, "chilena": 0.7, "cuerpeo": 0.55, "volada": 0.9, "hold": 9.0, "saque_largo": 0.6,
	"lanzar": 0.65, "punos": 0.6, "achique": 1.0}
## Sufijos a probar por dirección (el primero que exista): el arte nuevo
## tiene norte (sin sufijo), sur, este/oeste (espejo) y a veces diagonales.
const DIR_TRY := {
	"north": [""], "north-east": ["_ne", "_e", ""], "east": ["_e"], "south-east": ["_se", "_s", "_e"],
	"south": ["_s"], "south-west": ["_sw", "_s", "_w"], "west": ["_w"], "north-west": ["_nw", "_w", ""],
}
const REF_ID := "negro"
const REF_FPS := 10.0
## Gestos que se repiten mientras duran (el resto queda en el último cuadro).
const LOOP_ACTIONS := ["festejo", "lamento", "protesta", "hold"]
const USER_CELEBS := ["celeb_salto", "celeb_avion", "celeb_rodillas", "celeb_grito", "celeb_pistolas", "celeb_brazos_abiertos", "celeb_corazon", "celeb_surfero"]
const DIRS8 := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
const DIR_SUFFIX := {"north": "", "north-east": "_ne", "east": "_e", "south-east": "_se", "south": "_s", "south-west": "_sw", "west": "_w", "north-west": "_nw"}
const SKINS := ["#f4d6c0", "#eec1a3", "#d9a577", "#b57e56", "#8a5a3b", "#5f3a26"]
const BOOTS := ["#2b2b30", "#e8b923", "#3ee03a", "#ff4fa3", "#2e7bff", "#ff6a1a", "#d81e2a"]

const TAP_PX := 24.0
## Un trazo más corto que esto (y más largo que un toque) se toma como TOQUE
## en su punto final: así un toque "sucio" nunca sale como remate.
const KICK_MIN_PX := 45.0
const SWIPE_FULL_PX := 300.0

var sim
var cur_scale: float = 1.0
var origin := Vector2.ZERO
var s: float = 7.5 # px por metro (horizontal; el vertical es s * TILT)
var px: float = 1.5 # escala de los sprites
var view_w: float = VIEW_W_PLAY
var stadium
var ball_tex: Texture2D
var ball_spin: float = 0.0
var ball_prev := Vector2.ZERO
var trail: Array = []
var director
## REPETICIÓN DEL GOL: fotos de la jugada (últimos segundos) y su reproducción.
var rec: Array = []
var replay_pending: Dictionary = {}
var replaying: bool = false
var replay_t: float = 0.0
var replay_from: float = 0.0
var replay_to: float = 0.0
var replay_goal_t: float = 0.0
var replay_net_done: bool = false
var lbl_replay: Label
## Ayudas contextuales: cuántas veces se mostró cada una (las primeras 3).
var hints_seen: Dictionary = {}
var hint_key: String = ""
var fps_t: float = 0.0
var interlude_t: float = 0.0 # > 0: tarjeta entre jugadas (la sim está quieta)
var lbl_card: Label
var card_panel: PanelContainer

## px de pantalla por metro de altura.
func hpx() -> float:
	return BODY_ART_PX * px / 1.8
var font: Font
var cam := Vector2(34, 60)
var vis: Array = [] # por agente: {cfg, cache, stride, last, dir}
var user_celeb: String = "celeb_salto"
var btn_skill: Button

# Gesto
var touching: bool = false
var g_start := Vector2.ZERO
var g_start_ms: int = 0
var g_points: PackedVector2Array = []
var g_mode: String = "" # "", "move"

# HUD
var lbl_score: Label
var lbl_pace: Label
var lbl_hint: Label
var lbl_toast: Label
var end_panel: PanelContainer
var toast_tween: Tween

func _ready() -> void:
	font = ThemeDB.fallback_font
	_load_hints()
	_build_hud()
	_new_match()

func _new_match() -> void:
	# Formaciones al azar (las del juego real) hasta que la carrera las mande.
	var forms: Array = Sim.FORMATION_BASES.keys()
	var home_f: String = forms[randi() % forms.size()]
	var away_f: String = forms[randi() % forms.size()]
	sim = Sim.new("ST", 0, 70, 70, home_f, away_f)
	sim.sim_event.connect(_on_sim_event)
	_toast("%s  vs  %s" % [home_f, away_f], COL_USER, 1.6)
	cur_scale = 1.0
	cam = sim.ball_pos
	view_w = VIEW_W_PLAY
	stadium = Stadium.new(self, randi(), COL_HOME, COL_AWAY)
	ball_tex = BallDesign.texture(randi() % BallDesign.count())
	_setup_sprites()
	if end_panel:
		end_panel.visible = false
	if PLAYS_MODE:
		sim.plays_mode = true
		director = Director.new(randi(), "ST")
		_next_play("")

# ------------------------------------------------------------ repetición
## Una foto por cuadro de lo que hace falta para redibujar la jugada.
func _record() -> void:
	if sim.restart_timer > 0.0 and sim.phase == "goal" and sim.t - replay_goal_t > 1.0:
		return # durante el festejo no hace falta seguir grabando
	var ag: Array = []
	for a in sim.agents:
		ag.append([a.pos, a.vel, a.action, a.action_t, a.action_dir, a.stun])
	rec.append({"t": sim.t, "ag": ag, "ball": sim.ball_pos, "h": sim.ball_height(), "ref": sim.ref_pos})
	while rec.size() > 2 and float(rec[0]["t"]) < sim.t - 5.0:
		rec.pop_front()

func _start_replay() -> void:
	replaying = true
	replay_from = maxf(float(replay_pending["t"]) - 3.2, float(rec[0]["t"]) if not rec.is_empty() else 0.0)
	replay_to = float(replay_pending["t"]) + 0.5
	replay_goal_t = float(replay_pending["t"])
	replay_net_done = false
	replay_t = replay_from
	replay_pending = {}
	lbl_replay.visible = true
	touching = false

func _step_replay(delta: float) -> void:
	replay_t += delta * Rules.REPLAY_SPEED
	if replay_t >= replay_to or rec.size() < 2:
		replaying = false
		lbl_replay.visible = false
		return
	# Foto más cercana (interpolando posiciones entre dos).
	var i: int = 0
	while i < rec.size() - 2 and float(rec[i + 1]["t"]) < replay_t:
		i += 1
	var a0: Dictionary = rec[i]
	var a1: Dictionary = rec[i + 1]
	var k: float = clampf((replay_t - float(a0["t"])) / maxf(float(a1["t"]) - float(a0["t"]), 0.0001), 0.0, 1.0)
	for j in range(sim.agents.size()):
		var ag = sim.agents[j]
		var s0: Array = a0["ag"][j]
		var s1: Array = a1["ag"][j]
		ag.pos = (s0[0] as Vector2).lerp(s1[0], k)
		ag.vel = s0[1]
		ag.action = s0[2]
		ag.action_t = s0[3]
		ag.action_dir = s0[4]
		ag.stun = s0[5]
	sim.t = lerpf(float(a0["t"]), float(a1["t"]), k)
	sim.ball_pos = (a0["ball"] as Vector2).lerp(a1["ball"], k)
	sim.flight = {}
	sim.ball_z = lerpf(float(a0["h"]), float(a1["h"]), k)
	sim.owner = -1
	sim.ref_pos = a0["ref"]
	if not replay_net_done and replay_t >= replay_goal_t:
		replay_net_done = true
		stadium.goal_net(sim.ball_pos.x, sim.ball_pos.y < 52.5)
	_layout()
	cam = cam.lerp(sim.ball_pos, minf(1.0, delta * 4.0))
	view_w = lerpf(view_w, VIEW_W_BALL - 2.0, minf(1.0, delta * 2.0))
	_update_strides(delta)
	stadium.tick(delta)
	queue_redraw()

## Termina una jugada (o arranca el partido): tarjeta con lo que pasó, el
## minuto y la jugada que sigue; después de unos segundos, a jugar.
func _next_play(prev_result: String) -> void:
	if prev_result != "":
		director.results.append({"kind": sim.play_kind, "min": sim.play_minute, "result": prev_result})
	if not director.has_next():
		sim.finished = true
		card_panel.visible = false
		_show_end()
		return
	var nx: Dictionary = director.next()
	var txt: String = ""
	if prev_result != "":
		txt += String(RESULT_TEXT.get(prev_result, prev_result)) + "\n\n"
	for team in nx.get("bg", []):
		sim.score[int(team)] += 1
		txt += ("Mientras tanto: ¡gol de tu equipo!" if int(team) == 0 else "Mientras tanto: gol del rival") + "\n"
	if int(nx["min"]) > 45 and (director.idx == 0 or int(director.plays[director.idx - 1]["min"]) <= 45):
		txt += "— Segundo tiempo —\n"
	# Sin "jugada X de N" (17-oct, Wilber): no se anticipa cuántas quedan.
	txt += "%d'\n%s" % [int(nx["min"]), Director.label(String(nx["kind"]))]
	lbl_card.text = txt
	card_panel.visible = true
	interlude_t = 2.2 if prev_result != "" else 1.6
	sim.setup_play(String(nx["kind"]), int(nx["min"]))
	cam = sim.ball_pos
	view_w = VIEW_W_FAST + 6.0 # se acerca solo al arrancar (paneo de entrada)
	rec.clear()
	trail.clear()
	for a in sim.agents:
		vis[a.idx]["last"] = a.pos
	_had_ball = false # jugada nueva: no es que la hayas perdido
	lost_flash = 0.0

# ------------------------------------------------------------------ layout
var _view_c := Vector2.ZERO
func _layout() -> void:
	var vs := get_viewport_rect().size
	s = vs.x / view_w
	px = s * PX_PER_S
	_view_c = Vector2(vs.x * 0.5, vs.y * 0.52)
	origin = w2s(Vector2.ZERO)

## Solo para las capturas de prueba: cámara fija en ese punto (x < -900 = libre).
var cam_lock := Vector2(-999, -999)
func _update_camera(delta: float) -> void:
	var vs := get_viewport_rect().size
	if cam_lock.x > -900.0:
		cam = cam_lock
		return
	var goal: Vector2 = sim.ball_pos
	var want_w: float = VIEW_W_PLAY
	if sim.user_has_ball():
		var u = sim.user()
		goal = u.pos
		want_w = VIEW_W_BALL
		if u.pos.y < 45.0:
			goal.y = lerpf(u.pos.y, 0.0, 0.35) # que entre el arco para apuntar
	elif not sim.flight.is_empty() and int(sim.flight.get("passer", -1)) == sim.user_idx and String(sim.flight["kind"]) == "pass":
		# TU PASE: la cámara acompaña la pelota hasta el que la recibe.
		goal = sim.ball_pos.lerp(sim.flight["e"], 0.35)
		want_w = VIEW_W_PLAY
	else:
		# Un poco hacia vos, como en el juego: ves la jugada y dónde estás.
		goal = goal.lerp(sim.user().pos, 0.2)
		if cur_scale > 1.5:
			want_w = VIEW_W_FAST
	view_w = lerpf(view_w, want_w, minf(1.0, delta * 1.6))
	var half := Vector2(vs.x * 0.5 / s, vs.y * 0.5 / (s * TILT))
	# Se puede ver un poco de estadio (vallas, bancos, tribuna), no más.
	goal.x = clampf(goal.x, half.x - 9.0, Sim.PITCH_W - half.x + 7.0) # a la izquierda se ven bancos y túnel
	goal.y = clampf(goal.y, half.y - 17.0, Sim.PITCH_L - half.y + 13.0)
	cam = cam.lerp(goal, minf(1.0, delta * 3.0))

func w2s(p: Vector2) -> Vector2:
	return _view_c + Vector2((p.x - cam.x) * s, (p.y - cam.y) * s * TILT)

func s2w(q: Vector2) -> Vector2:
	var d: Vector2 = q - _view_c
	return Vector2(d.x / s, d.y / (s * TILT)) + cam

## Un trazo en pantalla → dirección en la cancha (deshace la inclinación).
func _sdir(d: Vector2) -> Vector2:
	return Vector2(d.x, d.y / TILT)

# ------------------------------------------------------------------- loop
func _process(delta: float) -> void:
	_layout()
	fps_t += delta
	if fps_t >= 5.0:
		fps_t = 0.0
		print("PROTO_FPS %d" % Engine.get_frames_per_second()) # se lee con adb logcat
	if replaying:
		_step_replay(delta)
		return
	if interlude_t > 0.0:
		interlude_t -= delta
		_update_camera(delta)
		stadium.tick(delta)
		_update_hud()
		queue_redraw()
		if interlude_t <= 0.0:
			card_panel.visible = false
		return
	if PLAYS_MODE and sim.play_over and not sim.finished:
		if not replay_pending.is_empty():
			_start_replay()
			return
		_next_play(sim.play_result)
		return
	_update_camera(delta)
	if tap_mate >= 0 and Time.get_ticks_msec() - tap_ms >= Rules.DOUBLE_TAP_MS:
		if sim.user_has_ball():
			sim.user_pass_to(tap_mate)
		tap_mate = -1
	_gesture_tick()
	var target: float = sim.desired_time_scale()
	var k: float = 1.0 - exp(-(14.0 if target < cur_scale else 9.0) * delta)
	cur_scale = lerpf(cur_scale, target, k)
	# Arrancar a correr con la pelota: el tiempo vuelve de golpe (antes
	# tardaba ~0,3 s en salir de la cámara lenta y se sentía pesado).
	if sim.user_has_ball() and sim.user_dribble and target >= 1.0:
		cur_scale = maxf(cur_scale, 0.85)
	var remaining: float = minf(delta, 0.1) * cur_scale
	while remaining > 0.0:
		var st: float = minf(remaining, 1.0 / 60.0)
		sim.step(st)
		remaining -= st
	_record()
	_check_user_lost()
	_update_strides(delta)
	stadium.tick(delta)
	stadium.score_text = "%d - %d" % [sim.score[0], sim.score[1]]
	_update_hud()
	queue_redraw()

# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if replaying and event is InputEventMouseButton and event.pressed:
		replay_t = replay_to # tocar = saltar la repetición
		return
	if sim.finished or interlude_t > 0.0 or replaying:
		touching = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_gesture_begin(event.position)
		elif touching:
			_gesture_end(event.position)
	elif event is InputEventMouseMotion and touching:
		_gesture_move(event.position)

## Clasificación del gesto (17-oct): con el balón, TOCAR = avanzar hasta ahí
## (o pase si tocás a un compañero); un trazo = patada (gambeta si es corto y
## sale de tu jugador). Ya no hay "mantener para conducir": se confundía con
## el tiro.
const SKILL_MAX_PX := 95.0
const SLIDE_MAX_MS := 280
const SLIDE_RANGE_M := 9.0

var g_on_user: bool = false
## Primer toque a un compañero esperando el segundo (doble toque = pase alto).
var tap_mate: int = -1
var tap_ms: int = 0

func _gesture_begin(p: Vector2) -> void:
	touching = true
	g_start = p
	g_start_ms = Time.get_ticks_msec()
	g_points = PackedVector2Array([p])
	g_on_user = _hit(sim.user(), p, 1.2)
	g_mode = ""

## Corre en cada cuadro mientras el dedo está apoyado: sin la pelota,
## arrastrar = ir moviéndote con el dedo.
func _gesture_tick() -> void:
	if not touching:
		return
	if g_mode == "move" and not sim.user_has_ball():
		sim.user_move_to(s2w(get_viewport().get_mouse_position()))

func _gesture_move(p: Vector2) -> void:
	if g_points.size() == 0 or g_points[g_points.size() - 1].distance_to(p) > 3.0:
		g_points.append(p)
	var held_ms: int = Time.get_ticks_msec() - g_start_ms
	var moved: float = p.distance_to(g_start)
	if g_mode == "" and not sim.user_has_ball() and not sim.ball_incoming_to_user() and moved > 12.0 and held_ms >= SLIDE_MAX_MS:
		g_mode = "move"

func _gesture_end(p: Vector2) -> void:
	touching = false
	var length: float = p.distance_to(g_start)
	var held_ms: int = Time.get_ticks_msec() - g_start_ms
	var w := s2w(p)
	var dir := p - g_start
	if g_mode == "move":
		pass
	elif sim.user_has_ball():
		# TOCAR = avanzar hasta ahí (17-oct, Wilber: "que sea tocar a donde
		# quieres ir en vez de arrastrar, para que no se confunda con el tiro").
		# Tocar a un compañero = pase; tocarte a vos = frenar.
		if length < KICK_MIN_PX and not (g_on_user and length >= TAP_PX):
			var mate = _agent_at_screen(p, 0, true)
			if mate != null:
				# Un toque = pase al pie; DOS toques seguidos = pase alto (WSC).
				# El primero espera DOUBLE_TAP_MS por si llega el segundo.
				var now: int = Time.get_ticks_msec()
				if tap_mate == mate.idx and now - tap_ms < Rules.DOUBLE_TAP_MS:
					tap_mate = -1
					sim.user_pass_to(mate.idx, true)
					_toast("¡Por arriba!", COL_USER, 0.5)
				else:
					tap_mate = mate.idx
					tap_ms = now
			elif _hit(sim.user(), p, 0.8):
				sim.user_dribble_end()
			else:
				sim.user_run_to(w)
		elif g_on_user and length < SKILL_MAX_PX:
			sim.user_skill(_sdir(dir))
		else:
			var power: float = clampf(length / SWIPE_FULL_PX, 0.15, 1.0)
			var soft: bool = held_ms > Rules.SOFT_SWIPE_MS
			var kind: String = sim.user_kick(_sdir(dir), power, _swipe_curve(), soft)
			if kind != "":
				_buzz(25)
			if kind == "chip":
				_toast("¡Vaselina!", COL_USER, 0.6)
	elif sim.ball_incoming_to_user() and length >= KICK_MIN_PX:
		# Viene el pase: el trazo queda armado y se patea DE PRIMERA al recibir
		# (de cabeza si llega alta).
		sim.user_first_time(_sdir(dir), clampf(length / SWIPE_FULL_PX, 0.15, 1.0), _swipe_curve())
		_toast("¡De primera!", COL_USER, 0.5)
	else:
		var c = sim.carrier()
		var rival_near: bool = c != null and c.team == 1 and c.pos.distance_to(sim.user().pos) < SLIDE_RANGE_M
		if length < TAP_PX:
			if _hit(sim.user(), p, 1.0):
				sim.user_call_for_ball()
			elif c != null and c.team == 1 and _hit(c, p, 1.2):
				sim.user_press()
				_toast("¡A presionar!", COL_USER, 0.6)
			else:
				sim.user_move_to(w)
		elif rival_near and held_ms <= SLIDE_MAX_MS:
			sim.user_slide(_sdir(dir))
		else:
			sim.user_move_to(w)
	g_points = PackedVector2Array()
	g_mode = ""

## Rosca: cuánto se aparta el trazo de la línea recta, con signo, relativo
## al largo. Mismo sentido de "perpendicular" que ProtoSim._launch_shot.
func _swipe_curve() -> float:
	if g_points.size() < 3:
		return 0.0
	var a: Vector2 = g_points[0]
	var b: Vector2 = g_points[g_points.size() - 1]
	var d := b - a
	var l: float = d.length()
	if l < 1.0:
		return 0.0
	var perp := Vector2(-d.y, d.x) / l
	var dev: float = 0.0
	for q in g_points:
		var v: float = (q - a).dot(perp)
		if absf(v) > absf(dev):
			dev = v
	return clampf(dev / l * 4.0, -1.0, 1.0)

## ¿El toque `p` (pantalla) cae sobre el cuerpo de `a`? Se mide contra el
## centro del SPRITE (no los pies): con jugadores grandes uno toca el torso.
func _hit(a, p: Vector2, k: float) -> bool:
	return p.distance_to(_body_center(a)) < 40.0 * px * 0.55 * k

func _body_center(a) -> Vector2:
	return w2s(a.pos) - Vector2(0, 40.0 * px * 0.45)

## El jugador de `team` más cerca del toque (pantalla), si alguno quedó a
## menos de ~un cuerpo.
func _agent_at_screen(p: Vector2, team: int, exclude_user: bool):
	var best = null
	var bd: float = 40.0 * px * 0.8
	for a in sim.agents:
		if a.team != team or (exclude_user and a.is_user):
			continue
		var d: float = p.distance_to(_body_center(a))
		if d < bd:
			bd = d
			best = a
	return best

func _agent_at(w: Vector2, team: int, radius: float, exclude_user: bool):
	var best = null
	var bd: float = radius
	for a in sim.agents:
		if a.team != team or (exclude_user and a.is_user):
			continue
		var d: float = a.pos.distance_to(w)
		if d < bd:
			bd = d
			best = a
	return best

# ----------------------------------------------------------------- dibujo
func _draw() -> void:
	var vs := get_viewport_rect().size
	stadium.draw_ground()
	stadium.draw_goal(0)
	stadium.draw_night()
	# Oscurecer en cámara lenta: los jugadores resaltan.
	var slow: float = clampf((0.45 - cur_scale) / 0.35, 0.0, 1.0)
	if slow > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, (0.08 if stadium.night else 0.14) * slow))
	_draw_world(slow)
	_draw_gesture()
	# Franjas detrás del marcador y de las ayudas (el texto tapaba jugadores).
	draw_rect(Rect2(0, 0, vs.x, 90), Color(0, 0, 0, 0.5))
	if lbl_hint.text != "" or btn_skill.visible:
		draw_rect(Rect2(0, vs.y - 104, vs.x, 104), Color(0, 0, 0, 0.55))
	if replaying:
		draw_rect(Rect2(0, 0, vs.x, 70), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(0, vs.y - 70, vs.x, 70), Color(0, 0, 0, 0.85))
	_draw_radar()

## Tintes de cada jugador: camiseta = color del equipo, cara/pelo al azar
## pero fijos (Avatar.random_config con semilla por índice).
func _setup_sprites() -> void:
	vis.clear()
	for a in sim.agents:
		var kit: Color
		if a.role == "GK":
			kit = COL_GK_HOME if a.team == 0 else COL_GK_AWAY
		else:
			kit = COL_HOME if a.team == 0 else COL_AWAY
		var look: Dictionary = Avatar.random_config(7919 * (a.idx + 1) + 13)
		var cfg := {
			"tint_clothing": kit.to_html(false),
			"tint_shorts": "#1f2026" if kit.get_luminance() > 0.42 else "#e9e9ec",
			"tint_base": SKINS[(a.idx * 5 + 1) % SKINS.size()],
			"tint_hair": String(look.get("tint_hair", "#2b2320")),
			"tint_boots": BOOTS[(a.idx * 3) % BOOTS.size()],
		}
		# PELO (17-oct, Wilber: "no se mantienen los pelos del jugador"): el
		# peinado ahora existe de frente, de espaldas y de costado
		# (tools/hair_views.py) y Avatar.anim_frames pega el que corresponde en
		# cada cuadro — el mismo peinado en todas las acciones.
		for k in ["hair", "face", "nose", "rasgo"]:
			if String(look.get(k, "")) != "":
				cfg[k] = String(look[k])
		vis.append({"cfg": cfg, "cache": {}, "stride": 0.0, "last": a.pos, "dir": "north" if a.team == 0 else "south"})

## Pasos al ritmo de lo que avanza + GIRO SUAVE (17-oct, "fluidez"): antes
## el cuerpo saltaba a la dirección nueva en un cuadro (de norte a sur de
## golpe); ahora gira de a 45° (TURN_SECS cada uno), como en el juego.
func _update_strides(delta: float) -> void:
	for a in sim.agents:
		var v: Dictionary = vis[a.idx]
		var mv: Vector2 = a.pos - (v["last"] as Vector2)
		v["last"] = a.pos
		if mv.length() < 2.0:
			v["stride"] = float(v["stride"]) + mv.length()
		var want: String
		if bool(v.get("moving", false)):
			want = _dir8(a.vel)
		elif a.role == "GK":
			want = "north" if a.team == 0 else "south"
		else:
			want = _dir8(sim.ball_pos - a.pos)
		var cur: int = DIRS8.find(String(v["dir"]))
		var tgt: int = DIRS8.find(want)
		if cur == tgt:
			v["turn"] = 0.0
			continue
		if mv.length() > 2.0:
			v["dir"] = want # reubicado de golpe (saque, reinicio): sin giro
			continue
		v["turn"] = float(v.get("turn", 0.0)) + delta
		if float(v["turn"]) >= TURN_SECS:
			v["turn"] = 0.0
			var diff: int = posmod(tgt - cur, 8)
			cur = posmod(cur + (1 if diff <= 4 else -1), 8)
			v["dir"] = DIRS8[cur]

func _in_wall(idx: int) -> bool:
	for w in sim.wall:
		if int(w["idx"]) == idx:
			return true
	return false

static func _dir8(v: Vector2) -> String:
	if v.length() < 0.001:
		return "north"
	var i: int = posmod(int(roundf(v.angle() / (PI / 4.0))), 8)
	return DIRS8[i]

func _frames(i: int, names: Array) -> Array:
	var v: Dictionary = vis[i]
	var cache: Dictionary = v["cache"]
	for n in names:
		if cache.has(n):
			if not (cache[n] as Array).is_empty():
				v["last_anim"] = n
				return cache[n]
			continue
		var f: Array = Avatar.anim_frames(v["cfg"], n) if Avatar.has_anim(n) else []
		cache[n] = f
		if not f.is_empty():
			v["last_anim"] = n
			return f
	return []

## Animaciones candidatas para el gesto actual de `a`, de la más exacta
## (su dirección) a la de reserva.
func _action_names(a) -> Array:
	var keeper: bool = a.role == "GK"
	var d8: String = _dir8(a.action_dir) if a.action_dir.length() > 0.01 else String(vis[a.idx]["dir"])
	match a.action:
		"festejo":
			return [user_celeb, "pitch_festejo"] if a.is_user else ["pitch_festejo"]
		"lamento":
			return ["lamento"]
		"protesta":
			return ["pitch_protesta"]
		"saque":
			return ["pitch_saque_e" if a.action_dir.x >= 0.0 else "pitch_saque_w", "pitch_pase"]
	if keeper:
		var back: String = "_n" if a.team == 0 else ""
		match a.action:
			"estirada":
				var side: String = "izq" if a.action_dir.x < 0.0 else "der"
				return ["gk_estirada_" + side + back, "gk_estirada_" + side]
			"volada":
				return ["gk_volada" + back, "gk_volada", "gk_salto"]
			"atajada":
				return ["gk_atajada" + back, "gk_atajada"]
			"hold":
				return ["gk_hold" + back, "gk_hold"]
			"lanzar":
				return ["gk_lanzar" + back, "gk_lanzar", "gk_saque_largo" + back]
			"punos":
				return ["gk_punos" + back, "gk_punos", "gk_volada" + back]
			"achique":
				return ["gk_achique" + back, "gk_achique", "gk_estirada_der" + back]
			"saque_largo":
				return ["gk_saque_largo" + back, "gk_saque_largo", "pitch_remate" + ("" if a.team == 0 else "_s")]
	var out: Array = []
	for sfx in DIR_TRY[d8]:
		out.append("pitch_" + a.action + sfx)
	out.append("pitch_" + a.action)
	return out

## Qué cuadro mostrar: gesto reciente > carrera > quieto.
func _agent_texture(a) -> Texture2D:
	var v: Dictionary = vis[a.idx]
	v["idle"] = false
	var since: float = sim.t - float(a.action_t)
	var keeper: bool = a.role == "GK"
	# Arquero CAMINANDO con la pelota en las manos: piernas de caminar (el
	# balón lo dibuja _draw_agent en el pecho); quieto, la pose de sostenerla.
	var gk_walk: bool = keeper and a.action == "hold" and a.vel.length() > 0.5
	v["gk_carry"] = gk_walk
	# LEVANTARSE (17-oct, animación nueva): después de caerse o tirarse al
	# piso, se para con el gesto (antes aparecía de pie de golpe).
	if a.action in ["caida", "barrida"] and not keeper and a.vel.length() < 2.0:
		var down: float = float(ACTION_SECS[a.action])
		if since >= down and since < down + LEVANTA_SECS:
			var d8l: String = _dir8(a.action_dir) if a.action_dir.length() > 0.01 else String(v["dir"])
			var ln: Array = []
			for sfx in DIR_TRY[d8l]:
				ln.append("pitch_levanta" + sfx)
			ln.append("pitch_levanta")
			var lf: Array = _frames(a.idx, ln)
			if not lf.is_empty():
				return lf[mini(int((since - down) / LEVANTA_SECS * lf.size()), lf.size() - 1)]
	if a.action != "" and since < float(ACTION_SECS.get(a.action, 0.5)) and not gk_walk:
		var names: Array = _action_names(a)
		var f: Array = _frames(a.idx, names)
		if not f.is_empty():
			var fi_: int = maxi(0, int(since * (10.0 if a.action in LOOP_ACTIONS else KICK_FPS))) + int(ACTION_START.get(a.action, 0))
			return f[fi_ % f.size()] if a.action in LOOP_ACTIONS else f[mini(fi_, f.size() - 1)]
	var dir: String = v["dir"]
	# HISTÉRESIS (17-oct, Wilber: "animaciones más fluidas"): al llegar a su
	# lugar la velocidad oscila alrededor del umbral y el sprite saltaba
	# entre correr y quieto (y el arquero entre su paso lateral y correr)
	# cuadro a cuadro. Ahora cada estado tiene un umbral para entrar y otro
	# para salir.
	var spd: float = a.vel.length()
	v["moving"] = spd > (0.3 if bool(v.get("moving", false)) else 0.9)
	var side_k: float = 1.0 if bool(v.get("gk_side", false)) else 1.6
	v["gk_side"] = keeper and spd > 0.3 and absf(a.vel.x) > absf(a.vel.y) * side_k
	if bool(v["gk_side"]):
		var steps: Array = _frames(a.idx, ["gk_paso_" + ("der" if a.vel.x > 0.0 else "izq") + ("_n" if a.team == 0 else "")])
		if not steps.is_empty():
			return steps[int(float(v["stride"]) / 0.35) % steps.size()]
	# Barrera de tiro libre: firmes, tapándose.
	if sim.phase == "set_piece" and _in_wall(a.idx):
		var wf: Array = _frames(a.idx, ["pitch_barrera" + ("_s" if a.team == 1 else ""), "pitch_barrera"])
		if not wf.is_empty():
			return wf[int(sim.t * 8.0) % wf.size()]
	if bool(v["moving"]):
		# TROTE (lento) o CARRERA de 8 cuadros (17-oct, animaciones nuevas):
		# antes todo lo que se movía usaba la carrera de 6 cuadros, que a poca
		# velocidad parecía flotar. Histéresis para no saltar entre las dos.
		var jog_lim: float = JOG_MAX + (0.4 if bool(v.get("jog", false)) else -0.4)
		v["jog"] = spd < jog_lim and not keeper
		var names2: Array = (["pitch_trote_" + dir] if bool(v["jog"]) else ["pitch_run8_" + dir]) + ["pitch_run_" + dir]
		# Con la pelota: la animación de conducción (pasos cortos, mirando el
		# balón) solo al trote; a toda carrera, la de correr (17-oct, Wilber:
		# "va como caminando en vez de correr").
		var drib_lim: float = Rules.CARRY_RUN_ANIM_SPEED + (0.5 if bool(v.get("drib", false)) else -0.5)
		v["drib"] = a.idx == sim.owner and spd < drib_lim
		if bool(v["drib"]):
			names2.push_front("pitch_drib_" + dir)
		var fr: Array = _frames(a.idx, names2)
		if not fr.is_empty():
			var step_m: float = STRIDE_M
			var used: String = String(v.get("last_anim", ""))
			if used.begins_with("pitch_trote"):
				step_m = STRIDE_JOG
			elif used.begins_with("pitch_run8"):
				step_m = STRIDE_RUN8
			return fr[int(float(v["stride"]) / step_m) % fr.size()]
	var idle: Array = ["gk_idle_" + dir, "gk_idle_south"] if keeper else ["pitch_idle_" + dir]
	v["idle"] = true
	# ARQUERO ALERTA: con la pelota cerca de su arco rebota en el lugar.
	if keeper and sim.ball_pos.distance_to(Vector2(34.0, 105.0 if a.team == 0 else 0.0)) < GK_ALERT_M:
		var al: Array = _frames(a.idx, ["gk_alerta" + ("_n" if a.team == 0 else ""), "gk_alerta"])
		if not al.is_empty():
			v["idle"] = false
			return al[int(Time.get_ticks_msec() / 1000.0 * 9.0 + a.idx) % al.size()]
	var fi: Array = _frames(a.idx, idle)
	return fi[0] if not fi.is_empty() else null

## UN SOLO PASE ordenado por profundidad (más abajo en la cancha = más cerca
## = tapa): jugadores, árbitro, jueces, objetos del estadio, tu arco y la
## pelota por el piso. La pelota en el aire va encima de todo.
func _draw_world(slow: float) -> void:
	var items: Array = []
	for a in sim.agents:
		items.append([a.pos.y, "agent", a])
	for it in stadium.items():
		items.append([float(it["y"]), "stadium", it])
	items.append([sim.ref_pos.y, "ref", null])
	for i in range(2):
		items.append([float(sim.lines_y[i]), "line", i])
	var h: float = sim.ball_height()
	if h < 0.6:
		items.append([sim.ball_pos.y + 0.05, "ball", null])
	items.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	var has_ball: bool = sim.user_has_ball()
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
	var c = sim.carrier()
	for it in items:
		match String(it[1]):
			"agent":
				_draw_agent(it[2], slow, has_ball, pulse, c)
			"stadium":
				stadium.draw_item(it[2])
			"ref":
				_draw_ref()
			"line":
				_draw_linesman(int(it[2]))
			"ball":
				_draw_ball()
	if h >= 0.6:
		_draw_ball()

func _draw_agent(a, slow: float, has_ball: bool, pulse: float, c) -> void:
	var vs := get_viewport_rect().size
	var feet := w2s(a.pos)
	if feet.x < -90 or feet.x > vs.x + 90 or feet.y < -40 or feet.y > vs.y + 140:
		return
	var rw: float = 0.9 * s
	# Aros bajo los pies: vos (dorado), compañeros tocables (celeste),
	# rival con balón (blanco).
	if a.is_user:
		var ring_col: Color = COL_USER.lerp(COL_AWAY, lost_flash) if lost_flash > 0.0 else COL_USER
		if a.idx == sim.owner:
			# Con la pelota: aro relleno (se nota de un vistazo que es tuya).
			_ellipse_fill(feet, rw * 1.25, rw * 0.5, Color(COL_USER, 0.28))
		_ellipse(feet, rw * (1.25 + pulse * 0.12 + lost_flash * 0.5), rw * (0.5 + lost_flash * 0.2), ring_col, 3.0 + lost_flash * 2.0)
	elif has_ball and a.team == 0:
		_ellipse(feet, rw * 1.1, rw * 0.45, Color(COL_PASS, 0.45 + 0.4 * slow), 2.0)
	elif c != null and a.idx == c.idx and c.team == 1:
		_ellipse(feet, rw * 1.1, rw * 0.45, Color(1, 1, 1, 0.7), 2.0)
	_ellipse_fill(feet + Vector2(1, 1), rw * 0.8, rw * 0.3, Color(0, 0, 0, 0.3))
	var tex := _agent_texture(a)
	if tex == null:
		draw_circle(feet, rw * 0.6, COL_HOME if a.team == 0 else COL_AWAY)
		return
	var sz: Vector2 = tex.get_size() * px
	var tl := feet - Vector2(sz.x * 0.5, sz.y * FEET_Y)
	var mod: Color = Color(0.75, 0.75, 0.75) if a.stun > 0.0 else Color.WHITE
	# Arquero de espaldas con la pelota: va DELANTE de él (tapada por el
	# cuerpo); asoma bajo el brazo, del lado de la mano.
	if bool(vis[a.idx].get("gk_carry", false)) and ball_tex != null and a.team == 0:
		_draw_held_ball(feet - Vector2(-1.0 * s, 0.85 * hpx()))
	# RESPIRA (como en el juego): parado, torso y cabeza bajan 1 píxel al
	# soltar el aire, cada uno a su tiempo.
	var v: Dictionary = vis[a.idx]
	var breath: float = fmod(Time.get_ticks_msec() / 1000.0 + float(a.idx) * 0.37, 2.4) / 2.4
	if bool(v.get("idle", false)) and breath > 0.55 and cur_scale > 0.3:
		var th: Vector2 = tex.get_size()
		var cut: float = floorf(th.y * 0.56)
		draw_texture_rect_region(tex, Rect2(tl + Vector2(0, cut * px), Vector2(sz.x, (th.y - cut) * px)), Rect2(0, cut, th.x, th.y - cut), mod)
		draw_texture_rect_region(tex, Rect2(tl + Vector2(0, px), Vector2(sz.x, cut * px)), Rect2(0, 0, th.x, cut), mod)
	else:
		draw_texture_rect(tex, Rect2(tl, sz), false, mod)
	if bool(v.get("gk_carry", false)) and ball_tex != null and a.team == 1:
		_draw_held_ball(feet - Vector2(0, 1.0 * hpx()))
	if a.is_user:
		var tw: float = font.get_string_size("TÚ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2(feet.x - tw * 0.5, tl.y + 10.0 * px * 0.7), "TÚ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COL_USER)

## Árbitro (assets/referee/<id>, sin teñir) y jueces de línea (por fuera
## de las bandas). `behind`: se dibujan ANTES que los jugadores (así nadie
## queda tapado por el árbitro de forma rara; en una vista de arriba alcanza).
func _draw_ref() -> void:
	var rf: Array = []
	var since: float = sim.t - sim.ref_action_t
	if sim.ref_action != "" and since < 0.9:
		rf = Referee.frames(REF_ID, sim.ref_action)
		if not rf.is_empty():
			_draw_official_tex(sim.ref_pos, rf[mini(int(since * REF_FPS), rf.size() - 1)], px, 1.0)
			return
	if sim.ref_vel.length() > 0.5:
		var d4: String = "east" if absf(sim.ref_vel.x) > absf(sim.ref_vel.y) and sim.ref_vel.x > 0 else ("west" if absf(sim.ref_vel.x) > absf(sim.ref_vel.y) else ("south" if sim.ref_vel.y > 0 else "north"))
		rf = Referee.frames(REF_ID, "run_" + d4)
		if not rf.is_empty():
			_draw_official_tex(sim.ref_pos, rf[int(sim.t * REF_FPS) % rf.size()], px, 1.0)
	else:
		rf = Referee.frames(REF_ID, "idle")
		if not rf.is_empty():
			_draw_official_tex(sim.ref_pos, rf[0], px, 1.0)

## Jueces de línea (68 px, pies a 57/68): banderín arriba en un lateral.
func _draw_linesman(i: int) -> void:
	var lp := Vector2(-1.6 if i == 0 else Sim.PITCH_W + 1.6, float(sim.lines_y[i]))
	var fs: float = sim.t - float(sim.lines_flag_t[i])
	var lf: Array = Referee.frames("linesman", "marca" if fs < 1.6 else "espera")
	if not lf.is_empty():
		var idx: int = mini(int(fs * REF_FPS), lf.size() - 1) if fs < 1.6 else int(sim.t * 4.0) % lf.size()
		_draw_official_tex(lp, lf[idx], px, FEET_Y)

func _draw_official_tex(p: Vector2, tex: Texture2D, px_scale: float, feet_ratio: float) -> void:
	var feet := w2s(p)
	var vs := get_viewport_rect().size
	if feet.x < -90 or feet.x > vs.x + 90 or feet.y < -40 or feet.y > vs.y + 140:
		return
	_ellipse_fill(feet + Vector2(0, 1), 0.7 * s, 0.25 * s, Color(0, 0, 0, 0.3))
	var sz: Vector2 = tex.get_size() * px_scale
	draw_texture_rect(tex, Rect2(feet - Vector2(sz.x * 0.5, sz.y * feet_ratio), sz), false)

func _draw_held_ball(c: Vector2) -> void:
	var bsd: float = BALL_R_M * s * 2.0
	draw_texture_rect(ball_tex, Rect2(c - Vector2(bsd, bsd) * 0.5, Vector2(bsd, bsd)), false)

func _ellipse(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for k in range(25):
		var ang: float = TAU * k / 24.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_polyline(pts, col, w, true)

func _ellipse_fill(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in range(16):
		var ang: float = TAU * k / 16.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(pts, col)

## Radar (estilo WSC): la cancha entera chiquita, arriba a la derecha.
func _draw_radar() -> void:
	var vs := get_viewport_rect().size
	var rs: float = 1.25
	var size := Vector2(Sim.PITCH_W, Sim.PITCH_L) * rs
	var o := Vector2(vs.x - size.x - 10.0, 96.0)
	draw_rect(Rect2(o, size), Color(0.05, 0.2, 0.08, 0.7))
	draw_rect(Rect2(o, size), Color(1, 1, 1, 0.5), false, 1.0)
	draw_line(o + Vector2(0, size.y * 0.5), o + Vector2(size.x, size.y * 0.5), Color(1, 1, 1, 0.35), 1.0)
	# Lo que muestra la cámara
	var half := Vector2(vs.x * 0.5 / s, vs.y * 0.5 / (s * TILT))
	var vr := Rect2(o + (cam - half) * rs, half * 2.0 * rs).intersection(Rect2(o, size))
	draw_rect(vr, Color(1, 1, 1, 0.25), false, 1.0)
	for a in sim.agents:
		var col: Color = COL_HOME if a.team == 0 else COL_AWAY
		if a.is_user:
			draw_circle(o + a.pos * rs, 3.2, COL_USER)
		else:
			draw_circle(o + a.pos * rs, 2.0, col.lightened(0.15))
	draw_circle(o + sim.ref_pos * rs, 1.6, Color(0.1, 0.1, 0.1))
	draw_circle(o + sim.ball_pos * rs, 1.8, Color.WHITE)

## El balón del juego (BallDesign) que GIRA según lo que rueda, se eleva en
## los centros (se agranda y su sombra queda en el piso) y deja una estela
## corta en los remates.
func _draw_ball() -> void:
	var c = sim.carrier()
	if c != null and c.role == "GK" and c.action in ["hold", "atajada", "lanzar", "saque_largo"]:
		return # la lleva el dibujo del arquero
	if sim.phase == "set_piece" and sim.set_piece.get("kind", "") == "throw" and sim.set_piece.get("ready", false) and Avatar.has_anim("pitch_saque_e"):
		return # el sprite del saque ya la lleva en las manos
	var gp := w2s(sim.ball_pos)
	var h: float = sim.ball_height()
	var br: float = BALL_R_M * s
	var hk: float = clampf(h / 3.0, 0.0, 1.0)
	_ellipse_fill(gp + Vector2(1.5 + h * 2.0, 1.5 + h * 0.8), br * lerpf(1.0, 0.6, hk), br * lerpf(0.6, 0.35, hk), Color(0, 0, 0, lerpf(0.35, 0.16, hk)))
	var bp := gp - Vector2(0, h * hpx())
	var bs: float = br * (1.0 + h * 0.07)
	var shot: bool = not sim.flight.is_empty() and String(sim.flight.get("kind", "")) == "shot"
	if shot or (not sim.flight.is_empty() and float(sim.flight.get("speed", 0.0)) > 20.0):
		trail.append(bp)
		if trail.size() > 5:
			trail.pop_front()
		for ti in range(trail.size() - 1):
			draw_circle(trail[ti], bs * (0.4 + 0.12 * ti), Color(1, 1, 1, 0.06 + 0.05 * ti))
	else:
		trail.clear()
	var moved: Vector2 = bp - ball_prev
	if moved.length() < 80.0:
		ball_spin += moved.length() / maxf(br, 1.0) * (1.0 if moved.x >= 0.0 else -1.0) * 0.55
	ball_prev = bp
	if ball_tex != null:
		var side: float = bs * 2.6
		draw_set_transform(bp, ball_spin, Vector2.ONE)
		draw_texture_rect(ball_tex, Rect2(-Vector2(side, side) * 0.5, Vector2(side, side)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(bp, bs, Color.WHITE)
		draw_arc(bp, bs, 0, TAU, 16, Color(0, 0, 0, 0.8), 1.2)

func _draw_gesture() -> void:
	# Destino de la carrera con la pelota: aro dorado que late + línea punteada.
	if sim.user_has_ball() and sim.user_dribble and sim.user_dribble_until < 0.0:
		var dst := w2s(sim.user_dribble_target)
		var up := w2s(sim.user().pos)
		var k: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		_ellipse(dst, 0.9 * s * (1.0 + 0.15 * k), 0.9 * s * TILT * 0.6, COL_USER, 2.5)
		var _n_unused: int = 0 # (sin línea punteada hasta el destino: solo el aro)
	# FLECHA DEL DESMARQUE: el que pica al espacio, hacia dónde va.
	if sim.user_has_ball() and sim.runner_idx >= 0:
		var ra = sim.agents[sim.runner_idx]
		var r0: Vector2 = w2s(ra.pos)
		var r1: Vector2 = w2s(ra.target)
		if r0.distance_to(r1) > 20.0:
			var dirr: Vector2 = (r1 - r0).normalized()
			var nn: int = int(r0.distance_to(r1) / 12.0)
			var ac := Color(COL_PASS, 0.85)
			for i in range(nn):
				if i % 2 == 0:
					draw_line(r0.lerp(r1, float(i) / nn), r0.lerp(r1, float(i + 1) / nn), ac, 3.0)
			var side := Vector2(-dirr.y, dirr.x)
			draw_colored_polygon(PackedVector2Array([r1 + dirr * 6.0, r1 - dirr * 12.0 + side * 9.0, r1 - dirr * 12.0 - side * 9.0]), ac)
	# ESTRELLA sobre el compañero mejor ubicado (como Score! Hero).
	if sim.user_has_ball() and cur_scale < 0.5 and not touching:
		var bi: int = sim.best_pass_option()
		if bi >= 0:
			var sc_: Vector2 = w2s(sim.agents[bi].pos) - Vector2(0, 68.0 * px * 0.95)
			var pr: float = 14.0 + 3.0 * sin(Time.get_ticks_msec() / 150.0)
			draw_circle(sc_, pr * 1.5, Color(1.0, 0.86, 0.25, 0.18))
			_draw_star(sc_, pr)
	# El TRAZO DEL DEDO sí se ve; la línea punteada de trayectoria no (17-oct,
	# Wilber: "la que quería que quitaras era la punteada").
	if touching and g_points.size() >= 2:
		draw_polyline(g_points, Color(1, 1, 1, 0.45), 4.0, true)
		draw_circle(g_points[g_points.size() - 1], 6.0, Color(1, 1, 1, 0.45))

## LÍNEA DE TRAYECTORIA mientras deslizás: por dónde va a ir la pelota
## (con la rosca y la altura), a qué compañero va el pase o adónde cae.
func _draw_trajectory(d: Vector2, power: float, curve: float, soft: bool) -> void:
	var u = sim.user()
	var dir: Vector2 = d.normalized()
	var from: Vector2 = sim.ball_pos
	var x_at: float = sim._goal_x_along(u.pos, dir)
	var pts: Array = []
	var colr: Color = COL_PASS
	if x_at > -900.0:
		var x: float = sim.assisted_shot_x(x_at)
		var e := Vector2(x, -0.6)
		var dist: float = from.distance_to(e)
		var perp := Vector2(-(e - from).y, (e - from).x).normalized()
		var c: Vector2 = from.lerp(e, 0.5) + perp * curve * dist * Rules.CURVE_BEND
		var zt: float = (Sim.GOAL_H - 0.5) if soft else Rules.shot_height_for_power(power)
		var arc: float = (2.2 + dist * 0.06) if soft else clampf(dist * 0.02, 0.1, 0.9) * (1.0 - power * 0.5)
		colr = COL_USER if soft else (Color(0.7, 0.7, 0.7) if zt > Sim.GOAL_H + 0.2 else COL_SHOT)
		for i in range(21):
			var t: float = float(i) / 20.0
			var a := from.lerp(c, t)
			var b := c.lerp(e, t)
			var z: float = lerpf(0.1, zt, t) + sin(t * PI) * arc
			pts.append(w2s(a.lerp(b, t)) - Vector2(0, z * hpx()))
	else:
		var mate = sim.magnet_target(u.pos, dir)
		var e2: Vector2 = from + dir * (7.0 + power * 33.0)
		if mate != null:
			e2 = mate.pos
			_ellipse(w2s(mate.pos), 1.2 * s, 0.6 * s * TILT, COL_PASS, 3.0)
		var h: float = from.distance_to(e2) * 0.15 if soft else 0.0
		var d2: Vector2 = e2 - from
		var c2: Vector2 = from.lerp(e2, 0.5) + Vector2(-d2.y, d2.x).normalized() * curve * d2.length() * Rules.CURVE_BEND
		for i in range(17):
			var t2: float = float(i) / 16.0
			var q: Vector2 = from.lerp(c2, t2).lerp(c2.lerp(e2, t2), t2)
			pts.append(w2s(q) - Vector2(0, sin(t2 * PI) * h * hpx()))
		if mate == null:
			_ellipse(w2s(e2), 0.8 * s, 0.4 * s * TILT, Color(colr, 0.7), 2.0)
	for i in range(pts.size()):
		var a2: float = 0.35 + 0.65 * float(i) / pts.size()
		draw_circle(pts[i], 3.2, Color(colr, a2))
	if pts.size() > 0:
		# X en el destino, como WSC.
		var xe: Vector2 = pts[pts.size() - 1]
		draw_line(xe + Vector2(-7, -7), xe + Vector2(7, 7), Color.WHITE, 3.0)
		draw_line(xe + Vector2(-7, 7), xe + Vector2(7, -7), Color.WHITE, 3.0)

func _draw_star(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var ang: float = -PI / 2.0 + i * PI / 5.0
		var rr: float = r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, Color(1.0, 0.86, 0.25))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.35, 0.25, 0.0), 1.5)

## ¿PERDISTE LA PELOTA? (17-oct, Wilber: "es difícil saber si boté el
## balón"): si la tenías y dejaste de tenerla sin patearla vos, el aro se
## pone rojo un momento, vibra y (si no hay otro aviso) dice "¡La perdiste!".
var _had_ball: bool = false
var lost_flash: float = 0.0
func _check_user_lost() -> void:
	var has: bool = sim.user_has_ball()
	if _had_ball and not has and sim.phase == "play":
		var kicked: bool = not sim.flight.is_empty() and int(sim.flight.get("passer", -1)) == sim.user_idx
		if not kicked:
			lost_flash = 1.0
			_buzz(70)
			if lbl_toast.modulate.a < 0.3:
				_toast("¡La perdiste!", COL_AWAY, 0.8)
	_had_ball = has
	lost_flash = maxf(0.0, lost_flash - get_process_delta_time() * 1.4)

func _buzz(ms: int) -> void:
	Input.vibrate_handheld(ms)

# -------------------------------------------------------------------- HUD
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	lbl_score = _label(root, 26, Color.WHITE)
	lbl_score.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lbl_score.offset_top = 18
	lbl_score.offset_bottom = 60

	lbl_pace = _label(root, 15, COL_USER)
	lbl_pace.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lbl_pace.offset_top = 58
	lbl_pace.offset_bottom = 84

	lbl_hint = _label(root, 14, Color(1, 1, 1, 0.8))
	lbl_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lbl_hint.offset_top = -100
	lbl_hint.offset_bottom = -16
	lbl_hint.offset_left = 18
	lbl_hint.offset_right = -18
	lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	lbl_toast = _label(root, 40, Color.WHITE)
	lbl_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lbl_toast.offset_left = -260
	lbl_toast.offset_right = 260
	lbl_toast.offset_top = -40
	lbl_toast.offset_bottom = 40
	lbl_toast.add_theme_constant_override("outline_size", 8)
	lbl_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl_toast.modulate.a = 0.0

	btn_skill = Button.new()
	btn_skill.text = "REGATE"
	btn_skill.add_theme_font_size_override("font_size", 22)
	btn_skill.custom_minimum_size = Vector2(150, 64)
	btn_skill.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_skill.offset_left = -170
	btn_skill.offset_top = -190
	btn_skill.offset_right = -18
	btn_skill.offset_bottom = -122
	btn_skill.visible = false
	btn_skill.focus_mode = Control.FOCUS_NONE
	btn_skill.pressed.connect(_on_skill_button)
	root.add_child(btn_skill)

	lbl_replay = _label(root, 26, Color(1.0, 0.86, 0.3))
	lbl_replay.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lbl_replay.offset_top = 96
	lbl_replay.offset_bottom = 150
	lbl_replay.text = "● REPETICIÓN\n(toca para saltar)"
	lbl_replay.add_theme_constant_override("outline_size", 6)
	lbl_replay.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl_replay.visible = false

	card_panel = PanelContainer.new()
	card_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card_panel.offset_left = -230
	card_panel.offset_right = 230
	card_panel.offset_top = -110
	card_panel.offset_bottom = 110
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.08, 0.86)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(COL_USER, 0.7)
	sb.set_border_width_all(2)
	card_panel.add_theme_stylebox_override("panel", sb)
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.visible = false
	root.add_child(card_panel)
	lbl_card = _label(card_panel, 24, Color.WHITE)
	lbl_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	end_panel = PanelContainer.new()
	end_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	end_panel.offset_left = -260
	end_panel.offset_right = 260
	end_panel.offset_top = -380
	end_panel.offset_bottom = 380
	end_panel.visible = false
	root.add_child(end_panel)

func _label(parent: Control, size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## Regate automático: hacia el arco, abriéndose hacia el lado contrario
## del rival que tenés encima.
func _on_skill_button() -> void:
	var u = sim.user()
	var opp = _agent_at(u.pos, 1, 5.5, false)
	var to_goal: Vector2 = (Vector2(34, 0) - u.pos).normalized()
	var side: float = 1.0
	if opp != null:
		side = 1.0 if u.pos.x >= opp.pos.x else -1.0
	sim.user_skill((to_goal + Vector2(side * 0.9, 0.0)).normalized())
	touching = false
	g_mode = ""

func _update_hud() -> void:
	btn_skill.visible = sim.user_has_ball() and sim.phase == "play" and _agent_at(sim.user().pos, 1, 5.5, false) != null
	lbl_score.text = "LOCAL  %d - %d  RIVAL    %d'" % [sim.score[0], sim.score[1], sim.minute()]
	if interlude_t > 0.0:
		lbl_pace.text = ""
		lbl_hint.text = ""
		btn_skill.visible = false
		return
	if sim.user_has_ball() and sim.phase == "set_piece":
		var k: String = sim.set_piece.get("kind", "")
		if k == "penalty":
			lbl_pace.text = "● PENAL"
			lbl_hint.text = "Desliza al arco: dirección = palo\nlargo del trazo = altura (fuerte = arriba)"
		elif k == "throw":
			lbl_pace.text = "● SAQUE DE BANDA"
			lbl_hint.text = "Toca un compañero para sacar  ·  Desliza = saque largo hacia el espacio"
		else:
			lbl_pace.text = "● TIRO LIBRE" if k == "free_kick" else "● TU SAQUE"
			lbl_hint.text = "Desliza al arco = remate (curva el trazo = rosca)  ·  Toca un compañero = pase"
	elif sim.user_has_ball():
		lbl_pace.text = "● TU JUGADA" if not sim.user_dribble else "● CONDUCIENDO"
		if sim.user().pos.y < 32.0:
			_hint("shoot", "Desliza hacia el arco para rematar\nmás largo = más alto  ·  lento = vaselina")
		else:
			_hint("ball", "Toca la cancha para avanzar  ·  toca un compañero = pase  ·  dos toques = pase alto")
	else:
		lbl_pace.text = "▶▶ x%.1f" % cur_scale if cur_scale > 1.5 else ""
		var c = sim.carrier()
		if sim.ball_incoming_to_user():
			_hint("first", "¡Viene el pase! Desliza ahora para rematar de primera")
		elif c != null and c.team == 1 and c.pos.distance_to(sim.user().pos) < 12.0:
			_hint("press", "Toca al rival para presionarlo  ·  desliza rápido hacia él = planchazo")
		else:
			_hint("move", "Toca la cancha para moverte  ·  tócate para pedirla")

## AYUDAS QUE APARECEN SOLO CUANDO HACEN FALTA: cada una se muestra las
## primeras veces que se da la situación (HINT_SHOWS) y después desaparece;
## así la pantalla queda limpia para quien ya sabe jugar.
func _hint(key: String, text: String) -> void:
	if key != hint_key:
		hint_key = key
		hints_seen[key] = int(hints_seen.get(key, 0)) + 1
		_save_hints()
	lbl_hint.text = text if int(hints_seen.get(key, 0)) <= Rules.HINT_SHOWS else ""

func _load_hints() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://proto_hints.cfg") == OK:
		for k in cf.get_section_keys("hints"):
			hints_seen[k] = int(cf.get_value("hints", k, 0))

func _save_hints() -> void:
	var cf := ConfigFile.new()
	for k in hints_seen:
		cf.set_value("hints", k, hints_seen[k])
	cf.save("user://proto_hints.cfg")

func _toast(text: String, col: Color, hold: float = 1.0) -> void:
	lbl_toast.text = text
	lbl_toast.add_theme_color_override("font_color", col)
	if toast_tween:
		toast_tween.kill()
	lbl_toast.modulate.a = 1.0
	toast_tween = create_tween()
	toast_tween.tween_interval(hold)
	toast_tween.tween_property(lbl_toast, "modulate:a", 0.0, 0.4)

func _on_sim_event(kind: String, d: Dictionary) -> void:
	match kind:
		"goal":
			stadium.goal_net(float(d.get("x", sim.ball_pos.x)), sim.ball_pos.y < 52.5)
			replay_pending = {"t": sim.t}
			stadium.coach_react(int(d["team"]))
			_buzz(140 if int(d["team"]) == 0 else 60)
			match String(d.get("kind", "")):
				"palo_adentro":
					_toast("¡Palo y adentro!", Color.WHITE, 1.0)
				"travesano_adentro":
					_toast("¡Travesaño y adentro!", Color.WHITE, 1.0)
			if bool(d.get("own_goal", false)):
				_toast("¡Gol en contra!", Color.WHITE, 1.2)
			if d["user"]:
				user_celeb = USER_CELEBS[randi() % USER_CELEBS.size()]
				_toast("¡GOOOL TUYO!", COL_USER, 1.8)
			elif d["assist_user"]:
				_toast("¡GOL! Asistencia tuya", COL_USER, 1.8)
			elif d["team"] == 0:
				_toast("¡GOL!", Color.WHITE, 1.5)
			else:
				_toast("Gol del rival", COL_AWAY, 1.5)
		"save":
			stadium.hype = maxf(stadium.hype, 1.5)
			_toast("¡Atajada!" if d["team"] == 1 else "¡Atajada de tu arquero!", Color.WHITE, 0.9)
		"miss":
			if bool(d.get("bar", false)):
				_toast("¡Al travesaño!", Color.WHITE, 0.9)
			elif d["post"]:
				_toast("¡Al palo!", Color.WHITE, 0.9)
			elif d["user"]:
				_toast("Por arriba" if d["over"] else "Afuera", Color(1, 1, 1, 0.85), 0.8)
		"intercept":
			if d["user_passer"]:
				_toast("Te la cortaron", COL_AWAY, 0.8)
		"tackle":
			if d["user_lost"] or d["user_won"]:
				_buzz(40)
			if d["user_lost"]:
				_toast("¡Te barrieron!" if bool(d.get("slide", false)) else "Te la quitaron", COL_AWAY, 0.8)
			elif d["user_won"]:
				_toast("¡Recuperada!", COL_USER, 0.8)
		"user_beat":
			_toast("¡Lo pasaste!", COL_USER, 0.6)
		"skill_ok":
			_toast("¡Gambeta!", COL_USER, 0.7)
		"skill_fail":
			_toast("Te la robaron", COL_AWAY, 0.8)
		"slide_ok":
			_toast("¡Planchazo limpio!", COL_USER, 0.8)
		"slide_miss":
			_toast("No llegaste", Color(1, 1, 1, 0.85), 0.6)
		"foul":
			if bool(d.get("penalty", false)):
				_toast("¡PENAL!", Color(1.0, 0.85, 0.3), 1.4)
				return
			if not bool(d.get("by_user", true)):
				_toast("Falta" + (" · amarilla" if d["card"] == "yellow" else ""), Color.WHITE, 0.9)
				return
			match String(d["card"]):
				"yellow":
					_toast("Falta · AMARILLA", Color(1.0, 0.85, 0.2), 1.3)
				"red", "red2":
					_toast("Falta · ¡ROJA!", COL_AWAY, 1.8)
				_:
					_toast("Falta", Color.WHITE, 0.9)
		"set_piece":
			var names := {"throw": "Saque de banda", "corner": "Córner", "goal_kick": "Saque de arco", "free_kick": "Tiro libre"}
			if d["kind"] != "goal_kick":
				_toast(names.get(d["kind"], ""), Color(1, 1, 1, 0.9), 0.8)
		"clearance":
			pass
		"advantage":
			_toast("¡Ventaja! Sigue", Color(1.0, 0.85, 0.3), 1.0)
		"offside":
			_toast("Fuera de juego", Color(1.0, 0.85, 0.3), 1.1)
		"parry_corner":
			_toast("¡Al córner!", Color.WHITE, 0.8)
		"user_call":
			_toast("¡Pídela!", COL_USER, 0.5)
		"first_time":
			pass
		"half_time":
			_toast("Entretiempo", Color.WHITE, 1.8)
		"full_time":
			_show_end()

func _show_end() -> void:
	for ch in end_panel.get_children():
		ch.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	end_panel.add_child(v)
	var st: Dictionary = sim.stats
	var tot_poss: float = maxf(float(st["possession"][0]) + float(st["possession"][1]), 0.01)
	var lines := [
		"FINAL  %d - %d" % [sim.score[0], sim.score[1]],
		"Posesión %d%% - %d%%" % [int(100.0 * st["possession"][0] / tot_poss), int(100.0 * st["possession"][1] / tot_poss)],
		"Remates %d - %d" % [st["shots"][0], st["shots"][1]],
		"",
		"TU PARTIDO",
		"Balones recibidos: %d" % st["user_receptions"],
		"Pases: %d/%d" % [st["user_passes_ok"], st["user_passes"]],
		"Remates: %d   Goles: %d   Asist.: %d" % [st["user_shots"], st["user_goals"], st["user_assists"]],
		"Gambetas: %d/%d   Planchazos: %d/%d" % [st["user_skills_ok"], st["user_skills"], st["user_slides_won"], st["user_slides"]],
		"Faltas: %d   Amarillas: %d%s" % [st["user_fouls"], st["user_yellows"], "   EXPULSADO" if sim.user_sent_off else ""],
		"Pérdidas en duelo: %d   Recuperaciones: %d" % [st["user_dribbles_lost"], st["user_tackles_won"]],
	]
	if PLAYS_MODE and director != null:
		lines.append("")
		lines.append("TUS JUGADAS")
		for r in director.results:
			lines.append("%d'  %s → %s" % [int(r["min"]), Director.label(String(r["kind"])), String(RESULT_TEXT.get(r["result"], r["result"]))])
	for t in lines:
		var l := Label.new()
		l.text = t
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 22 if t.begins_with("FINAL") or t == "TU PARTIDO" or t == "TUS JUGADAS" else (14 if "→" in t else 17))
		v.add_child(l)
	var b := Button.new()
	b.text = "Jugar otra vez"
	b.custom_minimum_size = Vector2(0, 56)
	b.pressed.connect(_new_match)
	v.add_child(b)
	end_panel.visible = true
