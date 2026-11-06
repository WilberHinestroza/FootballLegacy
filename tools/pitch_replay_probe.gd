extends Node

## Prueba de la cancha 2D (Paquete 1 del ROADMAP, 9-oct):
##  1. Todos los guiones de PitchPlays (cada kind × acierto/fallo × gol)
##     arman escena + pasos sin referencias rotas, y PitchView los
##     reproduce hasta emitir `finished` (no queda un tween colgado).
##  2. Un partido REAL entero en Match.tscn (motor de verdad, no instant)
##     contestando las decisiones solo: tiene que haber repeticiones, no
##     tiene que quedar ningún evento retenido y el partido tiene que
##     terminar (si la retención de eventos trabara el motor, no termina).
##  3. El penal en 9 zonas: la fórmula nueva respeta la probabilidad de
##     siempre en promedio (no cambia el balance).
## Usa slot_3 (copia desechable). La parte visual la valida Wilber.
##   godot --headless res://tools/PitchReplayProbe.tscn

var _fails: Array = []

func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)

func _ready() -> void:
	# Esta prueba recorre el sistema ANTERIOR (menú de decisiones + elegir
	# tocando). El modo en vivo lo cubre tools/LivePlayProbe. Solo en memoria.
	Preferences.live_play = false
	await _test_scripts()
	await _test_package3_scripts()
	await _test_penalty_result_event()
	_test_pitch_shot_formula()
	await _test_pitch_minigames()
	_test_penalty_balance()
	await _test_full_match()
	print("PROBE %s (%d fallos)" % ["OK" if _fails.is_empty() else "FAIL", _fails.size()])
	get_tree().quit(0 if _fails.is_empty() else 1)

func _ctx() -> Dictionary:
	var mates: Array = []
	var rivals: Array = []
	for i in range(10):
		mates.append({"num": str(i + 2), "name": "COMPA%d" % i})
		rivals.append({"num": str(i + 2), "name": "RIVAL%d" % i})
	return {"seed": 42, "us": Color(0.2, 0.4, 0.9), "them": Color(0.85, 0.2, 0.2),
		"user": {"num": "9", "name": "PROBE"}, "mates": mates, "rivals": rivals,
		"our_gk": {"num": "1", "name": "NUESTRO"}, "their_gk": {"num": "1", "name": "ELLOS"}}

