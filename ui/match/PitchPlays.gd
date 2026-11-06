extends RefCounted
class_name PitchPlays

## Guiones de jugada para PitchView (Paquete 1 del ROADMAP). Para cada
## `kind` de momento clave (los mismos de MatchEngine._decision_options)
## arma DÓNDE está cada uno y CÓMO termina — pero el resultado NO se decide
## acá: llega ya resuelto por DecisionResolver en el DECISION_RESULT
## (success / goal). Esto solo elige una forma creíble de mostrarlo.
##
## Siempre se dibuja la media cancha con el arco que importa ARRIBA:
##  - jugadas de ataque: arriba el arco RIVAL (arquero de ellos).
##  - defensa / arquero / gol rival: arriba TU arco (arquero tuyo).
##
## ctx (lo arma Match.gd): {"seed": int, "us": Color, "them": Color,
##   "user": {num, name}, "mates": [{num, name}...], "rivals": [...],
##   "our_gk": {num, name}, "their_gk": {num, name}}

const SHOT := ["shot_on_goal", "one_on_one", "long_shot", "free_kick", "volley", "chip_shot", "aerial_duel", "penalty", "penalty_shootout"]
const PASS := ["key_pass", "through_ball", "cutback", "cross", "one_two", "switch_play"]
const DRIBBLE := ["dribble", "counter_run"]
const DEFEND := ["pressing", "tackle", "interception", "clearance", "last_ditch_tackle", "recovery_tackle", "block_shot"]
const KEEPER := ["one_on_one_save", "sweep_keeper", "distribution", "penalty_save", "penalty_save_shootout"]

const GK_THEM := Color("#f2c230")
const GK_US := Color("#2bbf6a")
const REF := Color("#141414")
const CARD_YELLOW := Color("#ffd400")
const CARD_RED := Color("#e8322b")

## VAR (Paquete 3): solo SUSPENSO visual — siempre confirma el gol, porque
## el motor ya lo contó. Que el VAR anule de verdad tocaría el balance y va
## aparte (decisión de Wilber).
## VAR de la jugada que se va a mostrar: "" | "valid" | "annulled". Lo
## setea Match con lo que YA decidió el motor (payload "var") justo antes de
## pedir los pasos. El VAR ahora es real: acá solo se dibuja.
static var var_mode: String = ""
## La atajada deja REBOTE (lo setea Match con el payload "rebound" del motor).
static var rebound_mode: bool = false

## Posiciones de arranque por kind. Claves de actor:
##  ataque:  user, m1, m2 (compañeros), d1, d2, d3 (rivales), gk (de ellos)
##  defensa: user, m1, m2 (compañeros), a1, a2 (rivales), gk (tuyo)
##  arquero: user (= tu arquero, arriba), m1, m2, a1, a2
## "ball": id del actor que la tiene o una posición.
const SETUPS := {
	"shot_on_goal": {"user": Vector2(0.42, 0.19), "d1": Vector2(0.47, 0.14), "d2": Vector2(0.30, 0.26), "d3": Vector2(0.70, 0.30), "m1": Vector2(0.65, 0.22), "m2": Vector2(0.50, 0.42), "ball": "user"},
	"one_on_one": {"user": Vector2(0.50, 0.30), "d1": Vector2(0.46, 0.42), "d2": Vector2(0.72, 0.45), "d3": Vector2(0.30, 0.55), "m1": Vector2(0.25, 0.40), "m2": Vector2(0.60, 0.60), "ball": "user"},
	"long_shot": {"user": Vector2(0.50, 0.40), "d1": Vector2(0.50, 0.31), "d2": Vector2(0.38, 0.22), "d3": Vector2(0.62, 0.20), "m1": Vector2(0.72, 0.24), "m2": Vector2(0.28, 0.30), "ball": "user"},
	"penalty_save": {"user": Vector2(0.50, 0.03), "d1": Vector2(0.50, 0.30), "ball": Vector2(0.50, 0.215)},
	"penalty_save_shootout": {"user": Vector2(0.50, 0.03), "d1": Vector2(0.50, 0.30), "ball": Vector2(0.50, 0.215)},
	"free_kick": {"user": Vector2(0.47, 0.37), "d1": Vector2(0.46, 0.25), "d2": Vector2(0.50, 0.25), "d3": Vector2(0.54, 0.25), "m1": Vector2(0.36, 0.12), "m2": Vector2(0.63, 0.12), "ball": Vector2(0.50, 0.34)},
	"volley": {"user": Vector2(0.45, 0.20), "d1": Vector2(0.51, 0.16), "d2": Vector2(0.35, 0.25), "d3": Vector2(0.84, 0.19), "m1": Vector2(0.88, 0.10), "m2": Vector2(0.60, 0.35), "ball": "m1"},
	"chip_shot": {"user": Vector2(0.50, 0.25), "d1": Vector2(0.45, 0.37), "d2": Vector2(0.70, 0.30), "d3": Vector2(0.25, 0.45), "m1": Vector2(0.30, 0.30), "m2": Vector2(0.65, 0.42), "gk": Vector2(0.50, 0.13), "ball": "user"},
	"aerial_duel": {"user": Vector2(0.50, 0.14), "d1": Vector2(0.54, 0.12), "d2": Vector2(0.38, 0.16), "d3": Vector2(0.84, 0.19), "m1": Vector2(0.90, 0.11), "m2": Vector2(0.60, 0.30), "ball": "m1"},
	"penalty": {"user": Vector2(0.50, 0.25), "m1": Vector2(0.34, 0.36), "d1": Vector2(0.62, 0.36), "ball": Vector2(0.50, 0.21)},
	"penalty_shootout": {"user": Vector2(0.50, 0.25), "ball": Vector2(0.50, 0.21)},
	"key_pass": {"user": Vector2(0.38, 0.40), "m1": Vector2(0.62, 0.17), "m2": Vector2(0.20, 0.25), "d1": Vector2(0.42, 0.33), "d2": Vector2(0.57, 0.12), "d3": Vector2(0.30, 0.15), "ball": "user"},
	"through_ball": {"user": Vector2(0.50, 0.55), "m1": Vector2(0.68, 0.42), "m2": Vector2(0.30, 0.50), "d1": Vector2(0.50, 0.47), "d2": Vector2(0.62, 0.36), "d3": Vector2(0.38, 0.36), "ball": "user"},
	"cutback": {"user": Vector2(0.86, 0.07), "m1": Vector2(0.45, 0.20), "m2": Vector2(0.60, 0.30), "d1": Vector2(0.81, 0.12), "d2": Vector2(0.55, 0.10), "d3": Vector2(0.40, 0.12), "ball": "user"},
	"cross": {"user": Vector2(0.88, 0.18), "m1": Vector2(0.50, 0.16), "m2": Vector2(0.40, 0.30), "d1": Vector2(0.83, 0.24), "d2": Vector2(0.54, 0.12), "d3": Vector2(0.42, 0.15), "ball": "user"},
	"one_two": {"user": Vector2(0.42, 0.45), "m1": Vector2(0.58, 0.36), "m2": Vector2(0.25, 0.40), "d1": Vector2(0.46, 0.38), "d2": Vector2(0.60, 0.25), "d3": Vector2(0.35, 0.28), "ball": "user"},
	"switch_play": {"user": Vector2(0.14, 0.48), "m1": Vector2(0.86, 0.38), "m2": Vector2(0.40, 0.55), "d1": Vector2(0.20, 0.42), "d2": Vector2(0.30, 0.36), "d3": Vector2(0.42, 0.40), "ball": "user"},
	"dribble": {"user": Vector2(0.60, 0.40), "d1": Vector2(0.60, 0.32), "d2": Vector2(0.45, 0.22), "d3": Vector2(0.72, 0.20), "m1": Vector2(0.30, 0.35), "m2": Vector2(0.78, 0.50), "ball": "user"},
	"counter_run": {"user": Vector2(0.50, 0.80), "d1": Vector2(0.55, 0.62), "d2": Vector2(0.35, 0.50), "d3": Vector2(0.62, 0.45), "m1": Vector2(0.25, 0.72), "m2": Vector2(0.78, 0.70), "ball": "user"},
	"pressing": {"a1": Vector2(0.50, 0.62), "user": Vector2(0.50, 0.53), "a2": Vector2(0.75, 0.55), "m1": Vector2(0.30, 0.50), "m2": Vector2(0.60, 0.35), "ball": "a1"},
	"tackle": {"a1": Vector2(0.40, 0.40), "user": Vector2(0.45, 0.32), "a2": Vector2(0.65, 0.30), "m1": Vector2(0.60, 0.22), "m2": Vector2(0.30, 0.25), "ball": "a1"},
	"interception": {"a1": Vector2(0.28, 0.52), "a2": Vector2(0.62, 0.30), "user": Vector2(0.47, 0.40), "m1": Vector2(0.70, 0.22), "m2": Vector2(0.35, 0.25), "ball": "a1"},
	"clearance": {"user": Vector2(0.50, 0.19), "a1": Vector2(0.57, 0.15), "a2": Vector2(0.40, 0.20), "m1": Vector2(0.65, 0.10), "m2": Vector2(0.35, 0.12), "ball": Vector2(0.50, 0.11)},
	"last_ditch_tackle": {"a1": Vector2(0.52, 0.30), "user": Vector2(0.42, 0.38), "a2": Vector2(0.30, 0.40), "m1": Vector2(0.70, 0.35), "m2": Vector2(0.60, 0.50), "ball": "a1"},
	"recovery_tackle": {"a1": Vector2(0.50, 0.55), "user": Vector2(0.50, 0.64), "a2": Vector2(0.70, 0.45), "m1": Vector2(0.35, 0.40), "m2": Vector2(0.60, 0.30), "ball": "a1"},
	"block_shot": {"a1": Vector2(0.50, 0.25), "user": Vector2(0.50, 0.17), "a2": Vector2(0.65, 0.16), "m1": Vector2(0.38, 0.15), "m2": Vector2(0.60, 0.10), "ball": "a1"},
	"one_on_one_save": {"user": Vector2(0.50, 0.03), "a1": Vector2(0.50, 0.32), "a2": Vector2(0.70, 0.40), "m1": Vector2(0.42, 0.42), "m2": Vector2(0.30, 0.35), "ball": "a1"},
	"sweep_keeper": {"user": Vector2(0.50, 0.03), "a1": Vector2(0.62, 0.45), "a2": Vector2(0.40, 0.60), "m1": Vector2(0.55, 0.36), "m2": Vector2(0.30, 0.40), "ball": "a2"},
	"distribution": {"user": Vector2(0.50, 0.05), "m1": Vector2(0.18, 0.35), "m2": Vector2(0.75, 0.45), "a1": Vector2(0.40, 0.30), "a2": Vector2(0.65, 0.35), "ball": "user"},
}

