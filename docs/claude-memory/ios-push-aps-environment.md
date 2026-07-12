---
name: ios-push-aps-environment
description: Pas de push sur iPhone (mais Android OK) = aps-environment manquant + clé APNs pas uploadée dans Firebase
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

Push absent sur **iPhone** alors qu'**Android + email** marchent = problème **APNs/iOS**, pas le backend (le backend envoie bien les 3 canaux via sendNotification).

Deux causes, les deux nécessaires :
1. **Code (corrigé v413)** : `frontend/ios/Runner/Runner.entitlements` n'avait PAS la clé `aps-environment` → iOS refuse l'enregistrement aux notifications distantes → FCM ne livre rien sur iOS. Ajoutée (`development` ; promue `production` à l'archive de distribution via signing auto). `Info.plist` a déjà `UIBackgroundModes > remote-notification`.
2. **Hors-code (Daniel doit faire)** :
   - Xcode → Runner → Signing & Capabilities → **+ Push Notifications**.
   - **Firebase Console → Project settings → Cloud Messaging → Apple app config → uploader la clé APNs `.p8`** (+ Key ID + Team ID). C'est LA cause #1 d'un push iOS muet quand Android marche — sans elle FCM n'a aucun moyen d'atteindre APNs.

Prend effet au **prochain build iOS** (sur le Mac de Daniel) ; n'affecte pas l'APK Android. Voir [[fcm-multiprofile-token-fragmentation]] pour l'autre cause de push manquant (token sur un autre rôle).
