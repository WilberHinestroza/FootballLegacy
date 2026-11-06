extends RefCounted
class_name TraitBadge

## Insignia PROCEDURAL de un rasgo de jugador — mismo lenguaje que Crest /
## Competition / Trophy: se dibuja en runtime con Image (pixel-art, NEAREST),
## se cachea y no se persiste. Nada de SVGs sueltos.
##
## Estructura: rombo/escudo del COLOR DE LA CATEGORÍA del rasgo (finalización
## rojo, creación azul, defensa verde, balón parado dorado, físico naranja,
## portero turquesa, aura violeta) + aro claro + glifo blanco + brillo.

const _PX := 40

## Color por "familia" del efecto del rasgo (se deriva de qué buckets toca).
const _CAT_COLOR := {
	"finish": Color("#c0392b"),
	"playmk": Color("#2e6fb0"),
	"defense": Color("#2a9a55"),
	"setpiece": Color("#e0b422"),
	"fatigue": Color("#d3792a"),
	"keeper": Color("#1f8f8f"),
	"aura": Color("#8a63c8"),
}

## Glifo por rasgo. Los que no estén acá caen a "star".
const _GLYPH := {
	"killer_instinct": "target", "penalty_king": "flame", "engine": "gear",
	"rock": "bricks", "dead_ball": "star", "talisman": "spark",
	"poacher": "target", "aerial_threat": "chevron", "playmaker": "brain",
	"ball_winner": "magnet", "sweeper": "arc", "keeper_wall": "glove",
	"goal_machine": "boot", "speedster": "bolt", "iron_man": "gear",
	"free_kick_master": "star", "pressing_monster": "magnet", "last_man": "bricks",
	"mentor": "spark", "big_game_player": "flame", "fan_idol": "target",
	"cat_reflexes": "glove",
}

static var _cache: Dictionary = {}

## Categoría de color a partir de la config del rasgo en Traits.CATALOG.
static func _category(cfg: Dictionary) -> String:
	if cfg.has("concede_factor"):
		return "keeper"
	if cfg.has("rep_factor"):
		return "aura"
	if cfg.has("fatigue_factor"):
		return "fatigue"
	var buckets := {"finish": 0.0, "playmk": 0.0, "defense": 0.0, "setpiece": 0.0}
	buckets["finish"] = float(cfg.get("finish", 0.0))
	buckets["playmk"] = float(cfg.get("playmk", 0.0))
	buckets["defense"] = float(cfg.get("defense", 0.0))
	buckets["setpiece"] = float(cfg.get("set_piece", 0.0)) + float(cfg.get("penalty", 0.0))
	# Si toca 3+ buckets es un rasgo "aura" (talismán / mentor).
	var nonzero := 0
	for k in buckets:
		if buckets[k] > 0.0:
			nonzero += 1
	if nonzero >= 3:
		return "aura"
	var best := "finish"
	var bv := -1.0
	for k in buckets:
		if buckets[k] > bv:
			bv = buckets[k]
			best = k
	return best

