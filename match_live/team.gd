class_name Team
extends RefCounted
## Un equipo y su IA. Cada cuadro decide hacia dónde va cada jugador que
## no maneja el humano: mantener la formación, presionar, apoyar, cubrir.
## El portador CPU decide entre gambetear, pasar o tirar.


var side: int = 0
var short_name: String = ""
var color := Color.WHITE
var is_human: bool = false
var difficulty: float = 1.0      # 0.6 fácil .. 1.3 difícil (solo CPU)
var players: Array[Player] = []
var score: int = 0
var game: Node                   # Match (sin tipo para evitar ciclos)

var _dribble_dir := Vector2.ZERO

func _init(s: int, n: String, c: Color, human: bool) -> void:
	side = s
	short_name = n
	color = c
	is_human = human

var formation: String = "4-3-3"
var kit: Dictionary = {}
var gk_kit: Dictionary = {}
var ask_pass: float = 0.0          # el usuario pidió el balón (segundos que dura el pedido)

## Arma los 11 de una formación. `user_slot` = índice del puesto del
## usuario (0 = POR) o -1; `user_cfg` = su avatar (config de FootballCareer).
func build(world: Node2D, p_formation: String, p_kit: Dictionary, p_gk_kit: Dictionary, seed_base: int, user_slot: int = -1, user_cfg: Dictionary = {}, roster: Array = []) -> void:
	formation = p_formation
	kit = p_kit
	gk_kit = p_gk_kit
	if not roster.is_empty():
		_build_roster(world, roster)
		return
	var codes: Array = PitchFormations.slots(formation)
	var spots: Array = PitchFormations.layout(formation)
	for i in codes.size():
		var p := Player.new()
		var face: Dictionary = user_cfg if i == user_slot and not user_cfg.is_empty() else PitchAvatar.random_config(seed_base * 31 + i)
		var cfg: Dictionary = PitchAvatar.with_kit(face, gk_kit if i == 0 else kit)
		p.setup(self, i, String(codes[i]), spots[i], cfg)
		p.pname = Names.short(seed_base * 131 + i)
		world.add_child(p)
		players.append(p)

func gk() -> Player:
	return players[0]

func opponents() -> Team:
	return game.teams[1 - side]

## Posición de formación según dónde está el balón y quién lo tiene.
func shape_target(p: Player, ball_pos: Vector2, in_poss: bool) -> Vector2:
	var bd: float = Cfg.depth_of(side, ball_pos)
	var bx: float = ball_pos.x / Cfg.FIELD_W
	if side == 1:
		bx = 1.0 - bx
	var shift: float = (bd - 0.45) * 0.6 + (0.12 if in_poss else -0.04)
	var d: float = p.base.y + shift
	var x: float = p.base.x + (bx - 0.5) * 0.35
	if in_poss:
		x = 0.5 + (x - 0.5) * 1.12
		if p.role == "FW":
			d += 0.06
	else:
		x = 0.5 + (x - 0.5) * 0.85
		# Los defensores no se quedan delante del balón cuando defendemos.
		if p.role == "DF":
			d = minf(d, maxf(bd - 0.06, 0.08))
	d = clampf(d, 0.05, 0.9)
	x = clampf(x, 0.05, 0.95)
	return Cfg.form_to_world(side, x, d)

## Posiciones para un saque inicial (cada uno en su campo).
func kickoff_spot(p: Player, kicking: bool) -> Vector2:
	var d: float = minf(p.base.y, 0.46)
	if p.role == "FW":
		d = 0.47 if kicking else 0.40
	var x: float = p.base.x
	return Cfg.form_to_world(side, x, d)

## Tiempo aproximado que le tomaría a p llegar al balón.
func time_to_ball(p: Player, ball: Ball) -> float:
	var t: float = 0.0
	var spot: Vector2 = ball.position
	for _i in 3:
		spot = ball.predict(t)
		t = p.position.distance_to(spot) / p.max_speed(true)
	return t + (0.4 if p.busy() else 0.0)

func best_interceptor(ball: Ball, include_gk: bool = false) -> Player:
	var best: Player = null
	var bt: float = INF
	for p in players:
		if p.is_gk() and not include_gk:
			continue
		var t: float = time_to_ball(p, ball)
		if t < bt:
			bt = t
			best = p
	return best

# ---------------------------------------------------------------- IA principal

