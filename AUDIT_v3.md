# AUDIT v3 — HopeTSIT (Flutter + Node.js)

**Date** : 2026-04-14
**Périmètre** : `backend/` (Node.js + Express + MongoDB) et `frontend/` (Flutter + GetX)
**Objectif** : audit complet avant application des corrections v3. **Aucune modification de code n'a été effectuée.**

---

## 1. ARBORESCENCE COMMENTÉE

### 1.1 Racine du projet

```
HopeTSIT_FINAL/
├── admin_dashboard.html                # Dashboard admin statique (hors app Flutter)
├── HopeTSIT_Developer_Handoff.pdf      # Documentation transfert
├── HopeTSIT_Etat_Avancement.pdf        # État d'avancement
├── HopeTSIT_Guide_Backend.pdf          # Guide backend
├── backend/                             # API Node.js
└── frontend/                            # App Flutter (mobile + web)
```

### 1.2 Backend (`backend/src`)

```
backend/src/
├── app.js                         # Configuration Express, middleware, montage des routes
├── index.js                       # Point d'entrée : Mongo, HTTP, Socket.IO, scheduler
├── config/
│   ├── firebaseAdmin.js          # Init Firebase Admin (FCM)
│   └── swagger.js                # OpenAPI / Swagger
├── controllers/                   # 9 289 LOC — logique métier
│   ├── authController.js         # Signup, login, reset mdp, Google/Apple
│   ├── userController.js         # Profil, carte, switch rôle
│   ├── bookingController.js      # Réservations, PaymentIntent, remboursements
│   ├── sitterController.js       # Profils sitter, tarifs, Stripe Connect
│   ├── petController.js          # CRUD animaux + médias Cloudinary
│   ├── postController.js         # Posts sociaux, commentaires, likes
│   ├── applicationController.js  # Candidatures (owner ↔ sitter)
│   ├── conversationController.js # Messagerie (HTTP) — complément Socket.IO
│   ├── stripeConnectController.js
│   ├── stripeWebhookController.js
│   ├── taskController.js         # Rappels/tâches
│   ├── blockController.js        # Blocage d'utilisateurs
│   ├── reviewController.js       # Avis / notes
│   ├── notificationController.js # Notifications in-app
│   ├── pricingController.js      # Tiers de prix
│   ├── uploadController.js       # Upload fichiers
│   └── healthController.js       # Healthcheck
├── middleware/
│   ├── auth.js                   # requireAuth / requireRole (JWT)
│   └── ownerContext.js           # Attache user à la requête
├── models/                        # 14 modèles Mongoose
│   ├── Owner.js, Sitter.js, Pet.js, Booking.js, Application.js
│   ├── Conversation.js, Message.js, Post.js, Review.js
│   ├── Block.js, Task.js, Notification.js, VerificationCode.js
│   ├── Sitter.js.bak              # ⚠️ Fichier mort (backup)
│   └── (sitterRoutes.js.bak idem côté routes)
├── routes/                        # 20 fichiers de routes REST
├── services/
│   ├── stripeService.js          # PaymentIntent, Connect, refunds
│   ├── paypalService.js          # SDK PayPal
│   ├── paypalPayoutService.js    # Payouts PayPal
│   ├── payoutScheduler.js        # Cron payouts (setInterval)
│   ├── conversationService.js
│   ├── notificationService.js
│   ├── blockService.js
│   ├── emailService.js           # Nodemailer (vérif email, reset)
│   └── cloudinary.js             # Upload images
├── sockets/
│   ├── index.js                  # Init Socket.IO
│   ├── chatSocket.js             # Handlers chat temps réel
│   └── emitter.js                # Helper d'émission par room
├── scripts/                       # Scripts de maintenance / migration DB
└── utils/                         # errors, sanitize, code (OTP), pricing,
                                  # currency, location, fingerprint, tierPricing
```

### 1.3 Frontend (`frontend/lib`)

