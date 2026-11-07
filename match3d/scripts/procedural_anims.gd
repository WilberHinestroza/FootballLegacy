class_name ProceduralAnims
extends RefCounted
## Animaciones hechas por código sobre el esqueleto de Mixamo, para las que el modelo
## no trae: caminar de verdad (no "run" a cámara lenta), caminar cabizbajo y el salto
## de celebración. Se construyen una vez desde la postura del "idle" y se guardan en
## la biblioteca compartida de animaciones.
##
## Cada giro se escribe en el espacio del personaje (mira a +Z, +X es su izquierda) y
## se pasa al espacio local de cada hueso: local' = Gp⁻¹ · R · Gp · local, con Gp el
## giro global del padre en la postura base.

const FPS := 30.0

var _anim: AnimationPlayer
var _skel: Skeleton3D
var _idle: Animation
var _to_skel: Quaternion       # personaje -> esqueleto
var _skel_basis: Basis         # esqueleto -> personaje (con escala)
var _base_local := {}          # hueso -> Quaternion de la postura base
var _base_global := {}         # hueso -> Quaternion global (espacio esqueleto)
var _hips_pos := Vector3.ZERO
var _hip_h := 1.0              # altura de la cadera en metros


static func build_all(anim: AnimationPlayer, skel: Skeleton3D, owner: Node3D) -> void:
	var lib := anim.get_animation_library("")
	if lib == null or lib.has_meta("procedural_v3") or not anim.has_animation("idle"):
		return
	lib.set_meta("procedural_v3", true)
	var b := ProceduralAnims.new()
	b._setup(anim, skel, owner)
	b._add(lib, "walk", b._walk(1.05, 1.0, 0.0))
	b._add(lib, "walk_sad", b._walk(1.25, 0.7, 1.0))
	b._add(lib, "jump_cheer", b._jump())
	b._add(lib, "shot_strike", b._strike(true))
	b._add(lib, "pass_inside", b._strike(false))
	b._add(lib, "stumble_l", b._stumble(1.0))
	b._add(lib, "stumble_r", b._stumble(-1.0))
	b._add(lib, "tired", b._tired())


func _add(lib: AnimationLibrary, n: String, a: Animation) -> void:
	if lib.has_animation(n):
		lib.remove_animation(n)
	lib.add_animation(n, a)


func _setup(anim: AnimationPlayer, skel: Skeleton3D, owner: Node3D) -> void:
	_anim = anim
	_skel = skel
	_idle = anim.get_animation("idle")
	var acc := Transform3D.IDENTITY
	var n: Node = skel
	while n != null and n != owner:
		if n is Node3D:
			acc = (n as Node3D).transform * acc
		n = n.get_parent()
	_skel_basis = acc.basis
	_to_skel = acc.basis.get_rotation_quaternion().inverse()
	for i in skel.get_bone_count():
		var q := skel.get_bone_rest(i).basis.get_rotation_quaternion()
		var t := _track(i, Animation.TYPE_ROTATION_3D)
		if t >= 0:
			q = _idle.rotation_track_interpolate(t, 0.0)
		_base_local[i] = q
		var p := skel.get_bone_parent(i)
		_base_global[i] = (_base_global[p] as Quaternion) * q if p >= 0 else q
	var h := _bone("Hips")
	var pt := _track(h, Animation.TYPE_POSITION_3D)
	_hips_pos = _idle.position_track_interpolate(pt, 0.0) if pt >= 0 else skel.get_bone_rest(h).origin
	_hip_h = maxf(0.3, (acc * _hips_pos).y)


func _bone(short: String) -> int:
	return ItemCatalog.find_bone(_skel, short)


func _track(bone: int, ty: int) -> int:
	if bone < 0:
		return -1
	var bn := _skel.get_bone_name(bone)
	for t in _idle.get_track_count():
		if _idle.track_get_type(t) == ty and String(_idle.track_get_path(t)).get_slice(":", 1) == bn:
			return t
	return -1


