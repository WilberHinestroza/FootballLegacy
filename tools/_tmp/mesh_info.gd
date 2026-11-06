extends SceneTree
func _init() -> void:
	var av := PlayerAvatar.new()
	for mi: MeshInstance3D in av.find_children("*", "MeshInstance3D", true, false):
		var arr := mi.mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		for band in [[0.25, 0.27], [0.3, 0.33], [0.36, 0.39], [0.1, 0.2]]:
			var lo := 9.0
			var hi := -9.0
			for i in uv.size():
				if col[i].r < 0.5 and col[i].g < 0.5 and uv[i].y > band[0] and uv[i].y < band[1] and uv[i].x > 0.5:
					lo = minf(lo, uv[i].x - 0.5)
					hi = maxf(hi, uv[i].x - 0.5)
			print(band, " x ", lo, " .. ", hi)
	quit()
