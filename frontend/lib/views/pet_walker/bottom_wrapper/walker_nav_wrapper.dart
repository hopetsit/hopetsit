import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/home/sitter_homescreen.dart';
import 'package:hopetsit/views/pet_walker/booking/walker_bookings_screen.dart';
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

  // Walker tabs reuse the same chat/map infrastructure as sitters during
  // Phase 1 — these features are cross-role. Profile and Bookings are
  // walker-specific since v17: the bookings tab now uses
  // WalkerBookingsScreen + WalkerBookingsController, which hits
  // GET /bookings/my with the walker's token and displays bookings the
  // owner has targeted at the walker (the sitter-only fork returned [] for
  // walker callers before v17b). Home still reuses SitterHomescreen so
  // walkers see the shared owner feed.
  final List<Widget> _screens = const [
    SitterHomescreen(), // 0 — Home (shared feed — shows owner announcements)
    SitterChatScreen(), // 1 — Chat (shared)
    PawMapScreen(), // 2 — PawMap (shared) — POIs + Reports 48h + Amis live
    WalkerBookingsScreen(), // 3 — Bookings (walker-specific since v17)
    WalkerProfileScreen(), // 4 — Profile
  ];

  @override
  Widget build(BuildContext context) {
    return StackedNavigationWrapper(screens: _screens);
  }
}
