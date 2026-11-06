extends Node
## Tres bugs reportados el 11-oct: (1) "va al arco pero dice afuera",
## (2) "siempre la misma falta entre los mismos", (3) "la accion siguiente
## me pone en el lugar de siempre".
##   godot --headless --path . res://tools/ThreeBugsProbe.tscn
func _ctx(sd: int) -> Dictionary:
	var mates: Array = []
	var rivals: Array = []
	for i in range(9):
		mates.append({"num": str(i + 2), "name": "MATE%d" % i, "look": {"tint_hair": "#2b2320"}})
		rivals.append({"num": str(i + 2), "name": "RIVAL%d" % i, "look": {"tint_hair": "#c98f4b"}})
	return {"seed": sd, "us": Color(0.2, 0.4, 0.9), "them": Color(0.85, 0.2, 0.2),
		"user": {"num": "9", "name": "WILBER"}, "mates": mates, "rivals": rivals,
		"our_gk": {"num": "1", "name": "ARQUERO"}, "their_gk": {"num": "1", "name": "RIVALGK"}}

func _ready() -> void:
	var fails: int = 0
	var half: float = PitchView.GOAL_W * 0.5
	# (1) Remate fallado: el cartel coincide con donde va la pelota.
	var wrong: int = 0
	var n1: int = 0
	var outs: int = 0
	for kind in ["shot_on_goal", "one_on_one", "long_shot", "volley"]:
		for sd in range(60):
			for ax in [0.5 - half * 0.9, 0.5 - half * 0.4, 0.5, 0.5 + half * 0.5, 0.5 + half * 0.95, 0.5 + half * 1.4, 0.5 - half * 1.4]:
				var c := _ctx(sd)
				c["aim_x"] = ax
				var steps: Array = PitchPlays.outcome_for(kind, false, false, c)
				var ball_x: float = -9.0
				var text: String = ""
				for s in steps:
					if (s as Dictionary).get("ball", null) is Vector2 and (s["ball"] as Vector2).y < 0.06:
						ball_x = (s["ball"] as Vector2).x
					if String((s as Dictionary).get("flash", "")) != "":
						text = String(s["flash"])
				n1 += 1
				var inside: bool = ball_x > -1.0 and absf(ball_x - 0.5) <= half
				if text.contains("AFUERA"):
					outs += 1
					if inside or absf(ax - 0.5) <= half:
						wrong += 1
	if wrong > 0 or outs == 0:
		fails += 1
		print("FAIL 'afuera' con la pelota adentro o apuntando adentro: %d de %d (afueras: %d)" % [wrong, n1, outs])
	else:
		print("OK   remate fallado: %d casos, %d 'afuera', todos por fuera del palo y solo si apuntaste afuera" % [n1, outs])
	# (2) Faltas: cambia la victima y el lugar; el amonestado es el.
	var victims := {}
	var spots := {}
	var with_look: int = 0
	for i in range(9):
		var c2 := _ctx(100 + i)
		var play: Dictionary = PitchPlays.card_scene(c2, "MATE%d" % i, false, true, false)
		for a in play["scene"]["actors"]:
			if String(a["id"]) == "v":
				victims[String(a["name"])] = true
			if String(a["id"]) == "p":
				spots[str((a["pos"] as Vector2).snapped(Vector2(0.05, 0.05)))] = true
				if String(a["name"]) == "MATE%d" % i and (a as Dictionary).has("look"):
					with_look += 1
	if victims.size() < 3 or spots.size() < 3 or with_look < 9:
		fails += 1
		print("FAIL faltas repetidas: victimas distintas %d, lugares distintos %d, amonestado con su cara %d/9" % [victims.size(), spots.size(), with_look])
	else:
		print("OK   faltas: %d victimas distintas y %d lugares distintos en 9 tarjetas; el amonestado sale con su cara" % [victims.size(), spots.size()])
	# (3) La jugada sigue donde quedaste.
	var c3 := _ctx(7)
	var bad3: int = 0
	for wx in [0.2, 0.5, 0.8]:
		c3["user_at_world"] = Vector2(wx, 0.3)
		for kind in ["shot_on_goal", "key_pass", "cutback", "dribble", "through_ball"]:
			var sc: Dictionary = PitchPlays.scene_for(kind, c3)
			for a in sc["actors"]:
				# En la cancha (si la jugada va espejada, su x esta dada vuelta).
				var ux: float = (a["pos"] as Vector2).x
				if bool(sc.get("mirror", false)):
					ux = 1.0 - ux
				if String(a["id"]) == "user" and absf(ux - wx) > 0.02:
					bad3 += 1
					print("  %s: pedido x=%.2f, quedo en %.2f" % [kind, wx, ux])
	c3.erase("user_at_world")
	var base_x: float = 0.0
	for a in PitchPlays.scene_for("shot_on_goal", c3)["actors"]:
		if String(a["id"]) == "user":
			base_x = (a["pos"] as Vector2).x
	# Y hay jugadas por las dos bandas.
	var mirrored: int = 0
	for sd in range(40):
		if PitchPlays.mirror_for("shot_on_goal", _ctx(sd)):
			mirrored += 1
	if mirrored < 8 or mirrored > 32:
		fails += 1
		print("FAIL espejo: %d de 40 jugadas espejadas" % mirrored)
	else:
		print("OK   jugadas por las dos bandas: %d de 40 espejadas" % mirrored)
	if bad3 > 0 or absf(base_x - 0.42) > 0.001:
		fails += 1
		print("FAIL posicion encadenada: %d casos mal (sin encadenar x=%.2f)" % [bad3, base_x])
	else:
		print("OK   la accion siguiente arranca en tu costado (3 posiciones x 5 jugadas); una jugada nueva arranca en su lugar de siempre")
	# (4) Altura elegida con la fuerza: arriba y al palo = angulo; abajo = rasante.
	var bad4: int = 0
	var angles: int = 0
	var lows: int = 0
	for sd in range(40):
		for lvl in ["high", "low"]:
			var c4 := _ctx(sd)
			c4["aim_x"] = 0.5 + half * 0.9
			c4["shot_level"] = lvl
			var st4: Array = PitchPlays.outcome_for("shot_on_goal", true, true, c4)
			var arc4: float = -1.0
			var txt4: String = ""
			for s4 in st4:
				if (s4 as Dictionary).get("ball", null) is Vector2 and (s4["ball"] as Vector2).y < 0.06 and arc4 < 0.0:
					arc4 = float((s4 as Dictionary).get("arc", 0.0))
				if String((s4 as Dictionary).get("flash", "")).contains("GOL") and txt4 == "":
					txt4 = String(s4["flash"])
			if lvl == "high":
				if arc4 < 1.8 or not txt4.contains("NGULO"):
					bad4 += 1
				else:
					angles += 1
			else:
				if arc4 > 0.2 or txt4.contains("NGULO"):
					bad4 += 1
				else:
					lows += 1
	if bad4 > 0:
		fails += 1
		print("FAIL altura del remate: %d casos mal" % bad4)
	else:
		print("OK   altura del remate: %d al angulo (pelota alta) y %d rasantes, segun la fuerza elegida" % [angles, lows])
	# (5) El palo: sin rebote lo despeja un RIVAL (termina); con rebote, sigue.
	var post_end: int = 0
	var post_live: int = 0
	var bad5: int = 0
	for sd in range(120):
		var c5 := _ctx(sd)
		c5["aim_x"] = 0.5 + half * 0.95
		var st5: Array = PitchPlays.outcome_for("shot_on_goal", false, false, c5)
		for s5 in st5:
			if String((s5 as Dictionary).get("flash", "")).contains("PALO"):
				post_end += 1
				var mover: String = ""
				for s6 in st5:
					for mid in ((s6 as Dictionary).get("moves", {}) as Dictionary).keys():
						if String(mid) != "gk" and String(mid) != "user":
							mover = String(mid)
				if not mover.begins_with("d"):
					bad5 += 1
		PitchPlays.rebound_mode = true
		var st7: Array = PitchPlays.outcome_for("shot_on_goal", true, false, c5)
		PitchPlays.rebound_mode = false
		for s7 in st7:
			if String((s7 as Dictionary).get("flash", "")).contains("SIGUE"):
				post_live += 1
	if bad5 > 0 or post_end == 0 or post_live == 0:
		fails += 1
		print("FAIL palo: terminan %d (mal: %d), siguen %d" % [post_end, bad5, post_live])
	else:
		print("OK   palo: %d veces lo despeja un rival (termina) y %d veces queda viva (sigue la jugada)" % [post_end, post_live])
	print("PROBE ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
