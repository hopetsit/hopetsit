import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/services/firebase_analytics_service.dart';
import 'package:hopetsit/services/push_notification_service.dart';

/// 606 (ZOE, 01/10/2026) — refus Apple 1.25/605, guideline 2.1 : l'examinateur
/// (iPad Air, iPadOS 27) n'a JAMAIS vu la fenêtre de suivi publicitaire (ATT).
/// Causes mesurées dans le code v583 :
///   1. la demande n'était tentée QU'UNE fois, au démarrage : sans compte
///      connecté à ce moment-là (nouvelle installation → connexion), elle était
///      abandonnée pour toute la session ;
///   2. elle était interdite dans la même session que la fenêtre des
///      notifications, et exigeait que les notifications aient une réponse.
///
/// Nouvelle règle PURE (testée dans `test/lota583_att_test.dart`) : la fenêtre
/// est présentée dès que l'utilisateur est dans l'app ([hasSession]), qu'Apple
/// n'a pas encore de réponse ([status]), qu'AUCUNE question « notifications »
/// n'est en cours ([notificationFlowBusy] — l'ATT passe juste APRÈS elle, dans
/// la même session) et que l'app est au premier plan ([appActive], sinon iOS
/// ignore la demande).
bool attPromptAllowed({
  required bool hasSession,
  required bool notificationFlowBusy,
  required bool appActive,
  required TrackingStatus status,
}) =>
    hasSession &&
    !notificationFlowBusy &&
    appActive &&
    status == TrackingStatus.notDetermined;

/// 606 — le suivi publicitaire (Meta : IDFA, journal auto des événements,
/// événements de conversion ; Firebase : signaux pub) n'est actif sur iOS
/// QUE si l'utilisateur a répondu « Autoriser » à la fenêtre ATT. Avant la
/// réponse, ou après un refus : rien. Android : pas d'ATT (règle Apple).
bool adTrackingAllowed({required bool isIOS, required TrackingStatus status}) =>
    !isIOS || status == TrackingStatus.authorized;

/// 606 — attend le bon moment pour la fenêtre ATT, puis la présente.
/// Dépendances injectées pour être testée sans appareil. Renvoie la réponse
/// d'Apple, ou `null` si la fenêtre n'a pas pu être présentée (pas de compte,
/// déjà répondu, délai dépassé).
Future<TrackingStatus?> runAttPromptWhenReady({
  required bool Function() hasSession,
  required bool Function() notificationFlowBusy,
  required bool Function() appActive,
  required Future<TrackingStatus> Function() readStatus,
  required Future<TrackingStatus> Function() request,
  Duration initialDelay = const Duration(milliseconds: 1200),
  Duration poll = const Duration(milliseconds: 400),
  Duration maxWait = const Duration(seconds: 90),
}) async {
  await Future<void>.delayed(initialDelay);
  final deadline = DateTime.now().add(maxWait);
  while (true) {
    if (!hasSession()) return null;
    final status = await readStatus();
    if (status != TrackingStatus.notDetermined) return null;
    if (attPromptAllowed(
      hasSession: true,
      notificationFlowBusy: notificationFlowBusy(),
      appActive: appActive(),
      status: status,
    )) {
      // Petite pause après la fermeture d'une fenêtre système : iOS doit
      // repasser l'app à l'état actif avant d'accepter une nouvelle demande.
      await Future<void>.delayed(poll);
      if (!notificationFlowBusy() && appActive()) {
        return request();
      }
    }
    if (DateTime.now().isAfter(deadline)) return null;
    await Future<void>.delayed(poll);
  }
}

/// v529 — Service SDK Meta (Facebook App Events).
///
/// Objectif : signaler les installs + événements clés à Meta pour débloquer
/// les campagnes « Installations d'app » (bien moins chères par install que
/// le détour Trafic → hopetsit.com). App Meta ID `27796356886626061`.
///
/// iOS : Apple impose le consentement ATT (App Tracking Transparency) AVANT
/// d'activer le tracking publicitaire. 606 : la fenêtre est présentée dès la
/// 1re session, une fois l'utilisateur dans l'app, juste après la question
/// « notifications » ([requestTrackingAfterEntry]). Tant qu'Apple n'a pas de
/// réponse « Autoriser », RIEN ne part vers Meta (ni IDFA, ni journal
/// automatique, ni conversion) et Firebase n'envoie aucun signal pub.
/// Android : pas de popup ATT (règle Apple uniquement) → tracking actif.
///
/// Tout est non bloquant et non fatal : une erreur du SDK ne doit jamais
/// empêcher l'app de démarrer.
class MetaEventsService {
  MetaEventsService._();
  static final MetaEventsService instance = MetaEventsService._();

