// v566 — onglet « Mes amis » : recherche, cartes avec point vert de présence,
// pastille de rôle, actions claires (Message / Suivre / Profil), partage de
// position, retirer / bloquer dans le menu. Tri : en ligne d'abord.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/friends/tabs/friends_ui.dart';
import 'package:hopetsit/widgets/app_switch.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

class MyFriendsTab extends StatefulWidget {
  const MyFriendsTab({
    super.key,
    required this.controller,
    required this.accent,
    required this.onInvite,
  });

  final FriendController controller;
  final Color accent;

  /// « Inviter un ami » (état vide) → bascule sur l'onglet Ajouter.
  final VoidCallback onInvite;

  @override
  State<MyFriendsTab> createState() => _MyFriendsTabState();
}

class _MyFriendsTabState extends State<MyFriendsTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final RxString _query = ''.obs;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;
    final accent = widget.accent;
    return RefreshIndicator(
      color: accent,
      onRefresh: controller.refresh,
      child: Obx(() {
        // v23.1.278 — familyMembers est une dépendance : la pastille Famille
        // et l'anneau violet se recalculent dès un ajout / retrait.
        final familyIds = controller.familyMembers
            .map((m) => (m['id'] ?? m['userId'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toSet();
        // Dépendance de présence : le tri « en ligne d'abord » suit
        // `presence:update` en direct.
        // ignore: unused_local_variable
        final presenceTick = controller.onlineById.length;
        final online = Map<String, bool>.from(controller.onlineById);
        final all = controller.friends.toList();
        final q = _query.value.trim().toLowerCase();

        if (controller.isLoading.value && all.isEmpty) {
          return const FriendsSkeletonList();
        }
        if (controller.loadFailed.value && all.isEmpty) {
          return FriendsStateView.loadError(
            accent: accent,
            onRetry: controller.refresh,
          );
        }
        if (all.isEmpty) {
          return FriendsStateView(
            icon: Icons.pets_rounded,
            title: 'friends_empty_title'.tr,
            message: 'friends_empty_subtitle'.tr,
            accent: accent,
            actionLabel: 'friends566_invite_cta'.tr,
            onAction: widget.onInvite,
          );
        }

        bool isOn(Friendship f) => online[f.other?.id ?? ''] == true;
        final filtered = all.where((f) {
          if (q.isEmpty) return true;
          final o = f.other;
          if (o == null) return false;
          return o.name.toLowerCase().contains(q) ||
              o.city.toLowerCase().contains(q);
        }).toList()
          ..sort((a, b) {
            final oa = isOn(a) ? 0 : 1;
            final ob = isOn(b) ? 0 : 1;
            if (oa != ob) return oa.compareTo(ob);
            return (a.other?.name ?? '')
                .toLowerCase()
                .compareTo((b.other?.name ?? '').toLowerCase());
          });
        final onlineCount = all.where(isOn).length;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          // v465 — marge basse = inset système + 24 (barre Samsung).
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w,
              24.h + appBottomInset(context)),
          children: [
            FriendsSearchField(
              controller: _searchCtrl,
              hint: 'friends566_search_hint'.tr,
              accent: accent,
              onChanged: (v) => _query.value = v,
            ),
            SizedBox(height: 14.h),
            FriendsSectionHeader(
              title: 'friends_tab_friends'.tr,
              count: all.length,
              color: accent,
              trailing: onlineCount == 0
                  ? null
                  : FriendsBadge(
                      label: 'friends566_online_count'
                          .trParams({'n': '$onlineCount'}),
                      color: kFriendsGreen,
                      icon: Icons.circle,
                    ),
            ),
            if (filtered.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 12.w),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 40.sp, color: AppColors.greyText),
                    SizedBox(height: 10.h),
                    InterText(
                      text: 'friends566_no_match'.tr,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                    ),
                  ],
                ),
              )
            else
              for (final f in filtered)
                Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: FriendCard(
                    key: ValueKey('friend_${f.id}'),
                    friendship: f,
                    controller: controller,
                    accent: accent,
                    isFamily: familyIds.contains(f.other?.id ?? ''),
                    online: isOn(f),
                  ),
                ),
          ],
        );
      }),
    );
  }
}

