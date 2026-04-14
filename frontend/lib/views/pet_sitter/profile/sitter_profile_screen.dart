import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/views/pet_sitter/profile/iban_setup_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/availability_calendar_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/identity_verification_screen.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/widgets/top_sitter_card.dart';
import 'package:hopetsit/views/profile/my_referrals_screen.dart';

class SitterProfileScreen extends StatelessWidget {
  const SitterProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Safely get or create the controller
    final SitterProfileController controller;
    if (Get.isRegistered<SitterProfileController>()) {
      controller = Get.find<SitterProfileController>();
    } else {
      controller = Get.put(SitterProfileController());
    }

    return Scaffold(
      backgroundColor: AppColors.white38Color,
      appBar: CustomAppBar(
        title: 'title_profile'.tr,
        showNotificationIcon: false,
        userName: '',
        userImage: '',
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16.w,
            0,
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

  Widget _buildProfileInfo(SitterProfileController controller) {
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
              Obx(
                () => CircleAvatar(
                  radius: 55.r,
                  backgroundColor: AppColors.grey300Color,
                  backgroundImage: controller.profileImageUrl.value.isNotEmpty
                      ? CachedNetworkImageProvider(
                          controller.profileImageUrl.value,
                        )
                      : null,
                  child: controller.profileImageUrl.value.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 50.sp,
                          color: AppColors.greyColor,
                        )
                      : null,
                ),
              ),
              Positioned(
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
                    onTap: controller.editProfile,
                    child: SvgPicture.asset(
                      AppImages.editIcon,
                      height: 28.h,
                      width: 28.w,
                    ),
                  ),
                ),
              ),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Image.asset(AppImages.addressIcon),
                      SizedBox(width: 8.w),
                      Obx(
                        () => InterText(
                          text: controller.email.value.trim().isEmpty
                              ? 'profile_no_email_added'.tr
                              : controller.email.value,
                          fontSize: 14.sp,
                          color: AppColors.grey500Color,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
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
                                : 'N/A',
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
    SitterProfileController controller,
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
        // Switch Role Card
        _buildSwitchRoleCard(context),
        SizedBox(height: 20.h),

        _buildSettingsTile(
          'profile_edit_profile'.tr,
          Icons.arrow_forward_ios,
          controller.navigateToEditProfile,
        ),
        // Complete Profile - commented out
        // _buildSettingsTile(
        //   'Complete Profile',
        //   Icons.arrow_forward_ios,
        //   controller.navigateToPetsitterOnboarding,
        // ),
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
        //   'Blocked Users',
        //   Icons.arrow_forward_ios,
        //   controller.navigateToBlockedUsers,
        // ),
        // _buildSettingsTile(
        //   'Payment Method',
        //   Icons.arrow_forward_ios,
        //   controller.navigateToAddCard,
        // ),
        // Sprint 7 step 2 — Top Sitter progress card.
        const TopSitterCard(),
        // Sprint 7 step 3 — referrals tile.
        _buildSettingsTile(
          'referrals_title'.tr,
          Icons.group_add,
          () => Get.to(() => const MyReferralsScreen()),
        ),
        _buildStripeConnectTile(controller),
        _buildSettingsTile(
          'payout_status_screen_title'.tr,
          Icons.payment,
          controller.navigateToPayoutStatus,
        ),
        // FIX: IBAN bank payout (like Vinted)
        _buildSettingsTile(
          'iban_title'.tr,
          Icons.account_balance_outlined,
          () => Get.to(() => const IbanSetupScreen()),
        ),
        _buildSettingsTile(
          'bookings_tab_title'.tr,
          Icons.event,
          controller.navigateToBookings,
        ),
        // Sprint 5 UI step 3 — availability calendar
        _buildSettingsTile(
          'profile_my_availability'.tr,
          Icons.calendar_month,
          () => Get.to(() => const AvailabilityCalendarScreen()),
        ),
        // Sprint 5 UI step 4 — identity verification
        _buildSettingsTile(
          'profile_verify_identity'.tr,
          Icons.verified_user_outlined,
          () => Get.to(() => const IdentityVerificationScreen()),
        ),
        // Sprint 6 step 1 — theme mode.
        _buildSettingsTile(
          'theme_setting_title'.tr,
          Icons.brightness_6,
          () => Get.dialog(
            AlertDialog(
              title: Text('theme_setting_title'.tr),
              content: Obx(() {
                final tc = Get.find<ThemeController>();
                return Column(
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
                );
              }),
              actions: [
                TextButton(onPressed: () => Get.back(), child: Text('common_close'.tr)),
              ],
            ),
          ),
        ),
        // _buildSettingsTile(
        //   'Reviews',
        //   Icons.arrow_forward_ios,
        //   controller.navigateToReviews,
        // ),
        _buildSettingsTile(
          'profile_donate_us'.tr,
          Icons.arrow_forward_ios,
          controller.navigateToDonate,
        ),
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

  Widget _buildStripeConnectTile(SitterProfileController controller) {
    return GestureDetector(
      onTap: controller.navigateToStripeConnect,
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
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 20.sp,
                  color: AppColors.greyText,
                ),
                SizedBox(width: 12.w),
                InterText(
                  text: 'stripe_connect_title'.tr,
                  fontSize: 14.sp,
                  color: AppColors.greyText,
                  fontWeight: FontWeight.w500,
                ),
              ],
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 20.sp,
              color: AppColors.greyText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRoleCard(BuildContext context) {
    final authController = Get.find<AuthController>();
    final currentRole = authController.userRole.value;
    final switchDescription = currentRole == 'owner'
        ? 'profile_switch_to_sitter_description'.tr
        : 'profile_switch_to_owner_description'.tr;

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
                    text: currentRole == 'owner'
                        ? 'profile_switch_to_sitter'.tr
                        : 'profile_switch_to_owner'.tr,
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
    final isSwitchingToSitter = currentRole == 'owner';

    CustomConfirmationDialog.show(
      context: context,
      message: isSwitchingToSitter
          ? 'profile_switch_to_sitter_confirm'.tr
          : 'profile_switch_to_owner_confirm'.tr,
      yesText: isSwitchingToSitter
          ? 'profile_switch_to_sitter'.tr
          : 'profile_switch_to_owner'.tr,
      cancelText: 'common_cancel'.tr,
      onYes: () async {
        // Show loading dialog while switching role
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        await authController.switchRole();

        if (Get.isDialogOpen == true) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}
