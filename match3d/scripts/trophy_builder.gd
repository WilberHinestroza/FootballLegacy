class_name TrophyBuilder
extends RefCounted
## Trofeos 3D hechos con mallas, por TIPOS: liga, copa, "orejona" continental, copa de
## selecciones, Mundial, Mundial de Clubes, supercopa, Balón de Oro, Bota de Oro, MVP y
## once ideal. Cada id ("league_12", "dcup_España", "cont_UEFA_1", "ballon_dor"...) cae en
## su tipo y varía según el id (metal, colores de la peana, proporciones), así que cada
## título se ve distinto sin modelarlos uno a uno. Origen en la base; ~0.55 m de alto.
## Lo usan TrophyCeremony (la copa en la mano) y TrophyViewer (giratorio en menús).

const KINDS := ["league", "cup", "continental", "national", "world", "club_world", "supercup",
	"ballon", "boot", "mvp", "team", "glove"]


## Tipo de trofeo para un id del RPG (Trophy.gd / HonorsEngine) o un nombre de título.
static func kind_for(id: String) -> String:
	var s := id.to_lower()
	if s.begins_with("league_") or s == "league" or s.begins_with("liga"):
		return "league"
	if s.begins_with("dcup_") or s == "cup" or s == "copa" or s == "national_cup":
		return "cup"
	if s.begins_with("cont_") or s == "continental_cup" or s == "continental" or s == "copa continental":
		return "continental"
	if s.begins_with("natcup_") or s == "copa_continental_seleccion":
		return "national"
	if s == "mundial_seleccion" or s == "world_cup" or s == "copa del mundo":
		return "world"
	if s == "mundial_clubes" or s == "cwc" or s == "mundial de clubes":
		return "club_world"
	if s.begins_with("supercopa") or s == "supercup":
		return "supercup"
	if s.begins_with("ballon"):
		return "ballon"
	if s.begins_with("bota") or s == "max_goleador":
		return "boot"
	if s.begins_with("mvp"):
		return "mvp"
	if s.begins_with("once_ideal"):
		return "team"
	if s.begins_with("guante"):
		return "glove"
	return "cup"


