import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';

/// v23.1 — Custom header pour les home screens. Ne dépend PAS du widget
/// AppBar de Flutter, qui causait un grey rectangle persistant à droite.
///
/// Layout 100% explicite : Container blanc plein-écran, SafeArea top, Row
/// avec avatar + userName à gauche et actions à droite. Aucune magie M3,
/// aucun surfaceTintColor, aucun flexibleSpace.
class HomeHeader extends StatelessWidget implements PreferredSizeWidget {
  final String userName;
  final String userImage;
  final List<Widget> actions;
  final RxInt? notificationUnreadRx;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final String role;

  const HomeHeader({
    super.key,
    required this.userName,
    required this.userImage,
    this.actions = const [],
    this.notificationUnreadRx,
    this.onNotificationTap,
    this.onProfileTap,
    this.role = 'owner',
  });

  @override
  Size get preferredSize => Size.fromHeight(70.h);

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.appBar(context);
    final mergedActions = <Widget>[
      ...actions,
      // Notification bell, role-aware (badge supprimé sur home).
      NotificationBellAction(
        count: 0,
        onTap: onNotificationTap ?? () {},
        role: role,
      ),
    ];

    return Material(
      color: bgColor,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 70.h,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ─── LEFT : avatar + userName + role badge ─────────────
                GestureDetector(
                  onTap: onProfileTap ?? () {},
                  child: Container(
                    width: 42.w,
                    height: 42.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.r),
                      color: AppColors.inputFill(context),
                      border: Border.all(
                          color: AppColors.divider(context), width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13.r),
                      child: (userImage.startsWith('http://') ||
                              userImage.startsWith('https://'))
                          ? CachedNetworkImage(
                              imageUrl: userImage,
                              width: 42.w,
                              height: 42.w,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Icon(
                                Icons.person,
                                size: 22.sp,
                                color: AppColors.primaryColor,
                              ),
                              errorWidget: (_, __, ___) => Icon(
                                Icons.person,
                                size: 22.sp,
                                color: AppColors.primaryColor,
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 22.sp,
                              color: AppColors.primaryColor,
                            ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: InterText(
                          text: userName,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      _buildRoleBadge(context),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                // ─── RIGHT : caller actions + notification bell ────────
                ...mergedActions,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Petit badge coloré indiquant le rôle (Owner / Sitter / Walker).
  Widget _buildRoleBadge(BuildContext context) {
    try {
      final authController = Get.find<AuthController>();
      final r = authController.userRole.value;
      if (r == null || r.isEmpty) return const SizedBox.shrink();
      final lower = r.toLowerCase();
      Color badgeColor;
      String badgeKey;
      switch (lower) {
        case 'walker':
          badgeColor = const Color(0xFF16A34A);
          badgeKey = 'role_walker';
          break;
        case 'sitter':
          badgeColor = const Color(0xFF2563EB);
          badgeKey = 'role_sitter';
          break;
        default:
          badgeColor = AppColors.primaryColor;
          badgeKey = 'role_owner';
      }
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: InterText(
          text: badgeKey.tr,
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: badgeColor,
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
