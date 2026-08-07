import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// v532 — Service Firebase Analytics (canal Google Ads).
///
/// Pourquoi : Google Ads ne recevait QUE l'événement « installation » fourni
/// par le Play Store. Il optimisait donc sur le volume d'installs, sans savoir
/// distinguer un vrai utilisateur d'un clic accidentel (Réseau Display / jeux).
/// Résultat mesuré sur la campagne Paris : 263 installs pour 2 inscriptions.
///
/// Firebase Analytics est le SEUL canal par lequel Google Ads peut recevoir les
/// événements in-app. Une fois Firebase lié au compte Google Ads, l'événement
/// `sign_up` devient une action de conversion sélectionnable dans les enchères
/// (« Actions dans l'application ») — l'algorithme cherche alors des profils qui
/// créent réellement un compte, pas seulement qui installent.
///
/// Pendant Meta : [MetaEventsService] reste en place et envoie le même signal
/// côté Facebook. Les deux SDK sont indépendants et complémentaires.
///
/// Tout est non bloquant et non fatal : une erreur du SDK ne doit jamais
/// empêcher l'app de démarrer ou casser un parcours d'inscription.
class FirebaseAnalyticsService {
  FirebaseAnalyticsService._();
  static final FirebaseAnalyticsService instance = FirebaseAnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// À appeler une fois au démarrage, après l'initialisation de Firebase.
  Future<void> init() async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(true);
    } catch (e) {
      debugPrint('FirebaseAnalyticsService.init error: $e');
    }
  }

  /// Événement standard `sign_up` — c'est CELUI que Google Ads utilisera comme
  /// objectif d'optimisation. [method] = 'google' | 'apple' | 'email'.
  Future<void> logSignUp({required String method}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
    } catch (e) {
      debugPrint('FirebaseAnalyticsService.logSignUp error: $e');
    }
  }

  /// Événement `login` — utile pour distinguer les utilisateurs qui reviennent
  /// (signal de rétention) des simples installs.
  Future<void> logLogin({required String method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('FirebaseAnalyticsService.logLogin error: $e');
    }
  }
}
