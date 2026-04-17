import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// Coin Shop — Buy dog coins to boost your profile to the top of feed.
/// Works for both pet owners and pet sitters.
class CoinShopScreen extends StatefulWidget {
  const CoinShopScreen({super.key});

  @override
  State<CoinShopScreen> createState() => _CoinShopScreenState();
}

class _CoinShopScreenState extends State<CoinShopScreen> {
  bool _loading = true;
  bool _purchasing = false;
  String? _selectedTier;

  // Boost status
  bool _boostActive = false;
  String? _currentTier;
  int _remainingDays = 0;
  List<dynamic> _history = [];

  // Packages
  final List<Map<String, dynamic>> _packages = [
    {'tier': 'bronze', 'amount': 25, 'days': 3, 'icon': '🥉', 'label': '3 days', 'color': const Color(0xFFCD7F32)},
    {'tier': 'silver', 'amount': 50, 'days': 7, 'icon': '🥈', 'label': '1 week', 'color': const Color(0xFFC0C0C0)},
    {'tier': 'gold', 'amount': 100, 'days': 15, 'icon': '🥇', 'label': '2 weeks', 'color': const Color(0xFFFFD700)},
    {'tier': 'platinum', 'amount': 200, 'days': 30, 'icon': '💎', 'label': '1 month', 'color': const Color(0xFFE5E4E2)},
  ];

  @override
  void initState() {
    super.initState();
    _loadBoostStatus();
  }

  Future<void> _loadBoostStatus() async {
    setState(() => _loading = true);
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get('/boost/status');
      final map = data as Map<String, dynamic>;
      setState(() {
        _boostActive = map['isActive'] == true;
        _currentTier = map['tier'];
        _remainingDays = map['remainingDays'] ?? 0;
        _history = map['purchaseHistory'] as List<dynamic>? ?? [];
      });
    } catch (_) {
      // No boost yet
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _purchaseBoost(String tier) async {
    setState(() {
      _purchasing = true;
      _selectedTier = tier;
    });

    try {
      final api = Get.find<ApiClient>();

      // 1. Create PaymentIntent on backend
      final piData = await api.post('/boost/purchase', body: {'tier': tier});
      final map = piData as Map<String, dynamic>;
      final clientSecret = map['clientSecret'] as String?;
      final paymentIntentId = map['paymentIntentId'] as String?;

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Failed to create payment intent.');
      }

      // 2. Present Stripe payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'HopeTSIT - Coin Shop',
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // 3. Confirm boost on backend
      await api.post('/boost/confirm', body: {
        'tier': tier,
        'paymentIntentId': paymentIntentId,
      });

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
      // Parse error message — strip raw HTML if backend returned an HTML error page
      String errorMsg = e.toString();
      if (errorMsg.contains('<!DOCTYPE') || errorMsg.contains('<html')) {
        errorMsg = 'boost_service_unavailable'.tr;
      } else if (errorMsg.contains('404')) {
        errorMsg = 'boost_service_unavailable'.tr;
      }
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: errorMsg,
      );
    } finally {
      setState(() {
        _purchasing = false;
        _selectedTier = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBoostStatus,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Current boost status ──
                    _buildBoostStatus(),
                    SizedBox(height: 20.h),

                    // ── Section title ──
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

                    // ── Package cards ──
                    ..._packages.map((pkg) => _buildPackageCard(pkg)),

                    SizedBox(height: 20.h),

                    // ── How it works ──
                    _buildHowItWorks(),

                    // ── Purchase history ──
                    if (_history.isNotEmpty) ...[
                      SizedBox(height: 20.h),
                      _buildPurchaseHistory(),
                    ],

                    SizedBox(height: 40.h),
                  ],
                ),
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
                  text: _boostActive
                      ? 'boost_status_active'.tr
                      : 'boost_status_inactive'.tr,
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
                  color: _boostActive
                      ? Colors.white.withOpacity(0.85)
                      : AppColors.greyText,
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
                  // Icon
                  Container(
                    width: 50.w,
                    height: 50.w,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: Text(icon, style: TextStyle(fontSize: 26.sp)),
                    ),
                  ),
                  SizedBox(width: 14.w),

                  // Details
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

                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      PoppinsText(
                        text: '€$amount',
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryColor,
                      ),
                      InterText(
                        text: '€${(amount / days).toStringAsFixed(1)}/${'boost_per_day'.tr}',
                        fontSize: 10.sp,
                        color: AppColors.greyText,
                      ),
                    ],
                  ),

                  SizedBox(width: 8.w),

                  // Buy arrow or loading
                  isSelected && _purchasing
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryColor,
                          ),
                        )
                      : Icon(
                          Icons.arrow_forward_ios,
                          size: 16.sp,
                          color: AppColors.greyText,
                        ),
                ],
              ),
            ),
          ),

          // Popular badge
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
          ...steps.asMap().entries.map((entry) {
            final step = entry.value;
            return Padding(
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
                    child: Icon(
                      step['icon'] as IconData,
                      size: 16.sp,
                      color: AppColors.primaryColor,
                    ),
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
            );
          }),
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
                  text: '€${map['amount'] ?? 0}',
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
