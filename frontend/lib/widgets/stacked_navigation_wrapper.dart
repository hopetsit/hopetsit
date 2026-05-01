import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/custom_navigation_bar.dart';

/// v23.1 part 28 — wrapper accompagnant la nav bar HomeHeader-style.
/// extendBody: false → la zone derrière la nav est PAINTÉE par le wrapper
/// Scaffold (blanc), pas par les inner Scaffolds. Plus aucun risque de
/// scaffoldLight (#F7F7F8) qui transparait derrière.
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
    final whiteBg = AppColors.appBar(context);
    return Scaffold(
      backgroundColor: whiteBg,
      // extendBody: false → la nav bar a son propre layer blanc opaque,
      // le body inner Scaffold s'arrête au-dessus de la nav. Plus aucune
      // chance qu'un grey leak depuis derrière.
      extendBody: false,
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
