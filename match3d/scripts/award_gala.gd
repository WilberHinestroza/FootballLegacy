class_name AwardGala
extends Node3D
## Gala de premios individuales (Balón de Oro, Bota de Oro, MVP...): salón oscuro con
## alfombra roja, escenario, pantalla gigante y público de traje. Los focos barren la sala
## ("Y el ganador es..."), se posan sobre el ganador, sale el trofeo 3D (TrophyBuilder) en
## su mano, confeti y aplausos. Mundo y cámara propios: el RPG lo mete en un recuadro con
## AwardGala.make_view(datos, tamaño); el ganador es tu jugador si `profile` viene dado.

const REVEAL_AT := 3.6
const STAGE := Vector3(0.0, 0.6, -4.0)   # centro del escenario (encima de la tarima)

var camera: Camera3D
var winner: PlayerAvatar
var _d: Dictionary
var _t := 0.0
var _revealed := false
var _screen_lbl: Label3D
var _spots: Array[SpotLight3D] = []
var _audience: Array[PlayerAvatar] = []
var _confetti: CPUParticles3D
var _trophy: Node3D
var _trophy_h := 0.5
var _lifted := false


## Recuadro de interfaz con la gala dentro (mundo propio). d = {award, title, subtitle,
## winner_name, profile (PlayerProfile o null), is_you}
static func make_view(d: Dictionary, size: Vector2) -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(maxi(int(size.x), 640), maxi(int(size.y), 240)) # con stretch lo ajusta el recuadro
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(vp)
	var g := AwardGala.new()
	vp.add_child(g)
	g.setup(d)
	return box


func setup(d: Dictionary) -> void:
	_d = d
	_build_hall()
	_build_audience()
	_build_winner()
	camera = Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.make_current()
	_update_camera()


# ---------------------------------------------------------------- sala

func _build_hall() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.3, 0.45)
	env.ambient_light_energy = 0.35
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.15, 0.12, 0.2)
	env.fog_density = 0.02
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var gold := TrophyBuilder.metal("gold")
	# Suelo brillante, paredes oscuras con columnas doradas
	var floor_m := StandardMaterial3D.new()
	floor_m.albedo_color = Color(0.05, 0.05, 0.07)
	floor_m.roughness = 0.12
	floor_m.metallic = 0.5
	_add(FieldBuilder.box(Vector3(30.0, 0.1, 30.0)), Vector3(0, -0.05, 0), floor_m)
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.07, 0.06, 0.12)
	_add(FieldBuilder.box(Vector3(30.0, 10.0, 0.3)), Vector3(0, 5.0, -7.5), wall)
	for x: float in [-7.0, -3.5, 3.5, 7.0]:
		_add(FieldBuilder.box(Vector3(0.35, 8.0, 0.35)), Vector3(x, 4.0, -7.1), gold)
	# Escenario con escalones y borde dorado
	var stage_m := StandardMaterial3D.new()
	stage_m.albedo_color = Color(0.1, 0.08, 0.14)
	stage_m.roughness = 0.3
	_add(FieldBuilder.box(Vector3(9.0, 0.6, 4.0)), Vector3(0, 0.3, -5.0), stage_m)
	_add(FieldBuilder.box(Vector3(9.0, 0.05, 0.08)), Vector3(0, 0.6, -3.0), gold)
	for i in 3:
		_add(FieldBuilder.box(Vector3(2.4, 0.2, 0.35)), Vector3(0, 0.1 + i * 0.2 - 0.0, -2.0 - i * 0.35 + 0.35), stage_m)
	# Alfombra roja desde el público hasta el escenario
	var carpet := StandardMaterial3D.new()
	carpet.albedo_color = Color(0.55, 0.05, 0.08)
	carpet.roughness = 0.9
	_add(FieldBuilder.box(Vector3(2.0, 0.02, 14.0)), Vector3(0, 0.01, 4.5), carpet)
	# Pantalla gigante con el premio
	var screen := StandardMaterial3D.new()
	screen.albedo_color = Color(0.05, 0.05, 0.1)
	screen.emission_enabled = true
	screen.emission = Color(0.18, 0.12, 0.35)
	screen.emission_energy_multiplier = 1.2
	_add(FieldBuilder.box(Vector3(8.0, 3.6, 0.1)), Vector3(0, 4.3, -7.2), screen)
	_add(FieldBuilder.box(Vector3(8.3, 0.12, 0.12)), Vector3(0, 6.15, -7.15), gold)
	_add(FieldBuilder.box(Vector3(8.3, 0.12, 0.12)), Vector3(0, 2.45, -7.15), gold)
	var title := Label3D.new()
	title.text = String(_d.get("title", "BALÓN DE ORO")).to_upper()
	title.font_size = 140
	title.pixel_size = 0.006
	title.modulate = Color(1.0, 0.85, 0.4)
	title.outline_size = 0
	title.position = Vector3(0, 5.3, -7.1)
	add_child(title)
	_screen_lbl = Label3D.new()
	_screen_lbl.text = String(_d.get("subtitle", ""))
	_screen_lbl.font_size = 90
	_screen_lbl.pixel_size = 0.006
	_screen_lbl.outline_size = 0
	_screen_lbl.position = Vector3(0, 3.7, -7.1)
	add_child(_screen_lbl)
	# Atril
	_add(FieldBuilder.box(Vector3(0.7, 1.1, 0.5)), Vector3(2.6, 0.6 + 0.55, -4.4), gold)
	# Focos: tres que barren la sala y uno cálido de relleno sobre el escenario
	for i in 3:
		var s := SpotLight3D.new()
		s.spot_range = 22.0
		s.spot_angle = 11.0
		s.light_energy = 9.0
		s.light_color = [Color(1.0, 0.9, 0.7), Color(0.7, 0.8, 1.0), Color(1.0, 0.75, 0.9)][i]
		s.position = Vector3((i - 1) * 5.0, 8.0, 2.0)
		add_child(s)
		_spots.append(s)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 3.0, -2.0)
	fill.omni_range = 9.0
	fill.light_energy = 0.8
	fill.light_color = Color(1.0, 0.85, 0.65)
	add_child(fill)
	# Público de fondo: siluetas baratas en penumbra
	var sil := StandardMaterial3D.new()
	sil.albedo_color = Color(0.06, 0.06, 0.08)
	for r in 5:
		for k in 14:
			var x := -8.5 + k * 1.3 + (0.6 if r % 2 == 1 else 0.0)
			if absf(x) < 1.3:
				continue
			var cap := CapsuleMesh.new()
			cap.radius = 0.25
			cap.height = 1.1
			_add(cap, Vector3(x, 0.55 + r * 0.25, 6.5 + r * 1.2), sil)
	_confetti = _make_confetti()
	add_child(_confetti)


