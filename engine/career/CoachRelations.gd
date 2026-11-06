extends RefCounted
class_name CoachRelations

## Centraliza TODA la matemática de confianza jugador-entrenador — mismo
## principio que DecisionResolver para los momentos clave del partido: una
## sola fórmula, nunca dispersa por pantallas. Nunca dupliques estos
## cálculos en Hub ni en ningún otro sitio.

const TRUST_MIN := 0
const TRUST_MAX := 100
const TRUST_BASELINE := 50

## Cuánto cambia la confianza tras un partido, según la nota (1-10,
## MatchRatingCalculator) y lo exigente que sea el entrenador. Un
## entrenador más exigente (demanding alto) castiga más un partido malo y
## regala menos uno mediocre.
## `result`: +1 el equipo GANÓ, 0 empató, -1 perdió. Un DT real valora
## distinto un 6.0 en una victoria que en una derrota (pedido de Wilber:
## "las IAs más realistas"). El resultado pesa más si el DT es exigente.
static func trust_delta_for_rating(rating: float, coach: CoachData, result: int = 0) -> int:
	var demanding: float = float(coach.demanding) if coach != null else 50.0
	var severity: float = clampf(demanding / 50.0, 0.5, 2.0) # ~0.7..1.5 en la práctica

	var by_rating: int
	if rating >= 8.0:
		by_rating = int(round(9.0 / severity))
	elif rating >= 6.5:
		by_rating = int(round(3.0 / severity))
	elif rating >= 5.0:
		by_rating = 0
	elif rating >= 3.5:
		by_rating = int(round(-3.0 * severity))
	else:
		by_rating = int(round(-8.0 * severity))

	# Modificador por RESULTADO del equipo: ganar suma, perder resta —
	# más fuerte con un DT exigente. Una gran actuación en una derrota
	# igual te salva algo; una nota floja en una goleada a favor no te
	# hunde tanto.
	var by_result: int = 0
	if result > 0:
		by_result = int(round(2.0 * clampf(severity, 0.8, 1.6)))
	elif result < 0:
		by_result = int(round(-2.0 * clampf(severity, 0.8, 1.6)))

	return by_rating + by_result

## Techo "blando" para las SUBIDAS de confianza — cuanto más cerca de 100,
## menos rinde una buena actuación (nunca menos de un piso, para que
## siempre haya algo de movimiento). Las BAJADAS no se tocan: un mal
## partido pega igual de fuerte estés donde estés.
##
## BUG real encontrado en la auditoría del 12-sep (Wilber: "qué más hay
## que pulir"): sin este techo, un jugador que rinde bien seguido (rating
## ≥6.5 la mayoría de los partidos) pega el 100 en 1-2 temporadas y se
## queda ahí el RESTO de la carrera — el vínculo con el DT dejaba de
## sentirse vivo. Con el techo, un crack estable oscila alto (85-99) en
## vez de pegarse al techo, y una mala racha sí se nota.
const TRUST_GAIN_HEADROOM_FLOOR := 0.18

## Aplica el efecto de un partido jugado a la confianza (clamp 0-100).
static func apply_match_result(player: PlayerData, coach: CoachData, rating: float, result: int = 0) -> void:
	var delta: int = trust_delta_for_rating(rating, coach, result)
	if delta > 0:
		var headroom: float = float(TRUST_MAX - player.coach_trust) / float(TRUST_MAX - TRUST_MIN)
		var factor: float = clampf(headroom + TRUST_GAIN_HEADROOM_FLOOR, TRUST_GAIN_HEADROOM_FLOOR, 1.0)
		delta = maxi(1, int(round(float(delta) * factor)))
	player.coach_trust = clampi(player.coach_trust + delta, TRUST_MIN, TRUST_MAX)

## Probabilidad de que el entrenador te dé una oportunidad de titular pese
## a no ser de los 11 mejores por overall (favor del entrenador).
## 0 de confianza -> 0%; 50 (neutral) -> ~14%; 100 -> 40%.
static func start_chance(trust: int) -> float:
	var t: float = clampf(float(trust) / 100.0, 0.0, 1.0)
	return pow(t, 1.5) * 0.4

## NO CONVOCADO (9-oct, Wilber): con la confianza por el piso (chance de
## titular < 5%, ~confianza < 25) y sin méritos para los 9 suplentes, el DT
## te deja afuera de la lista. Recibe la chance FINAL (ya con favores del
## agente / promesa de titularidad, que te protegen).
const LEFT_OUT_BELOW := 0.05
static func can_be_left_out(final_start_chance: float) -> bool:
	return final_start_chance < LEFT_OUT_BELOW

## Frase corta del entrenador tras el partido, según su estilo y el mismo
## delta de confianza que ya calculó apply_match_result(). Puro sabor (no
## vuelve a tocar balance) — vive aquí porque usa ese mismo número.
static func reaction_quote(coach: CoachData, trust_delta: int) -> String:
	if coach == null:
		return ""
	if trust_delta >= 6:
		match coach.style:
			"Disciplinario":
				return "Por fin cumples con lo que exijo. Sigue así."
			"Paternal":
				return "Estoy muy orgulloso de ti hoy."
			"Exigente":
				return "Bien, pero no te relajes. Quiero más."
			"Cercano":
				return "¡Así se juega! Me alegro mucho por ti."
			_:
				return "Buen partido. Se nota el trabajo."
	if trust_delta <= -6:
		match coach.style:
			"Disciplinario":
				return "Esto es inaceptable. Espero una reacción ya."
			"Paternal":
				return "No te preocupes, todos tenemos días así."
			"Exigente":
				return "Necesito mucho más de ti la próxima vez."
			"Cercano":
				return "Hablemos con calma, esto se puede corregir."
			_:
				return "Partido flojo. Hay que mejorar."
	return "Correcto. Seguimos trabajando."