func _test_scripts() -> void:
	var view := PitchView.new()
	view.size = Vector2(540, 320)
	add_child(view)
	var ctx := _ctx()
	var kinds: Array = PitchPlays.SHOT + PitchPlays.PASS + PitchPlays.DRIBBLE + PitchPlays.DEFEND + PitchPlays.KEEPER
	var combos: int = 0
	var bad: Array = []
	for kind in kinds:
		for combo in [[true, true], [true, false], [false, false], [false, true]]:
			var scene: Dictionary = PitchPlays.scene_for(kind, ctx)
			var ids: Array = []
			for a in scene["actors"]:
				ids.append(a["id"])
			var steps: Array = PitchPlays.outcome_for(kind, combo[0], combo[1], ctx)
			for st in steps:
				for id in (st.get("moves", {}) as Dictionary):
					if not ids.has(id):
						bad.append("%s %s mueve a '%s' que no está en la escena" % [kind, combo, id])
				var b = st.get("ball", null)
				if b is String and not ids.has(b):
					bad.append("%s %s pasa la pelota a '%s' que no está" % [kind, combo, b])
				var dr: String = String(st.get("dribble", ""))
				if dr != "" and not ids.has(dr):
					bad.append("%s %s conduce '%s' que no está" % [kind, combo, dr])
			if steps.is_empty():
				bad.append("%s %s sin pasos" % [kind, combo])
			view.setup(scene)
			view.play(steps)
			var done := [false]
			view.finished.connect(func(): done[0] = true, CONNECT_ONE_SHOT)
			var t0: int = Time.get_ticks_msec()
			while not done[0] and Time.get_ticks_msec() - t0 < 8000:
				await get_tree().process_frame
			if not done[0]:
				bad.append("%s %s: la animación no terminó" % [kind, combo])
			combos += 1
	for b in bad:
		print("   ", b)
	_check(bad.is_empty(), "guiones: %d combinaciones (kind × resultado) arman y terminan" % combos)
	var rg: Dictionary = PitchPlays.rival_goal(ctx, "Juan Goleador", true, false)
	var has_scorer: bool = false
	for a in rg["scene"]["actors"]:
		if a["name"] == "GOLEADOR":
			has_scorer = true
	_check(has_scorer and (rg["steps"] as Array).size() >= 2, "gol rival: el goleador sale con su apellido")
	var tg: Dictionary = PitchPlays.team_goal(ctx, "Pedro Compañero", true, false)
	var tg_ok: bool = false
	var tg_user: bool = false
	for a in tg["scene"]["actors"]:
		if a["name"] == "COMPAÑERO" and a["color"] == ctx["us"]:
			tg_ok = true
		if a.get("user", false):
			tg_user = true
	_check(tg_ok and tg_user, "gol de compañero: goleador con nuestros colores y vos acompañando")
	# Tocar la cancha solo elige acciones que YA estaban en el menú.
	var opts := ["shot_on_goal", "key_pass", "dribble"]
	_check(PitchPlays.kind_for_tap("goal", opts) == "shot_on_goal" and PitchPlays.kind_for_tap("m1", opts) == "key_pass" and PitchPlays.kind_for_tap("d1", opts) == "dribble", "tocar arco/compañero/marcador = remate/pase/regate")
	_check(PitchPlays.kind_for_tap("goal", ["tackle", "interception"]) == "" and PitchPlays.kind_for_tap("a1", ["tackle", "interception"]) == "tackle", "tocar algo sin opción no inventa acciones")
	_check(PitchPlays.tap_targets(opts) == ["goal", "m1", "d1"], "objetivos resaltados según el menú")
	var fp: Vector2 = PitchPlays.user_full_pos("tackle", ctx)
	var ap: Vector2 = PitchPlays.user_full_pos("shot_on_goal", ctx)
	_check(fp.y > 0.5 and ap.y < 0.5, "mapa: las jugadas de ataque van arriba y las de defensa abajo")
	view.queue_free()

func _test_aim_then_bar() -> void:
	var good: float = DecisionResolver.pitch_aim_bar_precision(0.95, DecisionResolver.pitch_shot_aim_score(0.5, 0.9, false))
	var on_gk: float = DecisionResolver.pitch_aim_bar_precision(0.95, DecisionResolver.pitch_shot_aim_score(0.5, 0.1, false))
	var wide: float = DecisionResolver.pitch_aim_bar_precision(1.0, DecisionResolver.pitch_shot_aim_score(0.5, 1.0, true))
	var bad_bar: float = DecisionResolver.pitch_aim_bar_precision(0.4, DecisionResolver.pitch_shot_aim_score(0.5, 0.9, false))
	_check(good >= DecisionResolver.CLEAN_HIT and on_gk < DecisionResolver.CLEAN_HIT and wide < 0.3 and bad_bar < DecisionResolver.CLEAN_HIT,
		"apuntar + barra: buena puntería y verde sale (%.2f), encima del arquero no (%.2f), afuera no (%.2f), barra fallada no (%.2f)" % [good, on_gk, wide, bad_bar])

func _test_pitch_shot_formula() -> void:
	_test_aim_then_bar()
	# Remate en la cancha: lejos del arquero + fuerza justa = toque limpio;
	# encima del arquero o afuera = no; más difícil = exige más.
	var ideal: float = DecisionResolver.SHOT_POWER_IDEAL
	var clean: float = DecisionResolver.pitch_shot_precision(0.5, 1.0, ideal, false)
	var on_gk: float = DecisionResolver.pitch_shot_precision(0.5, 0.05, ideal, false)
	var wide: float = DecisionResolver.pitch_shot_precision(0.5, 1.0, ideal, true)
	var weak: float = DecisionResolver.pitch_shot_precision(0.5, 1.0, 0.15, false)
	_check(clean >= DecisionResolver.CLEAN_HIT and on_gk < DecisionResolver.CLEAN_HIT and wide < 0.3 and weak < DecisionResolver.CLEAN_HIT,
		"remate en cancha: limpio %.2f / encima del arquero %.2f / afuera %.2f / flojo %.2f" % [clean, on_gk, wide, weak])
	var easy_mid: float = DecisionResolver.pitch_shot_precision(0.0, 0.55, ideal, false)
	var hard_mid: float = DecisionResolver.pitch_shot_precision(1.0, 0.55, ideal, false)
	_check(easy_mid >= DecisionResolver.CLEAN_HIT and hard_mid < DecisionResolver.CLEAN_HIT, "remate en cancha: la dificultad exige alejarse más del arquero (%.2f fácil vs %.2f difícil)" % [easy_mid, hard_mid])

