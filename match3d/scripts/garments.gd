class_name Garments
extends RefCounted
## Ropa por piezas: cada prenda es una malla aparte (tools/blender/build_garments.py ->
## garments.glb) recortada de la del cuerpo e inflada, con los mismos pesos de hueso.
## Se pega al esqueleto del jugador y usa SU material de zonas, así que los colores, la
## equipación y el traje salen igual que antes, pero con volumen de tela de verdad.
## El cuerpo deja de dibujarse debajo (uniform `cover` del shader).

const PATH := "res://match3d/models/garments.glb"

## layer: 1 arriba, 2 abajo. lo/hi: alturas del tronco que tapa (algo por dentro del
## borde de la prenda); arm: brazo tapado hasta t; neck: tapa el cuello.
const SPECS := {
	"top_long": {"layer": 1.0, "lo": 0.367, "hi": 0.738, "arm": 1.98, "neck": true},
	"top_short": {"layer": 1.0, "lo": 0.367, "hi": 0.738, "arm": 0.5, "neck": true},
	"trousers": {"layer": 2.0, "lo": 0.047, "hi": 0.42, "arm": -9.0, "neck": false},
	"shorts": {"layer": 2.0, "lo": 0.244, "hi": 0.42, "arm": -9.0, "neck": false},
}

static var _cache := {} # id -> {mesh, binds: [[hueso, pose]], xform}


static func available() -> bool:
	_load()
	return not _cache.is_empty()


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
		var id := String(mi.name)
		if not SPECS.has(id) or mi.skin == null:
			continue
		var binds := []
		for i in mi.skin.get_bind_count():
			var bone := String(mi.skin.get_bind_name(i))
			if bone == "":
				bone = skel.get_bone_name(mi.skin.get_bind_bone(i))
			binds.append([bone, mi.skin.get_bind_pose(i)])
		_cache[id] = {"mesh": mi.mesh, "binds": binds, "xform": _relative(mi, skel)}
	root.free()


static func _relative(n: Node, to: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != null and c != to:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


## Crea la prenda como hija del esqueleto `skel` (o null si no existe).
static func make(id: String, skel: Skeleton3D) -> MeshInstance3D:
	_load()
	if not _cache.has(id):
		return null
	var d: Dictionary = _cache[id]
	# Piel por nombre de hueso: vale para cualquier esqueleto del mismo modelo
	var skin := Skin.new()
	for b: Array in d.binds:
		skin.add_named_bind(String(b[0]), b[1])
	var mi := MeshInstance3D.new()
	mi.name = "Garment_" + id
	mi.mesh = d.mesh
	mi.skin = skin
	mi.transform = d.xform
	mi.set_instance_shader_parameter("garment_layer", float(SPECS[id].layer))
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	return mi


## Lo que tapan juntas las prendas `ids` (para el `cover` del cuerpo).
static func cover_for(ids: Array) -> Vector4:
	var lo := 2.0
	var hi := -1.0
	var arm := -9.0
	var neck := 0.0
	for id: String in ids:
		if not SPECS.has(id):
			continue
		var s: Dictionary = SPECS[id]
		lo = minf(lo, float(s.lo))
		hi = maxf(hi, float(s.hi))
		arm = maxf(arm, float(s.arm))
		if bool(s.neck):
			neck = 1.0
	if hi < 0.0:
		return Vector4(2.0, 2.0, -9.0, 0.0)
	return Vector4(lo, hi, arm, neck)
