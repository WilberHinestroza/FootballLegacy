"""Jugadores y arqueros de la cancha 2D (PixelLab, 9-oct) → cuadros +
máscaras de tinte en assets/pixelplayer/anim/, mismo formato que
tools/anim_layers.py (R = clase, G = luminancia) para Avatar.anim_frames().

    python tools/pitch_sprites.py

Entrada (generada, NO recortada a mano):
  art_src/pixellab/player_full/rotations/<dir>.png      (48x48, quieto)
  art_src/pixellab/player_full/correr/<dir>/<n>.png     (48x48, 8 dir)
  art_src/pixellab/player_full/{remate,pase,barrida}/north/<n>.png (68x68)
  art_src/pixellab/goalkeeper/rotations/<dir>.png       (48x48, 4 dir)
  art_src/pixellab/goalkeeper/{atajada,estirada_izq,estirada_der}/south/<n>.png
Salida:
  pitch_idle_<dir>, pitch_run_<dir>, pitch_remate, pitch_pase, pitch_barrida
  gk_idle_<dir>, gk_atajada, gk_estirada_izq, gk_estirada_der
Los cuadros de 48 se centran en el lienzo de 68 (el de las animaciones),
así todas las animaciones comparten el mismo punto de anclaje.
"""
import os
import shutil
import sys
from PIL import Image, ImageOps

sys.path.insert(0, os.path.dirname(__file__))
import anim_layers as AL  # noqa: E402
import pixel_layers as PL  # noqa: E402

SRC = "art_src/pixellab"
STAGE = "art_src/pixellab/player_anims"
OUT = "assets/pixelplayer/anim"
DIRS8 = ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
CANVAS = 68


