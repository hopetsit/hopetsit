// v584 — lot C du chantier du 24/09 : les FEUILLES de la PawMap.
//
// Widgets PURS (données + rappels) : l'écran carte garde la logique (appels
// serveur, navigation), les tests de widgets appuient sur chaque bouton et
// vérifient le rappel déclenché. Tout suit LEGENDE_PAWMAP.md et
// NORME_DESIGN.md : couleurs de rôle fixes, zéro gris, zéro emoji, un seul
// bouton principal par feuille, libellés jamais coupés.
//
//   · [PawMapMemberSheet]     — fiche COURTE d'un membre : photo, prix, étoiles,
//     « Identité vérifiée », dispo aujourd'hui, et le gros bouton « Réserver »
//     à sa couleur de rôle (réserver en 2 appuis : épingle → Réserver).
//     Propriétaire → « Proposer mes services » s'il a une demande, sinon
//     « Ajouter en ami » / « Message ». Sans compte → inscription.
//   · [PawMapRequestSheet]    — bulle orange d'une demande : « Proposer mes
//     services » en UN appui (idée 3) ; « Ma demande » côté propriétaire.
//   · [PawMapVisibilitySheet] — « Qui me voit sur la carte ? » (tous / amis
//     seulement), avec confirmation.
//   · [PawMapLegendSheet]     — la légende en images (bouton « ? »).
//   · [PawMapFriendsOnlyPill] — pastille du haut « Visible par tes amis
//     seulement » (noir encre, chevron or) : un appui = redevenir visible.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/bottom_inset.dart';
import '../../../utils/pawmap_theme.dart';
import 'pawmap_buttons.dart';
import 'pawmap_pins.dart';

/// Conteneur commun des feuilles de la carte : carte flottante, coins 24,
/// ombre douce, poignée, marge système.
class PawMapSheetShell extends StatelessWidget {
  const PawMapSheetShell({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.86,
  });

  final Widget child;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * maxHeightFactor;
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, appBottomInset(context) + 12.h),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          color: PawMapTheme.panelOn(context),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: PawMapTheme.borderOn(context)),
          boxShadow: PawMapTheme.pillShadowOn(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: PawMapTheme.accent.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

Future<T?> showPawMapSheet<T>(BuildContext context, Widget child,
    {double maxHeightFactor = 0.86}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => PawMapSheetShell(maxHeightFactor: maxHeightFactor, child: child),
  );
}

// ── MEMBRE ─────────────────────────────────────────────────────────────────

/// État de la relation d'amitié avec le membre (calculé par l'écran).
enum PawFriendState { idle, busy, sent, friends, incoming, error }

class PawMapMemberData {
  const PawMapMemberData({
    required this.id,
    required this.role,
    required this.name,
    this.avatar = '',
    this.online = false,
    this.premium = false,
    this.boosted = false,
    this.verified = false,
    this.availableToday = false,
    this.isFriend = false,
    this.approx = false,
    this.approxKm = 1,
    this.rating = 0,
    this.reviewsCount = 0,
    this.priceFrom = 0,
    this.currency = 'EUR',
    this.hasOpenRequest = false,
    this.distanceLabel = '',
  });

  final String id;
  final String role; // owner | sitter | walker
  final String name;
  final String avatar;
  final bool online;
  final bool premium;
  final bool boosted;
  final bool verified;
  final bool availableToday;
  final bool isFriend;
  final bool approx;
  final double approxKm;
  final double rating;
  final int reviewsCount;
  final double priceFrom;
  final String currency;

  /// Propriétaire avec une demande en cours → « Proposer mes services ».
  final bool hasOpenRequest;
  final String distanceLabel;

  bool get isProvider => role == 'sitter' || role == 'walker';
}

class PawMapMemberSheet extends StatelessWidget {
  const PawMapMemberSheet({
    super.key,
    required this.member,
    required this.viewerRole,
    required this.viewerLoggedIn,
    required this.friendState,
    required this.priceLabel,
    required this.onBook,
    required this.onProfile,
    required this.onMessage,
    required this.onFriend,
    required this.onDirections,
    required this.onPropose,
    required this.onSignup,
  });

  final PawMapMemberData member;
  final String viewerRole;
  final bool viewerLoggedIn;
  final PawFriendState friendState;

