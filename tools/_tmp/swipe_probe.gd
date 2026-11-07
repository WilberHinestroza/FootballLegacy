extends SceneTree
## Gesto → regate o tiro (SwipeIntent): los casos que se confundían.
const SwipeIntent = preload("res://engine/match/m3d/SwipeIntent.gd")
func _init() -> void:
	var cases := [
		# [dot, largo, velocidad, distancia, esperado, nombre]
		[0.6, 0.18, 1.0, 28.0, "dodge", "regate en diagonal hacia delante"],
		[0.95, 0.10, 0.8, 30.0, "dodge", "toquecito hacia delante lejos"],
		[0.95, 0.10, 0.8, 12.0, "shot", "toque suave en el área = tiro colocado"],
		[0.6, 0.35, 1.2, 25.0, "shot", "diagonal larga = tiro cruzado"],
		[0.6, 0.15, 2.5, 25.0, "shot", "diagonal corta pero rápida = tiro"],
		[0.9, 0.40, 2.0, 25.0, "shot", "gesto largo a portería"],
		[0.1, 0.30, 2.0, 20.0, "dodge", "de lado"],
		[-0.8, 0.20, 1.0, 20.0, "hook", "hacia atrás"],
	]
	var fails := 0
	for c in cases:
		var got := SwipeIntent.classify(c[0], c[1], c[2], c[3])
		var ok: bool = got == c[4]
		if not ok:
			fails += 1
		print("%-40s -> %s %s" % [c[5], got, "" if ok else "  <-- FALLA"])
	print("SWIPE PROBE %s" % ("OK" if fails == 0 else "FAIL"))
	quit(0)
