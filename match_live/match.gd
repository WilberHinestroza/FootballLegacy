class_name Match
extends Node2D
## La CANCHA del sistema de partido: juega en vivo los momentos clave que
## pide el MatchEngine de FootballCareer (estilo World Soccer Champs: el
## partido se simula y tú juegas la jugada). Solo manejas a TU jugador; los
## compañeros y rivales son IA.
##
## Contrato (igual que MatchEngine.decision_requested / resolve_decision):
##   start_moment(situation)  ->  emite moment_finished(result) con
##   {"kind": acción que hiciste, "precision": 0..1, "outcome": "goal"/"saved"/...,
##    "live": true}
##
## Controles estilo World Soccer Champs (toques y deslizamientos):
##  Con balón:  tocar el pasto = avanzar hasta ahí (si un rival te alcanza te
##              la puede robar) · tocar compañero = pase (desde la banda al
##              área = centro) · deslizar hacia el arco = tiro (curvo = rosca,
##              lento = vaselina) · deslizar hacia otro lado = pase al espacio /
##              centro al área · tocarte = regate.
##  Sin balón:  tocar el pasto = moverte · tocarte = pedirla · deslizar
##              cuando te llega = volea / cabezazo.
##  Defensa:    deslizar = plancha (barrida) · tocar al rival = entrada.
##  Arquero:    tocar = moverte / salir · deslizar = estirada · con el balón en
##              las manos: tocar compañero = saque con la mano, deslizar = saque largo.

signal moment_finished(result: Dictionary)

const PRECISION := {
	"goal": 1.0, "assist_goal": 1.0, "team_goal": 0.8, "chance": 0.75, "saved": 0.55,
	"blocked": 0.35, "miss": 0.25, "kept": 0.55, "lost": 0.12,
	"pass_ok": 0.6, "won": 0.92, "team_won": 0.7, "cleared": 0.8, "block": 0.85, "opp_saved": 0.5,
	"opp_miss": 0.6, "held": 0.6, "conceded": 0.0, "claimed": 0.95, "gk_save": 0.9,
	"offside": 0.15,
}
const OUTCOME_TEXT := {
	"goal": "¡GOL!", "assist_goal": "¡GOL! Asistencia tuya", "team_goal": "¡Gol del equipo!",
	"chance": "Generaste la ocasión", "saved": "Atajada del arquero", "blocked": "Tiro bloqueado",
	"miss": "Afuera", "kept": "Jugada mantenida", "lost": "Perdiste el balón",
	"pass_ok": "Pase completado", "won": "¡Recuperaste!", "team_won": "Recuperó tu equipo", "cleared": "Despejado",
	"block": "¡Bloqueaste el tiro!", "opp_saved": "Atajó tu arquero", "opp_miss": "El rival la tiró afuera",
	"held": "Contuviste la jugada", "conceded": "Gol del rival", "claimed": "¡La agarraste!",
	"gk_save": "¡Atajadón!", "offside": "Fuera de juego",
}

var teams: Array[Team] = []
var ball: Ball
var world: Node2D
var refs: Array = []          # árbitro + 2 jueces de línea
var cam: Camera2D
var hud: Hud
var user: Player
var goals: Array[Goal] = []      # [arriba, abajo]
var now: float = 0.0
var state: String = "idle"        # idle, moment, after
var possession: int = 0

# Momento en curso.
var situation: Dictionary = {}
var m_kind: String = ""
var m_phase: String = "attack"    # attack, defense, gk
var m_t: float = 0.0
var m_limit: float = 14.0
var m_action: String = ""
var m_locked := false             # tiro libre / penal: no te movés
var m_shot: Dictionary = {}       # {"by": Player, "t": float}
var m_user_pass_to: Player = null
var m_lost_t: float = 0.0
var m_script: Array = []          # acciones programadas de la IA [{t, do, ...}]
var m_one_two: Player = null
var m_pass_ok := false            # tu pase llegó a un compañero
var _after_t: float = 0.0
var _result: Dictionary = {}

# Pausas de decisión (estilo WSC): la jugada se congela y espera tu gesto.
var paused := false
## Métricas del momento (para afinar ritmo y dificultad con datos).
var stat_pauses: int = 0
var stat_touches: int = 0
var pause_reason := ""
var auto_resume: float = -1.0     # segundos reales para reanudar solo (pruebas); -1 = esperar siempre
var _pause_ms: int = 0
var _resume_t: float = -9.0
var _duel_t: float = -9.0
var _press_t: float = -9.0
var _paused_kick: float = -99.0
var _paused_mate: Player = null
## Jugada defensiva que nace de un pase rival: pausa cuando él la recibe.
var _lead_rival: Player = null
var overlay: Node2D

var guard_t: float = 0.0
var run_target := Vector2.INF
## Llegó al punto tocado: se queda quieto ahí (la IA no lo vuelve a mover)
## hasta que le des otra orden.
var _parked := false
var _idle_t: float = 0.0
var _sim := false

# ================================================================ armado

## params: home_form, away_form, user_slot, user_cfg, home_kit, home_gk_kit,
## away_kit, away_gk_kit, home_name, away_name, difficulty.
func setup(params: Dictionary) -> void:
	add_child(Field.new())
	add_child(Stadium.new())
	sfx = Sfx.new()
	add_child(sfx)
	for top in [true, false]:
		var g := Goal.new()
		g.setup(top)
		add_child(g)
		goals.append(g)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	var home := Team.new(0, String(params.get("home_name", "TU EQUIPO")), Color(params.get("home_kit", {}).get("clothing", "#2e6fb0")), true)
	var away := Team.new(1, String(params.get("away_name", "RIVAL")), Color(params.get("away_kit", {}).get("clothing", "#c0392b")), false)
	away.difficulty = float(params.get("difficulty", 1.0))
	teams = [home, away]
	for t in teams:
		t.game = self
	var slot: int = int(params.get("user_slot", 9))
	home.build(world, String(params.get("home_form", "4-3-3")), params.get("home_kit", {}), params.get("home_gk_kit", {}), 11, slot, params.get("user_cfg", {}), params.get("home_roster", []))
	away.build(world, String(params.get("away_form", "4-4-2")), params.get("away_kit", {}), params.get("away_gk_kit", {}), 77, -1, {}, params.get("away_roster", []))
	user = home.players[slot]
	user.human = true
	user.pname = String(params.get("user_name", "TÚ"))
	if params.get("home_roster", []).is_empty():
		user.skill = 0.82
	ball = Ball.new()
	world.add_child(ball)
	# Árbitros: negro, o amarillo si algún equipo viste oscuro.
	var dark: bool = false
	for k in [params.get("home_kit", {}), params.get("away_kit", {})]:
		if Color(k.get("clothing", "#888888")).get_luminance() < 0.25:
			dark = true
	var ref_col: String = "#f2c81e" if dark else "#1b1b1f"
	for i in 3:
		var r := PitchReferee.new()
		r.setup(["main", "line_top", "line_bottom"][i], ref_col, 901 + i * 37)
		world.add_child(r)
		refs.append(r)
	# Pausa en blanco y negro (como WSC): un filtro sobre la cancha...
	var gray_layer := CanvasLayer.new()
	gray_layer.layer = 5
	add_child(gray_layer)
	gray = ColorRect.new()
	gray.set_anchors_preset(Control.PRESET_FULL_RECT)
	gray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = Shader.new()
	gm.shader.code = GRAY_SHADER
	gray.material = gm
	gray.visible = false
	gray_layer.add_child(gray)
	# ...y las marcas de decisión encima, en color, siguiendo la cámara.
	var marks_layer := CanvasLayer.new()
	marks_layer.layer = 6
	marks_layer.follow_viewport_enabled = true
	add_child(marks_layer)
	overlay = Node2D.new()
	overlay.draw.connect(_draw_marks)
	marks_layer.add_child(overlay)
	# Festejo de gol (goleador en grande).
	goal_card = CanvasLayer.new()
	goal_card.layer = 8
	add_child(goal_card)
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 5.0
	cam.limit_left = int(-16.0 * Cfg.M)
	cam.limit_right = int(Cfg.FIELD_W + 16.0 * Cfg.M)
	cam.limit_top = int(-16.0 * Cfg.M)
	cam.limit_bottom = int(Cfg.FIELD_H + 16.0 * Cfg.M)
	cam.zoom = Vector2.ONE * Cfg.CAM_ZOOM
	add_child(cam)
	cam.make_current()
	hud = Hud.new()
	add_child(hud)
	hud.tapped.connect(_on_tap)
	hud.swiped.connect(_on_swipe)
	hud.scribbled.connect(_on_scribble)
	_sim = OS.get_cmdline_user_args().has("--sim")
	show_idle()

## Entre momentos: el partido se ve en vivo de lejos (la IA juega sola,
## como la vista general de WSC) mientras corre el relato.
func show_idle() -> void:
	PlayerSprite.time_k = 1.0
	for ch in goal_card.get_children():
		ch.queue_free()
	gray.visible = false
	world.process_mode = Node.PROCESS_MODE_INHERIT
	hud.replay = false
	hud.rival_text = ""
	_replay_pending = false
	cam.zoom = Vector2.ONE * (SIM_ZOOM_WIDE if is_wide() else SIM_ZOOM)
	state = "idle"
	for t in teams:
		for p in t.players:
			p.position = t.kickoff_spot(p, false)
			p.vel = Vector2.ZERO
			p.want = Vector2.ZERO
			p.facing = Cfg.attack_dir(t.side)
			p.holding = false
	ball.release()
	ball.position = Vector2(Cfg.FIELD_W * 0.5, Cfg.FIELD_H * 0.5)
	ball.vel = Vector2.ZERO
	ball.z = 0.0
	hud.mode = "ticker"
	if not hud.message.begins_with("FIN"):
		hud.message = ""
	cam.position = Vector2(Cfg.FIELD_W * 0.5, Cfg.FIELD_H * 0.5)
	cam.reset_smoothing()
	# Saque del medio para que la IA arranque a jugar.
	var kp: Player = teams[randi() % 2].players[9]
	ball.position = Vector2(Cfg.FIELD_W * 0.5, Cfg.FIELD_H * 0.5)
	kp.position = ball.position - Cfg.attack_dir(kp.team.side) * 0.7 * Cfg.M
	ball.take(kp)
	kp.think_cd = 0.6

# ================================================================ momentos

