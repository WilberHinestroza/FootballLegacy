class_name SoccerPlayer
extends CharacterBody3D
## Futbolista: movimiento, animación sencilla y acciones (chutar, pasar, entrar).
## Lo maneja el humano (SoccerMatch) o la IA (AiBrain) escribiendo en move_input / sprinting.
## Aspecto: PlayerAvatar (modelo animado de ComfyUI + Mixamo, colores por zona y objetos).
## Si el modelo no existe, usa el muñeco de primitivas de _build_visual().

const SPEED := 6.2
const SPRINT_SPEED := 8.6
const KEEPER_SPEED := 6.8
const ACCEL := 38.0
const Momentum = preload("res://engine/match/m3d/Momentum.gd")
const LoftedPass = preload("res://engine/match/m3d/LoftedPass.gd")
## Multi-toque: velocidad extra máxima sobre el sprint normal.
const MOVE_BOOST_SPEED_MAX := 1.25

const SKIN_TONES := [
	Color(0.98, 0.82, 0.68), Color(0.87, 0.67, 0.5), Color(0.66, 0.46, 0.32), Color(0.45, 0.3, 0.2),
]
const HAIR_COLORS := [
	Color(0.1, 0.07, 0.05), Color(0.35, 0.2, 0.1), Color(0.85, 0.7, 0.35), Color(0.04, 0.04, 0.04),
]

var match_ref: SoccerMatch
var team := 0
var index := 0
var is_keeper := false
var role := "MF" # línea en la formación: GK, DF, MF o ST (como en FootballCareer)
var is_human := false
var facing := Vector3.RIGHT
var move_input := Vector3.ZERO
## El portero camina y está de pie como uno más (p. ej. en la salida de los equipos).
var walk_normal := false
## Al perder: vuelve al túnel cabizbajo ("walk_sad" en vez de "walk").
var sad_gait := false
var sprinting := false
## Multi-toque en el partido 3D: 0 = normal, 1 = máximo. Acelera al jugador y
## le gasta más energía (lo pone SoccerMatch al ordenar un punto con varios toques).
var move_boost := 0.0
var stun_timer := 0.0
var tackle_cooldown := 0.0
var ai_timer := 0.0   # retraso entre decisiones de la IA
var hold_timer := 0.0 # tiempo que el portero retiene el balón
var dodge_timer := 0.0 # mientras dura el regate no le pueden robar
var energy := 1.0      # baja al esprintar; la resistencia (stamina) decide cuánto
## Estadísticas con los mismos nombres y escala (0-100) que PlayerData de FootballCareer.
var stats := {}

const STAT_KEYS := ["speed", "stamina", "strength", "control", "passing", "shooting",
	"dribbling", "decision_making", "composure"]

var _visual: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _ring: MeshInstance3D
var _hl_ring: MeshInstance3D
var _materials: Array[StandardMaterial3D] = []
var _faded := false
var _anim_t := 0.0
var _last_anim_speed := 0.0
var _action_blend := false
var _lunge_timer := 0.0
# Modelo animado
var _avatar: PlayerAvatar
var _anim: AnimationPlayer
var _action_timer := 0.0
var _kick := {} # golpe en preparación: {vel, curl, left, release}

## Golpes: animación, desde qué segundo empieza, velocidad y segundo en que el pie toca el balón
## (medido en las animaciones de Mixamo). El tiro usa el final del penalti, que es un golpe fuerte.
const KICKS := {
	"shot": {"anim": "penalty", "from": 0.5, "speed": 1.45, "contact": 0.8},
	"penalty": {"anim": "penalty", "from": 0.15, "speed": 1.15, "contact": 0.8},
	"pass": {"anim": "pass", "from": 0.1, "speed": 1.25, "contact": 0.32},
	"throw": {"anim": "keeper_throw", "from": 0.75, "speed": 1.5, "contact": 1.55},
}

## Estiradas del portero. Las animaciones de Mixamo se importan sin desplazamiento (root motion),
## así que el juego mueve el cuerpo por el camino que hacía la cadera (medido en Blender, cada 0.1 s,
## en alturas del jugador): `side` = hacia su lado natural, `fwd` = hacia delante.
## `hands` = dónde quedan las manos en el contacto respecto al punto de salida.
const BODY_H := 1.78
const DIVES := {
	"low": {"anim": "keeper_dive", "from": 0.4, "speed": 1.5, "contact": 1.0, "natural": 1.0,
		"hands": Vector3(0.93, 0.38, 0.91),
		"side": [0.0, 0.01, 0.04, 0.07, 0.09, 0.12, 0.17, 0.24, 0.34, 0.44, 0.56, 0.67, 0.79, 0.93, 1.05, 1.12, 1.19, 1.23, 1.24],
		"fwd": [0.0, 0.02, 0.04, 0.06, 0.08, 0.12, 0.19, 0.25, 0.33, 0.42, 0.49, 0.56, 0.62, 0.69, 0.73, 0.77, 0.77, 0.76, 0.77]},
	"high": {"anim": "keeper_dive_high", "from": 0.3, "speed": 1.5, "contact": 0.9, "natural": -1.0,
		"hands": Vector3(1.17, 0.7, 0.57),
		"side": [0.0, 0.02, 0.05, 0.07, 0.1, 0.18, 0.27, 0.39, 0.51, 0.65, 0.77, 0.9, 1.04, 1.19, 1.27, 1.37, 1.44, 1.49, 1.51],
		"fwd": [0.0, 0.01, 0.02, 0.03, 0.05, 0.11, 0.15, 0.2, 0.24, 0.29, 0.33, 0.37, 0.4, 0.41, 0.43, 0.42, 0.41, 0.4, 0.4]},
}
const DIVE_LEAD := 0.4          # segundos desde que empieza la estirada hasta que las manos llegan
const RECEIVE_FROM := 0.8       # control orientado: tramo de "receive" con el toque de pie
const RECEIVE_CONTACT := 1.1
const RECEIVE_SPEED := 1.6
const HEADER_FROM := 0.75      # cabezazo: la cabeza va hacia delante hacia el segundo 1.05
const HEADER_CONTACT := 1.05
const HEADER_SPEED := 1.6

var _dive := {}          # estirada en curso
# Inclinación del cuerpo (x = hacia delante, y = lateral en las curvas)
var _lean := Vector2.ZERO
var _prev_yaw := 0.0
var _prev_vel := Vector3.ZERO
## Defensa de cara al balón: retrocede o se desplaza de lado mirando al rival.
var _jockey := false
var _receive_timer := 0.0


func setup(m: SoccerMatch, t: int, i: int, shirt: Color) -> void:
	match_ref = m
	team = t
	index = i
	is_keeper = i == 0
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = FieldBuilder.LAYER_WALLS | 2

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.9
	col.shape = cap
	col.position.y = 1.05
	add_child(col)
	if PlayerAvatar.available():
		_build_model(shirt)
	else:
		_build_visual(shirt)
		for mi: MeshInstance3D in _visual.find_children("*", "MeshInstance3D", true, false):
			_materials.append(mi.material_override as StandardMaterial3D)
	_build_rings()


