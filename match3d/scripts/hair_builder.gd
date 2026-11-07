class_name HairBuilder
extends RefCounted
## Peinados 3D hechos por código, ajustados a la forma real de la cabeza del modelo.
## Mide la cabeza una vez (vértices con peso de cabeza, ver tools/build_player_glb.py),
## crea un "casco" de pelo que la recubre y le añade volúmenes según el estilo
## (tupé, cresta, moño, rastas…). Todo en el espacio del avatar en reposo;
## PlayerAvatar lo pega al hueso Head. Las mallas se guardan en caché por estilo.

const STYLES_3D := [
	"tupe", "rulos", "melena", "cresta", "largo", "mono", "trenzas", "rastas", "engominado",
	"afro", "flequillo", "coleta", "puntas", "rizos_largos", "raya",
]
const NOSE_F := 0.8335 # altura de la nariz (fracción), como en el shader

static var _head := {}   # center, radius, points (espacio del esqueleto)
static var _meshes := {} # estilo -> ArrayMesh

var _st: SurfaceTool
var _c: Vector3   # centro del cráneo
var _R: float     # radio medio de la cabeza
var _pts: PackedVector3Array


static func has_style(id: String) -> bool:
	return id in STYLES_3D


## Malla del peinado (en espacio del esqueleto), o null si no es un peinado 3D.
static func mesh_for(id: String, avatar: PlayerAvatar) -> ArrayMesh:
	if not has_style(id):
		return null
	if not _meshes.has(id):
		if _head.is_empty():
			_measure_head(avatar)
		if _head.is_empty():
			return null
		var b := HairBuilder.new()
		_meshes[id] = b._build(id)
	return _meshes[id]


