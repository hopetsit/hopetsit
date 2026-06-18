import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/widgets/notification_badge.dart';

/// v459 — Daniel : NOUVEAU MENU (maquette Claude Design). Barre flottante
/// blanche arrondie + icônes duotone modernes (paw / chat / calendrier / user)
/// + bouton central « Paw Map » en pilule ORANGE surélevée (carte pliée + pin
/// + patte). Toujours visible (montée en bottomNavigationBar par le shell).
///
/// Logique PRÉSERVÉE depuis l'ancien menu : badges non-lus (Chat onglet 1,
/// Réservations onglet 3), clear-badge au tap (home/chat/bookings), haptique,
/// callback onTap(index) identique. Seul le VISUEL change.
const Color _kAccent = Color(0xFFF2741B); // orange maquette (actif + centre)
const Color _kAccentDark = Color(0xFFE0660F);
const Color _kInactive = Color(0xFF7D7D82);

class CustomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  // ── Icônes duotone (SVG injecté avec la bonne couleur selon actif/inactif) ──
  String get _accentHex => '#F2741B';
  String get _inactiveHex => '#7D7D82';
  String _hex(bool active) => active ? _accentHex : _inactiveHex;
  String _lite(bool active) => active ? '#F2741B26' : '#7D7D8222';

  String _pawSvg(bool active) {
    final f = _hex(active);
    return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="$f">
<ellipse cx="6.4" cy="10.6" rx="2" ry="2.6"/><ellipse cx="10.3" cy="7.2" rx="2" ry="2.7"/>
<ellipse cx="14.7" cy="7.2" rx="2" ry="2.7"/><ellipse cx="18.6" cy="10.6" rx="2" ry="2.6"/>
<path d="M12.5 12c-2.6 0-4.8 1.9-5.5 4.1-.5 1.7.4 3.3 2.2 3.6 1 .2 1.8-.3 2.7-.5.4-.1.8-.1 1.2 0 .9.2 1.7.7 2.7.5 1.8-.3 2.7-1.9 2.2-3.6-.7-2.2-2.9-4.1-5.5-4.1Z"/></svg>''';
  }

  String _chatSvg(bool active) {
    final s = _hex(active);
    final l = _lite(active);
    return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$s" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">
<path d="M12.2 4C7.4 4 3.6 7 3.6 11c0 1.7.7 3.2 1.8 4.4L4 19.7l4.5-1.4c1.1.4 2.4.6 3.7.6 4.8 0 8.6-3 8.6-7s-3.8-7-8.6-7.9Z" fill="$l" stroke="none"/>
<path d="M12.2 4C7.4 4 3.6 7 3.6 11c0 1.7.7 3.2 1.8 4.4L4 19.7l4.5-1.4c1.1.4 2.4.6 3.7.6 4.8 0 8.6-3 8.6-7S17 4 12.2 4Z"/>
<circle cx="8.9" cy="11.2" r="1" fill="$s" stroke="none"/><circle cx="12.3" cy="11.2" r="1" fill="$s" stroke="none"/><circle cx="15.7" cy="11.2" r="1" fill="$s" stroke="none"/></svg>''';
  }

  String _calSvg(bool active) {
    final s = _hex(active);
    final l = _lite(active);
    return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
<rect x="3.4" y="4.8" width="17.2" height="15.8" rx="4.2" fill="$l" stroke="none"/>
<rect x="3.4" y="4.8" width="17.2" height="15.8" rx="4.2"/>
<path d="M3.5 9.4h17" stroke-width="1.9"/><path d="M7.8 3v3.4M16.2 3v3.4"/>
<circle cx="8.3" cy="13.4" r="1.1" fill="$s" stroke="none"/><circle cx="12" cy="13.4" r="1.1" fill="$s" stroke="none"/><circle cx="15.7" cy="13.4" r="1.1" fill="$s" stroke="none"/>
<circle cx="8.3" cy="16.9" r="1.1" fill="$s" stroke="none"/><circle cx="12" cy="16.9" r="1.1" fill="$s" stroke="none"/></svg>''';
  }

  String _userSvg(bool active) {
    final s = _hex(active);
    final l = _lite(active);
    return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
<path d="M12 13.4c-4 0-7.2 2.6-7.2 6.6 0 .4.3.6.7.6h13c.4 0 .7-.2.7-.6 0-4-3.2-6.6-7.2-6.6Z" fill="$l" stroke="none"/>
<circle cx="12" cy="8" r="3.8" fill="$l"/><circle cx="12" cy="8" r="3.8"/>
<path d="M4.8 20.2c0-4 3.2-6.6 7.2-6.6s7.2 2.6 7.2 6.6"/></svg>''';
  }

  // Centre : carte pliée 3 panneaux + pin (patte dedans), blanc sur orange.
  static const String _centreSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 28 28" fill="none">
