class_name MvpCeremony
extends Node3D
## MVP del partido, como una entrega de verdad: el ganador camina hasta el podio y
## sube el escalón; un presentador de traje le da el trofeo; lo enseña a los
## fotógrafos (flashes) y lo levanta con confeti y bengalas. La cámara acompaña cada
## momento y al final gira alrededor. Sin botones; termina sola.

signal finished()

const PLAYER_SPOT := Vector3(0.0, 0.34, -4.5)
const GOLD := Color(1.0, 0.82, 0.28)
const WALK_SPEED := 1.5
const LIFT_HOLD := 4.2 # segundos con el trofeo en alto antes de terminar

var _match: SoccerMatch
var _winner: SoccerPlayer
var _award: Node3D
var _camera: Camera3D
var _title: Label3D
var _spotlight: SpotLight3D
var _presenter: PlayerAvatar
var _snappers: Array[PlayerAvatar] = []
var _holder: PlayerAvatar          # quién tiene el trofeo en las manos
var _path: Array[Vector3] = []
var _phase := "walk"               # walk -> meet -> show -> lift
var _phase_t := 0.0
var _elapsed := 0.0
var _lifted := false
var _sent := false
var _award_height := 0.5
var _flash_t := 0.0
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO


func start(m: SoccerMatch, winner: SoccerPlayer, player_name: String, team_color: Color) -> void:
	_match = m
	_winner = winner
	_winner.visible = true
	_winner.set_physics_process(false)
	_winner.move_input = Vector3.ZERO
	_winner.sprinting = false
	_winner.velocity = Vector3.ZERO
	_winner.collision_layer = 0
	_winner.collision_mask = 0
	if _winner.star_label != null:
		_winner.star_label.visible = false # el rótulo "TÚ" no forma parte del premio
	# Llega caminando desde un lado, por delante del podio
	var start_pos := PLAYER_SPOT + Vector3(-3.6, -PLAYER_SPOT.y, -2.6)
	_winner.reset_to(start_pos, Vector3.FORWARD)
	_winner.global_position.y = 0.0
	_path = [PLAYER_SPOT + Vector3(-0.8, -PLAYER_SPOT.y, -2.0), PLAYER_SPOT + Vector3(-0.15, 0.0, -0.1)]
	CeremonyKit.face(_winner, _path[0], 1.0)

	# Podio bajo y sobrio, con escalón delante: el protagonismo es del jugador y el premio
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(3.2, 0.35, 2.4)),
		PLAYER_SPOT + Vector3(0.0, -0.18, 0.0), team_color.darkened(0.25))
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(3.0, 0.05, 2.2)),
		PLAYER_SPOT + Vector3(0.0, 0.02, 0.0), team_color)
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(1.6, 0.17, 0.5)),
		PLAYER_SPOT + Vector3(0.0, -0.26, -1.45), team_color.darkened(0.4))

	_title = Label3D.new()
	_title.text = "MVP DEL PARTIDO\n" + player_name.to_upper()
	_title.font_size = 56
	_title.pixel_size = 0.003
	_title.modulate = Color(GOLD, 0.0) # aparece al levantar el trofeo
	_title.outline_modulate = Color(0.04, 0.04, 0.05, 0.0)
	_title.outline_size = 10
	_title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_title.position = PLAYER_SPOT + Vector3(0.0, 3.0, -0.2)
	add_child(_title)

	_spotlight = SpotLight3D.new()
	_spotlight.light_color = Color(1.0, 0.88, 0.58)
	_spotlight.light_energy = 2.2
	_spotlight.spot_range = 15.0
	_spotlight.spot_angle = 38.0
	_spotlight.position = PLAYER_SPOT + Vector3(0.0, 8.0, -2.0)
	add_child(_spotlight)
	_spotlight.look_at(PLAYER_SPOT + Vector3(0.0, 1.0, 0.0), Vector3.UP)

	# Presentador en el podio con el trofeo delante del pecho, esperando
	_presenter = CeremonyKit.suit_person(self, GOLD, "mvp:" + player_name)
	_presenter.position = PLAYER_SPOT + Vector3(1.0, 0.0, 0.0)
	_presenter.rotation.y = PI # de cara a la cámara (-Z)
	_presenter.pose_arms("hold", 0.01)
	_holder = _presenter

	# Fotógrafos de rodillas delante del podio
	# A los lados, por delante: el centro queda libre para la cámara
	for o: Vector3 in [Vector3(-2.9, 0.0, -2.9), Vector3(2.6, 0.0, -3.3), Vector3(3.6, 0.0, -2.2)]:
		_snappers.append(CeremonyKit.photographer(self, PLAYER_SPOT + o - Vector3(0.0, PLAYER_SPOT.y, 0.0),
			PLAYER_SPOT, Color(0.95, 0.55, 0.12)))

	_award = TrophyBuilder.build("mvp", GOLD)
	add_child(_award)
	_award.scale = Vector3.ONE * 1.55
	_award_height = _height(_award)
	_presenter.skeleton.skeleton_updated.connect(_place_award)
	if _winner._avatar != null:
		_winner._avatar.skeleton.skeleton_updated.connect(_place_award)
	_place_award()

	_camera = Camera3D.new()
	_camera.fov = 46.0
	add_child(_camera)
	_camera.make_current()
	_cam_look = _winner.global_position + Vector3(0.0, 1.3, 0.0)
	_cam_pos = _cam_look + Vector3(3.2, 1.2, -6.0)
	# Solo el homenaje en el césped: ni balón ni árbitros
	if _match.ball:
		_match.ball.visible = false
	for r: Node3D in _match.staff.refs:
		r.visible = false
	_match._hud.visible = false
	for item in _match._hud.find_children("*", "CanvasItem", true, false):
		(item as CanvasItem).visible = false
	FieldBuilder.set_scoreboard(_match, "")
	SoundFx.play("cheer", -6.0)


