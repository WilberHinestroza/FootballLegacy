extends RefCounted
class_name Crest

## Escudos de club MODULARES por capas, estilo pixel-art (mismo lenguaje
## que el Kenney pixel-ui).
##
## Siluetas + trim + brillo salen de PNGs blancos en assets/crests/ que se
## tiñen con `modulate`. Los PATRONES y EMBLEMAS son casi todos
## PROCEDURALES (se dibujan a un Image en runtime, cacheados): así hay
## muchísima variedad sin pedir más arte, y cada emblema trae su propio
## contorno oscuro "horneado" para que SIEMPRE se lea sobre cualquier
## color de fondo (antes se perdían los oscuros sobre escudo oscuro).
##
## Todo determinista por club: `config_for(club_id)` — nunca se guarda.

const _DIR := "res://assets/crests/"

## Silueta del escudo. Las 5 primeras son PNG (assets/crests/sh_*), el
## resto (`pr_*`) se dibujan a un Image en runtime — formas de escudos
## reales: española (base semicircular), francesa (base cóncava en punta),
## italiana, "scudetto" (gota), óvalo (Boca/River), banderín, hexágono
## (Juve), demi-círculo ("D"), "cometa" sudamericana, "crested" (remate
## almenado arriba) y "eared" (orejas redondeadas arriba) — estas dos
## últimas inspiradas en la guía de Wilber (sept-2026, "Forma 13/16
## Crested"), pero dibujadas por código en vez de con arte externo: probó
## el lote de PNGs (Gemini + Photoroom) dos veces y no le convenció el
## estilo, pidió volver a 100% procedural.
const SHAPES := [
	"classic", "round", "heater", "banner", "rounded",
	"pr_spanish", "pr_french", "pr_italian", "pr_scudetto",
	"pr_oval", "pr_pennant", "pr_hex", "pr_demi", "pr_kite",
	"pr_crested", "pr_eared",
]

## Patrones del campo del escudo. Casi todos procedurales ("pr_"): el
## color secundario del club los pinta. Recortado (sept-2026, pedido de
## Wilber: "que sigan una línea como los reales de hoy en día") — afuera
## los patrones más "heráldicos de manual" que casi no se ven en un
## escudo de club de verdad (gyronny, saltire, rombos tipo arlequín,
## rayos, cuarteles anillados, barras diagonales finas): quedan los que sí
## aparecen en escudos reales (mitades, banda, aros, franjas, bandas
## sup/inf, cruz simple).
const PATTERNS := [
	"none", "none",
	"pr_stripes", "pr_stripes_wide", "pr_hoops", "pr_hoops_thick",
	"pr_sash", "pr_sash_double", "pr_bend", "pr_chevron",
	"pr_pale", "pr_fess", "pr_cross", "pr_quarters",
	"pr_chief", "pr_base", "pr_pile", "pr_checker",
	"pr_halves", "pr_halves_diag", "pr_border", "pr_pinstripe",
]

## Emblemas que van encima. Todos procedurales, con contorno propio.
## Recortado con el mismo criterio que PATTERNS: afuera los que se leen
## más "sticker genérico" que escudo de club (rayos, sol, llama, botines
## cruzados, anillos/órbitas abstractas, flor, roseta).
const EMBLEMS := [
	"none",
	"em_ball", "em_star", "em_star_trio",
	"em_ribbon", "em_pennant", "em_scroll",
	"em_laurel", "em_laurel_star",
	"em_roundel", "em_shield_mini", "em_diamond", "em_crown",
	"em_wing", "em_anchor", "em_globe",
]

## --- Juego de piezas PIXEL ART (9-oct, pedido de Wilber: "siluetas de la
## actualidad, modulares con diseños y objetos") -------------------------
## Siluetas modernas dibujadas por código (tools/crest_shapes.py, PixelLab
## no logra siluetas lisas rellenas) + emblemas/objetos de PixelLab
## (tools/crest_assets.py). Los PATRONES siguen siendo los procedurales de
## siempre (se recortan dentro de la silueta igual que antes).
## PIXEL_SET = false vuelve al juego anterior tal cual (copia en
## art_src/legacy_kenney/Crest.gd.txt).
const PIXEL_SET := true
const PX_SHAPES := [
	"px_circle", "px_u_shield", "px_point_shield", "px_cut_shield", "px_squircle",
	"px_oval", "px_hexagon", "px_wing_shield", "px_diamond", "px_banner",
]
## Patrones para el juego pixel: los que se ven en escudos ACTUALES (afuera
## cheurón y pirámide: con las siluetas modernas dejaban una "Λ" oscura
## desprolija, visto en captura real).
const PX_PATTERNS := [
	"none", "none", "none",
	"pr_stripes", "pr_stripes_wide", "pr_hoops", "pr_hoops_thick", "pr_sash",
	"pr_halves", "pr_halves_diag", "pr_chief", "pr_base", "pr_pale", "pr_fess",
	"pr_quarters", "pr_border", "pr_pinstripe",
]
const PX_EMBLEMS := [
	"px_eagle", "px_lion", "px_crown", "px_wolf", "px_bull", "px_dragon",
	"px_tower", "px_anchor", "px_ball", "px_star", "px_horse",
	# 10-oct (escudos repetidos en una liga): 17 más, mismo estilo.
	"px_bear", "px_bee", "px_castle", "px_falcon", "px_fox", "px_griffin",
	"px_mountain", "px_owl", "px_panther", "px_phoenix", "px_rooster",
	"px_shark", "px_ship", "px_stag", "px_sun", "px_tiger", "px_tree",
	# un procedural que sigue funcionando bien al lado del arte (el laurel
	# se veía como una "Λ" oscura con picos — afuera):
	"em_star_trio",
]

## Cómo se coloca el emblema.
##  center       -> grande y centrado
##  upper        -> chico, tercio superior
##  banner_lower -> sobre una cinta en la parte baja
const LAYOUTS := ["center", "center", "upper", "banner_lower"]

static var _cache: Dictionary = {}

static func _tex(file: String) -> Texture2D:
	if _cache.has(file):
		return _cache[file]
	var p := _DIR + file
	var t: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
	_cache[file] = t
	return t

