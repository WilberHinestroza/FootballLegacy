class_name StadiumStaff
extends Node3D
## La banda del estadio: banquillos con suplentes y DT, cuarto árbitro con el cartel de
## cambios, túnel de vestuarios, camarógrafos, fotógrafos y recogepelotas.
## Las personas usan el mismo modelo que los jugadores (PlayerAvatar) con su ropa:
## DT de traje, suplentes con la camiseta y el peto, cámaras y fotógrafos de calle.
## Animado aquí: las cámaras siguen el balón, los DT caminan por su área técnica y celebran.

const SUIT := Color(0.12, 0.13, 0.17)
const STAFF_SHIRT := Color(0.18, 0.2, 0.26)
const PRESS := Color(0.95, 0.55, 0.12) # petos de los fotógrafos
const OFFICIAL := Color(0.95, 0.85, 0.1)
const BIB := Color(0.75, 1.0, 0.15)    # peto fosforito de los suplentes
# Poses fijas (grados de giro de cada hueso; ajustadas con build/staff_preview.gd)
const SIT_THIGH := 85.0
const SIT_KNEE := -85.0
const SIT_DROP := -0.38
const KNEEL_BACK := -15.0
const KNEEL_DROP := -0.45
const DUGOUT_H := 1.85    # alto del banquillo (pared del fondo y techo)
const DUGOUT_SEAT := 0.36 # alto del asiento del banquillo (PlayerAvatar.SIT_SEAT_H)
const ROW_HALF := 0.6 # media fila: la primera fila de grada está centrada en la boca

var _match: SoccerMatch
var _kits: Array = [{}, {}]
var _photo_cams: Array = []           # [avatar, cámara]: la cámara de fotos va en sus manos
var _followers: Array[Node3D] = []   # giran hacia el balón (cámaras, fotógrafos, banquillo)
var _coaches: Array[Node3D] = []
var _coach_home: Array[Vector3] = []
var _assistants: Array[Node3D] = []
## Desfile por el túnel (banquillo y técnicos): cada uno con su espera y su ruta.
## Mientras desfila, nadie más lo mueve (ni el DT sigue la jugada ni el ayudante gira).
var _parade: Array = [] # [{n, delay, steps: [{to}|{shake, t}|{clap, t}], end: "sit"|"coach"|"stand"|"hide"}]
var _bench_people: Array = [[], []]  # suplentes sentados de cada equipo
var _celebrate := [0.0, 0.0]
## DT haciendo un gesto (gritar, señalar, celebrar…): segundos que le quedan; mientras, no camina.
var _coach_action := [0.0, 0.0]
var _coach_next := [6.0, 10.0]
var _board: Node3D
var _board_time := 0.0
var _board_led: Array[Label3D] = []   # números: [sale, entra, sale (detrás), entra (detrás)]
var _board_lit: Array[MeshInstance3D] = []
## Banderines de los asistentes: [{ref, cloth, up, phase}] (tela que ondea en el palo)
var _flags: Array = []
var _official: Node3D
## Tú, sentado en el banquillo (si empiezas de suplente). Al entrar, el cambio lo haces tú.
var user_seat: Node3D
signal sub_entered(pos: Vector3) # el suplente pisa el campo
var _sub_walker: Node3D       # suplente que va a entrar: se levanta, espera junto al cuarto árbitro y entra
var _sub_phase := 0
var _leavers: Array = []     # los que salen en un cambio: andan del campo al banquillo y desaparecen
## Árbitro central y los dos asistentes (en el campo, siguen la jugada).
var refs: Array[Node3D] = []
## Durante la salida de los equipos: a dónde camina cada árbitro (lo pone el partido).
var ref_targets: Array = []
## Punto de paso de cada árbitro en la salida (la banda, frente al túnel); se borra al pisarlo.
var ref_via: Array = []
## Segundos que espera cada árbitro (oculto, tras la puerta del vestuario) antes de salir.
var ref_delay: Array = []
## Al volver al vestuario: pasada esta z (dentro del pasillo) el árbitro desaparece.
var ref_hide_z := -INF # -INF = nunca
## Paso de los árbitros en la salida y la vuelta (el partido lo iguala al de los jugadores).
var ref_walk_speed := 3.6
## Tarjeta: el central va hacia el infractor y se la enseña (ver show_card).
var _card: MeshInstance3D
var _card_mat: StandardMaterial3D
var _card_t := 0.0
var _card_target: Node3D
var _t := 0.0


## kits: diseño de camiseta de cada equipo ({"shirt_pattern", "shirt_color2"}), como los jugadores.
func build(m: SoccerMatch, shirts: Array, coach_names: Array, kits: Array = [{}, {}]) -> void:
	_match = m
	_kits = kits
	var W := SoccerMatch.FIELD_WIDTH
	var L := SoccerMatch.FIELD_LENGTH
	var line_z := -W * 0.5 # banda de los banquillos (la de enfrente de la cámara de TV)

	# Banquillos: el local defiende -X, su banquillo a ese lado
	for t in 2:
		var cx := -11.0 if t == 0 else 11.0
		var shirt: Color = shirts[t]
		_dugout(Vector3(cx, 0.0, line_z - 3.4), shirt, t)
		_technical_area(Vector3(cx, 0.0, line_z - 1.6))
		# DT de traje oscuro con la corbata del color del equipo
		var coach := _person({"shirt_color": SUIT, "shirt_pattern": 9, "shirt_color2": shirt,
				"long_sleeves": true, "long_pants": true, "shorts_color": SUIT})
		coach.position = Vector3(cx + (2.0 if t == 0 else -2.0), 0.0, line_z - 1.8)
		_coaches.append(coach)
		_coach_home.append(coach.position)
		var name_tag: String = coach_names[t] if t < coach_names.size() else ""
		if name_tag != "":
			coach.set_meta("name", name_tag)
		# Ayudante con el chándal del equipo
		var assistant := _person({"shirt_color": shirt.darkened(0.35), "shirt_pattern": 7, "shirt_color2": shirt,
				"long_sleeves": true, "long_pants": true, "shorts_color": STAFF_SHIRT})
		assistant.position = Vector3(cx + (-3.6 if t == 0 else 3.6), 0.0, line_z - 2.6)
		_followers.append(assistant)
		_assistants.append(assistant)

	# Cuarto árbitro entre los banquillos, con su cartel de cambios
	_official = _person({"shirt_color": OFFICIAL, "long_sleeves": true, "long_pants": true,
			"shorts_color": Color(0.08, 0.08, 0.1)})
	_official.position = Vector3(0.0, 0.0, line_z - 1.4)
	_board = _build_board()
	add_child(_board)
	_board.visible = false
	(_official.get_meta("avatar") as PlayerAvatar).skeleton.skeleton_updated.connect(_place_board)

	_tunnel(Vector3(0.0, 0.0, line_z - FieldBuilder.SIDE_STANDS))
	_official.position.x = 4.5 # deja libre la salida del túnel

	# Árbitros: de negro con hombros amarillos; los asistentes con su banderín
	for i in 3:
		var r := _person({"shirt_color": Color(0.08, 0.08, 0.1), "shirt_pattern": 7,
				"shirt_color2": Color(0.95, 0.85, 0.1), "shorts_color": Color(0.06, 0.06, 0.07),
				"socks_color": Color(0.06, 0.06, 0.07)})
		if i > 0:
			_flags.append(_build_flag(r, i))
		refs.append(r)
	refs[0].position = Vector3(-6.0, 0.0, 8.0)
	refs[1].position = Vector3(15.0, 0.0, W * 0.5 + 0.9)
	refs[2].position = Vector3(-15.0, 0.0, -W * 0.5 - 0.9)

	# Camarógrafos: en la banda de los banquillos, en las esquinas y detrás de cada portería
	for x: float in [-26.0, 26.0]:
		_cameraman(Vector3(x, 0.0, line_z - 2.2), true)
	for s: float in [-1.0, 1.0]:
		var gx := s * (L * 0.5 + 2.6)
		for z: float in [-10.5, 10.5]:
			_cameraman(Vector3(gx, 0.0, z), true)
		_cameraman(Vector3(s * (L * 0.5 + 1.8), 0.0, line_z - 1.8), false) # cámara al hombro
		# Fotógrafos de rodillas junto a la portería, con peto de prensa
		for z: float in [-6.5, 7.0, 13.0, -13.0]:
			var ph := _person({"shirt_color": Color(0.15, 0.15, 0.18), "shirt_pattern": 8, "shirt_color2": PRESS,
					"long_sleeves": true, "long_pants": true, "shorts_color": Color(0.2, 0.22, 0.28)}, "kneel")
			ph.position = Vector3(s * (L * 0.5 + 2.0), 0.0, z + randf_range(-0.3, 0.3))
			var pcam := _add_camera(ph, Vector3(0.0, 1.05, 0.3), 0.55)
			var pav: PlayerAvatar = ph.get_meta("avatar")
			pav.pose_arms("cam_photo", 0.01)
			_set_pose_seed(pav)
			_photo_cams.append([pav, pcam])
			_followers.append(ph)
	# Recogepelotas
	for s: float in [-1.0, 1.0]:
		for x: float in [-38.0, 38.0]:
			var kid := _person({"shirt_color": Color(0.15, 0.6, 0.3), "shorts_color": Color(0.12, 0.12, 0.14),
					"socks_color": Color(0.15, 0.6, 0.3), "boots_color": Color(0.9, 0.9, 0.9)})
			kid.scale = Vector3.ONE * 0.8
			kid.position = Vector3(x, 0.0, s * (W * 0.5 + 3.8))
			_followers.append(kid)


