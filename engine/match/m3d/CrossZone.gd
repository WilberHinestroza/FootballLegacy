extends RefCounted
## Centro con zona elegida (P1-10): puntos del área a los que puede ir el centro.
##
## El lateral que centra ve tres destinos claros: el primer palo (el más cercano
## a su banda), el segundo palo (el opuesto) y el punto penal. Cada zona lleva la
## altura a la que debe llegar el balón para que el remate sea cómodo. El partido
## usa estos puntos para mover a tu jugador y lanzar el centro; el HUD pinta un
## botón por zona.
##
## No toca nodos ni UI: se prueba en headless y lo usa el partido 3D.

const NEAR_POST := "near"
const FAR_POST := "far"
const PENALTY_SPOT := "spot"
## Zona que se lanza sola si el jugador no elige a tiempo.
const DEFAULT := NEAR_POST

## Media anchura del arco (m). El partido tiene GOAL_WIDTH = 8.2.
const GOAL_HALF_WIDTH := 4.1
## Cuánto se mete el punto de remate desde el poste hacia dentro.
const POST_INSET := 0.55
## Cuánto por delante de la línea de gol se remata en los palos.
const POST_DEPTH := 1.1
## Distancia del punto penal a la línea de gol (m).
const SPOT_DISTANCE := 11.0
## Altura (m) a la que llega el centro en cada zona.
const POST_HEIGHT := 1.85
const SPOT_HEIGHT := 1.45


## Las tres zonas de centro para un arco en `goal`. `side` es el signo de la
## banda desde la que se centra: +1 = lado +Z, -1 = lado -Z. Devuelve una lista
## de diccionarios con id, label, point y height; el primer palo va primero.
static func targets(goal: Vector3, side: float, goal_half_width := GOAL_HALF_WIDTH) -> Array:
	var s := 1.0 if side >= 0.0 else -1.0
	var half := maxf(goal_half_width - POST_INSET, 0.4)
	var near_z := s * half
	var near_point := Vector3(goal.x - POST_DEPTH, 0.0, near_z)
	var far_point := Vector3(goal.x - POST_DEPTH, 0.0, -near_z)
	var spot_point := Vector3(goal.x - SPOT_DISTANCE, 0.0, 0.0)
	return [
		{"id": NEAR_POST, "label": "1ER PALO", "point": near_point, "height": POST_HEIGHT},
		{"id": FAR_POST, "label": "2º PALO", "point": far_point, "height": POST_HEIGHT},
		{"id": PENALTY_SPOT, "label": "PUNTO PENAL", "point": spot_point, "height": SPOT_HEIGHT},
	]


## Zona concreta por su id; si no existe, devuelve la primera (el primer palo).
static func zone_by_id(zones: Array, id: String) -> Dictionary:
	for z: Dictionary in zones:
		if String(z.get("id", "")) == id:
			return z
	return zones[0] if not zones.is_empty() else {}


## Punto de una zona concreta, sin tener que recorrer la lista.
static func point_for(goal: Vector3, side: float, id: String,
		goal_half_width := GOAL_HALF_WIDTH) -> Vector3:
	var z := zone_by_id(targets(goal, side, goal_half_width), id)
	return z.get("point", goal) if not z.is_empty() else goal


## Altura del centro para una zona concreta.
static func height_for(id: String) -> float:
	return SPOT_HEIGHT if id == PENALTY_SPOT else POST_HEIGHT


static func label_for(id: String) -> String:
	match id:
		NEAR_POST:
			return "1ER PALO"
		FAR_POST:
			return "2º PALO"
		PENALTY_SPOT:
			return "PUNTO PENAL"
	return ""


## ¿Es una de las tres zonas válidas?
static func is_valid(id: String) -> bool:
	return id == NEAR_POST or id == FAR_POST or id == PENALTY_SPOT


## Id de la zona más cercana a un punto del área (útil para depurar y para
## comprobar que el jugador atacó el palo elegido).
static func nearest_id(point: Vector3, zones: Array) -> String:
	var best := ""
	var best_d := INF
	for z: Dictionary in zones:
		var p: Vector3 = z.get("point", Vector3.ZERO)
		var d := Vector2(p.x - point.x, p.z - point.z).length()
		if d < best_d:
			best_d = d
			best = String(z.get("id", ""))
	return best
