class_name PlayerAvatar
extends Node3D
## Modelo del jugador: malla con esqueleto y animaciones (ComfyUI + Mixamo),
## colores por zona (shader) y objetos equipados pegados a los huesos.
## Lo usan el partido (SoccerPlayer) y el editor de jugador.

const MODEL_PATH := "res://match3d/models/player01_anim.glb"
const ZONE_SHADER := preload("res://match3d/shaders/player_zones.gdshader")
const ZONE_SHADER_FADE := preload("res://match3d/shaders/player_zones_fade.gdshader")
const LOOP_ANIMS := ["idle", "run", "run_back", "strafe_left", "strafe_right", "keeper_idle", "keeper_side",
		"sit", "sit_2", "sit_3", "sit_talk", "sit_react",
		"sit_clap", "victory_idle", "clap", "kneel", "crouch",
		"dance_1", "dance_2", "dance_3", "dance_4", "dance_5", "dance_6", "dance_7", "dance_8"]

## Cabeza (accesorios): centro desde el hueso Head y radio, en metros del jugador.
const HEAD_C := Vector3(0.0, 0.27, 0.03)
const HEAD_R := 0.21
const EYE_Y := 0.205 # altura de los ojos sobre el hueso de la cabeza

static var _model_scene: PackedScene

var anim: AnimationPlayer
var skeleton: Skeleton3D
var _meshes: Array[MeshInstance3D] = []
var _mat: ShaderMaterial
var _mat_fade: ShaderMaterial
var _items := {} # ranura -> nodos pegados al esqueleto
var _hair_mat := StandardMaterial3D.new()
var _hair_node: Node3D
var _hair_style := ""
var _arm_pose: ArmPose
var _arm_tween: Tween
var _garments := {} # id -> MeshInstance3D (Garments)
var _garment_ids: Array = []
var _faded := false
var _casts_shadow := true
var _long_sleeves := false
var _long_pants := false


## Trote: no hay animación de andar/trotar en el modelo, así que se saca de "run" con la
## mitad de amplitud (piernas, brazos y rebote más suaves, hacia la postura del idle).
## Para volver a la posición o acompañar la jugada sin "correr a cámara lenta".
func _ensure_jog() -> void:
	_derive_gait("jog", 0.55, 0.5)
	# Caminar, caminar cabizbajo y el salto de celebración: hechos por código
	ProceduralAnims.build_all(anim, skeleton, self)


## Variante de "run" con menos amplitud de giro (`amp`) y de rebote de cadera (`bounce`).
func _derive_gait(new_name: String, amp: float, bounce: float) -> void:
	if anim.has_animation(new_name) or not anim.has_animation("run") or not anim.has_animation("idle"):
		return
	var run := anim.get_animation("run")
	var idle := anim.get_animation("idle")
	var jog := run.duplicate(true) as Animation
	for t in jog.get_track_count():
		var path := jog.track_get_path(t)
		var it := idle.find_track(path, jog.track_get_type(t))
		var ty := jog.track_get_type(t)
		if ty == Animation.TYPE_ROTATION_3D:
			var base: Quaternion = idle.rotation_track_interpolate(it, 0.0) if it >= 0 else Quaternion.IDENTITY
			for k in jog.track_get_key_count(t):
				var q: Quaternion = jog.track_get_key_value(t, k)
				jog.track_set_key_value(t, k, base.slerp(q, amp))
		elif ty == Animation.TYPE_POSITION_3D and it >= 0:
			var bp: Vector3 = idle.position_track_interpolate(it, 0.0)
			for k in jog.track_get_key_count(t):
				var v: Vector3 = jog.track_get_key_value(t, k)
				jog.track_set_key_value(t, k, bp.lerp(v, bounce))
	jog.loop_mode = Animation.LOOP_LINEAR
	var lib := anim.get_animation_library("")
	if lib != null and not lib.has_animation(new_name):
		lib.add_animation(new_name, jog)


