import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hopetsit/services/meta_events_service.dart';

/// 636 (08/11/2026, feu vert de Daniel) — point d'entrée UNIQUE des événements
/// Meta (SDK Facebook App Events) qui servent à optimiser la pub sur les
/// propriétaires qui installent, publient une demande et paient :
///
///   1. `fb_mobile_activate_app`      — [logActivateApp], au lancement ;
///   2. `fb_mobile_complete_registration` — [logRegistrationCompleted], quand
///      l'inscription est TERMINÉE (code e-mail vérifié, ou compte Google /
///      Apple créé) ;
///   3. `demande_publiee` (événement personnalisé) — [logDemandePubliee],
///      quand une demande propriétaire est publiée ;
///   4. `fb_mobile_purchase`          — [logBookingPaid], quand une réservation
///      est payée côté propriétaire (montant + devise → ROAS Meta).
///
/// Règles :
/// - iOS : RIEN ne part sans « Autoriser » à la fenêtre ATT (Apple 5.1.2) ;
///   la fenêtre elle-même reste gérée par [MetaEventsService] (606). Android :
///   pas d'ATT, les événements partent.
/// - jamais bloquant : chaque appel est en try/catch et les appelants
///   l'utilisent en `unawaited(...)`. Pas de `.timeout` : il poserait un Timer
///   qui reste en attente dans les tests de widgets (canal natif jamais répondu).
/// - aucune donnée personnelle dans les paramètres (ids techniques, ville,
///   type de service, montant, devise seulement).
class MetaEvents636 {
  MetaEvents636._();
  static final MetaEvents636 instance = MetaEvents636._();

  static const String eventDemandePubliee = 'demande_publiee';
  static const String eventActivateApp = 'fb_mobile_activate_app';
  final FacebookAppEvents _fb = FacebookAppEvents();

  /// Coupe-circuit pour les tests d'intégration / pilotes internes : aucun
  /// appel natif. Jamais vrai dans une app de store.
  static bool disabledForTests = false;

  Future<bool> _allowed() async {
    if (disabledForTests) return false;
    try {
      if (!Platform.isIOS) return true;
      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      return adTrackingAllowed(isIOS: true, status: status);
    } catch (e) {
      debugPrint('MetaEvents636._allowed error: $e');
      return false;
    }
  }

  Future<void> _guard(String what, Future<void> Function() body) async {
    try {
      if (!await _allowed()) return;
      await body();
    } catch (e) {
      debugPrint('MetaEvents636.$what error: $e');
    }
  }

  /// 1. Activation. Android : le SDK l'envoie lui-même (journal automatique
  /// actif par défaut) → rien à faire ici, sinon l'événement serait compté
  /// deux fois. iOS : le journal automatique est éteint dans Info.plist et
  /// rallumé seulement après « Autoriser » (606) — le SDK a donc déjà manqué
  /// l'activation de CETTE session ; on l'envoie à la main, une fois, au
  /// lancement, quand l'utilisateur a autorisé.
  Future<void> logActivateApp() => _guard('logActivateApp', () async {
        if (!Platform.isIOS) return;
        await _fb.logEvent(name: eventActivateApp);
      });

  /// 2. Inscription terminée ([method] : `email`, `google`, `apple`).
  Future<void> logRegistrationCompleted({required String method}) =>
      _guard('logRegistrationCompleted', () async {
        await MetaEventsService.instance
            .logCompletedRegistration(method: method);
      });

  /// 3. Demande propriétaire publiée. [budget] + [currency] alimentent
  /// `valueToSum` pour que Meta connaisse la valeur attendue.
  Future<void> logDemandePubliee({
    String? requestId,
    String? serviceType,
    String? city,
    String? country,
    double? budget,
    String? currency,
    int? notified,
  }) =>
      _guard('logDemandePubliee', () async {
        final params = demandeParams636(
          requestId: requestId,
          serviceType: serviceType,
          city: city,
          country: country,
          currency: currency,
          notified: notified,
        );
        await _fb.logEvent(
          name: eventDemandePubliee,
          parameters: params.isEmpty ? null : params,
          valueToSum: purchaseAmount636(budget),
        );
      });

  /// 4. Réservation payée côté propriétaire → `fb_mobile_purchase`.
  Future<void> logBookingPaid({
    required double amount,
    required String currency,
    String? bookingId,
    String? paymentIntentId,
    String method = 'airwallex',
  }) =>
      _guard('logBookingPaid', () async {
        final a = purchaseAmount636(amount);
        final c = currencyCode636(currency);
        if (a == null || c == null) return; // montant ou devise inexploitable
        await _fb.logPurchase(
          amount: a,
          currency: c,
          parameters: <String, dynamic>{
            'fb_content_type': 'booking',
            if (bookingId != null && bookingId.isNotEmpty)
              'fb_content_id': bookingId,
            if (paymentIntentId != null && paymentIntentId.isNotEmpty)
              'payment_intent': paymentIntentId,
            'payment_method': method,
          },
        );
      });
}

/// Montant exploitable par Meta : positif, fini, arrondi au centime.
/// `null` sinon (Meta refuse les montants négatifs ou NaN).
double? purchaseAmount636(num? value) {
  if (value == null) return null;
  final d = value.toDouble();
  if (d.isNaN || d.isInfinite || d <= 0) return null;
  return (d * 100).roundToDouble() / 100;
}

/// Code devise ISO 4217 en majuscules (3 lettres), `null` sinon.
String? currencyCode636(String? value) {
  if (value == null) return null;
  final c = value.trim().toUpperCase();
  return RegExp(r'^[A-Z]{3}$').hasMatch(c) ? c : null;
}

/// Paramètres de `demande_publiee` sans valeur vide ni donnée personnelle.
Map<String, dynamic> demandeParams636({
  String? requestId,
  String? serviceType,
  String? city,
  String? country,
  String? currency,
  int? notified,
}) {
  String? clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  return <String, dynamic>{
    if (clean(requestId) != null) 'fb_content_id': clean(requestId),
    'fb_content_type': 'request',
    if (clean(serviceType) != null) 'service_type': clean(serviceType),
    if (clean(city) != null) 'city': clean(city),
    if (clean(country) != null) 'country': clean(country),
    if (currencyCode636(currency) != null) 'fb_currency': currencyCode636(currency),
    if (notified != null && notified >= 0) 'notified': notified,
  };
}
