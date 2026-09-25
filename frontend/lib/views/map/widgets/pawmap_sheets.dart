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
    this.liveState,
    this.seenLabel = '',
    this.onFollow,
    this.rates = const <PawMapRateLine>[],
  });

  final PawMapMemberData member;

  /// v584 (25/09) — ami : `live` / `lost` = « Suivre la balade » possible ;
  /// null = pas de partage en cours (« vu il y a X », explication).
  final PawFollowState? liveState;

  /// « 3 j », « 12 min » — dernier signe de vie connu (ami sans partage).
  final String seenLabel;
  final VoidCallback? onFollow;

  /// v584 (25/09, point 8) — les 2-3 tarifs principaux, avant « Réserver ».
  final List<PawMapRateLine> rates;
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
    bool primaryIsMessage = false;
    final bool canFollow = liveState != null && onFollow != null;
    if (canFollow) {
      // v584 (25/09, point 14) — un ami qui partage sa balade : le bouton
      // principal est « Suivre la balade · en direct » (violet PawFollow).
      primary = PawSignatureButton(
        key: const ValueKey<String>('member_primary_follow'),
        label: liveState == PawFollowState.lost
            ? 'pawmap_member_follow_lost'.tr
            : 'pawmap_member_follow_walk'.tr,
        icon: Icons.directions_walk_rounded,
        color: PawMapLegend.pawFollow,
        onTap: onFollow,
      );
    } else if (member.isProvider) {
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
    } else if (viewerLoggedIn && friendState == PawFriendState.friends) {
      // v585 (25/09, Daniel : « où sont passés Ajouter en ami, Message ? ») —
      // un AMI : l'action utile est « Message », jamais « Ajouter en ami » ni
      // un gros bouton « Déjà amis » inutile.
      primaryIsMessage = true;
      primary = PawSignatureButton(
        key: const ValueKey<String>('member_primary_message'),
        label: 'pawmap_member_message'.tr,
        icon: Icons.chat_bubble_rounded,
        color: PawMapLegend.friend,
        onTap: onMessage,
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
          if (member.isFriend && !canFollow && seenLabel.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Container(
              key: const ValueKey<String>('member_seen_line'),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: PawMapLegend.friend.withValues(alpha: PawMapTheme.isDark(context) ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('pawmap_member_seen_no_share'.trParams({'ago': seenLabel}),
                      style: PawMapTheme.fontOn(context, size: 12.5.sp, weight: FontWeight.w800)),
                  SizedBox(height: 2.h),
                  Text('pawmap_member_seen_explain'.trParams({'name': member.name}),
                      style: PawMapTheme.fontOn(context,
                          size: 11.5.sp, weight: FontWeight.w500, color: PawMapTheme.subOn(context), height: 1.3)),
                ],
              ),
            ),
          ],
          if (rates.isNotEmpty) ...[
            SizedBox(height: 10.h),
            PawMapRatesBlock(rates: rates, color: roleColor),
          ],
          SizedBox(height: 14.h),
          primary,
          if (canFollow && member.isProvider) ...[
            SizedBox(height: 8.h),
            PawSignatureButton(
              key: const ValueKey<String>('member_book_secondary'),
              kind: PawButtonKind.secondary,
              label: 'pawmap_member_book'.tr,
              price: viewerLoggedIn ? priceLabel : null,
              icon: Icons.event_available_rounded,
              color: roleColor,
              onTap: viewerLoggedIn ? onBook : onSignup,
            ),
          ],
          // v585 — la rangée Ami / Message, sauf quand « Message » est déjà
          // le bouton principal (ami propriétaire).
          if (!primaryIsMessage) ...[
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
          ],
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
            ),
            // BOB 25/09 — une photo absente ou qui ne charge pas laissait un
            // disque de couleur vide (vu sur la fiche « Rhoda Mia ») : l'icône
            // du rôle reste affichée tant que la photo n'est pas là.
            child: ClipOval(
              child: hasUrl
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(icon, color: Colors.white, size: 26.sp),
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Icon(icon, color: Colors.white, size: 26.sp),
                    )
                  : Icon(icon, color: Colors.white, size: 26.sp),
            ),
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

