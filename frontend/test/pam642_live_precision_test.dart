// 642 (PAM) — trois petits défauts de la position en direct relevés par ZOE
// au contrôle du 641 :
//   (a) la porte GPS acceptait un point « précis » mais ABERRANT (saut
//       impossible) quand le dernier point gardé était imprécis ;
//   (b) le service de fond Android avançait l'heure du « dernier envoi » même
//       quand l'envoi avait échoué ;
//   (c) une précision NaN, infinie ou négative n'était pas traitée.
// Positions en zone fictive (−35 / −30).
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/services/live_tracking_bg.dart';
import 'package:hopetsit/views/map/widgets/pawmap_follow612.dart';

LatLng _at(double east, double north) =>
    LatLng(-35 + north / 111320.0, -30 + east / 91200.0);

void main() {
  final t0 = DateTime(2026, 11, 11, 9, 0, 0);
  DateTime at(double seconds) =>
      t0.add(Duration(milliseconds: (seconds * 1000).round()));

  group('642 (a) · point précis mais aberrant après un point imprécis', () {
    test('cache à 150 m près, puis point « précis » à 5 km, 2 s après : refusé',
        () {
      final g = PawGpsGate641();
      g.seed(null, at(0));
      expect(g.offer(_at(0, 0), 150, at(0.4)), isTrue); // 1er point du flux
      expect(g.offer(_at(5000, 0), 8, at(2.4)), isFalse,
          reason: '5 km en 2 s : ce point n\'est pas le bon, même « précis »');
      expect(g.last, _at(0, 0));
      // le vrai point GPS, dans le cercle d'erreur du 1er : pris
      expect(g.offer(_at(120, 0), 7, at(3.4)), isTrue);
      expect(g.last, _at(120, 0));
    });
    test('la marge suit la précision du dernier point (2 × + marche)', () {
      // dernier point à 150 m près, 2 s : portée = 300 + 8 + 18 = 326 m
      bool ok(double east) => pawAcceptGpsFix612(
          accuracyM: 8,
          fix: _at(east, 0),
          lastGood: _at(0, 0),
          lastGoodAt: at(0),
          lastGoodAccuracyM: 150,
          now: at(2),
          lastGoodFromGps: true);
      expect(ok(90), isTrue);
      expect(ok(320), isTrue);
      expect(ok(340), isFalse);
      expect(ok(2000), isFalse);
    });
    test('un point « moins imprécis » mais aberrant est refusé aussi', () {
      expect(
          pawAcceptGpsFix612(
              accuracyM: 60,
              fix: _at(3000, 0),
              lastGood: _at(0, 0),
              lastGoodAt: at(0),
              lastGoodAccuracyM: 150,
              now: at(2),
              lastGoodFromGps: true),
          isFalse);
    });
    test('position de départ venue de l\'ÉCRAN : aucun contrôle de saut', () {
      // Elle peut dater : le 1er vrai point GPS est pris à n'importe quelle
      // distance (sinon on retombe dans le défaut du 641 : 25 s sur la
      // mauvaise position).
      final g = PawGpsGate641();
      g.seed(_at(0, 0), at(0));
      expect(g.fromGps, isFalse);
      expect(g.offer(_at(4000, 0), 6, at(1)), isTrue);
      expect(g.fromGps, isTrue);
    });
    test('sans le drapeau (anciens appelants) : règles 641 inchangées', () {
      expect(
          pawAcceptGpsFix612(
              accuracyM: 8,
              fix: _at(5000, 0),
              lastGood: _at(0, 0),
              lastGoodAt: at(0),
              lastGoodAccuracyM: 150,
              now: at(2)),
          isTrue);
    });
    test('jamais figé : après 25 s on reprend ce qui vient', () {
      final g = PawGpsGate641();
      g.seed(null, at(0));
      expect(g.offer(_at(0, 0), 150, at(0)), isTrue);
      expect(g.offer(_at(5000, 0), 8, at(2)), isFalse);
      expect(g.offer(_at(5000, 0), 8, at(26)), isTrue);
    });
    test('dernier point de précision INCONNUE : pas de borne (rien à mesurer)',
        () {
      final g = PawGpsGate641();
      g.seed(null, at(0));
      expect(g.offer(_at(0, 0), double.nan, at(0)), isTrue); // tout 1er point
      expect(g.accuracyM, double.infinity);
      expect(g.offer(_at(900, 0), 9, at(2)), isTrue);
    });
    test('arrêt / nouveau départ : le drapeau repart de zéro', () {
      final g = PawGpsGate641();
      g.seed(null, at(0));
      g.offer(_at(0, 0), 10, at(0));
      expect(g.fromGps, isTrue);
      g.reset();
      expect(g.fromGps, isFalse);
      g.offer(_at(0, 0), 10, at(1));
      g.seed(_at(0, 0), at(2));
      expect(g.fromGps, isFalse);
    });
  });

  group('642 (c) · précision NaN, infinie ou négative = imprécis', () {
    test('pawAccuracyKnown642', () {
      expect(pawAccuracyKnown642(0), isTrue);
      expect(pawAccuracyKnown642(12.5), isTrue);
      expect(pawAccuracyKnown642(double.nan), isFalse);
      expect(pawAccuracyKnown642(double.infinity), isFalse);
      expect(pawAccuracyKnown642(double.negativeInfinity), isFalse);
      expect(pawAccuracyKnown642(-1), isFalse);
    });
    for (final bad in <double>[double.nan, double.infinity, double.negativeInfinity, -5]) {
      test('$bad juste après un BON point : refusé (avant : NaN et −5 passaient)',
          () {
        expect(
            pawAcceptGpsFix612(
                accuracyM: bad,
                fix: _at(4, 0),
                lastGood: _at(0, 0),
                lastGoodAt: at(0),
                lastGoodAccuracyM: 9,
                now: at(3)),
            isFalse);
      });
      test('$bad après un point IMPRÉCIS : refusé', () {
        expect(
            pawAcceptGpsFix612(
                accuracyM: bad,
                fix: _at(4, 0),
                lastGood: _at(0, 0),
                lastGoodAt: at(0),
                lastGoodAccuracyM: 150,
                now: at(3)),
            isFalse);
      });
      test('$bad : tout premier point pris, mais noté « douteux »', () {
        final g = PawGpsGate641();
        g.seed(null, at(0));
        expect(g.offer(_at(0, 0), bad, at(0)), isTrue);
        expect(g.accuracyM, double.infinity);
        // un vrai point le remplace tout de suite
        expect(g.offer(_at(50, 0), 8, at(1)), isTrue);
        expect(g.accuracyM, 8);
      });
      test('$bad après 25 s : repris (jamais figé), noté « douteux »', () {
        final g = PawGpsGate641();
        g.seed(_at(0, 0), at(0));
        expect(g.offer(_at(3, 0), 8, at(1)), isTrue);
        expect(g.offer(_at(9, 0), bad, at(27)), isTrue);
        expect(g.accuracyM, double.infinity);
      });
      test('service de fond : $bad = battement seul', () {
        expect(
            bgFixUsable641(
                accuracyM: bad, fixAt: at(9), now: at(10), lastSentAt: at(0)),
            isFalse);
      });
    }
    test('dernier point gardé de précision négative / NaN : traité imprécis',
        () {
      for (final bad in <double>[-3, double.nan]) {
        // un point précis le remplace à 90 m en 2 s (pas de « saut » mesuré)
        expect(
            pawAcceptGpsFix612(
                accuracyM: 8,
                fix: _at(90, 0),
                lastGood: _at(0, 0),
                lastGoodAt: at(0),
                lastGoodAccuracyM: bad,
                now: at(2)),
            isTrue);
      }
    });
  });

  group('642 · service de fond : règle 641 gardée pour l\'heure du dernier envoi',
      () {
    // Le changement (b) essayé (n'avancer l'heure que sur un envoi reçu) a été
    // RETIRÉ après le contrôle de ZOE : sur une série d'erreurs serveur il
    // faisait partir plus de points imprécis (39 envois contre 20 en 10 min).
    test('un point imprécis juste après une tentative : battement seul', () {
      // la tentative de t=15 (même échouée) compte : à t=30 le point imprécis
      // ne part pas, il attend t=45.
      expect(
          bgFixUsable641(
              accuracyM: 180, fixAt: at(30), now: at(30), lastSentAt: at(15)),
          isFalse);
      expect(
          bgFixUsable641(
              accuracyM: 180, fixAt: at(45), now: at(45), lastSentAt: at(15)),
          isTrue);
    });
  });

  // ── Contrôle de ZOE : le blocage de 25 s ne doit pas revenir ─────────────
  group('642 (a) · suites rejouées, un point par seconde : temps avant la bonne position',
      () {
    // [first] = 1er point du flux (t = 0) ; ensuite le VRAI point GPS, précis
    // (8 m), une fois par seconde en [truth]. Rend la seconde où la porte
    // garde un point à moins de 15 m de la vérité, et le nombre de refus.
    ({double seconds, int refused}) run(
        {required LatLng first, required double firstAcc, required LatLng truth}) {
      final g = PawGpsGate641();
      g.seed(null, at(0));
      expect(g.offer(first, firstAcc, at(0)), isTrue);
      var refused = 0;
      for (var t = 1; t <= 40; t++) {
        final ok = g.offer(truth, 8, at(t.toDouble()));
        if (!ok) refused++;
        if (ok && pawMeters612(g.last!, truth) < 15) {
          return (seconds: t.toDouble(), refused: refused);
        }
      }
      return (seconds: double.infinity, refused: refused);
    }

    void check(String name, ({double seconds, int refused}) r, double max) {
      // ignore: avoid_print
      print('642 porte GPS · $name : bonne position à ${r.seconds} s '
          '(${r.refused} point(s) précis refusé(s))');
      expect(r.seconds <= max, isTrue, reason: '$name : ${r.seconds} s');
    }

    test('cache annoncé à 65 m, vrai GPS à 5 km : ≤ 2 s (avant : 25,5 s)', () {
      check('cache 65 m → 5 km',
          run(first: _at(0, 0), firstAcc: 65, truth: _at(5000, 0)), 2);
    });
    test('cache annoncé à 150 m, vrai GPS à 5 km : ≤ 2 s', () {
      check('cache 150 m → 5 km',
          run(first: _at(0, 0), firstAcc: 150, truth: _at(5000, 0)), 2);
    });
    test('cache annoncé à 150 m, vrai GPS à 600 m : ≤ 2 s', () {
      check('cache 150 m → 600 m',
          run(first: _at(0, 0), firstAcc: 150, truth: _at(600, 0)), 2);
    });
    test('sortie de tunnel : 1er point annoncé à 80 m mais faux de 900 m : ≤ 2 s',
        () {
      check('tunnel 80 m annoncés, faux de 900 m',
          run(first: _at(0, 0), firstAcc: 80, truth: _at(0, 900)), 2);
    });
    test('imprécis puis précis à 80 m : pris tout de suite (1 s, 0 refus)', () {
      final r = run(first: _at(0, 0), firstAcc: 150, truth: _at(80, 0));
      check('imprécis → 80 m', r, 1);
      expect(r.refused, 0);
    });
    test('marche réelle pendant la bascule (1,5 m/s) : ≤ 2 s', () {
      final g = PawGpsGate641();
      g.seed(null, at(0));
      expect(g.offer(_at(0, 0), 150, at(0)), isTrue);
      expect(g.offer(_at(5000, 0), 8, at(1)), isFalse);
      expect(g.offer(_at(5001.5, 0), 8, at(2)), isTrue);
      expect(g.accuracyM, 8);
    });
    test('UN seul point aberrant isolé, puis retour : jamais affiché', () {
      final g = PawGpsGate641();
      g.seed(null, at(0));
      expect(g.offer(_at(0, 0), 150, at(0)), isTrue); // imprécis
      expect(g.offer(_at(5000, 0), 8, at(1)), isFalse); // aberrant, isolé
      expect(g.last, _at(0, 0));
      expect(g.offer(_at(60, 0), 8, at(2)), isTrue); // le vrai point
      expect(g.last, _at(60, 0));
      expect(g.pending, isNull);
      // ensuite, les règles 612 après un BON point : un saut reste refusé…
      expect(g.offer(_at(5000, 0), 8, at(3)), isFalse);
      // … même répété (le dernier point gardé est précis : pas de bascule)
      expect(g.offer(_at(5000, 0), 8, at(4)), isFalse);
      expect(g.last, _at(60, 0));
    });
    test('deux points aberrants qui ne sont PAS d\'accord : aucun n\'est pris',
        () {
      final g = PawGpsGate641();
      g.seed(null, at(0));
      expect(g.offer(_at(0, 0), 150, at(0)), isTrue);
      expect(g.offer(_at(5000, 0), 8, at(1)), isFalse);
      expect(g.offer(_at(0, 7000), 8, at(2)), isFalse); // ailleurs
      expect(g.offer(_at(-3000, 0), 8, at(3)), isFalse); // encore ailleurs
      expect(g.last, _at(0, 0));
      // un point imprécis entre deux précis casse la suite
      expect(g.offer(_at(5000, 0), 8, at(4)), isFalse);
      expect(g.offer(_at(40, 0), 400, at(5)), isFalse);
      expect(g.pending, isNull);
      expect(g.offer(_at(5000, 0), 8, at(6)), isFalse);
      expect(g.offer(_at(5000, 0), 8, at(7)), isTrue);
    });
    test('deux points précis trop espacés dans le temps (> 10 s) : pas d\'accord',
        () {
      expect(pawFixesAgree642(_at(0, 0), at(0), _at(3, 0), at(2)), isTrue);
      expect(pawFixesAgree642(_at(0, 0), at(0), _at(17, 0), at(2)), isTrue);
      expect(pawFixesAgree642(_at(0, 0), at(0), _at(60, 0), at(2)), isFalse);
      expect(pawFixesAgree642(_at(0, 0), at(0), _at(3, 0), at(12)), isFalse);
      expect(pawFixesAgree642(_at(0, 0), at(5), _at(3, 0), at(2)), isFalse);
    });
  });
}
