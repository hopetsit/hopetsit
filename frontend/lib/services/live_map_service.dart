import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  const FriendPosition({
    required this.userId,
    required this.role,
    required this.latitude,
    required this.longitude,
    required this.at,
    this.city = '',
  });

  factory FriendPosition.fromJson(Map<String, dynamic> j) {
    return FriendPosition(
      userId: j['userId']?.toString() ?? '',
      role: (j['role'] as String?) ?? '',
      latitude: ((j['lat'] as num?) ?? 0).toDouble(),
      longitude: ((j['lng'] as num?) ?? 0).toDouble(),
      at: DateTime.tryParse(j['at']?.toString() ?? '') ?? DateTime.now(),
      city: (j['city'] as String?) ?? '',
    );
  }
}

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

    socket.off('map:friend-position');
    socket.on('map:friend-position', (raw) {
      try {
        final map = (raw as Map).cast<String, dynamic>();
        final fp = FriendPosition.fromJson(map);
        friendPositions[fp.userId] = fp;
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
  }

  /// Start broadcasting my position to friends. Call [stopBroadcasting] when
  /// the user leaves the map or toggles sharing off.
  ///
  /// v23.1 part 238 — Daniel : "suivre famille sa me donne pas la bonne
  /// position". On ne se base plus sur la closure `latestPosition`
  /// (qui pouvait pointer sur le map center, pas le GPS reel). A la
  /// place, on s'abonne au stream Geolocator continu qui pousse une
  /// nouvelle position des que l'OS detecte un deplacement de >5m.
  /// Le ticker 10s lit cette derniere position GPS connue → le broadcast
  /// suit en TEMPS REEL les deplacements de l'user, meme s'il bouge
  /// rapidement entre 2 ticks.
  ///
  /// `latestPosition` est conserve en fallback si le stream GPS n'a pas
  /// encore livre sa premiere position (cold start du LocationManager).
  void startBroadcasting(LatLng Function() latestPosition, {String? city}) {
    if (broadcasting.value) return;
    broadcasting.value = true;

    // Init last known from the closure (typically _userPosition fresh).
    final initial = latestPosition();
    _lastKnownGps = initial;

    // Subscribe to Geolocator stream — pushes every 5m of movement.
    _gpsSub?.cancel();
    try {
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // notify every 5m moved
        ),
      ).listen((pos) {
        _lastKnownGps = LatLng(pos.latitude, pos.longitude);
      }, onError: (e) {
        debugPrint('[LiveMap] GPS stream error: $e');
      });
    } catch (e) {
      debugPrint('[LiveMap] failed to start GPS stream: $e');
    }

    // Emit once immediately.
    _emitPosition(initial, city: city);
    // Then every 10s while broadcasting, using the latest GPS we know of.
    _broadcastTicker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!broadcasting.value) return;
      final pos = _lastKnownGps ?? latestPosition();
      _emitPosition(pos, city: city);
    });
  }

  void stopBroadcasting() {
    _broadcastTicker?.cancel();
    _broadcastTicker = null;
    _gpsSub?.cancel();
    _gpsSub = null;
    _lastKnownGps = null;
    if (!broadcasting.value) return;
    broadcasting.value = false;
    final svc = Get.find<SocketService>();
    svc.socket?.emit('map:go-offline');
  }

  void _emitPosition(LatLng pos, {String? city}) {
    final svc = Get.find<SocketService>();
    final socket = svc.socket;
    if (socket == null) return;
    socket.emit('map:position-update', {
      'lat': pos.latitude,
      'lng': pos.longitude,
      if (city != null) 'city': city,
    });
  }

  @override
  void onClose() {
    stopBroadcasting();
    super.onClose();
  }
}
