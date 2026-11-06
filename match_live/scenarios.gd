class_name Scenarios
extends RefCounted
## Arma en la cancha cada TIPO de momento clave del MatchEngine de
## FootballCareer (_KIND_WEIGHTS): dónde está el balón, quién lo tiene,
## dónde estás tú y qué hacen rivales y compañeros. Tu equipo (lado 0)
## siempre ataca hacia arriba. Todo depende de TU puesto: un lateral
## izquierdo encara por la izquierda, un DFC defiende en el área, etc.
##
## Devuelve {"phase": attack|defense|gk, "limit": segundos, "title": texto,
## "locked": bool (tiro libre / penal)}.

const TITLES := {
	"shot_on_goal": "Ocasión de gol", "long_shot": "Tiro de lejos", "one_on_one": "Mano a mano",
	"chip_shot": "¡Para picarla!", "dribble": "Encarar", "key_pass": "Pase clave",
	"through_ball": "Pase filtrado", "cross": "Centro", "cutback": "Pase atrás",
	"counter_run": "Contraataque", "one_two": "Pared", "switch_play": "Cambio de frente",
	"free_kick": "Tiro libre", "penalty": "Penal", "volley": "Volea", "aerial_duel": "Duelo aéreo",
	"tackle": "Quite", "last_ditch_tackle": "Último recurso", "recovery_tackle": "Recuperación",
	"interception": "Corta el pase", "pressing": "Presión", "clearance": "Despeje",
	"block_shot": "Bloqueo", "one_on_one_save": "Mano a mano (arquero)",
	"sweep_keeper": "Salir a cortar", "distribution": "Saque del arquero",
}

## Tipos que el MatchEngine puede mandar y no tienen escenario propio.
const ALIAS := {"cross_field": "switch_play", "header": "aerial_duel", "penalty_kick": "penalty"}

static func W(x: float, d: float) -> Vector2:
	return Cfg.form_to_world(0, clampf(x, 0.03, 0.97), clampf(d, 0.01, 0.99))

