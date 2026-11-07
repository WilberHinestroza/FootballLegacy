class_name LockerRoom
extends Node3D
## Vestuario del descanso: taquillas y paredes con los colores del club, bancos, pizarra
## y luces de techo; tus compañeros sentados (los mismos del campo) y el míster de pie
## dando la charla. Tiene su propia cámara; SoccerMatch lo crea en el 45' y lo quita al volver.

const SIZE := Vector3(13.0, 3.6, 9.0)  # ancho (x), alto, fondo (z)
const SEAT_H := 0.26 # centro de la tabla: arriba a 0,30 (bajo, como un banco de vestuario)

var camera: Camera3D
var coach: PlayerAvatar
var you: PlayerAvatar
var mates: Array[PlayerAvatar] = []
var _t := 0.0
var _cam_from := Transform3D()
var _cam_to := Transform3D()
var _cam_time := 4.0
## Cada compañero cambia de postura de vez en cuando (segundos que le quedan).
var _fidget := {}
## Tras los aplausos vuelven a sentarse normal.
var _cheer_t := 0.0


## Construye la sala a partir del partido: colores del local y jugadores del equipo 0.
func build(m: SoccerMatch) -> void:
	var c1: Color = FieldBuilder.home_color
	var c2: Color = FieldBuilder.home_color2
	var W := SIZE.x
	var D := SIZE.z
	var H := SIZE.y
	# Suelo de goma, techo y paredes del color del club
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(W, 0.1, D)), Vector3(0.0, -0.05, 0.0), Color(0.16, 0.17, 0.19))
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(W, 0.1, D)), Vector3(0.0, H + 0.05, 0.0), Color(0.82, 0.83, 0.85))
	var wall := c1.darkened(0.45)
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(W, H, 0.2)), Vector3(0.0, H * 0.5, -D * 0.5), wall)
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(W, H, 0.2)), Vector3(0.0, H * 0.5, D * 0.5), wall)
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(0.2, H, D)), Vector3(-W * 0.5, H * 0.5, 0.0), wall)
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(0.2, H, D)), Vector3(W * 0.5, H * 0.5, 0.0), wall)
	# Franja del segundo color a media altura y el nombre del club en la pared del fondo
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(W - 0.3, 0.18, 0.05)), Vector3(0.0, 2.55, -D * 0.5 + 0.13), c2)
	var club := Label3D.new()
	club.text = String(SoccerMatch.TEAM_NAMES[0]).to_upper()
	club.font_size = 160
	club.pixel_size = 0.004
	club.modulate = c2
	club.outline_size = 0
	club.position = Vector3(0.0, 3.05, -D * 0.5 + 0.12)
	add_child(club)

	# Taquillas con banco: fondo y dos laterales; cada una con su número
	var seats: Array[Transform3D] = []
	var lockers_back := 9
	for i in lockers_back:
		var x := (i - (lockers_back - 1) * 0.5) * 1.25
		seats.append(_locker(Transform3D(Basis(), Vector3(x, 0.0, -D * 0.5 + 0.1)), i + 1, c1, c2))
	for s: float in [-1.0, 1.0]:
		for i in 4:
			var z := -2.4 + i * 1.25
			var b := Basis(Vector3.UP, -s * PI * 0.5)
			seats.append(_locker(Transform3D(b, Vector3(s * (W * 0.5 - 0.1), 0.0, z)), 10 + i + (0 if s < 0.0 else 4), c1, c2))

	# Pizarra táctica en el centro, con la alineación dibujada
	var board_pos := Vector3(2.2, 0.0, 0.6)
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(0.06, 1.0, 0.06)), board_pos + Vector3(0.0, 0.5, 0.0), Color(0.3, 0.3, 0.32))
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(1.7, 1.1, 0.05)), board_pos + Vector3(0.0, 1.55, 0.0), Color(0.95, 0.96, 0.97))
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(1.5, 0.92, 0.02)), board_pos + Vector3(0.0, 1.55, 0.03), Color(0.2, 0.52, 0.28))
	for k in 10:
		var dot := Vector3(-0.55 + (k % 4) * 0.36, 1.2 + (k / 4) * 0.3, 0.05)
		FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(0.07, 0.07, 0.01)), board_pos + dot, c1.lightened(0.2), true)
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(0.6, 0.015, 0.01)), board_pos + Vector3(0.1, 1.72, 0.05), Color(1, 1, 1), true)
	# Mesa de masajes, botellas y balones por el suelo: que parezca usado
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(1.9, 0.75, 0.7)), Vector3(-3.6, 0.375, 2.6), Color(0.85, 0.87, 0.9))
	for k in 6:
		var bottle := FieldBuilder.add_mesh(self, CylinderMesh.new(), Vector3(randf_range(-4.5, 4.5), 0.12, randf_range(-2.8, -2.2)), c1.lightened(0.3))
		bottle.scale = Vector3(0.07, 0.12, 0.07)
	for k in 3:
		var bm := SphereMesh.new()
		bm.radius = 0.11
		bm.height = 0.22
		FieldBuilder.add_mesh(self, bm, Vector3(randf_range(-5.0, 5.0), 0.11, randf_range(1.0, 3.5)), Color(0.95, 0.95, 0.95))

	# Luces de techo: paneles que brillan y focos que iluminan la sala
	for x: float in [-3.8, 0.0, 3.8]:
		FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(1.6, 0.04, 0.5)), Vector3(x, H - 0.02, 0.0), Color(1.4, 1.4, 1.35), true)
		var l := OmniLight3D.new()
		l.position = Vector3(x, H - 0.4, 0.0)
		l.omni_range = 7.5
		l.light_energy = 1.6
		l.light_color = Color(1.0, 0.97, 0.9)
		add_child(l)

	# Tus compañeros, con su aspecto del partido, sentados; tú en la taquilla del centro
	var team: Array = (m.teams[0] as Array).duplicate()
	team.erase(m.star)
	team.push_front(m.star) # tú, en la taquilla del centro del fondo
	var order: Array[int] = [4, 3, 5, 2, 6, 1, 7, 0, 8, 9, 10, 13, 14]
	var seat_i := 0
	for p: SoccerPlayer in team:
		if seat_i >= order.size():
			break
		if p._avatar == null or (not p.visible and p != m.star):
			continue
		var av := PlayerAvatar.new()
		add_child(av)
		av.copy_look(p._avatar)
		var sc := av.scale
		av.transform = seats[order[seat_i]]
		av.scale = sc
		av.position.y = av.sit_offset(SEAT_H + 0.04)
		var anim: String = PlayerAvatar.SIT_ANIMS.pick_random()
		if p == m.star:
			you = av
			anim = "sit"
		else:
			mates.append(av)
		av.anim.play(anim)
		av.anim.seek(randf() * av.anim.current_animation_length, true)
		seat_i += 1

	# El míster de pie junto a la pizarra
	coach = PlayerAvatar.new()
	add_child(coach)
	coach.set_colors({"shirt_color": Color(0.12, 0.13, 0.17), "shirt_pattern": 9, "shirt_color2": c1,
		"long_sleeves": true, "long_pants": true, "shorts_color": Color(0.12, 0.13, 0.17),
		"skin_color": PlayerProfile.SKIN_TONES.pick_random(), "hair_color": Color(0.25, 0.22, 0.2),
		"socks_color": Color(0.1, 0.1, 0.12), "boots_color": Color(0.06, 0.06, 0.07)})
	coach.position = Vector3(1.0, 0.0, 1.0)
	coach.rotation.y = PI * 0.92 # mirando a los jugadores del fondo
	coach.anim.play("yell")

	camera = Camera3D.new()
	camera.fov = 58.0
	add_child(camera)
	# Entrada lenta desde la puerta hacia el míster
	_cam_from = _look(Vector3(-1.5, 1.7, 4.0), Vector3(0.0, 1.1, -2.0))
	_cam_to = _look(Vector3(0.6, 1.55, 3.0), Vector3(0.2, 1.0, -1.5))
	camera.transform = _cam_from