<path d="M3 11 7.5 9.2v11.6L3 22.6V11Z" fill="#fff" opacity="0.9"/>
<path d="M20.5 9.2 25 11v11.6l-4.5-1.8V9.2Z" fill="#fff" opacity="0.9"/>
<path d="M7.5 9.2 20.5 11v9.8L7.5 20.8V9.2Z" fill="#fff" opacity="0.9"/>
<path d="M7.5 9.2v11.6M20.5 9.2v11.6" stroke="#F2741B" stroke-width="1" opacity="0.3" stroke-linecap="round"/>
<path d="M14 2c-3.4 0-6.1 2.6-6.1 6 0 4.2 6.1 10.2 6.1 10.2S20.1 12.2 20.1 8c0-3.4-2.7-6-6.1-6Z" fill="#fff" stroke="#F2741B" stroke-width="1.1"/>
<ellipse cx="11.4" cy="6.4" rx="0.95" ry="1.2" fill="#F2741B"/><ellipse cx="14" cy="5.5" rx="0.95" ry="1.2" fill="#F2741B"/><ellipse cx="16.6" cy="6.4" rx="0.95" ry="1.2" fill="#F2741B"/>
<path d="M14 7.7c-1.5 0-2.7 1-3.1 2.2-.3.9.2 1.8 1.1 2 .5.1 1-.1 1.4-.2.4-.1.7-.1 1.1 0 .5.1.9.3 1.4.2.9-.2 1.4-1.1 1.1-2-.4-1.2-1.6-2.2-3-2.2Z" fill="#F2741B"/></svg>''';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Theme override LOCAL (Material 2) : pas d'indicateur "selected" auto.
    return Theme(
      data: Theme.of(context).copyWith(
        // ignore: deprecated_member_use
        useMaterial3: false,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: Padding(
        // Barre FLOTTANTE : marges autour de la pilule blanche.
        padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h + bottomInset),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14141E).withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: const Color(0xFF14141E).withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _navItem(0, _pawSvg, 'nav_home'.tr)),
              Expanded(child: _navItem(1, _chatSvg, 'nav_chat'.tr, badge: 1)),
              _CenterPawMapButton(
                isSelected: currentIndex == 2,
                svg: _centreSvg,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onTap(2);
                },
              ),
              Expanded(
                  child: _navItem(3, _calSvg, 'nav_bookings'.tr, badge: 2)),
              Expanded(child: _navItem(4, _userSvg, 'nav_profile'.tr)),
            ],
          ),
        ),
      ),
    );
  }

  /// Onglet latéral : icône duotone + label. `badge` : 1=chat, 2=réservations.
  Widget _navItem(int index, String Function(bool) svgBuilder, String label,
      {int? badge}) {
    final isActive = currentIndex == index;
    final color = isActive ? _kAccent : _kInactive;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        if (Get.isRegistered<NotificationsController>()) {
          final nc = Get.find<NotificationsController>();
          if (index == 0) nc.clearHomeBadge();
          // v444 — onglet Chat : NE PAS forcer le badge à 0 (resync serveur).
          if (index == 1) nc.syncChatBadgeFromServer();
          if (index == 3) nc.clearBookingsBadge();
        }
        onTap(index);
      },
      child: AnimatedSlide(
        offset: isActive ? const Offset(0, -0.04) : Offset.zero,
        duration: const Duration(milliseconds: 160),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.string(
                  svgBuilder(isActive),
                  width: 26.w,
                  height: 26.w,
                ),
                if (badge != null)
                  Positioned(
                    top: -6.h,
                    right: -8.w,
                    child: Obx(() {
                      if (!Get.isRegistered<NotificationsController>()) {
                        return const SizedBox.shrink();
                      }
                      final nc = Get.find<NotificationsController>();
                      final count = badge == 1
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton central « Paw Map » — pilule ORANGE surélevée (maquette), icône
/// carte+pin+patte (SVG blanc) + texte « Paw Map », légère pulsation quand actif.
class _CenterPawMapButton extends StatefulWidget {
  const _CenterPawMapButton({
    required this.isSelected,
    required this.onTap,
    required this.svg,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final String svg;

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
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: 1.0,
      upperBound: 1.04,
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
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: ScaleTransition(
          scale: _pulse,
          child: AnimatedSlide(
            offset: widget.isSelected
                ? const Offset(0, -0.06)
                : Offset.zero,
            duration: const Duration(milliseconds: 180),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kAccent, _kAccentDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(22.r),
                boxShadow: [
                  BoxShadow(
                    color: _kAccent.withValues(alpha: 0.40),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.string(
                    widget.svg,
                    width: 30.w,
                    height: 30.w,
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'Paw Map',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
