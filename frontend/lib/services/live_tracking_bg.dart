// v416 — Daniel : "le suivi en direct doit rester allumé même quand l'app est
// fermée de force (swipe-kill)".
//
// PROBLÈME : la diffusion socket vit dans l'isolate UI. Quand l'utilisateur
// "swipe" l'app, le process Dart meurt → la position ne part plus.
//
// SOLUTION (Android) : flutter_background_service lance un FOREGROUND SERVICE
// dans un ISOLATE SÉPARÉ (notif persistante, START_STICKY) qui SURVIT au
// swipe-kill. Cet isolate ne peut pas tenir une socket facilement → il lit la
// position GPS et la POST en HTTP sur /friends/live-position toutes les ~15 s
// avec le Bearer token (le backend relaie aux amis/famille comme la socket).
//
// iOS : Apple INTERDIT l'exécution continue après un force-quit. Le mieux
// possible est un "background fetch" ponctuel (onIosBg) — documenté comme
// limite plateforme dans le guide iOS. Le foreground/arrière-plan normal est
// déjà couvert par AppleSettings.allowBackgroundLocationUpdates (live_map_service).

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

/// v559 — textes de la notification du service de fond dans la langue du
/// téléphone. Ce code tourne dans un ISOLATE séparé (pas de GetX, pas de
/// `.tr`) : on lit `Platform.localeName` et on garde une petite table locale.
String bgLiveText(String key) {
  final lang = Platform.localeName.toLowerCase().split(RegExp('[_-]')).first;
  const t = <String, Map<String, String>>{
    'fr': {'channel': 'Suivi en direct', 'channel_desc': 'Partage de position avec ton cercle PawFollow', 'active': 'Suivi en direct actif', 'title': 'HoPetSit — suivi en direct', 'body': 'Ta position est partagée avec ton cercle.'},
    'en': {'channel': 'Live tracking', 'channel_desc': 'Location sharing with your PawFollow circle', 'active': 'Live tracking active', 'title': 'HoPetSit — live tracking', 'body': 'Your location is shared with your circle.'},
    'es': {'channel': 'Seguimiento en vivo', 'channel_desc': 'Ubicación compartida con tu círculo PawFollow', 'active': 'Seguimiento en vivo activo', 'title': 'HoPetSit — seguimiento en vivo', 'body': 'Tu ubicación se comparte con tu círculo.'},
    'de': {'channel': 'Live-Tracking', 'channel_desc': 'Standortfreigabe für deinen PawFollow-Kreis', 'active': 'Live-Tracking aktiv', 'title': 'HoPetSit — Live-Tracking', 'body': 'Dein Standort wird mit deinem Kreis geteilt.'},
    'it': {'channel': 'Monitoraggio live', 'channel_desc': 'Posizione condivisa con la tua cerchia PawFollow', 'active': 'Monitoraggio live attivo', 'title': 'HoPetSit — monitoraggio live', 'body': 'La tua posizione è condivisa con la tua cerchia.'},
    'pt': {'channel': 'Seguimento ao vivo', 'channel_desc': 'Partilha de localização com o teu círculo PawFollow', 'active': 'Seguimento ao vivo ativo', 'title': 'HoPetSit — seguimento ao vivo', 'body': 'A tua localização é partilhada com o teu círculo.'},
    'ko': {'channel': '실시간 추적', 'channel_desc': 'PawFollow 서클과 위치 공유', 'active': '실시간 추적 켜짐', 'title': 'HoPetSit — 실시간 추적', 'body': '내 위치가 내 서클과 공유되고 있어요.'},
    'ja': {'channel': 'ライブ追跡', 'channel_desc': 'PawFollowサークルと位置情報を共有', 'active': 'ライブ追跡が有効です', 'title': 'HoPetSit — ライブ追跡', 'body': 'あなたの位置情報がサークルと共有されています。'},
    'pl': {'channel': 'Śledzenie na żywo', 'channel_desc': 'Udostępnianie lokalizacji Twojemu kręgowi PawFollow', 'active': 'Śledzenie na żywo aktywne', 'title': 'HoPetSit — śledzenie na żywo', 'body': 'Twoja lokalizacja jest udostępniana Twojemu kręgowi.'},
  };
  return (t[lang] ?? t['en']!)[key] ?? t['en']![key] ?? '';
}

/// Canal de notif du foreground service.
const String kBgChannelId = 'hopetsit_live_tracking';
const int kBgNotifId = 776655;