func _physics_process(delta: float) -> void:
	stun_timer = maxf(stun_timer - delta, 0.0)
	tackle_cooldown = maxf(tackle_cooldown - delta, 0.0)
	ai_timer = maxf(ai_timer - delta, 0.0)
	hold_timer = maxf(hold_timer - delta, 0.0)
	dodge_timer = maxf(dodge_timer - delta, 0.0)
	_receive_timer = maxf(_receive_timer - delta, 0.0)

	if is_diving():
		_dive_step(delta)
		return
	if not is_keeper and not has_ball() and not is_kicking() and _action_timer <= 0.0:
		_check_receive()

	var pace := lerpf(0.86, 1.14, stat("speed"))
	var boost := clampf(move_boost, 0.0, 1.0) if not is_keeper else 0.0
	var running := (sprinting or boost > 0.01) and move_input.length() > 0.3
	if running:
		# El multi-toque acelera, pero vacía la energía bastante más rápido.
		energy = maxf(energy - delta * lerpf(0.16, 0.05, stat("stamina")) * lerpf(1.0, 1.9, boost), 0.0)
	else:
		energy = minf(energy + delta * 0.12, 1.0)
	var speed := SPRINT_SPEED * lerpf(0.82, 1.0, energy) if sprinting else SPEED
	if is_keeper:
		speed = KEEPER_SPEED * (1.35 if sprinting else 1.0)
	speed *= pace
	if boost > 0.0:
		speed *= move_boost_speed()
	if has_ball():
		speed *= lerpf(0.82, 0.95, stat("dribbling"))
	var desired := move_input.limit_length(1.0) * speed
	if stun_timer > 0.0:
		desired = Vector3.ZERO
	if _receive_timer > 0.0:
		desired *= 0.35 # frena para controlar
	_jockey = _should_jockey(desired)
	if _jockey:
		desired *= 0.82 # de espaldas o de lado se va algo más lento
	if has_ball() and desired.length() > 0.1:
		# Con el balón en los pies no se gira en seco: frena al encarar otra dirección
		var align := facing.dot(desired.normalized())
		desired *= clampf(0.55 + align * 0.45, 0.3, 1.0)
	elif desired.length() > 0.1:
		# P0-11/P1-71: girar 180° también cuesta velocidad sin balón (evita el
		# patinaje de salir corriendo para el lado contrario).
		desired *= turn_speed_factor(facing.dot(desired.normalized()))
	if is_kicking():
		desired = Vector3.ZERO # se planta para golpear
		_kick.left -= delta
		if _kick.left <= 0.0:
			_release_kick()

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if _lunge_timer > 0.0:
		_lunge_timer -= delta
		flat = flat.move_toward(Vector3.ZERO, 10.0 * delta)
	else:
		# P1-14: arrancar es vivo, pero frenar arrastra inercia. Un jugador que
		# venía esprintando tarda más en parar; con el balón también se protege
		# el control. Al golpear o quedar aturdido se planta sin patinar.
		var rate := Momentum.rate(flat.length(), desired.length(),
				sprinting or move_boost > 0.01, has_ball())
		if is_kicking() or stun_timer > 0.0:
			rate = Momentum.ACCEL
		flat = flat.move_toward(desired, rate * delta)
	velocity = flat
	move_and_slide()
	global_position.y = 0.0

	if desired.length() > 0.3 and not is_kicking():
		var face_dir := desired.normalized()
		if _jockey:
			face_dir = SoccerMatch.flat(match_ref.ball.global_position - global_position).normalized()
		# Giro progresivo: a 180° se pisa el freno y se rota más despacio; de
		# frente el cuerpo acompaña casi al instante. Evita el "teletransporte"
		# de orientación al cambiar de dirección (P0-11 / P1-71).
		var base_turn := 8.0 if _jockey else 12.0
		if walk_normal:
			base_turn = 4.5 # caminando (túnel): el cuerpo gira con calma, no como un robot
		var align_turn := clampf((facing.dot(face_dir) + 1.0) * 0.5, 0.0, 1.0)
		var turn_rate := base_turn * lerpf(0.6, 1.0, align_turn)
		facing = _turn_toward(face_dir, delta, turn_rate)
	elif _should_watch_ball():
		var to_ball := SoccerMatch.flat(match_ref.ball.global_position - global_position)
		if to_ball.length() > 1.0:
			var nf2 := facing.slerp(to_ball.normalized(), minf(1.0, 3.5 * delta))
			if nf2.length() > 0.01:
				facing = nf2.normalized()
	rotation.y = atan2(facing.x, facing.z)
	_update_lean(delta, flat)
	_animate(delta, flat.length())


## Quieto y sin nada que hacer: se va girando hacia el balón (solo con el partido en juego).
func _should_watch_ball() -> bool:
	if is_human or has_ball() or is_kicking() or _action_timer > 0.0 or stun_timer > 0.0 or match_ref == null:
		return false
	var st: int = match_ref.state
	return st == SoccerMatch.State.SIMULATING or st == SoccerMatch.State.MOMENT \
			or st == SoccerMatch.State.MOMENT_INTRO or st == SoccerMatch.State.CUTSCENE


## Un defensa (IA) que recula o se abre cerca del balón rival lo hace mirándolo,
## en vez de darle la espalda y correr.
func _should_jockey(desired: Vector3) -> bool:
	if is_human or is_keeper or sprinting or has_ball() or _anim == null or match_ref == null:
		return false
	if desired.length() < 0.5 or stun_timer > 0.0 or _action_timer > 0.0:
		return false
	var holder: SoccerPlayer = match_ref.ball.owner_player
	if holder == null or holder.team == team:
		return false
	var to_ball := SoccerMatch.flat(match_ref.ball.global_position - global_position)
	var d := to_ball.length()
	if d > 13.0 or d < 1.2:
		return false
	return desired.normalized().dot(to_ball / d) < 0.35 # alejándose o de lado


## Se inclina hacia dentro en las curvas y hacia delante al arrancar y esprintar.
func _update_lean(delta: float, flat: Vector3) -> void:
	if _avatar == null or delta <= 0.0:
		return
	var yaw_rate := wrapf(rotation.y - _prev_yaw, -PI, PI) / delta
	_prev_yaw = rotation.y
	var fwd_acc := ((flat - _prev_vel) / delta).dot(facing)
	_prev_vel = flat
	var spd := flat.length()
	var target := Vector2.ZERO
	if _action_timer <= 0.0 and not is_kicking() and stun_timer <= 0.0 and not _jockey:
		# Con poca energía el cuerpo va algo más adelantado (cansancio visible).
		var tired := (1.0 - energy) * 0.075 * clampf(spd / SPEED, 0.0, 1.0)
		target.x = clampf(spd / SPRINT_SPEED * 0.1 + fwd_acc * 0.005 + tired, -0.06, 0.18)
		target.y = clampf(-yaw_rate * spd * 0.012, -0.22, 0.22)
	_lean = _lean.lerp(target, minf(1.0, 8.0 * delta))
	_avatar.rotation = Vector3(_lean.x, 0.0, _lean.y)


