// DEPRECATED: Stripe webview payment screen has been removed.
// All owner payment handling is now via Airwallex integration.

  @override
  State<StripeWebviewPaymentScreen> createState() =>
      _StripeWebviewPaymentScreenState();
}

class _StripeWebviewPaymentScreenState
    extends State<StripeWebviewPaymentScreen> {
  late final WebViewController _controller;
  final RxBool isLoading = true.obs;
  final RxString currentUrl = ''.obs;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    // Get the payment URL
    final paymentUrl = StripePaymentService.getStripePaymentUrl(
      clientSecret: widget.clientSecret,
      publishableKey: widget.publishableKey,
      returnUrl: 'hopetsit://payment-return',
      cancelUrl: 'hopetsit://payment-cancel',
      paymentPageUrl: widget.paymentPageUrl,
    );

    // Initialize WebView controller
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            isLoading.value = true;
            currentUrl.value = url;
            _handleNavigation(url);
          },
          onPageFinished: (String url) {
            isLoading.value = false;
            currentUrl.value = url;
          },
          onWebResourceError: (WebResourceError error) {
            isLoading.value = false;
            _handleError(error);
          },
        ),
      )
      ..loadRequest(Uri.parse(paymentUrl));
  }

  void _handleNavigation(String url) {
    // Check if this is a callback URL
    if (StripePaymentService.isStripeCallbackUrl(url)) {
      final result = StripePaymentService.parseReturnUrl(url);

      if (result != null) {
        final status = result['status'] ?? 'unknown';
        final paymentIntentId =
            result['payment_intent_id'] ?? widget.paymentIntentId ?? '';

        // Handle based on status
        if (status == 'succeeded' || status == 'paid' || status == 'success') {
          _handlePaymentSuccess(paymentIntentId);
        } else if (status == 'cancelled' || status == 'cancel') {
          _handlePaymentCancelled();
        } else {
          _handlePaymentError('Payment status: $status');
        }
        return;
      }
    }

    // Also check if URL contains payment_intent in query params (Stripe redirect)
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final paymentIntentId = uri.queryParameters['payment_intent'];
      final redirectStatus = uri.queryParameters['redirect_status'];

      if (paymentIntentId != null && redirectStatus != null) {
        if (redirectStatus == 'succeeded') {
          _handlePaymentSuccess(paymentIntentId);
        } else if (redirectStatus == 'cancelled') {
          _handlePaymentCancelled();
        } else {
          _handlePaymentError('Payment status: $redirectStatus');
        }
      }
    }
  }

  void _handlePaymentSuccess(String paymentIntentId) async {
    if (paymentIntentId.isEmpty) {
      _handlePaymentError('Payment intent ID is missing');
      return;
    }

    // Get the payment controller if it exists
    if (Get.isRegistered<StripePaymentController>(
      tag: 'stripe_payment_${widget.booking.id}',
    )) {
      final paymentController = Get.find<StripePaymentController>(
        tag: 'stripe_payment_${widget.booking.id}',
      );

      // Confirm payment with backend
      await paymentController.confirmPayment(paymentIntentId: paymentIntentId);
    } else {
      // Controller not found, navigate directly to success
      Get.off(
        () => PaymentResultScreen(
          isSuccess: true,
          message: 'Your payment has been processed successfully.',
          transactionId: paymentIntentId,
          amount: widget.totalAmount,
          currency: widget.booking.pricing?.currency ?? widget.booking.sitter.currency,
          onContinue: () {
            Get.until((route) => route.isFirst);
          },
        ),
      );
    }
  }

  void _handlePaymentCancelled() {
    Get.back();
    // The controller will handle showing appropriate message
    debugPrint('STRIPE CANCELLED');
  }

  void _handlePaymentError(String error) {
    Get.back();
    // The controller will handle showing error message
    debugPrint('STRIPE ERROR: $error');
  }

  void _handleError(WebResourceError error) {
    if (mounted) {
      Get.back();
      debugPrint('STRIPE ERROR: ${error.description}');
      debugPrint('STRIPE ERROR: ${error.errorCode}');
      debugPrint('STRIPE ERROR: ${error.errorType}');
      debugPrint('STRIPE ERROR: ${error.url}');
      Get.snackbar(
        'common_error'.tr,
        'payment_load_error'.tr.replaceAll('@error', error.description),
        backgroundColor: AppColors.errorColor,
        duration: Duration(seconds: 10),
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
          text: 'payment_title'.tr,
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
                            text: 'payment_loading_page'.tr,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: PoppinsText(
          text: 'payment_cancel_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
        content: InterText(text: 'payment_cancel_message'.tr, fontSize: 14.sp),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: PoppinsText(
              text: 'payment_continue'.tr,
              fontSize: 14.sp,
              color: AppColors.primaryColor,
            ),
          ),
          TextButton(
            onPressed: () {
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
