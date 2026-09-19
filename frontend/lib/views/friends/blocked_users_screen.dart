// v23.1.174 — Daniel : « Manque boutons Bloquer et Supprimer dans la liste
// d'amis […] Liste des bloqués accessible via paramètres ».
// v566 — sous-page modernisée (kit Profil + cartes Amis) : états chargement /
// vide / erreur + Réessayer, confirmation avant de débloquer, chargement par
// ligne, retrait immédiat sans recharger.
//
// Routes : GET /blocks (liste), DELETE /blocks { targetUserId, targetRole }
// (déblocage — voir FriendController.unblockUser pour le pourquoi du corps).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/friends/tabs/friends_ui.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late final FriendController controller;
  final RxSet<String> _busy = <String>{}.obs;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<FriendController>()
        ? Get.find<FriendController>()
        : Get.put(FriendController());
    // Rafraîchit la liste à l'ouverture.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadBlocked();
    });
  }

  Future<void> _unblock({
    required String userId,
    required String role,
    required String name,
    required Color accent,
  }) async {
    final confirmed = await confirmFriendsAction(
      context,
      title: 'friends566_unblock_title'.trParams({'name': name}),
      message: 'friends566_unblock_desc'.tr,
      confirmLabel: 'friend_unblock'.tr,
      accent: accent,
      icon: Icons.lock_open_rounded,
    );
    if (!confirmed) return;
    _busy.add(userId);
    final ok = await controller.unblockUser(userId, targetRole: role);
    _busy.remove(userId);
    if (ok) {
      CustomSnackbar.showSuccess(
        title: 'friend_unblocked_title'.tr,
        message: 'friend_unblocked_msg'.trParams({'name': name}),
      );
    } else {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'friend_unblock_failed'.tr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = currentRoleAccent();
    return ProfileSubPageScaffold(
      title: 'friend_blocked_list'.tr,
      accent: accent,
      scroll: false,
      body: RefreshIndicator(
        color: accent,
        onRefresh: controller.loadBlocked,
        child: Obx(() {
          final blocked = controller.blockedUsers.toList();
          // ignore: unused_local_variable
          final busyTick = _busy.length;
          if (controller.isLoadingBlocked.value && blocked.isEmpty) {
            return const FriendsSkeletonList(count: 3);
          }
          if (controller.blockedLoadFailed.value && blocked.isEmpty) {
            return FriendsStateView.loadError(
              accent: accent,
              onRetry: controller.loadBlocked,
            );
          }
          if (blocked.isEmpty) {
            return FriendsStateView(
              icon: Icons.verified_user_rounded,
              title: 'friend_blocked_empty'.tr,
              message: 'friends566_blocked_empty_msg'.tr,
              accent: accent,
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w,
                24.h + appBottomInsetInsideSafeArea(context)),
            children: [
              ProfileInfoBanner(
                icon: Icons.info_outline_rounded,
                text: 'friends566_blocked_info'.tr,
                accent: accent,
              ),
              SizedBox(height: 14.h),
              for (final b in blocked) _buildCard(context, b, accent),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCard(
      BuildContext context, Map<String, dynamic> b, Color accent) {
    // Le backend renvoie { id, blocked: { id, name, avatar, … }, blockedRole }.
    final u = (b['blocked'] is Map)
        ? Map<String, dynamic>.from(b['blocked'] as Map)
        : <String, dynamic>{};
    final rawName = (u['name'] ?? '').toString().trim();
    final composed = [u['firstName'], u['lastName']]
        .where((p) => p != null && p.toString().trim().isNotEmpty)
        .join(' ');
    final name = rawName.isNotEmpty
        ? rawName
        : (composed.isNotEmpty ? composed : 'common_user'.tr);
    final avatar = (u['avatar'] is Map)
        ? ((u['avatar'] as Map)['url'] ?? '').toString()
        : (u['avatar'] ?? '').toString();
    final role = (b['blockedRole'] ?? '').toString();
    final userId = (u['id'] ?? u['_id'] ?? '').toString();
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: FriendsCard(
        padding: EdgeInsets.all(12.w),
        child: Row(
          children: [
            FriendAvatar(
              imageUrl: avatar,
              ringColor: AppColors.divider(context),
              size: 42,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InterText(
                    text: name,
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FriendsBadge(
                      label: friendRoleLabel(role),
                      color: friendRoleColor(role),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 130.w),
              child: FriendsPillButton(
                label: 'friend_unblock'.tr,
                color: accent,
                loading: _busy.contains(userId),
                onTap: userId.isEmpty
                    ? null
                    : () => _unblock(
                          userId: userId,
                          role: role,
                          name: name,
                          accent: accent,
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
