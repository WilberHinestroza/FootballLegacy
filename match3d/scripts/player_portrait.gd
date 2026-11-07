class_name PlayerPortrait
extends SubViewportContainer
## Retrato 3D (busto) de un jugador con el MISMO modelo del partido, para fichas y
## pantallas. Va sustituyendo al retrato pixel art de FootballCareer: así el jugador
## que ves en los menús es el que juega en el campo.
##   var face := PlayerPortrait.new(84)
##   face.set_profile(profile, {"shirt_pattern": 1, "shirt_color2": Color.WHITE})
## Cuerpo entero (cartas): PlayerPortrait.new(160, Color(0, 0, 0, 0), true) — fondo transparente.
## Encuadres: "bust" (por defecto), "full" (cuerpo entero), "feet" (piernas y botas, tienda).
## Listas largas: con `snapshot_key` se dibuja una vez, se guarda como imagen (caché) y se
## suelta el 3D; la próxima vez con la misma clave sale la imagen directamente.

const SNAP_CACHE_MAX := 160
static var _snap_cache := {}

var avatar: PlayerAvatar
var framing := "bust"
var snapshot_key := ""
var _vp: SubViewport
var _cam: Camera3D
var _head := -1
var _frames := 0
var _loop_anim := ""
## Cuadros que la foto (snapshot) espera a que lleguen los estampados de la camiseta
## (Avatar3D los hornea aparte); al ponerlos se vuelve a 0.
var hold_frames := 0


func _init(px := 96, bg := Color(0.09, 0.13, 0.11), full_body := false, frame_mode := "") -> void:
	framing = frame_mode if frame_mode != "" else ("full" if full_body else "bust")
	stretch = true
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.size = Vector2i(px * 2, px * 2)
	_vp.transparent_bg = bg.a < 0.01
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.84)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30.0, 35.0, 0.0)
	key.light_energy = 1.15
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10.0, 200.0, 0.0)
	rim.light_energy = 0.5
	_vp.add_child(rim)
	avatar = PlayerAvatar.new()
	_vp.add_child(avatar)
	avatar.anim.play("idle")
	_cam = Camera3D.new()
	_cam.fov = 26.0
	_vp.add_child(_cam)
	_cam.current = true


## Imagen guardada de un retrato ya dibujado (o null).
static func cached(key: String) -> Texture2D:
	return _snap_cache.get(key)


## Tu jugador (cara, pelo, físico) con la equipación de `kit` encima (opcional).
func set_profile(p: PlayerProfile, kit: Dictionary = {}) -> void:
	avatar.apply_profile(p)
	if not kit.is_empty():
		avatar.set_colors(kit)


## Otro jugador: colores del shader y peinado 3D (ver SoccerPlayer.apply_look).
func set_look(colors: Dictionary, hair_style := "rapado") -> void:
	avatar.set_colors(colors)
	avatar.set_hair_style(hair_style)


## Pone una animación del modelo (festejos, firma...). loop = false: la repite tras una
## pausa corta, para que la pantalla no se quede quieta.
func play(anim_name: String, loop := true) -> void:
	if not avatar.anim.has_animation(anim_name):
		return
	_loop_anim = anim_name if not loop else ""
	avatar.anim.play(anim_name, 0.2)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _loop_anim != "" and not avatar.anim.is_playing():
		avatar.anim.play("idle", 0.3)
		get_tree().create_timer(1.6).timeout.connect(func() -> void:
			if is_instance_valid(avatar) and _loop_anim != "":
				avatar.anim.play(_loop_anim, 0.25))
	if _head < 0:
		_head = ItemCatalog.find_bone(avatar.skeleton, "Head")
		if _head < 0:
			return
	var k := absf(avatar.scale.y)
	match framing:
		"full":
			# Cuerpo entero, de frente y un poco de lado, con los pies dentro del cuadro
			var c := avatar.global_position + Vector3(0.0, 1.0, 0.0) * k
			_cam.global_position = c + Vector3(1.1, 0.0, 4.5) * k
			_cam.look_at(c, Vector3.UP)
		"top":
			# De cintura para arriba (tienda: camisas y chaquetas)
			var t := avatar.global_position + Vector3(0.0, 1.28, 0.0) * k
			_cam.global_position = t + Vector3(0.7, 0.05, 2.7) * k
			_cam.look_at(t, Vector3.UP)
		"legs":
			# De cintura para abajo (tienda: pantalones)
			var l := avatar.global_position + Vector3(0.0, 0.52, 0.0) * k
			_cam.global_position = l + Vector3(0.7, 0.15, 2.5) * k
			_cam.look_at(l, Vector3.UP)
		"feet":
			# Piernas y botas (tienda de guayos): de lado y desde arriba
			var f := avatar.global_position + Vector3(0.0, 0.25, 0.1) * k
			_cam.global_position = f + Vector3(1.3, 0.55, 1.2) * k
			_cam.look_at(f, Vector3.UP)
		_:
			# Busto: la cámara sigue la cabeza (el idle la mueve un poco)
			var hp := avatar.skeleton.global_transform * avatar.skeleton.get_bone_global_pose(_head).origin
			var target := hp + Vector3(0.0, 0.1, 0.0) * k
			_cam.global_position = target + Vector3(0.35, -0.08, 2.0) * k  # algo más bajo: se le ven los ojos
			_cam.look_at(target, Vector3.UP)
	if snapshot_key != "":
		_frames += 1
		if hold_frames > 0:
			hold_frames -= 1
		elif _frames >= 3:
			_take_snapshot()


## Guarda lo que se ve como imagen, la pone en lugar del 3D y libera el modelo.
func _take_snapshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img := _vp.get_texture().get_image()
	if img == null or img.is_empty():
		_frames = 0
		return
	var tex := ImageTexture.create_from_image(img)
	if _snap_cache.size() >= SNAP_CACHE_MAX:
		_snap_cache.clear()
	_snap_cache[snapshot_key] = tex
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Un SubViewportContainer solo dibuja sus SubViewport: la imagen va en un hermano
	var holder := get_parent()
	if holder == null:
		return
	r.custom_minimum_size = custom_minimum_size
	r.size_flags_horizontal = size_flags_horizontal
	r.size_flags_vertical = size_flags_vertical
	holder.add_child(r)
	holder.move_child(r, get_index())
	r.position = position
	r.size = size
	queue_free()
