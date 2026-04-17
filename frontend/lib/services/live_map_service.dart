import 'dart:async';

import 'package:flutter/foundation.dart';
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
  void startBroadcasting(LatLng Function() latestPosition, {String? city}) {
    if (broadcasting.value) return;
    broadcasting.value = true;

    // Emit once immediately.
    _emitPosition(latestPosition(), city: city);
    // Then every 10s while broadcasting.
    _broadcastTicker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!broadcasting.value) return;
      final pos = latestPosition();
      _emitPosition(pos, city: city);
    });
  }

  void stopBroadcasting() {
    _broadcastTicker?.cancel();
    _broadcastTicker = null;
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
