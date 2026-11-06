extends Node

## Prueba dirigida de WorldTickEngine._tick_press() (Parte 91, pedido de
## Wilber: "prensa no ligada a un partido concreto" — el hook estaba vacío,
## solo con un comentario "Pendiente"). Cubre:
##   1. _club_league_streak(): cuenta bien victorias/derrotas consecutivas
##      del CLUB en liga (no la nota del jugador), forzando resultados vía
##      season["results"] (el mismo mecanismo de override que ya usa el
##      mundo vivo para los partidos reales del usuario).
##   2. _club_press_headline(): con racha >=4 devuelve el titular correcto
##      (victorias -> POSITIVE, derrotas -> CRITICAL) y NO mira la tabla
##      (prioridad sobre la narrativa de tramo final).
##   3. Sin racha, cerca del final de temporada: si corresponde (top 3 o
##      fondo de tabla), devuelve un titular con las claves esperadas
##      (headline/body/source/sentiment) — smoke test de forma, no de
##      contenido exacto (la tabla real depende del seed).
##   4. _tick_press() end-to-end: respeta el chequeo semanal (día % 7),
##      el cooldown de 3 semanas tras publicar, y deja la entrada en
##      player.press_feed.
## No toca slot_1/slot_2 (usa slot_3, desechable).
##   godot --headless res://tools/ClubPressProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var strength_by_club: Dictionary = {}
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in meta_by_id:
		strength_by_club[club_id] = int(meta_by_id[club_id].get("base_overall", 55))

	var league: LeagueData = null
	for lg in world.get("leagues", []):
		if lg.tier == 1:
			league = lg
			break
	var clubs: Array = world.get("clubs_by_league", {}).get(league.league_id, [])
	var club_ids: Array = clubs.map(func(c): return c.club_id)
	var user_club: String = club_ids[0]
	var fixtures: Array = SeasonCalendar.build_league_fixtures(club_ids, league, 0)

	WorldTickEngine.world = world
	WorldTickEngine.world_seed = world_seed
	WorldTickEngine._strength_by_club = strength_by_club
	WorldTickEngine.user_club_id = user_club

	var ok: bool = true

	# --- 1+2: racha de VICTORIAS forzada (últimos 4 partidos del club) ---
	var own_fx: Array = fixtures.filter(func(fx): return fx["home_club_id"] == user_club or fx["away_club_id"] == user_club)
	own_fx.sort_custom(func(a, b): return int(a["epoch_day"]) < int(b["epoch_day"]))
	if own_fx.size() < 8:
		print("PROBE FAIL (liga con muy pocos partidos por club: %d)" % own_fx.size())
		get_tree().quit(1)
		return

	# Se fuerzan 5 partidos, no 4: el más viejo queda en EMPATE a propósito
	# para cortar la racha ahí y que el conteo de los últimos 4 dé
	# exactamente 4 pase lo que pase con el resultado natural (sin forzar)
	# de ese 5° partido hacia atrás.
	var win_results: Dictionary = {}
	var last5: Array = own_fx.slice(own_fx.size() - 5, own_fx.size())
	var last4: Array = last5.slice(1, 5)
	var boundary_key: String = SeasonEngine.league_result_key(int(last5[0]["matchday"]), last5[0]["home_club_id"], last5[0]["away_club_id"], int(last5[0]["epoch_day"]))
	win_results[boundary_key] = [1, 1]
	for fx in last4:
		var is_home: bool = fx["home_club_id"] == user_club
		var key: String = SeasonEngine.league_result_key(int(fx["matchday"]), fx["home_club_id"], fx["away_club_id"], int(fx["epoch_day"]))
		win_results[key] = [3, 0] if is_home else [0, 3]
	var cutoff_win: int = int(last4[3]["epoch_day"]) + 1
	WorldTickEngine.season = {"league_id": league.league_id, "season_start_epoch_day": 0, "league_fixtures": fixtures, "results": win_results}
	WorldTickEngine.current_epoch_day = cutoff_win

	var streak_win: Dictionary = WorldTickEngine._club_league_streak(league.league_id)
	print("racha forzada de victorias -> kind=%s count=%d" % [streak_win.get("kind", "?"), int(streak_win.get("count", 0))])
	if String(streak_win.get("kind", "")) != "win" or int(streak_win.get("count", 0)) != 4:
		print("FALLA 1: se esperaba kind=win count=4")
		ok = false

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 777
	var headline_win: Dictionary = WorldTickEngine._club_press_headline(rng1)
	print("titular racha victorias: %s | sentiment=%s" % [headline_win.get("headline", "?"), headline_win.get("sentiment", "?")])
	if headline_win.is_empty() or String(headline_win.get("sentiment", "")) != "POSITIVE":
		print("FALLA 2: titular de racha de victorias vacío o sentiment != POSITIVE")
		ok = false

	# --- racha de DERROTAS forzada (mismos 4 partidos, resultado opuesto) ---
	var loss_results: Dictionary = {boundary_key: [1, 1]}
	for fx in last4:
		var is_home2: bool = fx["home_club_id"] == user_club
		var key2: String = SeasonEngine.league_result_key(int(fx["matchday"]), fx["home_club_id"], fx["away_club_id"], int(fx["epoch_day"]))
		loss_results[key2] = [0, 2] if is_home2 else [2, 0]
	WorldTickEngine.season["results"] = loss_results
	var streak_loss: Dictionary = WorldTickEngine._club_league_streak(league.league_id)
	print("racha forzada de derrotas -> kind=%s count=%d" % [streak_loss.get("kind", "?"), int(streak_loss.get("count", 0))])
	if String(streak_loss.get("kind", "")) != "loss" or int(streak_loss.get("count", 0)) != 4:
		print("FALLA 3: se esperaba kind=loss count=4")
		ok = false

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 778
	var headline_loss: Dictionary = WorldTickEngine._club_press_headline(rng2)
	print("titular racha derrotas: %s | sentiment=%s" % [headline_loss.get("headline", "?"), headline_loss.get("sentiment", "?")])
	if headline_loss.is_empty() or String(headline_loss.get("sentiment", "")) != "CRITICAL":
		print("FALLA 4: titular de racha de derrotas vacío o sentiment != CRITICAL")
		ok = false

	# --- racha rota por un empate: no debe reportar racha ---
	var mixed_results: Dictionary = loss_results.duplicate()
	var last_key: String = SeasonEngine.league_result_key(int(last4[3]["matchday"]), last4[3]["home_club_id"], last4[3]["away_club_id"], int(last4[3]["epoch_day"]))
	mixed_results[last_key] = [1, 1]
	WorldTickEngine.season["results"] = mixed_results
	var streak_mixed: Dictionary = WorldTickEngine._club_league_streak(league.league_id)
	print("racha con empate al final -> kind=%s count=%d (esperado vacío)" % [streak_mixed.get("kind", "?"), int(streak_mixed.get("count", 0))])
	if String(streak_mixed.get("kind", "")) != "":
		print("FALLA 5: un empate en el último partido debería dar kind vacío, no arrastrar la racha anterior")
		ok = false

	# --- 3: smoke test de tramo final de temporada, sin overrides (tabla real) ---
	var total_md: int = maxi((clubs.size() - 1) * 2, 1)
	var target_md: int = maxi(total_md - 5, 1)
	var target_fx: Array = fixtures.filter(func(fx): return int(fx["matchday"]) == target_md and (fx["home_club_id"] == user_club or fx["away_club_id"] == user_club))
	if not target_fx.is_empty():
		WorldTickEngine.season = {"league_id": league.league_id, "season_start_epoch_day": 0, "league_fixtures": fixtures, "results": {}}
		WorldTickEngine.current_epoch_day = int(target_fx[0]["epoch_day"]) + 1
		var table: Array = WorldTickEngine.user_league_table()
		var row: Dictionary = LeagueTable.row_for(table, user_club)
		var games_left: int = total_md - int(row.get("pj", 0))
		print("tramo final smoke test: pos=%d pts=%d games_left=%d (de %d clubes)" % [int(row.get("pos", -1)), int(row.get("pts", -1)), games_left, table.size()])
		var rng3 := RandomNumberGenerator.new()
		rng3.seed = 779
		var headline3: Dictionary = WorldTickEngine._club_press_headline(rng3)
		if not headline3.is_empty():
			var shape_ok: bool = headline3.has("headline") and headline3.has("body") and headline3.has("source") and headline3.has("sentiment")
			print("titular de tramo final: %s | sentiment=%s | forma_ok=%s" % [headline3.get("headline", "?"), headline3.get("sentiment", "?"), shape_ok])
			if not shape_ok:
				print("FALLA 6: titular de tramo final con claves faltantes")
				ok = false
		else:
			print("(sin narrativa esta vez — club ni en la pelea por el título ni por descender, válido)")

	# --- 4: _tick_press() end-to-end (gate semanal + cooldown + press_feed) ---
	var p := PlayerData.new()
	p.player_name = "Probe Prensa"
	p.club_id = user_club
	p.overall = 70
	SaveManager.save_world_seed(world_seed)
	SaveManager.save_player(p)
	WorldTickEngine.season = {"league_id": league.league_id, "season_start_epoch_day": 0, "league_fixtures": fixtures, "results": win_results}

	# Día que NO es múltiplo de 7: no debe hacer nada.
	WorldTickEngine.current_epoch_day = cutoff_win if cutoff_win % 7 != 0 else cutoff_win + 1
	WorldTickEngine._tick_press()
	var after_nonweek := SaveManager.load_player()
	if not after_nonweek.press_feed.is_empty():
		print("FALLA 7: _tick_press() escribió algo en un día que no es múltiplo de 7")
		ok = false

	# Buscamos el primer día múltiplo de 7 (>= cutoff_win) donde la tirada
	# de 16% de _tick_press() efectivamente publique algo (debería tardar
	# poco: probabilidad geométrica con p=0.16).
	var fired_day: int = -1
	var d: int = cutoff_win - (cutoff_win % 7)
	if d < cutoff_win:
		d += 7
	for i in range(60):  # margen amplio, ~10x lo esperado
		WorldTickEngine.current_epoch_day = d
		WorldTickEngine._tick_press()
		var after := SaveManager.load_player()
		if not after.press_feed.is_empty():
			fired_day = d
			break
		d += 7
	if fired_day == -1:
		print("FALLA 8: _tick_press() no publicó nada en 60 semanas con racha de 4 victorias forzada (¿probabilidad rota?)")
		ok = false
	else:
		var fired_player := SaveManager.load_player()
		print("_tick_press() publicó en el día %d (semana %d): %s" % [fired_day, int(fired_day / 7.0), fired_player.press_feed[0].get("headline", "?")])
		# Cooldown: la semana siguiente (día+7) NO debería volver a publicar
		# aunque la racha siga forzada, porque club_press_cd_week quedó 3
		# semanas por delante.
		var feed_size_before: int = fired_player.press_feed.size()
		WorldTickEngine.current_epoch_day = fired_day + 7
		WorldTickEngine._tick_press()
		var after_cd := SaveManager.load_player()
		if after_cd.press_feed.size() != feed_size_before:
			print("FALLA 9: _tick_press() ignoró el cooldown de 3 semanas")
			ok = false
		else:
			print("cooldown respetado: feed sigue en %d entradas la semana siguiente" % after_cd.press_feed.size())

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
