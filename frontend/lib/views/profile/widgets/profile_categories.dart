// v565 — points 26 / 33 : catégories de la page Profil, PARTAGÉES par les 3
// rôles (owner / sitter / walker). Remplace les 3 onglets (Profil /
// Préférences / Sécurité) par des groupes clairs :
//   Compte · Mes animaux (owner) / Mon activité (prestataires) · Paiements &
//   wallet · Abonnements & boutique · Préférences & notifications · Sécurité
//   · Aide.
// Aucune fonction retirée : chaque ancienne tuile a sa rangée ici.
import 'package:hopetsit/utils/map_ui_state.dart';
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
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:hopetsit/views/profile/idea_box_screen.dart';
import 'package:hopetsit/views/profile/edit_pet_screen.dart';
import 'package:hopetsit/views/profile/my_pets_screen.dart';
import 'package:hopetsit/views/profile/my_rates_screen.dart';
import 'package:hopetsit/views/profile/my_referrals_screen.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/views/friends/friends_screen.dart';
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
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/loyalty_card.dart';
import 'package:hopetsit/widgets/paw_icons.dart';
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
///
/// v573 — dialogue maison (`app_dialog_kit`) : carte coins 22, disque teinté,
/// rangées de choix `AppChoiceRow` avec radio dessinée à l'accent du rôle.
/// Plus aucun `RadioListTile`. La logique est inchangée : un tap appelle
/// toujours `ThemeController.setMode`, et le dialogue reste ouvert.
void showThemeDialog([BuildContext? context]) {
  final tc = Get.find<ThemeController>();
  final ctx = context ?? Get.context;
  if (ctx == null) return;
  final accent = AppColors.activeRoleAccent();
  showDialog<void>(
    context: ctx,
    builder: (dCtx) => AppDialogCard(
      title: 'theme_setting_title'.tr,
      message: 'theme_setting_subtitle'.tr,
      icon: Icons.brightness_6_rounded,
      accent: accent,
      content: Obx(() {
        // Règle GetX du projet : le `.value` est lu DANS la closure de l'Obx.
        final current = tc.themeMode.value;
        Widget row(ThemeMode mode, IconData icon, String label) => Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: AppChoiceRow(
                label: label,
                icon: icon,
                accent: accent,
                selected: current == mode,
                onTap: () => tc.setMode(mode),
              ),
            );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(ThemeMode.light, Icons.light_mode_rounded, 'theme_light'.tr),
            row(ThemeMode.dark, Icons.dark_mode_rounded, 'theme_dark'.tr),
            row(ThemeMode.system, Icons.brightness_auto_rounded,
                'theme_system'.tr),
          ],
        );
      }),
      actions: [
        AppDialogSecondaryButton(
          label: 'common_close'.tr,
          onTap: () => Navigator.of(dCtx).pop(),
        ),
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
  static const Color _slate = Color(0xFFB69C96);
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

  /// v585 (bug 14) — « Mes amis » : N amis · N demandes (si le contrôleur
  /// d'amis est chargé), sinon ce que contient l'écran.
  Widget _friendsRow() {
    Widget row(String subtitle) => ProfileRow(
          key: const ValueKey<String>('profile_friends_row'),
          icon: PawIcon.friends,
          title: 'profile585_friends_title'.tr,
          subtitle: subtitle,
          color: const Color(0xFFE0457B),
          onTap: () => Get.to(() => const FriendsScreen()),
        );
    if (!Get.isRegistered<FriendController>()) {
      return row('profile585_friends_sub'.tr);
    }
    final fc = Get.find<FriendController>();
    return Obx(() {
      final n = fc.friends.where((f) => f.status == 'accepted').length;
      final r = fc.incomingRequests.where((f) => f.status == 'pending').length;
      return row(n + r == 0
          ? 'profile585_friends_sub'.tr
          : 'profile585_friends_count'
              .trParams({'n': '$n', 'r': '$r'}));
    });
  }

  // ── Compte ────────────────────────────────────────────────────────────
  Widget _account(BuildContext context, ProfileModel? p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionTitle('profile_cat_account'.tr, icon: Icons.person_rounded),
        ProfileGroupCard(children: [
          // v585 (bug 14, Daniel : « où est la section Amis ? ») — en tête
          // du Profil des 3 rôles : Mes amis (amis, demandes, en direct,
          // PawFamily) avec un compteur, puis PawFamily.
          _friendsRow(),
          ProfileRow(
            key: const ValueKey<String>('profile_family_row'),
            icon: PawIcon.home,
            title: 'profile585_family_title'.tr,
            subtitle: 'profile585_family_sub'.tr,
            color: const Color(0xFF7C3AED),
            onTap: () => Get.to(() => const FriendsScreen(initialIndex: 3)),
          ),
          ProfileRow(
            icon: PawIcon.user,
            title: 'profile_edit_profile'.tr,
            subtitle: 'profile_edit_profile_subtitle'.tr,
            color: accent,
            onTap: onEditProfile,
          ),
          ProfileRow(
            icon: PawIcon.mail,
            title: 'change_email_title'.tr,
            subtitle: (p?.email ?? '').isNotEmpty ? p!.email : 'profile_no_email_added'.tr,
            color: accent,
            onTap: () => showChangeEmailSheet(context, accent: accent, currentEmail: p?.email ?? ''),
          ),
          if (_isOwner)
            ProfileRow(
              icon: PawIcon.check,
              title: 'profile_view_tasks'.tr,
              subtitle: 'profile_view_tasks_subtitle'.tr,
              color: AppColors.greenColor,
              onTap: () => Get.to(() => const ViewTaskScreen()),
            ),
          if (_isOwner)
            ProfileRow(
              icon: PawIcon.plus,
              title: 'profile_add_tasks'.tr,
              subtitle: 'profile_add_tasks_subtitle'.tr,
              color: AppColors.greenColor,
              onTap: () => Get.to(() => const AddTaskScreen()),
            ),
          ProfileRow(
            icon: PawIcon.map,
            title: 'profile_pawmap'.tr,
            subtitle: _isOwner ? 'profile_pawmap_subtitle'.tr : 'sitter_pawmap_subtitle'.tr,
            color: _purple,
            onTap: () => openMainTabOr(2, () => const PawMapScreen()),
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
            icon: PawIcon.paw,
            title: 'my_pets_title'.tr,
            subtitle: 'profile_pets_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => const MyPetsScreen()),
          ),
          ProfileRow(
            icon: PawIcon.plus,
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
              icon: PawIcon.calendar,
              title: 'bookings_tab_title'.tr,
              subtitle: 'bookings_tab_subtitle'.tr,
              color: accent,
              onTap: () => openMainTabOr(3, () => const SitterBookingsScreen()),
            ),
          ProfileRow(
            icon: PawIcon.wallet,
            title: 'my_rates_section_title'.tr,
            subtitle: _isSitter ? 'my_rates_sitter_hint'.tr : 'my_rates_walker_hint'.tr,
            color: accent,
            onTap: () => Get.to(() => MyRatesScreen(role: role)),
          ),
          ProfileRow(
            icon: PawIcon.calendar,
            title: 'profile_my_availability'.tr,
            subtitle: 'profile_availability_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => AvailabilityCalendarScreen(role: _isSitter ? null : 'walker')),
          ),
          ProfileRow(
            icon: PawIcon.star,
            title: 'reviews_title'.tr,
            subtitle: 'profile_reviews_subtitle'.tr,
            color: _gold,
            onTap: () => openMyReviews(role: role, accent: accent),
          ),
          ProfileRow(
            icon: PawIcon.shield,
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
              icon: PawIcon.wallet,
              title: 'wallet_menu_title'.tr,
              subtitle: 'wallet_menu_subtitle'.tr,
              color: _blue,
              onTap: () => Get.to(() => const WalletScreen()),
            ),
          if (_isOwner)
            ProfileRow(
              icon: PawIcon.doc,
              title: 'owner_payments_title'.tr == 'owner_payments_title'
                  ? 'owner_payments_fallback'.tr
                  : 'owner_payments_title'.tr,
              subtitle: 'owner_payments_subtitle'.tr,
              color: accent,
              onTap: () => Get.to(() => const OwnerPaymentsScreen()),
            )
          else
            ProfileRow(
              icon: PawIcon.card,
              title: 'payment_management_title'.tr,
              subtitle: 'payment_management_subtitle'.tr,
              color: accent,
              onTap: () => Get.to(() => const PaymentManagementScreen()),
            ),
          ProfileRow(
            icon: PawIcon.card,
            title: 'saved_cards_title'.tr,
            subtitle: 'profile_saved_cards_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => const SavedCardsScreen()),
          ),
          if (!_isOwner)
            ProfileRow(
              icon: PawIcon.key,
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
            icon: PawIcon.gift,
            title: 'promo_screen_title'.tr,
            subtitle: 'promo_profile_tile_subtitle'.tr,
            color: _purple,
            onTap: () => showPromoCodeSheet(context, accent: accent),
            // v573 — audit mode sombre : le violet de marque sert ici de TEXTE
            // sur une pastille posée sur la carte → version `accentOn`.
            trailing: GestureDetector(
              onTap: () => Get.to(() => PromoCodeScreen(accent: accent)),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.accentOn(context, _purple)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: InterText(
                  text: 'promo_popup_cta'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentOn(context, _purple),
                ),
              ),
            ),
          ),
          ProfileRow(
            icon: PawIcon.bag,
            title: 'profile_shop'.tr,
            subtitle: 'profile_shop_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => const CoinShopScreen()),
          ),
          ProfileRow(
            // v585 — icône « cadeau » : l'icône Amis appartient à Mes amis.
            icon: PawIcon.coin,
            title: 'referrals_title'.tr,
            subtitle: 'referrals_subtitle'.tr,
            color: _amber,
            onTap: () => Get.to(() => const MyReferralsScreen()),
          ),
          ProfileRow(
            icon: PawIcon.medal,
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
            icon: PawIcon.gear,
            title: 'prefs_tab_general'.tr,
            subtitle: 'profile_prefs_general_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => ProfilePreferencesScreen(host: host, accent: accent, initialTab: 0)),
          ),
          ProfileRow(
            icon: PawIcon.bell,
            title: 'prefs_tab_notifications'.tr,
            subtitle: 'profile_prefs_notifications_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => ProfilePreferencesScreen(host: host, accent: accent, initialTab: 1)),
          ),
          // v575 — Daniel : « il y a déjà "Langue de l'app", et dans "À propos
          // de moi" il y a "Langue" : ce n'est pas clair ». Cette ligne ouvre
          // bien la LANGUE D'AFFICHAGE : elle porte désormais le même nom
          // qu'ailleurs (« Langue de l'app »), avec le sous-texte qui lève le
          // doute. Les « Langues parlées » vivent dans Modifier le profil.
          ProfileRow(
            icon: PawIcon.globe,
            title: 'pref_app_language'.tr,
            subtitle: 'pref_app_language_sub'.tr,
            color: _blue,
            onTap: host.showLanguageDialog,
          ),
          ProfileRow(
            icon: PawIcon.moon,
            title: 'theme_setting_title'.tr,
            subtitle: 'theme_setting_subtitle'.tr,
            color: _purple,
            onTap: () => showThemeDialog(context),
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
            icon: PawIcon.lock,
            title: 'profile_change_password'.tr,
            subtitle: 'profile_change_password_subtitle'.tr,
            color: accent,
            onTap: host.navigateToChangePassword,
          ),
          ProfileRow(
            icon: PawIcon.shield,
            title: 'profile_cat_security'.tr,
            subtitle: 'profile_security_subtitle'.tr,
            color: accent,
            onTap: () => Get.to(() => ProfileSecurityScreen(host: host, accent: accent)),
          ),
          ProfileRow(
            icon: PawIcon.eyeOff,
            title: 'profile_blocked_users'.tr,
            subtitle: 'profile_blocked_users_subtitle'.tr,
            color: AppColors.errorColor,
            onTap: host.navigateToBlockedUsers,
          ),
          ProfileRow(
            icon: PawIcon.trash,
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
  // v585 (lot D, demandes de Daniel du 25/09) : « Comprendre la PawMap » EN
  // TÊTE (ouvre l'écran d'aide réutilisable du lot C), UNE seule entrée
  // « Une idée ? Un problème ? » (boîte à idées), et « Tester les
  // notifications » GARDÉ mais relégué tout en bas, dans une petite ligne
  // « Dépannage », discrète.
  Widget _help(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionTitle('profile_cat_help'.tr, icon: Icons.help_rounded),
        ProfileGroupCard(children: [
          ProfileRow(
            icon: PawIcon.map,
            title: 'pawmap_help_title'.tr,
            subtitle: 'help_pawmap_sub'.tr,
            color: _purple,
            onTap: () => Get.to(() => const PawMapHelpScreen()),
          ),
          ProfileRow(
            icon: PawIcon.bulb,
            title: 'feedback_title'.tr,
            subtitle: 'feedback_sub'.tr,
            color: _warn,
            onTap: () => Get.to(() => const IdeaBoxScreen()),
          ),
          ProfileRow(
            icon: PawIcon.doc,
            title: 'terms_read_button'.tr,
            subtitle: 'terms_read_subtitle'.tr,
            color: _slate,
            onTap: () => Get.to(() => const TermsAndConditionsScreen()),
          ),
          ProfileRow(
            icon: PawIcon.shield,
            title: 'profile_privacy'.tr,
            subtitle: 'profile_privacy_subtitle'.tr,
            color: _slate,
            onTap: () => Get.to(() => const PrivacyPolicyScreen()),
          ),
        ]),
        // Dépannage : petite ligne discrète, tout en bas.
        Padding(
          padding: EdgeInsets.only(top: 6.h, left: 6.w, right: 6.w),
          child: InkWell(
            key: const ValueKey<String>('help_troubleshoot_row'),
            borderRadius: BorderRadius.circular(12.r),
            onTap: () => Get.to(() => const NotificationTestScreen()),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
              child: Row(
                children: [
                  PawIconWidget(PawIcon.bell,
                      size: 14.sp, color: AppColors.textSecondary(context)),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: InterText(
                      text: '${'help_troubleshoot'.tr} · ${'notif_test_title'.tr}',
                      fontSize: 11.5.sp,
                      color: AppColors.textSecondary(context),
                      maxLines: 2,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 16.sp, color: AppColors.textSecondary(context)),
                ],
              ),
            ),
          ),
        ),
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