func think(dt: float, ball: Ball, controlled: Player) -> void:
	var carrier: Player = ball.owner_p
	var we_have: bool = carrier != null and carrier.team == self
	var they_have: bool = carrier != null and carrier.team != self
	var chaser: Player = null
	var cover: Player = null
	if not we_have:
		chaser = best_interceptor(ball, _ball_in_own_box(ball))
		if they_have:
			cover = _second_closest(ball.position, chaser)
	# Pase entre compañeros en viaje: seguimos atacando (antes, en cada pase
	# todo el equipo se acomodaba para defender y volvía a salir).
	var ref: Player = carrier
	if carrier == null and ball.receiver != null and ball.receiver.team == self 			and ball.last_touch != null and ball.last_touch.team == self:
		ref = ball.receiver
	var attack_shape: bool = ref != null and ref.team == self
	var line_d: float = _line_depth(ball, carrier) if not attack_shape else 0.0
	var marked: Array = []
	for p in players:
		p.ai_cd = maxf(p.ai_cd - dt, 0.0)
		if not attack_shape:
			p.ai_run = false
	for p in players:
		if p == controlled or p.busy():
			continue
		if p == carrier:
			_carrier_ai(p, ball, dt)
			continue
		if p.is_gk():
			_gk_ai(p, ball, chaser == p)
			continue
		# El receptor de un pase va a buscarlo.
		if ball.receiver == p and ball.is_free():
			p.go_to(ball.predict(time_to_ball(p, ball)), 1.0, 0.1 * Cfg.M)
			continue
		# Un compañero parado en la línea de un pase nuestro se corre (si no,
		# la pelota le pega en el cuerpo).
		if _dodge_pass(p, ball):
			continue
		if p == chaser:
			if they_have:
				# Presiona entre el rival y nuestro arco.
				var g: Vector2 = Cfg.own_goal(side)
				# A 1,3 m: más cerca quedaban los dos sprites encimados.
				var spot: Vector2 = carrier.position + (g - carrier.position).normalized() * 1.3 * Cfg.M
				var far: bool = p.position.distance_to(spot) > 7.0 * Cfg.M
				p.go_to(spot, (0.9 if far else 0.78) * difficulty_factor(), 0.1 * Cfg.M)
			else:
				p.go_to(ball.predict(time_to_ball(p, ball)), 1.0, 0.1 * Cfg.M)
			continue
		if p == cover:
			var g2: Vector2 = Cfg.own_goal(side)
			# Pelota del rival cerca de SU arco: presión alta, el segundo tapa al
			# compañero más cercano del portador (le corta la salida).
			if they_have and Cfg.depth_of(side, ball.position) > 0.68:
				var outlet: Player = _nearest_mate_of(carrier)
				if outlet != null:
					p.go_to(outlet.position.lerp(carrier.position, 0.35), 0.9, 0.3 * Cfg.M)
					continue
			p.go_to(ball.position + (g2 - ball.position).normalized() * 5.0 * Cfg.M, 0.8)
			continue
		var t: Vector2 = shape_target(p, ref.position if attack_shape else ball.position, attack_shape)
		var urg: float = 0.55
		if attack_shape:
			var ov: Vector2 = _overlap_spot(p, ref)
			if ov != Vector2.INF:
				t = ov
				p.ai_run = true
			elif p.code == "MCD" and Cfg.depth_of(side, ref.position) > 0.4:
				# Ancla: detrás de la jugada y por el medio, para el pase atrás
				# y para cortar la contra si se pierde la pelota.
				t = ref.position - Cfg.attack_dir(side) * 11.0 * Cfg.M
				t.x = lerpf(t.x, Cfg.FIELD_W * 0.5, 0.5)
			elif p.role != "DF" or Cfg.depth_of(side, ref.position) > 0.62:
				t = _attack_spot(p, ref, t + (_support_offset(p, ref) if p.role != "DF" else Vector2.ZERO))
			if p.ai_run:
				urg = 1.0
			elif p.position.distance_to(t) > 6.0 * Cfg.M:
				urg = 0.8
		else:
			t = _defend_spot(p, t, line_d, marked)
			if p.position.distance_to(t) > 5.0 * Cfg.M:
				urg = 0.8
		p.go_to(t, urg, 0.8 * Cfg.M)
		if p.want.length() < 1.0:
			p.face(ball.position - p.position)
		if we_have and carrier != null:
			_maybe_ask(p, carrier)

func _dodge_pass(p: Player, ball: Ball) -> bool:
	if not ball.is_free() or ball.receiver == null or ball.receiver == p or ball.receiver.team != self:
		return false
	if ball.vel.length() < 3.0 * Cfg.M or ball.z > 1.9 * Cfg.M:
		return false
	var a: Vector2 = ball.position
	var b: Vector2 = ball.receiver.position
	var q: Vector2 = Geometry2D.get_closest_point_to_segment(p.position, a, b)
	var d: float = q.distance_to(p.position)
	if d > 1.8 * Cfg.M or q.distance_to(b) < 1.0 * Cfg.M:
		return false
	var perp: Vector2 = (b - a).orthogonal().normalized()
	if (p.position - q).dot(perp) < 0.0:
		perp = -perp
	p.want = perp * p.max_speed(true)
	return true

## Levanta la mano pidiéndola si está libre, con línea limpia y de frente
## al que la tiene (el gesto está dibujado de frente: el portador abajo).
func _maybe_ask(p: Player, carrier: Player) -> void:
	if p.gesture_cd > 0.0 or p.human or p.is_gk() or p.ai_run:
		return
	var to: Vector2 = carrier.position - p.position
	var d: float = to.length()
	if d < 7.0 * Cfg.M or d > 30.0 * Cfg.M or to.y < d * 0.35:
		return
	if _nearest_opp_dist(p.position) < 4.5 * Cfg.M or _lane_free(carrier.position, p.position) < 1.6 * Cfg.M:
		return
	if randf() < 0.012:
		p.face(to)
		p.play_gesture("pitch_pide", 1.1, randf_range(3.5, 6.0))