## UNICIDAD POR LIGA (10-oct, Wilber: "en una liga encontré como 7 veces el
## mismo escudo igualito y me confundo"). Causa raíz: en tablas (escudo
## < 40 px) no se dibuja el patrón, así que el escudo chico se reduce a
## silueta (10) × emblema (12) × colores, sorteado por hash de CADA club
## sin mirar a sus vecinos — y en una liga de 20 muchos comparten colores
## (rojo/blanco…): con 12 emblemas la repetición era casi segura. Ahora
## cada PAÍS reparte emblema y silueta entre sus clubes (barajado
## determinista): ningún emblema se repite dentro de una liga mientras haya
## emblemas de sobra, y las siluetas rotan. Fuera del mundo (clave que no
## es un club_id), el hash de siempre.
static var _league_slot: Dictionary = {}   # club_id -> [shape_idx, emblem_idx]

static func _slot_for(club_id: String) -> Array:
	if _league_slot.has(club_id):
		return _league_slot[club_id]
	var world: Dictionary = WorldTickEngine.world
	if world.is_empty():
		return []
	# Por PAÍS, no por liga: con ascensos/descensos un club cambia de liga y
	# su escudo no puede cambiar; además así no se repite entre 1.ª y 2.ª.
	var metas: Dictionary = world.get("club_meta_by_id", {})
	if not metas.has(club_id):
		return []
	var country: String = String(metas[club_id].get("country", ""))
	var ids: Array = []
	for cid in metas:
		if String(metas[cid].get("country", "")) == country:
			ids.append(String(cid))
	ids.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("crestcountry:" + country)
	var emb: Array = range(PX_EMBLEMS.size())
	var shp: Array = range(PX_SHAPES.size())
	_shuffle(emb, rng)
	_shuffle(shp, rng)
	# Dos clubes con el mismo emblema están a k·E posiciones (E = emblemas);
	# la silueta avanza 1 + `off` por vuelta, con `off` elegido para que
	# (E + off) ≡ 1 (mod siluetas): la silueta difiere en k — sin choque
	# hasta 10 vueltas (antes 29+1 = 30 caía en la MISMA silueta: Argentina
	# y MLS, 30 clubes, repetían).
	var off: int = posmod(1 - emb.size(), shp.size())
	for i in range(ids.size()):
		var lap: int = i / emb.size()
		_league_slot[ids[i]] = [shp[(i + lap * off) % shp.size()], emb[i % emb.size()]]
	return _league_slot.get(club_id, [])

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

## Config determinista. Muchos ejes = muy pocos escudos repetidos.
static func config_for(seed_key: String) -> Dictionary:
	if PIXEL_SET:
		var hp: int = absi(hash("crest:v7px:" + seed_key))
		var shape_i: int = (hp / 3) % PX_SHAPES.size()
		var emb_i: int = (hp / 37) % PX_EMBLEMS.size()
		var slot: Array = _slot_for(seed_key)
		if slot.size() == 2:
			shape_i = int(slot[0])
			emb_i = int(slot[1])
		return {
			"shape_name": PX_SHAPES[shape_i],
			"pattern": maxi(0, PATTERNS.find(PX_PATTERNS[(hp / 7) % PX_PATTERNS.size()])),
			"emblem_name": PX_EMBLEMS[emb_i],
			"layout": [0, 0, 1][(hp / 101) % 3],   # centro (más común) o arriba; sin cinta
			"trim": false,
			"flip": ((hp / 617) % 2) == 0,
			"accent_mode": (hp / 1531) % 3,
		}
	var h: int = absi(hash("crest:v6:" + seed_key))
	return {
		"shape": (h / 3) % SHAPES.size(),
		"pattern": (h / 7) % PATTERNS.size(),
		"emblem": (h / 37) % EMBLEMS.size(),
		"layout": (h / 101) % LAYOUTS.size(),
		"trim": ((h / 211) % 4) == 0,
		"flip": ((h / 617) % 2) == 0,
		"accent_mode": (h / 1531) % 3,   # 0 secundario · 1 secundario claro · 2 dorado
	}

## Color del "adorno" (emblema / cinta) según accent_mode.
static func _accent(secondary: Color, mode: int) -> Color:
	match mode:
		1: return secondary.lightened(0.45)
		2: return Color("#e8c860")
		_: return secondary.lightened(0.12)

