#!/usr/bin/env python3
"""Garde-fou « aucun bouton mort » (PawMap 585, lot 2 — bug 12).

Clique CHAQUE bouton / lien / interrupteur / épingle visible des pages
connectées du site et note ce qui se passe : navigation, nouvel onglet,
appel réseau à l'API, changement d'état à l'écran… ou RIEN.

Mode d'emploi (rien de réel n'est touché : faux serveur local) :
  1. node scripts/mock-api.js                         # faux serveur d'API :8790
  2. NEXT_PUBLIC_API_BASE=http://localhost:8790/api/v1 npx next build && npx next start -p 3112
  3. python3 scripts/check_buttons.py --base http://localhost:3112 --out /tmp/boutons
     (option --width 375 pour le téléphone ; --pages /map /chat … pour cibler)
Sortie : <out>/boutons.json + <out>/boutons.md (tableau page × bouton × résultat).
Code de sortie 1 s'il reste au moins un bouton « RIEN ».

La session est un FAUX jeton posé dans le navigateur local (aucun mot de
passe). En-tête et pied de page sont testés une seule fois (sur /dashboard).
"""
import argparse, hashlib, json, os, sys
from concurrent.futures import ThreadPoolExecutor
from playwright.sync_api import sync_playwright

USER = {"id": "o-cam", "name": "Camille Durand", "email": "mock@example.invalid", "role": "owner"}
PAGES = ["/map", "/pawmap", "/dashboard", "/boutique", "/p/sitter/s-lea", "/bookings", "/chat"]
# Pages vues sans session (la carte publique redirige vers /map si connecté).
ANON = {"/pawmap"}

COLLECT = r"""(opts) => {
  const vis = (e) => { const r = e.getBoundingClientRect(); const cs = getComputedStyle(e);
    return r.width >= 8 && r.height >= 8 && cs.visibility !== 'hidden' && cs.display !== 'none' && Number(cs.opacity) > 0.05; };
  const sel = 'button, a[href], [role=button], [role=switch], [role=combobox], [role=option], .leaflet-marker-icon';
  const out = [];
  for (const e of document.querySelectorAll(sel)) {
    if (!vis(e)) continue;
    if (e.closest('.leaflet-control-attribution')) continue;
    if (!opts.chrome && e.closest('header.sticky, footer')) continue;
    if (opts.chrome && !e.closest('header.sticky, footer')) continue;
    if (e.parentElement && e.parentElement.closest(sel) && !e.matches('.leaflet-marker-icon')) continue;
    const label = (e.getAttribute('aria-label') || e.getAttribute('title') || e.innerText || e.querySelector('img')?.getAttribute('alt') || '').replace(/\s+/g, ' ').trim().slice(0, 60)
      || (e.matches('.leaflet-marker-icon') ? 'épingle ' + ((e.querySelector('img')?.src || '').split('/').pop() || e.innerText || '?').slice(0, 24) : '?');
    out.push({ tag: e.tagName.toLowerCase(), label, href: e.getAttribute('href') || '',
      disabled: !!(e.disabled || e.getAttribute('aria-disabled') === 'true'),
      active: e.getAttribute('aria-pressed') === 'true' || e.getAttribute('aria-selected') === 'true' || e.getAttribute('aria-current') === 'page' });
  }
  return out;
}"""
CLICK = r"""([i, opts]) => {
  const vis = (e) => { const r = e.getBoundingClientRect(); const cs = getComputedStyle(e);
    return r.width >= 8 && r.height >= 8 && cs.visibility !== 'hidden' && cs.display !== 'none' && Number(cs.opacity) > 0.05; };
  const sel = 'button, a[href], [role=button], [role=switch], [role=combobox], [role=option], .leaflet-marker-icon';
  const list = [];
  for (const e of document.querySelectorAll(sel)) {
    if (!vis(e)) continue;
    if (e.closest('.leaflet-control-attribution')) continue;
    if (!opts.chrome && e.closest('header.sticky, footer')) continue;
    if (opts.chrome && !e.closest('header.sticky, footer')) continue;
    if (e.parentElement && e.parentElement.closest(sel) && !e.matches('.leaflet-marker-icon')) continue;
    list.push(e);
  }
  const e = list[i];
  if (!e) return false;
  e.scrollIntoView({ block: 'center' });
  if (e.matches('.leaflet-marker-icon')) e.dispatchEvent(new MouseEvent('click', { bubbles: true }));
  else e.click();
  return true;
}"""
STATE = "() => document.body.innerText.length + '|' + document.body.innerHTML.length + '|' + [...document.querySelectorAll('[aria-expanded],[aria-pressed],[aria-checked],[aria-selected]')].map(e => (e.getAttribute('aria-expanded')||'')+(e.getAttribute('aria-pressed')||'')+(e.getAttribute('aria-checked')||'')+(e.getAttribute('aria-selected')||'')).join('')"


