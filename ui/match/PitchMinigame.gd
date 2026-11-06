extends RefCounted
class_name PitchMinigame

## Minijuegos INTERACTIVOS sobre la cancha 2D (pedido de Wilber, 9-oct: "más
## participación mía y no solo la decisión"). La jugada se mueve mientras
## vos actuás; esto solo MIDE lo que hiciste (distancias, segundos de
## diferencia) y lo dibuja — el número de precisión sale de
## DecisionResolver (pitch_*_precision) en Match.gd, nunca de acá.
##
## Modos:
##  "pass"    los rivales cierran líneas de pase; tocás al compañero
##            cuando su línea está libre (verde).
##  "dribble" el defensor se acerca y se inclina hacia un lado; deslizás
##            hacia el lado CONTRARIO justo cuando se tira.
##  "defend"  el rival conduce; la pelota se le separa del pie (brilla) —
##            tocás en ese momento.
##  "keeper"  el delantero patea a un palo; deslizás hacia ese lado.
##  "sweep"   (arquero que sale) tocás cuando sale el pase filtrado.
## Si no hacés nada, a los TIMEOUT segundos se resuelve solo (toque flojo):
## el partido nunca se traba esperando.

signal done(result: Dictionary)

const TIMEOUT := 6.0
const SWIPE_PX := 20.0   # 10-oct: 26 → 20, deslizar costaba en pantallas chicas

var mode: String = ""
var kind: String = ""
var view = null                 # PitchView
var difficulty: float = 0.5
var speed: float = 1.0
var t: float = 0.0
var finished: bool = false

# Arrastre / toque.
var _press: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _drag_pos: Vector2 = Vector2.ZERO   # px (pantalla) del dedo mientras arrastra

# pass
var _receivers: Array = []
var _defenders: Array = []
var _def_base: Dictionary = {}
var _def_phase: Dictionary = {}
var _def_axis: Dictionary = {}

# pass · PAREDES (10-oct): toques previos antes del pase final. Tocás a un
# compañero libre, te la devuelve unos metros más adelante y la jugada
# sigue; cada pared limpia abre el pase final (DecisionResolver.COMBO_*).
var _combo_total: int = 0        # paredes de esta jugada
var _combo_done: int = 0
var _combo_prior: Array = []     # línea libre de cada toque previo
var _wall: Dictionary = {}       # pared en curso: {t, who, from, user_to, mate_to}
const WALL_GO := 0.30            # segundos de ida
const WALL_BACK := 0.34          # y de vuelta

# live · OPORTUNIDAD EN VIVO (10-oct): sin menú. Atacando: tocar a un
# compañero = pase, deslizar hacia el arco = remate (largo = fuerza),
# deslizar al costado = regate. Defendiendo: tocar = quite de pie,
# deslizar = barrida. Qué gestos valen sale de las opciones del motor.
var options: Array = []
var _live_att: bool = true
var _has_shot: bool = false
var _has_pass: bool = false
var _has_drib: bool = false
var _presser: String = ""
var _runner: String = ""         # compañero que tira la diagonal (puede quedar adelantado)
var _runner_x: float = 0.5
var _run_ph: float = 0.0
var _off_line: float = -1.0      # y del último defensor (línea del fuera de juego)
var _gk_speed: float = 2.0
# DESMARQUE (fase previa cuando te devuelven la pelota): arrastrás el dedo y
# tu jugador corre hacia ahí a SU velocidad mientras todo se mueve; al
# terminar te llega el pase y recién ahí se congela la jugada.
var _phase: String = "act"       # "run" → "pass_in" → "act"
var _press_phase: String = "act" # en qué fase se apoyó el dedo
var _run_left: float = 0.0
var _run_from: String = "m1"     # quién te la devuelve
var _open_dist: float = 0.2      # qué tan libre recibiste
var _pass_t: float = 0.0
var _pass_from: Vector2 = Vector2.ZERO

# dribble
var _lunge_t: float = 0.0
var _lean: int = 1               # -1 izquierda, 1 derecha (lado al que se tira el defensor)
var _d_from: Vector2
var _d_to: Vector2

# defend / sweep (momento justo)
var _expose_t: Array = []        # instantes en que la pelota queda expuesta
var _carrier: String = ""
var _car_from: Vector2
var _car_to: Vector2

# keeper
var _shot_t: float = 0.0
var _shot_side: int = 1
var _shooter: String = "a1"