## Taquilla con su banco y número; devuelve dónde se sienta el jugador.
func _locker(at: Transform3D, number: int, c1: Color, c2: Color) -> Transform3D:
	var fwd := at.basis.z # hacia el centro de la sala
	var p := at.origin
	var cab := FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(1.1, 2.1, 0.5)), p + fwd * 0.25 + Vector3.UP * 1.05, c1.darkened(0.15))
	cab.basis = at.basis
	var trim := FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(1.12, 0.1, 0.52)), p + fwd * 0.25 + Vector3.UP * 2.1, c2)
	trim.basis = at.basis
	var back := FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(0.95, 1.6, 0.02)), p + fwd * 0.51 + Vector3.UP * 1.25, c1.darkened(0.45))
	back.basis = at.basis
	var bench := FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(1.2, 0.08, 0.45)), p + fwd * 0.75 + Vector3.UP * SEAT_H, Color(0.62, 0.45, 0.3))
	bench.basis = at.basis
	var lab := Label3D.new()
	lab.text = str(number)
	lab.font_size = 72
	lab.pixel_size = 0.004
	lab.modulate = c2
	lab.outline_size = 0
	lab.transform = Transform3D(at.basis, p + fwd * 0.52 + Vector3.UP * 1.85)
	add_child(lab)
	return Transform3D(at.basis, p + fwd * 0.82)