## Control de `px`×`px` con el escudo compuesto.
static func build(primary: Color, secondary: Color, cfg: Dictionary, px: int, with_emblem: bool = true) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shape: String = String(cfg.get("shape_name", SHAPES[clampi(int(cfg.get("shape", 0)), 0, SHAPES.size() - 1)]))
	var px_shape: bool = shape.begins_with("px_")
	var layout: String = LAYOUTS[clampi(int(cfg.get("layout", 0)), 0, LAYOUTS.size() - 1)]
	var flip: bool = bool(cfg.get("flip", false))
	var accent: Color = _accent(secondary, int(cfg.get("accent_mode", 0)))
	# Versión CHICA (tablas/listas, < 40 px): visto en captura real del
	# juego (9-oct, Wilber: "solo a mi equipo le sale el nuevo escudo") —
	# a ~20 px el pixel art de 64 px reducido sin suavizado dejaba el emblema
	# como una mancha y el patrón ilegible: los escudos de los demás clubes
	# (siempre chicos en tablas) parecían genéricos/viejos. En chico: sin
	# patrón ni placa, emblema grande, y reducción SUAVIZADA (LINEAR).
	var small: bool = px < 40 and String(cfg.get("shape_name", "")).begins_with("px_")
	if small:
		root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var primary_lum: float = primary.get_luminance()
	# Contorno claro sobre primario oscuro, oscuro sobre primario claro —
	# si no, un club con primario casi negro (Newcastle) se comía su
	# propio contorno y el escudo quedaba plano, todo un mismo color.
	var outline_col: Color = Color(0.92, 0.93, 0.96) if primary_lum < 0.35 else Color(0.10, 0.11, 0.14)

	# Piso de luminancia SOLO para el relleno: un primario casi negro
	# (56 clubes reales del mundo importado tienen "#000000" literal, p.ej.
	# Corinthians/Botafogo/LAFC, y Newcastle "#241F20", luminancia 0.126)
	# se confunde con el propio fondo de tarjeta de la UI —
	# `Styles.CARD_DARK` es Color(0.11,0.11,0.11), luminancia 0.11 — así que
	# el escudo entero se "hundía" en la tarjeta y solo quedaban visibles el
	# contorno claro y las líneas finas del patrón/emblema que le tocaran
	# por hash: "es todo negro, solo lo salva el borde" (Wilber, escudo real
	# de Newcastle en su partida). Verificado con mockup pixel-exacto: un
	# piso de 0.20 (0.09 sobre la tarjeta) seguía leyéndose casi negro; 0.30
	# (0.19 sobre la tarjeta) ya se distingue con claridad en tarjetas/listas
	# y perfiles, y a tamaño de ícono chico (~44px) el contorno + la cruz/
	# cinta del patrón siguen leyéndose bien — límite de resolución, no de
	# color. El resto de la lógica (contorno/acento/patrón) sigue usando
	# `primary`/`primary_lum` reales, sin tocar la identidad de color del
	# club.
	var fill_tint: Color = primary
	if primary_lum < 0.30:
		var lift: float = clampf((0.30 - primary_lum) / maxf(0.001, 1.0 - primary_lum), 0.0, 0.5)
		fill_tint = primary.lightened(lift)

	# El relleno actúa de máscara: sus hijos se recortan a la silueta.
	var proc_shape: bool = shape.begins_with("pr_")
	var fill: TextureRect
	if px_shape:
		fill = _layer("%s_fill.png" % shape, fill_tint, px)
	elif proc_shape:
		fill = _tex_layer(_shape_fill_tex(shape), fill_tint)
	else:
		fill = _layer("sh_%s_fill.png" % shape, fill_tint, px)
	fill.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	root.add_child(fill)

	# Sombreado interno sutil: aro oscuro pegado al borde -> da volumen.
	# (Las siluetas pixel ya traen bisel + degradé horneados en el relleno.)
	if not px_shape:
		var shade := _tex_layer(_shade_tex(), Color(0, 0, 0, 0.18))
		fill.add_child(shade)

	# Brillo diagonal más marcado sobre rellenos oscuros: además del piso de
	# arriba, un highlight más visible ayuda a que se note relieve en vez de
	# una mancha plana (mismo caso Newcastle/clubes "todo negro").
	var sheen_alpha: float = 0.32 if primary_lum < 0.30 else 0.16

	# Patrón.
	var pat: String = PATTERNS[clampi(int(cfg.get("pattern", 0)), 0, PATTERNS.size() - 1)]
	if small:
		pat = "none"
	if pat.begins_with("pr_"):
		var pl := _tex_layer(_pattern_tex(pat, secondary), Color.WHITE)
		if flip:
			pl.flip_h = true
		fill.add_child(pl)
	elif pat != "none":
		fill.add_child(_layer("pat_%s.png" % pat, secondary, px))

	# Aro interior del color de acento (silueta pixel) — el detalle más
	# típico de los escudos actuales.
	if px_shape:
		fill.add_child(_layer("%s_rim.png" % shape, accent, px))

	if bool(cfg.get("trim", false)):
		var trim_tint: Color = accent
		trim_tint.a = 0.8
		fill.add_child(_layer("trim.png", trim_tint, px))

	# Brillo: sutil y arriba (antes deslavaba todo); más marcado en rellenos
	# oscuros -- ver `sheen_alpha` arriba.
	if not px_shape:
		var sh := _tex_layer(_tex("sheen.png"), Color(1, 1, 1, sheen_alpha))
		fill.add_child(sh)

	# Emblema (+ cinta si el layout la pide).
	var emb: String = String(cfg.get("emblem_name", EMBLEMS[clampi(int(cfg.get("emblem", 0)), 0, EMBLEMS.size() - 1)]))
	if with_emblem and emb.begins_with("px_"):
		# Emblema pixel art de PixelLab: blanco/grises + contorno oscuro ya
		# horneado → se tiñe multiplicando por el acento (el contorno sigue
		# oscuro, el sombreado se conserva).
		# Contraste garantizado: un acento que casi no se distingue del
		# relleno (visto: emblema negro sobre verde oscuro) pasa a blanco o
		# casi negro, el que más se lea.
		var emb_col: Color = accent
		if absf(accent.get_luminance() - fill_tint.get_luminance()) < 0.30:
			emb_col = Color(0.96, 0.96, 0.96) if fill_tint.get_luminance() < 0.55 else Color(0.10, 0.11, 0.14)
		var et := _tex_layer(_tex("emblems/%s.png" % emb), emb_col)
		var center_y: float = 0.36 if layout == "upper" else 0.52
		if pat != "none":
			# Con patrón, el emblema va sobre una PLACA redonda lisa del color
			# principal (si no, un emblema del mismo color que las franjas se
			# pierde — visto en el mockup del óvalo azul con torre azul).
			var plate_size: float = 0.46 if layout == "upper" else 0.58
			fill.add_child(_placed(_layer("px_circle_fill.png", fill_tint, px), Vector2(0.5, center_y), plate_size))
			fill.add_child(_placed(_layer("px_circle_outline.png", Color(0.08, 0.09, 0.11), px), Vector2(0.5, center_y), plate_size))
			fill.add_child(_placed(et, Vector2(0.5, center_y), plate_size * 0.76))
		elif small:
			fill.add_child(_placed(et, Vector2(0.5, 0.52), 0.74))
		else:
			fill.add_child(_placed(et, Vector2(0.5, center_y), 0.46 if layout == "upper" else 0.62))
	elif with_emblem and emb != "none":
		if layout == "banner_lower":
			fill.add_child(_placed(_tex_layer(_banner_tex(accent), Color.WHITE), Vector2(0.5, 0.74), 0.92))
			fill.add_child(_placed(_tex_layer(_emblem_tex(emb, accent), Color.WHITE), Vector2(0.5, 0.42), 0.5))
		elif layout == "upper":
			fill.add_child(_placed(_tex_layer(_emblem_tex(emb, accent), Color.WHITE), Vector2(0.5, 0.34), 0.42))
		else:
			fill.add_child(_placed(_tex_layer(_emblem_tex(emb, accent), Color.WHITE), Vector2(0.5, 0.52), 0.72))

	if px_shape:
		root.add_child(_layer("%s_outline.png" % shape, outline_col, px))
	elif proc_shape:
		root.add_child(_tex_layer(_shape_outline_tex(shape), outline_col))
	else:
		root.add_child(_layer("sh_%s_outline.png" % shape, outline_col, px))
	if small:
		_set_filter(root, CanvasItem.TEXTURE_FILTER_LINEAR)
	return root

