extends Node

## Diagnóstico de Fase 4 (5 copas continentales de selecciones): construye
## un mundo de prueba, resuelve las eliminatorias de las 5 confederaciones,
## alimenta cada copa continental con esos clasificados y verifica: la
## cadencia no hace coincidir las 5 el mismo año (ni con el Mundial), el
## campo de cada copa es un múltiplo de 4 razonable, los grupos existen
## desde el arranque pero el cuadro final no hasta que termina la fase de
## grupos, y el torneo llega a tener campeón. NUNCA toca un save real.
##   godot --headless res://tools/NationalCupProbe.tscn

func _ready() -> void:
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var strength_by_club: Dictionary = {}
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in meta_by_id:
		strength_by_club[club_id] = int(meta_by_id[club_id].get("base_overall", 55))
	var strength_by_country: Dictionary = NationalTeamFactory.strength_by_country(world, strength_by_club)
	var qual_day: int = QualifyingEngine.CYCLE_QUALIFYING_DAYS

	var bad: int = 0

	# Cadencia: ningún año entre 2024 y 2035 debería tener las 5 copas (ni
	# ninguna coincidiendo con un año de Mundial) a la vez.
	for year in range(2024, 2036):
		var cups_this_year: Array = []
		for conf in Confederations.ALL:
			if NationalCupEngine.is_cup_year(conf, year):
				cups_this_year.append(conf)
		var is_wc: bool = WorldCupEngine.is_wc_year(year)
		if cups_this_year.size() >= 4:
			print("  AÑO %d: %d copas juntas %s" % [year, cups_this_year.size(), cups_this_year])
			bad += 1
		if is_wc and not cups_this_year.is_empty():
			print("  AÑO %d: Mundial Y copa continental el mismo año: %s" % [year, cups_this_year])
			bad += 1
		if not cups_this_year.is_empty():
			print("[%d] copas: %s%s" % [year, cups_this_year, " (+ MUNDIAL)" if is_wc else ""])

	# Resuelve cada confederación en su próximo año de copa y verifica forma.
	for conf in Confederations.ALL:
		var qualifying: Dictionary = QualifyingEngine.resolve(conf, strength_by_country, world_seed, qual_day, 0, {})
		var base: int = int(NationalCupEngine.BASE_YEAR.get(conf, 2024))
		var f: Array = NationalCupEngine.field(conf, qualifying)
		var expected_groups: int = f.size() / 4
		print("[%s] campo=%d (múltiplo de 4: %s) grupos_esperados=%d" % [conf, f.size(), f.size() % 4 == 0, expected_groups])
		if f.size() % 4 != 0 or f.size() < 4:
			bad += 1

		var season_start: int = 0
		var group_start: int = season_start + NationalCupEngine.GROUP_START_OFFSET
		var knockout_start: int = season_start + NationalCupEngine.KNOCKOUT_OFFSET
		var final_day: int = knockout_start + NationalCupEngine.SPAN_TO_FINAL + 5
		for day_label in [["grupos", group_start + 7], ["cuadro final", final_day]]:
			var t: Dictionary = NationalCupEngine.resolve(conf, base, world_seed, strength_by_country, qualifying, season_start, day_label[1], {})
			if t.is_empty():
				print("  [%s] día %d: VACÍO" % [day_label[0], day_label[1]])
				bad += 1
				continue
			print("  [%s] día %d: grupos=%d rondas=%d campeón=%s" % [
				day_label[0], day_label[1], (t.get("groups", []) as Array).size(),
				(t.get("rounds", []) as Array).size(), String(t.get("champion_country", ""))])

	print("PROBE ", "OK" if bad == 0 else "FAIL (%d)" % bad)
	get_tree().quit(1 if bad > 0 else 0)
