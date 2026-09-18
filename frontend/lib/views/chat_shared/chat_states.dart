// v565 — états vide / chargement / erreur du chat (liste et discussion).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/widgets/app_text.dart';

class ChatLoadingState extends StatelessWidget {
  const ChatLoadingState({super.key, required this.theme, this.label});
  final ChatRoleTheme theme;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28.w,
            height: 28.w,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
            ),
          ),
          if (label != null) ...[
            SizedBox(height: 12.h),
            InterText(
              text: label!,
              fontSize: 12.sp,
              color: AppColors.textSecondary(context),
            ),
          ],
        ],
      ),
    );
  }
}

class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    super.key,
    required this.theme,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.actionLabel,
  });

  final ChatRoleTheme theme;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                color: theme.tintStrong,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34.sp, color: theme.accent),
            ),
            SizedBox(height: 16.h),
            PoppinsText(
              text: title,
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 6.h),
            InterText(
              text: body,
              fontSize: 13.sp,
              color: AppColors.textSecondary(context),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              height: 1.4,
            ),
            if (action != null && actionLabel != null) ...[
              SizedBox(height: 18.h),
              ElevatedButton(
                onPressed: action,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22.r),
                  ),
                  padding:
                      EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChatErrorState extends StatelessWidget {
  const ChatErrorState({
    super.key,
    required this.theme,
    required this.title,
    required this.detail,
    required this.onRetry,
    this.locked = false,
  });

  final ChatRoleTheme theme;
  final String title;
  final String detail;
  final VoidCallback onRetry;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              locked ? Icons.lock_outline_rounded : Icons.wifi_off_rounded,
              size: 44.sp,
              color: locked ? theme.accent : AppColors.greyColor,
            ),
            SizedBox(height: 12.h),
            InterText(
              text: title,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (detail.isNotEmpty) ...[
              SizedBox(height: 6.h),
              InterText(
                text: detail,
                fontSize: 11.sp,
                color: AppColors.greyText,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 16.h),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.accent,
                side: BorderSide(color: theme.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22.r),
                ),
              ),
              icon: Icon(Icons.refresh_rounded, size: 18.sp),
              label: Text('chat_retry'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