func on_goal(team: int) -> void:
	_celebrate[team] = 2.5
	# DT: el que marca celebra, el otro protesta; su banquillo aplaude sentado
	for i in _coaches.size():
		_coach_gesture(i, ["victory", "fist_pump", "fist_pump_2"].pick_random() if i == team else ["argue", "argue_2", "yell"].pick_random(), 3.0)
	for p: Node3D in _bench_people[team]:
		if p.has_meta("parade"):
			continue
		var av: PlayerAvatar = p.get_meta("avatar")
		if av.anim.has_animation("sit_clap"):
			av.anim.play("sit_clap", 0.3)
			p.set_meta("clap_t", 3.5)


func _coach_gesture(i: int, anim_name: String, t: float) -> void:
	var av: PlayerAvatar = _coaches[i].get_meta("avatar")
	if not av.anim.has_animation(anim_name):
		return
	av.anim.play(anim_name, 0.25)
	av.anim.speed_scale = 1.0
	_coach_action[i] = minf(t, av.anim.get_animation(anim_name).length)


## El cuarto árbitro levanta el cartel: sale `num_off` (rojo) y entra `num_on` (verde).
## Te sienta en el banquillo de tu equipo con tu aspecto y la equipación de calentar.
func seat_user(p: PlayerProfile, kit: Dictionary) -> Node3D:
	var bench: Array = _bench_people[0]
	if bench.is_empty():
		return null
	user_seat = bench[mini(4, bench.size() - 1)]
	var av: PlayerAvatar = user_seat.get_meta("avatar")
	av.apply_profile(p)
	var look := {"long_sleeves": true, "shorts_color": p.shorts, "socks_color": p.socks}
	look.merge(kit, true)
	av.set_colors(look)
	av.position.y = av.sit_offset(DUGOUT_SEAT) # tu estatura puede ser otra
	return user_seat


## `person` = quién entra (tu jugador desde el banco); si no, un suplente cualquiera.
func substitution(team: int, num_off: int, num_on: int, person: Node3D = null) -> void:
	_board_led[0].text = str(num_off)
	_board_led[1].text = str(num_on)
	_board_time = 6.5
	_board.visible = true
	var oav: PlayerAvatar = _official.get_meta("avatar")
	oav.pose_arms("board", 0.4)
	# El suplente que entra se levanta y va junto al cuarto árbitro, a la línea de banda
	if _sub_walker:
		_sub_walker.queue_free()
		_sub_walker = null
	var bench: Array = _bench_people[team]
	if person != null:
		bench.erase(person)
		bench.append(person)
	if not bench.is_empty():
		var p: Node3D = bench.pop_back()
		_parade_finish_node(p) # si aún iba camino del banquillo, ya está sentado
		var av: PlayerAvatar = p.get_meta("avatar")
		av.position.y = 0.0
		av.anim.play("idle", 0.3)
		# Se quita el peto de calentar: entra con la camiseta del partido
		if p != user_seat:
			var look: Dictionary = {"shirt_pattern": 0, "long_sleeves": false}
			look.merge(_kits[team], true)
			av.set_colors(look)
		_sub_walker = p
		_sub_phase = 0


func _process(delta: float) -> void:
	if _match == null or _match.ball == null:
		return
	_t += delta
	var b := _match.ball.global_position
	_update_parade(delta)
	for f in _followers:
		if not f.has_meta("parade"):
			_face(f, b, delta * 3.0)
	for pc: Array in _photo_cams:
		var pav: PlayerAvatar = pc[0]
		var pcam: Node3D = pc[1]
		pcam.global_position = pav.hands_position() + pav.global_transform.basis.z.normalized() * 0.1
		pcam.global_rotation = pav.global_rotation
	# DT: caminan por su área técnica siguiendo el juego, y saltan con los goles
	for i in _coaches.size():
		var c := _coaches[i]
		if c.has_meta("parade") or not c.visible:
			continue
		var home := _coach_home[i]
		var tx := home.x + clampf((b.x - home.x) * 0.12, -2.5, 2.5) + sin(_t * 0.35 + i * 2.0) * 1.2
		var av: PlayerAvatar = c.get_meta("avatar")
		# De vez en cuando grita o señala instrucciones a sus jugadores
		_coach_next[i] -= delta
		if _coach_next[i] <= 0.0:
			_coach_next[i] = randf_range(7.0, 16.0)
			_coach_gesture(i, ["yell", "point", "point", "argue_2", "clap"].pick_random(), 2.6)
		if _coach_action[i] > 0.0:
			_coach_action[i] -= delta
			_face(c, b, delta * 4.0)
			continue
		var moving: bool = absf(c.position.x - tx) > 0.05
		c.position.x = move_toward(c.position.x, tx, delta * 1.3)
		var want := "run" if moving else "idle"
		if av.anim.current_animation != want:
			av.anim.play(want, 0.3)
		av.anim.speed_scale = 0.45 if moving else 1.0
		_face(c, b, delta * 4.0)
	for t in 2:
		if _celebrate[t] > 0.0:
			_celebrate[t] -= delta
		for p: Node3D in _bench_people[t]:
			if p.has_meta("parade"):
				continue
			if p.has_meta("clap_t"):
				var left: float = float(p.get_meta("clap_t")) - delta
				if left <= 0.0:
					p.remove_meta("clap_t")
					(p.get_meta("avatar") as PlayerAvatar).anim.play(PlayerAvatar.SIT_ANIMS.pick_random(), 0.4)
				else:
					p.set_meta("clap_t", left)
			elif p != user_seat:
				# Siguen el partido con la mirada y se acomodan en el asiento cada tanto
				var sav: PlayerAvatar = p.get_meta("avatar")
				sav.look_at_point(b, 0.75)
				var left2: float = float(p.get_meta("fidget", randf_range(4.0, 14.0))) - delta
				if left2 <= 0.0 and _celebrate[t] <= 0.0:
					left2 = randf_range(8.0, 20.0)
					var cur := String(sav.anim.current_animation)
					var opts: Array = PlayerAvatar.SIT_ANIMS.filter(func(n: String) -> bool: return n != cur)
					sav.anim.play(opts.pick_random(), 0.8)
				p.set_meta("fidget", left2)
			if not (p.get_meta("avatar") as PlayerAvatar).anim.has_animation("sit_clap") and not p.has_meta("clap_t"):
				p.position.y = (p.get_meta("seat_y") as float) + (absf(sin(_t * 8.0 + p.position.x)) * 0.3 if _celebrate[t] > 0.0 else 0.0)
	_update_refs(b, delta)
	_update_sub(delta)
	_update_leavers(delta)
	# Cartel de cambios: arriba unos segundos, con los números parpadeando
	if _board_time > 0.0:
		_board_time -= delta
		_update_board()
		# Lo enseña a un lado y a otro de la grada
		var look := Vector3(_official.position.x + sin(_t * 0.9) * 6.0, 0.0, 0.0)
		_face(_official, look, delta * 3.0)
		if _board_time <= 0.0:
			_board.visible = false
			(_official.get_meta("avatar") as PlayerAvatar).pose_arms("", 0.4)
	else:
		_face(_official, b, delta * 2.0)
	_update_flags(delta)


