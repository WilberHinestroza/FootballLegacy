class_name FieldBuilder
extends RefCounted
## Construye el estadio con primitivas: césped, líneas, porterías, muros y grada.
## Cuando tengas modelos propios (Blender/ComfyUI) puedes sustituir estas piezas.

const LAYER_WALLS := 1
const LAYER_GROUND := 8



## Devuelve las dos áreas de gol: [0] = portería en +X (marca el equipo 0), [1] = portería en -X.
## Hora del partido: 0 día, 1 atardecer, 2 noche con focos. El partido la elige (o al azar).
## Humo de bengala: bola suave del color de la partícula, siempre de cara a la cámara.
const SMOKE_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
void vertex() {
	mat4 m = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	m = m * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * m;
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * smoothstep(1.0, 0.0, d) * 0.9;
}
"""
static var SMOKE_SHADER: Shader:
	get:
		if _smoke_shader == null:
			_smoke_shader = Shader.new()
			_smoke_shader.code = SMOKE_SHADER_CODE
		return _smoke_shader
static var _smoke_shader: Shader
static var time_of_day := -1


static func build(root: Node3D) -> Array[Area3D]:
	if time_of_day < 0:
		time_of_day = randi() % 3
	_apply_stars()
	_environment(root)
	_pitch(root)
	_lines(root)
	_ad_list = []
	_walls(root)
	_banner_plan = _plan_banners()
	_stands(root)
	AdBoards.build(root, _ad_list)
	_build_banners(root)
	_extras(root)
	_confetti(root)
	if stars >= 2:
		_flares(root)
	if stars >= 3:
		_scoreboard(root)
	var areas: Array[Area3D] = [_goal(root, 1.0), _goal(root, -1.0)]
	return areas


# ---------- utilidades ----------

static func mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func add_mesh(parent: Node, mesh: Mesh, pos: Vector3, color: Color, unshaded := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color, unshaded)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func add_static_box(parent: Node, size: Vector3, pos: Vector3, layer := LAYER_WALLS) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	parent.add_child(body)
	return body


# ---------- piezas ----------

static func _environment(root: Node3D) -> void:
	# Colores del cielo y del sol según la hora
	var top := Color(0.22, 0.47, 0.88)
	var horizon := Color(0.68, 0.8, 0.95)
	var sun_color := Color(1.0, 0.98, 0.94)
	var sun_rot := Vector3(-52.0, -35.0, 0.0)
	var sun_energy := 1.2
	var ambient := 0.8
	match time_of_day:
		1: # atardecer
			top = Color(0.26, 0.36, 0.68)
			horizon = Color(1.0, 0.64, 0.4)
			sun_color = Color(1.0, 0.78, 0.55)
			sun_rot = Vector3(-24.0, -60.0, 0.0)
			sun_energy = 1.15
			ambient = 0.7
		2: # noche: los focos iluminan desde arriba
			top = Color(0.015, 0.025, 0.07)
			horizon = Color(0.07, 0.09, 0.18)
			sun_color = Color(0.92, 0.95, 1.0)
			sun_rot = Vector3(-62.0, -20.0, 0.0)
			sun_energy = 1.05
			ambient = 0.55
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon.lerp(Color(0.3, 0.35, 0.3), 0.5)
	sky_mat.ground_bottom_color = Color(0.2, 0.28, 0.2) * (0.3 if time_of_day == 2 else 1.0)
	if time_of_day == 2:
		sky_mat.sun_angle_max = 0.0 # sin disco solar de noche
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient
	if time_of_day == 2:
		# De noche el cielo apenas ilumina: luz ambiente propia, fría
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.5, 0.55, 0.68)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Brillo de los focos y los flashes. El glow es un pase de pantalla completa
	# caro en el móvil: solo de noche, que es cuando de verdad se nota.
	env.glow_enabled = time_of_day == 2
	env.glow_intensity = 0.6 if time_of_day == 2 else 0.3
	env.glow_hdr_threshold = 1.2
	# Algo más de contraste y color, y una bruma suave que da profundidad a las gradas
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	env.fog_enabled = true
	env.fog_light_color = horizon.lerp(Color(0.5, 0.55, 0.6), 0.4)
	env.fog_density = 0.0035 if time_of_day != 2 else 0.005
	env.fog_sky_affect = 0.0

	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_energy = sun_energy
	sun.light_color = sun_color
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	if OS.has_feature("mobile"):
		# 4 cascadas = los jugadores se dibujan hasta 4 veces más para la sombra.
		# Con 2 y algo menos de alcance la sombra cerca de la cámara se ve igual.
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 38.0
	root.add_child(sun)


const GRASS_SHADER := preload("res://match3d/shaders/grass.gdshader")
const NET_SHADER := preload("res://match3d/shaders/net.gdshader")
const CROWD_SHADER := preload("res://match3d/shaders/crowd.gdshader")
const FLAG_SHADER := preload("res://match3d/shaders/flag.gdshader")
const FLASH_SHADER := preload("res://match3d/shaders/flash.gdshader")


static func _grass(stripes: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GRASS_SHADER
	m.set_shader_parameter("half_length", SoccerMatch.FIELD_LENGTH * 0.5)
	m.set_shader_parameter("stripe_width", SoccerMatch.FIELD_LENGTH / 12.0)
	m.set_shader_parameter("stripes_on", 1.0 if stripes else 0.0)
	m.set_shader_parameter("wear", 1.0 if stripes else 0.0)
	if not stripes:
		m.set_shader_parameter("dark_col", Color(0.2, 0.47, 0.19))
	return m


static func _pitch(root: Node3D) -> void:
	var L := SoccerMatch.FIELD_LENGTH
	var W := SoccerMatch.FIELD_WIDTH
	add_static_box(root, Vector3(200.0, 1.0, 200.0), Vector3(0.0, -0.5, 0.0), LAYER_GROUND)

	var outer := PlaneMesh.new()
	outer.size = Vector2(L + 40.0, W + 40.0)
	var om := add_mesh(root, outer, Vector3(0.0, -0.02, 0.0), Color.WHITE)
	om.material_override = _grass(false)

	var field := PlaneMesh.new()
	field.size = Vector2(L + 3.0, W + 3.0)
	var fm := add_mesh(root, field, Vector3.ZERO, Color.WHITE)
	fm.material_override = _grass(true)


static func _line(root: Node3D, sx: float, sz: float, x: float, z: float) -> void:
	add_mesh(root, box(Vector3(sx, 0.02, sz)), Vector3(x, 0.01, z), Color(0.97, 0.97, 0.97))


static func _lines(root: Node3D) -> void:
	var L := SoccerMatch.FIELD_LENGTH
	var W := SoccerMatch.FIELD_WIDTH
	var bd := SoccerMatch.BOX_DEPTH
	var bw := SoccerMatch.BOX_WIDTH
	var t := 0.12
	_line(root, L + t, t, 0.0, -W * 0.5)
	_line(root, L + t, t, 0.0, W * 0.5)
	_line(root, t, W, -L * 0.5, 0.0)
	_line(root, t, W, L * 0.5, 0.0)
	_line(root, t, W, 0.0, 0.0)

	for s: float in [-1.0, 1.0]:
		# Área grande
		_line(root, t, bw, s * (L * 0.5 - bd), 0.0)
		_line(root, bd, t, s * (L * 0.5 - bd * 0.5), -bw * 0.5)
		_line(root, bd, t, s * (L * 0.5 - bd * 0.5), bw * 0.5)
		# Área pequeña
		var sd := SoccerMatch.SMALL_BOX_DEPTH
		var sbw := SoccerMatch.SMALL_BOX_WIDTH
		_line(root, t, sbw, s * (L * 0.5 - sd), 0.0)
		_line(root, sd, t, s * (L * 0.5 - sd * 0.5), -sbw * 0.5)
		_line(root, sd, t, s * (L * 0.5 - sd * 0.5), sbw * 0.5)
		# Punto de penalti
		var spot := CylinderMesh.new()
		spot.top_radius = 0.12
		spot.bottom_radius = 0.12
		spot.height = 0.02
		var spot_x := s * (L * 0.5 - SoccerMatch.PENALTY_DIST)
		add_mesh(root, spot, Vector3(spot_x, 0.01, 0.0), Color.WHITE)
		# Semicírculo del área: solo la parte fuera del área grande
		var r := 3.6
		var edge := (bd - SoccerMatch.PENALTY_DIST) / r # coseno donde corta la línea del área
		var a := acos(clampf(edge, -1.0, 1.0))
		_arc(root, Vector3(spot_x, 0.0, 0.0), r, PI - a if s > 0.0 else -a, PI + a if s > 0.0 else a, 14, t)
		# Esquinas
		for zs: float in [-1.0, 1.0]:
			var corner := Vector3(s * L * 0.5, 0.0, zs * W * 0.5)
			var a0 := atan2(-zs, -s)
			_arc(root, corner, 0.9, a0 - PI * 0.25, a0 + PI * 0.25, 5, t)

	var circle := TorusMesh.new()
	circle.inner_radius = SoccerMatch.CENTER_RADIUS - 0.06
	circle.outer_radius = SoccerMatch.CENTER_RADIUS + 0.06
	circle.rings = 64
	var ci := add_mesh(root, circle, Vector3(0.0, 0.0, 0.0), Color(0.97, 0.97, 0.97))
	ci.scale = Vector3(1.0, 0.15, 1.0)
	var center := CylinderMesh.new()
	center.top_radius = 0.15
	center.bottom_radius = 0.15
	center.height = 0.02
	add_mesh(root, center, Vector3(0.0, 0.01, 0.0), Color.WHITE)


## Línea curva hecha de tramos rectos. Ángulos en radianes sobre el plano XZ (0 = +X, hacia +Z).
static func _arc(root: Node3D, center: Vector3, radius: float, a0: float, a1: float, segments: int, t: float) -> void:
	for i in segments:
		var u0 := a0 + (a1 - a0) * i / segments
		var u1 := a0 + (a1 - a0) * (i + 1) / segments
		var p0 := center + Vector3(cos(u0), 0.0, sin(u0)) * radius
		var p1 := center + Vector3(cos(u1), 0.0, sin(u1)) * radius
		var mi := add_mesh(root, box(Vector3(p0.distance_to(p1) + t * 0.5, 0.02, t)), (p0 + p1) * 0.5 + Vector3(0.0, 0.01, 0.0),
				Color(0.97, 0.97, 0.97))
		mi.rotation.y = -atan2(p1.z - p0.z, p1.x - p0.x)


## Banderines de córner y torres de focos.
## Tamaño del estadio según sus estrellas: de un campo de barrio (1) a un gran estadio (5).
static func _apply_stars() -> void:
	stars = clampi(stars, 1, 5)
	SIDE_ROWS = [4, 6, 8, 10, 13][stars - 1]
	END_ROWS = [2, 3, 5, 8, 10][stars - 1]


static func _extras(root: Node3D) -> void:
	var L := SoccerMatch.FIELD_LENGTH
	var W := SoccerMatch.FIELD_WIDTH
	var pole := CylinderMesh.new()
	pole.top_radius = 0.025
	pole.bottom_radius = 0.025
	pole.height = 1.5
	var flag := _flag_mesh(0.0, 0.42, 0.3, 1.48, Color(1.0, 0.82, 0.1))
	var flag_mat := ShaderMaterial.new()
	flag_mat.shader = FLAG_SHADER
	flag_mat.set_shader_parameter("stripe_color", Color(0.95, 0.25, 0.15))
	flag_mat.set_shader_parameter("swing_amount", 0.0)
	flag_mat.set_shader_parameter("wave", 0.7)
	for xs: float in [-1.0, 1.0]:
		for zs: float in [-1.0, 1.0]:
			var base := Vector3(xs * L * 0.5, 0.0, zs * W * 0.5)
			add_mesh(root, pole, base + Vector3(0.0, 0.75, 0.0), Color(0.95, 0.95, 0.95))
			var f := MeshInstance3D.new()
			f.mesh = flag
			f.material_override = flag_mat
			f.position = base
			f.rotation.y = 0.0 if xs < 0.0 else PI # la tela hacia dentro del campo
			root.add_child(f)

	# Focos en las cuatro esquinas, detrás de las gradas
	var mast := CylinderMesh.new()
	mast.top_radius = 0.25
	mast.bottom_radius = 0.4
	mast.height = [12.0, 18.0, 24.0, 30.0, 34.0][stars - 1]
	var lamp := mat(Color(1.0, 0.98, 0.85), true)
	if time_of_day == 2:
		# Encendidos: emisión por encima de 1 para que brillen (glow)
		lamp = StandardMaterial3D.new()
		lamp.albedo_color = Color(1.0, 0.98, 0.9)
		lamp.emission_enabled = true
		lamp.emission = Color(1.0, 0.97, 0.88)
		lamp.emission_energy_multiplier = 4.0
	for xs: float in [-1.0, 1.0]:
		for zs: float in [-1.0, 1.0]:
			var base := Vector3(xs * (L * 0.5 + 14.0), 0.0, zs * (W * 0.5 + 21.0))
			add_mesh(root, mast, base + Vector3(0.0, mast.height * 0.5, 0.0), Color(0.55, 0.57, 0.6))
			var panel := MeshInstance3D.new()
			panel.mesh = box(Vector3(5.0, 3.0, 0.4))
			panel.material_override = lamp
			root.add_child(panel)
			panel.position = base + Vector3(0.0, mast.height + 0.5, 0.0)
			panel.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
			panel.rotate_object_local(Vector3.RIGHT, 0.35)


## Distancias del estadio (metros desde la línea): banda con banquillos y cámaras, vallas, grada.
const TUNNEL_X := 0.5     # centro del túnel de vestuarios (banda de los banquillos)
const TUNNEL_GAP := 2.9   # medio ancho del hueco en la grada para el túnel
const TUNNEL_ROWS := 4    # filas de grada que corta (el pasillo pasa por debajo de las demás)
const SIDE_BOARDS := 5.0   # vallas de banda (entre medias: banquillos, cuarto árbitro, cámaras)
const END_BOARDS := 4.5    # vallas de fondo (fotógrafos y cámaras detrás de la portería)
const SIDE_STANDS := 6.5   # primera fila de la grada lateral
const END_STANDS := 6.0    # primera fila de la grada de fondo
## Filas de grada: dependen de las estrellas del estadio (ver _apply_stars).
static var SIDE_ROWS := 10
static var END_ROWS := 8

## Estadio del partido (lo pone SoccerMatch desde la config antes de build):
## estrellas de infraestructura 1-5, colores del club local, color de la afición
## visitante y qué parte del aforo se llena (0-1).
static var stars := 4
static var home_color := Color(0.86, 0.13, 0.16)
static var home_color2 := Color(0.95, 0.95, 0.95)
static var away_color := Color(0.16, 0.38, 0.92)
static var crowd_fill := 0.85
const ROW_DEPTH := 1.2
## Lado de los trozos del público (ver _stands).
const CROWD_CHUNK := 35.0
## Distancia (al centro de cada trozo de grada) a partir de la cual el público pasa
## a la versión barata de cajas.
const CROWD_NEAR := 45.0
const ROW_RISE := 0.6


## Vallas LED de este estadio: [{pos, length, yaw, h}] (ver AdBoards.build).
static var _ad_list: Array = []


static func _walls(root: Node3D) -> void:
	var L := SoccerMatch.FIELD_LENGTH
	var W := SoccerMatch.FIELD_WIDTH
	var h := 8.0
	var side_z := W * 0.5 + SIDE_BOARDS
	var end_x := L * 0.5 + END_BOARDS
	var boards := _ad_list

	for s: float in [-1.0, 1.0]:
		# Muro lateral invisible + vallas publicitarias
		add_static_box(root, Vector3(L + 2.0 * END_BOARDS + 2.0, h, 1.0), Vector3(0.0, h * 0.5, s * (side_z + 0.5)))
		var seg := 5.0
		var count := int(ceil((L + 2.0 * END_BOARDS) / seg))
		for i in count:
			var x := -(L + 2.0 * END_BOARDS) * 0.5 + (i + 0.5) * seg
			if s < 0.0 and absf(x - TUNNEL_X) < 1.0:
				continue # hueco en las vallas para la salida del túnel
			boards.append({"pos": Vector3(x, 0.5, s * (side_z + 0.08)), "length": seg - 0.05, "yaw": PI if s > 0.0 else 0.0})
		# Muro de fondo con vallas (la portería queda por delante)
		add_static_box(root, Vector3(1.0, h, W + 2.0 * SIDE_BOARDS + 2.0), Vector3(s * (end_x + 0.5), h * 0.5, 0.0))
		var ecount := int(ceil((W + 2.0 * SIDE_BOARDS) / seg))
		for i in ecount:
			var z := -(W + 2.0 * SIDE_BOARDS) * 0.5 + (i + 0.5) * seg
			boards.append({"pos": Vector3(s * (end_x + 0.08), 0.5, z), "length": seg - 0.05, "yaw": -s * PI * 0.5})


static func _stands(root: Node3D) -> void:
	var L := SoccerMatch.FIELD_LENGTH
	var W := SoccerMatch.FIELD_WIDTH
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var concrete := [Color(0.55, 0.57, 0.6), Color(0.48, 0.5, 0.54)]
	# Asientos con los colores del local (desde 3 estrellas), con franjas del segundo color
	var seat_a := home_color.darkened(0.3)
	var seat_b := home_color.darkened(0.42)
	var band := home_color2.darkened(0.15)
	var row_col := func(k: int) -> Color:
		if stars < 3:
			return seat_a if (stars == 2 and k == 0) else concrete[k % 2]
		return band if k % 4 == 3 else (seat_a if k % 2 == 0 else seat_b)
	var side_len := L + 2.0 * END_STANDS
	var end_len := W + 2.0 * SIDE_STANDS

	# Gradas laterales
	for s: float in [-1.0, 1.0]:
		for k in SIDE_ROWS:
			var z := s * (W * 0.5 + SIDE_STANDS + k * ROW_DEPTH)
			var top := 0.9 + k * ROW_RISE
			if s < 0.0 and k < TUNNEL_ROWS:
				# Filas cortadas por el túnel: dos tramos a los lados del hueco
				var gap_l := TUNNEL_X - TUNNEL_GAP
				var gap_r := TUNNEL_X + TUNNEL_GAP
				var left_len := gap_l + side_len * 0.5
				var right_len := side_len * 0.5 - gap_r
				add_mesh(root, box(Vector3(left_len, top, ROW_DEPTH)), Vector3(-side_len * 0.5 + left_len * 0.5, top * 0.5, z), row_col.call(k))
				add_mesh(root, box(Vector3(right_len, top, ROW_DEPTH)), Vector3(gap_r + right_len * 0.5, top * 0.5, z), row_col.call(k))
			else:
				add_mesh(root, box(Vector3(side_len, top, ROW_DEPTH)), Vector3(0.0, top * 0.5, z), row_col.call(k))
			var x := -side_len * 0.5 + 0.5
			while x < side_len * 0.5 - 0.5:
				# Hueco del túnel en el centro de la grada de los banquillos
				var tunnel := s < 0.0 and absf(x - TUNNEL_X) < TUNNEL_GAP + 0.3 and k < TUNNEL_ROWS
				if not tunnel and not _under_banner(s, k, x) and randf() < crowd_fill:
					var face := Basis(Vector3.UP, PI if s > 0.0 else 0.0) # mirando al campo
					xforms.append(Transform3D(face, Vector3(x + randf_range(-0.1, 0.1), top, z)))
					colors.append(_fan_color(false))
				x += 0.75
		# Techo sobre la grada lateral, con pilares: la principal desde 2 estrellas, las dos desde 3
		var depth := SIDE_ROWS * ROW_DEPTH
		var roof_z := s * (W * 0.5 + SIDE_STANDS + depth * 0.5)
		var roof_h := 0.9 + SIDE_ROWS * ROW_RISE + 4.5
		# Luces LED del color del local a lo largo de la primera fila (4-5 estrellas)
		if stars >= 4:
			var led := StandardMaterial3D.new()
			led.albedo_color = home_color
			led.emission_enabled = true
			led.emission = home_color
			led.emission_energy_multiplier = 1.6
			# En la grada de los banquillos se corta en la boca del túnel: entera
			# cruzaba el pasillo como una franja de color a la altura de la cintura.
			var spans: Array = [[-side_len * 0.5, side_len * 0.5]]
			if s < 0.0:
				spans = [[-side_len * 0.5, TUNNEL_X - TUNNEL_GAP], [TUNNEL_X + TUNNEL_GAP, side_len * 0.5]]
			for sp: Array in spans:
				var a: float = sp[0]
				var b: float = sp[1]
				var strip := MeshInstance3D.new()
				strip.mesh = box(Vector3(b - a, 0.22, 0.06))
				strip.material_override = led
				strip.position = Vector3((a + b) * 0.5, 0.62, s * (W * 0.5 + SIDE_STANDS - ROW_DEPTH * 0.5 - 0.04))
				root.add_child(strip)
		if stars < 2 or (stars == 2 and s > 0.0):
			continue
		var roof_col := Color(0.82, 0.84, 0.88) if stars < 4 else home_color.lerp(Color(0.85, 0.87, 0.9), 0.55)
		var roof := add_mesh(root, box(Vector3(side_len + 2.0, 0.3, depth + 2.0)), Vector3(0.0, roof_h, roof_z), roof_col)
		roof.rotation.x = s * 0.1
		# Anillo LED colgado del borde del techo, de cara al campo (4-5 estrellas)
		if stars >= 4:
			var front := depth * 0.5 + 1.0
			var ring_h := 1.3
			var ring_y := roof_h + front * sin(0.1) - 0.15 - ring_h * 0.5
			var seg_len := 7.8
			var n := int(floor(side_len / seg_len))
			for k in n:
				var rx := (k - (n - 1) * 0.5) * seg_len
				_ad_list.append({"pos": Vector3(rx, ring_y, s * (W * 0.5 + SIDE_STANDS - 1.0 + 0.1)),
					"length": seg_len - 0.04, "yaw": PI if s > 0.0 else 0.0, "h": ring_h})
		for k in 9:
			var px := lerpf(-side_len * 0.5, side_len * 0.5, k / 8.0)
			add_mesh(root, box(Vector3(0.4, roof_h, 0.4)), Vector3(px, roof_h * 0.5, s * (W * 0.5 + SIDE_STANDS + depth - 0.3)), Color(0.6, 0.62, 0.66))
	# Gradas de fondo
	for s: float in [-1.0, 1.0]:
		for k in END_ROWS:
			var x := s * (L * 0.5 + END_STANDS + k * ROW_DEPTH)
			var top := 0.9 + k * ROW_RISE
			add_mesh(root, box(Vector3(ROW_DEPTH, top, end_len)), Vector3(x, top * 0.5, 0.0), row_col.call(k))
			var z := -end_len * 0.5 + 0.5
			while z < end_len * 0.5 - 0.5:
				if randf() < crowd_fill:
					var face := Basis(Vector3.UP, -s * PI * 0.5)
					xforms.append(Transform3D(face, Vector3(x, top, z + randf_range(-0.1, 0.1))))
					colors.append(_fan_color(s > 0.0)) # la afición visitante, en el fondo de +X
				z += 0.75
		if stars == 5:
			# Gran estadio: también los fondos cubiertos
			var edepth := END_ROWS * ROW_DEPTH
			var eroof_h := 0.9 + END_ROWS * ROW_RISE + 3.5
			var eroof := add_mesh(root, box(Vector3(edepth + 2.0, 0.3, end_len + 2.0)),
					Vector3(s * (L * 0.5 + END_STANDS + edepth * 0.5), eroof_h, 0.0), home_color.lerp(Color(0.85, 0.87, 0.9), 0.55))
			eroof.rotation.z = -s * 0.1
			for k in 6:
				var pz := lerpf(-end_len * 0.5, end_len * 0.5, k / 5.0)
				add_mesh(root, box(Vector3(0.4, eroof_h, 0.4)), Vector3(s * (L * 0.5 + END_STANDS + edepth - 0.3), eroof_h * 0.5, pz), Color(0.6, 0.62, 0.66))

	# Muros traseros que cierran el estadio (que no se vea el vacío detrás de la grada)
	var back := Color(0.42, 0.45, 0.52) if stars < 3 else home_color.darkened(0.55)
	var trim := Color(0.85, 0.87, 0.9)
	for s: float in [-1.0, 1.0]:
		var bz := s * (W * 0.5 + SIDE_STANDS + SIDE_ROWS * ROW_DEPTH)
		var roofed := stars >= 3 or (stars == 2 and s < 0.0)
		var bh := 0.9 + SIDE_ROWS * ROW_RISE + (4.5 if roofed else 1.2) # sin techo, muro bajo
		add_mesh(root, box(Vector3(side_len + 2.0, bh, 0.5)), Vector3(0.0, bh * 0.5, bz), back)
		add_mesh(root, box(Vector3(side_len + 2.0, 0.25, 0.7)), Vector3(0.0, bh, bz), trim)
		var bx := s * (L * 0.5 + END_STANDS + END_ROWS * ROW_DEPTH)
		var eh := 0.9 + END_ROWS * ROW_RISE + (2.5 if stars >= 3 else 1.0)
		add_mesh(root, box(Vector3(0.5, eh, end_len + 26.0)), Vector3(bx, eh * 0.5, 0.0), back)
		add_mesh(root, box(Vector3(0.7, 0.25, end_len + 26.0)), Vector3(bx, eh, 0.0), trim)

	# Público en MultiMesh por trozos de grada (~35 m): pocas llamadas de dibujo y la
	# cámara descarta los trozos que no ve (uno solo se dibujaba siempre entero).
	var m := ShaderMaterial.new()
	m.shader = CROWD_SHADER
	root.set_meta("crowd_mat", m)
	var fan := _fan_mesh()
	var fan_far := _fan_mesh_far()
	var chunks := {}
	for i in xforms.size():
		var o := xforms[i].origin
		var key := Vector2i(floori(o.x / CROWD_CHUNK), floori(o.z / CROWD_CHUNK))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(i)
	var first := true
	# Dos niveles de detalle por trozo (7-nov): la persona con brazos (48 triángulos)
	# solo en los trozos cerca de la cámara; de lejos, la versión de cajas (22), que
	# ahí ocupa unos pocos píxeles. Godot cambia uno por otro según la distancia.
	for key: Vector2i in chunks:
		var ids: Array = chunks[key]
		for far: bool in [false, true]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = fan_far if far else fan
			mm.instance_count = ids.size()
			for j in ids.size():
				mm.set_instance_transform(j, xforms[ids[j]])
				mm.set_instance_color(j, colors[ids[j]])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = m
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if far:
				mmi.visibility_range_begin = CROWD_NEAR
				mmi.visibility_range_begin_margin = 3.0
			else:
				mmi.visibility_range_end = CROWD_NEAR
				mmi.visibility_range_end_margin = 3.0
			mmi.name = ("Crowd" if first else "CrowdPart") + ("Far" if far else "")
			root.add_child(mmi, true)
		first = false
	_fan_flags(root, xforms)
	_flashes(root, xforms)


## Persona de la grada (7-nov: antes tres cajas apiladas, "los aficionados son
## cubos"): tronco ahusado de 4 caras, cabeza redondeada con pelo y dos brazos que
## el shader levanta girando en el hombro (celebración, la ola). Pies en el origen,
## mira a +Z local; sin las caras que nunca se ven (espalda, base): 48 triángulos.
## UV.x = pieza (0 camiseta, 1 piel, 2 pelo), UV.y = brazo (-1 izq, 1 der, 0 no).
static func _fan_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv: Vector2) -> void:
		st.set_uv(uv)
		for v: Vector3 in [a, c, b, a, d, c]:   # Godot: cara delantera en sentido horario
			st.add_vertex(v)
	var tri := func(a: Vector3, b: Vector3, c: Vector3, uv: Vector2) -> void:
		st.set_uv(uv)
		for v: Vector3 in [a, c, b]:
			st.add_vertex(v)
	var ring := func(y: float, rx: float, rz: float, zoff: float, n: int) -> Array:
		var out := []
		for k in n + 1:
			var th := -PI * 0.5 + PI * float(k) / float(n)
			out.append(Vector3(sin(th) * rx, y, cos(th) * rz + zoff))
		return out
	var shirt := Vector2(0, 0)
	var skin := Vector2(1, 0)
	var hair := Vector2(2, 0)
	# Tronco: cintura -> pecho -> cuello (la banda de arriba hace de hombros)
	var r0: Array = ring.call(0.0, 0.16, 0.11, 0.0, 4)
	var r1: Array = ring.call(0.36, 0.205, 0.13, 0.0, 4)
	var r2: Array = ring.call(0.47, 0.075, 0.06, 0.0, 4)
	for k in 4:
		quad.call(r0[k], r0[k + 1], r1[k + 1], r1[k], shirt)
		quad.call(r1[k], r1[k + 1], r2[k + 1], r2[k], shirt)
	# Cabeza: barbilla -> mejillas -> sienes -> coronilla, de frente (cara) y tapa
	# trasera (nuca con pelo)
	var ha: Array = ring.call(0.56, 0.095, 0.095, 0.0, 4)
	var hb: Array = ring.call(0.67, 0.09, 0.088, -0.005, 4)
	var top := Vector3(0.0, 0.745, -0.02)
	var chin := Vector3(0.0, 0.485, 0.012)
	for k in 4:
		var front := k == 1 or k == 2
		tri.call(ha[k + 1], ha[k], chin, skin)
		quad.call(ha[k], ha[k + 1], hb[k + 1], hb[k], Vector2(2, 0.5) if front else hair)
		tri.call(hb[k], hb[k + 1], top, hair)
	tri.call(ha[4], hb[0], hb[4], hair)     # nuca
	tri.call(ha[4], ha[0], hb[0], hair)
	tri.call(hb[4], hb[0], top, hair)
	tri.call(ha[0], ha[4], chin, skin)
	# Brazos colgando a los lados: manga + antebrazo (piel) de frente y cara exterior
	for side: float in [-1.0, 1.0]:
		var arm := Vector2(0, side)
		var arm_skin := Vector2(1, side)
		var sx := side * 0.215
		var w := 0.075
		var sh_top := Vector3(sx, 0.43, 0.03)
		var elbow := Vector3(sx + side * 0.025, 0.25, 0.05)
		var hand := Vector3(sx + side * 0.03, 0.09, 0.07)
		var o := Vector3(side * w * 0.5, 0.0, 0.0)
		var f := Vector3(0.0, 0.0, 0.04)
		# de frente (orden según el lado para que la cara mire a +Z)
		if side > 0.0:
			quad.call(sh_top - o + f, elbow - o + f, elbow + o + f, sh_top + o + f, arm)
			quad.call(elbow - o + f, hand - o + f, hand + o + f, elbow + o + f, arm_skin)
			tri.call(sh_top + o + f, hand + o + f, hand + o - f, arm)
			tri.call(sh_top + o + f, hand + o - f, sh_top + o - f, arm)
		else:
			quad.call(sh_top - o + f, sh_top + o + f, elbow + o + f, elbow - o + f, arm)
			quad.call(elbow - o + f, elbow + o + f, hand + o + f, hand - o + f, arm_skin)
			tri.call(sh_top - o + f, hand - o - f, hand - o + f, arm)
			tri.call(sh_top - o + f, sh_top - o - f, hand - o - f, arm)
	st.generate_normals()
	return st.commit()


## La de lejos: tronco, hombros y cabeza en cajas (22 triángulos), con las mismas
## marcas de UV que _fan_mesh para el shader (camiseta / piel).
static func _fan_mesh_far() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)
	var back_bottom := [Vector3(0, 0, -1), Vector3(0, -1, 0)]
	st.set_uv(Vector2(0, 0))
	_st_box(st, Vector3(0.0, 0.22, 0.0), Vector3(0.36, 0.44, 0.26), back_bottom + [Vector3(0, 1, 0)])
	_st_box(st, Vector3(0.0, 0.44, 0.0), Vector3(0.46, 0.1, 0.27), back_bottom)
	st.set_uv(Vector2(1, 0))
	_st_box(st, Vector3(0.0, 0.63, 0.01), Vector3(0.2, 0.22, 0.2), back_bottom)
	st.generate_normals()
	return st.commit()


static func _st_box(st: SurfaceTool, c: Vector3, size: Vector3, skip: Array = []) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)], [Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)], [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
	]
	for f: Array in faces:
		var n: Vector3 = f[0]
		if skip.has(n):
			continue
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var p := [c + (n - u - v) * h, c + (n + u - v) * h, c + (n + u + v) * h, c + (n - u + v) * h]
		for i: int in [0, 2, 1, 0, 3, 2]:
			st.add_vertex(p[i])


## La red del fondo se hincha donde entra el balón (y se calma en un segundo).
static func net_hit(area: Area3D, ball_pos: Vector3) -> void:
	var goal := area.get_parent()
	if not goal.has_meta("net_back"):
		return
	var m: ShaderMaterial = goal.get_meta("net_back")
	var size: Vector2 = goal.get_meta("net_size")
	m.set_shader_parameter("hit", Vector2(clampf((ball_pos.z + size.x * 0.5) / size.x, 0.0, 1.0),
			clampf(ball_pos.y / size.y, 0.05, 0.95)))
	var tw := goal.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("pulse", v), 1.0, 0.0, 1.2) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## La ola en la grada (0 nada, 1 a tope).
## ---------- tifo ----------

const TIFO_SHADER := preload("res://match3d/shaders/tifo.gdshader")
const TIFO_DESIGNS := ["leon", "aguila", "corona", "antorcha"]
## Diseño del tifo del local ("" = según el nombre del club). Las máscaras salen de ComfyUI.
static var tifo_design := ""


## Lona del tifo sobre el fondo local (-X), recogida (ver set_tifo). Solo desde 3 estrellas.
static func build_tifo(root: Node3D, club_name: String) -> void:
	if stars < 3:
		return
	var designs: Array = []
	for d: String in TIFO_DESIGNS:
		if ResourceLoader.exists("res://assets/tifos/%s.png" % d):
			designs.append(d)
	if designs.is_empty():
		return
	var design := tifo_design if tifo_design in designs else String(designs[absi(hash(club_name)) % designs.size()])
	var L := SoccerMatch.FIELD_LENGTH
	var W := SoccerMatch.FIELD_WIDTH
	var s := -1.0
	var dx := END_ROWS * ROW_DEPTH
	var dy := END_ROWS * ROW_RISE
	var slope := sqrt(dx * dx + dy * dy)
	var width := (W + 2.0 * SIDE_STANDS) * 0.94
	var q := QuadMesh.new()
	q.size = Vector2(width, slope)
	q.subdivide_width = 24
	q.subdivide_depth = 6
	var mi := MeshInstance3D.new()
	mi.name = "Tifo"
	mi.mesh = q
	var u := Vector3(s * dx, dy, 0.0).normalized() # sube por la grada
	var r := Vector3(0.0, 0.0, s)
	mi.transform = Transform3D(Basis(r, u, r.cross(u)), Vector3(s * (L * 0.5 + END_STANDS - ROW_DEPTH * 0.5 + dx * 0.5), 0.9 + dy * 0.5 + 1.25, 0.0))
	var mat := ShaderMaterial.new()
	mat.shader = TIFO_SHADER
	mat.set_shader_parameter("mask", load("res://assets/tifos/%s.png" % design))
	mat.set_shader_parameter("c1", home_color)
	mat.set_shader_parameter("c2", home_color2)
	mat.set_shader_parameter("aspect", width / slope)
	mat.set_shader_parameter("cells", Vector2(roundf(width / 0.3), roundf(slope / 0.3)))
	mat.set_shader_parameter("reveal", 0.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	root.add_child(mi)


## Despliega (1) o recoge (0) el tifo.
static func set_tifo(root: Node, value: float) -> void:
	var n := root.get_node_or_null("Tifo") as MeshInstance3D
	if n:
		n.visible = value > 0.001
		(n.material_override as ShaderMaterial).set_shader_parameter("reveal", value)


## ---------- pancartas ----------

## Frases genéricas de la hinchada local (nada de nombres reales).
const BANNER_TEXTS := ["VAMOS EQUIPO", "SIEMPRE CONTIGO", "LA 12", "AGUANTE", "LOCALES",
		"ESTA ES TU CASA", "HASTA EL FINAL", "CORAZÓN Y GARRA", "LA BANDA", "FIELES"]
## Filas de grada que tapa un trapo (la 1 y la 2: la 0 queda delante, la 3 lo sostiene).
const BANNER_ROW0 := 1
const BANNER_ROWS := 2
## Pancartas del jugador (las pone SoccerMatch desde config["crowd"], de
## ImmersionEngine.crowd_banners): {kind: "love" | "boo" | "", banners: [String]}.
static var crowd := {}
## Semilla de las frases genéricas (el estadio): siempre las mismas en la misma cancha.
static var banner_seed_name := ""
## Plan de trapos de este partido: [{text, x, s, w, boo, home_cloth}]. Se arma antes de
## las gradas para no poner público debajo (ver _stands).
static var _banner_plan: Array = []


## Trapos tendidos sobre la grada lateral (como en las canchas sudamericanas), de cara
## a la cámara de TV. Junto al túnel (lo que enfoca la salida) van los tuyos; el resto
## son frases de la hinchada local, más cuantas más estrellas tenga el estadio.
static func _plan_banners() -> Array:
	var plan: Array = []
	var half := (SoccerMatch.FIELD_LENGTH + 2.0 * END_STANDS) * 0.5 - 2.0
	var mine: Array = crowd.get("banners", [])
	var boo := String(crowd.get("kind", "")) == "boo"
	var next_x := [TUNNEL_X - TUNNEL_GAP - 1.0, TUNNEL_X + TUNNEL_GAP + 1.0] # izquierda, derecha
	for i in mine.size():
		var txt := String(mine[i])
		var w := _banner_width(txt)
		var side := i % 2
		var x: float = next_x[side] - w * 0.5 if side == 0 else next_x[side] + w * 0.5
		next_x[side] = x - w * 0.5 - 1.0 if side == 0 else x + w * 0.5 + 1.0
		plan.append({"text": txt, "x": x, "s": -1.0, "w": w, "boo": boo, "home_cloth": true})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(banner_seed_name)
	var count := 1 + stars
	var tries := 0
	while count > 0 and tries < 80:
		tries += 1
		var txt: String = BANNER_TEXTS[rng.randi() % BANNER_TEXTS.size()]
		var w := _banner_width(txt)
		var s := -1.0 if rng.randf() < 0.6 else 1.0
		var x := rng.randf_range(-half + w * 0.5, half - w * 0.5)
		if s < 0.0 and absf(x - TUNNEL_X) < TUNNEL_GAP + 1.0 + w * 0.5:
			continue # el hueco del túnel
		var clash := false
		for q: Dictionary in plan:
			if float(q.s) == s and absf(x - float(q.x)) < (w + float(q.w)) * 0.5 + 1.0:
				clash = true
				break
		if not clash:
			plan.append({"text": txt, "x": x, "s": s, "w": w, "boo": false, "home_cloth": rng.randf() < 0.7})
			count -= 1
	return plan


## ¿Este asiento (grada lateral `s`, fila `k`, posición `x`) queda bajo un trapo?
static func _under_banner(s: float, k: int, x: float) -> bool:
	if k < BANNER_ROW0 or k >= BANNER_ROW0 + BANNER_ROWS:
		return false
	for q: Dictionary in _banner_plan:
		if float(q.s) == s and absf(x - float(q.x)) < float(q.w) * 0.5 + 0.2:
			return true
	return false


static func _banner_width(txt: String) -> float:
	return maxf(3.0, txt.length() * 0.45 + 1.0)


static func _build_banners(root: Node3D) -> void:
	if _banner_plan.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "Banners"
	root.add_child(holder)
	for q: Dictionary in _banner_plan:
		_banner(holder, q)


## Un trapo: borde, paño y texto, apoyado sobre la pendiente de la grada.
## `home_cloth` = paño del color del local (si no, blanco con letras del local);
## `boo` = tela negra de silbidos.
static func _banner(parent: Node3D, q: Dictionary) -> void:
	var s := float(q.s)
	var w := float(q.w)
	var cloth := Color(0.93, 0.93, 0.9)
	var edge := home_color
	var ink := home_color.darkened(0.3)
	if bool(q.boo):
		cloth = Color(0.07, 0.07, 0.08)
		edge = Color(0.85, 0.12, 0.12)
		ink = Color(0.96, 0.96, 0.96)
	elif bool(q.home_cloth):
		cloth = home_color
		edge = home_color2
		ink = Color(0.97, 0.97, 0.95) if home_color.get_luminance() < 0.55 else Color(0.08, 0.08, 0.1)
	# Del borde delantero de la fila BANNER_ROW0 al de la última fila que tapa
	var d0 := SoccerMatch.FIELD_WIDTH * 0.5 + SIDE_STANDS + BANNER_ROW0 * ROW_DEPTH - ROW_DEPTH * 0.5
	var y0 := 0.9 + BANNER_ROW0 * ROW_RISE
	var run := BANNER_ROWS * ROW_DEPTH
	var rise := BANNER_ROWS * ROW_RISE
	var up := Vector3(0.0, rise, s * run).normalized()        # sube por la grada
	var right := Vector3(1.0 if s < 0.0 else -1.0, 0.0, 0.0)  # se lee desde el campo
	var normal := right.cross(up)
	var h := sqrt(run * run + rise * rise) - 0.2
	var b := Node3D.new()
	b.transform = Transform3D(Basis(right, up, normal),
			Vector3(float(q.x), y0 + rise * 0.5, s * (d0 + run * 0.5)) + normal * 0.12)
	parent.add_child(b)
	add_mesh(b, box(Vector3(w + 0.2, h + 0.2, 0.02)), Vector3(0.0, 0.0, -0.015), edge)
	add_mesh(b, box(Vector3(w, h, 0.03)), Vector3.ZERO, cloth)
	var lab := Label3D.new()
	lab.text = String(q.text)
	lab.font_size = 64
	lab.pixel_size = 0.0115
	lab.outline_size = 0
	lab.modulate = ink
	lab.position = Vector3(0.0, 0.0, 0.02)
	b.add_child(lab)


static func set_crowd_wave(root: Node, value: float) -> void:
	var cm := root.get_meta("crowd_mat", null) as ShaderMaterial
	if cm:
		cm.set_shader_parameter("wave", value)


## Ambiente del estadio: 0 normal, 1 celebrando un gol.
static func set_crowd_excitement(root: Node, value: float) -> void:
	var cm := root.get_meta("crowd_mat", null) as ShaderMaterial
	if cm:
		cm.set_shader_parameter("excitement", value)
	for node_name: String in ["FanFlags", "Flashes"]:
		var n := root.get_node_or_null(node_name) as GeometryInstance3D
		if n:
			(n.material_override as ShaderMaterial).set_shader_parameter("excitement", value)


## Ropa de un aficionado: casi todos con la camiseta del local; en el fondo visitante, la del rival.
static func _fan_color(away_end: bool) -> Color:
	var r := randf()
	if away_end and r < 0.7:
		return away_color.lightened(randf_range(0.0, 0.2))
	if not away_end and r < 0.55:
		return home_color.lightened(randf_range(0.0, 0.2))
	if r < 0.65:
		return home_color2.darkened(randf_range(0.0, 0.15))
	return Color.from_hsv(randf(), randf_range(0.1, 0.5), randf_range(0.4, 0.95))


## Tubo recto entre dos puntos.
static func _tube(parent: Node3D, a: Vector3, b: Vector3, r: float, color: Color) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = 8
	c.rings = 1
	var mi := add_mesh(parent, c, (a + b) * 0.5, color)
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(side, up, side.cross(up))


## Cara de red: cuadrilátero a-b-c-d (en orden) con la malla del shader. Subdividida para que
## pueda hincharse al entrar el balón. Devuelve su material.
static func _net_quad(parent: Node3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> ShaderMaterial:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := (b - a).cross(d - a).normalized()
	var nu := 12
	var nv := 8
	var at := func(u: float, v: float) -> Vector3:
		return a.lerp(b, u).lerp(d.lerp(c, u), v)
	for j in nv:
		for i in nu:
			var u0 := float(i) / nu
			var u1 := float(i + 1) / nu
			var v0 := float(j) / nv
			var v1 := float(j + 1) / nv
			for uv: Vector2 in [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1)]:
				st.set_normal(n)
				st.set_uv(uv)
				st.add_vertex(at.call(uv.x, uv.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = NET_SHADER
	m.set_shader_parameter("size", Vector2(a.distance_to(b), a.distance_to(d)))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1.0 # al hincharse se sale de su caja
	parent.add_child(mi)
	return m


static func _goal(root: Node3D, s: float) -> Area3D:
	var L := SoccerMatch.FIELD_LENGTH
	var GW := SoccerMatch.GOAL_WIDTH
	var GH := SoccerMatch.GOAL_HEIGHT
	var GD := SoccerMatch.GOAL_DEPTH
	var x0 := s * L * 0.5
	var white := Color(0.98, 0.98, 0.98)
	var post_r := 0.08

	var goal := Node3D.new()
	goal.name = "GoalPlusX" if s > 0.0 else "GoalMinusX"
	root.add_child(goal)

	# Postes
	for zs: float in [-1.0, 1.0]:
		var post := CylinderMesh.new()
		post.top_radius = post_r
		post.bottom_radius = post_r
		post.height = GH
		add_mesh(goal, post, Vector3(x0, GH * 0.5, zs * GW * 0.5), white)
		var body := StaticBody3D.new()
		body.collision_layer = LAYER_WALLS
		body.collision_mask = 0
		body.position = Vector3(x0, GH * 0.5, zs * GW * 0.5)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = post_r
		cyl.height = GH
		cs.shape = cyl
		body.add_child(cs)
		body.set_meta("sfx", "post")
		goal.add_child(body)

	# Larguero
	var bar := CylinderMesh.new()
	bar.top_radius = post_r
	bar.bottom_radius = post_r
	bar.height = GW
	var bar_mi := add_mesh(goal, bar, Vector3(x0, GH, 0.0), white)
	bar_mi.rotation.x = PI * 0.5
	add_static_box(goal, Vector3(post_r * 2.0, post_r * 2.0, GW), Vector3(x0, GH, 0.0)).set_meta("sfx", "post")

	# Uniones redondeadas entre postes y larguero
	var joint := SphereMesh.new()
	joint.radius = post_r
	joint.height = post_r * 2.0
	for zs: float in [-1.0, 1.0]:
		add_mesh(goal, joint, Vector3(x0, GH, zs * GW * 0.5), white)

	# Armazón trasero (tubos finos grises) que sujeta la red
	var rod := Color(0.75, 0.77, 0.8)
	var rr := 0.03
	var back_top := GH * 0.8 # la red cae un poco hacia atrás
	for zs: float in [-1.0, 1.0]:
		var z := zs * GW * 0.5
		_tube(goal, Vector3(x0, 0.02, z), Vector3(x0 + s * GD, 0.02, z), rr, rod)         # suelo, lateral
		_tube(goal, Vector3(x0 + s * GD, 0.02, z), Vector3(x0 + s * GD, back_top, z), rr, rod) # poste trasero
		_tube(goal, Vector3(x0, GH, z), Vector3(x0 + s * GD, back_top, z), rr, rod)        # de larguero a atrás
	_tube(goal, Vector3(x0 + s * GD, 0.02, -GW * 0.5), Vector3(x0 + s * GD, 0.02, GW * 0.5), rr, rod)
	_tube(goal, Vector3(x0 + s * GD, back_top, -GW * 0.5), Vector3(x0 + s * GD, back_top, GW * 0.5), rr, rod)

	# Red: caras con el shader de malla (fondo, techo inclinado y laterales)
	var bx := x0 + s * GD
	var back := _net_quad(goal, Vector3(bx, 0.0, -GW * 0.5), Vector3(bx, 0.0, GW * 0.5),
			Vector3(bx, back_top, GW * 0.5), Vector3(bx, back_top, -GW * 0.5))
	back.set_shader_parameter("push_dir", Vector3(s, 0.0, 0.0))
	goal.set_meta("net_back", back)
	goal.set_meta("net_size", Vector2(GW, back_top))
	_net_quad(goal, Vector3(x0, GH, -GW * 0.5), Vector3(x0, GH, GW * 0.5),
			Vector3(bx, back_top, GW * 0.5), Vector3(bx, back_top, -GW * 0.5))
	for zs: float in [-1.0, 1.0]:
		var z := zs * GW * 0.5
		_net_quad(goal, Vector3(x0, 0.0, z), Vector3(bx, 0.0, z), Vector3(bx, back_top, z), Vector3(x0, GH, z))
	# Colisiones de la red (para que el balón se quede dentro)
	add_static_box(goal, Vector3(0.6, GH, GW + 0.4), Vector3(x0 + s * (GD + 0.3), GH * 0.5, 0.0)).set_meta("sfx", "net")
	for zs: float in [-1.0, 1.0]:
		add_static_box(goal, Vector3(GD, GH, 0.3), Vector3(x0 + s * GD * 0.5, GH * 0.5, zs * (GW * 0.5 + 0.15))).set_meta("sfx", "net")
	add_static_box(goal, Vector3(GD, 0.3, GW), Vector3(x0 + s * GD * 0.5, GH + 0.15, 0.0)).set_meta("sfx", "net")

	# Zona de gol: el balón debe cruzar la línea por completo
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 4
	area.monitorable = false
	area.position = Vector3(x0 + s * (0.3 + GD) * 0.5, GH * 0.5, 0.0)
	var acs := CollisionShape3D.new()
	var ash := BoxShape3D.new()
	ash.size = Vector3(GD - 0.3, GH - 0.1, GW - 0.2)
	acs.shape = ash
	area.add_child(acs)
	goal.add_child(area)
	return area


## Bandera con mástil, con el mástil en el origen y la tela hacia +X.
## UV.x < 0 marca el mástil para el shader; la tela tiene UV de 0 a 1.
static func _flag_mesh(pole_h: float, w: float, h: float, top: float, color: Color) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(color)
	st.set_normal(Vector3.BACK)
	if pole_h > 0.0:
		st.set_uv(Vector2(-1.0, 0.0))
		_st_box(st, Vector3(0.0, pole_h * 0.5, 0.0), Vector3(0.025, pole_h, 0.025))
	var cols := 6
	var rows := 2
	for i in cols:
		for j in rows:
			var quad := [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				var c: Vector2 = quad[k]
				var u := c.x / cols
				var v := c.y / rows
				st.set_uv(Vector2(u, v))
				st.set_normal(Vector3.BACK)
				st.add_vertex(Vector3(u * w, top - v * h, 0.0))
	return st.commit()


## Algunos aficionados con bandera de su equipo.
static func _fan_flags(root: Node3D, fans: Array[Transform3D]) -> void:
	var picks: Array[Transform3D] = []
	for xf in fans:
		if randf() < 0.05:
			picks.append(xf)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _flag_mesh(1.5, 0.95, 0.6, 1.5, Color.WHITE)
	mm.instance_count = picks.size()
	for i in picks.size():
		var xf := picks[i]
		# Mástil en la mano, un poco inclinado hacia el campo
		var b := xf.basis.rotated(xf.basis.x.normalized(), -0.15)
		mm.set_instance_transform(i, Transform3D(b, xf.origin + Vector3(0.0, 0.35, 0.0)))
		# Banderas del local, salvo en el fondo visitante (+X)
		var away_end := xf.origin.x > SoccerMatch.FIELD_LENGTH * 0.5 + END_STANDS - 0.5
		mm.set_instance_color(i, away_color if away_end else (home_color if randf() < 0.75 else home_color2))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = FLAG_SHADER
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.name = "FanFlags"
	root.add_child(mmi)


## Flashes de cámaras repartidos por la grada.
static func _flashes(root: Node3D, fans: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	mm.mesh = q
	var n := mini(420, fans.size())
	mm.instance_count = n
	for i in n:
		var xf := fans[randi() % fans.size()]
		mm.set_instance_transform(i, Transform3D(Basis(), xf.origin + Vector3(0.0, 0.7, 0.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = FLASH_SHADER
	m.set_shader_parameter("strength", 1.6 if time_of_day == 2 else 1.0)
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 2.0
	mmi.name = "Flashes"
	root.add_child(mmi)


## Confeti para los goles (uno por cada fondo).
static func _confetti(root: Node3D) -> void:
	var L := SoccerMatch.FIELD_LENGTH
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.06)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.6
	q.material = m
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.85, 0.1), Color(0.95, 0.2, 0.25), Color(0.2, 0.5, 1.0),
			Color(1.0, 1.0, 1.0), Color(0.2, 0.85, 0.4), Color(1.0, 0.5, 0.1)])
	for s: float in [1.0, -1.0]:
		var p := CPUParticles3D.new()
		p.name = "Confetti%d" % (0 if s > 0.0 else 1)
		p.mesh = q
		p.amount = 320
		p.lifetime = 3.2
		p.one_shot = true
		p.explosiveness = 0.75
		p.emitting = false
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(5.0, 0.5, SoccerMatch.FIELD_WIDTH * 0.45)
		p.position = Vector3(s * (L * 0.5 + 10.0), 10.0, 0.0)
		p.direction = Vector3(-s, 1.0, 0.0)
		p.spread = 50.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 7.0
		p.gravity = Vector3(0.0, -2.2, 0.0)
		p.damping_min = 0.6
		p.damping_max = 1.2
		p.angular_velocity_min = -400.0
		p.angular_velocity_max = 400.0
		p.particle_flag_rotate_y = true
		p.color_initial_ramp = grad
		p.local_coords = false
		root.add_child(p)


## Lanza el confeti en el fondo de la portería `area` (la del gol).
static func celebrate(root: Node, area: Area3D) -> void:
	AdBoards.goal(root)
	var goal_x := area.global_position.x
	var p := root.get_node_or_null("Confetti0" if goal_x > 0.0 else "Confetti1") as CPUParticles3D
	if p:
		p.restart()
		p.emitting = true

## Bengalas con humo de colores en la grada de cada fondo (salida de los equipos y goles).
static func _flares(root: Node3D) -> void:
	var L := SoccerMatch.FIELD_LENGTH
	var smoke_q := QuadMesh.new()
	smoke_q.size = Vector2(1.6, 1.6)
	var sm := ShaderMaterial.new()
	sm.shader = SMOKE_SHADER
	smoke_q.material = sm
	# Chispas: bolitas brillantes (la llama de la bengala)
	var spark_q := SphereMesh.new()
	spark_q.radius = 0.06
	spark_q.height = 0.12
	spark_q.radial_segments = 6
	spark_q.rings = 3
	var km := StandardMaterial3D.new()
	km.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	km.albedo_color = Color(1.0, 0.75, 0.4)
	km.emission_enabled = true
	km.emission = Color(1.0, 0.45, 0.15)
	km.emission_energy_multiplier = 3.0
	spark_q.material = km
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.0)])
	for s: float in [1.0, -1.0]:
		var group := Node3D.new()
		group.name = "Flares%d" % (0 if s > 0.0 else 1)
		root.add_child(group)
		for i in 4:
			var at := Vector3(s * (L * 0.5 + END_STANDS + 2.5 + (i % 2) * 2.4), 2.6 + (i % 2) * 1.2,
					(i - 1.5) * 7.0 + randf_range(-1.5, 1.5))
			var smoke := CPUParticles3D.new()
			smoke.mesh = smoke_q
			smoke.amount = 28
			smoke.lifetime = 4.5
			smoke.emitting = false
			smoke.position = at
			smoke.direction = Vector3(-s * 0.4, 1.0, 0.0)
			smoke.spread = 25.0
			smoke.initial_velocity_min = 0.8
			smoke.initial_velocity_max = 1.6
			smoke.gravity = Vector3(-s * 0.25, 0.35, 0.0)
			smoke.damping_min = 0.2
			smoke.damping_max = 0.4
			smoke.scale_amount_min = 1.0
			smoke.scale_amount_max = 2.4
			var grow := Curve.new()
			grow.add_point(Vector2(0.0, 0.4))
			grow.add_point(Vector2(1.0, 1.6))
			smoke.scale_amount_curve = grow
			smoke.color_ramp = fade
			smoke.local_coords = false
			smoke.set_meta("kind", "smoke")
			group.add_child(smoke)
			var spark := CPUParticles3D.new()
			spark.mesh = spark_q
			spark.amount = 14
			spark.lifetime = 0.35
			spark.emitting = false
			spark.position = at
			spark.direction = Vector3.UP
			spark.spread = 40.0
			spark.initial_velocity_min = 1.0
			spark.initial_velocity_max = 2.5
			spark.scale_amount_min = 0.5
			spark.scale_amount_max = 1.2
			spark.set_meta("kind", "spark")
			group.add_child(spark)


## Enciende las bengalas del fondo `end_sign` (+1 = fondo de +X) con humo `color` durante `seconds`.
static func flares(root: Node, end_sign: float, color: Color, seconds := 6.0) -> void:
	var group := root.get_node_or_null("Flares%d" % (0 if end_sign > 0.0 else 1))
	if group == null:
		return
	for p: CPUParticles3D in group.get_children():
		if String(p.get_meta("kind")) == "smoke":
			p.color = color.lerp(Color.WHITE, 0.15)
		p.emitting = true
	root.get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		if is_instance_valid(group):
			for p: CPUParticles3D in group.get_children():
				p.emitting = false)


## Videomarcador gigante sobre la grada del fondo de -X, mirando al campo.
static func _scoreboard(root: Node3D) -> void:
	var L := SoccerMatch.FIELD_LENGTH
	var x := -(L * 0.5 + END_STANDS + END_ROWS * ROW_DEPTH) + 0.6
	# Por encima del techo de la grada de fondo (eroof_h en _stands + espesor e
	# inclinación) con margen para la perspectiva de las cámaras bajas: antes el
	# borde de abajo quedaba detrás del techo y se cortaba el minuto.
	var roof_top := 0.9 + END_ROWS * ROW_RISE + 3.5 + 1.0
	var y := roof_top + 3.8 + 1.4
	var wall_top := 0.9 + END_ROWS * ROW_RISE + 2.5 # muro trasero de la grada (stars >= 3)
	var leg_len := y - 3.8 - wall_top
	var board := Node3D.new()
	board.name = "Scoreboard"
	board.position = Vector3(x, y, 0.0)
	board.rotation.y = PI * 0.5
	root.add_child(board)
	add_mesh(board, box(Vector3(20.0, 7.6, 0.5)), Vector3(0.0, 0.0, -0.3), Color(0.12, 0.13, 0.16))
	var screen := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(19.0, 6.6)
	screen.mesh = q
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.02, 0.05, 0.1)
	sm.emission_enabled = true
	sm.emission = Color(0.03, 0.08, 0.16)
	screen.material_override = sm
	screen.position = Vector3(0.0, 0.0, 0.0)
	board.add_child(screen)
	for leg: float in [-6.5, 6.5]:
		add_mesh(board, box(Vector3(0.5, leg_len, 0.5)), Vector3(leg, -3.8 - leg_len * 0.5, -0.4), Color(0.3, 0.32, 0.36))
	var label := Label3D.new()
	label.name = "Text"
	label.font_size = 200
	label.pixel_size = 0.014
	label.line_spacing = -20.0
	label.outline_size = 0
	label.modulate = Color(1.0, 0.95, 0.75)
	label.shaded = false
	label.double_sided = false
	label.position = Vector3(0.0, 0.0, 0.05)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = ""
	board.add_child(label)


## Escribe en el videomarcador (solo si cambia).
static func set_scoreboard(root: Node, text: String) -> void:
	var label := root.get_node_or_null("Scoreboard/Text") as Label3D
	if label and label.text != text:
		label.text = text
