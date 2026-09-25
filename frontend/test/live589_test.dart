// v589 (26/09/2026) — le direct suit la personne, pas le téléphone.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/services/live_tracking_bg.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 26, 10, 0);

  group('liveStateDecision', () {
    test('je diffuse, arrêté APRÈS mon démarrage sur un autre téléphone : je coupe', () {
      final d = liveStateDecision({
        'active': false, 'stopped': true,
        'stoppedAt': t0.add(const Duration(minutes: 5)).toIso8601String(),
      }, broadcasting: true, localStartedAt: t0);
      expect(d.stopLocal, isTrue);
      expect(d.elsewhere, isFalse);
    });

    test('arrêt ANCIEN (avant que je relance ici) : je garde mon direct', () {
      final d = liveStateDecision({
        'active': false, 'stopped': true,
        'stoppedAt': t0.subtract(const Duration(hours: 3)).toIso8601String(),
      }, broadcasting: true, localStartedAt: t0);
      expect(d.stopLocal, isFalse);
    });

    test('serveur sans session (redémarré) et sans arrêt voulu : jamais coupé', () {
      final d = liveStateDecision({'active': false, 'stopped': false},
          broadcasting: true, localStartedAt: t0);
      expect(d.stopLocal, isFalse);
    });

    test('je ne diffuse pas, direct actif ailleurs : pilule « autre téléphone »', () {
      final d = liveStateDecision({'active': true, 'stopped': false},
          broadcasting: false);
      expect(d.elsewhere, isTrue);
      expect(d.stopLocal, isFalse);
    });

    test('je ne diffuse pas, rien ailleurs : pilule normale', () {
      final d = liveStateDecision({'active': false, 'stopped': true},
          broadcasting: false);
      expect(d.elsewhere, isFalse);
    });
  });

  group('service de fond Android', () {
    test('réponse « arrêté ailleurs » reconnue', () {
      expect(bgStoppedElsewhere('{"ok":true,"ignored":true,"stopped":true}'), isTrue);
    });
    test('réponses normales : on continue', () {
      expect(bgStoppedElsewhere('{"ok":true,"listeners":2}'), isFalse);
      expect(bgStoppedElsewhere('pas du json'), isFalse);
      expect(bgStoppedElsewhere('{"ok":true,"stopped":true}'), isFalse);
    });
  });

  group('pilule Direct', () {
    setUp(() {
      Get.addTranslations({
        'fr': {
          'live589_pill_elsewhere': 'En direct · autre téléphone',
          'pawmap587_direct_off': 'Direct',
          'pawmap587_direct_on_now': 'En direct',
        },
      });
      Get.locale = const Locale('fr');
    });
    test('autre téléphone', () {
      expect(pawDirectPillLabel(live: false, startedAt: null, now: t0, elsewhere: true),
          'En direct · autre téléphone');
    });
    test('ce téléphone diffuse : son propre libellé prime', () {
      expect(pawDirectPillLabel(live: true, startedAt: t0, now: t0, elsewhere: true),
          'En direct');
    });
    test('éteint partout', () {
      expect(pawDirectPillLabel(live: false, startedAt: null, now: t0), 'Direct');
    });
  });
}