func _look(from: Vector3, to: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(to - from, Vector3.UP), from)


## Cámara que se acerca a `to` en `secs` segundos.
func move_camera(to_from: Vector3, to_target: Vector3, secs: float) -> void:
	_cam_from = camera.transform
	_cam_to = _look(to_from, to_target)
	_cam_time = secs
	_t = 0.0


## Primer plano de tu jugador (cuando te toca decidir).
func focus_you() -> void:
	if you:
		var head := you.position + Vector3.UP * 1.0
		var fwd := you.basis.z
		move_camera(head + fwd * 2.4 + Vector3.UP * 0.35 + you.basis.x * 0.8, head, 2.0)


## Reacción del vestuario a la decisión: aplausos y el míster arengando.
func cheer() -> void:
	for av in mates:
		av.anim.play(["sit_clap", "sit_react"].pick_random(), 0.2)
	coach.anim.play("fist_pump", 0.2)
	if you:
		you.anim.play("sit_clap", 0.2)
	_cheer_t = 3.2


func _process(delta: float) -> void:
	_t += delta
	var k := smoothstep(0.0, 1.0, clampf(_t / _cam_time, 0.0, 1.0))
	camera.transform = _cam_from.interpolate_with(_cam_to, k)
	# El míster alterna gritos y señalar la pizarra, y se va girando hacia
	# distintos jugadores mientras habla
	if not coach.anim.is_playing() or coach.anim.current_animation_position > 6.0:
		coach.anim.play(["argue", "point", "yell", "argue_2"].pick_random(), 0.3)
		if not mates.is_empty():
			coach.set_meta("face", mates.pick_random().position)
	if coach.has_meta("face"):
		var to: Vector3 = coach.get_meta("face") - coach.position
		var want := atan2(to.x, to.z)
		coach.rotation.y = lerp_angle(coach.rotation.y, want, minf(delta * 1.5, 1.0))
	var coach_head := coach.global_position + Vector3.UP * 1.65 * absf(coach.scale.y)
	if _cheer_t > 0.0:
		_cheer_t -= delta
		if _cheer_t <= 0.0:
			for av in mates + ([you] if you else []):
				av.anim.play(PlayerAvatar.SIT_ANIMS.pick_random(), 0.6)
	# Los compañeros escuchan al míster (lo miran) y se acomodan cada tanto
	for av in mates:
		av.look_at_point(coach_head, 0.8)
		var left: float = _fidget.get(av, randf_range(3.0, 12.0)) - delta
		if left <= 0.0 and _cheer_t <= 0.0:
			left = randf_range(7.0, 16.0)
			var cur := String(av.anim.current_animation)
			var opts: Array = PlayerAvatar.SIT_ANIMS.filter(func(n: String) -> bool: return n != cur)
			av.anim.play(opts.pick_random(), 0.8)
		_fidget[av] = left
	if you:
		you.look_at_point(coach_head, 0.6)
