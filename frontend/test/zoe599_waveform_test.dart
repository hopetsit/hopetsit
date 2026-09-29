// v599 (ZOE, 29/09/2026) — ondes sonores des vocaux : rééchantillonnage de la
// forme d'onde captée à l'enregistrement, motif de secours pour les anciens
// vocaux, conversion dBFS → 0..1. Sans widget ni réseau.
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/chat_shared/voice_player.dart';
import 'package:hopetsit/views/chat_shared/voice_recorder.dart';

void main() {
  group('resampleWaveform', () {
    test('ramène 120 échantillons à 40 barres, toutes entre 0.08 et 1', () {
      final src = List<double>.generate(120, (i) => (i % 10) / 10);
      final out = resampleWaveform(src, kVoiceBars);
      expect(out.length, kVoiceBars);
      for (final v in out) {
        expect(v, greaterThanOrEqualTo(0.08));
        expect(v, lessThanOrEqualTo(1.0));
      }
    });
    test('étire 5 échantillons à 40 barres (interpolation) et normalise le pic à 1', () {
      final out = resampleWaveform([0.1, 0.5, 0.2, 0.5, 0.1], 40);
      expect(out.length, 40);
      expect(out.reduce((a, b) => a > b ? a : b), closeTo(1.0, 1e-9));
    });
    test('source vide → barres minimales (jamais une ligne invisible)', () {
      final out = resampleWaveform(const [], 10);
      expect(out, List<double>.filled(10, 0.08));
    });
    test('un silence total reste visible et n\'est pas amplifié', () {
      final out = resampleWaveform(List<double>.filled(50, 0.0), 40);
      expect(out.every((v) => v == 0.08), isTrue);
    });
  });

  group('fallbackWaveform (anciens vocaux sans onde)', () {
    test('déterministe pour une même URL, différent pour une autre', () {
      final a = fallbackWaveform('https://x/a.mp4', 40);
      final b = fallbackWaveform('https://x/a.mp4', 40);
      final c = fallbackWaveform('https://x/b.mp4', 40);
      expect(a, b);
      expect(a, isNot(c));
      expect(a.length, 40);
    });
    test('jamais une ligne droite : au moins 8 valeurs distinctes', () {
      final a = fallbackWaveform('seed', 40);
      expect(a.toSet().length, greaterThanOrEqualTo(8));
      for (final v in a) {
        expect(v, greaterThanOrEqualTo(0.12));
        expect(v, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('amplitudeFromDb', () {
    test('silence −60 dBFS → 0, saturation 0 dBFS → 1, −30 → 0,5', () {
      expect(amplitudeFromDb(-60), 0);
      expect(amplitudeFromDb(0), 1);
      expect(amplitudeFromDb(-30), closeTo(0.5, 1e-9));
    });
    test('valeurs hors bornes et NaN sont bornées', () {
      expect(amplitudeFromDb(-160), 0);
      expect(amplitudeFromDb(20), 1);
      expect(amplitudeFromDb(double.nan), 0);
      expect(amplitudeFromDb(double.negativeInfinity), 0);
    });
  });
}