func _test_penalty_balance() -> void:
	# Promedio de "atajadas por adivinar" en el centro de la fila del medio
	# (zona 4) vs la fórmula vieja de 3 palos con la misma zona de columna.
	var n: int = 20000
	var saved_new: int = 0
	var saved_old: int = 0
	for i in range(n):
		if DecisionResolver.aim_penalty_grid_multiplier(0.4, 700.0, 4, 1.0) < 0.9:
			saved_new += 1
		if DecisionResolver.aim_shot_gk_multiplier(0.4, 700.0, 1, 1.0) < 0.9:
			saved_old += 1
	var diff: float = absf(float(saved_new - saved_old) / n)
	_check(diff < 0.02, "penal 9 zonas: misma probabilidad de que adivine que antes (%.3f vs %.3f)" % [float(saved_new) / n, float(saved_old) / n])
	var corner_saves: int = 0
	for i in range(n):
		if DecisionResolver.aim_penalty_grid_multiplier(0.9, 0.0, 0, 1.0) < 0.9:
			corner_saves += 1
	_check(corner_saves == 0, "penal 9 zonas: el ángulo de arriba con toque limpio no se ataja nunca")
	var weak: float = DecisionResolver.aim_penalty_grid_multiplier(0.0, 1400.0, 0, 0.5)
	_check(weak <= 0.5 * 0.85 + 0.0001, "penal 9 zonas: la fila de arriba castiga el toque flojo (%.3f)" % weak)

func _mk(name: String, pos: String, ovr: int) -> PlayerData:
	var p := PlayerData.new()
	p.player_name = name
	p.position = pos
	p.detailed_position = {"GK": "POR", "DF": "DFC", "MF": "MC", "ST": "DC"}[pos]
	p.overall = ovr
	p.potential = ovr
	return p

func _team(prefix: String, ovr: int) -> Array[PlayerData]:
	var out: Array[PlayerData] = []
	var spec := ["GK", "DF", "DF", "DF", "DF", "MF", "MF", "MF", "MF", "ST", "ST", "GK", "DF", "MF", "ST"]
	for i in range(spec.size()):
		out.append(_mk("%s Jugador%d" % [prefix, i], spec[i], ovr))
	return out

