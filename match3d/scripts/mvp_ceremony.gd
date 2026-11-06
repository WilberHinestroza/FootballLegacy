class_name MvpCeremony
extends Node3D
## Plano individual del MVP: aparece en el césped, alza el trofeo 3D y la
## cámara lo acompaña. No hay diálogo ni botones; termina sola.

signal finished()

const PLAYER_SPOT := Vector3(0.0, 0.34, -4.5)
const GOLD := Color(1.0, 0.82, 0.28)

var _match: SoccerMatch
var _winner: SoccerPlayer
var _award: Node3D
var _camera: Camera3D
var _title: Label3D
var _spotlight: SpotLight3D
var _elapsed := 0.0
var _lifted := false
var _sent := false
var _award_height := 0.5


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
	_winner.reset_to(PLAYER_SPOT, Vector3.FORWARD) # de frente a la cámara del homenaje
	_winner.global_position.y = PLAYER_SPOT.y
	_winner.rotation.y = PI
	if _winner._anim != null and _winner._anim.has_animation("victory_idle"):
		_winner._anim.play("victory_idle", 0.25)

	# Podio bajo y sobrio: el protagonismo queda en el jugador y el premio.
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(3.2, 0.35, 2.4)),
		PLAYER_SPOT + Vector3(0.0, -0.18, 0.0), team_color.darkened(0.25))
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(3.0, 0.05, 2.2)),
		PLAYER_SPOT + Vector3(0.0, 0.02, 0.0), team_color)

	_title = Label3D.new()
	_title.text = "MVP DEL PARTIDO\n" + player_name.to_upper()
	_title.font_size = 56
	_title.pixel_size = 0.003
	_title.modulate = GOLD
	_title.outline_modulate = Color(0.04, 0.04, 0.05)
	_title.outline_size = 10
	_title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_title.position = PLAYER_SPOT + Vector3(0.0, 3.0, -0.2)
	add_child(_title)

	_spotlight = SpotLight3D.new()
	_spotlight.light_color = Color(1.0, 0.88, 0.58)
	_spotlight.light_energy = 2.2
	_spotlight.spot_range = 15.0
	_spotlight.spot_angle = 38.0
	_spotlight.position = PLAYER_SPOT + Vector3(0.0, 8.0, 2.0)
	add_child(_spotlight)
	_spotlight.look_at(PLAYER_SPOT + Vector3(0.0, 1.0, 0.0), Vector3.UP)

	_award = TrophyBuilder.build("mvp", GOLD)
	add_child(_award)
	_award.scale = Vector3.ONE * 1.55
	_award_height = _height(_award)
	if _winner._avatar != null:
		_winner._avatar.pose_arms("hold", 0.25)
		_winner._avatar.skeleton.skeleton_updated.connect(_place_award)
	_place_award()

	_camera = Camera3D.new()
	_camera.fov = 48.0
	add_child(_camera)
	_camera.make_current()
	_match._hud.visible = false
	for item in _match._hud.find_children("*", "CanvasItem", true, false):
		(item as CanvasItem).visible = false
	FieldBuilder.set_scoreboard(_match, "")
	FieldBuilder.flares(_match, -1.0, GOLD, 5.0)
	SoundFx.play("cheer", -2.0)
	Haptics.hit("big")


func _process(delta: float) -> void:
	if _sent or _winner == null or not is_instance_valid(_winner):
		return
	_elapsed += delta
	var approach := smoothstep(0.0, 2.0, _elapsed)
	var angle := -0.28 + _elapsed * 0.12
	var distance := lerpf(10.0, 6.0, approach)
	var focus := _winner.global_position + Vector3(0.0, 1.45, 0.0)
	_camera.global_position = focus + Vector3(sin(angle) * distance, lerpf(2.8, 2.2, approach), -cos(angle) * distance)
	_camera.look_at(focus, Vector3.UP)
	if not _lifted and _elapsed >= 1.15:
		_lifted = true
		if _winner._avatar != null:
			_winner._avatar.pose_arms("lift", 0.4)
	if _winner._anim != null and not _winner._anim.is_playing() and _winner._anim.has_animation("victory_idle"):
		_winner._anim.play("victory_idle", 0.2)
	_place_award()
	if _elapsed >= 5.4:
		_sent = true
		finished.emit()


func _place_award() -> void:
	if _winner == null or _award == null or not is_instance_valid(_award):
		return
	if _winner._avatar == null:
		_award.global_position = _winner.global_position + Vector3(0.0, 2.15, 0.18)
		_award.global_rotation = Vector3.ZERO
		return
	_award.global_position = _winner._avatar.hands_position() - Vector3.UP * _award_height * 0.3
	_award.global_rotation = Vector3(-0.08 if _lifted else 0.0, sin(_elapsed * 0.7) * 0.08, 0.0)


func _height(node: Node3D) -> float:
	var lo := INF
	var hi := -INF
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var bounds := mesh.global_transform * mesh.get_aabb()
		lo = minf(lo, bounds.position.y)
		hi = maxf(hi, bounds.end.y)
	return maxf(hi - lo, 0.1) if hi > lo else 0.5
