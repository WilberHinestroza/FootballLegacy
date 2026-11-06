extends RefCounted
class_name Medals

## Medallas (Kenney medals pack, assets/medals/PNG/). Se usan para el
## podio del top 3 (oro / plata / bronce) en Premios anuales y para la
## tarjeta de nota de la ceremonia de fin de temporada.

const _DIR := "res://assets/medals/PNG/"
const _BY_RANK := {1: "flat_medal1", 2: "flat_medal2", 3: "flat_medal3"}
## por color, para usos que no son ranking (p. ej. nota de temporada)
const GOLD := "flat_medal1"
const SILVER := "flat_medal2"
const BRONZE := "flat_medal3"

static var _cache: Dictionary = {}

static func _tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path: String = _DIR + name + ".png"
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_cache[name] = tex
	return tex

## Medalla del puesto (1-3), o null.
static func for_rank(rank: int) -> Texture2D:
	if not _BY_RANK.has(rank):
		return null
	return _tex(_BY_RANK[rank])

static func by_name(name: String) -> Texture2D:
	return _tex(name)

## TextureRect de una medalla a `px` de lado. null si no existe.
static func rect(tex: Texture2D, px: int) -> TextureRect:
	if tex == null:
		return null
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
