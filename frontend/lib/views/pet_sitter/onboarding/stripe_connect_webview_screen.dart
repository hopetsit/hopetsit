import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/stripe_connect_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/pet_sitter/payment/payout_status_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Screen that displays Stripe Connect onboarding in a webview
class StripeConnectWebviewScreen extends StatefulWidget {
  final String onboardingUrl;
  final String accountId;

  const StripeConnectWebviewScreen({
    super.key,
    required this.onboardingUrl,
    required this.accountId,
  });

  @override
  State<StripeConnectWebviewScreen> createState() =>
      _StripeConnectWebviewScreenState();
}

class _StripeConnectWebviewScreenState
    extends State<StripeConnectWebviewScreen> {
  late final WebViewController _controller;
  final RxBool isLoading = true.obs;
  final RxString currentUrl = ''.obs;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    AppLogger.logInfo(
      'Stripe Connect WebView initializing',
      data: {
        'onboardingUrl': widget.onboardingUrl,
        'accountId': widget.accountId,
      },
    );

    final uri = Uri.tryParse(widget.onboardingUrl);
    if (uri == null) {
      AppLogger.logError(
        'Stripe Connect: invalid onboarding URL',
        error: widget.onboardingUrl,
      );
      if (mounted) {
        Get.back();
        Get.snackbar(
          'common_error'.tr,
          'stripe_onboarding_load_error'.tr.replaceAll(
            '@error',
            'snackbar_text_invalid_url'.tr,
          ),
          backgroundColor: AppColors.errorColor,
          colorText: AppColors.whiteColor,
        );
      }
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            AppLogger.logDebug('Stripe Connect WebView page started: $url');
            isLoading.value = true;
            currentUrl.value = url;
            _handleNavigation(url);
          },
          onPageFinished: (String url) {
            AppLogger.logDebug('Stripe Connect WebView page finished: $url');
            isLoading.value = false;
            currentUrl.value = url;
          },
          onWebResourceError: (WebResourceError error) {
            isLoading.value = false;
            _handleError(error);
          },
        ),
      )
      ..loadRequest(uri);
  }

  void _handleNavigation(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      AppLogger.logError(
        'Stripe Connect: failed to parse navigation URL',
        error: url,
      );
      return;
    }

    final path = uri.path.toLowerCase();
    final queryParams = uri.queryParameters;

    AppLogger.logDebug('Stripe Connect navigation', tag: 'StripeWebView');
    AppLogger.logInfo(
      'Stripe Connect URL',
      data: {'url': url, 'path': path, 'queryParams': queryParams},
    );

    // Close WebView when Stripe redirects to our (dev) return URL
    if (uri.host == 'localhost' && uri.path == '/stripe-connect/return') {
      AppLogger.logInfo(
        'Stripe Connect: reached localhost return URL, closing webview',
      );
      if (mounted) {
        Get.back();
      }
      return;
    }

    // Check if URL indicates completion
    if (path.contains('success') ||
        path.contains('complete') ||
        path.contains('onboarding_complete') ||
        queryParams.containsKey('onboarding_complete') ||
        queryParams['redirect_status'] == 'succeeded') {
      AppLogger.logInfo('Stripe Connect: onboarding success detected from URL');
      _handleOnboardingSuccess();
      return;
    }

    // Check if URL indicates cancellation
    if (path.contains('cancel') ||
        path.contains('cancelled') ||
        queryParams['redirect_status'] == 'cancelled') {
      AppLogger.logInfo(
        'Stripe Connect: onboarding cancelled detected from URL',
      );
      _handleOnboardingCancelled();
      return;
    }

    // Check if we're back at the app's return URL (if configured)
    if (url.startsWith('hopetsit://') || url.contains('return_url')) {
      if (queryParams['status'] == 'success' ||
          queryParams['onboarding_complete'] == 'true') {
        AppLogger.logInfo('Stripe Connect: success from return URL');
        _handleOnboardingSuccess();
      } else if (queryParams['status'] == 'cancel') {
        AppLogger.logInfo('Stripe Connect: cancel from return URL');
        _handleOnboardingCancelled();
      }
    }
  }

  void _handleOnboardingSuccess() async {
    AppLogger.logInfo('Stripe Connect: handling onboarding success');

    if (Get.isRegistered<StripeConnectController>()) {
      final controller = Get.find<StripeConnectController>();

      try {
        await controller.checkAccountStatus();
        AppLogger.logInfo(
          'Stripe Connect: account status checked successfully',
        );
      } catch (e, stackTrace) {
        AppLogger.logError(
          'Stripe Connect: checkAccountStatus failed',
          error: e,
          stackTrace: stackTrace,
        );
        if (mounted) {
          Get.snackbar(
            'common_error'.tr,
            'stripe_onboarding_load_error'.tr.replaceAll(
              '@error',
              e.toString(),
            ),
            backgroundColor: AppColors.errorColor,
            colorText: AppColors.whiteColor,
          );
        }
      }

      if (!mounted) return;
      Get.back(); // Close webview

      Get.snackbar(
        'common_success'.tr,
        'stripe_account_connected_success'.tr,
        backgroundColor: Colors.green,
        colorText: AppColors.whiteColor,
        duration: const Duration(seconds: 3),
      );

      Get.off(() => const PayoutStatusScreen());
    } else {
      AppLogger.logError(
        'Stripe Connect: StripeConnectController not registered on success',
      );
      Get.back();
      Get.snackbar(
        'common_success'.tr,
        'stripe_onboarding_completed'.tr,
        backgroundColor: Colors.green,
        colorText: AppColors.whiteColor,
      );
    }
  }

  void _handleOnboardingCancelled() {
    AppLogger.logInfo('Stripe Connect: onboarding cancelled by user');
    Get.back();
    Get.snackbar(
      'common_cancelled'.tr,
      'stripe_onboarding_cancelled'.tr,
      backgroundColor: Colors.orange,
      colorText: AppColors.whiteColor,
    );
  }

  void _handleError(WebResourceError error) {
    AppLogger.logError(
      'Stripe Connect WebView resource error',
      error:
          'code: ${error.errorCode}, type: ${error.errorType}, '
          'description: ${error.description}',
    );

    // If you want to be conservative, only close on obvious fatal/main-frame errors.
    // Otherwise, you can just return here and NOT close the WebView.
    // Example: ignore subresource errors and stay in the flow.
    if (error.isForMainFrame != true) {
      return;
    }

    // Optionally show a non-fatal toast/snackbar without closing:
    if (mounted) {
      Get.snackbar(
        'common_error'.tr,
        'stripe_onboarding_load_error'.tr.replaceAll(
          '@error',
          error.description.isNotEmpty
              ? error.description
              : 'snackbar_text_unknown_error'.tr,
        ),
        backgroundColor: AppColors.errorColor,
        colorText: AppColors.whiteColor,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _showCancelDialog();
          },
        ),
        title: PoppinsText(
          text: 'stripe_connect_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.blackColor,
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          Obx(
            () => isLoading.value
                ? Container(
                    color: AppColors.whiteColor,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primaryColor,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          PoppinsText(
                            text: 'stripe_loading_onboarding'.tr,
                            fontSize: 14.sp,
                            color: AppColors.grey700Color,
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    AppLogger.logDebug('Stripe Connect: cancel dialog shown');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.whiteColor,
        title: PoppinsText(
          text: 'stripe_cancel_onboarding_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
        content: InterText(
          text: 'stripe_cancel_onboarding_message'.tr,
          fontSize: 14.sp,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: PoppinsText(
              text: 'common_continue'.tr,
              fontSize: 14.sp,
              color: AppColors.primaryColor,
            ),
          ),
          TextButton(
            onPressed: () {
              AppLogger.logInfo(
                'Stripe Connect: user confirmed cancel, closing webview',
              );
              Get.back(); // Close dialog
              Get.back(); // Close webview
            },
            child: PoppinsText(
              text: 'common_cancel'.tr,
              fontSize: 14.sp,
              color: AppColors.errorColor,
            ),
          ),
        ],
      ),
    );
  }
}
