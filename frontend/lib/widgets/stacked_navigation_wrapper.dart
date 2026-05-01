import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/custom_navigation_bar.dart';

/// v23.1 part 27 — REVERT au wrapper qui marchait. Scaffold avec
/// bottomNavigationBar slot (Flutter gère l'inset/safe area nativement),
/// extendBody: true pour que la pill flottante puisse déborder au-dessus
/// du contenu. Pas de Stack/Material custom qui pouvait peindre des zones
/// hors de la pill et créer des artefacts gris.
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
      backgroundColor: AppColors.appBar(context),
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
    );
  }
}
