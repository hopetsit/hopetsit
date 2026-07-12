---
name: v498-package-rename
description: v498 — renommage package Android com.hopetsit.app → com.cardellihermanos.hopetsit (Google Play) + 2 actions console Daniel + crash GetX déjà corrigé
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

**v498** (build 23.1.498+498). Daniel a envoyé 2 choses (screenshots Crashlytics + refus Google Play).

**1. Crash GetX « improper use of a GetX » (RxInterface.notifyChildren / ObxState.build)** = DÉJÀ CORRIGÉ. Les 24 crashes sont sur builds 489/444/470 UNIQUEMENT (graphe versions), tous AVANT le fix v490 (la règle d'or `Obx(()=>Builder(…lit .value…))` retirée du signup_wizard). Grep `Obx(() => Builder` = 0 occurrence dans le code actuel. Les users qui crashent sont sur de vieilles APK → ils crasheront plus en passant à v498. Rien à recoder.

**2. Renommage package Android** (Google Play refuse l'AAB : exige `com.cardellihermanos.hopetsit` = société CARDELLI HERMANOS LIMITED). Fait dans le CODE :
- `frontend/android/app/build.gradle.kts` : `namespace` + `applicationId` → com.cardellihermanos.hopetsit.
- MainActivity déplacé : ancien `kotlin/com/hopetsit/app/` ET stray `kotlin/com/hopetsit/hopetsit/` SUPPRIMÉS → nouveau `kotlin/com/cardellihermanos/hopetsit/MainActivity.kt` (garde `FlutterFragmentActivity`, requis image_picker/local_auth).
- `frontend/android/app/google-services.json` : les 3 `package_name` Android (android_client_info + 2 oauth android_info) → nouveau package. mobilesdk_app_id/api_key/cert_hash/web client INCHANGÉS (FCM marche via app id). ios_info bundle_id laissé `com.hopetsit.app`.
- `website/public/.well-known/assetlinks.json` : 2 entrées (nouveau + ancien package, même SHA-256 `2E:AE:C3:…`).
- iOS NON touché (bundle id reste com.hopetsit.app, App Store séparé). firebase_options.dart inchangé.

**⚠️ 2 ACTIONS CONSOLE OBLIGATOIRES côté Daniel (je ne peux pas les faire) sinon login Google + carte cassés sur le nouveau package :**
1. **Firebase Console** → Paramètres projet → Ajouter une app Android → package `com.cardellihermanos.hopetsit` → ajouter SHA-1 release `2B:08:F1:DC:40:2A:69:99:F5:FB:73:12:EC:B0:C7:52:4D:A1:0D:6B` + `64:1E:19:91:2C:1F:2A:8D:B5:E8:1F:B3:9D:AC:08:23:30:14:ED:85` (les 2 cert_hash de google-services.json). → re-télécharger google-services.json (optionnel, le mien marche pour le build + FCM). Crée l'OAuth client Android → débloque Google Sign-In.
2. **Google Cloud Console** → clé Maps `AIzaSyBw11dPKfWj67XM_xOQdL5VU0au2GijxuI` → restriction « Applications Android » → AJOUTER `com.cardellihermanos.hopetsit` + SHA-1. Sinon carte grise.

Voir [[v497-livraison]] pour l'état précédent. RÈGLE Daniel : copier APK dans Downloads à chaque build.
