// v23.1 part 48 — In-app WebView for invoice HTML pages.
//
// Replaces the previous `launchUrl(externalApplication)` flow which exposed
// the raw `hopetsit-backend.onrender.com/...` URL in the system browser's
// address bar. From the user's perspective the invoice now feels native to
// HoPetSit : a branded app bar, no URL visible, and a bottom-right floating
// button that triggers the in-page `window.print()` for save-as-PDF.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class InvoiceViewerScreen extends StatefulWidget {
  final String url;
  final String invoiceNumber;

  const InvoiceViewerScreen({
    super.key,
    required this.url,
    required this.invoiceNumber,
  });

  @override
  State<InvoiceViewerScreen> createState() => _InvoiceViewerScreenState();
}

class _InvoiceViewerScreenState extends State<InvoiceViewerScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      // v23.1 part 65 — Bug 7 : the orange "⬇ Télécharger PDF" buttons
      // baked into the invoice HTML used to call window.print() which
      // is a silent no-op on Android WebView. Now they call
      // Hopetsit.postMessage('download') and we pop out to the system
      // browser via launchUrl (same path as the AppBar download icon).
      ..addJavaScriptChannel(
        'Hopetsit',
        onMessageReceived: (msg) {
          if (msg.message == 'download') {
            _triggerPrint();
          }
        },
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  // v23.1 part 63 — Bug F : open the invoice in the system browser /
  // Chrome so the OS's native "Save as PDF / Print / Share" handles it
  // properly. window.print() inside an embedded Android WebView is
  // unreliable (no Print Service bound, silent no-op on many devices)
  // — Daniel reported "le bouton telecharger nest pas connecter".
  // External launch is the cross-OS path that always works.
  Future<void> _triggerPrint() async {
    final uri = Uri.parse(widget.url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        // Fallback : try in-page window.print() if external launch fails
        // (rare — only if no browser is installed).
        await _controller.runJavaScript('window.print();');
      }
    } catch (_) {
      try {
        await _controller.runJavaScript('window.print();');
      } catch (_) {
        if (mounted) {
          CustomSnackbar.showError(
            title: 'common_error'.tr,
            message: 'invoice_download_failed'.tr,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            PoppinsText(
              text: 'Facture HoPetSit',
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            if (widget.invoiceNumber.isNotEmpty)
              InterText(
                text: widget.invoiceNumber,
                fontSize: 11.sp,
                color: Colors.white.withValues(alpha: 0.8),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Télécharger PDF',
            onPressed: _triggerPrint,
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryColor,
              ),
            ),
        ],
      ),
    );
  }
}