## Construye el trofeo de `id` (o de un tipo de KINDS). `accent` tiñe las franjas de la
## peana (p. ej. el color del club); si es transparente sale del propio id.
static func build(id: String, accent := Color(0, 0, 0, 0)) -> Node3D:
	var kind := id if id in KINDS else kind_for(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("trophy:" + id)
	var t := TrophyBuilder.new()
	t._rng = rng
	t.root = Node3D.new()
	t.root.name = "Trophy3D"
	t.accent = accent if accent.a > 0.0 else Color.from_hsv(rng.randf(), 0.65, 0.55)
	t._spec = TrophySpecs.SPECS.get(art_key(id), {})
	if not t._spec.is_empty():
		var rib: Array = t._spec.ribbons
		if accent.a <= 0.0 and not rib.is_empty():
			t.accent = rib[0]
	match kind:
		"league": t._league()
		"cup": t._cup()
		"continental": t._continental()
		"national": t._national()
		"world": t._world()
		"club_world": t._club_world()
		"supercup": t._supercup()
		"ballon": t._ballon()
		"boot": t._boot(id.to_lower() != "max_goleador")
		"mvp": t._mvp()
		"team": t._team()
		"glove": t._glove()
	t._decorate()
	return t.root


## Nombre del arte pixel (Trophy.V3_ART) para un id: sin tildes y con "_" en vez de espacios.
static func art_key(id: String) -> String:
	if id == "mvp_match":
		return "mvp_liga"
	var out := id
	for pair: Array in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ñ", "n"], ["Á", "A"], ["É", "E"], ["Í", "I"], ["Ó", "O"], ["Ú", "U"], [" ", "_"]]:
		out = out.replace(pair[0], pair[1])
	return out


# ---------------------------------------------------------------- materiales y piezas

var root: Node3D
var accent: Color
var _rng: RandomNumberGenerator
var _spec: Dictionary = {}       # del pixel art (TrophySpecs): metal, cintas, peana, remate...
var _bowl := Vector3(-1, -1, -1)  # frente de la copa (donde va el medallón); y < 0 = sin copa
var _hangs: Array[Vector3] = []   # de dónde cuelgan las cintas (bajo las asas)
var _top_y := -1.0                # dónde se apoya el remate (balón, globo, cristal...)
var _bowl_tilt := 0.0             # inclinación de la pared de la copa (rad)

static var _mats: Dictionary = {}


static func metal(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"gold":
			m.albedo_color = Color(1.0, 0.77, 0.3)
			m.metallic = 1.0
			m.roughness = 0.2
			m.emission_enabled = true
			m.emission = Color(0.45, 0.3, 0.06)
			m.emission_energy_multiplier = 0.35
		"silver":
			m.albedo_color = Color(0.9, 0.92, 0.95)
			m.metallic = 1.0
			m.roughness = 0.16
			m.emission_enabled = true
			m.emission = Color(0.25, 0.27, 0.3)
			m.emission_energy_multiplier = 0.3
		"bronze":
			m.albedo_color = Color(0.8, 0.48, 0.25)
			m.metallic = 1.0
			m.roughness = 0.25
		"base":
			m.albedo_color = Color(0.08, 0.07, 0.07)
			m.roughness = 0.35
			m.metallic = 0.2
		"malachite":
			m.albedo_color = Color(0.05, 0.42, 0.25)
			m.roughness = 0.15
			m.metallic = 0.1
		"crystal":
			m.albedo_color = Color(0.75, 0.9, 1.0, 0.35)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.02
			m.metallic = 0.3
			m.rim_enabled = true
	_mats[kind] = m
	return m


## Peana: del color del arte (madera, mármol...) o negra.
func _base_mat() -> StandardMaterial3D:
	if not _spec.has("base"):
		return metal("base")
	var m := StandardMaterial3D.new()
	m.albedo_color = (_spec.base as Color).darkened(0.15)
	m.roughness = 0.4
	m.metallic = 0.15
	return m


func _band_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = accent
	m.roughness = 0.3
	m.metallic = 0.3
	return m


func _cyl(r_top: float, r_bot: float, h: float, y: float, mat: Material, segs := 32) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position.y = y + h * 0.5
	root.add_child(mi)
	return mi


func _sphere(r: float, pos: Vector3, mat: Material, sc := Vector3.ONE) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 32
	sm.rings = 16
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = sc
	root.add_child(mi)
	return mi


## Aro (toro) de radio medio `r` y grosor `thick`, girado con `rot`.
func _ring(r: float, thick: float, pos: Vector3, rot: Vector3, mat: Material, sc := Vector3.ONE) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(r - thick, 0.0005)
	tm.outer_radius = r + thick
	tm.rings = 40
	tm.ring_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = sc
	root.add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	root.add_child(mi)
	return mi


## Peana negra de 1 o 2 pisos con una franja del color de acento; devuelve la altura.
func _plinth(r: float, tiers: int) -> float:
	var y := 0.0
	var band := _band_mat()
	for i in tiers:
		var rr := r * (1.0 - i * 0.18)
		var h := 0.05 if i == 0 else 0.04
		_cyl(rr * 0.96, rr, h, y, _base_mat())
		_cyl(rr * 0.985, rr * 0.995, h * 0.3, y + h * 0.35, band)
		y += h
	return y


## Asa en forma de lazo vertical a un lado (x = side * dx); `tall` la estira hacia arriba.
func _handle(side: float, dx: float, y: float, size: float, mat: Material, tall := 1.0) -> void:
	if _spec.has("handles"):
		var k := clampf(float(_spec.handles) / 1.5, 0.85, 1.2)
		size *= k
		dx = dx + size * (k - 1.0)
	_hangs.append(Vector3(side * (dx + size * 0.6), y - size * tall * 0.7, 0.0))
	_ring(size, size * 0.16, Vector3(side * dx, y, 0), Vector3(PI * 0.5, 0, 0), mat, Vector3(1.0, 1.0, tall))


## Estrella de 5 puntas extruida en el plano XY, centrada en `pos`.
func _star(r: float, depth: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector2] = []
	for i in 10:
		var a := PI * 0.5 + i * TAU / 10.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(Vector2(cos(a), sin(a)) * rr)
	for zf: float in [1.0, -1.0]:
		var z := depth * 0.5 * zf
		for i in 10:
			var a := pts[i]
			var b := pts[(i + 1) % 10]
			var tri: Array[Vector3] = [Vector3(0, 0, z * 1.6), Vector3(a.x, a.y, z), Vector3(b.x, b.y, z)]
			if zf > 0.0:
				tri = [tri[0], tri[2], tri[1]]
			for v in tri:
				st.add_vertex(v)
	for i in 10:
		var a := pts[i]
		var b := pts[(i + 1) % 10]
		for v: Vector3 in [Vector3(a.x, a.y, depth * 0.5), Vector3(b.x, b.y, depth * 0.5), Vector3(b.x, b.y, -depth * 0.5),
				Vector3(a.x, a.y, depth * 0.5), Vector3(b.x, b.y, -depth * 0.5), Vector3(a.x, a.y, -depth * 0.5)]:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	return mi


func _pick_metal(p_gold := 0.6) -> StandardMaterial3D:
	var forced := String(_spec.get("metal", ""))
	if forced != "":
		return metal(forced)
	return metal("gold") if _rng.randf() < p_gold else metal("silver")


# ---------------------------------------------------------------- tipos

## Liga: copa grande con tapa y estrella, sobre peana de dos pisos.
func _league() -> void:
	var m := _pick_metal(0.55)
	var y := _plinth(0.1, 2)
	var stem := _rng.randf_range(0.07, 0.11)
	_cyl(0.035, 0.06, 0.03, y, m)
	_cyl(0.022, 0.03, stem, y + 0.03, m)
	y += 0.03 + stem
	var bowl_h := _rng.randf_range(0.17, 0.22)
	var rtop := _rng.randf_range(0.1, 0.13)
	_cyl(rtop, 0.035, bowl_h, y, m)
	_ring(rtop, 0.008, Vector3(0, y + bowl_h, 0), Vector3.ZERO, m)
	for s: float in [-1.0, 1.0]:
		_handle(s, rtop + 0.03, y + bowl_h * 0.6, 0.045, m, 1.3)
	_bowl = Vector3(0, y + bowl_h * 0.55, lerpf(0.035, rtop, 0.55) + 0.004)
	_bowl_tilt = atan((rtop - 0.035) / bowl_h)
	y += bowl_h
	if _spec.get("top", "") != "":
		_top_y = y + rtop * 0.2
		return
	# Tapa en cúpula y estrella arriba
	_sphere(rtop * 0.85, Vector3(0, y, 0), m, Vector3(1, 0.45, 1))
	_cyl(0.012, 0.02, 0.04, y + rtop * 0.3, m)
	_star(0.035, 0.014, Vector3(0, y + rtop * 0.3 + 0.075, 0), m)


## Copa nacional: estilo copa antigua, panza redonda, asas grandes y tapa alta.
func _cup() -> void:
	var m := _pick_metal(0.4)
	var y := _plinth(0.085, 1)
	_cyl(0.025, 0.05, 0.05, y, m)
	_sphere(0.03, Vector3(0, y + 0.07, 0), m)
	y += 0.09
	var bh := _rng.randf_range(0.15, 0.2)
	_cyl(0.09, 0.03, bh, y, m)
	_sphere(0.075, Vector3(0, y + bh * 0.35, 0), m, Vector3(1, 0.8, 1))
	for s: float in [-1.0, 1.0]:
		_handle(s, 0.13, y + bh * 0.55, 0.05, m, 1.6)
	_bowl = Vector3(0, y + bh * 0.35, 0.075 * 0.8 + 0.006)
	y += bh
	if _spec.get("top", "") != "":
		_top_y = y
		return
	_cyl(0.06, 0.09, 0.04, y, m)
	_cyl(0.008, 0.03, 0.08, y + 0.04, m)
	_sphere(0.02, Vector3(0, y + 0.13, 0), m)


## "Orejona": copa de plata con asas enormes casi hasta la base.
func _continental() -> void:
	var m := _pick_metal(0.25)
	var y := _plinth(0.085, 1)
	_cyl(0.03, 0.065, 0.05, y, m)
	_cyl(0.02, 0.028, 0.08, y + 0.05, m)
	y += 0.13
	var bh := 0.2
	_cyl(0.105, 0.03, bh, y, m)
	_ring(0.105, 0.008, Vector3(0, y + bh, 0), Vector3.ZERO, m)
	for s: float in [-1.0, 1.0]:
		_handle(s, 0.145, y + bh * 0.45, 0.06, m, 1.9)
	_bowl = Vector3(0, y + bh * 0.55, lerpf(0.03, 0.105, 0.55) + 0.004)
	_bowl_tilt = atan(0.075 / bh)
	_top_y = y + bh


## Copa de selecciones: alta y estilizada, con bola en el pie.
func _national() -> void:
	var m := _pick_metal(0.35)
	var y := _plinth(0.08, 2)
	_cyl(0.02, 0.045, 0.05, y, m)
	_sphere(0.04, Vector3(0, y + 0.08, 0), m)
	y += 0.11
	_cyl(0.022, 0.02, 0.07, y, m)
	y += 0.07
	_cyl(0.08, 0.025, 0.16, y, m)
	for s: float in [-1.0, 1.0]:
		_handle(s, 0.105, y + 0.1, 0.04, m, 1.2)
	_bowl = Vector3(0, y + 0.09, lerpf(0.025, 0.08, 0.56) + 0.004)
	_bowl_tilt = atan(0.055 / 0.16)
	y += 0.16
	if _spec.get("top", "") != "":
		_top_y = y
		return
	_sphere(0.06, Vector3(0, y, 0), m, Vector3(1, 0.4, 1))
	_star(0.03, 0.012, Vector3(0, y + 0.06, 0), m)


## Mundial: base con franjas verdes, cuerpo en espiral y el globo arriba.
func _world() -> void:
	var g := metal("gold")
	_cyl(0.075, 0.08, 0.03, 0.0, g)
	_cyl(0.07, 0.072, 0.025, 0.03, metal("malachite"))
	_cyl(0.068, 0.07, 0.01, 0.055, g)
	_cyl(0.064, 0.066, 0.02, 0.065, metal("malachite"))
	var y := 0.085
	_cyl(0.035, 0.065, 0.12, y, g)
	_cyl(0.075, 0.035, 0.14, y + 0.12, g)
	# Figuras en espiral (tiras de bolitas doradas que suben girando)
	for k in 3:
		for i in 22:
			var t := i / 21.0
			var a := k * TAU / 3.0 + t * 2.4
			var r := lerpf(0.06, 0.07, t) - sin(t * PI) * 0.025
			_sphere(0.013, Vector3(cos(a) * r, y + 0.02 + t * 0.24, sin(a) * r), g)
	var gy := y + 0.26 + 0.075
	_sphere(0.085, Vector3(0, gy, 0), g)
	for i in 3:
		var off := (i - 1) * 0.04
		_ring(sqrt(0.0865 * 0.0865 - off * off), 0.003, Vector3(0, gy + off, 0), Vector3.ZERO, metal("malachite"))


## Mundial de Clubes: copa dorada con un globo plateado dentro de dos aros.
func _club_world() -> void:
	var g := metal("gold")
	var y := _plinth(0.08, 2)
	_cyl(0.03, 0.06, 0.06, y, g)
	y += 0.06
	_cyl(0.06, 0.03, 0.18, y, g)
	y += 0.18
	_sphere(0.07, Vector3(0, y + 0.06, 0), metal("silver"))
	_ring(0.085, 0.006, Vector3(0, y + 0.06, 0), Vector3(PI * 0.5, 0, 0), g)
	_ring(0.085, 0.006, Vector3(0, y + 0.06, 0), Vector3(PI * 0.5, 0, PI * 0.5), g)


## Supercopa: escudo-plato de pie sobre una columna, con estrella.
func _supercup() -> void:
	var m := _pick_metal(0.5)
	var y := _plinth(0.075, 1)
	_cyl(0.018, 0.035, 0.16, y, m)
	y += 0.16
	var plate := _cyl(0.13, 0.13, 0.012, 0.0, m, 48)
	plate.rotation.x = PI * 0.5
	plate.position = Vector3(0, y + 0.13, 0)
	_ring(0.128, 0.008, Vector3(0, y + 0.13, 0), Vector3(PI * 0.5, 0, 0), _band_mat())
	var other := metal("gold") if m == metal("silver") else metal("silver")
	_star(0.06, 0.02, Vector3(0, y + 0.13, 0.012), other)
	_star(0.06, 0.02, Vector3(0, y + 0.13, -0.012), other)


## Balón de Oro: balón dorado sobre peana negra con placa.
func _ballon() -> void:
	var g := metal("gold")
	_cyl(0.07, 0.08, 0.08, 0.0, metal("base"))
	_box(Vector3(0.07, 0.03, 0.004), Vector3(0, 0.04, 0.077), g)
	_cyl(0.04, 0.06, 0.03, 0.08, g)
	var by := 0.11 + 0.115
	_sphere(0.12, Vector3(0, by, 0), g)
	# Costuras del balón
	for r: Vector3 in [Vector3.ZERO, Vector3(PI * 0.5, 0, 0), Vector3(0, 0, PI * 0.5)]:
		_ring(0.1205, 0.0025, Vector3(0, by, 0), r, metal("base"))


## Bota de Oro (de plata para el máximo goleador): bota inclinada sobre peana.
func _boot(gold: bool) -> void:
	var m := metal("gold") if gold else metal("silver")
	var y := _plinth(0.08, 1)
	_cyl(0.025, 0.04, 0.08, y, m)
	y += 0.08
	var boot := Node3D.new()
	boot.position = Vector3(0, y + 0.012, 0)
	boot.rotation = Vector3(0.0, -0.35, 0.12)
	root.add_child(boot)
	var prev := root
	root = boot
	# Suela, pie redondeado (cápsula tumbada), caña con su boca y cordones
	_box(Vector3(0.23, 0.016, 0.075), Vector3(0.01, 0.0, 0), m)
	var foot := CapsuleMesh.new()
	foot.radius = 0.038
	foot.height = 0.22
	var fm := MeshInstance3D.new()
	fm.mesh = foot
	fm.material_override = m
	fm.rotation.z = PI * 0.5
	fm.position = Vector3(0.015, 0.03, 0)
	fm.scale = Vector3(1.0, 1.0, 0.95)
	root.add_child(fm)
	_cyl(0.04, 0.042, 0.1, 0.03, m).position.x = -0.06
	_ring(0.04, 0.007, Vector3(-0.06, 0.13, 0), Vector3.ZERO, m)
	for i in 4:
		_box(Vector3(0.006, 0.004, 0.04), Vector3(-0.015 + i * 0.022, 0.07 - i * 0.006, 0), metal("base"), Vector3(0, 0, -0.25))
	for i in 4:
		var stud := _cyl(0.007, 0.009, 0.014, 0.0, metal("base"))
		stud.position = Vector3(-0.08 + i * 0.055, -0.014, 0.02 * (1 if i % 2 == 0 else -1))
	root = prev


## MVP: estrella grande sobre columna.
func _mvp() -> void:
	var m := _pick_metal(0.7)
	var y := _plinth(0.075, 2)
	_cyl(0.015, 0.03, 0.16, y, m)
	var sy := y + 0.16 + 0.12
	_star(0.13, 0.04, Vector3(0, sy, 0), m)
	_ring(0.15, 0.006, Vector3(0, sy, 0), Vector3(PI * 0.5, 0, 0), _band_mat())


## Guante de Oro: guante de portero dorado, de pie y abierto, sobre peana.
func _glove() -> void:
	var g := metal("gold")
	var y := _plinth(0.08, 2)
	_cyl(0.03, 0.045, 0.06, y, g)
	y += 0.06
	var glove := Node3D.new()
	glove.position = Vector3(0, y, 0)
	glove.rotation = Vector3(0.0, 0.3, 0.0)
	root.add_child(glove)
	var prev := root
	root = glove
	# Puño ancho, palma y cuatro dedos con su pulgar abierto
	_box(Vector3(0.12, 0.05, 0.06), Vector3(0, 0.025, 0), metal("base"))
	_box(Vector3(0.14, 0.13, 0.05), Vector3(0, 0.115, 0), g)
	for i in 4:
		var fx := -0.051 + i * 0.034
		var h := 0.09 if i in [1, 2] else 0.075
		var f := CapsuleMesh.new()
		f.radius = 0.016
		f.height = h
		var fm := MeshInstance3D.new()
		fm.mesh = f
		fm.material_override = g
		fm.position = Vector3(fx, 0.18 + h * 0.5 - 0.012, 0)
		root.add_child(fm)
	var th := CapsuleMesh.new()
	th.radius = 0.018
	th.height = 0.08
	var tm := MeshInstance3D.new()
	tm.mesh = th
	tm.material_override = g
	tm.position = Vector3(-0.088, 0.12, 0.004)
	tm.rotation.z = 0.7
	root.add_child(tm)
	# Banda del puño con el color del premio
	_box(Vector3(0.124, 0.014, 0.064), Vector3(0, 0.05, 0), _band_mat())
	root = prev


## Once ideal: placa de cristal con once estrellitas doradas.
func _team() -> void:
	_box(Vector3(0.24, 0.05, 0.09), Vector3(0, 0.025, 0), metal("base"))
	_box(Vector3(0.2, 0.32, 0.03), Vector3(0, 0.05 + 0.16, 0), metal("crystal"))
	var lines := [[0.0], [-0.06, -0.02, 0.02, 0.06], [-0.05, 0.0, 0.05], [-0.05, 0.0, 0.05]]
	for li in lines.size():
		for x: float in lines[li]:
			_star(0.014, 0.006, Vector3(x, 0.09 + li * 0.065, 0.0), metal("gold"))


# ---------------------------------------------------------------- detalles del pixel art

## Lo que tiene el dibujo de cada trofeo: cintas con los colores (país/club) colgando de
## las asas, medallón con el balón al frente y el remate de arriba (balón, globo,
## cristal, estrella), alas o laurel.
func _decorate() -> void:
	var rib: Array = _spec.get("ribbons", [])
	if rib.is_empty() and _spec.is_empty() and not _hangs.is_empty():
		rib = [accent, accent.lightened(0.5)]
	for h in _hangs:
		_ribbons(h, rib)
	if _bowl.y > 0.0:
		_medallion(_bowl)
	var top := String(_spec.get("top", ""))
	if top != "" and _top_y > 0.0:
		match top:
			"ball": _ball_top(_top_y)
			"globe": _globe_top(_top_y)
			"crystal": _crystal_top(_top_y)
			"star": _star(0.05, 0.016, Vector3(0, _top_y + 0.06, 0), _pick_metal())
	if bool(_spec.get("wings", false)) and _bowl.y > 0.0:
		_wings(_bowl.y + 0.02)
	if bool(_spec.get("laurel", false)) and _bowl.y > 0.0:
		_laurel(_bowl.y - 0.04)


## Dos o tres cintas de colores que caen ondulando desde `at`.
func _ribbons(at: Vector3, cols: Array) -> void:
	var side := signf(at.x)
	for i in mini(cols.size(), 3):
		var c: Color = cols[i]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.roughness = 0.6
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var segs := 4
		var p := at + Vector3(side * i * 0.012, 0.0, 0.02 - i * 0.012)
		for k in segs:
			var len := 0.04
			var ang := side * (0.12 + 0.1 * sin(k * 1.7 + i))
			var seg := _box(Vector3(0.016, len, 0.003), p + Vector3(sin(ang) * len * 0.5, -len * 0.5, 0.0), mat, Vector3(0.0, side * 0.3, ang))
			seg.position.z += 0.004 * k
			p += Vector3(sin(ang) * len, -len, 0.0)


## Medallón blanco con un balón dibujado, pegado a la pared de la copa.
func _medallion(at: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.x = _bowl_tilt # sigue la pendiente de la copa
	root.add_child(holder)
	var prev := root
	root = holder
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.96, 0.94)
	white.roughness = 0.4
	var rim := _cyl(0.04, 0.04, 0.006, 0.0, _pick_metal())
	rim.rotation.x = PI * 0.5
	rim.position = Vector3(0, 0, 0.002)
	var disc := _cyl(0.033, 0.033, 0.006, 0.0, white)
	disc.rotation.x = PI * 0.5
	disc.position = Vector3(0, 0, 0.005)
	for i in 6:
		var p := Vector3(0, 0, 0.0085)
		if i > 0:
			var a := PI * 0.5 + i * TAU / 5.0
			p += Vector3(cos(a), sin(a), 0) * 0.024
		var r := 0.009 if i == 0 else 0.006
		var dot := _cyl(r, r, 0.002, 0.0, metal("base"), 5)
		dot.rotation.x = PI * 0.5
		dot.position = p
	root = prev


func _ball_top(y: float) -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.96, 0.95)
	white.roughness = 0.35
	var c := Vector3(0, y + 0.06, 0)
	_sphere(0.06, c, white)
	for d: Vector3 in [Vector3(0, 0, 1), Vector3(0, 1, 0.2), Vector3(0.9, 0.3, 0.3), Vector3(-0.9, 0.3, 0.3), Vector3(0.5, -0.5, 0.7), Vector3(-0.5, -0.5, 0.7)]:
		_sphere(0.018, c + d.normalized() * 0.052, metal("base"), Vector3(1, 1, 0.5)).look_at_from_position(c + d.normalized() * 0.052, c + d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.9 else Vector3.RIGHT)


func _globe_top(y: float) -> void:
	var sea := StandardMaterial3D.new()
	sea.albedo_color = Color(0.2, 0.5, 0.9)
	sea.roughness = 0.25
	sea.metallic = 0.2
	var land := StandardMaterial3D.new()
	land.albedo_color = Color(0.3, 0.7, 0.3)
	var c := Vector3(0, y + 0.065, 0)
	_sphere(0.065, c, sea)
	for i in 6:
		var d := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.7, 0.8), _rng.randf_range(-1, 1)).normalized()
		_sphere(0.03, c + d * 0.05, land, Vector3(1.0, 0.7, 1.0))
	_ring(0.075, 0.004, c, Vector3(0, 0, 0.4), _pick_metal())


