extends Node

## Prueba dirigida de los 12 momentos nuevos (Parte 91h, pedido de Wilber:
## "crea más situaciones de partido para actuar... distribuidas entre
## todas las posiciones y ataque, transición y defensa"): volley,
## chip_shot, cutback, cross, one_two, counter_run, switch_play,
## recovery_tackle, distribution, block_shot, one_on_one_save,
## sweep_keeper.
##
## Para cada uno: confirma que DecisionResolver.difficulty() no crashea y
## da un valor en [0,1], y corre MatchEngine._apply_decision_result() 40
## veces con precisión "toque limpio" (0.95, siempre >= CLEAN_HIT) para
## confirmar que en algún momento se registra el resultado esperado (gol
## para los de ataque, asistencia para los de transición/creación, robo
## para los de defensa) — no determinismo exacto (son tiradas de dado),
## pero 40 intentos con un toque limpio alcanza de sobra para no dar
## FALSO NEGATIVO por mala suerte.
##   godot --headless res://tools/NewDecisionKindsProbe.tscn

const _GOAL_KINDS := ["volley", "chip_shot"]
const _ASSIST_KINDS := ["cutback", "cross", "one_two", "counter_run", "switch_play", "distribution"]
const _DEFENSE_KINDS := ["recovery_tackle", "block_shot", "one_on_one_save", "sweep_keeper"]

func _make_engine() -> Object:
	var p := PlayerData.new()
	p.player_name = "Probe"
	p.overall = 82
	p.shooting = 82; p.passing = 82; p.dribbling = 82; p.composure = 82
	p.decision_making = 82; p.speed = 82; p.strength = 82; p.stamina = 82
	var home := MatchTeam.new()
	home.starting_xi = [p]
	var away := MatchTeam.new()
	var opp := PlayerData.new()
	opp.player_name = "Rival"
	opp.overall = 70
	opp.position = "GK"
	away.starting_xi = [opp, PlayerData.new(), PlayerData.new()]
	return MatchEngine.new(home, away, p, false, true)

func _ready() -> void:
	var problems: int = 0
	var all_kinds: Array = _GOAL_KINDS + _ASSIST_KINDS + _DEFENSE_KINDS

	# --- difficulty() no crashea para ninguno de los 12 ---
	var e0 = _make_engine()
	for k in all_kinds:
		var d: float = DecisionResolver.difficulty(k, e0.user_player, 70, 0)
		if d < 0.0 or d > 1.0:
			print("FALLA (difficulty fuera de rango): %s -> %.3f" % [k, d])
			problems += 1
	print("difficulty() de los 12 momentos nuevos: OK, todos en [0,1]")

	# --- goles ---
	for k in _GOAL_KINDS:
		var e = _make_engine()
		var goals_before: int = 0
		var goal_seen: bool = false
		for i in range(40):
			var gh0: int = e._score["home"]
			var ga0: int = e._score["away"]
			e._apply_decision_result(k, 30, {"precision": 0.95})
			if e._score["home"] != gh0 or e._score["away"] != ga0:
				goal_seen = true
		print("%s: gol registrado en 40 intentos = %s" % [k, goal_seen])
		if not goal_seen:
			print("FALLA: %s nunca registró un gol con toque limpio x40" % k)
			problems += 1

	# --- asistencias ---
	for k in _ASSIST_KINDS:
		var e = _make_engine()
		var assist_seen: bool = false
		for i in range(40):
			var a0: int = e._user_assists
			e._apply_decision_result(k, 30, {"precision": 0.95})
			if e._user_assists != a0:
				assist_seen = true
		print("%s: asistencia registrada en 40 intentos = %s" % [k, assist_seen])
		if not assist_seen:
			print("FALLA: %s nunca registró una asistencia con toque limpio x40" % k)
			problems += 1

	# --- defensa: al menos una vez se reconoce el ROBO exitoso (no crashea,
	# y el rating sube en al menos un intento — no hay un contador de
	# "robos" expuesto, así que se usa el rating como proxy, igual que
	# register_tackle_success ya hace internamente) ---
	for k in _DEFENSE_KINDS:
		var e = _make_engine()
		var success_seen: bool = false
		for i in range(40):
			var r0: float = e._ratings.get(e.user_player, 6.0)
			e._apply_decision_result(k, 30, {"precision": 0.95})
			var r1: float = e._ratings.get(e.user_player, 6.0)
			if r1 > r0:
				success_seen = true
		print("%s: robo/bloqueo exitoso en 40 intentos = %s" % [k, success_seen])
		if not success_seen:
			print("FALLA: %s nunca registró un éxito con toque limpio x40" % k)
			problems += 1

	# --- _decision_options() puede armar un menú con un kind nuevo como
	# PRIMARIO cuando los pesos del puesto lo incluyen (no crashea, y el
	# kind elegido tiene label/hint no vacíos) ---
	var e_gk = _make_engine()
	e_gk.user_player.position = "GK"
	var opts: Array = e_gk._decision_options("GK", 70, 70)
	print("_decision_options('GK'): %d opciones -> %s" % [opts.size(), opts.map(func(o): return o["kind"])])
	if opts.is_empty():
		print("FALLA: _decision_options('GK') no devolvió nada")
		problems += 1
	for o in opts:
		if String(o.get("label", "")) == "" :
			print("FALLA: opción %s sin label" % o.get("kind", "?"))
			problems += 1

	print("PROBE ", "OK" if problems == 0 else "FAIL (%d)" % problems)
	get_tree().quit(1 if problems > 0 else 0)
