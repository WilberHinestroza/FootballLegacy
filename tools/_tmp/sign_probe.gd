extends Node
## Captura la hoja de contrato: antes de firmar y con el sello puesto.
func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	await get_tree().process_frame
	var p := SaveManager.load_player()
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.16)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(bg)
	var sc := SigningCeremony.new()
	sc.setup({"club_id": p.club_id, "club_name": "Atlético Rquena", "league_name": "Primera División",
		"stars": 3, "wage": 420000, "years": 3, "role": "Titular", "number": 20, "is_renewal": false, "player": p})
	get_tree().root.add_child(sc)
	for i in 40:
		await get_tree().process_frame
	_shot("sign_a")
	sc._do_signature()
	for i in 200:
		await get_tree().process_frame
	_shot("sign_b")
	get_tree().quit(0)

func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/%s.png" % n))
