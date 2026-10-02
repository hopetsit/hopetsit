// 607 (PAM, 02/10/2026) — mini-peluches (idée 2 de Daniel), fluidité de la
// PawMap (règle « Moi » 48 px / 50 px, pas d'épingle Google de repli), et
// couleurs du menu du rôle sur les flèches des barres et les 4 boutons du haut.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/plush607_i18n.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';
import 'package:hopetsit/views/map/widgets/pawmap_jewel.dart';
import 'package:hopetsit/views/map/widgets/pawmap_overlap607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/views/map/widgets/pawmap_plush607.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';

const List<String> kLangs = <String>['fr', 'en', 'es', 'de', 'it', 'pt', 'pl', 'ja', 'ko'];

Widget _app(Widget child, {String lang = 'fr', Brightness b = Brightness.light}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      translations: AppTranslations(),
      locale: Locale(lang),
      theme: ThemeData(brightness: b),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void _size(WidgetTester t) {
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

const LatLng paris = LatLng(48.8566, 2.3522);

void main() {
  group('peluches · logique', () {
    test('lecture du serveur (contrat) et peluche à portée < 30 m', () {
      final p = PawPlush.fromJson({'id': 'a', 'type': 'fox', 'golden': true, 'lat': 48.8566, 'lng': 2.3522})!;
      expect(p.golden, isTrue);
      expect(PawPlush.fromJson({'id': '', 'lat': 1, 'lng': 2}), isNull);
      final far = PawPlush(id: 'b', type: 'teddy', lat: 48.8566 + 0.0005, lng: 2.3522); // ~55 m
      expect(pawPlushInReach(paris, [far]), isNull);
      final near = PawPlush(id: 'c', type: 'teddy', lat: 48.8566 + 0.0002, lng: 2.3522); // ~22 m
      expect(pawPlushInReach(paris, [far, near])!.id, 'c');
      expect(pawPlushAsset('fox'), 'assets/images/plush607_fox.png');
      expect(pawPlushAsset('fox', golden: true), 'assets/images/plush607_fox_gold.png');
      expect(pawPlushAsset('inconnu'), 'assets/images/plush607_teddy.png');
      expect(pawPlushFromLayers(const {}), isTrue);
      expect(pawPlushFromLayers(const {'plush': false}), isFalse);
    });

    test('capture : appel au serveur, peluche retirée, plus d\'essai le même jour', () async {
      final posts = <String>[];
      final layer = PawPlushLayer(
        get: (path, q) async => {
          'walkActive': true,
          'caughtToday': false,
          'plushies': [
            {'id': 'p1', 'type': 'kitty', 'lat': 48.8567, 'lng': 2.3522},
            {'id': 'p2', 'type': 'fox', 'lat': 48.87, 'lng': 2.36},
          ],
        },
        post: (path, body) async {
          posts.add(path);
          return {'ok': true, 'points': 520, 'streak': 3, 'bonuses': [{'kind': 'collector', 'points': 500}]};
        },
      );
      await layer.refresh(paris, force: true);
      expect(layer.items.map((e) => e.id), ['p1', 'p2']);
      final (r, pts) = await layer.onPosition(paris);
      expect(r, PawPlushCatch.caught);
      expect(pts, 520);
      expect(posts, ['/plush/p1/catch']);
      expect(layer.items.map((e) => e.id), ['p2']);
      expect(layer.lastWin!.collector, isTrue);
      expect(layer.caughtToday, isTrue);
      final (r2, _) = await layer.onPosition(const LatLng(48.87, 2.36));
      expect(r2, PawPlushCatch.none); // 1 par jour : on n'insiste pas
      expect(posts.length, 1);
    });

    test('refus du serveur : limite du jour, peluche déjà prise, trop loin', () async {
      String code = 'DAILY_LIMIT';
      PawPlushLayer mk() => PawPlushLayer(
            get: (p, q) async => {'plushies': [{'id': 'x', 'type': 'bunny', 'lat': 48.8566, 'lng': 2.3522}]},
            post: (p, b) async => throw ApiException(code, statusCode: 429, details: {'code': code}),
          );
      var l = mk();
      await l.refresh(paris, force: true);
      expect((await l.onPosition(paris)).$1, PawPlushCatch.dailyDone);
      code = 'ALREADY_CAUGHT';
      l = mk();
      await l.refresh(paris, force: true);
      expect((await l.onPosition(paris)).$1, PawPlushCatch.taken);
      expect(l.items, isEmpty);
      code = 'TOO_FAR';
      l = mk();
      await l.refresh(paris, force: true);
      expect((await l.onPosition(paris)).$1, PawPlushCatch.refused);
      expect(l.items.length, 1); // elle reste affichée
    });

    test('réseau coupé : la liste affichée RESTE ; Balade arrêtée : tout part', () async {
      var fail = false;
      final l = PawPlushLayer(
        get: (p, q) async {
          if (fail) throw Exception('réseau');
          return {'plushies': [{'id': 'k', 'type': 'puppy', 'lat': 48.86, 'lng': 2.35}]};
        },
        post: (p, b) async => {},
      );
      await l.refresh(paris, force: true);
      fail = true;
      await l.refresh(paris, force: true);
      expect(l.items.length, 1);
      l.clear();
      expect(l.items, isEmpty);
    });

    test('réglage éteint : aucun marqueur, aucune capture', () async {
      final l = PawPlushLayer(
        get: (p, q) async => {'plushies': [{'id': 'k', 'type': 'puppy', 'lat': 48.8566, 'lng': 2.3522}]},
        post: (p, b) async => fail('ne doit pas appeler le serveur'),
      );
      await l.refresh(paris, force: true);
      l.shown.value = false;
      expect(l.markers(tr: (k) => k), isEmpty);
      expect((await l.onPosition(paris)).$1, PawPlushCatch.none);
    });
  });

  group('peluches · textes et visuels', () {
    test('9 langues, mêmes clés, variables intactes', () {
      final fr = plush607I18n['fr']!.keys.toSet();
      for (final l in kLangs) {
        expect(plush607I18n[l]!.keys.toSet(), fr, reason: l);
        for (final k in ['plush607_caught', 'plush607_golden_won', 'plush607_collector_won']) {
          expect(plush607I18n[l]![k], contains('@points'), reason: '$l $k');
        }
        expect(plush607I18n[l]!['plush607_total'], contains('@count'));
        expect(plush607I18n[l]!['help607_plush_title'], isNotEmpty);
        expect(plush607I18n[l]!['help607_plush_body'], isNotEmpty);
      }
    });

    testWidgets('les 10 visuels existent (64 px) et se décodent', (t) async {
      for (final ty in kPawPlushTypes) {
        for (final g in [false, true]) {
          final data = await t.runAsync(() => rootBundle.load(pawPlushAsset(ty, golden: g)));
          final img = await t.runAsync(() async {
            final c = await ui.instantiateImageCodec(data!.buffer.asUint8List());
            return (await c.getNextFrame()).image;
          });
          expect(img!.width, 64, reason: '$ty $g');
        }
      }
    });

    testWidgets('collection : compteur par type, badge Collectionneur, 3 thèmes', (t) async {
      _size(t);
      for (final b in [Brightness.light, Brightness.dark]) {
        await t.pumpWidget(_app(
          PawPlushCollectionSection(
            load: () async => {
              'total': 4, 'golden': 1, 'streak': 3, 'badges': ['collector'],
              'counts': {'teddy': 2, 'bunny': 0, 'kitty': 1, 'puppy': 1, 'fox': 0},
            },
          ),
          b: b,
        ));
        await t.pumpAndSettle();
        expect(find.text('×2'), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('plush607_count_bunny')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('plush607_badge_collector')), findsOneWidget);
        expect(find.text('Ma collection de peluches'), findsOneWidget);
        expect(find.text('4 peluche(s)'), findsOneWidget);
        expect(t.takeException(), isNull);
      }
    });

    testWidgets('collection vide : phrase d\'invitation', (t) async {
      _size(t);
      await t.pumpWidget(_app(PawPlushCollectionSection(
          load: () async => {'total': 0, 'counts': {}}), lang: 'en'));
      await t.pumpAndSettle();
      expect(find.text('No plushies yet. Start a Walk and head to a park!'), findsOneWidget);
    });
  });

  group('fluidité · règle Moi (dessins jamais en contact) / 50 px', () {
    test('pastille PILE sur Moi : écartée jusqu\'à ne plus toucher la photo (56 + 4 px)', () {
      const me = Offset(100, 100);
      final s = pawRepelAll([const Offset(102, 100)], [true], [me], fixedR: [30], atR: [24.5]);
      final d = ((const Offset(102, 100) + s.first) - me).distance;
      expect(d, closeTo(30 + 24.5 + 4, 0.01)); // les dessins ne se touchent plus
      expect(s.first.distance, lessThanOrEqualTo(kPawRepelMaxPx));
    });

    test('un autre ami LOIN ne bloque plus l\'écart (bug du simulateur, Paris z12)', () {
      const me = Offset(100, 100);
      const friendFar = Offset(-60, 100); // à 160 px à gauche
      final s = pawRepelAll([const Offset(80, 100)], [true], [me, friendFar], fixedR: [30, 27.5], atR: [24.5]);
      expect(s.first, isNot(Offset.zero));
      expect(((const Offset(80, 100) + s.first) - me).distance, greaterThanOrEqualTo(58.4));
    });

    test('jamais deux ronds rapprochés à moins de 50 px', () {
      final me = const Offset(100, 100);
      // pastille à pousser vers la droite… où se trouve déjà une autre pastille
      final at = <Offset>[const Offset(110, 100), const Offset(175, 100)];
      final s = pawRepelAll(at, [true, true], [me]);
      final a = at[0] + s[0];
      final b = at[1] + s[1];
      expect((a - b).distance, greaterThanOrEqualTo(50));
      expect((a - me).distance, greaterThanOrEqualTo((at[0] - me).distance));
    });

    test('cas LEO (Paris z11) : pastille poussée vers un ami → elle fait le tour, jamais sous Moi', () {
      const me = Offset(200, 200);
      const friend = Offset(120, 200); // ami à 80 px à GAUCHE de Moi
      const at = Offset(185, 200); // pastille « 3 » à 15 px à gauche de Moi
      final s = pawRepelAll([at], [true], [me, friend], fixedR: [30, 27.5], atR: [24.5]);
      final p = at + s.first;
      expect((p - me).distance, greaterThanOrEqualTo(30 + 24.5 + 4 - 0.5)); // jamais sous Moi
      expect((p - friend).distance, greaterThanOrEqualTo(27.5 + 24.5 + 4 - 0.5)); // ni sous l'ami
      expect(s.first.distance, lessThanOrEqualTo(kPawRepelMaxPx * 1.5));
    });

    // ── 3 cas de LEO (site, 02/10) : rectangles réels ──
    final meBox = pawPinBox(30, labelW: 40, labelH: 16.3, labelGap: 3);
    final friendBox = pawPinBox(27.5);
    bool touchesMe(Offset me, Offset p, Rect box) => pawBoxesTouch(me, meBox, p, box);

    test('LEO 1 — Europe z3 : 2 amis à 11 km (2-3 px) sortent de sous « Moi », en éventail', () {
      const me = Offset(300, 300);
      final at = [const Offset(302, 301), const Offset(299, 302)];
      final sh = pawRepelBoxes(at, [friendBox, friendBox], [PawPlacedBox(me, meBox)]);
      final p0 = at[0] + sh[0], p1 = at[1] + sh[1];
      expect(touchesMe(me, p0, friendBox), isFalse);
      expect(touchesMe(me, p1, friendBox), isFalse);
      expect(pawBoxesTouch(p0, friendBox, p1, friendBox), isFalse); // l'un ne cache pas l'autre
    });

    test('LEO 2 — Paris z13-14 : le PRÉNOM sous un membre écarté ne touche plus « Moi »', () {
      const me = Offset(300, 300);
      final box = pawPinBox(24, labelW: 70); // rond + prénom dessous
      const at = Offset(300, 240); // membre au-dessus de moi : son prénom descend sur ma photo
      expect(touchesMe(me, at, box), isTrue);
      final sh = pawRepelBoxes([at], [box], [PawPlacedBox(me, meBox)]);
      expect(touchesMe(me, at + sh.first, box), isFalse);
    });

    test('LEO 3 — Bondy z13 : prénom long + bulle de prix, rectangle RÉEL (pas une marge fixe)', () {
      const me = Offset(300, 300);
      final box = pawPinBox(24, labelW: 132, bubbleW: 96); // « Christine-Hélène », « dès 100 €/sem »
      for (final at in [const Offset(313, 300), const Offset(300, 327), const Offset(280, 290)]) {
        final sh = pawRepelBoxes([at], [box], [PawPlacedBox(me, meBox)]);
        expect(touchesMe(me, at + sh.first, box), isFalse, reason: '$at');
      }
    });

    test('boîtes : deux membres posés ne se recouvrent jamais (prénoms compris)', () {
      const me = Offset(300, 300);
      final box = pawPinBox(24, labelW: 90, bubbleW: 70);
      final at = [const Offset(310, 305), const Offset(305, 310), const Offset(290, 300)];
      final sh = pawRepelBoxes(at, [box, box, box], [PawPlacedBox(me, meBox)]);
      final p = [for (var i = 0; i < 3; i++) at[i] + sh[i]];
      for (var i = 0; i < 3; i++) {
        expect(touchesMe(me, p[i], box), isFalse);
        for (var j = i + 1; j < 3; j++) {
          expect(pawBoxesTouch(p[i], box, p[j], box), isFalse, reason: '$i/$j');
        }
      }
    });

    test('un rond seul ne bouge jamais ; rien à écarter = zéro', () {
      final s = pawRepelAll([const Offset(101, 100), const Offset(400, 400)], [false, true], [const Offset(100, 100)]);
      expect(s, [Offset.zero, Offset.zero]);
    });

    test('Mercator aller-retour (position décalée exacte)', () {
      for (final z in [3.6, 9.0, 13.0, 16.0]) {
        final px = pawMercatorPx(48.8566, 2.3522, z);
        final (la, ln) = pawMercatorToLatLng(px, z);
        expect(la, closeTo(48.8566, 1e-9));
        expect(ln, closeTo(2.3522, 1e-9));
      }
    });

    testWidgets('image de repli = PNG transparent 1 × 1 (jamais d\'épingle Google)', (t) async {
      final img = await t.runAsync(() async {
        final c = await ui.instantiateImageCodec(kPawTransparentPng);
        return (await c.getNextFrame()).image;
      });
      expect(img!.width, 1);
      final bytes = await t.runAsync(() => img.toByteData(format: ui.ImageByteFormat.rawRgba));
      expect(bytes!.getUint8(3), 0); // alpha nul
      expect(PawMapPinCache.transparent.toJson().toString(), isNot(contains('defaultMarker')));
    });
  });

  group('couleur du menu du rôle', () {
    testWidgets('planche 3 rôles clair / sombre (image de référence)', (t) async {
      t.view.physicalSize = const Size(1200, 1500);
      t.view.devicePixelRatio = 3.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(_app(const _RoleBoard()));
      await t.pumpAndSettle();
      await expectLater(find.byKey(const ValueKey<String>('role_board')),
          matchesGoldenFile('goldens/pam607/menu_role_3roles.png'));
    });

    test('palette par rôle = celle de la pilule du menu', () {
      expect(pawMenuPaletteFor('owner').top, kPawTabBarPalettes[PawNavRole.owner]!.top);
      expect(pawMenuPaletteFor('sitter').top, kPawTabBarPalettes[PawNavRole.sitter]!.top);
      expect(pawMenuPaletteFor('walker').bottom, kPawTabBarPalettes[PawNavRole.walker]!.bottom);
      expect(pawMenuPaletteFor('').top, kPawTabBarPalettes[PawNavRole.owner]!.top);
      expect(pawJewelHeaderFor('sitter').light, kPawTabBarPalettes[PawNavRole.sitter]!.top);
      expect(pawJewelHeaderFor('walker').dark, kPawTabBarPalettes[PawNavRole.walker]!.bottom);
    });

    testWidgets('flèches des barres : fond plein du menu, contour et flèche blancs (3 rôles, clair/sombre)', (t) async {
      _size(t);
      for (final role in ['owner', 'sitter', 'walker']) {
        for (final b in [Brightness.light, Brightness.dark]) {
          for (final collapsed in [false, true]) {
            await t.pumpWidget(_app(
              PawBarCollapseTab(left: true, collapsed: collapsed, tint: Colors.red, onTap: () {}, role: role),
              b: b,
            ));
            final box = t.widget<Container>(find.byKey(const ValueKey<String>('pawmap_bar_tab_fill')));
            final deco = box.decoration! as BoxDecoration;
            final pal = pawMenuPaletteFor(role);
            expect((deco.gradient! as LinearGradient).colors, [pal.top, pal.bottom], reason: '$role $b');
            expect((deco.border! as Border).top.color, Colors.white);
            final icon = t.widget<Icon>(find.descendant(
                of: find.byKey(const ValueKey<String>('pawmap_bar_tab_fill')), matching: find.byType(Icon)));
            expect(icon.color, Colors.white);
          }
        }
      }
    });
  });
}

// Planche des 3 rôles (flèches des barres + 4 boutons du haut), clair et
// sombre : test/goldens/pam607/menu_role_3roles.png — à REGARDER.
class _RoleBoard extends StatelessWidget {
  const _RoleBoard();
  @override
  Widget build(BuildContext context) {
    Widget row(String role, Brightness b) => Theme(
          data: ThemeData(brightness: b),
          child: Container(
            color: b == Brightness.dark ? const Color(0xFF1E1716) : const Color(0xFFF6EFE6),
            padding: const EdgeInsets.all(8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final ic in [PawSymbols.help, PawSymbols.search, PawSymbols.refresh, PawSymbols.settings])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: PawJewel(palette: pawJewelHeaderFor(role), icon: ic, label: '', size: 40, onTap: () {}),
                ),
              const SizedBox(width: 12),
              PawBarCollapseTab(left: true, collapsed: false, tint: Colors.red, onTap: () {}, role: role),
              PawBarCollapseTab(left: false, collapsed: true, tint: Colors.red, onTap: () {}, role: role),
            ]),
          ),
        );
    return RepaintBoundary(
      key: const ValueKey<String>('role_board'),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final b in [Brightness.light, Brightness.dark])
          for (final r in ['owner', 'sitter', 'walker']) row(r, b),
      ]),
    );
  }
}

