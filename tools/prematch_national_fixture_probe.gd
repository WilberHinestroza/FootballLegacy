extends Node

## Prueba dirigida de PreMatch.gd con un partido de SELECCIÓN (Parte 91g,
## seguimiento de "nada distinto" — la previa recién ahora llega a verse
## para un partido de selección, porque antes Hub/Calendar ni la
## alcanzaban). Nada de esto CRASHEABA antes (Kit/Venue ya toleran
## club=null con defaults), pero se veía genérico: mismo celeste fijo
## para cualquier país, sin bandera, "Liga" como etiqueta de competencia.
##
## Llama los métodos de PreMatch.gd directo sobre una instancia sin
## agregarla al árbol (nunca dispara _ready(), así que los @onready de
## nodos de UI no importan — ninguno de los métodos probados los toca;
## _render() en sí SÍ los toca y no se prueba acá, igual que
## MatchNationalFixtureProbe hizo con Match.gd).
##   godot --headless res://tools/PreMatchNationalFixtureProbe.tscn

func _ready() -> void:
	var problems: int = 0
	var pm = (load("res://scenes/PreMatch/PreMatch.gd") as GDScript).new()

	var fx: Dictionary = {"competition": "world_cup", "home_country": "Argentina", "away_country": "Brasil"}
	var is_nat: bool = pm._is_national_fixture(fx)
	print("_is_national_fixture(): %s (esperado true)" % is_nat)
	if not is_nat:
		problems += 1

	var stub: ClubData = pm._country_kit_stub("Argentina")
	print("_country_kit_stub(): club_id=%s primary_color_hex=%s" % [stub.club_id, stub.primary_color_hex])
	if stub.club_id != "Argentina" or stub.primary_color_hex.is_empty():
		print("FALLA 1: el club de mentira para la camiseta no quedó bien armado")
		problems += 1

	# El mismo país debe dar SIEMPRE el mismo color (determinista) y dos
	# países distintos deben dar colores distintos (no todos genéricos).
	var stub2: ClubData = pm._country_kit_stub("Argentina")
	var stub_brasil: ClubData = pm._country_kit_stub("Brasil")
	print("determinismo: %s | distinto de Brasil: %s" % [stub.primary_color_hex == stub2.primary_color_hex, stub.primary_color_hex != stub_brasil.primary_color_hex])
	if stub.primary_color_hex != stub2.primary_color_hex:
		print("FALLA 2: el color del país no es determinista")
		problems += 1
	if stub.primary_color_hex == stub_brasil.primary_color_hex:
		print("FALLA 3: Argentina y Brasil dieron el mismo color (debería ser rarísimo)")
		problems += 1

	# _team_panel() no debe crashear y debe usar la BANDERA (no un
	# escudo en blanco) cuando el club es null y el fixture es selección.
	var home_team := MatchTeam.new()
	home_team.team_name = "Argentina"
	var panel: Control = pm._team_panel("home", home_team, null, false, fx)
	print("_team_panel() de selección armó un Control: %s" % (panel != null))
	if panel == null:
		print("FALLA 4: _team_panel crasheó o no devolvió nada para un fixture de selección")
		problems += 1

	# _competition_header() debe etiquetar bien la competencia de
	# selección (antes caía siempre a "Liga").
	var world: Dictionary = {}
	var header: Control = pm._competition_header(fx, world)
	var header_text: String = ""
	if header != null:
		for c in header.get_children():
			if c is Label and String(c.text) != "·":
				header_text = String(c.text)
				break
	print("_competition_header() texto: '%s' (esperado 'Mundial')" % header_text)
	if header_text != "Mundial":
		print("FALLA 5: la cabecera de competencia no distingue un Mundial de selección")
		problems += 1

	# --- Fixture de CLUB: cero cambio de comportamiento ---
	var fx_club: Dictionary = {"home_club_id": "a", "away_club_id": "b"}
	var is_nat_club: bool = pm._is_national_fixture(fx_club)
	print("_is_national_fixture() en fixture de club: %s (esperado false)" % is_nat_club)
	if is_nat_club:
		problems += 1

	print("PROBE ", "OK" if problems == 0 else "FAIL (%d)" % problems)
	get_tree().quit(1 if problems > 0 else 0)