## Cuánto se conserva la velocidad según el ángulo del giro. `align` es el
## producto escalar entre hacia dónde mira y hacia dónde quiere ir: -1 es un
## giro de 180° (se pisa el freno) y 1 es seguir de frente (sin castigo).
func turn_speed_factor(align: float) -> float:
	var t := clampf((align + 1.0) * 0.5, 0.0, 1.0)
	return lerpf(0.30, 1.0, t * t)


## Multiplicador de velocidad del multi-toque: 1,0 sin boost y hasta
## MOVE_BOOST_SPEED_MAX con el boost lleno.
func move_boost_speed() -> float:
	return lerpf(1.0, MOVE_BOOST_SPEED_MAX, clampf(move_boost, 0.0, 1.0))


## Gira de a poco hacia `dir` (parado): para encarar la cámara o la grada sin
## pegar el giro de golpe en un frame.
func ease_facing(dir: Vector3, delta: float, rate := 3.5) -> void:
	facing = _turn_toward(dir, delta, rate)
	rotation.y = atan2(facing.x, facing.z)


## Gira `facing` hacia `target_dir` como máximo `rate` radianes por segundo.
## Devuelve el vector aplanado; nunca da el salto instantáneo de orientación.
func _turn_toward(target_dir: Vector3, delta: float, rate: float) -> Vector3:
	var to := SoccerMatch.flat(target_dir)
	if to.length_squared() < 0.0001 or delta <= 0.0:
		return facing
	to = to.normalized()
	var cur_yaw := atan2(facing.x, facing.z)
	var want_yaw := atan2(to.x, to.z)
	var diff := wrapf(want_yaw - cur_yaw, -PI, PI)
	var step := clampf(rate * delta, 0.0, absf(diff))
	var yaw := cur_yaw + signf(diff) * step
	return Vector3(sin(yaw), 0.0, cos(yaw))


## Tiempo de mezcla entre dos animaciones de locomoción: los cambios grandes de
## velocidad y la vuelta desde una acción necesitan más mezcla para no patinar.
func locomotion_blend(prev_speed: float, next_speed: float, action_recovering := false) -> float:
	var change := absf(next_speed - prev_speed)
	var blend := lerpf(0.06, 0.16, clampf(change / 4.0, 0.0, 1.0))
	if action_recovering:
		blend = maxf(blend, 0.18)
	return clampf(blend, 0.05, 0.2)


# ---------- acciones ----------

func has_ball() -> bool:
	return match_ref.ball.owner_player == self


func on_gained_ball() -> void:
	ai_timer = randf_range(0.2, 0.45)
	if is_keeper:
		if is_diving():
			hold_timer = 2.2 # se levanta con el balón antes de sacar
			return
		hold_timer = 1.0
		facing = Vector3(match_ref.attack_dir(team), 0.0, 0.0)
		# Balón raso: lo recoge del suelo; alto: blocaje al pecho
		if match_ref.ball.global_position.y < 0.5:
			play_action_from("keeper_catch", 0.45, 1.6, 0.9)
		else:
			play_action_from("keeper_catch", 1.1, 1.4, 0.7)


# ---------- portero: estiradas ----------

func is_diving() -> bool:
	return not _dive.is_empty()


## Se estira hacia `target` (punto por donde pasará el balón). `reach_scale` < 1 = no llega.
func start_dive(target: Vector3, reach_scale := 1.0) -> void:
	if is_diving() or _anim == null:
		return
	var fwd := facing
	var left := Vector3.UP.cross(fwd) # izquierda del portero
	var off := SoccerMatch.flat(target - global_position)
	var lateral := off.dot(left)
	var side := 1.0 if lateral >= 0.0 else -1.0
	var kind := "high" if target.y > 0.95 else "low"
	var d: Dictionary = DIVES[kind]
	if not _anim.has_animation(d.anim):
		kind = "low"
		d = DIVES.low
	var h := BODY_H * absf(_avatar.scale.y)
	var natural_lat: float = d.hands.x * h
	var lat_scale := clampf(absf(lateral) / natural_lat, 0.45, 1.45) * reach_scale
	_avatar.set_mirrored(side != d.natural)
	_lean = Vector2.ZERO
	_avatar.rotation = Vector3.ZERO
	_anim.play(d.anim, 0.05)
	_anim.seek(d.from, true)
	_anim.speed_scale = d.speed
	_action_timer = (_anim.get_animation(d.anim).length - d.from) / d.speed
	_dive = {"def": d, "t": d.from, "origin": global_position, "left": left * side, "fwd": fwd,
		"lat": lat_scale, "h": h}
	velocity = Vector3.ZERO


func _dive_step(delta: float) -> void:
	var d: Dictionary = _dive.def
	_dive.t += delta * d.speed
	var t: float = _dive.t
	var path_side: Array = d.side
	var path_fwd: Array = d.fwd
	var p0 := _sample(path_side, d.from)
	var f0 := _sample(path_fwd, d.from)
	var h: float = _dive.h
	var pos: Vector3 = _dive.origin
	pos += (_dive.left as Vector3) * (_sample(path_side, t) - p0) * h * _dive.lat
	pos += (_dive.fwd as Vector3) * (_sample(path_fwd, t) - f0) * h * 0.45 # menos hacia delante: no deja la línea
	global_position = Vector3(pos.x, 0.0, pos.z)
	rotation.y = atan2(facing.x, facing.z)
	_action_timer -= delta
	if _action_timer <= 0.0:
		_dive = {}
		_avatar.set_mirrored(false)


## Valor de una tabla muestreada cada 0.1 s (se queda en el último valor al pasarse).
static func _sample(arr: Array, t: float) -> float:
	var x := clampf(t / 0.1, 0.0, arr.size() - 1.0)
	var i := mini(int(x), arr.size() - 2)
	return lerpf(arr[i], arr[i + 1], x - i)


## Segundos que faltan para que las manos lleguen al punto de la estirada (negativo = ya pasó).
func dive_contact_left() -> float:
	if not is_diving():
		return INF
	var d: Dictionary = _dive.def
	return (d.contact - float(_dive.t)) / d.speed


## Dónde están las manos ahora (el balón va ahí cuando lo atrapa el portero).
func hands_position() -> Vector3:
	if _avatar:
		return _avatar.hands_position()
	return global_position + facing * 0.4 + Vector3.UP


