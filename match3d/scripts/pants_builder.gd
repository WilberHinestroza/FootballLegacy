class_name PantsBuilder
extends RefCounted
## Pantalón largo de verdad (técnicos, árbitros de traje, fotógrafos, presentadores):
## la malla del jugador trae la pantaloneta modelada (con el borde abierto en el muslo),
## así que pintarla no basta. Se le pone encima un tubo por pierna, con piel (skin)
## sobre cadera, muslo, pierna y pie: se dobla en la rodilla con la animación.
## La pantaloneta queda dentro, tapada.

const RINGS := 18
const SIDES := 14


## Color del tejido: un negro puro se ve como una mancha plana; se aclara un poco.
static func tone(c: Color) -> Color:
	return c.lerp(Color(0.24, 0.24, 0.27), 0.18)


## Crea el pantalón como hijo del esqueleto. Devuelve el MeshInstance3D (o null).
static func build(skel: Skeleton3D, color: Color) -> MeshInstance3D:
	var names := ["Hips", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]
	var ids: Array[int] = []
	for n: String in names:
		var b := ItemCatalog.find_bone(skel, n)
		if b < 0:
			return null
		ids.append(b)
	var skin := Skin.new()
	for b in ids:
		skin.add_named_bind(skel.get_bone_name(b), skel.get_bone_global_rest(b).affine_inverse())
	var hips_pos := skel.get_bone_global_rest(ids[0]).origin
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var idx := PackedInt32Array()
	for side in 2:
		var o := side * 3 # índice de bind: muslo, pierna, pie
		var hip := skel.get_bone_global_rest(ids[1 + o]).origin
		var knee := skel.get_bone_global_rest(ids[2 + o]).origin
		var ankle := skel.get_bone_global_rest(ids[3 + o]).origin
		var thigh := hip.distance_to(knee)
		var shin := knee.distance_to(ankle)
		# Arriba empieza algo por encima de la articulación (cintura) y abajo cae sobre el zapato
		var up_dir := (hip - knee).normalized()
		var top := hip + up_dir * thigh * 0.22
		var bottom := ankle + (ankle - knee).normalized() * shin * 0.06
		# Hacia fuera del cuerpo (para no meter el tubo en la otra pierna)
		var leg_axis := (ankle - hip).normalized()
		var outward := hip - hips_pos
		outward = (outward - leg_axis * outward.dot(leg_axis)).normalized()
		var base := verts.size()
		for r in RINGS + 1:
			var u := float(r) / float(RINGS)
			# Recorre top -> rodilla (40 %) -> bajo
			var c: Vector3
			var axis: Vector3
			if u < 0.42:
				var k := u / 0.42
				c = top.lerp(knee, k)
				axis = (knee - top).normalized()
			else:
				var k2 := (u - 0.42) / 0.58
				c = knee.lerp(bottom, k2)
				axis = (bottom - knee).normalized()
			# Radio: ancho arriba, recto de rodilla abajo, con un poco de vuelo en el bajo
			var rad := thigh * lerpf(0.54, 0.4, smoothstep(0.0, 0.42, u))
			rad = lerpf(rad, thigh * 0.37, smoothstep(0.42, 0.9, u))
			rad += thigh * 0.04 * smoothstep(0.9, 1.0, u)
			# Pesos: cadera arriba, muslo, mezcla en la rodilla, pierna, pie en el bajo
			var w := {}
			if u < 0.1:
				var hw := 0.4 + (1.0 - u / 0.1) * 0.4
				w = {0: hw, 1 + o: 1.0 - hw}
			elif u < 0.34:
				w = {1 + o: 1.0}
			elif u < 0.5:
				var m := smoothstep(0.34, 0.5, u)
				w = {1 + o: 1.0 - m, 2 + o: m}
			elif u < 0.93:
				w = {2 + o: 1.0}
			else:
				var m2 := smoothstep(0.93, 1.0, u) * 0.5
				w = {2 + o: 1.0 - m2, 3 + o: m2}
			var side_v := axis.cross(Vector3(0, 0, 1))
			if side_v.length() < 0.1:
				side_v = axis.cross(Vector3(1, 0, 0))
			side_v = side_v.normalized()
			var fwd_v := side_v.cross(axis).normalized()
			for s in SIDES:
				var a := TAU * float(s) / float(SIDES)
				var n := side_v * cos(a) + fwd_v * sin(a)
				var p := c + n * rad
				# Arriba, que no se cruce con la otra pernera en la entrepierna
				if u < 0.25 and n.dot(outward) < 0.0:
					p -= n * rad * 0.45 * (1.0 - u / 0.25)
				verts.append(p)
				normals.append(n)
				var keys := w.keys()
				for j in 4:
					if j < keys.size():
						bones.append(int(keys[j]))
						weights.append(float(w[keys[j]]))
					else:
						bones.append(0)
						weights.append(0.0)
		for r in RINGS:
			for s in SIDES:
				var a0 := base + r * SIDES + s
				var a1 := base + r * SIDES + (s + 1) % SIDES
				var b0 := a0 + SIDES
				var b1 := a1 + SIDES
				idx.append_array([a0, b0, a1, a1, b0, b1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Pants"
	mi.mesh = mesh
	mi.skin = skin
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tone(color)
	mat.roughness = 0.72
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED # se ve por dentro por el bajo
	mat.rim_enabled = true
	mat.rim = 0.15
	mi.material_override = mat
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	return mi
