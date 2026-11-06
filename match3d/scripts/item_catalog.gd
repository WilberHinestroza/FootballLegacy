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
const GUAYOS := {
	"": {"name": "De serie", "color": "#151515", "price": 0},
	"guayos_negro": {"name": "Negros", "color": "#2b2b30", "price": 25},
	"guayos_blanco": {"name": "Blancos", "color": "#e9eef6", "price": 20},
	"guayos_verde": {"name": "Verdes", "color": "#3ee03a", "price": 20},
	"guayos_rosa": {"name": "Rosas", "color": "#ff4fa3", "price": 20},
	"guayos_azul": {"name": "Azules", "color": "#2e7bff", "price": 22},
	"guayos_rojo": {"name": "Rojos", "color": "#e3262f", "price": 22},
	"guayos_morado": {"name": "Morados", "color": "#8a3cff", "price": 30},
	"guayos_lava": {"name": "Lava", "color": "#ff6a1a", "price": 35},
	"guayos_plata": {"name": "Plata", "color": "#c9ced8", "price": 40},
	"guayos_arcoiris": {"name": "Arcoíris", "color": "#ffb21a", "price": 45},
	"guayos_oro": {"name": "Oro", "color": "#e8b923", "price": 65},
}


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


## Busca un hueso por su nombre corto, sea cual sea el prefijo (mixamorig:, mixamorig_…).
static func find_bone(skeleton: Skeleton3D, short_name: String) -> int:
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i).ends_with(short_name):
			return i
	return -1
