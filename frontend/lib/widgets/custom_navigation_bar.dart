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
        // Pas de migration possible sans changer le rendu : il faut hériter
        // du Theme ambiant ET forcer Material 2 ; un constructeur ThemeData
        // (.from/.light/.dark) perdrait les propriétés héritées.
        // ignore: deprecated_member_use
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
              Expanded(
                child: _CenterPawMapButton(
                  isSelected: currentIndex == 2,
                  bg: bgColor,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onTap(2);
                  },
                ),
              ),
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
            // v444 — onglet Chat : NE PAS forcer le badge à 0 (sinon le vrai
            // total non-lu « revient » au prochain resync — bug « 1 puis 5 »).
            // On recale sur la vérité serveur ; le badge se vide ensuite
            // conversation par conversation, à la lecture RÉELLE.
            if (index == 1) nc.syncChatBadgeFromServer();
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

}

/// v452 — Refonte du bouton central « Paw Map » (Daniel) : la fonctionnalité
/// PHARE de l'app. Pill arrondi ORANGE plus grand que les autres onglets,
/// surélevé, icône carte + patte + texte « Paw Map », ombre douce, légère
/// animation au clic, et pulsation discrète + icône plus grande quand actif.
/// Les autres onglets restent gris → Paw Map est le point focal.
class _CenterPawMapButton extends StatefulWidget {
  const _CenterPawMapButton({
    required this.isSelected,
    required this.onTap,
    required this.bg,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final Color bg;

  @override
  State<_CenterPawMapButton> createState() => _CenterPawMapButtonState();
}

class _CenterPawMapButtonState extends State<_CenterPawMapButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    // Pulsation discrète (1.0 ↔ 1.05) uniquement quand l'onglet est actif.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: 1.0,
      upperBound: 1.05,
    );
    if (widget.isSelected) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _CenterPawMapButton old) {
    super.didUpdateWidget(old);
    if (widget.isSelected && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isSelected && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const orange = AppColors.primaryColor;
    final iconSize = widget.isSelected ? 26.sp : 23.sp;
    return Container(
      color: widget.bg,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedScale(
            // Légère animation au clic (s'enfonce un peu).
            scale: _pressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 110),
            child: ScaleTransition(
              scale: _pulse,
              child: Container(
                // Pill plus large + surélevé (déborde un peu vers le haut).
                margin: EdgeInsets.only(bottom: 2.h),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B45), orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18.r),
                  boxShadow: [
                    BoxShadow(
                      color: orange.withValues(alpha: widget.isSelected ? 0.45 : 0.30),
                      blurRadius: widget.isSelected ? 14 : 9,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icône carte + patte intégrée (toujours blanche).
                    SizedBox(
                      width: iconSize + 4,
                      height: iconSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.map_rounded,
                              size: iconSize, color: Colors.white),
                          Positioned(
                            top: -2.h,
                            child: Container(
                              padding: EdgeInsets.all(1.6.w),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.pets,
                                  size: iconSize * 0.46, color: orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Paw Map',
                      style: TextStyle(
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
