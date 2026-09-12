import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/services/app_update_service.dart';

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
const Color _kAccent = Color(0xFFD83C28); // v559 — orange de l'icône (Daniel)
// ignore: unused_element
const Color _kAccentDark = Color(0xFFB92425);
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
  Worker? _tabRequestWorker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshNotificationBadge();
      // v561 — mise à jour de l'app (Play In-App Updates / feuille App Store),
      // vérifiée une fois par lancement, après que le menu est affiché.
      Future.delayed(const Duration(seconds: 3), AppUpdateService.checkOnce);
    });
    // v559 — un autre écran demande un onglet (ex. PawMap avec itinéraire).
    navWrapperMounted.value = true;
    _tabRequestWorker = ever<int>(requestedTab, (i) {
      if (i < 0 || !mounted) return;
      requestedTab.value = -1;
      if (i < widget.screens.length) _onTap(i);
    });
  }

  @override
  void dispose() {
    _tabRequestWorker?.dispose();
    navWrapperMounted.value = false;
    super.dispose();
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
  String _hex(bool a) => a ? '#D83C28' : '#7D7D82';
  String _lite(bool a) => a ? '#D83C2826' : '#7D7D8222';

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
<path d="M7.5 9.2v11.6M20.5 9.2v11.6" stroke="#D83C28" stroke-width="1" opacity="0.3" stroke-linecap="round"/>
<path d="M14 2c-3.4 0-6.1 2.6-6.1 6 0 4.2 6.1 10.2 6.1 10.2S20.1 12.2 20.1 8c0-3.4-2.7-6-6.1-6Z" fill="#fff" stroke="#D83C28" stroke-width="1.1"/>
<ellipse cx="11.4" cy="6.4" rx="0.95" ry="1.2" fill="#D83C28"/><ellipse cx="14" cy="5.5" rx="0.95" ry="1.2" fill="#D83C28"/><ellipse cx="16.6" cy="6.4" rx="0.95" ry="1.2" fill="#D83C28"/>
<path d="M14 7.7c-1.5 0-2.7 1-3.1 2.2-.3.9.2 1.8 1.1 2 .5.1 1-.1 1.4-.2.4-.1.7-.1 1.1 0 .5.1.9.3 1.4.2.9-.2 1.4-1.1 1.1-2-.4-1.2-1.6-2.2-3-2.2Z" fill="#D83C28"/></svg>''';

  @override
  Widget build(BuildContext context) {
    // v465 — Daniel : « le menu doit être collé au menu Samsung ». On lit
    // l'inset PHYSIQUE (viewPadding, fiable même en navigation gestuelle) et on
    // colle le menu juste au-dessus de la barre système (plus de bande de
    // sécurité colorée v464). Le menu clearance exactement l'inset → il n'est
    // ni recouvert par la barre Samsung, ni espacé inutilement.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    // v469 — Daniel : barre système Samsung teintée par RÔLE (owner orange pâle
    // / sitter bleu pâle / walker vert pâle) au lieu du gris. Le wrapper se
    // rebuild au changement d'onglet → la couleur suit le rôle courant.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.scaffoldLightForRole(),
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: true,
      ),
      child: Scaffold(
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
          // v561 — Daniel : « le menu un peu plus HD, bulle moderne ». Pilule
          // flottante (marges 10, coins 28), fond blanc, liseré très léger,
          // ombre douce ; onglet actif = icône dans une bulle teintée ; bulle
          // PawMap centrale ronde, surélevée, avec lueur orange. Hauteur utile
          // identique (58 + inset) → les marges de la PawMap sont conservées.
          : Container(
        margin: EdgeInsets.only(
          left: 10,
          right: 10,
          bottom: 6 + bottomInset,
        ),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0x0F14141E), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14141E).withValues(alpha: 0.14),
              blurRadius: 26,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFF14141E).withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 46,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? _kAccent.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SvgPicture.string(svg(active), width: 24, height: 24),
                  if (badge != null)
                    Positioned(top: -6, right: -8, child: badge()),
                ],
              ),
            ),
            const SizedBox(height: 3),
            // Daniel (12/09) : « Réservations » ne doit jamais être coupé →
            // le libellé se réduit pour tenir plutôt que d'être tronqué.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.2,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? _kAccent : _kInactive,
                  ),
                ),
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
      return _pill(n > 9 ? '9+' : n.toString(), const Color(0xFFC92A12));
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

  /// Bouton central « PawMap » : bulle orange surélevée, rectangle arrondi (dégradé +
  /// lueur + anneau blanc), icône carte+pin+patte et libellé dedans.
  Widget _centerTab() {
    final active = _currentIndex == 2;
    // Largeur = bouton (72) + 3 px de chaque côté : les onglets voisins
    // gardent leur libellé entier (« Réservations » n'est plus tronqué).
    return SizedBox(
      width: 78,
      height: 46,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTap(2),
        child: OverflowBox(
          maxHeight: 92,
          alignment: Alignment.center,
          // Daniel (12/09, 4e retour) : « doit dépasser un peu en haut du menu
          // et un peu en bas » → 72×66 centré sur la barre (46) : ~10 px de
          // dépassement de chaque côté.
          child: Transform.translate(
            offset: const Offset(0, 0),
            child: AnimatedScale(
              scale: active ? 1.06 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: Container(
                width: 72,
                height: 66,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  // Daniel (12/09) : « dégradé horizontal ».
                  // Dégradé HORIZONTAL franc (gauche clair → droite foncé).
                  // Daniel (12/09, 5e retour) : « j'aime pas le dégradé » →
                  // orange de l'app UNI (#D83C28, celui de l'icône), sans
                  // dégradé.
                  color: _kAccent,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _kAccent.withValues(alpha: active ? 0.55 : 0.40),
                      blurRadius: active ? 22 : 16,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFF14141E).withValues(alpha: 0.10),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.string(_centreSvg, width: 27, height: 27),
                    const SizedBox(height: 1),
                    Text(
                      'nav_pawmap'.tr,
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: 0.1,
                      ),
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
