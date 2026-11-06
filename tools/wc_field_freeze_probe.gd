extends Node

## Prueba dirigida de 2 pedidos de Wilber sobre el Mundial:
##   1. "miré y quedó campeón Alemania, a la siguiente que miré quedó
##      campeón Argentina y todo el torneo fue distinto — qué está
##      pasando?" — BUG REAL: world_cup_this_cycle()/national_cup_for()
##      recalculaban el campo de clasificados EN VIVO cada vez, así que
##      el torneo entero podía cambiar después de ya resuelto. Ahora se
##      congela la primera vez (SaveManager.load_international()).
##   2. "por qué no haces el mundial inicial con las selecciones de este
##      reciente mundial?" — WorldCupEngine.REAL_WC_2026_FIELD, los 48
##      países reales del Mundial 2026 de verdad.
## No toca slot_1/slot_2 (usa slot_3, desechable).
##   godot --headless res://tools/WcFieldFreezeProbe.tscn

func _ready() -> void:
	var ok: bool = true

	# --- 1) El campo real de 2026 tiene 48 países, sin duplicados, y
	# todos con confederación asignada (Curazao/Nueva Zelanda recién
	# agregados a los mapas de país -> confederación) ---
	var field: Array = WorldCupEngine.REAL_WC_2026_FIELD
	print("REAL_WC_2026_FIELD: %d países" % field.size())
	if field.size() != 48:
		print("FALLA: se esperaban 48 países, salieron %d" % field.size())
		ok = false
	var seen: Dictionary = {}
	for c in field:
		if seen.has(c):
			print("FALLA: país duplicado en el campo real: %s" % c)
			ok = false
		seen[c] = true
		var conf: String = Confederations.confederation_of(String(c))
		if conf == "":
			print("FALLA: '%s' no tiene confederación asignada (Confederations.COUNTRY_TO_CONFEDERATION)" % c)
			ok = false
	if not Countries.ALL.has("Curazao"):
		print("FALLA: Curazao no está en Countries.ALL")
		ok = false

	# --- 2) El campo se congela: world_cup_this_cycle() en 2 días
	# distintos (con la eliminatoria de fondo siguiendo su curso) debe
	# dar el MISMO campeón — antes cambiaba. ---
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
	var season_start: int = 0
	var final_day: int = season_start + WorldCupEngine.KNOCKOUT_OFFSET + WorldCupEngine.SPAN_TO_FINAL
	WorldTickEngine.season = {"start_year": WorldCupEngine.WC_BASE_YEAR, "season_start_epoch_day": season_start}

	WorldTickEngine.current_epoch_day = final_day
	var wc1: Dictionary = WorldTickEngine.world_cup_this_cycle()
	var champ1: String = String(wc1.get("champion_country", ""))
	print("Mundial 2026 (día %d): campeón=%s" % [final_day, champ1])

	WorldTickEngine.current_epoch_day = final_day + 300 # mucho después, la eliminatoria de fondo siguió corriendo
	var wc2: Dictionary = WorldTickEngine.world_cup_this_cycle()
	var champ2: String = String(wc2.get("champion_country", ""))
	print("Mundial 2026 (día %d, mucho después): campeón=%s" % [final_day + 300, champ2])

	if champ1 == "" or champ2 == "":
		print("FALLA: el Mundial no dio campeón en alguna de las 2 consultas")
		ok = false
	elif champ1 != champ2:
		print("FALLA: el campeón CAMBIÓ entre las 2 consultas (%s -> %s) — el campo no se congeló" % [champ1, champ2])
		ok = false

	# El campo usado debe ser el REAL (confirmando que se usó
	# REAL_WC_2026_FIELD y no una eliminatoria recién arrancada).
	var group_countries: Dictionary = {}
	for g in wc1.get("groups", []) as Array:
		for row in g.get("standings", []) as Array:
			group_countries[String(row.get("club_id", ""))] = true
	print("¿Curazao en el campo?=%s  ¿Nueva Zelanda?=%s  ¿Irak?=%s" % [
		group_countries.has("Curazao"), group_countries.has("Nueva Zelanda"), group_countries.has("Irak")])
	if not (group_countries.has("Curazao") and group_countries.has("Nueva Zelanda") and group_countries.has("Irak")):
		print("FALLA: el Mundial 2026 no usó el campo real (faltan países que sí jugaron de verdad)")
		ok = false

	# --- 3) Copa continental: mismo chequeo de congelado ---
	var conf_test: String = "CONMEBOL"
	var ncup_year: int = int(NationalCupEngine.BASE_YEAR[conf_test])
	var ncup_final_day: int = season_start + NationalCupEngine.KNOCKOUT_OFFSET + NationalCupEngine.SPAN_TO_FINAL
	WorldTickEngine.season = {"start_year": ncup_year, "season_start_epoch_day": season_start}
	WorldTickEngine.current_epoch_day = ncup_final_day
	var nc1: Dictionary = WorldTickEngine.national_cup_for(conf_test)
	var nchamp1: String = String(nc1.get("champion_country", ""))
	WorldTickEngine.current_epoch_day = ncup_final_day + 300
	var nc2: Dictionary = WorldTickEngine.national_cup_for(conf_test)
	var nchamp2: String = String(nc2.get("champion_country", ""))
	print("Copa %s %d: campeón día %d=%s, día %d=%s" % [conf_test, ncup_year, ncup_final_day, nchamp1, ncup_final_day + 300, nchamp2])
	if nchamp1 == "":
		print("(sin campeón de copa continental decidido en este seed/día — se omite ese sub-check)")
	elif nchamp1 != nchamp2:
		print("FALLA: el campeón de la copa continental CAMBIÓ entre las 2 consultas")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