```
frontend/lib/
├── main.dart                        # Init Firebase, GetX, Localization
├── firebase_options.dart            # Config Firebase (auto-généré)
├── controllers/                     # 33 controllers GetX
│   ├── auth_controller.dart, user_controller.dart
│   ├── bookings_controller.dart, sitter_bookings_controller.dart
│   ├── chat_controller.dart, sitter_chat_controller.dart
│   ├── stripe_payment_controller.dart, paypal_payment_controller.dart
│   ├── stripe_connect_controller.dart, sitter_paypal_payout_controller.dart
│   ├── notifications_controller.dart, applications_controller.dart
│   ├── profile_controller.dart, sitter_profile_controller.dart
│   ├── home_controller.dart, pets_map_controller.dart, posts_controller.dart
│   └── […]
├── data/network/
│   ├── api_client.dart              # Wrapper HTTP (GET/POST/PUT/PATCH/DELETE + multipart)
│   ├── api_config.dart              # URL dev (Render) vs prod (api.hopetsit.com)
│   ├── api_endpoints.dart           # Constantes de routes (122 lignes)
│   └── api_exception.dart           # Exceptions API typées
├── models/                          # 10 data classes (profile, sitter, pet, booking…)
├── repositories/                    # 8 repos (auth, user, pet, sitter, owner, post, chat, notifications)
├── services/
│   ├── socket_service.dart          # Client Socket.IO
│   ├── push_notification_service.dart # FCM
│   ├── location_service.dart        # Geolocator + Geocoding
│   └── stripe_payment_service.dart
├── views/                           # Écrans par feature
│   ├── splash/, auth/ (+ forgot_flow/)
│   ├── pet_owner/ (home, chat, booking-application, pet_profile, posts, reservation_request)
│   ├── pet_sitter/ (home, booking, booking-application, chat, onboarding, profile, payment, widgets)
│   ├── profile/ (owner, pets, cartes, tâches, blocked users, password, CGU)
│   ├── payment/ (Stripe, Stripe WebView, PayPal, PayPal WebView, result)
│   ├── notifications/, booking/, reviews/, map/
│   ├── service_provider/, admin/ (admin_dashboard_screen.dart), onboarding/, sitter_iban/
├── widgets/                         # 15+ composants réutilisables (AppText, CustomAppBar, …)
├── utils/                           # Colors, constantes, images, storage_keys, logger, currency
├── localization/
│   └── app_translations.dart        # ⚠️ 342,5 KB — FR/EN/ES/DE/IT/PT
└── helper/
    └── dependency_injection.dart    # Setup GetX / services
```

---

## 2. MODULES BACKEND (Node.js)

### 2.1 Point d'entrée

`backend/src/index.js` — charge `.env`, connecte MongoDB, crée le serveur HTTP, initialise Socket.IO et démarre le scheduler de payouts. Écoute sur `PORT` (5000 par défaut).

### 2.2 Routes / Controllers

| Route | Controller | Objet |
|------|-----------|-------|
| `/auth/*` | authController | Signup, login, vérif email, reset mdp, Google/Apple |
| `/users/*` | userController | Profil, carte, switch rôle |
| `/bookings/*` | bookingController | CRUD booking, PaymentIntent, cancel, refund |
| `/sitters/*` | sitterController | Profils, recherche 2dsphere, tarifs, Stripe Connect |
| `/pets/*` | petController | CRUD animaux, médias |
| `/posts/*` | postController | Posts, commentaires, likes |
| `/applications/*` | applicationController | Candidatures |
| `/conversations/*` | conversationController + chatSocket | Messagerie HTTP + Socket.IO |
| `/tasks/*` | taskController | Tâches / rappels |
| `/blocks/*` | blockController | Blocage |
| `/reviews/*` | reviewController | Avis |
| `/stripe-connect/*` | stripeConnectController | Création compte, URL onboarding |
| `/webhooks` | stripeWebhookController | Webhooks Stripe |
| `/notifications/*` | notificationController | Notifs in-app (pagination cursor) |
| `/admin/*` | adminRoutes | Dashboard, stats — auth `X-Admin-Secret` |
| `/pricing/*` | pricingController | Tiers de prix |
| `/sitter/*` (ibanRoutes) | — | Setup IBAN |
| `/uploads/*` | uploadController | Upload multipart |
| `/health` | healthController | Healthcheck |
| `/api-docs` | swagger-docs | Swagger UI |

### 2.3 Base de données

