import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Session v3.2 — handles the "chat requires Premium or Chat add-on"
/// upsell triggered when the backend returns `402 CHAT_ACCESS_REQUIRED`.
///
/// Call [maybeShowChatUpsell] from any catch block that might receive the
/// ApiException. Returns `true` when the exception was the chat-access one
/// (and the caller should stop its own error handling), `false` otherwise.
class ChatAccessUpsellHelper {
  ChatAccessUpsellHelper._();

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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card(dialogContext),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        title: Row(
          children: [
            Text('💬', style: TextStyle(fontSize: 22.sp)),
            SizedBox(width: 8.w),
            Expanded(
              child: PoppinsText(
                text: 'Chat verrouillé',
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(dialogContext),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InterText(
              text:
                  'Pour chatter librement avec des amis et entre deux prestations, active un des deux forfaits :',
              fontSize: 13.sp,
              color: AppColors.textSecondary(dialogContext),
            ),
            SizedBox(height: 12.h),
            _bullet(
              dialogContext,
              icon: Icons.star_rounded,
              color: const Color(0xFFFF9500),
              title: 'Premium',
              subtitle: 'Chat avec tout le monde + toutes les features.',
            ),
            SizedBox(height: 8.h),
            _bullet(
              dialogContext,
              icon: Icons.chat_bubble_outline_rounded,
              color: AppColors.primaryColor,
              title: 'Chat add-on (~0,99 €/mois)',
              subtitle: 'Débloque juste le chat, renouvelé tous les 30 jours.',
            ),
          ],
        ),
        actionsPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: InterText(
              text: 'Plus tard',
              fontSize: 14.sp,
              color: AppColors.textSecondary(dialogContext),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Get.to(() => const CoinShopScreen());
            },
            child: InterText(
              text: 'Voir la Boutique',
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _bullet(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34.w,
          height: 34.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10.r),
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
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 2.h),
              InterText(
                text: subtitle,
                fontSize: 12.sp,
                color: AppColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
