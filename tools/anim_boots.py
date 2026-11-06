"""Marca los BOTINES en las máscaras de todas las animaciones del jugador
(clase 7 = boots) para que se tiñan con los guayos equipados — antes los
guayos de la Tienda solo se veían en el cuerpo entero quieto (Wilber: "no
los he visto").

    python tools/anim_boots.py      (correr DESPUÉS de anim_layers.py / pitch_sprites.py)

Botín = píxel "fijo" (clase 0) claro y poco saturado, en el cuarto de abajo
del personaje, CONECTADO a una media/pierna (clases kit/short/piel). La
conexión deja afuera a la pelota del remate (blanca, a la altura de los
pies, pero suelta) y al blanco de los ojos.
"""
import colorsys
import os
from PIL import Image

ANIM_DIR = "assets/pixelplayer/anim"
BOOTS = 7
LEGS = {1, 3, 4, 5}


def is_candidate(p):
    if p[3] == 0:
        return False
    h, s, v = colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)
    return s < 0.28 and v > 0.45


def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def process(col_path, msk_path, limit=None):
    col = Image.open(col_path).convert("RGBA")
    msk = Image.open(msk_path).convert("RGBA")
    W, H = col.size
    bbox = col.getbbox()
    if bbox is None:
        return 0
    y_cut = bbox[3] - (bbox[3] - bbox[1]) * 0.26
    cand = set()
    for y in range(int(y_cut), H):
        for x in range(W):
            if msk.getpixel((x, y))[0] == 0 and is_candidate(col.getpixel((x, y))):
                cand.add((x, y))
    # Semillas: candidatos pegados a pierna/media/short.
    seeds = [c for c in cand if any(
        0 <= c[0] + dx < W and 0 <= c[1] + dy < H and msk.getpixel((c[0] + dx, c[1] + dy))[3] and msk.getpixel((c[0] + dx, c[1] + dy))[0] in LEGS
        for dx in (-1, 0, 1) for dy in (-1, 0, 1))]
    boots = set(seeds)
    stack = list(seeds)
    while stack:
        x, y = stack.pop()
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (x + dx, y + dy)
                if n in cand and n not in boots:
                    boots.add(n)
                    stack.append(n)
    if not boots or (limit is not None and len(boots) > limit):
        return 0 if not boots else -len(boots)   # negativo = descartado
    ref = max(lum(col.getpixel(b)) for b in boots) or 1
    for (x, y) in boots:
        g = min(255, int(round(lum(col.getpixel((x, y))) / ref * 255)))
        msk.putpixel((x, y), (BOOTS, g, 0, 255))
    msk.save(msk_path)
    return len(boots)


def _count(col_path, msk_path):
    import shutil, tempfile
    tmp = tempfile.mktemp(suffix=".png")
    shutil.copy(msk_path, tmp)
    c = process(col_path, tmp)
    os.remove(tmp)
    return c


def run():
    for anim in sorted(os.listdir(ANIM_DIR)):
        if anim.startswith("gk_"):
            continue   # el arquero usa sus propios botines/guantes
        d = os.path.join(ANIM_DIR, anim)
        if not os.path.isdir(d):
            continue
        # 1ª pasada en seco: cuántos px marcaría cada cuadro. Un cuadro que
        # marca mucho más que lo normal de SU animación es la pelota pegada
        # al pie (remate) → se descarta ese cuadro.
        n = 0
        while os.path.exists(os.path.join(d, "%d.png" % n)):
            n += 1
        dry = [_count(os.path.join(d, "%d.png" % i), os.path.join(d, "%d_m.png" % i)) for i in range(n)]
        nz = sorted(c for c in dry if c > 0)
        med = nz[len(nz) // 2] if nz else 0
        limit = max(2 * med, 8)
        counts = [process(os.path.join(d, "%d.png" % i), os.path.join(d, "%d_m.png" % i), limit) for i in range(n)]
        print("%-22s %s" % (anim, counts))


if __name__ == "__main__":
    run()
