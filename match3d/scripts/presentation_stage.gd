class_name PresentationStage
extends Node3D
## Presentación oficial en el estadio (7-nov, Wilber: "mejorar la presentación en
## estadio"). Estadio de noche lleno con los colores del club, alfombra desde el túnel
## hasta una tarima con el escudo detrás. Tu jugador sale del túnel con la camiseta
## nueva (diseño, escudo y dorsal del partido), le da la mano al presidente, enseña la
## camiseta con su dorsal a los fotógrafos (flashes) y saluda a la grada con confeti.
## Mundo y cámara propios: PlayerPresentation lo mete en pantalla con make_view().
##
## d = {profile: PlayerProfile, shirt, shirt2: Color, pattern: int, crest_center: bool,
##      crest: Callable -> Control, held_shirt: Callable -> Control,
##      club_name, sponsor, surname: String, number: int, stars: int}

signal finale  # ya posa ante la grada: la interfaz puede enseñar la ficha y "Continuar"

# La alfombra sale recta del túnel; la tarima queda a un LADO de la alfombra (con su
# fondo detrás), así nadie atraviesa el fondo: sale, gira y sube por el escalón.
const TUNNEL := Vector3(FieldBuilder.TUNNEL_X, 0.0, -39.5)
const STAGE_Z := -32.0
const STAGE_X := FieldBuilder.TUNNEL_X + 4.4
const STAGE_H := 0.3
const WAY := Vector3(FieldBuilder.TUNNEL_X, 0.0, STAGE_Z + 0.2)               # giro hacia la tarima
const SPOT := Vector3(STAGE_X - 0.6, STAGE_H, STAGE_Z + 0.2)                  # dónde posa el jugador
const PRES_SPOT := Vector3(STAGE_X + 0.65, STAGE_H, STAGE_Z + 0.2)

var camera: Camera3D
var player: PlayerAvatar
var _d: Dictionary
var _pres: PlayerAvatar
var _snappers: Array[PlayerAvatar] = []
var _shirt: MeshInstance3D
var _phase := "walk"   # walk -> meet -> shirt -> fans
var _leg := 0          # walk: 0 por la alfombra, 1 subiendo a la tarima
var _pending := {}
var _phase_t := 0.0
var _flash_t := 0.0
var _finale_sent := false
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _prim := Color.RED
var _sec := Color.WHITE


static func make_view(d: Dictionary, size: Vector2) -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(maxi(int(size.x), 640), maxi(int(size.y), 360))
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(vp)
	var s := PresentationStage.new()
	s.name = "Stage"
	s._pending = d
	vp.add_child(s)   # setup() en _ready, ya dentro del árbol
	return box


func _ready() -> void:
	if not _pending.is_empty():
		setup(_pending)
		_pending = {}


func setup(d: Dictionary) -> void:
	_d = d
	_prim = d.get("shirt", Color.RED)
	_sec = d.get("shirt2", Color.WHITE)
	# Estadio de noche y lleno, todo con la hinchada del club
	FieldBuilder.time_of_day = 2
	FieldBuilder.stars = clampi(int(d.get("stars", 4)), 1, 5)
	FieldBuilder.home_color = _prim
	FieldBuilder.home_color2 = _sec
	FieldBuilder.away_color = _prim
	FieldBuilder.crowd_fill = 0.95
	FieldBuilder.crowd = {}
	FieldBuilder.banner_seed_name = String(d.get("club_name", ""))
	AdBoards.home_name = String(d.get("club_name", ""))
	FieldBuilder.build(self)
	_build_stage()
	_build_people()
	camera = Camera3D.new()
	# En vertical (móvil) se fija el ancho: con KEEP_HEIGHT no cabían ni dos personas
	var vs := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(16, 9)
	if vs.y > vs.x:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = 50.0
	else:
		camera.fov = 50.0
	camera.far = 400.0
	add_child(camera)
	camera.make_current()
	_cam_pos = TUNNEL + Vector3(-2.2, 1.6, 4.4)
	_cam_look = TUNNEL + Vector3(0, 1.25, 0)
	camera.look_at_from_position(_cam_pos, _cam_look, Vector3.UP)