## Animación nueva con la postura base en todos los huesos (una clave).
func _blank(length: float, loop: bool) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for t in _idle.get_track_count():
		var ty := _idle.track_get_type(t)
		if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D:
			continue
		var nt := a.add_track(ty)
		a.track_set_path(nt, _idle.track_get_path(t))
		a.track_set_interpolation_type(nt, Animation.INTERPOLATION_LINEAR)
		if ty == Animation.TYPE_ROTATION_3D:
			a.rotation_track_insert_key(nt, 0.0, _idle.rotation_track_interpolate(t, 0.0))
		else:
			a.position_track_insert_key(nt, 0.0, _idle.position_track_interpolate(t, 0.0))
	return a


func _find(a: Animation, bone: int, ty: int) -> int:
	if bone < 0:
		return -1
	var bn := _skel.get_bone_name(bone)
	for t in a.get_track_count():
		if a.track_get_type(t) == ty and String(a.track_get_path(t)).get_slice(":", 1) == bn:
			return t
	return -1


## Giro `rc` (espacio del personaje) aplicado al hueso sobre su postura base.
func _rot(bone: int, rc: Quaternion) -> Quaternion:
	var base: Quaternion = _base_local[bone]
	var p := _skel.get_bone_parent(bone)
	var gp: Quaternion = _base_global[p] if p >= 0 else Quaternion.IDENTITY
	var rs := _to_skel * rc * _to_skel.inverse()
	return (gp.inverse() * rs * gp * base).normalized()


static func rx(deg: float) -> Quaternion:
	return Quaternion(Vector3.RIGHT, deg_to_rad(deg))


static func ry(deg: float) -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(deg))


static func rz(deg: float) -> Quaternion:
	return Quaternion(Vector3.BACK, deg_to_rad(deg))


## Escribe las claves de un hueso: fn(t) -> Quaternion en espacio del personaje.
func _key_bone(a: Animation, short: String, fn: Callable) -> void:
	var b := _bone(short)
	var t := _find(a, b, Animation.TYPE_ROTATION_3D)
	if t < 0:
		return
	while a.track_get_key_count(t) > 0:
		a.track_remove_key(t, 0)
	var n := int(round(a.length * FPS))
	for i in n + 1:
		var time := a.length * float(i) / float(n)
		a.rotation_track_insert_key(t, time, _rot(b, fn.call(time / a.length)))


## Cadera: desplazamiento en metros (espacio del personaje) en función de la fase.
func _key_hips(a: Animation, fn: Callable) -> void:
	var t := _find(a, _bone("Hips"), Animation.TYPE_POSITION_3D)
	if t < 0:
		return
	while a.track_get_key_count(t) > 0:
		a.track_remove_key(t, 0)
	var inv := _skel_basis.inverse()
	var n := int(round(a.length * FPS))
	for i in n + 1:
		var time := a.length * float(i) / float(n)
		var off: Vector3 = fn.call(time / a.length)
		a.position_track_insert_key(t, time, _hips_pos + inv * off)