func start_moment(sit: Dictionary) -> void:
	situation = sit
	m_kind = String(sit.get("kind", "dribble"))
	m_t = 0.0
	m_action = ""
	m_locked = false
	m_shot = {}
	m_user_pass_to = null
	m_lost_t = 0.0
	m_script = []
	m_one_two = null
	m_pass_ok = false
	stat_pauses = 0
	stat_touches = 0
	run_target = Vector2.INF
	_parked = false
	_idle_t = 0.0
	guard_t = 0.6
	for t in teams:
		t.ask_pass = 0.0
		for p in t.players:
			p.stun = 0.0
			p.slide_t = 0.0
			p.tackle_t = 0.0
			p.dive_t = 0.0
			p.fall_t = 0.0
			p.holding = false
			p.rush = false
			p.celebrate_t = 0.0
			p.tackle_cd = 0.0
			p.no_touch = 0.0
			p.regate_t = 0.0
			p.kick_t = 0.0
			p.control_t = 0.0
	var info: Dictionary = Scenarios.apply(self, m_kind)
	_place_refs()
	m_phase = String(info.get("phase", "attack"))
	m_limit = float(info.get("limit", 14.0))
	m_locked = bool(info.get("locked", false))
	# Entrada a la jugada: zoom suave desde la vista general (como WSC),
	# directo al encuadre que pide la jugada (arco + pelota + tu jugador).
	var zt: float = _wanted_zoom()
	if _zoom_tw != null:
		_zoom_tw.kill()
	_zoom_tw = create_tween()
	_zoom_tw.tween_property(cam, "zoom", Vector2.ONE * zt, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# La cámara arranca YA encuadrando la jugada (con el suavizado llegaba
	# tarde y en la primera pausa el arco quedaba fuera de cuadro).
	cam.zoom = Vector2.ONE * lerpf(cam.zoom.x, zt, 0.6)
	cam.position = _focus()
	cam.reset_smoothing()
	var minute: int = int(sit.get("minute", 0))
	for t in teams:
		for p in t.players:
			p.energy = clampf(1.0 - float(minute) / 90.0 * randf_range(0.25, 0.45), 0.4, 1.0)
	hud.card_text = "#%d  %s · %s" % [user.number, user.pname, PitchFormations.label(user.code)]
	hud.card_stats = _stats(user, true)
	hud.rival_text = ""
	rec.clear()
	sfx.play("whistle")
	state = "moment"
	hud.mode = "moment"
	hud.flash(String(info.get("title", "Tu jugada")) + "\n" + String(sit.get("narration", "")), 1.5)
	_resume_t = -9.0
	_duel_t = -9.0
	_press_t = -9.0
	_paused_kick = -99.0
	_paused_mate = null
	_pen_asked = false
	_pen_dive = Vector2.INF
	if m_kind == "penalty" and user.is_gk():
		_pen_asked = true
		_pause("gk_pen")
		return
	# La jugada nace con un pase: la primera pausa es al recibir (y el que
	# te la da no dispara "La tiene tu compañero").
	if bool(info.get("lead", false)):
		_paused_mate = ball.owner_p
		return
	_lead_rival = info.get("dlead")
	if _lead_rival != null:
		return
	_pause("start")

func _finish(outcome: String) -> void:
	if state != "moment":
		return
	if paused:
		_resume()
	state = "after"
	# Sin gol, a la siguiente rápido; con gol hay festejo y repetición.
	_after_t = 1.8 if outcome in ["goal", "assist_goal", "team_goal", "conceded"] else 1.2
	# Si la jugada terminó en plena cámara lenta, las animaciones vuelven a
	# velocidad normal (antes podían quedar lentas para siempre).
	PlayerSprite.time_k = 1.0
	_freeze_t = 0.0
	_ramp_t = 0.0
	if outcome in ["won", "claimed", "gk_save", "block", "chance", "assist_goal", "pass_ok", "cleared"]:
		sfx.play("good")
		sfx.buzz("won")
	var p: float = float(PRECISION.get(outcome, 0.5))
	var kind: String = m_action if m_action != "" else m_kind
	_result = {"kind": kind, "precision": p, "outcome": outcome, "live": true, "situation_kind": m_kind,
		"secs": m_t, "pauses": stat_pauses, "touches": stat_touches}
	hud.flash(String(OUTCOME_TEXT.get(outcome, outcome)), 1.8)
	if outcome in ["goal", "assist_goal", "team_goal"]:
		_show_goal_card(outcome)
		_celebrate(teams[0], user if outcome == "goal" else null)
	elif outcome in ["conceded"]:
		_celebrate(teams[1], null)
	# Reacciones al terminar la jugada.
	if outcome in ["won", "team_won", "block", "cleared", "gk_save", "assist_goal"] and not user.is_gk():
		user.play_gesture("puno", 1.6)
	elif outcome in ["saved", "miss", "blocked"] and not user.is_gk():
		user.play_gesture("lamento", 1.8)
	_log("momento %s -> %s (%.2f) acción=%s" % [m_kind, outcome, p, kind])

# ================================================================ bucle

func _physics_process(dt: float) -> void:
	now += dt
	Player.ball_at = ball.position
	match state:
		"moment":
			if paused:
				# Entrada a la pausa en cámara lenta (como WSC): el juego se
				# frena suave unos instantes antes de congelarse.
				if _freeze_t > 0.0:
					_freeze_t -= dt
					var k: float = clampf(_freeze_t / FREEZE_TIME, 0.0, 1.0) * (0.4 if pause_reason in ["gk_shot", "incoming", "gk_1v1"] else 1.0)
					PlayerSprite.time_k = k
					_sim_step(dt * k * k, false)
					if _freeze_t <= 0.0:
						world.process_mode = Node.PROCESS_MODE_DISABLED
						PlayerSprite.time_k = 1.0
				_paused_tick()
				_update_view()
				return
			# Salida de la pausa: arranca en cámara lenta y acelera.
			var ks: float = 1.0
			if _ramp_t > 0.0:
				_ramp_t = maxf(_ramp_t - dt, 0.0)
				ks = lerpf(1.0, 0.3, _ramp_t / RAMP_TIME)
				PlayerSprite.time_k = ks
			elif PlayerSprite.time_k != 1.0:
				PlayerSprite.time_k = 1.0
			_sim_step(dt * ks, true)
		"after":

			_after_t -= dt
			for t in teams:
				for p in t.players:
					# Frenan trotando (antes se clavaban en seco y la cancha
					# quedaba congelada casi 2 s).
					if p.celebrate_t <= 0.0:
						p.want = p.want.move_toward(Vector2.ZERO, 70.0 * dt)
			_step_players(dt)
			_step_refs(dt)
			var prev_a: Vector3 = Vector3(ball.position.x, ball.position.y, ball.z)
			ball.step(dt)
			_net_collide(prev_a)
			if _after_t <= 0.0:
				if _replay_pending and rec.size() > 30:
					_start_replay()
				else:
					show_idle()
					moment_finished.emit(_result)
		"replay":
			_replay_tick()
		"idle":
			_sim_tick(dt)
	_update_view()

## Cámara lenta de las pausas (segundos reales).
const SLOWMO := false
const FREEZE_TIME := 0.2
const RAMP_TIME := 0.25
var _freeze_t: float = 0.0
var _ramp_t: float = 0.0

## Un paso de la jugada. `live`: con decisiones (pausas) y control tuyo;
## en la cámara lenta de entrada a la pausa solo corre el mundo.
func _sim_step(dt: float, live: bool) -> void:
	if dt <= 0.0:
		return
	m_t += dt
	guard_t = maxf(guard_t - dt, 0.0)
	for t in teams:
		t.ask_pass = maxf(t.ask_pass - dt, 0.0)
	_run_script()
	if live:
		_human_control(dt)
	for t in teams:
		# En tiro libre / penal nadie se mueve hasta que pateás.
		if m_locked and ball.owner_p == user:
			for p in t.players:
				p.want = Vector2.ZERO
			continue
		t.think(dt, ball, _ai_skip())
	_step_players(dt)
	_step_refs(dt)
	var prev_b: Vector3 = Vector3(ball.position.x, ball.position.y, ball.z)
	ball.step(dt)
	_owned_ball_clear()
	_net_collide(prev_b)
	_interactions()
	_owned_ball_clear()   # un quite cambia el dueño: su pie no queda en el otro
	_check_bounds()
	_check_end(dt)
	if live:
		_check_pause()
	_record()
	overlay.queue_redraw()

func _step_refs(dt: float) -> void:
	for r in refs:
		r.step(dt, ball.position, ball.vel)

## Al armar una jugada, el árbitro aparece cerca (no cruzando la cancha).
func _place_refs() -> void:
	for r in refs:
		if r.kind == "main":
			var side: float = -1.0 if ball.position.x > Cfg.FIELD_W * 0.5 else 1.0
			r.position = ball.position + Vector2(side * 11.0 * Cfg.M, 12.0 * Cfg.M)
			r.position.x = clampf(r.position.x, 6.0 * Cfg.M, Cfg.FIELD_W - 6.0 * Cfg.M)
			r.position.y = clampf(r.position.y, 8.0 * Cfg.M, Cfg.FIELD_H - 8.0 * Cfg.M)
		elif r.kind == "line_top":
			r.position.y = clampf(ball.position.y, 2.0 * Cfg.M, Cfg.FIELD_H * 0.5)
		else:
			r.position.y = clampf(ball.position.y, Cfg.FIELD_H * 0.5, Cfg.FIELD_H - 2.0 * Cfg.M)
		r.vel = Vector2.ZERO

func _step_players(dt: float) -> void:
	for t in teams:
		for p in t.players:
			p.step(dt, ball.owner_p == p)
	_separate()

## Los cuerpos no se atraviesan: se empujan suave (barridas y estiradas pasan).
func _separate() -> void:
	var all: Array[Player] = []
	for t in teams:
		all.append_array(t.players)
	var min_d: float = Cfg.PLAYER_RADIUS * 2.0
	for i in all.size():
		var a: Player = all[i]
		if a.slide_t > 0.0 or a.dive_t > 0.0 or a.fall_t > 0.0:
			continue
		for j in range(i + 1, all.size()):
			var b: Player = all[j]
			if b.slide_t > 0.0 or b.dive_t > 0.0 or b.fall_t > 0.0:
				continue
			var d: Vector2 = b.position - a.position
			var l: float = d.length()
			if l >= min_d:
				continue
			var n: Vector2 = d / l if l > 0.01 else Vector2.RIGHT
			var push: float = (min_d - l) * 0.5
			a.position -= n * push
			b.position += n * push
			# También se frena el empuje: antes la posición se corregía pero la
			# velocidad no, y el que chocaba quedaba corriendo en el lugar.
			var vn: float = (b.vel - a.vel).dot(n)
			if vn < 0.0:
				a.vel += n * vn * 0.5
				b.vel -= n * vn * 0.5

func _ai_skip() -> Player:
	# Tu jugador lo maneja la IA solo si no lo tocás hace un rato y no tiene el balón.
	if run_target != Vector2.INF or _parked or ball.owner_p == user or _idle_t < 0.8 or m_locked:
		return user
	return null

func _run_script() -> void:
	# Las jugadas armadas (el pase que te da la jugada) no se cobran offside.
	_scripted = true
	_run_script_steps()
	_scripted = false

var _scripted := false
## Compañeros del que pasa que estaban en fuera de juego al patear: se cobra
## si alguno de ellos toca la pelota antes que nadie.
var _offside_set: Array = []
var _offside_at := Vector2.ZERO

func _run_script_steps() -> void:
	for a in m_script:
		if a.get("done", false) or m_t < float(a["t"]):
			continue
		# Pared: el compañero espera a que llegues cerca del espacio (máx 1,2 s).
		if String(a["do"]) == "wall" and user.position.distance_to(a["spot"]) > 6.0 * Cfg.M and m_t < float(a["t"]) + 0.5:
			continue
		a["done"] = true
		var from: Player = a.get("from")
		if from == null or ball.owner_p != from:
			continue
		match String(a["do"]):
			"pass":
				do_pass(from, a["to"], bool(a.get("lob", false)))
			"lead":
				# Pase al punto donde vas a recibir (al pie, o picado si es largo).
				var lspot: Vector2 = a["spot"]
				var lto: Player = a.get("to", user)
				var ld: float = from.position.distance_to(lspot)
				if bool(a.get("lob", false)):
					var T: float = clampf(ld / (17.0 * Cfg.M), 0.7, 1.5)
					kick_ball(from, (lspot - from.position).normalized() * ld / T * 1.05, 0.5 * Cfg.GRAVITY * T, 0.0, "lob", lto, "pase")
				else:
					var lsp: float = clampf(sqrt(2.0 * Cfg.ROLL_DECEL * ld) + 2.5 * Cfg.M, Cfg.PASS_MIN, Cfg.PASS_MAX)
					kick_ball(from, (lspot - from.position).normalized() * lsp, 0.0, 0.0, "pass", lto, "pase")
			"wall":
				var spot: Vector2 = a["spot"]
				var dw: float = from.position.distance_to(spot)
				var spw: float = clampf(sqrt(2.0 * Cfg.ROLL_DECEL * dw) + 3.5 * Cfg.M, Cfg.PASS_MIN, Cfg.PASS_MAX)
				kick_ball(from, (spot - from.position).normalized() * spw, 0.0, 0.0, "pass", user, "pase")
				# El que te marcaba quedó mirando la pelota: le ganaste la espalda.
				for o in teams[1].players:
					if not o.is_gk() and o.position.distance_to(user.position) < 5.0 * Cfg.M:
						o.stun = maxf(o.stun, randf_range(0.45, 0.85))
			"shoot":
				cpu_shoot(from)
				if m_kind == "penalty" and user.is_gk() and _pen_dive != Vector2.INF and absf(_pen_dive.x) > 0.2:
					user.start_dive(_pen_dive.x, _pen_dive.y < -0.5)
			"cross":
				var spot: Vector2 = a["spot"]
				var d: float = from.position.distance_to(spot)
				var T: float = clampf(d / (16.0 * Cfg.M), 0.7, 1.4)
				kick_ball(from, (spot - from.position).normalized() * d / T * 1.08, 0.5 * Cfg.GRAVITY * T * float(a.get("hk", 1.0)), 0.0, "lob", a.get("to"), "pase")

# ================================================================ control

func screen_to_world(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * p

func _human_control(dt: float) -> void:
	var u: Player = user
	var has: bool = ball.owner_p == u
	hud.hint = _hint(has)
	if u.busy():
		return
	if m_locked:
		u.want = Vector2.ZERO
		if hud.dragging:
			u.face(screen_to_world(hud.drag_pos) - u.position)
		return
	if u.holding:
		u.want = Vector2.ZERO
		return
	# Un pase para vos: tu jugador va solo a buscar la pelota (como WSC).
	# Antes se quedaba en el punto tocado y la pelota frenaba a 1-2 m.
	if hud.keys.length() <= 0.1 and ball.is_free() and ball.receiver == u and not u.is_gk() and (ball.z < 1.6 * Cfg.M or ball.kind == "lob"):
		# Pelota por el aire: al punto donde cae (antes la esperaba quieto y
		# se la ganaba el defensor).
		var land_t: float = maxf(u.team.time_to_ball(u, ball), (ball.vz + sqrt(maxf(ball.vz * ball.vz + 2.0 * Cfg.GRAVITY * ball.z, 0.0))) / Cfg.GRAVITY if ball.z > 0.0 else 0.0)
		u.go_to(ball.predict(land_t), 1.0, 0.1 * Cfg.M)
		run_target = Vector2.INF
		_parked = false
		_idle_t = 0.0
		return
	if hud.keys.length() > 0.1:
		run_target = Vector2.INF
		_parked = false
		u.want = hud.keys * u.max_speed(hud.sprint)
		_idle_t = 0.0
	elif run_target != Vector2.INF:
		# Avanza hasta el punto tocado (con balón, conduciendo).
		u.go_to(run_target, 1.0, 0.6 * Cfg.M)
		if u.is_gk():
			_clamp_gk(u)
		if u.want == Vector2.ZERO:
			run_target = Vector2.INF
			_parked = true
		_idle_t = 0.0
	else:
		_idle_t += dt
		if has or _parked:
			u.want = u.want.move_toward(Vector2.ZERO, Cfg.ACCEL * 1.6 * dt)
		elif _idle_t < 0.8:
			u.want = u.want.move_toward(Vector2.ZERO, Cfg.ACCEL * dt)

func _clamp_gk(u: Player) -> void:
	var g: Vector2 = Cfg.own_goal(u.team.side)
	var lim := Rect2(g.x - Cfg.BOX_W * 0.5, g.y - Cfg.BOX_H if u.team.side == 0 else g.y, Cfg.BOX_W, Cfg.BOX_H)
	var nxt: Vector2 = u.position + u.want * 0.1
	if not lim.has_point(nxt):
		u.want = Vector2.ZERO

func _hint(has: bool) -> String:
	if m_locked:
		return "Desliza para patear · Toca compañero: pase corto"
	if m_kind == "penalty" and user.is_gk() and m_shot.is_empty():
		return "Desliza hacia el lado que te tiras · Toca: quedarte al medio"
	if user.holding:
		return "Toca compañero: saque con la mano · Desliza: saque largo"
	if user.is_gk():
		return "Toca: moverte / salir · Desliza: estirada"
	if has:
		return "Toca el pasto: avanzar · Toca compañero: pase / centro · Desliza al arco: tiro"
	if ball.owner_p != null and ball.owner_p.team == user.team:
		return "Toca el pasto: desmarque · Tócate: ¡pídela!"
	return "Toca el pasto: moverte · Desliza: plancha · Toca al rival: entrada"

func _on_tap(screen: Vector2) -> void:
	_parked = false
	if state == "replay":
		_end_replay()
		return
	if state != "moment":
		return
	if m_kind == "penalty" and user.is_gk() and m_shot.is_empty():
		# En el penal el arquero no se adelanta: tocar = quedarte al medio.
		if paused:
			_resume()
			_pen_dive = Vector2.ZERO
			m_action = "penalty"
		return
	if paused:
		_resume()
		# Tocarte a ti mismo en la pausa (sin balón propio ni de un compañero) = seguir así.
		var mine: bool = ball.owner_p != null and ball.owner_p.team == user.team
		if screen_to_world(screen).distance_to(user.position + Vector2(0, -16)) < 2.2 * Cfg.M and not mine:
			return
	if user.busy():
		return
	var u: Player = user
	var w: Vector2 = screen_to_world(screen)
	var mate: Player = _mate_near(w, 4.5 * Cfg.M)
	if u.holding:
		if mate != null:
			m_action = "distribution"
			do_pass(u, mate, false)
		return
	if ball.owner_p == u:
		if mate != null:
			_user_pass(mate, false)
		elif m_locked:
			return
		elif w.distance_to(u.position + Vector2(0, -16)) < 2.0 * Cfg.M:
			# Tocarte = regate (arranque corto que esquiva entradas).
			_do_regate(u)
		else:
			run_target = w
		return
	if ball.owner_p != null and ball.owner_p.team == u.team:
		if w.distance_to(u.position + Vector2(0, -16)) < 2.2 * Cfg.M:
			u.team.ask_pass = 2.5
			hud.flash("¡Pídela!", 0.8)
		else:
			run_target = w
		return
	var carrier: Player = ball.owner_p
	if carrier != null and carrier.position.distance_to(w) < 3.0 * Cfg.M and u.position.distance_to(carrier.position) < 4.5 * Cfg.M and u.tackle_cd <= 0.0 and not u.is_gk():
		u.start_tackle(carrier.position - u.position)
		m_action = "tackle"
		return
	if u.is_gk() and ball.is_free() and ball.position.distance_to(w) < 4.0 * Cfg.M:
		u.rush = true
		m_action = "sweep_keeper"
	run_target = w

func _on_swipe(dir: Vector2, power: float, curve: float, chip: bool) -> void:
	if state != "moment":
		return
	if paused:
		_resume()
	if user.busy():
		return
	var u: Player = user
	if u.holding:
		m_action = "distribution"
		u.holding = false
		kick_ball(u, dir * 24.0 * Cfg.M, 9.0 * Cfg.M, 0.0, "lob", null, "saque_largo")
		return
	var goal: Vector2 = Cfg.target_goal(u.team.side)
	var to_goal: Vector2 = goal - u.position
	var at_goal: bool = absf(dir.angle_to(to_goal)) < 0.75 and to_goal.length() < 40.0 * Cfg.M
	if ball.owner_p == u:
		if m_locked or at_goal:
			if m_action == "" or m_action == "dribble":
				m_action = "chip_shot" if chip else ("free_kick" if m_kind == "free_kick" else "shot_on_goal")
			shoot(u, dir, power, curve, chip)
		else:
			_user_through(dir, power, chip)
		return
	# De primera: volea o cabezazo cuando el balón te llega.
	var reach: float = 1.7 * Cfg.M + (0.8 * Cfg.M if ball.z > 1.3 * Cfg.M else 0.0)
	if ball.is_free() and not u.is_gk() and u.position.distance_to(ball.position) < reach and ball.z < 2.6 * Cfg.M:
		var kk: String = "cabezazo" if ball.z > 1.3 * Cfg.M else ("volea" if ball.z > 0.4 * Cfg.M else "remate")
		if at_goal:
			m_action = "volley" if kk == "volea" else ("aerial_duel" if kk == "cabezazo" else "shot_on_goal")
			shoot(u, dir, power * (0.75 if kk == "cabezazo" else 1.0), curve * 0.5, false, kk)
		else:
			m_action = "clearance" if m_phase != "attack" else "key_pass"
			kick_ball(u, dir * lerpf(14.0, 26.0, power) * Cfg.M, 4.0 * Cfg.M, 0.0, "loose", null, kk)
		return
	if u.is_gk():
		if m_kind == "penalty" and m_shot.is_empty():
			_pen_dive = dir
			m_action = "penalty"
			return
		u.start_dive(dir.x, absf(dir.x) < 0.35)
		m_action = "one_on_one_save"
		return
	if ball.owner_p != null and ball.owner_p.team == u.team:
		run_target = u.position + dir * 12.0 * Cfg.M
		return
	if u.tackle_cd <= 0.0:
		u.start_slide(dir)
		m_action = "last_ditch_tackle" if m_kind == "last_ditch_tackle" else "tackle"

func _mate_near(w: Vector2, r: float) -> Player:
	var best: Player = null
	var bd: float = r
	for p in user.team.players:
		if p == user:
			continue
		var d: float = (p.position + Vector2(0, -14)).distance_to(w)
		if d < bd:
			bd = d
			best = p
	return best

func _user_pass(mate: Player, through: bool) -> void:
	var u: Player = user
	var far: float = u.position.distance_to(mate.position)
	var lane: float = u.team._lane_free(u.position, mate.position)
	if m_action == "" or m_action == "dribble":
		m_action = "through_ball" if through else ("cross" if m_kind in ["cross", "cutback"] else "key_pass")
	if m_kind == "one_two" and m_one_two == null:
		m_one_two = mate
		# Pared: tu marcador sigue la pelota con la vista y se queda clavado.
		for o in teams[1].players:
			if not o.is_gk() and o.position.distance_to(u.position) < 4.5 * Cfg.M:
				o.stun = maxf(o.stun, 0.5)
	if _is_cross(u.position, mate.position):
		m_action = "cross"
		_cross_to(u, mate.position + mate.vel * 0.6, mate)
		m_user_pass_to = mate
		return
	do_pass(u, mate, far > 22.0 * Cfg.M or (lane < 1.0 * Cfg.M and far > 10.0 * Cfg.M))
	m_user_pass_to = mate

## Pase filtrado: al espacio en la dirección del deslizamiento.
func _user_through(dir: Vector2, power: float, chip: bool) -> void:
	var u: Player = user
	var dist: float = clampf(power * 32.0 * Cfg.M, 10.0 * Cfg.M, 34.0 * Cfg.M)
	var spot: Vector2 = u.position + dir * dist
	spot.x = clampf(spot.x, 1.0 * Cfg.M, Cfg.FIELD_W - 1.0 * Cfg.M)
	spot.y = clampf(spot.y, 1.0 * Cfg.M, Cfg.FIELD_H - 1.0 * Cfg.M)
	var recv: Player = null
	var best: float = INF
	for p in u.team.players:
		if p == u or p.is_gk():
			continue
		var d: float = p.position.distance_to(spot)
		if d < best:
			best = d
			recv = p
	if m_action == "" or m_action == "dribble":
		m_action = "through_ball"
	if _is_cross(u.position, spot):
		m_action = "cross"
		_cross_to(u, spot, recv)
		m_user_pass_to = recv
		return
	var to: Vector2 = spot - u.position
	var d2: float = to.length()
	# Rival cerca, tapando la salida del pase: va picado por encima (antes
	# iba al ras y se lo comía el mismo que te marcaba).
	var blocked: bool = false
	if d2 > 10.0 * Cfg.M:
		for o in teams[1].players:
			if o.is_gk():
				continue
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(o.position, u.position, spot)
			if q.distance_to(o.position) < 1.4 * Cfg.M and q.distance_to(u.position) < 9.0 * Cfg.M:
				blocked = true
				break
	if chip or blocked or d2 > 24.0 * Cfg.M:
		var T: float = clampf(d2 / (17.0 * Cfg.M), 0.6, 1.6)
		# Con un rival encima, picada más alta (pasa sobre su cabeza).
		var hk: float = 1.5 if blocked else 1.0
		kick_ball(u, to / d2 * d2 / (T * hk) * 1.08, 0.5 * Cfg.GRAVITY * T * hk, 0.0, "lob", recv, "pase")
	else:
		var sp: float = clampf(sqrt(2.0 * Cfg.ROLL_DECEL * d2) + 2.0 * Cfg.M, Cfg.PASS_MIN, Cfg.PASS_MAX)
		kick_ball(u, to / d2 * sp, 0.0, 0.0, "pass", recv, "pase")
	m_user_pass_to = recv

# ================================================================ acciones

func kick_ball(p: Player, v: Vector2, lift: float, spin: float, kind: String, recv: Player, anim: String = "pase") -> void:
	# El adelantado la toca (de primera, de cabeza): se cobra ahí.
	if _offside_set.has(p):
		_offside_set.clear()
		_offside_at = p.position
		_call_offside(p)
		return
	if p.holding:
		p.holding = false
	p.play_kick(v, anim)
	ball.launch(p, v, lift, spin, kind, now, recv)
	# Pateada pegada a otro jugador que queda DETRÁS de la pelota: sale ya por
	# delante de su cuerpo (no nace adentro). Si está delante, es un bloqueo.
	if v.length() > 0.1:
		var vd: Vector2 = v.normalized()
		for t in teams:
			for q in t.players:
				if q == p:
					continue
				var rel: Vector2 = ball.position - q.position
				if rel.length() < BODY_R and rel.dot(vd) >= 0.0:
					var along: float = rel.dot(vd)
					var perp2: float = rel.length_squared() - along * along
					ball.position = q.position + vd * (sqrt(maxf(BODY_R * BODY_R - perp2, 0.0)) + 0.5) + (rel - vd * along)
	var strong: bool = kind == "shot" or v.length() > 20.0 * Cfg.M
	sfx.play("kick_hard" if strong else "kick_soft", 0.0 if state == "moment" else -10.0)
	if p == user:
		sfx.buzz("kick")
	possession = p.team.side
	if kind == "shot":
		m_shot = {"by": p, "t": m_t}
	_offside_set.clear()
	if not _scripted and kind in ["pass", "lob"] and _stage.is_empty():
		for q in p.team.players:
			if q != p and p.team.is_offside(q, p.position):
				_offside_set.append(q)

func do_pass(p: Player, target: Player, lob: bool) -> void:
	var dist0: float = p.position.distance_to(target.position)
	var t_est: float = dist0 / (15.0 * Cfg.M)
	var aim: Vector2 = target.position + target.vel * t_est * 0.8
	if lob and target.role != "DF" and not target.human:
		aim += Cfg.attack_dir(p.team.side) * 3.0 * Cfg.M
	aim.x = clampf(aim.x, 1.0 * Cfg.M, Cfg.FIELD_W - 1.0 * Cfg.M)
	aim.y = clampf(aim.y, 1.0 * Cfg.M, Cfg.FIELD_H - 1.0 * Cfg.M)
	var to: Vector2 = aim - p.position
	var d: float = maxf(to.length(), 1.0)
	var err: float = randf_range(-1.0, 1.0) * (0.09 - p.st("passing") / 100.0 * 0.08)
	var dir: Vector2 = to.normalized().rotated(err)
	var anim: String = ("saque_largo" if lob else "lanzar") if p.holding else "pase"
	if lob:
		var T: float = clampf(d / (17.0 * Cfg.M), 0.6, 1.7)
		kick_ball(p, dir * d / T * 1.1, 0.5 * Cfg.GRAVITY * T, 0.0, "lob", target, anim)
	else:
		var sp2: float = clampf(sqrt(2.0 * Cfg.ROLL_DECEL * d) + 4.0 * Cfg.M, Cfg.PASS_MIN, Cfg.PASS_MAX)
		kick_ball(p, dir * sp2, 0.0, 0.0, "pass", target, anim)
	target.think_cd = 0.0

func shoot(p: Player, dir: Vector2, power: float, curve: float, chip: bool, anim: String = "remate") -> void:
	var speed: float = lerpf(Cfg.SHOT_MIN, Cfg.SHOT_MAX, power)
	# Puntería: depende de remate + temple, y la potencia la empeora.
	var q: float = (p.st("shooting") * 0.65 + p.st("composure") * 0.35) / 100.0
	var err: float = randf_range(-1.0, 1.0) * (0.18 - q * 0.13) * (0.55 + power * 0.7)
	var d: Vector2 = dir.normalized().rotated(err + curve * 0.28)
	var lift: float
	if chip:
		speed *= 0.62
		lift = 10.0 * Cfg.M
	else:
		# A fondo, un remate flojo de técnica se puede ir por arriba.
		# (Calibrado para el travesaño de 2,5 m.)
		# Misma altura RELATIVA al travesaño que con el arco de 4,5 m: se escala
		# la altura al llegar al arco (0,55) compensando la gravedad según el
		# tiempo de vuelo real hasta la línea.
		var t_fly: float = clampf(p.position.distance_to(Cfg.target_goal(p.team.side)) / speed, 0.1, 1.5)
		lift = (lerpf(1.0, 6.0, power * power) + randf() * (1.2 + 18.0 * power * power * (1.0 - q))) * 0.55 * Cfg.M + 0.45 * 0.5 * Cfg.GRAVITY * t_fly
	if anim == "cabezazo":
		lift = 2.0 * Cfg.M
	# Tiro libre: comba para pasar por encima de la barrera (a 9,15 m).
	if m_kind == "free_kick" and p == user and not chip:
		var tw: float = 9.15 * Cfg.M / speed
		lift = maxf(lift, (2.2 * Cfg.M + 0.5 * Cfg.GRAVITY * tw * tw) / tw)
	kick_ball(p, d * speed, lift, -curve * 1.5, "shot", null, anim)

func cpu_shoot(p: Player) -> void:
	var goal: Vector2 = Cfg.target_goal(p.team.side)
	var keeper: Player = teams[1 - p.team.side].gk()
	var s: float = -1.0 if keeper.position.x > goal.x else 1.0
	if randf() < 0.25:
		s = -s
	if m_kind == "penalty":
		# Penal: a un palo y fuerte (o, a veces, al medio). Elige sin mirarte.
		var ps: float = (-1.0 if randf() < 0.5 else 1.0) * randf_range(0.7, 1.0)
		if randf() < 0.12:
			ps = randf_range(-0.12, 0.12)
		var pt := Vector2(goal.x + ps * (Cfg.GOAL_W * 0.5 - 0.5 * Cfg.M), goal.y)
		shoot(p, (pt - p.position).normalized(), randf_range(0.75, 1.0), 0.0, false)
		return
	var tx: float = goal.x + s * (Cfg.GOAL_W * 0.5 - 0.6 * Cfg.M) * randf_range(0.55, 1.0)
	# Arquero que achica: le cierra el ángulo. El delantero se apura (más
	# error) o intenta picarla por encima si el arquero salió lejos.
	var press: float = clampf(1.0 - keeper.position.distance_to(p.position) / (8.0 * Cfg.M), 0.0, 1.0)
	var off_line: float = absf(keeper.position.y - goal.y)
	if press > 0.0 and off_line > 4.0 * Cfg.M and randf() < press * 0.35:
		shoot(p, (Vector2(goal.x + randf_range(-0.25, 0.25) * Cfg.GOAL_W, goal.y) - p.position).normalized(), 0.65, 0.0, true)
		return
	tx += randf_range(-1.0, 1.0) * press * 1.6 * Cfg.M
	var dir: Vector2 = (Vector2(tx, goal.y) - p.position).normalized()
	shoot(p, dir, randf_range(0.6, 1.0) * (p.team.difficulty if not p.team.is_human else 1.0), randf_range(-0.3, 0.3), false)

# ================================================================ contactos

func _interactions() -> void:
	var carrier: Player = ball.owner_p
	# Tu entrada de pie.
	if user.tackle_t > 0.0 and carrier != null and carrier.team != user.team:
		if user.position.distance_to(carrier.ball_spot()) < 1.5 * Cfg.M:
			user.tackle_t = 0.0
			if randf() < 0.55 + _tackle_pow(user) * 0.3 - _hold_pow(carrier) * 0.15:
				carrier.stun = 0.5
				_take(user)
			else:
				user.stun = 0.5
			return
	# Achique del arquero: llega a los pies del portador y se la lleva (o la
	# desvía); si no llega a tiempo, el delantero lo pasa.
	if carrier != null:
		var k: Player = carrier.team.opponents().gk()
		# Tu arquero saliendo a achicar también se tira a los pies.
		if k == user and k.rush and k.smother_t <= 0.0 and not k.busy() and k.position.distance_to(carrier.ball_spot()) < 2.3 * Cfg.M:
			k.start_smother(carrier.ball_spot() - k.position)
		if k.smother_t > 0.0 and k.position.distance_to(carrier.ball_spot()) < 1.3 * Cfg.M:
			k.smother_t = 0.0
			k.stun = 0.5
			k.down_t = 0.5
			var win: float = 0.45 + k.skill * 0.35 - _hold_pow(carrier) * 0.2
			if randf() < win:
				carrier.stun = 0.4
				ball.release()
				ball.last_touch = k
				if randf() < 0.55:
					_take(k)
				else:
					ball.vel = (carrier.position - k.position).orthogonal().normalized() * 7.0 * Cfg.M
					ball.kind = "loose"
				sfx.play("tackle")
				if not m_shot.is_empty():
					m_shot = {}
				return
	# Quite automático de pie de la IA al acercarse al portador.
	if carrier != null and guard_t <= 0.0:
		for o in teams[1 - carrier.team.side].players:
			if o == user or o.busy() or o.tackle_cd > 0.0 or o.is_gk():
				continue
			if o.position.distance_to(carrier.ball_spot()) > Cfg.TACKLE_RADIUS:
				continue
			o.tackle_cd = randf_range(1.0, 1.6)
			var chance: float = 0.16 + _tackle_pow(o) * 0.2 - _hold_pow(carrier) * 0.12
			if not o.team.is_human:
				chance *= o.team.difficulty
			if carrier == user:
				chance *= 0.75
			if carrier.regate_t > 0.0:
				chance *= 0.2 + (1.0 - carrier.st("dribbling") / 100.0) * 0.3
			if randf() < chance:
				o.start_tackle(carrier.position - o.position)
				carrier.stun = 0.45
				if carrier != user and randf() < 0.45:
					carrier.play_gesture("pitch_protesta", 1.0)
				sfx.play("tackle")
				if carrier == user:
					hud.flash("¡Te robaron el balón!", 0.9)
					sfx.buzz("tackle")
				ball.release()
				ball.last_touch = o
				if randf() < 0.5:
					_take(o)
				else:
					ball.vel = (o.facing + Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6))).normalized() * 6.0 * Cfg.M
					o.no_touch = 0.2
				return
	# Planchas de la IA: el que persigue al portador a 1,6-2,6 m se tira.
	if carrier != null and guard_t <= 0.0:
		for o in teams[1 - carrier.team.side].players:
			if o == user or o.busy() or o.tackle_cd > 0.0 or o.is_gk():
				continue
			var dd: float = o.position.distance_to(ball.position)
			if carrier.regate_t <= 0.0 and dd > 1.6 * Cfg.M and dd < 2.6 * Cfg.M and randf() < 0.012 * (o.team.difficulty if not o.team.is_human else 0.6):
				o.start_slide(ball.position + carrier.vel * 0.15 - o.position)
				break
	# Barridas (planchas).
	for t in teams:
		for p in t.players:
			if p.slide_t <= 0.0:
				continue
			var owner: Player = ball.owner_p
			if owner == p or (owner != null and owner.team == p.team):
				continue
			if ball.z > 1.0 * Cfg.M or p.position.distance_to(ball.position) > 1.4 * Cfg.M:
				continue
			if owner != null:
				owner.knock_down()
				sfx.play("tackle")
				if owner == user or p == user:
					sfx.buzz("tackle")
				if owner == user:
					hud.flash("¡Te robaron con una plancha!", 0.9)
			ball.release()
			ball.vel = p.slide_dir * 8.0 * Cfg.M
			ball.last_touch = p
			p.no_touch = 0.15
			if p == user and m_phase != "attack":
				m_shot = {}
			return
	if not ball.is_free():
		return
	# Atajadas.
	if ball.vel.length() > 8.0 * Cfg.M:
		for t in teams:
			var k: Player = t.gk()
			if k.no_touch > 0.0 or k.stun > 0.0:
				continue
			if ball.last_touch != null and ball.last_touch.team == t:
				continue
			var reach: float = Cfg.GK_DIVE_REACH if k.dive_t > 0.0 else Cfg.GK_REACH
			# Balón alto: o te tiras de volada o llegas con menos alcance.
			var high: bool = ball.z > Cfg.GOAL_H_Z * 0.62
			if high and k.dive_t > 0.0 and not k.dive_high:
				reach *= 0.75
			elif high and k.dive_t <= 0.0:
				reach *= 0.85
			var d: float = k.position.distance_to(ball.position)
			if d > reach or ball.z > Cfg.GOAL_H_Z + 0.6 * Cfg.M:
				continue
			var sp: float = ball.vel.length()
			var bonus: float = 0.15 if (k == user and k.dive_t > 0.0) else 0.0
			# Achicar sirve: pegado al que remata, el arquero tapa el arco.
			if not m_shot.is_empty() and m_shot.get("by") is Player:
				var ds: float = k.position.distance_to((m_shot["by"] as Player).position)
				bonus += 0.22 * clampf(1.0 - ds / (7.0 * Cfg.M), 0.0, 1.0)
			# Penal: a 11 m y a un palo, se ataja poco (aunque adivines).
			if m_kind == "penalty":
				bonus -= 0.25
			var p_save: float = clampf(0.95 - sp / Cfg.SHOT_MAX * 0.45 - d / reach * 0.35 + (k.skill - 0.7) + bonus, 0.1, 0.92)
			if _force_save_side == t.side:
				p_save = 1.0
			# Remate AL CUERPO del arquero: lo frena sí o sí (antes, al
			# "fallar" la atajada, la pelota le pasaba por adentro).
			# Recorrido entero hasta la línea del arco (no solo el próximo tramo).
			var t_line: float = clampf(absf(Cfg.own_goal(t.side).y - ball.position.y) / maxf(absf(ball.vel.y), 1.0), 0.05, 1.0)
			var cp: Vector2 = Geometry2D.get_closest_point_to_segment(k.position, ball.position, ball.position + ball.vel * t_line)
			var path_d: float = cp.distance_to(k.position)
			# Altura de la pelota cuando pasa por él (un centro que viene alto
			# baja y le cae en el cuerpo).
			var tc: float = ball.position.distance_to(cp) / maxf(ball.vel.length(), 1.0)
			var zc: float = maxf(ball.z + ball.vz * tc - 0.5 * Cfg.GRAVITY * tc * tc, 0.0)
			if path_d < BODY_R * 1.1 and zc < 1.9 * Cfg.M:
				p_save = 1.0
			# ...y si con su movimiento (estirada, paso) va a quedar en el camino
			# justo cuando pasa la pelota, también: no puede "fallar" a través
			# de su propio cuerpo.
			var t_cross: float = absf(k.position.y - ball.position.y) / maxf(absf(ball.vel.y), 1.0)
			if t_cross < 0.5 and k.dive_t <= 0.0:
				var kf: Vector2 = k.position + k.vel * t_cross
				var bf: Vector2 = ball.position + ball.vel * t_cross
				var zf: float = ball.z + ball.vz * t_cross - 0.5 * Cfg.GRAVITY * t_cross * t_cross
				if kf.distance_to(bf) < BODY_R * 1.2 and zf < 1.9 * Cfg.M:
					p_save = 1.0
			if randf() < p_save:
				if state == "moment":
					sfx.play("ohh", -3.0)
				if sp < 22.0 * Cfg.M or randf() < 0.35:
					_take(k)
				else:
					# Rechazo: hacia afuera del arco, nunca al medio.
					var gx: float = Cfg.own_goal(t.side).x
					var away: float = signf(ball.position.x - gx) if absf(ball.position.x - gx) > 1.0 else (1.0 if randf() < 0.5 else -1.0)
					ball.vel = Vector2(away * sp * 0.45, Cfg.attack_dir(t.side).y * sp * 0.22)
					ball.vz = randf_range(2.0, 5.0) * Cfg.M
					ball.spin = 0.0
					ball.kind = "loose"
					ball.last_touch = k
					k.no_touch = 0.4
					if k == user:
						_finish("gk_save")
					elif not m_shot.is_empty():
						_resolve_shot("saved")
			else:
				k.no_touch = 0.6
				# Estirado y no llegó: frena el deslizamiento (llegó tarde) en
				# vez de cruzarse por delante de la pelota.
				if k.dive_t > 0.0:
					k.dive_t = 0.0
					k.vel = Vector2.ZERO
					k.stun = 0.45
					k.down_t = 0.45
				# Le ganó: ese remate ya no lo frena (no le iba al cuerpo).
				_beaten_gk = k
				_beaten_kick = ball.kick_time
			return
	# Balón aéreo: los delanteros de la IA rematan de primera en el área
	# rival y los defensores despejan de cabeza en la propia.
	if ball.z > 0.5 * Cfg.M and ball.z < 2.6 * Cfg.M and ball.last_touch != null:
		for t in teams:
			for p in t.players:
				if p == user or p.is_gk() or p.busy() or p.no_touch > 0.0:
					continue
				if p.position.distance_to(ball.position) > 1.5 * Cfg.M:
					continue
				var kk: String = "cabezazo" if ball.z > 1.3 * Cfg.M else "volea"
				var depth: float = Cfg.depth_of(t.side, p.position)
				if ball.last_touch.team == t and depth > 0.78 and randf() < 0.75:
					var goal: Vector2 = Cfg.target_goal(t.side)
					var aim := Vector2(goal.x + randf_range(-0.4, 0.4) * Cfg.GOAL_W, goal.y)
					shoot(p, (aim - p.position).normalized(), 0.75, 0.0, false, kk)
					return
				if ball.last_touch.team != t and depth < 0.25:
					var away: Vector2 = (Cfg.attack_dir(t.side) + Vector2(signf(p.position.x - Cfg.FIELD_W * 0.5) * 0.6, 0)).normalized()
					kick_ball(p, away * 18.0 * Cfg.M, 5.0 * Cfg.M, 0.0, "loose", null, kk)
					if not m_shot.is_empty():
						m_shot = {}
					return
	# Controles de balón suelto.
	var best: Player = null
	var bd: float = INF
	var can_ctrl: Array = []
	for t in teams:
		for p in t.players:
			if p.no_touch > 0.0 or p.stun > 0.0 or p.dive_t > 0.0 or p.slide_t > 0.0:
				continue
			# El destinatario baja la pelota también con el pecho.
			var zl: float = Cfg.GOAL_H_Z if p.is_gk() else (1.8 * Cfg.M if p == ball.receiver else 1.4 * Cfg.M)
			if ball.z > zl:
				continue
			# Un pase en movimiento para un compañero no se lo "roba" otro del
			# mismo equipo (lo deja pasar, como en un partido de verdad).
			if ball.receiver != null and p != ball.receiver and p.team == ball.receiver.team 					and (ball.vel.length() > 4.0 * Cfg.M or ball.receiver.position.distance_to(ball.position) < 4.0 * Cfg.M):
				continue
			var r: float = Cfg.CONTROL_RADIUS * (0.85 + p.st("control") / 100.0 * 0.3) * (1.35 if p == ball.receiver else 1.0)
			var d2: float = p.position.distance_to(ball.position)
			if d2 < r:
				can_ctrl.append(p)
			if d2 < r and d2 < bd:
				bd = d2
				best = p
	# Arquero ante un centro alto con un rival encima: despeja de puños.
	if best != null and best.is_gk() and ball.z > 1.5 * Cfg.M and (ball.last_touch == null or ball.last_touch.team != best.team):
		var near_opp: bool = false
		for o in best.team.opponents().players:
			if o.position.distance_to(best.position) < 1.8 * Cfg.M:
				near_opp = true
		if near_opp:
			var away: Vector2 = (Cfg.attack_dir(best.team.side) + Vector2(signf(ball.position.x - Cfg.FIELD_W * 0.5) * 0.8, 0)).normalized()
			kick_ball(best, away * 15.0 * Cfg.M, 6.0 * Cfg.M, 0.0, "loose", null, "punos")
			best.no_touch = 0.4
			if not m_shot.is_empty():
				m_shot = {}
			return
	# Los que no pueden controlarla (aturdidos, de espaldas al pase...) igual
	# tienen cuerpo: si la pelota les pega antes, rebota.
	if _body_hits(can_ctrl) or best == null:
		return
	var spd: float = ball.vel.length()
	if spd > 20.0 * Cfg.M and best != ball.receiver and not best.is_gk() and randf() < clampf(0.75 - best.st("control") / 100.0 * 0.4, 0.2, 0.7):
		# Rebota en el cuerpo: vuelve o sale al costado (no lo atraviesa).
		ball.vel = (-ball.vel).rotated(randf_range(-1.1, 1.1)) * 0.45
		ball.kind = "loose"
		ball.last_touch = best
		best.no_touch = 0.3
		if not m_shot.is_empty() and best.team != m_shot["by"].team:
			_resolve_shot("blocked")
		return
	# Control largo: una pelota que viene rápida y no era para él (o un
	# jugador de poco control) se le escapa unos metros. Nunca a vos ni al
	# destinatario del pase: así la recepción sigue siendo fiable.
	if spd > 12.0 * Cfg.M and best != ball.receiver and not best.human and not best.is_gk() and m_shot.is_empty():
		var heavy: float = clampf((spd - 12.0 * Cfg.M) / (10.0 * Cfg.M), 0.0, 1.0) * (1.0 - best.st("control") / 100.0) * 0.7
		if randf() < heavy:
			ball.vel = (-ball.vel).rotated(randf_range(-0.9, 0.9)) * 0.3
			ball.kind = "loose"
			ball.last_touch = best
			best.no_touch = 0.25
			return
	_take(best)