- MongoDB Atlas (cluster `petinsta.bbibplp.mongodb.net/Petinsta`)
- Mongoose v8.6.0
- Index `2dsphere` sur `location` (Owner & Sitter) pour recherche géographique
- 14 schémas (voir arborescence)

### 2.4 Sécurité & middleware

- JWT 7 jours, `middleware/auth.js` → `requireAuth`, `requireRole`
- Helmet avec CSP (autorise `js.stripe.com`, `api.stripe.com`, `'unsafe-inline'` ⚠️)
- CORS global sans whitelist d'origine ⚠️
- Admin : header `X-Admin-Secret` (pas de JWT) ⚠️

---

## 3. MODULES FRONTEND (Flutter)

### 3.1 Architecture GetX

- Service locator : `helper/dependency_injection.dart` (`setupDependencies()`)
- 8 repositories (Auth, User, Pet, Sitter, Owner, Post, Chat, Notifications)
- 33 controllers GetX
- Navigation : `Get.to()` et routes nommées implicites — **pas de fichier central `AppRoutes`/`AppPages`** ⚠️

### 3.2 Couche API

**`api_client.dart`**
- Méthodes GET/POST/PUT/PATCH/DELETE + variantes multipart
- Token récupéré depuis `GetStorage` → header `Authorization: Bearer …`
- Timeouts : 10 s connect, 30 s receive
- Logs sanitizés (mots de passe, tokens masqués)
- Exceptions typées `ApiException`

**`api_config.dart`**
- Dev : `https://petinsta-backend-g7jn.onrender.com`
- Prod : `https://api.hopetsit.com`

**`api_endpoints.dart`** : 122 lignes de constantes, alignées avec routes backend.

### 3.3 Features principales

| Feature | Écrans | Controllers | Repos |
|--------|--------|-------------|-------|
| Auth | login, signup, sign_up_as, email_verification, otp_verification, forgot_flow (4) | auth_controller | auth_repository |
| Home Owner | home_screen, my_pets, edit_pet, pet_profile | home, my_pets, create_pet_profile | pet |
| Home Sitter | sitter_homescreen, petsitter_onboarding, stripe_connect_webview | home, petsitter_onboarding, stripe_connect | sitter |
| Bookings | bookings_history, booking_agreement, owner_booking_detail, sitter_booking_detail | bookings, sitter_bookings | — |
| Chat | chat, individual_chat (owner + sitter) | chat, sitter_chat | chat |
| Paiement | stripe_payment (+ webview), paypal_payment (+ webview), payment_result, iban_setup | stripe_payment, paypal_payment, stripe_connect, sitter_paypal_payout | — |
| Notifications | notifications, sitter_notifications, notification_application_view, notification_post_view | notifications | notifications |
| Reviews | reviews_screen | reviews | — |
| Map | pets_map + widgets (pet_bottom_sheet, sitter_bottom_sheet) | pets_map | sitter |
| Posts | my_posts, edit_post | posts | post |
| Applications | application_screen, sitter_application_screen | applications, sitter_application | — |
| Admin | admin_dashboard_screen | — | — |
| Profile | profile, edit_owner_profile, edit_sitter_profile, blocked_users, add_card, add_task, change_password, terms | profile, sitter_profile, edit_owner_profile, edit_sitter_profile | user |

### 3.4 Services

- `socket_service.dart` — Socket.IO (chat temps réel)
- `push_notification_service.dart` — FCM (TODO : appel backend pour update token ⚠️)
- `location_service.dart` — Geolocator + Geocoding
- `stripe_payment_service.dart` — SDK Stripe

### 3.5 Thème et traductions

- Material Design 3 ; couleur primaire `#6200EE` (`utils/app_colors.dart`)
- ScreenUtil base `393 × 852`
- i18n : 6 langues (FR, EN, ES, DE, IT, PT) — fichier unique `app_translations.dart` de **342,5 KB** ⚠️ (à découper)

---

## 4. DÉPENDANCES

### 4.1 Frontend (`frontend/pubspec.yaml`)

