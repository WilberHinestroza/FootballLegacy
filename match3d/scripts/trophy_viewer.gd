class_name TrophyViewer
extends SubViewportContainer
## Trofeo 3D girando en un recuadro de interfaz (fondo transparente), para los menús del
## RPG: pantalla de campeón, premios... Entra con un pequeño salto y luego gira despacio.
## Uso: add_child(TrophyViewer.make("league_12", 150))

var trophy_id := "cup"
var accent := Color(0, 0, 0, 0)
var spin_speed := 0.7
var _pivot: Node3D
var _t := 0.0
var _yaw := 0.0          # giro extra al arrastrar
var _cam: Camera3D
var _fov := 30.0
## Si es true, tocarlo abre el trofeo en grande (open_closeup).
var zoomable := false
var title := ""
var _press := Vector2.INF


static func make(id: String, px: int, tint := Color(0, 0, 0, 0)) -> TrophyViewer:
	var v := TrophyViewer.new()
	v.trophy_id = id
	v.accent = tint
	v.custom_minimum_size = Vector2(px, px)
	v.size = Vector2(px, px)
	return v


## Abre el trofeo en grande encima de todo: gira solo, se arrastra para girarlo, rueda o
## pellizco para acercar, y un toque fuera de él lo cierra. `host`: cualquier nodo del árbol.
static func open_closeup(host: Node, id: String, label := "") -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	host.get_tree().root.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var vs := host.get_viewport().get_visible_rect().size
	var px := int(minf(vs.x, vs.y) * 0.72)
	var v := TrophyViewer.make(id, px)
	v.spin_speed = 0.35
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	v.position = (vs - Vector2(px, px)) * 0.5 + Vector2(0, 10)
	layer.add_child(v)
	var close := func() -> void:
		var tw := layer.create_tween()
		tw.tween_property(dim, "modulate:a", 0.0, 0.18)
		tw.parallel().tween_property(v, "modulate:a", 0.0, 0.18)
		tw.tween_callback(layer.queue_free)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			close.call())
	v.gui_input.connect(v._closeup_input)
	for txt: String in [label, "Arrastra para girarlo · toca fuera para cerrar"]:
		if txt == "":
			continue
		var l := Label.new()
		l.text = txt
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 30 if txt == label else 18)
		l.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55) if txt == label else Color(1, 1, 1, 0.6))
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.size = Vector2(vs.x, 40)
		l.position = Vector2(0, 18 if txt == label else vs.y - 44)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(l)
	dim.modulate.a = 0.0
	layer.create_tween().tween_property(dim, "modulate:a", 1.0, 0.2)


## Arrastrar gira el trofeo; rueda / pellizco acerca o aleja.
func _closeup_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_yaw += e.relative.x * 0.012
	elif e is InputEventScreenDrag:
		_yaw += e.relative.x * 0.012
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_fov = clampf(_fov + (-2.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 2.0), 14.0, 40.0)
	elif e is InputEventMagnifyGesture:
		_fov = clampf(_fov / e.factor, 14.0, 40.0)
	accept_event()


func _gui_input(e: InputEvent) -> void:
	if not zoomable:
		return
	# Un toque (sin arrastrar, que puede ser el scroll de la lista) abre el trofeo en grande
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		pressed = e.pressed
		released = not e.pressed
		pos = e.position
	elif e is InputEventScreenTouch:
		pressed = e.pressed
		released = not e.pressed
		pos = e.position
	if pressed:
		_press = pos
	elif released and _press != Vector2.INF and pos.distance_to(_press) < 14.0:
		_press = Vector2.INF
		TrophyViewer.open_closeup(self, trophy_id, title)


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_PASS if zoomable else Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.size = Vector2i(maxi(int(custom_minimum_size.x), 64), maxi(int(custom_minimum_size.y), 64))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	# Cielo solo para reflejos y luz ambiente: el fondo sigue transparente
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.35, 0.45, 0.7)
	mat.sky_horizon_color = Color(1.0, 0.9, 0.75)
	mat.ground_bottom_color = Color(0.55, 0.5, 0.45) # suelo claro: la plata no sale negra
	mat.ground_horizon_color = Color(0.9, 0.82, 0.7)
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	key.light_energy = 1.3
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10.0, 200.0, 0.0)
	rim.light_energy = 0.9
	rim.light_color = Color(1.0, 0.85, 0.6)
	vp.add_child(rim)

	_pivot = Node3D.new()
	vp.add_child(_pivot)
	var trophy := TrophyBuilder.build(trophy_id, accent)
	_pivot.add_child(trophy)
	# Encuadre según lo que mida el trofeo
	var box := _bounds(trophy)
	var h := maxf(box.size.y, 0.2)
	var w := maxf(maxf(box.size.x, box.size.z), 0.2)
	var cam := Camera3D.new()
	_cam = cam
	cam.fov = 30.0
	var dist := maxf(h, w) * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) * 1.18
	var center := box.get_center()
	cam.position = center + Vector3(0.0, h * 0.12, dist)
	vp.add_child(cam)
	cam.look_at(center, Vector3.UP)
	_pivot.scale = Vector3.ONE * 0.01


func _process(delta: float) -> void:
	_t += delta
	if _pivot == null:
		return
	# Entra con salto y gira; un leve vaivén para que no parezca un plato giratorio
	var pop := 1.0 + sin(clampf(_t / 0.5, 0.0, 1.0) * PI) * 0.12 if _t < 0.5 else 1.0
	var grow := clampf(_t / 0.35, 0.0, 1.0)
	_pivot.scale = Vector3.ONE * maxf(grow * pop, 0.01)
	_pivot.rotation.y = -0.6 + _t * spin_speed + _yaw
	if _cam:
		_cam.fov = lerpf(_cam.fov, _fov, 0.2)
	_pivot.rotation.z = sin(_t * 1.3) * 0.03


func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var a: AABB = (n.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb() if mi.is_inside_tree() \
				else _local_xform(n, mi) * mi.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


## Transform de `mi` relativo a `top` sin estar en el árbol.
func _local_xform(top: Node3D, mi: Node3D) -> Transform3D:
	var xf := mi.transform
	var p := mi.get_parent()
	while p != null and p != top and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