func start(p_view, p_mode: String, p_kind: String, p_difficulty: float, p_speed: float) -> void:
	view = p_view
	mode = p_mode
	kind = p_kind
	difficulty = clampf(p_difficulty, 0.0, 1.0)
	speed = maxf(0.5, p_speed)
	t = 0.0
	finished = false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match mode:
		"pass":
			for id in ["m1", "m2"]:
				if view.has_actor(id):
					_receivers.append(id)
			for id in ["d1", "d2", "d3", "a1", "a2"]:
				if view.has_actor(id):
					_defenders.append(id)
					_def_base[id] = view.npos(id)
					_def_phase[id] = rng.randf() * TAU
					# Se mueven de costado (perpendicular al arco).
					_def_axis[id] = Vector2(1, 0.25 * (1 if rng.randf() < 0.5 else -1)).normalized()
			_combo_total = DecisionResolver.combo_passes(kind) if _receivers.size() >= 1 else 0
		"live":
			options = (view.live_options as Array).duplicate()
			_live_att = PitchPlays.is_attack(kind)
			if _live_att:
				_has_shot = PitchPlays._first_in(options, PitchPlays.SHOT) != ""
				_has_pass = PitchPlays._first_in(options, PitchPlays.PASS) != ""
				_has_drib = PitchPlays._first_in(options, PitchPlays.DRIBBLE) != ""
				var u: Vector2 = view.npos("user")
				for id in ["m1", "m2"]:
					if view.has_actor(id):
						_receivers.append(id)
				var best_d: float = 9.0
				for id in ["d1", "d2", "d3"]:
					if view.has_actor(id):
						_defenders.append(id)
						if view.npos(id).distance_to(u) < best_d:
							best_d = view.npos(id).distance_to(u)
							_presser = id
				_off_line = 9.0
				for id in _defenders:
					if id == _presser:
						continue
					_def_base[id] = view.npos(id)
					_def_phase[id] = rng.randf() * TAU
					_def_axis[id] = Vector2(1, 0.25 * (1 if rng.randf() < 0.5 else -1)).normalized()
					_off_line = minf(_off_line, view.npos(id).y)
				if _off_line > 8.0:
					_off_line = -1.0
				# La regla de verdad: el penúltimo rival de TODA la cancha.
				if view.offside_line_for("user") > 0.0:
					_off_line = view.offside_line_for("user")
				_lunge_t = DecisionResolver.live_pressure_secs(difficulty) / speed
				_lean = -1 if rng.randf() < 0.5 else 1
				if _presser != "":
					_d_from = view.npos(_presser)
					_d_to = u + (_d_from - u).normalized() * 0.07
				# El compañero más adelantado tira la diagonal sobre la línea.
				if _has_pass and view.has_actor("m1") and _off_line > 0.0 and absf(view.npos("m1").y - _off_line) < 0.10 and view.npos("m1").y < u.y:
					_runner = "m1"
					_runner_x = view.npos("m1").x
					_run_ph = rng.randf() * TAU
				_gk_speed = lerpf(1.5, 2.8, difficulty) * speed
				if bool(view.live_run) and not _receivers.is_empty():
					_phase = "run"
					_run_left = DecisionResolver.RUN_SECS
					_run_from = String(_receivers[0])
					view.set_nball(view.npos(_run_from) + Vector2(0, -0.035))
			else:
				_carrier = "a2" if kind == "interception" else "a1"
				if not view.has_actor(_carrier):
					_carrier = "a1"
				_car_from = view.npos(_carrier)
				_car_to = _car_from + Vector2(rng.randf_range(-0.06, 0.06), -0.10)
				var first_l: float = rng.randf_range(1.1, 1.8) / speed
				_expose_t = [first_l, first_l + rng.randf_range(1.2, 1.7) / speed]
		"dribble":
			_lunge_t = lerpf(2.0, 1.25, difficulty) / speed
			_lean = -1 if rng.randf() < 0.5 else 1
			_d_from = view.npos("d1")
			_d_to = view.npos("user") + (view.npos("d1") - view.npos("user")).normalized() * 0.07
		"defend":
			_carrier = "a2" if kind == "interception" else "a1"
			if not view.has_actor(_carrier):
				_carrier = "a1"
			_car_from = view.npos(_carrier)
			_car_to = _car_from + Vector2(rng.randf_range(-0.06, 0.06), -0.10)
			var first: float = rng.randf_range(1.1, 1.8) / speed
			_expose_t = [first, first + rng.randf_range(1.2, 1.7) / speed]
		"keeper":
			_shooter = "a1"
			_shot_t = rng.randf_range(1.4, 2.1) / speed
			_shot_side = -1 if rng.randf() < 0.5 else 1
			_car_from = view.npos(_shooter)
			_car_to = Vector2(0.5 + _shot_side * 0.02, 0.17)
		"sweep":
			_expose_t = [rng.randf_range(1.2, 1.9) / speed]

