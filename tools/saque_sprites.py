"""Saque de banda (PixelLab, 16-oct, prototipo match_v2) → pitch_saque_e /
pitch_saque_w en assets/pixelplayer/anim, mismo formato que pitch_sprites.py.

    python tools/saque_sprites.py

Entrada: art_src/pixellab/player_full/pitch_saque/east/<n>.png (68x68, 9 cuadros;
bajar con tools/fetch_character.py player_full <id del personaje base>).

- Solo los cuadros 4..8 (pelota ya atrás de la cabeza → lanzamiento): el
  ejecutor llega caminando, se queda en el cuadro 0 hasta sacar.
- La pelota viene DIBUJADA en el sprite: sus píxeles (blancos/negros a la
  izquierda de la cabeza) se marcan "fixed" en la máscara, si no
  fix_white_shirts los teñía del color de la camiseta.
- Oeste = espejo del este.
"""
import os
import sys
from PIL import Image, ImageOps

sys.path.insert(0, os.path.dirname(__file__))
import anim_layers as AL  # noqa: E402
import pixel_layers as PL  # noqa: E402
import pitch_sprites as PS  # noqa: E402
import anim_boots as AB  # noqa: E402

SRC = "art_src/pixellab/player_full/pitch_saque/east"
FIRST = 4


def _ball_pixels(im, mirrored):
    """Píxeles de la pelota: blancos o casi negros, del lado de atrás de la
    cabeza (izquierda en el original), en la mitad de arriba."""
    hair = [(x, y) for y in range(im.height) for x in range(im.width)
            if im.getpixel((x, y))[3] and PL.hsv(im.getpixel((x, y)))[0] < 45
            and PL.hsv(im.getpixel((x, y)))[1] > 0.35 and y < 24]
    if not hair:
        return set()
    xs = [x for x, _ in hair]
    chin = max(y for _, y in hair) + 4
    out = set()
    for y in range(0, 32):
        for x in range(im.width):
            p = im.getpixel((x, y))
            if not p[3]:
                continue
            behind = x > max(xs) + 1 if mirrored else x < min(xs) - 1
            near_back = x > max(xs) - 3 if mirrored else x < min(xs) + 3
            white = min(p[:3]) >= 170 and max(p[:3]) - min(p[:3]) <= 30
            dark = max(p[:3]) < 70
            # Blanco por encima del mentón = pelota (la cabeza no tiene
            # blanco); negro solo del lado de la nuca (no los ojos).
            if (white and (behind or y < chin)) or (dark and (behind or near_back)):
                out.add((x, y))
    return out


def main():
    frames = [PS._pad(Image.open(os.path.join(SRC, "%d.png" % i))) for i in range(FIRST, 9)]
    names = []
    for name, mir in [("pitch_saque_e", False), ("pitch_saque_w", True)]:
        fr = [ImageOps.mirror(f) for f in frames] if mir else frames
        PS._stage(name, fr)
        names.append(name)
    AL.ANIMS = names
    AL.run()
    PS.fix_white_shirts(names)
    fixed = PL.CLASSES["fixed"]
    for name, mir in [("pitch_saque_e", False), ("pitch_saque_w", True)]:
        d = os.path.join(PS.OUT, name)
        i = 0
        n = 0
        while os.path.exists(os.path.join(d, "%d.png" % i)):
            im = Image.open(os.path.join(d, "%d.png" % i)).convert("RGBA")
            mp = os.path.join(d, "%d_m.png" % i)
            msk = Image.open(mp).convert("RGBA")
            for (x, y) in _ball_pixels(im, mir):
                msk.putpixel((x, y), (fixed, 0, 0, 255))
                n += 1
            msk.save(mp)
            # botines (mismo paso que anim_boots.run, solo para estos cuadros)
            AB.process(os.path.join(d, "%d.png" % i), mp)
            i += 1
        print("  %-16s pelota fija: %d px" % (name, n))


if __name__ == "__main__":
    main()