func difficulty_factor() -> float:
	return 1.0 if is_human else difficulty

func _ball_in_own_box(ball: Ball) -> bool:
	var g: Vector2 = Cfg.own_goal(side)
	return absf(ball.position.x - g.x) < Cfg.BOX_W * 0.5 and absf(ball.position.y - g.y) < Cfg.BOX_H

func _second_closest(pos: Vector2, skip: Player) -> Player:
	var best: Player = null
	var bd: float = INF
	for p in players:
		if p == skip or p.is_gk():
			continue
		var d: float = p.position.distance_squared_to(pos)
		if d < bd:
			bd = d
			best = p
	return best

## Profundidad (0..1 desde nuestro arco) de la última línea de los rivales
## (el penúltimo hombre: la línea del offside).
func offside_depth() -> float:
	var ds: Array = []
	for o in opponents().players:
		ds.append(Cfg.depth_of(side, o.position))
	ds.sort()
	ds.reverse()
	return ds[1] if ds.size() > 1 else 1.0

## ¿Está `p` en fuera de juego si se la pasan ahora desde `ball_pos`? En
## campo rival, más adelante que la pelota y que el penúltimo rival (con
## medio metro de margen: el juez de línea no cobra los milimétricos).
func is_offside(p: Player, ball_pos: Vector2) -> bool:
	if p.is_gk():
		return false
	var d: float = Cfg.depth_of(side, p.position)
	if d < 0.5 or d <= Cfg.depth_of(side, ball_pos):
		return false
	return (d - offside_depth()) * Cfg.FIELD_H > 0.5 * Cfg.M

## Desmarque: busca cerca de su puesto el lugar con más aire y línea de pase
## limpia desde el portador. Los delanteros, si el portador levanta la
## cabeza, pican a la espalda de la defensa (sin quedar en offside al salir).
func _attack_spot(p: Player, carrier: Player, base_t: Vector2) -> Vector2:
	var M: float = Cfg.M
	var off_d: float = offside_depth()
	var cd: float = Cfg.depth_of(side, carrier.position)
	# Quedó adelantado sin picada: vuelve a ponerse en línea (habilitado).
	if not p.ai_run and is_offside(p, carrier.position):
		var back: Vector2 = p.position - Cfg.attack_dir(side) * 2.5 * Cfg.M
		p.ai_spot = back
		p.ai_cd = 0.4
		return back
	if p.ai_cd > 0.0 and p.ai_spot != Vector2.INF:
		# Una picada termina si ya pasó la línea y el balón no vino.
		if p.ai_run and Cfg.depth_of(side, p.position) > off_d + 0.1:
			p.ai_run = false
			p.ai_cd = 0.0
		else:
			return p.ai_spot
	p.ai_cd = randf_range(0.5, 0.9)
	p.ai_run = false
	var fwd: Vector2 = Cfg.attack_dir(side)
	# Pelota en la banda cerca del área: a atacar el área (primer palo,
	# segundo palo, punto penal) y uno en la puerta para el pase atrás.
	var box_spot: Vector2 = _box_attack_spot(p, carrier)
	if box_spot != Vector2.INF:
		p.ai_spot = box_spot
		p.ai_run = p.position.distance_to(box_spot) > 4.0 * M
		p.ai_cd = 0.6
		return box_spot
	var my_d: float = Cfg.depth_of(side, p.position)
	var pressed: bool = _nearest_opp_dist(carrier.position) < 3.0 * M
	# Picada al espacio: delantero (o volante llegador) cerca de la línea.
	if (p.role == "FW" or (p.role == "MF" and randf() < 0.3)) and not pressed and cd > 0.25 \
			and my_d > off_d - 0.12 and off_d < 0.9 and randf() < 0.6:
		var goal: Vector2 = Cfg.target_goal(side)
		var line_y: float = Cfg.form_to_world(side, 0.5, off_d).y
		var spot := Vector2(lerpf(p.position.x, goal.x, 0.35), line_y) + fwd * 9.0 * M
		spot.x = clampf(spot.x, 4.0 * M, Cfg.FIELD_W - 4.0 * M)
		spot.y = clampf(spot.y, 6.0 * M, Cfg.FIELD_H - 6.0 * M)
		p.ai_run = true
		p.ai_spot = spot
		p.ai_cd = 2.2
		return spot
	var best: Vector2 = base_t
	var best_s: float = -INF
	for ring in [0.0, 4.5, 8.0]:
		var n: int = 1 if ring == 0.0 else 8
		for k in n:
			var c: Vector2 = base_t + Vector2.RIGHT.rotated(TAU * k / n + 0.4) * ring * M
			c.x = clampf(c.x, 2.0 * M, Cfg.FIELD_W - 2.0 * M)
			c.y = clampf(c.y, 3.0 * M, Cfg.FIELD_H - 3.0 * M)
			var cdep: float = Cfg.depth_of(side, c)
			var s: float = clampf(_nearest_opp_dist(c) / (7.0 * M), 0.0, 1.0) * 1.6
			s += clampf(_lane_free(carrier.position, c) / (3.0 * M), 0.0, 1.0) * 1.2
			s += (cdep - my_d) * 1.5
			s -= c.distance_to(base_t) / (10.0 * M) * 0.6
			if cdep > off_d + 0.01 and cdep > cd:
				s -= 2.5   # quedaría en offside
			var cdist: float = c.distance_to(carrier.position)
			if cdist < 6.0 * M:
				s -= 1.0
			elif cdist > 32.0 * M:
				s -= 0.8
			for m in players:
				if m != p and m != carrier and not m.is_gk():
					var ref: Vector2 = m.ai_spot if m.ai_spot != Vector2.INF else m.position
					if ref.distance_to(c) < 6.0 * M:
						s -= 0.7
			if s > best_s:
				best_s = s
				best = c
	p.ai_spot = best
	return best

