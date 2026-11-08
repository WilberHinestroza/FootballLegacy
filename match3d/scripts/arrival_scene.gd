class_name ArrivalScene
extends RefCounted
## Llegada al estadio (8-nov, Wilber: "bus y afición" → "cambia los aficionados
## por camara mans" + "agrega el espacio en el estadio para la entrada a los
## camerinos"): el autobús del club entra por la avenida entre vallas, con
## fotógrafos y cámaras de tele a los lados; frena ante la entrada cubierta de
## los vestuarios y tu jugador baja y camina hacia ella entre flashes.
## Solo decorado y tiempos: la cámara y el jugador los mueve match.gd (salida
## de los equipos). Se construye al empezar la salida y se borra al terminar
## la toma. Determinista, nada se guarda.

const DRIVE := 3.8        # segundos del autobús hasta frenar
const SHOT := 8.6         # duración de toda la toma a ras de suelo
const STEP_OFF := 4.3     # el jugador baja del autobús
const BUS_LEN := 12.5
const BUS_X := -3.6       # carril del autobús (el pasillo del jugador, a su derecha)
const START_BACK := 95.0  # de dónde viene, metros antes de la parada
const ENTRY_LEN := 5.5    # entrada cubierta de los vestuarios: largo, ancho y alto
const ENTRY_W := 6.0
const ENTRY_H := 4.4
const PRESS := Color(0.95, 0.55, 0.12)  # petos de prensa (los de StadiumStaff)
## Cuánta prensa espera según la popularidad de tu club (sus estrellas, 1-5;
## una selección cuenta como 5): de un par de fotógrafos a un pasillo lleno.
const PRESS_BY_STARS := [3, 3, 6, 10, 15, 22]
## La puerta del vestuario: al cruzar esta profundidad (detrás del marco) entras.
const INSIDE := 0.35

## Puerta del vestuario (fondo de la entrada), parada del autobús y su puerta.
## En los estadios grandes, delante del portón de la fachada más cercano al centro
## (por fuera de los pilares); en los demás, en el centro del muro trasero.
static func gate() -> Vector3:
	if FieldBuilder.design != "":
		var best := 0.0
		var gates := BigStadium.gate_offsets(BigStadium.back_x())
		if not gates.is_empty():
			best = gates[0]
			for x: float in gates:
				if absf(x) < absf(best):
					best = x
		return Vector3(best, 0.0, -(BigStadium.back_z() + 1.45))
	return Vector3(0.0, 0.0, -(StadiumGrounds.footprint().y + 0.4))

## Boca de la entrada cubierta (por donde se entra desde la explanada).
static func mouth() -> Vector3:
	return gate() - Vector3(0.0, 0.0, ENTRY_LEN)

static func stop_center() -> Vector3:
	return Vector3(mouth().x + BUS_X, 0.0, mouth().z - 8.0)

static func door() -> Vector3:
	return stop_center() + Vector3(1.9, 0.0, BUS_LEN * 0.5 - 1.6)

## Centro del autobús en el segundo `t` de la toma (frena suave hasta la parada).
static func bus_center(t: float) -> Vector3:
	var k: float = clampf(t / DRIVE, 0.0, 1.0)
	var e: float = 1.0 - pow(1.0 - k, 3.0)
	return stop_center() - Vector3(0.0, 0.0, START_BACK * (1.0 - e))


