#!/usr/bin/env python3
"""v585 (lot D) — ZÉRO GRIS, preuve par les PIXELS (règle de Daniel du 25/09).

Mesure, sur des captures d'écran (iPhone / Android / site), la part de pixels
GRIS : saturation quasi nulle (S < 0,08 en HSV) hors blancs (V > 0,93) et noirs
(V < 0,15), hors bandes du haut / du bas (barre d'état, barre système) et hors
rectangles à exclure (photos, carte). Les contours anti-crénelés du texte noir
sur blanc donnent des pixels gris d'1 px de large : ils ne sont PAS des zones
grises. On ne compte donc que les pixels gris dont TOUT le voisinage 3×3 est
gris (érosion), c'est-à-dire les APLATS (fonds, boutons, bordures ≥ 3 px).

Usage : python3 tool/gris_pixels.py <dossier_ou_fichiers.png> [--seuil 0.5]
        [--haut 90] [--bas 120] [--exclure fichier.png=x0,y0,x1,y1;...]
        [--sortie dossier]   (écrit un masque <nom>_gris.png des zones trouvées)
Sortie : une ligne par capture (« % gris »), la liste des captures au-dessus du
seuil, et un code de sortie 1 s'il en reste. Les chiffres vont dans le rapport.
"""
import argparse, glob, os, sys
from PIL import Image, ImageFilter, ImageChops

def mesure(path, haut, bas, exclure, sortie=None):
    im = Image.open(path).convert('RGB')
    w, h = im.size
    hsv = im.convert('HSV')
    _, s, v = hsv.split()
    # gris candidat : S < 0,08 (≈ 20/255) ET 0,15 < V < 0,93 (≈ 38..237)
    sat_low = s.point(lambda p: 255 if p < 20 else 0)
    v_mid = v.point(lambda p: 255 if 38 < p < 237 else 0)
    cand = ImageChops.multiply(sat_low, v_mid)
    # zone mesurée : hors bandes haut / bas et hors rectangles exclus
    zone = Image.new('L', (w, h), 255)
    zone.paste(0, (0, 0, w, haut))
    zone.paste(0, (0, h - bas, w, h))
    for (x0, y0, x1, y1) in exclure.get(os.path.basename(path), []):
        zone.paste(0, (x0, y0, x1, y1))
    cand = ImageChops.multiply(cand, zone)
    # aplats seulement : érosion 3×3 (les contours de texte d'1 px disparaissent)
    solid = cand.filter(ImageFilter.MinFilter(3))
    # dénominateur : pixels de la zone, ni blancs ni noirs
    countable = ImageChops.multiply(v_mid, zone)
    total = countable.histogram()[255]
    gris = solid.histogram()[255]
    if sortie:
        os.makedirs(sortie, exist_ok=True)
        over = im.copy()
        red = Image.new('RGB', (w, h), (255, 0, 0))
        over.paste(red, (0, 0), solid)
        over.save(os.path.join(sortie, os.path.splitext(os.path.basename(path))[0] + '_gris.png'))
    return (100.0 * gris / total) if total else 0.0, total

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('cibles', nargs='+')
    ap.add_argument('--seuil', type=float, default=0.5, help='pourcentage de pixels gris toléré')
    ap.add_argument('--haut', type=int, default=90, help='pixels ignorés en haut (barre d\'état)')
    ap.add_argument('--bas', type=int, default=0, help='pixels ignorés en bas (barre système)')
    ap.add_argument('--exclure', default='', help='fichier=x0,y0,x1,y1;… (photos, carte)')
    ap.add_argument('--sortie', default='', help='dossier des masques rouges (zones grises)')
    a = ap.parse_args()
    exclure = {}
    for part in filter(None, a.exclure.split(';')):
        f, rect = part.split('=')
        exclure.setdefault(f, []).append(tuple(int(x) for x in rect.split(',')))
    files = []
    for c in a.cibles:
        files += sorted(glob.glob(os.path.join(c, '*.png'))) if os.path.isdir(c) else [c]
    if not files:
        print('aucune capture'); return 2
    restes = []
    for f in files:
        pct, n = mesure(f, a.haut, a.bas, exclure, a.sortie or None)
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