// Clés GetStorage partagées entre l'isolate UI (live_map_service) et l'isolate
// de fond. Le token est recopié ici car il vit normalement dans le secure
// storage (inaccessible simplement depuis l'isolate de fond).
const String kBgLiveActive = 'bg_live_active';
const String kBgToken = 'bg_live_token';
const String kBgBaseUrl = 'bg_live_base_url';
const String kBgCity = 'bg_live_city';

/// À appeler UNE fois au démarrage (main). Idempotent + non bloquant.
Future<void> configureLiveTrackingService() async {
  try {
    // Le canal doit exister avant configure() (notif du foreground service).
    final fln = FlutterLocalNotificationsPlugin();
    await fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(AndroidNotificationChannel(
          kBgChannelId,
          bgLiveText('channel'),
          description: bgLiveText('channel_desc'),
          importance: Importance.low,
        ));
  } catch (e) {
    debugPrint('[bgLive] channel create failed: $e');
  }

  try {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onLiveBgStart,
        isForegroundMode: true,
        autoStart: false,
        autoStartOnBoot: false,
        notificationChannelId: kBgChannelId,
        initialNotificationTitle: 'HoPetSit',
        initialNotificationContent: bgLiveText('active'),
        foregroundServiceNotificationId: kBgNotifId,
        foregroundServiceTypes: const [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onLiveBgStart,
        onBackground: onLiveIosBg,
      ),
    );
  } catch (e) {
    debugPrint('[bgLive] configure failed: $e');
  }
}

/// Démarre le service de fond (appelé quand le broadcast démarre).
Future<void> startLiveTrackingService() async {
  try {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
  } catch (e) {
    debugPrint('[bgLive] start failed: $e');
  }
}

/// Arrête le service de fond (appelé quand le broadcast s'arrête).
Future<void> stopLiveTrackingService() async {
  try {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  } catch (e) {
    debugPrint('[bgLive] stop failed: $e');
  }
}

/// Point d'entrée de l'isolate de fond (Android + iOS foreground).
@pragma('vm:entry-point')
void onLiveBgStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  try {
    await GetStorage.init();
  } catch (_) {}

  service.on('stopService').listen((event) async {
    try {
      await _postOffline();
    } catch (_) {}
    try {
      await service.stopSelf();
    } catch (_) {}
  });

  if (service is AndroidServiceInstance) {
    try {
      await service.setAsForegroundService();
    } catch (_) {}
    try {
      await service.setForegroundNotificationInfo(
        title: bgLiveText('title'),
        content: bgLiveText('body'),
      );
    } catch (_) {}
  }

  Timer.periodic(const Duration(seconds: 15), (timer) async {
    try {
      GetStorage box;
      try {
        box = GetStorage();
      } catch (_) {
        await GetStorage.init();
        box = GetStorage();
      }
      final active = box.read(kBgLiveActive) == true;
      if (!active) {
        timer.cancel();
        try {
          await service.stopSelf();
        } catch (_) {}
        return;
      }
      final pos = await _readPosition();
      if (pos == null) return;
      await _postPosition(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('[bgLive] tick error: $e');
    }
  });
}

/// iOS background fetch (ponctuel, ~15-30 s max imposé par Apple).
@pragma('vm:entry-point')
Future<bool> onLiveIosBg(ServiceInstance service) async {
  try {
    await GetStorage.init();
    final box = GetStorage();
    if (box.read(kBgLiveActive) != true) return true;
    final pos = await _readPosition();
    if (pos != null) await _postPosition(pos.latitude, pos.longitude);
  } catch (_) {}
  return true;
}

Future<Position?> _readPosition() async {
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
  } catch (_) {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}

Future<void> _postPosition(double lat, double lng) async {
  final box = GetStorage();
  final token = (box.read(kBgToken) ?? '').toString();
  final base = (box.read(kBgBaseUrl) ?? '').toString();
  final city = (box.read(kBgCity) ?? '').toString();
  if (token.isEmpty || base.isEmpty) return;
  try {
    await http
        .post(
          Uri.parse('$base/friends/live-position'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'lat': lat,
            'lng': lng,
            if (city.isNotEmpty) 'city': city,
          }),
        )
        .timeout(const Duration(seconds: 12));
  } catch (e) {
    debugPrint('[bgLive] post failed: $e');
  }
}

Future<void> _postOffline() async {
  final box = GetStorage();
  final token = (box.read(kBgToken) ?? '').toString();
  final base = (box.read(kBgBaseUrl) ?? '').toString();
  if (token.isEmpty || base.isEmpty) return;
  try {
    await http
        .post(
          Uri.parse('$base/friends/live-position'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'offline': true}),
        )
        .timeout(const Duration(seconds: 8));
  } catch (_) {}
}
