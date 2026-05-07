// v23.1 part 48 — In-app WebView for invoice HTML pages.
//
// Replaces the previous `launchUrl(externalApplication)` flow which exposed
// the raw `hopetsit-backend.onrender.com/...` URL in the system browser's
// address bar. From the user's perspective the invoice now feels native to
// HoPetSit : a branded app bar, no URL visible, and a bottom-right floating
// button that triggers the in-page `window.print()` for save-as-PDF.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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

  // v23.1 part 70 — Bug 13 : Daniel "renvoi a render au lieu de se
  // telecharger ds telephone". Previously _triggerPrint used launchUrl
  // which opened Chrome with the raw Render URL visible. Daniel wants
  // the file to land on his phone directly. Solution :
  //   1. Fetch the invoice HTML via http (with the auth token already
  //      embedded in widget.url as ?token=JWT)
  //   2. Save to phone temporary directory as invoice-XXX.html
  //   3. Open the system Share sheet so the user can save to Drive /
  //      Files / email — no Render URL exposed, file lives on the phone.
  Future<void> _triggerPrint() async {
    try {
      CustomSnackbar.showInfo(
        title: 'Téléchargement…',
        message: 'Préparation de la facture',
      );
      final res = await http.get(Uri.parse(widget.url));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final dir = await getTemporaryDirectory();
      final safeNumber = widget.invoiceNumber.isNotEmpty
          ? widget.invoiceNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
          : 'invoice';
      final file = File('${dir.path}/HoPetSit-$safeNumber.html');
      await file.writeAsBytes(res.bodyBytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/html')],
        subject: 'Facture HoPetSit $safeNumber',
        text: 'Facture HoPetSit',
      );
    } catch (e) {
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
        // v23.1 part 67 — Daniel : "Enlever icone blanche en haut a droite".
        // The AppBar download icon was redundant : the invoice HTML itself
        // shows a big orange "⬇ Télécharger PDF" button at the top AND a
        // sticky one at the bottom (both calling Hopetsit.postMessage
        // 'download' which pops out to the OS browser). actions: [] now.
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
