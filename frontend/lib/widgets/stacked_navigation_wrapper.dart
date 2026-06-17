import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';

/// v23.1 part 33 — TENTATIVE COMPLÈTEMENT NOUVELLE : utilise BottomNavigationBar
/// natif Flutter au lieu de notre CustomNavigationBar custom. Si le bug du
/// rectangle gris vient de notre widget custom, le natif l'éliminera.
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

  Color _activeColor() {
    final role = Get.isRegistered<AuthController>()
        ? (Get.find<AuthController>().userRole.value ?? 'owner').toLowerCase()
        : 'owner';
    if (role == 'walker') return const Color(0xFF16A34A);
    if (role == 'sitter') return const Color(0xFF2563EB);
    return AppColors.primaryColor;
  }

  /// v23.1.266 — Daniel : "un petit badge stylé pour la demande de
  /// confirmation". Nombre de réservations en attente de l'action de
  /// l'utilisateur (owner : à confirmer ; prestataire : à démarrer/terminer).
  /// Role-aware : lit le bon contrôleur de réservations.
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

  @override
  Widget build(BuildContext context) {
    final activeColor = _activeColor();
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: widget.screens,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          // v23.1 part 33 — kill toute Material 3 highlight Indicator que
          // Flutter pourrait injecter automatiquement.
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: activeColor,
          unselectedItemColor: const Color(0xFF9E9E9E),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 8,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 0) _refreshNotificationBadge();
            if (index == 1) {
              if (Get.isRegistered<ChatController>()) {
                Get.find<ChatController>().reloadConversations();
              }
              if (Get.isRegistered<SitterChatController>()) {
                Get.find<SitterChatController>().reloadConversations();
              }
              // v448 — AUDIT MESSAGERIE : NE PLUS forcer le badge à 0 ici.
              // Mettre 0 localement alors que le serveur garde des conversations
              // non lues = le badge « revient » au prochain resync/reconnexion.
              // On resynchronise sur le VRAI total serveur (le badge ne descend
              // que lorsque les conversations sont réellement ouvertes/lues).
              // Aligné sur custom_navigation_bar.dart (fix v444).
              if (Get.isRegistered<NotificationsController>()) {
                Get.find<NotificationsController>().syncChatBadgeFromServer();
              }
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: Image.asset(
                AppImages.pawIcon,
                width: 22,
                height: 22,
                color: _currentIndex == 0 ? activeColor : const Color(0xFF9E9E9E),
              ),
              label: 'nav_home'.tr,
            ),
            BottomNavigationBarItem(
              // v23.1 part 63 — Bug H : red unread-chat badge on the chat
              // tab icon. Reads NotificationsController.unreadChat (RxInt)
              // which is bumped by chat_controller's "message:new" socket
              // listener. The Obx auto-rebuilds when the counter changes.
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Image.asset(
                    AppImages.chatIcon,
                    width: 22,
                    height: 22,
                    color: _currentIndex == 1
                        ? activeColor
                        : const Color(0xFF9E9E9E),
                  ),
                  if (Get.isRegistered<NotificationsController>())
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Obx(() {
                        final n = Get.find<NotificationsController>()
                            .unreadChat
                            .value;
                        if (n <= 0) return const SizedBox.shrink();
                        final label = n > 9 ? '9+' : n.toString();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          constraints: const BoxConstraints(
                              minWidth: 16, minHeight: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4324),
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
                      }),
                    ),
                ],
              ),
              label: 'nav_chat'.tr,
            ),
            BottomNavigationBarItem(
              icon: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.map_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              // v23.1.266 — badge vert "action requise" (confirmer / démarrer /
              // terminer un service) sur l'onglet Réservations.
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Image.asset(
                    AppImages.calendarIcon,
                    width: 22,
                    height: 22,
                    color: _currentIndex == 3
                        ? activeColor
                        : const Color(0xFF9E9E9E),
                  ),
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Obx(() {
                      final n = _bookingsBadgeCount();
                      if (n <= 0) return const SizedBox.shrink();
                      final label = n > 9 ? '9+' : n.toString();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        constraints: const BoxConstraints(
                            minWidth: 16, minHeight: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
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
                    }),
                  ),
                ],
              ),
              label: 'nav_bookings'.tr,
            ),
            BottomNavigationBarItem(
              icon: Image.asset(
                AppImages.personIcon,
                width: 22,
                height: 22,
                color: _currentIndex == 4 ? activeColor : const Color(0xFF9E9E9E),
              ),
              label: 'nav_profile'.tr,
            ),
          ],
        ),
      ),
    );
  }
}
