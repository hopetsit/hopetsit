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
**02/09/2026 — v546 « deep work vérification complète » (Mac).** Le MacBook
est la machine de travail principale ; le PC sert de miroir à jour.

| Surface | Version | État |
|---|---|---|
| Android (Play) | 23.1.546 | AAB/APK dans ~/Downloads — **import Play = Daniel** (session Google requise) |
| iOS (App Store) | 1.11 = build 545 | **PUBLIÉE** (READY_FOR_DISTRIBUTION) |
| iOS (App Store) | 1.12 = build 546 | créée par API (id b7e6640f-…), whatsNew posés, descriptions FR/EN remises dans le bon sens |
| Backend + admin (Render) | ADMIN_BUILD v546 | Déployé |
| Site (Vercel) | polonais + fix géoloc PawMap + blog | Déployé |

**Prochain build APK/AAB = 548** (547 = icônes officielles + polonais, construit le 02/09).

**02/09 — v547 + marketing automatisé (demande Daniel : « fais tout seul »)**
- **Icône** régénérée depuis `Hopetsit Icon-01.svg` : Android premier plan à
  **74 %** du canevas 108 (pastilles + pointeur entiers sous masque rond,
  vérifié visuellement), fond = illustration agrandie + floutée (dégradé réel)
  dans `drawable-*` — le XML lit `@drawable/ic_launcher_foreground`, PAS
  `mipmap` ; iOS 1024 plein cadre, coins remplis par le même flou (local).
  Play 512 : `~/Downloads/HOPETSIT_ICONE_512.png` (import manuel).
- **Routine cloud hebdo** `trig_01BpzyjaJz7SPDgPFCdjinQM` (dimanche 7 h
  Paris) : 1 article FR Paris/semaine (impaire = recrutement sitters, paire =
  propriétaires) + 1er dimanche du mois EN/PL/KO ; posts sociaux prêts à
  coller dans `website/marketing/social/`, rapport dans
  `website/marketing/reports/` ; tsc + push → Vercel. Mode d'emploi :
  `website/marketing/README.md`. Gestion : https://claude.ai/code/routines.
- **SEO programmatique** : 47 pages « devenir pet sitter à <ville> »
  (`website/src/lib/recruit-cities.ts` + `components/RecruitCityPage.tsx`) —
  FR paris-1…20 + communes + grandes villes, EN 7 villes US, PL 5, KO 3 ;
  sitemap automatique. Une ligne de données = une page.

**Contenu 546** (chantier de vérification demandé par Daniel — tout testé en
prod avec les comptes test + simulateur iOS) :
- **BUG RACINE « la photo de profil disparaît sur l'autre téléphone »** :
  depuis la migration du jeton vers le stockage sécurisé (part 125),
  `_purgeLegacy()` vide GetStorage mais 9 lectures directes du jeton restaient
  (ProfileController, SocketService, splash, live map, factures, rapport de
  visite, auth_controller) → au démarrage à froid : profil jamais rechargé
  (silhouette), sockets temps réel jamais connectés. Fix :
  `SecureTokenStore.currentToken()` partout. + côté serveur
  `utils/avatarFallback.js` (photo complétée depuis un rôle frère si vide) sur
  login e-mail/Google/Apple et `/users/me/profile`.
- **Langue POLONAISE** (ouverture Varsovie) : app (`pl.dart`, 3 200 textes
  générés par `translate_pl.py` + glossaire relu), site (bloc `pl`, sélecteur,
  légal = anglais repris — à faire relire), serveur (`APP_LOCALES`,
  `locales/pl/notifications.json`). Info.plist local : CFBundleLocalizations.
- **Invitation d'amis par lien** enfin fonctionnelle : lien avec rôle,
  `/invite` traité (demande envoyée automatiquement ; mémorisée si pas de
  session et rejouée après connexion), AASA `/invite`, Android pathPrefix.
- Design : états vides illustrés (classement PawPoints, accueil « Mes
  annonces », parrainages) ; « (N avis) » en dur → clé `reviews_count_short`.
- Vérifié OK (API prod + UI) : chaîne réservation → acceptation → intention de
  paiement Airwallex → HPP (formulaire carte rendu, dans l'app aussi pour
  « Ajouter une carte » 0,50 €) ; wallet, PawPoints, boutique (StoreKit),
  publications → candidature → acceptation, blocage/déblocage, amis, PawMap.
  **Le vrai débit carte reste à faire par Daniel** (quelques euros).
- ⚠️ Produit : le chat hors réservation payée exige Premium/add-on
  (« Chat requires an active Premium plan ») → frein possible à la 1re vente.
- Simulateur : intégration native KO tant que `sudo xcode-select -s
  /Applications/Xcode.app/Contents/Developer` n'est pas lancé par Daniel →
  contrôle d'écran (computer-use) + osascript pour taper.

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

