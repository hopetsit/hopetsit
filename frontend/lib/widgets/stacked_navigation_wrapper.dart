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
              icon: Image.asset(
                AppImages.chatIcon,
                width: 22,
                height: 22,
                color: _currentIndex == 1 ? activeColor : const Color(0xFF9E9E9E),
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
