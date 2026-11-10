// 640 (PAM) — coupe-circuit de fluidité `kPawSmooth640` (PAWMAP_SMOOTH).
// Vrai (défaut) : halo PawBoost FIXE sur la photo d'un ami, onde PawFollow
// animée pour 3 pastilles au plus. Faux : comportement d'avant.
//   flutter test test/pawmap640_smooth_test.dart
//   flutter test test/pawmap640_smooth_test.dart --dart-define=PAWMAP_SMOOTH=false
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';

Future<List<int>> _friendBoosted(int running) async {
  final double m = PawMapPinPainter.photoMarginGlow;
  final double s = PawMapPinPainter.photoBitmapSize(kPawFriendSize640, margin: m);
  final int phase = pawBoostPhase640(
      fixed: kPawFriendBoostFixed640, reduceMotion: false, running: running);
  return renderPinPng(
      s,
      s,
      (c) => PawMapPinPainter.paintPhotoDot(c,
          avatar: null,
          ringColor: PawMapLegend.friend,
          size: kPawFriendSize640,
          crownSize: kPawFriendCrown640,
          boostPhase: phase / kBoostPhases,
          margin: m,
          fallbackTint: PawMapLegend.friend),
      scale: 2);
}

void main() {
  test('640 — le coupe-circuit suit PAWMAP_SMOOTH (défaut : vrai)', () {
    expect(kPawSmooth640,
        const bool.fromEnvironment('PAWMAP_SMOOTH', defaultValue: true));
    expect(kPawFriendBoostFixed640, kPawSmooth640 && kPawFriendPhoto640);
  });

  test('640 — halo PawBoost d\'un ami en photo : fixe à son plein, ou respire',
      () async {
    // Ami : image FIXE (1 = halo plein) quand le coupe-circuit est vrai.
    for (var running = 0; running < kBoostPhases; running++) {
      expect(
          pawBoostPhase640(fixed: true, reduceMotion: false, running: running),
          kPawFriendBoostPhase640);
      // « Moi » et les autres ronds photo : inchangés (respiration).
      expect(
          pawBoostPhase640(fixed: false, reduceMotion: false, running: running),
          running);
      expect(pawBoostPhase640(fixed: false, reduceMotion: true, running: running), 0);
    }
    expect(kPawFriendBoostPhase640, 1);
    // Les IMAGES : identiques d'un battement à l'autre si fixe, sinon non.
    final a = await _friendBoosted(0);
    final b = await _friendBoosted(1);
    final c = await _friendBoosted(3);
    final bool same = _eq(a, b) && _eq(b, c);
    expect(same, kPawFriendBoostFixed640);
  });

  test('640 — onde PawFollow : animée jusqu\'à 3 pastilles, fixe au-delà', () {
    expect(kPawWaveMax640, 3);
    for (var k = 0; k <= 3; k++) {
      expect(pawWaveAnimated640(k), isTrue);
    }
    for (final k in const [4, 5, 20, 200]) {
      expect(pawWaveAnimated640(k), !kPawSmooth640);
    }
  });

  test('640 — l\'écran est branché sur le coupe-circuit (lecture du code)', () {
    final src = File('lib/views/map/paw_map_screen.dart').readAsStringSync();
    // Ami de profil et ami en direct : halo fixe, et plus de battement à 600 ms.
    expect('boostFixed: kPawFriendBoostFixed640'.allMatches(src).length, 2);
    expect(src, contains('if (boosted && !v2 && !(isFriend && kPawFriendBoostFixed640))'));
    expect(src, contains('if (liveBoosted && !kPawFriendBoostFixed640) _anyBoosted = true;'));
    // « Moi » boosté continue de respirer (inchangé).
    expect(src, contains('if (myBoost) _anyBoosted = true;'));
    // Onde : comptée à chaque passe, décidée par pawWaveAnimated640.
    expect(src, contains('if (wantWave) _waveWanted640++;'));
    expect(src, contains('final bool wave = wantWave && _waveOk640;'));
    expect(src, contains('_waveOk640 != pawWaveAnimated640(_waveWanted640)'));
    expect(src, contains('_applyLayout607(_buildMarkers640())'));
    // Les battements restent sautés pendant que la carte bouge.
    expect(RegExp(r'if \(!mounted \|\| _cameraMoving\) return;').hasMatch(src), isTrue);
  });
}

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

