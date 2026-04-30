import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/widgets/custom_navigation_bar.dart';

/// v23.1 part 21 — refactor RADICAL pour fixer définitivement le carré gris
/// gauche autour d'Accueil. Au lieu d'IndexedStack (qui peut leaker des
/// layouts d'écrans non-actifs), on rend UNIQUEMENT l'écran actif dans un
/// Stack avec un layer blanc absolu en arrière-plan.
///
///   Stack(fit: StackFit.expand)
///     - Container blanc plein-écran (Positioned.fill)
///     - Column [Expanded(visible screen), CustomNavigationBar]
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final whiteBg = isDark ? const Color(0xFF121212) : Colors.white;

    return Material(
      color: whiteBg,
      // Material 3 surface tint OFF — empêche tout overlay teinté.
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1) Layer blanc plein-écran — garantit qu'aucun pixel ne peut être
          //    gris derrière les autres widgets, même dans la safe area /
          //    gesture area de l'OS.
          Positioned.fill(
            child: ColoredBox(color: whiteBg),
          ),
          // 2) Contenu : UNIQUEMENT l'écran actif (pas d'IndexedStack qui peut
          //    leaker les layouts d'écrans inactifs) + nav bar.
          Column(
            children: [
              Expanded(
                child: ColoredBox(
                  color: whiteBg,
                  child: KeyedSubtree(
                    key: ValueKey<int>(_currentIndex),
                    child: widget.screens[_currentIndex],
                  ),
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
        ],
      ),
    );
  }
}
