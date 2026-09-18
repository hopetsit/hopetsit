// v565 — points 26 / 33 : catégories de la page Profil, PARTAGÉES par les 3
// rôles (owner / sitter / walker). Remplace les 3 onglets (Profil /
// Préférences / Sécurité) par des groupes clairs :
//   Compte · Mes animaux (owner) / Mon activité (prestataires) · Paiements &
//   wallet · Abonnements & boutique · Préférences & notifications · Sécurité
//   · Aide.
// Aucune fonction retirée : chaque ancienne tuile a sa rangée ici.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:hopetsit/controllers/billing_info_controller.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/boost/pawspot_leaderboard_screen.dart';
import 'package:hopetsit/views/kyc/kyc_verification_screen.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/notifications/notification_test_screen.dart';
import 'package:hopetsit/views/pet_owner/payments/owner_payments_screen.dart';
import 'package:hopetsit/views/pet_owner/payments/saved_cards_screen.dart';
import 'package:hopetsit/views/pet_sitter/booking/sitter_bookings_screen.dart';
import 'package:hopetsit/views/pet_sitter/payment/payment_management_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/availability_calendar_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/iban_setup_screen.dart';
import 'package:hopetsit/views/profile/add_task_screen.dart';
import 'package:hopetsit/views/profile/billing_info_screen.dart';
import 'package:hopetsit/views/profile/bug_report_screen.dart';
import 'package:hopetsit/views/profile/edit_pet_screen.dart';
import 'package:hopetsit/views/profile/my_pets_screen.dart';
import 'package:hopetsit/views/profile/my_rates_screen.dart';
import 'package:hopetsit/views/profile/my_referrals_screen.dart';
import 'package:hopetsit/views/profile/preferences_screen.dart';
import 'package:hopetsit/views/profile/privacy_policy_screen.dart';
import 'package:hopetsit/views/profile/promo_code_screen.dart';
import 'package:hopetsit/views/profile/security_screen.dart';
import 'package:hopetsit/views/profile/terms_and_conditions_screen.dart';
import 'package:hopetsit/views/profile/view_task_screen.dart';
import 'package:hopetsit/views/profile/widgets/change_email_sheet.dart';
import 'package:hopetsit/views/profile/widgets/profile_settings_host.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/views/reviews/my_reviews_screen.dart';
import 'package:hopetsit/views/wallet/wallet_screen.dart';
import 'package:hopetsit/widgets/loyalty_card.dart';
import 'package:hopetsit/widgets/promo_code_sheet.dart';
import 'package:hopetsit/widgets/top_sitter_card.dart';
import 'package:hopetsit/widgets/top_walker_card.dart';

/// Ouvre « Mes avis » d'un prestataire (sitter / walker) avec les vraies
/// données serveur (endpoint public /reviews).
Future<void> openMyReviews({required String role, required Color accent}) async {
  final id = GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile)?['id']?.toString() ?? '';
  if (id.isEmpty) return;
  List<dynamic> reviews = const [];
  try {
    reviews = await Get.find<OwnerRepository>().getProviderReviews(revieweeId: id, revieweeRole: role);
  } catch (_) {
    reviews = const [];
  }
  double avg = 0;
  if (reviews.isNotEmpty) {
    final sum = reviews.fold<double>(0, (a, r) {
      final v = (r is Map) ? r['rating'] : null;
      return a + ((v is num) ? v.toDouble() : 0);
    });
    avg = sum / reviews.length;
  }
  Get.to(() => MyReviewsScreen(
        reviews: reviews,
        rating: avg,
        reviewsCount: reviews.length,
        accent: accent,
      ));
}

/// Boîte de dialogue Apparence (Clair / Sombre / Système), partagée.
void showThemeDialog() {
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
              RadioListTile<ThemeMode>(title: Text('theme_light'.tr), value: ThemeMode.light),
              RadioListTile<ThemeMode>(title: Text('theme_dark'.tr), value: ThemeMode.dark),
              RadioListTile<ThemeMode>(title: Text('theme_system'.tr), value: ThemeMode.system),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('common_close'.tr)),
      ],
    ),
  );
}

class ProfileCategories extends StatelessWidget {
  final String role; // 'owner' | 'sitter' | 'walker'
  final Color accent;
  final ProfileSettingsHost host;
  final VoidCallback onEditProfile;

  const ProfileCategories({
    super.key,
    required this.role,
    required this.accent,
    required this.host,
    required this.onEditProfile,
  });

