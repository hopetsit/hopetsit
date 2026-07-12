---
name: chat-badge-1-then-5-fix
description: Badge messages incohérent (1 puis 5 qui revient) = double-comptage + faux-zéro ; fix source-unique-serveur v444
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

Bug Daniel récurrent : à la réception d'un message, le badge messages affichait « 1 » puis « 5 qui revient » (compte qui gonfle / se ré-inflate après lecture).

**Deux causes combinées (corrigées v444) :**
1. **Sur-comptage** — `notifications_controller._onSocketMessageNew` faisait `unreadChat++` **sans dédup par id de message**, alors que le backend émet `message:new` aux **3 rooms de rôle** (un compte multi-rôles owner+sitter+walker reçoit le même message plusieurs fois) + rejeu à la reconnexion. EN PLUS, `chat_controller` (branche « message pour autre conv ») ré-incrémentait `unreadChat` → double source.
2. **Faux-zéro qui revient** — `clearChatBadge()` (tap onglet Chat, `custom_navigation_bar.dart`) forçait `unreadChat=0` LOCALEMENT alors que le serveur gardait les conversations non-lues → au prochain `syncChatBadgeFromServer()` le vrai total « revenait » (le 5).

**Fix = source de vérité unique = serveur :**
- `_seenChatMsgIds` + `_chatMsgId()` + `_chatMsgSeenOrDupe()` : chaque message ne compte qu'1× (`_onSocketMessageNew` et `bumpUnreadChatImmediate(messageId:)` partagent la dédup ; FCM passe `data['messageId']`).
- `scheduleChatBadgeResync({ms})` : resync DÉBOUNCÉ de `syncChatBadgeFromServer` (somme des `unreadCount` serveur) appelé après chaque bump optimiste ET après lecture d'une conv (`chat_controller` après `markConversationRead`) + au resume.
- `chat_controller` ne fait plus `unreadChat++` → déclenche juste `scheduleChatBadgeResync()`.
- tap onglet Chat → `syncChatBadgeFromServer()` (vrai total) au lieu de `clearChatBadge()` (le badge se vide ensuite conv par conv à la lecture réelle).

**Backend déjà correct (ne pas re-toucher)** : `conversationService`/`conversationController` incrémentent `ownerUnreadCount`/`sitterUnreadCount` (+ `participants[].unreadCount` ami/famille) à l'envoi, remettent à 0 à la lecture ; la liste projette le bon champ selon le rôle (owner→ownerUnreadCount, prestataire→sitterUnreadCount). Push multi-profils OK via `notificationSender.gatherFcmTokens` (union des fcmTokens des 3 docs de rôle) + envoi mail. cf [[chat-badge-three-sources]], [[fcm-multiprofile-token-fragmentation]].
