extends RefCounted
## ¿Qué quiso hacer el jugador con el dedo? (7-nov, Wilber: "puede pasar que un amague
## o regate se confunda con tirar"). Antes solo contaba la DIRECCIÓN del gesto: todo lo
## que apuntara a menos de ~63° de la portería era tiro, así que un regate en diagonal
## hacia delante o un toquecito para avanzar salían como disparo.
## Ahora cuentan también LARGO y VELOCIDAD del gesto (en fracción del alto de pantalla):
## para tirar hay que deslizar con intención; lo corto y suave es regate/conducción.
## Funciones puras, sin nodos.

const SHOT := "shot"
const DODGE := "dodge"
const HOOK := "hook" # enganche: hacia atrás

## Hacia la portería por encima de esto puede ser tiro; por debajo, regate.
const SHOT_DOT := 0.45
## Zona dudosa (diagonal): hasta aquí hace falta un gesto largo o rápido para tirar.
const DIAGONAL_DOT := 0.75
## Gesto corto (fracción del alto de pantalla) y lento (fracción/seg).
const SHORT_LEN := 0.16
const DIAGONAL_LEN := 0.26
const FAST_SPEED := 1.6
## Dentro de esta distancia a la portería, un gesto corto hacia ella es tiro colocado.
const FINESSE_DIST := 16.0


static func classify(dot_to_goal: float, len_frac: float, speed_frac: float, dist_to_goal: float) -> String:
	if dot_to_goal < -0.55:
		return HOOK
	if dot_to_goal < SHOT_DOT:
		return DODGE
	var fast := speed_frac >= FAST_SPEED
	if dot_to_goal < DIAGONAL_DOT and len_frac < DIAGONAL_LEN and not fast:
		return DODGE # en diagonal y sin intención de golpeo: te vas del rival
	if len_frac < SHORT_LEN and not fast and dist_to_goal > FINESSE_DIST:
		return DODGE # toquecito hacia delante lejos del área: conducción, no tiro
	return SHOT
