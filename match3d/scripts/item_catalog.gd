class_name ItemCatalog
extends RefCounted
## Opciones de aspecto del jugador 3D, con los mismos id que FootballCareer (data/Avatar.gd):
## - Peinados y barbas: se eligen gratis (como en el editor de FootballCareer).
##   rapado, calvo y degradado los pinta el shader; el resto los construye HairBuilder en 3D
##   y se pegan al hueso Head.
## - Guayos: se compran en la tienda (ShopEngine.COSMETIC_PRICE); aquí solo cambian el color
##   de las botas. "price" es el precio mínimo de FootballCareer (allí sube con el sueldo).

const HAIR_STYLES := [
	{"id": "rapado", "name": "Rapado"},
	{"id": "calvo", "name": "Calvo", "hides_hair": true},
	{"id": "tupe", "name": "Tupé"}, {"id": "rulos", "name": "Rulos"},
	{"id": "melena", "name": "Melena"}, {"id": "cresta", "name": "Cresta"},
	{"id": "largo", "name": "Largo"}, {"id": "mono", "name": "Moño"},
	{"id": "trenzas", "name": "Trenzas"}, {"id": "rastas", "name": "Rastas"},
	{"id": "engominado", "name": "Engominado"}, {"id": "afro", "name": "Afro"},
	{"id": "flequillo", "name": "Flequillo"}, {"id": "coleta", "name": "Coleta"},
	{"id": "puntas", "name": "Puntas"}, {"id": "degradado", "name": "Degradado"},
	{"id": "rizos_largos", "name": "Rizos largos"}, {"id": "raya", "name": "Raya"},
]
## Peinados que pinta el shader sobre la cabeza (sin pieza 3D); el índice es hair_style del shader.
const BUILT_IN_HAIR := ["rapado", "calvo", "degradado", "cresta"]

## El índice es el valor de beard_style en el shader.
const FACE_STYLES := [
	{"id": "", "name": "Sin barba"},
	{"id": "barba", "name": "Barba"},
	{"id": "barba3", "name": "De 3 días"},
	{"id": "candado", "name": "Candado"},
	{"id": "bigote", "name": "Bigote"},
	{"id": "barba_larga", "name": "Barba larga"},
]

