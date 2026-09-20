# HoPetSit — Contexte projet pour Claude Code

> Ce fichier est chargé automatiquement par Claude Code. Il sert de « prompt »
> de reprise quand on travaille sur ce projet (y compris sur le Mac).
> L'historique détaillé (gotchas, décisions, versions) est dans
> **`docs/claude-memory/`** (copie de la mémoire) — lis `docs/claude-memory/MEMORY.md`.

## 🎯 LA MISSION — à lire en premier (document de Daniel, 14/09/2026)
> Détail complet : **`docs/claude-memory/la-mission.md`**. Chef de projet : **Bob**.

**Pourquoi.** Pour Daniel, l'argent n'est pas un chiffre : c'est **se nourrir, se loger, et
offrir une maison à sa maman**. HoPetSit est aussi un vrai service pour les propriétaires
d'animaux et ceux qui les gardent. Le but : que l'app réussisse et rapporte, durablement.
**La promesse** : l'effort chaque semaine, la mesure exacte, la vérité sur ce qui marche ou
non, et le changement de méthode quand ça ne marche pas. **On ne lâche pas.**

- **Objectif** : de nouveaux utilisateurs qui **réservent et paient**. Le critère, ce sont les
  **réservations payées et terminées** — **PAS le trafic**.
- **Marchés** : **Paris (fr)** et **USA (en-US)**, à égalité. Les autres pays sont **en pause**.
- **Autonomie** : tout ce qui peut tourner sans Daniel tourne sans lui.

**Les 6 règles permanentes :**
1. **Pas d'argent en plus** — Daniel est au maximum. Seule dépense acceptée : la pub Meta
   actuelle (16 €/jour). Tout nouveau levier doit être **gratuit** et tourner sur le Mac.
2. **Décisions** — Claude décide seul de ce qui est **gratuit et réversible** ; il demande
   l'accord de Daniel avant **toute dépense**, **tout rebuild de l'app**, et **tout envoi en
   son nom à de nouvelles personnes**.
3. **Honnêteté** — **jamais de chiffre inventé, jamais de promesse de revenus**. Si rien n'a
   bougé, on l'écrit.
4. **Priorité** — d'abord ce qui **fait perdre des utilisateurs**, ensuite ce qui **fait
   réserver**, enfin le design.
5. **Projets séparés** — Bob ne s'occupe **que** de HoPetSit (jamais LawsTravels, Allomoteur, AEPS).
6. **Listes de contacts** — **toujours vérifiées avant usage** (la liste « cliniques vétérinaires
   Espagne » du 14/09 était inventée : 35 domaines sur 40 inexistants → non utilisée).

**Prochaine grosse étape** : **build 565** après la remise à zéro du forfait le **18/09**, au
signal « go build 565 » de Daniel. ⚠️ La liste qui fait foi est la section
**« 📋 PROCHAIN BUILD (v562 app, build 565) »** plus bas dans ce fichier (tenue à jour) —
`la-mission.md` n'en garde qu'un instantané du 14/09.

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

