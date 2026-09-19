import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/paypal_payment_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/payment/widgets/payment_ui_kit.dart';
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
  // v569 — progression de la WebView (affichage seulement) pour la barre fine
  // du squelette de chargement. Null tant qu'aucune progression n'est connue.
  final RxnDouble loadProgress = RxnDouble();
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
          // v569 — purement décoratif : alimente la barre de progression du
          // squelette. Aucune décision de paiement n'en dépend.
          onProgress: (progress) {
            loadProgress.value = (progress.clamp(0, 100)) / 100.0;
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
    loadProgress.value = null;
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
    // v569 — même habillage que les autres écrans de paiement : barre
    // « Paiement sécurisé » avec cadenas + montant, squelette de chargement
    // avec barre de progression, état d'erreur « Réessayer » / « Annuler ».
    // La WebView garde TOUTE la place : les états ne s'affichent que pendant
    // le chargement ou en cas d'échec, jamais par-dessus le formulaire.
    final accent = AppColors.primaryColor;
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: PaySecureAppBar(
        accent: accent,
        title: 'pay569_title'.tr,
        subtitle: CurrencyHelper.format(widget.currency, widget.totalAmount),
        backIcon: Icons.close_rounded,
        backTooltip: 'common_cancel'.tr,
        onBack: () => Get.back(),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          Obx(
            () => isLoading.value && !loadFailed.value
                ? PayLoadingOverlay(
                    message: 'pay569_connecting'.tr,
                    accent: accent,
                    progress: loadProgress.value,
                  )
                : const SizedBox.shrink(),
          ),
          Obx(
            () => loadFailed.value
                ? Container(
                    color: AppColors.scaffold(context),
                    child: PayErrorPanel(
                      title: 'pay569_load_error_title'.tr,
                      message: 'pay569_load_error_msg'.tr,
                      retryLabel: 'common_retry'.tr,
                      cancelLabel: 'common_cancel'.tr,
                      accent: accent,
                      onRetry: _reload,
                      // Même action qu'avant : on quitte l'écran, le
                      // contrôleur PayPal n'est pas touché.
                      onCancel: () => Get.back(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
