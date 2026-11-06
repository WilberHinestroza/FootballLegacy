class_name TrophyRoom
extends Node3D
## Sala de trofeos: vitrina de madera con estantes iluminados y, en cada hueco, un título
## de tu carrera en 3D (TrophyBuilder, parecido a su dibujo pixel) con su plaquita. La
## cámara recorre la vitrina despacio. Mundo propio: el RPG lo mete en un recuadro con
## TrophyRoom.make_view(entradas, tamaño). entradas = [{id, label}] (id de Trophy.gd).

const ROWS := 3
const CELL := Vector2(0.95, 0.9)   # ancho y alto de cada hueco
const SHELF_Y0 := 0.55

var camera: Camera3D
var _t := 0.0
var _span := 0.0
var _items: Array = []   # [{node, id, label}] para tocar un trofeo y verlo de cerca
var _press := Vector2.INF


static func make_view(entries: Array, size: Vector2, title := "SALA DE TROFEOS") -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = size
	box.mouse_filter = Control.MOUSE_FILTER_PASS # deja pasar el scroll; un toque abre el trofeo
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(maxi(int(size.x), 640), maxi(int(size.y), 240)) # con stretch lo ajusta el recuadro
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(vp)
	var room := TrophyRoom.new()
	vp.add_child(room)
	room.build(entries, title)
	box.gui_input.connect(room._on_box_input.bind(box))
	return box


## Toque (sin arrastre) en la vitrina: el trofeo más cercano al dedo se abre en grande.
func _on_box_input(e: InputEvent, box: Control) -> void:
	var pos := Vector2.ZERO
	var pressed := false
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		pos = e.position
		pressed = e.pressed
	elif e is InputEventScreenTouch:
		pos = e.position
		pressed = e.pressed
	else:
		return
	if pressed:
		_press = pos
		return
	if _press == Vector2.INF or pos.distance_to(_press) > 14.0 or camera == null:
		return
	_press = Vector2.INF
	var vp_size := Vector2(get_viewport().size)
	var p := pos * vp_size / box.size # del recuadro al viewport (por si no coinciden)
	var best: Dictionary = {}
	var best_d := vp_size.y * 0.14
	for it: Dictionary in _items:
		var n: Node3D = it.node
		var at := n.global_position + Vector3.UP * 0.25
		if camera.is_position_behind(at):
			continue
		var d := camera.unproject_position(at).distance_to(p)
		if d < best_d:
			best_d = d
			best = it
	if not best.is_empty():
		TrophyViewer.open_closeup(box, String(best.id), String(best.label))


