// v605 (30/09/2026) — Daniel : « arrêter de le suivre doit être plus
// pratique et connecté au bouton Balade ; que je passe en direct par un
// message ou par la carte, TOUT doit passer par le bouton Balade vert ou
// noir ». UNE seule feuille « En direct », ouverte par :
//   · le bouton Balade (barre de droite) quand quelque chose est en cours,
//   · la pilule « Direct » (haut à gauche),
//   · « Arrêter » de la pilule de suivi,
//   · les arrêts du chat (`openLiveSheetFromChat`, pawfollow_widgets.dart).
// Elle lit la vérité UNIQUE `LiveMapService` (Obx) :
//   · Ma balade · 12 min · 2 te suivent        → Arrêter
//   · Tu suis Kathy                            → Arrêter de suivre
//   · Ils te suivent : Daniel, John            (lecture)
//   · Kathy est en direct                      → Suivre (le contour vert du
//     menu s'explique ici : vert = un ami est en direct, suivi ou non)
// Les deux sens sont indépendants : arrêter ma balade ne touche pas à qui je
// suis ; arrêter de suivre ne touche pas à ma balade.
//
// Ouvrir : `showPawLiveSheet(context)`.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../services/live_map_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/pawmap_theme.dart';
import 'pawmap_buttons.dart';
import 'pawmap_jewel.dart';
import 'pawmap_pins.dart';
import 'pawmap_sheets.dart';
import 'pawmap_friends610.dart' show PawPersonTile610;

/// Suivi connu du CHAT seulement (demande de suivi acceptée côté serveur,
/// la carte ne suit personne) : ligne « Tu suis … » avec son propre arrêt.
class PawLiveChatFollow {
  const PawLiveChatFollow({
    required this.userId,
    required this.name,
    required this.onStop,
    this.avatar = '',
  });

  final String userId;
  final String name;
  final String avatar;
  final Future<void> Function() onStop;
}

/// Ouvre la feuille unique « En direct ».
/// [onStartWalk] : bouton « Démarrer ma balade » quand rien n'est en cours.
/// [onFollowFriend] : « Suivre » sur un ami en direct (carte : vol + suivi ;
/// ailleurs : ouvrir la carte sur lui).
/// [chatFollow] : suivi connu du chat (voir [PawLiveChatFollow]).
Future<void> showPawLiveSheet(
  BuildContext context, {
  Future<void> Function()? onStartWalk,
  void Function(FriendPosition friend)? onFollowFriend,
  PawLiveChatFollow? chatFollow,
  // 610 — « QUI me suit » : appui sur une personne, et ouverture directe
  // sur cette section (pastille « 1 te suit » de la pilule).
  void Function(PawFollower610 follower)? onOpenFollower,
  bool focusFollowers = false,
}) {
  final LiveMapService live = Get.isRegistered<LiveMapService>()
      ? Get.find<LiveMapService>()
      : Get.put(LiveMapService(), permanent: true);
  return showPawMapSheet<void>(
    context,
    PawLiveSheet(
      live: live,
      onStartWalk: onStartWalk,
      onFollowFriend: onFollowFriend,
      chatFollow: chatFollow,
      onOpenFollower: onOpenFollower,
      focusFollowers: focusFollowers,
    ),
  );
}

/// 610 — « depuis 12 min » (au moins 1 min ; vide sans heure connue).
String pawFollowerSinceLabel610(DateTime? since, DateTime now) {
  if (since == null) return '';
  final m = now.difference(since).inMinutes;
  return 'pm610_since_min'.trParams({'min': '${m < 1 ? 1 : m}'});
}

/// Durée « 12 min » / « 1 h 05 » depuis [start]. Pure.
String pawLiveDurationLabel(DateTime? start, DateTime now) {
  if (start == null) return '';
  final d = now.difference(start);
  final m = d.inMinutes < 0 ? 0 : d.inMinutes;
  if (m < 60) return 'pm605_live_min'.trParams({'n': '$m'});
  final h = m ~/ 60;
  final mm = (m % 60).toString().padLeft(2, '0');
  return '$h h $mm';
}

