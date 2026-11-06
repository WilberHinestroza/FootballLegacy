extends Node

## Prueba dirigida de NationalMatchSummary.tscn con estado REALISTA (a
## diferencia de ScenePathProbe, que la instancia en blanco — eso hace
## que el camino de "sin resultado real" navegue de una a Hub.tscn, una
## pantalla pesada que ScenePathProbe no llega a asentar en 2 frames).
## Acá se arma un MatchState real (fixture + resultado) antes de
## instanciar, para probar el camino que de verdad importa: aplicar
## caps/goles/asistencias y no crashear. Usa slot_3 (desechable, con
## backup/restore alrededor de la corrida).
##   godot --headless res://tools/NationalSummaryProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var p := PlayerData.new()
	p.player_name = "Probe Nacional"
	p.country = "Argentina"
	p.position = "ST"
	p.detailed_position = "DC"
	p.overall = 80
	p.potential = 85
	p.caps = 5
	p.international_goals = 2
	p.international_assists = 1
	p.stamina = 70
	p.fatigue_physical = 0.0
	p.injury_days_remaining = 0
	SaveManager.save_world_seed(20260906)
	SaveManager.save_player(p)
	WorldTickEngine.load_runtime()

	MatchState.fixture = {"competition": "qualifying", "result_key": "Q:CONMEBOL:0:Argentina:Brasil", "home_country": "Argentina", "away_country": "Brasil"}
	MatchState.match_result = {
		"score": {"home": 2, "away": 1}, "user_rating": 7.4,
		"user_goals": 1, "user_assists": 1, "user_injured": false,
	}
	MatchState.return_scene = "res://scenes/Selections/Selections.tscn"

	var packed: PackedScene = load("res://scenes/NationalMatchSummary/NationalMatchSummary.tscn")
	var inst: Node = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame

	var reloaded := SaveManager.load_player()
	var intl: Dictionary = SaveManager.load_international()
	var recorded: Dictionary = (intl.get("qualifying_results", {}) as Dictionary).get("Q:CONMEBOL:0:Argentina:Brasil", {})
	var rscore: Array = recorded.get("score", [])
	var score_ok: bool = rscore.size() == 2 and int(rscore[0]) == 2 and int(rscore[1]) == 1
	var ok: bool = reloaded != null and reloaded.caps == 6 and reloaded.international_goals == 3 and reloaded.international_assists == 2 \
		and score_ok and recorded.get("winner", "") == "home"
	print("caps=%s goals=%s assists=%s (esperado 6/3/2)" % [reloaded.caps if reloaded else "?", reloaded.international_goals if reloaded else "?", reloaded.international_assists if reloaded else "?"])
	print("override grabado: ", recorded)

	# --- Fatiga/lesión cruzada con el club (Parte 91): antes un partido
	# de selección no restaba NADA de fatigue_physical ni aplicaba la
	# lesión de verdad (solo se mostraba el aviso en pantalla). ---
	var fatigue_ok: bool = reloaded != null and reloaded.fatigue_physical > 0.0
	print("fatigue_physical tras el partido de selección: %s (esperado > 0)" % (reloaded.fatigue_physical if reloaded else "?"))
	ok = ok and fatigue_ok

	MatchState.fixture = {"competition": "qualifying", "result_key": "Q:CONMEBOL:1:Argentina:Brasil", "home_country": "Argentina", "away_country": "Brasil"}
	MatchState.match_result = {
		"score": {"home": 0, "away": 1}, "user_rating": 6.0,
		"user_goals": 0, "user_assists": 0, "user_injured": true,
	}
	var p2 := PlayerData.new()
	p2.player_name = "Probe Nacional 2"
	p2.country = "Argentina"
	p2.stamina = 70
	p2.fatigue_physical = 0.0
	p2.injury_days_remaining = 0
	SaveManager.save_player(p2)
	var inst2: Node = packed.instantiate()
	add_child(inst2)
	await get_tree().process_frame
	await get_tree().process_frame
	var reloaded2 := SaveManager.load_player()
	var injury_ok: bool = reloaded2 != null and reloaded2.injury_days_remaining > 0
	print("injury_days_remaining tras salir lesionado: %s (esperado > 0)" % (reloaded2.injury_days_remaining if reloaded2 else "?"))
	ok = ok and injury_ok

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
