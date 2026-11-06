extends Node

## Prueba dirigida del bug real reportado por Wilber (Parte 88): "no es
## normal que hayan 2 partidos de liga en un fin de semana uno después
## del otro". Causa raíz: en una temporada COMPRIMIDA (años de Mundial/
## copa continental, TOURNAMENT_YEAR_SEASON_SPAN_DAYS=205, Parte 84) el
## paso entre jornadas baja de la semana justa (~5.4 días en vez de
## ~7.4), y _snap_to_weekdays solo garantizaba "un día más tarde que la
## jornada anterior" — nada impedía que 2 jornadas cayeran sábado+domingo
## del MISMO fin de semana. Fix: _snap_league_matchday mete la jornada
## ENTRE SEMANA cuando el fin de semana natural queda pegado a la
## anterior. Verifica en un mundo real: 0 pares de jornadas consecutivas
## con menos de 5 días de diferencia, tanto en una temporada NORMAL
## (span=280, regresión — no debería cambiar nada) como en una
## COMPRIMIDA (span=205, donde antes SÍ fallaba).
##   godot --headless res://tools/LeagueMidweekProbe.tscn

func _ready() -> void:
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var league: LeagueData = null
	for lg in world.get("leagues", []):
		if lg.tier == 1:
			league = lg
			break
	var clubs: Array = world.get("clubs_by_league", {}).get(league.league_id, [])
	var club_ids: Array = clubs.map(func(c): return c.club_id)

	var problems: int = 0
	problems += _check_span("NORMAL sin blackout", club_ids, league, SeasonCalendar.SEASON_SPAN_DAYS, [])
	problems += _check_span("COMPRIMIDA (año de torneo)", club_ids, league, SeasonCalendar.TOURNAMENT_YEAR_SEASON_SPAN_DAYS, [])
	# El escenario REAL que probablemente reportó Wilber: temporada normal
	# CON los recesos de siempre (mercado de invierno + 5 ventanas FIFA) —
	# _snap_to_weekdays empuja de golpe por encima de un blackout entero
	# (hasta 21 días de un salto), y la SIGUIENTE jornada (objetivo
	# independiente de esa jornada empujada) puede caer pegada al nuevo
	# día post-blackout. No hace falta una temporada comprimida para que
	# pase esto — pasa TODAS las temporadas.
	var real_blackouts: Array = [SeasonCalendar._mid_season_blackout(0)]
	real_blackouts.append_array(SeasonCalendar.international_windows_for_season(0))
	problems += _check_span("NORMAL con blackouts reales", club_ids, league, SeasonCalendar.SEASON_SPAN_DAYS, real_blackouts)

	print("PROBE ", "OK" if problems == 0 else "FAIL (%d)" % problems)
	get_tree().quit(1 if problems > 0 else 0)

func _check_span(label: String, club_ids: Array, league: LeagueData, span: int, blackout: Array = []) -> int:
	var fixtures: Array = SeasonCalendar.build_league_fixtures(club_ids, league, 0, span, SeasonCalendar.LEAGUE_WEEKDAYS, blackout)
	var days_by_matchday: Dictionary = {}
	for fx in fixtures:
		var md: int = int(fx["matchday"])
		days_by_matchday[md] = int(fx["epoch_day"])
	var mds: Array = days_by_matchday.keys()
	mds.sort()

	var violations: int = 0
	var midweek_used: int = 0
	var min_gap: int = 999
	for i in range(1, mds.size()):
		var gap: int = int(days_by_matchday[mds[i]]) - int(days_by_matchday[mds[i - 1]])
		min_gap = mini(min_gap, gap)
		if gap < SeasonCalendar.MIN_LEAGUE_MATCHDAY_GAP:
			violations += 1
			print("  [%s] jornadas %d->%d: solo %d día(s) de diferencia (día %d -> %d)" % [
				label, mds[i - 1], mds[i], gap, int(days_by_matchday[mds[i - 1]]), int(days_by_matchday[mds[i]])])
		var wd: int = CalendarUtils.weekday_of_epoch_day(int(days_by_matchday[mds[i]]))
		if wd in SeasonCalendar.MIDWEEK_DAYS:
			midweek_used += 1

	print("[%s] span=%d jornadas=%d min_gap=%d violaciones(<%dd)=%d entre-semana-usadas=%d" % [
		label, span, mds.size(), min_gap, SeasonCalendar.MIN_LEAGUE_MATCHDAY_GAP, violations, midweek_used])
	return violations