def new_ctx(b, width, anon):
    mobile = width < 500
    ctx = b.new_context(viewport={"width": width, "height": 812 if width < 1000 else 900}, is_mobile=mobile, has_touch=mobile,
                        geolocation={"latitude": 48.8566, "longitude": 2.3522}, permissions=["geolocation"], locale="fr-FR")
    if not anon:
        ctx.add_init_script("localStorage.setItem('hopetsit_token','mock-local');localStorage.setItem('hopetsit_role','owner');"
                            "localStorage.setItem('hopetsit_user'," + json.dumps(json.dumps(USER)) + ");localStorage.setItem('hopetsit_lang','fr');")
    else:
        ctx.add_init_script("localStorage.setItem('hopetsit_lang','fr');")
    # Rien ne sort vers un vrai service (hors tuiles de carte et polices).
    def route(r):
        u = r.request.url
        if u.startswith("http://localhost") or "tile.openstreetmap.org" in u or "arcgisonline" in u or "fonts.g" in u or u.startswith("data:"):
            return r.continue_()
        return r.abort()
    ctx.route("**/*", route)
    return ctx


def check_page(base, path, width, chrome=False):
    rows = []
    anon = path in ANON
    with sync_playwright() as p:
        b = p.chromium.launch()
        ctx = new_ctx(b, width, anon)
        pg = ctx.new_page()
        pg.goto(base + path); pg.wait_for_timeout(4000)
        items = pg.evaluate(COLLECT, {"chrome": chrome})
        seen_href = set()
        for i, it in enumerate(items):
            if it["href"] and it["href"] in seen_href and it["tag"] == "a":
                continue
            if it["href"]:
                seen_href.add(it["href"])
            if it["href"].startswith("http") and "localhost" not in it["href"]:
                rows.append({**it, "page": path, "result": "lien externe (non suivi)"}); continue
            pg.close(); pg = ctx.new_page()
            dialogs = []
            # Boîte de confirmation (ex. changer de rôle) : notée puis REFUSÉE,
            # pour ne rien modifier.
            pg.on("dialog", lambda d: (dialogs.append(d.message), d.dismiss()))
            api = []
            pg.on("request", lambda r: api.append(r.url) if ":8790/" in r.url and "/av/" not in r.url else None)
            pg.goto(base + path); pg.wait_for_timeout(3500)
            # Page « vivante » (horloge, rafraîchissements) ? On mesure le bruit
            # 1,3 s SANS cliquer : un changement qui arrive tout seul ne prouve rien.
            a0 = pg.evaluate(STATE); na = len(api); pg.wait_for_timeout(1300)
            noisy = pg.evaluate(STATE) != a0 or len(api) > na
            url0 = pg.url; st0 = pg.evaluate(STATE); n0 = len(api)
            pages0 = len(ctx.pages)
            try:
                ok = pg.evaluate(CLICK, [i, {"chrome": chrome}])
            except Exception as e:  # la page est partie pendant le clic
                ok = True
            pg.wait_for_timeout(1300)
            res = []
            try:
                if pg.url != url0: res.append("navigation → " + pg.url.replace(base, ""))
            except Exception:
                res.append("navigation")
            if len(ctx.pages) > pages0: res.append("nouvel onglet")
            if len(api) > n0: res.append("appel réseau (" + ", ".join(sorted({u.split(':8790/api/v1')[-1].split('?')[0] for u in api[n0:]}))[:80] + ")")
            try:
                if not res and pg.evaluate(STATE) != st0: res.append("changement à l'écran")
            except Exception:
                pass
            if dialogs: res.append("boîte de confirmation (« " + dialogs[0][:50] + " », refusée par le test)")
            if not res and it.get("disabled"): res.append("désactivé (normal : rien à envoyer)")
            if not res and it.get("active"): res.append("déjà choisi (normal)")
            if not res and it["href"] and it["href"].split("?")[0] == path: res.append("lien vers la page déjà ouverte")
            if noisy and res and all(x.startswith("appel") or x.startswith("changement") for x in res):
                res.append("à confirmer : la page bouge aussi toute seule")
            if not ok: res = ["introuvable au rechargement"]
            rows.append({**it, "page": path, "result": " ; ".join(res) or "RIEN"})
            for extra in ctx.pages[1:]:
                extra.close()
        b.close()
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://localhost:3112")
    ap.add_argument("--out", default="/tmp/boutons")
    ap.add_argument("--width", type=int, default=1280)
    ap.add_argument("--pages", nargs="*", default=PAGES)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    jobs = [(pth, False) for pth in a.pages] + ([("/dashboard", True)] if "/dashboard" in a.pages else [])
    with ThreadPoolExecutor(max_workers=4) as ex:
        results = list(ex.map(lambda j: check_page(a.base, j[0], a.width, j[1]), jobs))
    rows = [r for rs in results for r in rs]
    for r, (pth, chrome) in [(r, j) for rs, j in zip(results, jobs) for r in rs]:
        if chrome: r["page"] = "en-tête / pied (sur " + pth + ")"
    json.dump(rows, open(os.path.join(a.out, "boutons.json"), "w"), ensure_ascii=False, indent=1)
    with open(os.path.join(a.out, "boutons.md"), "w") as f:
        f.write(f"| Page | Bouton | Résultat |\n|---|---|---|\n")
        for r in rows:
            f.write(f"| {r['page']} | {r['label'].replace('|', '/')} | {r['result']} |\n")
    dead = [r for r in rows if r["result"] == "RIEN"]
    print(f"{len(rows)} éléments cliqués, {len(dead)} sans effet (largeur {a.width})")
    for r in dead:
        print("  RIEN :", r["page"], "·", r["label"])
    sys.exit(1 if dead else 0)


if __name__ == "__main__":
    main()
