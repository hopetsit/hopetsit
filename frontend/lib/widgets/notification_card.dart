import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/app_notification_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:intl/intl.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotificationModel notification;
  final VoidCallback onTap;

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('like')) return Icons.favorite_rounded;
    if (t.contains('comment')) return Icons.chat_bubble_outline_rounded;
    if (t.contains('booking') ||
        t.contains('application') ||
        t.contains('request')) {
      return Icons.event_available_rounded;
    }
    if (t.contains('message') || t.contains('chat')) {
      return Icons.forum_rounded;
    }
    if (t.contains('payment') || t.contains('payout')) {
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
      return AppColors.primaryColor;
    }
    return AppColors.primaryColor;
  }

  String _formatTime(DateTime utc) {
    final local = utc.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'time_just_now'.tr;
    if (diff.inHours < 24) {
      return DateFormat.Hm().format(local);
    }
    if (diff.inDays < 7) {
      return DateFormat.E().add_Hm().format(local);
    }
    return DateFormat.yMMMd().add_Hm().format(local);
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

  @override
  Widget build(BuildContext context) {
    final accent = _accentForType(notification.type);
    final unread = notification.isUnread;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: unread
                  ? accent.withValues(alpha: 0.35)
                  : AppColors.grey300Color.withValues(alpha: 0.6),
              width: unread ? 1.2 : 1,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15.r),
                      bottomLeft: Radius.circular(15.r),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accent,
                        accent.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48.w,
                          height: 48.w,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent.withValues(alpha: 0.15),
                                accent.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(
                            _iconForType(notification.type),
                            color: accent,
                            size: 24.sp,
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
                                          : 'notifications_fallback_title'
                                              .tr,
                                      fontSize: 15.sp,
                                      fontWeight: unread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: AppColors.blackColor,
                                      maxLines: 2,
                                    ),
                                  ),
                                  if (unread) ...[
                                    SizedBox(width: 8.w),
                                    Container(
                                      width: 8.w,
                                      height: 8.w,
                                      decoration: BoxDecoration(
                                        color: accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: 6.h),
                              InterText(
                                text: _localizedBody(notification.body),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.grey700Color,
                                maxLines: 4,
                              ),
                              SizedBox(height: 8.h),
                              InterText(
                                text: _formatTime(notification.createdAt),
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.greyText,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