func _test_full_match() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	var user := _mk("Probe Delantero", "ST", 80)
	var home_pool := _team("Local", 72)
	home_pool.append(user)
	var home := MatchTeam.assemble("Local", home_pool, user, 1.0)
	var away := MatchTeam.assemble("Visita", _team("Visita", 74), null, 0.0)
	MatchState.home_team = home
	MatchState.away_team = away
	MatchState.user_player = user
	MatchState.fixture = {}
	MatchState.match_result = {}
	var engine := MatchEngine.new(home, away, user, false, false)
	MatchState.engine = engine

	var counts := {"decisions": 0, "goals": 0, "replays": 0, "taps": 0, "pitch_shots": 0, "pitch_mg": 0, "classic": []}
	var match_scene: Node = load("res://scenes/Match/Match.tscn").instantiate()
	engine.decision_requested.connect(func(_s): counts["decisions"] += 1)
	engine.event_emitted.connect(func(e: MatchEvent):
		if e.type == MatchEvent.Type.GOAL:
			counts["goals"] += 1)
	# El partido es la "escena actual" (no el probe): al terminar hace
	# change_scene_to_file al resumen, y eso libera la escena actual.
	get_tree().root.add_child(match_scene)
	get_tree().current_scene = match_scene

	var t0: int = Time.get_ticks_msec()
	var was_replaying: bool = false
	while MatchState.match_result.is_empty() and Time.get_ticks_msec() - t0 < 400000:
		await get_tree().create_timer(0.2).timeout
		if not is_instance_valid(match_scene):
			break
		var replaying: bool = bool(match_scene.get("_replaying"))
		if replaying and not was_replaying:
			counts["replays"] += 1
		was_replaying = replaying
		# Contestar decisiones: elegir la primera opción y "clavar" el toque.
		var dp: Control = match_scene.get("decision_panel")
		if dp != null and dp.visible:
			var cb: Control = match_scene.get("choice_box")
			if cb.visible and cb.get_child_count() > 1:
				var kinds: Dictionary = match_scene.get("_opts_by_kind")
				if not kinds.is_empty():
					# Primero intentar elegir TOCANDO la cancha (Paquete 2).
					var targets: Array = PitchPlays.tap_targets(kinds.keys())
					if not targets.is_empty():
						match_scene.call("_on_pitch_tapped", String(targets[0]))
						await get_tree().process_frame
						if String(match_scene.get("_chosen_kind")) != "":
							counts["taps"] += 1
					if String(match_scene.get("_chosen_kind")) == "":
						match_scene.call("_on_choice_pressed", String(kinds.keys()[0]))
					await get_tree().process_frame
			if String(match_scene.get("_minigame")) == "pitch_mg":
				counts["pitch_mg"] += 1
				match_scene.call("_on_pitch_mg_done", {"mode": match_scene.call("_pitch_mg_mode", String(match_scene.get("_chosen_kind"))), "err": 0.02, "correct": true, "clearance": 0.2, "receiver": "m2"})
			elif String(match_scene.get("_minigame")) in ["pitch_shot_bar", "pitch_pass_bar"]:
				# Fase 2 (barra): clavarla en el centro de la zona.
				match_scene.set("_meter_value", float(match_scene.get("_target_center")))
				match_scene.set("_meter_running", true)
				match_scene.call("_on_tap_pressed")
			elif String(match_scene.get("_minigame")) == "pitch_shot_style":
				# Paso 2 del remate (11-oct): elegir el golpe.
				counts["strikes"] = int(counts.get("strikes", 0)) + 1
				match_scene.call("_on_strike_chosen", ["colocado", "potente", "comba"][int(counts["strikes"]) % 3])
			elif String(match_scene.get("_minigame")) == "pitch_shot_hold":
				# Fase 2 del remate (10-oct): cargar la potencia y soltar en la zona.
				counts["shot_holds"] = int(counts.get("shot_holds", 0)) + 1
				match_scene.set("_hold_active", true)
				match_scene.set("_hold_value", float(match_scene.get("_hold_target")))
				match_scene.call("_on_tap_up")
			elif String(match_scene.get("_minigame")) == "pitch_shot":
				# Remate en la cancha: soltar apuntando al palo opuesto al arquero.
				counts["pitch_shots"] += 1
				match_scene.call("_on_pitch_shot_released", 0.545, DecisionResolver.SHOT_POWER_IDEAL, 0.46)
			else:
				# Minijuego clásico: solo deberían ser tiro libre / cabezazo / penal.
				var ck: String = String(match_scene.get("_chosen_kind"))
				if ck == "":
					ck = String(match_scene.get("_aim_kind"))
				counts["classic"].append(ck if ck != "" else "penal")
				match_scene.call("_finish_decision", 0.9)
		var ht: Control = match_scene.get("halftime_panel")
		if ht != null and ht.visible:
			match_scene.call("_on_continue_second_half_pressed")
	var secs: float = (Time.get_ticks_msec() - t0) / 1000.0
	var gs: Dictionary = MatchState.gesture_stats
	_check(int(gs.get("perfecto", 0)) + int(gs.get("bueno", 0)) > 0 and int(gs.get("best_streak", 0)) >= 1, "gestos calificados durante el partido (%s)" % str(gs))
	_check(int(counts.get("shot_holds", 0)) == int(counts["pitch_shots"]), "cada remate en la cancha pasó por la carga de potencia (%d/%d)" % [int(counts.get("shot_holds", 0)), int(counts["pitch_shots"])])
	_check(not MatchState.match_result.is_empty(), "partido real terminó (%.0f s, %d decisiones, %d goles, %d repeticiones)" % [secs, counts["decisions"], counts["goals"], counts["replays"]])
	_check(counts["decisions"] == 0 or counts["replays"] > 0, "hubo repeticiones en la cancha")
	_check(counts["decisions"] == 0 or counts["taps"] > 0, "se eligió tocando la cancha (%d veces)" % counts["taps"])
	print("     remates jugados en la cancha: %d · otros minijuegos en la cancha: %d" % [counts["pitch_shots"], counts["pitch_mg"]])
	var bad_classic: Array = []
	for k in counts["classic"]:
		if not (String(k) in ["free_kick", "aerial_duel", "penalty", "penalty_shootout", "penal"]):
			bad_classic.append(k)
	_check(bad_classic.is_empty(), "solo tiro libre / cabezazo / penal usan el minijuego clásico (clásicos: %s)" % str(counts["classic"]))
	_check(MatchState.moment_map.size() > 0 or counts["decisions"] == 0, "mapa de jugadas registrado (%d entradas)" % MatchState.moment_map.size())
	# El resumen (escena siguiente) dibuja el mapa.
	# El partido espera el pitazo final (~1,6 s) antes de ir al resumen.
	var tw: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - tw < 4000 and (get_tree().current_scene == null or get_tree().current_scene.name == "Match"):
		await get_tree().process_frame
	for i in range(10):
		await get_tree().process_frame
	var cs: Node = get_tree().current_scene
	var found: bool = false
	# 11-oct: el mapa de jugadas vive en la pestaña Estadísticas (la primera
	# ahora es Vestuario).
	if cs != null and cs.has_method("_on_tab"):
		cs.call("_on_tab", "stats")
		for i in range(4):
			await get_tree().process_frame
	if cs != null:
		for n in cs.find_children("*", "", true, false):
			if n is MomentMap:
				found = true
	_check(found or MatchState.moment_map.is_empty(), "el resumen muestra 'TUS JUGADAS EN LA CANCHA' (escena %s)" % (cs.name if cs else "?"))
	if is_instance_valid(match_scene):
		var held: Array = match_scene.get("_held_events")
		_check(held.is_empty(), "no quedó ningún evento retenido (%d)" % held.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.get_slot_path("slot_3")))

