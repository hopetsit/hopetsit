import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/chat_addon_controller.dart';
import 'package:hopetsit/controllers/subscription_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/services/airwallex_payment_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/post_purchase_refresh.dart';
import 'package:hopetsit/views/boost/pawspot_leaderboard_screen.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/golden_paw_coin.dart';

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
  @override
  Widget build(BuildContext context) {
    // Ensure SubscriptionController is available.
    if (!Get.isRegistered<SubscriptionController>()) {
      Get.put(SubscriptionController());
    }
    // Chat add-on (session v3.2) — lazy register so the Premium tab can
    // show the cheap chat tile under the main Premium plans.
    if (!Get.isRegistered<ChatAddonController>()) {
      Get.put(ChatAddonController());
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
              Text('🐕', style: TextStyle(fontSize: 22.sp)),
              SizedBox(width: 8.w),
              InterText(
                text: 'boost_shop_title'.tr,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
          bottom: TabBar(
            labelColor: AppColors.primaryColor,
            unselectedLabelColor: AppColors.greyText,
            indicatorColor: AppColors.primaryColor,
            labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
            unselectedLabelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
            // v21.1.1 — rebrand : Premium → PawPass, Map Boost → PawSpot.
            // Refonte PawSpot — l'identité passe du pin bleu à l'empreinte
            // dorée (abonnement communautaire, plus un map boost).
            // v23.1.387 — Daniel : Boost devient PawBoost, PawFollow reçoit
            // son NOUVEAU logo officiel (pin violet + patte), et l'onglet
            // Paw Premium (pièce or + couronne) rejoint la boutique.
            tabs: [
              Tab(icon: const Icon(Icons.trending_up, size: 20), text: 'shop_tab_boost'.tr),
              Tab(
                icon: Image.asset(
                  'assets/images/pawfollow_logo.png',
                  width: 22,
                  height: 22,
                ),
                text: 'shop_tab_pawpass'.tr,
              ),
              // v23.1.363 — Daniel : le logo PawSpot = la pièce DORÉE
              // officielle (emoji fourni) partout dans la boutique.
              Tab(
                icon: const GoldenPawCoin(size: 22),
                text: 'shop_tab_pawspot'.tr,
              ),
              Tab(
                icon: Image.asset(
                  'assets/images/pawpremium_logo.png',
                  width: 22,
                  height: 22,
                ),
                text: 'shop_tab_premium'.tr,
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BoostTab(),
            _PremiumTab(),
            _PawSpotTab(),
            _PawPremiumTab(),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 1 — BOOST (existing boost packages)
// ═══════════════════════════════════════════════════════════════════════════
class _BoostTab extends StatefulWidget {
  const _BoostTab();

  @override
  State<_BoostTab> createState() => _BoostTabState();
}

class _BoostTabState extends State<_BoostTab> with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  bool _purchasing = false;
  String? _selectedTier;

  bool _boostActive = false;
  String? _currentTier;
  int _remainingDays = 0;
  List<dynamic> _history = [];

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
    {'tier': 'silver',   'amount': 7.99,  'days': 7,  'icon': '🥈', 'color': Color(0xFFC0C0C0)},
    {'tier': 'gold',     'amount': 11.99, 'days': 15, 'icon': '🥇', 'color': Color(0xFFFFD700)},
    {'tier': 'platinum', 'amount': 19.99, 'days': 30, 'icon': '💎', 'color': Color(0xFFE5E4E2)},
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
    final pkg = _packages.firstWhere(
      (p) => p['tier'] == tier,
      orElse: () => const <String, dynamic>{},
    );
    final amount = ((pkg['amount'] as num?) ?? 0).toDouble();
    final currency = (pkg['currency'] ?? 'EUR').toString();
    final ok = await Get.dialog<bool>(
      AlertDialog(
        // v23.1 part 243 — i18n. Was hardcoded FR.
        title: Text('coin_shop_pay_wallet_dialog_title'.tr),
        content: Text(
          'coin_shop_boost_wallet_confirm_msg'.trParams({
            'amount': '${amount.toStringAsFixed(2)} $currency',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('common_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('coin_shop_pay_wallet_btn'.tr),
          ),
        ],
      ),
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
      final priceLabel = pkg != null
          ? '${(pkg['amount'] as num).toStringAsFixed(2)} ${pkg['currency']}'
          : '?';
      // v23.1 part 243 — i18n. Was "${pkg['days']} jours" hardcoded FR.
      // Reuse mapboost_days_count which already handles "@count jour(s)".
      final daysLabel = pkg != null
          ? 'mapboost_days_count'.trParams({'count': pkg['days'].toString()})
          : '?';
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          // v23.1 part 243 — i18n. Was hardcoded FR.
          title: Text('coin_shop_boost_confirm_title'.trParams({'tier': tier.toUpperCase()})),
          content: Text(
            '${'mapboost_confirm_tier_label'.tr} : ${tier.toUpperCase()}\n'
            '${'mapboost_confirm_duration_label'.tr} : $daysLabel\n'
            '${'mapboost_confirm_price_label'.tr} : $priceLabel\n\n'
            '${'coin_shop_boost_confirm_description'.tr}',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('common_cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text('common_confirm'.tr),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      _purchasing = true;
      _selectedTier = tier;
    });

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
        setState(() {
          _purchasing = false;
          _selectedTier = null;
        });
        return;
      }

      final clientSecret = map['clientSecret'] as String?;
      final paymentIntentId = map['paymentIntentId'] as String?;

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Failed to create payment intent.');
      }

      final pkgMap = _packages.firstWhere(
        (p) => p['tier'] == tier,
        orElse: () => const <String, dynamic>{},
      );
      final displayAmount =
          ((pkgMap['amount'] as num?) ?? 0).toDouble();

      // v21.1.1 — Stripe purgé. Pure Airwallex.
      AppLogger.logInfo('[boost] AIRWALLEX flow ($displayAmount $currency)');
      final result = await AirwallexPaymentService.confirmPaymentIntent(
        intentId: paymentIntentId ?? '',
        clientSecret: clientSecret,
        amount: displayAmount,
        currency: currency,
      );
      if (!mounted) {
        setState(() {
          _purchasing = false;
          _selectedTier = null;
        });
        return;
      }
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
      String errorMsg = e.toString();
      if (errorMsg.contains('<!DOCTYPE') || errorMsg.contains('<html')) {
        errorMsg = 'boost_service_unavailable'.tr;
      } else if (errorMsg.contains('404')) {
        errorMsg = 'boost_service_unavailable'.tr;
      }
      CustomSnackbar.showError(title: 'common_error'.tr, message: errorMsg);
    } finally {
      if (mounted) {
        setState(() {
          _purchasing = false;
          _selectedTier = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadBoostStatus,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBoostStatus(),
                  SizedBox(height: 20.h),
                  InterText(
                    text: 'boost_choose_package'.tr,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                  SizedBox(height: 4.h),
                  InterText(
                    text: 'boost_choose_subtitle'.tr,
                    fontSize: 13.sp,
                    color: AppColors.greyText,
                  ),
                  SizedBox(height: 16.h),
                  ..._packages.map((p) => _buildPackageCard(context, p)),
                  SizedBox(height: 20.h),
                  _buildHowItWorks(),
                  if (_history.isNotEmpty) ...[
                    SizedBox(height: 20.h),
                    _buildPurchaseHistory(),
                  ],
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          );
  }

  Widget _buildBoostStatus() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _boostActive
              ? [AppColors.primaryColor, AppColors.primaryColor.withValues(alpha: 0.7)]
              : [Colors.grey.shade300, Colors.grey.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Center(
              child: Text(
                _boostActive ? '🔥' : '🐾',
                style: TextStyle(fontSize: 28.sp),
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: _boostActive ? 'boost_status_active'.tr : 'boost_status_inactive'.tr,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: _boostActive ? Colors.white : AppColors.blackColor,
                ),
                SizedBox(height: 4.h),
                InterText(
                  text: _boostActive
                      ? 'boost_remaining_days'.tr.replaceAll('@days', _remainingDays.toString())
                      : 'boost_inactive_hint'.tr,
                  fontSize: 13.sp,
                  color: _boostActive ? Colors.white.withValues(alpha: 0.85) : AppColors.greyText,
                ),
                if (_boostActive && _currentTier != null) ...[
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: InterText(
                      text: _currentTier!.toUpperCase(),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(BuildContext context, Map<String, dynamic> pkg) {
    final tier = pkg['tier'] as String;
    // Backend can return amount as double (e.g. 4.99) or int — coerce via num.
    final amount = ((pkg['amount'] as num?) ?? 0).toDouble();
    final days = ((pkg['days'] as num?) ?? 0).toInt();
    final icon = pkg['icon'] as String;
    // v18.9.8 — label localisé via _durationLabel(days), plus de label EN.
    final label = _durationLabel(days);
    final color = pkg['color'] as Color;
    final isSelected = _selectedTier == tier;
    final isPopular = tier == 'gold';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Stack(
        children: [
          GestureDetector(
            // v23.1 part 84 — long-press to pay with wallet, tap = card.
            // Daniel : "soit il l'utilise pour la boutique soit il le
            // retire et reçoit automatiquement". Walkers/sitters with
            // a wallet balance now have a 1-tap shortcut to apply
            // their earnings directly without going through the card
            // HPP. Long-press → confirm dialog → debit wallet.
            onLongPress: _purchasing ? null : () => _confirmPayWithWallet(tier),
            onTap: _purchasing ? null : () => _purchaseBoost(tier),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                // v23.1.276 — fond adaptatif (dark mode lisible). En light =
                // blanc, en dark = carte sombre → le texte reste visible.
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(16.r),
                border: isPopular ? Border.all(color: AppColors.primaryColor, width: 2) : null,
                boxShadow: isPopular
                    ? [BoxShadow(color: AppColors.primaryColor.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50.w,
                    height: 50.w,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(child: Text(icon, style: TextStyle(fontSize: 26.sp))),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            InterText(
                              text: tier[0].toUpperCase() + tier.substring(1),
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(context),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: InterText(
                                text: '$days ${'boost_days'.tr}',
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        InterText(
                          text: 'boost_package_desc'.tr.replaceAll('@days', label),
                          fontSize: 12.sp,
                          color: AppColors.greyText,
                        ),
                      ],
                    ),
                  ),
                  Obx(() {
                    final cur = Get.find<SubscriptionController>().currency.value;
                    final sym = CurrencyHelper.symbol(cur);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        PoppinsText(
                          text: '$sym$amount',
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryColor,
                        ),
                        InterText(
                          text: '$sym${(amount / days).toStringAsFixed(1)}/${'boost_per_day'.tr}',
                          fontSize: 10.sp,
                          color: AppColors.greyText,
                        ),
                      ],
                    );
                  }),
                  SizedBox(width: 8.w),
                  isSelected && _purchasing
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryColor),
                        )
                      : Icon(Icons.arrow_forward_ios, size: 16.sp, color: AppColors.greyText),
                ],
              ),
            ),
          ),
          if (isPopular)
            Positioned(
              top: 0,
              right: 16.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8.r),
                    bottomRight: Radius.circular(8.r),
                  ),
                ),
                child: InterText(
                  text: 'boost_popular'.tr,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    final steps = [
      {'icon': Icons.shopping_cart, 'text': 'boost_step_1'.tr},
      {'icon': Icons.payment, 'text': 'boost_step_2'.tr},
      {'icon': Icons.trending_up, 'text': 'boost_step_3'.tr},
      {'icon': Icons.visibility, 'text': 'boost_step_4'.tr},
    ];

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
            text: 'boost_how_title'.tr,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 12.h),
          ...steps.map((step) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Row(
                  children: [
                    Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(step['icon'] as IconData, size: 16.sp, color: AppColors.primaryColor),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: InterText(
                        text: step['text'] as String,
                        fontSize: 13.sp,
                        color: AppColors.blackColor,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
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
                  text: (map['tier'] ?? '').toString().toUpperCase(),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryColor,
                ),
                SizedBox(width: 8.w),
                InterText(
                  text: CurrencyHelper.format(
                    (map['currency'] as String?) ?? 'EUR',
                    ((map['amount'] ?? 0) as num).toDouble(),
                    decimals: 0,
                  ),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
                SizedBox(width: 8.w),
                InterText(
                  text: '${map['days'] ?? 0} ${'boost_days'.tr}',
                  fontSize: 12.sp,
                  color: AppColors.greyText,
                ),
                const Spacer(),
                if (date != null)
                  InterText(
                    text: '${date.day}/${date.month}/${date.year}',
                    fontSize: 11.sp,
                    color: AppColors.greyText,
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
  const _PremiumTab();

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
        return const Center(child: CircularProgressIndicator());
      }
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(context, controller),
              SizedBox(height: 20.h),
              // v23.1.278 — Daniel : "sépare bien sur la même page PawFollow :
              // un titre genre 'Suis ton animal', et PawFamily en violet pour
              // suivre en famille". 2 sections distinctes sur le même onglet.
              Align(
                alignment: Alignment.centerRight,
                child: _buildCurrencyPicker(context, controller),
              ),
              SizedBox(height: 14.h),
              // ── Section 1 : Suis ton animal (PawFollow individuel) ──────
              _planSectionHeader(
                context,
                emoji: '🐾',
                title: 'pawfollow_section_solo'.tr,
                subtitle: 'pawfollow_section_solo_sub'.tr,
                color: const Color(0xFF7C3AED),
              ),
              SizedBox(height: 12.h),
              // v23.1.387 — filtre EXPLICITE : le backend renvoie désormais
              // aussi family_yearly + premium_* ; les plans Premium ont leur
              // PROPRE onglet et ne doivent pas apparaître ici.
              ...controller.plans
                  .where((p) => p.plan == 'monthly' || p.plan == 'yearly')
                  .map((p) => _buildPlanCard(context, controller, p)),
              SizedBox(height: 22.h),
              // ── Section 2 : PawFamily (suivi en famille) — VIOLET ────────
              _planSectionHeader(
                context,
                emoji: '👨‍👩‍👧',
                title: 'PawFamily',
                subtitle: 'pawfollow_section_family_sub'.tr,
                color: const Color(0xFF7C3AED),
              ),
              SizedBox(height: 12.h),
              ...controller.plans
                  .where((p) =>
                      p.plan == 'family' ||
                      p.plan == 'famille' ||
                      p.plan == 'family_yearly')
                  .map((p) => _buildPlanCard(context, controller, p)),
              SizedBox(height: 20.h),
              // Session v3.2 — Chat add-on tile for free users who just want
              // chat with friends without going full Premium.
              _buildChatAddonTile(context),
              SizedBox(height: 20.h),
              _buildFeaturesList(context),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      );
    });
  }

  /// Secondary tile: cheap chat add-on. Hidden for active Premium users
  /// (they already have chat with everyone).
  Widget _buildChatAddonTile(BuildContext context) {
    final sub = Get.find<SubscriptionController>();
    final chat = Get.find<ChatAddonController>();
    return Obx(() {
      final isPremium = sub.status.value?.isPremium ?? false;
      if (isPremium) return const SizedBox.shrink();

      final plan = chat.plan.value;
      final status = chat.status.value;
      final alreadyActive = status?.isActive == true;
      final priceText = plan == null || plan.amount == 0
          ? '—'
          : '${CurrencyHelper.symbol(plan.currency)}${plan.amount.toStringAsFixed(2)}';

      return Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: alreadyActive
                ? Colors.green
                : AppColors.primaryColor.withValues(alpha: 0.35),
            width: 1.3,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 22.sp,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InterText(
                    text: 'coin_shop_chat_friends_title'.tr,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                  SizedBox(height: 3.h),
                  InterText(
                    text: alreadyActive
                        ? 'coin_shop_chat_friends_active'.tr
                        : 'coin_shop_chat_friends_desc'.tr,
                    fontSize: 12.sp,
                    color: AppColors.greyText,
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                InterText(
                  text: priceText,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryColor,
                ),
                SizedBox(height: 4.h),
                GestureDetector(
                  onTap: chat.isPurchasing.value
                      ? null
                      : () async {
                          final ok = await chat.purchase();
                          if (ok && mounted) {
                            CustomSnackbar.showSuccess(
                              title: 'Chat débloqué',
                              message: 'Tu peux maintenant chatter avec tes amis.',
                            );
                          }
                        },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: chat.isPurchasing.value
                          ? Colors.grey.shade300
                          : AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: InterText(
                      text: chat.isPurchasing.value
                          ? '…'
                          : (alreadyActive
                              ? 'shop_button_renew'.tr
                              : 'shop_button_buy'.tr),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCurrencyPicker(BuildContext context, SubscriptionController controller) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: controller.currency.value,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, size: 18.sp, color: AppColors.greyText),
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
    // la page (forfaits). On enveloppe dans IntrinsicHeight pour borner la
    // hauteur, ainsi les 2 moitiés s'égalisent sans casser le scroll.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _statusHalf(
              context,
              emoji: '⭐',
              title: 'PawFollow',
              active: pawFollowActive,
              days: pawFollowDays,
              activeColors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)], // v354 — PawFollow violet
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _statusHalf(
              context,
              emoji: '👨‍👩‍👧',
              title: 'Family',
              active: familyActive,
              days: familyDays,
              activeColors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusHalf(
    BuildContext context, {
    required String emoji,
    required String title,
    required bool active,
    required int days,
    required List<Color> activeColors,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: active
              ? activeColors
              : [Colors.grey.shade300, Colors.grey.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: TextStyle(fontSize: 18.sp)),
              SizedBox(width: 6.w),
              Flexible(
                child: InterText(
                  text: title,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : AppColors.blackColor,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          InterText(
            text: active
                ? (days > 0
                    ? 'premium_remaining_days'.trParams({'days': '$days'})
                    : 'premium_active'.tr)
                : 'shop_status_inactive'.tr,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: active
                ? Colors.white.withValues(alpha: 0.95)
                : AppColors.greyText,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // v23.1.278 — en-tête de section de forfaits (Suis ton animal / PawFamily).
  // PawFamily reçoit la couleur violette (code couleur famille de l'app).
  Widget _planSectionHeader(
    BuildContext context, {
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: TextStyle(fontSize: 20.sp)),
            SizedBox(width: 8.w),
            Flexible(
              child: InterText(
                text: title,
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: color,
                maxLines: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        InterText(
          text: subtitle,
          fontSize: 12.sp,
          color: AppColors.greyText,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    SubscriptionController controller,
    SubscriptionPlan plan,
  ) {
    // v23.1.276 — Daniel : "bien distinguer le PawFollow mensuel / annuel, et
    // la police violette pour PawFollow Famille". 3 plans visuellement
    // distincts : Mensuel ⭐ (gold clair) / Annuel 🏆 (gold profond + MEILLEUR
    // PRIX) / Famille 👨‍👩‍👧 (VIOLET, code couleur famille de l'app).
    // v23.1.387 — family_yearly : annuel ET famille à la fois.
    final isYearly = plan.plan == 'yearly' || plan.plan == 'family_yearly';
    // robuste FR/EN : l'enum backend accepte 'famille' ET 'family'.
    final isFamily = plan.plan == 'family' ||
        plan.plan == 'famille' ||
        plan.plan == 'family_yearly';
    final savings = isYearly ? 'pawfollow_yearly_savings'.tr : '';
    final currentPlan = controller.status.value?.plan;
    final isCurrent = currentPlan == plan.plan && controller.isPremium;

    // Couleur d'accent par plan (distinction claire mensuel/annuel/famille).
    const familyViolet = Color(0xFF8B5CF6);
    final accentColor = isFamily
        ? familyViolet // violet famille
        : isYearly
            ? const Color(0xFFE8A00A) // gold profond annuel
            : const Color(0xFFFFC83D); // gold clair mensuel

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Stack(
        children: [
          GestureDetector(
            onTap: (controller.isPurchasing.value || isCurrent)
                ? null
                : () => _handlePurchase(context, controller, plan.plan),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                // v23.1.276 — fond adaptatif : en dark mode le titre
                // (textPrimary = blanc) était invisible sur fond blanc.
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(16.r),
                border: (isYearly || isFamily)
                    ? Border.all(color: accentColor, width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: (isYearly || isFamily)
                        ? accentColor.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: (isYearly || isFamily) ? 12 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50.w,
                    height: 50.w,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: Text(
                        isFamily
                            ? '👨‍👩‍👧'
                            : isYearly
                                ? '🏆'
                                : '⭐',
                        style: TextStyle(fontSize: 26.sp),
                      ),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InterText(
                          text: '${('pawfollow_plan_${plan.plan}').tr}$savings',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          // v23.1.276 — titre violet pour PawFollow Famille.
                          color: isFamily
                              ? const Color(0xFF7C3AED)
                              : AppColors.textPrimary(context),
                        ),
                        SizedBox(height: 4.h),
                        InterText(
                          text: isFamily
                              ? 'pawfollow_subtitle_family'.tr
                              : isYearly
                                  ? 'pawfollow_subtitle_yearly'.tr
                                  : 'pawfollow_subtitle_monthly'.tr,
                          fontSize: 12.sp,
                          color: AppColors.greyText,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      PoppinsText(
                        text: CurrencyHelper.format(plan.currency, plan.amount),
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        // v23.1.276 — prix violet pour PawFollow Famille.
                        color: isFamily
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF7C3AED),
                      ),
                      InterText(
                        text: '${CurrencyHelper.format(plan.currency, plan.amountPerDay)}${'pawfollow_per_day_suffix'.tr}',
                        fontSize: 10.sp,
                        color: AppColors.greyText,
                      ),
                    ],
                  ),
                  SizedBox(width: 8.w),
                  Obx(() {
                    // v23.1 part 63 — Bug G : only spin THIS row when its
                    // plan is being purchased. Previously isPurchasing
                    // alone made every row spin at the same time.
                    final isThisOne =
                        controller.purchasingPlan.value == plan.plan;
                    if (controller.isPurchasing.value && isThisOne) {
                      return SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF7C3AED),
                        ),
                      );
                    }
                    if (isCurrent) {
                      return Icon(Icons.check_circle, size: 20.sp, color: Colors.green);
                    }
                    return Icon(Icons.arrow_forward_ios, size: 16.sp, color: AppColors.greyText);
                  }),
                ],
              ),
            ),
          ),
          if (isYearly)
            Positioned(
              top: 0,
              right: 16.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  // v354 — PawFollow = violet (Daniel), plus de ruban doré.
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8.r),
                    bottomRight: Radius.circular(8.r),
                  ),
                ),
                child: InterText(
                  text: 'MEILLEUR PRIX',
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList(BuildContext context) {
    // Session v15 — "PawMap complète" ligne retirée (les POIs vétos/parcs/
    // animaleries/points d'eau sont gratuits et publics). Les signalements
    // passent en tête pour valoriser la feature phare.
    // Session v15-4 — the "1 boost map offert" row becomes a shortcut
    // to the Map Boost tab (where the user can claim the credit). The
    // other features stay static since they're already unlocked by
    // Premium itself.
    // v19.1.5 — i18n : all Premium features are pulled from translation keys
    // so the list follows the current locale instead of staying in French.
    final features = <Map<String, dynamic>>[
      {
        'icon': Icons.warning_amber_rounded,
        'text': 'premium_feature_alerts'.tr,
      },
      {
        'icon': Icons.notifications_active_outlined,
        'text': 'premium_feature_notifications'.tr,
      },
      {
        'icon': Icons.chat_bubble_outline,
        'text': 'premium_feature_chat'.tr,
      },
      {
        'icon': Icons.people_outline,
        'text': 'premium_feature_friends_tracking'.tr,
      },
      // v23.1.357 — Daniel : "précise qu'avec PawFollow/PawFamily tu as les
      // itinéraires vers les lieux GRATUITS de la PawMap (eau, parcs, restos)".
      {
        'icon': Icons.directions_walk_rounded,
        'text': 'pawfollow_feature_directions'.tr,
      },
      // v21.1.1 — Forfait Famille mis en évidence (jusqu'à 5 personnes).
      {
        'icon': Icons.family_restroom,
        'text': 'premium_feature_family_plan'.tr,
      },
      {
        'icon': Icons.push_pin_rounded,
        'text': 'premium_feature_monthly_boost'.tr,
        'goToMapBoost': true,
      },
      {
        'icon': Icons.verified_rounded,
        'text': 'premium_feature_badge'.tr,
      },
    ];

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
            text: 'premium_what_unlocks_title'.tr,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 12.h),
          ...features.map((f) {
            final isShortcut = f['goToMapBoost'] == true;
            // Shortcut rows use the Map Boost blue accent + chevron to signal
            // tap affordance. Other rows stay flat with Premium orange.
            final accent = isShortcut
                ? AppColors.mapBoostBlue
                : const Color(0xFF7C3AED);
            final row = Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      f['icon'] as IconData,
                      size: 16.sp,
                      color: accent,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: InterText(
                      text: f['text'] as String,
                      fontSize: 13.sp,
                      // v21.1.1 — fix dark mode (texte noir invisible).
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  if (isShortcut) ...[
                    SizedBox(width: 6.w),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14.sp, color: accent),
                  ],
                ],
              ),
            );
            if (!isShortcut) return row;
            return InkWell(
              onTap: () {
                final ctl = DefaultTabController.maybeOf(context);
                if (ctl != null) {
                  ctl.animateTo(2);
                }
              },
              borderRadius: BorderRadius.circular(8.r),
              child: row,
            );
          }),
        ],
      ),
    );
  }

  Future<void> _handlePurchase(
    BuildContext context,
    SubscriptionController controller,
    String plan,
  ) async {
    try {
      final ok = await controller.purchase(plan);
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
      }
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString();
      if (msg.contains('<!DOCTYPE') || msg.contains('<html')) {
        msg = 'common_service_unavailable'.tr;
      }
      CustomSnackbar.showError(title: 'common_error'.tr, message: msg);
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
  const _PawSpotTab();

  @override
  State<_PawSpotTab> createState() => _PawSpotTabState();
}

class _PawSpotTabState extends State<_PawSpotTab>
    with AutomaticKeepAliveClientMixin {
  // Identité PawSpot : empreinte sur dégradé doré.
  static const Color _gold = Color(0xFFE8A00A);
  static const Color _goldLight = Color(0xFFFFD700);

  static const double _monthlyPrice = 4.99;
  static const double _yearlyPrice = 39.99;

  bool _loading = true;
  bool _trialLoading = false;
  String? _purchasingPlan; // 'monthly' | 'yearly' pendant un achat

  /// Payload brut de GET /pawspots/me/points.
  Map<String, dynamic> _me = const {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get('/pawspots/me/points', requiresAuth: true);
      if (!mounted) return;
      if (data is Map) {
        setState(() => _me = Map<String, dynamic>.from(data));
      }
    } catch (_) {
      // Best-effort : on garde l'état précédent si l'appel échoue.
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
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _trialLoading = false);
    }
  }

  /// Long-press sur une carte plan : payer avec le wallet (sitter/walker).
  /// Même pattern que le Boost tab — confirm dialog puis payWithWallet:true ;
  /// le backend rejette les owners avec un message clair.
  Future<void> _confirmPayWithWallet(String plan) async {
    final amount = plan == 'yearly' ? _yearlyPrice : _monthlyPrice;
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text('coin_shop_pay_wallet_dialog_title'.tr),
        content: Text(
          'coin_shop_boost_wallet_confirm_msg'.trParams({
            'amount': '${amount.toStringAsFixed(2)} EUR',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('common_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('coin_shop_pay_wallet_btn'.tr),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _subscribe(plan, payWithWallet: true);
    }
  }

  Future<void> _subscribe(String plan, {bool payWithWallet = false}) async {
    if (_purchasingPlan != null) return;
    final price = plan == 'yearly' ? _yearlyPrice : _monthlyPrice;
    final planLabel = plan == 'yearly'
        ? 'pawspot_plan_yearly'.tr
        : 'pawspot_plan_monthly'.tr;

    // Confirm dialog AVANT l'appel — même garde-fou que le Boost tab :
    // le backend active immédiatement les comptes staff dès le POST
    // /pawspots/subscribe, sans page de paiement.
    if (!payWithWallet) {
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('PawSpot'),
          content: Text('$planLabel · ${CurrencyHelper.format('EUR', price)}'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('common_cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.white,
              ),
              child: Text('common_confirm'.tr),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _purchasingPlan = plan);
    try {
      final api = Get.find<ApiClient>();
      final currency = Get.isRegistered<SubscriptionController>()
          ? Get.find<SubscriptionController>().currency.value
          : 'EUR';
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
        throw Exception('Failed to create payment intent.');
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
      String msg = e is ApiException ? e.message : e.toString();
      if (msg.contains('<!DOCTYPE') || msg.contains('<html') || msg.contains('404')) {
        msg = 'boost_service_unavailable'.tr;
      }
      CustomSnackbar.showError(title: 'common_error'.tr, message: msg);
    } finally {
      if (mounted) setState(() => _purchasingPlan = null);
    }
  }

  // v435 — les anciennes récompenses hardcodées (_redeem/_pickBadgeColor/
  // _askBannerUrl via /pawspots/rewards/redeem) ont été retirées : la carte
  // Récompenses ouvre désormais le vrai catalogue PawPoints (cf _buildRewardsCard
  // → showPawPointsRewardsSheet).

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadPoints,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            SizedBox(height: 14.h),
            _buildStatusCard(context),
            SizedBox(height: 14.h),
            _buildPlanCards(context),
            SizedBox(height: 12.h),
            _buildPlanFeatures(context),
            SizedBox(height: 20.h),
            _buildPointsCard(context),
            SizedBox(height: 14.h),
            _buildHowToEarnCard(context),
            SizedBox(height: 14.h),
            _buildBadgesCard(context),
            if (_subscribed) ...[
              SizedBox(height: 14.h),
              _buildRewardsCard(context),
            ],
            SizedBox(height: 18.h),
            _buildLeaderboardButton(context),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  /// a. Header doré : empreinte 🐾 sur dégradé doré.
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_gold, _goldLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // v23.1.362 — Daniel : l'emoji PawSpot DORÉ officiel (pièce or +
          // patte + pointe-pin) dans la description de la page PawSpot.
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Center(
              child: GoldenPawCoin(size: 46.w),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PoppinsText(
                  text: 'PawSpot',
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                SizedBox(height: 3.h),
                InterText(
                  text: 'pawspot_shop_subtitle'.tr,
                  fontSize: 12.sp,
                  color: Colors.white.withValues(alpha: 0.95),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// b. Carte statut : abonné (jours restants) ou bouton essai gratuit.
  Widget _buildStatusCard(BuildContext context) {
    if (_subscribed) {
      return Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: _gold, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: _gold, size: 24.sp),
            SizedBox(width: 10.w),
            Expanded(
              child: InterText(
                text: 'pawspot_active_until'
                    .trParams({'days': '$_remainingDays'}),
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      );
    }
    if (_trialUsed) {
      // 409 TRIAL_USED (ou flag du payload) → texte grisé non cliquable.
      return Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Center(
          child: InterText(
            text: 'pawspot_trial_used'.tr,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.greyText,
          ),
        ),
      );
    }
    return SizedBox(
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
        label: Text(
          'pawspot_trial_btn'.tr,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
      ),
    );
  }

  /// c. 2 cartes plans côte à côte (Mensuel / Annuel).
  Widget _buildPlanCards(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _planCard(
              context,
              plan: 'monthly',
              title: 'pawspot_plan_monthly'.tr,
              price: _monthlyPrice,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _planCard(
              context,
              plan: 'yearly',
              title: 'pawspot_plan_yearly'.tr,
              price: _yearlyPrice,
              saveBadge: 'pawspot_save_badge'.tr,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(
    BuildContext context, {
    required String plan,
    required String title,
    required double price,
    String? saveBadge,
  }) {
    final isPurchasing = _purchasingPlan != null;
    final isThisPlan = _purchasingPlan == plan;
    final isYearly = plan == 'yearly';
    return GestureDetector(
      onTap: isPurchasing ? null : () => _subscribe(plan),
      // Wallet (sitter/walker) — même raccourci long-press que le Boost tab.
      onLongPress: isPurchasing ? null : () => _confirmPayWithWallet(plan),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12.w, 18.h, 12.w, 14.h),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isYearly ? _gold : AppColors.divider(context),
                width: isYearly ? 2 : 1,
              ),
              boxShadow: isYearly
                  ? [
                      BoxShadow(
                        color: _gold.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InterText(
                  text: title,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
                SizedBox(height: 6.h),
                isThisPlan
                    ? SizedBox(
                        width: 22.w,
                        height: 22.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _gold,
                        ),
                      )
                    : PoppinsText(
                        text: CurrencyHelper.format('EUR', price),
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: _gold,
                      ),
                SizedBox(height: 4.h),
                InterText(
                  text: isYearly
                      ? '/ ${'pawspot_plan_yearly'.tr.toLowerCase()}'
                      : '/ ${'pawspot_plan_monthly'.tr.toLowerCase()}',
                  fontSize: 11.sp,
                  color: AppColors.greyText,
                ),
              ],
            ),
          ),
          if (saveBadge != null)
            Positioned(
              top: -8.h,
              right: 10.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_gold, _goldLight],
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: InterText(
                  text: saveBadge,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// c (suite). Les 4 features incluses, check doré.
  Widget _buildPlanFeatures(BuildContext context) {
    final features = <String>[
      'pawspot_feature_unlimited'.tr,
      'pawspot_feature_all'.tr,
      'pawspot_feature_top'.tr,
      'pawspot_feature_rewards'.tr,
    ];
    return Column(
      children: features
          .map(
            (f) => Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: _gold, size: 16.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: InterText(
                      text: f,
                      fontSize: 13.sp,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
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
                  color: AppColors.greyText,
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
              color: AppColors.greyText,
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

  /// e. Comment gagner des points — 6 lignes.
  Widget _buildHowToEarnCard(BuildContext context) {
    final rows = <Map<String, dynamic>>[
      {'icon': Icons.add_location_alt_rounded, 'text': 'pawspot_points_add'.tr},
      {'icon': Icons.photo_camera_rounded, 'text': 'pawspot_points_photo'.tr},
      {'icon': Icons.verified_rounded, 'text': 'pawspot_points_validated'.tr},
      {
        'icon': Icons.chat_bubble_outline_rounded,
        'text': 'pawspot_points_comment'.tr,
      },
      {'icon': Icons.flag_rounded, 'text': 'pawspot_points_report'.tr},
      {'icon': Icons.favorite_rounded, 'text': 'pawspot_points_popular'.tr},
    ];
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
            text: 'pawspot_points_how_title'.tr,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 12.h),
          ...rows.map(
            (r) => Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                children: [
                  Container(
                    width: 28.w,
                    height: 28.w,
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      r['icon'] as IconData,
                      size: 15.sp,
                      color: _gold,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: InterText(
                      text: r['text'] as String,
                      fontSize: 13.sp,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// f. Liste des 4 badges — atteints en couleur, le reste grisé.
  Widget _buildBadgesCard(BuildContext context) {
    // Seuils alignés sur le backend (et sur les libellés traduits).
    final rows = <Map<String, dynamic>>[
      {'label': 'pawspot_badge_explorer'.tr, 'min': 100},
      {'label': 'pawspot_badge_expert'.tr, 'min': 500},
      {'label': 'pawspot_badge_ambassador'.tr, 'min': 1500},
      {'label': 'pawspot_badge_pawmaster'.tr, 'min': 5000},
    ];
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
            text: 'pawspot_badges_title'.tr,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 12.h),
          ...rows.map((r) {
            final reached = _points >= (r['min'] as int);
            return Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                children: [
                  Icon(
                    reached
                        ? Icons.check_circle_rounded
                        : Icons.lock_outline_rounded,
                    size: 16.sp,
                    color: reached ? _gold : AppColors.greyText,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: InterText(
                      text: r['label'] as String,
                      fontSize: 13.sp,
                      fontWeight:
                          reached ? FontWeight.w700 : FontWeight.w500,
                      color: reached
                          ? AppColors.textPrimary(context)
                          : AppColors.greyText,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// g. Récompenses à points (abonnés uniquement).
  /// v435 — Daniel : "la boutique PawSpot n'est pas à jour". Avant, cette
  /// carte listait 3 récompenses HARDCODÉES (couleur de badge / cadre doré /
  /// bannière) échangées via /pawspots/rewards/redeem — déconnectées du
  /// catalogue PawPoints actuel (éditable par l'admin). On remplace par un
  /// accès au VRAI catalogue PawPoints (/pawpoints/catalog + /pawpoints/me)
  /// qui affiche le solde dépensable réel et permet d'échanger les
  /// récompenses admin + abonnement. Mêmes flux que le classement PawSpot.
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
            color: AppColors.greyText,
            maxLines: 3,
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => showPawPointsRewardsSheet(
                context,
                myPoints: spendable,
                onChanged: _loadPoints,
              ),
              icon: const Text('🎁', style: TextStyle(fontSize: 16)),
              label: Text(
                'pawpoints_rewards_cta'.tr,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          // Mise en avant d'un spot : se fait depuis la fiche d'un de tes
          // spots sur la carte — simple ligne info ici.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 15.sp, color: AppColors.greyText),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text: 'pawspot_reward_feature'.tr,
                  fontSize: 12.sp,
                  color: AppColors.greyText,
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
  const _PawPremiumTab();

  @override
  State<_PawPremiumTab> createState() => _PawPremiumTabState();
}

class _PawPremiumTabState extends State<_PawPremiumTab>
    with AutomaticKeepAliveClientMixin {
  // Identité Paw Premium : or sur fond noir (mockup Daniel).
  static const Color _gold = Color(0xFFE8A00A);
  static const Color _goldLight = Color(0xFFFFD700);
  static const Color _black = Color(0xFF15120D);

  static const double _monthlyPrice = 7.99;
  static const double _yearlyPrice = 59.99;
  // Prix des deux abonnements séparés (pour afficher l'économie réelle) :
  // PawFollow 6,99 + PawSpot 4,99 = 11,98 /mois · 49,99 + 39,99 = 89,98 /an.
  static const double _separateMonthly = 11.98;
  static const double _separateYearly = 89.98;

  bool _loading = true;
  String? _purchasingPlan; // 'premium_monthly' | 'premium_yearly'

  /// Payload brut de GET /users/me/benefits (premiumActive/premiumExpiry).
  Map<String, dynamic> _benefits = const {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadBenefits();
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
    final amount = plan == 'premium_yearly' ? _yearlyPrice : _monthlyPrice;
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text('coin_shop_pay_wallet_dialog_title'.tr),
        content: Text(
          'coin_shop_boost_wallet_confirm_msg'.trParams({
            'amount': '${amount.toStringAsFixed(2)} EUR',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('common_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('coin_shop_pay_wallet_btn'.tr),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _subscribe(plan, payWithWallet: true);
    }
  }

  Future<void> _subscribe(String plan, {bool payWithWallet = false}) async {
    if (_purchasingPlan != null) return;
    final price = plan == 'premium_yearly' ? _yearlyPrice : _monthlyPrice;
    final planLabel = plan == 'premium_yearly'
        ? 'premium_bundle_plan_yearly'.tr
        : 'premium_bundle_plan_monthly'.tr;

    if (!payWithWallet) {
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Paw Premium 👑'),
          content: Text('$planLabel · ${CurrencyHelper.format('EUR', price)}'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('common_cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.white,
              ),
              child: Text('common_confirm'.tr),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _purchasingPlan = plan);
    try {
      final api = Get.find<ApiClient>();
      final currency = Get.isRegistered<SubscriptionController>()
          ? Get.find<SubscriptionController>().currency.value
          : 'EUR';
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

      // Staff (gratuit) ou wallet → activation immédiate, pas de HPP.
      if (map['activated'] == true &&
          (map['staff'] == true || map['paidFromWallet'] == true)) {
        CustomSnackbar.showSuccess(
          title: 'common_success'.tr,
          message: map['paidFromWallet'] == true
              ? 'coin_shop_boost_wallet_success'.tr
              : 'premium_bundle_activated_msg'.tr,
        );
        await _loadBenefits();
        await refreshAfterPurchase();
        return;
      }

      final clientSecret = map['clientSecret'] as String?;
      final paymentIntentId = map['paymentIntentId'] as String?;
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Failed to create payment intent.');
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
      String msg = e is ApiException ? e.message : e.toString();
      if (msg.contains('<!DOCTYPE') || msg.contains('<html') || msg.contains('404')) {
        msg = 'boost_service_unavailable'.tr;
      }
      CustomSnackbar.showError(title: 'common_error'.tr, message: msg);
    } finally {
      if (mounted) setState(() => _purchasingPlan = null);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadBenefits,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_active) ...[
              _buildActiveCard(context),
              SizedBox(height: 14.h),
            ],
            _buildShowcaseCard(context),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  /// Carte statut quand le bundle est actif (jours restants).
  Widget _buildActiveCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _gold, width: 1.5),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/pawpremium_logo.png',
              width: 26.w, height: 26.w),
          SizedBox(width: 10.w),
          Expanded(
            child: InterText(
              text: 'premium_bundle_active_until'
                  .trParams({'days': '$_remainingDays'}),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// La grande carte noir/or « LE PLUS COMPLET » (mockup Daniel).
  Widget _buildShowcaseCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF221C12), _black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: _gold, width: 2),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(18.w, 22.h, 18.w, 20.h),
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
          SizedBox(height: 16.h),
          Image.asset('assets/images/pawpremium_logo.png',
              width: 84.w, height: 84.w),
          SizedBox(height: 10.h),
          PoppinsText(
            text: 'Paw Premium',
            fontSize: 22.sp,
            fontWeight: FontWeight.w800,
            color: _goldLight,
          ),
          SizedBox(height: 4.h),
          InterText(
            text: 'premium_bundle_subtitle'.tr,
            fontSize: 12.5.sp,
            color: Colors.white.withValues(alpha: 0.85),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          SizedBox(height: 12.h),
          // Pill « INCLUT PAWFOLLOW + PAWSPOT »
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: _gold.withValues(alpha: 0.5)),
            ),
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
          SizedBox(height: 16.h),
          // 6 avantages avec checks dorés
          ..._features(context),
          SizedBox(height: 18.h),
          // 2 cartes prix (mensuel / annuel)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _planCard(
                    context,
                    plan: 'premium_monthly',
                    title: 'premium_bundle_plan_monthly'.tr,
                    price: _monthlyPrice,
                    separatePrice: _separateMonthly,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _planCard(
                    context,
                    plan: 'premium_yearly',
                    title: 'premium_bundle_plan_yearly'.tr,
                    price: _yearlyPrice,
                    separatePrice: _separateYearly,
                    highlight: true,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          // Économie réelle vs les deux abonnements séparés (-33%)
          InterText(
            text: 'premium_bundle_savings'.tr,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w600,
            color: _goldLight,
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  List<Widget> _features(BuildContext context) {
    final items = <String>[
      'premium_bundle_feat_pawfollow'.tr,
      'premium_bundle_feat_pawspot'.tr,
      'premium_bundle_feat_exclusive'.tr,
      'premium_bundle_feat_badge'.tr,
      'premium_bundle_feat_points'.tr,
      'premium_bundle_feat_priority'.tr,
    ];
    return items
        .map(
          (t) => Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: _gold, size: 18.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: InterText(
                    text: t,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  Widget _planCard(
    BuildContext context, {
    required String plan,
    required String title,
    required double price,
    required double separatePrice,
    bool highlight = false,
  }) {
    final isPurchasing = _purchasingPlan != null;
    final isThisPlan = _purchasingPlan == plan;
    final pct = (100 - price / separatePrice * 100).round();
    return GestureDetector(
      onTap: isPurchasing ? null : () => _subscribe(plan),
      // Wallet (sitter/walker) — même raccourci long-press que les autres tabs.
      onLongPress: isPurchasing ? null : () => _confirmPayWithWallet(plan),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(10.w, 16.h, 10.w, 12.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: highlight ? 0.10 : 0.05),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: highlight ? _goldLight : _gold.withValues(alpha: 0.5),
                width: highlight ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InterText(
                  text: title,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                SizedBox(height: 6.h),
                isThisPlan
                    ? SizedBox(
                        width: 22.w,
                        height: 22.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _gold,
                        ),
                      )
                    : PoppinsText(
                        text: CurrencyHelper.format('EUR', price),
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: _goldLight,
                      ),
                SizedBox(height: 2.h),
                // Prix barré des deux abos séparés
                Text(
                  CurrencyHelper.format('EUR', separatePrice),
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white.withValues(alpha: 0.5),
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -8.h,
            right: 8.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_gold, _goldLight]),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                '-$pct%',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: _black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
