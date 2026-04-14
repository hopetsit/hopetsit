import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/paypal_payment_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
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
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.approvalUrl));
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
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Get.back(),
        ),
        title: PoppinsText(
          text: 'payment_method_paypal'.tr,
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
}

