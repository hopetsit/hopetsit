// v569 — Daniel : « dans le chat, si on clique sur le profil ou la photo de la
// personne, on peut la bloquer ou la demander en ami si elle ne l'est pas
// déjà ». Fiche ouverte depuis l'en-tête d'une discussion (3 rôles).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/views/chat_shared/chat_avatar.dart';
import 'package:hopetsit/views/chat_shared/chat_session.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

FriendController _friendController() => Get.isRegistered<FriendController>()
    ? Get.find<FriendController>()
    : Get.put(FriendController());

/// Ouvre la fiche du correspondant de [conversationId]. Sans identité connue
/// (très vieille conversation) on n'affiche rien plutôt qu'une fiche vide.
Future<void> showChatPeerSheet(
  BuildContext context, {
  required ChatSession session,
  required String conversationId,
  required String contactName,
  required String contactImage,
  required ChatRoleTheme theme,
}) async {
  String peerId = '';
  String peerRole = '';
  for (final c in session.conversationsRx) {
    if (c.id == conversationId) {
      peerId = c.contactId;
      peerRole = c.contactRole;
      break;
    }
  }
  if (peerId.isEmpty) return;

  final friends = _friendController();
  // État frais : la liste d'amis n'est pas forcément chargée depuis le chat.
  // ignore: discarded_futures
  friends.loadFriends();
  // ignore: discarded_futures
  friends.loadRequests();

  final blocked = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ChatPeerSheet(
      friends: friends,
      peerId: peerId,
      peerRole: peerRole.isEmpty ? 'owner' : peerRole,
      name: contactName,
      image: contactImage,
      theme: theme,
    ),
  );
  // Bloqué → on quitte la discussion (elle n'a plus lieu d'être ouverte).
  if (blocked == true && context.mounted) {
    Navigator.of(context).maybePop();
  }
}

class _ChatPeerSheet extends StatefulWidget {
  const _ChatPeerSheet({
    required this.friends,
    required this.peerId,
    required this.peerRole,
    required this.name,
    required this.image,
    required this.theme,
  });

  final FriendController friends;
  final String peerId;
  final String peerRole;
  final String name;
  final String image;
  final ChatRoleTheme theme;

  @override
  State<_ChatPeerSheet> createState() => _ChatPeerSheetState();
}

class _ChatPeerSheetState extends State<_ChatPeerSheet> {
  bool _sending = false;
  bool _blocking = false;
  bool _justSent = false;

  double _bottomInset(BuildContext context) => appBottomInset(context);

  Future<void> _addFriend() async {
    if (_sending) return;
    setState(() => _sending = true);
    final err = await widget.friends.sendRequest(widget.peerId, widget.peerRole);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _justSent = err.isEmpty || err == 'ALREADY_PENDING';
    });
    if (err.isEmpty) {
      HapticFeedback.lightImpact();
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'pawmap_member_request_sent'.tr,
      );
    } else if (err == 'ALREADY_PENDING' || err == 'ALREADY_ACCEPTED') {
      CustomSnackbar.showInfo(
        title: widget.name,
        message: 'pawmap_member_already'.tr,
      );
    } else {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'pawmap_member_request_failed'.tr,
      );
    }
  }

  Future<void> _block() async {
    if (_blocking) return;
    // v573 — dialogue maison (app_dialog_kit) : carte coins 22, disque rouge,
    // bouton « Bloquer » principal destructif. Logique inchangée.
    final ok = await showAppConfirmDialog(
      context,
      title: 'block_user_title'.tr,
      message: 'block_user_confirm_message'.tr,
      confirmLabel: 'block_user_action'.tr,
      cancelLabel: 'common_cancel'.tr,
      destructive: true,
      icon: Icons.block_rounded,
      accent: widget.theme.accent,
    );
    if (ok != true || !mounted) return;
    setState(() => _blocking = true);
    final done = await widget.friends.blockUser(
      targetUserId: widget.peerId,
      targetRole: widget.peerRole,
    );
    if (!mounted) return;
    setState(() => _blocking = false);
    if (done) {
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'block_user_success'.tr,
      );
      Navigator.of(context).pop(true);
    } else {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'block_user_failed'.tr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // `accent` sert de FOND au bouton plein (texte blanc dessus) ; `accentOn`
    // sert au texte / à la bordure posés sur la feuille, illisibles en mode
    // sombre avec le rouge propriétaire ou le bleu gardien.
    final accent = widget.theme.accent;
    final accentText = widget.theme.accentOn(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20.w, 10.h, 20.w, 18.h + _bottomInset(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider(context),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(height: 18.h),
          ChatAvatar(imageUrl: widget.image, size: 76, online: false),
          SizedBox(height: 10.h),
          PoppinsText(
            text: widget.name,
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 18.h),
          Obx(() {
            // Lectures directes des listes observables (règle GetX du projet).
            final isFriend = widget.friends.friends.any((f) =>
                f.status == 'accepted' &&
                (f.other?.id ?? '').trim().toLowerCase() ==
                    widget.peerId.trim().toLowerCase());
            final pending = widget.friends.outgoingRequests.any((f) =>
                f.status == 'pending' &&
                (f.other?.id ?? '').trim().toLowerCase() ==
                    widget.peerId.trim().toLowerCase());
            if (isFriend || pending || _justSent) {
              return _StatePill(
                icon: isFriend
                    ? Icons.verified_user_rounded
                    : Icons.hourglass_top_rounded,
                label: isFriend
                    ? 'pawmap_member_already'.tr
                    : 'pawmap_member_request_sent'.tr,
                color: accentText,
              );
            }
            return _ActionButton(
              icon: Icons.person_add_alt_1_rounded,
              label: 'pawmap_member_add_friend'.tr,
              color: accent,
              filled: true,
              busy: _sending,
              onTap: _addFriend,
            );
          }),
          SizedBox(height: 10.h),
          _ActionButton(
            icon: Icons.block_rounded,
            label: 'block_user_action'.tr,
            color: AppColors.errorColor,
            filled: false,
            busy: _blocking,
            onTap: _block,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Bouton non rempli : la couleur devient du TEXTE sur la feuille. Le rouge
    // « Bloquer » y est illisible en mode sombre → éclairci (clair inchangé).
    final onSurface = AppColors.accentOn(context, color);
    final fg = filled ? Colors.white : onSurface;
    return Material(
      color: filled
          ? color
          : color.withValues(alpha: isDark ? 0.18 : 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: busy ? null : onTap,
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: Center(
            child: busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: fg, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: InterText(
                          text: label,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: fg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 52,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: InterText(
              text: label,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: color,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
