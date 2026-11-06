"""Parte cada conjunto de ropa (assets/pixelplayer/body/<id>.png + _m.png)
en dos capas combinables para Avatar.gd (10-oct, Wilber: "separar camisas,
chaquetas, pantalones y zapatos en la tienda"):

    assets/pixelplayer/top/<id>.png     camisa/chaqueta + brazos y manos
    assets/pixelplayer/bottom/<id>.png  pantalón + el calzado que trae

Correr desde la raíz del repo:   python tools/split_outfits.py

Todos los conjuntos comparten la pose del sprite base (48x48), así que la
separación es geométrica:
  - columnas 16..31 = cadera/piernas; fuera de eso = brazos y manos.
  - HEM[id] = primera fila del pantalón (dónde termina la prenda de arriba).
  - el pantalón se estira hacia arriba hasta la fila BOTTOM_TOP para que
    cualquier prenda de arriba, por corta que sea, lo tape sin dejar hueco.
  - LONG[id] = abrigos largos: la prenda de arriba tapa las piernas hasta
    esa fila (se dibuja ENCIMA del pantalón).
Sin generaciones nuevas de PixelLab: sale todo del arte que ya existe.
"""
import os
import sys
from PIL import Image

SRC = "assets/pixelplayer/body"
W = H = 48
LEG_L, LEG_R = 16, 31      # columnas de cadera/piernas (inclusive)
BOTTOM_TOP = 26            # hasta dónde se estira el pantalón hacia arriba
SHOE_ROW = 42              # desde acá todo el ancho es calzado

# Primera fila del pantalón por conjunto (default 31). Ajustado mirando la
# hoja de control (art_src/_check/split_*.png).
HEM = {
    "camisa_chinos": 28, "polo": 30, "polo_oro": 30, "jeans": 30, "kit": 31,
    "camisa_vestir": 30, "franela": 30, "lino": 31, "oversize": 32,
    "hawaiana": 33, "hoodie": 32, "hoodie_negro": 32, "seda": 31,
    "traje_azul": 34, "traje_gris": 34, "traje_negro": 34, "traje_oro": 34,
    "smoking_blanco": 33, "cuello_alto": 31, "chandal": 32, "chandal_oro": 32,
    "retro": 32, "bomber_oro": 32,
}
LONG = {"abrigo": 40, "gabardina": 41}


def is_black(p):
    return p[3] > 0 and p[0] + p[1] + p[2] < 70


def split(name):
    col = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
    msk = Image.open(os.path.join(SRC, name + "_m.png")).convert("RGBA")
    hem = HEM.get(name, 31)
    long_end = LONG.get(name, 0)
    top_c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    top_m = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bot_c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bot_m = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for y in range(H):
        for x in range(W):
            p = col.getpixel((x, y))
            if p[3] == 0:
                continue
            legs = LEG_L <= x <= LEG_R
            is_top = y < hem or (not legs and y < SHOE_ROW) or (legs and long_end and y < long_end)
            if is_top:
                top_c.putpixel((x, y), p)
                top_m.putpixel((x, y), msk.getpixel((x, y)))
            if (legs and y >= hem) or y >= SHOE_ROW:
                bot_c.putpixel((x, y), p)
                bot_m.putpixel((x, y), msk.getpixel((x, y)))
    # Estirar la cintura hacia arriba: se repite una fila "limpia" del
    # pantalón (dos por debajo del borde, sin la línea del cinturón).
    ref = min(hem + 2, SHOE_ROW - 1)
    for y in range(BOTTOM_TOP, hem):
        for x in range(LEG_L, LEG_R + 1):
            p = col.getpixel((x, ref))
            if p[3] > 0:
                bot_c.putpixel((x, y), p)
                bot_m.putpixel((x, y), msk.getpixel((x, ref)))
    return (top_c, top_m, bot_c, bot_m)


def main():
    names = sorted(f[:-4] for f in os.listdir(SRC) if f.endswith(".png") and not f.endswith("_m.png"))
    for g in ("top", "bottom"):
        os.makedirs("assets/pixelplayer/" + g, exist_ok=True)
    pieces = {}
    for n in names:
        tc, tm, bc, bm = split(n)
        tc.save("assets/pixelplayer/top/%s.png" % n)
        tm.save("assets/pixelplayer/top/%s_m.png" % n)
        bc.save("assets/pixelplayer/bottom/%s.png" % n)
        bm.save("assets/pixelplayer/bottom/%s_m.png" % n)
        pieces[n] = (tc, bc)
    print("%d conjuntos -> top/ y bottom/" % len(names))

    # Hojas de control: cada "arriba" sobre un pantalón de referencia y cada
    # pantalón bajo una prenda de referencia (las combinaciones más duras:
    # arriba corto con pantalón de cintura baja y al revés).
    os.makedirs("art_src/_check", exist_ok=True)
    S, cols = 5, 9
    for tag, ref_bot, ref_top in (("a", "traje_azul", "camisa_chinos"), ("b", "camisa_chinos", "hoodie")):
        rows = (len(names) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * (W * S + 8), rows * 2 * (W * S + 14)), (40, 44, 52))
        for i, n in enumerate(names):
            x = (i % cols) * (W * S + 8)
            y = (i // cols) * 2 * (W * S + 14)
            a = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            a.alpha_composite(pieces[ref_bot][1])
            a.alpha_composite(pieces[n][0])
            b = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            b.alpha_composite(pieces[n][1])
            b.alpha_composite(pieces[ref_top][0])
            for k, im in enumerate((a, b)):
                big = im.resize((W * S, W * S), Image.NEAREST)
                sheet.paste(big, (x, y + k * (W * S + 6)), big)
        sheet.save("art_src/_check/split_%s.png" % tag)
    print("hojas de control en art_src/_check/")


if __name__ == "__main__":
    main()
