extends "res://tools/ui_gallery_probe.gd"
## POST PARTIDO en 4 pestanas (11-oct): Vestuario / Estadisticas / Otros /
## Notas. Captura REAL de las dos primeras. slot_3.
##   godot --path . --resolution 432x936 res://tools/SummaryTabsProbe.tscn
func _ready() -> void:
	_seed_career()
	await get_tree().process_frame
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	var home: bool = String(fx.get("home_club_id", "")) == pl.club_id
	MatchState.match_result = {"score": {"home": 2 if home else 1, "away": 1 if home else 2}, "user_rating": 8.1,
		"user_goals": 1, "user_assists": 1, "player_ratings": [], "events": [],
		"match_stats": {"home": {"shots": 12, "on_target": 5, "corners": 4, "fouls": 11, "possession": 54}, "away": {"shots": 9, "on_target": 3, "corners": 3, "fouls": 13, "possession": 46}}}
	MatchState.moment_map = [{"kind": "shot_on_goal", "ok": true, "goal": true, "pos": Vector2(0.5, 0.2), "to": null}]
	var ms: Node = (load("res://scenes/MatchSummary/MatchSummary.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(ms)
	for i in range(140):
		await get_tree().process_frame
	var fails: int = 0
	var labels: Array = ms.find_children("*", "Label", true, false)
	var has_locker: bool = labels.any(func(l): return String(l.text) == "EN EL VESTUARIO")
	var has_tu: bool = labels.any(func(l): return String(l.text) == "TU PARTIDO")
	if not has_locker or has_tu:
		fails += 1
		print("FAIL la primera pestana debe ser Vestuario (vestuario=%s, tu partido=%s)" % [has_locker, has_tu])
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/summary_locker.png"))
	ms.call("_on_tab", "stats")
	for i in range(30):
		await get_tree().process_frame
	labels = ms.find_children("*", "Label", true, false)
	has_locker = labels.any(func(l): return String(l.text) == "EN EL VESTUARIO" and not l.is_queued_for_deletion())
	has_tu = labels.any(func(l): return String(l.text) == "TU PARTIDO")
	if has_locker or not has_tu:
		fails += 1
		print("FAIL Estadisticas no debe traer el vestuario (vestuario=%s, tu partido=%s)" % [has_locker, has_tu])
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/summary_stats.png"))
	print("PROBE ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
