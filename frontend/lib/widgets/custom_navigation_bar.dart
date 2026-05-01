import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/notification_badge.dart';

/// v23.1 part 28 — APPLICATION DE LA TECHNIQUE HomeHeader QUI A FIXÉ LE
/// CARRÉ GRIS DU HAUT (Daniel : "fais la meme technique").
///
/// HomeHeader recette :
///   Material(color: bgColor, elevation: 0)
///     SafeArea(bottom: false)  ← gère top inset, pas bottom
///       SizedBox(height: 70.h)
///         Padding + Row [contenu]
///
/// Pour le BOTTOM nav, on inverse :
///   Material(color: bgColor, elevation: 0)
///     SafeArea(top: false)     ← gère bottom inset (gesture area), pas top
///       SizedBox(height: 78.h)
///         Row [items]
///
/// Le SafeArea peint la zone bottom-inset (gesture) en BLANC. Plus aucune
/// pixel transparent où un gris peut transparaître. Pas de margins, pas de
/// borderRadius, pas de boxShadow (qui créaient des zones non-peintes).
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
    final bgColor = AppColors.appBar(context);

    return Material(
      color: bgColor,
      elevation: 0,
      // Borders TOP fines pour séparer visuellement de la zone contenu sans
      // ombrer (les ombres faisaient apparaître des transparences).
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: BorderSide(
              color: AppColors.divider(context),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64.h,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildNavItem(
                    context, 0, AppImages.pawIcon, 'nav_home'.tr, isDark,
                    badgeIndex: 0,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context, 1, AppImages.chatIcon, 'nav_chat'.tr, isDark,
                    badgeIndex: 1,
                  ),
                ),
                Expanded(child: _buildCenterMapButton(context, isDark)),
                Expanded(
                  child: _buildNavItem(
                    context, 3, AppImages.calendarIcon, 'nav_bookings'.tr, isDark,
                    badgeIndex: 2,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context, 4, AppImages.personIcon, 'nav_profile'.tr, isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
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
      child: Center(
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
                          ? 0
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
    final roleAccentLight = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.25),
      roleAccent,
    );

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap(2);
      },
      child: Center(
        child: Container(
          width: 46.w,
          height: 46.w,
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
          ),
          child: Icon(
            Icons.map_rounded,
            size: 24.sp,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
