import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:hopetsit/widgets/paw_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hopetsit/widgets/paw_card_icons.dart';
import 'package:hopetsit/widgets/promo_code_sheet.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/subscription_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/services/airwallex_payment_service.dart';
// v503 — règle Apple 3.1.1 : sur iOS les abonnements/boosts s'achètent via
// StoreKit (achat intégré Apple) au lieu du flux carte Airwallex.
import 'package:hopetsit/services/apple_iap_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/post_purchase_refresh.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/boost/pawspot_leaderboard_screen.dart';
import 'package:hopetsit/views/boost/widgets/shop_ui_kit.dart';
// v488 — légende des types de spots déplacée de la PawMap vers cet onglet.
import 'package:hopetsit/controllers/pawspot_controller.dart' show PawSpotTypes;
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/golden_paw_coin.dart';
// v504 — refus 3.1.2(c) : liens CGU (EULA) + confidentialité dans la boutique.
import 'package:url_launcher/url_launcher.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

/// v491 — VRAI logo « membre Paw Map proche » : cercle rose dégradé + patte
/// blanche (réplique du badge de la carte). Fonction TOP-LEVEL → partagée par
/// l'onglet PawSpot et l'onglet Paw Premium (classes State distinctes).
Widget _pawBadgeMini() {
  return Container(
    width: 24,
    height: 24,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF06AA0), Color(0xFFE0568B)],
      ),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Color(0x55E0568B),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    alignment: Alignment.center,
    child: const Icon(Icons.pets_rounded, color: Colors.white, size: 13),
  );
}

/// v566 — message d'erreur LISIBLE et traduit pour un achat boutique.
/// Avant : `e.toString()` brut → « Exception: Failed to create payment
/// intent. » (anglais, préfixe technique) ou une page HTML d'erreur.
String _shopErrorText(Object e) {
  var msg = e is ApiException ? e.message : e.toString();
  msg = msg.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  if (msg.isEmpty ||
      msg.contains('<!DOCTYPE') ||
      msg.contains('<html') ||
      msg.contains('404')) {
    return 'boost_service_unavailable'.tr;
  }
  return msg;
}

/// v444 — réduction promo « % » appliquée à l'affichage des prix de la boutique.
///
/// Le flux code promo (PromoController) persiste, après consommation d'un code
/// de type `percent_discount`, un JSON `{code, discountPercent, plan}` dans
/// GetStorage sous [StorageKeys.redeemedPromoDiscount]. Ici on le RELIT et on
/// l'applique à l'AFFICHAGE des forfaits correspondants (prix barré + prix
/// réduit + note « code promo -X% »).
///
/// IMPORTANT : c'est purement de l'AFFICHAGE. Le montant réellement débité par
/// Airwallex reste calculé côté serveur (les contrôleurs d'achat ne sont pas
/// modifiés ici) — appliquer la réduction au montant facturé exigerait un
/// changement backend + SubscriptionController hors de ce périmètre.
class _PromoDiscount {
  const _PromoDiscount({
    required this.code,
    required this.percent,
    required this.plan,
  });

  final String code;
  final int percent;
  final String plan; // valeur canonique admin (cf promo_code_screen._planLabel)

  bool get isUsable => percent > 0 && percent < 100;

  /// Relit la réduction persistée. Renvoie `null` si absente / invalide.
  /// v506 — refus Apple 3.1.1 : les réductions promo maison ne s'appliquent
  /// JAMAIS sur iOS (facturation Apple) → aucun affichage promo en boutique.
  static _PromoDiscount? read() {
    if (Platform.isIOS) return null;
    try {
      final raw = GetStorage().read(StorageKeys.redeemedPromoDiscount);
      if (raw == null) return null;
      final map = raw is String ? jsonDecode(raw) : raw;
      if (map is! Map) return null;
      final percent = (map['discountPercent'] as num?)?.toInt() ?? 0;
      final d = _PromoDiscount(
        code: (map['code'] ?? '').toString(),
        percent: percent,
        plan: (map['plan'] ?? '').toString().toLowerCase(),
      );
      return d.isUsable ? d : null;
    } catch (_) {
      return null;
    }
  }

  /// Le code s'applique-t-il au forfait boutique [boutiquePlan] ?
  ///
  /// Mappe les valeurs canoniques admin vers les identifiants de plan utilisés
  /// dans la boutique. Un `plan` vide = code générique → s'applique à tous les
  /// abonnements (mais jamais au PawBoost ponctuel).
  bool appliesTo(String boutiquePlan) {
    final p = boutiquePlan.toLowerCase();
    if (plan.isEmpty || plan == 'all' || plan == 'subscription') return true;
    switch (plan) {
      case 'premium':
        return p == 'premium_monthly' || p == 'premium_yearly';
      case 'pawfollow':
        return p == 'monthly' || p == 'yearly';
      case 'pawfamily':
      case 'famille':
        return p == 'family' || p == 'famille' || p == 'family_yearly';
      case 'pawspot':
        return p == 'pawspot';
      default:
        // Sinon : correspondance exacte (premium_monthly, family_yearly…).
        return plan == p;
    }
  }

  /// Prix réduit (arrondi à 2 décimales).
  double discounted(double original) =>
      (original * (100 - percent) / 100 * 100).round() / 100;
}

/// v444 — petite étiquette « 🎟️ code promo -X% » affichée sous un prix réduit.
/// [accent] colore le ruban (couleur du forfait : violet PawFollow, doré
/// PawSpot/Premium…).
class _PromoBadge extends StatelessWidget {
  const _PromoBadge({required this.percent, required this.accent});

  final int percent;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: InterText(
        text: 'shop_promo_discount_note'.trParams({'percent': '$percent'}),
        fontSize: 9.sp,
        fontWeight: FontWeight.w700,
        color: accent,
        maxLines: 1,
      ),
    );
  }
}

/// Boutique screen — 4 tabs:
///   1. PawBoost    — one-time profile boost (renommé v23.1.387, Daniel)
///   2. PawFollow   — PawFollow / PawFamily subscription
///   3. PawSpot     — community subscription (tag pet-friendly spots on the
///                    PawMap, PawPoints + badges, leaderboards, rewards)
///   4. Paw Premium — bundle PawFollow + PawSpot + exclusifs (v23.1.387) :
///                    badge Premium, points ×2, priorité nouveautés.
///                    -33% vs les deux abonnements séparés.
///
/// Available for the 3 roles: Owner, Sitter, Walker.
class CoinShopScreen extends StatefulWidget {
  const CoinShopScreen({super.key, this.initialTab = 0});

  /// Index of the tab to show first. 0 = PawBoost (default), 1 = PawFollow,
  /// 2 = PawSpot, 3 = Paw Premium. Used by the PawMap "Passer Premium"
  /// banner to land directly on the right offer.
  final int initialTab;

  @override
  State<CoinShopScreen> createState() => _CoinShopScreenState();
}

