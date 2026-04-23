import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/notification_badge.dart';

/// v18.8 — couleur de rôle dynamique pour la nav bottom.
/// walker → vert · sitter → bleu · owner → orange (primary).
Color _activeColorForCurrentRole() {
  final role = Get.isRegistered<AuthController>()
      ? (Get.find<AuthController>().userRole.value ?? 'owner').toLowerCase()
      : 'owner';
  if (role == 'walker') return const Color(0xFF16A34A);
  if (role == 'sitter') return const Color(0xFF2563EB);
  return AppColors.primaryColor;
}

class CustomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 78.h,
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Home — v18.9 : badge "1" quand direct request arrive (provider)
          // ou application/acceptation arrive (owner).
          _buildNavItem(context, 0, AppImages.pawIcon, 'nav_home'.tr, isDark, badgeIndex: 0),
          // Chat
          _buildNavItem(context, 1, AppImages.chatIcon, 'nav_chat'.tr, isDark, badgeIndex: 1),
          // Center MAP button (elevated)
          _buildCenterMapButton(context, isDark),
          // Calendar / Bookings
          _buildNavItem(context, 3, AppImages.calendarIcon, 'nav_bookings'.tr, isDark, badgeIndex: 2),
          // Profile
          _buildNavItem(context, 4, AppImages.personIcon, 'nav_profile'.tr, isDark),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    String iconPath,
    String label,
    bool isDark, {
    int? badgeIndex,
  }) {
    final isSelected = currentIndex == index;
    final activeColor = _activeColorForCurrentRole();
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF9E9E9E);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (Get.isRegistered<NotificationsController>()) {
          final nc = Get.find<NotificationsController>();
          if (index == 0) nc.clearHomeBadge();
          if (index == 1) nc.clearChatBadge();
          if (index == 3) nc.clearBookingsBadge();
        }
        onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset(
                  iconPath,
                  width: 22.w,
                  height: 22.h,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                if (badgeIndex != null)
                  Positioned(
                    top: -6.h,
                    right: -8.w,
                    child: Obx(() {
                      if (!Get.isRegistered<NotificationsController>()) {
                        return const SizedBox.shrink();
                      }
                      final nc = Get.find<NotificationsController>();
                      final count = badgeIndex == 0
                          ? nc.unreadHome.value
                          : badgeIndex == 1
                              ? nc.unreadChat.value
                              : nc.unreadBookings.value;
                      return NotificationBadge(count: count);
                    }),
                  ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Selected indicator dot
            SizedBox(height: 3.h),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 5.w : 0,
              height: isSelected ? 5.w : 0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterMapButton(BuildContext context, bool isDark) {
    final isSelected = currentIndex == 2;
    final roleAccent = _activeColorForCurrentRole();
    // Nuance plus claire du rôle pour le gradient (sans dépendance asset).
    final roleAccentLight = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.25),
      roleAccent,
    );

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap(2);
      },
      child: Container(
        width: 54.w,
        height: 54.w,
        transform: Matrix4.translationValues(0, -14.h, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [roleAccent, roleAccentLight]
                : [roleAccent.withValues(alpha: 0.85), roleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: roleAccent.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            width: 3,
          ),
        ),
        child: Icon(
          Icons.map_rounded,
          size: 24.sp,
          color: Colors.white,
        ),
      ),
    );
  }
}