func _box_attack_spot(p: Player, carrier: Player) -> Vector2:
	var cx: float = carrier.position.x / Cfg.FIELD_W
	var cd: float = Cfg.depth_of(side, carrier.position)
	if absf(cx - 0.5) < 0.22 or cd < 0.66 or p.role == "DF":
		return Vector2.INF
	# El orden: delanteros primero, después los volantes más adelantados.
	var cand: Array = []
	for m in players:
		if m != carrier and not m.is_gk() and m.role != "DF":
			cand.append(m)
	cand.sort_custom(func(a, b): return (0 if a.role == "FW" else 1) * 10.0 - Cfg.depth_of(side, a.position) < (0 if b.role == "FW" else 1) * 10.0 - Cfg.depth_of(side, b.position))
	var i: int = cand.find(p)
	if i < 0 or i > 3:
		return Vector2.INF
	# En coordenadas de cancha: sg = lado de la pelota.
	var sg: float = signf(cx - 0.5)
	var spots: Array = [[0.5 + 0.07 * sg, 0.95], [0.5 - 0.09 * sg, 0.94], [0.5, 0.9], [0.5 - 0.06 * sg, 0.82]]
	var sp: Array = spots[i]
	# En línea con el último defensor (o con la pelota): entrar antes del
	# centro es quedar en offside.
	var dd: float = minf(float(sp[1]), maxf(offside_depth() - 0.006, cd))
	return Vector2(Cfg.FIELD_W * float(sp[0]), Cfg.form_to_world(side, 0.5, dd).y)

## Línea defensiva: los defensores comparten una sola profundidad. Sube cuando
## el balón está lejos o va hacia atrás; baja si el portador tiene espacio de
## frente a nuestro arco (para que no les piquen a la espalda).
func _line_depth(ball: Ball, carrier: Player) -> float:
	var bd: float = Cfg.depth_of(side, ball.position)
	var sum: float = 0.0
	var n: int = 0
	for p in players:
		if p.role == "DF":
			sum += p.base.y
			n += 1
	var d: float = (sum / maxf(n, 1)) + (bd - 0.45) * 0.75 + 0.06
	if carrier != null and carrier.team != self:
		var to_goal: Vector2 = (Cfg.own_goal(side) - carrier.position).normalized()
		var free: bool = _nearest_mate_dist(carrier.position) > 4.0 * Cfg.M
		if free and carrier.facing.dot(to_goal) > 0.5:
			d -= 0.05
	d = minf(d, maxf(bd - 0.07, 0.07))
	return clampf(d, 0.07, 0.5)

const FULLBACKS := ["LI", "LD", "CAI", "CAD"]

## Lateral que pasa al ataque: la pelota va por su banda en campo rival y
## el que la tiene es un compañero de adelante; corre por afuera a pasarlo.
## (Uno solo a la vez, y no si quedan menos de 2 defensores atrás.)
func _overlap_spot(p: Player, ref: Player) -> Vector2:
	if not p.code in FULLBACKS or ref == p or ref.role == "DF" or ref.human:
		return Vector2.INF
	var my_side: float = signf(p.base.x - 0.5)
	var rx: float = ref.position.x / Cfg.FIELD_W
	if side == 1:
		rx = 1.0 - rx
	if signf(rx - 0.5) != my_side or absf(rx - 0.5) < 0.18 or Cfg.depth_of(side, ref.position) < 0.5:
		return Vector2.INF
	var backs: int = 0
	for m in players:
		if m.role == "DF" and m != p and not m.ai_run:
			backs += 1
		elif m.code in FULLBACKS and m != p and m.ai_run:
			return Vector2.INF
	if backs < 2:
		return Vector2.INF
	var fwd: Vector2 = Cfg.attack_dir(side)
	var wide_x: float = Cfg.FIELD_W * (0.5 + my_side * 0.44 * (1.0 if side == 0 else -1.0))
	var spot := Vector2(wide_x, (ref.position + fwd * 9.0 * Cfg.M).y)
	spot.y = clampf(spot.y, 6.0 * Cfg.M, Cfg.FIELD_H - 6.0 * Cfg.M)
	return spot

## El compañero del portador más cercano (su salida de pase).
func _nearest_mate_of(c: Player) -> Player:
	var best: Player = null
	var bd: float = INF
	for o in c.team.players:
		if o == c or o.is_gk():
			continue
		var d: float = o.position.distance_to(c.position)
		if d < bd:
			bd = d
			best = o
	return best

