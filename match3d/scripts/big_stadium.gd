class_name BigStadium
extends RefCounted
## Gran estadio cubierto (5 estrellas, ver Venue.design): grada de DOS pisos con
## la alta volada sobre la baja, esquinas cerradas, techo de anillo sobre toda
## la grada con banda translúcida y luces en el borde, y franja LED de anuncios
## entre pisos. Tres estilos inspirados en la arquitectura de los grandes
## estadios (ninguno copia uno real):
##   "cuenco"   techo oscuro continuo con vigas a la vista por debajo
##   "catedral" cuatro gradas con cercha de acero en el borde y esquinas del techo abiertas
##   "anillo"   membrana blanca y anillo de luz del color del club en el borde
## FieldBuilder pone la grada baja (con las esquinas rellenas) y llama aquí para
## el resto. Todo determinista, nada se guarda.

const DESIGNS := ["cuenco", "catedral", "anillo"]
const UPPER_ROWS := 10
const UPPER_RISE := 0.78
const OVERHANG_ROWS := 3          # filas de la grada baja que quedan bajo la alta
const CONCOURSE := 3.4            # altura libre entre pisos (pasillo + franja LED)
const UPPER_SPACING := 1.3        # separación de la gente en la grada alta (lejana)
const ROOF_GAP := 5.0             # del último escalón al techo
const ROOF_INNER := 3.0           # cuánto vuela el techo por delante de la primera fila
const TRANSLUCENT := 7.0          # ancho de la banda translúcida del borde

static func _L() -> float:
	return SoccerMatch.FIELD_LENGTH

static func _W() -> float:
	return SoccerMatch.FIELD_WIDTH

## Altura del arranque de la grada alta (igual en los cuatro lados: el anillo cierra).
static func upper_base() -> float:
	var side_top: float = 0.9 + (FieldBuilder.SIDE_ROWS - 1) * FieldBuilder.ROW_RISE
	var end_top: float = 0.9 + (FieldBuilder.END_ROWS - 1) * FieldBuilder.ROW_RISE
	return maxf(side_top, end_top) + CONCOURSE

static func roof_y() -> float:
	return upper_base() + (UPPER_ROWS - 1) * UPPER_RISE + ROOF_GAP

## Fondo del estadio (muro trasero) en z (laterales) y en x (fondos).
static func back_z() -> float:
	return _W() * 0.5 + FieldBuilder.SIDE_STANDS + (FieldBuilder.SIDE_ROWS - OVERHANG_ROWS + UPPER_ROWS) * FieldBuilder.ROW_DEPTH

static func back_x() -> float:
	return _L() * 0.5 + FieldBuilder.END_STANDS + (FieldBuilder.END_ROWS - OVERHANG_ROWS + UPPER_ROWS) * FieldBuilder.ROW_DEPTH

## Largo de la grada baja lateral con las esquinas rellenas (FieldBuilder._stands).
static func lower_side_len() -> float:
	return _L() + 2.0 * (FieldBuilder.END_STANDS + FieldBuilder.END_ROWS * FieldBuilder.ROW_DEPTH)

static func _seat(k: int) -> Color:
	var a: Color = FieldBuilder.home_color.darkened(0.3)
	var b: Color = FieldBuilder.home_color.darkened(0.42)
	var band: Color = FieldBuilder.home_color2.darkened(0.15)
	return band if k % 4 == 3 else (a if k % 2 == 0 else b)

static func _no_shadow(mi: MeshInstance3D) -> MeshInstance3D:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