# --------------------------------------------------------------------------
# Siluetas PROCEDURALES (formas de escudos reales)
# --------------------------------------------------------------------------

static func _shape_mask(name: String) -> Image:
	var img := _new_img()
	var w := _PX
	var W := Color(1, 1, 1, 1)
	var l := 7.0
	var r := float(w) - 7.0
	var top := 4.0
	var bot := float(w) - 4.0
	match name:
		"pr_spanish":
			# Recto arriba y lados; base SEMICIRCULAR.
			var midy := lerpf(top, bot, 0.52)
			_rect(img, int(l), int(top), int(r), int(midy), W)
			_half_disc(img, (l + r) * 0.5, midy, (r - l) * 0.5, true, W)
		"pr_french":
			# Escudo francés antiguo: recto arriba/lados, base que baja con
			# hombros y una pequeña punta central (curva suave, sin dientes).
			var my := lerpf(top, bot, 0.58)
			var cxf := (l + r) * 0.5
			_rect(img, int(l), int(top), int(r), int(my), W)
			for y in range(int(my), int(bot) + 1):
				var t := (float(y) - my) / (bot - my)                # 0..1
				# hombros que se mantienen anchos y luego cierran a la punta
				var half := (r - l) * 0.5 * (1.0 - pow(t, 2.4)) + 3.0 * (1.0 - t)
				_rect(img, int(cxf - half), y, int(cxf + half), y, W)
		"pr_italian":
			var my2 := lerpf(top, bot, 0.42)
			# esquinas superiores redondeadas
			_rect(img, int(l), int(top) + 4, int(r), int(my2), W)
			_rect(img, int(l) + 4, int(top), int(r) - 4, int(top) + 4, W)
			_disc(img, l + 4, top + 4, 4, W)
			_disc(img, r - 4, top + 4, 4, W)
			# lados que curvan hacia dentro + punta
			for y in range(int(my2), int(bot) + 1):
				var t2 := (float(y) - my2) / (bot - my2)
				var half2 := (r - l) * 0.5 * (1.0 - pow(t2, 1.7))
				var cx2 := (l + r) * 0.5
				_rect(img, int(cx2 - half2), y, int(cx2 + half2), y, W)
		"pr_scudetto":
			# Gota: arriba redondeado ancho, baja a punta fina (escudo Juve).
			for y in range(int(top), int(bot) + 1):
				var t3 := (float(y) - top) / (bot - top)
				var half3 := (r - l) * 0.5 * sqrt(maxf(0.0, 1.0 - pow(t3 * 1.02, 2.2)))
				if t3 < 0.12:
					half3 *= t3 / 0.12
				var cx3 := (l + r) * 0.5
				_rect(img, int(cx3 - half3), y, int(cx3 + half3), y, W)
		"pr_oval":
			# Óvalo VERTICAL (Boca/River): más angosto que alto.
			_ellipse(img, (l + r) * 0.5, (top + bot) * 0.5, (r - l) * 0.40, (bot - top) * 0.52, W)
		"pr_pennant":
			# Banderín de cola de golondrina: cuerpo recto y base con DOS
			# puntas y una muesca en V en el centro.
			var my4 := lerpf(top, bot, 0.46)
			var cxp := (l + r) * 0.5
			_rect(img, int(l), int(top), int(r), int(my4), W)
			_fill_poly(img, PackedVector2Array([
				Vector2(l, my4), Vector2(r, my4),
				Vector2(cxp + 13, bot), Vector2(cxp, my4 + 9), Vector2(cxp - 13, bot),
			]), W)
		"pr_hex":
			var cx5 := (l + r) * 0.5
			var cy5 := (top + bot) * 0.5
			_fill_poly(img, PackedVector2Array([
				Vector2(cx5, top), Vector2(r, lerpf(top, bot, 0.3)), Vector2(r, lerpf(top, bot, 0.7)),
				Vector2(cx5, bot), Vector2(l, lerpf(top, bot, 0.7)), Vector2(l, lerpf(top, bot, 0.3)),
			]), W)
		"pr_demi":
			var my6 := lerpf(top, bot, 0.34)
			_rect(img, int(l), int(top), int(r), int(my6), W)
			_half_disc(img, (l + r) * 0.5, my6, (r - l) * 0.5, true, W)
		"pr_kite":
			# Hombros redondeados que caen a una punta (muy sudamericano).
			_rect(img, int(l), int(top) + 5, int(r), int(top) + 12, W)
			_disc(img, l + 6, top + 8, 6, W)
			_disc(img, r - 6, top + 8, 6, W)
			_rect(img, int(l) + 6, int(top), int(r) - 6, int(top) + 8, W)
			for y in range(int(top) + 12, int(bot) + 1):
				var t7 := (float(y) - top - 12.0) / (bot - top - 12.0)
				var half7 := (r - l) * 0.5 * (1.0 - pow(t7, 1.5))
				var cx7 := (l + r) * 0.5
				_rect(img, int(cx7 - half7), y, int(cx7 + half7), y, W)
		"pr_crested":
			# Remate ALMENADO arriba (4 dientes cuadrados, como una
			# muralla) y cuerpo que cierra en punta abajo.
			var cxc := (l + r) * 0.5
			var teeth := 4
			var tooth_w := (r - l) / float(teeth)
			for i in range(teeth):
				var tx0 := l + float(i) * tooth_w
				var tx1 := tx0 + tooth_w * 0.7
				_rect(img, int(tx0), int(top), int(tx1), int(top) + 9, W)
			var body_top := top + 9
			var mycr := lerpf(body_top, bot, 0.42)
			_rect(img, int(l), int(body_top), int(r), int(mycr), W)
			for y in range(int(mycr), int(bot) + 1):
				var tcr := (float(y) - mycr) / (bot - mycr)
				var halfcr := (r - l) * 0.5 * (1.0 - pow(tcr, 1.6))
				_rect(img, int(cxc - halfcr), y, int(cxc + halfcr), y, W)
		"pr_eared":
			# Dos "orejas" redondeadas en los hombros superiores, cuerpo
			# clásico de escudo abajo (heater con punta suave).
			var cxe := (l + r) * 0.5
			var myea := lerpf(top, bot, 0.5)
			_rect(img, int(l), int(top) + 6, int(r), int(myea), W)
			_disc(img, l + 5, top + 6, 6, W)
			_disc(img, r - 5, top + 6, 6, W)
			for y in range(int(myea), int(bot) + 1):
				var tea := (float(y) - myea) / (bot - myea)
				var halfea := (r - l) * 0.5 * (1.0 - pow(tea, 1.5))
				_rect(img, int(cxe - halfea), y, int(cxe + halfea), y, W)
		_:
			_rect(img, int(l), int(top), int(r), int(bot), W)
	return img

