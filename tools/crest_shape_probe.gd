extends Node

## Verifica que Crest.build() no se cae para NINGUNA combinación de
## silueta (incluidas las 2 procedurales nuevas "pr_crested"/"pr_eared",
## Parte 92b: Wilber pidió volver el escudo 100% procedural, sin arte
## PNG externo salvo las 5 siluetas de toda la vida) × emblema, en los
## 3 layouts.
##   godot --headless res://tools/CrestShapeProbe.tscn

func _ready() -> void:
	var ok := true
	var primary := Color("#1B5E20")
	var secondary := Color("#FFD700")

	for shape_i in range(Crest.SHAPES.size()):
		var cfg := {"shape": shape_i, "pattern": 4, "emblem": 3, "layout": 0, "trim": true, "flip": false, "accent_mode": 1}
		var ctrl := Crest.build(primary, secondary, cfg, 48)
		if ctrl == null or ctrl.get_child_count() == 0:
			print("FALLA: build() vacío shape=", Crest.SHAPES[shape_i])
			ok = false

	for emb_i in range(Crest.EMBLEMS.size()):
		for layout_i in range(Crest.LAYOUTS.size()):
			var cfg2 := {"shape": 0, "pattern": 0, "emblem": emb_i, "layout": layout_i, "trim": false, "flip": false, "accent_mode": 0}
			var ctrl2 := Crest.build(primary, secondary, cfg2, 48)
			if ctrl2 == null or ctrl2.get_child_count() == 0:
				print("FALLA: build() vacío emblem=", Crest.EMBLEMS[emb_i], " layout=", Crest.LAYOUTS[layout_i])
				ok = false

	# Juego pixel (9-oct): todas las siluetas x emblemas, con/sin patrón.
	for sh in Crest.PX_SHAPES:
		for f in ["%s_fill.png" % sh, "%s_rim.png" % sh, "%s_outline.png" % sh]:
			if Crest._tex(f) == null:
				print("FALLA: no carga ", f)
				ok = false
		for em in Crest.PX_EMBLEMS:
			if String(em).begins_with("px_") and Crest._tex("emblems/%s.png" % em) == null:
				print("FALLA: no carga emblema ", em)
				ok = false
			for pat_i in [0, 2]:
				for lay in [0, 1]:
					var cfg3 := {"shape_name": sh, "pattern": pat_i, "emblem_name": em, "layout": lay, "trim": false, "flip": false, "accent_mode": 2}
					var c3 := Crest.build(primary, secondary, cfg3, 48)
					if c3 == null or c3.get_child_count() == 0:
						print("FALLA: build() vacío ", sh, " ", em)
						ok = false
					c3.free()
	var used_shapes := {}
	for i in range(600):
		var cf: Dictionary = Crest.config_for("club_%d" % i)
		used_shapes[String(cf.get("shape_name", "?"))] = true
	if Crest.PIXEL_SET and (used_shapes.size() != Crest.PX_SHAPES.size() or used_shapes.has("?")):
		print("FALLA: config_for no reparte las siluetas pixel: ", used_shapes.keys())
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
