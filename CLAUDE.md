# HoPetSit — Contexte projet pour Claude Code

> Ce fichier est chargé automatiquement par Claude Code. Il sert de « prompt »
> de reprise quand on travaille sur ce projet (y compris sur le Mac).
> L'historique détaillé (gotchas, décisions, versions) est dans
> **`docs/claude-memory/`** (copie de la mémoire) — lis `docs/claude-memory/MEMORY.md`.

## Le produit
**HoPetSit** = marketplace de garde + promenade d'animaux. Met en relation des
**propriétaires** (orange) avec des **promeneurs** (vert) et **gardiens/pet-sitters** (bleu).
En plus : **PawMap** (carte communautaire), **PawSpot** (lieux pet-friendly),
**PawFollow** (suivi GPS en direct pendant le service), **PawPoints** (fidélité),
abonnements **PawPremium / PawBoost / PawFollow / PawSpot**, code promo.
Propriétaire : **Daniel** (français, non-technique, itération rapide).

## Les 3 surfaces (monorepo)
- **`frontend/`** — app Flutter (GetX, i18n 6 langues FR/EN/ES/DE/IT/PT via
  `lib/localization/translations/*.dart`). Suit la langue du téléphone.
- **`backend/`** — Node/Express + MongoDB (`backend/src`). Déployé sur **Render**.
- **`website/`** — Next.js + Tailwind (`website/src`), i18n via
  `src/lib/i18n/translations.ts`. Déployé sur **Vercel**.
- **`admin_dashboard.html`** — dashboard admin mono-fichier.

## Déploiement (IMPORTANT)
- Backend + site + admin : **`git push origin main`** → auto-deploy Render + Vercel.
  (remote `origin` = github.com/hopetsit/hopetsit)
- **iOS** : build MANUEL sur Mac (voir le PDF `HoPetSit_iOS_Build_Guide_v23.1.xxx.pdf`).
- **Android** : `cd frontend && flutter build apk --release` (+ `appbundle` pour le Play Store).

## Règles permanentes (Daniel)
1. **Trio de version** à CHAQUE build APK : `frontend/pubspec.yaml` (`version: 23.1.X+X`)
   + `backend/src/app.js` (`const ADMIN_BUILD = 'vX'`) + `admin_dashboard.html`
   (`var EMBEDDED = 'vX'` + `title="Build version">vX`).
2. À chaque build APK, **copier** l'APK dans `~/Downloads/HoPetSit_v23.1.<ver>.apk`.
3. **Toujours** `flutter analyze lib` (app) / `npx tsc --noEmit` (web) / `node -c` (backend)
   avant de commit/build.
4. **Règle d'or GetX** : JAMAIS `Obx(() => Builder(builder: …lit .value…))` — lire le
   `.value` directement dans la closure de l'Obx (sinon ErrorWidget GRIS en release).
5. **Release Flutter** : jamais `CrossAxisAlignment.stretch` sur un Row/Column avec
   `Expanded` dans un scroll (crash intrinsèque silencieux en release), jamais
   `Expanded` sous `IntrinsicHeight`.

## Marque / couleurs
Orange `#EF4324` (ou `#F0562B`), ink `#17141f`, vert promeneur `#16A34A`/`#15a35a`,
bleu gardien `#2563EB`, violet PawFollow `#7C3AED`, ambre PawSpot `#E8920A`,
PawPremium noir/or `#1c1726`→`#15120D` + or `#F4C04A`, badge membre rose
`#F06AA0`→`#E0568B`. Web : font-display = Nunito.