# ---------- control del pase ----------

## Si un balón raso viene hacia él, empieza el control justo antes de que llegue,
## para que el pie lo toque cuando lo recibe.
func _check_receive() -> void:
	var b := match_ref.ball
	if b.owner_player != null or _anim == null or not _anim.has_animation("receive"):
		return
	var bv := SoccerMatch.flat(b.linear_velocity)
	var spd := bv.length()
	var to_me := SoccerMatch.flat(global_position - b.global_position)
	var d := to_me.length()
	# Balón alto que viene hacia él: prepara el cabezazo (el golpe lo resuelve el partido)
	var by := b.global_position.y
	if spd > 4.0 and by > 1.0 and by < 3.2 and d < 4.0 and d > 0.4 and to_me.dot(bv) > d * spd * 0.85:
		var eta := (d - 0.4) / spd
		if eta < (HEADER_CONTACT - HEADER_FROM) / HEADER_SPEED:
			facing = -bv / spd
			play_action_from("header", HEADER_FROM, HEADER_SPEED, 0.6)
		return
	if spd < 4.0 or by > 0.7:
		return
	if d > 7.0 or d < 0.9 or to_me.dot(bv) < d * spd * 0.94:
		return
	var lead := (RECEIVE_CONTACT - RECEIVE_FROM) / RECEIVE_SPEED
	if (d - 0.8) / spd > lead:
		return
	facing = -bv / spd
	play_action_from("receive", RECEIVE_FROM, RECEIVE_SPEED, lead + 0.3)
	_receive_timer = lead + 0.2


## power de 0 a 1: más potencia = más rápido, más alto y algo menos preciso.
func shoot_at(target: Vector3, power: float) -> void:
	if not has_ball() or is_kicking():
		return
	var dir := SoccerMatch.flat(target - global_position).normalized()
	if dir == Vector3.ZERO:
		dir = facing
	var precision := stat("shooting") * 0.6 + stat("composure") * 0.25 + stat("stamina") * 0.15
	var fatigue := _shot_fatigue()
	dir = dir.rotated(Vector3.UP, randf_range(-0.06, 0.06) * (0.5 + power) * (1.5 - precision) * (1.0 + fatigue))
	var spd := lerpf(13.0, 29.0, power) * lerpf(0.9, 1.08, stat("shooting")) * lerpf(0.92, 1.0, stat("stamina"))
	var lift := lerpf(1.0, 5.5, power) * lerpf(0.95, 1.05, stat("shooting"))
	if is_keeper:
		# Despeje largo con la mano
		_start_kick("throw", dir * minf(spd, 20.0) + Vector3.UP * 6.0, 0.0, Callable())
		return
	_start_kick("shot", dir * spd + Vector3.UP * lift, 0.0, match_ref.on_shot.bind(self))


## Remate exacto para las jugadas de gol narradas: va al punto marcado, sin desviación
## aleatoria (la simulación ya decidió que es gol; el balón tiene que verse entrar).
func shoot_exact(target: Vector3, power: float) -> void:
	if not has_ball() or is_kicking():
		return
	var dir := SoccerMatch.flat(target - global_position).normalized()
	if dir == Vector3.ZERO:
		dir = facing
	var spd := lerpf(13.0, 29.0, power) * lerpf(0.9, 1.08, stat("shooting")) * lerpf(0.92, 1.0, stat("stamina"))
	var lift := lerpf(1.0, 5.5, power) * lerpf(0.95, 1.05, stat("shooting"))
	_start_kick("shot", dir * spd + Vector3.UP * lift, 0.0, match_ref.on_shot.bind(self))


## Chute exacto (desde un gesto): velocidad del balón y efecto ya calculados.
## `accuracy` (0..0.6) reduce la desviación aleatoria del gesto: la usa el
## remate encadenado de P1-12.
func shoot_vector(vel: Vector3, curl: float, accuracy := 0.0) -> void:
	if not has_ball() or is_kicking():
		return
	var kind := "penalty" if match_ref.moment_type == SoccerMatch.Moment.PENALTY else "shot"
	# El gesto marca la intención; la puntería (shooting) y la sangre fría (composure) la afinan
	var skill := stat("shooting") * 0.6 + stat("composure") * 0.25 + stat("stamina") * 0.15
	skill = clampf(skill + clampf(accuracy, 0.0, 0.6), 0.0, 1.0)
	var power := clampf(vel.length() / 30.0, 0.3, 1.0)
	var fatigue := _shot_fatigue()
	var err := randf_range(-1.0, 1.0) * (1.0 - skill) * 0.09 * (0.5 + power) * (1.0 + fatigue)
	var flat_v := SoccerMatch.flat(vel).rotated(Vector3.UP, err) * lerpf(0.92, 1.08, stat("shooting"))
	vel = flat_v + Vector3.UP * vel.y * randf_range(1.0 - (1.0 - skill) * 0.1, 1.0 + (1.0 - skill) * 0.2)
	_start_kick(kind, vel, curl, match_ref.on_shot.bind(self))


func pass_ball(target: SoccerPlayer) -> void:
	if not has_ball() or is_kicking():
		return
	var kind := "throw" if is_keeper else "pass"
	if target == null:
		_start_kick(kind, facing * 12.0 + Vector3.UP * 0.5, 0.0, Callable())
		return
	# Pase al hueco: apunta un poco por delante del compañero (se calcula al golpear).
	# Con poco pase (passing) el balón sale algo desviado o con la fuerza equivocada.
	var err := randf_range(-1.0, 1.0) * (1.0 - stat("passing")) * 0.12
	var force := 1.0 + randf_range(-1.0, 1.0) * (1.0 - stat("passing")) * 0.2
	var aim := func() -> Vector3:
		var lead := target.global_position + SoccerMatch.flat(target.velocity) * 0.35
		var to := SoccerMatch.flat(lead - global_position)
		var d := to.length()
		var spd := clampf(6.0 + d * 1.1, 9.0, 22.0) * force
		var up := 0.5 + d * 0.03
		if is_keeper:
			up += 1.5 # saque con la mano: sale de arriba y bota antes de llegar
		return (to / maxf(d, 0.01)).rotated(Vector3.UP, err) * spd + Vector3.UP * up
	_start_kick(kind, aim, 0.0, match_ref.on_pass.bind(self, target))


## P1-09 · Pase bombeado: levanta la pelota para pasar por encima del rival y
## la deja caer en los pies del compañero. `apex` es la altura máxima (m) del
## vuelo; por defecto pasa medio metro por encima de un defensor de campo.
func lofted_pass(target: SoccerPlayer, apex := LoftedPass.clearance_apex()) -> void:
	if not has_ball() or is_kicking() or target == null:
		return
	var err := randf_range(-1.0, 1.0) * (1.0 - stat("passing")) * 0.12
	var aim := func() -> Vector3:
		var lead := target.global_position + SoccerMatch.flat(target.velocity) * 0.5
		var to := SoccerMatch.flat(lead - global_position)
		var d := maxf(to.length(), 1.0)
		var k := SoccerBall.air_drag()
		var vy := LoftedPass.vy_for_apex(apex, k)
		var t := LoftedPass.hang_time(vy, k)
		var h := LoftedPass.horizontal_speed(d, t, k)
		return (to / d).rotated(Vector3.UP, err) * h + Vector3.UP * vy
	_start_kick("pass", aim, 0.0, match_ref.on_pass.bind(self, target))


