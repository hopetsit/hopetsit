import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
// v23.1.294 — AndroidSettings.foregroundNotificationConfig pour garder le GPS
// vivant en arrière-plan (foreground service + notif persistante). Les
// permissions FOREGROUND_SERVICE(_LOCATION) + ACCESS_BACKGROUND_LOCATION sont
// déjà dans AndroidManifest.xml.
import 'package:geolocator_android/geolocator_android.dart' as gloc_android;
import 'package:geolocator_apple/geolocator_apple.dart' as gloc_apple;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_config.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';
import 'package:hopetsit/services/live_tracking_bg.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/services/socket_service.dart';
import 'package:hopetsit/utils/storage_keys.dart';

/// Single friend's live position — used to drive the PawMap "friends layer".
class FriendPosition {
  final String userId;
  final String role;
  final double latitude;
  final double longitude;
  final DateTime at;
  final String city;
  // v565 — contrat §8 : le serveur garde la DERNIÈRE position 24 h et
  // renvoie `lastSeenAt` + `stale` (true si > 3 min). On les garde pour
  // afficher « actif / signal perdu · vu il y a X » chez les amis.
  final DateTime? lastSeenAt;
  final bool stale;

  const FriendPosition({
    required this.userId,
    required this.role,
    required this.latitude,
    required this.longitude,
    required this.at,
    this.city = '',
    this.lastSeenAt,
    this.stale = false,
  });

  factory FriendPosition.fromJson(Map<String, dynamic> j) {
    final at = DateTime.tryParse(j['at']?.toString() ?? '') ?? DateTime.now();
    return FriendPosition(
      userId: j['userId']?.toString() ?? '',
      role: (j['role'] as String?) ?? '',
      latitude: ((j['lat'] as num?) ?? 0).toDouble(),
      longitude: ((j['lng'] as num?) ?? 0).toDouble(),
      at: at,
      city: (j['city'] as String?) ?? '',
      lastSeenAt: DateTime.tryParse(j['lastSeenAt']?.toString() ?? '') ?? at,
      stale: j['stale'] == true,
    );
  }

  /// v565 — dernier signe de vie connu (position ou battement).
  DateTime get seenAt => lastSeenAt ?? at;

  /// v565 — « signal perdu » : le serveur le dit (`stale`) OU aucun signe de
  /// vie depuis plus de 3 min (même seuil que le serveur, calculé en local
  /// pour rester juste entre deux rafraîchissements).
  bool get isStale =>
      stale || DateTime.now().difference(seenAt) > const Duration(minutes: 3);

  FriendPosition copyWith({
    double? latitude,
    double? longitude,
    DateTime? at,
    String? city,
    DateTime? lastSeenAt,
    bool? stale,
  }) =>
      FriendPosition(
        userId: userId,
        role: role,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        at: at ?? this.at,
        city: city ?? this.city,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        stale: stale ?? this.stale,
      );
}

/// v565 — durées de partage proposées au démarrage (contrat §8).
/// Défaut : jusqu'à l'arrêt manuel.
enum LiveShareDuration { oneHour, fourHours, untilStop }

extension LiveShareDurationApi on LiveShareDuration {
  /// Valeur envoyée au serveur (`duration` de POST /friends/live-position).
  String get apiValue {
    switch (this) {
      case LiveShareDuration.oneHour:
        return '1h';
      case LiveShareDuration.fourHours:
        return '4h';
      case LiveShareDuration.untilStop:
        return 'until_stop';
    }
  }

  Duration? get length {
    switch (this) {
      case LiveShareDuration.oneHour:
        return const Duration(hours: 1);
      case LiveShareDuration.fourHours:
        return const Duration(hours: 4);
      case LiveShareDuration.untilStop:
        return null;
    }
  }

  static LiveShareDuration fromApi(String? v) {
    switch (v) {
      case '1h':
        return LiveShareDuration.oneHour;
      case '4h':
        return LiveShareDuration.fourHours;
      default:
        return LiveShareDuration.untilStop;
    }
  }
}

/// v565 — état RÉEL de mon partage, affiché dans le bandeau PawMap.
///   off    : je ne partage pas
///   active : positions livrées (socket vivante, ou battement HTTP passé)
///   lost   : socket coupée ET dernier battement HTTP en échec (ou GPS muet)
enum LiveShareStatus { off, active, lost }

