// v565 — bulle de message façon Apple (points 16, 18, 36) : texte, photos /
// vidéos, vocal, citation (réponse), heure + statut d'envoi, traduction,
// menu d'actions (répondre, copier, traduire, supprimer, signaler).
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/views/chat_shared/chat_avatar.dart';
import 'package:hopetsit/views/chat_shared/chat_media_viewer.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/chat_receipt_ticks.dart';
import 'package:hopetsit/views/chat_shared/chat_session.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/views/chat_shared/chat_time.dart';
import 'package:hopetsit/views/chat_shared/voice_player.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/report_dialog.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.session,
    required this.theme,
    required this.conversationId,
    required this.contactName,
    required this.onQuoteTap,
    this.highlighted = false,
    this.showAvatar = true,
    this.showReadLabel = false,
  });

  final ChatMessageBase message;
  final ChatSession session;
  final ChatRoleTheme theme;
  final String conversationId;
  final String contactName;
  final void Function(String messageId) onQuoteTap;
  final bool highlighted;
  final bool showAvatar;

  /// v566 — « Lu · 14:32 » sous la bulle (dernier message lu seulement).
  final bool showReadLabel;

  bool get mine => message.isFromCurrentUser;

  // ── menu d'actions ───────────────────────────────────────────────────────
  void _showActions(BuildContext context) {
    final m = message;
    final canReply = session.features.value.reply && !m.isDeleted;
    final hasText = m.message.trim().isNotEmpty && !m.isDeleted;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card(context),
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (sheet) {
        Widget tile(IconData icon, String label, VoidCallback onTap,
            {Color? color}) {
          final c = color ?? AppColors.textPrimary(sheet);
          return ListTile(
            leading: Icon(icon, color: c, size: 22.sp),
            title: InterText(
              text: label,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: c,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.of(sheet).pop();
              onTap();
            },
          );
        }

        return Padding(
          // v569 — `useSafeArea` ne protège pas le bas d'une feuille : la
          // dernière action (Annuler) passait sous la barre système.
          padding:
              EdgeInsets.fromLTRB(0, 8.h, 0, 8.h + appBottomInset(sheet)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.grey300Color,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              if (canReply)
                tile(Icons.reply_rounded, 'cs_action_reply'.tr,
                    () => session.setReply(m)),
              if (hasText)
                tile(Icons.copy_rounded, 'cs_action_copy'.tr, () async {
                  await Clipboard.setData(ClipboardData(text: m.message));
                  CustomSnackbar.showSuccess(
                    title: 'cs_action_copy'.tr,
                    message: 'cs_copied'.tr,
                  );
                }),
              if (hasText && !mine)
                tile(Icons.translate_rounded, 'cs_translate'.tr,
                    () => session.ensureTranslated(m)),
              if (mine && !m.isDeleted && !m.isPending)
                tile(Icons.delete_outline_rounded, 'chat_delete_message'.tr,
                    () => _confirmDelete(context),
                    color: AppColors.errorColor),
              if (!mine && !m.isDeleted)
                tile(Icons.flag_outlined, 'cs_action_report'.tr, () {
                  final photo = m.visualMedia.isNotEmpty
                      ? m.visualMedia.first.url
                      : null;
                  ReportDialog.show(
                    context: context,
                    targetType: photo != null ? 'photo' : 'message',
                    targetId: m.id,
                    conversationId: conversationId,
                    snapshot: m.message,
                    photoUrl: photo,
                  );
                }, color: AppColors.errorColor),
              tile(Icons.close_rounded, 'common_cancel'.tr, () {},
                  color: AppColors.textSecondary(sheet)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text('chat_delete_message'.tr),
        content: Text('chat_delete_message_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('common_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              'chat_delete_message'.tr,
              style: TextStyle(color: AppColors.errorColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await session.deleteMessage(message.id);
  }

  // ── rendu ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final m = message;
    final bubbleColor = mine ? theme.sentBubble : theme.receivedBubble(context);
    final textColor = mine ? theme.sentText : theme.receivedText(context);
    final maxW = MediaQuery.of(context).size.width * 0.74;

    final bubble = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      constraints: BoxConstraints(maxWidth: maxW),
      padding: EdgeInsets.fromLTRB(
        m.visualMedia.isNotEmpty ? 4.w : 12.w,
        m.visualMedia.isNotEmpty ? 4.h : 8.h,
        m.visualMedia.isNotEmpty ? 4.w : 10.w,
        6.h,
      ),
      decoration: BoxDecoration(
        color: highlighted ? theme.accent.withValues(alpha: 0.55) : bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
          bottomLeft: Radius.circular(mine ? 20.r : 6.r),
          bottomRight: Radius.circular(mine ? 6.r : 20.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Opacity(
        opacity: m.isPending ? 0.72 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.replyTo != null) _quote(context, m.replyTo!, textColor),
            if (m.isDeleted)
              _deleted(context, textColor)
            else ...[
              if (m.voiceAttachment != null)
                VoiceMessagePlayer(
                  attachment: m.voiceAttachment!,
                  mine: mine,
                  theme: theme,
                  pending: m.isPending,
                ),
              if (m.visualMedia.isNotEmpty) _mediaGrid(context, m.visualMedia),
              if (m.message.trim().isNotEmpty && !m.isVoice)
                Padding(
                  padding: EdgeInsets.only(
                    left: m.visualMedia.isNotEmpty ? 8.w : 0,
                    right: m.visualMedia.isNotEmpty ? 8.w : 0,
                    top: m.visualMedia.isNotEmpty ? 6.h : 0,
                  ),
                  child: Text(
                    m.message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14.sp,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              if (!mine && m.message.trim().isNotEmpty && !m.isVoice)
                _translation(context, textColor),
            ],
            SizedBox(height: 3.h),
            _meta(context, textColor),
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine && showAvatar) ...[
            ChatAvatar(imageUrl: m.senderImage, size: 28),
            SizedBox(width: 6.w),
          ] else if (!mine)
            SizedBox(width: 34.w),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => _showActions(context),
                  onTap: m.isFailed ? () => session.retryFailed(m.id) : null,
                  child: bubble,
                ),
                if (mine && showReadLabel && m.readAt != null)
                  ChatReadLabel(readAt: m.readAt!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quote(BuildContext context, ChatReplyRef r, Color textColor) {
    final fromMe = r.senderId.isNotEmpty && r.senderId == session.currentUserId;
    final who = fromMe ? 'cs_you'.tr : contactName;
    final barColor = mine ? Colors.white : theme.accent;
    return GestureDetector(
      onTap: () => onQuoteTap(r.messageId),
      child: Container(
        margin: EdgeInsets.only(bottom: 6.h),
        padding: EdgeInsets.fromLTRB(8.w, 6.h, 10.w, 6.h),
        decoration: BoxDecoration(
          color: theme.quoteBackground(mine, context),
          borderRadius: BorderRadius.circular(12.r),
          border: Border(left: BorderSide(color: barColor, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              who,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: mine ? Colors.white : theme.accent,
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              chatPreviewForKind(r.kind, r.body),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.85),
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deleted(BuildContext context, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.block_rounded,
            size: 13.sp, color: textColor.withValues(alpha: 0.7)),
        SizedBox(width: 6.w),
        Flexible(
          child: Text(
            'chat_message_deleted'.tr,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.75),
              fontSize: 13.sp,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _mediaGrid(BuildContext context, List<ChatAttachment> media) {
    final single = media.length == 1;
    final tile = single ? 220.w : 104.w;
    return Wrap(
      spacing: 4.w,
      runSpacing: 4.h,
      children: media.map((a) {
        final img = a.localPath != null
            ? Image.file(File(a.localPath!),
                width: tile, height: tile, fit: BoxFit.cover)
            : CachedNetworkImage(
                imageUrl: a.posterUrl,
                width: tile,
                height: tile,
                memCacheWidth: single ? 900 : 400,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: tile,
                  height: tile,
                  color: AppColors.grey300Color,
                  child: Center(
                    child: SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(theme.accent),
                      ),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: tile,
                  height: tile,
                  color: AppColors.grey300Color,
                  child: Icon(
                    a.isVideo
                        ? Icons.videocam_rounded
                        : Icons.broken_image_rounded,
                    size: 32.sp,
                    color: AppColors.greyColor,
                  ),
                ),
              );
        return GestureDetector(
          onTap: () => openChatMedia(context, a),
          onLongPress: () => _showActions(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: SizedBox(
              width: tile,
              height: tile,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  img,
                  if (a.isVideo) ...[
                    Container(color: Colors.black.withValues(alpha: 0.18)),
                    Center(
                      child: Container(
                        width: 44.w,
                        height: 44.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.play_arrow_rounded,
                            size: 28.sp, color: theme.accent),
                      ),
                    ),
                    if (a.duration != null)
                      Positioned(
                        left: 8.w,
                        bottom: 6.h,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            chatDuration(a.duration),
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                  if (message.isPending)
                    Center(
                      child: SizedBox(
                        width: 26.w,
                        height: 26.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _translation(BuildContext context, Color textColor) {
    return Obx(() {
      final id = message.id;
      final auto = session.autoTranslate.value;
      final has = session.translations.containsKey(id);
      final t = has ? session.translations[id] ?? '' : null;
      final busy = session.translating.contains(id);
      if (auto && !has && !busy) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          session.ensureTranslated(message);
        });
      }
      if (busy) {
        return Padding(
          padding: EdgeInsets.only(top: 4.h),
          child: SizedBox(
            width: 14.w,
            height: 14.w,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
            ),
          ),
        );
      }
      if (t != null && t.isNotEmpty && t.trim() != message.message.trim()) {
        return Padding(
          padding: EdgeInsets.only(top: 6.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 0.8, color: textColor.withValues(alpha: 0.15)),
              SizedBox(height: 5.h),
              Text(
                t,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.9),
                  fontSize: 13.5.sp,
                  height: 1.35,
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'cs_translated_label'.tr,
                style: TextStyle(
                  color: theme.accent,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }
      if (t != null && t.isEmpty) {
        return Padding(
          padding: EdgeInsets.only(top: 4.h),
          child: Text(
            'cs_translation_failed'.tr,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 10.5.sp,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }
      if (auto || has) return const SizedBox.shrink();
      return GestureDetector(
        onTap: () => session.ensureTranslated(message),
        child: Padding(
          padding: EdgeInsets.only(top: 5.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.translate_rounded, size: 12.sp, color: theme.accent),
              SizedBox(width: 4.w),
              Text(
                'cs_translate'.tr,
                style: TextStyle(
                  color: theme.accent,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _meta(BuildContext context, Color textColor) {
    final m = message;
    final c = textColor.withValues(alpha: 0.7);
    // v566 — coches façon WhatsApp à droite de l'heure (messages envoyés).
    final showTicks = mine && !m.isDeleted && !m.isSystem;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (m.isFailed) ...[
          Flexible(
            child: Text(
              'cs_tap_to_retry'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: 6.w),
        ],
        Text(
          chatClock(context, m.timestamp),
          style: TextStyle(color: c, fontSize: 10.sp),
        ),
        if (showTicks) ...[
          SizedBox(width: 3.w),
          ChatReceiptTicks(
            status: m.receiptStatus,
            greyColor: c,
            size: 13,
            onColoredBubble: true,
            failedColor: Colors.white,
          ),
        ],
      ],
    );
  }
}
