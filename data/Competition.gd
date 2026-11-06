extends RefCounted
class_name Competition

## Logo procedural por CAPAS de una competición (liga / copa doméstica /
## torneo continental), mismo espíritu que Crest.gd: PNGs blancos de 64×64
## en assets/complogos/ que se apilan y se tiñen con `modulate`, retro
## pixel-art (TEXTURE_FILTER_NEAREST). No se pre-generan: cada competición
## arma el suyo DETERMINISTA a partir de una clave estable.
##
## Capas: shape_<f> (relleno, primario) → ring_<f> (aro, secundario) →
## acc_<a> (adorno, blanco) → emb_<e> (emblema central) → outline_<f>
## (borde oscuro).

const _DIR := "res://assets/complogos/"

const SHAPES := ["roundel", "shield", "hex"]
const EMBLEMS := ["trophy", "ball", "star", "globe", "crown"]
const ACCENTS := ["none", "dots"]

## Color por confederación para los torneos continentales (primario, secundario).
const CONF_COLORS := {
	"UEFA": ["#1b2a6b", "#e8b800"],
	"CONMEBOL": ["#0b6b3a", "#e8c84a"],
	"CONCACAF": ["#0a6e73", "#e8e8e8"],
	"AFC": ["#c8621b", "#f0d24a"],
	"CAF": ["#0a7d3a", "#e8c84a"],
}

## Paleta determinista para ligas y copas domésticas (primario, secundario).
const PALETTE := [
	["#b0161f", "#f0d060"], ["#123a8a", "#e8e8e8"], ["#0d6b3f", "#f0d060"],
	["#5a1f8a", "#ecc8f0"], ["#1f1f1f", "#e8b800"], ["#0a5a7a", "#e8e8e8"],
	["#a8431a", "#f0d060"], ["#7a1030", "#e8c84a"],
]

# --- Configs ---

static func config_for(seed_key: String) -> Dictionary:
	var h: int = absi(hash("comp:" + seed_key))
	return {
		"shape": h % SHAPES.size(),
		"emblem": int(h / 5) % EMBLEMS.size(),
		"accent": int(h / 37) % ACCENTS.size(),
	}

static func for_league(league_id: int) -> Dictionary:
	var c := config_for("league:%d" % league_id)
	c["shape"] = int(absi(hash("lgshape:%d" % league_id)) % 2)  # roundel o shield
	c["emblem"] = EMBLEMS.find("star")
	return c

static func for_domestic_cup(country: String) -> Dictionary:
	var c := config_for("cup:" + country)
	c["shape"] = SHAPES.find("shield")
	c["emblem"] = EMBLEMS.find("trophy")
	c["accent"] = ACCENTS.find("none")
	return c

static func for_continental(confederation: String, tier: int) -> Dictionary:
	var c := config_for("cont:%s:%d" % [confederation, tier])
	c["shape"] = SHAPES.find("roundel")
	c["emblem"] = EMBLEMS.find("trophy") if tier == 1 else (EMBLEMS.find("globe") if tier == 2 else EMBLEMS.find("star"))
	c["accent"] = ACCENTS.find("dots")
	return c

# --- Nodos listos (eligen color solos) ---

## Logos con arte FIJO real (Wilber, sept-2026, generados fuera de Godot,
## mismos ids que Trophy.V3_ART: "league_<id>", "cont_<conf>_<tier>",
## "natcup_<conf>", "supercopa_cont", "mundial_clubes"/"mundial_seleccion").
## Lote grande (~150 logos, varias planillas) — este primer pase solo
## incluye los que se pudieron verificar contra la planilla real uno por
## uno ("lento pero verificado", pedido de Wilber); el resto sigue con el
## logo procedural de siempre hasta la próxima pasada.
const _FIXED_DIR := "res://assets/complogos/fixed/"

