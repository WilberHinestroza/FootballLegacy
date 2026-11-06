# Ropa por piezas: recorta prendas de la propia malla del jugador y las exporta con el
# mismo esqueleto a match3d/models/garments.glb.
#
#   "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b -P tools/blender/build_garments.py
#
# Cada prenda es una copia de las caras del cuerpo que cubre (cortadas con planos limpios
# por las mismas líneas que pinta el shader), inflada hacia fuera. Conserva los pesos de
# los huesos, las UV y los colores de vértice del cuerpo: se dobla exactamente igual que
# él (no lo atraviesa) y la pinta el mismo shader de zonas (equipación, traje, patrones).
import bpy, bmesh, os
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "match3d/models/player01_anim.glb")
OUT = os.path.join(ROOT, "match3d/models/garments.glb")

# Medidas del shader (player_body.gdshaderinc), en fracción de la altura / del brazo
COLLAR_F = 0.752
SLEEVE_END = 0.55
WRIST_T = 2.1

# lo/hi: alturas del tronco que cubre; sleeve: fin de la manga (t) o None; off: separación
GARMENTS = {
    # Chaqueta, camisa, chándal, abrigo: tronco + brazos hasta la muñeca
    "top_long": dict(lo=0.355, hi=COLLAR_F - 0.008, sleeve=WRIST_T - 0.04, off=1.7),
    # Camiseta (equipación, polo): mangas cortas
    "top_short": dict(lo=0.355, hi=COLLAR_F - 0.008, sleeve=SLEEVE_END + 0.02, off=1.4),
    # Pantalón largo: de la cintura al empeine
    "trousers": dict(lo=0.036, hi=0.43, sleeve=None, off=1.0, straight=True),
    # Pantaloneta
    "shorts": dict(lo=0.232, hi=0.43, sleeve=None, off=1.0),
}
HEM = 0.55  # grosor del dobladillo (unidades de la malla; la altura total ~196)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
body = bpy.data.objects["Player"]
rig = bpy.data.objects["PlayerRig"]
H = max(v.co.y for v in body.data.vertices)


def vert_values(me):
    """Por vértice: f (altura en la pose original), t (posición en el brazo), zona."""
    uv = me.uv_layers["UVMap"].data
    uv2 = me.uv_layers["UVMap.001"].data
    col = me.attributes["Color"].data
    acc = {}
    for li, loop in enumerate(me.loops):
        a = acc.setdefault(loop.vertex_index, [0.0, 0.0, 0.0, 0.0, 0])
        a[0] += 1.0 - uv[li].uv[1]
        a[1] += (1.0 - uv2[li].uv[1]) * 3.0 - 0.5
        a[2] += col[li].color[0]
        a[3] += col[li].color[1]
        a[4] += 1
    return {vi: (a[0] / a[4], a[1] / a[4], a[2] / a[4], a[3] / a[4]) for vi, a in acc.items()}


def face_vals(bm, face):
    uvl = bm.loops.layers.uv["UVMap"]
    uvl2 = bm.loops.layers.uv["UVMap.001"]
    cl = bm.loops.layers.color.get("Color")
    f = t = r = g = 0.0
    n = len(face.loops)
    for l in face.loops:
        f += 1.0 - l[uvl].uv[1]
        t += (1.0 - l[uvl2].uv[1]) * 3.0 - 0.5
        if cl:
            r += l[cl][0]
            g += l[cl][1]
    return f / n, t / n, r / n, g / n


def arm_plane(vals, me, side, t_cut):
    """Plano perpendicular al brazo donde el shader corta la manga (t = t_cut)."""
    near, before, after = [], [], []
    for vi, (f, t, r, g) in vals.items():
        if r < 0.5 or g > 0.5:
            continue
        p = me.vertices[vi].co
        if (p.x > 0) != (side > 0):
            continue
        if abs(t - t_cut) < 0.12:
            near.append(p.copy())
        if abs(t - (t_cut - 0.3)) < 0.12:
            before.append(p.copy())
        if abs(t - (t_cut + 0.3)) < 0.12:
            after.append(p.copy())
    if not near or not before or not after:
        return None
    c = sum(near, Vector()) / len(near)
    n = (sum(after, Vector()) / len(after) - sum(before, Vector()) / len(before)).normalized()
    return c, n


