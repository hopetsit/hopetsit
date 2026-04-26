# AUDIT EXHAUSTIF STRIPE — HopeTSIT Purge Totale

**Date:** 2026-04-26  
**Objectif:** Inventaire complet de tous les fichiers/champs Stripe en vue d'une suppression totale.

---

## 1. BACKEND — ROUTES (5 fichiers)

### ✓ SUPPRIMER
- **`backend/src/routes/stripeConnectRoutes.js`** (143 lignes)
  - 5 endpoints : `/create-account`, `/create-account-link`, `/account-status`, `/return`, `/refresh`
  - Dédié 100% Stripe Connect onboarding (sitter/walker)

- **`backend/src/routes/stripeWebhookRoutes.js`** (47 lignes)
  - Webhook `/webhooks/stripe` (raw body handler, signature verification)
  - Dédié 100% Stripe

- **`backend/src/routes/identityVerificationRoutes.js`** (166 lignes)
  - POST `/identity-verification/session` → crée session Stripe Identity
  - POST `/identity-verification/webhook` → Stripe appelle pour updates
  - Dédié 100% Stripe Identity

### ✓ NETTOYER
- **`backend/src/routes/ownerPaymentsRoutes.js`**
  - Ligne à vérifier : contient route payment owner (peut aussi avoir Airwallex)

- **`backend/src/routes/bookingRoutes.js`**
  - Peut contenir route vers stripeWebhookController ou stripeConnectController à nettoyer

---

## 2. BACKEND — CONTROLLERS (8 fichiers)

### ✓ SUPPRIMER
- **`backend/src/controllers/stripeConnectController.js`** (420 lignes)
  - `createStripeConnectAccount()`, `createStripeAccountLink()`, `getStripeAccountStatus()`, etc.
  - Dédié 100% Stripe Connect

- **`backend/src/controllers/stripeWebhookController.js`** (438 lignes)
  - `handleStripeWebhook()` → processe tous les événements Stripe (payment_intent, charge, etc.)
  - Dédié 100% Stripe webhooks

### ✓ NETTOYER
- **`backend/src/controllers/bookingController.js`**
  - Chercher : `stripePaymentIntentId`, `stripeChargeId`, `stripeSessionId`
  - Probable : création/update booking lie à paiement Stripe (logic métier peut rester, refs Stripe enlever)

- **`backend/src/controllers/ownerPaymentsController.js`**
  - Chercher : logique "owner payment" → probablement mixte Stripe + Airwallex
  - NETTOYER uniquement les branches Stripe

- **`backend/src/controllers/walletController.js`**
  - Peut contenir logique rechargement portefeuille (Airwallex ?)
  - Vérifier references Stripe

- **`backend/src/controllers/userController.js`**
  - Vérifier : champs `stripeCustomerId`, `stripeAccountId` dans les updates/reads

- **`backend/src/controllers/applicationController.js`**
  - Vérifier : lien entre application sitter et `stripeConnectAccountId`

- **`backend/src/controllers/donationController.js`**
  - Vérifier : logique paiement donation (Stripe ?)

---

## 3. BACKEND — SERVICES (3 fichiers)

### ✓ SUPPRIMER
- **`backend/src/services/stripeService.js`** (513 lignes)
  - Wrapper complet API Stripe
  - Fonctions : `createPaymentIntent()`, `handleWebhookEvent()`, `retrieveCharge()`, etc.
  - Dédié 100% Stripe

- **`backend/src/services/stripeIdentityService.js`** (113 lignes)
  - `createVerificationSession()`, `parseWebhookEvent()`, `isConfigured()`
  - Dédié 100% Stripe Identity

### ✓ NETTOYER
- **`backend/src/services/walletService.js`**
  - Peut appeler stripeService pour init stripe customer
  - Extraire refs Stripe, garder logique portefeuille

---

## 4. BACKEND — MODELS (4 fichiers)

### ✓ NETTOYER
Champs Stripe à SUPPRIMER :

- **`backend/src/models/Owner.js`**
  - L107-111 : `stripeCustomerId` (créé 1ère fois owner paie)
  - **ACTION:** Enlever champ + schema

