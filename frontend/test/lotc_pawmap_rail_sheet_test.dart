// v584 — lot C du chantier du 24/09 : RAIL, DOCK, FEUILLE GLISSANTE et
// DÉCOUVERTE GUIDÉE, bouton par bouton (méthode imposée : « tests de widgets
// qui appuient sur CHAQUE bouton du rail, du dock, de la feuille »).
//   · rail : chaque bouton de l'ordre choisi appelle `onTap(id)` avec SON id ;
//     appui long → `onLongPress(id)` ; le bouton « personnaliser » ;
//     un ordre inconnu / vide retombe sur l'ordre d'origine ;
//   · menu de personnalisation : interrupteur = cacher / montrer, remise à
//     zéro, la liste renvoyée est bien l'ordre affiché ;
//   · bulle d'explication : « Essayer » et « Personnaliser » ;
//   · dock : les 5 pilules (SOS, partager, calques, nuit, historique) ;
//   · feuille : 3 crans, bouton principal, sélecteur « Je cherche » (re-toucher
//     = « tout »), carte vide = une action ;
//   · découverte guidée : Suivant → Suivant → Compris.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/v565/lotc584_i18n.dart';
import 'package:hopetsit/localization/v565/map_i18n.dart';
import 'package:hopetsit/utils/pawmap_theme.dart';
import 'package:hopetsit/views/map/widgets/pawmap_buttons.dart';
import 'package:hopetsit/views/map/widgets/pawmap_rail.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheet.dart';

const List<String> _langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

class _T extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        for (final l in _langs)
          l: {
            ...mapI18n[l] ?? const <String, String>{},
            ...lotC584I18n[l]!,
            'pawmap_btn_around': 'Autour de moi',
            'pawmap_btn_directions': 'Itinéraire',
            'pawmap_btn_circle_chat': 'Chat du cercle',
            'pawmap_btn_spot_photo': 'Photo du spot',
            'pawmap_view_spots_btn': 'Voir les spots',
            'pawmap_tag_spot': 'Marquer un lieu',
            'pawmap_btn_send': 'Signaler',
            'pawmap_view_reports_btn': 'Voir signaux',
            'pawmap_dock_sos': 'SOS animal',
            'pawmap_dock_share_map': 'Partager la carte',
            'pawmap_dock_layers': 'Calques',
            'pawmap_dock_night': 'Mode nuit',
            'pawmap_dock_history': 'Historique',
          },
      };
}

Widget _app(Widget child, {bool scroll = true}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      translations: _T(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('en'),
      theme: ThemeData(brightness: Brightness.light),
      home: Scaffold(
        body: scroll
            ? SingleChildScrollView(
                child: Align(alignment: Alignment.topLeft, child: child))
            : child,
      ),
    ),
  );
}

