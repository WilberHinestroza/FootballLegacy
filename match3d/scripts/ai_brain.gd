class_name AiBrain
extends RefCounted
## IA sencilla por reglas. Cada frame decide hacia dónde se mueve un jugador
## y, con un pequeño retraso, si chuta, pasa o hace una entrada.
## P1-33/P1-34: las probabilidades y distancias salen de AiTuning, que las
## deriva de los atributos del jugador (passing, shooting, lectura, sangre fría).

const AiTuning = preload("res://engine/match/m3d/AiTuning.gd")
const Offside = preload("res://engine/match/m3d/Offside.gd")
const DribbleCombo = preload("res://engine/match/m3d/DribbleCombo.gd")


static func think(p: SoccerPlayer, m: SoccerMatch) -> void:
	p.sprinting = false
	if p.is_keeper:
		_keeper(p, m)
		return
	var holder := m.ball.owner_player
	if holder == p:
		_with_ball(p, m)
	elif holder != null and holder.team == p.team:
		_support(p, m, holder)
	elif holder != null:
		_defend(p, m, holder)
	else:
		_loose_ball(p, m)


static func move_to(p: SoccerPlayer, target: Vector3, stop_dist := 0.4, sprint := false) -> void:
	var to := SoccerMatch.flat(target - p.global_position)
	var d := to.length()
	if d < stop_dist or d < 0.01:
		p.move_input = Vector3.ZERO
		return
	p.move_input = to / d * clampf(d / 1.5, 0.3, 1.0)
	p.sprinting = sprint and d > 3.0


## El medio más cercano se ofrece corto; el resto conserva su dibujo táctico.
static func _support(p: SoccerPlayer, m: SoccerMatch, holder: SoccerPlayer) -> void:
	# Tras dártela, el pasador sigue la jugada: arranca al hueco para la devolución
	if p.has_meta("run_until") and Time.get_ticks_msec() < int(p.get_meta("run_until")):
		move_to(p, _hold_onside(p, m, p.get_meta("run_to") as Vector3), 0.6, true)
		return
	var offers := false
	if p.role == "MF" and m.state == SoccerMatch.State.SIMULATING:
		var best_d := INF
		for mate: SoccerPlayer in m.teams[p.team]:
			if mate == holder or mate.is_keeper:
				continue
			best_d = minf(best_d, SoccerMatch.flat_dist(mate.global_position, holder.global_position))
		offers = SoccerMatch.flat_dist(p.global_position, holder.global_position) <= best_d + 0.01
	if offers:
		var own_goal := m.goal_center(p.team)
		var ahead := SoccerMatch.flat(m.opponent_goal_center(p.team) - holder.global_position).normalized()
		var behind := SoccerMatch.flat(own_goal - holder.global_position).normalized()
		var offer := holder.global_position + ahead * AiTuning.support_distance(
			p.stat("passing"), p.stat("decision_making")) + behind * 1.5
		# Si el punto de ofrecimiento está demasiado cerca de un rival, desplazar
		# lateralmente para ofrecer en espacio libre (evita pases forzados).
		var nearest_opp := m.nearest_opponent_distance(p, offer)
		if nearest_opp < 2.5:
			var side := 1.0 if offer.z >= 0.0 else -1.0
			offer.z += side * 4.0
			offer.z = clampf(offer.z, -SoccerMatch.FIELD_WIDTH * 0.5 + 2.0, SoccerMatch.FIELD_WIDTH * 0.5 - 2.0)
		if absf(offer.z) < SoccerMatch.FIELD_WIDTH * 0.5 - 2.0 and absf(offer.x) < SoccerMatch.FIELD_LENGTH * 0.5 - 2.0:
			move_to(p, _hold_onside(p, m, offer), 0.6, false)
			return
	if p.role == "ST" and not p.is_human:
		var run := _run_in_behind(p, m, holder)
		if run != Vector3.INF:
			move_to(p, _hold_onside(p, m, run), 0.5, true)
			return
	# Lateral que dobla por fuera al compañero que avanza por su banda
	var lap := _overlap_run(p, m, holder)
	if lap != Vector3.INF:
		move_to(p, _hold_onside(p, m, lap), 0.6, true)
		return
	# Tercer hombre: el segundo mediocentro llega al borde del área para el pase
	# atrás. Da una opción más al que lleva el balón y variedad al ataque.
	var late := _late_run(p, m, holder)
	if late != Vector3.INF:
		move_to(p, _hold_onside(p, m, late), 0.5, true)
		return
	move_to(p, _hold_onside(p, m, m.formation_target(p)), 0.6, true)


