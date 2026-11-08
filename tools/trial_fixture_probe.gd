extends Node

## Regresión (8-nov, Wilber: "cuando cree un nuevo personaje, el partido de
## exhibicion fue un partido de otro slot"). La prueba al crear personaje no
## pone fixture y heredaba el del último partido jugado en la sesión.
##   godot --headless res://tools/TrialFixtureProbe.tscn

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")

func _ready() -> void:
	var fails: int = 0
	# Partido anterior de otra carrera, con todo lo suyo
	MatchState.fixture = {"competition": "cont1", "home_club_id": "x_old_home", "away_club_id": "x_old_away"}
	MatchState.ball_design = 3
	MatchState.kit_home_away = true
	var p := PlayerData.new()
	p.player_name = "Probe Prueba"
	p.overall = 55
	p.potential = 75
	p.position = "MF"
	p.country = "Argentina"
	var trial := CareerSetup.build_trial_teams(p)
	MatchState.start_new_match(trial["home"], trial["away"], p)
	if not MatchState.fixture.is_empty():
		print("FALLO: la prueba hereda el fixture anterior: ", MatchState.fixture)
		fails += 1
	if MatchState.ball_design != -1 or MatchState.kit_home_away:
		print("FALLO: balón/camisetas del partido anterior")
		fails += 1
	var cfg: Dictionary = Match3DBridge.build_config(func(_r): pass)
	print("3D: ", cfg.get("home_name"), " vs ", cfg.get("away_name"))
	if String(cfg.get("home_name")) != "Prueba A" or String(cfg.get("away_name")) != "Prueba B":
		print("FALLO: el 3D no muestra Prueba A vs Prueba B")
		fails += 1
	print("PROBE OK (0 fallos)" if fails == 0 else "PROBE FALLÓ (%d)" % fails)
	get_tree().quit(fails)
