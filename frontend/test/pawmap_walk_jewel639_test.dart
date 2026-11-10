// 639 — bouton « Balade en direct » (PawWalkJewel).
//
// Ce qu'on protège ici : le nouveau bouton prend EXACTEMENT la place de
// l'ancien `PawJewel` (mêmes dimensions extérieures, même pastille), reçoit
// ses appuis, ne vole pas ceux des voisins avec ses décorations, et n'anime
// rien hors balade ni quand la réduction des animations est demandée.
//
// Rendus de contrôle (PNG), seulement à la demande :
//   flutter test test/pawmap_walk_jewel639_test.dart \
//     --dart-define=BALADE_RENDUS=/chemin/du/dossier

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/views/map/widgets/pawmap_jewel.dart';
import 'package:hopetsit/views/map/widgets/pawmap_walk_jewel.dart';

const String _rendus = String.fromEnvironment('BALADE_RENDUS');

/// Même harnais que `paw_tab_bar_test.dart`. Écran 393 × 852 = maquette de
/// ScreenUtil : `38.w` vaut exactement 38.
Widget _app(Widget child, {bool reduceMotion = false}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: Scaffold(
            backgroundColor: const Color(0xFFF3EDE2),
            body: Center(child: child),
          ),
        ),
      ),
    ),
  );
}