/// Une ligne de légende : l'épingle dessinée à gauche, sa phrase à droite.
/// Utilisée par l'écran « Comprendre la PawMap » (`PawMapHelpScreen`).
class PawLegendRow extends StatelessWidget {
  const PawLegendRow({super.key, required this.label, required this.child});

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

// ── v584 (25/09) — SUIVI EN DIRECT REFAIT : pilule discrète + feuille ──────
// Daniel : « “arrêter de suivre en direct”, c'est nul, le système est moche,
// la barre violette ». Plus de bandeau plein en haut de la carte : quand je
// suis quelqu'un, une PETITE PILULE flottante entre les rails, au-dessus de
// la feuille (sa photo en rond, « Jose · en direct · 12 s », un chevron) ;
// un appui ouvre une feuille courte : Reprendre / Recentrer, Arrêter de
// suivre, Itinéraire, Message. Jamais un bouton « Arrêter » criard.

/// État d'un ami en direct, tel que la carte le montre (règle serveur v584).
enum PawFollowState { live, lost, paused }

class PawMapFollowPill extends StatelessWidget {
  const PawMapFollowPill({
    super.key,
    required this.name,
    required this.avatar,
    required this.role,
    required this.state,
    required this.agoLabel,
    required this.onTap,
  });

  final String name;
  final String avatar;
  final String role;
  final PawFollowState state;

  /// « 12 s », « 3 min » — âge du dernier signe de vie.
  final String agoLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tone = switch (state) {
      PawFollowState.live => PawMapLegend.pawFollow,
      PawFollowState.lost => const Color(0xFFE8920A),
      PawFollowState.paused => PawMapLegend.ink,
    };
    final String stateLabel = switch (state) {
      PawFollowState.live => 'pawmap_follow_pill_live'.tr,
      PawFollowState.lost => 'pawmap_follow_pill_lost'.tr,
      PawFollowState.paused => 'pawmap_follow_pill_paused'.tr,
    };
    final bool hasUrl = avatar.startsWith('http');
    return Semantics(
      button: true,
      label: '$name · $stateLabel',
      child: GestureDetector(
        key: const ValueKey<String>('pawmap_follow_pill'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: 44.h, maxWidth: 300.w),
          padding: EdgeInsets.fromLTRB(5.w, 4.h, 10.w, 4.h),
          decoration: BoxDecoration(
            color: PawMapTheme.panelOn(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tone.withValues(alpha: 0.55), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: tone.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tone,
                ),
                child: ClipOval(
                  child: hasUrl
                      ? Image.network(avatar, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _roleGlyph(role))
                      : _roleGlyph(role),
                ),
              ),
              SizedBox(width: 8.w),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PawMapTheme.fontOn(context,
                          size: 12.5.sp, weight: FontWeight.w800),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LiveDot(color: tone, breathing: state == PawFollowState.live),
                        SizedBox(width: 4.w),
                        Flexible(
                          child: Text(
                            '$stateLabel · $agoLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PawMapTheme.font(
                                size: 10.5.sp,
                                weight: FontWeight.w700,
                                color: AppColors.accentOn(context, tone)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              Icon(Icons.expand_less_rounded, size: 20.sp, color: AppColors.accentOn(context, tone)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleGlyph(String role) => ColoredBox(
        color: PawMapLegend.roleColor(role),
        child: Icon(PawMapLegend.roleIcon(role), color: Colors.white, size: 18.sp),
      );
}

/// Point (rond) qui respire quand c'est en direct.
class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color, required this.breathing});
  final Color color;
  final bool breathing;
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.breathing) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _LiveDot old) {
    super.didUpdateWidget(old);
    if (widget.breathing && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.breathing && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = reduce ? 0.5 : _c.value;
        return Container(
          width: 7.w,
          height: 7.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: widget.breathing
                ? [BoxShadow(color: widget.color.withValues(alpha: 0.35 + 0.35 * t), blurRadius: 4 + 5 * t, spreadRadius: 1 + 1.5 * t)]
                : null,
          ),
        );
      },
    );
  }
}

