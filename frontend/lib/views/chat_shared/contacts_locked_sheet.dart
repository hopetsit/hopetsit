// v565 — point 14 : verrou contacts à 700 comptes (contrat §4).
// Sur `402 { code: 'CONTACTS_LOCKED' }` (partage numéro / adresse) : feuille
// claire → titre, explication, bouton vers la boutique (CoinShopScreen).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/chat_shared/chat_api.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Renvoie true si l'erreur était le verrou contacts (et a été affichée).
bool maybeShowContactsLocked(
  BuildContext context,
  Object error, {
  ChatRoleTheme? theme,
}) {
  if (!ChatApi.isContactsLocked(error)) return false;
  showContactsLockedSheet(context, theme: theme);
  return true;
}

Future<void> showContactsLockedSheet(
  BuildContext context, {
  ChatRoleTheme? theme,
}) {
  final t = theme ?? ChatRoleTheme.current();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card(context),
    useSafeArea: true,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          24.w,
          14.h,
          24.w,
          18.h + MediaQuery.of(ctx).viewPadding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.grey300Color,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 18.h),
            Center(
              child: Container(
                width: 68.w,
                height: 68.w,
                decoration: BoxDecoration(
                  color: t.tintStrong,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_rounded, size: 32.sp, color: t.accent),
              ),
            ),
            SizedBox(height: 16.h),
            PoppinsText(
              text: 'contacts_locked_title'.tr,
              fontSize: 19.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(ctx),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 10.h),
            InterText(
              text: 'contacts_locked_body'.tr,
              fontSize: 13.5.sp,
              color: AppColors.textSecondary(ctx),
              textAlign: TextAlign.center,
              height: 1.45,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                Get.to(() => const CoinShopScreen(initialTab: 3));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
              ),
              icon: Icon(Icons.storefront_rounded, size: 18.sp),
              label: Text(
                'contacts_locked_cta'.tr,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: 6.h),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'common_cancel'.tr,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textSecondary(ctx),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
