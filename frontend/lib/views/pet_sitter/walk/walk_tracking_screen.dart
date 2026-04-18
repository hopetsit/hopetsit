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
  Timer? _timer;
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
        message: 'Location permission denied.',
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
        _startTicker();
      }
    } catch (e) {
      CustomSnackbar.showError(title: 'common_error', message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _pushPosition());
    // Push immediately too.
    _pushPosition();
  }

  Future<void> _pushPosition() async {
    if (_walkId == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _api.post(
        '${ApiEndpoints.walksPosition}/$_walkId/position',
        body: {'lat': pos.latitude, 'lng': pos.longitude},
        requiresAuth: true,
      );
      if (mounted) setState(() => _pushed++);
    } catch (_) {
      // best-effort; keep ticking
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
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
    _timer?.cancel();
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
        title: Text('Walk tracking', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(active ? 'Walk is live · $_pushed positions pushed' : 'Ready to start'),
            const SizedBox(height: 24),
            if (!active)
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start walk'),
                onPressed: _busy ? null : _start,
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text('End walk'),
                onPressed: _busy ? null : _stop,
              ),
          ],
        ),
      ),
    );
  }
}
