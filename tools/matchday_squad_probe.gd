extends Node
## Convocatoria de partido: 11 titulares + 9 suplentes (1 arquero), el
## usuario siempre adentro (titular o suplente).
##   godot --headless --path . res://tools/MatchdaySquadProbe.tscn
func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	var fails := 0
	for i in range(6):
		MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
		for t in [MatchState.home_team, MatchState.away_team]:
			var gks: int = t.bench.filter(func(p): return p.position == "GK").size()
			var ok: bool = t.starting_xi.size() == 11 and t.bench.size() <= MatchTeam.MATCHDAY_BENCH + (1 if t.user_not_called else 0) and gks <= 1
			if not ok:
				fails += 1
			print("XI %d · banco %d (arqueros %d)" % [t.starting_xi.size(), t.bench.size(), gks])
		var me := MatchState.home_team if (MatchState.home_team.starting_xi.has(pl) or MatchState.home_team.bench.has(pl)) else MatchState.away_team
		if not (me.starting_xi.has(pl) or me.bench.has(pl)):
			fails += 1
			print("FALLA: el usuario no está convocado")
	# NO CONVOCADO: confianza 0 + media baja → afuera de la lista (nunca en amistoso).
	pl.coach_trust = 0
	var keep_ovr: int = pl.overall
	pl.overall = 35
	pl.potential = maxi(pl.potential, 35)
	var nc := 0
	pl.active_effects.erase("role_titular_matches")
	pl.active_effects.erase("agent_lobby_matches")
	var fx_league: Dictionary = fx.duplicate()
	fx_league["competition"] = "league"
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	if MatchState.home_team.user_not_called or MatchState.away_team.user_not_called:
		fails += 1
		print("FALLA: no convocado en un amistoso")
	for i in range(4):
		MatchLauncher.prepare(WorldTickEngine.world, pl, fx_league, "res://scenes/Hub/Hub.tscn", false)
		var me2: MatchTeam = MatchState.home_team if MatchState.home_team.bench.has(pl) or MatchState.home_team.starting_xi.has(pl) else MatchState.away_team
		if me2.user_not_called:
			nc += 1
			if me2.starting_xi.has(pl):
				fails += 1
				print("FALLA: no convocado pero titular")
	print("no convocado %d/4 (esperado 4 con confianza 0 y media 35)" % nc)
	if nc != 4:
		fails += 1
	var t2 := CoachRelations.can_be_left_out(CoachRelations.start_chance(60))
	print("confianza 60 → puede quedar afuera: %s (esperado false)" % t2)
	if t2:
		fails += 1
	pl.overall = keep_ovr
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0)