## Árbitros: el central sigue la jugada en diagonal sin estorbar; cada asistente cubre su
## mitad por su banda. En la salida de los equipos caminan a `ref_targets`.
func _update_refs(b: Vector3, delta: float) -> void:
	var L := SoccerMatch.FIELD_LENGTH
	var W := SoccerMatch.FIELD_WIDTH
	if _card_t > 0.0:
		_update_card(delta)
	if not ref_targets.is_empty():
		for i in refs.size():
			if i < ref_delay.size() and float(ref_delay[i]) > 0.0:
				ref_delay[i] = float(ref_delay[i]) - delta
				refs[i].visible = float(ref_delay[i]) <= 0.0
				continue
			if refs[i].visible and refs[i].position.z < ref_hide_z:
				refs[i].visible = false # ya dentro del túnel
				continue
			if i < ref_targets.size() and refs[i].visible:
				var goal: Vector3 = ref_targets[i]
				if i < ref_via.size() and ref_via[i] != null:
					goal = ref_via[i]
					if Vector2(goal.x - refs[i].position.x, goal.z - refs[i].position.z).length() < 1.5:
						ref_via[i] = null
				# Al paso de los jugadores (~3.4 m/s), sin frenar en el punto de paso
				var spd := ref_walk_speed
				if not _walk(refs[i], goal, spd, delta):
					_face(refs[i], refs[i].position + Vector3.BACK, delta * 5.0)
		return
	var side := 1.0 if b.z <= 0.0 else -1.0
	var central := Vector3(clampf(b.x - 7.0, -L * 0.5 + 8.0, L * 0.5 - 8.0), 0.0,
			clampf(b.z + side * 11.0, -W * 0.5 + 3.0, W * 0.5 - 3.0))
	if _card_t <= 0.0:
		_walk(refs[0], central, 5.5, delta)
		_face(refs[0], b, delta * 4.0)
	# Jueces de línea: a la altura del penúltimo defensor (o del balón si va más
	# adelantado), como en la tele, para ver bien el fuera de juego
	var off0 := maxf(b.x, _match.offside_line_world(0))
	var off1 := minf(b.x, _match.offside_line_world(1))
	_walk(refs[1], Vector3(clampf(off0, 0.0, L * 0.5 - 1.0), 0.0, W * 0.5 + 0.9), 6.0, delta)
	_face(refs[1], Vector3(refs[1].position.x, 0.0, 0.0), delta * 4.0)
	_walk(refs[2], Vector3(clampf(off1, -L * 0.5 + 1.0, 0.0), 0.0, -W * 0.5 - 0.9), 6.0, delta)
	_face(refs[2], Vector3(refs[2].position.x, 0.0, 0.0), delta * 4.0)


## El central corre hacia `target` (el que hizo la falta) y le enseña la tarjeta en alto:
## amarilla, o roja si `red`. El infractor protesta.
func show_card(target: Node3D, red: bool) -> void:
	if refs.is_empty() or target == null:
		return
	if _card == null:
		var av: PlayerAvatar = refs[0].get_meta("avatar")
		var hand := ItemCatalog.find_bone(av.skeleton, "RightHand")
		var att := BoneAttachment3D.new()
		av.skeleton.add_child(att)
		att.bone_idx = hand
		_card = MeshInstance3D.new()
		var q := BoxMesh.new()
		var k := maxf(absf(av.skeleton.global_transform.basis.get_scale().y), 0.0001) # el esqueleto va en otra escala
		q.size = Vector3(0.17, 0.24, 0.015) / k
		_card.mesh = q
		_card_mat = StandardMaterial3D.new()
		_card_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_card.material_override = _card_mat
		_card.position = Vector3(0.0, 0.17, 0.03) / k
		att.add_child(_card)
	_card_mat.albedo_color = Color(0.9, 0.1, 0.1) if red else Color(1.0, 0.85, 0.05)
	_card.visible = false
	_card_target = target
	_card_t = 3.0
	# Si está lejos, el central "ya venía corriendo": aparece a unos metros (fuera de plano)
	var r := refs[0]
	var tp := target.global_position
	var off := Vector3(r.global_position.x - tp.x, 0.0, r.global_position.z - tp.z)
	if off.length() > 7.0:
		r.global_position = tp + off.normalized() * 6.0
	if target.has_method("play_action"):
		# Se levanta de la entrada y protesta
		get_tree().create_timer(0.7, false).timeout.connect(func() -> void:
			if is_instance_valid(target):
				target.play_action("argue", 1.0, 2.2))


func _update_card(delta: float) -> void:
	_card_t -= delta
	var r := refs[0]
	var av: PlayerAvatar = r.get_meta("avatar")
	if _card_t <= 0.0 or not is_instance_valid(_card_target):
		_card_t = 0.0
		_card.visible = false
		av.anim.play("idle", 0.3)
		av.pose_arms("", 0.3)
		return
	var tp := _card_target.global_position
	var away := Vector3(r.global_position.x - tp.x, 0.0, r.global_position.z - tp.z)
	if away.length() < 0.1:
		away = Vector3.BACK
	var spot := tp + away.normalized() * 1.4
	var near := Vector2(spot.x - r.global_position.x, spot.z - r.global_position.z).length() < 0.9
	if _card.visible or near or not _walk(r, spot, 7.0, delta):
		# Llegó: de cara al jugador, brazo arriba con la tarjeta
		_face(r, tp, delta * 8.0)
		if not _card.visible:
			# Saca la tarjeta del bolsillo y la levanta con el brazo estirado
			_card.visible = true
			av.anim.play("idle", 0.2)
			av.anim.speed_scale = 1.0
			av.pose_arms("card", 0.15)


