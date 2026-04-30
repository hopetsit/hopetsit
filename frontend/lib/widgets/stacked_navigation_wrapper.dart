import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/custom_navigation_bar.dart';

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
    // Badge should reflect server count as soon as the shell is shown (home tab).
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
    // v23.1 — refactor majeur : on retire le SafeArea du wrapper (chaque
    // écran a son propre Scaffold qui gère son SafeArea automatiquement),
    // et on utilise bottomNavigationBar du Scaffold OUTER pour que la nav
    // soit gérée nativement par Flutter. Ça résout le bug de "grey rectangle"
    // qui venait du SafeArea wrappant le Stack et créant des contraintes
    // bizarres sur l'AppBar des écrans inner.
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: widget.screens,
      ),
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });

          // Home tab: refresh unread badge whenever user lands here.
          if (index == 0) {
            _refreshNotificationBadge();
          }

          // When switching to the Chat tab (index 1), reload conversations.
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
    );
  }
}
