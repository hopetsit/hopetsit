import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/pet_sitter/payment/payment_management_screen.dart';
import 'package:hopetsit/views/profile/blocked_users_screen.dart';
import 'package:hopetsit/views/profile/change_password_screen.dart';
import 'package:hopetsit/views/profile/my_referrals_screen.dart';
import 'package:hopetsit/views/profile/privacy_policy_screen.dart';
import 'package:hopetsit/views/profile/terms_and_conditions_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Walker profile screen.
///
/// Phase 2 decision (session avril 2026) — the walker profile is not yet
/// built out (no pricing manager, no coverage editor, no avatar flow). Until
/// the full profile UI lands, tapping the Profil tab takes the walker directly
/// to the PawMap (their primary tool: POIs, reports 48h, amis en live).
///
/// A small gear button is overlaid top-right so the walker can still reach the
/// essentials — switch role, logout — without having to go back to the owner
/// or sitter flow.
class WalkerProfileScreen extends StatelessWidget {
  const WalkerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: Stack(
        children: [
          // Fill the whole body with the PawMap.
          const Positioned.fill(child: PawMapScreen()),
          // Floating gear — opens the walker quick-settings sheet.
          Positioned(
            top: MediaQuery.of(context).padding.top + 12.h,
            right: 12.w,
            child: _GearButton(onTap: () => _showQuickSettings(context)),
          ),
        ],
      ),
    );
  }

  /// Quick-settings bottom sheet — minimal actions the walker might need while
  /// the full profile screen is not yet implemented. The sheet is scrollable
  /// so the list can grow without overflowing short screens.
  void _showQuickSettings(BuildContext context) {
    Get.bottomSheet(
      Builder(
        builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtl) => Container(
            decoration: BoxDecoration(
              color: AppColors.card(sheetContext),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24.r),
                topRight: Radius.circular(24.r),
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollCtl,
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Grab handle.
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      margin: EdgeInsets.only(bottom: 16.h),
                      decoration: BoxDecoration(
                        color: AppColors.divider(sheetContext),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  PoppinsText(
                    text: 'Réglages promeneur',
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(sheetContext),
                  ),
                  SizedBox(height: 4.h),
                  InterText(
                    text: 'Le profil complet arrive bientôt. En attendant :',
                    fontSize: 12.sp,
                    color: AppColors.textSecondary(sheetContext),
                  ),

                  // ── Compte ─────────────────────────────────
                  _sectionHeader(sheetContext, 'Compte'),
                  _settingsRow(
                    sheetContext,
                    icon: Icons.pets_rounded,
                    iconColor: AppColors.primaryColor,
                    title: 'Passer en Propriétaire',
                    subtitle: 'Basculer vers le rôle owner',
                    onTap: () {
                      Get.back();
                      _confirmSwitchRole(context, 'owner', 'Propriétaire');
                    },
                  ),
                  SizedBox(height: 10.h),
                  _settingsRow(
                    sheetContext,
                    icon: Icons.home_work_rounded,
                    iconColor: const Color(0xFF1A73E8),
                    title: 'Passer en Gardien',
                    subtitle: 'Basculer vers le rôle sitter',
                    onTap: () {
                      Get.back();
                      _confirmSwitchRole(context, 'sitter', 'Gardien');
                    },
                  ),

                  // ── Paiements & services ───────────────────
                  _sectionHeader(sheetContext, 'Paiements & services'),
                  _settingsRow(
                    sheetContext,
                    icon: Icons.storefront_rounded,
                    iconColor: AppColors.greenColor,
                    title: 'Boutique',
                    subtitle: 'Premium, Boost profil, Map Boost',
                    onTap: () {
                      Get.back();
                      Get.to(() => const CoinShopScreen());
                    },
                  ),
                  SizedBox(height: 10.h),
                  _settingsRow(
                    sheetContext,
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: AppColors.primaryColor,
                    title: 'Gestion paiement',
                    subtitle: 'Moyens de paiement & payouts',
                    onTap: () {
                      Get.back();
                      Get.to(() => const PaymentManagementScreen());
                    },
                  ),
                  SizedBox(height: 10.h),
                  _settingsRow(
                    sheetContext,
                    icon: Icons.group_add_rounded,
                    iconColor: const Color(0xFFE9A73B),
                    title: 'Parrainages',
                    subtitle: 'Invite tes amis, gagne des crédits',
                    onTap: () {
                      Get.back();
                      Get.to(() => const MyReferralsScreen());
                    },
                  ),

                  // ── Préférences ────────────────────────────
                  _sectionHeader(sheetContext, 'Préférences'),
                  _settingsRow(
                    sheetContext,
                    icon: Icons.language_rounded,
                    iconColor: const Color(0xFF1A73E8),
                    title: 'Langue',
                    subtitle: 'Change la langue de l\'app',
                    onTap: () {
                      Get.back();
                      _profileController().showLanguageDialog();
                    },
                  ),
                  SizedBox(height: 10.h),
                  _settingsRow(
                    sheetContext,
                    icon: Icons.brightness_6_rounded,
                    iconColor: const Color(0xFF6A5AE0),
                    title: 'Thème',
                    subtitle: 'Clair / sombre / système',
                    onTap: () {
                      Get.back();
                      _showThemeDialog();
                    },
                  ),

                  // ── Sécurité ───────────────────────────────
                  _sectionHeader(sheetContext, 'Sécurité'),
                  _settingsRow(
                    sheetContext,
                    icon: Icons.lock_outline_rounded,
                    iconColor: AppColors.primaryColor,
                    title: 'Mot de passe',
                    subtitle: 'Modifier ton mot de passe',
                    onTap: () {
                      Get.back();
                      Get.to(() => const ChangePasswordScreen());
                    },
                  ),
                  SizedBox(height: 10.h),
                  _settingsRow(
                    sheetContext,
                    icon: Icons.block_rounded,
                    iconColor: AppColors.errorColor,
                    title: 'Utilisateurs bloqués',
                    subtitle: 'Gérer les personnes bloquées',
                    onTap: () {
                      Get.back();
                      Get.to(
                        () => const BlockedUsersScreen(userType: 'pet_walker'),
                      );
                    },
                  ),

                  // ── Légal ──────────────────────────────────
                  _sectionHeader(sheetContext, 'Légal'),
                  _settingsRow(
                    sheetContext,
                    icon: Icons.description_outlined,
                    iconColor: AppColors.textSecondary(sheetContext),
                    title: 'Conditions d\'utilisation',
                    subtitle: 'CGU de la plateforme',
                    onTap: () {
                      Get.back();
                      Get.to(() => const TermsAndConditionsScreen());
                    },
                  ),
                  SizedBox(height: 10.h),
                  _settingsRow(
                    sheetContext,
                    icon: Icons.privacy_tip_outlined,
                    iconColor: AppColors.textSecondary(sheetContext),
                    title: 'Confidentialité',
                    subtitle: 'Politique de confidentialité',
                    onTap: () {
                      Get.back();
                      Get.to(() => const PrivacyPolicyScreen());
                    },
                  ),

                  // ── Zone danger ────────────────────────────
                  _sectionHeader(sheetContext, 'Zone danger'),
                  _settingsRow(
                    sheetContext,
                    icon: Icons.delete_outline_rounded,
                    iconColor: AppColors.errorColor,
                    title: 'Supprimer le compte',
                    subtitle: 'Action irréversible',
                    onTap: () {
                      Get.back();
                      _profileController()
                          .showDeleteAccountDialog(context);
                    },
                  ),

                  SizedBox(height: 20.h),
                  Divider(color: AppColors.divider(sheetContext), height: 1),
                  SizedBox(height: 14.h),
                  _settingsRow(
                    sheetContext,
                    icon: Icons.logout_rounded,
                    iconColor: AppColors.errorColor,
                    title: 'Déconnexion',
                    subtitle: 'Quitter ta session',
                    onTap: () async {
                      Get.back();
                      if (Get.isRegistered<AuthController>()) {
                        await Get.find<AuthController>().logout();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  /// Lazy getter for ProfileController. We reuse it for the generic dialog
  /// flows (language picker, delete account) instead of duplicating that
  /// logic into walker-land. If the walker has never touched an owner flow,
  /// the controller is created on demand here.
  ProfileController _profileController() {
    return Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());
  }

  /// Theme picker dialog — mirrors the owner profile `_showThemeDialog` so the
  /// walker can toggle light / dark / system from the gear sheet.
  void _showThemeDialog() {
    final tc = Get.isRegistered<ThemeController>()
        ? Get.find<ThemeController>()
        : Get.put(ThemeController(), permanent: true);
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

  /// Small caps section label used to group bottom-sheet actions.
  Widget _sectionHeader(BuildContext context, String label) {
    return Padding(
      padding: EdgeInsets.only(top: 20.h, bottom: 10.h),
      child: PoppinsText(
        text: label.toUpperCase(),
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary(context),
      ),
    );
  }

  Widget _settingsRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: iconColor.withOpacity(0.18),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.14),
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
              size: 13.sp,
              color: AppColors.textSecondary(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Confirm dialog before switching role. Mirrors the pattern used in
  /// profile_screen.dart (owner) so walker UX feels consistent.
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
            title: Text(
              'Changer de rôle',
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
                      ? 'Bascule vers $roleLabel…'
                      : 'Tu vas basculer vers le rôle $roleLabel. Continuer ?',
                  style: TextStyle(color: AppColors.textPrimary(dialogContext)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Annuler',
                  style: TextStyle(color: AppColors.textSecondary(dialogContext)),
                ),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        await auth.switchRole(targetRole: targetRole);
                        if (Get.isDialogOpen == true) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                child: Text(
                  'Passer en $roleLabel',
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
}

/// Circular floating gear button — shown overlaid on top of the PawMap so the
/// walker can reach quick-settings without a profile screen.
class _GearButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.r),
        child: Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: AppColors.card(context),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: AppColors.divider(context),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.settings_rounded,
            size: 22.sp,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }
}