func _nearest_mate_dist(pos: Vector2) -> float:
	var best: float = INF
	for m in players:
		if not m.is_gk():
			best = minf(best, m.position.distance_to(pos))
	return best

## Sin balón: defensores en línea; todos marcan (del lado del arco) al rival
## libre más cercano a su zona.
func _defend_spot(p: Player, t: Vector2, line_d: float, marked: Array) -> Vector2:
	var M: float = Cfg.M
	var g: Vector2 = Cfg.own_goal(side)
	if p.role == "DF":
		t = Vector2(t.x, Cfg.form_to_world(side, 0.5, line_d).y)
	elif p.code == "MCD":
		# Ancla: unos 9 m delante de la línea, entre la pelota y el arco.
		var bpos: Vector2 = Player.ball_at if Player.ball_at != Vector2.INF else t
		var g0: Vector2 = Cfg.own_goal(side)
		var yy: float = Cfg.form_to_world(side, 0.5, minf(line_d + 0.09, 0.62)).y
		var k: float = (yy - g0.y) / (bpos.y - g0.y) if absf(bpos.y - g0.y) > 1.0 else 0.5
		t = Vector2(lerpf(g0.x, bpos.x, clampf(k, 0.0, 1.0)), yy)
	var near: Player = null
	var nd: float = (9.0 if p.role != "FW" else 6.0) * M
	for o in opponents().players:
		if o.is_gk() or marked.has(o):
			continue
		var d: float = o.position.distance_to(t)
		if d < nd:
			nd = d
			near = o
	if near == null:
		return t
	marked.append(near)
	var mark: Vector2 = near.position + (g - near.position).normalized() * 1.8 * M
	if p.role == "DF":
		# Sigue al hombre de costado; en profundidad solo baja (no sale de la línea).
		var od: float = Cfg.depth_of(side, mark)
		var x: float = lerpf(t.x, mark.x, 0.65)
		var dd: float = minf(line_d, od)
		return Vector2(x, Cfg.form_to_world(side, 0.5, dd).y)
	return t.lerp(mark, 0.6)

## Los compañeros se abren para dar línea de pase y los delanteros pican.
func _support_offset(p: Player, carrier: Player) -> Vector2:
	var away: Vector2 = p.position - carrier.position
	var off := Vector2.ZERO
	if away.length() < 7.0 * Cfg.M:
		off += away.normalized() * 4.0 * Cfg.M
	if p.role == "FW":
		off += Cfg.attack_dir(side) * 4.0 * Cfg.M
	return off

# ---------------------------------------------------------------- portador CPU

func _carrier_ai(p: Player, ball: Ball, _dt: float) -> void:
	if p.is_gk():
		if p.think_cd <= 0.0:
			_distribute_gk(p, ball)
		else:
			p.want = Vector2.ZERO
		return
	var goal: Vector2 = Cfg.target_goal(side)
	if p.think_cd <= 0.0:
		p.think_cd = randf_range(0.25, 0.45) / difficulty_factor() / (0.7 + p.st("decision_making") / 100.0 * 0.6)
		var dist: float = p.position.distance_to(goal)
		var press: float = _nearest_opp_dist(p.position)
		var my_d: float = Cfg.depth_of(side, p.position)
		var shoot_p: float = clampf((25.0 * Cfg.M - dist) / (12.0 * Cfg.M), 0.0, 0.95)
		# Arco tapado (cuerpos en la línea de tiro) y lejos: mejor no rematar.
		if dist > 11.0 * Cfg.M and _lane_free(p.position, goal) < 0.9 * Cfg.M:
			shoot_p *= 0.3
		if dist < 25.0 * Cfg.M and randf() < shoot_p:
			game.cpu_shoot(p)
			return
		# Defensor presionado en su tercio: nada de gambetas. Pase seguro o
		# la revienta para adelante.
		if p.role == "DF" and my_d < 0.3 and press < 4.0 * Cfg.M:
			var safe: Dictionary = best_pass(p)
			if not safe.is_empty() and safe.score > -0.5 and randf() < 0.75:
				game.do_pass(p, safe.target, safe.lob)
			else:
				var clr: Vector2 = (Cfg.attack_dir(side) + Vector2(signf(p.position.x - Cfg.FIELD_W * 0.5) * 0.7, 0)).normalized()
				game.kick_ball(p, clr * 22.0 * Cfg.M, 8.0 * Cfg.M, 0.0, "lob", null, "remate")
			return
		# Delantero de espaldas al arco y presionado: descarga para atrás.
		if p.role == "FW" and press < 2.5 * Cfg.M and p.facing.dot((goal - p.position).normalized()) < -0.2:
			var lay: Dictionary = best_pass(p, -Cfg.attack_dir(side))
			if not lay.is_empty() and randf() < 0.6:
				game.do_pass(p, lay.target, false)
				return
		var dribble_p: float = {"FW": 0.32, "MF": 0.22, "DF": 0.1}.get(p.role, 0.22) * (0.6 + p.st("dribbling") / 100.0 * 0.8)
		if press < 2.2 * Cfg.M and p.regate_t <= 0.0 and randf() < dribble_p:
			var near: Player = null
			var nd: float = INF
			for o in opponents().players:
				var od: float = o.position.distance_to(p.position)
				if od < nd:
					nd = od
					near = o
			var side_dir: Vector2 = p.facing.orthogonal()
			if near != null and (near.position - p.position).dot(side_dir) > 0.0:
				side_dir = -side_dir
			p.start_regate(side_dir)
			return
		# Un compañero picando a la espalda de la defensa: pase al espacio.
		if press > 1.6 * Cfg.M:
			for r in players:
				if r.ai_run and r != p and not r.human and not is_offside(r, p.position) and randf() < 0.55:
					var lead: Vector2 = r.position + r.vel * 0.7
					if p.position.distance_to(lead) < 34.0 * Cfg.M:
						game.do_pass(p, r, _lane_free(p.position, lead) < 1.4 * Cfg.M)
						r.ai_run = false
						return
		var opt: Dictionary = best_pass(p)
		if not opt.is_empty() and ask_pass > 0.0 and opt.target.human:
			ask_pass = 0.0
			game.do_pass(p, opt.target, opt.lob)
			return
		if not opt.is_empty():
			var pass_chance: float = 0.0
			if press < 2.2 * Cfg.M:
				pass_chance = 0.7 if opt.score > -0.3 else 0.2
			elif opt.score > 0.9:
				pass_chance = 0.35
			elif opt.score > 0.5:
				pass_chance = 0.12
			# Los defensores prefieren pasarla; los delanteros, encarar.
			pass_chance *= {"DF": 1.6, "MF": 1.0, "FW": 0.75}.get(p.role, 1.0)
			if randf() < pass_chance:
				game.do_pass(p, opt.target, opt.lob)
				return
		_dribble_dir = _dribble_direction(p, goal)
	# Con espacio por delante, acelera.
	var space: bool = true
	for o in opponents().players:
		var v: Vector2 = o.position - p.position
		if v.length() < 5.0 * Cfg.M and v.normalized().dot(_dribble_dir) > 0.3:
			space = false
			break
	p.want = _dribble_dir * p.max_speed(space)

