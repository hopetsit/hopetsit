---
name: maps-blank-google-cloud-key
description: "Carte blanche app : fond uni qui transparaît = RENDU Android (useAndroidViewSurface, fix v454) ; quadrillage gris = clé Google Cloud"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

## DEUX causes distinctes — TRIER PAR L'APPARENCE avant d'accuser Google :

**(A) Fond du scaffold qui TRANSPARAÎT (rose/blanc uni, le widget ne se peint pas) = RENDU natif Android, PAS la clé.** Indice décisif : la carte du SITE WEB marche mais TOUTES les cartes de l'app sont blanches → c'est le rendu, pas la facturation. `google_maps_flutter_android` utilise par défaut le *Texture Layer Hybrid Composition* (TLHC) qui rend une surface BLANCHE sur beaucoup d'appareils, surtout après un resize de la vue (notre mode « agrandir la carte »). **Fix v454** (`main.dart`, après `ensureInitialized`) : `final m = GoogleMapsFlutterPlatform.instance; if (m is GoogleMapsFlutterAndroid) m.useAndroidViewSurface = true;` + deps directes figées `google_maps_flutter_android: 2.18.12` + `google_maps_flutter_platform_interface: 2.14.1`. (C'était la VRAIE cause chez Daniel — pas Google Cloud, malgré mon 1er diagnostic.)

**(B) Quadrillage GRIS Google sans tuiles (parfois « For development purposes only ») = échec d'AUTH de la clé** → là seulement, voir Google Cloud ci-dessous.

Code app sain par ailleurs : le widget `GoogleMap` dans `paw_map_screen.dart` est **inconditionnel** (`_mapExpanded` défaut false), et la clé est dans `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY` = `AIzaSyBw11dPKfWj67XM_xOQdL5VU0au2GijxuI`).

**Cause réelle = configuration Google Cloud de la clé Maps** (action de Daniel, je ne peux pas y accéder) :
1. **Facturation** désactivée sur le projet (essai gratuit expiré / CB retirée) → TOUTES les cartes deviennent blanches d'un coup. Cause n°1 d'une carte « qui a disparu ».
2. **« Maps SDK for Android »** pas activé.
3. **Restriction de la clé** (Applications Android) doit lister `com.hopetsit.app` + l'empreinte SHA-1. Si seul le SHA-1 *Play App Signing* est listé, les APK **sideloadés** (buildés en local) ont une carte blanche alors que les installs Play Store marchent.
4. Quota dépassé.

**SHA-1 du keystore release/upload** (`C:/Users/Usuario/hopetsit-release.jks`, alias `hopetsit`, via `key.properties`) = `64:1E:19:91:2C:1F:2A:8D:B5:E8:1F:B3:9D:AC:08:23:30:14:ED:85` (SHA-256 `2E:AE:C3:53:...:C8:16`). C'est CE SHA-1 qu'il faut whitelister pour les APK buildés en local. Pour le Play Store, ajouter EN PLUS le SHA-1 *Play App Signing* (Play Console → Configuration → Signature de l'app).

NB : `google_maps_flutter` n'expose pas de callback d'échec d'auth → impossible d'afficher proprement un message d'erreur in-app ; l'échec n'apparaît que dans logcat (« Authorization failure »). Lié à [[git-deploy-remote-gotcha]] (déploiement) — ici c'est purement Google Cloud, rien à pousser.
