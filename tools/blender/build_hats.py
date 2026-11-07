# Gorras y gorros ajustados a la cabeza del jugador -> match3d/models/hats.glb
#
#   "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b -P tools/blender/build_hats.py
#
# Antes eran medias esferas posadas encima (Wilber, 7-nov: "las gorras se ven horribles y
# antinaturales"). Ahora cada copa es una esfera densa proyectada sobre una copia suavizada
# de la cabeza (la malla tiene pocos polígonos ahí), inflada y cortada por la línea del
# borde de cada prenda. Todo va pesado al hueso de la cabeza: se mueve con ella.
# Lo carga match3d/scripts/hats.gd.
import bpy, bmesh, os, math
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "match3d/models/player01_anim.glb")
OUT = os.path.join(ROOT, "match3d/models/hats.glb")
HEAD_BONE = "mixamorig:Head"
ZF, ZB = 26.0, -20.0  # frente y nuca (malla: Y arriba, +Z hacia la cara, ~1 unidad = 1 cm)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
body = bpy.data.objects["Player"]
rig = bpy.data.objects["PlayerRig"]

# ---- cabeza suavizada (solo para proyectar encima) ----
gi = {g.index: g.name for g in body.vertex_groups}
head_v = set()
for v in body.data.vertices:
    for g in v.groups:
        if gi[g.group] in (HEAD_BONE, "mixamorig:Neck") and g.weight > 0.5:
            head_v.add(v.index)
bm = bmesh.new()
bm.from_mesh(body.data)
bm.verts.ensure_lookup_table()
kill = [f for f in bm.faces if not all(v.index in head_v for v in f.verts)]
bmesh.ops.delete(bm, geom=kill, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.05)
hm = bpy.data.meshes.new("HeadTarget")
bm.to_mesh(hm)
bm.free()
target = bpy.data.objects.new("HeadTarget", hm)
target.matrix_world = body.matrix_world
bpy.context.collection.objects.link(target)
sub = target.modifiers.new("sub", "SUBSURF")
sub.levels = 2
sm = target.modifiers.new("smooth", "SMOOTH")
sm.iterations = 6
sm.factor = 0.5

TOP = max(body.data.vertices[i].co.y for i in head_v)
CEN = Vector((0.0, 175.0, 2.0))  # centro aproximado del cráneo


