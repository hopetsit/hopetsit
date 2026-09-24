#!/usr/bin/env python3
"""v585 (lot D) — ZÉRO GRIS, preuve par les PIXELS (règle de Daniel du 25/09).

Mesure, sur des captures d'écran (iPhone / Android), la part de pixels GRIS :
saturation quasi nulle (S < 0,08 en HSV) hors blancs (V > 0,93) et noirs
(V < 0,15), hors barre d'état (haut) et barre système Android (bas), hors
zones de photo / carte (rectangles à exclure passés en option).

Usage : python3 tool/gris_pixels.py <dossier_ou_fichiers.png> [--seuil 0.5]
        [--haut 90] [--bas 120] [--exclure fichier.png=x0,y0,x1,y1;...]
Sortie : une ligne par capture (« % gris »), la liste des captures au-dessus du
seuil, et un code de sortie 1 s'il en reste. Les chiffres vont dans le rapport.
"""
import argparse, glob, os, sys
from PIL import Image

def mesure(path, haut, bas, exclure):
    im = Image.open(path).convert('RGB')
    w, h = im.size
    hsv = im.convert('HSV')
    px = hsv.load()
    boxes = exclure.get(os.path.basename(path), [])
    total = 0; gris = 0
    # échantillonnage 1 pixel sur 2 (les captures 2x/3x sont grandes)
    for y in range(haut, h - bas, 2):
        for x in range(0, w, 2):
            if any(x0 <= x < x1 and y0 <= y < y1 for (x0, y0, x1, y1) in boxes):
                continue
            hh, s, v = px[x, y]
            v /= 255.0; s /= 255.0
            if v > 0.93 or v < 0.15:
                continue
            total += 1
            if s < 0.08:
                gris += 1
    return (100.0 * gris / total) if total else 0.0, total

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('cibles', nargs='+')
    ap.add_argument('--seuil', type=float, default=0.5, help='pourcentage de pixels gris toléré')
    ap.add_argument('--haut', type=int, default=90, help='pixels ignorés en haut (barre d\'état)')
    ap.add_argument('--bas', type=int, default=0, help='pixels ignorés en bas (barre système)')
    ap.add_argument('--exclure', default='', help='fichier=x0,y0,x1,y1;… (photos, carte)')
    a = ap.parse_args()
    exclure = {}
    for part in filter(None, a.exclure.split(';')):
        f, rect = part.split('=')
        exclure.setdefault(f, []).append(tuple(int(v) for v in rect.split(',')))
    files = []
    for c in a.cibles:
        files += sorted(glob.glob(os.path.join(c, '*.png'))) if os.path.isdir(c) else [c]
    if not files:
        print('aucune capture'); return 2
    restes = []
    for f in files:
        pct, n = mesure(f, a.haut, a.bas, exclure)
        flag = '  ⚠ GRIS' if pct > a.seuil else ''
        print(f'{pct:6.2f} %  {os.path.basename(f)}{flag}')
        if pct > a.seuil:
            restes.append((os.path.basename(f), pct))
    print(f'\n{len(files)} captures · seuil {a.seuil} % · {len(restes)} au-dessus du seuil')
    for f, pct in restes:
        print(f'  reste : {f} ({pct:.2f} %)')
    return 1 if restes else 0

if __name__ == '__main__':
    sys.exit(main())
