import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
    // v23.1 — bug d'affichage : les écrans (home / Mes réservations) étaient
    // dessinés SOUS la barre de navigation à cause du Stack. On ajoute un
    // padding-bottom égal à la hauteur de la nav bar pour que le contenu
    // s'arrête au-dessus. Pill = 78h + 10h margin top + 10h margin bottom = 98h total.
    final double navBarHeight = 98.h;
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content — laisse de la place pour la nav bar.
            Padding(
              padding: EdgeInsets.only(bottom: navBarHeight),
              child: IndexedStack(
                index: _currentIndex,
                children: widget.screens,
              ),
            ),

            // Navigation bar positioned at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CustomNavigationBar(
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
            ),
          ],
        ),
      ),
    );
  }
}