## État actuel
**Version app Android : 23.1.523 SOUMISE sur Google Play le 12/07/2026**
(déploiement complet, en examen ; la v500 est LIVE en attendant). Console :
compte Google **allomoteurs@gmail.com** → compte développeur « Daniel
Armando ». APK/AAB aussi dans `~/Downloads` côté PC. Contenu v523 : fix points PawMap invisibles (clé du cache marqueurs),
recherche de ville sur la carte AGRANDIE (n'animait que la carte cachée),
photo de profil stable multi-appareils (login n'écrase plus un avatar existant
par du vide — `_saveUserProfile` dans auth_controller), icône tarifs
€ → billets neutres (Icons.payments, 6 écrans), anglais AMÉRICANISÉ
(Canceled/favorites/Color), libellés « Didit » (les 6 langues). Sur le Play
Store : v500 soumise le 06/07 (statut à vérifier), v499 LIVE dans 177 pays —
fiche : https://play.google.com/store/apps/details?id=com.cardellihermanos.hopetsit.
**iOS : ✅ ACCEPTÉE par Apple (08/07/2026)** — build 506 (Apple IAP + Apple
Sign-In réécrit), fiche https://apps.apple.com/app/hopetsit/id6763645719 ;
code iOS synchronisé sur origin. Un prochain build iOS depuis le Mac (git pull
puis build 523) embarquera les mêmes correctifs. Backend/site/admin déployés
(**ADMIN_BUILD v524** : vérifications d'identité 3 € visibles dans l'onglet
Paiements + cartes à jour, sans double comptage avec la boutique ; v522 =
ajustements comptables ; v510 = Didit remplace Persona côté serveur).
KYC : la 1re vérification Didit réelle (Daniel, sitter) est passée le 12/07 —
session approuvée, badge ✓.

### ⚠️ v498 — RENOMMAGE PACKAGE ANDROID `com.hopetsit.app` → `com.cardellihermanos.hopetsit`
Exigence Google Play (= société CARDELLI HERMANOS LIMITED). Changé dans le CODE :
`build.gradle.kts` (namespace + applicationId), MainActivity déplacé sous
`kotlin/com/cardellihermanos/hopetsit/`, `google-services.json` (package_name
Android), `website/.well-known/assetlinks.json` (2 entrées : ancien + nouveau).
**iOS NON touché** (bundle id reste `com.hopetsit.app`, App Store séparé).
**2 actions CONSOLE obligatoires côté Daniel (sinon login Google + carte cassés)** :
1. **Firebase Console** → Project Settings → Add app (Android) → package
   `com.cardellihermanos.hopetsit` → ajouter les SHA-1 du keystore release
   (2B:08:F1:DC:… et 64:1E:19:91:…) → re-télécharger `google-services.json`.
2. **Google Cloud Console** → la clé Maps `AIzaSyBw11dPKfWj…` → ajouter
   `com.cardellihermanos.hopetsit` + SHA-1 à la restriction « Apps Android ».
FCM marche via le `mobilesdk_app_id` existant. App Links déjà à jour (assetlinks
2 entrées, même SHA-256).
**✅ FAIT côté Daniel** : Firebase + Maps key = SHA-1/SHA-256 de la **clé de signature Google Play**
(`F3:0C:55:8A:…` / `6E:88:82:E5:…`) enregistrées → carte + login Google OK sur la version Store.
assetlinks contient aussi la SHA-256 Google.

### v499 — contournement conflit Play « 498 déjà utilisé »
Bundle 498 déjà consommé dans la Play Console → impossible à ré-uploader. Bumpé en **499**
(aucun changement de code, juste le versionCode) → uploadé + soumis Production.

### Fixes récents (backend/web/admin, SANS rebuild app — déjà poussés sur origin)
- **Couronne premium** réparée partout (app + web) : `isPremium` calculé à 4 endroits
  (`fetchUserMini`, `members/nearby`, `live-positions`, web `premiumIds`) — tous passés en
  **staff + cross-rôle (email/oldId)**. Web : `premiumIds` n'incluait que la famille → ajout des amis.
  ⚠️ vieux compte sans couronne après ça = données email/oldId non liées entre ses 3 rôles.
- **Admin** : colonne « Inscrit le » sur listes Sitters/Walkers ; payout affiche « IBAN (Airwallex) »
  (plus « stripe » legacy).
- **Apple Sign-In** : corrigé sur Mac (sign_in_with_apple + nonce + accessToken + entitlement),
  voir `docs/claude-memory/apple-signin-fix-and-demo-account.md`. ⚠️ ces correctifs iOS sont
  **locaux sur le Mac** (patch `HoPetSit_modifs_locales_20260625.patch`), peut-être pas tous sur origin.
- **Compte démo store** : DOIT être email + mot de passe (pas Google/Apple à 2FA) — cause des
  refus Apple ET Google.
- **Suivi GPS** s'arrête ~1h sur Samsung = batterie OS (mettre l'app « Sans restriction »).

### ⚠️ REPRENDRE SUR LE MAC (lire RESUME-MAC.md)
Sur le Mac : **`git pull origin main`** pour récupérer le dernier code (renommage package
Android v498/v499, fixes couronne, admin). **NE PAS écraser** le Mac avec le zip (ça effacerait
les correctifs Apple locaux non commités). iOS = build sur Mac (Xcode / Codemagic), bundle
reste `com.hopetsit.app`.

### 📦 v523 SOUMISE sur Google Play le 12/07/2026 (examen en cours)
Tous les correctifs en attente sont DANS la v523 (PawMap, Didit, avatar,
icône tarifs, anglais US, recherche ville carte agrandie). Release envoyée
pour examen avec notes en 6 langues (en-GB/fr/de/es/it/pt) ; la v500 était
déjà approuvée et LIVE avant l'envoi. Surveiller le statut dans la console
(allomoteurs@gmail.com → « Daniel Armando »). Côté iOS, builder la 523 sur
le Mac quand Daniel veut pousser la mise à jour App Store (guide :
HoPetSit_iOS_Build_Guide_v23.1.523.pdf).

## Lancer en local
- Backend : `cd backend && npm install && npm run dev` (nécessite `.env`).
- Site : `cd website && npm install && npm run dev`.
- App : `cd frontend && flutter pub get && flutter run`.