| Package | Version | Usage |
|--------|---------|-------|
| get | ^4.7.2 | State management GetX |
| get_storage | ^2.1.1 | Persistance locale (token, user) |
| get_it | ^8.2.0 | Service locator (en complément de GetX) |
| http | ^1.5.0 | Client HTTP |
| firebase_core | ^4.1.1 | Init Firebase |
| firebase_auth | ^6.1.0 | Auth Firebase |
| firebase_messaging | ^16.0.2 | Push FCM |
| google_sign_in | ^7.2.0 | OAuth Google |
| the_apple_sign_in | ^1.1.1 | OAuth Apple |
| socket_io_client | ^3.1.3 | Chat temps réel |
| stripe_flutter | ^11.1.0 | SDK Stripe |
| google_maps_flutter | ^2.14.0 | Cartes |
| geolocator | ^14.0.2 | Géoloc |
| geocoding | ^4.0.0 | Reverse geocoding |
| google_places_flutter | ^2.1.1 | Autocomplete adresses |
| image_picker | ^1.2.0 | Sélecteur image |
| file_picker | ^10.3.3 | Sélecteur fichier |
| photo_view | ^0.14.0 | Viewer image |
| cached_network_image | ^3.4.1 | Cache images réseau |
| flutter_svg | ^2.2.1 | SVG |
| webview_flutter | ^4.13.1 | WebView (paiements) |
| flutter_screenutil | ^5.9.3 | Responsive |
| animated_custom_dropdown | ^3.1.1 | Dropdown |
| pinput | ^5.0.2 | Champ PIN |
| shimmer | ^3.0.0 | Loading skeleton |
| google_fonts | ^6.3.2 | Polices |
| cupertino_icons | ^1.0.8 | Icônes iOS |
| flutter_dotenv | ^6.0.0 | .env runtime ⚠️ |
| flutter_localizations | sdk | i18n |
| intl | ^0.20.2 | i18n/formatting |
| path_provider | ^2.1.5 | Chemins FS |
| permission_handler | ^12.0.1 | Permissions |
| share_plus | ^12.0.1 | Partage natif |
| mime | ^1.0.4 | Détection MIME |
| country_code_picker | ^3.4.1 | Picker indicatif |

### 4.2 Backend (`backend/package.json`)

| Package | Version | Usage |
|--------|---------|-------|
| express | ^4.19.2 | Framework web |
| mongoose | ^8.6.0 | ODM MongoDB |
| jsonwebtoken | ^9.0.2 | JWT |
| bcryptjs | ^2.4.3 | Hash mdp |
| cors | ^2.8.5 | CORS ⚠️ (wildcard) |
| helmet | ^7.1.0 | En-têtes sécurité |
| morgan | ^1.10.0 | Logs HTTP |
| multer | ^1.4.5-lts.1 | Upload |
| cloudinary | ^1.41.0 | Stockage images |
| socket.io | ^4.8.1 | Temps réel |
| stripe | ^14.25.0 | SDK Stripe |
| @paypal/paypal-server-sdk | 2.2.0 | SDK PayPal |
| firebase-admin | ^13.6.0 | Admin Firebase (FCM) |
| nodemailer | ^6.9.13 | Emails |
| swagger-jsdoc | ^6.2.8 | Doc API |
| swagger-ui-express | ^5.0.1 | UI Swagger |
| dotenv | ^16.4.5 | Variables d'env |
| dayjs | ^1.11.13 | Dates |

**Dev** : eslint ^8.56.0, nodemon ^3.1.4.

---

## 5. QUALITÉ DE CODE

### 5.1 Fichiers morts / backups

- `backend/src/models/Sitter.js.bak`
- `backend/src/routes/sitterRoutes.js.bak`
- `backend/public/index.html` — page de test Stripe (~23 KB) exposée en prod ⚠️

### 5.2 TODOs importants (frontend)

1. `services/push_notification_service.dart:107` — envoyer le token FCM au backend
2. `views/pet_owner/chat/individual_chat_screen.dart:321` — viewer image plein écran
3. `controllers/petsitter_onboarding_controller.dart:110` — appel API sauvegarde profil
4. `views/pet_sitter/payment/payout_status_screen.dart:238` — statut vérification depuis API
5. `views/pet_sitter/payment/payout_status_screen.dart:288` — statut payout depuis API
6. `controllers/profile_controller.dart:236` — persist blocked users
7. `controllers/profile_controller.dart:400` — navigation donate
8. `controllers/sitter_profile_controller.dart:184` — remplacer mock par API

