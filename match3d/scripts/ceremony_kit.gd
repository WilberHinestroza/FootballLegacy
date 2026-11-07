class_name CeremonyKit
extends RefCounted
## Piezas comunes de las ceremonias en el césped (MVP del partido, campeones):
## presentador de traje, fotógrafos con flash, confeti y "caminar hasta" con giro
## suave. Lo usan MvpCeremony y TrophyCeremony. Sin estado propio.


## Persona de traje oscuro con corbata `tie` (presentador, directivo). Mira hacia +Z.
static func suit_person(parent: Node3D, tie: Color, seed_text: String) -> PlayerAvatar:
	var av := PlayerAvatar.new()
	parent.add_child(av)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	av.set_colors({"skin_color": PlayerProfile.SKIN_TONES[rng.randi() % PlayerProfile.SKIN_TONES.size()],
		"hair_color": Color.from_hsv(0.08, 0.5, rng.randf_range(0.08, 0.5)), "show_hair": true,
		"shirt_color": Color(0.08, 0.08, 0.11), "shirt_pattern": 9, "shirt_color2": tie,
		"long_sleeves": true, "long_pants": true, "shorts_color": Color(0.08, 0.08, 0.11),
		"socks_color": Color(0.05, 0.05, 0.06), "boots_color": Color(0.03, 0.03, 0.03)})
	av.anim.play("idle")
	return av


## Fotógrafo de rodillas con su cámara, mirando hacia `look`. El flash (OmniLight3D)
## va en su meta "flash" y se dispara con `flash()`.
static func photographer(parent: Node3D, pos: Vector3, look: Vector3, vest: Color) -> PlayerAvatar:
	var av := PlayerAvatar.new()
	parent.add_child(av)
	av.set_colors({"skin_color": PlayerProfile.SKIN_TONES.pick_random(), "hair_color": PlayerProfile.HAIR_COLORS.pick_random(),
		"show_hair": true, "shirt_color": Color(0.15, 0.15, 0.18), "shirt_pattern": 8, "shirt_color2": vest,
		"long_sleeves": true, "long_pants": true, "shorts_color": Color(0.2, 0.22, 0.28),
		"socks_color": Color(0.1, 0.1, 0.12), "boots_color": Color(0.06, 0.06, 0.07)})
	av.position = pos
	face(av, look, 1.0)
	if av.anim.has_animation("kneel"):
		av.anim.play("kneel")
		av.anim.seek(randf() * av.anim.current_animation_length, true)
	# La cámara va EN LAS MANOS (antes era una caja fija delante del pecho que se
	# quedaba flotando mientras los brazos colgaban): brazos por código "cam_photo"
	# (se la lleva a la cara, dispara, la baja) y la cámara sigue a las manos.
	av.pose_arms("cam_photo", 0.01)
	var ap := av.skeleton.get_children().filter(func(c: Node) -> bool: return c is ArmPose)
	if not ap.is_empty():
		(ap[0] as ArmPose).seed = randf() * 5.0
	var grip := _CameraGrip.new()
	grip.av = av
	var body := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.16, 0.12, 0.12)
	body.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.06)
	body.material_override = m
	grip.add_child(body)
	var lens := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.035
	lm.bottom_radius = 0.04
	lm.height = 0.1
	lens.mesh = lm
	lens.material_override = m
	lens.rotation.x = PI * 0.5
	lens.position = Vector3(0.0, 0.0, 0.1)
	grip.add_child(lens)
	av.add_child(grip)
	var light := OmniLight3D.new()
	light.light_color = Color(0.95, 0.97, 1.0)
	light.omni_range = 7.0
	light.light_energy = 0.0
	light.position = Vector3(0.0, 0.0, 0.18)
	grip.add_child(light)
	av.set_meta("flash", light)
	return av


## Destello de flash de un fotógrafo (luz blanca muy corta).
static func flash(av: PlayerAvatar) -> void:
	var light: OmniLight3D = av.get_meta("flash", null)
	if light == null:
		return
	light.light_energy = 5.0
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.14)


## Lluvia de confeti (un solo disparo) sobre `pos`, en una caja de `extents`.
static func confetti(parent: Node3D, pos: Vector3, extents: Vector3, colors: Array) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 220
	p.lifetime = 4.5
	p.explosiveness = 0.8
	p.position = pos
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -2.2, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.05)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	var pc := PackedColorArray()
	var offs := PackedFloat32Array()
	for i in colors.size():
		pc.append(colors[i])
		offs.append(float(i) / maxf(1.0, float(colors.size() - 1)))
	g.colors = pc
	g.offsets = offs
	p.color_initial_ramp = g
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Gira `n` hacia `target` (en el plano), con suavidad `k` (0-1 por frame).
static func face(n: Node3D, target: Vector3, k: float) -> void:
	var d := target - n.global_position
	if Vector2(d.x, d.z).length() < 0.05:
		return
	n.rotation.y = lerp_angle(n.rotation.y, atan2(d.x, d.z), clampf(k, 0.0, 1.0))


## Camina (o trota, si `speed` > 2,2) hacia `target`, girando de a poco; frena al
## llegar. La altura pasa a la del destino en el último metro (subir al podio).
## Devuelve true mientras se mueve.
static func step_to(n: Node3D, anim: AnimationPlayer, target: Vector3, speed: float, delta: float) -> bool:
	var to := Vector3(target.x - n.global_position.x, 0.0, target.z - n.global_position.z)
	var d := to.length()
	if d <= 0.08:
		n.global_position.y = target.y
		return false
	var spd := minf(speed, d * 2.0 + 0.4)
	face(n, n.global_position + to, delta * 6.0)
	n.global_position += to / d * minf(spd * delta, d)
	if d < 1.0:
		n.global_position.y = lerpf(n.global_position.y, target.y, minf(1.0, delta * 6.0))
	var want := "jog" if spd > 2.2 else "walk"
	if anim != null and anim.has_animation(want):
		if anim.current_animation != want:
			anim.play(want, 0.25)
		anim.speed_scale = clampf(spd / (3.2 if want == "jog" else 1.4), 0.6, 1.4)
	return true


## Cámara de fotos sujeta: cada cuadro se pone entre las manos del fotógrafo,
## mirando hacia donde mira él (las manos las mueve ArmPose "cam_photo").
class _CameraGrip extends Node3D:
	var av: PlayerAvatar

	func _process(_delta: float) -> void:
		if av == null:
			return
		global_position = av.hands_position() + av.global_transform.basis.z.normalized() * 0.1
		global_rotation = av.global_rotation
