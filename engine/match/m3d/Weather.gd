extends RefCounted
## Clima del partido 3D (7-nov): despejado o lluvia. La lluvia se ve (cielo gris,
## césped mojado que brilla, gotas, sonido) y se juega: el balón corre más sobre el
## césped mojado y patina al botar. Funciones puras, sin nodos.

const CLEAR := 0
const RAIN := 1

## Probabilidad de lluvia en un partido (de noche algo más: refresca).
const RAIN_CHANCE := 0.14
const RAIN_CHANCE_NIGHT := 0.2

## Rodando sobre mojado pierde menos velocidad (m/s² × esto).
const ROLL_RESIST_WET := 0.55


static func pick(time_of_day: int, roll: float) -> int:
	var chance := RAIN_CHANCE_NIGHT if time_of_day == 2 else RAIN_CHANCE
	return RAIN if roll < chance else CLEAR


static func roll_resist_mult(weather: int) -> float:
	return ROLL_RESIST_WET if weather == RAIN else 1.0