## Actores que ESTE minijuego mueve (PitchView no les suma su propia IA).
func driven_ids() -> Array:
	match mode:
		"pass": return _defenders + _receivers
		"live":
			if _live_att:
				return _defenders + _receivers + (["gk"] if _has_shot else [])
			return [_carrier]
		"dribble": return ["d1"]
		"defend": return [_carrier]
		"keeper": return [_shooter]
		"sweep": return ["a1", "a2"]
	return []

func window_hint() -> String:
	match mode:
		"pass":
			if _combo_total > 0:
				return "JUGADA ASOCIADA: tocá a un compañero para tirar la pared — te la devuelve más adelante. Son %d toque%s y después el pase final. Ojo con los rivales que se cruzan." % [_combo_total, "" if _combo_total == 1 else "s"]
			return "Tocá a un compañero, o arrastrá el dedo hacia donde querés el pase. Mirá que no se cruce un rival. Después va la fuerza."
		"live":
			if not _live_att:
				return "TOCÁ cuando la pelota BRILLE = quite limpio.  DESLIZÁ = barrida: llega con más margen, pero si llegás tarde es falta (y puede ser tarjeta)."
			var parts := PackedStringArray()
			if _has_pass:
				parts.append("TOCÁ a un compañero = pase (ojo: te la pueden cortar o puede estar adelantado)")
			if _has_shot:
				parts.append("DESLIZÁ hacia el arco = remate (más largo, más fuerte)")
			if _has_drib:
				parts.append("DESLIZÁ al costado = regate (andá hacia donde haya espacio)")
			if _phase == "run":
				return "DESMARCATE: mantené el dedo apoyado y arrastralo a donde querés ir. Tu jugador corre a su velocidad y los rivales te siguen. Después te llega el pase."
			return "  ·  ".join(parts) + ".  Todo está quieto: mirá la jugada y elegí."
		"dribble": return "Cuando aparezca la flecha verde, deslizá el dedo hacia ESE lado para esquivar al defensor."
		"defend": return "Tocá la pantalla cuando la pelota BRILLE: ahí se le escapa al rival."
		"keeper": return "Deslizá el dedo hacia el palo al que va el remate."
		"sweep": return "Tocá la pantalla cuando la pelota BRILLE para salir a cortar el pase."
	return ""

# --- Ciclo -------------------------------------------------------------