def shell(name, offset, segs=64, rings=40):
    """Esfera densa pegada a la cabeza suavizada, a `offset` por fuera."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=40.0)
    ob = bpy.context.active_object
    ob.name = name
    ob.matrix_world = body.matrix_world
    for v in ob.data.vertices:
        v.co = v.co + CEN
    sw = ob.modifiers.new("wrap", "SHRINKWRAP")
    sw.target = target
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    sw.offset = offset
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="wrap")
    # Relaja la piel (sobre orejas y nariz se amontonaba) sin encoger
    lap = ob.modifiers.new("lap", "LAPLACIANSMOOTH")
    lap.iterations = 8
    lap.lambda_factor = 0.6
    lap.use_volume_preserve = True
    bpy.ops.object.modifier_apply(modifier="lap")
    return ob


def _bisect(ob, y_front, y_back, keep_above):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    slope = (y_front - y_back) / (ZF - ZB)
    n = Vector((0.0, 1.0, -slope)).normalized()
    if not keep_above:
        n = -n
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    # clear_inner borra lo que queda del lado negativo de la normal
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector((0.0, y_front, ZF)), plane_no=n, clear_inner=True)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(ob.data)
    bm.free()


def cut_above(ob, front_y, back_y):
    """Deja lo de encima de un plano inclinado: `front_y` en la frente, `back_y` en la nuca."""
    _bisect(ob, front_y, back_y, True)


def keep_band(ob, lo_front, hi_front, lo_back, hi_back):
    _bisect(ob, lo_front, lo_back, True)
    _bisect(ob, hi_front, hi_back, False)


def solid(ob, th):
    m = ob.modifiers.new("solid", "SOLIDIFY")
    m.thickness = th
    m.offset = -1.0
    m.use_rim = True
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="solid")


def boundary_pts(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    pts = [v.co.copy() for v in bm.verts if v.is_boundary]
    bm.free()
    return pts


def visor(name, crown, reach, droop, half_angle=1.15):
    """Visera: sale del borde delantero de la copa, curva de lado a lado y algo caída."""
    pts = boundary_pts(crown)
    rows = []
    n = 20
    steps = 5
    for i in range(n + 1):
        a = -half_angle + 2 * half_angle * i / n
        d = Vector((math.sin(a), 0.0, math.cos(a)))
        best = max(pts, key=lambda p: Vector((p.x - CEN.x, 0.0, p.z - CEN.z)).normalized().dot(d))
        q = abs(a) / half_angle
        k = 1.0 - q * q * 0.65
        row = []
        for s in range(steps + 1):
            t = s / steps
            p = best - d * 0.6 + d * ((reach * k + 0.6) * t)
            # cae un poco hacia el borde y más en los lados (curva de visera usada)
            p.y -= droop * k * t * t + droop * 0.4 * q * q * t
            row.append(p)
        rows.append(row)
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in row] for row in rows]
    for i in range(n):
        for s in range(steps):
            f = bm.faces.new((vs[i][s], vs[i + 1][s], vs[i + 1][s + 1], vs[i][s + 1]))
            f.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.matrix_world = body.matrix_world
    bpy.context.collection.objects.link(ob)
    solid(ob, 0.9)
    return ob


def ball(name, pos, r, segs=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=segs // 2 + 2, radius=r)
    ob = bpy.context.active_object
    ob.name = name
    ob.matrix_world = body.matrix_world
    for v in ob.data.vertices:
        v.co = v.co + pos
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def join(name, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    ob.data.name = name
    return ob


made = []

# Cada prenda se exporta en piezas separadas (copa, detalle) para darles material propio:
# el nombre termina en el número de pieza que usa hats.gd.

# ---- Gorra: copa ajustada + visera curva + botón ----
crown = shell("gorra_0", 1.3)
cut_above(crown, 178.5, 168.0)
vis = visor("gorra_1", crown, 16.0, 2.5, 0.78)
solid(crown, 0.5)
btn = ball("gorra_2", Vector((0.0, TOP + 1.0, -1.0)), 1.3)
made += [crown, vis, btn]

# ---- Gorro de lana: copa holgada hasta las orejas + vuelta doblada + pompón ----
bea = shell("gorro_lana_0", 1.6)
cut_above(bea, 176.5, 163.0)
solid(bea, 0.6)
cuff = shell("gorro_lana_1", 2.7)
keep_band(cuff, 176.0, 182.5, 162.5, 169.5)
solid(cuff, 0.8)
pom = ball("gorro_lana_2", Vector((0.0, TOP + 5.5, -1.5)), 5.2, 20)
made += [bea, cuff, pom]

# ---- Cinta: banda elástica en la frente, por encima de las cejas ----
band = shell("cinta_0", 0.7)
keep_band(band, 179.0, 184.5, 175.0, 180.5)
solid(band, 0.6)
made += [band]

# ---- Boina: copa y plato ancho, ladeado hacia un lado ----
ber = shell("boina_0", 1.0)
cut_above(ber, 179.5, 172.0)
for v in ber.data.vertices:
    h = max(0.0, min(1.0, (v.co.y - 176.0) / max(1.0, TOP - 176.0)))
    grow = 1.0 + 0.16 * math.sin(h * math.pi * 0.85) ** 2
    v.co.x = v.co.x * grow - 3.0 * h
    v.co.z = (v.co.z - 2.0) * grow + 2.0
    # plato plano por encima del cráneo, ladeado (más bajo del lado izquierdo)
    v.co.y = min(v.co.y + 1.5 * h, TOP + 1.8) + 1.5 * h * (v.co.x / 20.0)
solid(ber, 0.7)
stem = ball("boina_1", Vector((-3.0, TOP + 1.6, 2.0)), 1.0, 8)
made += [ber, stem]

# ---- Cadenas: un hilo que se apoya en la nuca y cae sobre la camiseta ----
# (un aro rígido no podía seguir el cuello y el pecho a la vez: quedaba dentro de la
# camiseta 3D o flotando delante). Se proyecta sobre el cuerpo en reposo, por fuera de
# la camiseta, y se pesa entre el cuello y el pecho para moverse con los dos.
torso = bpy.data.objects.new("TorsoTarget", body.data.copy())
torso.matrix_world = body.matrix_world
bpy.context.collection.objects.link(torso)
NECK_BONE, CHEST_BONE = "mixamorig:Neck", "mixamorig:Spine2"
SHIRT_OFF = 1.4  # lo que infla la camiseta (build_garments.py, top_short)


def necklace_path(n, drop):
    """Puntos del collar alrededor del cuello: arriba en la nuca, en V suave delante."""
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n  # 0 = delante
        c = (1.0 + math.cos(a)) * 0.5  # 1 delante, 0 detrás
        y = 149.0 - drop * c ** 1.6
        r = 14.5 + 9.0 * c
        pts.append(Vector((math.sin(a) * r, y, -2.0 + math.cos(a) * r * (1.0 + 0.6 * c))))
    return pts


def project(pts, offset):
    me = bpy.data.meshes.new("proj")
    me.from_pydata([p for p in pts], [], [])
    ob = bpy.data.objects.new("proj", me)
    ob.matrix_world = body.matrix_world
    bpy.context.collection.objects.link(ob)
    sw = ob.modifiers.new("wrap", "SHRINKWRAP")
    sw.target = torso
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    sw.wrap_mode = "OUTSIDE_SURFACE"
    sw.offset = offset
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="wrap")
    out = [v.co.copy() for v in ob.data.vertices]
    bpy.data.objects.remove(ob, do_unlink=True)
    # suaviza el recorrido (cerrado) para que no siga cada arista de la malla
    for _ in range(3):
        out = [(out[i - 1] + out[i] * 2 + out[(i + 1) % len(out)]) / 4 for i in range(len(out))]
    return out


def tube(name, pts, r, sides=8):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    n = len(pts)
    rings = []
    for i in range(n):
        t = (pts[(i + 1) % n] - pts[i - 1]).normalized()
        u = t.cross(Vector((0, 1, 0)))
        if u.length < 1e-4:
            u = Vector((1, 0, 0))
        u.normalize()
        w = t.cross(u).normalized()
        rings.append([bm.verts.new(pts[i] + (u * math.cos(k * 2 * math.pi / sides) + w * math.sin(k * 2 * math.pi / sides)) * r) for k in range(sides)])
    for i in range(n):
        a, b = rings[i], rings[(i + 1) % n]
        for k in range(sides):
            f = bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
            f.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.matrix_world = body.matrix_world
    bpy.context.collection.objects.link(ob)
    return ob


def pendant(name, at, r, th):
    """Medalla apoyada en el pecho: un disco de cara a +Z, algo inclinado."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=r, depth=th)
    ob = bpy.context.active_object
    ob.name = name
    ob.matrix_world = body.matrix_world
    for v in ob.data.vertices:
        # el cilindro ya tiene el eje en Z (malla: +Z hacia delante)
        v.co = at + Vector((0.0, -r * 0.9, th * 0.5 + 0.2)) + v.co
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


