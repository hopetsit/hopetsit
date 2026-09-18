// v566 — onglet « Famille PawFollow » : membres (jusqu'à 5), invitations
// reçues / envoyées, inviter depuis ses amis ou par e-mail, quitter / retirer
// avec confirmation, bandeau clair quand l'abonnement Famille est requis
// (→ boutique). Violet = code couleur Famille (halo PawMap, 4e orteil du logo).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/friends/tabs/friends_ui.dart';
import 'package:hopetsit/views/friends/tabs/requests_tab.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

const int _kFamilyMax = 5;

String _familyErrorLabel(String code) {
  switch (code) {
    case 'FAMILY_FULL':
      return 'family_err_full'.tr;
    case 'ALREADY_MEMBER':
      return 'family_err_already_member'.tr;
    case 'FAMILY_PLAN_REQUIRED':
      return 'family_err_plan_required'.tr;
  }
  return code;
}

class FamilyTab extends StatelessWidget {
  const FamilyTab({super.key, required this.controller});
  final FriendController controller;

  Future<void> _refresh() async {
    await Future.wait([
      controller.loadFamily(),
      controller.loadFamilyInvitations(),
    ]);
  }

  void _openShop() => Get.to(() => const CoinShopScreen(initialTab: 1));

  @override
  Widget build(BuildContext context) {
    const accent = kFamilyViolet;
    return RefreshIndicator(
      color: accent,
      onRefresh: _refresh,
      child: Obx(() {
        final hasPlan = controller.hasFamilyPlan.value;
        final isHolder = controller.isFamilyHolder.value;
        final holderName =
            (controller.familyHolder.value?['name'] ?? '').toString();
        final members = controller.familyMembers.toList();
        final invites = controller.incomingFamilyInvitations.toList();
        // ignore: unused_local_variable
        final presenceTick = controller.onlineById.length;

        if (controller.isLoadingFamily.value && !hasPlan && members.isEmpty) {
          return const FriendsSkeletonList(count: 3);
        }
        if (controller.familyLoadFailed.value && members.isEmpty) {
          return FriendsStateView.loadError(accent: accent, onRetry: _refresh);
        }

        final active =
            members.where((m) => (m['status'] ?? 'active') != 'pending').toList();
        final pending =
            members.where((m) => (m['status'] ?? 'active') == 'pending').toList();

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w,
              24.h + MediaQuery.of(context).viewPadding.bottom),
          children: [
            if (!hasPlan)
              _PlanRequiredCard(onTap: _openShop)
            else
              _FamilyHeroCard(count: members.length),
            SizedBox(height: 16.h),

            // Invitations REÇUES — visibles même sans abonnement (on peut
            // être invité dans la famille de quelqu'un d'autre).
            if (invites.isNotEmpty) ...[
              FriendsSectionHeader(
                title: 'friends566_family_invites_received'.tr,
                count: invites.length,
                color: accent,
              ),
              for (final inv in invites)
                FamilyInvitationCard(
                  key: ValueKey(
                      'faminv_${inv['id'] ?? inv['invitationId'] ?? inv.hashCode}'),
                  invitation: inv,
                  controller: controller,
                ),
              SizedBox(height: 6.h),
            ],

            if (hasPlan) ...[
              // v23.1.281 — MEMBRE (pas titulaire) : pas d'UI d'invitation
              // (elle échouerait), bandeau + « Quitter la famille ».
              if (!isHolder) ...[
                _MemberOfCard(
                  holderName: holderName,
                  controller: controller,
                ),
                SizedBox(height: 16.h),
              ] else if (members.length < _kFamilyMax) ...[
                FriendsSectionHeader(title: 'family_invite_section_title'.tr),
                FriendsCard(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Column(
                    children: [
                      ProfileRow(
                        icon: Icons.group_rounded,
                        title: 'family_add_from_friends'.tr,
                        subtitle: 'family_add_from_friends_sub'.tr,
                        color: accent,
                        onTap: () => showFamilyPickFriendSheet(
                            context, controller,
                            focusSearch: false),
                      ),
                      Divider(
                          height: 1,
                          indent: 60.w,
                          color: AppColors.divider(context)),
                      ProfileRow(
                        icon: Icons.person_search_rounded,
                        title: 'family_add_by_name'.tr,
                        subtitle: 'family_invite_by_name_sub'.tr,
                        color: accent,
                        onTap: () => showFamilyPickFriendSheet(
                            context, controller,
                            focusSearch: true),
                      ),
                      Divider(
                          height: 1,
                          indent: 60.w,
                          color: AppColors.divider(context)),
                      ProfileRow(
                        icon: Icons.mail_outline_rounded,
                        title: 'family_add_by_email'.tr,
                        subtitle: 'family_invite_by_email_sub'.tr,
                        color: accent,
                        onTap: () =>
                            showFamilyInviteByEmailSheet(context, controller),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
              ] else ...[
                ProfileInfoBanner(
                  icon: Icons.groups_rounded,
                  text: 'family_full_msg'.tr,
                  accent: accent,
                ),
                SizedBox(height: 16.h),
              ],

              if (active.isNotEmpty) ...[
                FriendsSectionHeader(
                  title: 'family_members_list_title'.tr,
                  count: active.length,
                  color: accent,
                ),
                for (final m in active)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: FamilyMemberCard(
                      key: ValueKey('fam_${m['id']}'),
                      member: m,
                      controller: controller,
                      isHolder: isHolder,
                      online: controller.onlineById[(m['id'] ?? '').toString()],
                    ),
                  ),
              ],
              if (pending.isNotEmpty) ...[
                FriendsSectionHeader(
                  title: 'friends566_family_invites_sent'.tr,
                  count: pending.length,
                ),
                for (final m in pending)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: FamilyMemberCard(
                      key: ValueKey('fampending_${m['id']}'),
                      member: m,
                      controller: controller,
                      isHolder: isHolder,
                      online: null,
                    ),
                  ),
              ],
              if (members.isEmpty)
                ProfileEmptyState(
                  icon: Icons.family_restroom_rounded,
                  title: 'friends566_family_empty_title'.tr,
                  message: 'friends566_family_empty_msg'.tr,
                  accent: accent,
                ),
            ],
          ],
        );
      }),
    );
  }
}

