// v569 — carte de la cloche, refaite au langage visuel du lot « listes ».
//
// ⚠️ DESIGN UNIQUEMENT : mêmes paramètres de constructeur (`notification`,
// `onTap`), mêmes conditions d'affichage des actions en ligne, mêmes appels
// FriendController (accept / decline / acceptFamilyInvitation /
// refuseFamilyInvitation) et même navigation au tap.
//
// Ce qui change :
//   • pastille RONDE teintée par catégorie avec icône pleine (48), point
//     « non lu » à gauche, fond très légèrement teinté pour les non-lus ;
//   • titre 14/700, corps 13 gris sur 2 lignes, heure RELATIVE ;
//   • les boutons Accepter / Refuser passent par `ActionPillButton`
//     (kit commun : ≥ 44 px, coins 14, anti double-tap, haptique) ;
//   • plus d'`IntrinsicHeight` avec un `Expanded` dedans (règle release du
//     projet) : le liseré vertical est remplacé par la pastille + le point ;
//   • dates/heures dans la langue de l'app (`Get.locale`), plus dans la
//     locale par défaut du système.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/models/app_notification_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:intl/intl.dart';

class NotificationCard extends StatefulWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotificationModel notification;
  final VoidCallback onTap;

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  // v23.1.183 — Daniel : "les demande damis naparaisse nul par il ny as
  // pas dendroi aou accepter ou refuser". Pour friend_request_received,
  // family_invitation_received, live_tracking_request_received → on
  // affiche les boutons Accepter / Refuser DIRECTEMENT dans la cloche
  // sans devoir naviguer.
  bool _actionPending = false;
  String? _actionDone; // 'accepted' | 'refused' une fois l'action faite

  AppNotificationModel get notification => widget.notification;
  VoidCallback get onTap => widget.onTap;

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('like')) return Icons.favorite_rounded;
    if (t.contains('comment')) return Icons.chat_bubble_rounded;
    if (t.contains('friend') || t.contains('family')) {
      return Icons.group_rounded;
    }
    if (t.contains('live') || t.contains('handover') || t.contains('walk')) {
      return Icons.my_location_rounded;
    }
    if (t.contains('booking') ||
        t.contains('application') ||
        t.contains('request')) {
      return Icons.event_available_rounded;
    }
    if (t.contains('message') || t.contains('chat')) {
      return Icons.forum_rounded;
    }
    if (t.contains('payment') ||
        t.contains('payout') ||
        t.contains('wallet') ||
        t.contains('paid')) {
      return Icons.payments_rounded;
    }
    return Icons.notifications_rounded;
  }

  // Session v17.1 — role-aware colour so owner notifications visually
  // distinguish walker requests (green) from sitter requests (blue). The
  // role hint is carried in `notification.data.providerRole` by the
  // backend (applicationController + bookingController since v17.1).
  static const Color _walkerAccent = Color(0xFF16A34A);
  static const Color _sitterAccent = Color(0xFF2563EB);

  Color _accentForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('like')) return const Color(0xFFE91E63);
    if (t.contains('comment')) return const Color(0xFF5C6BC0);
    // v569 — mêmes familles de couleur que les bandeaux d'action
    // (ActionTone) : ami / social rose, suivi en direct violet.
    if (t.contains('friend') || t.contains('family')) return ActionTone.social;
    if (t.contains('live') || t.contains('handover')) return ActionTone.live;
    if (t.contains('booking') || t.contains('application') || t.contains('request')) {
      // Prefer the role-specific colour when provided by the backend.
      final role = notification.data['providerRole']?.toString().toLowerCase();
      if (role == 'walker') return _walkerAccent;
      if (role == 'sitter') return _sitterAccent;
      // Fallback — also inspect actorRole on the notif itself in case the
      // backend forgot to include providerRole in data.
      final actorRole = notification.actorRole.toLowerCase();
      if (actorRole == 'walker') return _walkerAccent;
      if (actorRole == 'sitter') return _sitterAccent;
      // v488 — Daniel : « la couleur des notifs pas à jour par rôle ». À défaut
      // d'un rôle d'acteur, on suit le rôle COURANT de l'utilisateur (vert
      // promeneur / bleu gardien / orange propriétaire) au lieu d'orange fixe.
      return AppColors.activeRoleAccent();
    }
    return AppColors.activeRoleAccent();
  }

  /// v569 — heure RELATIVE (à l'instant / 12 min / 3 h / 2 j), puis date
  /// complète au-delà d'une semaine, DANS LA LANGUE DE L'APP.
  /// ⚠️ bug corrigé : `DateFormat.Hm()` sans locale suivait la locale par
  /// défaut, pas celle choisie par l'utilisateur.
  String _formatTime(DateTime utc) {
    final local = utc.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'time_just_now'.tr;
    if (diff.inMinutes < 60) {
      return 'lists569_time_min'.tr.replaceAll('{n}', '${diff.inMinutes}');
    }
    if (diff.inHours < 24) {
      return 'lists569_time_hour'.tr.replaceAll('{n}', '${diff.inHours}');
    }
    if (diff.inDays < 7) {
      return 'lists569_time_day'.tr.replaceAll('{n}', '${diff.inDays}');
    }
    return DateFormat.yMMMd(Get.locale?.toLanguageTag()).format(local);
  }

  /// Maps known English notification strings from the backend to localized keys.
  static const _titleMap = {
    'new request': 'notif_title_new_request',
    'new application': 'notif_title_new_application',
    'application accepted': 'notif_title_application_accepted',
    'application rejected': 'notif_title_application_rejected',
    'new message': 'notif_title_new_message',
    'new like': 'notif_title_new_like',
    'new comment': 'notif_title_new_comment',
    'booking confirmed': 'notif_title_booking_confirmed',
    'booking cancelled': 'notif_title_booking_cancelled',
    'payment received': 'notif_title_payment_received',
    // Session v16.3b - added entries for booking_* notification types coming
    // from the backend (bookingController createNotificationSafe strings).
    'new booking request': 'notif_title_booking_new',
    'booking accepted': 'notif_title_booking_accepted',
    'booking rejected': 'notif_title_booking_rejected',
    'booking paid': 'notif_title_booking_paid',
    'booking request cancelled': 'notif_title_booking_cancelled',
  };

  static const _bodyMap = {
    'a sitter sent you a request.': 'notif_body_sitter_sent_request',
    'an owner sent you a request.': 'notif_body_owner_sent_request',
    'your application was accepted.': 'notif_body_application_accepted',
    'your application was rejected.': 'notif_body_application_rejected',
    'you have a new message.': 'notif_body_new_message',
    'someone liked your post.': 'notif_body_post_liked',
    'someone commented on your post.': 'notif_body_post_commented',
    // Session v16.3b.
    'you received a new booking request.': 'notif_body_booking_new',
    'your booking request was accepted.': 'notif_body_booking_accepted',
    'your booking request was rejected.': 'notif_body_booking_rejected',
    'a pet-care provider sent you a request.': 'notif_body_provider_sent_request',
  };

  String _localizedTitle(String raw) {
    final key = _titleMap[raw.toLowerCase().trim()];
    if (key == null) return raw;
    final translated = key.tr;
    return translated == key ? raw : translated;
  }

  String _localizedBody(String raw) {
    final key = _bodyMap[raw.toLowerCase().trim()];
    if (key == null) return raw;
    // Session v17.1 — when the backend tags the notification with a provider
    // role (walker/sitter), pick a role-specific translation key if it
    // exists so the body text reads "Un promeneur vous a envoyé une demande"
    // vs "Un petsitter vous a envoyé une demande" instead of the generic
    // "Un prestataire ...". Falls back to the generic key if no role-specific
    // key is registered in the active locale.
    final role = notification.data['providerRole']?.toString().toLowerCase();
    if (role == 'walker' || role == 'sitter') {
      final roleKey = '${key}_$role';
      final roleTr = roleKey.tr;
      if (roleTr != roleKey) return roleTr;
    }
    final translated = key.tr;
    return translated == key ? raw : translated;
  }

  /// v23.1.183 — true si on doit afficher les boutons Accepter/Refuser
  /// inline dans la cloche pour ce type de notif.
  bool get _hasInlineActions {
    if (_actionDone != null) return true; // affiche le statut final
    final t = notification.type.toLowerCase();
    if (t == 'friend_request_received') {
      final fid = (notification.data['friendshipId'] ?? '').toString();
      return fid.isNotEmpty;
    }
    if (t == 'family_invitation_received') {
      final iid = (notification.data['invitationId'] ?? '').toString();
      return iid.isNotEmpty;
    }
    return false;
  }

  Future<void> _onAccept() async {
    if (_actionPending) return;
    final t = notification.type.toLowerCase();
    final ctrl = Get.isRegistered<FriendController>()
        ? Get.find<FriendController>()
        : Get.put(FriendController());
    setState(() => _actionPending = true);
    try {
      bool ok = false;
      if (t == 'friend_request_received') {
        final fid = (notification.data['friendshipId'] ?? '').toString();
        if (fid.isNotEmpty) ok = await ctrl.accept(fid);
      } else if (t == 'family_invitation_received') {
        final iid = (notification.data['invitationId'] ?? '').toString();
        if (iid.isNotEmpty) ok = await ctrl.acceptFamilyInvitation(iid);
      }
      if (!mounted) return;
      if (ok) {
        setState(() => _actionDone = 'accepted');
        CustomSnackbar.showSuccess(
          title: 'common_done'.tr,
          message: t == 'friend_request_received'
              ? 'friend_request_accepted_msg'.tr
              : 'family_invitation_accepted_msg'.tr,
        );
      } else {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'common_try_again'.tr,
        );
      }
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _onRefuse() async {
    if (_actionPending) return;
    final t = notification.type.toLowerCase();
    final ctrl = Get.isRegistered<FriendController>()
        ? Get.find<FriendController>()
        : Get.put(FriendController());
    setState(() => _actionPending = true);
    try {
      bool ok = false;
      if (t == 'friend_request_received') {
        final fid = (notification.data['friendshipId'] ?? '').toString();
        if (fid.isNotEmpty) ok = await ctrl.decline(fid);
      } else if (t == 'family_invitation_received') {
        final iid = (notification.data['invitationId'] ?? '').toString();
        if (iid.isNotEmpty) ok = await ctrl.refuseFamilyInvitation(iid);
      }
      if (!mounted) return;
      if (ok) {
        setState(() => _actionDone = 'refused');
      } else {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'common_try_again'.tr,
        );
      }
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  /// Actions en ligne — kit commun `ActionPillButton` : principale pleine
  /// (couleur « à traiter »), destructive en rouge texte. Le résultat final
  /// devient une simple pastille d'état.
  Widget _buildInlineActions(Color accent) {
    if (_actionDone != null) {
      final accepted = _actionDone == 'accepted';
      return Padding(
        padding: EdgeInsets.only(top: 10.h),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ActionStatusPill(
            label: accepted ? 'common_accepted'.tr : 'common_refused'.tr,
            icon: accepted
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            tone: accepted ? ActionTone.success : ActionTone.danger,
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: 10.h),
      child: Row(
        children: [
          Expanded(
            child: ActionPillButton(
              label: 'pawfollow_accept'.tr,
              icon: Icons.check_rounded,
              tone: accent,
              compact: true,
              expand: true,
              haptic: true,
              // Le bouton tapé affiche seul son indicateur (il reçoit un
              // Future) ; l'autre est simplement neutralisé.
              onPressed: _actionPending ? null : _onAccept,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: ActionPillButton(
              label: 'pawfollow_refuse'.tr,
              icon: Icons.close_rounded,
              tone: ActionTone.danger,
              kind: ActionPillKind.danger,
              compact: true,
              expand: true,
              haptic: true,
              onPressed: _actionPending ? null : _onRefuse,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentForType(notification.type);
    final unread = notification.isUnread;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(18.r);

    // Fond : la surface du thème, très légèrement teintée de la couleur de
    // la catégorie quand la notification n'est pas lue.
    final background = unread
        ? Color.alphaBlend(
            accent.withValues(alpha: dark ? 0.16 : 0.055),
            AppColors.card(context),
          )
        : AppColors.card(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: radius,
            boxShadow: AppColors.cardShadow(context),
            border: Border.all(
              color: unread
                  ? accent.withValues(alpha: dark ? 0.42 : 0.28)
                  : AppColors.divider(context),
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12.w, 14.h, 14.w, 14.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Point « non lu » — à gauche, aligné sur la première ligne.
                Padding(
                  padding: EdgeInsets.only(top: 18.h, right: 8.w),
                  child: Semantics(
                    label: unread ? 'lists569_unread'.tr : null,
                    child: Container(
                      width: 7.w,
                      height: 7.w,
                      decoration: BoxDecoration(
                        color: unread ? accent : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                // Pastille ronde teintée + icône pleine.
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: dark ? 0.26 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _iconForType(notification.type),
                    color: accent,
                    size: 23.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InterText(
                              text: notification.title.isNotEmpty
                                  ? _localizedTitle(notification.title)
                                  : 'notifications_fallback_title'.tr,
                              fontSize: 14.sp,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w600,
                              color: AppColors.textPrimary(context),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          InterText(
                            text: _formatTime(notification.createdAt),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary(context),
                            maxLines: 1,
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      InterText(
                        text: _localizedBody(notification.body),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // v23.1.183 — Boutons Accepter/Refuser inline pour
                      // friend_request_received et family_invitation_received.
                      if (_hasInlineActions) _buildInlineActions(accent),
                    ],
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
