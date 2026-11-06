class_name TrophyCeremony
extends Node3D
## Campeones: al ganar una final, entrega de la copa en el centro del campo.
##   1. Los compañeros llegan trotando al podio y se suben celebrando; tú caminas
##      hasta el centro, donde espera un directivo con la copa.
##   2. Te la entrega; te giras hacia la grada con ella delante del pecho mientras el
##      equipo se agacha detrás (la espera de siempre).
##   3. La levantas: todos saltan a la vez, confeti, bengalas y fuegos con los colores
##      del club; la cámara se abre y gira alrededor.
## Los rivales, cabizbajos, se van caminando al túnel (algunos se quedan un rato de
## rodillas). SoccerMatch la crea en el pitido final y la llama en cada paso de física.

const LIFT_ANIM := "idle" # piernas y tronco; los brazos los pone ArmPose (copa a dos manos)
const PODIUM := Vector3(0.0, 0.0, -6.0)
const CELEBRATE := ["fist_pump", "fist_pump_2", "clap", "dance_4", "dance_7", "victory_idle"]
## Segundos de toda la ceremonia (SoccerMatch espera esto para pasar a la vuelta al túnel).
const DURATION := 10.0

var camera: Camera3D
var _m: SoccerMatch
var _t := 0.0
var _lifter: SoccerPlayer
var _cup: Node3D
var _cup_h := 0.5   # alto de la copa (mundo), para cogerla por la mitad de abajo
var _lifted := false
var _presenter: PlayerAvatar
var _holder: PlayerAvatar
var _phase := "gather"  # gather -> hand -> turn -> lift
var _phase_t := 0.0
var _boom_t := 0.0
var _mates: Array = []  # [{p, path, spot, delay, speed, arrived, jump}]
var _lifter_path: Array[Vector3] = []
var _rivals: Array = [] # [{p, delay, via}]
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO


