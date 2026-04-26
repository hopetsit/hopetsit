import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';

/// Reusable dialog showing "This feature requires PawPass".
/// Usage: PawPassRequiredDialog.show(context)
class PawPassRequiredDialog {
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.card(dialogContext),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: PoppinsText(
            text: 'pawpass_required_title'.tr,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(dialogContext),
          ),
          content: InterText(
            text: 'pawpass_required_message'.tr,
            fontSize: 14.sp,
            color: AppColors.textSecondary(dialogContext),
            fontWeight: FontWeight.w400,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: PoppinsText(
                text: 'pawpass_later_button'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(dialogContext),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Get.to(() => const CoinShopScreen(initialTab: 1));
              },
              child: PoppinsText(
                text: 'pawpass_discover_button'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF5A623),
              ),
            ),
          ],
        );
      },
    );
  }
}
