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

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: AppColors.lightGrey,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(),
        title: PoppinsText(
          text: 'blocked_users_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.blackColor,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Obx(() {
                  if (controller.isLoadingBlockedUsers.value) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.w),
                        child: CircularProgressIndicator(
                          color: AppColors.primaryColor,
                        ),
                      ),
                    );
                  }

                  if (controller.blockedUsers.isEmpty) {
                    return _buildEmptyState();
                  }

                  return Column(
                    children: controller.blockedUsers
                        .map(
                          (user) =>
                              _buildBlockedUserCard(context, user, controller),
                        )
                        .toList(),
                  );
                }),
              ),
            ),

            // Save Button at bottom - Commented out
            // Padding(
            //   padding: EdgeInsets.all(20.w),
            //   child: CustomButton(
            //     title: 'Save',
            //     onTap: controller.saveBlockedUsers,
            //     bgColor: AppColors.primaryColor,
            //     textColor: AppColors.whiteColor,
            //     height: 48.h,
            //     radius: 48.r,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 100.h),
          Icon(Icons.block, size: 64.sp, color: AppColors.greyColor),
          SizedBox(height: 16.h),
          InterText(
            text: 'blocked_users_empty_title'.tr,
            fontSize: 16.sp,
            color: AppColors.greyColor,
            fontWeight: FontWeight.w500,
          ),
          SizedBox(height: 8.h),
          InterText(
            text: 'blocked_users_empty_message'.tr,
            fontSize: 14.sp,
            color: AppColors.grey500Color,
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedUserCard(
    BuildContext context,
    BlockedUser user,
    ProfileController controller,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.textFieldBorder),
      ),
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
                      color: AppColors.lightGrey,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => CircleAvatar(
                      radius: 25.r,
                      backgroundColor: AppColors.grey300Color,
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
                  backgroundColor: AppColors.grey300Color,
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
                  color: AppColors.blackColor,
                ),

                PoppinsText(
                  text: user.company,
                  fontSize: 11.sp,
                  color: AppColors.grey500Color,
                  fontWeight: FontWeight.w400,
                ),
              ],
            ),
          ),

          // Unblock Button
          GestureDetector(
            onTap: () =>
                controller.showUnblockUserDialog(context, user.id, user.name),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              child: PoppinsText(
                text: 'blocked_users_unblock_button'.tr,
                fontSize: 12.sp,
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
