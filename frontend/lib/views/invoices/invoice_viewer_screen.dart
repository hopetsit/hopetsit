// v23.1 part 48 — In-app WebView for invoice HTML pages.
//
// Replaces the previous `launchUrl(externalApplication)` flow which exposed
// the raw `hopetsit-backend.onrender.com/...` URL in the system browser's
// address bar. From the user's perspective the invoice now feels native to
// HoPetSit : a branded app bar, no URL visible, and a bottom-right floating
// button that triggers the in-page `window.print()` for save-as-PDF.
//
// v565 (point 28) — barre claire couleur du rôle, bouton bas « Télécharger
// le PDF », état d'erreur de chargement avec « Réessayer », anti double-tap.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/billing_info_controller.dart';
import 'package:hopetsit/models/invoice_model.dart';
import 'package:hopetsit/services/invoice_pdf_generator.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/invoices/widgets/invoice_billing_blocks.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
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
  // v565 — état d'erreur de chargement de la page (WebView) avec « Réessayer ».
  bool _loadFailed = false;
  bool _sharing = false;
  // v566 — informations de facturation : blocs Émetteur / Client + bandeau.
  late final BillingInfoController _billing;

  Color get _accent => currentRoleAccent();

  String get _role {
    try {
      return GetStorage().read<String>(StorageKeys.userRole) ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _billing = BillingInfoController.ensure();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _billing.loadIfNeeded();
    });
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) {
            setState(() {
              _loading = true;
              _loadFailed = false;
            });
          }
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (err) {
          // Seule l'erreur du document principal compte (pas une image).
          if (err.isForMainFrame == false) return;
          if (mounted) {
            setState(() {
              _loading = false;
              _loadFailed = true;
            });
          }
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
      // v576 — le gabarit servi par le backend appelait « HoPetSit » (deux
      // majuscules) alors que le canal ci-dessus s'appelle « Hopetsit ». Les
      // identifiants JS sont sensibles à la casse : le bouton intégré à la
      // page n'atteignait jamais l'app. Le serveur essaie désormais les deux
      // noms (répare les apps déjà installées) et l'app écoute les deux.
      ..addJavaScriptChannel(
        'HoPetSit',
        onMessageReceived: (msg) {
          if (msg.message == 'download') {
            _triggerPrint();
          }
        },
      )
      ..loadRequest(Uri.tryParse(widget.url) ?? Uri.parse('about:blank'));
  }

  void _reload() {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    _controller.loadRequest(Uri.tryParse(widget.url) ?? Uri.parse('about:blank'));
  }

  // v23.1 part 73 — Bug : "facture se telecharge en htlm elle peux pas
  // se telecharger directement en pdf sur le tel".
  // We now generate a real PDF locally on the phone using the `pdf`
  // package + the InvoiceModel data (already loaded by InvoicesScreen).
  // No backend round-trip, no third-party service. Saved as a .pdf to
  // the phone temp dir, opened via the system Share sheet so the user
  // can save to Files / Drive / email — opens with any PDF viewer.
  Future<void> _triggerPrint() async {
    if (_sharing) return;
    if (mounted) setState(() => _sharing = true);
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
      // v576 — BUG : le repli appelait window.print(), qui ne fait RIEN dans
      // la WebView Android → l'utilisateur tapait et il ne se passait rien,
      // sans le moindre message. On tente toujours l'impression (elle marche
      // sur iOS / navigateur), mais on prévient TOUJOURS en cas d'échec.
      bool printed = false;
      try {
        await _controller.runJavaScript('window.print();');
        printed = Platform.isIOS;
      } catch (_) {
        printed = false;
      }
      if (!printed && mounted) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'invoice576_save_failed'.tr,
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
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
    final accent = _accent;
    return Scaffold(
      // Audit mode sombre — le fond de page était figé en blanc pour la
      // WebView, mais l'en-tête « Émetteur / Client » et la bannière de
      // facturation posés AU-DESSUS se retrouvaient sur du blanc en thème
      // sombre. La WebView peint déjà son propre fond blanc
      // (setBackgroundColor ci-dessus) : le document reste blanc.
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.scaffold(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: accent),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20.sp, color: accent),
          onPressed: () => Get.back(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PoppinsText(
              text: 'invoice_viewer_title'.tr,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.invoiceNumber.isNotEmpty)
              InterText(
                text: widget.invoiceNumber,
                fontSize: 11.sp,
                color: AppColors.textSecondary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
            icon: Icon(Icons.ios_share_rounded, color: accent),
            onPressed: _sharing ? null : _saveToFiles,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // v566 — Émetteur / Client (feuille) + « Ajoute tes informations
            // de facturation » quand le bloc de l'utilisateur courant est vide.
            if (widget.invoice != null)
              Obx(() {
                final loaded = _billing.loaded.value;
                final mineEmpty = _billing.info.value.isEmpty;
                final inv = widget.invoice!;
                final showBanner = loaded && mineEmpty && inv.billingFor(_role).isEmpty;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (inv.hasAnyBilling) InvoicePartiesStrip(invoice: inv, accent: accent),
                    if (showBanner)
                      BillingMissingBanner(
                        accent: accent,
                        margin: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
                        onReturn: _reload,
                      ),
                  ],
                );
              }),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_loading && !_loadFailed)
                    Container(
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(color: accent),
                    ),
                  if (_loadFailed)
                    Container(
                      color: AppColors.scaffold(context),
                      child: ProfileEmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'v565_pay_load_error_title'.tr,
                        message: 'v565_pay_invoice_load_error'.tr,
                        accent: accent,
                        error: true,
                        actionLabel: 'common_retry'.tr,
                        onAction: _reload,
                      ),
                    ),
                ],
              ),
            ),
            // v565 — bouton bas explicite « Télécharger le PDF » (le partage
            // OS propose Enregistrer dans Fichiers / Drive / e-mail).
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
              child: ProfilePrimaryButton(
                label: 'v565_pay_invoice_download_pdf'.tr,
                accent: accent,
                icon: Icons.picture_as_pdf_rounded,
                loading: _sharing,
                onTap: _sharing ? null : _saveToFiles,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