func process(delta: float) -> void:
	if finished:
		return
	t += delta
	var pmode: String = mode
	if mode == "live":
		pmode = "live_att" if _live_att else "defend"
	match pmode:
		"live_att":
			# TODO QUIETO hasta que hacés algo (10-oct, Wilber). Solo se mueve
			# la fase de DESMARQUE, cuando la pelota la tiene un compañero.
			match _phase:
				"run":
					_run_left -= delta
					var me: Vector2 = view.npos("user")
					if _press and _drag_pos != Vector2.ZERO:
						var tgt: Vector2 = view.from_px(view._unzoom(_drag_pos))
						tgt = Vector2(clampf(tgt.x, 0.04, 0.96), clampf(tgt.y, 0.06, 1.2))
						var dv: Vector2 = tgt - me
						if dv.length() > 0.008:
							me += dv.normalized() * minf(dv.length(), float(view.live_run_speed) * delta)
							view.set_npos("user", me)
							view.set_running("user", true)
						else:
							view.set_running("user", false)
					else:
						view.set_running("user", false)
					# Los rivales te siguen: el más cercano te marca, el resto bascula.
					for id in _defenders:
						var dp0: Vector2 = view.npos(id)
						var to_me: Vector2 = me - dp0
						var want: float = 0.055 if id == _presser else 0.16
						if to_me.length() > want:
							view.set_npos(id, dp0 + to_me.normalized() * DecisionResolver.MARKER_SPEED * lerpf(0.75, 1.15, difficulty) * (1.0 if id == _presser else 0.45) * delta)
					view.set_nball(view.npos(_run_from) + Vector2(0, -0.035))
					if _run_left <= 0.0:
						view.set_running("user", false)
						_phase = "pass_in"
						_pass_t = 0.0
						_pass_from = view.nball()
				"pass_in":
					_pass_t += delta
					var k_in: float = clampf(_pass_t / 0.38, 0.0, 1.0)
					view.set_nball(_pass_from.lerp(view.npos("user") + Vector2(0, -0.035), k_in))
					if k_in >= 1.0:
						_phase = "act"
						t = 0.0
						# Qué tan libre recibiste, y quién quedó más cerca.
						_open_dist = 9.0
						for id in _defenders:
							var dd0: float = view.npos(id).distance_to(view.npos("user"))
							if dd0 < _open_dist:
								_open_dist = dd0
								_presser = id
						_off_line = 9.0
						for id in _defenders:
							if id != _presser:
								_off_line = minf(_off_line, view.npos(id).y)
						if _off_line > 8.0:
							_off_line = -1.0
						if view.offside_line_for("user") > 0.0:
							_off_line = view.offside_line_for("user")
				_:
					view.set_nball(view.npos("user") + Vector2(0, -0.035))
		"pass":
			if not _wall.is_empty():
				_wall_process(delta)
			for id in _defenders:
				var amp: float = lerpf(0.05, 0.09, difficulty)
				var w: float = lerpf(1.3, 2.6, difficulty) * speed
				view.set_npos(id, (_def_base[id] as Vector2) + (_def_axis[id] as Vector2) * sin(t * w + float(_def_phase[id])) * amp)
		"dribble":
			var k: float = clampf(t / _lunge_t, 0.0, 1.0)
			var p: Vector2 = _d_from.lerp(_d_to, k)
			if t >= _lunge_t:
				# Se tira al lado que venía marcando.
				p = _d_to + Vector2(_lean * 0.05, 0.02) * clampf((t - _lunge_t) / 0.18, 0.0, 1.0)
			view.set_npos("d1", p)
			if t > _lunge_t + 0.9:
				_finish({"err": 9.0, "correct": false, "timeout": true})
		"defend":
			var k2: float = clampf(t / (_expose_t.back() + 0.6), 0.0, 1.0)
			view.set_npos(_carrier, _car_from.lerp(_car_to, k2) + Vector2(sin(t * 7.0) * 0.008, 0))
			var off: float = 0.035
			if _exposed_now():
				off = 0.075
			view.set_nball(view.npos(_carrier) + Vector2(0, -off))
			if t > float(_expose_t.back()) + 0.9:
				_finish({"err": 9.0, "correct": true, "timeout": true})
		"keeper":
			if t < _shot_t:
				view.set_npos(_shooter, _car_from.lerp(_car_to, clampf(t / _shot_t, 0.0, 1.0)))
				view.set_nball(view.npos(_shooter) + Vector2(0, -0.035))
			else:
				var k3: float = clampf((t - _shot_t) / 0.5, 0.0, 1.0)
				var from: Vector2 = _car_to + Vector2(0, -0.035)
				view.set_nball(from.lerp(Vector2(0.5 + _shot_side * PitchView.GOAL_W * 0.4, 0.0), k3))
			if t > _shot_t + 1.0:
				_finish({"err": 9.0, "correct": false, "timeout": true})
		"sweep":
			# El rival (a2) tiene la pelota y a los _expose_t[0] segundos mete el
			# pase filtrado al espacio; el delantero (a1) pica a buscarla.
			var spot := Vector2(0.53, 0.19)
			if t >= float(_expose_t[0]):
				var k4: float = clampf((t - float(_expose_t[0])) / 0.7, 0.0, 1.0)
				view.set_nball(view.npos("a2").lerp(spot, k4))
				view.set_npos("a1", view.npos("a1").lerp(spot + Vector2(0.02, 0.05), 0.04))
			else:
				view.set_nball(view.npos("a2") + Vector2(0, -0.035))
			if t > float(_expose_t[0]) + 1.0:
				_finish({"err": 9.0, "correct": true, "timeout": true})
	# El ataque congelado no tiene reloj (podés pensar la jugada); queda un
	# tope largo por si la pantalla quedó olvidada.
	var limit: float = 45.0 if (mode == "live" and _live_att) else TIMEOUT
	if t > limit and not finished:
		_finish({"err": 9.0, "correct": false, "timeout": true, "clearance": 0.0})