## El que sale en un cambio: aparece donde estaba el jugador (mismo sitio y
## rumbo, con la camiseta del equipo; tu cara si eres tú) y anda hasta su
## banquillo, donde desaparece. Así en cada cambio se ve uno salir y otro entrar.
func walk_off(at: Vector3, yaw: float, team: int, prof: PlayerProfile = null) -> Node3D:
	var look: Dictionary = {"long_sleeves": false}
	look.merge(_kits[team], true)
	if prof != null:
		look.merge({"shorts_color": prof.shorts, "socks_color": prof.socks}, true)
	var n := _person(look)
	var av: PlayerAvatar = n.get_meta("avatar")
	if prof != null:
		av.apply_profile(prof)
		av.set_colors(look)
	n.position = Vector3(at.x, 0.0, at.z)
	n.rotation.y = yaw
	av.anim.play("walk" if av.anim.has_animation("walk") else "run", 0.2)
	var cx := -11.0 if team == 0 else 11.0
	n.set_meta("leave_to", Vector3(cx + randf_range(-2.0, 2.0), 0.0, -SoccerMatch.FIELD_WIDTH * 0.5 - 3.0))
	_leavers.append(n)
	return n


func _update_leavers(delta: float) -> void:
	for n: Node3D in _leavers.duplicate():
		if not is_instance_valid(n):
			_leavers.erase(n)
			continue
		if not _walk(n, n.get_meta("leave_to"), 1.5, delta):
			_leavers.erase(n)
			n.queue_free()


## El suplente que está entrando ahora (para la cámara), o null.
func current_sub_walker() -> Node3D:
	return _sub_walker


## El suplente: va a la banda junto al cuarto árbitro, espera el cartel y entra corriendo.
func _update_sub(delta: float) -> void:
	if _sub_walker == null:
		return
	var line_z := -SoccerMatch.FIELD_WIDTH * 0.5
	var spot := _official.position + Vector3(-0.9, 0.0, 0.9)
	if _sub_phase == 0:
		if not _walk(_sub_walker, spot, 3.0, delta):
			_face(_sub_walker, Vector3(spot.x, 0.0, 0.0), delta * 5.0)
			if _board_time < 1.0:
				_sub_phase = 1
	else:
		if not _walk(_sub_walker, Vector3(spot.x, 0.0, line_z + 9.0), 5.0, delta):
			sub_entered.emit(_sub_walker.global_position)
			if _sub_walker == user_seat:
				user_seat = null
			_sub_walker.queue_free()
			_sub_walker = null


## Lleva a una persona hacia `target` andando o corriendo; devuelve si se está moviendo.
## `brake` = false para puntos de paso: no frena encima (arranca-para-arranca robótico)
## y da por pasado el punto a ~0,9 m, de modo que la esquina sale en curva.
func _walk(n: Node3D, target: Vector3, max_speed: float, delta: float, brake := true) -> bool:
	var to := Vector3(target.x - n.position.x, 0.0, target.z - n.position.z)
	var d := to.length()
	var moving := d > (0.25 if brake else 0.9)
	var spd := 0.0
	if moving:
		spd = minf(max_speed, d * 1.5) if brake else max_speed
		# Avanza hacia donde mira (que gira de a poco hacia el punto): la ruta se curva
		# en vez de quebrarse en ángulos rectos.
		_face(n, n.global_position + to, delta * (6.0 if max_speed > 2.5 else 3.5))
		var fwd := Vector3(sin(n.rotation.y), 0.0, cos(n.rotation.y))
		var dir := to / d
		var blend := 0.6 if (not brake or d > 1.0) and fwd.dot(dir) > 0.3 else 0.0
		var step_dir := dir.lerp(fwd, blend).normalized()
		n.position += step_dir * minf(spd * delta, d)
	var av: PlayerAvatar = n.get_meta("avatar")
	var want := "run" if spd > 0.6 else "idle"
	# A paso de calle (desfile por el túnel), caminando de verdad: "run" a cámara
	# lenta parecía gente corriendo en el sitio.
	if want == "run" and spd < 2.2 and av.anim.has_animation("walk"):
		want = "walk"
	if av.anim.current_animation != want:
		av.anim.play(want, 0.25)
	if want == "run":
		av.anim.speed_scale = clampf(spd / 5.0, 0.4, 1.2)
	elif want == "walk":
		av.anim.speed_scale = clampf(spd / 1.4, 0.7, 1.4)
	else:
		av.anim.speed_scale = 1.0
	return moving


func _face(n: Node3D, target: Vector3, k: float) -> void:
	var d := target - n.global_position
	if Vector2(d.x, d.z).length() < 0.1:
		return
	n.rotation.y = lerp_angle(n.rotation.y, atan2(d.x, d.z), minf(1.0, k))


# ---------- desfile del banquillo por el túnel ----------

const PARADE_VIA_X := 4.5 # punto de paso a cada lado: rodea al cuarto árbitro y las mamparas


func _lane_x(team: int) -> float:
	return FieldBuilder.TUNNEL_X + (-0.7 if team == 0 else 0.7)


func _mouth_z() -> float:
	return -SoccerMatch.FIELD_WIDTH * 0.5 - FieldBuilder.SIDE_STANDS


## Salida: tras los titulares salen los suplentes (alternando equipos), los ayudantes y
## al final los dos técnicos. A veces se esperan y se dan la mano en la banda; otras
## sale uno antes, saluda a su grada y se va a su área sin mirar al otro.
func parade_in(t0: float) -> void:
	_parade.clear()
	var mz := _mouth_z()
	var line_z := -SoccerMatch.FIELD_WIDTH * 0.5
	var order := 0
	for k in 7:
		for t in 2:
			var bench: Array = _bench_people[t]
			if k >= bench.size():
				continue
			var p: Node3D = bench[k]
			var seat: Vector3 = p.get_meta("seat", p.position)
			var sx := signf(seat.x)
			var lx := _lane_x(t)
			_stand_up(p)
			p.position = Vector3(lx, 0.0, mz - 3.6)
			_parade_add(p, t0 + order * 0.5 + randf_range(0.0, 0.25), randf_range(1.6, 1.9), [
				{"to": Vector3(lx, 0.0, mz + 0.4)}, {"to": Vector3(lx, 0.0, line_z - 2.6)},
				{"to": Vector3(sx * PARADE_VIA_X, 0.0, line_z - 2.5)}, {"to": Vector3(seat.x, 0.0, line_z - 1.8)},
				{"to": seat}], "sit", true)
			order += 1
	var after := t0 + order * 0.5 + 0.6
	for t in _assistants.size():
		var a := _assistants[t]
		var home := a.position
		var lx := _lane_x(t)
		a.position = Vector3(lx, 0.0, mz - 3.6)
		_parade_add(a, after + t * 0.4 + randf_range(0.0, 0.3), 1.6, [
			{"to": Vector3(lx, 0.0, mz + 0.4)}, {"to": Vector3(lx, 0.0, line_z - 2.6)},
			{"to": Vector3(signf(home.x) * PARADE_VIA_X, 0.0, line_z - 2.5)}, {"to": home}], "stand", true)
	_coach_parade(after + 1.4, true)