static func apply(m: Match, kind_in: String) -> Dictionary:
	var kind: String = String(ALIAS.get(kind_in, kind_in))
	var u: Player = m.user
	var us: Team = m.teams[0]
	var them: Team = m.teams[1]
	# El arquero no encara: sus momentos son de arco.
	if u.is_gk() and not kind in ["one_on_one_save", "sweep_keeper", "distribution", "penalty"]:
		kind = {"tackle": "one_on_one_save", "clearance": "sweep_keeper", "interception": "sweep_keeper"}.get(kind, "one_on_one_save")
	# Jugadas de arquero que le tocan a un jugador de campo: su equivalente
	# (antes se armaban en el área propia con el título del arquero).
	if not u.is_gk() and kind in ["one_on_one_save", "sweep_keeper"]:
		kind = "last_ditch_tackle" if kind == "one_on_one_save" else "clearance"
	var ux: float = clampf(u.base.x, 0.1, 0.9)
	var side_x: float = 0.1 if ux < 0.5 else 0.9
	var lift: float = {"FW": 0.0, "MF": -0.08, "DF": -0.22, "GK": -0.3}.get(u.role, 0.0)
	var info := {"phase": "attack", "limit": 14.0, "title": TITLES.get(kind, "Tu jugada"), "locked": false}

	match kind:
		# ------------------------------------------------ ataque, con balón
		"shot_on_goal":
			# Dentro del área, como en WSC (~14 m del arco; antes ~21 m).
			var bp := W(lerpf(ux, 0.5, 0.6), 0.86)
			_place_all(m, bp, 0)
			_give(m, u, bp)
			_mark(them, u, 1.6, 0.6)
		"long_shot":
			var bp := W(lerpf(ux, 0.5, 0.5), 0.70)
			_place_all(m, bp, 0)
			_give(m, u, bp)
			_mark(them, u, 6.0, 0.0)
			_mark(them, u, 7.0, 0.5)
		"one_on_one", "chip_shot":
			var bp := W(lerpf(ux, 0.5, 0.7), 0.74)
			_place_all(m, bp, 0)
			_give(m, u, bp)
			# Todos los rivales quedaron atrás: solo el arquero.
			for o in them.players:
				if not o.is_gk():
					o.position.y = maxf(o.position.y, bp.y + randf_range(3.0, 14.0) * Cfg.M)
			if kind == "chip_shot":
				them.gk().position = W(0.5, 0.88)
				them.gk().rush = true
			info["limit"] = 9.0
		"dribble":
			var bp := W(ux, 0.62 + lift)
			_place_all(m, bp, 0)
			_give(m, u, bp)
			_mark(them, u, 3.0, 0.0)
		"key_pass", "through_ball":
			var bp := W(lerpf(ux, 0.5, 0.3), 0.64 + lift * 0.5)
			_place_all(m, bp, 0)
			_give(m, u, bp)
			_mark(them, u, 3.5, 0.3)
			# Los de arriba pican al espacio.
			for t in us.players:
				if t.role == "FW" and t != u:
					t.position = W(t.base.x, 0.74 + randf() * 0.04)
					m.run_target = Vector2.INF
		"cross":
			var bp := W(side_x, 0.84)
			_place_all(m, bp, 0)
			_give(m, u, bp)
			_mark(them, u, 2.5, 0.0)
			_box_runners(m, us, u)
		"cutback":
			var bp := W(lerpf(side_x, 0.5, 0.25), 0.95)
			_place_all(m, bp, 0)
			_give(m, u, bp)
			_mark(them, u, 2.0, 0.0)
			_box_runners(m, us, u, 0.84)
		"counter_run":
			var bp := W(ux, 0.42 + lift * 0.5)
			_place_all(m, bp, 0)
			_give(m, u, bp)
			# Contra: casi todo el rival quedó del otro lado.
			var keep: int = 0
			for o in them.players:
				if o.is_gk():
					continue
				if o.role == "DF" and keep < 3:
					o.position = W(o.base.x * 0.6 + 0.2, 0.74)
					keep += 1
				else:
					o.position.y = bp.y + randf_range(4.0, 18.0) * Cfg.M
			for t in us.players:
				if t.role == "FW" and t != u:
					t.position = W(t.base.x, 0.55)
			info["limit"] = 16.0
		"one_two":
			var bp := W(ux, 0.6 + lift * 0.5)
			_place_all(m, bp, 0)
			_give(m, u, bp)
			_mark(them, u, 2.5, 0.0)
			var mate: Player = _nearest(us, bp + Cfg.attack_dir(0) * 6.0 * Cfg.M, [u, us.gk()])
			# Al costado y apenas adelante: el carril del pase no pasa por el
			# rival que te marca (antes lo cortaba al primer toque).
			mate.position = bp + Vector2(signf(0.5 - ux) * 7.0 * Cfg.M, 0.0) + Cfg.attack_dir(0) * 1.5 * Cfg.M
			mate.face(bp - mate.position)
			info["wall_mate"] = mate
			for o in them.players:
				if not o.is_gk() and o.position.distance_to(mate.position) < 6.5 * Cfg.M and o.position.distance_to(bp) > 3.0 * Cfg.M:
					o.position = mate.position + (o.position - mate.position).normalized() * 6.5 * Cfg.M
		"switch_play":
			var bp := W(side_x, 0.5 + lift * 0.5)
			_place_all(m, bp, 0)
			_give(m, u, bp)
			_mark(them, u, 2.5, 0.0)
			var far: Player = _nearest(us, W(1.0 - side_x, 0.62), [u, us.gk()])
			far.position = W(1.0 - side_x, 0.62)
		"free_kick":
			var bp := W(0.5 + randf_range(-0.15, 0.15), 0.78)
			_place_all(m, bp, 0)
			_give(m, u, bp)
			u.position = bp + Vector2(0, 1.2 * Cfg.M)
			u.facing = (Cfg.target_goal(0) - bp).normalized()
			_wall(m, bp, 4)
			info["locked"] = true
			info["limit"] = 10.0
		"penalty":
			if u.is_gk():
				return _penalty_save(m, info)
			var bp := Vector2(Cfg.FIELD_W * 0.5, Cfg.PENALTY_SPOT)
			_place_all(m, bp, 0)
			for p in us.players + them.players:
				if not p.is_gk() and p.position.y < Cfg.BOX_H + 1.0 * Cfg.M:
					p.position.y = Cfg.BOX_H + randf_range(1.5, 4.0) * Cfg.M
			_give(m, u, bp)
			u.position = bp + Vector2(0, 1.2 * Cfg.M)
			u.facing = Vector2.UP
			them.gk().position = Vector2(Cfg.FIELD_W * 0.5, 0.6 * Cfg.M)
			info["locked"] = true
			info["limit"] = 8.0
		# ------------------------------------------------ ataque, balón por el aire
		"volley", "aerial_duel":
			var target := W(lerpf(ux, 0.5, 0.7), 0.86 if kind == "aerial_duel" else 0.80)
			var crosser_spot := W(side_x, 0.82)
			_place_all(m, target, 0)
			var crosser: Player = _nearest(us, crosser_spot, [u, us.gk()])
			crosser.position = crosser_spot
			_give(m, crosser, crosser_spot)
			u.position = target + Vector2(0, 2.5 * Cfg.M)
			_mark(them, u, 1.2, 0.0)
			# Centro programado a tu cabeza / a tu pie, con la altura justa.
			m.m_script.append({"t": 0.6, "do": "cross", "from": crosser, "to": u, "spot": target,
				"hk": 1.15 if kind == "aerial_duel" else 0.75})
			info["limit"] = 6.0
			if u.role == "DF" and kind == "aerial_duel":
				# Un DF en duelo aéreo es en su área: despejar. (La VOLEA de un
				# defensor es en el área rival, tras un córner: antes también
				# se armaba en la propia y decía "Volea" defendiendo.)
				return _defensive_header(m, info)
		# ------------------------------------------------ defensa
		"tackle", "pressing", "recovery_tackle", "last_ditch_tackle", "interception", "block_shot", "clearance":
			return _defense(m, kind, info, ux, lift)
		# ------------------------------------------------ arquero
		"one_on_one_save":
			info["phase"] = "gk"
			var bp := W(lerpf(ux, 0.5, 0.5), 0.24)
			_place_all(m, bp, 1)
			var att: Player = _nearest(them, bp, [them.gk()])
			_give(m, att, bp)
			for t in us.players:
				if not t.is_gk():
					t.position.y = minf(t.position.y, bp.y - randf_range(3.0, 12.0) * Cfg.M)
			_keeper_home(m)
			info["limit"] = 8.0
		"sweep_keeper":
			info["phase"] = "gk"
			var start := W(lerpf(ux, 0.5, 0.6), 0.32)
			_place_all(m, start, 1)
			var att2: Player = _nearest(them, start, [them.gk()])
			att2.position = start
			_keeper_home(m)
			# Pase filtrado rodando hacia tu arco.
			m.ball.release()
			m.ball.position = start + Vector2(0, 2.0 * Cfg.M)
			m.ball.vel = (W(0.5, 0.06) - m.ball.position).normalized() * 13.0 * Cfg.M
			m.ball.last_touch = att2
			info["limit"] = 7.0
		"distribution":
			info["phase"] = "gk"
			var g := W(0.5, 0.06)
			_place_all(m, W(0.5, 0.3), 0)
			if u.is_gk():
				_give(m, u, g)
				u.holding = true
			else:
				# Si no eres arquero, el saque te busca a ti: bajas a recibir
				# libre (antes el saque cruzaba 50 m hasta el 9 y se perdía).
				var rx: Vector2 = W(clampf(ux, 0.2, 0.8), 0.3)
				u.position = rx
				for o in them.players:
					if not o.is_gk() and o.position.distance_to(rx) < 7.0 * Cfg.M:
						o.position = rx + (o.position - rx).normalized() * 7.0 * Cfg.M
				_give(m, us.gk(), g)
				us.gk().holding = true
				us.gk().think_cd = 9.0
				m.m_script.append({"t": 1.0, "do": "pass", "from": us.gk(), "to": u})
				info["phase"] = "attack"
		_:
			# Cualquier otro tipo: encarar desde tu zona.
			var bp := W(ux, 0.6 + lift)
			_place_all(m, bp, 0)
			_give(m, u, bp)
			_mark(them, u, 3.0, 0.0)
	if lead_enabled and kind in LEAD_KINDS and m.ball.owner_p == u and not u.is_gk():
		_lead_in(m, kind, info)
	# Aire al arrancar: ningún rival pegado a vos con el balón (antes alguno
	# quedaba encima por la formación y te robaba apenas tocabas).
	if m.ball.owner_p == u and not u.is_gk():
		for o in them.players:
			if o.is_gk():
				continue
			var d: Vector2 = o.position - u.position
			if d.length() < 2.2 * Cfg.M:
				var dir: Vector2 = d.normalized() if d.length() > 1.0 else Cfg.attack_dir(0)
				o.position = u.position + dir * 2.2 * Cfg.M
				o.face(u.position - o.position)
	return info