def straighten(bm, nrm):
    """Pantalón de vestir: de la rodilla abajo cae recto (no se pega a la pantorrilla)
    y el vuelo de la pantaloneta modelada en el muslo desaparece."""
    for side in (1, -1):
        legs = [v for v in bm.verts if (v.co.x > 0) == (side > 0) and v.co.y < 0.33 * H]
        if not legs:
            continue

        def band(y, w=2.2):
            vs = [v for v in legs if abs(v.co.y - y) < w]
            if not vs:
                return None, 0.0
            c = sum((Vector((v.co.x, 0, v.co.z)) for v in vs), Vector()) / len(vs)
            r = sum((Vector((v.co.x, 0, v.co.z)) - c).length for v in vs) / len(vs)
            return c, r

        _, r_top = band(0.32 * H)
        _, r_knee = band(0.16 * H)
        r_low = max(r_knee * 0.96, r_top * 0.8)
        centers = {}
        for v in legs:
            f = v.co.y / H
            if f >= 0.27 or abs(v.co.x) < 3.5:
                continue  # la entrepierna se queda como está (si no, se estiran las caras)
            key = round(v.co.y / 2.0)
            if key not in centers:
                centers[key] = band(key * 2.0)[0]
            c = centers[key]
            if c is None:
                continue
            # Perfil: del muslo (0.32) baja suave hasta la rodilla y luego recto
            k = max(0.0, min(1.0, (f - 0.16) / 0.16))
            k = k * k * (3 - 2 * k)
            target = r_low + (r_top - r_low) * k
            # Un poco de vuelo en el bajo, sobre el zapato
            if f < 0.07:
                target *= 1.0 + 0.1 * (0.07 - f) / 0.035
            d = Vector((v.co.x, 0, v.co.z)) - c
            if d.length < 1e-4:
                continue
            nd = d.normalized()
            # Mezcla con la forma del cuerpo cerca del muslo (sin escalón)
            w = 1.0 - max(0.0, min(1.0, (f - 0.21) / 0.06))
            r = d.length + (max(target, d.length) - d.length) * w
            v.co.x = c.x + nd.x * r
            v.co.z = c.z + nd.z * r


def build(name, spec):
    ob = body.copy()
    ob.data = body.data.copy()
    ob.name = name
    ob.data.name = name
    bpy.context.collection.objects.link(ob)
    me = ob.data
    vals = vert_values(me)
    planes = []
    if spec["sleeve"] is not None:
        for side in (1, -1):
            pl = arm_plane(vals, me, side, spec["sleeve"])
            if pl:
                planes.append((side, pl))
    bm = bmesh.new()
    bm.from_mesh(me)
    # Cortes limpios: horizontales en el tronco (y = f * H) y perpendiculares en el brazo
    for y in (spec["lo"] * H, spec["hi"] * H):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector((0, y, 0)), plane_no=Vector((0, 1, 0)))
    for side, (c, n) in planes:
        faces = [f for f in bm.faces if all((v.co.x > 0) == (side > 0) for v in f.verts)]
        edges = list({e for f in faces for e in f.edges})
        verts = list({v for f in faces for v in f.verts})
        bmesh.ops.bisect_plane(bm, geom=verts + edges + faces, plane_co=c, plane_no=n)
    bm.faces.ensure_lookup_table()
    # Qué caras se quedan: por el centro de cada cara (los cortes ya hacen bordes lisos)
    kill = []
    for face in bm.faces:
        f, t, r, g = face_vals(bm, face)
        cen = face.calc_center_median()
        keep = False
        if g > 0.5:
            # Cabeza y cuello: solo el cuello por debajo de la línea del cuello de la camiseta
            # (sin la parte de abajo de la mandíbula: salía un pico en la barbilla)
            keep = spec["sleeve"] is not None and cen.y < spec["hi"] * H and face.normal.y > -0.35
        elif r > 0.5:
            if spec["sleeve"] is not None:
                pl = [p for s, p in planes if (cen.x > 0) == (s > 0)]
                keep = bool(pl) and (cen - pl[0][0]).dot(pl[0][1]) < 0.0
        else:
            keep = spec["lo"] * H < cen.y < spec["hi"] * H
        if not keep:
            kill.append(face)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.normal_update()
    # Normales suaves (las del cuerpo tienen aristas duras): media de las caras vecinas
    nrm = {}
    for v in bm.verts:
        n = Vector()
        for fc in v.link_faces:
            n += fc.normal * fc.calc_area()
        nrm[v] = n.normalized() if n.length > 1e-6 else v.normal.copy()
    if spec.get("straight"):
        straighten(bm, nrm)
    for v in bm.verts:
        v.co += nrm[v] * spec["off"]
    bm.to_mesh(me)
    bm.free()
    me.update()
    # Grosor en el borde (dobladillo, puños, cuello): sin él se ve el hueco de la tela.
    # Va antes del armature para que el grosor siga la pose.
    mod = ob.modifiers.new("hem", "SOLIDIFY")
    mod.thickness = HEM
    mod.offset = -1.0
    mod.use_rim = True
    mod.use_even_offset = False  # con True el borde se dispara en ángulos cerrados (picos)
    ob.modifiers.move(len(ob.modifiers) - 1, 0)
    return ob


made = [build(n, s) for n, s in GARMENTS.items()]
bpy.data.objects.remove(body, do_unlink=True)
for ob in list(bpy.data.objects):
    if ob.type == "MESH" and ob not in made:
        bpy.data.objects.remove(ob, do_unlink=True)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
for ob in made:
    ob.select_set(True)
kw = dict(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
          export_skins=True, export_animations=False, export_texcoords=True, export_normals=True)
try:
    bpy.ops.export_scene.gltf(**kw, export_vertex_color="ACTIVE", export_all_vertex_colors=True)
except TypeError:
    bpy.ops.export_scene.gltf(**kw, export_colors=True)
for ob in made:
    print("GARMENT", ob.name, len(ob.data.vertices), "verts")
print("OK", OUT)
