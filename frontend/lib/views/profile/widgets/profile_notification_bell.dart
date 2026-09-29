import 'package:hopetsit/widgets/paw_count_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/views/notifications/notifications_screen.dart';

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
        // v532 — plus de divergence : le promeneur voyait deux fils
        // différents selon qu'il ouvrait la cloche de l'accueil (2 types)
        // ou celle du profil (tout). Un seul écran pour les 3 rôles.
        ? const NotificationsScreen()
        : const NotificationsScreen();
    Get.to(() => target)?.then((_) => ctrl.refreshUnreadCount());
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    return GestureDetector(
      onTap: _open,
      behavior: HitTestBehavior.opaque,
      // v569 — DESIGN UNIQUEMENT : même destination, même compteur. Pastille
      // détachée du bord (liseré blanc 1,5 lisible sur l'en-tête coloré) et
      // bouton en carré arrondi 14 façon iOS.
      // v602 — pastille commune posée sur le coin haut-droit du bouton,
      // ancrée par la gauche (« 99+ » s'allonge vers l'extérieur).
      child: PawBadgeAnchor(
        iconWidth: 42.w,
        bite: 13,
        lift: 6,
        badge: Obx(() {
          final int count = ctrl.unreadCount.value;
          return PawCountBadge(count: count);
        }),
        child: Container(
        width: 42.w,
        height: 42.w,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        // v480 — maquette « Header v2 » : cloche en JAUNE doré (#FFCB2E)
        // sur les 3 rôles (ne plus hériter du blanc du texte).
        child: Icon(Icons.notifications_rounded,
            color: const Color(0xFFFFCB2E), size: 22.sp),
        ),
      ),
    );
  }
}
