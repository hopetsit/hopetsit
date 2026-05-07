import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Sprint 6 step 2 — sitter live walk tracking screen.
class WalkTrackingScreen extends StatefulWidget {
  final String bookingId;
  const WalkTrackingScreen({super.key, required this.bookingId});

  @override
  State<WalkTrackingScreen> createState() => _WalkTrackingScreenState();
}

class _WalkTrackingScreenState extends State<WalkTrackingScreen> {
  final ApiClient _api = Get.isRegistered<ApiClient>()
      ? Get.find<ApiClient>()
      : ApiClient();
  String? _walkId;
  // v23.1 part 106 — replace Timer.periodic with realtime position stream.
  // Geolocator.getPositionStream emits each time the device moves more
  // than `distanceFilter` meters, with `accuracy` controlling the GPS
  // fix quality. Battery-efficient (no spin when stationary) and gives
  // owner-side updates as soon as the sitter actually moves.
  StreamSubscription<Position>? _positionSub;
  int _pushed = 0;
  bool _busy = false;

  Future<bool> _ensurePermission() async {
    final status = await Permission.locationAlways.request();
    if (status.isGranted) return true;
    final wi = await Permission.locationWhenInUse.request();
    return wi.isGranted;
  }

  Future<void> _start() async {
    if (!await _ensurePermission()) {
      CustomSnackbar.showError(
        title: 'common_error',
        message: 'live_track_perm_denied'.tr.isEmpty
            ? 'Permission de localisation refusée.'
            : 'live_track_perm_denied'.tr,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await _api.post(
        ApiEndpoints.walksStart,
        body: {'bookingId': widget.bookingId},
        requiresAuth: true,
      );
      final walk = r is Map ? r['walk'] : null;
      if (walk is Map) {
        _walkId = (walk['_id'] ?? walk['id']).toString();
        _startStreamingPositions();
      }
    } catch (e) {
      CustomSnackbar.showError(title: 'common_error', message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startStreamingPositions() {
    _positionSub?.cancel();
    // distanceFilter = 10m → on émet une position à chaque déplacement
    // d'au moins 10 mètres. accuracy = high pour précision GPS suffisante
    // (~5m). Le owner reçoit les updates via le socket walk.position que
    // le backend émet à la réception du POST /walks/:id/position.
    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
    _positionSub = stream.listen(_onPosition, onError: (_) {});
    // Push une 1re fois immédiatement même sans mouvement (pour que le
    // owner voie le sitter sur la map dès que la balade commence).
    _pushCurrentPositionOnce();
  }

  Future<void> _pushCurrentPositionOnce() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _onPosition(pos);
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _onPosition(Position pos) async {
    if (_walkId == null) return;
    try {
      await _api.post(
        '${ApiEndpoints.walksPosition}/$_walkId/position',
        body: {'lat': pos.latitude, 'lng': pos.longitude},
        requiresAuth: true,
      );
      if (mounted) setState(() => _pushed++);
    } catch (_) {
      // best-effort; ignore individual failures
    }
  }

  Future<void> _stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    if (_walkId == null) return;
    setState(() => _busy = true);
    try {
      await _api.post(
        '${ApiEndpoints.walksEnd}/$_walkId/end',
        body: const {},
        requiresAuth: true,
      );
      if (mounted) Get.back();
    } catch (e) {
      CustomSnackbar.showError(title: 'common_error', message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _walkId != null;
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'live_track_title'.tr.isEmpty ? 'Suivi de balade' : 'live_track_title'.tr,
          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              active
                  ? '🟢 Balade en cours · $_pushed position(s) envoyée(s)'
                  : 'Prêt à démarrer la balade',
            ),
            const SizedBox(height: 8),
            if (active)
              Text(
                'Position envoyée automatiquement à chaque déplacement de 10m+',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 24),
            if (!active)
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Démarrer la balade'),
                onPressed: _busy ? null : _start,
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text('Terminer la balade'),
                onPressed: _busy ? null : _stop,
              ),
          ],
        ),
      ),
    );
  }
}
