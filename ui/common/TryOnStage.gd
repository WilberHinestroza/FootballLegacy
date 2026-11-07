extends Control
## Probador 3D de la tienda (7-nov): tu jugador de cuerpo entero EN VIVO (no la
## foto fija del retrato), girando despacio sobre una peana para que veas la prenda
## por delante, de lado y por detrás. Arrastrar con el dedo lo gira; al soltarlo,
## a los pocos segundos sigue girando solo. Al probarte algo nuevo hace un gesto.
##   var st := TryOnStage.make(cfg, 250)   (const TryOnStage = preload(...))   # null sin 3D (sigue el pixel art)

const AUTO_SPIN := 0.45      # rad/s girando solo
const DRAG_SPEED := 0.012    # rad por píxel arrastrado
const RESUME_AFTER := 2.5    # s sin tocar hasta que vuelve a girar solo

var _portrait: PlayerPortrait
var _yaw := 0.35
var _idle := 99.0
var _drag := false


static func make(cfg: Dictionary, px: int, gesture := false) -> Control:
	if not Avatar3D.enabled():
		return null
	var st = load("res://ui/common/TryOnStage.gd").new()
	st._setup(Avatar.from_legacy(cfg), px, gesture)
	return st


func _setup(cfg: Dictionary, px: int, gesture: bool) -> void:
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_portrait = PlayerPortrait.new(px, Color(0, 0, 0, 0), true)
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Avatar3D.apply(_portrait.avatar, cfg)
	Avatar3D._kit_decals(_portrait, cfg)
	add_child(_portrait)
	# Peana: sombra ovalada a los pies (que no flote en el panel)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.55
	cyl.height = 0.01
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.32)
	cyl.material = mat
	disc.mesh = cyl
	_portrait.avatar.get_parent().add_child(disc)
	if gesture:
		_portrait.play("victory_idle", false)


func _process(delta: float) -> void:
	if _portrait == null or not is_visible_in_tree():
		return
	_idle += delta
	if not _drag and _idle > RESUME_AFTER:
		_yaw += AUTO_SPIN * delta
	_portrait.avatar.rotation.y = _yaw


func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		_drag = e.pressed
		_idle = 0.0
		accept_event()
	elif (e is InputEventScreenDrag or e is InputEventMouseMotion) and _drag:
		_yaw += float(e.relative.x) * DRAG_SPEED
		_idle = 0.0
		accept_event()
