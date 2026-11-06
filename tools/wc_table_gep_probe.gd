extends Node

## Prueba dirigida: "en la tabla del mundial no se muestra partidos
## ganados, empatados y perdidos, todo está en 0 aunque se hayan jugado
## los partidos" — WorldCupEngine._standings() armaba las filas con las
## claves "pg"/"pe"/"pp", pero Selections.gd._table_row() (la UI) lee
## "g"/"e"/"p" — desajuste de nombres, siempre 0 aunque hubiera partidos
## jugados. Corre el Mundial de una semilla bien entrada en la fase de
## grupos y confirma que al menos una fila tiene g+e+p == pj (todo
## partido jugado cuenta para alguna de las 3 columnas).
##   godot --headless res://tools/WcTableGepProbe.tscn

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
	# Bien entrada la fase de grupos (arranca en GROUP_START_OFFSET, ver
	# WorldCupEngine.gd) para que haya partidos ya jugados de verdad.
	WorldTickEngine.current_epoch_day = WorldCupEngine.GROUP_START_OFFSET + 40

	var tournament: Dictionary = WorldTickEngine.world_cup_this_cycle()
	var ok: bool = true
	if tournament.is_empty():
		print("PROBE FAIL (no se armó el torneo — ¿no es año de Mundial en esta config?)")
		get_tree().quit(1)
		return

	var any_played: bool = false
	for g in tournament.get("groups", []) as Array:
		for row in g.get("standings", []) as Array:
			var pj: int = int(row.get("pj", 0))
			if pj <= 0:
				continue
			any_played = true
			var g_: int = int(row.get("g", -1))
			var e_: int = int(row.get("e", -1))
			var p_: int = int(row.get("p", -1))
			print("%s: pj=%d g=%d e=%d p=%d" % [row.get("club_id", "?"), pj, g_, e_, p_])
			if g_ < 0 or e_ < 0 or p_ < 0:
				print("FALLA: faltan las claves g/e/p en la fila")
				ok = false
			elif g_ + e_ + p_ != pj:
				print("FALLA: g+e+p (%d) != pj (%d)" % [g_ + e_ + p_, pj])
				ok = false
	if not any_played:
		print("PROBE FAIL (ningún partido jugado todavía — subir current_epoch_day)")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
