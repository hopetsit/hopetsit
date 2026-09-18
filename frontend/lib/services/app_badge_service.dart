import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// v566 — badge chiffré sur l'icône de l'app (iOS uniquement).
///
/// Canal natif `hopetsit/badge` (ios/Runner/AppDelegate.swift, méthode
/// `setBadge(int)`). Le serveur pose `aps.badge` sur chaque push envoyé à une
/// app iOS de build ≥ 566 ; l'app, elle, remet le badge au nombre réel de
/// notifications non lues à chaque changement du compteur, au retour au premier
/// plan, après « tout lire » (0) et à la déconnexion (0).
///
/// No-op sur Android et sur le web. Ne lève jamais.
class AppBadgeService {
  AppBadgeService._();

  static const MethodChannel _channel = MethodChannel('hopetsit/badge');
  static int? _last;

  static Future<void> set(int count, {bool force = false}) async {
    if (kIsWeb || !Platform.isIOS) return;
    final n = count < 0 ? 0 : count;
    if (!force && _last == n) return;
    _last = n;
    try {
      await _channel.invokeMethod<void>('setBadge', n);
    } catch (e) {
      // MissingPluginException (ancien binaire) ou autre : le badge n'est jamais bloquant.
      _last = null;
      debugPrint('AppBadgeService.set failed: $e');
    }
  }

  static Future<void> clear() => set(0, force: true);
}
