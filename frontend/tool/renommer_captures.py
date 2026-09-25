#!/usr/bin/env python3
"""v585 (lot D) — renomme les captures prises PAR L'HÔTE (boucle `adb exec-out
screencap` ou `xcrun simctl io screenshot`, une par seconde, nommées HHMMSS.png)
d'après les lignes `[CAPTURE] <iso> <nom>` (ou `[PARCOURS] <iso> <nom>`) du
journal de `flutter test`.

Usage : python3 tool/renommer_captures.py <journal.log> <dossier_captures> <dossier_sortie> [cible=1.0] [tolerance=2.0]
Le nom du fichier porte l'heure du DÉBUT de la capture, qui dure ~2 s sur
l'émulateur (le contenu est celui de la fin) ; la ligne du journal est écrite
APRÈS que l'écran est posé (il l'était déjà ~1 s avant) et l'écran reste ~3 s.
On prend donc la capture dont l'heure de début est la plus proche de `cible` s
par rapport à la ligne (défaut −1 s, donc contenu ≈ +1 s), dans ± `tolerance`.
"""
import glob, os, re, shutil, sys

def main():
    log, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]
    target = float(sys.argv[4]) if len(sys.argv) > 4 else -1.0
    tol = float(sys.argv[5]) if len(sys.argv) > 5 else 1.5
    os.makedirs(dst, exist_ok=True)
    rx = re.compile(r'\[(?:CAPTURE|PARCOURS)\] \d{4}-\d\d-\d\dT(\d\d):(\d\d):(\d\d)(?:\.\d+)? (\S+)(.*)')
    steps = []
    for line in open(log, encoding='utf-8', errors='ignore'):
        m = rx.search(line)
        if m:
            t = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3))
            steps.append((t, m.group(4), m.group(5).strip()))
    shots = sorted(glob.glob(os.path.join(src, '*.png')))
    def tsec(p):
        b = os.path.basename(p)[:6]
        return int(b[:2]) * 3600 + int(b[2:4]) * 60 + int(b[4:6])
    used = set(); n = 0; missing = []
    for t, name, rest in steps:
        cands = [p for p in shots if abs(tsec(p) - t - target) <= tol and p not in used]
        if not cands:
            missing.append(name); continue
        p = min(cands, key=lambda q: abs(tsec(q) - t - target)); used.add(p)
        slug = re.sub(r'[^a-z0-9]+', '-', rest.lower().replace('é', 'e').replace('è', 'e').replace('à', 'a')).strip('-')
        out = f"{name}_{slug}.png" if slug else f"{name}.png"
        shutil.copy(p, os.path.join(dst, out)); n += 1
    print(f'{n} captures renommées dans {dst}' + (f' ; sans capture : {missing}' if missing else ''))
    return 0 if not missing else 1

if __name__ == '__main__':
    sys.exit(main())