## Fuera de juego: sin balón, el atacante no sube más allá de la línea (espera el
## pase en ella). El error de cada uno sale de su lectura y se vuelve a sortear cada
## pocos segundos: los que leen mal a veces se quedan adelantados.
static func _hold_onside(p: SoccerPlayer, m: SoccerMatch, target: Vector3) -> Vector3:
	if p.is_human:
		return target
	var dir := m.attack_dir(p.team)
	var line := m.offside_line_world(p.team) * dir
	var now := Time.get_ticks_msec()
	if now - int(p.get_meta("offside_ms", -100000)) > 3000:
		p.set_meta("offside_ms", now)
		p.set_meta("offside_slack", AiTuning.offside_slack(p.stat("decision_making"), randf()))
	var limit := Offside.hold_x(line, float(p.get_meta("offside_slack", -0.5)))
	if target.x * dir > limit:
		target.x = limit * dir
	return target


## Subida del lateral: si un compañero conduce por su banda en campo rival, el
## defensa de ese lado (solo uno, el más abierto) dobla por fuera pegado a la
## cal. Nunca con el equipo atrincherado defendiendo una ventaja.
static func _overlap_run(p: SoccerPlayer, m: SoccerMatch, holder: SoccerPlayer) -> Vector3:
	if p.is_human or p.role != "DF" or m.state != SoccerMatch.State.SIMULATING:
		return Vector3.INF
	if m.team_mentality(p.team) < -2.0:
		return Vector3.INF
	var dir := m.attack_dir(p.team)
	var hz := holder.global_position.z
	if holder.global_position.x * dir < 4.0 or absf(hz) < 6.0:
		return Vector3.INF # balón por el centro o todavía en campo propio
	var side := signf(hz)
	# El defensa más abierto de esa banda es el lateral
	var wide: SoccerPlayer = null
	for mate: SoccerPlayer in m.teams[p.team]:
		if mate.role != "DF" or mate.is_keeper or not mate.visible:
			continue
		if signf(mate.global_position.z) != side:
			continue
		if wide == null or absf(mate.global_position.z) > absf(wide.global_position.z):
			wide = mate
	if wide != p or absf(p.global_position.z) < 5.0:
		return Vector3.INF
	var lane := side * (SoccerMatch.FIELD_WIDTH * 0.5 - 2.5)
	if absf(hz) > SoccerMatch.FIELD_WIDTH * 0.5 - 7.0:
		lane = side * (absf(hz) - 6.0) # él va pegado a la cal: el lateral entra por dentro
	var ahead := minf(holder.global_position.x * dir + 8.0, SoccerMatch.FIELD_LENGTH * 0.5 - 8.0)
	return Vector3(ahead * dir, 0.0, lane)


## Solo el SEGUNDO mediocentro más adelantado hace la llegada: el primero se
## ofrece corto. Si no, se juntarían todos en la misma zona.
static func _late_run(p: SoccerPlayer, m: SoccerMatch, holder: SoccerPlayer) -> Vector3:
	if p.is_human or p.role != "MF" or m.state != SoccerMatch.State.SIMULATING:
		return Vector3.INF
	var dir := m.attack_dir(p.team)
	if holder.global_position.x * dir < 20.0:
		return Vector3.INF # el balón aún no está en el último tercio
	var box := m.opponent_goal_center(p.team) - Vector3(dir * 10.0, 0.0, 0.0)
	var first: SoccerPlayer = null
	var second: SoccerPlayer = null
	var d1 := INF
	var d2 := INF
	for mate: SoccerPlayer in m.teams[p.team]:
		if mate == holder or mate.is_keeper or mate.is_human or not mate.visible or mate.role != "MF":
			continue
		var d := SoccerMatch.flat_dist(mate.global_position, box)
		if d < d1:
			d2 = d1
			second = first
			d1 = d
			first = mate
		elif d < d2:
			d2 = d
			second = mate
	if second != p:
		return Vector3.INF
	var lane := clampf(box.z * 0.5 + p.global_position.z * 0.5, -10.0, 10.0)
	var target := Vector3((SoccerMatch.FIELD_LENGTH * 0.5 - 13.0) * dir, 0.0, lane)
	if SoccerMatch.flat_dist(p.global_position, target) < 2.5:
		return Vector3.INF
	return target


