"""PEINADOS DESDE TODOS LOS ÁNGULOS (17-oct, Wilber: "no se mantienen los
pelos del jugador" → "procede con el pelo").

Los 17 peinados (assets/pixelplayer/hair/<id>.png + _m.png, 48x48) están
dibujados solo DE FRENTE, y el juego los pegaba únicamente en las poses de
frente (tools/anim_head_track.py). En la cancha el jugador corre de espaldas
y de costado → el peinado aparecía y desaparecía.

Este script:
  1. Genera cada peinado DE ESPALDAS (hair_n), DE COSTADO mirando al este
     (hair_e) y al oeste (hair_w, espejo), en el lienzo de 68 de las
     animaciones, alineados con la cabeza de pitch_idle_<dir> cuadro 0:
       - relleno: donde el sprite tiene su corte base (clase 2 de la máscara)
         va el pelo del peinado (calvo → piel; cresta → piel salvo la franja);
       - volumen: el dibujo de frente trasladado (de espaldas, entero; de
         costado, la mitad de atrás + la parte de arriba comprimida), sin
         tapar nunca la cara.
  2. Rastrea la cabeza en TODOS los cuadros de las animaciones de cancha
     (pitch_*), probando las 4 vistas (frente, espalda, este, oeste) y
     quedándose con la que mejor calza.
  3. Escribe data/AnimHeadOffsets.gd: conserva OFFSETS (lo de siempre, para
     las poses de frente) y agrega VIEWS = {anim: [[vista, dx, dy] | null]}.

    python tools/hair_views.py
"""
import os
import re
import numpy as np
from PIL import Image

HAIR = "assets/pixelplayer/hair"
ANIM = "assets/pixelplayer/anim"
OUT = "assets/pixelplayer"
OFFS = "data/AnimHeadOffsets.gd"
SEARCH = 14
MIN_IOU = 0.5
HEAD_ROWS = 12
BASE_OFF = 10

SHORT = {"degradado", "raya", "tupe", "puntas", "engominado"}


def load(path):
    return np.array(Image.open(path).convert("RGBA"))


def head_pts(mask, rows=HEAD_ROWS):
    """Píxeles de cabeza (piel o pelo) de un cuadro: desde lo más alto, `rows` filas."""
    cls = mask[:, :, 0]
    a = mask[:, :, 3] > 0
    hp = a & ((cls == 1) | (cls == 2))
    ys, xs = np.nonzero(hp)
    if len(ys) == 0:
        return None
    top = ys.min()
    keep = ys <= top + rows
    return xs[keep], ys[keep]


def bbox(xs, ys):
    return int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())


# ------------------------------------------------------------------ plantillas
def templates():
    """Vista → (puntos de cabeza, máscara completa del cuadro 0)."""
    t = {}
    for view, anim in (("s", "pitch_idle_south"), ("n", "pitch_idle_north"), ("e", "pitch_idle_east"), ("w", "pitch_idle_west")):
        m = load(os.path.join(ANIM, anim, "0_m.png"))
        pts = head_pts(m)
        cls = m[pts[1], pts[0], 0].astype(np.int32)
        t[view] = (pts, m, cls)
    return t