## Set ESTÁTICO de ids con arte fijo (nombre exacto del .png en _FIXED_DIR,
## sin extensión). Antes esto se armaba escaneando la carpeta con
## DirAccess.list_dir_begin() en tiempo de ejecución — funciona perfecto en
## el editor/headless (archivos sueltos en disco) pero en el APK EXPORTADO
## devuelve 0 archivos siempre (los PNG importados no quedan listables por
## directorio dentro del .pck, solo cargables por `load()` directo) —
## reportado por Wilber jugando: los logos nuevos de liga/copa nunca se
## veían en el juego real, solo el procedural de siempre. Mismo patrón que
## ya usa Trophy.gd (FIXED_ART como dict estático) por la misma razón.
## Regenerar esta lista si se agregan/quitan archivos en _FIXED_DIR:
##   ls assets/complogos/fixed/*.png | xargs -n1 basename | sed 's/\.png$//'
const _FIXED_IDS := {
	"cont_AFC_1": true, "cont_CAF_1": true, "cont_CAF_2": true,
	"cont_CONCACAF_1": true, "cont_CONCACAF_2": true, "cont_CONCACAF_3": true,
	"cont_CONMEBOL_1": true, "cont_CONMEBOL_2": true,
	"cont_UEFA_1": true, "cont_UEFA_2": true, "cont_UEFA_3": true,
	"cup_generic_0": true, "cup_generic_1": true, "cup_generic_2": true,
	"cup_generic_3": true, "cup_generic_4": true, "cup_generic_5": true,
	"league_2": true, "league_3": true, "league_4": true, "league_5": true,
	"league_6": true, "league_7": true, "league_8": true, "league_9": true,
	"league_10": true, "league_11": true, "league_12": true, "league_13": true,
	"league_14": true, "league_15": true, "league_16": true, "league_17": true,
	"league_18": true, "league_19": true, "league_20": true, "league_21": true,
	"league_22": true, "league_23": true, "league_24": true, "league_25": true,
	"league_26": true, "league_27": true, "league_28": true, "league_29": true,
	"league_30": true, "league_31": true, "league_32": true, "league_33": true,
	"league_34": true, "league_35": true, "league_36": true, "league_37": true,
	"league_38": true, "league_39": true, "league_40": true, "league_41": true,
	"league_42": true, "league_43": true, "league_44": true, "league_45": true,
	"league_46": true, "league_60": true, "league_61": true, "league_62": true,
	"league_63": true, "league_64": true, "league_67": true, "league_68": true,
	"league_69": true, "league_70": true, "league_71": true,
	"mundial_clubes": true, "mundial_seleccion": true,
	"natcup_AFC": true, "natcup_CAF": true, "natcup_CONMEBOL": true,
	"supercopa_cont": true,
}

static func _has_fixed(id: String) -> bool:
	return _FIXED_IDS.has(id)

static func _fixed_node(id: String, px: int) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := TextureRect.new()
	r.texture = load(_FIXED_DIR + id + ".png")
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return root

static func league_node(league_id: int, px: int) -> Control:
	var id := "league_%d" % league_id
	if _has_fixed(id):
		return _fixed_node(id, px)
	var p: Array = PALETTE[absi(hash("lg:%d" % league_id)) % PALETTE.size()]
	return build(Color(p[0]), Color(p[1]), for_league(league_id), px)

const _CUP_GENERIC_COUNT := 6  # cup_generic_0..5.png -- plantillas reales de Wilber (sept-2026), sin arte por país todavía: se reparten determinista por país en vez de un logo único repetido para las 42 copas domésticas sin arte propio.

static func domestic_cup_node(country: String, px: int) -> Control:
	var specific_id := "dcup_" + country
	if _has_fixed(specific_id):
		return _fixed_node(specific_id, px)
	var generic_id := "cup_generic_%d" % (absi(hash("cupgeneric:" + country)) % _CUP_GENERIC_COUNT)
	if _has_fixed(generic_id):
		return _fixed_node(generic_id, px)
	var p: Array = PALETTE[absi(hash("cup:" + country)) % PALETTE.size()]
	return build(Color(p[0]), Color(p[1]), for_domestic_cup(country), px)

static func continental_node(confederation: String, tier: int, px: int) -> Control:
	var id := "cont_%s_%d" % [confederation, tier]
	if _has_fixed(id):
		return _fixed_node(id, px)
	var pair: Array = CONF_COLORS.get(confederation, PALETTE[0])
	var prim: Color = Color(pair[0])
	if tier >= 2:
		prim = prim.lightened(0.12 * float(tier - 1))
	return build(prim, Color(pair[1]), for_continental(confederation, tier), px)

# --- Constructor ---

static func build(primary: Color, secondary: Color, cfg: Dictionary, px: int) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shape: String = SHAPES[int(cfg.get("shape", 0)) % SHAPES.size()]
	var emblem: String = EMBLEMS[int(cfg.get("emblem", 0)) % EMBLEMS.size()]
	var accent: String = ACCENTS[int(cfg.get("accent", 0)) % ACCENTS.size()]

	var emb_tint: Color = secondary.lightened(0.5) if secondary.get_luminance() < 0.55 else secondary.darkened(0.35)

	_add(root, "shape_" + shape, primary)
	_add(root, "ring_" + shape, secondary)
	if accent != "none":
		_add(root, "acc_" + accent, Color(1, 1, 1, 0.92))
	_add(root, "emb_" + emblem, emb_tint)
	_add(root, "outline_" + shape, Color(0.10, 0.11, 0.14))
	return root

static func _add(root: Control, file: String, tint: Color) -> void:
	var path := _DIR + file + ".png"
	if not ResourceLoader.exists(path):
		return
	var r := TextureRect.new()
	r.texture = load(path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = tint
	root.add_child(r)