func _process(delta: float) -> void:
	if _sent or _winner == null or not is_instance_valid(_winner):
		return
	_elapsed += delta
	_phase_t += delta
	var wav: PlayerAvatar = _winner._avatar
	match _phase:
		"walk":
			# Hasta el escalón y arriba del podio, a paso tranquilo
			if not _path.is_empty():
				if not CeremonyKit.step_to(_winner, _winner._anim, _path[0], WALK_SPEED, delta):
					_path.pop_front()
			if _path.is_empty():
				_set_phase("meet")
				_play(_winner._anim, "idle")
		"meet":
			# Se miran; el presentador le da el trofeo
			CeremonyKit.face(_winner, _presenter.global_position, delta * 5.0)
			CeremonyKit.face(_presenter, _winner.global_position, delta * 5.0)
			if _holder == _presenter and _phase_t > 0.7:
				_holder = wav if wav != null else _presenter
				if wav != null:
					wav.pose_arms("hold", 0.45)
				_presenter.pose_arms("", 0.5)
				_play(_presenter.anim, "clap")
				SoundFx.play("cheer", -4.0)
			if _phase_t > 1.4:
				_set_phase("show")
		"show":
			# Se gira hacia los fotógrafos con el trofeo delante del pecho
			CeremonyKit.face(_winner, _winner.global_position + Vector3.FORWARD, delta * 4.0)
			CeremonyKit.face(_presenter, _presenter.global_position + Vector3.FORWARD + Vector3.LEFT * 0.4, delta * 3.0)
			_flashes(delta, 0.12, 0.35)
			if _phase_t > 0.9:
				_set_phase("lift")
				_lift()
		"lift":
			CeremonyKit.face(_winner, _winner.global_position + Vector3.FORWARD, delta * 4.0)
			_flashes(delta, 0.25, 0.7)
			var a := clampf(_phase_t / 0.6, 0.0, 1.0)
			_title.modulate.a = a
			_title.outline_modulate.a = a
			if _winner._anim != null and not _winner._anim.is_playing():
				_play(_winner._anim, "idle")
			if _phase_t >= LIFT_HOLD:
				_sent = true
				finished.emit()
	if _presenter.anim.current_animation != "clap" and not _presenter.anim.is_playing():
		_play(_presenter.anim, "idle")
	_update_camera(delta)
	_place_award()