## La pelota suelta CHOCA con el cuerpo de un jugador que no la controla
## (acaba de tocarla otro, va a la altura del pecho o de la cabeza, el
## jugador está aturdido...). Antes la atravesaba como si fuera aire.
const BODY_R := 0.42 * Cfg.M
const BODY_H := 1.9 * Cfg.M

## La pelota que llevás en el pie no puede quedar DENTRO del cuerpo de un
## rival (se veía atravesándolo al conducir contra él): se corre por el
## costado, como cuando cubrís la pelota.
func _owned_ball_clear() -> void:
	var o: Player = ball.owner_p
	if o == null or o.holding:
		return
	# Varias pasadas: con dos rivales encima, sacarla de uno la metía en el otro.
	for _it in 3:
		var moved := false
		for p in o.team.opponents().players:
			if p.is_gk() and p.dive_t > 0.0:
				continue
			var d: Vector2 = ball.position - p.position
			var r: float = BODY_R * 0.9
			if d.length() < r:
				var n: Vector2 = d.normalized() if d.length() > 0.5 else (o.position - p.position).normalized()
				ball.position = p.position + n * r
				moved = true
		if not moved:
			break

## Arquero superado por el remate en curso (no lo frena con el cuerpo).
var _beaten_gk: Player = null
var _beaten_kick: float = -1.0

