"""Baja un personaje de PixelLab (zip sin auth) y extrae rotaciones y
animaciones a art_src/pixellab/<carpeta>/<anim>/<dir>/<n>.png
    python tools/fetch_character.py <carpeta> <character_id>
"""
import io, os, re, sys, urllib.request, zipfile
folder, cid = sys.argv[1], sys.argv[2]
data = urllib.request.urlopen("https://api.pixellab.ai/mcp/characters/%s/download" % cid).read()
z = zipfile.ZipFile(io.BytesIO(data))
out = os.path.join("art_src/pixellab", folder)
count = {}
for n in z.namelist():
    m = re.match(r"[^/]+/rotations/([a-z\-]+)\.png$", n)
    if m:
        d = os.path.join(out, "rotations"); os.makedirs(d, exist_ok=True)
        open(os.path.join(d, m.group(1) + ".png"), "wb").write(z.read(n)); continue
    m = re.match(r"[^/]+/animations/([^/]+)/([a-z\-]+)/frame_(\d+)\.png$", n)
    if m:
        d = os.path.join(out, m.group(1), m.group(2)); os.makedirs(d, exist_ok=True)
        open(os.path.join(d, "%d.png" % int(m.group(3))), "wb").write(z.read(n))
        count[(m.group(1), m.group(2))] = count.get((m.group(1), m.group(2)), 0) + 1
for (a, d), c in sorted(count.items()):
    print("  %-16s %-11s %d" % (a, d, c))