  final FacebookAppEvents _fb = FacebookAppEvents();

  /// Délai après l'appel avant d'envisager la fenêtre ATT : l'accueil doit
  /// être affiché et l'app active (Apple refuse le prompt sinon).
  static const Duration entryDelay = Duration(milliseconds: 1500);

  /// 606 — une seule boucle d'attente à la fois ; `_answered` = Apple a une
  /// réponse (plus rien à demander). Plusieurs appelants possibles : démarrage,
  /// arrivée sur l'accueil après connexion/inscription, retour au premier plan.
  Future<void>? _pending;
  bool _answered = false;

  /// À appeler une fois au démarrage (après runApp, quand une frame est prête).
  /// Ne présente AUCUNE fenêtre : aligne seulement le SDK sur la réponse ATT
  /// déjà connue, et active le journal automatique des événements.
  Future<void> init() async {
    try {
      if (Platform.isIOS) {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status != TrackingStatus.notDetermined) _answered = true;
        await _applyTracking(status);
      } else {
        // Android : consentement pub actif d'emblée.
        await _applyTracking(TrackingStatus.authorized);
      }
    } catch (e) {
      debugPrint('MetaEventsService.init error: $e');
    }
  }

  /// 606 — aligne Meta (IDFA + journal automatique des événements, dont
  /// `fb_mobile_activate_app`) et Firebase (signaux publicitaires) sur la
  /// réponse ATT. iOS sans « Autoriser » = tout éteint. Le journal auto est
  /// aussi coupé dans Info.plist (`FacebookAutoLogAppEventsEnabled` = NO) pour
  /// qu'aucun événement ne parte au lancement, avant ce code.
  Future<void> _applyTracking(TrackingStatus status) async {
    final allowed =
        adTrackingAllowed(isIOS: Platform.isIOS, status: status);
    try {
      await _fb.setAdvertiserTracking(enabled: allowed, collectId: allowed);
      await _fb.setAutoLogAppEventsEnabled(allowed);
    } catch (e) {
      debugPrint('MetaEventsService._applyTracking error: $e');
    }
    await FirebaseAnalyticsService.instance.applyAdConsent(allowed);
  }

  /// 606 — fenêtre ATT d'Apple (la fenêtre système, telle quelle — Apple
  /// 5.1.2), présentée de façon FIABLE dès la 1re session : dès que
  /// l'utilisateur est dans l'app, juste après la question « notifications »
  /// si elle est posée, et avant tout suivi publicitaire ([_applyTracking]).
  /// À appeler au démarrage ET à l'arrivée sur l'accueil (connexion,
  /// inscription) : les appels concurrents partagent la même attente.
  Future<void> requestTrackingAfterEntry() {
    if (!Platform.isIOS || _answered) return Future<void>.value();
    return _pending ??= _requestWhenReady().whenComplete(() => _pending = null);
  }

  Future<void> _requestWhenReady() async {
    try {
      final answer = await runAttPromptWhenReady(
        hasSession: _hasSession,
        notificationFlowBusy: () =>
            PushNotificationService.notificationFlowBusy,
        appActive: () {
          final life = WidgetsBinding.instance.lifecycleState;
          return life == null || life == AppLifecycleState.resumed;
        },
        readStatus: () => AppTrackingTransparency.trackingAuthorizationStatus,
        request: AppTrackingTransparency.requestTrackingAuthorization,
        initialDelay: entryDelay,
      );
      final status =
          answer ?? await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) _answered = true;
      await _applyTracking(status);
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

  /// Événement de complétion d'inscription — signal fort pour l'algorithme
  /// (Meta cherchera des profils similaires à ceux qui créent un compte).
  Future<void> logCompletedRegistration({String? method}) async {
    try {
      // 606 — jamais d'événement Meta sur iOS sans « Autoriser » à l'ATT.
      if (Platform.isIOS) {
        final status =
            await AppTrackingTransparency.trackingAuthorizationStatus;
        if (!adTrackingAllowed(isIOS: true, status: status)) return;
      }
      await _fb.logCompletedRegistration(registrationMethod: method);
    } catch (e) {
      debugPrint('MetaEventsService.logCompletedRegistration error: $e');
    }
  }
}
