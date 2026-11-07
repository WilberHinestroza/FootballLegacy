class_name Hats
extends RefCounted
## Gorras, gorros y cadenas ajustados al cuerpo (tools/blender/build_hats.py -> hats.glb). Cada
## prenda viene en piezas ("gorra_0" copa, "gorra_1" visera...) pesadas al hueso de la
## cabeza del mismo esqueleto, así que se mueven con ella sin atravesarla.
## Las cadenas se apoyan en la nuca y sobre la camiseta, pesadas al cuello y al pecho.
## Las usa PlayerAvatar.set_accessories para los huecos acc_head y acc_neck.

const PATH := "res://match3d/models/hats.glb"

## Material de cada pieza: [color, rugosidad, metal]
const LOOK := {
	"gorra": [["#16171c", 0.85], ["#1c1d23", 0.8], ["#16171c", 0.85]],
	"gorro_lana": [["#b3222c", 1.0], ["#951b24", 1.0], ["#f2f0ea", 1.0]],
	"cinta": [["#f2f3f6", 0.9]],
	"boina": [["#5b4b37", 1.0], ["#5b4b37", 1.0]],
	"cadena_fina": [["#ffd15e", 0.3, 0.55], ["#ffd15e", 0.25, 0.55]],
	"cadena_gruesa": [["#ffd15e", 0.3, 0.55], ["#ffd15e", 0.25, 0.55]],
}

static var _cache := {} # "gorra_0" -> {mesh, binds, xform}


static func has(id: String) -> bool:
	_load()
	return _cache.has(id + "_0")


static func _load() -> void:
	if not _cache.is_empty() or not ResourceLoader.exists(PATH):
		return
	var root := (load(PATH) as PackedScene).instantiate()
	var skels := root.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		root.free()
		return
	var skel := skels[0] as Skeleton3D
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null:
			continue
		var binds := []
		for i in mi.skin.get_bind_count():
			var bone := String(mi.skin.get_bind_name(i))
			if bone == "":
				bone = skel.get_bone_name(mi.skin.get_bind_bone(i))
			binds.append([bone, mi.skin.get_bind_pose(i)])
		_cache[String(mi.name)] = {"mesh": mi.mesh, "binds": binds, "xform": Garments._relative(mi, skel)}
	root.free()


## Crea las piezas de la prenda `id` como hijas de `skel` (vacío si no existe).
static func make(id: String, skel: Skeleton3D) -> Array:
	_load()
	var out := []
	var look: Array = LOOK.get(id, [])
	var i := 0
	while _cache.has("%s_%d" % [id, i]):
		var d: Dictionary = _cache["%s_%d" % [id, i]]
		var skin := Skin.new()
		for b: Array in d.binds:
			skin.add_named_bind(String(b[0]), b[1])
		var mi := MeshInstance3D.new()
		mi.name = "Hat_%s_%d" % [id, i]
		mi.mesh = d.mesh
		mi.skin = skin
		mi.transform = d.xform
		var m := StandardMaterial3D.new()
		var l: Array = look[i] if i < look.size() else ["#202020", 0.9]
		m.albedo_color = Color(String(l[0]))
		m.roughness = float(l[1])
		m.metallic = float(l[2]) if l.size() > 2 else 0.0
		mi.material_override = m
		skel.add_child(mi)
		mi.skeleton = NodePath("..")
		out.append(mi)
		i += 1
	return out