class _CoinShopScreenState extends State<CoinShopScreen> {
  // v565 (point 27) — incrémenté après un code promo appliqué : recrée les
  // onglets pour relire la réduction persistée (redeemedPromoDiscount).
  int _promoEpoch = 0;
  // v503 — spinner du bouton « Restaurer mes achats » (iOS uniquement).
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    // v503 — précharge les produits StoreKit (prix localisés Apple) dès
    // l'ouverture de la boutique. No-op sur Android.
    AppleIapService.init();
  }

  /// v569 — « J'ai un code » vit désormais dans le bloc « Aide & infos » en bas
  /// de CHAQUE onglet (au lieu d'un bouton isolé dans la barre du haut). La
  /// feuille consomme le code puis écrit StorageKeys.redeemedPromoDiscount ;
  /// on relance le build des onglets (clé) pour que _PromoDiscount.read()
  /// s'applique aux prix.
  Future<void> _openPromoSheet() async {
    final ok =
        await showPromoCodeSheet(context, accent: AppColors.primaryColor);
    if (ok && mounted) setState(() => _promoEpoch++);
  }

  /// Bouton « Restaurer mes achats » — OBLIGATOIRE Apple. Les transactions
  /// restaurées repassent par /apple-iap/validate (idempotent).
  Future<void> _restorePurchases() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    try {
      await AppleIapService.restorePurchases();
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'iap_restore_done'.tr,
      );
    } catch (e) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: _shopErrorText(e));
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  /// v504 — lien légal du pied de boutique (CGU / confidentialité).
  Widget _legalLink(String label, String url) {
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: AppColors.textSecondary(context),
            decoration: TextDecoration.underline,
            decorationColor: AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }

  /// v561 — cartes d'onglet de la boutique (handoff « Paw Buttons » de
  /// Daniel, 12/09) : verre dépoli, dégradé 165°, bord blanc translucide,
  /// reflet haut, ombre colorée, disque blanc 56 px avec icône 26 px pleine
  /// dans la teinte de la carte, titre 13/800, description 9,5/700 sur 2
  /// lignes. Design uniquement : les onglets gardent leurs actions.
  Widget _shopCardTab({
    required int index,
    required List<Color> colors,
    required Color shadow,
    required String svg,
    required String title,
    required String subtitle,
    Color titleColor = Colors.white,
  }) {
    return Tab(
      height: 150.h,
      child: Builder(builder: (context) {
        final ctl = DefaultTabController.of(context);
        return AnimatedBuilder(
          animation: ctl.animation ?? ctl,
          builder: (context, _) {
            final active = ctl.index == index;
            return AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              scale: active ? 1.0 : 0.96,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: active ? 1.0 : 0.9,
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: const Alignment(-0.6, -1),
                      end: const Alignment(0.6, 1),
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: shadow.withValues(alpha: active ? 0.6 : 0.35),
                        blurRadius: active ? 26 : 18,
                        spreadRadius: -12,
                        offset: Offset(0, active ? 14 : 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Reflet haut (45 %) + liseré intérieur blanc.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: 150.h * 0.45,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.22),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: 1,
                        child: ColoredBox(color: Colors.white.withValues(alpha: 0.55)),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(4.w, 14.h, 4.w, 12.h),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    spreadRadius: -6,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: SvgPicture.string(svg, width: 26, height: 26),
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.26,
                                color: titleColor,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              subtitle,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ensure SubscriptionController is available.
    if (!Get.isRegistered<SubscriptionController>()) {
      Get.put(SubscriptionController());
    }

    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTab.clamp(0, 3),
      child: Scaffold(
        backgroundColor: AppColors.scaffold(context),
        appBar: AppBar(
          backgroundColor: AppColors.appBar(context),
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: [
              PawIconWidget(PawIcon.bag, size: 24.sp, color: AppColors.primaryColor),
              SizedBox(width: 8.w),
              Flexible(
                child: InterText(
                  text: 'boost_shop_title'.tr,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // v569 — la barre du haut ne porte plus que le titre : « J'ai un
          // code » a rejoint le bloc « Aide & infos » en bas de chaque onglet
          // (avec « Gérer mon abonnement », la devise, « Restaurer mes
          // achats » et les liens légaux), au lieu d'être dispersé.
          // v561 — Daniel (maquette 12/09) : onglets = 4 CARTES colorées
          // (PawBoost orange, PawFollow violet, PawSpot or, PawPremium noir)
          // avec logo, nom et sous-titre ; la carte active est plus vive.
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(150.h + 18.h),
            child: Container(
              margin: EdgeInsets.fromLTRB(10.w, 4.h, 10.w, 10.h),
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                // Le beige clair entoure les 4 cartes (6 px de marge) : en mode
                // sombre il formait un cadre éblouissant sur le fond #121212.
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.cardDark
                    : const Color(0xFFF1E9E2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TabBar(
                indicator: const BoxDecoration(),
                indicatorColor: Colors.transparent,
                dividerColor: Colors.transparent,
                labelPadding: EdgeInsets.symmetric(horizontal: 4.w),
                padding: EdgeInsets.zero,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: [
                  _shopCardTab(
                    index: 0,
                    colors: const [Color(0xFFFF6B4A), Color(0xFFE0361F)],
                    shadow: const Color(0xFFE0361F),
                    svg: PawCardIcons.boost,
                    title: 'shop_tab_boost'.tr,
                    subtitle: 'shop_card_boost_sub'.tr,
                  ),
                  _shopCardTab(
                    index: 1,
                    colors: const [Color(0xFF9B6BFF), Color(0xFF6A34E0)],
                    shadow: const Color(0xFF6A34E0),
                    svg: PawCardIcons.follow,
                    title: 'shop_tab_pawpass'.tr,
                    subtitle: 'shop_card_follow_sub'.tr,
                  ),
                  _shopCardTab(
                    index: 2,
                    colors: const [Color(0xFFFFC23D), Color(0xFFF0900A)],
                    shadow: const Color(0xFFF0900A),
                    svg: PawCardIcons.spot,
                    title: 'shop_tab_pawspot'.tr,
                    subtitle: 'shop_card_spot_sub'.tr,
                  ),
                  _shopCardTab(
                    index: 3,
                    colors: const [Color(0xFF3A3028), Color(0xFF0E0A09)],
                    shadow: Colors.black,
                    svg: PawCardIcons.premium,
                    title: 'shop_tab_premium'.tr,
                    subtitle: 'shop_card_premium_sub'.tr,
                    titleColor: const Color(0xFFFFD34D),
                  ),
                ],
              ),
            ),
          ),
        ),
        // v567 — sur iOS, la rangée « Restaurer · CGU · Confidentialité »
        // (bottomNavigationBar ci-dessous) porte DÉJÀ le SafeArea du home
        // indicator. On retire donc le dégagement bas du corps, sinon la barre
        // d'achat collante de chaque onglet réservait 34 px de plus et laissait
        // une bande vide. Sur Android il n'y a pas de bottomNavigationBar : le
        // corps garde son inset, que shopBottomInset() corrige à 48 px quand le
        // système ment à 0 (Samsung edge-to-edge).
        body: PawPatternBackground(
          color: AppColors.activeRoleAccent(),
          child: Builder(
          builder: (ctx) {
            final body = TabBarView(
              key: ValueKey<int>(_promoEpoch),
              children: [
                _BoostTab(
                  onPromo: _openPromoSheet,
                  onRestore: _restorePurchases,
                  restoring: _restoring,
                ),
                _PremiumTab(
                  onPromo: _openPromoSheet,
                  onRestore: _restorePurchases,
                  restoring: _restoring,
                ),
                _PawSpotTab(
                  onPromo: _openPromoSheet,
                  onRestore: _restorePurchases,
                  restoring: _restoring,
                ),
                _PawPremiumTab(
                  onPromo: _openPromoSheet,
                  onRestore: _restorePurchases,
                  restoring: _restoring,
                ),
              ],
            );
            if (!Platform.isIOS) return body;
            // removeViewPadding met padding.bottom ET viewPadding.bottom à 0 :
            // shopBottomInset() renvoie alors 0 sur iOS (jamais +48, c'est
            // réservé à Android).
            return MediaQuery.removeViewPadding(
              context: ctx,
              removeBottom: true,
              child: body,
            );
          },
        ),
        ),
        // v503 — bouton « Restaurer mes achats » en bas de la boutique,
        // iOS uniquement (exigence Apple pour les achats intégrés).
        // v504 — refus 3.1.2(c) : + liens CGU (EULA) et Politique de
        // confidentialité, exigés dans le flux d'achat des abonnements.
        bottomNavigationBar: !Platform.isIOS
            ? null
            : SafeArea(
                top: false,
                // v566 — une seule rangée compacte (le bouton d'achat collant
                // de chaque onglet est juste au-dessus) : Restaurer · CGU ·
                // Confidentialité. Wrap = pas de débordement en de / pt.
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 2.h, 10.w, 4.h),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6.w,
                    children: [
                      InkWell(
                        onTap: _restoring ? null : _restorePurchases,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 4.w, vertical: 4.h),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _restoring
                                  ? SizedBox(
                                      width: 12.w,
                                      height: 12.w,
                                      child: const CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Icon(Icons.restore_rounded,
                                      size: 14.sp,
                                      color: AppColors.primaryColor),
                              SizedBox(width: 4.w),
                              Text(
                                'iap_restore_button'.tr,
                                style: TextStyle(
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _legalLink('iap_terms_link'.tr, kShopTermsUrl),
                      _legalLink('iap_privacy_link'.tr, kShopPrivacyUrl),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 1 — BOOST (existing boost packages)
// ═══════════════════════════════════════════════════════════════════════════
class _BoostTab extends StatefulWidget {
  const _BoostTab({
    required this.onPromo,
    required this.onRestore,
    required this.restoring,
  });

  /// v569 — lignes du bloc « Aide & infos » (pilotées par l'écran parent).
  final VoidCallback onPromo;
  final VoidCallback onRestore;
  final bool restoring;

  @override
  State<_BoostTab> createState() => _BoostTabState();
}

class _BoostTabState extends State<_BoostTab> with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  bool _purchasing = false;
  String? _selectedTier;
  // v566 — offre CHOISIE (tap = sélection, l'achat part du bouton collant).
  // Par défaut le palier « populaire » ; sur iOS le palier gold n'a pas de
  // produit Apple → silver.
  String _pickedTier = Platform.isIOS ? 'silver' : 'gold';
  Worker? _currencyWorker;

  bool _boostActive = false;
  String? _currentTier;
  int _remainingDays = 0;
  List<dynamic> _history = [];

  /// Dégradé PawBoost (handoff « Paw Buttons »).
  static const List<Color> _boostGradient = [
    Color(0xFFFF6B4A),
    Color(0xFFE0361F),
  ];

  // Session v3.2 — packages used to be hardcoded (25/50/100/200 €), which
  // meant admin price edits on /admin/pricing never showed up in the app.
  // Now we fetch /boost/packages live and fall back to the static list
  // only if the backend fails.
  // v18.9.8 — on ne stocke plus un `label` EN hardcodé ('3 days' / '1 week'
  // etc.). On calcule le libellé à l'affichage via _durationLabel(days) avec
  // la locale active → plus jamais de "pendant 3 days" côté FR.
  static const List<Map<String, dynamic>> _fallbackPackages = [
    // v23.1.393 — baisse PawBoost (Daniel) : -20%, alignée backend.
    {'tier': 'bronze',   'amount': 3.99,  'days': 3,  'icon': '🥉', 'color': Color(0xFFCD7F32)},
    {'tier': 'silver',   'amount': 7.99,  'days': 7,  'icon': '🥈', 'color': Color(0xFFC9BBB7)},
    {'tier': 'gold',     'amount': 11.99, 'days': 15, 'icon': '🥇', 'color': Color(0xFFFFD700)},
    {'tier': 'platinum', 'amount': 19.99, 'days': 30, 'icon': '💎', 'color': Color(0xFFEBDFDC)},
  ];

  /// v18.9.8 — libellé de durée localisé. Remplace les labels EN hardcodés
  /// stockés côté fallback/backend. Regle les cas 7j→"1 semaine",
  /// 14/21j→"2/3 semaines", 30j→"1 mois", sinon "X jours".
  String _durationLabel(int days) {
    if (days <= 0) return '';
    if (days == 30) return 'boost_duration_one_month'.tr;
    if (days == 7) return 'boost_duration_one_week'.tr;
    if (days % 7 == 0 && days > 7 && days < 30) {
      return 'boost_duration_weeks'
          .tr
          .replaceAll('@count', (days ~/ 7).toString());
    }
    return 'boost_duration_days'.tr.replaceAll('@count', days.toString());
  }
  List<Map<String, dynamic>> _packages = List.of(_fallbackPackages);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadBoostStatus();
    _loadBoostPackages();
    // v566 — l'onglet est gardé en vie (KeepAlive) : sans ce worker, changer
    // de devise dans l'onglet PawFollow laissait ici les anciens prix alors
    // que /boost/purchase facturait dans la nouvelle devise.
    if (Get.isRegistered<SubscriptionController>()) {
      _currencyWorker = ever<String>(
        Get.find<SubscriptionController>().currency,
        (_) => _loadBoostPackages(),
      );
    }
  }

  @override
  void dispose() {
    _currencyWorker?.dispose();
    super.dispose();
  }

  /// v566 — nom traduit du palier (avant : « Bronze/Silver/Gold/Platinum »
  /// fabriqué en dur à partir de l'identifiant serveur).
  String _tierName(String tier) {
    switch (tier) {
      case 'bronze':
        return 'v566_shop_tier_bronze'.tr;
      case 'silver':
        return 'v566_shop_tier_silver'.tr;
      case 'gold':
        return 'v566_shop_tier_gold'.tr;
      case 'platinum':
        return 'v566_shop_tier_platinum'.tr;
      default:
        return tier;
    }
  }

  /// v566 — prix affiché d'un palier : prix Apple localisé sur iOS, sinon
  /// montant serveur dans SA devise (avant : symbole de la devise du
  /// sélecteur + montant brut « €3.99 », faux tant que les prix n'étaient pas
  /// rechargés).
  String _tierPriceLabel(Map<String, dynamic> pkg) {
    final tier = (pkg['tier'] ?? '').toString();
    final applePrice = Platform.isIOS
        ? AppleIapService.priceLabel(AppleIapService.productForBoostTier(tier))
        : null;
    if (applePrice != null) return applePrice;
    final amount = ((pkg['amount'] as num?) ?? 0).toDouble();
    return CurrencyHelper.format((pkg['currency'] ?? 'EUR').toString(), amount);
  }

  /// Pulls the live boost pricing from the backend (admin-editable). The
  /// currency follows the Premium tab's SubscriptionController so all three
  /// tabs stay aligned.
  Future<void> _loadBoostPackages() async {
    try {
      final api = Get.find<ApiClient>();
      final currency = Get.isRegistered<SubscriptionController>()
          ? Get.find<SubscriptionController>().currency.value
          : 'EUR';
      final data = await api.get(
        '/boost/packages',
        queryParameters: {'currency': currency},
      ) as Map<String, dynamic>;
      final list = (data['packages'] as List?) ?? const [];
      // Preserve the visual metadata (icon / color / label) from the
      // fallback list — the backend only sends the pricing side.
      final merged = _fallbackPackages.map((fb) {
        final match = list.firstWhere(
          (p) => p is Map && p['tier'] == fb['tier'],
          orElse: () => const <String, dynamic>{},
        );
        if (match is Map && match.isNotEmpty) {
          return {
            ...fb,
            'amount': (match['amount'] as num?)?.toDouble() ?? fb['amount'],
            'days': (match['days'] as num?)?.toInt() ?? fb['days'],
            'currency': match['currency'] ?? 'EUR',
          };
        }
        return fb;
      }).toList();
      if (!mounted) return;
      setState(() => _packages = merged);
    } catch (e) {
      // Leave _packages as fallback if the call fails.
    }
  }

  Future<void> _loadBoostStatus() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get('/boost/status', requiresAuth: true);
      final map = data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _boostActive = map['isActive'] == true;
        _currentTier = map['tier'] as String?;
        // Backend returns this as num (can be double or int) — coerce safely.
        _remainingDays = (map['remainingDays'] as num?)?.toInt() ?? 0;
        _history = map['purchaseHistory'] as List<dynamic>? ?? [];
      });
    } catch (_) {
      // No boost yet
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// v23.1 part 84 — long-press shortcut on a tier card : confirm dialog
  /// then call _purchaseBoost(tier, payWithWallet: true). Only relevant
  /// for walker/sitter (owners get 402 from backend). Caller doesn't
  /// have to know about wallet — backend rejects with INSUFFICIENT_BALANCE
  /// and we fall back to a clear message.
  Future<void> _confirmPayWithWallet(String tier) async {
    // v503 — iOS : pas de paiement wallet pour un bien numérique (règle
    // Apple 3.1.1) → le long-press se comporte comme un tap (achat intégré).
    if (Platform.isIOS) {
      await _purchaseBoost(tier);
      return;
    }
    final pkg = _packages.firstWhere(
      (p) => p['tier'] == tier,
      orElse: () => const <String, dynamic>{},
    );
    if (pkg.isEmpty || !mounted) return;
    final ok = await showShopConfirmSheet(
      context,
      productName: 'shop_tab_boost'.tr,
      planLabel: _tierName(tier),
      priceLabel: _tierPriceLabel(pkg),
      durationLabel: _durationLabel(((pkg['days'] as num?) ?? 0).toInt()),
      colors: const [Color(0xFFFF6B4A), Color(0xFFE0361F)],
      icon: SvgPicture.string(PawCardIcons.boost, width: 20, height: 20),
      method: ShopPayMethod.wallet,
      oneTime: true,
    );
    if (ok == true) {
      await _purchaseBoost(tier, payWithWallet: true);
    }
  }

  Future<void> _purchaseBoost(String tier, {bool payWithWallet = false}) async {
    // v23.1 part 120 — Daniel : "qd on va pour acheter mais on met retour
    // sa met paw spot activer alors que c pas payer". Le backend active
    // automatiquement les users staff (isStaff=true) dès l'appel POST
    // /boost/purchase, sans confirmation. Donc Daniel active sans le
    // vouloir chaque fois qu'il tape un tier. On force un dialog avant.
    if (!payWithWallet) {
      final pkg = _packages.firstWhereOrNull((p) => p['tier'] == tier);
      if (pkg == null || !mounted) return;
      final confirmed = await showShopConfirmSheet(
        context,
        productName: 'shop_tab_boost'.tr,
        planLabel: _tierName(tier),
        priceLabel: _tierPriceLabel(pkg),
        durationLabel: _durationLabel(((pkg['days'] as num?) ?? 0).toInt()),
        colors: const [Color(0xFFFF6B4A), Color(0xFFE0361F)],
        icon: SvgPicture.string(PawCardIcons.boost, width: 20, height: 20),
        method:
            Platform.isIOS ? ShopPayMethod.appleIap : ShopPayMethod.card,
        oneTime: true,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _purchasing = true;
      _selectedTier = tier;
    });

    // v503 — iOS : achat intégré Apple (règle 3.1.1). La validation +
    // le crédit du boost se font via /apple-iap/validate dans le service.
    if (Platform.isIOS) {
      try {
        final productId = AppleIapService.productForBoostTier(tier);
        if (productId == null) {
          throw Exception('iap_unavailable_msg'.tr);
        }
        final ok = await AppleIapService.buy(productId);
        if (!mounted) return;
        if (ok) {
          CustomSnackbar.showSuccess(
            title: 'boost_purchase_success_title'.tr,
            message: 'boost_purchase_success_msg'.tr,
          );
          await _loadBoostStatus();
        }
        // annulation/échec → silencieux (la feuille Apple a déjà informé).
      } catch (e) {
        CustomSnackbar.showError(title: 'common_error'.tr, message: _shopErrorText(e));
      } finally {
        if (mounted) {
          setState(() {
            _purchasing = false;
            _selectedTier = null;
          });
        }
      }
      return;
    }

    try {
      final api = Get.find<ApiClient>();

      // Use the same currency picker as the Premium tab.
      final currency = Get.isRegistered<SubscriptionController>()
          ? Get.find<SubscriptionController>().currency.value
          : 'EUR';
      final piData = await api.post(
        '/boost/purchase',
        // v23.1 part 84 — Daniel : "soit il l'utilise pour la boutique
        // soit il le retire". When payWithWallet=true the backend debits
        // the walker / sitter's wallet and activates immediately —
        // skipping the Airwallex HPP entirely.
        body: {'tier': tier, 'currency': currency, 'payWithWallet': payWithWallet},
        requiresAuth: true,
      );
      final map = piData as Map<String, dynamic>;

      // v20.0.2 — Staff short-circuit: server already activated the boost
      // for free. Skip the payment sheet entirely.
      // v23.1 part 84 — same shortcut when paid from wallet.
      if ((map['staff'] == true && map['activated'] == true) ||
          (map['paidFromWallet'] == true && map['activated'] == true)) {
        CustomSnackbar.showSuccess(
          title: 'boost_purchase_success_title'.tr,
          message: payWithWallet
              ? 'coin_shop_boost_wallet_success'.tr
              : 'boost_purchase_success_msg'.tr,
        );
        await _loadBoostStatus();
        // v23.1 part 109 — refresh aussi les screens profile/map.
        await refreshAfterPurchase();
        // v566 — le `finally` remet déjà les drapeaux (avec garde `mounted`).
        return;
      }

      final clientSecret = map['clientSecret'] as String?;
      final paymentIntentId = map['paymentIntentId'] as String?;

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('boost_purchase_error'.tr);
      }

      final pkgMap = _packages.firstWhere(
        (p) => p['tier'] == tier,
        orElse: () => const <String, dynamic>{},
      );
      // v566 — montant RÉEL du PaymentIntent renvoyé par le serveur (repli :
      // prix affiché), pour que la feuille Airwallex annonce le bon montant.
      final displayAmount = (map['amount'] as num?)?.toDouble() ??
          ((pkgMap['amount'] as num?) ?? 0).toDouble();

      // v21.1.1 — Stripe purgé. Pure Airwallex.
      AppLogger.logInfo('[boost] AIRWALLEX flow ($displayAmount $currency)');
      final result = await AirwallexPaymentService.confirmPaymentIntent(
        intentId: paymentIntentId ?? '',
        clientSecret: clientSecret,
        amount: displayAmount,
        currency: currency,
        // v568 — client Airwallex : la page propose la carte enregistrée.
        customerId: (map['customerId'] as String?)?.trim().isEmpty ?? true
            ? null
            : map['customerId'] as String?,
      );
      // v566 — avant : `if (!mounted) { setState(...) }` → setState sur un
      // State démonté = exception « setState() called after dispose() ». On
      // confirme quand même l'achat côté serveur (le paiement est passé).
      if (result.isSuccess) {
        await api.post(
          '/boost/confirm',
          body: {
            'tier': tier,
            'paymentIntentId': paymentIntentId,
            'currency': currency,
          },
          requiresAuth: true,
        );
        CustomSnackbar.showSuccess(
          title: 'boost_purchase_success_title'.tr,
          message: 'boost_purchase_success_msg'.tr,
        );
        await _loadBoostStatus();
        // v23.1 part 109 — refresh profile + map après achat.
        await refreshAfterPurchase();
      } else if (result.outcome == AirwallexPaymentOutcome.failed) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: result.errorMessage ?? 'boost_purchase_error'.tr,
        );
      }
    } catch (e) {
      CustomSnackbar.showError(
          title: 'common_error'.tr, message: _shopErrorText(e));
    } finally {
      if (mounted) {
        setState(() {
          _purchasing = false;
          _selectedTier = null;
        });
      }
    }
  }

  /// v566 — paliers achetables sur CETTE plateforme (iOS : seuls ceux câblés
  /// à un produit Apple — bronze / silver / platinum ; gold masqué).
  List<Map<String, dynamic>> get _visiblePackages => _packages
      .where((p) =>
          !Platform.isIOS ||
          AppleIapService.productForBoostTier(p['tier'] as String) != null)
      .toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // v569 — squelette animé (shimmer maison) au lieu d'un rond de progression.
    if (_loading) {
      return const ShopSkeleton(tiles: 4);
    }
    final visible = _visiblePackages;
    final picked = visible.firstWhereOrNull((p) => p['tier'] == _pickedTier) ??
        (visible.isNotEmpty ? visible.first : null);
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([_loadBoostStatus(), _loadBoostPackages()]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              // v567 — la dernière carte ne doit jamais finir sous la barre
              // d'achat collante ni sous la barre système Samsung.
              padding: EdgeInsets.fromLTRB(
                  16.w, 16.h, 16.w, shopScrollBottomPadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Hero produit (état intégré en bas à gauche) ────────
                  ShopHero(
                    icon: SvgPicture.string(PawCardIcons.boost,
                        width: 28, height: 28),
                    title: 'shop_tab_boost'.tr,
                    subtitle: 'shop_card_boost_sub'.tr,
                    colors: _boostGradient,
                    status: ShopStatusPill(
                      label: 'shop_tab_boost'.tr,
                      active: _boostActive,
                      accent: Colors.white,
                      days: _remainingDays,
                      onDark: true,
                    ),
                  ),
                  if (_boostActive && _currentTier != null) ...[
                    SizedBox(height: 12.h),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ShopPill(
                        label: _tierName(_currentTier!),
                        background: AppColors.primaryColor,
                      ),
                    ),
                  ],
                  if (!_boostActive) ...[
                    SizedBox(height: 10.h),
                    InterText(
                      text: 'boost_inactive_hint'.tr,
                      fontSize: 12.sp,
                      color: AppColors.textSecondary(context),
                      maxLines: 2,
                    ),
                  ],
                  if (_boostActive &&
                      ShopExpiryNotice.shouldShow(_remainingDays)) ...[
                    SizedBox(height: 12.h),
                    ShopExpiryNotice(days: _remainingDays),
                  ],
                  SizedBox(height: 24.h),
                  // ── 2. Avantages ─────────────────────────────────────────
                  ShopSectionTitle(title: 'shop569_benefits_title'.tr),
                  SizedBox(height: 12.h),
                  ShopBenefitList(
                    accent: AppColors.primaryColor,
                    items: [
                      ShopBenefit(
                        icon: Icons.vertical_align_top_rounded,
                        title: 'shop569_boost_b1_title'.tr,
                        body: 'boost_step_3'.tr,
                      ),
                      ShopBenefit(
                        icon: Icons.visibility_rounded,
                        title: 'shop569_boost_b2_title'.tr,
                        body: 'boost_step_4'.tr,
                      ),
                      ShopBenefit(
                        icon: Icons.schedule_rounded,
                        title: 'shop569_boost_b3_title'.tr,
                        body: 'boost_step_1'.tr,
                      ),
                      ShopBenefit(
                        icon: Icons.local_fire_department_rounded,
                        title: 'shop569_boost_b4_title'.tr,
                        body: 'shop_pb_plus_body'.tr,
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  // ── 3. Gratuit vs payant ─────────────────────────────────
                  ShopSectionTitle(title: 'shop569_compare_title'.tr),
                  SizedBox(height: 12.h),
                  shopValueCard(
                    context,
                    color: const Color(0xFFC92A12),
                    freeTitle: 'shop_pb_free_title'.tr,
                    freeBody: 'shop_pb_free_body'.tr,
                    plusTitle: 'shop_pb_plus_title'.tr,
                    plusBody: 'shop_pb_plus_body'.tr,
                  ),
                  SizedBox(height: 24.h),
                  // ── 4. Forfaits ──────────────────────────────────────────
                  ShopSectionTitle(
                    title: 'boost_choose_package'.tr,
                    subtitle: 'boost_choose_subtitle'.tr,
                  ),
                  SizedBox(height: 16.h),
                  ...visible.map((p) => _buildPackageCard(context, p)),
                  if (!Platform.isIOS) ...[
                    SizedBox(height: 2.h),
                    InterText(
                      text: 'v566_shop_wallet_hint'.tr,
                      fontSize: 11.sp,
                      color: AppColors.textSecondary(context),
                      maxLines: 2,
                    ),
                  ],
                  SizedBox(height: 20.h),
                  // ── 5. Rangée de confiance ───────────────────────────────
                  ShopTrustRow(
                      accent: AppColors.primaryColor, oneTime: true),
                  // v569 — l'ancienne carte « Comment ça marche ? » disait
                  // exactement les 4 mêmes phrases (boost_step_1…4) que le
                  // bloc « Avantages » ci-dessus : le doublon est supprimé,
                  // aucun texte n'est perdu.
                  if (_history.isNotEmpty) ...[
                    SizedBox(height: 24.h),
                    _buildPurchaseHistory(),
                  ],
                  SizedBox(height: 24.h),
                  // ── 6. Aide & infos (+ mentions légales, CGU, privacy) ───
                  shopHelpCard(
                    context,
                    accent: AppColors.primaryColor,
                    oneTime: true,
                    showManage: false,
                    onPromo: widget.onPromo,
                    onRestore: widget.onRestore,
                    restoring: widget.restoring,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (picked != null)
          ShopStickyBar(
            title:
                '${'shop_tab_boost'.tr} · ${_tierName(picked['tier'] as String)}',
            priceLabel: _tierPriceLabel(picked),
            subLabel: _durationLabel(((picked['days'] as num?) ?? 0).toInt()),
            buttonLabel: _boostActive
                ? 'v566_shop_cta_extend'.tr
                : 'v566_shop_cta_boost'.tr,
            colors: _boostGradient,
            loading: _purchasing,
            onPressed: _purchasing
                ? null
                : () => _purchaseBoost(picked['tier'] as String),
          ),
      ],
    );
  }

  /// v569 — tuile de forfait commune aux 4 onglets ([ShopPlanTile]) : prix en
  /// gros, prix par jour en petit, ruban « Le plus choisi » sur le palier mis
  /// en avant, sélection = bord 2 px + coche animée. Tap = SÉLECTION (l'achat
  /// part du bouton collant), appui long = payer avec le portefeuille.
  /// v585 (lot D) — icône maison du palier (plus d'emoji de médaille).
  PawIcon _tierIcon(String tier) {
    switch (tier) {
      case 'platinum':
        return PawIcon.diamond;
      case 'gold':
        return PawIcon.crown;
      case 'silver':
        return PawIcon.medal;
      default:
        return PawIcon.rocket;
    }
  }

  Widget _buildPackageCard(BuildContext context, Map<String, dynamic> pkg) {
    final tier = pkg['tier'] as String;
    // Backend can return amount as double (e.g. 4.99) or int — coerce via num.
    final amount = ((pkg['amount'] as num?) ?? 0).toDouble();
    final days = ((pkg['days'] as num?) ?? 0).toInt();
    // v18.9.8 — label localisé via _durationLabel(days), plus de label EN.
    final label = _durationLabel(days);
    final isBuying = _selectedTier == tier && _purchasing;
    final isPicked = _pickedTier == tier;
    // iOS : gold n'existe pas → le palier mis en avant est silver.
    final isPopular = tier == (Platform.isIOS ? 'silver' : 'gold');
    final currency = (pkg['currency'] ?? 'EUR').toString();
    final applePrice = Platform.isIOS
        ? AppleIapService.priceLabel(AppleIapService.productForBoostTier(tier))
        : null;

    return ShopPlanTile(
      title: _tierName(tier),
      subtitle: 'boost_package_desc'.tr.replaceAll('@days', label),
      priceLabel: _tierPriceLabel(pkg),
      // Prix par jour : masqué sur iOS (calculé sur le prix carte, pas
      // forcément aligné sur le prix Apple).
      footnote: (applePrice == null && days > 0)
          ? '${CurrencyHelper.format(currency, amount / days)}/${'boost_per_day'.tr}'
          : null,
      leading: PawIconWidget(_tierIcon(tier), size: 24.sp, color: (pkg['color'] as Color?) ?? AppColors.primaryColor),
      // Ruban du palier mis en avant : on réutilise la clé existante
      // `boost_popular` (« Populaire ») plutôt que d'empiler deux pastilles
      // qui disent la même chose.
      ribbon: isPopular ? 'boost_popular'.tr : null,
      selected: isPicked,
      accent: AppColors.primaryColor,
      loading: isBuying,
      onTap: _purchasing ? null : () => setState(() => _pickedTier = tier),
      onLongPress: _purchasing ? null : () => _confirmPayWithWallet(tier),
    );
  }

  Widget _buildPurchaseHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: 'boost_history_title'.tr,
          fontSize: 15.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        SizedBox(height: 8.h),
        ...(_history.take(5).map((h) {
          final map = h as Map<String, dynamic>;
          final date = DateTime.tryParse(map['purchasedAt'] ?? '');
          return Container(
            margin: EdgeInsets.only(bottom: 6.h),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.divider(context)),
            ),
            child: Row(
              children: [
                InterText(
                  text: _tierName((map['tier'] ?? '').toString()).toUpperCase(),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryColor,
                ),
                SizedBox(width: 8.w),
                InterText(
                  // v566 — 2 décimales (avant : decimals 0 → « 3,99 » affiché « 4 »).
                  text: CurrencyHelper.format(
                    (map['currency'] as String?) ?? 'EUR',
                    ((map['amount'] ?? 0) as num).toDouble(),
                  ),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
                SizedBox(width: 8.w),
                InterText(
                  text: '${map['days'] ?? 0} ${'boost_days'.tr}',
                  fontSize: 12.sp,
                  color: AppColors.textSecondary(context),
                ),
                const Spacer(),
                if (date != null)
                  InterText(
                    text: '${date.day}/${date.month}/${date.year}',
                    fontSize: 11.sp,
                    color: AppColors.textSecondary(context),
                  ),
              ],
            ),
          );
        })),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 2 — PREMIUM (PawMap subscription €3.90/mo or €30/yr)
// ═══════════════════════════════════════════════════════════════════════════
class _PremiumTab extends StatefulWidget {
  const _PremiumTab({
    required this.onPromo,
    required this.onRestore,
    required this.restoring,
  });

  /// v569 — lignes du bloc « Aide & infos » (pilotées par l'écran parent).
  final VoidCallback onPromo;
  final VoidCallback onRestore;
  final bool restoring;

  @override
  State<_PremiumTab> createState() => _PremiumTabState();
}

class _PremiumTabState extends State<_PremiumTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // v23.1.279 — Daniel : "PawFollow et Family se calculent ensemble, Family
  // reste inactif". La bannière s'appuyait sur le plan UNIQUE de la sub
  // (mutuellement exclusif). On lit /me/benefits pour des signaux
  // INDÉPENDANTS (pawFollowActive + familyActive + leurs expirations) → les 2
  // moitiés peuvent être actives en même temps avec leurs propres jours.
  Map<String, dynamic> _benefits = const {};
  Worker? _benefitsTick;
  // v566 — offre CHOISIE (tap = sélection, l'achat part du bouton collant).
  String _picked = 'yearly';

  static const Color _violet = Color(0xFF7C3AED);
  static const List<Color> _violetGradient = [
    Color(0xFF9B6BFF),
    Color(0xFF6A34E0),
  ];

  bool _isFamilyKey(String k) =>
      k == 'family' || k == 'famille' || k == 'family_yearly';

  @override
  void initState() {
    super.initState();
    _loadBenefits();
    // v23.1.284 — re-fetch les jours quand un achat (n'importe où) notifie.
    _benefitsTick = ever<int>(
      ActiveBenefitsRow.refreshTickAccessor,
      (_) => _loadBenefits(),
    );
  }

  @override
  void dispose() {
    _benefitsTick?.dispose();
    super.dispose();
  }

  Future<void> _loadBenefits() async {
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      final r = await Get.find<ApiClient>()
          .get('/users/me/benefits', requiresAuth: true);
      if (!mounted) return;
      if (r is Map) setState(() => _benefits = Map<String, dynamic>.from(r));
    } catch (_) {/* defensive */}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final SubscriptionController controller = Get.find<SubscriptionController>();

    return Obx(() {
      if (controller.isLoading.value && controller.status.value == null) {
        // v569 — squelette animé au lieu d'un rond de progression.
        return const ShopSkeleton(tiles: 3);
      }
      // v566 — état d'erreur : /subscriptions/plans n'a rien renvoyé (réseau).
      // Avant : page sans aucune offre et sans explication.
      if (!controller.isLoading.value && controller.plans.isEmpty) {
        return ShopErrorState(onRetry: controller.refresh, accent: _violet);
      }
      final soloPlans = controller.plans
          .where((p) => p.plan == 'monthly' || p.plan == 'yearly')
          .toList();
      final familyPlans =
          controller.plans.where((p) => _isFamilyKey(p.plan)).toList();
      final offered = [...soloPlans, ...familyPlans];
      final picked = offered.firstWhereOrNull((p) => p.plan == _picked) ??
          (offered.isNotEmpty ? offered.first : null);
      final purchasing = controller.isPurchasing.value;
      return Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await controller.refresh();
                await _loadBenefits();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                // v567 — dégagement barre collante + barre système.
                padding: EdgeInsets.fromLTRB(
                    16.w, 16.h, 16.w, shopScrollBottomPadding(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Hero produit (état intégré en bas à gauche) ──────
                    ShopHero(
                      icon: SvgPicture.string(PawCardIcons.follow,
                          width: 28, height: 28),
                      title: 'shop_tab_pawpass'.tr,
                      subtitle: 'shop_card_follow_sub'.tr,
                      colors: _violetGradient,
                      status: _buildStatusCard(context, controller),
                    ),
                    ..._buildStatusExtras(context, controller),
                    SizedBox(height: 24.h),
                    // ── 2. Avantages ────────────────────────────────────────
                    ShopSectionTitle(title: 'shop569_benefits_title'.tr),
                    SizedBox(height: 12.h),
                    _buildFeaturesList(context),
                    SizedBox(height: 24.h),
                    // ── 3. Gratuit vs payant ────────────────────────────────
                    ShopSectionTitle(title: 'shop569_compare_title'.tr),
                    SizedBox(height: 12.h),
                    _pawFollowValueCard(context),
                    SizedBox(height: 24.h),
                    // ── 4. Forfaits ─────────────────────────────────────────
                    // Section 1 : Suis ton animal (PawFollow individuel).
                    _planSectionHeader(
                      context,
                      emoji: PawIcon.paw,
                      title: 'pawfollow_section_solo'.tr,
                      subtitle: 'pawfollow_section_solo_sub'.tr,
                      color: _violet,
                    ),
                    SizedBox(height: 12.h),
                    ...soloPlans.map((p) => _buildPlanCard(
                        context, controller, p, picked?.plan == p.plan)),
                    SizedBox(height: 16.h),
                    // Section 2 : PawFamily (suivi en famille).
                    _planSectionHeader(
                      context,
                      emoji: PawIcon.friends,
                      title: 'PawFamily',
                      subtitle: 'pawfollow_section_family_sub'.tr,
                      color: _violet,
                    ),
                    SizedBox(height: 8.h),
                    // #106 — PawFamily inclut 20 signalements premium.
                    _premiumReportsRow(context, _violet),
                    SizedBox(height: 12.h),
                    ...familyPlans.map((p) => _buildPlanCard(
                        context, controller, p, picked?.plan == p.plan)),
                    SizedBox(height: 8.h),
                    // ── 5. Rangée de confiance ──────────────────────────────
                    ShopTrustRow(accent: _violet),
                    SizedBox(height: 24.h),
                    // ── 6. Aide & infos (devise, code, légal, CGU) ──────────
                    // v503 — iOS : devise/prix imposés par Apple (StoreKit) →
                    // le sélecteur de devise Airwallex n'a plus de sens.
                    shopHelpCard(
                      context,
                      accent: _violet,
                      oneTime: false,
                      activeUntil: controller.status.value?.currentPeriodEnd,
                      onPromo: widget.onPromo,
                      onRestore: widget.onRestore,
                      restoring: widget.restoring,
                      currencyRow: Platform.isIOS
                          ? null
                          : _buildCurrencyPicker(context, controller),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (picked != null) _buildSticky(context, controller, picked, purchasing),
        ],
      );
    });
  }

  /// v566 — prix affiché d'un forfait : Apple localisé sur iOS, sinon prix
  /// serveur (réduit si un code promo % s'applique).
  String _planPriceLabel(SubscriptionPlan plan) {
    final applePrice = Platform.isIOS
        ? AppleIapService.priceLabel(
            AppleIapService.productForSubscriptionPlan(plan.plan))
        : null;
    if (applePrice != null) return applePrice;
    final promo = _PromoDiscount.read();
    final amount = (promo != null && promo.appliesTo(plan.plan))
        ? promo.discounted(plan.amount)
        : plan.amount;
    return CurrencyHelper.format(plan.currency, amount);
  }

  String _planName(SubscriptionPlan plan) {
    final key = plan.plan == 'famille' ? 'family' : plan.plan;
    return 'pawfollow_plan_$key'.tr;
  }

  /// Le forfait [plan] est-il celui qui est actif en ce moment ?
  bool _isCurrentPlan(SubscriptionController controller, SubscriptionPlan plan) {
    final cur = (controller.status.value?.plan ?? 'none').toLowerCase();
    final same = cur == plan.plan ||
        (cur == 'famille' && plan.plan == 'family') ||
        (cur == 'family' && plan.plan == 'famille');
    return same && controller.isPremium;
  }

  /// v566 — bandeau « expire bientôt ».
  /// v569 — « Gérer mon abonnement » a rejoint le bloc « Aide & infos ».
  List<Widget> _buildStatusExtras(
      BuildContext context, SubscriptionController controller) {
    final status = controller.status.value;
    final active = (status?.isPremium ?? false) ||
        _benefits['pawFollowActive'] == true ||
        _benefits['familyActive'] == true;
    if (!active) return const <Widget>[];
    final days = status?.remainingDays ?? 0;
    return <Widget>[
      if (ShopExpiryNotice.shouldShow(days)) ...[
        SizedBox(height: 12.h),
        ShopExpiryNotice(days: days),
      ],
    ];
  }

  Widget _buildSticky(BuildContext context, SubscriptionController controller,
      SubscriptionPlan picked, bool purchasing) {
    final isCurrent = _isCurrentPlan(controller, picked);
    // Jamais de bouton neutralisé : un abonnement actif peut venir d'un code
    // promo ou d'un autre profil (pas d'Apple) → l'achat doit rester possible.
    // Si l'abonnement Apple est déjà en cours, c'est la feuille StoreKit qui
    // l'annonce (« vous êtes déjà abonné »).
    final isYearly = picked.plan == 'yearly' || picked.plan == 'family_yearly';
    final perMonth = (isYearly && !Platform.isIOS)
        ? 'v566_shop_equiv_month'.tr.replaceAll(
            '{price}', CurrencyHelper.format(picked.currency, picked.amount / 12))
        : shopPeriodLabel(picked.intervalDays);
    return ShopStickyBar(
      title: _planName(picked),
      priceLabel: _planPriceLabel(picked),
      subLabel: perMonth,
      buttonLabel: (isCurrent ||
              (_isFamilyKey(picked.plan) && _benefits['familyActive'] == true))
          ? 'v566_shop_cta_extend'.tr
          : 'v566_shop_cta_subscribe'.tr,
      colors: _violetGradient,
      loading: purchasing,
      onPressed: purchasing
          ? null
          : () => _handlePurchase(context, controller, picked),
    );
  }

  /// v569 — sélecteur de devise = une LIGNE du bloc « Aide & infos » (même
  /// gabarit que « Gérer mon abonnement » / « J'ai un code »), le menu servant
  /// de contenu à droite. Mêmes devises, même `setCurrency`.
  Widget _buildCurrencyPicker(
      BuildContext context, SubscriptionController controller) {
    return ShopInfoRow(
      icon: Icons.public_rounded,
      label: 'shop567_currency'.tr,
      accent: _violet,
      showChevron: false,
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          // v566 — garde : une valeur absente de `items` fait planter le
          // DropdownButton (assert) → repli sur la 1re devise proposée.
          value:
              controller.supportedCurrencies.contains(controller.currency.value)
                  ? controller.currency.value
                  : (controller.supportedCurrencies.isNotEmpty
                      ? controller.supportedCurrencies.first
                      : null),
          isDense: true,
          borderRadius: BorderRadius.circular(16),
          icon: Icon(Icons.expand_more_rounded,
              size: 18.sp, color: AppColors.textSecondary(context)),
          items: controller.supportedCurrencies
              .map((c) => DropdownMenuItem<String>(
                    value: c,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          CurrencyHelper.symbol(c).trim(),
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          c,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) controller.setCurrency(v);
          },
        ),
      ),
    );
  }

  // v23.1.276 — Daniel : "le gros bouton PawFollow actif, divise-le en deux :
  // à gauche en jaune PawFollow actif avec le nombre de jours, à droite
  // PawFollow Family en violet avec les jours". Bannière SCINDÉE : la moitié
  // correspondant au plan actif s'allume (PawFollow doré pour mensuel/annuel,
  // Family violet pour le plan famille), l'autre reste grisée (inactive).
  Widget _buildStatusCard(BuildContext context, SubscriptionController controller) {
    final status = controller.status.value;
    final isPremium = status?.isPremium ?? false;
    final plan = (status?.plan ?? 'none').toLowerCase();
    final isFamilyPlan = plan == 'famille' || plan == 'family';
    final statusDays = status?.remainingDays ?? 0;

    // v23.1.279 — Daniel : "on dirait que PawFollow et Family se calculent
    // ensemble, Family reste inactif". On rend les 2 moitiés INDÉPENDANTES via
    // /me/benefits (un user peut avoir un abo individuel ET être dans une
    // famille). Fallback sur le plan unique de la sub si le backend n'est pas
    // encore déployé (pawFollowActive/familyActive absents du payload).
    DateTime? toDate(dynamic v) =>
        (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;
    int daysUntil(DateTime? d) => d == null
        ? 0
        : d.difference(DateTime.now()).inDays.clamp(0, 999999);
    final b = _benefits;
    final pfExpiry = toDate(b['pawFollowExpiry']);
    final famExpiry = toDate(b['familyExpiry']);
    final pawFollowActive = b.containsKey('pawFollowActive')
        ? b['pawFollowActive'] == true
        : (isPremium && !isFamilyPlan);
    final familyActive = b.containsKey('familyActive')
        ? b['familyActive'] == true
        : (isPremium && isFamilyPlan);
    // Jours par moitié : expiration dédiée si dispo, sinon les jours du plan
    // courant (ex: staff sans sub individuel → statusDays côté PawFollow).
    final pawFollowDays =
        pfExpiry != null ? daysUntil(pfExpiry) : (pawFollowActive ? statusDays : 0);
    final familyDays =
        famExpiry != null ? daysUntil(famExpiry) : (familyActive && isFamilyPlan ? statusDays : 0);

    // v23.1.278 — Daniel : "la page PawFollow a disparu". BUG : un Row avec
    // CrossAxisAlignment.stretch dans un Column/SingleChildScrollView reçoit
    // une hauteur NON BORNÉE → erreur de layout qui masquait tout le reste de
    // la page (forfaits). Règle release de CLAUDE.md : jamais `Expanded` sous
    // `IntrinsicHeight` ni `stretch` + `Expanded` dans un scroll.
    // v567 — les 2 moitiés deviennent les MÊMES pastilles d'état que les
    // 3 autres onglets : un `Wrap` (jamais d'Expanded, jamais de hauteur à
    // égaliser) qui passe à la ligne en allemand / polonais.
    // v569 — posées DANS le bandeau produit (fond violet) → `onDark`.
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        ShopStatusPill(
          label: 'PawFollow',
          active: pawFollowActive,
          accent: Colors.white,
          days: pawFollowDays,
          onDark: true,
        ),
        ShopStatusPill(
          label: 'PawFamily',
          active: familyActive,
          accent: Colors.white,
          days: familyDays,
          onDark: true,
        ),
      ],
    );
  }

  // v23.1.278 — en-tête de section de forfaits (Suis ton animal / PawFamily).
  // PawFamily reçoit la couleur violette (code couleur famille de l'app).
  /// v556 — « ce qui est gratuit / ce que PawFollow ajoute », deux colonnes.
  Widget _pawFollowValueCard(BuildContext context) => shopValueCard(
        context,
        color: const Color(0xFF7C3AED),
        freeTitle: 'shop_pf_free_title'.tr,
        freeBody: 'shop_pf_free_body'.tr,
        plusTitle: 'shop_pf_plus_title'.tr,
        plusBody: 'shop_pf_plus_body'.tr,
      );

  /// v567 — même gabarit de titre de section que les autres onglets.
  Widget _planSectionHeader(
    BuildContext context, {
    required PawIcon emoji,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return ShopSectionTitle(
      title: title,
      subtitle: subtitle,
      color: color,
      leading: PawIconWidget(emoji, size: 20.sp, color: color),
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    SubscriptionController controller,
    SubscriptionPlan plan,
    bool isPicked,
  ) {
    // v23.1.387 — family_yearly : annuel ET famille à la fois.
    final isYearly = plan.plan == 'yearly' || plan.plan == 'family_yearly';
    final isFamily = _isFamilyKey(plan.plan);
    final isCurrent = _isCurrentPlan(controller, plan);

    // v566 — économie RÉELLE de l'annuel, calculée sur les prix serveur
    // (avant : « (-35 %) » figé dans les traductions alors que 49,99 € contre
    // 12 × 6,99 € = −40 %). Rien d'affiché si le mensuel est introuvable.
    final monthlyRef = controller
        .planById(isFamily ? 'family' : 'monthly')
        ?.amount;
    final savingsPct = (isYearly && monthlyRef != null)
        ? shopYearlySavingsPct(monthly: monthlyRef, yearly: plan.amount)
        : 0;

    // v503 — iOS : prix localisé Apple (StoreKit) ; les codes promo maison ne
    // s'appliquent pas à la facturation Apple → pas de prix barré.
    final applePrice = Platform.isIOS
        ? AppleIapService.priceLabel(
            AppleIapService.productForSubscriptionPlan(plan.plan))
        : null;
    // v444/v450 — code promo % : appliqué par le serveur au montant du
    // PaymentIntent (/subscriptions/subscribe) ; ici on le montre.
    final promo = _PromoDiscount.read();
    final promoApplies =
        applePrice == null && promo != null && promo.appliesTo(plan.plan);

    final String subtitle;
    if (isFamily) {
      subtitle = 'pawfollow_subtitle_family'.tr;
    } else if (Platform.isIOS) {
      subtitle = isYearly
          ? 'pawfollow_subtitle_yearly'.tr
          : 'pawfollow_subtitle_monthly'.tr;
    } else {
      // Hors iOS le paiement est UNIQUE (pas de prélèvement récurrent) :
      // « Facturé tous les mois » était faux.
      subtitle = isYearly
          ? 'v566_shop_sub_year_once'.tr
          : 'v566_shop_sub_month_once'.tr;
    }

    // v569 — même tuile que les 3 autres onglets ([ShopPlanTile]) : prix en
    // gros, « soit X/mois » en petit, prix barré + « −X % » en haut à droite,
    // ruban « Le plus choisi » sur l'annuel, sélection = bord 2 px + coche.
    return ShopPlanTile(
      title: _planName(plan),
      subtitle: subtitle,
      priceLabel: _planPriceLabel(plan),
      // Équivalent mensuel de l'annuel (masqué sur iOS : prix Apple) ; sinon
      // la période facturée.
      footnote: (applePrice == null && isYearly)
          ? 'v566_shop_equiv_month'.tr.replaceAll('{price}',
              CurrencyHelper.format(plan.currency, plan.amount / 12))
          : (isYearly
              ? 'v566_shop_per_year'.tr
              : 'v566_shop_per_month'.tr),
      // v444 — prix d'origine barré quand un code promo % s'applique.
      strikeLabel: promoApplies
          ? CurrencyHelper.format(plan.currency, plan.amount)
          : null,
      savePct: savingsPct,
      ribbon: isYearly ? 'shop569_most_chosen'.tr : null,
      leading: PawIconWidget(
        isFamily
            ? PawIcon.friends
            : isYearly
                ? PawIcon.medal
                : PawIcon.star,
        size: 22.sp,
        color: _violet,
      ),
      badges: [
        if (isYearly)
          ShopPill(label: 'v565_shop_best_price'.tr, background: _violet),
        if (isCurrent)
          ShopPill(
            label: 'premium_active'.tr,
            background: const Color(0xFF16A34A),
          ),
        if (promoApplies)
          _PromoBadge(percent: promo.percent, accent: _violet),
      ],
      selected: isPicked,
      accent: _violet,
      // v23.1 part 63 — seul le forfait en cours d'achat tourne.
      loading: controller.isPurchasing.value &&
          controller.purchasingPlan.value == plan.plan,
      onTap: controller.isPurchasing.value
          ? null
          : () => setState(() => _picked = plan.plan),
    );
  }

  /// #106 — petite ligne « 🛡️ 20 signalements premium utilisables » réutilisée
  /// sous la section PawFamily (la même bénéf est listée dans _buildFeaturesList
  /// pour PawFollow). [accent] = couleur du bloc (violet famille).
  Widget _premiumReportsRow(BuildContext context, Color accent) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 18.sp, color: accent),
          SizedBox(width: 10.w),
          Expanded(
            child: InterText(
              text: 'shop_premium_reports_included'.tr,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  /// v569 — avantages en LIGNES « icône ronde teintée + titre court +
  /// sous-texte » (au lieu d'une liste de paragraphes). Les sous-textes
  /// reprennent les clés existantes, aucune fonctionnalité n'est retirée :
  /// le raccourci vers l'onglet PawSpot (boost offert) garde son chevron.
  Widget _buildFeaturesList(BuildContext context) {
    return ShopBenefitList(
      accent: _violet,
      items: [
        // v496 — Daniel : « rajoute la phrase de suivi dans l'onglet
        // PawFollow ». Suivi en direct longue durée, app fermée.
        ShopBenefit(
          icon: Icons.share_location_rounded,
          title: 'shop569_follow_b1_title'.tr,
          body: 'pawfollow_feature_live_toggle'.tr,
        ),
        // v23.1.357 — itinéraires vers les lieux GRATUITS de la PawMap.
        ShopBenefit(
          icon: Icons.directions_walk_rounded,
          title: 'shop569_follow_b2_title'.tr,
          body: 'pawfollow_feature_directions'.tr,
        ),
        // v556 — option C : l'historique de balade est un avantage PawFollow.
        ShopBenefit(
          icon: Icons.history_rounded,
          title: 'shop569_follow_b3_title'.tr,
          body: 'pawfollow_feature_history'.tr,
        ),
        // v21.1.1 — Forfait Famille mis en évidence (jusqu'à 5 personnes).
        ShopBenefit(
          icon: Icons.family_restroom,
          title: 'shop569_follow_b4_title'.tr,
          body: 'premium_feature_family_plan'.tr,
        ),
        ShopBenefit(
          icon: Icons.notifications_active_outlined,
          title: 'shop569_follow_b5_title'.tr,
          body:
              '${'premium_feature_notifications'.tr} · ${'premium_feature_chat'.tr}',
        ),
        // #106 — chaque abonnement inclut 20 signalements premium utilisables.
        ShopBenefit(
          icon: Icons.shield_outlined,
          title: 'shop569_follow_b6_title'.tr,
          body:
              '${'shop_premium_reports_included'.tr} · ${'premium_feature_badge'.tr}',
        ),
        // v489/v491 — Daniel : option « membres Paw Map proches » avec le VRAI
        // logo rose utilisateur (pas une icône générique).
        ShopBenefit(
          iconWidget: _pawBadgeMini(),
          title: 'shop_nearby_members'.tr,
          body: 'premium_feature_friends_tracking'.tr,
        ),
        // Session v15-4 — raccourci vers l'onglet PawSpot pour récupérer le
        // boost offert : chevron conservé, même action qu'avant.
        ShopBenefit(
          icon: Icons.push_pin_rounded,
          title: 'premium_feature_monthly_boost'.tr,
          onTap: () {
            final ctl = DefaultTabController.maybeOf(context);
            if (ctl != null) {
              ctl.animateTo(2);
            }
          },
        ),
      ],
    );
  }

  Future<void> _handlePurchase(
    BuildContext context,
    SubscriptionController controller,
    SubscriptionPlan planRow,
  ) async {
    final plan = planRow.plan;
    // v566 — feuille de confirmation AVANT le POST : le serveur active
    // immédiatement (et gratuitement) les comptes staff dès
    // /subscriptions/subscribe ; cet onglet était le seul sans garde-fou.
    final promo = _PromoDiscount.read();
    final promoApplies =
        !Platform.isIOS && promo != null && promo.appliesTo(plan);
    final confirmed = await showShopConfirmSheet(
      context,
      productName: _isFamilyKey(plan) ? 'PawFamily' : 'PawFollow',
      planLabel: _planName(planRow),
      priceLabel: _planPriceLabel(planRow),
      strikePriceLabel: promoApplies
          ? CurrencyHelper.format(planRow.currency, planRow.amount)
          : null,
      noteLabel: promoApplies
          ? 'shop_promo_discount_note'
              .trParams({'percent': '${promo.percent}'})
          : null,
      durationLabel: shopPeriodLabel(planRow.intervalDays),
      colors: _violetGradient,
      icon: SvgPicture.string(PawCardIcons.follow, width: 20, height: 20),
      method: Platform.isIOS ? ShopPayMethod.appleIap : ShopPayMethod.card,
    );
    if (!confirmed || !mounted) return;
    try {
      // v503 — iOS : achat intégré Apple (règle 3.1.1), sinon Airwallex.
      final ok = Platform.isIOS
          ? await controller.purchaseWithApple(plan)
          : await controller.purchase(plan);
      if (!mounted) return;
      if (ok) {
        // v23.1.284 — Daniel : "les jours ne se rajoutent pas dans le bouton".
        // CAUSE : la carte statut (_benefits) n'était chargée qu'au initState,
        // jamais re-fetchée après achat. On recharge /me/benefits + on notifie
        // le badge profil (ActiveBenefitsRow) pour que les jours montent.
        await _loadBenefits();
        ActiveBenefitsRow.notifyChanged();
        CustomSnackbar.showSuccess(
          title: 'premium_activated_title'.tr,
          message: 'premium_activated_msg'.tr,
        );
      } else if (mounted) {
        // Le code promo local a pu être consommé par le serveur : on relit.
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(
          title: 'common_error'.tr, message: _shopErrorText(e));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 3 — PAWSPOT (community subscription)
//  Refonte : l'ancien "map boost" à tiers (bronze→platinum, halos sur la
//  carte) est remplacé par l'abonnement communautaire PawSpot : taguer des
//  spots pet-friendly sur la PawMap, PawPoints + badges, classements et
//  récompenses. 4,99 €/mois · 39,99 €/an · essai gratuit 7 jours.
// ═══════════════════════════════════════════════════════════════════════════
class _PawSpotTab extends StatefulWidget {
  const _PawSpotTab({
    required this.onPromo,
    required this.onRestore,
    required this.restoring,
  });

  /// v569 — lignes du bloc « Aide & infos » (pilotées par l'écran parent).
  final VoidCallback onPromo;
  final VoidCallback onRestore;
  final bool restoring;

  @override
  State<_PawSpotTab> createState() => _PawSpotTabState();
}

class _PawSpotTabState extends State<_PawSpotTab>
    with AutomaticKeepAliveClientMixin {
  // Identité PawSpot : empreinte sur dégradé doré.
  static const Color _gold = Color(0xFFE8A00A);

  // Repli EUR tant que GET /pawspots/plans n'a pas répondu (serveur pas
  // encore déployé, réseau). Voir [_loadPlans].
  static const double _fallbackMonthly = 4.99;
  static const double _fallbackYearly = 39.99;
  static const List<Color> _spotGradient = [
    Color(0xFFFFC23D),
    Color(0xFFF0900A),
  ];

  bool _loading = true;
  bool _loadFailed = false;
  bool _trialLoading = false;
  String? _purchasingPlan; // 'monthly' | 'yearly' pendant un achat
  // v566 — offre CHOISIE (tap = sélection, l'achat part du bouton collant).
  String _picked = 'yearly';
  Worker? _currencyWorker;

  /// Payload brut de GET /pawspots/me/points.
  Map<String, dynamic> _me = const {};

  /// v566 — prix serveur par plan ({amount, currency}). Vide = repli EUR.
  Map<String, Map<String, dynamic>> _serverPlans = const {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
    _loadPlans();
    if (Get.isRegistered<SubscriptionController>()) {
      _currencyWorker = ever<String>(
        Get.find<SubscriptionController>().currency,
        (_) => _loadPlans(),
      );
    }
  }

  @override
  void dispose() {
    _currencyWorker?.dispose();
    super.dispose();
  }

  String get _shopCurrency => Get.isRegistered<SubscriptionController>()
      ? Get.find<SubscriptionController>().currency.value
      : 'EUR';

  /// v566 — audit boutique : les prix PawSpot étaient EN DUR (4,99 € /
  /// 39,99 €) alors que /pawspots/subscribe facture dans la devise choisie
  /// (5,49 $ pour un compte US) et que l'admin peut les modifier. On lit
  /// GET /pawspots/plans (même source que la facturation). Si la route ne
  /// répond pas, on garde le repli EUR ET on force l'achat en EUR
  /// ([_chargeCurrency]) pour que le prix affiché reste le prix débité.
  Future<void> _loadPlans() async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get(
        '/pawspots/plans',
        queryParameters: {'currency': _shopCurrency},
      );
      final list = (data is Map ? data['plans'] as List? : null) ?? const [];
      final out = <String, Map<String, dynamic>>{};
      for (final p in list) {
        if (p is Map && p['plan'] != null && p['amount'] is num) {
          out[p['plan'].toString()] = Map<String, dynamic>.from(p);
        }
      }
      if (!mounted) return;
      setState(() => _serverPlans = out);
    } catch (_) {
      if (mounted) setState(() => _serverPlans = const {});
    }
  }

  bool get _hasServerPrices =>
      _serverPlans.containsKey('monthly') && _serverPlans.containsKey('yearly');

  double _amountFor(String plan) {
    if (_hasServerPrices) {
      return (_serverPlans[plan]!['amount'] as num).toDouble();
    }
    return plan == 'yearly' ? _fallbackYearly : _fallbackMonthly;
  }

  /// Devise AFFICHÉE et ENVOYÉE au serveur (EUR forcé sans prix serveur).
  String get _chargeCurrency => _hasServerPrices
      ? (_serverPlans['monthly']!['currency'] ?? 'EUR').toString()
      : 'EUR';

  /// Prix affiché : Apple localisé sur iOS, sinon prix serveur.
  String _priceLabel(String plan) {
    final applePrice = Platform.isIOS
        ? AppleIapService.priceLabel(AppleIapService.productForPawSpotPlan(plan))
        : null;
    return applePrice ??
        CurrencyHelper.format(_chargeCurrency, _amountFor(plan));
  }

  Future<void> _loadPoints() async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get('/pawspots/me/points', requiresAuth: true);
      if (!mounted) return;
      if (data is Map) {
        setState(() {
          _me = Map<String, dynamic>.from(data);
          _loadFailed = false;
        });
      }
    } catch (_) {
      // On garde l'état précédent ; si rien n'a jamais été chargé, l'onglet
      // affiche un état d'erreur avec « Réessayer » (avant : page à 0 point
      // et bouton d'essai, comme si le compte était vierge).
      if (mounted && _me.isEmpty) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Accès payload ─────────────────────────────────────────────────────────
  bool get _subscribed => _me['subscribed'] == true;
  bool get _trialUsed => _me['trialUsed'] == true;
  bool get _isGoldCreator => _me['isGoldCreator'] == true;
  int get _points => (_me['points'] as num?)?.toInt() ?? 0;

  Map<String, dynamic>? get _badge =>
      _me['badge'] is Map ? Map<String, dynamic>.from(_me['badge'] as Map) : null;

  Map<String, dynamic>? get _nextBadge => _me['nextBadge'] is Map
      ? Map<String, dynamic>.from(_me['nextBadge'] as Map)
      : null;

  int get _remainingDays {
    final raw = _me['pawspotExpiry'];
    if (raw is! String || raw.isEmpty) return 0;
    final expiry = DateTime.tryParse(raw);
    if (expiry == null) return 0;
    // v23.1.370 — Daniel : "le badge jours ne correspond pas à
    // l'abonnement". inDays TRONQUE (29 j 23 h → 29) → on arrondit au
    // PLAFOND pour coller au plan acheté (mensuel → 30, essai → 7).
    final hours = expiry.difference(DateTime.now()).inHours;
    if (hours <= 0) return 0;
    return (hours / 24).ceil();
  }

  /// Mapping key backend → libellé traduit (qui inclut déjà emoji + seuil).
  String _badgeLabel(String key) {
    switch (key) {
      case 'explorer':
        return 'pawspot_badge_explorer'.tr;
      case 'expert':
        return 'pawspot_badge_expert'.tr;
      case 'ambassador':
        return 'pawspot_badge_ambassador'.tr;
      case 'pawmaster':
        return 'pawspot_badge_pawmaster'.tr;
      default:
        return key;
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _startTrial() async {
    if (_trialLoading) return;
    setState(() => _trialLoading = true);
    try {
      final api = Get.find<ApiClient>();
      await api.post('/pawspots/trial', requiresAuth: true);
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'pawspot_trial_started'.tr,
      );
      await _loadPoints();
      await refreshAfterPurchase();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        // 409 TRIAL_USED → on grise le bouton localement sans attendre
        // le prochain GET.
        setState(() => _me = {..._me, 'trialUsed': true});
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'pawspot_trial_used'.tr,
        );
      } else {
        CustomSnackbar.showError(title: 'common_error'.tr, message: e.message);
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: _shopErrorText(e),
      );
    } finally {
      if (mounted) setState(() => _trialLoading = false);
    }
  }

  /// Long-press sur une carte plan : payer avec le wallet (sitter/walker).
  /// Même pattern que le Boost tab — confirm dialog puis payWithWallet:true ;
  /// le backend rejette les owners avec un message clair.
  Future<void> _confirmPayWithWallet(String plan) async {
    // v503 — iOS : pas de paiement wallet pour un bien numérique (règle
    // Apple 3.1.1) → le long-press se comporte comme un tap (achat intégré).
    if (Platform.isIOS) {
      await _subscribe(plan);
      return;
    }
    final ok = await _confirmSheet(plan, ShopPayMethod.wallet);
    if (ok == true) {
      await _subscribe(plan, payWithWallet: true);
    }
  }

  Future<void> _subscribe(String plan, {bool payWithWallet = false}) async {
    if (_purchasingPlan != null) return;
    final price = _amountFor(plan);

    // Confirmation AVANT l'appel — le backend active immédiatement les
    // comptes staff dès le POST /pawspots/subscribe, sans page de paiement.
    if (!payWithWallet) {
      final confirmed = await _confirmSheet(
        plan,
        Platform.isIOS ? ShopPayMethod.appleIap : ShopPayMethod.card,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _purchasingPlan = plan);

    // v503 — iOS : achat intégré Apple (règle 3.1.1). Validation + crédit
    // via /apple-iap/validate dans AppleIapService.
    if (Platform.isIOS) {
      try {
        final productId = AppleIapService.productForPawSpotPlan(plan);
        if (productId == null) {
          throw Exception('iap_unavailable_msg'.tr);
        }
        final ok = await AppleIapService.buy(productId);
        if (!mounted) return;
        if (ok) {
          CustomSnackbar.showSuccess(
            title: 'common_success'.tr,
            message: 'premium_activated_msg'.tr,
          );
          await _loadPoints();
        }
      } catch (e) {
        CustomSnackbar.showError(title: 'common_error'.tr, message: _shopErrorText(e));
      } finally {
        if (mounted) setState(() => _purchasingPlan = null);
      }
      return;
    }

    try {
      final api = Get.find<ApiClient>();
      // v566 — devise = celle des prix AFFICHÉS (EUR forcé en repli).
      final currency = _chargeCurrency;
      final data = await api.post(
        '/pawspots/subscribe',
        body: {
          'plan': plan,
          'currency': currency,
          'payWithWallet': payWithWallet,
        },
        requiresAuth: true,
      );
      final map = data as Map<String, dynamic>;

      // Staff (gratuit) ou wallet (débit direct) → activation immédiate,
      // pas de HPP Airwallex.
      if (map['activated'] == true &&
          (map['staffFree'] == true ||
              map['staff'] == true ||
              map['paidFromWallet'] == true)) {
        CustomSnackbar.showSuccess(
          title: 'common_success'.tr,
          message: map['paidFromWallet'] == true
              ? 'coin_shop_boost_wallet_success'.tr
              : 'premium_activated_msg'.tr,
        );
        await _loadPoints();
        await refreshAfterPurchase();
        return;
      }

      final clientSecret = map['clientSecret'] as String?;
      final paymentIntentId = map['paymentIntentId'] as String?;
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('boost_purchase_error'.tr);
      }

      final displayAmount = (map['amount'] as num?)?.toDouble() ?? price;
      final displayCurrency = (map['currency'] as String?) ?? currency;

      // Même flux HPP Airwallex que les autres achats du shop.
      AppLogger.logInfo(
          '[pawspot] AIRWALLEX flow ($displayAmount $displayCurrency, $plan)');
      final result = await AirwallexPaymentService.confirmPaymentIntent(
        intentId: paymentIntentId ?? '',
        clientSecret: clientSecret,
        amount: displayAmount,
        currency: displayCurrency,
        // v568 — client Airwallex : la page propose la carte enregistrée.
        customerId: (map['customerId'] as String?)?.trim().isEmpty ?? true
            ? null
            : map['customerId'] as String?,
      );
      if (!mounted) return;
      if (result.isSuccess) {
        // Activation sync après le retour HPP.
        await api.post(
          '/pawspots/confirm',
          body: {'paymentIntentId': paymentIntentId, 'plan': plan},
          requiresAuth: true,
        );
        CustomSnackbar.showSuccess(
          title: 'common_success'.tr,
          message: 'premium_activated_msg'.tr,
        );
        await _loadPoints();
        await refreshAfterPurchase();
      } else if (result.outcome == AirwallexPaymentOutcome.failed) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: result.errorMessage ?? 'boost_purchase_error'.tr,
        );
      }
      // cancelled → silencieux (même comportement que les autres onglets).
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(
          title: 'common_error'.tr, message: _shopErrorText(e));
    } finally {
      if (mounted) setState(() => _purchasingPlan = null);
    }
  }

  Future<bool> _confirmSheet(String plan, ShopPayMethod method) {
    return showShopConfirmSheet(
      context,
      productName: 'PawSpot',
      planLabel: plan == 'yearly'
          ? 'pawspot_plan_yearly'.tr
          : 'pawspot_plan_monthly'.tr,
      priceLabel: method == ShopPayMethod.appleIap
          ? _priceLabel(plan)
          : CurrencyHelper.format(_chargeCurrency, _amountFor(plan)),
      durationLabel: shopPeriodLabel(plan == 'yearly' ? 365 : 30),
      colors: _spotGradient,
      icon: SvgPicture.string(PawCardIcons.spot, width: 20, height: 20),
      method: method,
    );
  }

  // v435 — les anciennes récompenses hardcodées (_redeem/_pickBadgeColor/
  // _askBannerUrl via /pawspots/rewards/redeem) ont été retirées : la carte
  // Récompenses ouvre désormais le vrai catalogue PawPoints (cf _buildRewardsCard
  // → showPawPointsRewardsSheet).

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // v569 — squelette animé au lieu d'un rond de progression.
    if (_loading) {
      return const ShopSkeleton(tiles: 2);
    }
    if (_loadFailed) {
      return ShopErrorState(
        accent: _gold,
        onRetry: () {
          setState(() => _loading = true);
          _loadPoints();
          _loadPlans();
        },
      );
    }
    final buying = _purchasingPlan != null;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([_loadPoints(), _loadPlans()]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              // v567 — dégagement barre collante + barre système.
              padding: EdgeInsets.fromLTRB(
                  16.w, 16.h, 16.w, shopScrollBottomPadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Hero produit (état intégré en bas à gauche) ────────
                  _buildHeader(context),
                  // Essai gratuit / rappel d'expiration juste sous le hero.
                  ..._buildStatusExtras(context),
                  SizedBox(height: 24.h),
                  // ── 2. Avantages ─────────────────────────────────────────
                  ShopSectionTitle(title: 'shop569_benefits_title'.tr),
                  SizedBox(height: 12.h),
                  _buildPlanFeatures(context),
                  SizedBox(height: 24.h),
                  // ── 3. Gratuit vs payant ─────────────────────────────────
                  ShopSectionTitle(title: 'shop569_compare_title'.tr),
                  SizedBox(height: 12.h),
                  shopValueCard(
                    context,
                    color: const Color(0xFFE8920A),
                    freeTitle: 'shop_ps_free_title'.tr,
                    freeBody: 'shop_ps_free_body'.tr,
                    plusTitle: 'shop_ps_plus_title'.tr,
                    plusBody: 'shop_ps_plus_body'.tr,
                  ),
                  SizedBox(height: 24.h),
                  // ── 4. Forfaits ──────────────────────────────────────────
                  ShopSectionTitle(title: 'shop567_choose_plan'.tr),
                  SizedBox(height: 16.h),
                  _buildPlanCards(context),
                  SizedBox(height: 8.h),
                  // ── 5. Rangée de confiance ───────────────────────────────
                  ShopTrustRow(accent: _gold),
                  SizedBox(height: 24.h),
                  _buildPointsCard(context),
                  // v440/v443 — catalogue de récompenses PawPoints OUVERT
                  // inline (plus de carte « Gagner des points » en doublon,
                  // plus d'anciens badges figés).
                  SizedBox(height: 16.h),
                  _buildRewardsCard(context),
                  SizedBox(height: 20.h),
                  _buildLeaderboardButton(context),
                  SizedBox(height: 20.h),
                  // v488 — légende des types de spots, en bas de l'onglet.
                  _buildSpotTypesLegend(context),
                  SizedBox(height: 24.h),
                  // ── 6. Aide & infos (+ mentions légales, CGU, privacy) ───
                  shopHelpCard(
                    context,
                    accent: const Color(0xFFB45309),
                    oneTime: false,
                    activeUntil: DateTime.tryParse(
                        (_me['pawspotExpiry'] ?? '').toString()),
                    onPromo: widget.onPromo,
                    onRestore: widget.onRestore,
                    restoring: widget.restoring,
                  ),
                ],
              ),
            ),
          ),
        ),
        ShopStickyBar(
          title:
              'PawSpot · ${_picked == 'yearly' ? 'pawspot_plan_yearly'.tr : 'pawspot_plan_monthly'.tr}',
          priceLabel: _priceLabel(_picked),
          subLabel: (_picked == 'yearly' && !Platform.isIOS)
              ? 'v566_shop_equiv_month'.tr.replaceAll(
                  '{price}',
                  CurrencyHelper.format(
                      _chargeCurrency, _amountFor('yearly') / 12))
              : shopPeriodLabel(_picked == 'yearly' ? 365 : 30),
          buttonLabel: _subscribed
              ? 'v566_shop_cta_extend'.tr
              : 'v566_shop_cta_subscribe'.tr,
          colors: _spotGradient,
          loading: buying,
          onPressed: buying ? null : () => _subscribe(_picked),
        ),
      ],
    );
  }

  /// v488 — Légende des types de spots PawSpot (pastille couleur + libellé),
  /// déplacée de la carte vers la boutique. Petite carte titrée, 2 par ligne.
  Widget _buildSpotTypesLegend(BuildContext context) {
    final types = PawSpotTypes.all.where((t) => t != 'other').toList();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.greyColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'pawspot_legend_title'.tr,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 14.w,
            runSpacing: 10.h,
            children: [
              for (final t in types)
                SizedBox(
                  width: 140.w,
                  child: Row(
                    children: [
                      Container(
                        width: 12.w,
                        height: 12.w,
                        decoration: BoxDecoration(
                          color: PawSpotTypes.color(t),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'pawspot_type_short_$t'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// a. Bandeau produit doré — v567 : même gabarit que les 3 autres onglets
  /// ([ShopHero]). L'icône reste la pièce dorée validée par Daniel.
  Widget _buildHeader(BuildContext context) {
    return ShopHero(
      // v23.1.362 — Daniel : l'emoji PawSpot DORÉ officiel (pièce or +
      // patte + pointe-pin) dans la description de la page PawSpot.
      icon: GoldenPawCoin(size: 40.w),
      title: 'PawSpot',
      subtitle: 'pawspot_shop_subtitle'.tr,
      colors: _spotGradient,
      // v569 — la pastille d'état vit DANS le hero, en bas à gauche.
      status: ShopStatusPill(
        label: 'PawSpot',
        active: _subscribed,
        accent: Colors.white,
        days: _remainingDays,
        onDark: true,
      ),
    );
  }

  /// b. Sous le hero : rappel d'expiration (abonné) ou essai gratuit.
  /// v567 — la pastille d'état est commune aux 4 onglets ; v569 — elle est
  /// remontée dans le hero et « Gérer mon abonnement » a rejoint « Aide &
  /// infos ». L'essai gratuit garde exactement le même flux.
  List<Widget> _buildStatusExtras(BuildContext context) {
    if (_subscribed) {
      return <Widget>[
        if (ShopExpiryNotice.shouldShow(_remainingDays)) ...[
          SizedBox(height: 12.h),
          ShopExpiryNotice(days: _remainingDays),
        ],
      ];
    }
    return <Widget>[
      SizedBox(height: 14.h),
      if (_trialUsed)
        // 409 TRIAL_USED (ou flag du payload) → texte grisé non cliquable.
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.divider(context).withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
          ),
          child: InterText(
            text: 'pawspot_trial_used'.tr,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
            maxLines: 2,
          ),
        )
      else
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _trialLoading ? null : _startTrial,
            icon: _trialLoading
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.card_giftcard_rounded, size: 18.sp),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'pawspot_trial_btn'.tr,
                maxLines: 1,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(52),
              padding: EdgeInsets.symmetric(vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
    ];
  }

  /// c. Les 2 forfaits (Mensuel / Annuel) en tuiles pleine largeur —
  /// v569 : même gabarit que les 3 autres onglets ([ShopPlanTile]).
  /// v566 — plus de `IntrinsicHeight` + `stretch` + `Expanded` (règle release
  /// de CLAUDE.md).
  Widget _buildPlanCards(BuildContext context) {
    final pct = shopYearlySavingsPct(
      monthly: _amountFor('monthly'),
      yearly: _amountFor('yearly'),
    );
    return Column(
      children: [
        _planCard(context, plan: 'monthly', title: 'pawspot_plan_monthly'.tr),
        // Économie calculée sur les prix réels (avant : « 33 % » figé).
        _planCard(
          context,
          plan: 'yearly',
          title: 'pawspot_plan_yearly'.tr,
          savePct: pct,
        ),
      ],
    );
  }

  Widget _planCard(
    BuildContext context, {
    required String plan,
    required String title,
    int savePct = 0,
  }) {
    final isPurchasing = _purchasingPlan != null;
    final isThisPlan = _purchasingPlan == plan;
    final isYearly = plan == 'yearly';
    final isPicked = _picked == plan;
    // v566 — plus de prix barré « code promo » ici : le serveur n'applique
    // PAS les codes promo % à /pawspots/subscribe (seulement aux forfaits de
    // /subscriptions/subscribe) → l'affichage promettait une réduction jamais
    // accordée.
    return ShopPlanTile(
      title: title,
      priceLabel: _priceLabel(plan),
      // Équivalent mensuel de l'annuel (masqué sur iOS : prix Apple).
      footnote: (isYearly && !Platform.isIOS)
          ? 'v566_shop_equiv_month'.tr.replaceAll('{price}',
              CurrencyHelper.format(_chargeCurrency, _amountFor('yearly') / 12))
          : (isYearly
              ? 'v566_shop_per_year'.tr
              : 'v566_shop_per_month'.tr),
      savePct: isYearly ? savePct : 0,
      ribbon: isYearly ? 'shop569_most_chosen'.tr : null,
      leading: GoldenPawCoin(size: 24.w),
      badges: [
        if (isYearly)
          ShopPill(
            label: 'v565_shop_best_price'.tr,
            background: _gold,
            gradient: const [_gold, Color(0xFFF0900A)],
          ),
      ],
      selected: isPicked,
      accent: _gold,
      loading: isThisPlan,
      onTap: isPurchasing ? null : () => setState(() => _picked = plan),
      // Wallet (sitter/walker) — même raccourci long-press que le Boost tab.
      onLongPress: isPurchasing ? null : () => _confirmPayWithWallet(plan),
    );
  }

  /// c (suite). Les avantages inclus — v569 : lignes « icône ronde teintée +
  /// titre court + sous-texte », mêmes clés qu'avant, aucun avantage retiré.
  Widget _buildPlanFeatures(BuildContext context) {
    return ShopBenefitList(
      accent: _gold,
      items: [
        ShopBenefit(
          icon: Icons.push_pin_rounded,
          title: 'shop569_spot_b1_title'.tr,
          // v556 — Daniel : « précise combien de tags gratuits ». Limite
          // serveur FREE_SPOT_LIMIT = 3.
          body:
              '${'pawspot_feature_unlimited'.tr} · ${'pawspot_free_tags_note'.tr}',
        ),
        ShopBenefit(
          icon: Icons.local_fire_department_rounded,
          title: 'shop569_spot_b2_title'.tr,
          body: '${'pawspot_feature_top'.tr} · ${'pawspot_feature_all'.tr}',
        ),
        // v444 — la communauté PawSpot tourne autour des PawPoints + badges.
        ShopBenefit(
          icon: Icons.military_tech_rounded,
          title: 'shop569_spot_b3_title'.tr,
          body: 'pawspot_feature_points_badges'.tr,
        ),
        ShopBenefit(
          icon: Icons.card_giftcard_rounded,
          title: 'shop569_spot_b4_title'.tr,
          body: 'pawspot_feature_rewards'.tr,
        ),
        // v556 — les itinéraires sont inclus dans PawSpot (règle serveur).
        ShopBenefit(
          icon: Icons.directions_walk_rounded,
          title: 'shop569_spot_b5_title'.tr,
          // #106 — 20 signalements premium utilisables inclus dans l'abo.
          body:
              '${'pawfollow_feature_directions'.tr} · ${'shop_premium_reports_included'.tr}',
        ),
        // v491 — Daniel : montrer le VRAI logo rose « membre Paw Map ».
        ShopBenefit(
          iconWidget: _pawBadgeMini(),
          title: 'shop_nearby_members'.tr,
        ),
      ],
    );
  }


  /// d. Compteur de points + badge actuel + progression vers le suivant.
  Widget _buildPointsCard(BuildContext context) {
    final badge = _badge;
    final next = _nextBadge;
    double progress = 1.0;
    if (next != null) {
      final base = (badge?['min'] as num?)?.toDouble() ?? 0;
      final target = (next['min'] as num?)?.toDouble() ?? 0;
      progress = target > base
          ? ((_points - base) / (target - base)).clamp(0.0, 1.0)
          : 0.0;
    }
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InterText(
            text: 'pawspot_points_title'.tr,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PoppinsText(
                text: '$_points',
                fontSize: 34.sp,
                fontWeight: FontWeight.w800,
                color: _gold,
              ),
              SizedBox(width: 6.w),
              Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: InterText(
                  text: 'pts',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: InterText(
                    // Le libellé traduit inclut déjà l'emoji + le seuil.
                    text: _badgeLabel((badge['key'] ?? '').toString()),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: _gold,
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8.h,
              backgroundColor: _gold.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(_gold),
            ),
          ),
          if (next != null) ...[
            SizedBox(height: 8.h),
            InterText(
              text: 'pawspot_next_badge'.trParams({
                'badge': (next['emoji'] ?? '').toString(),
                'points': '${(next['min'] as num?)?.toInt() ?? 0}',
              }),
              fontSize: 12.sp,
              color: AppColors.textSecondary(context),
            ),
          ],
          if (_isGoldCreator) ...[
            SizedBox(height: 10.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.workspace_premium_rounded,
                    color: _gold, size: 18.sp),
                SizedBox(width: 6.w),
                Expanded(
                  child: InterText(
                    text: 'pawspot_badge_gold_creator'.tr,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: _gold,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// g. Récompenses à points — page complète OUVERTE inline.
  /// v435 — la boutique PawSpot ouvrait un VRAI catalogue PawPoints
  /// (/pawpoints/catalog + /pawpoints/me) via un bouton « Voir les
  /// récompenses ».
  /// v440 — Daniel : "vires badges, au lieu d'un onglet voir les récompenses
  /// je veux la page complète écrite ouverte". On retire le bouton + le sheet
  /// et on rend le catalogue DIRECTEMENT inline (PawPointsRewardsList,
  /// embedded), visible dès l'arrivée sur la boutique. L'échange reste
  /// fonctionnel (même flux /pawpoints/redeem). Plus de gate « abonnés
  /// uniquement » : la liste est lisible par tous.
  Widget _buildRewardsCard(BuildContext context) {
    // Solde dépensable réel (payload /pawspots/me/points expose pawPointsSpendable
    // ; fallback sur points à vie si le champ n'est pas encore présent).
    final spendable = (_me['pawPointsSpendable'] as num?)?.toInt() ?? _points;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _gold.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PawIconWidget(PawIcon.gift, size: 20.sp, color: AppColors.primaryColor),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text: 'pawspot_rewards_title'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              // Solde dépensable réel.
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: InterText(
                  text: '$spendable pts',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: _gold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          InterText(
            text: 'pawspot_rewards_catalog_hint'.tr,
            fontSize: 12.sp,
            color: AppColors.textSecondary(context),
            maxLines: 3,
          ),
          SizedBox(height: 12.h),
          // v440 — la page de récompenses complète, écrite OUVERTE inline
          // (stats, barre de niveau, récompenses abonnement, niveaux, gains).
          PawPointsRewardsList(
            myPoints: spendable,
            onChanged: _loadPoints,
          ),
          SizedBox(height: 4.h),
          // Mise en avant d'un spot : se fait depuis la fiche d'un de tes
          // spots sur la carte — simple ligne info ici.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 15.sp, color: AppColors.textSecondary(context)),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text: 'pawspot_reward_feature'.tr,
                  fontSize: 12.sp,
                  color: AppColors.textSecondary(context),
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// h. Bouton classement (outline doré).
  Widget _buildLeaderboardButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Get.to(() => const PawspotLeaderboardScreen()),
        icon: Icon(Icons.emoji_events_rounded, color: _gold, size: 20.sp),
        label: Text(
          'pawspot_leaderboard_title'.tr,
          style: TextStyle(
            color: _gold,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _gold, width: 1.5),
          padding: EdgeInsets.symmetric(vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 4 — PAW PREMIUM (v23.1.387, Daniel)
//  Bundle PawFollow + PawSpot + exclusifs : badge Premium noir/or, points
//  communauté ×2, priorité sur les nouveautés. -33% vs les deux séparés.
//  Achat via /subscriptions/subscribe (plans premium_monthly/premium_yearly)
//  → le backend étend les 3 timers (tracking + pawspot + premium) d'un coup.
// ═══════════════════════════════════════════════════════════════════════════
class _PawPremiumTab extends StatefulWidget {
  const _PawPremiumTab({
    required this.onPromo,
    required this.onRestore,
    required this.restoring,
  });

  /// v569 — lignes du bloc « Aide & infos » (pilotées par l'écran parent).
  final VoidCallback onPromo;
  final VoidCallback onRestore;
  final bool restoring;

  @override
  State<_PawPremiumTab> createState() => _PawPremiumTabState();
}

class _PawPremiumTabState extends State<_PawPremiumTab>
    with AutomaticKeepAliveClientMixin {
  // Identité Paw Premium : or sur fond noir (mockup Daniel).
  static const Color _gold = Color(0xFFE8A00A);
  static const Color _goldLight = Color(0xFFFFD700);
  static const Color _black = Color(0xFF150F0D);

  // Repli EUR tant que /subscriptions/plans n'a pas répondu.
  static const double _fallbackMonthly = 7.99;
  static const double _fallbackYearly = 59.99;
  static const List<Color> _goldGradient = [Color(0xFFFFD34D), Color(0xFFE8A00A)];

  bool _loading = true;
  String? _purchasingPlan; // 'premium_monthly' | 'premium_yearly'
  // v566 — offre CHOISIE (tap = sélection, l'achat part du bouton collant).
  String _picked = 'premium_yearly';
  Worker? _plansWorker;
  Worker? _currencyWorker;

  /// Payload brut de GET /users/me/benefits (premiumActive/premiumExpiry).
  Map<String, dynamic> _benefits = const {};

  /// v566 — prix PawSpot serveur (pour le prix « 2 abonnements séparés »).
  Map<String, double> _spotAmounts = const {};

  @override
  bool get wantKeepAlive => true;

  SubscriptionController? get _subs =>
      Get.isRegistered<SubscriptionController>()
          ? Get.find<SubscriptionController>()
          : null;

  @override
  void initState() {
    super.initState();
    _loadBenefits();
    _loadSpotAmounts();
    final c = _subs;
    if (c != null) {
      // Les prix viennent de SubscriptionController.plans (Rx) : on
      // reconstruit quand ils arrivent / quand la devise change.
      _plansWorker = ever<List<SubscriptionPlan>>(c.plans, (_) {
        if (mounted) setState(() {});
      });
      _currencyWorker = ever<String>(c.currency, (_) => _loadSpotAmounts());
    }
  }

  @override
  void dispose() {
    _plansWorker?.dispose();
    _currencyWorker?.dispose();
    super.dispose();
  }

  /// v566 — audit boutique : les prix Paw Premium étaient EN DUR (7,99 € /
  /// 59,99 €, toujours en euros) alors que le serveur les expose déjà dans
  /// /subscriptions/plans (premium_monthly / premium_yearly) dans la devise
  /// du compte et facture dans cette devise.
  SubscriptionPlan? _serverPlan(String plan) => _subs?.planById(plan);

  bool get _hasServerPrices =>
      _serverPlan('premium_monthly') != null &&
      _serverPlan('premium_yearly') != null;

  double _amountFor(String plan) =>
      _serverPlan(plan)?.amount ??
      (plan == 'premium_yearly' ? _fallbackYearly : _fallbackMonthly);

  /// Devise AFFICHÉE et ENVOYÉE au serveur (EUR forcé sans prix serveur).
  String get _chargeCurrency => _hasServerPrices
      ? _serverPlan('premium_monthly')!.currency
      : 'EUR';

  /// Prix des deux abonnements séparés (PawFollow + PawSpot) sur la même
  /// période, calculé sur les prix serveur ; null si l'un des deux manque
  /// (on n'affiche alors ni prix barré ni « -X % » plutôt qu'un chiffre faux).
  double? _separateFor(String plan) {
    final yearly = plan == 'premium_yearly';
    final follow = _serverPlan(yearly ? 'yearly' : 'monthly')?.amount;
    final spot = _spotAmounts[yearly ? 'yearly' : 'monthly'];
    if (follow == null || spot == null || !_hasServerPrices) return null;
    return follow + spot;
  }

  Future<void> _loadSpotAmounts() async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get(
        '/pawspots/plans',
        queryParameters: {'currency': _subs?.currency.value ?? 'EUR'},
      );
      final list = (data is Map ? data['plans'] as List? : null) ?? const [];
      final out = <String, double>{};
      for (final p in list) {
        if (p is Map && p['plan'] != null && p['amount'] is num) {
          out[p['plan'].toString()] = (p['amount'] as num).toDouble();
        }
      }
      if (mounted) setState(() => _spotAmounts = out);
    } catch (_) {
      if (mounted) setState(() => _spotAmounts = const {});
    }
  }

  /// Prix affiché : Apple localisé sur iOS, sinon prix serveur (réduit si un
  /// code promo % s'applique — le serveur l'applique à ce forfait).
  String _priceLabel(String plan) {
    final applePrice = Platform.isIOS
        ? AppleIapService.priceLabel(
            AppleIapService.productForSubscriptionPlan(plan))
        : null;
    if (applePrice != null) return applePrice;
    final promo = _PromoDiscount.read();
    final base = _amountFor(plan);
    final amount =
        (promo != null && promo.appliesTo(plan)) ? promo.discounted(base) : base;
    return CurrencyHelper.format(_chargeCurrency, amount);
  }

  Future<bool> _confirmSheet(String plan, ShopPayMethod method) {
    final promo = _PromoDiscount.read();
    final promoApplies = method != ShopPayMethod.appleIap &&
        promo != null &&
        promo.appliesTo(plan);
    return showShopConfirmSheet(
      context,
      productName: 'Paw Premium',
      planLabel: plan == 'premium_yearly'
          ? 'premium_bundle_plan_yearly'.tr
          : 'premium_bundle_plan_monthly'.tr,
      priceLabel: _priceLabel(plan),
      strikePriceLabel: promoApplies
          ? CurrencyHelper.format(_chargeCurrency, _amountFor(plan))
          : null,
      noteLabel: promoApplies
          ? 'shop_promo_discount_note'.trParams({'percent': '${promo.percent}'})
          : null,
      durationLabel: shopPeriodLabel(plan == 'premium_yearly' ? 365 : 30),
      colors: const [Color(0xFF3A3028), Color(0xFF0E0A09)],
      icon: SvgPicture.string(PawCardIcons.premium, width: 20, height: 20),
      method: method,
    );
  }

  Future<void> _loadBenefits() async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get('/users/me/benefits', requiresAuth: true);
      if (!mounted) return;
      if (data is Map) {
        setState(() => _benefits = Map<String, dynamic>.from(data));
      }
    } catch (_) {
      // Best-effort.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _active => _benefits['premiumActive'] == true;

  int get _remainingDays {
    final raw = _benefits['premiumExpiry'];
    if (raw is! String || raw.isEmpty) return 0;
    final expiry = DateTime.tryParse(raw);
    if (expiry == null) return 0;
    // Arrondi au PLAFOND (cf. fix v23.1.370 PawSpot) : 29 j 23 h → 30.
    final hours = expiry.difference(DateTime.now()).inHours;
    if (hours <= 0) return 0;
    return (hours / 24).ceil();
  }

  // ── Achat ─────────────────────────────────────────────────────────────────

  Future<void> _confirmPayWithWallet(String plan) async {
    // v503 — iOS : pas de paiement wallet pour un bien numérique (règle
    // Apple 3.1.1) → le long-press se comporte comme un tap (achat intégré).
    if (Platform.isIOS) {
      await _subscribe(plan);
      return;
    }
    final ok = await _confirmSheet(plan, ShopPayMethod.wallet);
    if (ok == true) {
      await _subscribe(plan, payWithWallet: true);
    }
  }

  Future<void> _subscribe(String plan, {bool payWithWallet = false}) async {
    if (_purchasingPlan != null) return;
    final price = _amountFor(plan);

    if (!payWithWallet) {
      final confirmed = await _confirmSheet(
        plan,
        Platform.isIOS ? ShopPayMethod.appleIap : ShopPayMethod.card,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _purchasingPlan = plan);

    // v503 — iOS : achat intégré Apple (règle 3.1.1). Validation + crédit
    // via /apple-iap/validate dans AppleIapService.
    if (Platform.isIOS) {
      try {
        final productId = AppleIapService.productForSubscriptionPlan(plan);
        if (productId == null) {
          throw Exception('iap_unavailable_msg'.tr);
        }
        final ok = await AppleIapService.buy(productId);
        if (!mounted) return;
        if (ok) {
          CustomSnackbar.showSuccess(
            title: 'common_success'.tr,
            message: 'premium_bundle_activated_msg'.tr,
          );
          await _loadBenefits();
        }
      } catch (e) {
        CustomSnackbar.showError(title: 'common_error'.tr, message: _shopErrorText(e));
      } finally {
        if (mounted) setState(() => _purchasingPlan = null);
      }
      return;
    }

    try {
      final api = Get.find<ApiClient>();
      // v566 — devise = celle des prix AFFICHÉS (EUR forcé en repli).
      final currency = _chargeCurrency;
      final data = await api.post(
        '/subscriptions/subscribe',
        body: {
          'plan': plan,
          'currency': currency,
          'payWithWallet': payWithWallet,
        },
        requiresAuth: true,
      );
      final map = data as Map<String, dynamic>;
      // v566 — copie locale du code promo % (affichage) : retirée tout de
      // suite si le serveur facture le plein tarif (réduction déjà utilisée
      // ailleurs), et après un paiement RÉUSSI au prix réduit. Feuille fermée
      // = rien n'est effacé, la réduction reste disponible côté serveur.
      final chargedAmount = (map['amount'] as num?)?.toDouble();
      void syncPromoDisplay({required bool paid}) {
        if (map['staff'] == true) return;
        SubscriptionController.clearPromoDisplayAfterIntent(
          fullAmount: price,
          chargedAmount: chargedAmount,
          paid: paid,
          plan: plan,
        );
      }

      syncPromoDisplay(paid: false);

      // Staff (gratuit) ou wallet → activation immédiate, pas de HPP.
      if (map['activated'] == true &&
          (map['staff'] == true || map['paidFromWallet'] == true)) {
        CustomSnackbar.showSuccess(
          title: 'common_success'.tr,
          message: map['paidFromWallet'] == true
              ? 'coin_shop_boost_wallet_success'.tr
              : 'premium_bundle_activated_msg'.tr,
        );
        syncPromoDisplay(paid: true);
        await _loadBenefits();
        await refreshAfterPurchase();
        return;
      }

      final clientSecret = map['clientSecret'] as String?;
      final paymentIntentId = map['paymentIntentId'] as String?;
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('boost_purchase_error'.tr);
      }

      final displayAmount = (map['amount'] as num?)?.toDouble() ?? price;
      final displayCurrency = (map['currency'] as String?) ?? currency;

      AppLogger.logInfo(
          '[pawpremium] AIRWALLEX flow ($displayAmount $displayCurrency, $plan)');
      final result = await AirwallexPaymentService.confirmPaymentIntent(
        intentId: paymentIntentId ?? '',
        clientSecret: clientSecret,
        amount: displayAmount,
        currency: displayCurrency,
        // v568 — client Airwallex : la page propose la carte enregistrée.
        customerId: (map['customerId'] as String?)?.trim().isEmpty ?? true
            ? null
            : map['customerId'] as String?,
      );
      if (!mounted) return;
      if (result.isSuccess) {
        await api.post(
          '/subscriptions/confirm',
          body: {'paymentIntentId': paymentIntentId, 'plan': plan},
          requiresAuth: true,
        );
        CustomSnackbar.showSuccess(
          title: 'common_success'.tr,
          message: 'premium_bundle_activated_msg'.tr,
        );
        syncPromoDisplay(paid: true);
        await _loadBenefits();
        await refreshAfterPurchase();
      } else if (result.outcome == AirwallexPaymentOutcome.failed) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: result.errorMessage ?? 'boost_purchase_error'.tr,
        );
      }
      // cancelled → silencieux.
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(
          title: 'common_error'.tr, message: _shopErrorText(e));
    } finally {
      if (mounted) setState(() => _purchasingPlan = null);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // v569 — squelette animé au lieu d'un rond de progression.
    if (_loading) {
      return const ShopSkeleton(tiles: 2);
    }
    final buying = _purchasingPlan != null;
    final pickedYearly = _picked == 'premium_yearly';
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                _loadBenefits(),
                _loadSpotAmounts(),
                if (_subs != null) _subs!.loadPlans(),
              ]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              // v567 — dégagement barre collante + barre système.
              padding: EdgeInsets.fromLTRB(
                  16.w, 16.h, 16.w, shopScrollBottomPadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Hero produit (état intégré en bas à gauche) ────────
                  ShopHero(
                    icon: Image.asset('assets/images/pawpremium_logo.png',
                        width: 36, height: 36),
                    title: 'Paw Premium',
                    subtitle: 'premium_bundle_subtitle'.tr,
                    colors: const [Color(0xFF3A3028), Color(0xFF0E0A09)],
                    titleColor: const Color(0xFFFFD34D),
                    status: _buildActiveCard(context),
                  ),
                  if (_active &&
                      ShopExpiryNotice.shouldShow(_remainingDays)) ...[
                    SizedBox(height: 12.h),
                    ShopExpiryNotice(days: _remainingDays),
                  ],
                  SizedBox(height: 24.h),
                  // ── 2. Avantages (carte noir/or « LE PLUS COMPLET ») ─────
                  ShopSectionTitle(title: 'shop569_benefits_title'.tr),
                  SizedBox(height: 12.h),
                  _buildShowcaseCard(context),
                  SizedBox(height: 24.h),
                  // ── 3. Gratuit vs payant ─────────────────────────────────
                  ShopSectionTitle(title: 'shop569_compare_title'.tr),
                  SizedBox(height: 12.h),
                  shopValueCard(
                    context,
                    color: const Color(0xFF150F0D),
                    freeTitle: 'shop_pp_free_title'.tr,
                    freeBody: 'shop_pp_free_body'.tr,
                    plusTitle: 'shop_pp_plus_title'.tr,
                    plusBody: 'shop_pp_plus_body'.tr,
                  ),
                  SizedBox(height: 24.h),
                  // ── 4. Forfaits ──────────────────────────────────────────
                  ShopSectionTitle(title: 'shop567_choose_plan'.tr),
                  SizedBox(height: 16.h),
                  _planCard(
                    context,
                    plan: 'premium_monthly',
                    title: 'premium_bundle_plan_monthly'.tr,
                  ),
                  _planCard(
                    context,
                    plan: 'premium_yearly',
                    title: 'premium_bundle_plan_yearly'.tr,
                    highlight: true,
                  ),
                  // Économie vs les deux abonnements séparés : la phrase
                  // traduite annonce « 33 % » → affichée seulement quand c'est
                  // le chiffre réel ; sinon le pourcentage exact est sur les
                  // tuiles.
                  if (_separateFor('premium_yearly') == null ||
                      _bundlePct('premium_yearly') == 33) ...[
                    SizedBox(height: 4.h),
                    InterText(
                      text: 'premium_bundle_savings'.tr,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFB45309),
                      maxLines: 3,
                    ),
                  ],
                  SizedBox(height: 16.h),
                  // ── 5. Rangée de confiance ───────────────────────────────
                  ShopTrustRow(accent: _gold),
                  SizedBox(height: 24.h),
                  // ── 6. Aide & infos (+ mentions légales, CGU, privacy) ───
                  shopHelpCard(
                    context,
                    accent: const Color(0xFFB45309),
                    oneTime: false,
                    activeUntil: DateTime.tryParse(
                        (_benefits['premiumExpiry'] ?? '').toString()),
                    onPromo: widget.onPromo,
                    onRestore: widget.onRestore,
                    restoring: widget.restoring,
                  ),
                ],
              ),
            ),
          ),
        ),
        ShopStickyBar(
          dark: true,
          title:
              'Paw Premium · ${pickedYearly ? 'premium_bundle_plan_yearly'.tr : 'premium_bundle_plan_monthly'.tr}',
          priceLabel: _priceLabel(_picked),
          subLabel: (pickedYearly && !Platform.isIOS)
              ? 'v566_shop_equiv_month'.tr.replaceAll(
                  '{price}',
                  CurrencyHelper.format(
                      _chargeCurrency, _amountFor('premium_yearly') / 12))
              : shopPeriodLabel(pickedYearly ? 365 : 30),
          buttonLabel: _active
              ? 'v566_shop_cta_extend'.tr
              : 'v566_shop_cta_subscribe'.tr,
          colors: _goldGradient,
          buttonTextColor: _black,
          loading: buying,
          onPressed: buying ? null : () => _subscribe(_picked),
        ),
      ],
    );
  }

  /// État du bundle — v567 : la MÊME pastille que les 3 autres onglets
  /// (« Paw Premium · Actif · 30 j restants », « Illimité ∞ » au-delà de
  /// 10 ans au lieu de « Il vous reste 26766 jours »).
  Widget _buildActiveCard(BuildContext context) {
    // v569 — posée DANS le bandeau produit (fond noir) → `onDark`.
    return ShopStatusPill(
      label: 'Paw Premium',
      active: _active,
      accent: _goldLight,
      days: _remainingDays,
      onDark: true,
    );
  }

  /// La carte noir/or « LE PLUS COMPLET » (mockup Daniel) — v569 : elle porte
  /// désormais le BLOC AVANTAGES de l'onglet (même gabarit de lignes que les
  /// 3 autres onglets, en version sombre). Le ruban, le logo et la pastille
  /// « INCLUT PAWFOLLOW + PAWSPOT » sont conservés ; les forfaits et les
  /// mentions légales sont remontés au niveau de la page, comme ailleurs.
  Widget _buildShowcaseCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF221C12), _black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold, width: 2),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.25),
            blurRadius: 18,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 18.h),
      child: Column(
        children: [
          // Ruban « LE PLUS COMPLET 👑 »
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_gold, _goldLight]),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: InterText(
              text: 'premium_bundle_ribbon'.tr,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: _black,
            ),
          ),
          SizedBox(height: 14.h),
          // v567 — le nom et la phrase sont portés par le bandeau produit
          // ([ShopHero]) en haut de l'onglet : la carte garde le ruban, le
          // logo, la pastille « inclut » et les avantages.
          Image.asset('assets/images/pawpremium_logo.png',
              width: 56.w, height: 56.w),
          SizedBox(height: 12.h),
          // Pill « INCLUT PAWFOLLOW + PAWSPOT »
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: _gold.withValues(alpha: 0.5)),
            ),
            // v566 — FittedBox : « ENTHÄLT / INCLUI … » débordait en de / pt.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InterText(
                    text: '${'premium_bundle_includes'.tr} ',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  InterText(
                    text: 'PAWFOLLOW',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFA78BFA),
                  ),
                  InterText(
                    text: ' + ',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  InterText(
                    text: 'PAWSPOT',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: _goldLight,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          // Les avantages, en lignes « icône + titre court + sous-texte ».
          _features(context),
        ],
      ),
    );
  }

  /// v569 — mêmes avantages qu'avant (mêmes clés), rendus dans le gabarit
  /// commun aux 4 onglets, version sombre.
  Widget _features(BuildContext context) {
    return ShopBenefitList(
      onDark: true,
      accent: _goldLight,
      items: [
        ShopBenefit(
          icon: Icons.share_location_rounded,
          title: 'shop569_prem_b1_title'.tr,
          body: 'premium_bundle_feat_pawfollow'.tr,
        ),
        ShopBenefit(
          icon: Icons.push_pin_rounded,
          title: 'shop569_prem_b2_title'.tr,
          body: 'premium_bundle_feat_pawspot'.tr,
        ),
        ShopBenefit(
          icon: Icons.workspace_premium_rounded,
          title: 'shop569_prem_b3_title'.tr,
          body:
              '${'premium_bundle_feat_badge'.tr} · ${'premium_bundle_feat_exclusive'.tr}',
        ),
        ShopBenefit(
          icon: Icons.military_tech_rounded,
          title: 'shop569_prem_b4_title'.tr,
          body: 'premium_bundle_feat_points'.tr,
        ),
        ShopBenefit(
          icon: Icons.rocket_launch_rounded,
          title: 'shop569_prem_b5_title'.tr,
          body: 'premium_bundle_feat_priority'.tr,
        ),
        // #106 — 20 signalements premium utilisables inclus dans Paw Premium.
        ShopBenefit(
          icon: Icons.shield_outlined,
          title: 'shop_premium_reports_included'.tr,
        ),
      ],
    );
  }

  /// % d'économie du bundle par rapport aux deux abonnements séparés.
  int _bundlePct(String plan) {
    final sep = _separateFor(plan);
    if (sep == null || sep <= 0) return 0;
    final pct = (100 - _amountFor(plan) / sep * 100).round();
    return pct > 0 ? pct : 0;
  }

  Widget _planCard(
    BuildContext context, {
    required String plan,
    required String title,
    bool highlight = false,
  }) {
    final isPurchasing = _purchasingPlan != null;
    final isThisPlan = _purchasingPlan == plan;
    final isPicked = _picked == plan;
    final price = _amountFor(plan);
    final separatePrice = _separateFor(plan);
    final pct = _bundlePct(plan);
    // v503 — iOS : prix localisé Apple (les codes promo maison ne s'appliquent
    // pas à la facturation Apple → pas de double prix barré).
    final applePrice = Platform.isIOS
        ? AppleIapService.priceLabel(
            AppleIapService.productForSubscriptionPlan(plan))
        : null;
    // v444/v450 — code promo % : appliqué par le serveur à ce forfait.
    final promo = _PromoDiscount.read();
    final promoApplies =
        applePrice == null && promo != null && promo.appliesTo(plan);
    // Prix barrés : prix plein du bundle (si promo) puis « 2 abos séparés ».
    final strikes = <String>[
      if (promoApplies) CurrencyHelper.format(_chargeCurrency, price),
      if (separatePrice != null && applePrice == null)
        CurrencyHelper.format(_chargeCurrency, separatePrice),
    ];
    final isYearly = plan == 'premium_yearly';
    // v569 — même tuile que les 3 autres onglets ([ShopPlanTile]), en version
    // claire (les forfaits sont sortis de la carte noire) : l'or reste la
    // couleur d'accent de Paw Premium.
    return ShopPlanTile(
      title: title,
      priceLabel: _priceLabel(plan),
      // Équivalent mensuel de l'annuel (masqué sur iOS : prix Apple).
      footnote: (isYearly && applePrice == null)
          ? 'v566_shop_equiv_month'.tr.replaceAll('{price}',
              CurrencyHelper.format(_chargeCurrency, price / 12))
          : (isYearly
              ? 'v566_shop_per_year'.tr
              : 'v566_shop_per_month'.tr),
      strikeLabel: strikes.isEmpty ? null : strikes.join(' · '),
      savePct: pct,
      ribbon: highlight ? 'shop569_most_chosen'.tr : null,
      leading: Image.asset('assets/images/pawpremium_logo.png',
          width: 26.w, height: 26.w),
      badges: [
        if (highlight)
          ShopPill(
            label: 'v565_shop_best_price'.tr,
            background: _gold,
            foreground: _black,
            gradient: const [_gold, _goldLight],
          ),
        if (promoApplies) _PromoBadge(percent: promo.percent, accent: _gold),
      ],
      selected: isPicked,
      accent: const Color(0xFFB45309),
      checkColor: Colors.white,
      loading: isThisPlan,
      onTap: isPurchasing ? null : () => setState(() => _picked = plan),
      // Wallet (sitter/walker) — même raccourci long-press que les autres tabs.
      onLongPress: isPurchasing ? null : () => _confirmPayWithWallet(plan),
    );
  }
}

