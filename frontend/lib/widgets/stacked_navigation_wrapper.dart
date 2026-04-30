import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/custom_navigation_bar.dart';

/// v23.1 — refactor radical pour fixer le bug d'affichage persistant des
/// rectangles gris (top AppBar + bottom nav). Layout ultra-simple :
/// - Scaffold fond blanc (pas de grey qui peut percer)
/// - Column avec Expanded(screens) + CustomNavigationBar fixe en bas
/// - Pas de Stack, pas d'extendBody, pas de SafeArea sur le wrapper
/// - Chaque inner screen gère son propre SafeArea/AppBar
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBar(context), // blanc en light, surface en dark
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: widget.screens,
            ),
          ),
          CustomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
              if (index == 0) {
                _refreshNotificationBadge();
              }
              if (index == 1) {
                if (Get.isRegistered<ChatController>()) {
                  Get.find<ChatController>().reloadConversations();
                }
                if (Get.isRegistered<SitterChatController>()) {
                  Get.find<SitterChatController>().reloadConversations();
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
