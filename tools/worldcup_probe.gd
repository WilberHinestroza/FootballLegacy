extends Node

## Diagnóstico de Fase 3 (Mundial de selecciones): construye un mundo de
## prueba, resuelve las eliminatorias de las 5 confederaciones (Fase 1),
## alimenta WorldCupEngine con los clasificados y verifica que el torneo
## de 32 arma bien (campo completo, grupos → octavos → campeón según el
## día), sin crashear. NUNCA toca un save real.
##   godot --headless res://tools/WorldCupProbe.tscn

func _ready() -> void:
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var strength_by_club: Dictionary = {}
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in meta_by_id:
		strength_by_club[club_id] = int(meta_by_id[club_id].get("base_overall", 55))

	var strength_by_country: Dictionary = NationalTeamFactory.strength_by_country(world, strength_by_club)
	var qual_day: int = QualifyingEngine.CYCLE_QUALIFYING_DAYS # eliminatoria ya jugada entera
	var qualifying_by_conf: Dictionary = {}
	for conf in Confederations.ALL:
		qualifying_by_conf[conf] = QualifyingEngine.resolve(conf, strength_by_country, world_seed, qual_day, 0, {})
	var pool_by_conf: Dictionary = WorldCupEngine.pool_from_qualifying(qualifying_by_conf)

	var bad: int = 0
	var field: Array = WorldCupEngine.field(pool_by_conf)
	print("campo Mundial: %d países (esperado %d)" % [field.size(), WorldCupEngine.GROUPS * WorldCupEngine.PER_GROUP])
	if field.size() != WorldCupEngine.GROUPS * WorldCupEngine.PER_GROUP:
		bad += 1
	var dupes: Dictionary = {}
	for c in field:
		if dupes.has(c):
			bad += 1
			print("  DUPLICADO: ", c)
		dupes[c] = true

	# Gating por año: 2026/2030 sí, 2027/2028/2029 no.
	for year in [2025, 2026, 2027, 2028, 2029, 2030]:
		var is_yr: bool = WorldCupEngine.is_wc_year(year)
		var expected: bool = year == 2026 or year == 2030
		if is_yr != expected:
			bad += 1
			print("  año %d: is_wc_year=%s (esperado %s)" % [year, is_yr, expected])

	var season_start: int = 0
	var group_start: int = season_start + WorldCupEngine.GROUP_START_OFFSET
	var knockout_start: int = season_start + WorldCupEngine.KNOCKOUT_OFFSET
	var final_day: int = knockout_start + WorldCupEngine.SPAN_TO_FINAL + 5

	for day_label in [["antes de arrancar", 0], ["mitad de grupos", group_start + 7], ["fin de grupos (sin octavos aun)", group_start + 13], ["torneo resuelto", final_day]]:
		var label: String = day_label[0]
		var day: int = day_label[1]
		var t: Dictionary = WorldCupEngine.resolve(world_seed, 2026, strength_by_country, pool_by_conf, season_start, day, {})
		if t.is_empty():
			print("[%s] día %d: VACÍO" % [label, day])
			bad += 1
			continue
		var groups_count: int = (t.get("groups", []) as Array).size()
		var rounds_count: int = (t.get("rounds", []) as Array).size()
		var champion: String = String(t.get("champion_country", ""))
		print("[%s] día %d: grupos=%d rondas=%d campeón=%s" % [label, day, groups_count, rounds_count, champion])
		if groups_count != WorldCupEngine.GROUPS:
			bad += 1
		if rounds_count > 0 and rounds_count != 5:
			print("  ESPERABA 5 rondas (32 clasificados), salió %d" % rounds_count)
			bad += 1

	print("PROBE ", "OK" if bad == 0 else "FAIL (%d)" % bad)
	get_tree().quit(1 if bad > 0 else 0)