/// Libellé « qui me suit » : prénoms si le serveur les donne, sinon nombre.
String pawLiveFollowersLabel(int count, List<String> names) {
  if (names.isNotEmpty) {
    return 'pm605_live_they_follow'.trParams({'names': names.join(', ')});
  }
  if (count <= 0) return 'pm605_live_nobody_follows'.tr;
  if (count == 1) return 'pm605_live_follower_1'.tr;
  return 'pm605_live_they_follow_n'.trParams({'n': '$count'});
}

class PawLiveSheet extends StatefulWidget {
  const PawLiveSheet({
    super.key,
    required this.live,
    this.onStartWalk,
    this.onFollowFriend,
    this.chatFollow,
    this.onOpenFollower,
    this.focusFollowers = false,
  });

  final void Function(PawFollower610 follower)? onOpenFollower;
  final bool focusFollowers;
  final LiveMapService live;
  final Future<void> Function()? onStartWalk;
  final void Function(FriendPosition friend)? onFollowFriend;
  final PawLiveChatFollow? chatFollow;

  @override
  State<PawLiveSheet> createState() => _PawLiveSheetState();
}

class _PawLiveSheetState extends State<PawLiveSheet> {
  bool _busy = false;
  final GlobalKey _followersKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 610 — ouverte par la pastille « N te suit » : on va sur la section.
    if (widget.focusFollowers) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _followersKey.currentContext;
        if (c != null) {
          Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250));
        }
      });
    }
  }
  bool _chatFollowStopped = false;

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopMyWalk() => _run(() async {
        final live = widget.live;
        if (live.broadcasting.value) {
          live.stopBroadcasting();
        } else {
          await live.stopEverywhere();
        }
      });

  Future<void> _stopFollowing(String userId) => _run(() async {
        await widget.live.stopFollowing(userId, byUser: true);
      });

  Future<void> _stopChatFollow(PawLiveChatFollow f) => _run(() async {
        await f.onStop();
        widget.live.declineFollow(f.userId);
        if (widget.live.isFollowing(f.userId)) {
          await widget.live.stopFollowing(f.userId, byUser: true);
        }
        if (mounted) setState(() => _chatFollowStopped = true);
      });

  String _nameOf(String userId) {
    final live = widget.live;
    if (live.followingUserId.value == userId &&
        live.followingName.value.trim().isNotEmpty) {
      return live.followingName.value.trim();
    }
    final fp = live.friendPositions[userId];
    if (fp != null && fp.name.trim().isNotEmpty) return fp.name.trim();
    return 'pawmap_following_default'.tr;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final live = widget.live;
      live.staleTick.value; // durée et états « en direct » à jour (30 s)
      final bool sharing = live.broadcasting.value;
      final bool elsewhere = !sharing && live.liveElsewhere.value;
      final bool meLive = sharing || elsewhere;
      final String? followId = live.followingUserId.value;
      final int followers = live.myFollowers.value;
      final List<String> names = live.followerNames.toList();
      final List<PawFollower610> who = live.followerList.toList(); // 610
      final chat = widget.chatFollow;
      final bool chatRow = chat != null &&
          !_chatFollowStopped &&
          chat.userId.isNotEmpty &&
          chat.userId != followId;
      final now = DateTime.now();
      // Amis en direct que je ne suis pas (le contour vert du menu).
      final List<FriendPosition> othersLive = [
        for (final fp in live.friendPositions.values)
          if (fp.liveState != FriendLiveState.seen &&
              fp.userId != followId &&
              !(followId != null && fp.allIds.contains(followId.toLowerCase())) &&
              !(chatRow && fp.allIds.contains(chat.userId.toLowerCase())))
            fp,
      ];
      final bool nothing = !meLive && followId == null && !chatRow;

      final rows = <Widget>[];
      if (meLive) {
        final dur = pawLiveDurationLabel(live.sessionStartedAt.value, now);
        final sub = <String>[
          if (elsewhere) 'pm605_live_elsewhere'.tr,
          if (dur.isNotEmpty && !elsewhere) dur,
          pawLiveFollowersLabel(followers, const <String>[]),
        ].join(' · ');
        rows.add(_LiveRow(
          key: const ValueKey<String>('live_sheet_my_walk'),
          icon: PawSymbols.walk,
          tone: const Color(0xFF2E9E48),
          title: 'pm605_live_my_walk'.tr,
          subtitle: sub,
          actionLabel: 'pm605_live_stop'.tr,
          actionKey: const ValueKey<String>('live_sheet_stop_walk'),
          onAction: _busy ? null : () => _stopMyWalk(),
        ));
      }
      if (followId != null) {
        rows.add(_LiveRow(
          key: ValueKey<String>('live_sheet_following_$followId'),
          icon: Icons.visibility_rounded,
          tone: PawMapLegend.pawFollow,
          title: 'pm605_live_you_follow'.trParams({'name': _nameOf(followId)}),
          subtitle: '',
          actionLabel: 'pm605_live_stop_follow'.tr,
          actionKey: const ValueKey<String>('live_sheet_stop_follow'),
          onAction: _busy ? null : () => _stopFollowing(followId),
        ));
      }
      if (chatRow) {
        rows.add(_LiveRow(
          key: ValueKey<String>('live_sheet_following_${chat.userId}'),
          icon: Icons.visibility_rounded,
          tone: PawMapLegend.pawFollow,
          title: 'pm605_live_you_follow'.trParams({
            'name': chat.name.trim().isEmpty
                ? 'pawmap_following_default'.tr
                : chat.name.trim()
          }),
          subtitle: '',
          actionLabel: 'pm605_live_stop_follow'.tr,
          actionKey: const ValueKey<String>('live_sheet_stop_chat_follow'),
          onAction: _busy ? null : () => _stopChatFollow(chat),
        ));
      }
      if (meLive && who.isNotEmpty) {
        // 610 — Daniel : « il ne me dit pas QUI me suit ». Une ligne par
        // personne : photo, « Cam te suit », « depuis 12 min ».
        rows.add(Column(
          key: _followersKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 4.w, bottom: 2.h),
              child: Text(
                'pm610_they_follow_title'.tr,
                key: const ValueKey<String>('live_sheet_followers_title'),
                style: PawMapTheme.fontOn(context,
                    size: 12.sp,
                    weight: FontWeight.w800,
                    color: PawMapTheme.subOn(context)),
              ),
            ),
            for (final f in who)
              PawPersonTile610(
                key: ValueKey<String>('live_sheet_follower_${f.id}'),
                name: 'pm610_follows_you'.trParams({'name': f.name}),
                avatar: f.avatar,
                subtitle: pawFollowerSinceLabel610(f.since, now),
                ring: const Color(0xFF2E9E48),
                onTap: () {
                  if (widget.onOpenFollower == null) return;
                  Navigator.of(context).maybePop();
                  widget.onOpenFollower!(f);
                },
              ),
          ],
        ));
      } else if (meLive && names.isNotEmpty) {
        rows.add(_LiveRow(
          key: _followersKey,
          icon: Icons.groups_rounded,
          tone: const Color(0xFF2E9E48),
          title: pawLiveFollowersLabel(followers, names),
          subtitle: '',
        ));
      }
      for (final fp in othersLive.take(5)) {
        final n = fp.name.trim().isEmpty
            ? 'pawmap_following_default'.tr
            : fp.name.trim();
        rows.add(_LiveRow(
          key: ValueKey<String>('live_sheet_friend_${fp.userId}'),
          icon: Icons.sensors_rounded,
          tone: PawMapLegend.friend,
          title: 'pm605_live_friend_live'.trParams({'name': n}),
          subtitle: '',
          actionLabel: widget.onFollowFriend == null ? null : 'pm605_live_follow'.tr,
          actionKey: ValueKey<String>('live_sheet_follow_${fp.userId}'),
          actionSecondary: true,
          onAction: widget.onFollowFriend == null || _busy
              ? null
              : () {
                  Navigator.of(context).maybePop();
                  widget.onFollowFriend!(fp);
                },
        ));
      }

      return SingleChildScrollView(
        key: const ValueKey<String>('pawmap_live_sheet'),
        padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TitleJewel(sharing: meLive, following: followId != null || chatRow),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'pm605_live_title'.tr,
                    style: PawMapTheme.fontOn(context,
                        size: 18.sp, weight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              'pm605_live_hint'.tr,
              style: PawMapTheme.fontOn(context,
                  size: 12.sp,
                  weight: FontWeight.w500,
                  color: PawMapTheme.subOn(context),
                  height: 1.35),
            ),
            SizedBox(height: 12.h),
            // 607 (PAM, vu au simulateur) — « Rien en direct pour le moment »
            // s'affichait AU-DESSUS de « Test Walker est en direct ».
            if (nothing && othersLive.isEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Text(
                  'pm605_live_nothing'.tr,
                  key: const ValueKey<String>('live_sheet_nothing'),
                  style: PawMapTheme.fontOn(context,
                      size: 14.sp, weight: FontWeight.w700),
                ),
              ),
            for (int i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: 8.h),
              rows[i],
            ],
            // 607 (PAM, vu au simulateur) — en SUIVANT quelqu'un sans être
            // en balade, la feuille n'offrait aucun moyen de démarrer MA
            // balade (le bouton Balade ouvre cette feuille dès qu'on suit) :
            // impossible de faire « A suit B, puis B se met en direct ».
            if (!meLive && widget.onStartWalk != null) ...[
              SizedBox(height: 12.h),
              PawSignatureButton(
                key: const ValueKey<String>('live_sheet_start_walk'),
                label: 'pm605_live_start'.tr,
                icon: PawSymbols.walk,
                color: const Color(0xFF2E9E48),
                onTap: _busy
                    ? null
                    : () {
                        Navigator.of(context).maybePop();
                        widget.onStartWalk!();
                      },
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// Pastille du titre : l'état du bouton Balade en petit (vert / violet /
/// vert + point violet / noir).
class _TitleJewel extends StatelessWidget {
  const _TitleJewel({required this.sharing, required this.following});

  final bool sharing;
  final bool following;

  @override
  Widget build(BuildContext context) {
    final state = pawLiveButtonState(meLive: sharing, following: following);
    final pal = pawLiveJewelPalette(state);
    return SizedBox(
      width: 38.w,
      height: 38.w,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: pal.gradient,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(PawSymbols.walk, color: Colors.white, size: 20.sp),
          ),
          if (state == PawLiveButtonState.both)
            const Positioned(right: -2, top: -2, child: PawFollowingDot()),
        ],
      ),
    );
  }
}

