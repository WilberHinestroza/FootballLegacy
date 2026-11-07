extends RefCounted
class_name Avatar

## Avatares de jugador en PIXEL ART por capas (9-oct, reemplaza al Kenney
## Avatar Mixer — copia del sistema viejo en art_src/legacy_kenney/).
##
## Todo sale de UN sprite base de 48×48 (el personaje "Pixel art 2D sports
## game" de Wilber en PixelLab, vista de frente) + piezas generadas sobre
## ESE mismo sprite (ropa, peinados, barba, accesorios), así que todas
## calzan al píxel. tools/pixel_layers.py las separa en
## assets/pixelplayer/<grupo>/<id>.png (color) + <id>_m.png (máscara:
## R = clase del píxel, G = luminancia para teñir). Ver la cabecera de ese
## script para regenerarlas.
##
## Igual que antes: nadie se pre-genera — cada jugador/NPC arma el suyo
## DETERMINISTA por nombre + world_seed. El usuario lo edita en
## AvatarCreator (PlayerData.avatar) y se viste en la Tienda
## (PlayerData.cosmetics_equipped, schema v31).
##
## Config (v2): {"v": 2, "hair": id, "face": id|"", "outfit": id|"",
##   "acc_neck"/"acc_wrist"/"acc_ears"/"acc_eyes"/"acc_head": id|"",
##   "tint_<key>": "#rrggbb", "clothing_locked": bool, "full": bool}.
## "full" = cuerpo entero (si no, busto cabeza+hombros, que es lo que
## muestran casi todas las pantallas).

const _DIR := "res://assets/pixelplayer/"
const SPRITE_PX := 48
## Recorte del busto (cabeza + hombros) dentro del sprite de 48×48.
const BUST_RECT := Rect2i(10, 0, 28, 28)

## Clases de la máscara (canal R de <id>_m.png, ver tools/pixel_layers.py).
const MASK_SKIN := 1
const MASK_HAIR := 2
const MASK_SHIRT := 3
const MASK_SHORTS := 4
const MASK_SOCKS := 5
## Botines de las ANIMACIONES (tools/anim_boots.py): se tiñen con los guayos
## equipados — así se ven en la cancha y en los festejos, no solo en el
## cuerpo entero quieto.
const MASK_BOOTS := 7
const GUAYOS_TINT := {
	"guayos_verde": "#3ee03a", "guayos_oro": "#e8b923", "guayos_negro": "#2b2b30",
	"guayos_rosa": "#ff4fa3", "guayos_blanco": "#e9eef6",
	"guayos_azul": "#2e7bff", "guayos_morado": "#8a3cff", "guayos_rojo": "#e3262f", "guayos_arcoiris": "#ffb21a",
	"guayos_plata": "#c9ced8", "guayos_lava": "#ff6a1a",
	"guayos_tormenta": "#2e7bff", "guayos_galaxia": "#5a1fd1", "guayos_tigre": "#ff8a00",
	"guayos_camo": "#5a6b35", "guayos_fuego": "#ff8a1a", "guayos_hielo": "#4fd1ff",
	"guayos_neon": "#39ff14", "guayos_dos_caras": "#e3262f",
	"guayos_voltaje": "#ffe600",
	"guayos_dragon": "#b3121b",
	"guayos_grafiti": "#121214",
	"guayos_marmol": "#f2f2f0",
	"guayos_oceano": "#0a5fa8",
	"guayos_aurora": "#062a2a",
	"guayos_ajedrez": "#141414",
	"guayos_cobra": "#1f6b2a",
	"guayos_pantera": "#5a1fd1",
	"guayos_atardecer": "#ff7a1a",
	"guayos_glaciar": "#dff4ff",
	"guayos_bosque": "#1e5c2e",
	"guayos_confeti": "#f4f4f4",
}

const HAIR_STYLES := [
	{"id": "rapado", "label": "Rapado"},
	{"id": "tupe", "label": "Tupé"},
	{"id": "rulos", "label": "Rulos"},
	{"id": "melena", "label": "Melena"},
	{"id": "cresta", "label": "Cresta"},
	{"id": "largo", "label": "Largo"},
	{"id": "mono", "label": "Moño"},
	{"id": "trenzas", "label": "Trenzas"},
	{"id": "rastas", "label": "Rastas"},
	{"id": "engominado", "label": "Engominado"},
	# 9-oct (pedido de Wilber: "más peinados")
	{"id": "afro", "label": "Afro"},
	{"id": "calvo", "label": "Calvo"},
	{"id": "flequillo", "label": "Flequillo"},
	{"id": "coleta", "label": "Coleta"},
	{"id": "puntas", "label": "De punta"},
	{"id": "degradado", "label": "Degradado"},
	{"id": "rizos_largos", "label": "Rizos largos"},
	{"id": "raya", "label": "Raya al costado"},
]
## Sorteo EXTRA de peinados nuevos para los NPC (rng aparte en
## random_config, así las caras que ya existían no cambian).
const RANDOM_HAIR_NEW := ["afro", "flequillo", "puntas", "degradado", "degradado", "raya", "calvo", "coleta"]

## Rasgos de la cara (9-oct): grupos de capa propios, debajo del pelo.
const NOSES := [
	{"id": "", "label": "Normal"},
	{"id": "grande", "label": "Grande"},
	{"id": "aguilena", "label": "Aguileña"},
	{"id": "chata", "label": "Chata"},
]
const EARS := [
	{"id": "", "label": "Normales"},
	{"id": "grandes", "label": "Grandes"},
]
const RASGOS := [
	{"id": "", "label": "Ninguno"},
	{"id": "mandibula", "label": "Mandíbula cuadrada"},
	{"id": "redonda", "label": "Cara redonda"},
	{"id": "pecas", "label": "Pecas"},
	{"id": "cejas", "label": "Cejas gruesas"},
	{"id": "cicatriz", "label": "Cicatriz"},
]
## Sorteo de los jugadores/NPC: el largo queda solo para el editor (mismo
## criterio que el filtro de melenas largas del pack viejo, pedido de
## Wilber), el rapado pesa doble porque es el corte más futbolero.
const RANDOM_HAIR := ["rapado", "rapado", "tupe", "rulos", "melena", "cresta", "rastas", "trenzas"]

const FACE_STYLES := [
	{"id": "", "label": "Sin barba"},
	{"id": "barba", "label": "Barba"},
	{"id": "barba3", "label": "Barba de 3 días"},
	{"id": "candado", "label": "Candado"},
	{"id": "bigote", "label": "Bigote"},
	{"id": "barba_larga", "label": "Barba larga"},
]
const RANDOM_FACES := ["barba", "barba", "barba3", "barba3", "candado", "bigote", "barba_larga"]

