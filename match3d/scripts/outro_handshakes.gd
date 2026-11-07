extends RefCounted
## Saludo del pitazo final (separado de match.gd, 7-nov): tú le das la mano al rival
## más cercano y otros cuantos se saludan por parejas antes de aplaudir e irse.
## El estado vive en SoccerMatch._outro_shake; aquí solo el emparejado y cada paso.


## Saludo al final: tú le das la mano al rival más cercano y otros cuantos se
## saludan por parejas (ArmPose "shake"), antes de aplaudir e irse al túnel.
static func pair(order: Array[SoccerPlayer], star: SoccerPlayer) -> Dictionary:
	var shakes := {}
	var free: Array[SoccerPlayer] = []
	for p: SoccerPlayer in order:
		if not p.is_keeper:
			free.append(p)
	var firsts: Array[SoccerPlayer] = []
	if star != null and free.has(star):
		firsts.append(star)
	for p: SoccerPlayer in free:
		if p != star and p.team == 0 and randf() < 0.45:
			firsts.append(p)
	for a: SoccerPlayer in firsts:
		if shakes.has(a):
			continue
		var best: SoccerPlayer = null
		var bd := 32.0 if a == star else 12.0
		for b: SoccerPlayer in free:
			if b.team == a.team or shakes.has(b):
				continue
			var d := SoccerMatch.flat_dist(a.global_position, b.global_position)
			if d < bd:
				bd = d
				best = b
		if best == null:
			continue
		var mid := (a.global_position + best.global_position) * 0.5
		var dir := SoccerMatch.flat(best.global_position - a.global_position).normalized()
		if dir == Vector3.ZERO:
			dir = Vector3.RIGHT
		shakes[a] = {"partner": best, "spot": mid - dir * 0.36, "phase": "wait", "start": 0.3, "t": 0.0}
		shakes[best] = {"partner": a, "spot": mid + dir * 0.36, "phase": "wait", "start": 0.3, "t": 0.0}


## true mientras está con el saludo (camina al rival, espera, le da la mano).
	return shakes


static func update(m: SoccerMatch, p: SoccerPlayer, delta: float) -> bool:
	var sh: Dictionary = m._outro_shake[p]
	var partner: SoccerPlayer = sh.partner
	if m._outro_t < float(sh.start):
		return false # aún reaccionando al pitazo: lo lleva el flujo normal (quieto)
	match String(sh.phase):
		"wait":
			sh.phase = "go"
		"go":
			var spot: Vector3 = sh.spot
			if SoccerMatch.flat_dist(p.global_position, spot) > 0.16:
				AiBrain.move_to(p, spot, 0.05, false)
				# Lejos se acercan trotando; el último tramo, caminando
				var far := clampf((SoccerMatch.flat_dist(p.global_position, spot) - 3.0) / 8.0, 0.0, 1.0)
				p.move_input *= m._walk_pace(p) / SoccerMatch.WALK_PACE * lerpf(0.9, 2.0, far)
			else:
				p.move_input = Vector3.ZERO
				sh.phase = "ready"
			if m._outro_t > float(sh.start) + 9.0:
				sh.phase = "ready" # no se queda colgado si el otro no llega
		"ready":
			p.move_input = Vector3.ZERO
			p.ease_facing(SoccerMatch.flat(partner.global_position - p.global_position).normalized(), delta, 5.0)
			var other: Dictionary = m._outro_shake.get(partner, {})
			if other.is_empty() or String(other.phase) in ["ready", "shake"]:
				sh.phase = "shake"
				sh.t = 0.0
				if p._avatar != null:
					p._avatar.pose_arms("shake", 0.25)
		"shake":
			p.move_input = Vector3.ZERO
			p.ease_facing(SoccerMatch.flat(partner.global_position - p.global_position).normalized(), delta, 5.0)
			sh.t = float(sh.t) + delta
			if float(sh.t) > 1.5:
				if p._avatar != null:
					p._avatar.pose_arms("", 0.3)
				m._outro_shake.erase(p)
				return false
	return true
