// v566 — écran « Amis » découpé par onglet (views/friends/tabs/) et modernisé
// (style Apple / Paw Buttons, couleur du rôle courant). 4 onglets :
//   1. Mes amis  → tabs/my_friends_tab.dart
//   2. Demandes  → tabs/requests_tab.dart   (compteur sur l'onglet)
//   3. Ajouter   → tabs/add_friend_tab.dart (recherche, lien, QR, partage)
//   4. Famille   → tabs/family_tab.dart     (PawFollow Famille, violet)
// Briques communes : tabs/friends_ui.dart. Onglets historiques non câblés
// (Animaux, Messages) : tabs/legacy_tabs.dart.
//
// Historique des décisions (conservé) :
//   v23.1.185  5 onglets (mockup Daniel) · v205 onglet Demandes dédié + badge
//   v210       Famille et « Personnes en live » séparés
//   v225       « Personnes en live » devient PeopleLiveScreen (carte rapide
//              PawMap) ; Animaux retiré (doublon du halo PawMap)
//   v244       Messages retiré (doublon de l'onglet Chat) → 4 onglets
//   v274       icône diagnostic retirée (controller.diagnose() reste dispo)
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/friends/blocked_users_screen.dart';
import 'package:hopetsit/views/friends/tabs/add_friend_tab.dart';
import 'package:hopetsit/views/friends/tabs/family_tab.dart';
import 'package:hopetsit/views/friends/tabs/friends_ui.dart';
import 'package:hopetsit/views/friends/tabs/my_friends_tab.dart';
import 'package:hopetsit/views/friends/tabs/pending_banner.dart';
import 'package:hopetsit/views/friends/tabs/requests_tab.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

class FriendsScreen extends StatefulWidget {
  // v23.1 part 223 — `initialIndex` ouvre directement un onglet (liens
  // profonds : 1 = Demandes, 3 = Famille).
  const FriendsScreen({super.key, this.initialIndex = 0});
  final int initialIndex;

  static const int tabFriends = 0;
  static const int tabRequests = 1;
  static const int tabAdd = 2;
  static const int tabFamily = 3;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final FriendController controller;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<FriendController>()
        ? Get.find<FriendController>()
        : Get.put(FriendController());
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialIndex.clamp(0, 3),
    );
    // v23.1.172 — la famille est préchargée à l'ouverture. v566 — et la liste
    // est rafraîchie (présence, demandes) quand le contrôleur existait déjà.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadFamily();
      if (!controller.isLoading.value) controller.refresh();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _goTo(int index) => _tabs.animateTo(index);

  @override
  Widget build(BuildContext context) {
    final accent = currentRoleAccent();
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.scaffold(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: accent),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20.sp, color: accent),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: PoppinsText(
          text: 'friends_screen_title'.tr,
          fontSize: 17.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // v23.1.174 — accès à la liste des bloqués.
          IconButton(
            icon: Icon(Icons.block_rounded,
                color: AppColors.textSecondary(context), size: 21.sp),
            tooltip: 'friend_blocked_list'.tr,
            onPressed: () => Get.to(() => const BlockedUsersScreen()),
          ),
          // v23.1.170 — partage natif du lien d'invitation (id + rôle, v546).
          IconButton(
            icon: Icon(Icons.ios_share_rounded, color: accent, size: 21.sp),
            tooltip: 'friends_invite_link_tooltip'.tr,
            onPressed: shareFriendsInvite,
          ),
          SizedBox(width: 4.w),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          // v23.1 part 212 — onglets centrés.
          tabAlignment: TabAlignment.center,
          labelColor: accent,
          unselectedLabelColor: AppColors.textSecondary(context),
          indicatorColor: accent,
          indicatorWeight: 2.6,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: AppColors.divider(context),
          labelPadding: EdgeInsets.symmetric(horizontal: 14.w),
          labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
          tabs: [
            Tab(height: 42.h, text: 'friends_tab_friends'.tr),
            // v23.1 part 205 — compteur des demandes REÇUES sur l'onglet
            // (amis + invitations Famille).
            Tab(
              height: 42.h,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('friends_tab_requests'.tr),
                  Obx(() {
                    final n = controller.incomingRequests.length +
                        controller.incomingFamilyInvitations.length;
                    if (n == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.only(left: 6.w),
                      child: FriendsCountDot(
                        count: n,
                        color: const Color(0xFFE11D48),
                      ),
                    );
                  }),
                ],
              ),
            ),
            Tab(height: 42.h, text: 'friends_tab_add'.tr),
            Tab(height: 42.h, text: 'friends_tab_family'.tr),
          ],
        ),
      ),
      body: Column(
        children: [
          PendingRequestsBanner(
            controller: controller,
            accent: accent,
            tabController: _tabs,
            requestsTabIndex: FriendsScreen.tabRequests,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                MyFriendsTab(
                  controller: controller,
                  accent: accent,
                  onInvite: () => _goTo(FriendsScreen.tabAdd),
                ),
                RequestsTab(
                  controller: controller,
                  accent: accent,
                  onAdd: () => _goTo(FriendsScreen.tabAdd),
                ),
                AddFriendTab(
                  controller: controller,
                  accent: accent,
                  onOpenRequests: () => _goTo(FriendsScreen.tabRequests),
                ),
                FamilyTab(controller: controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
