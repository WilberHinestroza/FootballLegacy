class_name Player
extends Node2D
## Un futbolista. La posición del nodo es el punto de los PIES.
## No decide nada por sí mismo: el Team (IA) o el control del usuario le
## ponen `want` (velocidad deseada) y Match hace que patee / barra / ataje.
## Se dibuja con las animaciones de cancha de FootballCareer (PlayerSprite).

var team: Team
var idx: int = 0
var code: String = "MC"           # puesto detallado (POR, DFC, LI, MC, DC...)
var role: String = "MF"           # GK, DF, MF, FW (para la IA)
var base := Vector2.ZERO          # formación: x 0..1, d 0..1 desde la propia portería
var number: int = 0
var pace: float = 1.0
var skill: float = 0.7            # 0..1: precisión, quite, control
var cfg: Dictionary = {}
## Stats del jugador (las de PlayerData en FootballLegacy: speed, stamina,
## strength, control, passing, shooting, dribbling, decision_making,
## composure, overall). Si falta una, se usa `skill` * 100.
var stats: Dictionary = {}

var vel := Vector2.ZERO
var want := Vector2.ZERO
var facing := Vector2.UP
## Dónde está el balón (lo actualiza el partido cada cuadro): el arquero
## lo mira siempre, aunque se mueva de costado o hacia atrás.
static var ball_at := Vector2.INF
var stun: float = 0.0
var slide_t: float = 0.0
var slide_dir := Vector2.ZERO
var tackle_t: float = 0.0         # entrada de pie (estocada corta)
var kick_t: float = 0.0
var kick_kind: String = "pase"    # pase, remate, volea, cabezazo, lanzar, saque_largo
var dive_t: float = 0.0
var dive_dir: float = 0.0
var dive_high := false
var fall_t: float = 0.0
var control_t: float = 0.0
var regate_t: float = 0.0
var celebrate_t: float = 0.0
## Festejo elegido para este gol (vacío = el festejo corriendo de siempre).
var celebrate_anim: String = ""
## Gesto (pedir la pelota, lamento, protesta, puño...): se ve si está casi quieto.
var gesture: String = ""
var gesture_t: float = 0.0
var gesture_cd: float = 0.0
var rush := false                 # arquero saliendo a achicar
## Arquero: en el piso después de estirarse/achicar (no se para de golpe).
var down_t: float = 0.0
## Arquero: atajada con animación propia (al pecho, salto) por un instante.
var catch_t: float = 0.0
var catch_anim: String = ""
## Arquero: achique a los pies (se tira hacia el balón, una sola vez).
var smother_t: float = 0.0
var smother_dir := Vector2.ZERO
## Arquero en guardia (rival con la pelota cerca del arco).
var alert := false
var tackle_cd: float = 0.0
var no_touch: float = 0.0
var think_cd: float = 0.0
## IA sin balón: punto elegido (desmarque) y si va picando al espacio.
var ai_spot := Vector2.INF
var ai_cd: float = 0.0
var ai_run := false
var human: bool = false           # es TU jugador
var pname: String = ""            # nombre corto ("J. Pérez")
var energy: float = 1.0           # 0..1, baja con los minutos
var holding := false              # arquero con el balón en las manos

var gfx: PlayerSprite
var touch_phase: float = 0.0       # conducción: el balón va y vuelve entre toques
var regate_dir := Vector2.ZERO
var _has_ball := false

const KICK_TIME := {"pase": 0.36, "remate": 0.4, "volea": 0.45, "cabezazo": 0.45, "lanzar": 0.5, "saque_largo": 0.55, "control": 0.3}

func setup(t: Team, i: int, pos_code: String, base_pos: Vector2, config: Dictionary) -> void:
	team = t
	idx = i
	code = pos_code
	var b: String = PitchFormations.broad(code)
	role = "FW" if b == "ST" else b
	base = base_pos
	number = i + 1
	cfg = config
	pace = randf_range(0.94, 1.06)
	skill = randf_range(0.6, 0.85)
	facing = Cfg.attack_dir(team.side)
	gfx = PlayerSprite.new()
	gfx.setup(cfg)
	gfx.scale = Vector2.ONE * Cfg.PLAYER_SCALE
	add_child(gfx)
	_anim()