## Apellido en mayúsculas para la ficha (como la captura de referencia).
static func short_name(full: String) -> String:
	var parts: PackedStringArray = full.strip_edges().split(" ", false)
	if parts.is_empty():
		return ""
	return parts[parts.size() - 1].to_upper().left(12)

static func is_attack(kind: String) -> bool:
	return kind in SHOT or kind in PASS or kind in DRIBBLE

static func _rng(ctx: Dictionary, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = absi(int(ctx.get("seed", 0)) ^ hash(salt))
	return r

## Como _rng pero mezclando semilla y texto en UNA sola cadena: con el XOR
## de _rng dos escenas parecidas ("card:A" con semilla 100 y "card:B" con
## 101) podían caer en la misma semilla y salir idénticas.
static func _rng_mix(ctx: Dictionary, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = absi(hash("%d|%s" % [int(ctx.get("seed", 0)), salt]))
	return r

static func _person(ctx: Dictionary, key: String, idx: int) -> Dictionary:
	var arr: Array = ctx.get(key, [])
	if arr.is_empty():
		return {"num": "", "name": ""}
	return arr[idx % arr.size()]

## El jugador de ese nombre (con su cara y su número) si está en el plantel
## de la cancha; si no, uno "sin cara" con el nombre.
static func _person_named(ctx: Dictionary, key: String, full_name: String) -> Dictionary:
	var sn: String = short_name(full_name)
	for p in (ctx.get(key, []) as Array):
		if String((p as Dictionary).get("name", "")) == sn:
			return p
	return {"num": "", "name": sn}

## Uno cualquiera del plantel, distinto de `not_name`.
static func _person_other(ctx: Dictionary, key: String, rng: RandomNumberGenerator, not_name: String) -> Dictionary:
	var arr: Array = ctx.get(key, [])
	if arr.is_empty():
		return {"num": "", "name": ""}
	var start: int = rng.randi() % arr.size()
	for k in range(arr.size()):
		var p: Dictionary = arr[(start + k) % arr.size()]
		if String(p.get("name", "")) != not_name:
			return p
	return arr[start]

## ¿Esta jugada va espejada (por la otra banda)? Sale de la semilla de la
## jugada y NO del tipo de acción: el menú, la acción que elegís y el final
## tienen que coincidir. Pelota parada y arquero no se espejan.
static func mirror_for(kind: String, ctx: Dictionary) -> bool:
	if kind in ["penalty", "penalty_shootout", "free_kick"] or kind in KEEPER:
		return false
	return _rng_mix(ctx, "mirror").randf() < 0.5

## Escena de arranque para un momento clave de `kind`.
static func scene_for(kind: String, ctx: Dictionary) -> Dictionary:
	var base: Dictionary = SETUPS.get(kind, SETUPS["shot_on_goal"])
	var rng := _rng(ctx, "setup:" + kind)
	# LA JUGADA SIGUE DONDE QUEDASTE (11-oct, bug reportado por Wilber:
	# "después de encarar quedo en un lugar y la siguiente acción me coloca
	# en el mismo lugar de siempre"). Si venís de otra acción de la misma
	# jugada, toda la escena se corre para que arranques donde terminaste
	# (el costado exacto; la altura, lo más cerca que la jugada permite: un
	# remate no puede arrancar en mitad de cancha).
	var zone0: Array = ZONES.get(kind, [not is_attack(kind), 1.0])
	var mirror: bool = mirror_for(kind, ctx)
	var shift := Vector2.ZERO
	if ctx.has("user_at_world") and base.has("user") and not (kind in ["penalty", "penalty_shootout", "free_kick"]) and not (kind in KEEPER):
		var w: Vector2 = ctx["user_at_world"]
		var want: Vector2 = Vector2(1.0 - w.x, (2.0 - w.y) / float(zone0[1])) if bool(zone0[0]) else Vector2(w.x, w.y / float(zone0[1]))
		if mirror:
			want.x = 1.0 - want.x
		var bu: Vector2 = base["user"]
		shift = Vector2(clampf(want.x, 0.12, 0.88) - bu.x, clampf(want.y - bu.y, -0.10, 0.12))
	var us: Color = ctx.get("us", Color.WHITE)
	var them: Color = ctx.get("them", Color.BLACK)
	var actors: Array = []
	var user: Dictionary = ctx.get("user", {})
	for id in base:
		if id == "ball" or id == "gk":
			continue   # el arquero se agrega aparte, abajo
		var pos: Vector2 = base[id]
		# Un poco de variación para que dos tiros seguidos no se vean
		# idénticos (menos al que patea un penal / tiro libre).
		if not (kind in ["penalty", "penalty_shootout", "free_kick"]) and id != "user":
			pos += Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.02, 0.02))
		if shift != Vector2.ZERO:
			# Vos quedás exacto; los demás acompañan sin salirse de la cancha.
			pos = pos + shift if id == "user" else Vector2(clampf(pos.x + shift.x, 0.05, 0.95), clampf(pos.y + shift.y, 0.05, 0.98))
		var a: Dictionary = {"id": id, "pos": pos}
		if id == "user":
			var keeper: bool = kind in KEEPER
			a.merge({"color": GK_US if keeper else us, "num": user.get("num", ""), "name": user.get("name", ""), "look": user.get("look", {}), "gk": keeper, "user": true})
		elif id.begins_with("m"):
			a.merge({"color": us}.merged(_person(ctx, "mates", int(id.substr(1)) - 1)))
		else:
			a.merge({"color": them}.merged(_person(ctx, "rivals", int(id.substr(1)) - 1)))
		actors.append(a)
	# Arquero de arriba: el de ellos si atacás, el tuyo si defendés (salvo
	# que vos SEAS el arquero).
	if not (kind in KEEPER):
		var gk_pos: Vector2 = base.get("gk", Vector2(0.5, 0.025))
		if is_attack(kind):
			actors.append({"id": "gk", "pos": gk_pos, "color": GK_THEM}.merged(ctx.get("their_gk", {})))
		else:
			actors.append({"id": "gk", "pos": gk_pos, "color": GK_US}.merged(ctx.get("our_gk", {})))
	var zone: Array = zone0
	var ball0 = base.get("ball", "user")
	if ball0 is Vector2 and shift != Vector2.ZERO:
		ball0 = (ball0 as Vector2) + shift
	return {"actors": actors, "ball": ball0, "flip": bool(zone[0]), "stretch": float(zone[1]), "mirror": mirror}

## ZONA DE CADA JUGADA en la cancha completa (10-oct, Wilber: "seccionar
## los minijuegos y que no todo pase en el mismo pedazo de cancha").
## [en tu mitad (contra tu arco), estirado]. Sin entrada: ataque = arriba,
## defensa/arquero = tu área. Estirado > 1 aleja la jugada del arco: el
## armado arranca en el medio, la presión se hace lejos de tu arco.
const ZONES := {
	"key_pass": [false, 1.25], "one_two": [false, 1.45], "dribble": [false, 1.3],
	"through_ball": [false, 1.55], "switch_play": [false, 1.6], "counter_run": [false, 1.5],
	"long_shot": [false, 1.1],
	"pressing": [true, 1.75], "recovery_tackle": [true, 1.35], "interception": [true, 1.45],
	"tackle": [true, 1.2], "sweep_keeper": [true, 1.1],
}

