// v566 — onglet « Demandes » : reçues (Accepter vert / Refuser gris, état de
// chargement PAR LIGNE, disparition animée) et envoyées (« En attente » +
// Annuler). Les invitations Famille reçues y figurent aussi : c'est une
// demande comme une autre pour l'utilisateur.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/friends/tabs/friends_ui.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class RequestsTab extends StatelessWidget {
  const RequestsTab({
    super.key,
    required this.controller,
    required this.accent,
    required this.onAdd,
  });

  final FriendController controller;
  final Color accent;

  /// État vide → « Ajouter un ami ».
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: accent,
      onRefresh: controller.refresh,
      child: Obx(() {
        final incoming = controller.incomingRequests.toList();
        final outgoing = controller.outgoingRequests
            .where((f) => f.status == 'pending')
            .toList();
        final familyInvites = controller.incomingFamilyInvitations.toList();
        final empty =
            incoming.isEmpty && outgoing.isEmpty && familyInvites.isEmpty;

        if (controller.isLoading.value && empty) {
          return const FriendsSkeletonList(count: 3);
        }
        if (controller.loadFailed.value && empty) {
          return FriendsStateView.loadError(
            accent: accent,
            onRetry: controller.refresh,
          );
        }
        if (empty) {
          return FriendsStateView(
            icon: Icons.mark_email_read_rounded,
            title: 'friends566_requests_empty_title'.tr,
            message: 'friends566_requests_empty_msg'.tr,
            accent: accent,
            actionLabel: 'friends566_invite_cta'.tr,
            onAction: onAdd,
          );
        }
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w,
              24.h + MediaQuery.of(context).viewPadding.bottom),
          children: [
            if (incoming.isNotEmpty || familyInvites.isNotEmpty) ...[
              FriendsSectionHeader(
                title: 'friends566_received'.tr,
                count: incoming.length + familyInvites.length,
                color: accent,
              ),
              for (final f in incoming)
                IncomingRequestCard(
                  key: ValueKey('in_${f.id}'),
                  friendship: f,
                  controller: controller,
                  accent: accent,
                ),
              for (final inv in familyInvites)
                FamilyInvitationCard(
                  key: ValueKey(
                      'fam_${inv['id'] ?? inv['invitationId'] ?? inv.hashCode}'),
                  invitation: inv,
                  controller: controller,
                ),
              SizedBox(height: 10.h),
            ],
            if (outgoing.isNotEmpty) ...[
              FriendsSectionHeader(
                title: 'friends566_sent'.tr,
                count: outgoing.length,
              ),
              for (final f in outgoing)
                OutgoingRequestCard(
                  key: ValueKey('out_${f.id}'),
                  friendship: f,
                  controller: controller,
                  accent: accent,
                ),
            ],
          ],
        );
      }),
    );
  }
}

/// Enveloppe : fondu + repli vertical avant le retrait réel de la ligne.
class _Vanishing extends StatelessWidget {
  const _Vanishing({required this.gone, required this.child});
  final bool gone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: gone ? 0 : 1,
        child: gone
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: child,
              ),
      ),
    );
  }
}

const Duration _vanishDelay = Duration(milliseconds: 280);