## Pared en curso: la pelota va al compañero mientras vos picás al espacio,
## y te la devuelve. Al terminar arranca el toque siguiente.
func _wall_process(delta: float) -> void:
	_wall["t"] = float(_wall["t"]) + delta
	var wt: float = float(_wall["t"])
	var who: String = _wall["who"]
	var u_from: Vector2 = _wall["from"]
	var u_to: Vector2 = _wall["user_to"]
	var total: float = WALL_GO + WALL_BACK
	view.set_npos("user", u_from.lerp(u_to, clampf(wt / total, 0.0, 1.0)))
	view.set_npos(who, (_wall["mate_from"] as Vector2).lerp(_wall["mate_to"], clampf(wt / total, 0.0, 1.0)))
	var feet := Vector2(0, -0.035)
	if wt < WALL_GO:
		view.set_nball((u_from + feet).lerp(view.npos(who) + feet, wt / WALL_GO))
	else:
		view.set_nball((view.npos(who) + feet).lerp(u_to + feet, clampf((wt - WALL_GO) / WALL_BACK, 0.0, 1.0)))
	if wt >= total:
		view.set_npos("user", u_to)
		view.set_nball(u_to + feet)
		view.set_running("user", false)
		view.set_running(who, false)
		_wall = {}
		_combo_done += 1
		t = 0.0   # el reloj (TIMEOUT) vuelve a empezar en cada toque
		# La defensa retrocede y se reacomoda hacia la pelota.
		for id in _defenders:
			var base: Vector2 = _def_base[id]
			base += Vector2((u_to.x - base.x) * 0.12, -0.05)
			# Nadie queda encima tuyo: el que estaba pegado te da un paso.
			if base.distance_to(u_to) < 0.11:
				var away: Vector2 = base - u_to
				if away.length() < 0.01:
					away = Vector2(0.4, -1.0)
				base = u_to + away.normalized() * 0.11 + Vector2(0, -0.02)
			_def_base[id] = base

func _start_wall(who: String) -> void:
	var u: Vector2 = view.npos("user")
	var m: Vector2 = view.npos(who)
	# Picás hacia adelante y un poco hacia el lado del compañero.
	var u_to := Vector2(clampf(u.x + signf(m.x - u.x) * 0.025, 0.08, 0.92), maxf(u.y - 0.075, 0.20))
	_wall = {"t": 0.0, "who": who, "from": u, "user_to": u_to, "mate_from": m, "mate_to": Vector2(m.x, maxf(m.y - 0.035, 0.10))}
	view.set_running("user", true)
	view.set_running(who, true)

func _exposed_now() -> bool:
	for e in _expose_t:
		if absf(t - float(e)) <= 0.22:
			return true
	return false

func _nearest_expose_err() -> float:
	var best: float = 9.0
	for e in _expose_t:
		if absf(t - float(e)) < absf(best):
			best = t - float(e)
	return best

# --- Entrada -----------------------------------------------------------

func input(event: InputEvent) -> void:
	if finished:
		return
	var pos := Vector2.ZERO
	var down := false
	var up := false
	if event is InputEventScreenTouch:
		pos = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		down = event.pressed
		up = not event.pressed
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _press:
		_drag_pos = event.position
		return
	else:
		return
	if down and not _press:
		_press = true
		_press_phase = _phase
		_press_pos = pos
		_drag_pos = pos
		return
	if not (up and _press):
		return
	_press = false
	var delta: Vector2 = pos - _press_pos
	# El deslizamiento se mide sobre el eje "ancho de la cancha" tal como se
	# ve en pantalla: en la cámara de siempre es izquierda/derecha; en la de
	# TV o la isométrica sigue a la cancha (10-oct, cámaras).
	var swipe: int = 0
	var ax: Vector2 = view.screen_dir_x()
	var along: float = delta.dot(ax)
	var perp: float = delta.dot(Vector2(-ax.y, ax.x))
	if absf(along) >= SWIPE_PX and absf(along) > absf(perp):
		swipe = 1 if along > 0 else -1
	match mode:
		"live":
			_live_input(pos, delta, swipe)
		"pass":
			if not _wall.is_empty():
				return   # la pelota está viajando
			if delta.length() < SWIPE_PX:
				# Toque: pase al pie del compañero tocado.
				var target: String = view.target_at(view._unzoom(pos))
				if target in _receivers:
					var lane: float = lane_clearance(target)
					if _combo_done < _combo_total:
						# PARED: si la línea está tapada, te la cortan ahí.
						if lane < DecisionResolver.pass_lane_need(difficulty):
							_finish({"clearance": 0.0, "lost": true, "receiver": target, "combo": _combo_done})
						else:
							_combo_prior.append(lane)
							_start_wall(target)
						return
					_finish({"clearance": DecisionResolver.combo_pass_clearance(lane, _combo_prior, difficulty), "receiver": target, "combo": _combo_done})
			else:
				# Arrastre: pase a ESE punto (al espacio). Lo recibe el compañero
				# más cercano; si no hay ninguno cerca, es un pase perdido.
				var to: Vector2 = view.from_px(view._unzoom(pos))
				var best: String = ""
				var best_d: float = 0.16
				for id in _receivers:
					var dd: float = view.npos(id).distance_to(to)
					if dd < best_d:
						best_d = dd
						best = id
				if best == "":
					_finish({"clearance": 0.0, "lost": true, "to": to})
				else:
					_finish({"clearance": DecisionResolver.combo_pass_clearance(clearance_to(to), _combo_prior, difficulty), "receiver": best, "to": to, "combo": _combo_done})
		"dribble":
			if swipe != 0:
				# Bien = hacia el lado CONTRARIO al que se tira el defensor.
				_finish({"err": t - _lunge_t, "correct": swipe == -_lean, "side": swipe})
		"defend", "sweep":
			if swipe == 0:
				_finish({"err": _nearest_expose_err(), "correct": true})
		"keeper":
			if swipe != 0:
				if t < _shot_t:
					_finish({"guess": true, "early_by": _shot_t - t, "correct": swipe == _shot_side, "side": swipe})
				else:
					_finish({"err": t - _shot_t, "correct": swipe == _shot_side, "side": swipe})

