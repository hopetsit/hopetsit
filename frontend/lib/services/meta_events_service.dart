import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// v529 — Service SDK Meta (Facebook App Events).
///
/// Objectif : signaler les installs + événements clés à Meta pour débloquer
/// les campagnes « Installations d'app » (bien moins chères par install que
/// le détour Trafic → hopetsit.com). App Meta ID `27796356886626061`.
///
/// iOS : Apple impose le consentement ATT (App Tracking Transparency) AVANT
/// d'activer le tracking publicitaire. On demande la permission, puis on
/// active `setAdvertiserTracking` selon la réponse. Android : pas de popup
/// ATT (règle Apple uniquement) → tracking actif directement, attribution
/// quasi complète.
///
/// Tout est non bloquant et non fatal : une erreur du SDK ne doit jamais
/// empêcher l'app de démarrer.
class MetaEventsService {
  MetaEventsService._();
  static final MetaEventsService instance = MetaEventsService._();

  final FacebookAppEvents _fb = FacebookAppEvents();

  /// À appeler une fois au démarrage (après runApp, quand une frame est prête
  /// — la popup ATT ne doit pas s'afficher pendant l'écran de lancement).
  Future<void> init() async {
    try {
      if (Platform.isIOS) {
        // Attendre l'état ATT courant ; si "notDetermined", présenter la popup
        // Apple. iOS 14+ uniquement — sur versions antérieures la lib renvoie
        // "authorized" d'office.
        var status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          status = await AppTrackingTransparency.requestTrackingAuthorization();
        }
        final authorized = status == TrackingStatus.authorized;
        // Aligne le tracking pub Meta sur la réponse de l'utilisateur. Refusé =
        // pas d'IDFA, mais les events + SKAdNetwork restent utiles à Meta.
        await _fb.setAdvertiserTracking(enabled: authorized);
      } else {
        // Android : consentement pub actif d'emblée.
        await _fb.setAdvertiserTracking(enabled: true);
      }

      // Active le log automatique des events standards, dont
      // `fb_mobile_activate_app` (activation/install) — base de l'optimisation
      // « Installations ». Le SDK natif l'émet à chaque lancement au premier
      // plan ; pas de méthode manuelle "logActivatedApp" côté plugin.
      await _fb.setAutoLogAppEventsEnabled(true);
    } catch (e) {
      debugPrint('MetaEventsService.init error: $e');
    }
  }

  /// Événement de complétion d'inscription — signal fort pour l'algorithme
  /// (Meta cherchera des profils similaires à ceux qui créent un compte).
  Future<void> logCompletedRegistration({String? method}) async {
    try {
      await _fb.logCompletedRegistration(registrationMethod: method);
    } catch (e) {
      debugPrint('MetaEventsService.logCompletedRegistration error: $e');
    }
  }
}
