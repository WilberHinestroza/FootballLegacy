extends Node
## Capturas de "Crear jugador" en horizontal: datos, apariencia y test.
##   godot --path . res://tools/CreationProbe.tscn
func _ready() -> void:
	get_tree().current_scene = null
	CharacterDraft.identity = {}
	CharacterDraft.avatar = {}
	CharacterDraft.avatar_done = false
	await _shot("res://scenes/CharacterCreation/CharacterCreation.tscn", "land_Crear1_datos.png")
	CharacterDraft.identity = {"name": "Wilber Prueba", "country": "Colombia", "pos": "DC", "pos2": "", "foot": "Derecho", "origin": "Barrio", "difficulty": "normal", "age": 16}
	await _shot("res://scenes/AvatarCreator/AvatarCreator.tscn", "land_Crear2_apariencia.png")
	CharacterDraft.avatar = Avatar.random_config(7)
	CharacterDraft.avatar_done = true
	await _shot("res://scenes/CharacterCreation/CharacterCreation.tscn", "land_Crear3_test.png")
	get_tree().quit()

func _shot(scene: String, out: String) -> void:
	get_tree().change_scene_to_file(scene)
	await get_tree().create_timer(1.2).timeout
	var img: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_pixellab_preview"))
	img.save_png("res://_pixellab_preview/" + out)
	print("CAPTURA ", out)