/// Carte d'un ami.
class FriendCard extends StatefulWidget {
  const FriendCard({
    super.key,
    required this.friendship,
    required this.controller,
    required this.accent,
    required this.isFamily,
    required this.online,
  });

  final Friendship friendship;
  final FriendController controller;
  final Color accent;
  final bool isFamily;
  final bool online;

  @override
  State<FriendCard> createState() => _FriendCardState();
}

class _FriendCardState extends State<FriendCard> {
  bool _chatBusy = false;
  bool _followBusy = false;
  bool _shareBusy = false;
  bool _menuBusy = false;

  // v23.1 part 205 — null-safe : un orphelin (compte supprimé) remonte sans
  // `other` → profil de substitution, id vide = actions masquées.
  FriendProfile get _other =>
      widget.friendship.other ??
      FriendProfile(
        id: '',
        model: 'Owner',
        name: 'friends_deleted_user'.tr,
      );

  Future<void> _guard(void Function(bool) setBusy, Future<void> Function() run) async {
    setState(() => setBusy(true));
    try {
      await run();
    } finally {
      if (mounted) setState(() => setBusy(false));
    }
  }

  Future<void> _onShareToggle(bool v) => _guard((b) => _shareBusy = b, () async {
        final ok =
            await widget.controller.setSharePosition(widget.friendship.id, v);
        if (!ok) {
          CustomSnackbar.showError(
            title: 'common_error'.tr,
            message: 'friends566_error_msg'.tr,
          );
        }
      });

