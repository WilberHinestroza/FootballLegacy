"""Separa el arte de PixelLab (art_src/pixellab/raw/) en capas apilables
para Avatar.gd. Correr desde la raíz del repo:

    python tools/pixel_layers.py

Todo parte del MISMO sprite base de 48x48 (el personaje "Pixel art 2D
sports game" de Wilber, vista south). Cada prenda/peinado se generó con
`edit_image_pixen` sobre ese sprite, que conserva pose y estilo pero
retoca levemente TODO el sprite (diferencias de color < 20) — por eso cada
capa se saca por DIFERENCIA contra la base con un umbral, y solo dentro de
la zona de la pieza (si no, la capa de pelo arrastraría la cara retocada).

Salida por capa, en assets/pixelplayer/<grupo>/<id>.png + <id>_m.png:
  - <id>.png   colores originales (RGBA).
  - <id>_m.png máscara: R = clase del píxel (ver CLASSES), G = luminancia
    normalizada 0-255 para teñir. Avatar.gd tiñe multiplicando el color
    elegido por G (y deja el original si no hay tinte elegido).
"""
import colorsys
import os
from PIL import Image

SRC = "art_src/pixellab/raw"
OUT = "assets/pixelplayer"
W = H = 48
NECK_ROW = 15          # primera fila del cuerpo (cuello) en la base
DIFF_THRESHOLD = 30    # suma |dR|+|dG|+|dB| — el ruido de pixen queda < 20

# Mismas claves que Avatar.TINTS / Avatar.MASK_* en GDScript.
CLASSES = {"fixed": 0, "skin": 1, "hair": 2, "shirt": 3, "shorts": 4, "socks": 5, "trim": 6}

base = Image.open(os.path.join(SRC, "00_base.png")).convert("RGBA")

# Colores de pelo del rapado de la base (mismo naranja que la piel, se
# separan por color exacto + altura).
BASE_HAIR = {(0xcd, 0x82, 0x49), (0xe8, 0xab, 0x6e), (0x85, 0x40, 0x28), (0x8e, 0x47, 0x2b),
             (0x99, 0x50, 0x30), (0xa5, 0x5a, 0x35), (0xb2, 0x67, 0x3d)}


def hsv(p):
    h, s, v = colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)
    return h * 360, s, v


def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def base_class(x, y, p):
    """Clase de un píxel del sprite BASE (kit de fútbol)."""
    if p[3] == 0 or p[:3] == (0, 0, 0):
        return "fixed"
    h, s, v = hsv(p)
    if p[:3] in BASE_HAIR or (p[:3] == (0x76, 0x35, 0x23) and y <= 6):
        return "hair"
    if h < 40 and s > 0.4:
        return "skin"
    if v < 0.42:
        return "shorts" if y >= 30 else "trim"
    if y < 16:
        return "fixed"   # blanco de los ojos
    if y >= 42:
        return "fixed"   # botines
    return "socks" if y >= 36 else "shirt"


SKIN_PALETTE = sorted({base.getpixel((x, y))[:3] for y in range(H) for x in range(W)
                       if base_class(x, y, base.getpixel((x, y))) == "skin"})
SKIN_MAX_LUM = max(lum(c) for c in SKIN_PALETTE)


def is_skin(p):
    if p[3] == 0:
        return False
    return min(sum(abs(p[i] - c[i]) for i in range(3)) for c in SKIN_PALETTE) <= 36


def diff(p, q):
    if (p[3] == 0) != (q[3] == 0):
        return 255
    if p[3] == 0:
        return 0
    return sum(abs(p[i] - q[i]) for i in range(3))


def save_layer(group, name, pixels):
    """pixels: {(x,y): (rgba, clase)} → <name>.png + <name>_m.png"""
    os.makedirs(os.path.join(OUT, group), exist_ok=True)
    col = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    msk = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # Luminancia de referencia por clase: la piel usa la de la base (así
    # cabeza y cuerpo tiñen igual); el resto, la máxima de la propia capa.
    ref = {}
    for (rgba, cls) in pixels.values():
        if cls not in ("fixed", "skin"):
            ref[cls] = max(ref.get(cls, 1), lum(rgba))
    ref["skin"] = SKIN_MAX_LUM
    for (x, y), (rgba, cls) in pixels.items():
        col.putpixel((x, y), rgba)
        g = 0 if cls == "fixed" else min(255, int(round(lum(rgba) / ref[cls] * 255)))
        msk.putpixel((x, y), (CLASSES[cls], g, 0, 255))
    col.save(os.path.join(OUT, group, name + ".png"))
    msk.save(os.path.join(OUT, group, name + "_m.png"))
    return len(pixels)


