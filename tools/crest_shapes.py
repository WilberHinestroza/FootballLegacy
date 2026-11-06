"""Siluetas BASE de escudo moderno (blanco + contorno oscuro, 64x64) que
después PixelLab estiliza (edit_image_pixen) sin cambiar la forma.
PixelLab solo no logra siluetas lisas y rellenas (salen contornos vacíos o
donas) — por eso la forma se dibuja acá con precisión y el estilo lo pone
la IA. Salida: art_src/pixellab/crests/base_shapes/<id>.png

    python tools/crest_shapes.py
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = "art_src/pixellab/crests/base_shapes"
S = 8            # supermuestreo
W = 64 * S
FILL = (255, 255, 255, 255)
LINE = (24, 24, 30, 255)


def poly_shield(top_y, bottom_y, half_w, curve, pointed=False):
    """Escudo de lados rectos que terminan en curva/punta."""
    cx = W / 2
    pts = [(cx - half_w, top_y), (cx + half_w, top_y)]
    side_end = top_y + (bottom_y - top_y) * 0.45
    pts.append((cx + half_w, side_end))
    steps = 40
    for i in range(1, steps + 1):
        t = i / steps
        # de (half_w, side_end) a (0, bottom_y) con curvatura `curve`
        x = cx + half_w * (1 - t) ** curve
        y = side_end + (bottom_y - side_end) * (t if pointed else math.sin(t * math.pi / 2))
        pts.append((x, y))
    for i in range(steps, -1, -1):
        t = i / steps
        x = cx - half_w * (1 - t) ** curve
        y = side_end + (bottom_y - side_end) * (t if pointed else math.sin(t * math.pi / 2))
        pts.append((x, y))
    return pts


def shapes():
    m = 5 * S
    cx = W / 2
    out = {}
    out["circle"] = ("ellipse", (m, m, W - m, W - m))
    out["u_shield"] = ("poly", poly_shield(m + 2 * S, W - m, W / 2 - m - 3 * S, 1.0))
    out["point_shield"] = ("poly", poly_shield(m + 2 * S, W - m, W / 2 - m - 3 * S, 0.75, True))
    # Esquinas superiores recortadas + punta.
    cut = 7 * S
    hw = W / 2 - m - 3 * S
    p = poly_shield(m + 2 * S, W - m, hw, 0.85, True)
    p[0] = (cx - hw + cut, m + 2 * S)
    p[1] = (cx + hw - cut, m + 2 * S)
    p.insert(2, (cx + hw, m + 2 * S + cut))
    p.append((cx - hw, m + 2 * S + cut))
    out["cut_shield"] = ("poly", p)
    out["squircle"] = ("rounded", (m + S, m + S, W - m - S, W - m - S), 13 * S)
    out["oval"] = ("ellipse", (m + 8 * S, m, W - m - 8 * S, W - m))
    # Hexágono vertical.
    r = W / 2 - m
    out["hexagon"] = ("poly", [(cx + r * math.sin(a), W / 2 - r * math.cos(a)) for a in [i * math.pi / 3 for i in range(6)]])
    # Escudo con borde superior cóncavo (moderno, tipo "ala").
    p = poly_shield(m + 5 * S, W - m, hw, 0.7)
    top = []
    for i in range(21):
        t = i / 20
        x = cx - hw + 2 * hw * t
        y = m + 5 * S - 5 * S * (1 - (2 * t - 1) ** 2) * -1 - 5 * S
        top.append((x, m + S + 4 * S * (1 - (2 * t - 1) ** 2)))
    out["wing_shield"] = ("poly", top + p[2:])
    # Rombo redondeado.
    out["diamond"] = ("poly", [(cx, m), (W - m - 4 * S, W / 2), (cx, W - m), (m + 4 * S, W / 2)])
    # Estandarte: rectángulo alto con punta en V abajo.
    bw = 16 * S
    out["banner"] = ("poly", [(cx - bw, m), (cx + bw, m), (cx + bw, W - m - 8 * S), (cx, W - m), (cx - bw, W - m - 8 * S)])
    return out


def draw(kind, spec):
    big = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(big)
    if kind == "ellipse":
        d.ellipse(spec[0], fill=255)
    elif kind == "rounded":
        d.rounded_rectangle(spec[0], radius=spec[1], fill=255)
    else:
        d.polygon(spec[0], fill=255)
    mask = big.resize((64, 64), Image.LANCZOS).point(lambda v: 255 if v >= 128 else 0)
    # Contorno de 2 px por fuera de la máscara.
    grown = mask.filter(ImageFilter.MaxFilter(5))
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    for y in range(64):
        for x in range(64):
            if mask.getpixel((x, y)):
                img.putpixel((x, y), FILL)
            elif grown.getpixel((x, y)):
                img.putpixel((x, y), LINE)
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, spec in shapes().items():
        draw(spec[0], spec[1:]).save(os.path.join(OUT, name + ".png"))
        print(name)