# ---------------------------------------------------------------- defensa

static func _defense(m: Match, kind: String, info: Dictionary, ux: float, lift: float) -> Dictionary:
	var u: Player = m.user
	var us: Team = m.teams[0]
	var them: Team = m.teams[1]
	info["phase"] = "defense"
	info["limit"] = 11.0
	# Profundidad (marco de tu equipo) según dónde juegas.
	var d: float = {"DF": 0.26, "MF": 0.45, "FW": 0.66}.get(u.role, 0.4)
	match kind:
		"last_ditch_tackle", "block_shot", "clearance":
			d = 0.18
		"pressing":
			d = 0.7 if u.role == "FW" else d + 0.12
	var bp := W(ux, d)
	_place_all(m, bp, 1)
	var carrier: Player = _nearest(them, bp, [them.gk()])
	match kind:
		"tackle":
			_give(m, carrier, bp)
			u.position = bp + Vector2(0, 4.5 * Cfg.M)
			carrier.facing = Vector2.DOWN
			if lead_enabled:
				# Un rival se la juega al que te va a encarar.
				var sx: float = 1.0 if ux < 0.5 else -1.0
				_rival_lead(m, carrier, bp + Vector2(sx * 5.0, -13.0) * Cfg.M, bp + Vector2(0, -2.5 * Cfg.M), info)
				u.position = bp + Vector2(0, 5.5 * Cfg.M)
		"pressing":
			_give(m, carrier, bp)
			u.position = bp + Vector2(randf_range(-3.0, 3.0), 7.0) * Cfg.M
			if lead_enabled:
				# Pase horizontal entre sus defensores: salís a presionar al receptor.
				var sx2: float = 1.0 if ux < 0.5 else -1.0
				_rival_lead(m, carrier, bp + Vector2(sx2 * 13.0, -2.0) * Cfg.M, bp + Vector2(sx2 * 2.0 * Cfg.M, 0.0), info)
				u.vel = (bp - u.position).normalized() * 4.0 * Cfg.M
		"recovery_tackle":
			_give(m, carrier, bp)
			# Te pasó: estás detrás y a un costado.
			u.position = bp + Vector2(1.5 * Cfg.M, -2.5 * Cfg.M)
			carrier.vel = Vector2.DOWN * 5.0 * Cfg.M
		"last_ditch_tackle":
			_give(m, carrier, bp)
			u.position = bp + Vector2(2.2 * Cfg.M, -0.5 * Cfg.M)
			m.m_script.append({"t": 1.4, "do": "shoot", "from": carrier})
		"block_shot":
			var sp := W(ux * 0.6 + 0.2, 0.24)
			_give(m, carrier, sp)
			u.position = sp + Vector2(0, 3.5 * Cfg.M)
			m.m_script.append({"t": 1.0, "do": "shoot", "from": carrier})
		"interception":
			# El rival va a filtrar a un compañero que quedó a tu espalda.
			_give(m, carrier, bp + Vector2(0, -6.0 * Cfg.M))
			var recv: Player = _nearest(them, bp + Vector2(0, 8.0 * Cfg.M), [them.gk(), carrier])
			recv.position = bp + Vector2(randf_range(-4.0, 4.0) * Cfg.M, 9.0 * Cfg.M)
			u.position = bp.lerp(recv.position, 0.45) + Vector2(4.0 * Cfg.M, 0)
			m.m_script.append({"t": 0.9, "do": "pass", "from": carrier, "to": recv})
		"clearance":
			# Balón suelto en tu área y un delantero llegando.
			m.ball.release()
			m.ball.position = W(0.5 + (ux - 0.5) * 0.4, 0.09)
			m.ball.vel = Vector2(randf_range(-2.0, 2.0), 2.0) * Cfg.M
			m.ball.last_touch = carrier
			carrier.position = m.ball.position + Vector2(randf_range(-3.0, 3.0), -5.0) * Cfg.M
			u.position = m.ball.position + Vector2(0, 2.5 * Cfg.M)
			info["limit"] = 6.0
	u.facing = (m.ball.position - u.position).normalized()
	return info