/// Bridges the socket layer with the PawMap UI:
///   - Emits `map:identify` after connection so backend knows who we are.
///   - Emits `map:position-update` when we want to broadcast our location.
///   - Listens to `map:friend-position` / `map:friend-offline` and keeps a
///     reactive map of `userId → FriendPosition` that the UI can observe.
///
/// This service is a GetX service so we can inject it once at app boot and
/// have the subscription outlive individual screens.
class LiveMapService extends GetxService {
  LiveMapService({GetStorage? storage}) : _storage = storage ?? GetStorage();

  final GetStorage _storage;

  /// userId → latest FriendPosition from the socket
  final RxMap<String, FriendPosition> friendPositions =
      <String, FriendPosition>{}.obs;

  /// Has the user agreed to broadcast their position at all.
  final RxBool broadcasting = false.obs;

  Timer? _broadcastTicker;
  // v23.1 part 238 — Daniel : "suivre famille sa me donne pas la bonne
  // position". v237 fix utilisait _userPosition mais NE LE RAFRAICHIT
  // PAS pendant le broadcast (le user bouge, la position emise reste
  // l'initiale). FIX : on s'abonne au stream Geolocator continu pendant
  // le broadcast. Chaque mise a jour GPS = nouveau dernier-known stocke,
  // utilise par le ticker 10s + le _emitPosition immediate.
  StreamSubscription<Position>? _gpsSub;
  LatLng? _lastKnownGps;
  bool _hookRegistered = false;

  // v23.1.294 — position GPS live de l'utilisateur, observée par la PawMap pour
  // faire suivre la caméra "à la trace" quand « Me suivre » est actif.
  final Rxn<LatLng> myLivePosition = Rxn<LatLng>();
  // v565 — Daniel (14/09) : « le partage s'arrête tout seul en < 2 h, j'ai
  // rien touché ». Les anciennes causes d'arrêt automatique (cap de session
  // 2 h, session gratuite 30 min, immobilité 30 min) sont SUPPRIMÉES : le
  // partage ne s'arrête plus QUE sur action de l'utilisateur ou à la fin de
  // la durée qu'il a choisie (1 h / 4 h / jusqu'à l'arrêt — contrat §8).
  /// Durée choisie au démarrage de la session.
  final Rx<LiveShareDuration> sessionDuration =
      LiveShareDuration.untilStop.obs;
  /// Échéance de la session (null = jusqu'à l'arrêt manuel).
  final Rxn<DateTime> sessionEndsAt = Rxn<DateTime>();
  /// État réel de mon partage (actif / signal perdu).
  final Rx<LiveShareStatus> liveStatus = LiveShareStatus.off.obs;
  /// Compteur bumpé toutes les 30 s : les Obx qui affichent « vu il y a X »
  /// ou l'état « signal perdu » des amis se rafraîchissent sans nouvel event.
  final RxInt staleTick = 0.obs;
  Timer? _durationTimer;
  Timer? _staleTicker;
  Timer? _refreshTimer;
  Timer? _gpsRetryTimer;
  String? _city;
  DateTime? _lastGpsAt;
  DateTime? _lastHttpAt;
  bool _lastHttpOk = true;
  bool _gpsDegraded = false;
  /// Battement HTTP quand la socket est coupée (contrat §8 : toutes les 60 s).
  static const Duration _httpHeartbeatEvery = Duration(seconds: 60);
  /// Rafraîchissement des positions amis (stale / lastSeenAt) par HTTP.
  static const Duration _refreshEvery = Duration(minutes: 2);

