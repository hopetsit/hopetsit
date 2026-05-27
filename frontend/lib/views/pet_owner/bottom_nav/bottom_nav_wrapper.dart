import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/views/pet_owner/booking/owner_bookings_screen.dart';
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
    // v18.9 — remplace ApplicationScreen (vue fusionnée apps+bookings) par
    // OwnerBookingsScreen alignée sur WalkerBookingsScreen / SitterBookingsScreen.
    // Daniel voulait le même design de réservations sur les 3 profils.
    OwnerBookingsScreen(), // 3 — Bookings
    ProfileScreen(),    // 4 — Profile
  ];

  @override
  void initState() {
    super.initState();

    if (!Get.isRegistered<NotificationsController>()) {
      Get.put(NotificationsController(), permanent: true);
    }

    // v21.1.1 — eager-register BookingsController : sinon la
    // HomeQuickActionBar du HomeScreen ne détecte aucun booking pending tant
    // que l'owner n'a pas visité l'onglet Réservations.
    if (!Get.isRegistered<BookingsController>()) {
      Get.put(BookingsController(), permanent: true);
    }

    // v23.1 part 240 — Daniel (3eme tentative) : root cause Personnes
    // en live + Me suivre brisees → LiveMapService.attach() etait JAMAIS
    // appele si user n'ouvrait pas PawMap. Resultat : map:identify
    // jamais emis cote backend → broadcast position no-op. Fix :
    // register le service au boot, son onInit() hook addOnConnectedHook
    // pour emettre map:identify a chaque (re)connect socket.
    if (!Get.isRegistered<LiveMapService>()) {
      Get.put(LiveMapService(), permanent: true);
    }

    // v23.1 part 242 — Daniel : "messages et demandes apparaissent
    // instantanement sans avoir a mettre a jour". Pour que les socket
    // listeners de ChatController + FriendController soient actifs DES
    // le boot (et pas seulement quand l'user ouvre l'ecran Chat ou
    // Friends), on register les 2 controllers en permanent ici. Du coup
    // les events friend_request:received / message:new bumpent l'UI
    // meme si l'user est sur Home / PawMap / autre tab.
    if (!Get.isRegistered<ChatController>()) {
      Get.put(
        ChatController(Get.find<ChatRepository>(), storage: Get.find<GetStorage>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<FriendController>()) {
      Get.put(FriendController(), permanent: true);
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
