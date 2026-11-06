extends Node

## Prueba dirigida de Match._competition_label_text() (Parte 92c, pedido de
## Wilber: "en los partidos, arriba del marcador que aparezca el nombre de
## la competición, si tiene jornada en qué jornada va"). Solo prueba la
## lógica de texto (sin nodos @onready, mismo patrón que
## match_national_fixture_probe.gd) contra cada tipo de fixture real.
##   godot --headless res://tools/MatchCompetitionHeaderProbe.tscn

func _ready() -> void:
	var problems: int = 0
	var m = (load("res://scenes/Match/Match.gd") as GDScript).new()

	MatchState.fixture = {"competition": "league", "home_club_id": "club_a", "away_club_id": "club_b", "matchday": 14}
	# liga: necesita encontrar la liga del club del usuario -> sin mundo
	# cargado cae a "Liga" genérico, no debe crashear.
	var t_league: String = m._competition_label_text()
	print("liga: '%s'" % t_league)
	if t_league == "":
		problems += 1

	MatchState.fixture = {"competition": "cup", "home_club_id": "club_a", "away_club_id": "club_b", "round_name": "Cuartos de Final"}
	var t_cup: String = m._competition_label_text()
	print("copa: '%s' (esperado que incluya 'Cuartos de Final')" % t_cup)
	if not t_cup.contains("Cuartos de Final"):
		problems += 1

	MatchState.fixture = {"competition": "friendly", "home_club_id": "club_a", "away_club_id": "club_b"}
	var t_friendly: String = m._competition_label_text()
	print("amistoso: '%s'" % t_friendly)
	if t_friendly == "":
		problems += 1

	MatchState.fixture = {"competition": "continental", "home_club_id": "club_a", "away_club_id": "club_b", "cont_conf": "UEFA", "cont_tier": 1}
	var t_cont: String = m._competition_label_text()
	print("continental: '%s' (esperado 'Liga de Campeones de Europa')" % t_cont)
	if t_cont != "Liga de Campeones de Europa":
		problems += 1

	MatchState.fixture = {"competition": "supercup", "home_club_id": "club_a", "away_club_id": "club_b", "name": "Supercopa de España"}
	var t_super: String = m._competition_label_text()
	print("supercopa: '%s'" % t_super)
	if t_super != "Supercopa de España":
		problems += 1

	MatchState.fixture = {"competition": "cwc", "home_club_id": "club_a", "away_club_id": "club_b"}
	var t_cwc: String = m._competition_label_text()
	print("mundial de clubes: '%s'" % t_cwc)
	if t_cwc == "":
		problems += 1

	MatchState.fixture = {"competition": "world_cup", "home_country": "Argentina", "away_country": "Brasil"}
	var t_wc: String = m._competition_label_text()
	print("mundial selección: '%s' (esperado 'Mundial')" % t_wc)
	if t_wc != "Mundial":
		problems += 1

	MatchState.fixture = {"competition": "qualifying", "home_country": "Argentina", "away_country": "Brasil"}
	var t_qual: String = m._competition_label_text()
	print("eliminatoria: '%s' (esperado 'Eliminatoria')" % t_qual)
	if t_qual != "Eliminatoria":
		problems += 1

	print("PROBE ", "OK" if problems == 0 else "FAIL (%d)" % problems)
	get_tree().quit(1 if problems > 0 else 0)