func _play_until_done(view: PitchView, play: Dictionary) -> bool:
	view.setup(play["scene"])
	view.play(play["steps"])
	var done := [false]
	view.finished.connect(func(): done[0] = true, CONNECT_ONE_SHOT)
	var t0: int = Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame
	return done[0]

func _test_package3_scripts() -> void:
	var view := PitchView.new()
	view.size = Vector2(540, 320)
	add_child(view)
	var ctx := _ctx()
	# Penal: las 9 zonas + Panenka, gol y no gol; la pelota va al lado elegido.
	var bad: Array = []
	for zone in range(10):
		for combo in [[true, true], [false, false]]:
			ctx["aim_zone"] = zone
			var steps: Array = PitchPlays.outcome_for("penalty", combo[0], combo[1], ctx)
			if combo[1]:
				var ball_x: float = -1.0
				for st in steps:
					if st.get("ball", null) is Vector2 and (st["ball"] as Vector2).y < 0.0:
						ball_x = (st["ball"] as Vector2).x
				var want: float = 0.5 if zone == 9 else 0.5 + (zone % 3 - 1) * PitchView.GOAL_W * 0.39
				if absf(ball_x - want) > 0.001:
					bad.append("penal zona %d: la pelota fue a x=%.3f (esperado %.3f)" % [zone, ball_x, want])
			if not await _play_until_done(view, {"scene": PitchPlays.scene_for("penalty", ctx), "steps": steps}):
				bad.append("penal zona %d %s no terminó" % [zone, combo])
	ctx.erase("aim_zone")
	for b in bad:
		print("   ", b)
	_check(bad.is_empty(), "penal en la cancha: la pelota va a la zona elegida (10 zonas × gol/no gol)")
	var ok_all: bool = true
	for ph in ["kickoff", "half", "full"]:
		ok_all = ok_all and await _play_until_done(view, PitchPlays.whistle_scene(ph, ctx))
	for red in [false, true]:
		for ours in [false, true]:
			ok_all = ok_all and await _play_until_done(view, PitchPlays.card_scene(ctx, "Carlos Tarjeteado", false, ours, red))
	for ours in [false, true]:
		ok_all = ok_all and await _play_until_done(view, PitchPlays.penalty_award_scene(ctx, ours))
		ok_all = ok_all and await _play_until_done(view, PitchPlays.ai_penalty_goal(ctx, "Ivan Penalero", ours))
	_check(ok_all, "árbitro: pitazos, tarjetas, cobro de penal y penal de la IA se reproducen")
	# Árbitros en pixel art (3, con animaciones).
	var counts_ref := {}
	for i in range(300):
		var rid: String = Referee.for_fixture({"home_club_id": "c%d" % i, "away_club_id": "x", "matchday": i}, 7)
		counts_ref[rid] = int(counts_ref.get(rid, 0)) + 1
	_check(counts_ref.size() == 3, "árbitro por partido: reparte entre los 3 (%s)" % str(counts_ref))
	var all_anims: bool = true
	for r in Referee.REFEREES:
		var aset: Dictionary = Referee.anim_set(String(r["id"]))
		if aset.size() != 8 or (aset["amarilla"] as Array).size() != 9 or (aset["run_east"] as Array).size() != 6:
			all_anims = false
			print("   árbitro %s: %s" % [r["id"], aset.keys()])
	_check(all_anims, "los 3 árbitros tienen sus 8 animaciones (idle, pitazo, amarilla, roja, correr ×4)")
	ctx["ref_anims"] = Referee.anim_set("amarillo")
	var spr_ok: bool = await _play_until_done(view, PitchPlays.card_scene(ctx, "Carlos Tarjeteado", false, true, true))
	spr_ok = spr_ok and await _play_until_done(view, PitchPlays.whistle_scene("kickoff", ctx))
	_check(spr_ok, "escenas del árbitro con sprite animado se reproducen")
	ctx.erase("ref_anims")
	var card: Dictionary = PitchPlays.card_scene(ctx, "Carlos Tarjeteado", false, true, true)
	var sets_card: bool = false
	for st in card["steps"]:
		if (st.get("set_card", {}) as Dictionary).has("ref"):
			sets_card = true
	_check(sets_card, "tarjeta: el árbitro la levanta")
	# VAR REAL (10-oct): la repetición dibuja lo que el motor ya decidió
	# (PitchPlays.var_mode) — sin revisión no hay línea; "valid" muestra la
	# revisión y GOL VÁLIDO; "annulled" termina en GOL ANULADO.
	var var_ok: bool = true
	for mode in ["", "valid", "annulled"]:
		PitchPlays.var_mode = mode
		ctx["seed"] = 7
		var steps: Array = PitchPlays.outcome_for("shot_on_goal", true, true, ctx)
		var has_line: bool = false
		var annulled: bool = false
		var valid: bool = false
		for st in steps:
			# 11-oct: la linea solo sale si hay adelantado de verdad (ver
			# tools/OffsideProbe); lo que nunca falta es la revision.
			if String(st.get("flash", "")).contains("VAR"):
				has_line = true
			if String(st.get("flash", "")).contains("ANULADO"):
				annulled = true
			if String(st.get("flash", "")).contains("VÁLIDO"):
				valid = true
		if mode == "" and (has_line or annulled or valid):
			var_ok = false
		if mode == "valid" and not (has_line and valid and not annulled):
			var_ok = false
		if mode == "annulled" and not (has_line and annulled and not valid):
			var_ok = false
	PitchPlays.var_mode = ""
	_check(var_ok, "VAR: la repetición muestra exactamente lo que decidió el motor (sin revisión / válido / anulado)")
	ctx["seed"] = 42
	view.queue_free()

