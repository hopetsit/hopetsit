// 612 (PAM, 05/10/2026) — balade suivie en direct : zoom, éventail, tracé,
// GPS, glissement. Retours de Daniel du 05/10 (captures 1-12, vidéo 21 h 18).
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/views/map/widgets/pawmap_follow612.dart';
import 'package:hopetsit/views/map/widgets/pawmap_overlap607.dart';

const double _m = 1 / 111320; // ~1 m en latitude
LatLng _at(double north, double east) =>
    LatLng(37.85 + north * _m, -1.425 + east * _m / 0.7902);

void main() {
  group('A · viser / suivre ne fait JAMAIS dézoomer', () {
    // Règles d'avant (lues dans le code 611) : suivre = 16,5 en dur, 1er
    // appui = min(max(z + 1,5 ; 15) ; 18), ami de la liste = 16.
    double old611Follow(double z) => 16.5;
    double old611Tap(double z) => (z + 1.5).clamp(15.0, 18.0);

    test('AVANT (611) : au zoom 18,5 de Daniel, suivre et viser dézoomaient', () {
      expect(old611Follow(18.5), lessThan(18.5));
      expect(old611Tap(18.5), lessThan(18.5));
      // et la séquence réelle : 1er appui → 18 puis « Suivre » → 16,5
      expect(old611Follow(old611Tap(17)), lessThan(old611Tap(17)));
    });

    for (final z in <double>[3, 10, 14, 16, 16.9, 17, 17.5, 18, 18.5, 19.5, 20, 21]) {
      test('zoom $z → suivre ≥ $z (et zoom rue au minimum)', () {
        final f = pawFollowZoom(z);
        expect(f, greaterThanOrEqualTo(z > kPawFollowMaxZoom ? kPawFollowMaxZoom : z));
        expect(f, greaterThanOrEqualTo(16.9));
        expect(pawTapZoom(z), greaterThanOrEqualTo(z));
      });
    }

    test('recentrer = même zoom quand on est déjà au niveau de la rue', () {
      expect(pawFollowZoom(18.3), 18.3);
      expect(pawFollowZoom(17.5), 17.5);
      expect(pawFollowZoom(12), kPawFollowStreetZoom);
    });

    test('source : plus aucun zoom de suivi en dur dans la carte', () {
      final src = File('lib/views/map/paw_map_screen.dart').readAsStringSync();
      expect(src.contains('zoom: _followZoom)'), isFalse);
      expect(src.contains('math.min(math.max(_zoomLevel + 1.5, 15.0), 18.0)'), isFalse);
      expect(src.contains('zoom: kPawMapFriendFocusZoom);'), isFalse);
    });
  });

  group('C/D · personne suivie jamais décalée, écart court, aucun trait', () {
    final meBox = pawPinBox(30, labelW: 40, labelH: 16.3, labelGap: 3);
    final friendBox = pawPinBox(27.5);

    test('Moi et la personne suivie au même endroit : elle reste, Moi s\'écarte', () {
      final r = pawFan612(
        meAt: const Offset(200, 400),
        meBox: meBox,
        friendsAt: const [Offset(205, 404)],
        friendBox: friendBox,
        followed: const {0},
      );
      expect(r.friends[0], Offset.zero);
      expect(r.me, isNot(Offset.zero));
      expect(r.me.distance, lessThanOrEqualTo(90));
      // plus de chevauchement
      final meRect = meBox.shift(const Offset(200, 400) + r.me);
      final frRect = friendBox.shift(const Offset(205, 404));
      expect(meRect.overlaps(frRect), isFalse);
    });

    test('un AUTRE ami collé à Moi s\'écarte ; le suivi et Moi ne bougent pas', () {
      final r = pawFan612(
        meAt: const Offset(200, 400),
        meBox: meBox,
        friendsAt: const [Offset(400, 400), Offset(203, 401)],
        friendBox: friendBox,
        followed: const {0},
      );
      expect(r.friends[0], Offset.zero);
      expect(r.me, Offset.zero);
      expect(r.friends[1], isNot(Offset.zero));
      expect(r.friends[1].distance, lessThanOrEqualTo(90));
    });

    test('décalage par l\'ANCRE : la position reste la vraie', () {
      final a = pawShiftedAnchor612(const Offset(0.5, 0.4), const Offset(40, -20),
          width: 100, height: 120);
      expect(a.dx, closeTo(0.1, 1e-9));
      expect(a.dy, closeTo(0.4 + 20 / 120, 1e-9));
      expect(pawShiftedAnchor612(const Offset(0.5, 0.4), Offset.zero, width: 100, height: 120),
          const Offset(0.5, 0.4));
    });

    test('carte tournée de 90° (cap est) : un point à l\'est est AU-DESSUS', () {
      final d = pawScreenDelta(const Offset(50, 0), bearingDeg: 90);
      expect(d.dx, closeTo(0, 1e-6));
      expect(d.dy, closeTo(-50, 1e-6));
    });

    test('carte penchée de 55° : l\'écart vertical est réduit (vue rue)', () {
      final d = pawScreenDelta(const Offset(0, 100), tiltDeg: 55);
      expect(d.dy, closeTo(57.36, 0.05));
    });

    test('source : plus de trait rose, de cercle en mètres ni de trait violet', () {
      final src = File('lib/views/map/paw_map_screen.dart').readAsStringSync();
      for (final gone in [
        "PolylineId('fan607_",
        "CircleId('user_halo_outer')",
        "CircleId('live_halo_",
        "CircleId('follow_track_",
        "CircleId('walk_start_",
        "PolylineId('follow_trail')",
        "PolylineId('walk_halo_",
        '..._fanLines607',
      ]) {
        expect(src.contains(gone), isFalse, reason: gone);
      }
      expect(src.contains('Set<Circle> _buildHaloCircles() => const <Circle>{};'), isTrue);
    });

    test('peluche à moins de 60 px de la photo suivie : retirée', () {
      expect(pawPlushHiddenNearFollowed612(const Offset(10, 10), Offset.zero), isTrue);
      expect(pawPlushHiddenNearFollowed612(const Offset(80, 0), Offset.zero), isFalse);
    });
  });

  group('F · tracé propre (capture 5 : étoile au Mercadona)', () {
    test('les allers-retours en étoile sont retirés, la marche reste', () {
      final raw = <LatLng>[
        _at(0, 0), _at(12, 0), _at(70, 45), _at(24, 0), _at(-40, 50),
        _at(36, 0), _at(90, -60), _at(48, 0), _at(60, 0),
      ];
      final clean = pawCleanTrail612(raw, smoothPasses: 0);
      expect(clean.length, 6);
      for (final p in clean) {
        expect(pawMeters612(LatLng(p.latitude, -1.425), p), lessThan(5));
      }
    });

    test('lissage : extrémités gardées, plus de points, aucun écart de > 10 m', () {
      final raw = [for (var i = 0; i < 10; i++) _at(i * 10.0, (i % 2) * 6.0)];
      final s = pawCleanTrail612(raw);
      expect(s.first, raw.first);
      expect(s.last, raw.last);
      expect(s.length, greaterThan(raw.length));
      for (final p in s) {
        final near = raw.map((q) => pawMeters612(p, q)).reduce((a, b) => a < b ? a : b);
        expect(near, lessThan(10));
      }
    });
  });

  group('F · point GPS de ma balade', () {
    final t0 = DateTime(2026, 10, 5, 21, 0, 0);
    test('imprécis (> 40 m) juste après un bon point : refusé', () {
      expect(pawAcceptGpsFix612(accuracyM: 65, fix: _at(5, 0), lastGood: _at(0, 0),
          lastGoodAt: t0, now: t0.add(const Duration(seconds: 3))), isFalse);
    });
    test('saut de 120 m en 3 s : refusé ; marche à 1,5 m/s : acceptée', () {
      expect(pawAcceptGpsFix612(accuracyM: 10, fix: _at(120, 0), lastGood: _at(0, 0),
          lastGoodAt: t0, now: t0.add(const Duration(seconds: 3))), isFalse);
      expect(pawAcceptGpsFix612(accuracyM: 10, fix: _at(6, 0), lastGood: _at(0, 0),
          lastGoodAt: t0, now: t0.add(const Duration(seconds: 4))), isTrue);
    });
    test('après 25 s sans bon point : on reprend (jamais figé)', () {
      expect(pawAcceptGpsFix612(accuracyM: 80, fix: _at(200, 0), lastGood: _at(0, 0),
          lastGoodAt: t0, now: t0.add(const Duration(seconds: 26))), isTrue);
    });
    test('premier point : toujours accepté', () {
      expect(pawAcceptGpsFix612(accuracyM: 80, fix: _at(0, 0), now: t0), isTrue);
    });
  });

  group('3 · la photo glisse', () {
    test('glissement adouci : départ, arrivée, monotone', () {
      final a = _at(0, 0), b = _at(30, 0);
      expect(pawGlide612(a, b, 0), a);
      expect(pawGlide612(a, b, 1), b);
      var prev = -1.0;
      for (var i = 0; i <= 20; i++) {
        final p = pawGlide612(a, b, i / 20);
        expect(p.latitude, greaterThanOrEqualTo(prev));
        prev = p.latitude;
      }
    });
  });

  group('§7 · courte traîne derrière la photo', () {
    test('garde les 200 derniers mètres, finit au dernier point', () {
      final pts = [for (var i = 0; i <= 60; i++) _at(i * 10.0, 0)]; // 600 m
      final t = pawShortTrail612(pts);
      expect(t.last, pts.last);
      var len = 0.0;
      for (var i = 1; i < t.length; i++) {
        len += pawMeters612(t[i - 1], t[i]);
      }
      expect(len, closeTo(200, 1.5));
    });
    test('balade plus courte que 200 m : tout le chemin', () {
      final pts = [for (var i = 0; i <= 5; i++) _at(i * 10.0, 0)];
      expect(pawShortTrail612(pts), pts);
    });
    test('fondu : 5 morceaux, opacité croissante 0,12 → 1, sans trou', () {
      final pts = [for (var i = 0; i <= 20; i++) _at(i * 10.0, 0)];
      final f = pawFadedTrail612(pts);
      expect(f.length, 5);
      expect(f.first.$2, closeTo(0.12, 1e-9));
      expect(f.last.$2, 1);
      for (var k = 1; k < f.length; k++) {
        expect(f[k].$2, greaterThan(f[k - 1].$2));
        expect(f[k].$1.first, f[k - 1].$1.last);
      }
      expect(f.last.$1.last, pts.last);
    });
    test('source : plus de tracé complet pendant le direct', () {
      final src = File('lib/views/map/paw_map_screen.dart').readAsStringSync();
      expect(src.contains('pawFadedTrail612(pawShortTrail612('), isTrue);
    });
    test('aide : plus d\'« anneau violet qui respire » (9 langues)', () {
      final src = File('lib/localization/v565/balade599_i18n.dart').readAsStringSync();
      for (final gone in ['anneau violet', 'breathing purple ring', 'anillo morado',
          'violetten Ring', 'anello viola', 'anel roxo', 'obwódk', '紫のリング', '보라색 링']) {
        expect(src.contains(gone), isFalse, reason: gone);
      }
    });
  });

  test('centrage : la caméra recolle à la personne suivie après une attente', () {
    final src = File('lib/views/map/paw_map_screen.dart').readAsStringSync();
    // attente relue à chaque pas du glissement (plus figée au départ)
    expect(src.contains('moveCamera && !_followPaused && !_followCameraHeld()'), isFalse);
    // recollage programmé après + / − et après une carte glissée puis lâchée
    expect('_armRecenter612('.allMatches(src).length, greaterThanOrEqualTo(3));
    // la cible est la position glissée (celle de la photo)
    expect(src.contains('_animateFollowCamera(_glidePos612 ??'), isTrue);
  });
}