func _body_hits(skip: Array = []) -> bool:
	if ball.z > BODY_H:
		return false
	# Pelota lenta (rodando o casi quieta): no rebota, pero tampoco se queda
	# adentro de nadie: el cuerpo la empuja afuera.
	if ball.vel.length() < 1.5 * Cfg.M:
		for t in teams:
			for p in t.players:
				if p.slide_t > 0.0 or p.fall_t > 0.0 or p.dive_t > 0.0 or skip.has(p):
					continue
				var dv: Vector2 = ball.position - p.position
				if dv.length() < BODY_R * 0.95:
					var nn: Vector2 = dv.normalized() if dv.length() > 0.3 else p.facing
					ball.position = p.position + nn * BODY_R * 0.95
					ball.vel = nn * maxf(ball.vel.length(), 0.6 * Cfg.M)
					return true
		return false
	var dt: float = get_physics_process_delta_time()
	var prev: Vector2 = ball.position - ball.vel * dt
	for t in teams:
		for p in t.players:
			if skip.has(p):
				continue
			# Arquero: sus choques los resuelven las atajadas, salvo que ya no
			# pueda atajar (falló o está jugado): entonces su cuerpo frena.
			if p.is_gk():
				# Si le tocaba atajar (remate rival rápido), ya lo resolvió la
				# atajada; si no (pase de su equipo, pelota lenta, jugado), su
				# cuerpo frena como cualquiera.
				var saving: bool = ball.vel.length() > 8.0 * Cfg.M and p.no_touch <= 0.0 and p.stun <= 0.0 						and (ball.last_touch == null or ball.last_touch.team != p.team)
				if saving or (p == _beaten_gk and ball.kick_time == _beaten_kick):
					continue
			elif p.dive_t > 0.0:
				continue
			# Al que va dirigida la pelota no le rebota: la controla. Los
			# compañeros NO son transparentes: si la pelota les pega, rebota
			# (la IA los corre de la línea del pase para que no pase).
			if p == ball.receiver and ball.z < 1.9 * Cfg.M:
				continue
			# Barriéndose o en el piso: solo frena la pelota a ras.
			if (p.slide_t > 0.0 or p.fall_t > 0.0) and ball.z > 0.6 * Cfg.M:
				continue
			# El que la acaba de patear no se la lleva puesta (solo un instante).
			if ball.last_touch == p and p.no_touch > 0.08:
				continue
			# Contra un remate, cuerpo más angosto (piernas/tronco): si no, la
			# defensa tapaba demasiados tiros.
			# (Antes 0,65: tiros a 30 cm del centro pasaban "entre las piernas".)
			var br: float = BODY_R * (0.85 if ball.kind == "shot" else 1.0)
			var c: Vector2 = _sweep_circle(prev, ball.position, p.position, br)
			if c == Vector2.INF:
				# Arrancó adentro (pateada pegada a un rival): también choca.
				if prev.distance_to(p.position) < br:
					c = prev if prev.distance_to(p.position) > 0.3 else p.position - ball.vel.normalized() * br
				else:
					continue
			var n: Vector2 = (c - p.position).normalized()
			# Velocidad RELATIVA al cuerpo (un jugador que corre junto a la
			# pelota la "llevaba adentro": comparaba contra un cuerpo quieto).
			var vn: float = (ball.vel - p.vel).dot(n)
			if vn >= 0.0:
				# Se está yendo; si quedó adentro, la deja en el borde.
				if ball.position.distance_to(p.position) < br:
					var nn2: Vector2 = (ball.position - p.position).normalized() if ball.position.distance_to(p.position) > 0.3 else n
					ball.position = p.position + nn2 * (br + 0.5)
				continue
			# Rebote blando (el cuerpo amortigua) y algo de su movimiento.
			ball.vel -= 1.35 * vn * n
			ball.vel = ball.vel * 0.7 + p.vel * 0.3
			ball.vz = absf(ball.vz) * 0.3 if ball.z > 0.3 * Cfg.M else ball.vz
			ball.spin = 0.0
			ball.position = p.position + n * (br + 0.5)
			ball.kind = "loose"
			ball.last_touch = p
			if not m_shot.is_empty() and p.team != m_shot["by"].team:
				_resolve_shot("blocked")
			return true
	return false

