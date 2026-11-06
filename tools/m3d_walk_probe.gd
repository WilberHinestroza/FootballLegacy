extends Node
## Mide la salida del túnel: cuántos van por el pasillo, cuántos parados y la
## distancia mínima entre dos jugadores visibles. Sin ventana.
func _ready() -> void:
	var g: Node = load("res://tools/ui_gallery_probe.gd").new()
	g._seed_career()
	g.free()
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	var scr: Node = load("res://scenes/Match3D/Match3D.tscn").instantiate()
	add_child(scr)
	var m: SoccerMatch = scr._match
	var t := 0.0
	var mode := "walk"
	while t < 60.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
		if mode == "walk" and m.state != m.State.WALKOUT:
			mode = "out"
			m._start_outro()
		var vis := 0
		var tun := 0
		var still := 0
		var mind := 99.0
		var ps: Array = []
		for p: SoccerPlayer in m.players:
			if not p.visible:
				continue
			vis += 1
			ps.append(p)
			if p.global_position.z < -36.0:
				tun += 1
				if Vector2(p.velocity.x, p.velocity.z).length() < 0.3:
					still += 1
		for i in ps.size():
			for j in range(i + 1, ps.size()):
				var a: Vector3 = ps[i].global_position
				var b: Vector3 = ps[j].global_position
				mind = minf(mind, Vector2(a.x - b.x, a.z - b.z).length())
		var refs := ""
		for r: Node3D in m.staff.refs:
			refs += "(%.1f,%.1f,%s) " % [r.position.x, r.position.z, "v" if r.visible else "-"]
		print("%s t=%.1f vis=%d tunel=%d parados=%d mind=%.2f refs=%s" % [mode, t, vis, tun, still, mind, refs])
		if mode == "out" and m.state != m.State.OUTRO:
			break
	get_tree().quit(0)