## Centro bombeado al área: el balón cae a la altura de la cabeza del compañero.
func cross_to(target: SoccerPlayer) -> void:
	if target == null:
		return
	cross_to_point(target.global_position + SoccerMatch.flat(target.velocity) * 0.9, 1.75)


## P1-10 · Centro a un punto del área (primer palo, segundo palo o punto penal).
## `height` es la altura a la que debe llegar el balón para rematar cómodo.
func cross_to_point(point: Vector3, height := 1.75) -> void:
	if not has_ball() or is_kicking():
		return
	var err := randf_range(-1.0, 1.0) * (1.0 - stat("passing")) * 1.2
	var aim := func() -> Vector3:
		var to := SoccerMatch.flat(point - global_position)
		var d := to.length()
		to = to.rotated(Vector3.UP, err / maxf(d, 1.0))
		# Tiro parabólico con el frenado del aire (linear_damp k): llega a la
		# altura pedida en t segundos.
		var t := clampf(d / 16.0, 0.6, 2.0)
		var k := SoccerBall.air_drag()
		var f := (1.0 - exp(-k * t)) / k
		var h_speed := d / f
		var vy := SoccerBall.lift_for(maxf(height, 0.2) - SoccerBall.RADIUS, t)
		return to / maxf(d, 0.01) * h_speed + Vector3.UP * vy
	_start_kick("pass", aim, 0.0, Callable())


## P1-06 · Sombrero: picarla por encima del defensor hacia un punto del campo.
## `power` < 1 la deja corta (fallo de la jugada) para que el rival la controle.
func chip_ball(target_point: Vector3, power := 1.0) -> void:
	if not has_ball() or is_kicking():
		return
	var aim := func() -> Vector3:
		var to := SoccerMatch.flat(target_point - global_position)
		var d := maxf(to.length(), 1.0)
		var t := clampf(d / 11.0, 0.45, 1.4)
		var h := d / t * clampf(power, 0.5, 1.2)
		var vy := SoccerBall.lift_for(2.3, t)
		return to / d * h + Vector3.UP * vy
	_start_kick("pass", aim, 0.0, Callable())


## P1-06 · Rabona: pase con efecto al compañero, golpeando con la pierna de
## atrás. El `curl` abre el balón hacia afuera y el error crece con mal passing.
func rabona_pass(target: SoccerPlayer, curl: float) -> void:
	if not has_ball() or is_kicking():
		return
	var err := randf_range(-1.0, 1.0) * (1.0 - stat("passing")) * 0.2
	var aim := func() -> Vector3:
		var lead := target.global_position + SoccerMatch.flat(target.velocity) * 0.4
		var to := SoccerMatch.flat(lead - global_position)
		var d := maxf(to.length(), 1.0)
		var spd := clampf(8.0 + d * 1.0, 10.0, 20.0)
		return (to / d).rotated(Vector3.UP, err) * spd + Vector3.UP * (0.6 + d * 0.03)
	_start_kick("pass", aim, curl, match_ref.on_pass.bind(self, target))


## P1-07 · Pase al hueco dibujado: la pelota va al punto elegido con el dedo,
## medida para caer ahí (más fuerte = llega antes, no más lejos). El error
## crece con mal `passing`; `target` es el compañero que debería correrla.
func pass_to_point(point: Vector3, target: SoccerPlayer, power := 1.0) -> void:
	if not has_ball() or is_kicking():
		return
	var err := randf_range(-1.0, 1.0) * (1.0 - stat("passing")) * 0.1
	var aim := func() -> Vector3:
		var to := SoccerMatch.flat(point - global_position)
		var d := maxf(to.length(), 1.0)
		to = to.rotated(Vector3.UP, err)
		# Misma compensación de aire que el centro, pero rasa y medida.
		var t := clampf(d / 16.0, 0.35, 1.6)
		var k := SoccerBall.air_drag()
		var f := (1.0 - exp(-k * t)) / k
		var h := d / maxf(f, 0.01) * clampf(power, 0.6, 1.3)
		var vy := SoccerBall.lift_for(0.25, t)
		return to / maxf(d, 0.01) * h + Vector3.UP * vy
	_start_kick("pass", aim, 0.0, match_ref.on_pass.bind(self, target))


## P1-08 · Pase de primera: golpear el balón que viene sin controlarlo. La
## pelota sale desde donde está (no de los pies) y el jugador queda bloqueado
## un instante para no volver a recogerla en el acto. Si hay compañero, el
## pase lo busca; si no, va al punto elegido con el dedo.
func first_touch_pass(target: SoccerPlayer, point: Vector3) -> void:
	if is_kicking() or match_ref == null or match_ref.ball == null:
		return
	var b: SoccerBall = match_ref.ball
	var err := randf_range(-1.0, 1.0) * (1.0 - stat("passing")) * 0.1
	var aim := Vector3.ZERO
	if target != null:
		var lead := target.global_position + SoccerMatch.flat(target.velocity) * 0.3
		var to := SoccerMatch.flat(lead - b.global_position)
		var d := maxf(to.length(), 1.0)
		var spd := clampf(6.0 + d * 1.1, 9.0, 22.0)
		aim = (to / d).rotated(Vector3.UP, err) * spd + Vector3.UP * (0.4 + d * 0.025)
	else:
		var to := SoccerMatch.flat(point - b.global_position)
		var d := maxf(to.length(), 1.0)
		aim = (to / d).rotated(Vector3.UP, err) \
			* clampf(8.0 + d * 1.0, 10.0, 20.0) + Vector3.UP * 0.4
	facing = SoccerMatch.flat(aim).normalized()
	b.kick(self, aim, 0.0, "pass")
	b.block_pickup(self, 0.3)
	# El balón ya salió: se reproduce el gesto de pase sin esperar el contacto.
	play_action_from("pass", KICKS["pass"]["from"], KICKS["pass"]["speed"], 0.5)


func is_kicking() -> bool:
	return not _kick.is_empty()


## Dónde espera el balón mientras se prepara el golpe: delante del pie derecho.
func kick_spot() -> Vector3:
	if is_keeper:
		return hands_position() + facing * 0.12
	var right := facing.cross(Vector3.UP)
	return global_position + facing * 0.55 + right * 0.1