/// Feuille du suivi : Reprendre / Recentrer · Arrêter de suivre · Itinéraire ·
/// Message. Sobre, à la couleur PawFollow, jamais criarde.
class PawMapFollowSheet extends StatelessWidget {
  const PawMapFollowSheet({
    super.key,
    required this.name,
    required this.avatar,
    required this.role,
    required this.state,
    required this.agoLabel,
    required this.onResume,
    required this.onStop,
    required this.onDirections,
    required this.onMessage,
  });

  final String name;
  final String avatar;
  final String role;
  final PawFollowState state;
  final String agoLabel;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback? onDirections;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final Color tone = state == PawFollowState.lost ? const Color(0xFFE8920A) : PawMapLegend.pawFollow;
    final String stateLabel = switch (state) {
      PawFollowState.live => 'pawmap_follow_pill_live'.tr,
      PawFollowState.lost => 'pawmap_follow_pill_lost'.tr,
      PawFollowState.paused => 'pawmap_follow_pill_paused'.tr,
    };
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(
                url: avatar,
                ring: PawMapLegend.friend,
                icon: PawMapLegend.roleIcon(role),
                crown: false,
                online: state == PawFollowState.live,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 2,
                        style: PawMapTheme.fontOn(context, size: 17.sp, weight: FontWeight.w800)),
                    SizedBox(height: 3.h),
                    Row(children: [
                      _LiveDot(color: tone, breathing: state == PawFollowState.live),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text('$stateLabel · $agoLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PawMapTheme.font(
                                size: 12.5.sp,
                                weight: FontWeight.w700,
                                color: AppColors.accentOn(context, tone))),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            'pawmap_follow_sheet_hint'.trParams({'name': name}),
            style: PawMapTheme.fontOn(context,
                size: 12.sp, weight: FontWeight.w500, color: PawMapTheme.subOn(context), height: 1.35),
          ),
          SizedBox(height: 14.h),
          PawSignatureButton(
            key: const ValueKey<String>('follow_sheet_resume'),
            label: state == PawFollowState.paused
                ? 'pawmap_follow_resume'.tr
                : 'pawmap_follow_sheet_recenter'.trParams({'name': name}),
            icon: state == PawFollowState.paused ? Icons.play_arrow_rounded : Icons.my_location_rounded,
            color: PawMapLegend.pawFollow,
            onTap: onResume,
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              if (onDirections != null) ...[
                Expanded(
                  child: PawSignatureButton(
                    key: const ValueKey<String>('follow_sheet_directions'),
                    kind: PawButtonKind.secondary,
                    label: 'pawmap_btn_directions'.tr,
                    icon: Icons.directions_rounded,
                    color: PawMapLegend.walker,
                    onTap: onDirections,
                  ),
                ),
                SizedBox(width: 8.w),
              ],
              Expanded(
                child: PawSignatureButton(
                  key: const ValueKey<String>('follow_sheet_message'),
                  kind: PawButtonKind.secondary,
                  label: 'pawmap_member_message'.tr,
                  icon: Icons.chat_bubble_rounded,
                  color: PawMapLegend.sitter,
                  onTap: onMessage,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Center(
            child: PawSignatureButton(
              key: const ValueKey<String>('follow_sheet_stop'),
              kind: PawButtonKind.link,
              label: 'pawmap_follow_sheet_stop'.tr,
              icon: Icons.stop_circle_outlined,
              color: PawMapLegend.ink,
              expand: false,
              onTap: onStop,
            ),
          ),
        ],
      ),
    );
  }
}

