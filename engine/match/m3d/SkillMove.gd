extends RefCounted
## Jugadas de lujo (P1-06): rabona, sombrero, elástica y bicicleta.
##
## Funciones puras: clasifican el dibujo del gesto (los puntos de pantalla) y
## devuelven el nombre de la jugada, su costo de stamina y su probabilidad de
## salir bien. Son gestos de alto riesgo y alta recompensa: si salen, dejan al
## rival fuera de la jugada; si no, te dejan expuesto.
##
## No toca nodos ni UI: se prueba en headless y lo usa el partido 3D.

## Largo mínimo (px) para que un gesto cuente como jugada de lujo.
const MIN_LENGTH := 100.0
## Giro acumulado (grados) que delata una bicicleta (círculo completo).
const LOOP_TURN := 250.0
## Ángulo (grados) entre la salida y la llegada que delata una elástica (V).
const REVERSAL_DEG := 110.0
## Giro acumulado (grados) que delata una rabona (curva de un solo lado).
const CURVE_DEG := 65.0
## Cuánto (px) tiene que subir el arco del sombrero sobre sus extremos.
const ARCH_RISE := 32.0
## Ventana del arco: el punto más alto debe caer en el medio del gesto.
const ARCH_FROM := 0.2
const ARCH_TO := 0.8

## Costo de stamina de cada jugada.
const COSTS := {"elastica": 0.05, "bicicleta": 0.04, "sombrero": 0.07, "rabona": 0.06, "enganche": 0.03}


## Clasifica el gesto. Devuelve "" si es un gesto normal (tiro, pase, regate).
static func classify(points: PackedVector2Array) -> String:
	if points.size() < 3:
		return ""
	var total := _path_length(points)
	if total < MIN_LENGTH:
		return ""
	var turn := _total_turn(points)
	if absf(turn) >= LOOP_TURN and total >= MIN_LENGTH * 2.0:
		return "bicicleta"
	var first := _dir_between(points, 0.0, 0.3)
	var last := _dir_between(points, 0.7, 1.0)
	if first != Vector2.ZERO and last != Vector2.ZERO \
			and rad_to_deg(absf(first.angle_to(last))) >= REVERSAL_DEG:
		return "elastica"
	if _is_arch(points, total):
		return "sombrero"
	if absf(turn) >= CURVE_DEG:
		return "rabona"
	return ""


## Probabilidad de que la jugada salga bien. `defender_duel` es 0..1.
static func success_chance(move: String, dribbling: float, control: float,
		passing: float, defender_duel: float) -> float:
	var d := clampf(dribbling, 0.0, 1.0)
	var c := clampf(control, 0.0, 1.0)
	var p := clampf(passing, 0.0, 1.0)
	var def := clampf(defender_duel, 0.0, 1.0)
	var chance := 0.5
	match move:
		"elastica":
			chance = 0.55 + d * 0.4 - def * 0.2
		"bicicleta":
			chance = 0.6 + d * 0.3 - def * 0.15
		"sombrero":
			chance = 0.45 + c * 0.35 + d * 0.2 - def * 0.25
		"rabona":
			chance = 0.5 + p * 0.35 + c * 0.2 - def * 0.2
		"enganche": # pisar y salir: control y regate, contra un rival que llega lanzado
			chance = 0.52 + c * 0.25 + d * 0.25 - def * 0.25
	return clampf(chance, 0.2, 0.92)


static func stamina_cost(move: String) -> float:
	return float(COSTS.get(move, 0.0))


## Curva del balón para la rabona: el lado hacia el que se dibuja el gesto.
static func rabona_curl(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0
	var first := _dir_between(points, 0.0, 0.3)
	var last := _dir_between(points, 0.7, 1.0)
	if first == Vector2.ZERO or last == Vector2.ZERO:
		return 0.0
	# Producto cruz: positivo si el gesto gira a un lado y negativo al otro.
	var cross := first.x * last.y - first.y * last.x
	return 0.6 * signf(cross)


# ---------- geometría del gesto ----------

static func _path_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	return total


## Giro acumulado (grados, con signo) entre tramos consecutivos.
static func _total_turn(points: PackedVector2Array) -> float:
	var turn := 0.0
	var prev := Vector2.ZERO
	var has_prev := false
	for i in range(1, points.size()):
		var seg := points[i] - points[i - 1]
		if seg.length() < 3.0:
			continue
		var d := seg.normalized()
		if has_prev:
			turn += rad_to_deg(prev.angle_to(d))
		prev = d
		has_prev = true
	return turn


## Dirección media entre dos fracciones del recorrido.
static func _dir_between(points: PackedVector2Array, from_frac: float, to_frac: float) -> Vector2:
	var total := _path_length(points)
	if total < 0.001:
		return Vector2.ZERO
	var a := _point_at(points, from_frac * total)
	var b := _point_at(points, to_frac * total)
	if a.distance_to(b) < 1.0:
		return Vector2.ZERO
	return (b - a).normalized()


static func _point_at(points: PackedVector2Array, target: float) -> Vector2:
	var walked := 0.0
	for i in range(1, points.size()):
		var seg := points[i].distance_to(points[i - 1])
		if walked + seg >= target:
			var t := (target - walked) / maxf(seg, 0.001)
			return points[i - 1].lerp(points[i], t)
		walked += seg
	return points[points.size() - 1]


## Arco: sube, llega a un punto alto en el medio y vuelve a bajar. Un arco
## tendido (no una V cerrada) es un sombrero; si el gesto vuelve muy cerrado
## sobre sí mismo, se clasifica como elástica.
static func _is_arch(points: PackedVector2Array, total: float) -> bool:
	var first_dir := _dir_between(points, 0.0, 0.3)
	var last_dir := _dir_between(points, 0.7, 1.0)
	if first_dir == Vector2.ZERO or last_dir == Vector2.ZERO:
		return false
	if rad_to_deg(absf(first_dir.angle_to(last_dir))) >= REVERSAL_DEG:
		return false
	var top := points[0]
	var top_i := 0
	for i in points.size():
		if points[i].y < top.y:
			top = points[i]
			top_i = i
	var first := points[0]
	var last := points[points.size() - 1]
	if top.y > minf(first.y, last.y) - ARCH_RISE:
		return false
	var frac := float(top_i) / float(maxi(points.size() - 1, 1))
	if frac < ARCH_FROM or frac > ARCH_TO:
		return false
	# El arco no debe ser un simple círculo: eso ya es bicicleta.
	return total <= MIN_LENGTH * 2.0 or absf(_total_turn(points)) < LOOP_TURN