## "" = los guayos de serie (negros, gratis).
## color / c2 / accent + design: ver la cabecera de player_body.gdshaderinc (0 liso ·
## 1 degradado · 2 líneas · 3 llamas · 4 camuflaje · 5 rayo · 6 dos caras · 7 galaxia ·
## 8 tigre · 9 puntos · 10 arcoíris · 11 lava). El logo sale de la marca (BootBrands).
const GUAYOS := {
	"": {"name": "De serie", "color": "#151515", "price": 0},
	"guayos_negro": {"name": "Negros", "color": "#2b2b30", "c2": "#e3262f", "accent": "#e3262f", "design": 2, "price": 25},
	"guayos_blanco": {"name": "Blancos", "color": "#e9eef6", "c2": "#2e7bff", "accent": "#2e7bff", "design": 1, "price": 20},
	"guayos_verde": {"name": "Verdes", "color": "#3ee03a", "c2": "#121212", "accent": "#121212", "design": 2, "price": 20},
	"guayos_rosa": {"name": "Rosas", "color": "#ff4fa3", "c2": "#ff8a1a", "accent": "#ffffff", "design": 1, "price": 20},
	"guayos_azul": {"name": "Azules", "color": "#2e7bff", "c2": "#0b1d4a", "accent": "#ffffff", "design": 9, "price": 22},
	"guayos_rojo": {"name": "Rojos", "color": "#e3262f", "c2": "#ffb21a", "accent": "#ffe66b", "design": 3, "price": 22},
	"guayos_morado": {"name": "Morados", "color": "#8a3cff", "c2": "#c9ced8", "accent": "#ffffff", "design": 6, "price": 30},
	"guayos_lava": {"name": "Lava", "color": "#1d1a19", "c2": "#ff6a1a", "accent": "#ffd21a", "design": 11, "price": 35},
	"guayos_plata": {"name": "Plata", "color": "#c9ced8", "c2": "#7d8698", "accent": "#2e7bff", "design": 1, "price": 40},
	"guayos_arcoiris": {"name": "Arcoíris", "color": "#ffb21a", "c2": "#ffffff", "accent": "#ffffff", "design": 10, "price": 45},
	"guayos_oro": {"name": "Oro", "color": "#e8b923", "c2": "#fff1b0", "accent": "#141414", "design": 1, "price": 65},
	# 7-nov: diseños locos, como los de verdad (marcas y logos inventados)
	"guayos_tormenta": {"name": "Tormenta", "color": "#14161c", "c2": "#2e7bff", "accent": "#ffe600", "design": 5, "price": 55},
	"guayos_galaxia": {"name": "Galaxia", "color": "#160b3a", "c2": "#7a2cff", "accent": "#ffffff", "design": 7, "price": 70},
	"guayos_tigre": {"name": "Tigre", "color": "#ff8a00", "c2": "#141414", "accent": "#ffffff", "design": 8, "price": 50},
	"guayos_camo": {"name": "Camuflaje", "color": "#3b4a2a", "c2": "#7c8a45", "accent": "#e3262f", "design": 4, "price": 45},
	"guayos_fuego": {"name": "Fuego", "color": "#ffd21a", "c2": "#e3262f", "accent": "#141414", "design": 3, "price": 55},
	"guayos_hielo": {"name": "Hielo", "color": "#4fd1ff", "c2": "#f2fbff", "accent": "#1b4dff", "design": 1, "price": 45},
	"guayos_neon": {"name": "Neón", "color": "#121212", "c2": "#39ff14", "accent": "#ff2bd6", "design": 9, "price": 60},
	"guayos_dos_caras": {"name": "Dos caras", "color": "#f4f4f4", "c2": "#e3262f", "accent": "#141414", "design": 6, "price": 50},
	# 7-nov (2): más modelos, 8 por marca, con zigzag/ajedrez/salpicado/escamas/mármol
	"guayos_voltaje": {"name": "Voltaje", "color": "#ffe600", "c2": "#141414", "accent": "#e3262f", "design": 12, "price": 50},
	"guayos_dragon": {"name": "Dragón", "color": "#b3121b", "c2": "#2a0508", "accent": "#ffb21a", "design": 15, "price": 65},
	"guayos_grafiti": {"name": "Grafiti", "color": "#121214", "c2": "#e3262f", "accent": "#f4f4f4", "design": 14, "price": 45},
	"guayos_marmol": {"name": "Mármol", "color": "#f2f2f0", "c2": "#9aa3b5", "accent": "#d4af37", "design": 16, "price": 60},
	"guayos_oceano": {"name": "Océano", "color": "#0a5fa8", "c2": "#0b1d4a", "accent": "#4fd1ff", "design": 15, "price": 55},
	"guayos_aurora": {"name": "Aurora", "color": "#062a2a", "c2": "#19e3b1", "accent": "#ffffff", "design": 7, "price": 65},
	"guayos_ajedrez": {"name": "Ajedrez", "color": "#141414", "c2": "#f4f4f4", "accent": "#ff7a1a", "design": 13, "price": 50},
	"guayos_cobra": {"name": "Cobra", "color": "#1f6b2a", "c2": "#0d2a12", "accent": "#e8b923", "design": 15, "price": 60},
	"guayos_pantera": {"name": "Pantera", "color": "#141414", "c2": "#5a1fd1", "accent": "#ff2bd6", "design": 8, "price": 55},
	"guayos_atardecer": {"name": "Atardecer", "color": "#ff7a1a", "c2": "#ff2b6e", "accent": "#ffe66b", "design": 1, "price": 40},
	"guayos_glaciar": {"name": "Glaciar", "color": "#dff4ff", "c2": "#4fa8d8", "accent": "#1b4dff", "design": 16, "price": 55},
	"guayos_bosque": {"name": "Bosque", "color": "#1e5c2e", "c2": "#9be15d", "accent": "#141414", "design": 12, "price": 45},
	"guayos_confeti": {"name": "Confeti", "color": "#f4f4f4", "c2": "#ff4fa3", "accent": "#2e7bff", "design": 14, "price": 50},
}

## Logo del shader por marca (BootBrands.logo).
const BOOT_LOGO := {"bolt": 1, "wing": 2, "fox": 3, "peak": 4}


static func hair_style(id: String) -> Dictionary:
	for s: Dictionary in HAIR_STYLES:
		if s.id == id:
			return s
	return HAIR_STYLES[0]


static func hair_model_path(id: String) -> String:
	return "res://match3d/items/hair_%s.glb" % id


## El peinado se puede usar ya: lo pinta el shader o lo construye HairBuilder en 3D.
static func hair_available(id: String) -> bool:
	return id in BUILT_IN_HAIR or HairBuilder.has_style(id)


## Índice de hair_style en el shader. Los peinados 3D llevan debajo el rapado pintado
## (la cresta, su franja) para que no se vea piel entre el pelo.
static func shader_hair_index(id: String) -> int:
	return maxi(BUILT_IN_HAIR.find(id), 0)


static func face_index(id: String) -> int:
	for i in FACE_STYLES.size():
		if FACE_STYLES[i].id == id:
			return i
	return 0


static func guayos_color(id: String) -> Color:
	return Color(GUAYOS.get(id, GUAYOS[""]).color)


## Parámetros del shader para unos guayos (colores, diseño y logo de su marca).
static func guayos_params(id: String) -> Dictionary:
	var g: Dictionary = GUAYOS.get(id, GUAYOS[""])
	var main := Color(String(g.color))
	var brand: Dictionary = BootBrands.of_model(id)
	return {
		"boots_color": main,
		"boots_color2": Color(String(g.get("c2", g.color))),
		"boots_accent": Color(String(g.get("accent", g.color))),
		"boots_design": int(g.get("design", 0)),
		"boots_logo": int(BOOT_LOGO.get(String(brand.get("logo", "")), 0)),
	}


## Busca un hueso por su nombre corto, sea cual sea el prefijo (mixamorig:, mixamorig_…).
static func find_bone(skeleton: Skeleton3D, short_name: String) -> int:
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i).ends_with(short_name):
			return i
	return -1
