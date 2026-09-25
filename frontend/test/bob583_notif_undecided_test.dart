// BOB 25/09/2026 — règle « jamais répondu » de la fenêtre des notifications.
// Android ne renvoie jamais `notDetermined` : sans ce drapeau, la fenêtre
// système s'ouvrait dès l'écran visiteur (vu sur l'émulateur Samsung).
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/services/push_notification_service.dart';

void main() {
  test('iOS : seul notDetermined est indécis', () {
    expect(PushNotificationService.isUndecided(AuthorizationStatus.notDetermined, isAndroid: false, askedBefore: false), isTrue);
    expect(PushNotificationService.isUndecided(AuthorizationStatus.denied, isAndroid: false, askedBefore: false), isFalse);
    expect(PushNotificationService.isUndecided(AuthorizationStatus.authorized, isAndroid: false, askedBefore: false), isFalse);
  });

  test('Android : denied + jamais demandé = indécis (pas de fenêtre avant l entrée)', () {
    expect(PushNotificationService.isUndecided(AuthorizationStatus.denied, isAndroid: true, askedBefore: false), isTrue);
    expect(PushNotificationService.isUndecided(AuthorizationStatus.notDetermined, isAndroid: true, askedBefore: false), isTrue);
  });

  test('Android : déjà demandé ou autorisé = décidé', () {
    expect(PushNotificationService.isUndecided(AuthorizationStatus.denied, isAndroid: true, askedBefore: true), isFalse);
    expect(PushNotificationService.isUndecided(AuthorizationStatus.authorized, isAndroid: true, askedBefore: false), isFalse);
    expect(PushNotificationService.isUndecided(AuthorizationStatus.provisional, isAndroid: true, askedBefore: false), isFalse);
  });
}