func st(k: String) -> float:
	return float(stats.get(k, skill * 100.0))

func apply_stats(s: Dictionary) -> void:
	stats = s
	if s.has("overall"):
		skill = clampf(float(s["overall"]) / 100.0, 0.3, 0.99)
	if s.has("speed"):
		pace = 0.82 + float(s["speed"]) / 100.0 * 0.36

func is_gk() -> bool:
	return role == "GK"

func max_speed(sprint: bool = false) -> float:
	# El cansancio (energía) frena un poco: la resistencia importa.
	var s: float = Cfg.RUN_SPEED * pace * (0.85 + 0.15 * energy)
	if sprint:
		s *= Cfg.SPRINT_MULT
	if is_gk():
		s *= 0.9
	return s

func busy() -> bool:
	return stun > 0.0 or slide_t > 0.0 or dive_t > 0.0 or tackle_t > 0.0 or fall_t > 0.0 or smother_t > 0.0

## Dónde va el balón cuando lo lleva (un poco delante del pie).
func ball_spot() -> Vector2:
	if holding:
		return position + Vector2(0, -1)
	# Conducción con toques: a velocidad, el balón se adelanta y vuelve al pie
	# (más expuesto a un quite en el toque largo).
	var push: float = 0.0
	if vel.length() > 2.0 * Cfg.M and regate_t <= 0.0:
		var f: float = fposmod(touch_phase, 1.0)
		push = (f / 0.3 if f < 0.3 else (1.0 - f) / 0.7) * 0.75 * Cfg.M * clampf(vel.length() / (6.0 * Cfg.M), 0.3, 1.0)
	return position + facing * (0.55 * Cfg.M + push) + Vector2(0, 1)

func go_to(p: Vector2, urgency: float = 0.6, stop_r: float = 0.4 * Cfg.M) -> void:
	var to: Vector2 = p - position
	var d: float = to.length()
	if d < stop_r:
		want = Vector2.ZERO
		return
	var spd: float = max_speed(urgency > 0.85) * lerpf(0.5, 1.0, clampf(urgency, 0.0, 1.0))
	want = to / d * minf(spd, d * 4.0)

func face(v: Vector2) -> void:
	if v.length() > 0.01:
		facing = v.normalized()

func play_kick(dir: Vector2, kind: String = "pase") -> void:
	face(dir)
	kick_kind = kind
	kick_t = float(KICK_TIME.get(kind, 0.36))
	no_touch = 0.22
	_anim(true)

func start_slide(dir: Vector2) -> void:
	if dir.length() < 0.01:
		dir = facing
	slide_dir = dir.normalized()
	face(slide_dir)
	slide_t = Cfg.SLIDE_TIME
	tackle_cd = 1.0
	_anim(true)

func start_tackle(dir: Vector2) -> void:
	face(dir)
	tackle_t = 0.32
	tackle_cd = 0.7
	_anim(true)

func start_dive(dx: float, high: bool = false) -> void:
	dive_dir = signf(dx) if absf(dx) > 0.01 else (1.0 if randf() < 0.5 else -1.0)
	dive_high = high
	dive_t = 0.6
	_anim(true)

## Regate: amague hacia un costado con arranque (esquiva entradas).
## Arquero: se tira a los pies del delantero (achique). Termina en el piso.
func start_smother(dir: Vector2) -> void:
	smother_dir = dir.normalized()
	smother_t = 0.4
	_anim(true)

## Arquero: atajada con su animación (al pecho o en el aire).
func play_catch(high: bool) -> void:
	catch_anim = "gk_salto" if high else "gk_atajada"
	catch_t = 0.45
	_anim(true)

func start_regate(side_dir: Vector2) -> void:
	regate_dir = side_dir.normalized()
	regate_t = 0.55
	_anim(true)

func knock_down() -> void:
	fall_t = 0.9
	stun = 0.9
	_anim(true)

