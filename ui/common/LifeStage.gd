extends Control
## Vivienda y coche en 3D (8-nov, Wilber: "hacer en 3D las propiedades y cosas que
## compra el jugador en la sección de vida personal"). Cada nivel de
## LifestyleEngine.HOME_TIERS / CAR_TIERS tiene su modelo hecho con piezas sencillas
## (estilo del partido 3D) y tu jugador posa al lado. La cámara se mece despacio.
##   const LifeStage = preload("res://ui/common/LifeStage.gd")
##   var st := LifeStage.make(cfg, home_key, car_key, "home" | "car" | "both", 220)  # null sin 3D

const SKY := Color(0.62, 0.78, 0.95)
const GRASS := Color(0.33, 0.6, 0.3)
const CONCRETE := Color(0.66, 0.66, 0.64)
const ASPHALT := Color(0.2, 0.21, 0.23)
const GLASS := Color(0.18, 0.28, 0.4)
const LIT := Color(1.0, 0.86, 0.5)

## Tamaño de cada vivienda (ancho, alto) para encuadrarla.
const HOME_SIZE := {"shared_apartment": Vector2(8, 10), "small_apartment": Vector2(8, 8.5),
	"apartment": Vector2(9, 22), "house": Vector2(10, 8.5), "mansion": Vector2(17, 8)}
## Coches: largo, ancho, alto de carrocería, alto de cabina, largo de cabina, retraso de
## la cabina, radio de rueda, color, alerón, cromados.
const CAR_SPEC := {
	"economy": [3.7, 1.7, 0.75, 0.65, 2.0, -0.2, 0.3, Color(0.35, 0.6, 0.85), false, false],
	"sedan": [4.7, 1.82, 0.7, 0.58, 2.4, -0.15, 0.33, Color(0.72, 0.74, 0.78), false, false],
	"sports_car": [4.4, 1.92, 0.52, 0.44, 1.8, -0.35, 0.34, Color(0.85, 0.1, 0.1), true, false],
	"luxury_car": [5.3, 2.0, 0.8, 0.62, 2.7, -0.3, 0.38, Color(0.06, 0.06, 0.07), false, true],
}
const HOUSE_Z := -7.0   # fachada de la vivienda (m)
const CAR_POS := Vector3(2.6, 0.0, -0.6)
const PLAYER_POS := Vector3(-0.6, 0.0, 0.4)

var _portrait: PlayerPortrait
var _root: Node3D
var _k := 1.0
var _focus := "both"
var _home := ""
var _car := ""
var _look := Vector3.ZERO
var _eye := Vector3.ZERO
var _t := 0.0


static func make(cfg: Dictionary, home_key: String, car_key: String, focus: String, height := 220) -> Control:
	if not Avatar3D.enabled():
		return null
	var st = load("res://ui/common/LifeStage.gd").new()
	st._home = home_key
	st._car = car_key
	st._focus = focus
	st._setup(Avatar.from_legacy(cfg), height)
	return st