static func _shape_fill_tex(name: String) -> Texture2D:
	var key := "shf|" + name
	if _proc_cache.has(key):
		return _proc_cache[key]
	var t := _tex_from(_shape_mask(name))
	_proc_cache[key] = t
	return t

static func _shape_outline_tex(name: String) -> Texture2D:
	var key := "sho|" + name
	if _proc_cache.has(key):
		return _proc_cache[key]
	var img := _shape_mask(name)
	# Deja SOLO el borde (blanco+alpha, SIN hornear color — se tiñe en
	# build() según la luminancia del `primary` de cada club, si no un
	# primario oscuro como el de Newcastle se comía el contorno oscuro de
	# siempre y el escudo quedaba todo negro, sin leerse nada — reportado
	# por Wilber).
	var edge := _new_img()
	var W := Color(1, 1, 1, 1)
	for y in range(_PX):
		for x in range(_PX):
			if img.get_pixel(x, y).a < 0.5:
				continue
			var border := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if not _in(nx, ny) or img.get_pixel(nx, ny).a < 0.5:
					border = true
					break
			if border:
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						_put(edge, x + ox, y + oy, W)
	var t := _tex_from(edge)
	_proc_cache[key] = t
	return t

static func _half_disc(img: Image, cx: float, cy: float, r: float, bottom: bool, c: Color) -> void:
	var r2 := r * r
	for y in range(int(cy - r) - 1, int(cy + r) + 2):
		if bottom and float(y) < cy:
			continue
		if not bottom and float(y) > cy:
			continue
		for x in range(int(cx - r) - 1, int(cx + r) + 2):
			var dx := float(x) - cx
			var dy := float(y) - cy
			if dx * dx + dy * dy <= r2:
				_put(img, x, y, c)

static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx := (float(x) - cx) / maxf(rx, 0.001)
			var dy := (float(y) - cy) / maxf(ry, 0.001)
			if dx * dx + dy * dy <= 1.0:
				_put(img, x, y, c)

# --------------------------------------------------------------------------
# Capas / helpers de nodo
# --------------------------------------------------------------------------

static func _layer(file: String, tint: Color, _px: int) -> TextureRect:
	return _tex_layer(_tex(file), tint)

static func _tex_layer(tex: Texture2D, tint: Color) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# self_modulate (NO modulate): `modulate` se HEREDA a los hijos, y el
	# relleno es el padre de patrón/aro/placa/emblema (los recorta con
	# clip_children) — con `modulate` todo lo de adentro salía además
	# multiplicado por el color del escudo: emblemas oscuros y apagados,
	# patrones turbios. Bug viejo, visto recién en captura REAL del juego
	# (9-oct); el mockup de Python no lo mostraba porque no tiene herencia.
	r.self_modulate = tint
	return r

## Envuelve un TextureRect para colocarlo a `anchor` (0..1 del escudo) con
## un tamaño relativo `scale_rel` (0..1). Se usa para emblemas/cintas.
static func _placed(inner: TextureRect, anchor: Vector2, scale_rel: float) -> Control:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = false
	inner.anchor_left = anchor.x - scale_rel * 0.5
	inner.anchor_right = anchor.x + scale_rel * 0.5
	inner.anchor_top = anchor.y - scale_rel * 0.5
	inner.anchor_bottom = anchor.y + scale_rel * 0.5
	inner.offset_left = 0
	inner.offset_right = 0
	inner.offset_top = 0
	inner.offset_bottom = 0
	holder.add_child(inner)
	return holder

# --------------------------------------------------------------------------
# Dibujo procedural (Image) — cacheado
# --------------------------------------------------------------------------

const _PX := 64
static var _proc_cache: Dictionary = {}