def best_offset(tpl_pts, frame_hp, tpl_cls=None, frame_cls=None):
    """Mejor corrimiento de la plantilla. Con clases, un acierto exige que
    coincida piel con piel y pelo con pelo: así no se confunde la cabeza de
    frente (cara = piel) con la de espaldas (todo pelo), que tienen la misma
    silueta."""
    xs, ys = tpl_pts
    n = len(xs)
    h, w = frame_hp.shape
    integ = np.pad(frame_hp.astype(np.int32).cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    x0, x1, y0, y1 = bbox(xs, ys)
    best, best_iou = None, 0.0
    for dy in range(-SEARCH, SEARCH + 1):
        yy = ys + dy
        if yy.min() < 0 or yy.max() >= h:
            continue
        for dx in range(-SEARCH, SEARCH + 1):
            xx = xs + dx
            if xx.min() < 0 or xx.max() >= w:
                continue
            if tpl_cls is not None:
                hit = int((frame_cls[yy, xx] == tpl_cls).sum())
            else:
                hit = int(frame_hp[yy, xx].sum())
            if hit * 2 < n:
                continue
            a, b, c, d = y0 + dy, y1 + dy + 1, x0 + dx, x1 + dx + 1
            inbox = int(integ[b, d] - integ[a, d] - integ[b, c] + integ[a, c])
            iou = hit / float(n + inbox - hit)
            if iou > best_iou:
                best, best_iou = (dx, dy), iou
    return best, best_iou


# ------------------------------------------------------------------ peinados
def style_layers(name):
    c = load(os.path.join(HAIR, name + ".png"))
    m = load(os.path.join(HAIR, name + "_m.png"))
    return c, m


def median_g(m, c, cls):
    sel = (c[:, :, 3] > 0) & (m[:, :, 0] == cls)
    if not sel.any():
        return 90
    return int(np.median(m[:, :, 1][sel]))


def _near_hair(sm, sc, x, y):
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            xx, yy = x + dx, y + dy
            if 0 <= xx < sm.shape[1] and 0 <= yy < sm.shape[0] and sc[yy, xx, 3] > 0 and sm[yy, xx, 0] == 2:
                return True
    return False


def put(oc, om, x, y, col, msk):
    if 0 <= x < 68 and 0 <= y < 68:
        oc[y, x] = col
        om[y, x] = msk


def build_view(name, view, tpl, front_box):
    """Peinado `name` visto desde `view` ("n" o "e"), en el lienzo de 68."""
    sc, sm = style_layers(name)
    pts, tmask, _cls = tpl[view]
    hx0, hx1, htop, hbot = bbox(*pts)
    hcx = (hx0 + hx1) // 2
    fx0, fx1, ftop, _ = front_box
    fcx = (fx0 + fx1) // 2
    oc = np.zeros((68, 68, 4), np.uint8)
    om = np.zeros((68, 68, 4), np.uint8)
    g_hair = median_g(sm, sc, 2)
    g_skin = median_g(sm, sc, 1) if name == "calvo" else 150
    # 1) Relleno: donde el sprite tiene su corte base.
    base_hair = (tmask[:, :, 3] > 0) & (tmask[:, :, 0] == 2)
    ys, xs = np.nonzero(base_hair)
    for x, y in zip(xs, ys):
        row = y - htop
        if name in SHORT and row > 8:
            continue
        shade = 1.12 if row < 2 else (1.0 if row < 6 else 0.86)
        if name == "calvo" or (name == "cresta" and (abs(x - hcx) > 1 if view == "n" else row > 2)):
            g = int(min(255, g_skin * (1.05 if row < 3 else 0.95)))
            put(oc, om, x, y, (g, g, g, 255), (1, g, 0, 255))
        else:
            g = int(min(255, g_hair * shade))
            put(oc, om, x, y, (g, g, g, 255), (2, g, 0, 255))
    if name == "calvo":
        return oc, om
    # 2) Volumen: el dibujo de frente trasladado.
    fy, fxs = np.nonzero(sc[:, :, 3] > 0)
    for x, y in zip(fxs, fy):
        X, Y = x + BASE_OFF, y + BASE_OFF          # en el lienzo de 68
        cls = int(sm[y, x, 0])
        if cls == 1:
            continue # piel del dibujo de frente (orejas/frente): no va atrás
        if cls == 0 and not _near_hair(sm, sc, x, y):
            continue # contornos sueltos (barba, puntitos): no son del pelo
        ny = Y - ftop + htop
        if view == "n":
            nx = X - fcx + hcx
        else:
            if Y <= ftop + 3:
                nx = hx0 + int(round((X - fx0) * 0.75))
            elif X <= fcx + 1:
                nx = X - fcx + hcx - 1
            else:
                continue
            # Nunca tapar la cara (piel del sprite delante de la nuca).
            if 0 <= nx < 68 and 0 <= ny < 68 and tmask[ny, nx, 3] > 0 and tmask[ny, nx, 0] == 1 and ny > htop + 3 and nx > hcx:
                continue
        put(oc, om, nx, ny, sc[y, x], sm[y, x])
    return oc, om


def _shift(c, m, d):
    dx, dy = d
    oc = np.zeros_like(c)
    om = np.zeros_like(m)
    h, w = c.shape[:2]
    ys, xs = np.nonzero(c[:, :, 3] > 0)
    for x, y in zip(xs, ys):
        if 0 <= x + dx < w and 0 <= y + dy < h:
            oc[y + dy, x + dx] = c[y, x]
            om[y + dy, x + dx] = m[y, x]
    return oc, om


def write_pair(oc, om, view, name):
    d = os.path.join(OUT, "hair_" + view)
    os.makedirs(d, exist_ok=True)
    Image.fromarray(oc, "RGBA").save(os.path.join(d, name + ".png"))
    Image.fromarray(om, "RGBA").save(os.path.join(d, name + "_m.png"))


def gen_styles(tpl):
    # Caja de la cabeza de frente en el lienzo de 68 (sprite base en (10,10)).
    bm = load("assets/pixelplayer/head/base_m.png")
    xs, ys = head_pts(bm)
    front_box = bbox(xs + BASE_OFF, ys + BASE_OFF)
    names = sorted(f[:-4] for f in os.listdir(HAIR) if f.endswith(".png") and not f.endswith("_m.png"))
    ex0, ex1, etop, _ = bbox(*tpl["e"][0])
    wx0, wx1, wtop, _ = bbox(*tpl["w"][0])
    mx0, mx1 = 67 - ex1, 67 - ex0
    wshift = ((wx0 + wx1) // 2 - (mx0 + mx1) // 2, wtop - etop)
    print("corrimiento oeste:", wshift)
    for name in names:
        nc, nm = build_view(name, "n", tpl, front_box)
        write_pair(nc, nm, "n", name)
        ec, em = build_view(name, "e", tpl, front_box)
        write_pair(ec, em, "e", name)
        # Oeste: espejo del este, corrido para calzar con la cabeza del sprite
        # oeste (es otro dibujo, no un espejo exacto).
        wc, wm = _shift(ec[:, ::-1].copy(), em[:, ::-1].copy(), wshift)
        write_pair(wc, wm, "w", name)
    return names


# ------------------------------------------------------------------ rastreo
def _hint(anim):
    n = anim.lower()
    if n.endswith("west") or n.endswith("_w") or n.endswith("south-west") or n.endswith("_sw"):
        return "w"
    if n.endswith("east") or n.endswith("_e") or n.endswith("south-east") or n.endswith("_se"):
        return "e"
    if n.endswith("north") or n.endswith("north-east") or n.endswith("north-west"):
        return "n"
    return None


def track(tpl):
    views = {}
    for anim in sorted(os.listdir(ANIM)):
        if not anim.startswith("pitch_"):
            continue
        rows = []
        i = 0
        while os.path.exists(os.path.join(ANIM, anim, "%d_m.png" % i)):
            m = load(os.path.join(ANIM, anim, "%d_m.png" % i))
            hp = (m[:, :, 3] > 0) & ((m[:, :, 0] == 1) | (m[:, :, 0] == 2))
            fcls = np.where(hp, m[:, :, 0], 0).astype(np.int32)
            best = None
            for v in ("s", "n", "e", "w"):
                off, iou = best_offset(tpl[v][0], hp, tpl[v][2], fcls)
                if off is not None and iou >= MIN_IOU and (best is None or iou > best[2]):
                    best = (v, off, iou)
            if best is None:
                # Respaldo: solo silueta, y SOLO con la vista que dice el nombre
                # (corre al oeste → "w"): así nunca se tapa una cara con pelo de nuca.
                hint = _hint(anim)
                if hint is not None:
                    off, iou = best_offset(tpl[hint][0], hp)
                    if off is not None and iou >= 0.6:
                        best = (hint, off, iou)
            rows.append(None if best is None else [best[0], best[1][0], best[1][1]])
            i += 1
        # Correr/conducir: UNA sola vista por animación (la mayoritaria); si
        # no, en las diagonales el peinado cambiaba de forma a cada paso.
        if anim.startswith("pitch_run_") or anim.startswith("pitch_drib_"):
            cnt = {}
            for r in rows:
                if r is not None:
                    cnt[r[0]] = cnt.get(r[0], 0) + 1
            if cnt:
                major = max(cnt, key=cnt.get)
                for k in range(len(rows)):
                    if rows[k] is None or rows[k][0] != major:
                        m2 = load(os.path.join(ANIM, anim, "%d_m.png" % k))
                        hp2 = (m2[:, :, 3] > 0) & ((m2[:, :, 0] == 1) | (m2[:, :, 0] == 2))
                        off, iou = best_offset(tpl[major][0], hp2)
                        rows[k] = [major, off[0], off[1]] if off is not None and iou >= 0.45 else None
        # Huecos de UN cuadro entre dos de la misma vista: se completan con el
        # promedio (si no, el peinado parpadea un cuadro).
        for k in range(1, len(rows) - 1):
            pv, nx = rows[k - 1], rows[k + 1]
            if rows[k] is None and pv is not None and nx is not None and pv[0] == nx[0]:
                rows[k] = [pv[0], (pv[1] + nx[1]) // 2, (pv[2] + nx[2]) // 2]
        if rows:
            views[anim] = rows
    return views


def write_offsets(views):
    src = open(OFFS, encoding="utf-8").read()
    src = re.sub(r"\n## VISTAS \(hair_views\.py\).*", "", src, flags=re.S)
    lines = ["", "## VISTAS (hair_views.py): por cuadro de cada animación de cancha, desde",
             "## dónde se ve la cabeza (\"s\" frente, \"n\" espalda, \"e\"/\"w\" costado) y",
             "## cuánto se movió respecto de pitch_idle_<vista> cuadro 0 (null = no calza).",
             "## \"s\" usa los peinados de siempre (hair/); el resto, hair_n / hair_e / hair_w.",
             "const VIEWS := {"]
    for anim, rows in views.items():
        cells = ["null" if r is None else '["%s", %d, %d]' % (r[0], r[1], r[2]) for r in rows]
        lines.append('\t"%s": [%s],' % (anim, ", ".join(cells)))
    lines.append("}")
    open(OFFS, "w", encoding="utf-8", newline="\n").write(src.rstrip("\n") + "\n" + "\n".join(lines) + "\n")


if __name__ == "__main__":
    tpl = templates()
    names = gen_styles(tpl)
    print("peinados:", len(names))
    views = track(tpl)
    tot = sum(len(r) for r in views.values())
    hit = sum(1 for r in views.values() for c in r if c is not None)
    print("animaciones: %d  cuadros: %d  con cabeza: %d" % (len(views), tot, hit))
    write_offsets(views)
