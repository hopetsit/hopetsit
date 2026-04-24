import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Bell + optional count badge for AppBar [actions] (avoids title-area clipping).
class NotificationBellAction extends StatelessWidget {
  const NotificationBellAction({
    super.key,
    required this.count,
    required this.onTap,
    this.role = 'owner',
  });

  final int count;
  final VoidCallback onTap;
  /// v19.1.3 — role-colored bell : owner=orange, sitter=bleu, walker=vert.
  final String role;

  Color get _bellBg {
    switch (role) {
      case 'walker':
        return const Color(0xFF16A34A);
      case 'sitter':
        return const Color(0xFF2563EB);
      default:
        return AppColors.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, right: 4.w),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Material(
            color: _bellBg,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 38.w,
                height: 38.h,
                child: Center(
                  child: Image.asset(
                    AppImages.bellIcon,
                    width: 18.w,
                    height: 18.h,
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

/// v18.6 — Mini bouton "Boost" affiché dans la rangée d'actions de
/// l'AppBar, à côté de la cloche. Ouvre CoinShopScreen direct. Couleur
/// auto selon le rôle courant (vert walker / bleu sitter / orange owner).
class BoostQuickAction extends StatelessWidget {
  final String role; // 'owner' | 'sitter' | 'walker'
  const BoostQuickAction({super.key, required this.role});

  Color get _bg {
    switch (role) {
      case 'walker':
        return const Color(0xFF16A34A);
      case 'sitter':
        return const Color(0xFF2563EB);
      default:
        return AppColors.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, right: 4.w),
      child: Material(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Get.to(() => const CoinShopScreen()),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 38.w,
            height: 38.h,
            child: Center(
              child: Icon(
                Icons.rocket_launch_rounded,
                size: 20.sp,
                color: AppColors.whiteColor,
              ),
            ),
          ),
        ),
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
  /// v19.1.3 — role-colored bell: owner=orange, sitter=blue, walker=green.
  final String role;

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
    this.role = 'owner',
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
              role: role,
            ),
          ),
        );
      } else {
        mergedActions.add(
          NotificationBellAction(
            count: notificationBadgeCount ?? 0,
            onTap: onTap,
            role: role,
          ),
        );
      }
    }

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 70.h,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      backgroundColor: AppColors.appBar(context),
      title: title != null
          ? InterText(
              text: title!,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            )
          : Row(
              children: [
                GestureDetector(
                  onTap: onProfileTap,
                  child: Container(
                    width: 42.w,
                    height: 42.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.r),
                      color: AppColors.inputFill(context),
                      border: Border.all(color: AppColors.divider(context), width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13.r),
                      child:
                          userImage.startsWith('http://') ||
                              userImage.startsWith('https://')
                          ? CachedNetworkImage(
                              imageUrl: userImage,
                              width: 42.w,
                              height: 42.h,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppColors.lightGrey,
                                child: Icon(
                                  Icons.person,
                                  size: 22.sp,
                                  color: AppColors.primaryColor,
                                ),
                              ),
                              errorWidget: (context, url, error) => Icon(
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
                SizedBox(width: 12.w),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: InterText(
                          text: userName,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      _buildRoleBadge(),
                    ],
                  ),
                ),
              ],
            ),
      actions: mergedActions.isEmpty ? null : mergedActions,
    );
  }

  Widget _buildRoleBadge() {
    try {
      final authController = Get.find<AuthController>();
      final role = authController.userRole.value;
      if (role == null || role.isEmpty) return const SizedBox.shrink();

      final lower = role.toLowerCase();
      // Color + translation key by role (3 roles supported).
      Color badgeColor;
      String badgeKey;
      switch (lower) {
        case 'walker':
          badgeColor = AppColors.greenColor;
          badgeKey = 'role_pet_walker';
          break;
        case 'sitter':
          badgeColor = const Color(0xFF2196F3); // bleu
          badgeKey = 'role_pet_sitter';
          break;
        case 'owner':
        default:
          badgeColor = AppColors.primaryColor; // orange
          badgeKey = 'role_pet_owner';
          break;
      }
      final badgeLabel = badgeKey.tr;

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          badgeLabel,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  @override
  Size get preferredSize => Size.fromHeight(70.h);
}