## Transformación de `node` relativa a su antepasado `top` (sin depender del árbol de escena).
static func relative_transform(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != top:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## Puntos de la cabeza (peso de cabeza alto y por encima de la nariz) en espacio del avatar
## (Y arriba, Z adelante, metros). El esqueleto importado usa otro (centímetros, girado).
static func _measure_head(avatar: PlayerAvatar) -> void:
	var pts := PackedVector3Array()
	for mi: MeshInstance3D in avatar.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.get_parent() is BoneAttachment3D or mi.get_parent().get_parent() is BoneAttachment3D:
			continue
		# Malla con piel: sus vértices ya están en el espacio del modelo (el de las bind poses)
		var xf := Transform3D.IDENTITY
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var cols = arr[Mesh.ARRAY_COLOR]
			var uvs = arr[Mesh.ARRAY_TEX_UV]
			if cols == null or uvs == null:
				continue
			for i in verts.size():
				if cols[i].g > 0.85 and uvs[i].y > NOSE_F - 0.01:
					pts.append(xf * verts[i])
	if pts.size() < 20:
		push_warning("HairBuilder: no se encontró la cabeza en la malla")
		return
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var r := 0.0
	for p in pts:
		r += p.distance_to(c)
	_head = {"center": c, "radius": r / pts.size(), "points": pts}


# ---------- construcción ----------

func _build(id: String) -> ArrayMesh:
	_c = _head.center
	_R = _head.radius
	_pts = _head.points
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match id:
		"tupe":
			_cap(func(d: Vector3) -> float: return 0.07 + 0.42 * _bump(d, Vector3(0, 0.75, 0.66), 0.55))
		"engominado":
			_cap(func(d: Vector3) -> float: return 0.1 + 0.12 * maxf(-d.z, 0.0))
		"raya":
			_cap(func(d: Vector3) -> float: return 0.13 - 0.1 * _bump(d, Vector3(0.42, 0.9, 0.1), 0.22) + 0.05 * maxf(-d.x, 0.0))
		"afro":
			# Bola redonda de rizos: volumen que crece hacia arriba y atrás, menos en la frente,
			# y bultos encima para que no parezca un casco liso
			_cap(func(d: Vector3) -> float: return 0.18 + 0.14 * clampf(d.y, 0.0, 1.0) + 0.06 * maxf(-d.z, 0.0), 1.08)
			for d in _spread_dirs(46, -0.2):
				var front := maxf(d.z, 0.0) * (1.0 - clampf(d.y, 0.0, 1.0))
				_sphere(_scalp(d, 0.2 + 0.12 * clampf(d.y, 0.0, 1.0) - 0.15 * front), _R * 0.25, 1)
		"cresta":
			# Base muy pegada (el shader pinta la franja) y una fila de picos de la frente a la nuca
			_cap(func(_d: Vector3) -> float: return 0.0, 1.0, 0.2)
			for i in 9:
				var a := deg_to_rad(lerpf(45.0, -100.0, i / 8.0)) # ángulo desde arriba hacia la frente
				var d := Vector3(0.0, cos(a), sin(a))
				var h := _R * (0.6 - 0.3 * absf(i - 3.0) / 5.0)
				_cone(_scalp(d, 0.0), d.slerp(Vector3.UP, 0.3).normalized() * h, _R * 0.17, 4, 0.3)
		"puntas":
			_cap(func(_d: Vector3) -> float: return 0.06)
			for d in _spread_dirs(16, 0.25):
				_cone(_scalp(d, 0.03), d.slerp(Vector3.UP, 0.3).normalized() * _R * 0.38, _R * 0.13, 4, 0.0)
		"rulos":
			_cap(func(_d: Vector3) -> float: return 0.05)
			for d in _spread_dirs(34, -0.05):
				_sphere(_scalp(d, 0.1), _R * 0.17, 1)
		"mono":
			_cap(func(d: Vector3) -> float: return 0.08 + 0.06 * maxf(-d.z, 0.0))
			_sphere(_scalp(Vector3(0, 0.8, -0.6).normalized(), 0.25), _R * 0.36, 2)
		"coleta":
			_cap(func(d: Vector3) -> float: return 0.08 + 0.06 * maxf(-d.z, 0.0))
			var root := _scalp(Vector3(0, 0.45, -0.9).normalized(), 0.05)
			_tube([root, root + Vector3(0, -0.2, -0.45) * _R, root + Vector3(0, -0.9, -0.55) * _R,
				root + Vector3(0, -1.7, -0.45) * _R], [_R * 0.26, _R * 0.32, _R * 0.24, _R * 0.06], 6)
			_sphere(root, _R * 0.2, 1) # la goma
		"flequillo":
			_cap(func(d: Vector3) -> float: return 0.12 + 0.08 * maxf(d.z, 0.0))
			_curtain(-70.0, 70.0, 0.32, 0.12, 0.16)
		"melena":
			_cap(func(d: Vector3) -> float: return 0.09 + 0.06 * clampf(d.y, 0.0, 1.0))
			_curtain(55.0, 305.0, 0.95, 0.1, 0.14, 0.3, 0.1)
			_locks(0.8)
		"largo":
			_cap(func(d: Vector3) -> float: return 0.08 + 0.05 * clampf(d.y, 0.0, 1.0))
			_curtain(60.0, 300.0, 2.1, 0.06, 0.16, 0.25, 0.12)
			_locks(1.6)
		"rizos_largos":
			_cap(func(_d: Vector3) -> float: return 0.1)
			_curtain(60.0, 300.0, 1.35, 0.14, 0.2, 0.15, 0.08)
			for i in 26:
				var th := deg_to_rad(lerpf(65.0, 295.0, i / 25.0))
				var out := Vector3(sin(th), 0, cos(th))
				_sphere(_edge(th) + Vector3.DOWN * _R * (0.6 + 0.7 * fmod(i * 0.37, 1.0)) + out * _R * 0.22, _R * 0.2, 1)
			for d in _spread_dirs(18, 0.1):
				_sphere(_scalp(d, 0.12), _R * 0.16, 1)
		"trenzas":
			_cap(func(_d: Vector3) -> float: return 0.05)
			for side: float in [-1.0, 1.0]:
				var start := _edge(deg_to_rad(180.0 - side * 55.0))
				for k in 8:
					_sphere(start + Vector3(side * 0.06 * k, -0.27 * k, -0.05 * k) * _R, _R * (0.2 - 0.01 * k), 1)
		"rastas":
			# Casco con raíces abultadas y rastas gruesas que cuelgan (salen un poco y caen)
			_cap(func(_d: Vector3) -> float: return 0.1)
			for d in _spread_dirs(16, 0.2):
				_sphere(_scalp(d, 0.1), _R * 0.13, 1)
			for i in 26:
				var th := deg_to_rad(lerpf(48.0, 312.0, i / 25.0))
				var out := Vector3(sin(th), 0, cos(th))
				var e := _edge(th) + out * _R * 0.04
				var l := _R * (0.9 + 0.45 * fmod(i * 0.61, 1.0))
				var mid := e + out * _R * 0.14 + Vector3.DOWN * l * 0.45
				var tip := e + out * _R * 0.2 + Vector3.DOWN * l
				_tube([e, mid, tip], [_R * 0.12, _R * 0.11, _R * 0.08], 5)
	# Sombreado suave: se juntan los vértices repetidos y las normales se promedian
	# (antes cada triángulo tenía la suya y el pelo se veía facetado, de cartón)
	_st.index()
	_st.generate_normals()
	return _st.commit()


## Distancia del centro a la superficie de la cabeza en la dirección d (máxima proyección
## de sus vértices dentro de un cono alrededor de d).
func _surface(d: Vector3) -> float:
	var best := 0.0
	var cos_lim := cos(deg_to_rad(20.0))
	for p in _pts:
		var v := p - _c
		var l := v.length()
		if l > 0.0001 and v.dot(d) / l > cos_lim:
			best = maxf(best, v.dot(d))
	return best if best > 0.0 else _R


func _scalp(d: Vector3, extra: float) -> Vector3:
	return _c + d * (_surface(d) * 1.03 + _R * extra)


## Límite del pelo en grados desde la coronilla: alto en la frente, bajo en la nuca.
func _hairline(theta: float) -> float:
	return lerpf(60.0, 112.0, (1.0 - cos(theta)) * 0.5)


## theta: 0 = frente (+Z), alrededor del eje vertical; phi: grados desde arriba.
func _dir(theta: float, phi_deg: float) -> Vector3:
	var phi := deg_to_rad(phi_deg)
	return Vector3(sin(phi) * sin(theta), cos(phi), sin(phi) * cos(theta))


func _edge(theta: float) -> Vector3:
	return _scalp(_dir(theta, _hairline(theta)), 0.04)


func _bump(d: Vector3, center: Vector3, width: float) -> float:
	return exp(-pow(d.angle_to(center.normalized()) / width, 2.0))


## Casco de pelo sobre el cuero cabelludo. vol(d) = volumen extra (en radios); en el borde
## baja hasta la piel. edge_scale agranda la zona cubierta; width_limit la estrecha (cresta).
func _cap(vol: Callable, edge_scale := 1.0, width_limit := 0.0) -> void:
	var lon := 36
	var lat := 13
	var grid := []
	for j in lat + 1:
		var row := []
		for i in lon:
			var th := TAU * i / lon
			var t := float(j) / lat
			var d := _dir(th, _hairline(th) * edge_scale * t)
			if width_limit > 0.0 and absf(d.x) > width_limit:
				d.x = signf(d.x) * width_limit
				d = d.normalized()
			var fall := smoothstep(1.0, 0.75, t)
			row.append(_c + d * (_surface(d) * 1.03 + _R * (0.02 + float(vol.call(d)) * fall)))
		grid.append(row)
	for j in lat:
		for i in lon:
			var i2 := (i + 1) % lon
			_quad(grid[j][i], grid[j][i2], grid[j + 1][i2], grid[j + 1][i], _c)


## Cortina de pelo que cae desde el borde (de a0 a a1 grados alrededor), largo en radios.
## jag = puntas desiguales (mechones), bulge = abombado a media altura (no cae como una pared).
func _curtain(a0: float, a1: float, length: float, flare: float, thick: float, jag := 0.0, bulge := 0.0) -> void:
	var n := 40
	var rows := 9
	var g := []
	for k in rows + 1:
		var row := []
		for i in n + 1:
			var th := deg_to_rad(lerpf(a0, a1, float(i) / n))
			var out := Vector3(sin(th), 0.0, cos(th))
			var s := float(k) / rows
			# Mechones: columnas alternas más cortas, con algo de azar fijo
			var len_i := length * (1.0 - jag * (0.55 * float(i % 2) + 0.45 * fmod(i * 0.618, 1.0)))
			# Empieza un poco por encima del borde del casco para que no quede hueco
			var top := _scalp(_dir(th, _hairline(th) - 14.0), 0.1)
			var push := flare * s + thick * 0.5 + bulge * sin(s * PI) * (1.0 - s * 0.5)
			row.append(top + Vector3.DOWN * _R * (len_i + 0.15) * s + out * _R * push)
		g.append(row)
	for k in rows:
		for i in n:
			_quad(g[k][i], g[k][i + 1], g[k + 1][i + 1], g[k + 1][i], _c + Vector3.DOWN * _R * length * 0.5)


## Dos mechones delante de las orejas que enmarcan la cara (pelo largo).
func _locks(length: float) -> void:
	for side: float in [-1.0, 1.0]:
		var th := deg_to_rad(side * 62.0)
		var out := Vector3(sin(th), 0.0, cos(th))
		var e := _scalp(_dir(th, _hairline(th) - 6.0), 0.08)
		var mid := e + out * _R * 0.08 + Vector3.DOWN * _R * length * 0.5
		var tip := e + out * _R * 0.04 + Vector3.DOWN * _R * length
		_tube([e, mid, tip], [_R * 0.16, _R * 0.13, _R * 0.05], 5)


func _basis(axis: Vector3) -> Array:
	var a := axis.normalized()
	var u := a.cross(Vector3.FORWARD if absf(a.z) < 0.9 else Vector3.RIGHT).normalized()
	return [u, a.cross(u).normalized()]


func _cone(base: Vector3, axis: Vector3, radius: float, sides: int, tip_frac: float) -> void:
	var tip := base + axis
	var uv := _basis(axis)
	for i in sides:
		var r0: Vector3 = uv[0] * cos(TAU * i / sides) + uv[1] * sin(TAU * i / sides)
		var r1: Vector3 = uv[0] * cos(TAU * (i + 1) / sides) + uv[1] * sin(TAU * (i + 1) / sides)
		if tip_frac > 0.0:
			_quad(base + r0 * radius, base + r1 * radius, tip + r1 * radius * tip_frac, tip + r0 * radius * tip_frac, base + axis * 0.5)
		else:
			_tri(base + r0 * radius, base + r1 * radius, tip, base + axis * 0.3)


func _tube(path: Array, radii: Array, sides: int) -> void:
	for k in path.size() - 1:
		var a: Vector3 = path[k]
		var b: Vector3 = path[k + 1]
		var uv := _basis(b - a)
		var ra: float = radii[k]
		var rb: float = radii[k + 1]
		for i in sides:
			var r0: Vector3 = uv[0] * cos(TAU * i / sides) + uv[1] * sin(TAU * i / sides)
			var r1: Vector3 = uv[0] * cos(TAU * (i + 1) / sides) + uv[1] * sin(TAU * (i + 1) / sides)
			_quad(a + r0 * ra, a + r1 * ra, b + r1 * rb, b + r0 * rb, (a + b) * 0.5)


## Esfera low-poly (octaedro subdividido).
func _sphere(center: Vector3, radius: float, subdiv: int) -> void:
	subdiv += 1 # con sombreado suave, un nivel más para que los rizos sean redondos
	var tris := [
		[Vector3.UP, Vector3.FORWARD, Vector3.RIGHT], [Vector3.UP, Vector3.RIGHT, Vector3.BACK],
		[Vector3.UP, Vector3.BACK, Vector3.LEFT], [Vector3.UP, Vector3.LEFT, Vector3.FORWARD],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD], [Vector3.DOWN, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.LEFT, Vector3.BACK], [Vector3.DOWN, Vector3.FORWARD, Vector3.LEFT],
	]
	for _s in subdiv:
		var nt := []
		for t in tris:
			var ab: Vector3 = (t[0] + t[1]).normalized()
			var bc: Vector3 = (t[1] + t[2]).normalized()
			var ca: Vector3 = (t[2] + t[0]).normalized()
			nt.append_array([[t[0], ab, ca], [ab, t[1], bc], [ca, bc, t[2]], [ab, bc, ca]])
		tris = nt
	for t in tris:
		_tri(center + t[0] * radius, center + t[1] * radius, center + t[2] * radius, center)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3) -> void:
	_tri(a, b, c, inside)
	_tri(a, c, d, inside)


