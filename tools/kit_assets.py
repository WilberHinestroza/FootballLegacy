"""Siluetas de camiseta de PixelLab (art_src/pixellab/kits/body_*.png, blanco
+ grises + contorno oscuro horneado) → 3 capas para Kit.gd:
  assets/kits/body_px_<id>.png    relleno blanco (se tiñe con el primario y
                                  recorta el patrón con clip_children)
  assets/kits/shade_px_<id>.png   sombreado (negro con alfa) que va ENCIMA
                                  del patrón, para no perder los pliegues
  assets/kits/outline_px_<id>.png contorno/costuras (blanco, se tiñe)
    python tools/kit_assets.py
"""
import os
from PIL import Image

SRC = "art_src/pixellab/kits"
OUT = "assets/kits"
for f in sorted(os.listdir(SRC)):
    if not (f.startswith("body_") and f.endswith(".png")):
        continue
    name = f[len("body_"):-4]
    im = Image.open(os.path.join(SRC, f)).convert("RGBA")
    fill = Image.new("RGBA", im.size, (0, 0, 0, 0))
    shade = Image.new("RGBA", im.size, (0, 0, 0, 0))
    line = Image.new("RGBA", im.size, (0, 0, 0, 0))
    for y in range(im.height):
        for x in range(im.width):
            p = im.getpixel((x, y))
            if p[3] < 128:
                continue
            v = max(p[:3])
            if v < 70:
                line.putpixel((x, y), (255, 255, 255, 255))
                fill.putpixel((x, y), (255, 255, 255, 255))
                continue
            fill.putpixel((x, y), (255, 255, 255, 255))
            a = int(max(0, 255 - v) * 1.4)
            if a > 6:
                shade.putpixel((x, y), (0, 0, 0, min(200, a)))
    fill.save(os.path.join(OUT, "body_px_%s.png" % name))
    shade.save(os.path.join(OUT, "shade_px_%s.png" % name))
    line.save(os.path.join(OUT, "outline_px_%s.png" % name))
    print("camiseta", name)
