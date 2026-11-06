extends RefCounted
class_name Trophy

## TROFEOS — arte ÚNICO en assets/trophies/v3 (PixelLab, 10-oct: 133
## trofeos hechos a partir del nombre de cada liga/copa/torneo/premio).
##
## 10-oct (Wilber: "me salen los trofeos viejos — eliminar contenido que no
## se usa para evitar conflictos"): se RETIRARON los tres sistemas
## anteriores (capas procedurales teñidas, "fixed" de sept-2026 y la tanda
## "w"). Convivían como fallback uno del otro y cualquier id que no
## estuviera en el mapa nuevo mostraba, en silencio, un trofeo antiguo. Los
## PNG viejos quedaron fuera del proyecto en art_src/_retired/trophies/.
## Ahora hay UN mapa (V3_ART) y, si un id no está, un genérico del MISMO
## arte nuevo (determinista por id). Cobertura: tools/TrophyV3Probe.
##
## Puertas de entrada:
##   for_entry(entry, px)  → una entrada de player.career_titles (la que
##                            hay que usar para dibujar un título ganado)
##   for_title(id, px)     → "league_<id>" / "dcup_<país>"
##   for_honor(id, px)     → premios y copas por id de familia
##   generic(key, px)      → trofeo cualquiera, determinista por clave

## Ids de premio/torneo con arte propio (antes eran las "recetas" de capas).
const HONOR_IDS := ["ballon_dor", "bota_oro", "max_goleador", "mvp_match", "mvp_liga", "mvp_temporada",
	"once_ideal", "continental_cup", "supercopa", "mundial_clubes", "mundial_seleccion", "copa_continental_seleccion"]

static var _cache: Dictionary = {}

const V3_ART := {
	"ballon_dor": "ballon_dor", "bota_oro": "bota_oro", "cont_AFC_1": "cont_AFC_1", "cont_AFC_2": "cont_AFC_2",
	"cont_AFC_3": "cont_AFC_3", "cont_CAF_1": "cont_CAF_1", "cont_CAF_2": "cont_CAF_2", "cont_CONCACAF_1": "cont_CONCACAF_1",
	"cont_CONCACAF_2": "cont_CONCACAF_2", "cont_CONCACAF_3": "cont_CONCACAF_3", "cont_CONMEBOL_1": "cont_CONMEBOL_1", "cont_CONMEBOL_2": "cont_CONMEBOL_2",
	"cont_UEFA_1": "cont_UEFA_1", "cont_UEFA_2": "cont_UEFA_2", "cont_UEFA_3": "cont_UEFA_3", "continental_cup": "continental_cup",
	"copa_continental_seleccion": "copa_continental_seleccion", "dcup_Alemania": "dcup_Alemania", "dcup_Arabia Saudita": "dcup_Arabia_Saudita", "dcup_Argentina": "dcup_Argentina",
	"dcup_Australia": "dcup_Australia", "dcup_Austria": "dcup_Austria", "dcup_Azerbaiyán": "dcup_Azerbaiyan", "dcup_Brasil": "dcup_Brasil",
	"dcup_Bélgica": "dcup_Belgica", "dcup_Chile": "dcup_Chile", "dcup_China": "dcup_China", "dcup_Chipre": "dcup_Chipre",
	"dcup_Colombia": "dcup_Colombia", "dcup_Corea del Sur": "dcup_Corea_del_Sur", "dcup_Costa Rica": "dcup_Costa_Rica", "dcup_Croacia": "dcup_Croacia",
	"dcup_Dinamarca": "dcup_Dinamarca", "dcup_Ecuador": "dcup_Ecuador", "dcup_Egipto": "dcup_Egipto", "dcup_Emiratos Árabes Unidos": "dcup_Emiratos_Arabes_Unidos",
	"dcup_Escocia": "dcup_Escocia", "dcup_España": "dcup_Espana", "dcup_Estados Unidos": "dcup_Estados_Unidos", "dcup_Francia": "dcup_Francia",
	"dcup_Ghana": "dcup_Ghana", "dcup_Grecia": "dcup_Grecia", "dcup_Honduras": "dcup_Honduras", "dcup_Hungría": "dcup_Hungria",
	"dcup_India": "dcup_India", "dcup_Inglaterra": "dcup_Inglaterra", "dcup_Irlanda": "dcup_Irlanda", "dcup_Italia": "dcup_Italia",
	"dcup_Japón": "dcup_Japon", "dcup_Marruecos": "dcup_Marruecos", "dcup_México": "dcup_Mexico", "dcup_Nigeria": "dcup_Nigeria",
	"dcup_Noruega": "dcup_Noruega", "dcup_Paraguay": "dcup_Paraguay", "dcup_Países Bajos": "dcup_Paises_Bajos", "dcup_Polonia": "dcup_Polonia",
	"dcup_Portugal": "dcup_Portugal", "dcup_República Checa": "dcup_Republica_Checa", "dcup_Rumania": "dcup_Rumania", "dcup_Rumanía": "dcup_Rumania", "dcup_Senegal": "dcup_Senegal",
	"dcup_Suecia": "dcup_Suecia", "dcup_Suiza": "dcup_Suiza", "dcup_Turquía": "dcup_Turquia", "dcup_Ucrania": "dcup_Ucrania",
	"dcup_Uruguay": "dcup_Uruguay", "league_10": "league_10", "league_11": "league_11", "league_12": "league_12",
	"league_13": "league_13", "league_14": "league_14", "league_15": "league_15", "league_16": "league_16",
	"league_17": "league_17", "league_18": "league_18", "league_19": "league_19", "league_2": "league_2",
	"league_20": "league_20", "league_21": "league_21", "league_22": "league_22", "league_23": "league_23",
	"league_24": "league_24", "league_25": "league_25", "league_26": "league_26", "league_27": "league_27",
	"league_28": "league_28", "league_29": "league_29", "league_3": "league_3", "league_30": "league_30",
	"league_31": "league_31", "league_32": "league_32", "league_33": "league_33", "league_34": "league_34",
	"league_35": "league_35", "league_36": "league_36", "league_37": "league_37", "league_38": "league_38",
	"league_39": "league_39", "league_4": "league_4", "league_40": "league_40", "league_41": "league_41",
	"league_42": "league_42", "league_43": "league_43", "league_44": "league_44", "league_45": "league_45",
	"league_46": "league_46", "league_5": "league_5", "league_6": "league_6", "league_60": "league_60",
	"league_61": "league_61", "league_62": "league_62", "league_63": "league_63", "league_64": "league_64",
	"league_67": "league_67", "league_68": "league_68", "league_69": "league_69", "league_7": "league_7",
	"league_70": "league_70", "league_71": "league_71", "league_8": "league_8", "league_9": "league_9",
	"max_goleador": "max_goleador", "mundial_clubes": "mundial_clubes", "mundial_seleccion": "mundial_seleccion", "mvp_liga": "mvp_liga",
	"mvp_temporada": "mvp_temporada", "natcup_AFC": "natcup_AFC", "natcup_CAF": "natcup_CAF", "natcup_CONCACAF": "natcup_CONCACAF",
	"natcup_CONMEBOL": "natcup_CONMEBOL", "natcup_UEFA": "natcup_UEFA", "once_ideal": "once_ideal", "supercopa": "supercopa",
	"supercopa_cont": "supercopa_cont", "mvp_match": "mvp_liga",
}

