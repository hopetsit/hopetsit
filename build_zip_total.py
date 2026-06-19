"""
HopeTSIT — Bundle le projet complet dans un ZIP pour transfert vers Mac.

Sortie : ~/Downloads/HopeTSIT_FINAL_v23.1.497.zip

Exclut les artefacts non versionnés (recalculables avec `npm install` /
`flutter pub get` / `pod install` côté Mac) pour rester sous une taille
raisonnable (~200-400 MB au lieu de 2.6 GB).
"""

import os
import sys
import zipfile
from datetime import datetime
from pathlib import Path

# ─── Config ────────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent
OUTPUT = (
    Path.home() / "Downloads" / "HopeTSIT_FINAL_v23.1.497.zip"
)

# Dossiers à exclure (basés sur leur nom — n'importe où dans l'arbre).
EXCLUDE_DIRS = {
    "node_modules",
    "build",                # flutter build/ (1.2 GB)
    ".dart_tool",           # flutter cache (107 MB)
    ".next",                # next.js build
    ".vercel",              # vercel cache
    "__pycache__",
    ".DS_Store",
    "Pods",                 # ios/Pods/ (recalculé par pod install)
    "DerivedData",          # Xcode cache
    "Carthage",
    ".idea",
    ".vscode",
    "android-build-output", # vu chez certains projets
    "ephemeral",            # ios/Flutter/ephemeral
}

# Fichiers / extensions à exclure.
EXCLUDE_FILES = {
    ".DS_Store",
    "Thumbs.db",
    ".env.local",           # contient des secrets locaux
    ".flutter-plugins-dependencies",
    ".flutter-plugins",
    ".packages",
}

# Extensions à exclure.
EXCLUDE_EXTS = {
    ".pyc",
    ".log",
    ".lock",                # package-lock pas exclu (utile)
}

# Patterns racine à exclure (vieux backups + binaires lourds).
EXCLUDE_ROOT_PATTERNS = [
    "HopeTSIT_Backup_v",    # vieux backups dans le root
    "HopeTSIT_v",           # vieux deltas
    "HopeTSIT_FINAL_v",     # ancien zip total
    "HopeTSIT_iOS_Build",   # le PDF qu'on vient de générer (pas besoin)
]

# Le APK qu'on garde DANS website/public/ (utile pour le site).
# Mais on exclut les autres .apk plus volumineux ailleurs.

# Taille max d'un fichier inclus (50 MB). Au-delà on skippe + on log.
MAX_FILE_SIZE = 50 * 1024 * 1024


def should_skip(path: Path) -> bool:
    """Décide si on skippe ce fichier ou dossier."""
    rel = path.relative_to(PROJECT_ROOT)
    parts = set(rel.parts)
    # Exclu si l'un des parents est dans EXCLUDE_DIRS.
    if parts & EXCLUDE_DIRS:
        return True
    # Fichier racine matchant les patterns.
    if len(rel.parts) == 1:
        name = rel.parts[0]
        for prefix in EXCLUDE_ROOT_PATTERNS:
            if name.startswith(prefix) and name.endswith(".zip"):
                return True
            if name.startswith(prefix) and name.endswith(".pdf"):
                return True
    return False


def should_skip_file(path: Path) -> bool:
    """Spécifique fichier (extension, nom)."""
    if path.name in EXCLUDE_FILES:
        return True
    if path.suffix.lower() in EXCLUDE_EXTS:
        return True
    return False


def main():
    print(f"== ZIP HopeTSIT — {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"   Source : {PROJECT_ROOT}")
    print(f"   Sortie : {OUTPUT}")
    print()

    # Compte les fichiers d'abord pour afficher la progression.
    total_files = 0
    total_size = 0
    skipped_size = 0
    big_files = []
    files_to_zip = []

    for root, dirs, files in os.walk(PROJECT_ROOT):
        root_path = Path(root)
        if should_skip(root_path):
            dirs[:] = []
            continue
        # Filtre les sous-dossiers en place pour ne pas y descendre.
        dirs[:] = [
            d for d in dirs
            if not should_skip(root_path / d)
        ]
        for fname in files:
            fpath = root_path / fname
            try:
                size = fpath.stat().st_size
            except OSError:
                continue
            if should_skip_file(fpath):
                skipped_size += size
                continue
            if size > MAX_FILE_SIZE:
                big_files.append((fpath, size))
                skipped_size += size
                continue
            total_files += 1
            total_size += size
            files_to_zip.append((fpath, size))

    print(f"== Inventaire :")
    print(f"   Fichiers à inclure : {total_files:,}")
    print(f"   Taille pré-zip      : {total_size / 1024 / 1024:.1f} MB")
    print(f"   Taille skippée      : {skipped_size / 1024 / 1024:.1f} MB")
    if big_files:
        print(f"   Fichiers > 50 MB exclus :")
        for fp, sz in big_files:
            print(f"     - {fp.relative_to(PROJECT_ROOT)}  ({sz/1024/1024:.1f} MB)")
    print()

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    print("== Création du ZIP (compression deflate)...")
    written = 0
    with zipfile.ZipFile(
        OUTPUT, "w", zipfile.ZIP_DEFLATED, compresslevel=6
    ) as zf:
        for i, (fpath, size) in enumerate(files_to_zip, 1):
            rel = fpath.relative_to(PROJECT_ROOT)
            arcname = "HopeTSIT_FINAL/" + str(rel).replace("\\", "/")
            try:
                zf.write(fpath, arcname)
                written += 1
            except OSError as e:
                print(f"   [skip] {rel}: {e}")
                continue
            # Progress chaque 500 fichiers.
            if i % 500 == 0 or i == total_files:
                print(
                    f"   [{i:5}/{total_files}] "
                    f"{written/total_files*100:.0f}%  "
                    f"{rel}"
                )

    final_size = OUTPUT.stat().st_size
    print()
    print(f"== Done.")
    print(f"   ZIP final : {OUTPUT}")
    print(f"   Taille    : {final_size / 1024 / 1024:.1f} MB")
    print(f"   Ratio     : {final_size / total_size * 100:.0f}% de l'original")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrompu.")
        sys.exit(1)