## Empieza la animación del golpe y suelta el balón justo cuando el pie lo toca.
## `vel` es la velocidad del balón, o un Callable que la calcula en el momento del golpe.
func _start_kick(kind: String, vel: Variant, curl: float, on_release: Callable) -> void:
	var k: Dictionary = KICKS[kind]
	var flat_v := SoccerMatch.flat(vel.call() if vel is Callable else vel)
	if flat_v.length() > 0.01:
		facing = flat_v.normalized()
	var delay := 0.0
	if _anim and _anim.has_animation(k.anim):
		delay = (k.contact - k.from) / k.speed
		_anim.play(k.anim, 0.06)
		_anim.seek(k.from, true)
		_anim.speed_scale = k.speed
		_action_timer = minf((_anim.get_animation(k.anim).length - k.from) / k.speed, delay + 0.45)
	dodge_timer = maxf(dodge_timer, delay + 0.15) # no te lo roban a mitad del golpe
	_kick = {"kind": kind, "vel": vel, "curl": curl, "left": delay, "release": on_release}
	if delay <= 0.0:
		_release_kick()


func _release_kick() -> void:
	var k := _kick
	_kick = {}
	if not has_ball():
		return
	var v: Vector3 = k.vel.call() if k.vel is Callable else k.vel
	match_ref.ball.kick(self, v, k.curl, String(k.get("kind", "pass")))
	if (k.release as Callable).is_valid():
		(k.release as Callable).call()


func stun(t: float) -> void:
	stun_timer = maxf(stun_timer, t)
	if t >= 0.6:
		play_action("fall", 1.3, 1.1) # le han hecho una entrada


func lunge() -> void:
	velocity = facing * 10.0
	_lunge_timer = 0.22
	play_action("tackle", 2.5, 1.0)


## Reproduce una animación de acción (chute, pase, entrada…) sobre la de movimiento.
## Celebración de gol: un baile al azar durante `t` segundos.
func celebrate(t: float) -> void:
	var dances: Array[String] = []
	if _anim:
		for n in _anim.get_animation_list():
			if n.begins_with("dance_"):
				dances.append(n)
	if not dances.is_empty():
		play_action(dances.pick_random(), 1.0, t)


func play_action(anim_name: String, anim_speed := 1.0, max_time := 1.0) -> void:
	play_action_from(anim_name, 0.0, anim_speed, max_time)


func play_action_from(anim_name: String, from: float, anim_speed := 1.0, max_time := 1.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name) or is_diving():
		return
	_anim.play(anim_name, 0.08)
	if from > 0.0:
		_anim.seek(from, true)
	_anim.speed_scale = anim_speed
	_action_timer = minf((_anim.get_animation(anim_name).length - from) / anim_speed, max_time)
	_action_blend = true


## Quiebro rápido en una dirección sin perder el balón.
func dodge(dir: Vector3) -> void:
	var d := SoccerMatch.flat(dir).normalized()
	if d == Vector3.ZERO:
		return
	velocity = d * 9.5
	_lunge_timer = 0.3
	dodge_timer = 0.6
	var nf := (facing + d).normalized()
	if nf != Vector3.ZERO:
		facing = nf


## Semitransparente cuando tapa la jugada a la cámara.
func set_faded(value: bool) -> void:
	if value == _faded:
		return
	_faded = value
	if _avatar:
		_avatar.set_faded(value)
	for m in _materials:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if value else BaseMaterial3D.TRANSPARENCY_DISABLED
		m.albedo_color.a = 0.25 if value else 1.0


## Aspecto completo de tu jugador (colores, físico y objetos) desde el perfil.
func apply_profile(p: PlayerProfile) -> void:
	if _avatar:
		_avatar.apply_profile(p)


## Vuelve a un aspecto genérico al azar (el que sale de un cambio deja de ser "tu" jugador).
func reset_generic_look() -> void:
	if _avatar == null:
		return
	_avatar.set_colors({"skin_color": PlayerProfile.SKIN_TONES.pick_random(),
		"hair_color": PlayerProfile.HAIR_COLORS.pick_random(), "beard_style": 0, "show_hair": true,
		"hair_style": ItemCatalog.shader_hair_index("rapado")})
	_avatar.set_hair_style("rapado")
	_avatar.set_body_scale(Vector3.ONE)


## Cara de un jugador real de FootballCareer (la de su ficha): piel, pelo, peinado y barba.
func apply_look(look: Dictionary) -> void:
	if _avatar == null:
		return
	var hs := String(look.get("hair_style", "rapado"))
	if not ItemCatalog.hair_available(hs):
		hs = "rapado"
	var c := {"show_hair": hs != "calvo", "hair_style": ItemCatalog.shader_hair_index(hs),
			"beard_style": ItemCatalog.face_index(String(look.get("face", "")))}
	if look.has("skin"):
		c["skin_color"] = Color(String(look.skin))
	if look.has("hair"):
		c["hair_color"] = Color(String(look.hair))
	_avatar.set_colors(c)
	_avatar.set_hair_style(hs)


## Solo algunos colores (p. ej. la equipación del equipo).
func apply_decals(tex: Texture2D) -> void:
	if _avatar:
		_avatar.set_decals(tex)


func apply_colors(colors: Dictionary) -> void:
	if _avatar:
		_avatar.set_colors(colors)


## Valor de 0 a 1 de una estadística (50 si no la tiene).
func stat(key: String) -> float:
	return clampf(float(stats.get(key, 50)) / 100.0, 0.0, 1.0)


## Desgaste del tiro por el minuto del partido y la estamina del jugador:
## en el 2º tiempo la precisión baja un poco y en la prórroga más; la
## estamina alta mitiga el efecto. Espejo simplificado de MatchEngine.
func _shot_fatigue() -> float:
	if match_ref == null:
		return 0.0
	var m: int = int(match_ref.minute)
	var pen := 0.0
	if m >= 46 and m <= 90:
		pen = 0.04 * clampf(float(m - 45) / 45.0, 0.0, 1.0)
	elif m > 90:
		pen = 0.04 + 0.08 * clampf(float(m - 90) / 30.0, 0.0, 1.0)
	var stam := stat("stamina")
	pen *= (1.0 - stam * 0.3)
	return clampf(pen, 0.0, 0.12)

## FootballCareer no tiene stats de portero: los reflejos salen de control, decisión y sangre fría.
func keeper_skill() -> float:
	return stat("control") * 0.4 + stat("decision_making") * 0.3 + stat("composure") * 0.3


## Fuerza para robar o proteger el balón.
func duel_skill(defending: bool) -> float:
	if defending:
		return stat("strength") * 0.5 + stat("decision_making") * 0.3 + stat("speed") * 0.2
	return stat("control") * 0.4 + stat("strength") * 0.3 + stat("dribbling") * 0.3


func set_stats(d: Dictionary) -> void:
	stats = {}
	for k in STAT_KEYS:
		stats[k] = int(d.get(k, 50))


