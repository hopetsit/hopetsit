// v20.1 — Airwallex payment via Hosted Payment Page in a webview.
//
// Pourquoi pas le SDK Flutter natif ?
//   La 0.0.2 publiée sur pub.dev avait un bug (lib/ vide, package
//   incompilable) et la 0.1.13 (sortie le 24 avril 2026) n'a pas encore de
//   doc publique. La Hosted Payment Page d'Airwallex est aussi robuste,
//   supporte Apple Pay / Google Pay / Klarna automatiquement, et ne dépend
//   d'aucun SDK natif → un seul code path, plus simple à maintenir.
//
// Flow :
//   1. Backend crée un PaymentIntent → renvoie {intentId, clientSecret, ...}
//   2. App ouvre `https://hopetsit.com/pay?intent=...&secret=...&currency=EUR&country=FR`
//      dans une WebView plein écran
//   3. La page sur hopetsit.com charge airwallex.js et appelle
//      Airwallex.redirectToCheckout() → user atterrit sur la vraie page
//      sécurisée Airwallex
//   4. Une fois le paiement validé, Airwallex redirige vers
//      `https://hopetsit.com/pay/done?status=success`
//   5. La WebView détecte cette URL et se ferme avec le bon outcome.
//
// Toute l'UI Airwallex est servie par leur infra (PCI-DSS) — on ne touche
// jamais aux données carte de l'utilisateur.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum AirwallexPaymentOutcome { success, cancelled, failed }

class AirwallexPaymentResult {
  final AirwallexPaymentOutcome outcome;
  final String? errorMessage;

  const AirwallexPaymentResult(this.outcome, {this.errorMessage});

  bool get isSuccess => outcome == AirwallexPaymentOutcome.success;
}

class AirwallexPaymentService {
  AirwallexPaymentService._();

  /// Domaine du site web HoPetSit qui héberge la page bridge `/pay`. La
  /// production pointe sur le custom domain ; on garde une fallback vers
  /// l'URL Vercel au cas où le DNS bouge.
  static const String _bridgeBase = 'https://hopetsit.com';

  /// Init du service. No-op : pas de SDK natif à initialiser, juste un log
  /// pour confirmer au boot que la couche Airwallex est branchée.
  static Future<void> init({bool live = true}) async {
    AppLogger.logInfo(
      '[airwallex] webview HPP service ready (live=$live, bridge=$_bridgeBase)',
    );
  }

  /// Ouvre la WebView Airwallex et attend le résultat du paiement.
  ///
  /// [intentId] / [clientSecret] proviennent de la réponse backend create-intent.
  /// [amount] est en unités majeures (EUR pas cents). [currency] en ISO upper.
  ///
  /// Retourne [AirwallexPaymentOutcome.success] si le paiement est confirmé,
  /// `cancelled` si l'user ferme la WebView, `failed` sinon.
  static Future<AirwallexPaymentResult> confirmPaymentIntent({
    required String intentId,
    required String clientSecret,
    required double amount,
    required String currency,
    String countryCode = 'FR',
    String? customerId,
    bool live = true,
  }) async {
    if (intentId.isEmpty || clientSecret.isEmpty) {
      return const AirwallexPaymentResult(
        AirwallexPaymentOutcome.failed,
        errorMessage: 'Missing intentId or clientSecret',
      );
    }

    final env = live ? 'prod' : 'demo';
    final uri = Uri.parse(_bridgeBase).replace(
      path: '/pay',
      queryParameters: {
        'intent':   intentId,
        'secret':   clientSecret,
        'currency': currency.toUpperCase(),
        'country':  countryCode.toUpperCase(),
        'env':      env,
      },
    );

    AppLogger.logInfo('[airwallex] opening HPP webview → ${uri.toString()}');

    final result = await Get.to<AirwallexPaymentResult>(
      () => _AirwallexCheckoutScreen(
        url: uri,
        amount: amount,
        currency: currency,
      ),
      fullscreenDialog: true,
    );

    return result ??
        const AirwallexPaymentResult(AirwallexPaymentOutcome.cancelled);
  }
}