  /// v23.1 part 240 — Daniel (3eme tentative) : "personne en live sa marche
  /// toujour pas sa me donne ma geolocalisation au lieu de la geolocalisation
  /// reel de la personne corrige sa sa fais deja 3 fois que je tele dis,
  /// donc le bouton me suivre marcha pas car jai fais les test et apres qd
  /// la personne met voir en live sa lui donne sa geolocalisation au lieu de
  /// la mienne". ROOT CAUSE trouvee : attach() etait UNIQUEMENT appele dans
  /// paw_map_screen.dart. Si user ne visite jamais PawMap → map:identify
  /// jamais emis → backend rejette map:position-update (cf mapSocket.js
  /// L122 `if (!identity) return;`) → broadcast silencieusement no-op.
  ///
  /// FIX : on enregistre attach() en hook onConnected du SocketService.
  /// Comme ca des que la socket connect (boot, reconnect background→fg,
  /// network hiccup), on emet map:identify automatiquement. Idempotent
  /// grace aux .off() avant .on() dans attach().
  @override
  void onInit() {
    super.onInit();
    try {
      final svc = Get.find<SocketService>();
      if (!_hookRegistered) {
        _hookRegistered = true;
        svc.addOnConnectedHook(attach);
        // v23.1.300 — Daniel : "quand je me déco/reco, ça ne se réajoute pas
        // automatiquement". À chaque (re)connexion socket, si je partage ma
        // position, je la ré-émets IMMÉDIATEMENT (sans attendre le ticker 10s)
        // → je réapparais tout de suite chez mes amis/famille. attach() (hook
        // précédent, même liste, ordre garanti) a déjà ré-émis map:identify.
        svc.addOnConnectedHook(() {
          if (!broadcasting.value) return;
          final pos = _lastKnownGps;
          if (pos != null) _emitPosition(pos);
        });
      }
      // Si la socket est deja connectee, addOnConnectedHook fire le
      // callback immediatement (cf SocketService.addOnConnectedHook).
      // Sinon, tentative defensive d'attach maintenant (no-op si pas
      // de socket — attach() return early).
      if (svc.isConnected) {
        attach();
      }
    } catch (e) {
      debugPrint('[LiveMap] onInit hook failed: $e');
    }
    // v565 — « vu il y a X » et « signal perdu » se recalculent toutes les
    // 30 s même sans nouvel event socket.
    _staleTicker?.cancel();
    _staleTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      staleTick.value++;
    });
    // v565 — session persistée (app relancée après un swipe-kill ou un
    // redémarrage) : on reprend le partage au lieu d'afficher « OFF » alors
    // que le service de fond diffuse encore (cf. bug v532).
    unawaited(_resumePersistedSession());
  }

  /// v565 — reprend une session de partage persistée dans GetStorage si elle
  /// n'est pas échue. Best-effort : sans dernière position GPS connue, on
  /// attend le premier fix du flux (le ticker n'émet rien tant qu'il n'y a
  /// pas de position).
  Future<void> _resumePersistedSession() async {
    try {
      if (broadcasting.value) return;
      if (_storage.read(kBgLiveActive) != true) return;
      final until = (_storage.read(kBgUntil) as num?)?.toInt() ?? 0;
      if (until > 0 && DateTime.now().millisecondsSinceEpoch >= until) {
        // Échue pendant que l'app était fermée : on nettoie proprement.
        stopBroadcasting();
        return;
      }
      LatLng? last;
      try {
        final p = await Geolocator.getLastKnownPosition();
        if (p != null) last = LatLng(p.latitude, p.longitude);
      } catch (_) {/* pas de dernière position */}
      final duration = LiveShareDurationApi.fromApi(
          (_storage.read(kBgDuration) ?? '').toString());
      final city = (_storage.read(kBgCity) ?? '').toString();
      startBroadcasting(
        () => last ?? const LatLng(0, 0),
        city: city.isEmpty ? null : city,
        duration: duration,
        endsAt: until > 0 ? DateTime.fromMillisecondsSinceEpoch(until) : null,
      );
      debugPrint('[LiveMap] session persistée reprise (${duration.apiValue})');
    } catch (e) {
      debugPrint('[LiveMap] resume persisted session failed: $e');
    }
  }

  /// v565 — temps restant de la session (null = jusqu'à l'arrêt).
  Duration? get remaining {
    final end = sessionEndsAt.value;
    if (end == null) return null;
    final d = end.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  /// Register socket listeners — idempotent.
  void attach() {
    final svc = Get.find<SocketService>();
    final socket = svc.socket;
    if (socket == null) {
      debugPrint('[LiveMap] socket not ready yet');
      return;
    }

    // Identify on the map channel (separate from chat identify).
    final role = _storage.read<String>(StorageKeys.userRole);
    final profile = _storage.read<Map<String, dynamic>>(StorageKeys.userProfile);
    final userId = profile?['id']?.toString();
    if (role != null && userId != null) {
      socket.emit('map:identify', {'role': role, 'userId': userId});
    }

    // v23.1.351 — Daniel : "à la 1re connexion sur la PawMap, tous les amis/
    // famille doivent apparaître". Avant : friendPositions n'était rempli QUE
    // par les events live map:friend-position → carte vide d'amis tant que
    // LEUR téléphone n'émettait pas. On hydrate maintenant avec la dernière
    // position connue (<24h, mêmes règles d'accès que le live) en un appel.
    _hydrateLastKnownPositions();

    socket.off('map:friend-position');
    socket.on('map:friend-position', (raw) {
      try {
        final map = (raw as Map).cast<String, dynamic>();
        final fp = FriendPosition.fromJson(map);
        // v565 — une position live = signe de vie frais : jamais « stale ».
        friendPositions[fp.userId] =
            fp.copyWith(stale: false, lastSeenAt: fp.at);
      } catch (e) {
        debugPrint('[LiveMap] friend-position parse error: $e');
      }
    });

    socket.off('map:friend-offline');
    socket.on('map:friend-offline', (raw) {
      try {
        final map = (raw as Map).cast<String, dynamic>();
        final uid = map['userId']?.toString();
        if (uid != null) friendPositions.remove(uid);
      } catch (_) {}
    });

    // v565 — contrat §8 : à l'échéance de la durée choisie, le serveur
    // prévient le DIFFUSEUR (`map:live-session-ended`) : on coupe localement
    // (sans ré-émettre go-offline : le serveur a déjà tout fermé).
    socket.off('map:live-session-ended');
    socket.on('map:live-session-ended', (_) {
      if (!broadcasting.value) return;
      _durationTimer?.cancel();
      _durationTimer = null;
      final wasEnd = sessionEndsAt.value != null;
      stopBroadcasting();
      if (wasEnd) {
        CustomSnackbar.showInfo(
          title: 'v565_live_ended_title'.tr,
          message: 'v565_live_ended_msg'.tr,
        );
      }
    });

    // v565 — contrat §6 : présence « en ligne » en temps réel. On retire
    // UNIQUEMENT notre propre handler (d'autres écrans écoutent le même
    // event) avant de le remettre → idempotent à chaque reconnexion.
    socket.off('presence:update', _onPresenceUpdate);
    socket.on('presence:update', _onPresenceUpdate);
  }

  /// v565 — contrat §6 : `userId → en ligne ?` alimenté par `presence:update`.
  /// La PawMap (fiche membre, marqueurs) lit ici en priorité sur le champ
  /// `isOnline` figé renvoyé au chargement.
  final RxMap<String, bool> presence = <String, bool>{}.obs;

  void _onPresenceUpdate(dynamic raw) {
    try {
      final map = (raw as Map).cast<String, dynamic>();
      final uid = map['userId']?.toString();
      if (uid == null || uid.isEmpty) return;
      presence[uid] = map['online'] == true;
    } catch (_) {/* payload inattendu */}
  }

  /// v565 — en ligne ? (null = inconnu → l'appelant garde sa valeur chargée).
  bool? isOnline(String userId) => presence[userId];

  // v23.1.351 — garde anti-spam : 1 hydratation par session (attach() est
  // ré-appelé à chaque reconnexion socket ; le live prend le relais ensuite).
  bool _hydratedOnce = false;

  /// Hydrate `friendPositions` avec la DERNIÈRE position connue (<24h) de
  /// chaque ami/famille traçable — GET /friends/live-positions (mêmes règles
  /// d'accès que le live : opt-out > famille > PawFollow > partage). On
  /// n'écrase JAMAIS une position live déjà reçue (plus fraîche par nature).
  Future<void> _hydrateLastKnownPositions() async {
    if (_hydratedOnce) return;
    _hydratedOnce = true;
    final ok = await refreshFriendPositions();
    if (!ok) _hydratedOnce = false; // retentera à la prochaine (re)connexion
    // v565 — puis rafraîchissement périodique : `stale` / `lastSeenAt` restent
    // justes même si la socket ne livre plus rien (signal perdu côté ami).
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshEvery, (_) {
      unawaited(refreshFriendPositions());
    });
  }

  /// v565 — GET /friends/live-positions : fusionne `stale` + `lastSeenAt`
  /// dans les positions connues, sans jamais reculer une position plus
  /// fraîche reçue par la socket. Renvoie false en cas d'échec réseau.
  Future<bool> refreshFriendPositions() async {
    try {
      if (!Get.isRegistered<ApiClient>()) return false;
      final r = await Get.find<ApiClient>()
          .get('/friends/live-positions', requiresAuth: true);
      final list = (r is Map && r['positions'] is List)
          ? r['positions'] as List
          : const [];
      for (final item in list) {
        if (item is! Map) continue;
        final fp = FriendPosition.fromJson(item.cast<String, dynamic>());
        if (fp.userId.isEmpty) continue;
        final cur = friendPositions[fp.userId];
        if (cur == null) {
          friendPositions[fp.userId] = fp;
        } else if (!fp.at.isBefore(cur.at)) {
          friendPositions[fp.userId] = fp; // serveur au moins aussi frais
        } else {
          // live plus frais : on ne garde du serveur que l'état de session.
          friendPositions[fp.userId] = cur.copyWith(
            stale: fp.stale && cur.isStale,
            lastSeenAt: fp.seenAt.isAfter(cur.seenAt) ? fp.seenAt : cur.seenAt,
          );
        }
      }
      debugPrint('[LiveMap] refreshed ${list.length} friend position(s)');
      return true;
    } catch (e) {
      debugPrint('[LiveMap] refresh friend positions failed: $e');
      return false;
    }
  }

  /// Start broadcasting my position to friends. Call [stopBroadcasting] when
  /// the user toggles sharing off.
  ///
  /// v565 — contrat §8. La session dure [duration] (1 h / 4 h / jusqu'à
  /// l'arrêt, défaut jusqu'à l'arrêt) ; [endsAt] sert à REPRENDRE une session
  /// persistée sans repartir de zéro. Plus aucun cap de session ni d'arrêt
  /// sur immobilité : `map:go-offline` ne part QUE sur action de
  /// l'utilisateur ou à l'échéance choisie.
  ///
  /// `latestPosition` est conservé en fallback si le flux GPS n'a pas encore
  /// livré sa première position (cold start du LocationManager) ; (0,0) est
  /// ignoré (jamais envoyé).
  void startBroadcasting(
    LatLng Function() latestPosition, {
    String? city,
    LiveShareDuration duration = LiveShareDuration.untilStop,
    DateTime? endsAt,
  }) {
    if (broadcasting.value) return;
    broadcasting.value = true;
    liveStatus.value = LiveShareStatus.active;
    _city = city;
    sessionDuration.value = duration;
    final len = duration.length;
    sessionEndsAt.value = endsAt ?? (len == null ? null : DateTime.now().add(len));

    // v416 — Daniel : "le direct doit rester allumé même app fermée de force".
    // On arme le SERVICE DE FOND (isolate séparé, survit au swipe-kill sur
    // Android) : on lui dépose le token + l'URL + la ville + la durée dans
    // GetStorage (il n'a pas accès au secure storage), puis on le démarre.
    // v565 — pour TOUT le monde (plus de session « gratuite » qui meurt avec
    // l'app) : c'est la robustesse demandée au point 23. Best-effort : si ça
    // échoue, le flux socket + le battement HTTP en avant-plan continuent.
    try {
      final token = SecureTokenStore.instance.tokenSync ??
          SecureTokenStore.currentToken();
      _storage.write(kBgLiveActive, true);
      _storage.write(kBgToken, token ?? '');
      _storage.write(kBgBaseUrl, ApiConfig.baseUrl);
      _storage.write(kBgCity, city ?? '');
      _storage.write(kBgDuration, duration.apiValue);
      _storage.write(
          kBgUntil, sessionEndsAt.value?.millisecondsSinceEpoch ?? 0);
      if (defaultTargetPlatform == TargetPlatform.android) {
        startLiveTrackingService();
      }
    } catch (e) {
      debugPrint('[LiveMap] background service start failed: $e');
    }

    // Init last known from the closure (typically _userPosition fresh).
    final initial = latestPosition();
    final hasInitial = !(initial.latitude == 0 && initial.longitude == 0);
    _lastKnownGps = hasInitial ? initial : null;
    myLivePosition.value = hasInitial ? initial : null;

    _startGpsStream();

    // Emit once immediately (si on a une position), puis toutes les 10 s.
    if (hasInitial) _emitPosition(initial, city: city);
    _broadcastTicker?.cancel();
    _broadcastTicker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!broadcasting.value) return;
      final fromClosure = latestPosition();
      final pos = _lastKnownGps ??
          ((fromClosure.latitude == 0 && fromClosure.longitude == 0)
              ? null
              : fromClosure);
      _tick(pos);
    });

    // v565 — fin de la durée choisie : la SEULE fin automatique.
    _durationTimer?.cancel();
    final end = sessionEndsAt.value;
    if (end != null) {
      final wait = end.difference(DateTime.now());
      _durationTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
        if (!broadcasting.value) return;
        stopBroadcasting();
        CustomSnackbar.showInfo(
          title: 'v565_live_ended_title'.tr,
          message: 'v565_live_ended_msg'.tr,
        );
      });
    }
  }

  /// v565 — flux GPS. iOS : `allowsBackgroundLocationUpdates` (barre bleue),
  /// et si le flux tombe en erreur on repart en mode DÉGRADÉ (précision
  /// réduite, filtre 100 m ≈ « changements significatifs ») qui consomme
  /// moins et survit mieux à la mise en veille ; on retente la haute
  /// précision 5 min plus tard. Android : service de premier plan
  /// (notification persistante) via foregroundNotificationConfig.
  void _startGpsStream() {
    _gpsSub?.cancel();
    _gpsRetryTimer?.cancel();
    try {
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: _buildLocationSettings(degraded: _gpsDegraded),
      ).listen((pos) {
        final p = LatLng(pos.latitude, pos.longitude);
        _lastKnownGps = p;
        _lastGpsAt = DateTime.now();
        myLivePosition.value = p; // la PawMap suit la caméra « à la trace »
      }, onError: (e) {
        debugPrint('[LiveMap] GPS stream error: $e');
        _scheduleGpsRestart(degraded: true);
      }, onDone: () {
        if (broadcasting.value) _scheduleGpsRestart(degraded: _gpsDegraded);
      });
      if (_gpsDegraded) {
        // Retour à la haute précision après 5 min de mode dégradé.
        _gpsRetryTimer = Timer(const Duration(minutes: 5), () {
          if (!broadcasting.value) return;
          _gpsDegraded = false;
          _startGpsStream();
        });
      }
    } catch (e) {
      debugPrint('[LiveMap] failed to start GPS stream: $e');
      _scheduleGpsRestart(degraded: true);
    }
  }

  void _scheduleGpsRestart({required bool degraded}) {
    if (!broadcasting.value) return;
    _gpsDegraded = degraded;
    _gpsRetryTimer?.cancel();
    _gpsRetryTimer = Timer(const Duration(seconds: 5), () {
      if (broadcasting.value) _startGpsStream();
    });
  }

  /// v565 — un tick (10 s) : socket vivante → émission socket ; socket
  /// coupée → reconnexion automatique + battement HTTP toutes les 60 s
  /// (position si on en a une, sinon simple `heartbeat`). L'état affiché
  /// (`liveStatus`) reflète ce qui est RÉELLEMENT passé.
  void _tick(LatLng? pos) {
    final svc = Get.find<SocketService>();
    if (svc.isConnected && svc.socket != null) {
      if (pos != null) _emitPosition(pos, city: _city);
      _setStatus(_gpsSilent ? LiveShareStatus.lost : LiveShareStatus.active);
      return;
    }
    // Socket coupée : on la relance et on passe par HTTP.
    unawaited(svc.reconnectIfNeeded());
    final last = _lastHttpAt;
    if (last == null ||
        DateTime.now().difference(last) >= _httpHeartbeatEvery) {
      unawaited(_postHttp(pos));
    } else {
      _setStatus(_lastHttpOk && !_gpsSilent
          ? LiveShareStatus.active
          : LiveShareStatus.lost);
    }
  }

  /// GPS muet depuis plus de 3 min alors qu'on diffuse.
  bool get _gpsSilent {
    final at = _lastGpsAt;
    if (at == null) return false; // pas encore de fix : pas un « perdu »
    return DateTime.now().difference(at) > const Duration(minutes: 3);
  }

  void _setStatus(LiveShareStatus s) {
    if (!broadcasting.value) return;
    if (liveStatus.value != s) liveStatus.value = s;
  }

  /// v565 — POST /friends/live-position (contrat §8) : position + `duration`,
  /// ou `heartbeat: true` seul quand on n'a pas de position.
  Future<void> _postHttp(LatLng? pos) async {
    _lastHttpAt = DateTime.now();
    try {
      if (!Get.isRegistered<ApiClient>()) throw StateError('no api');
      await Get.find<ApiClient>().post(
        '/friends/live-position',
        body: {
          if (pos != null) 'lat': pos.latitude,
          if (pos != null) 'lng': pos.longitude,
          if (pos == null) 'heartbeat': true,
          if ((_city ?? '').isNotEmpty) 'city': _city,
          'duration': sessionDuration.value.apiValue,
        },
        requiresAuth: true,
      );
      _lastHttpOk = true;
      _setStatus(_gpsSilent ? LiveShareStatus.lost : LiveShareStatus.active);
    } catch (e) {
      _lastHttpOk = false;
      _setStatus(LiveShareStatus.lost);
      debugPrint('[LiveMap] HTTP heartbeat failed: $e');
    }
  }

  /// v23.1.294 — réglages GPS. Sur Android on attache un foreground service
  /// (notif persistante) pour que le partage survive en arrière-plan.
  LocationSettings _buildLocationSettings({bool degraded = false}) {
    final accuracy = degraded ? LocationAccuracy.low : LocationAccuracy.high;
    final int filter = degraded ? 100 : 5;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return gloc_android.AndroidSettings(
        accuracy: accuracy,
        distanceFilter: filter,
        foregroundNotificationConfig: gloc_android.ForegroundNotificationConfig(
          notificationTitle: 'live_share_notif_title'.tr,
          notificationText: 'live_share_notif_text'.tr,
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    // v414 — Daniel : "le direct s'éteint quand l'app se ferme". Sur iOS,
    // AppleSettings.allowBackgroundLocationUpdates garde le GPS vivant en
    // arrière-plan (UIBackgroundModes>location est déjà dans Info.plist) et
    // showBackgroundLocationIndicator affiche la barre bleue obligatoire.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return gloc_apple.AppleSettings(
        accuracy: accuracy,
        distanceFilter: filter,
        activityType: ActivityType.fitness,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return LocationSettings(accuracy: accuracy, distanceFilter: filter);
  }

  /// Arrêt du partage — UNIQUEMENT sur action de l'utilisateur ou fin de la
  /// durée choisie (contrat §8). Coupe tout : flux GPS, tickers, service de
  /// fond, état persisté, et émet `map:go-offline`.
  void stopBroadcasting() {
    _broadcastTicker?.cancel();
    _broadcastTicker = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    _gpsRetryTimer?.cancel();
    _gpsRetryTimer = null;
    _gpsSub?.cancel();
    _gpsSub = null;
    _lastKnownGps = null;
    _lastGpsAt = null;
    _lastHttpAt = null;
    _gpsDegraded = false;
    myLivePosition.value = null;
    sessionEndsAt.value = null;
    liveStatus.value = LiveShareStatus.off;
    // v532 — CE `return` RENDAIT L'ARRÊT IMPOSSIBLE APRÈS UN SWIPE-KILL.
    // `broadcasting` ne vit qu'en mémoire, alors que le service de fond, lui,
    // survit à la fermeture de l'app (START_STICKY). On coupe donc TOUJOURS
    // l'état persisté et le service de fond, même si l'app se croit déjà à
    // l'arrêt.
    final wasBroadcasting = broadcasting.value;
    broadcasting.value = false;
    if (wasBroadcasting) {
      final svc = Get.find<SocketService>();
      final socket = svc.socket;
      if (socket != null && svc.isConnected) {
        socket.emit('map:go-offline');
      } else {
        // Socket coupée : le serveur est prévenu par HTTP (offline:true).
        unawaited(_postOfflineHttp());
      }
    }
    // v416 — coupe aussi le service de fond (il enverra un ping offline final).
    try {
      _storage.write(kBgLiveActive, false);
      _storage.write(kBgToken, '');
      _storage.write(kBgUntil, 0);
      stopLiveTrackingService();
    } catch (e) {
      debugPrint('[LiveMap] background service stop failed: $e');
    }
  }

  Future<void> _postOfflineHttp() async {
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      await Get.find<ApiClient>().post(
        '/friends/live-position',
        body: {'offline': true},
        requiresAuth: true,
      );
    } catch (e) {
      debugPrint('[LiveMap] offline HTTP failed: $e');
    }
  }

  void _emitPosition(LatLng pos, {String? city}) {
    final svc = Get.find<SocketService>();
    final socket = svc.socket;
    if (socket == null) return;
    socket.emit('map:position-update', {
      'lat': pos.latitude,
      'lng': pos.longitude,
      if (city != null) 'city': city,
      // v565 — contrat §8 : durée choisie (le serveur l'ignore s'il ne la
      // lit pas sur la socket ; elle fait foi via HTTP).
      'duration': sessionDuration.value.apiValue,
    });
  }

  @override
  void onClose() {
    _staleTicker?.cancel();
    _refreshTimer?.cancel();
    stopBroadcasting();
    super.onClose();
  }
}
