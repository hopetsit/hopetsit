import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/views/pet_owner/booking-application/application_screen.dart';
import 'package:hopetsit/views/pet_owner/home/home_screen.dart';
import 'package:hopetsit/views/pet_owner/chat/chat_screen.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/profile/profile_screen.dart';
import 'package:hopetsit/widgets/stacked_navigation_wrapper.dart';
import 'package:hopetsit/controllers/home_controller.dart';

class BottomNavWrapper extends StatefulWidget {
  const BottomNavWrapper({super.key});

  @override
  State<BottomNavWrapper> createState() => _BottomNavWrapperState();
}

class _BottomNavWrapperState extends State<BottomNavWrapper> {
  final List<Widget> _screens = const [
    HomeScreen(),       // 0 — Home
    ChatScreen(),       // 1 — Chat
    PawMapScreen(),     // 2 — PawMap (center button) — POIs + Reports 48h + Amis live
    ApplicationScreen(),// 3 — Bookings
    ProfileScreen(),    // 4 — Profile
  ];

  @override
  void initState() {
    super.initState();

    if (!Get.isRegistered<NotificationsController>()) {
      Get.put(NotificationsController(), permanent: true);
    }

    // Ensure sitters refresh on every owner login.
    // HomeController may be permanent and survive logout/login.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!Get.isRegistered<HomeController>()) {
        Get.put(HomeController(), permanent: true);
      }
      await Get.find<HomeController>().loadSitters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StackedNavigationWrapper(screens: _screens);
  }
}
