# Build 565 — contrats entre lots (à respecter à la lettre)

Huit lots travaillent EN MÊME TEMPS dans ce dépôt. Chaque lot n'édite QUE ses fichiers
(liste dans son brief). Les échanges entre lots passent par les contrats ci-dessous :
noms de routes, de champs et de clés FIGÉS. Si un contrat doit changer, l'écrire dans la
section « Écarts » de ton rapport final, jamais en silence.

## Règles communes
- Jamais de `Write` sur un fichier existant : uniquement des remplacements ciblés (Edit).
- Jamais de commande git qui modifie l'arbre (commit, checkout, stash, reset, pull).
- Pas de `flutter pub add/get`, pas de `npm install` (déjà faits ; `record` et `audioplayers` sont disponibles).
- App : `cd frontend && dart analyze <tes dossiers>` jusqu'à 0 erreur dans TES fichiers.
  Backend : `node -c <fichier>` sur chaque fichier touché.
- Traductions app : UNIQUEMENT ton paquet `frontend/lib/localization/v565/<lot>_i18n.dart`
  (9 langues : en fr es de it pt ko ja pl — la MÊME clé partout, jamais de texte en dur ;
  les clés v565 priment sur une clé historique homonyme, ne PAS éditer translations/*.dart).
- Règles GetX/Flutter release de CLAUDE.md (jamais `Obx(() => Builder(...))`, jamais
  `CrossAxisAlignment.stretch` avec `Expanded` dans un scroll, jamais `Expanded` sous `IntrinsicHeight`).
- Aucune fonction existante retirée. Style : Apple minimaliste + « Paw Buttons » (couleurs CLAUDE.md).
- Jamais d'envoi réel (push, e-mail, annonce) vers de vrais utilisateurs ; comptes de test
  `dadaciao84+testowner/+testsitter/+testwalker@gmail.com` (mot de passe : voir CLAUDE.md).
  Une annonce de test se crée UNIQUEMENT dans une ville fictive lat -35 / lng -30 puis se supprime.

## 1. Sons de notification (fichiers déjà en place)
- iOS : `frontend/ios/Runner/Sounds/{bark,meow,tweet}.caf` (dans le bundle, ajoutés au pbxproj).
- Android : `frontend/android/app/src/main/res/raw/{bark,meow,tweet}.wav`.
- Aperçu dans l'app : `assets/sounds/{bark,meow,tweet}.m4a` (déclarés dans pubspec, lire avec `audioplayers`).
- Canaux Android (l'app les crée au démarrage, lot app-profile dans `push_notification_service.dart`) :
  `hopetsit_default_channel` (existant), `hopetsit_bark`, `hopetsit_meow`, `hopetsit_tweet`,
  `hopetsit_vibrate` (sans son, vibration), `hopetsit_silent` (importance basse, ni son ni vibration).

## 2. Préférences de notification (lot bk-users-chat ↔ lot app-profile ↔ notificationSender)
- Stockage : champ `notificationPrefs` sur Owner/Sitter/Walker (synchronisé sur les 3 docs de la personne) :
  ```json
  { "sound": "default|bark|meow|tweet|vibrate|silent",
    "categories": { "messages": true, "bookings": true, "payments": true, "friends": true,
                    "pawmap": true, "live": true, "reviews": true, "subscriptions": true } }
  ```
- Routes : `GET /users/me/notification-prefs` → l'objet ci-dessus (défauts si absent) ;
  `PATCH /users/me/notification-prefs` (corps partiel, mêmes clés) → objet complet.
- Catégorie par type (server, dans notificationSender) :
  messages = NEW_MESSAGE, CHAT_AUTO_WELCOME, chat_addon_activated, BOOKING_PAID_CHAT_UNLOCKED ;
  bookings = booking_*, application_*, service_*, VISIT_REPORT, BOOKING_*, walk_*, new_request_nearby, handover_* ;
  payments = PAYMENT_*, payout_*, withdrawal_*, wallet_credited, kyc_payment_succeeded, REFERRAL_CREDITED ;
  friends = friend_*, family_* ; pawmap = lost_pet_sighting, sos_pet_nearby, map_boost_activated, profile_boost_activated ;
  live = live_tracking_*, live_still_active ; reviews = NEW_REVIEW, PREMIUM_ACHIEVED, TOP_SITTER_ACHIEVED ;
  subscriptions = subscription_activated, kyc_verified, kyc_rejected (tout type inconnu = bookings).
- Effet : catégorie désactivée → PAS de push ni d'e-mail (la notification in-app reste créée).
  Son : apns `aps.sound = '<sound>.caf'` (default → 'default' ; vibrate/silent → pas de champ sound),
  android `notification.channelId = 'hopetsit_<sound>'` + `sound: '<sound>'` (default → canal existant).
  Le push porte aussi `data.sound = '<sound>'` pour l'affichage en premier plan par l'app.

## 3. Changement d'e-mail par l'utilisateur (bk-users-chat ↔ app-profile ↔ web)
- `POST /users/me/email-change` `{ "newEmail": "...", "password": "..." }` → 200 `{ ok: true }` :
  vérifie le mot de passe, l'unicité sur les 3 collections, stocke `pendingEmail` + code haché (24 h),
  envoie le code à la NOUVELLE adresse (emailService.sendVerificationEmail, langue du compte).
  Erreurs : 400 format, 401 mot de passe, 409 e-mail déjà pris.
- `POST /users/me/email-change/confirm` `{ "code": "123456" }` → 200 `{ ok: true, email }` :
  remplace l'e-mail sur les 3 docs de la personne, vide `pendingEmail`. 400 code faux/expiré.
- `POST /users/me/email-change/resend` → renvoie le code (limité à 1 / 2 min).

## 4. Verrou contacts à 700 comptes (bk-users-chat ↔ app-chat ↔ web)
- Variable `CONTACTS_FREE_UNTIL_USERS` (défaut 700). Au-delà (Owner+Sitter+Walker ≥ seuil, cache 10 min),
  `POST /conversations/:id/share-phone` et `/share-address` répondent
  `402 { "error": "...", "code": "CONTACTS_LOCKED" }` SAUF si : réservation PAYÉE entre les deux
  personnes (n'importe quel rôle), ou abonnement actif (PawPremium / PawFollow / Famille / PawSpot /
  add-on chat) de l'expéditeur, ou staff. Rien ne change sous le seuil.
- `GET /users/me/benefits` ajoute `contactsLocked: boolean` (true = seuil atteint ET aucun débloquage global).
- App : sur 402 `CONTACTS_LOCKED`, feuille claire (clé `contacts_locked_title/body/cta`) → bouton vers la boutique.

## 5. Chat : vocal, réponse à un message, drapeaux admin (bk-users-chat ↔ app-chat ↔ admin ↔ web)
- Message (modèle) : nouveau champ `replyTo` :
  `{ messageId, body (≤120 car.), senderRole, senderId, kind: 'text'|'image'|'video'|'audio'|'phone_share'|'address_share' }` ou null.
  `attachments[].resourceType` peut valoir `'audio'` (vocal), avec `duration` en secondes.
  Nouveau `type` de message : `'voice'` (attachments[0] = audio).
- Envoi texte avec réponse : `POST /conversations/:id/messages` corps `{ body, replyTo: { messageId } }`
  → le serveur charge le message cité et stocke l'instantané complet.
- Vocal : `POST /conversations/:id/messages/attachments` (multipart existant, champ `files`, 1 fichier
  `.m4a` ou `.aac`, mimetype audio/*) + champ `kind=voice` + `duration` (secondes) + `replyTo` optionnel (JSON).
  Serveur : upload Cloudinary `resource_type: 'video'` (l'audio passe par là), stocke `resourceType: 'audio'`.
  Photos/vidéos : même route, `kind=media` (défaut) — corriger ce qui casse aujourd'hui.
- Socket `message:new` : payload inchangé + `replyTo` + `type` + attachments (avec `resourceType`).
- Drapeaux : `GET /app-config/chat-features` (auth) → `{ media: true, voice: true, reply: true }` ;
  `GET /app-config/admin/chat-features` et `PATCH /app-config/admin/chat-features` (requireAdmin, corps partiel).
  Serveur : drapeau à false → la route correspondante répond `403 { code: 'FEATURE_DISABLED', feature }`.
  App/web : chargent les drapeaux à l'ouverture du chat et cachent les boutons désactivés.

## 6. Présence « en ligne » (bk-users-chat ↔ app-chat ↔ app-map ↔ web)
- Serveur : à la connexion/déconnexion socket (les 3 rooms de rôle), émet aux amis et aux
  correspondants de conversation `presence:update { userId, online: bool, at }` ; `lastSeenAt`
  écrit sur le doc à la déconnexion.
- `GET /conversations/list` : chaque item porte `isOnline` (calculé en direct via isUserOnline sur
  l'identité complète de la personne) et `lastSeenAt`. `GET /friends` et `/friends/members/nearby` :
  `isOnline` réel (même calcul) — plus le champ figé `isOnline` du doc.
- Clients : point vert = `isOnline` à la lecture + mises à jour `presence:update`.

## 7. Remise et rendu de l'animal (bk-bookings ↔ app-home-bookings ↔ admin)
- Champs Booking (en plus de pickupProof/returnProof/serviceStartedAt existants) :
  `handover: { pickupReminderAt, pickupOverdueAt, pickupProviderAt, pickupOwnerConfirmedAt, pickupAutoConfirmedAt,
               returnReminderAt, returnProviderAt, returnOwnerConfirmedAt, returnAutoConfirmedAt,
               pickupLat, pickupLng, returnLat, returnLng, stillActiveNoticeAt }` (dates null par défaut).
- Routes (existantes réutilisées) : `POST /bookings/:id/service/start` = « Animal récupéré » (prestataire ;
  accepte `lat`, `lng` en plus du code et de la photo), `POST /bookings/:id/service/complete` = « Animal rendu »
  (prestataire ; `lat`, `lng`, photo). NOUVELLES : `POST /bookings/:id/handover/confirm-pickup` (owner),
  `POST /bookings/:id/handover/confirm-return` (owner → identique à `/service/confirm` : libère le séquestre).
- Planificateur `handoverScheduler.js` (toutes les 60 s) : rappel 30 min avant le début aux DEUX parties
  (`handover_pickup_soon`), 30 min avant la fin (`handover_return_soon`), 1 h après le début sans
  récupération → `handover_pickup_overdue` aux deux ; 2 h après « récupéré » sans confirmation owner →
  auto-confirmation (`handover_pickup_auto`) ; 2 h après « rendu » sans confirmation → auto-confirmation
  + libération (`handover_return_auto`) (remplace l'attente 48 h pour ce cas).
  Notifications au moment de l'action : `handover_picked_up` (owner, bouton confirmer), `handover_pickup_confirmed`
  (prestataire), `handover_returned` (owner), `handover_return_confirmed` (prestataire).
  Templates dans les 9 `backend/src/locales/*/notifications.json` (title/body/emailSubject/emailBody).
- `GET /bookings/:id` (détail) renvoie `timeline: [{ step, at, by }]` avec step ∈
  planned | picked_up | pickup_confirmed | returned | return_confirmed | completed, et l'objet `handover`.

## 8. Partage en direct robuste (bk-bookings ↔ app-map)
- Serveur garde la DERNIÈRE position de chaque diffuseur en RAM 24 h (`lastSeenAt`) ; ne coupe jamais
  de lui-même. `GET /friends/live-positions` : chaque entrée porte `lastSeenAt` et `stale` (true si > 3 min).
  `POST /friends/live-position` accepte `duration` ∈ '1h'|'4h'|'until_stop' (défaut until_stop) et `heartbeat: true`
  (sans lat/lng = simple battement) ; à l'échéance de la durée le serveur émet `map:friend-offline` et
  notifie le diffuseur (`live_session_ended`). Toutes les 4 h de partage : notification `live_still_active`.
- App : `map:go-offline` UNIQUEMENT sur action utilisateur ou fin de durée choisie ; reconnexion socket
  automatique + battement HTTP toutes les 60 s si le socket tombe ; état affiché « actif / signal perdu ».

## 9. Pop-up promo + saisie de code (app-profile ↔ app-home-bookings)
- `frontend/lib/widgets/promo_code_sheet.dart` (lot app-profile) exporte
  `Future<bool> showPromoCodeSheet(BuildContext context, {required Color accent})` (true = code appliqué)
  et `class PromoPopup` (affiché une seule fois, jamais à la 1re ouverture, fermable, clé GetStorage
  `promo_popup_shown_v565`, compteur `app_open_count`). Le lot app-home-bookings appelle
  `showPromoCodeSheet` depuis l'écran de paiement (« J'ai un code ») et la boutique.

## 10. Admin (lot admin)
- Utilise UNIQUEMENT les routes ci-dessus + adminRoutes.js existantes ; compteurs cliquables du tableau
  de bord → liste avec l'e-mail du compte (les routes `/admin/users`… existent, vérifier les champs renvoyés).
