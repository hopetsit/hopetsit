import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/repositories/kyc_repository.dart';
import 'package:hopetsit/services/airwallex_payment_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
// v23.1 part 131 — image_picker + dart:io retirés (KYC manuel supprimé).
import 'package:webview_flutter/webview_flutter.dart';

/// v23.1 part 36 — KYC verification screen pour sitter/walker.
/// Flow :
///   1. État 'none' → bouton "Procéder à la vérification 3€"
///   2. État 'pending_payment' → ouvre Airwallex HPP webview pour 3€
///   3. État 'pending_verification' → bouton "Lancer la vérification"
///        → ouvre WebView Persona pour scan ID + selfie
///   4. État 'verified' → "✅ Vérifié le DD/MM/YYYY"
///   5. État 'rejected' → "Refusé. Contactez support."
class KycVerificationScreen extends StatefulWidget {
  const KycVerificationScreen({super.key});

  @override
  State<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends State<KycVerificationScreen> {
  late final KycRepository _repo;
  Map<String, dynamic> _status = {};
  bool _loading = true;
  bool _busy = false;

  Color get _accent {
    final role = Get.isRegistered<AuthController>()
        ? (Get.find<AuthController>().userRole.value ?? '').toLowerCase()
        : '';
    if (role == 'walker') return const Color(0xFF16A34A);
    if (role == 'sitter') return const Color(0xFF2563EB);
    return AppColors.primaryColor;
  }

  @override
  void initState() {
    super.initState();
    _repo = Get.isRegistered<KycRepository>()
        ? Get.find<KycRepository>()
        : KycRepository(Get.find<ApiClient>());
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      _status = await _repo.getStatus();
    } catch (e) {
      AppLogger.logError('kyc.getStatus failed', error: e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onPay() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final initResp = await _repo.initiatePayment();
      final pi = initResp['paymentIntent'] as Map?;
      if (pi == null) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'Failed to start payment',
        );
        return;
      }
      // Ouvre Airwallex HPP webview
      final result = await AirwallexPaymentService.confirmPaymentIntent(
        intentId: pi['id'] as String,
        clientSecret: pi['clientSecret'] as String,
        amount: 3.0,
        currency: 'EUR',
        live: true,
      );
      if (result.outcome == AirwallexPaymentOutcome.success) {
        CustomSnackbar.showSuccess(
          title: 'Paiement confirmé',
          message: 'On lance maintenant la vérification d\'identité.',
        );

        // v23.1 part 75 — Daniel : "sa as debiter et sa menvoi pas a la
        // verification id". Don't rely solely on the Airwallex webhook
        // to flip kycStatus → call /kyc/confirm-payment which re-checks
        // the PI server-side and forces the activation. Idempotent : if
        // the webhook already ran, this is a no-op. Race-safe.
        try {
          await _repo.confirmPayment();
        } catch (e) {
          AppLogger.logError('kyc.confirmPayment fallback failed', error: e);
        }

        // Poll /kyc/status as a safety net in case confirm-payment was
        // delayed (network / server). 6 polls × 1.5s = 9s max.
        bool reachedPending = false;
        for (int i = 0; i < 6; i++) {
          await Future.delayed(const Duration(milliseconds: 1500));
          await _refresh();
          if (_status['kycStatus'] == 'pending_verification') {
            reachedPending = true;
            break;
          }
        }
        if (reachedPending) {
          _onStartVerification();
        } else {
          CustomSnackbar.showWarning(
            title: 'Synchronisation en cours',
            message:
                'Ton paiement est confirmé mais la vérification met un peu '
                'plus longtemps que prévu. Réappuie sur "Continuer" dans '
                'quelques secondes.',
          );
        }
      } else {
        CustomSnackbar.showError(
          title: 'Paiement annulé',
          message: result.errorMessage ?? 'Réessaie quand tu veux.',
        );
      }
    } catch (e) {
      AppLogger.logError('kyc.pay failed', error: e);
      CustomSnackbar.showError(title: 'common_error'.tr, message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onStartVerification() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final resp = await _repo.startVerification();
      final url = resp['oneTimeLink'] as String?;
      if (url == null || url.isEmpty) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'Lien de vérification indisponible.',
        );
        return;
      }
      // Open Persona webview
      await Get.to(() => _PersonaWebViewScreen(url: url));
      // Refresh status after webview closes
      await _refresh();
    } catch (e) {
      AppLogger.logError('kyc.start failed', error: e);
      // v23.1 part 70 — Bug 14 : if backend is missing PERSONA env vars
      // it returns 503 with code='KYC_NOT_CONFIGURED'. Show a clear
      // message instead of the raw exception. Owner needs to set
      // PERSONA_API_KEY + PERSONA_TEMPLATE_ID on Render.
      final s = e.toString();
      if (s.contains('KYC_NOT_CONFIGURED') || s.contains('temporarily unavailable')) {
        CustomSnackbar.showWarning(
          title: 'Vérification temporairement indisponible',
          message:
              'La vérification d\'identité est désactivée pour le moment. '
              'Ton paiement est conservé, on activera la vérification très bientôt.',
        );
      } else {
        CustomSnackbar.showError(title: 'common_error'.tr, message: s);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBar(context),
      appBar: AppBar(
        title: PoppinsText(
          text: 'kyc_screen_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
        ),
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final status = (_status['kycStatus'] ?? 'none').toString();
    final price = _status['price'] ?? 3;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.all(20.w),
        children: [
          // Header explanation
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_rounded, color: _accent, size: 24.sp),
                    SizedBox(width: 8.w),
                    PoppinsText(
                      text: 'kyc_screen_why_title'.tr,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: _accent,
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                InterText(
                  text:
                      'Un badge "Vérifié" rassure les propriétaires et augmente '
                      'tes chances d\'être choisi pour leurs réservations. '
                      'Vérification rapide (~2 min) avec ID + selfie.',
                  fontSize: 13.sp,
                  color: AppColors.textPrimary(context),
                ),
                SizedBox(height: 12.h),
                _statusRow(status, price.toString()),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          _buildActionForStatus(status, price),
          SizedBox(height: 20.h),
          _buildSteps(),
        ],
      ),
    );
  }

  Widget _statusRow(String status, String price) {
    String label;
    Color color;
    IconData icon;
    switch (status) {
      case 'verified':
        label = 'Vérifié ✓';
        color = const Color(0xFF1976D2);
        icon = Icons.verified_rounded;
        break;
      case 'pending_verification':
        label = 'En attente de vérification';
        color = const Color(0xFFFFA000);
        icon = Icons.pending_outlined;
        break;
      case 'pending_payment':
        label = 'En attente de paiement';
        color = const Color(0xFFFFA000);
        icon = Icons.payment_outlined;
        break;
      case 'rejected':
        label = 'Vérification refusée';
        color = const Color(0xFFE53935);
        icon = Icons.cancel_outlined;
        break;
      default:
        label = 'Non vérifié — Coût : ${price}€';
        color = AppColors.greyColor;
        icon = Icons.circle_outlined;
    }
    return Row(
      children: [
        Icon(icon, color: color, size: 18.sp),
        SizedBox(width: 6.w),
        InterText(
          text: label,
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ],
    );
  }

  Widget _buildActionForStatus(String status, dynamic price) {
    if (status == 'verified') {
      final verifiedAt = _status['kycVerifiedAt']?.toString() ?? '';
      final dateStr = verifiedAt.isNotEmpty
          ? verifiedAt.split('T').first
          : '';
      return Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1976D2).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFF1976D2).withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.verified_rounded,
                color: const Color(0xFF1976D2), size: 60.sp),
            SizedBox(height: 12.h),
            PoppinsText(
              text: 'Tu es vérifié !',
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1976D2),
            ),
            if (dateStr.isNotEmpty) ...[
              SizedBox(height: 4.h),
              InterText(
                text: 'Le $dateStr',
                fontSize: 12.sp,
                color: AppColors.greyColor,
              ),
            ],
          ],
        ),
      );
    }
    if (status == 'rejected') {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cancel_outlined,
                    color: const Color(0xFFE53935), size: 24.sp),
                SizedBox(width: 8.w),
                PoppinsText(
                  text: 'Vérification refusée',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE53935),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            InterText(
              text: _status['kycRejectionReason']?.toString() ??
                  'Le document ou le selfie n\'ont pas pu être validés. Contacte le support.',
              fontSize: 13.sp,
              color: AppColors.textPrimary(context),
            ),
            SizedBox(height: 12.h),
            // v23.1 part 131 — Daniel : "Verification uniquement par
            // persona et automatique, virer verifier gratuit". L'upload
            // manuel est désormais retiré. En cas de rejet, on propose
            // de relancer la vérif Persona.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _onStartVerification,
                icon: Icon(Icons.bolt_rounded, color: _accent, size: 20.sp),
                label: Text(
                  _busy ? 'Chargement...' : 'Relancer la vérification Persona',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _accent, width: 1.5),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (status == 'pending_verification') {
      // v23.1 part 131 — Persona only. Upload manuel retiré.
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _onStartVerification,
              icon: _busy
                  ? SizedBox(
                      width: 18.sp, height: 18.sp,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.bolt_rounded,
                      color: Colors.white, size: 20.sp),
              label: Text(
                _busy ? 'Chargement...' : '⚡ Lancer la vérification Persona',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          InterText(
            text: 'Scan ID + selfie, vérification automatique ~2 minutes.',
            fontSize: 11.sp,
            color: AppColors.greyColor,
          ),
        ],
      );
    }
    // 'none' or 'pending_payment' — Persona payant uniquement.
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _onPay,
            icon: _busy
                ? SizedBox(
                    width: 18.sp, height: 18.sp,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.bolt_rounded,
                    color: Colors.white, size: 20.sp),
            label: Text(
              _busy ? 'Chargement...' : '⚡ Vérification rapide — $price €',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
        SizedBox(height: 4.h),
        InterText(
          text: 'Paiement 3 €, scan ID + selfie, ~2 minutes.',
          fontSize: 11.sp,
          color: AppColors.greyColor,
        ),
      ],
    );
  }

  // v23.1 part 131 — Daniel : "Verification uniquement par persona et
  // automatique, virer verifier gratuit". L'upload manuel a été retiré.
  // Le code ImagePicker / uploadIdentityManually n'est plus appelé.
  // Le bouton "Lancer la vérification Persona" appelle _onStartVerification.

  Widget _buildSteps() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.scaffoldLight,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PoppinsText(
            text: 'Comment ça marche',
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 10.h),
          _stepItem('1', 'Paie 3 € (frais unique, non-remboursable)'),
          _stepItem('2', 'Scan ton passeport ou carte d\'identité'),
          _stepItem('3', 'Prends un selfie pour la liveness check'),
          _stepItem('4', 'Vérification automatique en ~2 min'),
          _stepItem('5', 'Le badge "Vérifié" apparaît sur ton profil'),
        ],
      ),
    );
  }

  Widget _stepItem(String n, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22.w, height: 22.w,
            decoration: BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              n,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: InterText(
              text: text,
              fontSize: 12.sp,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Persona WebView ─────────────────────────────────────────────────────────

class _PersonaWebViewScreen extends StatefulWidget {
  final String url;
  const _PersonaWebViewScreen({required this.url});

  @override
  State<_PersonaWebViewScreen> createState() => _PersonaWebViewScreenState();
}

class _PersonaWebViewScreenState extends State<_PersonaWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onNavigationRequest: (request) {
          // Persona uses 'persona-callback://complete' or similar to signal done.
          if (request.url.contains('complete') ||
              request.url.contains('cancelled') ||
              request.url.contains('failed')) {
            Navigator.of(context).pop();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification d\'identité'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
