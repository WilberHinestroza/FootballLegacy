extends Node

## Prueba dirigida: "las pantallas de después de un partido de selección
## deben ser iguales a las de clubes — falta la pantalla de después y la
## opción de entrevista". NationalMatchSummary.gd pasó de un resumen
## MÍNIMO (marcador + tu nota + caps) a tener las MISMAS pestañas
## (Estadísticas/Valoraciones), figura del partido y botón de entrevista
## que MatchSummary.gd (clubes) — reusando los mismos componentes
## compartidos. Este probe arma un MatchState real (fixture + resultado
## de selección, actuación destacada) e instancia la escena real para
## confirmar que renderiza sin crash, las pestañas cambian, la X del
## botón de entrevista aparece cuando corresponde, y "Continuar" avanza
## el día (mismo criterio que MatchSummary).
##   godot --headless res://tools/NationalMatchSummaryProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)

	var p := PlayerData.new()
	p.player_name = "Probe Selección"
	p.country = "Argentina"
	p.club_id = "c_10_0"
	p.position = "ST"
	p.detailed_position = "DC"
	p.overall = 80
	p.caps = 3
	SaveManager.save_world_seed(world_seed)
	SaveManager.save_player(p)
	var season: Dictionary = SeasonCalendar.build_season(world, 10, 0, 2026, "c_10_0", world_seed)
	season["current_epoch_day"] = 67
	SaveManager.save_season(season)
	WorldTickEngine.load_runtime()

	MatchState.fixture = {
		"home_country": "Argentina", "away_country": "Uruguay",
		"competition": "qualifying", "is_knockout": false, "round_name": "",
	}
	MatchState.match_result = {
		"score": {"home": 2, "away": 1},
		"user_goals": 2, "user_assists": 0,
		"user_rating": 8.4,
		"shootout_winner": "", "user_red_carded": false, "user_injured": false,
		"match_stats": {
			"possession_home": 58,
			"home": {"shots": 12, "on_target": 6, "corners": 5, "fouls": 8},
			"away": {"shots": 7, "on_target": 2, "corners": 3, "fouls": 10},
		},
		"player_ratings": [
			{"name": "Probe Selección", "team": "home", "position": "ST", "rating": 8.4, "is_user": true},
			{"name": "Rival Uruguayo", "team": "away", "position": "DF", "rating": 5.1, "is_user": false},
		],
	}
	MatchState.return_scene = "res://scenes/Hub/Hub.tscn"
	MatchState.user_player = p

	var packed: PackedScene = load("res://scenes/NationalMatchSummary/NationalMatchSummary.tscn")
	var inst = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame

	var ok: bool = true
	print("interview_button.visible (2 goles, nota 8.4 -> debería ser destacada): %s" % inst.interview_button.visible)
	if not inst.interview_button.visible:
		print("FALLA: con 2 goles y nota 8.4 debería mostrarse la opción de entrevista")
		ok = false

	print("caps tras el partido: %d (esperado 4)" % inst._player.caps)
	if inst._player.caps != 4:
		ok = false

	var stats_children: int = inst.detail_box.get_child_count()
	print("hijos de la pestaña Estadísticas (MVP + Tu partido + Stats): %d" % stats_children)
	if stats_children < 3:
		print("FALLA: se esperaban varias tarjetas en la pestaña de estadísticas")
		ok = false

	inst._on_tab("ratings")
	await get_tree().process_frame
	var ratings_children: int = inst.detail_box.get_child_count()
	print("hijos de la pestaña Valoraciones: %d (esperado >= 2: los botones + al menos 1 fila)" % ratings_children)
	if ratings_children < 2:
		ok = false

	# No se llama a _on_continue_pressed()/_leave() de verdad: termina en
	# get_tree().change_scene_to_file(), que en este probe corrompería el
	# árbol (mismo motivo por el que NationalCallUpProbe evita llamar el
	# método completo — ver feedback_test_methodology). La lógica de
	# avance de día se revisó a mano en el código: _leave() replica
	# exactamente el mismo bloque que MatchSummary._on_continue_pressed().

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
