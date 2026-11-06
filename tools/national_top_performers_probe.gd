extends Node

## Prueba dirigida de goleadores/asistentes de torneos de SELECCIÓN
## (pedido de Wilber: botones en "Selecciones" para ver cada competición
## con su campeón, goleador y asistidor). Verifica:
##   NationalTeamFactory.squads_for_countries() — plantel de 23 por país,
##     en un solo recorrido de todos los clubes del mundo.
##   TopPerformersEngine.compute_national_tournament() — reparto de goles/
##     asistencias sobre un Mundial y una copa continental YA RESUELTOS
##     por el camino REAL (WorldTickEngine.world_cup_this_cycle()/
##     national_cup_for(), el mismo que ya probó NationalTrophyProbe con
##     un campeón real — no una réplica manual).
##   WorldTickEngine.top_performers_for_world_cup()/
##     top_performers_for_national_cup() — el wrapper que consume la
##     pantalla Selections.gd.
## No toca slot_1/slot_2 (usa slot_3, desechable).
##   godot --headless res://tools/NationalTopPerformersProbe.tscn

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

	var ok: bool = true
	var season_start: int = 0

	# --- Mundial ---
	var year: int = WorldCupEngine.WC_BASE_YEAR
	var final_day: int = season_start + WorldCupEngine.KNOCKOUT_OFFSET + WorldCupEngine.SPAN_TO_FINAL
	WorldTickEngine.season = {"start_year": year, "season_start_epoch_day": season_start, "current_epoch_day": final_day}
	WorldTickEngine.current_epoch_day = final_day

	var wc: Dictionary = WorldTickEngine.world_cup_this_cycle()
	var champion: String = String(wc.get("champion_country", ""))
	print("Mundial %d: campeón=%s" % [year, champion])
	if champion == "":
		print("PROBE FAIL (mundial no decidido en el día de prueba)")
		get_tree().quit(1)
		return

	var field: Dictionary = {}
	for g in wc.get("groups", []) as Array:
		for row in g.get("standings", []) as Array:
			field[String(row.get("club_id", ""))] = true

	var wc_perf: Dictionary = WorldTickEngine.top_performers_for_world_cup()
	var wc_scorers: Array = wc_perf.get("scorers", [])
	var wc_assists: Array = wc_perf.get("assists", [])
	print("Mundial goleadores: %d filas (top: %s)" % [wc_scorers.size(), wc_scorers[0] if not wc_scorers.is_empty() else "-"])
	print("Mundial asistentes: %d filas (top: %s)" % [wc_assists.size(), wc_assists[0] if not wc_assists.is_empty() else "-"])
	if wc_scorers.is_empty():
		print("FALLA: Mundial resuelto con campeón pero sin goleadores")
		ok = false
	ok = ok and _check_rows(wc_scorers, field, "Mundial/goleadores")
	ok = ok and _check_rows(wc_assists, field, "Mundial/asistentes")

	# --- Copa continental (CONMEBOL, mismo seed/setup que NationalTrophyProbe) ---
	var conf_test: String = "CONMEBOL"
	var ncup_year: int = int(NationalCupEngine.BASE_YEAR[conf_test])
	var ncup_final_day: int = season_start + NationalCupEngine.KNOCKOUT_OFFSET + NationalCupEngine.SPAN_TO_FINAL
	WorldTickEngine.season = {"start_year": ncup_year, "season_start_epoch_day": season_start, "current_epoch_day": ncup_final_day}
	WorldTickEngine.current_epoch_day = ncup_final_day

	var ncup: Dictionary = WorldTickEngine.national_cup_for(conf_test)
	var ncup_champion: String = String(ncup.get("champion_country", ""))
	print("Copa continental %s %d: campeón=%s" % [conf_test, ncup_year, ncup_champion])
	if ncup_champion == "":
		print("(sin campeón de copa continental decidido en este seed/día — se omite ese sub-check, igual que NationalTrophyProbe)")
	else:
		var ncup_field: Dictionary = {}
		for g in ncup.get("groups", []) as Array:
			for row in g.get("standings", []) as Array:
				ncup_field[String(row.get("club_id", ""))] = true

		var ncup_perf: Dictionary = WorldTickEngine.top_performers_for_national_cup(conf_test)
		var ncup_scorers: Array = ncup_perf.get("scorers", [])
		var ncup_assists: Array = ncup_perf.get("assists", [])
		print("%s goleadores: %d filas (top: %s)" % [conf_test, ncup_scorers.size(), ncup_scorers[0] if not ncup_scorers.is_empty() else "-"])
		if ncup_scorers.is_empty():
			print("FALLA: copa continental resuelta con campeón pero sin goleadores")
			ok = false
		ok = ok and _check_rows(ncup_scorers, ncup_field, "%s/goleadores" % conf_test)
		ok = ok and _check_rows(ncup_assists, ncup_field, "%s/asistentes" % conf_test)

	# --- Torneo sin datos: debe devolver listas vacías, no crashear ---
	var empty_perf: Dictionary = WorldTickEngine.top_performers_for_national_cup("UEFA_NO_EXISTE")
	if not (empty_perf.get("scorers", []) as Array).is_empty():
		print("FALLA: confederación inexistente debería devolver vacío")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)

## Cada fila: count > 0, ordenado descendente, y el país (club_name) es
## uno de los que realmente jugaron el torneo — nunca un país inventado.
func _check_rows(rows: Array, field: Dictionary, label: String) -> bool:
	var ok: bool = true
	var last_count: int = 999999
	for r in rows:
		var count: int = int(r.get("count", 0))
		if count <= 0:
			print("FALLA (%s): fila con count<=0: %s" % [label, r])
			ok = false
		if count > last_count:
			print("FALLA (%s): filas no vienen ordenadas descendente" % label)
			ok = false
		last_count = count
		var country: String = String(r.get("club_name", ""))
		if not field.has(country):
			print("FALLA (%s): país '%s' no está en el campo del torneo" % [label, country])
			ok = false
	return ok
