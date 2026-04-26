import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/widgets/boost_profile_card.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/pet_sitter/payment/earnings_history_screen.dart';
import 'package:hopetsit/views/pet_sitter/payment/payment_management_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/availability_calendar_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/iban_setup_screen.dart';
import 'package:hopetsit/views/wallet/wallet_screen.dart';
import 'package:hopetsit/views/profile/blocked_users_screen.dart';
import 'package:hopetsit/views/profile/change_password_screen.dart';
import 'package:hopetsit/views/pet_walker/profile/edit_walker_profile_screen.dart';
import 'package:hopetsit/views/profile/my_rates_screen.dart';
import 'package:hopetsit/views/profile/my_referrals_screen.dart';
import 'package:hopetsit/views/profile/privacy_policy_screen.dart';
import 'package:hopetsit/views/profile/terms_and_conditions_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/widgets/top_walker_card.dart';
import 'package:hopetsit/views/profile/bug_report_screen.dart';

/// Walker profile screen — full redesign (session avril 2026).
///
/// Previous iteration embedded the PawMap fullscreen + a gear bottom-sheet.
/// Feedback from Daniel: the profile tab should show a *real profile* with
/// all the action buttons visible inline. PawMap stays on the bottom-nav
/// center button where it belongs.
///
/// Layout mirrors [SitterProfileScreen]:
///   1. Green-gradient hero with avatar, name, email, walker role badge
///   2. Quick actions row (Revenues / Calendar / Boost / IBAN)
///   3. Switch-role cards (toward Owner and Sitter)
///   4. Settings list grouped in sections (Account / Payments / Preferences
///      / Security / Legal / Danger zone)
///   5. Logout button
///
/// Walker-specific data (rate manager, coverage zones, insurance) will land
/// in a later session; for now the header reuses ProfileController's generic
/// name/email/avatar fields, which are populated for every logged-in user.
class WalkerProfileScreen extends StatelessWidget {
  const WalkerProfileScreen({super.key});

  // Walker accent = green. Light variant used for icon chip backgrounds.
  static const Color _accent = AppColors.greenColor;
  static final Color _accentLight = AppColors.greenColor.withValues(alpha: 0.12);

