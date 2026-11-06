class_name TrophyCeremony
extends Node3D
## Campeones: al ganar una final, el equipo se junta en el centro del campo sobre un
## podio, tú levantas la copa (dorada, hecha con mallas) y hay confeti y bengalas con
## los colores del club. Cámara propia que gira alrededor. SoccerMatch la crea en el pitido final.

const LIFT_ANIM := "victory_idle" # piernas y tronco; los brazos los pone ArmPose (copa a dos manos)
const PODIUM := Vector3(0.0, 0.0, -6.0)

var camera: Camera3D
var _m: SoccerMatch
var _t := 0.0
var _lifter: SoccerPlayer
var _cup: Node3D
var _boom_t := 0.0
var _cup_h := 0.5   # alto de la copa (mundo), para cogerla por la mitad de abajo
var _lifted := false


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

	# El equipo: tú delante en el centro con la copa, el resto detrás celebrando
	_lifter = m.star if m.star.visible else m.teams[0][1]
	var others: Array = []
	for p: SoccerPlayer in m.teams[0]:
		if p != _lifter and p.visible:
			others.append(p)
	_stand(_lifter, PODIUM + Vector3(0.0, 0.3, 0.2), LIFT_ANIM)
	for i in others.size():
		var row := 0 if i < 5 else 1
		var k := i if row == 0 else i - 5
		var n := 5 if row == 0 else others.size() - 5
		var x := (k - (n - 1) * 0.5) * 1.35 + (0.0 if row == 0 else 0.6)
		var pos := PODIUM + Vector3(x, 0.3 if row == 0 else 0.6, -0.4 - row * 0.9)
		_stand(others[i], pos, ["fist_pump", "fist_pump_2", "clap", "dance_4", "dance_7", "victory_idle"].pick_random())
	# Los rivales, cabizbajos, se van hacia el túnel
	for p: SoccerPlayer in m.teams[1]:
		p.play_action("idle", 1.0, 99.0)

	if m.star.star_label:
		m.star.star_label.visible = false # que no tape el cartel
	# El trofeo de ESA competición (orejona, Mundial, copa...), con la franja del club
	var tid := String(SoccerMatch.config.get("final_trophy_id", ""))
	_cup = TrophyBuilder.build(tid if tid != "" else trophy_name, c1)
	_attach_to_hand(_lifter, _cup)

	camera = Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.make_current()
	_boom()


## Coloca a un jugador mirando a la cámara (hacia +Z) y le pone la celebración.
func _stand(p: SoccerPlayer, pos: Vector3, anim_name: String) -> void:
	p.reset_to(Vector3(pos.x, 0.0, pos.z), Vector3(0.0, 0.0, 1.0))
	p.velocity = Vector3.ZERO
	p.move_input = Vector3.ZERO
	p.global_position.y = pos.y
	p.set_physics_process(false) # quieto sobre el podio (sin gravedad ni IA)
	p.rotation.y = 0.0
	if p._anim and p._anim.has_animation(anim_name):
		p._anim.play(anim_name, 0.3)
		p._anim.speed_scale = 1.0


## La copa entre las dos manos: la presenta delante del pecho y a los 1,2 s la levanta
## (ArmPose "hold" -> "lift"). Se recoloca cada vez que el esqueleto se actualiza.
func _attach_to_hand(p: SoccerPlayer, cup: Node3D) -> void:
	add_child(cup)
	cup.scale = Vector3.ONE * 1.6
	_cup_h = _height(cup)
	var av: PlayerAvatar = p._avatar
	if av == null:
		cup.global_position = p.global_position + Vector3(0.0, 2.2, 0.0)
		return
	av.pose_arms("hold", 0.25)
	av.skeleton.skeleton_updated.connect(_place_cup)


func _place_cup() -> void:
	var av: PlayerAvatar = _lifter._avatar
	if av == null or _cup == null:
		return
	# Las manos agarran la copa por debajo de la mitad; sube un pelín inclinada hacia el público
	_cup.global_position = av.hands_position() - Vector3.UP * _cup_h * 0.32
	_cup.global_rotation = Vector3(-0.08 if _lifted else 0.0, sin(_t * 0.7) * 0.12, 0.0)


func _height(n: Node3D) -> float:
	var lo := INF
	var hi := -INF
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var a := mi.global_transform * mi.get_aabb()
		lo = minf(lo, a.position.y)
		hi = maxf(hi, a.end.y)
	return maxf(hi - lo, 0.1) if hi > lo else 0.5


func _boom() -> void:
	for a: Area3D in _m._goal_areas:
		FieldBuilder.celebrate(_m, a)
	FieldBuilder.flares(_m, -1.0, FieldBuilder.home_color, 7.0)
	FieldBuilder.flares(_m, 1.0, FieldBuilder.home_color2, 7.0)
	SoundFx.play("cheer", 0.0)
	_boom_t = 6.5


func _process(delta: float) -> void:
	_t += delta
	_boom_t -= delta
	if _boom_t <= 0.0:
		_boom()
	# Cámara: empieza abajo y lejos, sube y gira despacio alrededor del podio
	var center := PODIUM + Vector3(0.0, 1.6, -0.6)
	var ang := -0.5 + _t * 0.09
	var dist := lerpf(13.0, 7.5, smoothstep(0.0, 4.0, _t))
	var h := lerpf(1.0, 2.4, smoothstep(0.0, 4.0, _t))
	camera.global_position = center + Vector3(sin(ang) * dist, h, cos(ang) * dist)
	camera.look_at(center + Vector3(0.0, 0.3, 0.0), Vector3.UP)
	# El que levanta la copa: la presenta y la sube a dos manos
	if not _lifted and _t > 1.2 and _lifter._avatar:
		_lifted = true
		_lifter._avatar.pose_arms("lift", 0.4)
	if _lifter and _lifter._anim and not _lifter._anim.is_playing():
		_lifter._anim.play(LIFT_ANIM, 0.2)
	# Los demás no paran: cuando acaba una celebración empiezan otra
	for p: SoccerPlayer in _m.teams[0]:
		if p != _lifter and p.visible and p._anim and not p._anim.is_playing():
			p._anim.play(["fist_pump", "fist_pump_2", "clap", "dance_4", "dance_7"].pick_random(), 0.3)