## Delantero: si el compañero con balón está por detrás, pica al hueco a la altura del
## último defensor (sin pasarse mucho), en su carril. INF = no hay desmarque que hacer.
static func _run_in_behind(p: SoccerPlayer, m: SoccerMatch, holder: SoccerPlayer) -> Vector3:
	var dir := m.attack_dir(p.team)
	var hx := holder.global_position.x * dir
	var px := p.global_position.x * dir
	if hx > px - 4.0 or hx < -10.0:
		return Vector3.INF # ya va por delante, o el balón aún está en campo propio
	# Último defensor rival (el más retrasado sin contar al portero)
	var last := -INF
	for o: SoccerPlayer in m.teams[1 - p.team]:
		if not o.is_keeper and o.visible:
			last = maxf(last, o.global_position.x * dir)
	if last == -INF:
		return Vector3.INF
	var x := clampf(last + AiTuning.run_depth(p.stat("speed"), p.stat("decision_making")),
		px - 2.0, SoccerMatch.FIELD_LENGTH * 0.5 - 9.0)
	var lane := clampf(p.global_position.z, -16.0, 16.0)
	return Vector3(x * dir, 0.0, lane)


static func _with_ball(p: SoccerPlayer, m: SoccerMatch) -> void:
	# Jugada a balón parado o preparada del rival: espera y ejecuta (chute, centro, falta)
	if m.state == SoccerMatch.State.MOMENT and p == m.play_carrier:
		if p.ai_timer > 0.0:
			if bool(m.play.get("set_piece", false)):
				p.move_input = Vector3.ZERO
				return
		else:
			m.do_rival_action(p)
			return
	var goal := m.opponent_goal_center(p.team)
	var to_goal := SoccerMatch.flat(goal - p.global_position)
	var dist := to_goal.length()
	var dir_goal := to_goal / maxf(dist, 0.01)

	# En tus momentos clave, tus compañeros juegan para ti: te la dan en cuanto estás libre
	var for_star := m.state == SoccerMatch.State.MOMENT and p.team == 0 and m.star != null and p != m.star
	if p.ai_timer <= 0.0:
		p.ai_timer = randf_range(0.25, 0.5) * AiTuning.decision_delay_scale(p.stat("decision_making"))
		if for_star and (m.moment_type == SoccerMatch.Moment.CROSS or m.moment_type == SoccerMatch.Moment.CORNER):
			p.cross_to(m.star) # centro / córner: a la cabeza de tu jugador
			return
		if for_star:
			var star := m.star
			var lane := m.lane_clear(p.global_position, star.global_position, p.team)
			var free := m.nearest_opponent_distance(star, star.global_position) > 2.0
			# Desde la banda, con tu jugador en el área: centro para que cabecees
			var star_in_box := m.in_own_box(1 - p.team, star.global_position)
			var aware := randf() < AiTuning.offside_awareness(p.stat("passing"), p.stat("decision_making"))
			var star_off := aware and m.is_offside_now(star)
			if star_in_box and not star_off and absf(p.global_position.z) > 14.0 and dist < 32.0 \
					and randf() < AiTuning.star_cross_chance(p.stat("passing"), p.stat("composure")):
				p.cross_to(star)
				return
			var near := SoccerMatch.flat_dist(p.global_position, star.global_position) < 34.0
			if lane and near and not star_off and (m.pass_requested or (free
					and randf() < AiTuning.star_pass_chance(p.stat("passing"), p.stat("decision_making")))):
				p.pass_ball(star)
				return
			# Solo chuta él si está muy cerca y tú no estás libre
			if dist < 11.0 and not (lane and free) \
					and randf() < AiTuning.star_solo_shot_chance(p.stat("shooting"), p.stat("composure")):
				p.shoot_at(goal + Vector3(0.0, 0.0, randf_range(-2.5, 2.5)), 0.75)
				return
			if m.nearest_opponent_distance(p, p.global_position) < 1.6:
				var mate := m.best_pass_option(p)
				if mate:
					p.pass_ball(mate)
					return
		# Chutar si está cerca y con buen ángulo (perdiendo al final, también de lejos)
		elif dist < (24.0 if m.team_mentality(p.team) > 3.0 else 18.0) and absf(p.global_position.z) < 13.0 \
				and randf() < AiTuning.shot_chance(p.stat("shooting"), p.stat("composure"), dist):
			# Al palo contrario al portero (con algo de azar)
			var side := SoccerMatch.GOAL_WIDTH * 0.5 - 0.6
			var keeper: SoccerPlayer = m.teams[1 - p.team][0]
			var away := -signf(keeper.global_position.z - goal.z)
			if away == 0.0:
				away = 1.0 if randf() < 0.5 else -1.0
			var aim := goal + Vector3(0.0, 0.0, away * randf_range(side * 0.4, side))
			p.shoot_at(aim, clampf(0.45 + dist / 30.0, 0.5, 0.95))
			return
		# Desde la banda y cerca del área: centro al delantero (más variedad que
		# el pase raso de siempre).
		elif dist < 30.0 and absf(p.global_position.z) > 15.0 \
				and randf() < AiTuning.wing_cross_chance(p.stat("passing"), p.stat("composure")):
			var box := m.opponent_goal_center(p.team) - Vector3(m.attack_dir(p.team) * 7.0, 0.0, 0.0)
			var striker := m._nearest_of_role(p.team, box, ["ST"], [p])
			if striker != null and not (m.is_offside_now(striker)
					and randf() < AiTuning.offside_awareness(p.stat("passing"), p.stat("decision_making"))):
				p.cross_to(striker)
				return
		# Pasar si le presionan (o de vez en cuando, para mover el balón)
		var pressure := m.nearest_opponent_distance(p, p.global_position + dir_goal * 1.5)
		if not for_star and (pressure < 2.2
				or randf() < AiTuning.pressure_pass_chance(p.stat("passing"), p.stat("decision_making"))):
			var mate := m.best_pass_option(p)
			if mate:
				p.pass_ball(mate)
				return

	# Ganando por uno en los últimos minutos: al banderín a esconder el balón
	var move := dir_goal
	if _kill_clock(p, m, dist):
		var flag := goal + Vector3(-m.attack_dir(p.team) * 1.5, 0.0, signf(p.global_position.z + 0.01) * (SoccerMatch.FIELD_WIDTH * 0.5 - 1.0))
		move = SoccerMatch.flat(flag - p.global_position).normalized()
	# Rival justo delante: a veces lo encara con un regate de verdad (con su gesto)
	if not p.is_human and _try_dribble(p, m, dir_goal):
		return
	# Regatear hacia la portería apartándose de los rivales cercanos
	for o: SoccerPlayer in m.teams[1 - p.team]:
		var off := SoccerMatch.flat(p.global_position - o.global_position)
		var d := off.length()
		if d < 3.5 and d > 0.01:
			move += off / d * (3.5 - d) * 0.45
	var edge_z := SoccerMatch.FIELD_WIDTH * 0.5 - absf(p.global_position.z)
	if edge_z < 4.0:
		move.z -= signf(p.global_position.z) * (4.0 - edge_z) * 0.5
	p.move_input = SoccerMatch.flat(move).normalized()
	p.sprinting = m.nearest_opponent_distance(p, p.global_position) > 4.0


