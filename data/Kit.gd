extends RefCounted
class_name Kit

## Camiseta modular procedural por CAPAS (mismo patrón que Crest/Competition):
## PNGs blancos 64×64 en assets/kits/ que se apilan y se tiñen con
## `modulate`. Retro pixel-art (TEXTURE_FILTER_NEAREST). Determinista por
## club: no se pre-genera, cada club arma la suya desde su club_id + sus
## colores.
##
## Capas: body_<b> (silueta, primario) → pat_<p> (patrón recortado al
## torso, secundario) → acc_sleeves (mangas de contraste, opcional) →
## collar_<c> (cuello, secundario claro) → outline_<b> (borde oscuro).

const _DIR := "res://assets/kits/"

## Un solo cuerpo (arte nuevo de Wilber, sept-2026): las otras 4 siluetas
## viejas (vneck/polo/long/raglan) quedaron descartadas a propósito — mezclar
## el body nuevo con las viejas daba un look inconsistente ("las camisas
## viejas" que seguían saliendo). Si en el futuro llega arte nuevo para
## v-cuello/polo/manga larga/raglán, se agregan acá.
const BODIES := ["classic"]
## Siluetas de PixelLab (9-oct, pedido de Wilber: "camisetas con bastantes
## diseños y estilos para que los equipos sientan identidad propia"):
## cuello redondo, V, polo, manga larga, raglán — llegó el "arte nuevo" que
## pedía el comentario de arriba. Cada una en 3 capas (tools/kit_assets.py):
## body_px_* (relleno teñible), shade_px_* (pliegues encima del patrón),
## outline_px_* (contorno).
const PX_BODIES := ["px_crew", "px_vneck", "px_polo", "px_long", "px_raglan"]
const ALL_BODIES := ["classic", "px_crew", "px_vneck", "px_polo", "px_long", "px_raglan"]
## PNG (assets/kits/pat_*), todos del mismo lote de arte nuevo. Los 6
## patrones procedurales (`proc_*`) de la era anterior se sacaron a
## propósito por el mismo motivo — solo diseño nuevo, elegido al azar por
## el hash de config_for()/for_club_kit().
const PATTERNS := [
	"solid", "stripes", "hoops", "halves", "sash", "chevron", "placket",
	"pinstripe", "checker", "yoke", "raglan_shoulder", "chest_band",
	"argyle", "gradient", "geo_shards", "cross", "triple_stripe", "polka_dots",
	"diag_wide", "zigzag", "half_top", "half_bottom", "shoulder_yoke2",
	"camo", "vgradient", "wavy", "hpinstripe", "stripe_offcenter", "diag_shoulder",
]
const _SHORT_SLEEVE := {"classic": true, "vneck": true, "polo": true, "long": false, "raglan": true}
# Un solo cuello (rib de cuello redondo): sirve para cualquier escote y se
# lee limpio a 40-64px. La variedad de escote la da el recorte del `body`.
const _OUTLINE := {"classic": "outline_classic_v2", "vneck": "outline_classic", "polo": "outline_classic", "long": "outline_long", "raglan": "outline_raglan"}

## Camisetas de PixelLab de WILBER (9-oct, tools/kit_templates.py →
## assets/kits/w/NNN + máscara, data/KitTemplates.gd): ~7 de cada 10
## equipaciones usan uno de sus 32 diseños, recoloreado con los colores del
## club. `w` = índice en KitTemplates.LIST, -1 = corte+patrón procedural.
const W_SHARE := 7   # de 10

static func config_for(seed_key: String) -> Dictionary:
	var h: int = absi(hash("kit:" + seed_key))
	var hw: int = absi(hash("kitw:" + seed_key))
	return {
		"body": h % ALL_BODIES.size(),
		"pattern": int(h / 7) % PATTERNS.size(),
		"sleeve_accent": (int(h / 53) % 3) == 0,
		"w": (hw / 11) % KitTemplates.LIST.size() if hw % 10 < W_SHARE else -1,
	}

static func for_club(club: ClubData) -> Dictionary:
	if club == null:
		return config_for("none")
	return config_for(club.club_id)

