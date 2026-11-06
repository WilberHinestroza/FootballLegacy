class_name Sprites
extends RefCounted
## Arma los SpriteFrames de un set de PixelLab que está en
## res://assets/players/<set>/:
##   rotations/<dir>.png          -> idle_<dir>
##   <anim>/<dir>/<n>.png         -> <anim>_<dir>   (run, kick, dive...)
## Si un set no existe, el jugador se dibuja con figuras simples.

const DIRS := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
const ANIMS := {"run": [12.0, true], "kick": [16.0, false], "dive": [12.0, false]}

static var _cache: Dictionary = {}
static var _feet: Dictionary = {}

static func has_set(set_name: String) -> bool:
	return ResourceLoader.exists("res://assets/players/%s/rotations/south.png" % set_name)

static func frames_for(set_name: String) -> SpriteFrames:
	if _cache.has(set_name):
		return _cache[set_name]
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var root: String = "res://assets/players/%s/" % set_name
	for d in DIRS:
		var rp: String = root + "rotations/%s.png" % d
		if ResourceLoader.exists(rp):
			var idle: String = "idle_" + d
			sf.add_animation(idle)
			sf.set_animation_loop(idle, false)
			sf.add_frame(idle, load(rp))
		for anim in ANIMS.keys():
			var folder: String = root + anim + "/" + d + "/"
			var name: String = anim + "_" + d
			var i: int = 0
			while ResourceLoader.exists(folder + "%d.png" % i):
				if i == 0:
					sf.add_animation(name)
					sf.set_animation_speed(name, ANIMS[anim][0])
					sf.set_animation_loop(name, ANIMS[anim][1])
				sf.add_frame(name, load(folder + "%d.png" % i))
				i += 1
	_cache[set_name] = sf
	return sf

## Desplazamiento para que el punto del nodo quede en los PIES del sprite.
static func feet_offset(set_name: String) -> Vector2:
	if _feet.has(set_name):
		return _feet[set_name]
	var off := Vector2(0, -16)
	var rp: String = "res://assets/players/%s/rotations/south.png" % set_name
	if ResourceLoader.exists(rp):
		var tex: Texture2D = load(rp)
		var r: Rect2i = opaque_rect(tex)
		var h: int = tex.get_height()
		off = Vector2(0, -(float(r.end.y) - float(h) * 0.5) + 1.0)
	_feet[set_name] = off
	return off

## Rectángulo con píxeles no transparentes de una textura.
static func opaque_rect(tex: Texture2D) -> Rect2i:
	var img: Image = tex.get_image()
	if img == null:
		return Rect2i(Vector2i.ZERO, Vector2i(tex.get_width(), tex.get_height()))
	if img.is_compressed():
		img.decompress()
	var r: Rect2i = img.get_used_rect()
	if r.size == Vector2i.ZERO:
		return Rect2i(Vector2i.ZERO, img.get_size())
	return r

## Nombre de dirección (8) para un vector (y hacia abajo = sur).
static func dir_name(v: Vector2) -> String:
	var i: int = posmod(int(round(v.angle() / (PI / 4.0))), 8)
	return DIRS[i]

## Espejo horizontal de una dirección (east <-> west, etc.).
static func mirror_of(d: String) -> String:
	if d.contains("east"):
		return d.replace("east", "west")
	if d.contains("west"):
		return d.replace("west", "east")
	return d