def region_pixels(src, keep):
    """Píxeles de `src` que difieren de la base y que `keep(x, y)` acepta."""
    out = {}
    for y in range(H):
        for x in range(W):
            q = src.getpixel((x, y))
            if q[3] == 0 or not keep(x, y):
                continue
            if diff(base.getpixel((x, y)), q) > DIFF_THRESHOLD:
                out[(x, y)] = q
    return out


def in_face(x, y):
    """Interior de la cara (ojos/nariz/boca) — nunca lo pisa una capa de pelo."""
    return 18 <= x <= 29 and 8 <= y <= 14


def overlay_class(q, tint_cls):
    if q[:3] == (0, 0, 0):
        return "fixed"
    if is_skin(q):
        return "skin"
    return tint_cls


def main():
    report = []

    # --- Base: cabeza (filas < NECK_ROW) y cuerpo con el kit ---------------
    head, kit = {}, {}
    for y in range(H):
        for x in range(W):
            p = base.getpixel((x, y))
            if p[3] == 0:
                continue
            (head if y < NECK_ROW else kit)[(x, y)] = (p, base_class(x, y, p))
    report.append(("head/base", save_layer("head", "base", head)))
    report.append(("body/kit", save_layer("body", "kit", kit)))

    # --- Ropa: reemplaza el cuerpo entero (filas >= NECK_ROW) ---------------
    # + lo que la prenda agregue en las filas 11-14 fuera de la cara (cuellos
    # altos, capuchas).
    for f in sorted(os.listdir(SRC)):
        if not f.startswith("ropa_"):
            continue
        src = Image.open(os.path.join(SRC, f)).convert("RGBA")
        px = {}
        for y in range(NECK_ROW, H):
            for x in range(W):
                q = src.getpixel((x, y))
                if q[3] > 0:
                    px[(x, y)] = (q, "skin" if is_skin(q) else "fixed")
        for (x, y), q in region_pixels(src, lambda x, y: 11 <= y < NECK_ROW and not in_face(x, y)).items():
            px[(x, y)] = (q, "skin" if is_skin(q) else "fixed")
        name = f[len("ropa_"):-4]
        report.append(("body/" + name, save_layer("body", name, px)))

    # --- Peinados: diferencia en la mitad de arriba, sin tocar la cara -------
    for f in sorted(os.listdir(SRC)):
        if not f.startswith("pelo_"):
            continue
        src = Image.open(os.path.join(SRC, f)).convert("RGBA")
        reg = region_pixels(src, lambda x, y: y <= 27 and not in_face(x, y))
        px = {k: (q, overlay_class(q, "hair")) for k, q in reg.items()}
        name = f[len("pelo_"):-4]
        report.append(("hair/" + name, save_layer("hair", name, px)))

    # --- Cara: barba (sigue el color del pelo) ------------------------------
    FACE_REGIONS = {
    "barba": lambda x, y: 8 <= y <= 17 and 15 <= x <= 32,
    "bigote": lambda x, y: 9 <= y <= 15 and 17 <= x <= 30,
    "candado": lambda x, y: 9 <= y <= 17 and 16 <= x <= 31,
    "barba3": lambda x, y: 8 <= y <= 17 and 15 <= x <= 32,
    "barba_larga": lambda x, y: 8 <= y <= 27 and 13 <= x <= 34,
}
    for name, keep in FACE_REGIONS.items():
        src = Image.open(os.path.join(SRC, "cara_%s.png" % name)).convert("RGBA")
        reg = region_pixels(src, keep)
        px = {k: (q, overlay_class(q, "hair")) for k, q in reg.items()}
        report.append(("face/" + name, save_layer("face", name, px)))

    # --- Rasgos de la cara (9-oct, pedido de Wilber: "narices, orejas y
    # tipos de cara para el editor"). Cada grupo en SU zona: la nariz no
    # puede arrastrar la boca retocada por pixen, ni las orejas el pelo.
    def extract(prefix, group, keep):
        for f in sorted(os.listdir(SRC)):
            if not f.startswith(prefix):
                continue
            src = Image.open(os.path.join(SRC, f)).convert("RGBA")
            reg = region_pixels(src, keep)
            px = {k: (q, "skin" if is_skin(q) else "fixed") for k, q in reg.items()}
            name = f[len(prefix):-4]
            report.append((group + "/" + name, save_layer(group, name, px)))

    extract("nariz_", "nose", lambda x, y: 20 <= x <= 27 and 9 <= y <= 12)
    extract("orejas_", "ears", lambda x, y: (x <= 18 or x >= 29) and 5 <= y <= 14)
    # Rasgos: la cara entera menos el pelo de arriba (pecas, cejas, cicatriz,
    # mandíbula, cara redonda).
    extract("rasgo_", "rasgo", lambda x, y: 5 <= y <= 16 and 12 <= x <= 35)
    # Pecas DIBUJADAS a mano (9-oct, P0): las de pixen salían como manchas.
    # Puntitos sueltos en mejillas y nariz, un tono más oscuro que la piel
    # de la base (clase skin → se tiñen con cualquier tono de piel).
    FRECKLES = [(19, 12), (21, 12), (20, 13), (22, 11), (26, 12), (28, 12), (27, 13), (25, 11)]
    px = {}
    for (x, y) in FRECKLES:
        q = base.getpixel((x, y))
        d = tuple(int(c * 0.66) for c in q[:3]) + (255,)
        px[(x, y)] = (d, "skin")
    report.append(("rasgo/pecas (a mano)", save_layer("rasgo", "pecas", px)))

    # --- Accesorios: zona propia de cada uno, color original ----------------
    ACC_REGIONS = {
        "cadena_fina": lambda x, y: 14 <= y <= 26,
        "cadena_gruesa": lambda x, y: 14 <= y <= 27,
        "lentes_sol": lambda x, y: 7 <= y <= 13,
        "aviador": lambda x, y: 7 <= y <= 13,
        "gorra": lambda x, y: y <= 9,
        "gorro_lana": lambda x, y: y <= 9,
        "cinta": lambda x, y: y <= 9,
        "auriculares": lambda x, y: 13 <= y <= 24,
        "reloj": lambda x, y: 22 <= y <= 37 and (x <= 17 or x >= 30),
        "pendientes": lambda x, y: 8 <= y <= 14 and (x <= 18 or x >= 29),
    # 10-oct: zapatos de salir, guayos nuevos, bufanda, boina, lentes redondos.
    "zapatillas_blancas": lambda x, y: y >= 40,
    "mocasines": lambda x, y: y >= 40,
    "botas_chelsea": lambda x, y: y >= 39,
    "guayos_plata": lambda x, y: y >= 40,
    "guayos_lava": lambda x, y: y >= 40,
    "bufanda": lambda x, y: 13 <= y <= 26,
    "boina": lambda x, y: y <= 9,
    "lentes_redondos": lambda x, y: 7 <= y <= 13,
    # Guayos (9-oct): solo la zona de los pies.
    "guayos_verde": lambda x, y: y >= 40,
    "guayos_oro": lambda x, y: y >= 40,
    "guayos_negro": lambda x, y: y >= 40,
    "guayos_rosa": lambda x, y: y >= 40,
    "guayos_blanco": lambda x, y: y >= 40,
    "guayos_azul": lambda x, y: y >= 40,
    "guayos_morado": lambda x, y: y >= 40,
    "guayos_rojo": lambda x, y: y >= 40,
    "guayos_arcoiris": lambda x, y: y >= 40,
    }
    for name, keep in ACC_REGIONS.items():
        if not os.path.exists(os.path.join(SRC, "acc_%s.png" % name)):
            print("  falta acc_%s" % name)
            continue
        src = Image.open(os.path.join(SRC, "acc_%s.png" % name)).convert("RGBA")
        reg = region_pixels(src, keep)
        px = {k: (q, "skin" if is_skin(q) else "fixed") for k, q in reg.items()}
        report.append(("acc/" + name, save_layer("acc", name, px)))

    for name, n in report:
        print("%-24s %4d px" % (name, n))


if __name__ == "__main__":
    main()