func start(m: SoccerMatch, trophy_name: String) -> void:
	_m = m
	var c1: Color = FieldBuilder.home_color
	var c2: Color = FieldBuilder.home_color2
	# Podio de dos alturas con el nombre del título detrás
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(9.0, 0.3, 3.2)), PODIUM + Vector3(0.0, 0.15, -0.6), c1.darkened(0.2))
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(9.0, 0.06, 0.08)), PODIUM + Vector3(0.0, 0.31, 1.0), c2)
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(9.0, 0.3, 1.6)), PODIUM + Vector3(0.0, 0.45, -1.4), c1.darkened(0.35))
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(10.0, 3.2, 0.2)), PODIUM + Vector3(0.0, 1.6, -2.6), c1.darkened(0.5))
	var title := Label3D.new()
	title.text = "CAMPEONES\n" + trophy_name.to_upper()
	title.font_size = 150
	title.pixel_size = 0.006
	title.modulate = Color(1.0, 0.85, 0.35)
	title.outline_modulate = c1.darkened(0.6)
	title.outline_size = 18
	title.position = PODIUM + Vector3(0.0, 2.1, -2.45)
	add_child(title)

	# Tú caminas al centro del podio; el resto llega trotando a su sitio detrás
	_lifter = m.star if m.star.visible else m.teams[0][1]
	_prepare(_lifter, PODIUM + Vector3(-3.4, 0.0, 3.8))
	# Al borde del podio, por delante del equipo: que se le vea levantar la copa
	_lifter_path = [PODIUM + Vector3(-0.7, 0.0, 2.2), PODIUM + Vector3(0.0, 0.3, 0.8)]
	var others: Array = []
	for p: SoccerPlayer in m.teams[0]:
		if p != _lifter and p.visible:
			others.append(p)
	for i in others.size():
		var row := 0 if i < 5 else 1
		var k := i if row == 0 else i - 5
		var n := 5 if row == 0 else others.size() - 5
		var x := (k - (n - 1) * 0.5) * 1.35 + (0.0 if row == 0 else 0.6)
		var spot := PODIUM + Vector3(x, 0.3 if row == 0 else 0.6, -0.6 - row * 0.9)
		# Salen de un abanico delante del podio (venían celebrando por el campo)
		var side := -1.0 if x < 0.0 else 1.0
		var from := PODIUM + Vector3(x * 1.6 + side * randf_range(2.5, 5.0), 0.0, randf_range(5.0, 9.0))
		var p: SoccerPlayer = others[i]
		_prepare(p, from)
		_mates.append({"p": p, "spot": spot, "delay": randf_range(0.0, 0.7), "arrived": false, "jump": randf() * TAU,
			"path": [Vector3(x * 1.05, 0.0, PODIUM.z + 1.9), spot], "speed": randf_range(2.8, 3.4)})

	# Directivo con la copa, en el podio
	_presenter = CeremonyKit.suit_person(self, c1, "copa:" + trophy_name)
	_presenter.position = PODIUM + Vector3(1.35, 0.3, 0.8)
	_presenter.pose_arms("hold", 0.01)
	_holder = _presenter

	# Los rivales se van al túnel; algunos se quedan un rato de rodillas
	for p: SoccerPlayer in m.teams[1]:
		if not p.visible:
			continue
		# Los que quedaron delante del podio (en el plano) se van enseguida, sin arrodillarse
		var in_shot := p.global_position.z > PODIUM.z - 1.0 and absf(p.global_position.x) < 11.0 				and p.global_position.z < PODIUM.z + 14.0
		var kneel := randf() < 0.35 and not in_shot
		if kneel:
			p.play_action("kneel", 1.0, 2.6)
		p.walk_normal = true
		p.sad_gait = true
		p.collision_layer = SoccerMatch.WALK_BODY_LAYER
		p.collision_mask = SoccerMatch.WALK_BODY_LAYER
		_rivals.append({"p": p, "delay": (randf_range(0.0, 0.3) if in_shot else randf_range(0.5, 2.0)) + (2.8 if kneel else 0.0), "via": false})

	# Los árbitros también se retiran al vestuario (no cruzan por delante de la cámara)
	var mouth_z := -SoccerMatch.FIELD_WIDTH * 0.5 - FieldBuilder.SIDE_STANDS
	m.staff.ref_delay = []
	m.staff.ref_via = []
	m.staff.ref_targets = []
	for i in m.staff.refs.size():
		m.staff.ref_via.append(Vector3(FieldBuilder.TUNNEL_X - 0.6 + i * 0.3, 0.0, -SoccerMatch.FIELD_WIDTH * 0.5 + 1.5))
		m.staff.ref_targets.append(Vector3(FieldBuilder.TUNNEL_X - 0.4 + i * 0.4, 0.0, mouth_z - 4.2))
	m.staff.ref_hide_z = mouth_z - 3.4
	if m.star.star_label:
		m.star.star_label.visible = false # que no tape el cartel
	# El trofeo de ESA competición (orejona, Mundial, copa...), con la franja del club
	var tid := String(SoccerMatch.config.get("final_trophy_id", ""))
	_cup = TrophyBuilder.build(tid if tid != "" else trophy_name, c1)
	add_child(_cup)
	_cup.scale = Vector3.ONE * 1.6
	_cup_h = _height(_cup)
	_presenter.skeleton.skeleton_updated.connect(_place_cup)
	if _lifter._avatar:
		_lifter._avatar.skeleton.skeleton_updated.connect(_place_cup)
	_place_cup()

	camera = Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.make_current()
	_cam_look = PODIUM + Vector3(0.0, 1.2, 1.0)
	_cam_pos = PODIUM + Vector3(7.0, 2.2, 13.0)
	FieldBuilder.flares(_m, -1.0, c1, 7.0)
	SoundFx.play("cheer", 0.0)


## Fuera de la física (lo movemos a mano), de pie en `pos`.
func _prepare(p: SoccerPlayer, pos: Vector3) -> void:
	p.reset_to(Vector3(pos.x, 0.0, pos.z), Vector3(0.0, 0.0, 1.0))
	p.velocity = Vector3.ZERO
	p.move_input = Vector3.ZERO
	p.set_physics_process(false)
	p.collision_layer = 0
	p.collision_mask = 0
	p.global_position.y = pos.y


func _play(p: SoccerPlayer, anim_name: String, blend := 0.3) -> void:
	if p._anim and p._anim.has_animation(anim_name) and p._anim.current_animation != anim_name:
		p._anim.play(anim_name, blend)
		p._anim.speed_scale = 1.0


