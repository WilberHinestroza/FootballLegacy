extends RefCounted
## Datos de tu partido, como en las retransmisiones: km recorridos, sprints, xG de
## tus remates y mapa de calor. Funciones puras: no tocan nodos ni UI.
##
## Los km se ESTIMAN (el 3D va comprimido en el tiempo: medir la distancia tal cual
## daría cifras ridículas): base de tu puesto por minuto jugado, tu resistencia y
## cuánto esprintaste de verdad en el 3D.

## Km por 90' de un jugador medio de cada puesto.
const KM_PER_90 := {"GK": 5.4, "DF": 9.9, "MF": 11.1, "ST": 10.2}
## Mapa de calor: celdas a lo largo (de tu portería a la rival) y a lo ancho.
const HEAT_COLS := 12
const HEAT_ROWS := 8


## Km del partido. sprint_ratio = fracción del tiempo en tus jugadas que fuiste
## esprintando (0..1); stamina_stat 0..1.
static func km(role: String, minutes_played: float, stamina_stat: float, sprint_ratio: float) -> float:
	var base: float = float(KM_PER_90.get(role, 10.0))
	var k := base * lerpf(0.9, 1.1, clampf(stamina_stat, 0.0, 1.0)) * (1.0 + clampf(sprint_ratio, 0.0, 1.0) * 0.12)
	return snappedf(k * clampf(minutes_played, 0.0, 130.0) / 90.0, 0.1)


## xG de un remate: distancia (m) a la portería y ángulo que abren los postes.
## kind: "open", "penalty" o "free_kick".
static func shot_xg(dist: float, angle_rad: float, kind: String) -> float:
	if kind == "penalty":
		return 0.76
	var x := 1.0 + 0.11 * dist - 1.6 * angle_rad
	var xg := 1.0 / (1.0 + exp(x))
	if kind == "free_kick":
		xg *= 0.45
	return clampf(xg, 0.01, 0.9)


## Ángulo (rad) que abre la portería desde `pos` (x a lo largo, z a lo ancho),
## con la portería centrada en (goal_x, 0) y 7,32 m de ancho.
static func goal_angle(pos: Vector2, goal_x: float) -> float:
	var a := Vector2(goal_x, -3.66) - pos
	var b := Vector2(goal_x, 3.66) - pos
	return absf(a.angle_to(b))


## Celda del mapa de calor para una posición del campo vista desde tu equipo
## (x de -L/2 = tu portería a +L/2 = la rival; z a lo ancho).
static func heat_cell(x: float, z: float, length: float, width: float) -> int:
	var cx := clampi(int((x / length + 0.5) * HEAT_COLS), 0, HEAT_COLS - 1)
	var cz := clampi(int((z / width + 0.5) * HEAT_ROWS), 0, HEAT_ROWS - 1)
	return cz * HEAT_COLS + cx


static func empty_heat() -> Array:
	var a: Array = []
	a.resize(HEAT_COLS * HEAT_ROWS)
	a.fill(0)
	return a
