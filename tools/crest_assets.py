"""Piezas de escudo pixel art para Crest.gd (9-oct):
  - siluetas modernas (tools/crest_shapes.py) → assets/crests/px_<id>_fill.png
    (blanco, se tiñe y recorta patrones/emblema) + px_<id>_outline.png
    (contorno en blanco, se tiñe con el color de contorno).
  - emblemas PixelLab (art_src/pixellab/crests/emblems) →
    assets/crests/emblems/px_<id>.png (blanco/grises + contorno oscuro, se
    tiñen con el color de acento del club).
    python tools/crest_shapes.py && python tools/crest_assets.py
"""
import os
from PIL import Image

SHAPES_SRC = "art_src/pixellab/crests/base_shapes"
EMB_SRC = "art_src/pixellab/crests/emblems"
OUT = "assets/crests"

RIM_IN, RIM_OUT = 3, 5      # aro interior: entre 3 y 5 px adentro del borde


def edge_dist(mask, w, h):
    """Distancia (en px, 4-vecinos) de cada píxel del relleno al borde."""
    INF = 10 ** 6
    d = [[INF] * w for _ in range(h)]
    from collections import deque
    q = deque()
    for y in range(h):
        for x in range(w):
            if not mask[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or not mask[ny][nx]:
                    d[y][x] = 0
                    q.append((x, y))
                    break
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and d[ny][nx] > d[y][x] + 1:
                d[ny][nx] = d[y][x] + 1
                q.append((nx, ny))
    return d


def build_shape(name, im):
    w, h = im.size
    mask = [[im.getpixel((x, y))[3] > 0 and max(im.getpixel((x, y))[:3]) > 128 for x in range(w)] for y in range(h)]
    d = edge_dist(mask, w, h)
    ys = [y for y in range(h) for x in range(w) if mask[y][x]]
    y0, y1 = min(ys), max(ys)
    fill = Image.new("RGBA", im.size, (0, 0, 0, 0))
    rim = Image.new("RGBA", im.size, (0, 0, 0, 0))
    line = Image.new("RGBA", im.size, (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            p = im.getpixel((x, y))
            if p[3] == 0:
                continue
            if not mask[y][x]:
                line.putpixel((x, y), (255, 255, 255, 255))
                continue
            # Relleno: degradé vertical suave + bisel (luz arriba-izquierda).
            v = 1.0 - 0.14 * (y - y0) / max(1, y1 - y0)
            if d[y][x] <= 1:
                up_left = (not mask[max(0, y - 2)][x]) or (not mask[y][max(0, x - 2)])
                v = 1.0 if up_left else 0.66
            g = int(255 * v)
            fill.putpixel((x, y), (g, g, g, 255))
            if RIM_IN <= d[y][x] <= RIM_OUT:
                rim.putpixel((x, y), (255, 255, 255, 255))
    fill.save(os.path.join(OUT, "%s_fill.png" % name))
    rim.save(os.path.join(OUT, "%s_rim.png" % name))
    line.save(os.path.join(OUT, "%s_outline.png" % name))


def build_emblem(src, dst):
    em = Image.open(src).convert("RGBA")
    out = Image.new("RGBA", em.size, (0, 0, 0, 0))
    # Sombra: la silueta del emblema corrida 1px abajo-derecha, oscura.
    for y in range(em.height):
        for x in range(em.width):
            if em.getpixel((x, y))[3] > 0 and x + 1 < em.width and y + 1 < em.height:
                out.putpixel((x + 1, y + 1), (10, 10, 14, 150))
    out.alpha_composite(em)
    out.save(dst)


os.makedirs(os.path.join(OUT, "emblems"), exist_ok=True)
for f in sorted(os.listdir(SHAPES_SRC)):
    if f.endswith(".png"):
        build_shape("px_" + f[:-4], Image.open(os.path.join(SHAPES_SRC, f)).convert("RGBA"))
        print("silueta", f[:-4])
for f in sorted(os.listdir(EMB_SRC)):
    if f.endswith(".png"):
        build_emblem(os.path.join(EMB_SRC, f), os.path.join(OUT, "emblems", "px_" + f))
        print("emblema", f[:-4])
