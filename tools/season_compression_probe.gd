extends Node

## Prueba dirigida de la compresión de calendario en años de Mundial/copa
## continental (segunda vuelta del Item 1 de "hazlo todo" — Parte 82
## revirtió el intento de BLOQUEAR el calendario de club durante el
## Mundial por el riesgo de pisar jornadas en curso; esta vuelta en cambio
## ACORTA el span ANTES de generar los fixtures, sin ese problema).
## Construye un mundo real, arma la temporada de una liga UEFA en un año
## de Mundial y en un año normal, y confirma que:
##  1) año de Mundial: ninguna jornada de liga ni ronda de copa doméstica
##     cae DENTRO del bloque del Mundial (Parte 91p: movido al FRENTE de
##     la temporada — ver SeasonCalendar.world_cup_blackout_for_season() —
##     así que el bloqueo real ya NO es "antes del día 250", es el rango
##     [GROUP_START_OFFSET, KNOCKOUT_OFFSET+SPAN_TO_FINAL+5] de
##     WorldCupEngine, con margen antes del cierre de temporada, día 365).
##     2026 nunca coincide con un año de copa CONTINENTAL para ninguna
##     confederación (mod 4 distinto a propósito, ver Confederations) —
##     por eso el único bloqueo real que importa acá es el del Mundial.
##  2) año normal: el span vuelve a ser el de siempre (280) — sin regresión.
##   godot --headless res://tools/SeasonCompressionProbe.tscn

func _ready() -> void:
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var uefa_league: LeagueData = null
	for lg in world.get("leagues", []):
		if lg.tier == 1 and Confederations.confederation_of(lg.country) == "UEFA":
			uefa_league = lg
			break
	if uefa_league == null:
		print("PROBE FAIL (no se encontró liga UEFA tier 1 en este mundo)")
		get_tree().quit(1)
		return

	var problems: int = 0

	# --- Año de Mundial (2026) ---
	var season_wc: Dictionary = SeasonCalendar.build_season(world, uefa_league.league_id, 0, SeasonCalendar.WORLD_CUP_BASE_YEAR, "", world_seed)
	var wc_block_start: int = WorldCupEngine.GROUP_START_OFFSET
	var wc_block_end: int = WorldCupEngine.KNOCKOUT_OFFSET + WorldCupEngine.SPAN_TO_FINAL + 5
	var first_league_wc: int = _min_epoch_day(season_wc.get("league_fixtures", []))
	var last_league_wc: int = _max_epoch_day(season_wc.get("league_fixtures", []))
	var first_cup_wc: int = _min_cup_day(season_wc.get("cup", {}))
	var last_cup_wc: int = _max_cup_day(season_wc.get("cup", {}))
	print("Bloque del Mundial: día %d a %d" % [wc_block_start, wc_block_end])
	print("Año de Mundial (%d): liga día %d-%d, copa doméstica día %d-%d" % [
		SeasonCalendar.WORLD_CUP_BASE_YEAR, first_league_wc, last_league_wc, first_cup_wc, last_cup_wc])
	if first_league_wc <= wc_block_end and last_league_wc >= wc_block_start:
		print("FALLA 1: alguna jornada de liga cae DENTRO del bloque del Mundial")
		problems += 1
	if first_cup_wc <= wc_block_end and last_cup_wc >= wc_block_start and first_cup_wc > 0:
		print("FALLA 2: alguna ronda de copa doméstica cae DENTRO del bloque del Mundial")
		problems += 1
	if last_league_wc >= 365 or last_cup_wc >= 365:
		print("FALLA 2b: la temporada de Mundial no terminó antes del cierre (día 365)")
		problems += 1

	# --- Año normal (2029: ni Mundial ni copa continental de UEFA) ---
	var normal_year: int = 2029
	if SeasonCalendar.is_national_tournament_year("UEFA", normal_year):
		print("PROBE FAIL (2029 no debería ser año de torneo para UEFA — revisar el año de prueba)")
		get_tree().quit(1)
		return
	var season_normal: Dictionary = SeasonCalendar.build_season(world, uefa_league.league_id, 0, normal_year, "", world_seed)
	var last_league_normal: int = _max_epoch_day(season_normal.get("league_fixtures", []))
	print("Año normal (%d): última J liga=día %d (se espera cerca del span normal, ~315)" % [normal_year, last_league_normal])
	if last_league_normal < 280:
		print("FALLA 3: en un año normal el calendario se acortó también (regresión) — última J día %d" % last_league_normal)
		problems += 1

	print("PROBE ", "OK" if problems == 0 else "FAIL (%d)" % problems)
	get_tree().quit(1 if problems > 0 else 0)

func _max_epoch_day(fixtures: Array) -> int:
	var m: int = 0
	for fx in fixtures:
		m = maxi(m, int(fx.get("epoch_day", 0)))
	return m

func _min_epoch_day(fixtures: Array) -> int:
	var m: int = 999999
	for fx in fixtures:
		m = mini(m, int(fx.get("epoch_day", 999999)))
	return 0 if fixtures.is_empty() else m

func _max_cup_day(cup: Dictionary) -> int:
	var m: int = 0
	for rnd in cup.get("rounds", []):
		m = maxi(m, int(rnd.get("epoch_day", 0)))
	return m

func _min_cup_day(cup: Dictionary) -> int:
	var rounds: Array = cup.get("rounds", [])
	if rounds.is_empty():
		return 0
	var m: int = 999999
	for rnd in rounds:
		m = mini(m, int(rnd.get("epoch_day", 999999)))
	return m