# --- Finales --------------------------------------------------------------

static func _pos(scene: Dictionary, id: String) -> Vector2:
	for a in scene["actors"]:
		if a["id"] == id:
			return a["pos"]
	return Vector2(0.5, 0.5)

static func _has(scene: Dictionary, id: String) -> bool:
	for a in scene["actors"]:
		if a["id"] == id:
			return true
	return false

## Punto de la red donde entra (side -1 = palo izquierdo, 0 = medio,
## 1 = derecho).
static func _goal_point(side: float) -> Vector2:
	return Vector2(0.5 + side * PitchView.GOAL_W * 0.39, -0.034)   # 11-oct: hasta el fondo de la red (era -0.012)

## Cuántos goles pegados al palo se ven "palo y adentro" / "al ángulo", y
## cuántos remates errados cerca del palo se ven "en el palo".
const GOAL_POST_IN_SHARE := 0.16
const GOAL_TOP_CORNER_SHARE := 0.30
const MISS_POST_SHARE := 0.30

## El palo de ese lado (sobre la línea de gol).
static func post_point(sgn: float) -> Vector2:
	return Vector2(0.5 + sgn * PitchView.GOAL_W * 0.5, 0.002)

## side: -1/0/1 para forzar el lado (la zona que elegiste), 2 = al azar.
static func _goal_steps(shooter: String, rng: RandomNumberGenerator, keeper: String, scene: Dictionary, arc: float, ours: bool, side: float = 2.0, allow_var: bool = true) -> Array:
	if side > 1.5:
		side = -1.0 if rng.randf() < 0.5 else 1.0
	var gk_at: Vector2 = _pos(scene, keeper) if _has(scene, keeper) else Vector2(0.5, 0.025)
	var moves := {}
	if keeper != "" and _has(scene, keeper):
		# El arquero se tira para el otro lado (o al azar si fue al medio).
		var dive: float = -side if side != 0.0 else (-1.0 if rng.randf() < 0.5 else 1.0)
		moves[keeper] = Vector2(0.5 + dive * PitchView.GOAL_W * 0.46, gk_at.y)
	# GOLES CON HISTORIA (11-oct, Wilber: "goles al ángulo o que peguen en
	# el palo y entren"). Solo cambia CÓMO se ve el gol que el motor ya
	# decidió. Con puntería tuya, el palo y el ángulo solo salen si apuntaste
	# cerca del palo.
	var near_post: bool = absf(side) >= 0.8
	var roll: float = rng.randf()
	var gol_txt: String = "¡GOL!" if ours else "GOL"
	var gol_col: Color = Styles.GOLD if ours else Styles.RED
	var sgn: float = 1.0 if side >= 0.0 else -1.0
	var out: Array = []
	# Con altura elegida por vos manda eso: arriba y al palo = ÁNGULO
	# siempre; abajo y al palo = esquina inferior.
	var low_corner: bool = false
	if shot_level == "high" and near_post:
		roll = GOAL_POST_IN_SHARE + 0.001          # → rama del ángulo
	elif shot_level == "low" and near_post and roll >= GOAL_POST_IN_SHARE:
		low_corner = true
	elif shot_level == "high":
		gol_txt = "¡GOL! ARRIBA" if ours else "GOL"
	if low_corner:
		out = [
			{"t": 0.42, "ball": Vector2(0.5 + sgn * PitchView.GOAL_W * 0.44, -0.034), "arc": 0.1, "moves": moves},
			{"t": 0.95, "flash": "¡GOL! ABAJO, AL PALO" if ours else "GOL", "flash_color": gol_col, "anim": {shooter: "festejo"}},
		]
	elif near_post and roll < GOAL_POST_IN_SHARE:
		# Pega en el palo y se mete.
		out = [
			{"t": 0.45, "ball": post_point(sgn), "arc": arc, "moves": moves},
			{"t": 0.20, "ball": Vector2(0.5 + sgn * PitchView.GOAL_W * 0.22, -0.034), "arc": 0.0},
			{"t": 0.95, "flash": "¡PALO Y GOL!" if ours else "PALO Y GOL", "flash_color": gol_col, "anim": {shooter: "festejo"}},
		]
	elif near_post and roll < GOAL_POST_IN_SHARE + GOAL_TOP_CORNER_SHARE:
		# Al ángulo: alta y pegada al palo, imposible para el arquero.
		out = [
			{"t": 0.50, "ball": Vector2(0.5 + sgn * PitchView.GOAL_W * 0.44, -0.034), "arc": arc + 1.1, "curve": 0.02 * sgn, "moves": moves},
			{"t": 0.95, "flash": "¡GOL AL ÁNGULO!" if ours else "GOL AL ÁNGULO", "flash_color": gol_col, "anim": {shooter: "festejo"}},
		]
	else:
		out = [
			{"t": 0.45, "ball": _goal_point(side), "arc": arc, "moves": moves},
			{"t": 0.95, "flash": gol_txt, "flash_color": gol_col, "anim": {shooter: "festejo"}},
		]
	if allow_var and var_mode != "":
		# BUG (11-oct, Wilber: "los fuera de juego se miden mal"): la línea
		# del VAR se dibujaba EN LOS PIES DEL QUE REMATÓ, estuviera donde
		# estuviera — no medía nada. Ahora va donde corresponde: en el
		# último defensor. Y el veredicto tiene que coincidir con lo que se
		# ve: si el goleador NO está más allá de esa línea, el gol no se
		# puede anular por adelantado (se anula por falta previa, sin línea).
		var sy: float = _pos(scene, shooter).y if _has(scene, shooter) else 0.2
		var dline: float = 9.0
		for did in ["d1", "d2", "d3"]:
			if _has(scene, did):
				dline = minf(dline, _pos(scene, did).y)
		var beyond: bool = dline < 8.0 and sy < dline - 0.012
		if var_mode == "annulled":
			if beyond:
				out.append({"t": 0.3, "flash": "REVISIÓN VAR", "flash_color": Color(0.35, 0.9, 1.0), "line": dline})
				out.append({"t": 1.4})
				# El juez de línea levanta el banderín: posición adelantada.
				out.append({"t": 0.9, "flash": "FUERA DE JUEGO · GOL ANULADO", "flash_color": Styles.RED, "flag": true})
				out.append({"t": 0.5, "line": -9.0, "flag": false})
			else:
				out.append({"t": 0.3, "flash": "REVISIÓN VAR", "flash_color": Color(0.35, 0.9, 1.0)})
				out.append({"t": 1.4})
				out.append({"t": 0.9, "flash": "FALTA PREVIA · GOL ANULADO", "flash_color": Styles.RED})
		else:
			if dline < 8.0 and not beyond:
				out.append({"t": 0.3, "flash": "REVISIÓN VAR", "flash_color": Color(0.35, 0.9, 1.0), "line": dline})
			else:
				out.append({"t": 0.3, "flash": "REVISIÓN VAR", "flash_color": Color(0.35, 0.9, 1.0)})
			out.append({"t": 1.4})
			out.append({"t": 0.7, "flash": "✔ GOL VÁLIDO", "flash_color": Styles.GREEN, "line": -9.0})
	return out

