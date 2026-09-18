// v566 — Daniel : « faire comme WhatsApp : double coche, et écrit en mini que
// le message est lu ».
//   horloge            : envoi en cours
//   ✓  grise           : envoyé
//   ✓✓ grises          : remis
//   ✓✓ bleues #34B7F1  : lu
// Sur une bulle colorée (orange / vert / bleu du rôle) le bleu WhatsApp serait
// illisible : les coches « lu » sont alors posées sur une mini-pastille blanche.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/chat_time.dart';

/// Bleu « lu » de WhatsApp.
const Color kChatReadBlue = Color(0xFF34B7F1);

String chatReceiptLabel(ChatReceiptStatus status) {
  switch (status) {
    case ChatReceiptStatus.sending:
      return 'cs_receipt_sending'.tr;
    case ChatReceiptStatus.sent:
      return 'cs_receipt_sent'.tr;
    case ChatReceiptStatus.delivered:
      return 'cs_receipt_delivered'.tr;
    case ChatReceiptStatus.read:
      return 'cs_receipt_read'.tr;
    case ChatReceiptStatus.failed:
      return 'cs_send_failed_title'.tr;
  }
}

class ChatReceiptTicks extends StatelessWidget {
  const ChatReceiptTicks({
    super.key,
    required this.status,
    required this.greyColor,
    this.size = 13,
    this.onColoredBubble = false,
    this.failedColor,
  });

  final ChatReceiptStatus status;

  /// Couleur des états « gris » (blanc atténué sur une bulle colorée).
  final Color greyColor;
  final double size;

  /// true = la coche est posée sur une bulle à la couleur du rôle.
  final bool onColoredBubble;
  final Color? failedColor;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color = greyColor;
    switch (status) {
      case ChatReceiptStatus.sending:
        icon = Icons.schedule_rounded;
        break;
      case ChatReceiptStatus.sent:
        icon = Icons.done_rounded;
        break;
      case ChatReceiptStatus.delivered:
        icon = Icons.done_all_rounded;
        break;
      case ChatReceiptStatus.read:
        icon = Icons.done_all_rounded;
        color = kChatReadBlue;
        break;
      case ChatReceiptStatus.failed:
        icon = Icons.error_rounded;
        color = failedColor ?? AppColors.errorColor;
        break;
    }
    Widget child = Icon(icon, size: size.sp, color: color);
    if (status == ChatReceiptStatus.read && onColoredBubble) {
      child = Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: child,
      );
    }
    return Semantics(label: chatReceiptLabel(status), child: child);
  }
}

/// Mini-texte sous le DERNIER message lu : « Lu · 14:32 ».
class ChatReadLabel extends StatelessWidget {
  const ChatReadLabel({super.key, required this.readAt});

  final DateTime readAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 3.h, right: 4.w),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all_rounded, size: 11.sp, color: kChatReadBlue),
          SizedBox(width: 3.w),
          Flexible(
            child: Text(
              'cs_read_at'.trParams({'time': chatClock(context, readAt)}),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