## La jugada defensiva nace de un pase del rival: `carrier` todavía no la
## tiene; un compañero suyo se la juega a `spot` y la pausa llega cuando la
## recibe ("¡La recibe!").
static func _rival_lead(m: Match, carrier: Player, from: Vector2, spot: Vector2, info: Dictionary) -> void:
	var them: Team = m.teams[1]
	var us: Team = m.teams[0]
	var M: float = Cfg.M
	from.x = clampf(from.x, 2.0 * M, Cfg.FIELD_W - 2.0 * M)
	from.y = clampf(from.y, 4.0 * M, Cfg.FIELD_H - 4.0 * M)
	var passer: Player = _nearest(them, from, [carrier, them.gk()])
	if passer == null:
		return
	passer.position = from
	passer.face(spot - from)
	m.ball.release()
	m.ball.position = from + (spot - from).normalized() * 0.6 * M
	m.ball.take(passer)
	passer.think_cd = 9.0
	carrier.position = spot - (spot - from).normalized() * 1.5 * M
	carrier.face(from - carrier.position)
	carrier.think_cd = 0.6
	for o in us.players:
		if o.is_gk() or o == m.user:
			continue
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(o.position, from, spot)
		if q.distance_to(o.position) < 3.0 * M:
			var away: Vector2 = (o.position - q).normalized() if o.position.distance_to(q) > 0.3 else (from - spot).orthogonal().normalized()
			o.position = q + away * 3.2 * M
	m.m_script.append({"t": 0.4, "do": "lead", "from": passer, "to": carrier, "spot": spot, "lob": false})
	info["dlead"] = carrier
	info["limit"] = float(info.get("limit", 11.0)) + 1.0

