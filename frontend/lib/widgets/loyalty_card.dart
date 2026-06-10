import 'dart:async';

import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow(context),
          border: Border.all(color: Colors.amber, width: ctrl.isPremium.value ? 2 : 0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'loyalty_title'.tr,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (ctrl.isPremium.value)
                  Text(
                    'loyalty_premium_badge'.tr,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!ctrl.isPremium.value)
              Text(
                'loyalty_progress_premium'.trParams({
                  'done': ctrl.completedBookingsCount.value.toString(),
                  'goal': '10',
                }),
                style: TextStyle(color: AppColors.grey700Color),
              ),
            const SizedBox(height: 4),
            Text(
              'loyalty_progress_discount'.trParams({
                'done': (ctrl.completedBookingsCount.value % 3).toString(),
                'goal': '3',
              }),
              style: TextStyle(color: AppColors.grey700Color),
            ),
            if (ctrl.availableCreditsTotal.value > 0) ...[
              const SizedBox(height: 8),
              Text(
                'loyalty_credits_available'.trParams({
                  'amount': ctrl.availableCreditsTotal.value.toStringAsFixed(2),
                  'currency': ctrl.currency.value,
                }),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      );
    });
  }
}