static func _miss_steps(rng: RandomNumberGenerator, keeper: String, scene: Dictionary, arc: float, saved_text: String = "¡ATAJADA!", side: float = 2.0, high: bool = false) -> Array:
	if side > 1.5:
		# Sin puntería conocida (jugada de la IA): a un palo, y a veces afuera.
		side = (-1.0 if rng.randf() < 0.5 else 1.0) * (1.0 if rng.randf() < 0.55 else 1.4)
	if high and rng.randf() < 0.5:
		return [
			{"t": 0.5, "ball": Vector2(0.5 + side * PitchView.GOAL_W * 0.37, -0.07), "arc": arc + 1.0},
			{"t": 0.6, "flash": "¡POR ENCIMA!", "flash_color": Color.WHITE},
		]
	# BUG (11-oct, Wilber: "el balón va al arco pero me sale que va afuera").
	# Causa: el punto de "afuera" se calculaba como lado × (medio arco + un
	# poco). Con `side` chico (apuntaste hacia adentro) ese punto caía
	# DENTRO del arco: la pelota entraba y el cartel decía ¡AFUERA!. Ahora:
	#  - si apuntaste ADENTRO del arco (|side| <= 1.25) y no entró, lo que
	#    se ve es una ATAJADA — nunca "afuera";
	#  - "afuera" pasa siempre por FUERA del palo, del lado al que fue.
	var aimed_in: bool = absf(side) <= 1.25
	var can_save: bool = keeper != "" and _has(scene, keeper)
	# EN EL PALO: si fue cerca del palo (por adentro o por afuera), a veces
	# revienta el poste y sale.
	if not high and absf(side) >= 0.85 and rng.randf() < MISS_POST_SHARE:
		var ps: float = 1.0 if side >= 0.0 else -1.0
		# Acá la jugada TERMINA: el rebote le queda a un rival, que la saca.
		var spot := Vector2(0.5 + ps * 0.10, 0.13)
		# Los que DEFIENDEN ese arco: d1-d3 en tus jugadas; m1-m2 en las de otros.
		var clr: String = _closest(scene, spot, ["d1", "d2", "d3"] if _has(scene, "d1") else ["m1", "m2"])
		var post_steps: Array = [
			{"t": 0.45, "ball": post_point(ps), "arc": arc},
			{"t": 0.32, "ball": spot, "arc": 0.7},
		]
		if _has(scene, clr):
			post_steps.append({"t": 0.35, "moves": {clr: spot + Vector2(0, 0.012)}})
			post_steps.append({"t": 0.45, "ball": Vector2(0.5 + ps * 0.42, 0.62), "arc": 2.0})
			post_steps.append({"t": 0.6, "flash": "¡EN EL PALO! La despeja el rival", "flash_color": Color.WHITE})
		else:
			post_steps.append({"t": 0.6, "flash": "¡EN EL PALO!", "flash_color": Color.WHITE})
		return post_steps
	if can_save and (aimed_in or high or rng.randf() < 0.55):
		var at := Vector2(0.5 + clampf(side, -1.25, 1.25) * PitchView.GOAL_W * 0.33, _pos(scene, keeper).y + 0.005)
		return [
			{"t": 0.45, "ball": at, "arc": arc, "moves": {keeper: at - Vector2(0, 0.01)}},
			{"t": 0.6, "flash": saved_text, "flash_color": Color.WHITE},
		]
	var sgn: float = 1.0 if side >= 0.0 else -1.0
	return [
		{"t": 0.5, "ball": Vector2(0.5 + sgn * (PitchView.GOAL_W * 0.5 + 0.07), -0.04), "arc": arc},
		{"t": 0.6, "flash": "¡AFUERA!", "flash_color": Color.WHITE},
	]

## Pasos de cómo termina TU acción `kind`, dado el resultado del motor.
## `goal` = hubo gol en esa jugada (a favor si success, en contra si no).
## Altura del remate del usuario en la jugada que se está armando ("" = no
## se sabe: jugadas de la IA).
static var shot_level: String = ""
## Golpe elegido ("colocado" | "potente" | "comba" | ""), para dibujarlo.
static var shot_strike: String = ""

## El paso en que la pelota va al arco, según el golpe: con comba dobla
## hacia el palo; potente sale más rápido y recto.
static func _strike_look(step: Dictionary, side: float) -> Dictionary:
	# `side` = hacia qué palo va. La comba es el lado hacia el que se ABRE la
	# trayectoria: hacia adentro se abre por afuera del palo y vuelve; hacia
	# afuera sale por el medio (al arquero) y se va al palo.
	var sgn: float = 1.0 if side >= 0.0 else -1.0
	if shot_strike == "comba":
		step["curve"] = 0.06 * sgn    # se abre por AFUERA del palo y vuelve
		step["t"] = float(step.get("t", 0.45)) + 0.08
	elif shot_strike == "comba_fuera":
		step["curve"] = -0.07 * sgn   # sale por el MEDIO y se va al palo
		step["t"] = float(step.get("t", 0.45)) + 0.05
	elif shot_strike == "potente":
		step["curve"] = 0.0
		step["t"] = maxf(0.30, float(step.get("t", 0.45)) - 0.10)
	return step

static func outcome_for(kind: String, success: bool, goal: bool, ctx: Dictionary) -> Array:
	shot_level = ""
	shot_strike = String(ctx.get("strike", ""))
	var raw: Array = _outcome_raw(kind, success, goal, ctx)
	shot_level = ""
	# El golpe se ve en el paso en que la pelota llega al arco.
	if shot_strike != "":
		for i in range(raw.size()):
			var st: Dictionary = raw[i]
			if st.get("ball", null) is Vector2 and (st["ball"] as Vector2).y < 0.06 and not st.has("curve"):
				raw[i] = _strike_look(st.duplicate(), (st["ball"] as Vector2).x - 0.5)
				break
	shot_strike = ""
	return _with_action_anims(kind, success, goal, raw)

## ANIMACIONES DE ACCIÓN (10-oct, Wilber: "creemos animaciones como tacles y
## cosas así"): le pone a cada jugada su gesto — cabezazo, volea, regate,
## entrada de pie, cuerpeo, chilena. Solo agrega "anim" a pasos que
## ya existen; si falta el arte de alguna, PitchView la ignora.
static func _add_anim(step: Dictionary, id: String, anim: String) -> Dictionary:
	var st: Dictionary = step.duplicate()
	var an: Dictionary = (st.get("anim", {}) as Dictionary).duplicate()
	if not an.has(id):
		an[id] = anim
	st["anim"] = an
	return st

static func _with_action_anims(kind: String, success: bool, goal: bool, steps: Array) -> Array:
	var out: Array = steps.duplicate()
	if kind in ["volley", "aerial_duel"]:
		# El primer vuelo es el centro; el segundo, tu remate.
		var seen: int = 0
		for i in range(out.size()):
			if (out[i] as Dictionary).has("ball"):
				seen += 1
				if seen == 2:
					# Una volea que termina en gol es de CHILENA.
					out[i] = _add_anim(out[i], "user", "cabezazo" if kind == "aerial_duel" else ("chilena" if success and goal else "volea"))
					break
	elif kind in DRIBBLE and success:
		for i in range(out.size()):
			if String((out[i] as Dictionary).get("dribble", "")) == "user":
				out[i] = _add_anim(out[i], "user", "regate")
				break
	elif kind in DEFEND and success and kind in ["tackle", "interception", "pressing", "block_shot"]:
		for i in range(out.size()):
			var b = (out[i] as Dictionary).get("ball", null)
			if b is String and b == "user":
				out[i] = _add_anim(out[i], "user", "cuerpeo" if kind == "pressing" else "entrada")
				break
	return out

