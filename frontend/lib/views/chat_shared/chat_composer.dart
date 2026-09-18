// v565 — zone de saisie du chat (points 13, 16, 18) : menu « + » regroupant
// toutes les actions, aperçu de la citation, champ de texte, micro (appui
// long = enregistrer / glisser = annuler / relâcher = envoyer ; tap =
// enregistrement verrouillé), bouton envoyer.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/chat_session.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/views/chat_shared/voice_recorder.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Une entrée du menu « + ».
class ChatMenuItem {
  const ChatMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
}

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.session,
    required this.theme,
    required this.textController,
    required this.focusNode,
    required this.onSendText,
    required this.contactName,
    this.roleMenuItems = const [],
  });

  final ChatSession session;
  final ChatRoleTheme theme;
  final TextEditingController textController;
  final FocusNode focusNode;
  final VoidCallback onSendText;
  final String contactName;

  /// Actions propres au rôle (partager numéro / adresse, PawFollow…), après
  /// les actions communes (photo, caméra, vidéo, vocal, traduction).
  final List<ChatMenuItem> roleMenuItems;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final VoiceRecordController _rec = VoiceRecordController();

  @override
  void initState() {
    super.initState();
    _rec.onSend = (file, seconds) => widget.session.sendVoice(file, seconds);
    _rec.addListener(_onRec);
  }

  void _onRec() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _rec.removeListener(_onRec);
    _rec.dispose();
    super.dispose();
  }

  // ── menu « + » ───────────────────────────────────────────────────────────
  void _openMenu() {
    widget.focusNode.unfocus();
    final s = widget.session;
    final t = widget.theme;
    final f = s.features.value;
    final items = <ChatMenuItem>[
      if (f.media) ...[
        ChatMenuItem(
          icon: Icons.photo_library_rounded,
          label: 'cs_action_photo'.tr,
          color: const Color(0xFF7C3AED),
          onTap: s.pickPhotos,
        ),
        ChatMenuItem(
          icon: Icons.photo_camera_rounded,
          label: 'cs_action_camera'.tr,
          color: const Color(0xFFE8920A),
          onTap: s.takePhoto,
        ),
        ChatMenuItem(
          icon: Icons.videocam_rounded,
          label: 'cs_action_video'.tr,
          subtitle: 'cs_video_limit'.tr,
          color: const Color(0xFF0EA5E9),
          onTap: s.pickVideo,
        ),
      ],
      if (f.voice)
        ChatMenuItem(
          icon: Icons.mic_rounded,
          label: 'cs_action_voice'.tr,
          subtitle: 'cs_rec_hold_hint'.tr,
          color: AppColors.errorColor,
          onTap: () => _rec.start(locked: true),
        ),
      ...widget.roleMenuItems,
      ChatMenuItem(
        icon: Icons.translate_rounded,
        label: s.autoTranslate.value
            ? 'cs_action_translate_off'.tr
            : 'cs_action_translate_on'.tr,
        subtitle: 'cs_action_translate_sub'.tr,
        color: const Color(0xFF0F766E),
        onTap: () => s.autoTranslate.value = !s.autoTranslate.value,
      ),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card(context),
      useSafeArea: true,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheet) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.grey300Color,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                PoppinsText(
                  text: 'cs_menu_title'.tr,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(sheet),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8.h),
                ...items.map((it) => _MenuRow(item: it, sheet: sheet, theme: t)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── rendu ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final s = widget.session;
    return Container(
      padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 8.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() {
            final r = s.replyTarget.value;
            if (r == null) return const SizedBox.shrink();
            return _ReplyPreview(
              target: r,
              theme: t,
              contactName: widget.contactName,
              mineId: s.currentUserId,
              onClose: () => s.setReply(null),
            );
          }),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_rec.isRecording) ...[
                _RoundButton(
                  icon: Icons.add_rounded,
                  color: t.accent,
                  background: t.tintStrong,
                  onTap: _openMenu,
                ),
                SizedBox(width: 8.w),
              ],
              Expanded(
                child: _rec.isRecording
                    ? VoiceRecordingBar(controller: _rec, theme: t)
                    : Container(
                        constraints: BoxConstraints(
                          minHeight: 44.h,
                          maxHeight: 130.h,
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 14.w),
                        decoration: BoxDecoration(
                          color: AppColors.inputFill(context),
                          borderRadius: BorderRadius.circular(22.r),
                        ),
                        child: TextField(
                          controller: widget.textController,
                          focusNode: widget.focusNode,
                          decoration: InputDecoration(
                            hintText: 'chat_input_hint'.tr,
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 14.sp,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 12.h),
                          ),
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 14.sp,
                          ),
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline,
                        ),
                      ),
              ),
              SizedBox(width: 8.w),
              _trailingButton(t, s),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trailingButton(ChatRoleTheme t, ChatSession s) {
    if (_rec.isRecording && _rec.locked) {
      return _RoundButton(
        icon: Icons.send_rounded,
        color: Colors.white,
        background: t.accent,
        onTap: () => _rec.stop(send: true),
      );
    }
    if (_rec.isRecording) {
      // Appui maintenu : le bouton reste sous le doigt (GestureDetector
      // ci-dessous continue de recevoir les mouvements).
      return _micButton(t, s, active: true);
    }
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.textController,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        if (hasText) {
          return _RoundButton(
            icon: Icons.send_rounded,
            color: Colors.white,
            background: t.accent,
            onTap: widget.onSendText,
          );
        }
        return Obx(() {
          if (!s.features.value.voice) {
            return _RoundButton(
              icon: Icons.send_rounded,
              color: AppColors.greyColor,
              background: AppColors.grey300Color.withValues(alpha: 0.5),
              onTap: widget.onSendText,
            );
          }
          return _micButton(t, s, active: false);
        });
      },
    );
  }

  Widget _micButton(ChatRoleTheme t, ChatSession s, {required bool active}) {
    return GestureDetector(
      onTap: () {
        if (!_rec.isRecording) _rec.start(locked: true);
      },
      onLongPressStart: (_) {
        if (!_rec.isRecording) _rec.start(locked: false);
      },
      onLongPressMoveUpdate: (d) {
        if (_rec.isRecording && !_rec.locked) {
          _rec.setCancelArmed(d.offsetFromOrigin.dx < -70);
        }
      },
      onLongPressEnd: (_) {
        if (_rec.isRecording && !_rec.locked) {
          _rec.stop(send: !_rec.cancelArmed);
        }
      },
      onLongPressCancel: () {
        if (_rec.isRecording && !_rec.locked) _rec.stop(send: false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: active ? 52.w : 44.w,
        height: active ? 52.w : 44.w,
        decoration: BoxDecoration(
          color: active ? AppColors.errorColor : t.accent,
          shape: BoxShape.circle,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.errorColor.withValues(alpha: 0.4),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(Icons.mic_rounded, color: Colors.white, size: 22.sp),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44.w,
          height: 44.w,
          child: Icon(icon, color: color, size: 24.sp),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.sheet, required this.theme});
  final ChatMenuItem item;
  final BuildContext sheet;
  final ChatRoleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () {
          Navigator.of(sheet).pop();
          item.onTap();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 9.h, horizontal: 4.w),
          child: Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(item.icon, color: item.color, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InterText(
                      text: item.label,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subtitle != null)
                      InterText(
                        text: item.subtitle!,
                        fontSize: 11.5.sp,
                        color: AppColors.textSecondary(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.greyColor, size: 20.sp),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.target,
    required this.theme,
    required this.contactName,
    required this.mineId,
    required this.onClose,
  });
  final ChatMessageBase target;
  final ChatRoleTheme theme;
  final String contactName;
  final String mineId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final who = target.isFromCurrentUser ? 'cs_you'.tr : contactName;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.fromLTRB(10.w, 8.h, 4.w, 8.h),
      decoration: BoxDecoration(
        color: theme.tint,
        borderRadius: BorderRadius.circular(14.r),
        border: Border(left: BorderSide(color: theme.accent, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 18.sp, color: theme.accent),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: '${'cs_action_reply'.tr} · $who',
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w800,
                  color: theme.accent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                InterText(
                  text: chatPreviewForKind(target.replyKind, target.message),
                  fontSize: 12.sp,
                  color: AppColors.textSecondary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: Icon(Icons.close_rounded,
                size: 18.sp, color: AppColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }
}