func _take(p: Player) -> void:
	if not _offside_set.is_empty():
		var hit: bool = _offside_set.has(p)
		_offside_set.clear()
		if hit:
			_offside_at = p.position
			_call_offside(p)
			return
	var was_shot: bool = not m_shot.is_empty()
	ball.take(p)
	guard_t = maxf(guard_t, 0.35)
	possession = p.team.side
	p.think_cd = 0.9 if p.is_gk() else randf_range(0.35, 0.7)
	if p.is_gk():
		# Con las manos solo dentro de su área y si no es una cesión de un
		# compañero (pase con el pie): si no, la juega con los pies.
		var g: Vector2 = Cfg.own_goal(p.team.side)
		var in_box: bool = absf(p.position.x - g.x) < Cfg.BOX_W * 0.5 and absf(p.position.y - g.y) < Cfg.BOX_H
		var back_pass: bool = ball.last_touch != null and ball.last_touch.team == p.team and ball.last_touch != p
		p.holding = in_box and not back_pass
		p.think_cd = 1.2 if p.holding else 0.5
		if p.holding and ball.vel.length() > 5.0 * Cfg.M:
			p.play_catch(ball.z > 1.5 * Cfg.M)
		p.rush = false
	elif ball.vel.length() < 1.0:
		p.control_t = 0.25
	if p == user:
		run_target = Vector2.INF
		if state == "moment" and not paused:
			_pause("ball")
	elif p == _lead_rival:
		_lead_rival = null
		if state == "moment" and not paused:
			_duel_t = m_t
			_pause("rival_ball")
	if m_user_pass_to != null and p.team.side == 0 and p != user and ball.last_touch == user:
		m_pass_ok = true
	if was_shot and p.team != m_shot["by"].team:
		_resolve_shot("saved" if p.is_gk() else "blocked")
	# Pared: el compañero te la devuelve al espacio de primera.
	# Va AL ESPACIO detrás de tu marcador (hacia el lado del compañero): a tus
	# pies la cortaba el mismo rival que te marcaba.
	if m_one_two != null and p == m_one_two:
		var side: float = signf(p.position.x - user.position.x)
		var ahead: Vector2 = user.position + Cfg.attack_dir(0) * 6.5 * Cfg.M + Vector2(side * 1.5 * Cfg.M, 0.0)
		ahead.x = clampf(ahead.x, 2.0 * Cfg.M, Cfg.FIELD_W - 2.0 * Cfg.M)
		m_script.append({"t": m_t + 0.12, "do": "wall", "from": p, "spot": ahead})
		m_one_two = null
		run_target = ahead


## Un tiro terminó (atajado, bloqueado, afuera o se frenó).
## Juez de línea: banderín arriba, silbato y la pelota para el que defiende
## (tiro libre desde donde estaba el adelantado).
func _call_offside(p: Player) -> void:
	sfx.play("whistle")
	for r in refs:
		if r.kind != "main" and ((r.kind == "line_top") == (_offside_at.y < Cfg.FIELD_H * 0.5)):
			r.flag_up_t = 1.8
	hud.flash("¡Fuera de juego!", 1.4)
	ball.release()
	ball.vel = Vector2.ZERO
	ball.vz = 0.0
	ball.z = 0.0
	ball.position = _offside_at
	ball.last_touch = p
	p.play_gesture("pitch_protesta", 1.2)
	for q in p.team.players:
		q.no_touch = maxf(q.no_touch, 1.4)
	if state == "moment":
		_finish("offside" if p.team.side == 0 else "team_won")
		return
	# Partido de fondo: saca el defensor más cercano.
	var d: Player = p.team.opponents().best_interceptor(ball)
	if d != null:
		d.position = _offside_at + Cfg.attack_dir(d.team.side) * -0.8 * Cfg.M
		_take(d)

## Festeja el equipo que hizo el gol: el goleador (o `star`) con un festejo
## propio; los demás corren a abrazarse. El que lo recibió, se lamenta.
const CELEBS := ["celeb_brazos_abiertos", "celeb_dedos_cielo", "celeb_cielo", "celeb_salto",
	"celeb_grito", "celeb_pistolas", "celeb_rodillas", "celeb_aplauso"]

func _celebrate(t: Team, star: Player) -> void:
	if star == null:
		star = ball.last_touch if ball.last_touch != null and ball.last_touch.team == t else null
	for q in t.players:
		if q.position.distance_to(ball.position) < 25.0 * Cfg.M or q == star:
			q.celebrate_t = 1.8
			q.celebrate_anim = ""
	if star != null and not star.is_gk():
		star.celebrate_t = 2.2
		star.celebrate_anim = CELEBS[randi() % CELEBS.size()]
	for q in t.opponents().players:
		if not q.is_gk() and q.position.distance_to(ball.position) < 30.0 * Cfg.M:
			q.play_gesture("lamento", 2.0)

## En la pausa con la pelota en tu pie: los compañeros libres y con línea
## limpia ya están con la mano arriba (a quién pasársela, de un vistazo).
func _cue_free_mates() -> void:
	if ball.owner_p != user or user.holding:
		return
	var cands: Array = []
	for p in teams[0].players:
		if p == user or p.is_gk() or p.busy():
			continue
		var to: Vector2 = user.position - p.position
		var d: float = to.length()
		if d < 6.0 * Cfg.M or d > 28.0 * Cfg.M or to.y < d * 0.3:
			continue
		if teams[0]._nearest_opp_dist(p.position) < 3.0 * Cfg.M or teams[0]._lane_free(user.position, p.position) < 1.3 * Cfg.M:
			continue
		if teams[0].is_offside(p, user.position):
			continue
		cands.append([d, p])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(cands.size(), 2):
		var q: Player = cands[i][1]
		q.face(user.position - q.position)
		q.pose_gesture("pitch_pide", 0.9)

func _resolve_shot(how: String) -> void:
	if m_shot.is_empty() or state != "moment":
		return
	var by: Player = m_shot["by"]
	if how in ["miss", "saved"] and by != null and not by.is_gk():
		by.play_gesture("lamento", 1.6)
	m_shot = {}
	if by.team.side == 0:
		if by == user:
			_finish(how)
		elif m_user_pass_to != null:
			_finish("chance")
		else:
			_finish("kept" if how != "blocked" else "lost")
	else:
		if how == "blocked" and ball.last_touch == user:
			_finish("block")
		elif how == "saved":
			_finish("opp_saved" if teams[0].gk() != user else "gk_save")
		else:
			_finish("opp_miss" if how == "miss" else "team_won")

# ================================================================ reglas

func _check_bounds() -> void:
	if state != "moment":
		return
	var o: Player = ball.owner_p
	if o != null and o.is_gk():
		o.position.y = clampf(o.position.y, 1.2 * Cfg.M, Cfg.FIELD_H - 1.2 * Cfg.M)
		return
	if ball.is_free():
		for top in [true, false]:
			if _hit_frame(top):
				return
	var b: Vector2 = ball.position
	var W: float = Cfg.FIELD_W
	var H: float = Cfg.FIELD_H
	if b.y < -0.2 * Cfg.M or b.y > H + 0.2 * Cfg.M:
		var top2: bool = b.y < 0.0
		var off: float = absf(b.x - W * 0.5)
		if off < Cfg.GOAL_W * 0.5 and ball.z < Cfg.GOAL_H_Z and ball.is_free():
			goals[0 if top2 else 1].ripple(b.x)
			_goal(0 if top2 else 1)
			return
		_out()
	elif b.x < 0.0 or b.x > W:
		_out()

## Primer punto donde el segmento a->b entra en el círculo (centro, r).
## INF si no lo toca. Si ya arrancó adentro, devuelve el punto de salida
## más cercano (lo empuja afuera).
func _sweep_circle(a: Vector2, b: Vector2, center: Vector2, r: float) -> Vector2:
	var d: Vector2 = b - a
	var f: Vector2 = a - center
	if f.length() < r:
		return center + (f.normalized() if f.length() > 0.001 else -d.normalized()) * r
	var A: float = d.dot(d)
	if A < 0.0001:
		return Vector2.INF
	var B: float = 2.0 * f.dot(d)
	var C: float = f.dot(f) - r * r
	var disc: float = B * B - 4.0 * A * C
	if disc < 0.0:
		return Vector2.INF
	var t: float = (-B - sqrt(disc)) / (2.0 * A)
	if t < 0.0 or t > 1.0:
		return Vector2.INF
	return a + d * t

## Choque del balón con los palos (cilindros) y el travesaño de un arco.
## Rebote con pérdida (coef. 0,6). Devuelve true si pegó.
func _hit_frame(top: bool) -> bool:
	var line_y: float = 0.0 if top else Cfg.FIELD_H
	var L: float = Cfg.FIELD_W * 0.5 - Cfg.GOAL_W * 0.5
	var R: float = Cfg.FIELD_W * 0.5 + Cfg.GOAL_W * 0.5
	if absf(ball.position.y - line_y) > 1.5 * Cfg.M:
		return false
	# Palos.
	if ball.z < Cfg.GOAL_H_Z:
		var dt: float = get_physics_process_delta_time()
		var prev: Vector2 = ball.position - ball.vel * dt
		for px in [L, R]:
			var post := Vector2(px, line_y)
			# Barrido: un tiro fuerte avanza ~7 px por cuadro y el palo mide
			# ~5: antes a veces lo atravesaba.
			var c: Vector2 = _sweep_circle(prev, ball.position, post, Cfg.POST_R)
			if c != Vector2.INF:
				var n: Vector2 = (c - post).normalized()
				var vn: float = ball.vel.dot(n)
				if vn < 0.0:
					# Rebote con pérdida; el efecto lo abre un poco hacia el costado.
					var e: float = 0.55 + randf() * 0.15
					ball.vel -= (1.0 + e) * vn * n
					ball.vel = ball.vel.rotated(clampf(ball.spin * 0.08, -0.25, 0.25))
					ball.spin *= -0.4
					ball.vz = maxf(ball.vz, absf(vn) * 0.08)
					ball.position = post + n * (Cfg.POST_R + 0.5)
					ball.kind = "loose"
					goals[0 if top else 1].shake()
					hud.flash("¡Poste!", 0.8)
					sfx.play("post")
					sfx.play("ohh")
					sfx.buzz("post")
					if not m_shot.is_empty():
						m_shot["t"] = m_t
					return true
	# Travesaño (cilindro horizontal a la altura GOAL_H_Z).
	if ball.position.x > L and ball.position.x < R:
		var dt2: float = get_physics_process_delta_time()
		var cur := Vector2(ball.position.y - line_y, ball.z - Cfg.GOAL_H_Z)
		var prv: Vector2 = cur - Vector2(ball.vel.y, ball.vz) * dt2
		var c2: Vector2 = _sweep_circle(prv, cur, Vector2.ZERO, Cfg.POST_R)
		if c2 != Vector2.INF:
			var n2: Vector2 = c2.normalized()
			var v2 := Vector2(ball.vel.y, ball.vz)
			var vn2: float = v2.dot(n2)
			if vn2 < 0.0:
				v2 -= 1.6 * vn2 * n2
				ball.vel.y = v2.x
				ball.vz = v2.y
				ball.position.y = line_y + n2.x * (Cfg.POST_R + 0.5)
				ball.z = Cfg.GOAL_H_Z + n2.y * (Cfg.POST_R + 0.5)
				ball.kind = "loose"
				goals[0 if top else 1].shake()
				hud.flash("¡Travesaño!", 0.8)
				sfx.play("post")
				sfx.play("ohh")
				sfx.buzz("post")
				if not m_shot.is_empty():
					m_shot["t"] = m_t
				return true
	return false

func _goal(side: int) -> void:
	var by: Player = ball.last_touch
	m_shot = {}
	_replay_pending = true
	if side == 0:
		sfx.play("goal")
		sfx.play("roar")
		sfx.crowd_swell(10.0, 4.0)
		sfx.buzz("goal")
	else:
		sfx.play("goal_rival")
		sfx.buzz("goal_against")
	if side == 0:
		if by == user:
			_finish("goal")
		elif m_user_pass_to != null and by == m_user_pass_to:
			_finish("assist_goal")
		else:
			_finish("team_goal")
	else:
		_finish("conceded")

func _out() -> void:
	if not m_shot.is_empty():
		_resolve_shot("miss")
		return
	var last: int = ball.last_touch.team.side if ball.last_touch != null else 1
	if m_phase == "attack":
		_finish("kept" if last == 1 else "lost")
	else:
		_finish("cleared" if last == 0 else "won")

## RED de los dos arcos: fondo, laterales y techo, desde adentro y desde
## afuera. La red frena casi todo (no rebota como una pared) y se infla
## donde pega la pelota. Corre siempre que la pelota está suelta.
const NET_R := 0.25 * Cfg.M

func _net_collide(prev: Vector3) -> void:
	if not ball.is_free():
		return
	var L: float = Cfg.FIELD_W * 0.5 - Cfg.GOAL_W * 0.5
	var R: float = Cfg.FIELD_W * 0.5 + Cfg.GOAL_W * 0.5
	var D: float = Cfg.GOAL_DEPTH
	var H: float = Cfg.GOAL_H_Z
	var Hb: float = H * 0.55
	for top in [true, false]:
		var gy: float = 0.0 if top else Cfg.FIELD_H
		var out: float = -1.0 if top else 1.0
		var dep: float = (ball.position.y - gy) * out
		var pdep: float = (prev.y - gy) * out
		if dep < 0.0 or dep > D + NET_R * 2.0:
			continue
		var x: float = ball.position.x
		var roof: float = lerpf(H, Hb, clampf(dep / D, 0.0, 1.0))
		var g: Goal = goals[0 if top else 1]
		var was_in: bool = prev.x > L and prev.x < R and pdep >= -NET_R and prev.z <= lerpf(H, Hb, clampf(pdep / D, 0.0, 1.0)) + 1.0
		if was_in:
			# Fondo.
			if dep > D - NET_R and x > L and x < R:
				ball.position.y = gy + out * (D - NET_R)
				var vin: float = ball.vel.y * out
				if vin > 0.0:
					g.ripple(x)
					ball.vel.y = -out * vin * 0.1
				ball.vel.x *= 0.55
				ball.vz = minf(ball.vz, 0.0) * 0.4
				ball.spin = 0.0
			# Laterales (desde adentro).
			if x < L + NET_R:
				ball.position.x = L + NET_R
				ball.vel.x = absf(ball.vel.x) * 0.12
				ball.vel.y *= 0.7
			elif x > R - NET_R:
				ball.position.x = R - NET_R
				ball.vel.x = -absf(ball.vel.x) * 0.12
				ball.vel.y *= 0.7
			# Techo (desde adentro): la pelota que sube se frena contra la red.
			if ball.z > roof - NET_R:
				ball.z = roof - NET_R
				ball.vz = -absf(ball.vz) * 0.15
		else:
			# Desde afuera. Lateral: la pelota se queda en la red del costado.
			if ball.z < roof and dep < D:
				if prev.x <= L - NET_R * 0.5 and x > L - NET_R:
					ball.position.x = L - NET_R
					ball.vel.x = -absf(ball.vel.x) * 0.12
					ball.vel.y *= 0.5
					g.shake_net(x)
				elif prev.x >= R + NET_R * 0.5 and x < R + NET_R:
					ball.position.x = R + NET_R
					ball.vel.x = absf(ball.vel.x) * 0.12
					ball.vel.y *= 0.5
					g.shake_net(x)
			# Techo por arriba: cae sobre la red, pica bajito y rueda hacia atrás.
			if x > L and x < R and prev.z >= roof and ball.z < roof + NET_R and ball.vz < 0.0:
				ball.z = roof + NET_R
				ball.vz = absf(ball.vz) * 0.2
				ball.vel *= 0.6
				ball.vel.y += out * 1.5 * Cfg.M
				g.shake_net(x)

