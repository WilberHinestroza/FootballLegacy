extends RefCounted
## Balones por el aire (7-nov): no todo es cabezazo. Según la altura a la que
## llega, lo rápido que viene, si hay un rival encima, si es un pase de los suyos
## y la zona, el jugador elige: cabezazo, control de pecho, de muslo, de empeine,
## volea o esperar a que baje. Se decide UNA vez por jugador y por balón (ver
## SoccerMatch._aerial_choice) para que no cambie de idea a mitad del vuelo.
##
## Funciones puras: no toca nodos ni UI; se prueba en headless.

const HEADER := "header"
const CHEST := "chest"
const THIGH := "thigh"
const INSTEP := "instep"
const VOLLEY := "volley"
const LET_DROP := "let_drop"
const BICYCLE := "bicycle"
## Chilena: altura (m) del balón y rival a más de esto (m) para poder tumbarse.
const BICYCLE_MIN := 1.35
const BICYCLE_MAX := 2.3
const BICYCLE_RIVAL := 1.0
const CONTROLS := [CHEST, THIGH, INSTEP]

## Más rápido que esto (m/s) no se puede amortiguar: cabezazo o despeje.
const MAX_CONTROL_SPEED := 18.0
## Con un rival a menos de esto (m) no hay tiempo de bajarla si viene alta.
const PRESSURE_DIST := 1.4
## Alturas (m) del balón al llegar: pecho / muslo / empeine.
const CHEST_MIN := 1.15
const THIGH_MIN := 0.8
const INSTEP_MIN := 0.3
const BODY_MAX := 1.95
## Volea: altura (m) a la que se le puede pegar en el aire.
const VOLLEY_MIN := 0.35
const VOLLEY_MAX := 1.25


## `y` = altura prevista al llegar, `speed` = velocidad del balón, `rival_d` = rival
## más cercano al jugador, `own_pass` = el balón viene de un compañero, `att_box` = está
## cerca de la portería rival para rematar, `def_box` = en su área, `control` 0..1,
## `roll` 0..1 (una tirada por balón).
static func choose(y: float, speed: float, rival_d: float, own_pass: bool, att_box: bool,
		def_box: bool, control: float, roll: float, back_to_goal := false, flair := 0.0) -> String:
	# Rematar: cerca del arco rival el balón se ataca, no se controla
	if att_box:
		# De espaldas y a la altura justa: el atrevido se tumba y la engancha de chilena
		if back_to_goal and y >= BICYCLE_MIN and y <= BICYCLE_MAX and rival_d > BICYCLE_RIVAL \
				and roll < bicycle_chance(flair):
			return BICYCLE
		if y >= VOLLEY_MIN and y <= VOLLEY_MAX and rival_d > 0.9:
			return VOLLEY
		if y > 1.4:
			return HEADER
	# En su área con el rival encima: fuera, de cabeza (o como salga)
	if def_box and not own_pass and rival_d < 3.0:
		return HEADER if y > 1.3 else INSTEP
	if speed > MAX_CONTROL_SPEED:
		return HEADER if y > 1.4 else INSTEP
	if y > BODY_MAX:
		# Muy alto: si nadie aprieta, deja que baje y la controla de pecho
		return LET_DROP if rival_d > 2.2 else HEADER
	if y > 1.4 and rival_d < PRESSURE_DIST:
		return HEADER
	# Un despeje rival sin nadie cerca: el que sabe la baja; el resto la reventaba
	if not own_pass and y > 1.4 and roll > lerpf(0.35, 0.9, clampf(control, 0.0, 1.0)):
		return HEADER
	if y >= CHEST_MIN:
		return CHEST
	if y >= THIGH_MIN:
		return THIGH
	return INSTEP


## Probabilidad de intentar la chilena (`flair` 0..1 = regate y técnica).
static func bicycle_chance(flair: float) -> float:
	return lerpf(0.08, 0.55, clampf(flair, 0.0, 1.0))


static func is_control(choice: String) -> bool:
	return choice in CONTROLS or choice == LET_DROP


## Altura máxima a la que ese control alcanza el balón (m).
static func reach_height(choice: String) -> float:
	match choice:
		CHEST, LET_DROP:
			return BODY_MAX
		THIGH:
			return 1.3
		INSTEP:
			return 0.98
	return 0.95
