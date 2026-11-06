"""Animaciones extra de cancha (16-oct, prototipo match_v2) → assets/pixelplayer/anim,
mismo formato que pitch_sprites.py (máscara R = clase, G = luminancia).

    python tools/proto_extra_sprites.py

Entrada (bajar con tools/fetch_character.py):
  art_src/pixellab/player_full/<carpeta>/<dir>/<n>.png   (personaje base)
  art_src/pixellab/goalkeeper/<carpeta>/<dir>/<n>.png    (arquero)
Convención de nombres (la usa ProtoMatch._action_names):
  norte = sin sufijo, sur = _s, este = _e, oeste = _w (espejo del este).
  Arquero: sur (el de arriba, mira a la cancha) = sin sufijo, norte = _n.
"""
import os
import sys
from PIL import Image, ImageOps

sys.path.insert(0, os.path.dirname(__file__))
import anim_layers as AL  # noqa: E402
import pitch_sprites as PS  # noqa: E402
import anim_boots as AB  # noqa: E402

PF = "art_src/pixellab/player_full"
GK = "art_src/pixellab/goalkeeper"

# (carpeta PixelLab, dirección, nombre de salida, nombre del espejo o None)
PLAYER = [
    ("pitch_entrada_dir", "south", "pitch_entrada_s", None),
    ("pitch_entrada_dir", "east", "pitch_entrada_e", "pitch_entrada_w"),
    ("pitch_cabezazo_dir", "east", "pitch_cabezazo_e", "pitch_cabezazo_w"),
    ("pitch_regate_dir", "south", "pitch_regate_s", None),
    # 17-oct: regate de costado regenerado (la pelota dibujada sale suelta
    # y se borra con _strip_detached) y cabezazo de frente sin pelota.
    ("pitch_regate2", "east", "pitch_regate_e", "pitch_regate_w"),
    ("pitch_cabezazo2", "south", "pitch_cabezazo_s", None),
    # DT en la banda (mira a la cancha = este; el otro banco también está a la izquierda).
    ("coach_grita", "east", "coach_grita", None),
    ("coach_festeja", "east", "coach_festeja", None),
    ("coach_lamenta", "east", "coach_lamenta", None),
    ("pitch_caida_dir", "south", "pitch_caida_s", None),
    ("pitch_caida_dir", "east", "pitch_caida_e", "pitch_caida_w"),
    ("pitch_barrera", "south", "pitch_barrera_s", None),
    ("pitch_barrera", "north", "pitch_barrera", None),
    ("pitch_control", "north", "pitch_control", None),
    # 17-oct (video 2 de Wilber, "faltan animaciones y fluidez"): trote,
    # carrera de 8 cuadros, levantarse y control de pelota de frente/costado.
    ("pitch_trote", "north", "pitch_trote_north", None),
    ("pitch_trote", "south", "pitch_trote_south", None),
    ("pitch_trote", "east", "pitch_trote_east", None),
    ("pitch_trote", "west", "pitch_trote_west", None),
    ("pitch_trote", "north-east", "pitch_trote_north-east", None),
    ("pitch_trote", "north-west", "pitch_trote_north-west", None),
    ("pitch_trote", "south-east", "pitch_trote_south-east", None),
    ("pitch_trote", "south-west", "pitch_trote_south-west", None),
    ("pitch_correr8", "north", "pitch_run8_north", None),
    ("pitch_correr8", "south", "pitch_run8_south", None),
    ("pitch_correr8", "east", "pitch_run8_east", None),
    ("pitch_correr8", "west", "pitch_run8_west", None),
    ("pitch_correr8", "north-east", "pitch_run8_north-east", None),
    ("pitch_correr8", "north-west", "pitch_run8_north-west", None),
    ("pitch_correr8", "south-east", "pitch_run8_south-east", None),
    ("pitch_correr8", "south-west", "pitch_run8_south-west", None),
    ("pitch_levanta", "north", "pitch_levanta", None),
    ("pitch_levanta", "south", "pitch_levanta_s", None),
    ("pitch_levanta", "east", "pitch_levanta_e", "pitch_levanta_w"),
    ("pitch_control2", "south", "pitch_control_s", None),
    ("pitch_control2", "east", "pitch_control_e", "pitch_control_w"),
    # ("cabezazo", "south"): trae la pelota pegada a la cabeza → no se usa;
    # al sur cae al cabezazo de espaldas (ProtoMatch.DIR_TRY).
]
# (carpeta, dirección, salida, cuadros, quitar pelotas sueltas desde el cuadro N
#  de la lista o None). gk_hold arranca SIN pelota (la recoge en 0-1) → 2..4.
# Lanzar/saque largo: la pelota dibujada sirve MIENTRAS la tiene en las manos
# (la escena oculta la pelota real hasta el contacto, cuadro 6 de la lista);
# después de soltarla se saca del dibujo (si no, se verían dos pelotas).
KEEPER = [
    ("gk_hold", "south", "gk_hold", [2, 3, 4], None),
    ("gk_hold", "north", "gk_hold_n", [2, 3, 4], None),
    # Saque largo: el cuadro 6 (contacto, la pelota pegada al guante) se salta;
    # de espaldas la pelota sigue en todos los cuadros de después → termina
    # en la pose inicial.
    ("gk_saque_largo", "south", "gk_saque_largo", [0, 1, 2, 3, 4, 5, 7, 8], None),
    ("gk_saque_largo", "north", "gk_saque_largo_n", [0, 1, 2, 3, 4, 5, 0], None),
    ("gk_lanzar", "south", "gk_lanzar", [0, 1, 2, 3, 4, 5, 8], None),
    ("gk_lanzar", "north", "gk_lanzar_n", list(range(8)), None),
    ("gk_punos", "south", "gk_punos", list(range(9)), None),
    ("gk_punos", "north", "gk_punos_n", list(range(9)), None),
    ("gk_achique", "south", "gk_achique", list(range(9)), None),
    ("gk_achique", "north", "gk_achique_n", list(range(9)), None),
    # Postura de alerta (rebota en el lugar): el idle del arquero cuando la
    # pelota anda cerca de su arco.
    ("gk_alerta", "south", "gk_alerta", [4, 5, 6, 7, 8, 7, 6, 5], None),
    ("gk_alerta", "north", "gk_alerta_n", [4, 5, 6, 7, 8, 7, 6, 5], None),
]


