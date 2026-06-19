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
**Version app : 23.1.497** (APK + AAB livrés dans Downloads). Backend/site/admin
déployés. App ↔ web synchronisés (signalements, PawSpot + visites, PawPoints,
membres roses sur la carte, code promo boutique+profil+dashboard, notifications
traduites à la lecture dans la langue courante).

## Lancer en local
- Backend : `cd backend && npm install && npm run dev` (nécessite `.env`).
- Site : `cd website && npm install && npm run dev`.
- App : `cd frontend && flutter pub get && flutter run`.
