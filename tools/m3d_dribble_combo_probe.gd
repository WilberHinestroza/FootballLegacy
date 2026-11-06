extends Node
## Sonda de regresión P1-05 · regate con combos.
##   godot --headless --path . res://tools/M3DDribbleComboProbe.tscn
##
## Valida que encadenar dos o tres quiebros en direcciones distintas suba la
## probabilidad de superar al defensor (según su fuerza defensiva), que repetir
## el mismo lado no cuente como combo y que el combo se corte al perder el balón
## o al vencer la ventana. Monta el partido 3D real para el camino completo.

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")
const DribbleCombo = preload("res://engine/match/m3d/DribbleCombo.gd")

var fails := 0
var m: SoccerMatch

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		fails += 1
		print("FALLA: ", msg)

func _near(a: float, b: float, eps := 0.001) -> bool:
	return absf(a - b) <= eps

func _ready() -> void:
	_test_pure()
	await _test_match()
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


## La matemática pura: dirección, ventana, bonus y resistencia del rival.
func _test_pure() -> void:
	var north := Vector3(0.0, 0.0, 1.0)
	var south := Vector3(0.0, 0.0, -1.0)
	var slight := Vector3(0.25, 0.0, 1.0).normalized()
	_check(not DribbleCombo.is_chain(north, north), "repetir el mismo lado cuenta como combo")
	_check(DribbleCombo.is_chain(north, south), "cambiar de lado no cuenta como combo")
	_check(not DribbleCombo.is_chain(north, slight), "un cambio mínimo de dirección cuenta como combo")
	_check(not DribbleCombo.is_chain(Vector3.ZERO, north), "un gesto vacío cuenta como combo")

	_check(DribbleCombo.next_chain(0, north, south, 1.0) == 1, "el primer quiebro no empieza en 1")
	_check(DribbleCombo.next_chain(1, north, south, 0.0) == 1, "la ventana vencida no corta el combo")
	_check(DribbleCombo.next_chain(1, north, north, 1.0) == 1, "el mismo lado no reinicia el combo")
	_check(DribbleCombo.next_chain(1, north, south, 1.0) == 2, "el segundo quiebro no encadena")
	_check(DribbleCombo.next_chain(2, north, south, 1.0) == 3, "el tercer quiebro no encadena")
	_check(DribbleCombo.next_chain(3, north, south, 1.0) == DribbleCombo.MAX_CHAIN,
		"el combo no tiene techo")

	var c1: float = DribbleCombo.beat_chance(0.7, 0.6, 1)
	var c2: float = DribbleCombo.beat_chance(0.7, 0.6, 2)
	var c3: float = DribbleCombo.beat_chance(0.7, 0.6, 3)
	_check(c2 > c1 and c3 > c2, "el combo no suma probabilidad de regate")
	_check(DribbleCombo.beat_chance(0.9, 0.1, 1) > DribbleCombo.beat_chance(0.4, 0.1, 1),
		"el regate del jugador no mejora la chance")
	_check(DribbleCombo.beat_chance(0.7, 0.9, 1) < DribbleCombo.beat_chance(0.7, 0.1, 1),
		"la fuerza defensiva del rival no baja la chance")
	_check(DribbleCombo.beat_chance(0.7, 0.5, 2, true) < DribbleCombo.beat_chance(0.7, 0.5, 2),
		"el portero no resiste más que un defensor")
	_check(DribbleCombo.beat_chance(1.0, 0.0, 3) <= 0.95, "la chance de regate no tiene techo")
	_check(DribbleCombo.beat_chance(0.0, 1.0, 1) >= 0.15, "la chance de regate no tiene piso")
	_check(DribbleCombo.stun_time(2) > DribbleCombo.stun_time(1)
		and DribbleCombo.stun_time(3) > DribbleCombo.stun_time(2),
		"el combo no deja al rival mareado más tiempo")


func _test_match() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	pl.avatar = Avatar.random_config(1234)
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	fx["competition"] = "cup"
	fx["round_name"] = "Octavos de final"
	fx["is_knockout"] = true
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	var mine: MatchTeam = MatchState.home_team if String(fx.get("home_club_id", "")) == pl.club_id else MatchState.away_team
	var u: PlayerData = MatchState.user_player
	if not mine.starting_xi.has(u):
		mine.bench.erase(u)
		for i in mine.starting_xi.size():
			if (mine.starting_xi[i] as PlayerData).position == u.position:
				mine.starting_xi[i] = u
				break
	if not Match3DBridge.supported():
		_check(false, "el partido 3D no está soportado en esta configuración")
		return
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	await get_tree().process_frame
	m = scr._match
	_check(m != null, "el partido 3D se montó correctamente")
	if m == null:
		return
	if m.state == m.State.WALKOUT:
		m._end_walkout()
	if m.star == null:
		_check(false, "no hay jugador estrella")
		scr.queue_free()
		return

	m.state = m.State.MOMENT
	m.moment_type = m.Moment.ATTACK
	m.human = m.star
	m._give_ball_now(m.star)
	m.star.global_position = Vector3(0.0, 0.0, 0.0)
	m.star.stats["dribbling"] = 95
	for o: SoccerPlayer in m.teams[1]:
		o.global_position = Vector3(0.0, 0.0, 30.0)
	var rival: SoccerPlayer = m.teams[1][0]
	rival.global_position = m.star.global_position + Vector3(0.0, 0.0, 1.2)
	rival.stats["strength"] = 10
	rival.stats["decision_making"] = 10
	rival.stats["speed"] = 10

	# Primer quiebro: combo 1.
	m._reset_dodge_combo()
	m._do_dodge(Vector3(0.0, 0.0, 1.0))
	_check(m._dodge_chain == 1, "el primer quiebro no empieza el combo en 1")
	_check(m.star.dodge_timer > 0.0, "el quiebro no protege el balón")
	_check(m._dodge_window > 0.0, "el primer quiebro no abre la ventana del combo")

	# Segundo y tercero, cambiando de lado dentro de la ventana.
	m._do_dodge(Vector3(0.0, 0.0, -1.0))
	_check(m._dodge_chain == 2, "el segundo quiebro no encadena")
	m._do_dodge(Vector3(0.0, 0.0, 1.0))
	_check(m._dodge_chain == 3, "el tercer quiebro no encadena")
	m._do_dodge(Vector3(0.0, 0.0, -1.0))
	_check(m._dodge_chain == DribbleCombo.MAX_CHAIN, "el combo del partido no tiene techo")

	# La ventana se agota y el combo vuelve a cero.
	m._dodge_window = 0.0
	m._update_human(0.016)
	_check(m._dodge_chain == 0, "la ventana vencida no corta el combo en el partido")

	# Repetir el mismo lado no encadena.
	m._do_dodge(Vector3(0.0, 0.0, 1.0))
	m._do_dodge(Vector3(0.1, 0.0, 1.0).normalized())
	_check(m._dodge_chain == 1, "el partido encadena quiebros en el mismo lado")

	# Perder el balón corta el combo.
	m._dodge_chain = 3
	m._give_ball(rival)
	_check(m._dodge_chain == 0 and m._dodge_window == 0.0,
		"perder el balón no corta el combo")

	scr.queue_free()
	await get_tree().process_frame
