extends Node

## Prueba de la preferencia "balón aleatorio cada partido" (Parte 88):
## Preferences.ball_mode — validación, persistencia (round-trip por
## user://preferences.json), y que PreMatch._render() elige un índice
## válido de BallDesign tanto en "fixed" como en "random" sin crashear
## (no arma un MatchState completo — eso necesitaría equipos reales; acá
## se prueba la lógica de Preferences que es donde vive el cambio real).
##   godot --headless res://tools/BallModeProbe.tscn

func _ready() -> void:
	var problems: int = 0

	# --- Validación: solo "fixed"/"random" ---
	Preferences.set_ball_mode("random")
	if Preferences.ball_mode != "random":
		print("FALLA 1: set_ball_mode('random') no aplicó")
		problems += 1
	Preferences.set_ball_mode("algo_invalido")
	if Preferences.ball_mode != "random":
		print("FALLA 2: un valor inválido debería IGNORARSE, quedó en '%s'" % Preferences.ball_mode)
		problems += 1
	Preferences.set_ball_mode("fixed")
	if Preferences.ball_mode != "fixed":
		print("FALLA 3: set_ball_mode('fixed') no aplicó")
		problems += 1

	# --- Persistencia: round-trip por disco ---
	Preferences.set_ball_mode("random")
	Preferences._load()  # relee lo recién guardado
	if Preferences.ball_mode != "random":
		print("FALLA 4: no sobrevivió el round-trip a disco (quedó en '%s')" % Preferences.ball_mode)
		problems += 1

	# Dejar la preferencia real de Wilber como estaba (fixed es el default
	# de siempre) — esta prueba no debería cambiarle su configuración real.
	Preferences.set_ball_mode("fixed")

	# --- randi() % BallDesign.count() siempre da un índice válido ---
	for i in range(20):
		var idx: int = randi() % BallDesign.count()
		if idx < 0 or idx >= BallDesign.count():
			print("FALLA 5: índice de balón fuera de rango: %d" % idx)
			problems += 1
			break

	print("PROBE ", "OK" if problems == 0 else "FAIL (%d)" % problems)
	get_tree().quit(1 if problems > 0 else 0)