## Vuelta al vestuario al final: el banquillo se levanta y entra de a poco; los
## técnicos se dan la mano (o uno se va enseguida) y se meten detrás.
func parade_out(t0: float) -> void:
	_parade_finish_all() # por si alguien no había llegado aún a su sitio
	var mz := _mouth_z()
	var line_z := -SoccerMatch.FIELD_WIDTH * 0.5
	_coach_parade(t0, false)
	for t in _assistants.size():
		var a := _assistants[t]
		var lx := _lane_x(t)
		_parade_add(a, t0 + 2.0 + randf_range(0.0, 1.5), 1.5, [
			{"to": Vector3(signf(a.position.x) * PARADE_VIA_X, 0.0, line_z - 2.5)},
			{"to": Vector3(lx, 0.0, line_z - 2.8)}, {"to": Vector3(lx, 0.0, mz - 0.4)},
			{"to": Vector3(lx, 0.0, mz - 4.4)}], "hide", false)
	var order := 0
	for k in 7:
		for t in 2:
			var bench: Array = _bench_people[t]
			if k >= bench.size():
				continue
			var p: Node3D = bench[k]
			var lx := _lane_x(t)
			var seat := p.position
			_parade_add(p, t0 + 1.0 + order * 0.55 + randf_range(0.0, 0.5), randf_range(1.3, 1.6), [
				{"stand": true}, {"to": Vector3(seat.x, 0.0, line_z - 1.8)},
				{"to": Vector3(signf(seat.x) * PARADE_VIA_X, 0.0, line_z - 2.5)},
				{"to": Vector3(lx, 0.0, line_z - 2.8)}, {"to": Vector3(lx, 0.0, mz - 0.4)},
				{"to": Vector3(lx, 0.0, mz - 4.4)}], "hide", false)
			order += 1


## Los dos técnicos: 65% se esperan y se dan la mano frente a la manga; si no, uno
## sale (o se va) antes y el otro unos segundos después, cada uno a lo suyo.
func _coach_parade(t0: float, entering: bool) -> void:
	if _coaches.size() < 2:
		return
	var mz := _mouth_z()
	var line_z := -SoccerMatch.FIELD_WIDTH * 0.5
	var shake := randf() < 0.65
	var first := randi() % 2
	for t in 2:
		var c := _coaches[t]
		var lx := _lane_x(t)
		var meet := Vector3(FieldBuilder.TUNNEL_X + (-0.48 if t == 0 else 0.48), 0.0, line_z - 2.4)
		var partner := _coaches[1 - t]
		var late := 0.0 if t == first else (0.4 if shake else randf_range(2.5, 4.0))
		var steps: Array = []
		if entering:
			var home := _coach_home[t]
			c.position = Vector3(lx, 0.0, mz - 3.6)
			steps.append({"to": Vector3(lx, 0.0, mz + 0.4)})
			if shake:
				steps.append_array([{"to": meet}, {"shake": partner, "t": 1.8}])
			else:
				steps.append({"to": Vector3(lx, 0.0, line_z - 2.6)})
				if t == first:
					steps.append({"clap": 1.6, "look": Vector3(lx, 0.0, mz)}) # saluda a la grada
			steps.append_array([{"to": Vector3(signf(home.x) * PARADE_VIA_X, 0.0, line_z - 2.5)}, {"to": home}])
			_parade_add(c, t0 + late, 1.4, steps, "coach", true)
		else:
			if shake:
				steps.append_array([{"to": meet}, {"shake": partner, "t": 1.8}])
			else:
				steps.append({"to": Vector3(signf(c.position.x) * PARADE_VIA_X, 0.0, line_z - 2.5)})
			steps.append_array([{"to": Vector3(lx, 0.0, line_z - 2.8)}, {"to": Vector3(lx, 0.0, mz - 0.4)},
					{"to": Vector3(lx, 0.0, mz - 4.4)}])
			_parade_add(c, t0 + late, 1.5 if shake or t == first else 1.9, steps, "hide", false)


func _parade_add(n: Node3D, delay: float, speed: float, steps: Array, end: String, hidden: bool) -> void:
	_parade_finish_node(n)
	n.set_meta("parade", true)
	if hidden:
		n.visible = false
	_parade.append({"n": n, "delay": delay, "speed": speed, "steps": steps, "i": 0, "end": end})


func _stand_up(p: Node3D) -> void:
	var av: PlayerAvatar = p.get_meta("avatar")
	av.position.y = 0.0
	av.anim.play("idle", 0.3)
	av.anim.speed_scale = 1.0


func _parade_entry(n: Node3D) -> Dictionary:
	for e: Dictionary in _parade:
		if e["n"] == n:
			return e
	return {}


func _update_parade(delta: float) -> void:
	var i := 0
	while i < _parade.size():
		var e: Dictionary = _parade[i]
		var n: Node3D = e["n"]
		if not is_instance_valid(n):
			_parade.remove_at(i)
			continue
		if float(e["delay"]) > 0.0:
			e["delay"] = float(e["delay"]) - delta
			i += 1
			continue
		n.visible = true
		var steps: Array = e["steps"]
		if int(e["i"]) >= steps.size():
			_parade_end(e)
			_parade.remove_at(i)
			continue
		var st: Dictionary = steps[int(e["i"])]
		var av: PlayerAvatar = n.get_meta("avatar")
		if st.has("to"):
			# Frena solo al final de un tramo (antes de sentarse, saludar o quedarse)
			var nxt: int = int(e["i"]) + 1
			var brake: bool = nxt >= steps.size() or not (steps[nxt] as Dictionary).has("to")
			if not _walk(n, st["to"], float(e["speed"]), delta, brake):
				e["i"] = nxt
		elif st.has("stand"):
			_stand_up(n)
			e["i"] = int(e["i"]) + 1
		elif st.has("clap"):
			if not st.has("on"):
				st["on"] = true
				if av.anim.has_animation("clap"):
					av.anim.play("clap", 0.25)
			_face(n, st["look"], delta * 6.0)
			st["clap"] = float(st["clap"]) - delta
			if float(st["clap"]) <= 0.0:
				e["i"] = int(e["i"]) + 1
		elif st.has("shake"):
			var partner: Node3D = st["shake"]
			var pe := _parade_entry(partner)
			_face(n, partner.position, delta * 6.0)
			# Espera a que el otro llegue a su punto; si no aparece, sigue solo
			var ready: bool = not pe.is_empty() and int(pe["i"]) < (pe["steps"] as Array).size() \
					and (pe["steps"] as Array)[int(pe["i"])].has("shake")
			st["wait"] = float(st.get("wait", 0.0)) + delta
			if ready or st.has("on"):
				if not st.has("on"):
					st["on"] = true
					av.pose_arms("shake", 0.3)
				st["t"] = float(st["t"]) - delta
				if float(st["t"]) <= 0.0:
					av.pose_arms("", 0.3)
					e["i"] = int(e["i"]) + 1
			elif float(st["wait"]) > 6.0 or pe.is_empty():
				e["i"] = int(e["i"]) + 1
		i += 1


## Deja a la persona donde termina su ruta, en su postura final.
func _parade_end(e: Dictionary) -> void:
	var n: Node3D = e["n"]
	var av: PlayerAvatar = n.get_meta("avatar")
	av.pose_arms("", 0.2)
	match String(e["end"]):
		"sit":
			n.position = n.get_meta("seat", n.position)
			n.rotation.y = 0.0 # de cara al campo
			_pose(av, "sit")
			n.remove_meta("parade")
		"hide":
			n.visible = false # sigue marcado: nadie lo vuelve a mover
		_:
			av.anim.play("idle", 0.3)
			av.anim.speed_scale = 1.0
			n.rotation.y = 0.0
			n.remove_meta("parade")


