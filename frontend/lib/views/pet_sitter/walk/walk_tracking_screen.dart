import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Sprint 6 step 2 — sitter live walk tracking screen.
///
/// v565 — kit Profil : bandeau d'état couleur du rôle / vert en direct,
/// compteur, bouton Démarrer / Terminer ; 2 titres de snackbar sans `.tr`
/// corrigés, repli FR en dur du titre retiré (clé présente en 9 langues).
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
      // v23.1 part 244 — i18n (Daniel audit deep). Was hardcoded FR.
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'live_track_perm_denied'.tr,
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
      // v565 — `.tr` manquant : la clé brute « common_error » s'affichait.
      CustomSnackbar.showError(title: 'common_error'.tr, message: e.toString());
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
      // v565 — `.tr` manquant : la clé brute « common_error » s'affichait.
      CustomSnackbar.showError(title: 'common_error'.tr, message: e.toString());
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
    // v565 — kit Profil : bandeau d'état (prêt / en direct) couleur du rôle,
    // compteur de positions, un seul grand bouton Démarrer / Terminer.
    final active = _walkId != null;
    final accent = currentRoleAccent();
    final live = const Color(0xFF16A34A);
    final stateColor = active ? live : accent;
    return ProfileSubPageScaffold(
      title: 'live_track_title'.tr,
      accent: accent,
      bottom: active
          ? ProfilePrimaryButton(
              label: 'walk_stop_btn'.tr,
              accent: AppColors.errorColor,
              icon: Icons.stop_rounded,
              loading: _busy,
              onTap: _busy ? null : _stop,
            )
          : ProfilePrimaryButton(
              label: 'walk_start_btn'.tr,
              accent: accent,
              icon: Icons.play_arrow_rounded,
              loading: _busy,
              onTap: _busy ? null : _start,
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [stateColor, stateColor.withValues(alpha: 0.78)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22.r),
              boxShadow: [
                BoxShadow(
                  color: stateColor.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    active ? Icons.directions_walk_rounded : Icons.pets_rounded,
                    color: Colors.white,
                    size: 26.sp,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (active)
                        Row(
                          children: [
                            Container(
                              width: 8.w,
                              height: 8.w,
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                            ),
                            SizedBox(width: 6.w),
                            InterText(
                              text: 'v565_pay_walk_live'.tr.toUpperCase(),
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      PoppinsText(
                        text: active
                            ? 'walk_active_status'
                                .trParams({'count': _pushed.toString()})
                            : 'walk_ready_status'.tr,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        maxLines: 3,
                      ),
                      if (active) ...[
                        SizedBox(height: 4.h),
                        InterText(
                          text: 'v565_pay_walk_updates'
                              .trParams({'count': _pushed.toString()}),
                          fontSize: 11.5.sp,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (active) ...[
            SizedBox(height: 12.h),
            ProfileInfoBanner(
              icon: Icons.gps_fixed_rounded,
              text: 'walk_position_hint'.tr,
              accent: live,
            ),
          ],
        ],
      ),
    );
  }
}
