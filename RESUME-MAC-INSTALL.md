# HoPetSit — Installation complète sur Mac (guide pour Claude)

> **Tu es Claude sur le Mac de Daniel.** Ce fichier est TON mode d'emploi.
> Daniel est non-technique : fais tout toi-même, explique simplement, et ne
> lui demande que ce que lui seul peut faire (mots de passe, App Store…).
> Le contexte projet complet est dans `CLAUDE.md` (lis-le après ce fichier),
> l'historique détaillé dans `docs/claude-memory/MEMORY.md`.

## ⚠️ RÈGLE N°1 — NE JAMAIS ÉCRASER UN DOSSIER EXISTANT

Si un dossier HoPetSit existe DÉJÀ sur ce Mac (souvent `~/HoPetSit` ou
similaire, avec les projets `frontend/`, `backend/`, `website/`) :

- **NE PAS remplacer ce dossier par le contenu du zip.** Il contient des
  correctifs iOS locaux (Apple Sign-In, bundle id, IAP build 503) qui ne sont
  peut-être pas tous sur GitHub.
- À la place : `git pull origin main` dans ce dossier pour récupérer le
  dernier code, puis va directement à l'étape 4 (secrets) pour vérifier
  qu'il ne manque rien, et à l'étape 5 (dépendances).
- Le zip ne sert alors que de sauvegarde / source de secrets.

**Le zip complet ne sert à une installation fraîche que si ce Mac n'a encore
rien** (nouveau Mac, disque réinitialisé…).

## 1. Prérequis à vérifier (installe ce qui manque)

```bash
git --version        # sinon : xcode-select --install
node --version       # ≥ 18 ; sinon : brew install node
flutter --version    # sinon : https://docs.flutter.dev/get-started/install/macos
pod --version        # sinon : sudo gem install cocoapods
```
Xcode complet (App Store) est requis pour builder iOS.

## 2. Extraire le dossier (installation fraîche uniquement)

```bash
cd ~
unzip ~/Downloads/HoPetSit_Mac_complet_*.zip -d ~/
mv ~/HopeTSIT_FINAL ~/HoPetSit   # nom plus court
cd ~/HoPetSit
git status                        # le .git est inclus → l'historique est là
git remote -v                     # origin = https://github.com/hopetsit/hopetsit.git
git pull origin main              # récupère ce qui a été poussé depuis le zip
```

## 3. Ce que contient le zip (en plus du code)

- `.git/` — historique complet, remote `origin` déjà configuré.
- `backend/.env` — secrets backend (Mongo, Airwallex, Didit, Persona, FCM…).
  ⚠️ Ne jamais committer, ne jamais partager.
- `frontend/android/key.properties` + `_secrets-mac/hopetsit-release.jks` —
  clé de signature Android (Play Store).
- `admin_dashboard.html`, `docs/claude-memory/` — admin + mémoire projet.

## 4. Mettre les secrets en place

```bash
# Keystore Android → home du Mac
cp _secrets-mac/hopetsit-release.jks ~/hopetsit-release.jks
```
Puis ÉDITE `frontend/android/key.properties` : remplace la ligne
`storeFile=C:/Users/Usuario/hopetsit-release.jks` (chemin Windows) par
`storeFile=/Users/<NOM_UTILISATEUR_MAC>/hopetsit-release.jks`.
⚠️ Ce changement est LOCAL au Mac — ne le committe pas.
Enfin supprime le dossier `_secrets-mac/` après la copie.

`backend/.env` est déjà au bon endroit dans le zip — rien à faire.

⚠️ **ATTENTION `.env` (découvert le 12/07/2026)** : le `MONGODB_URI` de ce
fichier pointe sur une **VIEILLE base** (cluster « Petinsta », données
d'avril). La production tourne sur Render avec SES PROPRES variables
d'environnement (non incluses ici) → la prod n'est PAS affectée. Mais si tu
lances le backend EN LOCAL avec ce `.env`, il parlera à la mauvaise base :
ne t'en sers pas pour du vrai travail de données sans avoir demandé à
Daniel l'URI de prod (visible dans Render → Environment).

## 5. Installer les dépendances

```bash
cd ~/HoPetSit/backend  && npm install
cd ~/HoPetSit/website  && npm install
cd ~/HoPetSit/frontend && flutter pub get
cd ~/HoPetSit/frontend/ios && pod install   # iOS uniquement
```

## 6. Vérifier que tout marche

```bash
cd ~/HoPetSit
node -c backend/src/app.js                   # syntaxe backend OK
cd website && npx tsc --noEmit && cd ..      # types site OK
cd frontend && flutter analyze lib && cd ..  # app OK
flutter doctor                               # environnement Flutter OK
```

## 7. GitHub (déploiements)

- Les déploiements backend/site/admin = `git push origin main`
  (auto-deploy Render + Vercel). AUCUN accès serveur nécessaire.
- Au premier push, le Mac demandera un identifiant GitHub : compte
  **hopetsit** + le **jeton d'accès** (`github_pat_…`) que Daniel possède
  (régénéré le 07/07/2026). Demande-le à Daniel à ce moment-là — c'est lui
  qui le colle, pas toi.

## 8. Spécificités iOS (ce Mac est LA machine iOS)

- Bundle iOS : `com.cardellihermanos.hopetsit` (renommé pour l'IAP Apple).
- **✅ App iOS ACCEPTÉE par Apple (08/07/2026)** — build **506** en ligne :
  https://apps.apple.com/app/hopetsit/id6763645719
- **Le code iOS v506 (IAP + Apple Sign-In) est SYNCHRONISÉ sur origin**
  depuis le 12/07 (patch appliqué du Mac au PC) → un simple `git pull`
  suffit désormais, plus de correctifs « locaux au Mac » en attente.
- Guide de build : `HoPetSit_iOS_Build_Guide_v23.1.523.pdf` (fourni avec ce
  kit) + `RESUME-MAC.md` à la racine.
- **Prochaine version iOS = 23.1.523** (déjà dans pubspec après `git pull`) :
  elle embarque les fixes PawMap (points invisibles + recherche ville carte
  agrandie), photo de profil multi-appareils, icône tarifs universelle,
  anglais US et libellés Didit. Android v523 est déjà buildée côté PC.
- Android peut aussi se builder ici : `cd frontend && flutter build apk
  --release` (grâce au keystore de l'étape 4). Règle Daniel : copier chaque
  APK dans `~/Downloads/HoPetSit_v23.1.<ver>.apk`.

## 9. Règles permanentes (résumé — détail dans CLAUDE.md)

1. Trio de version à chaque build APK (pubspec + ADMIN_BUILD + EMBEDDED).
2. `flutter analyze lib` / `npx tsc --noEmit` / `node -c` avant tout commit.
3. Jamais de rebuild app pour du travail backend/site/admin.
4. Jamais afficher un `error.message` backend brut côté utilisateur.
5. Ne jamais committer : `.env`, `key.properties`, `*.jks`.
