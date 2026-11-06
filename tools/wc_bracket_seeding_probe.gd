extends Node

## Prueba dirigida: "por qué si dos selecciones están en el mismo grupo y
## pasan primero y segundo, se enfrentan entre sí en dieciseisavos?" —
## WorldCupEngine.resolve() armaba `qualifiers` con el 1º y 2º de cada
## grupo SEGUIDOS, y SeasonCalendar._build_bracket_rounds() empareja de a
## 2 consecutivos sin saber nada de grupos — así el cuadro de dieciseisavos
## podía (y de hecho pasaba) enfrentar a compañeros de grupo apenas
## terminada la fase de grupos. Arreglado con
## WorldCupEngine._avoid_same_group_pairs(). Corre varias semillas, deja
## que la fase de grupos termine y el cuadro se arme, y confirma que
## NINGÚN cruce de la primera ronda del cuadro tiene a 2 países del mismo
## grupo.
##   godot --headless res://tools/WcBracketSeedingProbe.tscn

func _ready() -> void:
	var ok: bool = true
	var seeds: Array = [20260906, 777, 42, 20270101, 555111]
	for world_seed in seeds:
		var world: Dictionary = WorldFactory.build(world_seed)
		var strength_by_club: Dictionary = {}
		var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
		for club_id in meta_by_id:
			strength_by_club[club_id] = int(meta_by_id[club_id].get("base_overall", 55))

		WorldTickEngine.world = world
		WorldTickEngine.world_seed = world_seed
		WorldTickEngine._strength_by_club = strength_by_club
		WorldTickEngine.season = {"start_year": 2026, "season_start_epoch_day": 0}
		# Bien entrada la primera ronda del cuadro (después de knockout_start).
		WorldTickEngine.current_epoch_day = WorldCupEngine.GROUP_START_OFFSET + WorldCupEngine.KNOCKOUT_OFFSET + 5

		var tournament: Dictionary = WorldTickEngine.world_cup_this_cycle()
		if tournament.is_empty():
			print("semilla %d: torneo vacío (¿no cae en año de Mundial?) — se omite" % world_seed)
			continue

		# País -> índice de grupo (para chequear los cruces del cuadro).
		var group_of: Dictionary = {}
		for gi in range(tournament.get("groups", []).size()):
			for row in tournament["groups"][gi].get("standings", []) as Array:
				group_of[String(row.get("club_id", ""))] = gi

		var rounds: Array = tournament.get("rounds", [])
		if rounds.is_empty():
			print("semilla %d: el cuadro todavía no se armó (¿faltan días?) — se omite" % world_seed)
			continue
		var first_round: Dictionary = rounds[0]
		var matches: Array = first_round.get("matches", [])
		print("semilla %d: %s, %d cruces en la primera ronda" % [world_seed, String(first_round.get("round_name", "?")), matches.size()])
		for m in matches:
			var h: String = String(m.get("home_club_id", ""))
			var a: String = String(m.get("away_club_id", ""))
			if h == "" or a == "":
				continue # bye
			var gh: int = int(group_of.get(h, -1))
			var ga: int = int(group_of.get(a, -2))
			if gh == ga:
				print("FALLA: %s vs %s son del MISMO grupo (%d) y se cruzan en la primera ronda" % [h, a, gh])
				ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