## Retoques a animaciones de Mixamo que se veían raras (revisadas cuadro a cuadro):
##  - chute y pase: el cuerpo iba encorvado todo el rato y la pierna apenas se movía →
##    tronco y cabeza más erguidos y la pierna que golpea con más recorrido;
##  - rodillas (festejo): la cadera no bajaba y la rodilla atravesaba el césped →
##    la cadera baja lo justo para que rodilla y pie apoyen en el suelo.
## Se hace una vez (la biblioteca de animaciones la comparten todos los jugadores).
func _fix_anims() -> void:
	var lib := anim.get_animation_library("")
	if lib == null or lib.has_meta("fixed_v1"):
		return
	lib.set_meta("fixed_v1", true)
	var idle := anim.get_animation("idle")
	for n: String in ["kick", "pass"]:
		if not anim.has_animation(n):
			continue
		var a := anim.get_animation(n)
		var leg := "LeftUpLeg" if n == "kick" else "RightUpLeg"
		var knee := "LeftLeg" if n == "kick" else "RightLeg"
		for t in a.get_track_count():
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var bone := String(a.track_get_path(t)).get_slice(":", 1)
			if bone.ends_with("Spine") or bone.ends_with("Spine1") or bone.ends_with("Spine2") 					or bone.ends_with("Neck") or bone.ends_with("Head"):
				var it := idle.find_track(a.track_get_path(t), Animation.TYPE_ROTATION_3D)
				if it < 0:
					continue
				var base: Quaternion = idle.rotation_track_interpolate(it, 0.0)
				for k in a.track_get_key_count(t):
					a.track_set_key_value(t, k, (a.track_get_key_value(t, k) as Quaternion).slerp(base, 0.45))
			elif bone.ends_with(leg) or bone.ends_with(knee):
				if a.track_get_key_count(t) == 0:
					continue
				var q0: Quaternion = a.track_get_key_value(t, 0)
				for k in a.track_get_key_count(t):
					var d: Quaternion = q0.inverse() * (a.track_get_key_value(t, k) as Quaternion)
					if d.get_angle() > 0.001:
						a.track_set_key_value(t, k, q0 * Quaternion(d.get_axis(), d.get_angle() * 1.35))
	if anim.has_animation("kneel"):
		_ground_fix(anim.get_animation("kneel"), ["LeftLeg", "RightLeg", "LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"])
	# Entrada y caída: el brazo que salía recto hacia arriba (un cuadro raro de la
	# captura) vuelve hacia la pose de reposo; la caída además se apoya en el suelo
	# con todo el cuerpo (antes quedaba flotando a medio metro).
	for n: String in ["tackle", "fall"]:
		if anim.has_animation(n):
			_tame_arms(anim.get_animation(n), idle, 0.55 if n == "tackle" else 0.75)
	if anim.has_animation("fall"):
		_ground_fix(anim.get_animation("fall"), ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot", "LeftLeg", "RightLeg",
			"Hips", "Spine1", "Spine2", "Head", "LeftHand", "RightHand", "LeftForeArm", "RightForeArm"], 0.09)
	# Estiradas del portero: al caer no se hunde en el césped.
	for n: String in ["keeper_dive", "keeper_dive_high"]:
		if anim.has_animation(n):
			_ground_fix(anim.get_animation(n), ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot", "LeftLeg", "RightLeg",
				"Hips", "Spine1", "Spine2", "Head", "LeftHand", "RightHand", "LeftForeArm", "RightForeArm"], 0.09, true)


## Brazos que apuntan hacia arriba más de `thr` (componente vertical del brazo, 0-1):
## se acercan a la pose del idle en proporción a cuánto se pasan.
func _tame_arms(a: Animation, idle: Animation, thr: float) -> void:
	var prefix := String(a.track_get_path(0)).get_slice(":", 0)
	var m := skeleton.transform
	var par := skeleton.get_parent()
	while par != null and par != self and par is Node3D:
		m = (par as Node3D).transform * m
		par = par.get_parent()
	for side: String in ["Left", "Right"]:
		var arm := ItemCatalog.find_bone(skeleton, side + "Arm")
		var fore := ItemCatalog.find_bone(skeleton, side + "ForeArm")
		if arm < 0 or fore < 0:
			continue
		var path := NodePath(prefix + ":" + skeleton.get_bone_name(arm))
		var rt := a.find_track(path, Animation.TYPE_ROTATION_3D)
		var it := idle.find_track(path, Animation.TYPE_ROTATION_3D)
		if rt < 0 or it < 0:
			continue
		var rest: Quaternion = idle.rotation_track_interpolate(it, 0.0)
		var fixes: Array = []
		for k in a.track_get_key_count(rt):
			var t := a.track_get_key_time(rt, k)
			var dir := (m * _fk(a, prefix, fore, t).origin) - (m * _fk(a, prefix, arm, t).origin)
			if dir.length() < 0.001:
				continue
			var up := dir.normalized().y
			if up > thr:
				fixes.append([k, clampf((up - thr) / (1.0 - thr), 0.0, 1.0) * 0.85])
		for fx: Array in fixes:
			var q: Quaternion = a.track_get_key_value(rt, fx[0])
			a.track_set_key_value(rt, fx[0], q.slerp(rest, fx[1]))


## Baja/sube la cadera en cada cuadro para que el punto más bajo de `bones` quede en
## el suelo (cinemática directa a mano, sin depender de que el modelo esté en escena).
## raise_only: solo sube lo que se hunde (estiradas: lo que va en el aire se queda).
func _ground_fix(a: Animation, bones: Array, floor_y := 0.04, raise_only := false) -> void:
	var hips := ItemCatalog.find_bone(skeleton, "Hips")
	if hips < 0:
		return
	var prefix := String(a.track_get_path(0)).get_slice(":", 0)
	var ht := a.find_track(NodePath(prefix + ":" + skeleton.get_bone_name(hips)), Animation.TYPE_POSITION_3D)
	if ht < 0:
		return
	# Cadera quieta (una sola clave, el giro lo hace la rotación): se le ponen claves a
	# 15 por segundo para poder subirla/bajarla cuadro a cuadro.
	if a.track_get_key_count(ht) < 4:
		var v0: Vector3 = a.track_get_key_value(ht, 0)
		var steps := maxi(2, int(ceil(a.length * 15.0)))
		for i in range(1, steps + 1):
			a.position_track_insert_key(ht, a.length * i / float(steps), v0)
	var ids: Array[int] = []
	for b: String in bones:
		var i := ItemCatalog.find_bone(skeleton, b)
		if i >= 0:
			ids.append(i)
	# Del espacio del esqueleto al del modelo (+Y arriba, metros)
	var m := skeleton.transform
	var p := skeleton.get_parent()
	while p != null and p != self and p is Node3D:
		m = (p as Node3D).transform * m
		p = p.get_parent()
	var up_local := m.basis.inverse() * Vector3.UP # 1 m hacia arriba, en unidades del esqueleto
	for k in a.track_get_key_count(ht):
		var t := a.track_get_key_time(ht, k)
		var low := INF
		for id in ids:
			low = minf(low, (m * _fk(a, prefix, id, t).origin).y)
		if low == INF:
			continue
		if raise_only and low >= floor_y:
			continue
		var v: Vector3 = a.track_get_key_value(ht, k)
		a.track_set_key_value(ht, k, v + up_local * (floor_y - low))