/// v605 — palette du bouton Balade selon l'état du direct.
PawJewelPalette pawLiveJewelPalette(PawLiveButtonState s) => switch (s) {
      PawLiveButtonState.off => kJewelWalkOff,
      PawLiveButtonState.sharing => kJewelWalkOn,
      PawLiveButtonState.both => kJewelWalkOn,
      PawLiveButtonState.following => kJewelWalkFollow,
    };

/// v605 — Balade quand je SUIS quelqu'un sans partager moi-même : violet
/// PawFollow (#7C3AED), même dégradé bijou que les autres boutons.
const PawJewelPalette kJewelWalkFollow =
    PawJewelPalette(Color(0xFFB08CFF), Color(0xFF7C3AED), Color(0xFF5B21B6));

/// v605 — petite pastille violette « je suis quelqu'un » posée sur le bouton
/// Balade vert (les deux sens en même temps).
class PawFollowingDot extends StatelessWidget {
  const PawFollowingDot({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('pawmap_walk_following_dot'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PawMapLegend.pawFollow,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: PawMapLegend.pawFollow.withValues(alpha: 0.55),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

class _LiveRow extends StatelessWidget {
  const _LiveRow({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.actionKey,
    this.onAction,
    this.actionSecondary = false,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;
  final bool actionSecondary;

  @override
  Widget build(BuildContext context) {
    final bool dark = PawMapTheme.isDark(context);
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 10.w, 10.h),
      decoration: BoxDecoration(
        color: dark
            ? Color.lerp(const Color(0xFF241916), tone, 0.16)
            : Color.lerp(Colors.white, tone, 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: tone.withValues(alpha: dark ? 0.55 : 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [PawMapLegend.lighten(tone, 0.12), PawMapLegend.darken(tone, 0.12)],
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 19.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PawMapTheme.fontOn(context,
                      size: 14.sp, weight: FontWeight.w800),
                ),
                if (subtitle.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PawMapTheme.font(
                        size: 12.sp,
                        weight: FontWeight.w700,
                        color: AppColors.accentOn(context, tone)),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null) ...[
            SizedBox(width: 8.w),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 150.w),
              child: PawSignatureButton(
                key: actionKey,
                kind: actionSecondary ? PawButtonKind.secondary : PawButtonKind.primary,
                label: actionLabel!,
                color: actionSecondary ? tone : const Color(0xFFB8261A),
                expand: false,
                onTap: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