func _keep_ball_in_net() -> void:
	var b: Vector2 = ball.position
	var lim: float = Cfg.GOAL_DEPTH - 2.0
	if b.y < -lim:
		ball.position.y = -lim
		ball.vel *= 0.2
	elif b.y > Cfg.FIELD_H + lim:
		ball.position.y = Cfg.FIELD_H + lim
		ball.vel *= 0.2

## ¿Terminó el momento? (posesión perdida/recuperada, tiro resuelto, tiempo).
func _check_end(dt: float) -> void:
	if state != "moment":
		return
	if not m_shot.is_empty():
		if ball.is_free() and ball.vel.length() < 3.0 * Cfg.M and m_t - float(m_shot["t"]) > 0.4:
			_resolve_shot("miss")
		elif m_t - float(m_shot["t"]) > 4.0:
			_resolve_shot("miss")
		return
	var o: Player = ball.owner_p
	if m_kind == "distribution" and user.is_gk():
		if o != null and o != user:
			_finish("kept" if o.team.side == 0 else "lost")
		elif m_t >= m_limit:
			_finish("held")
		return
	# Saque del arquero hacia vos: mientras tu arquero tiene la pelota en la
	# mano, la jugada todavía no empezó (antes terminaba al instante).
	if m_kind == "distribution" and o != null and o.is_gk() and o.team.side == 0 and m_t < m_limit:
		return
	if m_phase == "attack":
		if o != null and o.team.side == 1:
			m_lost_t += dt
			if m_lost_t > 0.35:
				_finish("pass_ok" if m_pass_ok else "lost")
				return
		else:
			m_lost_t = 0.0
	elif o != null and o.team.side == 0:
		if o == user or ball.last_touch == user or user.slide_t > 0.0:
			_finish("claimed" if o.is_gk() and o == user else "won")
		else:
			_finish("team_won")
		return
	if m_t >= m_limit:
		if m_phase == "attack":
			_finish("kept" if (o == null or o.team.side == 0) else "lost")
		else:
			_finish("held")

# ================================================================ vista

## Mejor opción de pase de tu jugador (para encuadrarla). Se recalcula cada
## 0,6 s de juego, así la cámara no tiembla cambiando de candidato.
var _opt_mate: Player = null
var _opt_t: float = -99.0

## Penal: lado elegido en la pausa (se tira recién cuando patean).
var _pen_asked := false
var _pen_dive: Vector2 = Vector2.INF

func _option_mate() -> Player:
	if ball.owner_p != user or user.holding or m_locked:
		return null
	if absf(m_t - _opt_t) > 0.6:
		_opt_t = m_t
		var o: Dictionary = teams[0].best_pass(user)
		_opt_mate = o.get("target") if not o.is_empty() else null
		if _opt_mate != null and _opt_mate.position.distance_to(user.position) > 30.0 * Cfg.M:
			_opt_mate = null
	return _opt_mate

func _focus() -> Vector2:
	var f: Vector2 = ball.position + Vector2(0, -ball.z * Cfg.Z_PROJ)
	if state == "moment" and user != null and user.holding:
		# Saque del arquero: los compañeros a la vista (antes solo se veía el área).
		var hh: float = get_viewport_rect().size.y * 0.5 / maxf(cam.zoom.y, 0.1)
		var fwd: float = signf(Cfg.target_goal(0).y - user.position.y)
		return Vector2(lerpf(user.position.x, Cfg.target_goal(0).x, 0.5), user.position.y + fwd * (hh - 5.0 * Cfg.M))
	if state == "moment" and user != null:
		f = f.lerp(user.position, 0.25)
		var om: Player = _option_mate()
		if om != null:
			f = f.lerp(om.position, 0.3)
		# En horizontal se ve poca profundidad: la cámara mira hacia adelante.
		if is_wide():
			f.y += (-5.0 if m_phase == "attack" else 5.0) * Cfg.M
		# Cerca de un arco, el arco SIEMPRE en pantalla: antes, en la pausa
		# del tiro la portería quedaba fuera de cuadro y tirabas a ciegas.
		var half_h: float = get_viewport_rect().size.y * 0.5 / maxf(cam.zoom.y, 0.1)
		var keep: float = half_h - 8.5 * Cfg.M
		for g in [Cfg.target_goal(0), Cfg.own_goal(0)]:
			if absf(ball.position.y - g.y) < 34.0 * Cfg.M or absf(user.position.y - g.y) < 30.0 * Cfg.M:
				f.y = clampf(f.y, g.y - keep, g.y + keep)
		# ...pero la PELOTA manda: nunca queda fuera de cuadro (en el mano a
		# mano del arquero el delantero quedaba afuera). Si no entran los dos,
		# _update_view aleja el zoom.
		# Tu jugador también a la vista (si no entran los dos, se aleja el zoom).
		var keep_u: float = half_h - 3.0 * Cfg.M
		f.y = clampf(f.y, user.position.y - keep_u, user.position.y + keep_u)
		var keep_b: float = half_h - 2.5 * Cfg.M
		f.y = clampf(f.y, ball.position.y - keep_b, ball.position.y + keep_b)
		var half_w: float = get_viewport_rect().size.x * 0.5 / maxf(cam.zoom.x, 0.1)
		f.x = clampf(f.x, user.position.x - (half_w - 3.0 * Cfg.M), user.position.x + (half_w - 3.0 * Cfg.M))
		f.x = clampf(f.x, ball.position.x - (half_w - 2.5 * Cfg.M), ball.position.x + (half_w - 2.5 * Cfg.M))
	return f

## Zoom de la jugada: el normal, o más abierto si hace falta para ver a la
## vez la pelota y el arco que está en juego.
func _wanted_zoom() -> float:
	# Encuadre en METROS visibles (alto de pantalla), igual en cualquier
	# resolución: antes era un zoom en píxeles y en el juego (360 de alto)
	# casi siempre quedaba al mínimo y los jugadores se veían chiquitos.
	var vp: Vector2 = get_viewport_rect().size
	if not is_wide():
		return Cfg.CAM_ZOOM
	if user.holding:
		return vp.y / (VIS_MAX * Cfg.M)
	var need: float = VIS_BASE
	# Cerca de un arco (zona de tiro): arco y pelota juntos.
	for g in [Cfg.target_goal(0), Cfg.own_goal(0)]:
		var by: float = absf(ball.position.y - g.y) / Cfg.M
		# WSC (medido): frente al arco se ven ~26 m; el arco abajo, grande.
		if by < 36.0:
			need = maxf(need, by + 12.0)
			break
	# Tu mejor opción de pase, si está razonablemente cerca.
	var om: Player = _option_mate()
	if om != null:
		var dm: Vector2 = (om.position - ball.position).abs() / Cfg.M
		if dm.y < 20.0:
			need = maxf(need, dm.y + 6.0)
	# Pelota y tu jugador en cuadro a la vez.
	var d: Vector2 = (ball.position - user.position).abs() / Cfg.M
	need = maxf(need, d.y + 6.0)
	need = maxf(need, (d.x + 6.0) * vp.y / vp.x)
	return vp.y / (clampf(need, VIS_BASE, VIS_MAX) * Cfg.M)

## Metros de alto que se ven en una jugada: lo normal y lo máximo.
const VIS_BASE := 24.0
const VIS_MAX := 32.0

func _update_view() -> void:
	if state == "idle":
		cam.position = cam.position.lerp(ball.position, 0.05 if _stage.is_empty() else 0.12)
		# En las escenas del partido de fondo la cámara se acerca (de lejos
		# no se veía qué pasaba) y después vuelve a la vista general.
		var base_z: float = idle_zoom if idle_zoom > 0.0 else (SIM_ZOOM_WIDE if is_wide() else SIM_ZOOM)
		var vz: float = maxf(base_z, get_viewport_rect().size.y / (34.0 * Cfg.M)) if not _stage.is_empty() else base_z
		cam.zoom = Vector2.ONE * lerpf(cam.zoom.x, vz, 0.06)
	else:
		cam.position = _focus()
		if state == "moment" and (_zoom_tw == null or not _zoom_tw.is_running()):
			var z: float = lerpf(cam.zoom.x, _wanted_zoom(), clampf(get_physics_process_delta_time() * 2.5, 0.0, 1.0))
			cam.zoom = Vector2.ONE * z
	var dots: Array = []
	for t in teams:
		for p in t.players:
			dots.append([p.position, Color(1, 0.95, 0.3) if p == user else t.color, 2.0 if p == user else 1.4])
	dots.append([ball.position, Color.WHITE, 1.6])
	hud.minimap_dots = dots

func _log(t: String) -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if _sim or a.has("--shots") or a.has("--gtest") or a.has("--sim-all"):
		print("[%5.1fs] %s" % [now, t])

# ================================================================ pausas de decisión

const PAUSE_TEXT := {
	"start": ["¿Qué haces?", ""],
	"ball": ["¡Es tuya!", "Toca el pasto: avanzar · Toca compañero: pase / centro · Desliza al arco: tiro"],
	"pressure": ["¡Te presionan!", "Toca compañero: pase · Desliza al arco: tiro · Toca el pasto: escapar"],
	"mate": ["La tiene tu compañero", "Tócate: ¡pídela! · Toca el pasto: desmarque"],
	"incoming": ["¡Te llega!", "Desliza: de primera (volea / cabezazo) · Tócate: controlar"],
	"rival_ball": ["¡La recibe!", "Toca al rival: ir al quite · Desliza: barrida · Toca el pasto: cerrar el paso"],
	"duel": ["¡Te encara!", "Desliza: plancha · Toca al rival: entrada · Toca el pasto: cerrar"],
	"gk_shot": ["¡Remate!", "Desliza hacia donde te tiras"],
	"gk_1v1": ["Mano a mano", "Toca adelante: achicar · Desliza: tirarte · Toca el balón: salir"],
	"locked": ["Balón parado", "Desliza para patear · Toca compañero: pase corto"],
	"gk_pen": ["¡Penal!", "Desliza hacia el lado que te tiras · Toca: quedarte al medio"],
	"gk_hold": ["Saque del arquero", "Toca compañero: saque con la mano · Desliza: saque largo"],
}

func _pause(reason: String) -> void:
	if paused or state != "moment":
		return
	if reason == "start":
		if m_locked:
			reason = "locked"
		elif ball.owner_p == user:
			reason = "gk_hold" if user.holding else "ball"
		elif ball.owner_p != null and ball.owner_p.team == user.team:
			reason = "mate"
		elif user.is_gk():
			reason = "gk_1v1"
		else:
			reason = "duel"
	paused = true
	stat_pauses += 1
	pause_reason = reason
	_cue_free_mates()
	gray.visible = true
	var opp: Player = ball.owner_p if (ball.owner_p != null and ball.owner_p.team.side == 1) else null
	if opp != null:
		hud.rival_text = "#%d  %s · %s (rival)" % [opp.number, opp.pname, opp.code]
		hud.rival_stats = _stats(opp, false)
	else:
		hud.rival_text = ""
	_log("  pausa: %s" % reason)
	_pause_ms = Time.get_ticks_msec()
	# En pleno juego la pausa entra en cámara lenta; la del arranque (jugada
	# recién armada) y la del balón parado, al instante.
	# WSC congela al instante (medido cuadro a cuadro): sin cámara lenta.
	if not SLOWMO or m_t < 0.05 or reason in ["gk_pen", "locked"]:
		_freeze_t = 0.0
		world.process_mode = Node.PROCESS_MODE_DISABLED
	elif reason in ["gk_shot", "incoming", "gk_1v1"]:
		# Críticas: frenado cortito (si no, el remate avanzaba de más y te
		# quitaba tiempo de reacción).
		_freeze_t = FREEZE_TIME * 0.4
	else:
		_freeze_t = FREEZE_TIME
	var t: Array = PAUSE_TEXT.get(reason, ["¿Qué haces?", ""])
	hud.paused = true
	hud.decision_title = String(t[0])
	hud.decision_hint = String(t[1]) if String(t[1]) != "" else _hint(ball.owner_p == user)
	hud.hint = hud.decision_hint
	overlay.queue_redraw()

func _resume() -> void:
	if not paused:
		return
	paused = false
	gray.visible = false
	_resume_t = m_t
	world.process_mode = Node.PROCESS_MODE_INHERIT
	_freeze_t = 0.0
	_ramp_t = RAMP_TIME if SLOWMO else 0.0
	hud.paused = false
	overlay.queue_redraw()

func _paused_tick() -> void:
	overlay.queue_redraw()
	# El teclado (PC) también decide.
	if hud.keys.length() > 0.1:
		_resume()
	elif auto_resume >= 0.0 and Time.get_ticks_msec() - _pause_ms > int(auto_resume * 1000.0):
		_resume()

## ¿Hay que frenar la jugada para que decidas?
## Ritmo de las pausas (fluidez): las CRÍTICAS (remate a tu arco, balón
## aéreo que te llega, mano a mano) pueden saltar 0,8 s después de reanudar;
## las demás necesitan 1,6 s de juego corrido y no más de 4 por jugada.
const PAUSE_GAP := 1.6
const PAUSE_MAX := 4

