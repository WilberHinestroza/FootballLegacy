class_name SoccerBall
extends RigidBody3D
## Balón con física real. Cuando un jugador lo controla, se "pega" delante de sus pies
## (regate) y deja de caer; al chutar o pasar vuelve a ser libre.

const RADIUS := 0.15 # un balón real mide 0.11; algo más grande para que se vea en el móvil
const TOUCH_EVERY := 2.8 # metros entre toques al conducir
const ROLL_RESIST := 0.9 # m/s² que pierde rodando por el césped (además del aire)

var _touch_phase := 0.0
## Cuán suelto va el balón al conducir (0 pegado al pie .. 1 toque largo recién dado).
## Lo leen los defensores para elegir cuándo entrar (BallContact).
var exposure := 0.0

var owner_player: SoccerPlayer = null:
	set(value):
		owner_player = value
		gravity_scale = 0.0 if value != null else 1.0
		exposure = 0.0
var last_touch: SoccerPlayer = null
var last_kick_kind := "" # "shot", "penalty", "pass", "throw": para contar bien los tiros a puerta
var sot_counted := false  # ya sumó este remate como tiro a puerta (evita duplicados)
var last_hit_post := false # el último remate pegó en el palo/larguero (para el relato)
var curl_rate := 0.0   # efecto: giro lateral en rad/s mientras vuela

var _curl_time := 0.0

var _blocked_player: SoccerPlayer = null
var _blocked_time := 0.0
var _teleport_to: Variant = null
var _pending_velocity: Variant = null


func _ready() -> void:
	mass = 0.45
	continuous_cd = true
	can_sleep = false
	linear_damp = 0.4 # ver air_drag()
	angular_damp = 1.0
	collision_layer = 4
	collision_mask = FieldBuilder.LAYER_WALLS | FieldBuilder.LAYER_GROUND

	contact_monitor = true
	max_contacts_reported = 3
	body_entered.connect(_on_body_entered)

	var pm := PhysicsMaterial.new()
	pm.bounce = 0.5
	pm.friction = 0.6
	physics_material_override = pm

	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = RADIUS
	cs.shape = sh
	add_child(cs)

	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	sm.radial_segments = 32
	sm.rings = 16
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	_mat = ShaderMaterial.new()
	_mat.shader = BALL_SHADER
	mi.material_override = _mat
	add_child(mi)
	_mesh = mi
	set_design(design)


const BALL_SHADER := preload("res://match3d/shaders/ball.gdshader")
## Diseños de balón: estilo del shader y colores (base, paneles, detalle). Mismo orden que
## BallDesign de FootballLegacy (los 16 balones pixel art), así el balón elegido sale igual.
const DESIGNS := [
	{"name": "Clásico", "style": 0, "base": Color(0.96, 0.96, 0.95), "panel": Color(0.07, 0.07, 0.09), "accent": Color.BLACK},
	{"name": "Estrella", "style": 3, "base": Color(0.55, 0.72, 0.92), "panel": Color(0.97, 0.97, 1.0), "accent": Color(0.12, 0.3, 0.62)},
	{"name": "Flúor", "style": 4, "base": Color(0.86, 1.0, 0.18), "panel": Color(1.0, 0.42, 0.72), "accent": Color(0.08, 0.06, 0.1)},
	{"name": "Invierno Naranja", "style": 0, "base": Color(1.0, 0.42, 0.1), "panel": Color(0.12, 0.15, 0.32), "accent": Color.BLACK, "shade": 0.15},
	{"name": "Cuero Retro", "style": 5, "base": Color(0.58, 0.32, 0.14), "panel": Color(0.4, 0.2, 0.08), "accent": Color(0.9, 0.82, 0.62)},
	{"name": "Dorado", "style": 0, "base": Color(1.0, 0.8, 0.32), "panel": Color(0.82, 0.55, 0.14), "accent": Color.BLACK, "metal": 0.5, "shade": 0.2},
	{"name": "Tricolor", "style": 6, "base": Color(0.97, 0.97, 0.96), "panel": Color(0.1, 0.55, 0.28), "accent": Color(0.85, 0.12, 0.14)},
	{"name": "Rojiblanco", "style": 0, "base": Color(0.97, 0.97, 0.96), "panel": Color(0.86, 0.1, 0.12), "accent": Color.BLACK},
	{"name": "Remolino", "style": 4, "base": Color(0.96, 0.97, 0.97), "panel": Color(0.12, 0.2, 0.36), "accent": Color(0.2, 0.62, 0.5)},
	{"name": "Circuito", "style": 7, "base": Color(0.2, 0.22, 0.28), "panel": Color(0.62, 0.3, 0.92), "accent": Color(0.25, 0.95, 1.0)},
	{"name": "Luna", "style": 8, "base": Color(0.97, 0.97, 0.98), "panel": Color(0.1, 0.14, 0.32), "accent": Color.BLACK},
	{"name": "Llamas", "style": 9, "base": Color(0.88, 0.12, 0.05), "panel": Color(1.0, 0.55, 0.08), "accent": Color(1.0, 0.95, 0.6)},
	{"name": "Acero", "style": 0, "base": Color(0.62, 0.72, 0.84), "panel": Color(0.36, 0.46, 0.6), "accent": Color.BLACK, "metal": 0.45, "shade": 0.25},
	{"name": "Camuflaje", "style": 10, "base": Color(0.46, 0.5, 0.3), "panel": Color(0.28, 0.32, 0.18), "accent": Color(0.68, 0.64, 0.46)},
	{"name": "Rombos", "style": 0, "base": Color(0.97, 0.97, 0.98), "panel": Color(0.1, 0.15, 0.36), "accent": Color.BLACK},
	{"name": "Carbón", "style": 0, "base": Color(0.3, 0.3, 0.32), "panel": Color(0.13, 0.13, 0.15), "accent": Color.BLACK, "metal": 0.2, "shade": 0.3},
]
static var design := 0 # el partido lo elige antes de crear el balón
var _mat: ShaderMaterial
var _mesh: MeshInstance3D
var _squash_t := 0.0
var _squash_k := 0.0