## Stats al azar alrededor de una media, para los jugadores que no son el tuyo.
static func random_stats(rating: float, keeper := false) -> Dictionary:
	var d := {}
	for k in STAT_KEYS:
		d[k] = int(clampf(rating + randf_range(-12.0, 12.0), 30.0, 95.0))
	if keeper:
		for k in ["control", "decision_making", "composure"]:
			d[k] = int(clampf(rating + randf_range(0.0, 12.0), 30.0, 95.0))
	return d


func set_highlight(value: bool) -> void:
	_hl_ring.visible = value


func reset_to(pos: Vector3, face: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	facing = face
	_kick = {}
	move_input = Vector3.ZERO
	stun_timer = 0.0
	tackle_cooldown = 0.0
	_lunge_timer = 0.0
	energy = 1.0
	_receive_timer = 0.0
	_action_timer = 0.0
	if not _dive.is_empty():
		_dive = {}
		_avatar.set_mirrored(false)
	rotation.y = atan2(face.x, face.z)


func set_human(value: bool) -> void:
	is_human = value
	_ring.visible = value


## Marca "TÚ" encima de tu jugador estrella (el de tu carrera en FootballCareer).
var star_label: Label3D # la marca "TÚ"


func set_star() -> void:
	var l := Label3D.new()
	star_label = l
	l.text = "TÚ"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 72
	l.pixel_size = 0.008
	l.outline_size = 14
	l.modulate = Color(1.0, 0.92, 0.2)
	l.position = Vector3(0.0, 2.6, 0.0)
	add_child(l)


# ---------- aspecto provisional (estilo chibi con primitivas) ----------

func _build_visual(shirt: Color) -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var skin: Color = SKIN_TONES.pick_random()
	var hair: Color = HAIR_COLORS.pick_random()
	var shorts := Color(0.95, 0.95, 0.95) if team == 0 else Color(0.08, 0.1, 0.22)
	var socks := shirt.darkened(0.25)
	var black := Color(0.06, 0.06, 0.06)

	# Proporciones de adulto, low-poly (según la referencia del jugador).
	# Piernas: piel + media + bota, con pivote en la cadera para animarlas
	_leg_l = _limb(Vector3(-0.13, 0.86, 0.0), Vector3(0.17, 0.62, 0.18), skin)
	_leg_r = _limb(Vector3(0.13, 0.86, 0.0), Vector3(0.17, 0.62, 0.18), skin)
	for leg in [_leg_l, _leg_r]:
		FieldBuilder.add_mesh(leg, FieldBuilder.box(Vector3(0.18, 0.22, 0.19)), Vector3(0.0, -0.68, 0.0), socks)
		FieldBuilder.add_mesh(leg, FieldBuilder.box(Vector3(0.19, 0.1, 0.32)), Vector3(0.0, -0.8, 0.05), black)

	# Pantalón corto
	FieldBuilder.add_mesh(_visual, FieldBuilder.box(Vector3(0.5, 0.3, 0.3)), Vector3(0.0, 0.9, 0.0), shorts)

	# Torso ancho (camiseta)
	var torso := CapsuleMesh.new()
	torso.radius = 0.25
	torso.height = 0.72
	torso.radial_segments = 10
	torso.rings = 4
	var torso_mi := FieldBuilder.add_mesh(_visual, torso, Vector3(0.0, 1.33, 0.0), shirt)
	torso_mi.scale = Vector3(1.25, 1.0, 0.72)

	# Brazos: manga corta + antebrazo de piel + mano
	_arm_l = _limb(Vector3(-0.38, 1.6, 0.0), Vector3(0.18, 0.24, 0.18), shirt)
	_arm_r = _limb(Vector3(0.38, 1.6, 0.0), Vector3(0.18, 0.24, 0.18), shirt)
	_arm_l.rotation.z = -0.12
	_arm_r.rotation.z = 0.12
	var hand_color := Color(0.95, 0.95, 0.95) if is_keeper else skin
	for arm in [_arm_l, _arm_r]:
		FieldBuilder.add_mesh(arm, FieldBuilder.box(Vector3(0.13, 0.42, 0.13)), Vector3(0.0, -0.42, 0.0), skin)
		var hand := SphereMesh.new()
		hand.radius = 0.075
		hand.height = 0.15
		hand.radial_segments = 8
		hand.rings = 4
		FieldBuilder.add_mesh(arm, hand, Vector3(0.0, -0.67, 0.0), hand_color)

	# Cuello y cabeza
	var neck := CylinderMesh.new()
	neck.top_radius = 0.08
	neck.bottom_radius = 0.1
	neck.height = 0.14
	FieldBuilder.add_mesh(_visual, neck, Vector3(0.0, 1.71, 0.0), skin)
	var head := SphereMesh.new()
	head.radius = 0.19
	head.height = 0.44
	head.radial_segments = 10
	head.rings = 6
	FieldBuilder.add_mesh(_visual, head, Vector3(0.0, 1.92, 0.0), skin)
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.2
	hair_mesh.height = 0.2
	hair_mesh.is_hemisphere = true
	hair_mesh.radial_segments = 10
	hair_mesh.rings = 3
	FieldBuilder.add_mesh(_visual, hair_mesh, Vector3(0.0, 1.98, -0.02), hair)
	var ear := SphereMesh.new()
	ear.radius = 0.05
	ear.height = 0.1
	for ex: float in [-0.19, 0.19]:
		FieldBuilder.add_mesh(_visual, ear, Vector3(ex, 1.91, 0.0), skin)
	var eye := SphereMesh.new()
	eye.radius = 0.025
	eye.height = 0.05
	for ex: float in [-0.07, 0.07]:
		FieldBuilder.add_mesh(_visual, eye, Vector3(ex, 1.94, 0.17), black)
	FieldBuilder.add_mesh(_visual, FieldBuilder.box(Vector3(0.24, 0.035, 0.04)), Vector3(0.0, 2.0, 0.165), hair)


## Modelo real con esqueleto y animaciones, pintado por zonas con los colores del jugador.
func _build_model(shirt: Color) -> void:
	_avatar = PlayerAvatar.new()
	_visual = _avatar
	add_child(_avatar)
	_anim = _avatar.anim
	# Aspecto al azar; tu jugador y la equipación de tu equipo se aplican luego desde el perfil
	_avatar.set_colors({
		"skin_color": PlayerProfile.SKIN_TONES.pick_random(),
		"hair_color": PlayerProfile.HAIR_COLORS.pick_random(),
		"shirt_color": shirt,
		"shorts_color": Color(0.95, 0.95, 0.95) if team == 0 else Color(0.08, 0.1, 0.22),
		"socks_color": shirt.darkened(0.15),
		"boots_color": ItemCatalog.guayos_color(ItemCatalog.GUAYOS.keys().pick_random()),
		"show_hair": true,
		"beard_style": randi() % ItemCatalog.FACE_STYLES.size() if randf() < 0.45 else 0,
	})
	# Peinado al azar: la mitad con pelo corto pintado, la otra mitad con uno de los 3D
	var style: String = ["rapado", "rapado", "degradado", "calvo"].pick_random()
	if randf() < 0.5:
		style = HairBuilder.STYLES_3D.pick_random()
	_avatar.set_colors({"hair_style": ItemCatalog.shader_hair_index(style), "show_hair": style != "calvo"})
	_avatar.set_hair_style(style)
	_avatar.set_body_scale(Vector3.ONE * randf_range(0.95, 1.04))
	if is_keeper:
		# Portero: manga larga y guantes (blancos con el puño oscuro, o al revés si la
		# camiseta es muy clara, para que se distingan del brazo)
		var light := shirt.get_luminance() > 0.7
		_avatar.set_colors({"long_sleeves": true, "gloves": true,
			"glove_color": Color(0.16, 0.17, 0.2) if light else Color(0.95, 0.95, 0.96),
			"glove_color2": shirt.darkened(0.45) if not light else Color(0.95, 0.95, 0.96)})
	_anim.play("keeper_idle" if is_keeper else "idle")
	_anim.seek(randf() * 2.0, true) # que no respiren todos a la vez


func _build_rings() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.55
	ring_mesh.outer_radius = 0.7
	_ring = FieldBuilder.add_mesh(self, ring_mesh, Vector3(0.0, 0.03, 0.0), Color(1.0, 0.92, 0.2), true)
	_ring.scale = Vector3(1.0, 0.2, 1.0)
	_ring.visible = false

	# Aro verde: compañero desmarcado al que puedes pasar
	var hl_mesh := TorusMesh.new()
	hl_mesh.inner_radius = 0.6
	hl_mesh.outer_radius = 0.8
	_hl_ring = FieldBuilder.add_mesh(self, hl_mesh, Vector3(0.0, 0.04, 0.0), Color(0.2, 1.0, 0.35), true)
	_hl_ring.scale = Vector3(1.0, 0.2, 1.0)
	_hl_ring.visible = false


func _limb(pivot_pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	_visual.add_child(pivot)
	FieldBuilder.add_mesh(pivot, FieldBuilder.box(size), Vector3(0.0, -size.y * 0.5, 0.0), color)
	return pivot


func _animate(delta: float, speed: float) -> void:
	if _anim != null:
		_animate_model(delta, speed)
		return
	var k := clampf(speed / SPEED, 0.0, 1.3)
	_anim_t += delta * (4.0 + speed * 1.6)
	var swing := sin(_anim_t) * 0.8 * k
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.8
	_arm_r.rotation.x = swing * 0.8
	_visual.position.y = absf(sin(_anim_t)) * 0.07 * k

	var tilt := 0.0
	if stun_timer > 0.0:
		tilt = -0.5
	elif _lunge_timer > 0.0:
		tilt = 0.6
	_visual.rotation.x = lerpf(_visual.rotation.x, tilt, minf(1.0, 12.0 * delta))


## Elige la animación de movimiento según la velocidad, salvo si hay una acción en curso.
func _animate_model(delta: float, speed: float) -> void:
	# Sigue el balón con la mirada (no durante acciones: chutes, entradas, festejos).
	# Al sprintar se reduce: el jugador mira hacia donde corre, no al balón,
	# para evitar el efecto "torpe" de girar el cuello a toda velocidad.
	if match_ref != null and match_ref.ball != null:
		var free := _action_timer <= 0.0 and stun_timer <= 0.0 and not is_kicking()
		var look_w := 1.0 if free else 0.0
		if sprinting:
			look_w *= 0.3
		_avatar.look_at_point(match_ref.ball.global_position, look_w)
	if _action_timer > 0.0:
		_action_timer -= delta
		return
	var target := "idle"
	if is_keeper and has_ball() and _anim.has_animation("keeper_catch"):
		# Con el balón en las manos: postura final del blocaje (balón al pecho)
		if _anim.current_animation != "keeper_catch":
			_anim.play("keeper_catch", 0.15)
			_anim.seek(1.9, true)
		_anim.speed_scale = 0.0
		return
	if is_keeper and not walk_normal:
		target = "keeper_side" if speed > 1.2 else "keeper_idle"
	elif speed > (0.6 if _last_anim_speed > 0.6 else 0.9):
		# Trote a ritmo bajo y carrera de verdad al ir rápido (con margen para no parpadear)
		var running := _anim.current_animation in ["run", "run_back", "strafe_left", "strafe_right"]
		target = "run" if speed > (2.7 if running else 3.3) or not _anim.has_animation("jog") else "jog"
		if target == "jog" and speed < (1.8 if _anim.current_animation == "walk" else 1.5) and _anim.has_animation("walk"):
			target = "walk"
			if sad_gait and _anim.has_animation("walk_sad"):
				target = "walk_sad"
		if _jockey:
			# Hacia atrás o de lado según hacia dónde va respecto a donde mira
			var v := SoccerMatch.flat(velocity).normalized()
			var fwd := v.dot(facing)
			var left := v.dot(Vector3.UP.cross(facing))
			if fwd < -0.45:
				target = "run_back"
			elif absf(left) > 0.5:
				target = "strafe_left" if left > 0.0 else "strafe_right"
	if _anim.current_animation != target:
		# La mezcla depende de cuánto cambió la velocidad y de si venimos de una
		# acción: la vuelta al trote no debe cortar de golpe (P0-11).
		var blend := locomotion_blend(_last_anim_speed, speed, _action_blend)
		_anim.play(target, blend)
		if target == "idle":
			_anim.seek(randf() * 8.0, false) # que no respiren todos a la vez
	_action_blend = false
	_last_anim_speed = speed
	if target == "walk":
		_anim.speed_scale = clampf(speed / 1.6, 0.6, 1.1)
	elif target == "walk_sad":
		_anim.speed_scale = clampf(speed / 1.2, 0.6, 1.1)
	elif target == "jog":
		_anim.speed_scale = clampf(speed / 2.4, 0.75, 1.35)
	elif target == "run":
		_anim.speed_scale = clampf(speed / 5.5, 0.7, 1.7)
	elif target in ["run_back", "strafe_left", "strafe_right"]:
		_anim.speed_scale = clampf(speed / 4.6, 0.7, 1.5)
	else:
		_anim.speed_scale = 1.0
	# Cansancio visible: zancada más corta y respiración más agitada con poca energía.
	var low := clampf(energy / 0.45, 0.0, 1.0)
	if target in ["walk", "walk_sad", "jog", "run", "run_back", "strafe_left", "strafe_right"]:
		_anim.speed_scale *= lerpf(0.84, 1.0, low)
	elif target == "idle":
		_anim.speed_scale = lerpf(1.22, 1.0, low)