func _parade_finish_node(n: Node3D) -> void:
	var e := _parade_entry(n)
	if e.is_empty():
		return
	_parade.erase(e)
	var steps: Array = e["steps"]
	for k in range(steps.size() - 1, -1, -1):
		if (steps[k] as Dictionary).has("to"):
			n.position = (steps[k] as Dictionary)["to"]
			break
	n.visible = true
	_parade_end(e)


## Todos a su sitio ya (p. ej. al empezar desde el banquillo o al cerrar el partido).
func parade_finish() -> void:
	_parade_finish_all()


func _parade_finish_all() -> void:
	while not _parade.is_empty():
		_parade_finish_node((_parade[0] as Dictionary)["n"])


# ---------- piezas ----------

## Banquillo cubierto con asientos del color del equipo y los suplentes sentados.
func _dugout(center: Vector3, color: Color, team: int) -> void:
	var length := 9.0
	var glass := FieldBuilder.mat(Color(0.75, 0.85, 0.95, 0.3))
	var frame := Color(0.25, 0.27, 0.3)
	# Banquillo bajo (antes 2,3 m: tapaba la grada y se veía enorme)
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(length, DUGOUT_H, 0.15)), center + Vector3(0.0, DUGOUT_H * 0.5, -0.9), frame)
	var roof := MeshInstance3D.new()
	roof.mesh = FieldBuilder.box(Vector3(length, 0.08, 2.1))
	roof.material_override = glass
	roof.position = center + Vector3(0.0, DUGOUT_H, 0.1)
	roof.rotation.x = -0.12
	add_child(roof)
	for sx: float in [-1.0, 1.0]:
		var side := MeshInstance3D.new()
		side.mesh = FieldBuilder.box(Vector3(0.06, DUGOUT_H - 0.1, 2.0))
		side.material_override = glass
		side.position = center + Vector3(sx * length * 0.5, (DUGOUT_H - 0.1) * 0.5, 0.1)
		add_child(side)
	# Asientos y suplentes
	var seats := 8
	for i in seats:
		var x := center.x + (i - (seats - 1) * 0.5) * 1.0
		# Asiento a la altura a la que se sienta el modelo (antes 0,45: se hundían)
		FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(0.5, DUGOUT_SEAT, 0.5)), Vector3(x, DUGOUT_SEAT * 0.5, center.z - 0.35), color.darkened(0.3))
		FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(0.5, 0.62, 0.12)), Vector3(x, DUGOUT_SEAT + 0.31, center.z - 0.62), color.darkened(0.3))
		if i < 7:
			# Suplente con la camiseta del equipo de manga larga; algunos con el peto de calentar
			var look: Dictionary = {"shirt_color": color, "long_sleeves": true,
					"shorts_color": color.darkened(0.6), "socks_color": color}
			look.merge(_kits[team], true)
			if i % 3 == 0:
				look["shirt_pattern"] = 8
				look["shirt_color2"] = BIB
			var sub := _person(look, "sit")
			sub.position = Vector3(x, 0.0, center.z - 0.3)
			sub.set_meta("seat_y", 0.0)
			sub.set_meta("seat", sub.position)
			_bench_people[team].append(sub)


## Rectángulo blanco del área técnica.
func _technical_area(center: Vector3) -> void:
	var w := 10.0
	var d := 1.4
	var white := Color(0.95, 0.95, 0.95)
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(w, 0.02, 0.08)), center + Vector3(0.0, 0.01, d * 0.5), white)
	for sx: float in [-1.0, 1.0]:
		FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(0.08, 0.02, d)), center + Vector3(sx * w * 0.5, 0.01, 0.0), white)


## Túnel de vestuarios hueco: pasillo con luz bajo la grada y manga abierta hasta la valla.
## Los jugadores salen de dentro (ver SoccerMatch._start_walkout).
func _tunnel(mouth: Vector3) -> void:
	var c := Vector3(FieldBuilder.TUNNEL_X, 0.0, mouth.z)
	var w := 4.0      # ancho libre
	var h := 3.0      # alto del pasillo
	var depth := 4.0  # cuánto entra bajo la grada
	var wall := FieldBuilder.mat(Color(0.32, 0.34, 0.38))
	wall.cull_mode = BaseMaterial3D.CULL_DISABLED
	var floor_m := FieldBuilder.mat(Color(0.2, 0.21, 0.23))
	# Pasillo: suelo, paredes, techo y fondo (con la puerta de vestuarios)
	_tunnel_box(Vector3(w + 0.4, 0.05, depth + 3.6), c + Vector3(0.0, 0.025, -depth * 0.5 + 1.8), floor_m)
	for sx: float in [-1.0, 1.0]:
		_tunnel_box(Vector3(0.2, h, depth), c + Vector3(sx * (w * 0.5 + 0.1), h * 0.5, -depth * 0.5), wall)
	_tunnel_box(Vector3(w + 0.4, 0.2, depth), c + Vector3(0.0, h + 0.1, -depth * 0.5), wall)
	_tunnel_box(Vector3(w, h, 0.2), c + Vector3(0.0, h * 0.5, -depth), FieldBuilder.mat(Color(0.12, 0.13, 0.16)))
	var door := FieldBuilder.mat(Color(0.95, 0.9, 0.75))
	door.emission_enabled = true
	door.emission = Color(1.0, 0.92, 0.75)
	door.emission_energy_multiplier = 1.5
	_tunnel_box(Vector3(1.6, 2.2, 0.05), c + Vector3(0.0, 1.1, -depth + 0.12), door)
	# Luces del techo
	var lamp := FieldBuilder.mat(Color(1.0, 1.0, 0.95), true)
	for k in 3:
		_tunnel_box(Vector3(1.4, 0.05, 0.25), c + Vector3(0.0, h - 0.03, -0.6 - k * 1.2), lamp)
	var light := OmniLight3D.new()
	light.position = c + Vector3(0.0, h - 0.4, -depth * 0.5)
	light.omni_range = 5.0
	light.light_energy = 1.2
	add_child(light)
	# Macizos a los lados y losa encima: tapan el corte de la grada (sin peldaños a la vista)
	var gap := FieldBuilder.TUNNEL_GAP
	var gdepth := FieldBuilder.TUNNEL_ROWS * FieldBuilder.ROW_DEPTH
	var top := 0.9 + FieldBuilder.TUNNEL_ROWS * FieldBuilder.ROW_RISE
	var pier_w := gap - w * 0.5
	var concrete := FieldBuilder.mat(Color(0.5, 0.52, 0.56))
	for sx: float in [-1.0, 1.0]:
		_tunnel_box(Vector3(pier_w, top, gdepth), c + Vector3(sx * (w * 0.5 + pier_w * 0.5), top * 0.5, -gdepth * 0.5 + ROW_HALF), concrete)
	_tunnel_box(Vector3(gap * 2.0, top - h, gdepth), c + Vector3(0.0, h + (top - h) * 0.5, -gdepth * 0.5 + ROW_HALF), concrete)
	# Marco de la boca en la grada
	var frame := Color(0.2, 0.22, 0.26)
	FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(w + 1.2, 0.5, 0.5)), c + Vector3(0.0, h + 0.25, 0.0), frame)
	for sx: float in [-1.0, 1.0]:
		FieldBuilder.add_mesh(self, FieldBuilder.box(Vector3(0.4, h, 0.5)), c + Vector3(sx * (w * 0.5 + 0.4), h * 0.5, 0.0), frame)
	# Manga (fuelle) abierta por los dos lados, de la grada hasta la valla
	var length := FieldBuilder.SIDE_STANDS - FieldBuilder.SIDE_BOARDS + 0.6
	var tube := CylinderMesh.new()
	tube.top_radius = w * 0.5 + 0.15
	tube.bottom_radius = w * 0.5 + 0.15
	tube.height = length
	tube.radial_segments = 20
	tube.cap_top = false
	tube.cap_bottom = false
	var tube_m := FieldBuilder.mat(Color(0.88, 0.9, 0.93))
	tube_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = tube
	mi.material_override = tube_m
	mi.position = c + Vector3(0.0, 0.9, length * 0.5)
	mi.rotation.x = PI * 0.5
	add_child(mi)
	# Aros del fuelle
	for k in 4:
		var ring := TorusMesh.new()
		ring.inner_radius = w * 0.5 + 0.1
		ring.outer_radius = w * 0.5 + 0.3
		var rm := MeshInstance3D.new()
		rm.mesh = ring
		rm.material_override = FieldBuilder.mat(Color(0.75, 0.1, 0.12))
		rm.position = c + Vector3(0.0, 0.9, 0.2 + k * (length - 0.4) / 3.0)
		rm.rotation.x = PI * 0.5
		add_child(rm)
	var lab := Label3D.new()
	lab.text = "VESTUARIOS"
	lab.font_size = 48
	lab.pixel_size = 0.008
	lab.position = c + Vector3(0.0, h + 0.25, 0.27)
	add_child(lab)