## Deformación breve del balón al golpearlo o al chocar: aplasta en la dirección del golpe.
func _squash(k: float) -> void:
	if k < 0.15 or _mesh == null:
		return
	_squash_k = k
	_squash_t = 0.12


func set_design(i: int) -> void:
	var d: Dictionary = DESIGNS[clampi(i, 0, DESIGNS.size() - 1)]
	_mat.set_shader_parameter("style", d.style)
	_mat.set_shader_parameter("base_color", d.base)
	_mat.set_shader_parameter("panel_color", d.panel)
	_mat.set_shader_parameter("accent_color", d.accent)
	_mat.set_shader_parameter("metal", float(d.get("metal", 0.0)))
	_mat.set_shader_parameter("panel_shade", float(d.get("shade", 0.0)))


var _trail: Array[MeshInstance3D] = []
var _hist: Array[Vector3] = []


## Estela de los tiros fuertes: bolitas que se desvanecen detrás del balón.
func _build_trail() -> void:
	for i in 8:
		var sm := SphereMesh.new()
		sm.radius = RADIUS * (0.85 - i * 0.08)
		sm.height = sm.radius * 2.0
		sm.radial_segments = 8
		sm.rings = 4
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = FieldBuilder.mat(Color(1.0, 1.0, 1.0, 0.4 * (1.0 - i / 8.0)), true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		mi.visible = false
		add_child(mi)
		_trail.append(mi)


func _physics_process(delta: float) -> void:
	if _blocked_time > 0.0:
		_blocked_time -= delta
	if _mesh:
		if _squash_t > 0.0:
			_squash_t -= delta
			var v := linear_velocity
			var f := sin(clampf(_squash_t / 0.12, 0.0, 1.0) * PI) * 0.22 * _squash_k
			var axis := v.normalized() if v.length() > 0.5 else Vector3.UP
			# Escala en ejes del mundo (el cuerpo gira): se deshace la rotación del padre
			var b := Basis.looking_at(axis) if absf(axis.dot(Vector3.UP)) < 0.99 else Basis()
			var sc := b * Basis.from_scale(Vector3(1.0 + f * 0.5, 1.0 + f * 0.5, 1.0 - f)) * b.inverse()
			_mesh.basis = global_transform.basis.orthonormalized().inverse() * sc
		elif _mesh.basis != Basis():
			_mesh.basis = Basis()
	if _trail.is_empty():
		_build_trail()
	_hist.push_front(global_position)
	if _hist.size() > 17:
		_hist.pop_back()
	var show := owner_player == null and linear_velocity.length() > 15.0
	for i in _trail.size():
		var mi := _trail[i]
		mi.visible = show and _hist.size() > (i + 1) * 2
		if mi.visible:
			mi.global_position = _hist[(i + 1) * 2]


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _teleport_to != null:
		var xf := state.transform
		xf.origin = _teleport_to
		state.transform = xf
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_teleport_to = null
		return

	if _pending_velocity != null:
		var v: Vector3 = _pending_velocity
		state.linear_velocity = v
		state.angular_velocity = Vector3(v.z, 0.0, -v.x) / RADIUS * 0.5
		_pending_velocity = null
		return

	if owner_player != null:
		var p := owner_player
		var pv := p.velocity
		pv.y = 0.0
		var target: Vector3
		var stiffness := 14.0
		if p.is_kicking():
			target = p.kick_spot() # quieto delante del pie que va a golpear
			stiffness = 18.0
		elif p.is_keeper:
			# En las manos (sigue a los huesos de la animación: blocaje, estirada, saque)
			target = p.hands_position() + p.facing * 0.12
			stiffness = 30.0
		else:
			# Conducción a toques: cada TOUCH_EVERY metros el pie lo adelanta y luego el
			# jugador lo alcanza. Parado, el balón queda junto al pie.
			var spd := pv.length()
			_touch_phase += state.step * spd / TOUCH_EVERY
			if _touch_phase >= 1.0:
				_touch_phase -= 1.0
				SoundFx.play("touch", -14.0)
			var run := clampf((spd - 0.5) / 3.0, 0.0, 1.0)
			# Esprintando el toque es más largo; el buen regateador lo lleva más pegado
			var sprint_k := clampf((spd - SoccerPlayer.SPEED) / (SoccerPlayer.SPRINT_SPEED - SoccerPlayer.SPEED), 0.0, 1.0)
			var touch := BallContact.touch_length(p.stat("dribbling"), p.stat("control"), sprint_k)
			var extra := run * BallContact.TOUCH_BASE * touch * pow(1.0 - _touch_phase, 2.0)
			exposure = BallContact.exposure(extra)
			var ahead := 0.42 + extra
			target = p.global_position + p.facing * ahead
			# En el pie izquierdo: del lado de la cámara, para que el cuerpo no lo tape
			target -= p.facing.cross(Vector3.UP) * 0.15
			stiffness = 10.0 + 12.0 * (1.0 - _touch_phase) * run
		if not p.is_keeper:
			target.y = RADIUS
		else:
			target.y = maxf(target.y, RADIUS)
		var to := target - state.transform.origin
		var nv := pv + to * stiffness
		state.linear_velocity = nv
		state.angular_velocity = Vector3(nv.z, 0.0, -nv.x) / RADIUS
		return

	# Rodando por el césped: algo de resistencia y el giro casa con el avance
	var on_grass := state.transform.origin.y < RADIUS + 0.03 and absf(state.linear_velocity.y) < 1.0
	if on_grass:
		var lv := state.linear_velocity
		var hv := Vector3(lv.x, 0.0, lv.z)
		var spd := hv.length()
		if spd > 0.01:
			# Solo frena los balones lentos: los pases calculados no se quedan cortos
			var dec := minf(spd, ROLL_RESIST * state.step * clampf((7.0 - spd) / 4.0, 0.0, 1.0))
			state.linear_velocity = lv - hv / spd * dec
			var roll := Vector3(hv.z, 0.0, -hv.x) / RADIUS
			state.angular_velocity = state.angular_velocity.lerp(roll, minf(1.0, 10.0 * state.step))

	# Efecto: curva la trayectoria girando la velocidad horizontal
	if curl_rate != 0.0 and _curl_time > 0.0:
		_curl_time -= state.step
		var v := state.linear_velocity
		var fv := Vector3(v.x, 0.0, v.z)
		if fv.length() > 3.0:
			state.linear_velocity = v + Vector3.UP.cross(fv) * curl_rate * state.step
			state.angular_velocity += Vector3.UP * curl_rate * 8.0 * state.step


## Frenado real del aire: el linear_damp del balón más el del proyecto (Godot los suma).
static func air_drag() -> float:
	return 0.4 + float(ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.1))