Aucun TODO dans le backend.

### 5.3 Code commenté

- Backend : ~199 blocs (majoritairement JSDoc — normal)
- Frontend : commentaires `TODO` dispersés, pas de gros blocs morts

### 5.4 Tests

- **Aucun test unitaire/intégration** côté backend ni frontend ⚠️⚠️
- `codemagic.yaml` présent mais pas de stage de tests

---

## 6. ÉTAT DES MODULES

| Module | État | Fichiers de référence |
|--------|------|------------------------|
| Authentification | ✅ Fonctionnel | `authController.js`, `auth_controller.dart`, `auth_repository.dart` |
| Chat | ✅ Fonctionnel | `chatSocket.js`, `conversationService.js`, `chat_controller.dart`, `socket_service.dart` |
| Paiement Stripe | ✅ Fonctionnel | `stripeService.js`, `stripe_payment_controller.dart`, `stripe_connect_controller.dart` |
| Paiement PayPal | ✅ Fonctionnel | `paypalService.js`, `paypalPayoutService.js`, `paypal_payment_controller.dart` |
| Notifications | ⚠️ Partiel | `notificationService.js`, `notifications_controller.dart` — TODO FCM token update backend |
| Traductions | ✅ Fonctionnel (⚠️ mono-fichier 342 KB) | `localization/app_translations.dart` |
| Thème | ✅ Fonctionnel | `utils/app_colors.dart`, `main.dart` |
| Admin | ⚠️ Partiel | `adminRoutes.js`, `admin_dashboard_screen.dart` — UI limitée, pas de CRUD utilisateurs |
| Géolocalisation | ✅ Fonctionnel | `utils/location.js`, `pets_map_controller.dart` |
| Blocage | ✅ Fonctionnel | `blockController.js`, `blockService.js` |
| Reviews | ✅ Fonctionnel | `reviewController.js`, `reviews_controller.dart` |
| Applications | ✅ Fonctionnel | `applicationController.js`, `applications_controller.dart` |
| Tests automatisés | ❌ Manquant | — |
| Logging structuré | ❌ Manquant | console.log uniquement |
| Rate limiting | ❌ Manquant | — |

---

## 7. CORRECTIONS v3 — MAPPING FICHIERS

> À valider avec le demandeur avant implémentation.

### 🔴 Critique

| # | Correction | Fichiers impactés |
|---|-----------|-------------------|
| C1 | Rotation + extraction des secrets (Firebase, Stripe, PayPal, Mongo, Admin) vers secret manager | `backend/.env`, `frontend/.env`, `backend/src/config/firebaseAdmin.js` |
| C2 | Whitelist CORS origines | `backend/src/app.js` |
| C3 | Retirer `'unsafe-inline'` du CSP (nonces) | `backend/src/app.js` (config helmet) |
| C4 | Rate limiting (auth + paiement) | `backend/src/app.js`, nouveau middleware |
| C5 | Remplacer auth admin par JWT rôle `admin` | `backend/src/routes/adminRoutes.js`, `middleware/auth.js` |
| C6 | Supprimer `public/index.html` (page test Stripe) en prod | `backend/src/app.js`, `backend/public/index.html` |

### 🟠 Haute priorité

| # | Correction | Fichiers impactés |
|---|-----------|-------------------|
| H1 | Validation d'entrée (Joi/Zod) sur auth, bookings, payments | `backend/src/routes/*`, nouveau `validators/` |
| H2 | Tokeniser/chiffrer IBAN, PayPal email, infos carte | `models/Owner.js`, `models/Sitter.js`, `userController.js` |
| H3 | Vérifier membership conversation à chaque message | `sockets/chatSocket.js`, `conversationService.js` |
| H4 | Stripe Connect : `country` configurable (pas hardcodé `US`) | `services/stripeService.js`, `stripeConnectController.js` |
| H5 | Supprimer `.bak` du repo | `backend/src/models/Sitter.js.bak`, `backend/src/routes/sitterRoutes.js.bak` |
| H6 | Envoyer le token FCM au backend + route dédiée | `services/push_notification_service.dart`, nouveau endpoint `/users/fcm-token`, `userController.js` |

