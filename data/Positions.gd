extends RefCounted
class_name Positions

## Posiciones de juego.
##
## Dos niveles:
##  - CATEGORÍA AMPLIA ("GK"/"DF"/"MF"/"ST"): la que usa el motor de
##    partido (MatchEngine, MatchTeam, WorldFactory). NUNCA se toca su
##    conjunto ni su orden canónico GK -> DF -> MF -> ST.
##  - CÓDIGO DETALLADO (POR, DFC, LI, ...): flavor y base para la
##    profundidad táctica futura. Se guarda en PlayerData.detailed_position.
##
## broad_of() es la ÚNICA fuente de verdad del mapeo detallado -> amplio.

const BROAD_GK := "GK"
const BROAD_DF := "DF"
const BROAD_MF := "MF"
const BROAD_ST := "ST"

## Códigos detallados en orden de presentación (respeta GK -> DF -> MF -> ST).
const DETAILED := [
	{"code": "POR", "label": "Portero", "broad": "GK"},
	{"code": "DFC", "label": "Defensa central", "broad": "DF"},
	{"code": "LD", "label": "Lateral derecho", "broad": "DF"},
	{"code": "LI", "label": "Lateral izquierdo", "broad": "DF"},
	{"code": "CAD", "label": "Carrilero derecho", "broad": "DF"},
	{"code": "CAI", "label": "Carrilero izquierdo", "broad": "DF"},
	{"code": "MCD", "label": "Mediocentro defensivo", "broad": "MF"},
	{"code": "MC", "label": "Centrocampista central", "broad": "MF"},
	{"code": "MD", "label": "Interior derecho", "broad": "MF"},
	{"code": "MI", "label": "Interior izquierdo", "broad": "MF"},
	{"code": "MCO", "label": "Mediocentro ofensivo", "broad": "MF"},
	{"code": "MP", "label": "Media punta", "broad": "MF"},
	{"code": "ED", "label": "Extremo derecho", "broad": "MF"},
	{"code": "EI", "label": "Extremo izquierdo", "broad": "MF"},
	{"code": "SD", "label": "Segundo delantero", "broad": "ST"},
	{"code": "DC", "label": "Delantero centro", "broad": "ST"},
]

## Código detallado por defecto para cada categoría amplia (usado por la
## migración de saves antiguos y como respaldo).
const DEFAULT_DETAILED_FOR_BROAD := {
	"GK": "POR",
	"DF": "DFC",
	"MF": "MC",
	"ST": "DC",
}

## Sigla EN ESPAÑOL de la categoría amplia (pedido de Wilber: no GK/DF/MF/ST).
##   GK→POR · DF→DEF · MF→MED · ST→DEL
const _BROAD_ES := {"GK": "POR", "DF": "DEF", "MF": "MED", "ST": "DEL"}

static func broad_label(broad: String) -> String:
	return _BROAD_ES.get(broad, broad)

static func broad_of(detailed_code: String) -> String:
	for entry in DETAILED:
		if entry["code"] == detailed_code:
			return entry["broad"]
	return BROAD_ST # respaldo seguro (10 de campo)

static func label_of(detailed_code: String) -> String:
	for entry in DETAILED:
		if entry["code"] == detailed_code:
			return entry["label"]
	return detailed_code

static func is_valid_detailed(detailed_code: String) -> bool:
	for entry in DETAILED:
		if entry["code"] == detailed_code:
			return true
	return false

static func codes_for_broad(broad: String) -> Array:
	var out: Array = []
	for entry in DETAILED:
		if entry["broad"] == broad:
			out.append(entry["code"])
	return out

static func default_detailed_for_broad(broad: String) -> String:
	return DEFAULT_DETAILED_FOR_BROAD.get(broad, "DC")