# ---------------------------------------------------------------- escenario

func _mat(c: Color, rough := 0.7, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _box(size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = FieldBuilder.box(size)
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


func _build_stage() -> void:
	var tx := FieldBuilder.TUNNEL_X
	var x := STAGE_X
	# Alfombra del color del club desde el túnel, con filo del segundo color, y un
	# tramo corto que gira hasta el escalón de la tarima
	var carpet_len := absf(TUNNEL.z - STAGE_Z) + 1.0
	var cz := TUNNEL.z + carpet_len * 0.5
	var rug := _mat(_prim.darkened(0.15), 0.95)
	var edge := _mat(_sec, 0.9)
	_box(Vector3(1.6, 0.02, carpet_len), Vector3(tx, 0.01, cz), rug)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0.08, 0.025, carpet_len), Vector3(tx + s * 0.8, 0.012, cz), edge)
	var side_len := (x - 3.0) - tx
	_box(Vector3(side_len, 0.021, 1.6), Vector3(tx + side_len * 0.5, 0.011, WAY.z), rug)
	# Tarima con escalón y borde de luz
	var dark := _mat(Color(0.08, 0.08, 0.1), 0.35)
	_box(Vector3(6.0, STAGE_H, 3.0), Vector3(x, STAGE_H * 0.5, STAGE_Z - 0.3), dark)
	_box(Vector3(0.5, STAGE_H * 0.5, 1.6), Vector3(x - 3.25, STAGE_H * 0.25, WAY.z), dark)
	_box(Vector3(6.0, 0.04, 0.06), Vector3(x, STAGE_H, STAGE_Z + 1.2), _mat(_sec, 0.4, 2.0))
	# Fondo con el escudo y el nombre del club, y el patrocinio a los lados
	var wall_z := STAGE_Z - 1.75
	_box(Vector3(7.0, 3.2, 0.2), Vector3(x, STAGE_H + 1.6, wall_z), _mat(_prim.darkened(0.35), 0.6))
	_box(Vector3(7.0, 0.12, 0.24), Vector3(x, STAGE_H + 3.2, wall_z), _mat(_sec, 0.5, 1.2))
	var club := Label3D.new()
	club.text = String(_d.get("club_name", "")).to_upper()
	club.font_size = 96
	club.pixel_size = 0.0055
	club.outline_size = 12
	club.position = Vector3(x, STAGE_H + 0.95, wall_z + 0.12)
	add_child(club)
	var sp := String(_d.get("sponsor", ""))
	if sp != "":
		for s: float in [-1.0, 1.0]:
			var l := Label3D.new()
			l.text = sp
			l.font_size = 64
			l.pixel_size = 0.005
			l.modulate = _sec
			l.position = Vector3(x + s * 2.6, STAGE_H + 2.2, wall_z + 0.12)
			add_child(l)
	# Focos sobre la tarima
	for s: float in [-1.0, 1.0]:
		var spot := SpotLight3D.new()
		spot.spot_range = 20.0
		spot.spot_angle = 22.0
		spot.light_energy = 7.0
		spot.light_color = Color(1.0, 0.95, 0.85)
		add_child(spot)
		spot.look_at_from_position(Vector3(x + s * 4.0, 7.5, STAGE_Z + 6.0), SPOT + Vector3(0, 1.0, 0), Vector3.UP)
	_crest_on_wall(Vector3(x, STAGE_H + 2.15, wall_z + 0.12))


func _crest_on_wall(pos: Vector3) -> void:
	var tex := await _bake(_d.get("crest", null), 256)
	if tex == null or not is_inside_tree():
		return
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.5, 1.5)
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material_override = m
	q.position = pos
	add_child(q)


## Pinta un Control (escudo, camiseta) en una textura, una vez.
func _bake(maker: Variant, px: int) -> Texture2D:
	if not (maker is Callable) or DisplayServer.get_name() == "headless":
		return null
	var c: Variant = (maker as Callable).call()
	if not (c is Control):
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var ctl := c as Control
	ctl.position = Vector2.ZERO
	ctl.custom_minimum_size = Vector2(px, px)
	ctl.size = Vector2(px, px)
	vp.add_child(ctl)
	for i in 3:
		await RenderingServer.frame_post_draw
	if not is_instance_valid(vp):
		return null
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- gente

