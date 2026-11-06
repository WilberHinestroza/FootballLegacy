extends SceneTree
func _init():
	var w1 := WorldFactory.build(20260904)
	var w2 := WorldFactory.build(20260904)
	var w3 := WorldFactory.build(999)

	var leagues: Array = w1["leagues"]
	assert(leagues.size() == WorldFactory.LEAGUE_BLUEPRINTS.size(), "n ligas")
	print("Ligas: ", leagues.size())
	for lg in leagues:
		var clubs: Array = w1["clubs_by_league"][lg.league_id]
		assert(clubs.size() == lg.team_count, "team_count %s" % lg.country)
		assert(lg.league_id >= 1, "league_id sentinel")
		var clubs2: Array = w2["clubs_by_league"][lg.league_id]
		for i in range(clubs.size()):
			assert(clubs[i].club_name == clubs2[i].club_name, "determinismo club")
			assert(clubs[i].league_id == lg.league_id, "club.league_id")
		print("  %-16s tc=%2d %-20s jorn=%d p/eq=%d rep=%d" % [lg.country, lg.team_count, lg.format, lg.matchdays(), lg.matches_per_team(), lg.reputation])

	var arg: LeagueData = WorldFactory.find_league_for_country(w1, "Argentina")
	assert(arg != null and arg.matches_per_team() == 27 and arg.matchdays() == 28, "arg format")
	assert(WorldFactory.find_league_for_country(w1, "Narnia") == null, "narnia sin liga")

	var col: LeagueData = WorldFactory.find_league_for_country(w1, "Colombia")
	var col_club_id: String = w1["clubs_by_league"][col.league_id][0].club_id
	var meta: Dictionary = w1["club_meta_by_id"][col_club_id]
	var squad_a := WorldFactory.make_squad(meta)
	var squad_b := WorldFactory.make_squad(w2["club_meta_by_id"][col_club_id])
	assert(squad_a.size() == 22 and squad_a[0].position == "GK", "squad shape")
	for i in range(squad_a.size()):
		assert(squad_a[i].potential >= squad_a[i].overall, "invariante pot>=ov")
		assert(squad_a[i].player_name == squad_b[i].player_name, "determinismo plantilla")
	print("Colombia club[0]=%s  fuerzaXI=%d  ej: %s (%s ov %d)" % [meta["name"], WorldFactory.squad_strength(squad_a), squad_a[0].player_name, squad_a[0].position, squad_a[0].overall])
	assert(w1["club_meta_by_id"]["c_1_0"]["base_overall"] != w3["club_meta_by_id"]["c_1_0"]["base_overall"] or w1["clubs_by_league"][1][0].club_name != w3["clubs_by_league"][1][0].club_name, "otra semilla otro mundo")
	print("OK")
	quit()