- **`backend/src/models/Sitter.js`**
  - L88-90 : `identityVerification.stripeSessionId`, `.provider` ('stripe_identity')
  - L106 : `payoutMethod` = enum `['stripe', 'paypal', 'iban']` → garder enum, enlever 'stripe'
  - L175-180 : `stripeConnectAccountId`, `stripeConnectAccountStatus`
  - L185-187 : `stripeCustomerId`
  - **ACTION:** Enlever tous ces champs, setter payoutMethod default = 'iban' ou 'paypal'

- **`backend/src/models/Walker.js`**
  - L139-152 : `identityVerification.stripeSessionId`, `.provider`
  - L228-229 : `payoutMethod` enum contient 'stripe' → nettoyer
  - L235-243 : `stripeConnectAccountId`, `stripeConnectAccountStatus`, `stripeCustomerId`
  - **ACTION:** Même traitement que Sitter

- **`backend/src/models/Booking.js`**
  - L60 : `paymentProvider` enum `['stripe', 'paypal']` → garder 'paypal' seulement
  - L63-68 : `stripePaymentIntentId`, `stripeChargeId`
  - **ACTION:** Enlever champs, garder logique booking, setter default provider = 'paypal'

---

## 5. BACKEND — ROUTES MIXTES (6 fichiers)

### ✓ NETTOYER
- **`backend/src/routes/adminRoutes.js`**
  - Chercher : endpoint debug/admin Stripe

- **`backend/src/routes/subscriptionRoutes.js`**
  - Chercher : `stripeWebhook` ou `stripeCustomerId`

- **`backend/src/routes/chatAddonRoutes.js`**
  - Logique paiement addon (stripe ?)

- **`backend/src/routes/boostRoutes.js`**, **`mapBoostRoutes.js`**
  - Paiement boost via Stripe → nettoyer

- **`backend/src/routes/sitterRoutes.js`**
  - Vérifier : identity verification upload (legacy POST /sitters/upload-identity)
  - Peut aussi avoir stripe connect endpoints

---

## 6. BACKEND — SCRIPTS DE MAINTENANCE (3 fichiers)

### ✓ SUPPRIMER
- **`backend/src/scripts/clearAllStripeAccounts.js`**
  - Maintenance-only, dédié Stripe

- **`backend/src/scripts/clearInvalidStripeAccounts.js`**
  - Maintenance-only, dédié Stripe

- **`backend/src/scripts/clearPaymentData.js`**
  - Probable : nettoie `stripePaymentIntentId`, etc.
  - Vérifier si also nettoie autre data

---

## 7. BACKEND — UTILS (2 fichiers)

### ✓ NETTOYER / SUPPRIMER
- **`backend/src/utils/stripeCountry.js`**
  - Mapping pays → Stripe (pour verification Identity)
  - **ACTION:** SUPPRIMER (dédié Stripe)

- **`backend/src/utils/sanitize.js`**
  - Vérifier si contient Stripe-specific logic

---

## 8. BACKEND — APP.JS (middleware + mounts)

### ✓ NETTOYER
- L (require) : `const stripeConnectRoutes = ...`, `const stripeWebhookRoutes = ...`
- L (helmet CSP) : `"https://js.stripe.com"`, `"https://api.stripe.com"`, `"https://hooks.stripe.com"`
- L (app.use) : `/webhooks` → stripeWebhookRoutes
- L (app.use) : Stripe Identity webhook raw body handler
- L (versionedRoutes) : `/stripe-connect` mount, `/identity-verification` mount
- **ACTION:** Enlever tous les requires, helmet config Stripe, app.use() mounts

---

## 9. FRONTEND — SERVICES (2 fichiers)

### ✓ SUPPRIMER
- **`frontend/lib/services/stripe_payment_service.dart`**
  - Service wrapper Stripe payment SDK (flutter_stripe was here before purge)
  - Dédié 100% Stripe

- **`frontend/lib/views/payment/stripe_payment_screen.dart`**
  - Écran paiement via flutter_stripe
  - **ATTENTION:** flutter_stripe plugin est déjà supprimé de pubspec.yaml

### ✓ NETTOYER
- **`frontend/lib/services/donation_service.dart`**
  - Vérifier : logique donation paiement (Stripe ?)

