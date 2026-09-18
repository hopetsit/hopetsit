// v565 — Daniel : « dans Messages, moderniser le bouton Nouvelle conversation ».
// Pilule flottante à la couleur du rôle : icône « composer » dans un disque
// blanc translucide, libellé + sous-titre, halo coloré, léger retour haptique.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/widgets/app_text.dart';

class NewConversationButton extends StatelessWidget {
  const NewConversationButton({super.key, required this.theme, required this.onTap});

  final ChatRoleTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = theme.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, theme.accentDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(8.w, 8.h, 18.w, 8.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit_square, color: Colors.white, size: 18.sp),
                ),
                SizedBox(width: 10.w),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: 'chat_new_conversation_btn'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    InterText(
                      text: 'chat_new_conversation_sub'.tr,
                      fontSize: 10.5.sp,
                      color: Colors.white.withValues(alpha: 0.85),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
