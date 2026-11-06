extends Node

## Prueba dirigida del rediseño de la curva de estamina (Parte 91, pedido
## de Wilber jugando de titular: "la estamina no me baja hasta el segundo
## tiempo, debería bajar desde el primer minuto, en el entretiempo
## recupera un poco, y en el segundo tiempo sigue bajando si sigo
## jugando"). Antes MatchEngine._fatigue_precision_penalty() daba 0 fijo
## para un titular hasta el min 46 — ahora corre desde el min 0.
## No toca ningún slot de guardado — todo en memoria.
##   godot --headless res://tools/StaminaCurveProbe.tscn

func _ready() -> void:
	var problems: int = 0

	var starter := PlayerData.new()
	starter.player_name = "Titular"
	starter.stamina = 60
	starter.overall = 70
	var home := MatchTeam.new()
	home.starting_xi = [starter]
	var away := MatchTeam.new()
	away.starting_xi = [PlayerData.new()]
	var engine := MatchEngine.new(home, away, starter, false, true)

	var s0: float = engine.stamina_pct(0)
	var s30: float = engine.stamina_pct(30)
	var s45: float = engine.stamina_pct(45)
	var s46: float = engine.stamina_pct(46)
	var s70: float = engine.stamina_pct(70)
	var s90: float = engine.stamina_pct(90)
	print("titular: min0=%.1f min30=%.1f min45=%.1f min46=%.1f min70=%.1f min90=%.1f" % [s0, s30, s45, s46, s70, s90])

	if s30 >= s0:
		print("FALLA 1: la estamina de un titular debería empezar a bajar ANTES del entretiempo (min30 < min0)")
		problems += 1
	if s45 >= s30:
		print("FALLA 2: debería seguir bajando durante el 1er tiempo (min45 < min30)")
		problems += 1
	if s46 <= s45:
		print("FALLA 3: en el entretiempo debería recuperar un poco (min46 > min45)")
		problems += 1
	if s70 >= s46:
		print("FALLA 4: si sigue jugando el 2do tiempo, debería seguir bajando (min70 < min46)")
		problems += 1
	if s90 >= s70:
		print("FALLA 5: debería seguir bajando hasta el final (min90 < min70)")
		problems += 1
	if s90 < 4.0 - 0.01:
		print("FALLA 6: el piso de la barra es 4.0, min90 dio %.2f" % s90)
		problems += 1

	# Suplente que entra en el 2do tiempo (min 60): fresco hasta entrar,
	# igual que antes de este cambio — no debe arrancar a bajar antes.
	var sub := PlayerData.new()
	sub.player_name = "Suplente"
	sub.stamina = 60
	sub.overall = 70
	var home2 := MatchTeam.new()
	home2.starting_xi = [PlayerData.new()]
	home2.bench = [sub]
	var away2 := MatchTeam.new()
	away2.starting_xi = [PlayerData.new()]
	var engine2 := MatchEngine.new(home2, away2, sub, false, true)
	engine2._user_is_on_pitch = false
	var before_sub: float = engine2.stamina_pct(50)
	engine2._user_is_on_pitch = true
	engine2._user_on_minute = 60
	var at_entry: float = engine2.stamina_pct(60)
	var after_entry: float = engine2.stamina_pct(80)
	print("suplente: banco(min50)=%.1f al_entrar(min60)=%.1f jugando(min80)=%.1f" % [before_sub, at_entry, after_entry])
	if before_sub < 99.9:
		print("FALLA 7: un suplente en el banco no debería perder estamina")
		problems += 1
	if at_entry < 99.9:
		print("FALLA 8: un suplente recién entrado debería estar fresco (100)")
		problems += 1
	if after_entry >= at_entry:
		print("FALLA 9: un suplente que sigue jugando debería empezar a bajar")
		problems += 1

	print("PROBE ", "OK" if problems == 0 else "FAIL (%d)" % problems)
	get_tree().quit(1 if problems > 0 else 0)
