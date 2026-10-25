// 622 (PAM, 25/10/2026) — rappel « Active les notifications » pour les
// GARDIENS et PROMENEURS (Daniel : « quand un propriétaire publie, les gens
// autour reçoivent la notif sans le bandeau de la page d'accueil »).
// Mesure serveur de BOB : une partie des prestataires prévenus n'ont rien vu
// hors de l'app. Jusqu'ici, un prestataire qui avait dit « Plus tard » ou
// refusé n'était plus jamais relancé (seul l'écran caché « Tester mes
// notifications » le proposait). Cette carte n'apparaît que si l'autorisation
// manque ; « Activer » ouvre la fenêtre système (jamais répondu) ou les
// Réglages de l'app (refusé) ; « Plus tard » la masque 7 jours.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

import '../services/push_notification_service.dart';
import '../utils/app_colors.dart';
import 'app_text.dart';

/// Clé locale : date (ms) jusqu'à laquelle le rappel est masqué.
const String kNotifNudgeSnoozeKey622 = 'notif_nudge_snooze_622';

/// Règle pure (testée) : montrer le rappel ?
bool notifNudgeVisible622({
  required String role,
  required bool needsPermission,
  int? snoozedUntilMs,
  DateTime? now,
}) {
  final r = role.toLowerCase();
  if (r != 'sitter' && r != 'walker') return false;
  if (!needsPermission) return false;
  final t = (now ?? DateTime.now()).millisecondsSinceEpoch;
  return snoozedUntilMs == null || t >= snoozedUntilMs;
}

class NotifNudge622 extends StatefulWidget {
  const NotifNudge622({super.key, required this.role, this.statusOverride});

  /// 'sitter' | 'walker' (rien pour un propriétaire).
  final String role;

  /// Tests seulement : état d'autorisation imposé.
  final Future<bool> Function()? statusOverride;

  @override
  State<NotifNudge622> createState() => _NotifNudge622State();
}

class _NotifNudge622State extends State<NotifNudge622> with WidgetsBindingObserver {
  bool _show = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour des Réglages : la carte disparaît dès que c'est autorisé.
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  int? _snoozedUntil() {
    try {
      final v = GetStorage().read(kNotifNudgeSnoozeKey622);
      return v is int ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _needsPermission() async {
    if (widget.statusOverride != null) return widget.statusOverride!();
    if (!Get.isRegistered<PushNotificationService>()) return false;
    final st = await Get.find<PushNotificationService>().authorizationStatus();
    return PushNotificationService.needsNudge622(st);
  }

  Future<void> _refresh() async {
    final needs = await _needsPermission();
    if (!mounted) return;
    final show = notifNudgeVisible622(
        role: widget.role, needsPermission: needs, snoozedUntilMs: _snoozedUntil());
    if (show != _show) setState(() => _show = show);
  }

  Future<void> _activate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      var granted = false;
      if (Get.isRegistered<PushNotificationService>()) {
        granted = await Get.find<PushNotificationService>().requestFromNudge622();
      }
      if (!granted) await openAppSettings();
    } catch (_) {/* jamais bloquant */}
    if (mounted) setState(() => _busy = false);
    await _refresh();
  }

  void _later() {
    try {
      GetStorage().write(kNotifNudgeSnoozeKey622,
          DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch);
    } catch (_) {}
    setState(() => _show = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final bool walker = widget.role.toLowerCase() == 'walker';
    // Couleur du rôle : bleu gardien, vert promeneur (jamais de gris).
    final Color a = walker ? AppColors.walkerAccent : const Color(0xFF2563EB);
    final Color b = walker ? const Color(0xFF15803D) : const Color(0xFF1E4FB0);
    return Container(
      key: const ValueKey<String>('notif_nudge_622'),
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 10.w, 12.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        // Dégradé horizontal à la couleur du rôle (préférence de Daniel).
        gradient: LinearGradient(colors: [a, b]),
        boxShadow: [
          BoxShadow(color: a.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40.r,
            height: 40.r,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(Icons.notifications_active_rounded, color: a, size: 22.r),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InterText(
                  text: 'notif622_title'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  maxLines: 1,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: (walker ? 'notif622_body_walker' : 'notif622_body_sitter').tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  maxLines: 3,
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    GestureDetector(
                      key: const ValueKey<String>('notif_nudge_622_on'),
                      onTap: _activate,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: _busy
                            ? SizedBox(
                                width: 14.r,
                                height: 14.r,
                                child: CircularProgressIndicator(strokeWidth: 2, color: a))
                            : InterText(
                                text: 'notif622_cta'.tr,
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w800,
                                color: b,
                              ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    GestureDetector(
                      key: const ValueKey<String>('notif_nudge_622_later'),
                      onTap: _later,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 7.h),
                        child: InterText(
                          text: 'notif622_later'.tr,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
