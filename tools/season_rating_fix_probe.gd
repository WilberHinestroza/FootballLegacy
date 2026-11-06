extends Node

## Prueba dirigida: "me dieron un 10 cuando mi rendimiento fue de 7.6" —
## SeasonReportEngine.player_rating() usaba player.season_appearances
## (TITULARIDADES nada más) como denominador de "goles+asistencias por
## partido" — con pocos partidos "vistos" por la fórmula pese a haber
## jugado muchos más de verdad (como suplente), la involucración por
## partido se inflaba y la nota se disparaba. Ahora usa
## season_matches_played (partidos jugados de verdad). Compara la MISMA
## producción (10 goles, 5 asistencias) atribuida a 12 "partidos" (el
## bug: solo titularidades) contra 30 partidos (el total real jugado) —
## la nota con 30 debería ser más moderada, no tocar el techo de 10.
##   godot --headless res://tools/SeasonRatingFixProbe.tscn

func _ready() -> void:
	var ok: bool = true

	var table: Array = [
		{"club_id": "c_2_0", "pos": 3},
		{"club_id": "c_2_1", "pos": 1},
	]
	var objective_progress: Dictionary = {"met": false}

	var p_few := PlayerData.new()
	p_few.club_id = "c_2_0"
	p_few.position = "MF"
	p_few.coach_trust = 50
	p_few.season_appearances = 12
	p_few.season_matches_played = 12 # sin el bug: coincide con appearances
	p_few.season_goals = 10
	p_few.season_key_passes = 5

	var p_many := PlayerData.new()
	p_many.club_id = "c_2_0"
	p_many.position = "MF"
	p_many.coach_trust = 50
	p_many.season_appearances = 12 # mismas titularidades...
	p_many.season_matches_played = 30 # ...pero jugó 30 partidos de verdad (18 de suplente)
	p_many.season_goals = 10
	p_many.season_key_passes = 5

	var rating_few: float = SeasonReportEngine.player_rating(p_few, table, objective_progress)
	var rating_many: float = SeasonReportEngine.player_rating(p_many, table, objective_progress)
	print("misma producción (10G/5A), 12 partidos jugados: nota = %.2f" % rating_few)
	print("misma producción (10G/5A), 30 partidos jugados: nota = %.2f (debería ser MENOR, no tocar el techo)" % rating_many)

	if rating_many >= rating_few:
		print("FALLA: haber jugado más partidos con la misma producción debería dar una nota MENOR (menos gol/asistencia por partido), no igual o mayor")
		ok = false
	if rating_many >= 9.9:
		print("FALLA: con 30 partidos jugados de verdad, la nota no debería seguir pegada al techo de 10")
		ok = false

	# Texto del resumen también debe reflejar los partidos JUGADOS, no
	# solo las titularidades.
	var summary: String = SeasonReportEngine.player_summary_text(p_many, table)
	print("resumen de temporada: '%s'" % summary)
	if summary.find("30 partidos") < 0:
		print("FALLA: el resumen debería decir '30 partidos', no las titularidades")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