## Oportunidad en vivo: el gesto decide QUÉ hacés y qué tan bien.
func _live_input(pos: Vector2, delta: Vector2, swipe: int) -> void:
	if not _live_att:
		_finish({"action": "tackle" if delta.length() < SWIPE_PX else "slide", "err": _nearest_expose_err()})
		return
	if _phase != "act" or _press_phase != "act":
		return   # te estás desmarcando (o ese dedo venía del desmarque): todavía no es una jugada
	if delta.length() < SWIPE_PX:
		# El compañero MÁS CERCANO al toque (no "lo que haya debajo": un
		# rival parado encima del compañero se comía el toque).
		if _has_pass:
			var tp: Vector2 = view._unzoom(pos)
			var near: String = ""
			var near_d: float = 46.0
			for id in _receivers:
				var dd: float = view.to_px(view.npos(id)).distance_to(tp)
				if dd < near_d:
					near_d = dd
					near = id
			if near != "":
				_live_pass(near)
		return
	var a: Vector2 = view.from_px(view._unzoom(_press_pos))
	var b: Vector2 = view.from_px(view._unzoom(pos))
	var v: Vector2 = b - a
	var ball: Vector2 = view.nball()
	var power: float = delta.length() / maxf(view.cam_zoom, 0.1) / maxf(view.aim_span_y(), 1.0)
	var gk_x: float = view.npos("gk").x if view.has_actor("gk") else 0.5
	var x_hit: float = 9.0
	if v.y < -0.012:
		x_hit = ball.x + v.x * ((0.0 - ball.y) / v.y)
	# Hacia el arco (con margen: un poco afuera de los palos = remate desviado).
	if _has_shot and absf(x_hit - 0.5) <= PitchView.GOAL_W * 0.5 + 0.12:
		_finish({"action": "shot", "aim_x": x_hit, "power": power, "gk_x": gk_x, "open": _open_dist})
		return
	if _has_drib and swipe != 0:
		# Te vas hacia ese lado: lo que cuenta es el espacio que hay por ahí.
		var dest: Vector2 = ball + Vector2(float(swipe) * 0.11, -0.05)
		_finish({"action": "dribble", "clearance": clearance_to(dest), "side": swipe, "open": _open_dist})
		return
	if _has_pass:
		# Deslizar hacia un compañero también es pase.
		var bp: Vector2 = view.to_px(ball)
		var best: String = ""
		var best_a: float = 0.60
		for id in _receivers:
			var ang: float = absf(delta.angle_to(view.to_px(view.npos(id)) - bp))
			if ang < best_a:
				best_a = ang
				best = id
		if best != "":
			_live_pass(best)
			return
	if _has_shot and x_hit < 8.0:
		_finish({"action": "shot", "aim_x": x_hit, "power": power, "gk_x": gk_x})

func _live_pass(id: String) -> void:
	# Se mide EN EL MOMENTO del pase, con todos los rivales donde están
	# ahora. Adelantado = más cerca del arco que el penúltimo rival Y que la
	# pelota (si el pase es hacia atrás no hay fuera de juego).
	var line_now: float = view.offside_line_for("user")
	if line_now <= 0.0:
		line_now = _off_line
	var ry: float = view.npos(id).y
	var off: bool = id == _runner and ry < line_now - 0.012 and ry < view.nball().y - 0.005
	_finish({"action": "pass", "receiver": id, "clearance": lane_clearance(id), "offside": off, "open": _open_dist})

func _finish(result: Dictionary) -> void:
	if finished:
		return
	finished = true
	result["mode"] = mode
	done.emit(result)

# --- Pase: qué tan libre está la línea -----------------------------------

func lane_clearance(receiver: String) -> float:
	return clearance_to(view.npos(receiver))

## Qué tan libre está un pase desde la pelota hasta el punto `b`.
func clearance_to(b: Vector2) -> float:
	var a: Vector2 = view.nball()
	var best: float = 1.0
	for id in _defenders:
		var p: Vector2 = view.npos(id)
		var ab: Vector2 = b - a
		var k: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * k))
	return best

