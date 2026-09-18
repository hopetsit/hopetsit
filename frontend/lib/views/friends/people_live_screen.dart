// v23.1 part 225 — « Personnes en live » : écran autonome ouvert depuis la
// carte rapide de la PawMap (l'onglet a quitté FriendsScreen).
// v566 — modernisé : mêmes cartes que « Mes amis » (avatar cerclé, pastille de
// rôle traduite), états chargement / vide / erreur + Réessayer, boutons
// Suivre / Itinéraire / Message.
//
// Liste les amis / membres de la famille :
//  (a) qui partagent explicitement leur position avec moi,
//  (b) qui ont PawFollow actif (partage automatique, v222),
//  (c) v565 — dont on a une position en direct (le serveur a déjà appliqué les
//      règles d'accès), avec l'état réel « actif / signal perdu · vu il y a X ».
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/friends/friends_screen.dart';
import 'package:hopetsit/views/friends/tabs/friends_ui.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/dotted_invite_card.dart';

const Color _liveGreen = Color(0xFF16A34A);
const Color _liveAmber = Color(0xFFE8920A);

class PeopleLiveScreen extends StatelessWidget {
  const PeopleLiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FriendController controller = Get.isRegistered<FriendController>()
        ? Get.find<FriendController>()
        : Get.put(FriendController());
    final accent = currentRoleAccent();

    Future<void> refresh() async {
      await controller.refresh();
      // v565 — contrat §8 : rafraîchit aussi stale / lastSeenAt.
      try {
        if (Get.isRegistered<LiveMapService>()) {
          await Get.find<LiveMapService>().refreshFriendPositions();
        }
      } catch (_) {/* défensif */}
    }

