extends Node
## Estadísticas de muchas jugadas 3D seguidas, con tu jugador manejado por la IA
## (como un usuario "medio"): cuántas acaban en gol, fuera de juego, falta, fuera,
## VAR... por tipo de jugada. Sirve para ajustar los números sin adivinar.
##   godot --headless --path . res://tools/M3DMomentStatsProbe.tscn -- [jugadas]
## Solo toca slot_3 (carrera de prueba).

var m: SoccerMatch
var stats := {}      # tipo -> {n, ok, goal, conceded, offside, var, foul, out, other}
var kicks := 0
var var_reviews := 0
var _last_state := -1
var as_human := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var want := int(args[0]) if args.size() > 0 else 30
	# "human": tu jugador queda como en el celular (sin tocar nada): ¿cuánto dura la jugada?
	as_human = args.has("human")
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	var mine: MatchTeam = MatchState.home_team if String(fx.get("home_club_id", "")) == pl.club_id else MatchState.away_team
	var u: PlayerData = MatchState.user_player
	if not mine.starting_xi.has(u):
		mine.bench.erase(u)
		for i in mine.starting_xi.size():
			if (mine.starting_xi[i] as PlayerData).position == u.position:
				mine.starting_xi[i] = u
				break
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	m = scr._match
	await get_tree().process_frame
	if m.state == m.State.WALKOUT:
		m._end_walkout()
	# Muchas jugadas: se juntan varias planificaciones (mismo reparto por puesto)
	var all: Array = []
	while all.size() < want:
		m._plan_moments()
		if m._moments.is_empty():
			break
		all.append_array(m._moments)
	all = all.slice(0, want)
	for i in all.size():
		all[i]["minute"] = 2.0 + 86.0 * float(i) / float(all.size())
	m._moments = all
	print("jugadas planeadas: ", all.size())
	if args.has("misses"):
		await _test_ambient_misses(30)
		get_tree().quit(0)
		return
	m.moment_ended.connect(_on_moment_ended)
	if args.has("goals"):
		for t in 2:
			(m._goal_areas[t] as Area3D).body_entered.connect(func(b: Node3D) -> void:
				if b == m.ball:
					print("  SENSOR gol equipo=%d estado=%s amb_team=%d amb_scored=%s miss=%s marcador=%s" % [
						t, m.State.keys()[m.state], m._ambient_goal_team, str(m._ambient_goal_scored),
						str(m._ambient_is_miss), str(m.score)]))
	m.ball.kicked.connect(_on_kick)
	var t0 := Time.get_ticks_msec()
	for tick in 60000:
		# Tu jugador lo maneja la IA (sin "humano", la IA también piensa por él)
		if not as_human and m.state == m.State.MOMENT and m.human != null:
			m._set_human(null)
		if m.state == m.State.LOCKER and m._hud.choices_visible():
			m._hud.hide_choices()
			m._on_choice(1)
		if m.state == m.State.VAR_REVIEW and _last_state != m.State.VAR_REVIEW:
			var_reviews += 1
		if m.state == m.State.MOMENT and _last_state != m.State.MOMENT:
			_moment_t0 = Time.get_ticks_msec()
			_moment_owner_log = []
		if m.state == m.State.MOMENT:
			var o := m.ball.owner_player
			var tag := "-" if o == null else ("%s%d%s" % ["L" if o.team == 0 else "R", o.index, "*" if o == m.star else ""])
			if _moment_owner_log.is_empty() or _moment_owner_log[-1] != tag:
				_moment_owner_log.append(tag)
		if as_human and args.has("trace") and m.state == m.State.MOMENT and Engine.get_physics_frames() % 3 == 0 \
				and Time.get_ticks_msec() - _moment_t0 < 2500:
			var s := m.star
			var near: SoccerPlayer = null
			var nd := INF
			for o: SoccerPlayer in m.teams[1]:
				var d := SoccerMatch.flat_dist(o.global_position, m.ball.global_position)
				if d < nd:
					nd = d
					near = o
			var ow := m.ball.owner_player
			print("  t=%4d %s star=(%.1f,%.1f) bal=(%.1f,%.2f,%.1f) v=%.1f dueño=%s rival+cerca R%d %.1fm st=%s act=%s" % [
				Time.get_ticks_msec() - _moment_t0, m.Moment.keys()[m.moment_type], s.global_position.x, s.global_position.z,
				m.ball.global_position.x, m.ball.global_position.y, m.ball.global_position.z, m.ball.linear_velocity.length(),
				"-" if ow == null else ("%s%d" % ["L" if ow.team == 0 else "R", ow.index]), near.index, nd,
				str(s.get("stun_timer")), str(s.get("_action_timer"))])
		_check_ghost_goal()
		_last_state = m.state
		if m.state in [m.State.OUTRO, m.State.ENDED, m.State.MVP_CEREMONY]:
			break
		await get_tree().physics_frame
	_report(Time.get_ticks_msec() - t0)
	get_tree().quit(0)


var _moment_t0 := 0
var _moment_owner_log: Array = []
var _inside := false
var _inside_score := 0
var ghost_goals := 0


