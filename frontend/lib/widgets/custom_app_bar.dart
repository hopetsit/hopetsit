import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Bell + optional count badge for AppBar [actions] (avoids title-area clipping).
class NotificationBellAction extends StatelessWidget {
  const NotificationBellAction({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, right: 4.w),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Material(
            color: AppColors.primaryColor,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40.w,
                height: 40.h,
                child: Center(
                  child: Image.asset(
                    AppImages.bellIcon,
                    width: 20.w,
                    height: 20.h,
                    color: AppColors.whiteColor,
                  ),
                ),
              ),
            ),
          ),
          if (count > 0)
            Positioned(
              right: -2,
              top: -4,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: count > 9 ? 4.w : 5.w,
                  vertical: 2.h,
                ),
                constraints: BoxConstraints(minWidth: 18.w, minHeight: 18.w),
                decoration: const BoxDecoration(
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String userName;
  final String userImage;
  final bool showNotificationIcon;

  /// Unread count for badge on bell; when null or 0, no badge.
  /// Prefer [notificationUnreadRx] so the badge rebuilds via [Obx] without
  /// relying on the parent widget to observe GetX.
  final int? notificationBadgeCount;
  final RxInt? notificationUnreadRx;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final String? title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Widget? leading;

  const CustomAppBar({
    super.key,
    required this.userName,
    required this.userImage,
    this.showNotificationIcon = true,
    this.notificationBadgeCount,
    this.notificationUnreadRx,
    this.onNotificationTap,
    this.onProfileTap,
    this.title,
    this.actions,
    this.automaticallyImplyLeading = false,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    // Bell must live in [actions], not in [title], or AppBar clips the badge.
    // AppBar: first [actions] child is the trailing (rightmost) widget — put
    // caller actions first (e.g. map on the far right), then the bell to its left.
    final List<Widget> mergedActions = [];
    if (actions != null && actions!.isNotEmpty) {
      mergedActions.addAll(actions!);
    }
    if (showNotificationIcon) {
      final onTap = onNotificationTap ?? () {};
      if (notificationUnreadRx != null) {
        mergedActions.add(
          Obx(
            () => NotificationBellAction(
              count: notificationUnreadRx!.value,
              onTap: onTap,
            ),
          ),
        );
      } else {
        mergedActions.add(
          NotificationBellAction(
            count: notificationBadgeCount ?? 0,
            onTap: onTap,
          ),
        );
      }
    }

    return AppBar(
      elevation: 0,
      toolbarHeight: 70.h,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      backgroundColor: AppColors.whiteColor,
      title: title != null
          ? InterText(
              text: title!,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.blackColor,
            )
          : Row(
              children: [
                GestureDetector(
                  onTap: onProfileTap,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20.r),
                    child: Container(
                      width: 40.w,
                      height: 40.h,
                      color: AppColors.lightGrey,
                      child:
                          userImage.startsWith('http://') ||
                              userImage.startsWith('https://')
                          ? CachedNetworkImage(
                              imageUrl: userImage,
                              width: 40.w,
                              height: 40.h,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppColors.lightGrey,
                                child: Icon(
                                  Icons.person,
                                  size: 24.sp,
                                  color: AppColors.primaryColor,
                                ),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.person,
                                size: 24.sp,
                                color: AppColors.primaryColor,
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 24.sp,
                              color: AppColors.primaryColor,
                            ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: InterText(
                    text: userName,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blackColor,
                  ),
                ),
              ],
            ),
      actions: mergedActions.isEmpty ? null : mergedActions,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(70.h);
}
