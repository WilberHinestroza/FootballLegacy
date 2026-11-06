class_name Ball
extends Node2D
## Balón en 2.5D: `position` es el punto en el piso y `z` la altura.
## La sombra queda en el piso y el sprite se dibuja levantado.
## Tiene efecto (spin) que curva la trayectoria y se apaga solo.

const BALL_PX := 7.0    # tamaño del balón (WSC: 1/5 del alto del jugador)

var vel := Vector2.ZERO
var z: float = 0.0
var vz: float = 0.0
var spin: float = 0.0
var owner_p: Player = null
var last_touch: Player = null
var kind: String = "loose"       # "loose", "pass", "lob", "shot"
var receiver: Player = null
var kick_time: float = -9.0
var roll: float = 0.0
var trail: Array[Vector2] = []     # estela de fuego en tiros fuertes

var _sprite: Sprite2D

func _ready() -> void:
	var path := "res://assets/ball.png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_sprite = Sprite2D.new()
		_sprite.texture = tex
		var r: Rect2i = Sprites.opaque_rect(tex)
		_sprite.region_enabled = true
		_sprite.region_rect = Rect2(r)
		var s: float = BALL_PX / float(maxi(r.size.x, r.size.y))
		_sprite.scale = Vector2(s, s)
		add_child(_sprite)

func take(p: Player) -> void:
	owner_p = p
	last_touch = p
	vel = Vector2.ZERO
	z = 0.0
	vz = 0.0
	spin = 0.0
	kind = "loose"
	receiver = null

func release() -> void:
	owner_p = null
	kind = "loose"
	receiver = null

func launch(by: Player, v: Vector2, lift: float, spin_rate: float, k: String, now: float, recv: Player = null) -> void:
	owner_p = null
	last_touch = by
	vel = v
	z = maxf(z, 0.5)
	vz = lift
	spin = spin_rate
	kind = k
	receiver = recv
	kick_time = now

func is_free() -> bool:
	return owner_p == null

func step(dt: float) -> void:
	if owner_p != null:
		position = owner_p.ball_spot()
		z = 0.0
		vz = 0.0
		roll += owner_p.vel.length() * dt
		_update_visual()
		return
	_integrate(dt)
	roll += vel.length() * dt
	# Estela de fuego en los tiros fuertes.
	if kind == "shot" and vel.length() > 24.0 * Cfg.M:
		trail.append(position + Vector2(0, -z * Cfg.Z_PROJ))
		if trail.size() > 9:
			trail.remove_at(0)
	elif not trail.is_empty():
		trail.remove_at(0)
	_update_visual()

## Física del balón libre (también la usa predict()).
func _integrate(dt: float) -> void:
	var sp: float = vel.length()
	var airborne: bool = z > 0.0 or vz > 0.0
	# Efecto (Magnus): curva más en el aire; en el piso se apaga rápido.
	if absf(spin) > 0.001:
		vel = vel.rotated(spin * dt * (1.0 if airborne else 0.35))
		spin *= exp(-Cfg.SPIN_DECAY * dt * (1.0 if airborne else 3.0))
	position += vel * dt
	if airborne:
		vz -= Cfg.GRAVITY * dt
		z += vz * dt
		# Roce del aire: lineal + cuadrático (un tiro fuerte pierde más).
		vel *= maxf(1.0 - (Cfg.AIR_DRAG + Cfg.AIR_DRAG_QUAD * sp / Cfg.M) * dt, 0.0)
		if z <= 0.0:
			z = 0.0
			if vz < -1.5 * Cfg.M:
				# Pique: rebota con pérdida y el pasto le saca velocidad y efecto.
				vz = -vz * Cfg.BOUNCE
				vel *= 0.8
				spin *= 0.5
			else:
				vz = 0.0
	else:
		if sp > 0.0:
			sp = maxf(sp - (Cfg.ROLL_DECEL + Cfg.GRASS_DRAG * sp) * dt, 0.0)
			vel = vel.normalized() * sp if sp > 0.0 else Vector2.ZERO
		if sp < 3.0 * Cfg.M and kind != "loose":
			kind = "loose"

## Dónde quedará el balón (en el piso) dentro de t segundos: simula la
## misma física en pasos de 1/30 s sin tocar el balón real.
func predict(t: float) -> Vector2:
	if owner_p != null:
		return owner_p.position + owner_p.vel * t
	var sp0: Vector2 = position
	var v0: Vector2 = vel
	var z0: float = z
	var vz0: float = vz
	var s0: float = spin
	var k0: String = kind
	var steps: int = clampi(int(t * 30.0), 0, 60)
	for _i in steps:
		_integrate(1.0 / 30.0)
	var out: Vector2 = position
	position = sp0
	vel = v0
	z = z0
	vz = vz0
	spin = s0
	kind = k0
	return out

func _update_visual() -> void:
	# Conduciendo de espaldas a la cámara, la pelota va adelante del pie y
	# quedaba tapada por las piernas: se dibuja encima.
	# Pero nunca encima de OTRO jugador parado delante (más cerca de la
	# cámara): eso se veía como la pelota atravesándole el cuerpo.
	var front: bool = owner_p != null and owner_p.facing.y < -0.3 and not owner_p.holding
	var high: bool = z > 2.2 * Cfg.M
	if (front or z > 1.2 * Cfg.M) and not high and _someone_in_front():
		front = false
	z_index = 1 if (high or front or (z > 1.2 * Cfg.M and not _someone_in_front())) else 0
	# El arquero con el balón en las manos ya lo trae dibujado en su animación.
	visible = not (owner_p != null and owner_p.holding)
	if _sprite != null:
		_sprite.position = Vector2(0, -BALL_PX * 0.5 - z * Cfg.Z_PROJ)
		# Gira según cuánto rodó (radio ~0,11 m).
		_sprite.rotation = roll / (0.11 * Cfg.M) * 0.25
	queue_redraw()

## ¿Hay un jugador (que no la lleva) cuyo dibujo tapa la pelota desde adelante?
func _someone_in_front() -> bool:
	var par: Node = get_parent()
	if par == null:
		return false
	for n in par.get_children():
		if n is Player and n != owner_p:
			var dy: float = n.position.y - position.y
			if dy > 0.0 and dy < 3.0 * Cfg.M and absf(n.position.x - position.x) < 1.1 * Cfg.M:
				return true
	return false

func _draw() -> void:
	# Estela (en coordenadas del balón).
	if trail.size() > 1:
		for i in range(trail.size() - 1):
			var k: float = float(i + 1) / float(trail.size())
			var col: Color = Color(1.0, 0.35, 0.05, 0.25).lerp(Color(1.0, 0.9, 0.3, 0.9), k)
			draw_line(trail[i] - position + Vector2(0, -BALL_PX * 0.5), trail[i + 1] - position + Vector2(0, -BALL_PX * 0.5), col, 1.0 + 4.0 * k)
	# Sombra: se achica y aclara con la altura.
	var sh: float = clampf(1.0 - z / (6.0 * Cfg.M), 0.35, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 4.0 * sh, Color(0, 0, 0, 0.35 * sh))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _sprite == null:
		var c := Vector2(0, -4.5 - z * Cfg.Z_PROJ)
		draw_circle(c, 4.5, Color(0.08, 0.08, 0.1))
		draw_circle(c, 3.6, Color(0.97, 0.97, 0.95))
		var a: float = roll * 0.15
		draw_circle(c + Vector2(cos(a), sin(a)) * 1.5, 1.2, Color(0.12, 0.12, 0.16))
