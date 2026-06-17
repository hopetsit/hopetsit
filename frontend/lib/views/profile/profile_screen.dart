import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_settings_tabs.dart';
import 'package:hopetsit/views/profile/widgets/profile_notification_bell.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/views/profile/terms_and_conditions_screen.dart';
import 'package:hopetsit/views/profile/privacy_policy_screen.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/widgets/loyalty_card.dart';
import 'package:hopetsit/views/profile/my_referrals_screen.dart';
import 'package:hopetsit/views/profile/promo_code_screen.dart';
import 'package:hopetsit/views/boost/pawspot_leaderboard_screen.dart';
import 'package:hopetsit/widgets/boost_profile_card.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
// v18.2 — Mes paiements entry point.
import 'package:hopetsit/views/pet_owner/payments/owner_payments_screen.dart';
// v23.1 — Mes cartes (Airwallex saved payment_consents).
import 'package:hopetsit/views/pet_owner/payments/saved_cards_screen.dart';
import 'package:hopetsit/views/profile/bug_report_screen.dart';
// v23.1 part 124 — Daniel : "Enlever admin de lapp ; car jai admin
// navigateur". Le panel admin est désormais accessible UNIQUEMENT via
// le navigateur (https://hopetsit-backend.onrender.com/admin). Le
// raccourci profil + l'import sont retirés ; le fichier
// views/admin/admin_dashboard_screen.dart sera supprimé en suivant.

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
            // v23.1.149 — Daniel : "le boost sur owner ne saffiche pas". On
            // wrap le hero dans un Obx qui ajoute un cadre doré + glow dès
            // que `ActiveBenefitsRow.boostActiveAccessor` passe à true. Ça
            // se rebuild auto quand l'ActiveBenefitsRow interne fetch ses
            // /users/me/benefits.
            // v23.1.175 — Daniel : "le cadre boost napparait toujour pas
            // sur le profile owner". Cause : timing async — _boostActive
            // mis à true seulement après le mount du widget enfant
            // ActiveBenefitsRow. On force maintenant un refetch immédiat
            // dès le build du profil owner pour avoir l'état correct au
            // tout premier frame (au lieu d'attendre 60s+ pour le tick).
            Builder(builder: (ctx) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ActiveBenefitsRow.refreshBoostState();
              });
              return const SizedBox.shrink();
            }),
            Obx(() {
              final isBoosted = ActiveBenefitsRow.boostActiveAccessor.value;
              const boostGold = Color(0xFFD4AF37);
              return Container(
                decoration: isBoosted
                    ? BoxDecoration(
                        border: Border.all(color: boostGold, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: boostGold.withValues(alpha: 0.45),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      )
                    : null,
                child: _buildOwnerHero(controller),
              );
            }),

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
          // v23.1.290 — hauteur MINIMALE (au lieu de fixe) : le header s'étend
          // si les badges passent sur 2 lignes (PawFollow + Famille + Boost +
          // PawSpot) au lieu de déborder sous le dégradé.
          constraints: BoxConstraints(minHeight: 200.h),
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
              // v23.1 part 130 — Phase 6 audit P6-5 : Daniel "Photo profil
              // gene". L'avatar overlap les badges Premium/Boost/PawSpot.
              // Solution : on réserve 130.w à droite pour que la Column
              // ne déborde plus sous l'avatar, et on remonte l'avatar à
              // top:60 pour qu'il dépasse du hero sous forme de tuile
              // classique "Instagram profile".
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            // v443 — Daniel : logo de l'app (ic_launcher) à la
                            // place du pictogramme générique, à côté du rôle.
                            Container(
                              width: 26.w,
                              height: 26.w,
                              padding: EdgeInsets.all(2.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(7.r),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5.r),
                                child: Image.asset(
                                  'assets/brand/png/ic_launcher.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            PoppinsText(
                              text: 'role_pet_owner'.tr,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const Spacer(),
                            // v441 — cloche de notifications (demandes / amis /
                            // paiements) en haut du hero, à gauche de l'avatar.
                            const ProfileNotificationBell(role: 'owner'),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Obx(() => PoppinsText(
                          text: controller.userName.value,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )),
                        // v23.1.299 — Daniel : "le mail apparaît dans le profil
                        // en haut, enlève-le". On retire l'email du héros (owner,
                        // sitter, walker) pour un en-tête épuré et cohérent.
                        // v23.1 part 109 — badges Boost / PawSpot / Premium
                        // visibles dans le header (rebuild auto via Obx).
                        const ActiveBenefitsRow(compact: true),
                      ],
                    ),
                  ),
                  // v23.1 part 130 — Phase 6 audit P6-5 : reserve la zone
                  // de l'avatar pour empêcher la Column de déborder.
                  SizedBox(width: 110.w),
                ],
              ),
            ),
          ),
        ),
        // Avatar overlay
        // v23.1 part 130 — Phase 6 audit P6-5 : top:60h (au lieu de 80)
        // pour que l'avatar dépasse plus visiblement du hero. Avec
        // hero 200h + avatar 100h, top 60 = bottom 160 = juste à
        // l'intérieur du hero (40h de dépassement avec le border-radius
        // de 55r). Look "Instagram profile".
        Positioned(
          right: 20.w,
          top: 60.h,
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
                        memCacheWidth: 300, // v235.
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
    // v446 — owner = UN SEUL grand bouton rectangle « Modifier mon animal ».
    // v449 — Daniel : bouton ORANGE PÂLE (au lieu du plein orange), cohérent
    // avec le pâle par rôle des boutons sitter/walker.
    return Builder(
      builder: (context) {
        final labelColor =
            Get.isDarkMode ? AppColors.textPrimary(context) : AppColors.ownerAccent;
        return GestureDetector(
          onTap: controller.navigateToEditPetProfile,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            decoration: BoxDecoration(
              color: Get.isDarkMode
                  ? const Color(0xFF2A211F)
                  : AppColors.scaffoldOwnerLight,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: Get.isDarkMode
                    ? const Color(0x59EF4324)
                    : const Color(0x4DEF4324),
                width: 1.1,
              ),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pets_rounded, color: labelColor, size: 20.sp),
                SizedBox(width: 10.w),
                InterText(
                  text: 'pet_edit_animal'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // _buildProfileInfo removed — replaced by _buildOwnerHero + _buildOwnerAvatar.

  // ── Section palette — matches the walker profile redesign so the 3 roles
  // feel consistent visually. Owner accent (primary red) is used where the
  // section doesn't already have a semantic color.
  // v406 — _paleBlue retiré (la tuile Langue est passée dans l'onglet Préférences).
  static const Color _palePurple = Color(0xFF6A5AE0);
  static const Color _paleOrange = Color(0xFFE9A73B);

  // v406 refonte — la section paramètres est désormais découpée en 3 onglets
  // (Profil / Préférences / Sécurité) comme la maquette. Le héros + boost +
  // switch-role + quick-actions restent au-dessus (build()).
  Widget _buildSettingsSection(
    BuildContext context,
    ProfileController controller,
  ) {
    return Obx(() {
      final tab = controller.profileTab.value;
      final p = controller.profile.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileTabBar(
            index: tab,
            accent: AppColors.primaryColor,
            onChanged: (i) => controller.profileTab.value = i,
          ),
          SizedBox(height: 16.h),
          if (tab == 0) _buildProfilTab(context, controller),
          if (tab == 1) ...[
            ProfilePreferencesTab(
              accent: AppColors.primaryColor,
              prefs: p?.preferences ?? const ProfilePreferences(),
              saving: controller.prefsSaving.value,
              onSave: (updated) => controller.savePreferences(updated.toJson()),
              onLanguage: controller.showLanguageDialog,
            ),
            _buildSettingsTile(
              'theme_setting_title'.tr,
              'theme_setting_subtitle'.tr,
              Icons.brightness_6_rounded,
              _palePurple,
              () => _showThemeDialog(),
            ),
          ],
          if (tab == 2)
            ProfileSecurityTab(
              accent: AppColors.primaryColor,
              twoFactorEnabled: p?.twoFactorEnabled ?? false,
              emailVerified: p?.verified ?? false,
              phoneVerified: (p?.mobile.isNotEmpty ?? false),
              saving: controller.prefsSaving.value,
              onToggle2FA: controller.setTwoFactor,
              onChangePassword: controller.navigateToChangePassword,
              onBlockedUsers: controller.navigateToBlockedUsers,
              onDeleteAccount: () => controller.showDeleteAccountDialog(context),
            ),
        ],
      );
    });
  }

  Widget _buildProfilTab(
    BuildContext context,
    ProfileController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── COMPTE ─────────────────────────────────────────
        _sectionHeader('profile_section_account'.tr),
        _buildSettingsTile(
          'profile_edit_profile'.tr,
          'profile_edit_profile_subtitle'.tr,
          Icons.person_outline_rounded,
          AppColors.primaryColor,
          controller.navigateToEditProfile,
        ),
        // v20.0.2 — Mes paiements remonté en haut pour que l'owner puisse
        // ajouter sa carte facilement s'il ne l'a pas fait à l'inscription.
        _buildSettingsTile(
          'owner_payments_title'.tr == 'owner_payments_title'
              ? 'owner_payments_fallback'.tr
              : 'owner_payments_title'.tr,
          'owner_payments_subtitle'.tr,
          Icons.credit_card_rounded,
          AppColors.primaryColor,
          () => Get.to(() => const OwnerPaymentsScreen()),
        ),
        // v23.1 — Mes cartes (Airwallex saved payment_consents).
        _buildSettingsTile(
          'saved_cards_title'.tr,
          'saved_cards_empty_message'.tr,
          Icons.credit_card_outlined,
          AppColors.primaryColor,
          () => Get.to(() => const SavedCardsScreen()),
        ),
        _buildSettingsTile(
          'profile_choose_service'.tr,
          'profile_choose_service_subtitle'.tr,
          Icons.work_outline_rounded,
          AppColors.primaryColor,
          controller.navigateToChooseService,
        ),
        _buildSettingsTile(
          'profile_pawmap'.tr,
          'profile_pawmap_subtitle'.tr,
          Icons.map_rounded,
          _palePurple,
          () => Get.to(() => const PawMapScreen()),
        ),

        // ── TÂCHES ─────────────────────────────────────────
        _sectionHeader('profile_section_tasks'.tr),
        _buildSettingsTile(
          'profile_add_tasks'.tr,
          'profile_add_tasks_subtitle'.tr,
          Icons.add_task_rounded,
          AppColors.greenColor,
          controller.navigateToAddTasks,
        ),
        _buildSettingsTile(
          'profile_view_tasks'.tr,
          'profile_view_tasks_subtitle'.tr,
          Icons.task_alt_rounded,
          AppColors.greenColor,
          controller.navigateToViewTask,
        ),

        // ── PAIEMENTS & SERVICES ──────────────────────────
        // v20.0.2 — Mes paiements déplacé en section COMPTE en haut.
        // Ici on garde le LoyaltyCard + Parrainage.
        _sectionHeader('profile_section_payments'.tr),
        const LoyaltyCard(),
        _buildSettingsTile(
          'referrals_title'.tr,
          'referrals_subtitle'.tr,
          Icons.group_add_rounded,
          _paleOrange,
          () => Get.to(() => const MyReferralsScreen()),
        ),
        // Code promo — saisie d'un code émis par l'admin (abo offert ou -%).
        _buildSettingsTile(
          'promo_screen_title'.tr,
          'promo_profile_tile_subtitle'.tr,
          Icons.confirmation_number_rounded,
          _palePurple,
          () => Get.to(() => PromoCodeScreen(accent: AppColors.primaryColor)),
        ),
        // Refonte PawSpot — accès direct au classement PawPoints (doré).
        _buildSettingsTile(
          'pawspot_profile_tile'.tr,
          'pawspot_profile_tile_sub'.tr,
          Icons.emoji_events_rounded,
          const Color(0xFFE8A00A),
          () => Get.to(() => const PawspotLeaderboardScreen()),
        ),

        // v406 — PRÉFÉRENCES + SÉCURITÉ déplacés dans les onglets dédiés
        // (ProfilePreferencesTab / ProfileSecurityTab). Voir _buildSettingsSection.

        // ── LÉGAL ─────────────────────────────────────────
        _sectionHeader('profile_section_legal'.tr),
        _buildSettingsTile(
          'terms_read_button'.tr,
          'terms_read_subtitle'.tr,
          Icons.description_outlined,
          AppColors.textSecondary(context),
          () => Get.to(() => const TermsAndConditionsScreen()),
        ),
        _buildSettingsTile(
          'profile_privacy'.tr,
          'profile_privacy_subtitle'.tr,
          Icons.privacy_tip_outlined,
          AppColors.textSecondary(context),
          () => Get.to(() => const PrivacyPolicyScreen()),
        ),

        // ── SUPPORT ──────────────────────────────────────
        // v20.0.8 — Bug report tile at the bottom of every profile.
        _sectionHeader('profile_section_support'.tr),
        _buildSettingsTile(
          'bug_report_title'.tr,
          'bug_report_subtitle'.tr,
          Icons.bug_report_rounded,
          const Color(0xFFF59E0B),
          () => Get.to(() => const BugReportScreen()),
        ),

        // v23.1 part 124 — section "Plateforme" + raccourci Dashboard
        // admin RETIRÉS de l'app. Daniel : "Enlever admin de lapp ; car
        // jai admin navigateur". Le panel reste dispo via
        // https://hopetsit-backend.onrender.com/admin.
        // v406 — ZONE DANGER (supprimer le compte) déplacée dans l'onglet
        // Sécurité (ProfileSecurityTab).
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

  // v406 — _buildSettingsTileDanger retiré : la suppression du compte est
  // désormais rendue par ProfileSecurityTab (onglet Sécurité).

  /// Builds a column of switch-role cards — one per role the user is NOT in.
  /// Each card opens a confirm dialog, then calls switchRole with the target.
  Widget _buildSwitchRoleCards(BuildContext context) {
    final authController = Get.find<AuthController>();
    final currentRole = authController.userRole.value;

    // Compute the 2 other roles the user can switch to.
    const allRoles = ['owner', 'sitter', 'walker'];
    final otherRoles = allRoles.where((r) => r != currentRole).toList();

    // v448 — Daniel : les 2 boutons « Passer en … » CÔTE À CÔTE, plus compacts,
    // police lisible (au lieu de l'un sous l'autre, pleine largeur).
    return Row(
      children: [
        for (int i = 0; i < otherRoles.length; i++) ...[
          Expanded(
            child: _buildSwitchRoleCard(context, targetRole: otherRoles[i]),
          ),
          if (i < otherRoles.length - 1) SizedBox(width: 10.w),
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

    return GestureDetector(
      onTap: () => _showSwitchRoleDialog(context, targetRole: targetRole),
      child: Builder(
        builder: (context) => Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Row(
            children: [
              // Colored icon chip on the left (compact).
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.pets_rounded, size: 18.sp, color: accentColor),
              ),
              SizedBox(width: 9.w),
              Expanded(
                child: InterText(
                  text: 'profile_switch_role_card_title'.trParams({
                    'role': newRoleText,
                  }),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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