  ProfileController _profileController() {
    return Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());
  }

  @override
  Widget build(BuildContext context) {
    final controller = _profileController();

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Walker hero ───────────────────────────────────
            _buildWalkerHero(context, controller),

            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 100.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),

                  // Quick Actions: revenues, calendar, boost, iban.
                  _buildQuickActions(context),
                  SizedBox(height: 20.h),

                  // v18.6 — Booster mon profil (vert walker).
                  BoostProfileCard(role: 'walker'),
                  SizedBox(height: 20.h),

                  // Switch role cards — one per role the walker can move to.
                  _buildSwitchRoleCards(context),
                  SizedBox(height: 20.h),

                  // Settings section.
                  _buildSettingsSection(context, controller),

                  SizedBox(height: 30.h),

                  // Logout button.
                  Center(
                    child: CustomButton(
                      width: 305.w,
                      radius: 16.r,
                      isGradient: false,
                      title: 'button_logout'.tr,
                      bgColor: Colors.grey.shade200,
                      textColor: _accent,
                      onTap: () async {
                        if (Get.isRegistered<AuthController>()) {
                          await Get.find<AuthController>().logout();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // HERO
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildWalkerHero(
    BuildContext context,
    ProfileController controller,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          height: 200.h,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1B5E20), // Dark green
                _accent,
                Color(0xFF66BB6A), // Light green
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
                  _buildWalkerAvatar(controller),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Role badge.
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.directions_walk_rounded,
                                size: 12.sp,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4.w),
                              InterText(
                                text: 'role_pet_walker'.tr,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10.h),
                        Obx(() => PoppinsText(
                              text: controller.userName.value.isEmpty
                                  ? 'walker_profile_title'.tr
                                  : controller.userName.value,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )),
                        SizedBox(height: 4.h),
                        Obx(() => InterText(
                              text: controller.email.value,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.85),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )),
                        SizedBox(height: 6.h),
                        // Session v3.3 — service pill "Promenade" so the
                        // walker hero mirrors the sitter hero layout.
                        Wrap(
                          spacing: 4.w,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: InterText(
                                text: 'service_dog_walking'.tr,
                                fontSize: 10.sp,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildWalkerAvatar(ProfileController controller) {
    return Stack(
      children: [
        Obx(() {
          final imageUrl = controller.profileImageUrl.value;
          final isUploading = controller.isUploadingImage.value;
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(42.r),
              child: SizedBox(
                width: 84.w,
                height: 84.w,
                child: isUploading
                    ? Container(
                        color: AppColors.lightGrey,
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(_accent),
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : (imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppColors.lightGrey),
                            errorWidget: (_, __, ___) => Container(
                              color: _accentLight,
                              child: Icon(
                                Icons.directions_walk_rounded,
                                size: 36.sp,
                                color: _accent,
                              ),
                            ),
                          )
                        : Container(
                            color: _accentLight,
                            child: Icon(
                              Icons.directions_walk_rounded,
                              size: 36.sp,
                              color: _accent,
                            ),
                          )),
              ),
            ),
          );
        }),
        // Session v3.3 — camera edit button overlay (parity with sitter hero).
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: controller.pickAndUploadProfilePicture,
            child: Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                color: _accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: 13.sp,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // QUICK ACTIONS
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        // v19.1.3 — "Mes revenus" replaced by "Mon portefeuille" (wallet).
        _quickAction(
          context,
          icon: Icons.account_balance_wallet_rounded,
          label: 'wallet_menu_title'.tr,
          onTap: () => Get.to(() => const WalletScreen()),
        ),
        SizedBox(width: 8.w),
        _quickAction(
          context,
          icon: Icons.calendar_month_rounded,
          label: 'profile_quick_calendar'.tr,
          onTap: () => Get.to(() => const AvailabilityCalendarScreen()),
        ),
        SizedBox(width: 8.w),
        _quickAction(
          context,
          icon: Icons.rocket_launch_rounded,
          label: 'profile_quick_boost_shop'.tr,
          onTap: () => Get.to(() => const CoinShopScreen()),
        ),
        SizedBox(width: 8.w),
        _quickAction(
          context,
          icon: Icons.account_balance_rounded,
          label: 'profile_quick_iban'.tr,
          onTap: () => Get.to(() => const IbanSetupScreen()),
        ),
      ],
    );
  }

  Widget _quickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
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
                  color: _accentLight,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, size: 17.sp, color: _accent),
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
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SWITCH ROLE
  // ═════════════════════════════════════════════════════════════════════════

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
        accentColor = const Color(0xFF1A73E8);
        break;
    }
    final roleLabel = roleLabelKey.tr;

    return GestureDetector(
      onTap: () => _confirmSwitchRole(context, targetRole, roleLabel),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: Row(
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
                    text: 'switch_role_to'.trParams({'role': roleLabel}),
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                  SizedBox(height: 3.h),
                  InterText(
                    text: 'switch_role_subtitle'.trParams({'role': targetRole}),
                    fontSize: 12.sp,
                    color: AppColors.greyText,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16.sp, color: accentColor),
          ],
        ),
      ),
    );
  }

  void _confirmSwitchRole(
    BuildContext context,
    String targetRole,
    String roleLabel,
  ) {
    final auth = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    if (auth == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Obx(() {
          final isLoading = auth.isSwitchingRole.value;
          return AlertDialog(
            backgroundColor: AppColors.card(dialogContext),
            title: Text('switch_role_dialog_title'.tr,
                style: TextStyle(color: AppColors.textPrimary(dialogContext))),
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
                      ? 'switch_role_loading'.trParams({'role': roleLabel})
                      : 'switch_role_confirm'.trParams({'role': roleLabel}),
                  style:
                      TextStyle(color: AppColors.textPrimary(dialogContext)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'common_cancel'.tr,
                  style: TextStyle(
                      color: AppColors.textSecondary(dialogContext)),
                ),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        await auth.switchRole(targetRole: targetRole);
                        if (!dialogContext.mounted) return;
                        if (Get.isDialogOpen == true) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                child: Text(
                  'switch_role_to'.trParams({'role': roleLabel}),
                  style: TextStyle(
                    color: isLoading
                        ? AppColors.textSecondary(dialogContext)
                        : Colors.blue,
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SETTINGS
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildSettingsSection(
    BuildContext context,
    ProfileController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('profile_section_account'.tr),
        _settingsTile(
          'profile_edit_my_profile'.tr,
          Icons.person_outline_rounded,
          () => Get.to(() => const EditWalkerProfileScreen()),
        ),
        // v20.0.7 — Paiement management (ajouter CB) remonté en section
        // COMPTE pour être immédiatement accessible, comme chez owner/sitter.
        _settingsTile(
          'profile_payment_management'.tr,
          Icons.credit_card_rounded,
          () => Get.to(() => const PaymentManagementScreen()),
        ),
        // v19.1.5 — "Mes tarifs" tile : dedicated screen to tweak 30/60 min
        // rates without scrolling through the full edit profile form.
        _settingsTile(
          'my_rates_section_title'.tr,
          Icons.euro_rounded,
          () => Get.to(() => const MyRatesScreen(role: 'walker')),
        ),
        _settingsTile(
          'profile_pawmap'.tr,
          Icons.map_rounded,
          () => Get.to(() => const PawMapScreen()),
        ),
        // v21.1.1 — Tile "Vérifier identité" retirée : Stripe Identity purgé.

        // v20.0.7 — Top Walker loyalty card (Avantages walker) — mirrors
        // TopSitterCard used in sitter profile so the walker sees his
        // progress vers 20 balades + 4.5★ → 15% commission.
        _sectionHeader('profile_section_my_services'.tr),
        const TopWalkerCard(),

        _sectionHeader('profile_section_payments'.tr),
        // v19.0 — Mon portefeuille en tête des paiements : c'est le solde
        // des gains du walker, d'où il peut retirer vers IBAN/PayPal ou
        // dépenser dans le shop.
        _settingsTile(
          'wallet_menu_title'.tr,
          Icons.account_balance_wallet_rounded,
          () => Get.to(() => const WalletScreen()),
        ),
        _settingsTile(
          'profile_shop'.tr,
          Icons.storefront_rounded,
          () => Get.to(() => const CoinShopScreen()),
        ),
        // v20.0.7 — Payment Management remonté en section COMPTE en haut.
        _settingsTile(
          'profile_referrals'.tr,
          Icons.group_add_rounded,
          () => Get.to(() => const MyReferralsScreen()),
        ),

        _sectionHeader('profile_section_preferences'.tr),
        _settingsTile(
          'profile_change_language'.tr,
          Icons.language_rounded,
          controller.showLanguageDialog,
        ),
        _settingsTile(
          'theme_setting_title'.tr,
          Icons.brightness_6_rounded,
          () => _showThemeDialog(),
        ),

        _sectionHeader('profile_section_security'.tr),
        _settingsTile(
          'profile_password'.tr,
          Icons.lock_outline_rounded,
          () => Get.to(() => const ChangePasswordScreen()),
        ),
        _settingsTile(
          'profile_blocked_users'.tr,
          Icons.block_rounded,
          () =>
              Get.to(() => const BlockedUsersScreen(userType: 'pet_walker')),
        ),

        _sectionHeader('profile_section_legal'.tr),
        _settingsTile(
          'profile_terms'.tr,
          Icons.description_outlined,
          () => Get.to(() => const TermsAndConditionsScreen()),
        ),
        _settingsTile(
          'profile_privacy'.tr,
          Icons.privacy_tip_outlined,
          () => Get.to(() => const PrivacyPolicyScreen()),
        ),

        // v20.0.8 — Bug report tile.
        _sectionHeader('profile_section_support'.tr),
        _settingsTile(
          'bug_report_title'.tr,
          Icons.bug_report_rounded,
          () => Get.to(() => const BugReportScreen()),
        ),

        _sectionHeader('profile_section_danger'.tr),
        _settingsTileDanger(
          'profile_delete_account'.tr,
          Icons.delete_outline_rounded,
          () => controller.showDeleteAccountDialog(Get.context!),
        ),
      ],
    );
  }

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

  Widget _settingsTile(String title, IconData icon, VoidCallback onTap) {
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
                  color: _accentLight,
                  borderRadius: BorderRadius.circular(9.r),
                ),
                child: Icon(icon, size: 16.sp, color: _accent),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: InterText(
                  text: title,
                  fontSize: 14.sp,
                  color: AppColors.textSecondary(context),
                  fontWeight: FontWeight.w500,
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

  Widget _settingsTileDanger(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Builder(
        builder: (context) => Container(
          margin: EdgeInsets.only(bottom: 6.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: AppColors.errorColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: AppColors.errorColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, size: 20.sp, color: AppColors.errorColor),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: InterText(
                  text: title,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.errorColor,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.sp,
                color: AppColors.errorColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