func _tunnel_box(size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = FieldBuilder.box(size)
	mi.material_override = m
	mi.position = pos
	add_child(mi)


## Camarógrafo con cámara sobre trípode (o al hombro), con las manos en la cámara.
func _cameraman(pos: Vector3, tripod: bool) -> void:
	var p := _person({"shirt_color": Color(0.12, 0.12, 0.14), "long_sleeves": true, "long_pants": true,
			"shorts_color": Color(0.22, 0.22, 0.26)})
	p.position = pos
	var av: PlayerAvatar = p.get_meta("avatar")
	if tripod:
		var cam := _add_camera(p, Vector3(0.0, 1.45, 0.6), 1.0)
		# Mando de giro hacia la mano derecha (atrás a la derecha del operador)
		var bar := MeshInstance3D.new()
		bar.mesh = FieldBuilder.box(Vector3(0.03, 0.03, 0.34))
		bar.material_override = FieldBuilder.mat(Color(0.15, 0.15, 0.16))
		bar.position = Vector3(-0.12, -0.12, -0.32)
		bar.rotation.y = -0.45
		cam.add_child(bar)
		for k in 3:
			var a := TAU * k / 3.0
			var leg := MeshInstance3D.new()
			leg.mesh = FieldBuilder.box(Vector3(0.04, 1.35, 0.04))
			leg.material_override = FieldBuilder.mat(Color(0.15, 0.15, 0.15))
			leg.position = Vector3(sin(a) * 0.24, 0.65, 0.6 + cos(a) * 0.24)
			leg.rotation = Vector3(cos(a) * 0.17, 0.0, -sin(a) * 0.17)
			p.add_child(leg)
		av.pose_arms("cam_tripod", 0.01)
	else:
		_add_camera(p, Vector3(-0.3, 1.6, 0.16), 0.8)
		av.pose_arms("cam_shoulder", 0.01)
	_set_pose_seed(av)
	_followers.append(p)


func _set_pose_seed(av: PlayerAvatar) -> void:
	var ap := av.skeleton.get_children().filter(func(c: Node) -> bool: return c is ArmPose)
	if not ap.is_empty():
		(ap[0] as ArmPose).seed = randf() * 5.0


## Cámara (cuerpo + objetivo) como un nodo: se puede mover entera (la de fotos va en las manos).
func _add_camera(parent: Node3D, at: Vector3, size: float) -> Node3D:
	var holder := Node3D.new()
	holder.position = at
	parent.add_child(holder)
	var body := MeshInstance3D.new()
	body.mesh = FieldBuilder.box(Vector3(0.22, 0.26, 0.5) * size)
	body.material_override = FieldBuilder.mat(Color(0.08, 0.08, 0.09))
	holder.add_child(body)
	var lens := CylinderMesh.new()
	lens.top_radius = 0.08 * size
	lens.bottom_radius = 0.1 * size
	lens.height = 0.28 * size
	var lm := MeshInstance3D.new()
	lm.mesh = lens
	lm.material_override = FieldBuilder.mat(Color(0.18, 0.18, 0.2))
	lm.position = Vector3(0.0, 0.0, 0.36 * size)
	lm.rotation.x = PI * 0.5
	holder.add_child(lm)
	return holder


## Persona con el modelo de los jugadores. `look`: parámetros del shader del cuerpo
## (shirt_color, shirt_pattern, long_sleeves…). Mira hacia +Z.
## pose: "stand" (de pie, respirando), "sit" (sentado en el banquillo) o "kneel" (de rodillas).
func _person(look: Dictionary, pose := "stand") -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var av := PlayerAvatar.new()
	n.add_child(av)
	var c := {
		"skin_color": PlayerProfile.SKIN_TONES.pick_random(),
		"hair_color": PlayerProfile.HAIR_COLORS.pick_random(),
		"hair_style": [0, 0, 2, 1].pick_random(),
		"show_hair": true,
		"beard_style": randi() % 5 if randf() < 0.4 else 0,
		"boots_color": Color(0.06, 0.06, 0.07),
		"socks_color": Color(0.1, 0.1, 0.12),
		"shorts_color": Color(0.1, 0.1, 0.12),
		"shirt_pattern": 0,
		"long_sleeves": false,
		"long_pants": false,
	}
	c.merge(look, true)
	av.set_colors(c)
	av.set_body_scale(Vector3.ONE * randf_range(0.94, 1.03))
	n.set_meta("avatar", av)
	av.anim.play("idle")
	av.anim.seek(randf() * 2.0, true)
	if pose != "stand":
		_pose(av, pose)
	if OS.has_feature("mobile"):
		av.set_casts_shadow(false) # personal de banda: en el móvil sin sombra propia
	return n


## Pose fija girando los huesos de las piernas (el modelo no trae animación de sentarse).
func _pose(av: PlayerAvatar, pose: String) -> void:
	# De rodillas / agachado (fotógrafos): animaciones de Mixamo si las trae
	if pose == "kneel" and av.anim.has_animation("kneel"):
		# Solo de rodillas: agachado ("crouch") la cabeza va tan inclinada que la
		# cámara de fotos no llega a la cara
		av.anim.play("kneel")
		av.anim.seek(randf() * av.anim.current_animation_length, true)
		return
	# Sentado: animaciones de Mixamo si el modelo las trae (cada uno una distinta)
	if pose == "sit" and av.anim.has_animation("sit"):
		av.anim.play((PlayerAvatar.SIT_ANIMS + ["sit_talk"]).pick_random())
		av.anim.seek(randf() * av.anim.current_animation_length, true)
		av.position.y = av.sit_offset(DUGOUT_SEAT)
		return
	av.anim.seek(0.0, true)
	av.anim.pause()
	var sk := av.skeleton
	var bend := func(bone: String, deg: float) -> void:
		var i := sk.find_bone("mixamorig_" + bone)
		if i >= 0:
			sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(Vector3.RIGHT, deg_to_rad(deg)))
	if pose == "sit":
		bend.call("LeftUpLeg", SIT_THIGH)
		bend.call("RightUpLeg", SIT_THIGH)
		bend.call("LeftLeg", SIT_KNEE)
		bend.call("RightLeg", SIT_KNEE)
		av.position.y = SIT_DROP
	else:
		bend.call("RightUpLeg", SIT_THIGH)
		bend.call("RightLeg", SIT_KNEE)
		bend.call("LeftUpLeg", KNEEL_BACK)
		bend.call("LeftLeg", SIT_KNEE * 1.1)
		bend.call("Spine", 12.0)
		av.position.y = KNEEL_DROP