static func _new_img() -> Image:
	var img := Image.create(_PX, _PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	return img

static func _tex_from(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

static func _in(x: int, y: int) -> bool:
	return x >= 0 and x < _PX and y >= 0 and y < _PX

static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if _in(x, y):
		img.set_pixel(x, y, c)

static func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	var r2 := r * r
	for y in range(int(cy - r) - 1, int(cy + r) + 2):
		for x in range(int(cx - r) - 1, int(cx + r) + 2):
			var dx := float(x) - cx
			var dy := float(y) - cy
			if dx * dx + dy * dy <= r2:
				_put(img, x, y, c)

static func _ring(img: Image, cx: float, cy: float, r: float, w: float, c: Color) -> void:
	var ro := r + w * 0.5
	var ri := r - w * 0.5
	for y in range(int(cy - ro) - 1, int(cy + ro) + 2):
		for x in range(int(cx - ro) - 1, int(cx + ro) + 2):
			var d := sqrt(pow(float(x) - cx, 2.0) + pow(float(y) - cy, 2.0))
			if d <= ro and d >= ri:
				_put(img, x, y, c)

static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			_put(img, x, y, c)

static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color, thick: int = 1) -> void:
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var x: int = x0
	var y: int = y0
	while true:
		for oy in range(-thick / 2, thick / 2 + 1):
			for ox in range(-thick / 2, thick / 2 + 1):
				_put(img, x + ox, y + oy, c)
		if x == x1 and y == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

## Estrella de N puntas.
static func _star(img: Image, cx: float, cy: float, r_out: float, r_in: float, points: int, c: Color, rot: float = -PI / 2.0) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(points * 2):
		var rr: float = r_out if i % 2 == 0 else r_in
		var a: float = rot + float(i) * PI / float(points)
		pts.append(Vector2(cx + cos(a) * rr, cy + sin(a) * rr))
	_fill_poly(img, pts, c)

static func _fill_poly(img: Image, pts: PackedVector2Array, c: Color) -> void:
	if pts.size() < 3:
		return
	var min_y := _PX
	var max_y := 0
	for p in pts:
		min_y = mini(min_y, int(floor(p.y)))
		max_y = maxi(max_y, int(ceil(p.y)))
	min_y = maxi(min_y, 0)
	max_y = mini(max_y, _PX - 1)
	for y in range(min_y, max_y + 1):
		var xs: Array = []
		var j := pts.size() - 1
		for i in range(pts.size()):
			var a := pts[i]
			var b := pts[j]
			if (a.y <= float(y) and b.y > float(y)) or (b.y <= float(y) and a.y > float(y)):
				var t := (float(y) - a.y) / (b.y - a.y)
				xs.append(a.x + t * (b.x - a.x))
			j = i
		xs.sort()
		var k := 0
		while k + 1 < xs.size():
			for x in range(int(round(xs[k])), int(round(xs[k + 1])) + 1):
				_put(img, x, y, c)
			k += 2

## Añade un contorno oscuro alrededor de todo lo opaco (para que el emblema
## se lea sobre cualquier fondo). `passes` = grosor.
static func _rim(img: Image, rim_c: Color, passes: int = 2) -> void:
	for _p in range(passes):
		var src := img.duplicate()
		for y in range(_PX):
			for x in range(_PX):
				if src.get_pixel(x, y).a > 0.35:
					continue
				var near := false
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if _in(nx, ny) and src.get_pixel(nx, ny).a > 0.5 and src.get_pixel(nx, ny) != rim_c:
						near = true
						break
				if near:
					_put(img, x, y, rim_c)

# ---- Patrones (se tiñen con el color secundario del club) -----------------

static func _pattern_tex(name: String, col: Color) -> Texture2D:
	var key := name + "|" + col.to_html()
	if _proc_cache.has(key):
		return _proc_cache[key]
	var img := _new_img()
	var A := Color(col.r, col.g, col.b, 0.92)
	var A2 := Color(col.r, col.g, col.b, 0.55)
	var w := _PX
	match name:
		"pr_stripes":
			for x in range(w):
				if (x / 6) % 2 == 0:
					_rect(img, x, 0, x, w, A)
		"pr_stripes_wide":
			for x in range(w):
				if (x / 10) % 2 == 0:
					_rect(img, x, 0, x, w, A)
		"pr_pinstripe":
			for x in range(0, w, 7):
				_rect(img, x, 0, x, w, A2)
		"pr_hoops":
			for y in range(w):
				if (y / 6) % 2 == 0:
					_rect(img, 0, y, w, y, A)
		"pr_hoops_thick":
			for y in range(w):
				if (y / 11) % 2 == 0:
					_rect(img, 0, y, w, y, A)
		"pr_sash":
			_thick_line(img, 0, w - 6, w - 6, 0, 10, A)
		"pr_sash_double":
			_thick_line(img, 0, w - 4, w - 4, 0, 7, A)
			_thick_line(img, 8, w, w, 8, 7, A2)
		"pr_bend":
			_thick_line(img, 0, 0, w, w, 12, A)
		"pr_chevron":
			for k in range(-w, w, 14):
				_line(img, 0, k + w / 2, w / 2, k, A, 4)
				_line(img, w / 2, k, w, k + w / 2, A, 4)
		"pr_chevrons_stack":
			for k in range(6, w, 12):
				_line(img, 4, k + 8, w / 2, k, A, 3)
				_line(img, w / 2, k, w - 4, k + 8, A, 3)
		"pr_pale":
			_rect(img, w / 2 - 7, 0, w / 2 + 7, w, A)
		"pr_fess":
			_rect(img, 0, w / 2 - 7, w, w / 2 + 7, A)
		"pr_cross":
			_rect(img, w / 2 - 6, 0, w / 2 + 6, w, A)
			_rect(img, 0, w / 2 - 6, w, w / 2 + 6, A)
		"pr_saltire":
			_thick_line(img, 0, 0, w, w, 8, A)
			_thick_line(img, w, 0, 0, w, 8, A)
		"pr_quarters":
			_rect(img, 0, 0, w / 2, w / 2, A)
			_rect(img, w / 2, w / 2, w, w, A)
		"pr_chief":
			_rect(img, 0, 0, w, 16, A)
		"pr_base":
			_rect(img, 0, w - 16, w, w, A)
		"pr_pile":
			_fill_poly(img, PackedVector2Array([Vector2(w / 2, w), Vector2(6, 0), Vector2(w - 6, 0)]), A)
		"pr_lozenge":
			for gy in range(-1, 6):
				for gx in range(-1, 6):
					var cx := gx * 14
					var cy := gy * 14 + (7 if gx % 2 == 0 else 0)
					_fill_poly(img, PackedVector2Array([Vector2(cx, cy - 7), Vector2(cx + 7, cy), Vector2(cx, cy + 7), Vector2(cx - 7, cy)]), A2)
		"pr_checker":
			for gy in range(0, w, 10):
				for gx in range(0, w, 10):
					if ((gx + gy) / 10) % 2 == 0:
						_rect(img, gx, gy, gx + 9, gy + 9, A2)
		"pr_rays":
			for a in range(0, 360, 18):
				var ar := deg_to_rad(a)
				_line(img, w / 2, w, int(w / 2 + cos(ar) * w), int(w + sin(ar) * w), A2, 3)
		"pr_halves":
			_rect(img, w / 2, 0, w, w, A)
		"pr_halves_diag":
			_fill_poly(img, PackedVector2Array([Vector2(w, 0), Vector2(w, w), Vector2(0, w)]), A)
		"pr_orbit":
			_ring(img, w / 2.0, w / 2.0, 20, 7, A)
		"pr_border":
			_rect(img, 0, 0, w, w, A)
			_rect(img, 6, 6, w - 6, w - 6, Color(0, 0, 0, 0))
		"pr_diag_bars":
			for y in range(w):
				for x in range(w):
					if ((x + y) / 6) % 2 == 0:
						_put(img, x, y, A2)
		"pr_gyronny":
			for y in range(w):
				for x in range(w):
					var q := (1 if x > w / 2 else 0) + (2 if y > w / 2 else 0)
					var diag := x + y < w
					if (q == 0 and diag) or (q == 3 and not diag) or q == 1:
						_put(img, x, y, A2)
		"pr_spark":
			_star(img, w / 2.0, w / 2.0, 30, 6, 12, A2)
	var t := _tex_from(img)
	_proc_cache[key] = t
	return t

static func _thick_line(img: Image, x0: int, y0: int, x1: int, y1: int, thick: int, c: Color) -> void:
	_line(img, x0, y0, x1, y1, c, thick)

# ---- Emblemas (traen su propio contorno; `accent` = color del cuerpo) -----

static func _emblem_tex(name: String, accent: Color) -> Texture2D:
	var key := "em|" + name + "|" + accent.to_html()
	if _proc_cache.has(key):
		return _proc_cache[key]
	var img := _new_img()
	var w := _PX
	var mid := w / 2.0
	# El cuerpo del emblema tiene que CONTRASTAR con el relleno del escudo.
	# Si el color de adorno del club es oscuro, se usa plateado casi blanco
	# (queda elegante); si es brillante, se usa tal cual.
	var body: Color = accent if accent.get_luminance() > 0.50 else Color(0.92, 0.93, 0.96)
	var lite := body.lightened(0.35)
	var dark := Color(0.10, 0.11, 0.15, 1.0)
	match name:
		"em_ball":
			_disc(img, mid, mid, 20, Color(0.97, 0.97, 0.98))
			var pent: PackedVector2Array = PackedVector2Array()
			for i in range(5):
				var a := -PI / 2.0 + float(i) * TAU / 5.0
				pent.append(Vector2(mid + cos(a) * 8.0, mid + sin(a) * 8.0))
			_fill_poly(img, pent, dark)
			for i in range(5):
				var a2 := -PI / 2.0 + float(i) * TAU / 5.0 + TAU / 10.0
				_line(img, int(mid + cos(a2) * 8), int(mid + sin(a2) * 8), int(mid + cos(a2) * 20), int(mid + sin(a2) * 20), dark, 2)
		"em_star":
			_star(img, mid, mid, 22, 9, 5, body)
		"em_starburst":
			for i in range(12):
				var a := float(i) * TAU / 12.0
				_line(img, int(mid), int(mid), int(mid + cos(a) * 26), int(mid + sin(a) * 26), lite, 2)
			_star(img, mid, mid, 16, 6, 5, body)
		"em_star_trio":
			_star(img, mid, mid - 4, 12, 5, 5, body)
			_star(img, mid - 13, mid + 10, 9, 4, 5, body)
			_star(img, mid + 13, mid + 10, 9, 4, 5, body)
		"em_ribbon":
			_fill_poly(img, PackedVector2Array([Vector2(4, 24), Vector2(w - 4, 24), Vector2(w - 4, 40), Vector2(4, 40)]), body)
			_fill_poly(img, PackedVector2Array([Vector2(0, 20), Vector2(10, 24), Vector2(10, 40), Vector2(0, 44)]), body.darkened(0.2))
			_fill_poly(img, PackedVector2Array([Vector2(w, 20), Vector2(w - 10, 24), Vector2(w - 10, 40), Vector2(w, 44)]), body.darkened(0.2))
		"em_pennant":
			_fill_poly(img, PackedVector2Array([Vector2(10, 8), Vector2(48, 20), Vector2(10, 32)]), body)
			_rect(img, 8, 8, 11, 52, body.darkened(0.25))
		"em_scroll":
			_fill_poly(img, PackedVector2Array([Vector2(6, 26), Vector2(w - 6, 26), Vector2(w - 6, 38), Vector2(6, 38)]), Color(0.93, 0.9, 0.8))
			_ring(img, 8, 32, 5, 3, Color(0.8, 0.75, 0.62))
			_ring(img, w - 8, 32, 5, 3, Color(0.8, 0.75, 0.62))
		"em_flower":
			for i in range(8):
				var a := float(i) * TAU / 8.0
				_disc(img, mid + cos(a) * 12.0, mid + sin(a) * 12.0, 7.0, body)
			_disc(img, mid, mid, 7, lite)
		"em_rosette":
			_ring(img, mid, mid, 20, 4, body)
			for i in range(16):
				var a := float(i) * TAU / 16.0
				_disc(img, mid + cos(a) * 20.0, mid + sin(a) * 20.0, 3.0, body)
			_disc(img, mid, mid, 7, lite)
		"em_laurel":
			_laurel(img, mid, dark, body)
		"em_laurel_star":
			_laurel(img, mid, dark, body)
			_star(img, mid, mid, 11, 5, 5, lite)
		"em_roundel":
			_disc(img, mid, mid, 22, body)
			_disc(img, mid, mid, 15, Color(0.96, 0.96, 0.98))
			_disc(img, mid, mid, 8, body)
		"em_ring_dot":
			_ring(img, mid, mid, 18, 6, body)
			_disc(img, mid, mid, 6, lite)
		"em_orbits":
			_ring(img, mid, mid, 20, 3, body)
			_ring(img, mid, mid, 12, 3, lite)
			_disc(img, mid, mid, 4, body)
		"em_bolt":
			_fill_poly(img, PackedVector2Array([Vector2(34, 6), Vector2(16, 34), Vector2(28, 34), Vector2(22, 58), Vector2(46, 26), Vector2(32, 26)]), body)
		"em_double_bolt":
			_fill_poly(img, PackedVector2Array([Vector2(26, 6), Vector2(12, 32), Vector2(22, 32), Vector2(16, 52), Vector2(34, 28), Vector2(24, 28)]), body)
			_fill_poly(img, PackedVector2Array([Vector2(44, 12), Vector2(32, 34), Vector2(40, 34), Vector2(36, 52), Vector2(52, 30), Vector2(44, 30)]), lite)
		"em_sun":
			for i in range(16):
				var a := float(i) * TAU / 16.0
				_line(img, int(mid + cos(a) * 12), int(mid + sin(a) * 12), int(mid + cos(a) * 24), int(mid + sin(a) * 24), lite, 3)
			_disc(img, mid, mid, 12, body)
		"em_flame":
			_fill_poly(img, PackedVector2Array([Vector2(mid, 6), Vector2(mid + 16, 34), Vector2(mid + 10, 52), Vector2(mid, 44), Vector2(mid - 10, 52), Vector2(mid - 16, 34)]), body)
			_fill_poly(img, PackedVector2Array([Vector2(mid, 20), Vector2(mid + 7, 38), Vector2(mid, 48), Vector2(mid - 7, 38)]), lite)
		"em_shield_mini":
			_fill_poly(img, PackedVector2Array([Vector2(mid - 16, 12), Vector2(mid + 16, 12), Vector2(mid + 16, 34), Vector2(mid, 50), Vector2(mid - 16, 34)]), body)
			_fill_poly(img, PackedVector2Array([Vector2(mid - 9, 18), Vector2(mid + 9, 18), Vector2(mid + 9, 32), Vector2(mid, 42), Vector2(mid - 9, 32)]), lite)
		"em_diamond":
			_fill_poly(img, PackedVector2Array([Vector2(mid, 8), Vector2(mid + 16, 26), Vector2(mid, 56), Vector2(mid - 16, 26)]), body)
			_fill_poly(img, PackedVector2Array([Vector2(mid, 8), Vector2(mid + 16, 26), Vector2(mid, 26)]), lite)
		"em_crown":
			_fill_poly(img, PackedVector2Array([Vector2(10, 40), Vector2(14, 18), Vector2(24, 32), Vector2(mid, 12), Vector2(40, 32), Vector2(50, 18), Vector2(54, 40)]), body)
			_rect(img, 10, 40, w - 10, 46, body.darkened(0.15))
		"em_crossed_boots":
			_thick_line(img, 14, 14, 46, 46, 6, body)
			_thick_line(img, 46, 14, 14, 46, 6, lite)
			_disc(img, 14, 46, 5, body)
			_disc(img, 46, 46, 5, lite)
		"em_wing":
			for i in range(5):
				_fill_poly(img, PackedVector2Array([Vector2(mid, 20 + i * 5), Vector2(mid - 22 + i * 3, 26 + i * 6), Vector2(mid - 8, 30 + i * 6)]), body if i % 2 == 0 else lite)
				_fill_poly(img, PackedVector2Array([Vector2(mid, 20 + i * 5), Vector2(mid + 22 - i * 3, 26 + i * 6), Vector2(mid + 8, 30 + i * 6)]), body if i % 2 == 0 else lite)
		"em_anchor":
			_rect(img, mid - 2, 12, mid + 2, 46, body)
			_ring(img, mid, 12, 5, 3, body)
			_line(img, int(mid - 16), 40, int(mid), 50, body, 4)
			_line(img, int(mid + 16), 40, int(mid), 50, body, 4)
			_rect(img, mid - 10, 22, mid + 10, 26, body)
		"em_globe":
			_disc(img, mid, mid, 20, body)
			_ring(img, mid, mid, 20, 2, dark)
			for yy in [-10, 0, 10]:
				_line(img, int(mid - 20), int(mid + yy), int(mid + 20), int(mid + yy), dark, 1)
			_ring(img, mid, mid, 8, 2, dark)
	_rim(img, dark, 1)
	var t := _tex_from(img)
	_proc_cache[key] = t
	return t

static func _laurel(img: Image, mid: float, stem: Color, leaf: Color) -> void:
	for side: float in [-1.0, 1.0]:
		for i in range(8):
			var t: float = float(i) / 7.0
			var ang: float = lerpf(0.9, -0.5, t) * side
			var px: float = mid + side * lerpf(20.0, 6.0, t)
			var py: float = lerpf(46.0, 12.0, t)
			var lx: float = px + cos(ang) * 8.0 * side
			var ly: float = py + sin(ang) * 8.0
			_fill_poly(img, PackedVector2Array([Vector2(px, py), Vector2((px + lx) * 0.5 - side * 3.0, (py + ly) * 0.5), Vector2(lx, ly)]), leaf)
		_line(img, int(mid + side * 20.0), 46, int(mid + side * 6.0), 12, stem, 2)

# ---- Cinta de fondo para el layout banner_lower --------------------------

static func _banner_tex(col: Color) -> Texture2D:
	var key := "banner|" + col.to_html()
	if _proc_cache.has(key):
		return _proc_cache[key]
	var img := _new_img()
	var w := _PX
	var y0 := 34
	var y1 := 50
	_fill_poly(img, PackedVector2Array([Vector2(2, y0), Vector2(w - 2, y0), Vector2(w - 2, y1), Vector2(2, y1)]), col)
	_fill_poly(img, PackedVector2Array([Vector2(0, y0 - 4), Vector2(8, y0), Vector2(8, y1), Vector2(0, y1 + 4)]), col.darkened(0.25))
	_fill_poly(img, PackedVector2Array([Vector2(w, y0 - 4), Vector2(w - 8, y0), Vector2(w - 8, y1), Vector2(w, y1 + 4)]), col.darkened(0.25))
	_rim(img, Color(0.09, 0.10, 0.13, 1.0), 1)
	var t := _tex_from(img)
	_proc_cache[key] = t
	return t

# ---- Sombreado interno -------------------------------------------------

static var _shade_cache: ImageTexture = null
static func _shade_tex() -> ImageTexture:
	if _shade_cache != null:
		return _shade_cache
	var img := _new_img()
	var w := _PX
	for y in range(w):
		for x in range(w):
			var d: float = minf(minf(float(x), float(w - 1 - x)), minf(float(y), float(w - 1 - y)))
			if d < 5.0:
				_put(img, x, y, Color(0, 0, 0, (1.0 - d / 5.0) * 0.55))
	_shade_cache = _tex_from(img)
	return _shade_cache

static func _set_filter(n: Node, f: CanvasItem.TextureFilter) -> void:
	if n is CanvasItem:
		(n as CanvasItem).texture_filter = f
	for c in n.get_children():
		_set_filter(c, f)