func _setup(cfg: Dictionary, height: int) -> void:
	custom_minimum_size = Vector2(0, height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_portrait = PlayerPortrait.new(height, SKY, true, "free")
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Avatar3D.apply(_portrait.avatar, cfg)
	add_child(_portrait)
	_k = absf(_portrait.avatar.scale.y)
	_root = Node3D.new()
	_root.scale = Vector3.ONE * _k # todo en metros, a la escala del modelo
	_portrait.avatar.get_parent().add_child(_root)
	_ground()
	_build_home(_home)
	_build_car(_car, CAR_POS)
	var av := _portrait.avatar
	av.position = PLAYER_POS * _k
	av.rotation.y = 0.35
	if _focus == "car":
		# Al lado de la parte de atrás del coche, sin taparlo
		var half: float = float((CAR_SPEC.get(_car, [1.4]) as Array)[0]) * 0.5
		av.position = (CAR_POS + Vector3(-half - 0.55, 0.0, 0.7)) * _k
		av.rotation.y = 0.45
	_frame()


## Cámara según lo que se enseña: la casa, el coche o las dos cosas.
func _frame() -> void:
	var hs: Vector2 = HOME_SIZE.get(_home, Vector2(8, 8))
	match _focus:
		"home":
			var d := maxf(hs.x * 0.95, hs.y * 1.05) + 4.0
			_look = Vector3(0.6, hs.y * 0.34, HOUSE_Z - 2.0)
			_eye = Vector3(3.0, 1.8 + hs.y * 0.18, HOUSE_Z + d)
		"car":
			_look = CAR_POS + Vector3(-0.6, 0.8, 0.0)
			_eye = CAR_POS + Vector3(1.0, 1.7, 6.6)
		_:
			_look = Vector3(0.6, minf(hs.y * 0.3, 4.0), HOUSE_Z * 0.5)
			_eye = Vector3(2.5, 2.6, 9.0 + hs.x * 0.35)
	var cam := _portrait._cam
	cam.fov = 45.0
	cam.far = 200.0
	_place_cam(0.0)


func _place_cam(yaw: float) -> void:
	var off := (_eye - _look).rotated(Vector3.UP, yaw)
	var eye := (_look + off) * _k
	_portrait._cam.transform = Transform3D(Basis.looking_at(_look * _k - eye, Vector3.UP), eye)


func _process(delta: float) -> void:
	if _portrait == null or not is_visible_in_tree():
		return
	_t += delta
	_place_cam(sin(_t * 0.3) * 0.16) # se mece despacio para que se vea en volumen


# ------------------------------------------------------------------ piezas
func _mat(c: Color, rough := 0.85, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _box(size: Vector3, pos: Vector3, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	(parent if parent != null else _root).add_child(mi)
	return mi


func _cyl(r: float, h: float, pos: Vector3, m: Material, parent: Node3D = null, top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r if top < 0.0 else top
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 14
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	(parent if parent != null else _root).add_child(mi)
	return mi


func _ball(r: float, pos: Vector3, m: Material, squash := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	mi.scale = Vector3(1.0, squash, 1.0)
	_root.add_child(mi)
	return mi


## Ventanas en rejilla sobre la fachada (z = `z`), algunas encendidas.
func _windows(x0: float, x1: float, y0: float, rows: int, cols: int, floor_h: float, z: float, size: Vector2, seed: int) -> void:
	var dark := _mat(GLASS, 0.15, 0.3)
	var lit := _mat(LIT, 0.5, 0.0, 0.9)
	var frame := _mat(Color(0.95, 0.95, 0.93))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for r in rows:
		for c in cols:
			var x := lerpf(x0, x1, (c + 0.5) / float(cols))
			var y := y0 + r * floor_h
			_box(Vector3(size.x + 0.14, size.y + 0.14, 0.04), Vector3(x, y, z + 0.01), frame)
			_box(Vector3(size.x, size.y, 0.05), Vector3(x, y, z + 0.03), lit if rng.randf() < 0.22 else dark)


func _tree(pos: Vector3, h := 3.2) -> void:
	_cyl(0.16, h * 0.5, pos + Vector3(0, h * 0.25, 0), _mat(Color(0.42, 0.29, 0.18)))
	_ball(h * 0.32, pos + Vector3(0, h * 0.62, 0), _mat(Color(0.22, 0.48, 0.22)))


func _palm(pos: Vector3) -> void:
	var trunk := _cyl(0.17, 5.0, pos + Vector3(0.2, 2.5, 0), _mat(Color(0.55, 0.42, 0.28)), null, 0.12)
	trunk.rotation.z = -0.08
	for i in 6:
		var leaf := _box(Vector3(2.4, 0.06, 0.5), pos + Vector3(0.4, 5.0, 0), _mat(Color(0.2, 0.55, 0.25)))
		leaf.rotation = Vector3(0.0, i * TAU / 6.0, -0.35)
		leaf.position += Vector3(cos(i * TAU / 6.0), -0.25, -sin(i * TAU / 6.0)) * 0.9


func _ground() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 80)
	g.mesh = pm
	g.material_override = _mat(GRASS)
	_root.add_child(g)
	# Acera y calle por delante; entrada de coches hasta la vivienda
	_box(Vector3(120, 0.04, 3.0), Vector3(0, 0.02, 2.6), _mat(CONCRETE))
	_box(Vector3(120, 0.03, 8.0), Vector3(0, 0.015, 8.0), _mat(ASPHALT))
	_box(Vector3(5.0, 0.05, 6.8), Vector3(CAR_POS.x, 0.025, -2.4), _mat(CONCRETE.darkened(0.1)))


# ------------------------------------------------------------------ viviendas
func _build_home(key: String) -> void:
	var z := HOUSE_Z
	match key:
		"shared_apartment":
			# Bloque viejo de 4 plantas: pintura gastada, aire acondicionado, bajante
			var wall := _mat(Color(0.74, 0.66, 0.56))
			_box(Vector3(8, 10, 6), Vector3(0, 5, z - 3), wall)
			_box(Vector3(8.3, 0.3, 6.3), Vector3(0, 10.15, z - 3), _mat(Color(0.5, 0.45, 0.4)))
			_windows(-4, 4, 2.6, 3, 4, 2.6, z, Vector2(1.0, 1.1), 11)
			_box(Vector3(1.4, 2.3, 0.08), Vector3(-1.2, 1.15, z + 0.04), _mat(Color(0.4, 0.27, 0.18)))
			for i in 3:
				_box(Vector3(0.7, 0.5, 0.45), Vector3(2.6 - i * 1.4, 3.5 + i * 2.6, z + 0.25), _mat(Color(0.85, 0.85, 0.83)))
			_cyl(0.08, 10, Vector3(3.85, 5, z + 0.1), _mat(Color(0.45, 0.45, 0.47)))
		"small_apartment":
			# Bloque moderno de 3 plantas con balcones y madera
			var white := _mat(Color(0.93, 0.93, 0.9))
			_box(Vector3(8, 8.4, 6), Vector3(0, 4.2, z - 3), white)
			_box(Vector3(1.4, 8.4, 0.1), Vector3(-3.3, 4.2, z + 0.05), _mat(Color(0.62, 0.42, 0.26)))
			_windows(-2.4, 4, 1.6, 3, 3, 2.8, z, Vector2(1.3, 1.6), 22)
			for r in 2:
				var y := 3.0 + r * 2.8
				_box(Vector3(5.6, 0.15, 1.2), Vector3(0.8, y, z + 0.6), white)
				var rail := _mat(Color(0.7, 0.85, 0.95, 0.45))
				rail.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_box(Vector3(5.6, 0.9, 0.04), Vector3(0.8, y + 0.5, z + 1.2), rail)
			_box(Vector3(1.6, 2.4, 0.08), Vector3(-3.3, 1.2, z + 0.12), _mat(GLASS, 0.15, 0.3))
		"apartment":
			# Torre de cristal con bandas por planta y ático retranqueado
			var glass := _mat(Color(0.32, 0.5, 0.66), 0.1, 0.5)
			_box(Vector3(9, 20, 8), Vector3(0, 10, z - 4), glass)
			var band := _mat(Color(0.92, 0.93, 0.95))
			for f in 8:
				_box(Vector3(9.06, 0.22, 8.06), Vector3(0, 2.5 * (f + 1), z - 4), band)
			_box(Vector3(6, 2.4, 5.5), Vector3(-0.8, 21.2, z - 4.5), _mat(Color(0.25, 0.4, 0.55), 0.1, 0.5))
			_box(Vector3(9.4, 0.25, 8.4), Vector3(0, 20.1, z - 4), band)
			_box(Vector3(3.5, 3.0, 0.1), Vector3(0, 1.5, z + 0.05), _mat(LIT, 0.4, 0.0, 0.5))
			_box(Vector3(4.6, 0.25, 2.0), Vector3(0, 3.2, z + 1.0), band) # marquesina
		"house":
			# Casa de dos plantas: tejado a dos aguas, garaje, valla y árbol
			var cream := _mat(Color(0.95, 0.9, 0.78))
			_box(Vector3(8, 5.6, 7), Vector3(-0.5, 2.8, z - 3.5), cream)
			var roof := MeshInstance3D.new()
			var pr := PrismMesh.new()
			pr.size = Vector3(7.8, 2.4, 8.8) # se gira: la cumbrera va a lo largo de X
			roof.mesh = pr
			roof.material_override = _mat(Color(0.55, 0.2, 0.16))
			roof.rotation.y = PI * 0.5
			roof.position = Vector3(-0.5, 6.8, z - 3.5)
			_root.add_child(roof)
			_box(Vector3(0.7, 1.8, 0.7), Vector3(1.8, 7.4, z - 4.2), _mat(Color(0.6, 0.35, 0.28))) # chimenea
			_box(Vector3(3.8, 3.2, 6), Vector3(5.3, 1.6, z - 3.0), cream) # garaje
			_box(Vector3(3.0, 2.5, 0.08), Vector3(5.3, 1.25, z + 0.04), _mat(Color(0.9, 0.9, 0.9)))
			_box(Vector3(4.0, 0.25, 6.2), Vector3(5.3, 3.3, z - 3.0), _mat(Color(0.45, 0.18, 0.14)))
			_windows(-4.5, 3.5, 1.7, 2, 3, 2.8, z, Vector2(1.3, 1.3), 33)
			_box(Vector3(1.2, 2.3, 0.08), Vector3(-0.5, 1.15, z + 0.06), _mat(Color(0.35, 0.22, 0.15)))
			var post := _mat(Color(0.97, 0.97, 0.97))
			for i in 9:
				_box(Vector3(0.1, 0.9, 0.1), Vector3(-7.0 + i * 0.6, 0.45, 0.8), post)
			_box(Vector3(5.0, 0.08, 0.06), Vector3(-4.6, 0.75, 0.8), post)
			_tree(Vector3(-6.5, 0, z + 1.5), 4.0)
		"mansion":
			# Villa moderna: dos volúmenes, cristaleras, piscina y palmeras
			var white := _mat(Color(0.97, 0.97, 0.95))
			var dark_glass := _mat(Color(0.12, 0.16, 0.22), 0.08, 0.6)
			_box(Vector3(16, 4, 9), Vector3(-1, 2, z - 4.5), white)
			_box(Vector3(10, 3.6, 8), Vector3(1.5, 5.8, z - 5), white)
			_box(Vector3(17, 0.3, 10), Vector3(-1, 4.1, z - 4.5), _mat(Color(0.3, 0.3, 0.32)))
			_box(Vector3(11, 0.3, 9), Vector3(1.5, 7.75, z - 5), _mat(Color(0.3, 0.3, 0.32)))
			_box(Vector3(12, 2.8, 0.08), Vector3(-2, 1.6, z + 0.04), dark_glass)
			_box(Vector3(8.5, 2.6, 0.08), Vector3(1.5, 5.8, z - 0.96), dark_glass)
			for i in 4:
				_cyl(0.18, 4, Vector3(-7.5 + i * 3.2, 2, z + 0.4), white)
			# Piscina con borde y tumbonas
			_box(Vector3(7.5, 0.12, 3.6), Vector3(-5.0, 0.06, -2.6), _mat(Color(0.92, 0.92, 0.88)))
			_box(Vector3(6.8, 0.13, 3.0), Vector3(-5.0, 0.07, -2.6), _mat(Color(0.2, 0.62, 0.9), 0.05, 0.1, 0.25))
			for i in 2:
				_box(Vector3(0.7, 0.3, 1.8), Vector3(-1.5 + i * 0.9, 0.15, -2.6), _mat(Color(0.95, 0.95, 0.95)))
			_palm(Vector3(-9.0, 0, -4.0))
			_palm(Vector3(7.5, 0, -1.5))
			for i in 6:
				_box(Vector3(1.6, 1.0, 0.9), Vector3(-9.5 + i * 1.7, 0.5, 0.9), _mat(Color(0.18, 0.42, 0.2)))
		_:
			_build_home("shared_apartment")


# ------------------------------------------------------------------ coches
func _build_car(key: String, pos: Vector3) -> void:
	if not CAR_SPEC.has(key):
		_bike(pos)
		return
	var s: Array = CAR_SPEC[key]
	var length: float = s[0]
	var width: float = s[1]
	var hb: float = s[2]
	var hc: float = s[3]
	var cab_len: float = s[4]
	var cab_off: float = s[5]
	var wr: float = s[6]
	var col: Color = s[7]
	var car := Node3D.new()
	car.position = pos
	_root.add_child(car)
	var paint := _mat(col, 0.28, 0.45)
	var body_y := wr * 0.95 + hb * 0.5
	_box(Vector3(length, hb, width), Vector3(0, body_y, 0), paint, car)
	_box(Vector3(cab_len, hc, width * 0.86), Vector3(cab_off, body_y + hb * 0.5 + hc * 0.5, 0), _mat(GLASS, 0.1, 0.4), car)
	_box(Vector3(cab_len * 0.92, 0.05, width * 0.84), Vector3(cab_off, body_y + hb * 0.5 + hc + 0.02, 0), paint, car) # techo
	var tyre := _mat(Color(0.07, 0.07, 0.08), 0.9)
	var rim := _mat(Color(0.8, 0.8, 0.82), 0.25, 0.8)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var wp := Vector3(sx * (length * 0.5 - wr * 1.55), wr, sz * (width * 0.5 - 0.05))
			var w := _cyl(wr, 0.26, wp, tyre, car)
			w.rotation.x = PI * 0.5
			var r := _cyl(wr * 0.6, 0.27, wp, rim, car)
			r.rotation.x = PI * 0.5
	# Faros delante (+X) y pilotos detrás
	for sz2: float in [-1.0, 1.0]:
		_box(Vector3(0.06, 0.14, 0.36), Vector3(length * 0.5, body_y + hb * 0.15, sz2 * width * 0.33), _mat(Color(1, 0.97, 0.85), 0.3, 0.0, 1.2), car)
		_box(Vector3(0.06, 0.12, 0.34), Vector3(-length * 0.5, body_y + hb * 0.18, sz2 * width * 0.33), _mat(Color(0.9, 0.08, 0.06), 0.3, 0.0, 0.8), car)
	_box(Vector3(0.12, 0.16, width * 1.01), Vector3(length * 0.5 - 0.02, wr * 0.95 + 0.08, 0), _mat(Color(0.12, 0.12, 0.13)), car)
	_box(Vector3(0.12, 0.16, width * 1.01), Vector3(-length * 0.5 + 0.02, wr * 0.95 + 0.08, 0), _mat(Color(0.12, 0.12, 0.13)), car)
	if bool(s[8]): # alerón
		_box(Vector3(0.35, 0.05, width * 0.95), Vector3(-length * 0.5 + 0.25, body_y + hb * 0.5 + 0.32, 0), paint, car)
		for sz3: float in [-0.35, 0.35]:
			_box(Vector3(0.08, 0.3, 0.06), Vector3(-length * 0.5 + 0.25, body_y + hb * 0.5 + 0.15, sz3 * width), paint, car)
	if bool(s[9]): # cromados: rejilla y moldura lateral
		var chrome := _mat(Color(0.88, 0.88, 0.9), 0.12, 1.0)
		_box(Vector3(0.05, hb * 0.55, width * 0.4), Vector3(length * 0.5 + 0.02, body_y, 0), chrome, car)
		_box(Vector3(length * 0.8, 0.05, width * 1.005), Vector3(0, body_y + hb * 0.12, 0), chrome, car)
	car.rotation.y = 0.12


## "Sin coche": la bici apoyada en la entrada.
func _bike(pos: Vector3) -> void:
	var bike := Node3D.new()
	bike.position = pos
	_root.add_child(bike)
	var tyre := _mat(Color(0.08, 0.08, 0.09))
	var frame := _mat(Color(0.15, 0.55, 0.75), 0.35, 0.5)
	for x: float in [-0.52, 0.52]:
		var w := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.3
		t.outer_radius = 0.35
		w.mesh = t
		w.material_override = tyre
		w.rotation.x = PI * 0.5
		w.position = Vector3(x, 0.35, 0)
		bike.add_child(w)
	var pts := [[Vector3(-0.52, 0.35, 0), Vector3(-0.1, 0.8, 0)], [Vector3(-0.1, 0.8, 0), Vector3(0.42, 0.8, 0)],
		[Vector3(-0.52, 0.35, 0), Vector3(0.0, 0.35, 0)], [Vector3(0.0, 0.35, 0), Vector3(-0.1, 0.8, 0)],
		[Vector3(0.0, 0.35, 0), Vector3(0.42, 0.8, 0)], [Vector3(0.52, 0.35, 0), Vector3(0.45, 0.98, 0)],
		[Vector3(0.45, 0.98, -0.25), Vector3(0.45, 0.98, 0.25)]]
	for ab: Array in pts:
		var a: Vector3 = ab[0]
		var b: Vector3 = ab[1]
		var mi := _cyl(0.025, a.distance_to(b), (a + b) * 0.5, frame, bike)
		mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	_box(Vector3(0.24, 0.05, 0.12), Vector3(-0.12, 0.88, 0), _mat(Color(0.1, 0.1, 0.1)), bike)
	bike.rotation.y = 0.2
