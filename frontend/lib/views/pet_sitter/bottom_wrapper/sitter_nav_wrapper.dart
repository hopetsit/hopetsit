import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/views/pet_sitter/home/sitter_homescreen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_chat_screen.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/pet_sitter/booking/sitter_bookings_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/sitter_profile_screen.dart';
import 'package:hopetsit/widgets/stacked_navigation_wrapper.dart';

class SitterNavWrapper extends StatefulWidget {
  const SitterNavWrapper({super.key});

  @override
  State<SitterNavWrapper> createState() => _SitterNavWrapperState();
}

class _SitterNavWrapperState extends State<SitterNavWrapper> {
  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<NotificationsController>()) {
      Get.put(NotificationsController(), permanent: true);
    }
  }

  final List<Widget> _screens = const [
    SitterHomescreen(),          // 0 — Home
    SitterChatScreen(),          // 1 — Chat
    PawMapScreen(),              // 2 — PawMap (center button) — POIs + Reports 48h + Amis live
    // v18.9 — Réservations sitter aligné sur le design walker/owner
    // (cartes compactes + filter chips + accent BLEU sitter).
    SitterBookingsScreen(),      // 3 — Bookings
    SitterProfileScreen(),       // 4 — Profile
  ];

  @override
  Widget build(BuildContext context) {
    return StackedNavigationWrapper(screens: _screens);
  }
}