## Regate de la IA: con un rival de frente a menos de 2,6 m, según su regate intenta
## un quiebro (o bicicleta / elástica / enganche). Sale bien según DribbleCombo y el
## rival se queda clavado; si no, sigue la jugada normal. Un intento cada ~2,5 s.
static func _try_dribble(p: SoccerPlayer, m: SoccerMatch, dir_goal: Vector3) -> bool:
	var now := Time.get_ticks_msec()
	if now < int(p.get_meta("dribble_ms", 0)) or p.dodge_timer > 0.0 or p.is_kicking():
		return false
	var rival: SoccerPlayer = null
	for o: SoccerPlayer in m.teams[1 - p.team]:
		if o.is_keeper or o.stun_timer > 0.0 or not o.visible:
			continue
		var off := SoccerMatch.flat(o.global_position - p.global_position)
		if off.length() < 2.6 and off.normalized().dot(dir_goal) > 0.4:
			rival = o
			break
	if rival == null:
		return false
	p.set_meta("dribble_ms", now + 2500)
	if randf() >= AiTuning.dribble_attempt_chance(p.stat("dribbling"), p.stat("composure")):
		return false
	var move := AiTuning.dribble_move(p.stat("dribbling"), randf())
	var side := 1.0 if randf() < 0.5 else -1.0
	var lateral := dir_goal.cross(Vector3.UP) * side
	var dir := (dir_goal * 0.55 + lateral).normalized()
	if move == "dragback":
		dir = (-dir_goal * 0.4 + lateral).normalized()
	p.dodge(dir, move)
	if move == "stepover" or move == "dragback":
		p.velocity *= 0.5
	var chance := DribbleCombo.beat_chance(p.stat("dribbling"), rival.duel_skill(true), 2 if move != "" else 1)
	if randf() < chance:
		rival.beaten(DribbleCombo.stun_time(1), p.global_position - rival.global_position)
	return true