static func _defensive_header(m: Match, info: Dictionary) -> Dictionary:
	# Centro del rival a tu área: deslizar = despejar de cabeza.
	var u: Player = m.user
	var us: Team = m.teams[0]
	var them: Team = m.teams[1]
	info["phase"] = "defense"
	var target := W(0.5 + (u.base.x - 0.5) * 0.3, 0.12)
	var cs := W(0.9 if u.base.x > 0.5 else 0.1, 0.16)
	_place_all(m, target, 1)
	var crosser: Player = _nearest(them, cs, [them.gk()])
	crosser.position = cs
	_give(m, crosser, cs)
	var striker: Player = _nearest(them, target, [them.gk(), crosser])
	striker.position = target + Vector2(1.0 * Cfg.M, -1.5 * Cfg.M)
	u.position = target + Vector2(-0.5 * Cfg.M, 1.0 * Cfg.M)
	m.m_script.append({"t": 0.6, "do": "cross", "from": crosser, "to": striker, "spot": target, "hk": 1.15})
	info["limit"] = 6.0
	return info

static func _penalty_save(m: Match, info: Dictionary) -> Dictionary:
	var us: Team = m.teams[0]
	var them: Team = m.teams[1]
	info["phase"] = "gk"
	var bp := Vector2(Cfg.FIELD_W * 0.5, Cfg.FIELD_H - Cfg.PENALTY_SPOT)
	_place_all(m, bp, 1)
	for p in us.players + them.players:
		if not p.is_gk() and p.position.y > Cfg.FIELD_H - Cfg.BOX_H - 1.0 * Cfg.M:
			p.position.y = Cfg.FIELD_H - Cfg.BOX_H - randf_range(1.5, 4.0) * Cfg.M
	var taker: Player = _nearest(them, bp, [them.gk()])
	_give(m, taker, bp)
	taker.position = bp + Vector2(0, -1.2 * Cfg.M)
	m.user.position = Vector2(Cfg.FIELD_W * 0.5, Cfg.FIELD_H - 0.6 * Cfg.M)
	m.m_script.append({"t": 1.6, "do": "shoot", "from": taker})
	info["limit"] = 6.0
	return info

