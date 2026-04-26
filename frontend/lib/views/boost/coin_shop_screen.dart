import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/chat_addon_controller.dart';
import 'package:hopetsit/controllers/map_boost_controller.dart';
import 'package:hopetsit/controllers/subscription_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/services/airwallex_payment_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/boost/widgets/map_boost_pin_icon.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Boutique screen — 3 tabs:
///   1. Boost     — one-time profile boost (existing feature)
///   2. Premium   — PawMap Premium subscription (€3.90/mo or €30/yr)
///   3. Map Boost — placeholder for Phase 5 (map visibility boost)
///
/// Available for the 3 roles: Owner, Sitter, Walker.
class CoinShopScreen extends StatefulWidget {
  const CoinShopScreen({super.key, this.initialTab = 0});

  /// Index of the tab to show first. 0 = Boost (default), 1 = Premium,
  /// 2 = Map Boost. Used by the PawMap "Passer Premium" banner to land
  /// directly on the Premium offers rather than the Boost page.
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
      length: 3,
      initialIndex: widget.initialTab.clamp(0, 2),
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
            tabs: [
              Tab(icon: const Icon(Icons.trending_up, size: 20), text: 'shop_tab_boost'.tr),
              Tab(icon: const Icon(Icons.star_rounded, size: 22), text: 'shop_tab_pawpass'.tr),
              Tab(icon: const Icon(Icons.location_on_outlined, size: 20), text: 'shop_tab_pawspot'.tr),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BoostTab(),
            _PremiumTab(),
            _MapBoostTab(),
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
    {'tier': 'bronze',   'amount': 4.99,  'days': 3,  'icon': '🥉', 'color': Color(0xFFCD7F32)},
    {'tier': 'silver',   'amount': 9.99,  'days': 7,  'icon': '🥈', 'color': Color(0xFFC0C0C0)},
    {'tier': 'gold',     'amount': 14.99, 'days': 15, 'icon': '🥇', 'color': Color(0xFFFFD700)},
    {'tier': 'platinum', 'amount': 24.99, 'days': 30, 'icon': '💎', 'color': Color(0xFFE5E4E2)},
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

  Future<void> _purchaseBoost(String tier) async {
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
        body: {'tier': tier, 'currency': currency},
        requiresAuth: true,
      );
      final map = piData as Map<String, dynamic>;

      // v20.0.2 — Staff short-circuit: server already activated the boost
      // for free. Skip the Stripe payment sheet entirely.
      if (map['staff'] == true && map['activated'] == true) {
        CustomSnackbar.showSuccess(
          title: 'boost_purchase_success_title'.tr,
          message: 'boost_purchase_success_msg'.tr,
        );
        await _loadBoostStatus();
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
                  ..._packages.map(_buildPackageCard),
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

  Widget _buildPackageCard(Map<String, dynamic> pkg) {
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
            onTap: _purchasing ? null : () => _purchaseBoost(tier),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InterText(
                          text: 'premium_choose_plan'.tr,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                        SizedBox(height: 4.h),
                        InterText(
                          text: 'premium_choose_plan_subtitle'.tr,
                          fontSize: 13.sp,
                          color: AppColors.greyText,
                        ),
                      ],
                    ),
                  ),
                  _buildCurrencyPicker(context, controller),
                ],
              ),
              SizedBox(height: 16.h),
              ...controller.plans.map((p) => _buildPlanCard(context, controller, p)),
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
                    text: 'Chat entre amis',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                  SizedBox(height: 3.h),
                  InterText(
                    text: alreadyActive
                        ? 'Actif · renouvelle le chat entre amis'
                        : 'Débloque le chat avec tes amis acceptés — 30 jours',
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

  Widget _buildStatusCard(BuildContext context, SubscriptionController controller) {
    final status = controller.status.value;
    final isPremium = status?.isPremium ?? false;
    final remainingDays = status?.remainingDays ?? 0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? const [Color(0xFFFFD700), Color(0xFFFF9500)]
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
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Center(
              child: Text(
                isPremium ? '⭐' : '🐾',
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
                  text: isPremium ? 'premium_active'.tr : 'premium_free_plan'.tr,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: isPremium ? Colors.white : AppColors.blackColor,
                ),
                SizedBox(height: 4.h),
                InterText(
                  text: isPremium
                      ? 'premium_remaining_days'.trParams({
                          'days': '$remainingDays',
                        })
                      : 'premium_upsell_text'.tr,
                  fontSize: 13.sp,
                  color: isPremium ? Colors.white.withValues(alpha: 0.9) : AppColors.greyText,
                ),
                if (isPremium && status!.cancelAtPeriodEnd) ...[
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: InterText(
                      text: "Annulation à la fin de la période",
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
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

  Widget _buildPlanCard(
    BuildContext context,
    SubscriptionController controller,
    SubscriptionPlan plan,
  ) {
    // v22.1 — 3 plans visuellement distincts : Mensuel ⭐ / Annuel 🏆 (gold)
    // / Famille 👨‍👩‍👧‍👦 (bleu — partage 5 membres).
    final isYearly = plan.plan == 'yearly';
    final isFamily = plan.plan == 'family';
    final savings = isYearly ? ' (35% off)' : '';
    final currentPlan = controller.status.value?.plan;
    final isCurrent = currentPlan == plan.plan && controller.isPremium;

    final accentColor = isFamily
        ? const Color(0xFF2196F3) // bleu famille
        : isYearly
            ? const Color(0xFFFFD700) // gold annuel
            : const Color(0xFFFFD700); // gold default

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
                color: Colors.white,
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
                          text: '${plan.label}$savings',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                        SizedBox(height: 4.h),
                        InterText(
                          text: isFamily
                              ? "Jusqu'à 5 membres • mensuel"
                              : isYearly
                                  ? 'Facturé 1x par an'
                                  : 'Facturé tous les mois',
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
                        color: const Color(0xFFFF9500),
                      ),
                      InterText(
                        text: '${CurrencyHelper.format(plan.currency, plan.amountPerDay)}/jour',
                        fontSize: 10.sp,
                        color: AppColors.greyText,
                      ),
                    ],
                  ),
                  SizedBox(width: 8.w),
                  Obx(() {
                    if (controller.isPurchasing.value) {
                      return SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF9500),
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
                  color: const Color(0xFFFFD700),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8.r),
                    bottomRight: Radius.circular(8.r),
                  ),
                ),
                child: InterText(
                  text: 'MEILLEUR PRIX',
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
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
                : const Color(0xFFFF9500);
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
        CustomSnackbar.showSuccess(
          title: 'Premium activé !',
          message: 'Profitez de toutes les fonctionnalités.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString();
      if (msg.contains('<!DOCTYPE') || msg.contains('<html')) {
        msg = 'Service indisponible.';
      }
      CustomSnackbar.showError(title: 'common_error'.tr, message: msg);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 3 — MAP BOOST (PawMap pin highlight)
// ═══════════════════════════════════════════════════════════════════════════
class _MapBoostTab extends StatefulWidget {
  const _MapBoostTab();

  @override
  State<_MapBoostTab> createState() => _MapBoostTabState();
}

class _MapBoostTabState extends State<_MapBoostTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final MapBoostController controller = Get.isRegistered<MapBoostController>()
        ? Get.find<MapBoostController>()
        : Get.put(MapBoostController());

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
              _buildMapBoostStatus(context, controller),
              SizedBox(height: 16.h),
              _buildPremiumCreditCard(context, controller),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InterText(
                          text: 'mapboost_header_title'.tr,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                        SizedBox(height: 4.h),
                        InterText(
                          text: 'mapboost_header_subtitle'.tr,
                          fontSize: 12.sp,
                          color: AppColors.greyText,
                        ),
                      ],
                    ),
                  ),
                  _buildCurrencyChip(context, controller),
                ],
              ),
              SizedBox(height: 16.h),
              ...controller.packages.map((p) => _buildPackageCard(context, controller, p)),
              SizedBox(height: 24.h),
              _buildHowItWorks(context),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildMapBoostStatus(BuildContext context, MapBoostController controller) {
    final status = controller.status.value;
    final isActive = status?.isActive ?? false;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? const [Color(0xFF43E97B), Color(0xFF38F9D7)]
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
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Center(
              child: Text(
                isActive ? '🗺️' : '📍',
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
                  text: isActive ? 'mapboost_active'.tr : 'mapboost_inactive'.tr,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppColors.blackColor,
                ),
                SizedBox(height: 4.h),
                InterText(
                  text: isActive
                      ? 'mapboost_remaining_days'.trParams({
                          'days': '${status!.remainingDays}',
                        })
                      : 'mapboost_pin_default'.tr,
                  fontSize: 12.sp,
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.9)
                      : AppColors.greyText,
                ),
                if (isActive && status!.tier != null) ...[
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: InterText(
                      text: status.tier!.toUpperCase(),
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

  Widget _buildPremiumCreditCard(BuildContext context, MapBoostController controller) {
    final credits = controller.status.value?.mapBoostCreditsRemaining ?? 0;
    if (credits <= 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF9500)],
        ),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Text('⭐', style: TextStyle(fontSize: 22.sp)),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: '$credits crédit(s) Premium disponible(s)',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: '1 crédit = 3 jours gratuits de Map Boost',
                  fontSize: 11.sp,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await controller.claimPremiumCredit();
              if (!mounted) return;
              if (ok) {
                CustomSnackbar.showSuccess(
                  title: 'Crédit utilisé',
                  message: '+3 jours de Map Boost appliqués.',
                );
              } else {
                CustomSnackbar.showError(
                  title: 'common_error'.tr,
                  message: 'Impossible d\'utiliser le crédit.',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFFF9500),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: InterText(
              text: 'Utiliser',
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFF9500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyChip(BuildContext context, MapBoostController controller) {
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
          items: const ['EUR', 'GBP', 'CHF', 'USD']
              .map((c) => DropdownMenuItem<String>(
                    value: c,
                    child: Text(c, style: TextStyle(fontSize: 12.sp)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) controller.setCurrency(v);
          },
        ),
      ),
    );
  }

  Widget _buildPackageCard(
    BuildContext context,
    MapBoostController controller,
    MapBoostPackage pkg,
  ) {
    // Session v15-4 — identité visuelle distincte du Boost :
    //   • pin cartographique animé (MapBoostPinIcon) au lieu des médailles
    //   • accent bleu-map (+ or sur gold/platinum) au lieu du rouge primaryColor
    //   • titres "Découverte / Visible / Pin Doré / Map Premium"
    //   • badge "Top map" sur gold
    //   • sous-titre descriptif sous le titre pour clarifier la valeur
    final tierAccent = _mapBoostTierAccent(pkg.tier);
    final isPopular = pkg.tier == 'gold';
    final isPurchasing = controller.isPurchasing.value;
    final sym = CurrencyHelper.symbol(pkg.currency);
    final pricePerDay = pkg.days > 0 ? (pkg.amount / pkg.days) : pkg.amount;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Stack(
        children: [
          GestureDetector(
            onTap: isPurchasing
                ? null
                : () => _handlePurchase(context, controller, pkg.tier),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: isPopular
                    ? Border.all(color: AppColors.mapBoostGold, width: 2)
                    : null,
                boxShadow: isPopular
                    ? [
                        BoxShadow(
                          color: AppColors.mapBoostGold
                              .withValues(alpha: 0.18),
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
              child: Row(
                children: [
                  Container(
                    width: 54.w,
                    height: 54.w,
                    decoration: BoxDecoration(
                      color: tierAccent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Center(
                      child: MapBoostPinIcon(tier: pkg.tier, size: 48),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InterText(
                          text: _mapBoostTierLabel(pkg.tier),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                        SizedBox(height: 2.h),
                        InterText(
                          text: _mapBoostTierDescription(pkg.tier),
                          fontSize: 11.sp,
                          color: AppColors.greyText,
                          maxLines: 2,
                        ),
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: tierAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: InterText(
                            text:
                                '${pkg.days} jour${pkg.days > 1 ? "s" : ""}',
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: tierAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      PoppinsText(
                        text: '$sym${pkg.amount.toStringAsFixed(2)}',
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: tierAccent,
                      ),
                      InterText(
                        text:
                            '$sym${pricePerDay.toStringAsFixed(2)}/${'boost_per_day'.tr}',
                        fontSize: 10.sp,
                        color: AppColors.greyText,
                      ),
                    ],
                  ),
                  SizedBox(width: 8.w),
                  isPurchasing
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: tierAccent),
                        )
                      : Icon(Icons.arrow_forward_ios,
                          size: 16.sp, color: AppColors.greyText),
                ],
              ),
            ),
          ),
          if (isPopular)
            Positioned(
              top: 0,
              right: 16.w,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.mapBoostGold,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8.r),
                    bottomRight: Radius.circular(8.r),
                  ),
                ),
                child: InterText(
                  text: 'Top map',
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

  /// Colour accent used on the Map Boost package card per tier. Blue for
  /// the entry tiers, gold for the premium tiers so there's a gentle
  /// progression that doesn't look like the Boost tab's medals.
  Color _mapBoostTierAccent(String tier) {
    switch (tier.toLowerCase()) {
      case 'bronze':
        return const Color(0xFF60A5FA);
      case 'silver':
        return AppColors.mapBoostBlue;
      case 'gold':
        return AppColors.mapBoostGold;
      case 'platinum':
      case 'diamond':
        return AppColors.mapBoostGoldDeep;
      default:
        return AppColors.mapBoostBlue;
    }
  }

  /// Short value-prop shown under the tier title. Helps the user pick
  /// without having to scroll through the "Comment fonctionne" section.
  String _mapBoostTierDescription(String tier) {
    switch (tier.toLowerCase()) {
      case 'bronze':
        return 'Testez la visibilité carte';
      case 'silver':
        return 'Pin surligné, portée moyenne';
      case 'gold':
        return 'Pin doré, top des résultats carte';
      case 'platinum':
      case 'diamond':
        return 'Pin doré + halo animé permanent';
      default:
        return '';
    }
  }

  Widget _buildHowItWorks(BuildContext context) {
    // Session v15 — icônes plus parlantes + textes raccourcis / clarifiés.
    // L'ancien set utilisait 4 icônes très proches visuellement (rond plein,
    // tiret montant, étoile…), ce qui brouillait la lecture. Passage à un
    // pin + œil + courbe + flèche de recyclage pour mieux différencier.
    // v19.1.5 — i18n so the "How Map Boost works" list is translated instead
    // of staying in French.
    final steps = [
      {
        'icon': Icons.push_pin_rounded,
        'text': 'mapboost_how_step_1'.tr,
      },
      {
        'icon': Icons.remove_red_eye_rounded,
        'text': 'mapboost_how_step_2'.tr,
      },
      {
        'icon': Icons.query_stats_rounded,
        'text': 'mapboost_how_step_3'.tr,
      },
      {
        'icon': Icons.autorenew_rounded,
        'text': 'mapboost_how_step_4'.tr,
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
            text: 'mapboost_how_title'.tr,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 12.h),
          ...steps.map((s) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28.w,
                      height: 28.w,
                      decoration: BoxDecoration(
                        color:
                            AppColors.mapBoostBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        s['icon'] as IconData,
                        size: 16.sp,
                        color: AppColors.mapBoostBlue,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: InterText(
                        text: s['text'] as String,
                        fontSize: 13.sp,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  /// Session v15-4 — tier labels renamed to drop the medal metaphor
  /// (bronze/silver/gold/diamond) and sound like a map visibility progression.
  /// The tier *keys* stay bronze/silver/gold/platinum for backend compat;
  /// only the display label changes here.
  String _mapBoostTierLabel(String tier) {
    switch (tier.toLowerCase()) {
      case 'bronze':
        return 'mapboost_tier_bronze'.tr;
      case 'silver':
        return 'mapboost_tier_silver'.tr;
      case 'gold':
        return 'mapboost_tier_gold'.tr;
      case 'platinum':
      case 'diamond':
        return 'mapboost_tier_platinum'.tr;
      default:
        return tier;
    }
  }

  Future<void> _handlePurchase(
    BuildContext context,
    MapBoostController controller,
    String tier,
  ) async {
    try {
      await controller.purchase(tier);
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'map_boost_purchase_success'.tr,
      );
    } catch (e) {
      debugPrint('MapBoost purchase failed: $e');
      if (!mounted) return;
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'map_boost_purchase_failed'.tr,
      );
    }
  }
}
