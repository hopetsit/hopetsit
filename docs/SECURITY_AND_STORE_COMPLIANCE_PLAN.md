# Plan — Vraie vérification d'identité, modération de contenu et conformité Play Store / App Store

**Rédigé : 18 avril 2026 (session v3.2)**

Ce document regroupe 3 chantiers distincts mais liés côté risque produit :

1. **Vérification d'identité automatisée et fiable** des sitters + walkers (aujourd'hui n'importe quelle photo passe)
2. **Modération automatique de contenu** (filtre pornographie / violence sur photos de profil, posts, attachments de chat)
3. **Conformité Play Store + App Store** avant publication

---

## 1. Vérification d'identité — options techniques

### Objectif
- Confirmer que le document envoyé est bien un ID officiel (carte / passeport / permis)
- Comparer le visage du document avec un selfie live (anti-usurpation)
- Retourner un verdict `verified | rejected | manual_review` automatiquement
- Archiver les résultats pour audit (nécessaire PDPO HK + RGPD)

### Options par ordre de recommandation

#### Option A — **Stripe Identity** (recommandé pour cohérence stack)
- **Pricing** : ~1,50 $ par vérification (Europe), 2 $ (autres pays). Volume : 0–100/mois = 0 coût mensuel en plus du pay-per-verification.
- **Intégration** : SDK officiel + VerificationSession côté backend. Stripe gère OCR, liveness check, face match. Retour synchrone dans ~30 s.
- **Avantages** : déjà intégré à Stripe (même dashboard, mêmes webhooks), conforme RGPD, documents stockés chez Stripe (moins de responsabilité légale côté nous).
- **Inconvénients** : moins granular que Onfido sur les pays exotiques ; pas encore super solide sur les pièces d'ID asiatiques.
- **Implémentation backend** : 1 endpoint `POST /walkers/identity-verification/session` qui crée une `VerificationSession`, frontend présente le client_secret dans le SDK Stripe Identity, webhook `/webhooks/stripe-identity` reçoit le verdict et met à jour `identityVerification.status`.
- **Temps dev estimé** : 2–3 jours (backend + frontend + webhook + tests).

#### Option B — **Onfido** (gold standard)
- **Pricing** : 0,40–1,80 £ par vérification selon forfait. Minimum 500 £/mois en Enterprise.
- **Avantages** : coverage mondiale excellente (195+ pays), face match très précis, SDK mobile natif.
- **Inconvénients** : minimum mensuel cher pour une petite app, contrat commercial obligatoire.
- **Quand choisir** : > 500 vérifications/mois ou si on cible l'Asie intensivement.

#### Option C — **Persona** (alternative moderne)
- **Pricing** : ~1 $ par vérification, pas de minimum.
- **Avantages** : bonne UX, customisable par étapes (document only, doc + selfie, doc + selfie + govt database).
- **Inconvénients** : coverage moins large que Onfido.

