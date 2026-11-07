class_name FootLock
extends SkeletonModifier3D
## Pies pegados al suelo (IK de dos huesos en las piernas) mientras el jugador está
## parado o casi: cada pie se queda donde pisó y, cuando el cuerpo se aleja o gira
## demasiado, da un paso corto (con un pequeño arco) hasta donde lo pone la animación.
## Así ya no "patina" al frenar, al girar en el sitio ni al moverse despacio en idle.
## Con locomoción (trote/carrera) se apaga: esos clips ya mueven los pies a su ritmo.

const STEP_DIST := 0.2     # m que se separa el pie de su sitio antes de dar el paso
const STEP_YAW := 0.6      # rad de giro del cuerpo respecto al pie antes del paso
const STEP_TIME := 0.22
const STEP_LIFT := 0.09
const SNAP_DIST := 0.7     # más lejos que esto (saque, recolocación): se recoloca sin paso
const FADE_IN := 4.0       # 1/s
const FADE_OUT := 8.0

## Nodo del jugador (+Y arriba, +Z delante).
var body: Node3D
## Lo pide PlayerAvatar.lock_feet; el peso real se acerca poco a poco.
var want := false
var _w := 0.0

var _ready_bones := false
var _up := [-1, -1]
var _leg := [-1, -1]
var _foot := [-1, -1]
var _plant: Array = [null, null]      # Transform3D global del pie apoyado
var _step_from: Array = [null, null]
var _step_t := [-1.0, -1.0]           # >= 0: dando el paso


func _setup() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for s in 2:
		var side: String = ["Left", "Right"][s]
		_up[s] = ItemCatalog.find_bone(sk, side + "UpLeg")
		_leg[s] = ItemCatalog.find_bone(sk, side + "Leg")
		_foot[s] = ItemCatalog.find_bone(sk, side + "Foot")
	_ready_bones = not (_up.has(-1) or _leg.has(-1) or _foot.has(-1))


func _process_modification_with_delta(delta: float) -> void:
	if not _ready_bones:
		_setup()
		if not _ready_bones:
			return
	_w = move_toward(_w, 1.0 if want else 0.0, delta * (FADE_IN if want else FADE_OUT))
	if _w <= 0.0:
		_plant = [null, null]
		_step_t = [-1.0, -1.0]
		return
	var sk := get_skeleton()
	var ref: Node3D = body if is_instance_valid(body) else sk
	var sk_g := sk.global_transform
	var fwd := ref.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	# Dónde pone cada pie la animación (global)
	var anim_feet: Array = []
	for s in 2:
		anim_feet.append(sk_g * sk.get_bone_global_pose(_foot[s]))
	# Pasos: solo un pie a la vez, el que peor está
	var worst := -1
	var worst_err := 0.0
	for s in 2:
		var a: Transform3D = anim_feet[s]
		if _plant[s] == null:
			_plant[s] = a
			continue
		var p: Transform3D = _plant[s]
		var off := a.origin - p.origin
		off.y = 0.0
		var dist := off.length()
		if dist > SNAP_DIST:
			_plant[s] = a
			_step_t[s] = -1.0
			continue
		if _step_t[s] >= 0.0:
			continue
		var yaw := absf(_yaw_between(p.basis, a.basis))
		var err := maxf(dist / STEP_DIST, yaw / STEP_YAW)
		if err > 1.0 and err > worst_err:
			worst = s
			worst_err = err
	if worst >= 0 and _step_t[1 - worst] < 0.0:
		_step_t[worst] = 0.0
		_step_from[worst] = _plant[worst]
	# Las mezclas se hacen en el espacio del esqueleto: los zurdos van espejados
	# (escala negativa) y en global la interpolación giraría el pie al revés
	var inv := sk_g.affine_inverse()
	var lift_dir := (inv.basis * Vector3.UP)
	for s in 2:
		var a := sk.get_bone_global_pose(_foot[s])
		var target: Transform3D = inv * (_plant[s] as Transform3D)
		if _step_t[s] >= 0.0:
			_step_t[s] += delta / STEP_TIME
			var k := smoothstep(0.0, 1.0, minf(_step_t[s], 1.0))
			var f: Transform3D = inv * (_step_from[s] as Transform3D)
			target = f.interpolate_with(a, k)
			target.origin += lift_dir * STEP_LIFT * sin(PI * minf(_step_t[s], 1.0))
			if _step_t[s] >= 1.0:
				_step_t[s] = -1.0
				_plant[s] = anim_feet[s]
				target = a
		_solve(sk, s, a.interpolate_with(target, _w), fwd)


## Giro en vertical entre dos orientaciones de pie (rad, con signo).
static func _yaw_between(a: Basis, b: Basis) -> float:
	var za := a.y # en Mixamo el hueso del pie apunta por su +Y hacia los dedos
	var zb := b.y
	za.y = 0.0
	zb.y = 0.0
	if za.length_squared() < 0.0001 or zb.length_squared() < 0.0001:
		return 0.0
	return za.normalized().signed_angle_to(zb.normalized(), Vector3.UP)


## Cadera -> rodilla -> tobillo hasta `goal` (espacio del esqueleto); la rodilla
## apunta hacia donde ya doblaba en la animación y el pie queda con la orientación de `goal`.
func _solve(sk: Skeleton3D, s: int, goal: Transform3D, fwd_world: Vector3) -> void:
	var up: int = _up[s]
	var leg: int = _leg[s]
	var foot: int = _foot[s]
	var ga := sk.get_bone_global_pose(up)
	var gb := sk.get_bone_global_pose(leg)
	var gc := sk.get_bone_global_pose(foot)
	var a := ga.origin
	var l1 := a.distance_to(gb.origin)
	var l2 := gb.origin.distance_to(gc.origin)
	var to := goal.origin - a
	var d := clampf(to.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var dir := to.normalized()
	var fwd := (sk.global_transform.basis.inverse() * fwd_world).normalized()
	var pole := (gb.origin - a) - dir * (gb.origin - a).dot(dir)
	if pole.length_squared() < 0.0004 * l1 * l1:
		pole = fwd
	var n := (pole - dir * pole.dot(dir))
	if n.length_squared() < 0.000001:
		n = fwd - dir * fwd.dot(dir)
	n = n.normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var knee := a + dir * (l1 * cos_a) + n * (l1 * sqrt(1.0 - cos_a * cos_a))
	var ankle := a + dir * d
	var r1 := Quaternion((gb.origin - a).normalized(), (knee - a).normalized())
	var new_ga := Transform3D(Basis(r1) * ga.basis, a)
	_set_global_rot(sk, up, new_ga)
	var gb2 := new_ga * sk.get_bone_pose(leg)
	var gc2 := gb2 * sk.get_bone_pose(foot)
	var r2 := Quaternion((gc2.origin - gb2.origin).normalized(), (ankle - gb2.origin).normalized())
	var new_gb := Transform3D(Basis(r2) * gb2.basis, gb2.origin)
	_set_global_rot(sk, leg, new_gb)
	# El pie conserva la orientación con la que pisó
	_set_global_rot(sk, foot, Transform3D(goal.basis, ankle))


func _set_global_rot(sk: Skeleton3D, bone: int, global: Transform3D) -> void:
	var parent := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var local := pg.affine_inverse() * global
	sk.set_bone_pose_rotation(bone, local.basis.orthonormalized().get_rotation_quaternion())
