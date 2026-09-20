import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';

class BlockedUser {
  final String id; // Block ID
  final String sitterId; // Sitter ID for unblocking
  final String name;
  final String company;
  final String profileImage;
  final DateTime blockedAt;

  BlockedUser({
    required this.id,
    required this.sitterId,
    required this.name,
    required this.company,
    required this.profileImage,
    required this.blockedAt,
  });
}

class BlockedUsersScreen extends StatelessWidget {
  final String userType;

  const BlockedUsersScreen({super.key, this.userType = 'pet_owner'});

  @override
  Widget build(BuildContext context) {
    // Try to find existing controller first, if not found create new one
    ProfileController controller;
    try {
      controller = Get.find<ProfileController>();
    } catch (e) {
      // Ensure dependencies are registered before creating controller
      if (!Get.isRegistered<GetStorage>()) {
        Get.put(GetStorage(), permanent: true);
      }
      if (!Get.isRegistered<ApiClient>()) {
        Get.put(ApiClient(storage: Get.find<GetStorage>()), permanent: true);
      }
      if (!Get.isRegistered<OwnerRepository>()) {
        Get.put(OwnerRepository(Get.find<ApiClient>()), permanent: true);
      }
      controller = Get.put(ProfileController());
    }

    // Load blocked users on screen open
    controller.loadBlockedUsers();

    // v565 — sous-page modernisée (kit Profil) : accent du rôle, états
    // chargement/vide, tirer pour rafraîchir, cartes groupées.
    final accent = userType == 'pet_sitter'
        ? profileAccentFor('sitter')
        : (userType == 'pet_walker' ? profileAccentFor('walker') : currentRoleAccent());
    return ProfileSubPageScaffold(
      title: 'blocked_users_title'.tr,
      accent: accent,
      scroll: false,
      body: Obx(() {
        if (controller.isLoadingBlockedUsers.value && controller.blockedUsers.isEmpty) {
          return Center(child: CircularProgressIndicator(color: accent));
        }
        return RefreshIndicator(
          color: accent,
          onRefresh: controller.loadBlockedUsers,
          child: controller.blockedUsers.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: 60.h),
                    ProfileEmptyState(
                      icon: Icons.block_rounded,
                      title: 'blocked_users_empty_title'.tr,
                      message: 'blocked_users_empty_message'.tr,
                      accent: accent,
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 28.h),
                  children: [
                    ProfileGroupCard(
                      children: [
                        for (final user in controller.blockedUsers)
                          _buildBlockedUserCard(context, user, controller, accent),
                      ],
                    ),
                  ],
                ),
        );
      }),
    );
  }

  Widget _buildBlockedUserCard(
    BuildContext context,
    BlockedUser user,
    ProfileController controller,
    Color accent,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: Row(
        children: [
          // Profile Picture
          user.profileImage.startsWith('http://') ||
                  user.profileImage.startsWith('https://')
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: user.profileImage,
                    width: 50.w,
                    height: 50.h,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 50.w,
                      height: 50.h,
                      // v571 — mode sombre : #F1F2F4 = disque blanc éblouissant.
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.dividerDark
                          : AppColors.lightGrey,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => CircleAvatar(
                      radius: 25.r,
                      backgroundColor: AppColors.divider(context),
                      child: Icon(
                        Icons.person,
                        size: 25.sp,
                        color: AppColors.greyColor,
                      ),
                    ),
                  ),
                )
              : CircleAvatar(
                  radius: 25.r,
                  backgroundColor: AppColors.divider(context),
                  backgroundImage: user.profileImage.isNotEmpty
                      ? AssetImage(user.profileImage)
                      : null,
                  child: user.profileImage.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 25.sp,
                          color: AppColors.greyColor,
                        )
                      : null,
                ),

          SizedBox(width: 10.w),

          // User Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PoppinsText(
                  text: user.name,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),

                PoppinsText(
                  text: user.company,
                  fontSize: 11.sp,
                  color: AppColors.textSecondary(context),
                  fontWeight: FontWeight.w400,
                ),
              ],
            ),
          ),

          // Unblock Button
          TextButton(
            onPressed: () =>
                controller.showUnblockUserDialog(context, user.id, user.name),
            style: TextButton.styleFrom(
              backgroundColor: accent.withValues(alpha: 0.12),
              foregroundColor: accent,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: PoppinsText(
              text: 'blocked_users_unblock_button'.tr,
              fontSize: 12.sp,
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
