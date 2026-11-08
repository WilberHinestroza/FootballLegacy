extends Node

## Prueba dirigida del pedido de Wilber: "en las fechas FIFA también
## deberían tener marcadas solo los dos partidos de esa fecha FIFA y no
## toda la semana" — antes Calendar._event_for_day() pintaba los 10 días
## de CUALQUIER ventana FIFA con el mismo rótulo genérico "Fecha FIFA —
## selecciones", tuvieras o no partido programado ESE día puntual. Ahora
## solo se pintan los días donde QualifyingEngine.user_fixture_today()
## encuentra un partido real de la selección del usuario.
## Instancia el SCRIPT suelto (Calendar.gd no tiene class_name) y llama
## _event_for_day() directo — no toca ningún nodo @onready para eso,
## mismo criterio de siempre en esta sesión.
##   godot --headless res://tools/CalendarFifaWindowProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var strength_by_club: Dictionary = {}
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in meta_by_id:
		strength_by_club[club_id] = int(meta_by_id[club_id].get("base_overall", 55))

	WorldTickEngine.world = world
	WorldTickEngine.world_seed = world_seed
	WorldTickEngine._strength_by_club = strength_by_club
	WorldTickEngine.season = {"start_year": 2026, "season_start_epoch_day": 0}
	WorldTickEngine.current_epoch_day = 100

	var cal_script: GDScript = load("res://scenes/Calendar/Calendar.gd")
	var cal = cal_script.new()
	cal._club_id = "c_1_0" # cualquier id, no hace falta que sea real para esta rama
	cal._today_epoch_day = 999999 # bien lejos, así ningún día de prueba cae en "hoy"
	cal._nat_country = "Argentina"
	var confederation: String = Confederations.confederation_of("Argentina")
	cal._nat_qualifying = WorldTickEngine.national_qualifying_for(confederation)

	var ok: bool = true

	# Busca el primer día CON partido real de Argentina dentro de una
	# ventana FIFA, y confirma que los días vecinos de la MISMA ventana
	# (sin partido) ya NO se pintan.
	var match_day: int = -1
	# El ciclo de eliminatorias arranca ~2 años antes del Mundial (Parte 93), no el día 0.
	var cyc: int = WorldTickEngine._international_cycle_start()
	# is_day_in_international_window solo mira la temporada cargada: se carga la del ciclo.
	var cyc_year: int = CalendarUtils.season_start_year(cyc)
	WorldTickEngine.season = {"start_year": cyc_year, "season_start_epoch_day": CalendarUtils.date_to_epoch_day(cyc_year, CalendarUtils.SEASON_START_MONTH, 1)}
	for day in range(cyc, cyc + 400):
		if not WorldTickEngine.is_day_in_international_window(day):
			continue
		var fx: Dictionary = QualifyingEngine.user_fixture_today(cal._nat_qualifying, "Argentina", day)
		if not fx.is_empty():
			match_day = day
			break
	if match_day < 0:
		print("PROBE FAIL (no se encontró ningún día de partido real de Argentina en los 400 primeros días del ciclo — ¿cambió el reparto de ventanas?)")
		get_tree().quit(1)
		return
	print("día de partido real de Argentina: %d" % match_day)

	var ev_match: Dictionary = cal._event_for_day(match_day)
	print("evento del día del partido: %s" % ev_match)
	if ev_match.is_empty():
		print("FALLA: el día CON partido real debería marcarse")
		ok = false

	# Busca, en la MISMA ventana de 10 días que match_day, un día SIN
	# partido real de Argentina — no debería marcarse ya más.
	var empty_day: int = -1
	for d in range(match_day - 9, match_day + 10):
		if not WorldTickEngine.is_day_in_international_window(d):
			continue
		var fx_d: Dictionary = QualifyingEngine.user_fixture_today(cal._nat_qualifying, "Argentina", d)
		if fx_d.is_empty():
			empty_day = d
			break
	if empty_day < 0:
		print("(cada día de esta ventana tenía partido real — se omite ese sub-check)")
	else:
		var ev_empty: Dictionary = cal._event_for_day(empty_day)
		print("evento del día %d (misma ventana, sin partido real): %s" % [empty_day, "vacío" if ev_empty.is_empty() else ev_empty])
		if not ev_empty.is_empty():
			print("FALLA: un día de la ventana SIN partido real ya no debería marcarse")
			ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
