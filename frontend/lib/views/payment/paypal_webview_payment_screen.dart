import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/paypal_payment_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PayPalWebviewPaymentScreen extends StatefulWidget {
  const PayPalWebviewPaymentScreen({
    super.key,
    required this.booking,
    required this.totalAmount,
    required this.currency,
    required this.orderId,
    required this.approvalUrl,
  });

  final BookingModel booking;
  final double totalAmount;
  final String currency;
  final String orderId;
  final String approvalUrl;

  @override
  State<PayPalWebviewPaymentScreen> createState() =>
      _PayPalWebviewPaymentScreenState();
}

class _PayPalWebviewPaymentScreenState extends State<PayPalWebviewPaymentScreen> {
  late final WebViewController _controller;
  final RxBool isLoading = true.obs;
  // v565 — état d'erreur de chargement de la page PayPal avec « Réessayer ».
  final RxBool loadFailed = false.obs;
  bool _captureStarted = false;

  // As provided by backend dev
  static const String _returnUrl = 'https://petinsta.com/paypal-success';
  static const String _cancelUrl = 'https://petinsta.com/paypal-cancel';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            isLoading.value = true;
            _handleNavigation(url);
          },
          onPageFinished: (url) {
            isLoading.value = false;
            _handleNavigation(url);
          },
          onNavigationRequest: (request) {
            _handleNavigation(request.url);
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            isLoading.value = false;
            // Seule l'erreur du document principal compte (pas une image).
            if (error.isForMainFrame == false) return;
            loadFailed.value = true;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.approvalUrl));
  }

  void _reload() {
    loadFailed.value = false;
    isLoading.value = true;
    _controller.loadRequest(Uri.parse(widget.approvalUrl));
  }

  void _handleNavigation(String url) {
    if (_captureStarted) return;

    // Normalize URL for comparison
    final trimmed = url.split('#').first;

    // User cancelled in PayPal
    if (trimmed.startsWith(_cancelUrl)) {
      Get.back();
      return;
    }

    // PayPal redirect after successful approval
    if (trimmed.startsWith(_returnUrl)) {
      _captureStarted = true;
      _capture(orderId: widget.orderId, payerId: null);
    }
  }

  Future<void> _capture({required String orderId, String? payerId}) async {
    final tag = 'paypal_payment_${widget.booking.id}';
    if (Get.isRegistered<PayPalPaymentController>(tag: tag)) {
      final ctrl = Get.find<PayPalPaymentController>(tag: tag);
      await ctrl.captureOrder(orderId: orderId);
      return;
    }
    // Fallback: create a controller and capture
    final ctrl = Get.put(
      PayPalPaymentController(
        booking: widget.booking,
        totalAmount: widget.totalAmount,
        currency: widget.currency,
      ),
      tag: tag,
    );
    await ctrl.captureOrder(orderId: orderId);
  }

  @override
  Widget build(BuildContext context) {
    // v565 (point 28) — en-tête clair (montant dans le titre), état de
    // chargement, état d'erreur avec « Réessayer », fermeture explicite.
    final accent = AppColors.primaryColor;
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: accent),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'common_cancel'.tr,
          onPressed: () => Get.back(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PoppinsText(
              text: 'payment_method_paypal'.tr,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.blackColor,
              maxLines: 1,
            ),
            InterText(
              text: CurrencyHelper.format(widget.currency, widget.totalAmount),
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: accent,
              maxLines: 1,
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          Obx(
            () => isLoading.value && !loadFailed.value
                ? Container(
                    color: AppColors.whiteColor,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
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
          Obx(
            () => loadFailed.value
                ? Container(
                    color: AppColors.whiteColor,
                    child: ProfileEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'v565_pay_load_error_title'.tr,
                      message: 'v565_pay_page_load_error'.tr,
                      accent: accent,
                      error: true,
                      actionLabel: 'common_retry'.tr,
                      onAction: _reload,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