func _dribble_direction(p: Player, goal: Vector2) -> Vector2:
	var dir: Vector2 = (goal - p.position).normalized()
	for o in opponents().players:
		var v: Vector2 = p.position - o.position
		var d: float = v.length()
		if d < 6.0 * Cfg.M and d > 0.01:
			var ahead: float = (o.position - p.position).normalized().dot(dir)
			if ahead > -0.2:
				dir += v / d * (6.0 * Cfg.M - d) / (6.0 * Cfg.M) * 1.6
	# No irse por la banda.
	if p.position.x < 4.0 * Cfg.M:
		dir.x += 0.8
	elif p.position.x > Cfg.FIELD_W - 4.0 * Cfg.M:
		dir.x -= 0.8
	return dir.normalized()

func _nearest_opp_dist(pos: Vector2) -> float:
	var best: float = INF
	for o in opponents().players:
		best = minf(best, o.position.distance_to(pos))
	return best

## Mejor opción de pase: avanza, está libre y no muy lejos.
func best_pass(p: Player, dir_hint: Vector2 = Vector2.ZERO) -> Dictionary:
	var best: Dictionary = {}
	var best_s: float = -INF
	for t in players:
		if t == p or (t.is_gk() and dir_hint == Vector2.ZERO):
			continue
		var to: Vector2 = t.position - p.position
		var dist: float = to.length()
		if dist < 4.0 * Cfg.M or dist > 38.0 * Cfg.M:
			continue
		if not p.human and is_offside(t, p.position):
			continue
		var gain: float = Cfg.depth_of(side, t.position) - Cfg.depth_of(side, p.position)
		var lane: float = _lane_free(p.position, t.position)
		var near: float = _nearest_opp_dist(t.position)
		var s: float = gain * 3.0 + clampf(near / (6.0 * Cfg.M), 0.0, 1.0) * 1.2 - dist / (40.0 * Cfg.M) * 0.6
		# Riesgo del carril: cuanto más largo el pase, más libre tiene que
		# estar (un rival a 2,5 m de un pase de 30 m lo corta). Antes el
		# avance (gain) mandaba y elegía pelotazos de 30 m a un extremo
		# marcado: se perdían casi todos.
		var need: float = 0.9 * Cfg.M + dist * 0.11
		if lane < need:
			s -= (1.0 - lane / need) * 4.0
		# El momento es del usuario: los compañeros lo buscan a él.
		if t.human and lane > 1.0 * Cfg.M:
			s += 0.7 + (3.0 if ask_pass > 0.0 else 0.0)
		if dir_hint != Vector2.ZERO:
			var ang: float = absf(dir_hint.angle_to(to))
			if ang > 1.0:
				continue
			s = (1.0 - ang) * 3.0 - dist / (40.0 * Cfg.M) + clampf(lane / (3.0 * Cfg.M), 0.0, 1.0)
		elif lane < 1.0 * Cfg.M and dist < 12.0 * Cfg.M:
			s -= 1.5
		if s > best_s:
			best_s = s
			best = {"target": t, "score": s, "lob": lane < 1.0 * Cfg.M and dist > 16.0 * Cfg.M}
	return best

