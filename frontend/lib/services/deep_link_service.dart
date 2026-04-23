import 'dart:async';

import 'package:app_links/app_links.dart';
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
      BookingModel? booking;
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
      );
    } on ApiException catch (e) {
      AppLogger.logError('DeepLink _openPayment ApiException', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_message'.tr,
      );
    } catch (e) {
      AppLogger.logError('DeepLink _openPayment failed', error: e);
    }
  }
}
