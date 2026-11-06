extends "res://tools/ui_gallery_probe.gd"
## REMATE EN 3 PASOS (11-oct): apuntar -> como le pegas -> potencia. slot_3.
##   godot --path . --resolution 432x936 res://tools/StrikeProbe.tscn
var _fails: int = 0
func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		_fails += 1

func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _ready() -> void:
	_seed_career()
	await get_tree().process_frame
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	var m: Node = (load("res://scenes/Match/Match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	await _wait(200)
	MatchState.engine.hold = true
	await _wait(160)
	var t0: int = Time.get_ticks_msec()
	while (bool(m.get("_replaying")) or (m.get("decision_panel") as Control).visible) and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	var opts: Array = []
	for k in ["shot_on_goal", "key_pass", "dribble"]:
		opts.append({"kind": k, "difficulty": 0.4, "label": k, "risk": "media"})
	m.call("_on_decision_requested", {"minute": 30, "kind": "shot_on_goal", "player": MatchState.user_player, "narration": "Prueba.", "options": opts})
	await _wait(40)
	_check((m.get("choice_box") as Control).visible, "primero el menu de botones")
	m.call("_on_choice_pressed", "shot_on_goal")
	await _wait(30)
	_check(String(m.get("_minigame")) == "pitch_shot", "paso 1: apuntar en la cancha")
	m.call("_on_pitch_shot_released", 0.5 + PitchView.GOAL_W * 0.4, DecisionResolver.SHOT_POWER_IDEAL, 0.46)
	await _wait(20)
	_check(String(m.get("_minigame")) == "pitch_shot_style", "paso 2: elegir como pegarle")
	var box: Node = (m.get("meter_area") as Node).get_node_or_null("MG_strike")
	var btns: int = 0
	if box != null:
		for c in box.get_children():
			if c is Button:
				btns += 1
	_check(btns == 4, "cuatro golpes para elegir: colocado, potente, comba adentro y comba afuera (%d)" % btns)
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/strike_choice.png"))
	m.call("_on_strike_chosen", "comba")
	await _wait(20)
	_check(String(m.get("_minigame")) == "pitch_shot_hold", "paso 3: la potencia")
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/strike_power.png"))
	# Los trueques de cada golpe.
	var wide_c: float = float(DecisionResolver.strike("colocado")["zone"])
	var wide_p: float = float(DecisionResolver.strike("potente")["zone"])
	_check(wide_c > 1.0 and wide_p < 1.0, "colocado ensancha la zona de fuerza y potente la achica")
	_check(DecisionResolver.strike_precision(0.99, "colocado") < 0.93 and DecisionResolver.strike_precision(0.90, "potente") >= 0.93, "colocado no llega al 'perfecto'; potente limpio si")
	_check(DecisionResolver.strike_aim_score(0.8, "comba") > 1.0 and DecisionResolver.strike_aim_score(0.8, "colocado") < 1.0, "con comba alcanza con apuntar menos al palo")
	_check(DecisionResolver.strike_precision(0.5, "potente") < DecisionResolver.CLEAN_HIT, "un remate mal pegado no se salva por elegir potente")
	# La comba se ve.
	var ctx := {"seed": 5, "us": Color.BLUE, "them": Color.RED, "user": {"num": "9", "name": "W"}, "mates": [], "rivals": [], "aim_x": 0.5 + PitchView.GOAL_W * 0.4, "strike": "comba"}
	var curved: bool = false
	for st in PitchPlays.outcome_for("shot_on_goal", true, true, ctx):
		if absf(float((st as Dictionary).get("curve", 0.0))) >= 0.02:
			curved = true
	_check(curved, "el remate con comba dobla en la repeticion")
	# Adentro y afuera doblan para lados OPUESTOS (mismo palo).
	var c_in: float = 0.0
	var c_out: float = 0.0
	for pair in [["comba", 0], ["comba_fuera", 1]]:
		ctx["strike"] = pair[0]
		for st2 in PitchPlays.outcome_for("shot_on_goal", true, true, ctx):
			if absf(float((st2 as Dictionary).get("curve", 0.0))) >= 0.02:
				if int(pair[1]) == 0:
					c_in = float(st2["curve"])
				else:
					c_out = float(st2["curve"])
	_check(c_in * c_out < 0.0, "comba adentro y comba afuera doblan para lados opuestos (%.2f / %.2f)" % [c_in, c_out])
	print("PROBE ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
