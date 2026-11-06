extends Node

## Mide "la pantalla de vitrina se demora mucho en cargar" / "carga muy
## lento la pantalla de final de temporada" (reporte de Wilber, ambas
## terminan llamando a WorldTickEngine.ballon_dor_ranking() —
## PlayerProfile._fill_ballon_dor y WorldTickEngine._finish_season_
## rollover). Antes: 48 ligas tier 1 completas, 8846ms en frío (medido
## con la versión anterior de este mismo probe). Ahora: solo ligas con
## reputación >= BALLON_DOR_MIN_LEAGUE_REPUTATION (70) — más realista
## (el Balón de Oro real no lo disputan las 48 ligas del mundo) y mucho
## más rápido. SOLO LECTURA, no cambia nada.
##   godot --headless res://tools/BallonDorTimingProbe.tscn

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
	WorldTickEngine.season = {"start_year": 2026, "season_start_epoch_day": 0, "league_id": 2}
	WorldTickEngine.current_epoch_day = 300

	var eligible: int = 0
	var total_tier1: int = 0
	for lg in world.get("leagues", []) as Array:
		if lg.tier != 1:
			continue
		total_tier1 += 1
		if lg.reputation >= WorldTickEngine.BALLON_DOR_MIN_LEAGUE_REPUTATION:
			eligible += 1
	print("ligas elegibles para el Balón de Oro: %d de %d de tier 1 (%d totales)" % [eligible, total_tier1, world.get("leagues", []).size()])

	var t0: int = Time.get_ticks_msec()
	var ranking: Array = WorldTickEngine.ballon_dor_ranking()
	var t1: int = Time.get_ticks_msec()
	print("ballon_dor_ranking() EN FRÍO: %d ms (%d candidatos) — antes: 8846 ms" % [t1 - t0, ranking.size()])

	if not ranking.is_empty():
		print("1º del ranking: %s (%s) — %d goles, %d asistencias" % [
			ranking[0].get("name", "?"), ranking[0].get("club_name", "?"),
			int(ranking[0].get("goals", 0)), int(ranking[0].get("assists", 0))])

	get_tree().quit(0)