static func _tex(trait_id: String) -> Texture2D:
	if _cache.has(trait_id):
		return _cache[trait_id]
	var cfg: Dictionary = Traits.CATALOG.get(trait_id, {})
	var base: Color = _CAT_COLOR.get(_category(cfg), Color("#666"))
	var glyph: String = String(_GLYPH.get(trait_id, "star"))
	var img := Image.create(_PX, _PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := _PX / 2.0
	var outline: Color = base.darkened(0.45)
	var fill_hi: Color = base.lightened(0.12)
	# --- rombo con esquinas suaves ---
	for y in range(_PX):
		for x in range(_PX):
			var dx: float = abs(x + 0.5 - c)
			var dy: float = abs(y + 0.5 - c)
			var diamond: float = (dx + dy) / (_PX * 0.5)          # 1.0 en el borde
			var box: float = max(dx, dy) / (_PX * 0.5)
			var m: float = lerpf(diamond, box, 0.35)              # rombo con panza
			if m <= 0.94:
				img.set_pixel(x, y, fill_hi if (y + x) < _PX * 0.85 else base)
			elif m <= 1.04:
				img.set_pixel(x, y, outline)
	# aro interior claro
	_stroke_diamond(img, c, _PX * 0.34, base.lightened(0.4), 0.10)
	# glifo
	_draw_glyph(img, glyph, c, Color(1, 1, 1, 0.96))
	# brillo diagonal arriba-izquierda
	for y in range(_PX):
		for x in range(_PX):
			if img.get_pixel(x, y).a > 0.1 and (x + y) < _PX * 0.6 and ((x * 3 + y) % 7 == 0):
				var p := img.get_pixel(x, y)
				img.set_pixel(x, y, p.lightened(0.28))
	var tex := ImageTexture.create_from_image(img)
	_cache[trait_id] = tex
	return tex

static func _stroke_diamond(img: Image, c: float, r: float, col: Color, w: float) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var d: float = (abs(x + 0.5 - c) + abs(y + 0.5 - c)) / r
			if d >= 1.0 - w and d <= 1.0 + w:
				var p := img.get_pixel(x, y)
				if p.a > 0.1:
					img.set_pixel(x, y, col)

static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)

static func _draw_glyph(img: Image, glyph: String, c: float, col: Color) -> void:
	var ci: int = int(c)
	match glyph:
		"target":
			_ring(img, c, 8.5, col); _ring(img, c, 4.5, col); _disc(img, c, 1.6, col)
		"flame":
			for y in range(-9, 8):
				var half: float = 5.0 * (1.0 - abs(float(y) + 1.0) / 10.0)
				if y < -3:
					half *= 0.5
				for x in range(-int(half), int(half) + 1):
					_px(img, ci + x, ci + y, col if y > -2 else col.darkened(0.15))
		"gear":
			_ring(img, c, 7.0, col); _disc(img, c, 2.2, col)
			for a in range(0, 360, 45):
				var rr := deg_to_rad(a)
				_disc_at(img, c + cos(rr) * 8.5, c + sin(rr) * 8.5, 1.8, col)
		"bricks":
			for y in range(-8, 9, 5):
				for x in range(-9, 10):
					_px(img, ci + x, ci + y, col)
			for y in range(-8, 9):
				var off := 0 if ((y + 8) / 5) % 2 == 0 else 5
				_px(img, ci - 9 + off, ci + y, col)
				_px(img, ci - 4 + off, ci + y, col)
				_px(img, ci + 6 - off + 4, ci + y, col)
		"bolt":
			var pts := [Vector2(2, -10), Vector2(-4, 1), Vector2(1, 1), Vector2(-2, 10), Vector2(6, -2), Vector2(1, -2)]
			_poly_fill(img, c, pts, col)
		"chevron":  # galones apuntando ARRIBA (juego aéreo)
			for k in range(0, 3):
				for x in range(-8, 9):
					_px(img, ci + x, ci - 3 - k * 5 + int(abs(x) * 0.7), col)
					_px(img, ci + x, ci - 2 - k * 5 + int(abs(x) * 0.7), col)
		"brain":
			_disc(img, c, 7.5, col)
			for i in range(-6, 7, 3):
				for y in range(-6, 7):
					_px(img, ci + i, ci + y, col.darkened(0.5))
		"magnet":
			for y in range(-8, 5):
				_px(img, ci - 6, ci + y, col); _px(img, ci - 5, ci + y, col)
				_px(img, ci + 5, ci + y, col); _px(img, ci + 6, ci + y, col)
			for x in range(-6, 7):
				_px(img, ci + x, ci + 4, col); _px(img, ci + x, ci + 5, col)
			for y in range(5, 9):
				_px(img, ci - 6, ci + y, col.darkened(0.3)); _px(img, ci - 5, ci + y, col.darkened(0.3))
				_px(img, ci + 5, ci + y, col.darkened(0.3)); _px(img, ci + 6, ci + y, col.darkened(0.3))
		"arc":
			for a in range(200, 341, 4):
				var rr := deg_to_rad(a)
				_disc_at(img, c + cos(rr) * 8.0, c + sin(rr) * 8.0, 1.6, col)
			_disc_at(img, c + cos(deg_to_rad(200)) * 8.0, c + sin(deg_to_rad(200)) * 8.0, 2.4, col)
		"glove":
			for y in range(-4, 9):
				for x in range(-6, 5):
					_px(img, ci + x, ci + y, col)
			for x in range(-6, 5, 3):
				for y in range(-9, -3):
					_px(img, ci + x, ci + y, col); _px(img, ci + x + 1, ci + y, col)
			for y in range(-3, 4):
				_px(img, ci + 5, ci + y, col); _px(img, ci + 6, ci + y, col)
		"boot":
			for y in range(-7, 2):
				for x in range(-3, 4):
					_px(img, ci + x, ci + y, col)
			for x in range(-3, 9):
				for y in range(2, 7):
					_px(img, ci + x, ci + y, col)
			for x in range(-4, 10):
				_px(img, ci + x, ci + 7, col.darkened(0.3))
		_: # star
			_star(img, c, 9.0, col)

