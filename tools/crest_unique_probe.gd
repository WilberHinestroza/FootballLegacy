extends Control

## Escudos repetidos dentro de una liga (10-oct, Wilber: "en una liga
## encontré como 7 veces el mismo escudo igualito"). Verifica en TODAS las
## ligas del mundo que ningún par (silueta, emblema) se repita, y que el
## emblema no se repita mientras la liga tenga menos clubes que emblemas.
## Además captura (render real) la tabla de escudos de la liga 11.
##   godot --path . res://tools/CrestUniqueProbe.tscn

func _ready() -> void:
	var ok := true
	if WorldTickEngine.world.is_empty():
		WorldTickEngine.world = WorldFactory.build(12345)
	var world: Dictionary = WorldTickEngine.world
	var by_league: Dictionary = world.get("clubs_by_league", {})
	var worst := 0
	for lid in by_league:
		var seen_pair := {}
		var seen_emb := {}
		var clubs: Array = by_league[lid]
		for c in clubs:
			var cf: Dictionary = Crest.config_for((c as ClubData).club_id)
			var pair := "%s|%s" % [cf["shape_name"], cf["emblem_name"]]
			if seen_pair.has(pair):
				print("FALLA: liga ", lid, " repite ", pair)
				ok = false
			seen_pair[pair] = true
			seen_emb[cf["emblem_name"]] = int(seen_emb.get(cf["emblem_name"], 0)) + 1
		if clubs.size() <= Crest.PX_EMBLEMS.size():
			for e in seen_emb:
				if int(seen_emb[e]) > 1:
					print("FALLA: liga ", lid, " repite emblema ", e)
					ok = false
		worst = maxi(worst, clubs.size())
	print("ligas: ", by_league.size(), " · liga más grande: ", worst, " · emblemas: ", Crest.PX_EMBLEMS.size())

	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.11, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(8, 8)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	var lid_show: int = 11 if by_league.has(11) else int(by_league.keys()[0])
	for c in by_league[lid_show]:
		var v := VBoxContainer.new()
		var row := HBoxContainer.new()
		row.add_child(Styles.club_crest((c as ClubData).club_id, 28))
		row.add_child(Styles.club_crest((c as ClubData).club_id, 64))
		v.add_child(row)
		var l := Label.new()
		l.text = (c as ClubData).short_name
		l.add_theme_font_size_override("font_size", 10)
		v.add_child(l)
		grid.add_child(v)
	for i in range(10):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/crest_unique.png"))
	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