/// Écran de téléphone (393 × 852, comme la maquette) : les tailles ScreenUtil
/// sont alors celles de l'app, pas celles de la fenêtre de test par défaut.
void _phone(WidgetTester tester, {double height = 852}) {
  tester.view.physicalSize = Size(393, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  tearDown(Get.reset);

  group('rail gauche personnalisable', () {
    testWidgets('chaque bouton de l\'ordre choisi appelle onTap avec SON id ; appui long = explication',
        (tester) async {
      _phone(tester, height: 1400);
      final taps = <String>[];
      final longs = <String>[];
      var customize = 0;
      final order = ['report', 'around', 'spots']; // ordre choisi par l'utilisateur
      await tester.pumpWidget(_app(PawMapRail(
        order: order,
        onTap: taps.add,
        onLongPress: longs.add,
        onCustomize: () => customize++,
      )));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
      // L'ordre affiché est l'ordre choisi.
      final ys = order
          .map((id) => tester.getTopLeft(find.byKey(ValueKey<String>('rail_$id'))).dy)
          .toList();
      expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue);
      for (final id in order) {
        await tester.tap(find.byKey(ValueKey<String>('rail_$id')));
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(taps, order);
      await tester.longPress(find.byKey(const ValueKey<String>('rail_around')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(longs, ['around']);
      await tester.tap(find.byKey(const ValueKey<String>('rail_customize')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(customize, 1);
      // Aucun bouton hors de l'ordre n'est dessiné.
      expect(find.byKey(const ValueKey<String>('rail_chat')), findsNothing);
    });

    testWidgets('les 9 boutons d\'origine sont tous là avec l\'ordre par défaut et chacun répond',
        (tester) async {
      _phone(tester, height: 1400);
      final taps = <String>[];
      await tester.pumpWidget(_app(PawMapRail(
        order: kPawRailDefaultOrder,
        onTap: taps.add,
        onLongPress: (_) {},
        onCustomize: () {},
      )));
      await tester.pump(const Duration(milliseconds: 60));
      expect(kPawRailDefaultOrder,
          ['around', 'directions', 'live_friends', 'chat', 'photo', 'spots', 'tag', 'report', 'feed']);
      for (final id in kPawRailDefaultOrder) {
        await tester.tap(find.byKey(ValueKey<String>('rail_$id')));
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(taps, kPawRailDefaultOrder);
    });

    test('normalizeRailOrder : ids inconnus et doublons retirés, vide = défaut', () {
      expect(normalizeRailOrder(['spots', 'hack', 'spots', 'tag']), ['spots', 'tag']);
      expect(normalizeRailOrder([]), kPawRailDefaultOrder);
      expect(normalizeRailOrder(null), kPawRailDefaultOrder);
      // Chaque bouton a une explication traduite dans les 9 langues.
      for (final spec in kPawRailSpecs) {
        for (final l in _langs) {
          expect(lotC584I18n[l]![spec.helpKey], isNotEmpty, reason: '$l/${spec.id}');
        }
      }
    });

    testWidgets('menu de personnalisation : cacher, montrer, remettre l\'ordre d\'origine',
        (tester) async {
      _phone(tester, height: 1600);
      final emitted = <List<String>>[];
      await tester.pumpWidget(_app(
        SizedBox(
          height: 1500,
          child: PawRailCustomizeSheet(
            order: const ['around', 'report'],
            onChanged: emitted.add,
          ),
        ),
        scroll: false,
      ));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
      // Cacher « around » : la liste renvoyée ne le contient plus.
      await tester.tap(find.byKey(const ValueKey<String>('rail_switch_around')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(emitted.last, ['report']);
      // Montrer « chat » : ajouté à la fin des affichés.
      await tester.tap(find.byKey(const ValueKey<String>('rail_switch_chat')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(emitted.last, ['report', 'chat']);
      // Remise à zéro.
      await tester.ensureVisible(find.byKey(const ValueKey<String>('rail_reset')));
      await tester.tap(find.byKey(const ValueKey<String>('rail_reset')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(emitted.last, kPawRailDefaultOrder);
      // Chaque ligne montre son explication.
      expect(find.text('pawmap_rail_help_report'.tr), findsOneWidget);
    });

    testWidgets('bulle d\'explication : Essayer et Personnaliser', (tester) async {
      _phone(tester);
      var did = 0, custom = 0;
      await tester.pumpWidget(_app(PawRailHelpSheet(
        title: 'Signaler',
        help: 'Signale quelque chose autour de toi.',
        color: PawMapTheme.danger,
        icon: Icons.add_moderator_rounded,
        onDo: () => did++,
        onCustomize: () => custom++,
      )));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Signale quelque chose autour de toi.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('rail_help_do')));
      await tester.tap(find.byKey(const ValueKey<String>('rail_help_customize')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(did, 1);
      expect(custom, 1);
    });
  });

  group('dock (SOS, partager, calques, nuit, historique)', () {
    testWidgets('les 5 pilules appellent leur rappel ; appui long = explication',
        (tester) async {
      _phone(tester);
      final calls = <String>[];
      final longs = <String>[];
      await tester.pumpWidget(_app(PawMapDockRow(
        wrap: true,
        nightMode: false,
        onSos: () => calls.add('sos'),
        onShare: () => calls.add('share'),
        onLayers: () => calls.add('layers'),
        onNight: () => calls.add('night'),
        onHistory: () => calls.add('history'),
        onLongPress: longs.add,
      )));
      await tester.pump(const Duration(milliseconds: 60));
      for (final id in ['sos', 'share', 'layers', 'night', 'history']) {
        await tester.tap(find.byKey(ValueKey<String>('dock_$id')));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(calls, ['sos', 'share', 'layers', 'night', 'history']);
      await tester.longPress(find.byKey(const ValueKey<String>('dock_sos')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(longs, ['sos']);
    });
  });

  group('feuille glissante à 3 positions', () {
    testWidgets('positions basse / moyenne / haute, bouton principal toujours visible',
        (tester) async {
      _phone(tester, height: 852);
      final ctl = DraggableScrollableController();
      var primaryTaps = 0;
      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, __) => GetMaterialApp(
          translations: _T(),
          locale: const Locale('fr'),
          home: Scaffold(
            body: LayoutBuilder(builder: (ctx, c) {
              final sheet = PawMapSheet(
                controller: ctl,
                availableHeight: c.maxHeight,
                peekHeight: 118,
                header: PawSignatureButton(
                  key: const ValueKey<String>('primary'),
                  label: 'Publier ma demande',
                  icon: Icons.campaign_rounded,
                  color: PawMapTheme.owner,
                  onTap: () => primaryTaps++,
                ),
                children: [
                  for (var i = 0; i < 12; i++)
                    SizedBox(height: 60, child: Text('ligne $i')),
                ],
              );
              return Stack(children: [Positioned.fill(child: sheet)]);
            }),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      // Position basse : le bouton principal est visible et cliquable.
      expect(find.byKey(const ValueKey<String>('primary')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('primary')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(primaryTaps, 1);
      final low = ctl.size;
      expect(low, closeTo(118 / 852, 0.02));
      // Cran moyen.
      ctl.jumpTo(0.46);
      await tester.pump(const Duration(milliseconds: 60));
      expect(ctl.size, closeTo(0.46, 0.01));
      // Cran haut.
      ctl.jumpTo(0.90);
      await tester.pump(const Duration(milliseconds: 60));
      expect(ctl.size, closeTo(0.90, 0.01));
      // Jamais plus haut que le cran haut, jamais plus bas que le cran bas.
      ctl.jumpTo(1.0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(ctl.size, lessThanOrEqualTo(0.90 + 1e-6));
      ctl.jumpTo(0.0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(ctl.size, greaterThanOrEqualTo(low - 1e-6));
    });

    testWidgets('sélecteur « Je cherche » : une pilule = un choix, re-toucher = tout',
        (tester) async {
      _phone(tester);
      final got = <String>[];
      await tester.pumpWidget(_app(PawMapLookingSelector(
        value: 'sitters',
        onChanged: got.add,
      )));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byKey(const ValueKey<String>('looking_walkers')));
      await tester.tap(find.byKey(const ValueKey<String>('looking_places')));
      await tester.tap(find.byKey(const ValueKey<String>('looking_friends')));
      await tester.tap(find.byKey(const ValueKey<String>('looking_sitters')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(got, ['walkers', 'places', 'friends', 'all']);
    });

    testWidgets('carte vide = une action (propriétaire / gardien)', (tester) async {
      _phone(tester);
      var taps = 0;
      await tester.pumpWidget(_app(PawMapEmptyCard(viewerRole: 'owner', onAction: () => taps++)));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.textContaining('Publie ta demande'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('pawmap_empty_action')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(taps, 1);
      await tester.pumpWidget(_app(PawMapEmptyCard(viewerRole: 'sitter', onAction: () => taps++)));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.textContaining('gardien du quartier'), findsOneWidget);
    });
  });

  group('découverte guidée (3 bulles max)', () {
    testWidgets('Suivant, Suivant, Compris', (tester) async {
      _phone(tester);
      var step = 0;
      var done = 0;
      Widget build() => _app(
            SizedBox(
              height: 800,
              child: Stack(children: [
                PawMapCoach(step: step, onNext: () => step++, onDone: () => done++),
              ]),
            ),
            scroll: false,
          );
      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.textContaining('« ? »'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('coach_next')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(step, 1);
      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.textContaining('rail'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('coach_next')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(step, 2);
      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.textContaining('panneau'), findsOneWidget);
      expect(find.text('Compris'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('coach_next')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(done, 1);
      expect(PawMapCoach.steps, 3);
    });
  });
}
