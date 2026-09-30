// v605 (30/09) — Daniel : « j'ai laissé la carte sur ton profil et ça m'est
// revenu sur ma position » ; « ce truc que la position change à chaque
// fois ». Tous les recentrages AUTOMATIQUES sur « Moi » passent par
// `pawMapMayRecenterOnMe` ; après un geste, une fiche ouverte, un ami montré
// ou pendant un suivi, la caméra ne repart jamais seule sur Moi.
//
// Le garde-fou « source » se rejoue sur une autre version du fichier avec
//   PAWMAP_SRC=/chemin/paw_map_screen.dart flutter test test/pawmap605_camera_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/pawmap_camera605.dart';

String _src() {
  final p = Platform.environment['PAWMAP_SRC'] ??
      'lib/views/map/paw_map_screen.dart';
  return File(p).readAsStringSync();
}

/// Corps du `ever(...)` qui écoute MA position GPS pendant ma balade.
String _myFollowWorkerBody(String s) {
  final i = s.indexOf('_myFollowWorker = ever<LatLng?>(');
  expect(i, greaterThan(0));
  final j = s.indexOf('    );', i);
  return s.substring(i, j);
}

String _resumeBody(String s) {
  final i = s.indexOf('if (state == AppLifecycleState.resumed) {');
  expect(i, greaterThan(0));
  return s.substring(i, s.indexOf('_haloTimer == null', i));
}

void main() {
  group('règle pure', () {
    test('ma balade + je regarde le profil d\'un ami : PAS de retour sur Moi', () {
      expect(
          pawMapMayRecenterOnMe(PawAutoRecenter.myLiveGps,
              cameraHeld: true, focusOpen: true, meFollow: false),
          isFalse);
    });
    test('ma balade, mode « me suivre » sans geste : la caméra me suit', () {
      expect(
          pawMapMayRecenterOnMe(PawAutoRecenter.myLiveGps,
              cameraHeld: false, meFollow: true),
          isTrue);
    });
    test('ma balade après un geste (me suivre coupé) : non', () {
      expect(
          pawMapMayRecenterOnMe(PawAutoRecenter.myLiveGps,
              cameraHeld: true, meFollow: false),
          isFalse);
    });
    test('pendant un suivi : jamais, quelle que soit la cause', () {
      for (final c in PawAutoRecenter.values) {
        expect(
            pawMapMayRecenterOnMe(c,
                cameraHeld: false, following: true, meFollow: true),
            isFalse,
            reason: '$c');
      }
    });
    test('retour d\'arrière-plan après un geste : non ; sans geste : oui', () {
      expect(
          pawMapMayRecenterOnMe(PawAutoRecenter.appResume, cameraHeld: true),
          isFalse);
      expect(
          pawMapMayRecenterOnMe(PawAutoRecenter.appResume, cameraHeld: false),
          isTrue);
    });
    test('1er fix GPS avec une fiche ouverte : non', () {
      expect(
          pawMapMayRecenterOnMe(PawAutoRecenter.gpsFirstFix,
              cameraHeld: false, focusOpen: true),
          isFalse);
    });
  });

  group('mémoire de session (écran PawMap recréé)', () {
    final t0 = DateTime(2026, 9, 30, 10);
    test('geste après le recentrage, 11 min plus tard : pas de nouveau vol', () {
      expect(
          pawMapShouldAutoRecenterAgain(
              now: t0.add(const Duration(minutes: 11)),
              lastAutoAt: t0,
              lastAutoKmFromTarget: 0.01,
              lastGestureAt: t0.add(const Duration(minutes: 1))),
          isFalse);
    });
    test('aucun geste, 11 min plus tard : recentrage permis', () {
      expect(
          pawMapShouldAutoRecenterAgain(
              now: t0.add(const Duration(minutes: 11)),
              lastAutoAt: t0,
              lastAutoKmFromTarget: 0.01),
          isTrue);
    });
    test('premier écran : oui ; geste de 2 min sur un écran précédent : non', () {
      expect(pawMapShouldAutoRecenterAgain(now: t0), isTrue);
      expect(
          pawMapShouldAutoRecenterAgain(
              now: t0, lastGestureAt: t0.subtract(const Duration(minutes: 2))),
          isFalse);
    });
  });

  group('garde-fou source (paw_map_screen.dart)', () {
    test('la position GPS de MA balade passe par la règle', () {
      final body = _myFollowWorkerBody(_src());
      expect(body.contains('pawMapMayRecenterOnMe(PawAutoRecenter.myLiveGps'),
          isTrue,
          reason: 'le worker recollait la caméra sur moi à chaque point GPS');
    });
    test('le retour d\'arrière-plan passe par la règle', () {
      expect(_resumeBody(_src()).contains('PawAutoRecenter.appResume'), isTrue);
    });
    test('le 1er fix GPS passe par la règle', () {
      expect(_src().contains('PawAutoRecenter.gpsFirstFix'), isTrue);
    });
    test('ouvrir un profil / une fiche / un ami garde la caméra', () {
      final s = _src();
      for (final sig in <String>[
        'void _focusFirstTap(',
        'Future<void> _focusFriend(',
        'Future<void> _applyIntent(',
        'void _startFollow(',
      ]) {
        final i = s.indexOf(sig);
        expect(i, greaterThan(0), reason: sig);
        final head = s.substring(i, i + 900);
        expect(head.contains('_holdCamera()'), isTrue, reason: sig);
      }
    });
  });

  group('branchements 605 (source)', () {
    test('suivi mutuel : démarrer MA balade pendant un suivi ne vole pas la caméra', () {
      final s = _src();
      final i = s.indexOf('Future<void> _startBroadcastWith(');
      expect(i, greaterThan(0));
      final body = s.substring(i, s.indexOf('/// v565 — feuille « Combien de temps ? »', i));
      expect(body.contains('keepOnFollowed'), isTrue);
      expect(body.contains('if (keepOnFollowed || _followUserId != null) return;'), isTrue);
    });
    test('Balade et pilule Direct passent par _onBaladeTap (feuille unique)', () {
      final s = _src();
      expect(RegExp(r'onTap: \(\) => unawaited\(_onBaladeTap\(\)\)').allMatches(s).length,
          greaterThanOrEqualTo(2));
      expect(s.contains('onTap: () => unawaited(_toggleDirect()),'), isFalse);
    });
    test('« Arrêter » de la pilule de suivi ouvre la feuille unique', () {
      final s = _src();
      final i = s.indexOf('void _openFollowSheet()');
      final body = s.substring(i, s.indexOf('void _endFollowIfGone()', i));
      expect(body.contains('_openLiveSheet()'), isTrue);
    });
    test('un arrêt fait ailleurs (feuille, chat) lâche la caméra ici', () {
      expect(_src().contains('_followSharedWorker = ever<String?>(_liveMap.followingUserId'),
          isTrue);
    });
  });
}
