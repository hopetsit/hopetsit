import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/loyalty_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';

/// Sprint 7 step 1 — compact loyalty card for owner profile.
///
/// v23.1.344 — Daniel : "avantages fidélité owner ne se met pas à jour".
/// AVANT : StatelessWidget qui appelait ctrl.load() dans build() → comme le
/// profil vit dans l'IndexedStack de la nav (jamais re-buildé au changement
/// d'onglet), la carte restait FIGÉE sur les valeurs du lancement de l'app.
/// MAINTENANT (même pattern éprouvé que TopSitterCard + la bande d'accueil) :
///   - load au montage,
///   - reload au retour de l'app au premier plan,
///   - reload à chaque notification reçue (une confirmation de service envoie
///     une notif → le compteur se met à jour dans la seconde),
///   - filet périodique 60s tant que la carte est montée.
class LoyaltyCard extends StatefulWidget {
  const LoyaltyCard({super.key});

  @override
  State<LoyaltyCard> createState() => _LoyaltyCardState();
}

class _LoyaltyCardState extends State<LoyaltyCard>
    with WidgetsBindingObserver {
  late final LoyaltyController ctrl;
  Worker? _notifWorker;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ctrl = Get.isRegistered<LoyaltyController>()
        ? Get.find<LoyaltyController>()
        : Get.put(LoyaltyController());
    ctrl.load();
    if (Get.isRegistered<NotificationsController>()) {
      final notifs = Get.find<NotificationsController>();
      _notifWorker = ever<int>(notifs.unreadCount, (_) => ctrl.load());
    }
    _refresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) ctrl.load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifWorker?.dispose();
    _refresh?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ctrl.load();
  }

  /// Or « PawPremium » (charte noir/or).
  static const Color _gold = Color(0xFFF4C04A);
  static const Color _goldDeep = Color(0xFFC8920A);

  @override
  Widget build(BuildContext context) {
    // v569 — DESIGN UNIQUEMENT : mêmes clés i18n, mêmes données, mêmes
    // rafraîchissements. Nouveau rendu : carte coins 20, en-tête à disque or,
    // barres de progression lisibles, crédits en pilule. Les textes suivent
    // désormais le mode sombre (avant : TextStyle const → noir sur noir).
    return Obx(() {
      final bool premium = ctrl.isPremium.value;
      final int done = ctrl.completedBookingsCount.value;
      final double credits = ctrl.availableCreditsTotal.value;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: AppColors.cardShadow(context),
          border: premium
              ? Border.all(color: _gold, width: 1.6)
              : Border.all(color: AppColors.divider(context), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38.w,
                  height: 38.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.workspace_premium_rounded,
                      size: 20.sp, color: _goldDeep),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'loyalty_title'.tr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                if (premium) ...[
                  SizedBox(width: 8.w),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    constraints: BoxConstraints(maxWidth: 120.w),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      'loyalty_premium_badge'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: _goldDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 14.h),
            if (!premium) ...[
              _progressRow(
                context,
                label: 'loyalty_progress_premium'.trParams({
                  'done': done.toString(),
                  'goal': '10',
                }),
                value: (done / 10).clamp(0.0, 1.0),
                color: _goldDeep,
              ),
              SizedBox(height: 12.h),
            ],
            Text(
              'misc569_loyalty_next'.tr.toUpperCase(),
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.textSecondary(context),
              ),
            ),
            SizedBox(height: 6.h),
            _progressRow(
              context,
              label: 'loyalty_progress_discount'.trParams({
                'done': (done % 3).toString(),
                'goal': '3',
              }),
              value: ((done % 3) / 3).clamp(0.0, 1.0),
              color: AppColors.activeRoleAccent(),
            ),
            if (credits > 0) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.card_giftcard_rounded,
                        size: 17.sp, color: const Color(0xFF16A34A)),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'loyalty_credits_available'.trParams({
                          'amount': credits.toStringAsFixed(2),
                          'currency': ctrl.currency.value,
                        }),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _progressRow(
    BuildContext context, {
    required String label,
    required double value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5.sp,
            height: 1.35,
            color: AppColors.textSecondary(context),
          ),
        ),
        SizedBox(height: 6.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(999.r),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6.h,
            backgroundColor: color.withValues(alpha: 0.14),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
