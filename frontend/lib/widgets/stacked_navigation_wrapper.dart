import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/utils/map_ui_state.dart';

/// v462 — NOUVEAU MENU (maquette Claude Design) appliqué AU VRAI wrapper de
/// navigation (celui réellement monté). Barre flottante blanche arrondie +
/// icônes duotone SVG + bouton central « Paw Map » en pilule orange surélevée.
///
/// ⚠️ Le widget `CustomNavigationBar` (lib/widgets/custom_navigation_bar.dart)
/// n'est PAS utilisé par l'app (code mort, supprimé du build par tree-shaking) :
/// c'est CE wrapper-ci qui dessine la barre du bas. Toute modif visuelle du
/// menu doit se faire ICI.
///
/// Logique 100% préservée : IndexedStack des écrans, onTap (setState +
/// refresh notif onglet Accueil + reload conversations onglet Chat + resync
/// badge chat serveur), badge non-lus Chat (rouge, unreadChat) + badge
/// « action requise » Réservations (vert, pendingActionCount role-aware).
const Color _kAccent = Color(0xFFF2741B);
const Color _kAccentDark = Color(0xFFE0660F);
const Color _kInactive = Color(0xFF7D7D82);

class StackedNavigationWrapper extends StatefulWidget {
  final List<Widget> screens;

  const StackedNavigationWrapper({super.key, required this.screens});

  @override
  State<StackedNavigationWrapper> createState() =>
      _StackedNavigationWrapperState();
}

