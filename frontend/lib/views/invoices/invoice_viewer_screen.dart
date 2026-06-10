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
import 'package:hopetsit/models/invoice_model.dart';
import 'package:hopetsit/services/invoice_pdf_generator.dart';
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
  // v23.1 part 73 — full InvoiceModel passed in so we can build a real
  // PDF locally on the phone (no need to scrape the HTML). Optional —
  // if null, falls back to the legacy http+share-as-html path.
  final InvoiceModel? invoice;

  const InvoiceViewerScreen({
    super.key,
    required this.url,
    required this.invoiceNumber,
    this.invoice,
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
      ..loadRequest(Uri.tryParse(widget.url) ?? Uri.parse('about:blank'));
  }

  // v23.1 part 73 — Bug : "facture se telecharge en htlm elle peux pas
  // se telecharger directement en pdf sur le tel".
  // We now generate a real PDF locally on the phone using the `pdf`
  // package + the InvoiceModel data (already loaded by InvoicesScreen).
  // No backend round-trip, no third-party service. Saved as a .pdf to
  // the phone temp dir, opened via the system Share sheet so the user
  // can save to Files / Drive / email — opens with any PDF viewer.
  Future<void> _triggerPrint() async {
    try {
      CustomSnackbar.showInfo(
        title: 'invoice_download_preparing_title'.tr,
        message: 'invoice_download_preparing_msg'.tr,
      );
      final safeNumber = widget.invoiceNumber.isNotEmpty
          ? widget.invoiceNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
          : 'invoice';
      final dir = await getTemporaryDirectory();
      // Preferred path : real PDF from InvoiceModel.
      if (widget.invoice != null) {
        final bytes = await InvoicePdfGenerator.build(widget.invoice!);
        final file = File('${dir.path}/HoPetSit-$safeNumber.pdf');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: '${'invoice_pdf_subject'.tr} $safeNumber',
          text: 'invoice_pdf_subject'.tr,
        ));
        return;
      }
      // Fallback : legacy HTML download for callers that haven't yet
      // started passing widget.invoice.
      // v23.1.175 — fix crash _Uri.resolve FormatException.
      final uri = Uri.tryParse(widget.url);
      if (uri == null || !uri.hasScheme) {
        throw Exception('Invalid invoice URL');
      }
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final file = File('${dir.path}/HoPetSit-$safeNumber.html');
      await file.writeAsBytes(res.bodyBytes);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'text/html')],
        subject: '${'invoice_pdf_subject'.tr} $safeNumber',
        text: 'invoice_pdf_subject'.tr,
      ));
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

  /// v23.1.154 — Daniel : "faite que je puis enregistrer mon pdf facture
  /// ds fichier du tel". Le bouton AppBar etait masque (actions: []) car
  /// les boutons HTML internes etaient supposes suffire. Mais sur iOS le
  /// share sheet montre "Save to Files" pas toujours visible au premier
  /// coup d'oeil. On rajoute un IconButton explicite (download icon) dans
  /// l'AppBar qui appelle directement _triggerPrint() → user voit l'option
  /// "Enregistrer dans Fichiers" du share sheet.
  Future<void> _saveToFiles() async {
    await _triggerPrint();
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
              text: 'invoice_viewer_title'.tr,
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
        // v23.1.154 — Daniel : "faite que je puis enregistrer mon pdf
        // facture ds fichier du tel". On reintroduit l'icone download
        // dans l'AppBar (apres le retrait part 67) avec un tooltip clair
        // "Enregistrer dans Fichiers" — le bouton appelle _triggerPrint()
        // qui ouvre le share sheet OS avec l'option "Save to Files" (iOS)
        // ou "Save to Downloads" (Android) directement visible.
        actions: [
          IconButton(
            tooltip: 'invoice_save_to_files'.tr,
            icon: const Icon(Icons.save_alt, color: Colors.white),
            onPressed: _saveToFiles,
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
