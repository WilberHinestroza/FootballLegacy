extends Node
## PELÍCULA de jugadas dentro del juego real (FootballLegacy H): carga slot_3,
## abre el partido y fuerza varias jugadas en la cancha en vivo; guarda un
## cuadro cada 0,5 s en res://_pixellab_preview/film/<tipo>_NN.png.
##   godot --path . --resolution 1170x540 res://tools/PlayFilmProbe.tscn
## Solo lee la partida (no guarda nada).

const KINDS := ["long_shot", "key_pass", "distribution", "penalty"]

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	var player: PlayerData = SaveManager.load_player()
	var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	var fixture: Dictionary = WorldTickEngine.next_user_fixture(player.club_id)
	var prep: Dictionary = MatchLauncher.prepare(world, player, fixture, "res://scenes/Hub/Hub.tscn", false)
	if not bool(prep.get("ok", false)):
		print("FILM FALLA: no se pudo preparar el partido")
		get_tree().quit(1)
		return
	LiveBridge.test_auto = true
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/Match/Match.tscn")
	_run()

func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	var cs: Node = get_tree().current_scene
	cs._ensure_live_bridge()
	var b: LiveBridge = cs._live_bridge
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_pixellab_preview/film"))
	for k in KINDS:
		var done := [false]
		var fn := func() -> void:
			var r: Dictionary = await b.play({"minute": 60, "kind": k, "options": [{"kind": k}], "narration": ""})
			print("FILM %s -> %s" % [k, r.get("outcome", "?")])
			done[0] = true
		fn.call()
		var i: int = 0
		while not done[0] and i < 16:
			await get_tree().create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/film/%s_%02d.png" % [k, i]))
			i += 1
		while not done[0]:
			await get_tree().create_timer(0.2).timeout
	get_tree().quit(0)