class _StackedNavigationWrapperState extends State<StackedNavigationWrapper> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshNotificationBadge();
    });
  }

  void _refreshNotificationBadge() {
    if (!Get.isRegistered<NotificationsController>()) return;
    Get.find<NotificationsController>().refreshUnreadCount();
  }

  /// Nombre de réservations en attente d'action (owner : à confirmer ;
  /// prestataire : à démarrer/terminer). Role-aware.
  int _bookingsBadgeCount() {
    final role = Get.isRegistered<AuthController>()
        ? (Get.find<AuthController>().userRole.value ?? 'owner').toLowerCase()
        : 'owner';
    try {
      if (role == 'sitter' && Get.isRegistered<SitterBookingsController>()) {
        return Get.find<SitterBookingsController>().pendingActionCount;
      }
      if (role == 'walker' && Get.isRegistered<WalkerBookingsController>()) {
        return Get.find<WalkerBookingsController>().pendingActionCount;
      }
      if (Get.isRegistered<BookingsController>()) {
        return Get.find<BookingsController>().pendingActionCount;
      }
    } catch (_) {/* defensive */}
    return 0;
  }

  void _onTap(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) _refreshNotificationBadge();
    if (index == 1) {
      if (Get.isRegistered<ChatController>()) {
        Get.find<ChatController>().reloadConversations();
      }
      if (Get.isRegistered<SitterChatController>()) {
        Get.find<SitterChatController>().reloadConversations();
      }
      // v448 — resync sur le VRAI total serveur (ne pas forcer 0 localement).
      if (Get.isRegistered<NotificationsController>()) {
        Get.find<NotificationsController>().syncChatBadgeFromServer();
      }
    }
  }

  // ── Icônes duotone (SVG injecté selon actif/inactif) ──
  String _hex(bool a) => a ? '#F2741B' : '#7D7D82';
  String _lite(bool a) => a ? '#F2741B26' : '#7D7D8222';

  String _pawSvg(bool a) {
    final f = _hex(a);
    return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="$f">
<ellipse cx="6.4" cy="10.6" rx="2" ry="2.6"/><ellipse cx="10.3" cy="7.2" rx="2" ry="2.7"/>
<ellipse cx="14.7" cy="7.2" rx="2" ry="2.7"/><ellipse cx="18.6" cy="10.6" rx="2" ry="2.6"/>
<path d="M12.5 12c-2.6 0-4.8 1.9-5.5 4.1-.5 1.7.4 3.3 2.2 3.6 1 .2 1.8-.3 2.7-.5.4-.1.8-.1 1.2 0 .9.2 1.7.7 2.7.5 1.8-.3 2.7-1.9 2.2-3.6-.7-2.2-2.9-4.1-5.5-4.1Z"/></svg>''';
  }

  String _chatSvg(bool a) {
    final s = _hex(a);
    final l = _lite(a);
    return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$s" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">
<path d="M12.2 4C7.4 4 3.6 7 3.6 11c0 1.7.7 3.2 1.8 4.4L4 19.7l4.5-1.4c1.1.4 2.4.6 3.7.6 4.8 0 8.6-3 8.6-7s-3.8-7-8.6-7.9Z" fill="$l" stroke="none"/>
<path d="M12.2 4C7.4 4 3.6 7 3.6 11c0 1.7.7 3.2 1.8 4.4L4 19.7l4.5-1.4c1.1.4 2.4.6 3.7.6 4.8 0 8.6-3 8.6-7S17 4 12.2 4Z"/>
<circle cx="8.9" cy="11.2" r="1" fill="$s" stroke="none"/><circle cx="12.3" cy="11.2" r="1" fill="$s" stroke="none"/><circle cx="15.7" cy="11.2" r="1" fill="$s" stroke="none"/></svg>''';
  }

  String _calSvg(bool a) {
    final s = _hex(a);
    final l = _lite(a);
    return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
<rect x="3.4" y="4.8" width="17.2" height="15.8" rx="4.2" fill="$l" stroke="none"/>
<rect x="3.4" y="4.8" width="17.2" height="15.8" rx="4.2"/>
<path d="M3.5 9.4h17" stroke-width="1.9"/><path d="M7.8 3v3.4M16.2 3v3.4"/>
<circle cx="8.3" cy="13.4" r="1.1" fill="$s" stroke="none"/><circle cx="12" cy="13.4" r="1.1" fill="$s" stroke="none"/><circle cx="15.7" cy="13.4" r="1.1" fill="$s" stroke="none"/>
<circle cx="8.3" cy="16.9" r="1.1" fill="$s" stroke="none"/><circle cx="12" cy="16.9" r="1.1" fill="$s" stroke="none"/></svg>''';
  }

  String _userSvg(bool a) {
    final s = _hex(a);
    final l = _lite(a);
    return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
<path d="M12 13.4c-4 0-7.2 2.6-7.2 6.6 0 .4.3.6.7.6h13c.4 0 .7-.2.7-.6 0-4-3.2-6.6-7.2-6.6Z" fill="$l" stroke="none"/>
<circle cx="12" cy="8" r="3.8" fill="$l"/><circle cx="12" cy="8" r="3.8"/>
<path d="M4.8 20.2c0-4 3.2-6.6 7.2-6.6s7.2 2.6 7.2 6.6"/></svg>''';
  }

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
    // v465 — Daniel : « le menu doit être collé au menu Samsung ». On lit
    // l'inset PHYSIQUE (viewPadding, fiable même en navigation gestuelle) et on
    // colle le menu juste au-dessus de la barre système (plus de bande de
    // sécurité colorée v464). Le menu clearance exactement l'inset → il n'est
    // ni recouvert par la barre Samsung, ni espacé inutilement.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: widget.screens,
      ),
      // v465 — en mode « carte agrandie » (PawMap), on MASQUE le menu pour que
      // la carte soit plein écran et que Signaler / Tag Spot / les bandeaux de
      // validation ne soient plus cachés derrière le menu.
      bottomNavigationBar: Obx(() => pawMapExpanded.value
          ? const SizedBox.shrink()
          // v467 — Daniel : « la barre de menu Paw Map bien horizontale de bout
          // en bout ». Plus de pilule flottante à marges : barre PLEINE LARGEUR
          // collée au bas, coins arrondis EN HAUT seulement, l'inset Samsung est
          // ajouté EN PADDING BAS (les icônes restent au-dessus de la barre
          // système).
          : Container(
        padding: EdgeInsets.only(
          left: 10,
          right: 10,
          top: 8,
          bottom: 8 + bottomInset,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14141E).withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
            BoxShadow(
              color: const Color(0xFF14141E).withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
            children: [
              _navTab(0, _pawSvg, 'nav_home'.tr),
              _navTab(1, _chatSvg, 'nav_chat'.tr, badge: _chatBadge),
              _centerTab(),
              _navTab(3, _calSvg, 'nav_bookings'.tr, badge: _bookingsBadge),
              _navTab(4, _userSvg, 'nav_profile'.tr),
            ],
          ),
        ),
        ),
    );
  }

  Widget _navTab(int index, String Function(bool) svg, String label,
      {Widget Function()? badge}) {
    final active = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTap(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.string(svg(active), width: 26, height: 26),
                if (badge != null)
                  Positioned(top: -5, right: -7, child: badge()),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? _kAccent : _kInactive,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Badge ROUGE non-lus Chat (unreadChat).
  Widget _chatBadge() {
    if (!Get.isRegistered<NotificationsController>()) {
      return const SizedBox.shrink();
    }
    return Obx(() {
      final n = Get.find<NotificationsController>().unreadChat.value;
      if (n <= 0) return const SizedBox.shrink();
      return _pill(n > 9 ? '9+' : n.toString(), const Color(0xFFEF4324));
    });
  }

  /// Badge VERT « action requise » Réservations (pendingActionCount).
  Widget _bookingsBadge() {
    return Obx(() {
      final n = _bookingsBadgeCount();
      if (n <= 0) return const SizedBox.shrink();
      return _pill(n > 9 ? '9+' : n.toString(), const Color(0xFF16A34A));
    });
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }

  /// Bouton central « Paw Map » : pilule ORANGE surélevée + icône carte+pin+patte.
  Widget _centerTab() {
    final active = _currentIndex == 2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTap(2),
      child: AnimatedScale(
        scale: active ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 160),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kAccent, _kAccentDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: _kAccent.withValues(alpha: 0.40),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.string(_centreSvg, width: 30, height: 30),
              const SizedBox(height: 3),
              const Text(
                'Paw Map',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
