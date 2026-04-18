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
import 'package:hopetsit/views/pet_sitter/payment/earnings_history_screen.dart';
import 'package:hopetsit/views/pet_sitter/payment/payment_management_screen.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/availability_calendar_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/identity_verification_screen.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/widgets/top_sitter_card.dart';
import 'package:hopetsit/views/profile/my_referrals_screen.dart';
import 'package:hopetsit/views/profile/terms_and_conditions_screen.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';

class SitterProfileScreen extends StatelessWidget {
  const SitterProfileScreen({super.key});

  String _localizeService(String s) {
    switch (s.toLowerCase().trim()) {
      case 'dog walking':
      case 'dog_walking':
        return 'sitter_service_dog_walking'.tr;
      case 'pet sitting':
      case 'pet_sitting':
        return 'choose_service_card_pet_sitting_title'.tr;
      case 'house sitting':
      case 'house_sitting':
        return 'choose_service_card_house_sitting_title'.tr;
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safely get or create the controller
    final SitterProfileController controller;
    if (Get.isRegistered<SitterProfileController>()) {
      controller = Get.find<SitterProfileController>();
    } else {
      controller = Get.put(SitterProfileController());
    }

    // Sitter accent color — distinct from owner
    const sitterAccent = Color(0xFF1A73E8);
    const sitterAccentLight = Color(0xFFE8F0FE);

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── SITTER HERO HEADER ──────────────────────
            _buildSitterHero(controller, sitterAccent),

            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 100.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),

                  // Sitter Stats Row
                  _buildSitterStatsRow(controller, sitterAccent),
                  SizedBox(height: 16.h),

                  // Quick Pro Actions
                  _buildSitterQuickActions(controller, sitterAccent, sitterAccentLight),
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
                      textColor: const Color(0xFF1A73E8),
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

  /// Sitter-specific hero: blue/professional gradient.
  Widget _buildSitterHero(SitterProfileController controller, Color accent) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          height: 200.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0D47A1),
                accent,
                const Color(0xFF42A5F5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  _buildSitterAvatar(controller, accent),
                  SizedBox(width: 16.w),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_outlined, color: Colors.white, size: 12.sp),
                                  SizedBox(width: 4.w),
                                  InterText(
                                    text: 'role_pet_sitter'.tr,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
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
                        SizedBox(height: 6.h),
                        Obx(() {
                          final services = controller.profile.value?.service ?? [];
                          if (services.isEmpty) return const SizedBox.shrink();
                          return Wrap(
                            spacing: 4.w,
                            children: services.take(3).map((s) => Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: InterText(
                                text: _localizeService(s),
                                fontSize: 10.sp,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            )).toList(),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSitterAvatar(SitterProfileController controller, Color accent) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Obx(
            () => CircleAvatar(
              radius: 42.r,
              backgroundColor: AppColors.grey300Color,
              backgroundImage: controller.profileImageUrl.value.isNotEmpty
                  ? CachedNetworkImageProvider(controller.profileImageUrl.value)
                  : null,
              child: controller.profileImageUrl.value.isEmpty
                  ? Icon(Icons.person, size: 40.sp, color: AppColors.greyColor)
                  : null,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: controller.editProfile,
            child: Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.camera_alt_rounded, size: 13.sp, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  /// Stats row for sitter — rating, reviews, services.
  Widget _buildSitterStatsRow(SitterProfileController controller, Color accent) {
    return Obx(() {
      final profile = controller.profile.value;
      return Builder(
        builder: (context) => Container(
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: AppColors.cardShadow(context),
          ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('0.0', 'Rating', Icons.star_rounded, Colors.amber),
            Container(width: 1, height: 32.h, color: AppColors.divider(context)),
            _statItem('0', 'Avis', Icons.reviews_outlined, accent),
            Container(width: 1, height: 32.h, color: AppColors.divider(context)),
            _statItem('${profile?.service.length ?? 0}', 'Services', Icons.work_outline_rounded, AppColors.greenColor),
          ],
        ),
        ),
      );
    });
  }

  Widget _statItem(String value, String label, IconData icon, Color color) {
    return Builder(
      builder: (context) => Column(
        children: [
          Icon(icon, size: 18.sp, color: color),
          SizedBox(height: 4.h),
          PoppinsText(text: value, fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
          InterText(text: label, fontSize: 10.sp, color: AppColors.textSecondary(context), fontWeight: FontWeight.w500),
        ],
      ),
    );
  }

  /// Quick actions: Earnings, Availability, Boost, IBAN.
  Widget _buildSitterQuickActions(SitterProfileController controller, Color accent, Color accentLight) {
    return Row(
      children: [
        _sitterQuickAction(Icons.bar_chart_rounded, 'earnings_title'.tr, accent, accentLight,
            () => Get.to(() => const EarningsHistoryScreen())),
        SizedBox(width: 8.w),
        _sitterQuickAction(Icons.calendar_month_rounded, 'profile_my_availability'.tr, accent, accentLight,
            () => Get.to(() => const AvailabilityCalendarScreen())),
        SizedBox(width: 8.w),
        _sitterQuickAction(Icons.rocket_launch_rounded, 'boost_shop_title'.tr, accent, accentLight,
            () => Get.to(() => const CoinShopScreen())),
        SizedBox(width: 8.w),
        _sitterQuickAction(Icons.account_balance_rounded, 'iban_title'.tr, accent, accentLight,
            () => Get.to(() => const IbanSetupScreen())),
      ],
    );
  }

  Widget _sitterQuickAction(IconData icon, String label, Color accent, Color accentLight, VoidCallback onTap) {
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
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: accentLight,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, size: 17.sp, color: accent),
              ),
              SizedBox(height: 6.h),
              InterText(
                text: label,
                fontSize: 9.sp,
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

  // ── Section palette — mirrors owner/walker redesign for cross-role
  // visual consistency.
  static const Color _sitterAccent = Color(0xFF1A73E8);
  static const Color _palePurple = Color(0xFF6A5AE0);
  static const Color _paleOrange = Color(0xFFE9A73B);

  Widget _buildSettingsSection(
    BuildContext context,
    SitterProfileController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Switch Role Cards — shows the 2 other roles (3-way switch).
        _buildSwitchRoleCards(context),

        // ── COMPTE ─────────────────────────────────────────
        _sectionHeader('Compte'),
        _buildSettingsTile(
          'profile_edit_profile'.tr,
          'Modifier ton profil et ta photo',
          Icons.person_outline_rounded,
          _sitterAccent,
          controller.navigateToEditProfile,
        ),
        _buildSettingsTile(
          'profile_choose_service'.tr,
          'Change les services que tu proposes',
          Icons.work_outline_rounded,
          _sitterAccent,
          controller.navigateToChooseService,
        ),
        _buildSettingsTile(
          'Carte',
          'PawMap — POIs, reports, amis, demandes',
          Icons.map_rounded,
          _palePurple,
          () => Get.to(() => const PawMapScreen()),
        ),
        _buildSettingsTile(
          'profile_verify_identity'.tr,
          'Sois vérifié pour rassurer les propriétaires',
          Icons.verified_user_outlined,
          AppColors.greenColor,
          () => Get.to(() => const IdentityVerificationScreen()),
        ),

        // ── MES SERVICES ──────────────────────────────────
        _sectionHeader('Mes services'),
        const TopSitterCard(),
        _buildSettingsTile(
          'bookings_tab_title'.tr,
          'Tes réservations en cours',
          Icons.event_rounded,
          _sitterAccent,
          controller.navigateToBookings,
        ),

        // ── PAIEMENTS & SERVICES ──────────────────────────
        _sectionHeader('Paiements & services'),
        _buildSettingsTile(
          'payment_management_title'.tr,
          'Moyens de paiement & payouts',
          Icons.account_balance_wallet_rounded,
          AppColors.primaryColor,
          () => Get.to(() => const PaymentManagementScreen()),
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
          _sitterAccent,
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
          _sitterAccent,
          controller.navigateToChangePassword,
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

  /// Small caps section header — shared with owner / walker profiles.
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

  /// Theme picker dialog (extracted so we can reuse it from the settings
  /// tile instead of inlining the Get.dialog literal).
  void _showThemeDialog() {
    Get.dialog(
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
          TextButton(
            onPressed: () => Get.back(),
            child: Text('common_close'.tr),
          ),
        ],
      ),
    );
  }

  /// Colored settings tile with title + subtitle + tinted icon chip.
  /// Same pattern as owner / walker for cross-role consistency.
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
                  color: iconColor.withOpacity(0.12),
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

  /// Danger variant — red accent + red outline for irreversible actions.
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
              color: AppColors.errorColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withOpacity(0.12),
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

  /// Renders the switch cards for the 2 other roles the user can move to.
  Widget _buildSwitchRoleCards(BuildContext context) {
    final authController = Get.find<AuthController>();
    final currentRole = authController.userRole.value;
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

  Widget _buildSwitchRoleCard(
    BuildContext context, {
    required String targetRole,
  }) {
    // Each role has its own translation key + accent color.
    String titleKey;
    String descKey;
    Color accentColor;
    switch (targetRole) {
      case 'owner':
        titleKey = 'profile_switch_to_owner';
        descKey = 'profile_switch_to_owner_description';
        accentColor = AppColors.primaryColor;
        break;
      case 'walker':
        // Reuse role_pet_walker for title; generic profile_switch description.
        titleKey = 'role_pet_walker';
        descKey = 'profile_switch_role_card_description';
        accentColor = AppColors.greenColor;
        break;
      case 'sitter':
      default:
        titleKey = 'profile_switch_to_sitter';
        descKey = 'profile_switch_to_sitter_description';
        accentColor = AppColors.sitterAccent;
        break;
    }

    // Walker target uses the parametrised description key; owner/sitter use
    // their own dedicated strings (existing keys kept intact).
    final description = descKey == 'profile_switch_role_card_description'
        ? 'profile_switch_role_card_description'.trParams({
            'role': titleKey.tr,
          })
        : descKey.tr;

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
                      text: titleKey.tr,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                    SizedBox(height: 8.h),
                    InterText(
                      text: description,
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

    String titleKey;
    switch (targetRole) {
      case 'owner':
        titleKey = 'profile_switch_to_owner';
        break;
      case 'walker':
        titleKey = 'role_pet_walker';
        break;
      case 'sitter':
      default:
        titleKey = 'profile_switch_to_sitter';
        break;
    }

    // Build confirm/yes text according to target role.
    final confirmMessage = targetRole == 'sitter'
        ? 'profile_switch_to_sitter_confirm'.tr
        : targetRole == 'owner'
            ? 'profile_switch_to_owner_confirm'.tr
            : 'dialog_switch_role_confirm'.trParams({'role': titleKey.tr});
    final yesText = titleKey.tr;

    CustomConfirmationDialog.show(
      context: context,
      message: confirmMessage,
      yesText: yesText,
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

        await authController.switchRole(targetRole: targetRole);

        if (Get.isDialogOpen == true) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}
