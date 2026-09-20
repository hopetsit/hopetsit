import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/kyc_repository.dart';
import 'package:hopetsit/services/airwallex_payment_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/views/profile/widgets/edit_profile_widgets.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:permission_handler/permission_handler.dart';
// v23.1 part 131 — image_picker + dart:io retirés (KYC manuel supprimé).
import 'package:webview_flutter/webview_flutter.dart';
// v23.1 part 244 — Daniel : "Impossible d'acceder a la camera" sur Persona.
// On a besoin de l'API Android-specifique du webview pour intercepter
// onPermissionRequest et grant CAMERA + RECORD_AUDIO au site hosted.
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

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
  // v565 — point 39 : message d'erreur de chargement (état « Réessayer »).
  String _loadError = '';

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
    setState(() {
      _loading = true;
      _loadError = '';
    });
    try {
      // v23.1 part 247 — capture l'ancien status pour detecter la
      // transition pending -> verified et fire notifyChanged().
      final prevStatus = (_status['kycStatus'] ?? 'none').toString();
      _status = await _repo.getStatus();
      final newStatus = (_status['kycStatus'] ?? 'none').toString();
      // Daniel : "sa la valider mais sa ne mas pas mis dans lapp ni
      // identiter verifier ni le beau badge verifier". Cause : apres que
      // le backend (v247 poll fallback) flippe kycStatus en 'verified',
      // les autres widgets de l'app (KycStatusBanner sur profile, etc.)
      // ne refresh pas car ils ecoutent ActiveBenefitsRow.refreshTick.
      // On le poke ici manuellement -> tous les banners + badges
      // refresh instantanement.
      if (newStatus == 'verified' && prevStatus != 'verified') {
        try { ActiveBenefitsRow.notifyChanged(); } catch (_) {/* defensive */}
      }
    } catch (e) {
      AppLogger.logError('kyc.getStatus failed', error: e);
      _loadError = e is ApiException && e.message.isNotEmpty
          ? e.message
          : 'kyc_load_error'.tr;
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
          message: 'kyc_payment_start_failed'.tr,
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
        // v568 — client Airwallex : la page propose la carte enregistrée
        // au lieu d'une nouvelle saisie.
        customerId: (initResp['customerId'] as String?)?.trim().isEmpty ?? true
            ? null
            : initResp['customerId'] as String?,
      );
      if (result.outcome == AirwallexPaymentOutcome.success) {
        CustomSnackbar.showSuccess(
          // v23.1 part 243 — i18n.
          title: 'kyc_payment_confirmed'.tr,
          message: 'kyc_payment_confirmed_msg'.tr,
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
            // v23.1 part 243 — i18n.
            title: 'kyc_sync_pending_title'.tr,
            message: 'kyc_sync_pending_msg'.tr,
          );
        }
      } else {
        CustomSnackbar.showError(
          // v23.1 part 243 — i18n.
          title: 'kyc_payment_canceled_title'.tr,
          message: result.errorMessage ?? 'kyc_payment_canceled_retry'.tr,
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
      // v23.1 part 244 — Daniel screenshot : webview Persona bloque sur
      // "Impossible d'acceder a la camera". Cause : sur Android, l'OS
      // n'accorde pas implicitement les permissions natives a une page
      // web qui les demande via getUserMedia. On doit (1) demander le
      // grant OS-level via permission_handler AVANT d'ouvrir le webview,
      // (2) intercepter onPermissionRequest cote webview Android pour
      // forward le grant a la page hosted. Ici on fait l'etape (1) en
      // sequentiel pour que l'user voie les dialogs systeme natifs
      // (claires + traduites par Android) avant d'ouvrir Persona.
      final camStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();
      if (camStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
        // L'user a coche "Ne plus demander" → on doit l'envoyer dans
        // les Settings systeme pour debloquer.
        CustomSnackbar.showWarning(
          title: 'kyc_perm_blocked_title'.tr,
          message: 'kyc_perm_blocked_msg'.tr,
        );
        await openAppSettings();
        return;
      }
      if (!camStatus.isGranted) {
        CustomSnackbar.showWarning(
          title: 'kyc_perm_camera_title'.tr,
          message: 'kyc_perm_camera_msg'.tr,
        );
        return;
      }
      // Microphone facultatif (Persona l'utilise pour le liveness audio
      // mais marche aussi sans) — on log juste mais on continue.
      if (!micStatus.isGranted) {
        AppLogger.logError(
          'kyc.start microphone permission not granted, '
          'liveness check may be reduced.',
        );
      }
      final resp = await _repo.startVerification();
      final url = resp['oneTimeLink'] as String?;
      if (url == null || url.isEmpty) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'kyc_link_unavailable'.tr,
        );
        return;
      }
      // Open Persona webview
      await Get.to(() => _PersonaWebViewScreen(url: url));
      // Refresh status after webview closes
      await _refresh();
    } catch (e) {
      AppLogger.logError('kyc.start failed', error: e);
      // v23.1 part 216 — Daniel : "Persona est configure dans render et
      // sa ne marche que dal". Les env vars sont OK mais le backend
      // renvoie 400 avec un message specifique (paiement requis, deja
      // verifie, etc.). Avant on affichait "indisponible" generique.
      // Maintenant on PARSE le message du backend et on surface la
      // vraie raison.
      final s = e.toString();
      if (s.contains('KYC_NOT_CONFIGURED') ||
          s.contains('temporarily unavailable')) {
        CustomSnackbar.showWarning(
          title: 'kyc_unavailable_title'.tr,
          message: 'kyc_unavailable_msg'.tr,
        );
      } else if (s.contains('Payment required first') ||
          s.contains('initiate-payment')) {
        CustomSnackbar.showWarning(
          title: 'kyc_payment_required_title'.tr,
          message: 'kyc_payment_required_msg'.tr,
        );
      } else if (s.contains('Already verified')) {
        CustomSnackbar.showSuccess(
          title: 'kyc_already_verified_title'.tr,
          message: 'kyc_already_verified_msg'.tr,
        );
      } else if (s.contains('Only sitter or walker')) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'kyc_only_provider_msg'.tr,
        );
      } else {
        // Defaut : on essaie d'extraire le message backend brut au lieu
        // du stacktrace complet. ApiException expose le body en string.
        final clean = s
            .replaceAll('ApiException:', '')
            .replaceAll('Exception:', '')
            .trim();
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: clean.isEmpty ? 'kyc_link_unavailable'.tr : clean,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // v565 — point 39 : kit Profil (carte d'état, actions en boutons du kit,
    // étapes numérotées), états chargement / erreur avec « Réessayer ».
    return ProfileSubPageScaffold(
      title: 'kyc_screen_title'.tr,
      accent: _accent,
      scroll: false,
      padding: EdgeInsets.zero,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_accent),
              ),
            )
          : (_loadError.isNotEmpty && _status.isEmpty)
              ? ProfileEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'kyc_load_error_title'.tr,
                  message: _loadError,
                  accent: _accent,
                  error: true,
                  actionLabel: 'common_retry'.tr,
                  onAction: _refresh,
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final status = (_status['kycStatus'] ?? 'none').toString();
    final price = _status['price'] ?? 3;
    return RefreshIndicator(
      onRefresh: _refresh,
      color: _accent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 28.h),
        children: [
          // En-tête : pourquoi + état courant.
          ProfileFormCard(
            accent: _accent,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Icon(Icons.verified_user_rounded, color: _accent, size: 22.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PoppinsText(
                          text: 'kyc_screen_why_title'.tr,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        InterText(
                          // v23.1 part 243 — i18n.
                          text: 'kyc_screen_why_body'.tr,
                          fontSize: 13.sp,
                          color: AppColors.textSecondary(context),
                          height: 1.4,
                          maxLines: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _statusRow(status, price.toString()),
            ],
          ),
          _buildActionForStatus(status, price),
          SizedBox(height: 6.h),
          _buildSteps(),
        ],
      ),
    );
  }

  Widget _statusRow(String status, String price) {
    String label;
    Color color;
    IconData icon;
    // v23.1 part 243 — i18n. kyc_status_* keys.
    switch (status) {
      case 'verified':
        label = 'kyc_status_verified'.tr;
        color = const Color(0xFF1976D2);
        icon = Icons.verified_rounded;
        break;
      case 'pending_verification':
        label = 'kyc_status_pending_verification'.tr;
        color = const Color(0xFFE8920A);
        icon = Icons.pending_outlined;
        break;
      case 'pending_payment':
        label = 'kyc_status_pending_payment'.tr;
        color = const Color(0xFFE8920A);
        icon = Icons.payment_outlined;
        break;
      case 'rejected':
        label = 'kyc_status_rejected'.tr;
        color = const Color(0xFFE53935);
        icon = Icons.cancel_outlined;
        break;
      default:
        label = 'kyc_status_none'.trParams({'price': price.toString()});
        color = AppColors.greyColor;
        icon = Icons.circle_outlined;
    }
    return Row(
      children: [
        InterText(
          text: 'kyc_section_status'.tr,
          fontSize: 12.5.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(width: 8.w),
        Flexible(child: ProfileStatusPill(icon: icon, text: label, color: color)),
      ],
    );
  }

  Widget _buildActionForStatus(String status, dynamic price) {
    if (status == 'verified') {
      final verifiedAt = _status['kycVerifiedAt']?.toString() ?? '';
      final dateStr = verifiedAt.isNotEmpty ? verifiedAt.split('T').first : '';
      const blue = Color(0xFF1976D2);
      return ProfileFormCard(
        accent: _accent,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: BoxDecoration(
                    color: blue.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.verified_rounded, color: blue, size: 40.sp),
                ),
                SizedBox(height: 12.h),
                // v23.1 part 243 — i18n.
                PoppinsText(
                  text: 'kyc_done_title'.tr,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: blue,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
                if (dateStr.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  InterText(
                    text: 'kyc_done_date'.trParams({'date': dateStr}),
                    fontSize: 12.sp,
                    color: AppColors.textSecondary(context),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }
    if (status == 'rejected') {
      const red = Color(0xFFE53935);
      return ProfileFormCard(
        accent: _accent,
        children: [
          Row(
            children: [
              Icon(Icons.cancel_rounded, color: red, size: 22.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: PoppinsText(
                  // v23.1 part 243 — i18n.
                  text: 'kyc_rejected_title'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: red,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          InterText(
            text: _status['kycRejectionReason']?.toString() ?? 'kyc_rejected_default'.tr,
            fontSize: 13.sp,
            color: AppColors.textPrimary(context),
            height: 1.4,
            maxLines: 8,
          ),
          // v23.1 part 131 — Persona uniquement : relancer la vérification.
          ProfileSecondaryButton(
            label: _busy ? 'kyc_loading'.tr : 'kyc_relaunch_persona'.tr,
            accent: _accent,
            icon: Icons.bolt_rounded,
            onTap: _busy ? null : _onStartVerification,
          ),
        ],
      );
    }
    if (status == 'pending_verification') {
      // v23.1 part 131 — Persona only.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfilePrimaryButton(
            label: 'kyc_launch_persona_btn'.tr,
            accent: _accent,
            icon: Icons.bolt_rounded,
            loading: _busy,
            onTap: _busy ? null : _onStartVerification,
          ),
          SizedBox(height: 8.h),
          InterText(
            // v23.1 part 243 — i18n.
            text: 'kyc_hint_after_payment'.tr,
            fontSize: 11.5.sp,
            color: AppColors.textSecondary(context),
            textAlign: TextAlign.center,
            maxLines: 3,
          ),
        ],
      );
    }
    // 'none' or 'pending_payment' — Persona payant uniquement.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfilePrimaryButton(
          label: 'kyc_quick_verify_btn'.trParams({'price': price.toString()}),
          accent: _accent,
          icon: Icons.bolt_rounded,
          loading: _busy,
          onTap: _busy ? null : _onPay,
        ),
        SizedBox(height: 8.h),
        InterText(
          // v23.1 part 243 — i18n.
          text: 'kyc_hint_before_payment'.tr,
          fontSize: 11.5.sp,
          color: AppColors.textSecondary(context),
          textAlign: TextAlign.center,
          maxLines: 3,
        ),
      ],
    );
  }

  // v23.1 part 131 — Daniel : "Verification uniquement par persona et
  // automatique, virer verifier gratuit". L'upload manuel a été retiré.

  Widget _buildSteps() {
    return ProfileFormCard(
      title: 'kyc_steps_title'.tr,
      icon: Icons.format_list_numbered_rounded,
      accent: _accent,
      gap: 10,
      children: [
        // v23.1 part 243 — i18n.
        _stepItem('1', 'kyc_step1'.tr),
        _stepItem('2', 'kyc_step2'.tr),
        _stepItem('3', 'kyc_step3'.tr),
        _stepItem('4', 'kyc_step4'.tr),
        _stepItem('5', 'kyc_step5'.tr),
      ],
    );
  }

  Widget _stepItem(String n, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24.w,
          height: 24.w,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            n,
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w800,
              color: _accent,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: InterText(
            text: text,
            fontSize: 13.sp,
            color: AppColors.textPrimary(context),
            height: 1.35,
            maxLines: 4,
          ),
        ),
      ],
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

// v23.1 part 247 + 251 — JS injecte pour masquer la banniere orange
// "You are in a Sandbox environment" de Persona.
//
// v251 — Daniel : "effacer le message sandbox qd personna souvre". Le
// scan one-shot v247 ratait la banniere car Persona est une SPA qui la
// rend EN DIFFERE (apres onPageFinished). Nouvelle approche robuste :
//   1. hideFn() : scan + hide (remonte jusqu'au parent banner, max 6 lvl).
//   2. Run immediat.
//   3. MutationObserver sur document.body → re-run a chaque mutation DOM
//      (catch la banniere des qu'elle est injectee, meme apres navigation
//      SPA interne Persona).
//   4. setInterval 400ms pendant 12s en filet de securite (au cas ou
//      l'observer raterait un cas).
// Guard window flag pour ne pas re-installer observer + interval a
// chaque page load.
const String _hidePersonaSandboxBannerJs = '''
(function() {
  try {
    function hideFn() {
      try {
        var walker = document.createTreeWalker(
          document.body, NodeFilter.SHOW_TEXT, null, false);
        var nodes = [];
        var n;
        while ((n = walker.nextNode())) {
          var txt = (n.nodeValue || '').toLowerCase();
          if (txt.indexOf('sandbox environment') !== -1 ||
              txt.indexOf('environment is for testing') !== -1 ||
              txt.indexOf('never enter your personal') !== -1) {
            nodes.push(n);
          }
        }
        nodes.forEach(function(node) {
          var p = node.parentElement;
          var lvl = 0;
          while (p && lvl < 7) {
            var text = (p.textContent || '');
            if (text.length < 900 &&
                (text.toLowerCase().indexOf('sandbox environment') !== -1 ||
                 text.toLowerCase().indexOf('environment is for testing') !== -1)) {
              p.style.setProperty('display', 'none', 'important');
              p.style.setProperty('visibility', 'hidden', 'important');
              p.style.setProperty('height', '0', 'important');
              p.style.setProperty('max-height', '0', 'important');
              p.style.setProperty('overflow', 'hidden', 'important');
              break;
            }
            p = p.parentElement;
            lvl++;
          }
        });
      } catch (e) {}
    }
    hideFn();
    if (!window.__hpt_persona_banner_installed) {
      window.__hpt_persona_banner_installed = true;
      // 1) MutationObserver : re-hide a chaque changement DOM.
      try {
        var obs = new MutationObserver(function() { hideFn(); });
        obs.observe(document.body, { childList: true, subtree: true });
      } catch (e) {}
      // 2) Filet de securite : interval 400ms pendant 12s.
      var ticks = 0;
      var iv = setInterval(function() {
        hideFn();
        ticks++;
        if (ticks > 30) clearInterval(iv);
      }, 400);
    }
  } catch (e) {/* defensive */}
})();
''';

class _PersonaWebViewScreenState extends State<_PersonaWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // v23.1 part 244 — Daniel screenshot "Impossible d'acceder a la camera".
    // Sur Android, on doit configurer le PlatformWebViewControllerCreationParams
    // pour activer le mediaPlaybackRequiresUserGesture=false + handler les
    // permissions web (getUserMedia). Sur iOS, WKWebView a besoin de
    // allowsInlineMediaPlayback + mediaTypesRequiringUserAction vide pour
    // que Persona puisse demarrer la camera sans intervention user.
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) async {
          if (mounted) setState(() => _loading = false);
          // v23.1 part 247 — Daniel screenshot : "dans lapp faite que ce
          // message ne sorte pas". Persona affiche en haut une banniere
          // orange "You are in a Sandbox environment" quand on est en
          // sandbox mode. Pas possible de la desactiver cote Persona —
          // on l'injecte hors-DOM via CSS apres chaque page load. Solution
          // robuste : injecter une <style> qui hide tout banner avec
          // class contenant 'sandbox' OU contenu texte "Sandbox env".
          //
          // NB : la VRAIE fix est de passer PERSONA_API_KEY de sandbox vers
          // production sur Render. Tant qu'on reste en sandbox la banniere
          // existe ; cette injection est un masque visuel cote user app.
          try {
            await _controller.runJavaScript(_hidePersonaSandboxBannerJs);
          } catch (_) {/* defensive */}
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
      ));

    // v23.1 part 244 — Android-specific : autoriser CAMERA + RECORD_AUDIO
    // pour les requetes getUserMedia faites par Persona dans le webview.
    // Sans ce hook, le webview rejette silencieusement → "Impossible
    // d'acceder a la camera". L'API setOnPlatformPermissionRequest est
    // exposee via la platform interface AndroidWebViewController.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final platform = _controller.platform;
      if (platform is AndroidWebViewController) {
        platform.setMediaPlaybackRequiresUserGesture(false);
        platform.setOnPlatformPermissionRequest((request) {
          // Persona demandera camera (et possiblement audio pour liveness).
          // On grant tout ce que Persona demande — la pre-check Android
          // dans _onStartVerification garantit que l'user a deja accepte
          // au niveau OS.
          request.grant();
        });
      }
    }

    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    // v573 — c'était le SEUL `AppBar` Material brut de l'app (titre au style
    // par défaut, fond et élévation du thème). Il adopte l'en-tête du reste
    // des écrans : `AppColors.appBar`, elevation 0, titre `PoppinsText`,
    // fine ligne de séparation. Le WebView et sa logique sont inchangés.
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: PoppinsText(
          text: 'kyc_identity_title'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          tooltip: 'common_close'.tr,
          icon: Icon(Icons.close_rounded,
              size: 22.sp, color: AppColors.textPrimary(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider(context)),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            Positioned.fill(
              child: Container(
                color: AppColors.scaffold(context),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64.w,
                      height: 64.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.verified_user_rounded,
                          size: 30.sp,
                          color: AppColors.accentOn(
                              context, AppColors.primaryColor)),
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: 140.w,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999.r),
                        child: LinearProgressIndicator(
                          minHeight: 4.h,
                          backgroundColor: AppColors.divider(context),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.accentOn(
                                context, AppColors.primaryColor),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    InterText(
                      text: 'pawmap_loading'.tr,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
