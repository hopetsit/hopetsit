import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
// v565 — pop-up promo discret (docs/v565_contracts.md §9), monté une fois ici.
import 'package:hopetsit/widgets/promo_code_sheet.dart';
// v570 — rendu de la barre (handoff hi-fi « PawMap Tab Bar » variante 12d).
import 'package:hopetsit/widgets/paw_tab_bar.dart';

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
/// v570 — le dessin de la barre vit dans `paw_tab_bar.dart` (variante 12d du
/// handoff). Les COULEURS PAR RÔLE sont dans `kPawTabBarPalettes` : c'est le
/// seul endroit à changer pour retoucher owner / sitter / walker.

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

  /// Rôle courant → jeu de couleurs de la barre.
  PawNavRole _navRole() {
    final role = Get.isRegistered<AuthController>()
        ? (Get.find<AuthController>().userRole.value ?? 'owner').toLowerCase()
        : 'owner';
    if (role == 'sitter') return PawNavRole.sitter;
    if (role == 'walker') return PawNavRole.walker;
    return PawNavRole.owner;
  }

  @override
  Widget build(BuildContext context) {
    // v465 — Daniel : « le menu doit être collé au menu Samsung ». On lit
    // l'inset PHYSIQUE (viewPadding, fiable même en navigation gestuelle) et on
    // colle le menu juste au-dessus de la barre système.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final role = _navRole();
    // v570 — la barre mesure `pawTabBarTotalHeight` (saillie de la patte
    // comprise, pour qu'elle reste cliquable), mais on n'annonce aux écrans
    // que la hauteur UTILE (haut de la pilule) : sinon chaque liste gagnerait
    // ~58 px de vide et les FAB remonteraient d'autant.
    final usefulInset = pawTabBarUsefulHeight(bottomInset);
    // v469 — Daniel : barre système Samsung teintée par RÔLE. Le wrapper se
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
        body: Stack(
          children: [
            // Le Scaffold annonce au body la hauteur TOTALE de la barre
            // (patte comprise) ; on la ramène à la hauteur utile pour les
            // écrans-onglets, qui la lisent via `appBottomInset()`.
            Builder(
              builder: (ctx) {
                final mq = MediaQuery.of(ctx);
                return MediaQuery(
                  data: mq.copyWith(
                    padding: mq.padding.copyWith(
                      bottom: mq.padding.bottom > usefulInset
                          ? usefulInset
                          : mq.padding.bottom,
                    ),
                  ),
                  child: IndexedStack(
                    index: _currentIndex,
                    children: widget.screens,
                  ),
                );
              },
            ),
            // v565 — pop-up promo (une fois, jamais à la 1re ouverture). Elle
            // reste HORS de l'override : elle est centrée en bas et doit donc
            // dégager la patte entière (hauteur totale).
            const PromoPopup(),
          ],
        ),
        // v465 — en mode « carte agrandie » (PawMap), on MASQUE le menu pour
        // que la carte soit plein écran.
        bottomNavigationBar: Obx(
          () => pawMapExpanded.value
              ? const SizedBox.shrink()
              // v570 — barre « PawMap » variante 12d (handoff hi-fi).
              : PawTabBar(
                  currentIndex: _currentIndex,
                  onTap: _onTap,
                  role: role,
                  systemInset: bottomInset,
                  labels: [
                    'nav_home'.tr,
                    'nav_chat'.tr,
                    'nav_pawmap'.tr,
                    'nav_bookings'.tr,
                    'nav_profile'.tr,
                  ],
                  badges: {
                    1: (_) => _chatBadge(role),
                    3: (_) => _bookingsBadge(role),
                  },
                ),
        ),
      ),
    );
  }

  /// Badge non-lus Chat (unreadChat).
  Widget _chatBadge(PawNavRole role) {
    if (!Get.isRegistered<NotificationsController>()) {
      return const SizedBox.shrink();
    }
    return Obx(() {
      final n = Get.find<NotificationsController>().unreadChat.value;
      if (n <= 0) return const SizedBox.shrink();
      return _pill(n > 9 ? '9+' : n.toString(), role);
    });
  }

  /// Badge « action requise » Réservations (pendingActionCount).
  Widget _bookingsBadge(PawNavRole role) {
    return Obx(() {
      final n = _bookingsBadgeCount();
      if (n <= 0) return const SizedBox.shrink();
      return _pill(n > 9 ? '9+' : n.toString(), role);
    });
  }

  /// v570 — la barre est désormais COLORÉE : une pastille rouge dessus ne se
  /// lirait plus. Fond blanc, chiffre à la couleur du rôle, liseré sombre +
  /// ombre pour la détacher du dégradé.
  Widget _pill(String label, PawNavRole role) {
    final palette =
        kPawTabBarPalettes[role] ?? kPawTabBarPalettes[PawNavRole.owner]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.bottom, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14141E).withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: palette.bottom,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}