func _build_people() -> void:
	player = PlayerAvatar.new()
	add_child(player)
	var prof: PlayerProfile = _d.get("profile", null)
	if prof != null:
		player.apply_profile(prof)
	player.set_colors({"shirt_pattern": int(_d.get("pattern", 0)), "shirt_color2": _sec,
		"crest_center": bool(_d.get("crest_center", false))})
	player.position = TUNNEL
	player.anim.play("walk")
	_bake_decals()
	_pres = CeremonyKit.suit_person(self, _prim, "presidente:" + String(_d.get("club_name", "")))
	_pres.position = PRES_SPOT
	CeremonyKit.face(_pres, TUNNEL, 1.0)
	# Fotógrafos de rodillas delante de la tarima
	# En arco por delante-derecha: el lado izquierdo queda libre para las cámaras
	for i in 6:
		var ang: float = 0.72 + i * 0.1
		var r: float = 3.5 + (0.4 if i % 2 == 1 else 0.0)
		var pos := Vector3(SPOT.x + sin(ang) * r, 0.0, SPOT.z + cos(ang) * r)
		_snappers.append(CeremonyKit.photographer(self, pos, SPOT, Color(0.9, 0.9, 0.2)))


func _bake_decals() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var ink: Color = _sec if absf(_prim.get_luminance() - _sec.get_luminance()) > 0.45 \
			else (Color(0.08, 0.08, 0.1) if _prim.get_luminance() > 0.55 else Color(0.97, 0.97, 0.97))
	var wr: WeakRef = weakref(player)
	var job := {
		"target": func(t: Texture2D) -> void:
			var av: PlayerAvatar = wr.get_ref()
			if av != null:
				av.set_decals(t),
		"crest": _d.get("crest", func() -> Control: return Control.new()),
		"sponsor": String(_d.get("sponsor", "")),
		"number": int(_d.get("number", 0)),
		"name": String(_d.get("surname", "")).to_upper(),
		"ink": ink,
		"edge": _prim,
	}
	KitDecals.bake_all(self, [job])


# ---------------------------------------------------------------- secuencia

func _process(delta: float) -> void:
	_phase_t += delta
	match _phase:
		"walk":
			var goal: Vector3 = WAY if _leg == 0 else SPOT
			if not CeremonyKit.step_to(player, player.anim, goal, 1.9, delta):
				if _leg == 0:
					_leg = 1
				else:
					_go("meet")
					player.anim.play("idle", 0.3)
			CeremonyKit.face(_pres, player.global_position, delta * 3.0)
		"meet":
			# Apretón de manos con el presidente, de cara uno al otro
			CeremonyKit.face(player, _pres.global_position, delta * 6.0)
			CeremonyKit.face(_pres, player.global_position, delta * 6.0)
			if _phase_t > 0.35 and _phase_t - delta <= 0.35:
				player.pose_arms("shake", 0.35)
				_pres.pose_arms("shake", 0.35)
			if _phase_t > 2.4:
				player.pose_arms("", 0.3)
				_pres.pose_arms("", 0.3)
				_go("shirt")
				_show_shirt()
		"shirt":
			# De frente a las cámaras, enseña la camiseta con su dorsal
			CeremonyKit.face(player, player.global_position + Vector3(0, 0, 1), delta * 5.0)
			CeremonyKit.face(_pres, player.global_position + Vector3(0, 0, 4), delta * 5.0)
			if _phase_t > 3.6:
				_go("fans")
				_to_fans()
		"fans":
			CeremonyKit.face(player, player.global_position + Vector3(0, 0, 1), delta * 4.0)
			if not player.anim.is_playing():
				player.anim.play(["clap", "victory_idle", "fist_pump"].pick_random(), 0.3)
			if not _pres.anim.is_playing():
				_pres.anim.play("clap", 0.3)
	_place_shirt()
	_flashes(delta)
	_update_camera(delta)


