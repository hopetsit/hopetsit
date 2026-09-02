"""
v546 — Génère la langue POLONAISE pour l'app (frontend/lib/localization/
translations/pl.dart) et pour le site (bloc `pl` de website/src/lib/i18n/
translations.ts) à partir de l'anglais, via Google Translate (deep_translator).

Méthode (héritée de translate_pt.py) :
  1. Parse en.dart → {clé: texte anglais} ; parse le bloc `en` du site.
  2. Protège les variables (@name, {count}, \\n, \\$) par des jetons.
  3. Traduit par LOTS de lignes (une requête = ~40 textes séparés par des
     sauts de ligne) ; si le nombre de lignes ne correspond pas, retombe sur
     la traduction texte par texte.
  4. Restaure les variables ; si une variable a été perdue, garde l'anglais
     (jamais de variable cassée en prod).
  5. Cache JSON résumable (pl_cache.json) : relancer reprend où ça s'est arrêté.

Run : <venv>/bin/python translate_pl.py [--app] [--web]
"""

import json
import re
import sys
import time
from pathlib import Path

from deep_translator import GoogleTranslator

ROOT = Path(__file__).resolve().parent
APP_DIR = ROOT / "frontend" / "lib" / "localization" / "translations"
EN_FILE = APP_DIR / "en.dart"
PL_FILE = APP_DIR / "pl.dart"
WEB_FILE = ROOT / "website" / "src" / "lib" / "i18n" / "translations.ts"
CACHE = ROOT / "pl_cache.json"

DART_KV = re.compile(r"""['"]([a-zA-Z0-9_]+)['"]\s*:\s*'((?:[^'\\]|\\.)*)'\s*,""")
TS_KV = re.compile(r"""^\s+([a-zA-Z0-9_]+):\s*"((?:[^"\\]|\\.)*)",?\s*$""", re.M)

PLACEHOLDER_PATTERNS = [
    re.compile(r"@[a-zA-Z_][a-zA-Z0-9_]*"),
    re.compile(r"\{[a-zA-Z0-9_]*\}"),
    re.compile(r"\\[ntr]"),
    re.compile(r"\\\$"),
    re.compile(r"%[sd]"),
]

BATCH = 40
SLEEP = 0.6


def protect(text):
    ph = {}
    n = [0]

    def rep(m):
        tok = f"XPLH{n[0]}X"
        ph[tok] = m.group(0)
        n[0] += 1
        return tok

    out = text
    for pat in PLACEHOLDER_PATTERNS:
        out = pat.sub(rep, out)
    return out, ph


def restore(text, ph):
    out = text
    for tok, orig in ph.items():
        # Google peut mettre des espaces/majuscules autour du jeton
        out = re.sub(re.escape(tok), lambda _m: orig, out, flags=re.I)
    return out


def load_cache():
    if CACHE.exists():
        return json.loads(CACHE.read_text(encoding="utf-8"))
    return {}


def save_cache(c):
    CACHE.write_text(json.dumps(c, ensure_ascii=False, indent=0), encoding="utf-8")


def translate_all(items, cache, label):
    """items: dict key -> english. Remplit cache[key] = polonais."""
    g = GoogleTranslator(source="en", target="pl")
    todo = [(k, v) for k, v in items.items() if k not in cache]
    print(f"[{label}] {len(items)} textes, {len(todo)} à traduire")
    done = 0
    for i in range(0, len(todo), BATCH):
        chunk = todo[i:i + BATCH]
        prot = [protect(v) for _, v in chunk]
        # Les textes multi-lignes (\\n littéral déjà protégé) ne contiennent
        # pas de vrai saut de ligne ; on sépare par un vrai \n.
        joined = "\n".join(p[0] for p in prot)
        try:
            res = g.translate(joined)
            lines = res.split("\n") if res else []
        except Exception as e:  # noqa: BLE001
            print("  lot en échec, texte par texte :", e)
            lines = []
        if len(lines) != len(chunk):
            lines = []
            for p in prot:
                try:
                    lines.append(g.translate(p[0]) or "")
                except Exception:  # noqa: BLE001
                    lines.append("")
                time.sleep(SLEEP)
        for (k, en), (protd, ph), pl in zip(chunk, prot, lines):
            pl = (pl or "").strip()
            if not pl:
                cache[k] = en
                continue
            out = restore(pl, ph)
            # Garde-fou : chaque variable doit être revenue intacte.
            ok = all(orig in out for orig in ph.values())
            cache[k] = out if ok else en
        done += len(chunk)
        save_cache(cache)
        print(f"  {label}: {done}/{len(todo)}")
        time.sleep(SLEEP)


def dart_escape(s):
    return s.replace("\\", "\\\\").replace("'", "\\'").replace("\\\\n", "\\n").replace("\\\\$", "\\$")


def build_app(cache):
    src = EN_FILE.read_text(encoding="utf-8")
    items = {}
    for m in DART_KV.finditer(src):
        # valeur telle qu'écrite (échappements Dart conservés)
        items[m.group(1)] = m.group(2)
    translate_all(items, cache, "app")
    lines = [
        "/// Polish (pl_PL) translations for HoPetSit.",
        "///",
        "/// v546 — générées automatiquement depuis en.dart (translate_pl.py),",
        "/// variables protégées ; textes clés relus à la main.",
        "const Map<String, String> plPLTranslations = <String, String>{",
    ]
    for k, en in items.items():
        pl = cache.get(k, en)
        lines.append(f"  '{k}': '{dart_escape(pl)}',")
    lines.append("};")
    PL_FILE.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("écrit", PL_FILE, len(items), "clés")


def build_web(cache):
    src = WEB_FILE.read_text(encoding="utf-8")
    start = src.index("\n  en: {\n") + 1
    end = src.index("\n  fr: {\n") + 1
    en_block = src[start:end]
    items = {}
    for m in TS_KV.finditer(en_block):
        items["web__" + m.group(1)] = m.group(2)
    translate_all(items, cache, "web")
    out = ["  pl: {"]
    for m in TS_KV.finditer(en_block):
        k = m.group(1)
        pl = cache.get("web__" + k, m.group(2))
        pl = pl.replace('"', '\\"') if '\\"' not in pl else pl
        out.append(f'    {k}: "{pl}",')
    out.append("  },")
    block = "\n".join(out) + "\n"
    if "\n  pl: {\n" in src:
        s2 = src.index("\n  pl: {\n") + 1
        e2 = src.index("\n};", s2) + 1
        src = src[:s2] + block + src[e2:]
    else:
        # insère avant la fermeture finale "};"
        idx = src.rindex("\n};")
        src = src[:idx + 1] + block + src[idx + 1:]
    WEB_FILE.write_text(src, encoding="utf-8")
    print("bloc pl écrit dans", WEB_FILE, len(items), "clés")


if __name__ == "__main__":
    args = sys.argv[1:] or ["--app", "--web"]
    cache = load_cache()
    if "--app" in args:
        build_app(cache)
    if "--web" in args:
        build_web(cache)
    print("terminé")