## El penal TUYO ahora emite DECISION_RESULT (antes, errarlo no avisaba nada).
func _test_penalty_result_event() -> void:
	var user := _mk("Probe Penalero", "ST", 80)
	var home_pool := _team("Local", 72)
	home_pool.append(user)
	var home := MatchTeam.assemble("Local", home_pool, user, 1.0)
	var away := MatchTeam.assemble("Visita", _team("Visita", 74), null, 0.0)
	var engine := MatchEngine.new(home, away, user, false, true) # instant: el motor patea solo
	engine._user_is_on_pitch = true
	var got := {"request": 0, "result": 0}
	engine.event_emitted.connect(func(e: MatchEvent):
		if e.type == MatchEvent.Type.DECISION_REQUEST and String(e.payload.get("kind", "")) == "penalty":
			got["request"] += 1
		if e.type == MatchEvent.Type.DECISION_RESULT and String(e.payload.get("kind", "")) == "penalty":
			got["result"] += 1)
	var tries: int = 0
	while got["request"] < 6 and tries < 400000:
		engine._penalties_used = 0
		await engine._maybe_environmental_penalty(30)
		tries += 1
	_check(got["request"] >= 6 and got["result"] == got["request"], "penal tuyo: cada penal emite su resultado (%d pedidos, %d resultados)" % [got["request"], got["result"]])