---

## 10. FRONTEND — CONTROLLERS (4 fichiers)

### ✓ SUPPRIMER
- **`frontend/lib/controllers/stripe_payment_controller.dart`**
  - Controller gestion paiement Stripe (IntentSecret, etc.)
  - Dédié 100% Stripe

- **`frontend/lib/controllers/stripe_connect_controller.dart`**
  - Controller onboarding Stripe Connect sitter/walker
  - Dédié 100% Stripe

### ✓ NETTOYER
- **`frontend/lib/controllers/subscription_controller.dart`**
  - Vérifier : logique souscription addon/boost (Stripe ?)

- **`frontend/lib/controllers/chat_addon_controller.dart`**
  - Vérifier : logique paiement addon (Stripe ?)

- **`frontend/lib/controllers/petsitter_onboarding_controller.dart`**
  - Vérifier : point d'appel StripeConnect integration

- **`frontend/lib/controllers/map_boost_controller.dart`**
  - Vérifier : point d'appel paiement boost (Stripe ?)

---

## 11. FRONTEND — ÉCRANS IDENTITY (3 fichiers)

### ✓ SUPPRIMER
- **`frontend/lib/views/pet_sitter/profile/identity_verification_screen.dart`**
  - Écran Stripe Identity verification pour sitter
  - Calls `stripeIdentityService` API → open URL → deep link return

- **`frontend/lib/views/pet_walker/profile/walker_identity_verification_screen.dart`**
  - Écran Stripe Identity verification pour walker
  - Dédié 100% Stripe Identity

### ✓ NETTOYER
- **`frontend/lib/views/sitter_iban/sitter_iban_screen.dart`**
  - **ATTENTION:** Cet écran pourrait avoir fallback UI pour identity upload (legacy pre-Stripe-Identity)
  - Vérifier si contient ancien form upload document

---

## 12. FRONTEND — ÉCRANS PAIEMENT (5 fichiers)

### ✓ SUPPRIMER
- **`frontend/lib/views/payment/stripe_webview_payment_screen.dart`**
  - Écran Stripe payment via webview
  - Dédié 100% Stripe

### ✓ NETTOYER
- **`frontend/lib/views/pet_owner/payments/add_card_screen.dart`**
  - Vérifier : logique "enregistrer carte" (Stripe ?)
  - Probable : appelle `stripePaymentService.createPaymentIntent()` → nettoyer

- **`frontend/lib/views/pet_owner/payments/owner_payments_screen.dart`**
  - Vérifier : logique paiement owner pour booking (Stripe ?)

- **`frontend/lib/views/payment/modern_card_payment_screen.dart`**
  - Écran paiement moderne → probable Airwallex (déjà purgé Stripe avant ?)
  - Vérifier si reste référence Stripe

- **`frontend/lib/views/auth/connect_payment_screen.dart`**
  - Vérifier : lien à Stripe Connect sitter onboarding

---

## 13. FRONTEND — ONBOARDING (2 fichiers)

### ✓ SUPPRIMER
- **`frontend/lib/views/pet_sitter/onboarding/stripe_connect_onboarding_screen.dart`**
  - Écran onboarding Stripe Connect
  - Dédié 100% Stripe

- **`frontend/lib/views/pet_sitter/onboarding/stripe_connect_webview_screen.dart`**
  - Webview Stripe Connect flow
  - Dédié 100% Stripe

---

## 14. FRONTEND — DATA & ROUTES (5 fichiers)

### ✓ NETTOYER
- **`frontend/lib/data/network/api_endpoints.dart`**
  - Probable : endpoints `/stripe-connect/*`, `/identity-verification/*`
  - **ACTION:** Enlever ces routes

- **`frontend/lib/routes/app_routes.dart`**
  - Probable : route names pour écrans Stripe (`stripeConnectOnboarding`, etc.)
  - **ACTION:** Enlever les routeName et l'import écrans Stripe

- **`frontend/lib/data/static/privacy_policy.dart`**, `terms_of_service.dart`
  - Vérifier : mentions Stripe Payment, Identity Verification
  - **ACTION:** Enlever si présent

