extends Node

## Verifica que el nuevo set de camisetas (Parte 92, arte de Wilber vía
## Gemini: body_classic/outline_classic_v2/pat_*/acc_sleeves nuevos) carga
## y compone sin null-texture para los 7 patrones nombrados, en los 5
## cuerpos. No mide píxeles (eso ya se validó fuera de Godot) — solo que
## Kit.build() no se cae y que cada capa esperada existe en disco.
##   godot --headless res://tools/KitAssetProbe.tscn

func _ready() -> void:
	var ok := true
	var primary := Color("#c8102e")
	var secondary := Color("#ffffff")
	for body_i in range(Kit.ALL_BODIES.size()):
		for pattern_i in range(Kit.PATTERNS.size()):
			var cfg := {"body": body_i, "pattern": pattern_i, "sleeve_accent": true}
			var ctrl := Kit.build(primary, secondary, cfg, 64)
			if ctrl == null or ctrl.get_child_count() == 0:
				print("FALLA: build() vacío body=%s pattern=%s" % [Kit.ALL_BODIES[body_i], Kit.PATTERNS[pattern_i]])
				ok = false

	for f in ["body_classic", "outline_classic_v2", "pat_stripes", "pat_hoops", "pat_sash", "pat_halves", "pat_chevron", "pat_placket", "acc_sleeves"]:
		var p := "res://assets/kits/%s.png" % f
		if not ResourceLoader.exists(p):
			print("FALLA: falta ", p)
			ok = false
		else:
			var t: Texture2D = load(p)
			if t == null or t.get_width() == 0:
				print("FALLA: textura vacía ", p)
				ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
