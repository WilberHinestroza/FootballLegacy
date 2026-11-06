extends RefCounted
class_name BallDesign

## Balón como sprite TERMINADO (assets/balls/ball_<id>.png) — arte propio
## por diseño, ya no modular/teñido (no ligado a color de club, así que no
## hace falta). `id` = índice en DESIGNS.

const _DIR := "res://assets/balls/"

## 9-oct: los 16 balones de PixelLab de Wilber (sección Objetos de su
## cuenta, art_src/pixellab/objects_wilber/081-096) reemplazan al catálogo
## anterior ("me gustan más"). El viejo quedó en art_src/legacy_kenney/
## balls_old. Un índice guardado más alto que el catálogo se acota solo
## (PreMatch clampi / build clampi).
const DESIGNS := [
	{"id": "w_clasico", "name": "Clásico"},
	{"id": "w_estrella", "name": "Estrella"},
	{"id": "w_fluor", "name": "Flúor"},
	{"id": "w_naranja", "name": "Invierno Naranja"},
	{"id": "w_cuero", "name": "Cuero Retro"},
	{"id": "w_dorado", "name": "Dorado"},
	{"id": "w_tricolor", "name": "Tricolor"},
	{"id": "w_rojiblanco", "name": "Rojiblanco"},
	{"id": "w_remolino", "name": "Remolino"},
	{"id": "w_circuito", "name": "Circuito"},
	{"id": "w_luna", "name": "Luna"},
	{"id": "w_llamas", "name": "Llamas"},
	{"id": "w_acero", "name": "Acero"},
	{"id": "w_camuflaje", "name": "Camuflaje"},
	{"id": "w_rombos", "name": "Rombos"},
	{"id": "w_carbon", "name": "Carbón"},
]

static var _cache: Dictionary = {}
static func _tex(file: String) -> Texture2D:
	if _cache.has(file):
		return _cache[file]
	var p := _DIR + file
	var t: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
	_cache[file] = t
	return t

static func count() -> int:
	return DESIGNS.size()

static func name_of(idx: int) -> String:
	return String(DESIGNS[clampi(idx, 0, DESIGNS.size() - 1)]["name"])

## Balón determinista de un partido si el usuario no eligió uno.
static func default_for(seed_key: String) -> int:
	return absi(hash("ball:" + seed_key)) % DESIGNS.size()

## Textura suelta del balón (para dibujarlo a mano, p. ej. en la cancha 2D).
static func texture(idx: int) -> Texture2D:
	var d: Dictionary = DESIGNS[clampi(idx, 0, DESIGNS.size() - 1)]
	return _tex("ball_%s.png" % String(d["id"]))

static func build(idx: int, px: int) -> Control:
	var d: Dictionary = DESIGNS[clampi(idx, 0, DESIGNS.size() - 1)]
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, "ball_%s.png" % String(d["id"]), Color.WHITE)
	return root

static func _add(root: Control, file: String, tint: Color) -> void:
	if not ResourceLoader.exists(_DIR + file):
		return
	var r := TextureRect.new()
	r.texture = _tex(file)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = tint
	root.add_child(r)