## Caminar. `period` = segundos por ciclo (dos pasos); `energy` escala la amplitud;
## `sad` (0-1) baja la cabeza, encorva y arrastra los brazos.
func _walk(period: float, energy: float, sad: float) -> Animation:
	var a := _blank(period, true)
	var A := 21.0 * energy      # muslo adelante/atrás
	var K := 50.0 * energy      # flexión de rodilla en el vuelo
	var ARM := 15.0 * energy * lerpf(1.0, 0.35, sad)
	for side: int in [0, 1]:
		var pre := "Left" if side == 0 else "Right"
		var off := 0.0 if side == 0 else 0.5
		var thigh := func(p: float) -> float: return A * sin(TAU * (p + off))
		var knee := func(p: float) -> float:
			var ph := TAU * (p + off)
			return 5.0 + K * pow(maxf(0.0, cos(ph - 0.25)), 1.7) + 9.0 * energy * maxf(0.0, sin(ph * 1.0 - 1.9)) * 0.6
		_key_bone(a, pre + "UpLeg", func(p: float) -> Quaternion: return rx(-thigh.call(p)))
		_key_bone(a, pre + "Leg", func(p: float) -> Quaternion: return rx(knee.call(p)))
		_key_bone(a, pre + "Foot", func(p: float) -> Quaternion:
			var ph := fposmod(p + off, 1.0)
			var level: float = -(float(thigh.call(p)) - float(knee.call(p))) * 0.85
			# Despegue: la punta empuja abajo justo antes del vuelo
			var push := -16.0 * energy * exp(-pow((ph - 0.8) / 0.07, 2.0))
			return rx(-(level + push)))
		_key_bone(a, pre + "ToeBase", func(p: float) -> Quaternion:
			var ph := fposmod(p + off, 1.0)
			return rx(-18.0 * energy * exp(-pow((ph - 0.8) / 0.08, 2.0))))
		# Brazo contrario a la pierna del mismo lado
		var arm := func(p: float) -> float: return -ARM * sin(TAU * (p + off))
		_key_bone(a, pre + "Arm", func(p: float) -> Quaternion:
			return rx(-arm.call(p)) * rz((-1.0 if side == 0 else 1.0) * lerpf(0.0, 4.0, sad)))
		_key_bone(a, pre + "ForeArm", func(p: float) -> Quaternion:
			return rx(-(lerpf(14.0, 6.0, sad) + 10.0 * energy * maxf(0.0, arm.call(p) / maxf(ARM, 0.01)))))
	# Pelvis: gira con la pierna que avanza; el pecho, al revés. Leve balanceo.
	_key_bone(a, "Hips", func(p: float) -> Quaternion:
		return ry(-5.0 * energy * sin(TAU * p)) * rz(2.0 * energy * cos(TAU * p)))
	_key_bone(a, "Spine", func(p: float) -> Quaternion: return rx(lerpf(2.0, 4.5, sad)) * ry(2.5 * energy * sin(TAU * p)))
	_key_bone(a, "Spine1", func(p: float) -> Quaternion: return rx(lerpf(1.0, 3.0, sad)) * ry(2.5 * energy * sin(TAU * p)))
	_key_bone(a, "Spine2", func(p: float) -> Quaternion: return rx(lerpf(0.0, 2.0, sad)) * ry(1.5 * energy * sin(TAU * p)))
	_key_bone(a, "Neck", func(p: float) -> Quaternion: return rx(lerpf(0.0, 7.0, sad)) * ry(-1.5 * energy * sin(TAU * p)))
	_key_bone(a, "Head", func(p: float) -> Quaternion:
		return rx(lerpf(-2.0, 13.0, sad) + 1.2 * cos(TAU * 2.0 * p)) * ry(-2.0 * energy * sin(TAU * p)))
	# Sube en cada apoyo medio, baja en el doble apoyo; se mece sobre la pierna que pisa
	var drop := _hip_h * (1.0 - cos(deg_to_rad(A * 0.9)))
	_key_hips(a, func(p: float) -> Vector3:
		return Vector3(-0.018 * energy * cos(TAU * p), -drop * 0.5 + drop * 0.5 * cos(TAU * 2.0 * p) - 0.012, 0.0))
	return a


