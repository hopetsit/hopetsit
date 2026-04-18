import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/stripe_connect_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';
import 'package:shimmer/shimmer.dart';

/// Mandatory screen for Pet Sitters to connect their payment account
/// This screen appears after service selection and blocks further navigation
/// until payment is successfully connected.
class ConnectPaymentScreen extends StatefulWidget {
  const ConnectPaymentScreen({super.key});

  @override
  State<ConnectPaymentScreen> createState() => _ConnectPaymentScreenState();
}

class _ConnectPaymentScreenState extends State<ConnectPaymentScreen>
    with WidgetsBindingObserver, RouteAware {
  late StripeConnectController _controller;
  bool _hasCheckedInitialStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh status when screen becomes visible (e.g., returning from webview)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_controller.isLoadingStatus.value) {
        // Small delay to ensure any navigation has completed
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _checkPaymentStatus();
          }
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app comes back to foreground, check payment status
    if (state == AppLifecycleState.resumed && mounted) {
      _checkPaymentStatus();
    }
  }

  Future<void> _checkPaymentStatus() async {
    await _controller.checkAccountStatus();

    // Debug logging
    debugPrint('[ConnectPaymentScreen] Status check:');
    debugPrint('  - Account ID: ${_controller.stripeAccountId.value}');
    debugPrint('  - Is Connected: ${_controller.isConnected.value}');
    debugPrint('  - Account Status: ${_controller.accountStatus.value}');

    // Only auto-navigate if fully connected
    // If account exists but not fully connected, allow user to proceed manually
    if (_controller.isConnected.value && mounted) {
      debugPrint(
        '[ConnectPaymentScreen] Account fully connected, navigating to dashboard',
      );
      _navigateToDashboard();
    } else if (_controller.stripeAccountId.value.isNotEmpty) {
      debugPrint(
        '[ConnectPaymentScreen] Account exists but not fully connected - showing "Go to Home" button',
      );
    }
  }

  void _initializeController() {
    // Get or create the Stripe Connect controller
    if (Get.isRegistered<StripeConnectController>()) {
      _controller = Get.find<StripeConnectController>();
    } else {
      _controller = Get.put(StripeConnectController());
    }

    // Listen to connection status changes - only auto-navigate if fully connected
    ever(_controller.isConnected, (bool isConnected) {
      if (isConnected && mounted) {
        // Only auto-navigate if fully connected
        _navigateToDashboard();
      }
    });

    // Check initial status after a short delay to ensure controller is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialStatus();
    });
  }

  Future<void> _checkInitialStatus() async {
    if (_hasCheckedInitialStatus) return;
    _hasCheckedInitialStatus = true;

    // Wait for initial status check to complete
    await Future.delayed(const Duration(milliseconds: 500));

    // Only auto-navigate if fully connected
    // If account exists but not fully connected, let user proceed manually
    if (_controller.isConnected.value) {
      _navigateToDashboard();
    } else {
      // Refresh status to ensure we have the latest
      await _controller.checkAccountStatus();
      // Only auto-navigate if fully connected
      if (_controller.isConnected.value && mounted) {
        _navigateToDashboard();
      }
      // If account exists but not fully connected, show message and allow manual navigation
    }
  }

  void _navigateToDashboard() {
    // Clean up any previous controllers
    Get.delete<StripeConnectController>(force: true);

    // Navigate to sitter dashboard
    Get.offAll(() => const SitterNavWrapper());
  }

  Future<void> _handleConnectPayment() async {
    // Always fetch a fresh onboarding URL when Connect Now is tapped
    // Clear any existing onboarding URL and expiration to force fetching a new one
    _controller.onboardingUrl.value = '';
    _controller.expiresAt.value = 0;

    // Fetch fresh onboarding URL - this will create a new onboarding session
    // The connectStripe() method will:
    // 1. Call the API to create/get a new onboarding session
    // 2. Navigate to the webview automatically
    // 3. Check account status when returning from webview
    await _controller.connectStripe();

    // After returning from webview, refresh status to check if account is now connected
    // Wait a bit for any navigation to complete
    await Future.delayed(const Duration(milliseconds: 500));
    await _checkPaymentStatus();

    // Status checking is handled by:
    // - The ever() listener on isConnected (auto-navigates when fully connected)
    // - The didChangeAppLifecycleState (checks when app resumes)
    // - Manual check after webview returns (above)
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          false, // Prevent back navigation - payment connection is mandatory
      child: Scaffold(
        backgroundColor: AppColors.scaffold(context),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 40.h),

                // Icon
                Center(
                  child: Container(
                    width: 100.w,
                    height: 100.h,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      size: 50.sp,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),

                SizedBox(height: 32.h),

                // Title
                Center(
                  child: PoppinsText(
                    text: 'stripe_connect_payment_title'.tr,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: 16.h),

                // Description - Dynamic based on account status
                Obx(() {
                  final hasAccount =
                      _controller.stripeAccountId.value.isNotEmpty;
                  final isFullyConnected = _controller.isConnected.value;

                  if (hasAccount && !isFullyConnected) {
                    // Account exists but not fully connected
                    return InterText(
                      text: 'stripe_connect_payment_partial_description'.tr,
                      fontSize: 14.sp,
                      color: AppColors.grey700Color,
                      textAlign: TextAlign.center,
                    );
                  }

                  // Default message for new accounts
                  return InterText(
                    text: 'stripe_connect_payment_description'.tr,
                    fontSize: 14.sp,
                    color: AppColors.grey700Color,
                    textAlign: TextAlign.center,
                  );
                }),

                SizedBox(height: 32.h),

                // Benefits List
                _buildBenefitsList(),

                SizedBox(height: 32.h),

                // Account Status Card (if account exists)
                Obx(() {
                  if (_controller.isLoadingStatus.value) {
                    return _buildAccountStatusShimmer();
                  } else if (_controller.stripeAccountId.value.isNotEmpty) {
                    return _buildAccountStatusCard();
                  }
                  return const SizedBox.shrink();
                }),

                // Partial onboarding message (if account exists but not fully connected)
                Obx(() {
                  final hasAccount =
                      _controller.stripeAccountId.value.isNotEmpty;
                  final isFullyConnected = _controller.isConnected.value;

                  if (hasAccount &&
                      !isFullyConnected &&
                      !_controller.isLoadingStatus.value) {
                    return Padding(
                      padding: EdgeInsets.only(top: 16.h),
                      child: Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: Colors.orange, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                              size: 20.sp,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: InterText(
                                text: 'stripe_connect_payment_partial_info'.tr,
                                fontSize: 13.sp,
                                color: AppColors.grey700Color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),

                SizedBox(height: 32.h),

                // Connect/Go to Home Button
                Obx(() {
                  final isLoading =
                      _controller.isConnecting.value ||
                      _controller.isLoadingStatus.value;
                  final isConnected = _controller.isConnected.value;
                  final hasAccount =
                      _controller.stripeAccountId.value.isNotEmpty;

                  if (isConnected) {
                    // Show success state briefly before navigation
                    return Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 24.sp,
                          ),
                          SizedBox(width: 12.w),
                          PoppinsText(
                            text: 'stripe_payment_connected_success'.tr,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    );
                  }

                  // If account exists but not fully connected, show "Go to Home" button
                  if (hasAccount && !isConnected) {
                    return CustomButton(
                      title: isLoading ? null : 'common_go_to_home'.tr,
                      onTap: isLoading ? null : _navigateToDashboard,
                      bgColor: AppColors.primaryColor,
                      textColor: AppColors.whiteColor,
                      height: 56.h,
                      radius: 56.r,
                      child: isLoading
                          ? SizedBox(
                              height: 24.h,
                              width: 24.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.whiteColor,
                                ),
                              ),
                            )
                          : null,
                    );
                  }

                  // Default: Connect Now button for new accounts
                  return CustomButton(
                    title: isLoading ? null : 'Connect Now',
                    onTap: isLoading ? null : _handleConnectPayment,
                    bgColor: AppColors.primaryColor,
                    textColor: AppColors.whiteColor,
                    height: 56.h,
                    radius: 56.r,
                    child: isLoading
                        ? SizedBox(
                            height: 24.h,
                            width: 24.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.whiteColor,
                              ),
                            ),
                          )
                        : null,
                  );
                }),

                // Optional skip action for signup flow
                Obx(() {
                  final isLoading =
                      _controller.isConnecting.value ||
                      _controller.isLoadingStatus.value;
                  final isConnected = _controller.isConnected.value;
                  if (isConnected) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: EdgeInsets.only(top: 12.h),
                    child: Center(
                      child: TextButton(
                        onPressed: isLoading ? null : _navigateToDashboard,
                        child: InterText(
                          text: 'Set it later',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ),
                  );
                }),

                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsList() {
    final benefits = [
      'stripe_benefit_secure'.tr,
      'stripe_benefit_fast_payouts'.tr,
      'stripe_benefit_no_fees'.tr,
      'stripe_benefit_required'.tr,
    ];

    return Column(
      children: benefits.map((benefit) {
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.divider(context), width: 1),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                size: 20.sp,
                color: AppColors.primaryColor,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: InterText(
                  text: benefit,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAccountStatusShimmer() {
    return Builder(
      builder: (context) => Shimmer.fromColors(
        baseColor: AppColors.grey300Color,
        highlightColor: AppColors.card(context),
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.divider(context), width: 1),
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24.sp,
                  height: 24.sp,
                  decoration: BoxDecoration(
                    color: AppColors.grey300Color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Container(
                    height: 16.sp,
                    decoration: BoxDecoration(
                      color: AppColors.grey300Color,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Container(
              height: 12.sp,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.grey300Color,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildAccountStatusCard() {
    return Obx(
      () => Builder(
        builder: (context) => Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: _controller.isConnected.value ? Colors.green : Colors.orange,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _controller.isConnected.value
                        ? Icons.check_circle
                        : Icons.pending,
                    color: _controller.isConnected.value
                        ? Colors.green
                        : Colors.orange,
                    size: 24.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: PoppinsText(
                      text: _controller.isConnected.value
                          ? 'stripe_account_connected'.tr
                          : 'stripe_account_created'.tr,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              InterText(
                text: _controller.isConnected.value
                    ? 'stripe_account_connected_message'.tr
                    : 'stripe_account_created_partial_message'.tr,
                fontSize: 14.sp,
                color: AppColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
