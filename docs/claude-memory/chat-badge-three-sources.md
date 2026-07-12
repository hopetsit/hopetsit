---
name: chat-badge-three-sources
description: "Le badge \"1\" de l'onglet chat a 3 sources indépendantes ; debug du \"badge ne vient pas\""
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

Le badge non-lu de l'onglet Chat (bottom nav, badgeIndex==1) lit `NotificationsController.unreadChat`, alimenté par **3 chemins indépendants** :

1. **Socket `message:new`** — temps réel quand l'app est ouverte + socket connecté. `_attachSocketListener` bumpe +1 (self-check via `triggeredBy.userId` et `message.senderId` ≠ myId).
2. **Push FCM foreground** — `push_notification_service` bumpe via `bumpUnreadChatImmediate()` quand `data.type` ∈ {new_message, message, message_new}. Le backend met bien `type:'NEW_MESSAGE'` dans le data du push.
3. **Resync serveur** — `syncChatBadgeFromServer()` somme le `unreadCount` par conversation (GET liste convs). Tourne **uniquement** dans `loadInitial()` → donc au **resume** de l'app et à l'ouverture de l'écran Notifications, PAS en idle sur Home.

**Gotcha multi-profils (staff) corrigé en v401 :** une conversation fige le `userModel` du participant à sa création. L'emit socket partait vers `user:<userModel>:<id>` alors que le destinataire rejoint sa room avec le rôle de **sa session JWT courante** → décalage = `message:new` jamais reçu = badge muet. Le push FCM tolérait déjà le décalage (fallback `resolveUser` qui cherche le même `userId` dans les autres collections). Fix : `emitChatMessage` (backend/src/sockets/emitter.js) emit désormais vers les 3 rooms owner/sitter/walker du `userId` (socket dans 1 seule room → pas de double-bump). Deploy-only, pas de rebuild.

**Quirk unread booking** : pas de `walkerUnreadCount` ; l'unread provider (sitter ET walker) est stocké dans `sitterUnreadCount`. Chat ami/famille = `participants[].unreadCount`.

Régression connue non corrigée (nécessiterait rebuild) : NotificationsController et ChatController font tous deux `socket.off('message:new')` puis `.on(...)` → ouvrir/fermer un chat peut déconnecter le listener badge pour le reste de la session. Le FCM foreground (listener séparé) et le resync au resume couvrent ce trou. Voir [[python3-store-alias-hook-error]] pour le contexte build.