static func _outcome_raw(kind: String, success: bool, goal: bool, ctx: Dictionary) -> Array:
	var scene := scene_for(kind, ctx)
	# OPORTUNIDAD EN VIVO: el final arranca desde donde quedó cada uno.
	if ctx.has("live_pos"):
		var lp: Dictionary = ctx["live_pos"]
		for a in scene["actors"]:
			if lp.has(String(a["id"])):
				a["pos"] = lp[String(a["id"])]
	var rng := _rng(ctx, "out:%s:%s:%s" % [kind, success, goal])
	var steps: Array = []
	var up := Vector2(0, -1)

	if kind in ["penalty_save", "penalty_save_shootout"]:
		# Vos en el arco: patea el rival; te tirás al lado que elegiste.
		var aimz: int = int(ctx.get("aim_zone", 1))
		var dive: float = float(aimz % 3 - 1)
		var shot_side: float = dive if success else (-dive if dive != 0.0 else (-1.0 if rng.randf() < 0.5 else 1.0))
		steps.append({"t": 0.45, "moves": {"d1": Vector2(0.5, 0.235)}})
		var at := Vector2(0.5 + shot_side * PitchView.GOAL_W * 0.33, 0.03)
		if success:
			steps.append({"t": 0.45, "ball": at, "arc": 0.5, "moves": {"user": at}})
			steps.append({"t": 0.4, "ball": at + Vector2(shot_side * 0.12, 0.12), "arc": 0.4})
			steps.append({"t": 0.7, "flash": "¡ATAJASTE!", "flash_color": Styles.GOLD})
		else:
			steps.append({"t": 0.45, "ball": Vector2(0.5 + shot_side * PitchView.GOAL_W * 0.4, -0.02), "arc": 0.5,
				"moves": {"user": Vector2(0.5 + dive * PitchView.GOAL_W * 0.4, 0.03)}})
			steps.append({"t": 0.7, "flash": "GOL", "flash_color": Styles.RED})
		return steps

	if kind in SHOT:
		var arc: float = 0.6
		if kind in ["volley", "aerial_duel"]:
			# Primero el centro del compañero.
			steps.append({"t": 0.6, "ball": "user", "arc": 2.4})
		if kind == "free_kick":
			steps.append({"t": 0.25, "moves": {"user": Vector2(0.495, 0.35)}})
			arc = 1.8
		elif kind == "chip_shot":
			arc = 2.6
		elif kind in ["penalty", "penalty_shootout"]:
			steps.append({"t": 0.3, "moves": {"user": Vector2(0.5, 0.225)}})
		else:
			steps.append({"t": 0.25, "dribble": "user", "moves": {"user": _pos(scene, "user") + up * 0.03}})
		# La zona que elegiste en el minijuego de apuntar (ctx["aim_zone"]):
		# penal 0..8 (fila*3+columna, fila 0 = arriba) o 9 = Panenka; el
		# resto de remates 0/1/2 = izquierda/medio/derecha.
		var aim: int = int(ctx.get("aim_zone", -1))
		var side: float = 2.0
		var high: bool = false
		if kind in ["penalty", "penalty_shootout"] and aim == 9:
			side = 0.0
			arc = 2.2
		elif kind in ["penalty", "penalty_shootout"] and aim >= 0 and aim <= 8:
			side = float(aim % 3 - 1)
			var row: int = floori(aim / 3.0)
			arc = [1.3, 0.7, 0.25][row]
			high = row == 0
		elif aim >= 0 and aim <= 2:
			side = float(aim - 1)
		# Remate en la cancha (minijuego interactivo): punto EXACTO apuntado.
		if ctx.has("aim_x"):
			side = clampf((float(ctx["aim_x"]) - 0.5) / (PitchView.GOAL_W * 0.39), -1.6, 1.6)
			high = bool(ctx.get("shot_high", false))
		# ALTURA QUE ELEGISTE con la fuerza (11-oct, Wilber: "si apunto a la
		# esquina inferior que el balón vaya allá, y si apunto al ángulo y le
		# pongo la fuerza necesaria, también"): "low" = rasante, "high" = arriba.
		shot_level = String(ctx.get("shot_level", ""))
		if not (kind in ["free_kick", "chip_shot", "penalty", "penalty_shootout", "volley", "aerial_duel"]):
			if shot_level == "low":
				arc = 0.12
			elif shot_level == "high":
				arc = 1.9
		if goal and success:
			steps.append_array(_goal_steps("user", rng, "gk", scene, arc, true, side, not (kind in ["penalty", "penalty_shootout"])))
		elif success:
			# Remate bueno sin gol: el arquero la manda al córner.
			var gk := _pos(scene, "gk")
			# EL PALO Y LA SEGUNDA JUGADA (11-oct, Wilber: "cuando pega en el
			# palo, si la agarra un rival termina la jugada; si la agarra uno
			# de mis compañeros ya sería otra cosa"). El motor ya decidió si la
			# pelota queda viva para tu equipo (`rebound_mode`); acá se ve: si
			# fue cerca del palo, lo que te la deja viva puede ser el POSTE.
			if rebound_mode and absf(side) >= 0.8 and absf(side) <= 1.6 and rng.randf() < 0.55:
				var ps: float = 1.0 if side >= 0.0 else -1.0
				steps.append({"t": 0.45, "ball": post_point(ps), "arc": arc})
				steps.append({"t": 0.38, "ball": Vector2(0.5 + ps * 0.05, 0.15), "arc": 0.9})
				steps.append({"t": 0.5, "flash": "¡EN EL PALO! ¡SIGUE LA JUGADA!", "flash_color": Styles.GOLD})
				return steps
			steps.append({"t": 0.42, "ball": gk + Vector2(0.03, 0.0), "arc": arc, "moves": {"gk": gk + Vector2(0.03, 0.0)}})
			if rebound_mode:
				# El arquero la rechaza corta: queda viva en el área.
				steps.append({"t": 0.4, "ball": Vector2(0.5 + (0.09 if rng.randf() < 0.5 else -0.09), 0.15), "arc": 1.1})
				steps.append({"t": 0.5, "flash": "¡REBOTE!", "flash_color": Styles.GOLD})
				return steps
			steps.append({"t": 0.45, "ball": Vector2(0.97, -0.01), "arc": 0.8})
			steps.append({"t": 0.5, "flash": "¡AL CÓRNER!", "flash_color": Color.WHITE})
		else:
			steps.append_array(_miss_steps(rng, "gk", scene, arc, "¡ATAJADA!", side, high))
		return steps

	if kind in PASS:
		# El compañero que TOCASTE en el minijuego de pase (si hubo).
		var receiver: String = String(ctx.get("pass_to", "m1"))
		if not _has(scene, receiver):
			receiver = "m1"
		var recv_to: Vector2 = _pos(scene, receiver)
		if ctx.has("pass_point"):
			recv_to = ctx["pass_point"]   # pase al espacio que elegiste arrastrando
		elif kind == "through_ball":
			recv_to = Vector2(0.62, 0.22)
		elif kind in ["cross", "cutback"]:
			recv_to = _pos(scene, receiver) + up * 0.02
		var arc: float = 2.2 if kind in ["cross", "switch_play"] else 0.3
		if success:
			if kind == "one_two":
				var run_to := Vector2(0.50, 0.24)
				steps.append({"t": 0.35, "ball": "m1"})
				steps.append({"t": 0.45, "moves": {"user": run_to}})
				steps.append({"t": 0.35, "ball": run_to + Vector2(0, -0.035)})
				receiver = "user"
			else:
				steps.append({"t": 0.55, "ball": receiver, "arc": arc, "moves": {receiver: recv_to}})
			if goal:
				steps.append_array(_goal_steps(receiver, rng, "gk", scene, 0.6, true))
			else:
				steps.append({"t": 0.4, "flash": "¡PASE!", "flash_color": Styles.GREEN})
		elif bool(ctx.get("force_offside", false)) or (not ctx.has("live_pos") and kind in ["through_ball", "one_two"] and not ctx.has("pass_point") and rng.randf() < 0.45):
			# FUERA DE JUEGO: el compañero picó antes de tiempo. El juez de
			# línea levanta el banderín y se marca la línea del último
			# defensor. (Solo cambia CÓMO se ve el fallo: el resultado ya lo
			# decidió el motor.)
			var last_def: float = 1.0
			for did in ["d1", "d2", "d3"]:
				if _has(scene, did):
					last_def = minf(last_def, _pos(scene, did).y)
			var off_to := Vector2(_pos(scene, receiver).x, last_def - 0.07)
			steps.append({"t": 0.3, "moves": {receiver: off_to}})
			steps.append({"t": 0.45, "ball": off_to + Vector2(0, -0.035), "arc": arc})
			steps.append({"t": 0.9, "flash": "¡FUERA DE JUEGO!", "flash_color": Color(1.0, 0.85, 0.3), "line": "auto:" + receiver, "flag": true})
			steps.append({"t": 0.4, "line": -9.0, "flag": false})
		else:
			# Interceptado: el rival más cerca del medio del pase se cruza.
			var mid: Vector2 = (_pos(scene, "user") + recv_to) * 0.5
			var cutter: String = _closest(scene, mid, ["d1", "d2", "d3"])
			steps.append({"t": 0.5, "ball": mid, "arc": arc * 0.5, "moves": {cutter: mid + Vector2(0, 0.03), receiver: recv_to}})
			steps.append({"t": 0.45, "flash": "CORTADO", "flash_color": Color.WHITE})
		return steps

	if kind in DRIBBLE:
		var u: Vector2 = _pos(scene, "user")
		var d: Vector2 = _pos(scene, "d1")
		if success:
			var side: float = 1.0 if u.x < 0.75 else -1.0
			steps.append({"t": 0.35, "dribble": "user", "moves": {"user": d + Vector2(side * 0.08, 0.03), "d1": u + Vector2(0, -0.02)}})
			var past: Vector2 = d + Vector2(side * 0.04, -0.12)
			if kind == "counter_run":
				past = Vector2(0.5, 0.28)
			steps.append({"t": 0.45, "dribble": "user", "moves": {"user": past}})
			if goal:
				steps.append_array(_goal_steps("user", rng, "gk", scene, 0.6, true))
			else:
				steps.append({"t": 0.4, "flash": "¡LO PASASTE!", "flash_color": Styles.GREEN})
		else:
			steps.append({"t": 0.35, "dribble": "user", "moves": {"user": d + Vector2(0, 0.04)}})
			steps.append({"t": 0.25, "ball": "d1", "moves": {"d1": d + Vector2(0.01, 0.03)}})
			steps.append({"t": 0.4, "dribble": "d1", "moves": {"d1": d + Vector2(-0.05, 0.16)}})
			steps.append({"t": 0.4, "flash": "TE LA QUITARON", "flash_color": Color.WHITE})
		return steps

	if kind in DEFEND:
		var carrier: String = "a1"
		var a: Vector2 = _pos(scene, "a1")
		match kind:
			"interception":
				var to: Vector2 = _pos(scene, "a2")
				var mid: Vector2 = (a + to) * 0.5
				if success:
					steps.append({"t": 0.45, "ball": mid, "moves": {"user": mid + Vector2(0, 0.02)}})
					steps.append({"t": 0.4, "dribble": "user", "moves": {"user": mid + Vector2(0.02, 0.14)}})
					steps.append({"t": 0.35, "flash": "¡ANTICIPASTE!", "flash_color": Styles.GREEN})
					return steps
				steps.append({"t": 0.5, "ball": "a2", "moves": {"user": mid + Vector2(0.03, 0.03)}})
				carrier = "a2"
				a = to
			"clearance":
				var b := Vector2(0.50, 0.11)
				if success:
					steps.append({"t": 0.3, "moves": {"user": b + Vector2(0, 0.03), "a1": b + Vector2(0.04, 0.02)}})
					steps.append({"t": 0.7, "ball": Vector2(0.18, 0.95), "arc": 3.0})
					steps.append({"t": 0.35, "flash": "¡DESPEJADA!", "flash_color": Styles.GREEN})
					return steps
				steps.append({"t": 0.35, "ball": "a1", "moves": {"a1": b + Vector2(0.01, 0.03), "user": b + Vector2(-0.04, 0.05)}})
				a = b + Vector2(0.01, 0.03)
			"block_shot":
				if success:
					var hit: Vector2 = _pos(scene, "user") + Vector2(0, 0.025)
					steps.append({"t": 0.25, "ball": hit, "arc": 0.3})
					steps.append({"t": 0.4, "ball": Vector2(0.86, -0.02), "arc": 1.2})
					steps.append({"t": 0.35, "flash": "¡BLOQUEADO!", "flash_color": Styles.GREEN})
					return steps
				steps.append({"t": 0.2, "moves": {"user": _pos(scene, "user") + Vector2(0.05, 0.01)}})
			_:
				# Quite / presión / cruce: llegás o te gambetean.
				if success:
					steps.append({"t": 0.4, "moves": {"user": a + Vector2(0, -0.02), "a1": a + Vector2(0.03, 0.03)}})
					steps.append({"t": 0.2, "ball": "user"})
					steps.append({"t": 0.4, "dribble": "user", "moves": {"user": a + Vector2(-0.02, 0.14)}})
					steps.append({"t": 0.35, "flash": "¡RECUPERADA!", "flash_color": Styles.GREEN})
					return steps
				var past := a + Vector2(0.08, -0.13)
				steps.append({"t": 0.45, "dribble": "a1", "moves": {"a1": past, "user": a + Vector2(-0.02, 0.0)}})
				a = past
		# Falló la acción: si fue gol, el rival define; si no, se pierde la jugada.
		if goal:
			steps.append_array(_goal_steps(carrier, rng, "gk", scene, 0.5, false))
		else:
			steps.append_array(_miss_steps(rng, "gk", scene, 0.5, "ATAJÓ TU ARQUERO"))
		return steps

	if kind in KEEPER:
		var a1: Vector2 = _pos(scene, "a1")
		match kind:
			"distribution":
				var to: Vector2 = _pos(scene, "m1")
				if success:
					steps.append({"t": 0.6, "ball": "m1", "arc": 2.0})
					steps.append({"t": 0.35, "flash": "¡BIEN SACADO!", "flash_color": Styles.GREEN})
				else:
					var mid: Vector2 = (_pos(scene, "user") + to) * 0.5
					steps.append({"t": 0.55, "ball": mid, "arc": 1.4, "moves": {"a1": mid + Vector2(0, 0.03)}})
					steps.append({"t": 0.35, "flash": "CORTADO", "flash_color": Color.WHITE})
				return steps
			"sweep_keeper":
				var spot := Vector2(0.53, 0.19)
				if success:
					steps.append({"t": 0.5, "ball": spot, "moves": {"a1": spot + Vector2(0.03, 0.06), "user": spot + Vector2(0, -0.02)}})
					steps.append({"t": 0.35, "flash": "¡LLEGASTE PRIMERO!", "flash_color": Styles.GREEN})
					return steps
				steps.append({"t": 0.5, "ball": spot, "moves": {"a1": spot + Vector2(0, 0.03), "user": spot + Vector2(-0.03, -0.06)}})
				steps.append({"t": 0.35, "dribble": "a1", "moves": {"a1": Vector2(0.62, 0.08)}})
			_:
				steps.append({"t": 0.45, "dribble": "a1", "moves": {"a1": Vector2(0.5, 0.17), "m1": Vector2(0.45, 0.24)}})
				if success:
					var at := Vector2(0.46, 0.05)
					steps.append({"t": 0.35, "ball": at, "arc": 0.4, "moves": {"user": at + Vector2(0, -0.01)}})
					steps.append({"t": 0.4, "flash": "¡ATAJADA!", "flash_color": Styles.GREEN})
					return steps
		if goal:
			steps.append_array(_goal_steps("a1", rng, "user", scene, 0.5, false))
		else:
			steps.append({"t": 0.45, "ball": Vector2(0.64, -0.04), "arc": 0.6})
			steps.append({"t": 0.4, "flash": "¡AFUERA!", "flash_color": Color.WHITE})
		return steps

	return steps

