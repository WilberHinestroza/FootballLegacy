class_name StadiumGrounds
extends RefCounted
## Alrededores del estadio: explanada, calles, aparcamientos con coches, árboles y
## la ciudad al fondo (que la bruma difumina). Se ve en la toma de llegada al
## estadio y, en los estadios pequeños, por encima de la grada. Todo con
## MultiMesh y sin sombras; determinista por club (semilla), nada se guarda.

## Huella del estadio (muro trasero) en x y z, según estrellas y diseño.
static func footprint() -> Vector2:
	if FieldBuilder.design != "":
		return Vector2(BigStadium.back_x(), BigStadium.back_z())
	var L := SoccerMatch.FIELD_LENGTH
	var W := SoccerMatch.FIELD_WIDTH
	return Vector2(L * 0.5 + FieldBuilder.END_STANDS + FieldBuilder.END_ROWS * FieldBuilder.ROW_DEPTH,
			W * 0.5 + FieldBuilder.SIDE_STANDS + FieldBuilder.SIDE_ROWS * FieldBuilder.ROW_DEPTH)


static func build(root: Node3D, seed_name: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("grounds:" + seed_name)
	var night := FieldBuilder.time_of_day == 2
	var dim := 0.35 if night else 1.0
	var fp := footprint()
	var holder := Node3D.new()
	holder.name = "Grounds"
	root.add_child(holder)

	# Suelo general (hierba seca de descampado) y explanada de cemento
	_flat(holder, Vector2(1800.0, 1800.0), Vector3(0.0, -0.08, 0.0), Color(0.33, 0.42, 0.27) * dim)
	var plaza := Vector2(fp.x * 2.0 + 50.0, fp.y * 2.0 + 50.0)
	_flat(holder, plaza, Vector3(0.0, -0.05, 0.0), Color(0.62, 0.62, 0.6) * dim)
	# Avenidas: una en cruz por cada eje y un anillo que rodea la explanada
	var road := Color(0.2, 0.21, 0.23) * dim
	var ring_x := plaza.x * 0.5 + 9.0
	var ring_z := plaza.y * 0.5 + 9.0
	for s: float in [-1.0, 1.0]:
		_flat(holder, Vector2(ring_x * 2.0 + 14.0, 12.0), Vector3(0.0, -0.04, s * ring_z), road)
		_flat(holder, Vector2(12.0, ring_z * 2.0 + 14.0), Vector3(s * ring_x, -0.04, 0.0), road)
		_flat(holder, Vector2(800.0, 14.0), Vector3(s * (ring_x + 400.0), -0.045, 0.0), road)
		_flat(holder, Vector2(14.0, 800.0), Vector3(0.0, -0.045, s * (ring_z + 400.0)), road)

	# Aparcamientos en las cuatro esquinas de fuera del anillo, llenos de coches
	var lot := Color(0.28, 0.29, 0.31) * dim
	var cars: Array[Transform3D] = []
	var car_cols: Array[Color] = []
	var palette := [Color(0.85, 0.85, 0.86), Color(0.1, 0.1, 0.12), Color(0.55, 0.57, 0.6),
		Color(0.7, 0.12, 0.12), Color(0.15, 0.25, 0.55), Color(0.9, 0.9, 0.92), Color(0.3, 0.32, 0.35)]
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector3(sx * (ring_x + 48.0), 0.0, sz * (ring_z + 34.0))
			_flat(holder, Vector2(76.0, 50.0), c + Vector3(0.0, -0.03, 0.0), lot)
			for row in 8:
				var z := c.z - 21.0 + row * 6.0
				var x := c.x - 35.0
				while x < c.x + 35.0:
					if rng.randf() < 0.82:
						cars.append(Transform3D(Basis(Vector3.UP, PI * 0.5 + (PI if row % 2 == 0 else 0.0)), Vector3(x, 0.0, z)))
						car_cols.append(palette[rng.randi() % palette.size()] * dim)
					x += 2.6
	_multi(holder, _car_mesh(), cars, car_cols, false)

	# Árboles a lo largo de las avenidas y en el descampado
	var trees: Array[Transform3D] = []
	var tree_cols: Array[Color] = []
	for s: float in [-1.0, 1.0]:
		var x := -ring_x
		while x <= ring_x:
			for side: float in [-1.0, 1.0]:
				trees.append(_tree_xf(rng, Vector3(x, 0.0, s * ring_z + side * 9.0)))
				tree_cols.append(_leaf(rng, dim))
			x += 9.0
		var z := -ring_z
		while z <= ring_z:
			trees.append(_tree_xf(rng, Vector3(s * ring_x + s * 9.0, 0.0, z)))
			tree_cols.append(_leaf(rng, dim))
			z += 9.0
	for i in 260:
		var p := _scatter(rng, ring_x + 90.0, ring_z + 70.0, 330.0)
		trees.append(_tree_xf(rng, p))
		tree_cols.append(_leaf(rng, dim))
	_multi(holder, _tree_mesh(), trees, tree_cols, false)

	# La ciudad: manzanas de edificios en un anillo, más altos cuanto más lejos
	var blds: Array[Transform3D] = []
	var bld_cols: Array[Color] = []
	var stone := [Color(0.82, 0.78, 0.7), Color(0.7, 0.68, 0.66), Color(0.86, 0.84, 0.8),
		Color(0.6, 0.55, 0.5), Color(0.75, 0.72, 0.62), Color(0.55, 0.6, 0.66)]
	for i in 420:
		var p := _scatter(rng, ring_x + 150.0, ring_z + 130.0, 620.0)
		var far := clampf((p.length() - 220.0) / 400.0, 0.0, 1.0)
		var h := rng.randf_range(8.0, 22.0) + far * rng.randf_range(0.0, 45.0) * (1.0 if rng.randf() < 0.35 else 0.3)
		var w := rng.randf_range(14.0, 30.0)
		var d := rng.randf_range(14.0, 30.0)
		var b := Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)).scaled(Vector3(w, h, d))
		blds.append(Transform3D(b, p + Vector3(0.0, h * 0.5, 0.0)))
		var col: Color = stone[rng.randi() % stone.size()]
		# De noche, ventanas encendidas: un tono cálido según el edificio
		bld_cols.append(col * 0.18 + Color(0.25, 0.2, 0.1) * rng.randf_range(0.2, 0.7) if night else col)
	_multi(holder, FieldBuilder.box(Vector3.ONE), blds, bld_cols, night)

	# Farolas del anillo (de noche, puntos de luz que dibujan las avenidas)
	if night:
		var lamps: Array[Transform3D] = []
		var lamp_cols: Array[Color] = []
		for s: float in [-1.0, 1.0]:
			var x := -ring_x
			while x <= ring_x:
				lamps.append(Transform3D(Basis().scaled(Vector3(0.6, 0.6, 0.6)), Vector3(x, 6.0, s * (ring_z - 6.5))))
				lamp_cols.append(Color(1.0, 0.8, 0.5) * 2.5)
				x += 18.0
			var z := -ring_z
			while z <= ring_z:
				lamps.append(Transform3D(Basis().scaled(Vector3(0.6, 0.6, 0.6)), Vector3(s * (ring_x - 6.5), 6.0, z)))
				lamp_cols.append(Color(1.0, 0.8, 0.5) * 2.5)
				z += 18.0
		_multi(holder, FieldBuilder.box(Vector3.ONE), lamps, lamp_cols, true)