#### Option D — **Manuelle + OCR maison** (pas recommandé)
- Stack : Google Vision OCR + face-api.js pour le match.
- **Pricing** : Google Vision ~1,50 $/1000 appels. Coût réel : notre temps de dev (~2 semaines) + modérateurs humains.
- **Inconvénients** : zéro liveness check fiable, face match maison facilement contournable (photo d'une photo).

### Recommandation
**Stripe Identity** pour v3.3 (cohérent avec le reste de la stack, pay-per-use, setup rapide). Migrer vers Onfido plus tard si le volume justifie (> 500 vérifs/mois).

### Changements nécessaires côté code
- `backend/src/services/stripeIdentityService.js` — wrapper
- `backend/src/routes/identityVerificationRoutes.js` — 2 endpoints (create session + webhook)
- `backend/src/models/Sitter.js` + `Walker.js` — ajouter `identityVerification.sessionId`, `identityVerification.verdict`, `identityVerification.details`
- `frontend/lib/views/pet_sitter/profile/identity_verification_screen.dart` — remplacer simple upload par Stripe Identity SDK
- Ajouter `stripe_identity` ou `flutter_stripe_identity` dans `pubspec.yaml`

---

## 2. Modération automatique de contenu (pornographie, violence, haine)

### Objectif
- Filtrer les photos de profil (avatar owners/sitters/walkers)
- Filtrer les photos de pet profiles
- Filtrer les attachments de messages chat
- Filtrer les photos attachées aux signalements PawMap
- Filtrer les médias des posts
- Rejeter automatiquement à l'upload + notifier l'admin

### Options

#### Option A — **Google Cloud Vision Safe Search** (recommandé)
- **Pricing** : 1 500 $/mois gratuit (premier 1000 appels), puis 1,50 $ / 1000 images.
- **Détection** : adult, violence, medical, spoof, racy (5 niveaux : VERY_UNLIKELY → VERY_LIKELY).
- **Intégration** : SDK Node ou REST. À ajouter dans l'upload pipeline (Cloudinary hook ou service custom).
- **Temps dev** : 1 jour.

#### Option B — **AWS Rekognition** (équivalent)
- **Pricing** : similaire (1 $/1000 images).
- **Détection** : "Detect Moderation Labels" (Explicit Nudity, Violence, etc.).
- **Avantage** : si on utilise déjà AWS ailleurs. Sinon indifférent.

#### Option C — **Cloudinary add-on** (simpliste si on utilise déjà Cloudinary)
- **Pricing** : AWS Rekognition ou Google Vision add-on intégré dans Cloudinary, ~50 $/mois.
- **Avantage** : un seul endroit, détection automatique à l'upload, tag `rekognition=unsafe` appliqué au média.
- **Inconvénient** : cher si peu de volume.

### Recommandation
**Google Cloud Vision Safe Search** côté backend dans un hook post-upload Cloudinary. Flow :

1. User upload → Cloudinary stocke
2. Cloudinary webhook nous notifie du nouvel asset
3. Backend call Vision Safe Search sur l'URL
4. Si `adult=LIKELY|VERY_LIKELY` ou `violence=LIKELY|VERY_LIKELY` → suppression Cloudinary + flag user + notif admin
5. Sinon → média publié

### Changements code
- `backend/src/services/contentModerationService.js` — wrapper Vision API
- Ajouter un middleware `requireSafeContent` dans les routes d'upload (profile picture, post media, chat attachment, report photo)
- `backend/src/models/ModerationEvent.js` — model pour l'audit (qui, quand, quel média, verdict)
- Nouvelle page admin `moderation-events` pour voir l'historique

---

## 3. Conformité Play Store + App Store

### Google Play Console

#### Obligatoire avant publication (Play Store)

- **Privacy Policy URL publique** (on l'a désormais : `/privacy-policy/:lang` + texte HK rédigé)
- **Data safety form** : déclarer toutes les données collectées (location, photos, identity, payment, messages)
  - Location : Collected, Shared with Stripe, Cloudinary
  - Photos : Collected, Optional, Shared with Cloudinary
  - Identity docs : Collected, Encrypted in transit and at rest, Deleted on request
  - Financial info : Not collected (passes through Stripe)
  - Messages : Collected, Encrypted in transit
- **Target API level** : 34 ou plus récent (obligatoire Aug 2024+)
- **Age rating** : IARC questionnaire → probable rating 12+ (chat + géoloc)
- **Account deletion in-app** : obligatoire depuis 2024. Vérifier que `/users/me` DELETE est bien câblé côté UI
- **App category** : Lifestyle ou Pets
- **Content rating** for pet photos + user-generated content → ACTIVER la modération Vision Safe Search avant publication (conformité User-Generated Content policy)

#### Risques
- **User-Generated Content policy violation** si pas de modération porno → refus immédiat
- **Data safety false declaration** → 1 strike, 2e = suspension
- **Background location** (notre tracking "Suivre mon animal") → justification requise dans la fiche, ou retirer la permission `ACCESS_BACKGROUND_LOCATION`

### Apple App Store

#### Obligatoire avant publication (App Store)

- **Privacy Policy URL publique**
- **App Privacy Labels** (Nutrition Label) : déclarer chaque type de données avec usage (Tracking/Third-Party Advertising/Analytics/App Functionality)
- **Sign in with Apple** obligatoire si on a Google Sign-In (déjà intégré : vérifier)
- **Account deletion in-app** (obligatoire depuis juin 2022)
- **Age rating** : questionnaire → probable 12+
- **In-app purchases** : Premium + Chat add-on + Boost **DOIVENT** passer par Apple IAP (StoreKit) si c'est du contenu digital, pas Stripe directement
  - ⚠️ **Risque critique** : actuellement tout passe par Stripe. Apple peut refuser l'app.
  - **Option 1** : Migrer les in-app purchases digitaux vers StoreKit (~1 semaine de dev).
  - **Option 2** : Considérer que Premium/Boost/Chat unlocks ne sont pas des "digital services" mais des "premium app features" — zone grise, risque de refus.
  - **Option 3** : Retirer les purchases de l'app iOS et rediriger vers le web (modèle Netflix) — pénible UX.
  - **Recommandation** : StoreKit pour Premium, Chat add-on, Map Boost. Boost profile peut rester Stripe si on argumente "service de visibilité marketing" (zone grise).
- **Background location** : même règle que Android, justification dans Info.plist

#### Risques
- **Apple IAP non-compliance** → rejet quasi systématique
- **Pas de Sign in with Apple** si Google Sign-In présent → rejet
- **Trackers déclarés dans privacy labels** sans consentement utilisateur → rejet

### Checklist avant soumission (à cocher)

- [ ] Privacy Policy et T&C publiés + URL publique accessible
- [ ] Account deletion in-app implémenté et testé
- [ ] ID verification automatique active (Stripe Identity ou équivalent)
- [ ] Content moderation active (Vision Safe Search)
- [ ] Data safety form Android rempli honnêtement
- [ ] Privacy Nutrition Labels iOS remplis
- [ ] Sign in with Apple présent si Google Sign-In présent
- [ ] Background location permission justifiée ou retirée
- [ ] IAP Apple StoreKit pour Premium / Chat add-on / Map Boost (ou scope revu)
- [ ] Target API 34+ Android
- [ ] Tests sur devices réels Android + iOS
- [ ] App icons + screenshots dans toutes les tailles requises
- [ ] Textes store descriptifs en 6 langues
- [ ] Support email actif (support@hopetsit.com)
- [ ] RGPD compliance check : bandeau cookies/trackers, consent management
- [ ] PDPO Hong Kong compliance : mention DPO + droits utilisateurs dans app settings

---

## Chiffrage total (ordre de grandeur)

| Chantier | Temps dev | Coût externe |
|---|---|---|
| Stripe Identity | 2–3 jours | ~1,50 $/vérification |
| Content moderation (Vision Safe Search) | 1–2 jours | 1 000 images = 1,50 $ après gratuit |
| StoreKit iOS pour IAP | 4–5 jours | 30 % de commission Apple sur purchases iOS |
| Privacy labels + data safety form | 0,5 jour | gratuit |
| Account deletion (si pas déjà OK) | 0,5 jour | gratuit |
| Sign in with Apple (si manquant) | 1 jour | gratuit |
| Tests + polish store | 2 jours | gratuit |
| **TOTAL** | **~11–14 jours de dev** | ~50–100 $/mois en coûts externes (variable selon volume) |

## Ordre de priorité proposé

1. **Content moderation** d'abord — c'est ce qui empêche le refus immédiat Play Store pour UGC.
2. **Stripe Identity** ensuite — permet de lancer les prestataires en confiance.
3. **Privacy Policy + T&C publiés** (fait côté admin v3.2 ✓ — reste à y coller les textes français/anglais).
4. **Account deletion in-app** — vérifier qu'il est bien accessible depuis Profil > Zone danger.
5. **Data safety + Privacy Labels** — remplissage au moment de soumettre.
6. **StoreKit iOS** — dernière étape, juste avant la soumission iOS.