func _fk(a: Animation, prefix: String, bone: int, t: float) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var b := bone
	while b >= 0:
		var name := skeleton.get_bone_name(b)
		var rest := skeleton.get_bone_rest(b)
		var pos := rest.origin
		var rot := rest.basis.get_rotation_quaternion()
		var pt := a.find_track(NodePath(prefix + ":" + name), Animation.TYPE_POSITION_3D)
		if pt >= 0:
			pos = a.position_track_interpolate(pt, t)
		var rt := a.find_track(NodePath(prefix + ":" + name), Animation.TYPE_ROTATION_3D)
		if rt >= 0:
			rot = a.rotation_track_interpolate(rt, t)
		xf = Transform3D(Basis(rot), pos) * xf
		b = skeleton.get_bone_parent(b)
	return xf


static func available() -> bool:
	return ResourceLoader.exists(MODEL_PATH)


func _init() -> void:
	if _model_scene == null:
		_model_scene = load(MODEL_PATH)
	var model := _model_scene.instantiate() as Node3D
	add_child(model)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for n: String in LOOP_ANIMS:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_ensure_jog()
	_fix_anims()
	_mat = ShaderMaterial.new()
	_mat.shader = ZONE_SHADER
	_mat_fade = ShaderMaterial.new()
	_mat_fade.shader = ZONE_SHADER_FADE
	var seed := randf() # cada uno parpadea a su ritmo
	_mat.set_shader_parameter("blink_seed", seed)
	_mat_fade.set_shader_parameter("blink_seed", seed)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _mat
		_meshes.append(mi)
	# La equipación también va por piezas (camiseta y pantaloneta con volumen de tela)
	set_garments(_kit_ids())
	# Pelo: mechones (ruido estirado en vertical) sobre el color, raíz más oscura
	# (color por vértice de HairBuilder) y algo de brillo
	_hair_mat.roughness = 0.62
	_hair_mat.metallic_specular = 0.45
	_hair_mat.vertex_color_use_as_albedo = true
	_hair_mat.albedo_texture = _hair_strands()
	_hair_mat.uv1_scale = Vector3(6.0, 1.0, 1.0)
	_hair_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_hair_mat.albedo_color = Color(0.35, 0.22, 0.12)


static var _strands_tex: NoiseTexture2D

## Textura de mechones compartida: ruido muy estirado a lo largo del pelo.
static func _hair_strands() -> Texture2D:
	if _strands_tex == null:
		var nz := FastNoiseLite.new()
		nz.noise_type = FastNoiseLite.TYPE_PERLIN
		nz.frequency = 0.06
		nz.fractal_octaves = 3
		var tex := NoiseTexture2D.new()
		tex.width = 256
		tex.height = 64
		tex.seamless = true
		tex.noise = nz
		tex.generate_mipmaps = true
		# Del ruido a mechones: casi todo claro con vetas más oscuras
		var g := Gradient.new()
		g.set_color(0, Color(0.62, 0.62, 0.62))
		g.set_color(1, Color(1.0, 1.0, 1.0))
		tex.color_ramp = g
		_strands_tex = tex
	return _strands_tex


## Colores del shader de zonas (skin_color, shirt_color… y show_hair).
func set_colors(colors: Dictionary) -> void:
	for key: String in colors:
		_mat.set_shader_parameter(key, colors[key])
		_mat_fade.set_shader_parameter(key, colors[key])
	if colors.has("hair_color"):
		_hair_mat.albedo_color = Color(colors.hair_color, _hair_mat.albedo_color.a)
	# Manga larga / pantalón largo: prendas de verdad (Garments) en vez de pintadas
	if colors.has("long_sleeves") or colors.has("long_pants"):
		_long_sleeves = bool(colors.get("long_sleeves", _long_sleeves))
		_long_pants = bool(colors.get("long_pants", _long_pants))
		set_garments(_kit_ids())


## Prendas de la ropa actual: camiseta (manga corta o larga) y pantaloneta o pantalón.
func _kit_ids() -> Array:
	return ["top_long" if _long_sleeves else "top_short", "trousers" if _long_pants else "shorts"]


## Viste prendas por piezas (ids de Garments.SPECS: "top_long", "top_short", "trousers",
## "shorts"). [] las quita todas. El cuerpo no se dibuja debajo de ellas.
func set_garments(ids: Array) -> void:
	if ids == _garment_ids:
		return
	for mi: MeshInstance3D in _garments.values():
		mi.queue_free()
	_garments.clear()
	_garment_ids = ids.duplicate()
	for id: String in ids:
		var mi := Garments.make(id, skeleton)
		if mi == null:
			continue
		mi.material_override = _mat_fade if _faded else _mat
		_garments[id] = mi
	if not _casts_shadow:
		set_casts_shadow(false)
	var c := Garments.cover_for(_garments.keys())
	for mi in _meshes:
		mi.set_instance_shader_parameter("cover", c)
		mi.set_instance_shader_parameter("cover_range", Garments.BODY_RANGE)


