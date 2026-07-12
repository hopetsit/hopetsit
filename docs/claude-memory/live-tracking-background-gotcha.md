---
name: live-tracking-background-gotcha
description: "Le suivi en direct s'éteignait car PawMap dispose() coupait le broadcast ; foreground service couvre le background mais PAS le swipe-kill"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

v414 — Daniel : "qd l'app se ferme le direct s'éteint, je veux qu'il reste allumé".

CAUSE : `paw_map_screen.dart` `dispose()` appelait `_liveMap.stopBroadcasting()` → quitter l'écran PawMap (ou l'OS qui dispose l'écran en arrière-plan) tuait le partage. RETIRÉ (commenté v414).

`LiveMapService` est un service PERMANENT (GetX). Sur **Android** : `Geolocator.getPositionStream` avec `AndroidSettings.foregroundNotificationConfig` (notif persistante, setOngoing, wakeLock) → GPS + Timer 10s + socket survivent en **arrière-plan** (permissions FOREGROUND_SERVICE / FOREGROUND_SERVICE_LOCATION / BACKGROUND_LOCATION déjà dans le Manifest). Sur **iOS** : `AppleSettings.allowBackgroundLocationUpdates:true` + showBackgroundLocationIndicator (UIBackgroundModes>location déjà dans Info.plist) ; `geolocator_apple` ajouté en dépendance DIRECTE (était transitive).

Le broadcast s'arrête seulement via : bouton Stop du bandeau "Live actif", cap session 2 h, ou 30 min d'immobilité.

**v416 — gros chantier swipe-kill FAIT (Android)** : `flutter_background_service` lance un foreground service dans un **isolate SÉPARÉ** (START_STICKY, type `location`) qui survit au swipe-kill. Il lit token+baseUrl+ville dans GetStorage (clés `bg_live_*` posées par `startBroadcasting`) et POST la position toutes les 15 s sur **`POST /friends/live-position`** (backend : `relayLivePosition` dans mapSocket.js fait le même fanout `map:friend-position` que la socket). Fichiers : `lib/services/live_tracking_bg.dart` (entrée `@pragma('vm:entry-point') onLiveBgStart`), configuré au boot dans main.dart, manifest : `foregroundServiceType="location"` mergé sur le service de la lib (exigence Android 14+).

⚠️ **iOS : impossible après force-quit** (règle Apple, pas un bug). iOS couvre seulement app ouverte + arrière-plan (allowBackgroundLocationUpdates) ; après un swipe-kill, relance seulement sur changement significatif (~500 m). Documenté dans HoPetSit_iOS_Build_Guide_v23.1.416.pdf.