## Ropa de calle: reemplaza el kit entero. Se compra en la Tienda (precio
## en ShopEngine.COSMETIC_PRICE).
const OUTFITS := [
	{"id": "hoodie", "label": "Hoodie gris"},
	{"id": "jeans", "label": "Remera negra y jeans rotos"},
	{"id": "polo", "label": "Polo rojo"},
	{"id": "chandal", "label": "Chándal azul"},
	{"id": "hawaiana", "label": "Camisa hawaiana"},
	{"id": "lino", "label": "Conjunto de lino"},
	{"id": "bomber", "label": "Bomber verde"},
	{"id": "vaquera", "label": "Chaqueta vaquera"},
	{"id": "universitaria", "label": "Chaqueta universitaria"},
	{"id": "camisa_vestir", "label": "Camisa de vestir"},
	{"id": "cuello_alto", "label": "Suéter de cuello alto"},
	{"id": "plumifero", "label": "Plumífero negro"},
	{"id": "cuero", "label": "Chaqueta de cuero"},
	{"id": "abrigo", "label": "Abrigo largo camel"},
	{"id": "traje_azul", "label": "Traje azul"},
	{"id": "traje_negro", "label": "Traje negro"},
	{"id": "smoking_blanco", "label": "Smoking blanco"},
	# 9-oct
	{"id": "franela", "label": "Camisa a cuadros"},
	{"id": "chaleco", "label": "Chaleco acolchado"},
	{"id": "oversize", "label": "Remera oversize con cadena"},
	{"id": "traje_gris", "label": "Traje gris de tres piezas"},
	{"id": "retro", "label": "Chándal retro rojo"},
	{"id": "seda", "label": "Camisa de seda barroca"},
	{"id": "hoodie_negro", "label": "Hoodie negro"},
	# 10-oct (Wilber: "más tipos de ropa... camisetas, pantalones,
	# chaquetas, zapatos de salir"): conjuntos con camisa/pantalón/chaqueta.
	{"id": "camisa_chinos", "label": "Camisa blanca y chinos"},
	{"id": "gabardina", "label": "Gabardina beige"},
	{"id": "parka_roja", "label": "Parka roja y cargo"},
	{"id": "blazer_terciopelo", "label": "Blazer de terciopelo"},
	{"id": "cortavientos", "label": "Cortavientos y joggers"},
	# Ediciones DORADAS: se ganan con logros (GoldEditions), no se compran.
	{"id": "traje_oro", "label": "Traje dorado", "gold": true},
	{"id": "chandal_oro", "label": "Chándal dorado", "gold": true},
	{"id": "bomber_oro", "label": "Bomber dorada", "gold": true},
	{"id": "polo_oro", "label": "Polo dorado", "gold": true},
	{"id": "cuero_oro", "label": "Campera de cuero dorada", "gold": true},
]

## Accesorios: uno por `slot` (se pueden combinar entre slots).
const ACCESSORIES := [
	{"id": "cinta", "label": "Cinta deportiva", "slot": "acc_head"},
	{"id": "gorra", "label": "Gorra negra", "slot": "acc_head"},
	{"id": "gorro_lana", "label": "Gorro de lana", "slot": "acc_head"},
	{"id": "lentes_sol", "label": "Lentes de sol", "slot": "acc_eyes"},
	{"id": "aviador", "label": "Lentes de aviador", "slot": "acc_eyes"},
	{"id": "auriculares", "label": "Auriculares", "slot": "acc_neck"},
	{"id": "cadena_fina", "label": "Cadena fina de oro", "slot": "acc_neck"},
	{"id": "cadena_gruesa", "label": "Cadena gruesa de oro", "slot": "acc_neck"},
	{"id": "pendientes", "label": "Pendientes de diamante", "slot": "acc_ears"},
	{"id": "reloj", "label": "Reloj de oro", "slot": "acc_wrist"},
	{"id": "guayos_verde", "label": "Guayos verde flúor", "slot": "acc_feet"},
	{"id": "guayos_oro", "label": "Guayos dorados", "slot": "acc_feet"},
	{"id": "guayos_negro", "label": "Guayos negro y rojo", "slot": "acc_feet"},
	{"id": "guayos_rosa", "label": "Guayos rosa y naranja", "slot": "acc_feet"},
	{"id": "guayos_blanco", "label": "Guayos blanco y azul", "slot": "acc_feet"},
	{"id": "guayos_azul", "label": "Guayos azul eléctrico", "slot": "acc_feet"},
	{"id": "guayos_morado", "label": "Guayos morado y plata", "slot": "acc_feet"},
	{"id": "guayos_rojo", "label": "Guayos rojo fuego", "slot": "acc_feet"},
	{"id": "guayos_arcoiris", "label": "Guayos arcoíris", "slot": "acc_feet"},
	# 10-oct: guayos nuevos + zapatos de salir (mismo slot de pies) +
	# bufanda, boina y lentes redondos.
	{"id": "guayos_plata", "label": "Guayos plateados", "slot": "acc_feet"},
	{"id": "guayos_lava", "label": "Guayos lava", "slot": "acc_feet"},
	# 7-nov: guayos con diseños locos (marcas inventadas, BootBrands)
	{"id": "guayos_tormenta", "label": "Guayos tormenta", "slot": "acc_feet"},
	{"id": "guayos_galaxia", "label": "Guayos galaxia", "slot": "acc_feet"},
	{"id": "guayos_tigre", "label": "Guayos tigre", "slot": "acc_feet"},
	{"id": "guayos_camo", "label": "Guayos camuflaje", "slot": "acc_feet"},
	{"id": "guayos_fuego", "label": "Guayos fuego", "slot": "acc_feet"},
	{"id": "guayos_hielo", "label": "Guayos hielo", "slot": "acc_feet"},
	{"id": "guayos_neon", "label": "Guayos neón", "slot": "acc_feet"},
	{"id": "guayos_dos_caras", "label": "Guayos dos caras", "slot": "acc_feet"},
	{"id": "guayos_voltaje", "label": "Guayos voltaje", "slot": "acc_feet"},
	{"id": "guayos_dragon", "label": "Guayos dragón", "slot": "acc_feet"},
	{"id": "guayos_grafiti", "label": "Guayos grafiti", "slot": "acc_feet"},
	{"id": "guayos_marmol", "label": "Guayos mármol", "slot": "acc_feet"},
	{"id": "guayos_oceano", "label": "Guayos océano", "slot": "acc_feet"},
	{"id": "guayos_aurora", "label": "Guayos aurora", "slot": "acc_feet"},
	{"id": "guayos_ajedrez", "label": "Guayos ajedrez", "slot": "acc_feet"},
	{"id": "guayos_cobra", "label": "Guayos cobra", "slot": "acc_feet"},
	{"id": "guayos_pantera", "label": "Guayos pantera", "slot": "acc_feet"},
	{"id": "guayos_atardecer", "label": "Guayos atardecer", "slot": "acc_feet"},
	{"id": "guayos_glaciar", "label": "Guayos glaciar", "slot": "acc_feet"},
	{"id": "guayos_bosque", "label": "Guayos bosque", "slot": "acc_feet"},
	{"id": "guayos_confeti", "label": "Guayos confeti", "slot": "acc_feet"},
	# Zapatos de CALLE: slot propio (10-oct, Wilber: "los guayos son
	# diferentes a los zapatos para ropa"). Se ven con ropa de calle; los
	# guayos (acc_feet) se ven con el kit.
	{"id": "zapatillas_blancas", "label": "Zapatillas blancas", "slot": "acc_shoes"},
	{"id": "mocasines", "label": "Mocasines de cuero", "slot": "acc_shoes"},
	{"id": "botas_chelsea", "label": "Botas chelsea", "slot": "acc_shoes"},
	{"id": "bufanda", "label": "Bufanda de lana", "slot": "acc_neck"},
	{"id": "boina", "label": "Boina de tweed", "slot": "acc_head"},
	{"id": "lentes_redondos", "label": "Lentes redondos", "slot": "acc_eyes"},
]
## Orden de dibujo de los slots (de atrás hacia adelante).
const ACC_SLOTS := ["acc_feet", "acc_shoes", "acc_neck", "acc_wrist", "acc_ears", "acc_eyes", "acc_head"]