### 🟡 Moyenne priorité

| # | Correction | Fichiers impactés |
|---|-----------|-------------------|
| M1 | Centraliser le routing GetX dans `AppRoutes`/`AppPages` | nouveau `lib/routes/app_pages.dart`, `main.dart` |
| M2 | Découper `app_translations.dart` par langue | `frontend/lib/localization/` |
| M3 | Sanitize HTML des posts / commentaires | `postController.js`, frontend post widgets |
| M4 | Masquer Swagger en prod | `backend/src/app.js` |
| M5 | Remplacer `setInterval` payouts par Bull + Redis | `services/payoutScheduler.js` |
| M6 | Compléter dashboard admin (CRUD utilisateurs, modération posts) | `admin_dashboard_screen.dart`, `adminRoutes.js` |
| M7 | Finaliser les 8 TODO listés en §5.2 | voir §5.2 |

### 🔵 Best practices

| # | Correction | Fichiers impactés |
|---|-----------|-------------------|
| B1 | Logger structuré (Pino/Winston) | `backend/src/**` |
| B2 | Tracking erreurs (Sentry) | backend + frontend |
| B3 | Tests unitaires critiques (auth, booking state machine, paiement) | nouveau `backend/tests/`, `frontend/test/` |
| B4 | Versionner les routes (`/api/v1`) | `backend/src/app.js`, `frontend/lib/data/network/api_endpoints.dart` |
| B5 | Migrations DB versionnées | `backend/src/scripts/` → outillage migrate-mongo |
| B6 | Utiliser `requestFingerprint.js` pour audit trail | middleware Express |

---

## 8. RISQUES TECHNIQUES IDENTIFIÉS

### Critiques

1. **Secrets en clair dans `.env` committable** — Firebase private key, Stripe secret, PayPal, Mongo URI, ADMIN_SECRET. Rotation immédiate requise.
2. **CORS ouvert** (`app.use(cors())` sans options).
3. **CSP permissive** : `'unsafe-inline'` scripts + styles.
4. **Pas de rate limit** : endpoints `/auth/*` et `/bookings/*` vulnérables (brute force, énumération).
5. **Auth admin par header statique** — pas de rotation, loggable en proxy.

### Élevés

6. **Aucune couverture de tests** — risque majeur de régression sur la logique paiement.
7. **Données sensibles en clair** (carte, IBAN, email PayPal) dans MongoDB.
8. **Stripe Connect hardcodé `country: 'US'`** — bloque l'usage européen.
9. **Page test Stripe exposée** (`/public/index.html`).
10. **Payout scheduler single-process** (`setInterval`) — pas de résilience crash.

### Moyens

11. **Pas de routing GetX centralisé** — navigation difficile à maintenir.
12. **`app_translations.dart` de 342 KB** — impact bundle size, ralentit le build.
13. **Swagger exposé par défaut** en prod.
14. **Pas d'API versioning** — breaking changes risqués pour les clients mobiles déjà déployés.
15. **Logs non structurés** (`console.log`) — supervision difficile.

### Faibles

16. **Pas de monitoring/error tracking** (Sentry, Rollbar).
17. **Pas de migrations versionnées** — scripts manuels dans `scripts/`.
18. **Fichiers `.bak` dans le repo**.
19. **8 TODO frontend non résolus** (voir §5.2).

---

## 9. CONCLUSION

L'application est **fonctionnellement complète** sur les domaines clés (auth, réservations, paiements Stripe + PayPal, messagerie temps réel, notifications, géoloc, i18n 6 langues). L'architecture est propre (controllers → services → models ; GetX + repositories côté Flutter).

Les **blocages pour une mise en production sereine** sont :

1. Fuite de secrets dans `.env` → rotation + secret manager.
2. CORS / CSP / rate limiting à durcir.
3. Absence totale de tests automatisés.
4. Admin incomplet, FCM token update manquant.
5. Stripe Connect hardcodé US.

Les corrections v3 proposées en §7 adressent ces points par ordre de priorité.

**En attente de validation de ce rapport avant modification du code.**
