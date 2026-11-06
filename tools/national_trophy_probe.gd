extends Node

## Prueba dirigida de WorldTickEngine._tick_national_trophies() (Item 2,
## "hazlo todo": acreditar títulos de SELECCIÓN al gabinete del jugador).
## Arma un mundo real, fuerza el estado runtime del autoload al día de la
## final del Mundial (+2), consulta el campeón REAL vía
## WorldTickEngine.world_cup_this_cycle() (la misma función que usa el
## juego — no una réplica manual, que dio un resultado distinto en un
## primer intento por el orden en que se resuelve la eliminatoria; mejor
## confiar en la función real), pone al jugador de prueba en ESE país con
## national_team_status="regular", corre _tick_national_trophies() y
## confirma que career_titles/trophies_won/balance se acreditan — y que
## llamarlo una segunda vez NO duplica (dedupe por id+season).
## No toca slot_1/slot_2 (usa slot_3, desechable).
##   godot --headless res://tools/NationalTrophyProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var strength_by_club: Dictionary = {}
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in meta_by_id:
		strength_by_club[club_id] = int(meta_by_id[club_id].get("base_overall", 55))

	var year: int = WorldCupEngine.WC_BASE_YEAR
	var season_start: int = 0
	var final_day: int = season_start + WorldCupEngine.KNOCKOUT_OFFSET + WorldCupEngine.SPAN_TO_FINAL

	WorldTickEngine.world = world
	WorldTickEngine.world_seed = world_seed
	WorldTickEngine._strength_by_club = strength_by_club
	WorldTickEngine.season = {"start_year": year, "season_start_epoch_day": season_start, "current_epoch_day": final_day}
	WorldTickEngine.current_epoch_day = final_day

	var wc: Dictionary = WorldTickEngine.world_cup_this_cycle()
	var champion: String = String(wc.get("champion_country", ""))
	print("Campeón REAL del Mundial %d (seed %d): %s" % [year, world_seed, champion])
	if champion == "":
		print("PROBE FAIL (mundial no decidido en el día de prueba)")
		get_tree().quit(1)
		return

	var p := PlayerData.new()
	p.player_name = "Probe Mundial"
	p.country = champion
	p.position = "ST"
	p.detailed_position = "DC"
	p.overall = 80
	p.potential = 85
	p.national_team_status = "regular"
	SaveManager.save_world_seed(world_seed)
	SaveManager.save_player(p)

	WorldTickEngine._tick_national_trophies()
	var after1 := SaveManager.load_player()
	var titles1: int = after1.career_titles.size()
	var trophies1: int = after1.trophies_won
	var balance1: int = after1.balance

	WorldTickEngine._tick_national_trophies()  # segunda vez: no debe duplicar
	var after2 := SaveManager.load_player()

	var honor_ok: bool = titles1 == 1 and trophies1 == 1 and String(after1.career_titles[0].get("id", "")) == "world_cup"
	var dedupe_ok: bool = after2.career_titles.size() == titles1 and after2.trophies_won == trophies1
	var art_key: String = HonorsEngine.trophy_key_for(after1.career_titles[0]) if titles1 > 0 else ""
	var art_ok: bool = art_key == "mundial_seleccion"

	print("titles=%d trophies=%d balance=%d art=%s" % [titles1, trophies1, balance1, art_key])
	var ok: bool = honor_ok and dedupe_ok and art_ok

	# --- Guard: si NO está convocado (""/"left_out"), aunque su país gane
	# no se acredita nada — evita premiar a alguien que ni jugó el ciclo. ---
	var p2 := PlayerData.new()
	p2.player_name = "Probe Afuera"
	p2.country = champion
	p2.national_team_status = "left_out"
	SaveManager.save_player(p2)
	WorldTickEngine._tick_national_trophies()
	var after_guard := SaveManager.load_player()
	var guard_ok: bool = after_guard.career_titles.is_empty()
	print("guard (left_out, no debe acreditar): titles=%d" % after_guard.career_titles.size())
	ok = ok and guard_ok

	# --- Copa continental de selecciones: mismo circuito, año/confederación
	# distintos (nunca coincide con el Mundial, ver NationalCupEngine.BASE_YEAR). ---
	var conf_test: String = "CONMEBOL"
	var ncup_year: int = int(NationalCupEngine.BASE_YEAR[conf_test])
	var ncup_final_day: int = season_start + NationalCupEngine.KNOCKOUT_OFFSET + NationalCupEngine.SPAN_TO_FINAL
	WorldTickEngine.season = {"start_year": ncup_year, "season_start_epoch_day": season_start, "current_epoch_day": ncup_final_day}
	WorldTickEngine.current_epoch_day = ncup_final_day
	var ncup: Dictionary = WorldTickEngine.national_cup_for(conf_test)
	var ncup_champion: String = String(ncup.get("champion_country", ""))
	print("Campeón REAL de la copa continental %s %d: %s" % [conf_test, ncup_year, ncup_champion])
	if ncup_champion != "":
		var p3 := PlayerData.new()
		p3.player_name = "Probe Copa"
		p3.country = ncup_champion
		p3.national_team_status = "captain"
		SaveManager.save_player(p3)
		WorldTickEngine._tick_national_trophies()
		var after3 := SaveManager.load_player()
		# trophy_key_for() ya NO colapsa natcup_* a un genérico (arte real
		# por confederación, Parte 92) — devuelve el id específico tal
		# cual. Esta prueba quedó desactualizada de esa migración; se
		# actualiza el valor esperado para reflejar el comportamiento
		# actual y correcto en vez de uno viejo.
		var ncup_ok: bool = after3.career_titles.size() == 1 \
			and String(after3.career_titles[0].get("id", "")) == "natcup_%s" % conf_test \
			and HonorsEngine.trophy_key_for(after3.career_titles[0]) == "natcup_%s" % conf_test
		print("natcup titles=%d id=%s art=%s" % [after3.career_titles.size(), after3.career_titles[0].get("id","") if not after3.career_titles.is_empty() else "?", HonorsEngine.trophy_key_for(after3.career_titles[0]) if not after3.career_titles.is_empty() else "?"])
		ok = ok and ncup_ok
	else:
		print("(sin campeón de copa continental decidido en este seed/día — se omite ese sub-check)")

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