## PRENDAS SUELTAS (10-oct, Wilber: "separar camisas, chaquetas, pantalones
## y zapatos en la tienda"). Cada conjunto de OUTFITS se partió en su parte
## de arriba y su pantalón (tools/split_outfits.py → assets/pixelplayer/
## top/ y bottom/) y se combinan libremente. `src` = id del conjunto del
## que sale el arte. Ids de tienda: "top_<src>" (slot "top") y "bot_<src>"
## (slot "bottom"). Quien ya tenía el conjunto entero tiene las dos piezas
## (ver owns()). `cat`: "camisa" | "chaqueta".
const TOPS := [
	{"src": "jeans", "label": "Remera negra", "cat": "camisa"},
	{"src": "oversize", "label": "Remera oversize con cadena", "cat": "camisa"},
	{"src": "polo", "label": "Polo rojo", "cat": "camisa"},
	{"src": "camisa_chinos", "label": "Camisa blanca", "cat": "camisa"},
	{"src": "camisa_vestir", "label": "Camisa celeste", "cat": "camisa"},
	{"src": "franela", "label": "Camisa a cuadros", "cat": "camisa"},
	{"src": "hawaiana", "label": "Camisa hawaiana", "cat": "camisa"},
	{"src": "lino", "label": "Camisa de lino", "cat": "camisa"},
	{"src": "seda", "label": "Camisa de seda barroca", "cat": "camisa"},
	{"src": "cuello_alto", "label": "Suéter de cuello alto", "cat": "camisa"},
	{"src": "polo_oro", "label": "Polo dorado", "cat": "camisa"},
	{"src": "hoodie", "label": "Hoodie gris", "cat": "chaqueta"},
	{"src": "hoodie_negro", "label": "Hoodie negro", "cat": "chaqueta"},
	{"src": "chandal", "label": "Campera de chándal azul", "cat": "chaqueta"},
	{"src": "retro", "label": "Campera retro roja", "cat": "chaqueta"},
	{"src": "cortavientos", "label": "Cortavientos", "cat": "chaqueta"},
	{"src": "bomber", "label": "Bomber verde", "cat": "chaqueta"},
	{"src": "vaquera", "label": "Chaqueta vaquera", "cat": "chaqueta"},
	{"src": "universitaria", "label": "Chaqueta universitaria", "cat": "chaqueta"},
	{"src": "chaleco", "label": "Chaleco acolchado", "cat": "chaqueta"},
	{"src": "plumifero", "label": "Plumífero negro", "cat": "chaqueta"},
	{"src": "parka_roja", "label": "Parka roja", "cat": "chaqueta"},
	{"src": "cuero", "label": "Chaqueta de cuero", "cat": "chaqueta"},
	{"src": "blazer_terciopelo", "label": "Blazer de terciopelo", "cat": "chaqueta"},
	{"src": "abrigo", "label": "Abrigo largo camel", "cat": "chaqueta"},
	{"src": "gabardina", "label": "Gabardina beige", "cat": "chaqueta"},
	{"src": "traje_azul", "label": "Saco azul", "cat": "chaqueta"},
	{"src": "traje_gris", "label": "Saco gris con chaleco", "cat": "chaqueta"},
	{"src": "traje_negro", "label": "Saco negro", "cat": "chaqueta"},
	{"src": "smoking_blanco", "label": "Saco de smoking blanco", "cat": "chaqueta"},
	{"src": "traje_oro", "label": "Saco dorado", "cat": "chaqueta"},
	{"src": "chandal_oro", "label": "Campera dorada", "cat": "chaqueta"},
	{"src": "bomber_oro", "label": "Bomber dorada", "cat": "chaqueta"},
	{"src": "cuero_oro", "label": "Campera de cuero dorada", "cat": "chaqueta"},
]
const BOTTOMS := [
	{"src": "jeans", "label": "Jeans rotos"},
	{"src": "cuero", "label": "Jeans azul oscuro"},
	{"src": "franela", "label": "Jeans oscuros"},
	{"src": "universitaria", "label": "Jeans negros"},
	{"src": "camisa_chinos", "label": "Chinos beige"},
	{"src": "oversize", "label": "Cargo caqui"},
	{"src": "bomber", "label": "Cargo negro"},
	{"src": "hawaiana", "label": "Bermuda beige"},
	{"src": "hoodie", "label": "Jogger gris"},
	{"src": "hoodie_negro", "label": "Jogger negro"},
	{"src": "cortavientos", "label": "Jogger gris claro"},
	{"src": "chandal", "label": "Pantalón de chándal azul"},
	{"src": "retro", "label": "Pantalón retro rojo"},
	{"src": "lino", "label": "Pantalón de lino blanco"},
	{"src": "camisa_vestir", "label": "Pantalón azul con cinturón"},
	{"src": "cuello_alto", "label": "Pantalón gris"},
	{"src": "traje_azul", "label": "Pantalón de traje azul"},
	{"src": "traje_gris", "label": "Pantalón de traje gris"},
	{"src": "traje_negro", "label": "Pantalón de traje negro"},
	{"src": "traje_oro", "label": "Pantalón dorado"},
	{"src": "chandal_oro", "label": "Jogger dorado"},
]
## Conjuntos cuyo "pantalón" no sirve suelto (abrigos largos: arrastra el
## faldón) → qué pantalón usar en su lugar.
const _BOTTOM_ALIAS := {"abrigo": "camisa_vestir", "gabardina": "cuello_alto"}
## Gorros que tapan el peinado (se dibujan sobre la cabeza rapada).
const HAT_IDS := ["gorra", "gorro_lana", "boina"]
## Accesorios que van en la cabeza (siguen a la cabeza en las animaciones).
const _HEAD_ACC := {"cinta": true, "gorra": true, "gorro_lana": true, "lentes_sol": true, "aviador": true, "pendientes": true,
	"boina": true, "lentes_redondos": true}