## Sin sombra propia (personal de banda en el móvil: se ahorra la pasada de sombras).
## Incluye el pelo y las prendas que se pongan después.
func set_casts_shadow(on: bool) -> void:
	_casts_shadow = on
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for gi: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = mode


func garment_ids() -> Array:
	return _garment_ids.duplicate()


## Copia el aspecto de otro avatar (colores, equipación, peinado y tamaño): para sacar a
## los mismos jugadores fuera del campo, como en el vestuario.
func copy_look(other: PlayerAvatar) -> void:
	for u: Dictionary in _mat.shader.get_shader_uniform_list():
		var n: String = u.name
		if n == "blink_seed":
			continue
		var v: Variant = other._mat.get_shader_parameter(n)
		if v != null:
			_mat.set_shader_parameter(n, v)
			_mat_fade.set_shader_parameter(n, v)
	_hair_mat.albedo_color = other._hair_mat.albedo_color
	set_hair_style(other._hair_style)
	_long_sleeves = other._long_sleeves
	_long_pants = other._long_pants
	set_garments(other._garment_ids)
	scale = Vector3(absf(other.scale.x), other.scale.y, other.scale.z)


## Peinado 3D (HairBuilder) pegado al hueso de la cabeza; "" o un peinado pintado lo quita.
func set_hair_style(id: String) -> void:
	if _hair_style == id:
		return
	_hair_style = id
	if _hair_node:
		_hair_node.queue_free()
		_hair_node = null
	var mesh := HairBuilder.mesh_for(id, self)
	var head := ItemCatalog.find_bone(skeleton, "Head")
	if mesh == null or head < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = skeleton.get_bone_name(head)
	skeleton.add_child(att)
	# La malla está en espacio del avatar en reposo: deshacer la posición de reposo del hueso
	var holder := Node3D.new()
	var bone_rest := HairBuilder.relative_transform(skeleton, self) * skeleton.get_bone_global_rest(head)
	holder.transform = bone_rest.affine_inverse()
	att.add_child(holder)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _hair_mat
	holder.add_child(mi)
	_hair_node = att


## Sentados (animaciones de Mixamo "sit*"): a qué altura queda la parte de abajo de
## los muslos con escala 1. Los asientos van a esa altura y cada jugador se sube o
## baja según su estatura; si no, los muslos se hundían en el asiento.
const SIT_SEAT_H := 0.37
## Las de sentado en una silla normal ("sit_2" es encaramado, con las piernas en alto).
const SIT_ANIMS := ["sit", "sit_3", "sit_talk"]


## Altura del avatar para que se siente justo encima de un asiento a `seat_top`.
func sit_offset(seat_top: float) -> float:
	return seat_top - SIT_SEAT_H * absf(scale.y)


func set_body_scale(s: Vector3) -> void:
	scale = Vector3(s.x * (-1.0 if _mirrored else 1.0), s.y, s.z)


var _mirrored := false
var _hands := Vector2i(-1, -1)


## Modelo en espejo (izquierda <-> derecha): una estirada sirve para los dos lados.
func set_mirrored(value: bool) -> void:
	if value == _mirrored:
		return
	_mirrored = value
	scale.x = -scale.x
	_set_both("decal_flip", -1.0 if value else 1.0)


## Punto entre las dos manos en el mundo, según la pose actual de la animación.
func hands_position() -> Vector3:
	if _hands.x < 0:
		_hands = Vector2i(ItemCatalog.find_bone(skeleton, "LeftHand"), ItemCatalog.find_bone(skeleton, "RightHand"))
		if _hands.x < 0 or _hands.y < 0:
			return global_position + Vector3.UP
	var mid := (skeleton.get_bone_global_pose(_hands.x).origin + skeleton.get_bone_global_pose(_hands.y).origin) * 0.5
	var anim_hands := skeleton.global_transform * mid
	# Con los brazos puestos por código (ArmPose), las manos están donde las lleva el
	# IK: la pose del esqueleto fuera de su actualización es la de la animación, y el
	# trofeo acababa a la altura de la cadera, dentro del cuerpo.
	if _arm_pose != null and _arm_pose.influence > 0.01:
		var ik: Variant = _arm_pose.hands_center()
		if ik != null:
			return anim_hands.lerp(global_transform * (ik as Vector3), _arm_pose.influence)
	return anim_hands


func set_faded(value: bool) -> void:
	_faded = value
	for mi in _meshes:
		mi.material_override = _mat_fade if value else _mat
	for mi: MeshInstance3D in _garments.values():
		mi.material_override = _mat_fade if value else _mat
	_hair_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if value else BaseMaterial3D.TRANSPARENCY_DISABLED
	_hair_mat.albedo_color.a = 0.25 if value else 1.0


## Pega una pieza 3D (GLB) a un hueso, en su ranura (quita la que hubiera). "" = nada.
func attach(slot: String, model_path: String, bone_name: String) -> void:
	if _items.has(slot):
		for n: Node in _items[slot]:
			n.queue_free()
		_items.erase(slot)
	if model_path == "" or not ResourceLoader.exists(model_path):
		return
	var bone := ItemCatalog.find_bone(skeleton, bone_name)
	if bone < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = skeleton.get_bone_name(bone)
	skeleton.add_child(att)
	att.add_child((load(model_path) as PackedScene).instantiate())
	_items[slot] = [att]


