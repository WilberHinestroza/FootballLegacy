extends Node
## Prototipo match_v2 — corre N partidos headless con el usuario en
## piloto automático y promedia los números (goles, remates, pases, cuántas
## veces le llega el balón al usuario). No toca saves ni autoloads.
##   godot --headless --path . res://tools/ProtoMatchV2Probe.tscn -- [partidos] [rol]
const Sim = preload("res://prototypes/match_v2/ProtoSim.gd")
const Director = preload("res://prototypes/match_v2/ProtoDirector.gd")

func _robot_act(sim) -> void:
	var u = sim.user()
	if u.pos.y < 26.0:
		var side: float = 1.0 if randf() < 0.5 else -1.0
		sim.user_kick(Vector2(34.0 + side * 2.6, 0.0) - u.pos, randf_range(0.5, 0.9), randf_range(-0.3, 0.3))
		return
	var r: float = randf()
	if r < 0.45:
		var best = null
		for a in sim.agents:
			if a.team == 0 and not a.is_user and a.role != "GK":
				if best == null or a.pos.y < best.pos.y:
					best = a
		sim.user_pass_to(best.idx)
	elif r < 0.6:
		sim.user_skill(Vector2(randf_range(-1.0, 1.0), -1.0))
	elif r < 0.75:
		sim.user_kick(Vector2(randf_range(-0.4, 0.4), -1.0), randf_range(0.3, 0.6), 0.0)
	else:
		sim.user_run_to(u.pos + Vector2(randf_range(-5.0, 5.0), -9.0))

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var n: int = int(args[0]) if args.size() > 0 else 20
	var role: String = args[1] if args.size() > 1 else "ST"
	## "scripted": el usuario NO es IA — un robot usa la API de gestos
	## (user_kick / user_pass_to / user_run_to) con el ritmo real de
	## desired_time_scale(), así se mide cuánto dura el partido en minutos
	## reales y se ejercitan los caminos del usuario.
	var scripted: bool = args.size() > 2 and args[2] in ["scripted", "plays"]
	## "plays": partido POR JUGADAS (ProtoDirector), con el robot de gestos.
	var plays: bool = args.size() > 2 and args[2] == "plays"
	var tot := {"goals": 0.0, "shots": 0.0, "on_target": 0.0, "passes": 0.0, "passes_ok": 0.0,
		"user_receptions": 0.0, "user_shots": 0.0, "user_goals": 0.0, "user_assists": 0.0,
		"user_passes": 0.0, "user_ball_time": 0.0, "sim_time": 0.0, "goals0": 0.0, "goals1": 0.0}
	var dt: float = 1.0 / 30.0
	for i in range(n):
		# args[3] / args[4]: formación local / visitante ("rand" = una distinta por partido).
		var forms: Array = Sim.FORMATION_BASES.keys()
		var hf: String = args[3] if args.size() > 3 else "4-4-2"
		var af: String = args[4] if args.size() > 4 else hf
		if hf == "rand":
			hf = forms[i % forms.size()]
		if af == "rand":
			af = forms[(i * 7 + 3) % forms.size()]
		var sim = Sim.new(role, 1000 + i, 70, 70, hf, af)
		sim.user_auto = not scripted
		sim.sim_event.connect(func(kind, d):
			var key: String = "ev_" + kind + ("_" + String(d["kind"]) if kind == "set_piece" else "")
			tot[key] = float(tot.get(key, 0.0)) + 1.0)
		var steps: int = 0
		var real_t: float = 0.0
		var think: float = 0.0
		var director = null
		if plays:
			director = Director.new(2000 + i, role)
			sim.plays_mode = true
			var p0: Dictionary = director.next()
			sim.setup_play(String(p0["kind"]), int(p0["min"]))
		while not sim.finished and steps < 400000:
			if plays and sim.play_over:
				var key2: String = "play_%s_%s" % [sim.play_kind, sim.play_result]
				tot[key2] = float(tot.get(key2, 0.0)) + 1.0
				if not director.has_next():
					break
				var pn: Dictionary = director.next()
				for bgt in pn.get("bg", []):
					sim.score[int(bgt)] += 1
				sim.setup_play(String(pn["kind"]), int(pn["min"]))
				continue
			var sc: float = sim.desired_time_scale()
			if scripted and sim.user_has_ball():
				think += dt
				if think > 0.8: # el "jugador" piensa 0,8 s reales
					think = 0.0
					_robot_act(sim)
			if scripted and not sim.user_has_ball() and sim.owner >= 0:
				var c = sim.carrier()
				var u2 = sim.user()
				if c.team == 1 and c.pos.distance_to(u2.pos) < 4.0 and randf() < 0.008:
					sim.user_slide(c.pos - u2.pos)
			sim.step(dt * sc)
			real_t += dt
			steps += 1
		tot["real_minutes"] = float(tot.get("real_minutes", 0.0)) + real_t / 60.0
		var s: Dictionary = sim.stats
		tot["goals0"] += sim.score[0]
		tot["goals1"] += sim.score[1]
		tot["goals"] += sim.score[0] + sim.score[1]
		tot["shots"] += s["shots"][0] + s["shots"][1]
		tot["on_target"] += s["on_target"][0] + s["on_target"][1]
		tot["passes"] += s["passes"][0] + s["passes"][1]
		tot["passes_ok"] += s["passes_ok"][0] + s["passes_ok"][1]
		for k in ["user_receptions", "user_shots", "user_goals", "user_assists", "user_passes", "user_ball_time", "user_skills", "user_skills_ok", "user_slides", "user_slides_won", "user_fouls", "user_yellows"]:
			if not tot.has(k):
				tot[k] = 0.0
			tot[k] += float(s[k])
		tot["sim_time"] += sim.t
		print("partido %d: %d-%d  remates %d-%d  pases ok %d/%d  usuario: recibe %d, remata %d, goles %d" % [i, sim.score[0], sim.score[1], s["shots"][0], s["shots"][1], s["passes_ok"][0] + s["passes_ok"][1], s["passes"][0] + s["passes"][1], s["user_receptions"], s["user_shots"], s["user_goals"]])
	print("--- PROMEDIO (%d partidos, rol %s) ---" % [n, role])
	for k in tot.keys():
		print("  %s: %.2f" % [k, tot[k] / n])
	get_tree().quit(0)
