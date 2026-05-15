import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/payment/airwallex_payment_screen.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// v18.8 — écoute les deep links `hopetsit://pay/:bookingId` envoyés dans
/// les emails "Bonne nouvelle, votre demande de réservation vient d'être
/// acceptée". Avant v18.8, le bouton "Payer maintenant" du mail ouvrait
/// l'app mais n'ouvrait PAS la page de paiement → l'owner devait naviguer
/// à la main vers Réservations. Désormais on route automatiquement vers
/// `AirwallexPaymentScreen(booking: ..., providerType: ...)`.
///
/// v23.1 part 146 — Bug fix : écran noir indéfini quand l'app était lancée
/// via un lien `https://www.hopetsit.com/...` (cliqué depuis un email ou
/// un partage). 3 causes cumulées :
///   1. `www.hopetsit.com` n'était pas dans la whitelist → handle rejette
///      silencieusement, mais l'app a quand même reçu un Intent VIEW qui
///      peut bloquer le boot Flutter.
///   2. Race condition : `start()` était appelé AVANT `runApp(MyApp())`
///      donc `Get.to(...)` côté handler push dans un GetMaterialApp non
///      encore monté → navigation cassée + écran noir.
///   3. Aucun fallback pour les paths non reconnus (`/`, `/login`, `/walkers`,
///      etc.) → l'app recevait le lien mais ne savait pas quoi en faire.
///
/// Fix :
///   - Whitelist élargie : `hopetsit.com`, `www.hopetsit.com`, `app.hopetsit.com`
///   - Buffering : si la nav GetX n'est pas encore prête (Get.context == null
///     ou GetMaterialApp pas monté), on stocke l'URI dans `_pendingUri` et on
///     la rejoue via [flushPending()] appelé après le premier frame de MyApp.
///   - Try/catch ultra-large dans `_handle` → jamais d'exception qui remonte
///     vers le main isolate.
///   - Fallback gracieux : path non reconnu → on log et on laisse le splash
///     router normalement (pas d'écran noir).
class DeepLinkService {
  DeepLinkService._internal();
  static final DeepLinkService instance = DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  /// v23.1 part 146 — URIs reçues AVANT que `GetMaterialApp` soit monté.
  /// On les rejoue via [flushPending] au premier frame.
  final List<Uri> _pendingUris = <Uri>[];

  /// v23.1 part 146 — true une fois que `MyApp` a fait son premier frame et
  /// que `Get.context` est utilisable. Mis à true par [flushPending].
  bool _navigatorReady = false;