## Partes teñibles + su paleta (hex). Mismas claves que el sistema viejo
## para "base"/"hair"/"clothing"/"background" (WorldFactory usa la paleta
## de "base" para la columna "skin" del import).
const TINTS := {
	"base": {
		"label": "Piel",
		"palette": ["#f4d6c0", "#eec1a3", "#d9a577", "#b57e56", "#8a5a3b", "#5f3a26"],
	},
	"hair": {
		"label": "Pelo",
		"palette": ["#2b2320", "#5a3b26", "#8a5a3b", "#c98f4b", "#d8c07a", "#9a9a9a", "#e8e8e8", "#3f6fb0"],
	},
	"clothing": {
		"label": "Camiseta",
		"palette": ["#e8e8e8", "#2b2b2b", "#c0392b", "#2e6fb0", "#27924f", "#e0b422", "#7a4bb0", "#d05a8a"],
	},
	"shorts": {
		"label": "Short",
		"palette": ["#f0f0f0", "#2b2b2b", "#1a2b40", "#c0392b", "#2e6fb0", "#27924f"],
	},
	"background": {
		"label": "Fondo",
		"palette": ["#9fc7e8", "#a7dfc5", "#f2c9a0", "#e8b0c4", "#c9b8e8", "#dfe0a0", "#c7c7c7", "#7fb0d8"],
	},
}
const RANDOM_TINT_KEYS := ["base", "hair", "clothing", "shorts", "background"]

## Colores del club actual del usuario (hex "#rrggbb"), los setea
## WorldTickEngine.load_runtime() en cada carga: camiseta = primario,
## short = secundario. El usuario viste el kit de su club salvo que haya
## fijado los colores a mano en el editor (`clothing_locked`).
static var user_kit_hex: String = ""
static var user_kit2_hex: String = ""
## Diseño de camiseta del club (plantilla de Wilber, KitTemplates; -1 =
## liso) + su color secundario — así tu jugador VISTE las rayas/cuadros del
## kit de esta temporada (9-oct).
static var user_kit_w: int = -1
static var user_kit_sec_hex: String = ""
## Club del usuario (lo pone WorldTickEngine._sync_user_kit_tint) para el escudo
## y el patrocinio estampados en la camiseta 3D.
static var user_kit_club: String = ""

static var _img_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}
const _TEX_CACHE_MAX := 400

# --- Catálogo ----------------------------------------------------------

static func outfit_by_id(id: String) -> Dictionary:
	for o in OUTFITS:
		if o["id"] == id:
			return o
	return {}

static func accessory_by_id(id: String) -> Dictionary:
	for a in ACCESSORIES:
		if a["id"] == id:
			return a
	return {}

## Conjunto del que sale una prenda suelta ("top_hoodie" → "hoodie"), o "".
static func piece_src(cosmetic_id: String) -> String:
	if cosmetic_id.begins_with("top_") or cosmetic_id.begins_with("bot_"):
		var src: String = cosmetic_id.substr(4)
		return src if not outfit_by_id(src).is_empty() else ""
	return ""

## Pantalón que corresponde a un conjunto entero (para vestir sus dos
## mitades): el suyo, o el alias si es un abrigo largo.
static func bottom_src_for(outfit_id: String) -> String:
	return String(_BOTTOM_ALIAS.get(outfit_id, outfit_id))

## Slot de un cosmético de la Tienda: "top"/"bottom" para prendas sueltas,
## "outfit" para un conjunto entero (regalos y ediciones doradas), el slot
## de accesorio si no. "" = id desconocido.
static func slot_of(cosmetic_id: String) -> String:
	if piece_src(cosmetic_id) != "":
		return "top" if cosmetic_id.begins_with("top_") else "bottom"
	if not outfit_by_id(cosmetic_id).is_empty():
		return "outfit"
	return String(accessory_by_id(cosmetic_id).get("slot", ""))

static func label_of(cosmetic_id: String) -> String:
	var src: String = piece_src(cosmetic_id)
	if src != "":
		for it in (TOPS if cosmetic_id.begins_with("top_") else BOTTOMS):
			if String(it["src"]) == src:
				return String(it["label"])
		return ("Parte de arriba" if cosmetic_id.begins_with("top_") else "Pantalón")
	var o := outfit_by_id(cosmetic_id)
	if not o.is_empty():
		return String(o["label"])
	return String(accessory_by_id(cosmetic_id).get("label", cosmetic_id))

## ¿El jugador tiene este cosmético? Una prenda suelta también se tiene si
## se tiene el CONJUNTO entero del que sale (compras de antes de separar la
## tienda, regalos del patrocinador y ediciones doradas).
static func owns(player: PlayerData, cosmetic_id: String) -> bool:
	if player == null:
		return false
	if player.cosmetics_owned.has(cosmetic_id):
		return true
	var src: String = piece_src(cosmetic_id)
	if src == "":
		return false
	if player.cosmetics_owned.has(src):
		return true
	# El pantalón "prestado" de un abrigo largo.
	if cosmetic_id.begins_with("bot_"):
		for k in _BOTTOM_ALIAS:
			if String(_BOTTOM_ALIAS[k]) == src and player.cosmetics_owned.has(k):
				return true
	return false

## Sin ropa de calle: lo que se usa en la cancha (kit del club).
static func strip_street(cfg: Dictionary) -> void:
	for k in ["outfit", "top", "bottom", "acc_shoes"]:
		cfg.erase(k)

static func wears_street(cfg: Dictionary) -> bool:
	return String(cfg.get("outfit", "")) != "" or String(cfg.get("top", "")) != "" or String(cfg.get("bottom", "")) != ""

# --- Configs -----------------------------------------------------------

