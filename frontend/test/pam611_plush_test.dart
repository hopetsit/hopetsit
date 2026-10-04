// 611 (PAM, 04/10/2026) — vidéo de Daniel et Cam à Alhama (18 h 09) : « on ne
// sait pas trop où aller… on est à 3 mètres, pas 30… elle bouge… on est grave
// loin ». Côté app, ce fichier rejoue :
//   1. tolérance GPS : à 3 m réels, le téléphone peut annoncer 38 m avec une
//      précision de 15 m → la capture part (avec la précision, que le serveur
//      plafonne à 20 m) ; sans précision connue, rien ne part à 38 m ;
//   2. guidage : une FLÈCHE vers la peluche, juste même quand la carte de
//      Balade est tournée dans le sens de la marche ;
//   3. « déjà prise » (dorée, ou peluche du jour déjà attrapée) : la pastille
//      le DIT au lieu de sauter en silence sur une peluche lointaine ;
//   4. textes 9 langues.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/pawmap611_i18n.dart';
import 'package:hopetsit/views/map/widgets/pawmap_plush607.dart';

const _plush = LatLng(37.8530, -1.4230);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('1. tolérance de précision GPS', () {
    LatLng north(double m) => LatLng(_plush.latitude - m / 111320, _plush.longitude);
    PawPlushLayer mk(List<Map<String, dynamic>> bodies) => PawPlushLayer(
          get: (p, q) async => {
            'walkActive': true,
            'plushies': [
              {'id': 'b1', 'type': 'bunny', 'lat': _plush.latitude, 'lng': _plush.longitude},
            ],
          },
          post: (p, b) async {
            bodies.add(b);
            return {'ok': true, 'points': 20};
          },
        );

    test('38 m annoncés, précision 15 m : la capture part avec la précision', () async {
      final bodies = <Map<String, dynamic>>[];
      final l = mk(bodies);
      await l.refresh(north(38), force: true);
      final (r, _) = await l.onPosition(north(38), accuracy: 15);
      expect(r, PawPlushCatch.caught);
      expect(bodies.single['accuracy'], 15);
    });

    test('38 m sans précision : rien ne part (règle des 30 m)', () async {
      final bodies = <Map<String, dynamic>>[];
      final l = mk(bodies);
      await l.refresh(north(38), force: true);
      expect((await l.onPosition(north(38))).$1, PawPlushCatch.none);
      expect(bodies, isEmpty);
    });

    test('précision énorme (500 m) : plafonnée à 20 m, 61 m reste trop loin', () async {
      final bodies = <Map<String, dynamic>>[];
      final l = mk(bodies);
      await l.refresh(north(61), force: true);
      expect((await l.onPosition(north(61), accuracy: 500)).$1, PawPlushCatch.none);
      expect(bodies, isEmpty);
    });
  });

  test('2. flèche vers la peluche, carte droite ou tournée', () {
    const me = LatLng(37.8500, -1.4230);
    const northPlush = LatLng(37.8530, -1.4230);
    const eastPlush = LatLng(37.8500, -1.4200);
    expect(pawPlushArrowDeg(me, northPlush, mapBearing: 0), closeTo(0, 1));
    expect(pawPlushArrowDeg(me, eastPlush, mapBearing: 0), closeTo(90, 1));
    // carte de Balade tournée vers l'est : la peluche à l'est est « tout droit »
    expect(pawPlushArrowDeg(me, eastPlush, mapBearing: 90), closeTo(0, 1));
    expect(pawPlushArrowDeg(me, northPlush, mapBearing: 90), closeTo(-90, 1));
  });

  testWidgets('3. pastille « peluche du jour attrapée » et « déjà prise »', (t) async {
    await t.pumpWidget(GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      home: const Scaffold(
        body: Column(children: [
          PawNearestPlushPill(type: 'fox', golden: false, label: '174 m', onTap: _noop, arrowDeg: 45),
          PawPlushDonePill(),
        ]),
      ),
    ));
    await t.pump();
    expect(find.byKey(const ValueKey<String>('pawmap_plush_arrow')), findsOneWidget);
    expect(find.text('Tes 2 peluches du jour sont attrapées · reviens demain'), findsOneWidget);
    expect('plush611_taken'.tr, contains('juste avant toi'));
  });

  test('5. deux captures par jour : après la 1re on continue, après la 2e on s\'arrête', () async {
    final posts = <String>[];
    final l = _Twice.layer(posts);
    await l.refresh(const LatLng(37.85, -1.42), force: true);
    expect((await l.onPosition(const LatLng(37.85, -1.42))).$1, PawPlushCatch.caught);
    expect(l.caughtTodayCount611.value, 1);
    expect(l.caughtToday, isFalse, reason: '1 sur 2 : on peut encore en attraper une');
    expect((await l.onPosition(const LatLng(37.86, -1.43))).$1, PawPlushCatch.caught);
    expect(l.caughtTodayCount611.value, 2);
    expect(l.caughtToday, isTrue);
    expect(posts, ['/plush/a/catch', '/plush/b/catch']);
  });

  testWidgets('6. pastille « 1/2 attrapée » et texte 2 par jour', (t) async {
    await t.pumpWidget(GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      home: const Scaffold(
        body: PawNearestPlushPill(type: 'fox', golden: false, label: '80 m', onTap: _noop, progress: '1/2'),
      ),
    ));
    await t.pump();
    expect(find.text('1/2 attrapée'), findsOneWidget);
    expect('plush607_daily_done'.tr, contains('2 peluches'));
    expect('pp607_limit_daily2'.tr, '2 par jour');
  });

  test('4. 9 langues', () {
    for (final l in const ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      for (final k in const ['plush611_done_today', 'plush611_taken', 'plush611_arrow', 'plush611_progress']) {
        expect((pawmap611I18n[l]![k] ?? '').trim(), isNotEmpty, reason: '$l $k');
      }
    }
  });
}

void _noop() {}

// 611 — « 2 peluches par jour » (vocal de Cam du 04/10).
void twoPerDay611() {}

class _Twice {
  static PawPlushLayer layer(List<String> posts, {int count = 0}) => PawPlushLayer(
        get: (p, q) async => {
          'walkActive': true,
          'caughtToday': count >= 2,
          'caughtTodayCount': count,
          'dailyMax': 2,
          'plushies': [
            {'id': 'a', 'type': 'fox', 'lat': 37.85, 'lng': -1.42},
            {'id': 'b', 'type': 'kitty', 'lat': 37.86, 'lng': -1.43},
          ],
        },
        post: (p, b) async {
          posts.add(p);
          return {'ok': true, 'points': 20};
        },
      );
}