func build(entries: Array, title: String) -> void:
	var n := maxi(entries.size(), 1)
	var cols := maxi(ceili(float(n) / ROWS), 3)
	var width := cols * CELL.x + 0.6
	_span = maxf(width * 0.5 - 2.4, 0.0)
	_environment()

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.17, 0.08)
	wood.roughness = 0.45
	var dark_wood := StandardMaterial3D.new()
	dark_wood.albedo_color = Color(0.16, 0.08, 0.04)
	dark_wood.roughness = 0.5
	var velvet := StandardMaterial3D.new()
	velvet.albedo_color = Color(0.16, 0.2, 0.42)
	velvet.roughness = 0.95
	var gold := TrophyBuilder.metal("gold")
	var floor_m := StandardMaterial3D.new()
	floor_m.albedo_color = Color(0.22, 0.12, 0.07)
	floor_m.roughness = 0.25
	floor_m.metallic = 0.1

	# Suelo de parqué, paredes y la vitrina: marco de madera, fondo de terciopelo
	_add(FieldBuilder.box(Vector3(width + 10.0, 0.1, 10.0)), Vector3(0, -0.05, 2.0), floor_m)
	_add(FieldBuilder.box(Vector3(width + 10.0, 4.5, 0.2)), Vector3(0, 2.25, -0.75), dark_wood)
	var top := SHELF_Y0 + ROWS * CELL.y
	_add(FieldBuilder.box(Vector3(width, top + 0.25, 0.1)), Vector3(0, (top + 0.25) * 0.5, -0.55), velvet)
	_add(FieldBuilder.box(Vector3(width + 0.3, 0.5, 0.75)), Vector3(0, 0.25, -0.2), wood)        # mueble de abajo
	_add(FieldBuilder.box(Vector3(width + 0.3, 0.14, 0.75)), Vector3(0, top + 0.3, -0.2), wood)   # remate de arriba
	for x: float in [-width * 0.5 - 0.075, width * 0.5 + 0.075]:
		_add(FieldBuilder.box(Vector3(0.15, top + 0.4, 0.75)), Vector3(x, (top + 0.4) * 0.5, -0.2), wood)
	for r in ROWS:
		var y := SHELF_Y0 + r * CELL.y
		_add(FieldBuilder.box(Vector3(width, 0.035, 0.6)), Vector3(0, y, -0.25), wood)
		_add(FieldBuilder.box(Vector3(width, 0.02, 0.02)), Vector3(0, y + 0.01, 0.05), gold)
	# Rótulo de la vitrina
	var t := Label3D.new()
	t.text = title.to_upper()
	t.font_size = 80
	t.pixel_size = 0.004
	t.modulate = Color(1.0, 0.85, 0.45)
	t.outline_size = 0
	t.position = Vector3(0, top + 0.55, 0.2)
	add_child(t)

	# Los trofeos: de izquierda a derecha y de arriba abajo, el más reciente primero
	if entries.is_empty():
		var hint := Label3D.new()
		hint.text = "Tu primer título\nte espera aquí"
		hint.font_size = 64
		hint.pixel_size = 0.004
		hint.position = Vector3(0, SHELF_Y0 + CELL.y * 1.4, -0.3)
		add_child(hint)
	for i in entries.size():
		var e: Dictionary = entries[i]
		var c := i / ROWS
		var r := ROWS - 1 - (i % ROWS)
		var x := (c - (cols - 1) * 0.5) * CELL.x
		var y := SHELF_Y0 + r * CELL.y + 0.02
		var tr := TrophyBuilder.build(String(e.get("id", "cup")))
		tr.position = Vector3(x, y, -0.3)
		tr.rotation.y = randf_range(-0.25, 0.25)
		tr.scale = Vector3.ONE * 1.3
		add_child(tr)
		_items.append({"node": tr, "id": String(e.get("id", "cup")), "label": String(e.get("label", ""))})
		var plate := Label3D.new()
		plate.text = String(e.get("label", ""))
		plate.font_size = 32
		plate.pixel_size = 0.003
		plate.width = 300.0
		plate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		plate.outline_size = 6
		plate.modulate = Color(1.0, 0.92, 0.7)
		plate.position = Vector3(x, y - 0.05, 0.2)
		add_child(plate)
	# Focos cálidos sobre cada columna (como mucho 8)
	var step := maxi(1, ceili(cols / 8.0))
	for c in range(0, cols, step):
		var l := SpotLight3D.new()
		l.position = Vector3((c - (cols - 1) * 0.5) * CELL.x, top + 0.9, 1.0)
		l.spot_range = 5.0
		l.spot_angle = 28.0
		l.light_energy = 3.0
		l.light_color = Color(1.0, 0.88, 0.7)
		add_child(l)
		l.look_at_from_position(l.position, Vector3(l.position.x, SHELF_Y0 + CELL.y, -0.3), Vector3.UP)

	# Luz suave dentro de la vitrina para que se vea el terciopelo
	var inner := OmniLight3D.new()
	inner.position = Vector3(0, SHELF_Y0 + CELL.y * 1.5, 0.6)
	inner.omni_range = width + 2.0
	inner.light_energy = 0.9
	inner.light_color = Color(1.0, 0.9, 0.8)
	add_child(inner)
	camera = Camera3D.new()
	camera.fov = 52.0
	add_child(camera)
	camera.make_current()
	_process(0.0)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.03, 0.02)
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.5, 0.45, 0.4)
	sm.sky_horizon_color = Color(0.9, 0.75, 0.55)
	sm.ground_bottom_color = Color(0.4, 0.3, 0.2)
	sm.ground_horizon_color = Color(0.8, 0.6, 0.4)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.5, 0.4)
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _add(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


## Cámara que pasea de lado a lado delante de la vitrina, con un leve acercamiento.
func _process(delta: float) -> void:
	_t += delta
	if camera == null:
		return
	var x := sin(_t * 0.25) * _span
	var z := clampf(1.4 + _span * 0.6 + 2.2, 3.4, 4.3) + sin(_t * 0.4) * 0.3 # más cerca si hay pocos
	camera.position = Vector3(x, 2.0, z)
	camera.look_at_from_position(camera.position, Vector3(x * 0.9, SHELF_Y0 + CELL.y * 1.55, -0.3), Vector3.UP)
