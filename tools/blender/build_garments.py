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
    "top_long": dict(lo=0.355, hi=COLLAR_F - 0.008, sleeve=WRIST_T - 0.04, cuff_t=WRIST_T, off=1.7, taper_top=0.035),
    # Camiseta (equipación, polo): mangas cortas
    "top_short": dict(lo=0.355, hi=COLLAR_F - 0.008, sleeve=SLEEVE_END + 0.02, cuff_t=SLEEVE_END, off=1.4, taper_top=0.035),
    # Pantalón largo: de la cintura al empeine
    "trousers": dict(lo=0.036, hi=0.43, sleeve=None, off=1.0, straight=True),
    # Pantaloneta
    # (por encima del labio doblado del borde modelado; el bajo se rehace con caras
    # nuevas. Arriba no sube tanto y se mete por dentro de la camiseta, que lo tapa)
    "shorts": dict(lo=0.249, hi=0.38, sleeve=None, off=1.0, hem_drop=0.013, tuck_from=0.335),
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
    span = sum(after, Vector()) / len(after) - sum(before, Vector()) / len(before)
    # n: hacia la mano; L: distancia por unidad de t (para rehacer t junto al corte)
    return c, span.normalized(), span.length / 0.6


def straighten(bm, nrm):
    """Pantalón de vestir: de la rodilla abajo cae recto (no se pega a la pantorrilla)
    y el vuelo de la pantaloneta modelada en el muslo desaparece."""
    for side in (1, -1):
        legs = [v for v in bm.verts if (v.co.x > 0) == (side > 0) and v.co.y < 0.38 * H]
        if not legs:
            continue

        def band(y, w=2.2):
            vs = [v for v in legs if abs(v.co.y - y) < w]
            if not vs:
                return None, 0.0
            c = sum((Vector((v.co.x, 0, v.co.z)) for v in vs), Vector()) / len(vs)
            r = sum((Vector((v.co.x, 0, v.co.z)) - c).length for v in vs) / len(vs)
            return c, r

        _, r_top = band(0.36 * H)
        _, r_knee = band(0.16 * H)
        r_low = max(r_knee * 0.96, r_top * 0.8)

        def box_center(y, w=2.2):
            vs = [v for v in legs if abs(v.co.y - y) < w]
            xs = [v.co.x for v in vs]
            zs = [v.co.z for v in vs]
            return Vector(((min(xs) + max(xs)) / 2, 0, (min(zs) + max(zs)) / 2))

        # Eje recto de la pierna (del tobillo al muslo). Con el centro de cada franja, el
        # labio de la pantaloneta modelada (muchos vértices de un lado) desviaba el eje y
        # la rodilla quedaba metida hacia dentro.
        c_lo, c_hi = box_center(0.08 * H), box_center(0.33 * H)
        for v in legs:
            f = v.co.y / H
            if f >= 0.36:
                continue
            a_ = max(0.0, min(1.0, (f - 0.08) / 0.25))
            c = c_lo.lerp(c_hi, a_) if f <= 0.33 else c_hi
            # Perfil: del muslo (0.32) baja suave hasta la rodilla y luego recto
            k = max(0.0, min(1.0, (f - 0.16) / 0.2))
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
            # Por encima del borde de la pantaloneta modelada manda el perfil (no el
            # bulto del borde); cerca de la cadera, mezcla con la forma del cuerpo
            w = 1.0 - max(0.0, min(1.0, (f - 0.3) / 0.06))
            # La entrepierna se queda casi como está (si no, se estiran las caras), pero
            # en degradado: un corte seco dejaba un pliegue en la cara interna del muslo
            inner = 1.0 - max(0.0, min(1.0, (abs(v.co.x) - 1.5) / 4.0))
            w *= 1.0 - inner * max(0.0, min(1.0, (f - 0.25) / 0.06))
            r = d.length + (target - d.length) * w
            v.co.x = c.x + nd.x * r
            v.co.z = c.z + nd.z * r


def rebridge_hem(bm):
    """El borde de la pantaloneta está modelado en la pierna (un labio doblado con muchos
    vértices y una costura abierta). En el pantalón largo esa franja se borra y se rehace
    con caras nuevas entre el muslo y la rodilla: tubo continuo, sin cresta ni raya.
    No crea vértices, así que los pesos de hueso no cambian."""
    lo, hi = 0.215 * H, 0.265 * H
    kill = [f for f in bm.faces if any(lo < v.co.y < hi for v in f.verts)
            and all(v.co.y < 0.33 * H for v in f.verts)]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    uvs = [bm.loops.layers.uv[i] for i in range(len(bm.loops.layers.uv))]
    cols = [bm.loops.layers.color[i] for i in range(len(bm.loops.layers.color))]
    for side in (1, -1):
        edges = [e for e in bm.edges if e.is_boundary and 0.15 * H < e.verts[0].co.y < 0.33 * H
                 and (e.verts[0].co.x > 0) == (side > 0)]
        if not edges:
            continue
        res = bmesh.ops.bridge_loops(bm, edges=edges)
        # Atributos por esquina de las caras nuevas: los de la propia esquina en otra cara
        for f in res["faces"]:
            f.smooth = True
            for l in f.loops:
                others = [o for o in l.vert.link_loops if o.face not in res["faces"]]
                if not others:
                    continue
                for lay in uvs:
                    l[lay].uv = sum((o[lay].uv for o in others), others[0][lay].uv * 0) / len(others)
                for lay in cols:
                    l[lay] = sum((Vector(o[lay]) for o in others), Vector((0, 0, 0, 0))) / len(others)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