static func random_config(seed_int: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_int)
	var cfg: Dictionary = {"v": 2}
	cfg["hair"] = RANDOM_HAIR[rng.randi() % RANDOM_HAIR.size()]
	cfg["face"] = String(RANDOM_FACES[rng.randi() % RANDOM_FACES.size()]) if rng.randf() < 0.40 else ""
	for key in RANDOM_TINT_KEYS:
		var pal: Array = TINTS[key]["palette"]
		cfg["tint_" + key] = String(pal[rng.randi() % pal.size()])
	if rng.randf() < 0.06:
		cfg["acc_head"] = "cinta"
	# Rasgos/peinados nuevos (9-oct) con un rng APARTE: los sorteos de
	# arriba quedan idénticos → las caras que ya veías no cambian.
	var r2 := RandomNumberGenerator.new()
	r2.seed = absi(seed_int) ^ 0x2C9E7F31
	if r2.randf() < 0.30:
		cfg["hair"] = RANDOM_HAIR_NEW[r2.randi() % RANDOM_HAIR_NEW.size()]
	if r2.randf() < 0.35:
		cfg["nose"] = String(NOSES[1 + r2.randi() % (NOSES.size() - 1)]["id"])
	if r2.randf() < 0.15:
		cfg["ears"] = "grandes"
	if r2.randf() < 0.30:
		cfg["rasgo"] = String(RASGOS[1 + r2.randi() % (RASGOS.size() - 1)]["id"])
	return cfg

## Convierte un config del sistema viejo (Kenney: índices de archivo por
## capa) a v2, conservando los tintes de piel/pelo/ropa/fondo — que es lo
## que más identifica a la cara. El peinado se mapea por índice (no hay
## equivalencia 1 a 1 entre los 38 del pack y los 6 de acá). Lo usa la
## migración v30→v31 (SaveManager) y, por las dudas, config_for_player.
static func from_legacy(old: Dictionary) -> Dictionary:
	if int(old.get("v", 1)) >= 2 or not _looks_kenney(old):
		return old.duplicate(true)
	var cfg: Dictionary = {"v": 2}
	var hair_idx: int = int(old.get("hair", 0))
	cfg["hair"] = "rapado" if hair_idx <= 0 else String(RANDOM_HAIR[hair_idx % RANDOM_HAIR.size()])
	cfg["face"] = "barba" if int(old.get("facial", 0)) > 0 else ""
	for key in ["base", "hair", "clothing", "background"]:
		if old.has("tint_" + key):
			cfg["tint_" + key] = String(old["tint_" + key])
	if bool(old.get("clothing_locked", false)):
		cfg["clothing_locked"] = true
	if old.has("skin"):
		cfg["skin"] = old["skin"]
	return cfg

## Un config es del sistema VIEJO (Kenney) solo si lo parece de verdad:
## peinado como ÍNDICE numérico o claves propias del pack ("base", "facial").
## Antes cualquier config sin "v": 2 se "convertía" y perdía sus piezas
## (visto en captura real, 9-oct: pelo/barba/guayos desaparecían).
static func _looks_kenney(cfg: Dictionary) -> bool:
	var h = cfg.get("hair", null)
	return cfg.has("base") or cfg.has("facial") or h is int or h is float

static func _is_full_config(cfg: Dictionary) -> bool:
	return cfg.has("hair") or cfg.has("base")

## Config de un jugador:
##  - avatar COMPLETO (del creador) → tal cual (convertido si es viejo).
##  - solo `{"skin": N}` (columna del import) → determinista + override
##    del tinte de piel.
##  - {} → todo determinista por nombre + país + world_seed.
## Encima, la ropa/accesorios que tenga puestos (cosmetics_equipped).
static func config_for_player(player: PlayerData, world_seed: int) -> Dictionary:
	if player == null:
		return random_config(world_seed)
	var cfg: Dictionary
	if player.avatar is Dictionary and _is_full_config(player.avatar):
		cfg = from_legacy(player.avatar)
	else:
		cfg = random_config(hash(player.player_name) ^ world_seed ^ hash(player.country))
		if player.avatar is Dictionary and player.avatar.has("skin"):
			var n: int = int(player.avatar["skin"])
			var pal: Array = TINTS["base"]["palette"]
			if n >= 0 and n < pal.size():
				cfg["tint_base"] = String(pal[n])
	var eq: Dictionary = player.cosmetics_equipped
	var split: bool = String(eq.get("top", "")) != "" or String(eq.get("bottom", "")) != ""
	for slot in eq:
		var id: String = String(eq[slot])
		if id == "" or not owns(player, id):
			continue
		match String(slot):
			"top", "bottom":
				cfg[String(slot)] = piece_src(id)
			"outfit":
				# Conjunto entero: solo si no hay prendas sueltas puestas.
				if not split:
					cfg["outfit"] = id
			_:
				# El slot sale del CATÁLOGO, no del guardado: unos zapatos de
				# calle guardados en "acc_feet" (antes de separar el slot)
				# caen solos en "acc_shoes".
				var real_slot: String = slot_of(id)
				cfg[real_slot if real_slot != "" else String(slot)] = id
	# ARRUGAS desde los 33 (P6: "tu retrato envejeciendo").
	if player.age >= 33:
		cfg["age"] = "arrugas"
	# CANAS con la edad (P3, 9-oct): desde los 31 el pelo (y la barba, que
	# usa el mismo tinte) va virando a gris; a los 38 ya es casi todo gris.
	if player.age >= 31:
		var t: float = clampf(float(player.age - 30) / 8.0, 0.0, 0.85)
		var hc := Color(String(cfg.get("tint_hair", "#2b2320")))
		var gray := Color(0.78, 0.78, 0.80)
		cfg["tint_hair"] = "#" + hc.lerp(gray, t).to_html(false)
	cfg = _apply_kit_tint(cfg)
	if cfg.has("kit_club"):
		cfg["kit_num"] = Kit.suggested_number(player.position, "%s|%d" % [player.player_name, world_seed])
		var words: PackedStringArray = player.player_name.split(" ", false)
		cfg["kit_name"] = words[words.size() - 1] if words.size() > 0 else ""
	return cfg

## Viste el kit con los colores del club actual (user_kit_hex /
## user_kit2_hex). Respeta `clothing_locked` (colores elegidos a mano).
static func _apply_kit_tint(cfg: Dictionary) -> Dictionary:
	if bool(cfg.get("clothing_locked", false)):
		return cfg
	if user_kit_hex != "":
		cfg["tint_clothing"] = user_kit_hex
	if user_kit2_hex != "":
		cfg["tint_shorts"] = user_kit2_hex
	if user_kit_w >= 0 and String(cfg.get("outfit", "")) == "" and String(cfg.get("top", "")) == "":
		cfg["kit_w"] = user_kit_w
		cfg["tint_kit2"] = user_kit_sec_hex
		# Club del kit: Avatar3D estampa su escudo y patrocinio en la camiseta.
		if user_kit_club != "":
			cfg["kit_club"] = user_kit_club
	return cfg

## Para vistas previas del editor: config con el kit de club aplicado
## (sin mutar el original).
static func preview_config(cfg: Dictionary) -> Dictionary:
	return _apply_kit_tint(from_legacy(cfg))

