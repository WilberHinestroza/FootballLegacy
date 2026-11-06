class_name PlayerSprite
extends Node2D
## Dibuja a un futbolista con las animaciones de cancha de FootballCareer
## (assets/pixelplayer/anim/<anim>/<n>.png + <n>_m.png), teñido por shader,
## con la cabeza/peinado/barba ENCIMA de cada cuadro según la tabla de
## AnimHeadOffsets.VIEWS (de frente: capas de siempre; de espaldas o de
## costado: hair_n / hair_e / hair_w).
## El punto (0,0) del nodo son los PIES.

const FEET := Vector2(34, 54)        # pies dentro del lienzo de 68×68
const LOOPING := ["idle", "run", "run8", "trote", "drib"]
const SHORT8 := {"north": "", "north-east": "_ne", "east": "_e", "south-east": "_se",
	"south": "_s", "south-west": "_sw", "west": "_w", "north-west": "_nw"}
const DIRS8 := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

var cfg: Dictionary = {}
var anim: String = ""
var frame: int = 0
var fps: float = 10.0
var speed_scale: float = 1.0
var loop: bool = true
var done: bool = false

var _rig: Node2D
var _body: Sprite2D
var _heads: Array[Sprite2D] = []
var _layers: Array = []
var _hair_id: String = ""
var _t: float = 0.0
var _count: int = 0
var _flip := false

func setup(config: Dictionary) -> void:
	cfg = config
	_layers = PitchAvatar.head_layers(cfg)
	_hair_id = String(cfg.get("hair", ""))
	if _hair_id == "rapado":
		_hair_id = ""
	_rig = Node2D.new()
	add_child(_rig)
	_body = _new_sprite()
	for _i in maxi(_layers.size(), 1):
		_heads.append(_new_sprite())

func _new_sprite() -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.material = PitchAvatar.make_material(cfg)
	_rig.add_child(s)
	return s

## Nombre real de la animación para un tipo y una dirección.
##  - run / run8 / trote / drib / idle: 8 direcciones con nombre completo.
##  - pase / remate / barrida: 8 direcciones con sufijo corto (_ne, _e...).
##  - entrada / control / regate / cabezazo / caida / levanta: 4 direcciones.
static func resolve(kind: String, dir: Vector2) -> String:
	var d8: String = DIRS8[posmod(int(round(dir.angle() / (PI / 4.0))), 8)]
	if kind in ["idle", "run", "run8", "trote", "drib"]:
		return "pitch_%s_%s" % [kind, d8]
	if kind in ["pase", "remate", "barrida"]:
		return "pitch_%s%s" % [kind, SHORT8[d8]]
	if kind in ["entrada", "control", "regate", "cabezazo", "caida", "levanta"]:
		var d4: String = ["_e", "_s", "_w", ""][posmod(int(round(dir.angle() / (PI / 2.0))), 4)]
		return "pitch_%s%s" % [kind, d4]
	return "pitch_" + kind

## Cambia de animación (si es la misma, sigue donde iba salvo `restart`).
func set_anim(name: String, p_loop: bool = true, p_fps: float = 10.0, restart: bool = false) -> void:
	if not PitchAvatar.has_anim(name):
		return
	loop = p_loop
	fps = p_fps
	if name == anim and not restart:
		return
	var keep: int = frame
	var was_loop: bool = anim != "" and _is_loop_family(anim)
	anim = name
	_count = PitchAvatar.frame_count(name)
	done = false
	_t = 0.0
	# Al cambiar de dirección corriendo, se conserva la fase de la zancada.
	frame = keep % _count if (was_loop and _is_loop_family(name) and loop) else 0
	_apply_frame()

func _is_loop_family(n: String) -> bool:
	for k in LOOPING:
		if n.begins_with("pitch_" + k + "_"):
			return true
	return false

func set_flip(f: bool) -> void:
	if f == _flip:
		return
	_flip = f
	_place_rig()

func set_flash(c: Color) -> void:
	for s in [_body] + _heads:
		(s.material as ShaderMaterial).set_shader_parameter("flash", c)

func _place_rig() -> void:
	if _rig == null:
		return
	_rig.scale.x = -1.0 if _flip else 1.0
	_rig.position = Vector2(FEET.x if _flip else -FEET.x, -FEET.y)