func step(dt: float, has_ball: bool) -> void:
	_has_ball = has_ball
	stun = maxf(stun - dt, 0.0)
	kick_t = maxf(kick_t - dt, 0.0)
	tackle_cd = maxf(tackle_cd - dt, 0.0)
	no_touch = maxf(no_touch - dt, 0.0)
	think_cd = maxf(think_cd - dt, 0.0)
	control_t = maxf(control_t - dt, 0.0)
	regate_t = maxf(regate_t - dt, 0.0)
	celebrate_t = maxf(celebrate_t - dt, 0.0)
	gesture_t = maxf(gesture_t - dt, 0.0)
	gesture_cd = maxf(gesture_cd - dt, 0.0)
	fall_t = maxf(fall_t - dt, 0.0)
	down_t = maxf(down_t - dt, 0.0)
	catch_t = maxf(catch_t - dt, 0.0)
	if smother_t > 0.0:
		smother_t -= dt
		vel = smother_dir * 7.5 * Cfg.M * clampf(smother_t / 0.4, 0.2, 1.0)
		if smother_t <= 0.0:
			stun = 0.5
			down_t = 0.5
	elif slide_t > 0.0:
		slide_t -= dt
		var k: float = clampf(slide_t / Cfg.SLIDE_TIME, 0.0, 1.0)
		vel = slide_dir * Cfg.SLIDE_SPEED * k
		if slide_t <= 0.0:
			stun = 0.4
	elif tackle_t > 0.0:
		tackle_t -= dt
		vel = facing * Cfg.RUN_SPEED * 1.2
	elif dive_t > 0.0:
		dive_t -= dt
		vel = Vector2(dive_dir * Cfg.GK_DIVE_SPEED * clampf(dive_t / 0.6, 0.15, 1.0), vel.y * 0.5)
		if dive_t <= 0.0:
			# Queda tirado un instante y se levanta (antes se paraba de golpe).
			stun = 0.45
			down_t = 0.45
	elif stun > 0.0:
		vel = vel.move_toward(Vector2.ZERO, Cfg.ACCEL * 1.4 * dt)
	elif regate_t > 0.0 and regate_dir != Vector2.ZERO:
		# Amague: primero hacia el costado, después sale hacia adelante.
		var k2: float = clampf(regate_t / 0.55, 0.0, 1.0)
		var d: Vector2 = (regate_dir * k2 + facing * (1.2 - k2)).normalized()
		vel = vel.move_toward(d * max_speed(true) * 1.05, Cfg.ACCEL * 2.2 * dt)
	else:
		var w: Vector2 = want
		if has_ball:
			w *= Cfg.DRIBBLE_MULT
		if holding:
			w = Vector2.ZERO
		# Inercia: frenar es más rápido que acelerar y girar en carrera cuesta.
		var acc: float = Cfg.ACCEL
		var sp: float = vel.length()
		# TU jugador responde más rápido al dedo (dar media vuelta tardaba
		# ~1 s); la IA conserva la inercia realista.
		var turn_min: float = 0.72 if human else 0.45
		if w.length() < sp - 0.5 * Cfg.M:
			acc *= 1.8 if human else 1.5
		elif sp > 2.0 * Cfg.M and w.length() > 0.1:
			var dot: float = vel.normalized().dot(w.normalized())
			acc *= lerpf(turn_min, 1.0, (dot + 1.0) * 0.5)
		if human:
			acc *= 1.15
		if has_ball:
			acc *= 0.85
		vel = vel.move_toward(w, acc * dt)
		if vel.length() > 0.6 * Cfg.M and kick_t <= 0.0 and not (is_gk() and ball_at != Vector2.INF):
			facing = facing.slerp(vel.normalized(), clampf(dt * 14.0, 0.0, 1.0)).normalized()
	# El ARQUERO mira la pelota siempre (antes miraba hacia donde caminaba y,
	# al volver a su arco, quedaba de espaldas al juego). Mientras se tira,
	# patea o la tiene en la mano, manda esa animación.
	if is_gk() and ball_at != Vector2.INF and dive_t <= 0.0 and kick_t <= 0.0 and not holding and smother_t <= 0.0 and down_t <= 0.0:
		var to_b: Vector2 = ball_at - position
		if to_b.length() > 0.5 * Cfg.M:
			facing = facing.slerp(to_b.normalized(), clampf(dt * 10.0, 0.0, 1.0)).normalized()
	if has_ball:
		touch_phase += vel.length() * dt / (2.4 * Cfg.M)
	position += vel * dt
	position.x = clampf(position.x, -Cfg.MARGIN, Cfg.FIELD_W + Cfg.MARGIN)
	position.y = clampf(position.y, -Cfg.MARGIN, Cfg.FIELD_H + Cfg.MARGIN)
	_anim()
	queue_redraw()