## Config para la celebración de gol (GoalCelebration.gd): el MISMO
## jugador de cuerpo entero, con el KIT puesto (en la cancha no se festeja
## de traje) — los accesorios sí quedan.
## Compañero para el festejo (10-oct, Wilber: "más celebraciones, tal vez
## con compañeros"): cara/piel/pelo propios (NPC determinista por `key`) y
## el MISMO kit que el usuario (camiseta, short, medias, diseño).
static func teammate_config(user_cfg: Dictionary, key: String, world_seed: int) -> Dictionary:
	var cfg: Dictionary = config_for_npc(key, "player", world_seed).duplicate(true)
	strip_street(cfg)
	for k in ["tint_clothing", "tint_shorts", "tint_socks", "kit_w", "tint_kit2", "kit_club"]:
		if user_cfg.has(k):
			cfg[k] = user_cfg[k]
		else:
			cfg.erase(k)
	cfg["full"] = true
	return cfg

static func celebration_config_for_player(player: PlayerData, world_seed: int) -> Dictionary:
	var cfg: Dictionary = config_for_player(player, world_seed).duplicate(true)
	strip_street(cfg)
	cfg["full"] = true
	return cfg

## NPC (DT, presidente, agente, periodista, pareja, staff, otros
## jugadores) con las MISMAS piezas, sesgado por rol: directivos/DT/agentes
## de traje o ropa formal, mayores (barba, canas); periodistas de camisa;
## pareja de ropa de calle sin barba. Determinista por nombre + rol + seed.
const _FORMAL_OUTFITS := ["traje_negro", "traje_azul", "camisa_vestir", "cuello_alto", "abrigo"]
const _PRESS_OUTFITS := ["camisa_vestir", "polo", "vaquera", "cuello_alto", "bomber"]
const _CASUAL_OUTFITS := ["hoodie", "jeans", "polo", "hawaiana", "lino", "bomber", "vaquera", "universitaria", "plumifero"]

static func config_for_npc(npc_name: String, role: String, world_seed: int) -> Dictionary:
	var seed_int: int = hash(npc_name) ^ world_seed ^ hash("npc:" + role)
	var cfg: Dictionary = random_config(seed_int)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_int) ^ 0x5f3759df
	match role:
		"coach", "president", "agent", "staff", "director":
			cfg["outfit"] = _FORMAL_OUTFITS[rng.randi() % _FORMAL_OUTFITS.size()]
			cfg["face"] = "barba" if rng.randf() < 0.6 else ""
			cfg.erase("acc_head")
			var greys: Array = ["#9a9a9a", "#e8e8e8", "#2b2320", "#5a3b26"]
			cfg["tint_hair"] = greys[rng.randi() % greys.size()]
			if role == "agent" and rng.randf() < 0.35:
				cfg["acc_eyes"] = "aviador"
		"journalist":
			cfg["outfit"] = _PRESS_OUTFITS[rng.randi() % _PRESS_OUTFITS.size()]
			cfg.erase("acc_head")
		"partner":
			cfg["outfit"] = _CASUAL_OUTFITS[rng.randi() % _CASUAL_OUTFITS.size()]
			cfg["face"] = ""
			cfg.erase("acc_head")
			if rng.randf() < 0.3:
				cfg["acc_eyes"] = "lentes_sol"
	return cfg

# --- Render ------------------------------------------------------------

## Capas a dibujar, de atrás hacia adelante: [grupo, id].
static func _layers(cfg: Dictionary) -> Array:
	var out: Array = []
	var outfit: String = String(cfg.get("outfit", ""))
	var top: String = String(cfg.get("top", ""))
	var bottom: String = String(cfg.get("bottom", ""))
	if top != "" or bottom != "":
		# Prendas sueltas: pantalón abajo, parte de arriba encima. La mitad
		# que falte es la del kit del club.
		out.append(["bottom", bottom if not outfit_by_id(bottom).is_empty() else "kit"])
		out.append(["top", top if not outfit_by_id(top).is_empty() else "kit"])
	else:
		out.append(["body", outfit if outfit != "" and not outfit_by_id(outfit).is_empty() else "kit"])
	out.append(["head", "base"])
	# "age" (arrugas por edad) y "expr" (feliz/enojado) usan las mismas
	# capas de rasgo, encima del rasgo elegido (P6, 10-oct).
	for grp in [["rasgo", "rasgo"], ["age", "rasgo"], ["expr", "rasgo"], ["nose", "nose"], ["ears", "ears"]]:
		var rid: String = String(cfg.get(grp[0], ""))
		if rid != "":
			out.append([grp[1], rid])
	var face: String = String(cfg.get("face", ""))
	if face != "":
		out.append(["face", face])
	var hat: bool = HAT_IDS.has(String(cfg.get("acc_head", "")))
	var hair: String = String(cfg.get("hair", "rapado"))
	if hair != "rapado" and hair != "" and not hat:
		out.append(["hair", hair])
	var street: bool = wears_street(cfg)
	for slot in ACC_SLOTS:
		# Guayos con el kit, zapatos de calle con ropa de calle.
		if (slot == "acc_feet" and street) or (slot == "acc_shoes" and not street):
			continue
		var id: String = String(cfg.get(slot, ""))
		if id != "" and not accessory_by_id(id).is_empty():
			out.append(["acc", id])
	return out

static func _image(path: String) -> Image:
	if _img_cache.has(path):
		return _img_cache[path]
	var img: Image = null
	if ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		if t != null:
			img = t.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				img.convert(Image.FORMAT_RGBA8)
	_img_cache[path] = img
	return img

static func _hex_or_null(cfg: Dictionary, key: String) -> Variant:
	var h: String = String(cfg.get("tint_" + key, ""))
	return Color(h) if h != "" else null

## Multiplica el tinte por la luminancia de la máscara, con un poco de
## brillo extra en las luces altas (si no, un kit blanco teñido de negro
## quedaba plano). Mismo cálculo que el mockup validado en
## _pixellab_preview/mock_combos.png.
static func _tinted(tint: Color, k: float) -> Color:
	var hi: float = maxf(0.0, k - 0.9) * 2.0
	return Color(
		minf(1.0, tint.r * k + (1.0 - tint.r) * hi),
		minf(1.0, tint.g * k + (1.0 - tint.g) * hi),
		minf(1.0, tint.b * k + (1.0 - tint.b) * hi), 1.0)

## Clave especial en el dict de tintes: estampado del diseño del club.
const _KITPAT := -100

static func _tints(cfg: Dictionary) -> Dictionary:
	var t := _tints_base(cfg)
	var w: int = int(cfg.get("kit_w", -1))
	if w >= 0 and cfg.has("tint_kit2") and String(cfg["tint_kit2"]) != "":
		var m: Image = Kit.w_mask(w)
		if m != null:
			t[_KITPAT] = {"mask": m, "bbox": m.get_used_rect(), "col2": Color(String(cfg["tint_kit2"]))}
	return t