## Balón entero dentro de la portería (entre palos, bajo el larguero) sin que suba
## el marcador = gol fantasma (lo que se ve en el celular: entra y sale).
func _check_ghost_goal() -> void:
	var b := m.ball.global_position
	var line := SoccerMatch.FIELD_LENGTH * 0.5
	# Episodio: desde que el balón llega a la boca de la portería hasta que sale de esa
	# zona; es gol fantasma si cruzó la línea entera y el marcador no se movió.
	var mouth := absf(b.z) < SoccerMatch.GOAL_WIDTH * 0.5 - 0.1 and b.y < SoccerMatch.GOAL_HEIGHT - 0.1
	var inside := absf(b.x) > line - 1.0 and mouth
	if inside and not _inside:
		_inside_score = m.score[0] + m.score[1]
		_inside_t = Time.get_ticks_msec()
		_inside_state = m.state
		_crossed = false
		_was_miss = m._ambient_is_miss
	if inside and absf(b.x) > line + 0.15:
		_crossed = true
	if _inside and not inside:
		if _crossed and m.score[0] + m.score[1] == _inside_score and m.state != m.State.PENALTY_SHOOTOUT \
				and _inside_state != m.State.PENALTY_SHOOTOUT:
			print("   (tiro decidido fallado: %s)" % str(_was_miss))
			ghost_goals += 1
			print("GOL FANTASMA estado=%s (al entrar %s) x=%.2f tras %d ms · moment=%s" % [
				m.State.keys()[m.state], m.State.keys()[_inside_state], b.x, Time.get_ticks_msec() - _inside_t,
				m.Moment.keys()[m.moment_type]])
	_inside = inside


var _crossed := false
var _was_miss := false
var _inside_t := 0
var _inside_state := 0
var kick_kinds := {}
var passes_with_offside := 0   # pases con algún compañero adelantado en ese instante


func _on_kick(_by: SoccerPlayer, kind: String) -> void:
	if m.state != m.State.MOMENT:
		return
	kicks += 1
	kick_kinds[kind] = int(kick_kinds.get(kind, 0)) + 1
	var snap: Dictionary = m._offside_snap
	if snap.is_empty():
		return
	for e: Dictionary in (snap.players as Dictionary).values():
		if float(e.margin) > 0.05:
			passes_with_offside += 1
			break


## Tiros que la simulación decidió fallados: ninguno debe acabar en la red.
func _test_ambient_misses(n: int) -> void:
	var in_net := [0]
	for t in 2:
		(m._goal_areas[t] as Area3D).body_entered.connect(func(b: Node3D) -> void:
			if b == m.ball and m.state == m.State.AMBIENT_GOAL and m._ambient_is_miss:
				in_net[0] += 1)
	for i in n:
		m._start_ambient_miss(i % 2, 30, "")
		for f in 200:
			await get_tree().physics_frame
		m._finish_ambient_goal()
		await get_tree().physics_frame
	print("FALLOS SIMULADOS: %d de %d acabaron dentro de la portería · marcador %s" % [in_net[0], n, str(m.score)])


func _on_moment_ended(text: String, ok: bool) -> void:
	var kind: String = m.Moment.keys()[m.moment_type]
	if not stats.has(kind):
		stats[kind] = {"n": 0, "ok": 0, "goal": 0, "conceded": 0, "offside": 0, "var": 0, "foul": 0, "out": 0, "other": 0}
	var s: Dictionary = stats[kind]
	s.n += 1
	if ok:
		s.ok += 1
	var t := text.to_upper()
	if t.contains("ANULADO"):
		s["var"] += 1
	elif t.contains("FUERA DE JUEGO"):
		s.offside += 1
	elif m._moment_goal == 0:
		s.goal += 1
	elif m._moment_goal == 1:
		s.conceded += 1
	elif t.contains("FALTA"):
		s.foul += 1
	elif t.contains("FUERA"):
		s.out += 1
	else:
		s.other += 1
	print("JUGADA %s ok=%s · %.1fs · %s · balón: %s" % [kind, str(ok), (Time.get_ticks_msec() - _moment_t0) / 1000.0 * m.MOMENT_TIME_SCALE,
		text.replace("\n", " / "), " > ".join(_moment_owner_log.slice(-8))])


func _report(ms: int) -> void:
	print("==== jugadas en %.0f s · golpeos %d · revisiones VAR %d · marcador %s" % [
		ms / 1000.0, kicks, var_reviews, str(m.score)])
	print("goles fantasma: ", ghost_goals)
	print("golpeos por tipo (en jugadas): ", kick_kinds, " · con compañero adelantado: ", passes_with_offside)
	var tot := {"n": 0, "ok": 0, "goal": 0, "conceded": 0, "offside": 0, "var": 0, "foul": 0, "out": 0, "other": 0}
	for kind: String in stats:
		var s: Dictionary = stats[kind]
		print("STATS %-10s n=%2d ok=%2d gol=%d encajado=%d offside=%d var=%d falta=%d fuera=%d otro=%d" % [
			kind, s.n, s.ok, s.goal, s.conceded, s.offside, s["var"], s.foul, s.out, s.other])
		for k: String in tot:
			tot[k] += int(s[k])
	print("STATS TOTAL      n=%d ok=%d gol=%d encajado=%d offside=%d var=%d falta=%d fuera=%d otro=%d" % [
		tot.n, tot.ok, tot.goal, tot.conceded, tot.offside, tot["var"], tot.foul, tot.out, tot.other])
