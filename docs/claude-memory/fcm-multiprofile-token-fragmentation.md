---
name: fcm-multiprofile-token-fragmentation
description: Push notif silently missing for a role = FCM token registered on a different role doc (1 compte = 3 profils)
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

Push notif (FCM) absent alors que l'email arrive = quasi toujours la **fragmentation des tokens multi-profils**.

`registerFcmToken` (userController) écrit le token **uniquement sur le doc du rôle courant** (`req.user.id` + `req.user.role`). Mais 1 compte = 3 profils = 3 docs séparés (Owner/Sitter/Walker). Quand le backend notifie le rôle X (`sendNotification({role:'owner', ...})`), `resolveUser` lit `X.fcmTokens` — **vides** si le token a été enregistré sous un autre rôle → `sendPush` saute (`[notif.push] skipped: no_tokens`). L'email part quand même car `resolveUser` a un fallback cross-collection (et l'email existe sur chaque doc).

**Fix posé (v408)** : `notificationSender.gatherFcmTokens(primary, userId)` unit les `fcmTokens` des 3 docs de rôle de la même personne (`$or: [{_id}, {email}, {oldId}]`) avant `sendPush`. Bénéficie à TOUTES les notifs push. C'est le pendant FCM du fix badge chat v401 (émettre `message:new` aux 3 rooms de rôle).

**Reste à surveiller** : la purge auto des dead-tokens dans `sendPush` ne nettoie que le doc `{userId, role}` cible → des tokens morts sur les docs frères persistent (ré-essayés, échouent, non bloquant). Voir [[chat-badge-three-sources]] pour la logique badge.

**Badge « demande de suivi »** : `pawfollow_request` (requestLiveTracking + requestLiveTrackingByConversation, bookingController) créait le message SANS incrémenter `unreadCount` → badge 0 au resync. Fix v408 : `$inc` owner/sitterUnreadCount (booking) ou `participants.$.unreadCount` (friendChat). Le walker partage `sitterUnreadCount` (pas de walkerUnreadCount au schéma Conversation).