static func _tints_base(cfg: Dictionary) -> Dictionary:
	return {
		MASK_SKIN: _hex_or_null(cfg, "base"),
		MASK_HAIR: _hex_or_null(cfg, "hair"),
		MASK_SHIRT: _hex_or_null(cfg, "clothing"),
		MASK_SHORTS: _hex_or_null(cfg, "shorts"),
		MASK_SOCKS: _hex_or_null(cfg, "socks") if cfg.has("tint_socks") else _hex_or_null(cfg, "clothing"),
		MASK_BOOTS: _hex_or_null(cfg, "boots") if cfg.has("tint_boots") else (Color(String(GUAYOS_TINT[cfg["acc_feet"]])) if GUAYOS_TINT.has(String(cfg.get("acc_feet", ""))) else null),
	}

## Pinta una capa (color + máscara) sobre `out`, tiñendo por clase.
static func _blit(out: Image, base_path: String, tints: Dictionary, at: Vector2i = Vector2i.ZERO) -> void:
	var col: Image = _image(base_path + ".png")
	var msk: Image = _image(base_path + "_m.png")
	if col == null or msk == null:
		return
	var w: int = col.get_width()
	var h: int = col.get_height()
	# Estampado del diseño del club sobre los píxeles de camiseta (clase 3):
	# la caja de la camiseta de ESTA capa/cuadro se mapea sobre la caja de la
	# plantilla; la clase de la plantilla decide primario/secundario y el
	# sombreado sigue siendo el del sprite.
	var pat = tints.get(_KITPAT)
	var sb := Rect2i()
	if pat != null and tints.get(MASK_SHIRT) != null:
		var x0: int = w
		var y0: int = h
		var x1: int = -1
		var y1: int = -1
		for yy in range(h):
			for xx in range(w):
				if col.get_pixel(xx, yy).a > 0.0 and int(round(msk.get_pixel(xx, yy).r * 255.0)) == MASK_SHIRT:
					x0 = mini(x0, xx)
					y0 = mini(y0, yy)
					x1 = maxi(x1, xx)
					y1 = maxi(y1, yy)
		if x1 >= x0:
			sb = Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
		else:
			pat = null
	for y in range(h):
		var oy: int = y + at.y
		if oy < 0 or oy >= out.get_height():
			continue
		for x in range(w):
			var ox: int = x + at.x
			if ox < 0 or ox >= out.get_width():
				continue
			var c: Color = col.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var m: Color = msk.get_pixel(x, y)
			var cls: int = int(round(m.r * 255.0))
			var t = tints.get(cls)
			if pat != null and cls == MASK_SHIRT:
				var tb: Rect2i = pat["bbox"]
				var tx: int = tb.position.x + int((x - sb.position.x + 0.5) * tb.size.x / float(sb.size.x))
				var ty: int = tb.position.y + int((y - sb.position.y + 0.5) * tb.size.y / float(sb.size.y))
				var pm: Image = pat["mask"]
				if int(round(pm.get_pixel(clampi(tx, 0, pm.get_width() - 1), clampi(ty, 0, pm.get_height() - 1)).r * 255.0)) == 2:
					t = pat["col2"]
			out.set_pixel(ox, oy, _tinted(t, m.g) if t != null else c)

## Sprite de 48×48 compuesto (cacheado por config).
static func compose(cfg: Dictionary) -> ImageTexture:
	var key: String = JSON.stringify(cfg, "", true)
	if _tex_cache.has(key):
		return _tex_cache[key]
	var tints := _tints(cfg)
	var out := Image.create(SPRITE_PX, SPRITE_PX, false, Image.FORMAT_RGBA8)
	for l in _layers(cfg):
		_blit(out, "%s%s/%s" % [_DIR, l[0], l[1]], tints)
	var tex := ImageTexture.create_from_image(out)
	if _tex_cache.size() >= _TEX_CACHE_MAX:
		_tex_cache.clear()
	_tex_cache[key] = tex
	return tex

## Nodo Control de `px`×`px`. Busto con fondo de color (lo que muestran
## casi todas las pantallas) o, con cfg["full"], cuerpo entero sin fondo.
## Escala con nitidez de pixel-art (TEXTURE_FILTER_NEAREST).
static func build(config: Dictionary, px: int) -> Control:
	var cfg: Dictionary = from_legacy(config)
	# Jugador 3D (el mismo modelo del partido) en vez del pixel art, si el 3D está activo
	var a3: Script = _avatar3d()
	if a3 != null:
		var c3: Control = a3.build(cfg, px)
		if c3 != null:
			return c3
	var full: bool = bool(cfg.get("full", false))
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not full:
		var bg_hex: String = String(cfg.get("tint_background", "#7fb0d8"))
		var bg := Panel.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# StyleBoxFlat directo (no Styles.card_flat): SaveManager depende de
		# Avatar (migración v31) y Styles depende de WorldTickEngine — sin
		# esto quedaba una cadena de dependencias entre autoloads.
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(bg_hex).darkened(0.25)
		sb.set_corner_radius_all(maxi(4, int(px * 0.18)))
		bg.add_theme_stylebox_override("panel", sb)
		root.add_child(bg)
	var tex: Texture2D = compose(cfg)
	if not full or cfg.has("region"):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(cfg["region"]) if cfg.has("region") else Rect2(BUST_RECT)
		tex = at
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return root

# --- Animaciones del jugador (PixelLab, 9-oct) ---------------------------
## Animaciones generadas sobre el personaje base y teñidas por cuadro con la
## piel/pelo/kit de cada jugador (máscaras de tools/anim_layers.py, en
## assets/pixelplayer/anim/<anim>/<n>.png). Lienzo de 68×68 (el de PixelLab
## al animar). Limitación conocida: el PEINADO y los accesorios no van en
## las animaciones (las piezas no siguen el movimiento) — sí el color de
## pelo, piel y kit.
const ANIM_PX := 68
const CELEBRATION_ANIMS := ["celeb_rodillas", "celeb_salto", "celeb_avion", "celeb_cielo", "celeb_escudo", "celeb_mortal",
	"celeb_baile", "celeb_corazon", "celeb_silencio", "celeb_bebe",
	# 10-oct: cuatro más (PixelLab sobre el mismo personaje).
	"celeb_pistolas", "celeb_saludo", "celeb_aplauso", "celeb_grito",
	# 10-oct (día, Wilber: festejos "de figura"): brazos cruzados, dedos al
	# cielo, salto con brazos abajo, saludo surfero, meditación, brazos
	# abiertos y robot. Sin nombres de jugadores reales.
	"celeb_brazos_cruzados", "celeb_dedos_cielo", "celeb_salto_giro", "celeb_surfero",
	"celeb_meditacion", "celeb_brazos_abiertos", "celeb_robot"]

static func has_anim(anim: String) -> bool:
	return ResourceLoader.exists("%sanim/%s/0.png" % [_DIR, anim])