/// Ligne identité commune (avatar + nom + pastille de rôle + sous-titre).
class _RequestIdentity extends StatelessWidget {
  const _RequestIdentity({
    required this.other,
    required this.subtitle,
  });
  final FriendProfile? other;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final model = other?.model ?? 'Owner';
    final roleColor = friendRoleColor(model);
    final name = (other?.name ?? '').isEmpty
        ? 'common_user_fallback'.tr
        : other!.name;
    return Row(
      children: [
        FriendAvatar(
          imageUrl: other?.avatar ?? '',
          ringColor: pawSpotRingColor(other?.pawSpotTier) ?? roleColor,
          size: 42,
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
                      text: name,
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  FriendsBadge(label: friendRoleLabel(model), color: roleColor),
                ],
              ),
              SizedBox(height: 3.h),
              InterText(
                text: subtitle,
                fontSize: 12.sp,
                color: AppColors.textSecondary(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Demande reçue ────────────────────────────────────────────────────────

class IncomingRequestCard extends StatefulWidget {
  const IncomingRequestCard({
    super.key,
    required this.friendship,
    required this.controller,
    required this.accent,
  });
  final Friendship friendship;
  final FriendController controller;
  final Color accent;

  @override
  State<IncomingRequestCard> createState() => _IncomingRequestCardState();
}

class _IncomingRequestCardState extends State<IncomingRequestCard> {
  String? _busy; // 'accept' | 'decline'
  bool _gone = false;

  Future<void> _accept() async {
    setState(() => _busy = 'accept');
    // POST /friends/:id/accept (idempotent côté contrôleur, cf. v488).
    final ok = await widget.controller
        .accept(widget.friendship.id, deferRefresh: true);
    if (!mounted) {
      if (ok) widget.controller.refresh();
      return;
    }
    if (!ok) {
      setState(() => _busy = null);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'friends566_error_msg'.tr,
      );
      return;
    }
    setState(() => _gone = true);
    CustomSnackbar.showSuccess(
      title: 'friends_accepted_title'.tr,
      message: 'friends_accepted_msg'.tr,
    );
    await Future<void>.delayed(_vanishDelay);
    // L'ami passe dans « Mes amis », le compteur de l'onglet se met à jour.
    widget.controller.removeRequestLocally(widget.friendship.id);
    await widget.controller.refresh();
  }

  Future<void> _decline() async {
    setState(() => _busy = 'decline');
    // POST /friends/:id/decline
    final ok = await widget.controller
        .decline(widget.friendship.id, deferRemove: true);
    if (!mounted) {
      if (ok) widget.controller.removeRequestLocally(widget.friendship.id);
      return;
    }
    if (!ok) {
      setState(() => _busy = null);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'friends566_error_msg'.tr,
      );
      return;
    }
    setState(() => _gone = true);
    await Future<void>.delayed(_vanishDelay);
    widget.controller.removeRequestLocally(widget.friendship.id);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busy != null;
    return _Vanishing(
      gone: _gone,
      child: FriendsCard(
        child: Column(
          children: [
            _RequestIdentity(
              other: widget.friendship.other,
              subtitle: 'friends_request_wants'.tr,
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: FriendsPillButton(
                    label: 'friends566_decline'.tr,
                    color: AppColors.textSecondary(context),
                    expand: true,
                    loading: _busy == 'decline',
                    onTap: busy ? null : _decline,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: FriendsPillButton(
                    label: 'friends566_accept'.tr,
                    icon: Icons.check_rounded,
                    color: kFriendsGreen,
                    filled: true,
                    expand: true,
                    loading: _busy == 'accept',
                    onTap: busy ? null : _accept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Demande envoyée ──────────────────────────────────────────────────────

class OutgoingRequestCard extends StatefulWidget {
  const OutgoingRequestCard({
    super.key,
    required this.friendship,
    required this.controller,
    required this.accent,
  });
  final Friendship friendship;
  final FriendController controller;
  final Color accent;

  @override
  State<OutgoingRequestCard> createState() => _OutgoingRequestCardState();
}

class _OutgoingRequestCardState extends State<OutgoingRequestCard> {
  bool _busy = false;
  bool _gone = false;

  Future<void> _cancel() async {
    setState(() => _busy = true);
    // DELETE /friends/:id — la route accepte une amitié en attente.
    final ok = await widget.controller
        .cancelRequest(widget.friendship.id, deferRemove: true);
    if (!mounted) {
      if (ok) widget.controller.removeRequestLocally(widget.friendship.id);
      return;
    }
    if (!ok) {
      setState(() => _busy = false);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'friends566_error_msg'.tr,
      );
      return;
    }
    setState(() => _gone = true);
    CustomSnackbar.showInfo(
      title: 'friends_pending_banner_cancelled_title'.tr,
      message: 'friends_pending_banner_cancelled_msg'.tr,
    );
    await Future<void>.delayed(_vanishDelay);
    widget.controller.removeRequestLocally(widget.friendship.id);
  }

  @override
  Widget build(BuildContext context) {
    return _Vanishing(
      gone: _gone,
      child: FriendsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RequestIdentity(
              other: widget.friendship.other,
              subtitle: 'friends_pending_banner_outgoing_msg'.tr,
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FriendsBadge(
                      label: 'family_member_pending'.tr,
                      color: const Color(0xFFB45309),
                      icon: Icons.hourglass_top_rounded,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                FriendsPillButton(
                  label: 'friends_pending_banner_cancel'.tr,
                  color: AppColors.textSecondary(context),
                  loading: _busy,
                  onTap: _busy ? null : _cancel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Invitation Famille reçue ─────────────────────────────────────────────

class FamilyInvitationCard extends StatefulWidget {
  const FamilyInvitationCard({
    super.key,
    required this.invitation,
    required this.controller,
  });
  final Map<String, dynamic> invitation;
  final FriendController controller;

  @override
  State<FamilyInvitationCard> createState() => _FamilyInvitationCardState();
}

class _FamilyInvitationCardState extends State<FamilyInvitationCard> {
  String? _busy;
  bool _gone = false;

  String get _id =>
      (widget.invitation['id'] ?? widget.invitation['invitationId'] ?? '')
          .toString();

  Future<void> _accept() async {
    setState(() => _busy = 'accept');
    // POST /friends/family/invitation/:id/accept
    final ok = await widget.controller.acceptFamilyInvitation(_id);
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = null);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'friends566_error_msg'.tr,
      );
      return;
    }
    setState(() => _gone = true);
    CustomSnackbar.showSuccess(
      title: 'common_done'.tr,
      message: 'family_invitation_accepted_msg'.tr,
    );
  }

  Future<void> _refuse() async {
    setState(() => _busy = 'refuse');
    // POST /friends/family/invitation/:id/refuse
    final ok = await widget.controller.refuseFamilyInvitation(_id);
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = null);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'friends566_error_msg'.tr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invitation;
    final name = (inv['familyOwnerName'] ?? '').toString();
    final avatar = (inv['familyOwnerAvatar'] ?? '').toString();
    final busy = _busy != null;
    return _Vanishing(
      gone: _gone,
      child: FriendsCard(
        tint: kFamilyViolet,
        child: Column(
          children: [
            Row(
              children: [
                FriendAvatar(
                  imageUrl: avatar,
                  ringColor: kFamilyViolet,
                  size: 42,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InterText(
                        text: name.isEmpty
                            ? 'friends566_family_invite_generic'.tr
                            : name,
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 3.h),
                      InterText(
                        text: 'friends_pending_banner_family_msg'.tr,
                        fontSize: 12.sp,
                        color: AppColors.textSecondary(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                FriendsBadge(
                  label: 'friends_tab_family'.tr,
                  color: kFamilyViolet,
                  icon: Icons.family_restroom_rounded,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: FriendsPillButton(
                    label: 'friends566_decline'.tr,
                    color: AppColors.textSecondary(context),
                    expand: true,
                    loading: _busy == 'refuse',
                    onTap: busy ? null : _refuse,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: FriendsPillButton(
                    label: 'friends566_accept'.tr,
                    icon: Icons.check_rounded,
                    color: kFriendsGreen,
                    filled: true,
                    expand: true,
                    loading: _busy == 'accept',
                    onTap: busy ? null : _accept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
