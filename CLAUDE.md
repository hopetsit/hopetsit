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
- **`frontend/`** — app Flutter (GetX, i18n 8 langues FR/EN/ES/DE/IT/PT/KO/JA via
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
Orange foncé `#C92A12` (rebrand 16/08 — ex EF4324/F0562B), ink `#17141f`, vert promeneur `#16A34A`/`#15a35a`,
bleu gardien `#2563EB`, violet PawFollow `#7C3AED`, ambre PawSpot `#E8920A`,
PawPremium noir/or `#1c1726`→`#15120D` + or `#F4C04A`, badge membre rose
`#F06AA0`→`#E0568B`. Web : font-display = Nunito.

## État actuel
**25/08/2026 — v545 (travaux Mac 540→545).** Le MacBook est désormais la
machine de travail principale ; le PC sert de miroir à jour.

| Surface | Version | État |
|---|---|---|
| Android (Play) | 23.1.544 | Publiée / en examen |
| iOS (App Store) | 1.10 = build 544 | **PUBLIÉE** |
| iOS (App Store) | 1.11 = build 545 | En review (nouvelle ASO) |
| Backend + admin (Render) | ADMIN_BUILD v545 | Déployé |
| Site (Vercel) | à jour | Déployé |

**Prochain build APK/AAB = 546** (540→545 consommés par le Mac).

**Contenu 540→545** : onboarding haute-fidélité (police Fredoka, tuiles de
rôle, micro-animations) ; **mode invité complet** (navigation sans compte,
fiche profil consultable, mur d'inscription seulement à l'action) ; fin du
blocage « ajoute ta ville » (retour en haut du formulaire + détection auto) —
c'était LE mur qui faisait abandonner les inscriptions ; **devise par pays**
(won KRW et yen JPY ajoutés app/backend/admin/boutique) ; sélecteur de devise
réparé côté gardien et ajouté côté promeneur ; retours Jose (« Demander un
service », « Mes annonces », crayon d'édition animaux) ; e-mails Gmail avec
« + » acceptés ; spinners Google/Apple ; bouton « Reprendre » ; **icône
officielle** déployée partout depuis le vectoriel de Daniel.

**Marketing (réel, 25/08)** : ≈723 € de Google Ads → 768 installs
(0,94 €/install ; Paris 1,01 € / Dallas 3,96 €). **2 inscriptions en 7 jours,
toutes deux aux USA en organique, 0 à Paris malgré la campagne.** Base : 16
propriétaires / 11 gardiens / 16 promeneurs. **La pub n'est pas le problème :
Paris n'a qu'UN SEUL prestataire (Asnières).** Priorité = recruter 10 pet
sitters parisiens (DM Instagram #petsitterparis, groupes Facebook) et
réorienter les annonces vers le recrutement.

**Code promo unique : `HOPDALIOS`** — offer code App Store (1 mois PawPremium,
tous pays, expire 31/12/2026) + code maison Android. Envoi depuis l'admin :
Promotions → « Envoyer une promo par email ».

**Comptes de test** (base réelle, masqués de la vitrine) :
`dadaciao84+testowner@gmail.com`, `+testsitter`, `+testwalker` — mot de passe
`Hopetsit2026`.

**Reste côté Daniel** : réimporter l'icône de la fiche Play À LA MAIN (Google
refuse l'injection par script) puis envoyer en examen ; avis 5 étoiles
(levier n°1 du classement App Store) ; recrutement sitters Paris.

### ⚠️ Règles ajoutées par le Mac (540→545)
- **NE JAMAIS réintroduire `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO`** dans
  l'AndroidManifest : Google a **BLOQUÉ la release 541** pour ça (règle
  « sélecteur de photos »). Retirées avec `tools:node="remove"`.
- **Icône** : uniquement le vectoriel de Daniel, rendu direct, **sans
  reconstruction de fond** — toute retouche modifie les couleurs ou rogne les
  pastilles.
- **`flutter clean` avant un IPA release** si un build simulateur a eu lieu
  (sinon Apple rejette : slice x86_64).
- **Play Console : import des images de la fiche = MANUEL.**

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