chains = []
for cid, thick, drop, pr in (("cadena_fina", 0.28, 12.0, 1.6), ("cadena_gruesa", 0.55, 14.0, 2.6)):
    path = project(necklace_path(72, drop), SHIRT_OFF + thick + 0.35)
    ch = tube(cid + "_0", path, thick)
    front = max(path, key=lambda p: p.z)
    pd = pendant(cid + "_1", front, pr, 0.5)
    chains += [ch, pd]
bpy.data.objects.remove(torso, do_unlink=True)

# Gorras: todo al hueso de la cabeza. Cadenas: entre el cuello y el pecho por altura.
for ob in made + chains:
    ob.vertex_groups.clear()
    if ob in chains:
        gn = ob.vertex_groups.new(name=NECK_BONE)
        gc = ob.vertex_groups.new(name=CHEST_BONE)
        for v in ob.data.vertices:
            k = max(0.0, min(1.0, (v.co.y - 139.0) / 8.0))
            gn.add([v.index], k, "REPLACE")
            gc.add([v.index], 1.0 - k, "REPLACE")
    else:
        vg = ob.vertex_groups.new(name=HEAD_BONE)
        vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = rig
    ob.matrix_parent_inverse = rig.matrix_world.inverted()
    arm = ob.modifiers.new("arm", "ARMATURE")
    arm.object = rig

bpy.data.objects.remove(target, do_unlink=True)
bpy.data.objects.remove(body, do_unlink=True)
made += chains
for ob in list(bpy.data.objects):
    if ob.type == "MESH" and ob not in made:
        bpy.data.objects.remove(ob, do_unlink=True)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
for ob in made:
    ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
                          export_skins=True, export_animations=False, export_normals=True)
for ob in made:
    ys = [v.co.y for v in ob.data.vertices]
    zs = [v.co.z for v in ob.data.vertices]
    print("HAT", ob.name, len(ob.data.vertices), "verts y %.1f..%.1f z %.1f..%.1f" % (min(ys), max(ys), min(zs), max(zs)))
print("OK", OUT)