static func _flat(parent: Node3D, size: Vector2, pos: Vector3, c: Color) -> void:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := FieldBuilder.add_mesh(parent, pm, pos, c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Punto al azar dentro de un radio, fuera del rectángulo (hx, hz) del estadio y sus calles.
static func _scatter(rng: RandomNumberGenerator, hx: float, hz: float, r: float) -> Vector3:
	for i in 30:
		var p := Vector3(rng.randf_range(-r, r), 0.0, rng.randf_range(-r, r))
		if (absf(p.x) > hx or absf(p.z) > hz) and absf(p.x) > 12.0 and absf(p.z) > 12.0 and p.length() < r:
			return p
	return Vector3(hx + 20.0, 0.0, hz + 20.0)


static func _tree_xf(rng: RandomNumberGenerator, p: Vector3) -> Transform3D:
	var k := rng.randf_range(0.8, 1.35)
	return Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(k, k, k)), p)


static func _leaf(rng: RandomNumberGenerator, dim: float) -> Color:
	return Color(0.2, 0.42, 0.18).lerp(Color(0.36, 0.5, 0.2), rng.randf()) * dim


static func _multi(parent: Node3D, mesh: Mesh, xforms: Array[Transform3D], cols: Array[Color], glow: bool) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


## Coche: carrocería + cabina (el color lo pone cada instancia; la cabina, más oscura).
static func _car_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)
	FieldBuilder._st_box(st, Vector3(0.0, 0.45, 0.0), Vector3(4.2, 0.7, 1.8))
	st.set_color(Color(0.45, 0.5, 0.58))
	FieldBuilder._st_box(st, Vector3(-0.2, 1.05, 0.0), Vector3(2.2, 0.55, 1.6))
	st.generate_normals()
	return st.commit()


## Árbol: tronco y copa en dos cajas (la copa con el color de la instancia).
static func _tree_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.45, 0.32, 0.2) * 0.7)
	FieldBuilder._st_box(st, Vector3(0.0, 1.2, 0.0), Vector3(0.45, 2.4, 0.45))
	st.set_color(Color.WHITE)
	FieldBuilder._st_box(st, Vector3(0.0, 3.9, 0.0), Vector3(3.4, 3.2, 3.4))
	FieldBuilder._st_box(st, Vector3(0.0, 5.6, 0.0), Vector3(2.2, 1.4, 2.2))
	st.generate_normals()
	return st.commit()
