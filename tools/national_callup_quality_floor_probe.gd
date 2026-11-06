extends Node

## Prueba dirigida: "me convocaron a la selección Colombia con una media
## de 55, eso no es normal" — NationalCallUpEngine.call_up_probability()
## daba convocatoria 100% GARANTIZADA a cualquiera que rankeara dentro
## del cupo de su línea (rank <= slots), sin mirar el nivel ABSOLUTO —
## en un país con pool flojo (mucho relleno sintético débil), un overall
## mediocre podía rankear 1º igual. Ahora hace falta además superar
## TransferMarketEngine.TIER_NORMAL_MIN (65) para la garantía.
##   godot --headless res://tools/NationalCallupQualityFloorProbe.tscn

func _ready() -> void:
	var ok: bool = true

	# Caso reportado: rankea 1º en su línea (dentro del cupo) pero con un
	# overall flojo (55, por debajo del piso 65) -> YA NO debería ser 1.0.
	var p_weak: float = NationalCallUpEngine.call_up_probability(1, "MF", 55, 0.5, 55)
	print("rank=1, overall=55 (debajo del piso): probability=%.3f (NO debería ser 1.0)" % p_weak)
	if p_weak >= 1.0:
		print("FALLA: sigue dando convocatoria garantizada con overall flojo")
		ok = false
	if p_weak <= 0.0:
		print("FALLA: no debería ser 0 duro — sigue siendo el mejor disponible")
		ok = false

	# Mismo rank, overall que SÍ supera el piso -> convocatoria garantizada.
	var p_ok: float = NationalCallUpEngine.call_up_probability(1, "MF", 55, 0.5, 70)
	print("rank=1, overall=70 (supera el piso): probability=%.3f (esperado 1.0)" % p_ok)
	if p_ok != 1.0:
		print("FALLA: con nivel aceptable debería seguir siendo garantizada")
		ok = false

	# Justo en el piso (65) -> garantizada (>=, no solo >).
	var p_edge: float = NationalCallUpEngine.call_up_probability(1, "MF", 55, 0.5, 65)
	print("rank=1, overall=65 (justo el piso): probability=%.3f (esperado 1.0)" % p_edge)
	if p_edge != 1.0:
		ok = false

	# Fuera del cupo (rank alto) con overall alto -> sigue la curva de
	# siempre, el piso no debería afectar este caso para nada.
	var p_far: float = NationalCallUpEngine.call_up_probability(20, "MF", 80, 0.8, 90)
	print("rank=20 (fuera del cupo), overall=90: probability=%.3f (curva normal, <1.0)" % p_far)
	if p_far >= 1.0:
		print("FALLA: fuera del cupo nunca debería ser garantizada")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
