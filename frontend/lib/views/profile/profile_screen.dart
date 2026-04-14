import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/views/profile/terms_and_conditions_screen.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/widgets/loyalty_card.dart';
import 'package:hopetsit/views/profile/my_referrals_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ProfileController controller = Get.put(ProfileController());

    return Scaffold(
      appBar: CustomAppBar(
        title: 'title_profile'.tr,
        showNotificationIcon: false,
        userName: '',
        userImage: '',
      ),
      // Sprint 6 step 4 — theme-driven bg
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16.w,
            0.w,
            16.w,
            100.h,
          ), // Extra bottom padding for navigation bar
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10.h),

              // Profile Information Section
              _buildProfileInfo(controller),

              SizedBox(height: 10.h),

              // Switch Role Card
              _buildSwitchRoleCard(context),
              SizedBox(height: 20.h),

              // Settings Section
              _buildSettingsSection(context, controller),

              SizedBox(height: 30.h),

              // Logout Button
              Center(
                child: CustomButton(
                  width: 305.w,
                  radius: 48.r,
                  isGradient: false,
                  title: 'button_logout'.tr,
                  bgColor: AppColors.primaryColor,
                  textColor: AppColors.whiteColor,
                  onTap: () => controller.showLogoutDialog(context),
                ),
              ),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfo(ProfileController controller) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Large Profile Picture with Edit Icon
          Stack(
            children: [
              Obx(() {
                final imageUrl = controller.profileImageUrl.value;
                final isUploading = controller.isUploadingImage.value;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(70.r),
                  child: Container(
                    width: 120.w,
                    height: 120.h,
                    color: AppColors.lightGrey,
                    child: isUploading
                        ? Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                            ),
                          )
                        : imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 140.w,
                            height: 140.h,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.lightGrey,
                              child: Icon(
                                Icons.person,
                                size: 70.sp,
                                color: AppColors.primaryColor,
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.person,
                              size: 70.sp,
                              color: AppColors.primaryColor,
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 70.sp,
                            color: AppColors.primaryColor,
                          ),
                  ),
                );
              }),
              Obx(() {
                if (controller.isUploadingImage.value) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  bottom: 0,
                  right: 13.w,
                  child: Container(
                    width: 24.w,
                    height: 24.h,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.whiteColor, width: 2),
                    ),
                    child: GestureDetector(
                      onTap: controller.pickAndUploadProfilePicture,
                      child: SvgPicture.asset(
                        AppImages.editIcon,
                        height: 28.h,
                        width: 28.w,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),

          SizedBox(width: 20.w),

          // Contact Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(
                  () => InterText(
                    text: controller.userName.value,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.blackColor,
                  ),
                ),

                SizedBox(height: 12.h),

                // Phone
                Row(
                  children: [
                    Image.asset(AppImages.callIcon),
                    SizedBox(width: 8.w),
                    Obx(
                      () => InterText(
                        text: controller.phoneNumber.value.trim().isEmpty
                            ? 'profile_no_phone_added'.tr
                            : controller.phoneNumber.value,
                        fontSize: 14.sp,
                        color: AppColors.grey500Color,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8.h),

                // Email
                Row(
                  children: [
                    Image.asset(AppImages.addressIcon),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Obx(
                          () => InterText(
                            text: controller.email.value.trim().isEmpty
                                ? 'profile_no_email_added'.tr
                                : controller.email.value,
                            fontSize: 14.sp,
                            color: AppColors.grey500Color,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8.h),

                // Role
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 20.sp,
                      color: AppColors.primaryColor,
                    ),
                    SizedBox(width: 8.w),
                    Obx(() {
                      final role = Get.find<AuthController>().userRole.value;
                      String displayRole = 'label_not_available'.tr;
                      if (role == 'owner') {
                        displayRole = 'role_pet_owner'.tr;
                      } else if (role == 'sitter') {
                        displayRole = 'role_pet_sitter'.tr;
                      }
                      return InterText(
                        text: displayRole,
                        fontSize: 14.sp,
                        color: AppColors.grey500Color,
                        fontWeight: FontWeight.w400,
                      );
                    }),
                  ],
                ),

                SizedBox(height: 8.h),

                // Service
                Row(
                  children: [
                    Icon(
                      Icons.work_outline,
                      size: 20.sp,
                      color: AppColors.primaryColor,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Obx(
                          () => InterText(
                            text:
                                controller.profile.value?.service.isNotEmpty ==
                                    true
                                ? controller.profile.value!.service.join(', ')
                                : 'label_not_available'.tr,
                            fontSize: 14.sp,
                            color: AppColors.grey500Color,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    ProfileController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PoppinsText(
          text: 'section_settings'.tr,
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.blackColor,
        ),

        SizedBox(height: 15.h),

        _buildSettingsTile(
          'profile_add_tasks'.tr,
          Icons.arrow_forward_ios,
          controller.navigateToAddTasks,
        ),
        _buildSettingsTile(
          'profile_view_tasks'.tr,
          Icons.arrow_forward_ios,
          controller.navigateToViewTask,
        ),
        _buildSettingsTile(
          'profile_bookings_history'.tr,
          Icons.arrow_forward_ios,
          controller.navigateToBookingsHistory,
        ),
        _buildSettingsTile(
          'profile_edit_profile'.tr,
          Icons.arrow_forward_ios,
          controller.navigateToEditProfile,
        ),
        _buildSettingsTile(
          'profile_edit_pets_profile'.tr,
          Icons.arrow_forward_ios,
          controller.navigateToEditPetProfile,
        ),
        _buildSettingsTile(
          'profile_choose_service'.tr,
          Icons.arrow_forward_ios,
          controller.navigateToChooseService,
        ),
        _buildSettingsTile(
          'profile_change_password'.tr,
          Icons.arrow_forward_ios,
          controller.navigateToChangePassword,
        ),
        _buildSettingsTile(
          'profile_change_language'.tr,
          Icons.keyboard_arrow_down,
          controller.showLanguageDialog,
        ),
        _buildSettingsTile(
          'profile_blocked_users'.tr,
          Icons.arrow_forward_ios,
          controller.navigateToBlockedUsers,
        ),
        // Sprint 7 step 1 — loyalty card
        const LoyaltyCard(),
        // Sprint 7 step 3 — referrals tile.
        _buildSettingsTile(
          'referrals_title'.tr,
          Icons.group_add,
          () => Get.to(() => const MyReferralsScreen()),
        ),
        // Sprint 5 step 4 — access T&C.
        _buildSettingsTile(
          'terms_read_button'.tr,
          Icons.arrow_forward_ios,
          () => Get.to(() => const TermsAndConditionsScreen()),
        ),
        // Sprint 6 step 1 — theme mode.
        _buildSettingsTile(
          'theme_setting_title'.tr,
          Icons.brightness_6,
          () => _showThemeDialog(),
        ),
        // _buildSettingsTile(
        //   'Payment Method',
        //   Icons.arrow_forward_ios,
        //   controller.navigateToAddCard,
        // ),
        // _buildSettingsTile(
        //   'Reviews',
        //   Icons.arrow_forward_ios,
        //   controller.navigateToReviews,
        // ),
        // _buildSettingsTile(
        //   'Donate Us',
        //   Icons.arrow_forward_ios,
        //   controller.navigateToDonate,
        // ),
        _buildSettingsTile(
          'profile_delete_account'.tr,
          Icons.arrow_forward_ios,
          () => controller.showDeleteAccountDialog(context),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.textFieldBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InterText(
              text: title,
              fontSize: 14.sp,
              color: AppColors.greyText,
              fontWeight: FontWeight.w500,
            ),
            Icon(icon, size: 20.sp, color: AppColors.greyText),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRoleCard(BuildContext context) {
    final authController = Get.find<AuthController>();
    final currentRole = authController.userRole.value;
    final newRoleKey = currentRole == 'owner'
        ? 'role_pet_sitter'
        : 'role_pet_owner';
    final newRoleText = newRoleKey.tr;
    final switchDescription = 'profile_switch_role_card_description'.trParams({
      'role': newRoleText,
    });

    return GestureDetector(
      onTap: () => _showSwitchRoleDialog(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.primaryColor, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InterText(
                    text: 'profile_switch_role_card_title'.trParams({
                      'role': newRoleText,
                    }),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryColor,
                  ),
                  SizedBox(height: 8.h),
                  InterText(
                    text: switchDescription,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.greyText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Icon(
              Icons.arrow_forward_ios,
              size: 20.sp,
              color: AppColors.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showSwitchRoleDialog(BuildContext context) {
    final authController = Get.find<AuthController>();
    final currentRole = authController.userRole.value;
    final newRoleKey = currentRole == 'owner'
        ? 'role_pet_sitter'
        : 'role_pet_owner';
    final newRoleText = newRoleKey.tr;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Obx(() {
          final isLoading = authController.isSwitchingRole.value;
          return AlertDialog(
            backgroundColor: AppColors.whiteColor,
            title: Text('dialog_switch_role_title'.tr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16.h),
                    child: const CircularProgressIndicator(),
                  ),
                Text(
                  isLoading
                      ? 'dialog_switch_role_switching'.trParams({
                          'role': newRoleText,
                        })
                      : 'dialog_switch_role_confirm'.trParams({
                          'role': newRoleText,
                        }),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text('common_cancel'.tr),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        await authController.switchRole();
                        if (Get.isDialogOpen == true) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                child: Text(
                  'dialog_switch_role_button'.trParams({'role': newRoleText}),
                  style: TextStyle(
                    color: isLoading ? Colors.grey : Colors.blue,
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  // Sprint 6 step 1 — theme picker dialog.
  void _showThemeDialog() {
    final tc = Get.find<ThemeController>();
    Get.dialog(
      AlertDialog(
        title: Text('theme_setting_title'.tr),
        content: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: Text('theme_light'.tr),
                value: ThemeMode.light,
                groupValue: tc.themeMode.value,
                onChanged: (v) => v != null ? tc.setMode(v) : null,
              ),
              RadioListTile<ThemeMode>(
                title: Text('theme_dark'.tr),
                value: ThemeMode.dark,
                groupValue: tc.themeMode.value,
                onChanged: (v) => v != null ? tc.setMode(v) : null,
              ),
              RadioListTile<ThemeMode>(
                title: Text('theme_system'.tr),
                value: ThemeMode.system,
                groupValue: tc.themeMode.value,
                onChanged: (v) => v != null ? tc.setMode(v) : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('common_close'.tr),
          ),
        ],
      ),
    );
  }
}