func _set_phase(ph: String) -> void:
	_phase = ph
	_phase_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	_phase_t += delta
	var front := _lifter.global_position + Vector3.BACK
	match _phase:
		"gather":
			if not _lifter_path.is_empty():
				if not CeremonyKit.step_to(_lifter, _lifter._anim, _lifter_path[0], 1.8, delta):
					_lifter_path.pop_front()
			if _lifter_path.is_empty():
				_play(_lifter, "idle")
				_set_phase("hand")
		"hand":
			CeremonyKit.face(_lifter, _presenter.global_position, delta * 5.0)
			CeremonyKit.face(_presenter, _lifter.global_position, delta * 5.0)
			if _holder == _presenter and _phase_t > 0.5 and _lifter._avatar:
				_holder = _lifter._avatar
				_lifter._avatar.pose_arms("hold", 0.45)
				_presenter.pose_arms("", 0.5)
				_presenter.anim.play("clap", 0.3)
				SoundFx.play("cheer", -3.0)
			if _phase_t > 1.0:
				_set_phase("turn")
		"turn":
			# De cara a la grada con la copa; el equipo se agacha detrás, esperando
			CeremonyKit.face(_lifter, front, delta * 4.0)
			for d: Dictionary in _mates:
				if bool(d["arrived"]):
					_play(d["p"], "crouch", 0.25)
			if _phase_t > 1.0:
				_set_phase("lift")
				_lift()
		"lift":
			CeremonyKit.face(_lifter, front, delta * 4.0)
			_boom_t -= delta
			if _boom_t <= 0.0:
				_boom()
			if _lifter._anim and not _lifter._anim.is_playing():
				_lifter._anim.play(LIFT_ANIM, 0.2)
	# Directivo: tras dar la copa, aplaude y se aparta hacia un lado del podio
	if _holder != _presenter and _phase != "hand":
		var off := PODIUM + Vector3(5.6, 0.0, 1.6) # se baja del podio, a un lado
		if not CeremonyKit.step_to(_presenter, _presenter.anim, off, 1.3, delta):
			CeremonyKit.face(_presenter, _lifter.global_position, delta * 3.0)
			if _presenter.anim.current_animation != "clap":
				_presenter.anim.play("clap", 0.3)
	_update_mates(delta)
	_update_camera(delta)


## Compañeros: trotan hasta su sitio, celebran; agachados en la espera; y al levantar
## la copa saltan todos a la vez (botes) y siguen celebrando cada uno a su ritmo.
func _update_mates(delta: float) -> void:
	for d: Dictionary in _mates:
		var p: SoccerPlayer = d["p"]
		if float(d["delay"]) > 0.0:
			d["delay"] = float(d["delay"]) - delta
			continue
		var path: Array = d["path"]
		if not path.is_empty():
			if not CeremonyKit.step_to(p, p._anim, path[0], float(d["speed"]), delta):
				path.pop_front()
				if path.is_empty():
					d["arrived"] = true
					_play(p, CELEBRATE.pick_random())
			continue
		var spot: Vector3 = d["spot"]
		CeremonyKit.face(p, p.global_position + Vector3.BACK, delta * 4.0)
		if _phase == "lift":
			# Saltos de verdad (se agachan, impulsan y caen): dos seguidos al levantar la
			# copa, casi a la vez; luego alguno suelto entre los festejos.
			p.global_position.y = spot.y
			var k := _phase_t - float(d["jump"]) * 0.03
			var a: AnimationPlayer = p._anim
			if a == null:
				continue
			var jumping := a.current_animation == "jump_cheer" and a.is_playing()
			if k > 0.0 and int(d.get("jumps", 0)) < 2 and not jumping:
				a.play("jump_cheer", 0.12)
				a.speed_scale = randf_range(1.05, 1.2)
				d["jumps"] = int(d.get("jumps", 0)) + 1
			elif not jumping and (not a.is_playing() or a.current_animation == "crouch"):
				a.play("jump_cheer" if randf() < 0.3 else CELEBRATE.pick_random(), 0.25)
				a.speed_scale = 1.0
		elif _phase != "turn" and p._anim and not p._anim.is_playing():
			p._anim.play(CELEBRATE.pick_random(), 0.3)


