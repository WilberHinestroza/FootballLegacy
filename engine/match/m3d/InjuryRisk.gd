extends RefCounted
## Lesiones de TU jugador en el partido 3D (antes el 3D nunca lesionaba: solo los
## partidos simulados). Mismo criterio que MatchEngine: un riesgo pequeño por
## minuto que se dispara si apuraste la vuelta de una lesión (recaída) y que el
## vendaje preventivo de la Tienda reduce. Además, en el 3D una falta que recibes
## puede lesionarte: más si es en plancha o si llegas fundido.
## Funciones puras: no tocan nodos ni UI.

## Por minuto en el campo (MatchEngine reparte 0,003/min entre 22 jugadores).
const PER_MINUTE := 0.003 / 22.0
## Recaída por minuto si apuraste la vuelta (igual que MatchEngine:
## ENV_INJURY_CHANCE_PER_MINUTE * (REINJURY_MULT - 1) * 0.5).
const REINJURY_PER_MINUTE := 0.003
## Una falta sobre ti: normal / en plancha.
const FOUL := 0.03
const FOUL_SLIDE := 0.07
## Fundido (energía 0) multiplica el riesgo hasta por esto.
const TIRED_MAX_MULT := 2.5
const REINJURY_FOUL_MULT := 3.0


static func _tired_mult(stamina: float) -> float:
	return lerpf(TIRED_MAX_MULT, 1.0, clampf(stamina, 0.0, 1.0))


## Probabilidad de lesionarte en un minuto simulado.
static func minute_chance(stamina: float, reinjury: bool, shield: bool) -> float:
	var c := PER_MINUTE * _tired_mult(stamina)
	if reinjury:
		c += REINJURY_PER_MINUTE
	if shield:
		c *= ShopEngine.BANDAGE_RISK_FACTOR
	return c


## Probabilidad de que la falta que te hacen te lesione.
static func foul_chance(slide: bool, stamina: float, reinjury: bool, shield: bool) -> float:
	var c := (FOUL_SLIDE if slide else FOUL) * _tired_mult(stamina)
	if reinjury:
		c *= REINJURY_FOUL_MULT
	if shield:
		c *= ShopEngine.BANDAGE_RISK_FACTOR
	return clampf(c, 0.0, 0.6)
