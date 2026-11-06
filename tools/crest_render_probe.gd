extends Control
## Captura REAL (con render, no headless) de los escudos de varios clubes
## tal como los arma el juego (Styles.club_crest), a varios tamaños.
## Guarda res://_pixellab_preview/godot_crests.png.
##   godot --path . res://tools/CrestRenderProbe.tscn   (SIN --headless)
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.11, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var world: Dictionary = WorldFactory.build(20260906)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.position = Vector2(10, 10)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)
	var n: int = 0
	for l in world.get("leagues", []):
		for c in world.get("clubs_by_league", {}).get(l.league_id, []).slice(0, 2):
			if n >= 24:
				break
			grid.add_child(Styles.club_crest(c.club_id, 64))
			n += 1
	var small := GridContainer.new()
	small.columns = 8
	small.add_theme_constant_override("h_separation", 52)
	small.add_theme_constant_override("v_separation", 52)
	small.position = Vector2(31, 290)
	add_child(small)
	n = 0
	for l in world.get("leagues", []):
		for c in world.get("clubs_by_league", {}).get(l.league_id, []).slice(0, 2):
			if n < 24:
				small.add_child(Styles.club_crest(c.club_id, 22))
				n += 1
	for i in range(8):
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://_pixellab_preview/godot_crests.png"))
	print("CAPTURA OK ", img.get_size(), " clubes=", n)
	get_tree().quit(0)