static func _closest(scene: Dictionary, p: Vector2, ids: Array) -> String:
	var best: String = String(ids[0])
	var best_d: float = INF
	for id in ids:
		if _has(scene, id):
			var d: float = _pos(scene, id).distance_to(p)
			if d < best_d:
				best_d = d
				best = id
	return best

# --- Goles sin decisión tuya (rival o compañero) ---------------------------

## Gol en contra: arriba TU arco, el goleador rival con su nombre real
## (payload del GOAL).
static func rival_goal(ctx: Dictionary, scorer_name: String, user_on_pitch: bool, user_is_gk: bool) -> Dictionary:
	return _ambient_goal(ctx, scorer_name, false, user_on_pitch, user_is_gk)

## Gol de un compañero (Paquete 2): arriba el arco RIVAL, el goleador con
## su nombre; si estás en cancha aparecés acompañando la jugada.
static func team_goal(ctx: Dictionary, scorer_name: String, user_on_pitch: bool, user_is_gk: bool) -> Dictionary:
	return _ambient_goal(ctx, scorer_name, true, user_on_pitch, user_is_gk)

## Tres libretos: centro y cabezazo, pase filtrado, remate de lejos. ids:
## a1 = goleador, a2/a3 = atacantes, m1/m2 = defensores, gk = arquero.
## OCASIÓN CLARA sin gol (11-oct): la misma jugada, pero el arquero ataja
## o la pelota se va apenas afuera.
static func clear_chance(ctx: Dictionary, shooter_name: String, ours: bool, user_on_pitch: bool, user_is_gk: bool) -> Dictionary:
	return _ambient_goal(ctx, shooter_name, ours, user_on_pitch, user_is_gk, true)

static func _ambient_goal(ctx: Dictionary, scorer_name: String, ours: bool, user_on_pitch: bool, user_is_gk: bool, no_goal: bool = false) -> Dictionary:
	var rng := _rng(ctx, ("team_goal:" if ours else "rival_goal:") + scorer_name)
	var us: Color = ctx.get("us", Color.WHITE)
	var them: Color = ctx.get("them", Color.BLACK)
	var att_col: Color = us if ours else them
	var def_col: Color = them if ours else us
	var att_pool: String = "mates" if ours else "rivals"
	var def_pool: String = "rivals" if ours else "mates"
	var scorer: Dictionary = {"num": "", "name": short_name(scorer_name)}
	var actors: Array = []
	var tpl: int = rng.randi() % 3
	var a1: Vector2
	var a2: Vector2
	var ball_start: String
	match tpl:
		0: # centro desde la banda y cabezazo
			a1 = Vector2(0.50, 0.20)
			a2 = Vector2(0.88, 0.14)
			ball_start = "a2"
		1: # pase filtrado y definición
			a1 = Vector2(0.62, 0.40)
			a2 = Vector2(0.44, 0.52)
			ball_start = "a2"
		_: # zapatazo de afuera
			a1 = Vector2(0.48, 0.40)
			a2 = Vector2(0.72, 0.30)
			ball_start = "a1"
	var user_field: bool = user_on_pitch and not user_is_gk
	actors.append({"id": "a1", "pos": a1, "color": att_col}.merged(scorer))
	actors.append({"id": "a2", "pos": a2, "color": att_col}.merged(_person(ctx, att_pool, 1)))
	# Si es gol NUESTRO y estás en cancha (y no sos el goleador), vos sos el
	# que acompaña la jugada.
	var a3: Dictionary = _person(ctx, att_pool, 2)
	var a3_user: bool = ours and user_field
	if a3_user:
		a3 = ctx.get("user", {})
	actors.append({"id": "a3", "pos": Vector2(0.30, 0.30), "color": att_col, "user": a3_user}.merged(a3))
	# Si es gol EN CONTRA y estás en cancha, sos el defensor que no llega.
	var def1: Dictionary = _person(ctx, def_pool, 0)
	var m1_user: bool = not ours and user_field
	if m1_user:
		def1 = ctx.get("user", {})
	actors.append({"id": "m1", "pos": a1 + Vector2(-0.06, -0.03), "color": def_col, "user": m1_user}.merged(def1))
	actors.append({"id": "m2", "pos": Vector2(0.62, 0.16), "color": def_col}.merged(_person(ctx, def_pool, 1)))
	var gk: Dictionary
	if ours:
		gk = {"id": "gk", "pos": Vector2(0.5, 0.025), "color": GK_THEM}.merged(ctx.get("their_gk", {}))
	else:
		gk = {"id": "gk", "pos": Vector2(0.5, 0.025), "color": GK_US, "user": user_is_gk}.merged(ctx.get("user", {}) if user_is_gk else ctx.get("our_gk", {}))
	actors.append(gk)
	var scene := {"actors": actors, "ball": ball_start, "flip": not ours, "mirror": rng.randf() < 0.5}

	var steps: Array = []
	match tpl:
		0:
			steps.append({"t": 0.65, "ball": "a1", "arc": 2.6, "moves": {"a1": Vector2(0.49, 0.12), "m1": Vector2(0.45, 0.13)}})
		1:
			steps.append({"t": 0.55, "ball": "a1", "moves": {"a1": Vector2(0.56, 0.20), "m1": Vector2(0.50, 0.24)}})
		_:
			steps.append({"t": 0.3, "dribble": "a1", "moves": {"a1": a1 + Vector2(0, -0.04)}})
	if no_goal:
		steps.append_array(_miss_steps(rng, "gk", scene, 1.0 if tpl == 2 else 0.4))
	else:
		steps.append_array(_goal_steps("a1", rng, "gk", scene, 1.0 if tpl == 2 else 0.4, ours))
	return {"scene": scene, "steps": steps}