func apply_profile(p: PlayerProfile) -> void:
	set_colors(p.colors())
	set_body_scale(p.body_scale())
	set_hair_style(p.hair_style)
	set_accessories({"acc_head": p.headband} if p.headband != "" else {})


## Estampados de la camiseta (KitDecals): escudo, patrocinio, dorsal y apellido.
func set_decals(tex: Texture2D) -> void:
	_set_both("kit_decals", tex)
	_set_both("use_decals", tex != null)


func _set_both(key: String, value: Variant) -> void:
	_mat.set_shader_parameter(key, value)
	_mat_fade.set_shader_parameter(key, value)


## Brazos por código encima de la animación (ArmPose): "lift", "board", "flag", "card",
## "hold". "" los suelta. Entra y sale con un fundido de `fade` segundos.
func pose_arms(mode: String, fade := 0.35) -> void:
	if _arm_pose == null:
		if mode == "":
			return
		_arm_pose = ArmPose.new()
		_arm_pose.body = self
		_arm_pose.influence = 0.0
		skeleton.add_child(_arm_pose)
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween()
	if mode == "":
		_arm_tween.tween_property(_arm_pose, "influence", 0.0, fade)
		return
	if _arm_pose.mode != mode or _arm_pose.influence < 0.05:
		_arm_pose.t = 0.0
	_arm_pose.mode = mode
	_arm_tween.tween_property(_arm_pose, "influence", 1.0, fade).set_trans(Tween.TRANS_SINE)



## Pies pegados al suelo cuando está parado o casi (FootLock); false los suelta
## (la locomoción ya mueve los pies). Solo lo usan los jugadores del partido.
var _foot_lock: FootLock


func lock_feet(on: bool) -> void:
	if _foot_lock == null:
		if not on:
			return
		_foot_lock = FootLock.new()
		_foot_lock.body = self
		skeleton.add_child(_foot_lock)
	_foot_lock.want = on


# ---------- mirada ----------

var _look: HeadLook

## La cabeza (y algo el cuello) gira hacia `point` (global) por encima de la animación.
## weight 0 la suelta poco a poco (acciones, celebraciones).
func look_at_point(point: Vector3, weight := 1.0) -> void:
	if _look == null:
		if weight <= 0.0:
			return
		_look = HeadLook.new()
		_look.body = self
		skeleton.add_child(_look)
	_look.target = point
	_look.want = weight


## Giro de cabeza y cuello hacia un punto, suavizado y con límites naturales.
class HeadLook extends SkeletonModifier3D:
	var body: Node3D
	var target := Vector3.ZERO
	var want := 1.0
	var _w := 0.0
	var _yaw := 0.0
	var _pitch := 0.0
	var _neck := -1
	var _head := -1

	func _process_modification_with_delta(delta: float) -> void:
		var sk := get_skeleton()
		if sk == null or not is_instance_valid(body):
			return
		if _head < 0:
			_neck = ItemCatalog.find_bone(sk, "Neck")
			_head = ItemCatalog.find_bone(sk, "Head")
			if _neck < 0 or _head < 0:
				return
		_w = move_toward(_w, want, delta * 2.5)
		var m := body.global_transform.affine_inverse() * sk.global_transform
		var head_body := m * sk.get_bone_global_pose(_head).origin
		var dir := body.global_transform.affine_inverse() * target - head_body
		var flat := Vector2(dir.x, dir.z).length()
		var yaw := 0.0
		var pitch := 0.0
		if flat > 0.3:
			yaw = atan2(dir.x, dir.z)
			if absf(yaw) > 2.2:
				yaw = 0.0 # detrás: no se retuerce, mira al frente
			yaw = clampf(yaw, -0.85, 0.85)
			pitch = clampf(atan2(-dir.y, flat), -0.25, 0.4)
		var k := minf(1.0, delta * 6.0)
		_yaw = lerpf(_yaw, yaw * _w, k)
		_pitch = lerpf(_pitch, pitch * _w, k)
		if absf(_yaw) + absf(_pitch) < 0.002:
			return
		var mb := m.basis
		var inv := mb.inverse()
		# Cuello 40 %, cabeza 60 %
		var ng := sk.get_bone_global_pose(_neck)
		var r1 := inv * Basis(Vector3.UP, _yaw * 0.4) * Basis(Vector3.RIGHT, _pitch * 0.4) * mb
		var new_ng := Transform3D(r1 * ng.basis, ng.origin)
		_set_rot(sk, _neck, new_ng)
		var hg := new_ng * sk.get_bone_pose(_head)
		var r2 := inv * Basis(Vector3.UP, _yaw * 0.6) * Basis(Vector3.RIGHT, _pitch * 0.6) * mb
		_set_rot(sk, _head, Transform3D(r2 * hg.basis, hg.origin))

	func _set_rot(sk: Skeleton3D, bone: int, global: Transform3D) -> void:
		var parent := sk.get_bone_parent(bone)
		var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
		sk.set_bone_pose_rotation(bone, (pg.affine_inverse() * global).basis.get_rotation_quaternion())


# ---------- accesorios de la tienda (FootballCareer) ----------

