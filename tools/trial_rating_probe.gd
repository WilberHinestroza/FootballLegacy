extends Node

## Prueba dirigida del bug real reportado por Wilber: "mi prueba siempre
## es un 6.5 aunque mi nota de ese partido fuera un 9". Causa raíz:
## MatchSummary._on_continue_pressed() SIEMPRE llama MatchState.clear()
## (vacía match_result) ANTES de navegar a Offers.tscn, que leía la nota
## desde match_result — ya vacío, caía siempre al valor por defecto de
## Dictionary.get() (MatchRatingCalculator.BASE_RATING=6.5). Fix: nuevo
## MatchState.last_user_rating, que clear() NO toca. No se puede
## instanciar Offers.gd de verdad (usa @onready) así que esto prueba el
## mecanismo de MatchState directamente + el cálculo de generate_offers()
## con una nota alta real en vez de 6.5.
##   godot --headless res://tools/TrialRatingProbe.tscn

func _ready() -> void:
	var ok: bool = true

	# --- 1) MatchState.last_user_rating sobrevive a clear(), match_result no ---
	MatchState.match_result = {"user_rating": 9.0}
	MatchState.last_user_rating = 9.0
	MatchState.clear()
	print("tras clear(): match_result=%s last_user_rating=%.1f" % [MatchState.match_result, MatchState.last_user_rating])
	if not MatchState.match_result.is_empty():
		print("FALLA: match_result debería quedar vacío tras clear() (comportamiento de siempre)")
		ok = false
	if MatchState.last_user_rating != 9.0:
		print("FALLA: last_user_rating debería sobrevivir a clear() con el valor real (9.0)")
		ok = false

	# --- 2) Con la nota real (9.0) las ofertas deberían ser mejores que
	# con la nota atascada (6.5) — confirma que el bug SÍ afectaba el
	# balance de ofertas, no solo el número que se mostraba en pantalla ---
	var p := PlayerData.new()
	p.player_name = "Probe Prueba"
	p.overall = 60
	p.potential = 75
	p.position = "MF"
	p.country = "Argentina"
	var world: Dictionary = WorldFactory.build(20260906)

	# generate_offers() no es determinista a propósito (RNG real, ver su
	# comentario) — se promedia sobre 25 tiradas para que la comparación
	# no sea ruido.
	var rep_stuck: float = _avg_rep_over_trials(p, MatchRatingCalculator.BASE_RATING, world, 25)
	var rep_real: float = _avg_rep_over_trials(p, 9.0, world, 25)
	print("reputación media de ofertas con nota atascada (6.5), 25 tiradas: %.1f" % rep_stuck)
	print("reputación media de ofertas con nota real (9.0), 25 tiradas: %.1f" % rep_real)
	# Umbral modesto a propósito: generate_offers() usa MUESTREO PONDERADO
	# (no un filtro duro), así que el promedio real regresa bastante hacia
	# la disponibilidad de ligas del mundo — lo que importa acá es la
	# DIRECCIÓN (9.0 > 6.5), no una brecha exacta.
	if rep_real <= rep_stuck:
		print("FALLA: una prueba de 9.0 debería dar ofertas de nivel mejor que una de 6.5, en promedio")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)

func _avg_rep_over_trials(p: PlayerData, trial_rating: float, world: Dictionary, trials: int) -> float:
	var total: float = 0.0
	var n: int = 0
	for i in range(trials):
		var offers: Array = CareerSetup.generate_offers(p, trial_rating, world)
		for o in offers:
			total += float(o.get("reputation", 0))
			n += 1
	return total / float(maxi(n, 1))