static func build(root: Node3D, team_name: String, c1: Color, c2: Color, club_stars: int) -> Node3D:
	var set := Node3D.new()
	set.name = "ArrivalSet"
	root.add_child(set)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("arrival:" + team_name)
	var night := FieldBuilder.time_of_day == 2
	_entry(set, team_name, c1, c2, night)

	# Vallas a los dos lados del pasillo del autobús y del jugador
	var fence := Color(0.7, 0.72, 0.75)
	var m := mouth()
	var z0: float = m.z - 40.0
	var z1: float = m.z - 0.5
	var ox: float = m.x
	for x: float in [ox + 2.6, ox + BUS_X - 2.6]:
		FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(0.08, 0.08, z1 - z0)), Vector3(x, 1.0, (z0 + z1) * 0.5), fence)
		var z := z0
		while z <= z1:
			FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(0.08, 1.0, 0.08)), Vector3(x, 0.5, z), fence)
			z += 2.5

	# La prensa tras las vallas, mirando al pasillo: fotógrafos (de rodillas
	# delante, de pie detrás) y cámaras de tele al hombro. Primero los de junto a
	# la entrada; cuántos, según la popularidad del club.
	var photogs: Array = []
	var left: int = PRESS_BY_STARS[clampi(club_stars, 0, 5)]
	var walk_x := ox - 0.8   # por donde pasa el jugador, más o menos
	var z := m.z - 0.8
	var i := 0
	while z > m.z - 17.0 and left > 0:
		var look := Vector3(walk_x, 0.0, z + 1.5)
		if i % 4 == 1:
			_tv_camera(set, Vector3(ox + 3.6 + rng.randf_range(-0.1, 0.2), 0.0, z), look)
		else:
			var av := CeremonyKit.photographer(set, Vector3(ox + 3.1 + rng.randf_range(-0.1, 0.15), 0.0, z), look, PRESS)
			photogs.append(av)
		left -= 1
		if i % 2 == 0 and left > 0:
			left -= 1
			var st := CeremonyKit.photographer(set, Vector3(ox + 4.2 + rng.randf_range(-0.1, 0.3), 0.0, z + 0.6), look, PRESS)
			st.anim.play("idle")
			st.anim.seek(rng.randf() * 2.0, true)
			photogs.append(st)
		z -= rng.randf_range(1.5, 2.0)
		i += 1
	# Al otro lado del autobús, el resto (se ven cuando llega)
	z = m.z - 2.0
	while z > m.z - 22.0 and left > 0:
		left -= 1
		var look := Vector3(ox + BUS_X, 0.0, z + 3.0)
		if i % 3 == 0:
			_tv_camera(set, Vector3(ox + BUS_X - 3.4, 0.0, z), look)
		else:
			var av := CeremonyKit.photographer(set, Vector3(ox + BUS_X - 3.2, 0.0, z), look, PRESS)
			av.anim.play("idle")
			photogs.append(av)
		z -= rng.randf_range(2.6, 3.4)
		i += 1
	set.set_meta("photogs", photogs)
	set.set_meta("flash_rng", rng)

	if night:
		# Luz de la explanada: el pasillo no se queda a oscuras
		for k in 2:
			var ol := OmniLight3D.new()
			ol.light_color = Color(1.0, 0.9, 0.75)
			ol.light_energy = 2.2
			ol.omni_range = 26.0
			ol.position = m + Vector3(0.0, 7.0, -4.0 - k * 16.0)
			set.add_child(ol)

	# El autobús del club
	var bus := _bus(team_name, c1, c2)
	bus.position = bus_center(0.0)
	set.add_child(bus)
	set.set_meta("bus", bus)
	return set


## Mueve el autobús, gira sus ruedas y dispara flashes en el segundo `t` de la toma
## (más flashes cuando el jugador ya ha bajado).
static func update(set: Node3D, t: float) -> void:
	var bus := set.get_meta("bus", null) as Node3D
	if bus == null:
		return
	var before := bus.position
	bus.position = bus_center(t)
	var moved: float = bus.position.z - before.z
	for w: Node3D in bus.get_meta("wheels", []):
		w.rotate_x(moved / 0.5)
	var photogs: Array = set.get_meta("photogs", [])
	var rng: RandomNumberGenerator = set.get_meta("flash_rng", null)
	if photogs.is_empty() or rng == null:
		return
	var chance := 0.35 if t >= STEP_OFF else (0.12 if t >= DRIVE * 0.7 else 0.0)
	if rng.randf() < chance:
		CeremonyKit.flash(photogs[rng.randi() % photogs.size()])