# --- Elegir tocando la cancha (Paquete 2) ----------------------------------
## Solo traduce "qué tocaste" a una de las opciones que YA ofreció el motor
## — nunca inventa una acción que no estaba en el menú.

static func _first_in(option_kinds: Array, group: Array) -> String:
	for k in option_kinds:
		if String(k) in group:
			return String(k)
	return ""

## Qué resaltar en la cancha según las opciones del menú.
static func tap_targets(option_kinds: Array) -> Array:
	var t: Array = []
	if _first_in(option_kinds, SHOT) != "":
		t.append("goal")
	if _first_in(option_kinds, PASS + ["distribution"]) != "":
		t.append("m1")
	if _first_in(option_kinds, DRIBBLE) != "":
		t.append("d1")
	if _first_in(option_kinds, DEFEND + ["one_on_one_save", "sweep_keeper"]) != "":
		t.append("a1")
	return t

## Acción del menú que corresponde a tocar `target`. "" = ninguna.
static func kind_for_tap(target: String, option_kinds: Array) -> String:
	if target == "goal":
		return _first_in(option_kinds, SHOT)
	if target.begins_with("m"):
		return _first_in(option_kinds, PASS + ["distribution"])
	if target.begins_with("a"):
		return _first_in(option_kinds, DEFEND + ["one_on_one_save", "sweep_keeper"])
	if target.begins_with("d") or target == "space":
		return _first_in(option_kinds, DRIBBLE)
	return ""

# --- Mapa de jugadas (Paquete 2) -------------------------------------------

## Dónde estabas en el momento `kind`, en coordenadas de CANCHA ENTERA
## vertical (x 0..1, y 0 = arco rival arriba, 1 = tu arco abajo). Las
## escenas de ataque son la mitad de arriba; las de defensa/arquero tienen
## TU arco arriba, así que se espejan a la mitad de abajo.
static func user_full_pos(kind: String, ctx: Dictionary) -> Vector2:
	var p: Vector2 = _pos(scene_for(kind, ctx), "user")
	if is_attack(kind):
		return Vector2(p.x, p.y * 0.5)
	return Vector2(1.0 - p.x, 1.0 - p.y * 0.5)

## A dónde fue tu pase (o null si la acción no es un pase), misma escala.
static func pass_target_full(kind: String, ctx: Dictionary) -> Variant:
	if not (kind in PASS):
		return null
	var p: Vector2 = _pos(scene_for(kind, ctx), "m1")
	if kind == "through_ball":
		p = Vector2(0.62, 0.22)
	return Vector2(p.x, p.y * 0.5)

# --- Árbitro y pelota parada (Paquete 3) -----------------------------------
## El árbitro es una ficha negra con borde dorado hasta que haya sprite
## (Paquete 5). Estas escenas no deciden nada: muestran eventos que el
## motor YA emitió.

## Si Match.gd pasó las animaciones del árbitro del partido
## (ctx["ref_anims"], ver Referee.anim_set) se dibuja el sprite; si no, la
## ficha negra de siempre.
static func _ref(pos: Vector2, ctx: Dictionary = {}) -> Dictionary:
	return {"id": "ref", "pos": pos, "color": REF, "num": "", "name": "ÁRBITRO", "ref": true, "anims": ctx.get("ref_anims", {})}

## CAMBIO (10-oct, Wilber: "agrega la animación de los cambios"): junto a
## la banda, a la altura del medio. El que sale camina hasta la línea, se
## saludan y el que entra pica a su puesto. `ours` = cambio de tu equipo.
static func sub_scene(ctx: Dictionary, out_name: String, in_name: String, ours: bool, out_is_user: bool, in_is_user: bool) -> Dictionary:
	var col: Color = ctx.get("us", Color.WHITE) if ours else ctx.get("them", Color.BLACK)
	var user: Dictionary = ctx.get("user", {})
	var a_out: Dictionary = {"id": "out", "pos": Vector2(0.40, 0.84), "color": col, "num": "", "name": "SALE " + short_name(out_name)}
	var a_in: Dictionary = {"id": "in", "pos": Vector2(-0.045, 1.0), "color": col, "num": "", "name": "ENTRA " + short_name(in_name)}
	if out_is_user:
		a_out.merge({"user": true, "look": user.get("look", {}), "num": user.get("num", "")}, true)
	if in_is_user:
		a_in.merge({"user": true, "look": user.get("look", {}), "num": user.get("num", "")}, true)
	# 11-oct (Wilber): el cuarto árbitro y el que entra esperan AFUERA de la
	# cancha, detrás de la línea de banda (x < 0), no parados adentro.
	var actors: Array = [a_out, a_in, _ref(Vector2(-0.05, 0.92), ctx)]
	# CUARTO ÁRBITRO CON EL CARTEL (11-oct, Wilber): rojo el número del que
	# sale, verde el del que entra. El número es el de su camiseta si está
	# en la lista de la cancha; si no, uno fijo para ese jugador.
	var n_out: String = String(a_out.get("num", ""))
	var n_in: String = String(a_in.get("num", ""))
	if n_out == "":
		n_out = String(_person_named(ctx, "mates" if ours else "rivals", out_name).get("num", ""))
	if n_out == "":
		n_out = str(2 + absi(hash("num:" + out_name)) % 10)
	if n_in == "":
		n_in = str(12 + absi(hash("num:" + in_name)) % 18)
	var steps: Array = [
		{"t": 0.25, "flash": "CAMBIO", "flash_color": Color(0.4, 0.9, 1.0), "cam": {"ids": ["out", "in", "ref"], "zoom": 1.6}, "board": {"id": "ref", "out": n_out, "in": n_in}},
		{"t": 0.95, "moves": {"out": Vector2(0.12, 0.985)}},
		{"t": 0.3},
		{"t": 0.85, "moves": {"in": Vector2(0.40, 0.86), "out": Vector2(-0.03, 1.03)}},
		{"t": 0.25, "cam": "reset"},
	]
	return {"scene": {"actors": actors, "ball": null}, "steps": steps}

## Pitazo: "kickoff" | "half" | "full".
static func whistle_scene(phase: String, ctx: Dictionary) -> Dictionary:
	var us: Color = ctx.get("us", Color.WHITE)
	var them: Color = ctx.get("them", Color.BLACK)
	# BUG (10-oct, Wilber: "cuando estoy en el banco aun así aparezco en el
	# partido"): el pitazo de arranque / entretiempo / final SIEMPRE ponía a
	# tu jugador en el círculo central, estuvieras o no en cancha. Si no
	# estás ("user_on" = false) ese lugar lo ocupa un compañero.
	var first: Dictionary = {"id": "user", "pos": Vector2(0.53, 0.95), "color": us, "user": true}.merged(ctx.get("user", {}))
	if not bool(ctx.get("user_on", true)):
		first = {"id": "m2", "pos": Vector2(0.53, 0.95), "color": us}.merged(_person(ctx, "mates", 1))
	var actors: Array = [
		first,
		{"id": "m1", "pos": Vector2(0.40, 0.90), "color": us}.merged(_person(ctx, "mates", 0)),
		{"id": "d1", "pos": Vector2(0.35, 0.70), "color": them}.merged(_person(ctx, "rivals", 0)),
		{"id": "d2", "pos": Vector2(0.66, 0.68), "color": them}.merged(_person(ctx, "rivals", 1)),
		_ref(Vector2(0.68, 0.86), ctx),
	]
	var text: String = {"kickoff": "¡A JUGAR!", "half": "ENTRETIEMPO", "full": "¡FINAL DEL PARTIDO!"}.get(phase, "")
	var steps: Array = [
		{"t": 0.45, "moves": {"ref": Vector2(0.62, 0.82)}},
		{"t": 0.9, "flash": text, "flash_color": Color.WHITE, "anim": {"ref": "pitazo"}},
	]
	if phase != "kickoff":
		# Al final de un tiempo los jugadores se aflojan y se van.
		steps.insert(1, {"t": 0.5, "moves": {"m1": Vector2(0.30, 0.98), "d1": Vector2(0.25, 0.80), "d2": Vector2(0.80, 0.80)}})
	return {"scene": {"actors": actors, "ball": Vector2(0.5, 1.0) if phase == "kickoff" else null}, "steps": steps}