func _tap_at(view: PitchView, px: Vector2, to_px: Vector2 = Vector2.INF) -> void:
	var a := InputEventMouseButton.new()
	a.button_index = MOUSE_BUTTON_LEFT
	a.pressed = true
	a.position = px
	view._gui_input(a)
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = false
	b.position = px if to_px == Vector2.INF else to_px
	view._gui_input(b)

func _run_mg(view: PitchView, kind: String, mode: String, act: Callable) -> Dictionary:
	var ctx := _ctx()
	view.setup(PitchPlays.scene_for(kind, ctx))
	var got := {}
	var cb := func(r): got.merge(r)
	view.minigame_done.connect(cb, CONNECT_ONE_SHOT)
	var mg: PitchMinigame = view.start_minigame(mode, kind, 0.5, 1.0)
	var t0: int = Time.get_ticks_msec()
	while got.is_empty() and Time.get_ticks_msec() - t0 < 9000:
		await get_tree().process_frame
		act.call(view, mg)
	if view.minigame_done.is_connected(cb):
		view.minigame_done.disconnect(cb)
	return got

func _test_pitch_minigames() -> void:
	var view := PitchView.new()
	view.size = Vector2(540, 320)
	add_child(view)
	await get_tree().process_frame
	# Pase: tocar al compañero → claridad de la línea + receptor.
	var r1: Dictionary = await _run_mg(view, "key_pass", "pass", func(v, mg):
		if mg.t > 0.4 and not mg.finished:
			_tap_at(v, v.to_screen(v.npos("m1"))))
	_check(r1.get("receiver", "") == "m1" and r1.has("clearance"), "minijuego pase: tocar al compañero mide su línea (%s)" % str(r1))
	# Regate: deslizar al lado CONTRARIO justo cuando entra.
	var r2: Dictionary = await _run_mg(view, "dribble", "dribble", func(v, mg):
		if mg.t >= mg._lunge_t and not mg.finished:
			var c: Vector2 = v.to_screen(v.npos("user"))
			_tap_at(v, c, c + v.screen_dir_x() * (-mg._lean * 60.0)))
	_check(bool(r2.get("correct", false)) and absf(float(r2.get("err", 9))) < 0.15, "minijuego regate: lado contrario a tiempo = correcto (%s)" % str(r2))
	# Defensa: tocar cuando la pelota brilla.
	var r3: Dictionary = await _run_mg(view, "tackle", "defend", func(v, mg):
		if mg.t >= float(mg._expose_t[0]) and not mg.finished:
			_tap_at(v, Vector2(200, 200)))
	_check(absf(float(r3.get("err", 9))) < 0.1, "minijuego defensa: tocar cuando brilla = error ~0 (%s)" % str(r3))
	# Arquero: deslizar hacia el palo del remate después de que patea.
	var r4: Dictionary = await _run_mg(view, "one_on_one_save", "keeper", func(v, mg):
		if mg.t >= mg._shot_t + 0.1 and not mg.finished:
			_tap_at(v, Vector2(270, 100), Vector2(270, 100) + v.screen_dir_x() * (mg._shot_side * 60.0)))
	_check(bool(r4.get("correct", false)) and not r4.get("guess", false), "minijuego arquero: lado correcto después del remate (%s)" % str(r4))
	var r5: Dictionary = await _run_mg(view, "one_on_one_save", "keeper", func(v, mg):
		if mg.t >= 0.3 and not mg.finished:
			_tap_at(v, Vector2(270, 100), Vector2(270, 100) + v.screen_dir_x() * (mg._shot_side * 60.0)))
	_check(bool(r5.get("guess", false)), "minijuego arquero: tirarse antes = adivinar (%s)" % str(r5))
	# Sin hacer nada: se resuelve solo (no traba el partido).
	var r6: Dictionary = await _run_mg(view, "tackle", "defend", func(_v, _mg): pass)
	_check(bool(r6.get("timeout", false)), "minijuego sin tocar nada: se resuelve solo")
	# Remate: el arrastre LATERAL mueve la mira de palo a palo (antes casi
	# todo caía al medio — reporte de Wilber).
	var aims := {}
	for side in [-1, 0, 1]:
		view.setup(PitchPlays.scene_for("shot_on_goal", _ctx()))
		await get_tree().process_frame
		var got := {}
		var cb2 := func(ax, pw, _gx):
			got["ax"] = ax
			got["pw"] = pw
		view.shot_released.connect(cb2, CONNECT_ONE_SHOT)
		view.start_shot_aim(0.5, 1.0, 0.15)
		var start := Vector2(270, 260)
		var span: float = view.aim_span_x()
		var up: float = view.aim_span_y() * DecisionResolver.SHOT_POWER_IDEAL
		_tap_at(view, start, start + Vector2(side * span, -up))
		# 11-oct: la jugada puede venir espejada; "a la izquierda" es siempre
		# el palo que se VE a la izquierda (en la jugada, el otro lado).
		if view.scene_mirror and got.has("ax"):
			got["ax"] = 1.0 - float(got["ax"])
		aims[side] = got
	var post: float = PitchView.GOAL_W * 0.5
	_check(absf(float(aims[-1].get("ax", 0)) - (0.5 - post)) < 0.004 and absf(float(aims[1].get("ax", 0)) - (0.5 + post)) < 0.004 and absf(float(aims[0].get("ax", 0)) - 0.5) < 0.002,
		"remate: arrastre lateral = mira en palo izq / medio / palo der (%.3f / %.3f / %.3f)" % [float(aims[-1].get("ax", 0)), float(aims[0].get("ax", 0)), float(aims[1].get("ax", 0))])
	_check(absf(float(aims[0].get("pw", 0)) - DecisionResolver.SHOT_POWER_IDEAL) < 0.02, "remate: arrastre hacia arriba = fuerza (%.2f)" % float(aims[0].get("pw", 0)))
	# Pase arrastrado al espacio: lo recibe el compañero más cercano.
	var rp: Dictionary = await _run_mg(view, "key_pass", "pass", func(v, mg):
		if mg.t > 0.3 and not mg.finished:
			var m1: Vector2 = v.npos("m1")
			_tap_at(v, v.to_screen(v.nball()), v.to_screen(m1 + Vector2(0, -0.05))))
	_check(rp.get("receiver", "") == "m1" and rp.has("to"), "pase arrastrado al espacio: lo recibe el compañero cercano (%s)" % str(rp))
	# Las fórmulas: buen momento = limpio, lado equivocado = malo.
	_check(DecisionResolver.pitch_timing_precision(0.5, 0.02, true, 0.3, 0.12) >= DecisionResolver.CLEAN_HIT and DecisionResolver.pitch_timing_precision(0.5, 0.02, false, 0.3, 0.12) < 0.3, "fórmula de momento justo: a tiempo sale, lado equivocado no")
	_check(DecisionResolver.pitch_pass_precision(0.5, 0.2) >= DecisionResolver.CLEAN_HIT and DecisionResolver.pitch_pass_precision(0.5, 0.01) < 0.3, "fórmula de pase: línea libre sale, tapada no")
	view.queue_free()