# ---------- cartel de cambios LED ----------

## Cartel electrónico: caja negra con borde, panel rojo (sale, flecha abajo) y verde
## (entra, flecha arriba) con números de LED, legible por las dos caras. Lo sostiene
## el cuarto árbitro a dos manos (ArmPose "board").
func _build_board() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = FieldBuilder.box(Vector3(0.78, 0.46, 0.07))
	body.material_override = FieldBuilder.mat(Color(0.07, 0.07, 0.09))
	root.add_child(body)
	var rim := MeshInstance3D.new()
	rim.mesh = FieldBuilder.box(Vector3(0.8, 0.03, 0.075))
	rim.material_override = FieldBuilder.mat(Color(0.75, 0.75, 0.8))
	rim.position = Vector3(0, 0.235, 0)
	root.add_child(rim)
	for side in 2:
		var x := -0.19 if side == 0 else 0.19
		var col := Color(1.0, 0.22, 0.18) if side == 0 else Color(0.25, 1.0, 0.4)
		for face: float in [1.0, -1.0]:
			# Panel de LED (apagado de fondo; brilla al parpadear) y el número encima
			var panel := MeshInstance3D.new()
			panel.mesh = FieldBuilder.box(Vector3(0.36, 0.38, 0.01))
			var pm := StandardMaterial3D.new()
			pm.albedo_color = col.darkened(0.85)
			pm.emission_enabled = true
			pm.emission = col
			pm.emission_energy_multiplier = 0.0
			panel.material_override = pm
			panel.position = Vector3(x * face, -0.02, 0.04 * face)
			root.add_child(panel)
			_board_lit.append(panel)
			var n := Label3D.new()
			n.font_size = 120
			n.pixel_size = 0.0022
			n.outline_size = 0
			n.modulate = col
			n.shaded = false
			n.position = Vector3(x * face, -0.03, 0.05 * face)
			n.rotation.y = 0.0 if face > 0.0 else PI
			n.set_meta("side", side)
			root.add_child(n)
			_board_led.append(n)
			# Flecha: abajo la de salida, arriba la de entrada
			var arrow := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.035
			cm.height = 0.05
			cm.radial_segments = 3
			arrow.mesh = cm
			var am := StandardMaterial3D.new()
			am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			am.albedo_color = col
			arrow.material_override = am
			arrow.position = Vector3(x * face, 0.135, 0.05 * face)
			arrow.rotation = Vector3(0.0, 0.0, PI if side == 0 else 0.0)
			root.add_child(arrow)
	# _board_led: [sale delante, sale detrás, entra delante, entra detrás] -> los de delante primero
	_board_led = [_board_led[0], _board_led[2], _board_led[1], _board_led[3]]
	return root


## El cartel, entre las manos (con los brazos ya puestos por ArmPose) y un poco por encima.
func _place_board() -> void:
	if not _board.visible:
		return
	var av: PlayerAvatar = _official.get_meta("avatar")
	_board.global_rotation = Vector3(0.0, _official.global_rotation.y, 0.0)
	_board.global_position = av.hands_position() + Vector3.UP * 0.05 + _board.global_basis.z * 0.06


## Anima los LED del cartel: al subir parpadea
## todo el panel, luego se encienden los números y de vez en cuando pasa un barrido de brillo.
func _update_board() -> void:
	var on := 6.5 - _board_time # tiempo con el cartel arriba
	for i in _board_lit.size():
		var side := i / 2
		var pm: StandardMaterial3D = _board_lit[i].material_override
		var flash := 1.0 if on < 0.7 and fmod(on, 0.2) < 0.1 else 0.0
		var sweep := maxf(0.0, 1.0 - absf(fmod(on * 0.8, 2.0) - 0.5 - side * 0.4) * 4.0) * 0.6
		pm.emission_energy_multiplier = flash * 1.5 + sweep
	for k in _board_led.size():
		var lbl := _board_led[k]
		var side := int(lbl.get_meta("side", 0))
		lbl.text = _board_led[side].text # la cara de atrás copia a la de delante
		lbl.visible = on > 0.7 + side * 0.15 # el de entrada se enciende un poco después
		lbl.modulate.a = 0.8 + 0.2 * sin(_t * 9.0 + side)


# ---------- banderines de los asistentes ----------

## Banderín en la mano derecha: palo y tela a cuadros amarillo/rojo que ondea.
func _build_flag(r: Node3D, i: int) -> Dictionary:
	var av: PlayerAvatar = r.get_meta("avatar")
	var hand := ItemCatalog.find_bone(av.skeleton, "RightHand")
	var att := BoneAttachment3D.new()
	av.skeleton.add_child(att)
	att.bone_idx = hand
	var k := maxf(absf(av.skeleton.global_transform.basis.get_scale().y), 0.0001)
	var holder := Node3D.new()
	holder.scale = Vector3.ONE / k
	att.add_child(holder)
	var stick := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = 0.5
	cm.radial_segments = 8
	stick.mesh = cm
	stick.material_override = FieldBuilder.mat(Color(0.12, 0.12, 0.14))
	stick.position = Vector3(0.0, 0.2, 0.0)
	holder.add_child(stick)
	var cloth := Node3D.new()
	cloth.position = Vector3(0.0, 0.42, 0.0)
	holder.add_child(cloth)
	for q in 4: # cuatro cuadros, alternando colores
		var sq := MeshInstance3D.new()
		sq.mesh = FieldBuilder.box(Vector3(0.008, 0.11, 0.14))
		var yellow := (q % 2 == 0) != (q >= 2)
		sq.material_override = FieldBuilder.mat(Color(1.0, 0.85, 0.1) if yellow else Color(0.95, 0.2, 0.15))
		sq.position = Vector3(0.0, -0.11 + (q / 2) * 0.11, 0.07 + (q % 2) * 0.14)
		cloth.add_child(sq)
	return {"ref": r, "cloth": cloth, "up": 0.0, "phase": float(i) * 1.7}


## El asistente levanta la bandera (fuera de juego) unos segundos. who = 0 o 1.
func flag_up(who: int, secs: float) -> void:
	if who < 0 or who >= _flags.size():
		return
	_flags[who].up = secs
	(_flags[who].ref.get_meta("avatar") as PlayerAvatar).pose_arms("flag", 0.25)


## La tela ondea siempre (más fuerte si la agita en alto).
func _update_flags(delta: float) -> void:
	for f: Dictionary in _flags:
		var cloth: Node3D = f.cloth
		var hard: bool = f.up > 0.0
		var amp := 0.45 if hard else 0.15
		cloth.rotation = Vector3(sin(_t * (9.0 if hard else 3.0) + f.phase) * amp * 0.3,
				sin(_t * (11.0 if hard else 4.0) + f.phase) * amp, 0.0)
		if hard:
			f.up -= delta
			if f.up <= 0.0:
				(f.ref.get_meta("avatar") as PlayerAvatar).pose_arms("", 0.4)