/// v569 — bloc « Aide & infos » en bas des 4 onglets : « Gérer mon
/// abonnement », le sélecteur de devise, « J'ai un code », « Restaurer mes
/// achats » (iOS) puis les mentions légales et les liens CGU /
/// confidentialité. Avant, ces entrées étaient dispersées (barre du haut,
/// milieu de page, pied d'écran).
///
/// Les liens CGU / confidentialité et le texte légal de renouvellement
/// restent donc présents sur CHAQUE onglet (exigence Apple 3.1.2), en plus de
/// la rangée toujours visible du pied d'écran iOS.
Widget shopHelpCard(
  BuildContext context, {
  required Color accent,
  required bool oneTime,
  required VoidCallback onPromo,
  required VoidCallback onRestore,
  required bool restoring,
  DateTime? activeUntil,
  bool showManage = true,
  Widget? currencyRow,
}) {
  return ShopHelpCard(
    rows: [
      if (showManage)
        ShopInfoRow(
          icon: Icons.manage_accounts_outlined,
          label: 'v566_shop_manage'.tr,
          accent: accent,
          onTap: () => ShopManageRow.open(
            context,
            accent: accent,
            activeUntil: activeUntil,
          ),
        ),
      if (currencyRow != null) currencyRow,
      ShopInfoRow(
        icon: Icons.confirmation_number_outlined,
        label: 'v565_promo_have_code'.tr,
        accent: accent,
        onTap: onPromo,
      ),
      // v503 — « Restaurer mes achats » : exigence Apple, iOS uniquement.
      if (Platform.isIOS)
        ShopInfoRow(
          icon: Icons.restore_rounded,
          label: 'iap_restore_button'.tr,
          accent: accent,
          loading: restoring,
          onTap: onRestore,
        ),
    ],
    footer: ShopLegalNote(oneTime: oneTime),
  );
}