static func _ring(img: Image, c: float, r: float, col: Color) -> void:
	for a in range(0, 360, 3):
		var rr := deg_to_rad(a)
		_disc_at(img, c + cos(rr) * r, c + sin(rr) * r, 1.4, col)

static func _disc(img: Image, c: float, r: float, col: Color) -> void:
	_disc_at(img, c, c, r, col)

static func _disc_at(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var ri := int(ceil(r))
	for y in range(-ri, ri + 1):
		for x in range(-ri, ri + 1):
			if x * x + y * y <= r * r:
				_px(img, int(cx) + x, int(cy) + y, col)

static func _star(img: Image, c: float, r: float, col: Color) -> void:
	var pts: Array = []
	for i in range(10):
		var ang := deg_to_rad(-90 + i * 36)
		var rad := r if i % 2 == 0 else r * 0.42
		pts.append(Vector2(cos(ang) * rad, sin(ang) * rad))
	_poly_fill(img, c, pts, col)

static func _poly_fill(img: Image, c: float, pts: Array, col: Color) -> void:
	var minx := 999; var maxx := -999; var miny := 999; var maxy := -999
	for p in pts:
		minx = mini(minx, int(p.x)); maxx = maxi(maxx, int(p.x))
		miny = mini(miny, int(p.y)); maxy = maxi(maxy, int(p.y))
	for y in range(miny, maxy + 1):
		for x in range(minx, maxx + 1):
			if _in_poly(Vector2(x, y), pts):
				_px(img, int(c) + x, int(c) + y, col)

static func _in_poly(pt: Vector2, poly: Array) -> bool:
	var inside := false
	var j := poly.size() - 1
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[j]
		if ((a.y > pt.y) != (b.y > pt.y)) and (pt.x < (b.x - a.x) * (pt.y - a.y) / (b.y - a.y + 0.0001) + a.x):
			inside = not inside
		j = i
	return inside

## Control cuadrado de `px`×`px` con la insignia. `dim` = escala de gris
## (para rasgos bloqueados).
static func build(trait_id: String, px: int, dim: bool = false) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := TextureRect.new()
	# Medalla pixel de PixelLab si existe (P6, 10-oct); si no, la procedural.
	var medal: String = "res://assets/medals/%s.png" % trait_id
	r.texture = load(medal) if ResourceLoader.exists(medal) else _tex(trait_id)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		r.modulate = Color(0.5, 0.5, 0.55, 0.65)
	root.add_child(r)
	return root