void _screen(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

PawJewel _old({Key? key, Widget? badge, VoidCallback? onTap}) => PawJewel(
  key: key,
  palette: kJewelWalkOn,
  icon: PawSymbols.walk,
  label: 'Ancien',
  size: 38,
  badge: badge,
  onTap: onTap ?? () {},
);

void main() {
  testWidgets('même encombrement qu\'un PawJewel(size: 38) posé à côté', (
    WidgetTester tester,
  ) async {
    _screen(tester);
    await tester.pumpWidget(
      _app(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _old(key: const ValueKey<String>('old')),
            PawWalkJewel(
              key: const ValueKey<String>('new'),
              label: 'Balade',
              onTap: () {},
            ),
            PawWalkJewel(
              key: const ValueKey<String>('new_live'),
              label: 'Balade en direct',
              live: true,
              badge: const PawFollowersBadge(count: 3),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    final Size old = tester.getSize(find.byKey(const ValueKey<String>('old')));
    expect(old, const Size(44, 44));
    expect(tester.getSize(find.byKey(const ValueKey<String>('new'))), old);
    // Ni la balade en cours (feuilles, pattes) ni la pastille n'agrandissent.
    expect(tester.getSize(find.byKey(const ValueKey<String>('new_live'))), old);
    // Les trois boutons se touchent : aucune marge ajoutée par le nouveau.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<String>('new'))).dx,
      tester.getTopRight(find.byKey(const ValueKey<String>('old'))).dx,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<String>('new_live'))).dx,
      tester.getTopRight(find.byKey(const ValueKey<String>('new'))).dx,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('au-dessus de 44 dp, la zone tactile suit la taille', (
    WidgetTester tester,
  ) async {
    _screen(tester);
    await tester.pumpWidget(
      _app(PawWalkJewel(label: 'Balade', size: 60, onTap: () {})),
    );
    expect(tester.getSize(find.byType(PawWalkJewel)), const Size(60, 60));
  });

  testWidgets('l\'appui et l\'appui long arrivent, une fois chacun', (
    WidgetTester tester,
  ) async {
    _screen(tester);
    int taps = 0;
    int longs = 0;
    await tester.pumpWidget(
      _app(
        PawWalkJewel(
          label: 'Balade',
          onTap: () => taps++,
          onLongPress: () => longs++,
        ),
      ),
    );
    await tester.tap(find.byType(PawWalkJewel));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(longs, 0);

    await tester.longPress(find.byType(PawWalkJewel));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(longs, 1);

    // Le coin de la zone tactile (hors du disque de 38) compte aussi.
    final Offset corner =
        tester.getTopLeft(find.byType(PawWalkJewel)) + const Offset(1, 1);
    await tester.tapAt(corner);
    await tester.pumpAndSettle();
    expect(taps, 2);
    // Le disque est remonté : plus rien ne bouge.
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('deux boutons collés : les décorations ne volent aucun appui', (
    WidgetTester tester,
  ) async {
    _screen(tester);
    int left = 0;
    int right = 0;
    int below = 0;
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PawWalkJewel(
                  key: const ValueKey<String>('a'),
                  label: 'A',
                  live: true,
                  onTap: () => left++,
                ),
                PawWalkJewel(
                  key: const ValueKey<String>('b'),
                  label: 'B',
                  live: true,
                  onTap: () => right++,
                ),
              ],
            ),
            _old(key: const ValueKey<String>('c'), onTap: () => below++),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    final Rect a = tester.getRect(find.byKey(const ValueKey<String>('a')));
    final Rect b = tester.getRect(find.byKey(const ValueKey<String>('b')));
    final Rect c = tester.getRect(find.byKey(const ValueKey<String>('c')));
    expect(a.right, b.left);

    await tester.tapAt(a.center);
    expect((left, right, below), (1, 0, 0));
    await tester.tapAt(b.center);
    expect((left, right, below), (1, 1, 0));

    // Juste de part et d'autre de la frontière : là où les feuilles et les
    // pattes de l'un sont peintes par-dessus l'autre.
    await tester.tapAt(Offset(a.right - 1, a.center.dy));
    expect((left, right, below), (2, 1, 0));
    await tester.tapAt(Offset(b.left + 1, b.center.dy));
    expect((left, right, below), (2, 2, 0));
    await tester.tapAt(Offset(b.left + 1, b.top + 2));
    expect((left, right, below), (2, 3, 0));

    // Le voisin du dessous garde tout son carré, bord supérieur compris
    // (l'ombre et les pattes du bouton du dessus y débordent en peinture).
    await tester.tapAt(Offset(c.center.dx, c.top + 1));
    expect((left, right, below), (2, 3, 1));
    await tester.tapAt(c.center);
    expect((left, right, below), (2, 3, 2));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('hors balade : aucune animation en cours', (
    WidgetTester tester,
  ) async {
    _screen(tester);
    await tester.pumpWidget(_app(PawWalkJewel(label: 'Balade', onTap: () {})));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('en balade : ça bouge, et ça s\'arrête quand la balade finit', (
    WidgetTester tester,
  ) async {
    _screen(tester);
    Widget at(bool live) =>
        _app(PawWalkJewel(label: 'Balade', live: live, onTap: () {}));

    await tester.pumpWidget(at(true));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(at(false));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);

    // Et ça repart à la balade suivante.
    await tester.pumpWidget(at(true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('réduction des animations : image fixe, même en balade', (
    WidgetTester tester,
  ) async {
    _screen(tester);
    await tester.pumpWidget(
      _app(
        PawWalkJewel(label: 'Balade', live: true, onTap: () {}),
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);

    // Le réglage change pendant la balade : l'animation s'arrête puis reprend.
    await tester.pumpWidget(
      _app(PawWalkJewel(label: 'Balade', live: true, onTap: () {})),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(
      _app(
        PawWalkJewel(label: 'Balade', live: true, onTap: () {}),
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('la pastille s\'affiche, au même endroit que sur PawJewel', (
    WidgetTester tester,
  ) async {
    _screen(tester);
    await tester.pumpWidget(
      _app(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _old(
              key: const ValueKey<String>('old'),
              badge: const PawFollowersBadge(
                key: ValueKey<String>('old_badge'),
                count: 4,
              ),
            ),
            PawWalkJewel(
              key: const ValueKey<String>('new'),
              label: 'Balade',
              live: true,
              badge: const PawFollowersBadge(
                key: ValueKey<String>('new_badge'),
                count: 4,
              ),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    expect(find.byKey(const ValueKey<String>('new_badge')), findsOneWidget);
    expect(find.text('4'), findsNWidgets(2));
    final Offset oldDelta =
        tester.getTopLeft(find.byKey(const ValueKey<String>('old_badge'))) -
        tester.getTopLeft(find.byKey(const ValueKey<String>('old')));
    final Offset newDelta =
        tester.getTopLeft(find.byKey(const ValueKey<String>('new_badge'))) -
        tester.getTopLeft(find.byKey(const ValueKey<String>('new')));
    expect(newDelta, oldDelta);
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('new_badge'))),
      tester.getSize(find.byKey(const ValueKey<String>('old_badge'))),
    );

    // Sans pastille : rien à cet endroit.
    await tester.pumpWidget(
      _app(PawWalkJewel(label: 'Balade', live: true, onTap: () {})),
    );
    expect(find.byType(PawFollowersBadge), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('lecteur d\'écran : un bouton, son libellé, son état', (
    WidgetTester tester,
  ) async {
    _screen(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        PawWalkJewel(
          label: 'Balade en direct',
          live: true,
          active: true,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    );
    expect(find.bySemanticsLabel('Balade en direct'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(PawWalkJewel)),
      isSemantics(
        label: 'Balade en direct',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
        hasLongPressAction: true,
      ),
    );

    await tester.pumpWidget(_app(PawWalkJewel(label: 'Balade', onTap: () {})));
    expect(
      tester.getSemantics(find.byType(PawWalkJewel)),
      isSemantics(
        label: 'Balade',
        isButton: true,
        isSelected: false,
        hasTapAction: true,
        hasLongPressAction: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('se dessine sans erreur à toutes les tailles et tous les états', (
    WidgetTester tester,
  ) async {
    _screen(tester);
    for (final double size in <double>[24, 38, 40, 56, 144]) {
      for (final bool live in <bool>[false, true]) {
        await tester.pumpWidget(
          _app(
            PawWalkJewel(
              label: 'Balade',
              size: size,
              live: live,
              badge: live ? const PawFollowersBadge(count: 12) : null,
              onTap: () {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1234));
        expect(tester.takeException(), isNull, reason: '$size / $live');
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // ── Rendus de contrôle (hors suite normale) ───────────────────────────
  group('rendus', () {
    const ValueKey<String> shot = ValueKey<String>('shot');

    Future<void> save(WidgetTester tester, String name, double ratio) async {
      final RenderRepaintBoundary boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(shot));
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage(pixelRatio: ratio);
        final ByteData? data = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        final Directory dir = Directory(_rendus)..createSync(recursive: true);
        File(
          '${dir.path}/$name.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    Widget framed(Widget child, {double pad = 22}) => RepaintBoundary(
      key: shot,
      child: ColoredBox(
        color: const Color(0xFFF3EDE2),
        child: Padding(padding: EdgeInsets.all(pad), child: child),
      ),
    );

    // Un bouton seul : hors ligne, en direct, appuyé.
    for (final double size in <double>[38, 144]) {
      for (final String state in <String>[
        'hors_ligne',
        'en_direct',
        'appuye',
      ]) {
        testWidgets('bouton $size $state', (WidgetTester tester) async {
          _screen(tester);
          final bool live = state != 'hors_ligne';
          await tester.pumpWidget(
            _app(
              framed(
                PawWalkJewel(
                  label: 'Balade',
                  size: size,
                  live: live,
                  onTap: () {},
                ),
                pad: size * 0.6,
              ),
            ),
          );
          // 1,5 s : la tête est penchée à fond (+8°), les feuilles ont bougé.
          await tester.pump(const Duration(milliseconds: 1500));
          TestGesture? gesture;
          if (state == 'appuye') {
            gesture = await tester.startGesture(
              tester.getCenter(find.byType(PawWalkJewel)),
            );
            // 1er pump : le doigt est reconnu (100 ms) ; 2e : le disque descend.
            await tester.pump(const Duration(milliseconds: 150));
            await tester.pump(const Duration(milliseconds: 200));
          }
          final int s = size.round();
          if (size == 38) {
            await save(tester, 'bouton_${s}dp_$state', 3);
            await save(tester, 'bouton_${s}dp_x4_$state', 12);
          } else {
            await save(tester, 'bouton_${s}dp_$state', 3);
          }
          await gesture?.up();
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }

    // Dans la barre de la PawMap : capsule de 50 dp rognée, voisins à 3 dp,
    // minutes sous le bouton (comme `capsule_balade`).
    for (final String state in <String>[
      'hors_ligne',
      'en_direct',
      'en_direct_pastille',
    ]) {
      testWidgets('contexte $state', (WidgetTester tester) async {
        _screen(tester);
        final bool live = state != 'hors_ligne';
        Widget neighbour(PawJewelPalette palette, IconData icon) => PawJewel(
          palette: palette,
          icon: icon,
          label: 'Voisin',
          onTap: () {},
        );
        await tester.pumpWidget(
          _app(
            framed(
              Container(
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(height: 4),
                      neighbour(kJewelWalkOff, PawSymbols.walk),
                      const SizedBox(height: 3),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          PawWalkJewel(
                            label: 'Balade',
                            live: live,
                            badge: state == 'en_direct_pastille'
                                ? const PawFollowersBadge(count: 3)
                                : null,
                            onTap: () {},
                          ),
                          Transform.translate(
                            offset: const Offset(0, -4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                live ? '12 min' : 'Balade',
                                maxLines: 1,
                                softWrap: false,
                                style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: live
                                      ? const Color(0xFF2A9A48)
                                      : const Color(0xFF17141F),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      neighbour(kJewelWalkOff, PawSymbols.walk),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
              pad: 18,
            ),
          ),
        );
        // Plusieurs instants : les pattes passent partout autour du bouton.
        final List<int> times = live ? <int>[1500, 4500, 9000] : <int>[100];
        int elapsed = 0;
        for (final int ms in times) {
          await tester.pump(Duration(milliseconds: ms - elapsed));
          elapsed = ms;
          await save(tester, 'contexte_${state}_${ms}ms', 6);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }, skip: _rendus.isEmpty ? 'rendus à la demande (BALADE_RENDUS)' : false);
}
