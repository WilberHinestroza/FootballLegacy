extends Node
## Jugadas en vivo del LiveBridge con y sin la cancha incrustada.
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	var pl: PlayerData = SaveManager.load_player()
	MatchLauncher.prepare(WorldTickEngine.world, pl, WorldTickEngine.next_user_fixture(pl.club_id), "res://scenes/Hub/Hub.tscn", false)
	LiveBridge.test_auto = true
	# Tu jugador titular (solo en memoria) en lugar del 10.
	for t in [MatchState.home_team, MatchState.away_team]:
		if t.bench.has(pl) and not t.starting_xi.has(pl):
			var out: PlayerData = t.starting_xi[9]
			t.starting_xi[9] = pl
			t.bench.erase(pl)
			t.bench.append(out)
	var b := LiveBridge.new()
	add_child(b)
	b.build(Color.RED, Color.BLUE)
	print("PUENTE controlás a: ", b.m.user.pname, " (", b.m.user.code, ")")
	var kinds := ["shot_on_goal", "long_shot", "one_on_one", "chip_shot", "dribble", "key_pass",
		"through_ball", "cross", "cutback", "counter_run", "one_two", "switch_play", "free_kick",
		"penalty", "volley", "aerial_duel", "tackle", "pressing", "recovery_tackle",
		"last_ditch_tackle", "interception", "block_shot", "clearance", "one_on_one_save",
		"sweep_keeper", "distribution", "penalty_save"]
	for k in kinds:
		var t0: int = Time.get_ticks_msec()
		var outs: Array = []
		var secs: Array = []
		for i in 3:
			var r: Dictionary = await b.play({"minute": 30, "kind": k, "options": [{"kind": k}], "narration": ""})
			outs.append(r["outcome"])
			secs.append(snappedf(b.m.m_t, 0.1))
		print("JUGADA %-18s %s  dur=%s  real=%.1fs" % [k, outs, secs, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit()