## Triángulo con normal plana hacia fuera (lejos de `inside`), cara frontal hacia fuera.
func _tri(a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	# Godot toma como cara frontal la de orden horario visto desde fuera.
	# UV: mechones que bajan desde la coronilla (u alrededor de la cabeza, v hacia
	# abajo); color: la raíz, pegada al cuero cabelludo, algo más oscura.
	for v: Vector3 in [a, c, b]:
		var rel := v - _c
		_st.set_uv(Vector2(atan2(rel.x, rel.z) / TAU * 5.0, -rel.y / _R * 0.9))
		var depth := clampf((rel.length() - _R * 1.02) / (_R * 0.3), 0.0, 1.0)
		var shade := lerpf(0.72, 1.0, maxf(depth, clampf(-rel.y / _R, 0.0, 1.0)))
		_st.set_color(Color(shade, shade, shade))
		_st.add_vertex(v)


## Direcciones repartidas por la cabeza dentro de la zona de pelo (y > min_y), siempre iguales.
func _spread_dirs(count: int, min_y: float) -> Array:
	var out := []
	var golden := PI * (3.0 - sqrt(5.0))
	var k := 0
	while out.size() < count and k < count * 8:
		var y := 1.0 - (k + 0.5) / (count * 2.2)
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var d := Vector3(cos(golden * k) * r, y, sin(golden * k) * r)
		k += 1
		if d.y < min_y:
			continue
		if rad_to_deg(acos(clampf(d.y, -1.0, 1.0))) > _hairline(atan2(d.x, d.z)) - 6.0:
			continue
		out.append(d)
	return out