def extend_hem(bm, drop):
    """Bajo de la pantaloneta: el borde de abajo se alarga hacia abajo y un poco hacia
    fuera (vuelo), con caras nuevas. Copian pesos, UV y colores del borde."""
    edges = [e for e in bm.edges if e.is_boundary and e.verts[0].co.y < 0.3 * H]
    res = bmesh.ops.extrude_edge_only(bm, edges=edges)
    newv = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
    for side in (1, -1):
        ring = [v for v in newv if (v.co.x > 0) == (side > 0)]
        if not ring:
            continue
        c = sum((Vector((v.co.x, 0, v.co.z)) for v in ring), Vector()) / len(ring)
        for v in ring:
            d = Vector((v.co.x, 0, v.co.z)) - c
            if d.length > 1e-4:
                v.co += d.normalized() * 0.45
            v.co.y -= drop * H
    for f in bm.faces:
        f.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


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
    # La malla del cuerpo trae vértices duplicados en las costuras (sobre todo el borde de
    # la pantaloneta modelada, f ~0.24): sin soldarlos la prenda queda abierta ahí y cada
    # lado se infla por su cuenta, dejando un escalón en el muslo. Las UV y los colores
    # son por esquina, así que no se pierden.
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.05)
    # Cortes limpios: horizontales en el tronco (y = f * H) y perpendiculares en el brazo
    for y in (spec["lo"] * H, spec["hi"] * H):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector((0, y, 0)), plane_no=Vector((0, 1, 0)))
    for side, (c, n, _L) in planes:
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
            # Cabeza y cuello: fuera. La malla tiene muy pocos polígonos ahí y un corte
            # quedaba en zigzag; el cuello de la camiseta lo pinta el shader en el cuerpo
            # (borde suave y ribete), justo encima del borde de esta prenda.
            keep = False
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
    if spec.get("straight"):
        rebridge_hem(bm)
    # Puño limpio: junto al corte, t sale de la distancia exacta al plano (la malla tiene
    # pocos polígonos y la t interpolada hacía un puño fino y en zigzag)
    if planes:
        s_end = spec["cuff_t"]
        uvl2 = bm.loops.layers.uv["UVMap.001"]
        cl = bm.loops.layers.color.get("Color")
        for v in bm.verts:
            for side, (c, n, L) in planes:
                if (v.co.x > 0) != (side > 0) or L < 1e-4:
                    continue
                d = -(v.co - c).dot(n) / L  # en unidades de t, positivo hacia el hombro
                if d < -0.01 or d > 0.25:
                    continue
                for l in v.link_loops:
                    if cl and l[cl][0] < 0.5:
                        continue
                    t_new = s_end - max(0.0, d)
                    l[uvl2].uv[1] = 1.0 - (t_new + 0.5) / 3.0
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
        # Rodilla: suaviza la unión muslo / caída recta (quedaba un anillo marcado)
        band = [v for v in bm.verts if 0.06 * H < v.co.y < 0.38 * H and not v.is_boundary]
        # Solo en horizontal: quita anillos y escalones sin acortar la pernera
        for _ in range(4):
            bmesh.ops.smooth_vert(bm, verts=band, factor=0.5, use_axis_x=True, use_axis_y=False, use_axis_z=True)
        bmesh.ops.dissolve_degenerate(bm, dist=0.15, edges=bm.edges[:])
        # Pesos de hueso suaves en el muslo: los del labio soldado venían de la
        # pantaloneta (todo muslo) y los de justo debajo ya seguían a la espinilla; con la
        # rodilla un poco doblada la tela se cortaba ahí en un escalón
        dl = bm.verts.layers.deform.active
        if dl is not None:
            zone = [v for v in bm.verts if 0.17 * H < v.co.y < 0.31 * H and not v.is_boundary]
            for _ in range(8):
                new = {}
                for v in zone:
                    acc = dict(v[dl])
                    nb = [e.other_vert(v) for e in v.link_edges]
                    for u in nb:
                        for g, wt in u[dl].items():
                            acc[g] = acc.get(g, 0.0) + wt
                    tot = sum(acc.values())
                    new[v] = {g: wt / tot for g, wt in acc.items() if wt / tot > 0.002} if tot > 0 else {}
                for v, ws in new.items():
                    dv = v[dl]
                    dv.clear()
                    for g, wt in ws.items():
                        dv[g] = wt
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.15)
        bm.normal_update()
        for v in bm.verts:
            n = Vector()
            for fc in v.link_faces:
                n += fc.normal * fc.calc_area()
            nrm[v] = n.normalized() if n.length > 1e-6 else v.normal.copy()
    tuck = spec.get("tuck_from")
    for v in bm.verts:
        off = spec["off"]
        if tuck is not None:
            # Bajo la camiseta: pegada al cuerpo (si no, roza la tela de encima y asoma)
            k = max(0.0, min(1.0, (v.co.y / H - tuck) / 0.03))
            off *= 1.0 - 0.7 * k
        taper = spec.get("taper_top")
        if taper is not None and abs(v.co.x) < 16.0:
            # Junto al cuello la tela se pega al cuerpo: el borde de arriba no hace
            # escalón y enlaza con el cuello que pinta el shader
            k2 = max(0.0, min(1.0, (v.co.y / H - (spec["hi"] - taper)) / taper))
            off *= 1.0 - 0.85 * k2 * k2 * (3 - 2 * k2)
        v.co += nrm[v] * off
    if spec.get("hem_drop"):
        extend_hem(bm, spec["hem_drop"])
    bm.to_mesh(me)
    bm.free()
    # Sombreado suave: fuera las normales a medida y las aristas duras heredadas del
    # cuerpo (el borde de la pantaloneta modelada y la rodilla dejaban una raya de luz)
    for attr in ("custom_normal", "sharp_edge", "sharp_face"):
        if attr in me.attributes:
            me.attributes.remove(me.attributes[attr])
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