## Salto de celebración con los dos pies y los puños arriba (1,2 s, sin bucle):
## se agacha, impulsa, en el aire encoge un poco las piernas, cae amortiguando.
func _jump() -> Animation:
	var L := 1.2
	var a := _blank(L, false)
	# Curvas por fase (0-1): agacharse, en el aire, altura
	var crouch := func(p: float) -> float:
		return smoothstep(0.0, 0.25, p) * (1.0 - smoothstep(0.3, 0.38, p)) \
			+ smoothstep(0.66, 0.74, p) * (1.0 - smoothstep(0.8, 1.0, p)) * 0.8
	var air := func(p: float) -> float: return smoothstep(0.34, 0.42, p) * (1.0 - smoothstep(0.6, 0.68, p))
	var lift := func(p: float) -> float:
		var q := clampf((p - 0.36) / 0.32, 0.0, 1.0)
		return 4.0 * q * (1.0 - q)
	var arms := func(p: float) -> float: return smoothstep(0.22, 0.4, p) * (1.0 - smoothstep(0.78, 1.0, p) * 0.85)
	for side: int in [0, 1]:
		var pre := "Left" if side == 0 else "Right"
		var s := 1.0 if side == 0 else -1.0
		_key_bone(a, pre + "UpLeg", func(p: float) -> Quaternion:
			return rx(-(48.0 * crouch.call(p) + 22.0 * air.call(p))))
		_key_bone(a, pre + "Leg", func(p: float) -> Quaternion:
			return rx(92.0 * crouch.call(p) + 40.0 * air.call(p)))
		_key_bone(a, pre + "Foot", func(p: float) -> Quaternion:
			return rx(-(-44.0 * crouch.call(p) + (-30.0) * air.call(p))))
		# Brazos: atrás al agacharse, arriba en V con el puño cerrado al saltar
		_key_bone(a, pre + "Arm", func(p: float) -> Quaternion:
			var up: float = arms.call(p)
			return rz(s * 140.0 * up) * rx(-8.0 * up + 25.0 * crouch.call(p) * (1.0 - up)))
		_key_bone(a, pre + "ForeArm", func(p: float) -> Quaternion:
			return rx(-(18.0 - 10.0 * arms.call(p))))
		_key_bone(a, pre + "Hand", func(p: float) -> Quaternion: return rx(-10.0 * arms.call(p)))
	_key_bone(a, "Spine", func(p: float) -> Quaternion: return rx(22.0 * crouch.call(p) - 8.0 * air.call(p)))
	_key_bone(a, "Spine1", func(p: float) -> Quaternion: return rx(8.0 * crouch.call(p) - 4.0 * air.call(p)))
	_key_bone(a, "Head", func(p: float) -> Quaternion: return rx(-14.0 * air.call(p) - 6.0 * crouch.call(p)))
	var leg := _hip_h
	_key_hips(a, func(p: float) -> Vector3:
		# Lo que baja la cadera al doblar rodillas (muslo y pierna, mitad del largo cada uno)
		var th := deg_to_rad(48.0 * crouch.call(p) + 22.0 * air.call(p))
		var sh := deg_to_rad(92.0 * crouch.call(p) + 40.0 * air.call(p)) - th
		var bend := leg * 0.5 * ((1.0 - cos(th)) + (1.0 - cos(sh)))
		var y: float = -bend * (1.0 - float(air.call(p))) + 0.42 * float(lift.call(p))
		return Vector3(0.0, y, 0.06 * crouch.call(p)))
	return a


