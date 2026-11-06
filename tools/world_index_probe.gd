extends Node

## Prueba dirigida a la auditoría de rendimiento general ("mejora y pule
## todos los querys del juego"): WorldFactory.find_club()/
## find_league_for_country() pasaron de escaneo lineal a índices O(1)
## (world["club_by_id"]/world["league_by_country"]) armados una sola vez
## en build(). Este probe confirma que los índices existen, que cubren
## TODOS los clubes/ligas reales, y que find_club()/find_league_for_country()
## siguen devolviendo EXACTAMENTE lo mismo que el escaneo lineal de
## siempre (comparado a mano acá, sin depender del código ya cambiado).
##   godot --headless res://tools/WorldIndexProbe.tscn

func _ready() -> void:
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var ok: bool = true

	# --- club_by_id cubre TODOS los clubes de clubs_by_league ---
	var idx: Dictionary = world.get("club_by_id", {})
	var total_clubs: int = 0
	for arr in world.get("clubs_by_league", {}).values():
		for club in arr:
			total_clubs += 1
			if not idx.has(club.club_id):
				print("FALLA: club_by_id no tiene a %s" % club.club_id)
				ok = false
			elif idx[club.club_id] != club:
				print("FALLA: club_by_id[%s] no es el MISMO objeto que en clubs_by_league" % club.club_id)
				ok = false
	print("clubes totales: %d, club_by_id.size(): %d" % [total_clubs, idx.size()])
	if idx.size() != total_clubs:
		print("FALLA: tamaños no coinciden")
		ok = false

	# --- find_club() da lo mismo que el escaneo lineal, para varios ids ---
	var sample_ids: Array = ["c_2_0", "c_3_5", "c_10_29", "c_999_0"] # el último no existe
	for cid in sample_ids:
		var via_index: ClubData = WorldFactory.find_club(world, cid)
		var via_scan: ClubData = null
		for arr in world.get("clubs_by_league", {}).values():
			for club in arr:
				if club.club_id == cid:
					via_scan = club
		if via_index != via_scan:
			print("FALLA: find_club('%s') difiere entre índice (%s) y escaneo (%s)" % [cid, via_index, via_scan])
			ok = false
		else:
			print("find_club('%s'): OK (%s)" % [cid, via_index.club_name if via_index != null else "null, como esperado"])

	# --- league_by_country: MENOR tier por país, igual que el escaneo de siempre ---
	var lidx: Dictionary = world.get("league_by_country", {})
	print("países indexados: %d, ligas totales: %d" % [lidx.size(), world.get("leagues", []).size()])
	for country in ["España", "Argentina", "Honduras", "Atlántida"]: # el último no existe
		var via_index2: LeagueData = WorldFactory.find_league_for_country(world, country)
		var best: LeagueData = null
		for league in world.get("leagues", []):
			if league.country.to_lower() == country.strip_edges().to_lower() and (best == null or league.tier < best.tier):
				best = league
		if via_index2 != best:
			print("FALLA: find_league_for_country('%s') difiere entre índice y escaneo" % country)
			ok = false
		else:
			print("find_league_for_country('%s'): OK (%s)" % [country, via_index2.league_name if via_index2 != null else "null, como esperado"])

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
