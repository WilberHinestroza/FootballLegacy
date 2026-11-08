class_name CupArch
extends RefCounted
## Arco ceremonial de las copas internacionales (8-nov, Wilber: "para partidos de
## torneos internacionales como la champions o libertadores ... y asi tambien en
## el mundial"): a la salida de la manga, un arco con el nombre del torneo,
## alfombra hasta la banda y el balón del partido en su pedestal. Colores y lema
## propios de cada torneo del juego (sin logos ni marcas reales). Solo decorado:
## sin colisiones, se construye al empezar la salida. `info` = config["cup_ceremony"]
## (Match3DBridge._cup_ceremony): {kind, conf, name}.

const R := 2.6          # medio ancho libre del arco (pasan las dos filas)
const PILLAR_W := 1.1
const PILLAR_H := 4.3
const DEPTH := 0.5

## Colores (fondo, adorno) y lema de cada torneo.
static func style(info: Dictionary) -> Dictionary:
	var kind: String = String(info.get("kind", ""))
	var conf: String = String(info.get("conf", ""))
	var gold := Color(0.86, 0.69, 0.32)
	var silver := Color(0.86, 0.88, 0.93)
	match kind:
		"cont1":
			if conf == "CONMEBOL":
				return {"c1": Color(0.06, 0.06, 0.07), "c2": gold, "motto": "LA GLORIA TE ESPERA"}
			return {"c1": Color(0.05, 0.09, 0.3), "c2": silver, "motto": "EL CAMINO A LA FINAL"}
		"cont2":
			return {"c1": Color(0.92, 0.42, 0.08), "c2": Color(0.08, 0.08, 0.1), "motto": "NOCHE CONTINENTAL"}
		"cont3":
			return {"c1": Color(0.08, 0.5, 0.34), "c2": Color(0.95, 0.96, 0.97), "motto": "NOCHE CONTINENTAL"}
		"cwc":
			return {"c1": Color(0.08, 0.12, 0.26), "c2": gold, "motto": "LOS MEJORES DEL MUNDO"}
		"world":
			return {"c1": Color(0.04, 0.24, 0.17), "c2": gold, "motto": "EL MUNDO TE MIRA"}
		"natcup":
			return {"c1": Color(0.42, 0.05, 0.11), "c2": gold, "motto": "ORGULLO DE NACIÓN"}
	return {}