  bool get _isOwner => role == 'owner';
  bool get _isSitter => role == 'sitter';

  static const Color _purple = Color(0xFF6A5AE0);
  static const Color _amber = Color(0xFFE8920A);
  static const Color _gold = Color(0xFFE8A00A);
  static const Color _blue = Color(0xFF1A73E8);
  static const Color _slate = Color(0xFF94A3B8);
  static const Color _warn = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final p = host.profile.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _account(context, p),
          if (_isOwner) _pets(context) else _activity(context),
          _payments(context),
          _shop(context),
          _prefs(context),
          _security(context),
          _help(context),
        ],
      );
    });
  }

  // ── Compte ────────────────────────────────────────────────────────────
  Widget _account(BuildContext context, ProfileModel? p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionTitle('profile_cat_account'.tr, icon: Icons.person_rounded),
        ProfileGroupCard(children: [
          ProfileRow(
            icon: Icons.person_outline_rounded,
            title: 'profile_edit_profile'.tr,
            subtitle: 'profile_edit_profile_subtitle'.tr,
            color: accent,
            onTap: onEditProfile,
          ),
          ProfileRow(
            icon: Icons.alternate_email_rounded,
            title: 'change_email_title'.tr,
            subtitle: (p?.email ?? '').isNotEmpty ? p!.email : 'profile_no_email_added'.tr,
            color: accent,
            onTap: () => showChangeEmailSheet(context, accent: accent, currentEmail: p?.email ?? ''),
          ),
          if (_isOwner)
            ProfileRow(
              icon: Icons.task_alt_rounded,
              title: 'profile_view_tasks'.tr,
              subtitle: 'profile_view_tasks_subtitle'.tr,
              color: AppColors.greenColor,
              onTap: () => Get.to(() => const ViewTaskScreen()),
            ),
          if (_isOwner)
            ProfileRow(
              icon: Icons.add_task_rounded,
              title: 'profile_add_tasks'.tr,
              subtitle: 'profile_add_tasks_subtitle'.tr,
              color: AppColors.greenColor,
              onTap: () => Get.to(() => const AddTaskScreen()),
            ),
          ProfileRow(
            icon: Icons.map_rounded,
            title: 'profile_pawmap'.tr,
            subtitle: _isOwner ? 'profile_pawmap_subtitle'.tr : 'sitter_pawmap_subtitle'.tr,
            color: _purple,
            onTap: () => Get.to(() => const PawMapScreen()),
          ),
        ]),
      ],
    );
  }

  // ── Mes animaux (owner) ───────────────────────────────────────────────
  Widget _pets(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionTitle('profile_cat_pets'.tr, icon: Icons.pets_rounded),
        ProfileGroupCard(children: [
          ProfileRow(
            icon: Icons.pets_rounded,
            title: 'my_pets_title'.tr,
            subtitle: 'profile_pets_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => const MyPetsScreen()),
          ),
          ProfileRow(
            icon: Icons.add_circle_outline_rounded,
            title: 'my_pets_add_pet'.tr,
            subtitle: 'profile_add_pet_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => const EditPetScreen()),
          ),
        ]),
      ],
    );
  }

  // ── Mon activité (prestataires) ───────────────────────────────────────
  Widget _activity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionTitle('profile_cat_activity'.tr, icon: Icons.work_rounded),
        if (_isSitter) const TopSitterCard() else const TopWalkerCard(),
        SizedBox(height: 8.h),
        ProfileGroupCard(children: [
          if (_isSitter)
            ProfileRow(
              icon: Icons.event_rounded,
              title: 'bookings_tab_title'.tr,
              subtitle: 'bookings_tab_subtitle'.tr,
              color: accent,
              onTap: () => Get.to(() => const SitterBookingsScreen()),
            ),
          ProfileRow(
            icon: Icons.payments_rounded,
            title: 'my_rates_section_title'.tr,
            subtitle: _isSitter ? 'my_rates_sitter_hint'.tr : 'my_rates_walker_hint'.tr,
            color: accent,
            onTap: () => Get.to(() => MyRatesScreen(role: role)),
          ),
          ProfileRow(
            icon: Icons.calendar_month_rounded,
            title: 'profile_my_availability'.tr,
            subtitle: 'profile_availability_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => AvailabilityCalendarScreen(role: _isSitter ? null : 'walker')),
          ),
          ProfileRow(
            icon: Icons.rate_review_rounded,
            title: 'reviews_title'.tr,
            subtitle: 'profile_reviews_subtitle'.tr,
            color: _gold,
            onTap: () => openMyReviews(role: role, accent: accent),
          ),
          ProfileRow(
            icon: Icons.verified_rounded,
            title: 'kyc_tile_title'.tr,
            subtitle: 'kyc_tile_subtitle'.tr,
            color: _blue,
            onTap: () => Get.to(() => const KycVerificationScreen()),
          ),
        ]),
      ],
    );
  }

  // ── Paiements & wallet ────────────────────────────────────────────────
  Widget _payments(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionTitle('profile_cat_payments'.tr, icon: Icons.account_balance_wallet_rounded),
        if (_isOwner) ...[
          const LoyaltyCard(),
          SizedBox(height: 8.h),
        ],
        ProfileGroupCard(children: [
          if (!_isOwner)
            ProfileRow(
              icon: Icons.account_balance_wallet_rounded,
              title: 'wallet_menu_title'.tr,
              subtitle: 'wallet_menu_subtitle'.tr,
              color: _blue,
              onTap: () => Get.to(() => const WalletScreen()),
            ),
          if (_isOwner)
            ProfileRow(
              icon: Icons.receipt_long_rounded,
              title: 'owner_payments_title'.tr == 'owner_payments_title'
                  ? 'owner_payments_fallback'.tr
                  : 'owner_payments_title'.tr,
              subtitle: 'owner_payments_subtitle'.tr,
              color: accent,
              onTap: () => Get.to(() => const OwnerPaymentsScreen()),
            )
          else
            ProfileRow(
              icon: Icons.credit_card_rounded,
              title: 'payment_management_title'.tr,
              subtitle: 'payment_management_subtitle'.tr,
              color: accent,
              onTap: () => Get.to(() => const PaymentManagementScreen()),
            ),
          ProfileRow(
            icon: Icons.credit_card_outlined,
            title: 'saved_cards_title'.tr,
            subtitle: 'profile_saved_cards_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => const SavedCardsScreen()),
          ),
          if (!_isOwner)
            ProfileRow(
              icon: Icons.account_balance_rounded,
              title: 'profile_quick_iban'.tr,
              subtitle: 'profile_iban_subtitle'.tr,
              color: accent,
              onTap: () => Get.to(() => const IbanSetupScreen()),
            ),
          // v566 — informations de facturation (NIF, SIRET, TVA…) des 3 rôles.
          BillingInfoRow(accent: accent),
        ]),
      ],
    );
  }

  // ── Abonnements & boutique ────────────────────────────────────────────
  Widget _shop(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionTitle('profile_cat_shop'.tr, icon: Icons.storefront_rounded),
        ProfileGroupCard(children: [
          // v565 — point 27 : entrée « Code promo » VISIBLE en tête.
          ProfileRow(
            icon: Icons.confirmation_number_rounded,
            title: 'promo_screen_title'.tr,
            subtitle: 'promo_profile_tile_subtitle'.tr,
            color: _purple,
            onTap: () => showPromoCodeSheet(context, accent: accent),
            trailing: GestureDetector(
              onTap: () => Get.to(() => PromoCodeScreen(accent: accent)),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'promo_popup_cta'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: _purple),
                ),
              ),
            ),
          ),
          ProfileRow(
            icon: Icons.storefront_rounded,
            title: 'profile_shop'.tr,
            subtitle: 'profile_shop_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => const CoinShopScreen()),
          ),
          ProfileRow(
            icon: Icons.group_add_rounded,
            title: 'referrals_title'.tr,
            subtitle: 'referrals_subtitle'.tr,
            color: _amber,
            onTap: () => Get.to(() => const MyReferralsScreen()),
          ),
          ProfileRow(
            icon: Icons.emoji_events_rounded,
            title: 'pawspot_profile_tile'.tr,
            subtitle: 'pawspot_profile_tile_sub'.tr,
            color: _gold,
            onTap: () => Get.to(() => const PawspotLeaderboardScreen()),
          ),
        ]),
      ],
    );
  }

  // ── Préférences & notifications ───────────────────────────────────────
  Widget _prefs(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionTitle('profile_cat_prefs'.tr, icon: Icons.tune_rounded),
        ProfileGroupCard(children: [
          ProfileRow(
            icon: Icons.tune_rounded,
            title: 'prefs_tab_general'.tr,
            subtitle: 'profile_prefs_general_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => ProfilePreferencesScreen(host: host, accent: accent, initialTab: 0)),
          ),
          ProfileRow(
            icon: Icons.notifications_active_rounded,
            title: 'prefs_tab_notifications'.tr,
            subtitle: 'profile_prefs_notifications_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => ProfilePreferencesScreen(host: host, accent: accent, initialTab: 1)),
          ),
          ProfileRow(
            icon: Icons.translate_rounded,
            title: 'profile_pref_language'.tr,
            subtitle: 'profile_change_language_subtitle'.tr,
            color: _blue,
            onTap: host.showLanguageDialog,
          ),
          ProfileRow(
            icon: Icons.brightness_6_rounded,
            title: 'theme_setting_title'.tr,
            subtitle: 'theme_setting_subtitle'.tr,
            color: _purple,
            onTap: showThemeDialog,
          ),
        ]),
      ],
    );
  }

  // ── Sécurité ──────────────────────────────────────────────────────────
  Widget _security(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionTitle('profile_cat_security'.tr, icon: Icons.shield_rounded),
        ProfileGroupCard(children: [
          ProfileRow(
            icon: Icons.lock_outline_rounded,
            title: 'profile_change_password'.tr,
            subtitle: 'profile_change_password_subtitle'.tr,
            color: accent,
            onTap: host.navigateToChangePassword,
          ),
          ProfileRow(
            icon: Icons.verified_user_rounded,
            title: 'profile_cat_security'.tr,
            subtitle: 'profile_security_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => ProfileSecurityScreen(host: host, accent: accent)),
          ),
          ProfileRow(
            icon: Icons.block_rounded,
            title: 'profile_blocked_users'.tr,
            subtitle: 'profile_blocked_users_subtitle'.tr,
            color: AppColors.errorColor,
            onTap: host.navigateToBlockedUsers,
          ),
          ProfileRow(
            icon: Icons.delete_outline_rounded,
            title: 'profile_delete_account'.tr,
            subtitle: 'profile_delete_account_subtitle'.tr,
            color: AppColors.errorColor,
            danger: true,
            onTap: () => host.showDeleteAccountDialog(context),
          ),
        ]),
      ],
    );
  }

  // ── Aide ──────────────────────────────────────────────────────────────
  Widget _help(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionTitle('profile_cat_help'.tr, icon: Icons.help_rounded),
        ProfileGroupCard(children: [
          ProfileRow(
            icon: Icons.notifications_active_rounded,
            title: 'notif_test_title'.tr,
            subtitle: 'profile_notif_test_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => const NotificationTestScreen()),
          ),
          ProfileRow(
            icon: Icons.bug_report_rounded,
            title: 'bug_report_title'.tr,
            subtitle: 'bug_report_subtitle'.tr,
            color: _warn,
            onTap: () => Get.to(() => const BugReportScreen()),
          ),
          ProfileRow(
            icon: Icons.description_outlined,
            title: 'terms_read_button'.tr,
            subtitle: 'terms_read_subtitle'.tr,
            color: _slate,
            onTap: () => Get.to(() => const TermsAndConditionsScreen()),
          ),
          ProfileRow(
            icon: Icons.privacy_tip_outlined,
            title: 'profile_privacy'.tr,
            subtitle: 'profile_privacy_subtitle'.tr,
            color: _slate,
            onTap: () => Get.to(() => const PrivacyPolicyScreen()),
          ),
        ]),
      ],
    );
  }
}

/// v566 — rangée « Informations de facturation » (Paiements & wallet, 3 rôles).
/// Sous-titre = résumé « CIF · B12345678 » une fois rempli, sinon l'invitation.
class BillingInfoRow extends StatefulWidget {
  final Color accent;
  const BillingInfoRow({super.key, required this.accent});

  @override
  State<BillingInfoRow> createState() => _BillingInfoRowState();
}

class _BillingInfoRowState extends State<BillingInfoRow> {
  late final BillingInfoController _c;

  @override
  void initState() {
    super.initState();
    _c = BillingInfoController.ensure();
    // Après la 1re frame : jamais de changement d'état pendant un build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.loadIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final summary = _c.info.value.summary;
      return ProfileRow(
        icon: Icons.request_quote_rounded,
        title: 'billing_title'.tr,
        subtitle: summary.isNotEmpty ? summary : 'billing_row_subtitle'.tr,
        color: widget.accent,
        onTap: () => Get.to(() => BillingInfoScreen(accent: widget.accent)),
      );
    });
  }
}