static func anim_frames(cfg: Dictionary, anim: String) -> Array:
	var key: String = "anim:%s:%s" % [anim, JSON.stringify(cfg, "", true)]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var tints := _tints(cfg)
	var out: Array = []
	var i: int = 0
	# Peinado / barba / gorro / lentes ENCIMA de cada cuadro, siguiendo la
	# cabeza (tools/anim_head_track.py). Antes las animaciones solo traían
	# el corte base: la melena o las rastas desaparecían en los festejos.
	var heads: Array = AnimHeadOffsets.OFFSETS.get(anim, [])
	# PEINADO DESDE TODOS LOS ÁNGULOS (17-oct, tools/hair_views.py): en las
	# animaciones de cancha cada cuadro dice si la cabeza se ve de frente, de
	# espaldas o de costado; de frente van las capas de siempre, si no, el
	# peinado dibujado para esa vista (hair_n / hair_e / hair_w).
	var views: Array = AnimHeadOffsets.VIEWS.get(anim, [])
	var head_layers: Array = []
	var hair_id: String = ""
	for l in _layers(cfg):
		if l[0] in ["face", "hair", "rasgo", "nose", "ears"] or (l[0] == "acc" and _HEAD_ACC.has(String(l[1]))):
			head_layers.append("%s%s/%s" % [_DIR, l[0], l[1]])
		if l[0] == "hair":
			hair_id = String(l[1])
	var front0: Vector2i = Vector2i.ZERO
	var f0: Array = AnimHeadOffsets.OFFSETS.get("pitch_idle_south", [])
	if not f0.is_empty() and f0[0] != null:
		front0 = f0[0]
	while ResourceLoader.exists("%sanim/%s/%d.png" % [_DIR, anim, i]):
		var img := Image.create(ANIM_PX, ANIM_PX, false, Image.FORMAT_RGBA8)
		_blit(img, "%sanim/%s/%d" % [_DIR, anim, i], tints)
		if not views.is_empty():
			if i < views.size() and views[i] != null:
				var vw: Array = views[i]
				var d := Vector2i(int(vw[1]), int(vw[2]))
				if String(vw[0]) == "s":
					for hp in head_layers:
						_blit(img, hp, tints, Vector2i(10, 10) + front0 + d)
				elif hair_id != "":
					_blit(img, "%shair_%s/%s" % [_DIR, String(vw[0]), hair_id], tints, d)
		elif i < heads.size() and heads[i] != null:
			var at: Vector2i = Vector2i(10, 10) + (heads[i] as Vector2i)
			for hp in head_layers:
				_blit(img, hp, tints, at)
		out.append(ImageTexture.create_from_image(img))
		i += 1
	if _tex_cache.size() >= _TEX_CACHE_MAX:
		_tex_cache.clear()
	_tex_cache[key] = out
	return out

## Nodo `px`×`px` con el jugador haciendo `anim` (se queda en el último
## cuadro salvo `loop`). Sin arte para esa animación → el cuerpo quieto.
static func build_anim(config: Dictionary, anim: String, px: int, loop: bool = false, fps: float = 10.0) -> Control:
	var cfg: Dictionary = from_legacy(config)
	var a3: Script = _avatar3d()
	if a3 != null:
		var c3: Control = a3.build_anim(cfg, anim, px, loop)
		if c3 != null:
			return c3
	var frames: Array = anim_frames(cfg, anim)
	if frames.is_empty():
		return build_full(cfg, px)
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := AnimRect.new()
	r.frames = frames
	r.loop = loop
	r.fps = fps
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(r)
	return root

## Avatar3D (data/Avatar3D.gd) cargado al usarlo, no al parsear: Avatar lo usan
## autoloads (SaveManager) que no deben arrastrar el modelo 3D. null = pixel art.
static func _avatar3d() -> Script:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null or not tree.root.has_node("Preferences"):
		return null
	if not bool(tree.root.get_node("Preferences").get("match_3d")):
		return null
	return load("res://data/Avatar3D.gd") as Script

## Pone el jugador 3D (cuerpo entero) dentro de `rect` si el 3D está activo.
static func fill_3d(rect: TextureRect, config: Dictionary, px: int) -> bool:
	var a3: Script = _avatar3d()
	return a3 != null and bool(a3.fill(rect, from_legacy(config), px))

## Celebración de gol: una de las 6 animaciones, determinista por texto.
static func celebration_anim_for(variant_seed: String) -> String:
	return String(CELEBRATION_ANIMS[absi(hash("celeb:" + variant_seed)) % CELEBRATION_ANIMS.size()])

## Cuerpo entero (editor, Tienda).
static func build_full(config: Dictionary, px: int) -> Control:
	var cfg: Dictionary = from_legacy(config)
	cfg["full"] = true
	return build(cfg, px)

## Zoom a los pies (Tienda, pestaña Guayos — P0 9-oct): piernas y botines
## del cuerpo entero, `w` de ancho (alto = w/2).
const FEET_RECT := Rect2i(12, 37, 24, 11)
static func build_feet(config: Dictionary, w: int) -> Control:
	var cfg: Dictionary = from_legacy(config).duplicate()
	cfg["full"] = true
	cfg["region"] = FEET_RECT
	var c := build(cfg, w)
	c.custom_minimum_size = Vector2(w, w * 0.5)
	return c

## Misma config con una EXPRESIÓN encima ("feliz" / "enojado") — P6.
static func with_expression(cfg: Dictionary, expr: String) -> Dictionary:
	var c: Dictionary = cfg.duplicate()
	c["expr"] = expr
	return c

static func for_player(player: PlayerData, world_seed: int, px: int) -> Control:
	return build(config_for_player(player, world_seed), px)

static func for_npc(npc_name: String, role: String, world_seed: int, px: int) -> Control:
	return build(config_for_npc(npc_name, role, world_seed), px)

# --- Editor ------------------------------------------------------------

## Ids elegibles de una categoría del editor ("hair" / "face").
static func _catalog(key: String) -> Array:
	match key:
		"hair":
			return HAIR_STYLES
		"face":
			return FACE_STYLES
		"nose":
			return NOSES
		"ears":
			return EARS
		"rasgo":
			return RASGOS
	return []

static func options_for(key: String) -> Array:
	var src: Array = _catalog(key)
	var out: Array = []
	for s in src:
		out.append(String(s["id"]))
	return out

static func option_label(key: String, id: String) -> String:
	var src: Array = _catalog(key)
	for s in src:
		if String(s["id"]) == id:
			return String(s["label"])
	return id

static func set_tint(config: Dictionary, key: String, hex: String) -> Dictionary:
	var out := config.duplicate(true)
	out["tint_" + key] = hex
	return out

static func tint_of(config: Dictionary, key: String) -> String:
	return String(config.get("tint_" + key, ""))
