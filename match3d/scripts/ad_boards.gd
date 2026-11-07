class_name AdBoards
extends RefCounted
## Vallas publicitarias LED del estadio.
##
## Todas las vallas son dos MultiMesh (marco + pantalla) con un único material: dos
## llamadas de dibujo en vez de una caja y un texto por valla. Los anuncios se
## dibujan una sola vez en un atlas (SubViewport) y el shader los rota cada pocos
## segundos con un barrido; en los goles todas las vallas muestran "¡GOOOL!".
## Patrocinadores inventados: nada de marcas reales.

const SHADER := preload("res://match3d/shaders/led_board.gdshader")
const FONT := preload("res://ui/fonts/Poppins-Black.ttf")
const CELL := Vector2i(512, 96)
const FACE_H := 0.82

## [texto, fondo, letra, acento]. El acento es una franja/forma que da identidad.
const SPONSORS := [
	["FOOTBALL LEGACY", Color(0.98, 0.76, 0.1), Color(0.08, 0.08, 0.1), Color(0.08, 0.08, 0.1)],
	["VOLTERRA ENERGÍA", Color(0.05, 0.2, 0.55), Color.WHITE, Color(0.3, 0.85, 1.0)],
	["RAYO COLA", Color(0.82, 0.08, 0.12), Color.WHITE, Color(1.0, 0.85, 0.2)],
	["KOMETA AIR", Color(0.97, 0.97, 0.97), Color(0.1, 0.2, 0.45), Color(0.95, 0.4, 0.1)],
	["PIXELNET", Color(0.1, 0.1, 0.12), Color(0.35, 1.0, 0.55), Color(0.35, 1.0, 0.55)],
	["MAREA SEGUROS", Color(0.0, 0.5, 0.55), Color.WHITE, Color(0.9, 0.95, 1.0)],
	["ZENDA SPORT", Color(0.95, 0.45, 0.05), Color(0.1, 0.1, 0.1), Color.WHITE],
	["", Color.BLACK, Color.WHITE, Color.WHITE], # "¡VAMOS <local>!" en los colores del local
]

static var home_name := ""


## Construye todas las vallas. `boards`: [{pos, length, yaw, h}] con la cara hacia +Z
## local; `h` (opcional) escala el alto (anillo LED bajo el techo).
static func build(root: Node3D, boards: Array) -> void:
	var tex := _atlas(root)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("atlas", tex)
	mat.set_shader_parameter("cells", float(SPONSORS.size()))
	# Estadios pequeños: vallas fijas (cada una con su anuncio); los grandes rotan
	mat.set_shader_parameter("period", 8.0 if FieldBuilder.stars >= 3 else 0.0)
	mat.set_shader_parameter("brightness", 1.0 if FieldBuilder.time_of_day == 2 else 0.92)
	root.set_meta("led_mat", mat)
	_bake(root, mat)

	var face := QuadMesh.new()
	face.size = Vector2(1.0, FACE_H)
	var frame := BoxMesh.new()
	frame.size = Vector3(1.0, 1.0, 0.15)
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.07, 0.07, 0.08)
	frame_mat.roughness = 0.6
	frame.material = frame_mat

	var mm_face := _multimesh(face, boards.size(), true)
	var mm_frame := _multimesh(frame, boards.size(), false)
	for i in boards.size():
		var b: Dictionary = boards[i]
		var length := float(b.length)
		var h := float(b.get("h", 1.0))
		var basis := Basis(Vector3.UP, float(b.yaw))
		var pos: Vector3 = b.pos
		mm_frame.set_instance_transform(i, Transform3D(basis * Basis.from_scale(Vector3(length, h, 1.0)), pos))
		var fpos := pos + basis * Vector3(0.0, 0.0, 0.078)
		mm_face.set_instance_transform(i, Transform3D(basis * Basis.from_scale(Vector3(length - 0.08, h, 1.0)), fpos))
		# Desfase: vecinas con anuncios distintos (el 3 es coprimo con 8)
		mm_face.set_instance_custom_data(i, Color(float((i * 3) % SPONSORS.size()), length, 0.0, 0.0))
	_add(root, mm_frame, null, "AdFrames")
	_add(root, mm_face, mat, "AdFaces")


