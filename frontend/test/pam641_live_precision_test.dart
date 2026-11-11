// 641 (PAM) — « Position en direct imprécise » (retour d'un testeur, 10/11 :
// « Pas précis dans la géoloc direct » / « Et pas en direct montre le bon »).
//
// Cause : le filtre des points GPS de MA balade ne savait rien de la
// PRÉCISION du point qu'il gardait. Le tout premier point du flux (souvent la
// position en cache du téléphone, à 100 m – 1 km près) était toujours accepté,
// puis le bon point GPS arrivé 1 à 3 s plus tard, à 60-300 m de là, était
// refusé comme « saut impossible à pied » — pendant 25 s. Téléphone immobile
// (filtre de 5 m) : plus aucun point ensuite → « Moi » et ce que voient mes
// amis restaient sur la mauvaise position.
//
// Ces tests rejouent ces suites de points. Positions en zone fictive (−35/−30).
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/services/live_tracking_bg.dart';
import 'package:hopetsit/views/map/widgets/pawmap_follow612.dart';

/// Un point à [east] m à l'est et [north] m au nord de (−35, −30).
LatLng _at(double east, double north) =>
    LatLng(-35 + north / 111320.0, -30 + east / 91200.0);

void main() {
  final t0 = DateTime(2026, 11, 10, 21, 0, 0);
  DateTime at(double seconds) =>
      t0.add(Duration(milliseconds: (seconds * 1000).round()));

  group('641 · filtre : la précision du dernier point compte', () {
    test('1er point imprécis, puis bon point à 90 m, 2 s après : accepté', () {
      // Avant : refusé (90 m en 2 s = « saut »), 25 s sur la mauvaise position.
      expect(
          pawAcceptGpsFix612(
              accuracyM: 8,
              fix: _at(90, 0),
              lastGood: _at(0, 0),
              lastGoodAt: at(0),
              lastGoodAccuracyM: 150,
              now: at(2)),
          isTrue);
    });
    test('dernier point imprécis : un point PLUS précis le remplace', () {
      expect(
          pawAcceptGpsFix612(
              accuracyM: 60,
              fix: _at(70, 0),
              lastGood: _at(0, 0),
              lastGoodAt: at(0),
              lastGoodAccuracyM: 150,
              now: at(2)),
          isTrue);
    });
    test('dernier point imprécis : un point ENCORE moins précis est refusé', () {
      expect(
          pawAcceptGpsFix612(
              accuracyM: 400,
              fix: _at(300, 0),
              lastGood: _at(0, 0),
              lastGoodAt: at(0),
              lastGoodAccuracyM: 150,
              now: at(2)),
          isFalse);
    });
    test('dernier point précis : les règles 612 ne changent pas', () {
      // imprécis juste après un bon point : refusé
      expect(
          pawAcceptGpsFix612(
              accuracyM: 65,
              fix: _at(5, 0),
              lastGood: _at(0, 0),
              lastGoodAt: at(0),
              lastGoodAccuracyM: 9,
              now: at(3)),
          isFalse);
      // saut de 120 m en 3 s : refusé
      expect(
          pawAcceptGpsFix612(
              accuracyM: 10,
              fix: _at(120, 0),
              lastGood: _at(0, 0),
              lastGoodAt: at(0),
              lastGoodAccuracyM: 9,
              now: at(3)),
          isFalse);
      // marche normale : acceptée
      expect(
          pawAcceptGpsFix612(
              accuracyM: 10,
              fix: _at(6, 0),
              lastGood: _at(0, 0),
              lastGoodAt: at(0),
              lastGoodAccuracyM: 9,
              now: at(4)),
          isTrue);
      // après 25 s : on reprend ce qui vient (jamais figé)
      expect(
          pawAcceptGpsFix612(
              accuracyM: 80,
              fix: _at(200, 0),
              lastGood: _at(0, 0),
              lastGoodAt: at(0),
              lastGoodAccuracyM: 9,
              now: at(26)),
          isTrue);
    });
  });

  group('641 · la porte GPS du direct (ce que fait le service)', () {
    test('direct lancé SANS position : cache imprécis puis bon point → bon point',
        () {
      final g = PawGpsGate641();
      g.seed(null, at(0));
      // 1er point du flux : le cache du téléphone, à 300 m près.
      expect(g.offer(_at(0, 0), 300, at(0.4)), isTrue);
      // le vrai point GPS, 2 s plus tard, à 120 m de là.
      expect(g.offer(_at(120, 0), 7, at(2.4)), isTrue,
          reason: 'le bon point doit remplacer le point imprécis');
      expect(g.last, _at(120, 0));
      expect(g.accuracyM, 7);
    });
    test('direct lancé AVEC ma position : le cache imprécis ne l\'écrase pas',
        () {
      final g = PawGpsGate641();
      g.seed(_at(0, 0), at(0)); // ma position affichée hors direct
      // Avant : ce 1er point était toujours accepté, puis verrouillé 25 s.
      expect(g.offer(_at(400, 0), 800, at(0.4)), isFalse,
          reason: 'un point à 800 m près ne remplace pas ma position de départ');
      expect(g.last, _at(0, 0));
      // le vrai point GPS arrive : il remplace la position de départ, même
      // s'il en est à 60 m (elle n'était précise qu'à ~100 m).
      expect(g.offer(_at(60, 0), 6, at(2.4)), isTrue);
      expect(g.last, _at(60, 0));
    });
    test('ensuite, un saut impossible après un BON point reste refusé', () {
      final g = PawGpsGate641();
      g.seed(_at(0, 0), at(0));
      expect(g.offer(_at(10, 0), 6, at(2)), isTrue);
      expect(g.offer(_at(160, 0), 9, at(5)), isFalse); // 150 m en 3 s
      expect(g.offer(_at(14, 0), 30, at(6)), isTrue); // marche normale
      expect(g.offer(_at(15, 0), 90, at(8)), isFalse); // imprécis
      expect(g.last, _at(14, 0));
    });
    test('après 25 s sans bon point : on reprend, puis le bon point revient',
        () {
      final g = PawGpsGate641();
      g.seed(_at(0, 0), at(0));
      expect(g.offer(_at(5, 0), 8, at(1)), isTrue);
      expect(g.offer(_at(90, 0), 120, at(27)), isTrue); // jamais figé
      // Avant : le bon point suivant était refusé 25 s de plus.
      expect(g.offer(_at(30, 0), 8, at(29)), isTrue);
      expect(g.last, _at(30, 0));
    });
    test('arrêt du direct : la porte repart de zéro', () {
      final g = PawGpsGate641();
      g.seed(_at(0, 0), at(0));
      g.reset();
      expect(g.last, isNull);
      expect(g.accuracyM, isNull);
      expect(g.offer(_at(500, 0), 900, at(1)), isTrue); // premier point
    });
  });

  group('641 · réglages du GPS pendant le direct', () {
    test('précision maximale (comme le bouton « Ma position »), filtre 5 m', () {
      expect(liveGpsAccuracy641(degraded: false), LocationAccuracy.best);
      expect(liveGpsDistanceFilter641(degraded: false), 5);
    });
    test('mode dégradé (panne du flux) : inchangé', () {
      expect(liveGpsAccuracy641(degraded: true), LocationAccuracy.low);
      expect(liveGpsDistanceFilter641(degraded: true), 100);
    });
  });

  group('641 · service de fond Android : pas de point imprécis par-dessus', () {
    test('point précis et frais : envoyé', () {
      expect(
          bgFixUsable641(
              accuracyM: 12, fixAt: at(9), now: at(10), lastSentAt: at(0)),
          isTrue);
    });
    test('point imprécis (> 40 m) juste après un envoi : battement seul', () {
      expect(
          bgFixUsable641(
              accuracyM: 180, fixAt: at(14), now: at(15), lastSentAt: at(0)),
          isFalse);
    });
    test('vieille position en cache (5 min) : battement seul', () {
      expect(
          bgFixUsable641(
              accuracyM: 10,
              fixAt: at(-300),
              now: at(15),
              lastSentAt: at(0)),
          isFalse);
    });
    test('rien d\'envoyé depuis 30 s : on envoie ce qu\'on a (jamais figé)', () {
      expect(
          bgFixUsable641(
              accuracyM: 180, fixAt: at(60), now: at(61), lastSentAt: at(0)),
          isTrue);
      expect(
          bgFixUsable641(
              accuracyM: 180, fixAt: at(30), now: at(30), lastSentAt: at(0)),
          isTrue);
      expect(
          bgFixUsable641(
              accuracyM: 180, fixAt: at(29), now: at(29), lastSentAt: at(0)),
          isFalse);
      expect(
          bgFixUsable641(accuracyM: 180, fixAt: at(1), now: at(2), lastSentAt: null),
          isTrue);
    });
  });
}
