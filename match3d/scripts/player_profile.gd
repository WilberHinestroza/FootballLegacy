class_name PlayerProfile
extends RefCounted
## Jugador creado en el editor: datos, cara (piel, barba, pelo), físico y guayos.
## Se guarda en user://player_profile.json. Colores e id como en FootballCareer
## (Avatar.TINTS, FACE_STYLES, HAIR_STYLES, guayos_*), para poder compartir el perfil.
## La equipación (camiseta, pantalón, medias) es la del club, no se elige aquí.

const SAVE_PATH := "user://player_profile.json"
## Modo pruebas: todo desbloqueado (guayos de la tienda incluidos). Quitar al unir con FootballCareer.
const TEST_UNLOCK_ALL := true
const BASE_HEIGHT := 1.82 # altura "real" que representa el modelo a escala 1

const POSITIONS := ["Portero", "Defensa", "Centrocampista", "Delantero"]
const FEET := ["Derecha", "Izquierda", "Ambas"]
# Avatar.TINTS de FootballCareer
const SKIN_TONES := [
	Color("f4d6c0"), Color("eec1a3"), Color("d9a577"), Color("b57e56"), Color("8a5a3b"), Color("5f3a26"),
]
const HAIR_COLORS := [
	Color("2b2320"), Color("5a3b26"), Color("8a5a3b"), Color("c98f4b"),
	Color("d8c07a"), Color("9a9a9a"), Color("e8e8e8"), Color("3f6fb0"),
]
const KIT_COLORS := [
	Color("db2128"), Color("2861eb"), Color("f2f2f2"), Color("141414"), Color("f5c518"),
	Color("1f9d4a"), Color("7b2cbf"), Color("ff7a1a"), Color("5ec8f2"), Color("8b0f2e"),
]

# Id del primer catálogo de pruebas (ya no existen)
const LEGACY_ITEMS := ["hair_short", "hair_shaved", "hair_mohawk", "hair_long", "boots_classic", "boots_speed", "acc_none", "acc_headband"]

var player_name := "Jugador"
var number := 10
var position := 3
var foot := 0
var skin: Color = SKIN_TONES[1]
var hair: Color = HAIR_COLORS[3]
var hair_style := "rapado"
var face := ""
var height := 1.80
var build := 1.0
var guayos := ""
var owned_items: Array[String] = [] # cosmetics_owned de FootballCareer (guayos_*…)
## Stats de PlayerData (FootballCareer). Al unir los juegos vendrán de tu carrera.
var stats := {
	"speed": 65, "stamina": 65, "strength": 60, "control": 65, "passing": 62,
	"shooting": 66, "dribbling": 66, "decision_making": 60, "composure": 60,
}
# Equipación del club
var shirt: Color = KIT_COLORS[0]
var shorts: Color = KIT_COLORS[2]
var socks: Color = KIT_COLORS[0]


## Colores y opciones para el shader de zonas del jugador.
func colors() -> Dictionary:
	var c := {
		"skin_color": skin, "hair_color": hair, "shirt_color": shirt,
		"shorts_color": shorts, "socks_color": socks,
		"show_hair": hair_style != "calvo",
		"hair_style": ItemCatalog.shader_hair_index(hair_style),
		"beard_style": ItemCatalog.face_index(face),
	}
	c.merge(ItemCatalog.guayos_params(guayos)) # color, diseño y logo de los guayos
	return c


## Escala del cuerpo: la altura escala todo, la complexión ensancha.
func body_scale() -> Vector3:
	var h := height / BASE_HEIGHT
	return Vector3(h * build, h, h * build)


## Media como el "overall" de FootballCareer (aprox.).
func overall() -> int:
	# Misma fórmula que PlayerDevelopment.compute_overall (6 stats de carta):
	# RIT, TIR, PAS, REG, DEF, FÍS. Evita desincronización entre perfil y carrera.
	var rit := float(stats.get("speed", 50))
	var tir := float(stats.get("shooting", 50))
	var pas := float(stats.get("passing", 50))
	var reg := (float(stats.get("dribbling", 50)) + float(stats.get("control", 50))) / 2.0
	var def := float(stats.get("decision_making", 50)) * 0.5 + float(stats.get("strength", 50)) * 0.3 + float(stats.get("speed", 50)) * 0.2
	var fis := (float(stats.get("strength", 50)) + float(stats.get("stamina", 50))) / 2.0
	var total := rit + tir + pas + reg + def + fis
	return int(round(total / 6.0))


func owns(item_id: String) -> bool:
	return TEST_UNLOCK_ALL or item_id == "" or owned_items.has(item_id)


func to_dict() -> Dictionary:
	return {
		"name": player_name, "number": number, "position": position, "foot": foot,
		"skin": skin.to_html(false), "hair": hair.to_html(false),
		"hair_style": hair_style, "face": face,
		"height": height, "build": build, "guayos": guayos, "owned_items": owned_items,
		"stats": stats,
		"shirt": shirt.to_html(false), "shorts": shorts.to_html(false), "socks": socks.to_html(false),
	}


static func from_dict(d: Dictionary) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.player_name = d.get("name", p.player_name)
	p.number = int(d.get("number", p.number))
	p.position = int(d.get("position", p.position))
	p.foot = int(d.get("foot", p.foot))
	p.skin = Color(d.get("skin", p.skin.to_html(false)))
	p.hair = Color(d.get("hair", p.hair.to_html(false)))
	p.hair_style = str(d.get("hair_style", p.hair_style))
	if not ItemCatalog.hair_available(p.hair_style):
		p.hair_style = "rapado"
	p.face = str(d.get("face", p.face))
	p.height = float(d.get("height", p.height))
	p.build = float(d.get("build", p.build))
	for id in d.get("owned_items", []):
		if str(id) in LEGACY_ITEMS:
			continue
		if not p.owned_items.has(str(id)):
			p.owned_items.append(str(id))
	p.guayos = str(d.get("guayos", ""))
	if not ItemCatalog.GUAYOS.has(p.guayos) or not p.owns(p.guayos):
		p.guayos = ""
	var st: Variant = d.get("stats", {})
	if st is Dictionary:
		for k in p.stats.keys():
			p.stats[k] = int(clampf(float(st.get(k, p.stats[k])), 20.0, 99.0))
	p.shirt = Color(d.get("shirt", p.shirt.to_html(false)))
	p.shorts = Color(d.get("shorts", p.shorts.to_html(false)))
	p.socks = Color(d.get("socks", p.socks.to_html(false)))
	return p


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict(), "\t"))


static func load_or_default() -> PlayerProfile:
	if not FileAccess.file_exists(SAVE_PATH):
		return PlayerProfile.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		return from_dict(data)
	return PlayerProfile.new()