## Segundos que tarda en recorrer `dist` metros en horizontal saliendo a `speed` m/s.
static func flight_time(dist: float, speed: float) -> float:
	var k := air_drag()
	var r := dist * k / maxf(speed, 0.1)
	if r >= 0.95:
		return 3.0
	return -log(1.0 - r) / k


## Velocidad vertical para estar `rise` metros más arriba al cabo de `t` segundos.
static func lift_for(rise: float, t: float) -> float:
	var k := air_drag()
	var f := (1.0 - exp(-k * t)) / k
	return (rise + 9.8 * t / k) / f - 9.8 / k


## Suelta el balón con una velocidad. `blocked` no puede recogerlo durante `block_time`.
func release(vel: Vector3, blocked: SoccerPlayer = null, block_time := 0.3) -> void:
	owner_player = null
	curl_rate = 0.0
	_blocked_player = blocked
	_blocked_time = block_time
	_pending_velocity = vel


func kick(by: SoccerPlayer, vel: Vector3, curl := 0.0, kind := "pass") -> void:
	last_touch = by
	last_kick_kind = kind
	sot_counted = false
	last_hit_post = false
	release(vel, by, 0.3)
	curl_rate = curl
	_curl_time = 1.6
	var k := clampf(vel.length() / 30.0, 0.0, 1.0)
	SoundFx.play("kick", lerpf(-12.0, 0.0, k), lerpf(1.25, 0.85, k))
	_squash(k)
	if k > 0.7 and get_parent().has_method("shake"):
		get_parent().shake(0.25 * k) # disparo con todo: la cámara lo nota