## Distancia del rival más cercano a la línea de pase.
func _lane_free(a: Vector2, b: Vector2) -> float:
	var best: float = INF
	for o in opponents().players:
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(o.position, a, b)
		best = minf(best, q.distance_to(o.position))
	return best

# ---------------------------------------------------------------- arquero

func _gk_ai(p: Player, ball: Ball, is_chaser: bool) -> void:
	var g: Vector2 = Cfg.own_goal(side)
	var out: Vector2 = Cfg.attack_dir(side)
	p.alert = false
	if p.down_t > 0.0:
		p.want = Vector2.ZERO
		return
	# Recién superado por un remate: no persigue la pelota que ya pasó.
	if p.no_touch > 0.0 and ball.is_free() and ball.kind == "shot":
		p.want = Vector2.ZERO
		return
	var carrier: Player = ball.owner_p
	var rival_ball: bool = carrier != null and carrier.team != self
	# Achique a los pies: el delantero se le viene encima con la pelota.
	if rival_ball and p.position.distance_to(carrier.ball_spot()) < 2.3 * Cfg.M and carrier.position.distance_to(g) < 18.0 * Cfg.M and p.smother_t <= 0.0:
		p.start_smother(carrier.ball_spot() - p.position)
		return
	# Tiro viniendo: se mueve al punto donde cruzará su línea (o se tira).
	var toward: float = ball.vel.dot(-out)
	if ball.is_free() and toward > 8.0 * Cfg.M:
		var dy: float = absf(p.position.y - ball.position.y)
		var t: float = dy / maxf(absf(ball.vel.y), 1.0)
		if t < 1.2:
			var px: float = ball.position.x + ball.vel.x * t
			px = clampf(px, g.x - Cfg.GOAL_W * 0.6, g.x + Cfg.GOAL_W * 0.6)
			var dx: float = px - p.position.x
			# Tiempo de reacción: un arquero no se tira en el mismo instante del remate.
			var react: float = 0.12 + (1.0 - p.skill) * 0.18
			var zt: float = ball.z + ball.vz * t - 0.5 * Cfg.GRAVITY * t * t
			if game.now - ball.kick_time > react and absf(dx) > 1.2 * Cfg.M and t < 0.45 and absf(dx) < Cfg.GK_DIVE_REACH + Cfg.GK_DIVE_SPEED * t:
				p.start_dive(dx, zt > Cfg.GOAL_H_Z * 0.62)
				return
			# Antes de reaccionar se queda plantado; después, pasos laterales
			# cortos (un arquero no corre de costado a 7 m/s: si no llega, se tira).
			p.alert = true
			if game.now - ball.kick_time <= react:
				p.want = Vector2.ZERO
				return
			p.go_to(Vector2(px, p.position.y), 1.0, 0.1 * Cfg.M)
			p.want = p.want.limit_length(3.0 * Cfg.M)
			_keep_in_front(p)
			return
	# Centro / pelota aérea que cae en su área chica: sale a cortarla.
	if ball.is_free() and ball.z > 1.0 * Cfg.M and ball.kind in ["lob", "cross"] and (ball.last_touch == null or ball.last_touch.team != self):
		var land: Vector2 = _landing(ball)
		var lg: Vector2 = land - g
		if absf(lg.y) < 7.0 * Cfg.M and absf(lg.x) < 9.0 * Cfg.M:
			var mine: float = p.position.distance_to(land) / p.max_speed(true)
			var theirs: float = INF
			for o in opponents().players:
				theirs = minf(theirs, o.position.distance_to(land) / o.max_speed(true))
			if mine < theirs + 0.35:
				p.rush = true
				p.go_to(land, 1.0, 0.1 * Cfg.M)
				return
	# Pase al espacio / pelota suelta hacia su arco que él alcanza antes que
	# cualquier rival: sale (fuera del área la juega con los pies).
	var our_pass: bool = ball.last_touch != null and ball.last_touch.team == self and ball.receiver != null and ball.receiver != p
	if ball.is_free() and ball.z < 1.2 * Cfg.M and not our_pass and (is_chaser or ball.vel.dot(-out) > 3.0 * Cfg.M):
		var t_me: float = time_to_ball(p, ball)
		var spot_b: Vector2 = ball.predict(t_me)
		if spot_b.distance_to(g) < 26.0 * Cfg.M:
			var t_opp: float = INF
			for o in opponents().players:
				t_opp = minf(t_opp, time_to_ball(o, ball))
			if t_me + 0.25 < t_opp or (is_chaser and _ball_in_own_box(ball)):
				p.rush = true
				p.go_to(spot_b, 1.0, 0.1 * Cfg.M)
				_keep_in_front(p)
				return
	p.rush = false
	var to_ball: Vector2 = ball.position - g
	var dist: float = to_ball.length()
	# Mano a mano: el delantero se fue solo hacia el arco (ningún defensor
	# entre él y el arco): sale a achicarle el ángulo, a 3-4 m de la pelota.
	if rival_ball and dist < 24.0 * Cfg.M and _alone(carrier, g):
		p.rush = true
		p.alert = true
		var close: Vector2 = carrier.ball_spot() + (g - carrier.ball_spot()).normalized() * 3.2 * Cfg.M
		if close.distance_to(g) > dist * 0.75:
			close = g + to_ball.normalized() * dist * 0.75
		p.go_to(close, 1.0, 0.3 * Cfg.M)
		_keep_in_front(p)
		return
	# Cubrir el ángulo: sobre la línea balón-centro del arco. Con la pelota
	# lejos (campo rival) se adelanta como líbero; con un rival armando el
	# remate cerca, se planta y espera en guardia (no camina al patear).
	var adv: float = clampf(dist * 0.1, 0.8 * Cfg.M, 3.5 * Cfg.M)
	if dist > 45.0 * Cfg.M:
		adv = lerpf(3.5 * Cfg.M, 12.0 * Cfg.M, clampf((dist - 45.0 * Cfg.M) / (30.0 * Cfg.M), 0.0, 1.0))
	var spot: Vector2 = g + to_ball.normalized() * adv
	spot.x = clampf(spot.x, g.x - Cfg.GOAL_W * 0.55, g.x + Cfg.GOAL_W * 0.55)
	var danger: bool = rival_ball and dist < 28.0 * Cfg.M
	p.alert = danger or (ball.is_free() and dist < 20.0 * Cfg.M)
	var urg: float = 0.45 if danger else 0.7
	if danger and carrier.facing.dot((g - carrier.position).normalized()) > 0.6 and dist < 22.0 * Cfg.M:
		urg = 0.3   # se planta: pasos cortos, listo para tirarse
	p.go_to(spot, urg, 0.3 * Cfg.M)
	if p.want.length() < 1.0:
		p.face(ball.position - p.position)

