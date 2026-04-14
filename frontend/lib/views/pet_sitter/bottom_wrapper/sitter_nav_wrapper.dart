import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/views/pet_sitter/home/sitter_homescreen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/booking-application/sitter_application_screen.dart';
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
    SitterHomescreen(),
    SitterChatScreen(),
    SitterApplicationScreen(),
    SitterProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return StackedNavigationWrapper(screens: _screens);
  }
}