## Rivales: caminan despacio a la manga y entran al vestuario (con física, como en la
## vuelta al túnel). SoccerMatch lo llama en su paso de física, tras congelar al resto.
func physics_step(delta: float) -> void:
	var mouth_z := -SoccerMatch.FIELD_WIDTH * 0.5 - FieldBuilder.SIDE_STANDS
	for d: Dictionary in _rivals:
		var p: SoccerPlayer = d["p"]
		if not p.visible:
			continue
		d["delay"] = float(d["delay"]) - delta
		if float(d["delay"]) > 0.0:
			continue
		var target := Vector3(FieldBuilder.TUNNEL_X + 1.05, 0.0, mouth_z - 6.0)
		# Los que están del lado de la cámara rodean el podio por fuera: si no, cruzan
		# por delante de la foto de campeones.
		if not bool(d.get("around", false)):
			if p.global_position.z < PODIUM.z - 2.0 or absf(p.global_position.x) > 11.0:
				d["around"] = true
			else:
				var sx := signf(p.global_position.x) if absf(p.global_position.x) > 0.5 else 1.0
				target = Vector3(sx * 13.0, 0.0, p.global_position.z)
		elif not bool(d["via"]):
			var via := Vector3(FieldBuilder.TUNNEL_X + 0.9, 0.0, -SoccerMatch.FIELD_WIDTH * 0.5 + 1.2)
			if SoccerMatch.flat_dist(p.global_position, via) < 2.2:
				d["via"] = true
			else:
				target = via
		if mouth_z - p.global_position.z >= FieldBuilder.TUNNEL_ROWS * FieldBuilder.ROW_DEPTH - 0.35:
			_m._vanish(p)
			continue
		AiBrain.move_to(p, target, 0.3, false)
		p.move_input *= SoccerMatch.OUTRO_PACE * _m._walk_pace(p) / SoccerMatch.WALK_PACE
		_m._keep_spacing(p)


func _lift() -> void:
	_lifted = true
	if _lifter._avatar:
		_lifter._avatar.pose_arms("lift", 0.35)
	if _lifter._anim:
		_lifter._anim.play(LIFT_ANIM, 0.2)
	CeremonyKit.confetti(self, PODIUM + Vector3(0.0, 2.5, -0.4), Vector3(4.5, 0.3, 1.6),
		[Color(1.0, 0.85, 0.3), FieldBuilder.home_color, FieldBuilder.home_color2, Color.WHITE])
	Haptics.hit("big")
	_boom()


func _boom() -> void:
	for a: Area3D in _m._goal_areas:
		FieldBuilder.celebrate(_m, a)
	FieldBuilder.flares(_m, -1.0, FieldBuilder.home_color, 7.0)
	FieldBuilder.flares(_m, 1.0, FieldBuilder.home_color2, 7.0)
	SoundFx.play("cheer", 0.0)
	_boom_t = 6.5


## Cámara: a ras de césped siguiendo tu llegada; plano medio de la entrega; contrapicado
## cerca en la espera; al levantar la copa se abre, sube y gira alrededor del podio.
func _update_camera(delta: float) -> void:
	if not is_inside_tree():
		return
	var lp := _lifter.global_position
	var look := lp + Vector3(0.0, 1.3, 0.0)
	var pos := look + Vector3(4.5, 0.6, 7.5)
	match _phase:
		"hand":
			look = (lp + _presenter.global_position) * 0.5 + Vector3(0.0, 1.4, 0.0)
			pos = look + Vector3(1.4, 0.4, 5.2)
		"turn":
			look = lp + Vector3(0.0, 1.5, -0.6)
			pos = lp + Vector3(0.8, 0.9, 4.6)
		"lift":
			var e := smoothstep(0.0, 2.0, _phase_t)
			look = PODIUM + Vector3(0.0, lerpf(1.8, 1.6, e), -0.5)
			var ang := 0.15 + _phase_t * 0.09 * e
			var dist := lerpf(5.0, 9.5, e)
			pos = look + Vector3(sin(ang) * dist, lerpf(0.2, 1.6, e), cos(ang) * dist)
	var k := minf(1.0, delta * 2.2)
	_cam_pos = _cam_pos.lerp(pos, k)
	_cam_look = _cam_look.lerp(look, k)
	camera.global_position = _cam_pos
	camera.look_at(_cam_look, Vector3.UP)


func _place_cup() -> void:
	if not is_inside_tree():
		return # la escena ya se fue (salida del partido): el esqueleto aún avisa
	if _holder == null or _cup == null:
		return
	# Las manos agarran la copa por debajo de la mitad; sube un pelín inclinada hacia el público
	_cup.global_position = _holder.hands_position() - Vector3.UP * _cup_h * (0.1 if _lifted else 0.32)
	_cup.global_rotation = Vector3(-0.08 if _lifted else 0.0, _holder.global_rotation.y + sin(_t * 0.7) * 0.12, 0.0)


func _height(n: Node3D) -> float:
	var lo := INF
	var hi := -INF
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var a := mi.global_transform * mi.get_aabb()
		lo = minf(lo, a.position.y)
		hi = maxf(hi, a.end.y)
	return maxf(hi - lo, 0.1) if hi > lo else 0.5
