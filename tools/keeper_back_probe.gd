extends Control
## Arquero de espaldas (tu arco) + festejo en cancha (11-oct). Captura REAL.
##   godot --path . --resolution 864x480 res://tools/KeeperBackProbe.tscn
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var ctx := {"seed": 5, "us": Color(0.2, 0.4, 0.9), "them": Color(0.85, 0.2, 0.2),
		"user": {"num": "9", "name": "WILBER"}, "mates": [{"num": "10", "name": "PEREZ"}, {"num": "7", "name": "GOMEZ"}],
		"rivals": [{"num": "4", "name": "LOPEZ"}, {"num": "5", "name": "DIAZ"}, {"num": "2", "name": "RUIZ"}],
		"our_gk": {"num": "1", "name": "ARQUERO"}, "their_gk": {"num": "1", "name": "RIVAL"}}
	var fails: int = 0
	var views: Array = []
	var plays: Array = [PitchPlays.rival_goal(ctx, "Lopez", false, false), PitchPlays.team_goal(ctx, "Perez", false, false)]
	for i in range(2):
		var v := PitchView.new()
		v.position = Vector2(i * 432, 0)
		v.size = Vector2(432, 460)
		v.clip_contents = true
		add_child(v)
		v.setup(plays[i]["scene"])
		views.append(v)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(2):
		(views[i] as PitchView).play(plays[i]["steps"])
	var seen_back: bool = false
	var seen_fest: bool = false
	var t0: int = Time.get_ticks_msec()
	var shots: int = 0
	while Time.get_ticks_msec() - t0 < 5000:
		await get_tree().process_frame
		var v0: PitchView = views[0]
		if v0._actors.has("gk"):
			var an: String = String(v0._actors["gk"]["anim"])
			if an.begins_with("estirada") or an == "atajada" or an == "salto":
				var fr: Array = v0._frames(v0._actors["gk"], an)
				if not fr.is_empty() and Avatar.has_anim("gk_" + an + "_n"):
					seen_back = true
				if shots == 0:
					await get_tree().create_timer(0.25).timeout
					get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/keeper_back.png"))
					shots = 1
		var v1: PitchView = views[1]
		for id in v1._actors:
			if String(v1._actors[id]["anim"]) == "festejo":
				seen_fest = true
	if not seen_back:
		fails += 1
		print("FAIL el arquero de tu arco no usó la atajada de espaldas")
	if not seen_fest:
		fails += 1
		print("FAIL el goleador no festejó en la cancha")
	print("PROBE ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
