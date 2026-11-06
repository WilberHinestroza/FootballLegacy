extends "res://tools/ui_gallery_probe.gd"
## Capturas REALES de cada minijuego de la cancha (10-oct), a tamaño de
## celular, forzando el momento clave. Carrera desechable en slot_3.
##   godot --path . --resolution 432x936 res://tools/MinigameShotProbe.tscn
var _tag: String = ""
func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/mg_%s%s.png" % [_tag, name]))

func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _force(m: Node, kind: String) -> void:
	m.call("_on_decision_requested", {"minute": 30, "kind": kind, "player": MatchState.user_player,
		"narration": "Prueba.", "options": [{"kind": kind, "difficulty": 0.45, "label": kind, "risk": "media"}]})
	await _wait(6)
	m.call("_on_choice_pressed", kind)
	await _wait(45)

func _ready() -> void:
	_seed_career()
	await get_tree().process_frame
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	var m: Node = (load("res://scenes/Match/Match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	await _wait(200)   # que pasen el saque y los carteles de arranque
	# Cámara opcional por argumento:  -- tv   /  -- iso
	var args := OS.get_cmdline_user_args()
	var cam: String = String(args[0]) if args.size() > 0 else "arco"
	var pv: PitchView = m.get("_pitch")
	if pv != null and cam != "arco":
		pv.set_cam_mode(cam)
	_tag = "" if cam == "arco" else cam + "_"
	for kind in ["shot_on_goal", "key_pass", "dribble", "tackle"]:
		await _force(m, kind)
		_shot(kind)
		if kind == "shot_on_goal":
			m.call("_on_pitch_shot_released", 0.56, 0.6, 0.44)
			await _wait(10)
			m.set("_hold_active", true)
			await _wait(28)
			_shot("shot_power")
			m.set("_hold_active", false)
		m.call("_finish_decision", 0.95)
		await _wait(20)
		_shot(kind + "_grade")
		await _wait(200)
	get_tree().quit(0)