  /// « 25 € » (prix d'entrée formaté par l'écran) ou vide.
  final String priceLabel;
  final VoidCallback onBook;
  final VoidCallback onProfile;
  final VoidCallback onMessage;
  final VoidCallback onFriend;
  final VoidCallback? onDirections;
  final VoidCallback onPropose;
  final VoidCallback onSignup;

  String get _roleLabel => member.role == 'walker'
      ? 'pawmap_legend_walker'.tr
      : (member.role == 'owner'
          ? 'pawmap_legend_owner'.tr
          : 'pawmap_legend_sitter'.tr);

  String _friendLabel() {
    switch (friendState) {
      case PawFriendState.sent:
        return 'v565_member_request_pending'.tr;
      case PawFriendState.friends:
        return 'v565_member_already_friends'.tr;
      case PawFriendState.incoming:
        return 'v565_member_request_reply'.tr;
      case PawFriendState.error:
        return 'pawmap_member_request_failed'.tr;
      case PawFriendState.busy:
        return '…';
      case PawFriendState.idle:
        return 'pawmap_member_add_friend'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color roleColor = PawMapLegend.roleColor(member.role);
    final Color viewerColor = PawMapLegend.roleColor(viewerRole);
    final bool friendBusy =
        friendState == PawFriendState.busy || friendState == PawFriendState.sent ||
            friendState == PawFriendState.friends;
    // Bouton PRINCIPAL contextuel (un seul par feuille) :
    //   prestataire → Réserver (· prix) ; sans compte → inscription ;
    //   propriétaire avec demande → Proposer mes services ;
    //   sinon → Ajouter en ami.
    final Widget primary;
    if (member.isProvider) {
      primary = PawSignatureButton(
        key: const ValueKey<String>('member_primary_book'),
        label: viewerLoggedIn
            ? 'pawmap_member_book'.tr
            : 'pawmap_member_signup_to_book'.tr,
        price: viewerLoggedIn ? priceLabel : null,
        icon: Icons.event_available_rounded,
        color: roleColor,
        onTap: viewerLoggedIn ? onBook : onSignup,
      );
    } else if (member.hasOpenRequest && viewerRole != 'owner') {
      primary = PawSignatureButton(
        key: const ValueKey<String>('member_primary_propose'),
        label: 'pawmap_request_propose'.tr,
        icon: Icons.volunteer_activism_rounded,
        color: viewerColor,
        onTap: viewerLoggedIn ? onPropose : onSignup,
      );
    } else {
      primary = PawSignatureButton(
        key: const ValueKey<String>('member_primary_friend'),
        label: viewerLoggedIn ? _friendLabel() : 'pawmap_member_signup_to_book'.tr,
        icon: friendState == PawFriendState.friends
            ? Icons.check_rounded
            : Icons.person_add_alt_1_rounded,
        color: PawMapLegend.friend,
        loading: friendState == PawFriendState.busy,
        enabled: !viewerLoggedIn || !friendBusy || friendState == PawFriendState.friends,
        onTap: viewerLoggedIn ? onFriend : onSignup,
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                url: member.avatar,
                ring: member.isFriend ? PawMapLegend.friend : roleColor,
                icon: PawMapLegend.roleIcon(member.role),
                crown: member.premium,
                online: member.online && !member.approx,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name.isNotEmpty
                          ? member.name
                          : (member.role == 'walker'
                              ? 'pawmap_default_walker'.tr
                              : 'pawmap_default_sitter'.tr),
                      maxLines: 2,
                      style: PawMapTheme.fontOn(context,
                          size: 17.sp, weight: FontWeight.w800),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      member.approx
                          ? '$_roleLabel · ${'pawmap_member_approx'.tr.replaceAll('{km}', member.approxKm >= 1 && member.approxKm == member.approxKm.roundToDouble() ? member.approxKm.toStringAsFixed(0) : member.approxKm.toStringAsFixed(1))}'
                          : '$_roleLabel${member.distanceLabel.isNotEmpty ? ' · ${member.distanceLabel}' : ''} · ${member.online ? 'pawmap_member_online'.tr : 'pawmap_member_offline'.tr}',
                      maxLines: 2,
                      style: PawMapTheme.fontOn(context,
                          size: 12.sp,
                          weight: FontWeight.w600,
                          color: PawMapTheme.subOn(context)),
                    ),
                    if (member.isProvider &&
                        (member.rating > 0 || priceLabel.isNotEmpty)) ...[
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          if (member.rating > 0) ...[
                            Icon(Icons.star_rounded,
                                size: 16.sp, color: PawMapLegend.gold),
                            SizedBox(width: 2.w),
                            Text(
                              '${member.rating.toStringAsFixed(1)}'
                              '${member.reviewsCount > 0 ? ' (${member.reviewsCount})' : ''}',
                              style: PawMapTheme.fontOn(context,
                                  size: 12.5.sp, weight: FontWeight.w800),
                            ),
                            SizedBox(width: 10.w),
                          ],
                          if (priceLabel.isNotEmpty)
                            Flexible(
                              child: Text(
                                '${'pawmap_member_price_from'.tr} $priceLabel',
                                maxLines: 1,
                                style: PawMapTheme.fontOn(
                                  context,
                                  size: 13.sp,
                                  weight: FontWeight.w800,
                                  color: AppColors.accentOn(context, roleColor),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (member.verified || member.availableToday || member.boosted) ...[
            SizedBox(height: 10.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: [
                if (member.verified)
                  PawInfoChip(
                    label: 'pawmap_member_verified'.tr,
                    color: PawMapLegend.sitter,
                    icon: Icons.verified_rounded,
                  ),
                if (member.availableToday)
                  PawInfoChip(
                    label: 'pawmap_member_available_today'.tr,
                    color: PawMapLegend.walker,
                    icon: Icons.today_rounded,
                  ),
                if (member.boosted)
                  PawInfoChip(
                    label: 'pawmap_member_boosted'.tr,
                    color: PawMapLegend.boost,
                    icon: Icons.rocket_launch_rounded,
                  ),
              ],
            ),
          ],
          SizedBox(height: 14.h),
          primary,
          SizedBox(height: 8.h),
          Row(
            children: [
              if (member.isProvider || member.hasOpenRequest)
                Expanded(
                  child: PawSignatureButton(
                    key: const ValueKey<String>('member_friend'),
                    kind: PawButtonKind.secondary,
                    label: _friendLabel(),
                    icon: friendState == PawFriendState.friends
                        ? Icons.check_rounded
                        : Icons.person_add_alt_1_rounded,
                    color: PawMapLegend.friend,
                    loading: friendState == PawFriendState.busy,
                    enabled: !friendBusy || friendState == PawFriendState.friends,
                    onTap: viewerLoggedIn ? onFriend : onSignup,
                  ),
                ),
              if (member.isProvider || member.hasOpenRequest)
                SizedBox(width: 8.w),
              Expanded(
                child: PawSignatureButton(
                  key: const ValueKey<String>('member_message'),
                  kind: PawButtonKind.secondary,
                  label: 'pawmap_member_message'.tr,
                  icon: Icons.chat_bubble_rounded,
                  color: viewerColor,
                  onTap: viewerLoggedIn ? onMessage : onSignup,
                ),
              ),
            ],
          ),
          if (onDirections != null) ...[
            SizedBox(height: 8.h),
            PawSignatureButton(
              key: const ValueKey<String>('member_directions'),
              kind: PawButtonKind.secondary,
              label: 'pawmap_btn_directions'.tr,
              icon: Icons.directions_rounded,
              color: PawMapLegend.walker,
              onTap: onDirections,
            ),
          ],
          SizedBox(height: 4.h),
          Center(
            child: PawSignatureButton(
              key: const ValueKey<String>('member_profile'),
              kind: PawButtonKind.link,
              label: 'pawmap_member_view_profile'.tr,
              icon: Icons.person_rounded,
              color: roleColor,
              expand: false,
              onTap: onProfile,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.ring,
    required this.icon,
    required this.crown,
    required this.online,
  });

  final String url;
  final Color ring;
  final IconData icon;
  final bool crown;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final bool hasUrl = url.startsWith('http');
    return SizedBox(
      width: 62.w,
      height: 62.w,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 58.w,
            height: 58.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ring,
              border: Border.all(color: ring, width: 3),
              image: hasUrl
                  ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                  : null,
            ),
            child: hasUrl ? null : Icon(icon, color: Colors.white, size: 26.sp),
          ),
          if (online)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 14.w,
                height: 14.w,
                decoration: BoxDecoration(
                  color: PawMapLegend.online,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          if (crown)
            Positioned(
              right: -2,
              top: -4,
              child: Container(
                width: 22.w,
                height: 22.w,
                decoration: BoxDecoration(
                  color: PawMapLegend.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: PawMapLegend.ink, width: 1.5),
                ),
                child: Icon(Icons.workspace_premium_rounded,
                    size: 14.sp, color: PawMapLegend.ink),
              ),
            ),
        ],
      ),
    );
  }
}

// ── DEMANDE D'UN PROPRIÉTAIRE ──────────────────────────────────────────────

enum PawProposeState { idle, busy, sent, already }

class PawMapRequestSheet extends StatelessWidget {
  const PawMapRequestSheet({
    super.key,
    required this.ownerName,
    required this.ownerAvatar,
    required this.walking,
    required this.city,
    required this.distanceLabel,
    required this.dateLabel,
    required this.budgetLabel,
    required this.body,
    required this.mine,
    required this.approx,
    required this.viewerRole,
    required this.proposeState,
    required this.onPropose,
    required this.onOpenMine,
    required this.onOwnerProfile,
  });

  final String ownerName;
  final String ownerAvatar;
  final bool walking;
  final String city;
  final String distanceLabel;
  final String dateLabel;
  final String budgetLabel;
  final String body;
  final bool mine;
  final bool approx;
  final String viewerRole;
  final PawProposeState proposeState;
  final VoidCallback onPropose;
  final VoidCallback onOpenMine;
  final VoidCallback onOwnerProfile;

  @override
  Widget build(BuildContext context) {
    final Color viewerColor = PawMapLegend.roleColor(viewerRole);
    final String service =
        walking ? 'pawmap_request_walk'.tr : 'pawmap_request_care'.tr;
    final String proposeLabel = switch (proposeState) {
      PawProposeState.sent => 'pawmap_request_sent'.tr,
      PawProposeState.already => 'pawmap_request_already'.tr,
      _ => 'pawmap_request_propose'.tr,
    };
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: const BoxDecoration(
                  color: PawMapLegend.owner,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  walking ? Icons.directions_walk_rounded : Icons.home_rounded,
                  color: Colors.white,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mine
                          ? 'pawmap_request_mine'.tr
                          : (ownerName.isNotEmpty
                              ? ownerName
                              : 'pawmap_request_default_title'.tr),
                      maxLines: 2,
                      style: PawMapTheme.fontOn(context,
                          size: 17.sp, weight: FontWeight.w800),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      [
                        service,
                        if (city.isNotEmpty) city,
                        if (distanceLabel.isNotEmpty) distanceLabel,
                      ].join(' · '),
                      maxLines: 2,
                      style: PawMapTheme.fontOn(context,
                          size: 12.sp,
                          weight: FontWeight.w600,
                          color: PawMapTheme.subOn(context)),
                    ),
                  ],
                ),
              ),
              if (budgetLabel.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: PawMapLegend.owner,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    budgetLabel,
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
            ],
          ),
          if (dateLabel.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    size: 16.sp, color: AppColors.accentOn(context, PawMapLegend.owner)),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(dateLabel,
                      maxLines: 2,
                      style: PawMapTheme.fontOn(context,
                          size: 12.5.sp, weight: FontWeight.w700)),
                ),
              ],
            ),
          ],
          if (body.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Text(
              body,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: PawMapTheme.fontOn(context,
                  size: 13.sp, weight: FontWeight.w500),
            ),
          ],
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.location_searching_rounded,
                  size: 14.sp, color: PawMapTheme.subOn(context)),
              SizedBox(width: 5.w),
              Expanded(
                child: Text(
                  mine ? 'pawmap_request_mine_sub'.tr : 'pawmap_request_approx'.tr,
                  maxLines: 2,
                  style: PawMapTheme.fontOn(context,
                      size: 11.5.sp,
                      weight: FontWeight.w600,
                      color: PawMapTheme.subOn(context)),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          if (mine)
            PawSignatureButton(
              key: const ValueKey<String>('request_open_mine'),
              label: 'pawmap_request_open_mine'.tr,
              icon: Icons.list_alt_rounded,
              color: PawMapLegend.owner,
              onTap: onOpenMine,
            )
          else ...[
            PawSignatureButton(
              key: const ValueKey<String>('request_propose'),
              label: proposeLabel,
              icon: proposeState == PawProposeState.sent
                  ? Icons.check_rounded
                  : Icons.volunteer_activism_rounded,
              color: viewerColor,
              loading: proposeState == PawProposeState.busy,
              enabled: proposeState == PawProposeState.idle,
              disabledReason: proposeState == PawProposeState.already
                  ? 'pawmap_request_already'.tr
                  : null,
              onTap: onPropose,
            ),
            SizedBox(height: 6.h),
            Center(
              child: Text(
                'pawmap_request_propose_sub'.tr,
                textAlign: TextAlign.center,
                style: PawMapTheme.fontOn(context,
                    size: 11.5.sp,
                    weight: FontWeight.w600,
                    color: PawMapTheme.subOn(context)),
              ),
            ),
            SizedBox(height: 4.h),
            Center(
              child: PawSignatureButton(
                key: const ValueKey<String>('request_owner_profile'),
                kind: PawButtonKind.link,
                label: 'pawmap_member_view_profile'.tr,
                icon: Icons.person_rounded,
                color: PawMapLegend.owner,
                expand: false,
                onTap: onOwnerProfile,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── VISIBILITÉ (mode amis seulement) ───────────────────────────────────────

class PawMapVisibilitySheet extends StatelessWidget {
  const PawMapVisibilitySheet({
    super.key,
    required this.friendsOnly,
    required this.saving,
    required this.onChanged,
  });

  final bool friendsOnly;
  final bool saving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option({
      required Key key,
      required bool value,
      required IconData icon,
      required String title,
      required String sub,
    }) {
      final bool selected = friendsOnly == value;
      final Color tone = value ? PawMapLegend.ink : PawMapLegend.walker;
      final bool isDark = PawMapTheme.isDark(context);
      final Color fg = selected
          ? Colors.white
          : (isDark ? PawMapTheme.lighten(tone, 0.4) : tone);
      return Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Semantics(
          button: true,
          selected: selected,
          label: title,
          child: GestureDetector(
            key: key,
            behavior: HitTestBehavior.opaque,
            onTap: saving ? null : () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: selected
                    ? tone
                    : tone.withValues(alpha: isDark ? 0.16 : 0.07),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                    color: selected ? tone : tone.withValues(alpha: 0.35),
                    width: 1.4),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.18)
                          : tone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(icon, color: fg, size: 20.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 2,
                            style: PawMapTheme.fontOn(context,
                                size: 14.sp,
                                weight: FontWeight.w800,
                                color: selected ? Colors.white : PawMapTheme.inkOn(context))),
                        Text(sub,
                            maxLines: 3,
                            style: PawMapTheme.fontOn(context,
                                size: 11.5.sp,
                                weight: FontWeight.w500,
                                color: selected
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : PawMapTheme.subOn(context))),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(
                      value ? Icons.visibility_off_rounded : Icons.check_rounded,
                      color: value ? PawMapLegend.gold : Colors.white,
                      size: 20.sp,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('pawmap_visibility_title'.tr,
              style: PawMapTheme.fontOn(context, size: 18.sp, weight: FontWeight.w800)),
          SizedBox(height: 12.h),
          option(
            key: const ValueKey<String>('visibility_all'),
            value: false,
            icon: Icons.public_rounded,
            title: 'pawmap_visibility_all'.tr,
            sub: 'profile_pref_hide_map_sub'.tr,
          ),
          option(
            key: const ValueKey<String>('visibility_friends'),
            value: true,
            icon: Icons.visibility_off_rounded,
            title: 'pawmap_visibility_friends'.tr,
            sub: 'pawmap_visibility_friends_sub'.tr,
          ),
          if (saving)
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: PawMapTheme.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pastille en haut de la carte quand je suis « visible par mes amis
/// seulement » : noir encre, chevron or. Un appui = redevenir visible.
class PawMapFriendsOnlyPill extends StatelessWidget {
  const PawMapFriendsOnlyPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'pawmap_visibility_pill'.tr,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(12.w, 8.h, 10.w, 8.h),
          decoration: BoxDecoration(
            color: PawMapLegend.ink,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: PawMapLegend.gold.withValues(alpha: 0.7)),
            boxShadow: PawMapTheme.pillShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility_off_rounded, size: 15.sp, color: PawMapLegend.gold),
              SizedBox(width: 7.w),
              Flexible(
                child: Text(
                  'pawmap_visibility_pill'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              Icon(Icons.chevron_right_rounded, size: 18.sp, color: PawMapLegend.gold),
            ],
          ),
        ),
      ),
    );
  }
}

// ── LÉGENDE « ? » ──────────────────────────────────────────────────────────

/// Une ligne de la légende : l'épingle (dessinée par le même peintre que la
/// carte) et son explication.
class PawLegendEntry {
  const PawLegendEntry({
    required this.key,
    required this.label,
    required this.width,
    required this.height,
    required this.paint,
  });

  final String key;
  final String label;
  final double width;
  final double height;
  final void Function(Canvas canvas) paint;
}

/// Les entrées de la légende, dans l'ordre de LEGENDE_PAWMAP.md.
List<PawLegendEntry> pawLegendEntries() {
  final ms = PawMapLegend.memberSize;
  return [
    PawLegendEntry(
      key: 'me',
      label: 'pawmap_legend_me'.tr,
      width: PawMapPinPainter.photoBitmapSize(PawMapLegend.meSize),
      height: PawMapPinPainter.photoBitmapSize(PawMapLegend.meSize, withLabel: true),
      paint: (c) => PawMapPinPainter.paintPhotoDot(c,
          avatar: null,
          ringColor: PawMapLegend.owner,
          size: PawMapLegend.meSize,
          label: 'pawmap_me_label'.tr,
          crownSize: PawMapLegend.crownMe),
    ),
    PawLegendEntry(
      key: 'friend',
      label: 'pawmap_legend_friend'.tr,
      width: PawMapPinPainter.photoBitmapSize(PawMapLegend.friendSize),
      height: PawMapPinPainter.photoBitmapSize(PawMapLegend.friendSize),
      paint: (c) => PawMapPinPainter.paintPhotoDot(c,
          avatar: null,
          ringColor: PawMapLegend.friend,
          size: PawMapLegend.friendSize,
          online: true,
          fallbackTint: PawMapLegend.friend),
    ),
    for (final role in const ['owner', 'sitter', 'walker'])
      PawLegendEntry(
        key: 'member_$role',
        label: 'pawmap_legend_$role'.tr,
        width: PawMapPinPainter.memberBitmapSize(ms),
        height: PawMapPinPainter.memberBitmapSize(ms),
        paint: (c) => PawMapPinPainter.paintMemberDot(c, role: role),
      ),
    PawLegendEntry(
      key: 'member_group',
      label: 'pawmap_legend_member_group'.tr,
      width: PawMapPinPainter.memberClusterWidth(12) + 12,
      height: PawMapLegend.memberClusterHeight + 12,
      paint: (c) => PawMapPinPainter.paintMemberCluster(c, 12,
          roleCounts: const {'owner': 5, 'sitter': 4, 'walker': 3}),
    ),
    PawLegendEntry(
      key: 'place',
      label: 'pawmap_legend_place'.tr,
      width: PawMapPinPainter.dropBitmapWidth(PawMapLegend.placeSize),
      height: PawMapPinPainter.dropHeight(PawMapLegend.placeSize),
      paint: (c) => PawMapPinPainter.paintPlaceDrop(c, category: 'vet'),
    ),
    PawLegendEntry(
      key: 'place_group',
      label: 'pawmap_legend_place_group'.tr,
      width: PawMapPinPainter.squareClusterBitmapSize(),
      height: PawMapPinPainter.squareClusterBitmapSize(),
      paint: (c) => PawMapPinPainter.paintSquareCluster(c, 8,
          tone: PawMapLegend.placeColor('park')),
    ),
    PawLegendEntry(
      key: 'spot',
      label: 'pawmap_legend_spot'.tr,
      width: PawMapPinPainter.dropBitmapWidth(PawMapLegend.spotSize),
      height: PawMapPinPainter.dropHeight(PawMapLegend.spotSize),
      paint: (c) => PawMapPinPainter.paintPawSpotDrop(c, type: 'path_walk'),
    ),
    PawLegendEntry(
      key: 'spot_gold',
      label: 'pawmap_legend_spot_gold'.tr,
      width: PawMapPinPainter.dropBitmapWidth(PawMapLegend.spotGoldSize),
      height: PawMapPinPainter.dropHeight(PawMapLegend.spotGoldSize),
      paint: (c) =>
          PawMapPinPainter.paintPawSpotDrop(c, type: 'path_walk', golden: true),
    ),
    PawLegendEntry(
      key: 'spot_group',
      label: 'pawmap_legend_spot_group'.tr,
      width: PawMapPinPainter.squareClusterBitmapSize(),
      height: PawMapPinPainter.squareClusterBitmapSize(),
      paint: (c) => PawMapPinPainter.paintSquareCluster(c, 4,
          tone: PawMapLegend.gold, black: true),
    ),
    PawLegendEntry(
      key: 'request',
      label: 'pawmap_legend_request'.tr,
      width: PawMapPinPainter.requestBubbleBitmapWidth(priceLabel: '25 €'),
      height: PawMapPinPainter.requestBubbleBitmapHeight(),
      paint: (c) => PawMapPinPainter.paintRequestBubble(c,
          priceLabel: '25 €', walking: false),
    ),
    PawLegendEntry(
      key: 'premium',
      label: 'pawmap_legend_premium'.tr,
      width: PawMapPinPainter.memberBitmapSize(ms),
      height: PawMapPinPainter.memberBitmapSize(ms),
      paint: (c) => PawMapPinPainter.paintMemberDot(c, role: 'sitter', crown: true),
    ),
    PawLegendEntry(
      key: 'boost',
      label: 'pawmap_legend_boost'.tr,
      width: PawMapPinPainter.memberBitmapSize(ms),
      height: PawMapPinPainter.memberBitmapSize(ms),
      paint: (c) =>
          PawMapPinPainter.paintMemberDot(c, role: 'walker', boostPhase: 0.25),
    ),
    PawLegendEntry(
      key: 'verified',
      label: 'pawmap_legend_verified'.tr,
      width: PawMapPinPainter.memberBitmapSize(ms),
      height: PawMapPinPainter.memberBitmapSize(ms),
      paint: (c) =>
          PawMapPinPainter.paintMemberDot(c, role: 'sitter', verified: true),
    ),
    PawLegendEntry(
      key: 'friends_only',
      label: 'pawmap_legend_friends_only'.tr,
      width: PawMapPinPainter.photoBitmapSize(PawMapLegend.meSize),
      height: PawMapPinPainter.photoBitmapSize(PawMapLegend.meSize),
      paint: (c) => PawMapPinPainter.paintPhotoDot(c,
          avatar: null,
          ringColor: PawMapLegend.owner,
          size: PawMapLegend.meSize,
          dashedRing: true,
          eyeOff: true),
    ),
  ];
}

class PawMapLegendSheet extends StatelessWidget {
  const PawMapLegendSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = pawLegendEntries();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 6.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('pawmap_legend_title'.tr,
                  style: PawMapTheme.fontOn(context,
                      size: 18.sp, weight: FontWeight.w800)),
              SizedBox(height: 6.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
                decoration: BoxDecoration(
                  color: PawMapLegend.ink,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Text(
                  'pawmap_legend_memo'.tr,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: PawMapLegend.gold,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 14.h),
            itemCount: entries.length + 1,
            separatorBuilder: (_, __) => SizedBox(height: 6.h),
            itemBuilder: (_, i) {
              if (i == entries.length) {
                // Signalement : inchangé (emoji du type), décrit sans image.
                return _LegendRow(
                  key: const ValueKey<String>('legend_report'),
                  label: 'pawmap_legend_report'.tr,
                  child: Icon(Icons.warning_amber_rounded,
                      size: 26.sp, color: PawMapTheme.danger),
                );
              }
              final e = entries[i];
              return _LegendRow(
                key: ValueKey<String>('legend_${e.key}'),
                label: e.label,
                child: PawPinPreview(entry: e),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88.w,
          height: 76.h,
          child: Center(child: child),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            label,
            maxLines: 3,
            style: PawMapTheme.fontOn(context,
                size: 13.sp, weight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Rendu d'une épingle de la légende (mêmes peintres que la carte).
class PawPinPreview extends StatefulWidget {
  const PawPinPreview({super.key, required this.entry});

  final PawLegendEntry entry;

  @override
  State<PawPinPreview> createState() => _PawPinPreviewState();
}

class _PawPinPreviewState extends State<PawPinPreview> {
  Uint8List? _png;

  @override
  void initState() {
    super.initState();
    renderPinPng(widget.entry.width, widget.entry.height, widget.entry.paint)
        .then((b) {
      if (mounted) setState(() => _png = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    final png = _png;
    if (png == null) {
      return SizedBox(width: widget.entry.width, height: widget.entry.height);
    }
    return Image.memory(
      png,
      width: widget.entry.width,
      height: widget.entry.height,
      filterQuality: FilterQuality.medium,
    );
  }
}

// ── LISTE « AUTOUR DE TOI » (idée 8 : compteur cliquable) ─────────────────

class PawMapAroundItem {
  const PawMapAroundItem({
    required this.id,
    required this.role,
    required this.name,
    required this.avatar,
    required this.distanceLabel,
    required this.priceLabel,
    this.premium = false,
    this.verified = false,
    this.availableToday = false,
  });

  final String id;
  final String role;
  final String name;
  final String avatar;
  final String distanceLabel;
  final String priceLabel;
  final bool premium;
  final bool verified;
  final bool availableToday;
}

class PawMapAroundList extends StatelessWidget {
  const PawMapAroundList({super.key, required this.items, required this.onTap});

  final List<PawMapAroundItem> items;
  final ValueChanged<PawMapAroundItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 6.h),
          child: Text(
            '${'pawmap_sheet_list_title'.tr} · ${items.length}',
            style: PawMapTheme.fontOn(context, size: 18.sp, weight: FontWeight.w800),
          ),
        ),
        Flexible(
          child: items.isEmpty
              ? Padding(
                  padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 22.h),
                  child: Text('pawmap_sheet_list_empty'.tr,
                      style: PawMapTheme.fontOn(context,
                          size: 13.sp,
                          weight: FontWeight.w600,
                          color: PawMapTheme.subOn(context))),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(10.w, 4.h, 10.w, 12.h),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => SizedBox(height: 4.h),
                  itemBuilder: (_, i) {
                    final it = items[i];
                    final color = PawMapLegend.roleColor(it.role);
                    final roleLabel = it.role == 'walker'
                        ? 'pawmap_legend_walker'.tr
                        : it.role == 'owner'
                            ? 'pawmap_legend_owner'.tr
                            : 'pawmap_legend_sitter'.tr;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: ValueKey<String>('around_${it.id}'),
                        borderRadius: BorderRadius.circular(14.r),
                        onTap: () => onTap(it),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                          child: Row(
                            children: [
                              Container(
                                width: 40.w,
                                height: 40.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                  image: it.avatar.startsWith('http')
                                      ? DecorationImage(
                                          image: NetworkImage(it.avatar),
                                          fit: BoxFit.cover)
                                      : null,
                                ),
                                child: it.avatar.startsWith('http')
                                    ? null
                                    : Icon(PawMapLegend.roleIcon(it.role),
                                        color: Colors.white, size: 20.sp),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            it.name.isEmpty ? roleLabel : it.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: PawMapTheme.fontOn(context,
                                                size: 14.sp,
                                                weight: FontWeight.w800),
                                          ),
                                        ),
                                        if (it.premium) ...[
                                          SizedBox(width: 4.w),
                                          Icon(Icons.workspace_premium_rounded,
                                              size: 15.sp, color: PawMapLegend.gold),
                                        ],
                                        if (it.verified) ...[
                                          SizedBox(width: 2.w),
                                          Icon(Icons.verified_rounded,
                                              size: 15.sp, color: PawMapLegend.sitter),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      [
                                        roleLabel,
                                        it.distanceLabel,
                                        if (it.availableToday)
                                          'pawmap_member_available_today'.tr,
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: PawMapTheme.fontOn(context,
                                          size: 11.5.sp,
                                          weight: FontWeight.w600,
                                          color: PawMapTheme.subOn(context)),
                                    ),
                                  ],
                                ),
                              ),
                              if (it.priceLabel.isNotEmpty)
                                Text(
                                  it.priceLabel,
                                  style: PawMapTheme.fontOn(context,
                                      size: 13.sp,
                                      weight: FontWeight.w800,
                                      color: AppColors.accentOn(context, color)),
                                ),
                              SizedBox(width: 4.w),
                              Icon(Icons.chevron_right_rounded,
                                  size: 20.sp, color: PawMapTheme.subOn(context)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
