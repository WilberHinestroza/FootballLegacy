"""Rastrea la CABEZA en cada cuadro de las animaciones de frente del jugador
para poder dibujarle encima el peinado / barba / gorro / lentes elegidos
(antes las animaciones solo tenían el corte base: melena, rastas, etc. se
perdían en los festejos — reporte de Wilber, 9-oct).

    python tools/anim_head_track.py

Cómo: la cabeza del sprite base (assets/pixelplayer/head/base.png, 48x48,
que en el lienzo de 68 de las animaciones cae en (10, 10)) se busca en cada
cuadro comparando la silueta piel+pelo de la máscara (_m.png, R = 1/2)
dentro de ±16 px. Si el mejor calce es malo (la cabeza rotada en una
vuelta carnero, tirado en el piso), ese cuadro queda sin superposición
(null) en vez de pegar el peinado torcido.

Salida: data/AnimHeadOffsets.gd (const OFFSETS = {anim: [[dx, dy] | null, ...]})
— GDScript y no JSON suelto, para que viaje dentro del APK sin depender
de los filtros de exportación.
"""
import json
import os
from PIL import Image

ANIM_DIR = "assets/pixelplayer/anim"
BASE_OFF = 10           # el sprite de 48 centrado en el lienzo de 68
SEARCH = 16
MIN_IOU = 0.62
# Solo animaciones DE FRENTE (el peinado está dibujado de frente).
FRONT = lambda a: (a.startswith("celeb_") or a in ("trofeo", "trofeo_oro", "balon_oro", "lesion", "cambio", "pitch_idle_south", "cabezazo", "arenga"))


def head_template():
    """Píxeles de cabeza del sprite base (piel+pelo de la capa head), en
    coordenadas del lienzo de 68."""
    m = Image.open("assets/pixelplayer/head/base_m.png").convert("RGBA")
    pts = set()
    for y in range(m.height):
        for x in range(m.width):
            p = m.getpixel((x, y))
            if p[3] and p[0] in (1, 2):
                pts.add((x + BASE_OFF, y + BASE_OFF))
    return pts


def frame_mask(path):
    m = Image.open(path).convert("RGBA")
    pts = set()
    for y in range(m.height):
        for x in range(m.width):
            p = m.getpixel((x, y))
            if p[3] and p[0] in (1, 2):
                pts.add((x, y))
    return pts


def best_offset(tpl, pts):
    best, best_iou = None, 0.0
    tn = len(tpl)
    for dy in range(-SEARCH, SEARCH + 1):
        for dx in range(-SEARCH, SEARCH + 1):
            hit = sum(1 for (x, y) in tpl if (x + dx, y + dy) in pts)
            if hit * 2 < tn:
                continue
            # IoU local: aciertos sobre la unión dentro de la caja de la cabeza
            # (el cuerpo/brazos de piel fuera de la caja no cuentan).
            xs = [x + dx for (x, y) in tpl]
            ys = [y + dy for (x, y) in tpl]
            x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
            inbox = sum(1 for (x, y) in pts if x0 <= x <= x1 and y0 <= y <= y1)
            iou = hit / float(tn + inbox - hit)
            if iou > best_iou:
                best, best_iou = (dx, dy), iou
    return best, best_iou


def run():
    tpl = head_template()
    table = {}
    for anim in sorted(os.listdir(ANIM_DIR)):
        if not FRONT(anim):
            continue
        d = os.path.join(ANIM_DIR, anim)
        offs, ious = [], []
        i = 0
        while os.path.exists(os.path.join(d, "%d_m.png" % i)):
            off, iou = best_offset(tpl, frame_mask(os.path.join(d, "%d_m.png" % i)))
            # Desplazamientos grandes = cabeza girada/tirada (vuelta carnero,
            # caída): el calce de silueta engaña ahí → sin superposición.
            ok = off is not None and iou >= MIN_IOU and abs(off[1]) <= 9 and abs(off[0]) <= 5
            offs.append(list(off) if ok else None)
            ious.append(round(iou, 2))
            i += 1
        table[anim] = offs
        print("%-18s %s" % (anim, " ".join("%s%s" % (("%+d,%+d" % tuple(o)) if o else "--", "") for o in offs)), ious)


    out = ["# GENERADO por tools/anim_head_track.py — no editar a mano.",
           "extends RefCounted", "class_name AnimHeadOffsets", "",
           "## Desplazamiento de la cabeza respecto al sprite base, por cuadro",
           "## (null = cabeza girada/tirada: sin peinado encima).",
           "const OFFSETS := {"]
    for anim, offs in table.items():
        items = ", ".join("null" if o is None else "Vector2i(%d, %d)" % (o[0], o[1]) for o in offs)
        out.append('	"%s": [%s],' % (anim, items))
    out.append("}")
    # Conservar las VISTAS de tools/hair_views.py (peinado de espaldas/costado).
    views = ""
    if os.path.exists("data/AnimHeadOffsets.gd"):
        old = open("data/AnimHeadOffsets.gd", encoding="utf-8").read()
        k = old.find(chr(10) + "## VISTAS (hair_views.py)")
        if k >= 0:
            views = old[k:].rstrip(chr(10)) + chr(10)
    open("data/AnimHeadOffsets.gd", "w", encoding="utf-8").write(chr(10).join(out) + chr(10) + views)


if __name__ == "__main__":
    run()
