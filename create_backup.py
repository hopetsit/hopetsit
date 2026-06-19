"""
HopeTSIT v23.1.166 - Backup complet du projet pour Daniel.

Genere un ZIP du repo entier en excluant les artefacts de build / cache /
node_modules. Cible : ~/Downloads/HopeTSIT_FULL_BACKUP_v23.1.166.zip

Exclusions :
  - frontend/build (1.2 GB)
  - frontend/.dart_tool (108 MB)
  - frontend/android/.gradle (105 MB)
  - frontend/ios/Pods (si existe)
  - backend/node_modules (312 MB)
  - website/node_modules (478 MB)
  - website/.next (46 MB)
  - **/.DS_Store
  - **/__pycache__

On GARDE :
  - .git (192 MB) - pour preserver l'historique complet
  - Tout le code source des 3 sous-projets
  - Tous les scripts Python d'injection + build PDF
  - Tous les .md et docs
  - Le fichier .env est exclu (sensible)
"""

import os
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).parent
OUTPUT = Path(os.path.expanduser("~")) / "Downloads" / "HopeTSIT_FULL_BACKUP_v23.1.497.zip"

EXCLUDED_DIR_NAMES = {
    "build",        # frontend Flutter build
    ".dart_tool",   # Flutter cache
    ".gradle",      # Android Gradle cache
    "Pods",         # iOS CocoaPods (might exist on Mac sync)
    "node_modules", # backend + website
    ".next",        # Next.js build
    "__pycache__",  # Python cache
    ".DS_Store",
    ".vscode",
    ".idea",
}

EXCLUDED_FILE_PATTERNS = {
    ".env",
    ".env.local",
    ".env.production",
    ".DS_Store",
    "Thumbs.db",
}


def should_skip(path):
    """Return True if the path component should be excluded from backup."""
    name = path.name
    if name in EXCLUDED_DIR_NAMES:
        return True
    if name in EXCLUDED_FILE_PATTERNS:
        return True
    # Exclude .env.* variants but allow .env.example
    if name.startswith(".env") and not name.endswith(".example"):
        return True
    return False


def main():
    print(f"== Creating backup ZIP ==")
    print(f"   Source : {ROOT}")
    print(f"   Output : {OUTPUT}")
    print()

    total_files = 0
    total_bytes = 0
    skipped_count = 0

    with zipfile.ZipFile(OUTPUT, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for dirpath, dirnames, filenames in os.walk(ROOT):
            # Prune excluded directories in-place so os.walk doesn't recurse into them
            dirnames[:] = [d for d in dirnames if not should_skip(Path(dirpath) / d)]

            for filename in filenames:
                file_path = Path(dirpath) / filename
                if should_skip(file_path):
                    skipped_count += 1
                    continue

                # Skip the backup zip itself if it ends up in the source tree
                if file_path.resolve() == OUTPUT.resolve():
                    continue

                try:
                    rel_path = file_path.relative_to(ROOT)
                    zf.write(file_path, arcname=rel_path)
                    total_files += 1
                    total_bytes += file_path.stat().st_size
                except (PermissionError, OSError) as e:
                    print(f"   [SKIP] {file_path}: {e}")
                    skipped_count += 1
                    continue

                if total_files % 500 == 0:
                    print(f"   ... {total_files} files / {total_bytes // (1024*1024)} MB")

    final_size_mb = OUTPUT.stat().st_size // (1024 * 1024)
    raw_size_mb = total_bytes // (1024 * 1024)
    print()
    print(f"== DONE ==")
    print(f"   Files included : {total_files}")
    print(f"   Files skipped  : {skipped_count}")
    print(f"   Raw size       : {raw_size_mb} MB")
    print(f"   Compressed ZIP : {final_size_mb} MB")
    print(f"   Output file    : {OUTPUT}")


if __name__ == "__main__":
    main()
