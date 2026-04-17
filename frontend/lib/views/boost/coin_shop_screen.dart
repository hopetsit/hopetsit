import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/map_boost_controller.dart';
import 'package:hopetsit/controllers/subscription_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// Boutique screen — 3 tabs:
///   1. Boost     — one-time profile boost (existing feature)
///   2. Premium   — PawMap Premium subscription (€3.90/mo or €30/yr)
///   3. Map Boost — placeholder for Phase 5 (map visibility boost)
///
/// Available for the 3 roles: Owner, Sitter, Walker.
class CoinShopScreen extends StatefulWidget {
  const CoinShopScreen({super.key});

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

    return DefaultTabController(
      length: 3,
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
            tabs: const [
              Tab(icon: Icon(Icons.trending_up, size: 20), text: 'Boost'),
              Tab(icon: Icon(Icons.star_rounded, size: 22), text: 'Premium'),
              Tab(icon: Icon(Icons.map_outlined, size: 20), text: 'Map Boost'),
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

  final List<Map<String, dynamic>> _packages = [
    {'tier': 'bronze', 'amount': 25, 'days': 3, 'icon': '🥉', 'label': '3 days', 'color': const Color(0xFFCD7F32)},
    {'tier': 'silver', 'amount': 50, 'days': 7, 'icon': '🥈', 'label': '1 week', 'color': const Color(0xFFC0C0C0)},
    {'tier': 'gold', 'amount': 100, 'days': 15, 'icon': '🥇', 'label': '2 weeks', 'color': const Color(0xFFFFD700)},
    {'tier': 'platinum', 'amount': 200, 'days': 30, 'icon': '💎', 'label': '1 month', 'color': const Color(0xFFE5E4E2)},
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadBoostStatus();
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
        _currentTier = map['tier'];
        _remainingDays = map['remainingDays'] ?? 0;
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
      final clientSecret = map['clientSecret'] as String?;
      final paymentIntentId = map['paymentIntentId'] as String?;

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Failed to create payment intent.');
      }

      final pk = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
      if (pk.isNotEmpty && Stripe.publishableKey.isEmpty) {
        Stripe.publishableKey = pk;
        await Stripe.instance.applySettings();
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'HopeTSIT - Coin Shop',
          style: ThemeMode.system,
        ),
      );
      await Stripe.instance.presentPaymentSheet();

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
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: e.error.localizedMessage ?? 'boost_purchase_error'.tr,
        );
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('StripeConfigException') ||
          errorMsg.contains('Stripe has not been correctly initialized')) {
        errorMsg =
            'Erreur de configuration Stripe. Ferme et relance l\'application, puis réessaie.';
      } else if (errorMsg.contains('<!DOCTYPE') || errorMsg.contains('<html')) {
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
              ? [AppColors.primaryColor, AppColors.primaryColor.withOpacity(0.7)]
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
              color: Colors.white.withOpacity(0.2),
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
                  color: _boostActive ? Colors.white.withOpacity(0.85) : AppColors.greyText,
                ),
                if (_boostActive && _currentTier != null) ...[
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
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
    final amount = pkg['amount'] as int;
    final days = pkg['days'] as int;
    final icon = pkg['icon'] as String;
    final label = pkg['label'] as String;
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
                    ? [BoxShadow(color: AppColors.primaryColor.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50.w,
                    height: 50.w,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
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
                                color: AppColors.primaryColor.withOpacity(0.1),
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
                        color: AppColors.primaryColor.withOpacity(0.1),
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
                          text: 'Choisir un forfait Premium',
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                        SizedBox(height: 4.h),
                        InterText(
                          text: 'Débloquez la PawMap complète et le social',
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
              _buildFeaturesList(context),
              SizedBox(height: 40.h),
            ],
          ),
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
              color: Colors.white.withOpacity(0.25),
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
                  text: isPremium ? 'Premium actif' : 'Plan gratuit',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: isPremium ? Colors.white : AppColors.blackColor,
                ),
                SizedBox(height: 4.h),
                InterText(
                  text: isPremium
                      ? 'Il vous reste $remainingDays jours'
                      : 'Passez Premium pour débloquer toutes les fonctionnalités',
                  fontSize: 13.sp,
                  color: isPremium ? Colors.white.withOpacity(0.9) : AppColors.greyText,
                ),
                if (isPremium && status!.cancelAtPeriodEnd) ...[
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
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
    final isYearly = plan.plan == 'yearly';
    final savings = isYearly ? ' (35% off)' : '';
    final currentPlan = controller.status.value?.plan;
    final isCurrent = currentPlan == plan.plan && controller.isPremium;

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
                border: isYearly
                    ? Border.all(color: const Color(0xFFFFD700), width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isYearly
                        ? const Color(0xFFFFD700).withOpacity(0.15)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: isYearly ? 12 : 10,
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
                      color: const Color(0xFFFFD700).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: Text(
                        isYearly ? '🏆' : '⭐',
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
                          text: isYearly
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
    final features = [
      {'icon': Icons.map_outlined, 'text': 'PawMap complète — vétos, parcs, boutiques, points d\'eau'},
      {'icon': Icons.warning_amber_rounded, 'text': 'Signalements 48h — caca, pipi, dangers, points d\'eau actifs'},
      {'icon': Icons.chat_bubble_outline, 'text': 'Chat avec les utilisateurs croisés sur la map'},
      {'icon': Icons.people_outline, 'text': 'Suivi d\'amis en temps réel (façon Waze)'},
      {'icon': Icons.notifications_active_outlined, 'text': 'Notifications de proximité'},
      {'icon': Icons.trending_up, 'text': '1 boost map inclus par mois'},
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
            text: 'Ce que Premium débloque',
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 12.h),
          ...features.map((f) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        f['icon'] as IconData,
                        size: 16.sp,
                        color: const Color(0xFFFF9500),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: InterText(
                        text: f['text'] as String,
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
    } on StripeException catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.error.localizedMessage ?? 'Paiement échoué.',
      );
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString();
      if (msg.contains('StripeConfigException') ||
          msg.contains('Stripe has not been correctly initialized')) {
        msg =
            'Erreur de configuration Stripe. Ferme et relance l\'application, puis réessaie.';
      } else if (msg.contains('<!DOCTYPE') || msg.contains('<html')) {
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
                          text: 'Booster mon pin sur la map',
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                        SizedBox(height: 4.h),
                        InterText(
                          text: 'Pin surligné sur la PawMap — les voisins vous voient en premier',
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
              color: Colors.white.withOpacity(0.25),
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
                  text: isActive ? 'Map Boost actif' : 'Map Boost inactif',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppColors.blackColor,
                ),
                SizedBox(height: 4.h),
                InterText(
                  text: isActive
                      ? 'Il vous reste ${status!.remainingDays} jour(s)'
                      : 'Votre pin s\'affiche en taille normale',
                  fontSize: 12.sp,
                  color: isActive
                      ? Colors.white.withOpacity(0.9)
                      : AppColors.greyText,
                ),
                if (isActive && status!.tier != null) ...[
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
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
                  color: Colors.white.withOpacity(0.95),
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
    final tierColor = {
      'bronze': const Color(0xFFCD7F32),
      'silver': const Color(0xFFC0C0C0),
      'gold': const Color(0xFFFFD700),
      'platinum': const Color(0xFFE5E4E2),
    }[pkg.tier] ?? AppColors.primaryColor;
    final icon = {
      'bronze': '🥉',
      'silver': '🥈',
      'gold': '🥇',
      'platinum': '💎',
    }[pkg.tier] ?? '🗺️';
    final isPopular = pkg.tier == 'gold';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Stack(
        children: [
          GestureDetector(
            onTap: controller.isPurchasing.value
                ? null
                : () => _handlePurchase(context, controller, pkg.tier),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: isPopular ? Border.all(color: AppColors.primaryColor, width: 2) : null,
                boxShadow: [
                  BoxShadow(
                    color: isPopular
                        ? AppColors.primaryColor.withOpacity(0.15)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: isPopular ? 12 : 10,
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
                      color: tierColor.withOpacity(0.15),
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
                              text: pkg.tier[0].toUpperCase() + pkg.tier.substring(1),
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(context),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: InterText(
                                text: '${pkg.days} j',
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        InterText(
                          text: 'Pin surligné pendant ${pkg.label}',
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
                        text: CurrencyHelper.format(pkg.currency, pkg.amount, decimals: 0),
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryColor,
                      ),
                      InterText(
                        text: '${CurrencyHelper.format(pkg.currency, pkg.pricePerDay)}/jour',
                        fontSize: 10.sp,
                        color: AppColors.greyText,
                      ),
                    ],
                  ),
                  SizedBox(width: 8.w),
                  controller.isPurchasing.value
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryColor,
                          ),
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
                  text: 'POPULAIRE',
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

  Widget _buildHowItWorks(BuildContext context) {
    final steps = [
      {'icon': Icons.shopping_cart, 'text': 'Choisir un forfait Map Boost'},
      {'icon': Icons.payment, 'text': 'Payer par carte (CB / Apple Pay / Google Pay)'},
      {'icon': Icons.highlight, 'text': 'Votre pin est surligné en couleur sur la PawMap'},
      {'icon': Icons.visibility, 'text': 'Les voisins vous voient en premier dans leur zone'},
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
            text: 'Comment ça marche',
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 12.h),
          ...steps.map((s) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Row(
                  children: [
                    Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(s['icon'] as IconData, size: 16.sp, color: AppColors.primaryColor),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: InterText(
                        text: s['text'] as String,
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

  Future<void> _handlePurchase(
    BuildContext context,
    MapBoostController controller,
    String tier,
  ) async {
    try {
      final ok = await controller.purchase(tier);
      if (!mounted) return;
      if (ok) {
        CustomSnackbar.showSuccess(
          title: 'Map Boost activé !',
          message: 'Votre pin est maintenant surligné sur la PawMap.',
        );
      }
    } on StripeException catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.error.localizedMessage ?? 'Paiement échoué.',
      );
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString();
      if (msg.contains('StripeConfigException') ||
          msg.contains('Stripe has not been correctly initialized')) {
        msg =
            'Erreur de configuration Stripe. Ferme et relance l\'application, puis réessaie.';
      } else if (msg.contains('<!DOCTYPE') || msg.contains('<html')) {
        msg = 'Service indisponible.';
      }
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: msg,
      );
    }
  }
}