# ---------------------------------------------------------------- animación

func _anim(restart: bool = false) -> void:
	if gfx == null:
		return
	var spd: float = vel.length()
	if is_gk():
		_anim_gk(spd, restart)
		return
	if fall_t > 0.0:
		gfx.set_anim(PlayerSprite.resolve("caida" if fall_t > 0.35 else "levanta", facing), false, 12.0, restart)
	elif slide_t > 0.0:
		gfx.set_anim(PlayerSprite.resolve("barrida", slide_dir), false, 18.0, restart)
	elif tackle_t > 0.0:
		gfx.set_anim(PlayerSprite.resolve("entrada", facing), false, 24.0, restart)
	elif kick_t > 0.0:
		var name: String = "pitch_volea" if kick_kind == "volea" else PlayerSprite.resolve(kick_kind if kick_kind in ["pase", "remate", "cabezazo"] else "pase", facing)
		var frames: int = maxi(PitchAvatar.frame_count(name), 1)
		# El cabezazo de costado termina tirado en el piso (palomita): en un
		# cabezazo común se cortaba de golpe parado. Solo el salto y el golpe.
		if name in ["pitch_cabezazo_e", "pitch_cabezazo_w"]:
			frames = mini(frames, 6)
		gfx.set_anim(name, false, float(frames) / float(KICK_TIME.get(kick_kind, 0.36)), restart)
	elif control_t > 0.0:
		gfx.set_anim(PlayerSprite.resolve("control", facing), false, 20.0, restart)
	elif regate_t > 0.0:
		gfx.set_anim(PlayerSprite.resolve("regate", facing), false, 18.0, restart)
	elif celebrate_t > 0.0:
		if celebrate_anim != "" and spd < 2.0 * Cfg.M:
			gfx.set_anim(celebrate_anim, false, 9.0, restart)
		else:
			gfx.set_anim("pitch_festejo", true, 10.0, restart)
	elif gesture_t > 0.0 and gesture != "" and spd < 2.6 * Cfg.M and not _has_ball:
		gfx.set_anim(gesture, false, 12.0 if gesture == "pitch_pide" else 10.0)
	elif _has_ball and spd > 0.4 * Cfg.M:
		gfx.set_anim(PlayerSprite.resolve("drib", facing), true, 12.0)
		gfx.speed_scale = clampf(spd / (5.5 * Cfg.M), 0.6, 1.5)
	elif spd > 4.2 * Cfg.M:
		gfx.set_anim(PlayerSprite.resolve("run8", facing), true, 13.0)
		gfx.speed_scale = clampf(spd / (6.8 * Cfg.M), 0.7, 1.5)
	elif spd > 0.5 * Cfg.M:
		gfx.set_anim(PlayerSprite.resolve("trote", facing), true, 10.0)
		gfx.speed_scale = clampf(spd / (3.0 * Cfg.M), 0.6, 1.4)
	else:
		gfx.set_anim(PlayerSprite.resolve("idle", facing), true, 1.0)
		gfx.speed_scale = 1.0

## Hace un gesto por `secs` segundos (si no tiene otro más importante).
func play_gesture(g: String, secs: float, cd: float = 0.0) -> void:
	if is_gk() and not g.begins_with("gk_"):
		return
	gesture = g
	gesture_t = secs
	gesture_cd = maxf(gesture_cd, cd)

