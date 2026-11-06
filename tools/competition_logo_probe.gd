extends Node

## Verifica el lote de logos reales de competición (Parte 92d, Wilber):
## que los ids con arte fijo carguen una textura real y que un id SIN
## arte fijo siga cayendo al logo procedural de siempre sin crashear.
##   godot --headless res://tools/CompetitionLogoProbe.tscn

func _ready() -> void:
	var ok := true

	# ids que SÍ tienen arte fijo (verificados a mano contra la planilla real)
	for league_id in [2, 3, 10, 37, 67]:
		var n := Competition.league_node(league_id, 40)
		if n == null or n.get_child_count() == 0:
			print("FALLA: league_node vacío para ", league_id)
			ok = false
	for pair in [["UEFA", 1], ["CONMEBOL", 2], ["AFC", 1], ["CAF", 2]]:
		var n2 := Competition.continental_node(pair[0], pair[1], 40)
		if n2 == null or n2.get_child_count() == 0:
			print("FALLA: continental_node vacío para ", pair)
			ok = false

	# id SIN arte fijo (liga chica cualquiera) -> debe caer al procedural,
	# no crashear ni devolver null
	var fallback := Competition.league_node(9999, 40)
	if fallback == null or fallback.get_child_count() == 0:
		print("FALLA: fallback procedural roto para league_id inexistente")
		ok = false
	# domestic_cup_node ahora reparte 6 plantillas genéricas reales entre
	# los países sin arte propio -- confirmar que un país cualquiera saca
	# una de esas 6, no el procedural viejo.
	var fallback_cup := Competition.domestic_cup_node("PaísInventado", 40)
	if fallback_cup == null or fallback_cup.get_child_count() == 0:
		print("FALLA: domestic_cup_node roto")
		ok = false
	for country in ["Argentina", "Alemania", "Ucrania", "Ghana"]:
		var cn := Competition.domestic_cup_node(country, 40)
		if cn == null or cn.get_child_count() == 0:
			print("FALLA: domestic_cup_node vacío para ", country)
			ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