def _strip_detached(im, max_px=80):
    """Borra las manchas chicas separadas del cuerpo (una pelota en el aire)."""
    im = im.copy()
    px = im.load()
    w, h = im.size
    seen = set()
    comps = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] and (x, y) not in seen:
                st = [(x, y)]
                seen.add((x, y))
                c = []
                while st:
                    a, b = st.pop()
                    c.append((a, b))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            q = (a + dx, b + dy)
                            if 0 <= q[0] < w and 0 <= q[1] < h and q not in seen and px[q][3]:
                                seen.add(q)
                                st.append(q)
                comps.append(c)
    comps.sort(key=len, reverse=True)
    for c in comps[1:]:
        if len(c) <= max_px:
            for q in c:
                px[q] = (0, 0, 0, 0)
    return im


def _clear(name):
    """Borra los cuadros viejos de una animación (si la nueva tiene menos
    cuadros, los sobrantes quedaban y se mostraban)."""
    d = os.path.join(PS.OUT, name)
    if not os.path.isdir(d):
        return
    for f in os.listdir(d):
        if f.endswith(".png") or f.endswith(".png.import"):
            os.remove(os.path.join(d, f))


def _src(base, folder, d):
    """PixelLab guarda en "<nombre>-<grupo>" la segunda animación con el
    mismo nombre (otra dirección pedida aparte): buscar ambas."""
    for f in sorted(os.listdir(base)):
        if (f == folder or f.startswith(folder + "-")) and os.path.isdir(os.path.join(base, f, d)):
            return os.path.join(base, f, d)
    return os.path.join(base, folder, d)


def _strip_green_ball(im):
    """El regate de frente salió con una pelota verde y blanca dibujada:
    se borra todo lo verde y lo claro a menos de 5 px de lo verde."""
    import pixel_layers as PL
    im = im.copy()
    px = im.load()
    green = [(x, y) for y in range(im.height) for x in range(im.width)
             if px[x, y][3] and 60 <= PL.hsv(px[x, y])[0] <= 180 and PL.hsv(px[x, y])[1] > 0.2]
    if not green:
        return im
    cx = sum(x for x, _ in green) / len(green)
    cy = sum(y for _, y in green) / len(green)
    for y in range(im.height):
        for x in range(im.width):
            p = px[x, y]
            if not p[3]:
                continue
            near = (x - cx) ** 2 + (y - cy) ** 2 <= 6.5 ** 2
            is_green = 60 <= PL.hsv(p)[0] <= 180 and PL.hsv(p)[1] > 0.2
            light = min(p[:3]) >= 150
            dark_outline = max(p[:3]) < 60
            if is_green or (near and (light or dark_outline)):
                px[x, y] = (0, 0, 0, 0)
    return im


def player():
    names = []
    for folder, d, name, mirror in PLAYER:
        fr = PS._frames(_src(PF, folder, d))
        if not fr:
            print("  falta", folder, d)
            continue
        if folder == "pitch_regate_dir" and d == "south":
            fr = [_strip_green_ball(f) for f in fr]
        if folder == "pitch_control2":
            # PixelLab dibujó la pelota: en 3-5 está pegada al pie → afuera;
            # en el resto se borra si quedó suelta.
            fr = [_strip_detached(fr[i], 80) for i in (0, 1, 2, 6, 7, 8) if i < len(fr)]
        if folder == "pitch_regate2":
            # 4 y 5: la pelota dibujada toca el pie (quedaba teñida) → afuera.
            fr = [_strip_detached(fr[i], 80) for i in (0, 1, 2, 3, 6, 7, 8) if i < len(fr)]
        fr = [PS._body_only(f) for f in fr]
        _clear(name)
        PS._stage(name, fr)
        names.append(name)
        if mirror:
            _clear(mirror)
            PS._stage(mirror, [ImageOps.mirror(f) for f in fr])
            names.append(mirror)
    if not names:
        return
    AL.ANIMS = names
    AL.run()
    PS.fix_white_shirts(names)
    for name in names:
        d = os.path.join(PS.OUT, name)
        i = 0
        while os.path.exists(os.path.join(d, "%d.png" % i)):
            AB.process(os.path.join(d, "%d.png" % i), os.path.join(d, "%d_m.png" % i))
            i += 1


def keeper():
    if not os.path.exists(os.path.join(GK, "rotations", "south.png")):
        return
    ref = PS._gk_ref()
    for folder, d, name, idxs, strip_from in KEEPER:
        allf = PS._frames(_src(GK, folder, d))
        fr = [allf[i] for i in idxs if i < len(allf)]
        if not fr:
            print("  falta", folder, d)
            continue
        if strip_from is not None:
            fr = [(_strip_detached(f) if k >= strip_from else f) for k, f in enumerate(fr)]
        # Sin _body_only: la pelota en las manos va pegada o separada y tiene
        # que quedar (blanca = "fixed" para gk_classify).
        _clear(name)
        PS._write(name, fr, PS.gk_classify, ref)


if __name__ == "__main__":
    player()
    keeper()
