"""Ediciones DORADAS de prendas (P3, 9-oct): recolorea la capa de una prenda
a una rampa dorada por luminancia (el contorno casi negro y la piel quedan).
Salida: assets/pixelplayer/body/<id>_oro.png + máscara copiada.
    python tools/gold_editions.py
"""
import os, shutil
from PIL import Image
BODY = "assets/pixelplayer/body"
ITEMS = ["traje_negro", "chandal", "bomber", "polo", "cuero"]
RAMP = [(122, 78, 6), (196, 140, 18), (238, 186, 36), (255, 222, 90), (255, 248, 190)]

def gold(l):
    t = min(max((l - 20) / 170.0, 0.0), 1.0) * (len(RAMP) - 1)
    i = min(int(t), len(RAMP) - 2)
    f = t - i
    a, b = RAMP[i], RAMP[i + 1]
    return tuple(int(a[k] + (b[k] - a[k]) * f) for k in range(3))

for it in ITEMS:
    src = Image.open(os.path.join(BODY, it + ".png")).convert("RGBA")
    msk = Image.open(os.path.join(BODY, it + "_m.png")).convert("RGBA")
    out = src.copy()
    for y in range(src.height):
        for x in range(src.width):
            p = src.getpixel((x, y))
            if p[3] == 0 or msk.getpixel((x, y))[0] != 0:
                continue
            l = 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
            if l < 16:
                continue  # contorno
            # Las prendas oscuras (traje negro) se iluminan un poco para que el oro se lea.
            out.putpixel((x, y), gold(max(l, 90) * 1.2) + (p[3],))
    name = (it if it != "traje_negro" else "traje") + "_oro"
    out.save(os.path.join(BODY, name + ".png"))
    shutil.copy(os.path.join(BODY, it + "_m.png"), os.path.join(BODY, name + "_m.png"))
    print("ok", name)
