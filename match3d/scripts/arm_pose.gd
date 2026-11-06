class_name ArmPose
extends SkeletonModifier3D
## Brazos animados por código (IK de dos huesos) encima de la animación que esté sonando:
## las piernas y el tronco siguen la animación base y los brazos van a donde toca.
## Modos:
##   "lift"  - copa arriba con las dos manos, con pequeños empujones (campeón)
##   "board" - cartel de cambios en alto con las dos manos (cuarto árbitro)
##   "flag"  - bandera arriba con la derecha, agitándola (juez de línea)
##   "card"  - tarjeta en alto con la derecha, brazo estirado (árbitro)
##   "hold"  - algo delante del pecho con las dos manos (presentar el trofeo)
##   "shake" - la derecha al frente para darse la mano (técnicos en el túnel)
## La entrada y la salida son suaves con `influence` (PlayerAvatar.pose_arms lo gestiona).

var mode := "lift"
var t := 0.0
## Nodo del jugador: sus ejes mandan (+Y arriba, +Z delante). El esqueleto de Mixamo
## tiene los suyos (Z arriba, centímetros), así que todo se calcula aquí y se convierte.
var body: Node3D
var _m := Transform3D.IDENTITY   # espacio del esqueleto -> espacio del jugador

var _ready_bones := false
var _arm := [-1, -1]      # [izq, der] hueso del brazo
var _fore := [-1, -1]
var _hand := [-1, -1]
var _len := 0.5           # brazo + antebrazo (espacio del jugador)
var _head_y := 1.6
var _shoulder_x := 0.18


func _setup() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for s in 2:
		var side: String = ["Left", "Right"][s]
		_arm[s] = ItemCatalog.find_bone(sk, side + "Arm")
		_fore[s] = ItemCatalog.find_bone(sk, side + "ForeArm")
		_hand[s] = ItemCatalog.find_bone(sk, side + "Hand")
	if _arm.has(-1) or _fore.has(-1) or _hand.has(-1):
		return
	_ready_bones = true


## Medidas del cuerpo en el espacio del jugador (cambian con la escala de cada uno).
func _measure(sk: Skeleton3D) -> void:
	var a := _m * sk.get_bone_global_rest(_arm[0]).origin
	var b := _m * sk.get_bone_global_rest(_fore[0]).origin
	var c := _m * sk.get_bone_global_rest(_hand[0]).origin
	_len = a.distance_to(b) + b.distance_to(c)
	_shoulder_x = absf(a.x)
	var head := ItemCatalog.find_bone(sk, "Head")
	_head_y = (_m * sk.get_bone_global_rest(head).origin).y if head >= 0 else a.y + _len * 0.4


func _process_modification_with_delta(delta: float) -> void:
	if not _ready_bones:
		_setup()
		if not _ready_bones:
			return
	t += delta
	var sk := get_skeleton()
	var ref: Node3D = body if is_instance_valid(body) else sk
	_m = ref.global_transform.affine_inverse() * sk.global_transform
	_measure(sk)
	var targets := _targets()
	for s in 2:
		if targets[s] != null:
			_solve(sk, s, targets[s])


## Dónde va cada mano (espacio del esqueleto: +Z delante, +X izquierda del jugador). null = libre.
func _targets() -> Array:
	var L := _len
	var top := _head_y
	var up := smoothstep(0.0, 0.55, t) # sube los brazos al empezar
	match mode:
		"lift":
			# Arriba, juntas, con empujones de alegría cada ~1,1 s
			var pump := absf(sin(t * 2.8)) * 0.12 * L
			var y := lerpf(top - 0.35 * L, top + 0.55 * L + pump, up)
			return [Vector3(0.11 * L, y, 0.12 * L), Vector3(-0.11 * L, y, 0.12 * L)]
		"board":
			var sway := sin(t * 1.6) * 0.03 * L
			var y2 := lerpf(top - 0.3 * L, top + 0.42 * L, up)
			return [Vector3(0.6 * L + sway, y2, 0.2 * L), Vector3(-0.6 * L + sway, y2, 0.2 * L)] # de los bordes
		"flag":
			var wave := sin(t * 7.0) * 0.22 * L
			var y3 := lerpf(top - 0.3 * L, top + 0.5 * L, up)
			return [null, Vector3(-0.42 * L + wave, y3 - absf(wave) * 0.3, 0.15 * L)]
		"card":
			var y4 := lerpf(top - 0.2 * L, top + 0.72 * L, smoothstep(0.0, 0.3, t))
			return [null, Vector3(-_shoulder_x - 0.08 * L, y4, 0.18 * L)]
		"hold":
			return [Vector3(0.14 * L, top - 0.45 * L, 0.42 * L), Vector3(-0.14 * L, top - 0.45 * L, 0.42 * L)]
		"shake":
			# Apretón de manos: la derecha al frente, hacia el centro, sacudiendo un poco
			var pump2 := sin(t * 9.0) * 0.035 * L * smoothstep(0.3, 0.6, t)
			return [null, Vector3(-0.03 * L, top - 1.0 * L + pump2, 0.78 * L)]
	return [null, null]


## IK analítico de dos huesos: gira brazo y antebrazo para que la mano llegue a `target`,
## con el codo hacia fuera y un poco atrás.
func _solve(sk: Skeleton3D, s: int, target_local: Vector3) -> void:
	var inv := _m.affine_inverse()
	var target := inv * target_local
	var arm: int = _arm[s]
	var fore: int = _fore[s]
	var hand: int = _hand[s]
	var ga := sk.get_bone_global_pose(arm)
	var gb := sk.get_bone_global_pose(fore)
	var gc := sk.get_bone_global_pose(hand)
	var a := ga.origin
	var l1 := a.distance_to(gb.origin)
	var l2 := gb.origin.distance_to(gc.origin)
	var to := target - a
	var d := clampf(to.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var dir := to.normalized()
	var side := 1.0 if (_m * a).x > 0.0 else -1.0
	var pole := (inv.basis * Vector3(side, -0.35, -0.45)).normalized()
	var n := (pole - dir * pole.dot(dir))
	if n.length_squared() < 0.0001:
		n = Vector3(0, 0, -1)
	n = n.normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var elbow := a + dir * (l1 * cos_a) + n * (l1 * sqrt(1.0 - cos_a * cos_a))
	var hand_at := a + dir * d
	# Brazo: lleva (codo actual - hombro) a (codo nuevo - hombro)
	var r1 := Quaternion((gb.origin - a).normalized(), (elbow - a).normalized())
	var new_ga := Transform3D(Basis(r1) * ga.basis, a)
	_set_global_rot(sk, arm, new_ga)
	# Antebrazo, ya con el brazo girado
	var gb2 := new_ga * sk.get_bone_pose(fore)
	var gc2 := gb2 * sk.get_bone_pose(hand)
	var r2 := Quaternion((gc2.origin - gb2.origin).normalized(), (hand_at - gb2.origin).normalized())
	var new_gb := Transform3D(Basis(r2) * gb2.basis, gb2.origin)
	_set_global_rot(sk, fore, new_gb)


func _set_global_rot(sk: Skeleton3D, bone: int, global: Transform3D) -> void:
	var parent := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var local := pg.affine_inverse() * global
	sk.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())