def _pad(im):
    im = im.convert("RGBA")
    if im.size == (CANVAS, CANVAS):
        return im
    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    out.paste(im, ((CANVAS - im.width) // 2, (CANVAS - im.height) // 2))
    return out


def _frames(path_dir):
    out = []
    i = 0
    while os.path.exists(os.path.join(path_dir, "%d.png" % i)):
        out.append(_pad(Image.open(os.path.join(path_dir, "%d.png" % i))))
        i += 1
    return out


def _body_only(im):
    """Deja solo la figura del jugador: PixelLab a veces dibuja una pelota
    suelta al lado (un manchón aparte). Se queda la mancha más grande."""
    w, h = im.size
    px = im.load()
    seen = [[False] * w for _ in range(h)]
    best = []
    for y0 in range(h):
        for x0 in range(w):
            if seen[y0][x0] or px[x0, y0][3] == 0:
                continue
            comp = []
            stack = [(x0, y0)]
            seen[y0][x0] = True
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] != 0:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            if len(comp) > len(best):
                best = comp
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    op = out.load()
    for x, y in best:
        op[x, y] = px[x, y]
    return out


def _stage(name, frames):
    d = os.path.join(STAGE, name)
    if os.path.isdir(d):
        shutil.rmtree(d)
    os.makedirs(d)
    for i, im in enumerate(frames):
        im.save(os.path.join(d, "%d.png" % i))


def stage_player():
    names = []
    pf = os.path.join(SRC, "player_full")
    for d in DIRS8:
        rot = os.path.join(pf, "rotations", d + ".png")
        if os.path.exists(rot):
            # (La plantilla "breathing-idle" de PixelLab se probo el 11-oct y se
            # descarto: redibuja al personaje — salia calvo. La respiracion se
            # hace por codigo en PitchView.)
            _stage("pitch_idle_" + d, [_pad(Image.open(rot))])
            names.append("pitch_idle_" + d)
        run = _frames(os.path.join(pf, "correr", d))
        if run:
            _stage("pitch_run_" + d, run)
            names.append("pitch_run_" + d)
        # 11-oct: conduccion con pelota (8 direcciones).
        drib = _frames(os.path.join(pf, "pitch_conduccion", d))
        if drib:
            _stage("pitch_drib_" + d, [_body_only(f) for f in drib])
            names.append("pitch_drib_" + d)
    for a in ["remate", "pase", "barrida"]:
        fr = _frames(os.path.join(pf, a, "north"))
        if fr:
            _stage("pitch_" + a, fr)
            names.append("pitch_" + a)
    # 11-oct: pase / remate / barrida hacia abajo y hacia los costados
    # (oeste = espejo del este).
    for a in ["remate", "pase", "barrida"]:
        for d, sfx, mir in [("south", "s", ""), ("east", "e", "w"), ("north-east", "ne", "nw"), ("south-east", "se", "sw")]:
            fr = _frames(os.path.join(pf, "pitch_%s_dir" % a, d))
            if not fr:
                print("  falta", a, d)
                continue
            fr = [_body_only(f) for f in fr]
            if a == "barrida" and sfx in ("e", "ne", "se"):
                # PixelLab la dibuja tirandose de CABEZA; una barrida va con los
                # pies adelante: los cuadros en el piso se espejan (pies al frente).
                fr = fr[:2] + [ImageOps.mirror(f) for f in fr[2:]]
            _stage("pitch_%s_%s" % (a, sfx), fr)
            names.append("pitch_%s_%s" % (a, sfx))
            if mir:
                _stage("pitch_%s_%s" % (a, mir), [ImageOps.mirror(f) for f in fr])
                names.append("pitch_%s_%s" % (a, mir))
    # 10-oct: gestos de acción (PixelLab guarda la carpeta con el nombre
    # que se le dio a la animación: pitch_<gesto>).
    for a, d in [("entrada", "north"), ("cabezazo", "north"), ("caida", "north"), ("regate", "north"),
                 ("volea", "north"), ("chilena", "north"), ("cuerpeo", "north"), ("protesta", "south"), ("festejo", "south")]:
        fr = []
        # "<gesto>2" = segunda toma (la primera salió con una pelota dibujada).
        for folder in ["pitch_" + a + "2", "pitch_" + a]:
            fr = _frames(os.path.join(pf, folder, d))
            if fr:
                break
        if fr:
            _stage("pitch_" + a, [_body_only(f) for f in fr])
            names.append("pitch_" + a)
        else:
            print("  falta", a)
    return names


# --- Arquero: buzo verde → clase "shirt" (se tiñe con el color de arquero
# del club), guantes blancos fijos, el resto (piel/pelo/short) igual que el
# jugador de campo.
def gk_classify(p):
    if p[3] == 0 or p[:3] == (0, 0, 0):
        return "fixed"
    h, s, v = PL.hsv(p)
    if 70 <= h <= 170 and s > 0.25 and v > 0.12:
        return "shirt"
    if s < 0.15 and v > 0.7:
        return "fixed"   # guantes
    cls = AL.classify(p)
    return "fixed" if cls == "shirt" else cls


def _gk_ref():
    ref = dict(AL.REF)
    im = Image.open(os.path.join(SRC, "goalkeeper", "rotations", "south.png")).convert("RGBA")
    m = 1
    for y in range(im.height):
        for x in range(im.width):
            p = im.getpixel((x, y))
            if p[3] and gk_classify(p) == "shirt":
                m = max(m, PL.lum(p))
    ref["shirt"] = m
    return ref


def _write(name, frames, classify, ref):
    dst = os.path.join(OUT, name)
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    os.makedirs(dst)
    for i, im in enumerate(frames):
        msk = Image.new("RGBA", im.size, (0, 0, 0, 0))
        for y in range(im.height):
            for x in range(im.width):
                p = im.getpixel((x, y))
                if p[3] == 0:
                    continue
                cls = classify(p)
                g = 0 if cls == "fixed" else min(255, int(round(PL.lum(p) / ref[cls] * 255)))
                msk.putpixel((x, y), (PL.CLASSES[cls], g, 0, 255))
        im.save(os.path.join(dst, "%d.png" % i))
        msk.save(os.path.join(dst, "%d_m.png" % i))
    print("  %-22s %d cuadros" % (name, len(frames)))


# Hacia qué lado camina el arte original de "paso_lateral" (se confirma
# mirando la hoja): [lado del original, lado del espejo].
STEP_SIDE = ["der", "izq"]


def keeper():
    ref = _gk_ref()
    gk = os.path.join(SRC, "goalkeeper")
    for d in ["north", "east", "south", "west"]:
        p = os.path.join(gk, "rotations", d + ".png")
        if os.path.exists(p):
            _write("gk_idle_" + d, [_pad(Image.open(p))], gk_classify, ref)
    for a in ["atajada", "estirada_der", "salto"]:
        fr = _frames(os.path.join(gk, a, "south"))
        if fr:
            _write("gk_" + a, fr, gk_classify, ref)
    # 10-oct (Wilber: "el arquero solo se tira a la derecha"): la
    # "estirada_izq" de PixelLab salió volando TAMBIÉN hacia la derecha de
    # la pantalla. La izquierda es ahora el espejo exacto de la derecha.
    fr = _frames(os.path.join(gk, "estirada_der", "south"))
    if fr:
        _write("gk_estirada_izq", [ImageOps.mirror(f) for f in fr], gk_classify, ref)
    # 11-oct: el arquero visto de ESPALDAS (tu arco en la cámara detrás del
    # arco). La izquierda es el espejo de la derecha, igual que de frente.
    fr = _frames(os.path.join(gk, "estirada_der_n", "north"))
    if fr:
        _write("gk_estirada_der_n", [_body_only(f) for f in fr], gk_classify, ref)
        _write("gk_estirada_izq_n", [ImageOps.mirror(_body_only(f)) for f in fr], gk_classify, ref)
    # 11-oct: pasos laterales antes de tirarse (de frente y de espaldas);
    # el otro lado es el espejo.
    for d, sfx in [("south", ""), ("north", "_n")]:
        fr = _frames(os.path.join(gk, "paso_lateral", d))
        if fr:
            # Solo los cuadros ya agachado y con los brazos abiertos: si el
            # ciclo vuelve a pararse derecho, "salta" en cada vuelta.
            fr = [_body_only(f) for f in fr[3:]]
            _write("gk_paso_%s%s" % (STEP_SIDE[0], sfx), fr, gk_classify, ref)
            _write("gk_paso_%s%s" % (STEP_SIDE[1], sfx), [ImageOps.mirror(f) for f in fr], gk_classify, ref)
    # 11-oct: VOLADA ALTA (a los ángulos, tiros libres). PixelLab la dibuja
    # como un salto recto con los brazos arriba; la diagonal hacia el palo
    # se la da PitchView girando el sprite en el aire.
    for d, sfx in [("south", ""), ("north", "_n")]:
        fr = _frames(os.path.join(gk, "volada_alta", d))
        if fr:
            _write("gk_volada" + sfx, [_body_only(f) for f in fr], gk_classify, ref)
    fr = _frames(os.path.join(gk, "atajada_n", "north"))
    if fr:
        _write("gk_atajada_n", [_body_only(f) for f in fr], gk_classify, ref)


def fix_white_shirts(names):
    """La camiseta de los cuadros ANIMADOS es más blanca que la del sprite
    quieto y la paleta la confundía con el blanco "fijo" (ojos / botines):
    el jugador corría con la camiseta SIN teñir (visto el 10-oct en una
    captura). Regla por posición: blanco en la parte alta del cuerpo =
    camiseta; abajo = botines (fijo). Tirado en el piso (caída, chilena) no
    hay "arriba": todo el blanco es camiseta."""
    fixed, shirt = PL.CLASSES["fixed"], PL.CLASSES["shirt"]
    n = 0
    for name in names:
        d = os.path.join(OUT, name)
        i = 0
        while os.path.exists(os.path.join(d, "%d.png" % i)):
            im = Image.open(os.path.join(d, "%d.png" % i)).convert("RGBA")
            mp = os.path.join(d, "%d_m.png" % i)
            msk = Image.open(mp).convert("RGBA")
            ys = [y for y in range(im.height) for x in range(im.width) if im.getpixel((x, y))[3]]
            if ys:
                top, bot = min(ys), max(ys)
                cut = top + (bot - top) * 0.70 if (bot - top) >= 30 else 10 ** 6
                for y in range(im.height):
                    for x in range(im.width):
                        q = im.getpixel((x, y))
                        m = msk.getpixel((x, y))
                        if q[3] and m[0] == fixed and y < cut and min(q[:3]) >= 200 and max(q[:3]) - min(q[:3]) <= 24:
                            msk.putpixel((x, y), (shirt, min(255, int(round(PL.lum(q) / AL.REF["shirt"] * 255))), 0, 255))
                            n += 1
                msk.save(mp)
            i += 1
    print("  camisetas blancas corregidas: %d píxeles" % n)


if __name__ == "__main__":
    AL.ANIMS = stage_player()
    AL.run()
    fix_white_shirts(AL.ANIMS)
    keeper()