## Dónde cae una pelota aérea (al bajar a 2 m).
func _landing(ball: Ball) -> Vector2:
	var vz: float = ball.vz
	var z: float = ball.z
	var pos: Vector2 = ball.position
	var v: Vector2 = ball.vel
	for _i in 60:
		vz -= Cfg.GRAVITY / 30.0
		z += vz / 30.0
		pos += v / 30.0
		if vz < 0.0 and z < 2.0 * Cfg.M:
			break
	return pos

## ¿El portador quedó solo frente al arco (ningún defensor delante)?
func _alone(c: Player, g: Vector2) -> bool:
	var to_g: Vector2 = g - c.position
	var d: float = to_g.length()
	for m in players:
		if m.is_gk():
			continue
		var rel: Vector2 = m.position - c.position
		var along: float = rel.dot(to_g / d)
		if along > 0.0 and along < d and absf(rel.cross(to_g / d)) < 4.0 * Cfg.M:
			return false
	return true

## El arquero nunca camina hacia adentro de su propio arco.
func _keep_in_front(p: Player) -> void:
	var line_y: float = Cfg.own_goal(side).y
	var inside: float = (p.position.y - line_y) * Cfg.attack_dir(side).y   # >0 = en la cancha
	if inside < 0.6 * Cfg.M and p.want.dot(Cfg.attack_dir(side)) < 0.0:
		p.want -= Cfg.attack_dir(side) * p.want.dot(Cfg.attack_dir(side))

func _distribute_gk(p: Player, ball: Ball) -> void:
	p.want = Vector2.ZERO
	var opt: Dictionary = best_pass(p)
	# Con la pelota en los pies (cesión, fuera del área): pase o despeje.
	if not p.holding:
		if not opt.is_empty() and opt.score > 0.3 and _nearest_opp_dist(p.position) > 3.0 * Cfg.M:
			game.do_pass(p, opt.target, opt.target.position.distance_to(p.position) > 22.0 * Cfg.M)
		else:
			var dir0: Vector2 = (Cfg.attack_dir(side) + Vector2(randf_range(-0.5, 0.5), 0)).normalized()
			game.kick_ball(p, dir0 * 24.0 * Cfg.M, 8.0 * Cfg.M, 0.0, "lob", null, "remate")
		ball.kick_time = game.now
		return
	if not opt.is_empty() and opt.score > 0.0 and randf() < 0.7:
		game.do_pass(p, opt.target, opt.target.position.distance_to(p.position) > 18.0 * Cfg.M)
	else:
		# Despeje largo hacia adelante.
		var dir: Vector2 = (Cfg.attack_dir(side) + Vector2(randf_range(-0.4, 0.4), 0)).normalized()
		game.kick_ball(p, dir * 24.0 * Cfg.M, 9.0 * Cfg.M, 0.0, "lob", null, "saque_largo")
	ball.kick_time = game.now

## Plantilla real (FootballLegacy): cada entrada {code, cfg, name, number,
## stats}. El arquero (POR) tiene que venir primero.
func _build_roster(world: Node2D, roster: Array) -> void:
	var codes: Array = []
	for r in roster:
		codes.append(String(r.get("code", "MC")))
	var spots: Array = PitchFormations.layout_codes(codes)
	for i in roster.size():
		var r: Dictionary = roster[i]
		var p := Player.new()
		p.setup(self, i, codes[i], spots[i], r.get("cfg", {}))
		p.number = int(r.get("number", i + 1))
		p.pname = String(r.get("name", ""))
		p.apply_stats(r.get("stats", {}))
		world.add_child(p)
		players.append(p)
