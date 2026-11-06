extends Node

## Diagnóstico dirigido al reporte de Wilber: "los dos días de partido de
## fecha FIFA no deberían ser días seguidos" + "salen con el nombre del
## mismo partido". Imprime, para una confederación de tabla (CONMEBOL) y
## una de grupos (UEFA), los días/rivales reales que asigna QualifyingEngine
## para el país del usuario — sin tocar ningún slot real.
##   godot --headless res://tools/FifaWindowSpacingProbe.tscn

func _ready() -> void:
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
	WorldTickEngine.current_epoch_day = 700

	var windows: Array = WorldTickEngine._qualifying_windows(0)
	print("cantidad de ventanas FIFA en el ciclo: %d" % windows.size())
	print("ventanas: ", windows)

	for country_conf in [["Argentina", Confederations.CONMEBOL], ["España", Confederations.UEFA]]:
		var country: String = country_conf[0]
		var conf: String = country_conf[1]
		var resolved: Dictionary = WorldTickEngine.national_qualifying_for(conf)
		print("\n--- %s (%s, formato %s) ---" % [country, conf, resolved.get("format", "?")])
		var days: Array = []
		if String(resolved.get("format", "")) == "table":
			for fx in resolved.get("fixtures", []):
				var home: String = String(fx.get("home", ""))
				var away: String = String(fx.get("away", ""))
				if home == country or away == country:
					var opp: String = away if home == country else home
					days.append([int(fx.get("epoch_day", -1)), opp, home == country])
		else:
			for g in resolved.get("groups", []):
				for fx in g.get("fixtures", []):
					var home: String = String(fx.get("home_club_id", ""))
					var away: String = String(fx.get("away_club_id", ""))
					if home == country or away == country:
						var opp: String = away if home == country else home
						days.append([int(fx.get("epoch_day", -1)), opp, home == country])
		days.sort_custom(func(a, b): return a[0] < b[0])
		for d in days:
			print("  día %d — vs %s (%s)" % [d[0], d[1], "local" if d[2] else "visitante"])

	get_tree().quit(0)
