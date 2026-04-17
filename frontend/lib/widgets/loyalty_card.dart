import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/loyalty_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';

/// Sprint 7 step 1 — compact loyalty card for owner profile.
class LoyaltyCard extends StatelessWidget {
  const LoyaltyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.isRegistered<LoyaltyController>()
        ? Get.find<LoyaltyController>()
        : Get.put(LoyaltyController());
    ctrl.load();

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
