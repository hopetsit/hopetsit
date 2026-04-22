import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/views/profile/terms_and_conditions_screen.dart';
import 'package:hopetsit/views/profile/privacy_policy_screen.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/widgets/loyalty_card.dart';
import 'package:hopetsit/views/profile/my_referrals_screen.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/widgets/boost_profile_card.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
// v18.2 — Mes paiements entry point.
import 'package:hopetsit/views/pet_owner/payments/owner_payments_screen.dart';

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

                  // v18.6 — Bouton "Booster mon profil" (orange owner).
                  const BoostProfileCard(role: 'owner'),
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
                AppColors.primaryColor.withValues(alpha: 0.8),
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
                          Icon(Icons.pets, color: Colors.white.withValues(alpha: 0.9), size: 20.sp),
                          SizedBox(width: 8.w),
                          PoppinsText(
                            text: 'role_pet_owner'.tr,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
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
                        color: Colors.white.withValues(alpha: 0.85),
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
                  color: Colors.black.withValues(alpha: 0.15),
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
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
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

  // ── Section palette — matches the walker profile redesign so the 3 roles
  // feel consistent visually. Owner accent (primary red) is used where the
  // section doesn't already have a semantic color.
  static const Color _paleBlue = Color(0xFF1A73E8);
  static const Color _palePurple = Color(0xFF6A5AE0);
  static const Color _paleOrange = Color(0xFFE9A73B);

  Widget _buildSettingsSection(
    BuildContext context,
    ProfileController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── COMPTE ─────────────────────────────────────────
        _sectionHeader('Compte'),
        _buildSettingsTile(
          'profile_edit_profile'.tr,
          'Modifier ton profil et ta photo',
          Icons.person_outline_rounded,
          AppColors.primaryColor,
          controller.navigateToEditProfile,
        ),
        _buildSettingsTile(
          'profile_choose_service'.tr,
          'Change le type de service recherché',
          Icons.work_outline_rounded,
          AppColors.primaryColor,
          controller.navigateToChooseService,
        ),
        _buildSettingsTile(
          'Carte',
          'PawMap — vétos, points d\'eau, amis',
          Icons.map_rounded,
          _palePurple,
          () => Get.to(() => const PawMapScreen()),
        ),

        // ── TÂCHES ─────────────────────────────────────────
        _sectionHeader('Tâches'),
        _buildSettingsTile(
          'profile_add_tasks'.tr,
          'Programme une nouvelle tâche',
          Icons.add_task_rounded,
          AppColors.greenColor,
          controller.navigateToAddTasks,
        ),
        _buildSettingsTile(
          'profile_view_tasks'.tr,
          'Consulte tes tâches existantes',
          Icons.task_alt_rounded,
          AppColors.greenColor,
          controller.navigateToViewTask,
        ),

        // ── PAIEMENTS & SERVICES ──────────────────────────
        _sectionHeader('Paiements & services'),
        const LoyaltyCard(),
        // Session v18.2 — entry point to the "Mes paiements" screen
        // (saved cards + history). Route via lazy import so that removing
        // this line later doesn't leave a dead reference.
        _buildSettingsTile(
          'owner_payments_title'.tr == 'owner_payments_title'
              ? 'Mes paiements'
              : 'owner_payments_title'.tr,
          'Cartes enregistrées et historique',
          Icons.credit_card_rounded,
          AppColors.primaryColor,
          () => Get.to(() => const OwnerPaymentsScreen()),
        ),
        _buildSettingsTile(
          'referrals_title'.tr,
          'Invite tes amis, gagne des crédits',
          Icons.group_add_rounded,
          _paleOrange,
          () => Get.to(() => const MyReferralsScreen()),
        ),

        // ── PRÉFÉRENCES ───────────────────────────────────
        _sectionHeader('Préférences'),
        _buildSettingsTile(
          'profile_change_language'.tr,
          'Change la langue de l\'app',
          Icons.language_rounded,
          _paleBlue,
          controller.showLanguageDialog,
        ),
        _buildSettingsTile(
          'theme_setting_title'.tr,
          'Clair / sombre / système',
          Icons.brightness_6_rounded,
          _palePurple,
          () => _showThemeDialog(),
        ),

        // ── SÉCURITÉ ──────────────────────────────────────
        _sectionHeader('Sécurité'),
        _buildSettingsTile(
          'profile_change_password'.tr,
          'Modifier ton mot de passe',
          Icons.lock_outline_rounded,
          AppColors.primaryColor,
          controller.navigateToChangePassword,
        ),
        _buildSettingsTile(
          'profile_blocked_users'.tr,
          'Gérer les personnes bloquées',
          Icons.block_rounded,
          AppColors.errorColor,
          controller.navigateToBlockedUsers,
        ),

        // ── LÉGAL ─────────────────────────────────────────
        _sectionHeader('Légal'),
        _buildSettingsTile(
          'terms_read_button'.tr,
          'CGU de la plateforme',
          Icons.description_outlined,
          AppColors.textSecondary(context),
          () => Get.to(() => const TermsAndConditionsScreen()),
        ),
        _buildSettingsTile(
          'Confidentialité',
          'Politique de confidentialité et RGPD',
          Icons.privacy_tip_outlined,
          AppColors.textSecondary(context),
          () => Get.to(() => const PrivacyPolicyScreen()),
        ),

        // ── ZONE DANGER ───────────────────────────────────
        _sectionHeader('Zone danger'),
        _buildSettingsTileDanger(
          'profile_delete_account'.tr,
          'Action irréversible',
          Icons.delete_outline_rounded,
          () => controller.showDeleteAccountDialog(context),
        ),
      ],
    );
  }

  /// Small caps section header (matches walker profile).
  Widget _sectionHeader(String label) {
    return Padding(
      padding: EdgeInsets.only(top: 18.h, bottom: 8.h, left: 4.w),
      child: PoppinsText(
        text: label.toUpperCase(),
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.greyText,
      ),
    );
  }

  /// Colored settings tile with title + subtitle + tinted icon chip. The
  /// `iconColor` parameter drives both the icon color and its background
  /// tint, so per-section palettes can vary (green for Compte, orange for
  /// Parrainages, etc.) while keeping the same visual rhythm.
  Widget _buildSettingsTile(
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Builder(
        builder: (context) => Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, size: 18.sp, color: iconColor),
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
                size: 14.sp,
                color: AppColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Danger variant — red accent + red outline to signal irreversible
  /// actions (delete account).
  Widget _buildSettingsTileDanger(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Builder(
        builder: (context) => Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: AppColors.cardShadow(context),
            border: Border.all(
              color: AppColors.errorColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, size: 18.sp, color: AppColors.errorColor),
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
                      color: AppColors.errorColor,
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
                size: 14.sp,
                color: AppColors.errorColor,
              ),
            ],
          ),
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
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Colored icon chip on the left.
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.pets_rounded, size: 22.sp, color: accentColor),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InterText(
                      text: 'profile_switch_role_card_title'.trParams({
                        'role': newRoleText,
                      }),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                    SizedBox(height: 3.h),
                    InterText(
                      text: switchDescription,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.greyText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16.sp,
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
                        // Guard: dialogContext may no longer be mounted after
                        // the async switchRole returns.
                        if (!dialogContext.mounted) return;
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
          () => RadioGroup<ThemeMode>(
            groupValue: tc.themeMode.value,
            onChanged: (v) {
              if (v != null) tc.setMode(v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: Text('theme_light'.tr),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('theme_dark'.tr),
                  value: ThemeMode.dark,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('theme_system'.tr),
                  value: ThemeMode.system,
                ),
              ],
            ),
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