// ── v584 (25/09, point 12) — PUCES D'ÉTAT dans la feuille ─────────────────
// Plus rien n'est posé sur les boutons du haut : « visible par tes amis
// seulement » et « en direct » vivent ici, sous le bouton principal.
class PawMapStatusChip extends StatelessWidget {
  const PawMapStatusChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.breathing = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool breathing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: 30.h),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: PawMapTheme.isDark(context) ? 0.22 : 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (breathing)
                _LiveDot(color: color, breathing: true)
              else
                Icon(icon, size: 14.sp, color: AppColors.accentOn(context, color)),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PawMapTheme.font(
                      size: 11.sp,
                      weight: FontWeight.w800,
                      color: AppColors.accentOn(context, color)),
                ),
              ),
              SizedBox(width: 2.w),
              Icon(Icons.chevron_right_rounded, size: 16.sp, color: AppColors.accentOn(context, color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── v584 (25/09, point 15) — LISTE D'UN GROUPE (membres ou lieux) ──────────
// Quand les épingles restent superposées au zoom max, le carré de groupe
// ouvre cette feuille : photo / icône, nom, rôle ou type, « Voir ».
class PawMapClusterItem {
  const PawMapClusterItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.color,
    this.avatar = '',
    this.icon,
  });
  final String id;
  final String title;
  final String subtitle;
  final Color color;
  final String avatar;
  final IconData? icon;
}

class PawMapClusterList extends StatelessWidget {
  const PawMapClusterList({
    super.key,
    required this.title,
    required this.items,
    required this.onOpen,
  });
  final String title;
  final List<PawMapClusterItem> items;
  final ValueChanged<PawMapClusterItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 6.h),
          child: Text(title,
              style: PawMapTheme.fontOn(context, size: 16.sp, weight: FontWeight.w800)),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 12.h),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(height: 6.h),
            itemBuilder: (ctx, i) {
              final it = items[i];
              final bool hasUrl = it.avatar.startsWith('http');
              return Semantics(
                button: true,
                label: it.title,
                child: InkWell(
                  key: ValueKey<String>('cluster_item_${it.id}'),
                  borderRadius: BorderRadius.circular(16.r),
                  onTap: () => onOpen(it),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: it.color.withValues(alpha: PawMapTheme.isDark(ctx) ? 0.16 : 0.07),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.w,
                          padding: EdgeInsets.all(2.w),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: it.color),
                          child: ClipOval(
                            child: hasUrl
                                ? Image.network(it.avatar, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(it.icon ?? Icons.place_rounded, color: Colors.white, size: 20.sp))
                                : Icon(it.icon ?? Icons.place_rounded, color: Colors.white, size: 20.sp),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PawMapTheme.fontOn(ctx, size: 14.sp, weight: FontWeight.w800)),
                              Text(it.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PawMapTheme.fontOn(ctx,
                                      size: 11.5.sp, weight: FontWeight.w600, color: PawMapTheme.subOn(ctx))),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text('pawmap_cluster_open'.tr,
                            style: PawMapTheme.font(
                                size: 12.sp, weight: FontWeight.w800, color: AppColors.accentOn(ctx, it.color))),
                        Icon(Icons.chevron_right_rounded, size: 18.sp, color: AppColors.accentOn(ctx, it.color)),
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

// ── v584 (25/09, point 8) — TARIFS sur la fiche courte ─────────────────────
/// Une ligne de tarif (« Prix / jour · 35 € ») déjà formatée par l'écran.
class PawMapRateLine {
  const PawMapRateLine({required this.label, required this.value});
  final String label;
  final String value;
}

class PawMapRatesBlock extends StatelessWidget {
  const PawMapRatesBlock({super.key, required this.rates, required this.color});
  final List<PawMapRateLine> rates;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (rates.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey<String>('member_rates'),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: PawMapTheme.isDark(context) ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          for (final r in rates)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 3.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(r.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PawMapTheme.fontOn(context, size: 12.5.sp, weight: FontWeight.w600)),
                  ),
                  Text(r.value,
                      style: PawMapTheme.font(
                          size: 13.5.sp, weight: FontWeight.w800, color: AppColors.accentOn(context, color))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