    return ProfileSubPageScaffold(
      title: 'pawmap_quick_people_live'.tr,
      accent: accent,
      scroll: false,
      body: RefreshIndicator(
        color: accent,
        onRefresh: refresh,
        child: Obx(() {
          final live = Get.isRegistered<LiveMapService>()
              ? Get.find<LiveMapService>()
              : null;
          live?.staleTick.value; // « vu il y a » se rafraîchit
          final positions =
              live?.friendPositions ?? const <String, FriendPosition>{};
          final friends = controller.friends.toList();

          if (controller.isLoading.value && friends.isEmpty) {
            return const FriendsSkeletonList(count: 3);
          }
          if (controller.loadFailed.value && friends.isEmpty) {
            return FriendsStateView.loadError(accent: accent, onRetry: refresh);
          }

          final livePeople = friends
              .where((f) =>
                  f.status == 'accepted' &&
                  f.other != null &&
                  (f.theirSharePosition ||
                      (f.other?.hasPawFollow ?? false) ||
                      positions.containsKey(f.other?.id ?? '')))
              .toList()
            ..sort((a, b) {
              final pa = positions[a.other?.id ?? ''];
              final pb = positions[b.other?.id ?? ''];
              final sa = pa == null ? 2 : (pa.isStale ? 1 : 0);
              final sb = pb == null ? 2 : (pb.isStale ? 1 : 0);
              return sa.compareTo(sb);
            });

          if (livePeople.isEmpty) {
            return FriendsStateView(
              icon: Icons.location_off_rounded,
              title: 'friends_people_live_empty_title'.tr,
              message: 'friends_people_live_empty_msg'.tr,
              accent: accent,
              // v552 — porte de sortie : inviter quelqu'un à partager.
              footer: Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: GestureDetector(
                  onTap: () => Get.to(() => const FriendsScreen()),
                  behavior: HitTestBehavior.opaque,
                  child: DottedInviteCard(
                    title: 'friends_live_invite_title'.tr,
                    subtitle: 'friends_live_invite_sub'.tr,
                    color: accent,
                  ),
                ),
              ),
            );
          }

          final activeCount = livePeople
              .where((f) => positions[f.other!.id]?.isStale == false)
              .length;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w,
                24.h + MediaQuery.of(context).viewPadding.bottom),
            children: [
              FriendsSectionHeader(
                title: 'pawmap_quick_people_live'.tr,
                count: livePeople.length,
                color: accent,
                trailing: activeCount == 0
                    ? null
                    : FriendsBadge(
                        label: '$activeCount · ${'v565_live_active'.tr}',
                        color: _liveGreen,
                        icon: Icons.circle,
                      ),
              ),
              for (final f in livePeople)
                Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: _LivePersonCard(
                    key: ValueKey('live_${f.id}'),
                    friendship: f,
                    controller: controller,
                    position: positions[f.other!.id],
                    accent: accent,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _LivePersonCard extends StatefulWidget {
  const _LivePersonCard({
    super.key,
    required this.friendship,
    required this.controller,
    required this.position,
    required this.accent,
  });

  final Friendship friendship;
  final FriendController controller;
  final FriendPosition? position;
  final Color accent;

  @override
  State<_LivePersonCard> createState() => _LivePersonCardState();
}

class _LivePersonCardState extends State<_LivePersonCard> {
  bool _followBusy = false;
  bool _routeBusy = false;
  bool _chatBusy = false;

  FriendProfile get _other => widget.friendship.other!;

  // v23.1 part 239/240 — la carte s'ouvre centrée sur L'AMI (socket → repli
  // /friends/:id/last-position), avec focusUserId pour le halo de suivi.
  Future<void> _follow() async {
    setState(() => _followBusy = true);
    try {
      await openPawMapOnMember(
        userId: _other.id,
        role: _other.model,
        name: _other.name,
      );
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  // v559 — itinéraire vers l'ami (à pied / vélo / voiture) sur la PawMap.
  Future<void> _route() async {
    setState(() => _routeBusy = true);
    try {
      final (lat, lng) = await resolveFriendLatLng(_other.id);
      if (lat == null || lng == null) {
        CustomSnackbar.showInfo(
          title: 'friends_tap_not_shared_title'.tr,
          message: 'friends566_no_position'.tr,
        );
        return;
      }
      openPawMapWithRoute(lat, lng);
    } finally {
      if (mounted) setState(() => _routeBusy = false);
    }
  }

  Future<void> _chat() async {
    setState(() => _chatBusy = true);
    try {
      await openFriendChatRoleAware(
          controller: widget.controller, other: _other);
    } finally {
      if (mounted) setState(() => _chatBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final other = _other;
    final pos = widget.position;
    // v565 — état réel de la session de l'ami.
    final bool stale = pos?.isStale ?? true;
    final Color dot = pos == null
        ? AppColors.greyText
        : (stale ? _liveAmber : _liveGreen);
    final String statusText = pos == null
        ? 'friends_people_live_subtitle'.tr
        : (stale
            ? '${'v565_live_signal_lost'.tr} · ${'pawmap_seen_ago'.tr.replaceAll('{ago}', friendsTimeAgo(pos.seenAt))}'
            : '${'v565_live_active'.tr} · ${friendsTimeAgo(pos.seenAt)}');
    final roleColor = friendRoleColor(other.model);
    final ring = pawSpotRingColor(other.pawSpotTier) ?? roleColor;

    return FriendsCard(
      onTap: _followBusy ? null : _follow,
      child: Column(
        children: [
          Row(
            children: [
              FriendAvatar(imageUrl: other.avatar, ringColor: ring),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: InterText(
                            text: other.name.isEmpty
                                ? 'common_user'.tr
                                : other.name,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        FriendsBadge(
                          label: friendRoleLabel(other.model),
                          color: roleColor,
                        ),
                      ],
                    ),
                    SizedBox(height: 5.h),
                    Row(
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration:
                              BoxDecoration(color: dot, shape: BoxShape.circle),
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: InterText(
                            text: statusText,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: pos == null
                                ? AppColors.textSecondary(context)
                                : dot,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: FriendsPillButton(
                  label: 'friends566_action_follow'.tr,
                  icon: Icons.near_me_rounded,
                  color: widget.accent,
                  filled: true,
                  expand: true,
                  loading: _followBusy,
                  onTap: _follow,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: FriendsPillButton(
                  label: 'pawmap_btn_directions'.tr,
                  icon: Icons.directions_rounded,
                  color: widget.accent,
                  expand: true,
                  loading: _routeBusy,
                  onTap: _route,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: FriendsPillButton(
                  label: 'friends566_action_message'.tr,
                  icon: Icons.chat_bubble_rounded,
                  color: widget.accent,
                  expand: true,
                  loading: _chatBusy,
                  onTap: _chat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
