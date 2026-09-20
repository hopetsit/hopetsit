// v565 — en-tête de discussion : retour, avatar, nom, statut en ligne /
// vu il y a X (point 10), actions du rôle à droite.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/chat_shared/chat_avatar.dart';
import 'package:hopetsit/views/chat_shared/chat_session.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/views/chat_shared/chat_time.dart';
import 'package:hopetsit/widgets/app_text.dart';

class ChatHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatHeaderBar({
    super.key,
    required this.session,
    required this.theme,
    required this.contactName,
    required this.contactImage,
    this.actions = const [],
    this.onTitleTap,
  });

  final ChatSession session;
  final ChatRoleTheme theme;
  final String contactName;
  final String contactImage;
  final List<Widget> actions;
  final VoidCallback? onTitleTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
      backgroundColor: AppColors.appBar(context),
      titleSpacing: 0,
      leadingWidth: 40.w,
      leading: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: theme.accentOn(context), size: 20.sp),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTitleTap,
        child: Row(
          children: [
            Obx(() => ChatAvatar(
                  imageUrl: contactImage,
                  size: 40,
                  online: session.peerOnline.value,
                )),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PoppinsText(
                    text: contactName,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Obx(() {
                    final online = session.peerOnline.value;
                    final seen = session.peerLastSeen.value;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7.w,
                          height: 7.w,
                          decoration: BoxDecoration(
                            color: online
                                ? ChatRoleTheme.online
                                : ChatRoleTheme.offline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 5.w),
                        Flexible(
                          child: InterText(
                            text: chatPresenceLabel(online, seen),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: online
                                ? ChatRoleTheme.online
                                : AppColors.textSecondary(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [...actions, SizedBox(width: 6.w)],
    );
  }
}

/// Petit bouton d'action d'en-tête (pilule teintée + icône) — utilisé pour
/// le bouton « Suivre » / « Partager ma position » du rôle.
class ChatHeaderPill extends StatelessWidget {
  const ChatHeaderPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ChatRoleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 4.w),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20.r),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(maxWidth: 150.w),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: theme.accent,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14.sp, color: Colors.white),
                SizedBox(width: 5.w),
                Flexible(
                  child: InterText(
                    text: label,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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
