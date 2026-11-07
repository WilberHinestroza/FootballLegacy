extends RefCounted
## Ajuste de las decisiones de la IA 3D por atributos (P1-33 / P1-34).
##
## Funciones puras: reciben atributos normalizados (0..1) y devuelven tiempos o
## probabilidades. No tocan nodos, UI ni estado global, así que se pueden probar
## en headless y reutilizar desde cualquier capa. La idea es que compañeros y
## rivales decidan distinto según quiénes son, en toda la jugada: con balón,
## apoyo, marca, presión, balón suelto y portero.

## Multiplicador del retraso entre decisiones: el que lee mejor el juego
## decide antes (0,7×) y el que lee peor tarda más (1,3×).
static func decision_delay_scale(decision_making: float) -> float:
	return lerpf(1.3, 0.7, clampf(decision_making, 0.0, 1.0))


## Probabilidad de que un compañero te dé el pase en tu jugada cuando estás
## libre. Mejor passing + lectura = la ve antes y la juega más.
static func star_pass_chance(passing: float, decision_making: float) -> float:
	return lerpf(0.48, 0.74, clampf(passing * 0.6 + decision_making * 0.4, 0.0, 1.0))


## Probabilidad de centro al área en tu jugada (banda + tu jugador en el área).
static func star_cross_chance(passing: float, composure: float) -> float:
	return lerpf(0.42, 0.70, clampf(passing * 0.7 + composure * 0.3, 0.0, 1.0))


## Probabilidad de que un compañero resuelva solo (tiro) si tú no estás libre.
static func star_solo_shot_chance(shooting: float, composure: float) -> float:
	return lerpf(0.28, 0.52, clampf(shooting * 0.7 + composure * 0.3, 0.0, 1.0))


## Probabilidad de tirar desde `dist` metros: el que define mejor se anima más
## y el que está lejos se anima menos.
static func shot_chance(shooting: float, composure: float, dist: float) -> float:
	var skill := clampf(shooting * 0.6 + composure * 0.4, 0.0, 1.0)
	var base := lerpf(0.52, 0.82, skill)
	var far := clampf((dist - 12.0) / 18.0, 0.0, 1.0)
	return clampf(base - far * 0.14, 0.30, 0.85)


## Probabilidad de centro desde la banda en juego abierto.
static func wing_cross_chance(passing: float, composure: float) -> float:
	return lerpf(0.22, 0.40, clampf(passing * 0.7 + composure * 0.3, 0.0, 1.0))


## Probabilidad de soltar el pase bajo presión (o para mover el balón).
static func pressure_pass_chance(passing: float, decision_making: float) -> float:
	return lerpf(0.08, 0.20, clampf(passing * 0.5 + decision_making * 0.5, 0.0, 1.0))


## Distancia a la que se ofrece el mediocampista: mejor passing/lectura encuentra
## el hueco un poco más lejos del portador.
static func support_distance(passing: float, decision_making: float) -> float:
	return lerpf(5.5, 7.5, clampf(passing * 0.5 + decision_making * 0.5, 0.0, 1.0))


## Metros que pica el delantero por delante del último defensor: la velocidad
## decide cuánto se atreve a estirar la línea.
static func run_depth(speed: float, decision_making: float) -> float:
	return lerpf(0.5, 1.8, clampf(speed * 0.6 + decision_making * 0.4, 0.0, 1.0))


## Distancia de marcaje al hombre peligroso: más cerca cuanto mejor defiende.
static func mark_tightness(decision_making: float, speed: float, danger_dist: float) -> float:
	var base := lerpf(1.8, 0.7, clampf(decision_making * 0.6 + speed * 0.4, 0.0, 1.0))
	var tier := 0.55 if danger_dist < 12.0 else (0.75 if danger_dist < 18.0 else 1.0)
	return clampf(base * tier, 0.55, 1.8)


## Multiplicador de la probabilidad de entrar al portador: lectura + fuerza.
static func press_bias(decision_making: float, strength: float) -> float:
	return lerpf(0.6, 1.4, clampf(decision_making * 0.6 + strength * 0.4, 0.0, 1.0))


## Probabilidad de que la entrada sea plancha: la disciplina la baja.
static func slide_bias(decision_making: float, composure: float) -> float:
	var discipline := clampf(decision_making * 0.6 + composure * 0.4, 0.0, 1.0)
	return lerpf(0.55, 0.18, discipline)


## Peso que le da el pasador al espacio libre al elegir receptor: mejor passing
## ve más y prefiere al hombre desmarcado.
static func vision_weight(passing: float) -> float:
	return lerpf(0.55, 1.0, clampf(passing, 0.0, 1.0))


## Anticipación del balón suelto: el que lee mejor arranca antes (0,75×..1,25×
## sobre el tiempo de intercepción).
static func loose_ball_anticipation(decision_making: float) -> float:
	return lerpf(1.25, 0.75, clampf(decision_making, 0.0, 1.0))


## Fuera de juego · error del desmarque (m) al esperar en la línea: el que lee bien
## se queda medio metro antes; el que lee mal a veces se pasa (y queda adelantado).
## Se vuelve a sortear cada pocos segundos por jugador (ver AiBrain._hold_onside).
static func offside_slack(decision_making: float, roll: float) -> float:
	var read := clampf(decision_making, 0.0, 1.0)
	return lerpf(-0.2, -0.9, read) + roll * lerpf(1.6, 0.5, read)


## Fuera de juego · probabilidad de que el pasador vea que el compañero está
## adelantado y no se la dé (con poca visión, a veces se la da igual).
static func offside_awareness(passing: float, decision_making: float) -> float:
	return lerpf(0.55, 0.95, clampf(passing * 0.5 + decision_making * 0.5, 0.0, 1.0))


## Fuera de juego · probabilidad de que la defensa salga a la vez para dejar en
## fuera de juego al delantero (línea adelantada) cuando el rival va a pasar.
static func offside_trap_chance(decision_making: float) -> float:
	return lerpf(0.15, 0.6, clampf(decision_making, 0.0, 1.0))