  /// À appeler au démarrage de l'app (après Get.put des repos/controllers).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        await _safeHandle(initial);
      }
    } catch (e) {
      AppLogger.logError('DeepLinkService.getInitialLink failed', error: e);
    }
    _sub = _appLinks.uriLinkStream.listen(
      (uri) async {
        await _safeHandle(uri);
      },
      onError: (Object e) {
        AppLogger.logError('DeepLinkService stream error', error: e);
      },
    );
  }

  /// v23.1 part 146 — wrapper paranoïaque : aucune exception ne remonte au
  /// main isolate. Si le navigator n'est pas encore prêt, on bufferise.
  Future<void> _safeHandle(Uri uri) async {
    try {
      if (!_navigatorReady) {
        AppLogger.logInfo(
          'DeepLink buffered (navigator not ready): ${uri.scheme}://${uri.host}${uri.path}',
        );
        _pendingUris.add(uri);
        return;
      }
      await _handle(uri);
    } catch (e, st) {
      // Catch large : on ne propage JAMAIS — sinon écran noir au boot.
      AppLogger.logError(
        'DeepLinkService._safeHandle failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// v23.1 part 146 — appelée depuis `MyApp` (ou splash) après le premier
  /// frame. Marque le navigator comme prêt et rejoue les URIs bufferisées.
  Future<void> flushPending() async {
    _navigatorReady = true;
    if (_pendingUris.isEmpty) return;
    final pending = List<Uri>.from(_pendingUris);
    _pendingUris.clear();
    AppLogger.logInfo(
      'DeepLink flushing ${pending.length} buffered URI(s)',
    );
    for (final uri in pending) {
      try {
        await _handle(uri);
      } catch (e, st) {
        AppLogger.logError(
          'DeepLinkService flushPending failed for $uri',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
    _navigatorReady = false;
    _pendingUris.clear();
  }

  /// v23.1 part 125 — Phase 2 audit M1.
  /// Regex strict pour valider un Mongo ObjectId 24 hex chars. Tout autre
  /// pattern (URL malicieuse passée via Intent depuis une app tierce, ou
  /// payload nullbyte/SQLi style) est rejeté AVANT navigation.
  static final RegExp _objectIdRegex = RegExp(r'^[a-fA-F0-9]{24}$');

  /// v23.1 part 146 — Regex stricte pour le one-time token de bridge web→app.
  /// Format : 64 chars hex lowercase (32 bytes random côté backend).
  /// Toute autre chaîne est rejetée avant l'appel `/auth/exchange`.
  static final RegExp _ottRegex = RegExp(r'^[a-f0-9]{64}$');

  /// v23.1 part 146 — hosts HTTPS autorisés pour les App Links.
  /// Inclut `www.` car Vercel sert le site sur les deux variantes et
  /// l'utilisateur peut taper sur n'importe laquelle depuis un email.
  static const Set<String> _allowedHttpsHosts = <String>{
    'hopetsit.com',
    'www.hopetsit.com',
    'app.hopetsit.com',
  };

  Future<void> _handle(Uri uri) async {
    // v23.1 part 125 — accepte exclusivement :
    //   hopetsit://<action>[/<arg>]                    (deep link app)
    //   https://hopetsit.com/<action>[/<arg>]          (App Links signés)
    //   https://www.hopetsit.com/<action>[/<arg>]      (variante www, v146)
    //   https://app.hopetsit.com/<action>[/<arg>]      (sous-domaine futur)
    // Tout autre host HTTPS est rejeté — empêche une app tierce de
    // forger une URL `https://malicious.example/pay/<id>` qui serait
    // résolue par notre AppLinks listener.
    if (uri.scheme == 'hopetsit') {
      // OK, scheme custom propre.
    } else if (uri.scheme == 'https' && _allowedHttpsHosts.contains(uri.host)) {
      // OK, App Links signés (autoVerify=true en manifest).
    } else {
      AppLogger.logWarning(
        'DeepLink rejected (unsupported scheme/host): ${uri.scheme}://${uri.host}',
      );
      return;
    }

    final segs = uri.pathSegments;
    final first =
        uri.host.isNotEmpty && uri.scheme == 'hopetsit'
            ? uri.host
            : (segs.isNotEmpty ? segs.first : '');

    // v19.2.0 — 4 chemins supportés :
    //   hopetsit://pay/:bookingId          → écran paiement
    //   hopetsit://chat[/:conversationId]  → écran chat (liste ou conversation)
    //   hopetsit://bookings[/:bookingId]   → écran réservations (provider accepte)
    //   hopetsit://notifications           → écran notifications
    // v23.1 part 146 — 5e chemin :
    //   hopetsit://auth?ott=<token>        → bridge session web → app
    if (first == 'pay') {
      // v23.1 part 125 — bookingId DOIT être un ObjectId 24 hex. Sinon
      // on log et on ignore (anti Intent Redirection).
      final rawBookingId = segs.isNotEmpty ? segs.last : '';
      if (!_objectIdRegex.hasMatch(rawBookingId)) {
        AppLogger.logWarning(
          'DeepLink rejected (invalid bookingId): "$rawBookingId"',
        );
        return;
      }
      await _openPayment(rawBookingId);
    } else if (first == 'chat') {
      // Récupère ?conversationId ou /chat/:id. Pour l'instant on navigue vers
      // le tab Chat — l'écran individuel sera ouvert via le badge si besoin.
      Get.toNamed('/chat');
    } else if (first == 'bookings') {
      Get.toNamed('/bookings');
    } else if (first == 'notifications') {
      Get.toNamed('/notifications');
    } else if (first == 'auth') {
      // v23.1 part 146 — auto-login via one-time token issued by the website.
      // Format attendu : hopetsit://auth?ott=<64 hex>
      //              ou : https://hopetsit.com/auth?ott=<64 hex>
      final ott = uri.queryParameters['ott'];
      if (ott == null || !_ottRegex.hasMatch(ott)) {
        AppLogger.logWarning(
          'DeepLink rejected (invalid ott): "${ott ?? "<null>"}"',
        );
        return;
      }
      await _handleAuthOtt(ott);
    } else {
      AppLogger.logInfo(
        'DeepLink path not handled (no-op): "${uri.path}"',
      );
    }
  }

  /// v23.1 part 146 — Bridge de session web → app.
  ///
  /// Reçoit un OTT (one-time token) issu de POST /auth/one-time-token côté
  /// website. On l'échange via POST /auth/exchange contre un JWT 30j et on
  /// applique la session dans `AuthController.applyExchangedSession`, qui
  /// stocke le token + role + user et navigate vers le bon home.
  ///
  /// Robustesse :
  ///   - L'OTT a déjà été validé par regex côté `_handle`.
  ///   - On affiche un loader pendant le call réseau (peut prendre ~500ms
  ///     sur Render free-tier en cold start).
  ///   - En cas d'erreur (token expiré, déjà utilisé, réseau down), on
  ///     ferme le loader et on montre un toast d'erreur. L'utilisateur
  ///     atterrit sur l'écran courant (splash → onboarding ou home).
  Future<void> _handleAuthOtt(String ott) async {
    // Loader pendant l'exchange. Si Get.context est null malgré
    // `_navigatorReady = true` (cas pathologique), on skip silencieusement
    // le loader visuel mais on continue l'exchange.
    final hasContext = Get.context != null;
    if (hasContext) {
      showDialog(
        context: Get.context!,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.25),
        builder: (_) => const Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
    }

    try {
      if (!Get.isRegistered<ApiClient>()) {
        AppLogger.logError(
          'DeepLink _handleAuthOtt: ApiClient not registered',
        );
        return;
      }
      final apiClient = Get.find<ApiClient>();
      final response = await apiClient.post(
        '/auth/exchange',
        body: {'token': ott},
      );

      if (response is! Map<String, dynamic>) {
        AppLogger.logError(
          'DeepLink _handleAuthOtt: unexpected response type ${response.runtimeType}',
        );
        if (hasContext && Get.isDialogOpen == true) Get.back();
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'common_error_message'.tr,
        );
        return;
      }

      // Ferme le loader AVANT d'appeler applyExchangedSession (qui va
      // Get.offAll vers home — sinon le loader resterait par-dessus).
      if (hasContext && Get.isDialogOpen == true) Get.back();

      if (!Get.isRegistered<AuthController>()) {
        AppLogger.logError(
          'DeepLink _handleAuthOtt: AuthController not registered',
        );
        return;
      }
      final authController = Get.find<AuthController>();
      final ok = await authController.applyExchangedSession(response);

      if (!ok) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'common_error_message'.tr,
        );
      }
    } on ApiException catch (e) {
      if (hasContext && Get.isDialogOpen == true) Get.back();
      AppLogger.logError(
        'DeepLink _handleAuthOtt ApiException',
        error: e,
      );
      // 401 = token expiré / déjà utilisé. On affiche un message clair
      // sans révéler les internes (anti enumeration).
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.statusCode == 401
            ? 'Lien expiré. Réessaye depuis le site.'
            : 'common_error_message'.tr,
      );
    } catch (e, st) {
      if (hasContext && Get.isDialogOpen == true) Get.back();
      AppLogger.logError(
        'DeepLink _handleAuthOtt failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _openPayment(String bookingId) async {
    try {
      // v18.9.8 — ouverture quasi-instantanée depuis une notif. Avant :
      // on attendait `getMyBookings()` (1-2s réseau) AVANT d'ouvrir l'écran,
      // donc écran noir pendant 2s après le tap sur la notif.
      //
      // Maintenant :
      //   1) Cache-first — on regarde si la booking est déjà en mémoire
      //      dans BookingsController ou l'ApiCache de OwnerRepository.
      //      Si oui → navigation immédiate (0ms réseau).
      //   2) Sinon → overlay loader Get.dialog pendant la fetch
      //      (spinner sur l'écran courant au lieu d'écran noir), puis
      //      push de l'écran Payment dès que la booking est dispo.
      BookingModel? booking;

      // (1) Cache-first : BookingsController garde déjà la liste en RAM.
      if (Get.isRegistered<BookingsController>()) {
        final ctrl = Get.find<BookingsController>();
        booking = ctrl.bookings.firstWhereOrNull((b) => b.id == bookingId);
      }

      // (2) Fallback réseau avec loader visible — empêche un écran vide.
      if (booking == null) {
        // Loader non-dismissible, barrier transparente pour rester sur
        // la vue actuelle.
        if (Get.context != null) {
          showDialog(
            context: Get.context!,
            barrierDismissible: false,
            barrierColor: Colors.black.withValues(alpha: 0.25),
            builder: (_) => const Center(
              child: SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          );
        }

        try {
          if (Get.isRegistered<OwnerRepository>()) {
            final repo = Get.find<OwnerRepository>();
            final all = await repo.getMyBookings();
            booking = all.firstWhereOrNull((b) => b.id == bookingId);
          }
          if (booking == null && Get.isRegistered<BookingsController>()) {
            final ctrl = Get.find<BookingsController>();
            await ctrl.loadBookings();
            booking = ctrl.bookings.firstWhereOrNull((b) => b.id == bookingId);
          }
        } finally {
          // Ferme le loader qu'on ait trouvé la booking ou pas.
          if (Get.isDialogOpen == true) Get.back();
        }
      }

      if (booking == null) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'common_error_message'.tr,
        );
        return;
      }
      final alreadyPaid =
          (booking.paymentStatus ?? '').toLowerCase() == 'paid';
      if (alreadyPaid) {
        // Nothing to do — booking already paid.
        return;
      }
      final pricing = booking.pricing;
      final base = (pricing?.totalPrice ??
              pricing?.resolvedBaseAmount ??
              booking.totalAmount ??
              booking.basePrice) ??
          0.0;
      final serviceLower = (booking.serviceType ?? '').toLowerCase();
      final providerType = serviceLower.contains('walking') ||
              serviceLower.contains('dog_walking')
          ? 'walker'
          : 'sitter';
      Get.to(
        () => AirwallexPaymentScreen(
          booking: booking!,
          totalAmount: base,
          currency: pricing?.currency ?? booking.sitter.currency,
          providerType: providerType,
        ),
        // v18.9.8 — transition instantanée pour rester cohérent avec le
        // reste des flows critiques (payment, chat).
        transition: Transition.rightToLeft,
        duration: const Duration(milliseconds: 180),
      );
    } on ApiException catch (e) {
      if (Get.isDialogOpen == true) Get.back();
      AppLogger.logError('DeepLink _openPayment ApiException', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_message'.tr,
      );
    } catch (e) {
      if (Get.isDialogOpen == true) Get.back();
      AppLogger.logError('DeepLink _openPayment failed', error: e);
    }
  }
}