## Accesorios con piezas sencillas pegadas a los huesos, siguiendo la cabeza / el cuello /
## la muñeca. acc = {"acc_head": "gorra"|"cinta"|"gorro_lana"|"boina",
## "acc_eyes": "lentes_sol"|"aviador"|"lentes_redondos",
## "acc_neck": "cadena_fina"|"cadena_gruesa"|"auriculares"|"bufanda", "acc_ears": "pendientes", "acc_wrist": "reloj"}
func set_accessories(acc: Dictionary) -> void:
	for slot: String in ["acc_head", "acc_eyes", "acc_neck", "acc_ears", "acc_wrist"]:
		if _items.has(slot):
			for n: Node in _items[slot]:
				n.queue_free()
			_items.erase(slot)
		var id := String(acc.get(slot, ""))
		if id == "":
			continue
		# Gorras, gorros y cadenas: modelados sobre el cuerpo (Hats), no piezas sueltas
		if slot in ["acc_head", "acc_neck"] and Hats.has(id):
			_items[slot] = Hats.make(id, skeleton)
			continue
		var bone := "LeftHand" if slot == "acc_wrist" else ("Neck" if slot == "acc_neck" else "Head")
		var holder := _holder(bone)
		if holder == null:
			continue
		_items[slot] = [holder.get_parent()]
		_build_accessory(holder, id)


## Nodo pegado al hueso con los ejes del jugador (+Y arriba, +Z delante) y en metros,
## con el origen en el hueso: lo que cuelgue de él sigue al hueso al animarse.
func _holder(bone_name: String) -> Node3D:
	var bone := ItemCatalog.find_bone(skeleton, bone_name)
	if bone < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = skeleton.get_bone_name(bone)
	skeleton.add_child(att)
	# Esqueleto -> jugador sin depender del árbol (puede que aún no esté dentro)
	var m := skeleton.transform
	var p := skeleton.get_parent()
	while p != null and p != self and p is Node3D:
		m = (p as Node3D).transform * m
		p = p.get_parent()
	var bone_in_body := m * skeleton.get_bone_global_rest(bone)
	var holder := Node3D.new()
	holder.transform = bone_in_body.affine_inverse() * Transform3D(Basis.IDENTITY, bone_in_body.origin)
	att.add_child(holder)
	return holder