---

## 15. FRONTEND — LOCALIZATION (6 fichiers)

### ✓ NETTOYER
- **`frontend/lib/localization/translations/{en,fr,de,es,it,pt}.dart`**
  - Chercher clé traduction `stripe*` (stripeError, stripeCardDeclined, stripeConnect, etc.)
  - **ACTION:** Enlever toute clé Stripe

---

## 16. FRONTEND — REPOSITORIES & MODELS (2 fichiers)

### ✓ NETTOYER
- **`frontend/lib/repositories/owner_repository.dart`**
  - Vérifier : appel API owner payments (Stripe ?)

- **`frontend/lib/repositories/sitter_repository.dart`**
  - Vérifier : appel Stripe Connect endpoints, identity verification endpoints

- **`frontend/lib/models/application_model.dart`**
  - Vérifier : champs lié application booking (stripePaymentIntentId ?)

---

## 17. FRONTEND — VIEWS MIXTES (3 fichiers)

### ✓ NETTOYER
- **`frontend/lib/views/pet_sitter/payment/earnings_history_screen.dart`**
  - Vérifier : affichage earnings (peut afficher Stripe payout status ?)

- **`frontend/lib/views/pet_sitter/payment/payment_management_screen.dart`**
  - Vérifier : gestion Stripe Connect account + payout status

- **`frontend/lib/views/pet_sitter/payment/payout_status_screen.dart`**
  - Probable : affiche "Stripe account en cours onboarding"
  - Remplacer par logique IBAN/PayPal

---

## 18. FRONTEND — DEEP LINKS & SERVICES (2 fichiers)

### ✓ NETTOYER
- **`frontend/lib/services/deep_link_service.dart`**
  - Vérifier : handler pour retour Stripe Identity (`?session_id=...`)
  - Enlever route `/identity-verification/return`

- **`frontend/lib/views/auth/sign_up_screen.dart`**
  - Vérifier : lien à wallet/card setup (Stripe ?)

---

## 19. PUBSPEC.YAML

### ✓ VÉRIFIER
- **`frontend/pubspec.yaml`**
  - Chercher : `flutter_stripe` (déjà supprimé selon commentaire)
  - Commentaire ligne 70+ : "flutter_stripe SUPPRIMÉ. Pure Airwallex via webview HPP."
  - **STATUS:** Déjà purgé, juste vérifier pas de résidu

---

## RÉSUMÉ ACTIONNABLE

| Catégorie | Supprimer | Nettoyer | Total |
|-----------|-----------|----------|-------|
| Routes | 3 | 6 | 9 |
| Controllers | 2 | 6 | 8 |
| Services | 2 | 1 | 3 |
| Models | 0 | 4 | 4 |
| Utils | 1 | 1 | 2 |
| Frontend Controllers | 2 | 4 | 6 |
| Frontend Screens | 6 | 5 | 11 |
| Frontend Data | 0 | 5 | 5 |
| Scripts | 3 | 0 | 3 |
| **TOTAL** | **19** | **32** | **51** |

---

## DÉPENDANCES CRITIQUES À VÉRIFIER

1. **app.js** → Imports stripeXxxRoutes + Helmet CSP + app.use() mounts
2. **package.json** → dépendance `stripe` npm package (si déjà enlever, OK)
3. **Models schema defaults** → `payoutMethod` default ne peut pas = 'stripe' après suppression
4. **Booking schema** → `paymentProvider` default ne peut pas = 'stripe' après suppression
5. **Frontend routes.dart** → Tous les RouteNames Stripe doivent être supprimés

---

## ORDRE RECOMMANDÉ DE PURGE

1. **Supprimer d'abord** (aucune dépendance) : scripts, services dédié, utils Stripe
2. **Supprimer routes/controllers** Stripe-only (stripeConnect*, stripeWebhook*, identityVerification*)
3. **Nettoyer models** : champs stripe*, énums payoutMethod, paymentProvider
4. **Nettoyer controllers/routes** qui appellent Stripe → retirer refs, laisser logique
5. **Nettoyer frontend** écrans, controllers, routes
6. **Nettoyer app.js** à la fin (quand aucun require stripeXxx n'existe)