## ¿Toca perder tiempo? Solo fuera de tus jugadas, ganando por uno pasado el 85' y ya
## en campo rival por la banda.
static func _kill_clock(p: SoccerPlayer, m: SoccerMatch, dist: float) -> bool:
	if m.state != SoccerMatch.State.SIMULATING or m.minute < 85.0:
		return false
	if int(m.score[p.team]) - int(m.score[1 - p.team]) != 1:
		return false
	return dist < 30.0 and absf(p.global_position.z) > 12.0


static func _defend(p: SoccerPlayer, m: SoccerMatch, holder: SoccerPlayer) -> void:
	var presser := m.closest_to_point_cached(p.team, holder.global_position, true)
	if presser != p and _is_second_presser(p, m, holder, presser):
		# Le cierra el camino hacia dentro sin entrar (la entrada la hace el primero)
		var g := m.goal_center(p.team)
		var shut := holder.global_position + SoccerMatch.flat(g - holder.global_position).normalized() * 2.2
		move_to(p, shut, 0.3, true)
		return
	if presser != p:
		# Marcaje: el atacante libre más peligroso (cerca de nuestra portería) tiene a alguien
		# encima, del lado de la portería. El resto guarda la posición.
		var own_goal := m.goal_center(p.team)
		var danger: SoccerPlayer = null
		var best_d := INF
		var adir := m.attack_dir(1 - p.team)
		var aline := m.offside_line_world(1 - p.team) * adir
		for a: SoccerPlayer in m.teams[1 - p.team]:
			if a == holder or a.is_keeper:
				continue
			# Adelantado y con el balón lejos: se le deja en fuera de juego, no se le sigue
			if Offside.leave_offside_runner(a.global_position.x * adir, aline,
					SoccerMatch.flat_dist(a.global_position, holder.global_position)):
				continue
			var d := SoccerMatch.flat_dist(a.global_position, own_goal)
			if d < best_d and d < 26.0:
				best_d = d
				danger = a
		if danger != null:
			var marker: SoccerPlayer = null
			var md := INF
			for mate: SoccerPlayer in m.teams[p.team]:
				if mate.is_keeper or mate == presser or mate.is_human:
					continue
				var d := SoccerMatch.flat_dist(mate.global_position, danger.global_position)
				if d < md:
					md = d
					marker = mate
			if marker == p:
				# Marcaje más pegado dentro del área: no dejar rematar cómodo.
				# La lectura y la velocidad del defensor ajustan la distancia.
				var tight := AiTuning.mark_tightness(p.stat("decision_making"), p.stat("speed"), best_d)
				var guard := danger.global_position + SoccerMatch.flat(own_goal - danger.global_position).normalized() * tight
				move_to(p, guard, 0.3, md > 3.0)
				return
		# Sin marcaje asignado: cubrir el hueco entre el balón y nuestra portería
		# (si el rival está cerca), en vez de quedarse en la casilla fija.
		var goal_own := m.goal_center(p.team)
		if SoccerMatch.flat_dist(holder.global_position, goal_own) < 24.0:
			var cover := holder.global_position.lerp(goal_own, 0.45)
			cover.z += signf(p.global_position.z - holder.global_position.z) * 3.0
			move_to(p, cover, 0.8, true)
			return
		move_to(p, m.formation_target(p), 0.6, true)
		return
	# Contiene perfilado entre el balón y la portería, con un sesgo lateral para tapar
	# el pase por dentro. No se pega al rival: espera a un par de pasos y se acerca
	# cuando el balón se le despega del pie (toque largo), que es cuando entra.
	var own_goal := m.goal_center(p.team)
	var line := SoccerMatch.flat(own_goal - holder.global_position).normalized()
	var lateral := Vector3(-line.z, 0.0, line.x)
	var side := 1.0 if holder.global_position.z >= 0.0 else -1.0
	var expo: float = m.ball.exposure
	var contain := BallContact.contain_distance(expo)
	if not holder.is_human:
		contain *= 0.8 # con la IA contra la IA se juega más al choque (la simulación avanza)
	elif p.tackle_cooldown > 0.0:
		contain = maxf(contain, 2.5) # aún no puede entrar: te espera a distancia, no encima
	var target := holder.global_position + line * contain + lateral * side * 0.35
	var hv := SoccerMatch.flat(holder.velocity)
	var rel := SoccerMatch.flat(p.global_position - holder.global_position)
	if hv.length() > 3.0 and rel.length() < 6.0 and rel.dot(hv.normalized()) < -0.3:
		# Le persigue desde atrás: en vez de ir a la estela, se pone a su altura por el
		# lado en el que ya está, a cuerpo de distancia, para pelearle con el hombro
		var sidev := Vector3(-hv.z, 0.0, hv.x).normalized()
		var by := 1.0 if rel.dot(sidev) >= 0.0 else -1.0
		target = holder.global_position + hv.normalized() * 0.3 + sidev * by * 0.8
		move_to(p, target, 0.0, true)
	else:
		move_to(p, target, 0.0, SoccerMatch.flat_dist(p.global_position, target) > 2.5)
	var dist_to_holder := SoccerMatch.flat_dist(p.global_position, holder.global_position)
	# Probabilidad de entrada escalada por decisión y fuerza: un defensor con
	# buena lectura entra más a menudo y con menos temeridad; uno débil se
	# arriesga menos (menos faltas tontas).
	var tackle_p := 0.05 if p.global_position.x * m.attack_dir(p.team) > 0.0 else 0.09
	tackle_p *= AiTuning.press_bias(p.stat("decision_making"), p.stat("strength"))
	# Una decisión de entrada cada 1.5 s como mucho (antes se tiraba por frame y el
	# defensor se quedaba entrando toda la jugada).
	var now := Time.get_ticks_msec()
	tackle_p *= BallContact.tackle_urge(p.stat("decision_making"), expo)
	if dist_to_holder < BallContact.tackle_reach(expo) and now - int(p.get_meta("tackle_ms", -100000)) > 1500 			and randf() < tackle_p * 6.0:
		p.set_meta("tackle_ms", now)
		# Contra ti en una jugada, a veces entran en plancha (puede ser falta a tu
		# favor). La lectura y la sangre fría del defensor deciden el riesgo; un
		# árbitro estricto hace que midan más la entrada.
		var slide_p := AiTuning.slide_bias(p.stat("decision_making"), p.stat("composure"))
		slide_p *= clampf(1.0 - maxf(0.0, m._referee_foul_mult - 1.0) * 0.4, 0.65, 1.0)
		m.request_tackle(p, holder.is_human and randf() < slide_p)