func _acc_mat(c: Color, metal := 0.0, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _acc_mesh(holder: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	holder.add_child(mi)


## Visera curva de gorra: media corona de radio interior `r0` y `depth` de vuelo,
## con algo de caída hacia el borde (de frente se ve la curva, no una tabla).
func _visor_mesh(r0: float, depth: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	var pts: Array = []
	for i in n + 1:
		var a := lerpf(-1.15, 1.15, float(i) / n)
		var inner := Vector3(sin(a) * r0, 0.0, cos(a) * r0)
		var reach := depth * (1.0 - 0.55 * absf(a) / 1.15)
		var outer := Vector3(sin(a) * (r0 + reach * 0.35), -0.035 * (1.0 - absf(a) / 1.6), cos(a) * (r0 + reach))
		pts.append([inner, outer])
	for i in n:
		var p0: Array = pts[i]
		var p1: Array = pts[i + 1]
		for v: Vector3 in [p0[0], p1[0], p1[1], p0[0], p1[1], p0[1]]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## Patilla de gafas: del borde del cristal (x = `from_x`, delante) a la oreja.
func _temple(h: Node3D, sx: float, y: float, from_x: float, m: Material, t: float) -> void:
	# Medido en la malla: a la altura de los ojos la cabeza mide ~0.19 de ancho por lado
	# y la oreja queda cerca de z = 0 (las patillas antes acababan en el aire)
	var a := Vector3(sx * from_x, y, HEAD_C.z + HEAD_R * 0.95)
	var b := Vector3(sx * 0.188, y + 0.004, -0.005)
	var bar := BoxMesh.new()
	bar.size = Vector3(t, t, a.distance_to(b))
	var mi := MeshInstance3D.new()
	mi.mesh = bar
	mi.material_override = m
	h.add_child(mi)
	mi.position = (a + b) * 0.5
	mi.basis = Basis.looking_at(b - a, Vector3.UP)


func _build_accessory(h: Node3D, id: String) -> void:
	var gold := _acc_mat(Color(1.0, 0.78, 0.3), 1.0, 0.25)
	match id:
		"gorra":
			# Gorra: copa ajustada a la cabeza (algo aplanada) y visera curva de verdad
			var col := Color(0.08, 0.08, 0.1)
			var cap := SphereMesh.new()
			cap.radius = HEAD_R * 1.07
			cap.height = HEAD_R * 1.07
			cap.is_hemisphere = true
			_acc_mesh(h, cap, Vector3(0, HEAD_C.y + HEAD_R * 0.2, HEAD_C.z - 0.005), _acc_mat(col, 0.0, 0.85), Vector3(-0.12, 0, 0), Vector3(1.0, 0.92, 1.04))
			var vm := _acc_mat(col.lightened(0.05), 0.0, 0.8)
			vm.cull_mode = BaseMaterial3D.CULL_DISABLED
			_acc_mesh(h, _visor_mesh(HEAD_R * 1.0, HEAD_R * 1.0), Vector3(0, HEAD_C.y + HEAD_R * 0.32, HEAD_C.z + 0.01), vm, Vector3(0.22, 0, 0))
			var button := SphereMesh.new()
			button.radius = 0.014
			button.height = 0.014
			_acc_mesh(h, button, Vector3(0, HEAD_C.y + HEAD_R * 1.12, HEAD_C.z - 0.03), _acc_mat(col))
		"gorro_lana":
			var wool0 := _acc_mat(Color(0.75, 0.15, 0.18), 0.0, 1.0)
			var beanie := SphereMesh.new()
			beanie.radius = HEAD_R * 1.08
			beanie.height = HEAD_R * 1.3
			beanie.is_hemisphere = true
			_acc_mesh(h, beanie, Vector3(0, HEAD_C.y + HEAD_R * 0.18, HEAD_C.z - 0.01), wool0, Vector3(-0.1, 0, 0))
			# Vuelta doblada en el borde y pompón
			var cuff := TorusMesh.new()
			cuff.inner_radius = HEAD_R * 1.0
			cuff.outer_radius = HEAD_R * 1.14
			_acc_mesh(h, cuff, Vector3(0, HEAD_C.y + HEAD_R * 0.25, HEAD_C.z - 0.01), _acc_mat(Color(0.68, 0.12, 0.15), 0.0, 1.0), Vector3(-0.1, 0, 0), Vector3(1.0, 0.9, 1.0))
			var pom := SphereMesh.new()
			pom.radius = HEAD_R * 0.3
			pom.height = HEAD_R * 0.6
			_acc_mesh(h, pom, Vector3(0, HEAD_C.y + HEAD_R * 1.45, HEAD_C.z - 0.05), _acc_mat(Color(0.95, 0.95, 0.95), 0.0, 1.0))
		"cinta":
			var band := TorusMesh.new()
			band.inner_radius = 0.192
			band.outer_radius = 0.212
			_acc_mesh(h, band, Vector3(0, HEAD_C.y + HEAD_R * 0.22, HEAD_C.z), _acc_mat(Color(0.95, 0.95, 0.97)), Vector3(0.18, 0, 0), Vector3(1.0, 1.8, 1.0))
		"lentes_sol", "aviador":
			var lens := CylinderMesh.new()
			lens.top_radius = HEAD_R * (0.26 if id == "lentes_sol" else 0.3)
			lens.bottom_radius = lens.top_radius
			lens.height = 0.01
			var glass := _acc_mat(Color(0.05, 0.05, 0.07) if id == "lentes_sol" else Color(0.35, 0.22, 0.08), 0.6, 0.1)
			for sx: float in [-1.0, 1.0]:
				_acc_mesh(h, lens, Vector3(sx * HEAD_R * 0.36, EYE_Y, HEAD_C.z + HEAD_R * 1.0), glass, Vector3(PI * 0.5, 0, 0))
				# Patillas pegadas a la cabeza, del borde del cristal a la oreja
				_temple(h, sx, EYE_Y + 0.01, HEAD_R * 0.62, gold if id == "aviador" else glass, 0.008)
			var bridge := BoxMesh.new()
			bridge.size = Vector3(HEAD_R * 0.2, 0.01, 0.01)
			_acc_mesh(h, bridge, Vector3(0, EYE_Y + 0.012, HEAD_C.z + HEAD_R * 1.02), gold if id == "aviador" else glass)
		"cadena_fina", "cadena_gruesa":
			var ring := TorusMesh.new()
			var thick := 0.011 if id == "cadena_fina" else 0.02
			ring.inner_radius = 0.15
			ring.outer_radius = 0.15 + thick
			ring.rings = 48
			# Rodea el cuello (antes el aro estaba centrado 16 cm por delante y quedaba
			# como una sonrisa pintada en el pecho): atrás toca la nuca, delante cae
			# sobre el pecho por fuera de la camiseta, con el colgante al final
			_acc_mesh(h, ring, Vector3(0, 0.02, 0.012), gold, Vector3(0.47, 0, 0), Vector3(0.95, 1.0, 1.08))
			var tag := CylinderMesh.new()
			tag.top_radius = 0.018 if id == "cadena_fina" else 0.03
			tag.bottom_radius = tag.top_radius
			tag.height = 0.007
			var drop := 0.025 if id == "cadena_fina" else 0.035
			_acc_mesh(h, tag, Vector3(0, -0.052 - drop, 0.168), gold, Vector3(PI * 0.5 - 0.2, 0, 0))
		"auriculares":
			# Al cuello: diadema por detrás y las dos almohadillas sobre las clavículas
			var arc := TorusMesh.new()
			arc.inner_radius = 0.13
			arc.outer_radius = 0.155
			var dark := _acc_mat(Color(0.1, 0.1, 0.12), 0.2, 0.4)
			_acc_mesh(h, arc, Vector3(0, 0.04, 0.07), dark, Vector3(0.6, 0, 0), Vector3(1.05, 1.0, 1.0))
			var cup := CylinderMesh.new()
			cup.top_radius = 0.06
			cup.bottom_radius = 0.06
			cup.height = 0.045
			var pad := _acc_mat(Color(0.85, 0.85, 0.88), 0.3, 0.35)
			for sx: float in [-1.0, 1.0]:
				_acc_mesh(h, cup, Vector3(sx * 0.14, 0.0, 0.15), dark, Vector3(0.5, 0, PI * 0.5 - sx * 0.35))
				var cap2 := CylinderMesh.new()
				cap2.top_radius = 0.035
				cap2.bottom_radius = 0.035
				cap2.height = 0.01
				_acc_mesh(h, cap2, Vector3(sx * 0.168, -0.008, 0.16), pad, Vector3(0.5, 0, PI * 0.5 - sx * 0.35))
		"bufanda":
			# Vuelta de lana gruesa al cuello y una punta que cuelga por delante
			var wool := _acc_mat(Color(0.62, 0.12, 0.16), 0.0, 1.0)
			var loop := TorusMesh.new()
			# Por fuera del cuello (radio ~0.135, centro algo atrás del hueso): antes el aro
			# iba adelantado, se metía en la nuca y la punta quedaba dentro de la camiseta
			loop.inner_radius = 0.14
			loop.outer_radius = 0.235
			loop.rings = 40
			_acc_mesh(h, loop, Vector3(0, 0.035, 0.005), wool, Vector3(0.32, 0, 0), Vector3(1.0, 1.35, 1.0))
			var tail := BoxMesh.new()
			tail.size = Vector3(0.12, 0.3, 0.035)
			_acc_mesh(h, tail, Vector3(0.075, -0.19, 0.212), wool, Vector3(-0.1, 0, 0.06))
			var fringe := BoxMesh.new()
			fringe.size = Vector3(0.12, 0.03, 0.037)
			_acc_mesh(h, fringe, Vector3(0.084, -0.352, 0.228), _acc_mat(Color(0.95, 0.92, 0.85), 0.0, 1.0), Vector3(-0.1, 0, 0.06))
		"boina":
			# Boina de tweed: plana, ladeada hacia un lado, con el rabito arriba
			var tweed := _acc_mat(Color(0.36, 0.3, 0.22), 0.0, 1.0)
			var top := SphereMesh.new()
			top.radius = HEAD_R * 1.12
			top.height = HEAD_R * 0.7
			_acc_mesh(h, top, Vector3(-0.02, HEAD_C.y + HEAD_R * 0.62, HEAD_C.z - 0.01), tweed, Vector3(0.08, 0, 0.16), Vector3(1.0, 0.75, 1.0))
			var stem := CylinderMesh.new()
			stem.top_radius = 0.006
			stem.bottom_radius = 0.01
			stem.height = 0.03
			_acc_mesh(h, stem, Vector3(-0.05, HEAD_C.y + HEAD_R * 0.98, HEAD_C.z - 0.01), tweed, Vector3(0, 0, 0.16))
		"lentes_redondos":
			# Montura fina y redonda (aros), cristal claro
			var frame := _acc_mat(Color(0.12, 0.1, 0.08), 0.4, 0.35)
			var ring := TorusMesh.new()
			ring.inner_radius = HEAD_R * 0.2
			ring.outer_radius = HEAD_R * 0.245
			var glass2 := CylinderMesh.new()
			glass2.top_radius = HEAD_R * 0.21
			glass2.bottom_radius = glass2.top_radius
			glass2.height = 0.004
			var clear := _acc_mat(Color(0.75, 0.85, 0.9, 0.35), 0.2, 0.05)
			clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			for sx: float in [-1.0, 1.0]:
				_acc_mesh(h, ring, Vector3(sx * HEAD_R * 0.36, EYE_Y, HEAD_C.z + HEAD_R * 1.0), frame, Vector3(PI * 0.5, 0, 0))
				_acc_mesh(h, glass2, Vector3(sx * HEAD_R * 0.36, EYE_Y, HEAD_C.z + HEAD_R * 1.0), clear, Vector3(PI * 0.5, 0, 0))
				_temple(h, sx, EYE_Y + 0.01, HEAD_R * 0.58, frame, 0.006)
			var bridge2 := BoxMesh.new()
			bridge2.size = Vector3(HEAD_R * 0.24, 0.006, 0.006)
			_acc_mesh(h, bridge2, Vector3(0, EYE_Y + 0.01, HEAD_C.z + HEAD_R * 1.02), frame)
		"pendientes":
			var gem := SphereMesh.new()
			gem.radius = 0.012
			gem.height = 0.024
			for sx: float in [-1.0, 1.0]:
				_acc_mesh(h, gem, Vector3(sx * 0.188, EYE_Y - 0.06, HEAD_C.z - 0.02), _acc_mat(Color(0.85, 0.95, 1.0), 0.3, 0.05))
		"reloj":
			# En reposo el brazo va a lo largo de X y el dorso de la mano mira a +Y. La
			# muñeca de la malla es un óvalo de ~9 cm de alto y ~13 de ancho: la correa
			# lo rodea y la esfera va encima del dorso (antes quedaba dentro del brazo)
			var strap := TorusMesh.new()
			strap.inner_radius = 0.057
			strap.outer_radius = 0.064
			_acc_mesh(h, strap, Vector3(-0.05, 0.004, -0.012), _acc_mat(Color(0.12, 0.1, 0.09), 0.2, 0.5), Vector3(0, 0, PI * 0.5), Vector3(1.0, 2.4, 1.25))
			var face := CylinderMesh.new()
			face.top_radius = 0.019
			face.bottom_radius = 0.021
			face.height = 0.009
			_acc_mesh(h, face, Vector3(-0.05, 0.069, -0.012), gold)
			var dial := CylinderMesh.new()
			dial.top_radius = 0.016
			dial.bottom_radius = 0.016
			dial.height = 0.002
			_acc_mesh(h, dial, Vector3(-0.05, 0.0742, -0.012), _acc_mat(Color(0.06, 0.07, 0.1), 0.4, 0.15))