func lane_open(receiver: String) -> bool:
	return lane_clearance(receiver) >= DecisionResolver.pass_lane_need(difficulty)

# --- Dibujo (lo llama PitchView._draw) ---------------------------------

## Cartel corto sobre la cancha (10-oct): le dice al jugador QUÉ hacer en el
## momento justo, en vez de depender del texto de abajo.
func _cue(v, at: Vector2, text: String, col: Color) -> void:
	var font: Font = Styles.font_black()
	var fs: int = 17
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p: Vector2 = at - Vector2(w * 0.5, 0)
	v.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.9))
	v.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _draw_live_attack(v, gold: Color, green: Color) -> void:
	var b: Vector2 = v.to_px(v.nball())
	if _phase != "act":
		# DESMARQUE: a dónde vas y cuánto tiempo te queda.
		var me: Vector2 = v.to_px(v.npos("user"))
		if _phase == "run":
			if _press and _drag_pos != Vector2.ZERO:
				var tp: Vector2 = v._unzoom(_drag_pos)
				var n0: int = 12
				for i in range(n0):
					if i % 2 == 0:
						v.draw_line(me.lerp(tp, float(i) / n0), me.lerp(tp, float(i + 1) / n0), Color(gold, 0.9), 2.5)
				v.draw_arc(tp, 10.0, 0, TAU, 20, Color(gold, 0.9), 2.5)
			var frac: float = clampf(_run_left / DecisionResolver.RUN_SECS, 0.0, 1.0)
			v.draw_arc(me + Vector2(0, -6), 30.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 32, Color(gold, 0.95), 4.0)
			_cue(v, me + Vector2(0, 46), "¡DESMARCATE!", gold)
		return
	if _has_pass:
		# SIN AYUDAS (10-oct, Wilber: "no debería mostrar si la línea de pase
		# es buena o mala, el jugador debe saber que hay un riesgo"): solo se
		# marca A QUIÉN podés pasarle. Si la línea está tapada o el compañero
		# quedó adelantado, lo tenés que leer vos mirando la jugada.
		var neutral := Color(1, 1, 1, 0.75)
		for id in _receivers:
			var r: Vector2 = v.to_px(v.npos(id))
			v.draw_arc(r, 20.0 + sin(t * 4.0) * 1.5, 0, TAU, 24, neutral, 2.0)
	# Remate: mientras deslizás, la línea de tiro (verde = fuerza justa).
	if _has_shot:
		if _press and _drag_pos.distance_to(_press_pos) >= SWIPE_PX:
			var dd: Vector2 = (_drag_pos - _press_pos) / maxf(v.cam_zoom, 0.1)
			var pw: float = dd.length() / maxf(v.aim_span_y(), 1.0)
			var okp: bool = absf(pw - DecisionResolver.SHOT_POWER_IDEAL) <= lerpf(0.20, 0.08, difficulty)
			var sc: Color = Color(0.3, 1.0, 0.5, 0.95) if okp else (Color(1.0, 0.45, 0.3, 0.95) if pw > DecisionResolver.SHOT_POWER_IDEAL else Color(1.0, 0.85, 0.3, 0.95))
			v.draw_line(b, b + dd.normalized() * 70.0, Color(0, 0, 0, 0.5), 6.0)
			v.draw_line(b, b + dd.normalized() * 70.0, sc, 3.0)
			_cue(v, b + Vector2(0, 30), "FUERZA JUSTA" if okp else ("MUY FUERTE" if pw > DecisionResolver.SHOT_POWER_IDEAL else "MÁS FUERTE"), sc)
		elif t < 2.2:
			_cue(v, v.to_px(Vector2(0.5, 0.0)) + Vector2(0, 26), "DESLIZÁ AL ARCO", gold)

## Flecha gruesa (para "deslizá hacia acá").
func _arrow(v, from: Vector2, dir: int, col: Color) -> void:
	var ax: Vector2 = v.screen_dir_x() * float(dir)
	var nx := Vector2(-ax.y, ax.x)
	var tip: Vector2 = from + ax * 44.0
	v.draw_line(from, tip, Color(0, 0, 0, 0.7), 9.0)
	v.draw_line(from, tip, col, 5.0)
	v.draw_colored_polygon(PackedVector2Array([tip + ax * 12.0, tip - nx * 11.0, tip + nx * 11.0]), col)