func _add(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


## Dos filas de invitados de traje sentados a los lados de la alfombra.
func _build_audience() -> void:
	var chair := StandardMaterial3D.new()
	chair.albedo_color = Color(0.35, 0.05, 0.08)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(_d.get("winner_name", "")))
	for row in 2:
		for k in 6:
			var side := -1.0 if k < 3 else 1.0
			var x := side * (1.7 + (k % 3) * 1.15)
			var z := 1.2 + row * 1.6
			_add(FieldBuilder.box(Vector3(0.7, 0.45, 0.6)), Vector3(x, 0.225, z + 0.1), chair)
			_add(FieldBuilder.box(Vector3(0.7, 0.8, 0.1)), Vector3(x, 0.6, z + 0.4), chair)
			var av := PlayerAvatar.new()
			add_child(av)
			_suit(av, rng, Color.from_hsv(rng.randf(), 0.4, 0.3))
			av.position = Vector3(x, 0.0, z)
			av.rotation.y = PI # mirando al escenario
			av.anim.play(["sit_talk", "sit", "sit_2"][rng.randi() % 3])
			av.anim.seek(rng.randf() * av.anim.current_animation_length, true)
			_audience.append(av)


## Traje oscuro con corbata; aspecto aleatorio (o el de un perfil).
func _suit(av: PlayerAvatar, rng: RandomNumberGenerator, tie: Color, prof: PlayerProfile = null) -> void:
	if prof != null:
		av.apply_profile(prof)
	else:
		av.set_colors({"skin_color": PlayerProfile.SKIN_TONES[rng.randi() % PlayerProfile.SKIN_TONES.size()],
			"hair_color": Color.from_hsv(0.08, 0.5, rng.randf_range(0.08, 0.5))})
		av.set_hair_style(["rapado", "degradado", "engominado", "raya", "tupe", "calvo"][rng.randi() % 6])
	var jacket: Color = [Color(0.08, 0.08, 0.1), Color(0.1, 0.1, 0.16), Color(0.15, 0.12, 0.1)][rng.randi() % 3]
	av.set_colors({"shirt_color": jacket, "shirt_pattern": 9, "shirt_color2": tie,
		"long_sleeves": true, "long_pants": true, "shorts_color": jacket,
		"socks_color": Color(0.05, 0.05, 0.06), "boots_color": Color(0.03, 0.03, 0.03)})


