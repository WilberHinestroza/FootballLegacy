"""Baja imágenes de PixelLab por job id a art_src/pixellab/<carpeta>/<nombre>.png
y las anota en art_src/pixellab/jobs.tsv. Uso:
    python tools/fetch_pixellab.py carpeta nombre:jobid [nombre:jobid ...]
Las URLs de descarga de imágenes no piden auth.
"""
import os
import sys
import urllib.request

BASE = "art_src/pixellab"
folder = sys.argv[1]
os.makedirs(os.path.join(BASE, folder), exist_ok=True)
with open(os.path.join(BASE, "jobs.tsv"), "a", encoding="utf-8") as log:
    for pair in sys.argv[2:]:
        name, jid = pair.split(":", 1)
        dst = os.path.join(BASE, folder, name + ".png")
        try:
            data = urllib.request.urlopen("https://api.pixellab.ai/mcp/images/%s/download" % jid).read()
            open(dst, "wb").write(data)
            log.write("%s/%s\t%s\n" % (folder, name, jid))
            print("ok  ", folder + "/" + name)
        except Exception as e:
            print("FALTA", name, e)
