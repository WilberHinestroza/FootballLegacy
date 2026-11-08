extends Node
## Partido 3D INTEGRADO — carrera real en slot_3: arma el partido con
## MatchLauncher.prepare() (plantel, rival, fixture de verdad), monta la
## pantalla Match3D, juega 2 jugadas sin tocar nada y valida que el resultado
## tenga el formato que consume MatchSummary; luego abre MatchSummary con él.
## Solo toca slot_3.
##   godot --headless --path . res://tools/M3DGameProbe.tscn
const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")

var fails := 0
var _res: Dictionary = {}

func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FALLA: ", msg)

func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	pl.avatar = Avatar.random_config(1234)   # cara de "tu editor"
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	fx["competition"] = "cup"
	fx["round_name"] = "Octavos de final"
	fx["is_knockout"] = true
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	var from_bench: bool = OS.get_cmdline_user_args().has("bench")
	var shots_rpg: bool = OS.get_cmdline_user_args().has("rpg")   # capturas: cansancio + falta con amarilla
	var test_tie: bool = OS.get_cmdline_user_args().has("tie")
	if shots_rpg:
		MatchState.user_player.fatigue_physical = 72.0
	# Si el DT te dejó fuera, la sonda te pone de titular en tu línea
	# (o, con "-- bench", en el banco).
	var mine: MatchTeam = MatchState.home_team if String(fx.get("home_club_id", "")) == pl.club_id else MatchState.away_team
	var u: PlayerData = MatchState.user_player
	if from_bench and mine.starting_xi.has(u):
		var repl: PlayerData = null
		for x in mine.bench:
			if (x as PlayerData).position == u.position:
				repl = x
		if repl == null:
			repl = mine.bench[0]
		mine.bench.erase(repl)
		mine.starting_xi[mine.starting_xi.find(u)] = repl
		mine.bench.append(u)
	if not from_bench and not mine.starting_xi.has(u):
		mine.bench.erase(u)
		for i in mine.starting_xi.size():
			if (mine.starting_xi[i] as PlayerData).position == u.position:
				mine.starting_xi[i] = u
				break
	print("soportado 3D: ", Match3DBridge.supported(), " · titular: ", MatchState.home_team.starting_xi.has(MatchState.user_player) or MatchState.away_team.starting_xi.has(MatchState.user_player))
	if not Match3DBridge.supported():
		print("PROBE FAIL (no soportado)")
		get_tree().quit(1)
		return
	var base_scale: Vector2i = get_tree().root.content_scale_size
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	var m: SoccerMatch = scr._match
	var cfg: Dictionary = scr._cfg
	print("%s vs %s · camisetas %s / %s (diseño %d/%d) · ritmo goles %.4f/%.4f" % [cfg.home_name, cfg.away_name,
		cfg.profile.shirt.to_html(false), cfg.away_shirt, cfg.home_pattern, cfg.away_pattern, cfg.goal_rate_home, cfg.goal_rate_away])
	print("tu jugador: %s #%d puesto %d pelo %s (%s) barba '%s' piel %s" % [cfg.profile.player_name, cfg.profile.number,
		cfg.profile.position, cfg.profile.hair_style, cfg.profile.hair.to_html(false), cfg.profile.face, cfg.profile.skin.to_html(false)])
	print("nombres local: ", m._names[0])
	print("nombres rival: ", m._names[1])
	_check(m._names[0].count("") == 0 and m._names[1].count("") == 0, "jugadores 3D sin nombre real")
	if from_bench:
		cfg["bench_until"] = 40.0   # la sonda fuerza la entrada en el 40'
		m._bench_until = 40.0
		m.entered = false
		m._plan_moments()
		print("banco: en tu hueco juega ", m._name_of(m.star), " · jugadas planeadas ", m._moments.size())
		var intro: Dictionary = m._walkout_intro_data()
		var bench_rows: Array = intro.lineups[0]
		_check(not bench_rows.any(func(row): return bool(row.get("you", false))), "la gráfica inicial te marca como titular estando en el banco")
		var player_words: PackedStringArray = MatchState.user_player.player_name.split(" ", false)
		var player_last: String = player_words[-1] if not player_words.is_empty() else MatchState.user_player.player_name
		_check(not bench_rows.any(func(row): return String(row.get("name", "")) == player_last), "tu apellido aparece en los titulares desde el banco")
	else:
		var intro: Dictionary = m._walkout_intro_data()
		var starter_rows: Array = intro.lineups[0]
		_check(starter_rows.any(func(row): return bool(row.get("you", false))), "la gráfica inicial no marca al usuario titular")
	_check(m.star.role == m.PROFILE_ROLE[cfg.profile.position], "tu jugador no está en su línea")
	# Prueba el camerino incluso si el usuario no está en cancha: ese estado no
	# debe saltarse el descanso del equipo.
	SoccerMatch.config["on_finish"] = _on_finish
	if DisplayServer.get_name() != "headless" and from_bench:
		# Con ventana desde el banco: salida completa, plano del banquillo y el cambio
		var wk := 0
		while m.state == m.State.WALKOUT:
			await get_tree().create_timer(0.5).timeout
			wk += 1
			if wk % 4 == 0 and wk <= 16:
				get_viewport().get_texture().get_image().save_png("res://build/m3d_review_walk_%d.png" % (wk / 4))
		await get_tree().create_timer(1.5).timeout
		get_viewport().get_texture().get_image().save_png("res://build/m3d_review_bench.png")
		m.minute = 39.0
		while m.state != m.State.CUTSCENE:
			await get_tree().process_frame
		for k in 4:
			await get_tree().create_timer(2.5).timeout
			get_viewport().get_texture().get_image().save_png("res://build/m3d_review_sub_%d.png" % k)
	if DisplayServer.get_name() == "headless":
		_check(bool(cfg.get("walkout_skip", false)), "la salida promete toque para avanzar pero tiene el salto desactivado")
		m._on_tapped(Vector2.ZERO)
		_check(m.state != m.State.WALKOUT, "tocar la salida no avanzó el partido")
	else:
		m._end_walkout()
	if from_bench:
		# La primera toma es el suplente en el banquillo; luego forzamos su
		# entrada real en el 40' y dejamos correr su cutscene antes del descanso.
		if m.state == m.State.CUTSCENE:
			m._end_cutscene()
		m.minute = 39.0
		m._simulate_minute(40)
		_check(m.entered and m._entry_minute == 40, "no se activó la entrada desde el banco en el 40'")
		if m.state == m.State.CUTSCENE:
			m._end_cutscene()
	var was_entered: bool = m.entered
	var test_player: PlayerData = MatchState.user_player
	test_player.consumables["energy_drink"] = 1
	m._moments.clear()
	m.minute = 45.0
	m.entered = false
	m._halftime_pending = true
	m._sim_step(0.0)
	# Descuento (StoppageTime): al 45' el cuarto árbitro levanta el cartel y el reloj
	# sigue en 45+X; al agotarse, descanso.
	_check(m._added_phase == 1 and m._added_total >= 1 and m.added_clock() == "45+1'",
		"no arrancó el descuento del primer tiempo (%d, %d, %s)" % [m._added_phase, m._added_total, m.added_clock()])
	m._added_elapsed = float(m._added_total)
	m._sim_step(0.0)
	_check(m._added_phase == 0, "el descuento del primer tiempo no terminó")
	# Rasgos equipados (TraitEffects): tu tiro supera más al portero; sin rasgos, igual.
	var saved_ids: Array = m._trait_ids
	var saved_mods: Dictionary = m._trait_mods
	m._trait_ids = ["killer_instinct", "engine"]
	m._trait_mods = m.TraitEffects.mods(m._trait_ids)
	var saved_touch = m.ball.last_touch
	var saved_kind: String = m.ball.last_kick_kind
	m.ball.last_touch = m.star
	m.ball.last_kick_kind = "shot"
	var adj: Array = m._trait_shot_adjust(m.teams[1][0], 0.3)
	_check(float(adj[0]) > 0.3 and float(adj[1]) == 0.3 and String(adj[2]) == "finish",
		"el rasgo de definición no ayudó a superar al portero (%s)" % str(adj))
	_check(m.TraitEffects.fatigue_factor(m._trait_mods) < 1.0, "Motor incansable no reduce el cansancio en 3D")
	_check(m.TraitEffects.top_trait(m._trait_ids, "finish") == "killer_instinct", "icono del rasgo equivocado")
	m._trait_ids = []
	m._trait_mods = m.TraitEffects.mods([])
	_check(float(m._trait_shot_adjust(m.teams[1][0], 0.3)[0]) == 0.3, "sin rasgos cambió el tiro")
	# Orden del descanso (HalftimeOrders): se mide solo la segunda parte.
	var HO = m.HalftimeOrders
	var ord: Dictionary = HO.pick("ST", -1, 0.0)
	_check(String(ord.get("id", "")) == "shoot", "orden de delantero perdiendo inesperada: %s" % str(ord))
	var base := {"shots": 3, "goals": 0}
	_check(not HO.met_early(ord, base, {"shots": 4}), "orden cumplida con un solo remate en la 2ª parte")
	_check(HO.met_early(ord, base, {"shots": 5}), "dos remates en la 2ª parte no cumplieron la orden")
	_check(not HO.met_final(ord, base, {"shots": 5}, true), "expulsado y cumplió la orden")
	var wall: Dictionary = HO.pick("GK", 1, 0.0)
	_check(String(wall.get("id", "")) == "wall" and HO.met_final(wall, {"conceded": 1}, {"conceded": 1}, false)
		and not HO.met_final(wall, {"conceded": 1}, {"conceded": 2}, false), "portería a cero mal juzgada")
	var focus: Dictionary = {}
	for o in HO.POOL:
		if o.id == "focus": focus = o
	_check(not HO.met_final(focus, {}, {"moments_ok": 0, "moments_fail": 0}, false), "sin jugar cumplió 'sin errores'")
	m._ht_order = HO.pick("MF", 0, 0.0)
	m._ht_base = (m.match_stats.me as Dictionary).duplicate()
	_check(m._halftime_speech().contains(String(m._ht_order.text)), "el míster no dijo la orden en el vestuario")
	_check(m.result().get("halftime_order", {}).has("met"), "la orden no viaja en el resultado")
	m._ht_order = {}
	m._trait_ids = saved_ids
	m._trait_mods = saved_mods
	m.ball.last_touch = saved_touch
	m.ball.last_kick_kind = saved_kind
	# Antes del vestuario, los equipos caminan al túnel; tocar la salta.
	_check(m.state == m.State.OUTRO and m._halftime_walk, "el descanso no arrancó con la caminata al túnel")
	m._on_tapped(Vector2.ZERO)
	_check(m.state == m.State.LOCKER and m._locker != null, "descanso no abrió el camerino con el usuario fuera de cancha")
	await get_tree().create_timer(2.6).timeout
	_check(m._hud.choices_visible(), "el míster no mostró opciones en el vestuario")
	if m._hud.choices_visible():
		m._hud.hide_choices()
		m._on_choice(3) # bebida energizante; vuelve a mostrar las tácticas
	_check(int(test_player.consumables.get("energy_drink", 0)) == 0, "no se consumió la bebida del descanso")
	_check(m.star.energy >= 0.99, "la bebida no recuperó energía 3D")
	m._hud.hide_choices()
	m._on_choice(0)
	for tick in 20:
		if m.state != m.State.LOCKER:
			break
		await get_tree().create_timer(0.25).timeout
	_check(m.state == m.State.SIMULATING and m.minute >= 45.0 and m.minute < 46.0,
		"el partido no volvió desde el vestuario en el 45' (%.1f')" % m.minute)
	m.entered = was_entered or from_bench
	# Gol de la simulación de fondo: debe verse el remate y sólo entonces subir
	# el marcador y el relato (antes el RNG anotaba un gol invisible).
	var score_before: int = m.score[0]
	m._start_ambient_goal(0, int(m.minute), "")
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("res://build/m3d_review_goal.png")
	for tick in 64: # remate + carrera al banderín + celebración
		if m.state == m.State.SIMULATING and m.score[0] > score_before:
			break
		await get_tree().create_timer(0.25).timeout
	_check(m.state == m.State.SIMULATING and m.score[0] == score_before + 1,
		"la jugada de gol ambient no se representó ni sincronizó con el marcador")
	# En el titular, usa dos ocasiones cortas; el resultado incluye ceremonia MVP.
	if test_tie:
		cfg["knockout"] = true
		cfg["has_tie_carry"] = true
		cfg["two_leg_first_leg"] = false
		cfg["carry_us"] = 1
		cfg["carry_them"] = 0
		cfg["ambient_ai"] = false
		cfg["goal_rate_home"] = 0.0
		cfg["goal_rate_away"] = 0.0
		m._hud.set_aggregate(1, 0)
		m._moments.clear()
		m.score = [0, 1] # con el 1-0 de la ida, el global termina empatado
		m.minute = 89.5
		m._halftime_pending = false
		m._hud.update_score(m.score, m.minute)
		_check(m._hud._aggregate_label != null and m._hud._aggregate_label.text == "GLOBAL · 1 - 1",
			"el HUD 3D no mostró el global en empate")
		m.match_stats.me.goals = 5
	elif from_bench:
		m._moments = [{"minute": 50.0, "kind": m.Moment.ATTACK}, {"minute": 65.0, "kind": m.Moment.DEFENSE}]
	else:
		m._moments = [{"minute": 46.0, "kind": m.Moment.ATTACK}, {"minute": 60.0, "kind": m.Moment.DEFENSE}]
		m.match_stats.me.goals = 5
	if DisplayServer.get_name() != "headless" and shots_rpg:
		await get_tree().create_timer(2.5).timeout
		get_viewport().get_texture().get_image().save_png("res://build/m3d_tired.png")
		await m.moment_started
		while m.state != m.State.MOMENT:
			await get_tree().process_frame
		await get_tree().create_timer(0.6).timeout
		var victim: SoccerPlayer = m.teams[1][5]
		m.star.lunge()
		m._call_foul(m.star, victim, true)
		for k in 3:
			await get_tree().create_timer(0.8).timeout
			get_viewport().get_texture().get_image().save_png("res://build/m3d_foul_%d.png" % k)
	elif DisplayServer.get_name() != "headless":   # con ventana: capturas de la jugada
		await m.moment_started
		for k in 3:
			await get_tree().create_timer(1.4).timeout
			get_viewport().get_texture().get_image().save_png("res://build/m3d_moment_%d.png" % k)
	for tick in 400:
		if m.state == m.State.OUTRO:
			if DisplayServer.get_name() != "headless":
				await get_tree().create_timer(1.5).timeout
				get_viewport().get_texture().get_image().save_png("res://build/m3d_review_outro.png")
			break
		if m.state == m.State.LOCKER and m._hud.choices_visible():
			m._hud.hide_choices()
			m._on_choice(1)
		await get_tree().create_timer(0.5).timeout
	_check(m.state == m.State.OUTRO, "el partido no alcanzó el outro (estado %s, minuto %.1f)" % [m.State.keys()[m.state], m.minute])
	if m.state != m.State.OUTRO:
		get_tree().quit(1)
		return
	print("final 3D %d–%d · jugadas %d · log %s" % [m.score[0], m.score[1], m.match_stats.moments, m.match_stats.moment_log.map(func(x): return "%s:%s" % [x.kind, x.ok])])
	var live: float = m.live_rating()
	for tick in 100:
		if m._outro_sent:
			break
		await get_tree().create_timer(0.25).timeout
	_check(m._outro_sent, "la salida de los jugadores al túnel no terminó")
	if not m._outro_sent:
		get_tree().quit(1)
		return
	await get_tree().process_frame
	_check(scr._mvp_ceremony != null and not scr._final_result.is_empty(), "no se inició la animación 3D del MVP")
	if scr._mvp_ceremony != null:
		_check(scr._mvp_ceremony._winner.visible, "el MVP no aparece en el césped")
		_check(scr._mvp_ceremony._award != null, "el MVP no carga el trofeo")
	if not from_bench and not scr._final_result.is_empty():
		var final_rows: Array = scr._final_result.get("player_ratings", [])
		_check(not final_rows.is_empty() and bool(final_rows[0].get("is_user", false)), "el MVP de prueba no es el usuario")
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(2.0).timeout
		get_viewport().get_texture().get_image().save_png("res://build/m3d_review_mvp.png")
		await get_tree().create_timer(4.0).timeout
	# La entrega del MVP dura ~9 s (camina, recibe, enseña y levanta): esperar a que acabe
	for tick in 60:
		if not _res.is_empty():
			break
		await get_tree().create_timer(0.25).timeout
	_check(not _res.is_empty(), "on_finish no se llamó")
	var res: Dictionary = scr._final_result if not scr._final_result.is_empty() else Match3DBridge.to_match_result(_res, cfg)
	for k in ["score", "user_rating", "rating_events", "user_injured", "user_red_carded", "user_double_yellow", "shootout_winner",
			"player_ratings", "match_stats", "user_goals", "user_assists", "user_started", "user_played", "user_yellows"]:
		_check(res.has(k), "falta la clave %s" % k)
	if from_bench:
		_check(bool(_res.entered) and int(_res.entry_minute) == 40, "no entraste desde el banco en el 40'")
		_check(not bool(res.user_started) and bool(res.user_played), "user_started/user_played desde el banco")
		_check(m._name_of(m.star) == MatchState.user_player.player_name, "tu nombre no está en tu hueco tras entrar")
	if test_tie:
		_check(bool(res.get("extra_time_played", false)), "el global empatado no jugó 30 minutos de prórroga")
		_check(String(res.get("shootout_winner", "")) != "", "el empate global no terminó en tanda")
		var aggregate: Dictionary = res.get("aggregate_score", {})
		_check(int(aggregate.get("home", -1)) == int(aggregate.get("away", -2)), "el global de prueba no era empate")
		var kicks: Array = res.get("shootout_score", [])
		_check(kicks.size() == 2 and int(kicks[0]) != int(kicks[1]), "la tanda no produjo un ganador")
	_check(absf(live - float(res.user_rating)) < 0.051, "nota en vivo %.2f ≠ nota final %.2f" % [live, res.user_rating])
	_check((res.player_ratings as Array).size() == (23 if from_bench else 22), "player_ratings: filas %d" % (res.player_ratings as Array).size())
	var us_goals: int = int(res.score.home if cfg.user_home else res.score.away)
	_check(us_goals == int(_res.score[0]), "orientación del marcador")
	if res.score.home == res.score.away:
		_check(res.shootout_winner != "", "cruce igualado sin tanda")
	print("resultado %d–%d (home–away, %s) · nota %.1f · tanda '%s' · stats %s" % [res.score.home, res.score.away,
		"local" if cfg.user_home else "visitante", res.user_rating, res.shootout_winner, res.match_stats])
	scr.queue_free()
	await get_tree().process_frame
	_check(get_tree().root.content_scale_size == base_scale, "no volvió a la pantalla del juego: %s" % get_tree().root.content_scale_size)
	MatchState.match_result = res
	var ms: Node = load("res://scenes/MatchSummary/MatchSummary.tscn").instantiate()
	add_child(ms)
	for i in 10:
		await get_tree().process_frame
	print("MatchSummary abrió con el resultado 3D (hijos: %d)" % ms.get_child_count())
	ms.queue_free()
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0)

func _on_finish(res: Dictionary) -> void:
	_res = res
