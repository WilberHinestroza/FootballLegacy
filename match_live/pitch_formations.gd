class_name PitchFormations
extends RefCounted
## Formaciones y puestos de FootballCareer (engine/world/Formations.gd y
## data/Positions.gd) llevados a la cancha: dónde se para cada código de
## posición. Coordenadas en el marco del equipo: x 0..1 de izquierda a
## derecha mirando hacia el arco rival, d 0..1 desde la propia portería.

## Copia de Formations.SLOTS (10 de campo; el POR va aparte).
const SLOTS := {
	"4-3-3":   ["LI", "DFC", "DFC", "LD", "MCD", "MC", "MC", "EI", "DC", "ED"],
	"4-4-2":   ["LI", "DFC", "DFC", "LD", "MI", "MC", "MC", "MD", "DC", "SD"],
	"4-2-3-1": ["LI", "DFC", "DFC", "LD", "MCD", "MCD", "EI", "MCO", "ED", "DC"],
	"3-5-2":   ["DFC", "DFC", "DFC", "MD", "MCD", "MC", "MC", "MI", "DC", "SD"],
	"5-3-2":   ["CAI", "DFC", "DFC", "DFC", "CAD", "MCD", "MC", "MC", "DC", "SD"],
	"4-5-1":   ["LI", "DFC", "DFC", "LD", "EI", "MC", "MCD", "MC", "ED", "DC"],
}

## Copia de Positions.DETAILED (código -> nombre, categoría amplia).
const POSITIONS := {
	"POR": ["Portero", "GK"],
	"DFC": ["Defensa central", "DF"], "LD": ["Lateral derecho", "DF"], "LI": ["Lateral izquierdo", "DF"],
	"CAD": ["Carrilero derecho", "DF"], "CAI": ["Carrilero izquierdo", "DF"],
	"MCD": ["Mediocentro defensivo", "MF"], "MC": ["Centrocampista central", "MF"],
	"MD": ["Interior derecho", "MF"], "MI": ["Interior izquierdo", "MF"],
	"MCO": ["Mediocentro ofensivo", "MF"], "MP": ["Media punta", "MF"],
	"ED": ["Extremo derecho", "MF"], "EI": ["Extremo izquierdo", "MF"],
	"SD": ["Segundo delantero", "ST"], "DC": ["Delantero centro", "ST"],
}

## Lugar base de cada código (x, d). Los repetidos (2-3 DFC, 2 MC...) se
## abren a lo ancho alrededor de este punto.
const SPOT := {
	"POR": Vector2(0.50, 0.02),
	"DFC": Vector2(0.50, 0.17), "LI": Vector2(0.12, 0.21), "LD": Vector2(0.88, 0.21),
	"CAI": Vector2(0.07, 0.30), "CAD": Vector2(0.93, 0.30),
	"MCD": Vector2(0.50, 0.31), "MC": Vector2(0.50, 0.40),
	"MI": Vector2(0.16, 0.41), "MD": Vector2(0.84, 0.41),
	"MCO": Vector2(0.50, 0.52), "MP": Vector2(0.50, 0.56),
	"EI": Vector2(0.12, 0.57), "ED": Vector2(0.88, 0.57),
	"SD": Vector2(0.40, 0.62), "DC": Vector2(0.55, 0.65),
}
const SPREAD := {"DFC": 0.22, "MCD": 0.22, "MC": 0.26}

static func formations() -> Array:
	return SLOTS.keys()

## Los 11 puestos (POR primero) de una formación.
static func slots(formation: String) -> Array:
	var out: Array = ["POR"]
	out.append_array(SLOTS.get(formation, SLOTS["4-3-3"]))
	return out

static func broad(code: String) -> String:
	return String(POSITIONS.get(code, ["", "MF"])[1])

static func label(code: String) -> String:
	return String(POSITIONS.get(code, [code])[0])

## Posición base (x, d) de cada uno de los 11 puestos.
static func layout(formation: String) -> Array:
	return layout_codes(slots(formation))

## Posiciones (x, d) para una lista cualquiera de puestos (la XI real que
## armó el DT en FootballLegacy, que puede no calzar con una formación).
static func layout_codes(codes: Array) -> Array:
	var count: Dictionary = {}
	for c in codes:
		count[c] = int(count.get(c, 0)) + 1
	var seen: Dictionary = {}
	var out: Array = []
	for c in codes:
		var p: Vector2 = SPOT.get(c, Vector2(0.5, 0.4))
		var n: int = int(count[c])
		var i: int = int(seen.get(c, 0))
		seen[c] = i + 1
		if n > 1:
			p.x += (float(i) - float(n - 1) * 0.5) * float(SPREAD.get(c, 0.24))
		# Con SD y DC juntos, el DC se corre un poco a la derecha.
		if c == "DC" and codes.has("SD"):
			p.x = 0.58
		out.append(p)
	return out
