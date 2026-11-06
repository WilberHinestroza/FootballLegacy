"""Animaciones del jugador (PixelLab, sobre el personaje base de Wilber) →
cuadros + máscaras de tinte para Avatar.anim_frames().

    python tools/anim_layers.py

Entrada: art_src/pixellab/player_anims/<anim>/<n>.png (68x68, ver
tools/fetch... / el zip del personaje). Salida:
assets/pixelplayer/anim/<anim>/<n>.png + <n>_m.png (mismo formato de
máscara que tools/pixel_layers.py: R = clase, G = luminancia).

En una animación los brazos/cuerpo se mueven, así que la clase NO puede
salir de la altura del píxel como en el sprite quieto: sale del COLOR más
cercano de la paleta del sprite base (ya clasificada por pixel_layers.py).
Lo que no se parece a nada de la base (la copa dorada, el Balón de Oro)
queda "fixed" — con su color original.
"""
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import pixel_layers as PL  # noqa: E402  (reusa la clasificación del sprite base)

SRC = "art_src/pixellab/player_anims"
OUT = "assets/pixelplayer/anim"
MAX_DIST = 30
ANIMS = ["celeb_rodillas", "celeb_salto", "celeb_avion", "celeb_cielo", "celeb_escudo",
         "celeb_mortal", "trofeo_oro", "balon_oro", "lesion", "cambio",
         "celeb_baile", "celeb_corazon", "celeb_silencio", "celeb_bebe", "cabezazo", "arenga",
         "celeb_pistolas", "celeb_saludo", "celeb_aplauso", "celeb_grito",
         # 10-oct (día): festejos "de figura" + animaciones de situaciones.
         "celeb_brazos_cruzados", "celeb_dedos_cielo", "celeb_salto_giro", "celeb_surfero",
         "celeb_meditacion", "celeb_brazos_abiertos", "celeb_robot",
         "llamada", "pensar", "sorpresa", "himno", "lamento", "firma", "puno"]

# Paleta del sprite base → clase (la de pixel_layers, por posición).
PALETTE = {}
for y in range(PL.H):
    for x in range(PL.W):
        p = PL.base.getpixel((x, y))
        if p[3] == 0:
            continue
        cls = PL.base_class(x, y, p)
        # Un mismo color puede caer en dos clases según la altura (blanco de
        # ojos vs camiseta): gana la clase teñible más frecuente.
        PALETTE.setdefault(p[:3], {}).setdefault(cls, 0)
        PALETTE[p[:3]][cls] += 1
PALETTE = {c: max(d, key=d.get) for c, d in PALETTE.items()}
# Medias y ribete: en una animación no hay altura confiable para separarlos
# de camiseta/short — siguen el color de la camiseta / del short.
PALETTE = {c: ("shirt" if k == "socks" else "shorts" if k == "trim" else k) for c, k in PALETTE.items()}

# Luminancia de referencia por clase = la del sprite base (así un cuadro
# de animación tiñe IGUAL que el avatar quieto).
REF = {}
for c, k in PALETTE.items():
    if k not in ("fixed",):
        REF[k] = max(REF.get(k, 1), PL.lum(c))
REF["skin"] = PL.SKIN_MAX_LUM


def classify(p):
    if p[3] == 0 or p[:3] == (0, 0, 0):
        return "fixed"
    best, best_d = None, 10 ** 9
    for c in PALETTE:
        d = sum(abs(p[i] - c[i]) for i in range(3))
        if d < best_d:
            best, best_d = c, d
    if best_d <= MAX_DIST:
        return PALETTE[best]
    # Tonos de piel NUEVOS que PixelLab inventa al animar (el puño en
    # escorzo, una mano en sombra): tono naranja/rojizo saturado → piel. El
    # dorado de la copa / Balón de Oro (tono ~40-50°) queda afuera.
    h, sat, v = PL.hsv(p)
    if h < 30 and sat > 0.35 and v > 0.3:
        return "skin"
    return "fixed"


def run():
    done = 0
    for anim in ANIMS:
        src_dir = os.path.join(SRC, anim)
        if not os.path.isdir(src_dir):
            print("  falta", anim)
            continue
        dst = os.path.join(OUT, anim)
        os.makedirs(dst, exist_ok=True)
        i = 0
        while os.path.exists(os.path.join(src_dir, "%d.png" % i)):
            im = Image.open(os.path.join(src_dir, "%d.png" % i)).convert("RGBA")
            msk = Image.new("RGBA", im.size, (0, 0, 0, 0))
            for y in range(im.height):
                for x in range(im.width):
                    p = im.getpixel((x, y))
                    if p[3] == 0:
                        continue
                    cls = classify(p)
                    g = 0 if cls == "fixed" else min(255, int(round(PL.lum(p) / REF[cls] * 255)))
                    msk.putpixel((x, y), (PL.CLASSES[cls], g, 0, 255))
            im.save(os.path.join(dst, "%d.png" % i))
            msk.save(os.path.join(dst, "%d_m.png" % i))
            i += 1
        print("  %-15s %d cuadros" % (anim, i))
        done += 1
    return done


if __name__ == "__main__":
    run()