const _V3_DIR := "res://assets/trophies/v3/"

static func _v3_node(id: String, px: int) -> Control:
	if not V3_ART.has(id):
		return null
	var key := "v3:" + id
	if not _cache.has(key):
		var p := _V3_DIR + String(V3_ART[id]) + ".png"
		_cache[key] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	if _cache[key] == null:
		return null
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := TextureRect.new()
	r.texture = _cache[key]
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	root.set_meta("trophy_id", id) # para su versión 3D (TrophyViewer)
	# Tocarlo (sin arrastrar: puede ser el scroll de la lista) lo abre en 3D y en grande
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.gui_input.connect(func(e: InputEvent) -> void:
		var touch: bool = e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT)
		if not touch:
			return
		if e.pressed:
			root.set_meta("press_at", e.position)
		elif root.has_meta("press_at") and (root.get_meta("press_at") as Vector2).distance_to(e.position) < 14.0:
			root.remove_meta("press_at")
			TrophyViewer.open_closeup(root, id, String(root.get_meta("title", ""))))
	return root

## Familia a la que cae un id específico sin arte propio.
static func _family_fallback(honor_id: String) -> String:
	if honor_id.begins_with("cont_"):
		return "continental_cup"
	if honor_id.begins_with("natcup_"):
		return "copa_continental_seleccion"
	if honor_id == "supercopa_cont":
		return "supercopa"
	return honor_id

## Trofeo genérico del arte nuevo, determinista por clave. `kind`:
## "league" (ligas), cualquier otra cosa = copas domésticas.
static var _generic_pools: Dictionary = {}
static func generic(seed_key: String, px: int, kind: String = "cup") -> Control:
	var prefix: String = "league_" if kind == "league" else "dcup_"
	if not _generic_pools.has(prefix):
		var pool: Array = []
		for k in V3_ART:
			if String(k).begins_with(prefix):
				pool.append(k)
		pool.sort()
		_generic_pools[prefix] = pool
	var ids: Array = _generic_pools[prefix]
	var node: Control = _v3_node(String(ids[absi(hash("generic:" + seed_key)) % ids.size()]), px) if not ids.is_empty() else null
	if node == null:
		node = Control.new()
		node.custom_minimum_size = Vector2(px, px)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

## Trofeo de un TÍTULO (liga/copa doméstica): "league_<id>" / "dcup_<país>".
## `metal` se conserva en la firma por compatibilidad (el arte ya trae el suyo).
static func for_title(id: String, px: int, _metal: int = 1) -> Control:
	var v3 := _v3_node(id, px)
	if v3 != null:
		return v3
	return generic(id, px, "league" if id.begins_with("league_") else "cup")

## Trofeo de una ENTRADA del gabinete (player.career_titles). ÚNICA puerta
## para dibujar un título ganado: traduce el id crudo ("botaoro_3",
## "once_ideal_3", "ballon_dor_podio"...) a su familia con arte
## (HonorsEngine.trophy_key_for). Bug real (10-oct, Wilber: "me salen los
## trofeos viejos"): la sala de trofeos del Perfil llamaba a for_title con
## el id crudo y caía al trofeo procedural antiguo.
static func for_entry(entry: Dictionary, px: int) -> Control:
	var honor_key: String = HonorsEngine.trophy_key_for(entry)
	if honor_key != "":
		return for_honor(honor_key, px)
	return for_title(String(entry.get("id", "")), px, int(entry.get("metal", 1)))

static func for_honor(honor_id: String, px: int = 56) -> Control:
	var v3 := _v3_node(honor_id, px)
	if v3 == null:
		v3 = _v3_node(_family_fallback(honor_id), px)
	if v3 != null:
		return v3
	return generic(honor_id, px)

## Trofeo de una competición sin id propio ("league" / "cup" / ...).
static func for_competition(comp_key: String, _metal: int = 1, px: int = 56) -> Control:
	return generic(comp_key, px, "league" if comp_key == "league" else "cup")
