---
name: chat-gate-payment-required-v500
description: « Messages cassés » sur la version Store = verrou PAYMENT_REQUIRED (pas un bug) ; diagnostic + v500 (panneau clair + fix points PawMap + vraies erreurs) ; méthode de reproduction backend avec comptes +testa/+testb
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

**Contexte (06/07/2026)** : app v499 EN LIGNE sur Google Play. Daniel : « impossible d'écrire des messages, le clavier se ferme, suivre l'animal ne se lance pas, AUCUNE erreur, le web marche » (3 comptes neufs sur 3 téléphones).

**DIAGNOSTIC (pas un bug !)** : c'est le verrou métier de la tâche #116 — `requirePaidBooking` (backend/src/middleware/chatAccess.js) renvoie 403 `PAYMENT_REQUIRED` tant que la réservation n'est pas payée ET pas d'abo actif. L'app remplaçait alors la saisie par un MINI-bandeau discret (« Le chat s'ouvre après confirmation du paiement ») → le clavier se fermait ~1s après l'ouverture (le fetch 403 arrive pendant la frappe) → effet « app cassée ». Daniel/amis ne l'avaient JAMAIS vu : staff/premium/réservations payées (+ son email `dadaciao84@gmail.com` est en liste blanche EN DUR dans chatAccess.js). Le web « marchait » car testé avec SON compte.

**Why:** tout symptôme « ça marche pour nous mais pas pour les nouveaux » → penser d'abord aux GATES métier (chat, tracking, signalements) avant de chercher une panne.

**How to apply:**
- **Reproduction backend sans device** : signup via `POST /api/v1/auth/signup` `{role, user:{email,password,name}}` avec alias Gmail `dadaciao84+xxx@gmail.com` (Daniel relaie les codes OTP) → `POST /auth/verify?email=..&code=..` (email en QUERY) → login → dérouler amis/conversations/messages en curl (`--ssl-no-revoke` obligatoire sur ce PC). Comptes créés : `dadaciao84+testa@gmail.com` / `+testb` (mdp `TestHopetsit2026!`, owners, amis entre eux, conv `6a4b72ab94b8d5f02066773d`). Parcours COMPLET vérifié OK en prod → backend sain.
- **Diagnostic chat 403 en prod** : `GET /api/v1/diagnostic/chat-access/:convId` (auth) = verdict de chaque bypass. `GET /diagnostic/version` (public) = commit déployé sur Render.
- **Bypasses du gate** (chatAccess.js) : friendChat (participant par id du TOKEN) → staff doc du rôle courant → email whitelist → hasActivePawFollow → hasAnyActiveSubscription (4 timers) → même famille → booking payé. ⚠️ le check staff lit le doc du RÔLE COURANT (pas cross-rôle email/oldId comme /me/benefits) — mais l'admin propage isStaff sur les 3 docs depuis v494.
- **Firebase Installations OK** pour les 2 signatures (testé : POST firebaseinstallations.googleapis.com avec X-Android-Package + X-Android-Cert store `F30C55...` et upload `641E19...` → 200) → notifs pas bloquées par les clés.

**v500 (build 23.1.500+500, APK+AAB dans Downloads, PUSH 10c9138)** :
1. Panneau clair « Chat verrouillé pour l'instant » + explication + Payer + Voir les abonnements (owner) / sans Payer (sitter/walker qui n'avait AUCUNE gestion du 403) + snackbar au déclenchement + clés `chat_gate_*` ×6.
2. Fix points PawMap 1er lancement : watchdog v352 ne tournait pas si géoloc timeout (early return AVANT) → watchdog TOUJOURS armé (3×4s) + 2e tentative GPS 15s (`_scheduleFirstLoadWatchdog`, paw_map_screen).
3. Échec d'envoi chat → snackbar avec la VRAIE erreur serveur (code+message) dans les 2 contrôleurs chat.

**⚠️ VRAIE CAUSE RACINE DU CLAVIER (trouvée APRÈS, captures Daniel)** : PAS le gate ! `ChatController.isLoading` était PARTAGÉ entre `_loadConversations` (liste) et `loadChatMessages` (conversation ouverte) → chaque refresh de la liste en arrière-plan (socket message:new, resync badge v444, activité WEB du même compte en parallèle) basculait l'écran de conversation ouvert sur le spinner plein écran → champ de saisie DÉTRUIT → clavier fermé instantanément (« comme un auto-retour »). Peu visible avant (peu d'activité simultanée) ; flagrant en test multi-appareils. FIX v500 : flag dédié `isMessagesLoading` (2 contrôleurs) + spinner seulement si messages de CETTE conv chargent ET liste vide (2 écrans). PUSH efdf3fe.

**v500 aussi** : navigation — boucle amis↔carte n'empile plus (`_openScreen` canPop?Get.off:Get.to dans paw_map_screen ×6 + Get.off dans people_live/alerts) → 1 seul retour ramène au menu (PUSH 0aadb1c).

**Staff VÉRIFIÉ en prod** : case admin cochée sur +testa → `/me/benefits` isStaff/isPremium/premiumActive/pawFollowActive = true immédiatement. L'octroi marche ; déblocage chat = rouvrir la conversation.

**Web (PUSH 77a77b5)** : APP EN LIGNE SUR GOOGLE PLAY 🎉 (`com.cardellihermanos.hopetsit`). Composant `StoreBadges` (badges noirs officiels) : Google Play actif avec `&hl=<langue site>` ; App Store « Bientôt sur iOS » (clé `store_ios_soon` ×6) — à activer à la validation Apple. Posé : accueil (héros + CTA final) + /download (refaite + 4 captures).

**RESTE OUVERT** : ami du Bénin « voir en direct » → vérifier qu'il a activé « Partager ma position » (OFF par défaut). Profil SITTER créé sur +testb (email non vérifié, OTP jamais saisi — compte incomplet, supprimable). Lié : [[couronne-premium-multi-sources]], [[v498-package-rename]].