## Entrada cubierta de los vestuarios, pegada a la fachada: suelo, paredes, techo
## con luces, portada con el nombre del club en la boca y, al fondo, la puerta
## iluminada con el cartel "VESTUARIOS".
static func _entry(set: Node3D, team_name: String, c1: Color, c2: Color, night: bool) -> void:
	var g := gate()
	var m := mouth()
	var cz: float = (g.z + m.z) * 0.5
	var ox: float = g.x
	var wall := Color(0.82, 0.83, 0.85)
	var hw := ENTRY_W * 0.5
	# Suelo (losas oscuras) y alfombra del color del club hasta la puerta
	FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(ENTRY_W, 0.06, ENTRY_LEN)), Vector3(ox, 0.03, cz), Color(0.36, 0.33, 0.3))
	FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(1.8, 0.07, ENTRY_LEN + 2.5)), Vector3(ox, 0.04, cz - 1.25), c1.darkened(0.25))
	# Paredes y techo
	for s: float in [-1.0, 1.0]:
		FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(0.3, ENTRY_H, ENTRY_LEN)), Vector3(ox + s * (hw + 0.15), ENTRY_H * 0.5, cz), wall)
		# Franja del color del club a media altura, por dentro
		FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(0.04, 0.35, ENTRY_LEN - 0.4)), Vector3(ox + s * (hw - 0.02), 1.6, cz), c1)
	FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(ENTRY_W + 0.6, 0.35, ENTRY_LEN + 0.4)), Vector3(ox, ENTRY_H + 0.17, cz - 0.2), wall.darkened(0.15))
	# Plafones en el techo (emisivos) y su luz
	for k in 3:
		var lz: float = m.z + 1.0 + k * (ENTRY_LEN - 1.6) * 0.5
		var lamp := FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(2.2, 0.05, 0.4)), Vector3(ox, ENTRY_H - 0.03, lz), Color(1.0, 0.97, 0.9), true)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var inner := OmniLight3D.new()
	inner.light_color = Color(1.0, 0.95, 0.86)
	inner.light_energy = 2.4 if night else 1.6
	inner.omni_range = 8.0
	inner.position = Vector3(ox, ENTRY_H - 0.6, cz)
	set.add_child(inner)
	# Fondo: pared con la puerta del vestuario abierta y luz cálida dentro
	var back := wall.darkened(0.08)
	var side_w: float = (ENTRY_W - 2.4) * 0.5
	for s: float in [-1.0, 1.0]:
		FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(side_w, ENTRY_H, 0.3)), Vector3(ox + s * (1.2 + side_w * 0.5), ENTRY_H * 0.5, g.z + 0.35), back)
		# Jambas del hueco (se ve el grosor al entrar)
		FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(0.1, 2.8, 0.6)), Vector3(ox + s * 1.25, 1.4, g.z + 0.5), back.darkened(0.2))
	FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(2.4, ENTRY_H - 2.8, 0.3)), Vector3(ox, 2.8 + (ENTRY_H - 2.8) * 0.5, g.z + 0.35), back)
	FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(2.4, 0.1, 0.6)), Vector3(ox, 2.8, g.z + 0.5), back.darkened(0.2))
	# Al fondo del hueco, luz cálida del vestuario: el jugador se pierde en ella
	var glow := FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(2.4, 2.8, 0.05)), Vector3(ox, 1.4, g.z + 0.78), Color(1.0, 0.86, 0.6), true)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for s: float in [-1.0, 1.0]:
		FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(0.18, 2.9, 0.12)), Vector3(ox + s * 1.29, 1.45, g.z + 0.12), Color(0.15, 0.15, 0.17))
	FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(2.76, 0.18, 0.12)), Vector3(ox, 2.88, g.z + 0.12), Color(0.15, 0.15, 0.17))
	var door_light := OmniLight3D.new()
	door_light.light_color = Color(1.0, 0.85, 0.6)
	door_light.light_energy = 1.8
	door_light.omni_range = 5.0
	door_light.position = g + Vector3(0.0, 1.6, -0.8)
	set.add_child(door_light)
	_label(set, "VESTUARIOS", 56, Color(1.0, 1.0, 1.0), g + Vector3(0.0, 3.3, 0.1))
	# Portada en la boca: pilares, dintel con el color del club y su nombre
	var post := Color(0.85, 0.86, 0.88)
	for s: float in [-1.0, 1.0]:
		FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(0.7, ENTRY_H + 0.9, 0.7)), m + Vector3(s * (hw + 0.2), (ENTRY_H + 0.9) * 0.5, 0.0), post)
	FieldBuilder.add_mesh(set, FieldBuilder.box(Vector3(ENTRY_W + 1.4, 1.0, 0.8)), m + Vector3(0.0, ENTRY_H + 0.85, 0.0), c1)
	var tint := c2 if c2.get_luminance() > 0.25 else Color.WHITE
	_label(set, team_name.to_upper(), 72, tint, m + Vector3(0.0, ENTRY_H + 0.85, -0.42))


