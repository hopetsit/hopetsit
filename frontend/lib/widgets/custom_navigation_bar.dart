import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/notification_badge.dart';

/// v23.1 part 20 — refactor RADICAL pour fixer définitivement le carré gris
/// autour de l'onglet "Accueil". Approche bulletproof :
///   1. Material(color: white) AU NIVEAU DU NAV BAR pour forcer un layer
///      Material avec couleur explicite (annule tout surface tint Material 3
///      hérité du Scaffold/Theme).
///   2. ColoredBox(white) à L'INTÉRIEUR de chaque _buildNavItem pour garantir
///      que même si un ancêtre tente de teinter, chaque slot est repaint en
///      blanc.
///   3. InkResponse(splashFactory: NoSplash, highlightColor: transparent)
///      remplace GestureDetector — élimine tout ripple/highlight Material qui
///      pourrait laisser un halo gris.
///   4. AnimatedContainer dot supprimé — un container 0×0 reste un nœud de
///      rendu dans le tree et peut potentiellement allouer un layer pendant
///      l'animation.
///   5. Pas de SizedBox.expand — le layout natif Row/Expanded suffit.
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bg = isDark ? const Color(0xFF121212) : Colors.white;

    // v23.1 part 26 — Option B Daniel : la zone bottom-inset (sous la nav bar
    // visible, où sont les III □ ← du système) DOIT être NOIRE pour matcher
    // l'OS. Sinon le blanc de notre app dépasse dans le coin bas-gauche et
    // crée un "rectangle gris" visible. On utilise un Column qui sépare
    // explicitement la nav (white) du bottom inset (black).
    return Material(
      color: bg,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1) Nav bar visible : 64.h, fond bg (blanc en light)
          SizedBox(
            height: 64.h,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildNavItem(
                    context, 0, AppImages.pawIcon, 'nav_home'.tr, isDark,
                    badgeIndex: 0, bg: bg,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context, 1, AppImages.chatIcon, 'nav_chat'.tr, isDark,
                    badgeIndex: 1, bg: bg,
                  ),
                ),
                Expanded(child: _buildCenterMapButton(context, isDark, bg)),
                Expanded(
                  child: _buildNavItem(
                    context, 3, AppImages.calendarIcon, 'nav_bookings'.tr, isDark,
                    badgeIndex: 2, bg: bg,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context, 4, AppImages.personIcon, 'nav_profile'.tr, isDark,
                    bg: bg,
                  ),
                ),
              ],
            ),
          ),
          // 2) Bottom inset : NOIR pour matcher la zone système OS Option B.
          //    Tue le rectangle blanc qui dépassait dans le coin bas-gauche.
          Container(
            height: bottomInset,
            color: Colors.black,
          ),
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
    required Color bg,
  }) {
    final isSelected = currentIndex == index;
    final activeColor = _activeColorForCurrentRole();
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF9E9E9E);

    // v23.1 part 20 — InkResponse + NoSplash pour zéro ripple. Wrapped dans
    // ColoredBox(bg) explicite pour garantir blanc partout.
    return ColoredBox(
      color: bg,
      child: InkResponse(
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
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        radius: 0,
        containedInkWell: false,
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
                        // home tab badge always 0 (suppressed) ; chat & bookings keep theirs.
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
              // v23.1 part 20 — dot indicator FIXE 5×5 visible uniquement quand
              // sélectionné (Visibility maintains: false → enlève le widget du
              // tree quand non sélectionné, plus d'AnimatedContainer 0×0 qui
              // pourrait flasher).
              SizedBox(height: 3.h),
              Visibility(
                visible: isSelected,
                maintainSize: false,
                maintainAnimation: false,
                maintainState: false,
                child: Container(
                  width: 5.w,
                  height: 5.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activeColor,
                  ),
                ),
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

    return ColoredBox(
      color: bg,
      child: InkResponse(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap(2);
        },
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
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
      ),
    );
  }
}
