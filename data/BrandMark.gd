extends RefCounted
class_name BrandMark

## Logo de marca FICTICIA por capas (patrocinadores + noticieros
## deportivos), estilo "app icon": fondo de color + glifo blanco.
## Determinista por nombre de marca. Mismo lenguaje pixel que
## Crest/Competition/Kit/Trophy.

const _DIR := "res://assets/brands/"

const SHAPES := ["circle", "rounded", "square", "hex"]
const GLYPHS := ["bolt", "wave", "ring", "star", "arrow", "peak", "drop", "orbit", "blocks", "cross"]

## Paletas (fondo, glifo) — el glifo casi siempre blanco, a veces el
## secundario para marcas de dos tonos.
const PALETTES := [
	["#e23b3b", "#ffffff"], ["#1f6fd6", "#ffffff"], ["#12a150", "#ffffff"],
	["#7b46d6", "#ffffff"], ["#f0a000", "#1a1a1a"], ["#0fb5c9", "#ffffff"],
	["#e8508a", "#ffffff"], ["#2a2a2a", "#f0c020"], ["#26355f", "#ffffff"],
	["#d95a2b", "#ffffff"],
]

static var _cache: Dictionary = {}

static func _tex(file: String) -> Texture2D:
	if _cache.has(file):
		return _cache[file]
	var p := _DIR + file
	var t: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
	_cache[file] = t
	return t

static func config_for(brand_name: String) -> Dictionary:
	var h: int = absi(hash("brand:" + brand_name))
	return {
		"shape": h % SHAPES.size(),
		"glyph": (h / 5) % GLYPHS.size(),
		"palette": (h / 41) % PALETTES.size(),
	}

## "Ándico Café" → "andico_cafe" (nombre de archivo del logo).
static func slug(brand_name: String) -> String:
	var t: String = brand_name.to_lower()
	for pair in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ñ", "n"]]:
		t = t.replace(pair[0], pair[1])
	return t.replace(" ", "_")

## Nodo `px`×`px` con el logo de la marca `brand_name`.
static func build(brand_name: String, px: int) -> Control:
	# Logo pixel de PixelLab si la marca lo tiene (9-oct, P1b: patrocinadores
	# con logo propio); si no, el genérico por capas de siempre.
	var art: String = "res://assets/sponsors/%s.png" % slug(brand_name)
	if ResourceLoader.exists(art):
		var r := TextureRect.new()
		r.texture = load(art)
		r.custom_minimum_size = Vector2(px, px)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return r
	var cfg := config_for(brand_name)
	var pal: Array = PALETTES[int(cfg["palette"]) % PALETTES.size()]
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, "bg_" + SHAPES[int(cfg["shape"]) % SHAPES.size()], Color(pal[0]))
	_add(root, "gl_" + GLYPHS[int(cfg["glyph"]) % GLYPHS.size()], Color(pal[1]))
	return root

## Fila logo + nombre (para tarjetas de patrocinio / fuente de prensa).
static func row(brand_name: String, px: int, name_color: Color = Color.WHITE) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var logo := build(brand_name, px)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(logo)
	var lbl := Label.new()
	lbl.text = brand_name
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.add_theme_color_override("font_color", name_color)
	hb.add_child(lbl)
	return hb

static func _add(root: Control, file: String, tint: Color) -> void:
	var path := _DIR + file + ".png"
	if not ResourceLoader.exists(path):
		return
	var r := TextureRect.new()
	r.texture = _tex(file + ".png")
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = tint
	root.add_child(r)