static func _label(set: Node3D, text: String, size: int, tint: Color, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.009
	l.outline_size = 10
	l.modulate = tint
	l.position = pos
	l.rotation.y = PI   # se lee desde fuera (mirando hacia +z)
	set.add_child(l)


## Cámara de tele al hombro, de pie, mirando hacia `look`.
static func _tv_camera(set: Node3D, pos: Vector3, look: Vector3) -> void:
	var av := PlayerAvatar.new()
	set.add_child(av)
	av.set_colors({"skin_color": PlayerProfile.SKIN_TONES.pick_random(), "hair_color": PlayerProfile.HAIR_COLORS.pick_random(),
		"show_hair": true, "shirt_color": Color(0.12, 0.12, 0.14), "long_sleeves": true, "long_pants": true,
		"shorts_color": Color(0.22, 0.22, 0.26), "socks_color": Color(0.1, 0.1, 0.12), "boots_color": Color(0.06, 0.06, 0.07)})
	av.position = pos
	CeremonyKit.face(av, look, 1.0)
	av.anim.play("idle")
	av.anim.seek(randf() * 2.0, true)
	var cam := Node3D.new()
	cam.position = Vector3(-0.3, 1.6, 0.16)
	av.add_child(cam)
	var body := MeshInstance3D.new()
	body.mesh = FieldBuilder.box(Vector3(0.18, 0.21, 0.4))
	body.material_override = FieldBuilder.mat(Color(0.08, 0.08, 0.09))
	cam.add_child(body)
	var lens := CylinderMesh.new()
	lens.top_radius = 0.065
	lens.bottom_radius = 0.08
	lens.height = 0.22
	var lm := MeshInstance3D.new()
	lm.mesh = lens
	lm.material_override = FieldBuilder.mat(Color(0.18, 0.18, 0.2))
	lm.position = Vector3(0.0, 0.0, 0.29)
	lm.rotation.x = PI * 0.5
	cam.add_child(lm)
	# Piloto rojo de "grabando"
	var rec := FieldBuilder.add_mesh(cam, FieldBuilder.box(Vector3(0.03, 0.03, 0.03)), Vector3(0.06, 0.12, 0.15), Color(1.0, 0.1, 0.1), true)
	rec.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	av.pose_arms("cam_shoulder", 0.01)


static func _bus(team_name: String, c1: Color, c2: Color) -> Node3D:
	var bus := Node3D.new()
	bus.name = "TeamBus"
	var glass := Color(0.06, 0.08, 0.1)
	var body := FieldBuilder.add_mesh(bus, FieldBuilder.box(Vector3(2.6, 2.9, BUS_LEN)), Vector3(0.0, 1.95, 0.0), c1)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	FieldBuilder.add_mesh(bus, FieldBuilder.box(Vector3(2.64, 0.5, BUS_LEN + 0.04)), Vector3(0.0, 0.8, 0.0), c2)
	FieldBuilder.add_mesh(bus, FieldBuilder.box(Vector3(2.66, 1.0, BUS_LEN - 2.4)), Vector3(0.0, 2.55, -0.6), glass)
	FieldBuilder.add_mesh(bus, FieldBuilder.box(Vector3(2.4, 1.5, 0.06)), Vector3(0.0, 2.45, BUS_LEN * 0.5 + 0.01), glass)
	FieldBuilder.add_mesh(bus, FieldBuilder.box(Vector3(2.5, 0.3, BUS_LEN - 0.6)), Vector3(0.0, 3.5, 0.0), c1.darkened(0.15))
	# Puerta delantera (lado del pasillo) y faros
	FieldBuilder.add_mesh(bus, FieldBuilder.box(Vector3(0.06, 2.3, 1.1)), Vector3(1.32, 1.65, BUS_LEN * 0.5 - 1.6), glass)
	for s: float in [-1.0, 1.0]:
		var hl := FieldBuilder.add_mesh(bus, FieldBuilder.box(Vector3(0.45, 0.22, 0.05)), Vector3(s * 0.85, 1.05, BUS_LEN * 0.5 + 0.03), Color(1.0, 0.97, 0.85), true)
		hl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Nombre del club en los dos costados
	for s: float in [-1.0, 1.0]:
		var l := Label3D.new()
		l.text = team_name.to_upper()
		l.font_size = 96
		l.pixel_size = 0.01
		l.outline_size = 14
		l.modulate = c2 if c2.get_luminance() > 0.25 else Color.WHITE
		l.position = Vector3(s * 1.34, 1.5, -0.8)
		l.rotation.y = s * PI * 0.5
		bus.add_child(l)
	var wheels: Array = []
	for zs: float in [BUS_LEN * 0.5 - 2.0, -BUS_LEN * 0.5 + 2.2]:
		for s: float in [-1.0, 1.0]:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.5
			cyl.bottom_radius = 0.5
			cyl.height = 0.35
			var w := Node3D.new()
			w.position = Vector3(s * 1.2, 0.5, zs)
			var wm := MeshInstance3D.new()
			wm.mesh = cyl
			wm.rotation.z = PI * 0.5
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.08, 0.08, 0.09)
			wm.material_override = m
			w.add_child(wm)
			bus.add_child(w)
			wheels.append(w)
	bus.set_meta("wheels", wheels)
	return bus