## Poste, larguero o red: cada cuerpo del campo lleva en "sfx" qué sonido hace.
func _on_body_entered(body: Node) -> void:
	var spd := linear_velocity.length()
	if body.has_meta("sfx") and spd > 3.0:
		SoundFx.play(body.get_meta("sfx"), lerpf(-10.0, 0.0, clampf(spd / 25.0, 0.0, 1.0)))
		_squash(clampf(spd / 25.0, 0.0, 1.0) * 0.8)
		if body.get_meta("sfx") == "post" and get_parent().has_method("shake"):
			last_hit_post = true
			get_parent().shake(0.6) # ¡al palo!


## Primer toque: quita casi toda la velocidad del pase y deja el balón con el ritmo del jugador.
func trap(p: SoccerPlayer) -> void:
	# Primer toque: se queda pegado al pie del que recibe. Con 0.2 se notaba
	# demasiado el balón "escapándose" en pases fuertes; 0.12 lo asienta.
	linear_velocity = p.velocity + (linear_velocity - p.velocity) * 0.12


## Control con el cuerpo (pecho/muslo): un pase a media altura llega igual de
## controlable, pero el primer toque queda algo más suelto que con el pie.
func trap_body(p: SoccerPlayer) -> void:
	linear_velocity = p.velocity + (linear_velocity - p.velocity) * 0.28
	linear_velocity.y = maxf(linear_velocity.y, 0.4)


## Velocidad real del balón. Al soltar un chute la velocidad queda pendiente
## hasta el siguiente paso de física, así que `linear_velocity` todavía vale 0:
## sin esto, un remate recién lanzado parecía un balón parado.
func speed() -> float:
	var v := linear_velocity.length()
	if _pending_velocity != null:
		v = maxf(v, (_pending_velocity as Vector3).length())
	return v


## Velocidad con la que viaja ahora, aunque la física todavía no la aplicó.
func velocity_now() -> Vector3:
	if _pending_velocity != null:
		return _pending_velocity
	return linear_velocity


## El portero despeja en lugar de atrapar.
func deflect(keeper: SoccerPlayer) -> void:
	var v := linear_velocity
	last_touch = keeper
	if not keeper.is_diving():
		keeper.play_action_from("keeper_catch", 0.45, 2.0, 0.5) # despeje de pie, con las manos abajo
	release(Vector3(-v.x * 0.35, absf(v.y) * 0.4 + 3.0, v.z * 0.4 + randf_range(-5.0, 5.0)), keeper, 0.6)


## P0-09 · Un defensor de campo se interpone en un remate: el balón rebota en
## su cuerpo y sale despedido, en vez de quedar limpio a sus pies.
func deflect_body(p: SoccerPlayer) -> void:
	var v := linear_velocity
	last_touch = p
	# Sale hacia el lado contrario al cuerpo del defensor, con algo de altura.
	var side := signf(global_position.z - p.global_position.z)
	if side == 0.0:
		side = 1.0 if randf() < 0.5 else -1.0
	release(Vector3(-v.x * 0.45 + randf_range(-2.0, 2.0),
			maxf(absf(v.y) * 0.35, 1.8),
			side * randf_range(2.5, 6.5)), p, 0.5)
	_squash(clampf(v.length() / 25.0, 0.0, 1.0) * 0.6)


## Impide que `p` toque el balón un momento (p. ej. el portero batido).
func block_pickup(p: SoccerPlayer, t: float) -> void:
	_blocked_player = p
	_blocked_time = t


func can_be_picked_by(p: SoccerPlayer) -> bool:
	return not (_blocked_time > 0.0 and p == _blocked_player)


func reset_to(pos: Vector3) -> void:
	owner_player = null
	last_touch = null
	last_kick_kind = ""
	sot_counted = false
	last_hit_post = false
	curl_rate = 0.0
	_pending_velocity = null
	_teleport_to = pos