func _check_pause() -> void:
	if paused or state != "moment" or m_t - _resume_t < 0.8:
		return
	var calm: bool = m_t - _resume_t >= PAUSE_GAP and stat_pauses < PAUSE_MAX
	var o: Player = ball.owner_p
	# Arquero: remate rival en camino a tu arco, o mano a mano.
	if user.is_gk():
		if m_kind == "penalty":
			return
		if not m_shot.is_empty() and m_shot["by"].team.side == 1 and not m_shot.get("paused", false):
			m_shot["paused"] = true
			_pause("gk_shot")
			return
		if o != null and o.team.side == 1 and o.position.distance_to(Cfg.own_goal(0)) < 20.0 * Cfg.M and m_t - _duel_t > 3.0:
			_duel_t = m_t
			_pause("gk_1v1")
		return
	# Te presionan con el balón: ¿pasas, tiras o cambias de rumbo?
	if calm and o == user and m_t - _press_t > 2.2:
		for r in teams[1].players:
			if not r.is_gk() and r.position.distance_to(user.position) < 3.5 * Cfg.M:
				_press_t = m_t
				run_target = Vector2.INF
				_pause("pressure")
				return
	# Te llega un balón por el aire.
	if ball.is_free() and ball.receiver == user and ball.z > 0.6 * Cfg.M and ball.kick_time != _paused_kick:
		if user.position.distance_to(ball.position) < 6.0 * Cfg.M:
			_paused_kick = ball.kick_time
			_pause("incoming")
			return
	# Un compañero recibió: ¿te desmarcas o la pides?
	# (Solo si estás cerca para participar y no vas corriendo a un punto.)
	if calm and o != null and o.team.side == 0 and o != user and o != _paused_mate and not o.holding and m_phase == "attack" 			and run_target == Vector2.INF and o.position.distance_to(user.position) < 28.0 * Cfg.M:
		_paused_mate = o
		_pause("mate")
		return
	# Un rival te encara.
	if calm and o != null and o.team.side == 1 and o.position.distance_to(user.position) < 5.0 * Cfg.M and m_t - _duel_t > 2.5:
		_duel_t = m_t
		_pause("duel")