func _crystal_top(y: float) -> void:
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.6, 0.85, 1.0, 0.75)
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.metallic = 0.4
	ice.roughness = 0.05
	ice.emission_enabled = true
	ice.emission = Color(0.3, 0.6, 1.0)
	ice.emission_energy_multiplier = 0.4
	for i in 5:
		var a := (i - 2) * 0.32
		var h := 0.13 - absf(i - 2) * 0.025
		var shard := _box(Vector3(0.028, h, 0.028), Vector3(sin(a) * 0.05, y + h * 0.5, 0), ice, Vector3(0, PI * 0.25, -a))
		shard.scale = Vector3(1.0, 1.0, 1.0)


## Alas plateadas a los lados de la copa (plumas en abanico).
func _wings(y: float) -> void:
	var m := metal("silver")
	for side: float in [-1.0, 1.0]:
		for k in 4:
			var len := 0.11 - k * 0.018
			var f := _sphere(0.5, Vector3(side * (0.12 + len * 0.4), y + 0.04 - k * 0.025, -0.02), m, Vector3(len, 0.022, 0.01))
			f.rotation.z = side * (0.35 - k * 0.12)


## Corona de laurel dorada alrededor de la copa.
func _laurel(y: float) -> void:
	var m := metal("gold")
	for i in 14:
		var a := PI * 0.15 + i * PI * 0.7 / 13.0
		for side: float in [-1.0, 1.0]:
			var p := Vector3(side * cos(a) * 0.13, y + sin(a) * 0.1 - 0.05, 0.03)
			var leaf := _sphere(0.5, p, m, Vector3(0.022, 0.01, 0.006))
			leaf.rotation.z = side * (a + 0.6)
