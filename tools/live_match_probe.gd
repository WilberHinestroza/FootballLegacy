extends Node
## PARTIDO REAL con la jugada EN VIVO (FootballLegacy H): carga slot_3, arma
## el próximo partido del calendario (igual que el Hub con MatchLauncher) y
## abre la pantalla de partido. Los momentos se juegan solos: cada pausa se
## reanuda sola y la IA mueve a tu jugador. Imprime cada momento y el final.
##   godot --path . res://tools/LiveMatchProbe.tscn
## Usa la COPIA de las partidas (user:// de "FootballLegacy H").

var _t0: int = 0

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	var player: PlayerData = SaveManager.load_player()
	var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	var fixture: Dictionary = WorldTickEngine.next_user_fixture(player.club_id)
	print("LIVE fixture: ", fixture.get("home_club_id", "?"), " vs ", fixture.get("away_club_id", "?"), " comp=", fixture.get("competition", "?"))
	var prep: Dictionary = MatchLauncher.prepare(world, player, fixture, "res://scenes/Hub/Hub.tscn", false)
	if not bool(prep.get("ok", false)):
		print("LIVE FALLA: no se pudo preparar el partido")
		get_tree().quit(1)
		return
	LiveBridge.test_auto = true
	MatchState.engine.decision_requested.connect(func(s: Dictionary) -> void:
		print("LIVE momento t=%.1f %d' %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, int(s.get("minute", 0)), String(s.get("kind", ""))]))
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/Match/Match.tscn")
	_t0 = Time.get_ticks_msec()
	_force_moments()
	_watch()

## Capturas de la pantalla de partido en horizontal (relato + jugada en vivo).
func _shots() -> void:
	for i in 4:
		await get_tree().create_timer(3.0 if i == 0 else 4.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/Match_%d.png" % i))
		print("LIVE captura ", i)
	get_tree().quit(0)

## Juega a la fuerza varios momentos con los equipos reales del partido.
func _force_moments() -> void:
	await get_tree().create_timer(3.0).timeout
	var cs: Node = get_tree().current_scene
	if cs == null:
		return
	cs._ensure_live_bridge()
	var b: LiveBridge = cs._live_bridge
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/Live_idle.png"))
	print("LIVE equipo: ", b.m.user.pname, " (", b.m.user.code, ") VEL=", b.m.user.st("speed"), " TIR=", b.m.user.st("shooting"))
	_snap_live()
	for k in ["shot_on_goal", "key_pass", "tackle", "dribble"]:
		var r: Dictionary = await b.play({"minute": 30, "kind": k, "options": [{"kind": k}], "narration": ""})
		print("LIVE forzado %s -> %s" % [k, r])
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/Live_back.png"))

func _watch() -> void:
	while Time.get_ticks_msec() - _t0 < 900000:
		await get_tree().create_timer(0.5).timeout
		var cs: Node = get_tree().current_scene
		if cs == null:
			continue
		var path: String = cs.scene_file_path
		if path.contains("MatchSummary"):
			print("LIVE FIN t=%.1f resultado: " % ((Time.get_ticks_msec() - _t0) / 1000.0), MatchState.match_result.get("score", "?"), " nota=", MatchState.last_user_rating)
			get_tree().quit(0)
			return
		if "halftime_panel" in cs and cs.halftime_panel != null and cs.halftime_panel.visible:
			await get_tree().create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/Halftime.png"))
			cs._on_continue_second_half_pressed()
	print("LIVE FALLA: el partido no terminó en 15 minutos")
	get_tree().quit(1)

func _snap_live() -> void:
	for i in 3:
		await get_tree().create_timer(0.5 if i == 0 else 1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/Live_%d.png" % i))
