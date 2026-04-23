import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/payment/stripe_payment_screen.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// v18.8 — écoute les deep links `hopetsit://pay/:bookingId` envoyés dans
/// les emails "Bonne nouvelle, votre demande de réservation vient d'être
/// acceptée". Avant v18.8, le bouton "Payer maintenant" du mail ouvrait
/// l'app mais n'ouvrait PAS la page de paiement → l'owner devait naviguer
/// à la main vers Réservations. Désormais on route automatiquement vers
/// `StripePaymentScreen(booking: ..., providerType: ...)`.
class DeepLinkService {
  DeepLinkService._internal();
  static final DeepLinkService instance = DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  /// À appeler au démarrage de l'app (après Get.put des repos/controllers).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        await _handle(initial);
      }
    } catch (e) {
      AppLogger.logError('DeepLinkService.getInitialLink failed', error: e);
    }
    _sub = _appLinks.uriLinkStream.listen(
      (uri) async {
        try {
          await _handle(uri);
        } catch (e) {
          AppLogger.logError('DeepLinkService._handle failed', error: e);
        }
      },
      onError: (Object e) {
        AppLogger.logError('DeepLinkService stream error', error: e);
      },
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  Future<void> _handle(Uri uri) async {
    // Accepte hopetsit://pay/:bookingId ET https://app.hopetsit.com/pay/:bookingId.
    if (uri.scheme != 'hopetsit' && !uri.host.contains('hopetsit')) return;

    final segs = uri.pathSegments;
    final first = uri.host.isNotEmpty ? uri.host : (segs.isNotEmpty ? segs.first : '');
    if (first == 'pay') {
      // hopetsit://pay/:bookingId  →  host=pay, pathSegments=[bookingId]
      final bookingId = segs.isNotEmpty ? segs.last : '';
      if (bookingId.isNotEmpty) {
        await _openPayment(bookingId);
      }
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
        () => StripePaymentScreen(
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
