import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

/// Session v3.2 — handles the "chat requires Premium or Chat add-on"
/// upsell triggered when the backend returns `402 CHAT_ACCESS_REQUIRED`.
///
/// Call [maybeShowChatUpsell] from any catch block that might receive the
/// ApiException. Returns `true` when the exception was the chat-access one
/// (and the caller should stop its own error handling), `false` otherwise.
///
/// v569 — DESIGN UNIQUEMENT : mêmes conditions de déclenchement, même
/// destination (Boutique), même valeur de retour. Nouveau rendu : carte
/// coins 24, disque or « premium » 56 px, titre centré, deux bénéfices en
/// lignes, boutons pleine largeur empilés.
class ChatAccessUpsellHelper {
  ChatAccessUpsellHelper._();

  /// Or « PawPremium » (charte : noir/or).
  static const Color _gold = Color(0xFFF4C04A);

  /// Inspects [error] and, if it's an [ApiException] with
  /// `statusCode == 402` and `code == 'CHAT_ACCESS_REQUIRED'`, shows a
  /// dialog pointing the user at the Boutique. Returns `true` when handled.
  static bool maybeShowChatUpsell(
    BuildContext context,
    Object error,
  ) {
    if (error is! ApiException) return false;
    if (error.statusCode != 402) return false;
    final details = error.details;
    final code = details is Map ? details['code']?.toString() : null;
    if (code != 'CHAT_ACCESS_REQUIRED') return false;

    _showUpsellDialog(context);
    return true;
  }

  static void _showUpsellDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final bool dark = Theme.of(dialogContext).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(horizontal: 26.w, vertical: 24.h),
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 18.h),
              decoration: BoxDecoration(
                color: AppColors.card(dialogContext),
                borderRadius: BorderRadius.circular(24.r),
                border: dark
                    ? Border.all(color: AppColors.dividerDark, width: 1)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.5 : 0.16),
                    blurRadius: 28,
                    spreadRadius: -8,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56.w,
                    height: 56.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: dark ? 0.24 : 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      color: const Color(0xFFC8920A),
                      size: 27.sp,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  // v23.1 part 240 — i18n full sweep, plus de strings hardcoded FR.
                  PoppinsText(
                    text: 'chat_locked_dialog_title'.tr,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(dialogContext),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  InterText(
                    text: 'chat_locked_dialog_desc'.tr,
                    fontSize: 14.sp,
                    height: 1.45,
                    color: AppColors.textSecondary(dialogContext),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 18.h),
                  _bullet(
                    dialogContext,
                    icon: Icons.star_rounded,
                    color: const Color(0xFF7C3AED), // v354 — PawFollow = violet
                    title: 'chat_locked_dialog_premium_title'.tr,
                    subtitle: 'chat_locked_dialog_premium_sub'.tr,
                  ),
                  SizedBox(height: 8.h),
                  _bullet(
                    dialogContext,
                    icon: Icons.chat_bubble_rounded,
                    color: AppColors.primaryColor,
                    title: 'chat_locked_dialog_addon_title'.tr,
                    subtitle: 'chat_locked_dialog_addon_sub'.tr,
                  ),
                  SizedBox(height: 20.h),
                  CustomButton(
                    width: double.infinity,
                    height: 50.h,
                    radius: 14.r,
                    title: 'chat_locked_dialog_open_shop'.tr,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    bgColor: AppColors.primaryColor,
                    textColor: AppColors.whiteColor,
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      Get.to(() => const CoinShopScreen());
                    },
                  ),
                  SizedBox(height: 10.h),
                  CustomButton(
                    width: double.infinity,
                    height: 50.h,
                    radius: 14.r,
                    title: 'chat_locked_dialog_later'.tr,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    bgColor: dark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF1F2F4),
                    textColor: AppColors.textPrimary(dialogContext),
                    onTap: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _bullet(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, size: 18.sp, color: color),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: title,
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: subtitle,
                  fontSize: 12.sp,
                  height: 1.35,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