func _build_winner() -> void:
	winner = PlayerAvatar.new()
	add_child(winner)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("winner:" + String(_d.get("winner_name", "")))
	var prof: PlayerProfile = _d.get("profile", null)
	_suit(winner, rng, Color(0.85, 0.65, 0.2), prof)
	winner.position = STAGE + Vector3(-0.6, 0.0, 0.3)
	winner.anim.play("idle")


func _make_confetti() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 160
	p.lifetime = 4.0
	p.explosiveness = 0.85
	p.position = STAGE + Vector3(0, 5.5, 0.5)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(4.0, 0.2, 2.0)
	p.direction = Vector3(0, -1, 0)
	p.spread = 35.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -1.6, 0)
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.04)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1.0, 0.82, 0.25), Color(1, 1, 1), Color(0.9, 0.2, 0.3), Color(0.3, 0.6, 1.0)])
	g.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	p.color_initial_ramp = g
	return p


# ---------------------------------------------------------------- secuencia

func _process(delta: float) -> void:
	_t += delta
	if not _revealed and _t >= REVEAL_AT:
		_reveal()
	# Focos: barren la sala antes; luego se clavan en el ganador
	var head := winner.global_position + Vector3(0, 1.2, 0)
	for i in _spots.size():
		var s := _spots[i]
		var target: Vector3
		if _revealed:
			target = head
		else:
			var a := _t * (1.3 + i * 0.4) + i * 2.1
			target = Vector3(sin(a) * 6.0, 0.0, cos(a * 0.7) * 4.0 + 1.0)
		var cur := s.global_position - s.global_basis.z
		var look := cur.lerp(target, 1.0) if _revealed and _t - REVEAL_AT > 0.6 else target
		s.look_at(look, Vector3.UP)
	if _revealed:
		if not winner.anim.is_playing():
			winner.anim.play("victory_idle", 0.2)
		if not _lifted and _t - REVEAL_AT > 1.1:
			_lifted = true
			winner.pose_arms("lift", 0.45) # del pecho a lo alto, a dos manos
		for av in _audience:
			if not av.anim.is_playing():
				av.anim.play(["sit_clap", "sit_react"].pick_random(), 0.2)
	_update_camera()


func _reveal() -> void:
	_revealed = true
	_screen_lbl.text = String(_d.get("winner_name", "")).to_upper()
	_screen_lbl.modulate = Color(1.0, 0.95, 0.75)
	winner.anim.play("victory_idle", 0.3)
	_trophy = TrophyBuilder.build(String(_d.get("award", "ballon_dor")))
	_attach_to_hand(winner, _trophy)
	for av in _audience:
		av.anim.play("sit_clap", 0.2)
	_confetti.restart()
	_confetti.emitting = true
	for s in _spots:
		s.light_energy = 14.0


## El premio entre las dos manos (ArmPose): primero lo enseña delante del pecho y luego
## lo levanta. Se recoloca cada vez que el esqueleto se actualiza.
func _attach_to_hand(av: PlayerAvatar, obj: Node3D) -> void:
	add_child(obj)
	obj.scale = Vector3.ONE * 1.8
	var lo := INF
	var hi := -INF
	for c in obj.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var a := mi.global_transform * mi.get_aabb()
		lo = minf(lo, a.position.y)
		hi = maxf(hi, a.end.y)
	_trophy_h = hi - lo if hi > lo else 0.5
	av.pose_arms("hold", 0.3)
	av.skeleton.skeleton_updated.connect(_place_trophy.bind(av, obj))


func _place_trophy(av: PlayerAvatar, obj: Node3D) -> void:
	obj.global_position = av.hands_position() - Vector3.UP * _trophy_h * 0.3
	obj.global_rotation = Vector3(0.0, av.global_rotation.y + sin(_t * 0.8) * 0.15, 0.0)


## Cámara: entra por la alfombra hacia el escenario; tras el anuncio, plano medio que gira.
func _update_camera() -> void:
	if camera == null:
		return
	if _t < REVEAL_AT:
		var k := smoothstep(0.0, REVEAL_AT, _t)
		# look_at_from_position: vale también antes de que la vista entre en el árbol
		camera.look_at_from_position(Vector3(lerpf(-1.5, 0.6, k), lerpf(2.6, 2.0, k), lerpf(9.0, 3.0, k)),
				Vector3(0, 2.2, -5.0), Vector3.UP)
	else:
		var r := _t - REVEAL_AT
		var c := winner.global_position + Vector3(0, 1.35, 0)
		var ang := -0.35 + r * 0.12
		var dist := lerpf(6.0, 4.2, smoothstep(0.0, 2.5, r))
		camera.look_at_from_position(c + Vector3(sin(ang) * dist, 0.5, cos(ang) * dist), c, Vector3.UP)