// ── Abonnement requis ────────────────────────────────────────────────────

class _PlanRequiredCard extends StatelessWidget {
  const _PlanRequiredCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: kFamilyViolet.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(Icons.family_restroom_rounded,
                    color: Colors.white, size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: PoppinsText(
                  text: 'family_no_plan_title'.tr,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  maxLines: 3,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          InterText(
            text: 'family_no_plan_desc'.tr,
            fontSize: 12.5.sp,
            color: Colors.white.withValues(alpha: 0.92),
            height: 1.4,
            maxLines: 8,
          ),
          SizedBox(height: 16.h),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: 48.h,
                width: double.infinity,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_bag_rounded,
                        color: kFamilyViolet, size: 18.sp),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: PoppinsText(
                        text: 'family_no_plan_cta'.tr,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: kFamilyViolet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte d'en-tête « Famille active » ───────────────────────────────────

class _FamilyHeroCard extends StatelessWidget {
  const _FamilyHeroCard({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final n = count.clamp(0, _kFamilyMax);
    return FriendsCard(
      tint: kFamilyViolet,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(15.r),
                ),
                child:
                    Icon(Icons.shield_rounded, color: Colors.white, size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: 'family_active_title'.tr,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: kFamilyViolet,
                      maxLines: 2,
                    ),
                    SizedBox(height: 2.h),
                    InterText(
                      text: '$n / $_kFamilyMax ${'family_members_added'.tr}',
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Jauge des 5 places.
          Row(
            children: [
              for (int i = 0; i < _kFamilyMax; i++) ...[
                Expanded(
                  child: Container(
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: i < n
                          ? kFamilyViolet
                          : kFamilyViolet.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                if (i < _kFamilyMax - 1) SizedBox(width: 4.w),
              ],
            ],
          ),
          SizedBox(height: 10.h),
          InterText(
            text: 'family_active_desc'.tr,
            fontSize: 12.sp,
            color: AppColors.textSecondary(context),
            height: 1.4,
            maxLines: 6,
          ),
        ],
      ),
    );
  }
}

// ── « Tu es dans la famille de X » + Quitter ─────────────────────────────

class _MemberOfCard extends StatefulWidget {
  const _MemberOfCard({required this.holderName, required this.controller});
  final String holderName;
  final FriendController controller;

  @override
  State<_MemberOfCard> createState() => _MemberOfCardState();
}

class _MemberOfCardState extends State<_MemberOfCard> {
  bool _busy = false;

  Future<void> _leave() async {
    final confirmed = await confirmFriendsAction(
      context,
      title: 'family_leave_button'.tr,
      message: 'family_leave_confirm_desc'.tr,
      confirmLabel: 'family_leave_button'.tr,
      accent: kFamilyViolet,
      icon: Icons.logout_rounded,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    // POST /friends/family/leave
    final ok = await widget.controller.leaveFamily();
    if (mounted) setState(() => _busy = false);
    if (ok) {
      CustomSnackbar.showSuccess(
        title: 'family_leave_button'.tr,
        message: 'family_left_msg'.tr,
      );
    } else {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'friends566_error_msg'.tr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FriendsCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  color: kFamilyViolet, size: 20.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InterText(
                      text: widget.holderName.isEmpty
                          ? 'family_you_are_member_generic'.tr
                          : 'family_you_are_member'
                              .trParams({'name': widget.holderName}),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: kFamilyViolet,
                      maxLines: 3,
                    ),
                    SizedBox(height: 4.h),
                    InterText(
                      text: 'family_member_only_hint'.tr,
                      fontSize: 12.sp,
                      color: AppColors.textSecondary(context),
                      height: 1.4,
                      maxLines: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Align(
            alignment: Alignment.centerLeft,
            child: FriendsPillButton(
              label: 'family_leave_button'.tr,
              icon: Icons.logout_rounded,
              color: AppColors.errorColor,
              loading: _busy,
              onTap: _busy ? null : _leave,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte d'un membre ────────────────────────────────────────────────────

class FamilyMemberCard extends StatefulWidget {
  const FamilyMemberCard({
    super.key,
    required this.member,
    required this.controller,
    required this.isHolder,
    required this.online,
  });

  final Map<String, dynamic> member;
  final FriendController controller;

  /// v23.1.281 — seul le titulaire peut retirer un membre.
  final bool isHolder;

  /// null = présence inconnue (pas de point).
  final bool? online;

  @override
  State<FamilyMemberCard> createState() => _FamilyMemberCardState();
}

class _FamilyMemberCardState extends State<FamilyMemberCard> {
  bool _chatBusy = false;
  bool _followBusy = false;
  bool _removeBusy = false;

  String get _id => (widget.member['id'] ?? '').toString();
  String get _name => (widget.member['name'] ?? '').toString();
  String get _role => (widget.member['role'] ?? '').toString();
  String get _displayName =>
      _name.isEmpty ? 'friends566_family_member_fallback'.tr : _name;

  Future<void> _remove(bool isPending) async {
    final confirmed = await confirmFriendsAction(
      context,
      title: isPending
          ? 'friends566_family_cancel_invite_title'.tr
          : 'friends566_family_remove_title'.tr,
      message: (isPending
              ? 'friends566_family_cancel_invite_desc'
              : 'friends566_family_remove_desc')
          .trParams({'name': _displayName}),
      confirmLabel: isPending
          ? 'friends566_family_cancel_invite'.tr
          : 'family_remove_member_tooltip'.tr,
      accent: kFamilyViolet,
      icon: Icons.person_remove_rounded,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _removeBusy = true);
    // DELETE /friends/family/member/:userId (v23.1.329 — erreur affichée).
    final err = await widget.controller.removeFamilyMember(_id);
    if (mounted) setState(() => _removeBusy = false);
    if (err == null) {
      CustomSnackbar.showSuccess(
        title: 'family_member_removed_title'.tr,
        message: 'family_member_removed_msg'.trParams({'name': _displayName}),
      );
    } else {
      CustomSnackbar.showError(title: 'common_error'.tr, message: err);
    }
  }

  Future<void> _follow() async {
    if (_id.isEmpty) return;
    setState(() => _followBusy = true);
    try {
      // v23.1.266 — la famille est toujours suivable (PawFollow Famille).
      await openPawMapOnMember(userId: _id, role: _role, name: _name);
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _chat() async {
    setState(() => _chatBusy = true);
    try {
      await openFriendChatRoleAware(
        controller: widget.controller,
        other: FriendProfile(
          id: _id,
          model: _role,
          name: _displayName,
          avatar: (widget.member['avatar'] ?? '').toString(),
        ),
      );
    } finally {
      if (mounted) setState(() => _chatBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final avatar = (m['avatar'] ?? '').toString();
    final isPending = (m['status'] ?? 'active').toString() == 'pending';
    // v23.1.336 — retirable seulement si le backend le dit (sinon 404).
    final removable = m['removable'] == true;
    final roleColor = friendRoleColor(_role);
    final pawSpot = pawSpotRingColor((m['pawSpotTier'] ?? '').toString());
    final hasId = _id.isNotEmpty;

    return FriendsCard(
      onTap: hasId && !isPending ? _follow : null,
      child: Column(
        children: [
          Row(
            children: [
              FriendAvatar(
                imageUrl: avatar,
                ringColor: pawSpot ?? kFamilyViolet,
                online: isPending ? null : widget.online,
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
                            text: _displayName,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (m['isPremium'] == true) ...[
                          SizedBox(width: 4.w),
                          Text('👑', style: TextStyle(fontSize: 12.sp)),
                        ],
                      ],
                    ),
                    SizedBox(height: 5.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 4.h,
                      children: [
                        FriendsBadge(
                          label: friendRoleLabel(_role),
                          color: roleColor,
                        ),
                        FriendsBadge(
                          label: 'friends_tab_family'.tr,
                          color: kFamilyViolet,
                        ),
                        if (pawSpot != null)
                          FriendsBadge(label: 'PawSpot', color: pawSpot),
                        if (isPending)
                          FriendsBadge(
                            label: 'family_member_pending'.tr,
                            color: const Color(0xFFB45309),
                            icon: Icons.hourglass_top_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasId) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                if (!isPending) ...[
                  Expanded(
                    child: FriendsPillButton(
                      label: 'friends566_action_message'.tr,
                      icon: Icons.chat_bubble_rounded,
                      color: kFamilyViolet,
                      filled: true,
                      expand: true,
                      loading: _chatBusy,
                      onTap: _chat,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: FriendsPillButton(
                      label: 'friends566_action_follow'.tr,
                      icon: Icons.near_me_rounded,
                      color: kFamilyViolet,
                      expand: true,
                      loading: _followBusy,
                      onTap: _follow,
                    ),
                  ),
                ],
                if (widget.isHolder && removable) ...[
                  if (!isPending) SizedBox(width: 8.w),
                  Expanded(
                    child: FriendsPillButton(
                      label: isPending
                          ? 'friends566_family_cancel_invite'.tr
                          : 'friends566_remove_short'.tr,
                      icon: Icons.person_remove_rounded,
                      color: isPending
                          ? AppColors.textSecondary(context)
                          : AppColors.errorColor,
                      expand: true,
                      loading: _removeBusy,
                      onTap: _removeBusy ? null : () => _remove(isPending),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Feuille « Depuis mes amis » / « Par nom » ────────────────────────────

/// v23.1 part 251 — choisir un membre parmi ses amis acceptés (hors membres
/// déjà présents). `focusSearch` = entrée « Par nom » (champ actif d'emblée).
void showFamilyPickFriendSheet(
  BuildContext context,
  FriendController controller, {
  required bool focusSearch,
}) {
  showProfileSheet<void>(
    context,
    builder: (ctx) => _FamilyPickFriendSheet(
      controller: controller,
      focusSearch: focusSearch,
    ),
  );
}

class _FamilyPickFriendSheet extends StatefulWidget {
  const _FamilyPickFriendSheet({
    required this.controller,
    required this.focusSearch,
  });
  final FriendController controller;
  final bool focusSearch;

  @override
  State<_FamilyPickFriendSheet> createState() => _FamilyPickFriendSheetState();
}

class _FamilyPickFriendSheetState extends State<_FamilyPickFriendSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final RxString _query = ''.obs;
  final RxSet<String> _busy = <String>{}.obs;

  @override
  void initState() {
    super.initState();
    if (widget.focusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _invite(FriendProfile other) async {
    _busy.add(other.id);
    final navigator = Navigator.of(context);
    // POST /friends/family/invite-member { userId, userRole }
    final err = await widget.controller.addFamilyMember(
      userId: other.id,
      userRole: other.model.toLowerCase(),
    );
    _busy.remove(other.id);
    if (err.isEmpty) {
      if (mounted) navigator.pop();
      CustomSnackbar.showSuccess(
        title: 'family_invite_sent_title'.tr,
        message: 'family_invite_sent_msg'.trParams({'name': other.name}),
      );
    } else {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: _familyErrorLabel(err),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
        child: Column(
          children: [
            FriendsSheetHeader(
              title: widget.focusSearch
                  ? 'family_add_by_name'.tr
                  : 'family_add_from_friends'.tr,
              icon: Icons.group_rounded,
              color: kFamilyViolet,
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _searchCtrl,
              focusNode: _focus,
              onChanged: (v) => _query.value = v,
              cursorColor: kFamilyViolet,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                  fontSize: 14.sp, color: AppColors.textPrimary(context)),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.card(context),
                hintText: 'friends566_search_hint'.tr,
                hintStyle:
                    TextStyle(fontSize: 13.5.sp, color: AppColors.greyText),
                prefixIcon: Icon(Icons.search_rounded,
                    color: kFamilyViolet, size: 20.sp),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 12.h),
              ),
            ),
            SizedBox(height: 10.h),
            Expanded(
              child: Obx(() {
                final familyIds = controller.familyMembers
                    .map((m) => (m['id'] ?? m['userId'] ?? '').toString())
                    .toSet();
                final q = _query.value.trim().toLowerCase();
                // ignore: unused_local_variable
                final busyTick = _busy.length;
                final candidates = controller.friends
                    .where((f) =>
                        f.status == 'accepted' &&
                        (f.other?.id.isNotEmpty ?? false) &&
                        !familyIds.contains(f.other!.id) &&
                        (q.isEmpty ||
                            f.other!.name.toLowerCase().contains(q)))
                    .toList();
                if (candidates.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: InterText(
                        text: q.isEmpty
                            ? 'family_add_from_friends_empty'.tr
                            : 'friends566_no_match'.tr,
                        fontSize: 13.sp,
                        color: AppColors.textSecondary(context),
                        textAlign: TextAlign.center,
                        maxLines: 5,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (_, i) {
                    final other = candidates[i].other!;
                    final roleColor = friendRoleColor(other.model);
                    return FriendsCard(
                      padding: EdgeInsets.all(10.w),
                      child: Row(
                        children: [
                          FriendAvatar(
                            imageUrl: other.avatar,
                            ringColor: roleColor,
                            size: 40,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InterText(
                                  text: other.name.isEmpty
                                      ? 'common_user'.tr
                                      : other.name,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary(context),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 3.h),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FriendsBadge(
                                    label: friendRoleLabel(other.model),
                                    color: roleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 120.w),
                            child: FriendsPillButton(
                              label: 'family_invite_btn'.tr,
                              color: kFamilyViolet,
                              filled: true,
                              loading: _busy.contains(other.id),
                              onTap: () => _invite(other),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feuille « Par e-mail » ───────────────────────────────────────────────

/// v23.1.174 — invite par e-mail : membre HoPetSit existant OU invitation
/// d'inscription envoyée par e-mail (`POST /friends/family/invite-by-email`).
void showFamilyInviteByEmailSheet(
    BuildContext context, FriendController controller) {
  showProfileSheet<void>(
    context,
    builder: (ctx) => _FamilyInviteByEmailSheet(controller: controller),
  );
}

class _FamilyInviteByEmailSheet extends StatefulWidget {
  const _FamilyInviteByEmailSheet({required this.controller});
  final FriendController controller;

  @override
  State<_FamilyInviteByEmailSheet> createState() =>
      _FamilyInviteByEmailSheetState();
}

class _FamilyInviteByEmailSheetState extends State<_FamilyInviteByEmailSheet> {
  final _emailCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!valid) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'family_invite_invalid_email'.tr,
      );
      return;
    }
    setState(() => _sending = true);
    final navigator = Navigator.of(context);
    final mode = await widget.controller.addFamilyMemberByEmail(email);
    if (mounted) setState(() => _sending = false);
    if (mode == 'existing_user') {
      if (mounted) navigator.pop();
      CustomSnackbar.showSuccess(
        title: 'family_member_added_title'.tr,
        message: 'family_invite_existing_user_msg'.tr,
      );
    } else if (mode == 'email_invite_sent') {
      if (mounted) navigator.pop();
      CustomSnackbar.showSuccess(
        title: 'family_invite_sent'.tr,
        message: 'family_invite_email_sent_msg'.trParams({'email': email}),
      );
    } else {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: _familyErrorLabel(mode),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FriendsSheetHeader(
            title: 'family_add_by_email'.tr,
            icon: Icons.mail_outline_rounded,
            color: kFamilyViolet,
          ),
          SizedBox(height: 6.h),
          InterText(
            text: 'family_add_by_email_desc'.tr,
            fontSize: 12.5.sp,
            color: AppColors.textSecondary(context),
            height: 1.4,
            maxLines: 6,
          ),
          SizedBox(height: 14.h),
          ProfileInput(
            label: 'friends566_email_label'.tr,
            controller: _emailCtrl,
            accent: kFamilyViolet,
            hint: 'friends566_email_hint'.tr,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            autofocus: true,
          ),
          SizedBox(height: 16.h),
          ProfilePrimaryButton(
            label: 'family_invite_send_btn'.tr,
            accent: kFamilyViolet,
            icon: Icons.send_rounded,
            loading: _sending,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}