static func _glow_box(root: Node3D, size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = FieldBuilder.box(size)
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

static func build(root: Node3D, xforms: Array[Transform3D], colors: Array[Color]) -> void:
	var design: String = FieldBuilder.design
	var L := _L()
	var W := _W()
	var RD: float = FieldBuilder.ROW_DEPTH
	var base: float = upper_base()
	var under: float = base - 2.2
	var bz: float = back_z()
	var bx: float = back_x()
	var ry: float = roof_y()
	var dark := Color(0.07, 0.07, 0.09)

	# --- Grada alta lateral (cubre también las esquinas) y pasillo bajo ella ---
	var side_len: float = 2.0 * bx
	for s: float in [-1.0, 1.0]:
		var z0: float = W * 0.5 + FieldBuilder.SIDE_STANDS + (FieldBuilder.SIDE_ROWS - OVERHANG_ROWS) * RD
		var lower_back: float = W * 0.5 + FieldBuilder.SIDE_STANDS + FieldBuilder.SIDE_ROWS * RD
		FieldBuilder.add_mesh(root, FieldBuilder.box(Vector3(side_len, under, bz - lower_back)), Vector3(0.0, under * 0.5, s * (lower_back + bz) * 0.5), dark)
		for k in UPPER_ROWS:
			var z: float = s * (z0 + k * RD)
			var top: float = base + k * UPPER_RISE
			FieldBuilder.add_mesh(root, FieldBuilder.box(Vector3(side_len, top - under, RD)), Vector3(0.0, (top + under) * 0.5, z), _seat(k))
			var x: float = -side_len * 0.5 + 0.6
			while x < side_len * 0.5 - 0.6:
				if randf() < FieldBuilder.crowd_fill:
					xforms.append(Transform3D(Basis(Vector3.UP, PI if s > 0.0 else 0.0), Vector3(x + randf_range(-0.1, 0.1), top, z)))
					colors.append(FieldBuilder._fan_color(false))
				x += UPPER_SPACING
		_fascia(root, Vector3(0.0, 0.0, s * (z0 - RD * 0.5 - 0.2)), side_len, PI if s > 0.0 else 0.0, under)

	# --- Grada alta de fondo ---
	var end_len: float = 2.0 * (W * 0.5 + FieldBuilder.SIDE_STANDS + (FieldBuilder.SIDE_ROWS - OVERHANG_ROWS) * RD)
	for s: float in [-1.0, 1.0]:
		var x0: float = L * 0.5 + FieldBuilder.END_STANDS + (FieldBuilder.END_ROWS - OVERHANG_ROWS) * RD
		var lower_back: float = L * 0.5 + FieldBuilder.END_STANDS + FieldBuilder.END_ROWS * RD
		FieldBuilder.add_mesh(root, FieldBuilder.box(Vector3(bx - lower_back, under, end_len)), Vector3(s * (lower_back + bx) * 0.5, under * 0.5, 0.0), dark)
		for k in UPPER_ROWS:
			var x: float = s * (x0 + k * RD)
			var top: float = base + k * UPPER_RISE
			FieldBuilder.add_mesh(root, FieldBuilder.box(Vector3(RD, top - under, end_len)), Vector3(x, (top + under) * 0.5, 0.0), _seat(k))
			var z: float = -end_len * 0.5 + 0.6
			while z < end_len * 0.5 - 0.6:
				if randf() < FieldBuilder.crowd_fill:
					xforms.append(Transform3D(Basis(Vector3.UP, -s * PI * 0.5), Vector3(x, top, z + randf_range(-0.1, 0.1))))
					colors.append(FieldBuilder._fan_color(s > 0.0))
				z += UPPER_SPACING
		_fascia(root, Vector3(s * (x0 - RD * 0.5 - 0.2), 0.0, 0.0), end_len, -s * PI * 0.5, under)

	# --- Muros traseros (cierran el anillo hasta el techo) ---
	var wall := FieldBuilder.home_color.darkened(0.55)
	if design == "catedral":
		wall = FieldBuilder.home_color.darkened(0.6).lerp(Color(0.42, 0.2, 0.15), 0.5) # ladrillo
	for s: float in [-1.0, 1.0]:
		FieldBuilder.add_mesh(root, FieldBuilder.box(Vector3(2.0 * bx + 1.0, ry + 1.0, 0.6)), Vector3(0.0, (ry + 1.0) * 0.5, s * (bz + 0.3)), wall)
		FieldBuilder.add_mesh(root, FieldBuilder.box(Vector3(0.6, ry + 1.0, 2.0 * bz + 1.0)), Vector3(s * (bx + 0.3), (ry + 1.0) * 0.5, 0.0), wall)

	_roof(root, design)


## Frente entre pisos: panel oscuro + franja LED de anuncios (AdBoards) a lo largo.
static func _fascia(root: Node3D, pos: Vector3, length: float, yaw: float, under: float) -> void:
	var h := 2.0
	var y: float = under + h * 0.5
	var panel := FieldBuilder.add_mesh(root, FieldBuilder.box(Vector3(length, h + 0.4, 0.3)), pos + Vector3(0.0, y, 0.0), Color(0.1, 0.1, 0.12))
	panel.rotation.y = yaw
	var seg := 7.8
	var n := int(floor(length / seg))
	var along := Vector3(cos(yaw), 0.0, -sin(yaw))
	var out := Vector3(sin(yaw), 0.0, cos(yaw)) # hacia el campo
	for k in n:
		var off: float = (k - (n - 1) * 0.5) * seg
		FieldBuilder._ad_list.append({"pos": pos + along * off + out * 0.17 + Vector3(0.0, y - 0.65, 0.0),
			"length": seg - 0.04, "yaw": yaw, "h": 1.3})


## Techo de anillo sobre las cuatro gradas.
static func _roof(root: Node3D, design: String) -> void:
	var L := _L()
	var W := _W()
	var bz: float = back_z()
	var bx: float = back_x()
	var ry: float = roof_y()
	var inner_z: float = W * 0.5 + FieldBuilder.SIDE_STANDS - ROOF_INNER
	var inner_x: float = L * 0.5 + FieldBuilder.END_STANDS - ROOF_INNER
	var roof_col := Color(0.2, 0.21, 0.24)
	match design:
		"catedral": roof_col = Color(0.27, 0.29, 0.32)
		"anillo": roof_col = Color(0.9, 0.91, 0.93)
	var glass := Color(0.92, 0.95, 1.0, 0.35)
	var lamp := _emissive(Color(1.0, 0.97, 0.88), 4.0 if FieldBuilder.time_of_day == 2 else 1.2)
	var ring := _emissive(FieldBuilder.home_color, 2.2 if FieldBuilder.time_of_day == 2 else 0.9)
	var steel := Color(0.78, 0.8, 0.83)
	# "catedral": cuatro tejados separados, las esquinas abiertas al cielo.
	var corners: bool = design != "catedral"
	var t := 0.6
	for s: float in [-1.0, 1.0]:
		var slen: float = 2.0 * bx if corners else 2.0 * inner_x
		var solid_d: float = bz - (inner_z + TRANSLUCENT)
		_no_shadow(FieldBuilder.add_mesh(root, FieldBuilder.box(Vector3(slen, t, solid_d)), Vector3(0.0, ry, s * (inner_z + TRANSLUCENT + solid_d * 0.5)), roof_col))
		_no_shadow(FieldBuilder.add_mesh(root, FieldBuilder.box(Vector3(slen, 0.12, TRANSLUCENT)), Vector3(0.0, ry, s * (inner_z + TRANSLUCENT * 0.5)), glass))
		var elen: float = 2.0 * inner_z
		var esolid: float = bx - (inner_x + TRANSLUCENT)
		_no_shadow(FieldBuilder.add_mesh(root, FieldBuilder.box(Vector3(esolid, t, elen)), Vector3(s * (inner_x + TRANSLUCENT + esolid * 0.5), ry, 0.0), roof_col))
		_no_shadow(FieldBuilder.add_mesh(root, FieldBuilder.box(Vector3(TRANSLUCENT, 0.12, elen)), Vector3(s * (inner_x + TRANSLUCENT * 0.5), ry, 0.0), glass))
		# Luces del borde (sustituyen a las torres de focos).
		_glow_box(root, Vector3(slen, 0.35, 0.5), Vector3(0.0, ry - 0.4, s * inner_z), lamp)
		_glow_box(root, Vector3(0.5, 0.35, elen), Vector3(s * inner_x, ry - 0.4, 0.0), lamp)
		match design:
			"cuenco":
				# Vigas a la vista por debajo del techo, del muro al borde.
				var beam := Color(0.55, 0.57, 0.6)
				var n := int(slen / 10.0)
				for k in n + 1:
					var px: float = -slen * 0.5 + k * slen / float(n)
					_no_shadow(FieldBuilder.add_mesh(root, FieldBuilder.box(Vector3(0.45, 0.9, bz - inner_z)), Vector3(px, ry - 0.75, s * (inner_z + bz) * 0.5), beam))
				var en := int(elen / 10.0)
				for k in en + 1:
					var pz: float = -elen * 0.5 + k * elen / float(en)
					_no_shadow(FieldBuilder.add_mesh(root, FieldBuilder.box(Vector3(bx - inner_x, 0.9, 0.45)), Vector3(s * (inner_x + bx) * 0.5, ry - 0.75, pz), beam))
			"catedral":
				# Cercha de acero sobre el borde: cordón inferior y superior + diagonales.
				_truss(root, Vector3(0.0, ry + 0.3, s * inner_z), Vector3.RIGHT, slen, steel)
				_truss(root, Vector3(s * inner_x, ry + 0.3, 0.0), Vector3.BACK, elen, steel)
			"anillo":
				# Anillo de luz del color del club por el borde del techo.
				_glow_box(root, Vector3(slen, 1.1, 0.3), Vector3(0.0, ry + 0.2, s * (inner_z - 0.1)), ring)
				_glow_box(root, Vector3(0.3, 1.1, elen), Vector3(s * (inner_x - 0.1), ry + 0.2, 0.0), ring)


static func _truss(root: Node3D, c0: Vector3, dir: Vector3, length: float, col: Color) -> void:
	var up := Vector3(0.0, 3.2, 0.0)
	var a0: Vector3 = c0 - dir * length * 0.5
	FieldBuilder._tube(root, a0, c0 + dir * length * 0.5, 0.18, col)
	FieldBuilder._tube(root, a0 + up, c0 + dir * length * 0.5 + up, 0.18, col)
	var bays := maxi(int(length / 6.0), 1)
	var step: float = length / float(bays)
	for k in bays:
		var a: Vector3 = a0 + dir * (k * step)
		var b: Vector3 = a + dir * step
		if k % 2 == 0:
			FieldBuilder._tube(root, a, b + up, 0.1, col)
		else:
			FieldBuilder._tube(root, a + up, b, 0.1, col)
		FieldBuilder._tube(root, b, b + up, 0.08, col)


## Marcador colgado del techo sobre el fondo de -X: {x, y}.
static func scoreboard_spot() -> Vector2:
	return Vector2(-(_L() * 0.5 + FieldBuilder.END_STANDS + 2.0), roof_y() - 6.0)
