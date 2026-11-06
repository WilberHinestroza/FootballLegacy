# Capas de malla en la pierna (Y es la altura en el espacio de la malla, T-pose).
import bpy, os, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "match3d/models/player01_anim.glb"))
o = bpy.data.objects["Player"]; me = o.data
uv = me.uv_layers["UVMap"].data
H = max(v.co.y for v in me.vertices)
# f de Godot (1 - v de Blender) frente a la altura
for li in range(0, len(me.loops), 700):
    vi = me.loops[li].vertex_index
    print("H=%.3f f=%.3f" % (me.vertices[vi].co.y / H, 1.0 - uv[li].uv[1]))
zc = sum(v.co.z for v in me.vertices) / len(me.vertices)
bm = bmesh.new(); bm.from_mesh(me); bvh = BVHTree.FromBMesh(bm)
for f in [0.03, 0.06, 0.08, 0.12, 0.18, 0.24, 0.26, 0.30, 0.35, 0.40, 0.43, 0.5]:
    y = f * H
    o2 = Vector((-60, y, zc)); hits = []
    while True:
        loc, n, idx, dist = bvh.ray_cast(o2, Vector((1, 0, 0)), 200)
        if loc is None: break
        hits.append(round(loc.x, 1)); o2 = loc + Vector((0.02, 0, 0))
    print("f=%.2f hits=%s" % (f, hits))