## Ayuda: solo cerca de nuestra área (a menos de 22 m) y si es el segundo más cercano.
static func _is_second_presser(p: SoccerPlayer, m: SoccerMatch, holder: SoccerPlayer, presser: SoccerPlayer) -> bool:
	if p.is_human or SoccerMatch.flat_dist(holder.global_position, m.goal_center(p.team)) > 22.0:
		return false
	var d := SoccerMatch.flat_dist(p.global_position, holder.global_position)
	if d > 12.0:
		return false
	for mate: SoccerPlayer in m.teams[p.team]:
		if mate == p or mate == presser or mate.is_keeper or not mate.visible:
			continue
		if SoccerMatch.flat_dist(mate.global_position, holder.global_position) < d:
			return false
	return true


static func _loose_ball(p: SoccerPlayer, m: SoccerMatch) -> void:
	# Va a por él quien antes lo alcanza (no quien está más cerca ahora): cortar pases
	var best: SoccerPlayer = null
	var best_d := INF
	for mate: SoccerPlayer in m.teams[p.team]:
		if mate.is_keeper or mate.is_human or not mate.visible:
			continue
		var d := SoccerMatch.flat_dist(mate.global_position, m.intercept_point_cached(mate))
		# El que lee mejor el balón suelto arranca antes (menor costo efectivo).
		d *= AiTuning.loose_ball_anticipation(mate.stat("decision_making"))
		if d < best_d:
			best_d = d
			best = mate
	if best == p:
		move_to(p, m.intercept_point_cached(p), 0.0, true)
	else:
		move_to(p, m.formation_target(p), 0.6, true)


