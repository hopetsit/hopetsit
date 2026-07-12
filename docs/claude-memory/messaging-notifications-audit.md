---
name: messaging-notifications-audit
description: Audit complet messagerie/badges/push/email/cloche/bandeau (v448) — vraies causes racines + ce qui reste
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

Stack réel (à NE PAS confondre) : temps réel = **Socket.IO** (pas Supabase), push = **FCM**, base = **MongoDB/Mongoose** (pas SQL). Pas de table `user_notifications`/`requests` ; vrais modèles = `Conversation` (compteurs `ownerUnreadCount`/`sitterUnreadCount` — **walker partage le slot sitter**, pas de `walkerUnreadCount`), `Notification`, `Booking`, `Post`. Friend-chat = `participants[].unreadCount`.

**Source unique de vérité badge chat (frontend)** = `NotificationsController` (socket `_onSocketMessageNew` dédupé par id msg + `syncChatBadgeFromServer` = somme serveur). v444 avait migré `chat_controller.dart` mais **2 écrivains legacy oubliés** = la cause récurrente du « 1 puis 5 ».

CORRIGÉ v448 (audit) :
- `sitter_chat_controller.dart:~356` : `unreadChat.value++` brut → `scheduleChatBadgeResync()` (double-comptage sitter/walker). cf [[chat-badge-1-then-5-fix]]
- `stacked_navigation_wrapper.dart:~114` : `unreadChat.value=0` au tap onglet Chat → `syncChatBadgeFromServer()` (sinon le badge « revient »). NB : `custom_navigation_bar.dart` = MORT (jamais instancié) ; le live = `StackedNavigationWrapper`.
- `airwallexWebhookController.js:378/428/444` : `paymentIntentId` **non déclaré** (var = `piId`) → ReferenceError avalé → garde anti-doublon cassée + messages système chat non postés ⇒ **double `booking_paid`**. Renommé en `piId`.
- i18n : clé manquante `profile_update_failed` (rendait la clé brute à l'échec save profil) ajoutée ×6.
- (déjà fait avant) `mapReportRoutes.resolvePremium` : override STAFF manquant → pins premium filtrés sur la carte.

CORRIGÉ v448 LOT 2/3/4 (audit, analyze clean + node -c) :
- Badge fantôme : `syncChatBadgeFromServer` DÉDUP par interlocuteur (clé `u:<otherId>`) avant somme.
- Cloche sur-compte : `push_notification_service.dart` ne bump plus `unreadCount` pour les types chat.
- Bandeau : `_isResponding` → try/finally (accept/refuse marche en boucle) ; « Confirme la fin » owner (statuts terminaux exclus + borne 30 j) ; provider in_progress (borne svcMaxAgeMs 7 j sur fin/début).
- EMAIL gating hors-ligne : `emitter.isUserOnline(userId)` (teste les 3 rooms de rôle) + `notificationSender` saute l'email pour `new_message` si destinataire en ligne (`PRESENCE_GATED_EMAIL_TYPES`). Log `[notif.email.skip]`.
- Push Android : `AndroidManifest.xml` + `com.google.firebase.messaging.default_notification_channel_id` = `hopetsit_default_channel`.
- Doublons : webhook Airwallex `booking_paid`/`booking_paid_owner` gardés par `wasAlreadyPaid` ; `new_request_nearby` exclut les docs prestataire de l'owner (selfIds).
- Script DB : `backend/scripts/audit_messaging_cleanup.js` (dry-run ; `--fix` pour appliquer — compteurs<0, reports (0,0), notifs doublons<60s, paires multi-conv). À lancer côté admin/Render avec MONGO_URI.

RESTE (décision/infra requise) :
- **ESP emailing** (SendGrid/Mailgun/SES) pour tuer le délai 10-20 min = throttling Gmail SMTP → compte+clés+domaine (Daniel). Sinon emails restent lents pour les users HORS ligne.
- PayPal capture hardcode rôle sitter (edge case ; Airwallex = chemin primaire) — non corrigé.
- Badge Réservations ≠ bande (`pendingActionCount` sans filtre dismiss/stale) — non corrigé (divergence mineure, pas de fausse action car la bande filtre déjà).
- Modèle dual-conversation par paire (refactor structurel) — le badge dédoublonne déjà côté lecture.
- Tests réels multi-comptes 2 téléphones = NON exécutables par moi → protocole + logs fournis.
- iOS Info.plist tronqué dans CETTE copie « FINAL_FIXED » (probable artefact d'archive) — vérifier le vrai repo.
