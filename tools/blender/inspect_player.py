# Inspecciona player01_anim.glb: mallas, atributos, huesos y capas de la pierna.
# blender -b -P tools/blender/inspect_player.py
import bpy, os, math
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "match3d/models/player01_anim.glb"))
for o in bpy.data.objects:
    print("OBJ", o.name, o.type, tuple(round(v,3) for v in o.scale), o.parent.name if o.parent else None)
    if o.type == 'MESH':
        me = o.data
        print("  verts", len(me.vertices), "faces", len(me.polygons), "attrs", [(a.name, a.domain, a.data_type) for a in me.attributes])
        print("  uv", [u.name for u in me.uv_layers], "vgroups", len(o.vertex_groups), "mats", [m.name for m in me.materials])
        zs = [v.co.z for v in me.vertices]; print("  z range", min(zs), max(zs))
    if o.type == 'ARMATURE':
        print("  bones", len(o.data.bones), [b.name for b in o.data.bones][:70])
print("ACTIONS", len(bpy.data.actions), [a.name for a in bpy.data.actions][:80])