# ---------------------------------------------------------------- utilidades

## Todos a su lugar de formación según dónde está el balón y quién lo tiene.
## Las pruebas que arrancan "con la pelota en el pie" lo apagan.
static var lead_enabled: bool = true

## Jugadas que arrancan con un pase de un compañero hacia vos.
const LEAD_KINDS := ["shot_on_goal", "one_on_one", "chip_shot", "long_shot", "dribble",
	"key_pass", "through_ball", "counter_run", "cross", "cutback", "switch_play", "one_two"]

## La jugada NACE: un compañero tiene la pelota y te la juega al punto donde
## antes "aparecías" con ella; vos venís corriendo a recibir. La primera
## decisión es al recibir (pausa "¡Es tuya!"), no en una foto armada.
static func _lead_in(m: Match, kind: String, info: Dictionary) -> void:
	var u: Player = m.user
	var us: Team = m.teams[0]
	var them: Team = m.teams[1]
	var M: float = Cfg.M
	var bp: Vector2 = m.ball.position
	var fwd: Vector2 = Cfg.attack_dir(0)
	var side: float = -1.0 if bp.x > Cfg.FIELD_W * 0.5 else 1.0   # hacia el centro
	var from: Vector2
	var run_back: float = 3.5
	match kind:
		"shot_on_goal":
			# Pase desde el costado del área.
			var wide: float = 14.0 * M if bp.x < Cfg.FIELD_W * 0.5 else -14.0 * M
			from = Vector2(bp.x + wide, bp.y) - fwd * 3.0 * M
			run_back = 4.0
		"one_on_one", "chip_shot":
			# Pelota por encima de la defensa: picás a la espalda.
			from = bp - fwd * 22.0 * M + Vector2(side * 6.0 * M, 0.0)
			run_back = 7.0
		"long_shot":
			# Un delantero te la descarga hacia atrás.
			from = bp + fwd * 7.0 * M + Vector2(side * 5.0 * M, 0.0)
			run_back = 3.0
		"counter_run":
			# Salida rápida al costado apenas se recupera la pelota.
			from = bp - fwd * 5.0 * M + Vector2(side * 11.0 * M, 0.0)
			run_back = 3.0
		"cross":
			# Te la abren a la banda y llegás lanzado (desborde).
			from = bp - fwd * 15.0 * M + Vector2(side * 7.0 * M, 0.0)
			run_back = 6.0
		"cutback":
			# Filtrado al callejón: picás hasta el fondo.
			from = bp - fwd * 16.0 * M + Vector2(side * 5.0 * M, 0.0)
			run_back = 7.0
		"switch_play":
			# Te la da el volante de al lado; el cambio lo decidís vos.
			from = bp + Vector2(side * 13.0 * M, 0.0) - fwd * 3.0 * M
			run_back = 2.0
		"one_two":
			from = bp - fwd * 11.0 * M - Vector2(side * 3.0 * M, 0.0)
			run_back = 3.0
		_:
			from = bp - fwd * 14.0 * M + Vector2(side * 5.0 * M, 0.0)
			run_back = 3.0
	from.x = clampf(from.x, 2.0 * M, Cfg.FIELD_W - 2.0 * M)
	from.y = clampf(from.y, 4.0 * M, Cfg.FIELD_H - 4.0 * M)
	var skip: Array = [u, us.gk()]
	if info.has("wall_mate"):
		skip.append(info["wall_mate"])
	var passer: Player = _nearest(us, from, skip)
	if passer == null:
		return
	passer.position = from
	passer.face(bp - from)
	m.ball.release()
	m.ball.position = from + (bp - from).normalized() * 0.6 * M
	m.ball.take(passer)
	passer.think_cd = 9.0
	# Vos, unos metros antes del punto, ya corriendo hacia él.
	u.position = bp - fwd * run_back * M
	u.facing = fwd
	u.vel = fwd * 4.0 * M
	m.run_target = bp
	# El carril del pase limpio (el rival llega tarde, no lo corta al toque).
	for o in them.players:
		if o.is_gk():
			continue
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(o.position, from, bp)
		if q.distance_to(o.position) < 2.6 * M:
			var away: Vector2 = (o.position - q).normalized() if o.position.distance_to(q) > 0.3 else (from - bp).orthogonal().normalized()
			o.position = q + away * 2.8 * M
		# El que te marca, medio paso atrás del punto donde recibís.
		if o.position.distance_to(bp) < 3.6 * M:
			o.position = bp + (o.position - bp).normalized() * 3.6 * M
			o.stun = maxf(o.stun, 0.9)
		# El que te marca arranca un paso atrasado: le ganaste la espalda con
		# el desmarque (si no, cortaba el pase justo detrás tuyo).
		if o.position.distance_to(u.position) < 4.0 * M:
			o.position = u.position + (o.position - u.position).normalized() * 4.0 * M
			o.stun = maxf(o.stun, 0.6)
		# En la contra los que vuelven vienen dándose vuelta: tardan un poco más.
		if kind == "counter_run" and o.position.distance_to(u.position) < 7.0 * M:
			o.stun = maxf(o.stun, 0.9)
		# Nadie encima del que pasa (se la cortaba al primer toque).
		if o.position.distance_to(from) < 3.5 * M:
			o.position = from + (o.position - from).normalized() * 3.5 * M
		# La defensa llega un tiempo tarde a la jugada (por eso es ocasión).
		var late: float = 0.9 if kind == "counter_run" else 0.55   # en la contra quedaron mal parados
		var reach: float = 6.0 if kind == "counter_run" else 4.0
		if o.position.distance_to(from) < 7.0 * M or Geometry2D.get_closest_point_to_segment(o.position, from, bp).distance_to(o.position) < reach * M:
			o.stun = maxf(o.stun, late)
	var lob: bool = from.distance_to(bp) > 24.0 * M or kind in ["one_on_one", "chip_shot"]
	# El arquero no corta el pase (sale recién cuando recibís).
	if kind in ["one_on_one", "chip_shot"]:
		them.gk().no_touch = 1.8
	m.m_script.append({"t": 0.3, "do": "lead", "from": passer, "spot": bp, "lob": lob})
	info["lead"] = true
	info["limit"] = float(info.get("limit", 14.0)) + 1.5

