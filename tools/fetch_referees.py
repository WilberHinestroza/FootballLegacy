"""Baja los 3 árbitros de PixelLab (personaje + animaciones) y los deja en
assets/referee/<id>/ con los nombres que espera data/Referee.gd:

    idle_0.png                         (pose de frente)
    pitazo_<n>.png, amarilla_<n>.png, roja_<n>.png   (de frente)
    run_<south|east|north|west>_<n>.png

Correr desde la raíz del repo:  python tools/fetch_referees.py
El zip de cada personaje lo sirve PixelLab sin auth en
api.pixellab.ai/mcp/characters/<id>/download (HTTP 423 si todavía tiene
trabajos pendientes — en ese caso volver a correr más tarde).
"""
import io
import os
import re
import sys
import urllib.request
import zipfile

REFEREES = {
    "negro": "af7c07b8-49dd-4827-b006-6490b5b9a986",
    "amarillo": "8ed14fa6-e033-4189-ab69-2365d2282982",
    "turquesa": "5b89cc77-8480-41e3-ae36-d8864c3d71fa",
}
OUT = "assets/referee"
ANIM_MAP = {"pitazo": "pitazo", "amarilla": "amarilla", "roja": "roja", "correr": "run", "var": "var"}


def fetch(ref_id: str, char_id: str) -> int:
    url = "https://api.pixellab.ai/mcp/characters/%s/download" % char_id
    try:
        data = urllib.request.urlopen(url).read()
    except Exception as e:  # 423 = todavía generando
        print("  %s: no disponible (%s)" % (ref_id, e))
        return 0
    z = zipfile.ZipFile(io.BytesIO(data))
    dst = os.path.join(OUT, ref_id)
    os.makedirs(dst, exist_ok=True)
    n = 0
    for name in z.namelist():
        m = re.match(r"[^/]+/rotations/south\.png$", name)
        if m:
            open(os.path.join(dst, "idle_0.png"), "wb").write(z.read(name))
            n += 1
            continue
        m = re.match(r"[^/]+/animations/([^/]+)/([a-z\-]+)/frame_(\d+)\.png$", name)
        if not m:
            continue
        anim, direction, idx = m.group(1), m.group(2), int(m.group(3))
        if anim not in ANIM_MAP:
            continue
        base = ANIM_MAP[anim]
        if base == "run":
            fname = "run_%s_%d.png" % (direction, idx)
        elif direction == "south":
            fname = "%s_%d.png" % (base, idx)
        else:
            continue
        open(os.path.join(dst, fname), "wb").write(z.read(name))
        n += 1
    print("  %s: %d archivos" % (ref_id, n))
    return n


if __name__ == "__main__":
    only = sys.argv[1:] or list(REFEREES)
    for rid in only:
        fetch(rid, REFEREES[rid])