func _go(p: String) -> void:
	_phase = p
	_phase_t = 0.0


## Salta al final (la interfaz lo llama si tocas la pantalla).
func skip_to_end() -> void:
	if _phase == "fans":
		return
	player.global_position = SPOT
	player.pose_arms("", 0.1)
	_pres.pose_arms("", 0.1)
	_go("fans")
	_to_fans()
	_cam_pos = _fans_cam()
	_cam_look = SPOT + Vector3(0, 0.55, 0)


func _show_shirt() -> void:
	player.pose_arms("hold", 0.4)
	if _shirt != null:
		return
	_shirt = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.62, 0.62)
	_shirt.mesh = qm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shirt.material_override = m
	_shirt.visible = false
	add_child(_shirt)
	var tex := await _bake(_d.get("held_shirt", null), 256)
	if tex != null and is_instance_valid(_shirt):
		m.albedo_texture = tex


func _place_shirt() -> void:
	if _shirt == null:
		return
	var m := _shirt.material_override as StandardMaterial3D
	_shirt.visible = _phase == "shirt" and m != null and m.albedo_texture != null
	if not _shirt.visible:
		return
	var fwd := player.global_basis.z.normalized()
	_shirt.global_position = player.hands_position() + fwd * 0.2 + Vector3(0, 0.1, 0)
	_shirt.global_rotation = Vector3(0.0, player.global_rotation.y, 0.0)


func _to_fans() -> void:
	player.pose_arms("", 0.3)
	player.anim.play("victory", 0.3)
	_pres.anim.play("clap", 0.3)
	FieldBuilder.set_crowd_excitement(self, 1.0)
	CeremonyKit.confetti(self, SPOT + Vector3(0, 6.0, 1.5), Vector3(4.0, 0.3, 2.5), [_prim, _sec, Color.WHITE, _prim.lightened(0.3)])
	if not _finale_sent:
		_finale_sent = true
		finale.emit()


func _flashes(delta: float) -> void:
	if _phase == "walk" or _snappers.is_empty():
		return
	_flash_t -= delta
	if _flash_t > 0.0:
		return
	_flash_t = randf_range(0.08, 0.3) if _phase != "fans" else randf_range(0.25, 0.7)
	CeremonyKit.flash(_snappers.pick_random())


func _fans_cam() -> Vector3:
	var a: float = 0.05 - _phase_t * 0.06
	return SPOT + Vector3(sin(a) * 4.6, 1.5, cos(a) * 4.6)


func _update_camera(delta: float) -> void:
	var want_pos: Vector3
	var want_look: Vector3
	var head := player.global_position + Vector3(0, 1.25, 0)
	match _phase:
		"walk":
			# Acompaña la salida del túnel por delante y de lado (lado libre, sin fondo)
			if _leg == 0:
				want_pos = player.global_position + Vector3(-2.2, 1.6, 4.4)
			else:
				want_pos = player.global_position + Vector3(0.3, 1.9, 3.2)
			want_look = head
		"meet":
			var mid := (player.global_position + _pres.global_position) * 0.5
			want_pos = mid + Vector3(0.0, 1.55, 3.4)
			want_look = mid + Vector3(0, 1.3, 0)
		"shirt":
			# Plano medio de frente, acercándose despacio
			var k := smoothstep(0.0, 3.6, _phase_t)
			want_pos = head + Vector3(lerpf(0.9, 0.3, k), lerpf(0.1, 0.0, k), lerpf(3.8, 2.9, k))
			want_look = head - Vector3(0, 0.15, 0)
		_:
			# Mira algo por debajo: los dos quedan arriba y la ficha de abajo no los tapa
			want_pos = _fans_cam()
			want_look = SPOT + Vector3(0, 0.55, 0)
	var k2 := minf(1.0, delta * 2.5)
	_cam_pos = _cam_pos.lerp(want_pos, k2)
	_cam_look = _cam_look.lerp(want_look, k2)
	camera.look_at_from_position(_cam_pos, _cam_look, Vector3.UP)