## Config de la equipación de un club para una temporada dada. `away` usa
## otra semilla (diseño distinto) y más variedad. `season_year` entra en
## la semilla → el diseño rota cada temporada ("para darle juego").
static func for_club_kit(club: ClubData, season_year: int, away: bool) -> Dictionary:
	var id: String = club.club_id if club != null else "none"
	var slot: String = "away" if away else "home"
	var cfg := config_for("%s|%d|%s" % [id, season_year, slot])
	if away:
		# Mismo CORTE que la local de esa temporada (Wilber, 9-oct: "local y
		# visitante no deberían tener diseños de camisa diferentes, lo que
		# cambia es el patrón") — la camiseta de un club en una temporada es
		# UNA silueta del proveedor; local y visitante se distinguen por el
		# patrón (y los colores). El patrón nunca repite el de la local.
		var home_cfg := config_for("%s|%d|home" % [id, season_year])
		cfg["body"] = int(home_cfg["body"])
		# Plantillas de Wilber: si la local es una, la visitante es OTRA de
		# sus diseños (todas comparten silueta = mismo corte); si la local es
		# procedural, la visitante también (mismo corte, otro patrón).
		var hw: int = int(home_cfg.get("w", -1))
		if hw >= 0:
			var n: int = KitTemplates.LIST.size()
			cfg["w"] = (hw + 1 + absi(hash("kitw2:%s|%d" % [id, season_year])) % (n - 1)) % n
		else:
			cfg["w"] = -1
		var h2: int = absi(hash("kit2:%s|%d" % [id, season_year]))
		var home_pat: int = int(home_cfg["pattern"]) % PATTERNS.size()
		cfg["pattern"] = (home_pat + 1 + h2 % (PATTERNS.size() - 1)) % PATTERNS.size()
		cfg["sleeve_accent"] = (h2 / 11) % 2 == 0
	return cfg

## `number` > 0 dibuja el dorsal centrado en la camiseta.
static func build(primary: Color, secondary: Color, cfg: Dictionary, px: int, number: int = 0) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if int(cfg.get("w", -1)) >= 0:
		root.add_child(_w_rect(int(cfg["w"]), primary, secondary))
		if number > 0:
			root.add_child(_number_label(primary, px, number))
		return root
	var body: String = ALL_BODIES[int(cfg.get("body", 0)) % ALL_BODIES.size()]
	var px_body: bool = body.begins_with("px_")
	var pattern: String = PATTERNS[int(cfg.get("pattern", 0)) % PATTERNS.size()]
	var collar_tint: Color = secondary.lightened(0.35) if secondary.get_luminance() < 0.6 else secondary.darkened(0.3)

	# El cuerpo hace de máscara: el patrón (PNG o procedural) se recorta a
	# la silueta vía clip_children, así los patrones dibujados en runtime no
	# se salen de la camiseta.
	var body_layer := _mk("body_" + body, primary)
	if body_layer != null:
		body_layer.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		root.add_child(body_layer)
		if pattern.begins_with("proc_"):
			var pt := _proc_pattern_tex(pattern)
			if pt != null:
				body_layer.add_child(_mk_tex(pt, secondary))
		elif pattern != "solid":
			var pl := _mk("pat_" + pattern, secondary)
			if pl != null:
				body_layer.add_child(pl)
	if px_body:
		# Pliegues de la tela ENCIMA del patrón (si no, las rayas tapaban
		# todo el volumen de la silueta).
		_add(root, "shade_" + body, Color.WHITE)
	elif bool(cfg.get("sleeve_accent", false)) and bool(_SHORT_SLEEVE[body]):
		_add(root, "acc_sleeves", secondary)
	if not px_body:
		_add(root, "collar_crew", collar_tint)
	# Contorno claro sobre camiseta oscura, oscuro sobre clara -- si no,
	# un club con primario casi negro se comía su propio contorno y la
	# camiseta quedaba plana (mismo bug que reportó Wilber en escudos).
	var outline_col: Color = Color(0.92, 0.93, 0.96) if primary.get_luminance() < 0.35 else Color(0.10, 0.11, 0.14)
	_add(root, "outline_" + body if px_body else String(_OUTLINE[body]), outline_col)

	if number > 0:
		root.add_child(_number_label(primary, px, number))
	return root

## Dorsal sugerido y ESTABLE para un jugador según su posición amplia.
static func suggested_number(broad_position: String, seed_key: String) -> int:
	var h: int = absi(hash("kitnum:" + seed_key))
	match broad_position:
		"GK":
			return [1, 12, 25][h % 3]
		"DF":
			return [2, 3, 4, 5, 6, 13, 14, 15, 23][h % 9]
		"MF":
			return [5, 6, 8, 10, 16, 17, 18, 20, 21][h % 9]
		_:
			return [7, 9, 11, 17, 19, 22, 24, 27][h % 8]