/// v556 — Daniel : « explique mieux les abonnements dans la boutique ».
/// Carte à deux colonnes « Gratuit pour tous / Avec (abonnement) », posée en
/// tête des onglets PawBoost, PawFollow, PawSpot et PawPremium. Une seule
/// implémentation pour que les quatre onglets se lisent pareil.
Widget shopValueCard(
  BuildContext context, {
  required Color color,
  required String freeTitle,
  required String freeBody,
  required String plusTitle,
  required String plusBody,
}) {
  // v567 — les deux colonnes ont la MÊME hauteur minimale : elles se terminent
  // au même niveau sans `IntrinsicHeight` (interdit avec `Expanded`) ni
  // `CrossAxisAlignment.stretch` dans un scroll (règles release du projet).
  Widget col({
    required IconData icon,
    required Color tone,
    required String title,
    required String body,
    required bool filled,
  }) {
    return Expanded(
      child: Container(
        // Hauteur plancher COMMUNE aux deux colonnes, exprimée en `.sp` :
        // elle suit la même échelle que le texte, donc les deux cartes
        // finissent au même niveau sur petit comme sur grand écran.
        constraints: BoxConstraints(minHeight: 216.sp),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          // v569 — la colonne payante porte un liseré 2 px de la couleur du
          // produit : elle se distingue même en mode sombre.
          border: Border.all(
            color: filled ? color : color.withValues(alpha: 0.25),
            width: filled ? 2 : 1,
          ),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 18,
                    spreadRadius: -10,
                    offset: const Offset(0, 10),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: filled
                        ? Colors.white.withValues(alpha: 0.18)
                        : tone.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon,
                      size: 18.sp, color: filled ? Colors.white : tone),
                ),
                // v569 — petit ruban « Recommandé » sur la colonne payante.
                if (filled) ...[
                  SizedBox(width: 6.w),
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 7.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'shop569_recommended'.tr,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 8.h),
            InterText(
              text: title,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: filled ? Colors.white : AppColors.textPrimary(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            InterText(
              text: body,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: filled
                  ? Colors.white.withValues(alpha: 0.92)
                  : AppColors.textSecondary(context),
              // 6 lignes max : le texte le plus long (allemand, Paw Premium)
              // reste sous la hauteur plancher commune → colonnes à égalité.
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      col(
        icon: Icons.lock_open_rounded,
        tone: const Color(0xFF16A34A),
        title: freeTitle,
        body: freeBody,
        filled: false,
      ),
      SizedBox(width: 10.w),
      col(
        icon: Icons.workspace_premium_rounded,
        tone: color,
        title: plusTitle,
        body: plusBody,
        filled: true,
      ),
    ],
  );
}