func _set_phase(p: String) -> void:
	_phase = p
	_phase_t = 0.0


func _lift() -> void:
	_lifted = true
	if _winner._avatar != null:
		_winner._avatar.pose_arms("lift", 0.4)
	_play(_winner._anim, "idle")
	CeremonyKit.confetti(self, PLAYER_SPOT + Vector3(0.0, 1.2, 0.0), Vector3(1.6, 0.2, 1.2),
		[GOLD, Color.WHITE, Color(1.0, 0.95, 0.7)])
	FieldBuilder.flares(_match, -1.0, GOLD, 5.0)
	SoundFx.play("cheer", -1.0)
	Haptics.hit("big")


func _flashes(delta: float, lo: float, hi: float) -> void:
	_flash_t -= delta
	if _flash_t <= 0.0 and not _snappers.is_empty():
		_flash_t = randf_range(lo, hi)
		CeremonyKit.flash(_snappers.pick_random())


func _play(anim: AnimationPlayer, n: String) -> void:
	if anim != null and anim.has_animation(n) and anim.current_animation != n:
		anim.play(n, 0.3)
		anim.speed_scale = 1.0


## Cámara: acompaña la caminata desde delante a un lado, se acerca a la entrega, queda
## baja y cerca cuando lo enseña y, al levantarlo, se abre y gira alrededor.
func _update_camera(delta: float) -> void:
	if not is_inside_tree():
		return # la escena ya se fue (salida del partido): el esqueleto aún avisa
	var w := _winner.global_position
	var look := w + Vector3(0.0, 1.3, 0.0)
	var pos := look + Vector3(3.0, 1.0, -5.6)
	match _phase:
		"meet":
			look = (w + _presenter.global_position) * 0.5 + Vector3(0.0, 1.35, 0.0)
			pos = look + Vector3(0.8, 0.5, -4.4)
		"show":
			look = w + Vector3(0.0, 1.45, 0.0)
			pos = look + Vector3(0.5, -0.1, -3.6)
		"lift":
			look = w + Vector3(0.0, 1.7, 0.0)
			var ang := -0.35 + _phase_t * 0.13
			var dist := lerpf(3.8, 6.2, smoothstep(0.0, 1.6, _phase_t))
			pos = look + Vector3(sin(ang) * dist, lerpf(-0.3, 0.5, smoothstep(0.0, 1.6, _phase_t)), -cos(ang) * dist)
	var k := minf(1.0, delta * 2.4)
	_cam_pos = _cam_pos.lerp(pos, k)
	_cam_look = _cam_look.lerp(look, k)
	_camera.global_position = _cam_pos
	_camera.look_at(_cam_look, Vector3.UP)


func _place_award() -> void:
	if not is_inside_tree():
		return # la escena ya se fue (salida del partido): el esqueleto aún avisa
	if _award == null or not is_instance_valid(_award) or _holder == null:
		return
	# Levantado, la copa asoma por encima de la cabeza (las manos quedan en la frente)
	_award.global_position = _holder.hands_position() - Vector3.UP * _award_height * (0.08 if _lifted else 0.3)
	_award.global_rotation = Vector3(-0.08 if _lifted else 0.0, _holder.global_rotation.y - PI + sin(_elapsed * 0.7) * 0.08, 0.0)


func _height(node: Node3D) -> float:
	var lo := INF
	var hi := -INF
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var bounds := mesh.global_transform * mesh.get_aabb()
		lo = minf(lo, bounds.position.y)
		hi = maxf(hi, bounds.end.y)
	return maxf(hi - lo, 0.1) if hi > lo else 0.5