## Dorsal centrado (contorno fuerte del tono contrario).
static func _number_label(primary: Color, px: int, number: int) -> Label:
	var num_col: Color = Color(0.97, 0.97, 1.0) if primary.get_luminance() < 0.55 else Color(0.10, 0.11, 0.14)
	var n := Label.new()
	n.text = str(number)
	n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	n.offset_top = px * 0.10
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_theme_font_override("font", Styles.font_black())
	n.add_theme_font_size_override("font_size", maxi(9, int(px * 0.34)))
	n.add_theme_color_override("font_color", num_col)
	# Contorno fuerte en el tono contrario: con patrones claros sobre
	# primario oscuro (o al revés) el dorsal se perdía en el diseño.
	var num_outline: Color = Color(0.05, 0.05, 0.08, 0.9) if num_col.get_luminance() > 0.5 else Color(1, 1, 1, 0.85)
	n.add_theme_color_override("font_outline_color", num_outline)
	n.add_theme_constant_override("outline_size", maxi(2, int(px * 0.06)))
	return n

## Plantilla de Wilber teñida (caché por diseño + colores).
static var _w_cache: Dictionary = {}
static func w_texture(w: int, primary: Color, secondary: Color) -> Texture2D:
	var num: String = String(KitTemplates.LIST[w % KitTemplates.LIST.size()][0])
	var key: String = "%s|%s|%s" % [num, primary.to_html(false), secondary.to_html(false)]
	if _w_cache.has(key):
		return _w_cache[key]
	var col: Image = _img("res://assets/kits/w/%s.png" % num)
	var msk: Image = _img("res://assets/kits/w/%s_m.png" % num)
	if col == null or msk == null:
		return null
	var out := Image.create(col.get_width(), col.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(col.get_height()):
		for x in range(col.get_width()):
			var c: Color = col.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var m: Color = msk.get_pixel(x, y)
			var cls: int = int(round(m.r * 255.0))
			if cls == 1:
				c = Avatar._tinted(primary, m.g)
			elif cls == 2:
				c = Avatar._tinted(secondary, m.g)
			out.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(out)
	if _w_cache.size() > 300:
		_w_cache.clear()
	_w_cache[key] = tex
	return tex

## Máscara de clases de una plantilla (para estampar el diseño en el
## jugador: Avatar usa esto en el torso).
static func w_mask(w: int) -> Image:
	return _img("res://assets/kits/w/%s_m.png" % String(KitTemplates.LIST[w % KitTemplates.LIST.size()][0]))

static func _img(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var t := load(path) as Texture2D
	var img: Image = t.get_image() if t != null else null
	if img != null:
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
	return img

static func _w_rect(w: int, primary: Color, secondary: Color) -> TextureRect:
	var r := TextureRect.new()
	r.texture = w_texture(w, primary, secondary)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func _club_colors(club: ClubData) -> Array:
	var prim: Color = Color("#2b6fb0")
	var sec: Color = Color.TRANSPARENT
	if club != null:
		if not club.primary_color_hex.is_empty():
			prim = Color(club.primary_color_hex)
		if not club.secondary_color_hex.is_empty():
			sec = Color(club.secondary_color_hex)
	if sec.a < 0.05 or absf(sec.get_luminance() - prim.get_luminance()) < 0.22:
		sec = prim.darkened(0.42) if prim.get_luminance() > 0.5 else prim.lightened(0.5)
	return [prim, sec]

## Camiseta lista de un club (equipación TITULAR de la temporada actual).
static func build_for_club(club: ClubData, px: int) -> Control:
	var c := _club_colors(club)
	return build(c[0], c[1], for_club(club), px)

## Equipación de un club para una temporada (home o away). La visitante
## invierte primario/secundario; si el secundario quedó muy parecido al
## primario, tira de un tono neutro (blanco/negro) para que contraste.
static func build_for_club_kit(club: ClubData, season_year: int, away: bool, px: int, number: int = 0) -> Control:
	var c := _club_colors(club)
	var prim: Color = c[0]
	var sec: Color = c[1]
	if away:
		var body: Color = sec
		var trim: Color = prim
		if body.is_equal_approx(prim) or absf(body.get_luminance() - prim.get_luminance()) < 0.12:
			body = Color.WHITE if prim.get_luminance() < 0.5 else Color("#1a1a1a")
		return build(body, trim, for_club_kit(club, season_year, true), px, number)
	return build(prim, sec, for_club_kit(club, season_year, false), px, number)

static func _add(root: Control, file: String, tint: Color) -> void:
	var r := _mk(file, tint)
	if r != null:
		root.add_child(r)

## TextureRect de un PNG de assets/kits/ (o null si no existe), sin añadirlo.
static func _mk(file: String, tint: Color) -> TextureRect:
	var path := _DIR + file + ".png"
	if not ResourceLoader.exists(path):
		return null
	return _mk_tex(load(path), tint)

static func _mk_tex(tex: Texture2D, tint: Color) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# self_modulate (NO modulate): el cuerpo es el padre del patrón (lo
	# recorta con clip_children) y `modulate` se HEREDA — el patrón salía
	# además multiplicado por el color principal (rayas turbias). Mismo bug
	# que tenían los escudos, encontrado en captura real (9-oct).
	r.self_modulate = tint
	return r

## --- Patrones PROCEDURALES (dibujados una vez, cacheados) --------------
## Lienzo 64×64 RGBA blanco+alpha; se tiñe luego con `modulate`. El recorte
## a la camiseta lo hace el clip_children del cuerpo (ver build()).
const _PROC_PX := 64
static var _proc_cache: Dictionary = {}

static func _proc_pattern_tex(name: String) -> Texture2D:
	if _proc_cache.has(name):
		return _proc_cache[name]
	var img := Image.create(_PROC_PX, _PROC_PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var w := _PROC_PX
	match name:
		"proc_pinstripe":
			for x in range(w):
				if x % 6 == 0:
					for y in range(w):
						img.set_pixel(x, y, Color(1, 1, 1, 0.9))
		"proc_thin_hoops":
			for y in range(w):
				if (y % 8) < 2:
					for x in range(w):
						img.set_pixel(x, y, Color(1, 1, 1, 0.9))
		"proc_shoulders":
			for y in range(w):
				for x in range(w):
					if y < 16 and (x < 10 or x >= w - 10 or y < 6):
						img.set_pixel(x, y, Color(1, 1, 1, 0.92))
		"proc_band":
			for y in range(w):
				if y >= 26 and y < 38:
					for x in range(w):
						img.set_pixel(x, y, Color(1, 1, 1, 0.92))
		"proc_checker":
			for y in range(w):
				for x in range(w):
					if ((int(x / 8.0)) + (int(y / 8.0))) % 2 == 0:
						img.set_pixel(x, y, Color(1, 1, 1, 0.55))
		"proc_grandad":
			# placket vertical central + cuello alto
			for y in range(w):
				for x in range(w):
					if y < 8 or (x >= w / 2 - 3 and x < w / 2 + 3 and y < 30):
						img.set_pixel(x, y, Color(1, 1, 1, 0.9))
	var tex := ImageTexture.create_from_image(img)
	_proc_cache[name] = tex
	return tex

## ¿Dos colores de camiseta se confunden en la cancha? (10-oct, captura
## real: los dos equipos de verde, uno más oscuro — la regla vieja solo
## miraba la luminancia y los dejaba pasar). Chocan si están cerca en RGB o
## si comparten tono con saturación (verde oscuro vs verde claro).
## ¿El escudo va al centro del pecho? Uno de cada cinco clubes por temporada
## (estable: mismo club y año, misma camiseta). El 3D además lo centra siempre en
## el polo retro. Lo leen Match3DBridge (partido) y Avatar3D.stamp_kit (retratos).
static func crest_centered(club_id: String, season_year: int) -> bool:
	return club_id != "" and absi(hash("crestc:%s|%d" % [club_id, season_year])) % 5 == 0

static func colors_clash(a: Color, b: Color) -> bool:
	var d: float = sqrt(pow(a.r - b.r, 2.0) + pow(a.g - b.g, 2.0) + pow(a.b - b.b, 2.0))
	if d < 0.42:
		return true
	var hd: float = absf(a.h - b.h)
	hd = minf(hd, 1.0 - hd)
	return a.s > 0.25 and b.s > 0.25 and hd < 0.09 and absf(a.v - b.v) < 0.55

## Color con el que sale el RIVAL cuando su camiseta choca con la tuya: su
## secundario si se distingue, si no blanco o casi negro (el más lejano).
static func alt_color_against(rival_club: ClubData, us: Color) -> Color:
	if rival_club != null and not rival_club.secondary_color_hex.is_empty():
		var sec := Color(rival_club.secondary_color_hex)
		if not colors_clash(sec, us):
			return sec
	var white := Color(0.95, 0.95, 0.95)
	var dark := Color(0.12, 0.12, 0.14)
	if colors_clash(white, us):
		return dark
	if colors_clash(dark, us):
		return white
	return white if us.get_luminance() < 0.5 else dark
