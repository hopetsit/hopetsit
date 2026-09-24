import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/services/push_notification_service.dart';

/// v583 (lot A du 24/09, décision de Daniel du 23/09) — règle PURE qui dit si
/// la fenêtre de suivi publicitaire d'Apple (ATT) peut être présentée
/// maintenant. Testée dans `test/lota583_att_test.dart`.
///
///   · [hasSession] : l'utilisateur est entré dans l'app (jeton présent) — la
///     fenêtre ne s'affiche plus au tout premier lancement, avant l'inscription ;
///   · [notificationsDecided] : la question « notifications » a déjà une
///     réponse (autorisée ou refusée) — donc elle ne sera PAS posée dans cette
///     session ;
///   · [notificationPromptShownThisSession] : la fenêtre système des
///     notifications a DÉJÀ été posée pendant cette session → on attend le
///     lancement suivant (jamais deux fenêtres système dans la même session) ;
///   · [status] : Apple n'a pas encore de réponse.
bool attPromptAllowed({
  required bool hasSession,
  required bool notificationsDecided,
  required bool notificationPromptShownThisSession,
  required TrackingStatus status,
}) =>
    hasSession &&
    notificationsDecided &&
    !notificationPromptShownThisSession &&
    status == TrackingStatus.notDetermined;

/// v529 — Service SDK Meta (Facebook App Events).
///
/// Objectif : signaler les installs + événements clés à Meta pour débloquer
/// les campagnes « Installations d'app » (bien moins chères par install que
/// le détour Trafic → hopetsit.com). App Meta ID `27796356886626061`.
///
/// iOS : Apple impose le consentement ATT (App Tracking Transparency) AVANT
/// d'activer le tracking publicitaire. v583 : la fenêtre n'est plus demandée
/// au démarrage mais APRÈS l'inscription, une fois l'utilisateur dans l'app,
/// et jamais dans la même session que la fenêtre des notifications
/// ([requestTrackingAfterEntry]). Tant qu'Apple n'a pas de réponse, le
/// tracking pub reste éteint ; le journal automatique des événements
/// (installs, activations, SKAdNetwork) continue. Android : pas de popup ATT
/// (règle Apple uniquement) → tracking actif directement.
///
/// Tout est non bloquant et non fatal : une erreur du SDK ne doit jamais
/// empêcher l'app de démarrer.
class MetaEventsService {
  MetaEventsService._();
  static final MetaEventsService instance = MetaEventsService._();

  final FacebookAppEvents _fb = FacebookAppEvents();

  /// Délai après la première image avant d'envisager la fenêtre ATT : l'accueil
  /// doit être affiché et l'app active (Apple refuse le prompt sinon).
  static const Duration entryDelay = Duration(milliseconds: 2500);

  bool _trackingAskedThisSession = false;

  /// À appeler une fois au démarrage (après runApp, quand une frame est prête).
  /// Ne présente AUCUNE fenêtre : aligne seulement le SDK sur la réponse ATT
  /// déjà connue, et active le journal automatique des événements.
  Future<void> init() async {
    try {
      if (Platform.isIOS) {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        // Refusé ou pas encore demandé = pas d'IDFA ; les events + SKAdNetwork
        // restent utiles à Meta.
        await _fb.setAdvertiserTracking(
            enabled: status == TrackingStatus.authorized);
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

  /// v583 — fenêtre ATT d'Apple, présentée APRÈS l'entrée dans l'app et
  /// jamais dans la même session que la fenêtre des notifications (règle
  /// [attPromptAllowed]). Aucune fenêtre maison avant : c'est la fenêtre
  /// système, telle quelle (Apple 5.1.2). Une seule tentative par session.
  Future<void> requestTrackingAfterEntry() async {
    if (_trackingAskedThisSession) return;
    _trackingAskedThisSession = true;
    try {
      if (!Platform.isIOS) return;
      await Future<void>.delayed(entryDelay);
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      final allowed = attPromptAllowed(
        hasSession: _hasSession(),
        notificationsDecided: await _notificationsDecided(),
        notificationPromptShownThisSession:
            PushNotificationService.systemPromptRequestedThisSession,
        status: status,
      );
      if (!allowed) return;
      // L'app doit être au premier plan et active, sinon iOS ignore la demande
      // et la réponse resterait « notDetermined » : on réessaiera au prochain
      // lancement.
      final life = WidgetsBinding.instance.lifecycleState;
      if (life != null && life != AppLifecycleState.resumed) return;
      final answer = await AppTrackingTransparency.requestTrackingAuthorization();
      await _fb.setAdvertiserTracking(
          enabled: answer == TrackingStatus.authorized);
    } catch (e) {
      debugPrint('MetaEventsService.requestTrackingAfterEntry error: $e');
    }
  }

  bool _hasSession() {
    try {
      if (!Get.isRegistered<ApiClient>()) return false;
      final t = Get.find<ApiClient>().authToken;
      return t != null && t.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _notificationsDecided() async {
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus != AuthorizationStatus.notDetermined;
    } catch (_) {
      // Sans réponse fiable, on ne présente pas la fenêtre (elle reviendra).
      return false;
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
