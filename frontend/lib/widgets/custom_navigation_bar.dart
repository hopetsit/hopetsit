import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/notification_badge.dart';

/// v23.1 part 31 — TENTATIVE FINALE : ZÉRO Material widget. Container brut
/// + Theme(useMaterial3: false) override LOCAL pour que Material 3 ne puisse
/// PAS injecter d'indicateur "selected" caché autour du tab actif.
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
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // v23.1 part 31 — Theme override LOCAL : useMaterial3: false force le
    // sous-tree à utiliser Material 2, qui n'a PAS de selected indicator
    // automatique sur les BottomNavigationBar / NavigationBar.
    return Theme(
      data: Theme.of(context).copyWith(
        useMaterial3: false,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: Container(
        color: bgColor,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          height: 64.h,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              top: BorderSide(
                color: const Color(0xFFE5E5E5),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildNavItem(
                  context, 0, AppImages.pawIcon, 'nav_home'.tr, isDark,
                  badgeIndex: 0, bg: bgColor,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  context, 1, AppImages.chatIcon, 'nav_chat'.tr, isDark,
                  badgeIndex: 1, bg: bgColor,
                ),
              ),
              Expanded(child: _buildCenterMapButton(context, isDark, bgColor)),
              Expanded(
                child: _buildNavItem(
                  context, 3, AppImages.calendarIcon, 'nav_bookings'.tr, isDark,
                  badgeIndex: 2, bg: bgColor,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  context, 4, AppImages.personIcon, 'nav_profile'.tr, isDark,
                  bg: bgColor,
                ),
              ),
            ],
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
    required Color bg,
  }) {
    final isSelected = currentIndex == index;
    final activeColor = _activeColorForCurrentRole();
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF9E9E9E);

    // v23.1 part 31 — Container BG explicite blanc + GestureDetector simple,
    // sans Material/InkResponse. Aucun selected indicator possible.
    return Container(
      color: bg,
      child: GestureDetector(
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
              // v23.1 part 31 — dot indicator FIXE (pas AnimatedContainer)
              // pour éviter tout repaint qui pourrait laisser un artefact.
              SizedBox(
                width: 5.w,
                height: 5.w,
                child: isSelected
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeColor,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterMapButton(BuildContext context, bool isDark, Color bg) {
    final isSelected = currentIndex == 2;
    final roleAccent = _activeColorForCurrentRole();
    final roleAccentLight = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.25),
      roleAccent,
    );

    return Container(
      color: bg,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap(2);
        },
        behavior: HitTestBehavior.opaque,
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
            ),
            child: Icon(
              Icons.map_rounded,
              size: 24.sp,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
