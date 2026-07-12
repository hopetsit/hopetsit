import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/widgets/boost_profile_card.dart';
import 'package:hopetsit/widgets/kyc_status_banner.dart';
import 'package:hopetsit/widgets/my_kyc_verified_badge.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/views/profile/widgets/profile_settings_tabs.dart';
import 'package:hopetsit/views/profile/widgets/profile_notification_bell.dart';
import 'package:hopetsit/views/profile/my_rates_screen.dart';
import 'package:hopetsit/views/pet_sitter/payment/payment_management_screen.dart';
// v23.1 — Mes cartes (Airwallex saved payment_consents) — sitter peut payer un PawSpot/PawFollow.
import 'package:hopetsit/views/pet_owner/payments/saved_cards_screen.dart';
import 'package:hopetsit/views/kyc/kyc_verification_screen.dart';
import 'package:hopetsit/views/boost/pawspot_leaderboard_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/availability_calendar_screen.dart';
import 'package:hopetsit/views/wallet/wallet_screen.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/widgets/top_sitter_card.dart';
// v23.1.332 — parrainage RÉACTIVÉ pour sitter (récompense -10% PawFollow/Family).
import 'package:hopetsit/views/profile/my_referrals_screen.dart';
import 'package:hopetsit/views/profile/promo_code_screen.dart';
import 'package:hopetsit/views/profile/terms_and_conditions_screen.dart';
import 'package:hopetsit/views/profile/privacy_policy_screen.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/profile/bug_report_screen.dart';

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
              // v468 — dégage le bas au-dessus du menu pleine largeur
              padding: EdgeInsets.fromLTRB(
                  // v488 — Daniel : « Se déconnecter toujours trop bas » → on
                  // dégage davantage le bas pour passer au-dessus du menu.
                  16.w, 0, 16.w, 140.h + MediaQuery.of(context).viewPadding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),

                  // v480 — maquette « Header v2 » : la carte blanche
                  // « Note / Avis / Services » est MASQUÉE (l'en-tête affiche
                  // déjà « jours actifs + Note » → évite le doublon). Méthode
                  // _buildSitterStatsRow conservée mais plus appelée.

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
          // v23.1.290 — hauteur MINIMALE : le header s'étend si les badges
          // passent sur 2 lignes au lieu de déborder sous le dégradé.
          // v471 — Daniel : « réduis BEAUCOUP plus, juste sous les badges » → 58
          // + padding/nom resserrés + avatar radius 36 → hero ultra-compact.
          // v473 — refonte MODERNE (Daniel) : coins inférieurs arrondis + ombre
          // douce bleue = en-tête carte HD avec profondeur. Compact conservé.
          clipBehavior: Clip.antiAlias,
          constraints: BoxConstraints(minHeight: 58.h),
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
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30.r)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.32),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              _heroPaw(),
              _heroDecoCircle(),
              SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 3.h),
              // v486b — Daniel : « centrer photo + texte comme owner ».
              // Structure owner-style : rangée du haut (chip rôle + cloche),
              // puis avatar CENTRÉ verticalement avec le nom, puis stats pleine
              // largeur.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // v443 — logo de l'app à côté du rôle.
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3.r),
                                    child: Image.asset(
                                      'assets/brand/png/ic_launcher.png',
                                      width: 14.w,
                                      height: 14.w,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
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
                            // v23.1 part 247 — Daniel : "met un badge jolie".
                            // Badge KYC verifie a cote de la role pill. Le widget
                            // s'auto-update via /users/me/benefits + tick worker
                            // declenche par notifyChanged() en fin de KYC.
                            SizedBox(width: 6.w),
                            const MyKycVerifiedBadge(large: true),
                            const Spacer(),
                            // v441 — cloche de notifications (demandes / amis /
                            // paiements) en haut à droite du hero.
                            const ProfileNotificationBell(role: 'sitter'),
                          ],
                        ),
                        SizedBox(height: 14.h),
                        // v486b — avatar CENTRÉ verticalement avec le nom +
                        // pastille statut (comme owner).
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildSitterAvatar(controller, accent),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Obx(() => PoppinsText(
                                        text: controller.userName.value,
                                        fontSize: 26.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      )),
                                  SizedBox(height: 8.h),
                                  _heroStatusPill(
                                      'profile_status_available_sit'.tr),
                                  // v493 — Daniel : les badges d'abonnement
                                  // (PawFollow/PawSpot/Premium, jours restants)
                                  // n'apparaissaient QUE chez l'owner. On les
                                  // ajoute aussi au gardien : ActiveBenefitsRow
                                  // lit /benefits (valable pour les 3 rôles).
                                  SizedBox(height: 8.h),
                                  const ActiveBenefitsRow(compact: true),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Obx(() => Row(
                              children: [
                                _heroStat(
                                    '${_daysActive(controller.profile.value?.createdAt)}',
                                    'profile_days_active'.tr),
                                SizedBox(width: 8.w),
                                _heroStat(
                                    '⭐ ${(controller.profile.value?.rating ?? 0).toStringAsFixed(1)}',
                                    'stat_rating'.tr),
                              ],
                            )),
                ],
              ),
            ),
          ),
              ],
            ),
        ),
      ],
    );
  }

  /// 🐾 filigrane + cercle déco (maquette Daniel — profondeur HD).
  /// v477 — jours actifs RÉELS depuis l'inscription (createdAt → aujourd'hui).
  int _daysActive(String? createdAt) {
    if (createdAt == null || createdAt.trim().isEmpty) return 0;
    final d = DateTime.tryParse(createdAt);
    if (d == null) return 0;
    final n = DateTime.now().difference(d).inDays;
    return n < 0 ? 0 : n;
  }

  /// Pastille statut « Disponible · … » (verre dépoli blanc).
  Widget _heroStatusPill(String label) => Container(
        padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8.w,
              height: 8.w,
              decoration: const BoxDecoration(
                  color: Color(0xFFBFE0FF), shape: BoxShape.circle),
            ),
            SizedBox(width: 7.w),
            InterText(
              text: label,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ],
        ),
      );

  /// Carte stat (valeur + libellé) du header (verre dépoli).
  Widget _heroStat(String value, String label) => Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 11.h, horizontal: 4.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InterText(
                text: value,
                fontSize: 19.sp,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
              SizedBox(height: 2.h),
              InterText(
                text: label,
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ],
          ),
        ),
      );

  Widget _heroPaw() => Positioned(
        right: -26.w,
        top: -24.h,
        child: Transform.rotate(
          angle: 0.31,
          child: Text('🐾',
              style: TextStyle(
                  fontSize: 150.sp, color: Colors.white.withValues(alpha: 0.10))),
        ),
      );

  Widget _heroDecoCircle() => Positioned(
        left: -34.w,
        bottom: -56.h,
        child: Container(
          width: 150.w,
          height: 150.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
      );

  Widget _buildSitterAvatar(SitterProfileController controller, Color accent) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Obx(
            () => CircleAvatar(
              // v477 — maquette v2 : avatar agrandi (~84px) à anneau + caméra.
              radius: 41.r,
              backgroundColor: AppColors.grey300Color,
              backgroundImage: controller.profileImageUrl.value.isNotEmpty
                  ? CachedNetworkImageProvider(controller.profileImageUrl.value)
                  : null,
              child: controller.profileImageUrl.value.isEmpty
                  ? Icon(Icons.person, size: 30.sp, color: AppColors.greyColor)
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

  // v480 — maquette « Header v2 » : carte « Note / Avis / Services » retirée
  // (doublon avec les stats de l'en-tête). _buildSitterStatsRow + _statItem
  // supprimés. La liste des avis reste accessible ailleurs (avis reçus).

  /// Quick actions: Earnings, Availability, Boost, IBAN.
  /// v23.1 part 144 — Daniel : 'icone tjr diforme' après 4 tentatives
  /// successives (.w/.sp, FittedBox, _outlined, etc.). Material Icons
  /// sont fondamentalement non-uniformes (chaque glyph dessiné à la
  /// main). Switch définitif vers EMOJIS rendus par le système Android :
  /// la fonte emoji du device garantit le même bounding box pour
  /// tous les caractères. Impossible d'être déformé.
  Widget _buildSitterQuickActions(SitterProfileController controller, Color accent, Color accentLight) {
    // v446 — Daniel : 2 boutons rectangle arrondi — Calendrier (gauche) +
    // Mon portefeuille (droite). v449 — Daniel : passés en BLEU PÂLE (au lieu
    // du plein bleu), cohérent avec le pâle par rôle owner/walker.
    return Row(
      children: [
        _sitterWideAction('📅', 'profile_my_availability'.tr, accent,
            () => Get.to(() => const AvailabilityCalendarScreen())),
        SizedBox(width: 12.w),
        _sitterWideAction('💼', 'wallet_menu_title'.tr, accent,
            () => Get.to(() => const WalletScreen())),
      ],
    );
  }

  /// v449 — bouton rectangle arrondi BLEU PÂLE (Expanded) : emoji + label
  /// bleu sitter, fond bleu pâle + bordure bleue translucide, 1 ligne.
  Widget _sitterWideAction(
      String emoji, String label, Color accent, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Builder(
          builder: (context) {
            final labelColor =
                Get.isDarkMode ? AppColors.textPrimary(context) : accent;
            return Container(
              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 10.w),
              decoration: BoxDecoration(
                color: Get.isDarkMode
                    ? const Color(0xFF1C2530)
                    : AppColors.scaffoldSitterLight,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  // bleu sitter translucide (≈0.30 clair / ≈0.35 sombre) en ARGB
                  color: Get.isDarkMode
                      ? const Color(0x592563EB)
                      : const Color(0x4D2563EB),
                  width: 1.1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: TextStyle(fontSize: 18.sp)),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: InterText(
                      text: label,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Section palette — mirrors owner/walker redesign for cross-role
  // visual consistency.
  static const Color _sitterAccent = Color(0xFF1A73E8);
  static const Color _palePurple = Color(0xFF6A5AE0);
  static const Color _paleOrange = Color(0xFFE9A73B);

  // v406 refonte — section paramètres découpée en onglets Profil / Préférences
  // / Sécurité (maquette). KYC + boost + switch-rôle restent au-dessus.
  Widget _buildSettingsSection(
    BuildContext context,
    SitterProfileController controller,
  ) {
    return Obx(() {
      final tab = controller.profileTab.value;
      final p = controller.profile.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // v23.1 part 115 — Banner KYC : « Vérifier mon identité » CTA quand
          // l'utilisateur n'a pas encore complété sa vérif, sinon badge ✓.
          const KycStatusBanner(),
          // v18.6 — Booster mon profil (bleu sitter).
          BoostProfileCard(role: 'sitter'),
          SizedBox(height: 16.h),
          // Switch Role Cards — shows the 2 other roles (3-way switch).
          _buildSwitchRoleCards(context),
          SizedBox(height: 8.h),
          ProfileTabBar(
            index: tab,
            accent: _sitterAccent,
            onChanged: (i) => controller.profileTab.value = i,
          ),
          SizedBox(height: 16.h),
          if (tab == 1) ...[
            ProfilePreferencesTab(
              accent: _sitterAccent,
              prefs: p?.preferences ?? const ProfilePreferences(),
              saving: controller.prefsSaving.value,
              onSave: (u) => controller.savePreferences(u.toJson()),
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
              accent: _sitterAccent,
              twoFactorEnabled: p?.twoFactorEnabled ?? false,
              emailVerified: p?.verified ?? false,
              phoneVerified: (p?.mobile.isNotEmpty ?? false),
              saving: controller.prefsSaving.value,
              onToggle2FA: controller.setTwoFactor,
              onChangePassword: controller.navigateToChangePassword,
              onBlockedUsers: controller.navigateToBlockedUsers,
              onDeleteAccount: () => controller.showDeleteAccountDialog(context),
            ),
          if (tab == 0) _buildProfilTab(context, controller),
        ],
      );
    });
  }

  Widget _buildProfilTab(
    BuildContext context,
    SitterProfileController controller,
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
          _sitterAccent,
          controller.navigateToEditProfile,
        ),
        // v20.0.17 — Vérif identité remontée juste après Edit profile
        // (comme sur walker profile) car c'est un gate critique pour
        // apparaître dans les recherches.
        // v21.1.1 — Tile "Vérifier identité" retirée : Stripe Identity purgé.
        // Sera réintégré v22 avec un autre fournisseur KYC si nécessaire.
        // v20.0.7 — Mes paiements remonté en haut (comme owner) pour que
        // le sitter puisse ajouter sa CB dès le début sans la chercher.
        _buildSettingsTile(
          'payment_management_title'.tr,
          'payment_management_subtitle'.tr,
          Icons.credit_card_rounded,
          _sitterAccent,
          () => Get.to(() => const PaymentManagementScreen()),
        ),
        // v23.1 — Mes cartes : sitter peut enregistrer une CB pour ses
        // achats (PawSpot, PawFollow). L'écran est role-aware côté backend.
        _buildSettingsTile(
          'saved_cards_title'.tr,
          'saved_cards_empty_message'.tr,
          Icons.credit_card_outlined,
          _sitterAccent,
          () => Get.to(() => const SavedCardsScreen()),
        ),
        // v23.1 part 36 — KYC verification (3€) → badge "Vérifié" sur profil.
        _buildSettingsTile(
          'kyc_tile_title'.tr,
          'kyc_tile_subtitle'.tr,
          Icons.verified_rounded,
          const Color(0xFF1976D2),
          () => Get.to(() => const KycVerificationScreen()),
        ),
        // v19.1.5 — "Mes tarifs" tile : dedicated screen to tweak daily/weekly/
        // monthly rates without reopening the full edit profile form.
        _buildSettingsTile(
          'my_rates_section_title'.tr,
          'my_rates_sitter_hint'.tr,
          Icons.payments_rounded,
          _sitterAccent,
          () => Get.to(() => const MyRatesScreen(role: 'sitter')),
        ),
        // v450 — Daniel : « Choisir un service » retiré (services dans Modifier
        // le profil).
        _buildSettingsTile(
          'profile_pawmap'.tr,
          'sitter_pawmap_subtitle'.tr,
          Icons.map_rounded,
          _palePurple,
          () => Get.to(() => const PawMapScreen()),
        ),
        // v19.0 — Mon portefeuille (solde + retraits IBAN/PayPal)
        _buildSettingsTile(
          'wallet_menu_title'.tr,
          'wallet_menu_subtitle'.tr,
          Icons.account_balance_wallet_rounded,
          const Color(0xFF1A73E8),
          () => Get.to(() => const WalletScreen()),
        ),

        // ── MES SERVICES ──────────────────────────────────
        _sectionHeader('profile_section_my_services'.tr),
        const TopSitterCard(),
        _buildSettingsTile(
          'bookings_tab_title'.tr,
          'bookings_tab_subtitle'.tr,
          Icons.event_rounded,
          _sitterAccent,
          controller.navigateToBookings,
        ),

        // v23.1.332 — Daniel : parrainage RÉACTIVÉ pour les 3 profils
        // (récompense = -10% sur PawFollow/PawFamily, dispo pour tous).
        _sectionHeader('profile_section_payments'.tr),
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
          () => Get.to(() => const PromoCodeScreen(accent: _sitterAccent)),
        ),
        // Refonte PawSpot — accès direct au classement PawPoints (doré).
        _buildSettingsTile(
          'pawspot_profile_tile'.tr,
          'pawspot_profile_tile_sub'.tr,
          Icons.emoji_events_rounded,
          const Color(0xFFE8A00A),
          () => Get.to(() => const PawspotLeaderboardScreen()),
        ),

        // v406 — PRÉFÉRENCES + SÉCURITÉ déplacés dans les onglets dédiés.

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
        // v20.0.8 — Bug report tile.
        _sectionHeader('profile_section_support'.tr),
        _buildSettingsTile(
          'bug_report_title'.tr,
          'bug_report_subtitle'.tr,
          Icons.bug_report_rounded,
          const Color(0xFFF59E0B),
          () => Get.to(() => const BugReportScreen()),
        ),

        // v406 — ZONE DANGER (supprimer le compte) déplacée dans l'onglet
        // Sécurité (ProfileSecurityTab).
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
          return RadioGroup<ThemeMode>(
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

  // v406 — _buildSettingsTileDanger retiré : suppression du compte rendue par
  // ProfileSecurityTab (onglet Sécurité).

  /// Renders the switch cards for the 2 other roles the user can move to.
  Widget _buildSwitchRoleCards(BuildContext context) {
    final authController = Get.find<AuthController>();
    final currentRole = authController.userRole.value;
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

  Widget _buildSwitchRoleCard(
    BuildContext context, {
    required String targetRole,
  }) {
    // Each role has its own translation key + accent color.
    String titleKey;
    Color accentColor;
    switch (targetRole) {
      case 'owner':
        titleKey = 'profile_switch_to_owner';
        accentColor = AppColors.primaryColor;
        break;
      case 'walker':
        titleKey = 'role_pet_walker';
        accentColor = AppColors.greenColor;
        break;
      case 'sitter':
      default:
        titleKey = 'profile_switch_to_sitter';
        accentColor = AppColors.sitterAccent;
        break;
    }

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
                  text: titleKey.tr,
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
                      ? 'dialog_switch_role_switching'.trParams({'role': newRoleText})
                      : 'dialog_switch_role_confirm'.trParams({'role': newRoleText}),
                  style: TextStyle(color: AppColors.textPrimary(dialogContext)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'common_cancel'.tr,
                  style: TextStyle(color: AppColors.textSecondary(dialogContext)),
                ),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        await authController.switchRole(targetRole: targetRole);
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
}