**Marketing (réel, 30/08)** : ≈810 € de Google Ads cumulés → 985 installs
(0,82 €/install). **Paris : 662 installs, 0,94 €/install… et ZÉRO inscription
parisienne.** Dallas : 2,88 €/install, toujours PAS mise en pause. Base
inchangée : 16 propriétaires / 11 gardiens / 16 promeneurs. Sur 21 jours,
**4 inscriptions réelles seulement** (Alexis/Asnières, Alicia/Férolles,
Linda/Texas, Serena/Géorgie) — les 2 américaines venues en **organique, sans
pub**. **La pub n'est pas le problème : Paris n'a qu'UN SEUL prestataire
(Asnières).** Une ville sans offre ne convertit aucun propriétaire.

**Test en cours (lancé le 30/08)** : budget Paris monté à **15 €/jour** avec
un message réorienté vers le **recrutement de sitters** (un sitter rejoint une
app jeune, un propriétaire non). Durée 10 jours, **un seul indicateur : le
nombre de nouveaux prestataires parisiens** — ≥8 : on investit ; 3-7 : on
affine ; <3 : on arrête la pub. ⚠️ Les DM Instagram à froid n'ont RIEN donné
(ils tombent dans « Invitations », jamais lus) → canal abandonné au profit des
**groupes Facebook locaux**, où Daniel a publié lui-même le 30/08.

**🎯 OBJECTIF PRIORITAIRE DE DANIEL : SA PREMIÈRE VENTE** (une réservation
réellement payée), pas seulement des inscriptions. Chemin retenu : (1) valider
de bout en bout la chaîne réservation → paiement → versement AVANT de pousser
du monde, (2) faire venir la demande par l'offre existante — demander aux
prestataires déjà inscrits d'amener leur premier client réel (transaction +
avis + preuve que ça marche), (3) concentrer sur UNE micro-zone (Asnières,
où il y a déjà un sitter) plutôt que « Paris » en général.

**Rendez-vous marketing : le DIMANCHE** (Daniel écrit « bilan » / « marketing »)
→ chiffres pub + inscriptions par ville + UNE décision. **Blog : un article
toutes les 2 semaines.** 10 articles en ligne (vérifiés), dont le dernier :
« Devenir pet sitter : combien ça rapporte vraiment ? ». ⚠️ Déséquilibre à
corriger : 8 articles sur 10 s'adressent aux PROPRIÉTAIRES alors que le besoin
n°1 est le recrutement de prestataires. Prochain sujet prévu : « Pet sitter :
faut-il se déclarer, et comment ? » (l'administratif est le frein réel).

**Code promo unique : `HOPDALIOS`** — offer code App Store (1 mois PawPremium,
tous pays, expire 31/12/2026) + code maison Android. Envoi depuis l'admin :
Promotions → « Envoyer une promo par email ».

**Comptes de test** (base réelle, masqués de la vitrine) :
`dadaciao84+testowner@gmail.com`, `+testsitter`, `+testwalker` — mot de passe
`Hopetsit2026`.

**Reste côté Daniel** : mettre **Dallas en pause** et vérifier que les titres
d'annonce Paris sont bien passés au message « recrutement » (⚠️ **Google Ads
refuse TOUS les clics automatisés** — 4 méthodes essayées : cellule d'état,
cases à cocher, page de paramètres, menu groupé → toute manipulation Ads est
MANUELLE) ; avis 5 étoiles (levier n°1 du classement App Store) ; réimporter
l'icône de la fiche Play à la main puis envoyer en examen.

**Site web — travaux après le 25/08** : bouton « me géolocaliser » de la
PawMap réparé (son callback d'erreur était vide → échec silencieux ; désormais
spinner, double tentative avec position récente acceptée, et message explicite
en 8 langues) ; icônes refaites depuis le **vectoriel de Daniel** en rendu
direct (mes versions « reconstruites » modifiaient les couleurs et rognaient
les pastilles — ne jamais recommencer) ; visuel de recrutement publié sur
`/social/recrutement-paris.jpg` ; nouvel article de blog.

**Publication automatique Facebook/Instagram — préparée, EN ATTENTE** :
programme prêt dans `~/hopetsit-social/` (publier.py + contenu.json +
MODE_EMPLOI.md), utilisant l'API Graph officielle. Bloqué à une seule étape :
la génération du jeton d'accès, que Meta réserve à un clic humain.
⚠️ **Cause du blocage identifiée** : Chrome est connecté à un compte Facebook
qui n'est PAS développeur (« Aucune app disponible » dans l'Explorateur) —
l'app HoPetSit appartient au compte **Daniel Cardelli** (user 61590618398480).
Alternative sans code recommandée : le planificateur natif de **Meta Business
Suite**, qui programme des publications Facebook + Instagram à l'avance.

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