## Pose fija (con el mundo en pausa): el último cuadro del gesto ya visible.
func pose_gesture(g: String, secs: float) -> void:
	play_gesture(g, secs)
	if gfx == null or is_gk() or busy() or _has_ball:
		return
	gfx.set_anim(g, false, 12.0, true)
	gfx.frame = maxi(PitchAvatar.frame_count(g) - 1, 0)
	gfx._apply_frame()

func _anim_gk(spd: float, restart: bool) -> void:
	var n: String = "_n" if facing.y < 0.0 else ""
	if dive_t > 0.0:
		var nm: String = ("gk_volada" + n) if dive_high else ("gk_estirada_%s%s" % ["der" if dive_dir > 0.0 else "izq", n])
		gfx.set_anim(nm, false, 16.0, restart)
	elif smother_t > 0.0:
		gfx.set_anim("gk_achique" + n, false, 20.0, restart)
	elif down_t > 0.0:
		pass   # sigue en el último cuadro de la estirada / el achique (en el piso)
	elif kick_t > 0.0:
		var k: String = "gk_lanzar" if kick_kind == "lanzar" else ("gk_saque_largo" if kick_kind in ["saque_largo", "remate"] else ("gk_punos" if kick_kind == "punos" else ""))
		if k != "":
			gfx.set_anim(k + n, false, 16.0, restart)
		else:
			gfx.set_anim(PlayerSprite.resolve("pase", facing), false, 20.0, restart)
	elif catch_t > 0.0 and catch_anim != "":
		gfx.set_anim(catch_anim + ("" if catch_anim == "gk_salto" else n), false, 18.0, restart)
	elif holding:
		# De espaldas, el cuadro "con el balón" dibuja pelota y guantes sobre
		# la espalda (parecían las manos atrás): de espaldas la pelota queda
		# tapada por el cuerpo, así que va la pose quieta.
		gfx.set_anim("gk_idle_north" if n != "" else "gk_hold", true, 6.0)
	elif spd > 0.5 * Cfg.M:
		# Volviendo al arco: retrocede de frente a la pelota (paso lateral),
		# no se da vuelta para correr. Saliendo rápido (achique, cortar un
		# pase): corre. Acomodándose despacio: en guardia.
		var back: bool = vel.dot(Cfg.attack_dir(team.side)) < -0.3 * spd
		if absf(vel.x) > absf(vel.y) * 1.2 or (back and spd < 6.0 * Cfg.M):
			var dx: float = vel.x if absf(vel.x) > 0.3 * Cfg.M else 1.0
			gfx.set_anim("gk_paso_%s%s" % ["der" if dx > 0.0 else "izq", n], true, clampf(spd / Cfg.M * 2.2, 6.0, 14.0))
		elif rush or spd > 3.5 * Cfg.M:
			gfx.set_anim(PlayerSprite.resolve("run8", vel), true, 12.0)
			gfx.speed_scale = clampf(spd / (6.8 * Cfg.M), 0.7, 1.4)
		else:
			gfx.set_anim("gk_alerta" + n, true, 7.0)
	elif alert:
		gfx.set_anim("gk_alerta" + n, true, 6.0)
	else:
		var d4: String = "north" if facing.y < 0.0 else "south"
		if absf(facing.x) > absf(facing.y) * 1.5:
			d4 = "east" if facing.x > 0.0 else "west"
		gfx.set_anim("gk_idle_" + d4, true, 4.0)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 7.0 * Cfg.PLAYER_SCALE, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if human:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, 11.0 * Cfg.PLAYER_SCALE, 0.0, TAU, 24, Color(1.0, 0.92, 0.2), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Flechita sobre la cabeza: así te encuentras rápido.
		var top := Vector2(0, -46 * Cfg.PLAYER_SCALE)
		draw_colored_polygon(PackedVector2Array([top, top + Vector2(-4, -6), top + Vector2(4, -6)]), Color(1.0, 0.92, 0.2))
