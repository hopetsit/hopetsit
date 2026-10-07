// 613 (PAM, 06/10/2026) — PROCHAIN_BUILD_613 §1, §2, §4a, §4d.
//   A. la fête de la peluche (john n'a rien vu à 22:26) ;
//   B. « Rejoindre john » pendant un suivi ;
//   C. halo de la personne suivie FIXE, « Moi » ne se colle plus sous elle ;
//   D. aucune épingle ne clignote quand une personne en direct la frôle ;
//   E. jamais de rond de signalement vide.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/pm613_i18n.dart';
import 'package:hopetsit/views/map/widgets/pawmap_alerts613.dart';
import 'package:hopetsit/views/map/widgets/pawmap_catch613.dart';
import 'package:hopetsit/views/map/widgets/pawmap_follow612.dart';
import 'package:hopetsit/views/map/widgets/pawmap_layout607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_overlap607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_plush607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_report_pin613.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart' show pawJoinLabel613, pawJoinLine613;
import 'package:hopetsit/views/map/widgets/pawmap_signal.dart';

Future<BuildContext> _app(WidgetTester t, {VoidCallback? onTapBehind, Locale locale = const Locale('fr')}) async {
  late BuildContext ctx;
  await t.pumpWidget(ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      translations: AppTranslations(),
      locale: locale,
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return SizedBox.expand(
          child: GestureDetector(
            key: const ValueKey<String>('map_behind'),
            behavior: HitTestBehavior.opaque,
            onTap: onTapBehind,
          ),
        );
      })),
    ),
  ));
  return ctx;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    PawCatchCelebration.silentForTests = true;
  });

  group('A · la fête de la peluche', () {
    testWidgets('capture au premier plan : carte « +40 points · Chiot attrapé ! », vibration, '
        'aucun toucher bloqué, partie seule', (t) async {
      final haptics = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
        if (c.method == 'HapticFeedback.vibrate') haptics.add('${c.arguments}');
        return null;
      });
      var taps = 0;
      final ctx = await _app(t, onTapBehind: () => taps++);
      PawCatchCelebration.deliver(ctx, const PawPlushWin(points: 40, type: 'puppy'),
          lifecycle: AppLifecycleState.resumed);
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('+40 points'), findsOneWidget);
      expect(find.text('Chiot attrapé !'), findsOneWidget);
      expect(haptics, contains('HapticFeedbackType.heavyImpact'));
      // la carte reste touchable PENDANT la fête (IgnorePointer)
      await t.tapAt(const Offset(200, 120)); // pile sous la carte
      await t.tapAt(const Offset(200, 500)); // sous les confettis
      expect(taps, 2);
      await t.pump(const Duration(seconds: 4));
      expect(find.text('+40 points'), findsNothing, reason: 'partie seule');
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    // Cause MESURÉE dans le code (rejouée ici) : la réponse de la 1re demande
    // perdue (réseau coupé, app suspendue en poche…), l'app redemande 20 s plus
    // tard ; le serveur 612 répondait 409 ALREADY_CAUGHT à la MÊME personne et
    // l'app disait « Trop tard : quelqu'un l'a attrapée juste avant toi ».
    PawPlushLayer layerWith(Future<dynamic> Function() reply) => PawPlushLayer(
          get: (p, q) async => {
            'walkActive': true, 'caughtToday': false, 'caughtTodayCount': 0, 'dailyMax': 2,
            'plushies': [
              {'id': 'chiot', 'type': 'puppy', 'lat': 37.73065, 'lng': -1.34780},
            ],
          },
          post: (p, b) => reply(),
        );
    const here = LatLng(37.73065, -1.34780);

    test('AVANT : 2e demande de john → 409 « déjà attrapée » → message « Trop tard »', () async {
      final l = layerWith(() async => throw ApiException('x', statusCode: 409, details: {'code': 'ALREADY_CAUGHT'}));
      await l.refresh(here, force: true);
      final (res, pts) = await l.onPosition(here);
      expect(res, PawPlushCatch.taken); // = 'plush611_taken' à l'écran
      expect(pts, 0);
    });

    test('APRÈS : 2e demande → 200 « already » → SA capture, fêtée (points d\'origine, sans recrédit)', () async {
      final l = layerWith(() async => {
            'ok': true, 'already': true, 'points': 20,
            'plush': {'id': 'chiot', 'type': 'puppy', 'golden': false},
          });
      await l.refresh(here, force: true);
      final (res, pts) = await l.onPosition(here);
      expect(res, PawPlushCatch.caught);
      expect(pts, 20);
      expect(l.lastWin!.already, isTrue);
      expect(l.lastWin!.type, 'puppy');
    });

    test('APRÈS : « already » sans points mémorisés (capture d\'avant le 613) → 0, jamais inventé', () async {
      final l = layerWith(() async => {'ok': true, 'already': true, 'points': null, 'plush': {'type': 'puppy'}});
      await l.refresh(here, force: true);
      final (_, pts) = await l.onPosition(here);
      expect(pts, 0);
    });

    testWidgets('APRÈS : capture app en arrière-plan → fête GARDÉE puis jouée au retour', (t) async {
      final ctx = await _app(t);
      final before = PawCatchCelebration.shownCount;
      PawCatchCelebration.deliver(ctx, const PawPlushWin(points: 20, type: 'puppy'),
          lifecycle: AppLifecycleState.paused);
      await t.pump(const Duration(seconds: 6));
      expect(find.text('+20 points'), findsNothing);
      expect(PawCatchCelebration.pendingCountForTests(), 1);
      PawCatchCelebration.flushPending(ctx); // ce que fait le retour au premier plan
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('+20 points'), findsOneWidget);
      expect(find.text('Chiot attrapé !'), findsOneWidget);
      expect(PawCatchCelebration.shownCount, before + 1);
      expect(PawCatchCelebration.pendingCountForTests(), 0);
      await t.pump(const Duration(seconds: 4));
    });

    testWidgets('« déjà à moi » sans points connus : le nom seul, jamais un chiffre inventé', (t) async {
      final ctx = await _app(t);
      PawCatchCelebration.show(ctx, const PawPlushWin(points: 0, type: 'fox', already: true));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Renard attrapé !'), findsOneWidget);
      expect(find.textContaining('points'), findsNothing);
      await t.pump(const Duration(seconds: 4));
    });

    testWidgets('pendant la fête, les autres pastilles attendent (jamais deux messages superposés)', (t) async {
      final ctx = await _app(t);
      PawCatchCelebration.show(ctx, const PawPlushWin(points: 40, type: 'puppy'));
      await t.pump(const Duration(milliseconds: 300));
      PawSignal.show(ctx, PawSignalKind.live, 'Direct activé');
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Direct activé'), findsNothing);
      await t.pump(const Duration(seconds: 4));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Direct activé'), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      PawSignal.hide();
    });

    test('fête gardée sur disque : relue < 6 h, oubliée au-delà', () {
      final now = DateTime(2026, 10, 6, 22, 30);
      final j = pawCatchToJson613(const PawPlushWin(points: 40, type: 'puppy'), now);
      expect(pawCatchFromJson613(j, now: now.add(const Duration(hours: 1)))!.points, 40);
      expect(pawCatchFromJson613(j, now: now.add(const Duration(hours: 7))), isNull);
      expect(pawCatchCanShowNow613(AppLifecycleState.paused), isFalse);
      expect(pawCatchCanShowNow613(AppLifecycleState.inactive), isFalse);
      expect(pawCatchCanShowNow613(AppLifecycleState.resumed), isTrue);
    });

    test('couleurs des confettis : celles de la peluche (+ or), jamais de gris', () {
      for (final type in kPawPlushTypes) {
        for (final c in pawCatchColors613(type)) {
          final hsl = HSLColor.fromColor(c);
          expect(hsl.saturation, greaterThan(0.25), reason: '$type $c');
        }
      }
    });
  });

  group('B · « Rejoindre john » (9 langues)', () {
    testWidgets('prénom seul, en français', (t) async {
      await _app(t);
      expect(pawJoinLabel613('john C'), 'Rejoindre john');
      expect(pawJoinLabel613('  '), 'Le rejoindre');
    });
    test('les 9 langues ont toutes les clés 613, avec leurs @variables', () {
      const langs = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
      final keys = pm613I18n['fr']!.keys.toSet();
      for (final l in langs) {
        expect(pm613I18n[l]!.keys.toSet(), keys, reason: l);
        for (final k in keys) {
          final fr = pm613I18n['fr']![k]!;
          for (final v in RegExp(r'@\w+').allMatches(fr)) {
            expect(pm613I18n[l]![k], contains(v.group(0)), reason: '$l $k');
          }
        }
      }
    });
  });

  group('C · suivi : halo fixe, « Moi » décollé', () {
    test('halo de la personne suivie : à son plein, plus de phase « invisible »', () {
      // drawGlow : s = 0,5 + 0,5·sin(2π·phase) ; 612 : phases 0..3 → s = 0,5 / 1 / 0,5 / 0
      final s = 0.5 + 0.5 * math.sin(kPawFollowHaloPhase613 / kBoostPhasesForTest * 2 * math.pi);
      expect(s, closeTo(1, 1e-9));
    });

    test('AVANT : « Moi » posé sous john, sur son étiquette, n\'était pas écarté ; APRÈS : écarté', () {
      const r = 26 + 2.5; // friendSize/2 + 2,5
      final meBox = pawPinBox(28 + 2.0, labelW: 30, labelH: 16.3, labelGap: 3);
      // john (suivi) en (0,0) ; « Moi » 64 px plus bas : son rond chevauche
      // l'étiquette « john » (dessinée de r+3 à r+19,3 sous le centre).
      const john = Offset(0, 0);
      const me = Offset(0, 64);
      final before = pawFan612(
          meAt: me, meBox: meBox, friendsAt: [john], friendBox: pawPinBox(r), followed: {0});
      expect(before.me, Offset.zero, reason: '612 : boîte = rond seul');
      final after = pawFan612(
          meAt: me, meBox: meBox, friendsAt: [john], friendBox: pawFriendBox613(r, labelW: 34),
          followed: {0});
      expect(after.me, isNot(Offset.zero));
      expect(after.friends.single, Offset.zero, reason: 'la personne suivie ne bouge jamais');
      // plus aucun contact entre « Moi » déplacé et john + étiquette
      expect(pawBoxesTouch(me + after.me, meBox, john, pawFriendBox613(r, labelW: 34)), isFalse);
    });
  });

  group('D · aucune épingle ne clignote au passage d\'une personne en direct', () {
    PawPlaced spot(Offset at) => PawPlaced(id: 'pawspot_1', at: at, size: const Size(60, 74), anchor: const Offset(0.5, 1));
    PawPlaced report(Offset at) => PawPlaced(id: 'report_1', at: at, size: const Size(36, 36));
    PawPlaced person(String id, Offset at) => PawPlaced(id: id, at: at, size: const Size(78, 96));

    test('john (ami en direct) passe sur un PawSpot puis repart : le spot ne disparaît JAMAIS', () {
      for (var x = -120.0; x <= 120; x += 6) {
        final hide = pawResolveCollisions([spot(const Offset(0, 0)), report(const Offset(40, -20)),
            person('friend_john', Offset(x, -30)), person('me', Offset(x + 50, -10))]);
        expect(hide, isEmpty, reason: 'john à x=$x');
      }
    });

    test('un membre IMMOBILE garde la règle 607 (le lieu sous lui n\'est pas posé)', () {
      final hide = pawResolveCollisions([spot(const Offset(0, 0)), person('nearby_42', const Offset(0, -30))]);
      expect(hide, contains('pawspot_1'));
    });
  });

  group('E · signalement : jamais de rond vide', () {
    ByteData disk({bool ink = false}) {
      const w = 56, h = 56;
      final b = ByteData(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          final inside = (x - 28) * (x - 28) + (y - 28) * (y - 28) < 26 * 26;
          final glyph = ink && (x - 28).abs() < 8 && (y - 28).abs() < 8;
          b.setUint8(i, glyph ? 30 : 255);
          b.setUint8(i + 1, glyph ? 30 : 255);
          b.setUint8(i + 2, glyph ? 30 : 255);
          b.setUint8(i + 3, inside ? 255 : 0);
        }
      }
      return b;
    }

    test('rond blanc sans glyphe = vide ; avec glyphe = plein', () {
      expect(pawPinHasInk613(disk(), 56, 56), isFalse);
      expect(pawPinHasInk613(disk(ink: true), 56, 56), isTrue);
    });

    testWidgets('l\'icône de secours se dessine toujours (police embarquée)', (t) async {
      await t.runAsync(() async {
        for (final type in ['hazard', 'busy_traffic', 'dead_animal', 'tick_zone', 'inconnu']) {
          final img = await pawPaintReportPin613(icon: pawReportFallbackIcon613(type));
          final raw = await img.toByteData(format: ImageByteFormat.rawRgba);
          expect(pawPinHasInk613(raw!, img.width, img.height), isTrue, reason: type);
        }
      });
    });
  });

  group('F · « Rejoindre » : l\'itinéraire passe AU-DESSUS du fond OSM et de la traîne', () {
    test('zIndex itinéraire > fond OSM (0) et > traîne violette (2)', () {
      final p = pawRoutePolyline613(const [LatLng(37.73, -1.348), LatLng(37.731, -1.347)], const Color(0xFFC92A12));
      expect(p.zIndex, greaterThan(2));
      expect(p.polylineId.value, 'pawspot_route');
    });
    test('départ / arrivée accrochés au sentier : pointillés vers MOI et vers john', () {
      const me = LatLng(37.73060, -1.34800);
      const john = LatLng(37.73118, -1.34786);
      const path = [LatLng(37.73087, -1.34766), LatLng(37.73110, -1.34775)]; // le sentier
      final set = pawRoutePolylines613(path, const Color(0xFFC92A12), from: me, to: john);
      final ids = set.map((p) => p.polylineId.value).toSet();
      expect(ids, {'pawspot_route', 'pawspot_route_in', 'pawspot_route_out'});
      final lin = set.firstWhere((p) => p.polylineId.value == 'pawspot_route_in');
      expect(lin.points.first, me);
      expect(set.firstWhere((p) => p.polylineId.value == 'pawspot_route_out').points.last, john);
      for (final p in set) {
        expect(p.zIndex, greaterThan(2));
      }
      // départ / arrivée déjà sur les personnes (< 4 m) : pas de pointillés
      final tight = pawRoutePolylines613([me, john], const Color(0xFFC92A12), from: me, to: john);
      expect(tight.length, 1);
    });
  });

  group('I · cadrage « Rejoindre » dans la zone libre', () {
    test('Moi et john (300 m) tiennent entre rails, bandeau et fiche', () {
      const scr = Size(393, 852);
      final free = Rect.fromLTRB(72, 181, 331, 634);
      const me = LatLng(37.73060, -1.34800);
      final john = LatLng(37.73060 + 210 / 111320, -1.34800 + 215 / 111320 / 0.7912);
      final (c, z) = pawFrameInRect613([me, john], scr, free);
      Offset px(LatLng p) {
        double mx(double l) => (l + 180) / 360;
        double my(double la) {
          final s = math.sin(la * math.pi / 180);
          return 0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi);
        }
        final w = 256 * math.pow(2, z);
        return Offset(scr.width / 2 + (mx(p.longitude) - mx(c.longitude)) * w,
            scr.height / 2 + (my(p.latitude) - my(c.latitude)) * w);
      }
      for (final p in [me, john]) {
        expect(free.deflate(40).contains(px(p)), isTrue, reason: '$p → ${px(p)}');
      }
      expect(z, lessThanOrEqualTo(18.5));
    });
    test('libellé du bandeau', () {
      expect(pawJoinLine613(name: 'john C', dist: '355 m', dur: '4 min à pied'),
          'Rejoindre john · 355\u00A0m · 4\u00A0min à pied');
    });
    testWidgets('9 langues : un nombre n\'est JAMAIS séparé de son unité (bandeau étroit)', (t) async {
      const langs = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
      for (final l in langs) {
        await _app(t, locale: Locale(l));
        for (final dur in ['route_duration_min'.tr.replaceAll('{min}', '4'),
            'route_duration_h'.tr.replaceAll('{h}', '1').replaceAll('{min}', '05')]) {
          final line = pawJoinLine613(
              name: 'john C', dist: '1.2 km'.replaceAll('.', ','), dur: 'pm613_walk_time'.trParams({'t': dur}));
          // aucune espace ordinaire à côté d'un chiffre
          expect(RegExp(r'\d[ ]|(?<!·)[ ]\d').hasMatch(line), isFalse, reason: '$l « $line »');
          // et au rendu, à toutes les largeurs de 120 à 300 px, chaque nombre
          // reste sur la même ligne que son unité
          for (var w = 120.0; w <= 300; w += 6) {
            final tp = TextPainter(
                text: TextSpan(text: line, style: const TextStyle(fontSize: 12.5)),
                textDirection: TextDirection.ltr)
              ..layout(maxWidth: w);
            for (final m in RegExp(r'\d+[\u00A0]\S+').allMatches(line)) {
              final a = tp.getOffsetForCaret(TextPosition(offset: m.start), Rect.zero).dy;
              final b = tp.getOffsetForCaret(TextPosition(offset: m.end - 1), Rect.zero).dy;
              expect(a, b, reason: '$l « ${m[0]} » coupé à ${w.toInt()} px');
            }
          }
        }
      }
    });
  });

  group('G · alertes jolies (4b)', () {
    test('gravité : danger rouge, attention orange, info bleu, jamais gris', () {
      expect(pawAlertLevel613('hazard'), PawAlertLevel.danger);
      expect(pawAlertLevel613('poison'), PawAlertLevel.danger);
      expect(pawAlertLevel613('aggressive_dog'), PawAlertLevel.danger);
      expect(pawAlertLevel613('busy_traffic'), PawAlertLevel.attention);
      expect(pawAlertLevel613('dead_animal'), PawAlertLevel.attention);
      expect(pawAlertLevel613('water_active'), PawAlertLevel.info);
      expect(pawAlertLevel613('type_inconnu'), PawAlertLevel.attention);
      for (final l in PawAlertLevel.values) {
        expect(HSLColor.fromColor(pawAlertColor613(l)).saturation, greaterThan(0.6));
      }
    });
    test('fraîche < 2 h ; pâlit après 24 h et 36 h', () {
      final t0 = DateTime(2026, 10, 6, 20, 35);
      expect(pawAlertFresh613(t0, t0.add(const Duration(minutes: 119))), isTrue);
      expect(pawAlertFresh613(t0, t0.add(const Duration(minutes: 121))), isFalse);
      expect(pawAlertAlpha613(t0, t0.add(const Duration(hours: 3))), 1.0);
      expect(pawAlertAlpha613(t0, t0.add(const Duration(hours: 30))), lessThan(1.0));
      expect(pawAlertAlpha613(t0, t0.add(const Duration(hours: 40))),
          lessThan(pawAlertAlpha613(t0, t0.add(const Duration(hours: 30)))));
    });
    testWidgets('épingle fraîche et normale : jamais vides, anneau coloré', (t) async {
      await t.runAsync(() async {
        for (final fresh in [false, true]) {
          final img = await pawPaintReportPin613(icon: pawReportFallbackIcon613('hazard'),
              ringColor: pawAlertColor613(PawAlertLevel.danger), fresh: fresh);
          final raw = await img.toByteData(format: ImageByteFormat.rawRgba);
          expect(pawPinHasInk613(raw!, img.width, img.height), isTrue);
          // un pixel de l'anneau, à gauche du centre, est rouge
          final rDisk = fresh ? 22 : 26;
          final x = 28 - rDisk + 1, y = 28;
          final i = (y * img.width + x) * 4;
          expect(raw.getUint8(i), greaterThan(150), reason: 'rouge (fresh=$fresh)');
          expect(raw.getUint8(i + 1), lessThan(120));
        }
      });
    });
  });

  group('H · alerte en passant (4c)', () {
    const me0 = LatLng(37.73000, -1.34800);
    LatLng north(double m) => LatLng(me0.latitude + m / 111320, me0.longitude);
    test('à ≤ 50 m : annoncée UNE fois par balade ; au-delà : rien ; nouvelle balade : de nouveau', () {
      final a = PawPassingAlerts613();
      final glass = PawAlertPoint613('r1', 'hazard', north(90));
      expect(a.onPosition(me0, [glass]), isNull, reason: '90 m');
      final hit = a.onPosition(north(45), [glass]);
      expect(hit, isNotNull);
      expect(hit!.meters, inInclusiveRange(44, 46));
      expect(hit.ahead, isTrue, reason: 'je marche vers le nord, elle est devant');
      expect(hit.level, PawAlertLevel.danger);
      expect(a.onPosition(north(60), [glass]), isNull, reason: 'déjà annoncée');
      a.reset();
      expect(a.onPosition(north(80), [glass]), isNotNull);
    });
    test('la plus proche d\'abord ; derrière moi = « près de toi »', () {
      final a = PawPassingAlerts613();
      a.onPosition(north(0), const []);
      final hit = a.onPosition(north(20), [
        PawAlertPoint613('loin', 'busy_traffic', north(60)),
        PawAlertPoint613('derriere', 'poop', north(0)),
      ]);
      expect(hit!.id, 'derriere');
      expect(hit.ahead, isFalse);
    });
    testWidgets('bandeau : texte traduit, ne bloque aucun toucher, part seul', (t) async {
      PawPassingBanner613.silentForTests = true;
      var taps = 0;
      final ctx = await _app(t, onTapBehind: () => taps++);
      PawPassingBanner613.show(ctx,
          const PawPassing613(id: 'r1', type: 'hazard', meters: 40, ahead: true),
          label: 'Verre cassé', emoji: '⚠️');
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Verre cassé'), findsOneWidget);
      expect(find.text('40 m devant toi'), findsOneWidget);
      await t.tapAt(const Offset(200, 120));
      expect(taps, 1);
      await t.pump(const Duration(seconds: 5));
      expect(find.text('Verre cassé'), findsNothing);
    });
  });
}

/// Même valeur que `kBoostPhases` (pawmap_pins.dart).
const int kBoostPhasesForTest = 4;