## Cabeza de los gestos que no están en la tabla generada (rastreadas con
## tools/anim_head_track.py). Los festejos usan la tabla OFFSETS (de frente).
const EXTRA_VIEWS := {
	"pitch_pide": [["s", 0, 0], ["s", 0, 0], ["s", 0, 0], ["s", 0, 0]],
	"lamento": [["s", 0, 0], ["s", 0, 0], ["s", 0, 1], ["s", 0, 2], ["s", 0, 4], ["s", 0, 4], ["s", 0, 2], ["s", 0, 1], ["s", 0, 0]],
	"puno": [["s", 0, 0], ["s", 0, 0], ["s", 0, 1], ["s", 0, 2], ["s", 0, 2], ["s", 0, 2], ["s", 0, 2], ["s", 0, 1], ["s", 0, 1]],
}
static var _views_cache: Dictionary = {}

static func _views_of(a: String) -> Array:
	if AnimHeadOffsets.VIEWS.has(a):
		return AnimHeadOffsets.VIEWS[a]
	if EXTRA_VIEWS.has(a):
		return EXTRA_VIEWS[a]
	if _views_cache.has(a):
		return _views_cache[a]
	var out: Array = []
	for o in AnimHeadOffsets.OFFSETS.get(a, []):
		out.append(null if o == null else ["s", (o as Vector2i).x, (o as Vector2i).y])
	_views_cache[a] = out
	return out

## Cámara lenta global de las animaciones (la usa la pausa estilo WSC).
static var time_k: float = 1.0

func _process(dt: float) -> void:
	if anim == "" or _count <= 1 or done:
		return
	_t += dt * fps * speed_scale * time_k
	while _t >= 1.0:
		_t -= 1.0
		if frame + 1 >= _count:
			if loop:
				frame = 0
			else:
				done = true
				break
		else:
			frame += 1
		_apply_frame()

func _apply_frame() -> void:
	_place_rig()
	var base: String = "%sanim/%s/%d" % [PitchAvatar.DIR, anim, frame]
	_set_tex(_body, base, Vector2.ZERO)
	for h in _heads:
		h.visible = false
	var views: Array = _views_of(anim)
	if views.is_empty() and anim.begins_with("gk_"):
		_gk_head()
		return
	if frame >= views.size() or views[frame] == null:
		return
	var vw: Array = views[frame]
	var d := Vector2(float(vw[1]), float(vw[2]))
	if String(vw[0]) == "s":
		for i in _layers.size():
			var l: Array = _layers[i]
			_set_tex(_heads[i], "%s%s/%s" % [PitchAvatar.DIR, l[0], l[1]], Vector2(10, 10) + d)
	elif _hair_id != "":
		_set_tex(_heads[0], "%shair_%s/%s" % [PitchAvatar.DIR, String(vw[0]), _hair_id], d)

func _set_tex(s: Sprite2D, base_path: String, pos: Vector2) -> void:
	var t: Texture2D = PitchAvatar.tex(base_path + ".png")
	var m: Texture2D = PitchAvatar.tex(base_path + "_m.png")
	if t == null:
		s.visible = false
		return
	s.texture = t
	s.position = pos
	s.visible = true
	(s.material as ShaderMaterial).set_shader_parameter("mask_tex", m)

## Las animaciones del arquero no tienen tabla de cabeza: en las que está
## parado (quieto, paso, con el balón) el peinado va en la posición base.
## En estiradas/voladas/saques se deja el corte base (la cabeza se mueve).
func _gk_head() -> void:
	for bad in ["estirada", "volada", "achique", "lanzar", "saque", "atajada", "punos", "salto"]:
		if anim.contains(bad):
			return
	var view: String = "s"
	if anim.ends_with("_n") or anim.ends_with("north"):
		view = "n"
	elif anim.ends_with("east"):
		view = "e"
	elif anim.ends_with("west"):
		view = "w"
	if view == "s":
		for i in _layers.size():
			var l: Array = _layers[i]
			_set_tex(_heads[i], "%s%s/%s" % [PitchAvatar.DIR, l[0], l[1]], Vector2(10, 10))
	elif _hair_id != "":
		_set_tex(_heads[0], "%shair_%s/%s" % [PitchAvatar.DIR, view, _hair_id], Vector2.ZERO)