## Tambaleo tras un choque de hombros. `s` = +1 empujado hacia su izquierda (+X),
## -1 hacia su derecha. El cuerpo se va hacia ese lado, la pierna de ese lado sale a
## buscar el suelo para no caerse y los brazos se abren para recuperar el equilibrio.
func _stumble(s: float) -> Animation:
	var L := 0.7
	var a := _blank(L, false)
	var hit := [[0.0, 0.0], [0.12, 1.0], [0.34, 0.75], [L, 0.0]]
	var step := [[0.0, 0.0], [0.1, 0.2], [0.24, 1.0], [0.45, 0.6], [L, 0.0]]
	var push_side := "Left" if s > 0.0 else "Right"
	var other_side := "Right" if s > 0.0 else "Left"
	# Pierna del lado del empujón: se abre y se dobla al apoyar
	_key_bone(a, push_side + "UpLeg", func(p: float) -> Quaternion:
		var k := curve(step, p * L)
		return rz(s * 16.0 * k) * rx(-14.0 * k))
	_key_bone(a, push_side + "Leg", func(p: float) -> Quaternion: return rx(10.0 + 24.0 * curve(step, p * L)))
	_key_bone(a, other_side + "UpLeg", func(p: float) -> Quaternion: return rx(-6.0 * curve(hit, p * L)))
	_key_bone(a, other_side + "Leg", func(p: float) -> Quaternion: return rx(8.0 + 14.0 * curve(hit, p * L)))
	# Tronco hacia el lado del empujón; la cabeza compensa un poco
	_key_bone(a, "Hips", func(p: float) -> Quaternion: return rz(-s * 8.0 * curve(hit, p * L)))
	_key_bone(a, "Spine", func(p: float) -> Quaternion:
		var k := curve(hit, p * L)
		return rz(-s * 13.0 * k) * rx(8.0 * k))
	_key_bone(a, "Spine1", func(p: float) -> Quaternion: return rz(-s * 5.0 * curve(hit, p * L)))
	_key_bone(a, "Head", func(p: float) -> Quaternion: return rz(s * 9.0 * curve(hit, p * L)))
	# Brazos abiertos para el equilibrio (más el del lado al que se cae)
	for side: int in [0, 1]:
		var pre := "Left" if side == 0 else "Right"
		var sa := 1.0 if side == 0 else -1.0
		var amt := 28.0 if pre == push_side else 14.0
		_key_bone(a, pre + "Arm", func(p: float) -> Quaternion:
			var k := curve(hit, p * L)
			return rz(sa * (amt * k + 8.0)) * rx(-10.0 * k))
		_key_bone(a, pre + "ForeArm", func(p: float) -> Quaternion: return rx(-(20.0 + 15.0 * curve(hit, p * L))))
	_key_hips(a, func(p: float) -> Vector3:
		var k := curve(hit, p * L)
		return Vector3(s * 0.12 * k, -0.05 * k, 0.0))
	return a


## Sin aire: inclinado hacia delante con las manos en las rodillas, respirando
## fuerte (bucle de 2,4 s, dos respiraciones). Para el que se queda parado y agotado.
func _tired() -> Animation:
	var L := 2.4
	var a := _blank(L, true)
	var breath := func(p: float) -> float: return 0.5 - 0.5 * cos(TAU * 2.0 * p)
	var BEND := 34.0  # tronco hacia delante (cadera + columna)
	var THIGH := 24.0 # rodillas un poco dobladas
	var KNEE := 34.0
	for side: int in [0, 1]:
		var pre := "Left" if side == 0 else "Right"
		var s := 1.0 if side == 0 else -1.0
		# La pelvis se inclina BEND: el muslo lo compensa para que la pierna siga
		# vertical, más la flexión de rodilla; el pie vuelve a quedar plano
		_key_bone(a, pre + "UpLeg", func(p: float) -> Quaternion: return rx(-(BEND + THIGH)) * rz(s * 3.0))
		_key_bone(a, pre + "Leg", func(p: float) -> Quaternion: return rx(KNEE))
		_key_bone(a, pre + "Foot", func(p: float) -> Quaternion: return rx(-(KNEE - THIGH) * 0.9))
		# Brazos hacia delante y abajo, las manos apoyadas encima de la rodilla
		_key_bone(a, pre + "Arm", func(p: float) -> Quaternion:
			return rx(-22.0 - 3.0 * breath.call(p)) * rz(-s * 7.0))
		_key_bone(a, pre + "ForeArm", func(p: float) -> Quaternion: return rx(-10.0))
		_key_bone(a, pre + "Hand", func(p: float) -> Quaternion: return rx(-25.0))
	_key_bone(a, "Hips", func(p: float) -> Quaternion: return rx(BEND))
	# Al tomar aire el pecho se abre (sube) y los hombros se levantan un poco
	_key_bone(a, "Spine", func(p: float) -> Quaternion: return rx(8.0 - 3.0 * breath.call(p)))
	_key_bone(a, "Spine1", func(p: float) -> Quaternion: return rx(4.0 - 2.0 * breath.call(p)))
	_key_bone(a, "Spine2", func(p: float) -> Quaternion: return rx(2.0 - 2.0 * breath.call(p)))
	# Cabeza levantada mirando al juego (si no, solo mira el suelo)
	_key_bone(a, "Neck", func(p: float) -> Quaternion: return rx(-14.0))
	_key_bone(a, "Head", func(p: float) -> Quaternion: return rx(-16.0 + 3.0 * breath.call(p)))
	var leg := _hip_h
	_key_hips(a, func(p: float) -> Vector3:
		var th := deg_to_rad(THIGH)
		var sh := deg_to_rad(KNEE) - th
		var bend := leg * 0.5 * ((1.0 - cos(th)) + (1.0 - cos(sh)))
		return Vector3(0.0, -bend - 0.01 * breath.call(p), -0.06))
	return a