static func build(root: Node3D, info: Dictionary) -> Node3D:
	var st := style(info)
	if st.is_empty():
		return null
	var c1: Color = st.c1
	var c2: Color = st.c2
	var name: String = String(info.get("name", "")).to_upper()
	var motto: String = String(st.motto)
	var set := Node3D.new()
	set.name = "CupArch"
	root.add_child(set)
	var x0 := FieldBuilder.TUNNEL_X
	var line_z := -SoccerMatch.FIELD_WIDTH * 0.5
	# Fin de la manga (StadiumStaff._tunnel): de ahí a la banda va la alfombra
	var canopy_end: float = line_z - FieldBuilder.SIDE_STANDS + (FieldBuilder.SIDE_STANDS - FieldBuilder.SIDE_BOARDS + 0.6)
	var arch_z: float = canopy_end + 1.6
	var carpet_end: float = line_z - 0.4

	# Alfombra con ribete y el nombre del torneo pintado (se lee desde el campo)
	var len: float = carpet_end - canopy_end
	var cz: float = (canopy_end + carpet_end) * 0.5
	_box(set, Vector3(2.9, 0.03, len), Vector3(x0, 0.015, cz), c1, false)
	for s: float in [-1.0, 1.0]:
		_box(set, Vector3(0.1, 0.035, len), Vector3(x0 + s * 1.4, 0.018, cz), c2, false)
	_flat_label(set, name, 30, c2, Vector3(x0, 0.04, carpet_end - 0.95))
	_flat_label(set, motto, 24, Color.WHITE, Vector3(x0, 0.04, carpet_end - 0.45))

	# El arco: dos pilares con estrella y lema, viga con el nombre, filo de adorno
	for s: float in [-1.0, 1.0]:
		var px: float = x0 + s * (R + PILLAR_W * 0.5)
		_box(set, Vector3(PILLAR_W, PILLAR_H, DEPTH), Vector3(px, PILLAR_H * 0.5, arch_z), c1, false)
		for e: float in [-1.0, 1.0]:
			_box(set, Vector3(0.07, PILLAR_H, DEPTH + 0.04), Vector3(px + e * (PILLAR_W * 0.5 - 0.035), PILLAR_H * 0.5, arch_z), c2, true)
		for face: float in [-1.0, 1.0]:
			var zf: float = arch_z + face * (DEPTH * 0.5 + 0.02)
			var star := _label(set, "★", 120, c2, Vector3(px, 2.8, zf), face)
			star.pixel_size = 0.006
			var m := _label(set, motto.replace(" ", "\n"), 30, Color.WHITE, Vector3(px, 1.5, zf), face)
			m.pixel_size = 0.005
	var beam_w: float = (R + PILLAR_W) * 2.0
	_box(set, Vector3(beam_w, 0.9, DEPTH), Vector3(x0, PILLAR_H + 0.45, arch_z), c1, false)
	_box(set, Vector3(beam_w, 0.07, DEPTH + 0.04), Vector3(x0, PILLAR_H + 0.04, arch_z), c2, true)
	_box(set, Vector3(beam_w, 0.07, DEPTH + 0.04), Vector3(x0, PILLAR_H + 0.87, arch_z), c2, true)
	for face: float in [-1.0, 1.0]:
		var t := _label(set, name, 64, c2, Vector3(x0, PILLAR_H + 0.45, arch_z + face * (DEPTH * 0.5 + 0.02)), face)
		t.pixel_size = minf(0.0075, (beam_w - 0.6) / maxf(float(name.length()) * 64.0 * 0.62, 1.0))

	# El balón del partido en su pedestal, junto a la alfombra
	var ped := Vector3(x0 - 2.1, 0.0, carpet_end - 0.6)
	_box(set, Vector3(0.42, 1.05, 0.42), ped + Vector3(0.0, 0.525, 0.0), c1, false)
	_box(set, Vector3(0.5, 0.06, 0.5), ped + Vector3(0.0, 1.08, 0.0), c2, true)
	var d: Dictionary = SoccerBall.DESIGNS[clampi(SoccerBall.design, 0, SoccerBall.DESIGNS.size() - 1)]
	var sm := SphereMesh.new()
	sm.radius = SoccerBall.RADIUS
	sm.height = SoccerBall.RADIUS * 2.0
	var bm := ShaderMaterial.new()
	bm.shader = SoccerBall.BALL_SHADER
	bm.set_shader_parameter("style", d.style)
	bm.set_shader_parameter("base_color", d.base)
	bm.set_shader_parameter("panel_color", d.panel)
	bm.set_shader_parameter("accent_color", d.accent)
	bm.set_shader_parameter("metal", float(d.get("metal", 0.0)))
	bm.set_shader_parameter("panel_shade", float(d.get("shade", 0.0)))
	var ball := MeshInstance3D.new()
	ball.mesh = sm
	ball.material_override = bm
	ball.position = ped + Vector3(0.0, 1.11 + SoccerBall.RADIUS, 0.0)
	set.add_child(ball)
	return set


static func _box(set: Node3D, size: Vector3, pos: Vector3, c: Color, glow: bool) -> MeshInstance3D:
	var mi := FieldBuilder.add_mesh(set, FieldBuilder.box(size), pos, c)
	if glow:
		var m := mi.material_override as StandardMaterial3D
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.2 if FieldBuilder.time_of_day == 2 else 0.35
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Cartel vertical; `face` +1 = mira al campo (+z), -1 = hacia la manga.
static func _label(set: Node3D, text: String, size: int, tint: Color, pos: Vector3, face: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.007
	l.outline_size = 6
	l.modulate = tint
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	l.rotation.y = 0.0 if face > 0.0 else PI
	set.add_child(l)
	return l


## Texto pintado en la alfombra (tumbado, se lee desde el campo).
static func _flat_label(set: Node3D, text: String, size: int, tint: Color, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.009
	l.outline_size = 0
	l.modulate = tint
	l.position = pos
	l.rotation.x = -PI * 0.5
	set.add_child(l)
