import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/booking-application/sitter_application_screen.dart';
import 'package:hopetsit/views/pet_walker/home/walker_homescreen.dart';
import 'package:hopetsit/views/pet_walker/profile/walker_profile_screen.dart';
import 'package:hopetsit/widgets/stacked_navigation_wrapper.dart';

/// Walker bottom-navigation shell — mirrors SitterNavWrapper structure so
/// walkers get the same 5-tab layout (home, chat, map, bookings, profile).
/// Phase 1 reuses the existing sitter chat/map/bookings screens; dedicated
/// walker screens (e.g. walk sessions list, rate manager) will be introduced
/// in later sessions.
class WalkerNavWrapper extends StatefulWidget {
  const WalkerNavWrapper({super.key});

  @override
  State<WalkerNavWrapper> createState() => _WalkerNavWrapperState();
}

class _WalkerNavWrapperState extends State<WalkerNavWrapper> {
  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<NotificationsController>()) {
      Get.put(NotificationsController(), permanent: true);
    }
  }

  // Walker tabs reuse the same chat/map/bookings infrastructure as sitters
  // during Phase 1 — these features are cross-role. Profile and home are
  // walker-specific (green accent, walker-appropriate copy).
  final List<Widget> _screens = const [
    WalkerHomescreen(), // 0 — Home
    SitterChatScreen(), // 1 — Chat (shared)
    PawMapScreen(), // 2 — PawMap (shared) — POIs + Reports 48h + Amis live
    SitterApplicationScreen(), // 3 — Bookings (shared; to be forked later)
    WalkerProfileScreen(), // 4 — Profile
  ];

  @override
  Widget build(BuildContext context) {
    return StackedNavigationWrapper(screens: _screens);
  }
}
