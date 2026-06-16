import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/notifications/notifications_screen.dart';
import 'package:hopetsit/views/notifications/sitter_notifications_screen.dart';

/// v441 — cloche de notifications affichée dans l'en-tête (hero) des 3 écrans
/// de profil (owner/sitter/walker). C'est là qu'arrivent les notifications de
/// demandes / amis / paiements. Réutilise le même [NotificationsController]
/// (badge non-lu) et la même destination que les écrans d'accueil. Icône
/// blanche sur fond coloré du hero, pastille de badge si non-lu > 0.
class ProfileNotificationBell extends StatelessWidget {
  /// 'owner' | 'sitter' | 'walker'. Détermine l'écran de notifications cible
  /// (le sitter a son propre écran ; owner/walker partagent le générique).
  final String role;
  const ProfileNotificationBell({super.key, required this.role});

  NotificationsController get _controller =>
      Get.isRegistered<NotificationsController>()
          ? Get.find<NotificationsController>()
          : Get.put(NotificationsController(), permanent: true);

  void _open() {
    final ctrl = _controller;
    final Widget target = role == 'sitter'
        ? const SitterNotificationsScreen()
        : const NotificationsScreen();
    Get.to(() => target)?.then((_) => ctrl.refreshUnreadCount());
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    return GestureDetector(
      onTap: _open,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.notifications_rounded,
                color: Colors.white, size: 22.sp),
            Positioned(
              top: 6.h,
              right: 8.w,
              child: Obx(() {
                final count = ctrl.unreadCount.value;
                if (count <= 0) return const SizedBox.shrink();
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  constraints: BoxConstraints(minWidth: 14.w),
                  decoration: BoxDecoration(
                    color: AppColors.errorColor,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