static func _place_all(m: Match, ball_pos: Vector2, poss_side: int) -> void:
	for t in m.teams:
		for p in t.players:
			if p.is_gk():
				var g: Vector2 = Cfg.own_goal(t.side)
				p.position = g + (ball_pos - g).normalized() * 1.5 * Cfg.M
			else:
				p.position = t.shape_target(p, ball_pos, t.side == poss_side) + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)) * Cfg.M
			p.vel = Vector2.ZERO
			p.want = Vector2.ZERO
			p.face(ball_pos - p.position)
	m.ball.release()
	m.ball.position = ball_pos
	m.ball.vel = Vector2.ZERO
	m.ball.z = 0.0
	m.ball.vz = 0.0

static func _give(m: Match, p: Player, pos: Vector2) -> void:
	p.position = pos - Cfg.attack_dir(p.team.side) * 0.7 * Cfg.M
	p.facing = Cfg.attack_dir(p.team.side)
	m.ball.position = pos
	m.ball.take(p)
	m.possession = p.team.side
	p.think_cd = 0.8

static func _keeper_home(m: Match) -> void:
	var k: Player = m.teams[0].gk()
	k.position = Cfg.own_goal(0) + Vector2(0, -1.5 * Cfg.M)
	k.facing = Vector2.UP