## Curva suave por claves [[t, valor], ...] (t en segundos), con tramos en S.
static func curve(keys: Array, t: float) -> float:
	if t <= float(keys[0][0]):
		return float(keys[0][1])
	for i in range(1, keys.size()):
		var t1 := float(keys[i][0])
		if t <= t1:
			var t0 := float(keys[i - 1][0])
			var u := smoothstep(0.0, 1.0, (t - t0) / maxf(t1 - t0, 0.0001))
			return lerpf(float(keys[i - 1][1]), float(keys[i][1]), u)
	return float(keys[-1][1])


## Golpe con la derecha. `shot`: empeine fuerte (paso de apoyo, pierna atrás con el
## talón al glúteo, latigazo, la pierna sigue hasta arriba, brazo izquierdo abierto
## para el equilibrio). Si no, pase con el interior: pie girado hacia fuera, poco
## recorrido y el tobillo firme. Contacto: 0,42 s (tiro) / 0,30 s (pase).
func _strike(shot: bool) -> Animation:
	var L := 0.95 if shot else 0.72
	var a := _blank(L, false)
	var k := 1.0 if shot else 0.0
	# Pierna que golpea (derecha): muslo adelante +, rodilla, pie (+ = punta arriba)
	var thigh := [[0.0, 0.0], [0.14, -10.0], [0.3, -32.0], [0.42, 24.0], [0.58, 62.0], [0.75, 22.0], [0.95, 0.0]] if shot 		else [[0.0, 0.0], [0.17, -24.0], [0.3, 16.0], [0.42, 30.0], [0.58, 8.0], [0.72, 0.0]]
	var knee := [[0.0, 6.0], [0.14, 30.0], [0.3, 100.0], [0.42, 12.0], [0.58, 18.0], [0.75, 30.0], [0.95, 6.0]] if shot 		else [[0.0, 6.0], [0.17, 48.0], [0.3, 14.0], [0.42, 12.0], [0.58, 22.0], [0.72, 6.0]]
	var foot := [[0.0, 0.0], [0.3, -25.0], [0.42, -38.0], [0.58, -20.0], [0.95, 0.0]] if shot 		else [[0.0, 0.0], [0.17, 6.0], [0.3, 10.0], [0.5, 6.0], [0.72, 0.0]]
	var turn_out := [[0.0, 0.0], [0.15, 0.0], [0.26, 42.0], [0.45, 42.0], [0.62, 0.0]] # pase: pie de lado
	# Pierna de apoyo (izquierda): un paso adelante y flexión al cargar
	var sthigh := [[0.0, 0.0], [0.18, 18.0], [0.42, 10.0], [0.65, 4.0], [L, 0.0]]
	var sknee := [[0.0, 6.0], [0.18, 14.0], [0.42, 26.0 if shot else 18.0], [0.65, 14.0], [L, 6.0]]
	# Tronco: se abre (cadera derecha atrás) y luego gira hacia el golpe
	var yaw := [[0.0, 0.0], [0.3, -16.0], [0.42, 6.0], [0.6, 20.0], [L, 0.0]] if shot 		else [[0.0, 0.0], [0.2, -8.0], [0.34, 10.0], [0.5, 6.0], [L, 0.0]]
	var lean := [[0.0, 4.0], [0.3, -2.0], [0.42, 8.0], [0.6, -6.0], [L, 2.0]] if shot 		else [[0.0, 6.0], [0.3, 10.0], [0.5, 8.0], [L, 4.0]]
	var arm_l := [[0.0, 8.0], [0.3, 55.0], [0.45, 70.0], [0.7, 40.0], [L, 8.0]] if shot 		else [[0.0, 8.0], [0.3, 30.0], [0.5, 26.0], [L, 8.0]]
	var arm_r := [[0.0, 0.0], [0.3, -30.0], [0.45, 20.0], [0.7, 10.0], [L, 0.0]] if shot 		else [[0.0, 0.0], [0.3, -12.0], [0.5, 6.0], [L, 0.0]]
	_key_bone(a, "RightUpLeg", func(p: float) -> Quaternion:
		var t := p * L
		var out := 0.0 if shot else curve(turn_out, t)
		return ry(-out) * rx(-curve(thigh, t)))
	_key_bone(a, "RightLeg", func(p: float) -> Quaternion: return rx(curve(knee, p * L)))
	_key_bone(a, "RightFoot", func(p: float) -> Quaternion: return rx(-curve(foot, p * L)))
	_key_bone(a, "LeftUpLeg", func(p: float) -> Quaternion: return rx(-curve(sthigh, p * L)))
	_key_bone(a, "LeftLeg", func(p: float) -> Quaternion: return rx(curve(sknee, p * L)))
	_key_bone(a, "LeftFoot", func(p: float) -> Quaternion:
		var t := p * L
		return rx(-(-(curve(sthigh, t) - curve(sknee, t)) * 0.85)))
	_key_bone(a, "Hips", func(p: float) -> Quaternion: return ry(curve(yaw, p * L)) * rz(-4.0 * k * sin(PI * clampf(p * L / 0.7, 0.0, 1.0))))
	_key_bone(a, "Spine", func(p: float) -> Quaternion: return rx(curve(lean, p * L)) * ry(-curve(yaw, p * L) * 0.4))
	_key_bone(a, "Spine1", func(p: float) -> Quaternion: return rx(curve(lean, p * L) * 0.5) * ry(-curve(yaw, p * L) * 0.3))
	# La cabeza mira el balón todo el golpe
	_key_bone(a, "Head", func(p: float) -> Quaternion: return rx(14.0 + 4.0 * k) * ry(-curve(yaw, p * L) * 0.3))
	_key_bone(a, "LeftArm", func(p: float) -> Quaternion:
		var v := curve(arm_l, p * L)
		return rz(v) * rx(-v * 0.15))
	_key_bone(a, "LeftForeArm", func(p: float) -> Quaternion: return rx(-(15.0 + curve(arm_l, p * L) * 0.2)))
	_key_bone(a, "RightArm", func(p: float) -> Quaternion:
		var v := curve(arm_r, p * L)
		return rx(-v) * rz(-curve(arm_l, p * L) * 0.35))
	_key_bone(a, "RightForeArm", func(p: float) -> Quaternion: return rx(-20.0))
	var drop := _hip_h
	_key_hips(a, func(p: float) -> Vector3:
		var t := p * L
		var th := deg_to_rad(curve(sthigh, t))
		var sh := deg_to_rad(curve(sknee, t)) - th
		var bend := drop * 0.5 * ((1.0 - cos(th)) + (1.0 - cos(sh)))
		# Al tirar se impulsa un poco hacia delante y arriba tras el golpe
		var hop := 0.03 * k * smoothstep(0.42, 0.55, t) * (1.0 - smoothstep(0.6, 0.85, t))
		return Vector3(0.0, -bend + hop, curve([[0.0, 0.0], [0.42, 0.07], [0.6, 0.08], [L, 0.0]], t)))
	return a
