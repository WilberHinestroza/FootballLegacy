extends SceneTree
## Captura de las FORMACIONES del prototipo match_v2 (con ventana):
##   godot --path . --resolution 576x1024 -s res://tools/proto_formation_probe.gd
## Salida: _pixellab_preview/proto_v2_form_<formación>.png — el local con esa
## formación (abajo, ataca hacia arriba) contra un 4-3-3, en posición base.
const Sim = preload("res://prototypes/match_v2/ProtoSim.gd")
var inst

func _initialize() -> void:
	inst = (load("res://prototypes/match_v2/ProtoMatch.tscn") as PackedScene).instantiate()
	root.add_child(inst)
	_run()

func _run() -> void:
	await _frames(30)
	for f in Sim.FORMATION_BASES.keys():
		inst.sim = Sim.new("ST", 7, 70, 70, f, "4-3-3")
		inst.sim.sim_event.connect(inst._on_sim_event)
		inst._setup_sprites()
		inst.sim._reset_positions()
		for i in range(12):
			inst.interlude_t = 99.0 # sim quieta
			inst.card_panel.visible = false
			inst.lbl_toast.modulate.a = 0.0
			inst.view_w = 72.0
			inst.cam_lock = Vector2(34, 52.5)
			await process_frame
		await _save("proto_v2_form_%s.png" % f)
	quit()

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _save(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://_pixellab_preview/" + n))
	print("CAPTURA OK ", n)
