// v566 — onglet « Ajouter » : recherche nom / e-mail (résultats en cartes,
// bouton qui reflète l'état : Inviter / Demande envoyée / Déjà amis /
// Répondre), lien d'invitation, QR code, partage natif, WhatsApp, e-mail.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/friends/tabs/friends_ui.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AddFriendTab extends StatefulWidget {
  const AddFriendTab({
    super.key,
    required this.controller,
    required this.accent,
    required this.onOpenRequests,
  });

  final FriendController controller;
  final Color accent;

  /// « Répondre » (cette personne m'a déjà envoyé une demande) → onglet Demandes.
  final VoidCallback onOpenRequests;

  @override
  State<AddFriendTab> createState() => _AddFriendTabState();
}

class _AddFriendTabState extends State<AddFriendTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final RxList<Map<String, dynamic>> _results = <Map<String, dynamic>>[].obs;
  final RxBool _loading = false.obs;
  final RxString _query = ''.obs;
  // Id des membres dont l'envoi est en cours (spinner par ligne).
  final RxSet<String> _sending = <String>{}.obs;
  // v23.1 part 243 — debounce 300 ms + rejet des réponses périmées.
  Timer? _debounce;
  String _lastQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _query.value = q;
    if (q.trim().length < 2) {
      _results.clear();
      _loading.value = false;
      _lastQuery = '';
      return;
    }
    _lastQuery = q;
    _loading.value = true;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final captured = q;
      try {
        // GET /friends/search?q=
        final users = await widget.controller.searchUsers(captured);
        if (captured != _lastQuery) return;
        _results.assignAll(users);
      } finally {
        if (captured == _lastQuery) _loading.value = false;
      }
    });
  }

  /// Partage direct par WhatsApp ou e-mail ; repli sur la feuille système.
  Future<void> _shareVia(String channel) async {
    final text = friendsInviteMessage();
    final uri = channel == 'whatsapp'
        ? Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}')
        : Uri(
            scheme: 'mailto',
            query: 'subject=${Uri.encodeComponent('friends_invite_subject'.tr)}'
                '&body=${Uri.encodeComponent(text)}',
          );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('cannot launch');
    } catch (_) {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'friends_invite_subject'.tr),
      );
    }
  }

  /// QR code de l'invitation : l'ami scanne, il arrive sur la demande d'ami
  /// (le lien /invite est un lien universel).
  void _showInviteQr() {
    final link = friendsInviteLink();
    final accent = widget.accent;
    showProfileSheet<void>(
      context,
      builder: (ctx) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FriendsSheetHeader(
              title: 'friends_share_qr_title'.tr,
              icon: Icons.qr_code_2_rounded,
              color: accent,
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                // Un QR se lit sur fond BLANC, y compris en thème sombre.
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
                boxShadow: AppColors.cardShadow(ctx),
              ),
              child: QrImageView(
                data: link,
                size: 210.w,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF17141F),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF17141F),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            InterText(
              text: 'friends_share_qr_hint'.tr,
              fontSize: 12.5.sp,
              color: AppColors.textSecondary(ctx),
              textAlign: TextAlign.center,
              height: 1.4,
              maxLines: 4,
            ),
            SizedBox(height: 16.h),
            ProfilePrimaryButton(
              label: 'friends_add_share_link'.tr,
              accent: accent,
              icon: Icons.ios_share_rounded,
              onTap: shareFriendsInvite,
            ),
            SizedBox(height: 8.h),
            ProfileSecondaryButton(
              label: 'friends566_copy_link'.tr,
              accent: accent,
              icon: Icons.link_rounded,
              onTap: copyFriendsInviteLink,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final accent = widget.accent;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w,
          24.h + MediaQuery.of(context).viewPadding.bottom),
      children: [
        FriendsSearchField(
          controller: _searchCtrl,
          hint: 'friends_add_search_hint'.tr,
          accent: accent,
          keyboardType: TextInputType.emailAddress,
          onChanged: _onSearch,
        ),
        SizedBox(height: 12.h),
        Obx(() {
          // Dépendances : l'état des boutons suit les listes du contrôleur
          // (demande envoyée → « Demande envoyée » sans recharger).
          final ctrl = widget.controller;
          // ignore: unused_local_variable
          final deps = ctrl.friends.length +
              ctrl.outgoingRequests.length +
              ctrl.incomingRequests.length +
              _sending.length;
          final q = _query.value.trim();
          if (q.length < 2) {
            return Padding(
              padding: EdgeInsets.fromLTRB(6.w, 0, 6.w, 4.h),
              child: InterText(
                text: 'friends_add_search_help'.tr,
                fontSize: 12.sp,
                color: AppColors.textSecondary(context),
                maxLines: 3,
              ),
            );
          }
          if (_loading.value && _results.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 28.h),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            );
          }
          if (_results.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 12.w),
              child: Column(
                children: [
                  Icon(Icons.person_search_rounded,
                      size: 40.sp, color: AppColors.greyText),
                  SizedBox(height: 8.h),
                  InterText(
                    text: 'friends_add_no_results'.tr,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                  ),
                  SizedBox(height: 4.h),
                  InterText(
                    text: 'friends566_no_results_hint'.tr,
                    fontSize: 12.sp,
                    color: AppColors.textSecondary(context),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              for (final u in _results) _buildResultCard(context, u),
            ],
          );
        }),
        SizedBox(height: 10.h),
        _buildInviteCard(context),
      ],
    );
  }

  // ── Carte « Invite tes proches » ───────────────────────────────────────

  Widget _buildInviteCard(BuildContext context) {
    final accent = widget.accent;
    return FriendsCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child:
                    Icon(Icons.card_giftcard_rounded, color: accent, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: 'friends566_invite_card_title'.tr,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                      maxLines: 2,
                    ),
                    SizedBox(height: 2.h),
                    InterText(
                      text: 'friends566_invite_card_sub'.tr,
                      fontSize: 12.sp,
                      color: AppColors.textSecondary(context),
                      maxLines: 3,
                      height: 1.35,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          ProfilePrimaryButton(
            label: 'friends_add_share_link'.tr,
            accent: accent,
            icon: Icons.ios_share_rounded,
            onTap: shareFriendsInvite,
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _shortcut(
                  context,
                  icon: Icons.qr_code_2_rounded,
                  label: 'friends_share_qr'.tr,
                  onTap: _showInviteQr,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _shortcut(
                  context,
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  onTap: () => _shareVia('whatsapp'),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _shortcut(
                  context,
                  icon: Icons.mail_rounded,
                  label: 'friends_share_email'.tr,
                  onTap: () => _shareVia('email'),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _shortcut(
                  context,
                  icon: Icons.link_rounded,
                  label: 'friends566_copy_short'.tr,
                  onTap: copyFriendsInviteLink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shortcut(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final accent = widget.accent;
    return Material(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 11.h, horizontal: 4.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 20.sp),
              SizedBox(height: 5.h),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Résultat de recherche ──────────────────────────────────────────────

  Future<void> _send(String id, String role, String name) async {
    _sending.add(id);
    try {
      // POST /friends/request { targetId, targetRole } — le contrôleur
      // recharge les demandes → le bouton passe à « Demande envoyée ».
      final err = await widget.controller.sendRequest(id, role);
      if (!mounted) return;
      if (err.isEmpty) {
        CustomSnackbar.showSuccess(
          title: 'friends_invite_sent_title'.tr,
          message: 'friends_invite_sent_msg'.trParams({'name': name}),
        );
      } else {
        final msg = err == 'ALREADY_PENDING'
            ? 'friends_invite_err_already_pending'.tr
            : err == 'ALREADY_ACCEPTED'
                ? 'friends_invite_err_already_accepted'.tr
                : err == 'SELF'
                    ? 'friends_invite_err_self'.tr
                    : err;
        CustomSnackbar.showError(
          title: 'friends_invite_err_title'.tr,
          message: msg,
        );
        // État réel côté serveur ≠ état affiché → on resynchronise.
        unawaited(widget.controller.refresh());
      }
    } finally {
      _sending.remove(id);
    }
  }

  Widget _buildResultCard(BuildContext context, Map<String, dynamic> u) {
    final ctrl = widget.controller;
    final id = (u['id'] ?? '').toString();
    final role = (u['role'] ?? '').toString();
    final name = (u['name'] ?? '').toString();
    final avatar = (u['avatar'] ?? '').toString();
    // v23.1 part 219 — jamais d'e-mail affiché dans les résultats.
    final displayName = name.isNotEmpty ? name : 'friends_search_no_name'.tr;
    final roleColor = friendRoleColor(role);

    final Widget action;
    if (ctrl.isFriendWith(id)) {
      action = FriendsBadge(
        label: 'friends566_state_friends'.tr,
        color: kFriendsGreen,
        icon: Icons.check_circle_rounded,
      );
    } else if (ctrl.hasPendingRequestTo(id)) {
      action = FriendsBadge(
        label: 'friends566_state_sent'.tr,
        color: const Color(0xFFB45309),
        icon: Icons.hourglass_top_rounded,
      );
    } else if (ctrl.incomingRequestFrom(id) != null) {
      action = FriendsPillButton(
        label: 'friends566_state_reply'.tr,
        color: kFriendsGreen,
        filled: true,
        onTap: widget.onOpenRequests,
      );
    } else {
      action = FriendsPillButton(
        label: 'friends_add_btn'.tr,
        icon: Icons.person_add_alt_1_rounded,
        color: widget.accent,
        filled: true,
        loading: _sending.contains(id),
        onTap: () => _send(id, role, name),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: FriendsCard(
        padding: EdgeInsets.all(12.w),
        child: Row(
          children: [
            FriendAvatar(imageUrl: avatar, ringColor: roleColor, size: 42),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InterText(
                    text: displayName,
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
                      color: roleColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            // Largeur bornée : « Demande envoyée » en allemand / portugais
            // s'abrège au lieu de pousser le nom hors de la carte.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 132.w),
              child: action,
            ),
          ],
        ),
      ),
    );
  }
}