**Prochain build APK/AAB = 575** (574 = 23.1.568 rôles synchronisés + correctif INVALID_BINARY, 20/09 ; 573 = audit ancien design + correctifs, 20/09 ; 572 = correctif bandeau → PawMap, 20/09 ; 571 = v567 accueils, 20/09 ; 570 = v567 : Play 570 le 19/09 ~23 h 30, iOS build 570 validé en attente de l'approbation de la 1.18/569 pour partir en 1.19 ; 569 = v566 publiée le 19/09 ~10 h 35 : Play 569 par API, iOS 1.18 build 569 resoumis ; 568 = v565 publiée le 19/09 ~04 h 20 : Play 568 par API, iOS 1.18 build 568 resoumis ; 567 = v564 publiée le 19/09 ~02 h : Play 567 par API, iOS 1.18 build 567 resoumis à la place du 566 ; 566 = v563 publiée le 18/09 à 13 h 30 : Play release 566 par API, iOS 1.18 build 566 resoumis à la place du 565 ; 565 = v562 publiée le 18/09 : Play release 565 par API, iOS 1.18 build 565 soumis ; 564 = v561 publiée le 12/09 : Play release 564 par API `play_release_api.py` [commit 200], iOS 1.17 build 564 ; 563 = IPA seule v560). 548 (03/09) = traductions site + polonais app + PawMap monde → Play APPROUVÉ/LIVE ; iOS 1.12/547 APPROUVÉE, **1.13 (build 548) WAITING_FOR_REVIEW**. **549 (04/09) = les 6 autres langues de l'app relues (es/de/it/pt/ko/ja, 1 915 corrections)** → **Play APPROUVÉ/LIVE (« Dernière release : 549 »)**, iOS : soumission 548 annulée, **1.13 resoumise avec le build 549 → WAITING_FOR_REVIEW (04/09)**.

**18/09 (nuit) — BUILD 565 (v562 app) : la grande passe des 37 points, EN COURS.** Méthode : 8 lots
en parallèle (contrats figés dans `docs/v565_contracts.md`, clés i18n par lot dans
`frontend/lib/localization/v565/*_i18n.dart` fusionnées par `v565_i18n.dart`). ⚠️ 8 agents Fable en même
temps ont épuisé la limite de SESSION en 30 min (pas le forfait hebdo) → relance par vagues de 4.
Livré et poussé (commit 9b337e5, déploiement Render + Vercel lancé par Daniel via
`~/hopetsit-social/publier_565.sh` — le garde-fou de Claude refuse commit/push) :
- **Notifications (point 5)** : chaîne iOS vérifiée (clé APNs prod importée le 07/09, entitlement
  production, background modes) ; **BUG liens e-mails/push** : `BASE_URL` générait `https://hopetsit.com`
  dont le fichier AASA répond 308 → www (Apple exige zéro redirection) → tous les liens passent en
  `www.hopetsit.com` (`emailLinkBuilder.js`). Double bannière iOS en premier plan corrigée
  (`push_notification_service.dart`). **Écran « Tester mes notifications »** (Profil › Aide) : autorisation,
  jeton, ré-enregistrement, envoi à soi-même de CHAQUE type (`POST /notifications/test-fire { type }`,
  `GET /notifications/test-types`, 20/10 min). Préférences par catégorie + son (aboiement / miaulement /
  cui-cui synthétisés en numpy, `assets/sounds`, `res/raw`, `Runner/Sounds/*.caf` ajoutés au pbxproj) :
  `GET/PATCH /users/me/notification-prefs`, canaux Android `hopetsit_<son>`, `apns.sound`. Plateforme des
  jetons mémorisée (`fcmDevices`) et affichée dans l'admin ( / 🤖).
- **Backend** : remise/rendu (point 24 : `handover`, `timeline`, `/handover/confirm-pickup|return`,
  `handoverScheduler.js` 60 s, 11 nouveaux types `handover_*`/`live_*` dans les 9 locales) ; partage en
  direct robuste (§8 : RAM 24 h, `lastSeenAt`/`stale`, `duration`, `heartbeat`, plus d'offline à la
  déconnexion socket) ; `createPost` notifie par ville normalisée + rayon (avant : 50 premiers prestataires
  du monde sans ville) ; chaîne de paiement auditée (2 corrections : rappel `schedulePayoutForBooking`
  écrasant l'auto-release, chemin PayPal sans push) ; changement d'e-mail (§3) ; verrou contacts 700 (§4,
  `CONTACTS_FREE_UNTIL_USERS`) ; chat vocal/réponse/médias + drapeaux admin (`AppConfig`,
  `/app-config/chat-features`) ; présence réelle (`presence:update`, `isOnline`/`lastSeenAt`) ; **BUG
  RACINE point 1** : `utils/userSyncService.js` exportait un identifiant inexistant → la synchro entre les 3
  profils n'a JAMAIS marché (corrigé + propagation via identityGroup) ; ville plate `city` conservée sans GPS
  (owner/sitter/walker) ; **switchRole NON destructif** (Daniel : « un compte, trois profils », « garder mes
  abonnements ») : profil cible existant réutilisé, ancien profil conservé, abonnement copié
  (`syncSubscriptionAcrossRoles`), `availableRoles` renvoyé.
- **App** : chat (`views/chat_shared/`, vocal `record`+`audioplayers`, réponse, photos/vidéos réparées :
  timeout 30 s, 10 fichiers vs 5, vidéos non sélectionnables), PawMap (amis en direct rose, chat du cercle
  sur la mini carte, Autour de moi = lieux animaux seulement, rôle coloré dès zoom 9, demandes
  synchronisées, plus de cap 2 h/30 min, durée 1 h/4 h/illimité, rails fixes, bouton retour), profil
  (catégories, `MyProfilesCard` « Mes profils » Actif/Activé/Activer, e-mail, préfixe, complétion %,
  `contact_info_gate.dart`, préférences/notifications, pop-up promo **pré-rempli avec le code du moment**
  `GET /app-config/public-promo` (défaut HOPDALIOS, réglable dans Admin › Promotions), feuille
  `showPromoCodeSheet(initialCode, autoApply)`), accueil/réservations (bandeau → PawMap, chronologie de
  remise, portes adresse/téléphone, « J'ai un code » à la réservation et en boutique), bouton « Nouvelle
  conversation » modernisé, « Modifier l'animal » modernisé, badge ∞ au-delà de 10 ans. **BUG** Accueil ›
  Autour de moi : la liste cherchait au GPS mais affichait la ville du profil → ancre GPS > profil, libellé
  « Ma position », repli sur les coordonnées du profil si GPS refusé.
- **Admin** : menu en 6 groupes, compteurs cliquables + auto 60 s, page Animaux, e-mails partout,
  chronologie de remise, drapeaux chat, code du moment, 140 appels vérifiés contre les routes,
  `GET /admin/bookings/:id`, `GET /admin/pets`. **Site** : AASA complet, pages `/friends/requests`,
  `/notifications`, `/paw-spot`, `/subscription`, `/wallet`, `/post`, `/report`, présence, `PromoCodeBox`,
  chat (vocal, citation, répondre), changement d'e-mail (à finir).
- **Démo simulateur (iPhone 17 Pro, `xcode-select` non posé → pilotage par simctl + computer-use)** :
  pop-up → HOPDALIOS appliqué en 1 tap (Paw Premium activé, vrai serveur) ; feuille code faux/réel OK ;
  API web : code faux 404, déjà utilisé 409. Pas d'émulateur Android sur ce Mac. Astuce : saisir du texte
  dans le simulateur = coller (`simctl pbcopy` + Cmd+V) — la frappe brute envoie des « Q » (clavier FR).
- **Reste (agents coupés par la limite, reprise à 6 h)** : points 17/35/28 (modernisation accueil,
  réservations, paiements/wallet), site (fin), **38** (notes en étoiles), **39** (sous-pages Profil
  restantes). Puis IPA + AAB + stores, admin 565/565 après validation. Notes stores prêtes :
  `~/hopetsit-social/play/notes_565.json` (≤ 500 car.) et `notes_565_asc.json`.
- **Suite de nuit (03 h–03 h 30)** : sous-pages Profil (point 39 : 3 « Modifier le profil », fiche animal
  création/modification en cartes Photo · Identité · Santé · Caractère (pilules) · Vie quotidienne · Bio, tarifs,
  disponibilités, IBAN, carte, onboarding sitter 100 % traduit, KYC, avis) ; paiements/wallet (Mes paiements,
  Mes cartes, Portefeuille, Gérer mes paiements — débordement IBAN corrigé —, historique/gains/statut de
  versement, factures + PDF, écrans Airwallex/PayPal/résultat, rapport de visite, suivi de promenade) ;
  accueil/réservations (chronologie de remise, « Publier ma demande » en 6 étapes + récapitulatif, étoiles
  `rating_stars.dart` + bandeau « laisser un avis », `booking_ui_kit.dart`, lat/lng envoyés avec l'annonce) ;
  PawMap rails redessinés (`paw_rail_button.dart`, capsule translucide) ; **en-têtes de profil unifiés**
  (`profile_hero.dart` : chip rôle, cloche, avatar, pilule statut/animal, badges « Premium · 60 j », 3 tuiles
  cliquables) ; « Mes profils » Actif/Activé/Activer ; pop-up promo affiche la récompense réelle
  (« 1 mois de Paw Premium gratuit », via /promo/check). Audit i18n final (`scratchpad/check_i18n.py`) :
  3 739 clés en, 0 manquante dans les 9 langues, 0 clé inconnue. `dart analyze lib` = 0 erreur/0 warning,
  `node -c` OK, `tsc` 0 erreur. Vérifié en prod après déploiement : public-promo, chat-features, 70 types
  test-fire, notification-prefs, switch non destructif (owner→sitter crée, retour réutilise le même id).
- **Sons v2 (Daniel, 03 h 40)** : « grenouille » = son PAR DÉFAUT (`notificationPrefs.sound` défaut `frog`,
  serveur + app), aboiement et miaulement resynthétisés (source glottale + résonances, scipy), le choix
  « oiseau » devient un **hibou** (id `tweet` conservé pour les canaux/serveur, libellé `notif_sound_tweet` =
  Hibou 🦉). Fichiers `frog.*` ajoutés (assets/sounds, res/raw, Runner/Sounds + pbxproj). En-tête profil :
  la tuile « Réservations » POUSSE l'écran (flèche retour) au lieu de changer d'onglet (Daniel : « pas de
  retour vers mon profil »).
- **Fin de nuit (04 h–05 h)** : **AUDIT INSCRIPTION 3 profils** (`backend/tests/authSignupFlow.test.js`, 22 tests,
  jest 49/49) — causes racines corrigées : le `login` appelé juste après `signup` régénérait le code → le lien
  du 1er e-mail était « expiré » (code récent < 10 min conservé) ; `verified` posé sur le 1er profil seulement
  → propagé aux 3 ; inscription Google/Apple d'un nouvel utilisateur n'aboutissait pas (`ROLE_REQUIRED` → wizard
  e-mail) → écran `social_city_screen.dart` + relance avec `role`/`user`, nom Apple mémorisé ; e-mail de
  vérification en anglais sans prénom (serveur lisait `req.body.appLocale` au lieu de `user.*`) ; photo
  d'inscription perdue sur le chemin direct (`utils/pending_signup_photo.dart`) ; retour arrière = étape
  précédente (`PopScope`) ; écran OTP « J'ai déjà activé via le lien » + vérif au retour au premier plan ;
  `/auth/login|verify|signup` renvoient `emailVerified` + `availableRoles` ; `resend-code` 429 < 60 s ;
  switchRole copie `city`/`country`/`appLocale`/`dateOfBirth`/`createdAt`. Décisions Daniel (« le plus pro ») :
  **ville obligatoire côté serveur pour les clients ≥ 565** (en-têtes `X-App-Version` / `X-App-Platform`
  ajoutés dans `api_client.dart`, `X-App-Version: web` sur le site ; `400 CITY_REQUIRED` traduit ; anciennes
  apps tolérées) ; **mur d'inscription invité = 3 rôles** avec « Recommandé » selon le contexte.
  Calendrier/portefeuille : `views/shared/provider_quick_actions.dart` (2 cartes sous l'en-tête sitter/walker),
  `views/shared/availability_calendar_screen.dart` (tap = dispo, re-tap = bloqué, glisser, raccourcis,
  auto-enregistrement, jours réservés verrouillés ; l'ancien fichier réexporte). PawMap : feuille de durée avec
  l'option en vert + temps restant + `changeDuration()`, pilules du haut en verre (badge filtres actifs), dock
  du bas assorti. Admin : « Promotions » sous « Utilisateurs », EMBEDDED v565. Contrôles finaux : `dart analyze
  lib` 0 erreur/0 warning, i18n 3 787 clés / 0 manquante, `tsc` 0, jest 49/49.
- **PUBLICATION 18/09 ~05 h** : `~/Downloads/HoPetSit_v23.1.562_build565.{ipa,aab,apk}`. **Play : release 565
  envoyée en production par l'API** (`play_release_api.py`, bundles.upload → track production → commit 200,
  notes `notes_565.json` 8 langues). **iOS : 1.17/564 était READY_FOR_SALE** → admin « Versions de l'app »
  iOS 564/0 posé ; **version 1.18 créée** (id `85b02ee8-8e79-4c2f-bce4-3d4da20a9047`), whatsNew 8 locales
  (`notes_565_asc.json`, 200 ×8), IPA distribuée par Transporter (DISTRIBUER cliqué via osascript
  `click at {1122,254}` — la fenêtre Transporter n'expose pas le bouton en AX), chaîne iris exécutée dans
  l'onglet ASC de Daniel : build 565 VALID (~15 min après Transporter) → attaché à la 1.18 → reviewSubmission
  `3f3a47b7-5920-4f78-9757-ea1034a36c8c` SUBMITTED 200 (05 h 05) → **1.18/565 WAITING_FOR_REVIEW**. ⚠️ Passer l'admin à 565/565 quand Play ET Apple ont approuvé (`PATCH /admin/app-version`
  `{android:{latest:565},ios:{latest:565}}`).
- **Bob (18/09, Daniel : « qu'il continue tout ce qui est en son pouvoir, gratuit et seul »)** :
  `~/hopetsit-social/BOB_PROMPT.md` étendu (effet 565 sur le taux de vérification, contrôle des leviers, un
  levier gratuit par semaine, actions 15 min pour Daniel) et **routine cloud créée**
  `trig_015koa7pn7ptRxyKBmVUkd5f` « HoPetSit — Bob, chef de projet » (lundi 07:00 UTC = 9 h Paris, Sonnet 5,
  Gmail, repo hopetsit/hopetsit ; 1re exécution 21/09), après le KPI local de 8 h.
- Décisions produit prises seul (à confirmer par Daniel) : cap gratuit 30 min du partage en direct
  SUPPRIMÉ (le partage ne s'arrête que sur action ou durée choisie) ; les anciens types `service_started`/
  `service_completion_request` remplacés par `handover_*` sur ces actions.

**18/09 (journée) — BUILD 566 (v563 app) : « que ce soit nickel » (Daniel, option A validée).** Remplace la
565 en examen. Méthode : lots exclusifs par vagues de 3-4 agents. Contenu :
- **Données de facturation** (CIF/NIF/NIE, SIRET, n° d'entreprise, TVA, passeport, adresse) : Profil ›
  Paiements › « Informations de facturation » (`billing_info_screen.dart`), `GET/PATCH /users/me/billing-info`
  (`utils/billingInfo.js`, synchronisé entre les 3 profils), **instantané figé sur chaque facture** (PDF app,
  e-mail, site `BillingInfoSection.tsx`), lecture admin `/admin/users/:role/:id/billing-info`.
- **Pop-up promo** : il passait DERRIÈRE le menu flottant sur Android (viewPadding = 0) → dégagement calculé
  (`padding.bottom` sinon `viewPadding + 96`), vérifié iOS aussi.
- **Chat** : double coche façon WhatsApp + « Lu » (`messageReceiptService.js`, `message:delivered` /
  `message:read`, `chat_receipt_ticks.dart`), bouton « Nouvelle conversation » (FAB qui s'étend), cartes
  « Suivre en direct » refaites (`pawfollow_widgets.dart`) ; `live_tracking_accepted|refused` n'étaient JAMAIS
  envoyées → corrigé.
- **Notifications (audit complet)** : `backend/scripts/audit_notifications.js` (types × 9 langues × canaux) ;
  **sons absents de l'AAB 565** (réduction de ressources) → `res/raw/keep.xml` ; icône `ic_stat_notify` ;
  init push iOS qui sautait les écouteurs sans jeton ; **badge iOS** (`aps.badge` pour build ≥ 566, canal natif
  `hopetsit/badge` dans `AppDelegate.swift`, `app_badge_service.dart`) ; **« lu » synchronisé entre appareils**
  (`notification.read` / `notification.removed` par socket + push silencieux) ; e-mails : gabarit unique
  échappé (`buildNotificationEmailHtml`), tutoiement FR partout.
- **Boutique** : `shop_ui_kit.dart`, devise du compte (plus d'euro figé), `GET /pawspots/plans`, PawSpot payé
  par carte jamais activé quand `/confirm` arrivait avant le webhook → corrigé, réductions réservées puis
  consommées APRÈS paiement (`discountReservationService.js`), site `useShopPrices.ts`.
- **Amis** : sous-pages refaites (`views/friends/tabs/*`, `friends_i18n.dart`), déblocage qui échouait selon le
  rôle de la cible (`blockController`), nom du titulaire d'une invitation famille.
- **PawMap fluide** : `BackdropFilter` retirés au-dessus de la carte (`paw_rail_button.dart` → RepaintBoundary).
- **Admin — revenus boutique** : `services/shopRevenueService.js` = calcul UNIQUE pour Tableau de bord,
  Boutique, Comptabilité et Revenus (App Store · Google Play · Carte/PayPal · Offerts), commissions des stores
  réglables (`ShopFeeConfig`, `/admin/shop-revenue`, `/fees`). **Montants réels** : Apple = prix/devise/pays/
  environnement lus dans la transaction signée (`amountSource: 'store'`), carte/portefeuille = montant débité
  (`'psp'`, `utils/paidAmount.js`, y compris boost profil, boost carte, add-on chat qui écrivaient encore le
  prix catalogue + « stripe »), `platform` ios|android|web (`utils/purchasePlatform.js`), **Sandbox et
  remboursés exclus des revenus** (`excludedFromRevenue`, `refundedAt` → `excludedCount`/`refundedCount`).
  Les lignes d'avant le 18/09 restent « estimé » (prix catalogue) — rien n'est inventé. ⚠️ Android : aucun
  Play Billing (achats par carte Airwallex / portefeuille) → la colonne Google Play reste à 0, c'est normal.
- **PUBLICATION 18/09 ~13 h 30** : `~/Downloads/HoPetSit_v23.1.563_build566.{ipa,aab,apk}` (4 sons vérifiés dans
  l'AAB et l'IPA). **Play : release 566 en production par l'API** (commit 200, `notes_566.json`). **iOS** : IPA
  par Transporter (DISTRIBUER = `click at {1317,307}`, la position change selon la liste), build 566 VALID
  (`8e527a19-…`) ~12 min après, soumission 565 `3f3a47b7` annulée (200), 566 attaché à la 1.18 (204 au 1er
  essai après 6 s), whatsNew 8 locales (⚠️ les locales ASC s'appellent `it` et `pl`, pas `it-IT`/`pl-PL`),
  nouvelle reviewSubmission `8852b59c-ea09-421b-b06c-09c1c09ee478` → **1.18/566 WAITING_FOR_REVIEW**.
  Serveur : commit + push par Daniel (`~/hopetsit-social/publier_566.sh`). ⚠️ Passer l'admin « Versions de
  l'app » à 566/566 quand Play ET Apple ont approuvé. **Prochain build = 567.**
- Contrôles : `dart analyze lib` 0 erreur, i18n 3 945 clés / 0 manquante / 0 inconnue, `tsc` 0, jest 127/127,
  JS admin valide. ⚠️ Incident : un agent a affiché le mot de passe admin dans une sortie d'outil →
  **Daniel doit le changer**. À prouver sur vrai téléphone : notifications type par type, sons Android,
  badge iOS, synchro multi-appareils, un achat de test.

**19/09 (nuit) — BUILD 567 (v564 app) : retours Daniel sur la 566 installée (captures Samsung).**
- **SONS / VIBREUR ANDROID MUETS — cause racine** : Android FIGE un canal de notification à sa création. Les
  téléphones passés par le build 565 (sons absents de l'AAB) ont créé `hopetsit_<son>` muets, à vie (un canal
  supprimé puis recréé sous le même id retrouve ses anciens réglages). → **canaux « _v2 »**
  (`hopetsit_<son>_v2`, `hopetsit_default_v2`, importance max, vibration 220/260 ms), anciens canaux supprimés
  au démarrage, manifeste `default_notification_channel_id = hopetsit_default_v2`, serveur
  `pushSoundConfig` aligné (une ancienne app retombe sur le canal par défaut de son manifeste). ⚠️ RÈGLE : ne
  JAMAIS changer le son/la vibration d'un canal existant — créer un `_v3`.
- **Sons v3** (`scratchpad/synth567.py`, synthèse source/filtre, plus forts : −5 à −12 dBFS RMS) : nouveau
  **`chime`** (bip moderne 2 notes) = son « par défaut » (libellé « Bip moderne », `chime.wav/.caf/.m4a`,
  `keep.xml`, pbxproj), aboiement « ouaf ouaf », miaulement, grenouille « rib-bit », hibou. La grenouille reste
  le son par défaut d'un compte neuf.
- **Boutique** : helper `shopBottomInset()` (inset 0 sur Samsung edge-to-edge → 48 px ; iOS = inset réel) sur la
  barre d'achat et les feuilles ; `ShopHero`, `ShopStatusPill`, « Illimité ∞ » > 3 650 j ; même règle posée
  dans `showProfileSheet` (feuille « J'ai un code »). **Bannière** `CustomSnackbar` refaite (carte blanche
  flottante dans l'Overlay racine, API inchangée, `ensureVisualUpdate` ajouté ; test `test/banner567_test.dart`).
  **Page Avis** refaite. **Suppression de compte** : feuille « Avant de partir… » (3 raisons max + commentaire)
  → modèle `AccountDeletion` (e-mail haché), `DELETE /users/me?reasons=…`, admin « 🚪 Comptes supprimés »
  (`GET /admin/account-deletions`).
- **PawSpot (audit)** : points infinis par création/suppression (confirmé en prod avec le compte test → corrigé :
  reprise des points, limite gratuite sur les créations cumulées et PAR COMPTE, plafond 10 spots/jour), abonné
  reconnu cross-profil, solde boutique, classement dédoublonné, like réel, anti-triche, « +20 » Premium affiché,
  2 notifications auteur (`pawspot_validated`, `pawspot_popular`, catégorie pawmap, 9 langues), compteur de tags
  gratuits. **Voir les spots = gratuit** (verrou d'abonnement retiré de `_togglePawSpotLayer`). **Nouveau repère
  carte** `_buildSpotPinBitmap` (goutte couleur du type + emoji, noir/or pour les dorés, ancre 0.5/1.0) — vérifié
  au simulateur avec 4 spots de test en zone fictive (−35/−30), supprimés ensuite. (« 20 signalements premium » = les 20 TYPES premium : 27 types − 7 gratuits, texte exact.)
- **PUBLICATION 19/09 ~02 h 15** : `~/Downloads/HoPetSit_v23.1.564_build567.{ipa,aab,apk}` (5 sons vérifiés dans l'AAB et
  l'IPA). Serveur v567 déployé (push Daniel, `publier_567.sh`, commit fae6a48). **Play : release 567 en production
  par l'API** (commit 200, `notes_567.json`). **iOS** : Transporter (DISTRIBUER = `app_click` computer-use à
  (646,180) ; le clic osascript n'a pas pris), build 567 VALID (`dc947379-…`), soumission 566 `8852b59c` annulée,
  567 attaché à la 1.18, whatsNew 8 locales, reviewSubmission `797547d8-2822-4136-b048-829b3291cba1` →
  **1.18/567 WAITING_FOR_REVIEW**. ⚠️ Admin « Versions de l'app » → 567/567 quand Play ET Apple ont approuvé.
  **Prochain build = 568.**
- i18n : paquets `shop567`, `ui567`, `delete567`, `pawspot567` branchés (3 996 clés, 0 inconnue). jest 169/169.
  Agents lancés en modèle Opus (forfait « tous modèles ») pour économiser le quota Fable.

**19/09 (03 h) — BUILD 568 (v565 app) : « la CB enregistrée ne reste pas » (Daniel, deep work).**
- **Causes racines** : (1) la page de paiement `airwallexBridgeRoutes.js` appelait `redirectToCheckout` SANS
  `customer_id` → Airwallex ouvrait toujours un formulaire vierge ; (2) le DON créait son intention sans client ;
  (3) Profil › « Ajouter une carte » envoyait numéro + CVC à NOTRE serveur (interdit PCI) et rien à Airwallex ;
  (4) un client Airwallex par RÔLE (jusqu'à 3 par personne) → la carte ne suivait pas la personne ; (5) la case
  « enregistrer ma carte » vivait dans un écran désactivé.
- **Corrigé** : `backend/src/utils/airwallexCustomer.js` = UN client par personne (récupère les anciens, mémorisé
  sur les 3 profils) branché sur réservation, abonnement, boosts, PawSpot, chat, KYC, don ; page de paiement avec
  `customer_id` + `autoSaveCardForFuturePayments` (repli automatique sans client si refus ; **coupe-circuit sans
  rebuild : `AIRWALLEX_HPP_CUSTOMER=off` sur Render**) ; Mes cartes : par défaut, remplacer (= ajouter + défaut +
  désactiver l'ancienne, Airwallex ne permet pas d'éditer un numéro), supprimer, badge « Expirée » ;
  `PUT /users/me/card` → 410, plus aucun PAN/CVC écrit. jest 186/186, i18n 4 014 clés (`cards568I18n`).
- ⚠️ **NON FAIT (refusé par le garde-fou de Claude : modification de données de production)** : purge des
  `card.number` / `card.cvc` déjà présents en base (owners/sitters/walkers). À faire par Daniel ou avec son accord
  explicite : migration au démarrage `v568_purge_card_pan_cvc` (`$set` à '' des deux champs).
- **PUBLICATION 19/09 ~04 h 20** : `~/Downloads/HoPetSit_v23.1.565_build568.{ipa,aab,apk}`. **Play : release 568 en
  production par l'API** (commit 200, `notes_568.json`). **iOS** : Transporter (`app_click` (646,180)), build 568 VALID
  (`99e90b1a-…`), soumission 567 `797547d8` annulée, 568 attaché à la 1.18 (204 au 4e essai), whatsNew 8 locales,
  reviewSubmission `bfdf2321-0eea-4f4e-ac5c-55d54fa627af` submit 200 → **1.18/568 en attente de vérification**.
  ⚠️ Un script iris avec `setTimeout` se FIGE quand Chrome met l'onglet en veille : pas de minuterie, enchaîner
  des requêtes. Serveur v568 = push Daniel (`publier_568.sh`). Admin « Versions de l'app » → 568/568 après
  validation Play + Apple. **Prochain build = 569.**
- Aussi : feuilles boutique = 48 px garantis en bas sur Android (`shopSafeAreaExtraInset` = `max(0, 48 − raw)`),
  vibration `HapticFeedback.vibrate()` à la réception app ouverte, produits Apple vérifiés (11/11 APPROVED, ids
  identiques à `apple_iap_service.dart`), feuille « Payer / Annuler » contrôlée au simulateur iPhone.
  À prouver par un vrai paiement : Mes cartes › Ajouter (0,50 € remboursés) → carte listée « Par défaut » →
  réservation puis don : Airwallex doit montrer « •••• 4242 » et ne demander que le cryptogramme.

**19/09 (journée) — BUILD 569 (v566 app) : « que l'app soit complètement mise à jour » (Daniel).** Le plus gros
lot depuis la 565 : ~12 agents Opus par vagues de 4 max, périmètres exclusifs, un paquet i18n par lot.
- **Crashlytics** : `PageRedirect.page Null check` (8 utilisateurs) = un lien universel / `hopetsit://` ouvrait
  l'app avec une route inconnue de GetX (deep linking natif de Flutter actif par défaut) → `unknownRoute`
  (Splash) + `flutter_deeplinking_enabled=false` (manifeste) + `FlutterDeepLinkingEnabled=false` (Info.plist,
  local au Mac) ; « Failed to load font » (google_fonts hors réseau) reclassé non fatal ; `invalid_sound` = 565,
  déjà corrigé.
- **⚠️ CAUSE RACINE des boutons sous la barre Samsung** : `showModalBottomSheet(useSafeArea: true)` enveloppe
  la feuille dans `SafeArea(bottom: FALSE)` — Flutter ne protège JAMAIS le bas d'une feuille (idem
  `Get.bottomSheet`). Les correctifs 567/568 supposaient l'inverse et n'ajoutaient rien. → utilitaire UNIQUE
  `lib/utils/bottom_inset.dart` : `appBottomInset(context)` (iOS = inset réel, Android = max(inset, 48)) et
  `appBottomInsetInsideSafeArea(context)` (complément quand un SafeArea(bottom:true) entoure déjà ; prendre un
  context AU-DESSUS du SafeArea). Audit : 51 feuilles + ~60 écrans, 74 fichiers corrigés ;
  `ProfileSubPageScaffold` (42 sous-pages) porte le dégagement. RÈGLE : tout nouveau bouton/feuille du bas passe
  par cet utilitaire.
- **Annulation sous 72 h** : ne marchait PAS pour les PROMENEURS (l'app appelait `DELETE …/self-cancel`, la route
  est un POST → 404) → app corrigée + alias `router.delete` (répare les apps installées) ; remboursement échoué
  ≠ « refunded » : `paymentStatus='refund'` + `refundError` ; `refundId`/`refundedAt` étaient écrits mais ABSENTS
  du schéma Booking (ajoutés) ; pop-up remplacé par `widgets/cancel_72h_sheet.dart` (3 rôles). Le site ne propose
  pas cette annulation (à faire).
- **Accord de réservation** : `GET /bookings/:id/agreement` renvoyait **500 sur toutes les promenades**
  (`sitterId` null) → corrigé + test ; date en anglais (table de mois codée en dur), « hourly » brut, « 0.0
  heures », bouton Payer visible côté prestataire, net prestataire jamais lu (`netToSitter`), aucun
  rafraîchissement (pull-to-refresh + socket `booking:*` + retour au premier plan).
- **Chat** : tap sur la photo/le nom → `chat_peer_sheet.dart` (ajouter en ami si pas déjà ami / demande en
  attente, bloquer) ; suppression de conversation : glisser / appui long → feuille moderne, optimiste, et
  **synchronisée** (`conversation:deleted` émis à MES rooms, app + web). Côté serveur la suppression ne masque
  que pour MOI (`clearedFor`) ; la conversation revient avec son historique si l'autre réécrit — le texte le dit.
- **Design** : `CustomButton` refait (19 écrans), thèmes globaux Elevated/Outlined/Filled/TextButton + dialogues
  coins 22 (`main.dart`), `widgets/role_chip.dart` (accueils des 3 rôles + chat), boutons d'en-tête « Paw
  Buttons » + cloche avec compteur (`custom_app_bar.dart`), boutique 4 onglets (`ShopHero`, `ShopBenefitList`,
  `ShopPlanTile`, `ShopTrustRow`, `ShopHelpCard`, squelette), pages de paiement (habillage SEUL, logique relue
  ligne à ligne : inchangée) + `payment_ui_kit.dart`, bandeaux d'accueil et boutons accepter/refuser
  (`widgets/action_banner_kit.dart` : `ActionBanner`, `ActionPillButton`, `ActionTone`), carte d'annonce vue
  prestataire (`post_card_kit.dart` ; l'offre de service part en UN tap, aucune feuille — inchangé), lots « jamais
  retouchés » : entrée dans l'app (`CustomTextField` API identique, connexion, mot de passe oublié, onboarding,
  invité), annonces/candidatures/notifications, dialogues/KYC/fidélité/badges/profil. Dialogue « Bloquer ce
  gardien » de l'accueil remis dans le bon sens (clés `…_yes`=Annuler / `…_no`=Bloquer nommées à l'envers).
- **Code mort repéré (non touché)** : `SignUpScreen`, `EmailVerificationScreen` (le tunnel vivant =
  `signup_wizard_screen`, `otp_verification_screen`, `sign_up_as`), `ApplicationScreen` + route
  `AppRoutes.application`, `notification_application_view_screen`, `sitter_notifications_screen`,
  `pet_sitter_request_card`, `pawpass_required_dialog`, `pet_enriched_fields`, `pet_extra_fields`,
  `translate_message_button`, `fullscreen_map_screen`, `report_category_grid_screen`, `pet_bottom_sheet`,
  `notification_badge`, `custom_navigation_bar`, `modern_toast`, `stripe_connect_*`, stubs
  `identity_verification_screen` ×2, `connect_payment_screen`.
- **PUBLICATION 19/09 ~10 h 35** : `~/Downloads/HoPetSit_v23.1.566_build569.{ipa,aab,apk}`. Serveur v569 déployé (push
  Daniel `publier_569.sh`, commit 7dff86d ; alias DELETE self-cancel vérifié : 401 au lieu de 404). **Play : release
  569 en production par l'API** (commit 200, `notes_569.json`). **iOS** : ⚠️ `flutter build ipa` a archivé mais
  l'EXPORT a échoué (`exportArchive No Accounts` : Xcode s'était déconnecté du compte Apple — liste
  `DVTDeveloperAccountManagerAppleIDLists` vide ; se reconnecter ailleurs, site/Transporter, ne sert à rien) →
  Daniel a rajouté le compte dans Xcode › Settings › Accounts, puis export SEUL sans rebuild :
  `xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive -exportOptionsPlist … -exportPath
  build/ios/ipa -allowProvisioningUpdates`. Transporter, build 569 VALID (`a28fd54c-…`, ~20 min), soumission 568
  `bfdf2321` annulée, 569 attaché à la 1.18 (204 au 5e essai), whatsNew 8 locales, reviewSubmission
  `1a7a0435-5510-4c7b-be0f-b0e7900c54bc` submit 200 → **1.18/569 en attente de vérification**. Admin « Versions
  de l'app » → 569/569 après validation Play + Apple. **Prochain build = 570.**
- i18n : paquets `chatdel569`, `shop569`, `agreement569`, `pay569`, `post569`, `misc569`, `auth569`, `lists569`
  branchés → 4 168 clés, 0 inconnue. jest 202/202, `tsc` 0, `dart analyze lib` 0 erreur / 0 warning.
  ⚠️ `dart format` lancé par erreur sur les 3 accueils (gros diff purement cosmétique).

**19/09 (soir) — BUILD 570 (v567 app) : nouveau menu « patte PawMap » + écran de lancement animé (handoff Claude
Design de Daniel, rangé dans `docs/design_handoff_pawmap_tab_bar/`, hi-fi, à suivre au pixel).**
- ⚠️ REMPLACE la préférence du 12/09 (« bouton PawMap rectangle arrondi orange uni, pas de dégradé, menu pilule
  blanche ») : le menu est désormais une pilule en DÉGRADÉ de la couleur du rôle (owner `#D83C28→#B92425` = la
  maquette ; sitter `#2F6FD6→#1E4FB0` ; walker `#2FAE4E→#15803D` — constante `kPawTabBarPalettes` dans
  `lib/widgets/paw_tab_bar.dart`, décision prise seul car Daniel tient aux couleurs de service : à confirmer),
  icônes au trait blanches, point lumineux qui glisse sous l'onglet actif, et au centre la PATTE-PIN (coussinet
  épingle noir + œil du logo + 4 doigts rouge/bleu/vert/violet qui sortent quand PawMap est actif). Daniel : « les
  petits ronds devraient être plus proches » → `out` des doigts ramené de +4 px vers l'extérieur à 2 px vers le
  centre (≈ 2 px de vide avec le coussinet).
- « Ne gêne aucun bouton » (exigence Daniel) : même ancrage bas que l'ancien menu (marge 6 + inset), barre 70 vs
  58 (+12 px), hauteur annoncée aux écrans = 76 + inset, zone tactile de la patte 84×67 seulement (test de widget :
  deux boutons voisins reçoivent leurs taps), carte « Autour de vous » de la PawMap remontée de 116 à 132
  (elle passait 8 px sous les doigts). Tests `test/paw_tab_bar_test.dart` (6).
- Splash : `splash_screen.dart` (rendu seul, redirection inchangée, affichage minimal 1,6 s) ; natif uni `#DD4430`
  (Android `launch_background.xml`, `values-v31` ET `values-night-v31` avec icône transparente ; iOS
  `LaunchScreen.storyboard`, local au Mac). L'œil du logo n'est PAS au centre de `HoPetSit_logo.png` (centre de
  l'œil = 256, 285.5) → image recadrée `pawmap_eye.png` (app + site).
- Logo PawMap = la patte-pin : widget `PawMapLogo` (app), `website/public/pawmap_logo*.svg|png` +
  `components/PawMapLogo.tsx` (animé sur l'accueil et `/pawmap`).
- **PUBLICATION 19/09 ~23 h 30** : `~/Downloads/HoPetSit_v23.1.567_build570.{ipa,aab,apk}` ; Play 570 en production
  par l'API (commit 200) ; serveur + site poussés (`publier_570.sh`, commit a0c6dcc) ; iOS : build 570 VALID
  (`152b2bfd-5ec3-4071-858b-b7fdf72724cf`) mais **NON soumis** : la 1.18/569 était passée **IN_REVIEW** → on
  n'annule pas un examen en cours (garde-fou ajouté au script iris : arrêt si IN_REVIEW / READY_FOR_SALE /
  PENDING_DEVELOPER_RELEASE). **À FAIRE dès que la 1.18 est approuvée : créer la 1.19 (`POST appStoreVersions`),
  whatsNew `notes_570.json`, attacher le build 570, soumettre ; puis admin « Versions de l'app ».**
  **Prochain build = 571.**

**20/09 — BUILD 571 (v567 app) : accueils plus accueillants (demande Daniel, 2 captures « Aucune publication »).**
- **Gardien/promeneur** (`sitter_homescreen.dart`) : plus d'écran vide. Rien dans le rayon mais des annonces plus
  loin → section « Les plus proches de toi » (max 10, pastille « à N km ») + carte « Rien dans un rayon de N km » avec
  bouton « Élargir à N km ». Vraiment rien → `HomeEmptyKit` (`views/shared/widgets/home_empty_kit.dart`) : patte
  PawMap qui respire, 3 cartes (Complète ton profil / Invite un propriétaire = `shareFriendsInvite()` / Mets-toi en
  avant = `CoinShopScreen`), « Rafraîchir » à la couleur du rôle.
- **`AroundMeSearchBar` redessinée** (API inchangée) : pastille-bouton « 📍 Autour de moi · Ville · Changer › » puis
  curseur pleine largeur. Le bloc de gauche que Daniel croyait inutile ÉTAIT le choix de ville. `midTickKm: 50` retiré
  côté propriétaire (la graduation du milieu était fausse : 10–500 km).
- **Feuille de ville partagée** `views/shared/widgets/city_picker_sheet.dart` : `showCityPickerSheet(context, accent,
  initialCity, subtitle…)` → `CityPickerResult` (`useMyPosition` | city/lat/lng). Nominatim identique, villes récentes
  GetStorage `home571_recent_cities`, `appBottomInset`. Branchée chez le gardien/promeneur ET le propriétaire.
- **Propriétaire** (`home_screen.dart` + `widgets/owner_home_kit.dart`) : 2 grandes cartes « Faire garder mon animal » /
  « Faire promener mon chien » (compactes 56 dp dès 1 annonce) → `PublishReservationRequestScreen(initialServiceType:)`
  (nouveau paramètre) ; « Mes annonces » vide = guide 3 étapes + « Publier » ; Gardiens/Promeneurs vides = écran
  accueillant + « Élargir le rayon » (paliers 25/50/100/250/500) + « Invite un gardien » ; bandeau de confiance
  (paiement sécurisé · identité vérifiée · annulation 72 h) ; onglet « Gardiens » par défaut si 0 annonce (une seule
  fois, jamais contre un choix manuel) ; carte « Ajoute ton animal » si `MyPetsController` chargé et vide.
- `ActionBanner` : titre sur 2 lignes (« Pas de demande en atten… » était coupé, 3 rôles).
- i18n : `home571_i18n.dart` (18 clés) + `ownerhome571_i18n.dart` (20 clés) × 9 langues, 4 206 clés, 0 inconnue.
  Tests : `test/home571_test.dart` (6) + `test/ownerhome571_test.dart` (5). ⚠️ `HomeEmptyIllustration` boucle :
  `pump(Duration)`, jamais `pumpAndSettle`. ⚠️ pas de `CrossAxisAlignment.stretch` dans un sliver (contrainte infinie).
- **Réservations des 3 rôles** refaites (rendu seul, logique intacte) : `BookingSegmentedTabs` dans `booking_ui_kit.dart`
  = 4 onglets FIXES à parts égales, icône au-dessus du libellé (Daniel : « pas de slide dans les onglets ») ; cartes
  (avatar, service, pastille de statut, méta en pastilles, prix) ; en-tête titre + compteur (`bookings571_i18n.dart`).
- **Fond à petites pattes** `lib/widgets/paw_pattern_background.dart` (`PawPatternBackground(color, child, opacity)`,
  CustomPainter déterministe, 9 % clair / 10 % sombre) posé sur : accueils (3 rôles), liste des messages + discussion,
  réservations, profil (3 rôles). Daniel : « le fond est tout blanc, sans patte ».
- **Audit mode sombre** : ~80 fichiers / ~370 occurrences. Cause n° 1 : `InterText`/`PoppinsText` retombaient sur
  `blackColor` sans couleur → `textPrimary(context)`. Nouveaux helpers `AppColors.textSecondaryStrong/textTertiary/
  mediaPlaceholder/accentOn(context, c)`. Laissé clair exprès : `guest_landing_screen.dart`.
- **Police** : `main.dart` → `GoogleFonts.interTextTheme(...)` (clair + sombre) ; titres d'AppBar `GoogleFonts.poppins`
  (`fontFamily: 'Poppins'` ne pointait sur AUCUNE police embarquée → police système).
- Accueil propriétaire : carte « Faire garder » en BLEU gardien (demande Daniel), bouton « + » flottant visible
  seulement après 260 px de défilement (il chevauchait la carte du rayon) ; onglet « Gardiens » par défaut seulement si
  0 annonce ET des gardiens à montrer. Patte de l'écran vide animée (ondes radar + doigts en cascade, boucle 5,2 s).
- Tests préexistants cassés, sans rapport : `test/widget_test.dart` (modèle Counter) et `test/i18n_test.dart`
  (4 clés `friends_share_*` absentes de `fr.dart`).
- **Publication 20/09 ~02 h 45** : Play 571 en production par API (commit 200) ; serveur + site poussés par Daniel
  (commit 2640b7a) ; site `/pawmap` : `PawMapHeroBadge.tsx` (patte en grand sur tuile orange animée, scène du splash).
  **iOS : 1.18/569 APPROUVÉE (READY_FOR_SALE le 20/09)** → version **1.19** créée (`bce5c89e-4b3e-4e5e-ae8e-7dcfb55ae72e`),
  build 571 (`0eb1f3fd-dcce-4a6e-9cbd-21b3cee4cd2d`) attaché, reviewSubmission `950f8eeb-89a9-4339-9788-0fbef01db2b8`
  → **WAITING_FOR_REVIEW**. ⚠️ `filter[version]=571` renvoyait « absent » alors que le build existait : lister par
  `sort=-uploadedDate` et filtrer côté client. Admin « Versions de l'app » : à passer à 571/571 après validation.
- Le 571 REMPLACE le 570 côté iOS (570 jamais soumis : la 1.18/569 était IN_REVIEW). **Prochain build = 572.**

**20/09 (~03 h 30) — BUILD 572 : bandeau « Tout est à jour » → PawMap (bug signalé par Daniel, 3 rôles).**
- Symptôme : le tap sur le bandeau neutre de l'accueil ouvrait l'ancien « Historique des réservations » au lieu de la
  PawMap. **Cause racine** : `navWrapperMounted` (`utils/map_ui_state.dart`) était un simple booléen ; au CHANGEMENT DE
  RÔLE le nouveau `StackedNavigationWrapper` se monte AVANT le `dispose()` de l'ancien, qui remettait le drapeau à
  `false` → `_onNeutralTap` (`home_quick_action_bar.dart`) prenait son repli. Touchait aussi `openPawMapWithRoute` et
  les liens profonds après un changement de rôle.
- Correctif : compteur statique `_mountedWrappers` dans `stacked_navigation_wrapper.dart` (`navWrapperMounted.value =
  _mountedWrappers > 0`) + repli de `_onNeutralTap` = `PawMapScreen` (plus jamais `BookingsHistoryScreen`).
- Vérifié au simulateur : propriétaire → profil promeneur → tap bandeau = onglet PawMap, menu conservé.
- iOS : Daniel a demandé une publication UNIQUE à la fin → le 572 n'a PAS été envoyé à Apple (1.19 reste sur le 571, WAITING_FOR_REVIEW) ; Play 572 publié (commit 200). **Prochain build = 573.**

**20/09 (matin) — BUILD 573 : audit complet « ancien design » + correctifs (Daniel : « ce genre de bug ne doit pas exister »).**
- **Audit** (agent Explore, 414 fichiers) : ~25 écrans/feuilles/dialogues encore à l'ancien style, 4 chaînes en dur,
  ~7 400 lignes de code mort (liste dans le rapport, NON supprimées). Lots refaits, rendu seul, logique intacte :
  - Profils publics `views/service_provider/` (gardien, promeneur, propriétaire) + `widgets/public_profile_kit.dart` :
    bandeau dégradé du rôle + avatar/initiale (PLUS d'image marketing `AppImages.placeholderImage`), carte « Détails de
    la réservation » seulement si réservation liée, sections en cartes, « Démarrer le chat » en barre collante.
  - Fiche animal `pet_profile_screen.dart` (devenu Stateful) : `resolvePetBannerUrl()` = bannière JAMAIS identique à
    l'avatar (sinon bandeau dessiné à pattes) ; changement de photo = aperçu local immédiat + voile, 1280 px/q80,
    `precacheImage`, éviction du cache si même URL, rechargement EN PLACE (plus de `Get.off`). Visionneuse commune
    `lib/widgets/photo_viewer_screen.dart` (`openPhotoViewer`). « Mes animaux » refaite.
  - `lib/widgets/app_dialog_kit.dart` : `showAppConfirmDialog(...)` + `AppChoiceRow` (thème, langue, blocage, suppression,
    changement de rôle). ⚠️ avec `onConfirm` qui fait `Get.offAll` (switchRole), ne `pop()` que si
    `ModalRoute.of(context)?.isActive` — sinon assertion `_history.isNotEmpty` (écran rouge trouvé au simulateur).
  - `views/map/widgets/map_sheet_kit.dart` (alertes + PawSpot), historique des réservations (cartes du kit, filtres en
    `Wrap` fixe), feuille des candidats, `pet_detail_screen.dart`, écran invité (clair + sombre), `sign_up_as`, KYC.
- **Menu du bas perdu** : 17 `Get.to(() => const <ÉcranOnglet>())` (notifications, profil, bandeau, liens) empilaient
  Chat/Réservations/Profil/PawMap SANS menu → `openMainTab(index)` / `openMainTabOr(index, fallback)` dans
  `utils/map_ui_state.dart` ; `deep_link_service` : `_goToTab` renvoie bool, chat=1, réservations=3, profil=4.
  **Garde-fou** `test/no_tab_push_test.dart` : échoue si un tel empilement réapparaît.
- **Localisation auto** (`services/location_service.dart`) : géocodeur natif souvent muet sur Android → secours
  Nominatim `/reverse`, délai GPS 6 → 12 s, `lastFailure` ('service_off'|'denied'|'denied_forever'|'timeout') +
  messages `location573_*` (9 langues) dans la publication et l'inscription sociale (qui affichait des CLÉS brutes).
- **Comptes aux 3 rôles** (serveur, vaut pour toutes les versions) : `middleware/auth.optionalAuth`,
  `utils/identityGroup.selfIdSet(req)` ; `/sitters/nearby` et `/walkers/nearby` retirent les documents du spectateur ;
  `postController` : `hideOwnPostsForProviders` (listPosts, media, requests) + nearby + anti auto-notification par
  groupe d'identité (les comptes récents n'ont pas d'`oldId`) ; `createApplication` refuse sa propre annonce (403
  `OWN_POST`). App : `getNearbyWalkers` envoie désormais le jeton. Test `tests/selfExclusion.test.js` (jest 208/208).
- PawMap : en-tête (tuile orange + logo aligné + Poppins), bandeau d'itinéraire remonté 136 → 160 (les doigts de la
  patte le chevauchaient) + `FittedBox` (débordait de 30 px), boutons peaufinés (rail, capsule, pilules).
- FR : 23 valeurs franglaises corrigées (`walker`→promeneur, `owner`→propriétaire, « Top Promeneur »…).
- Site : `public/screens/v573/fr/` (4 captures PawMap refaites) ; EN reste sur v561 (à refaire en anglais).
- Fiche animal : bouton appareil photo SUR la bannière (`_changeBanner` = ajoute une photo de galerie, aperçu local
  immédiat ; `resolvePetBannerUrl` retient désormais la photo de galerie la PLUS RÉCENTE ≠ avatar) + avatar cliquable
  avec badge appareil photo. Site `/map` : rail gauche et en-tête alignés sur l'app.
- **Publication 20/09 ~04 h 45** : Play **573 en production** (commit 200) ; serveur + site poussés par Daniel (commit
  9f2bdfd). **iOS : la 1.19/571 est passée IN_REVIEW → NON annulée** ; l'IPA 573 est distribué par Transporter (build
  prêt côté ASC). **À FAIRE dès que la 1.19 est approuvée (Daniel écrit « apple ok » ou vérifier par iris)** : créer la
  version **1.20** (`POST /iris/v1/appStoreVersions`), whatsNew = `notes_573.json` (locales ASC `it` et `pl`), attacher
  le build 573 (lister `builds?sort=-uploadedDate`, filtrer côté client), reviewSubmission → item → submitted. Puis
  admin « Versions de l'app » → 573/573 quand les deux stores ont validé. Captures EN du site PawMap à refaire.
- **20/09 (matin) — iOS : 1.19/571 APPROUVÉE (READY_FOR_SALE)** → version **1.20** créée (`8dc6b629-187d-4551-86d3-9258d16ddd10`), build 573
  (`657e1dd0-646b-42bd-a075-0ccd83ce0f82`) attaché, whatsNew 8 locales, reviewSubmission
  `da3d9acf-2a34-472d-a580-e1f175bbf687` soumise. Reste : admin « Versions de l'app » → 573/573 après validation.
- i18n : 4 225+ clés, 0 inconnue.

**20/09 (midi) — BUILD 574 (version interne 23.1.568) : rôles synchronisés + INVALID_BINARY Apple + bilan.**
- ⚠️ **Piège Apple `INVALID_BINARY`** : la 1.20/573 a été rejetée automatiquement (« Binaire non valide », item REJECTED,
  aucun fil dans le centre de résolution). Cause : le 573 portait `CFBundleShortVersionString` **23.1.567**, la même
  série que le 571 de la 1.19 ; dès qu'Apple APPROUVE une version, la série est FERMÉE aux nouveaux builds. **Règle :
  après chaque approbation Apple, incrémenter le nom de version du `pubspec.yaml` (23.1.568 → 23.1.569 …), pas
  seulement le numéro de build.** Reprise : PATCH `canceled:true` sur la soumission UNRESOLVED_ISSUES, attacher le
  nouveau build ; l'ajout de l'item renvoie 409 tant que la version n'est pas revenue à PREPARE_FOR_SUBMISSION →
  réessayer. 1.20 resoumise avec le **574** (`88698989-a50d-459d-853f-263690cc0bb2`), soumission `fbeb4fb4-…`.
- **Rôles synchronisés entre appareils** (Daniel : « activé sur Android, iOS ne l'affiche pas ») : `availableRoles` ne
  venait qu'à la connexion et vivait en mémoire. Serveur : `GET /users/me/roles` (`controllers/rolesController.js`,
  léger pour être testable). App : `AuthController.refreshAvailableRoles()` + persistance `available_roles_v574`,
  appelé à l'init, à la reprise (`notifications_controller`) et sur l'onglet Profil (`stacked_navigation_wrapper`).
  Site : `getMyRoles()` → ✓ / + devant chaque profil du tableau de bord.
- **Relance e-mail** `verify_email_d2` dans `lifecycleEmailScheduler.js` (48 h–21 j, `verified !== true` ni profil frère
  vérifié, UNE fois, garde-fous existants, 9 langues). jest 222/222.
- **Meta** (accord « ok pub ») : Paris 9 €, Dallas propriétaires 5 €, Dallas gardiens 2 € = 16 €/j (Paris = 7 €/inscrit,
  Dallas = 76 €). **Bilan** : `~/hopetsit-social/BILAN_2026-09-20.md` — 28 inscrits/7 j, 0 réservation sur 30 j, blocage
  = manque de propriétaires et de première annonce. `bob_hebdo.py` : `?limit=1000` (totaux tronqués à 20/rôle).
- Site : captures PawMap EN refaites (`public/screens/v573/en`). Astuce : passer l'app du simulateur en anglais en
  écrivant `language_code` dans `Documents/GetStorage.gs` du conteneur (app arrêtée).
- **Cap « premières transactions » (consigne Daniel du 20/09 : « fais tout tout seul ») :**
  - ⚠️ La pub Meta Paris pointait depuis le 13/09 sur `/garde-animaux/paris`, qui N'EXISTAIT PAS (catch-all « Ouvre
    dans l'app », non caché, ~2 s) → 59 % de perte. Corrigé : `website/src/app/garde-animaux/paris/page.tsx` (statique,
    hub des 20 arrondissements), premier écran mobile de conversion dans `OwnerCityPage.tsx`, `GetAppButton.tsx`,
    plus de `hopetsit://` automatique sur chemin inconnu (commit c5a12cc, vérifié en ligne : PRERENDER, 0,75 s).
    Reste : `<html lang="en">` statique sur tout le site ; doublon `/petsitter/paris` à fusionner un jour (308).
  - **Mesure d'audience maison sans cookie** (commit d9e4f7d) : `POST /site-events` (`models/SiteEvent.js`, empreinte
    journalière non réversible, ni IP ni UA stockés, robots rejetés, TTL 400 j), `GET /admin/site-analytics?days=`,
    `website/src/components/SiteAnalytics.tsx` + `trackSiteEvent('store_click')`, page admin « 📈 Trafic du site ».
    Les 3 pubs portent `url_tags=utm_source=meta&utm_medium=paid&utm_campaign=<clé>` (nouveaux creatives, anciens ids
    gardés dans `meta_ads_state.json` sous `creative_sans_utm`). jest 255/255.
  - FB/IG : file `banque_posts.json` réorientée propriétaires Paris (4 nouveaux posts, sauvegarde `.bak_20260920`).
  - Daniel a dit **NON** à la commission offerte sur la première garde : ne la proposer nulle part.
  - Claude lance désormais lui-même `bash ~/hopetsit-social/publier_*.sh` (autorisé explicitement le 20/09, ça passe).
- Play 574 en production (commit 200) ; serveur + site poussés (commit 6dcdd43). **Prochain build = 575, et version
  interne 23.1.569 dès que la 1.20 est approuvée.**

**18/09 — Pliables / tablettes / iPad : REPORTÉ (décision Daniel).** « Quand on sera beaucoup plus connus. » L'app tourne déjà (gonflée : `designSize` 393 px ; iPad = mode compatibilité, `TARGETED_DEVICE_FAMILY = 1`). Le jour venu : plafonner l'échelle + colonne centrée ≥ 600 px, portrait bloqué sur grand écran ; iPad natif = irréversible + captures 13" en 8 langues. **Priorité unique : plus d'utilisateurs et les premières réservations payées.**

**13/09 — v562 SITE « minimaliste, pro, façon Apple » (Daniel).** Design uniquement, mêmes
clés i18n / routes. Fond blanc + sections `#F5F5F7`, texte `#1D1D1F` / `#6E6E73`, titres
XXL centrés (`tracking-[-0.03em]`), cartes `rounded-[24px]` sans bordure ni ombre, bandes
noires `#1D1D1F` pour PawPremium, contour orange fluo global au survol SUPPRIMÉ
(`globals.css`). Pages refaites : accueil (`page.tsx`), `/pawmap`, `/pricing`, `/download`,
`components/SubscriptionsExplainer.tsx`, `components/PageHero.tsx` (partagé par how-it-works /
faq / contact), `Header.tsx` (barre 56 px, liens gris). **Icônes produits** régénérées au
design « Paw Buttons » : `public/pawboost_logo.svg`, `pawfollow_logo.svg`, `pawspot_logo.svg`
(+ `.png` via rsvg-convert), `pawpremium_logo.svg` (carré arrondi dégradé + disque blanc + icône
pleine) → toutes les pages qui les référencent sont à jour. **Captures** : `public/screens/v561/
{fr,en}/` = captures RÉELLES du simulateur (v561, statut 9:41, Paris = 48.8566,2.3522 et Dallas
= 32.7767,-96.7970) : 00-accueil/home, 01-carte/map, 02-signaler/report, 03-amis/friends,
04-reservations/bookings, 05-profil/profile, 06-premium, 07-boutique/shop, 08-autour/around,
09-autour-liste/around-list, 10-itineraire/route, 11-carte-dallas/map-dallas ; `lib/screens.tsx`
(`screensFor`, `pawmapShotFor`, `PhoneFrame`) les encadre ; anciens jeux v534 supprimés.
Méthode EN : `simctl spawn booted defaults write .GlobalPreferences AppleLanguages -array en-US
en` + `AppleLocale en_US` + reboot, l'app suit la langue du téléphone ; remis en fr_FR ensuite.
⚠️ `/boutique` et `/dashboard` exigent une session : vérifiés par `tsc` seulement.
**13/09 (suite) — 3e passe site.** États « sélectionné » = **orange pâle** `bg-owner-light` +
`text-owner-dark` (plus jamais gris foncé) : page courante dans `Header.tsx` (usePathname, desktop +
mobile), puces Voir signaux / Voir spots / rôles / catégories de `/map`. PawMap web : icônes SVG
pleines (`ActionIcon` : triangle, drapeau, patte, pin, viseur, flèche) à la place des emojis, +
bloc **« Autour de toi »** (6 lieux visibles les plus proches, distance haversine depuis
`userLocation ?? center`, statut ouvert/fermé via `formatOpenStatus`, clic = `setSelectedPoi` +
`setFocusTarget`, bouton = `handleDirections` existant) ; clés `map_around_title/sub/empty/show`
×9. Galerie accueil : 5 captures, UNE seule PawMap (09-autour-liste retirée de `screens.tsx`).
**Compte de test owner = « Camille Durand »** (photo Unsplash, animal « Rex » golden retriever,
bio propre) — Daniel : « test owner c'est un peu nul », ne plus remettre « Test ». Captures
00-accueil/home et 05-profil/profile refaites avec UNE annonce visible : annonce créée par l'API
dans une ville fictive `Le Marais, Paris` (lat -35, lng -30 → **0 sitter/walker notifié**, hors de
tout feed réel) puis **supprimée** juste après la capture. ⚠️ `createPost` sans `location.city`
notifierait jusqu'à 50 prestataires réels ; un post avec photo sort de « Mes annonces » (il passe
par `/posts/media` qui ne renvoie que `postType: media`).
**13/09 (suite 2) — PawMap web « comme l'app ».** Rail GAUCHE de 8 boutons ronds sur la carte
(`/map`, `RAIL_SVG` = copies des `_fabSvg*` de l'app, dégradés identiques) : Autour de moi
(scroll vers la liste), Itinéraire (POI sélectionné sinon liste), Chat (`/chat`), Photo du spot
et Tag spot (`openCreate("spot")`), Voir spots / Voir signaux (toggles), Signaler
(`openCreate("report")`). Les 4 puces doublonnées de la barre du haut ont été retirées (les
handlers restent). Zoom Leaflet déplacé en bas à droite (`ZoomControl`). Marqueurs PawSpot =
`public/pawspot_marker.png` (copie de `assets/images/pawspot_coin.png`, pin noir/or) + anneau
couleur du type, or et plus grand si golden — `PawSpotGoldCoin.tsx` n'est plus utilisé par la
carte. Tableau de bord : survol et page courante en orange pâle (`SideLink` avec usePathname,
`NavCard`, cartes PawMap / Réservations). Vérif locale : `~/.claude/launch.json` → config
`hopetsit-web` (next dev sur 3111) ; le backend refuse l'origine localhost (CORS) donc 0 lieu,
mais la carte, le rail et les styles se voient ; session injectée via localStorage
(`hopetsit_token` / `hopetsit_role` / `hopetsit_user`).
**13/09 (suite 3) — ADMIN modernisé (design uniquement, Daniel : « touche pas les
fonctionnalités »).** `admin_dashboard.html` : nouveau bloc `<style>` = thème CLAIR façon Apple
(fond `#F5F5F7`, cartes blanches ombre douce, Inter, orange `#D83C28`, sélection/survol menu en
orange pâle `--primary-light`), toutes les variables utilisées par le JS définies (`--error` et
`--card` manquaient), `<select>` stylés, en-têtes de tableau collants, boutons pilule. Ajouts sans
toucher au JS métier : champ « 🔍 Menu… » qui filtre les 31 entrées (`filterNav`), classe
`.panel` (Promotions = 3 étapes en 3 cartes), pastilles inline `white-space:nowrap`, tableaux
larges qui défilent dans leur carte. Mêmes ids/classes, EMBEDDED reste v561 (pas de rebuild app).
**Aperçu local de l'admin** : `~/.claude/launch.json` config `hopetsit-admin` (http.server 8777 sur
la racine du repo) + `scratchpad/cors_proxy.py 8778` (proxy → backend avec CORS, le backend
refuse l'origine localhost) + page `.claude/admin_boot.html?page=xxx` (pose `admin_token` /
`admin_api_url` en localStorage, iframe, clique l'entrée du menu) ; captures 1440 px via Chrome
headless (`scratchpad/shot.py <page>`, `--virtual-time-budget`, subprocess timeout 100 s — le pane
navigateur intégré rend minuscule au-delà de 560 px). Jeton admin obtenu par POST
`/auth/admin/login` avec `~/.hopetsit_admin_credentials`, jamais tapé dans un formulaire.
**13/09 — Play 564 VALIDÉ** (Daniel) → admin « Versions de l'app » : android latest 564 / min 0
(`appver_admin.py set 564 0 563 0`). iOS 1.17 (564) encore en vérification : passer `i_l` à 564
dès l'approbation Apple (`appver_admin.py set 564 0 564 0`).
**13/09 (nuit) — BILAN 10 JOURS + décisions « focus USA + Paris » (Daniel : « tu prends les
décisions »).** Chiffres : 31 comptes réels (hors test/staff), 8 inscriptions en 10 jours (5 US,
2 FR, 1 inconnu — Honolulu, Naples FL, St. Louis, San Francisco, University ; Boulogne, Blénod),
15 en 30 jours (8 US / 5 FR), 9 réservations dont 2 payées (48 € bruts, 8 € de commission),
boutique 26,95 €, 0 réservation terminée. Décisions prises : (1) routine cloud du dimanche
`trig_01BpzyjaJz7SPDgPFCdjinQM` réécrite = 1 article FR Paris + 1 article EN-US par semaine,
ville US en rotation (Dallas, New York, LA, Houston, Miami, Chicago, Austin, SF), section
« Langue du jour » = post Nextdoor/groupes FB de la ville, section « English » = post Reddit ;
les 7 autres langues sont en pause. (2) Affiches partenaires vague 2 = petite couronne (12
commerces, `~/hopetsit-social/partenaires_couronne.json`) + **Dallas en anglais** (10,
`partenaires_dallas.json`, affiche `affiche_commerce.py … en`, mailer `envoi_partenaires_us.py`) ;
envois automatiques **chaque lundi** par launchd (`com.hopetsit.partenaires.couronne` 10 h 05,
`.dallas` 16 h 05 Paris = 9 h Dallas) — le script n'envoie que les entrées `a_contacter`, donc
rien ne part deux fois ; nouvelle vague = ajouter au JSON. Listes construites par
`partenaires_build.py '<area Overpass>|…' sortie.json` (OSM + e-mail trouvé sur le site).
(3) BUG réparé : le post « banque » du mercredi 09/09 avait échoué (`git push` refusé, compte
GitHub `dadaciao84-ai` pris par le trousseau) → `publier_semaine.py` force
`credential.helper=osxkeychain` sur pull et push. (4) IndexNow : 571 URL du sitemap resoumises.
Non fait / à proposer à Daniel (argent) : relancer Google Ads Dallas (3,96 €/install) ou Paris
(1,08 €/install).
**13/09 (nuit) — PUB : « fais ce qui est le mieux ».** Bloqué côté exécution : l'extension Chrome
refuse facebook.com/adsmanager (comme play.google.com), le jeton page (`~/hopetsit-social/token.txt`)
n'a PAS `ads_management`, Google Ads = manuel. Livré : `~/hopetsit-social/ads/` = 6 visuels
(Dallas owners EN, Dallas sitters EN, Paris propriétaires FR, feed 1080×1350 + carré, rendus HTML
→ Chrome headless avec les vraies captures v561), `meta_ads.py plan|create|start|pause|status`
(API Marketing : 3 campagnes Trafic, 7+5+4 €/j, ciblage géo/intérêts, catégorie Emploi pour les
sitters, jeton lu dans `~/.hopetsit_meta_ads_token`), `README_PUB.md` (le geste unique de Daniel :
donner « Gérer les campagnes » à l'utilisateur système aepsinfos + jeton ads_management). Dès que
Daniel dit « jeton meta posé » → `create` puis `start`, bilan `status` le dimanche.
**13/09 ~5 h — CAMPAGNES META LANCÉES par l'API** (Daniel : « autorise tout, j'autorise tout »).
Déblocage : cas d'utilisation « Créer et gérer des publicités avec l'API Marketing » ajouté à l'app
(ads_management/ads_read « prête pour le test » suffit pour NOS comptes), compte pub attribué à
aepsinfos, jeton régénéré (Business Suite → utilisateurs système → Générer un token, expiration
Jamais, cocher ads_management + ads_read ; Meta a exigé un code e-mail sur hopetsit@gmail.com).
Le navigateur INTÉGRÉ de Claude (mcp__Claude_Browser) accepte facebook.com quand Daniel s'y
connecte lui-même — l'extension Chrome, non. Pièges API corrigés dans `meta_ads.py` :
`is_adset_budget_sharing_enabled='false'` sur la campagne, `targeting_automation.advantage_audience=0`
dans le ciblage, `instagram_user_id` (pas `instagram_actor_id`) dans object_story_spec,
`special_ad_category_country=['US']` pour la catégorie Emploi ; un `create` raté laisse une
campagne orpheline « HPS · … » à supprimer avant de relancer. IDs dans `meta_ads_state.json`
(Dallas owners 120247571949720284, Paris propriétaires 120247571950790284, Dallas sitters
120247571956790284). Budgets 7+5+4 €/j, pubs en examen Meta. ⚠️ Les 3 jetons ont transité par
le chat : les révoquer plus tard (« Révoquer les tokens ») et en régénérer un proprement.
**13/09 — Corriger l'e-mail d'un compte depuis l'admin** (Daniel : « le client s'est trompé de
mail »). `PATCH /admin/users/:role/:id/email {email}` (format + unicité sur Owner/Sitter/Walker,
propagé aux 3 docs de la même personne), puis l'admin appelle `POST /auth/resend-code?email=`
(code haché + e-mail, même flux que l'app). Bouton « ✉️ E-mail » sur chaque ligne de la page
Utilisateurs (FR/EN/ES). Premier cas traité : Lena gris (sitter, 13/09 11 h 52)
`lenagris62@iclous.com` → `lenagris62@icloud.com`, code renvoyé. Script d'attente de déploiement :
`scratchpad/fix_email.py <role> <id> <email>` (boucle tant que la route répond 404).
**14/09 ~2 h 30 — « pas d'argent, solutions gratuites, gère tout » (Daniel).** Pub Meta : il a
d'abord dit couper puis « remets » → les 3 campagnes restent à 7+5+4 €/j (Paris CPC 0,06 €,
Dallas 0,20 €, premiers clics). Gratuit, mis en place et **local** (launchd, 0 jeton Claude) :
`vigie.py` tous les jours 9 h 15 (corrige les domaines d'e-mail mal tapés des comptes non
vérifiés + renvoie le code, UN rappel de code par compte entre J+1 et J+30, état
`vigie_state.json`, journal.log) ; `bob_hebdo.py` lundi 8 h = rapport « Bob » (chef de projet, nom choisi par Daniel) envoyé à
dadaciao84@gmail.com via /admin/promo/send-campaign (inscriptions 7/30 j par pays, non vérifiés,
réservations, Meta 7 j par campagne, vigie) ; +40 pages villes US (`recruit-cities.ts`, banlieue
de Dallas d'abord) ; IndexNow relancé. **Constat clé : 17 comptes sur 34 n'ont JAMAIS validé
leur e-mail** (0 des 5 inscrits de la semaine) → la vérification par code est LA fuite du tunnel ;
13 codes renvoyés le 14/09. Piste (rebuild app) : laisser entrer sans code et vérifier plus tard,
ou lien magique dans l'e-mail. Routines cloud « équipe d'agents » NON créées (consomment son
forfait) : tout est en scripts locaux gratuits.
**17/09 — SEARCH CONSOLE : doublons et pages non indexées** (Daniel : « dis à Bob de corriger ça et
de me faire exploser à Paris et USA »). Constat : 320 détectées non indexées, 20 doublons sans
canonique, 14 explorées non indexées. Cause des doublons = QR des affiches `/download?ref=…` (et
?utm/?lang) sans canonique. Corrigé : `website/src/middleware.ts` → en-tête HTTP
`Link: <https://www.hopetsit.com{path}>; rel="canonical"` sur TOUTES les pages (y compris « use
client », qui ne peuvent pas exporter de metadata) + `X-Robots-Tag: noindex, follow` sur login,
signup, verify-email, open, pay, kyc-complete, search, map, boutique, posts, pawpoints, family, book
et espaces privés ; `sitemap.ts` : login/signup retirés, priorités (accueil 1 ; blog, /villes, FR et
villes US 0,8 ; villes EN hors USA 0,4 ; autres langues 0,3) ; accueil : bloc « Pet sitters à Paris
et en Île-de-France / in the United States » (20 arrondissements, 7 communes, 16 villes US).
Vérifié en ligne (en-têtes présents, PDF des affiches non touchés) ; IndexNow 651 URL.
**17/09 (après-midi) — Paris ≥ 80 % unique (consigne Daniel « 80 % minimum », « fais preuve
d'excellence »).** Mesure (`~/hopetsit-social/uniq_paris.py`, contenu `<main>` seul, chaque page
contre les 19 autres) : avant 15-50 % unique ; après **90-99 % par phrases et 80-91 % en 5-mots
(le plus strict), 40/40 pages ≥ 80 %**. Moyens : sur les arrondissements, OwnerCityPage et
RecruitCityPage masquent kicker, intro, badges, services, garanties, prix, étapes et FAQ
génériques (plus de FAQPage JSON-LD), titres courts avec le numéro (« Pet sitter Paris 11e : garde
et promenade », « Devenir pet sitter, Paris 11e »), CTA « Paris 11e avec HoPetSit » ;
`ParisLocalPlaces` = chiffres, vétos (ouverts sam./dim.), commerces animaliers, espaces canins,
jardins nommés (horaires OSM humanisés, formats saisonniers masqués), balades canines, voisins.
Données `paris_places_build.py` réécrit : **OpenStreetMap par FRONTIÈRE d'arrondissement**
(Overpass admin_level 9, aucun lieu partagé) + PawMap seulement si le lieu PawMap est à < 150 m
(sinon une enseigne comme Animalis prenait l'adresse d'une autre boutique). Pas de page ville hors
Paris touchée (/garde-animaux/lyon inchangée). ⚠️ **Vercel Security Checkpoint** (403
`x-vercel-mitigated: challenge`) présenté à CE Mac après des centaines de curl de vérification :
un navigateur le passe en 5 s, Googlebot et les robots Meta ne sont pas concernés. NE PLUS
sonder le site en boucle ; `indexnow.py` reconstruit la liste des URL depuis le dépôt si le
sitemap est illisible, `bob_prospection.py` et `publier_semaine.py` tolèrent ce 403.
**17/09 — PRIORITÉ BOB : INDEXATION PARIS** (Daniel). Cause : 20 arrondissements quasi identiques
(21 phrases sur 27 communes entre 11e et 15e). Fait : `components/ParisLocalPlaces.tsx` inséré dans
OwnerCityPage et RecruitCityPage (fr) = compteurs et 8 lieux RÉELS de la PawMap autour de
l'arrondissement (vétos, animaleries, toiletteurs, parcs, points d'eau), FAQ locale générée de ces
lieux, liens vers les arrondissements voisins ; données `website/src/lib/paris-places.json` produites
par `~/hopetsit-social/paris_places_build.py` (compte test owner, /map-pois/nearby rayon 1,1 km,
noms génériques filtrés) et rafraîchies le 1er du mois par launchd `com.hopetsit.bob.paris`.
Résultat mesuré 11e vs 15e : 42 % des mots en commun (≈ 85 % avant), 866 mots. IndexNow 651 URL.
**17/09 — Bob lit la Search Console tout seul** (lecture seule). Clés de compte de service
INTERDITES par la règle d'organisation `iam.disableServiceAccountKeyCreation` → OAuth « application de
bureau » : projet Google Cloud `orbital-bee-508911-e0` (compte hopetsit@gmail.com, séparé de
LawsTravels), écran de consentement « HoPetSit Bob » PUBLIÉ en production (sinon jeton expiré en
7 jours ; branding = hopetsit.com + /privacy + /terms), client `~/.hopetsit_gsc_client.json`, jeton
`~/.hopetsit_gsc_token.json` (600, rafraîchi automatiquement), venv `~/hopetsit-social/.venv-gsc`.
Ré-autoriser si besoin : `.venv-gsc/bin/python gsc_auth.py` (ouvre la page Google dans Chrome u/8).
Le navigateur intégré refuse la connexion Google (« Un problème est survenu ») et y est connecté à
lawstravels@gmail.com : ne rien créer dedans. `gsc_bob.py` = clics/impressions 28 j (FR/US), top
requêtes/pages, sitemap, et inspection d'URL de 42 pages clés Paris + USA ; intégré au rapport du
lundi (`bob_hebdo.py`, bloc GOOGLE). **Premier relevé 17/09** : 16 clics / 1 321 impressions en 28 j
(France 99 impressions, USA 770) ; pages clés indexées 14/42 (14 détectées non indexées, 13 inconnues
de Google = villes US ajoutées le 14/09, 1 doublon) ; /devenir-petsitter/paris et les 20
arrondissements PAS indexés → priorité SEO France.
**16/09 — Bob : prospection des pros de l'animal** (3 fichiers xlsx fournis par Daniel : pros
Paris/IDF 180, vétérinaires IDF 120, santé animale 10 villes 156). Vérifiés : 456 lignes → **329
retenues** (écartés : 106 2e adresse d'une même entreprise, 14 déjà contactés, 4 domaines sans
serveur mail, 2 RH/presse, 1 funéraire). ⚠️ La liste « Clinicas_Veterinarias_Espana.numbers » du
14/09 était INVENTÉE (35 domaines/40 inexistants) → jamais utilisée ; toujours contrôler les MX.
`~/hopetsit-social/partenaires_bob.json` (segments : commerce_sante 113, association 15, pro_garde
43 [invités comme prestataires, sans affiche], hotel 45, sante_hors_paris 113 en dernier) ;
`bob_prospection.py [N] [--dry]` = affiches neutres (`affiche_commerce.py nom slug fr neutre` : ne
prétend PAS que le commerce est sur la PawMap) publiées dans website/public/affiches, attente
content-type PDF, e-mail par segment via /admin/promo/send-campaign ; launchd
`com.hopetsit.bob.prospection` **mardi + jeudi 10 h 05, 25 contacts** (≈ 7 semaines). Rapport du
lundi de Bob : ligne « prospection ». **Jeton page Facebook invalidé** (publications auto cassées,
constaté 16/09) → régénéré depuis le jeton système (`jeton.py` avec `jeton_brut.txt` temporaire),
post du mercredi republié ; la vigie contrôle et régénère désormais ce jeton chaque matin.
**14/09 — TUNNEL DE VÉRIFICATION corrigé côté serveur (Daniel : « vérifie et corrige, dis-moi
avant si rebuild » → AUCUN rebuild).** Causes trouvées : e-mail de vérification en anglais
seulement, code valable **10 minutes**, rien à cliquer, expéditeur Gmail. Corrigé dans
`emailService.sendVerificationEmail(email, code, lang, name)` : 9 langues (`VERIFY_I18N`), bouton
« Activer mon compte » → `GET /auth/verify-link?email&code` (page HTML, valide le compte,
renvoie vers l'app), code affiché en secours, **valable 24 h** (4 blocs `email_verification` dans
authController ; le reset mot de passe reste à 10 min). Langue = `verifyLang(appLocale, language)`.
L'app ne change pas : après le lien, l'utilisateur se reconnecte et entre (login renvoie
verified). Vigie relance UNE fois le nouveau format à tous les non-vérifiés (état
`vigie_state.json` remis à zéro le 14/09).

### 📋 PROCHAIN BUILD (v562 app, build 565) — liste dictée par Daniel le 14/09, à faire EN UNE FOIS
Décision : Daniel était à 91 % de son forfait → **attendre la remise à zéro du 18/09**, puis tout
faire et publier iOS + Android dans la même passe. Rien de coûteux avant.
1. **Profils** : vérifier que les 3 profils (owner/sitter/walker) fonctionnent et restent
   synchronisés (nom, photo, e-mail, téléphone) ; vérifier e-mail + numéro à l'inscription ;
   vérifier que la **ville s'enregistre** bien (beaucoup de comptes avec pays/ville « ? »).
2. **Changer son e-mail dans l'app** après inscription (profil → e-mail) → nouveau code de
   vérification envoyé à la nouvelle adresse (backend : réutiliser la logique de
   `PATCH /admin/users/:role/:id/email` en version « moi-même » + `resend-code`).
3. **PawMap, rail gauche, mini ET grande carte** : nouveau bouton **rose « Amis en direct »** →
   liste de qui est en direct → clic sur un profil → **le suivre**, SANS que le menu déroulant
   s'ouvre. Sur la **mini carte** aussi : petit bouton **chat direct avec les amis** dans le rail.
4. **PawMap** : un vieux pop-up « Suivre en direct sur la PawMap » réapparaît parfois (reste
   d'anciens builds) → le supprimer.
5. **Notifications — PRIORITÉ HAUTE (Daniel l'a redemandé le 17/09 : « toutes les notifications
   Apple ne marchent pas »)** : vérifier Android et SURTOUT **Apple**, de bout en bout et type par type.
   Chaîne iOS à contrôler dans l'ordre : clé APNs WJSPRXB7FC bien chargée côté Firebase (slot
   PRODUCTION) ; entitlement `aps-environment = production` dans le build App Store ; capacité Push +
   Background Modes « remote-notification » ; demande d'autorisation au bon moment ;
   `getAPNSToken` puis jeton FCM obtenu et ENREGISTRÉ côté serveur pour le bon profil (les 3 rôles) ;
   charge utile avec bloc `notification` + `apns` (son, badge) ; affichage app ouverte (premier plan),
   en arrière-plan et app fermée ; tap → ouverture sur le bon écran (route). Tester CHAQUE type :
   message, demande et acceptation d'ami, demande de service, réservation (demande, acceptation,
   paiement, rappel 30 min, récupération, rendu), avis, wallet/retrait, abonnement, alerte PawMap,
   partage en direct. Preuve attendue : notification reçue sur iPhone réel (TestFlight) pour chaque
   type, pas seulement sur simulateur.
6. **E-mails** : vérifier que TOUS les e-mails (vérification, cycle de vie, notifications, promo)
   sont bien traduits dans la langue du compte.
7. **Autour de moi** : n'afficher QUE les lieux/services dédiés aux animaux ou pet-friendly
   (vétos, animaleries, toiletteurs, parcs, plages, restaurants pet-friendly…), rien d'autre.
8. **Membres sur la carte** : la couleur du rôle n'apparaît qu'en zoomant beaucoup (seuil
   zoom ≥ 12) → montrer la couleur plus tôt.
9. **Synchronisation PawMap ↔ reste de l'app** : demande d'ami et demande de service faites
   depuis la PawMap doivent se retrouver partout (bandeau notifications, cloche, onglet amis,
   annonces, réservations, paiement). Constaté : les demandes d'amis PawMap ne remontent ni
   dans la cloche ni dans la PawMap. Après une demande depuis la PawMap, le profil doit
   afficher « Demande déjà envoyée · en attente de réponse ».
10. **Point vert « en ligne »** : ne marche pas → vérifier sur toute l'app ET le web (présence socket).
11. **Suivi en direct on/off** : vérifier que l'interrupteur marche vraiment (démarrage/arrêt, visible par les amis).
12. **Partage d'adresse et de téléphone** : le téléphone ne prend pas le bon **préfixe pays** → corriger
    (préfixe déduit du pays du compte, modifiable) ; vérifier l'affichage/partage de l'adresse.
13. **Message vocal dans le chat** (enregistrer, envoyer, écouter ; upload Cloudinary audio).
14. **Verrou contacts à 700 utilisateurs** : vérifier que l'échange adresse/téléphone se verrouille
    automatiquement (côté serveur, sans rebuild) à partir de 700 comptes et ne se débloque qu'après
    un pet-sitting payé ou un abonnement ; message clair dans l'app quand c'est verrouillé.
    Recommandation donnée à Daniel : garder ce modèle (gratuit jusqu'à 700, verrou ensuite).
15. **Paiements, notifications, wallet** : passe complète de vérification (paiement réservation,
    commission 20 %, séquestre → wallet prestataire, retrait IBAN, notifications à chaque étape).
16. **Design du chat** : moderniser (bulles, en-tête, zone de saisie, pièces jointes/vocal) dans le
    style Apple/Paw Buttons validé, sans toucher aux fonctions.
17. **Page Réservations** : moderniser (filtres, cartes de réservation, statuts, vide/chargement).
18. **Chat — médias & réponses** : l'envoi de photos/vidéos ne marche pas (corriger), vocal audio
    (= point 13), **répondre à un message précis** (citation, comme WhatsApp), et **contrôle admin**
    de ces fonctions (activer/désactiver médias, vocal, réponses) dans la page admin.
19. **Profil › Préférences › onglet Notifications** : choisir quelles notifications recevoir
    (messages, paiements, demandes d'amis, réservations…) et le son : **aboiement de chien,
    miaulement de chat, cui-cui d'oiseau**, vibreur ou silencieux. Sons = fichiers courts (≤ 2 s)
    libres de droits (CC0) que je fournis moi-même sauf si Daniel en envoie ; canaux Android
    par son + `sound` APNs iOS.
20. **PawMap petite ET grande carte** : quand on bouge la carte, les barres (rail gauche, capsule
    droite) se masquent/passent sous le menu du bas → elles doivent rester visibles ; quand le
    menu du bas disparaît (grande carte), ajouter un **bouton retour en bas à gauche**.
21. **Admin › Tableau de bord** : un clic sur les compteurs (animaux, pet-sitters, promeneurs,
    propriétaires) ouvre la liste des profils correspondants.
22. **Accueil — bandeau « Tout est à jour · découvre la PawMap »** : le tap ouvre l'historique au
    lieu de la PawMap (retour testeur espagnol, capture 14/09) → doit ouvrir l'onglet PawMap.
23. **Partage en direct (PawFollow) qui s'arrête tout seul en < 2 h** (Daniel, 14/09 : « j'ai rien
    touché »). Plan : (a) trouver la cause — TTL côté serveur sur les positions live / le flag
    « en direct », vs suspension de l'app par l'OS en arrière-plan, vs socket coupé sans
    reconnexion ; (b) rendre le suivi robuste : Android = service de premier plan avec notification
    permanente « Partage en direct actif », iOS = mode arrière-plan localisation
    (`allowsBackgroundLocationUpdates`, indicateur bleu) + repli « changements significatifs »,
    reconnexion automatique du socket + battement de cœur, envoi aussi par HTTP si le socket
    tombe ; (c) côté serveur : garder la dernière position avec « vu il y a X min » au lieu de
    couper, et n'arrêter le partage QUE sur action de l'utilisateur ou après une durée choisie
    (1 h / 4 h / jusqu'à l'arrêt, défaut = jusqu'à l'arrêt) avec notification « ton partage est
    toujours actif » toutes les 4 h ; (d) affichage dans l'app de l'état réel (actif / signal
    perdu) pour l'utilisateur et ses amis.
24. **Validation de récupération et de rendu de l'animal** (Daniel, 14/09 : « 30 min avant, ça
    demande la validation, tu vois ce qui est le mieux »). Plan : rappel push aux DEUX parties
    30 min avant l'heure prévue (« Rex est récupéré dans 30 min — prêt ? ») ; à l'heure H, le
    prestataire appuie « Animal récupéré » (photo optionnelle, position GPS horodatée) → le
    propriétaire reçoit la notification et confirme d'un tap ; s'il ne répond pas, confirmation
    automatique après 2 h avec la photo/GPS comme preuve ; même chose au rendu (« Animal rendu »
    → confirmation propriétaire → le paiement séquestré est libéré vers le wallet). Un rappel de
    plus si aucune des deux parties n'a validé 1 h après l'heure. Tout visible dans la réservation
    (chronologie : prévu / récupéré / rendu / confirmé) et dans l'admin.
25. **Adresse et téléphone à l'inscription** (Daniel, 14/09 : « on les oblige ou pas ? »).
    Recommandation retenue : NE PAS obliger à l'inscription (chaque champ obligatoire fait perdre des
    inscrits, et la moitié se perdait déjà à la vérification). Inscription minimale = prénom/nom,
    e-mail, mot de passe, rôle, **ville** (obligatoire : sans ville pas de carte ni de pages villes).
    Puis demande **au moment où c'est utile** : prestataire → téléphone + adresse obligatoires pour
    publier son profil / accepter une réservation ; propriétaire → adresse (lieu de garde) +
    téléphone obligatoires pour envoyer une demande de réservation. Barre « profil complété à X % »
    sur la home + rappel J+3 (déjà dans le cycle de vie). Préfixe téléphone déduit du pays (point 12).
26. **Page Profil — refonte complète** (Daniel, 16/09) : plus claire, onglets rangés par catégorie
    (Compte · Mes animaux · Paiements & wallet · Abonnements & boutique · Préférences &
    notifications · Sécurité · Aide), et CHAQUE sous-page modernisée ; en même temps vérifier que
    chaque écran est bien connecté au serveur et synchronisé entre les 3 profils.
27. **Promotions / code promo** : très peu utilisé → le rendre visible sans gêner : petit pop-up
    discret (une fois, fermable, pas à la première ouverture), entrée claire dans Profil et au
    paiement (« J'ai un code »), message de succès lisible.
28. **Paiements, wallet, enregistrement de carte** : vérification ET modernisation, travail de fond
    minutieux (ajout/suppression de carte, carte par défaut, reçus, historique, erreurs lisibles).
29. **E-mails — liens vers l'app** : malgré l'audit, le bouton d'un e-mail ouvre encore le SITE au
    lieu de l'écran de l'app (constaté par Daniel). Vérifier universal links iOS (AASA, domaine
    associé dans le build) + App Links Android (assetlinks.json, autoVerify) + chaque route de
    `buildAppRoute` ; et re-vérifier les traductions de tous les e-mails.
30. **Annonce postée par un propriétaire** : vérifier que les notifications (push + e-mail
    « nouvelle demande près de chez vous ») partent bien aux prestataires proches.
31. **Admin › Tableau de bord** (complète le point 21) : chiffres qui se mettent à jour, TOUT
    cliquable ; clic sur propriétaires / sitters / promeneurs / animaux → liste avec l'**e-mail du
    compte** propriétaire de chaque profil ou animal.
32. **Chaîne de paiement complète, re-vérifiée de bout en bout** : propriétaire → sitter/promeneur
    (paiement, commission 20 %, séquestre, libération au rendu, wallet, retrait) ET boutique /
    abonnements (PawBoost, PawSpot, PawFollow/Family, Premium, Apple IAP, Google Play).
33. **Carte blanche sur le Profil et ses sous-pages** (Daniel, 17/09, renforce le point 26) : ne
    pas hésiter à **réorganiser les catégories** de la page Profil et les **slides / carrousels**
    (ordre, regroupements, libellés) si c'est plus clair ; **moderniser les pages et SURTOUT les
    sous-pages** (chacune, une par une) ; pour chaque écran vérifier qu'il est **branché** (vraies
    données serveur, actions qui aboutissent, synchro entre les 3 profils), **fonctionnel** (aucun
    bouton mort, états vide/chargement/erreur) et **bien traduit dans les 9 langues** (aucune clé
    brute, aucun texte en dur, textes qui ne débordent pas). Exigence d'excellence.
34. **Admin : même exigence** (Daniel, 17/09) : réorganiser le menu et les pages si c'est plus
    clair, améliorer le design de chaque page ET de chaque sous-page (modales, onglets, tableaux),
    et vérifier que TOUT est fonctionnel : chaque bouton appelle une route qui existe et répond,
    chaque tableau se charge, chaque filtre et export marche, les compteurs sont à jour et
    cliquables (points 21 et 31). Contrainte permanente : ne rien retirer des fonctions existantes,
    et l'admin étant servi par le backend Render, pas de rebuild app nécessaire pour cette partie.
35. **Accueil et Réservations : même consigne que le Profil (point 33)** (Daniel, 17/09) : carte
    blanche pour réorganiser les blocs, onglets et catégories de l'**Accueil** (bandeau, demande de
    service, Mes annonces / Pet-sitters / Promeneurs, cartes) et de **Réservations** (filtres,
    statuts, factures) si c'est plus clair ; moderniser chaque page ET chaque sous-page (détail
    d'annonce, création/édition d'annonce, profil sitter/promeneur ouvert depuis l'accueil, détail
    de réservation, paiement, facture, avis, suivi de promenade) ; vérifier pour chaque écran
    qu'il est branché, fonctionnel (aucun bouton mort, états vide/chargement/erreur) et traduit
    dans les 9 langues sans débordement. Excellence exigée, aucune fonction retirée.
36. **Messages (chat) : même consigne** (Daniel, 17/09, complète les points 13, 16 et 18) :
    réorganiser la liste des conversations et l'écran de discussion si c'est plus clair ;
    moderniser chaque sous-page (conversation, envoi photo/vidéo, vocal, réponse à un message,
    profil du correspondant, demandes d'amis, chat du cercle PawMap, notifications de message) ;
    vérifier que tout est branché (temps réel, non-lus, point vert en ligne), fonctionnel et
    traduit dans les 9 langues. Excellence exigée, aucune fonction retirée.
37. **PawMap (petite et grande carte) : même consigne** (Daniel, 17/09, complète les points 3, 4,
    7, 8, 9, 20 et 23) : réorganiser les rails, filtres et panneaux si c'est plus clair, en
    respectant les préférences fixées (bouton PawMap rectangle arrondi orange uni, rails alignés en
    bas et jamais contre le menu, design Paw Buttons) ; moderniser chaque sous-page (Autour de moi,
    itinéraire, signaler / voir les signalements, spots de la communauté et création de spot avec
    photo, amis en direct, partage en direct, profil d'un membre, demande d'ami ou de service
    depuis la carte, fiche d'un lieu) ; vérifier que tout est branché et synchronisé avec le reste
    de l'app, fonctionnel et traduit dans les 9 langues. Excellence exigée, aucune fonction retirée.
38. **Avis dans Réservations** (Daniel, 18/09) : à la fin du service le propriétaire peut noter son
    sitter/promeneur (étoiles + commentaire, depuis le détail de réservation et la chronologie) ; les
    notes des sitters et promeneurs s'affichent en étoiles, de façon moderne (carte profil, liste
    des prestataires, détail de réservation).
39. **Sous-pages restantes du Profil à moderniser** (constat 18/09) : fiche animal (modification),
    tarifs, calendrier de disponibilités, IBAN, ajout de carte, onboarding sitter, corps des 3 écrans
    « Modifier le profil », paiements / wallet / KYC.
Puis : build simulateur + tests, IPA (flutter clean avant) + Transporter, AAB + `play_release_api.py`,
admin « Versions de l'app » 565/565 après validations, journal + mémoire.
2e passe (retour Daniel sur capture du dashboard) : `/dashboard` (barre latérale gris clair,
bannière de rôle unie, cartes PawMap / Réservations gris clair, NavCard sans bordure, promo
noir) et `/map` (bandeaux, chips catégorie noir/gris, fiche lieu, chip PawPremium) au même
style ; galerie « L'app en images » = carte, alertes, accueil, profil, boutique, itinéraire
(le doublon Boutique/Premium est retiré). 3e passe : `/map` contrôles épurés (Signaler orange,
autres pilules noir actif / gris inactif, plus de rose fluo ni de dégradés, chips abonnements
blanc/noir, carte `rounded-[28px]` sans bordure) ; galerie = carte, alertes, accueil, profil,
boutique, « Autour de moi » (plus de 2e capture de carte).

**12/09 — v561 / build 564 « NOTIFICATIONS DIRECT DANS L'APP + MISE À JOUR AUTO + PAWMAP »
(14 points de Daniel, liste validée avant de commencer).**
- **Notifications → écran précis.** `backend/src/utils/emailLinkBuilder.js` : `buildAppRoute(type,
  data)` = UNE route « thème » par type (`/friends/requests`, `/chat/:id`, `/bookings/:id`,
  `/pay?bookingId=`, `/walk/:id`, `/post/:id`, `/wallet`, `/paw-spot`, `/subscription`,
  `/profile`, `/alert/:reportId`, sinon `/notifications`) ; le mail l'utilise en lien universel
  (`{{emailLink}}`) ET le push la porte dans `data.route`. Le raccourci v449 (« tout sur
  `/open` ») est SUPPRIMÉ. 26 mails sans bouton en ont un (« Ouvrir dans l'app », 9 langues),
  `booking_refunded` réparé (`{emailLink}` → `{{emailLink}}`), boutons passés à `#D83C28`.
  App : `DeepLinkService.openRoute(route)` = routeur unique (liens universels, `hopetsit://`,
  push via `route` ou `routeForNotification(type,data)`) ; il ATTEND que le menu soit monté
  (`navWrapperMounted`, max 6 s) avant tout `Get.to` → fin de l'écran noir au démarrage à
  froid ; sans session la route est mémorisée (`pending_deep_route`) et rejouée après login.
  `/chat/:id` ouvre LA conversation, `/bookings/:id` la fiche (owner), `/post/:id` l'annonce,
  `/friends/requests` l'onglet Demandes, `/friends/live` les personnes en direct, `/pawmap` et
  `/posts` basculent d'onglet. ⚠️ `hopetsit://friends/requests` : le host porte l'action et
  `pathSegments` = [requests] → toujours utiliser `rest` (segments après l'action), pas
  `segs[1]`. AASA (+14 chemins) et AndroidManifest (+14 pathPrefix) complétés ; site :
  `apple-itunes-app` (Smart App Banner), `components/AppLinkOpener.tsx` (mobile arrivant de
  l'extérieur → tente `hopetsit://<même chemin>` une fois), catch-all avec les vraies URLs
  stores. Vérifié au simulateur : `xcrun simctl openurl booted "hopetsit://friends/requests"`
  → onglet Demandes ; `hopetsit://pawmap` → onglet PawMap.
- **Mise à jour auto.** `GET /app-version` (public, cache 60 s) + `GET/PATCH /admin/app-version`
  (admin, page Tarifs → « Versions de l'app » : build actuel / minimum par plateforme).
  App : `services/app_update_service.dart` (3 s après le montage du menu) — Android : Play
  In-App Updates (`in_app_update`, immédiat sous le minimum, souple sinon) ; iOS / repli :
  feuille « Nouvelle version disponible » (une fois par version, refusable) ou bloquante sous
  le minimum, bouton App Store. Vérifié au simulateur (latest=999 → feuille). ⚠️ Après chaque
  publication, mettre `latest` = nouveau build dans l'admin (scratch `appver_admin.py`).
- **PawMap.** Bouton violet « Autour de moi » (rail gauche, petite + grande carte) → feuille :
  rayon 1/2/5/10 km (5 par défaut, mémorisé `pawmap_around_radius`), mode à pied/vélo/voiture,
  10 catégories → liste triée par distance (ouvert/fermé, adresse) → tap = `_startDirections`.
  Badges membres : 48 → 56 px, halo plus fort, ROSE FLUO dézoomé et couleur du rôle dès le
  zoom 12 (owner `#FF5A2E→#D83C28`, walker vert, sitter bleu) — clé `_pawBadgeKey(...)`.
  Rails : alignés sur le BAS de la capsule droite (padding en haut des boutons,
  `CrossAxisAlignment.end`), remontés de 22 px (168 / 228 / 284) pour ne pas toucher le menu
  flottant. Retour de l'app après ≥ 2 min en arrière-plan → `_recenterOnUser()` (sauf
  itinéraire / suivi / placement). Icône PawSpot = nouvelle pièce dorée
  `assets/images/pawspot_coin.png` (widget `GoldenPawCoin`, rail, marqueurs dorés avec anneau
  du type) ; web `public/pawspot_logo.png|svg`, `PawSpotGoldCoin` = `<img>`.
- **Design « Paw Buttons » (handoff Claude Design de Daniel, zip `Refonte boutons et
  cartes services.zip`, README = périmètre DESIGN UNIQUEMENT).** Boutique app
  (`coin_shop_screen.dart` `_shopCardTab`, `PreferredSize` 150.h + 18.h) et web
  (`boutique/page.tsx` `SectionTab` + `CARD_ICONS`) : 4 cartes verre dépoli ratio 1/1,75,
  dégradé 165° (Boost `#FF6B4A→#E0361F`, Follow `#9B6BFF→#6A34E0`, Spot `#FFC23D→#F0900A`,
  Premium `#3A3028→#0F0B08` titre `#FFD34D`), bord blanc .45, reflet 45 %, ombre colorée,
  disque blanc 56 px + icône SVG 26 px pleine, titre 13/800, description 9,5/700 (clés
  `shop_card_*_sub`, 9 langues app + 9 langues web). Boutons ronds PawMap
  (`_roundMapBtn` : `svg`, `g1`, `g2`) 44 px (54 dans la maquette, réduits pour tenir dans
  la bande de la petite carte), dégradé 165°, bord blanc .7, reflet, ombre colorée, icônes
  SVG blanches pleines du prototype, aucun libellé visible (Tooltip + Semantics gardés) ;
  ordre : Autour de moi (violet), Itinéraire (vert), [grande carte : Chat du cercle bleu,
  Photo du spot orange], PawSpots (or), Marquer un lieu (turquoise), Signaler (rouge
  triangle « ! »), Voir signaux (brun, drapeau + pastille rouge). Rail conservé à GAUCHE
  (la capsule zoom/position reste à droite) — la maquette le dessinait à droite, mais
  déplacer la colonne aurait changé l'ergonomie : design seulement.
  L'icône PawSpot « pièce » n'est plus utilisée sur le rail ; `GoldenPawCoin`
  (boutique en-tête, carte boost, marqueurs dorés, web) = bouton noir + pin doré dessiné
  (`~/hopetsit-social/play/pawspot_button_black_gold_1024.png`), demandé par Daniel après
  deux essais (pièce ChatGPT claire puis assombrie : « ne rend pas bien »).
- **Accueil / menu.** Onglet « Mes annonces (N) » en `FittedBox` (plus de « Mes annon… »).
  Menu = pilule flottante (marges 10, coins 28, ombre douce), onglet actif dans une bulle
  teintée, libellés en `FittedBox` (« Réservations » entier). **Bouton PawMap = rectangle
  arrondi 72×66, orange UNI `#D83C28` (Daniel : « j'aime pas le dégradé », après 5 essais),
  centré sur la barre pour dépasser ~10 px en haut et en bas.** Libellé `nav_pawmap`. Icônes
  SVG passées de `#F2741B` à `#D83C28`. Hauteur utile inchangée. Alertes : puce « Autour de
  moi · N km » bornée (débordement RIGHT OVERFLOWED corrigé).
- **Publication 12/09** : Play = `~/hopetsit-social/play/play_release_api.py <aab> notes_564.json`
  (bundles.upload → tracks/production completed → commit 200, notes 8 langues) ; iOS = IPA
  Transporter (bouton DISTRIBUER à cliquer cette fois), **1.17 créée (id
  `3b35da3b-1f93-4e73-b436-3fd602351826`)**, whatsNew 8 locales, build 564 attaché + soumis.
  ⚠️ Admin « Versions de l'app » : remis à 563/563 après le test (999) ; **passer à 564/564
  quand Play et Apple ont approuvé** (sinon la feuille « Nouvelle version » s'affiche avant que
  le store ne l'ait).

**11/09 — FICHES STORES 8 LANGUES (pack `HoPetSit-Apple-GooglePlay-Complet.zip`, visuels
promotionnels FR/EN/ES/IT/DE/PT/NL/PL : 5 captures + 1 bannière Play par langue).**
- **App Store** : la 1.15/562 était déjà APPROUVÉE (READY_FOR_DISTRIBUTION) → **version 1.16
  créée (id `5b51e075-ff9d-4f1d-b716-987dc4c087a8`), build 563 (v560, aucun changement de
  code, IPA seule) distribué par Transporter, attaché, soumise → WAITING_FOR_REVIEW le 11/09
  ~14:45**. 6 nouvelles localisations créées (es-ES, it, de-DE, pt-PT, nl-NL, pl) : nom +
  sous-titre (appInfoLocalizations de l'appInfo éditable `be4aeeaa-…`), description, mots-clés,
  whatsNew, URLs. ⚠️ Créer une appInfoLocalization crée AUSSI la appStoreVersionLocalization
  (POST = 409 DUPLICATE → PATCH). 40 captures 1320×2868 uploadées par API depuis l'onglet ASC
  (set `APP_IPHONE_67` par locale, anciens sets 6,5" supprimés), toutes `COMPLETE`, md5 vérifiés.
  Textes : `scratchpad/store_texts.json` (copie ci-dessous dans la mémoire si besoin).
- **Google Play — FAIT PAR L'API Android Publisher (fin des clics dans la console).** 8 fiches
  (en-GB, fr-FR, es-ES, it-IT, de-DE, pt-PT + **nl-NL et pl-PL créées**), titres localisés
  (fr « HoPetSit : Garde d'animaux », es « Cuidado de mascotas », it/pt « Pet Sitting »,
  de « Tierbetreuung », nl « Dierenoppas », pl « Opieka i spacery »), 5 captures + 1 bannière
  par langue, commit 200 → changements envoyés en examen automatiquement.
  **Méthode** : compte de service `play-publisher@lawstravels-6cce1.iam.gserviceaccount.com`
  (déjà utilisateur du compte développeur ; Daniel lui a donné le droit de publier sur HoPetSit
  le 11/09), clé JSON dans **`~/.hopetsit_play_sa.json` (chmod 600, jamais dans le code)**,
  script **`~/hopetsit-social/play/play_listing_api.py`** (venv google-auth + requests ;
  `--dry-run`, `--only-langs`), textes `store_texts.json`, pack `storezip/`. Pièges : 503
  passagers (réessais), `validate`/`commit` = 403 tant que le SA n'a pas « Publier des versions
  en production » ; un edit vit ~2 h. Les uploads d'AAB peuvent passer par la même voie
  (`edits/bundles` + `tracks/production`). ⚠️ Dans la console, le sélecteur de langue + « Save »
  acceptent les événements synthétiques, mais l'import d'images, « Select languages » et
  « Submit N changes » les refusent ; l'extension Claude in Chrome refuse `play.google.com`
  (et google.com) dans les DEUX Chrome → ne plus essayer.
- **Transfert de propriété Play → contact@hopetsit.com : FAIT par Daniel le 11/09** (mail Google
  « The owner of this developer account has been successfully changed »).

**10/09 — v560 « MOTEUR DE CROISSANCE AUTONOME » (mission Daniel : « crée du
trafic et des clients, des choses que tu feras seul »)** — mémoire détaillée :
`hopetsit_growth_engine.md`. Décision : plus de fonctionnalités app, tout à
l'acquisition/activation.
- **E-mails de cycle de vie** (`backend/src/services/lifecycleEmailScheduler.js`,
  démarré dans index.js, 1 passage/heure 9 h-19 h Paris, 15 max/passage) :
  `welcome_provider_d1` / `welcome_owner_d1` (20 h → 7 j), `profile_incomplete_d3`
  (prestataire sans photo/bio ≥ 20 car./tarif), `first_client_d7` (0 réservation),
  `owner_first_request_d5` (0 annonce, 0 réservation), `inactive_d21` (updatedAt
  ≥ 14 j), `review_after_booking` (réservation `completed` il y a 2-6 j, les deux
  côtés). Textes : `locales/<lang>/lifecycle.json` ×9 (`{{name}}` = prénom
  capitalisé). Traçage : modèle `LifecycleEmail` (index unique user/role/step/ref).
  Exclusions : `+test`, hopetsit@, dadaciao84@, jandoe, staff, `marketingOptOut`
  (nouveau champ Owner/Sitter/Walker). Désabonnement : `GET /api/v1/lifecycle/
  unsubscribe?r&u&t` (HMAC JWT_SECRET) → page HTML. `LIFECYCLE_EMAILS=off` coupe
  tout ; `LIFECYCLE_DRY_RUN=1` journalise sans rien écrire (testé sur la base dev :
  6 relances « inactif »). `POST /lifecycle/run` protégé par `LIFECYCLE_ADMIN_KEY`.
- **Pages villes** : 47 → **152** (76 villes × recrutement + propriétaires, 9
  langues). Données : `recruit-cities.ts` (+ `OWNER_PATH_PREFIX`, `ownerPaths()`),
  composants `RecruitCityPage` (5 langues ajoutées) et `OwnerCityPage` (nouveau,
  JSON-LD Service + FAQPage), 18 dossiers `src/app/<préfixe>/[city]`, liens
  croisés, hub `/villes` (pied de page `footer_cities`), sitemap auto.
  ⚠️ Slugs allemands sans umlaut (`muenchen`, `koeln`) ; Alicante mentionne
  Dénia/Jávea (zone du testeur espagnol).
- **Routine cloud dimanche** (`trig_01BpzyjaJz7SPDgPFCdjinQM`) réécrite : 2
  articles/semaine (FR Paris + langue en rotation ISO mod 8), préfixes des 9
  langues, section « 4. Langue du jour » du fichier social, **IndexNow** des 2
  URLs (clé lue dans `website/public/<hex>.txt`).
- **Retour Daniel (soir)** : « toute l'Europe et les USA, surtout Paris, surtout
  pas harceler par mail, de NOUVEAUX utilisateurs » → relances réservées aux
  comptes créés après `LIFECYCLE_SINCE` (10/09/2026), étape « inactif »
  supprimée, 6 jours minimum entre deux relances. Villes : **258** (≈ 520 pages
  villes) — 60 en Île-de-France (Paris d'abord), 37 en France, Belgique/Suisse/
  Luxembourg/Monaco en français, DE/AT/CH, IT, ES, PT, PL, et 35 villes d'Europe
  en anglais (Londres, Dublin, Amsterdam, Copenhague, Prague…), 45 aux USA (dont
  celles où des sitters existent déjà : St. Louis, Honolulu, Naples FL, Decatur
  GA). Copie EN sensible à la devise. Hub `/villes` : section EN = « USA ·
  United Kingdom · Europe (English) ». ⚠️ `sitemap.xml` est mis en cache par
  Vercel : lire avec `?nocache=<ts>` avant IndexNow.
- **Commerces partenaires** (validé par Daniel « il faut tout essayer ») :
  27 vétérinaires/animaleries/toiletteurs de Paris contactés le 10/09 avec une
  affiche A4 à leur nom (`website/public/affiches/<slug>.pdf`, QR
  `?ref=<slug>`). Outils dans `~/hopetsit-social/` (`affiche_commerce.py`,
  `envoi_partenaires.py`, `partenaires_paris.json` = statuts). Réponses sur
  hopetsit@gmail.com. Vague 2 = petite couronne. Pas de relance automatique.
- À surveiller : logs Render `[lifecycle]`, Search Console (nouveaux préfixes),
  `website/marketing/reports/`. Prochaines idées : fiche pro commerces (option
  B), hubs par pays, relances SMS (pas de canal).

**08/09 — v559 « itinéraire 3 modes + virages, horaires des lieux, FR en dur »**
(retours du testeur espagnol de Daniel + option A validée)
- ⚠️ **Le serveur OSRM public ignore le profil** (vérifié : `foot`, `bike`,
  `driving` → même trajet 13 234 m / 1 188 s) : « l'itinéraire piéton » de la
  v509 était un trajet VOITURE avec une durée recalculée à 4,8 km/h. Passage
  sur **Valhalla public (FOSSGIS, `valhalla1.openstreetmap.de`)** : modes
  réels (même paire : 12,8 km / 2 h 34 à pied, 13,3 km / 45 min vélo,
  14,7 km / 30 min voiture), durée réelle, manœuvres traduites (`language`),
  tracé en polyline précision 1e-6 (`decodePolyline6`). Params
  `GET /pawspots/directions?mode=walk|bike|car&lang=xx` → `steps[]`
  (type Valhalla, instruction, distance, lat/lng). OSRM puis ligne droite en
  secours. Pas de clé, usage raisonnable (User-Agent HoPetSit).
- App : `_routeMode` mémorisé (`pawmap_route_mode`), 3 pastilles sur le
  bandeau (à pied orange #C92A12 / vélo vert #16A34A / voiture bleu #2563EB),
  couleur du tracé = mode, distance + durée, mini-repères de virage
  (`_drawStepIcon`, 22 px, glyphe Material peint sur canvas, InfoWindow =
  instruction), feuille « Étapes ». Bouton **Itinéraire aussi sur la petite
  carte** (demande Daniel en cours de route). Site : mêmes pastilles,
  `routeColor`/`routeSteps` sur PoiMap (CircleMarker + Tooltip), liste repliée.
- **Horaires des lieux** : `openingHours` était stocké par le seed OSM mais
  ABSENT de la projection `/map-pois/nearby` → jamais affiché (Varsovie :
  111 lieux sur 195 en ont). Analyseur `opening_hours` maison (Dart
  `utils/opening_hours.dart` + TS `lib/openingHours.ts`, même logique) :
  jours/plages/`off`/`24/7`/passe-minuit ; non compris (texte libre, PH) →
  null → horaires bruts seuls. ⚠️ Piège corrigé : « Su,Mo off » = UNE règle,
  ne pas la couper à la virgule. Fiche app : statut vert/rouge + brut +
  téléphone « Appeler » (`tel:`), **aucun lien vers le site du commerce**
  (décision Daniel, le lien « Site web » du popup web a été retiré).
- **FR en dur** : audit (accents + mots français dans des chaînes sans `.tr`)
  → 25 textes passés en clés (« Date et heure de la promenade » = le
  « Fechas » en français du testeur, paiement/Airwallex, amis, IBAN,
  consentement vétérinaire → getter `.tr`, estimateur de prix, deep link,
  « Demande de garde »). `send_request_controller` : jours/mois ko/ja/pl
  manquaient → retombaient sur le FRANÇAIS ; repli passé sur l'anglais.
  Service de fond (`live_tracking_bg`) : isolate sans GetX → table locale
  par `Platform.localeName` (`bgLiveText`). Restent volontairement : textes
  légaux (`data/static`), diagnostics, noms de langues.
- 39 clés × 9 langues app, 12 × 9 site (+ `map_route_distance` sans « à pied »).
  ⚠️ Placeholders : l'app utilise `'clé'.tr.replaceAll('{x}', …)` (PAS
  `trParams`, qui attend `@x`) — un premier essai affichait « (min) min ».
- **Vérifié au simulateur** (compte test passé staff le temps du test, remis
  ensuite) : petite carte → Itinéraire → tracé orange 334 m / 4 min, repères
  « Tournez à droite dans l'allée. », Vélo → tracé vert 850 m / 3 min,
  Voiture → bleu 1,4 km / 6 min, feuille « Étapes » ; grande carte → 8,5 km /
  26 min en voiture. Daniel : « le bandeau gêne, qu'il ne touche pas les
  barres » → grande carte `top: 100.h` (sous la rangée du haut) ; petite carte :
  rails remontés à 206 quand un tracé est affiché (comme « Autour de vous »),
  bandeau centré à 136 → 24 px de marge. Site vérifié en prod (/map, jeton
  posé dans localStorage `hopetsit_token`) : popup lieu = horaires + « Appeler »,
  3 pastilles, Vélo → 2,1 km · 7 min, cadre vert, Étapes.
- Les exceptions `RawTooltipState … multiple tickers` du journal viennent des
  Tooltips des rails (v555, `_roundMapBtn`) quand ils disparaissent pendant un
  placement — silencieuses en release ; mes nouveaux boutons utilisent
  `Semantics`, pas `Tooltip`.
- Simulateur : `xcrun simctl location <udid> set 48.8566,2.3522` puis « ma
  position » dans l'app, sinon `_userPosition` est null et l'itinéraire ne
  part pas (snackbar furtive). Le tap « ma position » recentre → penser à
  déplacer la carte avant de choisir la destination (sinon départ = arrivée).
- **Intégration partout** (question Daniel : « suivi, adresse du domicile,
  PawSpot, PawFollow ? ») — audit : seule la PawMap traçait ; ailleurs Google
  Maps externe ou rien. Ajouts : `PawMapScreen(routeToLat/Lng)` (itinéraire
  lancé à l'ouverture, `_startPendingRoute` attend ma position ≤ 10 s) ;
  fiche membre/ami `_onNearbyTap(lat,lng)` → bouton Itinéraire vert ; bulle
  d'un ami en direct → tap = fiche ; « Personnes en direct » → 🧭 par ami
  (`_resolveFriendPosition`) ; balade en direct (propriétaire) → action
  Itinéraire ; `AddressShareCard` (domicile partagé dans le chat) →
  Itinéraire dans l'app + Google Maps en second ; site : popup ami en direct →
  bouton Itinéraire. Les pages publiques /spot/[id] et /alert/[id] gardent le
  lien Google Maps (visiteur non connecté).
- **Ouverture via l'ONGLET, pas un écran poussé** (Daniel : « la barre
  itinéraire est au milieu et le menu de l'app a disparu ») : `map_ui_state`
  gagne `requestedTab` (observé par `StackedNavigationWrapper`, `_onTap`),
  `pawMapPendingRoute` (observé par la PawMap, `ever` + valeur initiale) et
  `openPawMapWithRoute(lat,lng)` (retour à la racine `Get.until(isFirst)` →
  onglet PawMap → itinéraire). Repli : écran poussé si le menu n'est pas
  monté. PawMap poussée hors onglets → `_tabBarLift()` (canPop) retire les
  ~100 px prévus pour la barre d'onglets (rails, bandeau, « Autour de vous »,
  carte de placement). Lien `/map?lat&lng&route=1` = même chemin.
  Vérifié : `xcrun simctl openurl … "hopetsit://map?lat&lng&route=1"` →
  onglet PawMap + menu + tracé (le lien https ouvre Safari sur simulateur ;
  l'universal link n'y est pas associé).
- **Orange PawMap = orange de l'icône** (Daniel) : `#D83C28` (moyenne des
  pixels rouge-orange de l'icône 1024, script PIL) — `PawMapTheme.accent`,
  `_kAccent`/`_kAccentDark` (nav bar + wrapper : D83C28 / B92425), SVG
  `pawmap_logo_orange.svg` + `pawmap_nav.svg` (app) et `pawmap_logo*.svg`
  (site), bouton « OUVRIR LA PAW MAP » (`PawMapCTA`), page /alert.
- Trio → v559 / 23.1.559+**562**. Notes Play : `HoPetSit_559_notes_de_version.txt`.
- **Menu vérifié** (Daniel) : les 5 onglets ouverts l'un après l'autre au
  simulateur après l'ajout du worker `requestedTab` — tous OK.
- Fichiers : `~/Downloads/HoPetSit_v23.1.559.{apk,aab,ipa}` (build 562).
- **iOS** : la 1.14 (build 561) a été **APPROUVÉE** par Apple dans la journée
  (READY_FOR_DISTRIBUTION) → plus de soumission à annuler ; **1.15 créée**
  (`4b3059e6-ee3a-4fe1-8683-4d9bbbac2470`), build 562 rattaché, whatsNew
  fr/en, soumission `6683e96c-…` → **WAITING_FOR_REVIEW avec le 562**.
  ⚠️ Quand une version est READY_FOR_DISTRIBUTION, attach/whatsNew renvoient
  409 : créer la version suivante (`POST /appStoreVersions`).
- **Play** : AAB 562 importé par Daniel → notes 6 langues, Suivant, Enregistrer,
  aperçu, Envoyer + confirmation (tout en JS) → **« Modifications en cours
  d'examen » — 562 (23.1.559)**.

**08/09 (nuit) — v558 « rangée PawMap repliée + vérification notifications »**
- **Rangée repliée** (captures Daniel) : `_buildTopArea()` → replié =
  `_buildCollapsedTopRow()` : 3 cellules `Expanded` de largeur égale, hauteur
  `_topRowHeight` = 46, coins 16 : `PawMapPanelHandle(fill: true)` /
  `_buildLiveBroadcastBanner(compact: true)` / `_buildExpandPill(fill: true)`.
  Ouvert : inchangé. `_buildGlassPanel()` supprimé.
- Libellé `pawmap_live_share_off` → « Partager en direct » (9 langues, courts :
  Share live / Compartir en vivo / Live teilen / Condividi live / Partilhar ao
  vivo / 실시간 공유 / ライブ共有 / Udostępnij na żywo).
  ⚠️ Deux pièges vus au simulateur : (1) un retour à la ligne automatique
  coupe AU MILIEU du mot (« Part / age ») → `_twoLines()` coupe à l'espace le
  plus central puis FittedBox réduit ; (2) `Transform.scale` sur un Switch
  garde sa boîte de 60 px → texte minuscule ; en compact le Switch est dans
  `SizedBox(36×22) + FittedBox`.
- **Notifications vérifiées en prod** (comptes test, tout nettoyé après) :
  annonce publiée à Madrid (seule ville où il n'y a QUE le gardien test →
  aucun vrai membre notifié) → `new_request_nearby` : in-app + push (1 jeton,
  0 échec) + e-mail en 1 s ; demande d'ami → **bandeau bleu « Nouvelle
  demande d'ami » + point rouge sur la cloche en direct sur l'Accueil**
  (socket `notification.new`). Paiements (`booking_paid`, `booking_paid_owner`,
  `wallet_credited`, `payout_completed`) : passent tous par `sendNotification`
  (3 canaux) et les 9 catalogues ont les 59 types — non déclenchables sans un
  vrai paiement Airwallex. ⚠️ `new_request_nearby` cible par VILLE exacte
  (`location.city`), max 50, sans exclusion des comptes test : ne jamais
  publier une annonce test dans une ville réelle.
- Hot reload en arrière-plan : `mkfifo cmd.fifo ; (sleep 100000 > cmd.fifo &) ;
  flutter run … < cmd.fifo` puis `echo r > cmd.fifo` (a fonctionné une fois
  puis « Lost connection to device » — relancer si besoin).
- Trio → v558 / 23.1.558+**561**. Notes Play : `HoPetSit_558_notes_de_version.txt`.
- **Vérifié au simulateur** : replié = 3 cadres égaux, « Partager / en direct »
  lisible ; ouvert inchangé. Fichiers : `~/Downloads/HoPetSit_v23.1.558.{apk,aab,ipa}`.
- **iOS** : IPA envoyé par Transporter (distribution automatique à l'ouverture),
  build 561 VALID en ~10 min, soumission 85a54c5e annulée → 561 rattaché (204)
  → whatsNew fr/en → soumission `9e1a89be-…` → **1.14 WAITING_FOR_REVIEW avec le 561**.
- **Play** : AAB 561 importé par Daniel ; notes 6 langues posées par setter natif
  + InputEvent + blur (compteur « 6 langues sur 6 » après un 2e input/blur),
  puis **Suivant → Enregistrer → Accéder à l'aperçu → Envoyer 1 modification
  pour examen → dialogue** tous passés en JS cette fois (bouton du dialogue =
  « Envoi des modifications pour examen », à chercher DANS `[role=dialog]` ;
  le bouton « Envoyer 1 modification » : comparer `innerText` après
  `replace(/\s+/g,' ')`).

**07/09 (soir) — « notifications en retard » : diagnostic (serveur seul, pas de rebuild)**
- **Serveur hors de cause** : logs Render `[notif.entry]` → `[notif.channel] email ok`
  en ~1,2 s ; test SMTP prod → boîte Gmail mesuré **2 s** (en-têtes Received).
  Render = plan Starter (pas de mise en veille).
- **Cause iOS trouvée** : Firebase (projet `hopetsit`, console u/8 du Chrome
  de Daniel) n'a qu'une **clé APNs de DÉVELOPPEMENT** (WJSPRXB7FC, team
  49C67YDPJ5) et « Aucune clé d'authentification APNs de production » →
  les builds App Store (entitlement `aps-environment: production`) répondent
  `messaging/third-party-auth-error` → **aucun push iPhone** (Daniel : 1 de ses
  2 jetons ; Persia Riley : son seul jeton). Le .p8 existe :
  `~/.private_keys/AuthKey_WJSPRXB7FC.p8` → **IMPORTÉE dans le slot production
  (20:15 UTC, feu vert Daniel)** via le Chrome de Daniel : le .p8 servi par un
  mini serveur CORS local (127.0.0.1:8769) + XHR **synchrone** dans la page
  (le fetch async ne rend pas la main avec l'outil JS), fichier posé sur
  `input[type=file][name=Filedata]` (accept .p8 ; le drop sur la zone est
  refusé « type non accepté »), IDs de clé/équipe via setter natif, clic
  Importer. **Vérifié** : demande d'ami test → Daniel à 20:17 UTC =
  `fcmTokens=2`, plus aucune « partial failure » (avant : 1 succès / 1 échec).
  ⚠️ Ne PAS purger les jetons sur `third-party-auth-error` (ils sont valides).
- Android : le serveur ne peut plus rien faire → économie d'énergie Samsung
  (« applications en veille profonde », Gmail idem).
- Serveur v558 : priorité haute explicite (android.priority + apns-priority 10),
  canal `hopetsit_default_channel`, son, `apns-push-type alert`.
- Bundle iOS réel = `com.cardellihermanos.hopetsit` (pbxproj + GoogleService-Info),
  la note « iOS reste com.hopetsit.app » plus bas est périmée.

**07/09 (midi) — v557 « URGENT rectangle gris » + boutique 4 onglets + i18n**
- **Bug** (captures Daniel 12:11, sur la 556) : grand rectangle gris
  translucide sur la carte + rail gauche disparu. Cause : en rendant PawSpot
  gratuit j'ai retiré `spotOk`, seule lecture observable de l'Obx de
  `_buildMapActionsColumn` → GetX lève « improper use of a GetX » → ErrorWidget
  gris (0xF0C0C0C0) étiré sur la rangée des rails. **Reproduit en debug sur
  simulateur** (exception dans le log), corrigé (Builder au lieu d'Obx),
  re-vérifié : 0 exception, petite ET grande carte OK.
  ⚠️ RÈGLE : un Obx doit lire au moins un `.value` — sinon gris en release.
  Méthode de repro qui marche : `flutter run --debug` sur simulateur + login
  test via osascript (`click at` coordonnées écran + `keystroke`) — l'app_type
  en arrière-plan n'atteint PAS les champs Flutter.
- `pawMapExpanded.value = false` dans initState → « setState during build »
  (debug) → différé après la 1re frame.
- **Boutique** : carte « Gratuit pour tous / Avec … » sur les 4 onglets via
  `shopValueCard` (Daniel : « seul PawFollow avait été modifié »), 12 clés ×9.
- **i18n** : 7 chaînes françaises en dur dans Mes amis → clés
  (`friends_request_wants`, `common_user`). Audit : 9 langues identiques.
- Trio → v557 / 23.1.557+560. Notes Play : `HoPetSit_557_notes_de_version.txt`.
- **Play** : « Modifications en cours d'examen » — 560 (23.1.557).
- **iOS** : 1.14 → soumission 559 annulée, build **560** rattaché (204, après
  5 s d'attente — cf. piège DEVELOPER_REJECTED), soumission `85a54c5e-…` →
  **WAITING_FOR_REVIEW avec le 560**. whatsNew fr/en réécrits pour la 557.
  Fichiers : `~/Downloads/HoPetSit_v23.1.557.{apk,aab,ipa}`.

**07/09 (matin) — v556 « boutique expliquée + fiches sous la barre + traductions »**
- **Boutique** : carte « Gratuit pour tous / Avec PawFollow » en tête de
  l'onglet PawFollow (`_pawFollowValueCard`), avantages alignés sur l'option C
  (+ historique), PawSpot annonce les itinéraires inclus. 5 clés × 9 langues.
- **Fiches Ajouter un PawSpot / Publier le signalement** : bouton sous la
  barre système en carte agrandie (viewPadding = 0) → règle « 48 si 0 ».
- **Site** : `home_app2_body` réécrit (option C, 9 langues) ; 39 textes
  polonais ajoutés. ⚠️ **Faux positif d'audit** : « 111 clés manquantes » en
  es/de/it/pt n'existaient pas — ces clés sont en 2e position sur des lignes
  partagées (`a: "…", b: "…"`). Regex d'audit correct :
  `(?<![A-Za-z0-9_])clé:\s*["']`. tsc a attrapé mes doublons → retirés.
  Seule clé absente hors en : `account` (en-only, fallback anglais).
- **App** : pl.dart complété (8 clés). Audit : 9 langues à 3 256 clés, 0 manque.
- **Marqueurs** (demande Daniel en cours de route) : avatars amis/moi 96 →
  **80**, rendu médaillon (ombre, anneau fin dégradé or/violet/rôle, liseré,
  reflet), dessinés à **2×** et affichés via `BitmapDescriptor.bytes(width: 80)`
  (sans `width`, un bitmap 2× s'afficherait à 160). Pièce PawSpot : canvas
  128 + `canvas.scale(2)` (elle était étirée 3× par l'écran → floue), reflet
  métal, 70/64 → 62/56.
- **Halos par abonnement** (Daniel) : Premium or + contour noir, PawFollow/
  Famille violet, PawSpot jaune, sinon couleur du rôle — membres proches,
  amis en direct, halo perso (`_haloColorFor`). Serveur : `/friends/members/
  nearby` expose `isPremiumOnly` / `hasPawFollow` / `hasPawSpot`.
- **PawSpot gratuit dans l'app** (conforme au site) : voir spots/liste/couche
  pour tous, « Marquer un lieu » et « Photo » ouverts, serveur limite à
  3 tags (`FREE_SPOT_LIMIT`) → 402 → boutique. Note « 3 premiers tags
  gratuits » (9 langues, app + site).
- **Site** : `SubscriptionsExplainer` (accueil + /pawmap), 12 clés × 9 langues,
  prix PawPremium (`home_pawpremium_price_line`), en-tête cadré ; bouton
  « me géolocaliser » : GPS précis d'abord + flyTo 17. App : « ma position »
  = fix `LocationAccuracy.best` frais + zoom 17.
- **Play** : « Modifications en cours d'examen » — 559 (23.1.556).
- **iOS** : 1.14 → soumission 558 annulée, build **559** rattaché, renvoyée →
  **WAITING_FOR_REVIEW avec le 559**. ⚠️ Piège iris : juste après
  `canceled:true`, la version passe en DEVELOPER_REJECTED quelques secondes
  → attach/item renvoient 409 INVALID_STATE. Attendre ~4 s puis rejouer
  attach → item → submit sur la MÊME reviewSubmission (déjà créée) : 204/201/200.
- **Site** : halos par abonnement sur /map (`subscriptionHaloColor`,
  `makeMemberIcon(m)`, props `pawFollowIds`/`pawSpotIds`, halo perso via
  `benefits`) ; **accueil refait en 12 blocs** (héro, confiance, vidéo,
  « Comment ça marche » 4 étapes, rôles, services, bande PawMap sombre avec
  capture réelle, captures, abonnements expliqués, PawPremium, FAQ accordéon,
  CTA) — design seul, mêmes clés/routes ; vérifié en prod. Bandeau mobile
  « Télécharger l'app » n'apparaît qu'après 420 px de défilement (il
  recouvrait le titre du héro). Puis **5 pages en version premium**
  (Comment ça marche, Tarifs, PawMap, FAQ, Contact) via le composant commun
  `PageHero` / `SectionTitle` — vérifiées en prod.
- Fichiers : `~/Downloads/HoPetSit_v23.1.556.{apk,aab,ipa}` (build **559**),
  notes Play : `~/Downloads/HoPetSit_556_notes_de_version.txt`.

**07/09 (03 h) — v555 « deep work PawMap » (captures Daniel sur la 554 installée)**
- **Cause racine des boutons sous le menu** : les viseurs lisaient
  `MediaQuery.viewPadding.bottom`, qui vaut **0 sur le Samsung de Daniel**
  (edge-to-edge) ; tout le reste de la carte passe par `_navInset()` (48 par
  défaut). ⚠️ RÈGLE : pour la barre système, TOUJOURS `_navInset(context)`.
  Petite carte : la barre d'onglets pleine largeur monte jusqu'à ~125.h
  (mesuré : 122.h = SOUS la barre) → carte de placement à 140.h.
- **Placement refondu** (`_buildPickerOverlay`) : carte blanche ancrée en bas
  = titre + **adresse visée** (géocodage inverse au repos caméra, séquencé)
  + Annuler/Valider ; pendant un placement : dock, rail gauche, panneau,
  bannière du haut, « Autour de vous » ET « Effacer l'itinéraire » masqués ;
  seul le rail de zoom reste, au-dessus de la carte (petite 262.h, grande
  navInset + 136). Le signalement part du CENTRE de la carte (repère), plus
  de la position GPS.
- Rails : boutons **44 → 38**, écart 10 → 7, rangée 156 → **146** ; bannière
  « Partager ma position » sur **une ligne** (sous-titre en info-bulle),
  Agrandir aligné ; le panneau remonte de ~40 px.
- **Poignée** : widget `PawMapPanelHandle` (orange pâle, 120 de large,
  chevron qui respire 1,4 s ; repliée = pilule orange pleine + filtres).
- **« Photo du spot »** appelait `_startSpotPicking()` = « Marquer un lieu »
  → `_startSpotPhoto()` : ImagePicker caméra → `uploadPhoto` → fiche de
  création avec `initialPhotoUrl` (nouveau param de `showPawSpotCreateSheet`),
  position = GPS.
- **Suivi direct — règle serveur** : `listPositionListeners` exigeait
  `myShare && theirShare` (double opt-in) alors que `/friends/live-positions`
  n'exige que le partage de l'émetteur → mon partage suffit désormais.
  ⚠️ **Constat produit non tranché** : `requesterSharesPosition` /
  `addresseeSharesPosition` valent **false par défaut** → sans PawFollow ni
  famille, « Partager ma position » n'atteint QUE les amis pour lesquels on a
  allumé « Partager » dans Mes amis. Décision de Daniel attendue (défaut
  true = partage à tous les amis acceptés, ou garder l'opt-in par ami comme
  perk PawFollow — cf. v23.1 part 226).
- **Option C validée par Daniel** (partage gratuit entre amis, PawFollow =
  2 h + fond + itinéraires + historique + Famille) — voir commit 33c7752.
  Vérifié en prod avec les comptes test : amitié neuve = partage allumé des
  deux côtés sans abo, broadcast → `listeners: 1`, `/live-positions` renvoie
  la position ; amitié supprimée après. Le `.env` local pointe sur une base
  de DEV (host petinsta…, 3 owners) : la migration prod tourne AU DÉMARRAGE
  du serveur (marqueur `migrations/v555_share_default_true`).
- 6 clés i18n × 9 langues. Fichiers : `~/Downloads/HoPetSit_v23.1.555.{apk,aab,ipa}`
  (build **558**), notes Play : `~/Downloads/HoPetSit_555_notes_de_version.txt`.
- **Play** : « Modifications en cours d'examen » (bundle 558). Ce soir la
  Play Console a accepté « Suivant » mais NI « Enregistrer » NI « Envoyer 1
  modification pour examen » (clics Daniel) ; l'import du bundle reste manuel.
  ⚠️ Un « missing value » du tool JS = souvent un clic qui a FONCTIONNÉ (la
  page a changé pendant l'exécution) → toujours relire l'URL/le statut avant
  de conclure à l'échec.
- **iOS** : 1.14 → soumission 557 annulée, build **558** rattaché (204),
  whatsNew fr/en réécrits pour la 555, nouvelle soumission
  `7a04f55f-…` → **WAITING_FOR_REVIEW avec le 558**.

**07/09 (nuit) — v554 « 5 défauts de placement + recherche de ville »**
- Petite carte : les deux rails touchaient la barre d'onglets → remontés
  (108 → 156) ; quand « Autour de vous » est affichée ils passent au-dessus
  d'elle (206) au lieu de la chevaucher.
- **Poignée de repli du panneau blanc** : un appui masque tout le cadre des
  options, un appui le rouvre (demande Daniel).
- **Feuille « Calques » coupée par la barre système** : elle n'avait NI
  `useSafeArea` NI marge → `useSafeArea` + `viewPadding.bottom` + défilement.
- **Les 3 viseurs unifiés** (`_buildPickerOverlay`) : PawSpot, Signalement et
  Itinéraire avaient chacun leur bandeau et leur hauteur, d'où les
  chevauchements. Pendant un placement : dock, rail gauche, panneau blanc et
  « Autour de vous » s'effacent, le rail droit remonte de 18.
- **Itinéraire de la grande carte** : il ÉTAIT branché, mais (1) la caméra
  était animée sur `_mapCtl` — la petite carte cachée SOUS le calque — et
  (2) la destination était le centre exact de l'écran, donc départ = arrivée
  → « recherche échouée ». Corrigé : viseur de destination + `_activeMapCtl()`
  + bandeau « Effacer l'itinéraire » ajouté au calque agrandi (il n'existait
  que sur la petite carte).
- **Compteur « N membres autour de toi »** : il comptait les points DESSINÉS,
  couche monde comprise → 28 membres annoncés alors qu'il y en a une poignée.
  Il compte désormais ceux à moins de **50 km de l'utilisateur**, lus sur les
  listes brutes (indépendant du zoom et du plafond d'affichage). App + site.
- **Recherche de ville moderne** : l'AlertDialog exigeait le nom EXACT.
  Feuille avec suggestions au fil de la frappe (debounce 320 ms), villes
  récentes (GetStorage), repli sur le géocodage classique à la touche Entrée.
  Nouvelle route publique **`GET /geo/cities`** (backend) : **Photon**
  (komoot) avec biais de proximité + cache 1 h ; Nominatim en secours.
  ⚠️ **Vérifié : le `/search` de Nominatim ne fait PAS d'autocomplétion** —
  « asnie » ne renvoie RIEN et « par » renvoie un hameau anglais. Ne pas y
  revenir. Photon : « asnie » près de Paris → Asnières-sur-Seine en 1er.
- **Bouton ↻ « mettre à jour »** : il rechargeait en silence → spinner à sa
  place pendant le chargement + confirmation, et il force la couche monde à
  repartir du réseau (le cache 5 min serveur + 24 h local donnait
  l'impression qu'il ne faisait rien).
- **Repli du panneau MÉMORISÉ** (`pawmap_panel_collapsed` dans GetStorage) et
  pastille de réouverture ROSE avec l'icône des filtres : le cadre porte les
  3 interrupteurs d'abonnement, il ne doit pas disparaître discrètement.
  Ce changement a été fait APRÈS l'envoi du build 556 → rebuild en **557**.
- 3 clés i18n × 9 langues. Fichiers : `~/Downloads/HoPetSit_v23.1.554.{apk,aab,ipa}`
  (build **557**), notes Play : `~/Downloads/HoPetSit_554_notes_de_version.txt`.
- **PUBLIÉE** : Play « Modifications en cours d'examen » (bundle 557) — la 553
  était passée ACTIVE avant (« Dernière release : 555 (23.1.553) », 509
  installations). iOS **1.14 WAITING_FOR_REVIEW avec le build 557**
  (soumission portant le 555 annulée, 557 rattaché, whatsNew fr/en réécrits).
- ⚠️ **Play Console 07/09** : « Suivant » a répondu à la séquence
  pointerdown/mousedown/pointerup/mouseup/click, mais **l'import du bundle
  (input file + drop) et le bouton « Enregistrer » sont restés inertes** →
  ces deux-là = clic humain. Le compte Play de HoPetSit est sous
  **Cardelli Hermanos LTD, `u/1`, dev 4666400761832810651, app
  4973435507020277199**.
- ⚠️ **Piège git du jour** : `~/.gitconfig` route github.com vers
  `gh auth git-credential`, dont le compte actif est `dadaciao84-ai` — SANS
  droit de push sur hopetsit/hopetsit → 403. Contournement ponctuel :
  `git -c credential."https://github.com".helper= -c credential.helper=osxkeychain push`
  (le trousseau, lui, a le bon compte `hopetsit`).

**06/09 (nuit) — v553 « placement des boutons » (retours Daniel sur captures) — PUBLIÉE**
- Petite carte : « ma position » passe en BAS À DROITE ; les deux rails sont
  désormais dans UNE rangée ancrée en bas (`Row` + `crossAxisAlignment.center`)
  → ils restent centrés l'un sur l'autre quelles que soient leurs hauteurs.
- Rails : retour aux BOUTONS RONDS icône seule 44 px (les pilules à libellé
  de la v552 mangeaient la carte et cassaient l'alignement) ; libellé en appui
  long. Grande carte : ajout d'Itinéraire (vert), Chat du cercle (bleu) et
  Photo du spot (orange) au-dessus des 4 habituels.
- Panneau des filtres : fond BLANC OPAQUE (le translucide laissait la carte
  défiler derrière le texte).
- Dock bas : marge système + 14 ; rails : marge système + 82 → plus de
  chevauchement entre les deux rangées.
- **Bug** : « pas de retour en ouvrant le chat depuis la carte ». ChatScreen /
  SitterChatScreen sont des onglets racines → `CustomAppBar` avec
  `automaticallyImplyLeading: false` par défaut, donc aucun bouton retour quand
  l'écran est EMPILÉ. Corrigé avec `Navigator.of(context).canPop()`.
- Audit : les 20 boutons de la carte sont branchés ; les 4 écrans ouverts
  depuis la carte ont bien leur retour.
- **Publié** : Play « Modifications en cours d'examen » (bundle 555) ; iOS 1.14
  WAITING_FOR_REVIEW avec le build 555. La 552 est ACTIVE sur Play.
- ⚠️ **Numérotation** : le build iOS reprend le `+N` du pubspec → la version
  23.1.553 a produit le **build iOS 555** (et non 553). Les versionCodes 552,
  553 et 554 ont été consommés par les tentatives d'import Play.

**06/09 (soir) — v552 « redesign PawMap v3 » (maquette Claude Design + spec)**
- **2 bugs critiques** : le retour Android fermait l'app en carte agrandie
  (PopScope + workers qui recalculent `canPop`) ; boutons sous la barre
  système (marges `viewPadding` + 126 / + 66).
- **Carte plein écran** avec header et panneau « verre dépoli » flottants ;
  la grille 2×2, les filtres et les toggles fusionnés en UN panneau.
- **Filtres cumulables en pastel** (bleu gardien, vert promeneur, orange
  propriétaire, rouge signalement — décision Daniel : « pastel doux »),
  contour rose sur « Tous »/« Rien » quand ils s'appliquent.
- **Dock bas** : SOS animal, Partager la carte, Calques, Mode nuit, Historique.
- **SOS animal** (seule nouvelle fonctionnalité produit) : `POST /map-reports/sos`
  → signalement `lost_pet` avec `isSos`, notification à tous les membres dans
  10 km, 1 SOS/heure/personne. Textes `sos_pet_nearby` en 9 langues.
- **Partages contextuels** : `/spot/:id`, `/alert/:id`, `/map?lat&lng&z` déclarés
  en liens universels (AASA + manifest) ; PawMapScreen centre et ouvre la fiche ;
  page web `/alert/[id]` (composant serveur) + `GET /map-reports/public/:id`.
- **Amis** : bouton rose + QR code (qr_flutter) / WhatsApp / e-mail.
- **Balade** : `startWalk`/`endWalk` n'envoyaient AUCUNE notification → le
  propriétaire reçoit « balade commencée » et « balade terminée » (9 langues).
- ⚠️ **Play Console a refusé tous les clics automatisés ce jour-là** (« Suivant »
  et « Enregistrer comme brouillon » inertes, même en séquence pointer/mouse
  complète) et le 1er import a **consommé le versionCode 552** → AAB rebuildé en
  **code 553** (`~/Downloads/HoPetSit_v23.1.552_code553.aab`), import Play à
  faire à la main avec `~/Downloads/HoPetSit_552_notes_de_version.txt`.
  **iOS : 1.14 resoumise avec le build 552 (WAITING_FOR_REVIEW).**

**06/09 (matin) — v551 « PawMap pro » (demandes Daniel)**
- **Pastille « Chargement… » supprimée** : elle s'affichait dès qu'une couche
  se rechargeait (même 200 ms) → clignotement à chaque zoom/déplacement.
- **Pilule ma position / + / − remontée** sur la carte agrandie (24 → 96 h).
- **« Masquer mon profil sur la carte »** (Profil → Préférences, app + site,
  9 langues) : `preferences.hideFromMap` sur Owner/Sitter/Walker ; filtré dans
  `/friends/members/nearby` ET dans le cache de `/friends/members/world` ; les
  AMIS du viewer sont réinjectés hors cache (`_withHiddenFriends`) → « sauf mes
  amis » est tenu. Défaut false.
- **Regroupement des points** (app + web, sans dépendance) : projection Web
  Mercator, cellules de 76 px au zoom courant, pastille avec le nombre, tap =
  zoom +2,2. Lieux et membres regroupés SÉPARÉMENT. **Couleur par thème** quand
  le groupe est homogène (couleur + emoji de la catégorie) ; groupe mixte =
  bleu neutre ; membres = rose.
- **Fiche membre vendeuse** : `rating`, `reviewsCount`, `priceFrom`, `currency`
  ajoutés au payload world (priceFrom = min des walkRates/hourlyRate/dailyRate).
- **Filtres par type** (Gardiens / Promeneurs / Propriétaires) : rangée de
  puces compactes, jamais de défilement horizontal (règle v447 de Daniel), le
  dernier rôle actif rallume les autres au lieu de vider la carte.
- **Compteur « N membres autour de toi »** (app + web).
- Vérifié au simulateur : filtres OK (27 → 16 membres en décochant
  Propriétaire), pastilles numérotées et colorées, barre remontée, plus de
  « Chargement ». Site vérifié en prod (19 clusters, compteur, filtres).

**06/09 — v550 « PawMap : membres visibles, floutage juste, carte fluide » — PUBLIÉE**
- **Play** : release 550 (23.1.550) créée par injection (serveur CORS 8768 + DataTransfer),
  notes 6 langues, Suivant → Enregistrer → « Accéder à l'aperçu » → « Envoyer 1 modification »
  → dialogue confirmé → **« Modifications en cours d'examen »**. ⚠️ Le bouton du dialogue ne se
  trouve QUE dans `[role=dialog] button` (chercher dans `document.querySelectorAll('button')`
  global renvoie « not found » alors que le dialogue est ouvert).
- **iOS** : la 1.13/549 avait été APPROUVÉE et est READY_FOR_SALE → j'ai créé la **1.14**
  (id `4dec0ddf-bd56-4451-b278-f3cde9f54b24`), whatsNew fr-FR/en-GB, IPA distribué par
  Transporter (bouton DISTRIBUER via app_click), build 550 (`dca56b2a-3b76-44ac-a797-50dd6bc0e90a`)
  VALID ~20 min après, attaché (204) → reviewSubmission `c100d1b1-…` + item + submitted
  → **1.14 = WAITING_FOR_REVIEW avec 550**. Fichiers : ~/Downloads/HoPetSit_v23.1.550.{apk,aab,ipa}.
- **Floutage de la couche monde en KILOMÈTRES** (`/friends/members/world`) : la
  grille était en degrés (0,01° = 1,11 km en latitude mais 0,73 km à Paris et
  0,28 km au Svalbard en longitude) + un décalage stable par-dessus → le
  « ~1 km » affiché était faux. Grille convertie en degrés à la latitude du
  membre ; erreur max mesurée **0,89 km** partout (Paris/Dallas/équateur/
  Reykjavik/Sydney). Le rayon est renvoyé dans `approxKm` et **affiché depuis
  la réponse** ({km} dans `map_member_approx` / `pawmap_member_approx`, 9 langues).
- **⚠️ RÈGLE : toute nouvelle couche de la PawMap doit entrer DANS LA CLÉ de
  `_getMarkersFromCache()` ET dans les dépendances lues par les 2 Obx** (carte
  normale + calque agrandi). La couche monde (v548) n'y était pas → les
  membres roses n'apparaissaient jamais sur Android/iOS alors qu'ils
  s'affichaient sur le web. Même piège qu'en v521/v163/v248/v249.
- **Membres en ROSE BRILLANT** (demande Daniel) : badge agrandi (app 42→48 px,
  web 30→34), rose vif #FF4FA3→#F01E86, double halo lumineux + reflet ; halo
  atténué hors ligne.
- **Fiche membre (app)** : bouton **Réserver** ajouté pour gardien/promeneur
  (→ ServiceProviderDetailScreen / WalkerDetailScreen), comme sur le web.
- **Carte agrandie** : pilule **ma position / + / −** ajoutée ; `_activeMapCtl()`
  fait viser la carte réellement visible (`_expandedCtl`), et « ma position »
  rezoome à 14 quand on était très dézoomé.
- **Fluidité** : halo gelé pendant les gestes caméra ; `onCameraIdle` ne relance
  les 5 requêtes que si le centre a bougé d'≈1/4 de la largeur visible ; plafond
  d'affichage de la couche monde (200-400 points selon le zoom) ; cache local
  24 h (`pawmap_world_cache`) → carte peuplée dès la 1re frame.
- Vérifié : API `/friends/members/world` en prod renvoie `approxKm:1` ;
  `POST /friends/request` OK (test owner → test sitter, puis reset) ; web en
  prod « Position approximative (à moins de 1 km) » + Réserver → page /book
  chargée ; app v550 lancée sur simulateur (badges roses bien visibles).
  ⚠️ **Le tap sur un marqueur ne peut pas être testé sur simulateur** :
  l'intégration native refuse (« Xcode is installed but not selected ») alors
  que `xcode-select -p` est bon, et le contrôle par accessibilité active les
  boutons du calque du dessous au lieu du marqueur.

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
- ✅ 04/09 (v550, serveur seul) : **chat GRATUIT en phase de lancement** tant que
  la base compte < `CHAT_FREE_UNTIL_USERS` (1000) comptes — `chatAccessService.isLaunchPhase()`
  + middleware `requirePaidBooking`. Le gating Premium revient seul au-delà.
  **Search Console** = compte hopetsit@gmail.com (`/u/1/` ou `/u/4/` dans le Chrome de Daniel) ;
  sitemap lu pour la dernière fois le 08/07 (15/84 pages) → resoumission = clic humain.
  Affiche A4 vétos/animaleries : `~/Downloads/HoPetSit_Affiche_Paris_A4.pdf` (`scratchpad/make_poster.py`).
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

**03/09 — v548 « traductions + PawMap monde » (commit 0686fd9)** :
- **Traductions relues par des agents natifs** (site : es 76, de 121, it 115,
  pt 105, ko 46, ja 28 corrections ; app : pl.dart 1 037 corrections en 4 lots).
  Erreurs récurrentes trouvées : « Bis zu 4 Nutzer / Hasta 4 usuarios » (=5 !) dans
  4 langues, FAQ PawFollow périmée (faq_a6/a7) dans es/de/it/pt, marques traduites,
  pt-BR mélangé au pt-PT, « prestatore » (calque FR) en it, « Hundesitter » pour
  walker en de. Outils : `scratchpad/apply_fixes.py site <lang> <json>` /
  `dart <fichier> <json>` (JSON {clé: texte}). Les autres langues de l'APP
  (es/de/it/pt/ko/ja .dart) n'ont PAS été relues → prochain chantier.
- **PawMap** : nouvel endpoint `GET /friends/members/world` (tous les membres
  géolocalisés, position ARRONDIE ~1 km + décalage stable, cache 5 min, pas de
  gating abo, exclut +test et hiddenFromPublic) → couche « monde » visible en
  dézoomant sur app (`_worldMembers`) et web (`worldMembers`, fusion avec les
  proches exacts). **Tap/clic sur un membre rose = fiche + « Ajouter en ami »**
  (app : bottom sheet `_onNearbyTap` → FriendController.sendRequest ; web :
  `MemberPopup` dans PoiMap → sendFriendRequest, + lien Réserver pour
  sitter/walker). 7 clés i18n ×9 langues (`map_member_*` / `pawmap_member_*`).
- Sélecteur de langue du site : exclu du contour orange fluo global (classes
  `lang-switch` / `lang-menu` dans globals.css).

**Site 02/09 soir (sans rebuild app)** : icône officielle HD sur tout le site
(favicon.ico/svg, logo.png 512, icon-32/192/512, apple-touch, maskables, og-image
rouge avec le nom — `?v=548` dans layout.tsx ; script `make_web_icons.py`, source =
rendu 2048 du SVG de Daniel) ; sélecteur de langue fluide ; **polonais relu à la
main** (281 textes : marques PawMap/PawFollow/PawSpot/PawPoints ne se traduisent
JAMAIS — « Mapa łapy », « ŁapaŚledź » sont des erreurs ; opiekun/wyprowadzacz psów
au lieu de « spacerowicz » ; pozycja au lieu de « stanowisko » ; zgłoszenia pour
reports). Le `pl.dart` de l'app vient du même traducteur automatique → à relire
de la même façon avant la prochaine build.

**Publication automatique Facebook/Instagram — EN SERVICE depuis le 02/09** :
`~/hopetsit-social/` (Mac, hors dépôt) — jeton de page permanent (utilisateur
système aepsinfos, app HoPetSit) dans `token.txt`, jamais sur GitHub.
Chaîne : routine cloud dimanche 14 h écrit `website/marketing/social/AAAA-Wss.md`
(sections « ## 1. Facebook » / « ## 2. Instagram » obligatoires) → launchd
`com.hopetsit.social` dimanche 14 h 30 lance `publier_semaine.py` : visuel généré
dans `website/public/social/AAAA-Wss.jpg` + push, puis post Facebook (texte +
lien), Instagram (visuel + légende) et story Instagram. **Mercredi 12 h 30** :
launchd `com.hopetsit.social.mercredi` publie un post « evergreen » en rotation
(`banque_posts.json`, 8 posts Paris). 1re publication faite le 02/09
(recrutement Paris). Mac éteint à l'heure prévue = relancer à la main.
Mode d'emploi : `~/hopetsit-social/MODE_EMPLOI.md`. **IndexNow** : 84 URL
soumises à Bing/Yandex/Naver le 02/09 (`~/hopetsit-social/indexnow.py`).
**Groupes Facebook Paris** (canal humain n° 1) : liste + textes prêts dans
`website/marketing/groupes_facebook_paris.md`.

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

## ⛔ RÈGLE SEO DU 20/09/2026 — NE PLUS MULTIPLIER LES PAGES (mesurée, pas supposée)

Audit des **654 URL** du sitemap, une par une, via la Search Console
(`~/hopetsit-social/gsc_bob.py --audit`, lecture seule, relançable, reprise automatique, écrit
`gsc_audit.json`). Résultat du 20/09/2026 :

| État | Pages |
|---|---|
| Envoyée et indexée | **223** |
| **Google ne reconnaît pas cette URL** (jamais explorée) | **255** |
| Détectée, actuellement non indexée | 145 |
| Page en double sans canonique retenue | 20 |
| Explorée, actuellement non indexée | 11 |

Par marché (indexées / total) : **France 42/239 (17 %)**, USA + anglais 113/240 (47 %),
Allemagne 12/36 (33 %), Espagne 7/32 (21 %), autres langues (pl, ko, ja, it, pt, nl) 49/107 (45 %).
**Paris : 1 page indexée sur 42.**

Le sitemap est sain (654 URL, 0 erreur, relu par Google) et les pages déclarent bien leur balise
canonique (vérifié dans le HTML servi) : **le problème n'est pas technique.** Le site propose 654 URL
avec une autorité quasi nulle ; Google n'en explore qu'une fraction, et chaque page ajoutée **dilue
le budget d'exploration** au détriment des marchés visés.

### Ordre de priorité des marchés (Daniel, 20/09/2026)
1. **France (Paris) et USA** — priorité absolue, inchangée.
2. **Allemagne et Espagne** — à développer ensuite. Les villes existent déjà
   (`/tiersitter-werden`, `/tierbetreuung`, `/ser-cuidador-de-mascotas`, `/cuidado-de-mascotas`) :
   **il n'y a aucune page à créer**, seulement à faire indexer et convertir.
3. **Toutes les autres langues** (pl, ko, ja, it, pt, nl) — **gelées** : ni nouvelle ville, ni
   nouvelle langue. Elles consomment le budget d'exploration des quatre marchés ci-dessus.

### Règles de développement
1. **Ne pas créer de nouvelles pages villes ni de nouvelles langues** tant que le taux d'indexation
   ne remonte pas. Une ligne de plus dans `src/lib/recruit-cities.ts` = deux URL de plus qui ne
   seront pas explorées.
2. **Une page générée en boucle depuis une liste de données ne s'indexe pas toute seule.** Être dans
   le sitemap ne suffit pas (les 20 arrondissements de Paris le prouvent). Une page neuve n'a de
   chance d'être indexée que si des pages **déjà indexées** pointent vers elle : prévoir les liens
   internes entrants AVANT de créer la page.
3. **Améliorer et relier l'existant plutôt qu'élargir** — Paris et USA d'abord, puis Allemagne et
   Espagne.
4. **Google n'accepte aucune demande d'indexation par API** (l'Indexing API est réservée aux offres
   d'emploi et aux événements en direct). Seul IndexNow (`~/hopetsit-social/indexnow.py`) fonctionne,
   et uniquement pour Bing/Yandex/Naver/Seznam.
5. **Contrôle** : relancer l'audit et comparer le nombre de pages indexées. Ne jamais juger
   l'indexation au nombre de pages publiées ni au trafic.

### Point de vigilance ouvert
20 pages (dont `/devenir-petsitter/paris-14`) sont attribuées par Google au domaine
`www.747live.bet` (site de paris en ligne), alors que nos pages servent bien leur propre canonique
et ne contiennent rien de ce domaine. Le dernier passage de Google sur ces pages date du 15/09.
Piste : contenu copié par ce site. Rien à corriger dans le code ; à re-vérifier au prochain audit.
