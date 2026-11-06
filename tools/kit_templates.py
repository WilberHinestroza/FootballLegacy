"""Camisetas de PixelLab de WILBER (objetos 113-144 de su cuenta) →
plantillas RECOLOREABLES para los kits de cada club (9-oct: "que esos
diseños de camisetas se puedan aplicar a las de jugador en partido o
mostrando al jugador con el uniforme del equipo").

    python tools/kit_templates.py

Cada camiseta viene con SUS colores (rojo y negro, rayas verdes...). Se
separa en clases por color: los dos grupos de color más grandes pasan a
ser "primario" y "secundario" del club; contorno y detalles chicos quedan
fijos. Por grupo se guarda la luminancia (sombreado) relativa, así teñido
conserva el volumen. Mismo formato de máscara que el avatar:
  R = clase (0 fijo, 1 primario, 2 secundario), G = luminancia 0-255.

Salida: assets/kits/w/<NNN>.png + <NNN>_m.png  y  data/KitTemplates.gd
(lista de plantillas + "familia" de cuello para que local y visitante de
una temporada compartan el corte — regla de Wilber).
"""
import colorsys
import os
from PIL import Image

SRC = "art_src/pixellab/objects_wilber"
OUT = "assets/kits/w"


def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def feat(p):
    """Rasgo de color SIN luminancia (el sombreado no separa grupos):
    tono en el círculo × saturación; los grises/blancos/negros se separan por
    claridad gruesa."""
    h, s, v = colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)
    import math
    if s < 0.18 or v < 0.16:
        # Acromáticos: blanco / gris / negro como "colores" propios.
        return (0.0, 0.0, 2.0 + round(v * 2) * 1.0)
    return (math.cos(h * 2 * math.pi) * s, math.sin(h * 2 * math.pi) * s, 0.0)


def kmeans(points, k, iters=20):
    import random
    random.seed(7)
    cent = random.sample(points, k)
    for _ in range(iters):
        groups = [[] for _ in range(k)]
        for p in points:
            j = min(range(k), key=lambda i: sum((p[d] - cent[i][d]) ** 2 for d in range(3)))
            groups[j].append(p)
        cent = [tuple(sum(q[d] for q in g) / len(g) for d in range(3)) if g else cent[i] for i, g in enumerate(groups)]
    return cent


def collar_family(im):
    """Familia de cuello: compara las filas de arriba del centro (V, redondo,
    polo) por cuántos píxeles opacos hay en la franja del cuello."""
    w, h = im.size
    bbox = im.getbbox()
    top = bbox[1]
    cx = (bbox[0] + bbox[2]) // 2
    depth = 0
    for y in range(top, top + 12):
        if im.getpixel((cx, y))[3] == 0:
            depth += 1
    return "v" if depth >= 5 else ("redondo" if depth >= 2 else "polo")


def run():
    os.makedirs(OUT, exist_ok=True)
    files = sorted(f for f in os.listdir(SRC) if f.endswith(".png") and 113 <= int(f[:3]) <= 144)
    table = []
    for f in files:
        num = f[:3]
        im = Image.open(os.path.join(SRC, f)).convert("RGBA")
        px = [(x, y) for y in range(im.height) for x in range(im.width) if im.getpixel((x, y))[3] > 0]
        body = [(x, y) for (x, y) in px if lum(im.getpixel((x, y))) > 42]   # sin contorno
        feats = {xy: feat(im.getpixel(xy)) for xy in body}
        cent = kmeans(list(feats.values()), 3)
        counts = [0, 0, 0]
        assign = {}
        for xy, ft in feats.items():
            j = min(range(3), key=lambda i: sum((ft[d] - cent[i][d]) ** 2 for d in range(3)))
            assign[xy] = j
            counts[j] += 1
        order = sorted(range(3), key=lambda i: -counts[i])
        total = float(sum(counts))
        # El 3er grupo (cuello/vivos) también toma color del club salvo que
        # sea un detalle mínimo (escudito): si no, el cuello azul original
        # quedaba igual en TODOS los clubes.
        cls_of = {order[0]: 1, order[1]: 2, order[2]: (2 if counts[order[2]] / total > 0.03 else 0)}
        # Luminancia de referencia = la MEDIANA del grupo (el tono "plano"
        # de la tela) → con un blanco del club la tela sale blanca, no gris;
        # las sombras siguen más oscuras y los brillos suben.
        vals = {1: [], 2: []}
        for xy, j in assign.items():
            c = cls_of[j]
            if c:
                vals[c].append(lum(im.getpixel(xy)))
        ref = {}
        for c in (1, 2):
            v = sorted(vals[c]) or [255.0]
            ref[c] = max(1.0, v[len(v) // 2] / 0.92)
        msk = Image.new("RGBA", im.size, (0, 0, 0, 0))
        for xy in px:
            j = assign.get(xy)
            c = cls_of[j] if j is not None else 0
            g = 0 if c == 0 else min(255, int(round(lum(im.getpixel(xy)) / ref[c] * 255)))
            msk.putpixel(xy, (c, g, 0, 255))
        im.save(os.path.join(OUT, num + ".png"))
        msk.save(os.path.join(OUT, num + "_m.png"))
        fam = "clasica"   # las 32 comparten silueta (manga corta, mismo cuerpo)
        table.append((num, fam))
        print(num, fam, "prim %.0f%% sec %.0f%%" % (counts[order[0]] / total * 100, counts[order[1]] / total * 100))
    lines = ["# GENERADO por tools/kit_templates.py — no editar a mano.",
             "extends RefCounted", "class_name KitTemplates", "",
             "## Camisetas de Wilber recoloreables: [número, familia de cuello].",
             "## Local y visitante de una temporada salen de la MISMA familia.",
             "const LIST := ["]
    for num, fam in table:
        lines.append('\t["%s", "%s"],' % (num, fam))
    lines.append("]")
    open("data/KitTemplates.gd", "w", encoding="utf-8").write(chr(10).join(lines) + chr(10))


if __name__ == "__main__":
    run()