## Pone al rival más cercano encima de `target` (a `dist` metros hacia su
## arco, corrido `lat` a un costado).
static func _mark(team: Team, target: Player, dist: float, lat: float) -> void:
	var g: Vector2 = Cfg.own_goal(team.side)
	var away: Array = [team.gk()]
	var p: Player = _nearest(team, target.position, away)
	while p != null and p.position.distance_to(target.position) < 0.5 * Cfg.M and away.size() < 6:
		away.append(p)
		p = _nearest(team, target.position, away)
	if p == null:
		return
	var dir: Vector2 = (g - target.position).normalized()
	p.position = target.position + dir * dist * Cfg.M + dir.orthogonal() * lat * Cfg.M * 2.0
	p.face(target.position - p.position)

static func _nearest(team: Team, pos: Vector2, skip: Array) -> Player:
	var best: Player = null
	var bd: float = INF
	for p in team.players:
		if p in skip:
			continue
		var d: float = p.position.distance_squared_to(pos)
		if d < bd:
			bd = d
			best = p
	return best

static func _box_runners(m: Match, us: Team, u: Player, depth: float = 0.9) -> void:
	var xs := [0.38, 0.5, 0.62]
	var i: int = 0
	for t in us.players:
		if t == u or t.is_gk() or t.role == "DF":
			continue
		if i >= xs.size():
			break
		t.position = W(xs[i], depth + randf_range(-0.02, 0.02))
		i += 1

static func _wall(m: Match, ball_pos: Vector2, n: int) -> void:
	var g: Vector2 = Cfg.target_goal(0)
	var dir: Vector2 = (g - ball_pos).normalized()
	var c: Vector2 = ball_pos + dir * 9.15 * Cfg.M
	var used: Array = [m.teams[1].gk()]
	for i in n:
		var p: Player = _nearest(m.teams[1], c, used)
		used.append(p)
		p.position = c + dir.orthogonal() * (float(i) - float(n - 1) * 0.5) * 0.9 * Cfg.M
		p.face(-dir)
		# Pose de barrera (manos adelante), mirando al que patea.
		p.play_gesture("pitch_barrera_s" if -dir.y > 0.0 else "pitch_barrera", 9.0)
