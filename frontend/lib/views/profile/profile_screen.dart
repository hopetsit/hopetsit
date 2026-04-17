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
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/map/pets_map_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ProfileController controller = Get.put(ProfileController());

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── OWNER HERO HEADER ──────────────────────
            _buildOwnerHero(controller),

            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 100.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),

                  // Quick Actions Row
                  _buildQuickActions(controller),
                  SizedBox(height: 20.h),

                  // Switch Role Cards — shows the 2 other roles the user can switch to.
                  _buildSwitchRoleCards(context),
                  SizedBox(height: 20.h),

                  // Settings Section
                  _buildSettingsSection(context, controller),

                  SizedBox(height: 30.h),

                  // Logout Button
                  Center(
                    child: CustomButton(
                      width: 305.w,
                      radius: 16.r,
                      isGradient: false,
                      title: 'button_logout'.tr,
                      bgColor: Colors.grey.shade200,
                      textColor: AppColors.primaryColor,
                      onTap: () => controller.showLogoutDialog(context),
                    ),
                  ),

                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Owner-specific hero: warm gradient header with centered avatar.
  Widget _buildOwnerHero(ProfileController controller) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Gradient background
        Container(
          width: double.infinity,
          height: 200.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryColor,
                AppColors.primaryColor.withOpacity(0.8),
                const Color(0xFFFF6B4A),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pets, color: Colors.white.withOpacity(0.9), size: 20.sp),
                          SizedBox(width: 8.w),
                          PoppinsText(
                            text: 'role_pet_owner'.tr,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Obx(() => PoppinsText(
                        text: controller.userName.value,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                      SizedBox(height: 4.h),
                      Obx(() => InterText(
                        text: controller.email.value,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.85),
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Avatar overlay
        Positioned(
          right: 20.w,
          top: 80.h,
          child: _buildOwnerAvatar(controller),
        ),
      ],
    );
  }

  Widget _buildOwnerAvatar(ProfileController controller) {
    return Stack(
      children: [
        Obx(() {
          final imageUrl = controller.profileImageUrl.value;
          final isUploading = controller.isUploadingImage.value;
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(55.r),
              child: Container(
                width: 100.w,
                height: 100.w,
                color: AppColors.lightGrey,
                child: isUploading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                        ),
                      )
                    : imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 100.w,
                        height: 100.w,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.lightGrey,
                          child: Icon(Icons.person, size: 50.sp, color: AppColors.primaryColor),
                        ),
                        errorWidget: (context, url, error) =>
                            Icon(Icons.person, size: 50.sp, color: AppColors.primaryColor),
                      )
                    : Icon(Icons.person, size: 50.sp, color: AppColors.primaryColor),
              ),
            ),
          );
        }),
        Obx(() {
          if (controller.isUploadingImage.value) return const SizedBox.shrink();
          return Positioned(
            bottom: 2,
            right: 2,
            child: GestureDetector(
              onTap: controller.pickAndUploadProfilePicture,
              child: Container(
                width: 30.w,
                height: 30.w,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(Icons.camera_alt_rounded, size: 14.sp, color: Colors.white),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Quick action cards row for owner.
  Widget _buildQuickActions(ProfileController controller) {
    return Row(
      children: [
        _quickAction(Icons.pets, 'profile_edit_pets_profile'.tr,
            controller.navigateToEditPetProfile),
        SizedBox(width: 10.w),
        _quickAction(Icons.history, 'profile_bookings_history'.tr,
            controller.navigateToBookingsHistory),
        SizedBox(width: 10.w),
        _quickAction(Icons.rocket_launch, 'boost_shop_title'.tr,
            () => Get.to(() => const CoinShopScreen())),
      ],
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Builder(
          builder: (context) => Container(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: AppColors.cardShadow(context),
            ),
          child: Column(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, size: 18.sp, color: AppColors.primaryColor),
              ),
              SizedBox(height: 6.h),
              InterText(
                text: label,
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.grey700Color,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  // _buildProfileInfo removed — replaced by _buildOwnerHero + _buildOwnerAvatar.

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
          Icons.add_task_rounded,
          controller.navigateToAddTasks,
        ),
        _buildSettingsTile(
          'profile_view_tasks'.tr,
          Icons.task_alt_rounded,
          controller.navigateToViewTask,
        ),
        _buildSettingsTile(
          'profile_edit_profile'.tr,
          Icons.person_outline_rounded,
          controller.navigateToEditProfile,
        ),
        _buildSettingsTile(
          'profile_choose_service'.tr,
          Icons.work_outline_rounded,
          controller.navigateToChooseService,
        ),
        _buildSettingsTile(
          'profile_change_password'.tr,
          Icons.lock_outline_rounded,
          controller.navigateToChangePassword,
        ),
        _buildSettingsTile(
          'profile_change_language'.tr,
          Icons.language_rounded,
          controller.showLanguageDialog,
        ),
        _buildSettingsTile(
          'profile_blocked_users'.tr,
          Icons.block_rounded,
          controller.navigateToBlockedUsers,
        ),
        // Sprint 7 step 1 — loyalty card
        const LoyaltyCard(),
        // Carte — menu qui réunit Ma map classique + PawMap.
        _buildSettingsTile(
          'Carte',
          Icons.map_rounded,
          () => _showMapMenu(),
        ),
        // Sprint 7 step 3 — referrals tile.
        _buildSettingsTile(
          'referrals_title'.tr,
          Icons.group_add,
          () => Get.to(() => const MyReferralsScreen()),
        ),
        // Sprint 5 step 4 — access T&C.
        _buildSettingsTile(
          'terms_read_button'.tr,
          Icons.description_outlined,
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
          Icons.delete_outline_rounded,
          () => controller.showDeleteAccountDialog(context),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Builder(
        builder: (context) => Container(
          margin: EdgeInsets.only(bottom: 6.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: AppColors.cardShadow(context),
          ),
        child: Row(
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(9.r),
              ),
              child: Icon(icon, size: 16.sp, color: AppColors.primaryColor),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: InterText(
                text: title,
                fontSize: 14.sp,
                color: AppColors.grey700Color,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14.sp, color: AppColors.textSecondary(context)),
          ],
        ),
        ),
      ),
    );
  }

  /// Carte menu — bottom sheet that exposes both map experiences:
  /// - Ma map classique (PetsMapScreen) : legacy view focused on pets & sitters.
  /// - PawMap : Phase 2-4 unified map (POIs, reports 48h, amis live).
  /// Shown from the "Carte" settings tile on owner & sitter profiles.
  void _showMapMenu() {
    Get.bottomSheet(
      Builder(
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.r),
              topRight: Radius.circular(24.r),
            ),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle.
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 16.h),
                  decoration: BoxDecoration(
                    color: AppColors.divider(context),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              PoppinsText(
                text: 'Choisis ta carte',
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 4.h),
              InterText(
                text: 'Deux vues disponibles — l\'une pour tes animaux & sitters, l\'autre pour explorer les alentours.',
                fontSize: 12.sp,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(height: 16.h),
              _mapMenuOption(
                context,
                icon: Icons.pets_rounded,
                title: 'Ma map classique',
                subtitle: 'Mes animaux & sitters à proximité',
                onTap: () {
                  Get.back();
                  Get.to(() => const PetsMapScreen());
                },
              ),
              SizedBox(height: 10.h),
              _mapMenuOption(
                context,
                icon: Icons.explore_rounded,
                title: 'PawMap',
                subtitle: 'POIs, reports 48h, amis en live',
                onTap: () {
                  Get.back();
                  Get.to(() => const PawMapScreen());
                },
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: false,
    );
  }

  Widget _mapMenuOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: AppColors.primaryColor.withOpacity(0.18),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, size: 18.sp, color: AppColors.primaryColor),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PoppinsText(
                    text: title,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                  SizedBox(height: 2.h),
                  InterText(
                    text: subtitle,
                    fontSize: 11.sp,
                    color: AppColors.textSecondary(context),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 13.sp,
              color: AppColors.textSecondary(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a column of switch-role cards — one per role the user is NOT in.
  /// Each card opens a confirm dialog, then calls switchRole with the target.
  Widget _buildSwitchRoleCards(BuildContext context) {
    final authController = Get.find<AuthController>();
    final currentRole = authController.userRole.value;

    // Compute the 2 other roles the user can switch to.
    const allRoles = ['owner', 'sitter', 'walker'];
    final otherRoles = allRoles.where((r) => r != currentRole).toList();

    return Column(
      children: [
        for (int i = 0; i < otherRoles.length; i++) ...[
          _buildSwitchRoleCard(context, targetRole: otherRoles[i]),
          if (i < otherRoles.length - 1) SizedBox(height: 12.h),
        ],
      ],
    );
  }

  /// Single switch-role card targeting a specific role.
  Widget _buildSwitchRoleCard(
    BuildContext context, {
    required String targetRole,
  }) {
    // Map role -> translation key + accent color.
    String roleLabelKey;
    Color accentColor;
    switch (targetRole) {
      case 'owner':
        roleLabelKey = 'role_pet_owner';
        accentColor = AppColors.primaryColor;
        break;
      case 'walker':
        roleLabelKey = 'role_pet_walker';
        accentColor = AppColors.greenColor;
        break;
      case 'sitter':
      default:
        roleLabelKey = 'role_pet_sitter';
        accentColor = AppColors.sitterAccent;
        break;
    }

    final newRoleText = roleLabelKey.tr;
    final switchDescription = 'profile_switch_role_card_description'.trParams({
      'role': newRoleText,
    });

    return GestureDetector(
      onTap: () => _showSwitchRoleDialog(context, targetRole: targetRole),
      child: Builder(
        builder: (context) => Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: accentColor, width: 2),
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
                      color: accentColor,
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
                color: accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSwitchRoleDialog(
    BuildContext context, {
    required String targetRole,
  }) {
    final authController = Get.find<AuthController>();

    // Map role -> translation key for the confirm dialog text.
    String roleLabelKey;
    switch (targetRole) {
      case 'owner':
        roleLabelKey = 'role_pet_owner';
        break;
      case 'walker':
        roleLabelKey = 'role_pet_walker';
        break;
      case 'sitter':
      default:
        roleLabelKey = 'role_pet_sitter';
        break;
    }
    final newRoleText = roleLabelKey.tr;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Obx(() {
          final isLoading = authController.isSwitchingRole.value;
          return AlertDialog(
            backgroundColor: AppColors.card(dialogContext),
            title: Text(
              'dialog_switch_role_title'.tr,
              style: TextStyle(color: AppColors.textPrimary(dialogContext)),
            ),
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
                  style: TextStyle(color: AppColors.textPrimary(dialogContext)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text('common_cancel'.tr, style: TextStyle(color: AppColors.textSecondary(dialogContext))),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        await authController.switchRole(targetRole: targetRole);
                        if (Get.isDialogOpen == true) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                child: Text(
                  'dialog_switch_role_button'.trParams({'role': newRoleText}),
                  style: TextStyle(
                    color: isLoading ? AppColors.textSecondary(dialogContext) : Colors.blue,
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