func draw(v) -> void:
	if finished:
		return
	var gold := Color(1.0, 0.85, 0.3)
	var green := Color(0.3, 0.95, 0.5)
	var dmode: String = mode
	if mode == "live":
		dmode = "defend"
		if _live_att:
			_draw_live_attack(v, gold, green)
			return
		if t < 1.6:
			_cue(v, v.to_px(v.npos("user")) + Vector2(0, 54), "TOCÁ = QUITE   ·   DESLIZÁ = BARRIDA", gold)
	match dmode:
		"pass":
			var b: Vector2 = v.to_px(v.nball())
			# Arrastrando: línea al punto, verde si el pase está libre.
			if _press and _drag_pos.distance_to(_press_pos) >= SWIPE_PX:
				var to: Vector2 = v.from_px(v._unzoom(_drag_pos))
				var dc := Color(1.0, 0.86, 0.3, 0.95)
				v.draw_line(b, v.to_px(to), dc, 3.0)
				v.draw_arc(v.to_px(to), 9.0, 0, TAU, 16, dc, 2.5)
			# A QUIÉN podés pasarle (11-oct, Wilber: "que me muestre a quiénes
			# les puedo dar el pase y con el dedo apuntar"). Sin semáforo: si la
			# línea está tapada lo tenés que leer vos ("el jugador debe saber
			# que hay un riesgo").
			var nc := Color(1, 1, 1, 0.85)
			for id in _receivers:
				var r: Vector2 = v.to_px(v.npos(id))
				var n: int = 16
				for i in range(n):
					if i % 2 == 0:
						v.draw_line(b.lerp(r, float(i) / n), b.lerp(r, float(i + 1) / n), Color(1, 1, 1, 0.35), 2.0)
				v.draw_arc(r, 20.0 + sin(t * 4.0) * 1.5, 0, TAU, 24, nc, 2.5)
			# Paredes: en qué toque vas.
			if _combo_total > 0:
				var up3: Vector2 = v.to_px(v.npos("user"))
				var txt: String = "PASE FINAL" if _combo_done >= _combo_total else "PARED %d DE %d" % [_combo_done + 1, _combo_total]
				_cue(v, up3 + Vector2(0, 30), txt, gold)
		"dribble":
			var dp: Vector2 = v.to_px(v.npos("d1"))
			var k: float = clampf(t / _lunge_t, 0.0, 1.0)
			# Aro que se cierra: cuando toca el borde de la ficha, se tira.
			v.draw_arc(dp, lerpf(60.0, 16.0, k), 0, TAU, 32, Color(gold, 0.85), 2.0)
			if t > _lunge_t - 0.7:
				var lx: Vector2 = v.screen_dir_x() * float(_lean)
				var ln := Vector2(-lx.y, lx.x)
				var tip := dp + lx * 26.0
				v.draw_line(dp, tip, Color(1, 0.4, 0.3), 3.0)
				v.draw_line(tip, tip - lx * 7.0 - ln * 6.0, Color(1, 0.4, 0.3), 3.0)
				v.draw_line(tip, tip - lx * 7.0 + ln * 6.0, Color(1, 0.4, 0.3), 3.0)
				# Y la respuesta, bien visible: flecha VERDE del lado contrario,
				# saliendo de tu jugador. Lo difícil es el momento, no adivinar el lado.
				var up2: Vector2 = v.to_px(v.npos("user"))
				var pulse: float = 0.7 + 0.3 * sin(t * 14.0)
				_arrow(v, up2 - v.screen_dir_x() * float(_lean) * 18.0 + Vector2(0, -34.0), -_lean, Color(green, pulse))
				_cue(v, up2 + Vector2(0, -62.0), "¡DESLIZÁ!", green)
		"defend":
			var bp: Vector2 = v.to_px(v.nball())
			if _exposed_now():
				v.draw_arc(bp, 14.0, 0, TAU, 24, Color(gold, 1.0), 3.0)
				v.draw_circle(bp, 9.0, Color(gold, 0.35))
				_cue(v, bp + Vector2(0, -26), "¡AHORA!", gold)
		"keeper":
			if t < _shot_t and t > _shot_t - 0.6:
				var sp: Vector2 = v.to_px(v.npos(_shooter))
				v.draw_arc(sp, 22.0, 0, TAU, 24, Color(1, 0.4, 0.3, 0.9), 3.0)
				_cue(v, sp + Vector2(0, -34), "¡VA A PATEAR!", Color(1, 0.5, 0.4))
			elif t >= _shot_t:
				_cue(v, v.to_px(v.npos("user")) + Vector2(0, -54), "¡DESLIZÁ AL PALO!", gold)
		"sweep":
			if absf(t - float(_expose_t[0])) <= 0.22:
				var bp2: Vector2 = v.to_px(v.nball())
				v.draw_arc(bp2, 16.0, 0, TAU, 24, Color(gold, 1.0), 3.0)
				_cue(v, bp2 + Vector2(0, -26), "¡AHORA!", gold)
