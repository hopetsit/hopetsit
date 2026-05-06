import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
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
              // v23.1 part 63 — Bug H : reset the chat unread badge when
              // the user opens the chat tab. The counter will get bumped
              // again on the next incoming message via the socket listener.
              if (Get.isRegistered<NotificationsController>()) {
                Get.find<NotificationsController>().unreadChat.value = 0;
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
              icon: Image.asset(
                AppImages.calendarIcon,
                width: 22,
                height: 22,
                color: _currentIndex == 3 ? activeColor : const Color(0xFF9E9E9E),
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
