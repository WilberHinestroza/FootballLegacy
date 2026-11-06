extends Control

## Captura REAL de la ceremonia de despedida (LegacyEngine + FarewellCeremony)
## con un jugador "leyenda" armado en memoria (no toca ningún slot).
##   godot --path . res://tools/FarewellProbe.tscn

func _ready() -> void:
	if WorldTickEngine.world.is_empty():
		WorldTickEngine.world = WorldFactory.build(4242)
	var club: ClubData = WorldTickEngine.world["clubs_by_league"][11][0]
	var p := PlayerData.new()
	p.player_name = "Tomás Herrera"
	p.position = "ST"
	p.detailed_position = "DC"
	p.country = "Colombia"
	p.club_id = club.club_id
	p.club_seniority = 9
	p.career_matches = 512
	p.career_goals = 241
	p.career_assists = 88
	p.trophies_won = 6
	p.career_titles = [{"id": "ballon_dor", "season": 2031}, {"id": "league_11", "season": 2030}]
	p.age = 36
	var ok := LegacyEngine.tier(p) == 3 and LegacyEngine.jersey_retired(p)
	var q := PlayerData.new()
	q.club_id = club.club_id
	q.club_seniority = 2
	q.career_matches = 120
	ok = ok and not LegacyEngine.jersey_retired(q) and LegacyEngine.tier(q) <= 1
	var f := FarewellCeremony.open(self, p, club)
	for i in range(4):
		f._show(i)
		for k in range(40):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Farewell_%d.png" % i))
	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
