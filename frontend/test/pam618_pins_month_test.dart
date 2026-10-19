// 618 (PAM, 19/10/2026) — build 618 : ×2 Premium affiché (§A), pins du
// classement (§B), collection du mois + message de fin (§C).
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/plush618_i18n.dart';
import 'package:hopetsit/views/map/widgets/pawmap_catch613.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/views/map/widgets/pawmap_plush607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_plush_month618.dart';
import 'package:hopetsit/widgets/paw_pins618.dart';
import 'package:hopetsit/widgets/paw_rank611.dart';

Widget _app(Widget child, {String lang = 'fr', Brightness b = Brightness.light}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      translations: AppTranslations(),
      locale: Locale(lang),
      theme: ThemeData(brightness: b),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void _size(WidgetTester t) {
  t.view.physicalSize = const Size(393, 1600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

/// Réponse de /plush/collection AVANT le 01/11 (contrat de ZOE du 19/10).
Map<String, dynamic> _collection({
  Map<String, int> counts = const {'teddy': 1, 'bunny': 1, 'kitty': 1, 'puppy': 1, 'fox': 1},
  List<String> badges = const ['collector'],
  Map<String, dynamic>? monthly,
}) =>
    {
      'total': counts.values.fold<int>(0, (a, b) => a + b),
      'counts': counts,
      'golden': 0,
      'streak': 0,
      'badges': badges,
      'monthly': monthly,
      'monthlyBadges': const [],
      'items': const [],
    };

Map<String, dynamic> _novembre({List<String> caught = const [], bool complete = false}) => {
      'key': '2026-11',
      'theme': 'autumn',
      'label': 'Automne',
      'labels': {'fr': 'Automne', 'en': 'Autumn'},
      'color': '#C2571A',
      'caughtTypes': caught,
      'complete': complete,
      'bonusPoints': 500,
      'startsAt': '2026-10-31T23:00:00.000Z',
      'endsAt': '2026-11-30T23:00:00.000Z',
    };

void main() {
  test('les 9 langues ont les mêmes clés 618', () {
    final fr = plush618I18n['fr']!.keys.toSet();
    for (final l in ['en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      expect(plush618I18n[l]!.keys.toSet(), fr, reason: l);
    }
  });

  group('§B pins', () {
    test('lecture du contrat : absent / vide = null, podium 1..3, 1er Chef de meute', () {
      expect(PawPins618.fromJson(null), isNull);
      expect(PawPins618.fromJson(const {'podium': null, 'firstPackLeader': false}), isNull);
      expect(PawPins618.fromJson(const {'podium': 7}), isNull);
      expect(PawPins618.fromJson(const {'podium': 2})!.podium, 2);
      expect(PawPins618.fromJson(const {'firstPackLeader': true})!.mapCode, 4);
      expect(PawPins618.fromJson(const {'podium': 1, 'firstPackLeader': true})!.mapCode, 1);
      // Une personne à 3 rôles : le meilleur pin l'emporte.
      final best = PawPins618.bestOf(const [
        null,
        {'podium': 3},
        {'podium': 1},
        {'firstPackLeader': true},
      ])!;
      expect(best.podium, 1);
      expect(best.firstPackLeader, isTrue);
      expect(PawPins618.bestOf(const [null, {}]), isNull);
    });

    test('argent BLEUTÉ, jamais gris (saturation ≥ 25 %)', () {
      for (final c in [PawPinStyle618.silver.light, PawPinStyle618.silver.dark]) {
        expect(HSLColor.fromColor(c).saturation, greaterThanOrEqualTo(0.25));
      }
    });

    testWidgets('ma ligne du classement porte mes pins ; sans champ, rien', (t) async {
      _size(t);
      await t.pumpWidget(_app(const Column(children: [
        PawLeaderboardMeRow611(
          key: ValueKey('avec'),
          me: {
            'position': 1,
            'pointsEarned': 3200,
            'rank': {'key': 'pack_leader', 'level': 4, 'pointsEarned': 3200, 'nextAt': 10000, 'nextKey': 'legend'},
            'pins': {'podium': 1, 'firstPackLeader': true},
          },
        ),
        PawLeaderboardMeRow611(key: ValueKey('sans'), me: {'position': 9, 'pointsEarned': 136}),
      ])));
      await t.pump();
      expect(find.descendant(of: find.byKey(const ValueKey('avec')), matching: find.byKey(const ValueKey('pin618_1'))),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('avec')), matching: find.byKey(const ValueKey('pin618_4'))),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('sans')), matching: find.byKey(const ValueKey('pins618_row'))),
          findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('rangée complète : libellés traduits (fr, en, ko) et mode sombre', (t) async {
      _size(t);
      for (final lang in ['fr', 'en', 'ko']) {
        await t.pumpWidget(const SizedBox());
        Get.locale = Locale(lang);
        await t.pumpWidget(_app(
            const PawPinsRow618(pins: PawPins618(podium: 2, firstPackLeader: true)),
            lang: lang,
            b: lang == 'ko' ? Brightness.dark : Brightness.light));
        await t.pump();
        final want = plush618I18n[lang]!;
        expect(find.text(want['pins618_silver']!), findsOneWidget, reason: lang);
        expect(find.text(want['pins618_first_pack_leader']!), findsOneWidget, reason: lang);
        expect(t.takeException(), isNull);
      }
    });

    test('le pin se dessine sur le rond de la carte (sans exception)', () {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      for (final code in [1, 2, 3, 4]) {
        PawMapPinPainter.drawPin618(canvas, const Offset(20, 20), code);
      }
      PawMapPinPainter.drawPin618(canvas, const Offset(20, 20), 0); // rien
      rec.endRecording().dispose();
    });
  });

  group('§A ×2 Premium', () {
    test('« +500 ×2 Premium = 1000 » au lieu de « +1000 » seul', () {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr');
      expect(pawCatchTitle613(const PawPlushWin(points: 1000, premiumDoubled: true)),
          '+500 ×2 Premium = 1000');
      expect(pawCatchTitle613(const PawPlushWin(points: 40)), contains('40'));
      expect(pawCatchTitle613(const PawPlushWin(points: 40)), isNot(contains('×2')));
      // Gardée en mémoire puis rejouée : le drapeau survit.
      final back = pawCatchFromJson613(
          pawCatchToJson613(const PawPlushWin(points: 1000, premiumDoubled: true, monthCollector: true), DateTime.now()))!;
      expect(back.premiumDoubled, isTrue);
      expect(back.monthCollector, isTrue);
    });
  });

  group('§C collection du mois', () {
    test('message de fin de la collection d\'origine (question de Daniel)', () {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr');
      final now = DateTime(2026, 10, 19, 15);
      final nov = PawMonthly618.fromJson(_novembre(), lang: 'fr');
      expect(pawCollectionDoneMessage618(originComplete: true, monthly: nov, now: now),
          'Collection complète ! Prochaine collection : celle de novembre, dès le 1er');
      // Sans contrat serveur : même message (novembre 2026).
      expect(pawCollectionDoneMessage618(originComplete: true, monthly: null, now: now),
          'Collection complète ! Prochaine collection : celle de novembre, dès le 1er');
      expect(pawCollectionDoneMessage618(originComplete: false, monthly: nov, now: now), '');
      // Novembre en cours et complet → décembre.
      final done = PawMonthly618.fromJson(
          _novembre(caught: const ['teddy', 'bunny', 'kitty', 'puppy', 'fox'], complete: true))!;
      expect(pawCollectionDoneMessage618(originComplete: true, monthly: done, now: DateTime(2026, 11, 12)),
          'Collection de novembre complète ! Prochaine : celle de décembre, dès le 1er');
      expect(pawNextMonthKey618('2026-12'), '2027-01');
    });

    test('compte à rebours avant le 01/11 puis pendant le mois', () {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr');
      final nov = PawMonthly618.fromJson(_novembre())!;
      expect(pawMonthlyCountdown618(nov, DateTime.utc(2026, 10, 19, 12)), 'Départ dans 13 j, le 1er');
      expect(pawMonthlyCountdown618(nov, DateTime.utc(2026, 10, 31, 20)), 'Départ dans 3 h');
      expect(pawMonthlyCountdown618(nov, DateTime.utc(2026, 11, 25, 23)), 'Encore 5 j');
    });

    testWidgets('album : collection d\'origine complète → message + carte novembre 0/5', (t) async {
      _size(t);
      await t.pumpWidget(_app(PawPlushCollectionSection(
        load: () async => _collection(monthly: _novembre()),
        now: () => DateTime.utc(2026, 10, 19, 12),
      )));
      await t.pump();
      await t.pump();
      expect(find.text('Collection complète ! Prochaine collection : celle de novembre, dès le 1er'), findsOneWidget);
      expect(find.byKey(const ValueKey('month618_card')), findsOneWidget);
      expect(find.text('0/5'), findsOneWidget);
      expect(find.text('Départ dans 13 j, le 1er'), findsOneWidget);
      expect(find.text('Thème : Automne'), findsOneWidget);
      expect(find.byKey(const ValueKey('month618_plush_fox')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('novembre en cours, 3/5 attrapées, anglais + sombre', (t) async {
      _size(t);
      await t.pumpWidget(_app(
        PawPlushCollectionSection(
          load: () async => _collection(
              monthly: _novembre(caught: const ['teddy', 'fox', 'kitty'])),
          now: () => DateTime.utc(2026, 11, 20, 9),
        ),
        lang: 'en',
        b: Brightness.dark,
      ));
      await t.pump();
      await t.pump();
      expect(find.text('3/5'), findsOneWidget);
      expect(find.text('Theme: Autumn'), findsOneWidget);
      expect(find.text('11 d left'), findsOneWidget);
      // Collection du mois pas complète : pas de bandeau de fin.
      expect(find.byKey(const ValueKey('month618_done_banner')), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('ancien serveur (pas de « monthly ») : pas de faux compteur', (t) async {
      _size(t);
      await t.pumpWidget(_app(PawPlushCollectionSection(
        load: () async => _collection(counts: const {'teddy': 1}, badges: const []),
        now: () => DateTime.utc(2026, 10, 19, 12),
      )));
      await t.pump();
      await t.pump();
      expect(find.byKey(const ValueKey('month618_card')), findsNothing);
      expect(find.byKey(const ValueKey('month618_done_banner')), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('les 12 thèmes se dessinent (aucune image externe)', (t) async {
      _size(t);
      await t.pumpWidget(_app(Wrap(children: [
        for (final th in [...kPawMonthThemes618, 'inconnu'])
          PawThemedPlush618(type: 'teddy', theme: th, color: kPawMonthThemeColors618[th] ?? Colors.orange),
      ])));
      await t.pump();
      expect(find.byType(PawThemedPlush618), findsNWidgets(13));
      expect(t.takeException(), isNull);
    });
  });
}

