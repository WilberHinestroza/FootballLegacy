extends Node
## Sonda de BallContact (conducción a toques, choque de hombros, calidad del golpeo).
##   godot --headless --path . res://tools/M3DBallContactProbe.tscn

var fails := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		fails += 1
		print("FALLA: ", msg)


func _ready() -> void:
	# Toque: el buen regateador lo lleva más pegado; esprintar lo alarga
	_check(BallContact.touch_length(0.9, 0.9, 0.0) < BallContact.touch_length(0.3, 0.3, 0.0), "buen regate = toque más corto")
	_check(BallContact.touch_length(0.5, 0.5, 1.0) > BallContact.touch_length(0.5, 0.5, 0.0), "esprintar alarga el toque")
	_check(BallContact.exposure(0.0) == 0.0 and BallContact.exposure(99.0) == 1.0, "exposición entre 0 y 1")
	# Entradas: con el balón suelto se contiene más cerca, se llega más lejos y se gana más
	_check(BallContact.contain_distance(1.0) < BallContact.contain_distance(0.0), "con balón suelto se acerca")
	_check(BallContact.tackle_reach(1.0) > BallContact.tackle_reach(0.0), "con balón suelto llega desde más lejos")
	_check(BallContact.tackle_bonus(1.0) > 0.0 and BallContact.tackle_bonus(0.0) < 0.0, "entrar al mal toque premia; al balón pegado castiga")
	_check(BallContact.tackle_urge(0.9, 0.0) < BallContact.tackle_urge(0.2, 0.0), "el que lee bien no entra con el balón pegado")
	_check(BallContact.tackle_urge(0.9, 1.0) > BallContact.tackle_urge(0.9, 0.0) * 3.0, "el que lee bien espera el mal toque")
	# Hombros: el más fuerte gana, dentro de unos límites
	var strong := BallContact.shoulder_win_chance(0.9, 0.3, 0.3)
	var weak := BallContact.shoulder_win_chance(0.3, 0.9, 0.9)
	_check(strong > 0.7 and weak < 0.3, "el defensor fuerte suele ganar el choque (%.2f / %.2f)" % [strong, weak])
	_check(strong <= 0.85 and weak >= 0.15, "nunca es seguro")
	_check(BallContact.stumble_time(1.0) > BallContact.stumble_time(0.0), "perder claro tambalea más")
	_check(BallContact.stumble_error(0.7) > BallContact.stumble_error(0.0) and BallContact.stumble_error(0.0) == 1.0, "tambaleándose se falla más")
	_check(not BallContact.shoulder_loses_ball(0.2, 1.0), "con el balón pegado no se pierde por un choque")
	# Golpeo
	var clean := BallContact.strike(0.1, 10.0)
	var jam := BallContact.strike(-0.45, 10.0)
	var far := BallContact.strike(0.9, 10.0)
	var twist := BallContact.strike(0.1, 150.0)
	_check(clean.kind == "clean" and float(clean.error) < 1.0 and float(clean.power) == 1.0, "golpe limpio: preciso y con toda la fuerza")
	_check(jam.kind == "jammed" and float(jam.power) < 0.9 and float(jam.error) > 1.2, "balón pegado: golpe mordido")
	_check(far.kind == "stretched" and float(far.error) > 1.2, "balón largo: estirado")
	_check(twist.kind == "twisted" and float(twist.error) > 1.5, "girarse mucho: forzado")
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)
