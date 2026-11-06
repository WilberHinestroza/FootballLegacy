extends Node

## Prueba dirigida del bug real reportado por Wilber: "el popup de si
## acerté o no también debería parar el tiempo para evitar que se
## superpongan situaciones" — antes MatchEvent.Type.DECISION_RESULT no
## estaba en la lista de eventos que prenden _pending_ack en
## MatchEngine._emit(), así que el motor seguía simulando mientras el
## popup de ACERTASTE/FALLASTE seguía en pantalla. Se corrigió sumándolo
## a esa lista (Match.gd ahora avisa al motor cuando el popup se cierra
## solo, por su propio timer — ver Match._process()/_flash_result()).
## Test directo y chico: instancia un MatchEngine real (instant_mode=
## FALSE, para que el switch de pausa de _emit() SÍ corra) y confirma que
## emitir un DECISION_RESULT deja _pending_ack en true — sin correr un
## partido entero.
##   godot --headless res://tools/DecisionResultPauseProbe.tscn

func _ready() -> void:
	var p := PlayerData.new()
	p.player_name = "Probe"
	p.overall = 75
	var home := MatchTeam.new()
	home.starting_xi = [p]
	var away := MatchTeam.new()
	var opp := PlayerData.new()
	opp.player_name = "Rival"
	opp.position = "GK"
	away.starting_xi = [opp]
	var engine = MatchEngine.new(home, away, p, false, false) # instant_mode=false

	var ok: bool = true
	print("_pending_ack antes de emitir: %s (esperado false)" % engine._pending_ack)
	if engine._pending_ack:
		print("FALLA: _pending_ack ya arrancaba en true")
		ok = false

	engine._emit(MatchEvent.Type.DECISION_RESULT, 10, {"kind": "shot_on_goal", "success": true, "rating_delta": 0.5})
	print("_pending_ack tras emitir DECISION_RESULT: %s (esperado true)" % engine._pending_ack)
	if not engine._pending_ack:
		print("FALLA: DECISION_RESULT debería dejar _pending_ack=true (el motor debe esperar a que Match.gd cierre el popup)")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
