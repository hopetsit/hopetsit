// v601 (PAM, 29/09) — barre de DROITE personnalisable comme la gauche, et
// drapeau Balade au-dessus du bouton Balade (la pilule du haut à gauche est
// retirée). Clair / nuit, 9 langues, petites hauteurs d'écran.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/pawmap601_i18n.dart';
import 'package:hopetsit/views/map/widgets/paw_rail_button.dart';
import 'package:hopetsit/views/map/widgets/pawmap_rail.dart';
import 'package:hopetsit/views/map/widgets/pawmap_walk_badge.dart';

const List<String> kLangs = <String>[
  'fr', 'en', 'es', 'de', 'it', 'pt', 'pl', 'ja', 'ko',
];

Widget _app(Widget child,
    {String lang = 'fr', Brightness b = Brightness.light, Size size = const Size(393, 852)}) {
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

void _size(WidgetTester t, Size s) {
  t.view.physicalSize = s;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('réglage de la barre de droite', () {
    test('fixes jamais personnalisables ; ordre d\'origine ; vide permis', () {
      final ids = kPawCapsuleDefaultOrder;
      expect(ids, ['satellite', 'everyone', 'balade', 'eye']);
      for (final fixed in ['position', 'zoom_in', 'zoom_out', 'my_location']) {
        expect(pawCapsuleSlotOf(fixed), isNull, reason: fixed);
      }
      expect(normalizeCapsuleOrder(null), ids);
      expect(normalizeCapsuleOrder(<String>[]), isEmpty);
      expect(normalizeCapsuleOrder(['balade', 'x', 'balade', 'satellite']),
          ['balade', 'satellite']);
      // La gauche n'est pas touchée : ses ids ne passent pas à droite.
      expect(normalizeCapsuleOrder(['around', 'chat']), isEmpty);
    });

    test('9 langues pour chaque texte nouveau, sauf ceux qui existaient', () {
      for (final l in kLangs) {
        for (final k in pawmap601I18n['fr']!.keys) {
          expect(pawmap601I18n[l]?[k], isNotEmpty, reason: '$l $k');
        }
      }
      for (final s in kPawCapsuleSlotSpecs) {
        for (final l in kLangs) {
          final keys = AppTranslations().keys[l] ?? AppTranslations().keys['${l}_${l.toUpperCase()}'];
          if (keys == null) continue;
          expect(keys[s.labelKey], isNotNull, reason: '$l ${s.labelKey}');
          expect(keys[s.helpKey], isNotNull, reason: '$l ${s.helpKey}');
        }
      }
    });

    for (final b in Brightness.values) {
      testWidgets('même écran que la gauche : phrase des fixes, masquer tout, ordre ($b)',
          (t) async {
        _size(t, const Size(393, 852));
        List<String>? got;
        await t.pumpWidget(_app(
          Material(
            child: PawRailCustomizeSheet(
              order: kPawCapsuleDefaultOrder,
              specs: kPawCapsuleSlotSpecs,
              titleKey: 'pawmap601_capsule_customize',
              fixedNoteKey: 'pawmap601_capsule_fixed',
              allowEmpty: true,
              onChanged: (o) => got = o,
            ),
          ),
          b: b,
        ));
        await t.pump();
        expect(t.takeException(), isNull);
        expect(find.text('Modifier la barre de droite'), findsOneWidget);
        expect(find.byKey(const ValueKey('capsule_fixed_note')), findsOneWidget);
        for (final id in kPawCapsuleDefaultOrder) {
          expect(find.byKey(ValueKey('rail_switch_$id')), findsOneWidget, reason: id);
        }
        for (final id in kPawCapsuleDefaultOrder) {
          await t.tap(find.byKey(ValueKey('rail_switch_$id')));
          await t.pump();
        }
        expect(got, isEmpty, reason: 'tout masqué : permis à droite');
        await t.tap(find.byKey(const ValueKey('rail_switch_balade')));
        await t.pump();
        expect(got, ['balade']);
      });
    }

    testWidgets('la GAUCHE garde son comportement (jamais vide)', (t) async {
      List<String>? got;
      await t.pumpWidget(_app(Material(
        child: PawRailCustomizeSheet(order: const <String>[], onChanged: (o) => got = o),
      )));
      await t.pump();
      expect(find.text('Modifier la barre de droite'), findsNothing);
      expect(find.byKey(const ValueKey('capsule_fixed_note')), findsNothing);
      expect(find.byKey(const ValueKey('rail_switch_around')), findsOneWidget);
      expect(got, isNull);
    });
  });

  group('capsule : fixes toujours là, le reste défile (jamais sur le menu)', () {
    Widget btn(String k) => Container(key: ValueKey(k), width: 44, height: 44, color: const Color(0xFFC92A12));
    for (final h in <double>[568, 640, 667, 852, 956]) {
      testWidgets('écran de $h dp : aucun débordement', (t) async {
        _size(t, Size(360, h));
        // Hauteur utile d'une barre sur un petit écran : ~ la moitié.
        final double maxH = (h * 0.45).clamp(120, h);
        await t.pumpWidget(_app(PawGlassCapsule(
          width: 50,
          maxHeight: maxH,
          leading: [btn('fix_pos'), btn('fix_plus'), btn('fix_minus')],
          children: [for (var i = 0; i < 9; i++) btn('slot_$i')],
          footer: const SizedBox(height: 60, width: 50),
        )));
        await t.pump();
        expect(t.takeException(), isNull);
        final capsule = t.getSize(find.byType(PawGlassCapsule));
        expect(capsule.height, lessThanOrEqualTo(maxH + 0.5));
        for (final k in ['fix_pos', 'fix_plus', 'fix_minus']) {
          expect(find.byKey(ValueKey(k)).hitTestable(), findsOneWidget, reason: k);
        }
        expect(find.byKey(const ValueKey('pawmap_capsule_scroll')), findsOneWidget);
      });
    }

    testWidgets('sans hauteur maximale : pas d\'exception (Flexible jamais sans borne)',
        (t) async {
      await t.pumpWidget(_app(SingleChildScrollView(
        child: PawGlassCapsule(
          leading: [btn('a')],
          children: [btn('b')],
        ),
      )));
      await t.pump();
      expect(t.takeException(), isNull);
    });
  });

  group('drapeau Balade', () {
    final start = DateTime(2026, 9, 29, 14, 0);
    for (final l in kLangs) {
      for (final b in Brightness.values) {
        testWidgets('$l · $b : durée + suiveurs, tient dans 44 dp', (t) async {
          await t.pumpWidget(_app(
            PawWalkBadge(
              startedAt: start,
              followers: 3,
              now: () => start.add(const Duration(minutes: 120)),
            ),
            lang: l,
            b: b,
          ));
          await t.pump();
          expect(t.takeException(), isNull);
          final min = t.widget<Text>(find.byKey(const ValueKey('pawmap_walk_badge_min')));
          expect(min.data, contains('120'));
          expect(find.byKey(const ValueKey('pawmap_walk_badge_followers')), findsOneWidget);
          expect(t.getSize(find.byType(PawWalkBadge)).width, lessThanOrEqualTo(44.5));
          final sem = t.getSemantics(find.byType(PawWalkBadge));
          expect(sem.label, isNotEmpty);
        });
      }
    }

    testWidgets('sans suiveur : seulement la durée', (t) async {
      await t.pumpWidget(_app(PawWalkBadge(
        startedAt: start,
        followers: 0,
        now: () => start.add(const Duration(minutes: 7)),
      )));
      await t.pump();
      expect(find.text('7 min'), findsOneWidget);
      expect(find.byKey(const ValueKey('pawmap_walk_badge_followers')), findsNothing);
    });

    test('phrase complète (lecteur d\'écran)', () {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr');
      expect(
          pawWalkBadgeSentence(start, start.add(const Duration(minutes: 12)), 2),
          'En balade · 12 min · 2 te suivent');
    });

    test('écran : pilule du haut retirée, drapeau AU-DESSUS du bouton Balade', () {
      final src = File('lib/views/map/paw_map_screen.dart').readAsStringSync();
      expect(src.contains('PawMapDirectPill('), isFalse);
      final slot = src.indexOf("case 'balade':");
      final badge = src.indexOf('PawWalkBadge(', slot);
      final jewel = src.indexOf("ValueKey<String>('pawmap_walk_btn')", slot);
      expect(slot, greaterThan(0));
      expect(badge, greaterThan(slot));
      expect(jewel, greaterThan(badge));
      // Fixes en tête, jamais dans la liste personnalisable.
      final lead = src.indexOf('leading: [', src.indexOf('Widget _buildMapControlsStack()'));
      expect(src.indexOf('Icons.my_location_rounded', lead), greaterThan(lead));
      // Réglage retenu sur le compte.
      expect(src, contains("_prefs.update({'capsule': order});"));
      expect(src, contains('_capsuleOrder = normalizeCapsuleOrder(p.capsule);'));
    });
  });
}