## Un penal de la TANDA pateado por otro (P3, 9-oct: "repetición de la
## tanda de penales en la cancha 2D"). `ours` = patea tu equipo.
static func shootout_kick(ctx: Dictionary, ours: bool, taker_name: String, ok: bool, n: int) -> Dictionary:
	var us: Color = ctx.get("us", Color.WHITE)
	var them: Color = ctx.get("them", Color.BLACK)
	var rng := _rng(ctx, "shootout:%d" % n)
	var keeper: Dictionary = ({"id": "gk", "pos": Vector2(0.5, 0.025), "color": GK_THEM}.merged(ctx.get("their_gk", {}))) if ours 		else ({"id": "gk", "pos": Vector2(0.5, 0.025), "color": GK_US}.merged(ctx.get("our_gk", {})))
	var scene := {"actors": [
		{"id": "s", "pos": Vector2(0.5, 0.33), "color": us if ours else them, "num": "", "name": short_name(taker_name)},
		keeper,
	], "ball": Vector2(0.5, 0.215)}
	var side: float = -1.0 if rng.randf() < 0.5 else 1.0
	var steps: Array = [{"t": 0.45, "moves": {"s": Vector2(0.5, 0.235)}}]
	if ok:
		steps.append_array(_goal_steps("s", rng, "gk", scene, 0.6, ours, side, false))
	else:
		steps.append_array(_miss_steps(rng, "gk", scene, 0.6, "¡ATAJADA!", side, false))
	return {"scene": scene, "steps": steps}

## Tarjeta: el árbitro llega y la levanta. `ours` = el amonestado es de tu
## equipo.
static func card_scene(ctx: Dictionary, player_name: String, is_user: bool, ours: bool, red: bool) -> Dictionary:
	var us: Color = ctx.get("us", Color.WHITE)
	var them: Color = ctx.get("them", Color.BLACK)
	# BUG (11-oct, Wilber: "en las faltas parece que siempre hace la falta
	# el mismo jugador al mismo jugador"). Causa: el amonestado se dibujaba
	# sin su cara (un muñeco genérico con el nombre), la víctima era SIEMPRE
	# el primero de la lista del otro equipo, y todo pasaba en el mismo punto
	# de la cancha. Ahora el amonestado es él (cara y número), la víctima
	# cambia en cada falta y el lugar también.
	var rng := _rng_mix(ctx, "card:" + player_name)
	var who: Dictionary = ctx.get("user", {}) if is_user else _person_named(ctx, "mates" if ours else "rivals", player_name)
	var victim: Dictionary = _person_other(ctx, "rivals" if ours else "mates", rng, "")
	var at := Vector2(rng.randf_range(-0.22, 0.24), rng.randf_range(-0.16, 0.26))
	var actors: Array = [
		{"id": "p", "pos": Vector2(0.46, 0.44) + at, "color": us if ours else them, "user": is_user}.merged(who),
		{"id": "v", "pos": Vector2(0.53, 0.49) + at, "color": them if ours else us}.merged(victim),
		_ref(Vector2(0.76, 0.72) + at * 0.6, ctx),
	]
	var col: Color = CARD_RED if red else CARD_YELLOW
	var steps: Array = [
		{"t": 0.55, "moves": {"ref": Vector2(0.57, 0.37) + at}, "anim": {"v": "caida"}},
		{"t": 0.25, "set_card": {"ref": col}, "anim": {"ref": "roja" if red else "amarilla"}, "cam": {"ids": ["ref", "p"], "zoom": 2.6}},
		{"t": 1.2, "flash": "ROJA" if red else "AMARILLA", "flash_color": col, "anim": {"p": "protesta"}},
	]
	if red:
		steps.append({"t": 0.9, "moves": {"p": Vector2(0.02, 0.62)}, "cam": "reset"})
	return {"scene": {"actors": actors, "ball": null}, "steps": steps}

## LESIÓN (11-oct): el jugador queda en el piso, el árbitro para el juego,
## entran los camilleros desde la banda y se lo llevan.
static func injury_scene(ctx: Dictionary, player_name: String, is_user: bool, ours: bool) -> Dictionary:
	var us: Color = ctx.get("us", Color.WHITE)
	var them: Color = ctx.get("them", Color.BLACK)
	var rng := _rng_mix(ctx, "injury:" + player_name)
	var who: Dictionary = ctx.get("user", {}) if is_user else _person_named(ctx, "mates" if ours else "rivals", player_name)
	# El compañero que se acerca no puede ser el mismo lesionado.
	var mate: Dictionary = _person_other(ctx, "mates" if ours else "rivals", rng, String(who.get("name", "")))
	var actors: Array = [
		{"id": "p", "pos": Vector2(0.52, 0.52), "color": us if ours else them, "user": is_user}.merged(who),
		{"id": "v", "pos": Vector2(0.44, 0.47), "color": us if ours else them}.merged(mate),
		{"id": "o", "pos": Vector2(0.60, 0.44), "color": them if ours else us}.merged(_person_other(ctx, "rivals" if ours else "mates", rng, "")),
		_ref(Vector2(0.30, 0.66), ctx),
	]
	var steps: Array = [
		{"t": 0.7, "anim": {"p": "caida"}, "moves": {"ref": Vector2(0.45, 0.56)}},   # sin cartel: taparía al jugador (el aviso sale después)
		# El carrito médico entra, el jugador sube (deja de verse) y se va.
		{"t": 1.6, "stretcher": Vector2(0.61, 0.56), "anim": {"p": "caida"}},
		{"t": 0.7, "anim": {"p": "caida"}},
		{"t": 0.2, "hide": ["p"]},
		{"t": 1.7, "stretcher": Vector2(1.12, 0.56)},
	]
	return {"scene": {"actors": actors, "ball": null}, "steps": steps}

## Cobro de penal: el árbitro marca el punto. `ours` = penal a favor
## (arriba el arco rival); si no, arriba TU arco.
static func penalty_award_scene(ctx: Dictionary, ours: bool) -> Dictionary:
	var us: Color = ctx.get("us", Color.WHITE)
	var them: Color = ctx.get("them", Color.BLACK)
	var att: Color = us if ours else them
	var def: Color = them if ours else us
	var actors: Array = [
		{"id": "a1", "pos": Vector2(0.52, 0.12), "color": att}.merged(_person(ctx, "mates" if ours else "rivals", 0)),
		{"id": "m1", "pos": Vector2(0.46, 0.15), "color": def}.merged(_person(ctx, "rivals" if ours else "mates", 0)),
		{"id": "gk", "pos": Vector2(0.5, 0.025), "color": GK_THEM if ours else GK_US}.merged(ctx.get("their_gk" if ours else "our_gk", {})),
		_ref(Vector2(0.66, 0.42), ctx),
	]
	var steps: Array = [
		{"t": 0.5, "moves": {"ref": Vector2(0.55, 0.24)}},
		{"t": 0.9, "flash": "¡PENAL!", "flash_color": Styles.GOLD if ours else Styles.RED, "anim": {"ref": "pitazo"}},
	]
	return {"scene": {"actors": actors, "ball": Vector2(0.5, 0.21), "flip": not ours}, "steps": steps}

## Penal pateado por la IA que terminó en gol (los errados por la IA no
## emiten evento — no hay nada que mostrar).
static func ai_penalty_goal(ctx: Dictionary, taker_name: String, ours: bool) -> Dictionary:
	var rng := _rng(ctx, "ai_pen:" + taker_name)
	var actors: Array = [
		{"id": "a1", "pos": Vector2(0.5, 0.26), "color": ctx.get("us", Color.WHITE) if ours else ctx.get("them", Color.BLACK), "num": "", "name": short_name(taker_name)},
		{"id": "gk", "pos": Vector2(0.5, 0.025), "color": GK_THEM if ours else GK_US}.merged(ctx.get("their_gk" if ours else "our_gk", {})),
	]
	var scene := {"actors": actors, "ball": Vector2(0.5, 0.21), "flip": not ours}
	var steps: Array = [{"t": 0.35, "moves": {"a1": Vector2(0.5, 0.225)}}]
	steps.append_array(_goal_steps("a1", rng, "gk", scene, [1.3, 0.7, 0.25][rng.randi() % 3], ours, 2.0, false))
	return {"scene": scene, "steps": steps}