  Future<void> _onUnfriend() async {
    final other = _other;
    final confirmed = await confirmFriendsAction(
      context,
      title: 'friend_remove_confirm'.tr,
      message: 'friend_remove_confirm_desc'.trParams({'name': other.name}),
      confirmLabel: 'friend_remove'.tr,
      accent: widget.accent,
      icon: Icons.person_remove_rounded,
      danger: true,
    );
    if (!confirmed) return;
    await _guard((b) => _menuBusy = b, () async {
      final ok = await widget.controller.unfriend(widget.friendship.id);
      if (ok) {
        CustomSnackbar.showSuccess(
          title: 'friend_removed_title'.tr,
          message: 'friend_removed_msg'.tr,
        );
      } else {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'friends566_error_msg'.tr,
        );
      }
    });
  }

  Future<void> _onBlock() async {
    final other = _other;
    final confirmed = await confirmFriendsAction(
      context,
      title: 'friend_block_confirm'.tr,
      message: 'friend_block_confirm_desc'.trParams({'name': other.name}),
      confirmLabel: 'friend_block'.tr,
      accent: widget.accent,
      icon: Icons.block_rounded,
      danger: true,
    );
    if (!confirmed) return;
    await _guard((b) => _menuBusy = b, () async {
      final ok = await widget.controller.blockUser(
        targetUserId: other.id,
        targetRole: other.model.toLowerCase(),
        friendshipId: widget.friendship.id,
      );
      if (ok) {
        CustomSnackbar.showSuccess(
          title: 'friend_blocked_title'.tr,
          message: 'friend_blocked_msg'.trParams({'name': other.name}),
        );
      } else {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'friends566_error_msg'.tr,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.friendship;
    final other = _other;
    final hasId = other.id.isNotEmpty;
    final roleColor = friendRoleColor(other.model);
    final pawSpot = pawSpotRingColor(other.pawSpotTier);
    // v23.1.280 — anneau : PawSpot prioritaire, sinon violet famille, sinon rôle.
    final ring = pawSpot ?? (widget.isFamily ? kFamilyViolet : roleColor);
    final displayName = other.name.isEmpty ? 'common_user'.tr : other.name;

    final String statusText;
    if (widget.online) {
      statusText = 'friends566_online'.tr;
    } else if (other.lastSeenAt != null) {
      statusText = 'pawmap_seen_ago'
          .tr
          .replaceAll('{ago}', friendsTimeAgo(other.lastSeenAt!));
    } else {
      statusText = 'friends566_offline'.tr;
    }

    return FriendsCard(
      tint: widget.isFamily ? kFamilyViolet : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FriendAvatar(
                imageUrl: other.avatar,
                ringColor: ring,
                online: hasId ? widget.online : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: InterText(
                            text: displayName,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (other.isPremium) ...[
                          SizedBox(width: 4.w),
                          Text('👑', style: TextStyle(fontSize: 12.sp)),
                        ],
                      ],
                    ),
                    SizedBox(height: 5.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 4.h,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FriendsBadge(
                          label: friendRoleLabel(other.model),
                          color: roleColor,
                        ),
                        if (widget.isFamily)
                          FriendsBadge(
                            label: 'friends_tab_family'.tr,
                            color: kFamilyViolet,
                          ),
                        if (pawSpot != null)
                          FriendsBadge(label: 'PawSpot', color: pawSpot),
                      ],
                    ),
                    SizedBox(height: 5.h),
                    InterText(
                      text: other.city.isEmpty
                          ? statusText
                          : '$statusText · ${other.city}',
                      fontSize: 11.5.sp,
                      fontWeight:
                          widget.online ? FontWeight.w600 : FontWeight.w400,
                      color: widget.online
                          ? kFriendsGreen
                          : AppColors.textSecondary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _menuBusy
                  ? Padding(
                      padding: EdgeInsets.all(10.w),
                      child: SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(widget.accent),
                        ),
                      ),
                    )
                  : PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      tooltip: 'friends566_more'.tr,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      icon: Icon(Icons.more_horiz_rounded,
                          size: 20.sp, color: AppColors.greyText),
                      onSelected: (v) {
                        if (v == 'unfriend') _onUnfriend();
                        if (v == 'block') _onBlock();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'unfriend',
                          child: _menuRow(
                            context,
                            Icons.person_remove_rounded,
                            'friend_remove'.tr,
                            AppColors.textPrimary(context),
                          ),
                        ),
                        if (hasId)
                          PopupMenuItem(
                            value: 'block',
                            child: _menuRow(
                              context,
                              Icons.block_rounded,
                              'friend_block'.tr,
                              AppColors.errorColor,
                            ),
                          ),
                      ],
                    ),
            ],
          ),
          if (hasId) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: FriendsPillButton(
                    label: 'friends566_action_message'.tr,
                    icon: Icons.chat_bubble_rounded,
                    color: widget.accent,
                    filled: true,
                    expand: true,
                    loading: _chatBusy,
                    onTap: () => _guard(
                      (b) => _chatBusy = b,
                      () => openFriendChatRoleAware(
                        controller: widget.controller,
                        other: other,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: FriendsPillButton(
                    label: 'friends566_action_follow'.tr,
                    icon: Icons.near_me_rounded,
                    color: widget.accent,
                    expand: true,
                    loading: _followBusy,
                    onTap: () => _guard(
                      (b) => _followBusy = b,
                      () => followFriendLive(
                        controller: widget.controller,
                        friendship: f,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: FriendsPillButton(
                    label: 'friends566_action_profile'.tr,
                    icon: Icons.person_rounded,
                    color: widget.accent,
                    expand: true,
                    onTap: () => openMemberProfile(
                      userId: other.id,
                      role: other.model,
                      name: other.name,
                      avatar: other.avatar,
                      city: other.city,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Divider(height: 1, color: AppColors.divider(context)),
            SizedBox(height: 4.h),
            // v23.1 part 244 — l'interrupteur reste TOUJOURS manuel (plus de
            // badge « Auto »), il reflète la valeur enregistrée côté serveur.
            Row(
              children: [
                Icon(Icons.my_location_rounded,
                    size: 15.sp, color: AppColors.textSecondary(context)),
                SizedBox(width: 6.w),
                Expanded(
                  child: InterText(
                    text: 'friends566_share_my_position'.tr,
                    fontSize: 12.sp,
                    color: AppColors.textSecondary(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Opacity(
                  opacity: _shareBusy ? 0.5 : 1,
                  child: Transform.scale(
                    scale: 0.78,
                    alignment: Alignment.centerRight,
                    child: AppSwitch(
                      value: f.mySharePosition,
                      accent: widget.accent,
                      onChanged: _shareBusy ? null : _onShareToggle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _menuRow(BuildContext context, IconData icon, String label, Color c) {
    return Row(
      children: [
        Icon(icon, color: c, size: 18.sp),
        SizedBox(width: 10.w),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14.sp, color: c),
          ),
        ),
      ],
    );
  }
}