## Marcas en la cancha mientras la jugada está pausada.
func _draw_marks() -> void:
	if state != "moment":
		return
	# Destino que tocaste (avanzar hasta ahí).
	if run_target != Vector2.INF:
		var k: float = 4.0
		var c := Color(1, 1, 1, 0.85)
		overlay.draw_line(run_target + Vector2(-k, -k), run_target + Vector2(k, k), c, 2.0)
		overlay.draw_line(run_target + Vector2(-k, k), run_target + Vector2(k, -k), c, 2.0)
		overlay.draw_dashed_line(user.position, run_target, Color(1, 1, 1, 0.35), 1.5, 5.0)
	if not paused:
		return
	var pulse: float = 0.55 + 0.45 * sin(float(Time.get_ticks_msec()) / 160.0)
	var ov := overlay
	_ring(ov, user.position, 15.0 + pulse * 3.0, Color(1, 0.92, 0.2, 0.9), 2.5)
	var o: Player = ball.owner_p
	if o == user or pause_reason == "locked":
		# Compañeros para pasar: verde si la línea está libre, naranja si está tapada.
		for t in user.team.players:
			if t == user or t.is_gk():
				continue
			if t.position.distance_to(user.position) > 40.0 * Cfg.M:
				continue
			var free: bool = user.team._lane_free(user.position, t.position) > 1.2 * Cfg.M
			var col := Color(0.35, 1.0, 0.45, 0.85) if free else Color(1.0, 0.6, 0.2, 0.7)
			var offs: bool = user.team.is_offside(t, user.position)
			if offs:
				col = Color(0.75, 0.75, 0.75, 0.55)
				ov.draw_string(ThemeDB.fallback_font, t.position + Vector2(-9, 14), "OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.4, 0.35))
			_ring(ov, t.position, 10.0 + pulse * 2.0, col, 2.0)
			ov.draw_line(user.position, t.position, Color(col, 0.18), 1.0)
			# Número arriba de la cabeza (como WSC).
			var np: Vector2 = t.position + Vector2(-6, -52 * Cfg.PLAYER_SCALE)
			ov.draw_rect(Rect2(np + Vector2(-2, -10), Vector2(16, 12)), Color(0, 0, 0, 0.55))
			ov.draw_string(ThemeDB.fallback_font, np, str(t.number), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
			var ec: Color = Color(0.3, 0.95, 0.4) if t.energy > 0.6 else (Color(1, 0.85, 0.2) if t.energy > 0.4 else Color(1, 0.35, 0.3))
			ov.draw_rect(Rect2(np + Vector2(-2, 3), Vector2(16, 2)), Color(0, 0, 0, 0.6))
			ov.draw_rect(Rect2(np + Vector2(-2, 3), Vector2(16.0 * t.energy, 2)), ec)
		# Arco: zona a la que apuntar.
		var g: Vector2 = Cfg.target_goal(0)
		if user.position.distance_to(g) < 40.0 * Cfg.M:
			var a := Vector2(g.x - Cfg.GOAL_W * 0.5, g.y)
			var b := Vector2(g.x + Cfg.GOAL_W * 0.5, g.y)
			ov.draw_line(a, b, Color(1, 0.3, 0.3, 0.5 + 0.4 * pulse), 4.0)
			ov.draw_dashed_line(user.position, g, Color(1, 1, 1, 0.35), 1.5, 6.0)
	elif o != null and o.team.side == 0:
		_ring(ov, o.position, 12.0, Color(0.4, 0.8, 1.0, 0.8), 2.0)
		# Espacio libre sugerido para el desmarque.
		var ahead: Vector2 = user.position + Vector2(0, -9.0 * Cfg.M)
		ov.draw_circle(ahead, 5.0 + pulse * 2.0, Color(1, 1, 1, 0.25))
		ov.draw_dashed_line(user.position, ahead, Color(1, 1, 1, 0.4), 1.5, 5.0)
	elif o != null:
		# Rival que te encara.
		_ring(ov, o.position, 13.0 + pulse * 2.0, Color(1, 0.25, 0.25, 0.9), 2.5)
		ov.draw_dashed_line(user.position, o.position, Color(1, 0.4, 0.4, 0.6), 1.5, 5.0)
	if ball.is_free():
		# Hacia dónde va el balón.
		var land: Vector2 = ball.position + ball.vel * clampf(ball.vz / Cfg.GRAVITY * 2.0, 0.2, 1.2)
		if ball.z < 0.1 * Cfg.M:
			land = ball.predict(0.6)
		ov.draw_dashed_line(ball.position, land, Color(1, 1, 1, 0.5), 1.5, 4.0)
		_ring(ov, land, 6.0 + pulse * 2.0, Color(1, 1, 1, 0.7), 1.5)
		if pause_reason == "gk_shot":
			# Línea del remate hasta tu arco.
			var g2: Vector2 = Cfg.own_goal(0)
			var tt: float = absf((g2.y - ball.position.y) / maxf(absf(ball.vel.y), 1.0))
			var cross := Vector2(ball.position.x + ball.vel.x * tt, g2.y)
			ov.draw_line(ball.position, cross, Color(1, 0.3, 0.3, 0.8), 2.0)
			_ring(ov, cross, 7.0 + pulse * 3.0, Color(1, 0.3, 0.3, 0.9), 2.0)

func _ring(ov: Node2D, at: Vector2, r: float, col: Color, w: float) -> void:
	ov.draw_set_transform(at, 0.0, Vector2(1.0, 0.45))
	ov.draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, col, w)
	ov.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ================================================================ centros

## ¿Es un centro? Desde la banda, en el último tercio, hacia el área rival.
func _is_cross(from: Vector2, to: Vector2) -> bool:
	var wide: bool = from.x < Cfg.FIELD_W * 0.24 or from.x > Cfg.FIELD_W * 0.76
	var deep: bool = Cfg.depth_of(0, from) > 0.66
	var in_box: bool = absf(to.x - Cfg.FIELD_W * 0.5) < Cfg.BOX_W * 0.5 and to.y < Cfg.BOX_H + 2.0 * Cfg.M
	return wide and deep and in_box

## Centro bombeado al punto: cae a la altura de la cabeza / del pecho.
func _cross_to(p: Player, spot: Vector2, recv: Player) -> void:
	var to: Vector2 = spot - p.position
	var d: float = maxf(to.length(), 1.0)
	var T: float = clampf(d / (15.0 * Cfg.M), 0.75, 1.5)
	var err: float = randf_range(-1.0, 1.0) * (0.08 - p.st("passing") / 100.0 * 0.06)
	kick_ball(p, to.normalized().rotated(err) * d / T * 1.06, 0.5 * Cfg.GRAVITY * T * 1.05, 0.0, "lob", recv, "pase")
	hud.flash("¡Centro!", 0.6)

# ================================================================ regate

func _on_scribble() -> void:
	if state != "moment":
		return
	if paused:
		_resume()
	if ball.owner_p == user and not user.busy():
		_do_regate(user)

## Amague hacia el lado contrario al rival más cercano.
func _do_regate(u: Player) -> void:
	var near: Player = null
	var nd: float = INF
	for o in teams[1].players:
		var od: float = o.position.distance_to(u.position)
		if od < nd:
			nd = od
			near = o
	var side_dir: Vector2 = u.facing.orthogonal()
	if near != null and (near.position - u.position).dot(side_dir) > 0.0:
		side_dir = -side_dir
	u.start_regate(side_dir)
	guard_t = maxf(guard_t, 0.45)
	run_target = Vector2.INF
	if m_action == "":
		m_action = "dribble"
	hud.flash("¡Regate!", 0.5)

# ================================================================ estilo WSC

const SIM_ZOOM := 0.62
const SIM_ZOOM_WIDE := 0.5
const CAM_ZOOM_WIDE := 0.92

## ¿Pantalla ancha (versión horizontal)?
func is_wide() -> bool:
	var s: Vector2 = get_viewport().get_visible_rect().size
	return s.x > s.y
const GRAY_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(l * 0.92 + 0.04), 1.0);
}
"""
var gray: ColorRect
var goal_card: CanvasLayer

## Partido de fondo entre momentos: la IA juega sola (tu jugador también).
## Lo que pase acá no cuenta: el resultado lo decide el MatchEngine.
func _sim_tick(dt: float) -> void:
	for t in teams:
		t.think(dt, ball, null)
	_step_players(dt)
	_step_refs(dt)
	var prev_i: Vector3 = Vector3(ball.position.x, ball.position.y, ball.z)
	ball.step(dt)
	_owned_ball_clear()
	_net_collide(prev_i)
	_interactions()
	_owned_ball_clear()
	if not _stage.is_empty():
		_stage_tick(dt)
		return
	var b: Vector2 = ball.position
	if b.x < 0.0 or b.x > Cfg.FIELD_W or b.y < 0.0 or b.y > Cfg.FIELD_H:
		# Salió o fue "gol": saque rápido desde el punto más cercano adentro.
		var kp: Player = teams[randi() % 2].best_interceptor(ball)
		var spot := Vector2(clampf(b.x, 2.0 * Cfg.M, Cfg.FIELD_W - 2.0 * Cfg.M), clampf(b.y, 6.0 * Cfg.M, Cfg.FIELD_H - 6.0 * Cfg.M))
		kp.position = spot - Cfg.attack_dir(kp.team.side) * 0.7 * Cfg.M
		ball.position = spot
		ball.z = 0.0
		ball.take(kp)
		kp.holding = false
		kp.think_cd = 0.5

# ================================================================ partido de fondo dirigido

## El partido de fondo sigue a la NARRACIÓN (antes era un partido aparte:
## decía "ataca el rival" y en la cancha atacaba tu equipo). Las jugadas
## grandes (gol, ocasión, falta, córner...) se arman como una escena corta
## y avisan `staged` al terminar; las chicas (posesión) solo encaminan.
signal staged

var _stage: Dictionary = {}
var _force_save_side: int = -1
var last_stage: Dictionary = {}   # la última escena terminada (para pruebas)
var idle_zoom: float = -1.0        # zoom del partido de fondo (si lo fija quien lo muestra)

func stage(kind: String, ours: bool) -> void:
	if state != "idle":
		staged.emit.call_deferred()
		return
	var side: int = 0 if ours else 1
	var att: Team = teams[side]
	var dfn: Team = teams[1 - side]
	_force_save_side = -1
	_stage = {"kind": kind, "side": side, "t": 0.0, "end_t": -1.0}
	match kind:
		"goal", "chance", "long_shot":
			var depth: float = randf_range(0.76, 0.84) if kind != "long_shot" else randf_range(0.66, 0.7)
			var spot: Vector2 = Cfg.form_to_world(side, randf_range(0.32, 0.68), depth)
			Scenarios._place_all(self, spot, side)
			var sh: Player = _pick(att, ["FW", "MF"])
			Scenarios._give(self, sh, spot)
			sh.think_cd = 9.0
			_stage["shooter"] = sh
			# Un defensor llega tarde (se ve la jugada, no un tiro solo): no
			# alcanza a quitársela antes del remate que narra el relato.
			var gg: Vector2 = Cfg.target_goal(side)
			for o in dfn.players:
				if not o.is_gk() and o.position.distance_to(spot) < 3.0 * Cfg.M:
					o.position = spot + (o.position - spot).normalized() * 3.0 * Cfg.M
				o.tackle_cd = maxf(o.tackle_cd, 2.0)
				# Escena de GOL (corte de cámara: no se ve): el corredor del
				# remate queda libre; la defensa viene de costado, tarde.
				if kind == "goal" and not o.is_gk():
					o.no_touch = 2.0
					var q: Vector2 = Geometry2D.get_closest_point_to_segment(o.position, spot, gg)
					if q.distance_to(o.position) < 3.5 * Cfg.M:
						var aw: Vector2 = (o.position - q).normalized() if o.position.distance_to(q) > 0.2 else (gg - spot).orthogonal().normalized()
						o.position = q + aw * 3.5 * Cfg.M
			_cut_to(spot)
		"corner":
			var g: Vector2 = Cfg.target_goal(side)
			var flag := Vector2(0.0 if randf() < 0.5 else Cfg.FIELD_W, g.y)
			var box: Vector2 = Cfg.form_to_world(side, 0.5, 0.88)
			Scenarios._place_all(self, box, side)
			var cr: Player = _pick(att, ["MF", "FW"])
			# La pelota en el arco del córner (adentro) y el que patea mirando al área.
			var cspot: Vector2 = flag + Vector2(signf(Cfg.FIELD_W * 0.5 - flag.x), -Cfg.attack_dir(side).y) * 0.6 * Cfg.M
			Scenarios._give(self, cr, cspot)
			cr.position = cspot - (box - cspot).normalized() * 0.7 * Cfg.M
			cr.face(box - cr.position)
			ball.position = cspot
			cr.think_cd = 9.0
			cr.stun = 0.42          # quieto hasta patear (si no, salía conduciendo)
			# En un córner nadie se acerca al que patea (9 m).
			for o in dfn.players:
				if o.position.distance_to(cspot) < 9.0 * Cfg.M:
					o.position = cspot + (o.position - cspot).normalized() * 9.0 * Cfg.M
			_stage["shooter"] = cr
			_stage["box"] = box
			_cut_to(flag.lerp(box, 0.5))
		"foul", "card":
			var at: Vector2 = Cfg.form_to_world(side, randf_range(0.2, 0.8), randf_range(0.35, 0.65))
			Scenarios._place_all(self, at, 1 - side)
			var victim: Player = _pick(dfn, ["MF", "FW"])
			Scenarios._give(self, victim, at)
			var culprit: Player = _pick(att, ["MF", "DF"])
			culprit.position = at + Vector2(0.8 * Cfg.M, 0.4 * Cfg.M)
			culprit.start_tackle(victim.position - culprit.position)
			victim.think_cd = 9.0
			_stage["victim"] = victim
			_stage["end_t"] = 2.2
			_cut_to(at)
		"keeper":
			var k: Player = att.gk()
			Scenarios._place_all(self, Cfg.form_to_world(side, 0.5, 0.25), side)
			Scenarios._give(self, k, Cfg.form_to_world(side, 0.5, 0.06))
			k.holding = true
			k.think_cd = 1.0
			_stage["end_t"] = 2.4
			_cut_to(k.position + Cfg.attack_dir(side) * 12.0 * Cfg.M)
		_:
			_stage = {}
			staged.emit.call_deferred()

## Corte de cámara a la escena (como un cambio de toma en la TV).
func _cut_to(at: Vector2) -> void:
	cam.position = at
	cam.reset_smoothing()

func _pick(t: Team, roles: Array) -> Player:
	var pool: Array = []
	for r in roles:
		for p in t.players:
			if p.role == r:
				pool.append(p)
		if not pool.is_empty():
			break
	if pool.is_empty():
		pool = t.players.slice(1)
	return pool[randi() % pool.size()]

## Punto del arco (del lado `s2`) con la línea de tiro más limpia.
func _open_target(sh: Player, g: Vector2, s2: float, dfn: Team) -> float:
	var best: float = g.x + s2 * (Cfg.GOAL_W * 0.5 - 1.0 * Cfg.M) * 0.8
	var best_c: float = -1.0
	for i in 9:
		var f: float = lerpf(0.15, 0.95, float(i) / 8.0)
		var tx: float = g.x + s2 * (Cfg.GOAL_W * 0.5 - 1.0 * Cfg.M) * f
		var c: float = INF
		for o in dfn.players:
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(o.position, sh.position, Vector2(tx, g.y))
			c = minf(c, q.distance_to(o.position))
		# Aire en la línea (hasta 2 m cuenta) y, a igual aire, cerca del palo.
		var sc: float = minf(c, 2.0 * Cfg.M) - absf(f - 0.8) * 0.6 * Cfg.M
		if sc > best_c:
			best_c = sc
			best = tx
	return best

## Escena de gol: los defensores que tapan la línea de tiro se corren (llegan
## tarde) en los instantes antes del remate.
func _clear_shot_lane(sh: Player, target: Vector2, dfn: Team, dt: float) -> void:
	for o in dfn.players:
		if o.is_gk():
			continue
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(o.position, sh.position, target)
		var d: float = q.distance_to(o.position)
		if d < 2.0 * Cfg.M:
			var away: Vector2 = (o.position - q).normalized() if d > 0.2 else (target - sh.position).orthogonal().normalized()
			o.vel = away * 8.0 * Cfg.M
			o.position += away * 8.0 * Cfg.M * dt
			o.face(sh.position - o.position)

func _stage_tick(dt: float) -> void:
	var st: Dictionary = _stage
	st["t"] = float(st["t"]) + dt
	var t: float = st["t"]
	var side: int = st["side"]
	var kind: String = st["kind"]
	var g: Vector2 = Cfg.target_goal(side)
	var keeper: Player = teams[1 - side].gk()
	var lane_ok: bool = true
	if kind == "goal" and not st.has("shot"):
		var shp: Player = st["shooter"]
		var sg: float = -1.0 if keeper.position.x > g.x else 1.0
		var tgt := Vector2(_open_target(shp, g, sg, teams[1 - side]), g.y)
		_clear_shot_lane(shp, tgt, teams[1 - side], dt)
		# Patea recién con el hueco libre (si no, un paso más, hasta 1,4 s).
		for o in teams[1 - side].players:
			if not o.is_gk() and Geometry2D.get_closest_point_to_segment(o.position, shp.ball_spot(), tgt).distance_to(o.position) < BODY_R + 0.4 * Cfg.M:
				lane_ok = false
	if kind in ["goal", "chance", "long_shot"] and not st.has("shot") and t >= 0.65 and (lane_ok or t >= 1.4):
		st["shot"] = true
		st["t_shot"] = t
		var sh: Player = st["shooter"]
		if ball.owner_p == sh:
			var s2: float = -1.0 if keeper.position.x > g.x else 1.0
			if kind == "goal":
				# Al palo contrario del arquero, que se tira tarde y al otro lado,
				# por el hueco con más aire (sin cuerpos en la línea del tiro).
				var tx: float = _open_target(sh, g, s2, teams[1 - side])
				# Remate exacto al hueco (el relato ya cantó el gol): sin el error
				# de puntería, que lo mandaba contra un defensor.
				var sdir: Vector2 = (Vector2(tx, g.y) - sh.ball_spot()).normalized()
				var spd_s: float = lerpf(Cfg.SHOT_MIN, Cfg.SHOT_MAX, 0.85)
				var t_g: float = sh.ball_spot().distance_to(Vector2(tx, g.y)) / spd_s
				kick_ball(sh, sdir * spd_s, 0.5 * Cfg.GRAVITY * t_g + 0.6 * Cfg.M / maxf(t_g, 0.1), 0.0, "shot", null, "remate")
				keeper.no_touch = 2.0
				keeper.start_dive(-s2)
				# Se tiró al otro lado: ese remate lo superó.
				_beaten_gk = keeper
				_beaten_kick = ball.kick_time
				# Escena de GOL: ese remate entra. La defensa llega tarde (no la
				# toca), y el remate busca el hueco libre entre los cuerpos.
				for o in teams[1 - side].players:
					o.no_touch = maxf(o.no_touch, 1.5)
			elif kind == "chance":
				var tx2: float = keeper.position.x + randf_range(-1.6, 1.6) * Cfg.M
				shoot(sh, (Vector2(tx2, g.y) - sh.position).normalized(), 0.75, 0.0, false)
				_force_save_side = 1 - side
			else:
				cpu_shoot(sh)
	if kind == "corner" and not st.has("shot") and t >= 0.45:
		st["shot"] = true
		var cr: Player = st["shooter"]
		if ball.owner_p == cr:
			var box: Vector2 = st["box"] + Vector2(randf_range(-6.0, 6.0) * Cfg.M, 0.0)
			var d: float = cr.position.distance_to(box)
			var T: float = clampf(d / (16.0 * Cfg.M), 0.7, 1.4)
			kick_ball(cr, (box - cr.position).normalized() * d / T * 1.08, 0.5 * Cfg.GRAVITY * T * 1.15, 0.0, "lob", null, "pase")
	if kind in ["foul", "card"] and not st.has("fell") and t >= 0.3:
		st["fell"] = true
		var v: Player = st["victim"]
		v.knock_down()
		ball.release()
		ball.vel = Vector2.ZERO
	# ¿Terminó la escena?
	var b: Vector2 = ball.position
	var out: bool = b.x < -0.5 * Cfg.M or b.x > Cfg.FIELD_W + 0.5 * Cfg.M or b.y < -0.2 * Cfg.M or b.y > Cfg.FIELD_H + 0.2 * Cfg.M
	var in_goal: bool = out and absf(b.x - Cfg.FIELD_W * 0.5) < Cfg.GOAL_W * 0.5 and ball.z < Cfg.GOAL_H_Z
	if in_goal and not st.has("scored"):
		st["scored"] = true
		goals[0 if b.y < Cfg.FIELD_H * 0.5 else 1].ripple(b.x)
		sfx.play("roar")
		_celebrate(teams[side], null)
		st["end_t"] = t + 1.8
	var end_t: float = st["end_t"]
	var finished: bool = false
	if end_t > 0.0:
		finished = t >= end_t
	elif kind in ["chance", "long_shot", "goal"] and st.has("shot"):
		finished = (ball.owner_p != null and ball.owner_p.is_gk()) or out or t > 3.5 			or (kind == "chance" and ball.last_touch == keeper and t > float(st.get("t_shot", 0.0)) + 0.6)
	elif kind == "corner" and st.has("shot"):
		finished = ball.owner_p != null or out or t > 3.0
	elif t > 4.0:
		finished = true
	if finished:
		last_stage = st.duplicate()
		_stage = {}
		_force_save_side = -1
		if out or in_goal:
			_restart_after(in_goal, 1 - side if in_goal else side)
		staged.emit()

## Saque después de una escena: del medio tras un gol (saca el que lo
## recibió); si no, saque de arco del que defendía.
func _restart_after(goal: bool, to_side: int) -> void:
	var t: Team = teams[to_side]
	if goal:
		for tt in teams:
			for p in tt.players:
				p.position = tt.kickoff_spot(p, false)
				p.vel = Vector2.ZERO
		var kp: Player = t.players[9]
		ball.release()
		ball.position = Vector2(Cfg.FIELD_W * 0.5, Cfg.FIELD_H * 0.5)
		ball.z = 0.0
		ball.vel = Vector2.ZERO
		kp.position = ball.position - Cfg.attack_dir(to_side) * 0.7 * Cfg.M
		ball.take(kp)
		kp.think_cd = 0.6
		_cut_to(ball.position)
	else:
		var k: Player = t.gk()
		ball.release()
		ball.z = 0.0
		ball.vel = Vector2.ZERO
		ball.position = Cfg.own_goal(to_side) + Cfg.attack_dir(to_side) * 5.0 * Cfg.M
		ball.take(k)
		k.position = ball.position
		k.holding = true
		k.think_cd = 0.8

## Señal chica de la narración. `side`: 0 tu equipo, 1 rival, -1 sin lado.
## Si la posesión no coincide, la pelota cambia de dueño con un pase
## errado hacia el equipo correcto (no se teletransporta).
func cue(kind: String, side: int) -> void:
	if state != "idle" or not _stage.is_empty():
		return
	match kind:
		"corner_no_danger":
			stage("corner", (side if side >= 0 else _poss_side()) == 0)
			return
		"keeper_distribution", "goalkeeper_calm", "keeper_save_routine":
			stage("keeper", (side if side >= 0 else 1 - _poss_side()) == 0)
			return
		"long_range_effort":
			stage("long_shot", (side if side >= 0 else _poss_side()) == 0)
			return
		"foul", "tactical_foul":
			stage("foul", (side if side >= 0 else 1 - _poss_side()) == 0)
			return
	if side < 0:
		return
	var o: Player = ball.owner_p
	if o != null and o.team.side == side:
		return
	var to: Player = teams[side].best_interceptor(ball)
	if to == null:
		return
	if o != null and not o.is_gk():
		# Pase que se le va al rival.
		var d: float = o.position.distance_to(to.position)
		kick_ball(o, (to.position - o.position).normalized() * clampf(sqrt(2.0 * Cfg.ROLL_DECEL * d) + 3.0 * Cfg.M, Cfg.PASS_MIN, Cfg.PASS_MAX), 0.0, 0.0, "pass", to, "pase")
	elif ball.is_free():
		ball.receiver = to

func _poss_side() -> int:
	return ball.owner_p.team.side if ball.owner_p != null else (ball.last_touch.team.side if ball.last_touch != null else 0)

## Festejo: el goleador en grande con "¡¡GOOOOOL!!", quién marcó y la asistencia.
func _show_goal_card(outcome: String) -> void:
	var scorer: Player = ball.last_touch if ball.last_touch != null else user
	var assist: Player = null
	if outcome == "assist_goal":
		assist = user
	var s: Vector2 = get_viewport().get_visible_rect().size
	var wide: bool = is_wide()
	var k: float = 2.2 if wide else 3.4
	var by: float = s.y * (0.08 if wide else 0.2)
	var band := ColorRect.new()
	band.color = Color(0, 0, 0, 0.45)
	band.position = Vector2(0, by)
	band.size = Vector2(s.x, (48.0 * k + 80.0))
	goal_card.add_child(band)
	var big := PlayerSprite.new()
	big.setup(scorer.cfg)
	big.scale = Vector2(k, k)
	big.position = Vector2(s.x * 0.5, by + 46.0 * k)
	goal_card.add_child(big)
	big.set_anim("pitch_festejo", true, 10.0, true)
	var who: String = "¡Marca TU jugador!" if scorer == user else "¡Marca el #%d (%s)!" % [scorer.number, PitchFormations.label(scorer.code)]
	var lines: Array = ["¡¡GOOOOOL!!", who]
	if assist != null:
		lines.append("Asistencia: TU jugador")
	for i in lines.size():
		var l := Label.new()
		l.text = String(lines[i])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(s.x, 24)
		l.position = Vector2(0, by + 46.0 * k + 14.0 + i * 24)
		l.add_theme_font_size_override("font_size", 24 if i == 0 else 13)
		l.add_theme_color_override("font_color", Color(1, 0.95, 0.4) if i == 0 else Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		l.add_theme_constant_override("outline_size", 4)
		goal_card.add_child(l)
	hud.message = ""

# ================================================================ pulido: sonido, fichas, repetición

const REC_MAX := 240               # 4 s a 60 cuadros
var sfx: Sfx
var rec: Array = []
var _replay_pending := false
var _rep_i: float = 0.0
var _zoom_tw: Tween

## Estadísticas de la ficha (de pace/skill del prototipo; en FootballCareer
## salen de PlayerData). Las del rival se ven con "?" como en WSC.
func _stats(p: Player, known: bool) -> String:
	# Con stats reales (PlayerData de FootballLegacy) se muestran las de
	# verdad, tuyas y del rival: comparás antes de decidir.
	if not p.stats.is_empty():
		var ent_r: float = (p.st("strength") + p.st("decision_making")) * 0.5
		return "VEL %d  PAS %d  TIR %d  ENT %d" % [int(p.st("speed")), int(p.st("passing")), int(p.st("shooting")), int(ent_r)]
	if not known:
		return "VEL ?  PAS ?  TIR ?  ENT %d" % int(55 + p.skill * 40)
	var vel: int = int(60 + (p.pace - 0.9) * 200 + p.skill * 10)
	var pas: int = int(50 + p.skill * 45)
	var tir: int = int(45 + p.skill * 50 + (8 if p.role == "FW" else 0))
	var ent: int = int(40 + p.skill * 40 + (15 if p.role == "DF" else 0))
	return "VEL %d  PAS %d  TIR %d  ENT %d" % [clampi(vel, 30, 99), clampi(pas, 30, 99), clampi(tir, 30, 99), clampi(ent, 30, 99)]

## Graba la jugada (posición + cuadro de animación de todos y el balón).
func _record() -> void:
	var f: Array = []
	for t in teams:
		for p in t.players:
			f.append([p.position, p.gfx.anim, p.gfx.frame])
	f.append([ball.position, ball.z, ball.visible])
	rec.append(f)
	if rec.size() > REC_MAX:
		rec.remove_at(0)

## Repetición del gol en cámara lenta, con la "R" como en WSC.
func _start_replay() -> void:
	for ch in goal_card.get_children():
		ch.queue_free()
	state = "replay"
	_rep_i = maxf(0.0, float(rec.size()) - 200.0)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	hud.replay = true
	hud.message = ""
	ball.trail.clear()

func _replay_tick() -> void:
	var i: int = int(_rep_i)
	if i >= rec.size():
		_end_replay()
		return
	var f: Array = rec[i]
	var k: int = 0
	for t in teams:
		for p in t.players:
			var e: Array = f[k]
			p.position = e[0]
			if String(e[1]) != "":
				p.gfx.set_anim(String(e[1]), false, 0.001)
				p.gfx.frame = int(e[2])
				p.gfx._apply_frame()
			k += 1
	var b: Array = f[k]
	ball.position = b[0]
	ball.z = b[1]
	ball._update_visual()
	ball.visible = bool(b[2])
	cam.position = ball.position + Vector2(0, -ball.z * Cfg.Z_PROJ)
	_rep_i += 0.5                  # cámara lenta x0,5

func _end_replay() -> void:
	if state != "replay":
		return
	_replay_pending = false
	show_idle()
	moment_finished.emit(_result)

# ================================================================ stats

## Fuerza para quitar: fuerza + decisión (FootballLegacy no tiene "defensa").
func _tackle_pow(p: Player) -> float:
	return (p.st("strength") * 0.5 + p.st("decision_making") * 0.5) / 100.0

## Fuerza para aguantar el balón: regate + fuerza.
func _hold_pow(p: Player) -> float:
	return (p.st("dribbling") * 0.6 + p.st("strength") * 0.4) / 100.0