## Destello de gol: todas las vallas pasan a "¡GOOOL!" unos segundos.
static func goal(root: Node) -> void:
	var mat := root.get_meta("led_mat", null) as ShaderMaterial
	if mat == null or not root.is_inside_tree():
		return
	var tw := root.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("goal_mix", v), 0.0, 1.0, 0.25)
	tw.tween_interval(5.0)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("goal_mix", v), 1.0, 0.0, 0.6)


## El SubViewport no genera mipmaps: tras su único render se copia a una textura
## con mipmaps (sin parpadeo en las vallas lejanas) y se libera.
static func _bake(root: Node3D, mat: ShaderMaterial) -> void:
	var vp := root.get_node_or_null("AdAtlas") as SubViewport
	if vp == null or not root.is_inside_tree():
		return
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp):
		return
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return # sin GPU (headless): se queda la textura del viewport
	img.generate_mipmaps()
	mat.set_shader_parameter("atlas", ImageTexture.create_from_image(img))
	vp.queue_free()


static func _multimesh(mesh: Mesh, count: int, custom: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = count
	return mm


static func _add(root: Node3D, mm: MultiMesh, mat: Material, node_name: String) -> void:
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mat != null:
		mi.material_override = mat
	root.add_child(mi)


## Dibuja los anuncios (uno por fila, más la fila de gol al final) en un SubViewport
## que se renderiza una sola vez.
static func _atlas(root: Node3D) -> Texture2D:
	var rows := SPONSORS.size() + 1
	var vp := SubViewport.new()
	vp.name = "AdAtlas"
	vp.size = Vector2i(CELL.x, CELL.y * rows)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.transparent_bg = false
	vp.disable_3d = true
	root.add_child(vp)
	var home := FieldBuilder.home_color
	var home2 := FieldBuilder.home_color2
	for r in rows:
		var y := r * CELL.y
		var s: Array = SPONSORS[r] if r < SPONSORS.size() else ["¡GOOOL!", home, home2, home2]
		var text := String(s[0])
		var bg: Color = s[1]
		var fg: Color = s[2]
		var accent: Color = s[3]
		if text == "":
			text = "¡VAMOS %s!" % (home_name.to_upper() if home_name != "" else "EQUIPO")
			bg = home
			fg = home2
			accent = home2
		if bg.get_luminance() > 0.6 and fg.get_luminance() > 0.6:
			fg = Color(0.08, 0.08, 0.1) # local blanco con letra blanca: que se lea
		_rect(vp, Rect2(0, y, CELL.x, CELL.y), bg)
		_accent(vp, r, y, accent)
		var lab := Label.new()
		lab.text = text
		lab.position = Vector2(0, y)
		lab.size = Vector2(CELL.x, CELL.y)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.clip_text = true
		lab.add_theme_font_override("font", FONT)
		lab.add_theme_font_size_override("font_size", 54 if text.length() <= 12 else (44 if text.length() <= 16 else 34))
		lab.add_theme_color_override("font_color", fg)
		vp.add_child(lab)
	return vp.get_texture()


static func _rect(vp: SubViewport, r: Rect2, c: Color) -> void:
	var cr := ColorRect.new()
	cr.position = r.position
	cr.size = r.size
	cr.color = c
	vp.add_child(cr)


## Un adorno distinto por anuncio para que no sean solo texto sobre color.
static func _accent(vp: SubViewport, row: int, y: float, c: Color) -> void:
	var w := float(CELL.x)
	var h := float(CELL.y)
	match row % 4:
		0: # franjas arriba y abajo
			_rect(vp, Rect2(0, y + 4, w, 6), c)
			_rect(vp, Rect2(0, y + h - 10, w, 6), c)
		1: # bloque lateral
			_rect(vp, Rect2(0, y, 22, h), c)
			_rect(vp, Rect2(w - 22, y, 22, h), c)
		2: # subrayado central
			_rect(vp, Rect2(w * 0.3, y + h - 16, w * 0.4, 5), c)
		3: # esquinas
			_rect(vp, Rect2(0, y, 60, 8), c)
			_rect(vp, Rect2(w - 60, y + h - 8, 60, 8), c)