static func _keeper(p: SoccerPlayer, m: SoccerMatch) -> void:
	var ball := m.ball
	var b := ball.global_position
	var goal := m.goal_center(p.team)
	var dir := m.attack_dir(p.team)
	var half_goal := SoccerMatch.GOAL_WIDTH * 0.5

	if ball.owner_player == p:
		p.move_input = Vector3.ZERO
		if p.hold_timer <= 0.0:
			var mate := m.best_pass_option(p)
			if mate:
				p.pass_ball(mate)
			else:
				p.shoot_at(m.opponent_goal_center(p.team), 0.8)
		return

	var target := goal + Vector3(dir * 1.0, 0.0, clampf(b.z * 0.35, -half_goal + 0.4, half_goal - 0.4))

	if p.is_diving():
		p.move_input = Vector3.ZERO
		return

	# Tiro hacia nuestra portería: ir al punto por donde cruzará y, si no llega andando, estirarse
	var v := ball.linear_velocity
	if ball.owner_player == null and v.x * dir < -6.0:
		var t := (p.global_position.x - b.x) / (v.x * 0.9) # el balón frena un poco en el aire
		if t > 0.0 and t < 1.5:
			var cz := b.z + v.z * t
			var cy := b.y + v.y * t - 4.9 * t * t
			var on_target := absf(cz) < half_goal + 0.5 and cy < SoccerMatch.GOAL_HEIGHT + 0.4
			if on_target and t <= SoccerPlayer.DIVE_LEAD + 0.03 \
					and absf(cz - p.global_position.z) > 0.8:
				m.keeper_dive(p, Vector3(p.global_position.x, maxf(cy, 0.2), cz))
				return
			target.z = clampf(cz, -half_goal - 0.3, half_goal + 0.3)
			move_to(p, target, 0.05, true)
			p.sprinting = true
			return

	# Rival con balón cerca del área: salir a tapar ángulo (entre él y el centro de la portería)
	var holder := ball.owner_player
	if holder != null and holder.team != p.team:
		var to_h := SoccerMatch.flat(holder.global_position - goal)
		var dist := to_h.length()
		if dist > 0.01 and dist < 14.0:
			var out := clampf(dist * 0.3, 1.0, 3.2)
			move_to(p, goal + to_h / dist * out, 0.15, dist < 8.0)
			return

	# Balón suelto o centro al área: el portero sale a por él si es el primero
	# que puede llegar. Antes solo lo hacía con el balón ya en el suelo.
	if ball.owner_player == null and m.in_own_box(p.team, b) \
			and m.closest_to_point_cached(p.team, b, false) == p:
		if b.y > 0.55 and b.y < 2.4 and v.y < 2.5:
			# Centro/balón alto: se adelanta al punto de caída, no espera bajo palos
			move_to(p, SoccerMatch.flat(b + v * 0.25), 0.0, true)
			return
		if b.y < 0.55:
			move_to(p, b, 0.0, true)
			return

	move_to(p, target, 0.2)