// ─── Internal: webview screen ────────────────────────────────────────────────

class _AirwallexCheckoutScreen extends StatefulWidget {
  final Uri url;
  final double amount;
  final String currency;

  const _AirwallexCheckoutScreen({
    required this.url,
    required this.amount,
    required this.currency,
  });

  @override
  State<_AirwallexCheckoutScreen> createState() => _AirwallexCheckoutScreenState();
}

class _AirwallexCheckoutScreenState extends State<_AirwallexCheckoutScreen> {
  late final WebViewController _controller;
  bool _resolved = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          if (!_resolved) _maybeResolveFromUrl(url);
        },
        onPageFinished: (url) {
          if (mounted) setState(() => _loading = false);
          if (!_resolved) _maybeResolveFromUrl(url);
        },
        onUrlChange: (change) {
          final url = change.url;
          if (url != null && !_resolved) _maybeResolveFromUrl(url);
        },
        onNavigationRequest: (request) {
          if (!_resolved && _looksLikeDoneUrl(request.url)) {
            _resolveFromUrl(request.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (err) {
          AppLogger.logError(
            '[airwallex] webview error: ${err.errorCode} ${err.description}',
          );
        },
      ))
      ..loadRequest(widget.url);
  }

  bool _looksLikeDoneUrl(String url) =>
      url.contains('/pay/done');

  void _maybeResolveFromUrl(String url) {
    if (_looksLikeDoneUrl(url)) _resolveFromUrl(url);
  }

  void _resolveFromUrl(String url) {
    if (_resolved) return;
    _resolved = true;
    final uri = Uri.tryParse(url);
    final status = (uri?.queryParameters['status'] ?? '').toLowerCase();
    AirwallexPaymentOutcome outcome;
    if (status == 'success') {
      outcome = AirwallexPaymentOutcome.success;
    } else if (status == 'cancel') {
      outcome = AirwallexPaymentOutcome.cancelled;
    } else {
      outcome = AirwallexPaymentOutcome.failed;
    }
    AppLogger.logInfo('[airwallex] webview resolved → $status');
    Get.back<AirwallexPaymentResult>(result: AirwallexPaymentResult(outcome));
  }

  void _userCancel() {
    if (_resolved) return;
    _resolved = true;
    AppLogger.logInfo('[airwallex] webview closed by user');
    Get.back<AirwallexPaymentResult>(
      result: const AirwallexPaymentResult(AirwallexPaymentOutcome.cancelled),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _userCancel();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFFEF4324),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paiement sécurisé',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              Text(
                '${widget.amount.toStringAsFixed(2)} ${widget.currency.toUpperCase()}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _userCancel,
          ),
        ),
        // v23.1 part 48 — improved loading UX. The previous spinner appeared
        // briefly on a white background and looked like the page was frozen.
        // The new branded full-screen loader shows a paw logo + amount +
        // "Connexion sécurisée à Airwallex…" so the user understands what's
        // happening during the 1-3s bridge load.
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading) _BrandedLoader(amount: widget.amount, currency: widget.currency),
          ],
        ),
      ),
    );
  }
}

/// v23.1 part 48 — branded full-screen loader for the Airwallex HPP webview.
/// Shows while the bridge page (hopetsit.com/pay) is fetching airwallex.js
/// and redirecting to the actual checkout. Prevents the "blank white screen
/// for 2 seconds" effect and gives the user confidence the payment is
/// actually loading securely.
class _BrandedLoader extends StatelessWidget {
  final double amount;
  final String currency;

  const _BrandedLoader({required this.amount, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4324).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.lock_rounded,
                size: 36,
                color: Color(0xFFEF4324),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Color(0xFFEF4324),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Connexion sécurisée…',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF1F1F1F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${amount.toStringAsFixed(2)} ${currency.toUpperCase()}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 22,
                color: Color(0xFFEF4324),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Le paiement est traité par Airwallex (PCI-DSS Level 1). Vos données carte ne transitent jamais par HoPetSit.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF777777),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
