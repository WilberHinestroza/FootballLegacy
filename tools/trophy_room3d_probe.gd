extends "res://tools/ui_gallery_probe.gd"
## Vitrina 3D del Perfil (TrophyRoom) con títulos de prueba (solo en memoria, slot_3).
##   godot --path . res://tools/TrophyRoom3DProbe.tscn
func _ready() -> void:
	_seed_career() # carrera desechable en slot_3 (como RpgProbe)
	await get_tree().process_frame
	var p: PlayerData = SaveManager.load_player()
	p.career_titles = [
		{"id": "league_2", "name": "LaGiga", "kind": "team", "season": 2026, "metal": 1},
		{"id": "dcup_España", "name": "Copa", "kind": "team", "season": 2026, "metal": 1},
		{"id": "cont_UEFA_1", "name": "Champions", "kind": "continental", "season": 2027, "metal": 1},
		{"id": "ballon_dor", "name": "Balón de Oro", "kind": "individual", "season": 2027, "metal": 1},
		{"id": "botaoro_2027", "name": "Bota de Oro", "kind": "individual", "season": 2027, "metal": 1},
		{"id": "mundial_clubes", "name": "Mundial de Clubes", "kind": "world", "season": 2027, "metal": 1},
	]
	SaveManager.save_player(p)
	var inst: Node = (load("res://scenes/PlayerProfile/PlayerProfile.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	for i in 30:
		await get_tree().process_frame
	inst.call("_on_tab_pressed", "showcase")
	await get_tree().create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/TrophyRoom3D.png"))
	print("CAPTURA vitrina 3D")
	get_tree().quit()
