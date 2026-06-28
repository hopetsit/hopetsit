# 🔄 REPRENDRE HoPetSit SUR LE MACBOOK — guide express

> Ce fichier explique comment reprendre le travail sur le Mac, et quel
> « prompt » donner à Claude Code. État au moment du zip : **Android v23.1.499**
> (soumis Google Play), **iOS build 502** (soumis App Store).

---

## 1) Récupérer le dernier code (IMPORTANT)

Sur le Mac, dans le dossier du projet :

```bash
cd ~/chemin/vers/hopetsit       # ton dossier du repo
git status                       # vérifie s'il y a des modifs LOCALES non commitées (fixes Apple)
git stash                        # SI des modifs locales Apple non commitées → les mettre de côté
git pull origin main             # récupère tout le travail récent (Windows) : renommage package, couronne, admin
git stash pop                    # SI tu avais stashé → réapplique tes fixes Apple
```

⚠️ **NE PAS** dézipper le zip par-dessus le Mac : ça écraserait les correctifs **Apple Sign-In**
qui sont **locaux sur le Mac** (patch `HoPetSit_modifs_locales_20260625.patch`). Le zip n'est
qu'une **sauvegarde**. Pour synchroniser le Mac, c'est **`git pull`**.

Si les correctifs Apple ne sont plus là après le pull :
```bash
git apply HoPetSit_modifs_locales_20260625.patch
```

---

## 2) Le « prompt » pour Claude Code (à coller dans le terminal Claude sur le Mac)

> Tu reprends le projet **HoPetSit** (marketplace garde/promenade d'animaux).
> Lis d'abord **`CLAUDE.md`** (contexte + état actuel) et **`docs/claude-memory/MEMORY.md`**
> (historique, gotchas, décisions). Le propriétaire est **Daniel** (français, non-technique,
> itération rapide). Déploiement : `git push origin main` (Render backend + Vercel site/admin) ;
> iOS = build manuel sur Mac. Respecte les règles permanentes du CLAUDE.md (trio de version,
> copier l'APK dans Downloads à chaque build, règle d'or GetX, etc.).

Tout le contexte détaillé est dans **`CLAUDE.md`** et **`docs/claude-memory/`** (inclus dans ce zip).

---

## 3) Builds

- **iOS** (sur Mac) : voir le PDF `HoPetSit_iOS_Build_Guide_v23.1.499.pdf` (dans Downloads).
  Bundle iOS = `com.hopetsit.app` · Apple Team `49C67YDPJ5` · App Store ID `6763645719`.
- **Android** : `cd frontend && flutter build appbundle --release` (+ `apk`).
  Package = `com.cardellihermanos.hopetsit` (renommé v498, exigence Google Play).

## 4) Identifiants / consoles
- Repo : `github.com/hopetsit/hopetsit` (origin)
- Backend Render : `hopetsit-backend.onrender.com` (plan payant, toujours allumé)
- Firebase : projet `hopetsit` (470089536255)
- ⚠️ **Compte démo store** = email + mot de passe (JAMAIS Google/Apple à 2FA) sinon refus.

---

*Généré pour le transfert Mac — CARDELLI HERMANOS LIMITED.*
